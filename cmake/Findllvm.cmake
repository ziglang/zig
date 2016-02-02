# Copyright (c) 2014 Andrew Kelley
# This file is MIT licensed.
# See http://opensource.org/licenses/MIT

# LLVM_FOUND
# LLVM_INCLUDE_DIRS
# LLVM_LIBRARIES
# LLVM_LIBDIRS

find_path(LLVM_C_INCLUDE_DIR NAMES llvm-c/Core.h PATHS /usr/include/llvm-c-3.7/)
find_path(LLVM_INCLUDE_DIR NAMES llvm/IR/IRBuilder.h PATHS /usr/include/llvm-3.7/)
set(LLVM_INCLUDE_DIRS ${LLVM_C_INCLUDE_DIR} ${LLVM_INCLUDE_DIR})

find_program(LLVM_CONFIG_EXE NAMES llvm-config llvm-config-3.7)

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

set(LLVM_LIBRARIES ${LLVM_LIBRARIES} ${LLVM_SYSTEM_LIBS})


include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(LLVM DEFAULT_MSG LLVM_LIBRARIES LLVM_INCLUDE_DIRS)

mark_as_advanced(LLVM_INCLUDE_DIRS LLVM_LIBRARIES LLVM_LIBDIRS)
