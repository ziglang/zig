.syntax unified

.global __aeabi_memclr8
.global __aeabi_memclr4
.global __aeabi_memclr
.global __aeabi_memset8
.global __aeabi_memset4
.global __aeabi_memset

.type __aeabi_memclr8,%function
.type __aeabi_memclr4,%function
.type __aeabi_memclr,%function
.type __aeabi_memset8,%function
.type __aeabi_memset4,%function
.type __aeabi_memset,%function

__aeabi_memclr8:
__aeabi_memclr4:
__aeabi_memclr:
	movs  r2, #0
__aeabi_memset8:
__aeabi_memset4:
__aeabi_memset:
	cmp   r1, #0
	beq   2f
	adds  r1, r0, r1
1:	strb  r2, [r0]
	adds  r0, r0, #1
	cmp   r1, r0
	bne   1b
2:	bx    lr
