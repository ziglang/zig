//===- Writer.cpp ---------------------------------------------------------===//
//
//                             The LLVM Linker
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//

#include "Writer.h"
#include "Config.h"
#include "DLL.h"
#include "Error.h"
#include "InputFiles.h"
#include "MapFile.h"
#include "Memory.h"
#include "PDB.h"
#include "SymbolTable.h"
#include "Symbols.h"
#include "llvm/ADT/DenseMap.h"
#include "llvm/ADT/STLExtras.h"
#include "llvm/ADT/StringSwitch.h"
#include "llvm/Support/Debug.h"
#include "llvm/Support/Endian.h"
#include "llvm/Support/FileOutputBuffer.h"
#include "llvm/Support/Parallel.h"
#include "llvm/Support/RandomNumberGenerator.h"
#include "llvm/Support/raw_ostream.h"
#include <algorithm>
#include <cstdio>
#include <map>
#include <memory>
#include <utility>

using namespace llvm;
using namespace llvm::COFF;
using namespace llvm::object;
using namespace llvm::support;
using namespace llvm::support::endian;
using namespace lld;
using namespace lld::coff;

static const int SectorSize = 512;
static const int DOSStubSize = 64;
static const int NumberfOfDataDirectory = 16;

namespace {

class DebugDirectoryChunk : public Chunk {
public:
  DebugDirectoryChunk(const std::vector<Chunk *> &R) : Records(R) {}

  size_t getSize() const override {
    return Records.size() * sizeof(debug_directory);
  }

  void writeTo(uint8_t *B) const override {
    auto *D = reinterpret_cast<debug_directory *>(B + OutputSectionOff);

    for (const Chunk *Record : Records) {
      D->Characteristics = 0;
      D->TimeDateStamp = 0;
      D->MajorVersion = 0;
      D->MinorVersion = 0;
      D->Type = COFF::IMAGE_DEBUG_TYPE_CODEVIEW;
      D->SizeOfData = Record->getSize();
      D->AddressOfRawData = Record->getRVA();
      // TODO(compnerd) get the file offset
      D->PointerToRawData = 0;

      ++D;
    }
  }

private:
  const std::vector<Chunk *> &Records;
};

class CVDebugRecordChunk : public Chunk {
  size_t getSize() const override {
    return sizeof(codeview::DebugInfo) + Config->PDBPath.size() + 1;
  }

  void writeTo(uint8_t *B) const override {
    // Save off the DebugInfo entry to backfill the file signature (build id)
    // in Writer::writeBuildId
    DI = reinterpret_cast<codeview::DebugInfo *>(B + OutputSectionOff);

    DI->Signature.CVSignature = OMF::Signature::PDB70;

    // variable sized field (PDB Path)
    auto *P = reinterpret_cast<char *>(B + OutputSectionOff + sizeof(*DI));
    if (!Config->PDBPath.empty())
      memcpy(P, Config->PDBPath.data(), Config->PDBPath.size());
    P[Config->PDBPath.size()] = '\0';
  }

public:
  mutable codeview::DebugInfo *DI = nullptr;
};

// The writer writes a SymbolTable result to a file.
class Writer {
public:
  Writer(SymbolTable *T) : Symtab(T) {}
  void run();

private:
  void createSections();
  void createMiscChunks();
  void createImportTables();
  void createExportTable();
  void assignAddresses();
  void removeEmptySections();
  void createSymbolAndStringTable();
  void openFile(StringRef OutputPath);
  template <typename PEHeaderTy> void writeHeader();
  void fixSafeSEHSymbols();
  void setSectionPermissions();
  void writeSections();
  void sortExceptionTable();
  void writeBuildId();

  llvm::Optional<coff_symbol16> createSymbol(Defined *D);
  size_t addEntryToStringTable(StringRef Str);

  OutputSection *findSection(StringRef Name);
  OutputSection *createSection(StringRef Name);
  void addBaserels(OutputSection *Dest);
  void addBaserelBlocks(OutputSection *Dest, std::vector<Baserel> &V);

  uint32_t getSizeOfInitializedData();
  std::map<StringRef, std::vector<DefinedImportData *>> binImports();

  SymbolTable *Symtab;
  std::unique_ptr<FileOutputBuffer> Buffer;
  std::vector<OutputSection *> OutputSections;
  std::vector<char> Strtab;
  std::vector<llvm::object::coff_symbol16> OutputSymtab;
  IdataContents Idata;
  DelayLoadContents DelayIdata;
  EdataContents Edata;
  SEHTableChunk *SEHTable = nullptr;

