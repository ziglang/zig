# REQUIRES: x86
# RUN: grep -B99999 [S]PLITMARKER %s | llvm-mc -triple x86_64-windows-msvc -filetype=obj -o %t1.obj
# RUN: grep -A99999 [S]PLITMARKER %s | llvm-mc -triple x86_64-windows-msvc -filetype=obj -o %t2.obj
# RUN: lld-link %t1.obj %t2.obj -guard:nolongjmp -out:%t.exe -entry:main -opt:noref
# RUN: llvm-readobj -file-headers -coff-load-config %t.exe | FileCheck %s

# CHECK: ImageBase: 0x140000000
# CHECK: LoadConfig [
# CHECK:   SEHandlerTable: 0x0
# CHECK:   SEHandlerCount: 0
# CHECK:   GuardCFCheckFunction: 0x0
# CHECK:   GuardCFCheckDispatch: 0x0
# CHECK:   GuardCFFunctionTable: 0x14000{{.*}}
# CHECK:   GuardCFFunctionCount: 3
# CHECK:   GuardFlags: 0x500
# CHECK:   GuardAddressTakenIatEntryTable: 0x0
# CHECK:   GuardAddressTakenIatEntryCount: 0
# CHECK:   GuardLongJumpTargetTable: 0x0
# CHECK:   GuardLongJumpTargetCount: 0
# CHECK: ]
# CHECK:      GuardFidTable [
# CHECK-NEXT:   0x14000{{.*}}
# CHECK-NEXT:   0x14000{{.*}}
# CHECK-NEXT:   0x14000{{.*}}
# CHECK-NEXT: ]


# Indicate that no gfids are present. All symbols used by relocations in this
# file will be considered address-taken.
        .def     @feat.00; .scl    3; .type   0; .endef
        .globl  @feat.00
@feat.00 = 0

        .def     main; .scl    2; .type   32; .endef
        .section        .text,"xr",one_only,main
        .globl  main
main:
        subq $8, %rsp
        leaq foo(%rip), %rdx
        callq bar
        movl $0, %eax
        addq $8, %rsp
        retq

# Should not appear in gfids table.
        .def     baz; .scl    2; .type   32; .endef
        .section        .text,"xr",one_only,baz
        .globl  baz
baz:
        mov $1, %eax
        retq

        .def     qux; .scl    2; .type   32; .endef
        .section        .text,"xr",one_only,qux
        .globl  qux
qux:
        mov $2, %eax
        retq

        .def     quxx; .scl    2; .type   32; .endef
        .section        .text,"xr",one_only,quxx
        .globl  quxx
quxx:
        mov $3, %eax
        retq

# Load config.
        .section .rdata,"dr"
.globl _load_config_used
_load_config_used:
        .long 256
        .fill 124, 1, 0
        .quad __guard_fids_table
        .quad __guard_fids_count
        .long __guard_flags
        .fill 128, 1, 0

# SPLITMARKER

# Indicate that gfids are present. This file does not take any addresses.
        .def     @feat.00; .scl    3; .type   0; .endef
        .globl  @feat.00
@feat.00 = 0x800

        .def     foo; .scl    2; .type   32; .endef
        .section        .text,"xr",one_only,foo
        .global foo
foo:
        movl $42, %eax
        retq

        .def     bar; .scl    2; .type   32; .endef
        .section        .text,"xr",one_only,bar
        .global bar
bar:
        movl $13, %eax
        retq
