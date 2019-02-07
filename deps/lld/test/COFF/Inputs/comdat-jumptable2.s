        .section .text@comdatfunc, "x"
        .linkonce discard
        .globl comdatfunc
comdatfunc:
        leaq .Ljumptable(%rip), %rax
        movslq (%rax, %rcx, 4), %rcx
        addq %rcx, %rax
        jmp *%rax

        .section .rdata, "dr"
        .long 0xcccccccc
.Ljumptable:
        .long .Ltail1-.Ljumptable
        .long .Ltail2-.Ljumptable
        .long .Ltail3-.Ljumptable
        .long 0xdddddddd

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
        .globl otherfunc
otherfunc:
        call comdatfunc
        ret
