# REQUIRES: x86,mips
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: echo "SECTIONS                \
# RUN:  {                            \
# RUN:    .foo : {                   \
# RUN:      *(.foo.1)                \
# RUN:      BYTE(0x11)               \
# RUN:      *(.foo.2)                \
# RUN:      SHORT(0x1122)            \
# RUN:      *(.foo.3)                \
# RUN:      LONG(0x11223344)         \
# RUN:      *(.foo.4)                \
# RUN:      QUAD(0x1122334455667788) \
# RUN:    }                          \
# RUN:    .bar : {                   \
# RUN:      *(.bar.1)                \
# RUN:      BYTE(a + 1)              \
# RUN:      *(.bar.2)                \
# RUN:      SHORT(b)                 \
# RUN:      *(.bar.3)                \
# RUN:      LONG(c + 2)              \
# RUN:      *(.bar.4)                \
# RUN:      QUAD(d)                  \
# RUN:    }                          \
# RUN:  }" > %t.script
# RUN: ld.lld -o %t %t.o --script %t.script
# RUN: llvm-objdump -s %t | FileCheck %s

# CHECK:      Contents of section .foo:
# CHECK-NEXT:   ff11ff22 11ff4433 2211ff88 77665544
# CHECK-NEXT:   332211

# CHECK:      Contents of section .bar:
# CHECK-NEXT:   ff12ff22 11ff4633 2211ff88 77665544
# CHECK-NEXT:   332211

# RUN: llvm-mc -filetype=obj -triple=mips64-unknown-linux %s -o %tmips64be
# RUN: ld.lld --script %t.script %tmips64be -o %t2
# RUN: llvm-objdump -s %t2 | FileCheck %s --check-prefix=BE
# BE:      Contents of section .foo:
# BE-NEXT:   ff11ff11 22ff1122 3344ff11 22334455
# BE-NEXT:   667788
# BE-NEXT: Contents of section .bar:
# BE-NEXT:   ff12ff11 22ff1122 3346ff11 22334455
# BE-NEXT:   667788

# RUN: echo "MEMORY {                \
# RUN:     rom (rwx) : ORIGIN = 0x00, LENGTH = 2K \
# RUN:  }                            \
# RUN:  SECTIONS {                   \
# RUN:    .foo : {                   \
# RUN:      *(.foo.1)                \
# RUN:      BYTE(0x11)               \
# RUN:      *(.foo.2)                \
# RUN:      SHORT(0x1122)            \
# RUN:      *(.foo.3)                \
# RUN:      LONG(0x11223344)         \
# RUN:      *(.foo.4)                \
# RUN:      QUAD(0x1122334455667788) \
# RUN:    } > rom                    \
# RUN:    .bar : {                   \
# RUN:      *(.bar.1)                \
# RUN:      BYTE(a + 1)              \
# RUN:      *(.bar.2)                \
# RUN:      SHORT(b)                 \
# RUN:      *(.bar.3)                \
# RUN:      LONG(c + 2)              \
# RUN:      *(.bar.4)                \
# RUN:      QUAD(d)                  \
# RUN:    } > rom                    \
# RUN:  }" > %t-memory.script
# RUN: ld.lld -o %t-memory %t.o --script %t-memory.script
# RUN: llvm-objdump -s %t-memory | FileCheck %s --check-prefix=MEM

# MEM:      Contents of section .foo:
# MEM-NEXT:   0000 ff11ff22 11ff4433 2211ff88 77665544
# MEM-NEXT:   0010 332211

# MEM:      Contents of section .bar:
# MEM-NEXT:   0013 ff12ff22 11ff4633 2211ff88 77665544
# MEM-NEXT:   0023 332211

.global a
a = 0x11

.global b
b = 0x1122

.global c
c = 0x11223344

.global d
d = 0x1122334455667788

.section .foo.1, "a"
 .byte 0xFF

.section .foo.2, "a"
 .byte 0xFF

.section .foo.3, "a"
 .byte 0xFF

.section .foo.4, "a"
 .byte 0xFF

.section .bar.1, "a"
 .byte 0xFF

.section .bar.2, "a"
 .byte 0xFF

.section .bar.3, "a"
 .byte 0xFF

.section .bar.4, "a"
 .byte 0xFF
