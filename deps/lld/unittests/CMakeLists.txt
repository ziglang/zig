add_custom_target(LLDUnitTests)
set_target_properties(LLDUnitTests PROPERTIES FOLDER "lld tests")

set(CMAKE_BUILD_WITH_INSTALL_RPATH OFF)

# add_lld_unittest(test_dirname file1.cpp file2.cpp)
#
# Will compile the list of files together and link against lld
# Produces a binary named 'basename(test_dirname)'.
function(add_lld_unittest test_dirname)
  add_unittest(LLDUnitTests ${test_dirname} ${ARGN})
  target_link_libraries(${test_dirname} ${LLVM_COMMON_LIBS})
endfunction()

add_subdirectory(DriverTests)
add_subdirectory(MachOTests)
