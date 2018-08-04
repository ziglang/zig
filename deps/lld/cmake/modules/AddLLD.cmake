macro(add_lld_library name)
  cmake_parse_arguments(ARG
    "SHARED"
    ""
    ""
    ${ARGN})
  if(ARG_SHARED)
    set(ARG_ENABLE_SHARED SHARED)
  endif()
  llvm_add_library(${name} ${ARG_ENABLE_SHARED} ${ARG_UNPARSED_ARGUMENTS})
  set_target_properties(${name} PROPERTIES FOLDER "lld libraries")

  if (NOT LLVM_INSTALL_TOOLCHAIN_ONLY)
    if(${name} IN_LIST LLVM_DISTRIBUTION_COMPONENTS OR
        NOT LLVM_DISTRIBUTION_COMPONENTS)
      set(export_to_lldtargets EXPORT lldTargets)
      set_property(GLOBAL PROPERTY LLD_HAS_EXPORTS True)
    endif()

    install(TARGETS ${name}
      COMPONENT ${name}
      ${export_to_lldtargets}
      LIBRARY DESTINATION lib${LLVM_LIBDIR_SUFFIX}
      ARCHIVE DESTINATION lib${LLVM_LIBDIR_SUFFIX}
      RUNTIME DESTINATION bin)

    if (${ARG_SHARED} AND NOT CMAKE_CONFIGURATION_TYPES)
      add_llvm_install_targets(install-${name}
        DEPENDS ${name}
        COMPONENT ${name})
    endif()
    set_property(GLOBAL APPEND PROPERTY LLD_EXPORTS ${name})
  endif()
endmacro(add_lld_library)

macro(add_lld_executable name)
  add_llvm_executable(${name} ${ARGN})
  set_target_properties(${name} PROPERTIES FOLDER "lld executables")
endmacro(add_lld_executable)

macro(add_lld_tool name)
  if (NOT LLD_BUILD_TOOLS)
    set(EXCLUDE_FROM_ALL ON)
  endif()

  add_lld_executable(${name} ${ARGN})

  if (LLD_BUILD_TOOLS)
    if(${name} IN_LIST LLVM_DISTRIBUTION_COMPONENTS OR
        NOT LLVM_DISTRIBUTION_COMPONENTS)
      set(export_to_lldtargets EXPORT lldTargets)
      set_property(GLOBAL PROPERTY LLD_HAS_EXPORTS True)
    endif()

    install(TARGETS ${name}
      ${export_to_lldtargets}
      RUNTIME DESTINATION bin
      COMPONENT ${name})

    if(NOT CMAKE_CONFIGURATION_TYPES)
      add_llvm_install_targets(install-${name}
        DEPENDS ${name}
        COMPONENT ${name})
    endif()
    set_property(GLOBAL APPEND PROPERTY LLD_EXPORTS ${name})
  endif()
endmacro()

macro(add_lld_symlink name dest)
  add_llvm_tool_symlink(${name} ${dest} ALWAYS_GENERATE)
  # Always generate install targets
  llvm_install_symlink(${name} ${dest} ALWAYS_GENERATE)
endmacro()
