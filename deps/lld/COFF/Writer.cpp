//===- Writer.cpp ---------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
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
#include "lld/Common/Threads.h"
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
static unsigned char dosProgram[] = {
  0x0e, 0x1f, 0xba, 0x0e, 0x00, 0xb4, 0x09, 0xcd, 0x21, 0xb8, 0x01, 0x4c,
  0xcd, 0x21, 0x54, 0x68, 0x69, 0x73, 0x20, 0x70, 0x72, 0x6f, 0x67, 0x72,
  0x61, 0x6d, 0x20, 0x63, 0x61, 0x6e, 0x6e, 0x6f, 0x74, 0x20, 0x62, 0x65,
  0x20, 0x72, 0x75, 0x6e, 0x20, 0x69, 0x6e, 0x20, 0x44, 0x4f, 0x53, 0x20,
  0x6d, 0x6f, 0x64, 0x65, 0x2e, 0x24, 0x00, 0x00
};
static_assert(sizeof(dosProgram) % 8 == 0,
              "DOSProgram size must be multiple of 8");

static const int dosStubSize = sizeof(dos_header) + sizeof(dosProgram);
static_assert(dosStubSize % 8 == 0, "DOSStub size must be multiple of 8");

static const int numberOfDataDirectory = 16;

// Global vector of all output sections. After output sections are finalized,
// this can be indexed by Chunk::getOutputSection.
static std::vector<OutputSection *> outputSections;

OutputSection *Chunk::getOutputSection() const {
  return osidx == 0 ? nullptr : outputSections[osidx - 1];
}

namespace {

class DebugDirectoryChunk : public NonSectionChunk {
public:
  DebugDirectoryChunk(const std::vector<Chunk *> &r, bool writeRepro)
      : records(r), writeRepro(writeRepro) {}

  size_t getSize() const override {
    return (records.size() + int(writeRepro)) * sizeof(debug_directory);
  }

  void writeTo(uint8_t *b) const override {
    auto *d = reinterpret_cast<debug_directory *>(b);

    for (const Chunk *record : records) {
      OutputSection *os = record->getOutputSection();
      uint64_t offs = os->getFileOff() + (record->getRVA() - os->getRVA());
      fillEntry(d, COFF::IMAGE_DEBUG_TYPE_CODEVIEW, record->getSize(),
                record->getRVA(), offs);
      ++d;
    }

    if (writeRepro) {
      // FIXME: The COFF spec allows either a 0-sized entry to just say
      // "the timestamp field is really a hash", or a 4-byte size field
      // followed by that many bytes containing a longer hash (with the
      // lowest 4 bytes usually being the timestamp in little-endian order).
      // Consider storing the full 8 bytes computed by xxHash64 here.
      fillEntry(d, COFF::IMAGE_DEBUG_TYPE_REPRO, 0, 0, 0);
    }
  }

  void setTimeDateStamp(uint32_t timeDateStamp) {
    for (support::ulittle32_t *tds : timeDateStamps)
      *tds = timeDateStamp;
  }

private:
  void fillEntry(debug_directory *d, COFF::DebugType debugType, size_t size,
                 uint64_t rva, uint64_t offs) const {
    d->Characteristics = 0;
    d->TimeDateStamp = 0;
    d->MajorVersion = 0;
    d->MinorVersion = 0;
    d->Type = debugType;
    d->SizeOfData = size;
    d->AddressOfRawData = rva;
    d->PointerToRawData = offs;

    timeDateStamps.push_back(&d->TimeDateStamp);
  }

  mutable std::vector<support::ulittle32_t *> timeDateStamps;
  const std::vector<Chunk *> &records;
  bool writeRepro;
};

class CVDebugRecordChunk : public NonSectionChunk {
public:
  size_t getSize() const override {
    return sizeof(codeview::DebugInfo) + config->pdbAltPath.size() + 1;
  }

  void writeTo(uint8_t *b) const override {
    // Save off the DebugInfo entry to backfill the file signature (build id)
    // in Writer::writeBuildId
    buildId = reinterpret_cast<codeview::DebugInfo *>(b);

    // variable sized field (PDB Path)
    char *p = reinterpret_cast<char *>(b + sizeof(*buildId));
    if (!config->pdbAltPath.empty())
      memcpy(p, config->pdbAltPath.data(), config->pdbAltPath.size());
    p[config->pdbAltPath.size()] = '\0';
  }

  mutable codeview::DebugInfo *buildId = nullptr;
};

// PartialSection represents a group of chunks that contribute to an
// OutputSection. Collating a collection of PartialSections of same name and
// characteristics constitutes the OutputSection.
class PartialSectionKey {
public:
  StringRef name;
  unsigned characteristics;

  bool operator<(const PartialSectionKey &other) const {
    int c = name.compare(other.name);
    if (c == 1)
      return false;
    if (c == 0)
      return characteristics < other.characteristics;
    return true;
  }
};

// The writer writes a SymbolTable result to a file.
class Writer {
public:
  Writer() : buffer(errorHandler().outputBuffer) {}
  void run();

private:
  void createSections();
  void createMiscChunks();
  void createImportTables();
  void appendImportThunks();
  void locateImportTables();
  void createExportTable();
  void mergeSections();
  void removeUnusedSections();
  void assignAddresses();
  void finalizeAddresses();
  void removeEmptySections();
  void assignOutputSectionIndices();
  void createSymbolAndStringTable();
  void openFile(StringRef outputPath);
  template <typename PEHeaderTy> void writeHeader();
  void createSEHTable();
  void createRuntimePseudoRelocs();
  void insertCtorDtorSymbols();
  void createGuardCFTables();
  void markSymbolsForRVATable(ObjFile *file,
                              ArrayRef<SectionChunk *> symIdxChunks,
                              SymbolRVASet &tableSymbols);
  void maybeAddRVATable(SymbolRVASet tableSymbols, StringRef tableSym,
                        StringRef countSym);
  void setSectionPermissions();
  void writeSections();
  void writeBuildId();
  void sortExceptionTable();
  void sortCRTSectionChunks(std::vector<Chunk *> &chunks);
  void addSyntheticIdata();
  void fixPartialSectionChars(StringRef name, uint32_t chars);
  bool fixGnuImportChunks();
  PartialSection *createPartialSection(StringRef name, uint32_t outChars);
  PartialSection *findPartialSection(StringRef name, uint32_t outChars);

  llvm::Optional<coff_symbol16> createSymbol(Defined *d);
  size_t addEntryToStringTable(StringRef str);

  OutputSection *findSection(StringRef name);
  void addBaserels();
  void addBaserelBlocks(std::vector<Baserel> &v);

  uint32_t getSizeOfInitializedData();

  std::unique_ptr<FileOutputBuffer> &buffer;
  std::map<PartialSectionKey, PartialSection *> partialSections;
  std::vector<char> strtab;
  std::vector<llvm::object::coff_symbol16> outputSymtab;
  IdataContents idata;
  Chunk *importTableStart = nullptr;
  uint64_t importTableSize = 0;
  Chunk *iatStart = nullptr;
  uint64_t iatSize = 0;
  DelayLoadContents delayIdata;
  EdataContents edata;
  bool setNoSEHCharacteristic = false;

  DebugDirectoryChunk *debugDirectory = nullptr;
  std::vector<Chunk *> debugRecords;
  CVDebugRecordChunk *buildId = nullptr;
  ArrayRef<uint8_t> sectionTable;

  uint64_t fileSize;
  uint32_t pointerToSymbolTable = 0;
  uint64_t sizeOfImage;
  uint64_t sizeOfHeaders;

  OutputSection *textSec;
  OutputSection *rdataSec;
  OutputSection *buildidSec;
  OutputSection *dataSec;
  OutputSection *pdataSec;
  OutputSection *idataSec;
  OutputSection *edataSec;
  OutputSection *didatSec;
  OutputSection *rsrcSec;
  OutputSection *relocSec;
  OutputSection *ctorsSec;
  OutputSection *dtorsSec;

  // The first and last .pdata sections in the output file.
  //
  // We need to keep track of the location of .pdata in whichever section it
  // gets merged into so that we can sort its contents and emit a correct data
  // directory entry for the exception table. This is also the case for some
  // other sections (such as .edata) but because the contents of those sections
  // are entirely linker-generated we can keep track of their locations using
  // the chunks that the linker creates. All .pdata chunks come from input
  // files, so we need to keep track of them separately.
  Chunk *firstPdata = nullptr;
  Chunk *lastPdata;
};
} // anonymous namespace

