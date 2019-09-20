//===- DebugTypes.cpp -----------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "DebugTypes.h"
#include "Driver.h"
#include "InputFiles.h"
#include "lld/Common/ErrorHandler.h"
#include "llvm/DebugInfo/CodeView/TypeRecord.h"
#include "llvm/DebugInfo/PDB/GenericError.h"
#include "llvm/DebugInfo/PDB/Native/InfoStream.h"
#include "llvm/DebugInfo/PDB/Native/NativeSession.h"
#include "llvm/DebugInfo/PDB/Native/PDBFile.h"
#include "llvm/Support/Path.h"

using namespace lld;
using namespace lld::coff;
using namespace llvm;
using namespace llvm::codeview;

namespace {
// The TypeServerSource class represents a PDB type server, a file referenced by
// OBJ files compiled with MSVC /Zi. A single PDB can be shared by several OBJ
// files, therefore there must be only once instance per OBJ lot. The file path
// is discovered from the dependent OBJ's debug type stream. The
// TypeServerSource object is then queued and loaded by the COFF Driver. The
// debug type stream for such PDB files will be merged first in the final PDB,
// before any dependent OBJ.
class TypeServerSource : public TpiSource {
public:
  explicit TypeServerSource(MemoryBufferRef m, llvm::pdb::NativeSession *s)
      : TpiSource(PDB, nullptr), session(s), mb(m) {}

  // Queue a PDB type server for loading in the COFF Driver
  static void enqueue(const ObjFile *dependentFile,
                      const TypeServer2Record &ts);

  // Create an instance
  static Expected<TypeServerSource *> getInstance(MemoryBufferRef m);

  // Fetch the PDB instance loaded for a corresponding dependent OBJ.
  static Expected<TypeServerSource *>
  findFromFile(const ObjFile *dependentFile);

  static std::map<std::string, std::pair<std::string, TypeServerSource *>>
      instances;

  // The interface to the PDB (if it was opened successfully)
  std::unique_ptr<llvm::pdb::NativeSession> session;

private:
  MemoryBufferRef mb;
};

// This class represents the debug type stream of an OBJ file that depends on a
// PDB type server (see TypeServerSource).
class UseTypeServerSource : public TpiSource {
public:
  UseTypeServerSource(const ObjFile *f, const TypeServer2Record *ts)
      : TpiSource(UsingPDB, f), typeServerDependency(*ts) {}

  // Information about the PDB type server dependency, that needs to be loaded
  // in before merging this OBJ.
  TypeServer2Record typeServerDependency;
};

// This class represents the debug type stream of a Microsoft precompiled
// headers OBJ (PCH OBJ). This OBJ kind needs to be merged first in the output
// PDB, before any other OBJs that depend on this. Note that only MSVC generate
// such files, clang does not.
class PrecompSource : public TpiSource {
public:
  PrecompSource(const ObjFile *f) : TpiSource(PCH, f) {}
};

// This class represents the debug type stream of an OBJ file that depends on a
// Microsoft precompiled headers OBJ (see PrecompSource).
class UsePrecompSource : public TpiSource {
public:
  UsePrecompSource(const ObjFile *f, const PrecompRecord *precomp)
      : TpiSource(UsingPCH, f), precompDependency(*precomp) {}

  // Information about the Precomp OBJ dependency, that needs to be loaded in
  // before merging this OBJ.
  PrecompRecord precompDependency;
};
} // namespace

static std::vector<std::unique_ptr<TpiSource>> GC;

TpiSource::TpiSource(TpiKind k, const ObjFile *f) : kind(k), file(f) {
  GC.push_back(std::unique_ptr<TpiSource>(this));
}

TpiSource *lld::coff::makeTpiSource(const ObjFile *f) {
  return new TpiSource(TpiSource::Regular, f);
}

TpiSource *lld::coff::makeUseTypeServerSource(const ObjFile *f,
                                              const TypeServer2Record *ts) {
  TypeServerSource::enqueue(f, *ts);
  return new UseTypeServerSource(f, ts);
}

TpiSource *lld::coff::makePrecompSource(const ObjFile *f) {
  return new PrecompSource(f);
}

TpiSource *lld::coff::makeUsePrecompSource(const ObjFile *f,
                                           const PrecompRecord *precomp) {
  return new UsePrecompSource(f, precomp);
}

namespace lld {
namespace coff {
template <>
const PrecompRecord &retrieveDependencyInfo(const TpiSource *source) {
  assert(source->kind == TpiSource::UsingPCH);
  return ((const UsePrecompSource *)source)->precompDependency;
}

template <>
const TypeServer2Record &retrieveDependencyInfo(const TpiSource *source) {
  assert(source->kind == TpiSource::UsingPDB);
  return ((const UseTypeServerSource *)source)->typeServerDependency;
}
} // namespace coff
} // namespace lld

std::map<std::string, std::pair<std::string, TypeServerSource *>>
    TypeServerSource::instances;

// Make a PDB path assuming the PDB is in the same folder as the OBJ
static std::string getPdbBaseName(const ObjFile *file, StringRef tSPath) {
  StringRef localPath =
      !file->parentName.empty() ? file->parentName : file->getName();
  SmallString<128> path = sys::path::parent_path(localPath);

  // Currently, type server PDBs are only created by MSVC cl, which only runs
  // on Windows, so we can assume type server paths are Windows style.
  sys::path::append(path, sys::path::filename(tSPath, sys::path::Style::windows));
  return path.str();
}

