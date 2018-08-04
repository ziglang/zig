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
#include "InputFiles.h"
#include "MapFile.h"
#include "PDB.h"
#include "SymbolTable.h"
#include "Symbols.h"
#include "lld/Common/ErrorHandler.h"
#include "lld/Common/Memory.h"
#include "lld/Common/Timer.h"
#include "llvm/ADT/DenseMap.h"
#include "llvm/ADT/STLExtras.h"
#include "llvm/ADT/StringSwitch.h"
#include "llvm/Support/BinaryStreamReader.h"
#include "llvm/Support/Debug.h"
#include "llvm/Support/Endian.h"
#include "llvm/Support/FileOutputBuffer.h"
#include "llvm/Support/Parallel.h"
#include "llvm/Support/Path.h"
#include "llvm/Support/RandomNumberGenerator.h"
#include "llvm/Support/xxhash.h"
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

/* To re-generate DOSProgram:
$ cat > /tmp/DOSProgram.asm
org 0
        ; Copy cs to ds.
        push cs
        pop ds
        ; Point ds:dx at the $-terminated string.
        mov dx, str
        ; Int 21/AH=09h: Write string to standard output.
        mov ah, 0x9
        int 0x21
        ; Int 21/AH=4Ch: Exit with return code (in AL).
        mov ax, 0x4C01
        int 0x21
str:
        db 'This program cannot be run in DOS mode.$'
align 8, db 0
$ nasm -fbin /tmp/DOSProgram.asm -o /tmp/DOSProgram.bin
$ xxd -i /tmp/DOSProgram.bin
*/
static unsigned char DOSProgram[] = {
  0x0e, 0x1f, 0xba, 0x0e, 0x00, 0xb4, 0x09, 0xcd, 0x21, 0xb8, 0x01, 0x4c,
  0xcd, 0x21, 0x54, 0x68, 0x69, 0x73, 0x20, 0x70, 0x72, 0x6f, 0x67, 0x72,
  0x61, 0x6d, 0x20, 0x63, 0x61, 0x6e, 0x6e, 0x6f, 0x74, 0x20, 0x62, 0x65,
  0x20, 0x72, 0x75, 0x6e, 0x20, 0x69, 0x6e, 0x20, 0x44, 0x4f, 0x53, 0x20,
  0x6d, 0x6f, 0x64, 0x65, 0x2e, 0x24, 0x00, 0x00
};
static_assert(sizeof(DOSProgram) % 8 == 0,
              "DOSProgram size must be multiple of 8");

static const int SectorSize = 512;
static const int DOSStubSize = sizeof(dos_header) + sizeof(DOSProgram);
static_assert(DOSStubSize % 8 == 0, "DOSStub size must be multiple of 8");

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
      OutputSection *OS = Record->getOutputSection();
      uint64_t Offs = OS->getFileOff() + (Record->getRVA() - OS->getRVA());
      D->PointerToRawData = Offs;

      TimeDateStamps.push_back(&D->TimeDateStamp);
      ++D;
    }
  }

  void setTimeDateStamp(uint32_t TimeDateStamp) {
    for (support::ulittle32_t *TDS : TimeDateStamps)
      *TDS = TimeDateStamp;
  }

private:
  mutable std::vector<support::ulittle32_t *> TimeDateStamps;
  const std::vector<Chunk *> &Records;
};

class CVDebugRecordChunk : public Chunk {
public:
  size_t getSize() const override {
    return sizeof(codeview::DebugInfo) + Config->PDBAltPath.size() + 1;
  }

  void writeTo(uint8_t *B) const override {
    // Save off the DebugInfo entry to backfill the file signature (build id)
    // in Writer::writeBuildId
    BuildId = reinterpret_cast<codeview::DebugInfo *>(B + OutputSectionOff);

    // variable sized field (PDB Path)
    char *P = reinterpret_cast<char *>(B + OutputSectionOff + sizeof(*BuildId));
    if (!Config->PDBAltPath.empty())
      memcpy(P, Config->PDBAltPath.data(), Config->PDBAltPath.size());
    P[Config->PDBAltPath.size()] = '\0';
  }

  mutable codeview::DebugInfo *BuildId = nullptr;
};

// The writer writes a SymbolTable result to a file.
class Writer {
public:
  Writer() : Buffer(errorHandler().OutputBuffer) {}
  void run();

private:
  void createSections();
  void createMiscChunks();
  void createImportTables();
  void createExportTable();
  void mergeSections();
  void assignAddresses();
  void removeEmptySections();
  void createSymbolAndStringTable();
  void openFile(StringRef OutputPath);
  template <typename PEHeaderTy> void writeHeader();
  void createSEHTable();
  void createGuardCFTables();
  void markSymbolsForRVATable(ObjFile *File,
                              ArrayRef<SectionChunk *> SymIdxChunks,
                              SymbolRVASet &TableSymbols);
  void maybeAddRVATable(SymbolRVASet TableSymbols, StringRef TableSym,
                        StringRef CountSym);
  void setSectionPermissions();
  void writeSections();
  void writeBuildId();
  void sortExceptionTable();

  llvm::Optional<coff_symbol16> createSymbol(Defined *D);
  size_t addEntryToStringTable(StringRef Str);

  OutputSection *findSection(StringRef Name);
  void addBaserels();
  void addBaserelBlocks(std::vector<Baserel> &V);

  uint32_t getSizeOfInitializedData();
  std::map<StringRef, std::vector<DefinedImportData *>> binImports();

