# REQUIRES: x86
# RUN: echo '.section .bar, "a"; .quad 1;' | \
# RUN:   llvm-mc -filetype=obj -triple=x86_64-pc-linux - -o %tfile1.o
# RUN: echo '.section .zed, "a"; .quad 2;' | \
# RUN:   llvm-mc -filetype=obj -triple=x86_64-pc-linux - -o %tfile2.o

## We have a file name and no input sections description. In that case, all
## sections from the file specified should be included. Check that.
# RUN: ld.lld -o %t --script %s %tfile1.o %tfile2.o
# RUN: llvm-objdump -s %t | FileCheck %s

# CHECK:      Contents of section .foo:
# CHECK-NEXT:  01000000 00000000 02000000 00000000

SECTIONS {
 .foo : { *file1.o *file2.o }
}
