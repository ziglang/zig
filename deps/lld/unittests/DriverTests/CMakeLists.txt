add_lld_unittest(DriverTests
  DarwinLdDriverTest.cpp
  )

target_link_libraries(DriverTests
  lldDriver
  lldMachO
  )
