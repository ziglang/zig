//===- InputFiles.cpp -----------------------------------------------------===//
//
//                             The LLVM Linker
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//

#include "InputFiles.h"
#include "Error.h"
#include "InputSection.h"
#include "LinkerScript.h"
#include "Memory.h"
#include "SymbolTable.h"
#include "Symbols.h"
#include "SyntheticSections.h"
#include "llvm/ADT/STLExtras.h"
#include "llvm/CodeGen/Analysis.h"
#include "llvm/DebugInfo/DWARF/DWARFContext.h"
#include "llvm/IR/LLVMContext.h"
#include "llvm/IR/Module.h"
#include "llvm/LTO/LTO.h"
#include "llvm/MC/StringTableBuilder.h"
#include "llvm/Object/ELFObjectFile.h"
#include "llvm/Support/Path.h"
#include "llvm/Support/TarWriter.h"
#include "llvm/Support/raw_ostream.h"

using namespace llvm;
using namespace llvm::ELF;
using namespace llvm::object;
using namespace llvm::sys::fs;

using namespace lld;
using namespace lld::elf;

TarWriter *elf::Tar;

InputFile::InputFile(Kind K, MemoryBufferRef M) : MB(M), FileKind(K) {}

namespace {
// In ELF object file all section addresses are zero. If we have multiple
// .text sections (when using -ffunction-section or comdat group) then
// LLVM DWARF parser will not be able to parse .debug_line correctly, unless
// we assign each section some unique address. This callback method assigns
// each section an address equal to its offset in ELF object file.
class ObjectInfo : public LoadedObjectInfoHelper<ObjectInfo> {
public:
  uint64_t getSectionLoadAddress(const object::SectionRef &Sec) const override {
    return static_cast<const ELFSectionRef &>(Sec).getOffset();
  }
};
}

Optional<MemoryBufferRef> elf::readFile(StringRef Path) {
  log(Path);
  auto MBOrErr = MemoryBuffer::getFile(Path);
  if (auto EC = MBOrErr.getError()) {
    error("cannot open " + Path + ": " + EC.message());
    return None;
  }

  std::unique_ptr<MemoryBuffer> &MB = *MBOrErr;
  MemoryBufferRef MBRef = MB->getMemBufferRef();
  make<std::unique_ptr<MemoryBuffer>>(std::move(MB)); // take MB ownership

  if (Tar)
    Tar->append(relativeToRoot(Path), MBRef.getBuffer());
  return MBRef;
}

template <class ELFT> void elf::ObjectFile<ELFT>::initializeDwarfLine() {
  std::unique_ptr<object::ObjectFile> Obj =
      check(object::ObjectFile::createObjectFile(this->MB), toString(this));

  ObjectInfo ObjInfo;
  DWARFContextInMemory Dwarf(*Obj, &ObjInfo);
  DwarfLine.reset(new DWARFDebugLine);
  DWARFDataExtractor LineData(Dwarf.getLineSection(), Config->IsLE,
                              Config->Wordsize);

  // The second parameter is offset in .debug_line section
  // for compilation unit (CU) of interest. We have only one
  // CU (object file), so offset is always 0.
  DwarfLine->getOrParseLineTable(LineData, 0);
}

// Returns source line information for a given offset
// using DWARF debug info.
template <class ELFT>
Optional<DILineInfo> elf::ObjectFile<ELFT>::getDILineInfo(InputSectionBase *S,
                                                          uint64_t Offset) {
  llvm::call_once(InitDwarfLine, [this]() { initializeDwarfLine(); });

  // The offset to CU is 0.
  const DWARFDebugLine::LineTable *Tbl = DwarfLine->getLineTable(0);
  if (!Tbl)
    return None;

  // Use fake address calcuated by adding section file offset and offset in
  // section. See comments for ObjectInfo class.
  DILineInfo Info;
  Tbl->getFileLineInfoForAddress(
      S->getOffsetInFile() + Offset, nullptr,
      DILineInfoSpecifier::FileLineInfoKind::AbsoluteFilePath, Info);
  if (Info.Line == 0)
    return None;
  return Info;
}

// Returns source line information for a given offset
// using DWARF debug info.
template <class ELFT>
std::string elf::ObjectFile<ELFT>::getLineInfo(InputSectionBase *S,
                                               uint64_t Offset) {
  if (Optional<DILineInfo> Info = getDILineInfo(S, Offset))
    return Info->FileName + ":" + std::to_string(Info->Line);
  return "";
}

// Returns "<internal>", "foo.a(bar.o)" or "baz.o".
std::string lld::toString(const InputFile *F) {
  if (!F)
    return "<internal>";

  if (F->ToStringCache.empty()) {
    if (F->ArchiveName.empty())
      F->ToStringCache = F->getName();
    else
      F->ToStringCache = (F->ArchiveName + "(" + F->getName() + ")").str();
  }
  return F->ToStringCache;
}

template <class ELFT>
ELFFileBase<ELFT>::ELFFileBase(Kind K, MemoryBufferRef MB) : InputFile(K, MB) {
  if (ELFT::TargetEndianness == support::little)
    EKind = ELFT::Is64Bits ? ELF64LEKind : ELF32LEKind;
  else
    EKind = ELFT::Is64Bits ? ELF64BEKind : ELF32BEKind;

  EMachine = getObj().getHeader()->e_machine;
  OSABI = getObj().getHeader()->e_ident[llvm::ELF::EI_OSABI];
}

template <class ELFT>
typename ELFT::SymRange ELFFileBase<ELFT>::getGlobalSymbols() {
  return makeArrayRef(Symbols.begin() + FirstNonLocal, Symbols.end());
}

