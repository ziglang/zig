        .file   1 "test2.c"
        .loc    1 2 0
        jmp     bar

        .section        .debug_abbrev,"",@progbits
        .byte   1                       # Abbreviation Code
        .byte   17                      # DW_TAG_compile_unit
        .byte   0                       # DW_CHILDREN_no
        .byte   16                      # DW_AT_stmt_list
        .byte   23                      # DW_FORM_sec_offset
        .byte   0                       # EOM(1)
        .byte   0                       # EOM(2)
        .byte   0                       # EOM(3)

        .section        .debug_info,"",@progbits
        .long   .Lend0 - .Lbegin0       # Length of Unit
.Lbegin0:
        .short  4                       # DWARF version number
        .long   .debug_abbrev           # Offset Into Abbrev. Section
        .byte   8                       # Address Size (in bytes)
        .byte   1                       # Abbrev [1] 0xb:0x1f DW_TAG_compile_unit
        .long   .debug_line             # DW_AT_stmt_list
.Lend0:
        .section        .debug_line,"",@progbits
