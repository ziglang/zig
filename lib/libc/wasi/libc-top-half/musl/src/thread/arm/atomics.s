.syntax unified
.text

.global __a_barrier_dummy
.hidden __a_barrier_dummy
.type __a_barrier_dummy,%function
__a_barrier_dummy:
	bx lr

.global __a_barrier_oldkuser
.hidden __a_barrier_oldkuser
.type __a_barrier_oldkuser,%function
__a_barrier_oldkuser:
	push {r0,r1,r2,r3,ip,lr}
	mov r1,r0
	mov r2,sp
	ldr ip,=0xffff0fc0
	bl 1f
	pop {r0,r1,r2,r3,ip,lr}
	bx lr
1:	bx ip

.global __a_barrier_v6
.hidden __a_barrier_v6
.type __a_barrier_v6,%function
__a_barrier_v6:
	.arch armv6t2
	mcr p15,0,r0,c7,c10,5
	bx lr

.global __a_barrier_v7
.hidden __a_barrier_v7
.type __a_barrier_v7,%function
__a_barrier_v7:
	.arch armv7-a
	dmb ish
	bx lr

.global __a_cas_dummy
.hidden __a_cas_dummy
.type __a_cas_dummy,%function
__a_cas_dummy:
	mov r3,r0
	ldr r0,[r2]
	subs r0,r3,r0
	streq r1,[r2]
	bx lr

.global __a_cas_v6
.hidden __a_cas_v6
.type __a_cas_v6,%function
__a_cas_v6:
	.arch armv6t2
	mov r3,r0
	mcr p15,0,r0,c7,c10,5
1:	ldrex r0,[r2]
	subs r0,r3,r0
	strexeq r0,r1,[r2]
	teqeq r0,#1
	beq 1b
	mcr p15,0,r0,c7,c10,5
	bx lr

.global __a_cas_v7
.hidden __a_cas_v7
.type __a_cas_v7,%function
__a_cas_v7:
	.arch armv7-a
	mov r3,r0
	dmb ish
1:	ldrex r0,[r2]
	subs r0,r3,r0
	strexeq r0,r1,[r2]
	teqeq r0,#1
	beq 1b
	dmb ish
	bx lr

.global __a_gettp_cp15
.hidden __a_gettp_cp15
.type __a_gettp_cp15,%function
__a_gettp_cp15:
	mrc p15,0,r0,c13,c0,3
	bx lr

/* Tag this file with minimum ISA level so as not to affect linking. */
.object_arch armv4t
.eabi_attribute 6,2

.data
.align 2

.global __a_barrier_ptr
.hidden __a_barrier_ptr
__a_barrier_ptr:
	.word __a_barrier_dummy

.global __a_cas_ptr
.hidden __a_cas_ptr
__a_cas_ptr:
	.word __a_cas_dummy

.global __a_gettp_ptr
.hidden __a_gettp_ptr
__a_gettp_ptr:
	.word __a_gettp_cp15