// The casing of the PDB path stamped in the OBJ can differ from the actual path
// on disk. With this, we ensure to always use lowercase as a key for the
// PDBInputFile::Instances map, at least on Windows.
static std::string normalizePdbPath(StringRef path) {
#if defined(_WIN32)
  return path.lower();
#else // LINUX
  return path;
#endif
}

// If existing, return the actual PDB path on disk.
static Optional<std::string> findPdbPath(StringRef pdbPath,
                                         const ObjFile *dependentFile) {
  // Ensure the file exists before anything else. In some cases, if the path
  // points to a removable device, Driver::enqueuePath() would fail with an
  // error (EAGAIN, "resource unavailable try again") which we want to skip
  // silently.
  if (llvm::sys::fs::exists(pdbPath))
    return normalizePdbPath(pdbPath);
  std::string ret = getPdbBaseName(dependentFile, pdbPath);
  if (llvm::sys::fs::exists(ret))
    return normalizePdbPath(ret);
  return None;
}

// Fetch the PDB instance that was already loaded by the COFF Driver.
Expected<TypeServerSource *>
TypeServerSource::findFromFile(const ObjFile *dependentFile) {
  const TypeServer2Record &ts =
      retrieveDependencyInfo<TypeServer2Record>(dependentFile->debugTypesObj);

  Optional<std::string> p = findPdbPath(ts.Name, dependentFile);
  if (!p)
    return createFileError(ts.Name, errorCodeToError(std::error_code(
                                        ENOENT, std::generic_category())));

  auto it = TypeServerSource::instances.find(*p);
  // The PDB file exists on disk, at this point we expect it to have been
  // inserted in the map by TypeServerSource::loadPDB()
  assert(it != TypeServerSource::instances.end());

  std::pair<std::string, TypeServerSource *> &pdb = it->second;

  if (!pdb.second)
    return createFileError(
        *p, createStringError(inconvertibleErrorCode(), pdb.first.c_str()));

  pdb::PDBFile &pdbFile = (pdb.second)->session->getPDBFile();
  pdb::InfoStream &info = cantFail(pdbFile.getPDBInfoStream());

  // Just because a file with a matching name was found doesn't mean it can be
  // used. The GUID must match between the PDB header and the OBJ
  // TypeServer2 record. The 'Age' is used by MSVC incremental compilation.
  if (info.getGuid() != ts.getGuid())
    return createFileError(
        ts.Name,
        make_error<pdb::PDBError>(pdb::pdb_error_code::signature_out_of_date));

  return pdb.second;
}

// FIXME: Temporary interface until PDBLinker::maybeMergeTypeServerPDB() is
// moved here.
Expected<llvm::pdb::NativeSession *>
lld::coff::findTypeServerSource(const ObjFile *f) {
  Expected<TypeServerSource *> ts = TypeServerSource::findFromFile(f);
  if (!ts)
    return ts.takeError();
  return ts.get()->session.get();
}

// Queue a PDB type server for loading in the COFF Driver
void TypeServerSource::enqueue(const ObjFile *dependentFile,
                               const TypeServer2Record &ts) {
  // Start by finding where the PDB is located (either the record path or next
  // to the OBJ file)
  Optional<std::string> p = findPdbPath(ts.Name, dependentFile);
  if (!p)
    return;
  auto it = TypeServerSource::instances.emplace(
      *p, std::pair<std::string, TypeServerSource *>{});
  if (!it.second)
    return; // another OBJ already scheduled this PDB for load

  driver->enqueuePath(*p, false);
}

// Create an instance of TypeServerSource or an error string if the PDB couldn't
// be loaded. The error message will be displayed later, when the referring OBJ
// will be merged in. NOTE - a PDB load failure is not a link error: some
// debug info will simply be missing from the final PDB - that is the default
// accepted behavior.
void lld::coff::loadTypeServerSource(llvm::MemoryBufferRef m) {
  std::string path = normalizePdbPath(m.getBufferIdentifier());

  Expected<TypeServerSource *> ts = TypeServerSource::getInstance(m);
  if (!ts)
    TypeServerSource::instances[path] = {toString(ts.takeError()), nullptr};
  else
    TypeServerSource::instances[path] = {{}, *ts};
}

Expected<TypeServerSource *> TypeServerSource::getInstance(MemoryBufferRef m) {
  std::unique_ptr<llvm::pdb::IPDBSession> iSession;
  Error err = pdb::NativeSession::createFromPdb(
      MemoryBuffer::getMemBuffer(m, false), iSession);
  if (err)
    return std::move(err);

  std::unique_ptr<llvm::pdb::NativeSession> session(
      static_cast<pdb::NativeSession *>(iSession.release()));

  pdb::PDBFile &pdbFile = session->getPDBFile();
  Expected<pdb::InfoStream &> info = pdbFile.getPDBInfoStream();
  // All PDB Files should have an Info stream.
  if (!info)
    return info.takeError();
  return new TypeServerSource(m, session.release());
}
