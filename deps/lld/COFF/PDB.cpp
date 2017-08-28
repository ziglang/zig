//===- PDB.cpp ------------------------------------------------------------===//
//
//                             The LLVM Linker
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//

#include "PDB.h"
#include "Chunks.h"
#include "Config.h"
#include "Error.h"
#include "SymbolTable.h"
#include "Symbols.h"
#include "llvm/DebugInfo/CodeView/CVDebugRecord.h"
#include "llvm/DebugInfo/CodeView/DebugSubsectionRecord.h"
#include "llvm/DebugInfo/CodeView/LazyRandomTypeCollection.h"
#include "llvm/DebugInfo/CodeView/SymbolSerializer.h"
#include "llvm/DebugInfo/CodeView/TypeDeserializer.h"
#include "llvm/DebugInfo/CodeView/TypeDumpVisitor.h"
#include "llvm/DebugInfo/CodeView/TypeIndexDiscovery.h"
#include "llvm/DebugInfo/CodeView/TypeStreamMerger.h"
#include "llvm/DebugInfo/CodeView/TypeTableBuilder.h"
#include "llvm/DebugInfo/MSF/MSFBuilder.h"
#include "llvm/DebugInfo/MSF/MSFCommon.h"
#include "llvm/DebugInfo/PDB/GenericError.h"
#include "llvm/DebugInfo/PDB/Native/DbiModuleDescriptorBuilder.h"
#include "llvm/DebugInfo/PDB/Native/DbiStream.h"
#include "llvm/DebugInfo/PDB/Native/DbiStreamBuilder.h"
#include "llvm/DebugInfo/PDB/Native/InfoStream.h"
#include "llvm/DebugInfo/PDB/Native/InfoStreamBuilder.h"
#include "llvm/DebugInfo/PDB/Native/NativeSession.h"
#include "llvm/DebugInfo/PDB/Native/PDBFile.h"
#include "llvm/DebugInfo/PDB/Native/PDBFileBuilder.h"
#include "llvm/DebugInfo/PDB/Native/PDBStringTableBuilder.h"
#include "llvm/DebugInfo/PDB/Native/TpiStream.h"
#include "llvm/DebugInfo/PDB/Native/TpiStreamBuilder.h"
#include "llvm/DebugInfo/PDB/PDB.h"
#include "llvm/Object/COFF.h"
#include "llvm/Support/BinaryByteStream.h"
#include "llvm/Support/Endian.h"
#include "llvm/Support/FileOutputBuffer.h"
#include "llvm/Support/Path.h"
#include "llvm/Support/ScopedPrinter.h"
#include <memory>

using namespace lld;
using namespace lld::coff;
using namespace llvm;
using namespace llvm::codeview;

using llvm::object::coff_section;

static ExitOnError ExitOnErr;

namespace {
/// Map from type index and item index in a type server PDB to the
/// corresponding index in the destination PDB.
struct CVIndexMap {
  SmallVector<TypeIndex, 0> TPIMap;
  SmallVector<TypeIndex, 0> IPIMap;
  bool IsTypeServerMap = false;
};

class PDBLinker {
public:
  PDBLinker(SymbolTable *Symtab)
      : Alloc(), Symtab(Symtab), Builder(Alloc), TypeTable(Alloc),
        IDTable(Alloc) {}

  /// Emit the basic PDB structure: initial streams, headers, etc.
  void initialize(const llvm::codeview::DebugInfo *DI);

  /// Link CodeView from each object file in the symbol table into the PDB.
  void addObjectsToPDB();

  /// Link CodeView from a single object file into the PDB.
  void addObjectFile(ObjectFile *File);

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
  /// caller-provided ObjectIndexMap.
  const CVIndexMap &mergeDebugT(ObjectFile *File, CVIndexMap &ObjectIndexMap);

  const CVIndexMap &maybeMergeTypeServerPDB(ObjectFile *File,
                                            TypeServer2Record &TS);

  /// Add the section map and section contributions to the PDB.
  void addSections(ArrayRef<uint8_t> SectionTable);

  /// Write the PDB to disk.
  void commit();

private:
  BumpPtrAllocator Alloc;

