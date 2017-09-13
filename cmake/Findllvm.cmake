# Copyright (c) 2014 Andrew Kelley
# This file is MIT licensed.
# See http://opensource.org/licenses/MIT

# LLVM_FOUND
# LLVM_INCLUDE_DIRS
# LLVM_LIBRARIES
# LLVM_LIBDIRS

if(MSVC)
  find_package(LLVM REQUIRED CONFIG)

  # TODO: this currently doesn't work, it currently defines UNICODE but zig
  #       uses MBCS
  #add_definitions(${LLVM_DEFINITIONS})

  link_directories(${LLVM_LIBRARY_DIRS})
  llvm_map_components_to_libnames(LLVM_LIBRARIES
      LTO
      Symbolize
      XCoreDisassembler
      XCoreCodeGen
      XCoreAsmPrinter
      SystemZDisassembler
      SystemZCodeGen
      SystemZAsmParser
      SystemZAsmPrinter
      SparcDisassembler
      SparcCodeGen
      SparcAsmParser
      SparcAsmPrinter
      PowerPCDisassembler
      PowerPCCodeGen
      PowerPCAsmParser
      PowerPCAsmPrinter
      NVPTXCodeGen
      NVPTXAsmPrinter
      MSP430CodeGen
      MSP430AsmPrinter
      MipsDisassembler
      MipsCodeGen
      MipsAsmParser
      MipsAsmPrinter
      LanaiDisassembler
      LanaiCodeGen
      LanaiAsmParser
      LanaiAsmPrinter
      HexagonDisassembler
      HexagonCodeGen
      HexagonAsmParser
      BPFDisassembler
      BPFCodeGen
      BPFAsmPrinter
      ARMDisassembler
      ARMCodeGen
      ARMAsmParser
      ARMAsmPrinter
      AMDGPUDisassembler
      AMDGPUCodeGen
      AMDGPUAsmParser
      AMDGPUAsmPrinter
      AArch64Disassembler
      AArch64CodeGen
      AArch64AsmParser
      AArch64AsmPrinter
      LibDriver
      X86Disassembler
      X86AsmParser
      X86CodeGen
      X86AsmPrinter
      Core
  )

else()
  find_program(LLVM_CONFIG_EXE
      NAMES llvm-config-5.0 llvm-config
      PATHS
          "/mingw64/bin"
          "/c/msys64/mingw64/bin"
          "c:/msys64/mingw64/bin"
          "C:/Libraries/llvm-5.0.0/bin")

  execute_process(
      COMMAND ${LLVM_CONFIG_EXE} --libs
      OUTPUT_VARIABLE LLVM_LIBRARIES
      OUTPUT_STRIP_TRAILING_WHITESPACE)

  execute_process(
      COMMAND ${LLVM_CONFIG_EXE} --system-libs
      OUTPUT_VARIABLE LLVM_SYSTEM_LIBS
      OUTPUT_STRIP_TRAILING_WHITESPACE)

  execute_process(
      COMMAND ${LLVM_CONFIG_EXE} --libdir
      OUTPUT_VARIABLE LLVM_LIBDIRS
      OUTPUT_STRIP_TRAILING_WHITESPACE)

  execute_process(
      COMMAND ${LLVM_CONFIG_EXE} --includedir
      OUTPUT_VARIABLE LLVM_INCLUDE_DIRS
      OUTPUT_STRIP_TRAILING_WHITESPACE)

  find_library(LLVM_LIBRARY NAMES LLVM)

  set(LLVM_LIBRARIES ${LLVM_LIBRARIES} ${LLVM_SYSTEM_LIBS})

  if(LLVM_LIBRARY)
    set(LLVM_LIBRARIES ${LLVM_LIBRARY})
  endif()
endif()


include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(LLVM DEFAULT_MSG LLVM_LIBRARIES LLVM_INCLUDE_DIRS)

mark_as_advanced(LLVM_INCLUDE_DIRS LLVM_LIBRARIES LLVM_LIBDIRS)
