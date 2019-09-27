//===- PDB.cpp ------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "PDB.h"
#include "Chunks.h"
#include "Config.h"
#include "DebugTypes.h"
#include "Driver.h"
#include "SymbolTable.h"
#include "Symbols.h"
#include "TypeMerger.h"
#include "Writer.h"
#include "lld/Common/ErrorHandler.h"
#include "lld/Common/Timer.h"
#include "lld/Common/Threads.h"
#include "llvm/DebugInfo/CodeView/DebugFrameDataSubsection.h"
#include "llvm/DebugInfo/CodeView/DebugSubsectionRecord.h"
#include "llvm/DebugInfo/CodeView/GlobalTypeTableBuilder.h"
#include "llvm/DebugInfo/CodeView/LazyRandomTypeCollection.h"
#include "llvm/DebugInfo/CodeView/MergingTypeTableBuilder.h"
#include "llvm/DebugInfo/CodeView/RecordName.h"
#include "llvm/DebugInfo/CodeView/SymbolDeserializer.h"
#include "llvm/DebugInfo/CodeView/SymbolRecordHelpers.h"
#include "llvm/DebugInfo/CodeView/SymbolSerializer.h"
#include "llvm/DebugInfo/CodeView/TypeDeserializer.h"
#include "llvm/DebugInfo/CodeView/TypeDumpVisitor.h"
#include "llvm/DebugInfo/CodeView/TypeIndexDiscovery.h"
#include "llvm/DebugInfo/CodeView/TypeStreamMerger.h"
#include "llvm/DebugInfo/MSF/MSFBuilder.h"
#include "llvm/DebugInfo/MSF/MSFCommon.h"
#include "llvm/DebugInfo/PDB/GenericError.h"
#include "llvm/DebugInfo/PDB/Native/DbiModuleDescriptorBuilder.h"
#include "llvm/DebugInfo/PDB/Native/DbiStream.h"
#include "llvm/DebugInfo/PDB/Native/DbiStreamBuilder.h"
#include "llvm/DebugInfo/PDB/Native/GSIStreamBuilder.h"
#include "llvm/DebugInfo/PDB/Native/InfoStream.h"
#include "llvm/DebugInfo/PDB/Native/InfoStreamBuilder.h"
#include "llvm/DebugInfo/PDB/Native/NativeSession.h"
#include "llvm/DebugInfo/PDB/Native/PDBFile.h"
#include "llvm/DebugInfo/PDB/Native/PDBFileBuilder.h"
#include "llvm/DebugInfo/PDB/Native/PDBStringTableBuilder.h"
#include "llvm/DebugInfo/PDB/Native/TpiHashing.h"
#include "llvm/DebugInfo/PDB/Native/TpiStream.h"
#include "llvm/DebugInfo/PDB/Native/TpiStreamBuilder.h"
#include "llvm/DebugInfo/PDB/PDB.h"
#include "llvm/Object/COFF.h"
#include "llvm/Object/CVDebugRecord.h"
#include "llvm/Support/BinaryByteStream.h"
#include "llvm/Support/Endian.h"
#include "llvm/Support/Errc.h"
#include "llvm/Support/FormatVariadic.h"
#include "llvm/Support/JamCRC.h"
#include "llvm/Support/Path.h"
#include "llvm/Support/ScopedPrinter.h"
#include <memory>

using namespace lld;
using namespace lld::coff;
using namespace llvm;
using namespace llvm::codeview;

using llvm::object::coff_section;

static ExitOnError exitOnErr;

static Timer totalPdbLinkTimer("PDB Emission (Cumulative)", Timer::root());

static Timer addObjectsTimer("Add Objects", totalPdbLinkTimer);
static Timer typeMergingTimer("Type Merging", addObjectsTimer);
static Timer symbolMergingTimer("Symbol Merging", addObjectsTimer);
static Timer globalsLayoutTimer("Globals Stream Layout", totalPdbLinkTimer);
static Timer tpiStreamLayoutTimer("TPI Stream Layout", totalPdbLinkTimer);
static Timer diskCommitTimer("Commit to Disk", totalPdbLinkTimer);

namespace {
class DebugSHandler;

class PDBLinker {
  friend DebugSHandler;

public:
  PDBLinker(SymbolTable *symtab)
      : alloc(), symtab(symtab), builder(alloc), tMerger(alloc) {
    // This isn't strictly necessary, but link.exe usually puts an empty string
    // as the first "valid" string in the string table, so we do the same in
    // order to maintain as much byte-for-byte compatibility as possible.
    pdbStrTab.insert("");
  }

  /// Emit the basic PDB structure: initial streams, headers, etc.
  void initialize(llvm::codeview::DebugInfo *buildId);

  /// Add natvis files specified on the command line.
  void addNatvisFiles();

  /// Link CodeView from each object file in the symbol table into the PDB.
  void addObjectsToPDB();

  /// Link info for each import file in the symbol table into the PDB.
  void addImportFilesToPDB(ArrayRef<OutputSection *> outputSections);

  /// Link CodeView from a single object file into the target (output) PDB.
  /// When a precompiled headers object is linked, its TPI map might be provided
  /// externally.
  void addObjFile(ObjFile *file, CVIndexMap *externIndexMap = nullptr);

  /// Produce a mapping from the type and item indices used in the object
  /// file to those in the destination PDB.
  ///
  /// If the object file uses a type server PDB (compiled with /Zi), merge TPI
  /// and IPI from the type server PDB and return a map for it. Each unique type
  /// server PDB is merged at most once, so this may return an existing index
  /// mapping.
  ///
  /// If the object does not use a type server PDB (compiled with /Z7), we merge
  /// all the type and item records from the .debug$S stream and fill in the
  /// caller-provided objectIndexMap.
  Expected<const CVIndexMap &> mergeDebugT(ObjFile *file,
                                           CVIndexMap *objectIndexMap);

  /// Reads and makes available a PDB.
  Expected<const CVIndexMap &> maybeMergeTypeServerPDB(ObjFile *file);

  /// Merges a precompiled headers TPI map into the current TPI map. The
  /// precompiled headers object will also be loaded and remapped in the
  /// process.
  Error mergeInPrecompHeaderObj(ObjFile *file, CVIndexMap *objectIndexMap);

  /// Reads and makes available a precompiled headers object.
  ///
  /// This is a requirement for objects compiled with cl.exe /Yu. In that
  /// case, the referenced object (which was compiled with /Yc) has to be loaded
  /// first. This is mainly because the current object's TPI stream has external
  /// references to the precompiled headers object.
  ///
  /// If the precompiled headers object was already loaded, this function will
  /// simply return its (remapped) TPI map.
  Expected<const CVIndexMap &> aquirePrecompObj(ObjFile *file);

  /// Adds a precompiled headers object signature -> TPI mapping.
  std::pair<CVIndexMap &, bool /*already there*/>
  registerPrecompiledHeaders(uint32_t signature);

  void mergeSymbolRecords(ObjFile *file, const CVIndexMap &indexMap,
                          std::vector<ulittle32_t *> &stringTableRefs,
                          BinaryStreamRef symData);

  /// Add the section map and section contributions to the PDB.
  void addSections(ArrayRef<OutputSection *> outputSections,
                   ArrayRef<uint8_t> sectionTable);

  /// Write the PDB to disk and store the Guid generated for it in *Guid.
  void commit(codeview::GUID *guid);

  // Print statistics regarding the final PDB
  void printStats();

private:
  BumpPtrAllocator alloc;

  SymbolTable *symtab;

  pdb::PDBFileBuilder builder;

  TypeMerger tMerger;

  /// PDBs use a single global string table for filenames in the file checksum
  /// table.
  DebugStringTableSubsection pdbStrTab;

  llvm::SmallString<128> nativePath;

  std::vector<pdb::SecMapEntry> sectionMap;

  /// Type index mappings of type server PDBs that we've loaded so far.
  std::map<codeview::GUID, CVIndexMap> typeServerIndexMappings;

  /// Type index mappings of precompiled objects type map that we've loaded so
  /// far.
  std::map<uint32_t, CVIndexMap> precompTypeIndexMappings;

  // For statistics
  uint64_t globalSymbols = 0;
  uint64_t moduleSymbols = 0;
  uint64_t publicSymbols = 0;
};

class DebugSHandler {
  PDBLinker &linker;

  /// The object file whose .debug$S sections we're processing.
  ObjFile &file;

  /// The result of merging type indices.
  const CVIndexMap &indexMap;

  /// The DEBUG_S_STRINGTABLE subsection.  These strings are referred to by
  /// index from other records in the .debug$S section.  All of these strings
  /// need to be added to the global PDB string table, and all references to
  /// these strings need to have their indices re-written to refer to the
  /// global PDB string table.
  DebugStringTableSubsectionRef cVStrTab;

  /// The DEBUG_S_FILECHKSMS subsection.  As above, these are referred to
  /// by other records in the .debug$S section and need to be merged into the
  /// PDB.
  DebugChecksumsSubsectionRef checksums;

  /// The DEBUG_S_INLINEELINES subsection. There can be only one of these per
  /// object file.
  DebugInlineeLinesSubsectionRef inlineeLines;

  /// The DEBUG_S_FRAMEDATA subsection(s).  There can be more than one of
  /// these and they need not appear in any specific order.  However, they
  /// contain string table references which need to be re-written, so we
  /// collect them all here and re-write them after all subsections have been
  /// discovered and processed.
  std::vector<DebugFrameDataSubsectionRef> newFpoFrames;

