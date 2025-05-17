const checkExpected = math.checkExpected;
const Compare = math.Compare;
const fmax = math.fmax;
const fmin = math.fmin;
const Gpr = math.Gpr;
const inf = math.inf;
const math = @import("math.zig");
const nan = math.nan;
const RoundBitsUp = math.RoundBitsUp;
const Scalar = math.Scalar;
const Sse = math.Sse;
const tmin = math.tmin;

inline fn runtime(comptime Type: type, comptime value: Type) Type {
    if (@inComptime()) return value;
    return struct {
        var variable: Type = value;
    }.variable;
}

fn unary(comptime op: anytype, comptime opts: struct {
    libc_name: ?[]const u8 = null,
    compare: Compare = .relaxed,
}) type {
    return struct {
        // noinline so that `mem_arg` is on the stack
        noinline fn testArgKinds(
            _: Gpr,
            _: Gpr,
            _: Gpr,
            _: Gpr,
            _: Gpr,
            _: Gpr,
            _: Gpr,
            _: Gpr,
            _: Sse,
            _: Sse,
            _: Sse,
            _: Sse,
            _: Sse,
            _: Sse,
            _: Sse,
            _: Sse,
            comptime Type: type,
            comptime imm_arg: Type,
            mem_arg: Type,
        ) !void {
            const expected = expected: {
                if (opts.libc_name) |libc_name| libc: {
                    const libc_func = @extern(*const fn (Scalar(Type)) callconv(.c) Scalar(Type), .{
                        .name = switch (Scalar(Type)) {
                            f16 => "__" ++ libc_name ++ "h",
                            f32 => libc_name ++ "f",
                            f64 => libc_name,
                            f80 => "__" ++ libc_name ++ "x",
                            f128 => libc_name ++ "q",
                            else => break :libc,
                        },
                    });
                    switch (@typeInfo(Type)) {
                        else => break :expected libc_func(imm_arg),
                        .vector => |vector| {
                            var res: Type = undefined;
                            inline for (0..vector.len) |i| res[i] = libc_func(imm_arg[i]);
                            break :expected res;
                        },
                    }
                }
                break :expected comptime op(Type, imm_arg);
            };
            var reg_arg = mem_arg;
            _ = .{&reg_arg};
            try checkExpected(expected, op(Type, reg_arg), opts.compare);
            try checkExpected(expected, op(Type, mem_arg), opts.compare);
            if (opts.libc_name == null) try checkExpected(expected, op(Type, imm_arg), opts.compare);
        }
        // noinline for a more helpful stack trace
        noinline fn testArgs(comptime Type: type, comptime imm_arg: Type) !void {
            try testArgKinds(
                undefined,
                undefined,
                undefined,
                undefined,
                undefined,
                undefined,
                undefined,
                undefined,
                undefined,
                undefined,
                undefined,
                undefined,
                undefined,
                undefined,
                undefined,
                undefined,
                Type,
                imm_arg,
                imm_arg,
            );
        }
        fn testIntTypes() !void {
            try testArgs(i1, undefined);
            try testArgs(u1, undefined);
            try testArgs(i2, undefined);
            try testArgs(u2, undefined);
            try testArgs(i3, undefined);
            try testArgs(u3, undefined);
            try testArgs(i4, undefined);
            try testArgs(u4, undefined);
            try testArgs(i5, undefined);
            try testArgs(u5, undefined);
            try testArgs(i7, undefined);
            try testArgs(u7, undefined);
            try testArgs(i8, undefined);
            try testArgs(u8, undefined);
            try testArgs(i9, undefined);
            try testArgs(u9, undefined);
            try testArgs(i15, undefined);
            try testArgs(u15, undefined);
            try testArgs(i16, undefined);
            try testArgs(u16, undefined);
            try testArgs(i17, undefined);
            try testArgs(u17, undefined);
            try testArgs(i31, undefined);
            try testArgs(u31, undefined);
            try testArgs(i32, undefined);
            try testArgs(u32, undefined);
            try testArgs(i33, undefined);
            try testArgs(u33, undefined);
            try testArgs(i63, undefined);
            try testArgs(u63, undefined);
            try testArgs(i64, undefined);
            try testArgs(u64, undefined);
            try testArgs(i65, undefined);
            try testArgs(u65, undefined);
            try testArgs(i95, undefined);
            try testArgs(u95, undefined);
            try testArgs(i96, undefined);
            try testArgs(u96, undefined);
            try testArgs(i97, undefined);
            try testArgs(u97, undefined);
            try testArgs(i127, undefined);
            try testArgs(u127, undefined);
            try testArgs(i128, undefined);
            try testArgs(u128, undefined);
            try testArgs(i129, undefined);
            try testArgs(u129, undefined);
            try testArgs(i159, undefined);
            try testArgs(u159, undefined);
            try testArgs(i160, undefined);
            try testArgs(u160, undefined);
            try testArgs(i161, undefined);
            try testArgs(u161, undefined);
            try testArgs(i191, undefined);
            try testArgs(u191, undefined);
            try testArgs(i192, undefined);
            try testArgs(u192, undefined);
            try testArgs(i193, undefined);
            try testArgs(u193, undefined);
            try testArgs(i223, undefined);
            try testArgs(u223, undefined);
            try testArgs(i224, undefined);
            try testArgs(u224, undefined);
            try testArgs(i225, undefined);
            try testArgs(u225, undefined);
            try testArgs(i255, undefined);
            try testArgs(u255, undefined);
            try testArgs(i256, undefined);
            try testArgs(u256, undefined);
            try testArgs(i257, undefined);
            try testArgs(u257, undefined);
            try testArgs(i511, undefined);
            try testArgs(u511, undefined);
            try testArgs(i512, undefined);
            try testArgs(u512, undefined);
            try testArgs(i513, undefined);
            try testArgs(u513, undefined);
            try testArgs(i1023, undefined);
            try testArgs(u1023, undefined);
            try testArgs(i1024, undefined);
            try testArgs(u1024, undefined);
            try testArgs(i1025, undefined);
            try testArgs(u1025, undefined);
        }
        fn testInts() !void {
            try testArgs(i1, -1);
            try testArgs(i1, 0);
            try testArgs(u1, 0);
            try testArgs(u1, 1 << 0);

            try testArgs(i2, -1 << 1);
            try testArgs(i2, -1);
            try testArgs(i2, 0);
            try testArgs(u2, 0);
            try testArgs(u2, 1 << 0);
            try testArgs(u2, 1 << 1);

            try testArgs(i3, -1 << 2);
            try testArgs(i3, -1);
            try testArgs(i3, 0);
            try testArgs(u3, 0);
            try testArgs(u3, 1 << 0);
            try testArgs(u3, 1 << 1);
            try testArgs(u3, 1 << 2);

            try testArgs(i4, -1 << 3);
            try testArgs(i4, -1);
            try testArgs(i4, 0);
            try testArgs(u4, 0);
            try testArgs(u4, 1 << 0);
            try testArgs(u4, 1 << 1);
            try testArgs(u4, 1 << 2);
            try testArgs(u4, 1 << 3);

            try testArgs(i5, -1 << 4);
            try testArgs(i5, -1);
            try testArgs(i5, 0);
            try testArgs(u5, 0);
            try testArgs(u5, 1 << 0);
            try testArgs(u5, 1 << 1);
            try testArgs(u5, 1 << 3);
            try testArgs(u5, 1 << 4);

            try testArgs(i7, -1 << 6);
            try testArgs(i7, -1);
            try testArgs(i7, 0);
            try testArgs(u7, 0);
            try testArgs(u7, 1 << 0);
            try testArgs(u7, 1 << 1);
            try testArgs(u7, 1 << 5);
            try testArgs(u7, 1 << 6);

            try testArgs(i8, -1 << 7);
            try testArgs(i8, -1);
            try testArgs(i8, 0);
            try testArgs(u8, 0);
            try testArgs(u8, 1 << 0);
            try testArgs(u8, 1 << 1);
            try testArgs(u8, 1 << 6);
            try testArgs(u8, 1 << 7);

            try testArgs(i9, -1 << 8);
            try testArgs(i9, -1);
            try testArgs(i9, 0);
            try testArgs(u9, 0);
            try testArgs(u9, 1 << 0);
            try testArgs(u9, 1 << 1);
            try testArgs(u9, 1 << 7);
            try testArgs(u9, 1 << 8);

            try testArgs(i15, -1 << 14);
            try testArgs(i15, -1);
            try testArgs(i15, 0);
            try testArgs(u15, 0);
            try testArgs(u15, 1 << 0);
            try testArgs(u15, 1 << 1);
            try testArgs(u15, 1 << 13);
            try testArgs(u15, 1 << 14);

            try testArgs(i16, -1 << 15);
            try testArgs(i16, -1);
            try testArgs(i16, 0);
            try testArgs(u16, 0);
            try testArgs(u16, 1 << 0);
            try testArgs(u16, 1 << 1);
            try testArgs(u16, 1 << 14);
            try testArgs(u16, 1 << 15);

            try testArgs(i17, -1 << 16);
            try testArgs(i17, -1);
            try testArgs(i17, 0);
            try testArgs(u17, 0);
            try testArgs(u17, 1 << 0);
            try testArgs(u17, 1 << 1);
            try testArgs(u17, 1 << 15);
            try testArgs(u17, 1 << 16);

            try testArgs(i31, -1 << 30);
            try testArgs(i31, -1);
            try testArgs(i31, 0);
            try testArgs(u31, 0);
            try testArgs(u31, 1 << 0);
            try testArgs(u31, 1 << 1);
            try testArgs(u31, 1 << 29);
            try testArgs(u31, 1 << 30);

            try testArgs(i32, -1 << 31);
            try testArgs(i32, -1);
            try testArgs(i32, 0);
            try testArgs(u32, 0);
            try testArgs(u32, 1 << 0);
            try testArgs(u32, 1 << 1);
            try testArgs(u32, 1 << 30);
            try testArgs(u32, 1 << 31);

            try testArgs(i33, -1 << 32);
            try testArgs(i33, -1);
            try testArgs(i33, 0);
            try testArgs(u33, 0);
            try testArgs(u33, 1 << 0);
            try testArgs(u33, 1 << 1);
            try testArgs(u33, 1 << 31);
            try testArgs(u33, 1 << 32);

            try testArgs(i63, -1 << 62);
            try testArgs(i63, -1);
            try testArgs(i63, 0);
            try testArgs(u63, 0);
            try testArgs(u63, 1 << 0);
            try testArgs(u63, 1 << 1);
            try testArgs(u63, 1 << 61);
            try testArgs(u63, 1 << 62);

            try testArgs(i64, -1 << 63);
            try testArgs(i64, -1);
            try testArgs(i64, 0);
            try testArgs(u64, 0);
            try testArgs(u64, 1 << 0);
            try testArgs(u64, 1 << 1);
            try testArgs(u64, 1 << 62);
            try testArgs(u64, 1 << 63);

            try testArgs(i65, -1 << 64);
            try testArgs(i65, -1);
            try testArgs(i65, 0);
            try testArgs(u65, 0);
            try testArgs(u65, 1 << 0);
            try testArgs(u65, 1 << 1);
            try testArgs(u65, 1 << 63);
            try testArgs(u65, 1 << 64);

            try testArgs(i95, -1 << 94);
            try testArgs(i95, -1);
            try testArgs(i95, 0);
            try testArgs(u95, 0);
            try testArgs(u95, 1 << 0);
            try testArgs(u95, 1 << 1);
            try testArgs(u95, 1 << 93);
            try testArgs(u95, 1 << 94);

            try testArgs(i96, -1 << 95);
            try testArgs(i96, -1);
            try testArgs(i96, 0);
            try testArgs(u96, 0);
            try testArgs(u96, 1 << 0);
            try testArgs(u96, 1 << 1);
            try testArgs(u96, 1 << 94);
            try testArgs(u96, 1 << 95);

            try testArgs(i97, -1 << 96);
            try testArgs(i97, -1);
            try testArgs(i97, 0);
            try testArgs(u97, 0);
            try testArgs(u97, 1 << 0);
            try testArgs(u97, 1 << 1);
            try testArgs(u97, 1 << 95);
            try testArgs(u97, 1 << 96);

            try testArgs(i127, -1 << 126);
            try testArgs(i127, -1);
            try testArgs(i127, 0);
            try testArgs(u127, 0);
            try testArgs(u127, 1 << 0);
            try testArgs(u127, 1 << 1);
            try testArgs(u127, 1 << 125);
            try testArgs(u127, 1 << 126);

            try testArgs(i128, -1 << 127);
            try testArgs(i128, -1);
            try testArgs(i128, 0);
            try testArgs(u128, 0);
            try testArgs(u128, 1 << 0);
            try testArgs(u128, 1 << 1);
            try testArgs(u128, 1 << 126);
            try testArgs(u128, 1 << 127);

            try testArgs(i129, -1 << 128);
            try testArgs(i129, -1);
            try testArgs(i129, 0);
            try testArgs(u129, 0);
            try testArgs(u129, 1 << 0);
            try testArgs(u129, 1 << 1);
            try testArgs(u129, 1 << 127);
            try testArgs(u129, 1 << 128);

            try testArgs(i159, -1 << 158);
            try testArgs(i159, -1);
            try testArgs(i159, 0);
            try testArgs(u159, 0);
            try testArgs(u159, 1 << 0);
            try testArgs(u159, 1 << 1);
            try testArgs(u159, 1 << 157);
            try testArgs(u159, 1 << 158);

            try testArgs(i160, -1 << 159);
            try testArgs(i160, -1);
            try testArgs(i160, 0);
            try testArgs(u160, 0);
            try testArgs(u160, 1 << 0);
            try testArgs(u160, 1 << 1);
            try testArgs(u160, 1 << 158);
            try testArgs(u160, 1 << 159);

            try testArgs(i161, -1 << 160);
            try testArgs(i161, -1);
            try testArgs(i161, 0);
            try testArgs(u161, 0);
            try testArgs(u161, 1 << 0);
            try testArgs(u161, 1 << 1);
            try testArgs(u161, 1 << 159);
            try testArgs(u161, 1 << 160);

            try testArgs(i191, -1 << 190);
            try testArgs(i191, -1);
            try testArgs(i191, 0);
            try testArgs(u191, 0);
            try testArgs(u191, 1 << 0);
            try testArgs(u191, 1 << 1);
            try testArgs(u191, 1 << 189);
            try testArgs(u191, 1 << 190);

            try testArgs(i192, -1 << 191);
            try testArgs(i192, -1);
            try testArgs(i192, 0);
            try testArgs(u192, 0);
            try testArgs(u192, 1 << 0);
            try testArgs(u192, 1 << 1);
            try testArgs(u192, 1 << 190);
            try testArgs(u192, 1 << 191);

            try testArgs(i193, -1 << 192);
            try testArgs(i193, -1);
            try testArgs(i193, 0);
            try testArgs(u193, 0);
            try testArgs(u193, 1 << 0);
            try testArgs(u193, 1 << 1);
            try testArgs(u193, 1 << 191);
            try testArgs(u193, 1 << 192);

            try testArgs(i223, -1 << 222);
            try testArgs(i223, -1);
            try testArgs(i223, 0);
            try testArgs(u223, 0);
            try testArgs(u223, 1 << 0);
            try testArgs(u223, 1 << 1);
            try testArgs(u223, 1 << 221);
            try testArgs(u223, 1 << 222);

            try testArgs(i224, -1 << 223);
            try testArgs(i224, -1);
            try testArgs(i224, 0);
            try testArgs(u224, 0);
            try testArgs(u224, 1 << 0);
            try testArgs(u224, 1 << 1);
            try testArgs(u224, 1 << 222);
            try testArgs(u224, 1 << 223);

            try testArgs(i225, -1 << 224);
            try testArgs(i225, -1);
            try testArgs(i225, 0);
            try testArgs(u225, 0);
            try testArgs(u225, 1 << 0);
            try testArgs(u225, 1 << 1);
            try testArgs(u225, 1 << 223);
            try testArgs(u225, 1 << 224);

            try testArgs(i255, -1 << 254);
            try testArgs(i255, -1);
            try testArgs(i255, 0);
            try testArgs(u255, 0);
            try testArgs(u255, 1 << 0);
            try testArgs(u255, 1 << 1);
            try testArgs(u255, 1 << 253);
            try testArgs(u255, 1 << 254);

            try testArgs(i256, -1 << 255);
            try testArgs(i256, -1);
            try testArgs(i256, 0);
            try testArgs(u256, 0);
            try testArgs(u256, 1 << 0);
            try testArgs(u256, 1 << 1);
            try testArgs(u256, 1 << 254);
            try testArgs(u256, 1 << 255);

            try testArgs(i257, -1 << 256);
            try testArgs(i257, -1);
            try testArgs(i257, 0);
            try testArgs(u257, 0);
            try testArgs(u257, 1 << 0);
            try testArgs(u257, 1 << 1);
            try testArgs(u257, 1 << 255);
            try testArgs(u257, 1 << 256);

            try testArgs(i383, -1 << 382);
            try testArgs(i383, -1);
            try testArgs(i383, 0);
            try testArgs(u383, 0);
            try testArgs(u383, 1 << 0);
            try testArgs(u383, 1 << 1);
            try testArgs(u383, 1 << 381);
            try testArgs(u383, 1 << 382);

            try testArgs(i384, -1 << 383);
            try testArgs(i384, -1);
            try testArgs(i384, 0);
            try testArgs(u384, 0);
            try testArgs(u384, 1 << 0);
            try testArgs(u384, 1 << 1);
            try testArgs(u384, 1 << 382);
            try testArgs(u384, 1 << 383);

            try testArgs(i385, -1 << 384);
            try testArgs(i385, -1);
            try testArgs(i385, 0);
            try testArgs(u385, 0);
            try testArgs(u385, 1 << 0);
            try testArgs(u385, 1 << 1);
            try testArgs(u385, 1 << 383);
            try testArgs(u385, 1 << 384);

            try testArgs(i511, -1 << 510);
            try testArgs(i511, -1);
            try testArgs(i511, 0);
            try testArgs(u511, 0);
            try testArgs(u511, 1 << 0);
            try testArgs(u511, 1 << 1);
            try testArgs(u511, 1 << 509);
            try testArgs(u511, 1 << 510);

            try testArgs(i512, -1 << 511);
            try testArgs(i512, -1);
            try testArgs(i512, 0);
            try testArgs(u512, 0);
            try testArgs(u512, 1 << 0);
            try testArgs(u512, 1 << 1);
            try testArgs(u512, 1 << 510);
            try testArgs(u512, 1 << 511);

            try testArgs(i513, -1 << 512);
            try testArgs(i513, -1);
            try testArgs(i513, 0);
            try testArgs(u513, 0);
            try testArgs(u513, 1 << 0);
            try testArgs(u513, 1 << 1);
            try testArgs(u513, 1 << 511);
            try testArgs(u513, 1 << 512);

            try testArgs(i1023, -1 << 1022);
            try testArgs(i1023, -1);
            try testArgs(i1023, 0);
            try testArgs(u1023, 0);
            try testArgs(u1023, 1 << 0);
            try testArgs(u1023, 1 << 1);
            try testArgs(u1023, 1 << 1021);
            try testArgs(u1023, 1 << 1022);

            try testArgs(i1024, -1 << 1023);
            try testArgs(i1024, -1);
            try testArgs(i1024, 0);
            try testArgs(u1024, 0);
            try testArgs(u1024, 1 << 0);
            try testArgs(u1024, 1 << 1);
            try testArgs(u1024, 1 << 1022);
            try testArgs(u1024, 1 << 1023);

            try testArgs(i1025, -1 << 1024);
            try testArgs(i1025, -1);
            try testArgs(i1025, 0);
            try testArgs(u1025, 0);
            try testArgs(u1025, 1 << 0);
            try testArgs(u1025, 1 << 1);
            try testArgs(u1025, 1 << 1023);
            try testArgs(u1025, 1 << 1024);
        }
        fn testFloatTypes() !void {
            try testArgs(f16, undefined);
            try testArgs(f32, undefined);
            try testArgs(f64, undefined);
            try testArgs(f80, undefined);
            try testArgs(f128, undefined);
        }
        fn testFloats() !void {
            try testArgs(f16, -nan(f16));
            try testArgs(f16, -inf(f16));
            try testArgs(f16, -fmax(f16));
            try testArgs(f16, -1e1);
            try testArgs(f16, -1e0);
            try testArgs(f16, -1e-1);
            try testArgs(f16, -fmin(f16));
            try testArgs(f16, -tmin(f16));
            try testArgs(f16, -0.0);
            try testArgs(f16, 0.0);
            try testArgs(f16, tmin(f16));
            try testArgs(f16, fmin(f16));
            try testArgs(f16, 1e-1);
            try testArgs(f16, 1e0);
            try testArgs(f16, 1e1);
            try testArgs(f16, fmax(f16));
            try testArgs(f16, inf(f16));
            try testArgs(f16, nan(f16));

            try testArgs(f32, -nan(f32));
            try testArgs(f32, -inf(f32));
            try testArgs(f32, -fmax(f32));
            try testArgs(f32, -1e1);
            try testArgs(f32, -1e0);
            try testArgs(f32, -1e-1);
            try testArgs(f32, -fmin(f32));
            try testArgs(f32, -tmin(f32));
            try testArgs(f32, -0.0);
            try testArgs(f32, 0.0);
            try testArgs(f32, tmin(f32));
            try testArgs(f32, fmin(f32));
            try testArgs(f32, 1e-1);
            try testArgs(f32, 1e0);
            try testArgs(f32, 1e1);
            try testArgs(f32, fmax(f32));
            try testArgs(f32, inf(f32));
            try testArgs(f32, nan(f32));

            try testArgs(f64, -nan(f64));
            try testArgs(f64, -inf(f64));
            try testArgs(f64, -fmax(f64));
            try testArgs(f64, -1e1);
            try testArgs(f64, -1e0);
            try testArgs(f64, -1e-1);
            try testArgs(f64, -fmin(f64));
            try testArgs(f64, -tmin(f64));
            try testArgs(f64, -0.0);
            try testArgs(f64, 0.0);
            try testArgs(f64, tmin(f64));
            try testArgs(f64, fmin(f64));
            try testArgs(f64, 1e-1);
            try testArgs(f64, 1e0);
            try testArgs(f64, 1e1);
            try testArgs(f64, fmax(f64));
            try testArgs(f64, inf(f64));
            try testArgs(f64, nan(f64));

            try testArgs(f80, -nan(f80));
            try testArgs(f80, -inf(f80));
            try testArgs(f80, -fmax(f80));
            try testArgs(f80, -1e1);
            try testArgs(f80, -1e0);
            try testArgs(f80, -1e-1);
            try testArgs(f80, -fmin(f80));
            try testArgs(f80, -tmin(f80));
            try testArgs(f80, -0.0);
            try testArgs(f80, 0.0);
            try testArgs(f80, tmin(f80));
            try testArgs(f80, fmin(f80));
            try testArgs(f80, 1e-1);
            try testArgs(f80, 1e0);
            try testArgs(f80, 1e1);
            try testArgs(f80, fmax(f80));
            try testArgs(f80, inf(f80));
            try testArgs(f80, nan(f80));

            try testArgs(f128, -nan(f128));
            try testArgs(f128, -inf(f128));
            try testArgs(f128, -fmax(f128));
            try testArgs(f128, -1e1);
            try testArgs(f128, -1e0);
            try testArgs(f128, -1e-1);
            try testArgs(f128, -fmin(f128));
            try testArgs(f128, -tmin(f128));
            try testArgs(f128, -0.0);
            try testArgs(f128, 0.0);
            try testArgs(f128, tmin(f128));
            try testArgs(f128, fmin(f128));
            try testArgs(f128, 1e-1);
            try testArgs(f128, 1e0);
            try testArgs(f128, 1e1);
            try testArgs(f128, fmax(f128));
            try testArgs(f128, inf(f128));
            try testArgs(f128, nan(f128));
        }
        fn testIntVectorTypes() !void {
            try testArgs(@Vector(3, i1), undefined);
            try testArgs(@Vector(3, u1), undefined);
            try testArgs(@Vector(3, i2), undefined);
            try testArgs(@Vector(3, u2), undefined);
            try testArgs(@Vector(3, i3), undefined);
            try testArgs(@Vector(3, u3), undefined);
            try testArgs(@Vector(3, i4), undefined);
            try testArgs(@Vector(1, i4), undefined);
            try testArgs(@Vector(2, i4), undefined);
            try testArgs(@Vector(4, i4), undefined);
            try testArgs(@Vector(8, i4), undefined);
            try testArgs(@Vector(16, i4), undefined);
            try testArgs(@Vector(32, i4), undefined);
            try testArgs(@Vector(64, i4), undefined);
            try testArgs(@Vector(128, i4), undefined);
            try testArgs(@Vector(256, i4), undefined);
            try testArgs(@Vector(3, u4), undefined);
            try testArgs(@Vector(1, u4), undefined);
            try testArgs(@Vector(2, u4), undefined);
            try testArgs(@Vector(4, u4), undefined);
            try testArgs(@Vector(8, u4), undefined);
            try testArgs(@Vector(16, u4), undefined);
            try testArgs(@Vector(32, u4), undefined);
            try testArgs(@Vector(64, u4), undefined);
            try testArgs(@Vector(128, u4), undefined);
            try testArgs(@Vector(256, u4), undefined);
            try testArgs(@Vector(3, i5), undefined);
            try testArgs(@Vector(3, u5), undefined);
            try testArgs(@Vector(3, i7), undefined);
            try testArgs(@Vector(3, u7), undefined);
            try testArgs(@Vector(3, i8), undefined);
            try testArgs(@Vector(1, i8), undefined);
            try testArgs(@Vector(2, i8), undefined);
            try testArgs(@Vector(4, i8), undefined);
            try testArgs(@Vector(8, i8), undefined);
            try testArgs(@Vector(16, i8), undefined);
            try testArgs(@Vector(32, i8), undefined);
            try testArgs(@Vector(64, i8), undefined);
            try testArgs(@Vector(128, i8), undefined);
            try testArgs(@Vector(3, u8), undefined);
            try testArgs(@Vector(1, u8), undefined);
            try testArgs(@Vector(2, u8), undefined);
            try testArgs(@Vector(4, u8), undefined);
            try testArgs(@Vector(8, u8), undefined);
            try testArgs(@Vector(16, u8), undefined);
            try testArgs(@Vector(32, u8), undefined);
            try testArgs(@Vector(64, u8), undefined);
            try testArgs(@Vector(128, u8), undefined);
            try testArgs(@Vector(3, i9), undefined);
            try testArgs(@Vector(3, u9), undefined);
            try testArgs(@Vector(3, i15), undefined);
            try testArgs(@Vector(3, u15), undefined);
            try testArgs(@Vector(3, i16), undefined);
            try testArgs(@Vector(1, i16), undefined);
            try testArgs(@Vector(2, i16), undefined);
            try testArgs(@Vector(4, i16), undefined);
            try testArgs(@Vector(8, i16), undefined);
            try testArgs(@Vector(16, i16), undefined);
            try testArgs(@Vector(32, i16), undefined);
            try testArgs(@Vector(64, i16), undefined);
            try testArgs(@Vector(3, u16), undefined);
            try testArgs(@Vector(1, u16), undefined);
            try testArgs(@Vector(2, u16), undefined);
            try testArgs(@Vector(4, u16), undefined);
            try testArgs(@Vector(8, u16), undefined);
            try testArgs(@Vector(16, u16), undefined);
            try testArgs(@Vector(32, u16), undefined);
            try testArgs(@Vector(64, u16), undefined);
            try testArgs(@Vector(3, i17), undefined);
            try testArgs(@Vector(3, u17), undefined);
            try testArgs(@Vector(3, i31), undefined);
            try testArgs(@Vector(3, u31), undefined);
            try testArgs(@Vector(3, i32), undefined);
            try testArgs(@Vector(1, i32), undefined);
            try testArgs(@Vector(2, i32), undefined);
            try testArgs(@Vector(4, i32), undefined);
            try testArgs(@Vector(8, i32), undefined);
            try testArgs(@Vector(16, i32), undefined);
            try testArgs(@Vector(32, i32), undefined);
            try testArgs(@Vector(3, u32), undefined);
            try testArgs(@Vector(1, u32), undefined);
            try testArgs(@Vector(2, u32), undefined);
            try testArgs(@Vector(4, u32), undefined);
            try testArgs(@Vector(8, u32), undefined);
            try testArgs(@Vector(16, u32), undefined);
            try testArgs(@Vector(32, u32), undefined);
            try testArgs(@Vector(3, i33), undefined);
            try testArgs(@Vector(3, u33), undefined);
            try testArgs(@Vector(3, i63), undefined);
            try testArgs(@Vector(3, u63), undefined);
            try testArgs(@Vector(3, i64), undefined);
            try testArgs(@Vector(1, i64), undefined);
            try testArgs(@Vector(2, i64), undefined);
            try testArgs(@Vector(4, i64), undefined);
            try testArgs(@Vector(8, i64), undefined);
            try testArgs(@Vector(16, i64), undefined);
            try testArgs(@Vector(3, u64), undefined);
            try testArgs(@Vector(1, u64), undefined);
            try testArgs(@Vector(2, u64), undefined);
            try testArgs(@Vector(4, u64), undefined);
            try testArgs(@Vector(8, u64), undefined);
            try testArgs(@Vector(16, u64), undefined);
            try testArgs(@Vector(3, i65), undefined);
            try testArgs(@Vector(3, u65), undefined);
            try testArgs(@Vector(3, i127), undefined);
            try testArgs(@Vector(3, u127), undefined);
            try testArgs(@Vector(3, i128), undefined);
            try testArgs(@Vector(1, i128), undefined);
            try testArgs(@Vector(2, i128), undefined);
            try testArgs(@Vector(4, i128), undefined);
            try testArgs(@Vector(8, i128), undefined);
            try testArgs(@Vector(3, u128), undefined);
            try testArgs(@Vector(1, u128), undefined);
            try testArgs(@Vector(2, u128), undefined);
            try testArgs(@Vector(4, u128), undefined);
            try testArgs(@Vector(8, u128), undefined);
            try testArgs(@Vector(3, i129), undefined);
            try testArgs(@Vector(3, u129), undefined);
            try testArgs(@Vector(3, i191), undefined);
            try testArgs(@Vector(3, u191), undefined);
            try testArgs(@Vector(3, i192), undefined);
            try testArgs(@Vector(1, i192), undefined);
            try testArgs(@Vector(2, i192), undefined);
            try testArgs(@Vector(4, i192), undefined);
            try testArgs(@Vector(3, u192), undefined);
            try testArgs(@Vector(1, u192), undefined);
            try testArgs(@Vector(2, u192), undefined);
            try testArgs(@Vector(4, u192), undefined);
            try testArgs(@Vector(3, i193), undefined);
            try testArgs(@Vector(3, u193), undefined);
            try testArgs(@Vector(3, i255), undefined);
            try testArgs(@Vector(3, u255), undefined);
            try testArgs(@Vector(3, i256), undefined);
            try testArgs(@Vector(1, i256), undefined);
            try testArgs(@Vector(2, i256), undefined);
            try testArgs(@Vector(4, i256), undefined);
            try testArgs(@Vector(3, u256), undefined);
            try testArgs(@Vector(1, u256), undefined);
            try testArgs(@Vector(2, u256), undefined);
            try testArgs(@Vector(4, u256), undefined);
            try testArgs(@Vector(3, i257), undefined);
            try testArgs(@Vector(3, u257), undefined);
            try testArgs(@Vector(3, i511), undefined);
            try testArgs(@Vector(3, u511), undefined);
            try testArgs(@Vector(3, i512), undefined);
            try testArgs(@Vector(1, i512), undefined);
            try testArgs(@Vector(2, i512), undefined);
            try testArgs(@Vector(3, u512), undefined);
            try testArgs(@Vector(1, u512), undefined);
            try testArgs(@Vector(2, u512), undefined);
            try testArgs(@Vector(3, i513), undefined);
            try testArgs(@Vector(3, u513), undefined);
            try testArgs(@Vector(3, i1023), undefined);
            try testArgs(@Vector(3, u1023), undefined);
            try testArgs(@Vector(3, i1024), undefined);
            try testArgs(@Vector(1, i1024), undefined);
            try testArgs(@Vector(3, u1024), undefined);
            try testArgs(@Vector(1, u1024), undefined);
            try testArgs(@Vector(3, i1025), undefined);
            try testArgs(@Vector(3, u1025), undefined);
        }
        fn testIntVectors() !void {
            try testArgs(@Vector(3, i1), .{ -1 << 0, -1, 0 });
            try testArgs(@Vector(3, u1), .{ 0, 1, 1 << 0 });

            try testArgs(@Vector(3, i2), .{ -1 << 1, -1, 0 });
            try testArgs(@Vector(3, u2), .{ 0, 1, 1 << 1 });

            try testArgs(@Vector(3, i3), .{ -1 << 2, -1, 0 });
            try testArgs(@Vector(3, u3), .{ 0, 1, 1 << 2 });

            try testArgs(@Vector(3, i4), .{ -1 << 3, -1, 0 });
            try testArgs(@Vector(1, i4), .{
                -0x2,
            });
            try testArgs(@Vector(2, i4), .{
                -0x7, 0x4,
            });
            try testArgs(@Vector(4, i4), .{
                -0x3, 0x4, 0x2, -0x2,
            });
            try testArgs(@Vector(8, i4), .{
                -0x6, 0x3, 0x4, 0x3, 0x4, -0x8, -0x3, -0x5,
            });
            try testArgs(@Vector(16, i4), .{
                -0x3, 0x5, 0x4, -0x1, 0x2, 0x7, 0x1, 0x0, -0x2, 0x6, -0x1, -0x3, 0x5, -0x3, 0x3, -0x7,
            });
            try testArgs(@Vector(32, i4), .{
                -0x4, -0x2, 0x6, 0x6, -0x5, -0x8, -0x8, 0x7, -0x5, -0x5, 0x4, 0x5, -0x6, -0x1, 0x2, 0x0, -0x1, 0x3, 0x5, 0x1, -0x4, 0x2, -0x8, -0x6, -0x1, 0x3, 0x1, -0x8, 0x5, -0x6, 0x0, 0x2,
            });
            try testArgs(@Vector(64, i4), .{
                -0x2, 0x6,  -0x5, 0x2,  0x6, -0x5, 0x1,  -0x6, -0x6, 0x3, -0x5, 0x5, 0x0,  0x3, -0x6, -0x2, 0x0, -0x5, -0x2, -0x7, 0x6,  0x6, -0x6, 0x5, -0x1, 0x1, -0x5, 0x4,  -0x1, 0x2,  0x5,  0x0,
                0x6,  -0x1, -0x3, -0x1, 0x0, 0x0,  -0x2, -0x5, 0x7,  0x4, -0x7, 0x4, -0x8, 0x2, -0x1, -0x5, 0x4, -0x6, -0x3, 0x6,  -0x6, 0x5, 0x0,  0x6, -0x3, 0x3, -0x4, -0x4, 0x3,  -0x6, -0x5, -0x3,
            });
            try testArgs(@Vector(128, i4), .{
                -0x2, 0x7,  -0x7, 0x5,  0x4,  -0x8, -0x4, 0x2,  -0x6, 0x6,  0x3,  0x4,  -0x6, -0x3, 0x1,  -0x3, 0x4,  -0x4, 0x0, -0x5, 0x4,  -0x2, 0x4,  -0x6, 0x4,  0x7,  -0x6, 0x3,  -0x6, 0x5,  0x7,  -0x7,
                -0x8, 0x0,  0x2,  -0x6, -0x4, 0x5,  -0x2, -0x6, 0x2,  -0x3, -0x8, -0x3, -0x1, 0x4,  0x7,  -0x2, 0x7,  -0x3, 0x5, 0x3,  -0x6, 0x5,  -0x2, -0x5, -0x1, 0x5,  -0x6, -0x2, -0x5, -0x4, -0x7, -0x3,
                -0x4, -0x4, 0x6,  -0x8, -0x2, 0x3,  0x1,  0x7,  0x1,  -0x2, -0x7, -0x2, -0x8, -0x6, -0x6, 0x0,  -0x3, -0x4, 0x3, -0x5, -0x3, -0x5, 0x6,  0x5,  -0x7, -0x8, -0x5, -0x6, -0x2, -0x5, 0x5,  -0x5,
                0x0,  -0x6, -0x3, 0x0,  0x7,  0x6,  -0x6, -0x7, -0x4, -0x5, 0x3,  0x2,  0x7,  -0x3, -0x2, 0x4,  -0x4, -0x5, 0x6, 0x1,  0x7,  -0x5, -0x6, 0x0,  0x0,  -0x8, 0x4,  -0x1, -0x7, 0x0,  0x0,  0x5,
            });
            try testArgs(@Vector(256, i4), .{
                -0x7, 0x4,  0x7,  -0x5, 0x6,  -0x2, 0x6,  -0x5, 0x5,  0x5,  0x3,  -0x3, -0x5, 0x0,  0x5,  0x1,  0x4,  -0x1, 0x4,  -0x8, -0x4, -0x8, 0x2,  -0x8, 0x3,  0x1,  -0x7, -0x3, -0x1, 0x5,  -0x5, -0x8,
                -0x3, -0x3, -0x5, 0x6,  0x0,  0x4,  -0x3, -0x5, 0x0,  0x5,  -0x1, -0x3, -0x4, -0x3, 0x6,  -0x3, -0x1, 0x5,  -0x3, -0x3, 0x0,  0x3,  -0x2, -0x1, -0x5, 0x3,  0x2,  -0x8, 0x7,  -0x8, 0x6,  0x4,
                -0x5, -0x4, 0x5,  0x5,  0x6,  -0x3, 0x2,  -0x4, 0x3,  0x7,  0x6,  -0x2, -0x8, -0x1, -0x8, 0x2,  0x4,  0x1,  0x2,  -0x1, 0x5,  0x1,  0x3,  0x1,  0x3,  -0x5, 0x3,  -0x5, -0x5, 0x5,  -0x6, -0x7,
                0x0,  0x0,  -0x3, 0x6,  0x0,  0x5,  0x3,  0x0,  0x0,  -0x1, -0x6, -0x4, 0x5,  -0x8, -0x4, -0x3, -0x3, 0x2,  -0x5, -0x4, 0x4,  0x5,  -0x6, -0x3, 0x2,  0x5,  -0x7, -0x6, 0x3,  0x7,  -0x2, 0x6,
                0x2,  0x3,  0x7,  0x3,  0x2,  -0x5, 0x4,  0x5,  -0x4, -0x7, 0x2,  0x2,  -0x5, 0x7,  -0x3, -0x8, 0x2,  -0x4, 0x2,  0x4,  0x5,  -0x7, 0x7,  -0x6, 0x4,  -0x8, -0x1, 0x7,  0x0,  -0x4, 0x6,  -0x8,
                -0x5, 0x4,  -0x5, 0x1,  0x6,  -0x8, -0x1, -0x3, -0x5, 0x7,  0x1,  0x0,  -0x3, 0x4,  -0x5, -0x7, -0x5, 0x2,  0x0,  -0x1, -0x4, 0x0,  0x5,  0x6,  -0x3, -0x4, -0x2, 0x4,  -0x1, -0x8, 0x0,  0x6,
                0x7,  0x1,  0x5,  0x2,  -0x4, -0x7, -0x3, -0x3, -0x8, -0x8, -0x3, -0x4, 0x5,  -0x5, -0x2, -0x2, 0x1,  0x1,  0x1,  -0x8, 0x5,  0x4,  0x5,  0x6,  0x3,  0x0,  -0x2, -0x1, 0x4,  -0x4, -0x5, 0x0,
                -0x7, -0x8, -0x2, 0x1,  0x5,  0x4,  0x5,  -0x7, 0x3,  0x2,  0x2,  0x5,  -0x3, 0x7,  -0x4, 0x0,  -0x3, -0x2, -0x5, 0x1,  0x1,  -0x4, -0x4, 0x1,  -0x8, -0x3, 0x6,  -0x8, -0x2, 0x5,  0x7,  -0x3,
            });

            try testArgs(@Vector(3, u4), .{ 0, 1, 1 << 3 });
            try testArgs(@Vector(1, u4), .{
                0xb,
            });
            try testArgs(@Vector(2, u4), .{
                0x3, 0x4,
            });
            try testArgs(@Vector(4, u4), .{
                0x9, 0x2, 0xf, 0xe,
            });
            try testArgs(@Vector(8, u4), .{
                0x8, 0x1, 0xb, 0x1, 0xf, 0x5, 0x9, 0x6,
            });
            try testArgs(@Vector(16, u4), .{
                0xb, 0x6, 0x0, 0x7, 0x8, 0x5, 0x6, 0x9, 0xe, 0xb, 0x3, 0xa, 0xb, 0x5, 0x8, 0xc,
            });
            try testArgs(@Vector(32, u4), .{
                0xe, 0x6, 0xe, 0xa, 0xb, 0x4, 0xa, 0xb, 0x1, 0x3, 0xb, 0xc, 0x0, 0xb, 0x9, 0x4, 0xd, 0xa, 0xd, 0xd, 0x4, 0x8, 0x8, 0x6, 0xb, 0xe, 0x9, 0x6, 0xc, 0xd, 0x5, 0xd,
            });
            try testArgs(@Vector(64, u4), .{
                0x1, 0xc, 0xe, 0x9, 0x9, 0xf, 0x3, 0xf, 0x9, 0x9, 0x5, 0x3, 0xb, 0xd, 0xd, 0xf, 0x1, 0x2, 0xf, 0x9, 0x4, 0x4, 0x8, 0x9, 0x2, 0x9, 0x8, 0xe, 0x8, 0xa, 0x4, 0x3,
                0x4, 0xc, 0xb, 0x6, 0x4, 0x0, 0xa, 0x5, 0x1, 0xa, 0x4, 0xe, 0xa, 0x7, 0xd, 0x0, 0x4, 0xe, 0xe, 0x7, 0x7, 0xa, 0x4, 0x5, 0x6, 0xc, 0x6, 0x2, 0x6, 0xa, 0xe, 0xa,
            });
            try testArgs(@Vector(128, u4), .{
                0xd, 0x5, 0x6, 0xe, 0x3, 0x3, 0x3, 0xe, 0xd, 0xd, 0x9, 0x0, 0x0, 0xe, 0xa, 0x9, 0x8, 0x7, 0xb, 0x5, 0x7, 0xf, 0xb, 0x8, 0x0, 0xf, 0xb, 0x3, 0xa, 0x2, 0xb, 0xc,
                0x1, 0x1, 0xc, 0x8, 0x8, 0x6, 0x9, 0x1, 0xb, 0x0, 0x2, 0xb, 0x2, 0x2, 0x7, 0x6, 0x1, 0x1, 0xb, 0x4, 0x6, 0x4, 0x7, 0xc, 0xd, 0xc, 0xa, 0x8, 0x1, 0x7, 0x8, 0xa,
                0x9, 0xa, 0x1, 0x8, 0x1, 0x7, 0x9, 0x4, 0x5, 0x9, 0xd, 0x0, 0xa, 0xf, 0x3, 0x3, 0x9, 0x2, 0xf, 0x5, 0xb, 0x8, 0x6, 0xb, 0xf, 0x5, 0x8, 0x3, 0x9, 0xf, 0x6, 0x8,
                0xc, 0x8, 0x3, 0x4, 0xa, 0xe, 0xc, 0x1, 0xe, 0x9, 0x1, 0x8, 0xf, 0x6, 0xc, 0xc, 0x6, 0xf, 0x6, 0xd, 0xb, 0x9, 0xc, 0x3, 0xd, 0xa, 0x6, 0x8, 0x4, 0xa, 0x6, 0x9,
            });
            try testArgs(@Vector(256, u4), .{
                0x6, 0xc, 0xe, 0x3, 0x8, 0x2, 0xb, 0xd, 0x3, 0xa, 0x3, 0x8, 0xb, 0x8, 0x3, 0x0, 0xb, 0x5, 0x1, 0x3, 0x2, 0x2, 0xf, 0xc, 0x5, 0x1, 0x3, 0xb, 0x1, 0xc, 0x2, 0xd,
                0xa, 0x8, 0x1, 0xc, 0xb, 0xa, 0x3, 0x1, 0xe, 0x4, 0xf, 0xb, 0xd, 0x8, 0xf, 0xa, 0xc, 0xb, 0xb, 0x0, 0xa, 0xc, 0xf, 0xe, 0x8, 0xd, 0x9, 0x3, 0xa, 0xe, 0x8, 0x7,
                0x5, 0xa, 0x0, 0xe, 0x0, 0xd, 0x2, 0x2, 0x9, 0x4, 0x8, 0x9, 0x0, 0x4, 0x4, 0x8, 0xe, 0x1, 0xf, 0x1, 0x9, 0x3, 0xf, 0xc, 0xa, 0x0, 0x3, 0x2, 0x4, 0x1, 0x2, 0x3,
                0xf, 0x2, 0x7, 0xb, 0x5, 0x0, 0xd, 0x3, 0x4, 0xf, 0xa, 0x3, 0xc, 0x2, 0x5, 0xe, 0x7, 0x5, 0xd, 0x7, 0x9, 0x0, 0xd, 0x7, 0x9, 0xd, 0x5, 0x7, 0xf, 0xd, 0xb, 0x4,
                0x9, 0x6, 0xf, 0xb, 0x1, 0xb, 0x6, 0xb, 0xf, 0x7, 0xf, 0x0, 0x4, 0x7, 0x5, 0xa, 0x8, 0x1, 0xf, 0x9, 0x9, 0x0, 0x6, 0xb, 0x1, 0x2, 0x4, 0x3, 0x2, 0x0, 0x7, 0x0,
                0x6, 0x7, 0xf, 0x1, 0xe, 0xa, 0x8, 0x2, 0x9, 0xc, 0x1, 0x5, 0x7, 0x1, 0xb, 0x0, 0x1, 0x3, 0xd, 0x3, 0x0, 0x1, 0xa, 0x0, 0x3, 0x7, 0x1, 0x2, 0xb, 0xc, 0x2, 0x9,
                0x8, 0x8, 0x7, 0x0, 0xd, 0x5, 0x1, 0x5, 0x7, 0x7, 0x2, 0x3, 0x8, 0x7, 0xc, 0x8, 0xf, 0xa, 0xf, 0xf, 0x3, 0x2, 0x0, 0x4, 0x7, 0x5, 0x6, 0xd, 0x6, 0x3, 0xa, 0x4,
                0x1, 0x1, 0x2, 0xc, 0x3, 0xe, 0x2, 0xc, 0x7, 0x6, 0xe, 0xf, 0xb, 0x8, 0x6, 0x6, 0x9, 0x0, 0x4, 0xb, 0xe, 0x4, 0x2, 0x7, 0xf, 0xc, 0x0, 0x6, 0xd, 0xa, 0xe, 0xc,
            });

            try testArgs(@Vector(3, i5), .{ -1 << 4, -1, 0 });
            try testArgs(@Vector(3, u5), .{ 0, 1, 1 << 4 });

            try testArgs(@Vector(3, i7), .{ -1 << 6, -1, 0 });
            try testArgs(@Vector(3, u7), .{ 0, 1, 1 << 6 });

            try testArgs(@Vector(3, i8), .{ -1 << 7, -1, 0 });
            try testArgs(@Vector(1, i8), .{
                0x71,
            });
            try testArgs(@Vector(2, i8), .{
                -0x50, -0x43,
            });
            try testArgs(@Vector(4, i8), .{
                -0x09, -0x19, -0x15, -0x5d,
            });
            try testArgs(@Vector(8, i8), .{
                -0x4f, -0x55, -0x5b, -0x23, -0x76, 0x36, 0x6f, -0x63,
            });
            try testArgs(@Vector(16, i8), .{
                0x24, -0x03, 0x2e, 0x7b, 0x68, 0x29, 0x6c, 0x7f, -0x2f, -0x3b, -0x11, -0x3c, -0x2e, 0x27, -0x45, 0x45,
            });
            try testArgs(@Vector(32, i8), .{
                0x70, 0x33, -0x28, -0x38, -0x3b, 0x44,  -0x1d, 0x7d,  -0x48, 0x3c,  0x61, -0x09, -0x49, 0x15,  0x0a, -0x5a,
                0x78, 0x11, -0x07, -0x23, 0x4a,  -0x72, 0x25,  -0x17, -0x51, -0x04, 0x55, 0x20,  -0x80, -0x3d, 0x59, -0x39,
            });
            try testArgs(@Vector(64, i8), .{
                0x4f, 0x40,  -0x62, -0x4f, 0x37, -0x06, -0x33, 0x4d,  -0x10, 0x55,  0x24,  -0x76, 0x1d,  0x2b,  -0x54, -0x0f,
                0x21, -0x4c, -0x74, -0x07, 0x23, -0x5a, -0x21, -0x4a, -0x7c, -0x16, -0x20, -0x2e, 0x0a,  0x15,  0x03,  0x44,
                0x19, -0x27, 0x3e,  0x61,  0x6e, -0x76, 0x2a,  0x74,  -0x21, 0x34,  -0x69, -0x18, -0x21, -0x61, -0x34, -0x02,
                0x5e, -0x36, -0x79, -0x0f, 0x26, 0x6e,  0x5f,  0x52,  -0x0f, -0x64, 0x1a,  0x74,  -0x37, 0x00,  -0x47, -0x57,
            });
            try testArgs(@Vector(128, i8), .{
                -0x38, -0x19, 0x51,  0x09,  0x76,  -0x3b, -0x33, 0x39,  0x67,  0x51,  0x10,  0x77,  0x24,  0x21,  0x6f,  -0x1a,
                0x4e,  -0x69, 0x2e,  -0x78, -0x06, 0x5c,  0x17,  0x2e,  -0x0e, -0x2e, 0x09,  0x2a,  -0x5f, -0x40, -0x64, 0x3f,
                0x4a,  -0x77, -0x54, 0x38,  0x6b,  0x1f,  -0x04, 0x40,  0x27,  -0x0c, 0x65,  -0x46, 0x49,  -0x69, -0x53, 0x64,
                0x13,  -0x33, 0x3a,  -0x10, -0x15, 0x7f,  -0x1c, 0x5e,  -0x22, 0x2f,  -0x75, 0x77,  0x22,  0x6b,  -0x32, -0x55,
                0x18,  0x19,  0x2c,  -0x27, -0x03, 0x4f,  0x07,  0x0b,  0x44,  -0x21, 0x79,  0x55,  -0x65, 0x1d,  -0x29, 0x2f,
                0x4a,  0x6f,  -0x40, -0x57, -0x2f, 0x42,  0x52,  0x68,  -0x2a, -0x6b, 0x6f,  -0x49, -0x32, 0x52,  0x1e,  -0x60,
                -0x80, 0x53,  0x5e,  0x73,  -0x1e, 0x2d,  -0x46, -0x27, 0x4b,  0x57,  0x1f,  0x6a,  -0x65, 0x5f,  -0x2b, -0x03,
                -0x3a, -0x76, -0x51, 0x20,  0x04,  -0x0a, 0x2b,  -0x04, -0x1e, -0x18, -0x2d, 0x53,  -0x58, -0x69, 0x16,  0x19,
            });

            try testArgs(@Vector(3, u8), .{ 0, 1, 1 << 7 });
            try testArgs(@Vector(1, u8), .{
                0x33,
            });
            try testArgs(@Vector(2, u8), .{
                0x66, 0x87,
            });
            try testArgs(@Vector(4, u8), .{
                0x9d, 0xcb, 0x30, 0x7b,
            });
            try testArgs(@Vector(8, u8), .{
                0x4b, 0x35, 0x3f, 0x5c, 0xa5, 0x91, 0x23, 0x6d,
            });
            try testArgs(@Vector(16, u8), .{
                0xb7, 0x57, 0x27, 0x29, 0x58, 0xf8, 0xc9, 0x6c, 0xbe, 0x41, 0xf4, 0xd7, 0x4d, 0x01, 0xf0, 0x37,
            });
            try testArgs(@Vector(32, u8), .{
                0x5f, 0x61, 0x34, 0xe8, 0x37, 0x12, 0xba, 0x5a, 0x85, 0xf3, 0x3e, 0xa2, 0x0f, 0xd0, 0x65, 0xae,
                0xed, 0xf5, 0xe8, 0x65, 0x61, 0x28, 0x4a, 0x27, 0x2e, 0x01, 0x40, 0x8c, 0xe3, 0x36, 0x5d, 0xb6,
            });
            try testArgs(@Vector(64, u8), .{
                0xb0, 0x19, 0x5c, 0xc2, 0x3b, 0x16, 0x70, 0xad, 0x26, 0x45, 0xf2, 0xe1, 0x4f, 0x0f, 0x01, 0x72,
                0x7f, 0x1f, 0x07, 0x9e, 0xee, 0x9b, 0xb3, 0x38, 0x50, 0xf3, 0x56, 0x73, 0xd0, 0xd1, 0xee, 0xe3,
                0xeb, 0xf3, 0x1b, 0xe0, 0x77, 0x78, 0x75, 0xc6, 0x19, 0xe4, 0x69, 0xaa, 0x73, 0x08, 0xcd, 0x0c,
                0xf9, 0xed, 0x94, 0xf8, 0x79, 0x86, 0x63, 0x31, 0xbf, 0xd1, 0xe3, 0x17, 0x2b, 0xb9, 0xa1, 0x72,
            });
            try testArgs(@Vector(128, u8), .{
                0x2e, 0x93, 0x87, 0x09, 0x4f, 0x68, 0x14, 0xab, 0x3f, 0x04, 0x86, 0xc1, 0x95, 0xe8, 0x74, 0x11,
                0x57, 0x25, 0xe1, 0x88, 0xc0, 0x96, 0x33, 0x99, 0x15, 0x86, 0x2c, 0x84, 0x2e, 0xd7, 0x57, 0x21,
                0xd3, 0x18, 0xd5, 0x0e, 0xb4, 0x60, 0xe2, 0x08, 0xce, 0xbc, 0xd5, 0x4d, 0x8f, 0x59, 0x01, 0x67,
                0x71, 0x0a, 0x74, 0x48, 0xef, 0x39, 0x49, 0x7e, 0xa8, 0x39, 0x34, 0x75, 0x95, 0x3b, 0x38, 0xea,
                0x60, 0xd7, 0xed, 0x8f, 0xbb, 0xc0, 0x7d, 0xc2, 0x79, 0x2d, 0xbf, 0xa5, 0x64, 0xf4, 0x09, 0x86,
                0xfb, 0x29, 0xfe, 0xc7, 0xff, 0x62, 0x1a, 0x6f, 0xf8, 0xbd, 0xfe, 0xa4, 0xac, 0x24, 0xcf, 0x56,
                0x82, 0x69, 0x81, 0x0d, 0xc1, 0x51, 0x8d, 0x85, 0xf4, 0x00, 0xe7, 0x25, 0xab, 0xa5, 0x33, 0x45,
                0x66, 0x2e, 0x33, 0xc8, 0xf3, 0x35, 0x16, 0x7d, 0x1f, 0xc9, 0xf7, 0x44, 0xab, 0x66, 0x28, 0x0d,
            });

            try testArgs(@Vector(3, i9), .{ -1 << 8, -1, 0 });
            try testArgs(@Vector(3, u9), .{ 0, 1, 1 << 8 });

            try testArgs(@Vector(3, i15), .{ -1 << 14, -1, 0 });
            try testArgs(@Vector(3, u15), .{ 0, 1, 1 << 14 });

            try testArgs(@Vector(3, i16), .{ -1 << 15, -1, 0 });
            try testArgs(@Vector(1, i16), .{
                -0x015a,
            });
            try testArgs(@Vector(2, i16), .{
                -0x1c2f, 0x5ce8,
            });
            try testArgs(@Vector(4, i16), .{
                0x1212, 0x5bfc, -0x20ea, 0x0993,
            });
            try testArgs(@Vector(8, i16), .{
                0x4d55, -0x0dfb, -0x7921, 0x7e20, 0x74a5, -0x7371, -0x08e0, 0x7f23,
            });
            try testArgs(@Vector(16, i16), .{
                0x2354, -0x048a, -0x3ef9, 0x29d4, 0x4e5e, -0x3da9, -0x0cc4, -0x0377,
                0x4d44, 0x4384,  -0x1e46, 0x0bf1, 0x3151, -0x57c6, -0x367e, -0x7ae5,
            });
            try testArgs(@Vector(32, i16), .{
                0x5b5a, -0x54c4, -0x2089, -0x448d, 0x38e8,  -0x36a5, -0x0a8f, 0x06e0,
                0x09d9, 0x3877,  0x33c8,  0x5d3a,  0x018b,  0x29c9,  0x6f59,  -0x4078,
                0x6be4, -0x249e, 0x43b3,  -0x0389, 0x545e,  0x6ed7,  0x6636,  0x587d,
                0x55b0, -0x608b, 0x72e0,  0x4dfd,  -0x051d, 0x7433,  -0x7fc2, 0x2de3,
            });
            try testArgs(@Vector(64, i16), .{
                0x7834,  -0x43f9, -0x1cb3, -0x05f2, 0x25b5,  0x55f2,  0x4cfb,  -0x58bb,
                0x7292,  -0x082e, -0x5a6e, 0x1fc8,  -0x1f49, 0x7e3c,  0x4aa5,  -0x617e,
                0x2fab,  -0x2b96, 0x7474,  -0x6644, -0x5484, -0x278e, -0x6a0e, -0x5210,
                0x1adf,  -0x2799, 0x61e0,  -0x733c, -0x6bcc, -0x6fe2, -0x4e91, 0x5d01,
                0x3745,  0x24eb,  0x6c89,  0x4a94,  -0x7339, 0x4907,  -0x4f8f, -0x7e39,
                0x1a32,  0x65ca,  -0x6c27, -0x3269, 0x107b,  0x1c53,  -0x5529, 0x5232,
                -0x26ec, 0x4442,  -0x63f5, -0x174a, 0x3033,  -0x7363, 0x58be,  0x239f,
                0x7f7b,  -0x437d, -0x6df6, 0x0a7b,  0x3faa,  -0x1d75, -0x7426, 0x1274,
            });

            try testArgs(@Vector(3, u16), .{ 0, 1, 1 << 15 });
            try testArgs(@Vector(1, u16), .{
                0x4da6,
            });
            try testArgs(@Vector(2, u16), .{
                0x04d7, 0x50c6,
            });
            try testArgs(@Vector(4, u16), .{
                0x4c06, 0xd71f, 0x4d8f, 0xe0a4,
            });
            try testArgs(@Vector(8, u16), .{
                0xee9a, 0x881d, 0x31fb, 0xd3f7, 0x2c74, 0x6949, 0x4e04, 0x53d7,
            });
            try testArgs(@Vector(16, u16), .{
                0xeafe, 0x9a7b, 0x0d6f, 0x18cb, 0xaf8f, 0x8ee4, 0xa47e, 0xd39a,
                0x6572, 0x9c53, 0xf36e, 0x982e, 0x41c1, 0x8682, 0xf5dc, 0x7e01,
            });
            try testArgs(@Vector(32, u16), .{
                0xdfb3, 0x7de6, 0xd9ed, 0xb42e, 0x95ac, 0x9b5b, 0x0422, 0xdfcd,
                0x6196, 0x4dbe, 0x1818, 0x8816, 0x75e7, 0xc9b0, 0x92f7, 0x1f71,
                0xe584, 0x576c, 0x043a, 0x0f31, 0xfc4c, 0x2c87, 0x6b02, 0x0229,
                0x25b7, 0x53cd, 0x9bab, 0x866b, 0x9008, 0xf0f3, 0xeb21, 0x88e2,
            });
            try testArgs(@Vector(64, u16), .{
                0x084c, 0x445f, 0xce89, 0xd3ee, 0xb399, 0x315d, 0x8ef8, 0x4f6f,
                0xf9af, 0xcbc4, 0x0332, 0xcd55, 0xa4dc, 0xbc38, 0x6e33, 0x8ead,
                0xd15a, 0x5057, 0x58ef, 0x657a, 0xe9f0, 0x1418, 0x2b62, 0x3387,
                0x1c15, 0x04e1, 0x0276, 0x3783, 0xad9c, 0xea9a, 0x0e5e, 0xe803,
                0x2ee7, 0x0cf1, 0x30f1, 0xb12a, 0x381b, 0x353d, 0xf637, 0xf853,
                0x2ac1, 0x7ce8, 0x6a50, 0xcbb8, 0xc9b8, 0x9b25, 0xd1e9, 0xeff0,
                0xc0a2, 0x8e51, 0xde7a, 0x4e58, 0x5685, 0xeb3f, 0xd29b, 0x66ed,
                0x3dd5, 0xcb59, 0x6003, 0xf710, 0x943a, 0x7276, 0xe547, 0xe48f,
            });

            try testArgs(@Vector(3, i17), .{ -1 << 16, -1, 0 });
            try testArgs(@Vector(3, u17), .{ 0, 1, 1 << 16 });

            try testArgs(@Vector(3, i31), .{ -1 << 30, -1, 0 });
            try testArgs(@Vector(3, u31), .{ 0, 1, 1 << 30 });

            try testArgs(@Vector(3, i32), .{ -1 << 31, -1, 0 });
            try testArgs(@Vector(1, i32), .{
                -0x27f49dce,
            });
            try testArgs(@Vector(2, i32), .{
                0x24641ec7, 0x436c5bd2,
            });
            try testArgs(@Vector(4, i32), .{
                0x59e5eff1, -0x46b5b8db, -0x1029efa7, -0x1937fe73,
            });
            try testArgs(@Vector(8, i32), .{
                0x0ca01401,  -0x46b2bc0c, 0x51e5dee7, -0x74edfde8,
                -0x0ab09a6a, -0x5a51a88b, 0x18c28bc2, 0x63d79966,
            });
            try testArgs(@Vector(16, i32), .{
                0x3900e6c8, 0x2408c2bb, 0x5e01bc6e,  -0x0eb8c400,
                0x4c0dc6c2, 0x6c75e7f5, -0x66632ca8, 0x0e978daf,
                0x61ffe725, 0x720253e4, -0x6f6c38c1, -0x3302e60a,
                0x43f53c92, 0x5a3c1075, 0x7044a110,  0x18e41ad8,
            });
            try testArgs(@Vector(32, i32), .{
                0x3a5c2b01,  0x2a52d9fa,  -0x5843fc47, 0x6c493c7d,
                -0x47937cb1, -0x3ad95ec4, 0x71cf5e7b,  -0x3b6719c2,
                0x06bace17,  -0x6ccda5ed, 0x42b9ed04,  0x6be2b287,
                -0x7cf56523, -0x3c98e2e4, 0x1e7db6c0,  -0x7e668ad2,
                -0x6c245ecf, -0x09842450, -0x403a4335, -0x7a68e9b7,
                0x0036cf57,  -0x251edb4e, -0x67ec3abf, -0x183f0333,
                -0x4b46723c, -0x1e5383d6, 0x188c1de3,  0x400b3648,
                -0x4b21d9d3, 0x61635257,  0x179eb187,  0x31cd8376,
            });

            try testArgs(@Vector(3, u32), .{ 0, 1, 1 << 31 });
            try testArgs(@Vector(1, u32), .{
                0x17e2805c,
            });
            try testArgs(@Vector(2, u32), .{
                0xdb6aadc5, 0xb1ff3754,
            });
            try testArgs(@Vector(4, u32), .{
                0xf7897b31, 0x342e1af9, 0x190fd76b, 0x283b5374,
            });
            try testArgs(@Vector(8, u32), .{
                0x81a0bd16, 0xc55da94e, 0x910f7e7c, 0x078d5ef7,
                0x0bdb1e4a, 0xf1a96e99, 0xcdd729b5, 0xe6966a1c,
            });
            try testArgs(@Vector(16, u32), .{
                0xfee812db, 0x29eacbed, 0xaed48136, 0x3053de13,
                0xbbda20df, 0x6faa274a, 0xe0b5ec3a, 0x1878b0dc,
                0x98204475, 0x810d8d05, 0x1e6996b6, 0xc543826a,
                0x53b47d8c, 0xc72c3142, 0x12f7e1f9, 0xf6782e54,
            });
            try testArgs(@Vector(32, u32), .{
                0xf0cf30d3, 0xe3c587b8, 0xcee44739, 0xe4a0bd72,
                0x41d44cce, 0x6d7c4259, 0xd85580a5, 0xec4b02d7,
                0xa366483d, 0x2d7b59d4, 0xe9c0ace4, 0x82cb441c,
                0xa23958ba, 0x04a70148, 0x3f0d20a3, 0xf9e21e37,
                0x009fce8b, 0x4a34a229, 0xf09c35cf, 0xc0977d4d,
                0xcc4d4647, 0xa30f1363, 0x27a65b14, 0xe572c785,
                0x8f42e320, 0x2b2cdeca, 0x11205bd4, 0x739d26aa,
                0xcbcc2df0, 0x5f7a3649, 0xbde1b7aa, 0x180a169f,
            });

            try testArgs(@Vector(3, i33), .{ -1 << 32, -1, 0 });
            try testArgs(@Vector(3, u33), .{ 0, 1, 1 << 32 });

            try testArgs(@Vector(3, i63), .{ -1 << 62, -1, 0 });
            try testArgs(@Vector(3, u63), .{ 0, 1, 1 << 62 });

            try testArgs(@Vector(3, i64), .{ -1 << 63, -1, 0 });
            try testArgs(@Vector(1, i64), .{
                0x29113011488d8b65,
            });
            try testArgs(@Vector(2, i64), .{
                -0x3f865dcdfd831d03, -0x35512d15095445d6,
            });
            try testArgs(@Vector(4, i64), .{
                0x6f37a9484440251e, 0x2757e5e2b77e6ef3,
                0x4903a91bd2993d0b, 0x162244ba22371f62,
            });
            try testArgs(@Vector(8, i64), .{
                -0x46e2340c765175c1, -0x031ee2297e6cc8b3,
                -0x2627434d4b4fb796, 0x525e1ef31b6daa46,
                0x72d8eaaea07fa5ea,  0x2a8c0c36da019448,
                -0x5419ebf5cd514cde, -0x618c56a881057ac4,
            });
            try testArgs(@Vector(16, i64), .{
                0x36b4a703d084c774,  0x07a500f0d603a4d5,
                -0x27387989d2450cdd, 0x02073880984d74c8,
                -0x18d1593e36724417, -0x79df283cc6f403d8,
                0x36838a7c54da5f2b,  -0x2bf76c1666a1b768,
                -0x6ace0d64a2757edc, 0x41442e9979a0ab64,
                0x002612bfdf419826,  0x1128ba5648d22fe8,
                0x49b0f67e0abb8f3b,  0x6bf3e9ac37f73cf3,
                -0x5c89f516258c7e77, 0x6b345f04e60d2e56,
            });

            try testArgs(@Vector(3, u64), .{ 0, 1, 1 << 63 });
            try testArgs(@Vector(1, u64), .{
                0x7d2e439abb0edba7,
            });
            try testArgs(@Vector(2, u64), .{
                0x3749ee5a2d237b9f, 0x6d8f4c3e1378f389,
            });
            try testArgs(@Vector(4, u64), .{
                0x03c127040e10d52b, 0xa86fe019072e27eb,
                0x0a554a47b709cdba, 0xf4342cc597e196c3,
            });
            try testArgs(@Vector(8, u64), .{
                0xea455c104375a055, 0x5c35d9d945edb2fa,
                0xc11b73d9d9d546fc, 0x2a9d63aae838dd5b,
                0xed6603f1f5d574b3, 0x2f37b354c81c1e56,
                0xbe7f5e2476bc76bd, 0xb0c88eacfffa9a8f,
            });
            try testArgs(@Vector(16, u64), .{
                0x2258fc04b31f8dbe, 0x3a2e5483003a10d8,
                0xebf24b31c0460510, 0x15d5b4c09b53ffa5,
                0x05abf6e744b17cc6, 0x9747b483f2d159fe,
                0x4616d8b2c8673125, 0x8ae3f91d422447eb,
                0x18da2f101a9e9776, 0x77a1197fb0441007,
                0x4ba480c8ec2dd10b, 0xeb99b9c0a1725278,
                0xd9d0acc5084ecdf0, 0xa0a23317fff4f515,
                0x0901c59a9a6a408b, 0x7c77ca72e25df033,
            });

            try testArgs(@Vector(3, i65), .{ -1 << 64, -1, 0 });
            try testArgs(@Vector(3, u65), .{ 0, 1, 1 << 64 });

            try testArgs(@Vector(3, i127), .{ -1 << 126, -1, 0 });
            try testArgs(@Vector(3, u127), .{ 0, 1, 1 << 126 });

            try testArgs(@Vector(3, i128), .{ -1 << 127, -1, 0 });
            try testArgs(@Vector(1, i128), .{
                -0x2b0b1462b44785f39d1b7d763ec7bdb2,
            });
            try testArgs(@Vector(2, i128), .{
                -0x2faebe898a6fe60fbc6aadc3623431b7,
                0x5e596259e7b2588860d2b470ba751ace,
            });
            try testArgs(@Vector(4, i128), .{
                -0x624cb7e74cf789c06121809a3a5b51ba,
                0x23af4553d4d64672795c2b949635426f,
                -0x0b598b1f94876757fb13f2198e902b13,
                0x1daf732f50654d8211d464fda4fc030c,
            });
            try testArgs(@Vector(8, i128), .{
                -0x03c7df38daee9bc9a2c659a1a124ef10,
                0x657a590c91905c4021c28b0d6e42304a,
                -0x3f5176206dadc974d10e6fcbd67f3d29,
                0x066310ace384b1bc3549c71113b96b8a,
                -0x6c0201f66583206fcea7b7fe11889644,
                -0x5cc4d2a368002b380b25415be83f8218,
                0x11156c91b97a6a93427009efebcb2c31,
                -0x4221b5249ed0686c2ff2d5cab9f1c362,
            });

            try testArgs(@Vector(3, u128), .{ 0, 1, 1 << 127 });
            try testArgs(@Vector(1, u128), .{
                0x809f29e7fbafadc01145e1732590e7d9,
            });
            try testArgs(@Vector(2, u128), .{
                0x5150ac3438aacd0d51132cc2723b2995,
                0x151be9c47ad29cf719cf8358dd40165c,
            });
            try testArgs(@Vector(4, u128), .{
                0x4bae22df929f2f7cb9bd84deaad3e7a8,
                0x1ed46b2d6e1f3569f56b2ac33d8bc1cb,
                0xae93ea459d2ccfd5fb794e6d5c31aabb,
                0xb1177136acf099f550b70949ac202ec4,
            });
            try testArgs(@Vector(8, u128), .{
                0x7cd78db6baed6bfdf8c5265136c4e0fd,
                0xa41b8984c6bbde84640068194b7eba98,
                0xd33102778f2ae1a48d1e9bf8801bbbf0,
                0x0d59f6de003513a60055c86cbce2c200,
                0x825579d90012afddfbf04851c0748561,
                0xc2647c885e9d6f0ee1f5fac5da8ef7f5,
                0xcb4bbc1f81aa8ee68aa4dc140745687b,
                0x4ff10f914f74b46c694407f5bf7c7836,
            });

            try testArgs(@Vector(3, i129), .{ -1 << 128, -1, 0 });
            try testArgs(@Vector(3, u129), .{ 0, 1, 1 << 128 });

            try testArgs(@Vector(3, i191), .{ -1 << 190, -1, 0 });
            try testArgs(@Vector(3, u191), .{ 0, 1, 1 << 190 });

            try testArgs(@Vector(3, i192), .{ -1 << 191, -1, 0 });
            try testArgs(@Vector(1, i192), .{
                0x0206223e53631dfaf431066cf5ac30dd203bb8c7baa0cec7,
            });
            try testArgs(@Vector(2, i192), .{
                0x187a65fa29d1981dacf927e6a8e435481cfdcba6b63b781b,
                -0x0f53cb01d7662de0d19fa0b250e5bbc6edf7d3dd152f0dc3,
            });
            try testArgs(@Vector(4, i192), .{
                -0x3a456cd0eab663b34d5b6ad15933a31623aacb913adb8e41,
                -0x03376d57e9c495ac4ea623e1bf427ae22dcef26e4833da33,
                -0x28a90cfee819450e3000f3f2694a7dba2c02311996e01073,
                0x46c6cae4281780acd6a0322c3f4f8b63c3741da31b20a3cd,
            });

            try testArgs(@Vector(3, u192), .{ 0, 1, 1 << 191 });
            try testArgs(@Vector(1, u192), .{
                0xe7baafcb9781626a77571b0539b9471a60c97d6c02106c8b,
            });
            try testArgs(@Vector(2, u192), .{
                0xbc9510913ed09e2c2aa50ffab9f1bc7b303a87f36e232a83,
                0x1f37bee446d7712d1ad457c47a66812cb926198d052aee65,
            });
            try testArgs(@Vector(4, u192), .{
                0xdca6a7cfc19c69efc34022062a8ca36f2569ab3dce001202,
                0xd25a4529e621c9084181fdb6917c6a32eccc58b63601b35d,
                0x0a258afd6debbaf8c158f1caa61fed63b31871d13f51b43d,
                0x6b40a178674fcb82c623ac322f851623d5e993dac97a219a,
            });

            try testArgs(@Vector(3, i193), .{ -1 << 192, -1, 0 });
            try testArgs(@Vector(3, u193), .{ 0, 1, 1 << 192 });

            try testArgs(@Vector(3, i255), .{ -1 << 254, -1, 0 });
            try testArgs(@Vector(3, u255), .{ 0, 1, 1 << 254 });

            try testArgs(@Vector(3, i256), .{ -1 << 255, -1, 0 });
            try testArgs(@Vector(1, i256), .{
                0x59a12bff854679d9b3c6d1d195333d9f748dd1e2a7ad28f24f611a208bf91ed3,
            });
            try testArgs(@Vector(2, i256), .{
                0x6b266e98bd5e7e66ba90f2e1cb2ff555ac755efdbe0946313660c58b46c589bb,
                -0x4ab426d26f53253ae3b2fb412d9649fc8071db22605e528f918b9a3ee9d2a832,
            });
            try testArgs(@Vector(4, i256), .{
                -0x3a64f67fddd0859c0f3b063fc12b13b1865447b87d1740de51358421f50553b5,
                -0x7c364fc0218f1cab29425b1a4c9cbdbf0c676375bee8079b135ce40de3557c0b,
                0x368d25dc3eab1b00decd18679b29b7f4d95314161bd3ee687f2896e8cd525311,
                -0x6d9aacd172a363bf2d53ea497c289fd35e62c2484329c208e10a91b4cea88111,
            });

            try testArgs(@Vector(3, u256), .{ 0, 1, 1 << 255 });
            try testArgs(@Vector(1, u256), .{
                0x230413bb481fa3a997796acf282010c560d1942e7339fd584a0f15a90c83fbda,
            });
            try testArgs(@Vector(2, u256), .{
                0x3ad569f8d91fdbc9da8ec0e933565919f2feb90b996c90c352b461aa0908e62d,
                0x0f109696d64647983f1f757042515510729ad1350e862cbf38cb73b5cf99f0f7,
            });
            try testArgs(@Vector(4, u256), .{
                0x1717c6ded4ac6de282d59f75f068da47d5a47a30f2c5053d2d59e715f9d28b97,
                0x3087189ce7540e2e0028b80af571ebc6353a00b2917f243a869ed29ecca0adaa,
                0x1507c6a9d104684bf503cdb08841cf91adab4644306bd67aafff5326604833ce,
                0x857e134ff9179733c871295b25f824bd3eb562977bad30890964fa0cdc15bb07,
            });

            try testArgs(@Vector(3, i257), .{ -1 << 256, -1, 0 });
            try testArgs(@Vector(3, u257), .{ 0, 1, 1 << 256 });

            try testArgs(@Vector(3, i511), .{ -1 << 510, -1, 0 });
            try testArgs(@Vector(3, u511), .{ 0, 1, 1 << 510 });

            try testArgs(@Vector(3, i512), .{ -1 << 511, -1, 0 });
            try testArgs(@Vector(1, i512), .{
                -0x235b5d838cdf67b9eb6d7eeb518fb63cff402a74c687927feb363b5040556b8d32c55e565cc2fe33cb4dcc37e8fd1c92989522c11b6c186d11400d17e40d35b5,
            });
            try testArgs(@Vector(2, i512), .{
                -0x5f5ff44fec38adc4c9c8bc8de00acf01fcc62bc55d07033f4e788d4f3825382e1e39f6bd69dff328eec9a89486ebaaaffd9ab69d28eb7d952be4ef250cff6de1,
                -0x403e0fd866e1598ad928ecd234005debd527483375f5e7e79eee3a129868354acb5b74e42de9f297f81062d04ea41adc158e542ab04770dd039d527cffb81845,
            });

            try testArgs(@Vector(3, u512), .{ 0, 1, 1 << 511 });
            try testArgs(@Vector(1, u512), .{
                0xa3ff51a609f1370e5eeb96b05169bf7469e465cf76ac5b4ea8ffd166c1ba3cd94f2dedf0d647a1fe424f3a06e6d7940f03e257f28100970b00bd5528c52b9ae6,
            });
            try testArgs(@Vector(2, u512), .{
                0xc6d43cd46ae31ab71f9468a895c83bf17516c6b2f1c9b04b9aa113bf7fe1b789eb7d95fcf951f12a9a6f2124589551efdd8c00f528b366a7bfb852faf8f3da53,
                0xc9099d2bdf8d1a0d30485ec6db4a24cbc0d89a863de30e18313ee1d66f71dd2d26235caaa703286cf4a2b51e1a12ef96d2d944c66c0bd3f0d72dd4cf0fc8100e,
            });

            try testArgs(@Vector(3, i513), .{ -1 << 512, -1, 0 });
            try testArgs(@Vector(3, u513), .{ 0, 1, 1 << 512 });

            try testArgs(@Vector(3, i1023), .{ -1 << 1022, -1, 0 });
            try testArgs(@Vector(3, u1023), .{ 0, 1, 1 << 1022 });

            try testArgs(@Vector(3, i1024), .{ -1 << 1023, -1, 0 });
            try testArgs(@Vector(1, i1024), .{
                0x10eee350e115375812126750b24255ca76fdee619b64261c354af58bd4a29af6e2448ccda4d84e1b2fbf76d3710cf1b5e62b1360c3b63e104d0755fa264d6c171f8f7a3292d7859b08a5dff60e9ad8ba9dcdd7e6098eb70be7a27a0cbcc6480661330c21299b2960fac954ee4480f3a2cc1ca5a492e1e75084c079ba701cd7ab,
            });

            try testArgs(@Vector(3, u1024), .{ 0, 1, 1 << 1023 });
            try testArgs(@Vector(1, u1024), .{
                0xc6cfaa6571139552e1f067402dfc131d9b9a58aafda97198a78764b05138fb68cf26f085b7652f3d5ae0e56aa21732f296a581bb411d4a73795c213de793489fa49b173b9f5c089aa6295ff1fcdc14d491a05035b45d08fc35cd67a83d887a02b8db512f07518132e0ba56533c7d6fbe958255eddf5649bd8aba288c0dd84a25,
            });

            try testArgs(@Vector(3, i1025), .{ -1 << 1024, -1, 0 });
            try testArgs(@Vector(3, u1025), .{ 0, 1, 1 << 1024 });
        }
        fn testFloatVectorTypes() !void {
            try testArgs(@Vector(1, f16), undefined);
            try testArgs(@Vector(2, f16), undefined);
            try testArgs(@Vector(4, f16), undefined);
            try testArgs(@Vector(8, f16), undefined);
            try testArgs(@Vector(16, f16), undefined);
            try testArgs(@Vector(32, f16), undefined);
            try testArgs(@Vector(64, f16), undefined);

            try testArgs(@Vector(1, f32), undefined);
            try testArgs(@Vector(2, f32), undefined);
            try testArgs(@Vector(4, f32), undefined);
            try testArgs(@Vector(8, f32), undefined);
            try testArgs(@Vector(16, f32), undefined);
            try testArgs(@Vector(32, f32), undefined);

            try testArgs(@Vector(1, f64), undefined);
            try testArgs(@Vector(2, f64), undefined);
            try testArgs(@Vector(4, f64), undefined);
            try testArgs(@Vector(8, f64), undefined);
            try testArgs(@Vector(16, f64), undefined);

            try testArgs(@Vector(1, f80), undefined);
            try testArgs(@Vector(2, f80), undefined);
            try testArgs(@Vector(4, f80), undefined);
            try testArgs(@Vector(8, f80), undefined);

            try testArgs(@Vector(1, f128), undefined);
            try testArgs(@Vector(2, f128), undefined);
            try testArgs(@Vector(4, f128), undefined);
            try testArgs(@Vector(8, f128), undefined);
        }
        fn testFloatVectors() !void {
            try testArgs(@Vector(1, f16), .{
                -0x1.17cp-12,
            });
            try testArgs(@Vector(2, f16), .{
                0x1.47cp9, 0x1.3acp9,
            });
            try testArgs(@Vector(4, f16), .{
                0x1.ab4p0, -0x1.7fcp-7, -0x1.1cp0, -0x1.f14p12,
            });
            try testArgs(@Vector(8, f16), .{
                -0x1.8d8p8, 0x1.83p10, -0x1.5ap-1, -0x1.d78p13, -0x1.608p12, 0x1.e8p-9, -0x1.688p-10, -0x1.738p9,
            });
            try testArgs(@Vector(16, f16), .{
                0x1.da8p-1, -0x1.ed4p-10, -0x1.dc8p1,  0x1.b78p-14, nan(f16),    0x1.9d8p8,   nan(f16),     0x1.d5p13,
                -0x1.2dp13, 0x1.6c4p12,   0x1.a9cp-11, -0x1.0ecp8,  0x0.4ccp-14, -0x1.0a8p-6, -0x1.5bcp-14, 0x1.6d8p-9,
            });
            try testArgs(@Vector(32, f16), .{
                0x1.d5cp-6,  -0x1.a98p5,  0x1.49cp5,   -0x1.e4p-1,  -0x1.21p-13, -0x1.c94p-1, -0x1.adcp-5, -0x1.524p-1,
                -0x1.0d8p-3, -0x1.5c4p-2, 0x1.f84p-2,  0x1.664p1,   -0x1.f64p13, -0x1.bf4p4,  -0x1.4b8p0,  -0x0.f64p-14,
                -0x1.3f8p1,  0x1.098p2,   -0x1.a44p8,  0x1.048p13,  0x1.fd4p-11, 0x1.18p-9,   -0x1.504p2,  0x1.d04p7,
                -nan(f16),   0x1.a94p2,   0x0.5e8p-14, -0x1.7acp-7, 0x1.4c8p-3,  0x1.518p-4,  nan(f16),    0x1.8f8p10,
            });
            try testArgs(@Vector(64, f16), .{
                -0x1.c2p2,   0x0.2fcp-14,  0x1.de8p0,    -0x1.714p2,   0x1.f9p-7,    -0x1.11cp-13, -0x1.558p10, -0x1.2acp-7,
                0x1.348p14,  0x1.2dcp7,    -0x1.8acp-12, -0x1.2cp2,    0x1.868p1,    -0x1.1f8p-14, 0x1.638p7,   -0x1.734p-5,
                0x0.b98p-14, -0x1.7f4p-12, -0x1.38cp15,  0x1.50cp15,   0x1.91cp8,    0x1.cb4p-1,   0x1.fc4p-13, 0x1.9a4p0,
                0x1.18p-4,   0x1.60cp10,   0x1.6fp-12,   0x1.b48p6,    0x1.37cp-11,  0x1.424p7,    0x1.44cp13,  0x1.aep5,
                0x1.968p14,  0x1.e8p13,    -0x1.bp2,     -0x1.644p5,   0x1.de4p-8,   -0x1.5b4p-14, -0x1.4ap1,   -0x1.868p9,
                -0x1.d14p0,  0x1.d7cp15,   0x1.3c8p14,   0x1.2ccp-14,  -0x1.ee4p8,   0x1.49p-3,    0x1.35cp12,  0x1.d34p6,
                0x1.7acp3,   -0x1.fa4p2,   0x1.7b4p13,   -0x1.cf4p-12, -0x1.ebcp-10, -0x1.5p-3,    0x1.4bp-6,   0x1.83p12,
                -0x1.f9cp-8, -0x1.43p-8,   -0x1.99p-1,   -0x1.dacp3,   -0x1.728p-4,  -0x1.03cp4,   0x1.604p-2,  -0x1.0ep13,
            });

            try testArgs(@Vector(1, f32), .{
                -0x1.17cp-12,
            });
            try testArgs(@Vector(2, f32), .{
                -0x1.a3123ap90, -0x1.4a2ec6p-54,
            });
            try testArgs(@Vector(4, f32), .{
                -0x1.8a41p77, -0x1.7c54e2p-61, -0x1.498556p-41, 0x1.d77c22p-20,
            });
            try testArgs(@Vector(8, f32), .{
                0x1.943da4p-86, 0x1.528792p95,  -0x1.9c9bfap-26, -0x1.8df936p-90,
                -0x1.6a70cep56, 0x1.626638p-48, 0x1.7bb2bap-57,  -0x1.ac5104p94,
            });
            try testArgs(@Vector(16, f32), .{
                0x1.157044p115, -0x1.416c04p-111, 0x1.a8f164p-104, 0x1.9b6678p84,
                -0x1.9d065cp9,  -0x1.e8c4b4p126,  -0x1.ddb968p84,  -0x1.fec8c8p74,
                0x1.64ffb2p59,  0x1.548922p20,    0x1.7270fcp22,   -0x1.abac68p33,
                0x1.faabfp33,   -0x1.8aee82p55,   0x1.1bf8fp75,    0x1.33c46ap-66,
            });
            try testArgs(@Vector(32, f32), .{
                -0x1.039b68p37,   -0x1.34de4ap-74, -0x1.05d78ap-76, -0x1.be0f5ap-47,
                0x1.032204p-38,   0x1.ef8e2ap-78,  -0x1.b013ecp-80, 0x1.71fe4cp99,
                0x1.abdadap-14,   0x1.56a9a8p-48,  -0x1.8bbd7ep9,   0x1.edd308p-72,
                -0x1.92fafcp-121, -0x1.50812p19,   0x1.f4ddc4p28,   -0x1.6f0b12p-50,
                -0x1.12ab02p127,  0x1.24df48p21,   -0x1.993c3p-14,  -0x1.4cc476p-112,
                0x1.13d9a8p-40,   0x1.a6e652p-9,   -0x1.9c730cp-21, -0x1.a75aaap-70,
                -0x1.39e632p-111, 0x1.8e8da8p-45,  0x1.b5652cp31,   0x1.258366p44,
                0x1.d473aap92,    -0x1.951b64p9,   0x1.542edp15,    -0x0.f6222ap-126,
            });

            try testArgs(@Vector(1, f64), .{
                -0x1.0114613df6f97p816,
            });
            try testArgs(@Vector(2, f64), .{
                -0x1.8404dad72003cp720, -0x1.6b14b40bcf3b7p-176,
            });
            try testArgs(@Vector(4, f64), .{
                -0x1.04e1acbfddd9cp681, -0x1.ed553cc056da7p-749,
                0x1.3d3f703a0c893p-905, 0x1.0b35633fa78fp691,
            });
            try testArgs(@Vector(8, f64), .{
                -0x1.901a2a60f0562p-301, -0x1.2516175ad61ecp-447,
                0x1.e7b12124846bfp564,   0x1.9291384bd7259p209,
                -0x1.a7bf62f803c98p900,  0x1.4e2e26257bb3p987,
                -0x1.413ca9a32d894p811,  0x1.61b1dd9432e95p479,
            });
            try testArgs(@Vector(16, f64), .{
                -0x1.8fc7286d95f54p-235,  -0x1.796a7ea8372b6p-837,
                -0x1.8c0f930539acbp-98,   -0x1.ec80dfbf0b931p-430,
                -0x1.e3d80c640652fp-1019, 0x1.8241238fb542fp161,
                -0x1.e1f1a79d50263p137,   -0x1.9ac5cb2771c28p-791,
                0x1.4d8f00fe881e7p-401,   -0x1.87fbd7bfd99d7p346,
                -0x1.a8a7cc575335ep1017,  0x1.37bb88dc3fd8bp-355,
                0x1.9d53d346c0e65p929,    -0x1.bbae3d0229c34p289,
                -0x1.cb8ef994d5ce5p25,    0x1.ba20af512616ap50,
            });

            try testArgs(@Vector(1, f80), .{
                -0x1.a2e9410a7dfedabp-2324,
            });
            try testArgs(@Vector(2, f80), .{
                -0x1.a2e9410a7dfedabp-2324,
                0x1.2b17da3b9746885p-8665,
            });
            try testArgs(@Vector(4, f80), .{
                -0x1.c488fedb7ab646cep-13007,
                0x1.e914deaccaa50016p2073,
                -0x1.d1c7ae8ec3c9df86p10642,
                -0x1.2da1658f337fa01p9893,
            });
            try testArgs(@Vector(8, f80), .{
                -0x1.bed8a74c43750656p890,
                -0x1.7bf57f38004ac976p8481,
                -0x1.9cdc10ac0657d328p7884,
                0x1.c86f61883da149fp12293,
                -0x1.528d6957df6bfdd8p14125,
                -0x1.5ebb4006d0243bfep14530,
                -0x1.94b9b18636d12402p-1845,
                -0x1.25439a6d68add188p5962,
            });

            try testArgs(@Vector(1, f128), .{
                -0x1.d1e6fc3b1e66632e7b79051a47dap14300,
            });
            try testArgs(@Vector(2, f128), .{
                0x1.84b3ac8ffe5893b2c6af8d68de9dp-83,
                -0x1.438ca2c8a0d8e3ee9062d351c46ep-10235,
            });
            try testArgs(@Vector(4, f128), .{
                0x1.04eb03882d4fd1b090e714d3e5ep806,
                -0x1.4082b29f7c26e701764c915642ffp-6182,
                -0x1.b6f1e8565e5040415110f18b519ap13383,
                0x1.1c29f8c162cead9061c5797ea15ap11957,
            });
            try testArgs(@Vector(8, f128), .{
                -0x1.53d7f00cd204d80e5ff5bb665773p11218,
                -0x1.4daa1c81cffe28e8fa5cd703c287p2362,
                -0x1.cc6a71c3ad4560871efdbd025cd7p-8116,
                -0x1.87f8553cf8772fb6b78e7df3e3bap14523,
                -0x1.14b6880f6678f86dfb543dde1c6ep2105,
                0x1.9d2d4398414da9d857e76e8fd7ccp-13668,
                0x1.a37f07af240ded458d103c022064p-1158,
                0x1.425d53e6bd6070b847e5da1ed593p1394,
            });
        }
    };
}

