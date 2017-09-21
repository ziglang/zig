//===- InputFiles.cpp -----------------------------------------------------===//
//
//                             The LLVM Linker
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//

#include "InputFiles.h"
#include "Chunks.h"
#include "Config.h"
#include "Driver.h"
#include "Error.h"
#include "Memory.h"
#include "SymbolTable.h"
#include "Symbols.h"
#include "llvm-c/lto.h"
#include "llvm/ADT/SmallVector.h"
#include "llvm/ADT/Triple.h"
#include "llvm/ADT/Twine.h"
#include "llvm/BinaryFormat/COFF.h"
#include "llvm/Object/Binary.h"
#include "llvm/Object/COFF.h"
#include "llvm/Support/Casting.h"
#include "llvm/Support/Endian.h"
#include "llvm/Support/Error.h"
#include "llvm/Support/ErrorOr.h"
#include "llvm/Support/FileSystem.h"
#include "llvm/Target/TargetOptions.h"
#include <cstring>
#include <system_error>
#include <utility>

using namespace llvm;
using namespace llvm::COFF;
using namespace llvm::object;
using namespace llvm::support::endian;

using llvm::Triple;
using llvm::support::ulittle32_t;

namespace lld {
namespace coff {

/// Checks that Source is compatible with being a weak alias to Target.
/// If Source is Undefined and has no weak alias set, makes it a weak
/// alias to Target.
static void checkAndSetWeakAlias(SymbolTable *Symtab, InputFile *F,
                                 SymbolBody *Source, SymbolBody *Target) {
  if (auto *U = dyn_cast<Undefined>(Source)) {
    if (U->WeakAlias && U->WeakAlias != Target)
      Symtab->reportDuplicate(Source->symbol(), F);
    U->WeakAlias = Target;
  }
}

ArchiveFile::ArchiveFile(MemoryBufferRef M) : InputFile(ArchiveKind, M) {}

void ArchiveFile::parse() {
  // Parse a MemoryBufferRef as an archive file.
  File = check(Archive::create(MB), toString(this));

  // Read the symbol table to construct Lazy objects.
  for (const Archive::Symbol &Sym : File->symbols())
    Symtab->addLazy(this, Sym);
}

// Returns a buffer pointing to a member file containing a given symbol.
void ArchiveFile::addMember(const Archive::Symbol *Sym) {
  const Archive::Child &C =
      check(Sym->getMember(),
            "could not get the member for symbol " + Sym->getName());

  // Return an empty buffer if we have already returned the same buffer.
  if (!Seen.insert(C.getChildOffset()).second)
    return;

  Driver->enqueueArchiveMember(C, Sym->getName(), getName());
}

void ObjectFile::parse() {
  // Parse a memory buffer as a COFF file.
  std::unique_ptr<Binary> Bin = check(createBinary(MB), toString(this));

  if (auto *Obj = dyn_cast<COFFObjectFile>(Bin.get())) {
    Bin.release();
    COFFObj.reset(Obj);
  } else {
    fatal(toString(this) + " is not a COFF file");
  }

  // Read section and symbol tables.
  initializeChunks();
  initializeSymbols();
  initializeSEH();
}

void ObjectFile::initializeChunks() {
  uint32_t NumSections = COFFObj->getNumberOfSections();
  Chunks.reserve(NumSections);
  SparseChunks.resize(NumSections + 1);
  for (uint32_t I = 1; I < NumSections + 1; ++I) {
    const coff_section *Sec;
    StringRef Name;
    if (auto EC = COFFObj->getSection(I, Sec))
      fatal(EC, "getSection failed: #" + Twine(I));
    if (auto EC = COFFObj->getSectionName(Sec, Name))
      fatal(EC, "getSectionName failed: #" + Twine(I));
    if (Name == ".sxdata") {
      SXData = Sec;
      continue;
    }
    if (Name == ".drectve") {
      ArrayRef<uint8_t> Data;
      COFFObj->getSectionContents(Sec, Data);
      Directives = std::string((const char *)Data.data(), Data.size());
      continue;
    }

    // Object files may have DWARF debug info or MS CodeView debug info
    // (or both).
    //
    // DWARF sections don't need any special handling from the perspective
    // of the linker; they are just a data section containing relocations.
    // We can just link them to complete debug info.
    //
    // CodeView needs a linker support. We need to interpret and debug
    // info, and then write it to a separate .pdb file.

    // Ignore debug info unless /debug is given.
    if (!Config->Debug && Name.startswith(".debug"))
      continue;

    if (Sec->Characteristics & llvm::COFF::IMAGE_SCN_LNK_REMOVE)
      continue;
    auto *C = make<SectionChunk>(this, Sec);

    // CodeView sections are stored to a different vector because they are not
    // linked in the regular manner.
    if (C->isCodeView())
      DebugChunks.push_back(C);
    else
      Chunks.push_back(C);

    SparseChunks[I] = C;
  }
}

void ObjectFile::initializeSymbols() {
  uint32_t NumSymbols = COFFObj->getNumberOfSymbols();
  SymbolBodies.reserve(NumSymbols);
  SparseSymbolBodies.resize(NumSymbols);

  SmallVector<std::pair<SymbolBody *, uint32_t>, 8> WeakAliases;
  int32_t LastSectionNumber = 0;

  for (uint32_t I = 0; I < NumSymbols; ++I) {
    // Get a COFFSymbolRef object.
    ErrorOr<COFFSymbolRef> SymOrErr = COFFObj->getSymbol(I);
    if (!SymOrErr)
      fatal(SymOrErr.getError(), "broken object file: " + toString(this));
    COFFSymbolRef Sym = *SymOrErr;

    const void *AuxP = nullptr;
    if (Sym.getNumberOfAuxSymbols())
      AuxP = COFFObj->getSymbol(I + 1)->getRawPtr();
    bool IsFirst = (LastSectionNumber != Sym.getSectionNumber());

    SymbolBody *Body = nullptr;
    if (Sym.isUndefined()) {
      Body = createUndefined(Sym);
    } else if (Sym.isWeakExternal()) {
      Body = createUndefined(Sym);
      uint32_t TagIndex =
          static_cast<const coff_aux_weak_external *>(AuxP)->TagIndex;
      WeakAliases.emplace_back(Body, TagIndex);
    } else {
      Body = createDefined(Sym, AuxP, IsFirst);
    }
    if (Body) {
      SymbolBodies.push_back(Body);
      SparseSymbolBodies[I] = Body;
    }
    I += Sym.getNumberOfAuxSymbols();
    LastSectionNumber = Sym.getSectionNumber();
  }

  for (auto &KV : WeakAliases) {
    SymbolBody *Sym = KV.first;
    uint32_t Idx = KV.second;
    checkAndSetWeakAlias(Symtab, this, Sym, SparseSymbolBodies[Idx]);
  }
}

SymbolBody *ObjectFile::createUndefined(COFFSymbolRef Sym) {
  StringRef Name;
  COFFObj->getSymbolName(Sym, Name);
  return Symtab->addUndefined(Name, this, Sym.isWeakExternal())->body();
}

SymbolBody *ObjectFile::createDefined(COFFSymbolRef Sym, const void *AuxP,
                                      bool IsFirst) {
  StringRef Name;
  if (Sym.isCommon()) {
    auto *C = make<CommonChunk>(Sym);
    Chunks.push_back(C);
    COFFObj->getSymbolName(Sym, Name);
    Symbol *S =
        Symtab->addCommon(this, Name, Sym.getValue(), Sym.getGeneric(), C);
    return S->body();
  }
  if (Sym.isAbsolute()) {
    COFFObj->getSymbolName(Sym, Name);
    // Skip special symbols.
    if (Name == "@comp.id")
      return nullptr;
    // COFF spec 5.10.1. The .sxdata section.
    if (Name == "@feat.00") {
      if (Sym.getValue() & 1)
        SEHCompat = true;
      return nullptr;
    }
    if (Sym.isExternal())
      return Symtab->addAbsolute(Name, Sym)->body();
    else
      return make<DefinedAbsolute>(Name, Sym);
  }
  int32_t SectionNumber = Sym.getSectionNumber();
  if (SectionNumber == llvm::COFF::IMAGE_SYM_DEBUG)
    return nullptr;

  // Reserved sections numbers don't have contents.
  if (llvm::COFF::isReservedSectionNumber(SectionNumber))
    fatal("broken object file: " + toString(this));

  // This symbol references a section which is not present in the section
  // header.
  if ((uint32_t)SectionNumber >= SparseChunks.size())
    fatal("broken object file: " + toString(this));

  // Nothing else to do without a section chunk.
  auto *SC = cast_or_null<SectionChunk>(SparseChunks[SectionNumber]);
  if (!SC)
    return nullptr;

  // Handle section definitions
  if (IsFirst && AuxP) {
    auto *Aux = reinterpret_cast<const coff_aux_section_definition *>(AuxP);
    if (Aux->Selection == IMAGE_COMDAT_SELECT_ASSOCIATIVE)
      if (auto *ParentSC = cast_or_null<SectionChunk>(
              SparseChunks[Aux->getNumber(Sym.isBigObj())])) {
        ParentSC->addAssociative(SC);
        // If we already discarded the parent, discard the child.
        if (ParentSC->isDiscarded())
          SC->markDiscarded();
      }
    SC->Checksum = Aux->CheckSum;
  }

  DefinedRegular *B;
  if (Sym.isExternal()) {
    COFFObj->getSymbolName(Sym, Name);
    Symbol *S =
        Symtab->addRegular(this, Name, SC->isCOMDAT(), Sym.getGeneric(), SC);
    B = cast<DefinedRegular>(S->body());
  } else
    B = make<DefinedRegular>(this, /*Name*/ "", SC->isCOMDAT(),
                             /*IsExternal*/ false, Sym.getGeneric(), SC);
  if (SC->isCOMDAT() && Sym.getValue() == 0 && !AuxP)
    SC->setSymbol(B);

  return B;
}

void ObjectFile::initializeSEH() {
  if (!SEHCompat || !SXData)
    return;
  ArrayRef<uint8_t> A;
  COFFObj->getSectionContents(SXData, A);
  if (A.size() % 4 != 0)
    fatal(".sxdata must be an array of symbol table indices");
  auto *I = reinterpret_cast<const ulittle32_t *>(A.data());
  auto *E = reinterpret_cast<const ulittle32_t *>(A.data() + A.size());
  for (; I != E; ++I)
    SEHandlers.insert(SparseSymbolBodies[*I]);
}

MachineTypes ObjectFile::getMachineType() {
  if (COFFObj)
    return static_cast<MachineTypes>(COFFObj->getMachine());
  return IMAGE_FILE_MACHINE_UNKNOWN;
}

StringRef ltrim1(StringRef S, const char *Chars) {
  if (!S.empty() && strchr(Chars, S[0]))
    return S.substr(1);
  return S;
}

void ImportFile::parse() {
  const char *Buf = MB.getBufferStart();
  const char *End = MB.getBufferEnd();
  const auto *Hdr = reinterpret_cast<const coff_import_header *>(Buf);

  // Check if the total size is valid.
  if ((size_t)(End - Buf) != (sizeof(*Hdr) + Hdr->SizeOfData))
    fatal("broken import library");

  // Read names and create an __imp_ symbol.
  StringRef Name = Saver.save(StringRef(Buf + sizeof(*Hdr)));
  StringRef ImpName = Saver.save("__imp_" + Name);
  const char *NameStart = Buf + sizeof(coff_import_header) + Name.size() + 1;
  DLLName = StringRef(NameStart);
  StringRef ExtName;
  switch (Hdr->getNameType()) {
  case IMPORT_ORDINAL:
    ExtName = "";
    break;
  case IMPORT_NAME:
    ExtName = Name;
    break;
  case IMPORT_NAME_NOPREFIX:
    ExtName = ltrim1(Name, "?@_");
    break;
  case IMPORT_NAME_UNDECORATE:
    ExtName = ltrim1(Name, "?@_");
    ExtName = ExtName.substr(0, ExtName.find('@'));
    break;
  }

  this->Hdr = Hdr;
  ExternalName = ExtName;

  ImpSym = cast<DefinedImportData>(
      Symtab->addImportData(ImpName, this)->body());
  if (Hdr->getType() == llvm::COFF::IMPORT_CONST)
    ConstSym =
        cast<DefinedImportData>(Symtab->addImportData(Name, this)->body());

  // If type is function, we need to create a thunk which jump to an
  // address pointed by the __imp_ symbol. (This allows you to call
  // DLL functions just like regular non-DLL functions.)
  if (Hdr->getType() != llvm::COFF::IMPORT_CODE)
    return;
  ThunkSym = cast<DefinedImportThunk>(
      Symtab->addImportThunk(Name, ImpSym, Hdr->Machine)->body());
}

void BitcodeFile::parse() {
  Obj = check(lto::InputFile::create(MemoryBufferRef(
      MB.getBuffer(), Saver.save(ParentName + MB.getBufferIdentifier()))));
  for (const lto::InputFile::Symbol &ObjSym : Obj->symbols()) {
    StringRef SymName = Saver.save(ObjSym.getName());
    Symbol *Sym;
    if (ObjSym.isUndefined()) {
      Sym = Symtab->addUndefined(SymName, this, false);
    } else if (ObjSym.isCommon()) {
      Sym = Symtab->addCommon(this, SymName, ObjSym.getCommonSize());
    } else if (ObjSym.isWeak() && ObjSym.isIndirect()) {
      // Weak external.
      Sym = Symtab->addUndefined(SymName, this, true);
      std::string Fallback = ObjSym.getCOFFWeakExternalFallback();
      SymbolBody *Alias = Symtab->addUndefined(Saver.save(Fallback));
      checkAndSetWeakAlias(Symtab, this, Sym->body(), Alias);
    } else {
      bool IsCOMDAT = ObjSym.getComdatIndex() != -1;
      Sym = Symtab->addRegular(this, SymName, IsCOMDAT);
    }
    SymbolBodies.push_back(Sym->body());
  }
  Directives = Obj->getCOFFLinkerOpts();
}

MachineTypes BitcodeFile::getMachineType() {
  switch (Triple(Obj->getTargetTriple()).getArch()) {
  case Triple::x86_64:
    return AMD64;
  case Triple::x86:
    return I386;
  case Triple::arm:
    return ARMNT;
  case Triple::aarch64:
    return ARM64;
  default:
    return IMAGE_FILE_MACHINE_UNKNOWN;
  }
}
} // namespace coff
} // namespace lld

// Returns the last element of a path, which is supposed to be a filename.
static StringRef getBasename(StringRef Path) {
  size_t Pos = Path.find_last_of("\\/");
  if (Pos == StringRef::npos)
    return Path;
  return Path.substr(Pos + 1);
}

// Returns a string in the format of "foo.obj" or "foo.obj(bar.lib)".
std::string lld::toString(coff::InputFile *File) {
  if (!File)
    return "(internal)";
  if (File->ParentName.empty())
    return File->getName().lower();

  std::string Res =
      (getBasename(File->ParentName) + "(" + getBasename(File->getName()) + ")")
          .str();
  return StringRef(Res).lower();
}
