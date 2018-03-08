//===- InputFiles.cpp -----------------------------------------------------===//
//
//                             The LLVM Linker
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//

#include "InputFiles.h"

#include "Config.h"
#include "InputSegment.h"
#include "SymbolTable.h"
#include "lld/Common/ErrorHandler.h"
#include "lld/Common/Memory.h"
#include "llvm/Object/Binary.h"
#include "llvm/Object/Wasm.h"
#include "llvm/Support/raw_ostream.h"

#define DEBUG_TYPE "lld"

using namespace lld;
using namespace lld::wasm;

using namespace llvm;
using namespace llvm::object;
using namespace llvm::wasm;

Optional<MemoryBufferRef> lld::wasm::readFile(StringRef Path) {
  log("Loading: " + Path);

  auto MBOrErr = MemoryBuffer::getFile(Path);
  if (auto EC = MBOrErr.getError()) {
    error("cannot open " + Path + ": " + EC.message());
    return None;
  }
  std::unique_ptr<MemoryBuffer> &MB = *MBOrErr;
  MemoryBufferRef MBRef = MB->getMemBufferRef();
  make<std::unique_ptr<MemoryBuffer>>(std::move(MB)); // take MB ownership

  return MBRef;
}

void ObjFile::dumpInfo() const {
  log("reloc info for: " + getName() + "\n" +
      "        FunctionIndexOffset : " + Twine(FunctionIndexOffset) + "\n" +
      "         NumFunctionImports : " + Twine(NumFunctionImports()) + "\n" +
      "           NumGlobalImports : " + Twine(NumGlobalImports()) + "\n");
}

bool ObjFile::isImportedFunction(uint32_t Index) const {
  return Index < NumFunctionImports();
}

Symbol *ObjFile::getFunctionSymbol(uint32_t Index) const {
  return FunctionSymbols[Index];
}

Symbol *ObjFile::getTableSymbol(uint32_t Index) const {
  return TableSymbols[Index];
}

Symbol *ObjFile::getGlobalSymbol(uint32_t Index) const {
  return GlobalSymbols[Index];
}

uint32_t ObjFile::getRelocatedAddress(uint32_t Index) const {
  return getGlobalSymbol(Index)->getVirtualAddress();
}

uint32_t ObjFile::relocateFunctionIndex(uint32_t Original) const {
  Symbol *Sym = getFunctionSymbol(Original);
  uint32_t Index = Sym->getOutputIndex();
  DEBUG(dbgs() << "relocateFunctionIndex: " << toString(*Sym) << ": "
               << Original << " -> " << Index << "\n");
  return Index;
}

uint32_t ObjFile::relocateTypeIndex(uint32_t Original) const {
  return TypeMap[Original];
}

uint32_t ObjFile::relocateTableIndex(uint32_t Original) const {
  Symbol *Sym = getTableSymbol(Original);
  uint32_t Index = Sym->getTableIndex();
  DEBUG(dbgs() << "relocateTableIndex: " << toString(*Sym) << ": " << Original
               << " -> " << Index << "\n");
  return Index;
}

uint32_t ObjFile::relocateGlobalIndex(uint32_t Original) const {
  Symbol *Sym = getGlobalSymbol(Original);
  uint32_t Index = Sym->getOutputIndex();
  DEBUG(dbgs() << "relocateGlobalIndex: " << toString(*Sym) << ": " << Original
               << " -> " << Index << "\n");
  return Index;
}

void ObjFile::parse() {
  // Parse a memory buffer as a wasm file.
  DEBUG(dbgs() << "Parsing object: " << toString(this) << "\n");
  std::unique_ptr<Binary> Bin = CHECK(createBinary(MB), toString(this));

  auto *Obj = dyn_cast<WasmObjectFile>(Bin.get());
  if (!Obj)
    fatal(toString(this) + ": not a wasm file");
  if (!Obj->isRelocatableObject())
    fatal(toString(this) + ": not a relocatable wasm file");

  Bin.release();
  WasmObj.reset(Obj);

  // Find the code and data sections.  Wasm objects can have at most one code
  // and one data section.
  for (const SectionRef &Sec : WasmObj->sections()) {
    const WasmSection &Section = WasmObj->getWasmSection(Sec);
    if (Section.Type == WASM_SEC_CODE)
      CodeSection = &Section;
    else if (Section.Type == WASM_SEC_DATA)
      DataSection = &Section;
  }

  initializeSymbols();
}

