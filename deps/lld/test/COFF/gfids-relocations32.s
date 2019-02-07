# REQUIRES: x86
# RUN: llvm-mc -triple i686-pc-win32 %s -filetype=obj -o %t.obj
# RUN: lld-link %t.obj -guard:cf -out:%t.exe -entry:main
# RUN: llvm-readobj -coff-load-config %t.exe | FileCheck %s --check-prefix=CHECK

# Only f and _main should go in the table.
# (use /lldmap:map.txt to check their addresses).
#
# CHECK: GuardFidTable [
# CHECK-NEXT: 0x401000
# CHECK-NEXT: 0x401030
# CHECK-NEXT: ]

# The input was loosly based on studying this program:
#
#  void foo() { return; }
#  void bar() { return; }
#  int main() {
#    foo();
#    void (*arr[])() = { &bar };
#    (*arr[0])();
#    return 0;
#  }
# cl /c a.cc && dumpbin /disasm a.obj > a.txt &&
#   link a.obj /guard:cf /map:map.txt && dumpbin /loadconfig a.exe



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
fp:     .long f        # DIR32 relocation to function
        .long label    # DIR32 relocation to label


        .def    _main;
        .scl    2;
        .type   32;
        .endef
        .section       .text,"xr",one_only,_main
        .globl  _main
        .p2align 4
_main:  call *fp       # DIR32 relocation to data
        call g         # REL32 relocation to function
        ret


# Load configuration directory entry (winnt.h _IMAGE_LOAD_CONFIG_DIRECTORY32).
# The linker will define the ___guard_* symbols.
        .section .rdata,"dr"
.globl __load_config_used
__load_config_used:
        .long 104  # Size.
        .fill 76, 1, 0
        .long ___guard_fids_table
        .long ___guard_fids_count
        .long ___guard_flags
        .fill 12, 1, 0
