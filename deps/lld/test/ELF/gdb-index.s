# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t1.o
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %p/Inputs/gdb-index.s -o %t2.o
# RUN: ld.lld --gdb-index %t1.o %t2.o -o %t
# RUN: llvm-dwarfdump -gdb-index %t | FileCheck %s
# RUN: llvm-objdump -d %t | FileCheck %s --check-prefix=DISASM

# DISASM:       Disassembly of section .text:
# DISASM:       entrypoint:
# DISASM-CHECK:   201000: 90 nop
# DISASM-CHECK:   201001: cc int3
# DISASM-CHECK:   201002: cc int3
# DISASM-CHECK:   201003: cc int3
# DISASM:       main2:
# DISASM-CHECK:   201004: 90 nop
# DISASM-CHECK:   201005: 90 nop

# CHECK:      .gnu_index contents:
# CHECK-NEXT:    Version = 7
# CHECK:       CU list offset = 0x18, has 2 entries:
# CHECK-NEXT:    0: Offset = 0x0, Length = 0x34
# CHECK-NEXT:    1: Offset = 0x34, Length = 0x34
# CHECK:       Address area offset = 0x38, has 2 entries:
# CHECK-NEXT:    Low/High address = [0x201000, 0x201001) (Size: 0x1), CU id = 0
# CHECK-NEXT:    Low/High address = [0x201004, 0x201006) (Size: 0x2), CU id = 1
# CHECK:       Symbol table offset = 0x60, size = 1024, filled slots:
# CHECK-NEXT:    754: Name offset = 0x27, CU vector offset = 0x8
# CHECK-NEXT:	   String name: int, CU vector index: 1
# CHECK-NEXT:    822: Name offset = 0x1c, CU vector offset = 0x0
# CHECK-NEXT:	   String name: entrypoint, CU vector index: 0
# CHECK-NEXT:    956: Name offset = 0x2b, CU vector offset = 0x14
# CHECK-NEXT:      String name: main2, CU vector index: 2
# CHECK:       Constant pool offset = 0x2060, has 3 CU vectors:
# CHECK-NEXT:    0(0x0): 0x30000000
# CHECK-NEXT:    1(0x8): 0x90000000 0x90000001
# CHECK-NEXT:    2(0x14): 0x30000001

# RUN: ld.lld --gdb-index --no-gdb-index %t1.o %t2.o -o %t2
# RUN: llvm-readobj -sections %t2 | FileCheck -check-prefix=NOGDB %s
# NOGDB-NOT: Name: .gdb_index

## The following section contents are created by this using gcc 7.1.0:
## echo 'int entrypoint() { return 0; }' | gcc -gsplit-dwarf -xc++ -S -o- -

.text
.Ltext0:
.globl entrypoint
.type entrypoint, @function
entrypoint:
 nop
.Letext0:

.section .debug_info,"",@progbits
.long 0x30
.value 0x4
.long 0
.byte 0x8
.uleb128 0x1
.quad .Ltext0
.quad .Letext0-.Ltext0
.long 0
.long 0
.long 0
.long 0
.byte 0x63
.byte 0x88
.byte 0xb4
.byte 0x61
.byte 0xaa
.byte 0xb6
.byte 0xb0
.byte 0x67

.section .debug_abbrev,"",@progbits
.uleb128 0x1
.uleb128 0x11
.byte 0
.uleb128 0x11
.uleb128 0x1
.uleb128 0x12
.uleb128 0x7
.uleb128 0x10
.uleb128 0x17
.uleb128 0x2130
.uleb128 0xe
.uleb128 0x1b
.uleb128 0xe
.uleb128 0x2134
.uleb128 0x19
.uleb128 0x2133
.uleb128 0x17
.uleb128 0x2131
.uleb128 0x7
.byte 0
.byte 0
.byte 0

.section .debug_gnu_pubnames,"",@progbits
.long 0x18
.value 0x2
.long 0
.long 0x33
.long 0x18
.byte 0x30
.string "entrypoint"
.long 0

.section .debug_gnu_pubtypes,"",@progbits
.long 0x17
.value 0x2
.long 0
.long 0x33
.long 0x2b
.byte 0x90
.string "int"
.long 0
