# REQUIRES: x86
# RUN: llvm-mc -triple=x86_64-windows-gnu %s -filetype=obj -o %t1.obj
# RUN: llvm-mc -triple=x86_64-windows-gnu %S/Inputs/comdat-jumptable2.s -filetype=obj -o %t2.obj

# RUN: llvm-objdump -s %t1.obj | FileCheck --check-prefix=OBJ1 %s
# RUN: llvm-objdump -s %t2.obj | FileCheck --check-prefix=OBJ2 %s

# RUN: lld-link -lldmingw -entry:main %t1.obj %t2.obj -out:%t.exe
# RUN: llvm-objdump -s %t.exe | FileCheck --check-prefix=EXE %s

# Test linking cases where comdat functions have an associated jump table
# in a non-comdat rdata (which GCC produces for functions with jump tables).
# In these cases, ld.bfd keeps all rdata sections, but the relocations that
# refer to discarded comdat sections just are emitted as they were originally.

# In real scenarios, the jump table .rdata section should be identical across
# all object files; here it is different to illustrate more clearly what
# the linker actually does.

# OBJ1: Contents of section .rdata:
# OBJ1:  0000 aaaaaaaa 14000000 1e000000 28000000
# OBJ1:  0010 bbbbbbbb

# OBJ2: Contents of section .rdata:
# OBJ2:  0000 cccccccc 14000000 1e000000 28000000
# OBJ2:  0010 dddddddd

# EXE: Contents of section .rdata:
# EXE:  140002000 aaaaaaaa 0c100000 12100000 18100000
# EXE:  140002010 bbbbbbbb cccccccc 14000000 1e000000
# EXE:  140002020 28000000 dddddddd


        .section .text@comdatfunc, "x"
        .linkonce discard
        .globl comdatfunc
comdatfunc:
        leaq .Ljumptable(%rip), %rax
        movslq (%rax, %rcx, 4), %rcx
        addq %rcx, %rax
        jmp *%rax

        .section .rdata, "dr"
        .long 0xaaaaaaaa
.Ljumptable:
        .long .Ltail1-.Ljumptable
        .long .Ltail2-.Ljumptable
        .long .Ltail3-.Ljumptable
        .long 0xbbbbbbbb

        .section .text@comdatfunc, "x"
# If assembled with binutils, the following line can be kept in:
#       .linkonce discard
.Ltail1:
        movl $1, %eax
        ret
.Ltail2:
        movl $2, %eax
        ret
.Ltail3:
        movl $3, %eax
        ret


        .text
        .globl main
main:
        call comdatfunc
        call otherfunc
        ret