template <class ELFT>
uint32_t ELFFileBase<ELFT>::getSectionIndex(const Elf_Sym &Sym) const {
  return check(getObj().getSectionIndex(&Sym, Symbols, SymtabSHNDX),
               toString(this));
}

template <class ELFT>
void ELFFileBase<ELFT>::initSymtab(ArrayRef<Elf_Shdr> Sections,
                                   const Elf_Shdr *Symtab) {
  FirstNonLocal = Symtab->sh_info;
  Symbols = check(getObj().symbols(Symtab), toString(this));
  if (FirstNonLocal == 0 || FirstNonLocal > Symbols.size())
    fatal(toString(this) + ": invalid sh_info in symbol table");

  StringTable = check(getObj().getStringTableForSymtab(*Symtab, Sections),
                      toString(this));
}

template <class ELFT>
elf::ObjectFile<ELFT>::ObjectFile(MemoryBufferRef M, StringRef ArchiveName)
    : ELFFileBase<ELFT>(Base::ObjectKind, M) {
  this->ArchiveName = ArchiveName;
}

template <class ELFT>
ArrayRef<SymbolBody *> elf::ObjectFile<ELFT>::getLocalSymbols() {
  if (this->SymbolBodies.empty())
    return this->SymbolBodies;
  return makeArrayRef(this->SymbolBodies).slice(1, this->FirstNonLocal - 1);
}

template <class ELFT>
ArrayRef<SymbolBody *> elf::ObjectFile<ELFT>::getSymbols() {
  if (this->SymbolBodies.empty())
    return this->SymbolBodies;
  return makeArrayRef(this->SymbolBodies).slice(1);
}

template <class ELFT>
void elf::ObjectFile<ELFT>::parse(DenseSet<CachedHashStringRef> &ComdatGroups) {
  // Read section and symbol tables.
  initializeSections(ComdatGroups);
  initializeSymbols();
}

// Sections with SHT_GROUP and comdat bits define comdat section groups.
// They are identified and deduplicated by group name. This function
// returns a group name.
template <class ELFT>
StringRef
elf::ObjectFile<ELFT>::getShtGroupSignature(ArrayRef<Elf_Shdr> Sections,
                                            const Elf_Shdr &Sec) {
  // Group signatures are stored as symbol names in object files.
  // sh_info contains a symbol index, so we fetch a symbol and read its name.
  if (this->Symbols.empty())
    this->initSymtab(
        Sections,
        check(object::getSection<ELFT>(Sections, Sec.sh_link), toString(this)));

  const Elf_Sym *Sym = check(
      object::getSymbol<ELFT>(this->Symbols, Sec.sh_info), toString(this));
  StringRef Signature = check(Sym->getName(this->StringTable), toString(this));

  // As a special case, if a symbol is a section symbol and has no name,
  // we use a section name as a signature.
  //
  // Such SHT_GROUP sections are invalid from the perspective of the ELF
  // standard, but GNU gold 1.14 (the neweset version as of July 2017) or
  // older produce such sections as outputs for the -r option, so we need
  // a bug-compatibility.
  if (Signature.empty() && Sym->getType() == STT_SECTION)
    return getSectionName(Sec);
  return Signature;
}

template <class ELFT>
ArrayRef<typename elf::ObjectFile<ELFT>::Elf_Word>
elf::ObjectFile<ELFT>::getShtGroupEntries(const Elf_Shdr &Sec) {
  const ELFFile<ELFT> &Obj = this->getObj();
  ArrayRef<Elf_Word> Entries = check(
      Obj.template getSectionContentsAsArray<Elf_Word>(&Sec), toString(this));
  if (Entries.empty() || Entries[0] != GRP_COMDAT)
    fatal(toString(this) + ": unsupported SHT_GROUP format");
  return Entries.slice(1);
}

template <class ELFT>
bool elf::ObjectFile<ELFT>::shouldMerge(const Elf_Shdr &Sec) {
  // We don't merge sections if -O0 (default is -O1). This makes sometimes
  // the linker significantly faster, although the output will be bigger.
  if (Config->Optimize == 0)
    return false;

  // Do not merge sections if generating a relocatable object. It makes
  // the code simpler because we do not need to update relocation addends
  // to reflect changes introduced by merging. Instead of that we write
  // such "merge" sections into separate OutputSections and keep SHF_MERGE
  // / SHF_STRINGS flags and sh_entsize value to be able to perform merging
  // later during a final linking.
  if (Config->Relocatable)
    return false;

  // A mergeable section with size 0 is useless because they don't have
  // any data to merge. A mergeable string section with size 0 can be
  // argued as invalid because it doesn't end with a null character.
  // We'll avoid a mess by handling them as if they were non-mergeable.
  if (Sec.sh_size == 0)
    return false;

  // Check for sh_entsize. The ELF spec is not clear about the zero
  // sh_entsize. It says that "the member [sh_entsize] contains 0 if
  // the section does not hold a table of fixed-size entries". We know
  // that Rust 1.13 produces a string mergeable section with a zero
  // sh_entsize. Here we just accept it rather than being picky about it.
  uint64_t EntSize = Sec.sh_entsize;
  if (EntSize == 0)
    return false;
  if (Sec.sh_size % EntSize)
    fatal(toString(this) +
          ": SHF_MERGE section size must be a multiple of sh_entsize");

  uint64_t Flags = Sec.sh_flags;
  if (!(Flags & SHF_MERGE))
    return false;
  if (Flags & SHF_WRITE)
    fatal(toString(this) + ": writable SHF_MERGE section is not supported");

  // Don't try to merge if the alignment is larger than the sh_entsize and this
  // is not SHF_STRINGS.
  //
  // Since this is not a SHF_STRINGS, we would need to pad after every entity.
  // It would be equivalent for the producer of the .o to just set a larger
  // sh_entsize.
  if (Flags & SHF_STRINGS)
    return true;

  return Sec.sh_addralign <= EntSize;
}

