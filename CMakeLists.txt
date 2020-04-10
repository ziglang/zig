cmake_minimum_required(VERSION 2.8.5)

if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE "Debug" CACHE STRING
        "Choose the type of build, options are: None Debug Release RelWithDebInfo MinSizeRel." FORCE)
endif()

if(NOT CMAKE_INSTALL_PREFIX)
    set(CMAKE_INSTALL_PREFIX "${CMAKE_BINARY_DIR}" CACHE STRING
      "Directory to install zig to" FORCE)
endif()

set(CMAKE_USER_MAKE_RULES_OVERRIDE
   ${CMAKE_CURRENT_SOURCE_DIR}/cmake/c_flag_overrides.cmake)
set(CMAKE_USER_MAKE_RULES_OVERRIDE_CXX
   ${CMAKE_CURRENT_SOURCE_DIR}/cmake/cxx_flag_overrides.cmake)

project(zig C CXX)
set(CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake ${CMAKE_MODULE_PATH})

set(ZIG_VERSION_MAJOR 0)
set(ZIG_VERSION_MINOR 5)
set(ZIG_VERSION_PATCH 0)
set(ZIG_VERSION "${ZIG_VERSION_MAJOR}.${ZIG_VERSION_MINOR}.${ZIG_VERSION_PATCH}")

find_program(GIT_EXE NAMES git)
if(GIT_EXE)
    execute_process(
        COMMAND ${GIT_EXE} -C ${CMAKE_SOURCE_DIR} name-rev HEAD --tags --name-only --no-undefined --always
        RESULT_VARIABLE EXIT_STATUS
        OUTPUT_VARIABLE ZIG_GIT_REV
        OUTPUT_STRIP_TRAILING_WHITESPACE
        ERROR_QUIET)
    if(EXIT_STATUS EQUAL "0")
        if(ZIG_GIT_REV MATCHES "\\^0$")
            if(NOT("${ZIG_GIT_REV}" STREQUAL "${ZIG_VERSION}^0"))
                message("WARNING: Tag does not match configured Zig version")
            endif()
        else()
            set(ZIG_VERSION "${ZIG_VERSION}+${ZIG_GIT_REV}")
        endif()
    endif()
endif()
message("Configuring zig version ${ZIG_VERSION}")

set(ZIG_STATIC off CACHE BOOL "Attempt to build a static zig executable (not compatible with glibc)")
set(ZIG_ENABLE_MEM_PROFILE off CACHE BOOL "Activate memory usage instrumentation")

string(REGEX REPLACE "\\\\" "\\\\\\\\" ZIG_LIBC_LIB_DIR_ESCAPED "${ZIG_LIBC_LIB_DIR}")
string(REGEX REPLACE "\\\\" "\\\\\\\\" ZIG_LIBC_STATIC_LIB_DIR_ESCAPED "${ZIG_LIBC_STATIC_LIB_DIR}")
string(REGEX REPLACE "\\\\" "\\\\\\\\" ZIG_LIBC_INCLUDE_DIR_ESCAPED "${ZIG_LIBC_INCLUDE_DIR}")

option(ZIG_TEST_COVERAGE "Build Zig with test coverage instrumentation" OFF)

# Zig no longer has embedded LLD. This option is kept for package maintainers
# so that they don't have to update their scripts in case we ever re-introduce
# LLD to the tree. This option does nothing.
option(ZIG_FORCE_EXTERNAL_LLD "does nothing" OFF)

set(ZIG_TARGET_TRIPLE "native" CACHE STRING "arch-os-abi to output binaries for")
set(ZIG_TARGET_MCPU "baseline" CACHE STRING "-mcpu parameter to output binaries for")
set(ZIG_EXECUTABLE "" CACHE STRING "(when cross compiling) path to already-built zig binary")

# Find Clang
if("${ZIG_TARGET_TRIPLE}" STREQUAL "native")
  find_package(Clang REQUIRED)
  if (CLANG_LINK_CLANG_DYLIB)
    set(CLANG_LIBRARIES clang-cpp)
  else()
    set(CLANG_LIBRARIES 
      clangFrontendTool
      clangCodeGen
      clangFrontend
      clangDriver
      clangSerialization
      clangSema
      clangStaticAnalyzerFrontend
      clangStaticAnalyzerCheckers
      clangStaticAnalyzerCore
      clangAnalysis
      clangASTMatchers
      clangAST
      clangParse
      clangSema
      clangBasic
      clangEdit
      clangLex
      clangARCMigrate
      clangRewriteFrontend
      clangRewrite
      clangCrossTU
      clangIndex
    )
  endif()
