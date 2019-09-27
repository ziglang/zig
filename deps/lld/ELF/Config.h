//===- Config.h -------------------------------------------------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef LLD_ELF_CONFIG_H
#define LLD_ELF_CONFIG_H

#include "lld/Common/ErrorHandler.h"
#include "llvm/ADT/MapVector.h"
#include "llvm/ADT/StringRef.h"
#include "llvm/ADT/StringSet.h"
#include "llvm/BinaryFormat/ELF.h"
#include "llvm/Support/CachePruning.h"
#include "llvm/Support/CodeGen.h"
#include "llvm/Support/Endian.h"
#include <atomic>
#include <vector>

namespace lld {
namespace elf {

class InputFile;
class InputSectionBase;

enum ELFKind {
  ELFNoneKind,
  ELF32LEKind,
  ELF32BEKind,
  ELF64LEKind,
  ELF64BEKind
};

// For --build-id.
enum class BuildIdKind { None, Fast, Md5, Sha1, Hexstring, Uuid };

// For --discard-{all,locals,none}.
enum class DiscardPolicy { Default, All, Locals, None };

// For --icf={none,safe,all}.
enum class ICFLevel { None, Safe, All };

// For --strip-{all,debug}.
enum class StripPolicy { None, All, Debug };

// For --unresolved-symbols.
enum class UnresolvedPolicy { ReportError, Warn, Ignore };

// For --orphan-handling.
enum class OrphanHandlingPolicy { Place, Warn, Error };

// For --sort-section and linkerscript sorting rules.
enum class SortSectionPolicy { Default, None, Alignment, Name, Priority };

// For --target2
enum class Target2Policy { Abs, Rel, GotRel };

// For tracking ARM Float Argument PCS
enum class ARMVFPArgKind { Default, Base, VFP, ToolChain };

struct SymbolVersion {
  llvm::StringRef name;
  bool isExternCpp;
  bool hasWildcard;
};

// This struct contains symbols version definition that
// can be found in version script if it is used for link.
struct VersionDefinition {
  llvm::StringRef name;
  uint16_t id = 0;
  std::vector<SymbolVersion> globals;
};

// This struct contains the global configuration for the linker.
// Most fields are direct mapping from the command line options
// and such fields have the same name as the corresponding options.
// Most fields are initialized by the driver.
struct Configuration {
  uint8_t osabi = 0;
  uint32_t andFeatures = 0;
  llvm::CachePruningPolicy thinLTOCachePolicy;
  llvm::StringMap<uint64_t> sectionStartMap;
  llvm::StringRef chroot;
  llvm::StringRef dynamicLinker;
  llvm::StringRef dwoDir;
  llvm::StringRef entry;
  llvm::StringRef emulation;
  llvm::StringRef fini;
  llvm::StringRef init;
  llvm::StringRef ltoAAPipeline;
  llvm::StringRef ltoCSProfileFile;
  llvm::StringRef ltoNewPmPasses;
  llvm::StringRef ltoObjPath;
  llvm::StringRef ltoSampleProfile;
  llvm::StringRef mapFile;
  llvm::StringRef outputFile;
  llvm::StringRef optRemarksFilename;
  llvm::StringRef optRemarksPasses;
  llvm::StringRef optRemarksFormat;
  llvm::StringRef progName;
  llvm::StringRef printSymbolOrder;
  llvm::StringRef soName;
  llvm::StringRef sysroot;
  llvm::StringRef thinLTOCacheDir;
  llvm::StringRef thinLTOIndexOnlyArg;
  std::pair<llvm::StringRef, llvm::StringRef> thinLTOObjectSuffixReplace;
  std::pair<llvm::StringRef, llvm::StringRef> thinLTOPrefixReplace;
  std::string rpath;
  std::vector<VersionDefinition> versionDefinitions;
  std::vector<llvm::StringRef> auxiliaryList;
  std::vector<llvm::StringRef> filterList;
  std::vector<llvm::StringRef> searchPaths;
  std::vector<llvm::StringRef> symbolOrderingFile;
  std::vector<llvm::StringRef> undefined;
  std::vector<SymbolVersion> dynamicList;
  std::vector<SymbolVersion> versionScriptGlobals;
  std::vector<SymbolVersion> versionScriptLocals;
  std::vector<uint8_t> buildIdVector;
  llvm::MapVector<std::pair<const InputSectionBase *, const InputSectionBase *>,
                  uint64_t>
      callGraphProfile;
  bool allowMultipleDefinition;
  bool allowShlibUndefined;
  bool androidPackDynRelocs;
  bool armHasBlx = false;
  bool armHasMovtMovw = false;
  bool armJ1J2BranchEncoding = false;
  bool asNeeded = false;
  bool bsymbolic;
  bool bsymbolicFunctions;
  bool callGraphProfileSort;
  bool checkSections;
  bool compressDebugSections;
  bool cref;
  bool defineCommon;
  bool demangle = true;
  bool dependentLibraries;
  bool disableVerify;
  bool ehFrameHdr;
  bool emitLLVM;
  bool emitRelocs;
  bool enableNewDtags;
  bool executeOnly;
  bool exportDynamic;
  bool fixCortexA53Errata843419;
  bool forceBTI;
  bool formatBinary = false;
  bool requireCET;
  bool gcSections;
  bool gdbIndex;
  bool gnuHash = false;
  bool gnuUnique;
  bool hasDynamicList = false;
  bool hasDynSymTab;
  bool ignoreDataAddressEquality;
  bool ignoreFunctionAddressEquality;
  bool ltoCSProfileGenerate;
  bool ltoDebugPassManager;
  bool ltoNewPassManager;
  bool mergeArmExidx;
  bool mipsN32Abi = false;
  bool nmagic;
  bool noinhibitExec;
  bool nostdlib;
  bool oFormatBinary;
  bool omagic;
  bool optRemarksWithHotness;
  bool pacPlt;
  bool picThunk;
  bool pie;
  bool printGcSections;
  bool printIcfSections;
  bool relocatable;
  bool relrPackDynRelocs;
  bool saveTemps;
  bool singleRoRx;
  bool shared;
  bool isStatic = false;
  bool sysvHash = false;
  bool target1Rel;
  bool trace;
  bool thinLTOEmitImportsFiles;
  bool thinLTOIndexOnly;
  bool tocOptimize;
  bool undefinedVersion;
  bool useAndroidRelrTags = false;
  bool warnBackrefs;
  bool warnCommon;
  bool warnIfuncTextrel;
  bool warnMissingEntry;
  bool warnSymbolOrdering;
  bool writeAddends;
  bool zCombreloc;
  bool zCopyreloc;
  bool zExecstack;
  bool zGlobal;
  bool zHazardplt;
  bool zIfuncNoplt;
  bool zInitfirst;
  bool zInterpose;
  bool zKeepTextSectionPrefix;
  bool zNodefaultlib;
  bool zNodelete;
  bool zNodlopen;
  bool zNow;
  bool zOrigin;
  bool zRelro;
  bool zRodynamic;
  bool zText;
  bool zRetpolineplt;
  bool zWxneeded;
  DiscardPolicy discard;
  ICFLevel icf;
  OrphanHandlingPolicy orphanHandling;
  SortSectionPolicy sortSection;
  StripPolicy strip;
  UnresolvedPolicy unresolvedSymbols;
  Target2Policy target2;
  ARMVFPArgKind armVFPArgs = ARMVFPArgKind::Default;
  BuildIdKind buildId = BuildIdKind::None;
  ELFKind ekind = ELFNoneKind;
  uint16_t defaultSymbolVersion = llvm::ELF::VER_NDX_GLOBAL;
  uint16_t emachine = llvm::ELF::EM_NONE;
  llvm::Optional<uint64_t> imageBase;
  uint64_t commonPageSize;
  uint64_t maxPageSize;
  uint64_t mipsGotSize;
  uint64_t zStackSize;
  unsigned ltoPartitions;
  unsigned ltoo;
  unsigned optimize;
  unsigned thinLTOJobs;
  int32_t splitStackAdjustSize;

