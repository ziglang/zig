# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o

# RUN: llvm-dwarfdump -v %t.o | FileCheck -check-prefix=INPUT %s
# INPUT:     .debug_info contents:
# INPUT:       DW_TAG_variable
# INPUT-NEXT:    DW_AT_name [DW_FORM_strp]       ( .debug_str[0x00000027] = "foo")
# INPUT-NEXT:    DW_AT_type [DW_FORM_ref4]       (cu + 0x0033 => {0x00000033} "int")
# INPUT-NEXT:    DW_AT_external [DW_FORM_flag_present]   (true)
# INPUT-NEXT:    DW_AT_decl_file [DW_FORM_data1] ("/home/path/test.c")
# INPUT-NEXT:    DW_AT_decl_line [DW_FORM_data1] (1)
# INPUT-NEXT:    DW_AT_location [DW_FORM_exprloc]        (DW_OP_addr 0x0)
# INPUT:       DW_TAG_variable
# INPUT-NEXT:    DW_AT_name [DW_FORM_strp]       ( .debug_str[0x0000002f] = "bar")
# INPUT-NEXT:    DW_AT_type [DW_FORM_ref4]       (cu + 0x0033 => {0x00000033} "int")
# INPUT-NEXT:    DW_AT_external [DW_FORM_flag_present]   (true)
# INPUT-NEXT:    DW_AT_decl_file [DW_FORM_data1] ("/home/path/test.c")
# INPUT-NEXT:    DW_AT_decl_line [DW_FORM_data1] (2)
# INPUT-NEXT:    DW_AT_location [DW_FORM_exprloc]        (DW_OP_addr 0x0)

## Check we use information from .debug_info in messages.
# RUN: not ld.lld %t.o %t.o -o /dev/null 2>&1 | FileCheck %s
# CHECK:      duplicate symbol: bar
# CHECK-NEXT: >>> defined at test.c:2
# CHECK-NEXT: >>>            {{.*}}:(bar)
# CHECK-NEXT: >>> defined at test.c:2
# CHECK-NEXT: >>>            {{.*}}:(.data+0x0)
# CHECK:      duplicate symbol: foo
# CHECK-NEXT: >>> defined at test.c:1
# CHECK-NEXT: >>>            {{.*}}:(foo)
# CHECK-NEXT: >>> defined at test.c:1
# CHECK-NEXT: >>>            {{.*}}:(.bss+0x0)

# Used reduced output from following code and clang
# version 6.0.0 (trunk 316661) to produce this input file:
# Source (test.c):
#  int foo = 0;
#  int bar = 1;
# Invocation: clang -g -S test.c

.text
.file  "test.c"
.file  1 "test.c"

.type  foo,@object
.bss
.globl  foo
.p2align  2
foo:
 .long  0
 .size  foo, 4

.type  bar,@object
.data
.globl  bar
.p2align  2
bar:
 .long  1
 .size  bar, 4

.section  .debug_str,"MS",@progbits,1
.Linfo_string0:
  .asciz  "clang version 6.0.0"
.Linfo_string1:
  .asciz  "test.c"
.Linfo_string2:
  .asciz  "/home/path/"
.Linfo_string3:
  .asciz  "foo"
.Linfo_string4:
  .asciz  "int"
.Linfo_string5:
  .asciz  "bar"

.section  .debug_abbrev,"",@progbits
  .byte  1                       # Abbreviation Code
  .byte  17                      # DW_TAG_compile_unit
  .byte  1                       # DW_CHILDREN_yes
  .byte  37                      # DW_AT_producer
  .byte  14                      # DW_FORM_strp
  .byte  19                      # DW_AT_language
  .byte  5                       # DW_FORM_data2
  .byte  3                       # DW_AT_name
  .byte  14                      # DW_FORM_strp
  .byte  16                      # DW_AT_stmt_list
  .byte  23                      # DW_FORM_sec_offset
  .byte  27                      # DW_AT_comp_dir
  .byte  14                      # DW_FORM_strp
  .ascii  "\264B"                # DW_AT_GNU_pubnames
  .byte  25                      # DW_FORM_flag_present
  .byte  0                       # EOM(1)
  .byte  0                       # EOM(2)

  .byte  2                       # Abbreviation Code
  .byte  52                      # DW_TAG_variable
  .byte  0                       # DW_CHILDREN_no
  .byte  3                       # DW_AT_name
  .byte  14                      # DW_FORM_strp
  .byte  73                      # DW_AT_type
  .byte  19                      # DW_FORM_ref4
  .byte  63                      # DW_AT_external
  .byte  25                      # DW_FORM_flag_present
  .byte  58                      # DW_AT_decl_file
  .byte  11                      # DW_FORM_data1
  .byte  59                      # DW_AT_decl_line
  .byte  11                      # DW_FORM_data1
  .byte  2                       # DW_AT_location
  .byte  24                      # DW_FORM_exprloc
  .byte  0                       # EOM(1)
  .byte  0                       # EOM(2)

  .byte  3                       # Abbreviation Code
  .byte  36                      # DW_TAG_base_type
  .byte  0                       # DW_CHILDREN_no
  .byte  3                       # DW_AT_name
  .byte  14                      # DW_FORM_strp
  .byte  62                      # DW_AT_encoding
  .byte  11                      # DW_FORM_data1
  .byte  11                      # DW_AT_byte_size
  .byte  11                      # DW_FORM_data1
  .byte  0                       # EOM(1)
  .byte  0                       # EOM(2)
  .byte  0                       # EOM(3)

.section  .debug_info,"",@progbits
.Lcu_begin0:
  .long  76                      # Length of Unit
  .short  4                      # DWARF version number
  .long  .debug_abbrev           # Offset Into Abbrev. Section
  .byte  8                       # Address Size (in bytes)

  .byte  1                       # Abbrev [1] 0xb:0x45 DW_TAG_compile_unit
  .long  .Linfo_string0          # DW_AT_producer
  .short  12                     # DW_AT_language
  .long  .Linfo_string1          # DW_AT_name
  .long  0                       # DW_AT_stmt_list
  .long  .Linfo_string2          # DW_AT_comp_dir

  .byte  2                       # Abbrev [2] 0x1e:0x15 DW_TAG_variable
  .long  .Linfo_string3          # DW_AT_name
  .long  51                      # DW_AT_type
  .byte  1                       # DW_AT_decl_file
  .byte  1                       # DW_AT_decl_line
  .byte  9                       # DW_AT_location
  .byte  3
  .quad  foo

  .byte  3                       # Abbrev [3] 0x33:0x7 DW_TAG_base_type
  .long  .Linfo_string4          # DW_AT_name
  .byte  5                       # DW_AT_encoding
  .byte  4                       # DW_AT_byte_size

  .byte  2                       # Abbrev [2] 0x3a:0x15 DW_TAG_variable
  .long  .Linfo_string5          # DW_AT_name
  .long  51                      # DW_AT_type
  .byte  1                       # DW_AT_decl_file
  .byte  2                       # DW_AT_decl_line
  .byte  9                       # DW_AT_location
  .byte  3
  .quad  bar
  .byte  0                       # End Of Children Mark
