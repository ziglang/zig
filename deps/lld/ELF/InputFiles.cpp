//===- InputFiles.cpp -----------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "InputFiles.h"
#include "Driver.h"
#include "InputSection.h"
#include "LinkerScript.h"
#include "SymbolTable.h"
#include "Symbols.h"
#include "SyntheticSections.h"
#include "lld/Common/ErrorHandler.h"
#include "lld/Common/Memory.h"
#include "llvm/ADT/STLExtras.h"
#include "llvm/CodeGen/Analysis.h"
#include "llvm/DebugInfo/DWARF/DWARFContext.h"
#include "llvm/IR/LLVMContext.h"
#include "llvm/IR/Module.h"
#include "llvm/LTO/LTO.h"
#include "llvm/MC/StringTableBuilder.h"
#include "llvm/Object/ELFObjectFile.h"
#include "llvm/Support/ARMAttributeParser.h"
#include "llvm/Support/ARMBuildAttributes.h"
#include "llvm/Support/Endian.h"
#include "llvm/Support/Path.h"
#include "llvm/Support/TarWriter.h"
#include "llvm/Support/raw_ostream.h"

using namespace llvm;
using namespace llvm::ELF;
using namespace llvm::object;
using namespace llvm::sys;
using namespace llvm::sys::fs;
using namespace llvm::support::endian;

using namespace lld;
using namespace lld::elf;

bool InputFile::isInGroup;
uint32_t InputFile::nextGroupId;
std::vector<BinaryFile *> elf::binaryFiles;
std::vector<BitcodeFile *> elf::bitcodeFiles;
std::vector<LazyObjFile *> elf::lazyObjFiles;
std::vector<InputFile *> elf::objectFiles;
std::vector<SharedFile *> elf::sharedFiles;

std::unique_ptr<TarWriter> elf::tar;

static ELFKind getELFKind(MemoryBufferRef mb, StringRef archiveName) {
  unsigned char size;
  unsigned char endian;
  std::tie(size, endian) = getElfArchType(mb.getBuffer());

  auto report = [&](StringRef msg) {
    StringRef filename = mb.getBufferIdentifier();
    if (archiveName.empty())
      fatal(filename + ": " + msg);
    else
      fatal(archiveName + "(" + filename + "): " + msg);
  };

  if (!mb.getBuffer().startswith(ElfMagic))
    report("not an ELF file");
  if (endian != ELFDATA2LSB && endian != ELFDATA2MSB)
    report("corrupted ELF file: invalid data encoding");
  if (size != ELFCLASS32 && size != ELFCLASS64)
    report("corrupted ELF file: invalid file class");

  size_t bufSize = mb.getBuffer().size();
  if ((size == ELFCLASS32 && bufSize < sizeof(Elf32_Ehdr)) ||
      (size == ELFCLASS64 && bufSize < sizeof(Elf64_Ehdr)))
    report("corrupted ELF file: file is too short");

  if (size == ELFCLASS32)
    return (endian == ELFDATA2LSB) ? ELF32LEKind : ELF32BEKind;
  return (endian == ELFDATA2LSB) ? ELF64LEKind : ELF64BEKind;
}

InputFile::InputFile(Kind k, MemoryBufferRef m)
    : mb(m), groupId(nextGroupId), fileKind(k) {
  // All files within the same --{start,end}-group get the same group ID.
  // Otherwise, a new file will get a new group ID.
  if (!isInGroup)
    ++nextGroupId;
}

Optional<MemoryBufferRef> elf::readFile(StringRef path) {
  // The --chroot option changes our virtual root directory.
  // This is useful when you are dealing with files created by --reproduce.
  if (!config->chroot.empty() && path.startswith("/"))
    path = saver.save(config->chroot + path);

  log(path);

  auto mbOrErr = MemoryBuffer::getFile(path, -1, false);
  if (auto ec = mbOrErr.getError()) {
    error("cannot open " + path + ": " + ec.message());
    return None;
  }

  std::unique_ptr<MemoryBuffer> &mb = *mbOrErr;
  MemoryBufferRef mbref = mb->getMemBufferRef();
  make<std::unique_ptr<MemoryBuffer>>(std::move(mb)); // take MB ownership

  if (tar)
    tar->append(relativeToRoot(path), mbref.getBuffer());
  return mbref;
}

// All input object files must be for the same architecture
// (e.g. it does not make sense to link x86 object files with
// MIPS object files.) This function checks for that error.
static bool isCompatible(InputFile *file) {
  if (!file->isElf() && !isa<BitcodeFile>(file))
    return true;

  if (file->ekind == config->ekind && file->emachine == config->emachine) {
    if (config->emachine != EM_MIPS)
      return true;
    if (isMipsN32Abi(file) == config->mipsN32Abi)
      return true;
  }

  if (!config->emulation.empty()) {
    error(toString(file) + " is incompatible with " + config->emulation);
  } else {
    InputFile *existing;
    if (!objectFiles.empty())
      existing = objectFiles[0];
    else if (!sharedFiles.empty())
      existing = sharedFiles[0];
    else
      existing = bitcodeFiles[0];

    error(toString(file) + " is incompatible with " + toString(existing));
  }

  return false;
}

template <class ELFT> static void doParseFile(InputFile *file) {
  if (!isCompatible(file))
    return;

  // Binary file
  if (auto *f = dyn_cast<BinaryFile>(file)) {
    binaryFiles.push_back(f);
    f->parse();
    return;
  }

  // .a file
  if (auto *f = dyn_cast<ArchiveFile>(file)) {
    f->parse();
    return;
  }

  // Lazy object file
  if (auto *f = dyn_cast<LazyObjFile>(file)) {
    lazyObjFiles.push_back(f);
    f->parse<ELFT>();
    return;
  }

  if (config->trace)
    message(toString(file));

  // .so file
  if (auto *f = dyn_cast<SharedFile>(file)) {
    f->parse<ELFT>();
    return;
  }

  // LLVM bitcode file
  if (auto *f = dyn_cast<BitcodeFile>(file)) {
    bitcodeFiles.push_back(f);
    f->parse<ELFT>();
    return;
  }

  // Regular object file
  objectFiles.push_back(file);
  cast<ObjFile<ELFT>>(file)->parse();
}

// Add symbols in File to the symbol table.
void elf::parseFile(InputFile *file) {
  switch (config->ekind) {
  case ELF32LEKind:
    doParseFile<ELF32LE>(file);
    return;
  case ELF32BEKind:
    doParseFile<ELF32BE>(file);
    return;
  case ELF64LEKind:
    doParseFile<ELF64LE>(file);
    return;
  case ELF64BEKind:
    doParseFile<ELF64BE>(file);
    return;
  default:
    llvm_unreachable("unknown ELFT");
  }
}

// Concatenates arguments to construct a string representing an error location.
static std::string createFileLineMsg(StringRef path, unsigned line) {
  std::string filename = path::filename(path);
  std::string lineno = ":" + std::to_string(line);
  if (filename == path)
    return filename + lineno;
  return filename + lineno + " (" + path.str() + lineno + ")";
}

template <class ELFT>
static std::string getSrcMsgAux(ObjFile<ELFT> &file, const Symbol &sym,
                                InputSectionBase &sec, uint64_t offset) {
  // In DWARF, functions and variables are stored to different places.
  // First, lookup a function for a given offset.
  if (Optional<DILineInfo> info = file.getDILineInfo(&sec, offset))
    return createFileLineMsg(info->FileName, info->Line);

  // If it failed, lookup again as a variable.
  if (Optional<std::pair<std::string, unsigned>> fileLine =
          file.getVariableLoc(sym.getName()))
    return createFileLineMsg(fileLine->first, fileLine->second);

  // File.sourceFile contains STT_FILE symbol, and that is a last resort.
  return file.sourceFile;
}

