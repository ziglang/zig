/* Contract for all versions is same as cas.l r2,r3,@r0
 * pr and r1 are also clobbered (by jsr & r1 as temp).
 * r0,r2,r4-r15 must be preserved.
 * r3 contains result (==r2 iff cas succeeded). */

	.align 2
.global __sh_cas_gusa
.hidden __sh_cas_gusa
__sh_cas_gusa:
	mov.l r5,@-r15
	mov.l r4,@-r15
	mov r0,r4
	mova 1f,r0
	mov r15,r1
	mov #(0f-1f),r15
0:	mov.l @r4,r5
	cmp/eq r5,r2
	bf 1f
	mov.l r3,@r4
1:	mov r1,r15
	mov r5,r3
	mov r4,r0
	mov.l @r15+,r4
	rts
	 mov.l @r15+,r5

.global __sh_cas_llsc
.hidden __sh_cas_llsc
__sh_cas_llsc:
	mov r0,r1
	.word 0x00ab /* synco */
0:	.word 0x0163 /* movli.l @r1,r0 */
	cmp/eq r0,r2
	bf 1f
	mov r3,r0
	.word 0x0173 /* movco.l r0,@r1 */
	bf 0b
	mov r2,r0
1:	.word 0x00ab /* synco */
	mov r0,r3
	rts
	 mov r1,r0

.global __sh_cas_imask
.hidden __sh_cas_imask
__sh_cas_imask:
	mov r0,r1
	stc sr,r0
	mov.l r0,@-r15
	or #0xf0,r0
	ldc r0,sr
	mov.l @r1,r0
	cmp/eq r0,r2
	bf 1f
	mov.l r3,@r1
1:	ldc.l @r15+,sr
	mov r0,r3
	rts
	 mov r1,r0

.global __sh_cas_cas_l
.hidden __sh_cas_cas_l
__sh_cas_cas_l:
	rts
	 .word 0x2323 /* cas.l r2,r3,@r0 */
