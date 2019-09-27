# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: echo "foo = 0x22;" > %t.script

## This testcase checks that we apply -defsym and linker script
## in the same order are they specified in a command line. 

## Check that linker script can override -defsym assignments.
# RUN: ld.lld %t.o -defsym=foo=0x11 -script %t.script -o %t
# RUN: llvm-readobj --symbols %t | FileCheck %s
# CHECK:      Name: foo
# CHECK-NEXT:   Value: 0x22

## Check that -defsym can override linker script. Check that multiple
## -defsym commands for the same symbol are allowed.
# RUN: ld.lld %t.o -script %t.script -defsym=foo=0x11 -defsym=foo=0x33 -o %t
# RUN: llvm-readobj --symbols %t | FileCheck %s --check-prefix=REORDER
# REORDER:      Name: foo
# REORDER-NEXT:   Value: 0x33