else()
  find_path(CLANG_INCLUDE_DIRS NAMES clang/Frontend/ASTUnit.h)

  macro(FIND_AND_ADD_CLANG_LIB _libname_)
      string(TOUPPER ${_libname_} _prettylibname_)
      find_library(CLANG_${_prettylibname_}_LIB NAMES ${_libname_})
      set(CLANG_LIBRARIES ${CLANG_LIBRARIES} ${CLANG_${_prettylibname_}_LIB})
  endmacro(FIND_AND_ADD_CLANG_LIB)

  FIND_AND_ADD_CLANG_LIB(clangFrontendTool)
  FIND_AND_ADD_CLANG_LIB(clangCodeGen)
  FIND_AND_ADD_CLANG_LIB(clangFrontend)
  FIND_AND_ADD_CLANG_LIB(clangDriver)
  FIND_AND_ADD_CLANG_LIB(clangSerialization)
  FIND_AND_ADD_CLANG_LIB(clangSema)
  FIND_AND_ADD_CLANG_LIB(clangStaticAnalyzerFrontend)
  FIND_AND_ADD_CLANG_LIB(clangStaticAnalyzerCheckers)
  FIND_AND_ADD_CLANG_LIB(clangStaticAnalyzerCore)
  FIND_AND_ADD_CLANG_LIB(clangAnalysis)
  FIND_AND_ADD_CLANG_LIB(clangASTMatchers)
  FIND_AND_ADD_CLANG_LIB(clangAST)
  FIND_AND_ADD_CLANG_LIB(clangParse)
  FIND_AND_ADD_CLANG_LIB(clangSema)
  FIND_AND_ADD_CLANG_LIB(clangBasic)
  FIND_AND_ADD_CLANG_LIB(clangEdit)
  FIND_AND_ADD_CLANG_LIB(clangLex)
  FIND_AND_ADD_CLANG_LIB(clangARCMigrate)
  FIND_AND_ADD_CLANG_LIB(clangRewriteFrontend)
  FIND_AND_ADD_CLANG_LIB(clangRewrite)
  FIND_AND_ADD_CLANG_LIB(clangCrossTU)
  FIND_AND_ADD_CLANG_LIB(clangIndex)
endif()

# Find LLVM
if("${ZIG_TARGET_TRIPLE}" STREQUAL "native")
  find_library(LLVM REQUIRED)

  if(NOT ${LLVM_VERSION_MAJOR} EQUAL 10)
    message(FATAL_ERROR "expected LLVM 10.x but found ${LLVM_VERSION_MAJOR}")
  endif()

  function(NEED_TARGET TARGET_NAME)
      list (FIND LLVM_TARGETS_TO_BUILD "${TARGET_NAME}" _index)
      if (${_index} EQUAL -1)
          message(FATAL_ERROR "LLVM is missing target ${TARGET_NAME}. Zig requires LLVM to be built with all default targets enabled. If you patch out this check, please make it clear to your users that this has been done. Zig users expect to be able to cross compile!")
      endif()
  endfunction(NEED_TARGET)
  NEED_TARGET("AArch64")
  NEED_TARGET("AMDGPU")
  NEED_TARGET("ARM")
  NEED_TARGET("BPF")
  NEED_TARGET("Hexagon")
  NEED_TARGET("Lanai")
  NEED_TARGET("Mips")
  NEED_TARGET("MSP430")
  NEED_TARGET("NVPTX")
  NEED_TARGET("PowerPC")
  NEED_TARGET("RISCV")
  NEED_TARGET("Sparc")
  NEED_TARGET("SystemZ")
  NEED_TARGET("WebAssembly")
  NEED_TARGET("X86")
  NEED_TARGET("XCore")

  if(LLVM_LINK_LLVM_DYLIB)
    set(LLVM_LIBRARIES LLVM)
  else()
    # This list can be re-generated with `llvm-config --libfiles` and then
    # reformatting using your favorite text editor. Note we do not execute
    # `llvm-config` under any circumstances, because it is unreliable, and
    # not available when cross-compiling.
    set(LLVM_LIBRARIES
      LLVMXRay
      LLVMWindowsManifest
      LLVMSymbolize
      LLVMDebugInfoPDB
      LLVMOrcJIT
      LLVMOrcError
      LLVMJITLink
      LLVMObjectYAML
      LLVMMCA
      LLVMLTO
      LLVMPasses
      LLVMObjCARCOpts
      LLVMLineEditor
      LLVMLibDriver
      LLVMInterpreter
      LLVMFuzzMutate
      LLVMFrontendOpenMP
      LLVMMCJIT
      LLVMExecutionEngine
      LLVMRuntimeDyld
      LLVMDWARFLinker
      LLVMDlltoolDriver
      LLVMOption
      LLVMDebugInfoGSYM
      LLVMCoverage
      LLVMCoroutines
      LLVMAVRDisassembler
      LLVMAVRCodeGen
      LLVMAVRAsmParser
      LLVMAVRDesc
      LLVMAVRInfo
      LLVMXCoreDisassembler
      LLVMXCoreCodeGen
      LLVMXCoreDesc
      LLVMXCoreInfo
      LLVMX86Disassembler
      LLVMX86AsmParser
      LLVMX86CodeGen
      LLVMX86Desc
      LLVMX86Utils
      LLVMX86Info
      LLVMWebAssemblyDisassembler
      LLVMWebAssemblyCodeGen
      LLVMWebAssemblyDesc
      LLVMWebAssemblyAsmParser
      LLVMWebAssemblyInfo
      LLVMSystemZDisassembler
      LLVMSystemZCodeGen
      LLVMSystemZAsmParser
      LLVMSystemZDesc
      LLVMSystemZInfo
      LLVMSparcDisassembler
      LLVMSparcCodeGen
      LLVMSparcAsmParser
      LLVMSparcDesc
      LLVMSparcInfo
      LLVMRISCVDisassembler
      LLVMRISCVCodeGen
      LLVMRISCVAsmParser
      LLVMRISCVDesc
      LLVMRISCVUtils
      LLVMRISCVInfo
      LLVMPowerPCDisassembler
      LLVMPowerPCCodeGen
      LLVMPowerPCAsmParser
      LLVMPowerPCDesc
      LLVMPowerPCInfo
      LLVMNVPTXCodeGen
      LLVMNVPTXDesc
      LLVMNVPTXInfo
      LLVMMSP430Disassembler
      LLVMMSP430CodeGen
      LLVMMSP430AsmParser
      LLVMMSP430Desc
      LLVMMSP430Info
      LLVMMipsDisassembler
      LLVMMipsCodeGen
      LLVMMipsAsmParser
      LLVMMipsDesc
      LLVMMipsInfo
      LLVMLanaiDisassembler
      LLVMLanaiCodeGen
      LLVMLanaiAsmParser
      LLVMLanaiDesc
      LLVMLanaiInfo
      LLVMHexagonDisassembler
      LLVMHexagonCodeGen
      LLVMHexagonAsmParser
      LLVMHexagonDesc
      LLVMHexagonInfo
      LLVMBPFDisassembler
      LLVMBPFCodeGen
      LLVMBPFAsmParser
      LLVMBPFDesc
      LLVMBPFInfo
      LLVMARMDisassembler
      LLVMARMCodeGen
      LLVMARMAsmParser
      LLVMARMDesc
      LLVMARMUtils
      LLVMARMInfo
      LLVMAMDGPUDisassembler
      LLVMAMDGPUCodeGen
      LLVMMIRParser
      LLVMipo
      LLVMInstrumentation
      LLVMVectorize
      LLVMLinker
      LLVMIRReader
      LLVMAsmParser
      LLVMAMDGPUAsmParser
      LLVMAMDGPUDesc
      LLVMAMDGPUUtils
      LLVMAMDGPUInfo
      LLVMAArch64Disassembler
      LLVMMCDisassembler
      LLVMAArch64CodeGen
      LLVMCFGuard
      LLVMGlobalISel
      LLVMSelectionDAG
      LLVMAsmPrinter
      LLVMDebugInfoDWARF
      LLVMCodeGen
      LLVMTarget
      LLVMScalarOpts
      LLVMInstCombine
      LLVMAggressiveInstCombine
      LLVMTransformUtils
      LLVMBitWriter
      LLVMAnalysis
      LLVMProfileData
      LLVMObject
      LLVMTextAPI
      LLVMBitReader
      LLVMCore
      LLVMRemarks
      LLVMBitstreamReader
      LLVMAArch64AsmParser
      LLVMMCParser
      LLVMAArch64Desc
      LLVMMC
      LLVMDebugInfoCodeView
      LLVMDebugInfoMSF
      LLVMBinaryFormat
      LLVMAArch64Utils
      LLVMAArch64Info
      LLVMSupport
      LLVMDemangle
    )
  endif()
