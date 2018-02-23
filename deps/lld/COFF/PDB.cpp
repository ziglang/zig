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
#include "Driver.h"
#include "SymbolTable.h"
#include "Symbols.h"
#include "Writer.h"
#include "lld/Common/ErrorHandler.h"
#include "llvm/DebugInfo/CodeView/CVDebugRecord.h"
#include "llvm/DebugInfo/CodeView/DebugSubsectionRecord.h"
#include "llvm/DebugInfo/CodeView/GlobalTypeTableBuilder.h"
#include "llvm/DebugInfo/CodeView/LazyRandomTypeCollection.h"
#include "llvm/DebugInfo/CodeView/MergingTypeTableBuilder.h"
#include "llvm/DebugInfo/CodeView/RecordName.h"
#include "llvm/DebugInfo/CodeView/SymbolDeserializer.h"
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
#include "llvm/Support/BinaryByteStream.h"
#include "llvm/Support/Endian.h"
#include "llvm/Support/JamCRC.h"
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
        IDTable(Alloc), GlobalTypeTable(Alloc), GlobalIDTable(Alloc) {}

  /// Emit the basic PDB structure: initial streams, headers, etc.
  void initialize(const llvm::codeview::DebugInfo &BuildId);

  /// Link CodeView from each object file in the symbol table into the PDB.
  void addObjectsToPDB();

  /// Link CodeView from a single object file into the PDB.
  void addObjFile(ObjFile *File);

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
  Expected<const CVIndexMap&> mergeDebugT(ObjFile *File,
                                          CVIndexMap &ObjectIndexMap);

  Expected<const CVIndexMap&> maybeMergeTypeServerPDB(ObjFile *File,
                                                      TypeServer2Record &TS);

  /// Add the section map and section contributions to the PDB.
  void addSections(ArrayRef<OutputSection *> OutputSections,
                   ArrayRef<uint8_t> SectionTable);

  void addSectionContrib(pdb::DbiModuleDescriptorBuilder &LinkerModule,
                         OutputSection *OS, Chunk *C);

  /// Write the PDB to disk.
  void commit();

private:
  BumpPtrAllocator Alloc;

  SymbolTable *Symtab;

  pdb::PDBFileBuilder Builder;

  /// Type records that will go into the PDB TPI stream.
  MergingTypeTableBuilder TypeTable;

  /// Item records that will go into the PDB IPI stream.
  MergingTypeTableBuilder IDTable;

  /// Type records that will go into the PDB TPI stream (for /DEBUG:GHASH)
  GlobalTypeTableBuilder GlobalTypeTable;

  /// Item records that will go into the PDB IPI stream (for /DEBUG:GHASH)
  GlobalTypeTableBuilder GlobalIDTable;

  /// PDBs use a single global string table for filenames in the file checksum
  /// table.
  DebugStringTableSubsection PDBStrTab;

  llvm::SmallString<128> NativePath;

  std::vector<pdb::SecMapEntry> SectionMap;

  /// Type index mappings of type server PDBs that we've loaded so far.
  std::map<GUID, CVIndexMap> TypeServerIndexMappings;

  /// List of TypeServer PDBs which cannot be loaded.
  /// Cached to prevent repeated load attempts.
  std::set<GUID> MissingTypeServerPDBs;
};
}