  // The following config options do not directly correspond to any
  // particualr command line options.

  // True if we need to pass through relocations in input files to the
  // output file. Usually false because we consume relocations.
  bool copyRelocs;

  // True if the target is ELF64. False if ELF32.
  bool is64;

  // True if the target is little-endian. False if big-endian.
  bool isLE;

  // endianness::little if isLE is true. endianness::big otherwise.
  llvm::support::endianness endianness;

  // True if the target is the little-endian MIPS64.
  //
  // The reason why we have this variable only for the MIPS is because
  // we use this often.  Some ELF headers for MIPS64EL are in a
  // mixed-endian (which is horrible and I'd say that's a serious spec
  // bug), and we need to know whether we are reading MIPS ELF files or
  // not in various places.
  //
  // (Note that MIPS64EL is not a typo for MIPS64LE. This is the official
  // name whatever that means. A fun hypothesis is that "EL" is short for
  // little-endian written in the little-endian order, but I don't know
  // if that's true.)
  bool isMips64EL;

  // True if we need to set the DF_STATIC_TLS flag to an output file,
  // which works as a hint to the dynamic loader that the file contains
  // code compiled with the static TLS model. The thread-local variable
  // compiled with the static TLS model is faster but less flexible, and
  // it may not be loaded using dlopen().
  //
  // We set this flag to true when we see a relocation for the static TLS
  // model. Once this becomes true, it will never become false.
  //
  // Since the flag is updated by multi-threaded code, we use std::atomic.
  // (Writing to a variable is not considered thread-safe even if the
  // variable is boolean and we always set the same value from all threads.)
  std::atomic<bool> hasStaticTlsModel{false};

  // Holds set of ELF header flags for the target.
  uint32_t eflags = 0;

  // The ELF spec defines two types of relocation table entries, RELA and
  // REL. RELA is a triplet of (offset, info, addend) while REL is a
  // tuple of (offset, info). Addends for REL are implicit and read from
  // the location where the relocations are applied. So, REL is more
  // compact than RELA but requires a bit of more work to process.
  //
  // (From the linker writer's view, this distinction is not necessary.
  // If the ELF had chosen whichever and sticked with it, it would have
  // been easier to write code to process relocations, but it's too late
  // to change the spec.)
  //
  // Each ABI defines its relocation type. IsRela is true if target
  // uses RELA. As far as we know, all 64-bit ABIs are using RELA. A
  // few 32-bit ABIs are using RELA too.
  bool isRela;

  // True if we are creating position-independent code.
  bool isPic;

  // 4 for ELF32, 8 for ELF64.
  int wordsize;
};

// The only instance of Configuration struct.
extern Configuration *config;

static inline void errorOrWarn(const Twine &msg) {
  if (!config->noinhibitExec)
    error(msg);
  else
    warn(msg);
}
} // namespace elf
} // namespace lld

#endif
