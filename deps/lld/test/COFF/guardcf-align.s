# REQUIRES: x86
# RUN: llvm-mc -triple x86_64-windows-msvc -filetype=obj -o %t.obj %s
# RUN: yaml2obj < %p/Inputs/guardcf-align-foobar.yaml \
# RUN:     > %T/guardcf-align-foobar.obj
# RUN: lld-link -out:%T/guardcf-align.exe -entry:main -guard:cf \
# RUN:     %t.obj %T/guardcf-align-foobar.obj
# RUN: llvm-readobj --coff-load-config %T/guardcf-align.exe | FileCheck %s

# Check that the gfids table contains at least one entry that ends in 0
# and no entries that end in something other than 0.
# CHECK: GuardFidTable [
# CHECK-NOT: 0x{{[0-9A-Fa-f]+[^0]$}}
# CHECK: 0x{{[0-9A-Fa-f]+0$}}
# CHECK-NOT: 0x{{[0-9A-Fa-f]+[^0]$}}
# CHECK: ]

# @feat.00 and _load_config_used to indicate we have gfids.
        .def     @feat.00;
        .scl    3;
        .type   0;
        .endef
        .globl  @feat.00
@feat.00 = 0x801

        .section .rdata,"dr"
.globl _load_config_used
_load_config_used:
        .long 256
        .fill 124, 1, 0
        .quad __guard_fids_table
        .quad __guard_fids_count
        .long __guard_flags
        .fill 128, 1, 0

# Functions that are called indirectly.
        .section        .gfids$y,"dr"
        .symidx foo


        .section .text,"rx"
        .global main
main:
        movq foo, %rcx
        xorq %rax, %rax
        callq bar
        retq