std::string InputFile::getSrcMsg(const Symbol &sym, InputSectionBase &sec,
                                 uint64_t offset) {
  if (kind() != ObjKind)
    return "";
  switch (config->ekind) {
  default:
    llvm_unreachable("Invalid kind");
  case ELF32LEKind:
    return getSrcMsgAux(cast<ObjFile<ELF32LE>>(*this), sym, sec, offset);
  case ELF32BEKind:
    return getSrcMsgAux(cast<ObjFile<ELF32BE>>(*this), sym, sec, offset);
  case ELF64LEKind:
    return getSrcMsgAux(cast<ObjFile<ELF64LE>>(*this), sym, sec, offset);
  case ELF64BEKind:
    return getSrcMsgAux(cast<ObjFile<ELF64BE>>(*this), sym, sec, offset);
  }
}

template <class ELFT> void ObjFile<ELFT>::initializeDwarf() {
  dwarf = llvm::make_unique<DWARFContext>(make_unique<LLDDwarfObj<ELFT>>(this));
  for (std::unique_ptr<DWARFUnit> &cu : dwarf->compile_units()) {
    auto report = [](Error err) {
      handleAllErrors(std::move(err),
                      [](ErrorInfoBase &info) { warn(info.message()); });
    };
    Expected<const DWARFDebugLine::LineTable *> expectedLT =
        dwarf->getLineTableForUnit(cu.get(), report);
    const DWARFDebugLine::LineTable *lt = nullptr;
    if (expectedLT)
      lt = *expectedLT;
    else
      report(expectedLT.takeError());
    if (!lt)
      continue;
    lineTables.push_back(lt);

    // Loop over variable records and insert them to variableLoc.
    for (const auto &entry : cu->dies()) {
      DWARFDie die(cu.get(), &entry);
      // Skip all tags that are not variables.
      if (die.getTag() != dwarf::DW_TAG_variable)
        continue;

      // Skip if a local variable because we don't need them for generating
      // error messages. In general, only non-local symbols can fail to be
      // linked.
      if (!dwarf::toUnsigned(die.find(dwarf::DW_AT_external), 0))
        continue;

      // Get the source filename index for the variable.
      unsigned file = dwarf::toUnsigned(die.find(dwarf::DW_AT_decl_file), 0);
      if (!lt->hasFileAtIndex(file))
        continue;

      // Get the line number on which the variable is declared.
      unsigned line = dwarf::toUnsigned(die.find(dwarf::DW_AT_decl_line), 0);

      // Here we want to take the variable name to add it into variableLoc.
      // Variable can have regular and linkage name associated. At first, we try
      // to get linkage name as it can be different, for example when we have
      // two variables in different namespaces of the same object. Use common
      // name otherwise, but handle the case when it also absent in case if the
      // input object file lacks some debug info.
      StringRef name =
          dwarf::toString(die.find(dwarf::DW_AT_linkage_name),
                          dwarf::toString(die.find(dwarf::DW_AT_name), ""));
      if (!name.empty())
        variableLoc.insert({name, {lt, file, line}});
    }
  }
}

// Returns the pair of file name and line number describing location of data
// object (variable, array, etc) definition.
template <class ELFT>
Optional<std::pair<std::string, unsigned>>
ObjFile<ELFT>::getVariableLoc(StringRef name) {
  llvm::call_once(initDwarfLine, [this]() { initializeDwarf(); });

  // Return if we have no debug information about data object.
  auto it = variableLoc.find(name);
  if (it == variableLoc.end())
    return None;

  // Take file name string from line table.
  std::string fileName;
  if (!it->second.lt->getFileNameByIndex(
          it->second.file, {},
          DILineInfoSpecifier::FileLineInfoKind::AbsoluteFilePath, fileName))
    return None;

  return std::make_pair(fileName, it->second.line);
}

// Returns source line information for a given offset
// using DWARF debug info.
template <class ELFT>
Optional<DILineInfo> ObjFile<ELFT>::getDILineInfo(InputSectionBase *s,
                                                  uint64_t offset) {
  llvm::call_once(initDwarfLine, [this]() { initializeDwarf(); });

  // Detect SectionIndex for specified section.
  uint64_t sectionIndex = object::SectionedAddress::UndefSection;
  ArrayRef<InputSectionBase *> sections = s->file->getSections();
  for (uint64_t curIndex = 0; curIndex < sections.size(); ++curIndex) {
    if (s == sections[curIndex]) {
      sectionIndex = curIndex;
      break;
    }
  }

  // Use fake address calcuated by adding section file offset and offset in
  // section. See comments for ObjectInfo class.
  DILineInfo info;
  for (const llvm::DWARFDebugLine::LineTable *lt : lineTables) {
    if (lt->getFileLineInfoForAddress(
            {s->getOffsetInFile() + offset, sectionIndex}, nullptr,
            DILineInfoSpecifier::FileLineInfoKind::AbsoluteFilePath, info))
      return info;
  }
  return None;
}

// Returns "<internal>", "foo.a(bar.o)" or "baz.o".
std::string lld::toString(const InputFile *f) {
  if (!f)
    return "<internal>";

  if (f->toStringCache.empty()) {
    if (f->archiveName.empty())
      f->toStringCache = f->getName();
    else
      f->toStringCache = (f->archiveName + "(" + f->getName() + ")").str();
  }
  return f->toStringCache;
}

ELFFileBase::ELFFileBase(Kind k, MemoryBufferRef mb) : InputFile(k, mb) {
  ekind = getELFKind(mb, "");

  switch (ekind) {
  case ELF32LEKind:
    init<ELF32LE>();
    break;
  case ELF32BEKind:
    init<ELF32BE>();
    break;
  case ELF64LEKind:
    init<ELF64LE>();
    break;
  case ELF64BEKind:
    init<ELF64BE>();
    break;
  default:
    llvm_unreachable("getELFKind");
  }
}

template <typename Elf_Shdr>
static const Elf_Shdr *findSection(ArrayRef<Elf_Shdr> sections, uint32_t type) {
  for (const Elf_Shdr &sec : sections)
    if (sec.sh_type == type)
      return &sec;
  return nullptr;
}

template <class ELFT> void ELFFileBase::init() {
  using Elf_Shdr = typename ELFT::Shdr;
  using Elf_Sym = typename ELFT::Sym;

  // Initialize trivial attributes.
  const ELFFile<ELFT> &obj = getObj<ELFT>();
  emachine = obj.getHeader()->e_machine;
  osabi = obj.getHeader()->e_ident[llvm::ELF::EI_OSABI];
  abiVersion = obj.getHeader()->e_ident[llvm::ELF::EI_ABIVERSION];

  ArrayRef<Elf_Shdr> sections = CHECK(obj.sections(), this);

  // Find a symbol table.
  bool isDSO =
      (identify_magic(mb.getBuffer()) == file_magic::elf_shared_object);
  const Elf_Shdr *symtabSec =
      findSection(sections, isDSO ? SHT_DYNSYM : SHT_SYMTAB);

  if (!symtabSec)
    return;

  // Initialize members corresponding to a symbol table.
  firstGlobal = symtabSec->sh_info;

  ArrayRef<Elf_Sym> eSyms = CHECK(obj.symbols(symtabSec), this);
  if (firstGlobal == 0 || firstGlobal > eSyms.size())
    fatal(toString(this) + ": invalid sh_info in symbol table");

  elfSyms = reinterpret_cast<const void *>(eSyms.data());
  numELFSyms = eSyms.size();
  stringTable = CHECK(obj.getStringTableForSymtab(*symtabSec, sections), this);
}

template <class ELFT>
uint32_t ObjFile<ELFT>::getSectionIndex(const Elf_Sym &sym) const {
  return CHECK(
      this->getObj().getSectionIndex(&sym, getELFSyms<ELFT>(), shndxTable),
      this);
}

template <class ELFT> ArrayRef<Symbol *> ObjFile<ELFT>::getLocalSymbols() {
  if (this->symbols.empty())
    return {};
  return makeArrayRef(this->symbols).slice(1, this->firstGlobal - 1);
}

