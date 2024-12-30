# Copyright (c) 2014 Andrew Kelley
# This file is MIT licensed.
# See http://opensource.org/licenses/MIT

# LLVM_FOUND
# LLVM_INCLUDE_DIRS
# LLVM_LIBRARIES
# LLVM_LIBDIRS
# LLVM_LINK_MODE


if(ZIG_USE_LLVM_CONFIG)
  set(LLVM_CONFIG_ERROR_MESSAGES "")
  while(1)
    # If this variable is not unset, the same result is returned even though
    # the ignore list has changed, causing the configure process to not
    # terminate when the right LLVM version is not found.
    unset(LLVM_CONFIG_EXE CACHE)
    find_program(LLVM_CONFIG_EXE
        NAMES llvm-config-19 llvm-config-19.0 llvm-config190 llvm-config19 llvm-config NAMES_PER_DIR
        PATHS
            "/mingw64/bin"
            "/c/msys64/mingw64/bin"
            "c:/msys64/mingw64/bin"
            "C:/Libraries/llvm-19.0.0/bin")

    if ("${LLVM_CONFIG_EXE}" STREQUAL "LLVM_CONFIG_EXE-NOTFOUND")
      if (NOT LLVM_CONFIG_ERROR_MESSAGES STREQUAL "")
        list(JOIN LLVM_CONFIG_ERROR_MESSAGES "\n" LLVM_CONFIG_ERROR_MESSAGE)
        message(FATAL_ERROR ${LLVM_CONFIG_ERROR_MESSAGE})
      else()
        message(FATAL_ERROR "unable to find llvm-config")
      endif()
    endif()

    # Check that this LLVM is the right version
    execute_process(
      COMMAND ${LLVM_CONFIG_EXE} --version
      OUTPUT_VARIABLE LLVM_CONFIG_VERSION
      OUTPUT_STRIP_TRAILING_WHITESPACE)

    get_filename_component(LLVM_CONFIG_DIR "${LLVM_CONFIG_EXE}" DIRECTORY)
    if("${LLVM_CONFIG_VERSION}" VERSION_LESS 19 OR "${LLVM_CONFIG_VERSION}" VERSION_EQUAL 20 OR "${LLVM_CONFIG_VERSION}" VERSION_GREATER 20)
      # Save the error message, in case this is the last llvm-config we find
      list(APPEND LLVM_CONFIG_ERROR_MESSAGES "expected LLVM 19.x but found ${LLVM_CONFIG_VERSION} using ${LLVM_CONFIG_EXE}")

      # Ignore this directory and try the search again
      list(APPEND CMAKE_IGNORE_PATH "${LLVM_CONFIG_DIR}")
      continue()
    endif()

    # Check that this LLVM supports linking as a shared/static library, if requested
    if (ZIG_SHARED_LLVM OR ZIG_STATIC_LLVM)
      if (ZIG_SHARED_LLVM)
        set(STATIC_OR_SHARED_LINK "--link-shared")
      elseif (ZIG_STATIC_LLVM)
        set(STATIC_OR_SHARED_LINK "--link-static")
      endif()

      execute_process(
        COMMAND ${LLVM_CONFIG_EXE} --libs ${STATIC_OR_SHARED_LINK}
        OUTPUT_QUIET
        ERROR_VARIABLE LLVM_CONFIG_ERROR
        ERROR_STRIP_TRAILING_WHITESPACE)

      if (LLVM_CONFIG_ERROR)
        # Save the error message, in case this is the last llvm-config we find
        if (ZIG_SHARED_LLVM)
          list(APPEND LLVM_CONFIG_ERROR_MESSAGES "LLVM 19.x found at ${LLVM_CONFIG_EXE} does not support linking as a shared library")
        else()
          list(APPEND LLVM_CONFIG_ERROR_MESSAGES "LLVM 19.x found at ${LLVM_CONFIG_EXE} does not support linking as a static library")
        endif()

        # Ignore this directory and try the search again
        list(APPEND CMAKE_IGNORE_PATH "${LLVM_CONFIG_DIR}")
        continue()
      endif()
    endif()

    execute_process(
      COMMAND ${LLVM_CONFIG_EXE} --targets-built
        OUTPUT_VARIABLE LLVM_TARGETS_BUILT_SPACES
      OUTPUT_STRIP_TRAILING_WHITESPACE)
    string(REPLACE " " ";" LLVM_TARGETS_BUILT "${LLVM_TARGETS_BUILT_SPACES}")

    set(ZIG_LLVM_REQUIRED_TARGETS "AArch64;AMDGPU;ARM;AVR;BPF;Hexagon;Lanai;Mips;MSP430;NVPTX;PowerPC;RISCV;Sparc;SystemZ;VE;WebAssembly;X86;XCore")

    set(ZIG_LLVM_REQUIRED_TARGETS_ENABLED TRUE)
    foreach(TARGET_NAME IN LISTS ZIG_LLVM_REQUIRED_TARGETS)
      list (FIND LLVM_TARGETS_BUILT "${TARGET_NAME}" _index)
      if (${_index} EQUAL -1)
        # Save the error message, in case this is the last llvm-config we find
        list(APPEND LLVM_CONFIG_ERROR_MESSAGES "LLVM (according to ${LLVM_CONFIG_EXE}) is missing target ${TARGET_NAME}. Zig requires LLVM to be built with all default targets enabled.")

        # Ignore this directory and try the search again
        list(APPEND CMAKE_IGNORE_PATH "${LLVM_CONFIG_DIR}")
        set(ZIG_LLVM_REQUIRED_TARGETS_ENABLED FALSE)
        break()
      endif()
    endforeach()
    if (NOT ZIG_LLVM_REQUIRED_TARGETS_ENABLED)
      continue()
    endif()

    # Got it!
    break()
  endwhile()

  if(ZIG_SHARED_LLVM OR ZIG_STATIC_LLVM)
    execute_process(
        COMMAND ${LLVM_CONFIG_EXE} --libfiles ${STATIC_OR_SHARED_LINK}
        OUTPUT_VARIABLE LLVM_LIBRARIES_SPACES
        OUTPUT_STRIP_TRAILING_WHITESPACE)
    string(REPLACE " " ";" LLVM_LIBRARIES "${LLVM_LIBRARIES_SPACES}")

    execute_process(
        COMMAND ${LLVM_CONFIG_EXE} --libdir ${STATIC_OR_SHARED_LINK}
        OUTPUT_VARIABLE LLVM_LIBDIRS_SPACES
        OUTPUT_STRIP_TRAILING_WHITESPACE)
    string(REPLACE " " ";" LLVM_LIBDIRS "${LLVM_LIBDIRS_SPACES}")

    execute_process(
        COMMAND ${LLVM_CONFIG_EXE} --system-libs ${STATIC_OR_SHARED_LINK}
        OUTPUT_VARIABLE LLVM_SYSTEM_LIBS_SPACES
        OUTPUT_STRIP_TRAILING_WHITESPACE)
    string(REPLACE " " ";" LLVM_SYSTEM_LIBS "${LLVM_SYSTEM_LIBS_SPACES}")

    execute_process(
      COMMAND ${LLVM_CONFIG_EXE} --shared-mode ${STATIC_OR_SHARED_LINK}
      OUTPUT_VARIABLE LLVM_LINK_MODE
      OUTPUT_STRIP_TRAILING_WHITESPACE)
  else()
    execute_process(
        COMMAND ${LLVM_CONFIG_EXE} --libs
        OUTPUT_VARIABLE LLVM_LIBRARIES_SPACES
        OUTPUT_STRIP_TRAILING_WHITESPACE)
    string(REPLACE " " ";" LLVM_LIBRARIES "${LLVM_LIBRARIES_SPACES}")

    execute_process(
        COMMAND ${LLVM_CONFIG_EXE} --libdir
        OUTPUT_VARIABLE LLVM_LIBDIRS_SPACES
        OUTPUT_STRIP_TRAILING_WHITESPACE)
    string(REPLACE " " ";" LLVM_LIBDIRS "${LLVM_LIBDIRS_SPACES}")

    execute_process(
        COMMAND ${LLVM_CONFIG_EXE} --system-libs
        OUTPUT_VARIABLE LLVM_SYSTEM_LIBS_SPACES
        OUTPUT_STRIP_TRAILING_WHITESPACE)
    string(REPLACE " " ";" LLVM_SYSTEM_LIBS "${LLVM_SYSTEM_LIBS_SPACES}")

    execute_process(
      COMMAND ${LLVM_CONFIG_EXE} --shared-mode
      OUTPUT_VARIABLE LLVM_LINK_MODE
      OUTPUT_STRIP_TRAILING_WHITESPACE)
  endif()

  if (${LLVM_LINK_MODE} STREQUAL "shared")
    # We always ask for the system libs corresponding to static linking,
    # since on some distros LLD is only available as a static library
    # and we need these libraries to link it successfully
    execute_process(
        COMMAND ${LLVM_CONFIG_EXE} --system-libs --link-static
        OUTPUT_VARIABLE LLVM_STATIC_SYSTEM_LIBS_SPACES
        ERROR_QUIET # Some installations have no static libs, we just ignore the failure
        OUTPUT_STRIP_TRAILING_WHITESPACE)
    string(REPLACE " " ";" LLVM_STATIC_SYSTEM_LIBS "${LLVM_STATIC_SYSTEM_LIBS_SPACES}")

    set(LLVM_LIBRARIES ${LLVM_LIBRARIES} ${LLVM_SYSTEM_LIBS} ${LLVM_STATIC_SYSTEM_LIBS})
  else()
    set(LLVM_LIBRARIES ${LLVM_LIBRARIES} ${LLVM_SYSTEM_LIBS})
  endif()

  execute_process(
      COMMAND ${LLVM_CONFIG_EXE} --includedir
      OUTPUT_VARIABLE LLVM_INCLUDE_DIRS_SPACES
      OUTPUT_STRIP_TRAILING_WHITESPACE)
  string(REPLACE " " ";" LLVM_INCLUDE_DIRS "${LLVM_INCLUDE_DIRS_SPACES}")

  link_directories("${LLVM_LIBDIRS}")