else()
  # Here we assume that we're cross compiling with Zig, of course. No reason
  # to support more complicated setups. We also assume the experimental target
  # AVR is enabled.

  find_path(LLVM_INCLUDE_DIRS NAMES llvm/IR/IRBuilder.h)

  macro(FIND_AND_ADD_LLVM_LIB _libname_)
    string(TOUPPER ${_libname_} _prettylibname_)
    find_library(LLVM_${_prettylibname_}_LIB NAMES ${_libname_})
    set(LLVM_LIBRARIES ${LLVM_LIBRARIES} ${LLVM_${_prettylibname_}_LIB})
  endmacro(FIND_AND_ADD_LLVM_LIB)

  FIND_AND_ADD_LLVM_LIB(LLVMXRay)
  FIND_AND_ADD_LLVM_LIB(LLVMWindowsManifest)
  FIND_AND_ADD_LLVM_LIB(LLVMSymbolize)
  FIND_AND_ADD_LLVM_LIB(LLVMDebugInfoPDB)
  FIND_AND_ADD_LLVM_LIB(LLVMOrcJIT)
  FIND_AND_ADD_LLVM_LIB(LLVMOrcError)
  FIND_AND_ADD_LLVM_LIB(LLVMJITLink)
  FIND_AND_ADD_LLVM_LIB(LLVMObjectYAML)
  FIND_AND_ADD_LLVM_LIB(LLVMMCA)
  FIND_AND_ADD_LLVM_LIB(LLVMLTO)
  FIND_AND_ADD_LLVM_LIB(LLVMPasses)
  FIND_AND_ADD_LLVM_LIB(LLVMObjCARCOpts)
  FIND_AND_ADD_LLVM_LIB(LLVMLineEditor)
  FIND_AND_ADD_LLVM_LIB(LLVMLibDriver)
  FIND_AND_ADD_LLVM_LIB(LLVMInterpreter)
  FIND_AND_ADD_LLVM_LIB(LLVMFuzzMutate)
  FIND_AND_ADD_LLVM_LIB(LLVMFrontendOpenMP)
  FIND_AND_ADD_LLVM_LIB(LLVMMCJIT)
  FIND_AND_ADD_LLVM_LIB(LLVMExecutionEngine)
  FIND_AND_ADD_LLVM_LIB(LLVMRuntimeDyld)
  FIND_AND_ADD_LLVM_LIB(LLVMDWARFLinker)
  FIND_AND_ADD_LLVM_LIB(LLVMDlltoolDriver)
  FIND_AND_ADD_LLVM_LIB(LLVMOption)
  FIND_AND_ADD_LLVM_LIB(LLVMDebugInfoGSYM)
  FIND_AND_ADD_LLVM_LIB(LLVMCoverage)
  FIND_AND_ADD_LLVM_LIB(LLVMCoroutines)
  FIND_AND_ADD_LLVM_LIB(LLVMAVRDisassembler)
  FIND_AND_ADD_LLVM_LIB(LLVMAVRCodeGen)
  FIND_AND_ADD_LLVM_LIB(LLVMAVRAsmParser)
  FIND_AND_ADD_LLVM_LIB(LLVMAVRDesc)
  FIND_AND_ADD_LLVM_LIB(LLVMAVRInfo)
  FIND_AND_ADD_LLVM_LIB(LLVMXCoreDisassembler)
  FIND_AND_ADD_LLVM_LIB(LLVMXCoreCodeGen)
  FIND_AND_ADD_LLVM_LIB(LLVMXCoreDesc)
  FIND_AND_ADD_LLVM_LIB(LLVMXCoreInfo)
  FIND_AND_ADD_LLVM_LIB(LLVMX86Disassembler)
  FIND_AND_ADD_LLVM_LIB(LLVMX86AsmParser)
  FIND_AND_ADD_LLVM_LIB(LLVMX86CodeGen)
  FIND_AND_ADD_LLVM_LIB(LLVMX86Desc)
  FIND_AND_ADD_LLVM_LIB(LLVMX86Utils)
  FIND_AND_ADD_LLVM_LIB(LLVMX86Info)
  FIND_AND_ADD_LLVM_LIB(LLVMWebAssemblyDisassembler)
  FIND_AND_ADD_LLVM_LIB(LLVMWebAssemblyCodeGen)
  FIND_AND_ADD_LLVM_LIB(LLVMWebAssemblyDesc)
  FIND_AND_ADD_LLVM_LIB(LLVMWebAssemblyAsmParser)
  FIND_AND_ADD_LLVM_LIB(LLVMWebAssemblyInfo)
  FIND_AND_ADD_LLVM_LIB(LLVMSystemZDisassembler)
  FIND_AND_ADD_LLVM_LIB(LLVMSystemZCodeGen)
  FIND_AND_ADD_LLVM_LIB(LLVMSystemZAsmParser)
  FIND_AND_ADD_LLVM_LIB(LLVMSystemZDesc)
  FIND_AND_ADD_LLVM_LIB(LLVMSystemZInfo)
  FIND_AND_ADD_LLVM_LIB(LLVMSparcDisassembler)
  FIND_AND_ADD_LLVM_LIB(LLVMSparcCodeGen)
  FIND_AND_ADD_LLVM_LIB(LLVMSparcAsmParser)
  FIND_AND_ADD_LLVM_LIB(LLVMSparcDesc)
  FIND_AND_ADD_LLVM_LIB(LLVMSparcInfo)
  FIND_AND_ADD_LLVM_LIB(LLVMRISCVDisassembler)
  FIND_AND_ADD_LLVM_LIB(LLVMRISCVCodeGen)
  FIND_AND_ADD_LLVM_LIB(LLVMRISCVAsmParser)
  FIND_AND_ADD_LLVM_LIB(LLVMRISCVDesc)
  FIND_AND_ADD_LLVM_LIB(LLVMRISCVUtils)
  FIND_AND_ADD_LLVM_LIB(LLVMRISCVInfo)
  FIND_AND_ADD_LLVM_LIB(LLVMPowerPCDisassembler)
  FIND_AND_ADD_LLVM_LIB(LLVMPowerPCCodeGen)
  FIND_AND_ADD_LLVM_LIB(LLVMPowerPCAsmParser)
  FIND_AND_ADD_LLVM_LIB(LLVMPowerPCDesc)
  FIND_AND_ADD_LLVM_LIB(LLVMPowerPCInfo)
  FIND_AND_ADD_LLVM_LIB(LLVMNVPTXCodeGen)
  FIND_AND_ADD_LLVM_LIB(LLVMNVPTXDesc)
  FIND_AND_ADD_LLVM_LIB(LLVMNVPTXInfo)
  FIND_AND_ADD_LLVM_LIB(LLVMMSP430Disassembler)
  FIND_AND_ADD_LLVM_LIB(LLVMMSP430CodeGen)
  FIND_AND_ADD_LLVM_LIB(LLVMMSP430AsmParser)
  FIND_AND_ADD_LLVM_LIB(LLVMMSP430Desc)
  FIND_AND_ADD_LLVM_LIB(LLVMMSP430Info)
  FIND_AND_ADD_LLVM_LIB(LLVMMipsDisassembler)
  FIND_AND_ADD_LLVM_LIB(LLVMMipsCodeGen)
  FIND_AND_ADD_LLVM_LIB(LLVMMipsAsmParser)
  FIND_AND_ADD_LLVM_LIB(LLVMMipsDesc)
  FIND_AND_ADD_LLVM_LIB(LLVMMipsInfo)
  FIND_AND_ADD_LLVM_LIB(LLVMLanaiDisassembler)
  FIND_AND_ADD_LLVM_LIB(LLVMLanaiCodeGen)
  FIND_AND_ADD_LLVM_LIB(LLVMLanaiAsmParser)
  FIND_AND_ADD_LLVM_LIB(LLVMLanaiDesc)
  FIND_AND_ADD_LLVM_LIB(LLVMLanaiInfo)
  FIND_AND_ADD_LLVM_LIB(LLVMHexagonDisassembler)
  FIND_AND_ADD_LLVM_LIB(LLVMHexagonCodeGen)
  FIND_AND_ADD_LLVM_LIB(LLVMHexagonAsmParser)
  FIND_AND_ADD_LLVM_LIB(LLVMHexagonDesc)
  FIND_AND_ADD_LLVM_LIB(LLVMHexagonInfo)
  FIND_AND_ADD_LLVM_LIB(LLVMBPFDisassembler)
  FIND_AND_ADD_LLVM_LIB(LLVMBPFCodeGen)
  FIND_AND_ADD_LLVM_LIB(LLVMBPFAsmParser)
  FIND_AND_ADD_LLVM_LIB(LLVMBPFDesc)
  FIND_AND_ADD_LLVM_LIB(LLVMBPFInfo)
  FIND_AND_ADD_LLVM_LIB(LLVMARMDisassembler)
  FIND_AND_ADD_LLVM_LIB(LLVMARMCodeGen)
  FIND_AND_ADD_LLVM_LIB(LLVMARMAsmParser)
  FIND_AND_ADD_LLVM_LIB(LLVMARMDesc)
  FIND_AND_ADD_LLVM_LIB(LLVMARMUtils)
  FIND_AND_ADD_LLVM_LIB(LLVMARMInfo)
  FIND_AND_ADD_LLVM_LIB(LLVMAMDGPUDisassembler)
  FIND_AND_ADD_LLVM_LIB(LLVMAMDGPUCodeGen)
  FIND_AND_ADD_LLVM_LIB(LLVMMIRParser)
  FIND_AND_ADD_LLVM_LIB(LLVMipo)
  FIND_AND_ADD_LLVM_LIB(LLVMInstrumentation)
  FIND_AND_ADD_LLVM_LIB(LLVMVectorize)
  FIND_AND_ADD_LLVM_LIB(LLVMLinker)
  FIND_AND_ADD_LLVM_LIB(LLVMIRReader)
  FIND_AND_ADD_LLVM_LIB(LLVMAsmParser)
  FIND_AND_ADD_LLVM_LIB(LLVMAMDGPUAsmParser)
  FIND_AND_ADD_LLVM_LIB(LLVMAMDGPUDesc)
  FIND_AND_ADD_LLVM_LIB(LLVMAMDGPUUtils)
  FIND_AND_ADD_LLVM_LIB(LLVMAMDGPUInfo)
  FIND_AND_ADD_LLVM_LIB(LLVMAArch64Disassembler)
  FIND_AND_ADD_LLVM_LIB(LLVMMCDisassembler)
  FIND_AND_ADD_LLVM_LIB(LLVMAArch64CodeGen)
  FIND_AND_ADD_LLVM_LIB(LLVMCFGuard)
  FIND_AND_ADD_LLVM_LIB(LLVMGlobalISel)
  FIND_AND_ADD_LLVM_LIB(LLVMSelectionDAG)
  FIND_AND_ADD_LLVM_LIB(LLVMAsmPrinter)
  FIND_AND_ADD_LLVM_LIB(LLVMDebugInfoDWARF)
  FIND_AND_ADD_LLVM_LIB(LLVMCodeGen)
  FIND_AND_ADD_LLVM_LIB(LLVMTarget)
  FIND_AND_ADD_LLVM_LIB(LLVMScalarOpts)
  FIND_AND_ADD_LLVM_LIB(LLVMInstCombine)
  FIND_AND_ADD_LLVM_LIB(LLVMAggressiveInstCombine)
  FIND_AND_ADD_LLVM_LIB(LLVMTransformUtils)
  FIND_AND_ADD_LLVM_LIB(LLVMBitWriter)
  FIND_AND_ADD_LLVM_LIB(LLVMAnalysis)
  FIND_AND_ADD_LLVM_LIB(LLVMProfileData)
  FIND_AND_ADD_LLVM_LIB(LLVMObject)
  FIND_AND_ADD_LLVM_LIB(LLVMTextAPI)
  FIND_AND_ADD_LLVM_LIB(LLVMBitReader)
  FIND_AND_ADD_LLVM_LIB(LLVMCore)
  FIND_AND_ADD_LLVM_LIB(LLVMRemarks)
  FIND_AND_ADD_LLVM_LIB(LLVMBitstreamReader)
  FIND_AND_ADD_LLVM_LIB(LLVMAArch64AsmParser)
  FIND_AND_ADD_LLVM_LIB(LLVMMCParser)
  FIND_AND_ADD_LLVM_LIB(LLVMAArch64Desc)
  FIND_AND_ADD_LLVM_LIB(LLVMMC)
  FIND_AND_ADD_LLVM_LIB(LLVMDebugInfoCodeView)
  FIND_AND_ADD_LLVM_LIB(LLVMDebugInfoMSF)
  FIND_AND_ADD_LLVM_LIB(LLVMBinaryFormat)
  FIND_AND_ADD_LLVM_LIB(LLVMAArch64Utils)
  FIND_AND_ADD_LLVM_LIB(LLVMAArch64Info)
  FIND_AND_ADD_LLVM_LIB(LLVMSupport)
  FIND_AND_ADD_LLVM_LIB(LLVMDemangle)
