# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
# RUN: ld.lld %t -o %tout --gc-sections -shared
# RUN: llvm-nm -D %tout | FileCheck %s

# CHECK-NOT: qux
# CHECK: bar
# CHECK-NOT: qux

	.global foo,bar,qux
	.local baz

	.section .data.foo,"aw",%progbits
foo:
	.dc.a	bar

	.section .bata.baz,"aw",%progbits
baz:
	.dc.a	qux