  Chunk *DebugDirectory = nullptr;
  std::vector<Chunk *> DebugRecords;
  CVDebugRecordChunk *BuildId = nullptr;
  ArrayRef<uint8_t> SectionTable;

  uint64_t FileSize;
  uint32_t PointerToSymbolTable = 0;
  uint64_t SizeOfImage;
  uint64_t SizeOfHeaders;
};
} // anonymous namespace

namespace lld {
namespace coff {

void writeResult(SymbolTable *T) { Writer(T).run(); }

void OutputSection::setRVA(uint64_t RVA) {
  Header.VirtualAddress = RVA;
  for (Chunk *C : Chunks)
    C->setRVA(C->getRVA() + RVA);
}

void OutputSection::setFileOffset(uint64_t Off) {
  // If a section has no actual data (i.e. BSS section), we want to
  // set 0 to its PointerToRawData. Otherwise the output is rejected
  // by the loader.
  if (Header.SizeOfRawData == 0)
    return;
  Header.PointerToRawData = Off;
}

void OutputSection::addChunk(Chunk *C) {
  Chunks.push_back(C);
  C->setOutputSection(this);
  uint64_t Off = Header.VirtualSize;
  Off = alignTo(Off, C->getAlign());
  C->setRVA(Off);
  C->OutputSectionOff = Off;
  Off += C->getSize();
  Header.VirtualSize = Off;
  if (C->hasData())
    Header.SizeOfRawData = alignTo(Off, SectorSize);
}

void OutputSection::addPermissions(uint32_t C) {
  Header.Characteristics |= C & PermMask;
}

void OutputSection::setPermissions(uint32_t C) {
  Header.Characteristics = C & PermMask;
}

// Write the section header to a given buffer.
void OutputSection::writeHeaderTo(uint8_t *Buf) {
  auto *Hdr = reinterpret_cast<coff_section *>(Buf);
  *Hdr = Header;
  if (StringTableOff) {
    // If name is too long, write offset into the string table as a name.
    sprintf(Hdr->Name, "/%d", StringTableOff);
  } else {
    assert(!Config->Debug || Name.size() <= COFF::NameSize);
    strncpy(Hdr->Name, Name.data(),
            std::min(Name.size(), (size_t)COFF::NameSize));
  }
}

} // namespace coff
} // namespace lld

// The main function of the writer.
void Writer::run() {
  createSections();
  createMiscChunks();
  createImportTables();
  createExportTable();
  if (Config->Relocatable)
    createSection(".reloc");
  assignAddresses();
  removeEmptySections();
  setSectionPermissions();
  createSymbolAndStringTable();
  openFile(Config->OutputFile);
  if (Config->is64()) {
    writeHeader<pe32plus_header>();
  } else {
    writeHeader<pe32_header>();
  }
  fixSafeSEHSymbols();
  writeSections();
  sortExceptionTable();
  writeBuildId();

  if (!Config->PDBPath.empty() && Config->Debug) {
    const llvm::codeview::DebugInfo *DI = nullptr;
    if (Config->DebugTypes & static_cast<unsigned>(coff::DebugType::CV))
      DI = BuildId->DI;
    createPDB(Symtab, SectionTable, DI);
  }

  writeMapFile(OutputSections);

  if (auto EC = Buffer->commit())
    fatal(EC, "failed to write the output file");
}

static StringRef getOutputSection(StringRef Name) {
  StringRef S = Name.split('$').first;
  auto It = Config->Merge.find(S);
  if (It == Config->Merge.end())
    return S;
  return It->second;
}

// Create output section objects and add them to OutputSections.
void Writer::createSections() {
  // First, bin chunks by name.
  std::map<StringRef, std::vector<Chunk *>> Map;
  for (Chunk *C : Symtab->getChunks()) {
    auto *SC = dyn_cast<SectionChunk>(C);
    if (SC && !SC->isLive()) {
      if (Config->Verbose)
        SC->printDiscardedMessage();
      continue;
    }
    Map[C->getSectionName()].push_back(C);
  }

  // Then create an OutputSection for each section.
  // '$' and all following characters in input section names are
  // discarded when determining output section. So, .text$foo
  // contributes to .text, for example. See PE/COFF spec 3.2.
  SmallDenseMap<StringRef, OutputSection *> Sections;
  for (auto Pair : Map) {
    StringRef Name = getOutputSection(Pair.first);
    OutputSection *&Sec = Sections[Name];
    if (!Sec) {
      Sec = make<OutputSection>(Name);
      OutputSections.push_back(Sec);
    }
    std::vector<Chunk *> &Chunks = Pair.second;
    for (Chunk *C : Chunks) {
      Sec->addChunk(C);
      Sec->addPermissions(C->getPermissions());
    }
  }
}

