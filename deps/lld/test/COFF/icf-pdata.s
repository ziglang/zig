# REQUIRES: x86
# RUN: llvm-mc %s -triple x86_64-windows-msvc -filetype=obj -o %t.obj
# RUN: lld-link %t.obj -dll -noentry -out:%t.dll -merge:.xdata=.xdata
# RUN: llvm-readobj -sections -coff-exports %t.dll | FileCheck %s

# CHECK:         Name: .pdata
# CHECK-NEXT:    VirtualSize: 0x18
# CHECK:         Name: .xdata
# CHECK-NEXT:    VirtualSize: 0x10

# CHECK:         Name: xdata1
# CHECK-NEXT:    RVA: 0x1010
# CHECK:         Name: xdata1a
# CHECK-NEXT:    RVA: 0x1010
# CHECK:         Name: xdata1b
# CHECK-NEXT:    RVA: 0x1030

	.text
callee:
	ret

	.def	 xdata1;
	.scl	2;
	.type	32;
	.endef
	.section	.text,"xr",one_only,xdata1
	.globl	xdata1                  # -- Begin function xdata1
	.p2align	4, 0x90
xdata1:                                 # @xdata1
.seh_proc xdata1
# BB#0:                                 # %entry
	subq	$40, %rsp
	.seh_stackalloc 40
	.seh_endprologue
	callq	callee
	nop
	addq	$40, %rsp
	jmp	callee                  # TAILCALL
	.seh_handlerdata
	.section	.text,"xr",one_only,xdata1
	.seh_endproc
                                        # -- End function

# xdata1a is identical to xdata1, so it should be ICFd, and so should its pdata.
# It also has associative debug and CFG sections which should be ignored by ICF.
	.def	 xdata1a;
	.scl	2;
	.type	32;
	.endef
	.section	.text,"xr",one_only,xdata1a
	.globl	xdata1a                  # -- Begin function xdata1a
	.p2align	4, 0x90
xdata1a:                                 # @xdata1a
.seh_proc xdata1a
# BB#0:                                 # %entry
	subq	$40, %rsp
	.seh_stackalloc 40
	.seh_endprologue
	callq	callee
	nop
	addq	$40, %rsp
	jmp	callee                  # TAILCALL
	.seh_handlerdata
	.section	.text,"xr",one_only,xdata1a
	.seh_endproc

	.section .debug$S,"r",associative,xdata1a
	.section .gfids$y,"r",associative,xdata1a
	.section .gljmp$y,"r",associative,xdata1a

# xdata1b's text is identical to xdata1, but its xdata specifies a different
# stack size, so it cannot be ICFd with xdata1.
	.def	 xdata1b;
	.scl	2;
	.type	32;
	.endef
	.section	.text,"xr",one_only,xdata1b
	.globl	xdata1b                  # -- Begin function xdata1b
	.p2align	4, 0x90
xdata1b:                                 # @xdata1b
.seh_proc xdata1b
# BB#0:                                 # %entry
	subq	$40, %rsp
	.seh_stackalloc 48
	.seh_endprologue
	callq	callee
	nop
	addq	$40, %rsp
	jmp	callee                  # TAILCALL
	.seh_handlerdata
	.section	.text,"xr",one_only,xdata1b
	.seh_endproc
                                        # -- End function

	.section	.drectve,"yn"
	.ascii	" -export:xdata1"
	.ascii	" -export:xdata1a"
	.ascii	" -export:xdata1b"
