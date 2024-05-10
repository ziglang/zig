# Copyright (c) 2016 Andrew Kelley
# This file is MIT licensed.
# See http://opensource.org/licenses/MIT

# CLANG_FOUND
# CLANG_INCLUDE_DIRS
# CLANG_LIBRARIES
# CLANG_LIBDIRS

find_path(CLANG_INCLUDE_DIRS NAMES clang/Frontend/ASTUnit.h
  HINTS ${LLVM_INCLUDE_DIRS}
  # Only look for Clang next to LLVM or in { CMAKE_PREFIX_PATH, CMAKE_LIBRARY_PATH, CMAKE_FRAMEWORK_PATH }
  NO_SYSTEM_ENVIRONMENT_PATH
  NO_CMAKE_SYSTEM_PATH
)

if(${LLVM_LINK_MODE} STREQUAL "shared")
  find_library(CLANG_LIBRARIES
    NAMES
      libclang-cpp.so.18
      clang-cpp-18.0
      clang-cpp180
      clang-cpp
    NAMES_PER_DIR
    HINTS "${LLVM_LIBDIRS}"
    # Only look for Clang next to LLVM or in { CMAKE_PREFIX_PATH, CMAKE_LIBRARY_PATH, CMAKE_FRAMEWORK_PATH }
    NO_SYSTEM_ENVIRONMENT_PATH
    NO_CMAKE_SYSTEM_PATH
  )
else()
  macro(FIND_AND_ADD_CLANG_LIB _libname_)
    string(TOUPPER ${_libname_} _prettylibname_)
    find_library(CLANG_${_prettylibname_}_LIB NAMES ${_libname_} NAMES_PER_DIR
      HINTS "${LLVM_LIBDIRS}"
      # Only look for Clang next to LLVM or in { CMAKE_PREFIX_PATH, CMAKE_LIBRARY_PATH, CMAKE_FRAMEWORK_PATH }
      NO_SYSTEM_ENVIRONMENT_PATH
      NO_CMAKE_SYSTEM_PATH
    )
    if(CLANG_${_prettylibname_}_LIB)
      set(CLANG_LIBRARIES ${CLANG_LIBRARIES} ${CLANG_${_prettylibname_}_LIB})
    endif()
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
  FIND_AND_ADD_CLANG_LIB(clangAPINotes)
  FIND_AND_ADD_CLANG_LIB(clangBasic)
  FIND_AND_ADD_CLANG_LIB(clangEdit)
  FIND_AND_ADD_CLANG_LIB(clangLex)
  FIND_AND_ADD_CLANG_LIB(clangARCMigrate)
  FIND_AND_ADD_CLANG_LIB(clangRewriteFrontend)
  FIND_AND_ADD_CLANG_LIB(clangRewrite)
  FIND_AND_ADD_CLANG_LIB(clangCrossTU)
  FIND_AND_ADD_CLANG_LIB(clangIndex)
  FIND_AND_ADD_CLANG_LIB(clangToolingCore)
  FIND_AND_ADD_CLANG_LIB(clangExtractAPI)
  FIND_AND_ADD_CLANG_LIB(clangSupport)
endif()

if (MSVC)
  set(CLANG_LIBRARIES ${CLANG_LIBRARIES} "version.lib")
endif()

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(clang DEFAULT_MSG CLANG_LIBRARIES CLANG_INCLUDE_DIRS)

mark_as_advanced(CLANG_INCLUDE_DIRS CLANG_LIBRARIES CLANG_LIBDIRS)
