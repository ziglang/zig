# Copyright (c) 2014 Andrew Kelley
# This file is MIT licensed.
# See http://opensource.org/licenses/MIT

# LLVM_INCLUDE_DIR
# LLVM_LIBRARIES
# LLVM_LIBDIRS

if(LLVM_INSTALL_PREFIX)
    find_program(LLVM_CONFIG_EXE
        NAMES llvm-config-5.0 llvm-config
        PATHS ${LLVM_INSTALL_PREFIX}/bin
        NO_DEFAULT_PATH)
    if(NOT LLVM_CONFIG_EXE)
        message(FATAL_ERROR "Invalid LLVM_INSTALL_PREFIX \"${LLVM_INSTALL_PREFIX}\", could not find llvm-config")
    endif()
else()
    find_program(LLVM_CONFIG_EXE
        NAMES llvm-config-5.0 llvm-config
        PATHS
            "/mingw64/bin"
            "/c/msys64/mingw64/bin"
            "c:/msys64/mingw64/bin"
            "C:/Libraries/llvm-5.0.0/bin")
    if(NOT LLVM_CONFIG_EXE)
        message(FATAL_ERROR "Could not find llvm-config, use -DLLVM_INSTALL_PREFIX to specify the install path")
    endif()
    execute_process(
        COMMAND ${LLVM_CONFIG_EXE} --prefix
        OUTPUT_VARIABLE LLVM_INSTALL_PREFIX
        OUTPUT_STRIP_TRAILING_WHITESPACE)
endif()

if(${LLVM_INSTALL_PREFIX} MATCHES "^.* ")
    # NOTE: this is a limitation due to llvm-config.  If the path contains spaces then there's
    # no way to tell from the output of llvm-config whether a space is seperating a filename, or
    # just a space in the path name.
    message(FATAL_ERROR "The LLVM install path \"${LLVM_INSTALL_PREFIX}\" cannot contain spaces")
endif()

execute_process(
    COMMAND ${LLVM_CONFIG_EXE} --libs
    OUTPUT_VARIABLE LLVM_LIBRARIES_STRING
    OUTPUT_STRIP_TRAILING_WHITESPACE)
string(REPLACE " " ";" LLVM_LIBRARIES ${LLVM_LIBRARIES_STRING})

execute_process(
    COMMAND ${LLVM_CONFIG_EXE} --system-libs
    OUTPUT_VARIABLE LLVM_SYSTEM_LIBS_STRING
    OUTPUT_STRIP_TRAILING_WHITESPACE)
string(REPLACE " " ";" LLVM_SYSTEM_LIBS ${LLVM_SYSTEM_LIBS_STRING})

execute_process(
    COMMAND ${LLVM_CONFIG_EXE} --libdir
    OUTPUT_VARIABLE LLVM_LIBDIRS
    OUTPUT_STRIP_TRAILING_WHITESPACE)

execute_process(
    COMMAND ${LLVM_CONFIG_EXE} --includedir
    OUTPUT_VARIABLE LLVM_INCLUDE_DIR
    OUTPUT_STRIP_TRAILING_WHITESPACE)

find_library(LLVM_LIBRARY NAMES LLVM)

set(LLVM_LIBRARIES ${LLVM_LIBRARIES} ${LLVM_SYSTEM_LIBS})

if(LLVM_LIBRARY)
  set(LLVM_LIBRARIES ${LLVM_LIBRARY})
endif()


include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(LLVM DEFAULT_MSG LLVM_LIBRARIES LLVM_INCLUDE_DIR)

mark_as_advanced(LLVM_INCLUDE_DIR LLVM_LIBRARIES LLVM_LIBDIRS)