  /// Pointers to raw memory that we determine have string table references
  /// that need to be re-written.  We first process all .debug$S subsections
  /// to ensure that we can handle subsections written in any order, building
  /// up this list as we go.  At the end, we use the string table (which must
  /// have been discovered by now else it is an error) to re-write these
  /// references.
  std::vector<ulittle32_t *> stringTableReferences;

public:
  DebugSHandler(PDBLinker &linker, ObjFile &file, const CVIndexMap &indexMap)
      : linker(linker), file(file), indexMap(indexMap) {}

  void handleDebugS(lld::coff::SectionChunk &debugS);

  std::shared_ptr<DebugInlineeLinesSubsection>
  mergeInlineeLines(DebugChecksumsSubsection *newChecksums);

  void finish();
};
}

// Visual Studio's debugger requires absolute paths in various places in the
// PDB to work without additional configuration:
// https://docs.microsoft.com/en-us/visualstudio/debugger/debug-source-files-common-properties-solution-property-pages-dialog-box
static void pdbMakeAbsolute(SmallVectorImpl<char> &fileName) {
  // The default behavior is to produce paths that are valid within the context
  // of the machine that you perform the link on.  If the linker is running on
  // a POSIX system, we will output absolute POSIX paths.  If the linker is
  // running on a Windows system, we will output absolute Windows paths.  If the
  // user desires any other kind of behavior, they should explicitly pass
  // /pdbsourcepath, in which case we will treat the exact string the user
  // passed in as the gospel and not normalize, canonicalize it.
  if (sys::path::is_absolute(fileName, sys::path::Style::windows) ||
      sys::path::is_absolute(fileName, sys::path::Style::posix))
    return;

  // It's not absolute in any path syntax.  Relative paths necessarily refer to
  // the local file system, so we can make it native without ending up with a
  // nonsensical path.
  if (config->pdbSourcePath.empty()) {
    sys::path::native(fileName);
    sys::fs::make_absolute(fileName);
    return;
  }

  // Try to guess whether /PDBSOURCEPATH is a unix path or a windows path.
  // Since PDB's are more of a Windows thing, we make this conservative and only
  // decide that it's a unix path if we're fairly certain.  Specifically, if
  // it starts with a forward slash.
  SmallString<128> absoluteFileName = config->pdbSourcePath;
  sys::path::Style guessedStyle = absoluteFileName.startswith("/")
                                      ? sys::path::Style::posix
                                      : sys::path::Style::windows;
  sys::path::append(absoluteFileName, guessedStyle, fileName);
  sys::path::native(absoluteFileName, guessedStyle);
  sys::path::remove_dots(absoluteFileName, true, guessedStyle);

  fileName = std::move(absoluteFileName);
}

// A COFF .debug$H section is currently a clang extension.  This function checks
// if a .debug$H section is in a format that we expect / understand, so that we
// can ignore any sections which are coincidentally also named .debug$H but do
// not contain a format we recognize.
static bool canUseDebugH(ArrayRef<uint8_t> debugH) {
  if (debugH.size() < sizeof(object::debug_h_header))
    return false;
  auto *header =
      reinterpret_cast<const object::debug_h_header *>(debugH.data());
  debugH = debugH.drop_front(sizeof(object::debug_h_header));
  return header->Magic == COFF::DEBUG_HASHES_SECTION_MAGIC &&
         header->Version == 0 &&
         header->HashAlgorithm == uint16_t(GlobalTypeHashAlg::SHA1_8) &&
         (debugH.size() % 8 == 0);
}

static Optional<ArrayRef<uint8_t>> getDebugH(ObjFile *file) {
  SectionChunk *sec =
      SectionChunk::findByName(file->getDebugChunks(), ".debug$H");
  if (!sec)
    return llvm::None;
  ArrayRef<uint8_t> contents = sec->getContents();
  if (!canUseDebugH(contents))
    return None;
  return contents;
}

static ArrayRef<GloballyHashedType>
getHashesFromDebugH(ArrayRef<uint8_t> debugH) {
  assert(canUseDebugH(debugH));

  debugH = debugH.drop_front(sizeof(object::debug_h_header));
  uint32_t count = debugH.size() / sizeof(GloballyHashedType);
  return {reinterpret_cast<const GloballyHashedType *>(debugH.data()), count};
}

static void addTypeInfo(pdb::TpiStreamBuilder &tpiBuilder,
                        TypeCollection &typeTable) {
  // Start the TPI or IPI stream header.
  tpiBuilder.setVersionHeader(pdb::PdbTpiV80);

  // Flatten the in memory type table and hash each type.
  typeTable.ForEachRecord([&](TypeIndex ti, const CVType &type) {
    auto hash = pdb::hashTypeRecord(type);
    if (auto e = hash.takeError())
      fatal("type hashing error");
    tpiBuilder.addTypeRecord(type.RecordData, *hash);
  });
}

Expected<const CVIndexMap &>
PDBLinker::mergeDebugT(ObjFile *file, CVIndexMap *objectIndexMap) {
  ScopedTimer t(typeMergingTimer);

  if (!file->debugTypesObj)
    return *objectIndexMap; // no Types stream

  // Precompiled headers objects need to save the index map for further
  // reference by other objects which use the precompiled headers.
  if (file->debugTypesObj->kind == TpiSource::PCH) {
    uint32_t pchSignature = file->pchSignature.getValueOr(0);
    if (pchSignature == 0)
      fatal("No signature found for the precompiled headers OBJ (" +
            file->getName() + ")");

    // When a precompiled headers object comes first on the command-line, we
    // update the mapping here. Otherwise, if an object referencing the
    // precompiled headers object comes first, the mapping is created in
    // aquirePrecompObj(), thus we would skip this block.
    if (!objectIndexMap->isPrecompiledTypeMap) {
      auto r = registerPrecompiledHeaders(pchSignature);
      if (r.second)
        fatal(
            "A precompiled headers OBJ with the same signature was already "
            "provided! (" +
            file->getName() + ")");

      objectIndexMap = &r.first;
    }
  }

  if (file->debugTypesObj->kind == TpiSource::UsingPDB) {
    // Look through type servers. If we've already seen this type server,
    // don't merge any type information.
    return maybeMergeTypeServerPDB(file);
  }
  
  CVTypeArray &types = *file->debugTypes;

  if (file->debugTypesObj->kind == TpiSource::UsingPCH) {
    // This object was compiled with /Yu, so process the corresponding
    // precompiled headers object (/Yc) first. Some type indices in the current
    // object are referencing data in the precompiled headers object, so we need
    // both to be loaded.
    Error e = mergeInPrecompHeaderObj(file, objectIndexMap);
    if (e)
      return std::move(e);

    // Drop LF_PRECOMP record from the input stream, as it has been replaced
    // with the precompiled headers Type stream in the mergeInPrecompHeaderObj()
    // call above. Note that we can't just call Types.drop_front(), as we
    // explicitly want to rebase the stream.
    CVTypeArray::Iterator firstType = types.begin();
    types.setUnderlyingStream(
        types.getUnderlyingStream().drop_front(firstType->RecordData.size()));
  }

  // Fill in the temporary, caller-provided ObjectIndexMap.
  if (config->debugGHashes) {
    ArrayRef<GloballyHashedType> hashes;
    std::vector<GloballyHashedType> ownedHashes;
    if (Optional<ArrayRef<uint8_t>> debugH = getDebugH(file))
      hashes = getHashesFromDebugH(*debugH);
    else {
      ownedHashes = GloballyHashedType::hashTypes(types);
      hashes = ownedHashes;
    }

    if (auto err = mergeTypeAndIdRecords(
            tMerger.globalIDTable, tMerger.globalTypeTable,
            objectIndexMap->tpiMap, types, hashes, file->pchSignature))
      fatal("codeview::mergeTypeAndIdRecords failed: " +
            toString(std::move(err)));
  } else {
    if (auto err = mergeTypeAndIdRecords(tMerger.iDTable, tMerger.typeTable,
                                         objectIndexMap->tpiMap, types,
                                         file->pchSignature))
      fatal("codeview::mergeTypeAndIdRecords failed: " +
            toString(std::move(err)));
  }
  return *objectIndexMap;
}

