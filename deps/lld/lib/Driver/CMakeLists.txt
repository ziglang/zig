set(LLVM_TARGET_DEFINITIONS DarwinLdOptions.td)
tablegen(LLVM DarwinLdOptions.inc -gen-opt-parser-defs)
add_public_tablegen_target(DriverOptionsTableGen)

add_lld_library(lldDriver
  DarwinLdDriver.cpp

  ADDITIONAL_HEADER_DIRS
  ${LLD_INCLUDE_DIR}/lld/Driver

  LINK_COMPONENTS
    Object
    Option
    Support

  LINK_LIBS
    lldConfig
    lldMachO
    lldCore
    lldReaderWriter
    lldYAML
  )

add_dependencies(lldDriver DriverOptionsTableGen)