void Writer::createMiscChunks() {
  OutputSection *RData = createSection(".rdata");

  // Create thunks for locally-dllimported symbols.
  if (!Symtab->LocalImportChunks.empty()) {
    for (Chunk *C : Symtab->LocalImportChunks)
      RData->addChunk(C);
  }

  // Create Debug Information Chunks
  if (Config->Debug) {
    DebugDirectory = make<DebugDirectoryChunk>(DebugRecords);

    // TODO(compnerd) create a coffgrp entry if DebugType::CV is not enabled
    if (Config->DebugTypes & static_cast<unsigned>(coff::DebugType::CV)) {
      auto *Chunk = make<CVDebugRecordChunk>();

      BuildId = Chunk;
      DebugRecords.push_back(Chunk);
    }

    RData->addChunk(DebugDirectory);
    for (Chunk *C : DebugRecords)
      RData->addChunk(C);
  }

  // Create SEH table. x86-only.
  if (Config->Machine != I386)
    return;

  std::set<Defined *> Handlers;

  for (lld::coff::ObjectFile *File : Symtab->ObjectFiles) {
    if (!File->SEHCompat)
      return;
    for (SymbolBody *B : File->SEHandlers) {
      // Make sure the handler is still live. Assume all handlers are regular
      // symbols.
      auto *D = dyn_cast<DefinedRegular>(B);
      if (D && D->getChunk()->isLive())
        Handlers.insert(D);
    }
  }

  if (!Handlers.empty()) {
    SEHTable = make<SEHTableChunk>(Handlers);
    RData->addChunk(SEHTable);
  }
}

// Create .idata section for the DLL-imported symbol table.
// The format of this section is inherently Windows-specific.
// IdataContents class abstracted away the details for us,
// so we just let it create chunks and add them to the section.
void Writer::createImportTables() {
  if (Symtab->ImportFiles.empty())
    return;

  // Initialize DLLOrder so that import entries are ordered in
  // the same order as in the command line. (That affects DLL
  // initialization order, and this ordering is MSVC-compatible.)
  for (ImportFile *File : Symtab->ImportFiles) {
    if (!File->Live)
      continue;

    std::string DLL = StringRef(File->DLLName).lower();
    if (Config->DLLOrder.count(DLL) == 0)
      Config->DLLOrder[DLL] = Config->DLLOrder.size();
  }

  OutputSection *Text = createSection(".text");
  for (ImportFile *File : Symtab->ImportFiles) {
    if (!File->Live)
      continue;

    if (DefinedImportThunk *Thunk = File->ThunkSym)
      Text->addChunk(Thunk->getChunk());

    if (Config->DelayLoads.count(StringRef(File->DLLName).lower())) {
      if (!File->ThunkSym)
        fatal("cannot delay-load " + toString(File) +
              " due to import of data: " + toString(*File->ImpSym));
      DelayIdata.add(File->ImpSym);
    } else {
      Idata.add(File->ImpSym);
    }
  }

  if (!Idata.empty()) {
    OutputSection *Sec = createSection(".idata");
    for (Chunk *C : Idata.getChunks())
      Sec->addChunk(C);
  }

  if (!DelayIdata.empty()) {
    Defined *Helper = cast<Defined>(Config->DelayLoadHelper);
    DelayIdata.create(Helper);
    OutputSection *Sec = createSection(".didat");
    for (Chunk *C : DelayIdata.getChunks())
      Sec->addChunk(C);
    Sec = createSection(".data");
    for (Chunk *C : DelayIdata.getDataChunks())
      Sec->addChunk(C);
    Sec = createSection(".text");
    for (Chunk *C : DelayIdata.getCodeChunks())
      Sec->addChunk(C);
  }
}

void Writer::createExportTable() {
  if (Config->Exports.empty())
    return;
  OutputSection *Sec = createSection(".edata");
  for (Chunk *C : Edata.Chunks)
    Sec->addChunk(C);
}

// The Windows loader doesn't seem to like empty sections,
// so we remove them if any.
void Writer::removeEmptySections() {
  auto IsEmpty = [](OutputSection *S) { return S->getVirtualSize() == 0; };
  OutputSections.erase(
      std::remove_if(OutputSections.begin(), OutputSections.end(), IsEmpty),
      OutputSections.end());
  uint32_t Idx = 1;
  for (OutputSection *Sec : OutputSections)
    Sec->SectionIndex = Idx++;
}

