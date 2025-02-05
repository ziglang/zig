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

fn __hexagon_adddf3() align(32) callconv(.naked) noreturn {
    asm volatile (
        \\  {
        \\   r4 = extractu(r1,#11,#20)
        \\   r5 = extractu(r3,#11,#20)
        \\   r13:12 = combine(##0x20000000,#0)
        \\  }
        \\  {
        \\   p3 = dfclass(r1:0,#2)
        \\   p3 = dfclass(r3:2,#2)
        \\   r9:8 = r13:12
        \\   p2 = cmp.gtu(r5,r4)
        \\  }
        \\  {
        \\   if (!p3) jump .Ladd_abnormal
        \\   if (p2) r1:0 = r3:2
        \\   if (p2) r3:2 = r1:0
        \\   if (p2) r5:4 = combine(r4,r5)
        \\  }
        \\  {
        \\   r13:12 = insert(r1:0,#52,#11 -2)
        \\   r9:8 = insert(r3:2,#52,#11 -2)
        \\   r15 = sub(r4,r5)
        \\   r7:6 = combine(#62,#1)
        \\  }
        \\
        \\
        \\
        \\
        \\
        \\ .Ladd_continue:
        \\  {
        \\   r15 = min(r15,r7)
        \\
        \\   r11:10 = neg(r13:12)
        \\   p2 = cmp.gt(r1,#-1)
        \\   r14 = #0
        \\  }
        \\  {
        \\   if (!p2) r13:12 = r11:10
        \\   r11:10 = extractu(r9:8,r15:14)
        \\   r9:8 = ASR(r9:8,r15)
        \\
        \\
        \\
        \\
        \\   r15:14 = #0
        \\  }
        \\  {
        \\   p1 = cmp.eq(r11:10,r15:14)
        \\   if (!p1.new) r8 = or(r8,r6)
        \\   r5 = add(r4,#-1024 -60)
        \\   p3 = cmp.gt(r3,#-1)
        \\  }
        \\  {
        \\   r13:12 = add(r13:12,r9:8)
        \\   r11:10 = sub(r13:12,r9:8)
        \\   r7:6 = combine(#54,##2045)
        \\  }
        \\  {
        \\   p0 = cmp.gtu(r4,r7)
        \\   p0 = !cmp.gtu(r4,r6)
        \\   if (!p0.new) jump:nt .Ladd_ovf_unf
        \\   if (!p3) r13:12 = r11:10
        \\  }
        \\  {
        \\   r1:0 = convert_d2df(r13:12)
        \\   p0 = cmp.eq(r13,#0)
        \\   p0 = cmp.eq(r12,#0)
        \\   if (p0.new) jump:nt .Ladd_zero
        \\  }
        \\  {
        \\   r1 += asl(r5,#20)
        \\   jumpr r31
        \\  }
        \\
        \\  .falign
        \\ .Ladd_zero:
        \\
        \\
        \\  {
        \\   r28 = USR
        \\   r1:0 = #0
        \\   r3 = #1
        \\  }
        \\  {
        \\   r28 = extractu(r28,#2,#22)
        \\   r3 = asl(r3,#31)
        \\  }
        \\  {
        \\   p0 = cmp.eq(r28,#2)
        \\   if (p0.new) r1 = xor(r1,r3)
        \\   jumpr r31
        \\  }
        \\  .falign
        \\ .Ladd_ovf_unf:
        \\  {
        \\   r1:0 = convert_d2df(r13:12)
        \\   p0 = cmp.eq(r13,#0)
        \\   p0 = cmp.eq(r12,#0)
        \\   if (p0.new) jump:nt .Ladd_zero
        \\  }
        \\  {
        \\   r28 = extractu(r1,#11,#20)
        \\   r1 += asl(r5,#20)
        \\  }
        \\  {
        \\   r5 = add(r5,r28)
        \\   r3:2 = combine(##0x00100000,#0)
        \\  }
        \\  {
        \\   p0 = cmp.gt(r5,##1024 +1024 -2)
        \\   if (p0.new) jump:nt .Ladd_ovf
        \\  }
        \\  {
        \\   p0 = cmp.gt(r5,#0)
        \\   if (p0.new) jumpr:t r31
        \\   r28 = sub(#1,r5)
        \\  }
        \\  {
        \\   r3:2 = insert(r1:0,#52,#0)
        \\   r1:0 = r13:12
        \\  }
        \\  {
        \\   r3:2 = lsr(r3:2,r28)
        \\  }
        \\  {
        \\   r1:0 = insert(r3:2,#63,#0)
        \\   jumpr r31
        \\  }
        \\  .falign
        \\ .Ladd_ovf:
        \\
        \\  {
        \\   r1:0 = r13:12
        \\   r28 = USR
        \\   r13:12 = combine(##0x7fefffff,#-1)
        \\  }
        \\  {
        \\   r5 = extractu(r28,#2,#22)
        \\   r28 = or(r28,#0x28)
        \\   r9:8 = combine(##0x7ff00000,#0)
        \\  }
        \\  {
        \\   USR = r28
        \\   r5 ^= lsr(r1,#31)
        \\   r28 = r5
        \\  }
        \\  {
        \\   p0 = !cmp.eq(r28,#1)
        \\   p0 = !cmp.eq(r5,#2)
        \\   if (p0.new) r13:12 = r9:8
        \\  }
        \\  {
        \\   r1:0 = insert(r13:12,#63,#0)
        \\  }
        \\  {
        \\   p0 = dfcmp.eq(r1:0,r1:0)
        \\   jumpr r31
        \\  }
        \\
        \\ .Ladd_abnormal:
        \\  {
        \\   r13:12 = extractu(r1:0,#63,#0)
        \\   r9:8 = extractu(r3:2,#63,#0)
        \\  }
        \\  {
        \\   p3 = cmp.gtu(r13:12,r9:8)
        \\   if (!p3.new) r1:0 = r3:2
        \\   if (!p3.new) r3:2 = r1:0
        \\  }
        \\  {
        \\
        \\   p0 = dfclass(r1:0,#0x0f)
        \\   if (!p0.new) jump:nt .Linvalid_nan_add
        \\   if (!p3) r13:12 = r9:8
        \\   if (!p3) r9:8 = r13:12
        \\  }
        \\  {
        \\
        \\
        \\   p1 = dfclass(r1:0,#0x08)
        \\   if (p1.new) jump:nt .Linf_add
        \\  }
        \\  {
        \\   p2 = dfclass(r3:2,#0x01)
        \\   if (p2.new) jump:nt .LB_zero
        \\   r13:12 = #0
        \\  }
        \\
        \\  {
        \\   p0 = dfclass(r1:0,#4)
        \\   if (p0.new) jump:nt .Ladd_two_subnormal
        \\   r13:12 = combine(##0x20000000,#0)
        \\  }
        \\  {
        \\   r4 = extractu(r1,#11,#20)
        \\   r5 = #1
        \\
        \\   r9:8 = asl(r9:8,#11 -2)
        \\  }
        \\
        \\
        \\
        \\  {
        \\   r13:12 = insert(r1:0,#52,#11 -2)
        \\   r15 = sub(r4,r5)
        \\   r7:6 = combine(#62,#1)
        \\   jump .Ladd_continue
        \\  }
        \\
        \\ .Ladd_two_subnormal:
        \\  {
        \\   r13:12 = extractu(r1:0,#63,#0)
        \\   r9:8 = extractu(r3:2,#63,#0)
        \\  }
        \\  {
        \\   r13:12 = neg(r13:12)
        \\   r9:8 = neg(r9:8)
        \\   p0 = cmp.gt(r1,#-1)
        \\   p1 = cmp.gt(r3,#-1)
        \\  }
        \\  {
        \\   if (p0) r13:12 = r1:0
        \\   if (p1) r9:8 = r3:2
        \\  }
        \\  {
        \\   r13:12 = add(r13:12,r9:8)
        \\  }
        \\  {
        \\   r9:8 = neg(r13:12)
        \\   p0 = cmp.gt(r13,#-1)
        \\   r3:2 = #0
        \\  }
        \\  {
        \\   if (!p0) r1:0 = r9:8
        \\   if (p0) r1:0 = r13:12
        \\   r3 = ##0x80000000
        \\  }
        \\  {
        \\   if (!p0) r1 = or(r1,r3)
        \\   p0 = dfcmp.eq(r1:0,r3:2)
        \\   if (p0.new) jump:nt .Lzero_plus_zero
        \\  }
        \\  {
        \\   jumpr r31
        \\  }
        \\
        \\ .Linvalid_nan_add:
        \\  {
        \\   r28 = convert_df2sf(r1:0)
        \\   p0 = dfclass(r3:2,#0x0f)
        \\   if (p0.new) r3:2 = r1:0
        \\  }
        \\  {
        \\   r2 = convert_df2sf(r3:2)
        \\   r1:0 = #-1
        \\   jumpr r31
        \\  }
        \\  .falign
        \\ .LB_zero:
        \\  {
        \\   p0 = dfcmp.eq(r13:12,r1:0)
        \\   if (!p0.new) jumpr:t r31
        \\  }
        \\
        \\
        \\
        \\
        \\ .Lzero_plus_zero:
        \\  {
        \\   p0 = cmp.eq(r1:0,r3:2)
        \\   if (p0.new) jumpr:t r31
        \\  }
        \\  {
        \\   r28 = USR
        \\  }
        \\  {
        \\   r28 = extractu(r28,#2,#22)
        \\   r1:0 = #0
        \\  }
        \\  {
        \\   p0 = cmp.eq(r28,#2)
        \\   if (p0.new) r1 = ##0x80000000
        \\   jumpr r31
        \\  }
        \\ .Linf_add:
        \\
        \\  {
        \\   p0 = !cmp.eq(r1,r3)
        \\   p0 = dfclass(r3:2,#8)
        \\   if (!p0.new) jumpr:t r31
        \\  }
        \\  {
        \\   r2 = ##0x7f800001
        \\  }
        \\  {
        \\   r1:0 = convert_sf2df(r2)
        \\   jumpr r31
        \\  }
    );
}

fn __hexagon_subdf3() align(32) callconv(.naked) noreturn {
    asm volatile (
        \\ {
        \\   r3 = togglebit(r3,#31)
        \\   jump ##__hexagon_adddf3
        \\ }
    );
}

fn __hexagon_divdf3() align(32) callconv(.naked) noreturn {
    asm volatile (
        \\  {
        \\   p2 = dfclass(r1:0,#0x02)
        \\   p2 = dfclass(r3:2,#0x02)
        \\   r13:12 = combine(r3,r1)
        \\   r28 = xor(r1,r3)
        \\  }
        \\  {
        \\   if (!p2) jump .Ldiv_abnormal
        \\   r7:6 = extractu(r3:2,#23,#52 -23)
        \\   r8 = ##0x3f800001
        \\  }
        \\  {
        \\   r9 = or(r8,r6)
        \\   r13 = extractu(r13,#11,#52 -32)
        \\   r12 = extractu(r12,#11,#52 -32)
        \\   p3 = cmp.gt(r28,#-1)
        \\  }
        \\
        \\
        \\ .Ldenorm_continue:
        \\  {
        \\   r11,p0 = sfrecipa(r8,r9)
        \\   r10 = and(r8,#-2)
        \\   r28 = #1
        \\   r12 = sub(r12,r13)
        \\  }
        \\
        \\
        \\  {
        \\   r10 -= sfmpy(r11,r9):lib
        \\   r1 = insert(r28,#11 +1,#52 -32)
        \\   r13 = ##0x00800000 << 3
        \\  }
        \\  {
        \\   r11 += sfmpy(r11,r10):lib
        \\   r3 = insert(r28,#11 +1,#52 -32)
        \\   r10 = and(r8,#-2)
        \\  }
        \\  {
        \\   r10 -= sfmpy(r11,r9):lib
        \\   r5 = #-0x3ff +1
        \\   r4 = #0x3ff -1
        \\  }
        \\  {
        \\   r11 += sfmpy(r11,r10):lib
        \\   p1 = cmp.gt(r12,r5)
        \\   p1 = !cmp.gt(r12,r4)
        \\  }
        \\  {
        \\   r13 = insert(r11,#23,#3)
        \\   r5:4 = #0
        \\   r12 = add(r12,#-61)
        \\  }
        \\
        \\
        \\
        \\
        \\  {
        \\   r13 = add(r13,#((-3) << 3))
        \\  }
        \\  { r7:6 = mpyu(r13,r1); r1:0 = asl(r1:0,# ( 15 )); }; { r6 = # 0; r1:0 -= mpyu(r7,r2); r15:14 = mpyu(r7,r3); }; { r5:4 += ASL(r7:6, # ( 14 )); r1:0 -= asl(r15:14, # 32); }
        \\  { r7:6 = mpyu(r13,r1); r1:0 = asl(r1:0,# ( 15 )); }; { r6 = # 0; r1:0 -= mpyu(r7,r2); r15:14 = mpyu(r7,r3); }; { r5:4 += ASR(r7:6, # ( 1 )); r1:0 -= asl(r15:14, # 32); }
        \\  { r7:6 = mpyu(r13,r1); r1:0 = asl(r1:0,# ( 15 )); }; { r6 = # 0; r1:0 -= mpyu(r7,r2); r15:14 = mpyu(r7,r3); }; { r5:4 += ASR(r7:6, # ( 16 )); r1:0 -= asl(r15:14, # 32); }
        \\  { r7:6 = mpyu(r13,r1); r1:0 = asl(r1:0,# ( 15 )); }; { r6 = # 0; r1:0 -= mpyu(r7,r2); r15:14 = mpyu(r7,r3); }; { r5:4 += ASR(r7:6, # ( 31 )); r1:0 -= asl(r15:14, # 32); r7:6=# ( 0 ); }
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\  {
        \\
        \\   r15:14 = sub(r1:0,r3:2)
        \\   p0 = cmp.gtu(r3:2,r1:0)
        \\
        \\   if (!p0.new) r6 = #2
        \\  }
        \\  {
        \\   r5:4 = add(r5:4,r7:6)
        \\   if (!p0) r1:0 = r15:14
        \\   r15:14 = #0
        \\  }
        \\  {
        \\   p0 = cmp.eq(r1:0,r15:14)
        \\   if (!p0.new) r4 = or(r4,r28)
        \\  }
        \\  {
        \\   r7:6 = neg(r5:4)
        \\  }
        \\  {
        \\   if (!p3) r5:4 = r7:6
        \\  }
        \\  {
        \\   r1:0 = convert_d2df(r5:4)
        \\   if (!p1) jump .Ldiv_ovf_unf
        \\  }
        \\  {
        \\   r1 += asl(r12,#52 -32)
        \\   jumpr r31
        \\  }
        \\
        \\ .Ldiv_ovf_unf:
        \\  {
        \\   r1 += asl(r12,#52 -32)
        \\   r13 = extractu(r1,#11,#52 -32)
        \\  }
        \\  {
        \\   r7:6 = abs(r5:4)
        \\   r12 = add(r12,r13)
        \\  }
        \\  {
        \\   p0 = cmp.gt(r12,##0x3ff +0x3ff)
        \\   if (p0.new) jump:nt .Ldiv_ovf
        \\  }
        \\  {
        \\   p0 = cmp.gt(r12,#0)
        \\   if (p0.new) jump:nt .Ldiv_possible_unf
        \\  }
        \\  {
        \\   r13 = add(clb(r7:6),#-1)
        \\   r12 = sub(#7,r12)
        \\   r10 = USR
        \\   r11 = #63
        \\  }
        \\  {
        \\   r13 = min(r12,r11)
        \\   r11 = or(r10,#0x030)
        \\   r7:6 = asl(r7:6,r13)
        \\   r12 = #0
        \\  }
        \\  {
        \\   r15:14 = extractu(r7:6,r13:12)
        \\   r7:6 = lsr(r7:6,r13)
        \\   r3:2 = #1
        \\  }
        \\  {
        \\   p0 = cmp.gtu(r3:2,r15:14)
        \\   if (!p0.new) r6 = or(r2,r6)
        \\   r7 = setbit(r7,#52 -32+4)
        \\  }
        \\  {
        \\   r5:4 = neg(r7:6)
        \\   p0 = bitsclr(r6,#(1<<4)-1)
        \\   if (!p0.new) r10 = r11
        \\  }
        \\  {
        \\   USR = r10
        \\   if (p3) r5:4 = r7:6
        \\   r10 = #-0x3ff -(52 +4)
        \\  }
        \\  {
        \\   r1:0 = convert_d2df(r5:4)
        \\  }
        \\  {
        \\   r1 += asl(r10,#52 -32)
        \\   jumpr r31
        \\  }
        \\
        \\
        \\ .Ldiv_possible_unf:
        \\
        \\
        \\  {
        \\   r3:2 = extractu(r1:0,#63,#0)
        \\   r15:14 = combine(##0x00100000,#0)
        \\   r10 = #0x7FFF
        \\  }
        \\  {
        \\   p0 = dfcmp.eq(r15:14,r3:2)
        \\   p0 = bitsset(r7,r10)
        \\  }
        \\
        \\
        \\
        \\
        \\
        \\
        \\  {
        \\   if (!p0) jumpr r31
        \\   r10 = USR
        \\  }
        \\
        \\  {
        \\   r10 = or(r10,#0x30)
        \\  }
        \\  {
        \\   USR = r10
        \\  }
        \\  {
        \\   p0 = dfcmp.eq(r1:0,r1:0)
        \\   jumpr r31
        \\  }
        \\
        \\ .Ldiv_ovf:
        \\
        \\
        \\
        \\  {
        \\   r10 = USR
        \\   r3:2 = combine(##0x7fefffff,#-1)
        \\   r1 = mux(p3,#0,#-1)
        \\  }
        \\  {
        \\   r7:6 = combine(##0x7ff00000,#0)
        \\   r5 = extractu(r10,#2,#22)
        \\   r10 = or(r10,#0x28)
        \\  }
        \\  {
        \\   USR = r10
        \\   r5 ^= lsr(r1,#31)
        \\   r4 = r5
        \\  }
        \\  {
        \\   p0 = !cmp.eq(r4,#1)
        \\   p0 = !cmp.eq(r5,#2)
        \\   if (p0.new) r3:2 = r7:6
        \\   p0 = dfcmp.eq(r3:2,r3:2)
        \\  }
        \\  {
        \\   r1:0 = insert(r3:2,#63,#0)
        \\   jumpr r31
        \\  }
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\ .Ldiv_abnormal:
        \\  {
        \\   p0 = dfclass(r1:0,#0x0F)
        \\   p0 = dfclass(r3:2,#0x0F)
        \\   p3 = cmp.gt(r28,#-1)
        \\  }
        \\  {
        \\   p1 = dfclass(r1:0,#0x08)
        \\   p1 = dfclass(r3:2,#0x08)
        \\  }
        \\  {
        \\   p2 = dfclass(r1:0,#0x01)
        \\   p2 = dfclass(r3:2,#0x01)
        \\  }
        \\  {
        \\   if (!p0) jump .Ldiv_nan
        \\   if (p1) jump .Ldiv_invalid
        \\  }
        \\  {
        \\   if (p2) jump .Ldiv_invalid
        \\  }
        \\  {
        \\   p2 = dfclass(r1:0,#(0x0F ^ 0x01))
        \\   p2 = dfclass(r3:2,#(0x0F ^ 0x08))
        \\  }
        \\  {
        \\   p1 = dfclass(r1:0,#(0x0F ^ 0x08))
        \\   p1 = dfclass(r3:2,#(0x0F ^ 0x01))
        \\  }
        \\  {
        \\   if (!p2) jump .Ldiv_zero_result
        \\   if (!p1) jump .Ldiv_inf_result
        \\  }
        \\
        \\
        \\
        \\
        \\
        \\  {
        \\   p0 = dfclass(r1:0,#0x02)
        \\   p1 = dfclass(r3:2,#0x02)
        \\   r10 = ##0x00100000
        \\  }
        \\  {
        \\   r13:12 = combine(r3,r1)
        \\   r1 = insert(r10,#11 +1,#52 -32)
        \\   r3 = insert(r10,#11 +1,#52 -32)
        \\  }
        \\  {
        \\   if (p0) r1 = or(r1,r10)
        \\   if (p1) r3 = or(r3,r10)
        \\  }
        \\  {
        \\   r5 = add(clb(r1:0),#-11)
        \\   r4 = add(clb(r3:2),#-11)
        \\   r10 = #1
        \\  }
        \\  {
        \\   r12 = extractu(r12,#11,#52 -32)
        \\   r13 = extractu(r13,#11,#52 -32)
        \\  }
        \\  {
        \\   r1:0 = asl(r1:0,r5)
        \\   r3:2 = asl(r3:2,r4)
        \\   if (!p0) r12 = sub(r10,r5)
        \\   if (!p1) r13 = sub(r10,r4)
        \\  }
        \\  {
        \\   r7:6 = extractu(r3:2,#23,#52 -23)
        \\  }
        \\  {
        \\   r9 = or(r8,r6)
        \\   jump .Ldenorm_continue
        \\  }
        \\
        \\ .Ldiv_zero_result:
        \\  {
        \\   r1 = xor(r1,r3)
        \\   r3:2 = #0
        \\  }
        \\  {
        \\   r1:0 = insert(r3:2,#63,#0)
        \\   jumpr r31
        \\  }
        \\ .Ldiv_inf_result:
        \\  {
        \\   p2 = dfclass(r3:2,#0x01)
        \\   p2 = dfclass(r1:0,#(0x0F ^ 0x08))
        \\  }
        \\  {
        \\   r10 = USR
        \\   if (!p2) jump 1f
        \\   r1 = xor(r1,r3)
        \\  }
        \\  {
        \\   r10 = or(r10,#0x04)
        \\  }
        \\  {
        \\   USR = r10
        \\  }
        \\ 1:
        \\  {
        \\   r3:2 = combine(##0x7ff00000,#0)
        \\   p0 = dfcmp.uo(r3:2,r3:2)
        \\  }
        \\  {
        \\   r1:0 = insert(r3:2,#63,#0)
        \\   jumpr r31
        \\  }
        \\ .Ldiv_nan:
        \\  {
        \\   p0 = dfclass(r1:0,#0x10)
        \\   p1 = dfclass(r3:2,#0x10)
        \\   if (!p0.new) r1:0 = r3:2
        \\   if (!p1.new) r3:2 = r1:0
        \\  }
        \\  {
        \\   r5 = convert_df2sf(r1:0)
        \\   r4 = convert_df2sf(r3:2)
        \\  }
        \\  {
        \\   r1:0 = #-1
        \\   jumpr r31
        \\  }
        \\
        \\ .Ldiv_invalid:
        \\  {
        \\   r10 = ##0x7f800001
        \\  }
        \\  {
        \\   r1:0 = convert_sf2df(r10)
        \\   jumpr r31
        \\  }
    );
}

fn __hexagon_muldf3() align(32) callconv(.naked) noreturn {
    asm volatile (
        \\  {
        \\   p0 = dfclass(r1:0,#2)
        \\   p0 = dfclass(r3:2,#2)
        \\   r13:12 = combine(##0x40000000,#0)
        \\  }
        \\  {
        \\   r13:12 = insert(r1:0,#52,#11 -1)
        \\   r5:4 = asl(r3:2,#11 -1)
        \\   r28 = #-1024
        \\   r9:8 = #1
        \\  }
        \\  {
        \\   r7:6 = mpyu(r4,r13)
        \\   r5:4 = insert(r9:8,#2,#62)
        \\  }
        \\
        \\
        \\
        \\
        \\  {
        \\   r15:14 = mpyu(r12,r4)
        \\   r7:6 += mpyu(r12,r5)
        \\  }
        \\  {
        \\   r7:6 += lsr(r15:14,#32)
        \\   r11:10 = mpyu(r13,r5)
        \\   r5:4 = combine(##1024 +1024 -4,#0)
        \\  }
        \\  {
        \\   r11:10 += lsr(r7:6,#32)
        \\   if (!p0) jump .Lmul_abnormal
        \\   p1 = cmp.eq(r14,#0)
        \\   p1 = cmp.eq(r6,#0)
        \\  }
        \\  {
        \\   if (!p1) r10 = or(r10,r8)
        \\   r6 = extractu(r1,#11,#20)
        \\   r7 = extractu(r3,#11,#20)
        \\  }
        \\  {
        \\   r15:14 = neg(r11:10)
        \\   r6 += add(r28,r7)
        \\   r28 = xor(r1,r3)
        \\  }
        \\  {
        \\   if (!p2.new) r11:10 = r15:14
        \\   p2 = cmp.gt(r28,#-1)
        \\   p0 = !cmp.gt(r6,r5)
        \\   p0 = cmp.gt(r6,r4)
        \\   if (!p0.new) jump:nt .Lmul_ovf_unf
        \\  }
        \\  {
        \\   r1:0 = convert_d2df(r11:10)
        \\   r6 = add(r6,#-1024 -58)
        \\  }
        \\  {
        \\   r1 += asl(r6,#20)
        \\   jumpr r31
        \\  }
        \\
        \\  .falign
        \\ .Lmul_possible_unf:
        \\  {
        \\   p0 = cmp.eq(r0,#0)
        \\   p0 = bitsclr(r1,r4)
        \\   if (!p0.new) jumpr:t r31
        \\   r5 = #0x7fff
        \\  }
        \\  {
        \\   p0 = bitsset(r13,r5)
        \\   r4 = USR
        \\   r5 = #0x030
        \\  }
        \\  {
        \\   if (p0) r4 = or(r4,r5)
        \\  }
        \\  {
        \\   USR = r4
        \\  }
        \\  {
        \\   p0 = dfcmp.eq(r1:0,r1:0)
        \\   jumpr r31
        \\  }
        \\  .falign
        \\ .Lmul_ovf_unf:
        \\  {
        \\   r1:0 = convert_d2df(r11:10)
        \\   r13:12 = abs(r11:10)
        \\   r7 = add(r6,#-1024 -58)
        \\  }
        \\  {
        \\   r1 += asl(r7,#20)
        \\   r7 = extractu(r1,#11,#20)
        \\   r4 = ##0x7FEFFFFF
        \\  }
        \\  {
        \\   r7 += add(r6,##-1024 -58)
        \\
        \\   r5 = #0
        \\  }
        \\  {
        \\   p0 = cmp.gt(r7,##1024 +1024 -2)
        \\   if (p0.new) jump:nt .Lmul_ovf
        \\  }
        \\  {
        \\   p0 = cmp.gt(r7,#0)
        \\   if (p0.new) jump:nt .Lmul_possible_unf
        \\   r5 = sub(r6,r5)
        \\   r28 = #63
        \\  }
        \\  {
        \\   r4 = #0
        \\   r5 = sub(#5,r5)
        \\  }
        \\  {
        \\   p3 = cmp.gt(r11,#-1)
        \\   r5 = min(r5,r28)
        \\   r11:10 = r13:12
        \\  }
        \\  {
        \\   r28 = USR
        \\   r15:14 = extractu(r11:10,r5:4)
        \\  }
        \\  {
        \\   r11:10 = asr(r11:10,r5)
        \\   r4 = #0x0030
        \\   r1 = insert(r9,#11,#20)
        \\  }
        \\  {
        \\   p0 = cmp.gtu(r9:8,r15:14)
        \\   if (!p0.new) r10 = or(r10,r8)
        \\   r11 = setbit(r11,#20 +3)
        \\  }
        \\  {
        \\   r15:14 = neg(r11:10)
        \\   p1 = bitsclr(r10,#0x7)
        \\   if (!p1.new) r28 = or(r4,r28)
        \\  }
        \\  {
        \\   if (!p3) r11:10 = r15:14
        \\   USR = r28
        \\  }
        \\  {
        \\   r1:0 = convert_d2df(r11:10)
        \\   p0 = dfcmp.eq(r1:0,r1:0)
        \\  }
        \\  {
        \\   r1 = insert(r9,#11 -1,#20 +1)
        \\   jumpr r31
        \\  }
        \\  .falign
        \\ .Lmul_ovf:
        \\
        \\  {
        \\   r28 = USR
        \\   r13:12 = combine(##0x7fefffff,#-1)
        \\   r1:0 = r11:10
        \\  }
        \\  {
        \\   r14 = extractu(r28,#2,#22)
        \\   r28 = or(r28,#0x28)
        \\   r5:4 = combine(##0x7ff00000,#0)
        \\  }
        \\  {
        \\   USR = r28
        \\   r14 ^= lsr(r1,#31)
        \\   r28 = r14
        \\  }
        \\  {
        \\   p0 = !cmp.eq(r28,#1)
        \\   p0 = !cmp.eq(r14,#2)
        \\   if (p0.new) r13:12 = r5:4
        \\   p0 = dfcmp.eq(r1:0,r1:0)
        \\  }
        \\  {
        \\   r1:0 = insert(r13:12,#63,#0)
        \\   jumpr r31
        \\  }
        \\
        \\ .Lmul_abnormal:
        \\  {
        \\   r13:12 = extractu(r1:0,#63,#0)
        \\   r5:4 = extractu(r3:2,#63,#0)
        \\  }
        \\  {
        \\   p3 = cmp.gtu(r13:12,r5:4)
        \\   if (!p3.new) r1:0 = r3:2
        \\   if (!p3.new) r3:2 = r1:0
        \\  }
        \\  {
        \\
        \\   p0 = dfclass(r1:0,#0x0f)
        \\   if (!p0.new) jump:nt .Linvalid_nan
        \\   if (!p3) r13:12 = r5:4
        \\   if (!p3) r5:4 = r13:12
        \\  }
        \\  {
        \\
        \\   p1 = dfclass(r1:0,#0x08)
        \\   p1 = dfclass(r3:2,#0x0e)
        \\  }
        \\  {
        \\
        \\
        \\   p0 = dfclass(r1:0,#0x08)
        \\   p0 = dfclass(r3:2,#0x01)
        \\  }
        \\  {
        \\   if (p1) jump .Ltrue_inf
        \\   p2 = dfclass(r3:2,#0x01)
        \\  }
        \\  {
        \\   if (p0) jump .Linvalid_zeroinf
        \\   if (p2) jump .Ltrue_zero
        \\   r28 = ##0x7c000000
        \\  }
        \\
        \\
        \\
        \\
        \\
        \\  {
        \\   p0 = bitsclr(r1,r28)
        \\   if (p0.new) jump:nt .Lmul_tiny
        \\  }
        \\  {
        \\   r28 = cl0(r5:4)
        \\  }
        \\  {
        \\   r28 = add(r28,#-11)
        \\  }
        \\  {
        \\   r5:4 = asl(r5:4,r28)
        \\  }
        \\  {
        \\   r3:2 = insert(r5:4,#63,#0)
        \\   r1 -= asl(r28,#20)
        \\  }
        \\  jump __hexagon_muldf3
        \\ .Lmul_tiny:
        \\  {
        \\   r28 = USR
        \\   r1:0 = xor(r1:0,r3:2)
        \\  }
        \\  {
        \\   r28 = or(r28,#0x30)
        \\   r1:0 = insert(r9:8,#63,#0)
        \\   r5 = extractu(r28,#2,#22)
        \\  }
        \\  {
        \\   USR = r28
        \\   p0 = cmp.gt(r5,#1)
        \\   if (!p0.new) r0 = #0
        \\   r5 ^= lsr(r1,#31)
        \\  }
        \\  {
        \\   p0 = cmp.eq(r5,#3)
        \\   if (!p0.new) r0 = #0
        \\   jumpr r31
        \\  }
        \\ .Linvalid_zeroinf:
        \\  {
        \\   r28 = USR
        \\  }
        \\  {
        \\   r1:0 = #-1
        \\   r28 = or(r28,#2)
        \\  }
        \\  {
        \\   USR = r28
        \\  }
        \\  {
        \\   p0 = dfcmp.uo(r1:0,r1:0)
        \\   jumpr r31
        \\  }
        \\ .Linvalid_nan:
        \\  {
        \\   p0 = dfclass(r3:2,#0x0f)
        \\   r28 = convert_df2sf(r1:0)
        \\   if (p0.new) r3:2 = r1:0
        \\  }
        \\  {
        \\   r2 = convert_df2sf(r3:2)
        \\   r1:0 = #-1
        \\   jumpr r31
        \\  }
        \\  .falign
        \\ .Ltrue_zero:
        \\  {
        \\   r1:0 = r3:2
        \\   r3:2 = r1:0
        \\  }
        \\ .Ltrue_inf:
        \\  {
        \\   r3 = extract(r3,#1,#31)
        \\  }
        \\  {
        \\   r1 ^= asl(r3,#31)
        \\   jumpr r31
        \\  }
    );
}

fn __hexagon_sqrtdf2() align(32) callconv(.naked) noreturn {
    asm volatile (
        \\  {
        \\   r15:14 = extractu(r1:0,#23 +1,#52 -23)
        \\   r28 = extractu(r1,#11,#52 -32)
        \\   r5:4 = combine(##0x3f000004,#1)
        \\  }
        \\  {
        \\   p2 = dfclass(r1:0,#0x02)
        \\   p2 = cmp.gt(r1,#-1)
        \\   if (!p2.new) jump:nt .Lsqrt_abnormal
        \\   r9 = or(r5,r14)
        \\  }
        \\
        \\ .Ldenormal_restart:
        \\  {
        \\   r11:10 = r1:0
        \\   r7,p0 = sfinvsqrta(r9)
        \\   r5 = and(r5,#-16)
        \\   r3:2 = #0
        \\  }
        \\  {
        \\   r3 += sfmpy(r7,r9):lib
        \\   r2 += sfmpy(r7,r5):lib
        \\   r6 = r5
        \\
        \\
        \\   r9 = and(r28,#1)
        \\  }
        \\  {
        \\   r6 -= sfmpy(r3,r2):lib
        \\   r11 = insert(r4,#11 +1,#52 -32)
        \\   p1 = cmp.gtu(r9,#0)
        \\  }
        \\  {
        \\   r3 += sfmpy(r3,r6):lib
        \\   r2 += sfmpy(r2,r6):lib
        \\   r6 = r5
        \\   r9 = mux(p1,#8,#9)
        \\  }
        \\  {
        \\   r6 -= sfmpy(r3,r2):lib
        \\   r11:10 = asl(r11:10,r9)
        \\   r9 = mux(p1,#3,#2)
        \\  }
        \\  {
        \\   r2 += sfmpy(r2,r6):lib
        \\
        \\   r15:14 = asl(r11:10,r9)
        \\  }
        \\  {
        \\   r2 = and(r2,##0x007fffff)
        \\  }
        \\  {
        \\   r2 = add(r2,##0x00800000 - 3)
        \\   r9 = mux(p1,#7,#8)
        \\  }
        \\  {
        \\   r8 = asl(r2,r9)
        \\   r9 = mux(p1,#15-(1+1),#15-(1+0))
        \\  }
        \\  {
        \\   r13:12 = mpyu(r8,r15)
        \\  }
        \\  {
        \\   r1:0 = asl(r11:10,#15)
        \\   r15:14 = mpyu(r13,r13)
        \\   p1 = cmp.eq(r0,r0)
        \\  }
        \\  {
        \\   r1:0 -= asl(r15:14,#15)
        \\   r15:14 = mpyu(r13,r12)
        \\   p2 = cmp.eq(r0,r0)
        \\  }
        \\  {
        \\   r1:0 -= lsr(r15:14,#16)
        \\   p3 = cmp.eq(r0,r0)
        \\  }
        \\  {
        \\   r1:0 = mpyu(r1,r8)
        \\  }
        \\  {
        \\   r13:12 += lsr(r1:0,r9)
        \\   r9 = add(r9,#16)
        \\   r1:0 = asl(r11:10,#31)
        \\  }
        \\
        \\  {
        \\   r15:14 = mpyu(r13,r13)
        \\   r1:0 -= mpyu(r13,r12)
        \\  }
        \\  {
        \\   r1:0 -= asl(r15:14,#31)
        \\   r15:14 = mpyu(r12,r12)
        \\  }
        \\  {
        \\   r1:0 -= lsr(r15:14,#33)
        \\  }
        \\  {
        \\   r1:0 = mpyu(r1,r8)
        \\  }
        \\  {
        \\   r13:12 += lsr(r1:0,r9)
        \\   r9 = add(r9,#16)
        \\   r1:0 = asl(r11:10,#47)
        \\  }
        \\
        \\  {
        \\   r15:14 = mpyu(r13,r13)
        \\  }
        \\  {
        \\   r1:0 -= asl(r15:14,#47)
        \\   r15:14 = mpyu(r13,r12)
        \\  }
        \\  {
        \\   r1:0 -= asl(r15:14,#16)
        \\   r15:14 = mpyu(r12,r12)
        \\  }
        \\  {
        \\   r1:0 -= lsr(r15:14,#17)
        \\  }
        \\  {
        \\   r1:0 = mpyu(r1,r8)
        \\  }
        \\  {
        \\   r13:12 += lsr(r1:0,r9)
        \\  }
        \\  {
        \\   r3:2 = mpyu(r13,r12)
        \\   r5:4 = mpyu(r12,r12)
        \\   r15:14 = #0
        \\   r1:0 = #0
        \\  }
        \\  {
        \\   r3:2 += lsr(r5:4,#33)
        \\   r5:4 += asl(r3:2,#33)
        \\   p1 = cmp.eq(r0,r0)
        \\  }
        \\  {
        \\   r7:6 = mpyu(r13,r13)
        \\   r1:0 = sub(r1:0,r5:4,p1):carry
        \\   r9:8 = #1
        \\  }
        \\  {
        \\   r7:6 += lsr(r3:2,#31)
        \\   r9:8 += asl(r13:12,#1)
        \\  }
        \\
        \\
        \\
        \\
        \\
        \\  {
        \\   r15:14 = sub(r11:10,r7:6,p1):carry
        \\   r5:4 = sub(r1:0,r9:8,p2):carry
        \\
        \\
        \\
        \\
        \\   r7:6 = #1
        \\   r11:10 = #0
        \\  }
        \\  {
        \\   r3:2 = sub(r15:14,r11:10,p2):carry
        \\   r7:6 = add(r13:12,r7:6)
        \\   r28 = add(r28,#-0x3ff)
        \\  }
        \\  {
        \\
        \\   if (p2) r13:12 = r7:6
        \\   if (p2) r1:0 = r5:4
        \\   if (p2) r15:14 = r3:2
        \\  }
        \\  {
        \\   r5:4 = sub(r1:0,r9:8,p3):carry
        \\   r7:6 = #1
        \\   r28 = asr(r28,#1)
        \\  }
        \\  {
        \\   r3:2 = sub(r15:14,r11:10,p3):carry
        \\   r7:6 = add(r13:12,r7:6)
        \\  }
        \\  {
        \\   if (p3) r13:12 = r7:6
        \\   if (p3) r1:0 = r5:4
        \\
        \\
        \\
        \\
        \\
        \\   r2 = #1
        \\  }
        \\  {
        \\   p0 = cmp.eq(r1:0,r11:10)
        \\   if (!p0.new) r12 = or(r12,r2)
        \\   r3 = cl0(r13:12)
        \\   r28 = add(r28,#-63)
        \\  }
        \\
        \\
        \\
        \\  {
        \\   r1:0 = convert_ud2df(r13:12)
        \\   r28 = add(r28,r3)
        \\  }
        \\  {
        \\   r1 += asl(r28,#52 -32)
        \\   jumpr r31
        \\  }
        \\ .Lsqrt_abnormal:
        \\  {
        \\   p0 = dfclass(r1:0,#0x01)
        \\   if (p0.new) jumpr:t r31
        \\  }
        \\  {
        \\   p0 = dfclass(r1:0,#0x10)
        \\   if (p0.new) jump:nt .Lsqrt_nan
        \\  }
        \\  {
        \\   p0 = cmp.gt(r1,#-1)
        \\   if (!p0.new) jump:nt .Lsqrt_invalid_neg
        \\   if (!p0.new) r28 = ##0x7F800001
        \\  }
        \\  {
        \\   p0 = dfclass(r1:0,#0x08)
        \\   if (p0.new) jumpr:nt r31
        \\  }
        \\
        \\
        \\  {
        \\   r1:0 = extractu(r1:0,#52,#0)
        \\  }
        \\  {
        \\   r28 = add(clb(r1:0),#-11)
        \\  }
        \\  {
        \\   r1:0 = asl(r1:0,r28)
        \\   r28 = sub(#1,r28)
        \\  }
        \\  {
        \\   r1 = insert(r28,#1,#52 -32)
        \\  }
        \\  {
        \\   r3:2 = extractu(r1:0,#23 +1,#52 -23)
        \\   r5 = ##0x3f000004
        \\  }
        \\  {
        \\   r9 = or(r5,r2)
        \\   r5 = and(r5,#-16)
        \\   jump .Ldenormal_restart
        \\  }
        \\ .Lsqrt_nan:
        \\  {
        \\   r28 = convert_df2sf(r1:0)
        \\   r1:0 = #-1
        \\   jumpr r31
        \\  }
        \\ .Lsqrt_invalid_neg:
        \\  {
        \\   r1:0 = convert_sf2df(r28)
        \\   jumpr r31
        \\  }
    );
}

comptime {
    if (builtin.cpu.arch == .hexagon) {
        @export(&__hexagon_adddf3, .{ .name = "__hexagon_adddf3", .linkage = common.linkage, .visibility = common.visibility });
        @export(&__hexagon_adddf3, .{ .name = "__hexagon_fast_adddf3", .linkage = common.linkage, .visibility = common.visibility });
        @export(&__hexagon_subdf3, .{ .name = "__hexagon_subdf3", .linkage = common.linkage, .visibility = common.visibility });
        @export(&__hexagon_subdf3, .{ .name = "__hexagon_fast_subdf3", .linkage = common.linkage, .visibility = common.visibility });
        @export(&__hexagon_divdf3, .{ .name = "__hexagon_divdf3", .linkage = common.linkage, .visibility = common.visibility });
        @export(&__hexagon_divdf3, .{ .name = "__hexagon_fast_divdf3", .linkage = common.linkage, .visibility = common.visibility });
        @export(&__hexagon_muldf3, .{ .name = "__hexagon_muldf3", .linkage = common.linkage, .visibility = common.visibility });
        @export(&__hexagon_muldf3, .{ .name = "__hexagon_fast_muldf3", .linkage = common.linkage, .visibility = common.visibility });
        @export(&__hexagon_sqrtdf2, .{ .name = "__hexagon_sqrtdf2", .linkage = common.linkage, .visibility = common.visibility });
        @export(&__hexagon_sqrtdf2, .{ .name = "__hexagon_fast2_sqrtdf2", .linkage = common.linkage, .visibility = common.visibility });
        @export(&__hexagon_sqrtdf2, .{ .name = "__hexagon_sqrt", .linkage = common.linkage, .visibility = common.visibility });
        @export(&__hexagon_divsf3, .{ .name = "__hexagon_divsf3", .linkage = common.linkage, .visibility = common.visibility });
        @export(&__hexagon_divsf3, .{ .name = "__hexagon_fast_divsf3", .linkage = common.linkage, .visibility = common.visibility });
        @export(&__hexagon_divsi3, .{ .name = "__hexagon_divsi3", .linkage = common.linkage, .visibility = common.visibility });
        @export(&__hexagon_umodsi3, .{ .name = "__hexagon_umodsi3", .linkage = common.linkage, .visibility = common.visibility });
        @export(&__hexagon_sqrtf, .{ .name = "__hexagon_sqrtf", .linkage = common.linkage, .visibility = common.visibility });
        @export(&__hexagon_sqrtf, .{ .name = "__hexagon_fast2_sqrtf", .linkage = common.linkage, .visibility = common.visibility });
        @export(&__hexagon_moddi3, .{ .name = "__hexagon_moddi3", .linkage = common.linkage, .visibility = common.visibility });
        @export(&__hexagon_divdi3, .{ .name = "__hexagon_divdi3", .linkage = common.linkage, .visibility = common.visibility });
        @export(&__hexagon_udivdi3, .{ .name = "__hexagon_udivdi3", .linkage = common.linkage, .visibility = common.visibility });
        @export(&__hexagon_umoddi3, .{ .name = "__hexagon_umoddi3", .linkage = common.linkage, .visibility = common.visibility });
        @export(&__hexagon_modsi3, .{ .name = "__hexagon_modsi3", .linkage = common.linkage, .visibility = common.visibility });
        @export(&__hexagon_memcpy_likely_aligned_min32bytes_mult8bytes, .{ .name = "__hexagon_memcpy_likely_aligned_min32bytes_mult8bytes", .linkage = common.linkage, .visibility = common.visibility });
        @export(&__hexagon_udivsi3, .{ .name = "__hexagon_udivsi3", .linkage = common.linkage, .visibility = common.visibility });
    }
}
