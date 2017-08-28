if(NOT LLD_BUILT_STANDALONE)
  set(tablegen_deps intrinsics_gen)
endif()

add_lld_library(lldCore
  DefinedAtom.cpp
  Error.cpp
  File.cpp
  LinkingContext.cpp
  Reader.cpp
  Reproduce.cpp
  Resolver.cpp
  SymbolTable.cpp
  TargetOptionsCommandFlags.cpp
  Writer.cpp

  ADDITIONAL_HEADER_DIRS
  ${LLD_INCLUDE_DIR}/lld/Core

  LINK_COMPONENTS
    BinaryFormat
    MC
    Support

  LINK_LIBS
  ${LLVM_PTHREAD_LIB}

  DEPENDS
  ${tablegen_deps}
  )