template <class ELFT> ArrayRef<Symbol *> ObjFile<ELFT>::getGlobalSymbols() {
  return makeArrayRef(this->symbols).slice(this->firstGlobal);
}

template <class ELFT> void ObjFile<ELFT>::parse(bool ignoreComdats) {
  // Read a section table. justSymbols is usually false.
  if (this->justSymbols)
    initializeJustSymbols();
  else
    initializeSections(ignoreComdats);

  // Read a symbol table.
  initializeSymbols();
}

// Sections with SHT_GROUP and comdat bits define comdat section groups.
// They are identified and deduplicated by group name. This function
// returns a group name.
template <class ELFT>
StringRef ObjFile<ELFT>::getShtGroupSignature(ArrayRef<Elf_Shdr> sections,
                                              const Elf_Shdr &sec) {
  typename ELFT::SymRange symbols = this->getELFSyms<ELFT>();
  if (sec.sh_info >= symbols.size())
    fatal(toString(this) + ": invalid symbol index");
  const typename ELFT::Sym &sym = symbols[sec.sh_info];
  StringRef signature = CHECK(sym.getName(this->stringTable), this);

  // As a special case, if a symbol is a section symbol and has no name,
  // we use a section name as a signature.
  //
  // Such SHT_GROUP sections are invalid from the perspective of the ELF
  // standard, but GNU gold 1.14 (the newest version as of July 2017) or
  // older produce such sections as outputs for the -r option, so we need
  // a bug-compatibility.
  if (signature.empty() && sym.getType() == STT_SECTION)
    return getSectionName(sec);
  return signature;
}

template <class ELFT> bool ObjFile<ELFT>::shouldMerge(const Elf_Shdr &sec) {
  // On a regular link we don't merge sections if -O0 (default is -O1). This
  // sometimes makes the linker significantly faster, although the output will
  // be bigger.
  //
  // Doing the same for -r would create a problem as it would combine sections
  // with different sh_entsize. One option would be to just copy every SHF_MERGE
  // section as is to the output. While this would produce a valid ELF file with
  // usable SHF_MERGE sections, tools like (llvm-)?dwarfdump get confused when
  // they see two .debug_str. We could have separate logic for combining
  // SHF_MERGE sections based both on their name and sh_entsize, but that seems
  // to be more trouble than it is worth. Instead, we just use the regular (-O1)
  // logic for -r.
  if (config->optimize == 0 && !config->relocatable)
    return false;

  // A mergeable section with size 0 is useless because they don't have
  // any data to merge. A mergeable string section with size 0 can be
  // argued as invalid because it doesn't end with a null character.
  // We'll avoid a mess by handling them as if they were non-mergeable.
  if (sec.sh_size == 0)
    return false;

  // Check for sh_entsize. The ELF spec is not clear about the zero
  // sh_entsize. It says that "the member [sh_entsize] contains 0 if
  // the section does not hold a table of fixed-size entries". We know
  // that Rust 1.13 produces a string mergeable section with a zero
  // sh_entsize. Here we just accept it rather than being picky about it.
  uint64_t entSize = sec.sh_entsize;
  if (entSize == 0)
    return false;
  if (sec.sh_size % entSize)
    fatal(toString(this) +
          ": SHF_MERGE section size must be a multiple of sh_entsize");

  uint64_t flags = sec.sh_flags;
  if (!(flags & SHF_MERGE))
    return false;
  if (flags & SHF_WRITE)
    fatal(toString(this) + ": writable SHF_MERGE section is not supported");

  return true;
}

// This is for --just-symbols.
//
// --just-symbols is a very minor feature that allows you to link your
// output against other existing program, so that if you load both your
// program and the other program into memory, your output can refer the
// other program's symbols.
//
// When the option is given, we link "just symbols". The section table is
// initialized with null pointers.
template <class ELFT> void ObjFile<ELFT>::initializeJustSymbols() {
  ArrayRef<Elf_Shdr> sections = CHECK(this->getObj().sections(), this);
  this->sections.resize(sections.size());
}

// An ELF object file may contain a `.deplibs` section. If it exists, the
// section contains a list of library specifiers such as `m` for libm. This
// function resolves a given name by finding the first matching library checking
// the various ways that a library can be specified to LLD. This ELF extension
// is a form of autolinking and is called `dependent libraries`. It is currently
// unique to LLVM and lld.
static void addDependentLibrary(StringRef specifier, const InputFile *f) {
  if (!config->dependentLibraries)
    return;
  if (fs::exists(specifier))
    driver->addFile(specifier, /*withLOption=*/false);
  else if (Optional<std::string> s = findFromSearchPaths(specifier))
    driver->addFile(*s, /*withLOption=*/true);
  else if (Optional<std::string> s = searchLibraryBaseName(specifier))
    driver->addFile(*s, /*withLOption=*/true);
  else
    error(toString(f) +
          ": unable to find library from dependent library specifier: " +
          specifier);
}

template <class ELFT>
void ObjFile<ELFT>::initializeSections(bool ignoreComdats) {
  const ELFFile<ELFT> &obj = this->getObj();

  ArrayRef<Elf_Shdr> objSections = CHECK(obj.sections(), this);
  uint64_t size = objSections.size();
  this->sections.resize(size);
  this->sectionStringTable =
      CHECK(obj.getSectionStringTable(objSections), this);

  for (size_t i = 0, e = objSections.size(); i < e; i++) {
    if (this->sections[i] == &InputSection::discarded)
      continue;
    const Elf_Shdr &sec = objSections[i];

    if (sec.sh_type == ELF::SHT_LLVM_CALL_GRAPH_PROFILE)
      cgProfile =
          check(obj.template getSectionContentsAsArray<Elf_CGProfile>(&sec));

    // SHF_EXCLUDE'ed sections are discarded by the linker. However,
    // if -r is given, we'll let the final link discard such sections.
    // This is compatible with GNU.
    if ((sec.sh_flags & SHF_EXCLUDE) && !config->relocatable) {
      if (sec.sh_type == SHT_LLVM_ADDRSIG) {
        // We ignore the address-significance table if we know that the object
        // file was created by objcopy or ld -r. This is because these tools
        // will reorder the symbols in the symbol table, invalidating the data
        // in the address-significance table, which refers to symbols by index.
        if (sec.sh_link != 0)
          this->addrsigSec = &sec;
        else if (config->icf == ICFLevel::Safe)
          warn(toString(this) + ": --icf=safe is incompatible with object "
                                "files created using objcopy or ld -r");
      }
      this->sections[i] = &InputSection::discarded;
      continue;
    }

    switch (sec.sh_type) {
    case SHT_GROUP: {
      // De-duplicate section groups by their signatures.
      StringRef signature = getShtGroupSignature(objSections, sec);
      this->sections[i] = &InputSection::discarded;


      ArrayRef<Elf_Word> entries =
          CHECK(obj.template getSectionContentsAsArray<Elf_Word>(&sec), this);
      if (entries.empty())
        fatal(toString(this) + ": empty SHT_GROUP");

      // The first word of a SHT_GROUP section contains flags. Currently,
      // the standard defines only "GRP_COMDAT" flag for the COMDAT group.
      // An group with the empty flag doesn't define anything; such sections
      // are just skipped.
      if (entries[0] == 0)
        continue;

      if (entries[0] != GRP_COMDAT)
        fatal(toString(this) + ": unsupported SHT_GROUP format");

      bool isNew =
          ignoreComdats ||
          symtab->comdatGroups.try_emplace(CachedHashStringRef(signature), this)
              .second;
      if (isNew) {
        if (config->relocatable)
          this->sections[i] = createInputSection(sec);
        continue;
      }

      // Otherwise, discard group members.
      for (uint32_t secIndex : entries.slice(1)) {
        if (secIndex >= size)
          fatal(toString(this) +
                ": invalid section index in group: " + Twine(secIndex));
        this->sections[secIndex] = &InputSection::discarded;
      }
      break;
    }
    case SHT_SYMTAB_SHNDX:
      shndxTable = CHECK(obj.getSHNDXTable(sec, objSections), this);
      break;
    case SHT_SYMTAB:
    case SHT_STRTAB:
    case SHT_NULL:
      break;
    default:
      this->sections[i] = createInputSection(sec);
    }

    // .ARM.exidx sections have a reverse dependency on the InputSection they
    // have a SHF_LINK_ORDER dependency, this is identified by the sh_link.
    if (sec.sh_flags & SHF_LINK_ORDER) {
      InputSectionBase *linkSec = nullptr;
      if (sec.sh_link < this->sections.size())
        linkSec = this->sections[sec.sh_link];
      if (!linkSec)
        fatal(toString(this) +
              ": invalid sh_link index: " + Twine(sec.sh_link));

      InputSection *isec = cast<InputSection>(this->sections[i]);
      linkSec->dependentSections.push_back(isec);
      if (!isa<InputSection>(linkSec))
        error("a section " + isec->name +
              " with SHF_LINK_ORDER should not refer a non-regular "
              "section: " +
              toString(linkSec));
    }
  }
}