  SymbolTable *Symtab;

  pdb::PDBFileBuilder Builder;

  /// Type records that will go into the PDB TPI stream.
  TypeTableBuilder TypeTable;

  /// Item records that will go into the PDB IPI stream.
  TypeTableBuilder IDTable;

  /// PDBs use a single global string table for filenames in the file checksum
  /// table.
  DebugStringTableSubsection PDBStrTab;

  llvm::SmallString<128> NativePath;

  std::vector<pdb::SecMapEntry> SectionMap;

  /// Type index mappings of type server PDBs that we've loaded so far.
  std::map<GUID, CVIndexMap> TypeServerIndexMappings;
};
}

// Returns a list of all SectionChunks.
static void addSectionContribs(SymbolTable *Symtab,
                               pdb::DbiStreamBuilder &DbiBuilder) {
  for (Chunk *C : Symtab->getChunks())
    if (auto *SC = dyn_cast<SectionChunk>(C))
      DbiBuilder.addSectionContrib(SC->File->ModuleDBI, SC->Header);
}

static SectionChunk *findByName(std::vector<SectionChunk *> &Sections,
                                StringRef Name) {
  for (SectionChunk *C : Sections)
    if (C->getSectionName() == Name)
      return C;
  return nullptr;
}

static ArrayRef<uint8_t> consumeDebugMagic(ArrayRef<uint8_t> Data,
                                           StringRef SecName) {
  // First 4 bytes are section magic.
  if (Data.size() < 4)
    fatal(SecName + " too short");
  if (support::endian::read32le(Data.data()) != COFF::DEBUG_SECTION_MAGIC)
    fatal(SecName + " has an invalid magic");
  return Data.slice(4);
}

static ArrayRef<uint8_t> getDebugSection(ObjectFile *File, StringRef SecName) {
  if (SectionChunk *Sec = findByName(File->getDebugChunks(), SecName))
    return consumeDebugMagic(Sec->getContents(), SecName);
  return {};
}

static void addTypeInfo(pdb::TpiStreamBuilder &TpiBuilder,
                        TypeTableBuilder &TypeTable) {
  // Start the TPI or IPI stream header.
  TpiBuilder.setVersionHeader(pdb::PdbTpiV80);

  // Flatten the in memory type table.
  TypeTable.ForEachRecord([&](TypeIndex TI, ArrayRef<uint8_t> Rec) {
    // FIXME: Hash types.
    TpiBuilder.addTypeRecord(Rec, None);
  });
}

static Optional<TypeServer2Record>
maybeReadTypeServerRecord(CVTypeArray &Types) {
  auto I = Types.begin();
  if (I == Types.end())
    return None;
  const CVType &Type = *I;
  if (Type.kind() != LF_TYPESERVER2)
    return None;
  TypeServer2Record TS;
  if (auto EC = TypeDeserializer::deserializeAs(const_cast<CVType &>(Type), TS))
    fatal(EC, "error reading type server record");
  return std::move(TS);
}

const CVIndexMap &PDBLinker::mergeDebugT(ObjectFile *File,
                                         CVIndexMap &ObjectIndexMap) {
  ArrayRef<uint8_t> Data = getDebugSection(File, ".debug$T");
  if (Data.empty())
    return ObjectIndexMap;

  BinaryByteStream Stream(Data, support::little);
  CVTypeArray Types;
  BinaryStreamReader Reader(Stream);
  if (auto EC = Reader.readArray(Types, Reader.getLength()))
    fatal(EC, "Reader::readArray failed");

  // Look through type servers. If we've already seen this type server, don't
  // merge any type information.
  if (Optional<TypeServer2Record> TS = maybeReadTypeServerRecord(Types))
    return maybeMergeTypeServerPDB(File, *TS);

  // This is a /Z7 object. Fill in the temporary, caller-provided
  // ObjectIndexMap.
  if (auto Err = mergeTypeAndIdRecords(IDTable, TypeTable,
                                       ObjectIndexMap.TPIMap, Types))
    fatal(Err, "codeview::mergeTypeAndIdRecords failed");
  return ObjectIndexMap;
}