namespace lld {
namespace coff {

static Timer codeLayoutTimer("Code Layout", Timer::root());
static Timer diskCommitTimer("Commit Output File", Timer::root());

void writeResult() { Writer().run(); }

void OutputSection::addChunk(Chunk *c) {
  chunks.push_back(c);
}

void OutputSection::insertChunkAtStart(Chunk *c) {
  chunks.insert(chunks.begin(), c);
}

void OutputSection::setPermissions(uint32_t c) {
  header.Characteristics &= ~permMask;
  header.Characteristics |= c;
}

void OutputSection::merge(OutputSection *other) {
  chunks.insert(chunks.end(), other->chunks.begin(), other->chunks.end());
  other->chunks.clear();
  contribSections.insert(contribSections.end(), other->contribSections.begin(),
                         other->contribSections.end());
  other->contribSections.clear();
}

// Write the section header to a given buffer.
void OutputSection::writeHeaderTo(uint8_t *buf) {
  auto *hdr = reinterpret_cast<coff_section *>(buf);
  *hdr = header;
  if (stringTableOff) {
    // If name is too long, write offset into the string table as a name.
    sprintf(hdr->Name, "/%d", stringTableOff);
  } else {
    assert(!config->debug || name.size() <= COFF::NameSize ||
           (hdr->Characteristics & IMAGE_SCN_MEM_DISCARDABLE) == 0);
    strncpy(hdr->Name, name.data(),
            std::min(name.size(), (size_t)COFF::NameSize));
  }
}

void OutputSection::addContributingPartialSection(PartialSection *sec) {
  contribSections.push_back(sec);
}

} // namespace coff
} // namespace lld

// Check whether the target address S is in range from a relocation
// of type relType at address P.
static bool isInRange(uint16_t relType, uint64_t s, uint64_t p, int margin) {
  if (config->machine == ARMNT) {
    int64_t diff = AbsoluteDifference(s, p + 4) + margin;
    switch (relType) {
    case IMAGE_REL_ARM_BRANCH20T:
      return isInt<21>(diff);
    case IMAGE_REL_ARM_BRANCH24T:
    case IMAGE_REL_ARM_BLX23T:
      return isInt<25>(diff);
    default:
      return true;
    }
  } else if (config->machine == ARM64) {
    int64_t diff = AbsoluteDifference(s, p) + margin;
    switch (relType) {
    case IMAGE_REL_ARM64_BRANCH26:
      return isInt<28>(diff);
    case IMAGE_REL_ARM64_BRANCH19:
      return isInt<21>(diff);
    case IMAGE_REL_ARM64_BRANCH14:
      return isInt<16>(diff);
    default:
      return true;
    }
  } else {
    llvm_unreachable("Unexpected architecture");
  }
}

// Return the last thunk for the given target if it is in range,
// or create a new one.
static std::pair<Defined *, bool>
getThunk(DenseMap<uint64_t, Defined *> &lastThunks, Defined *target, uint64_t p,
         uint16_t type, int margin) {
  Defined *&lastThunk = lastThunks[target->getRVA()];
  if (lastThunk && isInRange(type, lastThunk->getRVA(), p, margin))
    return {lastThunk, false};
  Chunk *c;
  switch (config->machine) {
  case ARMNT:
    c = make<RangeExtensionThunkARM>(target);
    break;
  case ARM64:
    c = make<RangeExtensionThunkARM64>(target);
    break;
  default:
    llvm_unreachable("Unexpected architecture");
  }
  Defined *d = make<DefinedSynthetic>("", c);
  lastThunk = d;
  return {d, true};
}

// This checks all relocations, and for any relocation which isn't in range
// it adds a thunk after the section chunk that contains the relocation.
// If the latest thunk for the specific target is in range, that is used
// instead of creating a new thunk. All range checks are done with the
// specified margin, to make sure that relocations that originally are in
// range, but only barely, also get thunks - in case other added thunks makes
// the target go out of range.
//
// After adding thunks, we verify that all relocations are in range (with
// no extra margin requirements). If this failed, we restart (throwing away
// the previously created thunks) and retry with a wider margin.
static bool createThunks(OutputSection *os, int margin) {
  bool addressesChanged = false;
  DenseMap<uint64_t, Defined *> lastThunks;
  DenseMap<std::pair<ObjFile *, Defined *>, uint32_t> thunkSymtabIndices;
  size_t thunksSize = 0;
  // Recheck Chunks.size() each iteration, since we can insert more
  // elements into it.
  for (size_t i = 0; i != os->chunks.size(); ++i) {
    SectionChunk *sc = dyn_cast_or_null<SectionChunk>(os->chunks[i]);
    if (!sc)
      continue;
    size_t thunkInsertionSpot = i + 1;

    // Try to get a good enough estimate of where new thunks will be placed.
    // Offset this by the size of the new thunks added so far, to make the
    // estimate slightly better.
    size_t thunkInsertionRVA = sc->getRVA() + sc->getSize() + thunksSize;
    ObjFile *file = sc->file;
    std::vector<std::pair<uint32_t, uint32_t>> relocReplacements;
    ArrayRef<coff_relocation> originalRelocs =
        file->getCOFFObj()->getRelocations(sc->header);
    for (size_t j = 0, e = originalRelocs.size(); j < e; ++j) {
      const coff_relocation &rel = originalRelocs[j];
      Symbol *relocTarget = file->getSymbol(rel.SymbolTableIndex);

      // The estimate of the source address P should be pretty accurate,
      // but we don't know whether the target Symbol address should be
      // offset by thunksSize or not (or by some of thunksSize but not all of
      // it), giving us some uncertainty once we have added one thunk.
      uint64_t p = sc->getRVA() + rel.VirtualAddress + thunksSize;

      Defined *sym = dyn_cast_or_null<Defined>(relocTarget);
      if (!sym)
        continue;

      uint64_t s = sym->getRVA();

      if (isInRange(rel.Type, s, p, margin))
        continue;

      // If the target isn't in range, hook it up to an existing or new
      // thunk.
      Defined *thunk;
      bool wasNew;
      std::tie(thunk, wasNew) = getThunk(lastThunks, sym, p, rel.Type, margin);
      if (wasNew) {
        Chunk *thunkChunk = thunk->getChunk();
        thunkChunk->setRVA(
            thunkInsertionRVA); // Estimate of where it will be located.
        os->chunks.insert(os->chunks.begin() + thunkInsertionSpot, thunkChunk);
        thunkInsertionSpot++;
        thunksSize += thunkChunk->getSize();
        thunkInsertionRVA += thunkChunk->getSize();
        addressesChanged = true;
      }

      // To redirect the relocation, add a symbol to the parent object file's
      // symbol table, and replace the relocation symbol table index with the
      // new index.
      auto insertion = thunkSymtabIndices.insert({{file, thunk}, ~0U});
      uint32_t &thunkSymbolIndex = insertion.first->second;
      if (insertion.second)
        thunkSymbolIndex = file->addRangeThunkSymbol(thunk);
      relocReplacements.push_back({j, thunkSymbolIndex});
    }

    // Get a writable copy of this section's relocations so they can be
    // modified. If the relocations point into the object file, allocate new
    // memory. Otherwise, this must be previously allocated memory that can be
    // modified in place.
    ArrayRef<coff_relocation> curRelocs = sc->getRelocs();
    MutableArrayRef<coff_relocation> newRelocs;
    if (originalRelocs.data() == curRelocs.data()) {
      newRelocs = makeMutableArrayRef(
          bAlloc.Allocate<coff_relocation>(originalRelocs.size()),
          originalRelocs.size());
    } else {
      newRelocs = makeMutableArrayRef(
          const_cast<coff_relocation *>(curRelocs.data()), curRelocs.size());
    }

    // Copy each relocation, but replace the symbol table indices which need
    // thunks.
    auto nextReplacement = relocReplacements.begin();
    auto endReplacement = relocReplacements.end();
    for (size_t i = 0, e = originalRelocs.size(); i != e; ++i) {
      newRelocs[i] = originalRelocs[i];
      if (nextReplacement != endReplacement && nextReplacement->first == i) {
        newRelocs[i].SymbolTableIndex = nextReplacement->second;
        ++nextReplacement;
      }
    }

    sc->setRelocs(newRelocs);
  }
  return addressesChanged;
}

// Verify that all relocations are in range, with no extra margin requirements.
static bool verifyRanges(const std::vector<Chunk *> chunks) {
  for (Chunk *c : chunks) {
    SectionChunk *sc = dyn_cast_or_null<SectionChunk>(c);
    if (!sc)
      continue;

    ArrayRef<coff_relocation> relocs = sc->getRelocs();
    for (size_t j = 0, e = relocs.size(); j < e; ++j) {
      const coff_relocation &rel = relocs[j];
      Symbol *relocTarget = sc->file->getSymbol(rel.SymbolTableIndex);

      Defined *sym = dyn_cast_or_null<Defined>(relocTarget);
      if (!sym)
        continue;

      uint64_t p = sc->getRVA() + rel.VirtualAddress;
      uint64_t s = sym->getRVA();

      if (!isInRange(rel.Type, s, p, 0))
        return false;
    }
  }
  return true;
}

