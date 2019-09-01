# Copyright (c) 2014 Andrew Kelley
# This file is MIT licensed.
# See http://opensource.org/licenses/MIT

# LLVM_FOUND
# LLVM_INCLUDE_DIRS
# LLVM_LIBRARIES

find_library(LLVM REQUIRED)
find_program(LLVM_CONFIG_EXE
    NAMES llvm-config-8 llvm-config-8.0 llvm-config80 llvm-config
    PATHS
        "/mingw64/bin"
        "/c/msys64/mingw64/bin"
        "c:/msys64/mingw64/bin"
        "C:/Libraries/llvm-8.0.0/bin")

if ("${LLVM_CONFIG_EXE}" STREQUAL "LLVM_CONFIG_EXE-NOTFOUND")
  message(FATAL_ERROR "unable to find llvm-config")
endif()

execute_process(
	COMMAND ${LLVM_CONFIG_EXE} --version
	OUTPUT_VARIABLE LLVM_CONFIG_VERSION
	OUTPUT_STRIP_TRAILING_WHITESPACE)

if(NOT ${LLVM_VERSION_MAJOR} EQUAL 8)
  message(FATAL_ERROR "expected LLVM 8.x but found ${LLVM_VERSION_MAJOR}")
endif()

execute_process(
	COMMAND ${LLVM_CONFIG_EXE} --targets-built
    OUTPUT_VARIABLE LLVM_TARGETS_BUILT_SPACES
	OUTPUT_STRIP_TRAILING_WHITESPACE)
string(REPLACE " " ";" LLVM_TARGETS_BUILT "${LLVM_TARGETS_BUILT_SPACES}")
function(NEED_TARGET TARGET_NAME)
    list (FIND LLVM_TARGETS_BUILT "${TARGET_NAME}" _index)
    if (${_index} EQUAL -1)
        message(FATAL_ERROR "LLVM is missing target ${TARGET_NAME}. Zig requires LLVM to be built with all default targets enabled.")
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
NEED_TARGET("Sparc")
NEED_TARGET("SystemZ")
NEED_TARGET("WebAssembly")
NEED_TARGET("X86")
NEED_TARGET("XCore")

execute_process(
    COMMAND ${LLVM_CONFIG_EXE} --libfiles
    OUTPUT_VARIABLE LLVM_LIBRARIES_SPACES
    OUTPUT_STRIP_TRAILING_WHITESPACE)
string(REPLACE " " ";" LLVM_LIBRARIES "${LLVM_LIBRARIES_SPACES}")

execute_process(
    COMMAND ${LLVM_CONFIG_EXE} --system-libs
    OUTPUT_VARIABLE LLVM_SYSTEM_LIBS_SPACES
    OUTPUT_STRIP_TRAILING_WHITESPACE)
string(REPLACE " " ";" LLVM_SYSTEM_LIBS "${LLVM_SYSTEM_LIBS_SPACES}")

list(APPEND LLVM_LIBRARIES ${LLVM_SYSTEM_LIBS})