Expected<const CVIndexMap &> PDBLinker::maybeMergeTypeServerPDB(ObjFile *file) {
  Expected<llvm::pdb::NativeSession *> pdbSession = findTypeServerSource(file);
  if (!pdbSession)
    return pdbSession.takeError();

  pdb::PDBFile &pdbFile = pdbSession.get()->getPDBFile();
  pdb::InfoStream &info = cantFail(pdbFile.getPDBInfoStream());

  auto it = typeServerIndexMappings.emplace(info.getGuid(), CVIndexMap());
  CVIndexMap &indexMap = it.first->second;
  if (!it.second)
    return indexMap; // already merged

  // Mark this map as a type server map.
  indexMap.isTypeServerMap = true;

  Expected<pdb::TpiStream &> expectedTpi = pdbFile.getPDBTpiStream();
  if (auto e = expectedTpi.takeError())
    fatal("Type server does not have TPI stream: " + toString(std::move(e)));
  pdb::TpiStream *maybeIpi = nullptr;
  if (pdbFile.hasPDBIpiStream()) {
    Expected<pdb::TpiStream &> expectedIpi = pdbFile.getPDBIpiStream();
    if (auto e = expectedIpi.takeError())
      fatal("Error getting type server IPI stream: " + toString(std::move(e)));
    maybeIpi = &*expectedIpi;
  }

  if (config->debugGHashes) {
    // PDBs do not actually store global hashes, so when merging a type server
    // PDB we have to synthesize global hashes.  To do this, we first synthesize
    // global hashes for the TPI stream, since it is independent, then we
    // synthesize hashes for the IPI stream, using the hashes for the TPI stream
    // as inputs.
    auto tpiHashes = GloballyHashedType::hashTypes(expectedTpi->typeArray());
    Optional<uint32_t> endPrecomp;
    // Merge TPI first, because the IPI stream will reference type indices.
    if (auto err =
            mergeTypeRecords(tMerger.globalTypeTable, indexMap.tpiMap,
                             expectedTpi->typeArray(), tpiHashes, endPrecomp))
      fatal("codeview::mergeTypeRecords failed: " + toString(std::move(err)));

    // Merge IPI.
    if (maybeIpi) {
      auto ipiHashes =
          GloballyHashedType::hashIds(maybeIpi->typeArray(), tpiHashes);
      if (auto err =
              mergeIdRecords(tMerger.globalIDTable, indexMap.tpiMap,
                             indexMap.ipiMap, maybeIpi->typeArray(), ipiHashes))
        fatal("codeview::mergeIdRecords failed: " + toString(std::move(err)));
    }
  } else {
    // Merge TPI first, because the IPI stream will reference type indices.
    if (auto err = mergeTypeRecords(tMerger.typeTable, indexMap.tpiMap,
                                    expectedTpi->typeArray()))
      fatal("codeview::mergeTypeRecords failed: " + toString(std::move(err)));

    // Merge IPI.
    if (maybeIpi) {
      if (auto err = mergeIdRecords(tMerger.iDTable, indexMap.tpiMap,
                                    indexMap.ipiMap, maybeIpi->typeArray()))
        fatal("codeview::mergeIdRecords failed: " + toString(std::move(err)));
    }
  }

  return indexMap;
}

Error PDBLinker::mergeInPrecompHeaderObj(ObjFile *file,
                                         CVIndexMap *objectIndexMap) {
  const PrecompRecord &precomp =
      retrieveDependencyInfo<PrecompRecord>(file->debugTypesObj);

  Expected<const CVIndexMap &> e = aquirePrecompObj(file);
  if (!e)
    return e.takeError();

  const CVIndexMap &precompIndexMap = *e;
  assert(precompIndexMap.isPrecompiledTypeMap);

  if (precompIndexMap.tpiMap.empty())
    return Error::success();

  assert(precomp.getStartTypeIndex() == TypeIndex::FirstNonSimpleIndex);
  assert(precomp.getTypesCount() <= precompIndexMap.tpiMap.size());
  // Use the previously remapped index map from the precompiled headers.
  objectIndexMap->tpiMap.append(precompIndexMap.tpiMap.begin(),
                                precompIndexMap.tpiMap.begin() +
                                    precomp.getTypesCount());
  return Error::success();
}

static bool equals_path(StringRef path1, StringRef path2) {
#if defined(_WIN32)
  return path1.equals_lower(path2);
#else
  return path1.equals(path2);
#endif
}

// Find by name an OBJ provided on the command line
static ObjFile *findObjByName(StringRef fileNameOnly) {
  SmallString<128> currentPath;

  for (ObjFile *f : ObjFile::instances) {
    StringRef currentFileName = sys::path::filename(f->getName());

    // Compare based solely on the file name (link.exe behavior)
    if (equals_path(currentFileName, fileNameOnly))
      return f;
  }
  return nullptr;
}

std::pair<CVIndexMap &, bool /*already there*/>
PDBLinker::registerPrecompiledHeaders(uint32_t signature) {
  auto insertion = precompTypeIndexMappings.insert({signature, CVIndexMap()});
  CVIndexMap &indexMap = insertion.first->second;
  if (!insertion.second)
    return {indexMap, true};
  // Mark this map as a precompiled types map.
  indexMap.isPrecompiledTypeMap = true;
  return {indexMap, false};
}

Expected<const CVIndexMap &> PDBLinker::aquirePrecompObj(ObjFile *file) {
  const PrecompRecord &precomp =
      retrieveDependencyInfo<PrecompRecord>(file->debugTypesObj);

  // First, check if we already loaded the precompiled headers object with this
  // signature. Return the type index mapping if we've already seen it.
  auto r = registerPrecompiledHeaders(precomp.getSignature());
  if (r.second)
    return r.first;

  CVIndexMap &indexMap = r.first;

  // Cross-compile warning: given that Clang doesn't generate LF_PRECOMP
  // records, we assume the OBJ comes from a Windows build of cl.exe. Thusly,
  // the paths embedded in the OBJs are in the Windows format.
  SmallString<128> precompFileName = sys::path::filename(
      precomp.getPrecompFilePath(), sys::path::Style::windows);

  // link.exe requires that a precompiled headers object must always be provided
  // on the command-line, even if that's not necessary.
  auto precompFile = findObjByName(precompFileName);
  if (!precompFile)
    return createFileError(
        precompFileName.str(),
        make_error<pdb::PDBError>(pdb::pdb_error_code::external_cmdline_ref));

  addObjFile(precompFile, &indexMap);

  if (!precompFile->pchSignature)
    fatal(precompFile->getName() + " is not a precompiled headers object");

  if (precomp.getSignature() != precompFile->pchSignature.getValueOr(0))
    return createFileError(
        precomp.getPrecompFilePath().str(),
        make_error<pdb::PDBError>(pdb::pdb_error_code::signature_out_of_date));

  return indexMap;
}

static bool remapTypeIndex(TypeIndex &ti, ArrayRef<TypeIndex> typeIndexMap) {
  if (ti.isSimple())
    return true;
  if (ti.toArrayIndex() >= typeIndexMap.size())
    return false;
  ti = typeIndexMap[ti.toArrayIndex()];
  return true;
}

static void remapTypesInSymbolRecord(ObjFile *file, SymbolKind symKind,
                                     MutableArrayRef<uint8_t> recordBytes,
                                     const CVIndexMap &indexMap,
                                     ArrayRef<TiReference> typeRefs) {
  MutableArrayRef<uint8_t> contents =
      recordBytes.drop_front(sizeof(RecordPrefix));
  for (const TiReference &ref : typeRefs) {
    unsigned byteSize = ref.Count * sizeof(TypeIndex);
    if (contents.size() < ref.Offset + byteSize)
      fatal("symbol record too short");

    // This can be an item index or a type index. Choose the appropriate map.
    ArrayRef<TypeIndex> typeOrItemMap = indexMap.tpiMap;
    bool isItemIndex = ref.Kind == TiRefKind::IndexRef;
    if (isItemIndex && indexMap.isTypeServerMap)
      typeOrItemMap = indexMap.ipiMap;

    MutableArrayRef<TypeIndex> tIs(
        reinterpret_cast<TypeIndex *>(contents.data() + ref.Offset), ref.Count);
    for (TypeIndex &ti : tIs) {
      if (!remapTypeIndex(ti, typeOrItemMap)) {
        log("ignoring symbol record of kind 0x" + utohexstr(symKind) + " in " +
            file->getName() + " with bad " + (isItemIndex ? "item" : "type") +
            " index 0x" + utohexstr(ti.getIndex()));
        ti = TypeIndex(SimpleTypeKind::NotTranslated);
        continue;
      }
    }
  }
}

static void
recordStringTableReferenceAtOffset(MutableArrayRef<uint8_t> contents,
                                   uint32_t offset,
                                   std::vector<ulittle32_t *> &strTableRefs) {
  contents =
      contents.drop_front(offset).take_front(sizeof(support::ulittle32_t));
  ulittle32_t *index = reinterpret_cast<ulittle32_t *>(contents.data());
  strTableRefs.push_back(index);
}

static void
recordStringTableReferences(SymbolKind kind, MutableArrayRef<uint8_t> contents,
                            std::vector<ulittle32_t *> &strTableRefs) {
  // For now we only handle S_FILESTATIC, but we may need the same logic for
  // S_DEFRANGE and S_DEFRANGE_SUBFIELD.  However, I cannot seem to generate any
  // PDBs that contain these types of records, so because of the uncertainty
  // they are omitted here until we can prove that it's necessary.
  switch (kind) {
  case SymbolKind::S_FILESTATIC:
    // FileStaticSym::ModFileOffset
    recordStringTableReferenceAtOffset(contents, 8, strTableRefs);
    break;
  case SymbolKind::S_DEFRANGE:
  case SymbolKind::S_DEFRANGE_SUBFIELD:
    log("Not fixing up string table reference in S_DEFRANGE / "
        "S_DEFRANGE_SUBFIELD record");
    break;
  default:
    break;
  }
}

static SymbolKind symbolKind(ArrayRef<uint8_t> recordData) {
  const RecordPrefix *prefix =
      reinterpret_cast<const RecordPrefix *>(recordData.data());
  return static_cast<SymbolKind>(uint16_t(prefix->RecordKind));
}

