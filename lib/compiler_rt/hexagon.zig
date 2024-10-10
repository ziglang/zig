const builtin = @import("builtin");
const common = @import("./common.zig");

fn __hexagon_divsi3() callconv(.naked) noreturn {
    asm volatile (
        \\ {
        \\   p0 = cmp.ge(r0,#0)
        \\   p1 = cmp.ge(r1,#0)
        \\   r1 = abs(r0)
        \\   r2 = abs(r1)
        \\  }
        \\  {
        \\   r3 = cl0(r1)
        \\   r4 = cl0(r2)
        \\   r5 = sub(r1,r2)
        \\   p2 = cmp.gtu(r2,r1)
        \\  }
        \\  {
        \\   r0 = #0
        \\   p1 = xor(p0,p1)
        \\   p0 = cmp.gtu(r2,r5)
        \\   if (p2) jumpr r31
        \\  }
        \\
        \\  {
        \\   r0 = mux(p1,#-1,#1)
        \\   if (p0) jumpr r31
        \\   r4 = sub(r4,r3)
        \\   r3 = #1
        \\  }
        \\  {
        \\   r0 = #0
        \\   r3:2 = vlslw(r3:2,r4)
        \\   loop0(1f,r4)
        \\  }
        \\  .falign
        \\ 1:
        \\  {
        \\   p0 = cmp.gtu(r2,r1)
        \\   if (!p0.new) r1 = sub(r1,r2)
        \\   if (!p0.new) r0 = add(r0,r3)
        \\   r3:2 = vlsrw(r3:2,#1)
        \\  }:endloop0
        \\  {
        \\   p0 = cmp.gtu(r2,r1)
        \\   if (!p0.new) r0 = add(r0,r3)
        \\   if (!p1) jumpr r31
        \\  }
        \\  {
        \\   r0 = neg(r0)
        \\   jumpr r31
        \\  }
    );
}

fn __hexagon_udivmoddi4() callconv(.naked) noreturn {
    asm volatile (
        \\ {
        \\   r6 = cl0(r1:0)
        \\   r7 = cl0(r3:2)
        \\   r5:4 = r3:2
        \\   r3:2 = r1:0
        \\  }
        \\  {
        \\   r10 = sub(r7,r6)
        \\   r1:0 = #0
        \\   r15:14 = #1
        \\  }
        \\  {
        \\   r11 = add(r10,#1)
        \\   r13:12 = lsl(r5:4,r10)
        \\   r15:14 = lsl(r15:14,r10)
        \\  }
        \\  {
        \\   p0 = cmp.gtu(r5:4,r3:2)
        \\   loop0(1f,r11)
        \\  }
        \\  {
        \\   if (p0) jumpr r31
        \\  }
        \\  .falign
        \\ 1:
        \\  {
        \\   p0 = cmp.gtu(r13:12,r3:2)
        \\  }
        \\  {
        \\   r7:6 = sub(r3:2, r13:12)
        \\   r9:8 = add(r1:0, r15:14)
        \\  }
        \\  {
        \\   r1:0 = vmux(p0, r1:0, r9:8)
        \\   r3:2 = vmux(p0, r3:2, r7:6)
        \\  }
        \\  {
        \\   r15:14 = lsr(r15:14, #1)
        \\   r13:12 = lsr(r13:12, #1)
        \\  }:endloop0
        \\  {
        \\   jumpr r31
        \\  }
    );
}

fn __hexagon_umodsi3() callconv(.naked) noreturn {
    asm volatile (
        \\ {
        \\   r2 = cl0(r0)
        \\   r3 = cl0(r1)
        \\   p0 = cmp.gtu(r1,r0)
        \\  }
        \\  {
        \\   r2 = sub(r3,r2)
        \\   if (p0) jumpr r31
        \\  }
        \\  {
        \\   loop0(1f,r2)
        \\   p1 = cmp.eq(r2,#0)
        \\   r2 = lsl(r1,r2)
        \\  }
        \\  .falign
        \\ 1:
        \\  {
        \\   p0 = cmp.gtu(r2,r0)
        \\   if (!p0.new) r0 = sub(r0,r2)
        \\   r2 = lsr(r2,#1)
        \\   if (p1) r1 = #0
        \\  }:endloop0
        \\  {
        \\   p0 = cmp.gtu(r2,r0)
        \\   if (!p0.new) r0 = sub(r0,r1)
        \\   jumpr r31
        \\  }
    );
}

fn __hexagon_sqrtf() callconv(.naked) noreturn {
    asm volatile (
        \\ {
        \\     r3,p0 = sfinvsqrta(r0)
        \\     r5 = sffixupr(r0)
        \\     r4 = ##0x3f000000
        \\     r1:0 = combine(#0,#0)
        \\   }
        \\   {
        \\     r0 += sfmpy(r3,r5):lib
        \\     r1 += sfmpy(r3,r4):lib
        \\     r2 = r4
        \\     r3 = r5
        \\   }
        \\   {
        \\     r2 -= sfmpy(r0,r1):lib
        \\     p1 = sfclass(r5,#1)
        \\
        \\   }
        \\   {
        \\     r0 += sfmpy(r0,r2):lib
        \\     r1 += sfmpy(r1,r2):lib
        \\     r2 = r4
        \\     r3 = r5
        \\   }
        \\   {
        \\     r2 -= sfmpy(r0,r1):lib
        \\     r3 -= sfmpy(r0,r0):lib
        \\   }
        \\   {
        \\     r0 += sfmpy(r1,r3):lib
        \\     r1 += sfmpy(r1,r2):lib
        \\     r2 = r4
        \\     r3 = r5
        \\   }
        \\   {
        \\
        \\     r3 -= sfmpy(r0,r0):lib
        \\     if (p1) r0 = or(r0,r5)
        \\   }
        \\   {
        \\     r0 += sfmpy(r1,r3,p0):scale
        \\     jumpr r31
        \\   }
    );
}

fn __hexagon_udivmodsi4() callconv(.naked) noreturn {
    asm volatile (
        \\ {
        \\   r2 = cl0(r0)
        \\   r3 = cl0(r1)
        \\   r5:4 = combine(#1,#0)
        \\   p0 = cmp.gtu(r1,r0)
        \\  }
        \\  {
        \\   r6 = sub(r3,r2)
        \\   r4 = r1
        \\   r1:0 = combine(r0,r4)
        \\   if (p0) jumpr r31
        \\  }
        \\  {
        \\   r3:2 = vlslw(r5:4,r6)
        \\   loop0(1f,r6)
        \\   p0 = cmp.eq(r6,#0)
        \\   if (p0.new) r4 = #0
        \\  }
        \\  .falign
        \\ 1:
        \\  {
        \\   p0 = cmp.gtu(r2,r1)
        \\   if (!p0.new) r1 = sub(r1,r2)
        \\   if (!p0.new) r0 = add(r0,r3)
        \\   r3:2 = vlsrw(r3:2,#1)
        \\  }:endloop0
        \\  {
        \\   p0 = cmp.gtu(r2,r1)
        \\   if (!p0.new) r1 = sub(r1,r4)
        \\   if (!p0.new) r0 = add(r0,r3)
        \\   jumpr r31
        \\  }
    );
}

fn __hexagon_moddi3() callconv(.naked) noreturn {
    asm volatile (
        \\ {
        \\   p3 = tstbit(r1,#31)
        \\  }
        \\  {
        \\   r1:0 = abs(r1:0)
        \\   r3:2 = abs(r3:2)
        \\  }
        \\  {
        \\   r6 = cl0(r1:0)
        \\   r7 = cl0(r3:2)
        \\   r5:4 = r3:2
        \\   r3:2 = r1:0
        \\  }
        \\  {
        \\   r10 = sub(r7,r6)
        \\   r1:0 = #0
        \\   r15:14 = #1
        \\  }
        \\  {
        \\   r11 = add(r10,#1)
        \\   r13:12 = lsl(r5:4,r10)
        \\   r15:14 = lsl(r15:14,r10)
        \\  }
        \\  {
        \\   p0 = cmp.gtu(r5:4,r3:2)
        \\   loop0(1f,r11)
        \\  }
        \\  {
        \\   if (p0) jump .hexagon_moddi3_return
        \\  }
        \\  .falign
        \\ 1:
        \\  {
        \\   p0 = cmp.gtu(r13:12,r3:2)
        \\  }
        \\  {
        \\   r7:6 = sub(r3:2, r13:12)
        \\   r9:8 = add(r1:0, r15:14)
        \\  }
        \\  {
        \\   r1:0 = vmux(p0, r1:0, r9:8)
        \\   r3:2 = vmux(p0, r3:2, r7:6)
        \\  }
        \\  {
        \\   r15:14 = lsr(r15:14, #1)
        \\   r13:12 = lsr(r13:12, #1)
        \\  }:endloop0
        \\
        \\ .hexagon_moddi3_return:
        \\  {
        \\   r1:0 = neg(r3:2)
        \\  }
        \\  {
        \\   r1:0 = vmux(p3,r1:0,r3:2)
        \\   jumpr r31
        \\  }
    );
}

fn __hexagon_divdi3() callconv(.naked) noreturn {
    asm volatile (
        \\ {
        \\   p2 = tstbit(r1,#31)
        \\   p3 = tstbit(r3,#31)
        \\  }
        \\  {
        \\   r1:0 = abs(r1:0)
        \\   r3:2 = abs(r3:2)
        \\  }
        \\  {
        \\   r6 = cl0(r1:0)
        \\   r7 = cl0(r3:2)
        \\   r5:4 = r3:2
        \\   r3:2 = r1:0
        \\  }
        \\  {
        \\   p3 = xor(p2,p3)
        \\   r10 = sub(r7,r6)
        \\   r1:0 = #0
        \\   r15:14 = #1
        \\  }
        \\  {
        \\   r11 = add(r10,#1)
        \\   r13:12 = lsl(r5:4,r10)
        \\   r15:14 = lsl(r15:14,r10)
        \\  }
        \\  {
        \\   p0 = cmp.gtu(r5:4,r3:2)
        \\   loop0(1f,r11)
        \\  }
        \\  {
        \\   if (p0) jump .hexagon_divdi3_return
        \\  }
        \\  .falign
        \\ 1:
        \\  {
        \\   p0 = cmp.gtu(r13:12,r3:2)
        \\  }
        \\  {
        \\   r7:6 = sub(r3:2, r13:12)
        \\   r9:8 = add(r1:0, r15:14)
        \\  }
        \\  {
        \\   r1:0 = vmux(p0, r1:0, r9:8)
        \\   r3:2 = vmux(p0, r3:2, r7:6)
        \\  }
        \\  {
        \\   r15:14 = lsr(r15:14, #1)
        \\   r13:12 = lsr(r13:12, #1)
        \\  }:endloop0
        \\
        \\ .hexagon_divdi3_return:
        \\  {
        \\   r3:2 = neg(r1:0)
        \\  }
        \\  {
        \\   r1:0 = vmux(p3,r3:2,r1:0)
        \\   jumpr r31
        \\  }
    );
}

fn __hexagon_divsf3() callconv(.naked) noreturn {
    asm volatile (
        \\ {
        \\     r2,p0 = sfrecipa(r0,r1)
        \\     r4 = sffixupd(r0,r1)
        \\     r3 = ##0x3f800000
        \\   }
        \\   {
        \\     r5 = sffixupn(r0,r1)
        \\     r3 -= sfmpy(r4,r2):lib
        \\     r6 = ##0x80000000
        \\     r7 = r3
        \\   }
        \\   {
        \\     r2 += sfmpy(r3,r2):lib
        \\     r3 = r7
        \\     r6 = r5
        \\     r0 = and(r6,r5)
        \\   }
        \\   {
        \\     r3 -= sfmpy(r4,r2):lib
        \\     r0 += sfmpy(r5,r2):lib
        \\   }
        \\   {
        \\     r2 += sfmpy(r3,r2):lib
        \\     r6 -= sfmpy(r0,r4):lib
        \\   }
        \\   {
        \\     r0 += sfmpy(r6,r2):lib
        \\   }
        \\   {
        \\     r5 -= sfmpy(r0,r4):lib
        \\   }
        \\   {
        \\     r0 += sfmpy(r5,r2,p0):scale
        \\     jumpr r31
        \\   }
    );
}

fn __hexagon_udivdi3() callconv(.naked) noreturn {
    asm volatile (
        \\ {
        \\   r6 = cl0(r1:0)
        \\   r7 = cl0(r3:2)
        \\   r5:4 = r3:2
        \\   r3:2 = r1:0
        \\  }
        \\  {
        \\   r10 = sub(r7,r6)
        \\   r1:0 = #0
        \\   r15:14 = #1
        \\  }
        \\  {
        \\   r11 = add(r10,#1)
        \\   r13:12 = lsl(r5:4,r10)
        \\   r15:14 = lsl(r15:14,r10)
        \\  }
        \\  {
        \\   p0 = cmp.gtu(r5:4,r3:2)
        \\   loop0(1f,r11)
        \\  }
        \\  {
        \\   if (p0) jumpr r31
        \\  }
        \\  .falign
        \\ 1:
        \\  {
        \\   p0 = cmp.gtu(r13:12,r3:2)
        \\  }
        \\  {
        \\   r7:6 = sub(r3:2, r13:12)
        \\   r9:8 = add(r1:0, r15:14)
        \\  }
        \\  {
        \\   r1:0 = vmux(p0, r1:0, r9:8)
        \\   r3:2 = vmux(p0, r3:2, r7:6)
        \\  }
        \\  {
        \\   r15:14 = lsr(r15:14, #1)
        \\   r13:12 = lsr(r13:12, #1)
        \\  }:endloop0
        \\  {
        \\   jumpr r31
        \\  }
    );
}

fn __hexagon_umoddi3() callconv(.naked) noreturn {
    asm volatile (
        \\ {
        \\   r6 = cl0(r1:0)
        \\   r7 = cl0(r3:2)
        \\   r5:4 = r3:2
        \\   r3:2 = r1:0
        \\  }
        \\  {
        \\   r10 = sub(r7,r6)
        \\   r1:0 = #0
        \\   r15:14 = #1
        \\  }
        \\  {
        \\   r11 = add(r10,#1)
        \\   r13:12 = lsl(r5:4,r10)
        \\   r15:14 = lsl(r15:14,r10)
        \\  }
        \\  {
        \\   p0 = cmp.gtu(r5:4,r3:2)
        \\   loop0(1f,r11)
        \\  }
        \\  {
        \\   if (p0) jump .hexagon_umoddi3_return
        \\  }
        \\  .falign
        \\ 1:
        \\  {
        \\   p0 = cmp.gtu(r13:12,r3:2)
        \\  }
        \\  {
        \\   r7:6 = sub(r3:2, r13:12)
        \\   r9:8 = add(r1:0, r15:14)
        \\  }
        \\  {
        \\   r1:0 = vmux(p0, r1:0, r9:8)
        \\   r3:2 = vmux(p0, r3:2, r7:6)
        \\  }
        \\  {
        \\   r15:14 = lsr(r15:14, #1)
        \\   r13:12 = lsr(r13:12, #1)
        \\  }:endloop0
        \\
        \\ .hexagon_umoddi3_return:
        \\  {
        \\   r1:0 = r3:2
        \\   jumpr r31
        \\  }
    );
}

fn __hexagon_modsi3() callconv(.naked) noreturn {
    asm volatile (
        \\ {
        \\   p2 = cmp.ge(r0,#0)
        \\   r2 = abs(r0)
        \\   r1 = abs(r1)
        \\  }
        \\  {
        \\   r3 = cl0(r2)
        \\   r4 = cl0(r1)
        \\   p0 = cmp.gtu(r1,r2)
        \\  }
        \\  {
        \\   r3 = sub(r4,r3)
        \\   if (p0) jumpr r31
        \\  }
        \\  {
        \\   p1 = cmp.eq(r3,#0)
        \\   loop0(1f,r3)
        \\   r0 = r2
        \\   r2 = lsl(r1,r3)
        \\  }
        \\  .falign
        \\ 1:
        \\  {
        \\   p0 = cmp.gtu(r2,r0)
        \\   if (!p0.new) r0 = sub(r0,r2)
        \\   r2 = lsr(r2,#1)
        \\   if (p1) r1 = #0
        \\  }:endloop0
        \\  {
        \\   p0 = cmp.gtu(r2,r0)
        \\   if (!p0.new) r0 = sub(r0,r1)
        \\   if (p2) jumpr r31
        \\  }
        \\  {
        \\   r0 = neg(r0)
        \\   jumpr r31
        \\  }
    );
}

fn __hexagon_memcpy_likely_aligned_min32bytes_mult8bytes() callconv(.naked) noreturn {
    asm volatile (
        \\ {
        \\   p0 = bitsclr(r1,#7)
        \\   p0 = bitsclr(r0,#7)
        \\   if (p0.new) r5:4 = memd(r1)
        \\   r3 = #-3
        \\  }
        \\  {
        \\   if (!p0) jump .Lmemcpy_call
        \\   if (p0) memd(r0++#8) = r5:4
        \\   if (p0) r5:4 = memd(r1+#8)
        \\   r3 += lsr(r2,#3)
        \\  }
        \\  {
        \\   memd(r0++#8) = r5:4
        \\   r5:4 = memd(r1+#16)
        \\   r1 = add(r1,#24)
        \\   loop0(1f,r3)
        \\  }
        \\  .falign
        \\ 1:
        \\  {
        \\   memd(r0++#8) = r5:4
        \\   r5:4 = memd(r1++#8)
        \\  }:endloop0
        \\  {
        \\   memd(r0) = r5:4
        \\   r0 -= add(r2,#-8)
        \\   jumpr r31
        \\  }
        \\ .Lmemcpy_call:
        \\      jump memcpy@PLT
    );
}

fn __hexagon_udivsi3() callconv(.naked) noreturn {
    asm volatile (
        \\ {
        \\   r2 = cl0(r0)
        \\   r3 = cl0(r1)
        \\   r5:4 = combine(#1,#0)
        \\   p0 = cmp.gtu(r1,r0)
        \\  }
        \\  {
        \\   r6 = sub(r3,r2)
        \\   r4 = r1
        \\   r1:0 = combine(r0,r4)
        \\   if (p0) jumpr r31
        \\  }
        \\  {
        \\   r3:2 = vlslw(r5:4,r6)
        \\   loop0(1f,r6)
        \\  }
        \\  .falign
        \\ 1:
        \\  {
        \\   p0 = cmp.gtu(r2,r1)
        \\   if (!p0.new) r1 = sub(r1,r2)
        \\   if (!p0.new) r0 = add(r0,r3)
        \\   r3:2 = vlsrw(r3:2,#1)
        \\  }:endloop0
        \\  {
        \\   p0 = cmp.gtu(r2,r1)
        \\   if (!p0.new) r0 = add(r0,r3)
        \\   jumpr r31
        \\  }
    );
}

comptime {
    if (builtin.cpu.arch == .hexagon) {
        @export(__hexagon_divsi3, .{ .name = "__hexagon_divsi3", .linkage = common.linkage, .visibility = common.visibility });
        @export(__hexagon_udivmoddi4, .{ .name = "__hexagon_udivmoddi4", .linkage = common.linkage, .visibility = common.visibility });
        @export(__hexagon_umodsi3, .{ .name = "__hexagon_umodsi3", .linkage = common.linkage, .visibility = common.visibility });
        @export(__hexagon_sqrtf, .{ .name = "__hexagon_sqrtf", .linkage = common.linkage, .visibility = common.visibility });
        @export(__hexagon_udivmodsi4, .{ .name = "__hexagon_udivmodsi4", .linkage = common.linkage, .visibility = common.visibility });
        @export(__hexagon_moddi3, .{ .name = "__hexagon_moddi3", .linkage = common.linkage, .visibility = common.visibility });
        @export(__hexagon_divdi3, .{ .name = "__hexagon_divdi3", .linkage = common.linkage, .visibility = common.visibility });
        @export(__hexagon_divsf3, .{ .name = "__hexagon_divsf3", .linkage = common.linkage, .visibility = common.visibility });
        @export(__hexagon_udivdi3, .{ .name = "__hexagon_udivdi3", .linkage = common.linkage, .visibility = common.visibility });
        @export(__hexagon_umoddi3, .{ .name = "__hexagon_umoddi3", .linkage = common.linkage, .visibility = common.visibility });
        @export(__hexagon_modsi3, .{ .name = "__hexagon_modsi3", .linkage = common.linkage, .visibility = common.visibility });
        @export(__hexagon_memcpy_likely_aligned_min32bytes_mult8bytes, .{ .name = "__hexagon_memcpy_likely_aligned_min32bytes_mult8bytes", .linkage = common.linkage, .visibility = common.visibility });
        @export(__hexagon_udivsi3, .{ .name = "__hexagon_udivsi3", .linkage = common.linkage, .visibility = common.visibility });
    }
}