size_t Writer::addEntryToStringTable(StringRef Str) {
  assert(Str.size() > COFF::NameSize);
  size_t OffsetOfEntry = Strtab.size() + 4; // +4 for the size field
  Strtab.insert(Strtab.end(), Str.begin(), Str.end());
  Strtab.push_back('\0');
  return OffsetOfEntry;
}

Optional<coff_symbol16> Writer::createSymbol(Defined *Def) {
  // Relative symbols are unrepresentable in a COFF symbol table.
  if (isa<DefinedSynthetic>(Def))
    return None;

  if (auto *D = dyn_cast<DefinedRegular>(Def)) {
    // Don't write dead symbols or symbols in codeview sections to the symbol
    // table.
    if (!D->getChunk()->isLive() || D->getChunk()->isCodeView())
      return None;
  }

  if (auto *Sym = dyn_cast<DefinedImportData>(Def))
    if (!Sym->File->Live)
      return None;

  if (auto *Sym = dyn_cast<DefinedImportThunk>(Def))
    if (!Sym->WrappedSym->File->Live)
      return None;

  coff_symbol16 Sym;
  StringRef Name = Def->getName();
  if (Name.size() > COFF::NameSize) {
    Sym.Name.Offset.Zeroes = 0;
    Sym.Name.Offset.Offset = addEntryToStringTable(Name);
  } else {
    memset(Sym.Name.ShortName, 0, COFF::NameSize);
    memcpy(Sym.Name.ShortName, Name.data(), Name.size());
  }

  if (auto *D = dyn_cast<DefinedCOFF>(Def)) {
    COFFSymbolRef Ref = D->getCOFFSymbol();
    Sym.Type = Ref.getType();
    Sym.StorageClass = Ref.getStorageClass();
  } else {
    Sym.Type = IMAGE_SYM_TYPE_NULL;
    Sym.StorageClass = IMAGE_SYM_CLASS_EXTERNAL;
  }
  Sym.NumberOfAuxSymbols = 0;

  switch (Def->kind()) {
  case SymbolBody::DefinedAbsoluteKind:
    Sym.Value = Def->getRVA();
    Sym.SectionNumber = IMAGE_SYM_ABSOLUTE;
    break;
  default: {
    uint64_t RVA = Def->getRVA();
    OutputSection *Sec = nullptr;
    for (OutputSection *S : OutputSections) {
      if (S->getRVA() > RVA)
        break;
      Sec = S;
    }
    Sym.Value = RVA - Sec->getRVA();
    Sym.SectionNumber = Sec->SectionIndex;
    break;
  }
  }
  return Sym;
}

void Writer::createSymbolAndStringTable() {
  if (!Config->Debug || !Config->WriteSymtab)
    return;

  // Name field in the section table is 8 byte long. Longer names need
  // to be written to the string table. First, construct string table.
  for (OutputSection *Sec : OutputSections) {
    StringRef Name = Sec->getName();
    if (Name.size() <= COFF::NameSize)
      continue;
    Sec->setStringTableOff(addEntryToStringTable(Name));
  }

  for (lld::coff::ObjectFile *File : Symtab->ObjectFiles) {
    for (SymbolBody *B : File->getSymbols()) {
      auto *D = dyn_cast<Defined>(B);
      if (!D || D->WrittenToSymtab)
        continue;
      D->WrittenToSymtab = true;

      if (Optional<coff_symbol16> Sym = createSymbol(D))
        OutputSymtab.push_back(*Sym);
    }
  }

  OutputSection *LastSection = OutputSections.back();
  // We position the symbol table to be adjacent to the end of the last section.
  uint64_t FileOff = LastSection->getFileOff() +
                     alignTo(LastSection->getRawSize(), SectorSize);
  if (!OutputSymtab.empty()) {
    PointerToSymbolTable = FileOff;
    FileOff += OutputSymtab.size() * sizeof(coff_symbol16);
  }
  if (!Strtab.empty())
    FileOff += Strtab.size() + 4;
  FileSize = alignTo(FileOff, SectorSize);
}