// Assign addresses and add thunks if necessary.
void Writer::finalizeAddresses() {
  assignAddresses();
  if (config->machine != ARMNT && config->machine != ARM64)
    return;

  size_t origNumChunks = 0;
  for (OutputSection *sec : outputSections) {
    sec->origChunks = sec->chunks;
    origNumChunks += sec->chunks.size();
  }

  int pass = 0;
  int margin = 1024 * 100;
  while (true) {
    // First check whether we need thunks at all, or if the previous pass of
    // adding them turned out ok.
    bool rangesOk = true;
    size_t numChunks = 0;
    for (OutputSection *sec : outputSections) {
      if (!verifyRanges(sec->chunks)) {
        rangesOk = false;
        break;
      }
      numChunks += sec->chunks.size();
    }
    if (rangesOk) {
      if (pass > 0)
        log("Added " + Twine(numChunks - origNumChunks) + " thunks with " +
            "margin " + Twine(margin) + " in " + Twine(pass) + " passes");
      return;
    }

    if (pass >= 10)
      fatal("adding thunks hasn't converged after " + Twine(pass) + " passes");

    if (pass > 0) {
      // If the previous pass didn't work out, reset everything back to the
      // original conditions before retrying with a wider margin. This should
      // ideally never happen under real circumstances.
      for (OutputSection *sec : outputSections)
        sec->chunks = sec->origChunks;
      margin *= 2;
    }

    // Try adding thunks everywhere where it is needed, with a margin
    // to avoid things going out of range due to the added thunks.
    bool addressesChanged = false;
    for (OutputSection *sec : outputSections)
      addressesChanged |= createThunks(sec, margin);
    // If the verification above thought we needed thunks, we should have
    // added some.
    assert(addressesChanged);

    // Recalculate the layout for the whole image (and verify the ranges at
    // the start of the next round).
    assignAddresses();

    pass++;
  }
}

// The main function of the writer.
void Writer::run() {
  ScopedTimer t1(codeLayoutTimer);

  createImportTables();
  createSections();
  createMiscChunks();
  appendImportThunks();
  createExportTable();
  mergeSections();
  removeUnusedSections();
  finalizeAddresses();
  removeEmptySections();
  assignOutputSectionIndices();
  setSectionPermissions();
  createSymbolAndStringTable();

  if (fileSize > UINT32_MAX)
    fatal("image size (" + Twine(fileSize) + ") " +
        "exceeds maximum allowable size (" + Twine(UINT32_MAX) + ")");

  openFile(config->outputFile);
  if (config->is64()) {
    writeHeader<pe32plus_header>();
  } else {
    writeHeader<pe32_header>();
  }
  writeSections();
  sortExceptionTable();

  t1.stop();

  if (!config->pdbPath.empty() && config->debug) {
    assert(buildId);
    createPDB(symtab, outputSections, sectionTable, buildId->buildId);
  }
  writeBuildId();

  writeMapFile(outputSections);

  if (errorCount())
    return;

  ScopedTimer t2(diskCommitTimer);
  if (auto e = buffer->commit())
    fatal("failed to write the output file: " + toString(std::move(e)));
}

static StringRef getOutputSectionName(StringRef name) {
  StringRef s = name.split('$').first;

  // Treat a later period as a separator for MinGW, for sections like
  // ".ctors.01234".
  return s.substr(0, s.find('.', 1));
}

// For /order.
static void sortBySectionOrder(std::vector<Chunk *> &chunks) {
  auto getPriority = [](const Chunk *c) {
    if (auto *sec = dyn_cast<SectionChunk>(c))
      if (sec->sym)
        return config->order.lookup(sec->sym->getName());
    return 0;
  };

  llvm::stable_sort(chunks, [=](const Chunk *a, const Chunk *b) {
    return getPriority(a) < getPriority(b);
  });
}

// Change the characteristics of existing PartialSections that belong to the
// section Name to Chars.
void Writer::fixPartialSectionChars(StringRef name, uint32_t chars) {
  for (auto it : partialSections) {
    PartialSection *pSec = it.second;
    StringRef curName = pSec->name;
    if (!curName.consume_front(name) ||
        (!curName.empty() && !curName.startswith("$")))
      continue;
    if (pSec->characteristics == chars)
      continue;
    PartialSection *destSec = createPartialSection(pSec->name, chars);
    destSec->chunks.insert(destSec->chunks.end(), pSec->chunks.begin(),
                           pSec->chunks.end());
    pSec->chunks.clear();
  }
}

// Sort concrete section chunks from GNU import libraries.
//
// GNU binutils doesn't use short import files, but instead produces import
// libraries that consist of object files, with section chunks for the .idata$*
// sections. These are linked just as regular static libraries. Each import
// library consists of one header object, one object file for every imported
// symbol, and one trailer object. In order for the .idata tables/lists to
// be formed correctly, the section chunks within each .idata$* section need
// to be grouped by library, and sorted alphabetically within each library
// (which makes sure the header comes first and the trailer last).
bool Writer::fixGnuImportChunks() {
  uint32_t rdata = IMAGE_SCN_CNT_INITIALIZED_DATA | IMAGE_SCN_MEM_READ;

  // Make sure all .idata$* section chunks are mapped as RDATA in order to
  // be sorted into the same sections as our own synthesized .idata chunks.
  fixPartialSectionChars(".idata", rdata);

  bool hasIdata = false;
  // Sort all .idata$* chunks, grouping chunks from the same library,
  // with alphabetical ordering of the object fils within a library.
  for (auto it : partialSections) {
    PartialSection *pSec = it.second;
    if (!pSec->name.startswith(".idata"))
      continue;

    if (!pSec->chunks.empty())
      hasIdata = true;
    llvm::stable_sort(pSec->chunks, [&](Chunk *s, Chunk *t) {
      SectionChunk *sc1 = dyn_cast_or_null<SectionChunk>(s);
      SectionChunk *sc2 = dyn_cast_or_null<SectionChunk>(t);
      if (!sc1 || !sc2) {
        // if SC1, order them ascending. If SC2 or both null,
        // S is not less than T.
        return sc1 != nullptr;
      }
      // Make a string with "libraryname/objectfile" for sorting, achieving
      // both grouping by library and sorting of objects within a library,
      // at once.
      std::string key1 =
          (sc1->file->parentName + "/" + sc1->file->getName()).str();
      std::string key2 =
          (sc2->file->parentName + "/" + sc2->file->getName()).str();
      return key1 < key2;
    });
  }
  return hasIdata;
}

// Add generated idata chunks, for imported symbols and DLLs, and a
// terminator in .idata$2.
void Writer::addSyntheticIdata() {
  uint32_t rdata = IMAGE_SCN_CNT_INITIALIZED_DATA | IMAGE_SCN_MEM_READ;
  idata.create();

  // Add the .idata content in the right section groups, to allow
  // chunks from other linked in object files to be grouped together.
  // See Microsoft PE/COFF spec 5.4 for details.
  auto add = [&](StringRef n, std::vector<Chunk *> &v) {
    PartialSection *pSec = createPartialSection(n, rdata);
    pSec->chunks.insert(pSec->chunks.end(), v.begin(), v.end());
  };

  // The loader assumes a specific order of data.
  // Add each type in the correct order.
  add(".idata$2", idata.dirs);
  add(".idata$4", idata.lookups);
  add(".idata$5", idata.addresses);
  add(".idata$6", idata.hints);
  add(".idata$7", idata.dllNames);
}

// Locate the first Chunk and size of the import directory list and the
// IAT.
void Writer::locateImportTables() {
  uint32_t rdata = IMAGE_SCN_CNT_INITIALIZED_DATA | IMAGE_SCN_MEM_READ;

  if (PartialSection *importDirs = findPartialSection(".idata$2", rdata)) {
    if (!importDirs->chunks.empty())
      importTableStart = importDirs->chunks.front();
    for (Chunk *c : importDirs->chunks)
      importTableSize += c->getSize();
  }

  if (PartialSection *importAddresses = findPartialSection(".idata$5", rdata)) {
    if (!importAddresses->chunks.empty())
      iatStart = importAddresses->chunks.front();
    for (Chunk *c : importAddresses->chunks)
      iatSize += c->getSize();
  }
}

// Return whether a SectionChunk's suffix (the dollar and any trailing
// suffix) should be removed and sorted into the main suffixless
// PartialSection.
static bool shouldStripSectionSuffix(SectionChunk *sc, StringRef name) {
  // On MinGW, comdat groups are formed by putting the comdat group name
  // after the '$' in the section name. For .eh_frame$<symbol>, that must
  // still be sorted before the .eh_frame trailer from crtend.o, thus just
  // strip the section name trailer. For other sections, such as
  // .tls$$<symbol> (where non-comdat .tls symbols are otherwise stored in
  // ".tls$"), they must be strictly sorted after .tls. And for the
  // hypothetical case of comdat .CRT$XCU, we definitely need to keep the
  // suffix for sorting. Thus, to play it safe, only strip the suffix for
  // the standard sections.
  if (!config->mingw)
    return false;
  if (!sc || !sc->isCOMDAT())
    return false;
  return name.startswith(".text$") || name.startswith(".data$") ||
         name.startswith(".rdata$") || name.startswith(".pdata$") ||
         name.startswith(".xdata$") || name.startswith(".eh_frame$");
}