  std::unique_ptr<FileOutputBuffer> &Buffer;
  std::vector<OutputSection *> OutputSections;
  std::vector<char> Strtab;
  std::vector<llvm::object::coff_symbol16> OutputSymtab;
  IdataContents Idata;
  DelayLoadContents DelayIdata;
  EdataContents Edata;
  bool SetNoSEHCharacteristic = false;

  DebugDirectoryChunk *DebugDirectory = nullptr;
  std::vector<Chunk *> DebugRecords;
  CVDebugRecordChunk *BuildId = nullptr;
  Optional<codeview::DebugInfo> PreviousBuildId;
  ArrayRef<uint8_t> SectionTable;

  uint64_t FileSize;
  uint32_t PointerToSymbolTable = 0;
  uint64_t SizeOfImage;
  uint64_t SizeOfHeaders;

  OutputSection *TextSec;
  OutputSection *RdataSec;
  OutputSection *BuildidSec;
  OutputSection *DataSec;
  OutputSection *PdataSec;
  OutputSection *IdataSec;
  OutputSection *EdataSec;
  OutputSection *DidatSec;
  OutputSection *RsrcSec;
  OutputSection *RelocSec;

  // The first and last .pdata sections in the output file.
  //
  // We need to keep track of the location of .pdata in whichever section it
  // gets merged into so that we can sort its contents and emit a correct data
  // directory entry for the exception table. This is also the case for some
  // other sections (such as .edata) but because the contents of those sections
  // are entirely linker-generated we can keep track of their locations using
  // the chunks that the linker creates. All .pdata chunks come from input
  // files, so we need to keep track of them separately.
  Chunk *FirstPdata = nullptr;
  Chunk *LastPdata;
};
} // anonymous namespace

namespace lld {
namespace coff {

static Timer CodeLayoutTimer("Code Layout", Timer::root());
static Timer DiskCommitTimer("Commit Output File", Timer::root());

void writeResult() { Writer().run(); }

void OutputSection::addChunk(Chunk *C) {
  Chunks.push_back(C);
  C->setOutputSection(this);
}

void OutputSection::setPermissions(uint32_t C) {
  Header.Characteristics &= ~PermMask;
  Header.Characteristics |= C;
}

void OutputSection::merge(OutputSection *Other) {
  for (Chunk *C : Other->Chunks)
    C->setOutputSection(this);
  Chunks.insert(Chunks.end(), Other->Chunks.begin(), Other->Chunks.end());
  Other->Chunks.clear();
}

// Write the section header to a given buffer.
void OutputSection::writeHeaderTo(uint8_t *Buf) {
  auto *Hdr = reinterpret_cast<coff_section *>(Buf);
  *Hdr = Header;
  if (StringTableOff) {
    // If name is too long, write offset into the string table as a name.
    sprintf(Hdr->Name, "/%d", StringTableOff);
  } else {
    assert(!Config->Debug || Name.size() <= COFF::NameSize ||
           (Hdr->Characteristics & IMAGE_SCN_MEM_DISCARDABLE) == 0);
    strncpy(Hdr->Name, Name.data(),
            std::min(Name.size(), (size_t)COFF::NameSize));
  }
}

} // namespace coff
} // namespace lld

// PDBs are matched against executables using a build id which consists of three
// components:
//   1. A 16-bit GUID
//   2. An age
//   3. A time stamp.
//
// Debuggers and symbol servers match executables against debug info by checking
// each of these components of the EXE/DLL against the corresponding value in
// the PDB and failing a match if any of the components differ.  In the case of
// symbol servers, symbols are cached in a folder that is a function of the
// GUID.  As a result, in order to avoid symbol cache pollution where every
// incremental build copies a new PDB to the symbol cache, we must try to re-use
// the existing GUID if one exists, but bump the age.  This way the match will
// fail, so the symbol cache knows to use the new PDB, but the GUID matches, so
// it overwrites the existing item in the symbol cache rather than making a new
// one.
static Optional<codeview::DebugInfo> loadExistingBuildId(StringRef Path) {
  // We don't need to incrementally update a previous build id if we're not
  // writing codeview debug info.
  if (!Config->Debug)
    return None;

  auto ExpectedBinary = llvm::object::createBinary(Path);
  if (!ExpectedBinary) {
    consumeError(ExpectedBinary.takeError());
    return None;
  }

  auto Binary = std::move(*ExpectedBinary);
  if (!Binary.getBinary()->isCOFF())
    return None;

  std::error_code EC;
  COFFObjectFile File(Binary.getBinary()->getMemoryBufferRef(), EC);
  if (EC)
    return None;

  // If the machine of the binary we're outputting doesn't match the machine
  // of the existing binary, don't try to re-use the build id.
  if (File.is64() != Config->is64() || File.getMachine() != Config->Machine)
    return None;

  for (const auto &DebugDir : File.debug_directories()) {
    if (DebugDir.Type != IMAGE_DEBUG_TYPE_CODEVIEW)
      continue;

    const codeview::DebugInfo *ExistingDI = nullptr;
    StringRef PDBFileName;
    if (auto EC = File.getDebugPDBInfo(ExistingDI, PDBFileName)) {
      (void)EC;
      return None;
    }
    // We only support writing PDBs in v70 format.  So if this is not a build
    // id that we recognize / support, ignore it.
    if (ExistingDI->Signature.CVSignature != OMF::Signature::PDB70)
      return None;
    return *ExistingDI;
  }
  return None;
}

