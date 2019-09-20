# REQUIRES: x86, zlib
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t1.o
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %p/Inputs/gdb-index.s -o %t2.o
# RUN: ld.lld --gdb-index %t1.o %t2.o -o %t

# RUN: llvm-objdump -d %t | FileCheck %s --check-prefix=DISASM
# RUN: llvm-dwarfdump -gdb-index %t | FileCheck %s --check-prefix=DWARF
# RUN: llvm-readelf -sections %t | FileCheck %s --check-prefix=SECTION

# RUN: llvm-mc -compress-debug-sections=zlib-gnu -filetype=obj -triple=x86_64-pc-linux \
# RUN:   %p/Inputs/gdb-index.s -o %t2.o
# RUN: ld.lld --gdb-index %t1.o %t2.o -o %t

# RUN: llvm-objdump -d %t | FileCheck %s --check-prefix=DISASM
# RUN: llvm-dwarfdump -gdb-index %t | FileCheck %s --check-prefix=DWARF
# RUN: llvm-readelf -sections %t | FileCheck %s --check-prefix=SECTION

# DISASM:       Disassembly of section .text:
# DISASM-EMPTY:
# DISASM:       entrypoint:
# DISASM-CHECK:   201000: 90 nop
# DISASM-CHECK:   201001: cc int3
# DISASM-CHECK:   201002: cc int3
# DISASM-CHECK:   201003: cc int3
# DISASM:       aaaaaaaaaaaaaaaa:
# DISASM-CHECK:   201004: 90 nop
# DISASM-CHECK:   201005: 90 nop

# DWARF:      .gdb_index contents:
# DWARF-NEXT:    Version = 7
# DWARF:       CU list offset = 0x18, has 2 entries:
# DWARF-NEXT:    0: Offset = 0x0, Length = 0x34
# DWARF-NEXT:    1: Offset = 0x34, Length = 0x34
# DWARF:       Address area offset = 0x38, has 2 entries:
# DWARF-NEXT:    Low/High address = [0x201000, 0x201001) (Size: 0x1), CU id = 0
# DWARF-NEXT:    Low/High address = [0x201004, 0x201006) (Size: 0x2), CU id = 1
# DWARF:       Symbol table offset = 0x60, size = 1024, filled slots:
# DWARF-NEXT:    512: Name offset = 0x1c, CU vector offset = 0x0
# DWARF-NEXT:      String name: aaaaaaaaaaaaaaaa, CU vector index: 0
# DWARF-NEXT:    754: Name offset = 0x38, CU vector offset = 0x10
# DWARF-NEXT:      String name: int, CU vector index: 2
# DWARF-NEXT:    822: Name offset = 0x2d, CU vector offset = 0x8
# DWARF-NEXT:      String name: entrypoint, CU vector index: 1
# DWARF:       Constant pool offset = 0x2060, has 3 CU vectors:
# DWARF-NEXT:    0(0x0): 0x30000001
# DWARF-NEXT:    1(0x8): 0x30000000
# DWARF-NEXT:    2(0x10): 0x90000000 0x90000001

# SECTION-NOT: debug_gnu_pubnames

# RUN: ld.lld --gdb-index --no-gdb-index %t1.o %t2.o -o %t2
# RUN: llvm-readobj --sections %t2 | FileCheck -check-prefix=NOGDB %s
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