// Create output section objects and add them to OutputSections.
void Writer::createSections() {
  // First, create the builtin sections.
  const uint32_t data = IMAGE_SCN_CNT_INITIALIZED_DATA;
  const uint32_t bss = IMAGE_SCN_CNT_UNINITIALIZED_DATA;
  const uint32_t code = IMAGE_SCN_CNT_CODE;
  const uint32_t discardable = IMAGE_SCN_MEM_DISCARDABLE;
  const uint32_t r = IMAGE_SCN_MEM_READ;
  const uint32_t w = IMAGE_SCN_MEM_WRITE;
  const uint32_t x = IMAGE_SCN_MEM_EXECUTE;

  SmallDenseMap<std::pair<StringRef, uint32_t>, OutputSection *> sections;
  auto createSection = [&](StringRef name, uint32_t outChars) {
    OutputSection *&sec = sections[{name, outChars}];
    if (!sec) {
      sec = make<OutputSection>(name, outChars);
      outputSections.push_back(sec);
    }
    return sec;
  };

  // Try to match the section order used by link.exe.
  textSec = createSection(".text", code | r | x);
  createSection(".bss", bss | r | w);
  rdataSec = createSection(".rdata", data | r);
  buildidSec = createSection(".buildid", data | r);
  dataSec = createSection(".data", data | r | w);
  pdataSec = createSection(".pdata", data | r);
  idataSec = createSection(".idata", data | r);
  edataSec = createSection(".edata", data | r);
  didatSec = createSection(".didat", data | r);
  rsrcSec = createSection(".rsrc", data | r);
  relocSec = createSection(".reloc", data | discardable | r);
  ctorsSec = createSection(".ctors", data | r | w);
  dtorsSec = createSection(".dtors", data | r | w);

  // Then bin chunks by name and output characteristics.
  for (Chunk *c : symtab->getChunks()) {
    auto *sc = dyn_cast<SectionChunk>(c);
    if (sc && !sc->live) {
      if (config->verbose)
        sc->printDiscardedMessage();
      continue;
    }
    StringRef name = c->getSectionName();
    if (shouldStripSectionSuffix(sc, name))
      name = name.split('$').first;
    PartialSection *pSec = createPartialSection(name,
                                                c->getOutputCharacteristics());
    pSec->chunks.push_back(c);
  }

  fixPartialSectionChars(".rsrc", data | r);
  // Even in non MinGW cases, we might need to link against GNU import
  // libraries.
  bool hasIdata = fixGnuImportChunks();
  if (!idata.empty())
    hasIdata = true;

  if (hasIdata)
    addSyntheticIdata();

  // Process an /order option.
  if (!config->order.empty())
    for (auto it : partialSections)
      sortBySectionOrder(it.second->chunks);

  if (hasIdata)
    locateImportTables();

  // Then create an OutputSection for each section.
  // '$' and all following characters in input section names are
  // discarded when determining output section. So, .text$foo
  // contributes to .text, for example. See PE/COFF spec 3.2.
  for (auto it : partialSections) {
    PartialSection *pSec = it.second;
    StringRef name = getOutputSectionName(pSec->name);
    uint32_t outChars = pSec->characteristics;

    if (name == ".CRT") {
      // In link.exe, there is a special case for the I386 target where .CRT
      // sections are treated as if they have output characteristics DATA | R if
      // their characteristics are DATA | R | W. This implements the same
      // special case for all architectures.
      outChars = data | r;

      log("Processing section " + pSec->name + " -> " + name);

      sortCRTSectionChunks(pSec->chunks);
    }

    OutputSection *sec = createSection(name, outChars);
    for (Chunk *c : pSec->chunks)
      sec->addChunk(c);

    sec->addContributingPartialSection(pSec);
  }

  // Finally, move some output sections to the end.
  auto sectionOrder = [&](const OutputSection *s) {
    // Move DISCARDABLE (or non-memory-mapped) sections to the end of file
    // because the loader cannot handle holes. Stripping can remove other
    // discardable ones than .reloc, which is first of them (created early).
    if (s->header.Characteristics & IMAGE_SCN_MEM_DISCARDABLE)
      return 2;
    // .rsrc should come at the end of the non-discardable sections because its
    // size may change by the Win32 UpdateResources() function, causing
    // subsequent sections to move (see https://crbug.com/827082).
    if (s == rsrcSec)
      return 1;
    return 0;
  };
  llvm::stable_sort(outputSections,
                    [&](const OutputSection *s, const OutputSection *t) {
                      return sectionOrder(s) < sectionOrder(t);
                    });
}

void Writer::createMiscChunks() {
  for (MergeChunk *p : MergeChunk::instances) {
    if (p) {
      p->finalizeContents();
      rdataSec->addChunk(p);
    }
  }

  // Create thunks for locally-dllimported symbols.
  if (!symtab->localImportChunks.empty()) {
    for (Chunk *c : symtab->localImportChunks)
      rdataSec->addChunk(c);
  }

  // Create Debug Information Chunks
  OutputSection *debugInfoSec = config->mingw ? buildidSec : rdataSec;
  if (config->debug || config->repro) {
    debugDirectory = make<DebugDirectoryChunk>(debugRecords, config->repro);
    debugInfoSec->addChunk(debugDirectory);
  }

  if (config->debug) {
    // Make a CVDebugRecordChunk even when /DEBUG:CV is not specified.  We
    // output a PDB no matter what, and this chunk provides the only means of
    // allowing a debugger to match a PDB and an executable.  So we need it even
    // if we're ultimately not going to write CodeView data to the PDB.
    buildId = make<CVDebugRecordChunk>();
    debugRecords.push_back(buildId);

    for (Chunk *c : debugRecords)
      debugInfoSec->addChunk(c);
  }

  // Create SEH table. x86-only.
  if (config->safeSEH)
    createSEHTable();

  // Create /guard:cf tables if requested.
  if (config->guardCF != GuardCFLevel::Off)
    createGuardCFTables();

  if (config->mingw) {
    createRuntimePseudoRelocs();

    insertCtorDtorSymbols();
  }
}

// Create .idata section for the DLL-imported symbol table.
// The format of this section is inherently Windows-specific.
// IdataContents class abstracted away the details for us,
// so we just let it create chunks and add them to the section.
void Writer::createImportTables() {
  // Initialize DLLOrder so that import entries are ordered in
  // the same order as in the command line. (That affects DLL
  // initialization order, and this ordering is MSVC-compatible.)
  for (ImportFile *file : ImportFile::instances) {
    if (!file->live)
      continue;

    std::string dll = StringRef(file->dllName).lower();
    if (config->dllOrder.count(dll) == 0)
      config->dllOrder[dll] = config->dllOrder.size();

    if (file->impSym && !isa<DefinedImportData>(file->impSym))
      fatal(toString(*file->impSym) + " was replaced");
    DefinedImportData *impSym = cast_or_null<DefinedImportData>(file->impSym);
    if (config->delayLoads.count(StringRef(file->dllName).lower())) {
      if (!file->thunkSym)
        fatal("cannot delay-load " + toString(file) +
              " due to import of data: " + toString(*impSym));
      delayIdata.add(impSym);
    } else {
      idata.add(impSym);
    }
  }
}

void Writer::appendImportThunks() {
  if (ImportFile::instances.empty())
    return;

  for (ImportFile *file : ImportFile::instances) {
    if (!file->live)
      continue;

    if (!file->thunkSym)
      continue;

    if (!isa<DefinedImportThunk>(file->thunkSym))
      fatal(toString(*file->thunkSym) + " was replaced");
    DefinedImportThunk *thunk = cast<DefinedImportThunk>(file->thunkSym);
    if (file->thunkLive)
      textSec->addChunk(thunk->getChunk());
  }

  if (!delayIdata.empty()) {
    Defined *helper = cast<Defined>(config->delayLoadHelper);
    delayIdata.create(helper);
    for (Chunk *c : delayIdata.getChunks())
      didatSec->addChunk(c);
    for (Chunk *c : delayIdata.getDataChunks())
      dataSec->addChunk(c);
    for (Chunk *c : delayIdata.getCodeChunks())
      textSec->addChunk(c);
  }
}

void Writer::createExportTable() {
  if (config->exports.empty())
    return;
  for (Chunk *c : edata.chunks)
    edataSec->addChunk(c);
}

void Writer::removeUnusedSections() {
  // Remove sections that we can be sure won't get content, to avoid
  // allocating space for their section headers.
  auto isUnused = [this](OutputSection *s) {
    if (s == relocSec)
      return false; // This section is populated later.
    // MergeChunks have zero size at this point, as their size is finalized
    // later. Only remove sections that have no Chunks at all.
    return s->chunks.empty();
  };
  outputSections.erase(
      std::remove_if(outputSections.begin(), outputSections.end(), isUnused),
      outputSections.end());
}

// The Windows loader doesn't seem to like empty sections,
// so we remove them if any.
void Writer::removeEmptySections() {
  auto isEmpty = [](OutputSection *s) { return s->getVirtualSize() == 0; };
  outputSections.erase(
      std::remove_if(outputSections.begin(), outputSections.end(), isEmpty),
      outputSections.end());
}

void Writer::assignOutputSectionIndices() {
  // Assign final output section indices, and assign each chunk to its output
  // section.
  uint32_t idx = 1;
  for (OutputSection *os : outputSections) {
    os->sectionIndex = idx;
    for (Chunk *c : os->chunks)
      c->setOutputSectionIdx(idx);
    ++idx;
  }

  // Merge chunks are containers of chunks, so assign those an output section
  // too.
  for (MergeChunk *mc : MergeChunk::instances)
    if (mc)
      for (SectionChunk *sc : mc->sections)
        if (sc && sc->live)
          sc->setOutputSectionIdx(mc->getOutputSectionIdx());
}

