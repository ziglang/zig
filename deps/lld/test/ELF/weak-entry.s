# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t
# RUN: ld.lld %t -o %tout
# RUN: llvm-nm %tout | FileCheck %s

# CHECK:      w _start
# CHECK-NEXT: T foo

.global foo
.weak _start
.text
foo:
	.dc.a _start