// For ARM only, to set the EF_ARM_ABI_FLOAT_SOFT or EF_ARM_ABI_FLOAT_HARD
// flag in the ELF Header we need to look at Tag_ABI_VFP_args to find out how
// the input objects have been compiled.
static void updateARMVFPArgs(const ARMAttributeParser &attributes,
                             const InputFile *f) {
  if (!attributes.hasAttribute(ARMBuildAttrs::ABI_VFP_args))
    // If an ABI tag isn't present then it is implicitly given the value of 0
    // which maps to ARMBuildAttrs::BaseAAPCS. However many assembler files,
    // including some in glibc that don't use FP args (and should have value 3)
    // don't have the attribute so we do not consider an implicit value of 0
    // as a clash.
    return;

  unsigned vfpArgs = attributes.getAttributeValue(ARMBuildAttrs::ABI_VFP_args);
  ARMVFPArgKind arg;
  switch (vfpArgs) {
  case ARMBuildAttrs::BaseAAPCS:
    arg = ARMVFPArgKind::Base;
    break;
  case ARMBuildAttrs::HardFPAAPCS:
    arg = ARMVFPArgKind::VFP;
    break;
  case ARMBuildAttrs::ToolChainFPPCS:
    // Tool chain specific convention that conforms to neither AAPCS variant.
    arg = ARMVFPArgKind::ToolChain;
    break;
  case ARMBuildAttrs::CompatibleFPAAPCS:
    // Object compatible with all conventions.
    return;
  default:
    error(toString(f) + ": unknown Tag_ABI_VFP_args value: " + Twine(vfpArgs));
    return;
  }
  // Follow ld.bfd and error if there is a mix of calling conventions.
  if (config->armVFPArgs != arg && config->armVFPArgs != ARMVFPArgKind::Default)
    error(toString(f) + ": incompatible Tag_ABI_VFP_args");
  else
    config->armVFPArgs = arg;
}

// The ARM support in lld makes some use of instructions that are not available
// on all ARM architectures. Namely:
// - Use of BLX instruction for interworking between ARM and Thumb state.
// - Use of the extended Thumb branch encoding in relocation.
// - Use of the MOVT/MOVW instructions in Thumb Thunks.
// The ARM Attributes section contains information about the architecture chosen
// at compile time. We follow the convention that if at least one input object
// is compiled with an architecture that supports these features then lld is
// permitted to use them.
static void updateSupportedARMFeatures(const ARMAttributeParser &attributes) {
  if (!attributes.hasAttribute(ARMBuildAttrs::CPU_arch))
    return;
  auto arch = attributes.getAttributeValue(ARMBuildAttrs::CPU_arch);
  switch (arch) {
  case ARMBuildAttrs::Pre_v4:
  case ARMBuildAttrs::v4:
  case ARMBuildAttrs::v4T:
    // Architectures prior to v5 do not support BLX instruction
    break;
  case ARMBuildAttrs::v5T:
  case ARMBuildAttrs::v5TE:
  case ARMBuildAttrs::v5TEJ:
  case ARMBuildAttrs::v6:
  case ARMBuildAttrs::v6KZ:
  case ARMBuildAttrs::v6K:
    config->armHasBlx = true;
    // Architectures used in pre-Cortex processors do not support
    // The J1 = 1 J2 = 1 Thumb branch range extension, with the exception
    // of Architecture v6T2 (arm1156t2-s and arm1156t2f-s) that do.
    break;
  default:
    // All other Architectures have BLX and extended branch encoding
    config->armHasBlx = true;
    config->armJ1J2BranchEncoding = true;
    if (arch != ARMBuildAttrs::v6_M && arch != ARMBuildAttrs::v6S_M)
      // All Architectures used in Cortex processors with the exception
      // of v6-M and v6S-M have the MOVT and MOVW instructions.
      config->armHasMovtMovw = true;
    break;
  }
}

// If a source file is compiled with x86 hardware-assisted call flow control
// enabled, the generated object file contains feature flags indicating that
// fact. This function reads the feature flags and returns it.
//
// Essentially we want to read a single 32-bit value in this function, but this
// function is rather complicated because the value is buried deep inside a
// .note.gnu.property section.
//
// The section consists of one or more NOTE records. Each NOTE record consists
// of zero or more type-length-value fields. We want to find a field of a
// certain type. It seems a bit too much to just store a 32-bit value, perhaps
// the ABI is unnecessarily complicated.
template <class ELFT>
static uint32_t readAndFeatures(ObjFile<ELFT> *obj, ArrayRef<uint8_t> data) {
  using Elf_Nhdr = typename ELFT::Nhdr;
  using Elf_Note = typename ELFT::Note;

  uint32_t featuresSet = 0;
  while (!data.empty()) {
    // Read one NOTE record.
    if (data.size() < sizeof(Elf_Nhdr))
      fatal(toString(obj) + ": .note.gnu.property: section too short");

    auto *nhdr = reinterpret_cast<const Elf_Nhdr *>(data.data());
    if (data.size() < nhdr->getSize())
      fatal(toString(obj) + ": .note.gnu.property: section too short");

    Elf_Note note(*nhdr);
    if (nhdr->n_type != NT_GNU_PROPERTY_TYPE_0 || note.getName() != "GNU") {
      data = data.slice(nhdr->getSize());
      continue;
    }

    uint32_t featureAndType = config->emachine == EM_AARCH64
                                  ? GNU_PROPERTY_AARCH64_FEATURE_1_AND
                                  : GNU_PROPERTY_X86_FEATURE_1_AND;

    // Read a body of a NOTE record, which consists of type-length-value fields.
    ArrayRef<uint8_t> desc = note.getDesc();
    while (!desc.empty()) {
      if (desc.size() < 8)
        fatal(toString(obj) + ": .note.gnu.property: section too short");

      uint32_t type = read32le(desc.data());
      uint32_t size = read32le(desc.data() + 4);

      if (type == featureAndType) {
        // We found a FEATURE_1_AND field. There may be more than one of these
        // in a .note.gnu.propery section, for a relocatable object we
        // accumulate the bits set.
        featuresSet |= read32le(desc.data() + 8);
      }

      // On 64-bit, a payload may be followed by a 4-byte padding to make its
      // size a multiple of 8.
      if (ELFT::Is64Bits)
        size = alignTo(size, 8);

      desc = desc.slice(size + 8); // +8 for Type and Size
    }

    // Go to next NOTE record to look for more FEATURE_1_AND descriptions.
    data = data.slice(nhdr->getSize());
  }

  return featuresSet;
}