inline fn bitNot(comptime Type: type, rhs: Type) @TypeOf(~rhs) {
    return ~rhs;
}
test bitNot {
    const test_bit_not = unary(bitNot, .{});
    try test_bit_not.testInts();
    try test_bit_not.testIntVectors();
}

inline fn clz(comptime Type: type, rhs: Type) @TypeOf(@clz(rhs)) {
    return @clz(rhs);
}
test clz {
    const test_clz = unary(clz, .{});
    try test_clz.testInts();
    try test_clz.testIntVectors();
}

inline fn ctz(comptime Type: type, rhs: Type) @TypeOf(@ctz(rhs)) {
    return @ctz(rhs);
}
test ctz {
    const test_ctz = unary(ctz, .{});
    try test_ctz.testInts();
}

inline fn popCount(comptime Type: type, rhs: Type) @TypeOf(@popCount(rhs)) {
    return @popCount(rhs);
}
test popCount {
    const test_pop_count = unary(popCount, .{});
    try test_pop_count.testInts();
}

inline fn byteSwap(comptime Type: type, rhs: Type) RoundBitsUp(Type, 8) {
    return @byteSwap(@as(RoundBitsUp(Type, 8), rhs));
}
test byteSwap {
    const test_byte_swap = unary(byteSwap, .{});
    try test_byte_swap.testInts();
}

