set(LLVM_TARGET_DEFINITIONS Options.td)
tablegen(LLVM Options.inc -gen-opt-parser-defs)
add_public_tablegen_target(WasmOptionsTableGen)

add_lld_library(lldWasm
  Driver.cpp
  InputFiles.cpp
  InputSegment.cpp
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
  Object
  Option
  Support

  LINK_LIBS
  lldCommon
  )
