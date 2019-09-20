# REQUIRES: x86
# RUN: llvm-mc -triple x86_64-windows-msvc %s -filetype=obj -o %t.obj
# RUN: lld-link %t.obj -opt:noref -guard:nolongjmp -out:%t.exe -entry:main 2>&1 | FileCheck %s --check-prefix=ERRS
# RUN: llvm-readobj --file-headers --coff-load-config %t.exe | FileCheck %s

# ERRS: warning: ignoring .gfids$y symbol table index section in object {{.*}}gfids-corrupt{{.*}}
# ERRS: warning: ignoring invalid symbol table index in section .gfids$y in object {{.*}}gfids-corrupt{{.*}}

# The table is arbitrary, really.
# CHECK: ImageBase: 0x140000000
# CHECK: LoadConfig [
# CHECK:   SEHandlerTable: 0x0
# CHECK:   SEHandlerCount: 0
# CHECK:   GuardCFCheckFunction: 0x0
# CHECK:   GuardCFCheckDispatch: 0x0
# CHECK:   GuardCFFunctionTable: 0x14000{{.*}}
# CHECK:   GuardCFFunctionCount: 2
# CHECK:   GuardFlags: 0x500
# CHECK:   GuardAddressTakenIatEntryTable: 0x0
# CHECK:   GuardAddressTakenIatEntryCount: 0
# CHECK:   GuardLongJumpTargetTable: 0x0
# CHECK:   GuardLongJumpTargetCount: 0
# CHECK: ]
# CHECK:      GuardFidTable [
# CHECK-NEXT:   0x14000{{.*}}
# CHECK-NEXT:   0x14000{{.*}}
# CHECK-NEXT: ]


# Indicate that gfids are present.
        .def     @feat.00; .scl    3; .type   0; .endef
        .globl  @feat.00
@feat.00 = 0x800

        .def     f1; .scl    2; .type   32; .endef
        .section        .text,"xr",one_only,f1
        .global f1
f1:
        movl $42, %eax
        retq

        .def     f2; .scl    2; .type   32; .endef
        .section        .text,"xr",one_only,f2
        .global f2
f2:
        movl $13, %eax
        retq

        .section        .data,"dw",one_only,fp1
        .globl  fp1
fp1:
        .quad   f1

        .section        .data,"dw",one_only,fp2
        .globl  fp2
fp2:
        .quad   f2

        .section        .gfids$y,"dr",associative,fp1
        .symidx f1
        .byte 0

        .section        .gfids$y,"dr",associative,fp2
        .symidx f2
        .long 0x400

        .def     main; .scl    2; .type   32; .endef
        .section        .text,"xr",one_only,main
        .globl  main
main:
        callq      *fp1(%rip)
        callq      *fp2(%rip)
        xor %eax, %eax
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
