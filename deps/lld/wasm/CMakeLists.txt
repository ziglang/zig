set(LLVM_TARGET_DEFINITIONS Options.td)
tablegen(LLVM Options.inc -gen-opt-parser-defs)
add_public_tablegen_target(WasmOptionsTableGen)

if(NOT LLD_BUILT_STANDALONE)
  set(tablegen_deps intrinsics_gen)
endif()

add_lld_library(lldWasm
  Driver.cpp
  InputChunks.cpp
  InputFiles.cpp
  LTO.cpp
  MarkLive.cpp
  OutputSections.cpp
  SymbolTable.cpp
  Symbols.cpp
  Writer.cpp
  WriterUtils.cpp

  LINK_COMPONENTS
  ${LLVM_TARGETS_TO_BUILD}
  BinaryFormat
  Core
  Demangle
  LTO
  MC
  Object
  Option
  Support

  LINK_LIBS
  lldCommon

  DEPENDS
  WasmOptionsTableGen
  ${tablegen_deps}
  )