/// MSVC translates S_PROC_ID_END to S_END, and S_[LG]PROC32_ID to S_[LG]PROC32
static void translateIdSymbols(MutableArrayRef<uint8_t> &recordData,
                               TypeCollection &iDTable) {
  RecordPrefix *prefix = reinterpret_cast<RecordPrefix *>(recordData.data());

  SymbolKind kind = symbolKind(recordData);

  if (kind == SymbolKind::S_PROC_ID_END) {
    prefix->RecordKind = SymbolKind::S_END;
    return;
  }

  // In an object file, GPROC32_ID has an embedded reference which refers to the
  // single object file type index namespace.  This has already been translated
  // to the PDB file's ID stream index space, but we need to convert this to a
  // symbol that refers to the type stream index space.  So we remap again from
  // ID index space to type index space.
  if (kind == SymbolKind::S_GPROC32_ID || kind == SymbolKind::S_LPROC32_ID) {
    SmallVector<TiReference, 1> refs;
    auto content = recordData.drop_front(sizeof(RecordPrefix));
    CVSymbol sym(recordData);
    discoverTypeIndicesInSymbol(sym, refs);
    assert(refs.size() == 1);
    assert(refs.front().Count == 1);

    TypeIndex *ti =
        reinterpret_cast<TypeIndex *>(content.data() + refs[0].Offset);
    // `ti` is the index of a FuncIdRecord or MemberFuncIdRecord which lives in
    // the IPI stream, whose `FunctionType` member refers to the TPI stream.
    // Note that LF_FUNC_ID and LF_MEMFUNC_ID have the same record layout, and
    // in both cases we just need the second type index.
    if (!ti->isSimple() && !ti->isNoneType()) {
      CVType funcIdData = iDTable.getType(*ti);
      SmallVector<TypeIndex, 2> indices;
      discoverTypeIndices(funcIdData, indices);
      assert(indices.size() == 2);
      *ti = indices[1];
    }

    kind = (kind == SymbolKind::S_GPROC32_ID) ? SymbolKind::S_GPROC32
                                              : SymbolKind::S_LPROC32;
    prefix->RecordKind = uint16_t(kind);
  }
}

/// Copy the symbol record. In a PDB, symbol records must be 4 byte aligned.
/// The object file may not be aligned.
static MutableArrayRef<uint8_t>
copyAndAlignSymbol(const CVSymbol &sym, MutableArrayRef<uint8_t> &alignedMem) {
  size_t size = alignTo(sym.length(), alignOf(CodeViewContainer::Pdb));
  assert(size >= 4 && "record too short");
  assert(size <= MaxRecordLength && "record too long");
  assert(alignedMem.size() >= size && "didn't preallocate enough");

  // Copy the symbol record and zero out any padding bytes.
  MutableArrayRef<uint8_t> newData = alignedMem.take_front(size);
  alignedMem = alignedMem.drop_front(size);
  memcpy(newData.data(), sym.data().data(), sym.length());
  memset(newData.data() + sym.length(), 0, size - sym.length());

  // Update the record prefix length. It should point to the beginning of the
  // next record.
  auto *prefix = reinterpret_cast<RecordPrefix *>(newData.data());
  prefix->RecordLen = size - 2;
  return newData;
}

struct ScopeRecord {
  ulittle32_t ptrParent;
  ulittle32_t ptrEnd;
};

struct SymbolScope {
  ScopeRecord *openingRecord;
  uint32_t scopeOffset;
};

static void scopeStackOpen(SmallVectorImpl<SymbolScope> &stack,
                           uint32_t curOffset, CVSymbol &sym) {
  assert(symbolOpensScope(sym.kind()));
  SymbolScope s;
  s.scopeOffset = curOffset;
  s.openingRecord = const_cast<ScopeRecord *>(
      reinterpret_cast<const ScopeRecord *>(sym.content().data()));
  s.openingRecord->ptrParent = stack.empty() ? 0 : stack.back().scopeOffset;
  stack.push_back(s);
}

static void scopeStackClose(SmallVectorImpl<SymbolScope> &stack,
                            uint32_t curOffset, InputFile *file) {
  if (stack.empty()) {
    warn("symbol scopes are not balanced in " + file->getName());
    return;
  }
  SymbolScope s = stack.pop_back_val();
  s.openingRecord->ptrEnd = curOffset;
}

static bool symbolGoesInModuleStream(const CVSymbol &sym, bool isGlobalScope) {
  switch (sym.kind()) {
  case SymbolKind::S_GDATA32:
  case SymbolKind::S_CONSTANT:
  // We really should not be seeing S_PROCREF and S_LPROCREF in the first place
  // since they are synthesized by the linker in response to S_GPROC32 and
  // S_LPROC32, but if we do see them, don't put them in the module stream I
  // guess.
  case SymbolKind::S_PROCREF:
  case SymbolKind::S_LPROCREF:
    return false;
  // S_UDT records go in the module stream if it is not a global S_UDT.
  case SymbolKind::S_UDT:
    return !isGlobalScope;
  // S_GDATA32 does not go in the module stream, but S_LDATA32 does.
  case SymbolKind::S_LDATA32:
  default:
    return true;
  }
}

static bool symbolGoesInGlobalsStream(const CVSymbol &sym, bool isGlobalScope) {
  switch (sym.kind()) {
  case SymbolKind::S_CONSTANT:
  case SymbolKind::S_GDATA32:
  // S_LDATA32 goes in both the module stream and the globals stream.
  case SymbolKind::S_LDATA32:
  case SymbolKind::S_GPROC32:
  case SymbolKind::S_LPROC32:
  // We really should not be seeing S_PROCREF and S_LPROCREF in the first place
  // since they are synthesized by the linker in response to S_GPROC32 and
  // S_LPROC32, but if we do see them, copy them straight through.
  case SymbolKind::S_PROCREF:
  case SymbolKind::S_LPROCREF:
    return true;
  // S_UDT records go in the globals stream if it is a global S_UDT.
  case SymbolKind::S_UDT:
    return isGlobalScope;
  default:
    return false;
  }
}

static void addGlobalSymbol(pdb::GSIStreamBuilder &builder, uint16_t modIndex,
                            unsigned symOffset, const CVSymbol &sym) {
  switch (sym.kind()) {
  case SymbolKind::S_CONSTANT:
  case SymbolKind::S_UDT:
  case SymbolKind::S_GDATA32:
  case SymbolKind::S_LDATA32:
  case SymbolKind::S_PROCREF:
  case SymbolKind::S_LPROCREF:
    builder.addGlobalSymbol(sym);
    break;
  case SymbolKind::S_GPROC32:
  case SymbolKind::S_LPROC32: {
    SymbolRecordKind k = SymbolRecordKind::ProcRefSym;
    if (sym.kind() == SymbolKind::S_LPROC32)
      k = SymbolRecordKind::LocalProcRef;
    ProcRefSym ps(k);
    ps.Module = modIndex;
    // For some reason, MSVC seems to add one to this value.
    ++ps.Module;
    ps.Name = getSymbolName(sym);
    ps.SumName = 0;
    ps.SymOffset = symOffset;
    builder.addGlobalSymbol(ps);
    break;
  }
  default:
    llvm_unreachable("Invalid symbol kind!");
  }
}

void PDBLinker::mergeSymbolRecords(ObjFile *file, const CVIndexMap &indexMap,
                                   std::vector<ulittle32_t *> &stringTableRefs,
                                   BinaryStreamRef symData) {
  ArrayRef<uint8_t> symsBuffer;
  cantFail(symData.readBytes(0, symData.getLength(), symsBuffer));
  SmallVector<SymbolScope, 4> scopes;

  // Iterate every symbol to check if any need to be realigned, and if so, how
  // much space we need to allocate for them.
  bool needsRealignment = false;
  unsigned totalRealignedSize = 0;
  auto ec = forEachCodeViewRecord<CVSymbol>(
      symsBuffer, [&](CVSymbol sym) -> llvm::Error {
        unsigned realignedSize =
            alignTo(sym.length(), alignOf(CodeViewContainer::Pdb));
        needsRealignment |= realignedSize != sym.length();
        totalRealignedSize += realignedSize;
        return Error::success();
      });

  // If any of the symbol record lengths was corrupt, ignore them all, warn
  // about it, and move on.
  if (ec) {
    warn("corrupt symbol records in " + file->getName());
    consumeError(std::move(ec));
    return;
  }

  // If any symbol needed realignment, allocate enough contiguous memory for
  // them all. Typically symbol subsections are small enough that this will not
  // cause fragmentation.
  MutableArrayRef<uint8_t> alignedSymbolMem;
  if (needsRealignment) {
    void *alignedData =
        alloc.Allocate(totalRealignedSize, alignOf(CodeViewContainer::Pdb));
    alignedSymbolMem = makeMutableArrayRef(
        reinterpret_cast<uint8_t *>(alignedData), totalRealignedSize);
  }

  // Iterate again, this time doing the real work.
  unsigned curSymOffset = file->moduleDBI->getNextSymbolOffset();
  ArrayRef<uint8_t> bulkSymbols;
  cantFail(forEachCodeViewRecord<CVSymbol>(
      symsBuffer, [&](CVSymbol sym) -> llvm::Error {
        // Align the record if required.
        MutableArrayRef<uint8_t> recordBytes;
        if (needsRealignment) {
          recordBytes = copyAndAlignSymbol(sym, alignedSymbolMem);
          sym = CVSymbol(recordBytes);
        } else {
          // Otherwise, we can actually mutate the symbol directly, since we
          // copied it to apply relocations.
          recordBytes = makeMutableArrayRef(
              const_cast<uint8_t *>(sym.data().data()), sym.length());
        }

        // Discover type index references in the record. Skip it if we don't
        // know where they are.
        SmallVector<TiReference, 32> typeRefs;
        if (!discoverTypeIndicesInSymbol(sym, typeRefs)) {
          log("ignoring unknown symbol record with kind 0x" +
              utohexstr(sym.kind()));
          return Error::success();
        }

        // Re-map all the type index references.
        remapTypesInSymbolRecord(file, sym.kind(), recordBytes, indexMap,
                                 typeRefs);

        // An object file may have S_xxx_ID symbols, but these get converted to
        // "real" symbols in a PDB.
        translateIdSymbols(recordBytes, tMerger.getIDTable());
        sym = CVSymbol(recordBytes);

        // If this record refers to an offset in the object file's string table,
        // add that item to the global PDB string table and re-write the index.
        recordStringTableReferences(sym.kind(), recordBytes, stringTableRefs);

        // Fill in "Parent" and "End" fields by maintaining a stack of scopes.
        if (symbolOpensScope(sym.kind()))
          scopeStackOpen(scopes, curSymOffset, sym);
        else if (symbolEndsScope(sym.kind()))
          scopeStackClose(scopes, curSymOffset, file);

        // Add the symbol to the globals stream if necessary.  Do this before
        // adding the symbol to the module since we may need to get the next
        // symbol offset, and writing to the module's symbol stream will update
        // that offset.
        if (symbolGoesInGlobalsStream(sym, scopes.empty())) {
          addGlobalSymbol(builder.getGsiBuilder(),
                          file->moduleDBI->getModuleIndex(), curSymOffset, sym);
          ++globalSymbols;
        }

        if (symbolGoesInModuleStream(sym, scopes.empty())) {
          // Add symbols to the module in bulk. If this symbol is contiguous
          // with the previous run of symbols to add, combine the ranges. If
          // not, close the previous range of symbols and start a new one.
          if (sym.data().data() == bulkSymbols.end()) {
            bulkSymbols = makeArrayRef(bulkSymbols.data(),
                                       bulkSymbols.size() + sym.length());
          } else {
            file->moduleDBI->addSymbolsInBulk(bulkSymbols);
            bulkSymbols = recordBytes;
          }
          curSymOffset += sym.length();
          ++moduleSymbols;
        }
        return Error::success();
      }));

  // Add any remaining symbols we've accumulated.
  file->moduleDBI->addSymbolsInBulk(bulkSymbols);
}