else()
  # Here we assume that we're cross compiling with Zig, of course. No reason
  # to support more complicated setups.

  macro(FIND_AND_ADD_LLVM_LIB _libname_)
    string(TOUPPER ${_libname_} _prettylibname_)
    find_library(LLVM_${_prettylibname_}_LIB
      NAMES ${_libname_} NAMES_PER_DIR)
    set(LLVM_LIBRARIES ${LLVM_LIBRARIES} ${LLVM_${_prettylibname_}_LIB})
  endmacro(FIND_AND_ADD_LLVM_LIB)

  set(LLVM_LINK_MODE "static")

  # This list can be re-generated with `llvm-config --libfiles` and then
  # reformatting using your favorite text editor. Note we do not execute
  # `llvm-config` here because we are cross compiling.
  FIND_AND_ADD_LLVM_LIB(LLVMWindowsManifest)
  FIND_AND_ADD_LLVM_LIB(LLVMXRay)
  FIND_AND_ADD_LLVM_LIB(LLVMLibDriver)
  FIND_AND_ADD_LLVM_LIB(LLVMDlltoolDriver)
  FIND_AND_ADD_LLVM_LIB(LLVMTextAPIBinaryReader)
  FIND_AND_ADD_LLVM_LIB(LLVMCoverage)
  FIND_AND_ADD_LLVM_LIB(LLVMLineEditor)
  FIND_AND_ADD_LLVM_LIB(LLVMSandboxIR)
  FIND_AND_ADD_LLVM_LIB(LLVMXCoreDisassembler)
  FIND_AND_ADD_LLVM_LIB(LLVMXCoreCodeGen)
  FIND_AND_ADD_LLVM_LIB(LLVMXCoreDesc)
  FIND_AND_ADD_LLVM_LIB(LLVMXCoreInfo)
  FIND_AND_ADD_LLVM_LIB(LLVMX86TargetMCA)
  FIND_AND_ADD_LLVM_LIB(LLVMX86Disassembler)
  FIND_AND_ADD_LLVM_LIB(LLVMX86AsmParser)
  FIND_AND_ADD_LLVM_LIB(LLVMX86CodeGen)
  FIND_AND_ADD_LLVM_LIB(LLVMX86Desc)
  FIND_AND_ADD_LLVM_LIB(LLVMX86Info)
  FIND_AND_ADD_LLVM_LIB(LLVMWebAssemblyDisassembler)
  FIND_AND_ADD_LLVM_LIB(LLVMWebAssemblyAsmParser)
  FIND_AND_ADD_LLVM_LIB(LLVMWebAssemblyCodeGen)
  FIND_AND_ADD_LLVM_LIB(LLVMWebAssemblyUtils)
  FIND_AND_ADD_LLVM_LIB(LLVMWebAssemblyDesc)
  FIND_AND_ADD_LLVM_LIB(LLVMWebAssemblyInfo)
  FIND_AND_ADD_LLVM_LIB(LLVMVEDisassembler)
  FIND_AND_ADD_LLVM_LIB(LLVMVEAsmParser)
  FIND_AND_ADD_LLVM_LIB(LLVMVECodeGen)
  FIND_AND_ADD_LLVM_LIB(LLVMVEDesc)
  FIND_AND_ADD_LLVM_LIB(LLVMVEInfo)
  FIND_AND_ADD_LLVM_LIB(LLVMSystemZDisassembler)
  FIND_AND_ADD_LLVM_LIB(LLVMSystemZAsmParser)
  FIND_AND_ADD_LLVM_LIB(LLVMSystemZCodeGen)
  FIND_AND_ADD_LLVM_LIB(LLVMSystemZDesc)
  FIND_AND_ADD_LLVM_LIB(LLVMSystemZInfo)
  FIND_AND_ADD_LLVM_LIB(LLVMSparcDisassembler)
  FIND_AND_ADD_LLVM_LIB(LLVMSparcAsmParser)
  FIND_AND_ADD_LLVM_LIB(LLVMSparcCodeGen)
  FIND_AND_ADD_LLVM_LIB(LLVMSparcDesc)
  FIND_AND_ADD_LLVM_LIB(LLVMSparcInfo)
  FIND_AND_ADD_LLVM_LIB(LLVMRISCVTargetMCA)
  FIND_AND_ADD_LLVM_LIB(LLVMRISCVDisassembler)
  FIND_AND_ADD_LLVM_LIB(LLVMRISCVAsmParser)
  FIND_AND_ADD_LLVM_LIB(LLVMRISCVCodeGen)
  FIND_AND_ADD_LLVM_LIB(LLVMRISCVDesc)
  FIND_AND_ADD_LLVM_LIB(LLVMRISCVInfo)
  FIND_AND_ADD_LLVM_LIB(LLVMPowerPCDisassembler)
  FIND_AND_ADD_LLVM_LIB(LLVMPowerPCAsmParser)
  FIND_AND_ADD_LLVM_LIB(LLVMPowerPCCodeGen)
  FIND_AND_ADD_LLVM_LIB(LLVMPowerPCDesc)
  FIND_AND_ADD_LLVM_LIB(LLVMPowerPCInfo)
  FIND_AND_ADD_LLVM_LIB(LLVMNVPTXCodeGen)
  FIND_AND_ADD_LLVM_LIB(LLVMNVPTXDesc)
  FIND_AND_ADD_LLVM_LIB(LLVMNVPTXInfo)
  FIND_AND_ADD_LLVM_LIB(LLVMMSP430Disassembler)
  FIND_AND_ADD_LLVM_LIB(LLVMMSP430AsmParser)
  FIND_AND_ADD_LLVM_LIB(LLVMMSP430CodeGen)
  FIND_AND_ADD_LLVM_LIB(LLVMMSP430Desc)
  FIND_AND_ADD_LLVM_LIB(LLVMMSP430Info)
  FIND_AND_ADD_LLVM_LIB(LLVMMipsDisassembler)
  FIND_AND_ADD_LLVM_LIB(LLVMMipsAsmParser)
  FIND_AND_ADD_LLVM_LIB(LLVMMipsCodeGen)
  FIND_AND_ADD_LLVM_LIB(LLVMMipsDesc)
  FIND_AND_ADD_LLVM_LIB(LLVMMipsInfo)
  FIND_AND_ADD_LLVM_LIB(LLVMLoongArchDisassembler)
  FIND_AND_ADD_LLVM_LIB(LLVMLoongArchAsmParser)
  FIND_AND_ADD_LLVM_LIB(LLVMLoongArchCodeGen)
  FIND_AND_ADD_LLVM_LIB(LLVMLoongArchDesc)
  FIND_AND_ADD_LLVM_LIB(LLVMLoongArchInfo)
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
  FIND_AND_ADD_LLVM_LIB(LLVMBPFAsmParser)
  FIND_AND_ADD_LLVM_LIB(LLVMBPFCodeGen)
  FIND_AND_ADD_LLVM_LIB(LLVMBPFDesc)
  FIND_AND_ADD_LLVM_LIB(LLVMBPFInfo)
  FIND_AND_ADD_LLVM_LIB(LLVMAVRDisassembler)
  FIND_AND_ADD_LLVM_LIB(LLVMAVRAsmParser)
  FIND_AND_ADD_LLVM_LIB(LLVMAVRCodeGen)
  FIND_AND_ADD_LLVM_LIB(LLVMAVRDesc)
  FIND_AND_ADD_LLVM_LIB(LLVMAVRInfo)
  FIND_AND_ADD_LLVM_LIB(LLVMARMDisassembler)
  FIND_AND_ADD_LLVM_LIB(LLVMARMAsmParser)
  FIND_AND_ADD_LLVM_LIB(LLVMARMCodeGen)
  FIND_AND_ADD_LLVM_LIB(LLVMARMDesc)
  FIND_AND_ADD_LLVM_LIB(LLVMARMUtils)
  FIND_AND_ADD_LLVM_LIB(LLVMARMInfo)
  FIND_AND_ADD_LLVM_LIB(LLVMAMDGPUTargetMCA)
  FIND_AND_ADD_LLVM_LIB(LLVMAMDGPUDisassembler)
  FIND_AND_ADD_LLVM_LIB(LLVMAMDGPUAsmParser)
  FIND_AND_ADD_LLVM_LIB(LLVMAMDGPUCodeGen)
  FIND_AND_ADD_LLVM_LIB(LLVMAMDGPUDesc)
  FIND_AND_ADD_LLVM_LIB(LLVMAMDGPUUtils)
  FIND_AND_ADD_LLVM_LIB(LLVMAMDGPUInfo)
  FIND_AND_ADD_LLVM_LIB(LLVMAArch64Disassembler)
  FIND_AND_ADD_LLVM_LIB(LLVMAArch64AsmParser)
  FIND_AND_ADD_LLVM_LIB(LLVMAArch64CodeGen)
  FIND_AND_ADD_LLVM_LIB(LLVMAArch64Desc)
  FIND_AND_ADD_LLVM_LIB(LLVMAArch64Utils)
  FIND_AND_ADD_LLVM_LIB(LLVMAArch64Info)
  FIND_AND_ADD_LLVM_LIB(LLVMOrcDebugging)
  FIND_AND_ADD_LLVM_LIB(LLVMOrcJIT)
  FIND_AND_ADD_LLVM_LIB(LLVMWindowsDriver)
  FIND_AND_ADD_LLVM_LIB(LLVMMCJIT)
  FIND_AND_ADD_LLVM_LIB(LLVMJITLink)
  FIND_AND_ADD_LLVM_LIB(LLVMInterpreter)
  FIND_AND_ADD_LLVM_LIB(LLVMExecutionEngine)
  FIND_AND_ADD_LLVM_LIB(LLVMRuntimeDyld)
  FIND_AND_ADD_LLVM_LIB(LLVMOrcTargetProcess)
  FIND_AND_ADD_LLVM_LIB(LLVMOrcShared)
  FIND_AND_ADD_LLVM_LIB(LLVMDWP)
  FIND_AND_ADD_LLVM_LIB(LLVMDebugInfoLogicalView)
  FIND_AND_ADD_LLVM_LIB(LLVMDebugInfoGSYM)
  FIND_AND_ADD_LLVM_LIB(LLVMOption)
  FIND_AND_ADD_LLVM_LIB(LLVMObjectYAML)
  FIND_AND_ADD_LLVM_LIB(LLVMObjCopy)
  FIND_AND_ADD_LLVM_LIB(LLVMMCA)
  FIND_AND_ADD_LLVM_LIB(LLVMMCDisassembler)
  FIND_AND_ADD_LLVM_LIB(LLVMLTO)
  FIND_AND_ADD_LLVM_LIB(LLVMPasses)
  FIND_AND_ADD_LLVM_LIB(LLVMHipStdPar)
  FIND_AND_ADD_LLVM_LIB(LLVMCFGuard)
  FIND_AND_ADD_LLVM_LIB(LLVMCoroutines)
  FIND_AND_ADD_LLVM_LIB(LLVMipo)
  FIND_AND_ADD_LLVM_LIB(LLVMVectorize)
  FIND_AND_ADD_LLVM_LIB(LLVMLinker)
  FIND_AND_ADD_LLVM_LIB(LLVMInstrumentation)
  FIND_AND_ADD_LLVM_LIB(LLVMFrontendOpenMP)
  FIND_AND_ADD_LLVM_LIB(LLVMFrontendOffloading)
  FIND_AND_ADD_LLVM_LIB(LLVMFrontendOpenACC)
  FIND_AND_ADD_LLVM_LIB(LLVMFrontendHLSL)
  FIND_AND_ADD_LLVM_LIB(LLVMFrontendDriver)
  FIND_AND_ADD_LLVM_LIB(LLVMExtensions)
  FIND_AND_ADD_LLVM_LIB(LLVMDWARFLinkerParallel)
  FIND_AND_ADD_LLVM_LIB(LLVMDWARFLinkerClassic)
  FIND_AND_ADD_LLVM_LIB(LLVMDWARFLinker)
  FIND_AND_ADD_LLVM_LIB(LLVMCodeGenData)
  FIND_AND_ADD_LLVM_LIB(LLVMGlobalISel)
  FIND_AND_ADD_LLVM_LIB(LLVMMIRParser)
  FIND_AND_ADD_LLVM_LIB(LLVMAsmPrinter)
  FIND_AND_ADD_LLVM_LIB(LLVMSelectionDAG)
  FIND_AND_ADD_LLVM_LIB(LLVMCodeGen)
  FIND_AND_ADD_LLVM_LIB(LLVMTarget)
  FIND_AND_ADD_LLVM_LIB(LLVMObjCARCOpts)
  FIND_AND_ADD_LLVM_LIB(LLVMCodeGenTypes)
  FIND_AND_ADD_LLVM_LIB(LLVMIRPrinter)
  FIND_AND_ADD_LLVM_LIB(LLVMInterfaceStub)
  FIND_AND_ADD_LLVM_LIB(LLVMFileCheck)
  FIND_AND_ADD_LLVM_LIB(LLVMFuzzMutate)
  FIND_AND_ADD_LLVM_LIB(LLVMScalarOpts)
  FIND_AND_ADD_LLVM_LIB(LLVMInstCombine)
  FIND_AND_ADD_LLVM_LIB(LLVMAggressiveInstCombine)
  FIND_AND_ADD_LLVM_LIB(LLVMTransformUtils)
  FIND_AND_ADD_LLVM_LIB(LLVMBitWriter)
  FIND_AND_ADD_LLVM_LIB(LLVMAnalysis)
  FIND_AND_ADD_LLVM_LIB(LLVMProfileData)
  FIND_AND_ADD_LLVM_LIB(LLVMSymbolize)
  FIND_AND_ADD_LLVM_LIB(LLVMDebugInfoBTF)
  FIND_AND_ADD_LLVM_LIB(LLVMDebugInfoPDB)
  FIND_AND_ADD_LLVM_LIB(LLVMDebugInfoMSF)
  FIND_AND_ADD_LLVM_LIB(LLVMDebugInfoDWARF)
  FIND_AND_ADD_LLVM_LIB(LLVMObject)
  FIND_AND_ADD_LLVM_LIB(LLVMTextAPI)
  FIND_AND_ADD_LLVM_LIB(LLVMMCParser)
  FIND_AND_ADD_LLVM_LIB(LLVMIRReader)
  FIND_AND_ADD_LLVM_LIB(LLVMAsmParser)
  FIND_AND_ADD_LLVM_LIB(LLVMMC)
  FIND_AND_ADD_LLVM_LIB(LLVMDebugInfoCodeView)
  FIND_AND_ADD_LLVM_LIB(LLVMBitReader)
  FIND_AND_ADD_LLVM_LIB(LLVMFuzzerCLI)
  FIND_AND_ADD_LLVM_LIB(LLVMCore)
  FIND_AND_ADD_LLVM_LIB(LLVMRemarks)
  FIND_AND_ADD_LLVM_LIB(LLVMBitstreamReader)
  FIND_AND_ADD_LLVM_LIB(LLVMBinaryFormat)
  FIND_AND_ADD_LLVM_LIB(LLVMTargetParser)
  FIND_AND_ADD_LLVM_LIB(LLVMSupport)
  FIND_AND_ADD_LLVM_LIB(LLVMDemangle)

  get_filename_component(LLVM_LIBDIRS "${LLVM_LLVMCORE_LIB}" DIRECTORY)
  find_path(LLVM_INCLUDE_DIRS NAMES llvm/IR/IRBuilder.h)
endif()

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(llvm DEFAULT_MSG LLVM_LIBRARIES LLVM_INCLUDE_DIRS)

mark_as_advanced(LLVM_INCLUDE_DIRS LLVM_LIBRARIES LLVM_LIBDIRS)
