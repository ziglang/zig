set(LLVM_TARGET_DEFINITIONS Options.td)
tablegen(LLVM Options.inc -gen-opt-parser-defs)
add_public_tablegen_target(MinGWOptionsTableGen)

if(NOT LLD_BUILT_STANDALONE)
  set(tablegen_deps intrinsics_gen)
endif()

add_lld_library(lldMinGW
  Driver.cpp

  LINK_COMPONENTS
  Option
  Support

  LINK_LIBS
  lldCOFF
  lldCommon

  DEPENDS
  MinGWOptionsTableGen
  ${tablegen_deps}
)