inline fn bitReverse(comptime Type: type, rhs: Type) @TypeOf(@bitReverse(rhs)) {
    return @bitReverse(rhs);
}
test bitReverse {
    const test_bit_reverse = unary(bitReverse, .{});
    try test_bit_reverse.testInts();
}

inline fn sqrt(comptime Type: type, rhs: Type) @TypeOf(@sqrt(rhs)) {
    return @sqrt(rhs);
}
test sqrt {
    const test_sqrt = unary(sqrt, .{ .libc_name = "sqrt", .compare = .approx });
    try test_sqrt.testFloats();
    try test_sqrt.testFloatVectors();
}

inline fn sin(comptime Type: type, rhs: Type) @TypeOf(@sin(rhs)) {
    return @sin(rhs);
}
test sin {
    const test_sin = unary(sin, .{ .libc_name = "sin", .compare = .strict });
    try test_sin.testFloats();
    try test_sin.testFloatVectors();
}

inline fn cos(comptime Type: type, rhs: Type) @TypeOf(@cos(rhs)) {
    return @cos(rhs);
}
test cos {
    const test_cos = unary(cos, .{ .libc_name = "cos", .compare = .strict });
    try test_cos.testFloats();
    try test_cos.testFloatVectors();
}

inline fn tan(comptime Type: type, rhs: Type) @TypeOf(@tan(rhs)) {
    return @tan(rhs);
}
test tan {
    const test_tan = unary(tan, .{ .libc_name = "tan", .compare = .strict });
    try test_tan.testFloats();
    try test_tan.testFloatVectors();
}

