# Copyright (c) 2016 Andrew Kelley
# This file is MIT licensed.
# See http://opensource.org/licenses/MIT

# CLANG_FOUND
# CLANG_INCLUDE_DIRS
# CLANG_LIBRARIES

find_package(Clang REQUIRED)

if(CLANG_LINK_CLANG_DYLIB)
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