endif()

find_package(lld)

set(ZIG_CPP_LIB_DIR "${CMAKE_BINARY_DIR}/zig_cpp")

# Handle multi-config builds and place each into a common lib. The VS generator
# for example will append a Debug folder by default if not explicitly specified.
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${ZIG_CPP_LIB_DIR})
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${ZIG_CPP_LIB_DIR})
foreach(CONFIG_TYPE ${CMAKE_CONFIGURATION_TYPES})
    string(TOUPPER ${CONFIG_TYPE} CONFIG_TYPE)
    set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY_${CONFIG_TYPE} ${ZIG_CPP_LIB_DIR})
    set(CMAKE_LIBRARY_OUTPUT_DIRECTORY_${CONFIG_TYPE} ${ZIG_CPP_LIB_DIR})
endforeach(CONFIG_TYPE CMAKE_CONFIGURATION_TYPES)

include_directories(${LLVM_INCLUDE_DIRS})
include_directories(${LLD_INCLUDE_DIRS})
include_directories(${CLANG_INCLUDE_DIRS})

# No patches have been applied to SoftFloat-3e
set(EMBEDDED_SOFTFLOAT_SOURCES
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/8086/f128M_isSignalingNaN.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/8086/s_commonNaNToF128M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/8086/s_commonNaNToF16UI.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/8086/s_commonNaNToF32UI.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/8086/s_commonNaNToF64UI.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/8086/s_f128MToCommonNaN.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/8086/s_f16UIToCommonNaN.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/8086/s_f32UIToCommonNaN.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/8086/s_f64UIToCommonNaN.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/8086/s_propagateNaNF128M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/8086/s_propagateNaNF16UI.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/8086/softfloat_raiseFlags.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f128M_add.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f128M_div.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f128M_eq.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f128M_eq_signaling.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f128M_le.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f128M_le_quiet.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f128M_lt.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f128M_lt_quiet.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f128M_mul.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f128M_mulAdd.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f128M_rem.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f128M_roundToInt.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f128M_sqrt.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f128M_sub.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f128M_to_f16.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f128M_to_f32.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f128M_to_f64.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f128M_to_i32.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f128M_to_i32_r_minMag.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f128M_to_i64.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f128M_to_i64_r_minMag.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f128M_to_ui32.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f128M_to_ui32_r_minMag.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f128M_to_ui64.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f128M_to_ui64_r_minMag.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f16_add.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f16_div.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f16_eq.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f16_isSignalingNaN.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f16_lt.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f16_mul.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f16_rem.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f16_roundToInt.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f16_sqrt.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f16_sub.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f16_to_f128M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f16_to_f64.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f32_to_f128M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f64_to_f128M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f64_to_f16.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/i32_to_f128M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_add256M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_addCarryM.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_addComplCarryM.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_addF128M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_addM.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_addMagsF16.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_addMagsF32.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_addMagsF64.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_approxRecip32_1.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_approxRecipSqrt32_1.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_approxRecipSqrt_1Ks.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_approxRecip_1Ks.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_compare128M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_compare96M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_countLeadingZeros16.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_countLeadingZeros32.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_countLeadingZeros64.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_countLeadingZeros8.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_eq128.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_invalidF128M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_isNaNF128M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_le128.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_lt128.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_mul128MTo256M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_mul64To128M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_mulAddF128M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_mulAddF16.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_mulAddF32.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_mulAddF64.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_negXM.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_normRoundPackMToF128M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_normRoundPackToF16.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_normRoundPackToF32.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_normRoundPackToF64.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_normSubnormalF128SigM.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_normSubnormalF16Sig.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_normSubnormalF32Sig.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_normSubnormalF64Sig.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_remStepMBy32.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_roundMToI64.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_roundMToUI64.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_roundPackMToF128M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_roundPackToF16.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_roundPackToF32.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_roundPackToF64.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_roundToI32.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_roundToI64.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_roundToUI32.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_roundToUI64.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_shiftLeftM.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_shiftNormSigF128M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_shiftRightJam256M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_shiftRightJam32.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_shiftRightJam64.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_shiftRightJamM.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_shiftRightM.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_shortShiftLeft64To96M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_shortShiftLeftM.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_shortShiftRightExtendM.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_shortShiftRightJam64.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_shortShiftRightJamM.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_shortShiftRightM.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_sub1XM.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_sub256M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_subM.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_subMagsF16.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_subMagsF32.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_subMagsF64.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_tryPropagateNaNF128M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f16_mulAdd.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f128M_mulAdd.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/softfloat_state.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/ui32_to_f128M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/ui64_to_f128M.c"
)
add_library(embedded_softfloat STATIC ${EMBEDDED_SOFTFLOAT_SOURCES})
if(MSVC)
    set_target_properties(embedded_softfloat PROPERTIES
        COMPILE_FLAGS "/w /O2"
    )