template <class ELFT>
void elf::ObjectFile<ELFT>::initializeSections(
    DenseSet<CachedHashStringRef> &ComdatGroups) {
  const ELFFile<ELFT> &Obj = this->getObj();

  ArrayRef<Elf_Shdr> ObjSections =
      check(this->getObj().sections(), toString(this));
  uint64_t Size = ObjSections.size();
  this->Sections.resize(Size);
  this->SectionStringTable =
      check(Obj.getSectionStringTable(ObjSections), toString(this));

  for (size_t I = 0, E = ObjSections.size(); I < E; I++) {
    if (this->Sections[I] == &InputSection::Discarded)
      continue;
    const Elf_Shdr &Sec = ObjSections[I];

    // SHF_EXCLUDE'ed sections are discarded by the linker. However,
    // if -r is given, we'll let the final link discard such sections.
    // This is compatible with GNU.
    if ((Sec.sh_flags & SHF_EXCLUDE) && !Config->Relocatable) {
      this->Sections[I] = &InputSection::Discarded;
      continue;
    }

    switch (Sec.sh_type) {
    case SHT_GROUP: {
      // De-duplicate section groups by their signatures.
      StringRef Signature = getShtGroupSignature(ObjSections, Sec);
      bool IsNew = ComdatGroups.insert(CachedHashStringRef(Signature)).second;
      this->Sections[I] = &InputSection::Discarded;

      // If it is a new section group, we want to keep group members.
      // Group leader sections, which contain indices of group members, are
      // discarded because they are useless beyond this point. The only
      // exception is the -r option because in order to produce re-linkable
      // object files, we want to pass through basically everything.
      if (IsNew) {
        if (Config->Relocatable)
          this->Sections[I] = createInputSection(Sec);
        continue;
      }

      // Otherwise, discard group members.
      for (uint32_t SecIndex : getShtGroupEntries(Sec)) {
        if (SecIndex >= Size)
          fatal(toString(this) +
                ": invalid section index in group: " + Twine(SecIndex));
        this->Sections[SecIndex] = &InputSection::Discarded;
      }
      break;
    }
    case SHT_SYMTAB:
      this->initSymtab(ObjSections, &Sec);
      break;
    case SHT_SYMTAB_SHNDX:
      this->SymtabSHNDX =
          check(Obj.getSHNDXTable(Sec, ObjSections), toString(this));
      break;
    case SHT_STRTAB:
    case SHT_NULL:
      break;
    default:
      this->Sections[I] = createInputSection(Sec);
    }

    // .ARM.exidx sections have a reverse dependency on the InputSection they
    // have a SHF_LINK_ORDER dependency, this is identified by the sh_link.
    if (Sec.sh_flags & SHF_LINK_ORDER) {
      if (Sec.sh_link >= this->Sections.size())
        fatal(toString(this) + ": invalid sh_link index: " +
              Twine(Sec.sh_link));
      this->Sections[Sec.sh_link]->DependentSections.push_back(
          this->Sections[I]);
    }
  }
}

template <class ELFT>
InputSectionBase *elf::ObjectFile<ELFT>::getRelocTarget(const Elf_Shdr &Sec) {
  uint32_t Idx = Sec.sh_info;
  if (Idx >= this->Sections.size())
    fatal(toString(this) + ": invalid relocated section index: " + Twine(Idx));
  InputSectionBase *Target = this->Sections[Idx];

  // Strictly speaking, a relocation section must be included in the
  // group of the section it relocates. However, LLVM 3.3 and earlier
  // would fail to do so, so we gracefully handle that case.
  if (Target == &InputSection::Discarded)
    return nullptr;

  if (!Target)
    fatal(toString(this) + ": unsupported relocation reference");
  return Target;
}

// Create a regular InputSection class that has the same contents
// as a given section.
InputSectionBase *toRegularSection(MergeInputSection *Sec) {
  auto *Ret = make<InputSection>(Sec->Flags, Sec->Type, Sec->Alignment,
                                 Sec->Data, Sec->Name);
  Ret->File = Sec->File;
  return Ret;
}