inline fn exp(comptime Type: type, rhs: Type) @TypeOf(@exp(rhs)) {
    return @exp(rhs);
}
test exp {
    const test_exp = unary(exp, .{ .libc_name = "exp", .compare = .strict });
    try test_exp.testFloats();
    try test_exp.testFloatVectors();
}

inline fn exp2(comptime Type: type, rhs: Type) @TypeOf(@exp2(rhs)) {
    return @exp2(rhs);
}
test exp2 {
    const test_exp2 = unary(exp2, .{ .libc_name = "exp2", .compare = .strict });
    try test_exp2.testFloats();
    try test_exp2.testFloatVectors();
}

inline fn log(comptime Type: type, rhs: Type) @TypeOf(@log(rhs)) {
    return @log(rhs);
}
test log {
    const test_log = unary(log, .{ .libc_name = "log", .compare = .strict });
    try test_log.testFloats();
    try test_log.testFloatVectors();
}

inline fn log2(comptime Type: type, rhs: Type) @TypeOf(@log2(rhs)) {
    return @log2(rhs);
}
test log2 {
    const test_log2 = unary(log2, .{ .libc_name = "log2", .compare = .strict });
    try test_log2.testFloats();
    try test_log2.testFloatVectors();
}

inline fn log10(comptime Type: type, rhs: Type) @TypeOf(@log10(rhs)) {
    return @log10(rhs);
}
test log10 {
    const test_log10 = unary(log10, .{ .libc_name = "log10", .compare = .strict });
    try test_log10.testFloats();
    try test_log10.testFloatVectors();
}

