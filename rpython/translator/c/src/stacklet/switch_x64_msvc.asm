;
; stack switching code for MASM on x64
; Kristjan Valur Jonsson, apr 2011
;

include macamd64.inc

pop_reg MACRO reg
	pop reg
ENDM

load_xmm128 macro Reg, Offset
	movdqa  Reg, Offset[rsp]
endm

.code

;arguments save_state, restore_state, extra are passed in rcx, rdx, r8 respectively
;slp_switch PROC FRAME
NESTED_ENTRY slp_switch, _TEXT$00
	; save all registers that the x64 ABI specifies as non-volatile.
	; This includes some mmx registers.  May not always be necessary,
	; unless our application is doing 3D, but better safe than sorry.
	alloc_stack 168; 10 * 16 bytes, plus 8 bytes to make stack 16 byte aligned
	save_xmm128 xmm15, 144
	save_xmm128 xmm14, 128
	save_xmm128 xmm13, 112
	save_xmm128 xmm12, 96
	save_xmm128 xmm11, 80
	save_xmm128 xmm10, 64
	save_xmm128 xmm9,  48
	save_xmm128 xmm8,  32
	save_xmm128 xmm7,  16
	save_xmm128 xmm6,  0
	
	push_reg r15
	push_reg r14
	push_reg r13
	push_reg r12
	
	push_reg rbp
	push_reg rbx
	push_reg rdi
	push_reg rsi
	
	sub rsp, 20h ;allocate shadow stack space for the arguments (must be multiple of 16)
	.allocstack 20h
.endprolog

	;save argments in nonvolatile registers
	mov r12, rcx ;save_state
	mov r13, rdx
	mov r14, r8

	; load stack base that we are saving minus the callee argument
	; shadow stack.  We don't want that clobbered
	lea rcx, [rsp+20h] 
	mov rdx, r14
	call r12 ;pass stackpointer, return new stack pointer in eax
	
	; an null value means that we don't restore.
	test rax, rax
	jz exit
	
	;actual stack switch (and re-allocating the shadow stack):
	lea rsp, [rax-20h]
	
	mov rcx, rax ;pass new stack pointer
	mov rdx, r14
	call r13
	;return the rax
EXIT:
	
	add rsp, 20h
	pop_reg rsi
	pop_reg rdi
	pop_reg rbx
	pop_reg rbp
	
	pop_reg r12
	pop_reg r13
	pop_reg r14
	pop_reg r15
	
	load_xmm128 xmm15, 144
	load_xmm128 xmm14, 128
	load_xmm128 xmm13, 112
	load_xmm128 xmm12, 96
	load_xmm128 xmm11, 80
	load_xmm128 xmm10, 64
	load_xmm128 xmm9,  48
	load_xmm128 xmm8,  32
	load_xmm128 xmm7,  16
	load_xmm128 xmm6,  0
	add rsp, 168
	ret
	
NESTED_END slp_switch, _TEXT$00
;slp_switch ENDP 
	
END