else()
    set_target_properties(embedded_softfloat PROPERTIES
        COMPILE_FLAGS "-std=c99 -O3"
    )
endif()
target_include_directories(embedded_softfloat PUBLIC
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e-prebuilt"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/8086"
)
include_directories("${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/include")
set(SOFTFLOAT_LIBRARIES embedded_softfloat)

find_package(Threads)

# CMake doesn't let us create an empty executable, so we hang on to this one separately.
set(ZIG_MAIN_SRC "${CMAKE_SOURCE_DIR}/src/main.cpp")

# This is our shim which will be replaced by libstage2 written in Zig.
set(ZIG0_SHIM_SRC "${CMAKE_SOURCE_DIR}/src/stage2.cpp")

if(ZIG_ENABLE_MEM_PROFILE)
    set(ZIG_SOURCES_MEM_PROFILE "${CMAKE_SOURCE_DIR}/src/mem_profile.cpp")
endif()

set(ZIG_SOURCES
    "${CMAKE_SOURCE_DIR}/src/analyze.cpp"
    "${CMAKE_SOURCE_DIR}/src/ast_render.cpp"
    "${CMAKE_SOURCE_DIR}/src/bigfloat.cpp"
    "${CMAKE_SOURCE_DIR}/src/bigint.cpp"
    "${CMAKE_SOURCE_DIR}/src/buffer.cpp"
    "${CMAKE_SOURCE_DIR}/src/cache_hash.cpp"
    "${CMAKE_SOURCE_DIR}/src/codegen.cpp"
    "${CMAKE_SOURCE_DIR}/src/compiler.cpp"
    "${CMAKE_SOURCE_DIR}/src/dump_analysis.cpp"
    "${CMAKE_SOURCE_DIR}/src/errmsg.cpp"
    "${CMAKE_SOURCE_DIR}/src/error.cpp"
    "${CMAKE_SOURCE_DIR}/src/glibc.cpp"
    "${CMAKE_SOURCE_DIR}/src/heap.cpp"
    "${CMAKE_SOURCE_DIR}/src/ir.cpp"
    "${CMAKE_SOURCE_DIR}/src/ir_print.cpp"
    "${CMAKE_SOURCE_DIR}/src/link.cpp"
    "${CMAKE_SOURCE_DIR}/src/mem.cpp"
    "${CMAKE_SOURCE_DIR}/src/os.cpp"
    "${CMAKE_SOURCE_DIR}/src/parser.cpp"
    "${CMAKE_SOURCE_DIR}/src/range_set.cpp"
    "${CMAKE_SOURCE_DIR}/src/target.cpp"
    "${CMAKE_SOURCE_DIR}/src/tokenizer.cpp"
    "${CMAKE_SOURCE_DIR}/src/util.cpp"
    "${ZIG_SOURCES_MEM_PROFILE}"
)
set(OPTIMIZED_C_SOURCES
    "${CMAKE_SOURCE_DIR}/src/blake2b.c"
    "${CMAKE_SOURCE_DIR}/src/parse_f128.c"
)
set(ZIG_CPP_SOURCES
    "${CMAKE_SOURCE_DIR}/src/zig_llvm.cpp"
    "${CMAKE_SOURCE_DIR}/src/zig_clang.cpp"
    "${CMAKE_SOURCE_DIR}/src/zig_clang_driver.cpp"
    "${CMAKE_SOURCE_DIR}/src/zig_clang_cc1_main.cpp"
    "${CMAKE_SOURCE_DIR}/src/zig_clang_cc1as_main.cpp"
    "${CMAKE_SOURCE_DIR}/src/windows_sdk.cpp"
)

