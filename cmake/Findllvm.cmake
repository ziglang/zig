# Copyright (c) 2014 Andrew Kelley
# This file is MIT licensed.
# See http://opensource.org/licenses/MIT

# LLVM_FOUND
# LLVM_INCLUDE_DIRS
# LLVM_LIBRARIES
# LLVM_LIBDIRS

find_program(LLVM_CONFIG_EXE
    NAMES llvm-config-9 llvm-config-9.0 llvm-config90 llvm-config
    PATHS
        "/mingw64/bin"
        "/c/msys64/mingw64/bin"
        "c:/msys64/mingw64/bin"
        "C:/Libraries/llvm-9.0.0/bin")

if ("${LLVM_CONFIG_EXE}" STREQUAL "LLVM_CONFIG_EXE-NOTFOUND")
  message(FATAL_ERROR "unable to find llvm-config")
endif()

if ("${LLVM_CONFIG_EXE}" STREQUAL "LLVM_CONFIG_EXE-NOTFOUND")
  message(FATAL_ERROR "unable to find llvm-config")
endif()

execute_process(
	COMMAND ${LLVM_CONFIG_EXE} --version
	OUTPUT_VARIABLE LLVM_CONFIG_VERSION
	OUTPUT_STRIP_TRAILING_WHITESPACE)

if("${LLVM_CONFIG_VERSION}" VERSION_LESS 9)
  message(FATAL_ERROR "expected LLVM 9.x but found ${LLVM_CONFIG_VERSION}")
endif()
if("${LLVM_CONFIG_VERSION}" VERSION_EQUAL 10)
  message(FATAL_ERROR "expected LLVM 9.x but found ${LLVM_CONFIG_VERSION}")
endif()
if("${LLVM_CONFIG_VERSION}" VERSION_GREATER 10)
  message(FATAL_ERROR "expected LLVM 9.x but found ${LLVM_CONFIG_VERSION}")
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
NEED_TARGET("RISCV")
NEED_TARGET("Sparc")
NEED_TARGET("SystemZ")
NEED_TARGET("WebAssembly")
NEED_TARGET("X86")
NEED_TARGET("XCore")

if(ZIG_STATIC_LLVM)
  execute_process(
      COMMAND ${LLVM_CONFIG_EXE} --libfiles --link-static
      OUTPUT_VARIABLE LLVM_LIBRARIES_SPACES
      OUTPUT_STRIP_TRAILING_WHITESPACE)
  string(REPLACE " " ";" LLVM_LIBRARIES "${LLVM_LIBRARIES_SPACES}")

  execute_process(
      COMMAND ${LLVM_CONFIG_EXE} --system-libs --link-static
      OUTPUT_VARIABLE LLVM_SYSTEM_LIBS_SPACES
      OUTPUT_STRIP_TRAILING_WHITESPACE)
  string(REPLACE " " ";" LLVM_SYSTEM_LIBS "${LLVM_SYSTEM_LIBS_SPACES}")

  execute_process(
      COMMAND ${LLVM_CONFIG_EXE} --libdir --link-static
      OUTPUT_VARIABLE LLVM_LIBDIRS_SPACES
      OUTPUT_STRIP_TRAILING_WHITESPACE)
  string(REPLACE " " ";" LLVM_LIBDIRS "${LLVM_LIBDIRS_SPACES}")
endif()
if(NOT LLVM_LIBRARIES)
  execute_process(
      COMMAND ${LLVM_CONFIG_EXE} --libs
      OUTPUT_VARIABLE LLVM_LIBRARIES_SPACES
      OUTPUT_STRIP_TRAILING_WHITESPACE)
  string(REPLACE " " ";" LLVM_LIBRARIES "${LLVM_LIBRARIES_SPACES}")

  execute_process(
      COMMAND ${LLVM_CONFIG_EXE} --system-libs
      OUTPUT_VARIABLE LLVM_SYSTEM_LIBS_SPACES
      OUTPUT_STRIP_TRAILING_WHITESPACE)
  string(REPLACE " " ";" LLVM_SYSTEM_LIBS "${LLVM_SYSTEM_LIBS_SPACES}")

  execute_process(
      COMMAND ${LLVM_CONFIG_EXE} --libdir
      OUTPUT_VARIABLE LLVM_LIBDIRS_SPACES
      OUTPUT_STRIP_TRAILING_WHITESPACE)
  string(REPLACE " " ";" LLVM_LIBDIRS "${LLVM_LIBDIRS_SPACES}")
endif()

execute_process(
    COMMAND ${LLVM_CONFIG_EXE} --includedir
    OUTPUT_VARIABLE LLVM_INCLUDE_DIRS
    OUTPUT_STRIP_TRAILING_WHITESPACE)

set(LLVM_LIBRARIES ${LLVM_LIBRARIES} ${LLVM_SYSTEM_LIBS})

if(NOT LLVM_LIBRARIES)
  find_library(LLVM_LIBRARIES NAMES LLVM LLVM-9 LLVM-9.0)
endif()

link_directories("${CMAKE_PREFIX_PATH}/lib")
link_directories("${LLVM_LIBDIRS}")

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(LLVM DEFAULT_MSG LLVM_LIBRARIES LLVM_INCLUDE_DIRS)

mark_as_advanced(LLVM_INCLUDE_DIRS LLVM_LIBRARIES LLVM_LIBDIRS)