// Return the InputSegment in which a given symbol is defined.
InputSegment *ObjFile::getSegment(const WasmSymbol &WasmSym) {
  uint32_t Address = WasmObj->getWasmSymbolValue(WasmSym);
  for (InputSegment *Segment : Segments) {
    if (Address >= Segment->startVA() && Address < Segment->endVA()) {
      DEBUG(dbgs() << "Found symbol in segment: " << WasmSym.Name << " -> "
                   << Segment->getName() << "\n");

      return Segment;
    }
  }
  error("symbol not found in any segment: " + WasmSym.Name);
  return nullptr;
}

static void copyRelocationsRange(std::vector<WasmRelocation> &To,
                                 ArrayRef<WasmRelocation> From, size_t Start,
                                 size_t End) {
  for (const WasmRelocation &R : From)
    if (R.Offset >= Start && R.Offset < End)
      To.push_back(R);
}

void ObjFile::initializeSymbols() {
  Symbols.reserve(WasmObj->getNumberOfSymbols());

  for (const WasmImport &Import : WasmObj->imports()) {
    switch (Import.Kind) {
    case WASM_EXTERNAL_FUNCTION:
      ++FunctionImports;
      break;
    case WASM_EXTERNAL_GLOBAL:
      ++GlobalImports;
      break;
    }
  }

  FunctionSymbols.resize(FunctionImports + WasmObj->functions().size());
  GlobalSymbols.resize(GlobalImports + WasmObj->globals().size());

  for (const WasmSegment &S : WasmObj->dataSegments()) {
    InputSegment *Seg = make<InputSegment>(&S, this);
    copyRelocationsRange(Seg->Relocations, DataSection->Relocations,
                         Seg->getInputSectionOffset(),
                         Seg->getInputSectionOffset() + Seg->getSize());
    Segments.emplace_back(Seg);
  }

  // Populate `FunctionSymbols` and `GlobalSymbols` based on the WasmSymbols
  // in the object
  for (const SymbolRef &Sym : WasmObj->symbols()) {
    const WasmSymbol &WasmSym = WasmObj->getWasmSymbol(Sym.getRawDataRefImpl());
    Symbol *S;
    switch (WasmSym.Type) {
    case WasmSymbol::SymbolType::FUNCTION_IMPORT:
    case WasmSymbol::SymbolType::GLOBAL_IMPORT:
      S = createUndefined(WasmSym);
      break;
    case WasmSymbol::SymbolType::GLOBAL_EXPORT:
      S = createDefined(WasmSym, getSegment(WasmSym));
      break;
    case WasmSymbol::SymbolType::FUNCTION_EXPORT:
      S = createDefined(WasmSym);
      break;
    case WasmSymbol::SymbolType::DEBUG_FUNCTION_NAME:
      // These are for debugging only, no need to create linker symbols for them
      continue;
    }

    Symbols.push_back(S);
    if (WasmSym.isFunction()) {
      DEBUG(dbgs() << "Function: " << WasmSym.ElementIndex << " -> "
                   << toString(*S) << "\n");
      FunctionSymbols[WasmSym.ElementIndex] = S;
      if (WasmSym.HasAltIndex)
        FunctionSymbols[WasmSym.AltIndex] = S;
    } else {
      DEBUG(dbgs() << "Global: " << WasmSym.ElementIndex << " -> "
                   << toString(*S) << "\n");
      GlobalSymbols[WasmSym.ElementIndex] = S;
      if (WasmSym.HasAltIndex)
        GlobalSymbols[WasmSym.AltIndex] = S;
    }
  }

  DEBUG(for (size_t I = 0; I < FunctionSymbols.size(); ++I)
            assert(FunctionSymbols[I] != nullptr);
        for (size_t I = 0; I < GlobalSymbols.size(); ++I)
            assert(GlobalSymbols[I] != nullptr););

  // Populate `TableSymbols` with all symbols that are called indirectly
  uint32_t SegmentCount = WasmObj->elements().size();
  if (SegmentCount) {
    if (SegmentCount > 1)
      fatal(getName() + ": contains more than one element segment");
    const WasmElemSegment &Segment = WasmObj->elements()[0];
    if (Segment.Offset.Opcode != WASM_OPCODE_I32_CONST)
      fatal(getName() + ": unsupported element segment");
    if (Segment.TableIndex != 0)
      fatal(getName() + ": unsupported table index in elem segment");
    if (Segment.Offset.Value.Int32 != 0)
      fatal(getName() + ": unsupported element segment offset");
    TableSymbols.reserve(Segment.Functions.size());
    for (uint64_t FunctionIndex : Segment.Functions)
      TableSymbols.push_back(getFunctionSymbol(FunctionIndex));
  }

  DEBUG(dbgs() << "TableSymbols: " << TableSymbols.size() << "\n");
  DEBUG(dbgs() << "Functions   : " << FunctionSymbols.size() << "\n");
  DEBUG(dbgs() << "Globals     : " << GlobalSymbols.size() << "\n");
}

