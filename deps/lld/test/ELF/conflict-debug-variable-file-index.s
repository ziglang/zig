# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: not ld.lld %t.o %t.o -o %t 2>&1 | FileCheck %s

## Check we are able to report errors even if DW_AT_decl_file
## contains invalid file name index.
## We did not try to support this intentionally but have
## an error handling and reporting logic that can take care
## of that and hence needs a test. 

# CHECK:      duplicate symbol: foo
# CHECK-NEXT: >>> defined at {{.*}}.o:(foo)
# CHECK-NEXT: >>>            {{.*}}.o:(.bss+0x0)

# Used modified output from the following code and gcc 7.1.0:
# Source (1.c):
#  int foo = 0;
# Invocation: g++ -g -S 1.c

.bss
.globl  foo
.type  foo, @object
.size  foo, 4
foo:

.text
.file 1 "1.c"

.section  .debug_info,"",@progbits
  .long  0x35            # Compile Unit: length = 0x0000004b)
  .value  0x4            # version = 0x0004
  .long  0               # abbr_offset = 0x0
  .byte  0x8             # addr_size = 0x08

  .uleb128 0x1           # DW_TAG_compile_unit [1] *
  .long  0               # DW_AT_producer [DW_FORM_strp]  ( .debug_str[0x00000000] = )
  .byte  0x4             # DW_AT_language [DW_FORM_data1]  (DW_LANG_C_plus_plus)
  .string  "1.c"         # DW_AT_name [DW_FORM_string]  ("1.c")
  .long  0               # DW_AT_comp_dir [DW_FORM_strp]  ( .debug_str[0x00000000] = )
  .long  0               # DW_AT_stmt_list [DW_FORM_sec_offset]  (0x00000000)

  .uleb128 0x2           # DW_TAG_variable [2]
  .string  "foo"         # DW_AT_name [DW_FORM_string]  ("foo")
  .byte  0xFE            # DW_AT_decl_file [DW_FORM_data1]  <broken file>
  .byte  0x1             # DW_AT_decl_line [DW_FORM_data1]  (1)
  .long  0x32            # DW_AT_type [DW_FORM_ref4]  (cu + 0x0032 => {0x00000032})
  .uleb128 0x9           # DW_AT_external [DW_FORM_flag_present]  (true)
  .byte  0x3
  .quad  foo             # DW_AT_location [DW_FORM_exprloc]  (DW_OP_addr 0x0)

  .uleb128 0x3           # DW_TAG_base_type [3]
  .byte  0x4             # DW_AT_byte_size [DW_FORM_data1]  (0x04)
  .byte  0x5             # DW_AT_encoding [DW_FORM_data1]  (DW_ATE_signed)
  .string  "int"         # DW_AT_name [DW_FORM_string]  ("int")

.section  .debug_abbrev,"",@progbits
  .uleb128 0x1   # Abbreviation code.
  .uleb128 0x11  # DW_TAG_compile_unit

  .byte  0x1     # ID
  .uleb128 0x25  # DW_AT_producer, DW_FORM_strp
  .uleb128 0xe
  .uleb128 0x13  # DW_AT_language, DW_FORM_data1
  .uleb128 0xb
  .uleb128 0x3   # DW_AT_name, DW_FORM_string
  .uleb128 0x8
  .uleb128 0x1b  # DW_AT_comp_dir, DW_FORM_strp
  .uleb128 0xe
  .uleb128 0x10  # DW_AT_stmt_list, DW_FORM_sec_offset
  .uleb128 0x17
  .byte  0
  .byte  0

  .uleb128 0x2  # ID
  .uleb128 0x34 # DW_TAG_variable, DW_CHILDREN_no
  .byte  0
  .uleb128 0x3  # DW_AT_name, DW_FORM_string
  .uleb128 0x8
  .uleb128 0x3a # DW_AT_decl_file, DW_FORM_data1
  .uleb128 0xb
  .uleb128 0x3b # DW_AT_decl_line, DW_FORM_data1
  .uleb128 0xb
  .uleb128 0x49 # DW_AT_type, DW_FORM_ref4
  .uleb128 0x13
  .uleb128 0x3f # DW_AT_external, DW_FORM_flag_present
  .uleb128 0x19
  .uleb128 0x2  # DW_AT_location, DW_FORM_exprloc
  .uleb128 0x18
  .byte  0
  .byte  0

  .uleb128 0x3  # ID
  .uleb128 0x24 # DW_TAG_base_type, DW_CHILDREN_no
  .byte  0
  .uleb128 0xb  # DW_AT_byte_size, DW_FORM_data1
  .uleb128 0xb
  .uleb128 0x3e # DW_AT_encoding, DW_FORM_data1
  .uleb128 0xb
  .uleb128 0x3  # DW_AT_name, DW_FORM_string
  .uleb128 0x8
  .byte  0
  .byte  0
  .byte  0
