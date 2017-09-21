# RUN: llvm-mc -triple i686-windows-msvc %s -filetype=obj -o %t.obj
# RUN: lld-link %t.obj -safeseh -out:%t.exe -opt:noref -entry:main
# RUN: llvm-readobj -coff-load-config %t.exe | FileCheck %s --check-prefix=CHECK-NOGC
# RUN: lld-link %t.obj -safeseh -out:%t.exe -opt:ref -entry:main
# RUN: llvm-readobj -coff-load-config %t.exe | FileCheck %s --check-prefix=CHECK-GC

# CHECK-NOGC: LoadConfig [
# CHECK-NOGC:   Size: 0x48
# CHECK-NOGC:   SEHandlerTable: 0x401048
# CHECK-NOGC:   SEHandlerCount: 1
# CHECK-NOGC: ]
# CHECK-NOGC: SEHTable [
# CHECK-NOGC-NEXT:   0x402006
# CHECK-NOGC-NEXT: ]

# CHECK-GC: LoadConfig [
# CHECK-GC:   Size: 0x48
# CHECK-GC:   SEHandlerTable: 0x0
# CHECK-GC:   SEHandlerCount: 0
# CHECK-GC: ]
# CHECK-GC-NOT: SEHTable


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

# This handler can be GCd, which will make the safeseh table empty, so it should
# appear null.
        .def     _my_handler;
        .scl    3;
        .type   32;
        .endef
        .section        .text,"xr",one_only,_my_handler
_my_handler:
        ret

.safeseh _my_handler


        .section .rdata,"dr"
.globl __load_config_used
__load_config_used:
        .long 72
        .fill 60, 1, 0
        .long ___safe_se_handler_table
        .long ___safe_se_handler_count