Symbol *ObjFile::createUndefined(const WasmSymbol &Sym) {
  return Symtab->addUndefined(this, &Sym);
}

Symbol *ObjFile::createDefined(const WasmSymbol &Sym,
                               const InputSegment *Segment) {
  Symbol *S;
  if (Sym.isLocal()) {
    S = make<Symbol>(Sym.Name, true);
    Symbol::Kind Kind;
    if (Sym.Type == WasmSymbol::SymbolType::FUNCTION_EXPORT)
      Kind = Symbol::Kind::DefinedFunctionKind;
    else if (Sym.Type == WasmSymbol::SymbolType::GLOBAL_EXPORT)
      Kind = Symbol::Kind::DefinedGlobalKind;
    else
      llvm_unreachable("invalid local symbol type");
    S->update(Kind, this, &Sym, Segment);
    return S;
  }
  return Symtab->addDefined(this, &Sym, Segment);
}

void ArchiveFile::parse() {
  // Parse a MemoryBufferRef as an archive file.
  DEBUG(dbgs() << "Parsing library: " << toString(this) << "\n");
  File = CHECK(Archive::create(MB), toString(this));

  // Read the symbol table to construct Lazy symbols.
  int Count = 0;
  for (const Archive::Symbol &Sym : File->symbols()) {
    Symtab->addLazy(this, &Sym);
    ++Count;
  }
  DEBUG(dbgs() << "Read " << Count << " symbols\n");
}

void ArchiveFile::addMember(const Archive::Symbol *Sym) {
  const Archive::Child &C =
      CHECK(Sym->getMember(),
            "could not get the member for symbol " + Sym->getName());

  // Don't try to load the same member twice (this can happen when members
  // mutually reference each other).
  if (!Seen.insert(C.getChildOffset()).second)
    return;

  DEBUG(dbgs() << "loading lazy: " << Sym->getName() << "\n");
  DEBUG(dbgs() << "from archive: " << toString(this) << "\n");

  MemoryBufferRef MB =
      CHECK(C.getMemoryBufferRef(),
            "could not get the buffer for the member defining symbol " +
                Sym->getName());

  if (identify_magic(MB.getBuffer()) != file_magic::wasm_object) {
    error("unknown file type: " + MB.getBufferIdentifier());
    return;
  }

  InputFile *Obj = make<ObjFile>(MB);
  Obj->ParentName = ParentName;
  Symtab->addFile(Obj);
}

// Returns a string in the format of "foo.o" or "foo.a(bar.o)".
std::string lld::toString(const wasm::InputFile *File) {
  if (!File)
    return "<internal>";

  if (File->ParentName.empty())
    return File->getName();

  return (File->ParentName + "(" + File->getName() + ")").str();
}
