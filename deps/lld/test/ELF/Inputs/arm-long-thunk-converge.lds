SECTIONS {
  .foo : { *(.foo) }
  .bar 0x2000000 : { *(.bar) }
}
