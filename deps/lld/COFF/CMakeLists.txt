set(LLVM_TARGET_DEFINITIONS Options.td)
tablegen(LLVM Options.inc -gen-opt-parser-defs)
add_public_tablegen_target(COFFOptionsTableGen)

if(NOT LLD_BUILT_STANDALONE)
  set(tablegen_deps intrinsics_gen)
endif()

add_lld_library(lldCOFF
  Chunks.cpp
  DLL.cpp
  Driver.cpp
  DriverUtils.cpp
  Error.cpp
  ICF.cpp
  InputFiles.cpp
  LTO.cpp
  MapFile.cpp
  MarkLive.cpp
  PDB.cpp
  Strings.cpp
  SymbolTable.cpp
  Symbols.cpp
  Writer.cpp

  LINK_COMPONENTS
  ${LLVM_TARGETS_TO_BUILD}
  BinaryFormat
  BitReader
  Core
  DebugInfoCodeView
  DebugInfoMSF
  DebugInfoPDB
  LTO
  LibDriver
  Object
  MC
  MCDisassembler
  Target
  Option
  Support

  LINK_LIBS
  lldCore
  ${LLVM_PTHREAD_LIB}

  DEPENDS
  COFFOptionsTableGen
  ${tablegen_deps}
  )