size_t Writer::addEntryToStringTable(StringRef str) {
  assert(str.size() > COFF::NameSize);
  size_t offsetOfEntry = strtab.size() + 4; // +4 for the size field
  strtab.insert(strtab.end(), str.begin(), str.end());
  strtab.push_back('\0');
  return offsetOfEntry;
}

Optional<coff_symbol16> Writer::createSymbol(Defined *def) {
  coff_symbol16 sym;
  switch (def->kind()) {
  case Symbol::DefinedAbsoluteKind:
    sym.Value = def->getRVA();
    sym.SectionNumber = IMAGE_SYM_ABSOLUTE;
    break;
  case Symbol::DefinedSyntheticKind:
    // Relative symbols are unrepresentable in a COFF symbol table.
    return None;
  default: {
    // Don't write symbols that won't be written to the output to the symbol
    // table.
    Chunk *c = def->getChunk();
    if (!c)
      return None;
    OutputSection *os = c->getOutputSection();
    if (!os)
      return None;

    sym.Value = def->getRVA() - os->getRVA();
    sym.SectionNumber = os->sectionIndex;
    break;
  }
  }

  // Symbols that are runtime pseudo relocations don't point to the actual
  // symbol data itself (as they are imported), but points to the IAT entry
  // instead. Avoid emitting them to the symbol table, as they can confuse
  // debuggers.
  if (def->isRuntimePseudoReloc)
    return None;

  StringRef name = def->getName();
  if (name.size() > COFF::NameSize) {
    sym.Name.Offset.Zeroes = 0;
    sym.Name.Offset.Offset = addEntryToStringTable(name);
  } else {
    memset(sym.Name.ShortName, 0, COFF::NameSize);
    memcpy(sym.Name.ShortName, name.data(), name.size());
  }

  if (auto *d = dyn_cast<DefinedCOFF>(def)) {
    COFFSymbolRef ref = d->getCOFFSymbol();
    sym.Type = ref.getType();
    sym.StorageClass = ref.getStorageClass();
  } else {
    sym.Type = IMAGE_SYM_TYPE_NULL;
    sym.StorageClass = IMAGE_SYM_CLASS_EXTERNAL;
  }
  sym.NumberOfAuxSymbols = 0;
  return sym;
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
  for (OutputSection *sec : outputSections) {
    if (sec->name.size() <= COFF::NameSize)
      continue;
    if ((sec->header.Characteristics & IMAGE_SCN_MEM_DISCARDABLE) == 0)
      continue;
    sec->setStringTableOff(addEntryToStringTable(sec->name));
  }

  if (config->debugDwarf || config->debugSymtab) {
    for (ObjFile *file : ObjFile::instances) {
      for (Symbol *b : file->getSymbols()) {
        auto *d = dyn_cast_or_null<Defined>(b);
        if (!d || d->writtenToSymtab)
          continue;
        d->writtenToSymtab = true;

        if (Optional<coff_symbol16> sym = createSymbol(d))
          outputSymtab.push_back(*sym);
      }
    }
  }

  if (outputSymtab.empty() && strtab.empty())
    return;

  // We position the symbol table to be adjacent to the end of the last section.
  uint64_t fileOff = fileSize;
  pointerToSymbolTable = fileOff;
  fileOff += outputSymtab.size() * sizeof(coff_symbol16);
  fileOff += 4 + strtab.size();
  fileSize = alignTo(fileOff, config->fileAlign);
}

void Writer::mergeSections() {
  if (!pdataSec->chunks.empty()) {
    firstPdata = pdataSec->chunks.front();
    lastPdata = pdataSec->chunks.back();
  }

  for (auto &p : config->merge) {
    StringRef toName = p.second;
    if (p.first == toName)
      continue;
    StringSet<> names;
    while (1) {
      if (!names.insert(toName).second)
        fatal("/merge: cycle found for section '" + p.first + "'");
      auto i = config->merge.find(toName);
      if (i == config->merge.end())
        break;
      toName = i->second;
    }
    OutputSection *from = findSection(p.first);
    OutputSection *to = findSection(toName);
    if (!from)
      continue;
    if (!to) {
      from->name = toName;
      continue;
    }
    to->merge(from);
  }
}

// Visits all sections to assign incremental, non-overlapping RVAs and
// file offsets.
void Writer::assignAddresses() {
  sizeOfHeaders = dosStubSize + sizeof(PEMagic) + sizeof(coff_file_header) +
                  sizeof(data_directory) * numberOfDataDirectory +
                  sizeof(coff_section) * outputSections.size();
  sizeOfHeaders +=
      config->is64() ? sizeof(pe32plus_header) : sizeof(pe32_header);
  sizeOfHeaders = alignTo(sizeOfHeaders, config->fileAlign);
  fileSize = sizeOfHeaders;

  // The first page is kept unmapped.
  uint64_t rva = alignTo(sizeOfHeaders, config->align);

  for (OutputSection *sec : outputSections) {
    if (sec == relocSec)
      addBaserels();
    uint64_t rawSize = 0, virtualSize = 0;
    sec->header.VirtualAddress = rva;

    // If /FUNCTIONPADMIN is used, functions are padded in order to create a
    // hotpatchable image.
    const bool isCodeSection =
        (sec->header.Characteristics & IMAGE_SCN_CNT_CODE) &&
        (sec->header.Characteristics & IMAGE_SCN_MEM_READ) &&
        (sec->header.Characteristics & IMAGE_SCN_MEM_EXECUTE);
    uint32_t padding = isCodeSection ? config->functionPadMin : 0;

    for (Chunk *c : sec->chunks) {
      if (padding && c->isHotPatchable())
        virtualSize += padding;
      virtualSize = alignTo(virtualSize, c->getAlignment());
      c->setRVA(rva + virtualSize);
      virtualSize += c->getSize();
      if (c->hasData)
        rawSize = alignTo(virtualSize, config->fileAlign);
    }
    if (virtualSize > UINT32_MAX)
      error("section larger than 4 GiB: " + sec->name);
    sec->header.VirtualSize = virtualSize;
    sec->header.SizeOfRawData = rawSize;
    if (rawSize != 0)
      sec->header.PointerToRawData = fileSize;
    rva += alignTo(virtualSize, config->align);
    fileSize += alignTo(rawSize, config->fileAlign);
  }
  sizeOfImage = alignTo(rva, config->align);

  // Assign addresses to sections in MergeChunks.
  for (MergeChunk *mc : MergeChunk::instances)
    if (mc)
      mc->assignSubsectionRVAs();
}