static Expected<std::unique_ptr<pdb::NativeSession>>
tryToLoadPDB(const GUID &GuidFromObj, StringRef TSPath) {
  std::unique_ptr<pdb::IPDBSession> ThisSession;
  if (auto EC =
          pdb::loadDataForPDB(pdb::PDB_ReaderType::Native, TSPath, ThisSession))
    return std::move(EC);

  std::unique_ptr<pdb::NativeSession> NS(
      static_cast<pdb::NativeSession *>(ThisSession.release()));
  pdb::PDBFile &File = NS->getPDBFile();
  auto ExpectedInfo = File.getPDBInfoStream();
  // All PDB Files should have an Info stream.
  if (!ExpectedInfo)
    return ExpectedInfo.takeError();

  // Just because a file with a matching name was found and it was an actual
  // PDB file doesn't mean it matches.  For it to match the InfoStream's GUID
  // must match the GUID specified in the TypeServer2 record.
  if (ExpectedInfo->getGuid() != GuidFromObj)
    return make_error<pdb::GenericError>(
        pdb::generic_error_code::type_server_not_found, TSPath);

  return std::move(NS);
}

const CVIndexMap &PDBLinker::maybeMergeTypeServerPDB(ObjectFile *File,
                                                     TypeServer2Record &TS) {
  // First, check if we already loaded a PDB with this GUID. Return the type
  // index mapping if we have it.
  auto Insertion = TypeServerIndexMappings.insert({TS.getGuid(), CVIndexMap()});
  CVIndexMap &IndexMap = Insertion.first->second;
  if (!Insertion.second)
    return IndexMap;

  // Mark this map as a type server map.
  IndexMap.IsTypeServerMap = true;

  // Check for a PDB at:
  // 1. The given file path
  // 2. Next to the object file or archive file
  auto ExpectedSession = tryToLoadPDB(TS.getGuid(), TS.getName());
  if (!ExpectedSession) {
    consumeError(ExpectedSession.takeError());
    StringRef LocalPath =
        !File->ParentName.empty() ? File->ParentName : File->getName();
    SmallString<128> Path = sys::path::parent_path(LocalPath);
    sys::path::append(
        Path, sys::path::filename(TS.getName(), sys::path::Style::windows));
    ExpectedSession = tryToLoadPDB(TS.getGuid(), Path);
  }
  if (auto E = ExpectedSession.takeError())
    fatal(E, "Type server PDB was not found");

  // Merge TPI first, because the IPI stream will reference type indices.
  auto ExpectedTpi = (*ExpectedSession)->getPDBFile().getPDBTpiStream();
  if (auto E = ExpectedTpi.takeError())
    fatal(E, "Type server does not have TPI stream");
  if (auto Err = mergeTypeRecords(TypeTable, IndexMap.TPIMap,
                                  ExpectedTpi->typeArray()))
    fatal(Err, "codeview::mergeTypeRecords failed");

  // Merge IPI.
  auto ExpectedIpi = (*ExpectedSession)->getPDBFile().getPDBIpiStream();
  if (auto E = ExpectedIpi.takeError())
    fatal(E, "Type server does not have TPI stream");
  if (auto Err = mergeIdRecords(IDTable, IndexMap.TPIMap, IndexMap.IPIMap,
                                ExpectedIpi->typeArray()))
    fatal(Err, "codeview::mergeIdRecords failed");

  return IndexMap;
}

static bool remapTypeIndex(TypeIndex &TI, ArrayRef<TypeIndex> TypeIndexMap) {
  if (TI.isSimple())
    return true;
  if (TI.toArrayIndex() >= TypeIndexMap.size())
    return false;
  TI = TypeIndexMap[TI.toArrayIndex()];
  return true;
}

