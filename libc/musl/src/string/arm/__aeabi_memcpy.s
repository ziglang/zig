.syntax unified

.global __aeabi_memcpy8
.global __aeabi_memcpy4
.global __aeabi_memcpy
.global __aeabi_memmove8
.global __aeabi_memmove4
.global __aeabi_memmove

.type __aeabi_memcpy8,%function
.type __aeabi_memcpy4,%function
.type __aeabi_memcpy,%function
.type __aeabi_memmove8,%function
.type __aeabi_memmove4,%function
.type __aeabi_memmove,%function

__aeabi_memmove8:
__aeabi_memmove4:
__aeabi_memmove:
	cmp   r0, r1
	bls   3f
	cmp   r2, #0
	beq   2f
	adds  r0, r0, r2
	adds  r2, r1, r2
1:	subs  r2, r2, #1
	ldrb  r3, [r2]
	subs  r0, r0, #1
	strb  r3, [r0]
	cmp   r1, r2
	bne   1b
2:	bx    lr
__aeabi_memcpy8:
__aeabi_memcpy4:
__aeabi_memcpy:
3:	cmp   r2, #0
	beq   2f
	adds  r2, r1, r2
1:	ldrb  r3, [r1]
	adds  r1, r1, #1
	strb  r3, [r0]
	adds  r0, r0, #1
	cmp   r1, r2
	bne   1b
2:	bx    lr
