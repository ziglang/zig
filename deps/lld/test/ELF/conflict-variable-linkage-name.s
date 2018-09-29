# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: not ld.lld %t.o %t.o -o /dev/null 2>&1 | FileCheck %s

## Check we can report the locations of 2 different "bar" variables.
# CHECK:      duplicate symbol: A::bar
# CHECK-NEXT: >>> defined at 1.cpp:2
# CHECK-NEXT: >>>            {{.*}}:(A::bar)
# CHECK-NEXT: >>> defined at 1.cpp:2
# CHECK-NEXT: >>>            {{.*}}:(.bss+0x0)
# CHECK:      duplicate symbol: Z::bar
# CHECK-NEXT: >>> defined at 1.cpp:6
# CHECK-NEXT: >>>            {{.*}}:(Z::bar)
# CHECK-NEXT: >>> defined at 1.cpp:6
# CHECK-NEXT: >>>            {{.*}}:(.data+0x0)

# Used reduced output from following code and clang version 7.0.0 (trunk 332701)
# to produce this input file:
# Source (1.cpp):
#  namespace A {
#    int bar;
#  }
#  
#  namespace Z {
#    int bar;
#  }
# Invocation: clang-7 -g -S 1.cpp

.text
.file  "1.cpp"
.file  1 "/path" "1.cpp"

.type  _ZN1A3barE,@object
.bss
.globl  _ZN1A3barE
_ZN1A3barE:
  .long  0
  .size  _ZN1A3barE, 4

.type  _ZN1Z3barE,@object
.data
.globl  _ZN1Z3barE
_ZN1Z3barE:
  .long  1
  .size  _ZN1Z3barE, 4

.section  .debug_str,"MS",@progbits,1
.Linfo_string0:
  .asciz  "clang version 7.0.0 (trunk 332701)" # string offset=0
.Linfo_string1:
  .asciz  "1.cpp"                 # string offset=35
.Linfo_string2:
  .asciz  "/path"                 # string offset=41
.Linfo_string3:
  .asciz  "A"                     # string offset=87
.Linfo_string4:
  .asciz  "bar"                   # string offset=89
.Linfo_string5:
  .asciz  "int"                   # string offset=93
.Linfo_string6:
  .asciz  "_ZN1A3barE"            # string offset=97
.Linfo_string7:
  .asciz  "Z"                     # string offset=108
.Linfo_string8:
  .asciz  "_ZN1Z3barE"            # string offset=110

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
  .byte  57                      # DW_TAG_namespace
  .byte  1                       # DW_CHILDREN_yes
  .byte  3                       # DW_AT_name
  .byte  14                      # DW_FORM_strp
  .byte  0                       # EOM(1)
  .byte  0                       # EOM(2)
  
  .byte  3                       # Abbreviation Code
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
  .byte  110                     # DW_AT_linkage_name
  .byte  14                      # DW_FORM_strp
  .byte  0                       # EOM(1)
  .byte  0                       # EOM(2)
  
  .byte  4                       # Abbreviation Code
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
  .long  96                      # Length of Unit
  .short  4                      # DWARF version number
  .long  .debug_abbrev           # Offset Into Abbrev. Section
  .byte  8                       # Address Size (in bytes)
  
  .byte  1                       # Abbrev [1] 0xb:0x59 DW_TAG_compile_unit
  .long  .Linfo_string0          # DW_AT_producer
  .short  4                      # DW_AT_language
  .long  .Linfo_string1          # DW_AT_name
  .long  0                       # DW_AT_stmt_list
  .long  .Linfo_string2          # DW_AT_comp_dir
                                 # DW_AT_GNU_pubnames

  .byte  2                       # Abbrev [2] 0x1e:0x1f DW_TAG_namespace
  .long  .Linfo_string3          # DW_AT_name
  
  .byte  3                       # Abbrev [3] 0x23:0x19 DW_TAG_variable
  .long  .Linfo_string4          # DW_AT_name
  .long  61                      # DW_AT_type
                                 # DW_AT_external
  .byte  1                       # DW_AT_decl_file
  .byte  2                       # DW_AT_decl_line
  .byte  9                       # DW_AT_location
  .byte  3
  .quad  _ZN1A3barE
  .long  .Linfo_string6          # DW_AT_linkage_name
  .byte  0                       # End Of Children Mark
  
  .byte  4                       # Abbrev [4] 0x3d:0x7 DW_TAG_base_type
  .long  .Linfo_string5          # DW_AT_name
  .byte  5                       # DW_AT_encoding
  .byte  4                       # DW_AT_byte_size
  
  .byte  2                       # Abbrev [2] 0x44:0x1f DW_TAG_namespace
  .long  .Linfo_string7          # DW_AT_name
  
  .byte  3                       # Abbrev [3] 0x49:0x19 DW_TAG_variable
  .long  .Linfo_string4          # DW_AT_name
  .long  61                      # DW_AT_type
                                 # DW_AT_external
  .byte  1                       # DW_AT_decl_file
  .byte  6                       # DW_AT_decl_line
  .byte  9                       # DW_AT_location
  .byte  3
  .quad  _ZN1Z3barE
  .long  .Linfo_string8          # DW_AT_linkage_name
  
  .byte  0                       # End Of Children Mark
  .byte  0                       # End Of Children Mark