static void remapTypesInSymbolRecord(ObjectFile *File,
                                     MutableArrayRef<uint8_t> Contents,
                                     const CVIndexMap &IndexMap,
                                     ArrayRef<TiReference> TypeRefs) {
  for (const TiReference &Ref : TypeRefs) {
    unsigned ByteSize = Ref.Count * sizeof(TypeIndex);
    if (Contents.size() < Ref.Offset + ByteSize)
      fatal("symbol record too short");

    // This can be an item index or a type index. Choose the appropriate map.
    ArrayRef<TypeIndex> TypeOrItemMap = IndexMap.TPIMap;
    if (Ref.Kind == TiRefKind::IndexRef && IndexMap.IsTypeServerMap)
      TypeOrItemMap = IndexMap.IPIMap;

    MutableArrayRef<TypeIndex> TIs(
        reinterpret_cast<TypeIndex *>(Contents.data() + Ref.Offset), Ref.Count);
    for (TypeIndex &TI : TIs) {
      if (!remapTypeIndex(TI, TypeOrItemMap)) {
        TI = TypeIndex(SimpleTypeKind::NotTranslated);
        log("ignoring symbol record in " + File->getName() +
            " with bad type index 0x" + utohexstr(TI.getIndex()));
        continue;
      }
    }
  }
}

/// MSVC translates S_PROC_ID_END to S_END.
uint16_t canonicalizeSymbolKind(SymbolKind Kind) {
  if (Kind == SymbolKind::S_PROC_ID_END)
    return SymbolKind::S_END;
  return Kind;
}

/// Copy the symbol record. In a PDB, symbol records must be 4 byte aligned.
/// The object file may not be aligned.
static MutableArrayRef<uint8_t> copySymbolForPdb(const CVSymbol &Sym,
                                                 BumpPtrAllocator &Alloc) {
  size_t Size = alignTo(Sym.length(), alignOf(CodeViewContainer::Pdb));
  assert(Size >= 4 && "record too short");
  assert(Size <= MaxRecordLength && "record too long");
  void *Mem = Alloc.Allocate(Size, 4);

  // Copy the symbol record and zero out any padding bytes.
  MutableArrayRef<uint8_t> NewData(reinterpret_cast<uint8_t *>(Mem), Size);
  memcpy(NewData.data(), Sym.data().data(), Sym.length());
  memset(NewData.data() + Sym.length(), 0, Size - Sym.length());

  // Update the record prefix length. It should point to the beginning of the
  // next record. MSVC does some canonicalization of the record kind, so we do
  // that as well.
  auto *Prefix = reinterpret_cast<RecordPrefix *>(Mem);
  Prefix->RecordKind = canonicalizeSymbolKind(Sym.kind());
  Prefix->RecordLen = Size - 2;
  return NewData;
}

/// Return true if this symbol opens a scope. This implies that the symbol has
/// "parent" and "end" fields, which contain the offset of the S_END or
/// S_INLINESITE_END record.
static bool symbolOpensScope(SymbolKind Kind) {
  switch (Kind) {
  case SymbolKind::S_GPROC32:
  case SymbolKind::S_LPROC32:
  case SymbolKind::S_LPROC32_ID:
  case SymbolKind::S_GPROC32_ID:
  case SymbolKind::S_BLOCK32:
  case SymbolKind::S_SEPCODE:
  case SymbolKind::S_THUNK32:
  case SymbolKind::S_INLINESITE:
  case SymbolKind::S_INLINESITE2:
    return true;
  default:
    break;
  }
  return false;
}

static bool symbolEndsScope(SymbolKind Kind) {
  switch (Kind) {
  case SymbolKind::S_END:
  case SymbolKind::S_PROC_ID_END:
  case SymbolKind::S_INLINESITE_END:
    return true;
  default:
    break;
  }
  return false;
}

struct ScopeRecord {
  ulittle32_t PtrParent;
  ulittle32_t PtrEnd;
};

struct SymbolScope {
  ScopeRecord *OpeningRecord;
  uint32_t ScopeOffset;
};

static void scopeStackOpen(SmallVectorImpl<SymbolScope> &Stack,
                           uint32_t CurOffset, CVSymbol &Sym) {
  assert(symbolOpensScope(Sym.kind()));
  SymbolScope S;
  S.ScopeOffset = CurOffset;
  S.OpeningRecord = const_cast<ScopeRecord *>(
      reinterpret_cast<const ScopeRecord *>(Sym.content().data()));
  S.OpeningRecord->PtrParent = Stack.empty() ? 0 : Stack.back().ScopeOffset;
  Stack.push_back(S);
}

