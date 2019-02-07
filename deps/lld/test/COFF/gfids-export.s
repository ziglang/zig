# REQUIRES: x86
# RUN: llvm-mc -triple x86_64-pc-win32 %s -filetype=obj -o %t.obj
# RUN: lld-link %t.obj -guard:cf -dll -out:%t.dll -noentry
# RUN: llvm-readobj -coff-load-config %t.dll | FileCheck %s --check-prefix=CHECK

# There should be a single entry in the table for the exported symbol.
#
# CHECK: GuardFidTable [
# CHECK-NEXT: 0x180001000
# CHECK-NEXT: ]

        .def    func_export; .scl    2; .type   32; .endef
        .globl func_export
        .section       .text,"xr",one_only,func_export
        .p2align 4
func_export:
        movl $1, %eax
        .globl label_export
label_export:
        movl $2, %eax
        ret

        .data
        .globl data_export
data_export:
        .long 42

        .section .drectve,"dr"
        .ascii " /EXPORT:func_export"
        .ascii " /EXPORT:label_export"
        .ascii " /EXPORT:data_export"


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