// The main function of the writer.
void Writer::run() {
  ScopedTimer T1(CodeLayoutTimer);

  createSections();
  createMiscChunks();
  createImportTables();
  createExportTable();
  mergeSections();
  assignAddresses();
  removeEmptySections();
  setSectionPermissions();
  createSymbolAndStringTable();

  if (FileSize > UINT32_MAX)
    fatal("image size (" + Twine(FileSize) + ") " +
        "exceeds maximum allowable size (" + Twine(UINT32_MAX) + ")");

  // We must do this before opening the output file, as it depends on being able
  // to read the contents of the existing output file.
  PreviousBuildId = loadExistingBuildId(Config->OutputFile);
  openFile(Config->OutputFile);
  if (Config->is64()) {
    writeHeader<pe32plus_header>();
  } else {
    writeHeader<pe32_header>();
  }
  writeSections();
  sortExceptionTable();
  writeBuildId();

  T1.stop();

  if (!Config->PDBPath.empty() && Config->Debug) {
    assert(BuildId);
    createPDB(Symtab, OutputSections, SectionTable, *BuildId->BuildId);
  }

  writeMapFile(OutputSections);

  ScopedTimer T2(DiskCommitTimer);
  if (auto E = Buffer->commit())
    fatal("failed to write the output file: " + toString(std::move(E)));
}

static StringRef getOutputSectionName(StringRef Name) {
  StringRef S = Name.split('$').first;

  // Treat a later period as a separator for MinGW, for sections like
  // ".ctors.01234".
  return S.substr(0, S.find('.', 1));
}

// For /order.
static void sortBySectionOrder(std::vector<Chunk *> &Chunks) {
  auto GetPriority = [](const Chunk *C) {
    if (auto *Sec = dyn_cast<SectionChunk>(C))
      if (Sec->Sym)
        return Config->Order.lookup(Sec->Sym->getName());
    return 0;
  };

  std::stable_sort(Chunks.begin(), Chunks.end(),
                   [=](const Chunk *A, const Chunk *B) {
                     return GetPriority(A) < GetPriority(B);
                   });
}

// Create output section objects and add them to OutputSections.
void Writer::createSections() {
  // First, create the builtin sections.
  const uint32_t DATA = IMAGE_SCN_CNT_INITIALIZED_DATA;
  const uint32_t BSS = IMAGE_SCN_CNT_UNINITIALIZED_DATA;
  const uint32_t CODE = IMAGE_SCN_CNT_CODE;
  const uint32_t DISCARDABLE = IMAGE_SCN_MEM_DISCARDABLE;
  const uint32_t R = IMAGE_SCN_MEM_READ;
  const uint32_t W = IMAGE_SCN_MEM_WRITE;
  const uint32_t X = IMAGE_SCN_MEM_EXECUTE;

  SmallDenseMap<std::pair<StringRef, uint32_t>, OutputSection *> Sections;
  auto CreateSection = [&](StringRef Name, uint32_t OutChars) {
    OutputSection *&Sec = Sections[{Name, OutChars}];
    if (!Sec) {
      Sec = make<OutputSection>(Name, OutChars);
      OutputSections.push_back(Sec);
    }
    return Sec;
  };

  // Try to match the section order used by link.exe.
  TextSec = CreateSection(".text", CODE | R | X);
  CreateSection(".bss", BSS | R | W);
  RdataSec = CreateSection(".rdata", DATA | R);
  BuildidSec = CreateSection(".buildid", DATA | R);
  DataSec = CreateSection(".data", DATA | R | W);
  PdataSec = CreateSection(".pdata", DATA | R);
  IdataSec = CreateSection(".idata", DATA | R);
  EdataSec = CreateSection(".edata", DATA | R);
  DidatSec = CreateSection(".didat", DATA | R);
  RsrcSec = CreateSection(".rsrc", DATA | R);
  RelocSec = CreateSection(".reloc", DATA | DISCARDABLE | R);

  // Then bin chunks by name and output characteristics.
  std::map<std::pair<StringRef, uint32_t>, std::vector<Chunk *>> Map;
  for (Chunk *C : Symtab->getChunks()) {
    auto *SC = dyn_cast<SectionChunk>(C);
    if (SC && !SC->isLive()) {
      if (Config->Verbose)
        SC->printDiscardedMessage();
      continue;
    }
    Map[{C->getSectionName(), C->getOutputCharacteristics()}].push_back(C);
  }

  // Process an /order option.
  if (!Config->Order.empty())
    for (auto &Pair : Map)
      sortBySectionOrder(Pair.second);

  // Then create an OutputSection for each section.
  // '$' and all following characters in input section names are
  // discarded when determining output section. So, .text$foo
  // contributes to .text, for example. See PE/COFF spec 3.2.
  for (auto Pair : Map) {
    StringRef Name = getOutputSectionName(Pair.first.first);
    uint32_t OutChars = Pair.first.second;

    // In link.exe, there is a special case for the I386 target where .CRT
    // sections are treated as if they have output characteristics DATA | R if
    // their characteristics are DATA | R | W. This implements the same special
    // case for all architectures.
    if (Name == ".CRT")
      OutChars = DATA | R;

    OutputSection *Sec = CreateSection(Name, OutChars);
    std::vector<Chunk *> &Chunks = Pair.second;
    for (Chunk *C : Chunks)
      Sec->addChunk(C);
  }

  // Finally, move some output sections to the end.
  auto SectionOrder = [&](OutputSection *S) {
    // Move DISCARDABLE (or non-memory-mapped) sections to the end of file because
    // the loader cannot handle holes. Stripping can remove other discardable ones
    // than .reloc, which is first of them (created early).
    if (S->Header.Characteristics & IMAGE_SCN_MEM_DISCARDABLE)
      return 2;
    // .rsrc should come at the end of the non-discardable sections because its
    // size may change by the Win32 UpdateResources() function, causing
    // subsequent sections to move (see https://crbug.com/827082).
    if (S == RsrcSec)
      return 1;
    return 0;
  };
  std::stable_sort(OutputSections.begin(), OutputSections.end(),
                   [&](OutputSection *S, OutputSection *T) {
                     return SectionOrder(S) < SectionOrder(T);
                   });
}

