# REQUIRES: mips
# Check MIPS TLS 64-bit relocations handling.

# RUN: llvm-mc -filetype=obj -triple=mips64-unknown-linux \
# RUN:         %p/Inputs/mips-tls.s -o %t.so.o
# RUN: ld.lld -shared %t.so.o -o %t.so
# RUN: llvm-mc -filetype=obj -triple=mips64-unknown-linux %s -o %t.o

# RUN: ld.lld %t.o %t.so -o %t.exe
# RUN: llvm-objdump -d -s -t %t.exe | FileCheck -check-prefix=DIS %s
# RUN: llvm-readobj -r -mips-plt-got %t.exe | FileCheck %s

# RUN: ld.lld -shared %t.o %t.so -o %t-out.so
# RUN: llvm-objdump -d -s -t %t-out.so | FileCheck -check-prefix=DIS-SO %s
# RUN: llvm-readobj -r -mips-plt-got %t-out.so | FileCheck -check-prefix=SO %s

# DIS:      __start:
# DIS-NEXT:    20000:   24 62 80 30   addiu   $2, $3, -32720
# DIS-NEXT:    20004:   24 62 80 20   addiu   $2, $3, -32736
# DIS-NEXT:    20008:   24 62 80 40   addiu   $2, $3, -32704
# DIS-NEXT:    2000c:   24 62 80 50   addiu   $2, $3, -32688
# DIS-NEXT:    20010:   24 62 80 28   addiu   $2, $3, -32728

# DIS:      Contents of section .got:
# DIS-NEXT:  30010 00000000 00000000 80000000 00000000
# DIS-NEXT:  30020 00000000 00000000 ffffffff ffff9004
# DIS-NEXT:  30030 00000000 00000000 00000000 00000000
# DIS-NEXT:  30040 00000000 00000001 00000000 00000000
# DIS-NEXT:  30050 00000000 00000001 ffffffff ffff8004

# DIS: 0000000000000000 l     O .tdata          00000000 loc
# DIS: 0000000000000004 g     O .tdata          00000000 bar
# DIS: 0000000000000000 g     O *UND*           00000000 foo

# CHECK:      Relocations [
# CHECK-NEXT:   Section (7) .rel.dyn {
# CHECK-NEXT:     0x30020 R_MIPS_TLS_TPREL64/R_MIPS_NONE/R_MIPS_NONE foo 0x0
# CHECK-NEXT:     0x30030 R_MIPS_TLS_DTPMOD64/R_MIPS_NONE/R_MIPS_NONE foo 0x0
# CHECK-NEXT:     0x30038 R_MIPS_TLS_DTPREL64/R_MIPS_NONE/R_MIPS_NONE foo 0x0
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
#               ^-- -32736 R_MIPS_TLS_GOTTPREL R_MIPS_TLS_TPREL64  foo
#               ^-- -32728 R_MIPS_TLS_GOTTPREL VA - 0x7000 bar
#               ^-- -32720 R_MIPS_TLS_GD       R_MIPS_TLS_DTPMOD64 foo
#               ^-- -32712                     R_MIPS_TLS_DTPREL64 foo
#               ^-- -32704 R_MIPS_TLS_LDM      1 loc
#               ^-- -32696                     0 loc
#               ^-- -32688 R_MIPS_TLS_GD       1 bar
#               ^-- -32680                     VA - 0x8000 bar

# DIS-SO:      Contents of section .got:
# DIS-SO-NEXT:  20000 00000000 00000000 80000000 00000000
# DIS-SO-NEXT:  20010 00000000 00000000 00000000 00000004
# DIS-SO-NEXT:  20020 00000000 00000000 00000000 00000000
# DIS-SO-NEXT:  20030 00000000 00000000 00000000 00000000
# DIS-SO-NEXT:  20040 00000000 00000000 00000000 00000000

# SO:      Relocations [
# SO-NEXT:   Section (7) .rel.dyn {
# SO-NEXT:     0x20030 R_MIPS_TLS_DTPMOD64/R_MIPS_NONE/R_MIPS_NONE - 0x0
# SO-NEXT:     0x20018 R_MIPS_TLS_TPREL64/R_MIPS_NONE/R_MIPS_NONE bar 0x0
# SO-NEXT:     0x20040 R_MIPS_TLS_DTPMOD64/R_MIPS_NONE/R_MIPS_NONE bar 0x0
# SO-NEXT:     0x20048 R_MIPS_TLS_DTPREL64/R_MIPS_NONE/R_MIPS_NONE bar 0x0
# SO-NEXT:     0x20010 R_MIPS_TLS_TPREL64/R_MIPS_NONE/R_MIPS_NONE foo 0x0
# SO-NEXT:     0x20020 R_MIPS_TLS_DTPMOD64/R_MIPS_NONE/R_MIPS_NONE foo 0x0
# SO-NEXT:     0x20028 R_MIPS_TLS_DTPREL64/R_MIPS_NONE/R_MIPS_NONE foo 0x0
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
#            ^-- -32736 R_MIPS_TLS_GOTTPREL R_MIPS_TLS_TPREL64  foo
#            ^-- -32728 R_MIPS_TLS_GOTTPREL R_MIPS_TLS_TPREL64  bar
#            ^-- -32720 R_MIPS_TLS_GD       R_MIPS_TLS_DTPMOD64 foo
#            ^-- -32712                     R_MIPS_TLS_DTPREL64 foo
#            ^-- -32704 R_MIPS_TLS_LDM      R_MIPS_TLS_DTPMOD64 loc
#            ^-- -32696                     0 loc
#            ^-- -32688 R_MIPS_TLS_GD       R_MIPS_TLS_DTPMOD64 bar
#            ^-- -32680                     R_MIPS_TLS_DTPREL64 bar

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