// Allocate memory for a .debug$S / .debug$F section and relocate it.
static ArrayRef<uint8_t> relocateDebugChunk(BumpPtrAllocator &alloc,
                                            SectionChunk &debugChunk) {
  uint8_t *buffer = alloc.Allocate<uint8_t>(debugChunk.getSize());
  assert(debugChunk.getOutputSectionIdx() == 0 &&
         "debug sections should not be in output sections");
  debugChunk.writeTo(buffer);
  return makeArrayRef(buffer, debugChunk.getSize());
}

static pdb::SectionContrib createSectionContrib(const Chunk *c, uint32_t modi) {
  OutputSection *os = c ? c->getOutputSection() : nullptr;
  pdb::SectionContrib sc;
  memset(&sc, 0, sizeof(sc));
  sc.ISect = os ? os->sectionIndex : llvm::pdb::kInvalidStreamIndex;
  sc.Off = c && os ? c->getRVA() - os->getRVA() : 0;
  sc.Size = c ? c->getSize() : -1;
  if (auto *secChunk = dyn_cast_or_null<SectionChunk>(c)) {
    sc.Characteristics = secChunk->header->Characteristics;
    sc.Imod = secChunk->file->moduleDBI->getModuleIndex();
    ArrayRef<uint8_t> contents = secChunk->getContents();
    JamCRC crc(0);
    ArrayRef<char> charContents = makeArrayRef(
        reinterpret_cast<const char *>(contents.data()), contents.size());
    crc.update(charContents);
    sc.DataCrc = crc.getCRC();
  } else {
    sc.Characteristics = os ? os->header.Characteristics : 0;
    sc.Imod = modi;
  }
  sc.RelocCrc = 0; // FIXME

  return sc;
}

static uint32_t
translateStringTableIndex(uint32_t objIndex,
                          const DebugStringTableSubsectionRef &objStrTable,
                          DebugStringTableSubsection &pdbStrTable) {
  auto expectedString = objStrTable.getString(objIndex);
  if (!expectedString) {
    warn("Invalid string table reference");
    consumeError(expectedString.takeError());
    return 0;
  }

  return pdbStrTable.insert(*expectedString);
}

void DebugSHandler::handleDebugS(lld::coff::SectionChunk &debugS) {
  DebugSubsectionArray subsections;

  ArrayRef<uint8_t> relocatedDebugContents = SectionChunk::consumeDebugMagic(
      relocateDebugChunk(linker.alloc, debugS), debugS.getSectionName());

  BinaryStreamReader reader(relocatedDebugContents, support::little);
  exitOnErr(reader.readArray(subsections, relocatedDebugContents.size()));

  for (const DebugSubsectionRecord &ss : subsections) {
    // Ignore subsections with the 'ignore' bit. Some versions of the Visual C++
    // runtime have subsections with this bit set.
    if (uint32_t(ss.kind()) & codeview::SubsectionIgnoreFlag)
      continue;

    switch (ss.kind()) {
    case DebugSubsectionKind::StringTable: {
      assert(!cVStrTab.valid() &&
             "Encountered multiple string table subsections!");
      exitOnErr(cVStrTab.initialize(ss.getRecordData()));
      break;
    }
    case DebugSubsectionKind::FileChecksums:
      assert(!checksums.valid() &&
             "Encountered multiple checksum subsections!");
      exitOnErr(checksums.initialize(ss.getRecordData()));
      break;
    case DebugSubsectionKind::Lines:
      // We can add the relocated line table directly to the PDB without
      // modification because the file checksum offsets will stay the same.
      file.moduleDBI->addDebugSubsection(ss);
      break;
    case DebugSubsectionKind::InlineeLines:
      assert(!inlineeLines.valid() &&
             "Encountered multiple inlinee lines subsections!");
      exitOnErr(inlineeLines.initialize(ss.getRecordData()));
      break;
    case DebugSubsectionKind::FrameData: {
      // We need to re-write string table indices here, so save off all
      // frame data subsections until we've processed the entire list of
      // subsections so that we can be sure we have the string table.
      DebugFrameDataSubsectionRef fds;
      exitOnErr(fds.initialize(ss.getRecordData()));
      newFpoFrames.push_back(std::move(fds));
      break;
    }
    case DebugSubsectionKind::Symbols: {
      linker.mergeSymbolRecords(&file, indexMap, stringTableReferences,
                                ss.getRecordData());
      break;
    }

    case DebugSubsectionKind::CrossScopeImports:
    case DebugSubsectionKind::CrossScopeExports:
      // These appear to relate to cross-module optimization, so we might use
      // these for ThinLTO.
      break;

    case DebugSubsectionKind::ILLines:
    case DebugSubsectionKind::FuncMDTokenMap:
    case DebugSubsectionKind::TypeMDTokenMap:
    case DebugSubsectionKind::MergedAssemblyInput:
      // These appear to relate to .Net assembly info.
      break;

    case DebugSubsectionKind::CoffSymbolRVA:
      // Unclear what this is for.
      break;

    default:
      warn("ignoring unknown debug$S subsection kind 0x" +
           utohexstr(uint32_t(ss.kind())) + " in file " + toString(&file));
      break;
    }
  }
}

static Expected<StringRef>
getFileName(const DebugStringTableSubsectionRef &strings,
            const DebugChecksumsSubsectionRef &checksums, uint32_t fileID) {
  auto iter = checksums.getArray().at(fileID);
  if (iter == checksums.getArray().end())
    return make_error<CodeViewError>(cv_error_code::no_records);
  uint32_t offset = iter->FileNameOffset;
  return strings.getString(offset);
}

std::shared_ptr<DebugInlineeLinesSubsection>
DebugSHandler::mergeInlineeLines(DebugChecksumsSubsection *newChecksums) {
  auto newInlineeLines = std::make_shared<DebugInlineeLinesSubsection>(
      *newChecksums, inlineeLines.hasExtraFiles());

  for (const InlineeSourceLine &line : inlineeLines) {
    TypeIndex inlinee = line.Header->Inlinee;
    uint32_t fileID = line.Header->FileID;
    uint32_t sourceLine = line.Header->SourceLineNum;

    ArrayRef<TypeIndex> typeOrItemMap =
        indexMap.isTypeServerMap ? indexMap.ipiMap : indexMap.tpiMap;
    if (!remapTypeIndex(inlinee, typeOrItemMap)) {
      log("ignoring inlinee line record in " + file.getName() +
          " with bad inlinee index 0x" + utohexstr(inlinee.getIndex()));
      continue;
    }

    SmallString<128> filename =
        exitOnErr(getFileName(cVStrTab, checksums, fileID));
    pdbMakeAbsolute(filename);
    newInlineeLines->addInlineSite(inlinee, filename, sourceLine);

    if (inlineeLines.hasExtraFiles()) {
      for (uint32_t extraFileId : line.ExtraFiles) {
        filename = exitOnErr(getFileName(cVStrTab, checksums, extraFileId));
        pdbMakeAbsolute(filename);
        newInlineeLines->addExtraFile(filename);
      }
    }
  }

  return newInlineeLines;
}

