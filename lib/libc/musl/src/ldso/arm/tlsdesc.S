.syntax unified

.text
.global __tlsdesc_static
.hidden __tlsdesc_static
.type __tlsdesc_static,%function
__tlsdesc_static:
	ldr r0,[r0]
	bx lr

.global __tlsdesc_dynamic
.hidden __tlsdesc_dynamic
.type __tlsdesc_dynamic,%function
__tlsdesc_dynamic:
	push {r2,r3,ip,lr}
	ldr r1,[r0]
	ldr r2,[r1,#4]  // r2 = offset
	ldr r1,[r1]     // r1 = modid

#if ((__ARM_ARCH_6K__ || __ARM_ARCH_6KZ__ || __ARM_ARCH_6ZK__) && !__thumb__) \
 || __ARM_ARCH_7A__ || __ARM_ARCH_7R__ || __ARM_ARCH >= 7
	mrc p15,0,r0,c13,c0,3
#else
	ldr r0,1f
	add r0,r0,pc
	ldr r0,[r0]
2:
#if __ARM_ARCH >= 5
	blx r0          // r0 = tp
#else
#if __thumb__
	add lr,pc,#1
#else
	mov lr,pc
#endif
	bx r0
#endif
#endif
	ldr r3,[r0,#-4] // r3 = dtv
	ldr ip,[r3,r1,LSL #2]
	sub r0,ip,r0
	add r0,r0,r2    // r0 = r3[r1]-r0+r2
#if __ARM_ARCH >= 5
	pop {r2,r3,ip,pc}
#else
	pop {r2,r3,ip,lr}
	bx lr
#endif

#if ((__ARM_ARCH_6K__ || __ARM_ARCH_6KZ__ || __ARM_ARCH_6ZK__) && !__thumb__) \
 || __ARM_ARCH_7A__ || __ARM_ARCH_7R__ || __ARM_ARCH >= 7
#else
	.align 2
1:	.word __a_gettp_ptr - 2b
#endif
