.global __cp_begin
.hidden __cp_begin
.global __cp_end
.hidden __cp_end
.global __cp_cancel
.hidden __cp_cancel
.hidden __cancel
.global __syscall_cp_asm
.hidden __syscall_cp_asm

#r0: volatile. may be modified during linkage.
#r1: stack frame: 16 byte alignment.
#r2: tls/thread pointer on pp32
#r3,r4: return values, first args
#r5-r10: args
#r11-r12: volatile. may be modified during linkage
#r13: "small data area" pointer
#r14 - r30: local vars
#r31: local or environment pointer

#r1, r14-31: belong to the caller, must be saved and restored
#r0, r3-r12, ctr, xer: volatile, not preserved
#r0,r11,r12: may be altered by cross-module call, 
#"a func cannot depend on that these regs have the values placed by the caller"

#the fields CR2,CR2,CR4 of the cond reg must be preserved
#LR (link reg) shall contain the funcs return address
	.text
	.type   __syscall_cp_asm,%function
__syscall_cp_asm:
	# at enter: r3 = pointer to self->cancel, r4: syscall no, r5: first arg, r6: 2nd, r7: 3rd, r8: 4th, r9: 5th, r10: 6th
__cp_begin:
	# r3 holds first argument, its a pointer to self->cancel. 
	# we must compare the dereferenced value with 0 and jump to __cancel if its not
	
	lwz 0, 0(3) #deref pointer into r0
	
	cmpwi cr7, 0, 0 #compare r0 with 0, store result in cr7. 
	beq+ cr7, 1f #jump to label 1 if r0 was 0
	
	b __cp_cancel #else call cancel
1:
	#ok, the cancel flag was not set
	# syscall: number goes to r0, the rest 3-8
	mr      0, 4                  # put the system call number into r0
	mr      3, 5                  # Shift the arguments: arg1
	mr      4, 6                  # arg2
	mr      5, 7                  # arg3
	mr      6, 8                  # arg4
	mr      7, 9                  # arg5
	mr      8, 10                  # arg6
	sc
__cp_end:
	bnslr+ # return if no summary overflow. 
	#else negate result.
	neg 3, 3
	blr
__cp_cancel:
	b __cancel
