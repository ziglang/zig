.section .text,"ax"
sym:
    .quad zed6
sym2:
    .quad zed7

.section .debug_line,"",@progbits
.Lunit:
    .long .Lunit_end - .Lunit_start # unit length
.Lunit_start:
    .short 4                        # version
    .long .Lprologue_end - .Lprologue_start # prologue length
.Lprologue_start:
    .byte 1                         # minimum instruction length
    .byte 1                         # maximum operatiosn per instruction
    .byte 1                         # default is_stmt
    .byte -5                        # line base
    .byte 14                        # line range
    .byte 13                        # opcode base
    .byte 0, 1, 1, 1, 1, 0, 0, 0, 1, 0, 0, 1 # standard opcode lengths
    .asciz "dir"                    # include directories
    .byte 0
    .asciz "undef-bad-debug.s"      # file names
    .byte 1, 0, 0
    .byte 0
    .byte 0                         # extraneous byte
.Lprologue_end:
    .byte 0, 9, 2                   # DW_LNE_set_address
    .quad sym
    .byte 3                         # DW_LNS_advance_line
    .byte 10
    .byte 1                         # DW_LNS_copy
    .byte 2                         # DW_LNS_advance_pc
    .byte 8
    .byte 0, 1, 1                   # DW_LNE_end_sequence
.Lunit_end:

.Lunit2:
    .long .Lunit2_end - .Lunit2_start # unit length
.Lunit2_start:
    .short 4                        # version
    .long .Lprologue2_end - .Lprologue2_start # prologue length
.Lprologue2_start:
    .byte 1                         # minimum instruction length
    .byte 1                         # maximum operatiosn per instruction
    .byte 1                         # default is_stmt
    .byte -5                        # line base
    .byte 14                        # line range
    .byte 13                        # opcode base
    .byte 0, 1, 1, 1, 1, 0, 0, 0, 1, 0, 0, 1 # standard opcode lengths
    .asciz "dir2"                   # include directories
    .byte 0
    .asciz "undef-bad-debug2.s"     # file names
    .byte 1, 0, 0
    .byte 0
.Lprologue2_end:
    .byte 0, 9, 2                   # DW_LNE_set_address
    .quad sym2
    .byte 3                         # DW_LNS_advance_line
    .byte 10
    .byte 1                         # DW_LNS_copy
    .byte 2                         # DW_LNS_advance_pc
    .byte 8
    .byte 0, 1, 1                   # DW_LNE_end_sequence
    .byte 0, 9, 2                   # DW_LNE_set_address
    .quad 0x0badbeef
    .byte 3                         # DW_LNS_advance_line
    .byte 99
    .byte 1                         # DW_LNS_copy
    .byte 99                        # DW_LNS_advance_pc
    .byte 119
    # Missing end of sequence.
.Lunit2_end:

.section .debug_info,"",@progbits
    .long   .Lcu_end - .Lcu_start   # Length of Unit
.Lcu_start:
    .short  4                       # DWARF version number
    .long   .Lsection_abbrev        # Offset Into Abbrev. Section
    .byte   8                       # Address Size (in bytes)
    .byte   1                       # Abbrev [1] 0xb:0x79 DW_TAG_compile_unit
    .long   .Lunit                  # DW_AT_stmt_list
    .byte   2                       # Abbrev [2] 0x2a:0x15 DW_TAG_variable
    .long   .Linfo_string           # DW_AT_name
                                        # DW_AT_external
    .byte   1                       # DW_AT_decl_file
    .byte   3                       # DW_AT_decl_line
    .byte   0                       # End Of Children Mark
.Lcu_end:

    .long   .Lcu2_end - .Lcu2_start # Length of Unit
.Lcu2_start:
    .short  4                       # DWARF version number
    .long   .Lsection_abbrev        # Offset Into Abbrev. Section
    .byte   8                       # Address Size (in bytes)
    .byte   1                       # Abbrev [1] 0xb:0x79 DW_TAG_compile_unit
    .long   .Lunit2                 # DW_AT_stmt_list
    .byte   2                       # Abbrev [2] 0x2a:0x15 DW_TAG_variable
    .long   .Linfo2_string          # DW_AT_name
                                        # DW_AT_external
    .byte   1                       # DW_AT_decl_file
    .byte   3                       # DW_AT_decl_line
    .byte   0                       # End Of Children Mark
.Lcu2_end:

.section .debug_abbrev,"",@progbits
.Lsection_abbrev:
    .byte   1                       # Abbreviation Code
    .byte   17                      # DW_TAG_compile_unit
    .byte   1                       # DW_CHILDREN_yes
    .byte   16                      # DW_AT_stmt_list
    .byte   23                      # DW_FORM_sec_offset
    .byte   0                       # EOM(1)
    .byte   0                       # EOM(2)
    .byte   2                       # Abbreviation Code
    .byte   52                      # DW_TAG_variable
    .byte   0                       # DW_CHILDREN_no
    .byte   3                       # DW_AT_name
    .byte   14                      # DW_FORM_strp
    .byte   63                      # DW_AT_external
    .byte   25                      # DW_FORM_flag_present
    .byte   58                      # DW_AT_decl_file
    .byte   11                      # DW_FORM_data1
    .byte   59                      # DW_AT_decl_line
    .byte   11                      # DW_FORM_data1
    .byte   0                       # EOM(1)
    .byte   0                       # EOM(2)
    .byte   0                       # EOM(3)

.section .debug_str,"MS",@progbits,1
.Linfo_string:
    .asciz "sym"
.Linfo2_string:
    .asciz "sym2"