if(MSVC)
    set(MSVC_DIA_SDK_DIR "$ENV{VSINSTALLDIR}DIA SDK")
    if(IS_DIRECTORY ${MSVC_DIA_SDK_DIR})
        set(ZIG_DIA_GUIDS_LIB "${MSVC_DIA_SDK_DIR}/lib/amd64/diaguids.lib")
        string(REGEX REPLACE "\\\\" "\\\\\\\\" ZIG_DIA_GUIDS_LIB_ESCAPED "${ZIG_DIA_GUIDS_LIB}")
    endif()
endif()

set(ZIG_LIB_DIR "lib/zig")
set(C_HEADERS_DEST "${ZIG_LIB_DIR}/include")
set(LIBC_FILES_DEST "${ZIG_LIB_DIR}/libc")
set(LIBUNWIND_FILES_DEST "${ZIG_LIB_DIR}/libunwind")
set(LIBCXX_FILES_DEST "${ZIG_LIB_DIR}/libcxx")
set(ZIG_STD_DEST "${ZIG_LIB_DIR}/std")
set(ZIG_CONFIG_H_OUT "${CMAKE_BINARY_DIR}/config.h")
configure_file (
    "${CMAKE_SOURCE_DIR}/src/config.h.in"
    "${ZIG_CONFIG_H_OUT}"
)

