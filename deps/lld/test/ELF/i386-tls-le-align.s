# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=i386 %s -o %t.o
# RUN: ld.lld %t.o -o %t
# RUN: llvm-objdump -d --no-show-raw-insn --print-imm-hex %t | FileCheck %s

# -alignTo(p_memsz, p_align) = -alignTo(4, 64) = -64

# CHECK:      movl %gs:0xffffffc0, %eax
  movl %gs:a@NTPOFF, %eax

# CHECK-NEXT: subl $0x40, %edx
  subl $a@tpoff, %edx

# GD to LE relaxation.
# CHECK-NEXT: movl %gs:0x0, %eax
# CHECK-NEXT: subl $0x40, %eax
  leal a@tlsgd(,%ebx,1), %eax
  call ___tls_get_addr@plt
  ret

.globl ___tls_get_addr
.type ___tls_get_addr,@function
___tls_get_addr:

.section .tbss,"awT"
.align 64
a:
.long 0
.size a, 4