// Visits all sections to assign incremental, non-overlapping RVAs and
// file offsets.
void Writer::assignAddresses() {
  SizeOfHeaders = DOSStubSize + sizeof(PEMagic) + sizeof(coff_file_header) +
                  sizeof(data_directory) * NumberfOfDataDirectory +
                  sizeof(coff_section) * OutputSections.size();
  SizeOfHeaders +=
      Config->is64() ? sizeof(pe32plus_header) : sizeof(pe32_header);
  SizeOfHeaders = alignTo(SizeOfHeaders, SectorSize);
  uint64_t RVA = 0x1000; // The first page is kept unmapped.
  FileSize = SizeOfHeaders;
  // Move DISCARDABLE (or non-memory-mapped) sections to the end of file because
  // the loader cannot handle holes.
  std::stable_partition(
      OutputSections.begin(), OutputSections.end(), [](OutputSection *S) {
        return (S->getPermissions() & IMAGE_SCN_MEM_DISCARDABLE) == 0;
      });
  for (OutputSection *Sec : OutputSections) {
    if (Sec->getName() == ".reloc")
      addBaserels(Sec);
    Sec->setRVA(RVA);
    Sec->setFileOffset(FileSize);
    RVA += alignTo(Sec->getVirtualSize(), PageSize);
    FileSize += alignTo(Sec->getRawSize(), SectorSize);
  }
  SizeOfImage = SizeOfHeaders + alignTo(RVA - 0x1000, PageSize);
}