void Writer::createMiscChunks() {
  for (auto &P : MergeChunk::Instances)
    RdataSec->addChunk(P.second);

  // Create thunks for locally-dllimported symbols.
  if (!Symtab->LocalImportChunks.empty()) {
    for (Chunk *C : Symtab->LocalImportChunks)
      RdataSec->addChunk(C);
  }

  // Create Debug Information Chunks
  if (Config->Debug) {
    DebugDirectory = make<DebugDirectoryChunk>(DebugRecords);

    OutputSection *DebugInfoSec = Config->MinGW ? BuildidSec : RdataSec;

    // Make a CVDebugRecordChunk even when /DEBUG:CV is not specified.  We
    // output a PDB no matter what, and this chunk provides the only means of
    // allowing a debugger to match a PDB and an executable.  So we need it even
    // if we're ultimately not going to write CodeView data to the PDB.
    auto *CVChunk = make<CVDebugRecordChunk>();
    BuildId = CVChunk;
    DebugRecords.push_back(CVChunk);

    DebugInfoSec->addChunk(DebugDirectory);
    for (Chunk *C : DebugRecords)
      DebugInfoSec->addChunk(C);
  }

  // Create SEH table. x86-only.
  if (Config->Machine == I386)
    createSEHTable();

  // Create /guard:cf tables if requested.
  if (Config->GuardCF != GuardCFLevel::Off)
    createGuardCFTables();
}

// Create .idata section for the DLL-imported symbol table.
// The format of this section is inherently Windows-specific.
// IdataContents class abstracted away the details for us,
// so we just let it create chunks and add them to the section.
void Writer::createImportTables() {
  if (ImportFile::Instances.empty())
    return;

  // Initialize DLLOrder so that import entries are ordered in
  // the same order as in the command line. (That affects DLL
  // initialization order, and this ordering is MSVC-compatible.)
  for (ImportFile *File : ImportFile::Instances) {
    if (!File->Live)
      continue;

    std::string DLL = StringRef(File->DLLName).lower();
    if (Config->DLLOrder.count(DLL) == 0)
      Config->DLLOrder[DLL] = Config->DLLOrder.size();

    if (File->ThunkSym) {
      if (!isa<DefinedImportThunk>(File->ThunkSym))
        fatal(toString(*File->ThunkSym) + " was replaced");
      DefinedImportThunk *Thunk = cast<DefinedImportThunk>(File->ThunkSym);
      if (File->ThunkLive)
        TextSec->addChunk(Thunk->getChunk());
    }

    if (File->ImpSym && !isa<DefinedImportData>(File->ImpSym))
      fatal(toString(*File->ImpSym) + " was replaced");
    DefinedImportData *ImpSym = cast_or_null<DefinedImportData>(File->ImpSym);
    if (Config->DelayLoads.count(StringRef(File->DLLName).lower())) {
      if (!File->ThunkSym)
        fatal("cannot delay-load " + toString(File) +
              " due to import of data: " + toString(*ImpSym));
      DelayIdata.add(ImpSym);
    } else {
      Idata.add(ImpSym);
    }
  }

  if (!Idata.empty())
    for (Chunk *C : Idata.getChunks())
      IdataSec->addChunk(C);

  if (!DelayIdata.empty()) {
    Defined *Helper = cast<Defined>(Config->DelayLoadHelper);
    DelayIdata.create(Helper);
    for (Chunk *C : DelayIdata.getChunks())
      DidatSec->addChunk(C);
    for (Chunk *C : DelayIdata.getDataChunks())
      DataSec->addChunk(C);
    for (Chunk *C : DelayIdata.getCodeChunks())
      TextSec->addChunk(C);
  }
}

void Writer::createExportTable() {
  if (Config->Exports.empty())
    return;
  for (Chunk *C : Edata.Chunks)
    EdataSec->addChunk(C);
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
  coff_symbol16 Sym;
  switch (Def->kind()) {
  case Symbol::DefinedAbsoluteKind:
    Sym.Value = Def->getRVA();
    Sym.SectionNumber = IMAGE_SYM_ABSOLUTE;
    break;
  case Symbol::DefinedSyntheticKind:
    // Relative symbols are unrepresentable in a COFF symbol table.
    return None;
  default: {
    // Don't write symbols that won't be written to the output to the symbol
    // table.
    Chunk *C = Def->getChunk();
    if (!C)
      return None;
    OutputSection *OS = C->getOutputSection();
    if (!OS)
      return None;

    Sym.Value = Def->getRVA() - OS->getRVA();
    Sym.SectionNumber = OS->SectionIndex;
    break;
  }
  }

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
  return Sym;
}