template <class ELFT>
InputSectionBase *
elf::ObjectFile<ELFT>::createInputSection(const Elf_Shdr &Sec) {
  StringRef Name = getSectionName(Sec);

  switch (Sec.sh_type) {
  case SHT_ARM_ATTRIBUTES:
    // FIXME: ARM meta-data section. Retain the first attribute section
    // we see. The eglibc ARM dynamic loaders require the presence of an
    // attribute section for dlopen to work.
    // In a full implementation we would merge all attribute sections.
    if (InX::ARMAttributes == nullptr) {
      InX::ARMAttributes = make<InputSection>(this, &Sec, Name);
      return InX::ARMAttributes;
    }
    return &InputSection::Discarded;
  case SHT_RELA:
  case SHT_REL: {
    // Find the relocation target section and associate this
    // section with it. Target can be discarded, for example
    // if it is a duplicated member of SHT_GROUP section, we
    // do not create or proccess relocatable sections then.
    InputSectionBase *Target = getRelocTarget(Sec);
    if (!Target)
      return nullptr;

    // This section contains relocation information.
    // If -r is given, we do not interpret or apply relocation
    // but just copy relocation sections to output.
    if (Config->Relocatable)
      return make<InputSection>(this, &Sec, Name);

    if (Target->FirstRelocation)
      fatal(toString(this) +
            ": multiple relocation sections to one section are not supported");

    // Mergeable sections with relocations are tricky because relocations
    // need to be taken into account when comparing section contents for
    // merging. It's not worth supporting such mergeable sections because
    // they are rare and it'd complicates the internal design (we usually
    // have to determine if two sections are mergeable early in the link
    // process much before applying relocations). We simply handle mergeable
    // sections with relocations as non-mergeable.
    if (auto *MS = dyn_cast<MergeInputSection>(Target)) {
      Target = toRegularSection(MS);
      this->Sections[Sec.sh_info] = Target;
    }

    size_t NumRelocations;
    if (Sec.sh_type == SHT_RELA) {
      ArrayRef<Elf_Rela> Rels =
          check(this->getObj().relas(&Sec), toString(this));
      Target->FirstRelocation = Rels.begin();
      NumRelocations = Rels.size();
      Target->AreRelocsRela = true;
    } else {
      ArrayRef<Elf_Rel> Rels = check(this->getObj().rels(&Sec), toString(this));
      Target->FirstRelocation = Rels.begin();
      NumRelocations = Rels.size();
      Target->AreRelocsRela = false;
    }
    assert(isUInt<31>(NumRelocations));
    Target->NumRelocations = NumRelocations;

    // Relocation sections processed by the linker are usually removed
    // from the output, so returning `nullptr` for the normal case.
    // However, if -emit-relocs is given, we need to leave them in the output.
    // (Some post link analysis tools need this information.)
    if (Config->EmitRelocs) {
      InputSection *RelocSec = make<InputSection>(this, &Sec, Name);
      // We will not emit relocation section if target was discarded.
      Target->DependentSections.push_back(RelocSec);
      return RelocSec;
    }
    return nullptr;
  }
  }

  // The GNU linker uses .note.GNU-stack section as a marker indicating
  // that the code in the object file does not expect that the stack is
  // executable (in terms of NX bit). If all input files have the marker,
  // the GNU linker adds a PT_GNU_STACK segment to tells the loader to
  // make the stack non-executable. Most object files have this section as
  // of 2017.
  //
  // But making the stack non-executable is a norm today for security
  // reasons. Failure to do so may result in a serious security issue.
  // Therefore, we make LLD always add PT_GNU_STACK unless it is
  // explicitly told to do otherwise (by -z execstack). Because the stack
  // executable-ness is controlled solely by command line options,
  // .note.GNU-stack sections are simply ignored.
  if (Name == ".note.GNU-stack")
    return &InputSection::Discarded;

  // Split stacks is a feature to support a discontiguous stack. At least
  // as of 2017, it seems that the feature is not being used widely.
  // Only GNU gold supports that. We don't. For the details about that,
  // see https://gcc.gnu.org/wiki/SplitStacks
  if (Name == ".note.GNU-split-stack") {
    error(toString(this) +
          ": object file compiled with -fsplit-stack is not supported");
    return &InputSection::Discarded;
  }

  if (Config->Strip != StripPolicy::None && Name.startswith(".debug"))
    return &InputSection::Discarded;

  // If -gdb-index is given, LLD creates .gdb_index section, and that
  // section serves the same purpose as .debug_gnu_pub{names,types} sections.
  // If that's the case, we want to eliminate .debug_gnu_pub{names,types}
  // because they are redundant and can waste large amount of disk space
  // (for example, they are about 400 MiB in total for a clang debug build.)
  if (Config->GdbIndex &&
      (Name == ".debug_gnu_pubnames" || Name == ".debug_gnu_pubtypes"))
    return &InputSection::Discarded;

  // The linkonce feature is a sort of proto-comdat. Some glibc i386 object
  // files contain definitions of symbol "__x86.get_pc_thunk.bx" in linkonce
  // sections. Drop those sections to avoid duplicate symbol errors.
  // FIXME: This is glibc PR20543, we should remove this hack once that has been
  // fixed for a while.
  if (Name.startswith(".gnu.linkonce."))
    return &InputSection::Discarded;

  // The linker merges EH (exception handling) frames and creates a
  // .eh_frame_hdr section for runtime. So we handle them with a special
  // class. For relocatable outputs, they are just passed through.
  if (Name == ".eh_frame" && !Config->Relocatable)
    return make<EhInputSection>(this, &Sec, Name);

  if (shouldMerge(Sec))
    return make<MergeInputSection>(this, &Sec, Name);
  return make<InputSection>(this, &Sec, Name);
}

template <class ELFT>
StringRef elf::ObjectFile<ELFT>::getSectionName(const Elf_Shdr &Sec) {
  return check(this->getObj().getSectionName(&Sec, SectionStringTable),
               toString(this));
}

template <class ELFT> void elf::ObjectFile<ELFT>::initializeSymbols() {
  SymbolBodies.reserve(this->Symbols.size());
  for (const Elf_Sym &Sym : this->Symbols)
    SymbolBodies.push_back(createSymbolBody(&Sym));
}

template <class ELFT>
InputSectionBase *elf::ObjectFile<ELFT>::getSection(const Elf_Sym &Sym) const {
  uint32_t Index = this->getSectionIndex(Sym);
  if (Index >= this->Sections.size())
    fatal(toString(this) + ": invalid section index: " + Twine(Index));
  InputSectionBase *S = this->Sections[Index];

  // We found that GNU assembler 2.17.50 [FreeBSD] 2007-07-03 could
  // generate broken objects. STT_SECTION/STT_NOTYPE symbols can be
  // associated with SHT_REL[A]/SHT_SYMTAB/SHT_STRTAB sections.
  // In this case it is fine for section to be null here as we do not
  // allocate sections of these types.
  if (!S) {
    if (Index == 0 || Sym.getType() == STT_SECTION ||
        Sym.getType() == STT_NOTYPE)
      return nullptr;
    fatal(toString(this) + ": invalid section index: " + Twine(Index));
  }

  if (S == &InputSection::Discarded)
    return S;
  return S->Repl;
}