inline fn abs(comptime Type: type, rhs: Type) @TypeOf(@abs(rhs)) {
    return @abs(rhs);
}
test abs {
    const test_abs = unary(abs, .{ .compare = .strict });
    try test_abs.testInts();
    try test_abs.testIntVectors();
    try test_abs.testFloats();
    try test_abs.testFloatVectors();
}

inline fn floor(comptime Type: type, rhs: Type) @TypeOf(@floor(rhs)) {
    return @floor(rhs);
}
test floor {
    const test_floor = unary(floor, .{ .libc_name = "floor", .compare = .strict });
    try test_floor.testFloats();
    try test_floor.testFloatVectors();
}

inline fn ceil(comptime Type: type, rhs: Type) @TypeOf(@ceil(rhs)) {
    return @ceil(rhs);
}
test ceil {
    const test_ceil = unary(ceil, .{ .libc_name = "ceil", .compare = .strict });
    try test_ceil.testFloats();
    try test_ceil.testFloatVectors();
}

inline fn round(comptime Type: type, rhs: Type) @TypeOf(@round(rhs)) {
    return @round(rhs);
}
test round {
    const test_round = unary(round, .{ .libc_name = "round", .compare = .strict });
    try test_round.testFloats();
    try test_round.testFloatVectors();
}

