# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t

# RUN: ld.lld %t -o %t2 --gc-sections
# RUN: llvm-readobj --symbols %t2 | FileCheck %s
# RUN: llvm-objdump --dwarf=frames %t2 | FileCheck --check-prefix=EH %s

# RUN: ld.lld %t -o %t3
# RUN: llvm-readobj --symbols %t3 | FileCheck --check-prefix=NOGC %s
# RUN: llvm-objdump --dwarf=frames %t3 | FileCheck --check-prefix=EHNOGC %s

# CHECK-NOT: foo
# NOGC:      foo

# EH:     FDE cie={{.*}} pc=
# EH-NOT: FDE

# EHNOGC: FDE cie={{.*}} pc=
# EHNOGC: FDE cie={{.*}} pc=

	.section	.text,"ax",@progbits,unique,0
	.globl	foo
foo:
	.cfi_startproc
	.cfi_endproc

	.section	.text,"ax",@progbits,unique,1
	.globl	_start
_start:
	.cfi_startproc
	.cfi_endproc