template <typename PEHeaderTy> void Writer::writeHeader() {
  // Write DOS stub
  uint8_t *Buf = Buffer->getBufferStart();
  auto *DOS = reinterpret_cast<dos_header *>(Buf);
  Buf += DOSStubSize;
  DOS->Magic[0] = 'M';
  DOS->Magic[1] = 'Z';
  DOS->AddressOfRelocationTable = sizeof(dos_header);
  DOS->AddressOfNewExeHeader = DOSStubSize;

  // Write PE magic
  memcpy(Buf, PEMagic, sizeof(PEMagic));
  Buf += sizeof(PEMagic);

  // Write COFF header
  auto *COFF = reinterpret_cast<coff_file_header *>(Buf);
  Buf += sizeof(*COFF);
  COFF->Machine = Config->Machine;
  COFF->NumberOfSections = OutputSections.size();
  COFF->Characteristics = IMAGE_FILE_EXECUTABLE_IMAGE;
  if (Config->LargeAddressAware)
    COFF->Characteristics |= IMAGE_FILE_LARGE_ADDRESS_AWARE;
  if (!Config->is64())
    COFF->Characteristics |= IMAGE_FILE_32BIT_MACHINE;
  if (Config->DLL)
    COFF->Characteristics |= IMAGE_FILE_DLL;
  if (!Config->Relocatable)
    COFF->Characteristics |= IMAGE_FILE_RELOCS_STRIPPED;
  COFF->SizeOfOptionalHeader =
      sizeof(PEHeaderTy) + sizeof(data_directory) * NumberfOfDataDirectory;

  // Write PE header
  auto *PE = reinterpret_cast<PEHeaderTy *>(Buf);
  Buf += sizeof(*PE);
  PE->Magic = Config->is64() ? PE32Header::PE32_PLUS : PE32Header::PE32;

  // If {Major,Minor}LinkerVersion is left at 0.0, then for some
  // reason signing the resulting PE file with Authenticode produces a
  // signature that fails to validate on Windows 7 (but is OK on 10).
  // Set it to 14.0, which is what VS2015 outputs, and which avoids
  // that problem.
  PE->MajorLinkerVersion = 14;
  PE->MinorLinkerVersion = 0;

  PE->ImageBase = Config->ImageBase;
  PE->SectionAlignment = PageSize;
  PE->FileAlignment = SectorSize;
  PE->MajorImageVersion = Config->MajorImageVersion;
  PE->MinorImageVersion = Config->MinorImageVersion;
  PE->MajorOperatingSystemVersion = Config->MajorOSVersion;
  PE->MinorOperatingSystemVersion = Config->MinorOSVersion;
  PE->MajorSubsystemVersion = Config->MajorOSVersion;
  PE->MinorSubsystemVersion = Config->MinorOSVersion;
  PE->Subsystem = Config->Subsystem;
  PE->SizeOfImage = SizeOfImage;
  PE->SizeOfHeaders = SizeOfHeaders;
  if (!Config->NoEntry) {
    Defined *Entry = cast<Defined>(Config->Entry);
    PE->AddressOfEntryPoint = Entry->getRVA();
    // Pointer to thumb code must have the LSB set, so adjust it.
    if (Config->Machine == ARMNT)
      PE->AddressOfEntryPoint |= 1;
  }
  PE->SizeOfStackReserve = Config->StackReserve;
  PE->SizeOfStackCommit = Config->StackCommit;
  PE->SizeOfHeapReserve = Config->HeapReserve;
  PE->SizeOfHeapCommit = Config->HeapCommit;

  // Import Descriptor Tables and Import Address Tables are merged
  // in our output. That's not compatible with the Binding feature
  // that is sort of prelinking. Setting this flag to make it clear
  // that our outputs are not for the Binding.
  PE->DLLCharacteristics = IMAGE_DLL_CHARACTERISTICS_NO_BIND;

  if (Config->AppContainer)
    PE->DLLCharacteristics |= IMAGE_DLL_CHARACTERISTICS_APPCONTAINER;
  if (Config->DynamicBase)
    PE->DLLCharacteristics |= IMAGE_DLL_CHARACTERISTICS_DYNAMIC_BASE;
  if (Config->HighEntropyVA)
    PE->DLLCharacteristics |= IMAGE_DLL_CHARACTERISTICS_HIGH_ENTROPY_VA;
  if (Config->NxCompat)
    PE->DLLCharacteristics |= IMAGE_DLL_CHARACTERISTICS_NX_COMPAT;
  if (!Config->AllowIsolation)
    PE->DLLCharacteristics |= IMAGE_DLL_CHARACTERISTICS_NO_ISOLATION;
  if (Config->TerminalServerAware)
    PE->DLLCharacteristics |= IMAGE_DLL_CHARACTERISTICS_TERMINAL_SERVER_AWARE;
  PE->NumberOfRvaAndSize = NumberfOfDataDirectory;
  if (OutputSection *Text = findSection(".text")) {
    PE->BaseOfCode = Text->getRVA();
    PE->SizeOfCode = Text->getRawSize();
  }
  PE->SizeOfInitializedData = getSizeOfInitializedData();

  // Write data directory
  auto *Dir = reinterpret_cast<data_directory *>(Buf);
  Buf += sizeof(*Dir) * NumberfOfDataDirectory;
  if (OutputSection *Sec = findSection(".edata")) {
    Dir[EXPORT_TABLE].RelativeVirtualAddress = Sec->getRVA();
    Dir[EXPORT_TABLE].Size = Sec->getVirtualSize();
  }
  if (!Idata.empty()) {
    Dir[IMPORT_TABLE].RelativeVirtualAddress = Idata.getDirRVA();
    Dir[IMPORT_TABLE].Size = Idata.getDirSize();
    Dir[IAT].RelativeVirtualAddress = Idata.getIATRVA();
    Dir[IAT].Size = Idata.getIATSize();
  }
  if (OutputSection *Sec = findSection(".rsrc")) {
    Dir[RESOURCE_TABLE].RelativeVirtualAddress = Sec->getRVA();
    Dir[RESOURCE_TABLE].Size = Sec->getVirtualSize();
  }
  if (OutputSection *Sec = findSection(".pdata")) {
    Dir[EXCEPTION_TABLE].RelativeVirtualAddress = Sec->getRVA();
    Dir[EXCEPTION_TABLE].Size = Sec->getVirtualSize();
  }
  if (OutputSection *Sec = findSection(".reloc")) {
    Dir[BASE_RELOCATION_TABLE].RelativeVirtualAddress = Sec->getRVA();
    Dir[BASE_RELOCATION_TABLE].Size = Sec->getVirtualSize();
  }
  if (Symbol *Sym = Symtab->findUnderscore("_tls_used")) {
    if (Defined *B = dyn_cast<Defined>(Sym->body())) {
      Dir[TLS_TABLE].RelativeVirtualAddress = B->getRVA();
      Dir[TLS_TABLE].Size = Config->is64()
                                ? sizeof(object::coff_tls_directory64)
                                : sizeof(object::coff_tls_directory32);
    }
  }
  if (Config->Debug) {
    Dir[DEBUG_DIRECTORY].RelativeVirtualAddress = DebugDirectory->getRVA();
    Dir[DEBUG_DIRECTORY].Size = DebugDirectory->getSize();
  }
  if (Symbol *Sym = Symtab->findUnderscore("_load_config_used")) {
    if (auto *B = dyn_cast<DefinedRegular>(Sym->body())) {
      SectionChunk *SC = B->getChunk();
      assert(B->getRVA() >= SC->getRVA());
      uint64_t OffsetInChunk = B->getRVA() - SC->getRVA();
      if (!SC->hasData() || OffsetInChunk + 4 > SC->getSize())
        fatal("_load_config_used is malformed");

      ArrayRef<uint8_t> SecContents = SC->getContents();
      uint32_t LoadConfigSize =
          *reinterpret_cast<const ulittle32_t *>(&SecContents[OffsetInChunk]);
      if (OffsetInChunk + LoadConfigSize > SC->getSize())
        fatal("_load_config_used is too large");
      Dir[LOAD_CONFIG_TABLE].RelativeVirtualAddress = B->getRVA();
      Dir[LOAD_CONFIG_TABLE].Size = LoadConfigSize;
    }
  }
  if (!DelayIdata.empty()) {
    Dir[DELAY_IMPORT_DESCRIPTOR].RelativeVirtualAddress =
        DelayIdata.getDirRVA();
    Dir[DELAY_IMPORT_DESCRIPTOR].Size = DelayIdata.getDirSize();
  }

  // Write section table
  for (OutputSection *Sec : OutputSections) {
    Sec->writeHeaderTo(Buf);
    Buf += sizeof(coff_section);
  }
  SectionTable = ArrayRef<uint8_t>(
      Buf - OutputSections.size() * sizeof(coff_section), Buf);

  if (OutputSymtab.empty())
    return;

  COFF->PointerToSymbolTable = PointerToSymbolTable;
  uint32_t NumberOfSymbols = OutputSymtab.size();
  COFF->NumberOfSymbols = NumberOfSymbols;
  auto *SymbolTable = reinterpret_cast<coff_symbol16 *>(
      Buffer->getBufferStart() + COFF->PointerToSymbolTable);
  for (size_t I = 0; I != NumberOfSymbols; ++I)
    SymbolTable[I] = OutputSymtab[I];
  // Create the string table, it follows immediately after the symbol table.
  // The first 4 bytes is length including itself.
  Buf = reinterpret_cast<uint8_t *>(&SymbolTable[NumberOfSymbols]);
  write32le(Buf, Strtab.size() + 4);
  if (!Strtab.empty())
    memcpy(Buf + 4, Strtab.data(), Strtab.size());
}