template <typename PEHeaderTy> void Writer::writeHeader() {
  // Write DOS header. For backwards compatibility, the first part of a PE/COFF
  // executable consists of an MS-DOS MZ executable. If the executable is run
  // under DOS, that program gets run (usually to just print an error message).
  // When run under Windows, the loader looks at AddressOfNewExeHeader and uses
  // the PE header instead.
  uint8_t *buf = buffer->getBufferStart();
  auto *dos = reinterpret_cast<dos_header *>(buf);
  buf += sizeof(dos_header);
  dos->Magic[0] = 'M';
  dos->Magic[1] = 'Z';
  dos->UsedBytesInTheLastPage = dosStubSize % 512;
  dos->FileSizeInPages = divideCeil(dosStubSize, 512);
  dos->HeaderSizeInParagraphs = sizeof(dos_header) / 16;

  dos->AddressOfRelocationTable = sizeof(dos_header);
  dos->AddressOfNewExeHeader = dosStubSize;

  // Write DOS program.
  memcpy(buf, dosProgram, sizeof(dosProgram));
  buf += sizeof(dosProgram);

  // Write PE magic
  memcpy(buf, PEMagic, sizeof(PEMagic));
  buf += sizeof(PEMagic);

  // Write COFF header
  auto *coff = reinterpret_cast<coff_file_header *>(buf);
  buf += sizeof(*coff);
  coff->Machine = config->machine;
  coff->NumberOfSections = outputSections.size();
  coff->Characteristics = IMAGE_FILE_EXECUTABLE_IMAGE;
  if (config->largeAddressAware)
    coff->Characteristics |= IMAGE_FILE_LARGE_ADDRESS_AWARE;
  if (!config->is64())
    coff->Characteristics |= IMAGE_FILE_32BIT_MACHINE;
  if (config->dll)
    coff->Characteristics |= IMAGE_FILE_DLL;
  if (!config->relocatable)
    coff->Characteristics |= IMAGE_FILE_RELOCS_STRIPPED;
  if (config->swaprunCD)
    coff->Characteristics |= IMAGE_FILE_REMOVABLE_RUN_FROM_SWAP;
  if (config->swaprunNet)
    coff->Characteristics |= IMAGE_FILE_NET_RUN_FROM_SWAP;
  coff->SizeOfOptionalHeader =
      sizeof(PEHeaderTy) + sizeof(data_directory) * numberOfDataDirectory;

  // Write PE header
  auto *pe = reinterpret_cast<PEHeaderTy *>(buf);
  buf += sizeof(*pe);
  pe->Magic = config->is64() ? PE32Header::PE32_PLUS : PE32Header::PE32;

  // If {Major,Minor}LinkerVersion is left at 0.0, then for some
  // reason signing the resulting PE file with Authenticode produces a
  // signature that fails to validate on Windows 7 (but is OK on 10).
  // Set it to 14.0, which is what VS2015 outputs, and which avoids
  // that problem.
  pe->MajorLinkerVersion = 14;
  pe->MinorLinkerVersion = 0;

  pe->ImageBase = config->imageBase;
  pe->SectionAlignment = config->align;
  pe->FileAlignment = config->fileAlign;
  pe->MajorImageVersion = config->majorImageVersion;
  pe->MinorImageVersion = config->minorImageVersion;
  pe->MajorOperatingSystemVersion = config->majorOSVersion;
  pe->MinorOperatingSystemVersion = config->minorOSVersion;
  pe->MajorSubsystemVersion = config->majorOSVersion;
  pe->MinorSubsystemVersion = config->minorOSVersion;
  pe->Subsystem = config->subsystem;
  pe->SizeOfImage = sizeOfImage;
  pe->SizeOfHeaders = sizeOfHeaders;
  if (!config->noEntry) {
    Defined *entry = cast<Defined>(config->entry);
    pe->AddressOfEntryPoint = entry->getRVA();
    // Pointer to thumb code must have the LSB set, so adjust it.
    if (config->machine == ARMNT)
      pe->AddressOfEntryPoint |= 1;
  }
  pe->SizeOfStackReserve = config->stackReserve;
  pe->SizeOfStackCommit = config->stackCommit;
  pe->SizeOfHeapReserve = config->heapReserve;
  pe->SizeOfHeapCommit = config->heapCommit;
  if (config->appContainer)
    pe->DLLCharacteristics |= IMAGE_DLL_CHARACTERISTICS_APPCONTAINER;
  if (config->dynamicBase)
    pe->DLLCharacteristics |= IMAGE_DLL_CHARACTERISTICS_DYNAMIC_BASE;
  if (config->highEntropyVA)
    pe->DLLCharacteristics |= IMAGE_DLL_CHARACTERISTICS_HIGH_ENTROPY_VA;
  if (!config->allowBind)
    pe->DLLCharacteristics |= IMAGE_DLL_CHARACTERISTICS_NO_BIND;
  if (config->nxCompat)
    pe->DLLCharacteristics |= IMAGE_DLL_CHARACTERISTICS_NX_COMPAT;
  if (!config->allowIsolation)
    pe->DLLCharacteristics |= IMAGE_DLL_CHARACTERISTICS_NO_ISOLATION;
  if (config->guardCF != GuardCFLevel::Off)
    pe->DLLCharacteristics |= IMAGE_DLL_CHARACTERISTICS_GUARD_CF;
  if (config->integrityCheck)
    pe->DLLCharacteristics |= IMAGE_DLL_CHARACTERISTICS_FORCE_INTEGRITY;
  if (setNoSEHCharacteristic)
    pe->DLLCharacteristics |= IMAGE_DLL_CHARACTERISTICS_NO_SEH;
  if (config->terminalServerAware)
    pe->DLLCharacteristics |= IMAGE_DLL_CHARACTERISTICS_TERMINAL_SERVER_AWARE;
  pe->NumberOfRvaAndSize = numberOfDataDirectory;
  if (textSec->getVirtualSize()) {
    pe->BaseOfCode = textSec->getRVA();
    pe->SizeOfCode = textSec->getRawSize();
  }
  pe->SizeOfInitializedData = getSizeOfInitializedData();

  // Write data directory
  auto *dir = reinterpret_cast<data_directory *>(buf);
  buf += sizeof(*dir) * numberOfDataDirectory;
  if (!config->exports.empty()) {
    dir[EXPORT_TABLE].RelativeVirtualAddress = edata.getRVA();
    dir[EXPORT_TABLE].Size = edata.getSize();
  }
  if (importTableStart) {
    dir[IMPORT_TABLE].RelativeVirtualAddress = importTableStart->getRVA();
    dir[IMPORT_TABLE].Size = importTableSize;
  }
  if (iatStart) {
    dir[IAT].RelativeVirtualAddress = iatStart->getRVA();
    dir[IAT].Size = iatSize;
  }
  if (rsrcSec->getVirtualSize()) {
    dir[RESOURCE_TABLE].RelativeVirtualAddress = rsrcSec->getRVA();
    dir[RESOURCE_TABLE].Size = rsrcSec->getVirtualSize();
  }
  if (firstPdata) {
    dir[EXCEPTION_TABLE].RelativeVirtualAddress = firstPdata->getRVA();
    dir[EXCEPTION_TABLE].Size =
        lastPdata->getRVA() + lastPdata->getSize() - firstPdata->getRVA();
  }
  if (relocSec->getVirtualSize()) {
    dir[BASE_RELOCATION_TABLE].RelativeVirtualAddress = relocSec->getRVA();
    dir[BASE_RELOCATION_TABLE].Size = relocSec->getVirtualSize();
  }
  if (Symbol *sym = symtab->findUnderscore("_tls_used")) {
    if (Defined *b = dyn_cast<Defined>(sym)) {
      dir[TLS_TABLE].RelativeVirtualAddress = b->getRVA();
      dir[TLS_TABLE].Size = config->is64()
                                ? sizeof(object::coff_tls_directory64)
                                : sizeof(object::coff_tls_directory32);
    }
  }
  if (debugDirectory) {
    dir[DEBUG_DIRECTORY].RelativeVirtualAddress = debugDirectory->getRVA();
    dir[DEBUG_DIRECTORY].Size = debugDirectory->getSize();
  }
  if (Symbol *sym = symtab->findUnderscore("_load_config_used")) {
    if (auto *b = dyn_cast<DefinedRegular>(sym)) {
      SectionChunk *sc = b->getChunk();
      assert(b->getRVA() >= sc->getRVA());
      uint64_t offsetInChunk = b->getRVA() - sc->getRVA();
      if (!sc->hasData || offsetInChunk + 4 > sc->getSize())
        fatal("_load_config_used is malformed");

      ArrayRef<uint8_t> secContents = sc->getContents();
      uint32_t loadConfigSize =
          *reinterpret_cast<const ulittle32_t *>(&secContents[offsetInChunk]);
      if (offsetInChunk + loadConfigSize > sc->getSize())
        fatal("_load_config_used is too large");
      dir[LOAD_CONFIG_TABLE].RelativeVirtualAddress = b->getRVA();
      dir[LOAD_CONFIG_TABLE].Size = loadConfigSize;
    }
  }
  if (!delayIdata.empty()) {
    dir[DELAY_IMPORT_DESCRIPTOR].RelativeVirtualAddress =
        delayIdata.getDirRVA();
    dir[DELAY_IMPORT_DESCRIPTOR].Size = delayIdata.getDirSize();
  }

  // Write section table
  for (OutputSection *sec : outputSections) {
    sec->writeHeaderTo(buf);
    buf += sizeof(coff_section);
  }
  sectionTable = ArrayRef<uint8_t>(
      buf - outputSections.size() * sizeof(coff_section), buf);

  if (outputSymtab.empty() && strtab.empty())
    return;

  coff->PointerToSymbolTable = pointerToSymbolTable;
  uint32_t numberOfSymbols = outputSymtab.size();
  coff->NumberOfSymbols = numberOfSymbols;
  auto *symbolTable = reinterpret_cast<coff_symbol16 *>(
      buffer->getBufferStart() + coff->PointerToSymbolTable);
  for (size_t i = 0; i != numberOfSymbols; ++i)
    symbolTable[i] = outputSymtab[i];
  // Create the string table, it follows immediately after the symbol table.
  // The first 4 bytes is length including itself.
  buf = reinterpret_cast<uint8_t *>(&symbolTable[numberOfSymbols]);
  write32le(buf, strtab.size() + 4);
  if (!strtab.empty())
    memcpy(buf + 4, strtab.data(), strtab.size());
}

void Writer::openFile(StringRef path) {
  buffer = CHECK(
      FileOutputBuffer::create(path, fileSize, FileOutputBuffer::F_executable),
      "failed to open " + path);
}

void Writer::createSEHTable() {
  SymbolRVASet handlers;
  for (ObjFile *file : ObjFile::instances) {
    if (!file->hasSafeSEH())
      error("/safeseh: " + file->getName() + " is not compatible with SEH");
    markSymbolsForRVATable(file, file->getSXDataChunks(), handlers);
  }

  // Set the "no SEH" characteristic if there really were no handlers, or if
  // there is no load config object to point to the table of handlers.
  setNoSEHCharacteristic =
      handlers.empty() || !symtab->findUnderscore("_load_config_used");

  maybeAddRVATable(std::move(handlers), "__safe_se_handler_table",
                   "__safe_se_handler_count");
}

// Add a symbol to an RVA set. Two symbols may have the same RVA, but an RVA set
// cannot contain duplicates. Therefore, the set is uniqued by Chunk and the
// symbol's offset into that Chunk.
static void addSymbolToRVASet(SymbolRVASet &rvaSet, Defined *s) {
  Chunk *c = s->getChunk();
  if (auto *sc = dyn_cast<SectionChunk>(c))
    c = sc->repl; // Look through ICF replacement.
  uint32_t off = s->getRVA() - (c ? c->getRVA() : 0);
  rvaSet.insert({c, off});
}