template <class ELFT>
SymbolBody *elf::ObjectFile<ELFT>::createSymbolBody(const Elf_Sym *Sym) {
  int Binding = Sym->getBinding();
  InputSectionBase *Sec = getSection(*Sym);

  uint8_t StOther = Sym->st_other;
  uint8_t Type = Sym->getType();
  uint64_t Value = Sym->st_value;
  uint64_t Size = Sym->st_size;

  if (Binding == STB_LOCAL) {
    if (Sym->getType() == STT_FILE)
      SourceFile = check(Sym->getName(this->StringTable), toString(this));

    if (this->StringTable.size() <= Sym->st_name)
      fatal(toString(this) + ": invalid symbol name offset");

    StringRefZ Name = this->StringTable.data() + Sym->st_name;
    if (Sym->st_shndx == SHN_UNDEF)
      return make<Undefined>(Name, /*IsLocal=*/true, StOther, Type, this);

    return make<DefinedRegular>(Name, /*IsLocal=*/true, StOther, Type, Value,
                                Size, Sec, this);
  }

  StringRef Name = check(Sym->getName(this->StringTable), toString(this));

  switch (Sym->st_shndx) {
  case SHN_UNDEF:
    return elf::Symtab<ELFT>::X
        ->addUndefined(Name, /*IsLocal=*/false, Binding, StOther, Type,
                       /*CanOmitFromDynSym=*/false, this)
        ->body();
  case SHN_COMMON:
    if (Value == 0 || Value >= UINT32_MAX)
      fatal(toString(this) + ": common symbol '" + Name +
            "' has invalid alignment: " + Twine(Value));
    return elf::Symtab<ELFT>::X
        ->addCommon(Name, Size, Value, Binding, StOther, Type, this)
        ->body();
  }

  switch (Binding) {
  default:
    fatal(toString(this) + ": unexpected binding: " + Twine(Binding));
  case STB_GLOBAL:
  case STB_WEAK:
  case STB_GNU_UNIQUE:
    if (Sec == &InputSection::Discarded)
      return elf::Symtab<ELFT>::X
          ->addUndefined(Name, /*IsLocal=*/false, Binding, StOther, Type,
                         /*CanOmitFromDynSym=*/false, this)
          ->body();
    return elf::Symtab<ELFT>::X
        ->addRegular(Name, StOther, Type, Value, Size, Binding, Sec, this)
        ->body();
  }
}

ArchiveFile::ArchiveFile(std::unique_ptr<Archive> &&File)
    : InputFile(ArchiveKind, File->getMemoryBufferRef()),
      File(std::move(File)) {}

template <class ELFT> void ArchiveFile::parse() {
  Symbols.reserve(File->getNumberOfSymbols());
  for (const Archive::Symbol &Sym : File->symbols())
    Symbols.push_back(Symtab<ELFT>::X->addLazyArchive(this, Sym));
}

// Returns a buffer pointing to a member file containing a given symbol.
std::pair<MemoryBufferRef, uint64_t>
ArchiveFile::getMember(const Archive::Symbol *Sym) {
  Archive::Child C =
      check(Sym->getMember(), toString(this) +
                                  ": could not get the member for symbol " +
                                  Sym->getName());

  if (!Seen.insert(C.getChildOffset()).second)
    return {MemoryBufferRef(), 0};

  MemoryBufferRef Ret =
      check(C.getMemoryBufferRef(),
            toString(this) +
                ": could not get the buffer for the member defining symbol " +
                Sym->getName());

  if (C.getParent()->isThin() && Tar)
    Tar->append(relativeToRoot(check(C.getFullName(), toString(this))),
                Ret.getBuffer());
  if (C.getParent()->isThin())
    return {Ret, 0};
  return {Ret, C.getChildOffset()};
}

template <class ELFT>
SharedFile<ELFT>::SharedFile(MemoryBufferRef M, StringRef DefaultSoName)
    : ELFFileBase<ELFT>(Base::SharedKind, M), SoName(DefaultSoName),
      AsNeeded(Config->AsNeeded) {}

template <class ELFT>
const typename ELFT::Shdr *
SharedFile<ELFT>::getSection(const Elf_Sym &Sym) const {
  return check(
      this->getObj().getSection(&Sym, this->Symbols, this->SymtabSHNDX),
      toString(this));
}

// Partially parse the shared object file so that we can call
// getSoName on this object.
template <class ELFT> void SharedFile<ELFT>::parseSoName() {
  const Elf_Shdr *DynamicSec = nullptr;
  const ELFFile<ELFT> Obj = this->getObj();
  ArrayRef<Elf_Shdr> Sections = check(Obj.sections(), toString(this));

  // Search for .dynsym, .dynamic, .symtab, .gnu.version and .gnu.version_d.
  for (const Elf_Shdr &Sec : Sections) {
    switch (Sec.sh_type) {
    default:
      continue;
    case SHT_DYNSYM:
      this->initSymtab(Sections, &Sec);
      break;
    case SHT_DYNAMIC:
      DynamicSec = &Sec;
      break;
    case SHT_SYMTAB_SHNDX:
      this->SymtabSHNDX =
          check(Obj.getSHNDXTable(Sec, Sections), toString(this));
      break;
    case SHT_GNU_versym:
      this->VersymSec = &Sec;
      break;
    case SHT_GNU_verdef:
      this->VerdefSec = &Sec;
      break;
    }
  }

  if (this->VersymSec && this->Symbols.empty())
    error("SHT_GNU_versym should be associated with symbol table");

  // Search for a DT_SONAME tag to initialize this->SoName.
  if (!DynamicSec)
    return;
  ArrayRef<Elf_Dyn> Arr =
      check(Obj.template getSectionContentsAsArray<Elf_Dyn>(DynamicSec),
            toString(this));
  for (const Elf_Dyn &Dyn : Arr) {
    if (Dyn.d_tag == DT_SONAME) {
      uint64_t Val = Dyn.getVal();
      if (Val >= this->StringTable.size())
        fatal(toString(this) + ": invalid DT_SONAME entry");
      SoName = this->StringTable.data() + Val;
      return;
    }
  }
}

