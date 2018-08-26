# REQUIRES: x86

# RUN: llvm-mc -triple=x86_64-windows-gnu %s -filetype=obj -o %t1.obj
# RUN: llvm-mc -triple=x86_64-windows-gnu %S/Inputs/common-replacement.s -filetype=obj -o %t2.obj

# RUN: lld-link -lldmingw -entry:main %t1.obj %t2.obj -out:%t.exe -verbose 2>&1 \
# RUN:   | FileCheck -check-prefix VERBOSE %s
# RUN: llvm-readobj -s %t.exe | FileCheck -check-prefix SECTIONS %s

# VERBOSE: -aligncomm:"foo",2

# As long as the .comm symbol is replaced with actual data, RawDataSize
# below should be nonzero.

# SECTIONS:         Name: .data (2E 64 61 74 61 00 00 00)
# SECTIONS-NEXT:    VirtualSize: 0x8
# SECTIONS-NEXT:    VirtualAddress: 0x2000
# SECTIONS-NEXT:    RawDataSize: 512


        .text
        .def            main;
        .scl            2;
        .type           32;
        .endef
        .globl          main
        .p2align        4, 0x90
main:
        movl            foo(%rip), %eax
        retq

# This produces an aligncomm directive, but when linking in
# Inputs/common-replacement.s, this symbol is replaced by a normal defined
# symbol instead.
        .comm           foo, 4, 2