// Given a symbol, add it to the GFIDs table if it is a live, defined, function
// symbol in an executable section.
static void maybeAddAddressTakenFunction(SymbolRVASet &addressTakenSyms,
                                         Symbol *s) {
  if (!s)
    return;

  switch (s->kind()) {
  case Symbol::DefinedLocalImportKind:
  case Symbol::DefinedImportDataKind:
    // Defines an __imp_ pointer, so it is data, so it is ignored.
    break;
  case Symbol::DefinedCommonKind:
    // Common is always data, so it is ignored.
    break;
  case Symbol::DefinedAbsoluteKind:
  case Symbol::DefinedSyntheticKind:
    // Absolute is never code, synthetic generally isn't and usually isn't
    // determinable.
    break;
  case Symbol::LazyKind:
  case Symbol::UndefinedKind:
    // Undefined symbols resolve to zero, so they don't have an RVA. Lazy
    // symbols shouldn't have relocations.
    break;

  case Symbol::DefinedImportThunkKind:
    // Thunks are always code, include them.
    addSymbolToRVASet(addressTakenSyms, cast<Defined>(s));
    break;

  case Symbol::DefinedRegularKind: {
    // This is a regular, defined, symbol from a COFF file. Mark the symbol as
    // address taken if the symbol type is function and it's in an executable
    // section.
    auto *d = cast<DefinedRegular>(s);
    if (d->getCOFFSymbol().getComplexType() == COFF::IMAGE_SYM_DTYPE_FUNCTION) {
      SectionChunk *sc = dyn_cast<SectionChunk>(d->getChunk());
      if (sc && sc->live &&
          sc->getOutputCharacteristics() & IMAGE_SCN_MEM_EXECUTE)
        addSymbolToRVASet(addressTakenSyms, d);
    }
    break;
  }
  }
}

// Visit all relocations from all section contributions of this object file and
// mark the relocation target as address-taken.
static void markSymbolsWithRelocations(ObjFile *file,
                                       SymbolRVASet &usedSymbols) {
  for (Chunk *c : file->getChunks()) {
    // We only care about live section chunks. Common chunks and other chunks
    // don't generally contain relocations.
    SectionChunk *sc = dyn_cast<SectionChunk>(c);
    if (!sc || !sc->live)
      continue;

    for (const coff_relocation &reloc : sc->getRelocs()) {
      if (config->machine == I386 && reloc.Type == COFF::IMAGE_REL_I386_REL32)
        // Ignore relative relocations on x86. On x86_64 they can't be ignored
        // since they're also used to compute absolute addresses.
        continue;

      Symbol *ref = sc->file->getSymbol(reloc.SymbolTableIndex);
      maybeAddAddressTakenFunction(usedSymbols, ref);
    }
  }
}

// Create the guard function id table. This is a table of RVAs of all
// address-taken functions. It is sorted and uniqued, just like the safe SEH
// table.
void Writer::createGuardCFTables() {
  SymbolRVASet addressTakenSyms;
  SymbolRVASet longJmpTargets;
  for (ObjFile *file : ObjFile::instances) {
    // If the object was compiled with /guard:cf, the address taken symbols
    // are in .gfids$y sections, and the longjmp targets are in .gljmp$y
    // sections. If the object was not compiled with /guard:cf, we assume there
    // were no setjmp targets, and that all code symbols with relocations are
    // possibly address-taken.
    if (file->hasGuardCF()) {
      markSymbolsForRVATable(file, file->getGuardFidChunks(), addressTakenSyms);
      markSymbolsForRVATable(file, file->getGuardLJmpChunks(), longJmpTargets);
    } else {
      markSymbolsWithRelocations(file, addressTakenSyms);
    }
  }

  // Mark the image entry as address-taken.
  if (config->entry)
    maybeAddAddressTakenFunction(addressTakenSyms, config->entry);

  // Mark exported symbols in executable sections as address-taken.
  for (Export &e : config->exports)
    maybeAddAddressTakenFunction(addressTakenSyms, e.sym);

  // Ensure sections referenced in the gfid table are 16-byte aligned.
  for (const ChunkAndOffset &c : addressTakenSyms)
    if (c.inputChunk->getAlignment() < 16)
      c.inputChunk->setAlignment(16);

  maybeAddRVATable(std::move(addressTakenSyms), "__guard_fids_table",
                   "__guard_fids_count");

  // Add the longjmp target table unless the user told us not to.
  if (config->guardCF == GuardCFLevel::Full)
    maybeAddRVATable(std::move(longJmpTargets), "__guard_longjmp_table",
                     "__guard_longjmp_count");

  // Set __guard_flags, which will be used in the load config to indicate that
  // /guard:cf was enabled.
  uint32_t guardFlags = uint32_t(coff_guard_flags::CFInstrumented) |
                        uint32_t(coff_guard_flags::HasFidTable);
  if (config->guardCF == GuardCFLevel::Full)
    guardFlags |= uint32_t(coff_guard_flags::HasLongJmpTable);
  Symbol *flagSym = symtab->findUnderscore("__guard_flags");
  cast<DefinedAbsolute>(flagSym)->setVA(guardFlags);
}

// Take a list of input sections containing symbol table indices and add those
// symbols to an RVA table. The challenge is that symbol RVAs are not known and
// depend on the table size, so we can't directly build a set of integers.
void Writer::markSymbolsForRVATable(ObjFile *file,
                                    ArrayRef<SectionChunk *> symIdxChunks,
                                    SymbolRVASet &tableSymbols) {
  for (SectionChunk *c : symIdxChunks) {
    // Skip sections discarded by linker GC. This comes up when a .gfids section
    // is associated with something like a vtable and the vtable is discarded.
    // In this case, the associated gfids section is discarded, and we don't
    // mark the virtual member functions as address-taken by the vtable.
    if (!c->live)
      continue;

    // Validate that the contents look like symbol table indices.
    ArrayRef<uint8_t> data = c->getContents();
    if (data.size() % 4 != 0) {
      warn("ignoring " + c->getSectionName() +
           " symbol table index section in object " + toString(file));
      continue;
    }

    // Read each symbol table index and check if that symbol was included in the
    // final link. If so, add it to the table symbol set.
    ArrayRef<ulittle32_t> symIndices(
        reinterpret_cast<const ulittle32_t *>(data.data()), data.size() / 4);
    ArrayRef<Symbol *> objSymbols = file->getSymbols();
    for (uint32_t symIndex : symIndices) {
      if (symIndex >= objSymbols.size()) {
        warn("ignoring invalid symbol table index in section " +
             c->getSectionName() + " in object " + toString(file));
        continue;
      }
      if (Symbol *s = objSymbols[symIndex]) {
        if (s->isLive())
          addSymbolToRVASet(tableSymbols, cast<Defined>(s));
      }
    }
  }
}

// Replace the absolute table symbol with a synthetic symbol pointing to
// tableChunk so that we can emit base relocations for it and resolve section
// relative relocations.
void Writer::maybeAddRVATable(SymbolRVASet tableSymbols, StringRef tableSym,
                              StringRef countSym) {
  if (tableSymbols.empty())
    return;

  RVATableChunk *tableChunk = make<RVATableChunk>(std::move(tableSymbols));
  rdataSec->addChunk(tableChunk);

  Symbol *t = symtab->findUnderscore(tableSym);
  Symbol *c = symtab->findUnderscore(countSym);
  replaceSymbol<DefinedSynthetic>(t, t->getName(), tableChunk);
  cast<DefinedAbsolute>(c)->setVA(tableChunk->getSize() / 4);
}

// MinGW specific. Gather all relocations that are imported from a DLL even
// though the code didn't expect it to, produce the table that the runtime
// uses for fixing them up, and provide the synthetic symbols that the
// runtime uses for finding the table.
void Writer::createRuntimePseudoRelocs() {
  std::vector<RuntimePseudoReloc> rels;

  for (Chunk *c : symtab->getChunks()) {
    auto *sc = dyn_cast<SectionChunk>(c);
    if (!sc || !sc->live)
      continue;
    sc->getRuntimePseudoRelocs(rels);
  }

  if (!rels.empty())
    log("Writing " + Twine(rels.size()) + " runtime pseudo relocations");
  PseudoRelocTableChunk *table = make<PseudoRelocTableChunk>(rels);
  rdataSec->addChunk(table);
  EmptyChunk *endOfList = make<EmptyChunk>();
  rdataSec->addChunk(endOfList);

  Symbol *headSym = symtab->findUnderscore("__RUNTIME_PSEUDO_RELOC_LIST__");
  Symbol *endSym = symtab->findUnderscore("__RUNTIME_PSEUDO_RELOC_LIST_END__");
  replaceSymbol<DefinedSynthetic>(headSym, headSym->getName(), table);
  replaceSymbol<DefinedSynthetic>(endSym, endSym->getName(), endOfList);
}