// Parse the version definitions in the object file if present. Returns a vector
// whose nth element contains a pointer to the Elf_Verdef for version identifier
// n. Version identifiers that are not definitions map to nullptr. The array
// always has at least length 1.
template <class ELFT>
std::vector<const typename ELFT::Verdef *>
SharedFile<ELFT>::parseVerdefs(const Elf_Versym *&Versym) {
  std::vector<const Elf_Verdef *> Verdefs(1);
  // We only need to process symbol versions for this DSO if it has both a
  // versym and a verdef section, which indicates that the DSO contains symbol
  // version definitions.
  if (!VersymSec || !VerdefSec)
    return Verdefs;

  // The location of the first global versym entry.
  const char *Base = this->MB.getBuffer().data();
  Versym = reinterpret_cast<const Elf_Versym *>(Base + VersymSec->sh_offset) +
           this->FirstNonLocal;

  // We cannot determine the largest verdef identifier without inspecting
  // every Elf_Verdef, but both bfd and gold assign verdef identifiers
  // sequentially starting from 1, so we predict that the largest identifier
  // will be VerdefCount.
  unsigned VerdefCount = VerdefSec->sh_info;
  Verdefs.resize(VerdefCount + 1);

  // Build the Verdefs array by following the chain of Elf_Verdef objects
  // from the start of the .gnu.version_d section.
  const char *Verdef = Base + VerdefSec->sh_offset;
  for (unsigned I = 0; I != VerdefCount; ++I) {
    auto *CurVerdef = reinterpret_cast<const Elf_Verdef *>(Verdef);
    Verdef += CurVerdef->vd_next;
    unsigned VerdefIndex = CurVerdef->vd_ndx;
    if (Verdefs.size() <= VerdefIndex)
      Verdefs.resize(VerdefIndex + 1);
    Verdefs[VerdefIndex] = CurVerdef;
  }

  return Verdefs;
}

// Fully parse the shared object file. This must be called after parseSoName().
template <class ELFT> void SharedFile<ELFT>::parseRest() {
  // Create mapping from version identifiers to Elf_Verdef entries.
  const Elf_Versym *Versym = nullptr;
  std::vector<const Elf_Verdef *> Verdefs = parseVerdefs(Versym);

  Elf_Sym_Range Syms = this->getGlobalSymbols();
  for (const Elf_Sym &Sym : Syms) {
    unsigned VersymIndex = 0;
    if (Versym) {
      VersymIndex = Versym->vs_index;
      ++Versym;
    }
    bool Hidden = VersymIndex & VERSYM_HIDDEN;
    VersymIndex = VersymIndex & ~VERSYM_HIDDEN;

    StringRef Name = check(Sym.getName(this->StringTable), toString(this));
    if (Sym.isUndefined()) {
      Undefs.push_back(Name);
      continue;
    }

    // Ignore local symbols.
    if (Versym && VersymIndex == VER_NDX_LOCAL)
      continue;

    const Elf_Verdef *V =
        VersymIndex == VER_NDX_GLOBAL ? nullptr : Verdefs[VersymIndex];

    if (!Hidden)
      elf::Symtab<ELFT>::X->addShared(this, Name, Sym, V);

    // Also add the symbol with the versioned name to handle undefined symbols
    // with explicit versions.
    if (V) {
      StringRef VerName = this->StringTable.data() + V->getAux()->vda_name;
      Name = Saver.save(Name + "@" + VerName);
      elf::Symtab<ELFT>::X->addShared(this, Name, Sym, V);
    }
  }
}

static ELFKind getBitcodeELFKind(const Triple &T) {
  if (T.isLittleEndian())
    return T.isArch64Bit() ? ELF64LEKind : ELF32LEKind;
  return T.isArch64Bit() ? ELF64BEKind : ELF32BEKind;
}

static uint8_t getBitcodeMachineKind(StringRef Path, const Triple &T) {
  switch (T.getArch()) {
  case Triple::aarch64:
    return EM_AARCH64;
  case Triple::arm:
  case Triple::thumb:
    return EM_ARM;
  case Triple::avr:
    return EM_AVR;
  case Triple::mips:
  case Triple::mipsel:
  case Triple::mips64:
  case Triple::mips64el:
    return EM_MIPS;
  case Triple::ppc:
    return EM_PPC;
  case Triple::ppc64:
    return EM_PPC64;
  case Triple::x86:
    return T.isOSIAMCU() ? EM_IAMCU : EM_386;
  case Triple::x86_64:
    return EM_X86_64;
  default:
    fatal(Path + ": could not infer e_machine from bitcode target triple " +
          T.str());
  }
}

BitcodeFile::BitcodeFile(MemoryBufferRef MB, StringRef ArchiveName,
                         uint64_t OffsetInArchive)
    : InputFile(BitcodeKind, MB) {
  this->ArchiveName = ArchiveName;

  // Here we pass a new MemoryBufferRef which is identified by ArchiveName
  // (the fully resolved path of the archive) + member name + offset of the
  // member in the archive.
  // ThinLTO uses the MemoryBufferRef identifier to access its internal
  // data structures and if two archives define two members with the same name,
  // this causes a collision which result in only one of the objects being
  // taken into consideration at LTO time (which very likely causes undefined
  // symbols later in the link stage).
  MemoryBufferRef MBRef(MB.getBuffer(),
                        Saver.save(ArchiveName + MB.getBufferIdentifier() +
                                   utostr(OffsetInArchive)));
  Obj = check(lto::InputFile::create(MBRef), toString(this));

  Triple T(Obj->getTargetTriple());
  EKind = getBitcodeELFKind(T);
  EMachine = getBitcodeMachineKind(MB.getBufferIdentifier(), T);
}