void DebugSHandler::finish() {
  pdb::DbiStreamBuilder &dbiBuilder = linker.builder.getDbiBuilder();

  // We should have seen all debug subsections across the entire object file now
  // which means that if a StringTable subsection and Checksums subsection were
  // present, now is the time to handle them.
  if (!cVStrTab.valid()) {
    if (checksums.valid())
      fatal(".debug$S sections with a checksums subsection must also contain a "
            "string table subsection");

    if (!stringTableReferences.empty())
      warn("No StringTable subsection was encountered, but there are string "
           "table references");
    return;
  }

  // Rewrite string table indices in the Fpo Data and symbol records to refer to
  // the global PDB string table instead of the object file string table.
  for (DebugFrameDataSubsectionRef &fds : newFpoFrames) {
    const ulittle32_t *reloc = fds.getRelocPtr();
    for (codeview::FrameData fd : fds) {
      fd.RvaStart += *reloc;
      fd.FrameFunc =
          translateStringTableIndex(fd.FrameFunc, cVStrTab, linker.pdbStrTab);
      dbiBuilder.addNewFpoData(fd);
    }
  }

  for (ulittle32_t *ref : stringTableReferences)
    *ref = translateStringTableIndex(*ref, cVStrTab, linker.pdbStrTab);

  // Make a new file checksum table that refers to offsets in the PDB-wide
  // string table. Generally the string table subsection appears after the
  // checksum table, so we have to do this after looping over all the
  // subsections.
  auto newChecksums = make_unique<DebugChecksumsSubsection>(linker.pdbStrTab);
  for (FileChecksumEntry &fc : checksums) {
    SmallString<128> filename =
        exitOnErr(cVStrTab.getString(fc.FileNameOffset));
    pdbMakeAbsolute(filename);
    exitOnErr(dbiBuilder.addModuleSourceFile(*file.moduleDBI, filename));
    newChecksums->addChecksum(filename, fc.Kind, fc.Checksum);
  }

  // Rewrite inlinee item indices if present.
  if (inlineeLines.valid())
    file.moduleDBI->addDebugSubsection(mergeInlineeLines(newChecksums.get()));

  file.moduleDBI->addDebugSubsection(std::move(newChecksums));
}

void PDBLinker::addObjFile(ObjFile *file, CVIndexMap *externIndexMap) {
  if (file->mergedIntoPDB)
    return;
  file->mergedIntoPDB = true;

  // Before we can process symbol substreams from .debug$S, we need to process
  // type information, file checksums, and the string table.  Add type info to
  // the PDB first, so that we can get the map from object file type and item
  // indices to PDB type and item indices.
  CVIndexMap objectIndexMap;
  auto indexMapResult =
      mergeDebugT(file, externIndexMap ? externIndexMap : &objectIndexMap);

  // If the .debug$T sections fail to merge, assume there is no debug info.
  if (!indexMapResult) {
    if (!config->warnDebugInfoUnusable) {
      consumeError(indexMapResult.takeError());
      return;
    }
    warn("Cannot use debug info for '" + toString(file) + "' [LNK4099]\n" +
         ">>> failed to load reference " +
         StringRef(toString(indexMapResult.takeError())));
    return;
  }

  ScopedTimer t(symbolMergingTimer);

  pdb::DbiStreamBuilder &dbiBuilder = builder.getDbiBuilder();
  DebugSHandler dsh(*this, *file, *indexMapResult);
  // Now do all live .debug$S and .debug$F sections.
  for (SectionChunk *debugChunk : file->getDebugChunks()) {
    if (!debugChunk->live || debugChunk->getSize() == 0)
      continue;

    if (debugChunk->getSectionName() == ".debug$S") {
      dsh.handleDebugS(*debugChunk);
      continue;
    }

    if (debugChunk->getSectionName() == ".debug$F") {
      ArrayRef<uint8_t> relocatedDebugContents =
          relocateDebugChunk(alloc, *debugChunk);

      FixedStreamArray<object::FpoData> fpoRecords;
      BinaryStreamReader reader(relocatedDebugContents, support::little);
      uint32_t count = relocatedDebugContents.size() / sizeof(object::FpoData);
      exitOnErr(reader.readArray(fpoRecords, count));

      // These are already relocated and don't refer to the string table, so we
      // can just copy it.
      for (const object::FpoData &fd : fpoRecords)
        dbiBuilder.addOldFpoData(fd);
      continue;
    }
  }

  // Do any post-processing now that all .debug$S sections have been processed.
  dsh.finish();
}

// Add a module descriptor for every object file. We need to put an absolute
// path to the object into the PDB. If this is a plain object, we make its
// path absolute. If it's an object in an archive, we make the archive path
// absolute.
static void createModuleDBI(pdb::PDBFileBuilder &builder) {
  pdb::DbiStreamBuilder &dbiBuilder = builder.getDbiBuilder();
  SmallString<128> objName;

  for (ObjFile *file : ObjFile::instances) {

    bool inArchive = !file->parentName.empty();
    objName = inArchive ? file->parentName : file->getName();
    pdbMakeAbsolute(objName);
    StringRef modName = inArchive ? file->getName() : StringRef(objName);

    file->moduleDBI = &exitOnErr(dbiBuilder.addModuleInfo(modName));
    file->moduleDBI->setObjFileName(objName);

    ArrayRef<Chunk *> chunks = file->getChunks();
    uint32_t modi = file->moduleDBI->getModuleIndex();

    for (Chunk *c : chunks) {
      auto *secChunk = dyn_cast<SectionChunk>(c);
      if (!secChunk || !secChunk->live)
        continue;
      pdb::SectionContrib sc = createSectionContrib(secChunk, modi);
      file->moduleDBI->setFirstSectionContrib(sc);
      break;
    }
  }
}

static PublicSym32 createPublic(Defined *def) {
  PublicSym32 pub(SymbolKind::S_PUB32);
  pub.Name = def->getName();
  if (auto *d = dyn_cast<DefinedCOFF>(def)) {
    if (d->getCOFFSymbol().isFunctionDefinition())
      pub.Flags = PublicSymFlags::Function;
  } else if (isa<DefinedImportThunk>(def)) {
    pub.Flags = PublicSymFlags::Function;
  }

  OutputSection *os = def->getChunk()->getOutputSection();
  assert(os && "all publics should be in final image");
  pub.Offset = def->getRVA() - os->getRVA();
  pub.Segment = os->sectionIndex;
  return pub;
}

// Add all object files to the PDB. Merge .debug$T sections into IpiData and
// TpiData.
void PDBLinker::addObjectsToPDB() {
  ScopedTimer t1(addObjectsTimer);

  createModuleDBI(builder);

  for (ObjFile *file : ObjFile::instances)
    addObjFile(file);

  builder.getStringTableBuilder().setStrings(pdbStrTab);
  t1.stop();

  // Construct TPI and IPI stream contents.
  ScopedTimer t2(tpiStreamLayoutTimer);
  addTypeInfo(builder.getTpiBuilder(), tMerger.getTypeTable());
  addTypeInfo(builder.getIpiBuilder(), tMerger.getIDTable());
  t2.stop();

  ScopedTimer t3(globalsLayoutTimer);
  // Compute the public and global symbols.
  auto &gsiBuilder = builder.getGsiBuilder();
  std::vector<PublicSym32> publics;
  symtab->forEachSymbol([&publics](Symbol *s) {
    // Only emit defined, live symbols that have a chunk.
    auto *def = dyn_cast<Defined>(s);
    if (def && def->isLive() && def->getChunk())
      publics.push_back(createPublic(def));
  });

  if (!publics.empty()) {
    publicSymbols = publics.size();
    // Sort the public symbols and add them to the stream.
    parallelSort(publics, [](const PublicSym32 &l, const PublicSym32 &r) {
      return l.Name < r.Name;
    });
    for (const PublicSym32 &pub : publics)
      gsiBuilder.addPublicSymbol(pub);
  }
}

void PDBLinker::printStats() {
  if (!config->showSummary)
    return;

  SmallString<256> buffer;
  raw_svector_ostream stream(buffer);

  stream << center_justify("Summary", 80) << '\n'
         << std::string(80, '-') << '\n';

  auto print = [&](uint64_t v, StringRef s) {
    stream << format_decimal(v, 15) << " " << s << '\n';
  };

  print(ObjFile::instances.size(),
        "Input OBJ files (expanded from all cmd-line inputs)");
  print(typeServerIndexMappings.size(), "PDB type server dependencies");
  print(precompTypeIndexMappings.size(), "Precomp OBJ dependencies");
  print(tMerger.getTypeTable().size() + tMerger.getIDTable().size(),
        "Merged TPI records");
  print(pdbStrTab.size(), "Output PDB strings");
  print(globalSymbols, "Global symbol records");
  print(moduleSymbols, "Module symbol records");
  print(publicSymbols, "Public symbol records");

  message(buffer);
}

void PDBLinker::addNatvisFiles() {
  for (StringRef file : config->natvisFiles) {
    ErrorOr<std::unique_ptr<MemoryBuffer>> dataOrErr =
        MemoryBuffer::getFile(file);
    if (!dataOrErr) {
      warn("Cannot open input file: " + file);
      continue;
    }
    builder.addInjectedSource(file, std::move(*dataOrErr));
  }
}

static codeview::CPUType toCodeViewMachine(COFF::MachineTypes machine) {
  switch (machine) {
  case COFF::IMAGE_FILE_MACHINE_AMD64:
    return codeview::CPUType::X64;
  case COFF::IMAGE_FILE_MACHINE_ARM:
    return codeview::CPUType::ARM7;
  case COFF::IMAGE_FILE_MACHINE_ARM64:
    return codeview::CPUType::ARM64;
  case COFF::IMAGE_FILE_MACHINE_ARMNT:
    return codeview::CPUType::ARMNT;
  case COFF::IMAGE_FILE_MACHINE_I386:
    return codeview::CPUType::Intel80386;
  default:
    llvm_unreachable("Unsupported CPU Type");
  }
}

