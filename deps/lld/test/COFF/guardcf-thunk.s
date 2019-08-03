# REQUIRES: x86

# Make a DLL that exports exportfn1.
# RUN: yaml2obj < %p/Inputs/export.yaml > %t.obj
# RUN: lld-link /out:%t.dll /dll %t.obj /export:exportfn1 /implib:%t.lib

# Make an obj that takes the address of that exported function.
# RUN: llvm-mc -filetype=obj -triple=x86_64-windows-msvc %s -o %t2.obj
# RUN: lld-link -entry:main -guard:cf %t2.obj %t.lib -nodefaultlib -out:%t.exe
# RUN: llvm-readobj --coff-load-config %t.exe | FileCheck %s

# Check that the gfids table contains *exactly* two entries, one for exportfn1
# and one for main.
# CHECK: GuardFidTable [
# CHECK-NEXT: 0x{{[0-9A-Fa-f]+0$}}
# CHECK-NEXT: 0x{{[0-9A-Fa-f]+0$}}
# CHECK-NEXT: ]


        .def     @feat.00;
        .scl    3;
        .type   0;
        .endef
        .globl  @feat.00
@feat.00 = 0x001

        .section .text,"rx"
        .def     main; .scl    2; .type   32; .endef
        .global main
main:
        leaq exportfn1(%rip), %rax
        retq

        .section .rdata,"dr"
.globl _load_config_used
_load_config_used:
        .long 256
        .fill 124, 1, 0
        .quad __guard_fids_table
        .quad __guard_fids_count
        .long __guard_flags
        .fill 128, 1, 0