// MinGW specific.
// The MinGW .ctors and .dtors lists have sentinels at each end;
// a (uintptr_t)-1 at the start and a (uintptr_t)0 at the end.
// There's a symbol pointing to the start sentinel pointer, __CTOR_LIST__
// and __DTOR_LIST__ respectively.
void Writer::insertCtorDtorSymbols() {
  AbsolutePointerChunk *ctorListHead = make<AbsolutePointerChunk>(-1);
  AbsolutePointerChunk *ctorListEnd = make<AbsolutePointerChunk>(0);
  AbsolutePointerChunk *dtorListHead = make<AbsolutePointerChunk>(-1);
  AbsolutePointerChunk *dtorListEnd = make<AbsolutePointerChunk>(0);
  ctorsSec->insertChunkAtStart(ctorListHead);
  ctorsSec->addChunk(ctorListEnd);
  dtorsSec->insertChunkAtStart(dtorListHead);
  dtorsSec->addChunk(dtorListEnd);

  Symbol *ctorListSym = symtab->findUnderscore("__CTOR_LIST__");
  Symbol *dtorListSym = symtab->findUnderscore("__DTOR_LIST__");
  replaceSymbol<DefinedSynthetic>(ctorListSym, ctorListSym->getName(),
                                  ctorListHead);
  replaceSymbol<DefinedSynthetic>(dtorListSym, dtorListSym->getName(),
                                  dtorListHead);
}

// Handles /section options to allow users to overwrite
// section attributes.
void Writer::setSectionPermissions() {
  for (auto &p : config->section) {
    StringRef name = p.first;
    uint32_t perm = p.second;
    for (OutputSection *sec : outputSections)
      if (sec->name == name)
        sec->setPermissions(perm);
  }
}

// Write section contents to a mmap'ed file.
void Writer::writeSections() {
  // Record the number of sections to apply section index relocations
  // against absolute symbols. See applySecIdx in Chunks.cpp..
  DefinedAbsolute::numOutputSections = outputSections.size();

  uint8_t *buf = buffer->getBufferStart();
  for (OutputSection *sec : outputSections) {
    uint8_t *secBuf = buf + sec->getFileOff();
    // Fill gaps between functions in .text with INT3 instructions
    // instead of leaving as NUL bytes (which can be interpreted as
    // ADD instructions).
    if (sec->header.Characteristics & IMAGE_SCN_CNT_CODE)
      memset(secBuf, 0xCC, sec->getRawSize());
    parallelForEach(sec->chunks, [&](Chunk *c) {
      c->writeTo(secBuf + c->getRVA() - sec->getRVA());
    });
  }
}

void Writer::writeBuildId() {
  // There are two important parts to the build ID.
  // 1) If building with debug info, the COFF debug directory contains a
  //    timestamp as well as a Guid and Age of the PDB.
  // 2) In all cases, the PE COFF file header also contains a timestamp.
  // For reproducibility, instead of a timestamp we want to use a hash of the
  // PE contents.
  if (config->debug) {
    assert(buildId && "BuildId is not set!");
    // BuildId->BuildId was filled in when the PDB was written.
  }

  // At this point the only fields in the COFF file which remain unset are the
  // "timestamp" in the COFF file header, and the ones in the coff debug
  // directory.  Now we can hash the file and write that hash to the various
  // timestamp fields in the file.
  StringRef outputFileData(
      reinterpret_cast<const char *>(buffer->getBufferStart()),
      buffer->getBufferSize());

  uint32_t timestamp = config->timestamp;
  uint64_t hash = 0;
  bool generateSyntheticBuildId =
      config->mingw && config->debug && config->pdbPath.empty();

  if (config->repro || generateSyntheticBuildId)
    hash = xxHash64(outputFileData);

  if (config->repro)
    timestamp = static_cast<uint32_t>(hash);

  if (generateSyntheticBuildId) {
    // For MinGW builds without a PDB file, we still generate a build id
    // to allow associating a crash dump to the executable.
    buildId->buildId->PDB70.CVSignature = OMF::Signature::PDB70;
    buildId->buildId->PDB70.Age = 1;
    memcpy(buildId->buildId->PDB70.Signature, &hash, 8);
    // xxhash only gives us 8 bytes, so put some fixed data in the other half.
    memcpy(&buildId->buildId->PDB70.Signature[8], "LLD PDB.", 8);
  }

  if (debugDirectory)
    debugDirectory->setTimeDateStamp(timestamp);

  uint8_t *buf = buffer->getBufferStart();
  buf += dosStubSize + sizeof(PEMagic);
  object::coff_file_header *coffHeader =
      reinterpret_cast<coff_file_header *>(buf);
  coffHeader->TimeDateStamp = timestamp;
}

// Sort .pdata section contents according to PE/COFF spec 5.5.
void Writer::sortExceptionTable() {
  if (!firstPdata)
    return;
  // We assume .pdata contains function table entries only.
  auto bufAddr = [&](Chunk *c) {
    OutputSection *os = c->getOutputSection();
    return buffer->getBufferStart() + os->getFileOff() + c->getRVA() -
           os->getRVA();
  };
  uint8_t *begin = bufAddr(firstPdata);
  uint8_t *end = bufAddr(lastPdata) + lastPdata->getSize();
  if (config->machine == AMD64) {
    struct Entry { ulittle32_t begin, end, unwind; };
    parallelSort(
        MutableArrayRef<Entry>((Entry *)begin, (Entry *)end),
        [](const Entry &a, const Entry &b) { return a.begin < b.begin; });
    return;
  }
  if (config->machine == ARMNT || config->machine == ARM64) {
    struct Entry { ulittle32_t begin, unwind; };
    parallelSort(
        MutableArrayRef<Entry>((Entry *)begin, (Entry *)end),
        [](const Entry &a, const Entry &b) { return a.begin < b.begin; });
    return;
  }
  errs() << "warning: don't know how to handle .pdata.\n";
}

// The CRT section contains, among other things, the array of function
// pointers that initialize every global variable that is not trivially
// constructed. The CRT calls them one after the other prior to invoking
// main().
//
// As per C++ spec, 3.6.2/2.3,
// "Variables with ordered initialization defined within a single
// translation unit shall be initialized in the order of their definitions
// in the translation unit"
//
// It is therefore critical to sort the chunks containing the function
// pointers in the order that they are listed in the object file (top to
// bottom), otherwise global objects might not be initialized in the
// correct order.
void Writer::sortCRTSectionChunks(std::vector<Chunk *> &chunks) {
  auto sectionChunkOrder = [](const Chunk *a, const Chunk *b) {
    auto sa = dyn_cast<SectionChunk>(a);
    auto sb = dyn_cast<SectionChunk>(b);
    assert(sa && sb && "Non-section chunks in CRT section!");

    StringRef sAObj = sa->file->mb.getBufferIdentifier();
    StringRef sBObj = sb->file->mb.getBufferIdentifier();

    return sAObj == sBObj && sa->getSectionNumber() < sb->getSectionNumber();
  };
  llvm::stable_sort(chunks, sectionChunkOrder);

  if (config->verbose) {
    for (auto &c : chunks) {
      auto sc = dyn_cast<SectionChunk>(c);
      log("  " + sc->file->mb.getBufferIdentifier().str() +
          ", SectionID: " + Twine(sc->getSectionNumber()));
    }
  }
}

OutputSection *Writer::findSection(StringRef name) {
  for (OutputSection *sec : outputSections)
    if (sec->name == name)
      return sec;
  return nullptr;
}

uint32_t Writer::getSizeOfInitializedData() {
  uint32_t res = 0;
  for (OutputSection *s : outputSections)
    if (s->header.Characteristics & IMAGE_SCN_CNT_INITIALIZED_DATA)
      res += s->getRawSize();
  return res;
}

// Add base relocations to .reloc section.
void Writer::addBaserels() {
  if (!config->relocatable)
    return;
  relocSec->chunks.clear();
  std::vector<Baserel> v;
  for (OutputSection *sec : outputSections) {
    if (sec->header.Characteristics & IMAGE_SCN_MEM_DISCARDABLE)
      continue;
    // Collect all locations for base relocations.
    for (Chunk *c : sec->chunks)
      c->getBaserels(&v);
    // Add the addresses to .reloc section.
    if (!v.empty())
      addBaserelBlocks(v);
    v.clear();
  }
}

// Add addresses to .reloc section. Note that addresses are grouped by page.
void Writer::addBaserelBlocks(std::vector<Baserel> &v) {
  const uint32_t mask = ~uint32_t(pageSize - 1);
  uint32_t page = v[0].rva & mask;
  size_t i = 0, j = 1;
  for (size_t e = v.size(); j < e; ++j) {
    uint32_t p = v[j].rva & mask;
    if (p == page)
      continue;
    relocSec->addChunk(make<BaserelChunk>(page, &v[i], &v[0] + j));
    i = j;
    page = p;
  }
  if (i == j)
    return;
  relocSec->addChunk(make<BaserelChunk>(page, &v[i], &v[0] + j));
}

PartialSection *Writer::createPartialSection(StringRef name,
                                             uint32_t outChars) {
  PartialSection *&pSec = partialSections[{name, outChars}];
  if (pSec)
    return pSec;
  pSec = make<PartialSection>(name, outChars);
  return pSec;
}

PartialSection *Writer::findPartialSection(StringRef name, uint32_t outChars) {
  auto it = partialSections.find({name, outChars});
  if (it != partialSections.end())
    return it->second;
  return nullptr;
}