include_directories(
    ${CMAKE_SOURCE_DIR}
    ${CMAKE_BINARY_DIR}
    "${CMAKE_SOURCE_DIR}/src"
)

# These have to go before the -Wno- flags
if(MSVC)
  set(EXE_CFLAGS "/std:c++14")
else(MSVC)
  set(EXE_CFLAGS "-std=c++14")
endif(MSVC)

if("${CMAKE_BUILD_TYPE}" STREQUAL "Debug")
    if(MSVC)
        set(EXE_CFLAGS "${EXE_CFLAGS} /w")
    else()
        set(EXE_CFLAGS "${EXE_CFLAGS} -Werror -Wall -Werror=implicit-fallthrough")
    endif()
endif()

if(MSVC)
    set(EXE_CFLAGS "${EXE_CFLAGS}")
else()
    set(EXE_CFLAGS "${EXE_CFLAGS} -D__STDC_CONSTANT_MACROS -D__STDC_FORMAT_MACROS -D__STDC_LIMIT_MACROS -D_GNU_SOURCE -fvisibility-inlines-hidden -fno-exceptions -fno-rtti -Werror=type-limits -Wno-missing-braces")
    if(MINGW)
        set(EXE_CFLAGS "${EXE_CFLAGS} -Wno-format")
    endif()
endif()

if(MSVC)
  set(OPTIMIZED_C_FLAGS "/O2")
else(MSVC)
  set(OPTIMIZED_C_FLAGS "-std=c99 -O3")
endif(MSVC)

set(EXE_LDFLAGS " ")
if(MSVC)
    set(EXE_LDFLAGS "${EXE_LDFLAGS} /STACK:16777216")
    if(NOT "${CMAKE_BUILD_TYPE}" STREQUAL "Release" AND NOT "${CMAKE_BUILD_TYPE}" STREQUAL "MinSizeRel")
        set(EXE_LDFLAGS "${EXE_LDFLAGS} /debug:fastlink")
    endif()
elseif(MINGW)
    set(EXE_LDFLAGS "${EXE_LDFLAGS} -Wl,--stack,16777216")
endif()

if(ZIG_STATIC)
    if(APPLE)
        set(EXE_LDFLAGS "${EXE_LDFLAGS} -static-libgcc -static-libstdc++")
    elseif(MINGW)
        set(EXE_LDFLAGS "${EXE_LDFLAGS} -static-libgcc -static-libstdc++ -Wl,-Bstatic, -lwinpthread -lz3 -lz -lgomp")
    elseif(NOT MSVC)
        set(EXE_LDFLAGS "${EXE_LDFLAGS} -static")
    endif()
else()
    if(MINGW)
        set(EXE_LDFLAGS "${EXE_LDFLAGS}")
    endif()
endif()

if(ZIG_TEST_COVERAGE)
    set(EXE_CFLAGS "${EXE_CFLAGS} -fprofile-arcs -ftest-coverage")
    set(EXE_LDFLAGS "${EXE_LDFLAGS} -fprofile-arcs -ftest-coverage")
