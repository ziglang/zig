if(NOT LLD_BUILT_STANDALONE)
  set(tablegen_deps intrinsics_gen)
endif()

find_first_existing_vc_file("${LLVM_MAIN_SRC_DIR}" llvm_vc)
find_first_existing_vc_file("${LLD_SOURCE_DIR}" lld_vc)

set(version_inc "${CMAKE_CURRENT_BINARY_DIR}/VCSVersion.inc")
set(generate_vcs_version_script "${LLVM_CMAKE_PATH}/GenerateVersionFromVCS.cmake")

if(lld_vc)
  set(lld_source_dir ${LLD_SOURCE_DIR})
endif()

add_custom_command(OUTPUT "${version_inc}"
  DEPENDS "${lld_vc}" "${generate_vcs_version_script}"
  COMMAND ${CMAKE_COMMAND} "-DNAMES=LLD"
  "-DLLD_SOURCE_DIR=${LLD_SOURCE_DIR}"
  "-DHEADER_FILE=${version_inc}"
  -P "${generate_vcs_version_script}")

# Mark the generated header as being generated.
set_source_files_properties("${version_inc}"
  PROPERTIES GENERATED TRUE
  HEADER_FILE_ONLY TRUE)

set_property(SOURCE Version.cpp APPEND PROPERTY
  COMPILE_DEFINITIONS "HAVE_VCS_VERSION_INC")

add_lld_library(lldCommon
  Args.cpp
  ErrorHandler.cpp
  Filesystem.cpp
  Memory.cpp
  Reproduce.cpp
  Strings.cpp
  TargetOptionsCommandFlags.cpp
  Threads.cpp
  Timer.cpp
  VCSVersion.inc
  Version.cpp

  ADDITIONAL_HEADER_DIRS
  ${LLD_INCLUDE_DIR}/lld/Common

  LINK_COMPONENTS
  Codegen
  Core
  Demangle
  MC
  Option
  Support
  Target

  LINK_LIBS
  ${LLVM_PTHREAD_LIB}

  DEPENDS
  ${tablegen_deps}
  )
