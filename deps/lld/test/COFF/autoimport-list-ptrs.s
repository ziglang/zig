# REQUIRES: x86

# RUN: llvm-mc -triple=x86_64-windows-gnu %s -filetype=obj -o %t.obj
# RUN: lld-link -lldmingw -out:%t.exe -entry:main %t.obj -verbose

# RUN: llvm-objdump -s %t.exe | FileCheck -check-prefix=CONTENTS %s

# Even if we didn't actually write any pseudo relocations,
# check that the synthetic pointers still are set to a non-null value
# CONTENTS: Contents of section .data:
# CONTENTS:  140003000 00200040 01000000 00200040 01000000

    .global main
    .text
main:
    retq
    .data
relocs:
    .quad __RUNTIME_PSEUDO_RELOC_LIST__
    .quad __RUNTIME_PSEUDO_RELOC_LIST_END__
