# REQUIRES: x86
# RUN: llvm-mc -triple i686-windows-msvc %s -filetype=obj -o %t.obj
# RUN: lld-link %t.obj %S/Inputs/except_handler3.lib -safeseh -out:%t.exe -opt:noref -entry:main
# RUN: llvm-readobj --coff-load-config %t.exe | FileCheck %s

# CHECK: SEHTable [
# CHECK-NEXT: 0x
# CHECK-NEXT: ]

        .def     @feat.00;
        .scl    3;
        .type   0;
        .endef
        .globl  @feat.00
@feat.00 = 1

        .def     _main;
        .scl    2;
        .type   32;
        .endef
        .section        .text,"xr",one_only,_main
        .globl  _main
_main:
        movl $42, %eax
        ret

.safeseh __except_handler3

	.section .rdata,"dr"
.globl __load_config_used
__load_config_used:
        .long 72
        .fill 60, 1, 0
        .long ___safe_se_handler_table
        .long ___safe_se_handler_count