void Writer::createSymbolAndStringTable() {
  // PE/COFF images are limited to 8 byte section names. Longer names can be
  // supported by writing a non-standard string table, but this string table is
  // not mapped at runtime and the long names will therefore be inaccessible.
  // link.exe always truncates section names to 8 bytes, whereas binutils always
  // preserves long section names via the string table. LLD adopts a hybrid
  // solution where discardable sections have long names preserved and
  // non-discardable sections have their names truncated, to ensure that any
  // section which is mapped at runtime also has its name mapped at runtime.
  for (OutputSection *Sec : OutputSections) {
    if (Sec->Name.size() <= COFF::NameSize)
      continue;
    if ((Sec->Header.Characteristics & IMAGE_SCN_MEM_DISCARDABLE) == 0)
      continue;
    Sec->setStringTableOff(addEntryToStringTable(Sec->Name));
  }

  if (Config->DebugDwarf || Config->DebugSymtab) {
    for (ObjFile *File : ObjFile::Instances) {
      for (Symbol *B : File->getSymbols()) {
        auto *D = dyn_cast_or_null<Defined>(B);
        if (!D || D->WrittenToSymtab)
          continue;
        D->WrittenToSymtab = true;

        if (Optional<coff_symbol16> Sym = createSymbol(D))
          OutputSymtab.push_back(*Sym);
      }
    }
  }

  if (OutputSymtab.empty() && Strtab.empty())
    return;

  // We position the symbol table to be adjacent to the end of the last section.
  uint64_t FileOff = FileSize;
  PointerToSymbolTable = FileOff;
  FileOff += OutputSymtab.size() * sizeof(coff_symbol16);
  FileOff += 4 + Strtab.size();
  FileSize = alignTo(FileOff, SectorSize);
}

void Writer::mergeSections() {
  if (!PdataSec->getChunks().empty()) {
    FirstPdata = PdataSec->getChunks().front();
    LastPdata = PdataSec->getChunks().back();
  }

  for (auto &P : Config->Merge) {
    StringRef ToName = P.second;
    if (P.first == ToName)
      continue;
    StringSet<> Names;
    while (1) {
      if (!Names.insert(ToName).second)
        fatal("/merge: cycle found for section '" + P.first + "'");
      auto I = Config->Merge.find(ToName);
      if (I == Config->Merge.end())
        break;
      ToName = I->second;
    }
    OutputSection *From = findSection(P.first);
    OutputSection *To = findSection(ToName);
    if (!From)
      continue;
    if (!To) {
      From->Name = ToName;
      continue;
    }
    To->merge(From);
  }
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
  uint64_t RVA = PageSize; // The first page is kept unmapped.
  FileSize = SizeOfHeaders;

  for (OutputSection *Sec : OutputSections) {
    if (Sec == RelocSec)
      addBaserels();
    uint64_t RawSize = 0, VirtualSize = 0;
    Sec->Header.VirtualAddress = RVA;
    for (Chunk *C : Sec->getChunks()) {
      VirtualSize = alignTo(VirtualSize, C->Alignment);
      C->setRVA(RVA + VirtualSize);
      C->OutputSectionOff = VirtualSize;
      C->finalizeContents();
      VirtualSize += C->getSize();
      if (C->hasData())
        RawSize = alignTo(VirtualSize, SectorSize);
    }
    if (VirtualSize > UINT32_MAX)
      error("section larger than 4 GiB: " + Sec->Name);
    Sec->Header.VirtualSize = VirtualSize;
    Sec->Header.SizeOfRawData = RawSize;
    if (RawSize != 0)
      Sec->Header.PointerToRawData = FileSize;
    RVA += alignTo(VirtualSize, PageSize);
    FileSize += alignTo(RawSize, SectorSize);
  }
  SizeOfImage = alignTo(RVA, PageSize);
}

