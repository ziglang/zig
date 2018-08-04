# REQUIRES: x86
# RUN: llvm-mc -triple x86_64-windows-msvc %s -filetype=obj -o %t.obj
# RUN: lld-link %t.obj -guard:nolongjmp -out:%t.exe -opt:noref -entry:main
# RUN: llvm-readobj -file-headers -coff-load-config %t.exe | FileCheck %s --check-prefix=CHECK-NOGC
# RUN: lld-link %t.obj -guard:nolongjmp -out:%t.exe -opt:noref -entry:main -debug:dwarf
# RUN: llvm-readobj -file-headers -coff-load-config %t.exe | FileCheck %s --check-prefix=CHECK-NOGC
# RUN: lld-link %t.obj -guard:nolongjmp -out:%t.exe -opt:ref -entry:main
# RUN: llvm-readobj -file-headers -coff-load-config %t.exe | FileCheck %s --check-prefix=CHECK-GC

# This assembly is meant to mimic what CL emits for this kind of C code when
# /Gw (-fdata-sections) is enabled:
# int f() { return 42; }
# int g() { return 13; }
# int (*fp1)() = &f;
# int (*fp2)() = &g;
# int main() {
#   return fp1();
# }
# Compile with 'cl -c -guard:cf -Gw -O1' and note the two associative .gfids$y
# sections.

# Expect 3 entries: main, f, and g.

# CHECK-NOGC: ImageBase: 0x140000000
# CHECK-NOGC: LoadConfig [
# CHECK-NOGC:   SEHandlerTable: 0x0
# CHECK-NOGC:   SEHandlerCount: 0
# CHECK-NOGC:   GuardCFCheckFunction: 0x0
# CHECK-NOGC:   GuardCFCheckDispatch: 0x0
# CHECK-NOGC:   GuardCFFunctionTable: 0x14000{{.*}}
# CHECK-NOGC:   GuardCFFunctionCount: 3
# CHECK-NOGC:   GuardFlags: 0x500
# CHECK-NOGC:   GuardAddressTakenIatEntryTable: 0x0
# CHECK-NOGC:   GuardAddressTakenIatEntryCount: 0
# CHECK-NOGC:   GuardLongJumpTargetTable: 0x0
# CHECK-NOGC:   GuardLongJumpTargetCount: 0
# CHECK-NOGC: ]
# CHECK-NOGC:      GuardFidTable [
# CHECK-NOGC-NEXT:   0x14000{{.*}}
# CHECK-NOGC-NEXT:   0x14000{{.*}}
# CHECK-NOGC-NEXT:   0x14000{{.*}}
# CHECK-NOGC-NEXT: ]

# Expect 2 entries: main and f. fp2 was discarded, so g was only used as a
# direct call target.

# CHECK-GC: ImageBase: 0x140000000
# CHECK-GC: LoadConfig [
# CHECK-GC:   SEHandlerTable: 0x0
# CHECK-GC:   SEHandlerCount: 0
# CHECK-GC:   GuardCFCheckFunction: 0x0
# CHECK-GC:   GuardCFCheckDispatch: 0x0
# CHECK-GC:   GuardCFFunctionTable: 0x14000{{.*}}
# CHECK-GC:   GuardCFFunctionCount: 2
# CHECK-GC:   GuardFlags: 0x500
# CHECK-GC:   GuardAddressTakenIatEntryTable: 0x0
# CHECK-GC:   GuardAddressTakenIatEntryCount: 0
# CHECK-GC:   GuardLongJumpTargetTable: 0x0
# CHECK-GC:   GuardLongJumpTargetCount: 0
# CHECK-GC: ]
# CHECK-GC:      GuardFidTable [
# CHECK-GC-NEXT:   0x14000{{.*}}
# CHECK-GC-NEXT:   0x14000{{.*}}
# CHECK-GC-NEXT: ]


# We need @feat.00 to have 0x800 to indicate .gfids are present.
        .def     @feat.00;
        .scl    3;
        .type   0;
        .endef
        .globl  @feat.00
@feat.00 = 0x801

        .def     main;
        .scl    2;
        .type   32;
        .endef
        .section        .text,"xr",one_only,main
        .globl  main
main:
        # Call g directly so that it is not dead stripped.
        callq g
        rex64 jmpq      *fp1(%rip)

        .def     f;
        .scl    3;
        .type   32;
        .endef
        .section        .text,"xr",one_only,f
f:
        movl $42, %eax
        retq

        .section        .data,"dw",one_only,fp1
        .globl  fp1
fp1:
        .quad   f

        .section        .gfids$y,"dr",associative,fp1
        .symidx f

# Section GC will remove the following, so 'g' should not be present in the
# guard fid table.

        .def     g;
        .scl    3;
        .type   32;
        .endef
        .section        .text,"xr",one_only,g
g:
        movl $13, %eax
        retq

        .section        .data,"dw",one_only,fp2
        .globl  fp2
fp2:
        .quad   g

        .section        .gfids$y,"dr",associative,fp2
        .symidx g

        .section .rdata,"dr"
.globl _load_config_used
_load_config_used:
        .long 256
        .fill 124, 1, 0
        .quad __guard_fids_table
        .quad __guard_fids_count
        .long __guard_flags
        .fill 128, 1, 0