static uint8_t mapVisibility(GlobalValue::VisibilityTypes GvVisibility) {
  switch (GvVisibility) {
  case GlobalValue::DefaultVisibility:
    return STV_DEFAULT;
  case GlobalValue::HiddenVisibility:
    return STV_HIDDEN;
  case GlobalValue::ProtectedVisibility:
    return STV_PROTECTED;
  }
  llvm_unreachable("unknown visibility");
}

template <class ELFT>
static Symbol *createBitcodeSymbol(const std::vector<bool> &KeptComdats,
                                   const lto::InputFile::Symbol &ObjSym,
                                   BitcodeFile *F) {
  StringRef NameRef = Saver.save(ObjSym.getName());
  uint32_t Binding = ObjSym.isWeak() ? STB_WEAK : STB_GLOBAL;

  uint8_t Type = ObjSym.isTLS() ? STT_TLS : STT_NOTYPE;
  uint8_t Visibility = mapVisibility(ObjSym.getVisibility());
  bool CanOmitFromDynSym = ObjSym.canBeOmittedFromSymbolTable();

  int C = ObjSym.getComdatIndex();
  if (C != -1 && !KeptComdats[C])
    return Symtab<ELFT>::X->addUndefined(NameRef, /*IsLocal=*/false, Binding,
                                         Visibility, Type, CanOmitFromDynSym,
                                         F);

  if (ObjSym.isUndefined())
    return Symtab<ELFT>::X->addUndefined(NameRef, /*IsLocal=*/false, Binding,
                                         Visibility, Type, CanOmitFromDynSym,
                                         F);

  if (ObjSym.isCommon())
    return Symtab<ELFT>::X->addCommon(NameRef, ObjSym.getCommonSize(),
                                      ObjSym.getCommonAlignment(), Binding,
                                      Visibility, STT_OBJECT, F);

  return Symtab<ELFT>::X->addBitcode(NameRef, Binding, Visibility, Type,
                                     CanOmitFromDynSym, F);
}

template <class ELFT>
void BitcodeFile::parse(DenseSet<CachedHashStringRef> &ComdatGroups) {
  std::vector<bool> KeptComdats;
  for (StringRef S : Obj->getComdatTable())
    KeptComdats.push_back(ComdatGroups.insert(CachedHashStringRef(S)).second);

  for (const lto::InputFile::Symbol &ObjSym : Obj->symbols())
    Symbols.push_back(createBitcodeSymbol<ELFT>(KeptComdats, ObjSym, this));
}

static ELFKind getELFKind(MemoryBufferRef MB) {
  unsigned char Size;
  unsigned char Endian;
  std::tie(Size, Endian) = getElfArchType(MB.getBuffer());

  if (Endian != ELFDATA2LSB && Endian != ELFDATA2MSB)
    fatal(MB.getBufferIdentifier() + ": invalid data encoding");
  if (Size != ELFCLASS32 && Size != ELFCLASS64)
    fatal(MB.getBufferIdentifier() + ": invalid file class");

  size_t BufSize = MB.getBuffer().size();
  if ((Size == ELFCLASS32 && BufSize < sizeof(Elf32_Ehdr)) ||
      (Size == ELFCLASS64 && BufSize < sizeof(Elf64_Ehdr)))
    fatal(MB.getBufferIdentifier() + ": file is too short");

  if (Size == ELFCLASS32)
    return (Endian == ELFDATA2LSB) ? ELF32LEKind : ELF32BEKind;
  return (Endian == ELFDATA2LSB) ? ELF64LEKind : ELF64BEKind;
}

template <class ELFT> void BinaryFile::parse() {
  ArrayRef<uint8_t> Data = toArrayRef(MB.getBuffer());
  auto *Section =
      make<InputSection>(SHF_ALLOC | SHF_WRITE, SHT_PROGBITS, 8, Data, ".data");
  Sections.push_back(Section);

  // For each input file foo that is embedded to a result as a binary
  // blob, we define _binary_foo_{start,end,size} symbols, so that
  // user programs can access blobs by name. Non-alphanumeric
  // characters in a filename are replaced with underscore.
  std::string S = "_binary_" + MB.getBufferIdentifier().str();
  for (size_t I = 0; I < S.size(); ++I)
    if (!isalnum(S[I]))
      S[I] = '_';

  elf::Symtab<ELFT>::X->addRegular(Saver.save(S + "_start"), STV_DEFAULT,
                                   STT_OBJECT, 0, 0, STB_GLOBAL, Section,
                                   nullptr);
  elf::Symtab<ELFT>::X->addRegular(Saver.save(S + "_end"), STV_DEFAULT,
                                   STT_OBJECT, Data.size(), 0, STB_GLOBAL,
                                   Section, nullptr);
  elf::Symtab<ELFT>::X->addRegular(Saver.save(S + "_size"), STV_DEFAULT,
                                   STT_OBJECT, Data.size(), 0, STB_GLOBAL,
                                   nullptr, nullptr);
}

static bool isBitcode(MemoryBufferRef MB) {
  using namespace sys::fs;
  return identify_magic(MB.getBuffer()) == file_magic::bitcode;
}