inline fn trunc(comptime Type: type, rhs: Type) @TypeOf(@trunc(rhs)) {
    return @trunc(rhs);
}
test trunc {
    const test_trunc = unary(trunc, .{ .libc_name = "trunc", .compare = .strict });
    try test_trunc.testFloats();
    try test_trunc.testFloatVectors();
}

inline fn negate(comptime Type: type, rhs: Type) @TypeOf(-rhs) {
    return -rhs;
}
test negate {
    const test_negate = unary(negate, .{ .compare = .strict });
    try test_negate.testFloats();
    try test_negate.testFloatVectors();
}

inline fn nullIsNull(comptime Type: type, _: Type) bool {
    return runtime(?Type, null) == null;
}
test nullIsNull {
    const test_null_is_null = unary(nullIsNull, .{});
    try test_null_is_null.testIntTypes();
    try test_null_is_null.testIntVectorTypes();
    try test_null_is_null.testFloatTypes();
    try test_null_is_null.testFloatVectorTypes();
}

inline fn nullIsNotNull(comptime Type: type, _: Type) bool {
    return runtime(?Type, null) != null;
}
test nullIsNotNull {
    const test_null_is_not_null = unary(nullIsNotNull, .{});
    try test_null_is_not_null.testIntTypes();
    try test_null_is_not_null.testIntVectorTypes();
    try test_null_is_not_null.testFloatTypes();
    try test_null_is_not_null.testFloatVectorTypes();
}