static void scopeStackClose(SmallVectorImpl<SymbolScope> &Stack,
                            uint32_t CurOffset, ObjectFile *File) {
  if (Stack.empty()) {
    warn("symbol scopes are not balanced in " + File->getName());
    return;
  }
  SymbolScope S = Stack.pop_back_val();
  S.OpeningRecord->PtrEnd = CurOffset;
}

static void mergeSymbolRecords(BumpPtrAllocator &Alloc, ObjectFile *File,
                               const CVIndexMap &IndexMap,
                               BinaryStreamRef SymData) {
  // FIXME: Improve error recovery by warning and skipping records when
  // possible.
  CVSymbolArray Syms;
  BinaryStreamReader Reader(SymData);
  ExitOnErr(Reader.readArray(Syms, Reader.getLength()));
  SmallVector<SymbolScope, 4> Scopes;
  for (const CVSymbol &Sym : Syms) {
    // Discover type index references in the record. Skip it if we don't know
    // where they are.
    SmallVector<TiReference, 32> TypeRefs;
    if (!discoverTypeIndices(Sym, TypeRefs)) {
      log("ignoring unknown symbol record with kind 0x" + utohexstr(Sym.kind()));
      continue;
    }

    // Copy the symbol record so we can mutate it.
    MutableArrayRef<uint8_t> NewData = copySymbolForPdb(Sym, Alloc);

    // Re-map all the type index references.
    MutableArrayRef<uint8_t> Contents =
        NewData.drop_front(sizeof(RecordPrefix));
    remapTypesInSymbolRecord(File, Contents, IndexMap, TypeRefs);

    // Fill in "Parent" and "End" fields by maintaining a stack of scopes.
    CVSymbol NewSym(Sym.kind(), NewData);
    if (symbolOpensScope(Sym.kind()))
      scopeStackOpen(Scopes, File->ModuleDBI->getNextSymbolOffset(), NewSym);
    else if (symbolEndsScope(Sym.kind()))
      scopeStackClose(Scopes, File->ModuleDBI->getNextSymbolOffset(), File);

    // Add the symbol to the module.
    File->ModuleDBI->addSymbol(NewSym);
  }
}

// Allocate memory for a .debug$S section and relocate it.
static ArrayRef<uint8_t> relocateDebugChunk(BumpPtrAllocator &Alloc,
                                            SectionChunk *DebugChunk) {
  uint8_t *Buffer = Alloc.Allocate<uint8_t>(DebugChunk->getSize());
  assert(DebugChunk->OutputSectionOff == 0 &&
         "debug sections should not be in output sections");
  DebugChunk->writeTo(Buffer);
  return consumeDebugMagic(makeArrayRef(Buffer, DebugChunk->getSize()),
                           ".debug$S");
}

