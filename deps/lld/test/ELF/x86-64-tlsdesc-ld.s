# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64 %s -o %t.o

# RUN: ld.lld -shared %t.o -o %t.so
# RUN: llvm-readobj -r %t.so | FileCheck --check-prefix=LD-REL %s
# RUN: llvm-objdump -d --no-show-raw-insn %t.so | FileCheck --check-prefix=LD %s

# RUN: ld.lld %t.o -o %t
# RUN: llvm-readelf -r %t | FileCheck --check-prefix=NOREL %s
# RUN: llvm-objdump -d --no-show-raw-insn %t | FileCheck --check-prefix=LE %s

## Check _TLS_MODULE_BASE_ used by LD produces a dynamic relocation with a value of 0.
# LD-REL:      .rela.dyn {
# LD-REL-NEXT:   0x20A0 R_X86_64_TLSDESC - 0x0
# LD-REL-NEXT: }

## 0x20a0-0x1007 = 4249
## dtpoff(a) = 8, dtpoff(b) = 12
# LD:            leaq 4249(%rip), %rax
# LD-NEXT: 1007: callq *(%rax)
# LD-NEXT:       movl %fs:8(%rax), %edx
# LD-NEXT:       addl %fs:12(%rax), %edx

## When producing an executable, the LD code sequence can be relaxed to LE.
## It is the same as GD->LE.
## tpoff(_TLS_MODULE_BASE_) = 0, tpoff(a) = -8, tpoff(b) = -4

# NOREL: no relocations

# LE:      movq $0, %rax
# LE-NEXT: nop
# LE-NEXT: movl %fs:-8(%rax), %edx
# LE-NEXT: addl %fs:-4(%rax), %edx

leaq _TLS_MODULE_BASE_@tlsdesc(%rip), %rax
call *_TLS_MODULE_BASE_@tlscall(%rax)
movl %fs:a@dtpoff(%rax), %edx
addl %fs:b@dtpoff(%rax), %edx

.section .tbss
.zero 8
a:
.zero 4
b:
.zero 4
