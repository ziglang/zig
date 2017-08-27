add_lld_library(lldConfig
  Version.cpp

  ADDITIONAL_HEADER_DIRS
  ${LLD_INCLUDE_DIR}/lld/Config

  LINK_COMPONENTS
    Support
  )