void Writer::openFile(StringRef Path) {
  Buffer = check(
      FileOutputBuffer::create(Path, FileSize, FileOutputBuffer::F_executable),
      "failed to open " + Path);
}

void Writer::fixSafeSEHSymbols() {
  if (!SEHTable)
    return;
  // Replace the absolute table symbol with a synthetic symbol pointing to the
  // SEHTable chunk so that we can emit base relocations for it and resolve
  // section relative relocations.
  Symbol *T = Symtab->find("___safe_se_handler_table");
  Symbol *C = Symtab->find("___safe_se_handler_count");
  replaceBody<DefinedSynthetic>(T, T->body()->getName(), SEHTable);
  cast<DefinedAbsolute>(C->body())->setVA(SEHTable->getSize() / 4);
}

// Handles /section options to allow users to overwrite
// section attributes.
void Writer::setSectionPermissions() {
  for (auto &P : Config->Section) {
    StringRef Name = P.first;
    uint32_t Perm = P.second;
    if (auto *Sec = findSection(Name))
      Sec->setPermissions(Perm);
  }
}

// Write section contents to a mmap'ed file.
void Writer::writeSections() {
  // Record the section index that should be used when resolving a section
  // relocation against an absolute symbol.
  DefinedAbsolute::OutputSectionIndex = OutputSections.size() + 1;

  uint8_t *Buf = Buffer->getBufferStart();
  for (OutputSection *Sec : OutputSections) {
    uint8_t *SecBuf = Buf + Sec->getFileOff();
    // Fill gaps between functions in .text with INT3 instructions
    // instead of leaving as NUL bytes (which can be interpreted as
    // ADD instructions).
    if (Sec->getPermissions() & IMAGE_SCN_CNT_CODE)
      memset(SecBuf, 0xCC, Sec->getRawSize());
    for_each(parallel::par, Sec->getChunks().begin(), Sec->getChunks().end(),
             [&](Chunk *C) { C->writeTo(SecBuf); });
  }
}

