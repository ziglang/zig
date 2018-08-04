set(LLVM_SOURCE_DIR "${LLVM_MAIN_SRC_DIR}")
set(LLVM_BINARY_DIR "${LLVM_BINARY_DIR}")
set(LLVM_BUILD_MODE "%(build_mode)s")
set(LLVM_TOOLS_DIR "${LLVM_TOOLS_BINARY_DIR}/%(build_config)s")
set(LLVM_LIBS_DIR "${LLVM_BINARY_DIR}/lib${LLVM_LIBDIR_SUFFIX}/%(build_config)s")

if(LLD_BUILT_STANDALONE)
  # Set HAVE_LIBZ according to recorded LLVM_ENABLE_ZLIB value. This
  # value is forced to 0 if zlib was not found, so it is fine to use it
  # instead of HAVE_LIBZ (not recorded).
  if(LLVM_ENABLE_ZLIB)
    set(HAVE_LIBZ 1)
  endif()
endif()

llvm_canonicalize_cmake_booleans(
  HAVE_LIBZ)

configure_lit_site_cfg(
  ${CMAKE_CURRENT_SOURCE_DIR}/lit.site.cfg.py.in
  ${CMAKE_CURRENT_BINARY_DIR}/lit.site.cfg.py
  MAIN_CONFIG
  ${CMAKE_CURRENT_SOURCE_DIR}/lit.cfg.py
  )
configure_lit_site_cfg(
  ${CMAKE_CURRENT_SOURCE_DIR}/Unit/lit.site.cfg.py.in
  ${CMAKE_CURRENT_BINARY_DIR}/Unit/lit.site.cfg.py
  MAIN_CONFIG
  ${CMAKE_CURRENT_SOURCE_DIR}/Unit/lit.cfg.py
  )

set(LLD_TEST_DEPS lld)
if (NOT LLD_BUILT_STANDALONE)
  list(APPEND LLD_TEST_DEPS
    FileCheck count llc llvm-ar llvm-as llvm-bcanalyzer llvm-config llvm-dis
    llvm-dwarfdump llvm-lib llvm-mc llvm-nm llvm-objcopy llvm-objdump
    llvm-pdbutil llvm-readelf llvm-readobj not obj2yaml opt yaml2obj
    )
endif()

if (LLVM_INCLUDE_TESTS)
  list(APPEND LLD_TEST_DEPS LLDUnitTests)
endif()

set(LLD_TEST_PARAMS
  lld_site_config=${CMAKE_CURRENT_BINARY_DIR}/lit.site.cfg
  )

add_lit_testsuite(check-lld "Running lld test suite"
  ${CMAKE_CURRENT_BINARY_DIR}
  PARAMS lld_site_config=${CMAKE_CURRENT_BINARY_DIR}/lit.site.cfg
       lld_unit_site_config=${CMAKE_CURRENT_BINARY_DIR}/Unit/lit.site.cfg
  DEPENDS ${LLD_TEST_DEPS}
  )

add_lit_testsuites(LLD ${CMAKE_CURRENT_SOURCE_DIR}
  PARAMS lld_site_config=${CMAKE_CURRENT_BINARY_DIR}/lit.site.cfg
       lld_unit_site_config=${CMAKE_CURRENT_BINARY_DIR}/Unit/lit.site.cfg
  DEPENDS ${LLD_TEST_DEPS}
  )

set_target_properties(check-lld PROPERTIES FOLDER "lld tests")

# Add a legacy target spelling: lld-test
add_custom_target(lld-test)
add_dependencies(lld-test check-lld)
set_target_properties(lld-test PROPERTIES FOLDER "lld tests")