template <typename PEHeaderTy> void Writer::writeHeader() {
  // Write DOS header. For backwards compatibility, the first part of a PE/COFF
  // executable consists of an MS-DOS MZ executable. If the executable is run
  // under DOS, that program gets run (usually to just print an error message).
  // When run under Windows, the loader looks at AddressOfNewExeHeader and uses
  // the PE header instead.
  uint8_t *Buf = Buffer->getBufferStart();
  auto *DOS = reinterpret_cast<dos_header *>(Buf);
  Buf += sizeof(dos_header);
  DOS->Magic[0] = 'M';
  DOS->Magic[1] = 'Z';
  DOS->UsedBytesInTheLastPage = DOSStubSize % 512;
  DOS->FileSizeInPages = divideCeil(DOSStubSize, 512);
  DOS->HeaderSizeInParagraphs = sizeof(dos_header) / 16;

  DOS->AddressOfRelocationTable = sizeof(dos_header);
  DOS->AddressOfNewExeHeader = DOSStubSize;

  // Write DOS program.
  memcpy(Buf, DOSProgram, sizeof(DOSProgram));
  Buf += sizeof(DOSProgram);

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
  if (Config->AppContainer)
    PE->DLLCharacteristics |= IMAGE_DLL_CHARACTERISTICS_APPCONTAINER;
  if (Config->DynamicBase)
    PE->DLLCharacteristics |= IMAGE_DLL_CHARACTERISTICS_DYNAMIC_BASE;
  if (Config->HighEntropyVA)
    PE->DLLCharacteristics |= IMAGE_DLL_CHARACTERISTICS_HIGH_ENTROPY_VA;
  if (!Config->AllowBind)
    PE->DLLCharacteristics |= IMAGE_DLL_CHARACTERISTICS_NO_BIND;
  if (Config->NxCompat)
    PE->DLLCharacteristics |= IMAGE_DLL_CHARACTERISTICS_NX_COMPAT;
  if (!Config->AllowIsolation)
    PE->DLLCharacteristics |= IMAGE_DLL_CHARACTERISTICS_NO_ISOLATION;
  if (Config->GuardCF != GuardCFLevel::Off)
    PE->DLLCharacteristics |= IMAGE_DLL_CHARACTERISTICS_GUARD_CF;
  if (Config->IntegrityCheck)
    PE->DLLCharacteristics |= IMAGE_DLL_CHARACTERISTICS_FORCE_INTEGRITY;
  if (SetNoSEHCharacteristic)
    PE->DLLCharacteristics |= IMAGE_DLL_CHARACTERISTICS_NO_SEH;
  if (Config->TerminalServerAware)
    PE->DLLCharacteristics |= IMAGE_DLL_CHARACTERISTICS_TERMINAL_SERVER_AWARE;
  PE->NumberOfRvaAndSize = NumberfOfDataDirectory;
  if (TextSec->getVirtualSize()) {
    PE->BaseOfCode = TextSec->getRVA();
    PE->SizeOfCode = TextSec->getRawSize();
  }
  PE->SizeOfInitializedData = getSizeOfInitializedData();

  // Write data directory
  auto *Dir = reinterpret_cast<data_directory *>(Buf);
  Buf += sizeof(*Dir) * NumberfOfDataDirectory;
  if (!Config->Exports.empty()) {
    Dir[EXPORT_TABLE].RelativeVirtualAddress = Edata.getRVA();
    Dir[EXPORT_TABLE].Size = Edata.getSize();
  }
  if (!Idata.empty()) {
    Dir[IMPORT_TABLE].RelativeVirtualAddress = Idata.getDirRVA();
    Dir[IMPORT_TABLE].Size = Idata.getDirSize();
    Dir[IAT].RelativeVirtualAddress = Idata.getIATRVA();
    Dir[IAT].Size = Idata.getIATSize();
  }
  if (RsrcSec->getVirtualSize()) {
    Dir[RESOURCE_TABLE].RelativeVirtualAddress = RsrcSec->getRVA();
    Dir[RESOURCE_TABLE].Size = RsrcSec->getVirtualSize();
  }
  if (FirstPdata) {
    Dir[EXCEPTION_TABLE].RelativeVirtualAddress = FirstPdata->getRVA();
    Dir[EXCEPTION_TABLE].Size =
        LastPdata->getRVA() + LastPdata->getSize() - FirstPdata->getRVA();
  }
  if (RelocSec->getVirtualSize()) {
    Dir[BASE_RELOCATION_TABLE].RelativeVirtualAddress = RelocSec->getRVA();
    Dir[BASE_RELOCATION_TABLE].Size = RelocSec->getVirtualSize();
  }
  if (Symbol *Sym = Symtab->findUnderscore("_tls_used")) {
    if (Defined *B = dyn_cast<Defined>(Sym)) {
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
    if (auto *B = dyn_cast<DefinedRegular>(Sym)) {
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

  if (OutputSymtab.empty() && Strtab.empty())
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
  Buffer = CHECK(
      FileOutputBuffer::create(Path, FileSize, FileOutputBuffer::F_executable),
      "failed to open " + Path);
}

void Writer::createSEHTable() {
  // Set the no SEH characteristic on x86 binaries unless we find exception
  // handlers.
  SetNoSEHCharacteristic = true;

  SymbolRVASet Handlers;
  for (ObjFile *File : ObjFile::Instances) {
    // FIXME: We should error here instead of earlier unless /safeseh:no was
    // passed.
    if (!File->hasSafeSEH())
      return;

    markSymbolsForRVATable(File, File->getSXDataChunks(), Handlers);
  }

  // Remove the "no SEH" characteristic if all object files were built with
  // safeseh, we found some exception handlers, and there is a load config in
  // the object.
  SetNoSEHCharacteristic =
      Handlers.empty() || !Symtab->findUnderscore("_load_config_used");

  maybeAddRVATable(std::move(Handlers), "__safe_se_handler_table",
                   "__safe_se_handler_count");
}

// Add a symbol to an RVA set. Two symbols may have the same RVA, but an RVA set
// cannot contain duplicates. Therefore, the set is uniqued by Chunk and the
// symbol's offset into that Chunk.
static void addSymbolToRVASet(SymbolRVASet &RVASet, Defined *S) {
  Chunk *C = S->getChunk();
  if (auto *SC = dyn_cast<SectionChunk>(C))
    C = SC->Repl; // Look through ICF replacement.
  uint32_t Off = S->getRVA() - (C ? C->getRVA() : 0);
  RVASet.insert({C, Off});
}

// Visit all relocations from all section contributions of this object file and
// mark the relocation target as address-taken.
static void markSymbolsWithRelocations(ObjFile *File,
                                       SymbolRVASet &UsedSymbols) {
  for (Chunk *C : File->getChunks()) {
    // We only care about live section chunks. Common chunks and other chunks
    // don't generally contain relocations.
    SectionChunk *SC = dyn_cast<SectionChunk>(C);
    if (!SC || !SC->isLive())
      continue;

    // Look for relocations in this section against symbols in executable output
    // sections.
    for (Symbol *Ref : SC->symbols()) {
      // FIXME: Do further testing to see if the relocation type matters,
      // especially for 32-bit where taking the address of something usually
      // uses an absolute relocation instead of a relative one.
      if (auto *D = dyn_cast_or_null<Defined>(Ref)) {
        Chunk *RefChunk = D->getChunk();
        OutputSection *OS = RefChunk ? RefChunk->getOutputSection() : nullptr;
        if (OS && OS->Header.Characteristics & IMAGE_SCN_MEM_EXECUTE)
          addSymbolToRVASet(UsedSymbols, D);
      }
    }
  }
}

// Create the guard function id table. This is a table of RVAs of all
// address-taken functions. It is sorted and uniqued, just like the safe SEH
// table.
void Writer::createGuardCFTables() {
  SymbolRVASet AddressTakenSyms;
  SymbolRVASet LongJmpTargets;
  for (ObjFile *File : ObjFile::Instances) {
    // If the object was compiled with /guard:cf, the address taken symbols
    // are in .gfids$y sections, and the longjmp targets are in .gljmp$y
    // sections. If the object was not compiled with /guard:cf, we assume there
    // were no setjmp targets, and that all code symbols with relocations are
    // possibly address-taken.
    if (File->hasGuardCF()) {
      markSymbolsForRVATable(File, File->getGuardFidChunks(), AddressTakenSyms);
      markSymbolsForRVATable(File, File->getGuardLJmpChunks(), LongJmpTargets);
    } else {
      markSymbolsWithRelocations(File, AddressTakenSyms);
    }
  }

  // Mark the image entry as address-taken.
  if (Config->Entry)
    addSymbolToRVASet(AddressTakenSyms, cast<Defined>(Config->Entry));

  // Ensure sections referenced in the gfid table are 16-byte aligned.
  for (const ChunkAndOffset &C : AddressTakenSyms)
    if (C.InputChunk->Alignment < 16)
      C.InputChunk->Alignment = 16;

  maybeAddRVATable(std::move(AddressTakenSyms), "__guard_fids_table",
                   "__guard_fids_count");

  // Add the longjmp target table unless the user told us not to.
  if (Config->GuardCF == GuardCFLevel::Full)
    maybeAddRVATable(std::move(LongJmpTargets), "__guard_longjmp_table",
                     "__guard_longjmp_count");

  // Set __guard_flags, which will be used in the load config to indicate that
  // /guard:cf was enabled.
  uint32_t GuardFlags = uint32_t(coff_guard_flags::CFInstrumented) |
                        uint32_t(coff_guard_flags::HasFidTable);
  if (Config->GuardCF == GuardCFLevel::Full)
    GuardFlags |= uint32_t(coff_guard_flags::HasLongJmpTable);
  Symbol *FlagSym = Symtab->findUnderscore("__guard_flags");
  cast<DefinedAbsolute>(FlagSym)->setVA(GuardFlags);
}

// Take a list of input sections containing symbol table indices and add those
// symbols to an RVA table. The challenge is that symbol RVAs are not known and
// depend on the table size, so we can't directly build a set of integers.
void Writer::markSymbolsForRVATable(ObjFile *File,
                                    ArrayRef<SectionChunk *> SymIdxChunks,
                                    SymbolRVASet &TableSymbols) {
  for (SectionChunk *C : SymIdxChunks) {
    // Skip sections discarded by linker GC. This comes up when a .gfids section
    // is associated with something like a vtable and the vtable is discarded.
    // In this case, the associated gfids section is discarded, and we don't
    // mark the virtual member functions as address-taken by the vtable.
    if (!C->isLive())
      continue;

    // Validate that the contents look like symbol table indices.
    ArrayRef<uint8_t> Data = C->getContents();
    if (Data.size() % 4 != 0) {
      warn("ignoring " + C->getSectionName() +
           " symbol table index section in object " + toString(File));
      continue;
    }

    // Read each symbol table index and check if that symbol was included in the
    // final link. If so, add it to the table symbol set.
    ArrayRef<ulittle32_t> SymIndices(
        reinterpret_cast<const ulittle32_t *>(Data.data()), Data.size() / 4);
    ArrayRef<Symbol *> ObjSymbols = File->getSymbols();
    for (uint32_t SymIndex : SymIndices) {
      if (SymIndex >= ObjSymbols.size()) {
        warn("ignoring invalid symbol table index in section " +
             C->getSectionName() + " in object " + toString(File));
        continue;
      }
      if (Symbol *S = ObjSymbols[SymIndex]) {
        if (S->isLive())
          addSymbolToRVASet(TableSymbols, cast<Defined>(S));
      }
    }
  }
}

// Replace the absolute table symbol with a synthetic symbol pointing to
// TableChunk so that we can emit base relocations for it and resolve section
// relative relocations.
void Writer::maybeAddRVATable(SymbolRVASet TableSymbols, StringRef TableSym,
                              StringRef CountSym) {
  if (TableSymbols.empty())
    return;

  RVATableChunk *TableChunk = make<RVATableChunk>(std::move(TableSymbols));
  RdataSec->addChunk(TableChunk);

  Symbol *T = Symtab->findUnderscore(TableSym);
  Symbol *C = Symtab->findUnderscore(CountSym);
  replaceSymbol<DefinedSynthetic>(T, T->getName(), TableChunk);
  cast<DefinedAbsolute>(C)->setVA(TableChunk->getSize() / 4);
}

// Handles /section options to allow users to overwrite
// section attributes.
void Writer::setSectionPermissions() {
  for (auto &P : Config->Section) {
    StringRef Name = P.first;
    uint32_t Perm = P.second;
    for (OutputSection *Sec : OutputSections)
      if (Sec->Name == Name)
        Sec->setPermissions(Perm);
  }
}

// Write section contents to a mmap'ed file.
void Writer::writeSections() {
  // Record the number of sections to apply section index relocations
  // against absolute symbols. See applySecIdx in Chunks.cpp..
  DefinedAbsolute::NumOutputSections = OutputSections.size();

  uint8_t *Buf = Buffer->getBufferStart();
  for (OutputSection *Sec : OutputSections) {
    uint8_t *SecBuf = Buf + Sec->getFileOff();
    // Fill gaps between functions in .text with INT3 instructions
    // instead of leaving as NUL bytes (which can be interpreted as
    // ADD instructions).
    if (Sec->Header.Characteristics & IMAGE_SCN_CNT_CODE)
      memset(SecBuf, 0xCC, Sec->getRawSize());
    for_each(parallel::par, Sec->getChunks().begin(), Sec->getChunks().end(),
             [&](Chunk *C) { C->writeTo(SecBuf); });
  }
}

void Writer::writeBuildId() {
  // There are two important parts to the build ID.
  // 1) If building with debug info, the COFF debug directory contains a
  //    timestamp as well as a Guid and Age of the PDB.
  // 2) In all cases, the PE COFF file header also contains a timestamp.
  // For reproducibility, instead of a timestamp we want to use a hash of the
  // binary, however when building with debug info the hash needs to take into
  // account the debug info, since it's possible to add blank lines to a file
  // which causes the debug info to change but not the generated code.
  //
  // To handle this, we first set the Guid and Age in the debug directory (but
  // only if we're doing a debug build).  Then, we hash the binary (thus causing
  // the hash to change if only the debug info changes, since the Age will be
  // different).  Finally, we write that hash into the debug directory (if
  // present) as well as the COFF file header (always).
  if (Config->Debug) {
    assert(BuildId && "BuildId is not set!");
    if (PreviousBuildId.hasValue()) {
      *BuildId->BuildId = *PreviousBuildId;
      BuildId->BuildId->PDB70.Age = BuildId->BuildId->PDB70.Age + 1;
    } else {
      BuildId->BuildId->Signature.CVSignature = OMF::Signature::PDB70;
      BuildId->BuildId->PDB70.Age = 1;
      llvm::getRandomBytes(BuildId->BuildId->PDB70.Signature, 16);
    }
  }

  // At this point the only fields in the COFF file which remain unset are the
  // "timestamp" in the COFF file header, and the ones in the coff debug
  // directory.  Now we can hash the file and write that hash to the various
  // timestamp fields in the file.
  StringRef OutputFileData(
      reinterpret_cast<const char *>(Buffer->getBufferStart()),
      Buffer->getBufferSize());

  uint32_t Timestamp = Config->Timestamp;
  if (Config->Repro)
    Timestamp = static_cast<uint32_t>(xxHash64(OutputFileData));

  if (DebugDirectory)
    DebugDirectory->setTimeDateStamp(Timestamp);

  uint8_t *Buf = Buffer->getBufferStart();
  Buf += DOSStubSize + sizeof(PEMagic);
  object::coff_file_header *CoffHeader =
      reinterpret_cast<coff_file_header *>(Buf);
  CoffHeader->TimeDateStamp = Timestamp;
}

// Sort .pdata section contents according to PE/COFF spec 5.5.
void Writer::sortExceptionTable() {
  if (!FirstPdata)
    return;
  // We assume .pdata contains function table entries only.
  auto BufAddr = [&](Chunk *C) {
    return Buffer->getBufferStart() + C->getOutputSection()->getFileOff() +
           C->getRVA() - C->getOutputSection()->getRVA();
  };
  uint8_t *Begin = BufAddr(FirstPdata);
  uint8_t *End = BufAddr(LastPdata) + LastPdata->getSize();
  if (Config->Machine == AMD64) {
    struct Entry { ulittle32_t Begin, End, Unwind; };
    sort(parallel::par, (Entry *)Begin, (Entry *)End,
         [](const Entry &A, const Entry &B) { return A.Begin < B.Begin; });
    return;
  }
  if (Config->Machine == ARMNT || Config->Machine == ARM64) {
    struct Entry { ulittle32_t Begin, Unwind; };
    sort(parallel::par, (Entry *)Begin, (Entry *)End,
         [](const Entry &A, const Entry &B) { return A.Begin < B.Begin; });
    return;
  }
  errs() << "warning: don't know how to handle .pdata.\n";
}

OutputSection *Writer::findSection(StringRef Name) {
  for (OutputSection *Sec : OutputSections)
    if (Sec->Name == Name)
      return Sec;
  return nullptr;
}

uint32_t Writer::getSizeOfInitializedData() {
  uint32_t Res = 0;
  for (OutputSection *S : OutputSections)
    if (S->Header.Characteristics & IMAGE_SCN_CNT_INITIALIZED_DATA)
      Res += S->getRawSize();
  return Res;
}

// Add base relocations to .reloc section.
void Writer::addBaserels() {
  if (!Config->Relocatable)
    return;
  std::vector<Baserel> V;
  for (OutputSection *Sec : OutputSections) {
    if (Sec->Header.Characteristics & IMAGE_SCN_MEM_DISCARDABLE)
      continue;
    // Collect all locations for base relocations.
    for (Chunk *C : Sec->getChunks())
      C->getBaserels(&V);
    // Add the addresses to .reloc section.
    if (!V.empty())
      addBaserelBlocks(V);
    V.clear();
  }
}

// Add addresses to .reloc section. Note that addresses are grouped by page.
void Writer::addBaserelBlocks(std::vector<Baserel> &V) {
  const uint32_t Mask = ~uint32_t(PageSize - 1);
  uint32_t Page = V[0].RVA & Mask;
  size_t I = 0, J = 1;
  for (size_t E = V.size(); J < E; ++J) {
    uint32_t P = V[J].RVA & Mask;
    if (P == Page)
      continue;
    RelocSec->addChunk(make<BaserelChunk>(Page, &V[I], &V[0] + J));
    I = J;
    Page = P;
  }
  if (I == J)
    return;
  RelocSec->addChunk(make<BaserelChunk>(Page, &V[I], &V[0] + J));
}
