# Copyright (c) 2016 Andrew Kelley
# This file is MIT licensed.
# See http://opensource.org/licenses/MIT

# CLANG_FOUND
# CLANG_INCLUDE_DIRS
# CLANG_LIBRARIES

find_path(CLANG_INCLUDE_DIRS NAMES clang/Frontend/ASTUnit.h
    PATHS
        ${LLVM_INSTALL_PREFIX}/include
        /usr/lib/llvm/5/include
        /usr/lib/llvm-5.0/include
        /mingw64/include)

if(NOT CLANG_INCLUDE_DIRS)
    message(FATAL_ERROR "Failed to find CLANG header files")
endif()

macro(FIND_AND_ADD_CLANG_LIB _libname_)
    string(TOUPPER ${_libname_} _prettylibname_)
    find_library(CLANG_${_prettylibname_}_LIB NAMES ${_libname_}
        PATHS
            ${LLVM_INSTALL_PREFIX}/lib
            /usr/lib/llvm/5/lib
            /usr/lib/llvm-5.0/lib
            /mingw64/lib
            /c/msys64/mingw64/lib
            c:\\msys64\\mingw64\\lib)
    if(CLANG_${_prettylibname_}_LIB)
        set(CLANG_LIBRARIES ${CLANG_LIBRARIES} ${CLANG_${_prettylibname_}_LIB})
    endif()
endmacro(FIND_AND_ADD_CLANG_LIB)

FIND_AND_ADD_CLANG_LIB(clangFrontend)
FIND_AND_ADD_CLANG_LIB(clangDriver)
FIND_AND_ADD_CLANG_LIB(clangSerialization)
FIND_AND_ADD_CLANG_LIB(clangSema)
FIND_AND_ADD_CLANG_LIB(clangAnalysis)
FIND_AND_ADD_CLANG_LIB(clangAST)
FIND_AND_ADD_CLANG_LIB(clangParse)
FIND_AND_ADD_CLANG_LIB(clangSema)
FIND_AND_ADD_CLANG_LIB(clangBasic)
FIND_AND_ADD_CLANG_LIB(clangEdit)
FIND_AND_ADD_CLANG_LIB(clangLex)

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(CLANG DEFAULT_MSG CLANG_LIBRARIES CLANG_INCLUDE_DIRS)

mark_as_advanced(CLANG_INCLUDE_DIRS CLANG_LIBRARIES)