// Mimic MSVC which surrounds arguments containing whitespace with quotes.
// Double double-quotes are handled, so that the resulting string can be
// executed again on the cmd-line.
static std::string quote(ArrayRef<StringRef> args) {
  std::string r;
  r.reserve(256);
  for (StringRef a : args) {
    if (!r.empty())
      r.push_back(' ');
    bool hasWS = a.find(' ') != StringRef::npos;
    bool hasQ = a.find('"') != StringRef::npos;
    if (hasWS || hasQ)
      r.push_back('"');
    if (hasQ) {
      SmallVector<StringRef, 4> s;
      a.split(s, '"');
      r.append(join(s, "\"\""));
    } else {
      r.append(a);
    }
    if (hasWS || hasQ)
      r.push_back('"');
  }
  return r;
}

static void fillLinkerVerRecord(Compile3Sym &cs) {
  cs.Machine = toCodeViewMachine(config->machine);
  // Interestingly, if we set the string to 0.0.0.0, then when trying to view
  // local variables WinDbg emits an error that private symbols are not present.
  // By setting this to a valid MSVC linker version string, local variables are
  // displayed properly.   As such, even though it is not representative of
  // LLVM's version information, we need this for compatibility.
  cs.Flags = CompileSym3Flags::None;
  cs.VersionBackendBuild = 25019;
  cs.VersionBackendMajor = 14;
  cs.VersionBackendMinor = 10;
  cs.VersionBackendQFE = 0;

  // MSVC also sets the frontend to 0.0.0.0 since this is specifically for the
  // linker module (which is by definition a backend), so we don't need to do
  // anything here.  Also, it seems we can use "LLVM Linker" for the linker name
  // without any problems.  Only the backend version has to be hardcoded to a
  // magic number.
  cs.VersionFrontendBuild = 0;
  cs.VersionFrontendMajor = 0;
  cs.VersionFrontendMinor = 0;
  cs.VersionFrontendQFE = 0;
  cs.Version = "LLVM Linker";
  cs.setLanguage(SourceLanguage::Link);
}

static void addCommonLinkerModuleSymbols(StringRef path,
                                         pdb::DbiModuleDescriptorBuilder &mod,
                                         BumpPtrAllocator &allocator) {
  ObjNameSym ons(SymbolRecordKind::ObjNameSym);
  EnvBlockSym ebs(SymbolRecordKind::EnvBlockSym);
  Compile3Sym cs(SymbolRecordKind::Compile3Sym);
  fillLinkerVerRecord(cs);

  ons.Name = "* Linker *";
  ons.Signature = 0;

  ArrayRef<StringRef> args = makeArrayRef(config->argv).drop_front();
  std::string argStr = quote(args);
  ebs.Fields.push_back("cwd");
  SmallString<64> cwd;
  if (config->pdbSourcePath.empty())
    sys::fs::current_path(cwd);
  else
    cwd = config->pdbSourcePath;
  ebs.Fields.push_back(cwd);
  ebs.Fields.push_back("exe");
  SmallString<64> exe = config->argv[0];
  pdbMakeAbsolute(exe);
  ebs.Fields.push_back(exe);
  ebs.Fields.push_back("pdb");
  ebs.Fields.push_back(path);
  ebs.Fields.push_back("cmd");
  ebs.Fields.push_back(argStr);
  mod.addSymbol(codeview::SymbolSerializer::writeOneSymbol(
      ons, allocator, CodeViewContainer::Pdb));
  mod.addSymbol(codeview::SymbolSerializer::writeOneSymbol(
      cs, allocator, CodeViewContainer::Pdb));
  mod.addSymbol(codeview::SymbolSerializer::writeOneSymbol(
      ebs, allocator, CodeViewContainer::Pdb));
}

static void addLinkerModuleCoffGroup(PartialSection *sec,
                                     pdb::DbiModuleDescriptorBuilder &mod,
                                     OutputSection &os,
                                     BumpPtrAllocator &allocator) {
  // If there's a section, there's at least one chunk
  assert(!sec->chunks.empty());
  const Chunk *firstChunk = *sec->chunks.begin();
  const Chunk *lastChunk = *sec->chunks.rbegin();

  // Emit COFF group
  CoffGroupSym cgs(SymbolRecordKind::CoffGroupSym);
  cgs.Name = sec->name;
  cgs.Segment = os.sectionIndex;
  cgs.Offset = firstChunk->getRVA() - os.getRVA();
  cgs.Size = lastChunk->getRVA() + lastChunk->getSize() - firstChunk->getRVA();
  cgs.Characteristics = sec->characteristics;

  // Somehow .idata sections & sections groups in the debug symbol stream have
  // the "write" flag set. However the section header for the corresponding
  // .idata section doesn't have it.
  if (cgs.Name.startswith(".idata"))
    cgs.Characteristics |= llvm::COFF::IMAGE_SCN_MEM_WRITE;

  mod.addSymbol(codeview::SymbolSerializer::writeOneSymbol(
      cgs, allocator, CodeViewContainer::Pdb));
}

static void addLinkerModuleSectionSymbol(pdb::DbiModuleDescriptorBuilder &mod,
                                         OutputSection &os,
                                         BumpPtrAllocator &allocator) {
  SectionSym sym(SymbolRecordKind::SectionSym);
  sym.Alignment = 12; // 2^12 = 4KB
  sym.Characteristics = os.header.Characteristics;
  sym.Length = os.getVirtualSize();
  sym.Name = os.name;
  sym.Rva = os.getRVA();
  sym.SectionNumber = os.sectionIndex;
  mod.addSymbol(codeview::SymbolSerializer::writeOneSymbol(
      sym, allocator, CodeViewContainer::Pdb));

  // Skip COFF groups in MinGW because it adds a significant footprint to the
  // PDB, due to each function being in its own section
  if (config->mingw)
    return;

  // Output COFF groups for individual chunks of this section.
  for (PartialSection *sec : os.contribSections) {
    addLinkerModuleCoffGroup(sec, mod, os, allocator);
  }
}

// Add all import files as modules to the PDB.
void PDBLinker::addImportFilesToPDB(ArrayRef<OutputSection *> outputSections) {
  if (ImportFile::instances.empty())
    return;

  std::map<std::string, llvm::pdb::DbiModuleDescriptorBuilder *> dllToModuleDbi;

  for (ImportFile *file : ImportFile::instances) {
    if (!file->live)
      continue;

    if (!file->thunkSym)
      continue;

    if (!file->thunkLive)
        continue;

    std::string dll = StringRef(file->dllName).lower();
    llvm::pdb::DbiModuleDescriptorBuilder *&mod = dllToModuleDbi[dll];
    if (!mod) {
      pdb::DbiStreamBuilder &dbiBuilder = builder.getDbiBuilder();
      SmallString<128> libPath = file->parentName;
      pdbMakeAbsolute(libPath);
      sys::path::native(libPath);

      // Name modules similar to MSVC's link.exe.
      // The first module is the simple dll filename
      llvm::pdb::DbiModuleDescriptorBuilder &firstMod =
          exitOnErr(dbiBuilder.addModuleInfo(file->dllName));
      firstMod.setObjFileName(libPath);
      pdb::SectionContrib sc =
          createSectionContrib(nullptr, llvm::pdb::kInvalidStreamIndex);
      firstMod.setFirstSectionContrib(sc);

      // The second module is where the import stream goes.
      mod = &exitOnErr(dbiBuilder.addModuleInfo("Import:" + file->dllName));
      mod->setObjFileName(libPath);
    }

    DefinedImportThunk *thunk = cast<DefinedImportThunk>(file->thunkSym);
    Chunk *thunkChunk = thunk->getChunk();
    OutputSection *thunkOS = thunkChunk->getOutputSection();

    ObjNameSym ons(SymbolRecordKind::ObjNameSym);
    Compile3Sym cs(SymbolRecordKind::Compile3Sym);
    Thunk32Sym ts(SymbolRecordKind::Thunk32Sym);
    ScopeEndSym es(SymbolRecordKind::ScopeEndSym);

    ons.Name = file->dllName;
    ons.Signature = 0;

    fillLinkerVerRecord(cs);

    ts.Name = thunk->getName();
    ts.Parent = 0;
    ts.End = 0;
    ts.Next = 0;
    ts.Thunk = ThunkOrdinal::Standard;
    ts.Length = thunkChunk->getSize();
    ts.Segment = thunkOS->sectionIndex;
    ts.Offset = thunkChunk->getRVA() - thunkOS->getRVA();

    mod->addSymbol(codeview::SymbolSerializer::writeOneSymbol(
        ons, alloc, CodeViewContainer::Pdb));
    mod->addSymbol(codeview::SymbolSerializer::writeOneSymbol(
        cs, alloc, CodeViewContainer::Pdb));

    SmallVector<SymbolScope, 4> scopes;
    CVSymbol newSym = codeview::SymbolSerializer::writeOneSymbol(
        ts, alloc, CodeViewContainer::Pdb);
    scopeStackOpen(scopes, mod->getNextSymbolOffset(), newSym);

    mod->addSymbol(newSym);

    newSym = codeview::SymbolSerializer::writeOneSymbol(es, alloc,
                                                        CodeViewContainer::Pdb);
    scopeStackClose(scopes, mod->getNextSymbolOffset(), file);

    mod->addSymbol(newSym);

    pdb::SectionContrib sc =
        createSectionContrib(thunk->getChunk(), mod->getModuleIndex());
    mod->setFirstSectionContrib(sc);
  }
}