void PDBLinker::addObjectFile(ObjectFile *File) {
  // Add a module descriptor for every object file. We need to put an absolute
  // path to the object into the PDB. If this is a plain object, we make its
  // path absolute. If it's an object in an archive, we make the archive path
  // absolute.
  bool InArchive = !File->ParentName.empty();
  SmallString<128> Path = InArchive ? File->ParentName : File->getName();
  sys::fs::make_absolute(Path);
  sys::path::native(Path, sys::path::Style::windows);
  StringRef Name = InArchive ? File->getName() : StringRef(Path);

  File->ModuleDBI = &ExitOnErr(Builder.getDbiBuilder().addModuleInfo(Name));
  File->ModuleDBI->setObjFileName(Path);

  // Before we can process symbol substreams from .debug$S, we need to process
  // type information, file checksums, and the string table.  Add type info to
  // the PDB first, so that we can get the map from object file type and item
  // indices to PDB type and item indices.
  CVIndexMap ObjectIndexMap;
  const CVIndexMap &IndexMap = mergeDebugT(File, ObjectIndexMap);

  // Now do all live .debug$S sections.
  for (SectionChunk *DebugChunk : File->getDebugChunks()) {
    if (!DebugChunk->isLive() || DebugChunk->getSectionName() != ".debug$S")
      continue;

    ArrayRef<uint8_t> RelocatedDebugContents =
        relocateDebugChunk(Alloc, DebugChunk);
    if (RelocatedDebugContents.empty())
      continue;

    DebugSubsectionArray Subsections;
    BinaryStreamReader Reader(RelocatedDebugContents, support::little);
    ExitOnErr(Reader.readArray(Subsections, RelocatedDebugContents.size()));

    DebugStringTableSubsectionRef CVStrTab;
    DebugChecksumsSubsectionRef Checksums;
    for (const DebugSubsectionRecord &SS : Subsections) {
      switch (SS.kind()) {
      case DebugSubsectionKind::StringTable:
        ExitOnErr(CVStrTab.initialize(SS.getRecordData()));
        break;
      case DebugSubsectionKind::FileChecksums:
        ExitOnErr(Checksums.initialize(SS.getRecordData()));
        break;
      case DebugSubsectionKind::Lines:
        // We can add the relocated line table directly to the PDB without
        // modification because the file checksum offsets will stay the same.
        File->ModuleDBI->addDebugSubsection(SS);
        break;
      case DebugSubsectionKind::Symbols:
        mergeSymbolRecords(Alloc, File, IndexMap, SS.getRecordData());
        break;
      default:
        // FIXME: Process the rest of the subsections.
        break;
      }
    }

    if (Checksums.valid()) {
      // Make a new file checksum table that refers to offsets in the PDB-wide
      // string table. Generally the string table subsection appears after the
      // checksum table, so we have to do this after looping over all the
      // subsections.
      if (!CVStrTab.valid())
        fatal(".debug$S sections must have both a string table subsection "
              "and a checksum subsection table or neither");
      auto NewChecksums = make_unique<DebugChecksumsSubsection>(PDBStrTab);
      for (FileChecksumEntry &FC : Checksums) {
        StringRef FileName = ExitOnErr(CVStrTab.getString(FC.FileNameOffset));
        ExitOnErr(Builder.getDbiBuilder().addModuleSourceFile(*File->ModuleDBI,
                                                              FileName));
        NewChecksums->addChecksum(FileName, FC.Kind, FC.Checksum);
      }
      File->ModuleDBI->addDebugSubsection(std::move(NewChecksums));
    }
  }
}

// Add all object files to the PDB. Merge .debug$T sections into IpiData and
// TpiData.
void PDBLinker::addObjectsToPDB() {
  for (ObjectFile *File : Symtab->ObjectFiles)
    addObjectFile(File);

  Builder.getStringTableBuilder().setStrings(PDBStrTab);

  // Construct TPI stream contents.
  addTypeInfo(Builder.getTpiBuilder(), TypeTable);

  // Construct IPI stream contents.
  addTypeInfo(Builder.getIpiBuilder(), IDTable);

  // Add public and symbol records stream.

  // For now we don't actually write any thing useful to the publics stream, but
  // the act of "getting" it also creates it lazily so that we write an empty
  // stream.
  (void)Builder.getPublicsBuilder();
}

static void addLinkerModuleSymbols(StringRef Path,
                                   pdb::DbiModuleDescriptorBuilder &Mod,
                                   BumpPtrAllocator &Allocator) {
  codeview::SymbolSerializer Serializer(Allocator, CodeViewContainer::Pdb);
  codeview::ObjNameSym ONS(SymbolRecordKind::ObjNameSym);
  codeview::Compile3Sym CS(SymbolRecordKind::Compile3Sym);
  codeview::EnvBlockSym EBS(SymbolRecordKind::EnvBlockSym);

  ONS.Name = "* Linker *";
  ONS.Signature = 0;

  CS.Machine = Config->is64() ? CPUType::X64 : CPUType::Intel80386;
  CS.Flags = CompileSym3Flags::None;
  CS.VersionBackendBuild = 0;
  CS.VersionBackendMajor = 0;
  CS.VersionBackendMinor = 0;
  CS.VersionBackendQFE = 0;
  CS.VersionFrontendBuild = 0;
  CS.VersionFrontendMajor = 0;
  CS.VersionFrontendMinor = 0;
  CS.VersionFrontendQFE = 0;
  CS.Version = "LLVM Linker";
  CS.setLanguage(SourceLanguage::Link);

  ArrayRef<StringRef> Args = makeArrayRef(Config->Argv).drop_front();
  std::string ArgStr = llvm::join(Args, " ");
  EBS.Fields.push_back("cwd");
  SmallString<64> cwd;
  sys::fs::current_path(cwd);
  EBS.Fields.push_back(cwd);
  EBS.Fields.push_back("exe");
  EBS.Fields.push_back(Config->Argv[0]);
  EBS.Fields.push_back("pdb");
  EBS.Fields.push_back(Path);
  EBS.Fields.push_back("cmd");
  EBS.Fields.push_back(ArgStr);
  Mod.addSymbol(codeview::SymbolSerializer::writeOneSymbol(
      ONS, Allocator, CodeViewContainer::Pdb));
  Mod.addSymbol(codeview::SymbolSerializer::writeOneSymbol(
      CS, Allocator, CodeViewContainer::Pdb));
  Mod.addSymbol(codeview::SymbolSerializer::writeOneSymbol(
      EBS, Allocator, CodeViewContainer::Pdb));
}