static SectionChunk *findByName(ArrayRef<SectionChunk *> Sections,
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

static ArrayRef<uint8_t> getDebugSection(ObjFile *File, StringRef SecName) {
  if (SectionChunk *Sec = findByName(File->getDebugChunks(), SecName))
    return consumeDebugMagic(Sec->getContents(), SecName);
  return {};
}

// A COFF .debug$H section is currently a clang extension.  This function checks
// if a .debug$H section is in a format that we expect / understand, so that we
// can ignore any sections which are coincidentally also named .debug$H but do
// not contain a format we recognize.
static bool canUseDebugH(ArrayRef<uint8_t> DebugH) {
  if (DebugH.size() < sizeof(object::debug_h_header))
    return false;
  auto *Header =
      reinterpret_cast<const object::debug_h_header *>(DebugH.data());
  DebugH = DebugH.drop_front(sizeof(object::debug_h_header));
  return Header->Magic == COFF::DEBUG_HASHES_SECTION_MAGIC &&
         Header->Version == 0 &&
         Header->HashAlgorithm == uint16_t(GlobalTypeHashAlg::SHA1) &&
         (DebugH.size() % 20 == 0);
}

static Optional<ArrayRef<uint8_t>> getDebugH(ObjFile *File) {
  SectionChunk *Sec = findByName(File->getDebugChunks(), ".debug$H");
  if (!Sec)
    return llvm::None;
  ArrayRef<uint8_t> Contents = Sec->getContents();
  if (!canUseDebugH(Contents))
    return None;
  return Contents;
}

static ArrayRef<GloballyHashedType>
getHashesFromDebugH(ArrayRef<uint8_t> DebugH) {
  assert(canUseDebugH(DebugH));

  DebugH = DebugH.drop_front(sizeof(object::debug_h_header));
  uint32_t Count = DebugH.size() / sizeof(GloballyHashedType);
  return {reinterpret_cast<const GloballyHashedType *>(DebugH.data()), Count};
}

static void addTypeInfo(pdb::TpiStreamBuilder &TpiBuilder,
                        TypeCollection &TypeTable) {
  // Start the TPI or IPI stream header.
  TpiBuilder.setVersionHeader(pdb::PdbTpiV80);

  // Flatten the in memory type table and hash each type.
  TypeTable.ForEachRecord([&](TypeIndex TI, const CVType &Type) {
    auto Hash = pdb::hashTypeRecord(Type);
    if (auto E = Hash.takeError())
      fatal("type hashing error");
    TpiBuilder.addTypeRecord(Type.RecordData, *Hash);
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
    fatal("error reading type server record: " + toString(std::move(EC)));
  return std::move(TS);
}

Expected<const CVIndexMap&> PDBLinker::mergeDebugT(ObjFile *File,
                                                   CVIndexMap &ObjectIndexMap) {
  ArrayRef<uint8_t> Data = getDebugSection(File, ".debug$T");
  if (Data.empty())
    return ObjectIndexMap;

  BinaryByteStream Stream(Data, support::little);
  CVTypeArray Types;
  BinaryStreamReader Reader(Stream);
  if (auto EC = Reader.readArray(Types, Reader.getLength()))
    fatal("Reader::readArray failed: " + toString(std::move(EC)));

  // Look through type servers. If we've already seen this type server, don't
  // merge any type information.
  if (Optional<TypeServer2Record> TS = maybeReadTypeServerRecord(Types))
    return maybeMergeTypeServerPDB(File, *TS);

  // This is a /Z7 object. Fill in the temporary, caller-provided
  // ObjectIndexMap.
  if (Config->DebugGHashes) {
    ArrayRef<GloballyHashedType> Hashes;
    std::vector<GloballyHashedType> OwnedHashes;
    if (Optional<ArrayRef<uint8_t>> DebugH = getDebugH(File))
      Hashes = getHashesFromDebugH(*DebugH);
    else {
      OwnedHashes = GloballyHashedType::hashTypes(Types);
      Hashes = OwnedHashes;
    }

    if (auto Err = mergeTypeAndIdRecords(GlobalIDTable, GlobalTypeTable,
                                         ObjectIndexMap.TPIMap, Types, Hashes))
      fatal("codeview::mergeTypeAndIdRecords failed: " +
            toString(std::move(Err)));
  } else {
    if (auto Err = mergeTypeAndIdRecords(IDTable, TypeTable,
                                         ObjectIndexMap.TPIMap, Types))
      fatal("codeview::mergeTypeAndIdRecords failed: " +
            toString(std::move(Err)));
  }
  return ObjectIndexMap;
}

static Expected<std::unique_ptr<pdb::NativeSession>>
tryToLoadPDB(const GUID &GuidFromObj, StringRef TSPath) {
  ErrorOr<std::unique_ptr<MemoryBuffer>> MBOrErr = MemoryBuffer::getFile(
      TSPath, /*FileSize=*/-1, /*RequiresNullTerminator=*/false);
  if (!MBOrErr)
    return errorCodeToError(MBOrErr.getError());

  std::unique_ptr<pdb::IPDBSession> ThisSession;
  if (auto EC = pdb::NativeSession::createFromPdb(
          MemoryBuffer::getMemBuffer(Driver->takeBuffer(std::move(*MBOrErr)),
                                     /*RequiresNullTerminator=*/false),
          ThisSession))
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

Expected<const CVIndexMap&> PDBLinker::maybeMergeTypeServerPDB(ObjFile *File,
                                                               TypeServer2Record &TS) {
  const GUID& TSId = TS.getGuid();
  StringRef TSPath = TS.getName();

  // First, check if the PDB has previously failed to load.
  if (MissingTypeServerPDBs.count(TSId))
    return make_error<pdb::GenericError>(
      pdb::generic_error_code::type_server_not_found, TSPath);

  // Second, check if we already loaded a PDB with this GUID. Return the type
  // index mapping if we have it.
  auto Insertion = TypeServerIndexMappings.insert({TSId, CVIndexMap()});
  CVIndexMap &IndexMap = Insertion.first->second;
  if (!Insertion.second)
    return IndexMap;

  // Mark this map as a type server map.
  IndexMap.IsTypeServerMap = true;

  // Check for a PDB at:
  // 1. The given file path
  // 2. Next to the object file or archive file
  auto ExpectedSession = tryToLoadPDB(TSId, TSPath);
  if (!ExpectedSession) {
    consumeError(ExpectedSession.takeError());
    StringRef LocalPath =
        !File->ParentName.empty() ? File->ParentName : File->getName();
    SmallString<128> Path = sys::path::parent_path(LocalPath);
    sys::path::append(
        Path, sys::path::filename(TSPath, sys::path::Style::windows));
    ExpectedSession = tryToLoadPDB(TSId, Path);
  }
  if (auto E = ExpectedSession.takeError()) {
    TypeServerIndexMappings.erase(TSId);
    MissingTypeServerPDBs.emplace(TSId);
    return std::move(E);
  }

  auto ExpectedTpi = (*ExpectedSession)->getPDBFile().getPDBTpiStream();
  if (auto E = ExpectedTpi.takeError())
    fatal("Type server does not have TPI stream: " + toString(std::move(E)));
  auto ExpectedIpi = (*ExpectedSession)->getPDBFile().getPDBIpiStream();
  if (auto E = ExpectedIpi.takeError())
    fatal("Type server does not have TPI stream: " + toString(std::move(E)));

  if (Config->DebugGHashes) {
    // PDBs do not actually store global hashes, so when merging a type server
    // PDB we have to synthesize global hashes.  To do this, we first synthesize
    // global hashes for the TPI stream, since it is independent, then we
    // synthesize hashes for the IPI stream, using the hashes for the TPI stream
    // as inputs.
    auto TpiHashes = GloballyHashedType::hashTypes(ExpectedTpi->typeArray());
    auto IpiHashes =
        GloballyHashedType::hashIds(ExpectedIpi->typeArray(), TpiHashes);

    // Merge TPI first, because the IPI stream will reference type indices.
    if (auto Err = mergeTypeRecords(GlobalTypeTable, IndexMap.TPIMap,
                                    ExpectedTpi->typeArray(), TpiHashes))
      fatal("codeview::mergeTypeRecords failed: " + toString(std::move(Err)));

    // Merge IPI.
    if (auto Err =
            mergeIdRecords(GlobalIDTable, IndexMap.TPIMap, IndexMap.IPIMap,
                           ExpectedIpi->typeArray(), IpiHashes))
      fatal("codeview::mergeIdRecords failed: " + toString(std::move(Err)));
  } else {
    // Merge TPI first, because the IPI stream will reference type indices.
    if (auto Err = mergeTypeRecords(TypeTable, IndexMap.TPIMap,
                                    ExpectedTpi->typeArray()))
      fatal("codeview::mergeTypeRecords failed: " + toString(std::move(Err)));

    // Merge IPI.
    if (auto Err = mergeIdRecords(IDTable, IndexMap.TPIMap, IndexMap.IPIMap,
                                  ExpectedIpi->typeArray()))
      fatal("codeview::mergeIdRecords failed: " + toString(std::move(Err)));
  }

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

static void remapTypesInSymbolRecord(ObjFile *File, SymbolKind SymKind,
                                     MutableArrayRef<uint8_t> Contents,
                                     const CVIndexMap &IndexMap,
                                     ArrayRef<TiReference> TypeRefs) {
  for (const TiReference &Ref : TypeRefs) {
    unsigned ByteSize = Ref.Count * sizeof(TypeIndex);
    if (Contents.size() < Ref.Offset + ByteSize)
      fatal("symbol record too short");

    // This can be an item index or a type index. Choose the appropriate map.
    ArrayRef<TypeIndex> TypeOrItemMap = IndexMap.TPIMap;
    bool IsItemIndex = Ref.Kind == TiRefKind::IndexRef;
    if (IsItemIndex && IndexMap.IsTypeServerMap)
      TypeOrItemMap = IndexMap.IPIMap;

    MutableArrayRef<TypeIndex> TIs(
        reinterpret_cast<TypeIndex *>(Contents.data() + Ref.Offset), Ref.Count);
    for (TypeIndex &TI : TIs) {
      if (!remapTypeIndex(TI, TypeOrItemMap)) {
        log("ignoring symbol record of kind 0x" + utohexstr(SymKind) + " in " +
            File->getName() + " with bad " + (IsItemIndex ? "item" : "type") +
            " index 0x" + utohexstr(TI.getIndex()));
        TI = TypeIndex(SimpleTypeKind::NotTranslated);
        continue;
      }
    }
  }
}

static SymbolKind symbolKind(ArrayRef<uint8_t> RecordData) {
  const RecordPrefix *Prefix =
      reinterpret_cast<const RecordPrefix *>(RecordData.data());
  return static_cast<SymbolKind>(uint16_t(Prefix->RecordKind));
}

/// MSVC translates S_PROC_ID_END to S_END, and S_[LG]PROC32_ID to S_[LG]PROC32
static void translateIdSymbols(MutableArrayRef<uint8_t> &RecordData,
                               TypeCollection &IDTable) {
  RecordPrefix *Prefix = reinterpret_cast<RecordPrefix *>(RecordData.data());

  SymbolKind Kind = symbolKind(RecordData);

  if (Kind == SymbolKind::S_PROC_ID_END) {
    Prefix->RecordKind = SymbolKind::S_END;
    return;
  }

  // In an object file, GPROC32_ID has an embedded reference which refers to the
  // single object file type index namespace.  This has already been translated
  // to the PDB file's ID stream index space, but we need to convert this to a
  // symbol that refers to the type stream index space.  So we remap again from
  // ID index space to type index space.
  if (Kind == SymbolKind::S_GPROC32_ID || Kind == SymbolKind::S_LPROC32_ID) {
    SmallVector<TiReference, 1> Refs;
    auto Content = RecordData.drop_front(sizeof(RecordPrefix));
    CVSymbol Sym(Kind, RecordData);
    discoverTypeIndicesInSymbol(Sym, Refs);
    assert(Refs.size() == 1);
    assert(Refs.front().Count == 1);

    TypeIndex *TI =
        reinterpret_cast<TypeIndex *>(Content.data() + Refs[0].Offset);
    // `TI` is the index of a FuncIdRecord or MemberFuncIdRecord which lives in
    // the IPI stream, whose `FunctionType` member refers to the TPI stream.
    // Note that LF_FUNC_ID and LF_MEMFUNC_ID have the same record layout, and
    // in both cases we just need the second type index.
    if (!TI->isSimple() && !TI->isNoneType()) {
      CVType FuncIdData = IDTable.getType(*TI);
      SmallVector<TypeIndex, 2> Indices;
      discoverTypeIndices(FuncIdData, Indices);
      assert(Indices.size() == 2);
      *TI = Indices[1];
    }

    Kind = (Kind == SymbolKind::S_GPROC32_ID) ? SymbolKind::S_GPROC32
                                              : SymbolKind::S_LPROC32;
    Prefix->RecordKind = uint16_t(Kind);
  }
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
  // next record.
  auto *Prefix = reinterpret_cast<RecordPrefix *>(Mem);
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
                            uint32_t CurOffset, ObjFile *File) {
  if (Stack.empty()) {
    warn("symbol scopes are not balanced in " + File->getName());
    return;
  }
  SymbolScope S = Stack.pop_back_val();
  S.OpeningRecord->PtrEnd = CurOffset;
}

static bool symbolGoesInModuleStream(const CVSymbol &Sym) {
  switch (Sym.kind()) {
  case SymbolKind::S_GDATA32:
  case SymbolKind::S_CONSTANT:
  case SymbolKind::S_UDT:
  // We really should not be seeing S_PROCREF and S_LPROCREF in the first place
  // since they are synthesized by the linker in response to S_GPROC32 and
  // S_LPROC32, but if we do see them, don't put them in the module stream I
  // guess.
  case SymbolKind::S_PROCREF:
  case SymbolKind::S_LPROCREF:
    return false;
  // S_GDATA32 does not go in the module stream, but S_LDATA32 does.
  case SymbolKind::S_LDATA32:
  default:
    return true;
  }
}

static bool symbolGoesInGlobalsStream(const CVSymbol &Sym) {
  switch (Sym.kind()) {
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
  // FIXME: For now, we drop all S_UDT symbols (i.e. they don't go in the
  // globals stream or the modules stream).  These have special handling which
  // needs more investigation before we can get right, but by putting them all
  // into the globals stream WinDbg fails to display local variables of class
  // types saying that it cannot find the type Foo *.  So as a stopgap just to
  // keep things working, we drop them.
  case SymbolKind::S_UDT:
  default:
    return false;
  }
}

static void addGlobalSymbol(pdb::GSIStreamBuilder &Builder, ObjFile &File,
                            const CVSymbol &Sym) {
  switch (Sym.kind()) {
  case SymbolKind::S_CONSTANT:
  case SymbolKind::S_UDT:
  case SymbolKind::S_GDATA32:
  case SymbolKind::S_LDATA32:
  case SymbolKind::S_PROCREF:
  case SymbolKind::S_LPROCREF:
    Builder.addGlobalSymbol(Sym);
    break;
  case SymbolKind::S_GPROC32:
  case SymbolKind::S_LPROC32: {
    SymbolRecordKind K = SymbolRecordKind::ProcRefSym;
    if (Sym.kind() == SymbolKind::S_LPROC32)
      K = SymbolRecordKind::LocalProcRef;
    ProcRefSym PS(K);
    PS.Module = static_cast<uint16_t>(File.ModuleDBI->getModuleIndex());
    // For some reason, MSVC seems to add one to this value.
    ++PS.Module;
    PS.Name = getSymbolName(Sym);
    PS.SumName = 0;
    PS.SymOffset = File.ModuleDBI->getNextSymbolOffset();
    Builder.addGlobalSymbol(PS);
    break;
  }
  default:
    llvm_unreachable("Invalid symbol kind!");
  }
}

static void mergeSymbolRecords(BumpPtrAllocator &Alloc, ObjFile *File,
                               pdb::GSIStreamBuilder &GsiBuilder,
                               const CVIndexMap &IndexMap,
                               TypeCollection &IDTable,
                               BinaryStreamRef SymData) {
  // FIXME: Improve error recovery by warning and skipping records when
  // possible.
  CVSymbolArray Syms;
  BinaryStreamReader Reader(SymData);
  ExitOnErr(Reader.readArray(Syms, Reader.getLength()));
  SmallVector<SymbolScope, 4> Scopes;
  for (CVSymbol Sym : Syms) {
    // Discover type index references in the record. Skip it if we don't know
    // where they are.
    SmallVector<TiReference, 32> TypeRefs;
    if (!discoverTypeIndicesInSymbol(Sym, TypeRefs)) {
      log("ignoring unknown symbol record with kind 0x" + utohexstr(Sym.kind()));
      continue;
    }

    // Copy the symbol record so we can mutate it.
    MutableArrayRef<uint8_t> NewData = copySymbolForPdb(Sym, Alloc);

    // Re-map all the type index references.
    MutableArrayRef<uint8_t> Contents =
        NewData.drop_front(sizeof(RecordPrefix));
    remapTypesInSymbolRecord(File, Sym.kind(), Contents, IndexMap, TypeRefs);

    // An object file may have S_xxx_ID symbols, but these get converted to
    // "real" symbols in a PDB.
    translateIdSymbols(NewData, IDTable);

    SymbolKind NewKind = symbolKind(NewData);

    // Fill in "Parent" and "End" fields by maintaining a stack of scopes.
    CVSymbol NewSym(NewKind, NewData);
    if (symbolOpensScope(NewKind))
      scopeStackOpen(Scopes, File->ModuleDBI->getNextSymbolOffset(), NewSym);
    else if (symbolEndsScope(NewKind))
      scopeStackClose(Scopes, File->ModuleDBI->getNextSymbolOffset(), File);

    // Add the symbol to the globals stream if necessary.  Do this before adding
    // the symbol to the module since we may need to get the next symbol offset,
    // and writing to the module's symbol stream will update that offset.
    if (symbolGoesInGlobalsStream(NewSym))
      addGlobalSymbol(GsiBuilder, *File, NewSym);

    // Add the symbol to the module.
    if (symbolGoesInModuleStream(NewSym))
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

void PDBLinker::addObjFile(ObjFile *File) {
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
  auto IndexMapResult = mergeDebugT(File, ObjectIndexMap);

  // If the .debug$T sections fail to merge, assume there is no debug info.
  if (!IndexMapResult) {
    warn("Type server PDB for " + Name + " is invalid, ignoring debug info. " +
         toString(IndexMapResult.takeError()));
    return;
  }

  const CVIndexMap &IndexMap = *IndexMapResult;

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
        if (Config->DebugGHashes) {
          mergeSymbolRecords(Alloc, File, Builder.getGsiBuilder(), IndexMap,
                             GlobalIDTable, SS.getRecordData());
        } else {
          mergeSymbolRecords(Alloc, File, Builder.getGsiBuilder(), IndexMap,
                             IDTable, SS.getRecordData());
        }
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

static PublicSym32 createPublic(Defined *Def) {
  PublicSym32 Pub(SymbolKind::S_PUB32);
  Pub.Name = Def->getName();
  if (auto *D = dyn_cast<DefinedCOFF>(Def)) {
    if (D->getCOFFSymbol().isFunctionDefinition())
      Pub.Flags = PublicSymFlags::Function;
  } else if (isa<DefinedImportThunk>(Def)) {
    Pub.Flags = PublicSymFlags::Function;
  }

  OutputSection *OS = Def->getChunk()->getOutputSection();
  assert(OS && "all publics should be in final image");
  Pub.Offset = Def->getRVA() - OS->getRVA();
  Pub.Segment = OS->SectionIndex;
  return Pub;
}

// Add all object files to the PDB. Merge .debug$T sections into IpiData and
// TpiData.
void PDBLinker::addObjectsToPDB() {
  for (ObjFile *File : ObjFile::Instances)
    addObjFile(File);

  Builder.getStringTableBuilder().setStrings(PDBStrTab);

  // Construct TPI and IPI stream contents.
  if (Config->DebugGHashes) {
    addTypeInfo(Builder.getTpiBuilder(), GlobalTypeTable);
    addTypeInfo(Builder.getIpiBuilder(), GlobalIDTable);
  } else {
    addTypeInfo(Builder.getTpiBuilder(), TypeTable);
    addTypeInfo(Builder.getIpiBuilder(), IDTable);
  }

  // Compute the public and global symbols.
  auto &GsiBuilder = Builder.getGsiBuilder();
  std::vector<PublicSym32> Publics;
  Symtab->forEachSymbol([&Publics](Symbol *S) {
    // Only emit defined, live symbols that have a chunk.
    auto *Def = dyn_cast<Defined>(S);
    if (Def && Def->isLive() && Def->getChunk())
      Publics.push_back(createPublic(Def));
  });

  if (!Publics.empty()) {
    // Sort the public symbols and add them to the stream.
    std::sort(Publics.begin(), Publics.end(),
              [](const PublicSym32 &L, const PublicSym32 &R) {
                return L.Name < R.Name;
              });
    for (const PublicSym32 &Pub : Publics)
      GsiBuilder.addPublicSymbol(Pub);
  }
}

static void addCommonLinkerModuleSymbols(StringRef Path,
                                         pdb::DbiModuleDescriptorBuilder &Mod,
                                         BumpPtrAllocator &Allocator) {
  ObjNameSym ONS(SymbolRecordKind::ObjNameSym);
  Compile3Sym CS(SymbolRecordKind::Compile3Sym);
  EnvBlockSym EBS(SymbolRecordKind::EnvBlockSym);

  ONS.Name = "* Linker *";
  ONS.Signature = 0;

  CS.Machine = Config->is64() ? CPUType::X64 : CPUType::Intel80386;
  // Interestingly, if we set the string to 0.0.0.0, then when trying to view
  // local variables WinDbg emits an error that private symbols are not present.
  // By setting this to a valid MSVC linker version string, local variables are
  // displayed properly.   As such, even though it is not representative of
  // LLVM's version information, we need this for compatibility.
  CS.Flags = CompileSym3Flags::None;
  CS.VersionBackendBuild = 25019;
  CS.VersionBackendMajor = 14;
  CS.VersionBackendMinor = 10;
  CS.VersionBackendQFE = 0;

  // MSVC also sets the frontend to 0.0.0.0 since this is specifically for the
  // linker module (which is by definition a backend), so we don't need to do
  // anything here.  Also, it seems we can use "LLVM Linker" for the linker name
  // without any problems.  Only the backend version has to be hardcoded to a
  // magic number.
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
  SmallString<64> exe = Config->Argv[0];
  llvm::sys::fs::make_absolute(exe);
  EBS.Fields.push_back(exe);
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

static void addLinkerModuleSectionSymbol(pdb::DbiModuleDescriptorBuilder &Mod,
                                         OutputSection &OS,
                                         BumpPtrAllocator &Allocator) {
  SectionSym Sym(SymbolRecordKind::SectionSym);
  Sym.Alignment = 12; // 2^12 = 4KB
  Sym.Characteristics = OS.getCharacteristics();
  Sym.Length = OS.getVirtualSize();
  Sym.Name = OS.getName();
  Sym.Rva = OS.getRVA();
  Sym.SectionNumber = OS.SectionIndex;
  Mod.addSymbol(codeview::SymbolSerializer::writeOneSymbol(
      Sym, Allocator, CodeViewContainer::Pdb));
}

// Creates a PDB file.
void coff::createPDB(SymbolTable *Symtab,
                     ArrayRef<OutputSection *> OutputSections,
                     ArrayRef<uint8_t> SectionTable,
                     const llvm::codeview::DebugInfo &BuildId) {
  PDBLinker PDB(Symtab);
  PDB.initialize(BuildId);
  PDB.addObjectsToPDB();
  PDB.addSections(OutputSections, SectionTable);
  PDB.commit();
}

void PDBLinker::initialize(const llvm::codeview::DebugInfo &BuildId) {
  ExitOnErr(Builder.initialize(4096)); // 4096 is blocksize

  // Create streams in MSF for predefined streams, namely
  // PDB, TPI, DBI and IPI.
  for (int I = 0; I < (int)pdb::kSpecialStreamCount; ++I)
    ExitOnErr(Builder.getMsfBuilder().addStream(0));

  // Add an Info stream.
  auto &InfoBuilder = Builder.getInfoBuilder();
  InfoBuilder.setAge(BuildId.PDB70.Age);

  GUID uuid;
  memcpy(&uuid, &BuildId.PDB70.Signature, sizeof(uuid));
  InfoBuilder.setGuid(uuid);
  InfoBuilder.setSignature(time(nullptr));
  InfoBuilder.setVersion(pdb::PdbRaw_ImplVer::PdbImplVC70);

  // Add an empty DBI stream.
  pdb::DbiStreamBuilder &DbiBuilder = Builder.getDbiBuilder();
  DbiBuilder.setAge(BuildId.PDB70.Age);
  DbiBuilder.setVersionHeader(pdb::PdbDbiV70);
  ExitOnErr(DbiBuilder.addDbgStream(pdb::DbgHeaderType::NewFPO, {}));
}

void PDBLinker::addSectionContrib(pdb::DbiModuleDescriptorBuilder &LinkerModule,
                                  OutputSection *OS, Chunk *C) {
  pdb::SectionContrib SC;
  memset(&SC, 0, sizeof(SC));
  SC.ISect = OS->SectionIndex;
  SC.Off = C->getRVA() - OS->getRVA();
  SC.Size = C->getSize();
  if (auto *SecChunk = dyn_cast<SectionChunk>(C)) {
    SC.Characteristics = SecChunk->Header->Characteristics;
    SC.Imod = SecChunk->File->ModuleDBI->getModuleIndex();
    ArrayRef<uint8_t> Contents = SecChunk->getContents();
    JamCRC CRC(0);
    ArrayRef<char> CharContents = makeArrayRef(
        reinterpret_cast<const char *>(Contents.data()), Contents.size());
    CRC.update(CharContents);
    SC.DataCrc = CRC.getCRC();
  } else {
    SC.Characteristics = OS->getCharacteristics();
    // FIXME: When we start creating DBI for import libraries, use those here.
    SC.Imod = LinkerModule.getModuleIndex();
  }
  SC.RelocCrc = 0; // FIXME
  Builder.getDbiBuilder().addSectionContrib(SC);
}

void PDBLinker::addSections(ArrayRef<OutputSection *> OutputSections,
                            ArrayRef<uint8_t> SectionTable) {
  // It's not entirely clear what this is, but the * Linker * module uses it.
  pdb::DbiStreamBuilder &DbiBuilder = Builder.getDbiBuilder();
  NativePath = Config->PDBPath;
  sys::fs::make_absolute(NativePath);
  sys::path::native(NativePath, sys::path::Style::windows);
  uint32_t PdbFilePathNI = DbiBuilder.addECName(NativePath);
  auto &LinkerModule = ExitOnErr(DbiBuilder.addModuleInfo("* Linker *"));
  LinkerModule.setPdbFilePathNI(PdbFilePathNI);
  addCommonLinkerModuleSymbols(NativePath, LinkerModule, Alloc);

  // Add section contributions. They must be ordered by ascending RVA.
  for (OutputSection *OS : OutputSections) {
    addLinkerModuleSectionSymbol(LinkerModule, *OS, Alloc);
    for (Chunk *C : OS->getChunks())
      addSectionContrib(LinkerModule, OS, C);
  }

  // Add Section Map stream.
  ArrayRef<object::coff_section> Sections = {
      (const object::coff_section *)SectionTable.data(),
      SectionTable.size() / sizeof(object::coff_section)};
  SectionMap = pdb::DbiStreamBuilder::createSectionMap(Sections);
  DbiBuilder.setSectionMap(SectionMap);

  // Add COFF section header stream.
  ExitOnErr(
      DbiBuilder.addDbgStream(pdb::DbgHeaderType::SectionHdr, SectionTable));
}

void PDBLinker::commit() {
  // Write to a file.
  ExitOnErr(Builder.commit(Config->PDBPath));
}