endif()

add_library(zig_cpp STATIC ${ZIG_CPP_SOURCES})
set_target_properties(zig_cpp PROPERTIES
    COMPILE_FLAGS ${EXE_CFLAGS}
)
target_link_libraries(zig_cpp LINK_PUBLIC
    ${CLANG_LIBRARIES}
    ${LLD_LIBRARIES}
    ${LLVM_LIBRARIES}
)

add_library(opt_c_util STATIC ${OPTIMIZED_C_SOURCES})
set_target_properties(opt_c_util PROPERTIES
    COMPILE_FLAGS "${OPTIMIZED_C_FLAGS}"
)

add_library(zigcompiler STATIC ${ZIG_SOURCES})
set_target_properties(zigcompiler PROPERTIES
    COMPILE_FLAGS ${EXE_CFLAGS}
    LINK_FLAGS ${EXE_LDFLAGS}
)
target_link_libraries(zigcompiler LINK_PUBLIC
    zig_cpp
    opt_c_util
    ${SOFTFLOAT_LIBRARIES}
    ${CMAKE_THREAD_LIBS_INIT}
)
if(NOT MSVC)
    target_link_libraries(zigcompiler LINK_PUBLIC ${LIBXML2})
endif()

if(ZIG_DIA_GUIDS_LIB)
    target_link_libraries(zigcompiler LINK_PUBLIC ${ZIG_DIA_GUIDS_LIB})
endif()

if(MSVC OR MINGW)
    target_link_libraries(zigcompiler LINK_PUBLIC version)
endif()

add_executable(zig0 "${ZIG_MAIN_SRC}" "${ZIG0_SHIM_SRC}")
set_target_properties(zig0 PROPERTIES
    COMPILE_FLAGS ${EXE_CFLAGS}
    LINK_FLAGS ${EXE_LDFLAGS}
)
target_link_libraries(zig0 zigcompiler)

if(MSVC)
    set(LIBSTAGE2 "${CMAKE_BINARY_DIR}/zigstage2.lib")
else()
    set(LIBSTAGE2 "${CMAKE_BINARY_DIR}/libzigstage2.a")
endif()
if("${CMAKE_BUILD_TYPE}" STREQUAL "Debug")
    set(LIBSTAGE2_RELEASE_ARG "")
else()
    set(LIBSTAGE2_RELEASE_ARG --release-fast --strip)
endif()

set(BUILD_LIBSTAGE2_ARGS "build-lib"
    "src-self-hosted/stage2.zig"
    -target "${ZIG_TARGET_TRIPLE}"
    "-mcpu=${ZIG_TARGET_MCPU}"
    --name zigstage2
    --override-lib-dir "${CMAKE_SOURCE_DIR}/lib"
    --cache on
    --output-dir "${CMAKE_BINARY_DIR}"
    ${LIBSTAGE2_RELEASE_ARG}
    --bundle-compiler-rt
    -fPIC
    -lc
)

if("${ZIG_TARGET_TRIPLE}" STREQUAL "native")
  add_custom_target(zig_build_libstage2 ALL
      COMMAND zig0 ${BUILD_LIBSTAGE2_ARGS}
      DEPENDS zig0
      BYPRODUCTS "${LIBSTAGE2}"
      WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
  )
  set(ZIG_EXECUTABLE "${zig_BINARY_DIR}/zig")
else()
  add_custom_target(zig_build_libstage2 ALL
      COMMAND "${ZIG_EXECUTABLE}" ${BUILD_LIBSTAGE2_ARGS}
      BYPRODUCTS "${LIBSTAGE2}"
      WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
  )
endif()

add_executable(zig "${ZIG_MAIN_SRC}")

set_target_properties(zig PROPERTIES
    COMPILE_FLAGS ${EXE_CFLAGS}
    LINK_FLAGS ${EXE_LDFLAGS}
)
target_link_libraries(zig zigcompiler "${LIBSTAGE2}")
if(MSVC)
  target_link_libraries(zig ntdll.lib)
elseif(MINGW)
  target_link_libraries(zig ntdll)
endif()
add_dependencies(zig zig_build_libstage2)

install(TARGETS zig DESTINATION bin)

set(ZIG_INSTALL_ARGS "build"
    --override-lib-dir "${CMAKE_SOURCE_DIR}/lib"
    "-Dlib-files-only"
    --prefix "${CMAKE_INSTALL_PREFIX}"
    "-Dconfig_h=${ZIG_CONFIG_H_OUT}"
    install
)

# CODE has no effect with Visual Studio build system generator, therefore
# when using Visual Studio build system generator we resort to running
# `zig build install` during the build phase.
if(MSVC)
    set(ZIG_SKIP_INSTALL_LIB_FILES off CACHE BOOL
        "Windows-only: Disable copying lib/ files to install prefix during the build phase")
    if(NOT ZIG_SKIP_INSTALL_LIB_FILES)
        add_custom_target(zig_install_lib_files ALL
            COMMAND zig ${ZIG_INSTALL_ARGS}
            DEPENDS zig
            WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
        )
    endif()
else()
    get_target_property(zig_BINARY_DIR zig BINARY_DIR)
    install(CODE "set(zig_EXE \"${ZIG_EXECUTABLE}\")")
    install(CODE "set(ZIG_INSTALL_ARGS \"${ZIG_INSTALL_ARGS}\")")
    install(CODE "set(CMAKE_SOURCE_DIR \"${CMAKE_SOURCE_DIR}\")")
    install(SCRIPT ${CMAKE_CURRENT_SOURCE_DIR}/cmake/install.cmake)
endif()
