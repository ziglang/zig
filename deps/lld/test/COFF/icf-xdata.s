# RUN: llvm-mc %s -triple x86_64-windows-msvc -filetype=obj -o %t.obj
# RUN: lld-link %t.obj -dll -noentry -out:%t.dll
# RUN: llvm-readobj -sections %t.dll | FileCheck %s

# There shouldn't be much xdata, because all three .pdata entries (12 bytes
# each) should use the same .xdata unwind info.
# CHECK:         Name: .pdata
# CHECK-NEXT:    VirtualSize: 0x24
# CHECK:         Name: .xdata
# CHECK-NEXT:    VirtualSize: 0x8

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
	.def	 xdata2;
	.scl	2;
	.type	32;
	.endef
	.section	.text,"xr",one_only,xdata2
	.globl	xdata2                  # -- Begin function xdata2
	.p2align	4, 0x90
xdata2:                                 # @xdata2
.seh_proc xdata2
# BB#0:                                 # %entry
	subq	$40, %rsp
	.seh_stackalloc 40
	.seh_endprologue
	callq	callee
	callq	callee
	nop
	addq	$40, %rsp
	jmp	callee                  # TAILCALL
	.seh_handlerdata
	.section	.text,"xr",one_only,xdata2
	.seh_endproc
                                        # -- End function
	.def	 xdata3;
	.scl	2;
	.type	32;
	.endef
	.section	.text,"xr",one_only,xdata3
	.globl	xdata3                  # -- Begin function xdata3
	.p2align	4, 0x90
xdata3:                                 # @xdata3
.seh_proc xdata3
# BB#0:                                 # %entry
	subq	$40, %rsp
	.seh_stackalloc 40
	.seh_endprologue
	callq	callee
	callq	callee
	callq	callee
	nop
	addq	$40, %rsp
	jmp	callee                  # TAILCALL
	.seh_handlerdata
	.section	.text,"xr",one_only,xdata3
	.seh_endproc
                                        # -- End function
	.section	.drectve,"yn"
	.ascii	" -export:xdata1"
	.ascii	" -export:xdata2"
	.ascii	" -export:xdata3"