template <class ELFT>
InputSectionBase *ObjFile<ELFT>::getRelocTarget(const Elf_Shdr &sec) {
  uint32_t idx = sec.sh_info;
  if (idx >= this->sections.size())
    fatal(toString(this) + ": invalid relocated section index: " + Twine(idx));
  InputSectionBase *target = this->sections[idx];

  // Strictly speaking, a relocation section must be included in the
  // group of the section it relocates. However, LLVM 3.3 and earlier
  // would fail to do so, so we gracefully handle that case.
  if (target == &InputSection::discarded)
    return nullptr;

  if (!target)
    fatal(toString(this) + ": unsupported relocation reference");
  return target;
}

// Create a regular InputSection class that has the same contents
// as a given section.
static InputSection *toRegularSection(MergeInputSection *sec) {
  return make<InputSection>(sec->file, sec->flags, sec->type, sec->alignment,
                            sec->data(), sec->name);
}

template <class ELFT>
InputSectionBase *ObjFile<ELFT>::createInputSection(const Elf_Shdr &sec) {
  StringRef name = getSectionName(sec);

  switch (sec.sh_type) {
  case SHT_ARM_ATTRIBUTES: {
    if (config->emachine != EM_ARM)
      break;
    ARMAttributeParser attributes;
    ArrayRef<uint8_t> contents = check(this->getObj().getSectionContents(&sec));
    attributes.Parse(contents, /*isLittle*/ config->ekind == ELF32LEKind);
    updateSupportedARMFeatures(attributes);
    updateARMVFPArgs(attributes, this);

    // FIXME: Retain the first attribute section we see. The eglibc ARM
    // dynamic loaders require the presence of an attribute section for dlopen
    // to work. In a full implementation we would merge all attribute sections.
    if (in.armAttributes == nullptr) {
      in.armAttributes = make<InputSection>(*this, sec, name);
      return in.armAttributes;
    }
    return &InputSection::discarded;
  }
  case SHT_LLVM_DEPENDENT_LIBRARIES: {
    if (config->relocatable)
      break;
    ArrayRef<char> data =
        CHECK(this->getObj().template getSectionContentsAsArray<char>(&sec), this);
    if (!data.empty() && data.back() != '\0') {
      error(toString(this) +
            ": corrupted dependent libraries section (unterminated string): " +
            name);
      return &InputSection::discarded;
    }
    for (const char *d = data.begin(), *e = data.end(); d < e;) {
      StringRef s(d);
      addDependentLibrary(s, this);
      d += s.size() + 1;
    }
    return &InputSection::discarded;
  }
  case SHT_RELA:
  case SHT_REL: {
    // Find a relocation target section and associate this section with that.
    // Target may have been discarded if it is in a different section group
    // and the group is discarded, even though it's a violation of the
    // spec. We handle that situation gracefully by discarding dangling
    // relocation sections.
    InputSectionBase *target = getRelocTarget(sec);
    if (!target)
      return nullptr;

    // This section contains relocation information.
    // If -r is given, we do not interpret or apply relocation
    // but just copy relocation sections to output.
    if (config->relocatable) {
      InputSection *relocSec = make<InputSection>(*this, sec, name);
      // We want to add a dependency to target, similar like we do for
      // -emit-relocs below. This is useful for the case when linker script
      // contains the "/DISCARD/". It is perhaps uncommon to use a script with
      // -r, but we faced it in the Linux kernel and have to handle such case
      // and not to crash.
      target->dependentSections.push_back(relocSec);
      return relocSec;
    }

    if (target->firstRelocation)
      fatal(toString(this) +
            ": multiple relocation sections to one section are not supported");

    // ELF spec allows mergeable sections with relocations, but they are
    // rare, and it is in practice hard to merge such sections by contents,
    // because applying relocations at end of linking changes section
    // contents. So, we simply handle such sections as non-mergeable ones.
    // Degrading like this is acceptable because section merging is optional.
    if (auto *ms = dyn_cast<MergeInputSection>(target)) {
      target = toRegularSection(ms);
      this->sections[sec.sh_info] = target;
    }

    if (sec.sh_type == SHT_RELA) {
      ArrayRef<Elf_Rela> rels = CHECK(getObj().relas(&sec), this);
      target->firstRelocation = rels.begin();
      target->numRelocations = rels.size();
      target->areRelocsRela = true;
    } else {
      ArrayRef<Elf_Rel> rels = CHECK(getObj().rels(&sec), this);
      target->firstRelocation = rels.begin();
      target->numRelocations = rels.size();
      target->areRelocsRela = false;
    }
    assert(isUInt<31>(target->numRelocations));

    // Relocation sections processed by the linker are usually removed
    // from the output, so returning `nullptr` for the normal case.
    // However, if -emit-relocs is given, we need to leave them in the output.
    // (Some post link analysis tools need this information.)
    if (config->emitRelocs) {
      InputSection *relocSec = make<InputSection>(*this, sec, name);
      // We will not emit relocation section if target was discarded.
      target->dependentSections.push_back(relocSec);
      return relocSec;
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
  if (name == ".note.GNU-stack")
    return &InputSection::discarded;

  // Object files that use processor features such as Intel Control-Flow
  // Enforcement (CET) or AArch64 Branch Target Identification BTI, use a
  // .note.gnu.property section containing a bitfield of feature bits like the
  // GNU_PROPERTY_X86_FEATURE_1_IBT flag. Read a bitmap containing the flag.
  //
  // Since we merge bitmaps from multiple object files to create a new
  // .note.gnu.property containing a single AND'ed bitmap, we discard an input
  // file's .note.gnu.property section.
  if (name == ".note.gnu.property") {
    ArrayRef<uint8_t> contents = check(this->getObj().getSectionContents(&sec));
    this->andFeatures = readAndFeatures(this, contents);
    return &InputSection::discarded;
  }

  // Split stacks is a feature to support a discontiguous stack,
  // commonly used in the programming language Go. For the details,
  // see https://gcc.gnu.org/wiki/SplitStacks. An object file compiled
  // for split stack will include a .note.GNU-split-stack section.
  if (name == ".note.GNU-split-stack") {
    if (config->relocatable) {
      error("cannot mix split-stack and non-split-stack in a relocatable link");
      return &InputSection::discarded;
    }
    this->splitStack = true;
    return &InputSection::discarded;
  }

  // An object file cmpiled for split stack, but where some of the
  // functions were compiled with the no_split_stack_attribute will
  // include a .note.GNU-no-split-stack section.
  if (name == ".note.GNU-no-split-stack") {
    this->someNoSplitStack = true;
    return &InputSection::discarded;
  }

  // The linkonce feature is a sort of proto-comdat. Some glibc i386 object
  // files contain definitions of symbol "__x86.get_pc_thunk.bx" in linkonce
  // sections. Drop those sections to avoid duplicate symbol errors.
  // FIXME: This is glibc PR20543, we should remove this hack once that has been
  // fixed for a while.
  if (name == ".gnu.linkonce.t.__x86.get_pc_thunk.bx" ||
      name == ".gnu.linkonce.t.__i686.get_pc_thunk.bx")
    return &InputSection::discarded;

  // If we are creating a new .build-id section, strip existing .build-id
  // sections so that the output won't have more than one .build-id.
  // This is not usually a problem because input object files normally don't
  // have .build-id sections, but you can create such files by
  // "ld.{bfd,gold,lld} -r --build-id", and we want to guard against it.
  if (name == ".note.gnu.build-id" && config->buildId != BuildIdKind::None)
    return &InputSection::discarded;

  // The linker merges EH (exception handling) frames and creates a
  // .eh_frame_hdr section for runtime. So we handle them with a special
  // class. For relocatable outputs, they are just passed through.
  if (name == ".eh_frame" && !config->relocatable)
    return make<EhInputSection>(*this, sec, name);

  if (shouldMerge(sec))
    return make<MergeInputSection>(*this, sec, name);
  return make<InputSection>(*this, sec, name);
}

template <class ELFT>
StringRef ObjFile<ELFT>::getSectionName(const Elf_Shdr &sec) {
  return CHECK(getObj().getSectionName(&sec, sectionStringTable), this);
}

// Initialize this->Symbols. this->Symbols is a parallel array as
// its corresponding ELF symbol table.
template <class ELFT> void ObjFile<ELFT>::initializeSymbols() {
  ArrayRef<Elf_Sym> eSyms = this->getELFSyms<ELFT>();
  this->symbols.resize(eSyms.size());

  // Our symbol table may have already been partially initialized
  // because of LazyObjFile.
  for (size_t i = 0, end = eSyms.size(); i != end; ++i)
    if (!this->symbols[i] && eSyms[i].getBinding() != STB_LOCAL)
      this->symbols[i] =
          symtab->insert(CHECK(eSyms[i].getName(this->stringTable), this));

  // Fill this->Symbols. A symbol is either local or global.
  for (size_t i = 0, end = eSyms.size(); i != end; ++i) {
    const Elf_Sym &eSym = eSyms[i];

    // Read symbol attributes.
    uint32_t secIdx = getSectionIndex(eSym);
    if (secIdx >= this->sections.size())
      fatal(toString(this) + ": invalid section index: " + Twine(secIdx));

    InputSectionBase *sec = this->sections[secIdx];
    uint8_t binding = eSym.getBinding();
    uint8_t stOther = eSym.st_other;
    uint8_t type = eSym.getType();
    uint64_t value = eSym.st_value;
    uint64_t size = eSym.st_size;
    StringRefZ name = this->stringTable.data() + eSym.st_name;

    // Handle local symbols. Local symbols are not added to the symbol
    // table because they are not visible from other object files. We
    // allocate symbol instances and add their pointers to Symbols.
    if (binding == STB_LOCAL) {
      if (eSym.getType() == STT_FILE)
        sourceFile = CHECK(eSym.getName(this->stringTable), this);

      if (this->stringTable.size() <= eSym.st_name)
        fatal(toString(this) + ": invalid symbol name offset");

      if (eSym.st_shndx == SHN_UNDEF)
        this->symbols[i] = make<Undefined>(this, name, binding, stOther, type);
      else if (sec == &InputSection::discarded)
        this->symbols[i] = make<Undefined>(this, name, binding, stOther, type,
                                           /*DiscardedSecIdx=*/secIdx);
      else
        this->symbols[i] =
            make<Defined>(this, name, binding, stOther, type, value, size, sec);
      continue;
    }

    // Handle global undefined symbols.
    if (eSym.st_shndx == SHN_UNDEF) {
      this->symbols[i]->resolve(Undefined{this, name, binding, stOther, type});
      continue;
    }

    // Handle global common symbols.
    if (eSym.st_shndx == SHN_COMMON) {
      if (value == 0 || value >= UINT32_MAX)
        fatal(toString(this) + ": common symbol '" + StringRef(name.data) +
              "' has invalid alignment: " + Twine(value));
      this->symbols[i]->resolve(
          CommonSymbol{this, name, binding, stOther, type, value, size});
      continue;
    }

    // If a defined symbol is in a discarded section, handle it as if it
    // were an undefined symbol. Such symbol doesn't comply with the
    // standard, but in practice, a .eh_frame often directly refer
    // COMDAT member sections, and if a comdat group is discarded, some
    // defined symbol in a .eh_frame becomes dangling symbols.
    if (sec == &InputSection::discarded) {
      this->symbols[i]->resolve(
          Undefined{this, name, binding, stOther, type, secIdx});
      continue;
    }

    // Handle global defined symbols.
    if (binding == STB_GLOBAL || binding == STB_WEAK ||
        binding == STB_GNU_UNIQUE) {
      this->symbols[i]->resolve(
          Defined{this, name, binding, stOther, type, value, size, sec});
      continue;
    }

    fatal(toString(this) + ": unexpected binding: " + Twine((int)binding));
  }
}

ArchiveFile::ArchiveFile(std::unique_ptr<Archive> &&file)
    : InputFile(ArchiveKind, file->getMemoryBufferRef()),
      file(std::move(file)) {}

void ArchiveFile::parse() {
  for (const Archive::Symbol &sym : file->symbols())
    symtab->addSymbol(LazyArchive{*this, sym});
}

// Returns a buffer pointing to a member file containing a given symbol.
void ArchiveFile::fetch(const Archive::Symbol &sym) {
  Archive::Child c =
      CHECK(sym.getMember(), toString(this) +
                                 ": could not get the member for symbol " +
                                 toELFString(sym));

  if (!seen.insert(c.getChildOffset()).second)
    return;

  MemoryBufferRef mb =
      CHECK(c.getMemoryBufferRef(),
            toString(this) +
                ": could not get the buffer for the member defining symbol " +
                toELFString(sym));

  if (tar && c.getParent()->isThin())
    tar->append(relativeToRoot(CHECK(c.getFullName(), this)), mb.getBuffer());

  InputFile *file = createObjectFile(
      mb, getName(), c.getParent()->isThin() ? 0 : c.getChildOffset());
  file->groupId = groupId;
  parseFile(file);
}

unsigned SharedFile::vernauxNum;

// Parse the version definitions in the object file if present, and return a
// vector whose nth element contains a pointer to the Elf_Verdef for version
// identifier n. Version identifiers that are not definitions map to nullptr.
template <typename ELFT>
static std::vector<const void *> parseVerdefs(const uint8_t *base,
                                              const typename ELFT::Shdr *sec) {
  if (!sec)
    return {};

  // We cannot determine the largest verdef identifier without inspecting
  // every Elf_Verdef, but both bfd and gold assign verdef identifiers
  // sequentially starting from 1, so we predict that the largest identifier
  // will be verdefCount.
  unsigned verdefCount = sec->sh_info;
  std::vector<const void *> verdefs(verdefCount + 1);

  // Build the Verdefs array by following the chain of Elf_Verdef objects
  // from the start of the .gnu.version_d section.
  const uint8_t *verdef = base + sec->sh_offset;
  for (unsigned i = 0; i != verdefCount; ++i) {
    auto *curVerdef = reinterpret_cast<const typename ELFT::Verdef *>(verdef);
    verdef += curVerdef->vd_next;
    unsigned verdefIndex = curVerdef->vd_ndx;
    verdefs.resize(verdefIndex + 1);
    verdefs[verdefIndex] = curVerdef;
  }
  return verdefs;
}

// We do not usually care about alignments of data in shared object
// files because the loader takes care of it. However, if we promote a
// DSO symbol to point to .bss due to copy relocation, we need to keep
// the original alignment requirements. We infer it in this function.
template <typename ELFT>
static uint64_t getAlignment(ArrayRef<typename ELFT::Shdr> sections,
                             const typename ELFT::Sym &sym) {
  uint64_t ret = UINT64_MAX;
  if (sym.st_value)
    ret = 1ULL << countTrailingZeros((uint64_t)sym.st_value);
  if (0 < sym.st_shndx && sym.st_shndx < sections.size())
    ret = std::min<uint64_t>(ret, sections[sym.st_shndx].sh_addralign);
  return (ret > UINT32_MAX) ? 0 : ret;
}

// Fully parse the shared object file.
//
// This function parses symbol versions. If a DSO has version information,
// the file has a ".gnu.version_d" section which contains symbol version
// definitions. Each symbol is associated to one version through a table in
// ".gnu.version" section. That table is a parallel array for the symbol
// table, and each table entry contains an index in ".gnu.version_d".
//
// The special index 0 is reserved for VERF_NDX_LOCAL and 1 is for
// VER_NDX_GLOBAL. There's no table entry for these special versions in
// ".gnu.version_d".
//
// The file format for symbol versioning is perhaps a bit more complicated
// than necessary, but you can easily understand the code if you wrap your
// head around the data structure described above.
template <class ELFT> void SharedFile::parse() {
  using Elf_Dyn = typename ELFT::Dyn;
  using Elf_Shdr = typename ELFT::Shdr;
  using Elf_Sym = typename ELFT::Sym;
  using Elf_Verdef = typename ELFT::Verdef;
  using Elf_Versym = typename ELFT::Versym;

  ArrayRef<Elf_Dyn> dynamicTags;
  const ELFFile<ELFT> obj = this->getObj<ELFT>();
  ArrayRef<Elf_Shdr> sections = CHECK(obj.sections(), this);

  const Elf_Shdr *versymSec = nullptr;
  const Elf_Shdr *verdefSec = nullptr;

  // Search for .dynsym, .dynamic, .symtab, .gnu.version and .gnu.version_d.
  for (const Elf_Shdr &sec : sections) {
    switch (sec.sh_type) {
    default:
      continue;
    case SHT_DYNAMIC:
      dynamicTags =
          CHECK(obj.template getSectionContentsAsArray<Elf_Dyn>(&sec), this);
      break;
    case SHT_GNU_versym:
      versymSec = &sec;
      break;
    case SHT_GNU_verdef:
      verdefSec = &sec;
      break;
    }
  }

  if (versymSec && numELFSyms == 0) {
    error("SHT_GNU_versym should be associated with symbol table");
    return;
  }

  // Search for a DT_SONAME tag to initialize this->soName.
  for (const Elf_Dyn &dyn : dynamicTags) {
    if (dyn.d_tag == DT_NEEDED) {
      uint64_t val = dyn.getVal();
      if (val >= this->stringTable.size())
        fatal(toString(this) + ": invalid DT_NEEDED entry");
      dtNeeded.push_back(this->stringTable.data() + val);
    } else if (dyn.d_tag == DT_SONAME) {
      uint64_t val = dyn.getVal();
      if (val >= this->stringTable.size())
        fatal(toString(this) + ": invalid DT_SONAME entry");
      soName = this->stringTable.data() + val;
    }
  }

  // DSOs are uniquified not by filename but by soname.
  DenseMap<StringRef, SharedFile *>::iterator it;
  bool wasInserted;
  std::tie(it, wasInserted) = symtab->soNames.try_emplace(soName, this);

  // If a DSO appears more than once on the command line with and without
  // --as-needed, --no-as-needed takes precedence over --as-needed because a
  // user can add an extra DSO with --no-as-needed to force it to be added to
  // the dependency list.
  it->second->isNeeded |= isNeeded;
  if (!wasInserted)
    return;

  sharedFiles.push_back(this);

  verdefs = parseVerdefs<ELFT>(obj.base(), verdefSec);

  // Parse ".gnu.version" section which is a parallel array for the symbol
  // table. If a given file doesn't have a ".gnu.version" section, we use
  // VER_NDX_GLOBAL.
  size_t size = numELFSyms - firstGlobal;
  std::vector<uint32_t> versyms(size, VER_NDX_GLOBAL);
  if (versymSec) {
    ArrayRef<Elf_Versym> versym =
        CHECK(obj.template getSectionContentsAsArray<Elf_Versym>(versymSec),
              this)
            .slice(firstGlobal);
    for (size_t i = 0; i < size; ++i)
      versyms[i] = versym[i].vs_index;
  }

  // System libraries can have a lot of symbols with versions. Using a
  // fixed buffer for computing the versions name (foo@ver) can save a
  // lot of allocations.
  SmallString<0> versionedNameBuffer;

  // Add symbols to the symbol table.
  ArrayRef<Elf_Sym> syms = this->getGlobalELFSyms<ELFT>();
  for (size_t i = 0; i < syms.size(); ++i) {
    const Elf_Sym &sym = syms[i];

    // ELF spec requires that all local symbols precede weak or global
    // symbols in each symbol table, and the index of first non-local symbol
    // is stored to sh_info. If a local symbol appears after some non-local
    // symbol, that's a violation of the spec.
    StringRef name = CHECK(sym.getName(this->stringTable), this);
    if (sym.getBinding() == STB_LOCAL) {
      warn("found local symbol '" + name +
           "' in global part of symbol table in file " + toString(this));
      continue;
    }

    if (sym.isUndefined()) {
      Symbol *s = symtab->addSymbol(
          Undefined{this, name, sym.getBinding(), sym.st_other, sym.getType()});
      s->exportDynamic = true;
      continue;
    }

    // MIPS BFD linker puts _gp_disp symbol into DSO files and incorrectly
    // assigns VER_NDX_LOCAL to this section global symbol. Here is a
    // workaround for this bug.
    uint32_t idx = versyms[i] & ~VERSYM_HIDDEN;
    if (config->emachine == EM_MIPS && idx == VER_NDX_LOCAL &&
        name == "_gp_disp")
      continue;

    uint32_t alignment = getAlignment<ELFT>(sections, sym);
    if (!(versyms[i] & VERSYM_HIDDEN)) {
      symtab->addSymbol(SharedSymbol{*this, name, sym.getBinding(),
                                     sym.st_other, sym.getType(), sym.st_value,
                                     sym.st_size, alignment, idx});
    }

    // Also add the symbol with the versioned name to handle undefined symbols
    // with explicit versions.
    if (idx == VER_NDX_GLOBAL)
      continue;

    if (idx >= verdefs.size() || idx == VER_NDX_LOCAL) {
      error("corrupt input file: version definition index " + Twine(idx) +
            " for symbol " + name + " is out of bounds\n>>> defined in " +
            toString(this));
      continue;
    }

    StringRef verName =
        this->stringTable.data() +
        reinterpret_cast<const Elf_Verdef *>(verdefs[idx])->getAux()->vda_name;
    versionedNameBuffer.clear();
    name = (name + "@" + verName).toStringRef(versionedNameBuffer);
    symtab->addSymbol(SharedSymbol{*this, saver.save(name), sym.getBinding(),
                                   sym.st_other, sym.getType(), sym.st_value,
                                   sym.st_size, alignment, idx});
  }
}

static ELFKind getBitcodeELFKind(const Triple &t) {
  if (t.isLittleEndian())
    return t.isArch64Bit() ? ELF64LEKind : ELF32LEKind;
  return t.isArch64Bit() ? ELF64BEKind : ELF32BEKind;
}

static uint8_t getBitcodeMachineKind(StringRef path, const Triple &t) {
  switch (t.getArch()) {
  case Triple::aarch64:
    return EM_AARCH64;
  case Triple::amdgcn:
  case Triple::r600:
    return EM_AMDGPU;
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
  case Triple::msp430:
    return EM_MSP430;
  case Triple::ppc:
    return EM_PPC;
  case Triple::ppc64:
  case Triple::ppc64le:
    return EM_PPC64;
  case Triple::riscv32:
  case Triple::riscv64:
    return EM_RISCV;
  case Triple::x86:
    return t.isOSIAMCU() ? EM_IAMCU : EM_386;
  case Triple::x86_64:
    return EM_X86_64;
  default:
    error(path + ": could not infer e_machine from bitcode target triple " +
          t.str());
    return EM_NONE;
  }
}

BitcodeFile::BitcodeFile(MemoryBufferRef mb, StringRef archiveName,
                         uint64_t offsetInArchive)
    : InputFile(BitcodeKind, mb) {
  this->archiveName = archiveName;

  std::string path = mb.getBufferIdentifier().str();
  if (config->thinLTOIndexOnly)
    path = replaceThinLTOSuffix(mb.getBufferIdentifier());

  // ThinLTO assumes that all MemoryBufferRefs given to it have a unique
  // name. If two archives define two members with the same name, this
  // causes a collision which result in only one of the objects being taken
  // into consideration at LTO time (which very likely causes undefined
  // symbols later in the link stage). So we append file offset to make
  // filename unique.
  StringRef name = archiveName.empty()
                       ? saver.save(path)
                       : saver.save(archiveName + "(" + path + " at " +
                                    utostr(offsetInArchive) + ")");
  MemoryBufferRef mbref(mb.getBuffer(), name);

  obj = CHECK(lto::InputFile::create(mbref), this);

  Triple t(obj->getTargetTriple());
  ekind = getBitcodeELFKind(t);
  emachine = getBitcodeMachineKind(mb.getBufferIdentifier(), t);
}

static uint8_t mapVisibility(GlobalValue::VisibilityTypes gvVisibility) {
  switch (gvVisibility) {
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
static Symbol *createBitcodeSymbol(const std::vector<bool> &keptComdats,
                                   const lto::InputFile::Symbol &objSym,
                                   BitcodeFile &f) {
  StringRef name = saver.save(objSym.getName());
  uint8_t binding = objSym.isWeak() ? STB_WEAK : STB_GLOBAL;
  uint8_t type = objSym.isTLS() ? STT_TLS : STT_NOTYPE;
  uint8_t visibility = mapVisibility(objSym.getVisibility());
  bool canOmitFromDynSym = objSym.canBeOmittedFromSymbolTable();

  int c = objSym.getComdatIndex();
  if (objSym.isUndefined() || (c != -1 && !keptComdats[c])) {
    Undefined New(&f, name, binding, visibility, type);
    if (canOmitFromDynSym)
      New.exportDynamic = false;
    return symtab->addSymbol(New);
  }

  if (objSym.isCommon())
    return symtab->addSymbol(
        CommonSymbol{&f, name, binding, visibility, STT_OBJECT,
                     objSym.getCommonAlignment(), objSym.getCommonSize()});

  Defined New(&f, name, binding, visibility, type, 0, 0, nullptr);
  if (canOmitFromDynSym)
    New.exportDynamic = false;
  return symtab->addSymbol(New);
}

template <class ELFT> void BitcodeFile::parse() {
  std::vector<bool> keptComdats;
  for (StringRef s : obj->getComdatTable())
    keptComdats.push_back(
        symtab->comdatGroups.try_emplace(CachedHashStringRef(s), this).second);

  for (const lto::InputFile::Symbol &objSym : obj->symbols())
    symbols.push_back(createBitcodeSymbol<ELFT>(keptComdats, objSym, *this));

  for (auto l : obj->getDependentLibraries())
    addDependentLibrary(l, this);
}

void BinaryFile::parse() {
  ArrayRef<uint8_t> data = arrayRefFromStringRef(mb.getBuffer());
  auto *section = make<InputSection>(this, SHF_ALLOC | SHF_WRITE, SHT_PROGBITS,
                                     8, data, ".data");
  sections.push_back(section);

  // For each input file foo that is embedded to a result as a binary
  // blob, we define _binary_foo_{start,end,size} symbols, so that
  // user programs can access blobs by name. Non-alphanumeric
  // characters in a filename are replaced with underscore.
  std::string s = "_binary_" + mb.getBufferIdentifier().str();
  for (size_t i = 0; i < s.size(); ++i)
    if (!isAlnum(s[i]))
      s[i] = '_';

  symtab->addSymbol(Defined{nullptr, saver.save(s + "_start"), STB_GLOBAL,
                            STV_DEFAULT, STT_OBJECT, 0, 0, section});
  symtab->addSymbol(Defined{nullptr, saver.save(s + "_end"), STB_GLOBAL,
                            STV_DEFAULT, STT_OBJECT, data.size(), 0, section});
  symtab->addSymbol(Defined{nullptr, saver.save(s + "_size"), STB_GLOBAL,
                            STV_DEFAULT, STT_OBJECT, data.size(), 0, nullptr});
}

InputFile *elf::createObjectFile(MemoryBufferRef mb, StringRef archiveName,
                                 uint64_t offsetInArchive) {
  if (isBitcode(mb))
    return make<BitcodeFile>(mb, archiveName, offsetInArchive);

  switch (getELFKind(mb, archiveName)) {
  case ELF32LEKind:
    return make<ObjFile<ELF32LE>>(mb, archiveName);
  case ELF32BEKind:
    return make<ObjFile<ELF32BE>>(mb, archiveName);
  case ELF64LEKind:
    return make<ObjFile<ELF64LE>>(mb, archiveName);
  case ELF64BEKind:
    return make<ObjFile<ELF64BE>>(mb, archiveName);
  default:
    llvm_unreachable("getELFKind");
  }
}

void LazyObjFile::fetch() {
  if (mb.getBuffer().empty())
    return;

  InputFile *file = createObjectFile(mb, archiveName, offsetInArchive);
  file->groupId = groupId;

  mb = {};

  // Copy symbol vector so that the new InputFile doesn't have to
  // insert the same defined symbols to the symbol table again.
  file->symbols = std::move(symbols);

  parseFile(file);
}

template <class ELFT> void LazyObjFile::parse() {
  using Elf_Sym = typename ELFT::Sym;

  // A lazy object file wraps either a bitcode file or an ELF file.
  if (isBitcode(this->mb)) {
    std::unique_ptr<lto::InputFile> obj =
        CHECK(lto::InputFile::create(this->mb), this);
    for (const lto::InputFile::Symbol &sym : obj->symbols()) {
      if (sym.isUndefined())
        continue;
      symtab->addSymbol(LazyObject{*this, saver.save(sym.getName())});
    }
    return;
  }

  if (getELFKind(this->mb, archiveName) != config->ekind) {
    error("incompatible file: " + this->mb.getBufferIdentifier());
    return;
  }

  // Find a symbol table.
  ELFFile<ELFT> obj = check(ELFFile<ELFT>::create(mb.getBuffer()));
  ArrayRef<typename ELFT::Shdr> sections = CHECK(obj.sections(), this);

  for (const typename ELFT::Shdr &sec : sections) {
    if (sec.sh_type != SHT_SYMTAB)
      continue;

    // A symbol table is found.
    ArrayRef<Elf_Sym> eSyms = CHECK(obj.symbols(&sec), this);
    uint32_t firstGlobal = sec.sh_info;
    StringRef strtab = CHECK(obj.getStringTableForSymtab(sec, sections), this);
    this->symbols.resize(eSyms.size());

    // Get existing symbols or insert placeholder symbols.
    for (size_t i = firstGlobal, end = eSyms.size(); i != end; ++i)
      if (eSyms[i].st_shndx != SHN_UNDEF)
        this->symbols[i] = symtab->insert(CHECK(eSyms[i].getName(strtab), this));

    // Replace existing symbols with LazyObject symbols.
    //
    // resolve() may trigger this->fetch() if an existing symbol is an
    // undefined symbol. If that happens, this LazyObjFile has served
    // its purpose, and we can exit from the loop early.
    for (Symbol *sym : this->symbols) {
      if (!sym)
        continue;
      sym->resolve(LazyObject{*this, sym->getName()});

      // MemoryBuffer is emptied if this file is instantiated as ObjFile.
      if (mb.getBuffer().empty())
        return;
    }
    return;
  }
}

std::string elf::replaceThinLTOSuffix(StringRef path) {
  StringRef suffix = config->thinLTOObjectSuffixReplace.first;
  StringRef repl = config->thinLTOObjectSuffixReplace.second;

  if (path.consume_back(suffix))
    return (path + repl).str();
  return path;
}

template void BitcodeFile::parse<ELF32LE>();
template void BitcodeFile::parse<ELF32BE>();
template void BitcodeFile::parse<ELF64LE>();
template void BitcodeFile::parse<ELF64BE>();

template void LazyObjFile::parse<ELF32LE>();
template void LazyObjFile::parse<ELF32BE>();
template void LazyObjFile::parse<ELF64LE>();
template void LazyObjFile::parse<ELF64BE>();

template class elf::ObjFile<ELF32LE>;
template class elf::ObjFile<ELF32BE>;
template class elf::ObjFile<ELF64LE>;
template class elf::ObjFile<ELF64BE>;

template void SharedFile::parse<ELF32LE>();
template void SharedFile::parse<ELF32BE>();
template void SharedFile::parse<ELF64LE>();
template void SharedFile::parse<ELF64BE>();
