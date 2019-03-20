# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: ld.lld -z retpolineplt -z now %t.o -o %t
# RUN: llvm-objdump -d -no-show-raw-insn %t | FileCheck %s

#0x201001+5 + 42 = 0x201030 (foo@plt)
# CHECK:      _start:
# CHECK-NEXT:  201001:       callq   42

#Static IPLT header due to -z retpolineplt
# CHECK:       0000000000201010 .plt:
# CHECK-NEXT:  201010:       callq   11 <.plt+0x10>
# CHECK-NEXT:  201015:       pause
# CHECK-NEXT:  201017:       lfence
#foo@plt
# CHECK:       201030:       movq    4041(%rip), %r11
# CHECK-NEXT:  201037:       jmp     -44 <.plt>

.type foo STT_GNU_IFUNC
.globl foo
foo:
  ret

.globl _start
_start:
  call foo
