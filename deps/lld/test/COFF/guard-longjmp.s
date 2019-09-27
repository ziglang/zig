# REQUIRES: x86
# RUN: llvm-mc -triple x86_64-windows-msvc %s -filetype=obj -o %t.obj
# RUN: lld-link %t.obj -guard:cf -out:%t.exe -entry:main
# RUN: llvm-readobj --file-headers --coff-load-config %t.exe | FileCheck %s

# CHECK: ImageBase: 0x140000000
# CHECK: LoadConfig [
# CHECK:   SEHandlerTable: 0x0
# CHECK:   SEHandlerCount: 0
# CHECK:   GuardCFCheckFunction: 0x0
# CHECK:   GuardCFCheckDispatch: 0x0
# CHECK:   GuardCFFunctionTable: 0x14000{{.*}}
# CHECK:   GuardCFFunctionCount: 1
# CHECK:   GuardFlags: 0x10500
# CHECK:   GuardAddressTakenIatEntryTable: 0x0
# CHECK:   GuardAddressTakenIatEntryCount: 0
# CHECK:   GuardLongJumpTargetTable: 0x14000{{.*}}
# CHECK:   GuardLongJumpTargetCount: 1
# CHECK: ]
# CHECK:      GuardLJmpTable [
# CHECK-NEXT:   0x14000{{.*}}
# CHECK-NEXT: ]


# This assembly is reduced from C code like:
# #include <setjmp.h>
# jmp_buf buf;
# void g() { longjmp(buf, 1); }
# void f() {
#   if (setjmp(buf))
#     return;
#   g();
# }
# int main() { f(); }

# We need @feat.00 to have 0x800 to indicate /guard:cf.
        .def     @feat.00;
        .scl    3;
        .type   0;
        .endef
        .globl  @feat.00
@feat.00 = 0x801
        .def     f; .scl    2; .type   32; .endef
        .globl  f
f:
        pushq   %rbp
        subq    $32, %rsp
        leaq    32(%rsp), %rbp
        leaq    buf(%rip), %rcx
        leaq    -32(%rbp), %rdx
        callq   _setjmp
.Lljmp1:
        testl   %eax, %eax
        je      .LBB1_1
        addq    $32, %rsp
        popq    %rbp
        retq
.LBB1_1:                                # %if.end
        leaq    buf(%rip), %rcx
        movl    $1, %edx
        callq   longjmp
        ud2

        # Record the longjmp target.
        .section        .gljmp$y,"dr"
        .symidx .Lljmp1
        .text

        # Provide setjmp/longjmp stubs.
        .def     _setjmp; .scl    2; .type   32; .endef
        .globl  _setjmp
_setjmp:
        retq

        .def     longjmp; .scl    2; .type   32; .endef
        .globl  longjmp
longjmp:
        retq

        .def     main; .scl    2; .type   32; .endef
        .globl  main                    # -- Begin function main
main:                                   # @main
        subq    $40, %rsp
        callq   f
        xorl    %eax, %eax
        addq    $40, %rsp
        retq

        .comm   buf,256,4               # @buf

        .section .rdata,"dr"
.globl _load_config_used
_load_config_used:
        .long 256
        .fill 124, 1, 0
        .quad __guard_fids_table
        .quad __guard_fids_count
        .long __guard_flags
        .fill 12, 1, 0
        .quad __guard_iat_table
        .quad __guard_iat_count
        .quad __guard_longjmp_table
        .quad __guard_fids_count
        .fill 84, 1, 0
