# Check MIPS TLS relocations handling.

# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux \
# RUN:         %p/Inputs/mips-tls.s -o %t.so.o
# RUN: ld.lld -shared %t.so.o -o %t.so
# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux %s -o %t.o

# RUN: ld.lld %t.o %t.so -o %t.exe
# RUN: llvm-objdump -d -s -t %t.exe | FileCheck -check-prefix=DIS %s
# RUN: llvm-readobj -r -mips-plt-got %t.exe | FileCheck %s

# RUN: ld.lld -shared %t.o %t.so -o %t-out.so
# RUN: llvm-objdump -d -s -t %t-out.so | FileCheck -check-prefix=DIS-SO %s
# RUN: llvm-readobj -r -mips-plt-got %t-out.so | FileCheck -check-prefix=SO %s

# REQUIRES: mips

# DIS:      __start:
# DIS-NEXT:    20000:   24 62 80 18   addiu   $2, $3, -32744
# DIS-NEXT:    20004:   24 62 80 20   addiu   $2, $3, -32736
# DIS-NEXT:    20008:   24 62 80 24   addiu   $2, $3, -32732
# DIS-NEXT:    2000c:   24 62 80 2c   addiu   $2, $3, -32724
# DIS-NEXT:    20010:   24 62 80 34   addiu   $2, $3, -32716

# DIS:      Contents of section .got:
# DIS-NEXT:  30010 00000000 80000000 00000000 00000000
# DIS-NEXT:  30020 00000000 00000001 00000000 00000001
# DIS-NEXT:  30030 ffff8004 ffff9004

# DIS: 00000000 l       .tdata          00000000 loc
# DIS: 00000004 g       .tdata          00000000 bar
# DIS: 00000000 g       *UND*           00000000 foo

# CHECK:      Relocations [
# CHECK-NEXT:   Section (7) .rel.dyn {
# CHECK-NEXT:     0x30018 R_MIPS_TLS_DTPMOD32 foo 0x0
# CHECK-NEXT:     0x3001C R_MIPS_TLS_DTPREL32 foo 0x0
# CHECK-NEXT:     0x30020 R_MIPS_TLS_TPREL32 foo 0x0
# CHECK-NEXT:   }
# CHECK-NEXT: ]
# CHECK-NEXT: Primary GOT {
# CHECK-NEXT:   Canonical gp value: 0x38000
# CHECK-NEXT:   Reserved entries [
# CHECK:        ]
# CHECK-NEXT:   Local entries [
# CHECK-NEXT:   ]
# CHECK-NEXT:   Global entries [
# CHECK-NEXT:   ]
# CHECK-NEXT:   Number of TLS and multi-GOT entries: 8
#               ^-- -32744 R_MIPS_TLS_GD       R_MIPS_TLS_DTPMOD32 foo
#               ^-- -32740                     R_MIPS_TLS_DTPREL32 foo
#               ^-- -32736 R_MIPS_TLS_GOTTPREL R_MIPS_TLS_TPREL32  foo
#               ^-- -32732 R_MIPS_TLS_LDM      1 loc
#               ^-- -32728                     0 loc
#               ^-- -32724 R_MIPS_TLS_GD       1 bar
#               ^-- -32720                     VA - 0x8000 bar
#               ^-- -32716 R_MIPS_TLS_GOTTPREL VA - 0x7000 bar

# DIS-SO:      Contents of section .got:
# DIS-SO-NEXT:  20000 00000000 80000000 00000000 00000000
# DIS-SO-NEXT:  20010 00000000 00000000 00000000 00000000
# DIS-SO-NEXT:  20020 00000000 00000000

# SO:      Relocations [
# SO-NEXT:   Section (7) .rel.dyn {
# SO-NEXT:     0x20014 R_MIPS_TLS_DTPMOD32 - 0x0
# SO-NEXT:     0x2001C R_MIPS_TLS_DTPMOD32 bar 0x0
# SO-NEXT:     0x20020 R_MIPS_TLS_DTPREL32 bar 0x0
# SO-NEXT:     0x20024 R_MIPS_TLS_TPREL32 bar 0x0
# SO-NEXT:     0x20008 R_MIPS_TLS_DTPMOD32 foo 0x0
# SO-NEXT:     0x2000C R_MIPS_TLS_DTPREL32 foo 0x0
# SO-NEXT:     0x20010 R_MIPS_TLS_TPREL32 foo 0x0
# SO-NEXT:   }
# SO-NEXT: ]
# SO-NEXT: Primary GOT {
# SO-NEXT:   Canonical gp value: 0x27FF0
# SO-NEXT:   Reserved entries [
# SO:        ]
# SO-NEXT:   Local entries [
# SO-NEXT:   ]
# SO-NEXT:   Global entries [
# SO-NEXT:   ]
# SO-NEXT:   Number of TLS and multi-GOT entries: 8
#            ^-- -32744 R_MIPS_TLS_GD       R_MIPS_TLS_DTPMOD32 foo
#            ^-- -32740 R_MIPS_TLS_DTPREL32 foo
#            ^-- -32736 R_MIPS_TLS_GOTTPREL R_MIPS_TLS_TPREL32  foo
#            ^-- -32732 R_MIPS_TLS_LDM      R_MIPS_TLS_DTPMOD32 loc
#            ^-- -32728 0 loc
#            ^-- -32724 R_MIPS_TLS_GD       R_MIPS_TLS_DTPMOD32 bar
#            ^-- -32720 R_MIPS_TLS_DTPREL32 bar
#            ^-- -32716 R_MIPS_TLS_GOTTPREL R_MIPS_TLS_TPREL32  bar

  .text
  .global  __start
__start:
  addiu $2, $3, %tlsgd(foo)     # R_MIPS_TLS_GD
  addiu $2, $3, %gottprel(foo)  # R_MIPS_TLS_GOTTPREL
  addiu $2, $3, %tlsldm(loc)    # R_MIPS_TLS_LDM
  addiu $2, $3, %tlsgd(bar)     # R_MIPS_TLS_GD
  addiu $2, $3, %gottprel(bar)  # R_MIPS_TLS_GOTTPREL

 .section .tdata,"awT",%progbits
 .global bar
loc:
 .word 0
bar:
 .word 0