// Creates a PDB file.
void coff::createPDB(SymbolTable *Symtab, ArrayRef<uint8_t> SectionTable,
                     const llvm::codeview::DebugInfo *DI) {
  PDBLinker PDB(Symtab);
  PDB.initialize(DI);
  PDB.addObjectsToPDB();
  PDB.addSections(SectionTable);
  PDB.commit();
}

void PDBLinker::initialize(const llvm::codeview::DebugInfo *DI) {
  ExitOnErr(Builder.initialize(4096)); // 4096 is blocksize

  // Create streams in MSF for predefined streams, namely
  // PDB, TPI, DBI and IPI.
  for (int I = 0; I < (int)pdb::kSpecialStreamCount; ++I)
    ExitOnErr(Builder.getMsfBuilder().addStream(0));

  // Add an Info stream.
  auto &InfoBuilder = Builder.getInfoBuilder();
  InfoBuilder.setAge(DI ? DI->PDB70.Age : 0);

  GUID uuid{};
  if (DI)
    memcpy(&uuid, &DI->PDB70.Signature, sizeof(uuid));
  InfoBuilder.setGuid(uuid);
  InfoBuilder.setSignature(time(nullptr));
  InfoBuilder.setVersion(pdb::PdbRaw_ImplVer::PdbImplVC70);

  // Add an empty DBI stream.
  pdb::DbiStreamBuilder &DbiBuilder = Builder.getDbiBuilder();
  DbiBuilder.setVersionHeader(pdb::PdbDbiV70);
  ExitOnErr(DbiBuilder.addDbgStream(pdb::DbgHeaderType::NewFPO, {}));
}

void PDBLinker::addSections(ArrayRef<uint8_t> SectionTable) {
  // Add Section Contributions.
  pdb::DbiStreamBuilder &DbiBuilder = Builder.getDbiBuilder();
  addSectionContribs(Symtab, DbiBuilder);

  // Add Section Map stream.
  ArrayRef<object::coff_section> Sections = {
      (const object::coff_section *)SectionTable.data(),
      SectionTable.size() / sizeof(object::coff_section)};
  SectionMap = pdb::DbiStreamBuilder::createSectionMap(Sections);
  DbiBuilder.setSectionMap(SectionMap);

  // It's not entirely clear what this is, but the * Linker * module uses it.
  NativePath = Config->PDBPath;
  sys::fs::make_absolute(NativePath);
  sys::path::native(NativePath, sys::path::Style::windows);
  uint32_t PdbFilePathNI = DbiBuilder.addECName(NativePath);
  auto &LinkerModule = ExitOnErr(DbiBuilder.addModuleInfo("* Linker *"));
  LinkerModule.setPdbFilePathNI(PdbFilePathNI);
  addLinkerModuleSymbols(NativePath, LinkerModule, Alloc);

  // Add COFF section header stream.
  ExitOnErr(
      DbiBuilder.addDbgStream(pdb::DbgHeaderType::SectionHdr, SectionTable));
}

void PDBLinker::commit() {
  // Write to a file.
  ExitOnErr(Builder.commit(Config->PDBPath));
}
