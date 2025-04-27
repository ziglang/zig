// __syscall_cp_asm(&self->cancel, nr,  u, v, w, x, y,    z)
//                  r0             r1  r2 r3 r4 r5  stack stack

// syscall(nr,  u, v, w, x, y, z)
//         r6  r0 r1 r2 r3 r4 r5

.text
.global __cp_begin
.hidden __cp_begin
.global __cp_end
.hidden __cp_end
.global __cp_cancel
.hidden __cp_cancel
.hidden __cancel
.global __syscall_cp_asm
.hidden __syscall_cp_asm
.type __syscall_cp_asm,%function
__syscall_cp_asm:
__cp_begin:
	r0 = memw(r0+#0)
	{
	  p0 = cmp.eq(r0, #0); if (!p0.new) jump:nt __cancel
	}
	{ r6 = r1
	  r1:0 = combine(r3, r2)
	  r3:2 = combine(r5, r4) }
	{ r4 = memw(r29+#0)
	  r5 = memw(r29+#4) }
	trap0(#1)
__cp_end:
	jumpr r31
.size __syscall_cp_asm, .-__syscall_cp_asm
__cp_cancel:
        jump __cancel
.size __cp_cancel, .-__cp_cancel