// Sort .pdata section contents according to PE/COFF spec 5.5.
void Writer::sortExceptionTable() {
  OutputSection *Sec = findSection(".pdata");
  if (!Sec)
    return;
  // We assume .pdata contains function table entries only.
  uint8_t *Begin = Buffer->getBufferStart() + Sec->getFileOff();
  uint8_t *End = Begin + Sec->getVirtualSize();
  if (Config->Machine == AMD64) {
    struct Entry { ulittle32_t Begin, End, Unwind; };
    sort(parallel::par, (Entry *)Begin, (Entry *)End,
         [](const Entry &A, const Entry &B) { return A.Begin < B.Begin; });
    return;
  }
  if (Config->Machine == ARMNT) {
    struct Entry { ulittle32_t Begin, Unwind; };
    sort(parallel::par, (Entry *)Begin, (Entry *)End,
         [](const Entry &A, const Entry &B) { return A.Begin < B.Begin; });
    return;
  }
  errs() << "warning: don't know how to handle .pdata.\n";
}

// Backfill the CVSignature in a PDB70 Debug Record.  This backfilling allows us
// to get reproducible builds.
void Writer::writeBuildId() {
  // There is nothing to backfill if BuildId was not setup.
  if (BuildId == nullptr)
    return;

  assert(BuildId->DI->Signature.CVSignature == OMF::Signature::PDB70 &&
         "only PDB 7.0 is supported");
  assert(sizeof(BuildId->DI->PDB70.Signature) == 16 &&
         "signature size mismatch");

  // Compute an MD5 hash.
  ArrayRef<uint8_t> Buf(Buffer->getBufferStart(), Buffer->getBufferEnd());
  memcpy(BuildId->DI->PDB70.Signature, MD5::hash(Buf).data(), 16);

  // TODO(compnerd) track the Age
  BuildId->DI->PDB70.Age = 1;
}

OutputSection *Writer::findSection(StringRef Name) {
  for (OutputSection *Sec : OutputSections)
    if (Sec->getName() == Name)
      return Sec;
  return nullptr;
}

uint32_t Writer::getSizeOfInitializedData() {
  uint32_t Res = 0;
  for (OutputSection *S : OutputSections)
    if (S->getPermissions() & IMAGE_SCN_CNT_INITIALIZED_DATA)
      Res += S->getRawSize();
  return Res;
}

// Returns an existing section or create a new one if not found.
OutputSection *Writer::createSection(StringRef Name) {
  if (auto *Sec = findSection(Name))
    return Sec;
  const auto DATA = IMAGE_SCN_CNT_INITIALIZED_DATA;
  const auto BSS = IMAGE_SCN_CNT_UNINITIALIZED_DATA;
  const auto CODE = IMAGE_SCN_CNT_CODE;
  const auto DISCARDABLE = IMAGE_SCN_MEM_DISCARDABLE;
  const auto R = IMAGE_SCN_MEM_READ;
  const auto W = IMAGE_SCN_MEM_WRITE;
  const auto X = IMAGE_SCN_MEM_EXECUTE;
  uint32_t Perms = StringSwitch<uint32_t>(Name)
                       .Case(".bss", BSS | R | W)
                       .Case(".data", DATA | R | W)
                       .Cases(".didat", ".edata", ".idata", ".rdata", DATA | R)
                       .Case(".reloc", DATA | DISCARDABLE | R)
                       .Case(".text", CODE | R | X)
                       .Default(0);
  if (!Perms)
    llvm_unreachable("unknown section name");
  auto Sec = make<OutputSection>(Name);
  Sec->addPermissions(Perms);
  OutputSections.push_back(Sec);
  return Sec;
}

// Dest is .reloc section. Add contents to that section.
void Writer::addBaserels(OutputSection *Dest) {
  std::vector<Baserel> V;
  for (OutputSection *Sec : OutputSections) {
    if (Sec == Dest)
      continue;
    // Collect all locations for base relocations.
    for (Chunk *C : Sec->getChunks())
      C->getBaserels(&V);
    // Add the addresses to .reloc section.
    if (!V.empty())
      addBaserelBlocks(Dest, V);
    V.clear();
  }
}

// Add addresses to .reloc section. Note that addresses are grouped by page.
void Writer::addBaserelBlocks(OutputSection *Dest, std::vector<Baserel> &V) {
  const uint32_t Mask = ~uint32_t(PageSize - 1);
  uint32_t Page = V[0].RVA & Mask;
  size_t I = 0, J = 1;
  for (size_t E = V.size(); J < E; ++J) {
    uint32_t P = V[J].RVA & Mask;
    if (P == Page)
      continue;
    Dest->addChunk(make<BaserelChunk>(Page, &V[I], &V[0] + J));
    I = J;
    Page = P;
  }
  if (I == J)
    return;
  Dest->addChunk(make<BaserelChunk>(Page, &V[I], &V[0] + J));
}