inline fn optionalIsNull(comptime Type: type, lhs: Type) bool {
    return @as(?Type, lhs) == null;
}
test optionalIsNull {
    const test_optional_is_null = unary(optionalIsNull, .{});
    try test_optional_is_null.testInts();
    try test_optional_is_null.testFloats();
}

inline fn optionalIsNotNull(comptime Type: type, lhs: Type) bool {
    return @as(?Type, lhs) != null;
}
test optionalIsNotNull {
    const test_optional_is_not_null = unary(optionalIsNotNull, .{});
    try test_optional_is_not_null.testInts();
    try test_optional_is_not_null.testFloats();
}

inline fn nullEqualNull(comptime Type: type, _: Type) bool {
    return runtime(?Type, null) == runtime(?Type, null);
}
test nullEqualNull {
    const test_null_equal_null = unary(nullEqualNull, .{});
    try test_null_equal_null.testIntTypes();
    try test_null_equal_null.testFloatTypes();
}

inline fn nullNotEqualNull(comptime Type: type, _: Type) bool {
    return runtime(?Type, null) != runtime(?Type, null);
}
test nullNotEqualNull {
    const test_null_not_equal_null = unary(nullNotEqualNull, .{});
    try test_null_not_equal_null.testIntTypes();
    try test_null_not_equal_null.testFloatTypes();
}

inline fn optionalEqualNull(comptime Type: type, lhs: Type) bool {
    return lhs == runtime(?Type, null);
}
test optionalEqualNull {
    const test_optional_equal_null = unary(optionalEqualNull, .{});
    try test_optional_equal_null.testInts();
    try test_optional_equal_null.testFloats();
}

inline fn optionalNotEqualNull(comptime Type: type, lhs: Type) bool {
    return lhs != runtime(?Type, null);
}
test optionalNotEqualNull {
    const test_optional_not_equal_null = unary(optionalIsNotNull, .{});
    try test_optional_not_equal_null.testInts();
    try test_optional_not_equal_null.testFloats();
}

inline fn splat(comptime Type: type, lhs: Type) Type {
    return @splat(lhs[0]);
}
test splat {
    const test_splat = unary(splat, .{});
    try test_splat.testIntVectors();
    try test_splat.testFloatVectors();
}