// Creates a PDB file.
void coff::createPDB(SymbolTable *symtab,
                     ArrayRef<OutputSection *> outputSections,
                     ArrayRef<uint8_t> sectionTable,
                     llvm::codeview::DebugInfo *buildId) {
  ScopedTimer t1(totalPdbLinkTimer);
  PDBLinker pdb(symtab);

  pdb.initialize(buildId);
  pdb.addObjectsToPDB();
  pdb.addImportFilesToPDB(outputSections);
  pdb.addSections(outputSections, sectionTable);
  pdb.addNatvisFiles();

  ScopedTimer t2(diskCommitTimer);
  codeview::GUID guid;
  pdb.commit(&guid);
  memcpy(&buildId->PDB70.Signature, &guid, 16);

  t2.stop();
  t1.stop();
  pdb.printStats();
}

void PDBLinker::initialize(llvm::codeview::DebugInfo *buildId) {
  exitOnErr(builder.initialize(4096)); // 4096 is blocksize

  buildId->Signature.CVSignature = OMF::Signature::PDB70;
  // Signature is set to a hash of the PDB contents when the PDB is done.
  memset(buildId->PDB70.Signature, 0, 16);
  buildId->PDB70.Age = 1;

  // Create streams in MSF for predefined streams, namely
  // PDB, TPI, DBI and IPI.
  for (int i = 0; i < (int)pdb::kSpecialStreamCount; ++i)
    exitOnErr(builder.getMsfBuilder().addStream(0));

  // Add an Info stream.
  auto &infoBuilder = builder.getInfoBuilder();
  infoBuilder.setVersion(pdb::PdbRaw_ImplVer::PdbImplVC70);
  infoBuilder.setHashPDBContentsToGUID(true);

  // Add an empty DBI stream.
  pdb::DbiStreamBuilder &dbiBuilder = builder.getDbiBuilder();
  dbiBuilder.setAge(buildId->PDB70.Age);
  dbiBuilder.setVersionHeader(pdb::PdbDbiV70);
  dbiBuilder.setMachineType(config->machine);
  // Technically we are not link.exe 14.11, but there are known cases where
  // debugging tools on Windows expect Microsoft-specific version numbers or
  // they fail to work at all.  Since we know we produce PDBs that are
  // compatible with LINK 14.11, we set that version number here.
  dbiBuilder.setBuildNumber(14, 11);
}

void PDBLinker::addSections(ArrayRef<OutputSection *> outputSections,
                            ArrayRef<uint8_t> sectionTable) {
  // It's not entirely clear what this is, but the * Linker * module uses it.
  pdb::DbiStreamBuilder &dbiBuilder = builder.getDbiBuilder();
  nativePath = config->pdbPath;
  pdbMakeAbsolute(nativePath);
  uint32_t pdbFilePathNI = dbiBuilder.addECName(nativePath);
  auto &linkerModule = exitOnErr(dbiBuilder.addModuleInfo("* Linker *"));
  linkerModule.setPdbFilePathNI(pdbFilePathNI);
  addCommonLinkerModuleSymbols(nativePath, linkerModule, alloc);

  // Add section contributions. They must be ordered by ascending RVA.
  for (OutputSection *os : outputSections) {
    addLinkerModuleSectionSymbol(linkerModule, *os, alloc);
    for (Chunk *c : os->chunks) {
      pdb::SectionContrib sc =
          createSectionContrib(c, linkerModule.getModuleIndex());
      builder.getDbiBuilder().addSectionContrib(sc);
    }
  }

  // The * Linker * first section contrib is only used along with /INCREMENTAL,
  // to provide trampolines thunks for incremental function patching. Set this
  // as "unused" because LLD doesn't support /INCREMENTAL link.
  pdb::SectionContrib sc =
      createSectionContrib(nullptr, llvm::pdb::kInvalidStreamIndex);
  linkerModule.setFirstSectionContrib(sc);

  // Add Section Map stream.
  ArrayRef<object::coff_section> sections = {
      (const object::coff_section *)sectionTable.data(),
      sectionTable.size() / sizeof(object::coff_section)};
  sectionMap = pdb::DbiStreamBuilder::createSectionMap(sections);
  dbiBuilder.setSectionMap(sectionMap);

  // Add COFF section header stream.
  exitOnErr(
      dbiBuilder.addDbgStream(pdb::DbgHeaderType::SectionHdr, sectionTable));
}

void PDBLinker::commit(codeview::GUID *guid) {
  // Write to a file.
  exitOnErr(builder.commit(config->pdbPath, guid));
}

static uint32_t getSecrelReloc() {
  switch (config->machine) {
  case AMD64:
    return COFF::IMAGE_REL_AMD64_SECREL;
  case I386:
    return COFF::IMAGE_REL_I386_SECREL;
  case ARMNT:
    return COFF::IMAGE_REL_ARM_SECREL;
  case ARM64:
    return COFF::IMAGE_REL_ARM64_SECREL;
  default:
    llvm_unreachable("unknown machine type");
  }
}

// Try to find a line table for the given offset Addr into the given chunk C.
// If a line table was found, the line table, the string and checksum tables
// that are used to interpret the line table, and the offset of Addr in the line
// table are stored in the output arguments. Returns whether a line table was
// found.
static bool findLineTable(const SectionChunk *c, uint32_t addr,
                          DebugStringTableSubsectionRef &cVStrTab,
                          DebugChecksumsSubsectionRef &checksums,
                          DebugLinesSubsectionRef &lines,
                          uint32_t &offsetInLinetable) {
  ExitOnError exitOnErr;
  uint32_t secrelReloc = getSecrelReloc();

  for (SectionChunk *dbgC : c->file->getDebugChunks()) {
    if (dbgC->getSectionName() != ".debug$S")
      continue;

    // Build a mapping of SECREL relocations in dbgC that refer to `c`.
    DenseMap<uint32_t, uint32_t> secrels;
    for (const coff_relocation &r : dbgC->getRelocs()) {
      if (r.Type != secrelReloc)
        continue;

      if (auto *s = dyn_cast_or_null<DefinedRegular>(
              c->file->getSymbols()[r.SymbolTableIndex]))
        if (s->getChunk() == c)
          secrels[r.VirtualAddress] = s->getValue();
    }

    ArrayRef<uint8_t> contents =
        SectionChunk::consumeDebugMagic(dbgC->getContents(), ".debug$S");
    DebugSubsectionArray subsections;
    BinaryStreamReader reader(contents, support::little);
    exitOnErr(reader.readArray(subsections, contents.size()));

    for (const DebugSubsectionRecord &ss : subsections) {
      switch (ss.kind()) {
      case DebugSubsectionKind::StringTable: {
        assert(!cVStrTab.valid() &&
               "Encountered multiple string table subsections!");
        exitOnErr(cVStrTab.initialize(ss.getRecordData()));
        break;
      }
      case DebugSubsectionKind::FileChecksums:
        assert(!checksums.valid() &&
               "Encountered multiple checksum subsections!");
        exitOnErr(checksums.initialize(ss.getRecordData()));
        break;
      case DebugSubsectionKind::Lines: {
        ArrayRef<uint8_t> bytes;
        auto ref = ss.getRecordData();
        exitOnErr(ref.readLongestContiguousChunk(0, bytes));
        size_t offsetInDbgC = bytes.data() - dbgC->getContents().data();

        // Check whether this line table refers to C.
        auto i = secrels.find(offsetInDbgC);
        if (i == secrels.end())
          break;

        // Check whether this line table covers Addr in C.
        DebugLinesSubsectionRef linesTmp;
        exitOnErr(linesTmp.initialize(BinaryStreamReader(ref)));
        uint32_t offsetInC = i->second + linesTmp.header()->RelocOffset;
        if (addr < offsetInC || addr >= offsetInC + linesTmp.header()->CodeSize)
          break;

        assert(!lines.header() &&
               "Encountered multiple line tables for function!");
        exitOnErr(lines.initialize(BinaryStreamReader(ref)));
        offsetInLinetable = addr - offsetInC;
        break;
      }
      default:
        break;
      }

      if (cVStrTab.valid() && checksums.valid() && lines.header())
        return true;
    }
  }

  return false;
}

// Use CodeView line tables to resolve a file and line number for the given
// offset into the given chunk and return them, or {"", 0} if a line table was
// not found.
std::pair<StringRef, uint32_t> coff::getFileLine(const SectionChunk *c,
                                                 uint32_t addr) {
  ExitOnError exitOnErr;

  DebugStringTableSubsectionRef cVStrTab;
  DebugChecksumsSubsectionRef checksums;
  DebugLinesSubsectionRef lines;
  uint32_t offsetInLinetable;

  if (!findLineTable(c, addr, cVStrTab, checksums, lines, offsetInLinetable))
    return {"", 0};

  Optional<uint32_t> nameIndex;
  Optional<uint32_t> lineNumber;
  for (LineColumnEntry &entry : lines) {
    for (const LineNumberEntry &ln : entry.LineNumbers) {
      LineInfo li(ln.Flags);
      if (ln.Offset > offsetInLinetable) {
        if (!nameIndex) {
          nameIndex = entry.NameIndex;
          lineNumber = li.getStartLine();
        }
        StringRef filename =
            exitOnErr(getFileName(cVStrTab, checksums, *nameIndex));
        return {filename, *lineNumber};
      }
      nameIndex = entry.NameIndex;
      lineNumber = li.getStartLine();
    }
  }
  if (!nameIndex)
    return {"", 0};
  StringRef filename = exitOnErr(getFileName(cVStrTab, checksums, *nameIndex));
  return {filename, *lineNumber};
}