InputFile *elf::createObjectFile(MemoryBufferRef MB, StringRef ArchiveName,
                                 uint64_t OffsetInArchive) {
  if (isBitcode(MB))
    return make<BitcodeFile>(MB, ArchiveName, OffsetInArchive);

  switch (getELFKind(MB)) {
  case ELF32LEKind:
    return make<ObjectFile<ELF32LE>>(MB, ArchiveName);
  case ELF32BEKind:
    return make<ObjectFile<ELF32BE>>(MB, ArchiveName);
  case ELF64LEKind:
    return make<ObjectFile<ELF64LE>>(MB, ArchiveName);
  case ELF64BEKind:
    return make<ObjectFile<ELF64BE>>(MB, ArchiveName);
  default:
    llvm_unreachable("getELFKind");
  }
}

InputFile *elf::createSharedFile(MemoryBufferRef MB, StringRef DefaultSoName) {
  switch (getELFKind(MB)) {
  case ELF32LEKind:
    return make<SharedFile<ELF32LE>>(MB, DefaultSoName);
  case ELF32BEKind:
    return make<SharedFile<ELF32BE>>(MB, DefaultSoName);
  case ELF64LEKind:
    return make<SharedFile<ELF64LE>>(MB, DefaultSoName);
  case ELF64BEKind:
    return make<SharedFile<ELF64BE>>(MB, DefaultSoName);
  default:
    llvm_unreachable("getELFKind");
  }
}

MemoryBufferRef LazyObjectFile::getBuffer() {
  if (Seen)
    return MemoryBufferRef();
  Seen = true;
  return MB;
}

InputFile *LazyObjectFile::fetch() {
  MemoryBufferRef MBRef = getBuffer();
  if (MBRef.getBuffer().empty())
    return nullptr;
  return createObjectFile(MBRef, ArchiveName, OffsetInArchive);
}

template <class ELFT> void LazyObjectFile::parse() {
  for (StringRef Sym : getSymbols())
    Symtab<ELFT>::X->addLazyObject(Sym, *this);
}

template <class ELFT> std::vector<StringRef> LazyObjectFile::getElfSymbols() {
  typedef typename ELFT::Shdr Elf_Shdr;
  typedef typename ELFT::Sym Elf_Sym;
  typedef typename ELFT::SymRange Elf_Sym_Range;

  const ELFFile<ELFT> Obj(this->MB.getBuffer());
  ArrayRef<Elf_Shdr> Sections = check(Obj.sections(), toString(this));
  for (const Elf_Shdr &Sec : Sections) {
    if (Sec.sh_type != SHT_SYMTAB)
      continue;

    Elf_Sym_Range Syms = check(Obj.symbols(&Sec), toString(this));
    uint32_t FirstNonLocal = Sec.sh_info;
    StringRef StringTable =
        check(Obj.getStringTableForSymtab(Sec, Sections), toString(this));
    std::vector<StringRef> V;

    for (const Elf_Sym &Sym : Syms.slice(FirstNonLocal))
      if (Sym.st_shndx != SHN_UNDEF)
        V.push_back(check(Sym.getName(StringTable), toString(this)));
    return V;
  }
  return {};
}

std::vector<StringRef> LazyObjectFile::getBitcodeSymbols() {
  std::unique_ptr<lto::InputFile> Obj =
      check(lto::InputFile::create(this->MB), toString(this));
  std::vector<StringRef> V;
  for (const lto::InputFile::Symbol &Sym : Obj->symbols())
    if (!Sym.isUndefined())
      V.push_back(Saver.save(Sym.getName()));
  return V;
}

// Returns a vector of globally-visible defined symbol names.
std::vector<StringRef> LazyObjectFile::getSymbols() {
  if (isBitcode(this->MB))
    return getBitcodeSymbols();

  switch (getELFKind(this->MB)) {
  case ELF32LEKind:
    return getElfSymbols<ELF32LE>();
  case ELF32BEKind:
    return getElfSymbols<ELF32BE>();
  case ELF64LEKind:
    return getElfSymbols<ELF64LE>();
  case ELF64BEKind:
    return getElfSymbols<ELF64BE>();
  default:
    llvm_unreachable("getELFKind");
  }
}

template void ArchiveFile::parse<ELF32LE>();
template void ArchiveFile::parse<ELF32BE>();
template void ArchiveFile::parse<ELF64LE>();
template void ArchiveFile::parse<ELF64BE>();

template void BitcodeFile::parse<ELF32LE>(DenseSet<CachedHashStringRef> &);
template void BitcodeFile::parse<ELF32BE>(DenseSet<CachedHashStringRef> &);
template void BitcodeFile::parse<ELF64LE>(DenseSet<CachedHashStringRef> &);
template void BitcodeFile::parse<ELF64BE>(DenseSet<CachedHashStringRef> &);

template void LazyObjectFile::parse<ELF32LE>();
template void LazyObjectFile::parse<ELF32BE>();
template void LazyObjectFile::parse<ELF64LE>();
template void LazyObjectFile::parse<ELF64BE>();

template class elf::ELFFileBase<ELF32LE>;
template class elf::ELFFileBase<ELF32BE>;
template class elf::ELFFileBase<ELF64LE>;
template class elf::ELFFileBase<ELF64BE>;

template class elf::ObjectFile<ELF32LE>;
template class elf::ObjectFile<ELF32BE>;
template class elf::ObjectFile<ELF64LE>;
template class elf::ObjectFile<ELF64BE>;

template class elf::SharedFile<ELF32LE>;
template class elf::SharedFile<ELF32BE>;
template class elf::SharedFile<ELF64LE>;
template class elf::SharedFile<ELF64BE>;

template void BinaryFile::parse<ELF32LE>();
template void BinaryFile::parse<ELF32BE>();
template void BinaryFile::parse<ELF64LE>();
template void BinaryFile::parse<ELF64BE>();
