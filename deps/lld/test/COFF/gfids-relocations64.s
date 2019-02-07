# REQUIRES: x86
# RUN: llvm-mc -triple x86_64-pc-win32 %s -filetype=obj -o %t.obj
# RUN: lld-link %t.obj -guard:cf -out:%t.exe -entry:main
# RUN: llvm-readobj -coff-load-config %t.exe | FileCheck %s --check-prefix=CHECK

# f, g, and main go in the table.
# Including g isn't strictly necessary since it's not an indirect call target,
# however the linker can't know that because relative relocations are used both
# for direct calls and for getting the absolute address of a function.
# (use /lldmap:map.txt to check their addresses).
#
# CHECK: GuardFidTable [
# CHECK-NEXT: 0x140001000
# CHECK-NEXT: 0x140001010
# CHECK-NEXT: 0x140001030
# CHECK-NEXT: ]

        .def    f;
        .scl    3;
        .type   32;
        .endef
        .section       .text,"xr",one_only,f
        .p2align 4
f:      movl $1, %eax
        ret


        .def    g;
        .scl    3;
        .type   32;
        .endef
        .section       .text,"xr",one_only,g
        .p2align 4
g:      movl $2, %eax
        ret


        .def    label;
        .scl    6;     # StorageClass: Label
        .type   0;     # Type: Not a function.
        .endef
        .section       .text,"xr",one_only,label
        .p2align 4
label:  ret


        .data
        .globl fp
        .p2align 4
fp:     .quad f        # DIR32 relocation to function
        .quad label    # DIR32 relocation to label


        .def    main;
        .scl    2;
        .type   32;
        .endef
        .section       .text,"xr",one_only,main
        .globl  main
        .p2align 4
main:   call *fp       # DIR32 relocation to data
        call g         # REL32 relocation to function
        ret


# Load configuration directory entry (winnt.h _IMAGE_LOAD_CONFIG_DIRECTORY64).
# The linker will define the __guard_* symbols.
        .section .rdata,"dr"
.globl _load_config_used
_load_config_used:
        .long 256
        .fill 124, 1, 0
        .quad __guard_fids_table
        .quad __guard_fids_count
        .long __guard_flags
        .fill 128, 1, 0
