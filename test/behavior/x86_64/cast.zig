const checkExpected = math.checkExpected;
const Compare = math.Compare;
const fmax = math.fmax;
const fmin = math.fmin;
const Gpr = math.Gpr;
const imax = math.imax;
const imin = math.imin;
const inf = math.inf;
const Log2Int = math.Log2Int;
const Log2IntCeil = math.Log2IntCeil;
const math = @import("math.zig");
const nan = math.nan;
const next = math.next;
const Scalar = math.Scalar;
const splat = math.splat;
const Sse = math.Sse;
const tmin = math.tmin;

fn cast(comptime op: anytype, comptime opts: struct { compare: Compare = .relaxed }) type {
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
            comptime Result: type,
            comptime Type: type,
            comptime imm_arg: Type,
            mem_arg: Type,
        ) !void {
            const expected = comptime op(Result, Type, imm_arg, imm_arg);
            var reg_arg = mem_arg;
            _ = .{&reg_arg};
            try checkExpected(expected, op(Result, Type, reg_arg, imm_arg), opts.compare);
            try checkExpected(expected, op(Result, Type, mem_arg, imm_arg), opts.compare);
            try checkExpected(expected, op(Result, Type, imm_arg, imm_arg), opts.compare);
        }
        // noinline for a more helpful stack trace
        noinline fn testArgs(comptime Result: type, comptime Type: type, comptime imm_arg: Type) !void {
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
                Result,
                Type,
                imm_arg,
                imm_arg,
            );
        }
        fn testSameSignednessInts() !void {
            try testArgs(i8, i1, -1);
            try testArgs(i8, i1, 0);
            try testArgs(i16, i1, -1);
            try testArgs(i16, i1, 0);
            try testArgs(i32, i1, -1);
            try testArgs(i32, i1, 0);
            try testArgs(i64, i1, -1);
            try testArgs(i64, i1, 0);
            try testArgs(i128, i1, -1);
            try testArgs(i128, i1, 0);
            try testArgs(i256, i1, -1);
            try testArgs(i256, i1, 0);
            try testArgs(i512, i1, -1);
            try testArgs(i512, i1, 0);
            try testArgs(i1024, i1, -1);
            try testArgs(i1024, i1, 0);
            try testArgs(u8, u1, 0);
            try testArgs(u8, u1, 1 << 0);
            try testArgs(u16, u1, 0);
            try testArgs(u16, u1, 1 << 0);
            try testArgs(u32, u1, 0);
            try testArgs(u32, u1, 1 << 0);
            try testArgs(u64, u1, 0);
            try testArgs(u64, u1, 1 << 0);
            try testArgs(u128, u1, 0);
            try testArgs(u128, u1, 1 << 0);
            try testArgs(u256, u1, 0);
            try testArgs(u256, u1, 1 << 0);
            try testArgs(u512, u1, 0);
            try testArgs(u512, u1, 1 << 0);
            try testArgs(u1024, u1, 0);
            try testArgs(u1024, u1, 1 << 0);

            try testArgs(i8, i2, -1 << 1);
            try testArgs(i8, i2, -1);
            try testArgs(i8, i2, 0);
            try testArgs(i16, i2, -1 << 1);
            try testArgs(i16, i2, -1);
            try testArgs(i16, i2, 0);
            try testArgs(i32, i2, -1 << 1);
            try testArgs(i32, i2, -1);
            try testArgs(i32, i2, 0);
            try testArgs(i64, i2, -1 << 1);
            try testArgs(i64, i2, -1);
            try testArgs(i64, i2, 0);
            try testArgs(i128, i2, -1 << 1);
            try testArgs(i128, i2, -1);
            try testArgs(i128, i2, 0);
            try testArgs(i256, i2, -1 << 1);
            try testArgs(i256, i2, -1);
            try testArgs(i256, i2, 0);
            try testArgs(i512, i2, -1 << 1);
            try testArgs(i512, i2, -1);
            try testArgs(i512, i2, 0);
            try testArgs(i1024, i2, -1 << 1);
            try testArgs(i1024, i2, -1);
            try testArgs(i1024, i2, 0);
            try testArgs(u8, u2, 0);
            try testArgs(u8, u2, 1 << 0);
            try testArgs(u8, u2, 1 << 1);
            try testArgs(u16, u2, 0);
            try testArgs(u16, u2, 1 << 0);
            try testArgs(u16, u2, 1 << 1);
            try testArgs(u32, u2, 0);
            try testArgs(u32, u2, 1 << 0);
            try testArgs(u32, u2, 1 << 1);
            try testArgs(u64, u2, 0);
            try testArgs(u64, u2, 1 << 0);
            try testArgs(u64, u2, 1 << 1);
            try testArgs(u128, u2, 0);
            try testArgs(u128, u2, 1 << 0);
            try testArgs(u128, u2, 1 << 1);
            try testArgs(u256, u2, 0);
            try testArgs(u256, u2, 1 << 0);
            try testArgs(u256, u2, 1 << 1);
            try testArgs(u512, u2, 0);
            try testArgs(u512, u2, 1 << 0);
            try testArgs(u512, u2, 1 << 1);
            try testArgs(u1024, u2, 0);
            try testArgs(u1024, u2, 1 << 0);
            try testArgs(u1024, u2, 1 << 1);

            try testArgs(i8, i3, -1 << 2);
            try testArgs(i8, i3, -1);
            try testArgs(i8, i3, 0);
            try testArgs(i16, i3, -1 << 2);
            try testArgs(i16, i3, -1);
            try testArgs(i16, i3, 0);
            try testArgs(i32, i3, -1 << 2);
            try testArgs(i32, i3, -1);
            try testArgs(i32, i3, 0);
            try testArgs(i64, i3, -1 << 2);
            try testArgs(i64, i3, -1);
            try testArgs(i64, i3, 0);
            try testArgs(i128, i3, -1 << 2);
            try testArgs(i128, i3, -1);
            try testArgs(i128, i3, 0);
            try testArgs(i256, i3, -1 << 2);
            try testArgs(i256, i3, -1);
            try testArgs(i256, i3, 0);
            try testArgs(i512, i3, -1 << 2);
            try testArgs(i512, i3, -1);
            try testArgs(i512, i3, 0);
            try testArgs(i1024, i3, -1 << 2);
            try testArgs(i1024, i3, -1);
            try testArgs(i1024, i3, 0);
            try testArgs(u8, u3, 0);
            try testArgs(u8, u3, 1 << 0);
            try testArgs(u8, u3, 1 << 2);
            try testArgs(u16, u3, 0);
            try testArgs(u16, u3, 1 << 0);
            try testArgs(u16, u3, 1 << 2);
            try testArgs(u32, u3, 0);
            try testArgs(u32, u3, 1 << 0);
            try testArgs(u32, u3, 1 << 2);
            try testArgs(u64, u3, 0);
            try testArgs(u64, u3, 1 << 0);
            try testArgs(u64, u3, 1 << 2);
            try testArgs(u128, u3, 0);
            try testArgs(u128, u3, 1 << 0);
            try testArgs(u128, u3, 1 << 2);
            try testArgs(u256, u3, 0);
            try testArgs(u256, u3, 1 << 0);
            try testArgs(u256, u3, 1 << 2);
            try testArgs(u512, u3, 0);
            try testArgs(u512, u3, 1 << 0);
            try testArgs(u512, u3, 1 << 2);
            try testArgs(u1024, u3, 0);
            try testArgs(u1024, u3, 1 << 0);
            try testArgs(u1024, u3, 1 << 2);

            try testArgs(i8, i4, -1 << 3);
            try testArgs(i8, i4, -1);
            try testArgs(i8, i4, 0);
            try testArgs(i16, i4, -1 << 3);
            try testArgs(i16, i4, -1);
            try testArgs(i16, i4, 0);
            try testArgs(i32, i4, -1 << 3);
            try testArgs(i32, i4, -1);
            try testArgs(i32, i4, 0);
            try testArgs(i64, i4, -1 << 3);
            try testArgs(i64, i4, -1);
            try testArgs(i64, i4, 0);
            try testArgs(i128, i4, -1 << 3);
            try testArgs(i128, i4, -1);
            try testArgs(i128, i4, 0);
            try testArgs(i256, i4, -1 << 3);
            try testArgs(i256, i4, -1);
            try testArgs(i256, i4, 0);
            try testArgs(i512, i4, -1 << 3);
            try testArgs(i512, i4, -1);
            try testArgs(i512, i4, 0);
            try testArgs(i1024, i4, -1 << 3);
            try testArgs(i1024, i4, -1);
            try testArgs(i1024, i4, 0);
            try testArgs(u8, u4, 0);
            try testArgs(u8, u4, 1 << 0);
            try testArgs(u8, u4, 1 << 3);
            try testArgs(u16, u4, 0);
            try testArgs(u16, u4, 1 << 0);
            try testArgs(u16, u4, 1 << 3);
            try testArgs(u32, u4, 0);
            try testArgs(u32, u4, 1 << 0);
            try testArgs(u32, u4, 1 << 3);
            try testArgs(u64, u4, 0);
            try testArgs(u64, u4, 1 << 0);
            try testArgs(u64, u4, 1 << 3);
            try testArgs(u128, u4, 0);
            try testArgs(u128, u4, 1 << 0);
            try testArgs(u128, u4, 1 << 3);
            try testArgs(u256, u4, 0);
            try testArgs(u256, u4, 1 << 0);
            try testArgs(u256, u4, 1 << 3);
            try testArgs(u512, u4, 0);
            try testArgs(u512, u4, 1 << 0);
            try testArgs(u512, u4, 1 << 3);
            try testArgs(u1024, u4, 0);
            try testArgs(u1024, u4, 1 << 0);
            try testArgs(u1024, u4, 1 << 3);

            try testArgs(i8, i5, -1 << 4);
            try testArgs(i8, i5, -1);
            try testArgs(i8, i5, 0);
            try testArgs(i16, i5, -1 << 4);
            try testArgs(i16, i5, -1);
            try testArgs(i16, i5, 0);
            try testArgs(i32, i5, -1 << 4);
            try testArgs(i32, i5, -1);
            try testArgs(i32, i5, 0);
            try testArgs(i64, i5, -1 << 4);
            try testArgs(i64, i5, -1);
            try testArgs(i64, i5, 0);
            try testArgs(i128, i5, -1 << 4);
            try testArgs(i128, i5, -1);
            try testArgs(i128, i5, 0);
            try testArgs(i256, i5, -1 << 4);
            try testArgs(i256, i5, -1);
            try testArgs(i256, i5, 0);
            try testArgs(i512, i5, -1 << 4);
            try testArgs(i512, i5, -1);
            try testArgs(i512, i5, 0);
            try testArgs(i1024, i5, -1 << 4);
            try testArgs(i1024, i5, -1);
            try testArgs(i1024, i5, 0);
            try testArgs(u8, u5, 0);
            try testArgs(u8, u5, 1 << 0);
            try testArgs(u8, u5, 1 << 4);
            try testArgs(u16, u5, 0);
            try testArgs(u16, u5, 1 << 0);
            try testArgs(u16, u5, 1 << 4);
            try testArgs(u32, u5, 0);
            try testArgs(u32, u5, 1 << 0);
            try testArgs(u32, u5, 1 << 4);
            try testArgs(u64, u5, 0);
            try testArgs(u64, u5, 1 << 0);
            try testArgs(u64, u5, 1 << 4);
            try testArgs(u128, u5, 0);
            try testArgs(u128, u5, 1 << 0);
            try testArgs(u128, u5, 1 << 4);
            try testArgs(u256, u5, 0);
            try testArgs(u256, u5, 1 << 0);
            try testArgs(u256, u5, 1 << 4);
            try testArgs(u512, u5, 0);
            try testArgs(u512, u5, 1 << 0);
            try testArgs(u512, u5, 1 << 4);
            try testArgs(u1024, u5, 0);
            try testArgs(u1024, u5, 1 << 0);
            try testArgs(u1024, u5, 1 << 4);

            try testArgs(i8, i7, -1 << 6);
            try testArgs(i8, i7, -1);
            try testArgs(i8, i7, 0);
            try testArgs(i16, i7, -1 << 6);
            try testArgs(i16, i7, -1);
            try testArgs(i16, i7, 0);
            try testArgs(i32, i7, -1 << 6);
            try testArgs(i32, i7, -1);
            try testArgs(i32, i7, 0);
            try testArgs(i64, i7, -1 << 6);
            try testArgs(i64, i7, -1);
            try testArgs(i64, i7, 0);
            try testArgs(i128, i7, -1 << 6);
            try testArgs(i128, i7, -1);
            try testArgs(i128, i7, 0);
            try testArgs(i256, i7, -1 << 6);
            try testArgs(i256, i7, -1);
            try testArgs(i256, i7, 0);
            try testArgs(i512, i7, -1 << 6);
            try testArgs(i512, i7, -1);
            try testArgs(i512, i7, 0);
            try testArgs(i1024, i7, -1 << 6);
            try testArgs(i1024, i7, -1);
            try testArgs(i1024, i7, 0);
            try testArgs(u8, u7, 0);
            try testArgs(u8, u7, 1 << 0);
            try testArgs(u8, u7, 1 << 6);
            try testArgs(u16, u7, 0);
            try testArgs(u16, u7, 1 << 0);
            try testArgs(u16, u7, 1 << 6);
            try testArgs(u32, u7, 0);
            try testArgs(u32, u7, 1 << 0);
            try testArgs(u32, u7, 1 << 6);
            try testArgs(u64, u7, 0);
            try testArgs(u64, u7, 1 << 0);
            try testArgs(u64, u7, 1 << 6);
            try testArgs(u128, u7, 0);
            try testArgs(u128, u7, 1 << 0);
            try testArgs(u128, u7, 1 << 6);
            try testArgs(u256, u7, 0);
            try testArgs(u256, u7, 1 << 0);
            try testArgs(u256, u7, 1 << 6);
            try testArgs(u512, u7, 0);
            try testArgs(u512, u7, 1 << 0);
            try testArgs(u512, u7, 1 << 6);
            try testArgs(u1024, u7, 0);
            try testArgs(u1024, u7, 1 << 0);
            try testArgs(u1024, u7, 1 << 6);

            try testArgs(i8, i8, -1 << 7);
            try testArgs(i8, i8, -1);
            try testArgs(i8, i8, 0);
            try testArgs(i16, i8, -1 << 7);
            try testArgs(i16, i8, -1);
            try testArgs(i16, i8, 0);
            try testArgs(i32, i8, -1 << 7);
            try testArgs(i32, i8, -1);
            try testArgs(i32, i8, 0);
            try testArgs(i64, i8, -1 << 7);
            try testArgs(i64, i8, -1);
            try testArgs(i64, i8, 0);
            try testArgs(i128, i8, -1 << 7);
            try testArgs(i128, i8, -1);
            try testArgs(i128, i8, 0);
            try testArgs(i256, i8, -1 << 7);
            try testArgs(i256, i8, -1);
            try testArgs(i256, i8, 0);
            try testArgs(i512, i8, -1 << 7);
            try testArgs(i512, i8, -1);
            try testArgs(i512, i8, 0);
            try testArgs(i1024, i8, -1 << 7);
            try testArgs(i1024, i8, -1);
            try testArgs(i1024, i8, 0);
            try testArgs(u8, u8, 0);
            try testArgs(u8, u8, 1 << 0);
            try testArgs(u8, u8, 1 << 7);
            try testArgs(u16, u8, 0);
            try testArgs(u16, u8, 1 << 0);
            try testArgs(u16, u8, 1 << 7);
            try testArgs(u32, u8, 0);
            try testArgs(u32, u8, 1 << 0);
            try testArgs(u32, u8, 1 << 7);
            try testArgs(u64, u8, 0);
            try testArgs(u64, u8, 1 << 0);
            try testArgs(u64, u8, 1 << 7);
            try testArgs(u128, u8, 0);
            try testArgs(u128, u8, 1 << 0);
            try testArgs(u128, u8, 1 << 7);
            try testArgs(u256, u8, 0);
            try testArgs(u256, u8, 1 << 0);
            try testArgs(u256, u8, 1 << 7);
            try testArgs(u512, u8, 0);
            try testArgs(u512, u8, 1 << 0);
            try testArgs(u512, u8, 1 << 7);
            try testArgs(u1024, u8, 0);
            try testArgs(u1024, u8, 1 << 0);
            try testArgs(u1024, u8, 1 << 7);

            try testArgs(i8, i9, -1 << 8);
            try testArgs(i8, i9, -1);
            try testArgs(i8, i9, 0);
            try testArgs(i16, i9, -1 << 8);
            try testArgs(i16, i9, -1);
            try testArgs(i16, i9, 0);
            try testArgs(i32, i9, -1 << 8);
            try testArgs(i32, i9, -1);
            try testArgs(i32, i9, 0);
            try testArgs(i64, i9, -1 << 8);
            try testArgs(i64, i9, -1);
            try testArgs(i64, i9, 0);
            try testArgs(i128, i9, -1 << 8);
            try testArgs(i128, i9, -1);
            try testArgs(i128, i9, 0);
            try testArgs(i256, i9, -1 << 8);
            try testArgs(i256, i9, -1);
            try testArgs(i256, i9, 0);
            try testArgs(i512, i9, -1 << 8);
            try testArgs(i512, i9, -1);
            try testArgs(i512, i9, 0);
            try testArgs(i1024, i9, -1 << 8);
            try testArgs(i1024, i9, -1);
            try testArgs(i1024, i9, 0);
            try testArgs(u8, u9, 0);
            try testArgs(u8, u9, 1 << 0);
            try testArgs(u8, u9, 1 << 8);
            try testArgs(u16, u9, 0);
            try testArgs(u16, u9, 1 << 0);
            try testArgs(u16, u9, 1 << 8);
            try testArgs(u32, u9, 0);
            try testArgs(u32, u9, 1 << 0);
            try testArgs(u32, u9, 1 << 8);
            try testArgs(u64, u9, 0);
            try testArgs(u64, u9, 1 << 0);
            try testArgs(u64, u9, 1 << 8);
            try testArgs(u128, u9, 0);
            try testArgs(u128, u9, 1 << 0);
            try testArgs(u128, u9, 1 << 8);
            try testArgs(u256, u9, 0);
            try testArgs(u256, u9, 1 << 0);
            try testArgs(u256, u9, 1 << 8);
            try testArgs(u512, u9, 0);
            try testArgs(u512, u9, 1 << 0);
            try testArgs(u512, u9, 1 << 8);
            try testArgs(u1024, u9, 0);
            try testArgs(u1024, u9, 1 << 0);
            try testArgs(u1024, u9, 1 << 8);

            try testArgs(i8, i15, -1 << 14);
            try testArgs(i8, i15, -1);
            try testArgs(i8, i15, 0);
            try testArgs(i16, i15, -1 << 14);
            try testArgs(i16, i15, -1);
            try testArgs(i16, i15, 0);
            try testArgs(i32, i15, -1 << 14);
            try testArgs(i32, i15, -1);
            try testArgs(i32, i15, 0);
            try testArgs(i64, i15, -1 << 14);
            try testArgs(i64, i15, -1);
            try testArgs(i64, i15, 0);
            try testArgs(i128, i15, -1 << 14);
            try testArgs(i128, i15, -1);
            try testArgs(i128, i15, 0);
            try testArgs(i256, i15, -1 << 14);
            try testArgs(i256, i15, -1);
            try testArgs(i256, i15, 0);
            try testArgs(i512, i15, -1 << 14);
            try testArgs(i512, i15, -1);
            try testArgs(i512, i15, 0);
            try testArgs(i1024, i15, -1 << 14);
            try testArgs(i1024, i15, -1);
            try testArgs(i1024, i15, 0);
            try testArgs(u8, u15, 0);
            try testArgs(u8, u15, 1 << 0);
            try testArgs(u8, u15, 1 << 14);
            try testArgs(u16, u15, 0);
            try testArgs(u16, u15, 1 << 0);
            try testArgs(u16, u15, 1 << 14);
            try testArgs(u32, u15, 0);
            try testArgs(u32, u15, 1 << 0);
            try testArgs(u32, u15, 1 << 14);
            try testArgs(u64, u15, 0);
            try testArgs(u64, u15, 1 << 0);
            try testArgs(u64, u15, 1 << 14);
            try testArgs(u128, u15, 0);
            try testArgs(u128, u15, 1 << 0);
            try testArgs(u128, u15, 1 << 14);
            try testArgs(u256, u15, 0);
            try testArgs(u256, u15, 1 << 0);
            try testArgs(u256, u15, 1 << 14);
            try testArgs(u512, u15, 0);
            try testArgs(u512, u15, 1 << 0);
            try testArgs(u512, u15, 1 << 14);
            try testArgs(u1024, u15, 0);
            try testArgs(u1024, u15, 1 << 0);
            try testArgs(u1024, u15, 1 << 14);

            try testArgs(i8, i16, -1 << 15);
            try testArgs(i8, i16, -1);
            try testArgs(i8, i16, 0);
            try testArgs(i16, i16, -1 << 15);
            try testArgs(i16, i16, -1);
            try testArgs(i16, i16, 0);
            try testArgs(i32, i16, -1 << 15);
            try testArgs(i32, i16, -1);
            try testArgs(i32, i16, 0);
            try testArgs(i64, i16, -1 << 15);
            try testArgs(i64, i16, -1);
            try testArgs(i64, i16, 0);
            try testArgs(i128, i16, -1 << 15);
            try testArgs(i128, i16, -1);
            try testArgs(i128, i16, 0);
            try testArgs(i256, i16, -1 << 15);
            try testArgs(i256, i16, -1);
            try testArgs(i256, i16, 0);
            try testArgs(i512, i16, -1 << 15);
            try testArgs(i512, i16, -1);
            try testArgs(i512, i16, 0);
            try testArgs(i1024, i16, -1 << 15);
            try testArgs(i1024, i16, -1);
            try testArgs(i1024, i16, 0);
            try testArgs(u8, u16, 0);
            try testArgs(u8, u16, 1 << 0);
            try testArgs(u8, u16, 1 << 15);
            try testArgs(u16, u16, 0);
            try testArgs(u16, u16, 1 << 0);
            try testArgs(u16, u16, 1 << 15);
            try testArgs(u32, u16, 0);
            try testArgs(u32, u16, 1 << 0);
            try testArgs(u32, u16, 1 << 15);
            try testArgs(u64, u16, 0);
            try testArgs(u64, u16, 1 << 0);
            try testArgs(u64, u16, 1 << 15);
            try testArgs(u128, u16, 0);
            try testArgs(u128, u16, 1 << 0);
            try testArgs(u128, u16, 1 << 15);
            try testArgs(u256, u16, 0);
            try testArgs(u256, u16, 1 << 0);
            try testArgs(u256, u16, 1 << 15);
            try testArgs(u512, u16, 0);
            try testArgs(u512, u16, 1 << 0);
            try testArgs(u512, u16, 1 << 15);
            try testArgs(u1024, u16, 0);
            try testArgs(u1024, u16, 1 << 0);
            try testArgs(u1024, u16, 1 << 15);

            try testArgs(i8, i17, -1 << 16);
            try testArgs(i8, i17, -1);
            try testArgs(i8, i17, 0);
            try testArgs(i16, i17, -1 << 16);
            try testArgs(i16, i17, -1);
            try testArgs(i16, i17, 0);
            try testArgs(i32, i17, -1 << 16);
            try testArgs(i32, i17, -1);
            try testArgs(i32, i17, 0);
            try testArgs(i64, i17, -1 << 16);
            try testArgs(i64, i17, -1);
            try testArgs(i64, i17, 0);
            try testArgs(i128, i17, -1 << 16);
            try testArgs(i128, i17, -1);
            try testArgs(i128, i17, 0);
            try testArgs(i256, i17, -1 << 16);
            try testArgs(i256, i17, -1);
            try testArgs(i256, i17, 0);
            try testArgs(i512, i17, -1 << 16);
            try testArgs(i512, i17, -1);
            try testArgs(i512, i17, 0);
            try testArgs(i1024, i17, -1 << 16);
            try testArgs(i1024, i17, -1);
            try testArgs(i1024, i17, 0);
            try testArgs(u8, u17, 0);
            try testArgs(u8, u17, 1 << 0);
            try testArgs(u8, u17, 1 << 16);
            try testArgs(u16, u17, 0);
            try testArgs(u16, u17, 1 << 0);
            try testArgs(u16, u17, 1 << 16);
            try testArgs(u32, u17, 0);
            try testArgs(u32, u17, 1 << 0);
            try testArgs(u32, u17, 1 << 16);
            try testArgs(u64, u17, 0);
            try testArgs(u64, u17, 1 << 0);
            try testArgs(u64, u17, 1 << 16);
            try testArgs(u128, u17, 0);
            try testArgs(u128, u17, 1 << 0);
            try testArgs(u128, u17, 1 << 16);
            try testArgs(u256, u17, 0);
            try testArgs(u256, u17, 1 << 0);
            try testArgs(u256, u17, 1 << 16);
            try testArgs(u512, u17, 0);
            try testArgs(u512, u17, 1 << 0);
            try testArgs(u512, u17, 1 << 16);
            try testArgs(u1024, u17, 0);
            try testArgs(u1024, u17, 1 << 0);
            try testArgs(u1024, u17, 1 << 16);

            try testArgs(i8, i31, -1 << 30);
            try testArgs(i8, i31, -1);
            try testArgs(i8, i31, 0);
            try testArgs(i16, i31, -1 << 30);
            try testArgs(i16, i31, -1);
            try testArgs(i16, i31, 0);
            try testArgs(i32, i31, -1 << 30);
            try testArgs(i32, i31, -1);
            try testArgs(i32, i31, 0);
            try testArgs(i64, i31, -1 << 30);
            try testArgs(i64, i31, -1);
            try testArgs(i64, i31, 0);
            try testArgs(i128, i31, -1 << 30);
            try testArgs(i128, i31, -1);
            try testArgs(i128, i31, 0);
            try testArgs(i256, i31, -1 << 30);
            try testArgs(i256, i31, -1);
            try testArgs(i256, i31, 0);
            try testArgs(i512, i31, -1 << 30);
            try testArgs(i512, i31, -1);
            try testArgs(i512, i31, 0);
            try testArgs(i1024, i31, -1 << 30);
            try testArgs(i1024, i31, -1);
            try testArgs(i1024, i31, 0);
            try testArgs(u8, u31, 0);
            try testArgs(u8, u31, 1 << 0);
            try testArgs(u8, u31, 1 << 30);
            try testArgs(u16, u31, 0);
            try testArgs(u16, u31, 1 << 0);
            try testArgs(u16, u31, 1 << 30);
            try testArgs(u32, u31, 0);
            try testArgs(u32, u31, 1 << 0);
            try testArgs(u32, u31, 1 << 30);
            try testArgs(u64, u31, 0);
            try testArgs(u64, u31, 1 << 0);
            try testArgs(u64, u31, 1 << 30);
            try testArgs(u128, u31, 0);
            try testArgs(u128, u31, 1 << 0);
            try testArgs(u128, u31, 1 << 30);
            try testArgs(u256, u31, 0);
            try testArgs(u256, u31, 1 << 0);
            try testArgs(u256, u31, 1 << 30);
            try testArgs(u512, u31, 0);
            try testArgs(u512, u31, 1 << 0);
            try testArgs(u512, u31, 1 << 30);
            try testArgs(u1024, u31, 0);
            try testArgs(u1024, u31, 1 << 0);
            try testArgs(u1024, u31, 1 << 30);

            try testArgs(i8, i32, -1 << 31);
            try testArgs(i8, i32, -1);
            try testArgs(i8, i32, 0);
            try testArgs(i16, i32, -1 << 31);
            try testArgs(i16, i32, -1);
            try testArgs(i16, i32, 0);
            try testArgs(i32, i32, -1 << 31);
            try testArgs(i32, i32, -1);
            try testArgs(i32, i32, 0);
            try testArgs(i64, i32, -1 << 31);
            try testArgs(i64, i32, -1);
            try testArgs(i64, i32, 0);
            try testArgs(i128, i32, -1 << 31);
            try testArgs(i128, i32, -1);
            try testArgs(i128, i32, 0);
            try testArgs(i256, i32, -1 << 31);
            try testArgs(i256, i32, -1);
            try testArgs(i256, i32, 0);
            try testArgs(i512, i32, -1 << 31);
            try testArgs(i512, i32, -1);
            try testArgs(i512, i32, 0);
            try testArgs(i1024, i32, -1 << 31);
            try testArgs(i1024, i32, -1);
            try testArgs(i1024, i32, 0);
            try testArgs(u8, u32, 0);
            try testArgs(u8, u32, 1 << 0);
            try testArgs(u8, u32, 1 << 31);
            try testArgs(u16, u32, 0);
            try testArgs(u16, u32, 1 << 0);
            try testArgs(u16, u32, 1 << 31);
            try testArgs(u32, u32, 0);
            try testArgs(u32, u32, 1 << 0);
            try testArgs(u32, u32, 1 << 31);
            try testArgs(u64, u32, 0);
            try testArgs(u64, u32, 1 << 0);
            try testArgs(u64, u32, 1 << 31);
            try testArgs(u128, u32, 0);
            try testArgs(u128, u32, 1 << 0);
            try testArgs(u128, u32, 1 << 31);
            try testArgs(u256, u32, 0);
            try testArgs(u256, u32, 1 << 0);
            try testArgs(u256, u32, 1 << 31);
            try testArgs(u512, u32, 0);
            try testArgs(u512, u32, 1 << 0);
            try testArgs(u512, u32, 1 << 31);
            try testArgs(u1024, u32, 0);
            try testArgs(u1024, u32, 1 << 0);
            try testArgs(u1024, u32, 1 << 31);

            try testArgs(i8, i33, -1 << 32);
            try testArgs(i8, i33, -1);
            try testArgs(i8, i33, 0);
            try testArgs(i16, i33, -1 << 32);
            try testArgs(i16, i33, -1);
            try testArgs(i16, i33, 0);
            try testArgs(i32, i33, -1 << 32);
            try testArgs(i32, i33, -1);
            try testArgs(i32, i33, 0);
            try testArgs(i64, i33, -1 << 32);
            try testArgs(i64, i33, -1);
            try testArgs(i64, i33, 0);
            try testArgs(i128, i33, -1 << 32);
            try testArgs(i128, i33, -1);
            try testArgs(i128, i33, 0);
            try testArgs(i256, i33, -1 << 32);
            try testArgs(i256, i33, -1);
            try testArgs(i256, i33, 0);
            try testArgs(i512, i33, -1 << 32);
            try testArgs(i512, i33, -1);
            try testArgs(i512, i33, 0);
            try testArgs(i1024, i33, -1 << 32);
            try testArgs(i1024, i33, -1);
            try testArgs(i1024, i33, 0);
            try testArgs(u8, u33, 0);
            try testArgs(u8, u33, 1 << 0);
            try testArgs(u8, u33, 1 << 32);
            try testArgs(u16, u33, 0);
            try testArgs(u16, u33, 1 << 0);
            try testArgs(u16, u33, 1 << 32);
            try testArgs(u32, u33, 0);
            try testArgs(u32, u33, 1 << 0);
            try testArgs(u32, u33, 1 << 32);
            try testArgs(u64, u33, 0);
            try testArgs(u64, u33, 1 << 0);
            try testArgs(u64, u33, 1 << 32);
            try testArgs(u128, u33, 0);
            try testArgs(u128, u33, 1 << 0);
            try testArgs(u128, u33, 1 << 32);
            try testArgs(u256, u33, 0);
            try testArgs(u256, u33, 1 << 0);
            try testArgs(u256, u33, 1 << 32);
            try testArgs(u512, u33, 0);
            try testArgs(u512, u33, 1 << 0);
            try testArgs(u512, u33, 1 << 32);
            try testArgs(u1024, u33, 0);
            try testArgs(u1024, u33, 1 << 0);
            try testArgs(u1024, u33, 1 << 32);

            try testArgs(i8, i63, -1 << 62);
            try testArgs(i8, i63, -1);
            try testArgs(i8, i63, 0);
            try testArgs(i16, i63, -1 << 62);
            try testArgs(i16, i63, -1);
            try testArgs(i16, i63, 0);
            try testArgs(i32, i63, -1 << 62);
            try testArgs(i32, i63, -1);
            try testArgs(i32, i63, 0);
            try testArgs(i64, i63, -1 << 62);
            try testArgs(i64, i63, -1);
            try testArgs(i64, i63, 0);
            try testArgs(i128, i63, -1 << 62);
            try testArgs(i128, i63, -1);
            try testArgs(i128, i63, 0);
            try testArgs(i256, i63, -1 << 62);
            try testArgs(i256, i63, -1);
            try testArgs(i256, i63, 0);
            try testArgs(i512, i63, -1 << 62);
            try testArgs(i512, i63, -1);
            try testArgs(i512, i63, 0);
            try testArgs(i1024, i63, -1 << 62);
            try testArgs(i1024, i63, -1);
            try testArgs(i1024, i63, 0);
            try testArgs(u8, u63, 0);
            try testArgs(u8, u63, 1 << 0);
            try testArgs(u8, u63, 1 << 62);
            try testArgs(u16, u63, 0);
            try testArgs(u16, u63, 1 << 0);
            try testArgs(u16, u63, 1 << 62);
            try testArgs(u32, u63, 0);
            try testArgs(u32, u63, 1 << 0);
            try testArgs(u32, u63, 1 << 62);
            try testArgs(u64, u63, 0);
            try testArgs(u64, u63, 1 << 0);
            try testArgs(u64, u63, 1 << 62);
            try testArgs(u128, u63, 0);
            try testArgs(u128, u63, 1 << 0);
            try testArgs(u128, u63, 1 << 62);
            try testArgs(u256, u63, 0);
            try testArgs(u256, u63, 1 << 0);
            try testArgs(u256, u63, 1 << 62);
            try testArgs(u512, u63, 0);
            try testArgs(u512, u63, 1 << 0);
            try testArgs(u512, u63, 1 << 62);
            try testArgs(u1024, u63, 0);
            try testArgs(u1024, u63, 1 << 0);
            try testArgs(u1024, u63, 1 << 62);

            try testArgs(i8, i64, -1 << 63);
            try testArgs(i8, i64, -1);
            try testArgs(i8, i64, 0);
            try testArgs(i16, i64, -1 << 63);
            try testArgs(i16, i64, -1);
            try testArgs(i16, i64, 0);
            try testArgs(i32, i64, -1 << 63);
            try testArgs(i32, i64, -1);
            try testArgs(i32, i64, 0);
            try testArgs(i64, i64, -1 << 63);
            try testArgs(i64, i64, -1);
            try testArgs(i64, i64, 0);
            try testArgs(i128, i64, -1 << 63);
            try testArgs(i128, i64, -1);
            try testArgs(i128, i64, 0);
            try testArgs(i256, i64, -1 << 63);
            try testArgs(i256, i64, -1);
            try testArgs(i256, i64, 0);
            try testArgs(i512, i64, -1 << 63);
            try testArgs(i512, i64, -1);
            try testArgs(i512, i64, 0);
            try testArgs(i1024, i64, -1 << 63);
            try testArgs(i1024, i64, -1);
            try testArgs(i1024, i64, 0);
            try testArgs(u8, u64, 0);
            try testArgs(u8, u64, 1 << 0);
            try testArgs(u8, u64, 1 << 63);
            try testArgs(u16, u64, 0);
            try testArgs(u16, u64, 1 << 0);
            try testArgs(u16, u64, 1 << 63);
            try testArgs(u32, u64, 0);
            try testArgs(u32, u64, 1 << 0);
            try testArgs(u32, u64, 1 << 63);
            try testArgs(u64, u64, 0);
            try testArgs(u64, u64, 1 << 0);
            try testArgs(u64, u64, 1 << 63);
            try testArgs(u128, u64, 0);
            try testArgs(u128, u64, 1 << 0);
            try testArgs(u128, u64, 1 << 63);
            try testArgs(u256, u64, 0);
            try testArgs(u256, u64, 1 << 0);
            try testArgs(u256, u64, 1 << 63);
            try testArgs(u512, u64, 0);
            try testArgs(u512, u64, 1 << 0);
            try testArgs(u512, u64, 1 << 63);
            try testArgs(u1024, u64, 0);
            try testArgs(u1024, u64, 1 << 0);
            try testArgs(u1024, u64, 1 << 63);

            try testArgs(i8, i65, -1 << 64);
            try testArgs(i8, i65, -1);
            try testArgs(i8, i65, 0);
            try testArgs(i16, i65, -1 << 64);
            try testArgs(i16, i65, -1);
            try testArgs(i16, i65, 0);
            try testArgs(i32, i65, -1 << 64);
            try testArgs(i32, i65, -1);
            try testArgs(i32, i65, 0);
            try testArgs(i64, i65, -1 << 64);
            try testArgs(i64, i65, -1);
            try testArgs(i64, i65, 0);
            try testArgs(i128, i65, -1 << 64);
            try testArgs(i128, i65, -1);
            try testArgs(i128, i65, 0);
            try testArgs(i256, i65, -1 << 64);
            try testArgs(i256, i65, -1);
            try testArgs(i256, i65, 0);
            try testArgs(i512, i65, -1 << 64);
            try testArgs(i512, i65, -1);
            try testArgs(i512, i65, 0);
            try testArgs(i1024, i65, -1 << 64);
            try testArgs(i1024, i65, -1);
            try testArgs(i1024, i65, 0);
            try testArgs(u8, u65, 0);
            try testArgs(u8, u65, 1 << 0);
            try testArgs(u8, u65, 1 << 64);
            try testArgs(u16, u65, 0);
            try testArgs(u16, u65, 1 << 0);
            try testArgs(u16, u65, 1 << 64);
            try testArgs(u32, u65, 0);
            try testArgs(u32, u65, 1 << 0);
            try testArgs(u32, u65, 1 << 64);
            try testArgs(u64, u65, 0);
            try testArgs(u64, u65, 1 << 0);
            try testArgs(u64, u65, 1 << 64);
            try testArgs(u128, u65, 0);
            try testArgs(u128, u65, 1 << 0);
            try testArgs(u128, u65, 1 << 64);
            try testArgs(u256, u65, 0);
            try testArgs(u256, u65, 1 << 0);
            try testArgs(u256, u65, 1 << 64);
            try testArgs(u512, u65, 0);
            try testArgs(u512, u65, 1 << 0);
            try testArgs(u512, u65, 1 << 64);
            try testArgs(u1024, u65, 0);
            try testArgs(u1024, u65, 1 << 0);
            try testArgs(u1024, u65, 1 << 64);

            try testArgs(i8, i95, -1 << 94);
            try testArgs(i8, i95, -1);
            try testArgs(i8, i95, 0);
            try testArgs(i16, i95, -1 << 94);
            try testArgs(i16, i95, -1);
            try testArgs(i16, i95, 0);
            try testArgs(i32, i95, -1 << 94);
            try testArgs(i32, i95, -1);
            try testArgs(i32, i95, 0);
            try testArgs(i64, i95, -1 << 94);
            try testArgs(i64, i95, -1);
            try testArgs(i64, i95, 0);
            try testArgs(i128, i95, -1 << 94);
            try testArgs(i128, i95, -1);
            try testArgs(i128, i95, 0);
            try testArgs(i256, i95, -1 << 94);
            try testArgs(i256, i95, -1);
            try testArgs(i256, i95, 0);
            try testArgs(i512, i95, -1 << 94);
            try testArgs(i512, i95, -1);
            try testArgs(i512, i95, 0);
            try testArgs(i1024, i95, -1 << 94);
            try testArgs(i1024, i95, -1);
            try testArgs(i1024, i95, 0);
            try testArgs(u8, u95, 0);
            try testArgs(u8, u95, 1 << 0);
            try testArgs(u8, u95, 1 << 94);
            try testArgs(u16, u95, 0);
            try testArgs(u16, u95, 1 << 0);
            try testArgs(u16, u95, 1 << 94);
            try testArgs(u32, u95, 0);
            try testArgs(u32, u95, 1 << 0);
            try testArgs(u32, u95, 1 << 94);
            try testArgs(u64, u95, 0);
            try testArgs(u64, u95, 1 << 0);
            try testArgs(u64, u95, 1 << 94);
            try testArgs(u128, u95, 0);
            try testArgs(u128, u95, 1 << 0);
            try testArgs(u128, u95, 1 << 94);
            try testArgs(u256, u95, 0);
            try testArgs(u256, u95, 1 << 0);
            try testArgs(u256, u95, 1 << 94);
            try testArgs(u512, u95, 0);
            try testArgs(u512, u95, 1 << 0);
            try testArgs(u512, u95, 1 << 94);
            try testArgs(u1024, u95, 0);
            try testArgs(u1024, u95, 1 << 0);
            try testArgs(u1024, u95, 1 << 94);

            try testArgs(i8, i97, -1 << 96);
            try testArgs(i8, i97, -1);
            try testArgs(i8, i97, 0);
            try testArgs(i16, i97, -1 << 96);
            try testArgs(i16, i97, -1);
            try testArgs(i16, i97, 0);
            try testArgs(i32, i97, -1 << 96);
            try testArgs(i32, i97, -1);
            try testArgs(i32, i97, 0);
            try testArgs(i64, i97, -1 << 96);
            try testArgs(i64, i97, -1);
            try testArgs(i64, i97, 0);
            try testArgs(i128, i97, -1 << 96);
            try testArgs(i128, i97, -1);
            try testArgs(i128, i97, 0);
            try testArgs(i256, i97, -1 << 96);
            try testArgs(i256, i97, -1);
            try testArgs(i256, i97, 0);
            try testArgs(i512, i97, -1 << 96);
            try testArgs(i512, i97, -1);
            try testArgs(i512, i97, 0);
            try testArgs(i1024, i97, -1 << 96);
            try testArgs(i1024, i97, -1);
            try testArgs(i1024, i97, 0);
            try testArgs(u8, u97, 0);
            try testArgs(u8, u97, 1 << 0);
            try testArgs(u8, u97, 1 << 96);
            try testArgs(u16, u97, 0);
            try testArgs(u16, u97, 1 << 0);
            try testArgs(u16, u97, 1 << 96);
            try testArgs(u32, u97, 0);
            try testArgs(u32, u97, 1 << 0);
            try testArgs(u32, u97, 1 << 96);
            try testArgs(u64, u97, 0);
            try testArgs(u64, u97, 1 << 0);
            try testArgs(u64, u97, 1 << 96);
            try testArgs(u128, u97, 0);
            try testArgs(u128, u97, 1 << 0);
            try testArgs(u128, u97, 1 << 96);
            try testArgs(u256, u97, 0);
            try testArgs(u256, u97, 1 << 0);
            try testArgs(u256, u97, 1 << 96);
            try testArgs(u512, u97, 0);
            try testArgs(u512, u97, 1 << 0);
            try testArgs(u512, u97, 1 << 96);
            try testArgs(u1024, u97, 0);
            try testArgs(u1024, u97, 1 << 0);
            try testArgs(u1024, u97, 1 << 96);

            try testArgs(i8, i127, -1 << 126);
            try testArgs(i8, i127, -1);
            try testArgs(i8, i127, 0);
            try testArgs(i16, i127, -1 << 126);
            try testArgs(i16, i127, -1);
            try testArgs(i16, i127, 0);
            try testArgs(i32, i127, -1 << 126);
            try testArgs(i32, i127, -1);
            try testArgs(i32, i127, 0);
            try testArgs(i64, i127, -1 << 126);
            try testArgs(i64, i127, -1);
            try testArgs(i64, i127, 0);
            try testArgs(i128, i127, -1 << 126);
            try testArgs(i128, i127, -1);
            try testArgs(i128, i127, 0);
            try testArgs(i256, i127, -1 << 126);
            try testArgs(i256, i127, -1);
            try testArgs(i256, i127, 0);
            try testArgs(i512, i127, -1 << 126);
            try testArgs(i512, i127, -1);
            try testArgs(i512, i127, 0);
            try testArgs(i1024, i127, -1 << 126);
            try testArgs(i1024, i127, -1);
            try testArgs(i1024, i127, 0);
            try testArgs(u8, u127, 0);
            try testArgs(u8, u127, 1 << 0);
            try testArgs(u8, u127, 1 << 126);
            try testArgs(u16, u127, 0);
            try testArgs(u16, u127, 1 << 0);
            try testArgs(u16, u127, 1 << 126);
            try testArgs(u32, u127, 0);
            try testArgs(u32, u127, 1 << 0);
            try testArgs(u32, u127, 1 << 126);
            try testArgs(u64, u127, 0);
            try testArgs(u64, u127, 1 << 0);
            try testArgs(u64, u127, 1 << 126);
            try testArgs(u128, u127, 0);
            try testArgs(u128, u127, 1 << 0);
            try testArgs(u128, u127, 1 << 126);
            try testArgs(u256, u127, 0);
            try testArgs(u256, u127, 1 << 0);
            try testArgs(u256, u127, 1 << 126);
            try testArgs(u512, u127, 0);
            try testArgs(u512, u127, 1 << 0);
            try testArgs(u512, u127, 1 << 126);
            try testArgs(u1024, u127, 0);
            try testArgs(u1024, u127, 1 << 0);
            try testArgs(u1024, u127, 1 << 126);

            try testArgs(i8, i128, -1 << 127);
            try testArgs(i8, i128, -1);
            try testArgs(i8, i128, 0);
            try testArgs(i16, i128, -1 << 127);
            try testArgs(i16, i128, -1);
            try testArgs(i16, i128, 0);
            try testArgs(i32, i128, -1 << 127);
            try testArgs(i32, i128, -1);
            try testArgs(i32, i128, 0);
            try testArgs(i64, i128, -1 << 127);
            try testArgs(i64, i128, -1);
            try testArgs(i64, i128, 0);
            try testArgs(i128, i128, -1 << 127);
            try testArgs(i128, i128, -1);
            try testArgs(i128, i128, 0);
            try testArgs(i256, i128, -1 << 127);
            try testArgs(i256, i128, -1);
            try testArgs(i256, i128, 0);
            try testArgs(i512, i128, -1 << 127);
            try testArgs(i512, i128, -1);
            try testArgs(i512, i128, 0);
            try testArgs(i1024, i128, -1 << 127);
            try testArgs(i1024, i128, -1);
            try testArgs(i1024, i128, 0);
            try testArgs(u8, u128, 0);
            try testArgs(u8, u128, 1 << 0);
            try testArgs(u8, u128, 1 << 127);
            try testArgs(u16, u128, 0);
            try testArgs(u16, u128, 1 << 0);
            try testArgs(u16, u128, 1 << 127);
            try testArgs(u32, u128, 0);
            try testArgs(u32, u128, 1 << 0);
            try testArgs(u32, u128, 1 << 127);
            try testArgs(u64, u128, 0);
            try testArgs(u64, u128, 1 << 0);
            try testArgs(u64, u128, 1 << 127);
            try testArgs(u128, u128, 0);
            try testArgs(u128, u128, 1 << 0);
            try testArgs(u128, u128, 1 << 127);
            try testArgs(u256, u128, 0);
            try testArgs(u256, u128, 1 << 0);
            try testArgs(u256, u128, 1 << 127);
            try testArgs(u512, u128, 0);
            try testArgs(u512, u128, 1 << 0);
            try testArgs(u512, u128, 1 << 127);
            try testArgs(u1024, u128, 0);
            try testArgs(u1024, u128, 1 << 0);
            try testArgs(u1024, u128, 1 << 127);

            try testArgs(i8, i129, -1 << 128);
            try testArgs(i8, i129, -1);
            try testArgs(i8, i129, 0);
            try testArgs(i16, i129, -1 << 128);
            try testArgs(i16, i129, -1);
            try testArgs(i16, i129, 0);
            try testArgs(i32, i129, -1 << 128);
            try testArgs(i32, i129, -1);
            try testArgs(i32, i129, 0);
            try testArgs(i64, i129, -1 << 128);
            try testArgs(i64, i129, -1);
            try testArgs(i64, i129, 0);
            try testArgs(i128, i129, -1 << 128);
            try testArgs(i128, i129, -1);
            try testArgs(i128, i129, 0);
            try testArgs(i256, i129, -1 << 128);
            try testArgs(i256, i129, -1);
            try testArgs(i256, i129, 0);
            try testArgs(i512, i129, -1 << 128);
            try testArgs(i512, i129, -1);
            try testArgs(i512, i129, 0);
            try testArgs(i1024, i129, -1 << 128);
            try testArgs(i1024, i129, -1);
            try testArgs(i1024, i129, 0);
            try testArgs(u8, u129, 0);
            try testArgs(u8, u129, 1 << 0);
            try testArgs(u8, u129, 1 << 128);
            try testArgs(u16, u129, 0);
            try testArgs(u16, u129, 1 << 0);
            try testArgs(u16, u129, 1 << 128);
            try testArgs(u32, u129, 0);
            try testArgs(u32, u129, 1 << 0);
            try testArgs(u32, u129, 1 << 128);
            try testArgs(u64, u129, 0);
            try testArgs(u64, u129, 1 << 0);
            try testArgs(u64, u129, 1 << 128);
            try testArgs(u128, u129, 0);
            try testArgs(u128, u129, 1 << 0);
            try testArgs(u128, u129, 1 << 128);
            try testArgs(u256, u129, 0);
            try testArgs(u256, u129, 1 << 0);
            try testArgs(u256, u129, 1 << 128);
            try testArgs(u512, u129, 0);
            try testArgs(u512, u129, 1 << 0);
            try testArgs(u512, u129, 1 << 128);
            try testArgs(u1024, u129, 0);
            try testArgs(u1024, u129, 1 << 0);
            try testArgs(u1024, u129, 1 << 128);

            try testArgs(i8, i255, -1 << 254);
            try testArgs(i8, i255, -1);
            try testArgs(i8, i255, 0);
            try testArgs(i16, i255, -1 << 254);
            try testArgs(i16, i255, -1);
            try testArgs(i16, i255, 0);
            try testArgs(i32, i255, -1 << 254);
            try testArgs(i32, i255, -1);
            try testArgs(i32, i255, 0);
            try testArgs(i64, i255, -1 << 254);
            try testArgs(i64, i255, -1);
            try testArgs(i64, i255, 0);
            try testArgs(i128, i255, -1 << 254);
            try testArgs(i128, i255, -1);
            try testArgs(i128, i255, 0);
            try testArgs(i256, i255, -1 << 254);
            try testArgs(i256, i255, -1);
            try testArgs(i256, i255, 0);
            try testArgs(i512, i255, -1 << 254);
            try testArgs(i512, i255, -1);
            try testArgs(i512, i255, 0);
            try testArgs(i1024, i255, -1 << 254);
            try testArgs(i1024, i255, -1);
            try testArgs(i1024, i255, 0);
            try testArgs(u8, u255, 0);
            try testArgs(u8, u255, 1 << 0);
            try testArgs(u8, u255, 1 << 254);
            try testArgs(u16, u255, 0);
            try testArgs(u16, u255, 1 << 0);
            try testArgs(u16, u255, 1 << 254);
            try testArgs(u32, u255, 0);
            try testArgs(u32, u255, 1 << 0);
            try testArgs(u32, u255, 1 << 254);
            try testArgs(u64, u255, 0);
            try testArgs(u64, u255, 1 << 0);
            try testArgs(u64, u255, 1 << 254);
            try testArgs(u128, u255, 0);
            try testArgs(u128, u255, 1 << 0);
            try testArgs(u128, u255, 1 << 254);
            try testArgs(u256, u255, 0);
            try testArgs(u256, u255, 1 << 0);
            try testArgs(u256, u255, 1 << 254);
            try testArgs(u512, u255, 0);
            try testArgs(u512, u255, 1 << 0);
            try testArgs(u512, u255, 1 << 254);
            try testArgs(u1024, u255, 0);
            try testArgs(u1024, u255, 1 << 0);
            try testArgs(u1024, u255, 1 << 254);

            try testArgs(i8, i256, -1 << 255);
            try testArgs(i8, i256, -1);
            try testArgs(i8, i256, 0);
            try testArgs(i16, i256, -1 << 255);
            try testArgs(i16, i256, -1);
            try testArgs(i16, i256, 0);
            try testArgs(i32, i256, -1 << 255);
            try testArgs(i32, i256, -1);
            try testArgs(i32, i256, 0);
            try testArgs(i64, i256, -1 << 255);
            try testArgs(i64, i256, -1);
            try testArgs(i64, i256, 0);
            try testArgs(i128, i256, -1 << 255);
            try testArgs(i128, i256, -1);
            try testArgs(i128, i256, 0);
            try testArgs(i256, i256, -1 << 255);
            try testArgs(i256, i256, -1);
            try testArgs(i256, i256, 0);
            try testArgs(i512, i256, -1 << 255);
            try testArgs(i512, i256, -1);
            try testArgs(i512, i256, 0);
            try testArgs(i1024, i256, -1 << 255);
            try testArgs(i1024, i256, -1);
            try testArgs(i1024, i256, 0);
            try testArgs(u8, u256, 0);
            try testArgs(u8, u256, 1 << 0);
            try testArgs(u8, u256, 1 << 255);
            try testArgs(u16, u256, 0);
            try testArgs(u16, u256, 1 << 0);
            try testArgs(u16, u256, 1 << 255);
            try testArgs(u32, u256, 0);
            try testArgs(u32, u256, 1 << 0);
            try testArgs(u32, u256, 1 << 255);
            try testArgs(u64, u256, 0);
            try testArgs(u64, u256, 1 << 0);
            try testArgs(u64, u256, 1 << 255);
            try testArgs(u128, u256, 0);
            try testArgs(u128, u256, 1 << 0);
            try testArgs(u128, u256, 1 << 255);
            try testArgs(u256, u256, 0);
            try testArgs(u256, u256, 1 << 0);
            try testArgs(u256, u256, 1 << 255);
            try testArgs(u512, u256, 0);
            try testArgs(u512, u256, 1 << 0);
            try testArgs(u512, u256, 1 << 255);
            try testArgs(u1024, u256, 0);
            try testArgs(u1024, u256, 1 << 0);
            try testArgs(u1024, u256, 1 << 255);

            try testArgs(i8, i257, -1 << 256);
            try testArgs(i8, i257, -1);
            try testArgs(i8, i257, 0);
            try testArgs(i16, i257, -1 << 256);
            try testArgs(i16, i257, -1);
            try testArgs(i16, i257, 0);
            try testArgs(i32, i257, -1 << 256);
            try testArgs(i32, i257, -1);
            try testArgs(i32, i257, 0);
            try testArgs(i64, i257, -1 << 256);
            try testArgs(i64, i257, -1);
            try testArgs(i64, i257, 0);
            try testArgs(i128, i257, -1 << 256);
            try testArgs(i128, i257, -1);
            try testArgs(i128, i257, 0);
            try testArgs(i256, i257, -1 << 256);
            try testArgs(i256, i257, -1);
            try testArgs(i256, i257, 0);
            try testArgs(i512, i257, -1 << 256);
            try testArgs(i512, i257, -1);
            try testArgs(i512, i257, 0);
            try testArgs(i1024, i257, -1 << 256);
            try testArgs(i1024, i257, -1);
            try testArgs(i1024, i257, 0);
            try testArgs(u8, u257, 0);
            try testArgs(u8, u257, 1 << 0);
            try testArgs(u8, u257, 1 << 256);
            try testArgs(u16, u257, 0);
            try testArgs(u16, u257, 1 << 0);
            try testArgs(u16, u257, 1 << 256);
            try testArgs(u32, u257, 0);
            try testArgs(u32, u257, 1 << 0);
            try testArgs(u32, u257, 1 << 256);
            try testArgs(u64, u257, 0);
            try testArgs(u64, u257, 1 << 0);
            try testArgs(u64, u257, 1 << 256);
            try testArgs(u128, u257, 0);
            try testArgs(u128, u257, 1 << 0);
            try testArgs(u128, u257, 1 << 256);
            try testArgs(u256, u257, 0);
            try testArgs(u256, u257, 1 << 0);
            try testArgs(u256, u257, 1 << 256);
            try testArgs(u512, u257, 0);
            try testArgs(u512, u257, 1 << 0);
            try testArgs(u512, u257, 1 << 256);
            try testArgs(u1024, u257, 0);
            try testArgs(u1024, u257, 1 << 0);
            try testArgs(u1024, u257, 1 << 256);

            try testArgs(i8, i511, -1 << 510);
            try testArgs(i8, i511, -1);
            try testArgs(i8, i511, 0);
            try testArgs(i16, i511, -1 << 510);
            try testArgs(i16, i511, -1);
            try testArgs(i16, i511, 0);
            try testArgs(i32, i511, -1 << 510);
            try testArgs(i32, i511, -1);
            try testArgs(i32, i511, 0);
            try testArgs(i64, i511, -1 << 510);
            try testArgs(i64, i511, -1);
            try testArgs(i64, i511, 0);
            try testArgs(i128, i511, -1 << 510);
            try testArgs(i128, i511, -1);
            try testArgs(i128, i511, 0);
            try testArgs(i256, i511, -1 << 510);
            try testArgs(i256, i511, -1);
            try testArgs(i256, i511, 0);
            try testArgs(i512, i511, -1 << 510);
            try testArgs(i512, i511, -1);
            try testArgs(i512, i511, 0);
            try testArgs(i1024, i511, -1 << 510);
            try testArgs(i1024, i511, -1);
            try testArgs(i1024, i511, 0);
            try testArgs(u8, u511, 0);
            try testArgs(u8, u511, 1 << 0);
            try testArgs(u8, u511, 1 << 510);
            try testArgs(u16, u511, 0);
            try testArgs(u16, u511, 1 << 0);
            try testArgs(u16, u511, 1 << 510);
            try testArgs(u32, u511, 0);
            try testArgs(u32, u511, 1 << 0);
            try testArgs(u32, u511, 1 << 510);
            try testArgs(u64, u511, 0);
            try testArgs(u64, u511, 1 << 0);
            try testArgs(u64, u511, 1 << 510);
            try testArgs(u128, u511, 0);
            try testArgs(u128, u511, 1 << 0);
            try testArgs(u128, u511, 1 << 510);
            try testArgs(u256, u511, 0);
            try testArgs(u256, u511, 1 << 0);
            try testArgs(u256, u511, 1 << 510);
            try testArgs(u512, u511, 0);
            try testArgs(u512, u511, 1 << 0);
            try testArgs(u512, u511, 1 << 510);
            try testArgs(u1024, u511, 0);
            try testArgs(u1024, u511, 1 << 0);
            try testArgs(u1024, u511, 1 << 510);

            try testArgs(i8, i512, -1 << 511);
            try testArgs(i8, i512, -1);
            try testArgs(i8, i512, 0);
            try testArgs(i16, i512, -1 << 511);
            try testArgs(i16, i512, -1);
            try testArgs(i16, i512, 0);
            try testArgs(i32, i512, -1 << 511);
            try testArgs(i32, i512, -1);
            try testArgs(i32, i512, 0);
            try testArgs(i64, i512, -1 << 511);
            try testArgs(i64, i512, -1);
            try testArgs(i64, i512, 0);
            try testArgs(i128, i512, -1 << 511);
            try testArgs(i128, i512, -1);
            try testArgs(i128, i512, 0);
            try testArgs(i256, i512, -1 << 511);
            try testArgs(i256, i512, -1);
            try testArgs(i256, i512, 0);
            try testArgs(i512, i512, -1 << 511);
            try testArgs(i512, i512, -1);
            try testArgs(i512, i512, 0);
            try testArgs(i1024, i512, -1 << 511);
            try testArgs(i1024, i512, -1);
            try testArgs(i1024, i512, 0);
            try testArgs(u8, u512, 0);
            try testArgs(u8, u512, 1 << 0);
            try testArgs(u8, u512, 1 << 511);
            try testArgs(u16, u512, 0);
            try testArgs(u16, u512, 1 << 0);
            try testArgs(u16, u512, 1 << 511);
            try testArgs(u32, u512, 0);
            try testArgs(u32, u512, 1 << 0);
            try testArgs(u32, u512, 1 << 511);
            try testArgs(u64, u512, 0);
            try testArgs(u64, u512, 1 << 0);
            try testArgs(u64, u512, 1 << 511);
            try testArgs(u128, u512, 0);
            try testArgs(u128, u512, 1 << 0);
            try testArgs(u128, u512, 1 << 511);
            try testArgs(u256, u512, 0);
            try testArgs(u256, u512, 1 << 0);
            try testArgs(u256, u512, 1 << 511);
            try testArgs(u512, u512, 0);
            try testArgs(u512, u512, 1 << 0);
            try testArgs(u512, u512, 1 << 511);
            try testArgs(u1024, u512, 0);
            try testArgs(u1024, u512, 1 << 0);
            try testArgs(u1024, u512, 1 << 511);

            try testArgs(i8, i513, -1 << 512);
            try testArgs(i8, i513, -1);
            try testArgs(i8, i513, 0);
            try testArgs(i16, i513, -1 << 512);
            try testArgs(i16, i513, -1);
            try testArgs(i16, i513, 0);
            try testArgs(i32, i513, -1 << 512);
            try testArgs(i32, i513, -1);
            try testArgs(i32, i513, 0);
            try testArgs(i64, i513, -1 << 512);
            try testArgs(i64, i513, -1);
            try testArgs(i64, i513, 0);
            try testArgs(i128, i513, -1 << 512);
            try testArgs(i128, i513, -1);
            try testArgs(i128, i513, 0);
            try testArgs(i256, i513, -1 << 512);
            try testArgs(i256, i513, -1);
            try testArgs(i256, i513, 0);
            try testArgs(i512, i513, -1 << 512);
            try testArgs(i512, i513, -1);
            try testArgs(i512, i513, 0);
            try testArgs(i1024, i513, -1 << 512);
            try testArgs(i1024, i513, -1);
            try testArgs(i1024, i513, 0);
            try testArgs(u8, u513, 0);
            try testArgs(u8, u513, 1 << 0);
            try testArgs(u8, u513, 1 << 512);
            try testArgs(u16, u513, 0);
            try testArgs(u16, u513, 1 << 0);
            try testArgs(u16, u513, 1 << 512);
            try testArgs(u32, u513, 0);
            try testArgs(u32, u513, 1 << 0);
            try testArgs(u32, u513, 1 << 512);
            try testArgs(u64, u513, 0);
            try testArgs(u64, u513, 1 << 0);
            try testArgs(u64, u513, 1 << 512);
            try testArgs(u128, u513, 0);
            try testArgs(u128, u513, 1 << 0);
            try testArgs(u128, u513, 1 << 512);
            try testArgs(u256, u513, 0);
            try testArgs(u256, u513, 1 << 0);
            try testArgs(u256, u513, 1 << 512);
            try testArgs(u512, u513, 0);
            try testArgs(u512, u513, 1 << 0);
            try testArgs(u512, u513, 1 << 512);
            try testArgs(u1024, u513, 0);
            try testArgs(u1024, u513, 1 << 0);
            try testArgs(u1024, u513, 1 << 512);

            try testArgs(i8, i1023, -1 << 1022);
            try testArgs(i8, i1023, -1);
            try testArgs(i8, i1023, 0);
            try testArgs(i16, i1023, -1 << 1022);
            try testArgs(i16, i1023, -1);
            try testArgs(i16, i1023, 0);
            try testArgs(i32, i1023, -1 << 1022);
            try testArgs(i32, i1023, -1);
            try testArgs(i32, i1023, 0);
            try testArgs(i64, i1023, -1 << 1022);
            try testArgs(i64, i1023, -1);
            try testArgs(i64, i1023, 0);
            try testArgs(i128, i1023, -1 << 1022);
            try testArgs(i128, i1023, -1);
            try testArgs(i128, i1023, 0);
            try testArgs(i256, i1023, -1 << 1022);
            try testArgs(i256, i1023, -1);
            try testArgs(i256, i1023, 0);
            try testArgs(i512, i1023, -1 << 1022);
            try testArgs(i512, i1023, -1);
            try testArgs(i512, i1023, 0);
            try testArgs(i1024, i1023, -1 << 1022);
            try testArgs(i1024, i1023, -1);
            try testArgs(i1024, i1023, 0);
            try testArgs(u8, u1023, 0);
            try testArgs(u8, u1023, 1 << 0);
            try testArgs(u8, u1023, 1 << 1022);
            try testArgs(u16, u1023, 0);
            try testArgs(u16, u1023, 1 << 0);
            try testArgs(u16, u1023, 1 << 1022);
            try testArgs(u32, u1023, 0);
            try testArgs(u32, u1023, 1 << 0);
            try testArgs(u32, u1023, 1 << 1022);
            try testArgs(u64, u1023, 0);
            try testArgs(u64, u1023, 1 << 0);
            try testArgs(u64, u1023, 1 << 1022);
            try testArgs(u128, u1023, 0);
            try testArgs(u128, u1023, 1 << 0);
            try testArgs(u128, u1023, 1 << 1022);
            try testArgs(u256, u1023, 0);
            try testArgs(u256, u1023, 1 << 0);
            try testArgs(u256, u1023, 1 << 1022);
            try testArgs(u512, u1023, 0);
            try testArgs(u512, u1023, 1 << 0);
            try testArgs(u512, u1023, 1 << 1022);
            try testArgs(u1024, u1023, 0);
            try testArgs(u1024, u1023, 1 << 0);
            try testArgs(u1024, u1023, 1 << 1022);

            try testArgs(i8, i1024, -1 << 1023);
            try testArgs(i8, i1024, -1);
            try testArgs(i8, i1024, 0);
            try testArgs(i16, i1024, -1 << 1023);
            try testArgs(i16, i1024, -1);
            try testArgs(i16, i1024, 0);
            try testArgs(i32, i1024, -1 << 1023);
            try testArgs(i32, i1024, -1);
            try testArgs(i32, i1024, 0);
            try testArgs(i64, i1024, -1 << 1023);
            try testArgs(i64, i1024, -1);
            try testArgs(i64, i1024, 0);
            try testArgs(i128, i1024, -1 << 1023);
            try testArgs(i128, i1024, -1);
            try testArgs(i128, i1024, 0);
            try testArgs(i256, i1024, -1 << 1023);
            try testArgs(i256, i1024, -1);
            try testArgs(i256, i1024, 0);
            try testArgs(i512, i1024, -1 << 1023);
            try testArgs(i512, i1024, -1);
            try testArgs(i512, i1024, 0);
            try testArgs(i1024, i1024, -1 << 1023);
            try testArgs(i1024, i1024, -1);
            try testArgs(i1024, i1024, 0);
            try testArgs(u8, u1024, 0);
            try testArgs(u8, u1024, 1 << 0);
            try testArgs(u8, u1024, 1 << 1023);
            try testArgs(u16, u1024, 0);
            try testArgs(u16, u1024, 1 << 0);
            try testArgs(u16, u1024, 1 << 1023);
            try testArgs(u32, u1024, 0);
            try testArgs(u32, u1024, 1 << 0);
            try testArgs(u32, u1024, 1 << 1023);
            try testArgs(u64, u1024, 0);
            try testArgs(u64, u1024, 1 << 0);
            try testArgs(u64, u1024, 1 << 1023);
            try testArgs(u128, u1024, 0);
            try testArgs(u128, u1024, 1 << 0);
            try testArgs(u128, u1024, 1 << 1023);
            try testArgs(u256, u1024, 0);
            try testArgs(u256, u1024, 1 << 0);
            try testArgs(u256, u1024, 1 << 1023);
            try testArgs(u512, u1024, 0);
            try testArgs(u512, u1024, 1 << 0);
            try testArgs(u512, u1024, 1 << 1023);
            try testArgs(u1024, u1024, 0);
            try testArgs(u1024, u1024, 1 << 0);
            try testArgs(u1024, u1024, 1 << 1023);

            try testArgs(i8, i1025, -1 << 1024);
            try testArgs(i8, i1025, -1);
            try testArgs(i8, i1025, 0);
            try testArgs(i16, i1025, -1 << 1024);
            try testArgs(i16, i1025, -1);
            try testArgs(i16, i1025, 0);
            try testArgs(i32, i1025, -1 << 1024);
            try testArgs(i32, i1025, -1);
            try testArgs(i32, i1025, 0);
            try testArgs(i64, i1025, -1 << 1024);
            try testArgs(i64, i1025, -1);
            try testArgs(i64, i1025, 0);
            try testArgs(i128, i1025, -1 << 1024);
            try testArgs(i128, i1025, -1);
            try testArgs(i128, i1025, 0);
            try testArgs(i256, i1025, -1 << 1024);
            try testArgs(i256, i1025, -1);
            try testArgs(i256, i1025, 0);
            try testArgs(i512, i1025, -1 << 1024);
            try testArgs(i512, i1025, -1);
            try testArgs(i512, i1025, 0);
            try testArgs(i1024, i1025, -1 << 1024);
            try testArgs(i1024, i1025, -1);
            try testArgs(i1024, i1025, 0);
            try testArgs(u8, u1025, 0);
            try testArgs(u8, u1025, 1 << 0);
            try testArgs(u8, u1025, 1 << 1024);
            try testArgs(u16, u1025, 0);
            try testArgs(u16, u1025, 1 << 0);
            try testArgs(u16, u1025, 1 << 1024);
            try testArgs(u32, u1025, 0);
            try testArgs(u32, u1025, 1 << 0);
            try testArgs(u32, u1025, 1 << 1024);
            try testArgs(u64, u1025, 0);
            try testArgs(u64, u1025, 1 << 0);
            try testArgs(u64, u1025, 1 << 1024);
            try testArgs(u128, u1025, 0);
            try testArgs(u128, u1025, 1 << 0);
            try testArgs(u128, u1025, 1 << 1024);
            try testArgs(u256, u1025, 0);
            try testArgs(u256, u1025, 1 << 0);
            try testArgs(u256, u1025, 1 << 1024);
            try testArgs(u512, u1025, 0);
            try testArgs(u512, u1025, 1 << 0);
            try testArgs(u512, u1025, 1 << 1024);
            try testArgs(u1024, u1025, 0);
            try testArgs(u1024, u1025, 1 << 0);
            try testArgs(u1024, u1025, 1 << 1024);
        }
        fn testInts() !void {
            try testSameSignednessInts();

            try testArgs(u8, i1, -1);
            try testArgs(u8, i1, 0);
            try testArgs(u16, i1, -1);
            try testArgs(u16, i1, 0);
            try testArgs(u32, i1, -1);
            try testArgs(u32, i1, 0);
            try testArgs(u64, i1, -1);
            try testArgs(u64, i1, 0);
            try testArgs(u128, i1, -1);
            try testArgs(u128, i1, 0);
            try testArgs(u256, i1, -1);
            try testArgs(u256, i1, 0);
            try testArgs(u512, i1, -1);
            try testArgs(u512, i1, 0);
            try testArgs(u1024, i1, -1);
            try testArgs(u1024, i1, 0);
            try testArgs(i8, u1, 0);
            try testArgs(i8, u1, 1 << 0);
            try testArgs(i16, u1, 0);
            try testArgs(i16, u1, 1 << 0);
            try testArgs(i32, u1, 0);
            try testArgs(i32, u1, 1 << 0);
            try testArgs(i64, u1, 0);
            try testArgs(i64, u1, 1 << 0);
            try testArgs(i128, u1, 0);
            try testArgs(i128, u1, 1 << 0);
            try testArgs(i256, u1, 0);
            try testArgs(i256, u1, 1 << 0);
            try testArgs(i512, u1, 0);
            try testArgs(i512, u1, 1 << 0);
            try testArgs(i1024, u1, 0);
            try testArgs(i1024, u1, 1 << 0);

            try testArgs(u8, i2, -1 << 1);
            try testArgs(u8, i2, -1);
            try testArgs(u8, i2, 0);
            try testArgs(u16, i2, -1 << 1);
            try testArgs(u16, i2, -1);
            try testArgs(u16, i2, 0);
            try testArgs(u32, i2, -1 << 1);
            try testArgs(u32, i2, -1);
            try testArgs(u32, i2, 0);
            try testArgs(u64, i2, -1 << 1);
            try testArgs(u64, i2, -1);
            try testArgs(u64, i2, 0);
            try testArgs(u128, i2, -1 << 1);
            try testArgs(u128, i2, -1);
            try testArgs(u128, i2, 0);
            try testArgs(u256, i2, -1 << 1);
            try testArgs(u256, i2, -1);
            try testArgs(u256, i2, 0);
            try testArgs(u512, i2, -1 << 1);
            try testArgs(u512, i2, -1);
            try testArgs(u512, i2, 0);
            try testArgs(u1024, i2, -1 << 1);
            try testArgs(u1024, i2, -1);
            try testArgs(u1024, i2, 0);
            try testArgs(i8, u2, 0);
            try testArgs(i8, u2, 1 << 0);
            try testArgs(i8, u2, 1 << 1);
            try testArgs(i16, u2, 0);
            try testArgs(i16, u2, 1 << 0);
            try testArgs(i16, u2, 1 << 1);
            try testArgs(i32, u2, 0);
            try testArgs(i32, u2, 1 << 0);
            try testArgs(i32, u2, 1 << 1);
            try testArgs(i64, u2, 0);
            try testArgs(i64, u2, 1 << 0);
            try testArgs(i64, u2, 1 << 1);
            try testArgs(i128, u2, 0);
            try testArgs(i128, u2, 1 << 0);
            try testArgs(i128, u2, 1 << 1);
            try testArgs(i256, u2, 0);
            try testArgs(i256, u2, 1 << 0);
            try testArgs(i256, u2, 1 << 1);
            try testArgs(i512, u2, 0);
            try testArgs(i512, u2, 1 << 0);
            try testArgs(i512, u2, 1 << 1);
            try testArgs(i1024, u2, 0);
            try testArgs(i1024, u2, 1 << 0);
            try testArgs(i1024, u2, 1 << 1);

            try testArgs(u8, i3, -1 << 2);
            try testArgs(u8, i3, -1);
            try testArgs(u8, i3, 0);
            try testArgs(u16, i3, -1 << 2);
            try testArgs(u16, i3, -1);
            try testArgs(u16, i3, 0);
            try testArgs(u32, i3, -1 << 2);
            try testArgs(u32, i3, -1);
            try testArgs(u32, i3, 0);
            try testArgs(u64, i3, -1 << 2);
            try testArgs(u64, i3, -1);
            try testArgs(u64, i3, 0);
            try testArgs(u128, i3, -1 << 2);
            try testArgs(u128, i3, -1);
            try testArgs(u128, i3, 0);
            try testArgs(u256, i3, -1 << 2);
            try testArgs(u256, i3, -1);
            try testArgs(u256, i3, 0);
            try testArgs(u512, i3, -1 << 2);
            try testArgs(u512, i3, -1);
            try testArgs(u512, i3, 0);
            try testArgs(u1024, i3, -1 << 2);
            try testArgs(u1024, i3, -1);
            try testArgs(u1024, i3, 0);
            try testArgs(i8, u3, 0);
            try testArgs(i8, u3, 1 << 0);
            try testArgs(i8, u3, 1 << 2);
            try testArgs(i16, u3, 0);
            try testArgs(i16, u3, 1 << 0);
            try testArgs(i16, u3, 1 << 2);
            try testArgs(i32, u3, 0);
            try testArgs(i32, u3, 1 << 0);
            try testArgs(i32, u3, 1 << 2);
            try testArgs(i64, u3, 0);
            try testArgs(i64, u3, 1 << 0);
            try testArgs(i64, u3, 1 << 2);
            try testArgs(i128, u3, 0);
            try testArgs(i128, u3, 1 << 0);
            try testArgs(i128, u3, 1 << 2);
            try testArgs(i256, u3, 0);
            try testArgs(i256, u3, 1 << 0);
            try testArgs(i256, u3, 1 << 2);
            try testArgs(i512, u3, 0);
            try testArgs(i512, u3, 1 << 0);
            try testArgs(i512, u3, 1 << 2);
            try testArgs(i1024, u3, 0);
            try testArgs(i1024, u3, 1 << 0);
            try testArgs(i1024, u3, 1 << 2);

            try testArgs(u8, i4, -1 << 3);
            try testArgs(u8, i4, -1);
            try testArgs(u8, i4, 0);
            try testArgs(u16, i4, -1 << 3);
            try testArgs(u16, i4, -1);
            try testArgs(u16, i4, 0);
            try testArgs(u32, i4, -1 << 3);
            try testArgs(u32, i4, -1);
            try testArgs(u32, i4, 0);
            try testArgs(u64, i4, -1 << 3);
            try testArgs(u64, i4, -1);
            try testArgs(u64, i4, 0);
            try testArgs(u128, i4, -1 << 3);
            try testArgs(u128, i4, -1);
            try testArgs(u128, i4, 0);
            try testArgs(u256, i4, -1 << 3);
            try testArgs(u256, i4, -1);
            try testArgs(u256, i4, 0);
            try testArgs(u512, i4, -1 << 3);
            try testArgs(u512, i4, -1);
            try testArgs(u512, i4, 0);
            try testArgs(u1024, i4, -1 << 3);
            try testArgs(u1024, i4, -1);
            try testArgs(u1024, i4, 0);
            try testArgs(i8, u4, 0);
            try testArgs(i8, u4, 1 << 0);
            try testArgs(i8, u4, 1 << 3);
            try testArgs(i16, u4, 0);
            try testArgs(i16, u4, 1 << 0);
            try testArgs(i16, u4, 1 << 3);
            try testArgs(i32, u4, 0);
            try testArgs(i32, u4, 1 << 0);
            try testArgs(i32, u4, 1 << 3);
            try testArgs(i64, u4, 0);
            try testArgs(i64, u4, 1 << 0);
            try testArgs(i64, u4, 1 << 3);
            try testArgs(i128, u4, 0);
            try testArgs(i128, u4, 1 << 0);
            try testArgs(i128, u4, 1 << 3);
            try testArgs(i256, u4, 0);
            try testArgs(i256, u4, 1 << 0);
            try testArgs(i256, u4, 1 << 3);
            try testArgs(i512, u4, 0);
            try testArgs(i512, u4, 1 << 0);
            try testArgs(i512, u4, 1 << 3);
            try testArgs(i1024, u4, 0);
            try testArgs(i1024, u4, 1 << 0);
            try testArgs(i1024, u4, 1 << 3);

            try testArgs(u8, i5, -1 << 4);
            try testArgs(u8, i5, -1);
            try testArgs(u8, i5, 0);
            try testArgs(u16, i5, -1 << 4);
            try testArgs(u16, i5, -1);
            try testArgs(u16, i5, 0);
            try testArgs(u32, i5, -1 << 4);
            try testArgs(u32, i5, -1);
            try testArgs(u32, i5, 0);
            try testArgs(u64, i5, -1 << 4);
            try testArgs(u64, i5, -1);
            try testArgs(u64, i5, 0);
            try testArgs(u128, i5, -1 << 4);
            try testArgs(u128, i5, -1);
            try testArgs(u128, i5, 0);
            try testArgs(u256, i5, -1 << 4);
            try testArgs(u256, i5, -1);
            try testArgs(u256, i5, 0);
            try testArgs(u512, i5, -1 << 4);
            try testArgs(u512, i5, -1);
            try testArgs(u512, i5, 0);
            try testArgs(u1024, i5, -1 << 4);
            try testArgs(u1024, i5, -1);
            try testArgs(u1024, i5, 0);
            try testArgs(i8, u5, 0);
            try testArgs(i8, u5, 1 << 0);
            try testArgs(i8, u5, 1 << 4);
            try testArgs(i16, u5, 0);
            try testArgs(i16, u5, 1 << 0);
            try testArgs(i16, u5, 1 << 4);
            try testArgs(i32, u5, 0);
            try testArgs(i32, u5, 1 << 0);
            try testArgs(i32, u5, 1 << 4);
            try testArgs(i64, u5, 0);
            try testArgs(i64, u5, 1 << 0);
            try testArgs(i64, u5, 1 << 4);
            try testArgs(i128, u5, 0);
            try testArgs(i128, u5, 1 << 0);
            try testArgs(i128, u5, 1 << 4);
            try testArgs(i256, u5, 0);
            try testArgs(i256, u5, 1 << 0);
            try testArgs(i256, u5, 1 << 4);
            try testArgs(i512, u5, 0);
            try testArgs(i512, u5, 1 << 0);
            try testArgs(i512, u5, 1 << 4);
            try testArgs(i1024, u5, 0);
            try testArgs(i1024, u5, 1 << 0);
            try testArgs(i1024, u5, 1 << 4);

            try testArgs(u8, i7, -1 << 6);
            try testArgs(u8, i7, -1);
            try testArgs(u8, i7, 0);
            try testArgs(u16, i7, -1 << 6);
            try testArgs(u16, i7, -1);
            try testArgs(u16, i7, 0);
            try testArgs(u32, i7, -1 << 6);
            try testArgs(u32, i7, -1);
            try testArgs(u32, i7, 0);
            try testArgs(u64, i7, -1 << 6);
            try testArgs(u64, i7, -1);
            try testArgs(u64, i7, 0);
            try testArgs(u128, i7, -1 << 6);
            try testArgs(u128, i7, -1);
            try testArgs(u128, i7, 0);
            try testArgs(u256, i7, -1 << 6);
            try testArgs(u256, i7, -1);
            try testArgs(u256, i7, 0);
            try testArgs(u512, i7, -1 << 6);
            try testArgs(u512, i7, -1);
            try testArgs(u512, i7, 0);
            try testArgs(u1024, i7, -1 << 6);
            try testArgs(u1024, i7, -1);
            try testArgs(u1024, i7, 0);
            try testArgs(i8, u7, 0);
            try testArgs(i8, u7, 1 << 0);
            try testArgs(i8, u7, 1 << 6);
            try testArgs(i16, u7, 0);
            try testArgs(i16, u7, 1 << 0);
            try testArgs(i16, u7, 1 << 6);
            try testArgs(i32, u7, 0);
            try testArgs(i32, u7, 1 << 0);
            try testArgs(i32, u7, 1 << 6);
            try testArgs(i64, u7, 0);
            try testArgs(i64, u7, 1 << 0);
            try testArgs(i64, u7, 1 << 6);
            try testArgs(i128, u7, 0);
            try testArgs(i128, u7, 1 << 0);
            try testArgs(i128, u7, 1 << 6);
            try testArgs(i256, u7, 0);
            try testArgs(i256, u7, 1 << 0);
            try testArgs(i256, u7, 1 << 6);
            try testArgs(i512, u7, 0);
            try testArgs(i512, u7, 1 << 0);
            try testArgs(i512, u7, 1 << 6);
            try testArgs(i1024, u7, 0);
            try testArgs(i1024, u7, 1 << 0);
            try testArgs(i1024, u7, 1 << 6);

            try testArgs(u8, i8, -1 << 7);
            try testArgs(u8, i8, -1);
            try testArgs(u8, i8, 0);
            try testArgs(u16, i8, -1 << 7);
            try testArgs(u16, i8, -1);
            try testArgs(u16, i8, 0);
            try testArgs(u32, i8, -1 << 7);
            try testArgs(u32, i8, -1);
            try testArgs(u32, i8, 0);
            try testArgs(u64, i8, -1 << 7);
            try testArgs(u64, i8, -1);
            try testArgs(u64, i8, 0);
            try testArgs(u128, i8, -1 << 7);
            try testArgs(u128, i8, -1);
            try testArgs(u128, i8, 0);
            try testArgs(u256, i8, -1 << 7);
            try testArgs(u256, i8, -1);
            try testArgs(u256, i8, 0);
            try testArgs(u512, i8, -1 << 7);
            try testArgs(u512, i8, -1);
            try testArgs(u512, i8, 0);
            try testArgs(u1024, i8, -1 << 7);
            try testArgs(u1024, i8, -1);
            try testArgs(u1024, i8, 0);
            try testArgs(i8, u8, 0);
            try testArgs(i8, u8, 1 << 0);
            try testArgs(i8, u8, 1 << 7);
            try testArgs(i16, u8, 0);
            try testArgs(i16, u8, 1 << 0);
            try testArgs(i16, u8, 1 << 7);
            try testArgs(i32, u8, 0);
            try testArgs(i32, u8, 1 << 0);
            try testArgs(i32, u8, 1 << 7);
            try testArgs(i64, u8, 0);
            try testArgs(i64, u8, 1 << 0);
            try testArgs(i64, u8, 1 << 7);
            try testArgs(i128, u8, 0);
            try testArgs(i128, u8, 1 << 0);
            try testArgs(i128, u8, 1 << 7);
            try testArgs(i256, u8, 0);
            try testArgs(i256, u8, 1 << 0);
            try testArgs(i256, u8, 1 << 7);
            try testArgs(i512, u8, 0);
            try testArgs(i512, u8, 1 << 0);
            try testArgs(i512, u8, 1 << 7);
            try testArgs(i1024, u8, 0);
            try testArgs(i1024, u8, 1 << 0);
            try testArgs(i1024, u8, 1 << 7);

            try testArgs(u8, i9, -1 << 8);
            try testArgs(u8, i9, -1);
            try testArgs(u8, i9, 0);
            try testArgs(u16, i9, -1 << 8);
            try testArgs(u16, i9, -1);
            try testArgs(u16, i9, 0);
            try testArgs(u32, i9, -1 << 8);
            try testArgs(u32, i9, -1);
            try testArgs(u32, i9, 0);
            try testArgs(u64, i9, -1 << 8);
            try testArgs(u64, i9, -1);
            try testArgs(u64, i9, 0);
            try testArgs(u128, i9, -1 << 8);
            try testArgs(u128, i9, -1);
            try testArgs(u128, i9, 0);
            try testArgs(u256, i9, -1 << 8);
            try testArgs(u256, i9, -1);
            try testArgs(u256, i9, 0);
            try testArgs(u512, i9, -1 << 8);
            try testArgs(u512, i9, -1);
            try testArgs(u512, i9, 0);
            try testArgs(u1024, i9, -1 << 8);
            try testArgs(u1024, i9, -1);
            try testArgs(u1024, i9, 0);
            try testArgs(i8, u9, 0);
            try testArgs(i8, u9, 1 << 0);
            try testArgs(i8, u9, 1 << 8);
            try testArgs(i16, u9, 0);
            try testArgs(i16, u9, 1 << 0);
            try testArgs(i16, u9, 1 << 8);
            try testArgs(i32, u9, 0);
            try testArgs(i32, u9, 1 << 0);
            try testArgs(i32, u9, 1 << 8);
            try testArgs(i64, u9, 0);
            try testArgs(i64, u9, 1 << 0);
            try testArgs(i64, u9, 1 << 8);
            try testArgs(i128, u9, 0);
            try testArgs(i128, u9, 1 << 0);
            try testArgs(i128, u9, 1 << 8);
            try testArgs(i256, u9, 0);
            try testArgs(i256, u9, 1 << 0);
            try testArgs(i256, u9, 1 << 8);
            try testArgs(i512, u9, 0);
            try testArgs(i512, u9, 1 << 0);
            try testArgs(i512, u9, 1 << 8);
            try testArgs(i1024, u9, 0);
            try testArgs(i1024, u9, 1 << 0);
            try testArgs(i1024, u9, 1 << 8);

            try testArgs(u8, i15, -1 << 14);
            try testArgs(u8, i15, -1);
            try testArgs(u8, i15, 0);
            try testArgs(u16, i15, -1 << 14);
            try testArgs(u16, i15, -1);
            try testArgs(u16, i15, 0);
            try testArgs(u32, i15, -1 << 14);
            try testArgs(u32, i15, -1);
            try testArgs(u32, i15, 0);
            try testArgs(u64, i15, -1 << 14);
            try testArgs(u64, i15, -1);
            try testArgs(u64, i15, 0);
            try testArgs(u128, i15, -1 << 14);
            try testArgs(u128, i15, -1);
            try testArgs(u128, i15, 0);
            try testArgs(u256, i15, -1 << 14);
            try testArgs(u256, i15, -1);
            try testArgs(u256, i15, 0);
            try testArgs(u512, i15, -1 << 14);
            try testArgs(u512, i15, -1);
            try testArgs(u512, i15, 0);
            try testArgs(u1024, i15, -1 << 14);
            try testArgs(u1024, i15, -1);
            try testArgs(u1024, i15, 0);
            try testArgs(i8, u15, 0);
            try testArgs(i8, u15, 1 << 0);
            try testArgs(i8, u15, 1 << 14);
            try testArgs(i16, u15, 0);
            try testArgs(i16, u15, 1 << 0);
            try testArgs(i16, u15, 1 << 14);
            try testArgs(i32, u15, 0);
            try testArgs(i32, u15, 1 << 0);
            try testArgs(i32, u15, 1 << 14);
            try testArgs(i64, u15, 0);
            try testArgs(i64, u15, 1 << 0);
            try testArgs(i64, u15, 1 << 14);
            try testArgs(i128, u15, 0);
            try testArgs(i128, u15, 1 << 0);
            try testArgs(i128, u15, 1 << 14);
            try testArgs(i256, u15, 0);
            try testArgs(i256, u15, 1 << 0);
            try testArgs(i256, u15, 1 << 14);
            try testArgs(i512, u15, 0);
            try testArgs(i512, u15, 1 << 0);
            try testArgs(i512, u15, 1 << 14);
            try testArgs(i1024, u15, 0);
            try testArgs(i1024, u15, 1 << 0);
            try testArgs(i1024, u15, 1 << 14);

            try testArgs(u8, i16, -1 << 15);
            try testArgs(u8, i16, -1);
            try testArgs(u8, i16, 0);
            try testArgs(u16, i16, -1 << 15);
            try testArgs(u16, i16, -1);
            try testArgs(u16, i16, 0);
            try testArgs(u32, i16, -1 << 15);
            try testArgs(u32, i16, -1);
            try testArgs(u32, i16, 0);
            try testArgs(u64, i16, -1 << 15);
            try testArgs(u64, i16, -1);
            try testArgs(u64, i16, 0);
            try testArgs(u128, i16, -1 << 15);
            try testArgs(u128, i16, -1);
            try testArgs(u128, i16, 0);
            try testArgs(u256, i16, -1 << 15);
            try testArgs(u256, i16, -1);
            try testArgs(u256, i16, 0);
            try testArgs(u512, i16, -1 << 15);
            try testArgs(u512, i16, -1);
            try testArgs(u512, i16, 0);
            try testArgs(u1024, i16, -1 << 15);
            try testArgs(u1024, i16, -1);
            try testArgs(u1024, i16, 0);
            try testArgs(i8, u16, 0);
            try testArgs(i8, u16, 1 << 0);
            try testArgs(i8, u16, 1 << 15);
            try testArgs(i16, u16, 0);
            try testArgs(i16, u16, 1 << 0);
            try testArgs(i16, u16, 1 << 15);
            try testArgs(i32, u16, 0);
            try testArgs(i32, u16, 1 << 0);
            try testArgs(i32, u16, 1 << 15);
            try testArgs(i64, u16, 0);
            try testArgs(i64, u16, 1 << 0);
            try testArgs(i64, u16, 1 << 15);
            try testArgs(i128, u16, 0);
            try testArgs(i128, u16, 1 << 0);
            try testArgs(i128, u16, 1 << 15);
            try testArgs(i256, u16, 0);
            try testArgs(i256, u16, 1 << 0);
            try testArgs(i256, u16, 1 << 15);
            try testArgs(i512, u16, 0);
            try testArgs(i512, u16, 1 << 0);
            try testArgs(i512, u16, 1 << 15);
            try testArgs(i1024, u16, 0);
            try testArgs(i1024, u16, 1 << 0);
            try testArgs(i1024, u16, 1 << 15);

            try testArgs(u8, i17, -1 << 16);
            try testArgs(u8, i17, -1);
            try testArgs(u8, i17, 0);
            try testArgs(u16, i17, -1 << 16);
            try testArgs(u16, i17, -1);
            try testArgs(u16, i17, 0);
            try testArgs(u32, i17, -1 << 16);
            try testArgs(u32, i17, -1);
            try testArgs(u32, i17, 0);
            try testArgs(u64, i17, -1 << 16);
            try testArgs(u64, i17, -1);
            try testArgs(u64, i17, 0);
            try testArgs(u128, i17, -1 << 16);
            try testArgs(u128, i17, -1);
            try testArgs(u128, i17, 0);
            try testArgs(u256, i17, -1 << 16);
            try testArgs(u256, i17, -1);
            try testArgs(u256, i17, 0);
            try testArgs(u512, i17, -1 << 16);
            try testArgs(u512, i17, -1);
            try testArgs(u512, i17, 0);
            try testArgs(u1024, i17, -1 << 16);
            try testArgs(u1024, i17, -1);
            try testArgs(u1024, i17, 0);
            try testArgs(i8, u17, 0);
            try testArgs(i8, u17, 1 << 0);
            try testArgs(i8, u17, 1 << 16);
            try testArgs(i16, u17, 0);
            try testArgs(i16, u17, 1 << 0);
            try testArgs(i16, u17, 1 << 16);
            try testArgs(i32, u17, 0);
            try testArgs(i32, u17, 1 << 0);
            try testArgs(i32, u17, 1 << 16);
            try testArgs(i64, u17, 0);
            try testArgs(i64, u17, 1 << 0);
            try testArgs(i64, u17, 1 << 16);
            try testArgs(i128, u17, 0);
            try testArgs(i128, u17, 1 << 0);
            try testArgs(i128, u17, 1 << 16);
            try testArgs(i256, u17, 0);
            try testArgs(i256, u17, 1 << 0);
            try testArgs(i256, u17, 1 << 16);
            try testArgs(i512, u17, 0);
            try testArgs(i512, u17, 1 << 0);
            try testArgs(i512, u17, 1 << 16);
            try testArgs(i1024, u17, 0);
            try testArgs(i1024, u17, 1 << 0);
            try testArgs(i1024, u17, 1 << 16);

            try testArgs(u8, i31, -1 << 30);
            try testArgs(u8, i31, -1);
            try testArgs(u8, i31, 0);
            try testArgs(u16, i31, -1 << 30);
            try testArgs(u16, i31, -1);
            try testArgs(u16, i31, 0);
            try testArgs(u32, i31, -1 << 30);
            try testArgs(u32, i31, -1);
            try testArgs(u32, i31, 0);
            try testArgs(u64, i31, -1 << 30);
            try testArgs(u64, i31, -1);
            try testArgs(u64, i31, 0);
            try testArgs(u128, i31, -1 << 30);
            try testArgs(u128, i31, -1);
            try testArgs(u128, i31, 0);
            try testArgs(u256, i31, -1 << 30);
            try testArgs(u256, i31, -1);
            try testArgs(u256, i31, 0);
            try testArgs(u512, i31, -1 << 30);
            try testArgs(u512, i31, -1);
            try testArgs(u512, i31, 0);
            try testArgs(u1024, i31, -1 << 30);
            try testArgs(u1024, i31, -1);
            try testArgs(u1024, i31, 0);
            try testArgs(i8, u31, 0);
            try testArgs(i8, u31, 1 << 0);
            try testArgs(i8, u31, 1 << 30);
            try testArgs(i16, u31, 0);
            try testArgs(i16, u31, 1 << 0);
            try testArgs(i16, u31, 1 << 30);
            try testArgs(i32, u31, 0);
            try testArgs(i32, u31, 1 << 0);
            try testArgs(i32, u31, 1 << 30);
            try testArgs(i64, u31, 0);
            try testArgs(i64, u31, 1 << 0);
            try testArgs(i64, u31, 1 << 30);
            try testArgs(i128, u31, 0);
            try testArgs(i128, u31, 1 << 0);
            try testArgs(i128, u31, 1 << 30);
            try testArgs(i256, u31, 0);
            try testArgs(i256, u31, 1 << 0);
            try testArgs(i256, u31, 1 << 30);
            try testArgs(i512, u31, 0);
            try testArgs(i512, u31, 1 << 0);
            try testArgs(i512, u31, 1 << 30);
            try testArgs(i1024, u31, 0);
            try testArgs(i1024, u31, 1 << 0);
            try testArgs(i1024, u31, 1 << 30);

            try testArgs(u8, i32, -1 << 31);
            try testArgs(u8, i32, -1);
            try testArgs(u8, i32, 0);
            try testArgs(u16, i32, -1 << 31);
            try testArgs(u16, i32, -1);
            try testArgs(u16, i32, 0);
            try testArgs(u32, i32, -1 << 31);
            try testArgs(u32, i32, -1);
            try testArgs(u32, i32, 0);
            try testArgs(u64, i32, -1 << 31);
            try testArgs(u64, i32, -1);
            try testArgs(u64, i32, 0);
            try testArgs(u128, i32, -1 << 31);
            try testArgs(u128, i32, -1);
            try testArgs(u128, i32, 0);
            try testArgs(u256, i32, -1 << 31);
            try testArgs(u256, i32, -1);
            try testArgs(u256, i32, 0);
            try testArgs(u512, i32, -1 << 31);
            try testArgs(u512, i32, -1);
            try testArgs(u512, i32, 0);
            try testArgs(u1024, i32, -1 << 31);
            try testArgs(u1024, i32, -1);
            try testArgs(u1024, i32, 0);
            try testArgs(i8, u32, 0);
            try testArgs(i8, u32, 1 << 0);
            try testArgs(i8, u32, 1 << 31);
            try testArgs(i16, u32, 0);
            try testArgs(i16, u32, 1 << 0);
            try testArgs(i16, u32, 1 << 31);
            try testArgs(i32, u32, 0);
            try testArgs(i32, u32, 1 << 0);
            try testArgs(i32, u32, 1 << 31);
            try testArgs(i64, u32, 0);
            try testArgs(i64, u32, 1 << 0);
            try testArgs(i64, u32, 1 << 31);
            try testArgs(i128, u32, 0);
            try testArgs(i128, u32, 1 << 0);
            try testArgs(i128, u32, 1 << 31);
            try testArgs(i256, u32, 0);
            try testArgs(i256, u32, 1 << 0);
            try testArgs(i256, u32, 1 << 31);
            try testArgs(i512, u32, 0);
            try testArgs(i512, u32, 1 << 0);
            try testArgs(i512, u32, 1 << 31);
            try testArgs(i1024, u32, 0);
            try testArgs(i1024, u32, 1 << 0);
            try testArgs(i1024, u32, 1 << 31);

            try testArgs(u8, i33, -1 << 32);
            try testArgs(u8, i33, -1);
            try testArgs(u8, i33, 0);
            try testArgs(u16, i33, -1 << 32);
            try testArgs(u16, i33, -1);
            try testArgs(u16, i33, 0);
            try testArgs(u32, i33, -1 << 32);
            try testArgs(u32, i33, -1);
            try testArgs(u32, i33, 0);
            try testArgs(u64, i33, -1 << 32);
            try testArgs(u64, i33, -1);
            try testArgs(u64, i33, 0);
            try testArgs(u128, i33, -1 << 32);
            try testArgs(u128, i33, -1);
            try testArgs(u128, i33, 0);
            try testArgs(u256, i33, -1 << 32);
            try testArgs(u256, i33, -1);
            try testArgs(u256, i33, 0);
            try testArgs(u512, i33, -1 << 32);
            try testArgs(u512, i33, -1);
            try testArgs(u512, i33, 0);
            try testArgs(u1024, i33, -1 << 32);
            try testArgs(u1024, i33, -1);
            try testArgs(u1024, i33, 0);
            try testArgs(i8, u33, 0);
            try testArgs(i8, u33, 1 << 0);
            try testArgs(i8, u33, 1 << 32);
            try testArgs(i16, u33, 0);
            try testArgs(i16, u33, 1 << 0);
            try testArgs(i16, u33, 1 << 32);
            try testArgs(i32, u33, 0);
            try testArgs(i32, u33, 1 << 0);
            try testArgs(i32, u33, 1 << 32);
            try testArgs(i64, u33, 0);
            try testArgs(i64, u33, 1 << 0);
            try testArgs(i64, u33, 1 << 32);
            try testArgs(i128, u33, 0);
            try testArgs(i128, u33, 1 << 0);
            try testArgs(i128, u33, 1 << 32);
            try testArgs(i256, u33, 0);
            try testArgs(i256, u33, 1 << 0);
            try testArgs(i256, u33, 1 << 32);
            try testArgs(i512, u33, 0);
            try testArgs(i512, u33, 1 << 0);
            try testArgs(i512, u33, 1 << 32);
            try testArgs(i1024, u33, 0);
            try testArgs(i1024, u33, 1 << 0);
            try testArgs(i1024, u33, 1 << 32);

            try testArgs(u8, i63, -1 << 62);
            try testArgs(u8, i63, -1);
            try testArgs(u8, i63, 0);
            try testArgs(u16, i63, -1 << 62);
            try testArgs(u16, i63, -1);
            try testArgs(u16, i63, 0);
            try testArgs(u32, i63, -1 << 62);
            try testArgs(u32, i63, -1);
            try testArgs(u32, i63, 0);
            try testArgs(u64, i63, -1 << 62);
            try testArgs(u64, i63, -1);
            try testArgs(u64, i63, 0);
            try testArgs(u128, i63, -1 << 62);
            try testArgs(u128, i63, -1);
            try testArgs(u128, i63, 0);
            try testArgs(u256, i63, -1 << 62);
            try testArgs(u256, i63, -1);
            try testArgs(u256, i63, 0);
            try testArgs(u512, i63, -1 << 62);
            try testArgs(u512, i63, -1);
            try testArgs(u512, i63, 0);
            try testArgs(u1024, i63, -1 << 62);
            try testArgs(u1024, i63, -1);
            try testArgs(u1024, i63, 0);
            try testArgs(i8, u63, 0);
            try testArgs(i8, u63, 1 << 0);
            try testArgs(i8, u63, 1 << 62);
            try testArgs(i16, u63, 0);
            try testArgs(i16, u63, 1 << 0);
            try testArgs(i16, u63, 1 << 62);
            try testArgs(i32, u63, 0);
            try testArgs(i32, u63, 1 << 0);
            try testArgs(i32, u63, 1 << 62);
            try testArgs(i64, u63, 0);
            try testArgs(i64, u63, 1 << 0);
            try testArgs(i64, u63, 1 << 62);
            try testArgs(i128, u63, 0);
            try testArgs(i128, u63, 1 << 0);
            try testArgs(i128, u63, 1 << 62);
            try testArgs(i256, u63, 0);
            try testArgs(i256, u63, 1 << 0);
            try testArgs(i256, u63, 1 << 62);
            try testArgs(i512, u63, 0);
            try testArgs(i512, u63, 1 << 0);
            try testArgs(i512, u63, 1 << 62);
            try testArgs(i1024, u63, 0);
            try testArgs(i1024, u63, 1 << 0);
            try testArgs(i1024, u63, 1 << 62);

            try testArgs(u8, i64, -1 << 63);
            try testArgs(u8, i64, -1);
            try testArgs(u8, i64, 0);
            try testArgs(u16, i64, -1 << 63);
            try testArgs(u16, i64, -1);
            try testArgs(u16, i64, 0);
            try testArgs(u32, i64, -1 << 63);
            try testArgs(u32, i64, -1);
            try testArgs(u32, i64, 0);
            try testArgs(u64, i64, -1 << 63);
            try testArgs(u64, i64, -1);
            try testArgs(u64, i64, 0);
            try testArgs(u128, i64, -1 << 63);
            try testArgs(u128, i64, -1);
            try testArgs(u128, i64, 0);
            try testArgs(u256, i64, -1 << 63);
            try testArgs(u256, i64, -1);
            try testArgs(u256, i64, 0);
            try testArgs(u512, i64, -1 << 63);
            try testArgs(u512, i64, -1);
            try testArgs(u512, i64, 0);
            try testArgs(u1024, i64, -1 << 63);
            try testArgs(u1024, i64, -1);
            try testArgs(u1024, i64, 0);
            try testArgs(i8, u64, 0);
            try testArgs(i8, u64, 1 << 0);
            try testArgs(i8, u64, 1 << 63);
            try testArgs(i16, u64, 0);
            try testArgs(i16, u64, 1 << 0);
            try testArgs(i16, u64, 1 << 63);
            try testArgs(i32, u64, 0);
            try testArgs(i32, u64, 1 << 0);
            try testArgs(i32, u64, 1 << 63);
            try testArgs(i64, u64, 0);
            try testArgs(i64, u64, 1 << 0);
            try testArgs(i64, u64, 1 << 63);
            try testArgs(i128, u64, 0);
            try testArgs(i128, u64, 1 << 0);
            try testArgs(i128, u64, 1 << 63);
            try testArgs(i256, u64, 0);
            try testArgs(i256, u64, 1 << 0);
            try testArgs(i256, u64, 1 << 63);
            try testArgs(i512, u64, 0);
            try testArgs(i512, u64, 1 << 0);
            try testArgs(i512, u64, 1 << 63);
            try testArgs(i1024, u64, 0);
            try testArgs(i1024, u64, 1 << 0);
            try testArgs(i1024, u64, 1 << 63);

            try testArgs(u8, i65, -1 << 64);
            try testArgs(u8, i65, -1);
            try testArgs(u8, i65, 0);
            try testArgs(u16, i65, -1 << 64);
            try testArgs(u16, i65, -1);
            try testArgs(u16, i65, 0);
            try testArgs(u32, i65, -1 << 64);
            try testArgs(u32, i65, -1);
            try testArgs(u32, i65, 0);
            try testArgs(u64, i65, -1 << 64);
            try testArgs(u64, i65, -1);
            try testArgs(u64, i65, 0);
            try testArgs(u128, i65, -1 << 64);
            try testArgs(u128, i65, -1);
            try testArgs(u128, i65, 0);
            try testArgs(u256, i65, -1 << 64);
            try testArgs(u256, i65, -1);
            try testArgs(u256, i65, 0);
            try testArgs(u512, i65, -1 << 64);
            try testArgs(u512, i65, -1);
            try testArgs(u512, i65, 0);
            try testArgs(u1024, i65, -1 << 64);
            try testArgs(u1024, i65, -1);
            try testArgs(u1024, i65, 0);
            try testArgs(i8, u65, 0);
            try testArgs(i8, u65, 1 << 0);
            try testArgs(i8, u65, 1 << 64);
            try testArgs(i16, u65, 0);
            try testArgs(i16, u65, 1 << 0);
            try testArgs(i16, u65, 1 << 64);
            try testArgs(i32, u65, 0);
            try testArgs(i32, u65, 1 << 0);
            try testArgs(i32, u65, 1 << 64);
            try testArgs(i64, u65, 0);
            try testArgs(i64, u65, 1 << 0);
            try testArgs(i64, u65, 1 << 64);
            try testArgs(i128, u65, 0);
            try testArgs(i128, u65, 1 << 0);
            try testArgs(i128, u65, 1 << 64);
            try testArgs(i256, u65, 0);
            try testArgs(i256, u65, 1 << 0);
            try testArgs(i256, u65, 1 << 64);
            try testArgs(i512, u65, 0);
            try testArgs(i512, u65, 1 << 0);
            try testArgs(i512, u65, 1 << 64);
            try testArgs(i1024, u65, 0);
            try testArgs(i1024, u65, 1 << 0);
            try testArgs(i1024, u65, 1 << 64);

            try testArgs(u8, i95, -1 << 94);
            try testArgs(u8, i95, -1);
            try testArgs(u8, i95, 0);
            try testArgs(u16, i95, -1 << 94);
            try testArgs(u16, i95, -1);
            try testArgs(u16, i95, 0);
            try testArgs(u32, i95, -1 << 94);
            try testArgs(u32, i95, -1);
            try testArgs(u32, i95, 0);
            try testArgs(u64, i95, -1 << 94);
            try testArgs(u64, i95, -1);
            try testArgs(u64, i95, 0);
            try testArgs(u128, i95, -1 << 94);
            try testArgs(u128, i95, -1);
            try testArgs(u128, i95, 0);
            try testArgs(u256, i95, -1 << 94);
            try testArgs(u256, i95, -1);
            try testArgs(u256, i95, 0);
            try testArgs(u512, i95, -1 << 94);
            try testArgs(u512, i95, -1);
            try testArgs(u512, i95, 0);
            try testArgs(u1024, i95, -1 << 94);
            try testArgs(u1024, i95, -1);
            try testArgs(u1024, i95, 0);
            try testArgs(i8, u95, 0);
            try testArgs(i8, u95, 1 << 0);
            try testArgs(i8, u95, 1 << 94);
            try testArgs(i16, u95, 0);
            try testArgs(i16, u95, 1 << 0);
            try testArgs(i16, u95, 1 << 94);
            try testArgs(i32, u95, 0);
            try testArgs(i32, u95, 1 << 0);
            try testArgs(i32, u95, 1 << 94);
            try testArgs(i64, u95, 0);
            try testArgs(i64, u95, 1 << 0);
            try testArgs(i64, u95, 1 << 94);
            try testArgs(i128, u95, 0);
            try testArgs(i128, u95, 1 << 0);
            try testArgs(i128, u95, 1 << 94);
            try testArgs(i256, u95, 0);
            try testArgs(i256, u95, 1 << 0);
            try testArgs(i256, u95, 1 << 94);
            try testArgs(i512, u95, 0);
            try testArgs(i512, u95, 1 << 0);
            try testArgs(i512, u95, 1 << 94);
            try testArgs(i1024, u95, 0);
            try testArgs(i1024, u95, 1 << 0);
            try testArgs(i1024, u95, 1 << 94);

            try testArgs(u8, i96, -1 << 95);
            try testArgs(u8, i96, -1);
            try testArgs(u8, i96, 0);
            try testArgs(u16, i96, -1 << 95);
            try testArgs(u16, i96, -1);
            try testArgs(u16, i96, 0);
            try testArgs(u32, i96, -1 << 95);
            try testArgs(u32, i96, -1);
            try testArgs(u32, i96, 0);
            try testArgs(u64, i96, -1 << 95);
            try testArgs(u64, i96, -1);
            try testArgs(u64, i96, 0);
            try testArgs(u128, i96, -1 << 95);
            try testArgs(u128, i96, -1);
            try testArgs(u128, i96, 0);
            try testArgs(u256, i96, -1 << 95);
            try testArgs(u256, i96, -1);
            try testArgs(u256, i96, 0);
            try testArgs(u512, i96, -1 << 95);
            try testArgs(u512, i96, -1);
            try testArgs(u512, i96, 0);
            try testArgs(u1024, i96, -1 << 95);
            try testArgs(u1024, i96, -1);
            try testArgs(u1024, i96, 0);
            try testArgs(i8, u96, 0);
            try testArgs(i8, u96, 1 << 0);
            try testArgs(i8, u96, 1 << 95);
            try testArgs(i16, u96, 0);
            try testArgs(i16, u96, 1 << 0);
            try testArgs(i16, u96, 1 << 95);
            try testArgs(i32, u96, 0);
            try testArgs(i32, u96, 1 << 0);
            try testArgs(i32, u96, 1 << 95);
            try testArgs(i64, u96, 0);
            try testArgs(i64, u96, 1 << 0);
            try testArgs(i64, u96, 1 << 95);
            try testArgs(i128, u96, 0);
            try testArgs(i128, u96, 1 << 0);
            try testArgs(i128, u96, 1 << 95);
            try testArgs(i256, u96, 0);
            try testArgs(i256, u96, 1 << 0);
            try testArgs(i256, u96, 1 << 95);
            try testArgs(i512, u96, 0);
            try testArgs(i512, u96, 1 << 0);
            try testArgs(i512, u96, 1 << 95);
            try testArgs(i1024, u96, 0);
            try testArgs(i1024, u96, 1 << 0);
            try testArgs(i1024, u96, 1 << 95);

            try testArgs(u8, i97, -1 << 96);
            try testArgs(u8, i97, -1);
            try testArgs(u8, i97, 0);
            try testArgs(u16, i97, -1 << 96);
            try testArgs(u16, i97, -1);
            try testArgs(u16, i97, 0);
            try testArgs(u32, i97, -1 << 96);
            try testArgs(u32, i97, -1);
            try testArgs(u32, i97, 0);
            try testArgs(u64, i97, -1 << 96);
            try testArgs(u64, i97, -1);
            try testArgs(u64, i97, 0);
            try testArgs(u128, i97, -1 << 96);
            try testArgs(u128, i97, -1);
            try testArgs(u128, i97, 0);
            try testArgs(u256, i97, -1 << 96);
            try testArgs(u256, i97, -1);
            try testArgs(u256, i97, 0);
            try testArgs(u512, i97, -1 << 96);
            try testArgs(u512, i97, -1);
            try testArgs(u512, i97, 0);
            try testArgs(u1024, i97, -1 << 96);
            try testArgs(u1024, i97, -1);
            try testArgs(u1024, i97, 0);
            try testArgs(i8, u97, 0);
            try testArgs(i8, u97, 1 << 0);
            try testArgs(i8, u97, 1 << 96);
            try testArgs(i16, u97, 0);
            try testArgs(i16, u97, 1 << 0);
            try testArgs(i16, u97, 1 << 96);
            try testArgs(i32, u97, 0);
            try testArgs(i32, u97, 1 << 0);
            try testArgs(i32, u97, 1 << 96);
            try testArgs(i64, u97, 0);
            try testArgs(i64, u97, 1 << 0);
            try testArgs(i64, u97, 1 << 96);
            try testArgs(i128, u97, 0);
            try testArgs(i128, u97, 1 << 0);
            try testArgs(i128, u97, 1 << 96);
            try testArgs(i256, u97, 0);
            try testArgs(i256, u97, 1 << 0);
            try testArgs(i256, u97, 1 << 96);
            try testArgs(i512, u97, 0);
            try testArgs(i512, u97, 1 << 0);
            try testArgs(i512, u97, 1 << 96);
            try testArgs(i1024, u97, 0);
            try testArgs(i1024, u97, 1 << 0);
            try testArgs(i1024, u97, 1 << 96);

            try testArgs(u8, i127, -1 << 126);
            try testArgs(u8, i127, -1);
            try testArgs(u8, i127, 0);
            try testArgs(u16, i127, -1 << 126);
            try testArgs(u16, i127, -1);
            try testArgs(u16, i127, 0);
            try testArgs(u32, i127, -1 << 126);
            try testArgs(u32, i127, -1);
            try testArgs(u32, i127, 0);
            try testArgs(u64, i127, -1 << 126);
            try testArgs(u64, i127, -1);
            try testArgs(u64, i127, 0);
            try testArgs(u128, i127, -1 << 126);
            try testArgs(u128, i127, -1);
            try testArgs(u128, i127, 0);
            try testArgs(u256, i127, -1 << 126);
            try testArgs(u256, i127, -1);
            try testArgs(u256, i127, 0);
            try testArgs(u512, i127, -1 << 126);
            try testArgs(u512, i127, -1);
            try testArgs(u512, i127, 0);
            try testArgs(u1024, i127, -1 << 126);
            try testArgs(u1024, i127, -1);
            try testArgs(u1024, i127, 0);
            try testArgs(i8, u127, 0);
            try testArgs(i8, u127, 1 << 0);
            try testArgs(i8, u127, 1 << 126);
            try testArgs(i16, u127, 0);
            try testArgs(i16, u127, 1 << 0);
            try testArgs(i16, u127, 1 << 126);
            try testArgs(i32, u127, 0);
            try testArgs(i32, u127, 1 << 0);
            try testArgs(i32, u127, 1 << 126);
            try testArgs(i64, u127, 0);
            try testArgs(i64, u127, 1 << 0);
            try testArgs(i64, u127, 1 << 126);
            try testArgs(i128, u127, 0);
            try testArgs(i128, u127, 1 << 0);
            try testArgs(i128, u127, 1 << 126);
            try testArgs(i256, u127, 0);
            try testArgs(i256, u127, 1 << 0);
            try testArgs(i256, u127, 1 << 126);
            try testArgs(i512, u127, 0);
            try testArgs(i512, u127, 1 << 0);
            try testArgs(i512, u127, 1 << 126);
            try testArgs(i1024, u127, 0);
            try testArgs(i1024, u127, 1 << 0);
            try testArgs(i1024, u127, 1 << 126);

            try testArgs(u8, i128, -1 << 127);
            try testArgs(u8, i128, -1);
            try testArgs(u8, i128, 0);
            try testArgs(u16, i128, -1 << 127);
            try testArgs(u16, i128, -1);
            try testArgs(u16, i128, 0);
            try testArgs(u32, i128, -1 << 127);
            try testArgs(u32, i128, -1);
            try testArgs(u32, i128, 0);
            try testArgs(u64, i128, -1 << 127);
            try testArgs(u64, i128, -1);
            try testArgs(u64, i128, 0);
            try testArgs(u128, i128, -1 << 127);
            try testArgs(u128, i128, -1);
            try testArgs(u128, i128, 0);
            try testArgs(u256, i128, -1 << 127);
            try testArgs(u256, i128, -1);
            try testArgs(u256, i128, 0);
            try testArgs(u512, i128, -1 << 127);
            try testArgs(u512, i128, -1);
            try testArgs(u512, i128, 0);
            try testArgs(u1024, i128, -1 << 127);
            try testArgs(u1024, i128, -1);
            try testArgs(u1024, i128, 0);
            try testArgs(i8, u128, 0);
            try testArgs(i8, u128, 1 << 0);
            try testArgs(i8, u128, 1 << 127);
            try testArgs(i16, u128, 0);
            try testArgs(i16, u128, 1 << 0);
            try testArgs(i16, u128, 1 << 127);
            try testArgs(i32, u128, 0);
            try testArgs(i32, u128, 1 << 0);
            try testArgs(i32, u128, 1 << 127);
            try testArgs(i64, u128, 0);
            try testArgs(i64, u128, 1 << 0);
            try testArgs(i64, u128, 1 << 127);
            try testArgs(i128, u128, 0);
            try testArgs(i128, u128, 1 << 0);
            try testArgs(i128, u128, 1 << 127);
            try testArgs(i256, u128, 0);
            try testArgs(i256, u128, 1 << 0);
            try testArgs(i256, u128, 1 << 127);
            try testArgs(i512, u128, 0);
            try testArgs(i512, u128, 1 << 0);
            try testArgs(i512, u128, 1 << 127);
            try testArgs(i1024, u128, 0);
            try testArgs(i1024, u128, 1 << 0);
            try testArgs(i1024, u128, 1 << 127);

            try testArgs(u8, i129, -1 << 128);
            try testArgs(u8, i129, -1);
            try testArgs(u8, i129, 0);
            try testArgs(u16, i129, -1 << 128);
            try testArgs(u16, i129, -1);
            try testArgs(u16, i129, 0);
            try testArgs(u32, i129, -1 << 128);
            try testArgs(u32, i129, -1);
            try testArgs(u32, i129, 0);
            try testArgs(u64, i129, -1 << 128);
            try testArgs(u64, i129, -1);
            try testArgs(u64, i129, 0);
            try testArgs(u128, i129, -1 << 128);
            try testArgs(u128, i129, -1);
            try testArgs(u128, i129, 0);
            try testArgs(u256, i129, -1 << 128);
            try testArgs(u256, i129, -1);
            try testArgs(u256, i129, 0);
            try testArgs(u512, i129, -1 << 128);
            try testArgs(u512, i129, -1);
            try testArgs(u512, i129, 0);
            try testArgs(u1024, i129, -1 << 128);
            try testArgs(u1024, i129, -1);
            try testArgs(u1024, i129, 0);
            try testArgs(i8, u129, 0);
            try testArgs(i8, u129, 1 << 0);
            try testArgs(i8, u129, 1 << 128);
            try testArgs(i16, u129, 0);
            try testArgs(i16, u129, 1 << 0);
            try testArgs(i16, u129, 1 << 128);
            try testArgs(i32, u129, 0);
            try testArgs(i32, u129, 1 << 0);
            try testArgs(i32, u129, 1 << 128);
            try testArgs(i64, u129, 0);
            try testArgs(i64, u129, 1 << 0);
            try testArgs(i64, u129, 1 << 128);
            try testArgs(i128, u129, 0);
            try testArgs(i128, u129, 1 << 0);
            try testArgs(i128, u129, 1 << 128);
            try testArgs(i256, u129, 0);
            try testArgs(i256, u129, 1 << 0);
            try testArgs(i256, u129, 1 << 128);
            try testArgs(i512, u129, 0);
            try testArgs(i512, u129, 1 << 0);
            try testArgs(i512, u129, 1 << 128);
            try testArgs(i1024, u129, 0);
            try testArgs(i1024, u129, 1 << 0);
            try testArgs(i1024, u129, 1 << 128);

            try testArgs(u8, i255, -1 << 254);
            try testArgs(u8, i255, -1);
            try testArgs(u8, i255, 0);
            try testArgs(u16, i255, -1 << 254);
            try testArgs(u16, i255, -1);
            try testArgs(u16, i255, 0);
            try testArgs(u32, i255, -1 << 254);
            try testArgs(u32, i255, -1);
            try testArgs(u32, i255, 0);
            try testArgs(u64, i255, -1 << 254);
            try testArgs(u64, i255, -1);
            try testArgs(u64, i255, 0);
            try testArgs(u128, i255, -1 << 254);
            try testArgs(u128, i255, -1);
            try testArgs(u128, i255, 0);
            try testArgs(u256, i255, -1 << 254);
            try testArgs(u256, i255, -1);
            try testArgs(u256, i255, 0);
            try testArgs(u512, i255, -1 << 254);
            try testArgs(u512, i255, -1);
            try testArgs(u512, i255, 0);
            try testArgs(u1024, i255, -1 << 254);
            try testArgs(u1024, i255, -1);
            try testArgs(u1024, i255, 0);
            try testArgs(i8, u255, 0);
            try testArgs(i8, u255, 1 << 0);
            try testArgs(i8, u255, 1 << 254);
            try testArgs(i16, u255, 0);
            try testArgs(i16, u255, 1 << 0);
            try testArgs(i16, u255, 1 << 254);
            try testArgs(i32, u255, 0);
            try testArgs(i32, u255, 1 << 0);
            try testArgs(i32, u255, 1 << 254);
            try testArgs(i64, u255, 0);
            try testArgs(i64, u255, 1 << 0);
            try testArgs(i64, u255, 1 << 254);
            try testArgs(i128, u255, 0);
            try testArgs(i128, u255, 1 << 0);
            try testArgs(i128, u255, 1 << 254);
            try testArgs(i256, u255, 0);
            try testArgs(i256, u255, 1 << 0);
            try testArgs(i256, u255, 1 << 254);
            try testArgs(i512, u255, 0);
            try testArgs(i512, u255, 1 << 0);
            try testArgs(i512, u255, 1 << 254);
            try testArgs(i1024, u255, 0);
            try testArgs(i1024, u255, 1 << 0);
            try testArgs(i1024, u255, 1 << 254);

            try testArgs(u8, i256, -1 << 255);
            try testArgs(u8, i256, -1);
            try testArgs(u8, i256, 0);
            try testArgs(u16, i256, -1 << 255);
            try testArgs(u16, i256, -1);
            try testArgs(u16, i256, 0);
            try testArgs(u32, i256, -1 << 255);
            try testArgs(u32, i256, -1);
            try testArgs(u32, i256, 0);
            try testArgs(u64, i256, -1 << 255);
            try testArgs(u64, i256, -1);
            try testArgs(u64, i256, 0);
            try testArgs(u128, i256, -1 << 255);
            try testArgs(u128, i256, -1);
            try testArgs(u128, i256, 0);
            try testArgs(u256, i256, -1 << 255);
            try testArgs(u256, i256, -1);
            try testArgs(u256, i256, 0);
            try testArgs(u512, i256, -1 << 255);
            try testArgs(u512, i256, -1);
            try testArgs(u512, i256, 0);
            try testArgs(u1024, i256, -1 << 255);
            try testArgs(u1024, i256, -1);
            try testArgs(u1024, i256, 0);
            try testArgs(i8, u256, 0);
            try testArgs(i8, u256, 1 << 0);
            try testArgs(i8, u256, 1 << 255);
            try testArgs(i16, u256, 0);
            try testArgs(i16, u256, 1 << 0);
            try testArgs(i16, u256, 1 << 255);
            try testArgs(i32, u256, 0);
            try testArgs(i32, u256, 1 << 0);
            try testArgs(i32, u256, 1 << 255);
            try testArgs(i64, u256, 0);
            try testArgs(i64, u256, 1 << 0);
            try testArgs(i64, u256, 1 << 255);
            try testArgs(i128, u256, 0);
            try testArgs(i128, u256, 1 << 0);
            try testArgs(i128, u256, 1 << 255);
            try testArgs(i256, u256, 0);
            try testArgs(i256, u256, 1 << 0);
            try testArgs(i256, u256, 1 << 255);
            try testArgs(i512, u256, 0);
            try testArgs(i512, u256, 1 << 0);
            try testArgs(i512, u256, 1 << 255);
            try testArgs(i1024, u256, 0);
            try testArgs(i1024, u256, 1 << 0);
            try testArgs(i1024, u256, 1 << 255);

            try testArgs(u8, i257, -1 << 256);
            try testArgs(u8, i257, -1);
            try testArgs(u8, i257, 0);
            try testArgs(u16, i257, -1 << 256);
            try testArgs(u16, i257, -1);
            try testArgs(u16, i257, 0);
            try testArgs(u32, i257, -1 << 256);
            try testArgs(u32, i257, -1);
            try testArgs(u32, i257, 0);
            try testArgs(u64, i257, -1 << 256);
            try testArgs(u64, i257, -1);
            try testArgs(u64, i257, 0);
            try testArgs(u128, i257, -1 << 256);
            try testArgs(u128, i257, -1);
            try testArgs(u128, i257, 0);
            try testArgs(u256, i257, -1 << 256);
            try testArgs(u256, i257, -1);
            try testArgs(u256, i257, 0);
            try testArgs(u512, i257, -1 << 256);
            try testArgs(u512, i257, -1);
            try testArgs(u512, i257, 0);
            try testArgs(u1024, i257, -1 << 256);
            try testArgs(u1024, i257, -1);
            try testArgs(u1024, i257, 0);
            try testArgs(i8, u257, 0);
            try testArgs(i8, u257, 1 << 0);
            try testArgs(i8, u257, 1 << 256);
            try testArgs(i16, u257, 0);
            try testArgs(i16, u257, 1 << 0);
            try testArgs(i16, u257, 1 << 256);
            try testArgs(i32, u257, 0);
            try testArgs(i32, u257, 1 << 0);
            try testArgs(i32, u257, 1 << 256);
            try testArgs(i64, u257, 0);
            try testArgs(i64, u257, 1 << 0);
            try testArgs(i64, u257, 1 << 256);
            try testArgs(i128, u257, 0);
            try testArgs(i128, u257, 1 << 0);
            try testArgs(i128, u257, 1 << 256);
            try testArgs(i256, u257, 0);
            try testArgs(i256, u257, 1 << 0);
            try testArgs(i256, u257, 1 << 256);
            try testArgs(i512, u257, 0);
            try testArgs(i512, u257, 1 << 0);
            try testArgs(i512, u257, 1 << 256);
            try testArgs(i1024, u257, 0);
            try testArgs(i1024, u257, 1 << 0);
            try testArgs(i1024, u257, 1 << 256);

            try testArgs(u8, i511, -1 << 510);
            try testArgs(u8, i511, -1);
            try testArgs(u8, i511, 0);
            try testArgs(u16, i511, -1 << 510);
            try testArgs(u16, i511, -1);
            try testArgs(u16, i511, 0);
            try testArgs(u32, i511, -1 << 510);
            try testArgs(u32, i511, -1);
            try testArgs(u32, i511, 0);
            try testArgs(u64, i511, -1 << 510);
            try testArgs(u64, i511, -1);
            try testArgs(u64, i511, 0);
            try testArgs(u128, i511, -1 << 510);
            try testArgs(u128, i511, -1);
            try testArgs(u128, i511, 0);
            try testArgs(u256, i511, -1 << 510);
            try testArgs(u256, i511, -1);
            try testArgs(u256, i511, 0);
            try testArgs(u512, i511, -1 << 510);
            try testArgs(u512, i511, -1);
            try testArgs(u512, i511, 0);
            try testArgs(u1024, i511, -1 << 510);
            try testArgs(u1024, i511, -1);
            try testArgs(u1024, i511, 0);
            try testArgs(i8, u511, 0);
            try testArgs(i8, u511, 1 << 0);
            try testArgs(i8, u511, 1 << 510);
            try testArgs(i16, u511, 0);
            try testArgs(i16, u511, 1 << 0);
            try testArgs(i16, u511, 1 << 510);
            try testArgs(i32, u511, 0);
            try testArgs(i32, u511, 1 << 0);
            try testArgs(i32, u511, 1 << 510);
            try testArgs(i64, u511, 0);
            try testArgs(i64, u511, 1 << 0);
            try testArgs(i64, u511, 1 << 510);
            try testArgs(i128, u511, 0);
            try testArgs(i128, u511, 1 << 0);
            try testArgs(i128, u511, 1 << 510);
            try testArgs(i256, u511, 0);
            try testArgs(i256, u511, 1 << 0);
            try testArgs(i256, u511, 1 << 510);
            try testArgs(i512, u511, 0);
            try testArgs(i512, u511, 1 << 0);
            try testArgs(i512, u511, 1 << 510);
            try testArgs(i1024, u511, 0);
            try testArgs(i1024, u511, 1 << 0);
            try testArgs(i1024, u511, 1 << 510);

            try testArgs(u8, i512, -1 << 511);
            try testArgs(u8, i512, -1);
            try testArgs(u8, i512, 0);
            try testArgs(u16, i512, -1 << 511);
            try testArgs(u16, i512, -1);
            try testArgs(u16, i512, 0);
            try testArgs(u32, i512, -1 << 511);
            try testArgs(u32, i512, -1);
            try testArgs(u32, i512, 0);
            try testArgs(u64, i512, -1 << 511);
            try testArgs(u64, i512, -1);
            try testArgs(u64, i512, 0);
            try testArgs(u128, i512, -1 << 511);
            try testArgs(u128, i512, -1);
            try testArgs(u128, i512, 0);
            try testArgs(u256, i512, -1 << 511);
            try testArgs(u256, i512, -1);
            try testArgs(u256, i512, 0);
            try testArgs(u512, i512, -1 << 511);
            try testArgs(u512, i512, -1);
            try testArgs(u512, i512, 0);
            try testArgs(u1024, i512, -1 << 511);
            try testArgs(u1024, i512, -1);
            try testArgs(u1024, i512, 0);
            try testArgs(i8, u512, 0);
            try testArgs(i8, u512, 1 << 0);
            try testArgs(i8, u512, 1 << 511);
            try testArgs(i16, u512, 0);
            try testArgs(i16, u512, 1 << 0);
            try testArgs(i16, u512, 1 << 511);
            try testArgs(i32, u512, 0);
            try testArgs(i32, u512, 1 << 0);
            try testArgs(i32, u512, 1 << 511);
            try testArgs(i64, u512, 0);
            try testArgs(i64, u512, 1 << 0);
            try testArgs(i64, u512, 1 << 511);
            try testArgs(i128, u512, 0);
            try testArgs(i128, u512, 1 << 0);
            try testArgs(i128, u512, 1 << 511);
            try testArgs(i256, u512, 0);
            try testArgs(i256, u512, 1 << 0);
            try testArgs(i256, u512, 1 << 511);
            try testArgs(i512, u512, 0);
            try testArgs(i512, u512, 1 << 0);
            try testArgs(i512, u512, 1 << 511);
            try testArgs(i1024, u512, 0);
            try testArgs(i1024, u512, 1 << 0);
            try testArgs(i1024, u512, 1 << 511);

            try testArgs(u8, i513, -1 << 512);
            try testArgs(u8, i513, -1);
            try testArgs(u8, i513, 0);
            try testArgs(u16, i513, -1 << 512);
            try testArgs(u16, i513, -1);
            try testArgs(u16, i513, 0);
            try testArgs(u32, i513, -1 << 512);
            try testArgs(u32, i513, -1);
            try testArgs(u32, i513, 0);
            try testArgs(u64, i513, -1 << 512);
            try testArgs(u64, i513, -1);
            try testArgs(u64, i513, 0);
            try testArgs(u128, i513, -1 << 512);
            try testArgs(u128, i513, -1);
            try testArgs(u128, i513, 0);
            try testArgs(u256, i513, -1 << 512);
            try testArgs(u256, i513, -1);
            try testArgs(u256, i513, 0);
            try testArgs(u512, i513, -1 << 512);
            try testArgs(u512, i513, -1);
            try testArgs(u512, i513, 0);
            try testArgs(u1024, i513, -1 << 512);
            try testArgs(u1024, i513, -1);
            try testArgs(u1024, i513, 0);
            try testArgs(i8, u513, 0);
            try testArgs(i8, u513, 1 << 0);
            try testArgs(i8, u513, 1 << 512);
            try testArgs(i16, u513, 0);
            try testArgs(i16, u513, 1 << 0);
            try testArgs(i16, u513, 1 << 512);
            try testArgs(i32, u513, 0);
            try testArgs(i32, u513, 1 << 0);
            try testArgs(i32, u513, 1 << 512);
            try testArgs(i64, u513, 0);
            try testArgs(i64, u513, 1 << 0);
            try testArgs(i64, u513, 1 << 512);
            try testArgs(i128, u513, 0);
            try testArgs(i128, u513, 1 << 0);
            try testArgs(i128, u513, 1 << 512);
            try testArgs(i256, u513, 0);
            try testArgs(i256, u513, 1 << 0);
            try testArgs(i256, u513, 1 << 512);
            try testArgs(i512, u513, 0);
            try testArgs(i512, u513, 1 << 0);
            try testArgs(i512, u513, 1 << 512);
            try testArgs(i1024, u513, 0);
            try testArgs(i1024, u513, 1 << 0);
            try testArgs(i1024, u513, 1 << 512);

            try testArgs(u8, i1023, -1 << 1022);
            try testArgs(u8, i1023, -1);
            try testArgs(u8, i1023, 0);
            try testArgs(u16, i1023, -1 << 1022);
            try testArgs(u16, i1023, -1);
            try testArgs(u16, i1023, 0);
            try testArgs(u32, i1023, -1 << 1022);
            try testArgs(u32, i1023, -1);
            try testArgs(u32, i1023, 0);
            try testArgs(u64, i1023, -1 << 1022);
            try testArgs(u64, i1023, -1);
            try testArgs(u64, i1023, 0);
            try testArgs(u128, i1023, -1 << 1022);
            try testArgs(u128, i1023, -1);
            try testArgs(u128, i1023, 0);
            try testArgs(u256, i1023, -1 << 1022);
            try testArgs(u256, i1023, -1);
            try testArgs(u256, i1023, 0);
            try testArgs(u512, i1023, -1 << 1022);
            try testArgs(u512, i1023, -1);
            try testArgs(u512, i1023, 0);
            try testArgs(u1024, i1023, -1 << 1022);
            try testArgs(u1024, i1023, -1);
            try testArgs(u1024, i1023, 0);
            try testArgs(i8, u1023, 0);
            try testArgs(i8, u1023, 1 << 0);
            try testArgs(i8, u1023, 1 << 1022);
            try testArgs(i16, u1023, 0);
            try testArgs(i16, u1023, 1 << 0);
            try testArgs(i16, u1023, 1 << 1022);
            try testArgs(i32, u1023, 0);
            try testArgs(i32, u1023, 1 << 0);
            try testArgs(i32, u1023, 1 << 1022);
            try testArgs(i64, u1023, 0);
            try testArgs(i64, u1023, 1 << 0);
            try testArgs(i64, u1023, 1 << 1022);
            try testArgs(i128, u1023, 0);
            try testArgs(i128, u1023, 1 << 0);
            try testArgs(i128, u1023, 1 << 1022);
            try testArgs(i256, u1023, 0);
            try testArgs(i256, u1023, 1 << 0);
            try testArgs(i256, u1023, 1 << 1022);
            try testArgs(i512, u1023, 0);
            try testArgs(i512, u1023, 1 << 0);
            try testArgs(i512, u1023, 1 << 1022);
            try testArgs(i1024, u1023, 0);
            try testArgs(i1024, u1023, 1 << 0);
            try testArgs(i1024, u1023, 1 << 1022);

            try testArgs(u8, i1024, -1 << 1023);
            try testArgs(u8, i1024, -1);
            try testArgs(u8, i1024, 0);
            try testArgs(u16, i1024, -1 << 1023);
            try testArgs(u16, i1024, -1);
            try testArgs(u16, i1024, 0);
            try testArgs(u32, i1024, -1 << 1023);
            try testArgs(u32, i1024, -1);
            try testArgs(u32, i1024, 0);
            try testArgs(u64, i1024, -1 << 1023);
            try testArgs(u64, i1024, -1);
            try testArgs(u64, i1024, 0);
            try testArgs(u128, i1024, -1 << 1023);
            try testArgs(u128, i1024, -1);
            try testArgs(u128, i1024, 0);
            try testArgs(u256, i1024, -1 << 1023);
            try testArgs(u256, i1024, -1);
            try testArgs(u256, i1024, 0);
            try testArgs(u512, i1024, -1 << 1023);
            try testArgs(u512, i1024, -1);
            try testArgs(u512, i1024, 0);
            try testArgs(u1024, i1024, -1 << 1023);
            try testArgs(u1024, i1024, -1);
            try testArgs(u1024, i1024, 0);
            try testArgs(i8, u1024, 0);
            try testArgs(i8, u1024, 1 << 0);
            try testArgs(i8, u1024, 1 << 1023);
            try testArgs(i16, u1024, 0);
            try testArgs(i16, u1024, 1 << 0);
            try testArgs(i16, u1024, 1 << 1023);
            try testArgs(i32, u1024, 0);
            try testArgs(i32, u1024, 1 << 0);
            try testArgs(i32, u1024, 1 << 1023);
            try testArgs(i64, u1024, 0);
            try testArgs(i64, u1024, 1 << 0);
            try testArgs(i64, u1024, 1 << 1023);
            try testArgs(i128, u1024, 0);
            try testArgs(i128, u1024, 1 << 0);
            try testArgs(i128, u1024, 1 << 1023);
            try testArgs(i256, u1024, 0);
            try testArgs(i256, u1024, 1 << 0);
            try testArgs(i256, u1024, 1 << 1023);
            try testArgs(i512, u1024, 0);
            try testArgs(i512, u1024, 1 << 0);
            try testArgs(i512, u1024, 1 << 1023);
            try testArgs(i1024, u1024, 0);
            try testArgs(i1024, u1024, 1 << 0);
            try testArgs(i1024, u1024, 1 << 1023);

            try testArgs(u8, i1025, -1 << 1024);
            try testArgs(u8, i1025, -1);
            try testArgs(u8, i1025, 0);
            try testArgs(u16, i1025, -1 << 1024);
            try testArgs(u16, i1025, -1);
            try testArgs(u16, i1025, 0);
            try testArgs(u32, i1025, -1 << 1024);
            try testArgs(u32, i1025, -1);
            try testArgs(u32, i1025, 0);
            try testArgs(u64, i1025, -1 << 1024);
            try testArgs(u64, i1025, -1);
            try testArgs(u64, i1025, 0);
            try testArgs(u128, i1025, -1 << 1024);
            try testArgs(u128, i1025, -1);
            try testArgs(u128, i1025, 0);
            try testArgs(u256, i1025, -1 << 1024);
            try testArgs(u256, i1025, -1);
            try testArgs(u256, i1025, 0);
            try testArgs(u512, i1025, -1 << 1024);
            try testArgs(u512, i1025, -1);
            try testArgs(u512, i1025, 0);
            try testArgs(u1024, i1025, -1 << 1024);
            try testArgs(u1024, i1025, -1);
            try testArgs(u1024, i1025, 0);
            try testArgs(i8, u1025, 0);
            try testArgs(i8, u1025, 1 << 0);
            try testArgs(i8, u1025, 1 << 1024);
            try testArgs(i16, u1025, 0);
            try testArgs(i16, u1025, 1 << 0);
            try testArgs(i16, u1025, 1 << 1024);
            try testArgs(i32, u1025, 0);
            try testArgs(i32, u1025, 1 << 0);
            try testArgs(i32, u1025, 1 << 1024);
            try testArgs(i64, u1025, 0);
            try testArgs(i64, u1025, 1 << 0);
            try testArgs(i64, u1025, 1 << 1024);
            try testArgs(i128, u1025, 0);
            try testArgs(i128, u1025, 1 << 0);
            try testArgs(i128, u1025, 1 << 1024);
            try testArgs(i256, u1025, 0);
            try testArgs(i256, u1025, 1 << 0);
            try testArgs(i256, u1025, 1 << 1024);
            try testArgs(i512, u1025, 0);
            try testArgs(i512, u1025, 1 << 0);
            try testArgs(i512, u1025, 1 << 1024);
            try testArgs(i1024, u1025, 0);
            try testArgs(i1024, u1025, 1 << 0);
            try testArgs(i1024, u1025, 1 << 1024);
        }
        fn testFloats() !void {
            @setEvalBranchQuota(3_100);

            try testArgs(f16, f16, -nan(f16));
            try testArgs(f16, f16, -inf(f16));
            try testArgs(f16, f16, -fmax(f16));
            try testArgs(f16, f16, -1e1);
            try testArgs(f16, f16, -1e0);
            try testArgs(f16, f16, -1e-1);
            try testArgs(f16, f16, -fmin(f16));
            try testArgs(f16, f16, -tmin(f16));
            try testArgs(f16, f16, -0.0);
            try testArgs(f16, f16, 0.0);
            try testArgs(f16, f16, tmin(f16));
            try testArgs(f16, f16, fmin(f16));
            try testArgs(f16, f16, 1e-1);
            try testArgs(f16, f16, 1e0);
            try testArgs(f16, f16, 1e1);
            try testArgs(f16, f16, fmax(f16));
            try testArgs(f16, f16, inf(f16));
            try testArgs(f16, f16, nan(f16));

            try testArgs(f32, f16, -nan(f16));
            try testArgs(f32, f16, -inf(f16));
            try testArgs(f32, f16, -fmax(f16));
            try testArgs(f32, f16, -1e1);
            try testArgs(f32, f16, -1e0);
            try testArgs(f32, f16, -1e-1);
            try testArgs(f32, f16, -fmin(f16));
            try testArgs(f32, f16, -tmin(f16));
            try testArgs(f32, f16, -0.0);
            try testArgs(f32, f16, 0.0);
            try testArgs(f32, f16, tmin(f16));
            try testArgs(f32, f16, fmin(f16));
            try testArgs(f32, f16, 1e-1);
            try testArgs(f32, f16, 1e0);
            try testArgs(f32, f16, 1e1);
            try testArgs(f32, f16, fmax(f16));
            try testArgs(f32, f16, inf(f16));
            try testArgs(f32, f16, nan(f16));

            try testArgs(f64, f16, -nan(f16));
            try testArgs(f64, f16, -inf(f16));
            try testArgs(f64, f16, -fmax(f16));
            try testArgs(f64, f16, -1e1);
            try testArgs(f64, f16, -1e0);
            try testArgs(f64, f16, -1e-1);
            try testArgs(f64, f16, -fmin(f16));
            try testArgs(f64, f16, -tmin(f16));
            try testArgs(f64, f16, -0.0);
            try testArgs(f64, f16, 0.0);
            try testArgs(f64, f16, tmin(f16));
            try testArgs(f64, f16, fmin(f16));
            try testArgs(f64, f16, 1e-1);
            try testArgs(f64, f16, 1e0);
            try testArgs(f64, f16, 1e1);
            try testArgs(f64, f16, fmax(f16));
            try testArgs(f64, f16, inf(f16));
            try testArgs(f64, f16, nan(f16));

            try testArgs(f80, f16, -nan(f16));
            try testArgs(f80, f16, -inf(f16));
            try testArgs(f80, f16, -fmax(f16));
            try testArgs(f80, f16, -1e1);
            try testArgs(f80, f16, -1e0);
            try testArgs(f80, f16, -1e-1);
            try testArgs(f80, f16, -fmin(f16));
            try testArgs(f80, f16, -tmin(f16));
            try testArgs(f80, f16, -0.0);
            try testArgs(f80, f16, 0.0);
            try testArgs(f80, f16, tmin(f16));
            try testArgs(f80, f16, fmin(f16));
            try testArgs(f80, f16, 1e-1);
            try testArgs(f80, f16, 1e0);
            try testArgs(f80, f16, 1e1);
            try testArgs(f80, f16, fmax(f16));
            try testArgs(f80, f16, inf(f16));
            try testArgs(f80, f16, nan(f16));

            try testArgs(f128, f16, -nan(f16));
            try testArgs(f128, f16, -inf(f16));
            try testArgs(f128, f16, -fmax(f16));
            try testArgs(f128, f16, -1e1);
            try testArgs(f128, f16, -1e0);
            try testArgs(f128, f16, -1e-1);
            try testArgs(f128, f16, -fmin(f16));
            try testArgs(f128, f16, -tmin(f16));
            try testArgs(f128, f16, -0.0);
            try testArgs(f128, f16, 0.0);
            try testArgs(f128, f16, tmin(f16));
            try testArgs(f128, f16, fmin(f16));
            try testArgs(f128, f16, 1e-1);
            try testArgs(f128, f16, 1e0);
            try testArgs(f128, f16, 1e1);
            try testArgs(f128, f16, fmax(f16));
            try testArgs(f128, f16, inf(f16));
            try testArgs(f128, f16, nan(f16));

            try testArgs(f16, f32, -nan(f32));
            try testArgs(f16, f32, -inf(f32));
            try testArgs(f16, f32, -fmax(f32));
            try testArgs(f16, f32, -1e1);
            try testArgs(f16, f32, -1e0);
            try testArgs(f16, f32, -1e-1);
            try testArgs(f16, f32, -fmin(f32));
            try testArgs(f16, f32, -tmin(f32));
            try testArgs(f16, f32, -0.0);
            try testArgs(f16, f32, 0.0);
            try testArgs(f16, f32, tmin(f32));
            try testArgs(f16, f32, fmin(f32));
            try testArgs(f16, f32, 1e-1);
            try testArgs(f16, f32, 1e0);
            try testArgs(f16, f32, 1e1);
            try testArgs(f16, f32, fmax(f32));
            try testArgs(f16, f32, inf(f32));
            try testArgs(f16, f32, nan(f32));

            try testArgs(f32, f32, -nan(f32));
            try testArgs(f32, f32, -inf(f32));
            try testArgs(f32, f32, -fmax(f32));
            try testArgs(f32, f32, -1e1);
            try testArgs(f32, f32, -1e0);
            try testArgs(f32, f32, -1e-1);
            try testArgs(f32, f32, -fmin(f32));
            try testArgs(f32, f32, -tmin(f32));
            try testArgs(f32, f32, -0.0);
            try testArgs(f32, f32, 0.0);
            try testArgs(f32, f32, tmin(f32));
            try testArgs(f32, f32, fmin(f32));
            try testArgs(f32, f32, 1e-1);
            try testArgs(f32, f32, 1e0);
            try testArgs(f32, f32, 1e1);
            try testArgs(f32, f32, fmax(f32));
            try testArgs(f32, f32, inf(f32));
            try testArgs(f32, f32, nan(f32));

            try testArgs(f64, f32, -nan(f32));
            try testArgs(f64, f32, -inf(f32));
            try testArgs(f64, f32, -fmax(f32));
            try testArgs(f64, f32, -1e1);
            try testArgs(f64, f32, -1e0);
            try testArgs(f64, f32, -1e-1);
            try testArgs(f64, f32, -fmin(f32));
            try testArgs(f64, f32, -tmin(f32));
            try testArgs(f64, f32, -0.0);
            try testArgs(f64, f32, 0.0);
            try testArgs(f64, f32, tmin(f32));
            try testArgs(f64, f32, fmin(f32));
            try testArgs(f64, f32, 1e-1);
            try testArgs(f64, f32, 1e0);
            try testArgs(f64, f32, 1e1);
            try testArgs(f64, f32, fmax(f32));
            try testArgs(f64, f32, inf(f32));
            try testArgs(f64, f32, nan(f32));

            try testArgs(f80, f32, -nan(f32));
            try testArgs(f80, f32, -inf(f32));
            try testArgs(f80, f32, -fmax(f32));
            try testArgs(f80, f32, -1e1);
            try testArgs(f80, f32, -1e0);
            try testArgs(f80, f32, -1e-1);
            try testArgs(f80, f32, -fmin(f32));
            try testArgs(f80, f32, -tmin(f32));
            try testArgs(f80, f32, -0.0);
            try testArgs(f80, f32, 0.0);
            try testArgs(f80, f32, tmin(f32));
            try testArgs(f80, f32, fmin(f32));
            try testArgs(f80, f32, 1e-1);
            try testArgs(f80, f32, 1e0);
            try testArgs(f80, f32, 1e1);
            try testArgs(f80, f32, fmax(f32));
            try testArgs(f80, f32, inf(f32));
            try testArgs(f80, f32, nan(f32));

            try testArgs(f128, f32, -nan(f32));
            try testArgs(f128, f32, -inf(f32));
            try testArgs(f128, f32, -fmax(f32));
            try testArgs(f128, f32, -1e1);
            try testArgs(f128, f32, -1e0);
            try testArgs(f128, f32, -1e-1);
            try testArgs(f128, f32, -fmin(f32));
            try testArgs(f128, f32, -tmin(f32));
            try testArgs(f128, f32, -0.0);
            try testArgs(f128, f32, 0.0);
            try testArgs(f128, f32, tmin(f32));
            try testArgs(f128, f32, fmin(f32));
            try testArgs(f128, f32, 1e-1);
            try testArgs(f128, f32, 1e0);
            try testArgs(f128, f32, 1e1);
            try testArgs(f128, f32, fmax(f32));
            try testArgs(f128, f32, inf(f32));
            try testArgs(f128, f32, nan(f32));

            try testArgs(f16, f64, -nan(f64));
            try testArgs(f16, f64, -inf(f64));
            try testArgs(f16, f64, -fmax(f64));
            try testArgs(f16, f64, -1e1);
            try testArgs(f16, f64, -1e0);
            try testArgs(f16, f64, -1e-1);
            try testArgs(f16, f64, -fmin(f64));
            try testArgs(f16, f64, -tmin(f64));
            try testArgs(f16, f64, -0.0);
            try testArgs(f16, f64, 0.0);
            try testArgs(f16, f64, tmin(f64));
            try testArgs(f16, f64, fmin(f64));
            try testArgs(f16, f64, 1e-1);
            try testArgs(f16, f64, 1e0);
            try testArgs(f16, f64, 1e1);
            try testArgs(f16, f64, fmax(f64));
            try testArgs(f16, f64, inf(f64));
            try testArgs(f16, f64, nan(f64));

            try testArgs(f32, f64, -nan(f64));
            try testArgs(f32, f64, -inf(f64));
            try testArgs(f32, f64, -fmax(f64));
            try testArgs(f32, f64, -1e1);
            try testArgs(f32, f64, -1e0);
            try testArgs(f32, f64, -1e-1);
            try testArgs(f32, f64, -fmin(f64));
            try testArgs(f32, f64, -tmin(f64));
            try testArgs(f32, f64, -0.0);
            try testArgs(f32, f64, 0.0);
            try testArgs(f32, f64, tmin(f64));
            try testArgs(f32, f64, fmin(f64));
            try testArgs(f32, f64, 1e-1);
            try testArgs(f32, f64, 1e0);
            try testArgs(f32, f64, 1e1);
            try testArgs(f32, f64, fmax(f64));
            try testArgs(f32, f64, inf(f64));
            try testArgs(f32, f64, nan(f64));

            try testArgs(f64, f64, -nan(f64));
            try testArgs(f64, f64, -inf(f64));
            try testArgs(f64, f64, -fmax(f64));
            try testArgs(f64, f64, -1e1);
            try testArgs(f64, f64, -1e0);
            try testArgs(f64, f64, -1e-1);
            try testArgs(f64, f64, -fmin(f64));
            try testArgs(f64, f64, -tmin(f64));
            try testArgs(f64, f64, -0.0);
            try testArgs(f64, f64, 0.0);
            try testArgs(f64, f64, tmin(f64));
            try testArgs(f64, f64, fmin(f64));
            try testArgs(f64, f64, 1e-1);
            try testArgs(f64, f64, 1e0);
            try testArgs(f64, f64, 1e1);
            try testArgs(f64, f64, fmax(f64));
            try testArgs(f64, f64, inf(f64));
            try testArgs(f64, f64, nan(f64));

            try testArgs(f80, f64, -nan(f64));
            try testArgs(f80, f64, -inf(f64));
            try testArgs(f80, f64, -fmax(f64));
            try testArgs(f80, f64, -1e1);
            try testArgs(f80, f64, -1e0);
            try testArgs(f80, f64, -1e-1);
            try testArgs(f80, f64, -fmin(f64));
            try testArgs(f80, f64, -tmin(f64));
            try testArgs(f80, f64, -0.0);
            try testArgs(f80, f64, 0.0);
            try testArgs(f80, f64, tmin(f64));
            try testArgs(f80, f64, fmin(f64));
            try testArgs(f80, f64, 1e-1);
            try testArgs(f80, f64, 1e0);
            try testArgs(f80, f64, 1e1);
            try testArgs(f80, f64, fmax(f64));
            try testArgs(f80, f64, inf(f64));
            try testArgs(f80, f64, nan(f64));

            try testArgs(f128, f64, -nan(f64));
            try testArgs(f128, f64, -inf(f64));
            try testArgs(f128, f64, -fmax(f64));
            try testArgs(f128, f64, -1e1);
            try testArgs(f128, f64, -1e0);
            try testArgs(f128, f64, -1e-1);
            try testArgs(f128, f64, -fmin(f64));
            try testArgs(f128, f64, -tmin(f64));
            try testArgs(f128, f64, -0.0);
            try testArgs(f128, f64, 0.0);
            try testArgs(f128, f64, tmin(f64));
            try testArgs(f128, f64, fmin(f64));
            try testArgs(f128, f64, 1e-1);
            try testArgs(f128, f64, 1e0);
            try testArgs(f128, f64, 1e1);
            try testArgs(f128, f64, fmax(f64));
            try testArgs(f128, f64, inf(f64));
            try testArgs(f128, f64, nan(f64));

            try testArgs(f16, f80, -nan(f80));
            try testArgs(f16, f80, -inf(f80));
            try testArgs(f16, f80, -fmax(f80));
            try testArgs(f16, f80, -1e1);
            try testArgs(f16, f80, -1e0);
            try testArgs(f16, f80, -1e-1);
            try testArgs(f16, f80, -fmin(f80));
            try testArgs(f16, f80, -tmin(f80));
            try testArgs(f16, f80, -0.0);
            try testArgs(f16, f80, 0.0);
            try testArgs(f16, f80, tmin(f80));
            try testArgs(f16, f80, fmin(f80));
            try testArgs(f16, f80, 1e-1);
            try testArgs(f16, f80, 1e0);
            try testArgs(f16, f80, 1e1);
            try testArgs(f16, f80, fmax(f80));
            try testArgs(f16, f80, inf(f80));
            try testArgs(f16, f80, nan(f80));

            try testArgs(f32, f80, -nan(f80));
            try testArgs(f32, f80, -inf(f80));
            try testArgs(f32, f80, -fmax(f80));
            try testArgs(f32, f80, -1e1);
            try testArgs(f32, f80, -1e0);
            try testArgs(f32, f80, -1e-1);
            try testArgs(f32, f80, -fmin(f80));
            try testArgs(f32, f80, -tmin(f80));
            try testArgs(f32, f80, -0.0);
            try testArgs(f32, f80, 0.0);
            try testArgs(f32, f80, tmin(f80));
            try testArgs(f32, f80, fmin(f80));
            try testArgs(f32, f80, 1e-1);
            try testArgs(f32, f80, 1e0);
            try testArgs(f32, f80, 1e1);
            try testArgs(f32, f80, fmax(f80));
            try testArgs(f32, f80, inf(f80));
            try testArgs(f32, f80, nan(f80));

            try testArgs(f64, f80, -nan(f80));
            try testArgs(f64, f80, -inf(f80));
            try testArgs(f64, f80, -fmax(f80));
            try testArgs(f64, f80, -1e1);
            try testArgs(f64, f80, -1e0);
            try testArgs(f64, f80, -1e-1);
            try testArgs(f64, f80, -fmin(f80));
            try testArgs(f64, f80, -tmin(f80));
            try testArgs(f64, f80, -0.0);
            try testArgs(f64, f80, 0.0);
            try testArgs(f64, f80, tmin(f80));
            try testArgs(f64, f80, fmin(f80));
            try testArgs(f64, f80, 1e-1);
            try testArgs(f64, f80, 1e0);
            try testArgs(f64, f80, 1e1);
            try testArgs(f64, f80, fmax(f80));
            try testArgs(f64, f80, inf(f80));
            try testArgs(f64, f80, nan(f80));

            try testArgs(f80, f80, -nan(f80));
            try testArgs(f80, f80, -inf(f80));
            try testArgs(f80, f80, -fmax(f80));
            try testArgs(f80, f80, -1e1);
            try testArgs(f80, f80, -1e0);
            try testArgs(f80, f80, -1e-1);
            try testArgs(f80, f80, -fmin(f80));
            try testArgs(f80, f80, -tmin(f80));
            try testArgs(f80, f80, -0.0);
            try testArgs(f80, f80, 0.0);
            try testArgs(f80, f80, tmin(f80));
            try testArgs(f80, f80, fmin(f80));
            try testArgs(f80, f80, 1e-1);
            try testArgs(f80, f80, 1e0);
            try testArgs(f80, f80, 1e1);
            try testArgs(f80, f80, fmax(f80));
            try testArgs(f80, f80, inf(f80));
            try testArgs(f80, f80, nan(f80));

            try testArgs(f128, f80, -nan(f80));
            try testArgs(f128, f80, -inf(f80));
            try testArgs(f128, f80, -fmax(f80));
            try testArgs(f128, f80, -1e1);
            try testArgs(f128, f80, -1e0);
            try testArgs(f128, f80, -1e-1);
            try testArgs(f128, f80, -fmin(f80));
            try testArgs(f128, f80, -tmin(f80));
            try testArgs(f128, f80, -0.0);
            try testArgs(f128, f80, 0.0);
            try testArgs(f128, f80, tmin(f80));
            try testArgs(f128, f80, fmin(f80));
            try testArgs(f128, f80, 1e-1);
            try testArgs(f128, f80, 1e0);
            try testArgs(f128, f80, 1e1);
            try testArgs(f128, f80, fmax(f80));
            try testArgs(f128, f80, inf(f80));
            try testArgs(f128, f80, nan(f80));

            try testArgs(f16, f128, -nan(f128));
            try testArgs(f16, f128, -inf(f128));
            try testArgs(f16, f128, -fmax(f128));
            try testArgs(f16, f128, -1e1);
            try testArgs(f16, f128, -1e0);
            try testArgs(f16, f128, -1e-1);
            try testArgs(f16, f128, -fmin(f128));
            try testArgs(f16, f128, -tmin(f128));
            try testArgs(f16, f128, -0.0);
            try testArgs(f16, f128, 0.0);
            try testArgs(f16, f128, tmin(f128));
            try testArgs(f16, f128, fmin(f128));
            try testArgs(f16, f128, 1e-1);
            try testArgs(f16, f128, 1e0);
            try testArgs(f16, f128, 1e1);
            try testArgs(f16, f128, fmax(f128));
            try testArgs(f16, f128, inf(f128));
            try testArgs(f16, f128, nan(f128));

            try testArgs(f32, f128, -nan(f128));
            try testArgs(f32, f128, -inf(f128));
            try testArgs(f32, f128, -fmax(f128));
            try testArgs(f32, f128, -1e1);
            try testArgs(f32, f128, -1e0);
            try testArgs(f32, f128, -1e-1);
            try testArgs(f32, f128, -fmin(f128));
            try testArgs(f32, f128, -tmin(f128));
            try testArgs(f32, f128, -0.0);
            try testArgs(f32, f128, 0.0);
            try testArgs(f32, f128, tmin(f128));
            try testArgs(f32, f128, fmin(f128));
            try testArgs(f32, f128, 1e-1);
            try testArgs(f32, f128, 1e0);
            try testArgs(f32, f128, 1e1);
            try testArgs(f32, f128, fmax(f128));
            try testArgs(f32, f128, inf(f128));
            try testArgs(f32, f128, nan(f128));

            try testArgs(f64, f128, -nan(f128));
            try testArgs(f64, f128, -inf(f128));
            try testArgs(f64, f128, -fmax(f128));
            try testArgs(f64, f128, -1e1);
            try testArgs(f64, f128, -1e0);
            try testArgs(f64, f128, -1e-1);
            try testArgs(f64, f128, -fmin(f128));
            try testArgs(f64, f128, -tmin(f128));
            try testArgs(f64, f128, -0.0);
            try testArgs(f64, f128, 0.0);
            try testArgs(f64, f128, tmin(f128));
            try testArgs(f64, f128, fmin(f128));
            try testArgs(f64, f128, 1e-1);
            try testArgs(f64, f128, 1e0);
            try testArgs(f64, f128, 1e1);
            try testArgs(f64, f128, fmax(f128));
            try testArgs(f64, f128, inf(f128));
            try testArgs(f64, f128, nan(f128));

            try testArgs(f80, f128, -nan(f128));
            try testArgs(f80, f128, -inf(f128));
            try testArgs(f80, f128, -fmax(f128));
            try testArgs(f80, f128, -1e1);
            try testArgs(f80, f128, -1e0);
            try testArgs(f80, f128, -1e-1);
            try testArgs(f80, f128, -fmin(f128));
            try testArgs(f80, f128, -tmin(f128));
            try testArgs(f80, f128, -0.0);
            try testArgs(f80, f128, 0.0);
            try testArgs(f80, f128, tmin(f128));
            try testArgs(f80, f128, fmin(f128));
            try testArgs(f80, f128, 1e-1);
            try testArgs(f80, f128, 1e0);
            try testArgs(f80, f128, 1e1);
            try testArgs(f80, f128, fmax(f128));
            try testArgs(f80, f128, inf(f128));
            try testArgs(f80, f128, nan(f128));

            try testArgs(f128, f128, -nan(f128));
            try testArgs(f128, f128, -inf(f128));
            try testArgs(f128, f128, -fmax(f128));
            try testArgs(f128, f128, -1e1);
            try testArgs(f128, f128, -1e0);
            try testArgs(f128, f128, -1e-1);
            try testArgs(f128, f128, -fmin(f128));
            try testArgs(f128, f128, -tmin(f128));
            try testArgs(f128, f128, -0.0);
            try testArgs(f128, f128, 0.0);
            try testArgs(f128, f128, tmin(f128));
            try testArgs(f128, f128, fmin(f128));
            try testArgs(f128, f128, 1e-1);
            try testArgs(f128, f128, 1e0);
            try testArgs(f128, f128, 1e1);
            try testArgs(f128, f128, fmax(f128));
            try testArgs(f128, f128, inf(f128));
            try testArgs(f128, f128, nan(f128));
        }
        fn testSameSignednessIntVectors() !void {
            try testArgs(@Vector(1, i7), @Vector(1, i1), .{-1});
            try testArgs(@Vector(1, i8), @Vector(1, i1), .{-1});
            try testArgs(@Vector(1, i9), @Vector(1, i1), .{-1});
            try testArgs(@Vector(1, i15), @Vector(1, i1), .{-1});
            try testArgs(@Vector(1, i16), @Vector(1, i1), .{-1});
            try testArgs(@Vector(1, i17), @Vector(1, i1), .{-1});
            try testArgs(@Vector(1, i31), @Vector(1, i1), .{-1});
            try testArgs(@Vector(1, i32), @Vector(1, i1), .{-1});
            try testArgs(@Vector(1, i33), @Vector(1, i1), .{-1});
            try testArgs(@Vector(1, i63), @Vector(1, i1), .{-1});
            try testArgs(@Vector(1, i64), @Vector(1, i1), .{-1});
            try testArgs(@Vector(1, i65), @Vector(1, i1), .{-1});
            try testArgs(@Vector(1, i127), @Vector(1, i1), .{-1});
            try testArgs(@Vector(1, i128), @Vector(1, i1), .{-1});
            try testArgs(@Vector(1, i129), @Vector(1, i1), .{-1});
            try testArgs(@Vector(1, i255), @Vector(1, i1), .{-1});
            try testArgs(@Vector(1, i256), @Vector(1, i1), .{-1});
            try testArgs(@Vector(1, i257), @Vector(1, i1), .{-1});
            try testArgs(@Vector(1, i511), @Vector(1, i1), .{-1});
            try testArgs(@Vector(1, i512), @Vector(1, i1), .{-1});
            try testArgs(@Vector(1, i513), @Vector(1, i1), .{-1});
            try testArgs(@Vector(1, i1023), @Vector(1, i1), .{-1});
            try testArgs(@Vector(1, i1024), @Vector(1, i1), .{-1});
            try testArgs(@Vector(1, i1025), @Vector(1, i1), .{-1});
            try testArgs(@Vector(1, u7), @Vector(1, u1), .{1});
            try testArgs(@Vector(1, u8), @Vector(1, u1), .{1});
            try testArgs(@Vector(1, u9), @Vector(1, u1), .{1});
            try testArgs(@Vector(1, u15), @Vector(1, u1), .{1});
            try testArgs(@Vector(1, u16), @Vector(1, u1), .{1});
            try testArgs(@Vector(1, u17), @Vector(1, u1), .{1});
            try testArgs(@Vector(1, u31), @Vector(1, u1), .{1});
            try testArgs(@Vector(1, u32), @Vector(1, u1), .{1});
            try testArgs(@Vector(1, u33), @Vector(1, u1), .{1});
            try testArgs(@Vector(1, u63), @Vector(1, u1), .{1});
            try testArgs(@Vector(1, u64), @Vector(1, u1), .{1});
            try testArgs(@Vector(1, u65), @Vector(1, u1), .{1});
            try testArgs(@Vector(1, u127), @Vector(1, u1), .{1});
            try testArgs(@Vector(1, u128), @Vector(1, u1), .{1});
            try testArgs(@Vector(1, u129), @Vector(1, u1), .{1});
            try testArgs(@Vector(1, u255), @Vector(1, u1), .{1});
            try testArgs(@Vector(1, u256), @Vector(1, u1), .{1});
            try testArgs(@Vector(1, u257), @Vector(1, u1), .{1});
            try testArgs(@Vector(1, u511), @Vector(1, u1), .{1});
            try testArgs(@Vector(1, u512), @Vector(1, u1), .{1});
            try testArgs(@Vector(1, u513), @Vector(1, u1), .{1});
            try testArgs(@Vector(1, u1023), @Vector(1, u1), .{1});
            try testArgs(@Vector(1, u1024), @Vector(1, u1), .{1});
            try testArgs(@Vector(1, u1025), @Vector(1, u1), .{1});

            try testArgs(@Vector(2, i7), @Vector(2, i1), .{ -1, 0 });
            try testArgs(@Vector(2, i8), @Vector(2, i1), .{ -1, 0 });
            try testArgs(@Vector(2, i9), @Vector(2, i1), .{ -1, 0 });
            try testArgs(@Vector(2, i15), @Vector(2, i1), .{ -1, 0 });
            try testArgs(@Vector(2, i16), @Vector(2, i1), .{ -1, 0 });
            try testArgs(@Vector(2, i17), @Vector(2, i1), .{ -1, 0 });
            try testArgs(@Vector(2, i31), @Vector(2, i1), .{ -1, 0 });
            try testArgs(@Vector(2, i32), @Vector(2, i1), .{ -1, 0 });
            try testArgs(@Vector(2, i33), @Vector(2, i1), .{ -1, 0 });
            try testArgs(@Vector(2, i63), @Vector(2, i1), .{ -1, 0 });
            try testArgs(@Vector(2, i64), @Vector(2, i1), .{ -1, 0 });
            try testArgs(@Vector(2, i65), @Vector(2, i1), .{ -1, 0 });
            try testArgs(@Vector(2, i127), @Vector(2, i1), .{ -1, 0 });
            try testArgs(@Vector(2, i128), @Vector(2, i1), .{ -1, 0 });
            try testArgs(@Vector(2, i129), @Vector(2, i1), .{ -1, 0 });
            try testArgs(@Vector(2, i255), @Vector(2, i1), .{ -1, 0 });
            try testArgs(@Vector(2, i256), @Vector(2, i1), .{ -1, 0 });
            try testArgs(@Vector(2, i257), @Vector(2, i1), .{ -1, 0 });
            try testArgs(@Vector(2, i511), @Vector(2, i1), .{ -1, 0 });
            try testArgs(@Vector(2, i512), @Vector(2, i1), .{ -1, 0 });
            try testArgs(@Vector(2, i513), @Vector(2, i1), .{ -1, 0 });
            try testArgs(@Vector(2, i1023), @Vector(2, i1), .{ -1, 0 });
            try testArgs(@Vector(2, i1024), @Vector(2, i1), .{ -1, 0 });
            try testArgs(@Vector(2, i1025), @Vector(2, i1), .{ -1, 0 });
            try testArgs(@Vector(2, u7), @Vector(2, u1), .{ 0, 1 });
            try testArgs(@Vector(2, u8), @Vector(2, u1), .{ 0, 1 });
            try testArgs(@Vector(2, u9), @Vector(2, u1), .{ 0, 1 });
            try testArgs(@Vector(2, u15), @Vector(2, u1), .{ 0, 1 });
            try testArgs(@Vector(2, u16), @Vector(2, u1), .{ 0, 1 });
            try testArgs(@Vector(2, u17), @Vector(2, u1), .{ 0, 1 });
            try testArgs(@Vector(2, u31), @Vector(2, u1), .{ 0, 1 });
            try testArgs(@Vector(2, u32), @Vector(2, u1), .{ 0, 1 });
            try testArgs(@Vector(2, u33), @Vector(2, u1), .{ 0, 1 });
            try testArgs(@Vector(2, u63), @Vector(2, u1), .{ 0, 1 });
            try testArgs(@Vector(2, u64), @Vector(2, u1), .{ 0, 1 });
            try testArgs(@Vector(2, u65), @Vector(2, u1), .{ 0, 1 });
            try testArgs(@Vector(2, u127), @Vector(2, u1), .{ 0, 1 });
            try testArgs(@Vector(2, u128), @Vector(2, u1), .{ 0, 1 });
            try testArgs(@Vector(2, u129), @Vector(2, u1), .{ 0, 1 });
            try testArgs(@Vector(2, u255), @Vector(2, u1), .{ 0, 1 });
            try testArgs(@Vector(2, u256), @Vector(2, u1), .{ 0, 1 });
            try testArgs(@Vector(2, u257), @Vector(2, u1), .{ 0, 1 });
            try testArgs(@Vector(2, u511), @Vector(2, u1), .{ 0, 1 });
            try testArgs(@Vector(2, u512), @Vector(2, u1), .{ 0, 1 });
            try testArgs(@Vector(2, u513), @Vector(2, u1), .{ 0, 1 });
            try testArgs(@Vector(2, u1023), @Vector(2, u1), .{ 0, 1 });
            try testArgs(@Vector(2, u1024), @Vector(2, u1), .{ 0, 1 });
            try testArgs(@Vector(2, u1025), @Vector(2, u1), .{ 0, 1 });

            try testArgs(@Vector(3, i7), @Vector(3, i2), .{ -1 << 1, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, i2), .{ -1 << 1, -1, 0 });
            try testArgs(@Vector(3, i9), @Vector(3, i2), .{ -1 << 1, -1, 0 });
            try testArgs(@Vector(3, i15), @Vector(3, i2), .{ -1 << 1, -1, 0 });
            try testArgs(@Vector(3, i16), @Vector(3, i2), .{ -1 << 1, -1, 0 });
            try testArgs(@Vector(3, i17), @Vector(3, i2), .{ -1 << 1, -1, 0 });
            try testArgs(@Vector(3, i31), @Vector(3, i2), .{ -1 << 1, -1, 0 });
            try testArgs(@Vector(3, i32), @Vector(3, i2), .{ -1 << 1, -1, 0 });
            try testArgs(@Vector(3, i33), @Vector(3, i2), .{ -1 << 1, -1, 0 });
            try testArgs(@Vector(3, i63), @Vector(3, i2), .{ -1 << 1, -1, 0 });
            try testArgs(@Vector(3, i64), @Vector(3, i2), .{ -1 << 1, -1, 0 });
            try testArgs(@Vector(3, i65), @Vector(3, i2), .{ -1 << 1, -1, 0 });
            try testArgs(@Vector(3, i127), @Vector(3, i2), .{ -1 << 1, -1, 0 });
            try testArgs(@Vector(3, i128), @Vector(3, i2), .{ -1 << 1, -1, 0 });
            try testArgs(@Vector(3, i129), @Vector(3, i2), .{ -1 << 1, -1, 0 });
            try testArgs(@Vector(3, i255), @Vector(3, i2), .{ -1 << 1, -1, 0 });
            try testArgs(@Vector(3, i256), @Vector(3, i2), .{ -1 << 1, -1, 0 });
            try testArgs(@Vector(3, i257), @Vector(3, i2), .{ -1 << 1, -1, 0 });
            try testArgs(@Vector(3, i511), @Vector(3, i2), .{ -1 << 1, -1, 0 });
            try testArgs(@Vector(3, i512), @Vector(3, i2), .{ -1 << 1, -1, 0 });
            try testArgs(@Vector(3, i513), @Vector(3, i2), .{ -1 << 1, -1, 0 });
            try testArgs(@Vector(3, i1023), @Vector(3, i2), .{ -1 << 1, -1, 0 });
            try testArgs(@Vector(3, i1024), @Vector(3, i2), .{ -1 << 1, -1, 0 });
            try testArgs(@Vector(3, i1025), @Vector(3, i2), .{ -1 << 1, -1, 0 });
            try testArgs(@Vector(3, u7), @Vector(3, u2), .{ 0, 1, 1 << 1 });
            try testArgs(@Vector(3, u8), @Vector(3, u2), .{ 0, 1, 1 << 1 });
            try testArgs(@Vector(3, u9), @Vector(3, u2), .{ 0, 1, 1 << 1 });
            try testArgs(@Vector(3, u15), @Vector(3, u2), .{ 0, 1, 1 << 1 });
            try testArgs(@Vector(3, u16), @Vector(3, u2), .{ 0, 1, 1 << 1 });
            try testArgs(@Vector(3, u17), @Vector(3, u2), .{ 0, 1, 1 << 1 });
            try testArgs(@Vector(3, u31), @Vector(3, u2), .{ 0, 1, 1 << 1 });
            try testArgs(@Vector(3, u32), @Vector(3, u2), .{ 0, 1, 1 << 1 });
            try testArgs(@Vector(3, u33), @Vector(3, u2), .{ 0, 1, 1 << 1 });
            try testArgs(@Vector(3, u63), @Vector(3, u2), .{ 0, 1, 1 << 1 });
            try testArgs(@Vector(3, u64), @Vector(3, u2), .{ 0, 1, 1 << 1 });
            try testArgs(@Vector(3, u65), @Vector(3, u2), .{ 0, 1, 1 << 1 });
            try testArgs(@Vector(3, u127), @Vector(3, u2), .{ 0, 1, 1 << 1 });
            try testArgs(@Vector(3, u128), @Vector(3, u2), .{ 0, 1, 1 << 1 });
            try testArgs(@Vector(3, u129), @Vector(3, u2), .{ 0, 1, 1 << 1 });
            try testArgs(@Vector(3, u255), @Vector(3, u2), .{ 0, 1, 1 << 1 });
            try testArgs(@Vector(3, u256), @Vector(3, u2), .{ 0, 1, 1 << 1 });
            try testArgs(@Vector(3, u257), @Vector(3, u2), .{ 0, 1, 1 << 1 });
            try testArgs(@Vector(3, u511), @Vector(3, u2), .{ 0, 1, 1 << 1 });
            try testArgs(@Vector(3, u512), @Vector(3, u2), .{ 0, 1, 1 << 1 });
            try testArgs(@Vector(3, u513), @Vector(3, u2), .{ 0, 1, 1 << 1 });
            try testArgs(@Vector(3, u1023), @Vector(3, u2), .{ 0, 1, 1 << 1 });
            try testArgs(@Vector(3, u1024), @Vector(3, u2), .{ 0, 1, 1 << 1 });
            try testArgs(@Vector(3, u1025), @Vector(3, u2), .{ 0, 1, 1 << 1 });

            try testArgs(@Vector(3, i7), @Vector(3, i3), .{ -1 << 2, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, i3), .{ -1 << 2, -1, 0 });
            try testArgs(@Vector(3, i9), @Vector(3, i3), .{ -1 << 2, -1, 0 });
            try testArgs(@Vector(3, i15), @Vector(3, i3), .{ -1 << 2, -1, 0 });
            try testArgs(@Vector(3, i16), @Vector(3, i3), .{ -1 << 2, -1, 0 });
            try testArgs(@Vector(3, i17), @Vector(3, i3), .{ -1 << 2, -1, 0 });
            try testArgs(@Vector(3, i31), @Vector(3, i3), .{ -1 << 2, -1, 0 });
            try testArgs(@Vector(3, i32), @Vector(3, i3), .{ -1 << 2, -1, 0 });
            try testArgs(@Vector(3, i33), @Vector(3, i3), .{ -1 << 2, -1, 0 });
            try testArgs(@Vector(3, i63), @Vector(3, i3), .{ -1 << 2, -1, 0 });
            try testArgs(@Vector(3, i64), @Vector(3, i3), .{ -1 << 2, -1, 0 });
            try testArgs(@Vector(3, i65), @Vector(3, i3), .{ -1 << 2, -1, 0 });
            try testArgs(@Vector(3, i127), @Vector(3, i3), .{ -1 << 2, -1, 0 });
            try testArgs(@Vector(3, i128), @Vector(3, i3), .{ -1 << 2, -1, 0 });
            try testArgs(@Vector(3, i129), @Vector(3, i3), .{ -1 << 2, -1, 0 });
            try testArgs(@Vector(3, i255), @Vector(3, i3), .{ -1 << 2, -1, 0 });
            try testArgs(@Vector(3, i256), @Vector(3, i3), .{ -1 << 2, -1, 0 });
            try testArgs(@Vector(3, i257), @Vector(3, i3), .{ -1 << 2, -1, 0 });
            try testArgs(@Vector(3, i511), @Vector(3, i3), .{ -1 << 2, -1, 0 });
            try testArgs(@Vector(3, i512), @Vector(3, i3), .{ -1 << 2, -1, 0 });
            try testArgs(@Vector(3, i513), @Vector(3, i3), .{ -1 << 2, -1, 0 });
            try testArgs(@Vector(3, i1023), @Vector(3, i3), .{ -1 << 2, -1, 0 });
            try testArgs(@Vector(3, i1024), @Vector(3, i3), .{ -1 << 2, -1, 0 });
            try testArgs(@Vector(3, i1025), @Vector(3, i3), .{ -1 << 2, -1, 0 });
            try testArgs(@Vector(3, u7), @Vector(3, u3), .{ 0, 1, 1 << 2 });
            try testArgs(@Vector(3, u8), @Vector(3, u3), .{ 0, 1, 1 << 2 });
            try testArgs(@Vector(3, u9), @Vector(3, u3), .{ 0, 1, 1 << 2 });
            try testArgs(@Vector(3, u15), @Vector(3, u3), .{ 0, 1, 1 << 2 });
            try testArgs(@Vector(3, u16), @Vector(3, u3), .{ 0, 1, 1 << 2 });
            try testArgs(@Vector(3, u17), @Vector(3, u3), .{ 0, 1, 1 << 2 });
            try testArgs(@Vector(3, u31), @Vector(3, u3), .{ 0, 1, 1 << 2 });
            try testArgs(@Vector(3, u32), @Vector(3, u3), .{ 0, 1, 1 << 2 });
            try testArgs(@Vector(3, u33), @Vector(3, u3), .{ 0, 1, 1 << 2 });
            try testArgs(@Vector(3, u63), @Vector(3, u3), .{ 0, 1, 1 << 2 });
            try testArgs(@Vector(3, u64), @Vector(3, u3), .{ 0, 1, 1 << 2 });
            try testArgs(@Vector(3, u65), @Vector(3, u3), .{ 0, 1, 1 << 2 });
            try testArgs(@Vector(3, u127), @Vector(3, u3), .{ 0, 1, 1 << 2 });
            try testArgs(@Vector(3, u128), @Vector(3, u3), .{ 0, 1, 1 << 2 });
            try testArgs(@Vector(3, u129), @Vector(3, u3), .{ 0, 1, 1 << 2 });
            try testArgs(@Vector(3, u255), @Vector(3, u3), .{ 0, 1, 1 << 2 });
            try testArgs(@Vector(3, u256), @Vector(3, u3), .{ 0, 1, 1 << 2 });
            try testArgs(@Vector(3, u257), @Vector(3, u3), .{ 0, 1, 1 << 2 });
            try testArgs(@Vector(3, u511), @Vector(3, u3), .{ 0, 1, 1 << 2 });
            try testArgs(@Vector(3, u512), @Vector(3, u3), .{ 0, 1, 1 << 2 });
            try testArgs(@Vector(3, u513), @Vector(3, u3), .{ 0, 1, 1 << 2 });
            try testArgs(@Vector(3, u1023), @Vector(3, u3), .{ 0, 1, 1 << 2 });
            try testArgs(@Vector(3, u1024), @Vector(3, u3), .{ 0, 1, 1 << 2 });
            try testArgs(@Vector(3, u1025), @Vector(3, u3), .{ 0, 1, 1 << 2 });

            try testArgs(@Vector(3, i7), @Vector(3, i4), .{ -1 << 3, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, i4), .{ -1 << 3, -1, 0 });
            try testArgs(@Vector(3, i9), @Vector(3, i4), .{ -1 << 3, -1, 0 });
            try testArgs(@Vector(3, i15), @Vector(3, i4), .{ -1 << 3, -1, 0 });
            try testArgs(@Vector(3, i16), @Vector(3, i4), .{ -1 << 3, -1, 0 });
            try testArgs(@Vector(3, i17), @Vector(3, i4), .{ -1 << 3, -1, 0 });
            try testArgs(@Vector(3, i31), @Vector(3, i4), .{ -1 << 3, -1, 0 });
            try testArgs(@Vector(3, i32), @Vector(3, i4), .{ -1 << 3, -1, 0 });
            try testArgs(@Vector(3, i33), @Vector(3, i4), .{ -1 << 3, -1, 0 });
            try testArgs(@Vector(3, i63), @Vector(3, i4), .{ -1 << 3, -1, 0 });
            try testArgs(@Vector(3, i64), @Vector(3, i4), .{ -1 << 3, -1, 0 });
            try testArgs(@Vector(3, i65), @Vector(3, i4), .{ -1 << 3, -1, 0 });
            try testArgs(@Vector(3, i127), @Vector(3, i4), .{ -1 << 3, -1, 0 });
            try testArgs(@Vector(3, i128), @Vector(3, i4), .{ -1 << 3, -1, 0 });
            try testArgs(@Vector(3, i129), @Vector(3, i4), .{ -1 << 3, -1, 0 });
            try testArgs(@Vector(3, i255), @Vector(3, i4), .{ -1 << 3, -1, 0 });
            try testArgs(@Vector(3, i256), @Vector(3, i4), .{ -1 << 3, -1, 0 });
            try testArgs(@Vector(3, i257), @Vector(3, i4), .{ -1 << 3, -1, 0 });
            try testArgs(@Vector(3, i511), @Vector(3, i4), .{ -1 << 3, -1, 0 });
            try testArgs(@Vector(3, i512), @Vector(3, i4), .{ -1 << 3, -1, 0 });
            try testArgs(@Vector(3, i513), @Vector(3, i4), .{ -1 << 3, -1, 0 });
            try testArgs(@Vector(3, i1023), @Vector(3, i4), .{ -1 << 3, -1, 0 });
            try testArgs(@Vector(3, i1024), @Vector(3, i4), .{ -1 << 3, -1, 0 });
            try testArgs(@Vector(3, i1025), @Vector(3, i4), .{ -1 << 3, -1, 0 });
            try testArgs(@Vector(3, u7), @Vector(3, u4), .{ 0, 1, 1 << 3 });
            try testArgs(@Vector(3, u8), @Vector(3, u4), .{ 0, 1, 1 << 3 });
            try testArgs(@Vector(3, u9), @Vector(3, u4), .{ 0, 1, 1 << 3 });
            try testArgs(@Vector(3, u15), @Vector(3, u4), .{ 0, 1, 1 << 3 });
            try testArgs(@Vector(3, u16), @Vector(3, u4), .{ 0, 1, 1 << 3 });
            try testArgs(@Vector(3, u17), @Vector(3, u4), .{ 0, 1, 1 << 3 });
            try testArgs(@Vector(3, u31), @Vector(3, u4), .{ 0, 1, 1 << 3 });
            try testArgs(@Vector(3, u32), @Vector(3, u4), .{ 0, 1, 1 << 3 });
            try testArgs(@Vector(3, u33), @Vector(3, u4), .{ 0, 1, 1 << 3 });
            try testArgs(@Vector(3, u63), @Vector(3, u4), .{ 0, 1, 1 << 3 });
            try testArgs(@Vector(3, u64), @Vector(3, u4), .{ 0, 1, 1 << 3 });
            try testArgs(@Vector(3, u65), @Vector(3, u4), .{ 0, 1, 1 << 3 });
            try testArgs(@Vector(3, u127), @Vector(3, u4), .{ 0, 1, 1 << 3 });
            try testArgs(@Vector(3, u128), @Vector(3, u4), .{ 0, 1, 1 << 3 });
            try testArgs(@Vector(3, u129), @Vector(3, u4), .{ 0, 1, 1 << 3 });
            try testArgs(@Vector(3, u255), @Vector(3, u4), .{ 0, 1, 1 << 3 });
            try testArgs(@Vector(3, u256), @Vector(3, u4), .{ 0, 1, 1 << 3 });
            try testArgs(@Vector(3, u257), @Vector(3, u4), .{ 0, 1, 1 << 3 });
            try testArgs(@Vector(3, u511), @Vector(3, u4), .{ 0, 1, 1 << 3 });
            try testArgs(@Vector(3, u512), @Vector(3, u4), .{ 0, 1, 1 << 3 });
            try testArgs(@Vector(3, u513), @Vector(3, u4), .{ 0, 1, 1 << 3 });
            try testArgs(@Vector(3, u1023), @Vector(3, u4), .{ 0, 1, 1 << 3 });
            try testArgs(@Vector(3, u1024), @Vector(3, u4), .{ 0, 1, 1 << 3 });
            try testArgs(@Vector(3, u1025), @Vector(3, u4), .{ 0, 1, 1 << 3 });

            try testArgs(@Vector(3, i7), @Vector(3, i5), .{ -1 << 4, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, i5), .{ -1 << 4, -1, 0 });
            try testArgs(@Vector(3, i9), @Vector(3, i5), .{ -1 << 4, -1, 0 });
            try testArgs(@Vector(3, i15), @Vector(3, i5), .{ -1 << 4, -1, 0 });
            try testArgs(@Vector(3, i16), @Vector(3, i5), .{ -1 << 4, -1, 0 });
            try testArgs(@Vector(3, i17), @Vector(3, i5), .{ -1 << 4, -1, 0 });
            try testArgs(@Vector(3, i31), @Vector(3, i5), .{ -1 << 4, -1, 0 });
            try testArgs(@Vector(3, i32), @Vector(3, i5), .{ -1 << 4, -1, 0 });
            try testArgs(@Vector(3, i33), @Vector(3, i5), .{ -1 << 4, -1, 0 });
            try testArgs(@Vector(3, i63), @Vector(3, i5), .{ -1 << 4, -1, 0 });
            try testArgs(@Vector(3, i64), @Vector(3, i5), .{ -1 << 4, -1, 0 });
            try testArgs(@Vector(3, i65), @Vector(3, i5), .{ -1 << 4, -1, 0 });
            try testArgs(@Vector(3, i127), @Vector(3, i5), .{ -1 << 4, -1, 0 });
            try testArgs(@Vector(3, i128), @Vector(3, i5), .{ -1 << 4, -1, 0 });
            try testArgs(@Vector(3, i129), @Vector(3, i5), .{ -1 << 4, -1, 0 });
            try testArgs(@Vector(3, i255), @Vector(3, i5), .{ -1 << 4, -1, 0 });
            try testArgs(@Vector(3, i256), @Vector(3, i5), .{ -1 << 4, -1, 0 });
            try testArgs(@Vector(3, i257), @Vector(3, i5), .{ -1 << 4, -1, 0 });
            try testArgs(@Vector(3, i511), @Vector(3, i5), .{ -1 << 4, -1, 0 });
            try testArgs(@Vector(3, i512), @Vector(3, i5), .{ -1 << 4, -1, 0 });
            try testArgs(@Vector(3, i513), @Vector(3, i5), .{ -1 << 4, -1, 0 });
            try testArgs(@Vector(3, i1023), @Vector(3, i5), .{ -1 << 4, -1, 0 });
            try testArgs(@Vector(3, i1024), @Vector(3, i5), .{ -1 << 4, -1, 0 });
            try testArgs(@Vector(3, i1025), @Vector(3, i5), .{ -1 << 4, -1, 0 });
            try testArgs(@Vector(3, u7), @Vector(3, u5), .{ 0, 1, 1 << 4 });
            try testArgs(@Vector(3, u8), @Vector(3, u5), .{ 0, 1, 1 << 4 });
            try testArgs(@Vector(3, u9), @Vector(3, u5), .{ 0, 1, 1 << 4 });
            try testArgs(@Vector(3, u15), @Vector(3, u5), .{ 0, 1, 1 << 4 });
            try testArgs(@Vector(3, u16), @Vector(3, u5), .{ 0, 1, 1 << 4 });
            try testArgs(@Vector(3, u17), @Vector(3, u5), .{ 0, 1, 1 << 4 });
            try testArgs(@Vector(3, u31), @Vector(3, u5), .{ 0, 1, 1 << 4 });
            try testArgs(@Vector(3, u32), @Vector(3, u5), .{ 0, 1, 1 << 4 });
            try testArgs(@Vector(3, u33), @Vector(3, u5), .{ 0, 1, 1 << 4 });
            try testArgs(@Vector(3, u63), @Vector(3, u5), .{ 0, 1, 1 << 4 });
            try testArgs(@Vector(3, u64), @Vector(3, u5), .{ 0, 1, 1 << 4 });
            try testArgs(@Vector(3, u65), @Vector(3, u5), .{ 0, 1, 1 << 4 });
            try testArgs(@Vector(3, u127), @Vector(3, u5), .{ 0, 1, 1 << 4 });
            try testArgs(@Vector(3, u128), @Vector(3, u5), .{ 0, 1, 1 << 4 });
            try testArgs(@Vector(3, u129), @Vector(3, u5), .{ 0, 1, 1 << 4 });
            try testArgs(@Vector(3, u255), @Vector(3, u5), .{ 0, 1, 1 << 4 });
            try testArgs(@Vector(3, u256), @Vector(3, u5), .{ 0, 1, 1 << 4 });
            try testArgs(@Vector(3, u257), @Vector(3, u5), .{ 0, 1, 1 << 4 });
            try testArgs(@Vector(3, u511), @Vector(3, u5), .{ 0, 1, 1 << 4 });
            try testArgs(@Vector(3, u512), @Vector(3, u5), .{ 0, 1, 1 << 4 });
            try testArgs(@Vector(3, u513), @Vector(3, u5), .{ 0, 1, 1 << 4 });
            try testArgs(@Vector(3, u1023), @Vector(3, u5), .{ 0, 1, 1 << 4 });
            try testArgs(@Vector(3, u1024), @Vector(3, u5), .{ 0, 1, 1 << 4 });
            try testArgs(@Vector(3, u1025), @Vector(3, u5), .{ 0, 1, 1 << 4 });

            try testArgs(@Vector(3, i7), @Vector(3, i7), .{ -1 << 6, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, i7), .{ -1 << 6, -1, 0 });
            try testArgs(@Vector(3, i9), @Vector(3, i7), .{ -1 << 6, -1, 0 });
            try testArgs(@Vector(3, i15), @Vector(3, i7), .{ -1 << 6, -1, 0 });
            try testArgs(@Vector(3, i16), @Vector(3, i7), .{ -1 << 6, -1, 0 });
            try testArgs(@Vector(3, i17), @Vector(3, i7), .{ -1 << 6, -1, 0 });
            try testArgs(@Vector(3, i31), @Vector(3, i7), .{ -1 << 6, -1, 0 });
            try testArgs(@Vector(3, i32), @Vector(3, i7), .{ -1 << 6, -1, 0 });
            try testArgs(@Vector(3, i33), @Vector(3, i7), .{ -1 << 6, -1, 0 });
            try testArgs(@Vector(3, i63), @Vector(3, i7), .{ -1 << 6, -1, 0 });
            try testArgs(@Vector(3, i64), @Vector(3, i7), .{ -1 << 6, -1, 0 });
            try testArgs(@Vector(3, i65), @Vector(3, i7), .{ -1 << 6, -1, 0 });
            try testArgs(@Vector(3, i127), @Vector(3, i7), .{ -1 << 6, -1, 0 });
            try testArgs(@Vector(3, i128), @Vector(3, i7), .{ -1 << 6, -1, 0 });
            try testArgs(@Vector(3, i129), @Vector(3, i7), .{ -1 << 6, -1, 0 });
            try testArgs(@Vector(3, i255), @Vector(3, i7), .{ -1 << 6, -1, 0 });
            try testArgs(@Vector(3, i256), @Vector(3, i7), .{ -1 << 6, -1, 0 });
            try testArgs(@Vector(3, i257), @Vector(3, i7), .{ -1 << 6, -1, 0 });
            try testArgs(@Vector(3, i511), @Vector(3, i7), .{ -1 << 6, -1, 0 });
            try testArgs(@Vector(3, i512), @Vector(3, i7), .{ -1 << 6, -1, 0 });
            try testArgs(@Vector(3, i513), @Vector(3, i7), .{ -1 << 6, -1, 0 });
            try testArgs(@Vector(3, i1023), @Vector(3, i7), .{ -1 << 6, -1, 0 });
            try testArgs(@Vector(3, i1024), @Vector(3, i7), .{ -1 << 6, -1, 0 });
            try testArgs(@Vector(3, i1025), @Vector(3, i7), .{ -1 << 6, -1, 0 });
            try testArgs(@Vector(3, u7), @Vector(3, u7), .{ 0, 1, 1 << 6 });
            try testArgs(@Vector(3, u8), @Vector(3, u7), .{ 0, 1, 1 << 6 });
            try testArgs(@Vector(3, u9), @Vector(3, u7), .{ 0, 1, 1 << 6 });
            try testArgs(@Vector(3, u15), @Vector(3, u7), .{ 0, 1, 1 << 6 });
            try testArgs(@Vector(3, u16), @Vector(3, u7), .{ 0, 1, 1 << 6 });
            try testArgs(@Vector(3, u17), @Vector(3, u7), .{ 0, 1, 1 << 6 });
            try testArgs(@Vector(3, u31), @Vector(3, u7), .{ 0, 1, 1 << 6 });
            try testArgs(@Vector(3, u32), @Vector(3, u7), .{ 0, 1, 1 << 6 });
            try testArgs(@Vector(3, u33), @Vector(3, u7), .{ 0, 1, 1 << 6 });
            try testArgs(@Vector(3, u63), @Vector(3, u7), .{ 0, 1, 1 << 6 });
            try testArgs(@Vector(3, u64), @Vector(3, u7), .{ 0, 1, 1 << 6 });
            try testArgs(@Vector(3, u65), @Vector(3, u7), .{ 0, 1, 1 << 6 });
            try testArgs(@Vector(3, u127), @Vector(3, u7), .{ 0, 1, 1 << 6 });
            try testArgs(@Vector(3, u128), @Vector(3, u7), .{ 0, 1, 1 << 6 });
            try testArgs(@Vector(3, u129), @Vector(3, u7), .{ 0, 1, 1 << 6 });
            try testArgs(@Vector(3, u255), @Vector(3, u7), .{ 0, 1, 1 << 6 });
            try testArgs(@Vector(3, u256), @Vector(3, u7), .{ 0, 1, 1 << 6 });
            try testArgs(@Vector(3, u257), @Vector(3, u7), .{ 0, 1, 1 << 6 });
            try testArgs(@Vector(3, u511), @Vector(3, u7), .{ 0, 1, 1 << 6 });
            try testArgs(@Vector(3, u512), @Vector(3, u7), .{ 0, 1, 1 << 6 });
            try testArgs(@Vector(3, u513), @Vector(3, u7), .{ 0, 1, 1 << 6 });
            try testArgs(@Vector(3, u1023), @Vector(3, u7), .{ 0, 1, 1 << 6 });
            try testArgs(@Vector(3, u1024), @Vector(3, u7), .{ 0, 1, 1 << 6 });
            try testArgs(@Vector(3, u1025), @Vector(3, u7), .{ 0, 1, 1 << 6 });

            try testArgs(@Vector(3, i7), @Vector(3, i8), .{ -1 << 7, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, i8), .{ -1 << 7, -1, 0 });
            try testArgs(@Vector(3, i9), @Vector(3, i8), .{ -1 << 7, -1, 0 });
            try testArgs(@Vector(3, i15), @Vector(3, i8), .{ -1 << 7, -1, 0 });
            try testArgs(@Vector(3, i16), @Vector(3, i8), .{ -1 << 7, -1, 0 });
            try testArgs(@Vector(3, i17), @Vector(3, i8), .{ -1 << 7, -1, 0 });
            try testArgs(@Vector(3, i31), @Vector(3, i8), .{ -1 << 7, -1, 0 });
            try testArgs(@Vector(3, i32), @Vector(3, i8), .{ -1 << 7, -1, 0 });
            try testArgs(@Vector(3, i33), @Vector(3, i8), .{ -1 << 7, -1, 0 });
            try testArgs(@Vector(3, i63), @Vector(3, i8), .{ -1 << 7, -1, 0 });
            try testArgs(@Vector(3, i64), @Vector(3, i8), .{ -1 << 7, -1, 0 });
            try testArgs(@Vector(3, i65), @Vector(3, i8), .{ -1 << 7, -1, 0 });
            try testArgs(@Vector(3, i127), @Vector(3, i8), .{ -1 << 7, -1, 0 });
            try testArgs(@Vector(3, i128), @Vector(3, i8), .{ -1 << 7, -1, 0 });
            try testArgs(@Vector(3, i129), @Vector(3, i8), .{ -1 << 7, -1, 0 });
            try testArgs(@Vector(3, i255), @Vector(3, i8), .{ -1 << 7, -1, 0 });
            try testArgs(@Vector(3, i256), @Vector(3, i8), .{ -1 << 7, -1, 0 });
            try testArgs(@Vector(3, i257), @Vector(3, i8), .{ -1 << 7, -1, 0 });
            try testArgs(@Vector(3, i511), @Vector(3, i8), .{ -1 << 7, -1, 0 });
            try testArgs(@Vector(3, i512), @Vector(3, i8), .{ -1 << 7, -1, 0 });
            try testArgs(@Vector(3, i513), @Vector(3, i8), .{ -1 << 7, -1, 0 });
            try testArgs(@Vector(3, i1023), @Vector(3, i8), .{ -1 << 7, -1, 0 });
            try testArgs(@Vector(3, i1024), @Vector(3, i8), .{ -1 << 7, -1, 0 });
            try testArgs(@Vector(3, i1025), @Vector(3, i8), .{ -1 << 7, -1, 0 });
            try testArgs(@Vector(3, u7), @Vector(3, u8), .{ 0, 1, 1 << 7 });
            try testArgs(@Vector(3, u8), @Vector(3, u8), .{ 0, 1, 1 << 7 });
            try testArgs(@Vector(3, u9), @Vector(3, u8), .{ 0, 1, 1 << 7 });
            try testArgs(@Vector(3, u15), @Vector(3, u8), .{ 0, 1, 1 << 7 });
            try testArgs(@Vector(3, u16), @Vector(3, u8), .{ 0, 1, 1 << 7 });
            try testArgs(@Vector(3, u17), @Vector(3, u8), .{ 0, 1, 1 << 7 });
            try testArgs(@Vector(3, u31), @Vector(3, u8), .{ 0, 1, 1 << 7 });
            try testArgs(@Vector(3, u32), @Vector(3, u8), .{ 0, 1, 1 << 7 });
            try testArgs(@Vector(3, u33), @Vector(3, u8), .{ 0, 1, 1 << 7 });
            try testArgs(@Vector(3, u63), @Vector(3, u8), .{ 0, 1, 1 << 7 });
            try testArgs(@Vector(3, u64), @Vector(3, u8), .{ 0, 1, 1 << 7 });
            try testArgs(@Vector(3, u65), @Vector(3, u8), .{ 0, 1, 1 << 7 });
            try testArgs(@Vector(3, u127), @Vector(3, u8), .{ 0, 1, 1 << 7 });
            try testArgs(@Vector(3, u128), @Vector(3, u8), .{ 0, 1, 1 << 7 });
            try testArgs(@Vector(3, u129), @Vector(3, u8), .{ 0, 1, 1 << 7 });
            try testArgs(@Vector(3, u255), @Vector(3, u8), .{ 0, 1, 1 << 7 });
            try testArgs(@Vector(3, u256), @Vector(3, u8), .{ 0, 1, 1 << 7 });
            try testArgs(@Vector(3, u257), @Vector(3, u8), .{ 0, 1, 1 << 7 });
            try testArgs(@Vector(3, u511), @Vector(3, u8), .{ 0, 1, 1 << 7 });
            try testArgs(@Vector(3, u512), @Vector(3, u8), .{ 0, 1, 1 << 7 });
            try testArgs(@Vector(3, u513), @Vector(3, u8), .{ 0, 1, 1 << 7 });
            try testArgs(@Vector(3, u1023), @Vector(3, u8), .{ 0, 1, 1 << 7 });
            try testArgs(@Vector(3, u1024), @Vector(3, u8), .{ 0, 1, 1 << 7 });
            try testArgs(@Vector(3, u1025), @Vector(3, u8), .{ 0, 1, 1 << 7 });

            try testArgs(@Vector(3, i7), @Vector(3, i9), .{ -1 << 8, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, i9), .{ -1 << 8, -1, 0 });
            try testArgs(@Vector(3, i9), @Vector(3, i9), .{ -1 << 8, -1, 0 });
            try testArgs(@Vector(3, i15), @Vector(3, i9), .{ -1 << 8, -1, 0 });
            try testArgs(@Vector(3, i16), @Vector(3, i9), .{ -1 << 8, -1, 0 });
            try testArgs(@Vector(3, i17), @Vector(3, i9), .{ -1 << 8, -1, 0 });
            try testArgs(@Vector(3, i31), @Vector(3, i9), .{ -1 << 8, -1, 0 });
            try testArgs(@Vector(3, i32), @Vector(3, i9), .{ -1 << 8, -1, 0 });
            try testArgs(@Vector(3, i33), @Vector(3, i9), .{ -1 << 8, -1, 0 });
            try testArgs(@Vector(3, i63), @Vector(3, i9), .{ -1 << 8, -1, 0 });
            try testArgs(@Vector(3, i64), @Vector(3, i9), .{ -1 << 8, -1, 0 });
            try testArgs(@Vector(3, i65), @Vector(3, i9), .{ -1 << 8, -1, 0 });
            try testArgs(@Vector(3, i127), @Vector(3, i9), .{ -1 << 8, -1, 0 });
            try testArgs(@Vector(3, i128), @Vector(3, i9), .{ -1 << 8, -1, 0 });
            try testArgs(@Vector(3, i129), @Vector(3, i9), .{ -1 << 8, -1, 0 });
            try testArgs(@Vector(3, i255), @Vector(3, i9), .{ -1 << 8, -1, 0 });
            try testArgs(@Vector(3, i256), @Vector(3, i9), .{ -1 << 8, -1, 0 });
            try testArgs(@Vector(3, i257), @Vector(3, i9), .{ -1 << 8, -1, 0 });
            try testArgs(@Vector(3, i511), @Vector(3, i9), .{ -1 << 8, -1, 0 });
            try testArgs(@Vector(3, i512), @Vector(3, i9), .{ -1 << 8, -1, 0 });
            try testArgs(@Vector(3, i513), @Vector(3, i9), .{ -1 << 8, -1, 0 });
            try testArgs(@Vector(3, i1023), @Vector(3, i9), .{ -1 << 8, -1, 0 });
            try testArgs(@Vector(3, i1024), @Vector(3, i9), .{ -1 << 8, -1, 0 });
            try testArgs(@Vector(3, i1025), @Vector(3, i9), .{ -1 << 8, -1, 0 });
            try testArgs(@Vector(3, u7), @Vector(3, u9), .{ 0, 1, 1 << 8 });
            try testArgs(@Vector(3, u8), @Vector(3, u9), .{ 0, 1, 1 << 8 });
            try testArgs(@Vector(3, u9), @Vector(3, u9), .{ 0, 1, 1 << 8 });
            try testArgs(@Vector(3, u15), @Vector(3, u9), .{ 0, 1, 1 << 8 });
            try testArgs(@Vector(3, u16), @Vector(3, u9), .{ 0, 1, 1 << 8 });
            try testArgs(@Vector(3, u17), @Vector(3, u9), .{ 0, 1, 1 << 8 });
            try testArgs(@Vector(3, u31), @Vector(3, u9), .{ 0, 1, 1 << 8 });
            try testArgs(@Vector(3, u32), @Vector(3, u9), .{ 0, 1, 1 << 8 });
            try testArgs(@Vector(3, u33), @Vector(3, u9), .{ 0, 1, 1 << 8 });
            try testArgs(@Vector(3, u63), @Vector(3, u9), .{ 0, 1, 1 << 8 });
            try testArgs(@Vector(3, u64), @Vector(3, u9), .{ 0, 1, 1 << 8 });
            try testArgs(@Vector(3, u65), @Vector(3, u9), .{ 0, 1, 1 << 8 });
            try testArgs(@Vector(3, u127), @Vector(3, u9), .{ 0, 1, 1 << 8 });
            try testArgs(@Vector(3, u128), @Vector(3, u9), .{ 0, 1, 1 << 8 });
            try testArgs(@Vector(3, u129), @Vector(3, u9), .{ 0, 1, 1 << 8 });
            try testArgs(@Vector(3, u255), @Vector(3, u9), .{ 0, 1, 1 << 8 });
            try testArgs(@Vector(3, u256), @Vector(3, u9), .{ 0, 1, 1 << 8 });
            try testArgs(@Vector(3, u257), @Vector(3, u9), .{ 0, 1, 1 << 8 });
            try testArgs(@Vector(3, u511), @Vector(3, u9), .{ 0, 1, 1 << 8 });
            try testArgs(@Vector(3, u512), @Vector(3, u9), .{ 0, 1, 1 << 8 });
            try testArgs(@Vector(3, u513), @Vector(3, u9), .{ 0, 1, 1 << 8 });
            try testArgs(@Vector(3, u1023), @Vector(3, u9), .{ 0, 1, 1 << 8 });
            try testArgs(@Vector(3, u1024), @Vector(3, u9), .{ 0, 1, 1 << 8 });
            try testArgs(@Vector(3, u1025), @Vector(3, u9), .{ 0, 1, 1 << 8 });

            try testArgs(@Vector(3, i7), @Vector(3, i15), .{ -1 << 14, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, i15), .{ -1 << 14, -1, 0 });
            try testArgs(@Vector(3, i9), @Vector(3, i15), .{ -1 << 14, -1, 0 });
            try testArgs(@Vector(3, i15), @Vector(3, i15), .{ -1 << 14, -1, 0 });
            try testArgs(@Vector(3, i16), @Vector(3, i15), .{ -1 << 14, -1, 0 });
            try testArgs(@Vector(3, i17), @Vector(3, i15), .{ -1 << 14, -1, 0 });
            try testArgs(@Vector(3, i31), @Vector(3, i15), .{ -1 << 14, -1, 0 });
            try testArgs(@Vector(3, i32), @Vector(3, i15), .{ -1 << 14, -1, 0 });
            try testArgs(@Vector(3, i33), @Vector(3, i15), .{ -1 << 14, -1, 0 });
            try testArgs(@Vector(3, i63), @Vector(3, i15), .{ -1 << 14, -1, 0 });
            try testArgs(@Vector(3, i64), @Vector(3, i15), .{ -1 << 14, -1, 0 });
            try testArgs(@Vector(3, i65), @Vector(3, i15), .{ -1 << 14, -1, 0 });
            try testArgs(@Vector(3, i127), @Vector(3, i15), .{ -1 << 14, -1, 0 });
            try testArgs(@Vector(3, i128), @Vector(3, i15), .{ -1 << 14, -1, 0 });
            try testArgs(@Vector(3, i129), @Vector(3, i15), .{ -1 << 14, -1, 0 });
            try testArgs(@Vector(3, i255), @Vector(3, i15), .{ -1 << 14, -1, 0 });
            try testArgs(@Vector(3, i256), @Vector(3, i15), .{ -1 << 14, -1, 0 });
            try testArgs(@Vector(3, i257), @Vector(3, i15), .{ -1 << 14, -1, 0 });
            try testArgs(@Vector(3, i511), @Vector(3, i15), .{ -1 << 14, -1, 0 });
            try testArgs(@Vector(3, i512), @Vector(3, i15), .{ -1 << 14, -1, 0 });
            try testArgs(@Vector(3, i513), @Vector(3, i15), .{ -1 << 14, -1, 0 });
            try testArgs(@Vector(3, i1023), @Vector(3, i15), .{ -1 << 14, -1, 0 });
            try testArgs(@Vector(3, i1024), @Vector(3, i15), .{ -1 << 14, -1, 0 });
            try testArgs(@Vector(3, i1025), @Vector(3, i15), .{ -1 << 14, -1, 0 });
            try testArgs(@Vector(3, u7), @Vector(3, u15), .{ 0, 1, 1 << 14 });
            try testArgs(@Vector(3, u8), @Vector(3, u15), .{ 0, 1, 1 << 14 });
            try testArgs(@Vector(3, u9), @Vector(3, u15), .{ 0, 1, 1 << 14 });
            try testArgs(@Vector(3, u15), @Vector(3, u15), .{ 0, 1, 1 << 14 });
            try testArgs(@Vector(3, u16), @Vector(3, u15), .{ 0, 1, 1 << 14 });
            try testArgs(@Vector(3, u17), @Vector(3, u15), .{ 0, 1, 1 << 14 });
            try testArgs(@Vector(3, u31), @Vector(3, u15), .{ 0, 1, 1 << 14 });
            try testArgs(@Vector(3, u32), @Vector(3, u15), .{ 0, 1, 1 << 14 });
            try testArgs(@Vector(3, u33), @Vector(3, u15), .{ 0, 1, 1 << 14 });
            try testArgs(@Vector(3, u63), @Vector(3, u15), .{ 0, 1, 1 << 14 });
            try testArgs(@Vector(3, u64), @Vector(3, u15), .{ 0, 1, 1 << 14 });
            try testArgs(@Vector(3, u65), @Vector(3, u15), .{ 0, 1, 1 << 14 });
            try testArgs(@Vector(3, u127), @Vector(3, u15), .{ 0, 1, 1 << 14 });
            try testArgs(@Vector(3, u128), @Vector(3, u15), .{ 0, 1, 1 << 14 });
            try testArgs(@Vector(3, u129), @Vector(3, u15), .{ 0, 1, 1 << 14 });
            try testArgs(@Vector(3, u255), @Vector(3, u15), .{ 0, 1, 1 << 14 });
            try testArgs(@Vector(3, u256), @Vector(3, u15), .{ 0, 1, 1 << 14 });
            try testArgs(@Vector(3, u257), @Vector(3, u15), .{ 0, 1, 1 << 14 });
            try testArgs(@Vector(3, u511), @Vector(3, u15), .{ 0, 1, 1 << 14 });
            try testArgs(@Vector(3, u512), @Vector(3, u15), .{ 0, 1, 1 << 14 });
            try testArgs(@Vector(3, u513), @Vector(3, u15), .{ 0, 1, 1 << 14 });
            try testArgs(@Vector(3, u1023), @Vector(3, u15), .{ 0, 1, 1 << 14 });
            try testArgs(@Vector(3, u1024), @Vector(3, u15), .{ 0, 1, 1 << 14 });
            try testArgs(@Vector(3, u1025), @Vector(3, u15), .{ 0, 1, 1 << 14 });

            try testArgs(@Vector(3, i7), @Vector(3, i16), .{ -1 << 15, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, i16), .{ -1 << 15, -1, 0 });
            try testArgs(@Vector(3, i9), @Vector(3, i16), .{ -1 << 15, -1, 0 });
            try testArgs(@Vector(3, i15), @Vector(3, i16), .{ -1 << 15, -1, 0 });
            try testArgs(@Vector(3, i16), @Vector(3, i16), .{ -1 << 15, -1, 0 });
            try testArgs(@Vector(3, i17), @Vector(3, i16), .{ -1 << 15, -1, 0 });
            try testArgs(@Vector(3, i31), @Vector(3, i16), .{ -1 << 15, -1, 0 });
            try testArgs(@Vector(3, i32), @Vector(3, i16), .{ -1 << 15, -1, 0 });
            try testArgs(@Vector(3, i33), @Vector(3, i16), .{ -1 << 15, -1, 0 });
            try testArgs(@Vector(3, i63), @Vector(3, i16), .{ -1 << 15, -1, 0 });
            try testArgs(@Vector(3, i64), @Vector(3, i16), .{ -1 << 15, -1, 0 });
            try testArgs(@Vector(3, i65), @Vector(3, i16), .{ -1 << 15, -1, 0 });
            try testArgs(@Vector(3, i127), @Vector(3, i16), .{ -1 << 15, -1, 0 });
            try testArgs(@Vector(3, i128), @Vector(3, i16), .{ -1 << 15, -1, 0 });
            try testArgs(@Vector(3, i129), @Vector(3, i16), .{ -1 << 15, -1, 0 });
            try testArgs(@Vector(3, i255), @Vector(3, i16), .{ -1 << 15, -1, 0 });
            try testArgs(@Vector(3, i256), @Vector(3, i16), .{ -1 << 15, -1, 0 });
            try testArgs(@Vector(3, i257), @Vector(3, i16), .{ -1 << 15, -1, 0 });
            try testArgs(@Vector(3, i511), @Vector(3, i16), .{ -1 << 15, -1, 0 });
            try testArgs(@Vector(3, i512), @Vector(3, i16), .{ -1 << 15, -1, 0 });
            try testArgs(@Vector(3, i513), @Vector(3, i16), .{ -1 << 15, -1, 0 });
            try testArgs(@Vector(3, i1023), @Vector(3, i16), .{ -1 << 15, -1, 0 });
            try testArgs(@Vector(3, i1024), @Vector(3, i16), .{ -1 << 15, -1, 0 });
            try testArgs(@Vector(3, i1025), @Vector(3, i16), .{ -1 << 15, -1, 0 });
            try testArgs(@Vector(3, u7), @Vector(3, u16), .{ 0, 1, 1 << 15 });
            try testArgs(@Vector(3, u8), @Vector(3, u16), .{ 0, 1, 1 << 15 });
            try testArgs(@Vector(3, u9), @Vector(3, u16), .{ 0, 1, 1 << 15 });
            try testArgs(@Vector(3, u15), @Vector(3, u16), .{ 0, 1, 1 << 15 });
            try testArgs(@Vector(3, u16), @Vector(3, u16), .{ 0, 1, 1 << 15 });
            try testArgs(@Vector(3, u17), @Vector(3, u16), .{ 0, 1, 1 << 15 });
            try testArgs(@Vector(3, u31), @Vector(3, u16), .{ 0, 1, 1 << 15 });
            try testArgs(@Vector(3, u32), @Vector(3, u16), .{ 0, 1, 1 << 15 });
            try testArgs(@Vector(3, u33), @Vector(3, u16), .{ 0, 1, 1 << 15 });
            try testArgs(@Vector(3, u63), @Vector(3, u16), .{ 0, 1, 1 << 15 });
            try testArgs(@Vector(3, u64), @Vector(3, u16), .{ 0, 1, 1 << 15 });
            try testArgs(@Vector(3, u65), @Vector(3, u16), .{ 0, 1, 1 << 15 });
            try testArgs(@Vector(3, u127), @Vector(3, u16), .{ 0, 1, 1 << 15 });
            try testArgs(@Vector(3, u128), @Vector(3, u16), .{ 0, 1, 1 << 15 });
            try testArgs(@Vector(3, u129), @Vector(3, u16), .{ 0, 1, 1 << 15 });
            try testArgs(@Vector(3, u255), @Vector(3, u16), .{ 0, 1, 1 << 15 });
            try testArgs(@Vector(3, u256), @Vector(3, u16), .{ 0, 1, 1 << 15 });
            try testArgs(@Vector(3, u257), @Vector(3, u16), .{ 0, 1, 1 << 15 });
            try testArgs(@Vector(3, u511), @Vector(3, u16), .{ 0, 1, 1 << 15 });
            try testArgs(@Vector(3, u512), @Vector(3, u16), .{ 0, 1, 1 << 15 });
            try testArgs(@Vector(3, u513), @Vector(3, u16), .{ 0, 1, 1 << 15 });
            try testArgs(@Vector(3, u1023), @Vector(3, u16), .{ 0, 1, 1 << 15 });
            try testArgs(@Vector(3, u1024), @Vector(3, u16), .{ 0, 1, 1 << 15 });
            try testArgs(@Vector(3, u1025), @Vector(3, u16), .{ 0, 1, 1 << 15 });

            try testArgs(@Vector(3, i7), @Vector(3, i17), .{ -1 << 16, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, i17), .{ -1 << 16, -1, 0 });
            try testArgs(@Vector(3, i9), @Vector(3, i17), .{ -1 << 16, -1, 0 });
            try testArgs(@Vector(3, i15), @Vector(3, i17), .{ -1 << 16, -1, 0 });
            try testArgs(@Vector(3, i16), @Vector(3, i17), .{ -1 << 16, -1, 0 });
            try testArgs(@Vector(3, i17), @Vector(3, i17), .{ -1 << 16, -1, 0 });
            try testArgs(@Vector(3, i31), @Vector(3, i17), .{ -1 << 16, -1, 0 });
            try testArgs(@Vector(3, i32), @Vector(3, i17), .{ -1 << 16, -1, 0 });
            try testArgs(@Vector(3, i33), @Vector(3, i17), .{ -1 << 16, -1, 0 });
            try testArgs(@Vector(3, i63), @Vector(3, i17), .{ -1 << 16, -1, 0 });
            try testArgs(@Vector(3, i64), @Vector(3, i17), .{ -1 << 16, -1, 0 });
            try testArgs(@Vector(3, i65), @Vector(3, i17), .{ -1 << 16, -1, 0 });
            try testArgs(@Vector(3, i127), @Vector(3, i17), .{ -1 << 16, -1, 0 });
            try testArgs(@Vector(3, i128), @Vector(3, i17), .{ -1 << 16, -1, 0 });
            try testArgs(@Vector(3, i129), @Vector(3, i17), .{ -1 << 16, -1, 0 });
            try testArgs(@Vector(3, i255), @Vector(3, i17), .{ -1 << 16, -1, 0 });
            try testArgs(@Vector(3, i256), @Vector(3, i17), .{ -1 << 16, -1, 0 });
            try testArgs(@Vector(3, i257), @Vector(3, i17), .{ -1 << 16, -1, 0 });
            try testArgs(@Vector(3, i511), @Vector(3, i17), .{ -1 << 16, -1, 0 });
            try testArgs(@Vector(3, i512), @Vector(3, i17), .{ -1 << 16, -1, 0 });
            try testArgs(@Vector(3, i513), @Vector(3, i17), .{ -1 << 16, -1, 0 });
            try testArgs(@Vector(3, i1023), @Vector(3, i17), .{ -1 << 16, -1, 0 });
            try testArgs(@Vector(3, i1024), @Vector(3, i17), .{ -1 << 16, -1, 0 });
            try testArgs(@Vector(3, i1025), @Vector(3, i17), .{ -1 << 16, -1, 0 });
            try testArgs(@Vector(3, u7), @Vector(3, u17), .{ 0, 1, 1 << 16 });
            try testArgs(@Vector(3, u8), @Vector(3, u17), .{ 0, 1, 1 << 16 });
            try testArgs(@Vector(3, u9), @Vector(3, u17), .{ 0, 1, 1 << 16 });
            try testArgs(@Vector(3, u15), @Vector(3, u17), .{ 0, 1, 1 << 16 });
            try testArgs(@Vector(3, u16), @Vector(3, u17), .{ 0, 1, 1 << 16 });
            try testArgs(@Vector(3, u17), @Vector(3, u17), .{ 0, 1, 1 << 16 });
            try testArgs(@Vector(3, u31), @Vector(3, u17), .{ 0, 1, 1 << 16 });
            try testArgs(@Vector(3, u32), @Vector(3, u17), .{ 0, 1, 1 << 16 });
            try testArgs(@Vector(3, u33), @Vector(3, u17), .{ 0, 1, 1 << 16 });
            try testArgs(@Vector(3, u63), @Vector(3, u17), .{ 0, 1, 1 << 16 });
            try testArgs(@Vector(3, u64), @Vector(3, u17), .{ 0, 1, 1 << 16 });
            try testArgs(@Vector(3, u65), @Vector(3, u17), .{ 0, 1, 1 << 16 });
            try testArgs(@Vector(3, u127), @Vector(3, u17), .{ 0, 1, 1 << 16 });
            try testArgs(@Vector(3, u128), @Vector(3, u17), .{ 0, 1, 1 << 16 });
            try testArgs(@Vector(3, u129), @Vector(3, u17), .{ 0, 1, 1 << 16 });
            try testArgs(@Vector(3, u255), @Vector(3, u17), .{ 0, 1, 1 << 16 });
            try testArgs(@Vector(3, u256), @Vector(3, u17), .{ 0, 1, 1 << 16 });
            try testArgs(@Vector(3, u257), @Vector(3, u17), .{ 0, 1, 1 << 16 });
            try testArgs(@Vector(3, u511), @Vector(3, u17), .{ 0, 1, 1 << 16 });
            try testArgs(@Vector(3, u512), @Vector(3, u17), .{ 0, 1, 1 << 16 });
            try testArgs(@Vector(3, u513), @Vector(3, u17), .{ 0, 1, 1 << 16 });
            try testArgs(@Vector(3, u1023), @Vector(3, u17), .{ 0, 1, 1 << 16 });
            try testArgs(@Vector(3, u1024), @Vector(3, u17), .{ 0, 1, 1 << 16 });
            try testArgs(@Vector(3, u1025), @Vector(3, u17), .{ 0, 1, 1 << 16 });

            try testArgs(@Vector(3, i7), @Vector(3, i31), .{ -1 << 30, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, i31), .{ -1 << 30, -1, 0 });
            try testArgs(@Vector(3, i9), @Vector(3, i31), .{ -1 << 30, -1, 0 });
            try testArgs(@Vector(3, i15), @Vector(3, i31), .{ -1 << 30, -1, 0 });
            try testArgs(@Vector(3, i16), @Vector(3, i31), .{ -1 << 30, -1, 0 });
            try testArgs(@Vector(3, i17), @Vector(3, i31), .{ -1 << 30, -1, 0 });
            try testArgs(@Vector(3, i31), @Vector(3, i31), .{ -1 << 30, -1, 0 });
            try testArgs(@Vector(3, i32), @Vector(3, i31), .{ -1 << 30, -1, 0 });
            try testArgs(@Vector(3, i33), @Vector(3, i31), .{ -1 << 30, -1, 0 });
            try testArgs(@Vector(3, i63), @Vector(3, i31), .{ -1 << 30, -1, 0 });
            try testArgs(@Vector(3, i64), @Vector(3, i31), .{ -1 << 30, -1, 0 });
            try testArgs(@Vector(3, i65), @Vector(3, i31), .{ -1 << 30, -1, 0 });
            try testArgs(@Vector(3, i127), @Vector(3, i31), .{ -1 << 30, -1, 0 });
            try testArgs(@Vector(3, i128), @Vector(3, i31), .{ -1 << 30, -1, 0 });
            try testArgs(@Vector(3, i129), @Vector(3, i31), .{ -1 << 30, -1, 0 });
            try testArgs(@Vector(3, i255), @Vector(3, i31), .{ -1 << 30, -1, 0 });
            try testArgs(@Vector(3, i256), @Vector(3, i31), .{ -1 << 30, -1, 0 });
            try testArgs(@Vector(3, i257), @Vector(3, i31), .{ -1 << 30, -1, 0 });
            try testArgs(@Vector(3, i511), @Vector(3, i31), .{ -1 << 30, -1, 0 });
            try testArgs(@Vector(3, i512), @Vector(3, i31), .{ -1 << 30, -1, 0 });
            try testArgs(@Vector(3, i513), @Vector(3, i31), .{ -1 << 30, -1, 0 });
            try testArgs(@Vector(3, i1023), @Vector(3, i31), .{ -1 << 30, -1, 0 });
            try testArgs(@Vector(3, i1024), @Vector(3, i31), .{ -1 << 30, -1, 0 });
            try testArgs(@Vector(3, i1025), @Vector(3, i31), .{ -1 << 30, -1, 0 });
            try testArgs(@Vector(3, u7), @Vector(3, u31), .{ 0, 1, 1 << 30 });
            try testArgs(@Vector(3, u8), @Vector(3, u31), .{ 0, 1, 1 << 30 });
            try testArgs(@Vector(3, u9), @Vector(3, u31), .{ 0, 1, 1 << 30 });
            try testArgs(@Vector(3, u15), @Vector(3, u31), .{ 0, 1, 1 << 30 });
            try testArgs(@Vector(3, u16), @Vector(3, u31), .{ 0, 1, 1 << 30 });
            try testArgs(@Vector(3, u17), @Vector(3, u31), .{ 0, 1, 1 << 30 });
            try testArgs(@Vector(3, u31), @Vector(3, u31), .{ 0, 1, 1 << 30 });
            try testArgs(@Vector(3, u32), @Vector(3, u31), .{ 0, 1, 1 << 30 });
            try testArgs(@Vector(3, u33), @Vector(3, u31), .{ 0, 1, 1 << 30 });
            try testArgs(@Vector(3, u63), @Vector(3, u31), .{ 0, 1, 1 << 30 });
            try testArgs(@Vector(3, u64), @Vector(3, u31), .{ 0, 1, 1 << 30 });
            try testArgs(@Vector(3, u65), @Vector(3, u31), .{ 0, 1, 1 << 30 });
            try testArgs(@Vector(3, u127), @Vector(3, u31), .{ 0, 1, 1 << 30 });
            try testArgs(@Vector(3, u128), @Vector(3, u31), .{ 0, 1, 1 << 30 });
            try testArgs(@Vector(3, u129), @Vector(3, u31), .{ 0, 1, 1 << 30 });
            try testArgs(@Vector(3, u255), @Vector(3, u31), .{ 0, 1, 1 << 30 });
            try testArgs(@Vector(3, u256), @Vector(3, u31), .{ 0, 1, 1 << 30 });
            try testArgs(@Vector(3, u257), @Vector(3, u31), .{ 0, 1, 1 << 30 });
            try testArgs(@Vector(3, u511), @Vector(3, u31), .{ 0, 1, 1 << 30 });
            try testArgs(@Vector(3, u512), @Vector(3, u31), .{ 0, 1, 1 << 30 });
            try testArgs(@Vector(3, u513), @Vector(3, u31), .{ 0, 1, 1 << 30 });
            try testArgs(@Vector(3, u1023), @Vector(3, u31), .{ 0, 1, 1 << 30 });
            try testArgs(@Vector(3, u1024), @Vector(3, u31), .{ 0, 1, 1 << 30 });
            try testArgs(@Vector(3, u1025), @Vector(3, u31), .{ 0, 1, 1 << 30 });

            try testArgs(@Vector(3, i7), @Vector(3, i32), .{ -1 << 31, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, i32), .{ -1 << 31, -1, 0 });
            try testArgs(@Vector(3, i9), @Vector(3, i32), .{ -1 << 31, -1, 0 });
            try testArgs(@Vector(3, i15), @Vector(3, i32), .{ -1 << 31, -1, 0 });
            try testArgs(@Vector(3, i16), @Vector(3, i32), .{ -1 << 31, -1, 0 });
            try testArgs(@Vector(3, i17), @Vector(3, i32), .{ -1 << 31, -1, 0 });
            try testArgs(@Vector(3, i31), @Vector(3, i32), .{ -1 << 31, -1, 0 });
            try testArgs(@Vector(3, i32), @Vector(3, i32), .{ -1 << 31, -1, 0 });
            try testArgs(@Vector(3, i33), @Vector(3, i32), .{ -1 << 31, -1, 0 });
            try testArgs(@Vector(3, i63), @Vector(3, i32), .{ -1 << 31, -1, 0 });
            try testArgs(@Vector(3, i64), @Vector(3, i32), .{ -1 << 31, -1, 0 });
            try testArgs(@Vector(3, i65), @Vector(3, i32), .{ -1 << 31, -1, 0 });
            try testArgs(@Vector(3, i127), @Vector(3, i32), .{ -1 << 31, -1, 0 });
            try testArgs(@Vector(3, i128), @Vector(3, i32), .{ -1 << 31, -1, 0 });
            try testArgs(@Vector(3, i129), @Vector(3, i32), .{ -1 << 31, -1, 0 });
            try testArgs(@Vector(3, i255), @Vector(3, i32), .{ -1 << 31, -1, 0 });
            try testArgs(@Vector(3, i256), @Vector(3, i32), .{ -1 << 31, -1, 0 });
            try testArgs(@Vector(3, i257), @Vector(3, i32), .{ -1 << 31, -1, 0 });
            try testArgs(@Vector(3, i511), @Vector(3, i32), .{ -1 << 31, -1, 0 });
            try testArgs(@Vector(3, i512), @Vector(3, i32), .{ -1 << 31, -1, 0 });
            try testArgs(@Vector(3, i513), @Vector(3, i32), .{ -1 << 31, -1, 0 });
            try testArgs(@Vector(3, i1023), @Vector(3, i32), .{ -1 << 31, -1, 0 });
            try testArgs(@Vector(3, i1024), @Vector(3, i32), .{ -1 << 31, -1, 0 });
            try testArgs(@Vector(3, i1025), @Vector(3, i32), .{ -1 << 31, -1, 0 });
            try testArgs(@Vector(3, u7), @Vector(3, u32), .{ 0, 1, 1 << 31 });
            try testArgs(@Vector(3, u8), @Vector(3, u32), .{ 0, 1, 1 << 31 });
            try testArgs(@Vector(3, u9), @Vector(3, u32), .{ 0, 1, 1 << 31 });
            try testArgs(@Vector(3, u15), @Vector(3, u32), .{ 0, 1, 1 << 31 });
            try testArgs(@Vector(3, u16), @Vector(3, u32), .{ 0, 1, 1 << 31 });
            try testArgs(@Vector(3, u17), @Vector(3, u32), .{ 0, 1, 1 << 31 });
            try testArgs(@Vector(3, u31), @Vector(3, u32), .{ 0, 1, 1 << 31 });
            try testArgs(@Vector(3, u32), @Vector(3, u32), .{ 0, 1, 1 << 31 });
            try testArgs(@Vector(3, u33), @Vector(3, u32), .{ 0, 1, 1 << 31 });
            try testArgs(@Vector(3, u63), @Vector(3, u32), .{ 0, 1, 1 << 31 });
            try testArgs(@Vector(3, u64), @Vector(3, u32), .{ 0, 1, 1 << 31 });
            try testArgs(@Vector(3, u65), @Vector(3, u32), .{ 0, 1, 1 << 31 });
            try testArgs(@Vector(3, u127), @Vector(3, u32), .{ 0, 1, 1 << 31 });
            try testArgs(@Vector(3, u128), @Vector(3, u32), .{ 0, 1, 1 << 31 });
            try testArgs(@Vector(3, u129), @Vector(3, u32), .{ 0, 1, 1 << 31 });
            try testArgs(@Vector(3, u255), @Vector(3, u32), .{ 0, 1, 1 << 31 });
            try testArgs(@Vector(3, u256), @Vector(3, u32), .{ 0, 1, 1 << 31 });
            try testArgs(@Vector(3, u257), @Vector(3, u32), .{ 0, 1, 1 << 31 });
            try testArgs(@Vector(3, u511), @Vector(3, u32), .{ 0, 1, 1 << 31 });
            try testArgs(@Vector(3, u512), @Vector(3, u32), .{ 0, 1, 1 << 31 });
            try testArgs(@Vector(3, u513), @Vector(3, u32), .{ 0, 1, 1 << 31 });
            try testArgs(@Vector(3, u1023), @Vector(3, u32), .{ 0, 1, 1 << 31 });
            try testArgs(@Vector(3, u1024), @Vector(3, u32), .{ 0, 1, 1 << 31 });
            try testArgs(@Vector(3, u1025), @Vector(3, u32), .{ 0, 1, 1 << 31 });

            try testArgs(@Vector(3, i7), @Vector(3, i33), .{ -1 << 32, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, i33), .{ -1 << 32, -1, 0 });
            try testArgs(@Vector(3, i9), @Vector(3, i33), .{ -1 << 32, -1, 0 });
            try testArgs(@Vector(3, i15), @Vector(3, i33), .{ -1 << 32, -1, 0 });
            try testArgs(@Vector(3, i16), @Vector(3, i33), .{ -1 << 32, -1, 0 });
            try testArgs(@Vector(3, i17), @Vector(3, i33), .{ -1 << 32, -1, 0 });
            try testArgs(@Vector(3, i31), @Vector(3, i33), .{ -1 << 32, -1, 0 });
            try testArgs(@Vector(3, i32), @Vector(3, i33), .{ -1 << 32, -1, 0 });
            try testArgs(@Vector(3, i33), @Vector(3, i33), .{ -1 << 32, -1, 0 });
            try testArgs(@Vector(3, i63), @Vector(3, i33), .{ -1 << 32, -1, 0 });
            try testArgs(@Vector(3, i64), @Vector(3, i33), .{ -1 << 32, -1, 0 });
            try testArgs(@Vector(3, i65), @Vector(3, i33), .{ -1 << 32, -1, 0 });
            try testArgs(@Vector(3, i127), @Vector(3, i33), .{ -1 << 32, -1, 0 });
            try testArgs(@Vector(3, i128), @Vector(3, i33), .{ -1 << 32, -1, 0 });
            try testArgs(@Vector(3, i129), @Vector(3, i33), .{ -1 << 32, -1, 0 });
            try testArgs(@Vector(3, i255), @Vector(3, i33), .{ -1 << 32, -1, 0 });
            try testArgs(@Vector(3, i256), @Vector(3, i33), .{ -1 << 32, -1, 0 });
            try testArgs(@Vector(3, i257), @Vector(3, i33), .{ -1 << 32, -1, 0 });
            try testArgs(@Vector(3, i511), @Vector(3, i33), .{ -1 << 32, -1, 0 });
            try testArgs(@Vector(3, i512), @Vector(3, i33), .{ -1 << 32, -1, 0 });
            try testArgs(@Vector(3, i513), @Vector(3, i33), .{ -1 << 32, -1, 0 });
            try testArgs(@Vector(3, i1023), @Vector(3, i33), .{ -1 << 32, -1, 0 });
            try testArgs(@Vector(3, i1024), @Vector(3, i33), .{ -1 << 32, -1, 0 });
            try testArgs(@Vector(3, i1025), @Vector(3, i33), .{ -1 << 32, -1, 0 });
            try testArgs(@Vector(3, u7), @Vector(3, u33), .{ 0, 1, 1 << 32 });
            try testArgs(@Vector(3, u8), @Vector(3, u33), .{ 0, 1, 1 << 32 });
            try testArgs(@Vector(3, u9), @Vector(3, u33), .{ 0, 1, 1 << 32 });
            try testArgs(@Vector(3, u15), @Vector(3, u33), .{ 0, 1, 1 << 32 });
            try testArgs(@Vector(3, u16), @Vector(3, u33), .{ 0, 1, 1 << 32 });
            try testArgs(@Vector(3, u17), @Vector(3, u33), .{ 0, 1, 1 << 32 });
            try testArgs(@Vector(3, u31), @Vector(3, u33), .{ 0, 1, 1 << 32 });
            try testArgs(@Vector(3, u32), @Vector(3, u33), .{ 0, 1, 1 << 32 });
            try testArgs(@Vector(3, u33), @Vector(3, u33), .{ 0, 1, 1 << 32 });
            try testArgs(@Vector(3, u63), @Vector(3, u33), .{ 0, 1, 1 << 32 });
            try testArgs(@Vector(3, u64), @Vector(3, u33), .{ 0, 1, 1 << 32 });
            try testArgs(@Vector(3, u65), @Vector(3, u33), .{ 0, 1, 1 << 32 });
            try testArgs(@Vector(3, u127), @Vector(3, u33), .{ 0, 1, 1 << 32 });
            try testArgs(@Vector(3, u128), @Vector(3, u33), .{ 0, 1, 1 << 32 });
            try testArgs(@Vector(3, u129), @Vector(3, u33), .{ 0, 1, 1 << 32 });
            try testArgs(@Vector(3, u255), @Vector(3, u33), .{ 0, 1, 1 << 32 });
            try testArgs(@Vector(3, u256), @Vector(3, u33), .{ 0, 1, 1 << 32 });
            try testArgs(@Vector(3, u257), @Vector(3, u33), .{ 0, 1, 1 << 32 });
            try testArgs(@Vector(3, u511), @Vector(3, u33), .{ 0, 1, 1 << 32 });
            try testArgs(@Vector(3, u512), @Vector(3, u33), .{ 0, 1, 1 << 32 });
            try testArgs(@Vector(3, u513), @Vector(3, u33), .{ 0, 1, 1 << 32 });
            try testArgs(@Vector(3, u1023), @Vector(3, u33), .{ 0, 1, 1 << 32 });
            try testArgs(@Vector(3, u1024), @Vector(3, u33), .{ 0, 1, 1 << 32 });
            try testArgs(@Vector(3, u1025), @Vector(3, u33), .{ 0, 1, 1 << 32 });

            try testArgs(@Vector(3, i7), @Vector(3, i63), .{ -1 << 62, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, i63), .{ -1 << 62, -1, 0 });
            try testArgs(@Vector(3, i9), @Vector(3, i63), .{ -1 << 62, -1, 0 });
            try testArgs(@Vector(3, i15), @Vector(3, i63), .{ -1 << 62, -1, 0 });
            try testArgs(@Vector(3, i16), @Vector(3, i63), .{ -1 << 62, -1, 0 });
            try testArgs(@Vector(3, i17), @Vector(3, i63), .{ -1 << 62, -1, 0 });
            try testArgs(@Vector(3, i31), @Vector(3, i63), .{ -1 << 62, -1, 0 });
            try testArgs(@Vector(3, i32), @Vector(3, i63), .{ -1 << 62, -1, 0 });
            try testArgs(@Vector(3, i33), @Vector(3, i63), .{ -1 << 62, -1, 0 });
            try testArgs(@Vector(3, i63), @Vector(3, i63), .{ -1 << 62, -1, 0 });
            try testArgs(@Vector(3, i64), @Vector(3, i63), .{ -1 << 62, -1, 0 });
            try testArgs(@Vector(3, i65), @Vector(3, i63), .{ -1 << 62, -1, 0 });
            try testArgs(@Vector(3, i127), @Vector(3, i63), .{ -1 << 62, -1, 0 });
            try testArgs(@Vector(3, i128), @Vector(3, i63), .{ -1 << 62, -1, 0 });
            try testArgs(@Vector(3, i129), @Vector(3, i63), .{ -1 << 62, -1, 0 });
            try testArgs(@Vector(3, i255), @Vector(3, i63), .{ -1 << 62, -1, 0 });
            try testArgs(@Vector(3, i256), @Vector(3, i63), .{ -1 << 62, -1, 0 });
            try testArgs(@Vector(3, i257), @Vector(3, i63), .{ -1 << 62, -1, 0 });
            try testArgs(@Vector(3, i511), @Vector(3, i63), .{ -1 << 62, -1, 0 });
            try testArgs(@Vector(3, i512), @Vector(3, i63), .{ -1 << 62, -1, 0 });
            try testArgs(@Vector(3, i513), @Vector(3, i63), .{ -1 << 62, -1, 0 });
            try testArgs(@Vector(3, i1023), @Vector(3, i63), .{ -1 << 62, -1, 0 });
            try testArgs(@Vector(3, i1024), @Vector(3, i63), .{ -1 << 62, -1, 0 });
            try testArgs(@Vector(3, i1025), @Vector(3, i63), .{ -1 << 62, -1, 0 });
            try testArgs(@Vector(3, u7), @Vector(3, u63), .{ 0, 1, 1 << 62 });
            try testArgs(@Vector(3, u8), @Vector(3, u63), .{ 0, 1, 1 << 62 });
            try testArgs(@Vector(3, u9), @Vector(3, u63), .{ 0, 1, 1 << 62 });
            try testArgs(@Vector(3, u15), @Vector(3, u63), .{ 0, 1, 1 << 62 });
            try testArgs(@Vector(3, u16), @Vector(3, u63), .{ 0, 1, 1 << 62 });
            try testArgs(@Vector(3, u17), @Vector(3, u63), .{ 0, 1, 1 << 62 });
            try testArgs(@Vector(3, u31), @Vector(3, u63), .{ 0, 1, 1 << 62 });
            try testArgs(@Vector(3, u32), @Vector(3, u63), .{ 0, 1, 1 << 62 });
            try testArgs(@Vector(3, u33), @Vector(3, u63), .{ 0, 1, 1 << 62 });
            try testArgs(@Vector(3, u63), @Vector(3, u63), .{ 0, 1, 1 << 62 });
            try testArgs(@Vector(3, u64), @Vector(3, u63), .{ 0, 1, 1 << 62 });
            try testArgs(@Vector(3, u65), @Vector(3, u63), .{ 0, 1, 1 << 62 });
            try testArgs(@Vector(3, u127), @Vector(3, u63), .{ 0, 1, 1 << 62 });
            try testArgs(@Vector(3, u128), @Vector(3, u63), .{ 0, 1, 1 << 62 });
            try testArgs(@Vector(3, u129), @Vector(3, u63), .{ 0, 1, 1 << 62 });
            try testArgs(@Vector(3, u255), @Vector(3, u63), .{ 0, 1, 1 << 62 });
            try testArgs(@Vector(3, u256), @Vector(3, u63), .{ 0, 1, 1 << 62 });
            try testArgs(@Vector(3, u257), @Vector(3, u63), .{ 0, 1, 1 << 62 });
            try testArgs(@Vector(3, u511), @Vector(3, u63), .{ 0, 1, 1 << 62 });
            try testArgs(@Vector(3, u512), @Vector(3, u63), .{ 0, 1, 1 << 62 });
            try testArgs(@Vector(3, u513), @Vector(3, u63), .{ 0, 1, 1 << 62 });
            try testArgs(@Vector(3, u1023), @Vector(3, u63), .{ 0, 1, 1 << 62 });
            try testArgs(@Vector(3, u1024), @Vector(3, u63), .{ 0, 1, 1 << 62 });
            try testArgs(@Vector(3, u1025), @Vector(3, u63), .{ 0, 1, 1 << 62 });

            try testArgs(@Vector(3, i7), @Vector(3, i64), .{ -1 << 63, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, i64), .{ -1 << 63, -1, 0 });
            try testArgs(@Vector(3, i9), @Vector(3, i64), .{ -1 << 63, -1, 0 });
            try testArgs(@Vector(3, i15), @Vector(3, i64), .{ -1 << 63, -1, 0 });
            try testArgs(@Vector(3, i16), @Vector(3, i64), .{ -1 << 63, -1, 0 });
            try testArgs(@Vector(3, i17), @Vector(3, i64), .{ -1 << 63, -1, 0 });
            try testArgs(@Vector(3, i31), @Vector(3, i64), .{ -1 << 63, -1, 0 });
            try testArgs(@Vector(3, i32), @Vector(3, i64), .{ -1 << 63, -1, 0 });
            try testArgs(@Vector(3, i33), @Vector(3, i64), .{ -1 << 63, -1, 0 });
            try testArgs(@Vector(3, i63), @Vector(3, i64), .{ -1 << 63, -1, 0 });
            try testArgs(@Vector(3, i64), @Vector(3, i64), .{ -1 << 63, -1, 0 });
            try testArgs(@Vector(3, i65), @Vector(3, i64), .{ -1 << 63, -1, 0 });
            try testArgs(@Vector(3, i127), @Vector(3, i64), .{ -1 << 63, -1, 0 });
            try testArgs(@Vector(3, i128), @Vector(3, i64), .{ -1 << 63, -1, 0 });
            try testArgs(@Vector(3, i129), @Vector(3, i64), .{ -1 << 63, -1, 0 });
            try testArgs(@Vector(3, i255), @Vector(3, i64), .{ -1 << 63, -1, 0 });
            try testArgs(@Vector(3, i256), @Vector(3, i64), .{ -1 << 63, -1, 0 });
            try testArgs(@Vector(3, i257), @Vector(3, i64), .{ -1 << 63, -1, 0 });
            try testArgs(@Vector(3, i511), @Vector(3, i64), .{ -1 << 63, -1, 0 });
            try testArgs(@Vector(3, i512), @Vector(3, i64), .{ -1 << 63, -1, 0 });
            try testArgs(@Vector(3, i513), @Vector(3, i64), .{ -1 << 63, -1, 0 });
            try testArgs(@Vector(3, i1023), @Vector(3, i64), .{ -1 << 63, -1, 0 });
            try testArgs(@Vector(3, i1024), @Vector(3, i64), .{ -1 << 63, -1, 0 });
            try testArgs(@Vector(3, i1025), @Vector(3, i64), .{ -1 << 63, -1, 0 });
            try testArgs(@Vector(3, u7), @Vector(3, u64), .{ 0, 1, 1 << 63 });
            try testArgs(@Vector(3, u8), @Vector(3, u64), .{ 0, 1, 1 << 63 });
            try testArgs(@Vector(3, u9), @Vector(3, u64), .{ 0, 1, 1 << 63 });
            try testArgs(@Vector(3, u15), @Vector(3, u64), .{ 0, 1, 1 << 63 });
            try testArgs(@Vector(3, u16), @Vector(3, u64), .{ 0, 1, 1 << 63 });
            try testArgs(@Vector(3, u17), @Vector(3, u64), .{ 0, 1, 1 << 63 });
            try testArgs(@Vector(3, u31), @Vector(3, u64), .{ 0, 1, 1 << 63 });
            try testArgs(@Vector(3, u32), @Vector(3, u64), .{ 0, 1, 1 << 63 });
            try testArgs(@Vector(3, u33), @Vector(3, u64), .{ 0, 1, 1 << 63 });
            try testArgs(@Vector(3, u63), @Vector(3, u64), .{ 0, 1, 1 << 63 });
            try testArgs(@Vector(3, u64), @Vector(3, u64), .{ 0, 1, 1 << 63 });
            try testArgs(@Vector(3, u65), @Vector(3, u64), .{ 0, 1, 1 << 63 });
            try testArgs(@Vector(3, u127), @Vector(3, u64), .{ 0, 1, 1 << 63 });
            try testArgs(@Vector(3, u128), @Vector(3, u64), .{ 0, 1, 1 << 63 });
            try testArgs(@Vector(3, u129), @Vector(3, u64), .{ 0, 1, 1 << 63 });
            try testArgs(@Vector(3, u255), @Vector(3, u64), .{ 0, 1, 1 << 63 });
            try testArgs(@Vector(3, u256), @Vector(3, u64), .{ 0, 1, 1 << 63 });
            try testArgs(@Vector(3, u257), @Vector(3, u64), .{ 0, 1, 1 << 63 });
            try testArgs(@Vector(3, u511), @Vector(3, u64), .{ 0, 1, 1 << 63 });
            try testArgs(@Vector(3, u512), @Vector(3, u64), .{ 0, 1, 1 << 63 });
            try testArgs(@Vector(3, u513), @Vector(3, u64), .{ 0, 1, 1 << 63 });
            try testArgs(@Vector(3, u1023), @Vector(3, u64), .{ 0, 1, 1 << 63 });
            try testArgs(@Vector(3, u1024), @Vector(3, u64), .{ 0, 1, 1 << 63 });
            try testArgs(@Vector(3, u1025), @Vector(3, u64), .{ 0, 1, 1 << 63 });

            try testArgs(@Vector(3, i7), @Vector(3, i65), .{ -1 << 64, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, i65), .{ -1 << 64, -1, 0 });
            try testArgs(@Vector(3, i9), @Vector(3, i65), .{ -1 << 64, -1, 0 });
            try testArgs(@Vector(3, i15), @Vector(3, i65), .{ -1 << 64, -1, 0 });
            try testArgs(@Vector(3, i16), @Vector(3, i65), .{ -1 << 64, -1, 0 });
            try testArgs(@Vector(3, i17), @Vector(3, i65), .{ -1 << 64, -1, 0 });
            try testArgs(@Vector(3, i31), @Vector(3, i65), .{ -1 << 64, -1, 0 });
            try testArgs(@Vector(3, i32), @Vector(3, i65), .{ -1 << 64, -1, 0 });
            try testArgs(@Vector(3, i33), @Vector(3, i65), .{ -1 << 64, -1, 0 });
            try testArgs(@Vector(3, i63), @Vector(3, i65), .{ -1 << 64, -1, 0 });
            try testArgs(@Vector(3, i64), @Vector(3, i65), .{ -1 << 64, -1, 0 });
            try testArgs(@Vector(3, i65), @Vector(3, i65), .{ -1 << 64, -1, 0 });
            try testArgs(@Vector(3, i127), @Vector(3, i65), .{ -1 << 64, -1, 0 });
            try testArgs(@Vector(3, i128), @Vector(3, i65), .{ -1 << 64, -1, 0 });
            try testArgs(@Vector(3, i129), @Vector(3, i65), .{ -1 << 64, -1, 0 });
            try testArgs(@Vector(3, i255), @Vector(3, i65), .{ -1 << 64, -1, 0 });
            try testArgs(@Vector(3, i256), @Vector(3, i65), .{ -1 << 64, -1, 0 });
            try testArgs(@Vector(3, i257), @Vector(3, i65), .{ -1 << 64, -1, 0 });
            try testArgs(@Vector(3, i511), @Vector(3, i65), .{ -1 << 64, -1, 0 });
            try testArgs(@Vector(3, i512), @Vector(3, i65), .{ -1 << 64, -1, 0 });
            try testArgs(@Vector(3, i513), @Vector(3, i65), .{ -1 << 64, -1, 0 });
            try testArgs(@Vector(3, i1023), @Vector(3, i65), .{ -1 << 64, -1, 0 });
            try testArgs(@Vector(3, i1024), @Vector(3, i65), .{ -1 << 64, -1, 0 });
            try testArgs(@Vector(3, i1025), @Vector(3, i65), .{ -1 << 64, -1, 0 });
            try testArgs(@Vector(3, u7), @Vector(3, u65), .{ 0, 1, 1 << 64 });
            try testArgs(@Vector(3, u8), @Vector(3, u65), .{ 0, 1, 1 << 64 });
            try testArgs(@Vector(3, u9), @Vector(3, u65), .{ 0, 1, 1 << 64 });
            try testArgs(@Vector(3, u15), @Vector(3, u65), .{ 0, 1, 1 << 64 });
            try testArgs(@Vector(3, u16), @Vector(3, u65), .{ 0, 1, 1 << 64 });
            try testArgs(@Vector(3, u17), @Vector(3, u65), .{ 0, 1, 1 << 64 });
            try testArgs(@Vector(3, u31), @Vector(3, u65), .{ 0, 1, 1 << 64 });
            try testArgs(@Vector(3, u32), @Vector(3, u65), .{ 0, 1, 1 << 64 });
            try testArgs(@Vector(3, u33), @Vector(3, u65), .{ 0, 1, 1 << 64 });
            try testArgs(@Vector(3, u63), @Vector(3, u65), .{ 0, 1, 1 << 64 });
            try testArgs(@Vector(3, u64), @Vector(3, u65), .{ 0, 1, 1 << 64 });
            try testArgs(@Vector(3, u65), @Vector(3, u65), .{ 0, 1, 1 << 64 });
            try testArgs(@Vector(3, u127), @Vector(3, u65), .{ 0, 1, 1 << 64 });
            try testArgs(@Vector(3, u128), @Vector(3, u65), .{ 0, 1, 1 << 64 });
            try testArgs(@Vector(3, u129), @Vector(3, u65), .{ 0, 1, 1 << 64 });
            try testArgs(@Vector(3, u255), @Vector(3, u65), .{ 0, 1, 1 << 64 });
            try testArgs(@Vector(3, u256), @Vector(3, u65), .{ 0, 1, 1 << 64 });
            try testArgs(@Vector(3, u257), @Vector(3, u65), .{ 0, 1, 1 << 64 });
            try testArgs(@Vector(3, u511), @Vector(3, u65), .{ 0, 1, 1 << 64 });
            try testArgs(@Vector(3, u512), @Vector(3, u65), .{ 0, 1, 1 << 64 });
            try testArgs(@Vector(3, u513), @Vector(3, u65), .{ 0, 1, 1 << 64 });
            try testArgs(@Vector(3, u1023), @Vector(3, u65), .{ 0, 1, 1 << 64 });
            try testArgs(@Vector(3, u1024), @Vector(3, u65), .{ 0, 1, 1 << 64 });
            try testArgs(@Vector(3, u1025), @Vector(3, u65), .{ 0, 1, 1 << 64 });

            try testArgs(@Vector(3, i7), @Vector(3, i95), .{ -1 << 94, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, i95), .{ -1 << 94, -1, 0 });
            try testArgs(@Vector(3, i9), @Vector(3, i95), .{ -1 << 94, -1, 0 });
            try testArgs(@Vector(3, i15), @Vector(3, i95), .{ -1 << 94, -1, 0 });
            try testArgs(@Vector(3, i16), @Vector(3, i95), .{ -1 << 94, -1, 0 });
            try testArgs(@Vector(3, i17), @Vector(3, i95), .{ -1 << 94, -1, 0 });
            try testArgs(@Vector(3, i31), @Vector(3, i95), .{ -1 << 94, -1, 0 });
            try testArgs(@Vector(3, i32), @Vector(3, i95), .{ -1 << 94, -1, 0 });
            try testArgs(@Vector(3, i33), @Vector(3, i95), .{ -1 << 94, -1, 0 });
            try testArgs(@Vector(3, i63), @Vector(3, i95), .{ -1 << 94, -1, 0 });
            try testArgs(@Vector(3, i64), @Vector(3, i95), .{ -1 << 94, -1, 0 });
            try testArgs(@Vector(3, i65), @Vector(3, i95), .{ -1 << 94, -1, 0 });
            try testArgs(@Vector(3, i127), @Vector(3, i95), .{ -1 << 94, -1, 0 });
            try testArgs(@Vector(3, i128), @Vector(3, i95), .{ -1 << 94, -1, 0 });
            try testArgs(@Vector(3, i129), @Vector(3, i95), .{ -1 << 94, -1, 0 });
            try testArgs(@Vector(3, i255), @Vector(3, i95), .{ -1 << 94, -1, 0 });
            try testArgs(@Vector(3, i256), @Vector(3, i95), .{ -1 << 94, -1, 0 });
            try testArgs(@Vector(3, i257), @Vector(3, i95), .{ -1 << 94, -1, 0 });
            try testArgs(@Vector(3, i511), @Vector(3, i95), .{ -1 << 94, -1, 0 });
            try testArgs(@Vector(3, i512), @Vector(3, i95), .{ -1 << 94, -1, 0 });
            try testArgs(@Vector(3, i513), @Vector(3, i95), .{ -1 << 94, -1, 0 });
            try testArgs(@Vector(3, i1023), @Vector(3, i95), .{ -1 << 94, -1, 0 });
            try testArgs(@Vector(3, i1024), @Vector(3, i95), .{ -1 << 94, -1, 0 });
            try testArgs(@Vector(3, i1025), @Vector(3, i95), .{ -1 << 94, -1, 0 });
            try testArgs(@Vector(3, u7), @Vector(3, u95), .{ 0, 1, 1 << 94 });
            try testArgs(@Vector(3, u8), @Vector(3, u95), .{ 0, 1, 1 << 94 });
            try testArgs(@Vector(3, u9), @Vector(3, u95), .{ 0, 1, 1 << 94 });
            try testArgs(@Vector(3, u15), @Vector(3, u95), .{ 0, 1, 1 << 94 });
            try testArgs(@Vector(3, u16), @Vector(3, u95), .{ 0, 1, 1 << 94 });
            try testArgs(@Vector(3, u17), @Vector(3, u95), .{ 0, 1, 1 << 94 });
            try testArgs(@Vector(3, u31), @Vector(3, u95), .{ 0, 1, 1 << 94 });
            try testArgs(@Vector(3, u32), @Vector(3, u95), .{ 0, 1, 1 << 94 });
            try testArgs(@Vector(3, u33), @Vector(3, u95), .{ 0, 1, 1 << 94 });
            try testArgs(@Vector(3, u63), @Vector(3, u95), .{ 0, 1, 1 << 94 });
            try testArgs(@Vector(3, u64), @Vector(3, u95), .{ 0, 1, 1 << 94 });
            try testArgs(@Vector(3, u65), @Vector(3, u95), .{ 0, 1, 1 << 94 });
            try testArgs(@Vector(3, u127), @Vector(3, u95), .{ 0, 1, 1 << 94 });
            try testArgs(@Vector(3, u128), @Vector(3, u95), .{ 0, 1, 1 << 94 });
            try testArgs(@Vector(3, u129), @Vector(3, u95), .{ 0, 1, 1 << 94 });
            try testArgs(@Vector(3, u255), @Vector(3, u95), .{ 0, 1, 1 << 94 });
            try testArgs(@Vector(3, u256), @Vector(3, u95), .{ 0, 1, 1 << 94 });
            try testArgs(@Vector(3, u257), @Vector(3, u95), .{ 0, 1, 1 << 94 });
            try testArgs(@Vector(3, u511), @Vector(3, u95), .{ 0, 1, 1 << 94 });
            try testArgs(@Vector(3, u512), @Vector(3, u95), .{ 0, 1, 1 << 94 });
            try testArgs(@Vector(3, u513), @Vector(3, u95), .{ 0, 1, 1 << 94 });
            try testArgs(@Vector(3, u1023), @Vector(3, u95), .{ 0, 1, 1 << 94 });
            try testArgs(@Vector(3, u1024), @Vector(3, u95), .{ 0, 1, 1 << 94 });
            try testArgs(@Vector(3, u1025), @Vector(3, u95), .{ 0, 1, 1 << 94 });

            try testArgs(@Vector(3, i7), @Vector(3, i96), .{ -1 << 95, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, i96), .{ -1 << 95, -1, 0 });
            try testArgs(@Vector(3, i9), @Vector(3, i96), .{ -1 << 95, -1, 0 });
            try testArgs(@Vector(3, i15), @Vector(3, i96), .{ -1 << 95, -1, 0 });
            try testArgs(@Vector(3, i16), @Vector(3, i96), .{ -1 << 95, -1, 0 });
            try testArgs(@Vector(3, i17), @Vector(3, i96), .{ -1 << 95, -1, 0 });
            try testArgs(@Vector(3, i31), @Vector(3, i96), .{ -1 << 95, -1, 0 });
            try testArgs(@Vector(3, i32), @Vector(3, i96), .{ -1 << 95, -1, 0 });
            try testArgs(@Vector(3, i33), @Vector(3, i96), .{ -1 << 95, -1, 0 });
            try testArgs(@Vector(3, i63), @Vector(3, i96), .{ -1 << 95, -1, 0 });
            try testArgs(@Vector(3, i64), @Vector(3, i96), .{ -1 << 95, -1, 0 });
            try testArgs(@Vector(3, i65), @Vector(3, i96), .{ -1 << 95, -1, 0 });
            try testArgs(@Vector(3, i127), @Vector(3, i96), .{ -1 << 95, -1, 0 });
            try testArgs(@Vector(3, i128), @Vector(3, i96), .{ -1 << 95, -1, 0 });
            try testArgs(@Vector(3, i129), @Vector(3, i96), .{ -1 << 95, -1, 0 });
            try testArgs(@Vector(3, i255), @Vector(3, i96), .{ -1 << 95, -1, 0 });
            try testArgs(@Vector(3, i256), @Vector(3, i96), .{ -1 << 95, -1, 0 });
            try testArgs(@Vector(3, i257), @Vector(3, i96), .{ -1 << 95, -1, 0 });
            try testArgs(@Vector(3, i511), @Vector(3, i96), .{ -1 << 95, -1, 0 });
            try testArgs(@Vector(3, i512), @Vector(3, i96), .{ -1 << 95, -1, 0 });
            try testArgs(@Vector(3, i513), @Vector(3, i96), .{ -1 << 95, -1, 0 });
            try testArgs(@Vector(3, i1023), @Vector(3, i96), .{ -1 << 95, -1, 0 });
            try testArgs(@Vector(3, i1024), @Vector(3, i96), .{ -1 << 95, -1, 0 });
            try testArgs(@Vector(3, i1025), @Vector(3, i96), .{ -1 << 95, -1, 0 });
            try testArgs(@Vector(3, u7), @Vector(3, u96), .{ 0, 1, 1 << 95 });
            try testArgs(@Vector(3, u8), @Vector(3, u96), .{ 0, 1, 1 << 95 });
            try testArgs(@Vector(3, u9), @Vector(3, u96), .{ 0, 1, 1 << 95 });
            try testArgs(@Vector(3, u15), @Vector(3, u96), .{ 0, 1, 1 << 95 });
            try testArgs(@Vector(3, u16), @Vector(3, u96), .{ 0, 1, 1 << 95 });
            try testArgs(@Vector(3, u17), @Vector(3, u96), .{ 0, 1, 1 << 95 });
            try testArgs(@Vector(3, u31), @Vector(3, u96), .{ 0, 1, 1 << 95 });
            try testArgs(@Vector(3, u32), @Vector(3, u96), .{ 0, 1, 1 << 95 });
            try testArgs(@Vector(3, u33), @Vector(3, u96), .{ 0, 1, 1 << 95 });
            try testArgs(@Vector(3, u63), @Vector(3, u96), .{ 0, 1, 1 << 95 });
            try testArgs(@Vector(3, u64), @Vector(3, u96), .{ 0, 1, 1 << 95 });
            try testArgs(@Vector(3, u65), @Vector(3, u96), .{ 0, 1, 1 << 95 });
            try testArgs(@Vector(3, u127), @Vector(3, u96), .{ 0, 1, 1 << 95 });
            try testArgs(@Vector(3, u128), @Vector(3, u96), .{ 0, 1, 1 << 95 });
            try testArgs(@Vector(3, u129), @Vector(3, u96), .{ 0, 1, 1 << 95 });
            try testArgs(@Vector(3, u255), @Vector(3, u96), .{ 0, 1, 1 << 95 });
            try testArgs(@Vector(3, u256), @Vector(3, u96), .{ 0, 1, 1 << 95 });
            try testArgs(@Vector(3, u257), @Vector(3, u96), .{ 0, 1, 1 << 95 });
            try testArgs(@Vector(3, u511), @Vector(3, u96), .{ 0, 1, 1 << 95 });
            try testArgs(@Vector(3, u512), @Vector(3, u96), .{ 0, 1, 1 << 95 });
            try testArgs(@Vector(3, u513), @Vector(3, u96), .{ 0, 1, 1 << 95 });
            try testArgs(@Vector(3, u1023), @Vector(3, u96), .{ 0, 1, 1 << 95 });
            try testArgs(@Vector(3, u1024), @Vector(3, u96), .{ 0, 1, 1 << 95 });
            try testArgs(@Vector(3, u1025), @Vector(3, u96), .{ 0, 1, 1 << 95 });

            try testArgs(@Vector(3, i7), @Vector(3, i97), .{ -1 << 96, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, i97), .{ -1 << 96, -1, 0 });
            try testArgs(@Vector(3, i9), @Vector(3, i97), .{ -1 << 96, -1, 0 });
            try testArgs(@Vector(3, i15), @Vector(3, i97), .{ -1 << 96, -1, 0 });
            try testArgs(@Vector(3, i16), @Vector(3, i97), .{ -1 << 96, -1, 0 });
            try testArgs(@Vector(3, i17), @Vector(3, i97), .{ -1 << 96, -1, 0 });
            try testArgs(@Vector(3, i31), @Vector(3, i97), .{ -1 << 96, -1, 0 });
            try testArgs(@Vector(3, i32), @Vector(3, i97), .{ -1 << 96, -1, 0 });
            try testArgs(@Vector(3, i33), @Vector(3, i97), .{ -1 << 96, -1, 0 });
            try testArgs(@Vector(3, i63), @Vector(3, i97), .{ -1 << 96, -1, 0 });
            try testArgs(@Vector(3, i64), @Vector(3, i97), .{ -1 << 96, -1, 0 });
            try testArgs(@Vector(3, i65), @Vector(3, i97), .{ -1 << 96, -1, 0 });
            try testArgs(@Vector(3, i127), @Vector(3, i97), .{ -1 << 96, -1, 0 });
            try testArgs(@Vector(3, i128), @Vector(3, i97), .{ -1 << 96, -1, 0 });
            try testArgs(@Vector(3, i129), @Vector(3, i97), .{ -1 << 96, -1, 0 });
            try testArgs(@Vector(3, i255), @Vector(3, i97), .{ -1 << 96, -1, 0 });
            try testArgs(@Vector(3, i256), @Vector(3, i97), .{ -1 << 96, -1, 0 });
            try testArgs(@Vector(3, i257), @Vector(3, i97), .{ -1 << 96, -1, 0 });
            try testArgs(@Vector(3, i511), @Vector(3, i97), .{ -1 << 96, -1, 0 });
            try testArgs(@Vector(3, i512), @Vector(3, i97), .{ -1 << 96, -1, 0 });
            try testArgs(@Vector(3, i513), @Vector(3, i97), .{ -1 << 96, -1, 0 });
            try testArgs(@Vector(3, i1023), @Vector(3, i97), .{ -1 << 96, -1, 0 });
            try testArgs(@Vector(3, i1024), @Vector(3, i97), .{ -1 << 96, -1, 0 });
            try testArgs(@Vector(3, i1025), @Vector(3, i97), .{ -1 << 96, -1, 0 });
            try testArgs(@Vector(3, u7), @Vector(3, u97), .{ 0, 1, 1 << 96 });
            try testArgs(@Vector(3, u8), @Vector(3, u97), .{ 0, 1, 1 << 96 });
            try testArgs(@Vector(3, u9), @Vector(3, u97), .{ 0, 1, 1 << 96 });
            try testArgs(@Vector(3, u15), @Vector(3, u97), .{ 0, 1, 1 << 96 });
            try testArgs(@Vector(3, u16), @Vector(3, u97), .{ 0, 1, 1 << 96 });
            try testArgs(@Vector(3, u17), @Vector(3, u97), .{ 0, 1, 1 << 96 });
            try testArgs(@Vector(3, u31), @Vector(3, u97), .{ 0, 1, 1 << 96 });
            try testArgs(@Vector(3, u32), @Vector(3, u97), .{ 0, 1, 1 << 96 });
            try testArgs(@Vector(3, u33), @Vector(3, u97), .{ 0, 1, 1 << 96 });
            try testArgs(@Vector(3, u63), @Vector(3, u97), .{ 0, 1, 1 << 96 });
            try testArgs(@Vector(3, u64), @Vector(3, u97), .{ 0, 1, 1 << 96 });
            try testArgs(@Vector(3, u65), @Vector(3, u97), .{ 0, 1, 1 << 96 });
            try testArgs(@Vector(3, u127), @Vector(3, u97), .{ 0, 1, 1 << 96 });
            try testArgs(@Vector(3, u128), @Vector(3, u97), .{ 0, 1, 1 << 96 });
            try testArgs(@Vector(3, u129), @Vector(3, u97), .{ 0, 1, 1 << 96 });
            try testArgs(@Vector(3, u255), @Vector(3, u97), .{ 0, 1, 1 << 96 });
            try testArgs(@Vector(3, u256), @Vector(3, u97), .{ 0, 1, 1 << 96 });
            try testArgs(@Vector(3, u257), @Vector(3, u97), .{ 0, 1, 1 << 96 });
            try testArgs(@Vector(3, u511), @Vector(3, u97), .{ 0, 1, 1 << 96 });
            try testArgs(@Vector(3, u512), @Vector(3, u97), .{ 0, 1, 1 << 96 });
            try testArgs(@Vector(3, u513), @Vector(3, u97), .{ 0, 1, 1 << 96 });
            try testArgs(@Vector(3, u1023), @Vector(3, u97), .{ 0, 1, 1 << 96 });
            try testArgs(@Vector(3, u1024), @Vector(3, u97), .{ 0, 1, 1 << 96 });
            try testArgs(@Vector(3, u1025), @Vector(3, u97), .{ 0, 1, 1 << 96 });

            try testArgs(@Vector(3, i7), @Vector(3, i127), .{ -1 << 126, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, i127), .{ -1 << 126, -1, 0 });
            try testArgs(@Vector(3, i9), @Vector(3, i127), .{ -1 << 126, -1, 0 });
            try testArgs(@Vector(3, i15), @Vector(3, i127), .{ -1 << 126, -1, 0 });
            try testArgs(@Vector(3, i16), @Vector(3, i127), .{ -1 << 126, -1, 0 });
            try testArgs(@Vector(3, i17), @Vector(3, i127), .{ -1 << 126, -1, 0 });
            try testArgs(@Vector(3, i31), @Vector(3, i127), .{ -1 << 126, -1, 0 });
            try testArgs(@Vector(3, i32), @Vector(3, i127), .{ -1 << 126, -1, 0 });
            try testArgs(@Vector(3, i33), @Vector(3, i127), .{ -1 << 126, -1, 0 });
            try testArgs(@Vector(3, i63), @Vector(3, i127), .{ -1 << 126, -1, 0 });
            try testArgs(@Vector(3, i64), @Vector(3, i127), .{ -1 << 126, -1, 0 });
            try testArgs(@Vector(3, i65), @Vector(3, i127), .{ -1 << 126, -1, 0 });
            try testArgs(@Vector(3, i127), @Vector(3, i127), .{ -1 << 126, -1, 0 });
            try testArgs(@Vector(3, i128), @Vector(3, i127), .{ -1 << 126, -1, 0 });
            try testArgs(@Vector(3, i129), @Vector(3, i127), .{ -1 << 126, -1, 0 });
            try testArgs(@Vector(3, i255), @Vector(3, i127), .{ -1 << 126, -1, 0 });
            try testArgs(@Vector(3, i256), @Vector(3, i127), .{ -1 << 126, -1, 0 });
            try testArgs(@Vector(3, i257), @Vector(3, i127), .{ -1 << 126, -1, 0 });
            try testArgs(@Vector(3, i511), @Vector(3, i127), .{ -1 << 126, -1, 0 });
            try testArgs(@Vector(3, i512), @Vector(3, i127), .{ -1 << 126, -1, 0 });
            try testArgs(@Vector(3, i513), @Vector(3, i127), .{ -1 << 126, -1, 0 });
            try testArgs(@Vector(3, i1023), @Vector(3, i127), .{ -1 << 126, -1, 0 });
            try testArgs(@Vector(3, i1024), @Vector(3, i127), .{ -1 << 126, -1, 0 });
            try testArgs(@Vector(3, i1025), @Vector(3, i127), .{ -1 << 126, -1, 0 });
            try testArgs(@Vector(3, u7), @Vector(3, u127), .{ 0, 1, 1 << 126 });
            try testArgs(@Vector(3, u8), @Vector(3, u127), .{ 0, 1, 1 << 126 });
            try testArgs(@Vector(3, u9), @Vector(3, u127), .{ 0, 1, 1 << 126 });
            try testArgs(@Vector(3, u15), @Vector(3, u127), .{ 0, 1, 1 << 126 });
            try testArgs(@Vector(3, u16), @Vector(3, u127), .{ 0, 1, 1 << 126 });
            try testArgs(@Vector(3, u17), @Vector(3, u127), .{ 0, 1, 1 << 126 });
            try testArgs(@Vector(3, u31), @Vector(3, u127), .{ 0, 1, 1 << 126 });
            try testArgs(@Vector(3, u32), @Vector(3, u127), .{ 0, 1, 1 << 126 });
            try testArgs(@Vector(3, u33), @Vector(3, u127), .{ 0, 1, 1 << 126 });
            try testArgs(@Vector(3, u63), @Vector(3, u127), .{ 0, 1, 1 << 126 });
            try testArgs(@Vector(3, u64), @Vector(3, u127), .{ 0, 1, 1 << 126 });
            try testArgs(@Vector(3, u65), @Vector(3, u127), .{ 0, 1, 1 << 126 });
            try testArgs(@Vector(3, u127), @Vector(3, u127), .{ 0, 1, 1 << 126 });
            try testArgs(@Vector(3, u128), @Vector(3, u127), .{ 0, 1, 1 << 126 });
            try testArgs(@Vector(3, u129), @Vector(3, u127), .{ 0, 1, 1 << 126 });
            try testArgs(@Vector(3, u255), @Vector(3, u127), .{ 0, 1, 1 << 126 });
            try testArgs(@Vector(3, u256), @Vector(3, u127), .{ 0, 1, 1 << 126 });
            try testArgs(@Vector(3, u257), @Vector(3, u127), .{ 0, 1, 1 << 126 });
            try testArgs(@Vector(3, u511), @Vector(3, u127), .{ 0, 1, 1 << 126 });
            try testArgs(@Vector(3, u512), @Vector(3, u127), .{ 0, 1, 1 << 126 });
            try testArgs(@Vector(3, u513), @Vector(3, u127), .{ 0, 1, 1 << 126 });
            try testArgs(@Vector(3, u1023), @Vector(3, u127), .{ 0, 1, 1 << 126 });
            try testArgs(@Vector(3, u1024), @Vector(3, u127), .{ 0, 1, 1 << 126 });
            try testArgs(@Vector(3, u1025), @Vector(3, u127), .{ 0, 1, 1 << 126 });

            try testArgs(@Vector(3, i7), @Vector(3, i128), .{ -1 << 127, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, i128), .{ -1 << 127, -1, 0 });
            try testArgs(@Vector(3, i9), @Vector(3, i128), .{ -1 << 127, -1, 0 });
            try testArgs(@Vector(3, i15), @Vector(3, i128), .{ -1 << 127, -1, 0 });
            try testArgs(@Vector(3, i16), @Vector(3, i128), .{ -1 << 127, -1, 0 });
            try testArgs(@Vector(3, i17), @Vector(3, i128), .{ -1 << 127, -1, 0 });
            try testArgs(@Vector(3, i31), @Vector(3, i128), .{ -1 << 127, -1, 0 });
            try testArgs(@Vector(3, i32), @Vector(3, i128), .{ -1 << 127, -1, 0 });
            try testArgs(@Vector(3, i33), @Vector(3, i128), .{ -1 << 127, -1, 0 });
            try testArgs(@Vector(3, i63), @Vector(3, i128), .{ -1 << 127, -1, 0 });
            try testArgs(@Vector(3, i64), @Vector(3, i128), .{ -1 << 127, -1, 0 });
            try testArgs(@Vector(3, i65), @Vector(3, i128), .{ -1 << 127, -1, 0 });
            try testArgs(@Vector(3, i127), @Vector(3, i128), .{ -1 << 127, -1, 0 });
            try testArgs(@Vector(3, i128), @Vector(3, i128), .{ -1 << 127, -1, 0 });
            try testArgs(@Vector(3, i129), @Vector(3, i128), .{ -1 << 127, -1, 0 });
            try testArgs(@Vector(3, i255), @Vector(3, i128), .{ -1 << 127, -1, 0 });
            try testArgs(@Vector(3, i256), @Vector(3, i128), .{ -1 << 127, -1, 0 });
            try testArgs(@Vector(3, i257), @Vector(3, i128), .{ -1 << 127, -1, 0 });
            try testArgs(@Vector(3, i511), @Vector(3, i128), .{ -1 << 127, -1, 0 });
            try testArgs(@Vector(3, i512), @Vector(3, i128), .{ -1 << 127, -1, 0 });
            try testArgs(@Vector(3, i513), @Vector(3, i128), .{ -1 << 127, -1, 0 });
            try testArgs(@Vector(3, i1023), @Vector(3, i128), .{ -1 << 127, -1, 0 });
            try testArgs(@Vector(3, i1024), @Vector(3, i128), .{ -1 << 127, -1, 0 });
            try testArgs(@Vector(3, i1025), @Vector(3, i128), .{ -1 << 127, -1, 0 });
            try testArgs(@Vector(3, u7), @Vector(3, u128), .{ 0, 1, 1 << 127 });
            try testArgs(@Vector(3, u8), @Vector(3, u128), .{ 0, 1, 1 << 127 });
            try testArgs(@Vector(3, u9), @Vector(3, u128), .{ 0, 1, 1 << 127 });
            try testArgs(@Vector(3, u15), @Vector(3, u128), .{ 0, 1, 1 << 127 });
            try testArgs(@Vector(3, u16), @Vector(3, u128), .{ 0, 1, 1 << 127 });
            try testArgs(@Vector(3, u17), @Vector(3, u128), .{ 0, 1, 1 << 127 });
            try testArgs(@Vector(3, u31), @Vector(3, u128), .{ 0, 1, 1 << 127 });
            try testArgs(@Vector(3, u32), @Vector(3, u128), .{ 0, 1, 1 << 127 });
            try testArgs(@Vector(3, u33), @Vector(3, u128), .{ 0, 1, 1 << 127 });
            try testArgs(@Vector(3, u63), @Vector(3, u128), .{ 0, 1, 1 << 127 });
            try testArgs(@Vector(3, u64), @Vector(3, u128), .{ 0, 1, 1 << 127 });
            try testArgs(@Vector(3, u65), @Vector(3, u128), .{ 0, 1, 1 << 127 });
            try testArgs(@Vector(3, u127), @Vector(3, u128), .{ 0, 1, 1 << 127 });
            try testArgs(@Vector(3, u128), @Vector(3, u128), .{ 0, 1, 1 << 127 });
            try testArgs(@Vector(3, u129), @Vector(3, u128), .{ 0, 1, 1 << 127 });
            try testArgs(@Vector(3, u255), @Vector(3, u128), .{ 0, 1, 1 << 127 });
            try testArgs(@Vector(3, u256), @Vector(3, u128), .{ 0, 1, 1 << 127 });
            try testArgs(@Vector(3, u257), @Vector(3, u128), .{ 0, 1, 1 << 127 });
            try testArgs(@Vector(3, u511), @Vector(3, u128), .{ 0, 1, 1 << 127 });
            try testArgs(@Vector(3, u512), @Vector(3, u128), .{ 0, 1, 1 << 127 });
            try testArgs(@Vector(3, u513), @Vector(3, u128), .{ 0, 1, 1 << 127 });
            try testArgs(@Vector(3, u1023), @Vector(3, u128), .{ 0, 1, 1 << 127 });
            try testArgs(@Vector(3, u1024), @Vector(3, u128), .{ 0, 1, 1 << 127 });
            try testArgs(@Vector(3, u1025), @Vector(3, u128), .{ 0, 1, 1 << 127 });

            try testArgs(@Vector(3, i7), @Vector(3, i129), .{ -1 << 128, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, i129), .{ -1 << 128, -1, 0 });
            try testArgs(@Vector(3, i9), @Vector(3, i129), .{ -1 << 128, -1, 0 });
            try testArgs(@Vector(3, i15), @Vector(3, i129), .{ -1 << 128, -1, 0 });
            try testArgs(@Vector(3, i16), @Vector(3, i129), .{ -1 << 128, -1, 0 });
            try testArgs(@Vector(3, i17), @Vector(3, i129), .{ -1 << 128, -1, 0 });
            try testArgs(@Vector(3, i31), @Vector(3, i129), .{ -1 << 128, -1, 0 });
            try testArgs(@Vector(3, i32), @Vector(3, i129), .{ -1 << 128, -1, 0 });
            try testArgs(@Vector(3, i33), @Vector(3, i129), .{ -1 << 128, -1, 0 });
            try testArgs(@Vector(3, i63), @Vector(3, i129), .{ -1 << 128, -1, 0 });
            try testArgs(@Vector(3, i64), @Vector(3, i129), .{ -1 << 128, -1, 0 });
            try testArgs(@Vector(3, i65), @Vector(3, i129), .{ -1 << 128, -1, 0 });
            try testArgs(@Vector(3, i127), @Vector(3, i129), .{ -1 << 128, -1, 0 });
            try testArgs(@Vector(3, i128), @Vector(3, i129), .{ -1 << 128, -1, 0 });
            try testArgs(@Vector(3, i129), @Vector(3, i129), .{ -1 << 128, -1, 0 });
            try testArgs(@Vector(3, i255), @Vector(3, i129), .{ -1 << 128, -1, 0 });
            try testArgs(@Vector(3, i256), @Vector(3, i129), .{ -1 << 128, -1, 0 });
            try testArgs(@Vector(3, i257), @Vector(3, i129), .{ -1 << 128, -1, 0 });
            try testArgs(@Vector(3, i511), @Vector(3, i129), .{ -1 << 128, -1, 0 });
            try testArgs(@Vector(3, i512), @Vector(3, i129), .{ -1 << 128, -1, 0 });
            try testArgs(@Vector(3, i513), @Vector(3, i129), .{ -1 << 128, -1, 0 });
            try testArgs(@Vector(3, i1023), @Vector(3, i129), .{ -1 << 128, -1, 0 });
            try testArgs(@Vector(3, i1024), @Vector(3, i129), .{ -1 << 128, -1, 0 });
            try testArgs(@Vector(3, i1025), @Vector(3, i129), .{ -1 << 128, -1, 0 });
            try testArgs(@Vector(3, u7), @Vector(3, u129), .{ 0, 1, 1 << 128 });
            try testArgs(@Vector(3, u8), @Vector(3, u129), .{ 0, 1, 1 << 128 });
            try testArgs(@Vector(3, u9), @Vector(3, u129), .{ 0, 1, 1 << 128 });
            try testArgs(@Vector(3, u15), @Vector(3, u129), .{ 0, 1, 1 << 128 });
            try testArgs(@Vector(3, u16), @Vector(3, u129), .{ 0, 1, 1 << 128 });
            try testArgs(@Vector(3, u17), @Vector(3, u129), .{ 0, 1, 1 << 128 });
            try testArgs(@Vector(3, u31), @Vector(3, u129), .{ 0, 1, 1 << 128 });
            try testArgs(@Vector(3, u32), @Vector(3, u129), .{ 0, 1, 1 << 128 });
            try testArgs(@Vector(3, u33), @Vector(3, u129), .{ 0, 1, 1 << 128 });
            try testArgs(@Vector(3, u63), @Vector(3, u129), .{ 0, 1, 1 << 128 });
            try testArgs(@Vector(3, u64), @Vector(3, u129), .{ 0, 1, 1 << 128 });
            try testArgs(@Vector(3, u65), @Vector(3, u129), .{ 0, 1, 1 << 128 });
            try testArgs(@Vector(3, u127), @Vector(3, u129), .{ 0, 1, 1 << 128 });
            try testArgs(@Vector(3, u128), @Vector(3, u129), .{ 0, 1, 1 << 128 });
            try testArgs(@Vector(3, u129), @Vector(3, u129), .{ 0, 1, 1 << 128 });
            try testArgs(@Vector(3, u255), @Vector(3, u129), .{ 0, 1, 1 << 128 });
            try testArgs(@Vector(3, u256), @Vector(3, u129), .{ 0, 1, 1 << 128 });
            try testArgs(@Vector(3, u257), @Vector(3, u129), .{ 0, 1, 1 << 128 });
            try testArgs(@Vector(3, u511), @Vector(3, u129), .{ 0, 1, 1 << 128 });
            try testArgs(@Vector(3, u512), @Vector(3, u129), .{ 0, 1, 1 << 128 });
            try testArgs(@Vector(3, u513), @Vector(3, u129), .{ 0, 1, 1 << 128 });
            try testArgs(@Vector(3, u1023), @Vector(3, u129), .{ 0, 1, 1 << 128 });
            try testArgs(@Vector(3, u1024), @Vector(3, u129), .{ 0, 1, 1 << 128 });
            try testArgs(@Vector(3, u1025), @Vector(3, u129), .{ 0, 1, 1 << 128 });

            try testArgs(@Vector(3, i7), @Vector(3, i159), .{ -1 << 158, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, i159), .{ -1 << 158, -1, 0 });
            try testArgs(@Vector(3, i9), @Vector(3, i159), .{ -1 << 158, -1, 0 });
            try testArgs(@Vector(3, i15), @Vector(3, i159), .{ -1 << 158, -1, 0 });
            try testArgs(@Vector(3, i16), @Vector(3, i159), .{ -1 << 158, -1, 0 });
            try testArgs(@Vector(3, i17), @Vector(3, i159), .{ -1 << 158, -1, 0 });
            try testArgs(@Vector(3, i31), @Vector(3, i159), .{ -1 << 158, -1, 0 });
            try testArgs(@Vector(3, i32), @Vector(3, i159), .{ -1 << 158, -1, 0 });
            try testArgs(@Vector(3, i33), @Vector(3, i159), .{ -1 << 158, -1, 0 });
            try testArgs(@Vector(3, i63), @Vector(3, i159), .{ -1 << 158, -1, 0 });
            try testArgs(@Vector(3, i64), @Vector(3, i159), .{ -1 << 158, -1, 0 });
            try testArgs(@Vector(3, i65), @Vector(3, i159), .{ -1 << 158, -1, 0 });
            try testArgs(@Vector(3, i127), @Vector(3, i159), .{ -1 << 158, -1, 0 });
            try testArgs(@Vector(3, i128), @Vector(3, i159), .{ -1 << 158, -1, 0 });
            try testArgs(@Vector(3, i129), @Vector(3, i159), .{ -1 << 158, -1, 0 });
            try testArgs(@Vector(3, i255), @Vector(3, i159), .{ -1 << 158, -1, 0 });
            try testArgs(@Vector(3, i256), @Vector(3, i159), .{ -1 << 158, -1, 0 });
            try testArgs(@Vector(3, i257), @Vector(3, i159), .{ -1 << 158, -1, 0 });
            try testArgs(@Vector(3, i511), @Vector(3, i159), .{ -1 << 158, -1, 0 });
            try testArgs(@Vector(3, i512), @Vector(3, i159), .{ -1 << 158, -1, 0 });
            try testArgs(@Vector(3, i513), @Vector(3, i159), .{ -1 << 158, -1, 0 });
            try testArgs(@Vector(3, i1023), @Vector(3, i159), .{ -1 << 158, -1, 0 });
            try testArgs(@Vector(3, i1024), @Vector(3, i159), .{ -1 << 158, -1, 0 });
            try testArgs(@Vector(3, i1025), @Vector(3, i159), .{ -1 << 158, -1, 0 });
            try testArgs(@Vector(3, u7), @Vector(3, u159), .{ 0, 1, 1 << 158 });
            try testArgs(@Vector(3, u8), @Vector(3, u159), .{ 0, 1, 1 << 158 });
            try testArgs(@Vector(3, u9), @Vector(3, u159), .{ 0, 1, 1 << 158 });
            try testArgs(@Vector(3, u15), @Vector(3, u159), .{ 0, 1, 1 << 158 });
            try testArgs(@Vector(3, u16), @Vector(3, u159), .{ 0, 1, 1 << 158 });
            try testArgs(@Vector(3, u17), @Vector(3, u159), .{ 0, 1, 1 << 158 });
            try testArgs(@Vector(3, u31), @Vector(3, u159), .{ 0, 1, 1 << 158 });
            try testArgs(@Vector(3, u32), @Vector(3, u159), .{ 0, 1, 1 << 158 });
            try testArgs(@Vector(3, u33), @Vector(3, u159), .{ 0, 1, 1 << 158 });
            try testArgs(@Vector(3, u63), @Vector(3, u159), .{ 0, 1, 1 << 158 });
            try testArgs(@Vector(3, u64), @Vector(3, u159), .{ 0, 1, 1 << 158 });
            try testArgs(@Vector(3, u65), @Vector(3, u159), .{ 0, 1, 1 << 158 });
            try testArgs(@Vector(3, u127), @Vector(3, u159), .{ 0, 1, 1 << 158 });
            try testArgs(@Vector(3, u128), @Vector(3, u159), .{ 0, 1, 1 << 158 });
            try testArgs(@Vector(3, u129), @Vector(3, u159), .{ 0, 1, 1 << 158 });
            try testArgs(@Vector(3, u255), @Vector(3, u159), .{ 0, 1, 1 << 158 });
            try testArgs(@Vector(3, u256), @Vector(3, u159), .{ 0, 1, 1 << 158 });
            try testArgs(@Vector(3, u257), @Vector(3, u159), .{ 0, 1, 1 << 158 });
            try testArgs(@Vector(3, u511), @Vector(3, u159), .{ 0, 1, 1 << 158 });
            try testArgs(@Vector(3, u512), @Vector(3, u159), .{ 0, 1, 1 << 158 });
            try testArgs(@Vector(3, u513), @Vector(3, u159), .{ 0, 1, 1 << 158 });
            try testArgs(@Vector(3, u1023), @Vector(3, u159), .{ 0, 1, 1 << 158 });
            try testArgs(@Vector(3, u1024), @Vector(3, u159), .{ 0, 1, 1 << 158 });
            try testArgs(@Vector(3, u1025), @Vector(3, u159), .{ 0, 1, 1 << 158 });

            try testArgs(@Vector(3, i7), @Vector(3, i160), .{ -1 << 159, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, i160), .{ -1 << 159, -1, 0 });
            try testArgs(@Vector(3, i9), @Vector(3, i160), .{ -1 << 159, -1, 0 });
            try testArgs(@Vector(3, i15), @Vector(3, i160), .{ -1 << 159, -1, 0 });
            try testArgs(@Vector(3, i16), @Vector(3, i160), .{ -1 << 159, -1, 0 });
            try testArgs(@Vector(3, i17), @Vector(3, i160), .{ -1 << 159, -1, 0 });
            try testArgs(@Vector(3, i31), @Vector(3, i160), .{ -1 << 159, -1, 0 });
            try testArgs(@Vector(3, i32), @Vector(3, i160), .{ -1 << 159, -1, 0 });
            try testArgs(@Vector(3, i33), @Vector(3, i160), .{ -1 << 159, -1, 0 });
            try testArgs(@Vector(3, i63), @Vector(3, i160), .{ -1 << 159, -1, 0 });
            try testArgs(@Vector(3, i64), @Vector(3, i160), .{ -1 << 159, -1, 0 });
            try testArgs(@Vector(3, i65), @Vector(3, i160), .{ -1 << 159, -1, 0 });
            try testArgs(@Vector(3, i127), @Vector(3, i160), .{ -1 << 159, -1, 0 });
            try testArgs(@Vector(3, i128), @Vector(3, i160), .{ -1 << 159, -1, 0 });
            try testArgs(@Vector(3, i129), @Vector(3, i160), .{ -1 << 159, -1, 0 });
            try testArgs(@Vector(3, i255), @Vector(3, i160), .{ -1 << 159, -1, 0 });
            try testArgs(@Vector(3, i256), @Vector(3, i160), .{ -1 << 159, -1, 0 });
            try testArgs(@Vector(3, i257), @Vector(3, i160), .{ -1 << 159, -1, 0 });
            try testArgs(@Vector(3, i511), @Vector(3, i160), .{ -1 << 159, -1, 0 });
            try testArgs(@Vector(3, i512), @Vector(3, i160), .{ -1 << 159, -1, 0 });
            try testArgs(@Vector(3, i513), @Vector(3, i160), .{ -1 << 159, -1, 0 });
            try testArgs(@Vector(3, i1023), @Vector(3, i160), .{ -1 << 159, -1, 0 });
            try testArgs(@Vector(3, i1024), @Vector(3, i160), .{ -1 << 159, -1, 0 });
            try testArgs(@Vector(3, i1025), @Vector(3, i160), .{ -1 << 159, -1, 0 });
            try testArgs(@Vector(3, u7), @Vector(3, u160), .{ 0, 1, 1 << 159 });
            try testArgs(@Vector(3, u8), @Vector(3, u160), .{ 0, 1, 1 << 159 });
            try testArgs(@Vector(3, u9), @Vector(3, u160), .{ 0, 1, 1 << 159 });
            try testArgs(@Vector(3, u15), @Vector(3, u160), .{ 0, 1, 1 << 159 });
            try testArgs(@Vector(3, u16), @Vector(3, u160), .{ 0, 1, 1 << 159 });
            try testArgs(@Vector(3, u17), @Vector(3, u160), .{ 0, 1, 1 << 159 });
            try testArgs(@Vector(3, u31), @Vector(3, u160), .{ 0, 1, 1 << 159 });
            try testArgs(@Vector(3, u32), @Vector(3, u160), .{ 0, 1, 1 << 159 });
            try testArgs(@Vector(3, u33), @Vector(3, u160), .{ 0, 1, 1 << 159 });
            try testArgs(@Vector(3, u63), @Vector(3, u160), .{ 0, 1, 1 << 159 });
            try testArgs(@Vector(3, u64), @Vector(3, u160), .{ 0, 1, 1 << 159 });
            try testArgs(@Vector(3, u65), @Vector(3, u160), .{ 0, 1, 1 << 159 });
            try testArgs(@Vector(3, u127), @Vector(3, u160), .{ 0, 1, 1 << 159 });
            try testArgs(@Vector(3, u128), @Vector(3, u160), .{ 0, 1, 1 << 159 });
            try testArgs(@Vector(3, u129), @Vector(3, u160), .{ 0, 1, 1 << 159 });
            try testArgs(@Vector(3, u255), @Vector(3, u160), .{ 0, 1, 1 << 159 });
            try testArgs(@Vector(3, u256), @Vector(3, u160), .{ 0, 1, 1 << 159 });
            try testArgs(@Vector(3, u257), @Vector(3, u160), .{ 0, 1, 1 << 159 });
            try testArgs(@Vector(3, u511), @Vector(3, u160), .{ 0, 1, 1 << 159 });
            try testArgs(@Vector(3, u512), @Vector(3, u160), .{ 0, 1, 1 << 159 });
            try testArgs(@Vector(3, u513), @Vector(3, u160), .{ 0, 1, 1 << 159 });
            try testArgs(@Vector(3, u1023), @Vector(3, u160), .{ 0, 1, 1 << 159 });
            try testArgs(@Vector(3, u1024), @Vector(3, u160), .{ 0, 1, 1 << 159 });
            try testArgs(@Vector(3, u1025), @Vector(3, u160), .{ 0, 1, 1 << 159 });

            try testArgs(@Vector(3, i7), @Vector(3, i161), .{ -1 << 160, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, i161), .{ -1 << 160, -1, 0 });
            try testArgs(@Vector(3, i9), @Vector(3, i161), .{ -1 << 160, -1, 0 });
            try testArgs(@Vector(3, i15), @Vector(3, i161), .{ -1 << 160, -1, 0 });
            try testArgs(@Vector(3, i16), @Vector(3, i161), .{ -1 << 160, -1, 0 });
            try testArgs(@Vector(3, i17), @Vector(3, i161), .{ -1 << 160, -1, 0 });
            try testArgs(@Vector(3, i31), @Vector(3, i161), .{ -1 << 160, -1, 0 });
            try testArgs(@Vector(3, i32), @Vector(3, i161), .{ -1 << 160, -1, 0 });
            try testArgs(@Vector(3, i33), @Vector(3, i161), .{ -1 << 160, -1, 0 });
            try testArgs(@Vector(3, i63), @Vector(3, i161), .{ -1 << 160, -1, 0 });
            try testArgs(@Vector(3, i64), @Vector(3, i161), .{ -1 << 160, -1, 0 });
            try testArgs(@Vector(3, i65), @Vector(3, i161), .{ -1 << 160, -1, 0 });
            try testArgs(@Vector(3, i127), @Vector(3, i161), .{ -1 << 160, -1, 0 });
            try testArgs(@Vector(3, i128), @Vector(3, i161), .{ -1 << 160, -1, 0 });
            try testArgs(@Vector(3, i129), @Vector(3, i161), .{ -1 << 160, -1, 0 });
            try testArgs(@Vector(3, i255), @Vector(3, i161), .{ -1 << 160, -1, 0 });
            try testArgs(@Vector(3, i256), @Vector(3, i161), .{ -1 << 160, -1, 0 });
            try testArgs(@Vector(3, i257), @Vector(3, i161), .{ -1 << 160, -1, 0 });
            try testArgs(@Vector(3, i511), @Vector(3, i161), .{ -1 << 160, -1, 0 });
            try testArgs(@Vector(3, i512), @Vector(3, i161), .{ -1 << 160, -1, 0 });
            try testArgs(@Vector(3, i513), @Vector(3, i161), .{ -1 << 160, -1, 0 });
            try testArgs(@Vector(3, i1023), @Vector(3, i161), .{ -1 << 160, -1, 0 });
            try testArgs(@Vector(3, i1024), @Vector(3, i161), .{ -1 << 160, -1, 0 });
            try testArgs(@Vector(3, i1025), @Vector(3, i161), .{ -1 << 160, -1, 0 });
            try testArgs(@Vector(3, u7), @Vector(3, u161), .{ 0, 1, 1 << 160 });
            try testArgs(@Vector(3, u8), @Vector(3, u161), .{ 0, 1, 1 << 160 });
            try testArgs(@Vector(3, u9), @Vector(3, u161), .{ 0, 1, 1 << 160 });
            try testArgs(@Vector(3, u15), @Vector(3, u161), .{ 0, 1, 1 << 160 });
            try testArgs(@Vector(3, u16), @Vector(3, u161), .{ 0, 1, 1 << 160 });
            try testArgs(@Vector(3, u17), @Vector(3, u161), .{ 0, 1, 1 << 160 });
            try testArgs(@Vector(3, u31), @Vector(3, u161), .{ 0, 1, 1 << 160 });
            try testArgs(@Vector(3, u32), @Vector(3, u161), .{ 0, 1, 1 << 160 });
            try testArgs(@Vector(3, u33), @Vector(3, u161), .{ 0, 1, 1 << 160 });
            try testArgs(@Vector(3, u63), @Vector(3, u161), .{ 0, 1, 1 << 160 });
            try testArgs(@Vector(3, u64), @Vector(3, u161), .{ 0, 1, 1 << 160 });
            try testArgs(@Vector(3, u65), @Vector(3, u161), .{ 0, 1, 1 << 160 });
            try testArgs(@Vector(3, u127), @Vector(3, u161), .{ 0, 1, 1 << 160 });
            try testArgs(@Vector(3, u128), @Vector(3, u161), .{ 0, 1, 1 << 160 });
            try testArgs(@Vector(3, u129), @Vector(3, u161), .{ 0, 1, 1 << 160 });
            try testArgs(@Vector(3, u255), @Vector(3, u161), .{ 0, 1, 1 << 160 });
            try testArgs(@Vector(3, u256), @Vector(3, u161), .{ 0, 1, 1 << 160 });
            try testArgs(@Vector(3, u257), @Vector(3, u161), .{ 0, 1, 1 << 160 });
            try testArgs(@Vector(3, u511), @Vector(3, u161), .{ 0, 1, 1 << 160 });
            try testArgs(@Vector(3, u512), @Vector(3, u161), .{ 0, 1, 1 << 160 });
            try testArgs(@Vector(3, u513), @Vector(3, u161), .{ 0, 1, 1 << 160 });
            try testArgs(@Vector(3, u1023), @Vector(3, u161), .{ 0, 1, 1 << 160 });
            try testArgs(@Vector(3, u1024), @Vector(3, u161), .{ 0, 1, 1 << 160 });
            try testArgs(@Vector(3, u1025), @Vector(3, u161), .{ 0, 1, 1 << 160 });

            try testArgs(@Vector(3, i7), @Vector(3, i191), .{ -1 << 190, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, i191), .{ -1 << 190, -1, 0 });
            try testArgs(@Vector(3, i9), @Vector(3, i191), .{ -1 << 190, -1, 0 });
            try testArgs(@Vector(3, i15), @Vector(3, i191), .{ -1 << 190, -1, 0 });
            try testArgs(@Vector(3, i16), @Vector(3, i191), .{ -1 << 190, -1, 0 });
            try testArgs(@Vector(3, i17), @Vector(3, i191), .{ -1 << 190, -1, 0 });
            try testArgs(@Vector(3, i31), @Vector(3, i191), .{ -1 << 190, -1, 0 });
            try testArgs(@Vector(3, i32), @Vector(3, i191), .{ -1 << 190, -1, 0 });
            try testArgs(@Vector(3, i33), @Vector(3, i191), .{ -1 << 190, -1, 0 });
            try testArgs(@Vector(3, i63), @Vector(3, i191), .{ -1 << 190, -1, 0 });
            try testArgs(@Vector(3, i64), @Vector(3, i191), .{ -1 << 190, -1, 0 });
            try testArgs(@Vector(3, i65), @Vector(3, i191), .{ -1 << 190, -1, 0 });
            try testArgs(@Vector(3, i127), @Vector(3, i191), .{ -1 << 190, -1, 0 });
            try testArgs(@Vector(3, i128), @Vector(3, i191), .{ -1 << 190, -1, 0 });
            try testArgs(@Vector(3, i129), @Vector(3, i191), .{ -1 << 190, -1, 0 });
            try testArgs(@Vector(3, i255), @Vector(3, i191), .{ -1 << 190, -1, 0 });
            try testArgs(@Vector(3, i256), @Vector(3, i191), .{ -1 << 190, -1, 0 });
            try testArgs(@Vector(3, i257), @Vector(3, i191), .{ -1 << 190, -1, 0 });
            try testArgs(@Vector(3, i511), @Vector(3, i191), .{ -1 << 190, -1, 0 });
            try testArgs(@Vector(3, i512), @Vector(3, i191), .{ -1 << 190, -1, 0 });
            try testArgs(@Vector(3, i513), @Vector(3, i191), .{ -1 << 190, -1, 0 });
            try testArgs(@Vector(3, i1023), @Vector(3, i191), .{ -1 << 190, -1, 0 });
            try testArgs(@Vector(3, i1024), @Vector(3, i191), .{ -1 << 190, -1, 0 });
            try testArgs(@Vector(3, i1025), @Vector(3, i191), .{ -1 << 190, -1, 0 });
            try testArgs(@Vector(3, u7), @Vector(3, u191), .{ 0, 1, 1 << 190 });
            try testArgs(@Vector(3, u8), @Vector(3, u191), .{ 0, 1, 1 << 190 });
            try testArgs(@Vector(3, u9), @Vector(3, u191), .{ 0, 1, 1 << 190 });
            try testArgs(@Vector(3, u15), @Vector(3, u191), .{ 0, 1, 1 << 190 });
            try testArgs(@Vector(3, u16), @Vector(3, u191), .{ 0, 1, 1 << 190 });
            try testArgs(@Vector(3, u17), @Vector(3, u191), .{ 0, 1, 1 << 190 });
            try testArgs(@Vector(3, u31), @Vector(3, u191), .{ 0, 1, 1 << 190 });
            try testArgs(@Vector(3, u32), @Vector(3, u191), .{ 0, 1, 1 << 190 });
            try testArgs(@Vector(3, u33), @Vector(3, u191), .{ 0, 1, 1 << 190 });
            try testArgs(@Vector(3, u63), @Vector(3, u191), .{ 0, 1, 1 << 190 });
            try testArgs(@Vector(3, u64), @Vector(3, u191), .{ 0, 1, 1 << 190 });
            try testArgs(@Vector(3, u65), @Vector(3, u191), .{ 0, 1, 1 << 190 });
            try testArgs(@Vector(3, u127), @Vector(3, u191), .{ 0, 1, 1 << 190 });
            try testArgs(@Vector(3, u128), @Vector(3, u191), .{ 0, 1, 1 << 190 });
            try testArgs(@Vector(3, u129), @Vector(3, u191), .{ 0, 1, 1 << 190 });
            try testArgs(@Vector(3, u255), @Vector(3, u191), .{ 0, 1, 1 << 190 });
            try testArgs(@Vector(3, u256), @Vector(3, u191), .{ 0, 1, 1 << 190 });
            try testArgs(@Vector(3, u257), @Vector(3, u191), .{ 0, 1, 1 << 190 });
            try testArgs(@Vector(3, u511), @Vector(3, u191), .{ 0, 1, 1 << 190 });
            try testArgs(@Vector(3, u512), @Vector(3, u191), .{ 0, 1, 1 << 190 });
            try testArgs(@Vector(3, u513), @Vector(3, u191), .{ 0, 1, 1 << 190 });
            try testArgs(@Vector(3, u1023), @Vector(3, u191), .{ 0, 1, 1 << 190 });
            try testArgs(@Vector(3, u1024), @Vector(3, u191), .{ 0, 1, 1 << 190 });
            try testArgs(@Vector(3, u1025), @Vector(3, u191), .{ 0, 1, 1 << 190 });

            try testArgs(@Vector(3, i7), @Vector(3, i192), .{ -1 << 191, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, i192), .{ -1 << 191, -1, 0 });
            try testArgs(@Vector(3, i9), @Vector(3, i192), .{ -1 << 191, -1, 0 });
            try testArgs(@Vector(3, i15), @Vector(3, i192), .{ -1 << 191, -1, 0 });
            try testArgs(@Vector(3, i16), @Vector(3, i192), .{ -1 << 191, -1, 0 });
            try testArgs(@Vector(3, i17), @Vector(3, i192), .{ -1 << 191, -1, 0 });
            try testArgs(@Vector(3, i31), @Vector(3, i192), .{ -1 << 191, -1, 0 });
            try testArgs(@Vector(3, i32), @Vector(3, i192), .{ -1 << 191, -1, 0 });
            try testArgs(@Vector(3, i33), @Vector(3, i192), .{ -1 << 191, -1, 0 });
            try testArgs(@Vector(3, i63), @Vector(3, i192), .{ -1 << 191, -1, 0 });
            try testArgs(@Vector(3, i64), @Vector(3, i192), .{ -1 << 191, -1, 0 });
            try testArgs(@Vector(3, i65), @Vector(3, i192), .{ -1 << 191, -1, 0 });
            try testArgs(@Vector(3, i127), @Vector(3, i192), .{ -1 << 191, -1, 0 });
            try testArgs(@Vector(3, i128), @Vector(3, i192), .{ -1 << 191, -1, 0 });
            try testArgs(@Vector(3, i129), @Vector(3, i192), .{ -1 << 191, -1, 0 });
            try testArgs(@Vector(3, i255), @Vector(3, i192), .{ -1 << 191, -1, 0 });
            try testArgs(@Vector(3, i256), @Vector(3, i192), .{ -1 << 191, -1, 0 });
            try testArgs(@Vector(3, i257), @Vector(3, i192), .{ -1 << 191, -1, 0 });
            try testArgs(@Vector(3, i511), @Vector(3, i192), .{ -1 << 191, -1, 0 });
            try testArgs(@Vector(3, i512), @Vector(3, i192), .{ -1 << 191, -1, 0 });
            try testArgs(@Vector(3, i513), @Vector(3, i192), .{ -1 << 191, -1, 0 });
            try testArgs(@Vector(3, i1023), @Vector(3, i192), .{ -1 << 191, -1, 0 });
            try testArgs(@Vector(3, i1024), @Vector(3, i192), .{ -1 << 191, -1, 0 });
            try testArgs(@Vector(3, i1025), @Vector(3, i192), .{ -1 << 191, -1, 0 });
            try testArgs(@Vector(3, u7), @Vector(3, u192), .{ 0, 1, 1 << 191 });
            try testArgs(@Vector(3, u8), @Vector(3, u192), .{ 0, 1, 1 << 191 });
            try testArgs(@Vector(3, u9), @Vector(3, u192), .{ 0, 1, 1 << 191 });
            try testArgs(@Vector(3, u15), @Vector(3, u192), .{ 0, 1, 1 << 191 });
            try testArgs(@Vector(3, u16), @Vector(3, u192), .{ 0, 1, 1 << 191 });
            try testArgs(@Vector(3, u17), @Vector(3, u192), .{ 0, 1, 1 << 191 });
            try testArgs(@Vector(3, u31), @Vector(3, u192), .{ 0, 1, 1 << 191 });
            try testArgs(@Vector(3, u32), @Vector(3, u192), .{ 0, 1, 1 << 191 });
            try testArgs(@Vector(3, u33), @Vector(3, u192), .{ 0, 1, 1 << 191 });
            try testArgs(@Vector(3, u63), @Vector(3, u192), .{ 0, 1, 1 << 191 });
            try testArgs(@Vector(3, u64), @Vector(3, u192), .{ 0, 1, 1 << 191 });
            try testArgs(@Vector(3, u65), @Vector(3, u192), .{ 0, 1, 1 << 191 });
            try testArgs(@Vector(3, u127), @Vector(3, u192), .{ 0, 1, 1 << 191 });
            try testArgs(@Vector(3, u128), @Vector(3, u192), .{ 0, 1, 1 << 191 });
            try testArgs(@Vector(3, u129), @Vector(3, u192), .{ 0, 1, 1 << 191 });
            try testArgs(@Vector(3, u255), @Vector(3, u192), .{ 0, 1, 1 << 191 });
            try testArgs(@Vector(3, u256), @Vector(3, u192), .{ 0, 1, 1 << 191 });
            try testArgs(@Vector(3, u257), @Vector(3, u192), .{ 0, 1, 1 << 191 });
            try testArgs(@Vector(3, u511), @Vector(3, u192), .{ 0, 1, 1 << 191 });
            try testArgs(@Vector(3, u512), @Vector(3, u192), .{ 0, 1, 1 << 191 });
            try testArgs(@Vector(3, u513), @Vector(3, u192), .{ 0, 1, 1 << 191 });
            try testArgs(@Vector(3, u1023), @Vector(3, u192), .{ 0, 1, 1 << 191 });
            try testArgs(@Vector(3, u1024), @Vector(3, u192), .{ 0, 1, 1 << 191 });
            try testArgs(@Vector(3, u1025), @Vector(3, u192), .{ 0, 1, 1 << 191 });

            try testArgs(@Vector(3, i7), @Vector(3, i193), .{ -1 << 192, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, i193), .{ -1 << 192, -1, 0 });
            try testArgs(@Vector(3, i9), @Vector(3, i193), .{ -1 << 192, -1, 0 });
            try testArgs(@Vector(3, i15), @Vector(3, i193), .{ -1 << 192, -1, 0 });
            try testArgs(@Vector(3, i16), @Vector(3, i193), .{ -1 << 192, -1, 0 });
            try testArgs(@Vector(3, i17), @Vector(3, i193), .{ -1 << 192, -1, 0 });
            try testArgs(@Vector(3, i31), @Vector(3, i193), .{ -1 << 192, -1, 0 });
            try testArgs(@Vector(3, i32), @Vector(3, i193), .{ -1 << 192, -1, 0 });
            try testArgs(@Vector(3, i33), @Vector(3, i193), .{ -1 << 192, -1, 0 });
            try testArgs(@Vector(3, i63), @Vector(3, i193), .{ -1 << 192, -1, 0 });
            try testArgs(@Vector(3, i64), @Vector(3, i193), .{ -1 << 192, -1, 0 });
            try testArgs(@Vector(3, i65), @Vector(3, i193), .{ -1 << 192, -1, 0 });
            try testArgs(@Vector(3, i127), @Vector(3, i193), .{ -1 << 192, -1, 0 });
            try testArgs(@Vector(3, i128), @Vector(3, i193), .{ -1 << 192, -1, 0 });
            try testArgs(@Vector(3, i129), @Vector(3, i193), .{ -1 << 192, -1, 0 });
            try testArgs(@Vector(3, i255), @Vector(3, i193), .{ -1 << 192, -1, 0 });
            try testArgs(@Vector(3, i256), @Vector(3, i193), .{ -1 << 192, -1, 0 });
            try testArgs(@Vector(3, i257), @Vector(3, i193), .{ -1 << 192, -1, 0 });
            try testArgs(@Vector(3, i511), @Vector(3, i193), .{ -1 << 192, -1, 0 });
            try testArgs(@Vector(3, i512), @Vector(3, i193), .{ -1 << 192, -1, 0 });
            try testArgs(@Vector(3, i513), @Vector(3, i193), .{ -1 << 192, -1, 0 });
            try testArgs(@Vector(3, i1023), @Vector(3, i193), .{ -1 << 192, -1, 0 });
            try testArgs(@Vector(3, i1024), @Vector(3, i193), .{ -1 << 192, -1, 0 });
            try testArgs(@Vector(3, i1025), @Vector(3, i193), .{ -1 << 192, -1, 0 });
            try testArgs(@Vector(3, u7), @Vector(3, u193), .{ 0, 1, 1 << 192 });
            try testArgs(@Vector(3, u8), @Vector(3, u193), .{ 0, 1, 1 << 192 });
            try testArgs(@Vector(3, u9), @Vector(3, u193), .{ 0, 1, 1 << 192 });
            try testArgs(@Vector(3, u15), @Vector(3, u193), .{ 0, 1, 1 << 192 });
            try testArgs(@Vector(3, u16), @Vector(3, u193), .{ 0, 1, 1 << 192 });
            try testArgs(@Vector(3, u17), @Vector(3, u193), .{ 0, 1, 1 << 192 });
            try testArgs(@Vector(3, u31), @Vector(3, u193), .{ 0, 1, 1 << 192 });
            try testArgs(@Vector(3, u32), @Vector(3, u193), .{ 0, 1, 1 << 192 });
            try testArgs(@Vector(3, u33), @Vector(3, u193), .{ 0, 1, 1 << 192 });
            try testArgs(@Vector(3, u63), @Vector(3, u193), .{ 0, 1, 1 << 192 });
            try testArgs(@Vector(3, u64), @Vector(3, u193), .{ 0, 1, 1 << 192 });
            try testArgs(@Vector(3, u65), @Vector(3, u193), .{ 0, 1, 1 << 192 });
            try testArgs(@Vector(3, u127), @Vector(3, u193), .{ 0, 1, 1 << 192 });
            try testArgs(@Vector(3, u128), @Vector(3, u193), .{ 0, 1, 1 << 192 });
            try testArgs(@Vector(3, u129), @Vector(3, u193), .{ 0, 1, 1 << 192 });
            try testArgs(@Vector(3, u255), @Vector(3, u193), .{ 0, 1, 1 << 192 });
            try testArgs(@Vector(3, u256), @Vector(3, u193), .{ 0, 1, 1 << 192 });
            try testArgs(@Vector(3, u257), @Vector(3, u193), .{ 0, 1, 1 << 192 });
            try testArgs(@Vector(3, u511), @Vector(3, u193), .{ 0, 1, 1 << 192 });
            try testArgs(@Vector(3, u512), @Vector(3, u193), .{ 0, 1, 1 << 192 });
            try testArgs(@Vector(3, u513), @Vector(3, u193), .{ 0, 1, 1 << 192 });
            try testArgs(@Vector(3, u1023), @Vector(3, u193), .{ 0, 1, 1 << 192 });
            try testArgs(@Vector(3, u1024), @Vector(3, u193), .{ 0, 1, 1 << 192 });
            try testArgs(@Vector(3, u1025), @Vector(3, u193), .{ 0, 1, 1 << 192 });

            try testArgs(@Vector(3, i7), @Vector(3, i223), .{ -1 << 222, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, i223), .{ -1 << 222, -1, 0 });
            try testArgs(@Vector(3, i9), @Vector(3, i223), .{ -1 << 222, -1, 0 });
            try testArgs(@Vector(3, i15), @Vector(3, i223), .{ -1 << 222, -1, 0 });
            try testArgs(@Vector(3, i16), @Vector(3, i223), .{ -1 << 222, -1, 0 });
            try testArgs(@Vector(3, i17), @Vector(3, i223), .{ -1 << 222, -1, 0 });
            try testArgs(@Vector(3, i31), @Vector(3, i223), .{ -1 << 222, -1, 0 });
            try testArgs(@Vector(3, i32), @Vector(3, i223), .{ -1 << 222, -1, 0 });
            try testArgs(@Vector(3, i33), @Vector(3, i223), .{ -1 << 222, -1, 0 });
            try testArgs(@Vector(3, i63), @Vector(3, i223), .{ -1 << 222, -1, 0 });
            try testArgs(@Vector(3, i64), @Vector(3, i223), .{ -1 << 222, -1, 0 });
            try testArgs(@Vector(3, i65), @Vector(3, i223), .{ -1 << 222, -1, 0 });
            try testArgs(@Vector(3, i127), @Vector(3, i223), .{ -1 << 222, -1, 0 });
            try testArgs(@Vector(3, i128), @Vector(3, i223), .{ -1 << 222, -1, 0 });
            try testArgs(@Vector(3, i129), @Vector(3, i223), .{ -1 << 222, -1, 0 });
            try testArgs(@Vector(3, i255), @Vector(3, i223), .{ -1 << 222, -1, 0 });
            try testArgs(@Vector(3, i256), @Vector(3, i223), .{ -1 << 222, -1, 0 });
            try testArgs(@Vector(3, i257), @Vector(3, i223), .{ -1 << 222, -1, 0 });
            try testArgs(@Vector(3, i511), @Vector(3, i223), .{ -1 << 222, -1, 0 });
            try testArgs(@Vector(3, i512), @Vector(3, i223), .{ -1 << 222, -1, 0 });
            try testArgs(@Vector(3, i513), @Vector(3, i223), .{ -1 << 222, -1, 0 });
            try testArgs(@Vector(3, i1023), @Vector(3, i223), .{ -1 << 222, -1, 0 });
            try testArgs(@Vector(3, i1024), @Vector(3, i223), .{ -1 << 222, -1, 0 });
            try testArgs(@Vector(3, i1025), @Vector(3, i223), .{ -1 << 222, -1, 0 });
            try testArgs(@Vector(3, u7), @Vector(3, u223), .{ 0, 1, 1 << 222 });
            try testArgs(@Vector(3, u8), @Vector(3, u223), .{ 0, 1, 1 << 222 });
            try testArgs(@Vector(3, u9), @Vector(3, u223), .{ 0, 1, 1 << 222 });
            try testArgs(@Vector(3, u15), @Vector(3, u223), .{ 0, 1, 1 << 222 });
            try testArgs(@Vector(3, u16), @Vector(3, u223), .{ 0, 1, 1 << 222 });
            try testArgs(@Vector(3, u17), @Vector(3, u223), .{ 0, 1, 1 << 222 });
            try testArgs(@Vector(3, u31), @Vector(3, u223), .{ 0, 1, 1 << 222 });
            try testArgs(@Vector(3, u32), @Vector(3, u223), .{ 0, 1, 1 << 222 });
            try testArgs(@Vector(3, u33), @Vector(3, u223), .{ 0, 1, 1 << 222 });
            try testArgs(@Vector(3, u63), @Vector(3, u223), .{ 0, 1, 1 << 222 });
            try testArgs(@Vector(3, u64), @Vector(3, u223), .{ 0, 1, 1 << 222 });
            try testArgs(@Vector(3, u65), @Vector(3, u223), .{ 0, 1, 1 << 222 });
            try testArgs(@Vector(3, u127), @Vector(3, u223), .{ 0, 1, 1 << 222 });
            try testArgs(@Vector(3, u128), @Vector(3, u223), .{ 0, 1, 1 << 222 });
            try testArgs(@Vector(3, u129), @Vector(3, u223), .{ 0, 1, 1 << 222 });
            try testArgs(@Vector(3, u255), @Vector(3, u223), .{ 0, 1, 1 << 222 });
            try testArgs(@Vector(3, u256), @Vector(3, u223), .{ 0, 1, 1 << 222 });
            try testArgs(@Vector(3, u257), @Vector(3, u223), .{ 0, 1, 1 << 222 });
            try testArgs(@Vector(3, u511), @Vector(3, u223), .{ 0, 1, 1 << 222 });
            try testArgs(@Vector(3, u512), @Vector(3, u223), .{ 0, 1, 1 << 222 });
            try testArgs(@Vector(3, u513), @Vector(3, u223), .{ 0, 1, 1 << 222 });
            try testArgs(@Vector(3, u1023), @Vector(3, u223), .{ 0, 1, 1 << 222 });
            try testArgs(@Vector(3, u1024), @Vector(3, u223), .{ 0, 1, 1 << 222 });
            try testArgs(@Vector(3, u1025), @Vector(3, u223), .{ 0, 1, 1 << 222 });

            try testArgs(@Vector(3, i7), @Vector(3, i224), .{ -1 << 223, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, i224), .{ -1 << 223, -1, 0 });
            try testArgs(@Vector(3, i9), @Vector(3, i224), .{ -1 << 223, -1, 0 });
            try testArgs(@Vector(3, i15), @Vector(3, i224), .{ -1 << 223, -1, 0 });
            try testArgs(@Vector(3, i16), @Vector(3, i224), .{ -1 << 223, -1, 0 });
            try testArgs(@Vector(3, i17), @Vector(3, i224), .{ -1 << 223, -1, 0 });
            try testArgs(@Vector(3, i31), @Vector(3, i224), .{ -1 << 223, -1, 0 });
            try testArgs(@Vector(3, i32), @Vector(3, i224), .{ -1 << 223, -1, 0 });
            try testArgs(@Vector(3, i33), @Vector(3, i224), .{ -1 << 223, -1, 0 });
            try testArgs(@Vector(3, i63), @Vector(3, i224), .{ -1 << 223, -1, 0 });
            try testArgs(@Vector(3, i64), @Vector(3, i224), .{ -1 << 223, -1, 0 });
            try testArgs(@Vector(3, i65), @Vector(3, i224), .{ -1 << 223, -1, 0 });
            try testArgs(@Vector(3, i127), @Vector(3, i224), .{ -1 << 223, -1, 0 });
            try testArgs(@Vector(3, i128), @Vector(3, i224), .{ -1 << 223, -1, 0 });
            try testArgs(@Vector(3, i129), @Vector(3, i224), .{ -1 << 223, -1, 0 });
            try testArgs(@Vector(3, i255), @Vector(3, i224), .{ -1 << 223, -1, 0 });
            try testArgs(@Vector(3, i256), @Vector(3, i224), .{ -1 << 223, -1, 0 });
            try testArgs(@Vector(3, i257), @Vector(3, i224), .{ -1 << 223, -1, 0 });
            try testArgs(@Vector(3, i511), @Vector(3, i224), .{ -1 << 223, -1, 0 });
            try testArgs(@Vector(3, i512), @Vector(3, i224), .{ -1 << 223, -1, 0 });
            try testArgs(@Vector(3, i513), @Vector(3, i224), .{ -1 << 223, -1, 0 });
            try testArgs(@Vector(3, i1023), @Vector(3, i224), .{ -1 << 223, -1, 0 });
            try testArgs(@Vector(3, i1024), @Vector(3, i224), .{ -1 << 223, -1, 0 });
            try testArgs(@Vector(3, i1025), @Vector(3, i224), .{ -1 << 223, -1, 0 });
            try testArgs(@Vector(3, u7), @Vector(3, u224), .{ 0, 1, 1 << 223 });
            try testArgs(@Vector(3, u8), @Vector(3, u224), .{ 0, 1, 1 << 223 });
            try testArgs(@Vector(3, u9), @Vector(3, u224), .{ 0, 1, 1 << 223 });
            try testArgs(@Vector(3, u15), @Vector(3, u224), .{ 0, 1, 1 << 223 });
            try testArgs(@Vector(3, u16), @Vector(3, u224), .{ 0, 1, 1 << 223 });
            try testArgs(@Vector(3, u17), @Vector(3, u224), .{ 0, 1, 1 << 223 });
            try testArgs(@Vector(3, u31), @Vector(3, u224), .{ 0, 1, 1 << 223 });
            try testArgs(@Vector(3, u32), @Vector(3, u224), .{ 0, 1, 1 << 223 });
            try testArgs(@Vector(3, u33), @Vector(3, u224), .{ 0, 1, 1 << 223 });
            try testArgs(@Vector(3, u63), @Vector(3, u224), .{ 0, 1, 1 << 223 });
            try testArgs(@Vector(3, u64), @Vector(3, u224), .{ 0, 1, 1 << 223 });
            try testArgs(@Vector(3, u65), @Vector(3, u224), .{ 0, 1, 1 << 223 });
            try testArgs(@Vector(3, u127), @Vector(3, u224), .{ 0, 1, 1 << 223 });
            try testArgs(@Vector(3, u128), @Vector(3, u224), .{ 0, 1, 1 << 223 });
            try testArgs(@Vector(3, u129), @Vector(3, u224), .{ 0, 1, 1 << 223 });
            try testArgs(@Vector(3, u255), @Vector(3, u224), .{ 0, 1, 1 << 223 });
            try testArgs(@Vector(3, u256), @Vector(3, u224), .{ 0, 1, 1 << 223 });
            try testArgs(@Vector(3, u257), @Vector(3, u224), .{ 0, 1, 1 << 223 });
            try testArgs(@Vector(3, u511), @Vector(3, u224), .{ 0, 1, 1 << 223 });
            try testArgs(@Vector(3, u512), @Vector(3, u224), .{ 0, 1, 1 << 223 });
            try testArgs(@Vector(3, u513), @Vector(3, u224), .{ 0, 1, 1 << 223 });
            try testArgs(@Vector(3, u1023), @Vector(3, u224), .{ 0, 1, 1 << 223 });
            try testArgs(@Vector(3, u1024), @Vector(3, u224), .{ 0, 1, 1 << 223 });
            try testArgs(@Vector(3, u1025), @Vector(3, u224), .{ 0, 1, 1 << 223 });

            try testArgs(@Vector(3, i7), @Vector(3, i225), .{ -1 << 224, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, i225), .{ -1 << 224, -1, 0 });
            try testArgs(@Vector(3, i9), @Vector(3, i225), .{ -1 << 224, -1, 0 });
            try testArgs(@Vector(3, i15), @Vector(3, i225), .{ -1 << 224, -1, 0 });
            try testArgs(@Vector(3, i16), @Vector(3, i225), .{ -1 << 224, -1, 0 });
            try testArgs(@Vector(3, i17), @Vector(3, i225), .{ -1 << 224, -1, 0 });
            try testArgs(@Vector(3, i31), @Vector(3, i225), .{ -1 << 224, -1, 0 });
            try testArgs(@Vector(3, i32), @Vector(3, i225), .{ -1 << 224, -1, 0 });
            try testArgs(@Vector(3, i33), @Vector(3, i225), .{ -1 << 224, -1, 0 });
            try testArgs(@Vector(3, i63), @Vector(3, i225), .{ -1 << 224, -1, 0 });
            try testArgs(@Vector(3, i64), @Vector(3, i225), .{ -1 << 224, -1, 0 });
            try testArgs(@Vector(3, i65), @Vector(3, i225), .{ -1 << 224, -1, 0 });
            try testArgs(@Vector(3, i127), @Vector(3, i225), .{ -1 << 224, -1, 0 });
            try testArgs(@Vector(3, i128), @Vector(3, i225), .{ -1 << 224, -1, 0 });
            try testArgs(@Vector(3, i129), @Vector(3, i225), .{ -1 << 224, -1, 0 });
            try testArgs(@Vector(3, i255), @Vector(3, i225), .{ -1 << 224, -1, 0 });
            try testArgs(@Vector(3, i256), @Vector(3, i225), .{ -1 << 224, -1, 0 });
            try testArgs(@Vector(3, i257), @Vector(3, i225), .{ -1 << 224, -1, 0 });
            try testArgs(@Vector(3, i511), @Vector(3, i225), .{ -1 << 224, -1, 0 });
            try testArgs(@Vector(3, i512), @Vector(3, i225), .{ -1 << 224, -1, 0 });
            try testArgs(@Vector(3, i513), @Vector(3, i225), .{ -1 << 224, -1, 0 });
            try testArgs(@Vector(3, i1023), @Vector(3, i225), .{ -1 << 224, -1, 0 });
            try testArgs(@Vector(3, i1024), @Vector(3, i225), .{ -1 << 224, -1, 0 });
            try testArgs(@Vector(3, i1025), @Vector(3, i225), .{ -1 << 224, -1, 0 });
            try testArgs(@Vector(3, u7), @Vector(3, u225), .{ 0, 1, 1 << 224 });
            try testArgs(@Vector(3, u8), @Vector(3, u225), .{ 0, 1, 1 << 224 });
            try testArgs(@Vector(3, u9), @Vector(3, u225), .{ 0, 1, 1 << 224 });
            try testArgs(@Vector(3, u15), @Vector(3, u225), .{ 0, 1, 1 << 224 });
            try testArgs(@Vector(3, u16), @Vector(3, u225), .{ 0, 1, 1 << 224 });
            try testArgs(@Vector(3, u17), @Vector(3, u225), .{ 0, 1, 1 << 224 });
            try testArgs(@Vector(3, u31), @Vector(3, u225), .{ 0, 1, 1 << 224 });
            try testArgs(@Vector(3, u32), @Vector(3, u225), .{ 0, 1, 1 << 224 });
            try testArgs(@Vector(3, u33), @Vector(3, u225), .{ 0, 1, 1 << 224 });
            try testArgs(@Vector(3, u63), @Vector(3, u225), .{ 0, 1, 1 << 224 });
            try testArgs(@Vector(3, u64), @Vector(3, u225), .{ 0, 1, 1 << 224 });
            try testArgs(@Vector(3, u65), @Vector(3, u225), .{ 0, 1, 1 << 224 });
            try testArgs(@Vector(3, u127), @Vector(3, u225), .{ 0, 1, 1 << 224 });
            try testArgs(@Vector(3, u128), @Vector(3, u225), .{ 0, 1, 1 << 224 });
            try testArgs(@Vector(3, u129), @Vector(3, u225), .{ 0, 1, 1 << 224 });
            try testArgs(@Vector(3, u255), @Vector(3, u225), .{ 0, 1, 1 << 224 });
            try testArgs(@Vector(3, u256), @Vector(3, u225), .{ 0, 1, 1 << 224 });
            try testArgs(@Vector(3, u257), @Vector(3, u225), .{ 0, 1, 1 << 224 });
            try testArgs(@Vector(3, u511), @Vector(3, u225), .{ 0, 1, 1 << 224 });
            try testArgs(@Vector(3, u512), @Vector(3, u225), .{ 0, 1, 1 << 224 });
            try testArgs(@Vector(3, u513), @Vector(3, u225), .{ 0, 1, 1 << 224 });
            try testArgs(@Vector(3, u1023), @Vector(3, u225), .{ 0, 1, 1 << 224 });
            try testArgs(@Vector(3, u1024), @Vector(3, u225), .{ 0, 1, 1 << 224 });
            try testArgs(@Vector(3, u1025), @Vector(3, u225), .{ 0, 1, 1 << 224 });

            try testArgs(@Vector(3, i7), @Vector(3, i255), .{ -1 << 254, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, i255), .{ -1 << 254, -1, 0 });
            try testArgs(@Vector(3, i9), @Vector(3, i255), .{ -1 << 254, -1, 0 });
            try testArgs(@Vector(3, i15), @Vector(3, i255), .{ -1 << 254, -1, 0 });
            try testArgs(@Vector(3, i16), @Vector(3, i255), .{ -1 << 254, -1, 0 });
            try testArgs(@Vector(3, i17), @Vector(3, i255), .{ -1 << 254, -1, 0 });
            try testArgs(@Vector(3, i31), @Vector(3, i255), .{ -1 << 254, -1, 0 });
            try testArgs(@Vector(3, i32), @Vector(3, i255), .{ -1 << 254, -1, 0 });
            try testArgs(@Vector(3, i33), @Vector(3, i255), .{ -1 << 254, -1, 0 });
            try testArgs(@Vector(3, i63), @Vector(3, i255), .{ -1 << 254, -1, 0 });
            try testArgs(@Vector(3, i64), @Vector(3, i255), .{ -1 << 254, -1, 0 });
            try testArgs(@Vector(3, i65), @Vector(3, i255), .{ -1 << 254, -1, 0 });
            try testArgs(@Vector(3, i127), @Vector(3, i255), .{ -1 << 254, -1, 0 });
            try testArgs(@Vector(3, i128), @Vector(3, i255), .{ -1 << 254, -1, 0 });
            try testArgs(@Vector(3, i129), @Vector(3, i255), .{ -1 << 254, -1, 0 });
            try testArgs(@Vector(3, i255), @Vector(3, i255), .{ -1 << 254, -1, 0 });
            try testArgs(@Vector(3, i256), @Vector(3, i255), .{ -1 << 254, -1, 0 });
            try testArgs(@Vector(3, i257), @Vector(3, i255), .{ -1 << 254, -1, 0 });
            try testArgs(@Vector(3, i511), @Vector(3, i255), .{ -1 << 254, -1, 0 });
            try testArgs(@Vector(3, i512), @Vector(3, i255), .{ -1 << 254, -1, 0 });
            try testArgs(@Vector(3, i513), @Vector(3, i255), .{ -1 << 254, -1, 0 });
            try testArgs(@Vector(3, i1023), @Vector(3, i255), .{ -1 << 254, -1, 0 });
            try testArgs(@Vector(3, i1024), @Vector(3, i255), .{ -1 << 254, -1, 0 });
            try testArgs(@Vector(3, i1025), @Vector(3, i255), .{ -1 << 254, -1, 0 });
            try testArgs(@Vector(3, u7), @Vector(3, u255), .{ 0, 1, 1 << 254 });
            try testArgs(@Vector(3, u8), @Vector(3, u255), .{ 0, 1, 1 << 254 });
            try testArgs(@Vector(3, u9), @Vector(3, u255), .{ 0, 1, 1 << 254 });
            try testArgs(@Vector(3, u15), @Vector(3, u255), .{ 0, 1, 1 << 254 });
            try testArgs(@Vector(3, u16), @Vector(3, u255), .{ 0, 1, 1 << 254 });
            try testArgs(@Vector(3, u17), @Vector(3, u255), .{ 0, 1, 1 << 254 });
            try testArgs(@Vector(3, u31), @Vector(3, u255), .{ 0, 1, 1 << 254 });
            try testArgs(@Vector(3, u32), @Vector(3, u255), .{ 0, 1, 1 << 254 });
            try testArgs(@Vector(3, u33), @Vector(3, u255), .{ 0, 1, 1 << 254 });
            try testArgs(@Vector(3, u63), @Vector(3, u255), .{ 0, 1, 1 << 254 });
            try testArgs(@Vector(3, u64), @Vector(3, u255), .{ 0, 1, 1 << 254 });
            try testArgs(@Vector(3, u65), @Vector(3, u255), .{ 0, 1, 1 << 254 });
            try testArgs(@Vector(3, u127), @Vector(3, u255), .{ 0, 1, 1 << 254 });
            try testArgs(@Vector(3, u128), @Vector(3, u255), .{ 0, 1, 1 << 254 });
            try testArgs(@Vector(3, u129), @Vector(3, u255), .{ 0, 1, 1 << 254 });
            try testArgs(@Vector(3, u255), @Vector(3, u255), .{ 0, 1, 1 << 254 });
            try testArgs(@Vector(3, u256), @Vector(3, u255), .{ 0, 1, 1 << 254 });
            try testArgs(@Vector(3, u257), @Vector(3, u255), .{ 0, 1, 1 << 254 });
            try testArgs(@Vector(3, u511), @Vector(3, u255), .{ 0, 1, 1 << 254 });
            try testArgs(@Vector(3, u512), @Vector(3, u255), .{ 0, 1, 1 << 254 });
            try testArgs(@Vector(3, u513), @Vector(3, u255), .{ 0, 1, 1 << 254 });
            try testArgs(@Vector(3, u1023), @Vector(3, u255), .{ 0, 1, 1 << 254 });
            try testArgs(@Vector(3, u1024), @Vector(3, u255), .{ 0, 1, 1 << 254 });
            try testArgs(@Vector(3, u1025), @Vector(3, u255), .{ 0, 1, 1 << 254 });

            try testArgs(@Vector(3, i7), @Vector(3, i256), .{ -1 << 255, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, i256), .{ -1 << 255, -1, 0 });
            try testArgs(@Vector(3, i9), @Vector(3, i256), .{ -1 << 255, -1, 0 });
            try testArgs(@Vector(3, i15), @Vector(3, i256), .{ -1 << 255, -1, 0 });
            try testArgs(@Vector(3, i16), @Vector(3, i256), .{ -1 << 255, -1, 0 });
            try testArgs(@Vector(3, i17), @Vector(3, i256), .{ -1 << 255, -1, 0 });
            try testArgs(@Vector(3, i31), @Vector(3, i256), .{ -1 << 255, -1, 0 });
            try testArgs(@Vector(3, i32), @Vector(3, i256), .{ -1 << 255, -1, 0 });
            try testArgs(@Vector(3, i33), @Vector(3, i256), .{ -1 << 255, -1, 0 });
            try testArgs(@Vector(3, i63), @Vector(3, i256), .{ -1 << 255, -1, 0 });
            try testArgs(@Vector(3, i64), @Vector(3, i256), .{ -1 << 255, -1, 0 });
            try testArgs(@Vector(3, i65), @Vector(3, i256), .{ -1 << 255, -1, 0 });
            try testArgs(@Vector(3, i127), @Vector(3, i256), .{ -1 << 255, -1, 0 });
            try testArgs(@Vector(3, i128), @Vector(3, i256), .{ -1 << 255, -1, 0 });
            try testArgs(@Vector(3, i129), @Vector(3, i256), .{ -1 << 255, -1, 0 });
            try testArgs(@Vector(3, i255), @Vector(3, i256), .{ -1 << 255, -1, 0 });
            try testArgs(@Vector(3, i256), @Vector(3, i256), .{ -1 << 255, -1, 0 });
            try testArgs(@Vector(3, i257), @Vector(3, i256), .{ -1 << 255, -1, 0 });
            try testArgs(@Vector(3, i511), @Vector(3, i256), .{ -1 << 255, -1, 0 });
            try testArgs(@Vector(3, i512), @Vector(3, i256), .{ -1 << 255, -1, 0 });
            try testArgs(@Vector(3, i513), @Vector(3, i256), .{ -1 << 255, -1, 0 });
            try testArgs(@Vector(3, i1023), @Vector(3, i256), .{ -1 << 255, -1, 0 });
            try testArgs(@Vector(3, i1024), @Vector(3, i256), .{ -1 << 255, -1, 0 });
            try testArgs(@Vector(3, i1025), @Vector(3, i256), .{ -1 << 255, -1, 0 });
            try testArgs(@Vector(3, u7), @Vector(3, u256), .{ 0, 1, 1 << 255 });
            try testArgs(@Vector(3, u8), @Vector(3, u256), .{ 0, 1, 1 << 255 });
            try testArgs(@Vector(3, u9), @Vector(3, u256), .{ 0, 1, 1 << 255 });
            try testArgs(@Vector(3, u15), @Vector(3, u256), .{ 0, 1, 1 << 255 });
            try testArgs(@Vector(3, u16), @Vector(3, u256), .{ 0, 1, 1 << 255 });
            try testArgs(@Vector(3, u17), @Vector(3, u256), .{ 0, 1, 1 << 255 });
            try testArgs(@Vector(3, u31), @Vector(3, u256), .{ 0, 1, 1 << 255 });
            try testArgs(@Vector(3, u32), @Vector(3, u256), .{ 0, 1, 1 << 255 });
            try testArgs(@Vector(3, u33), @Vector(3, u256), .{ 0, 1, 1 << 255 });
            try testArgs(@Vector(3, u63), @Vector(3, u256), .{ 0, 1, 1 << 255 });
            try testArgs(@Vector(3, u64), @Vector(3, u256), .{ 0, 1, 1 << 255 });
            try testArgs(@Vector(3, u65), @Vector(3, u256), .{ 0, 1, 1 << 255 });
            try testArgs(@Vector(3, u127), @Vector(3, u256), .{ 0, 1, 1 << 255 });
            try testArgs(@Vector(3, u128), @Vector(3, u256), .{ 0, 1, 1 << 255 });
            try testArgs(@Vector(3, u129), @Vector(3, u256), .{ 0, 1, 1 << 255 });
            try testArgs(@Vector(3, u255), @Vector(3, u256), .{ 0, 1, 1 << 255 });
            try testArgs(@Vector(3, u256), @Vector(3, u256), .{ 0, 1, 1 << 255 });
            try testArgs(@Vector(3, u257), @Vector(3, u256), .{ 0, 1, 1 << 255 });
            try testArgs(@Vector(3, u511), @Vector(3, u256), .{ 0, 1, 1 << 255 });
            try testArgs(@Vector(3, u512), @Vector(3, u256), .{ 0, 1, 1 << 255 });
            try testArgs(@Vector(3, u513), @Vector(3, u256), .{ 0, 1, 1 << 255 });
            try testArgs(@Vector(3, u1023), @Vector(3, u256), .{ 0, 1, 1 << 255 });
            try testArgs(@Vector(3, u1024), @Vector(3, u256), .{ 0, 1, 1 << 255 });
            try testArgs(@Vector(3, u1025), @Vector(3, u256), .{ 0, 1, 1 << 255 });

            try testArgs(@Vector(3, i7), @Vector(3, i257), .{ -1 << 256, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, i257), .{ -1 << 256, -1, 0 });
            try testArgs(@Vector(3, i9), @Vector(3, i257), .{ -1 << 256, -1, 0 });
            try testArgs(@Vector(3, i15), @Vector(3, i257), .{ -1 << 256, -1, 0 });
            try testArgs(@Vector(3, i16), @Vector(3, i257), .{ -1 << 256, -1, 0 });
            try testArgs(@Vector(3, i17), @Vector(3, i257), .{ -1 << 256, -1, 0 });
            try testArgs(@Vector(3, i31), @Vector(3, i257), .{ -1 << 256, -1, 0 });
            try testArgs(@Vector(3, i32), @Vector(3, i257), .{ -1 << 256, -1, 0 });
            try testArgs(@Vector(3, i33), @Vector(3, i257), .{ -1 << 256, -1, 0 });
            try testArgs(@Vector(3, i63), @Vector(3, i257), .{ -1 << 256, -1, 0 });
            try testArgs(@Vector(3, i64), @Vector(3, i257), .{ -1 << 256, -1, 0 });
            try testArgs(@Vector(3, i65), @Vector(3, i257), .{ -1 << 256, -1, 0 });
            try testArgs(@Vector(3, i127), @Vector(3, i257), .{ -1 << 256, -1, 0 });
            try testArgs(@Vector(3, i128), @Vector(3, i257), .{ -1 << 256, -1, 0 });
            try testArgs(@Vector(3, i129), @Vector(3, i257), .{ -1 << 256, -1, 0 });
            try testArgs(@Vector(3, i255), @Vector(3, i257), .{ -1 << 256, -1, 0 });
            try testArgs(@Vector(3, i256), @Vector(3, i257), .{ -1 << 256, -1, 0 });
            try testArgs(@Vector(3, i257), @Vector(3, i257), .{ -1 << 256, -1, 0 });
            try testArgs(@Vector(3, i511), @Vector(3, i257), .{ -1 << 256, -1, 0 });
            try testArgs(@Vector(3, i512), @Vector(3, i257), .{ -1 << 256, -1, 0 });
            try testArgs(@Vector(3, i513), @Vector(3, i257), .{ -1 << 256, -1, 0 });
            try testArgs(@Vector(3, i1023), @Vector(3, i257), .{ -1 << 256, -1, 0 });
            try testArgs(@Vector(3, i1024), @Vector(3, i257), .{ -1 << 256, -1, 0 });
            try testArgs(@Vector(3, i1025), @Vector(3, i257), .{ -1 << 256, -1, 0 });
            try testArgs(@Vector(3, u7), @Vector(3, u257), .{ 0, 1, 1 << 256 });
            try testArgs(@Vector(3, u8), @Vector(3, u257), .{ 0, 1, 1 << 256 });
            try testArgs(@Vector(3, u9), @Vector(3, u257), .{ 0, 1, 1 << 256 });
            try testArgs(@Vector(3, u15), @Vector(3, u257), .{ 0, 1, 1 << 256 });
            try testArgs(@Vector(3, u16), @Vector(3, u257), .{ 0, 1, 1 << 256 });
            try testArgs(@Vector(3, u17), @Vector(3, u257), .{ 0, 1, 1 << 256 });
            try testArgs(@Vector(3, u31), @Vector(3, u257), .{ 0, 1, 1 << 256 });
            try testArgs(@Vector(3, u32), @Vector(3, u257), .{ 0, 1, 1 << 256 });
            try testArgs(@Vector(3, u33), @Vector(3, u257), .{ 0, 1, 1 << 256 });
            try testArgs(@Vector(3, u63), @Vector(3, u257), .{ 0, 1, 1 << 256 });
            try testArgs(@Vector(3, u64), @Vector(3, u257), .{ 0, 1, 1 << 256 });
            try testArgs(@Vector(3, u65), @Vector(3, u257), .{ 0, 1, 1 << 256 });
            try testArgs(@Vector(3, u127), @Vector(3, u257), .{ 0, 1, 1 << 256 });
            try testArgs(@Vector(3, u128), @Vector(3, u257), .{ 0, 1, 1 << 256 });
            try testArgs(@Vector(3, u129), @Vector(3, u257), .{ 0, 1, 1 << 256 });
            try testArgs(@Vector(3, u255), @Vector(3, u257), .{ 0, 1, 1 << 256 });
            try testArgs(@Vector(3, u256), @Vector(3, u257), .{ 0, 1, 1 << 256 });
            try testArgs(@Vector(3, u257), @Vector(3, u257), .{ 0, 1, 1 << 256 });
            try testArgs(@Vector(3, u511), @Vector(3, u257), .{ 0, 1, 1 << 256 });
            try testArgs(@Vector(3, u512), @Vector(3, u257), .{ 0, 1, 1 << 256 });
            try testArgs(@Vector(3, u513), @Vector(3, u257), .{ 0, 1, 1 << 256 });
            try testArgs(@Vector(3, u1023), @Vector(3, u257), .{ 0, 1, 1 << 256 });
            try testArgs(@Vector(3, u1024), @Vector(3, u257), .{ 0, 1, 1 << 256 });
            try testArgs(@Vector(3, u1025), @Vector(3, u257), .{ 0, 1, 1 << 256 });

            try testArgs(@Vector(3, i7), @Vector(3, i511), .{ -1 << 510, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, i511), .{ -1 << 510, -1, 0 });
            try testArgs(@Vector(3, i9), @Vector(3, i511), .{ -1 << 510, -1, 0 });
            try testArgs(@Vector(3, i15), @Vector(3, i511), .{ -1 << 510, -1, 0 });
            try testArgs(@Vector(3, i16), @Vector(3, i511), .{ -1 << 510, -1, 0 });
            try testArgs(@Vector(3, i17), @Vector(3, i511), .{ -1 << 510, -1, 0 });
            try testArgs(@Vector(3, i31), @Vector(3, i511), .{ -1 << 510, -1, 0 });
            try testArgs(@Vector(3, i32), @Vector(3, i511), .{ -1 << 510, -1, 0 });
            try testArgs(@Vector(3, i33), @Vector(3, i511), .{ -1 << 510, -1, 0 });
            try testArgs(@Vector(3, i63), @Vector(3, i511), .{ -1 << 510, -1, 0 });
            try testArgs(@Vector(3, i64), @Vector(3, i511), .{ -1 << 510, -1, 0 });
            try testArgs(@Vector(3, i65), @Vector(3, i511), .{ -1 << 510, -1, 0 });
            try testArgs(@Vector(3, i127), @Vector(3, i511), .{ -1 << 510, -1, 0 });
            try testArgs(@Vector(3, i128), @Vector(3, i511), .{ -1 << 510, -1, 0 });
            try testArgs(@Vector(3, i129), @Vector(3, i511), .{ -1 << 510, -1, 0 });
            try testArgs(@Vector(3, i255), @Vector(3, i511), .{ -1 << 510, -1, 0 });
            try testArgs(@Vector(3, i256), @Vector(3, i511), .{ -1 << 510, -1, 0 });
            try testArgs(@Vector(3, i257), @Vector(3, i511), .{ -1 << 510, -1, 0 });
            try testArgs(@Vector(3, i511), @Vector(3, i511), .{ -1 << 510, -1, 0 });
            try testArgs(@Vector(3, i512), @Vector(3, i511), .{ -1 << 510, -1, 0 });
            try testArgs(@Vector(3, i513), @Vector(3, i511), .{ -1 << 510, -1, 0 });
            try testArgs(@Vector(3, i1023), @Vector(3, i511), .{ -1 << 510, -1, 0 });
            try testArgs(@Vector(3, i1024), @Vector(3, i511), .{ -1 << 510, -1, 0 });
            try testArgs(@Vector(3, i1025), @Vector(3, i511), .{ -1 << 510, -1, 0 });
            try testArgs(@Vector(3, u7), @Vector(3, u511), .{ 0, 1, 1 << 510 });
            try testArgs(@Vector(3, u8), @Vector(3, u511), .{ 0, 1, 1 << 510 });
            try testArgs(@Vector(3, u9), @Vector(3, u511), .{ 0, 1, 1 << 510 });
            try testArgs(@Vector(3, u15), @Vector(3, u511), .{ 0, 1, 1 << 510 });
            try testArgs(@Vector(3, u16), @Vector(3, u511), .{ 0, 1, 1 << 510 });
            try testArgs(@Vector(3, u17), @Vector(3, u511), .{ 0, 1, 1 << 510 });
            try testArgs(@Vector(3, u31), @Vector(3, u511), .{ 0, 1, 1 << 510 });
            try testArgs(@Vector(3, u32), @Vector(3, u511), .{ 0, 1, 1 << 510 });
            try testArgs(@Vector(3, u33), @Vector(3, u511), .{ 0, 1, 1 << 510 });
            try testArgs(@Vector(3, u63), @Vector(3, u511), .{ 0, 1, 1 << 510 });
            try testArgs(@Vector(3, u64), @Vector(3, u511), .{ 0, 1, 1 << 510 });
            try testArgs(@Vector(3, u65), @Vector(3, u511), .{ 0, 1, 1 << 510 });
            try testArgs(@Vector(3, u127), @Vector(3, u511), .{ 0, 1, 1 << 510 });
            try testArgs(@Vector(3, u128), @Vector(3, u511), .{ 0, 1, 1 << 510 });
            try testArgs(@Vector(3, u129), @Vector(3, u511), .{ 0, 1, 1 << 510 });
            try testArgs(@Vector(3, u255), @Vector(3, u511), .{ 0, 1, 1 << 510 });
            try testArgs(@Vector(3, u256), @Vector(3, u511), .{ 0, 1, 1 << 510 });
            try testArgs(@Vector(3, u257), @Vector(3, u511), .{ 0, 1, 1 << 510 });
            try testArgs(@Vector(3, u511), @Vector(3, u511), .{ 0, 1, 1 << 510 });
            try testArgs(@Vector(3, u512), @Vector(3, u511), .{ 0, 1, 1 << 510 });
            try testArgs(@Vector(3, u513), @Vector(3, u511), .{ 0, 1, 1 << 510 });
            try testArgs(@Vector(3, u1023), @Vector(3, u511), .{ 0, 1, 1 << 510 });
            try testArgs(@Vector(3, u1024), @Vector(3, u511), .{ 0, 1, 1 << 510 });
            try testArgs(@Vector(3, u1025), @Vector(3, u511), .{ 0, 1, 1 << 510 });

            try testArgs(@Vector(3, i7), @Vector(3, i512), .{ -1 << 511, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, i512), .{ -1 << 511, -1, 0 });
            try testArgs(@Vector(3, i9), @Vector(3, i512), .{ -1 << 511, -1, 0 });
            try testArgs(@Vector(3, i15), @Vector(3, i512), .{ -1 << 511, -1, 0 });
            try testArgs(@Vector(3, i16), @Vector(3, i512), .{ -1 << 511, -1, 0 });
            try testArgs(@Vector(3, i17), @Vector(3, i512), .{ -1 << 511, -1, 0 });
            try testArgs(@Vector(3, i31), @Vector(3, i512), .{ -1 << 511, -1, 0 });
            try testArgs(@Vector(3, i32), @Vector(3, i512), .{ -1 << 511, -1, 0 });
            try testArgs(@Vector(3, i33), @Vector(3, i512), .{ -1 << 511, -1, 0 });
            try testArgs(@Vector(3, i63), @Vector(3, i512), .{ -1 << 511, -1, 0 });
            try testArgs(@Vector(3, i64), @Vector(3, i512), .{ -1 << 511, -1, 0 });
            try testArgs(@Vector(3, i65), @Vector(3, i512), .{ -1 << 511, -1, 0 });
            try testArgs(@Vector(3, i127), @Vector(3, i512), .{ -1 << 511, -1, 0 });
            try testArgs(@Vector(3, i128), @Vector(3, i512), .{ -1 << 511, -1, 0 });
            try testArgs(@Vector(3, i129), @Vector(3, i512), .{ -1 << 511, -1, 0 });
            try testArgs(@Vector(3, i255), @Vector(3, i512), .{ -1 << 511, -1, 0 });
            try testArgs(@Vector(3, i256), @Vector(3, i512), .{ -1 << 511, -1, 0 });
            try testArgs(@Vector(3, i257), @Vector(3, i512), .{ -1 << 511, -1, 0 });
            try testArgs(@Vector(3, i511), @Vector(3, i512), .{ -1 << 511, -1, 0 });
            try testArgs(@Vector(3, i512), @Vector(3, i512), .{ -1 << 511, -1, 0 });
            try testArgs(@Vector(3, i513), @Vector(3, i512), .{ -1 << 511, -1, 0 });
            try testArgs(@Vector(3, i1023), @Vector(3, i512), .{ -1 << 511, -1, 0 });
            try testArgs(@Vector(3, i1024), @Vector(3, i512), .{ -1 << 511, -1, 0 });
            try testArgs(@Vector(3, i1025), @Vector(3, i512), .{ -1 << 511, -1, 0 });
            try testArgs(@Vector(3, u7), @Vector(3, u512), .{ 0, 1, 1 << 511 });
            try testArgs(@Vector(3, u8), @Vector(3, u512), .{ 0, 1, 1 << 511 });
            try testArgs(@Vector(3, u9), @Vector(3, u512), .{ 0, 1, 1 << 511 });
            try testArgs(@Vector(3, u15), @Vector(3, u512), .{ 0, 1, 1 << 511 });
            try testArgs(@Vector(3, u16), @Vector(3, u512), .{ 0, 1, 1 << 511 });
            try testArgs(@Vector(3, u17), @Vector(3, u512), .{ 0, 1, 1 << 511 });
            try testArgs(@Vector(3, u31), @Vector(3, u512), .{ 0, 1, 1 << 511 });
            try testArgs(@Vector(3, u32), @Vector(3, u512), .{ 0, 1, 1 << 511 });
            try testArgs(@Vector(3, u33), @Vector(3, u512), .{ 0, 1, 1 << 511 });
            try testArgs(@Vector(3, u63), @Vector(3, u512), .{ 0, 1, 1 << 511 });
            try testArgs(@Vector(3, u64), @Vector(3, u512), .{ 0, 1, 1 << 511 });
            try testArgs(@Vector(3, u65), @Vector(3, u512), .{ 0, 1, 1 << 511 });
            try testArgs(@Vector(3, u127), @Vector(3, u512), .{ 0, 1, 1 << 511 });
            try testArgs(@Vector(3, u128), @Vector(3, u512), .{ 0, 1, 1 << 511 });
            try testArgs(@Vector(3, u129), @Vector(3, u512), .{ 0, 1, 1 << 511 });
            try testArgs(@Vector(3, u255), @Vector(3, u512), .{ 0, 1, 1 << 511 });
            try testArgs(@Vector(3, u256), @Vector(3, u512), .{ 0, 1, 1 << 511 });
            try testArgs(@Vector(3, u257), @Vector(3, u512), .{ 0, 1, 1 << 511 });
            try testArgs(@Vector(3, u511), @Vector(3, u512), .{ 0, 1, 1 << 511 });
            try testArgs(@Vector(3, u512), @Vector(3, u512), .{ 0, 1, 1 << 511 });
            try testArgs(@Vector(3, u513), @Vector(3, u512), .{ 0, 1, 1 << 511 });
            try testArgs(@Vector(3, u1023), @Vector(3, u512), .{ 0, 1, 1 << 511 });
            try testArgs(@Vector(3, u1024), @Vector(3, u512), .{ 0, 1, 1 << 511 });
            try testArgs(@Vector(3, u1025), @Vector(3, u512), .{ 0, 1, 1 << 511 });

            try testArgs(@Vector(3, i7), @Vector(3, i513), .{ -1 << 512, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, i513), .{ -1 << 512, -1, 0 });
            try testArgs(@Vector(3, i9), @Vector(3, i513), .{ -1 << 512, -1, 0 });
            try testArgs(@Vector(3, i15), @Vector(3, i513), .{ -1 << 512, -1, 0 });
            try testArgs(@Vector(3, i16), @Vector(3, i513), .{ -1 << 512, -1, 0 });
            try testArgs(@Vector(3, i17), @Vector(3, i513), .{ -1 << 512, -1, 0 });
            try testArgs(@Vector(3, i31), @Vector(3, i513), .{ -1 << 512, -1, 0 });
            try testArgs(@Vector(3, i32), @Vector(3, i513), .{ -1 << 512, -1, 0 });
            try testArgs(@Vector(3, i33), @Vector(3, i513), .{ -1 << 512, -1, 0 });
            try testArgs(@Vector(3, i63), @Vector(3, i513), .{ -1 << 512, -1, 0 });
            try testArgs(@Vector(3, i64), @Vector(3, i513), .{ -1 << 512, -1, 0 });
            try testArgs(@Vector(3, i65), @Vector(3, i513), .{ -1 << 512, -1, 0 });
            try testArgs(@Vector(3, i127), @Vector(3, i513), .{ -1 << 512, -1, 0 });
            try testArgs(@Vector(3, i128), @Vector(3, i513), .{ -1 << 512, -1, 0 });
            try testArgs(@Vector(3, i129), @Vector(3, i513), .{ -1 << 512, -1, 0 });
            try testArgs(@Vector(3, i255), @Vector(3, i513), .{ -1 << 512, -1, 0 });
            try testArgs(@Vector(3, i256), @Vector(3, i513), .{ -1 << 512, -1, 0 });
            try testArgs(@Vector(3, i257), @Vector(3, i513), .{ -1 << 512, -1, 0 });
            try testArgs(@Vector(3, i511), @Vector(3, i513), .{ -1 << 512, -1, 0 });
            try testArgs(@Vector(3, i512), @Vector(3, i513), .{ -1 << 512, -1, 0 });
            try testArgs(@Vector(3, i513), @Vector(3, i513), .{ -1 << 512, -1, 0 });
            try testArgs(@Vector(3, i1023), @Vector(3, i513), .{ -1 << 512, -1, 0 });
            try testArgs(@Vector(3, i1024), @Vector(3, i513), .{ -1 << 512, -1, 0 });
            try testArgs(@Vector(3, i1025), @Vector(3, i513), .{ -1 << 512, -1, 0 });
            try testArgs(@Vector(3, u7), @Vector(3, u513), .{ 0, 1, 1 << 512 });
            try testArgs(@Vector(3, u8), @Vector(3, u513), .{ 0, 1, 1 << 512 });
            try testArgs(@Vector(3, u9), @Vector(3, u513), .{ 0, 1, 1 << 512 });
            try testArgs(@Vector(3, u15), @Vector(3, u513), .{ 0, 1, 1 << 512 });
            try testArgs(@Vector(3, u16), @Vector(3, u513), .{ 0, 1, 1 << 512 });
            try testArgs(@Vector(3, u17), @Vector(3, u513), .{ 0, 1, 1 << 512 });
            try testArgs(@Vector(3, u31), @Vector(3, u513), .{ 0, 1, 1 << 512 });
            try testArgs(@Vector(3, u32), @Vector(3, u513), .{ 0, 1, 1 << 512 });
            try testArgs(@Vector(3, u33), @Vector(3, u513), .{ 0, 1, 1 << 512 });
            try testArgs(@Vector(3, u63), @Vector(3, u513), .{ 0, 1, 1 << 512 });
            try testArgs(@Vector(3, u64), @Vector(3, u513), .{ 0, 1, 1 << 512 });
            try testArgs(@Vector(3, u65), @Vector(3, u513), .{ 0, 1, 1 << 512 });
            try testArgs(@Vector(3, u127), @Vector(3, u513), .{ 0, 1, 1 << 512 });
            try testArgs(@Vector(3, u128), @Vector(3, u513), .{ 0, 1, 1 << 512 });
            try testArgs(@Vector(3, u129), @Vector(3, u513), .{ 0, 1, 1 << 512 });
            try testArgs(@Vector(3, u255), @Vector(3, u513), .{ 0, 1, 1 << 512 });
            try testArgs(@Vector(3, u256), @Vector(3, u513), .{ 0, 1, 1 << 512 });
            try testArgs(@Vector(3, u257), @Vector(3, u513), .{ 0, 1, 1 << 512 });
            try testArgs(@Vector(3, u511), @Vector(3, u513), .{ 0, 1, 1 << 512 });
            try testArgs(@Vector(3, u512), @Vector(3, u513), .{ 0, 1, 1 << 512 });
            try testArgs(@Vector(3, u513), @Vector(3, u513), .{ 0, 1, 1 << 512 });
            try testArgs(@Vector(3, u1023), @Vector(3, u513), .{ 0, 1, 1 << 512 });
            try testArgs(@Vector(3, u1024), @Vector(3, u513), .{ 0, 1, 1 << 512 });
            try testArgs(@Vector(3, u1025), @Vector(3, u513), .{ 0, 1, 1 << 512 });

            try testArgs(@Vector(3, i7), @Vector(3, i1023), .{ -1 << 1022, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, i1023), .{ -1 << 1022, -1, 0 });
            try testArgs(@Vector(3, i9), @Vector(3, i1023), .{ -1 << 1022, -1, 0 });
            try testArgs(@Vector(3, i15), @Vector(3, i1023), .{ -1 << 1022, -1, 0 });
            try testArgs(@Vector(3, i16), @Vector(3, i1023), .{ -1 << 1022, -1, 0 });
            try testArgs(@Vector(3, i17), @Vector(3, i1023), .{ -1 << 1022, -1, 0 });
            try testArgs(@Vector(3, i31), @Vector(3, i1023), .{ -1 << 1022, -1, 0 });
            try testArgs(@Vector(3, i32), @Vector(3, i1023), .{ -1 << 1022, -1, 0 });
            try testArgs(@Vector(3, i33), @Vector(3, i1023), .{ -1 << 1022, -1, 0 });
            try testArgs(@Vector(3, i63), @Vector(3, i1023), .{ -1 << 1022, -1, 0 });
            try testArgs(@Vector(3, i64), @Vector(3, i1023), .{ -1 << 1022, -1, 0 });
            try testArgs(@Vector(3, i65), @Vector(3, i1023), .{ -1 << 1022, -1, 0 });
            try testArgs(@Vector(3, i127), @Vector(3, i1023), .{ -1 << 1022, -1, 0 });
            try testArgs(@Vector(3, i128), @Vector(3, i1023), .{ -1 << 1022, -1, 0 });
            try testArgs(@Vector(3, i129), @Vector(3, i1023), .{ -1 << 1022, -1, 0 });
            try testArgs(@Vector(3, i255), @Vector(3, i1023), .{ -1 << 1022, -1, 0 });
            try testArgs(@Vector(3, i256), @Vector(3, i1023), .{ -1 << 1022, -1, 0 });
            try testArgs(@Vector(3, i257), @Vector(3, i1023), .{ -1 << 1022, -1, 0 });
            try testArgs(@Vector(3, i511), @Vector(3, i1023), .{ -1 << 1022, -1, 0 });
            try testArgs(@Vector(3, i512), @Vector(3, i1023), .{ -1 << 1022, -1, 0 });
            try testArgs(@Vector(3, i513), @Vector(3, i1023), .{ -1 << 1022, -1, 0 });
            try testArgs(@Vector(3, i1023), @Vector(3, i1023), .{ -1 << 1022, -1, 0 });
            try testArgs(@Vector(3, i1024), @Vector(3, i1023), .{ -1 << 1022, -1, 0 });
            try testArgs(@Vector(3, i1025), @Vector(3, i1023), .{ -1 << 1022, -1, 0 });
            try testArgs(@Vector(3, u7), @Vector(3, u1023), .{ 0, 1, 1 << 1022 });
            try testArgs(@Vector(3, u8), @Vector(3, u1023), .{ 0, 1, 1 << 1022 });
            try testArgs(@Vector(3, u9), @Vector(3, u1023), .{ 0, 1, 1 << 1022 });
            try testArgs(@Vector(3, u15), @Vector(3, u1023), .{ 0, 1, 1 << 1022 });
            try testArgs(@Vector(3, u16), @Vector(3, u1023), .{ 0, 1, 1 << 1022 });
            try testArgs(@Vector(3, u17), @Vector(3, u1023), .{ 0, 1, 1 << 1022 });
            try testArgs(@Vector(3, u31), @Vector(3, u1023), .{ 0, 1, 1 << 1022 });
            try testArgs(@Vector(3, u32), @Vector(3, u1023), .{ 0, 1, 1 << 1022 });
            try testArgs(@Vector(3, u33), @Vector(3, u1023), .{ 0, 1, 1 << 1022 });
            try testArgs(@Vector(3, u63), @Vector(3, u1023), .{ 0, 1, 1 << 1022 });
            try testArgs(@Vector(3, u64), @Vector(3, u1023), .{ 0, 1, 1 << 1022 });
            try testArgs(@Vector(3, u65), @Vector(3, u1023), .{ 0, 1, 1 << 1022 });
            try testArgs(@Vector(3, u127), @Vector(3, u1023), .{ 0, 1, 1 << 1022 });
            try testArgs(@Vector(3, u128), @Vector(3, u1023), .{ 0, 1, 1 << 1022 });
            try testArgs(@Vector(3, u129), @Vector(3, u1023), .{ 0, 1, 1 << 1022 });
            try testArgs(@Vector(3, u255), @Vector(3, u1023), .{ 0, 1, 1 << 1022 });
            try testArgs(@Vector(3, u256), @Vector(3, u1023), .{ 0, 1, 1 << 1022 });
            try testArgs(@Vector(3, u257), @Vector(3, u1023), .{ 0, 1, 1 << 1022 });
            try testArgs(@Vector(3, u511), @Vector(3, u1023), .{ 0, 1, 1 << 1022 });
            try testArgs(@Vector(3, u512), @Vector(3, u1023), .{ 0, 1, 1 << 1022 });
            try testArgs(@Vector(3, u513), @Vector(3, u1023), .{ 0, 1, 1 << 1022 });
            try testArgs(@Vector(3, u1023), @Vector(3, u1023), .{ 0, 1, 1 << 1022 });
            try testArgs(@Vector(3, u1024), @Vector(3, u1023), .{ 0, 1, 1 << 1022 });
            try testArgs(@Vector(3, u1025), @Vector(3, u1023), .{ 0, 1, 1 << 1022 });

            try testArgs(@Vector(3, i7), @Vector(3, i1024), .{ -1 << 1023, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, i1024), .{ -1 << 1023, -1, 0 });
            try testArgs(@Vector(3, i9), @Vector(3, i1024), .{ -1 << 1023, -1, 0 });
            try testArgs(@Vector(3, i15), @Vector(3, i1024), .{ -1 << 1023, -1, 0 });
            try testArgs(@Vector(3, i16), @Vector(3, i1024), .{ -1 << 1023, -1, 0 });
            try testArgs(@Vector(3, i17), @Vector(3, i1024), .{ -1 << 1023, -1, 0 });
            try testArgs(@Vector(3, i31), @Vector(3, i1024), .{ -1 << 1023, -1, 0 });
            try testArgs(@Vector(3, i32), @Vector(3, i1024), .{ -1 << 1023, -1, 0 });
            try testArgs(@Vector(3, i33), @Vector(3, i1024), .{ -1 << 1023, -1, 0 });
            try testArgs(@Vector(3, i63), @Vector(3, i1024), .{ -1 << 1023, -1, 0 });
            try testArgs(@Vector(3, i64), @Vector(3, i1024), .{ -1 << 1023, -1, 0 });
            try testArgs(@Vector(3, i65), @Vector(3, i1024), .{ -1 << 1023, -1, 0 });
            try testArgs(@Vector(3, i127), @Vector(3, i1024), .{ -1 << 1023, -1, 0 });
            try testArgs(@Vector(3, i128), @Vector(3, i1024), .{ -1 << 1023, -1, 0 });
            try testArgs(@Vector(3, i129), @Vector(3, i1024), .{ -1 << 1023, -1, 0 });
            try testArgs(@Vector(3, i255), @Vector(3, i1024), .{ -1 << 1023, -1, 0 });
            try testArgs(@Vector(3, i256), @Vector(3, i1024), .{ -1 << 1023, -1, 0 });
            try testArgs(@Vector(3, i257), @Vector(3, i1024), .{ -1 << 1023, -1, 0 });
            try testArgs(@Vector(3, i511), @Vector(3, i1024), .{ -1 << 1023, -1, 0 });
            try testArgs(@Vector(3, i512), @Vector(3, i1024), .{ -1 << 1023, -1, 0 });
            try testArgs(@Vector(3, i513), @Vector(3, i1024), .{ -1 << 1023, -1, 0 });
            try testArgs(@Vector(3, i1023), @Vector(3, i1024), .{ -1 << 1023, -1, 0 });
            try testArgs(@Vector(3, i1024), @Vector(3, i1024), .{ -1 << 1023, -1, 0 });
            try testArgs(@Vector(3, i1025), @Vector(3, i1024), .{ -1 << 1023, -1, 0 });
            try testArgs(@Vector(3, u7), @Vector(3, u1024), .{ 0, 1, 1 << 1023 });
            try testArgs(@Vector(3, u8), @Vector(3, u1024), .{ 0, 1, 1 << 1023 });
            try testArgs(@Vector(3, u9), @Vector(3, u1024), .{ 0, 1, 1 << 1023 });
            try testArgs(@Vector(3, u15), @Vector(3, u1024), .{ 0, 1, 1 << 1023 });
            try testArgs(@Vector(3, u16), @Vector(3, u1024), .{ 0, 1, 1 << 1023 });
            try testArgs(@Vector(3, u17), @Vector(3, u1024), .{ 0, 1, 1 << 1023 });
            try testArgs(@Vector(3, u31), @Vector(3, u1024), .{ 0, 1, 1 << 1023 });
            try testArgs(@Vector(3, u32), @Vector(3, u1024), .{ 0, 1, 1 << 1023 });
            try testArgs(@Vector(3, u33), @Vector(3, u1024), .{ 0, 1, 1 << 1023 });
            try testArgs(@Vector(3, u63), @Vector(3, u1024), .{ 0, 1, 1 << 1023 });
            try testArgs(@Vector(3, u64), @Vector(3, u1024), .{ 0, 1, 1 << 1023 });
            try testArgs(@Vector(3, u65), @Vector(3, u1024), .{ 0, 1, 1 << 1023 });
            try testArgs(@Vector(3, u127), @Vector(3, u1024), .{ 0, 1, 1 << 1023 });
            try testArgs(@Vector(3, u128), @Vector(3, u1024), .{ 0, 1, 1 << 1023 });
            try testArgs(@Vector(3, u129), @Vector(3, u1024), .{ 0, 1, 1 << 1023 });
            try testArgs(@Vector(3, u255), @Vector(3, u1024), .{ 0, 1, 1 << 1023 });
            try testArgs(@Vector(3, u256), @Vector(3, u1024), .{ 0, 1, 1 << 1023 });
            try testArgs(@Vector(3, u257), @Vector(3, u1024), .{ 0, 1, 1 << 1023 });
            try testArgs(@Vector(3, u511), @Vector(3, u1024), .{ 0, 1, 1 << 1023 });
            try testArgs(@Vector(3, u512), @Vector(3, u1024), .{ 0, 1, 1 << 1023 });
            try testArgs(@Vector(3, u513), @Vector(3, u1024), .{ 0, 1, 1 << 1023 });
            try testArgs(@Vector(3, u1023), @Vector(3, u1024), .{ 0, 1, 1 << 1023 });
            try testArgs(@Vector(3, u1024), @Vector(3, u1024), .{ 0, 1, 1 << 1023 });
            try testArgs(@Vector(3, u1025), @Vector(3, u1024), .{ 0, 1, 1 << 1023 });

            try testArgs(@Vector(3, i7), @Vector(3, i1025), .{ -1 << 1024, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, i1025), .{ -1 << 1024, -1, 0 });
            try testArgs(@Vector(3, i9), @Vector(3, i1025), .{ -1 << 1024, -1, 0 });
            try testArgs(@Vector(3, i15), @Vector(3, i1025), .{ -1 << 1024, -1, 0 });
            try testArgs(@Vector(3, i16), @Vector(3, i1025), .{ -1 << 1024, -1, 0 });
            try testArgs(@Vector(3, i17), @Vector(3, i1025), .{ -1 << 1024, -1, 0 });
            try testArgs(@Vector(3, i31), @Vector(3, i1025), .{ -1 << 1024, -1, 0 });
            try testArgs(@Vector(3, i32), @Vector(3, i1025), .{ -1 << 1024, -1, 0 });
            try testArgs(@Vector(3, i33), @Vector(3, i1025), .{ -1 << 1024, -1, 0 });
            try testArgs(@Vector(3, i63), @Vector(3, i1025), .{ -1 << 1024, -1, 0 });
            try testArgs(@Vector(3, i64), @Vector(3, i1025), .{ -1 << 1024, -1, 0 });
            try testArgs(@Vector(3, i65), @Vector(3, i1025), .{ -1 << 1024, -1, 0 });
            try testArgs(@Vector(3, i127), @Vector(3, i1025), .{ -1 << 1024, -1, 0 });
            try testArgs(@Vector(3, i128), @Vector(3, i1025), .{ -1 << 1024, -1, 0 });
            try testArgs(@Vector(3, i129), @Vector(3, i1025), .{ -1 << 1024, -1, 0 });
            try testArgs(@Vector(3, i255), @Vector(3, i1025), .{ -1 << 1024, -1, 0 });
            try testArgs(@Vector(3, i256), @Vector(3, i1025), .{ -1 << 1024, -1, 0 });
            try testArgs(@Vector(3, i257), @Vector(3, i1025), .{ -1 << 1024, -1, 0 });
            try testArgs(@Vector(3, i511), @Vector(3, i1025), .{ -1 << 1024, -1, 0 });
            try testArgs(@Vector(3, i512), @Vector(3, i1025), .{ -1 << 1024, -1, 0 });
            try testArgs(@Vector(3, i513), @Vector(3, i1025), .{ -1 << 1024, -1, 0 });
            try testArgs(@Vector(3, i1023), @Vector(3, i1025), .{ -1 << 1024, -1, 0 });
            try testArgs(@Vector(3, i1024), @Vector(3, i1025), .{ -1 << 1024, -1, 0 });
            try testArgs(@Vector(3, i1025), @Vector(3, i1025), .{ -1 << 1024, -1, 0 });
            try testArgs(@Vector(3, u7), @Vector(3, u1025), .{ 0, 1, 1 << 1024 });
            try testArgs(@Vector(3, u8), @Vector(3, u1025), .{ 0, 1, 1 << 1024 });
            try testArgs(@Vector(3, u9), @Vector(3, u1025), .{ 0, 1, 1 << 1024 });
            try testArgs(@Vector(3, u15), @Vector(3, u1025), .{ 0, 1, 1 << 1024 });
            try testArgs(@Vector(3, u16), @Vector(3, u1025), .{ 0, 1, 1 << 1024 });
            try testArgs(@Vector(3, u17), @Vector(3, u1025), .{ 0, 1, 1 << 1024 });
            try testArgs(@Vector(3, u31), @Vector(3, u1025), .{ 0, 1, 1 << 1024 });
            try testArgs(@Vector(3, u32), @Vector(3, u1025), .{ 0, 1, 1 << 1024 });
            try testArgs(@Vector(3, u33), @Vector(3, u1025), .{ 0, 1, 1 << 1024 });
            try testArgs(@Vector(3, u63), @Vector(3, u1025), .{ 0, 1, 1 << 1024 });
            try testArgs(@Vector(3, u64), @Vector(3, u1025), .{ 0, 1, 1 << 1024 });
            try testArgs(@Vector(3, u65), @Vector(3, u1025), .{ 0, 1, 1 << 1024 });
            try testArgs(@Vector(3, u127), @Vector(3, u1025), .{ 0, 1, 1 << 1024 });
            try testArgs(@Vector(3, u128), @Vector(3, u1025), .{ 0, 1, 1 << 1024 });
            try testArgs(@Vector(3, u129), @Vector(3, u1025), .{ 0, 1, 1 << 1024 });
            try testArgs(@Vector(3, u255), @Vector(3, u1025), .{ 0, 1, 1 << 1024 });
            try testArgs(@Vector(3, u256), @Vector(3, u1025), .{ 0, 1, 1 << 1024 });
            try testArgs(@Vector(3, u257), @Vector(3, u1025), .{ 0, 1, 1 << 1024 });
            try testArgs(@Vector(3, u511), @Vector(3, u1025), .{ 0, 1, 1 << 1024 });
            try testArgs(@Vector(3, u512), @Vector(3, u1025), .{ 0, 1, 1 << 1024 });
            try testArgs(@Vector(3, u513), @Vector(3, u1025), .{ 0, 1, 1 << 1024 });
            try testArgs(@Vector(3, u1023), @Vector(3, u1025), .{ 0, 1, 1 << 1024 });
            try testArgs(@Vector(3, u1024), @Vector(3, u1025), .{ 0, 1, 1 << 1024 });
            try testArgs(@Vector(3, u1025), @Vector(3, u1025), .{ 0, 1, 1 << 1024 });
        }
        fn testIntVectors() !void {
            try testSameSignednessIntVectors();

            try testArgs(@Vector(1, u8), @Vector(1, i1), .{-1});
            try testArgs(@Vector(1, u16), @Vector(1, i1), .{-1});
            try testArgs(@Vector(1, u32), @Vector(1, i1), .{-1});
            try testArgs(@Vector(1, u64), @Vector(1, i1), .{-1});
            try testArgs(@Vector(1, u128), @Vector(1, i1), .{-1});
            try testArgs(@Vector(1, u256), @Vector(1, i1), .{-1});
            try testArgs(@Vector(1, u512), @Vector(1, i1), .{-1});
            try testArgs(@Vector(1, u1024), @Vector(1, i1), .{-1});
            try testArgs(@Vector(1, i8), @Vector(1, u1), .{1});
            try testArgs(@Vector(1, i16), @Vector(1, u1), .{1});
            try testArgs(@Vector(1, i32), @Vector(1, u1), .{1});
            try testArgs(@Vector(1, i64), @Vector(1, u1), .{1});
            try testArgs(@Vector(1, i128), @Vector(1, u1), .{1});
            try testArgs(@Vector(1, i256), @Vector(1, u1), .{1});
            try testArgs(@Vector(1, i512), @Vector(1, u1), .{1});
            try testArgs(@Vector(1, i1024), @Vector(1, u1), .{1});

            try testArgs(@Vector(2, u8), @Vector(2, i1), .{ -1, 0 });
            try testArgs(@Vector(2, u16), @Vector(2, i1), .{ -1, 0 });
            try testArgs(@Vector(2, u32), @Vector(2, i1), .{ -1, 0 });
            try testArgs(@Vector(2, u64), @Vector(2, i1), .{ -1, 0 });
            try testArgs(@Vector(2, u128), @Vector(2, i1), .{ -1, 0 });
            try testArgs(@Vector(2, u256), @Vector(2, i1), .{ -1, 0 });
            try testArgs(@Vector(2, u512), @Vector(2, i1), .{ -1, 0 });
            try testArgs(@Vector(2, u1024), @Vector(2, i1), .{ -1, 0 });
            try testArgs(@Vector(2, i8), @Vector(2, u1), .{ 0, 1 });
            try testArgs(@Vector(2, i16), @Vector(2, u1), .{ 0, 1 });
            try testArgs(@Vector(2, i32), @Vector(2, u1), .{ 0, 1 });
            try testArgs(@Vector(2, i64), @Vector(2, u1), .{ 0, 1 });
            try testArgs(@Vector(2, i128), @Vector(2, u1), .{ 0, 1 });
            try testArgs(@Vector(2, i256), @Vector(2, u1), .{ 0, 1 });
            try testArgs(@Vector(2, i512), @Vector(2, u1), .{ 0, 1 });
            try testArgs(@Vector(2, i1024), @Vector(2, u1), .{ 0, 1 });

            try testArgs(@Vector(3, u8), @Vector(3, i2), .{ -1 << 1, -1, 0 });
            try testArgs(@Vector(3, u16), @Vector(3, i2), .{ -1 << 1, -1, 0 });
            try testArgs(@Vector(3, u32), @Vector(3, i2), .{ -1 << 1, -1, 0 });
            try testArgs(@Vector(3, u64), @Vector(3, i2), .{ -1 << 1, -1, 0 });
            try testArgs(@Vector(3, u128), @Vector(3, i2), .{ -1 << 1, -1, 0 });
            try testArgs(@Vector(3, u256), @Vector(3, i2), .{ -1 << 1, -1, 0 });
            try testArgs(@Vector(3, u512), @Vector(3, i2), .{ -1 << 1, -1, 0 });
            try testArgs(@Vector(3, u1024), @Vector(3, i2), .{ -1 << 1, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, u2), .{ 0, 1, 1 << 1 });
            try testArgs(@Vector(3, i16), @Vector(3, u2), .{ 0, 1, 1 << 1 });
            try testArgs(@Vector(3, i32), @Vector(3, u2), .{ 0, 1, 1 << 1 });
            try testArgs(@Vector(3, i64), @Vector(3, u2), .{ 0, 1, 1 << 1 });
            try testArgs(@Vector(3, i128), @Vector(3, u2), .{ 0, 1, 1 << 1 });
            try testArgs(@Vector(3, i256), @Vector(3, u2), .{ 0, 1, 1 << 1 });
            try testArgs(@Vector(3, i512), @Vector(3, u2), .{ 0, 1, 1 << 1 });
            try testArgs(@Vector(3, i1024), @Vector(3, u2), .{ 0, 1, 1 << 1 });

            try testArgs(@Vector(3, u8), @Vector(3, i3), .{ -1 << 2, -1, 0 });
            try testArgs(@Vector(3, u16), @Vector(3, i3), .{ -1 << 2, -1, 0 });
            try testArgs(@Vector(3, u32), @Vector(3, i3), .{ -1 << 2, -1, 0 });
            try testArgs(@Vector(3, u64), @Vector(3, i3), .{ -1 << 2, -1, 0 });
            try testArgs(@Vector(3, u128), @Vector(3, i3), .{ -1 << 2, -1, 0 });
            try testArgs(@Vector(3, u256), @Vector(3, i3), .{ -1 << 2, -1, 0 });
            try testArgs(@Vector(3, u512), @Vector(3, i3), .{ -1 << 2, -1, 0 });
            try testArgs(@Vector(3, u1024), @Vector(3, i3), .{ -1 << 2, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, u3), .{ 0, 1, 1 << 2 });
            try testArgs(@Vector(3, i16), @Vector(3, u3), .{ 0, 1, 1 << 2 });
            try testArgs(@Vector(3, i32), @Vector(3, u3), .{ 0, 1, 1 << 2 });
            try testArgs(@Vector(3, i64), @Vector(3, u3), .{ 0, 1, 1 << 2 });
            try testArgs(@Vector(3, i128), @Vector(3, u3), .{ 0, 1, 1 << 2 });
            try testArgs(@Vector(3, i256), @Vector(3, u3), .{ 0, 1, 1 << 2 });
            try testArgs(@Vector(3, i512), @Vector(3, u3), .{ 0, 1, 1 << 2 });
            try testArgs(@Vector(3, i1024), @Vector(3, u3), .{ 0, 1, 1 << 2 });

            try testArgs(@Vector(3, u8), @Vector(3, i4), .{ -1 << 3, -1, 0 });
            try testArgs(@Vector(3, u16), @Vector(3, i4), .{ -1 << 3, -1, 0 });
            try testArgs(@Vector(3, u32), @Vector(3, i4), .{ -1 << 3, -1, 0 });
            try testArgs(@Vector(3, u64), @Vector(3, i4), .{ -1 << 3, -1, 0 });
            try testArgs(@Vector(3, u128), @Vector(3, i4), .{ -1 << 3, -1, 0 });
            try testArgs(@Vector(3, u256), @Vector(3, i4), .{ -1 << 3, -1, 0 });
            try testArgs(@Vector(3, u512), @Vector(3, i4), .{ -1 << 3, -1, 0 });
            try testArgs(@Vector(3, u1024), @Vector(3, i4), .{ -1 << 3, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, u4), .{ 0, 1, 1 << 3 });
            try testArgs(@Vector(3, i16), @Vector(3, u4), .{ 0, 1, 1 << 3 });
            try testArgs(@Vector(3, i32), @Vector(3, u4), .{ 0, 1, 1 << 3 });
            try testArgs(@Vector(3, i64), @Vector(3, u4), .{ 0, 1, 1 << 3 });
            try testArgs(@Vector(3, i128), @Vector(3, u4), .{ 0, 1, 1 << 3 });
            try testArgs(@Vector(3, i256), @Vector(3, u4), .{ 0, 1, 1 << 3 });
            try testArgs(@Vector(3, i512), @Vector(3, u4), .{ 0, 1, 1 << 3 });
            try testArgs(@Vector(3, i1024), @Vector(3, u4), .{ 0, 1, 1 << 3 });

            try testArgs(@Vector(3, u8), @Vector(3, i5), .{ -1 << 4, -1, 0 });
            try testArgs(@Vector(3, u16), @Vector(3, i5), .{ -1 << 4, -1, 0 });
            try testArgs(@Vector(3, u32), @Vector(3, i5), .{ -1 << 4, -1, 0 });
            try testArgs(@Vector(3, u64), @Vector(3, i5), .{ -1 << 4, -1, 0 });
            try testArgs(@Vector(3, u128), @Vector(3, i5), .{ -1 << 4, -1, 0 });
            try testArgs(@Vector(3, u256), @Vector(3, i5), .{ -1 << 4, -1, 0 });
            try testArgs(@Vector(3, u512), @Vector(3, i5), .{ -1 << 4, -1, 0 });
            try testArgs(@Vector(3, u1024), @Vector(3, i5), .{ -1 << 4, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, u5), .{ 0, 1, 1 << 4 });
            try testArgs(@Vector(3, i16), @Vector(3, u5), .{ 0, 1, 1 << 4 });
            try testArgs(@Vector(3, i32), @Vector(3, u5), .{ 0, 1, 1 << 4 });
            try testArgs(@Vector(3, i64), @Vector(3, u5), .{ 0, 1, 1 << 4 });
            try testArgs(@Vector(3, i128), @Vector(3, u5), .{ 0, 1, 1 << 4 });
            try testArgs(@Vector(3, i256), @Vector(3, u5), .{ 0, 1, 1 << 4 });
            try testArgs(@Vector(3, i512), @Vector(3, u5), .{ 0, 1, 1 << 4 });
            try testArgs(@Vector(3, i1024), @Vector(3, u5), .{ 0, 1, 1 << 4 });

            try testArgs(@Vector(3, u8), @Vector(3, i7), .{ -1 << 6, -1, 0 });
            try testArgs(@Vector(3, u16), @Vector(3, i7), .{ -1 << 6, -1, 0 });
            try testArgs(@Vector(3, u32), @Vector(3, i7), .{ -1 << 6, -1, 0 });
            try testArgs(@Vector(3, u64), @Vector(3, i7), .{ -1 << 6, -1, 0 });
            try testArgs(@Vector(3, u128), @Vector(3, i7), .{ -1 << 6, -1, 0 });
            try testArgs(@Vector(3, u256), @Vector(3, i7), .{ -1 << 6, -1, 0 });
            try testArgs(@Vector(3, u512), @Vector(3, i7), .{ -1 << 6, -1, 0 });
            try testArgs(@Vector(3, u1024), @Vector(3, i7), .{ -1 << 6, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, u7), .{ 0, 1, 1 << 6 });
            try testArgs(@Vector(3, i16), @Vector(3, u7), .{ 0, 1, 1 << 6 });
            try testArgs(@Vector(3, i32), @Vector(3, u7), .{ 0, 1, 1 << 6 });
            try testArgs(@Vector(3, i64), @Vector(3, u7), .{ 0, 1, 1 << 6 });
            try testArgs(@Vector(3, i128), @Vector(3, u7), .{ 0, 1, 1 << 6 });
            try testArgs(@Vector(3, i256), @Vector(3, u7), .{ 0, 1, 1 << 6 });
            try testArgs(@Vector(3, i512), @Vector(3, u7), .{ 0, 1, 1 << 6 });
            try testArgs(@Vector(3, i1024), @Vector(3, u7), .{ 0, 1, 1 << 6 });

            try testArgs(@Vector(3, u8), @Vector(3, i8), .{ -1 << 7, -1, 0 });
            try testArgs(@Vector(3, u16), @Vector(3, i8), .{ -1 << 7, -1, 0 });
            try testArgs(@Vector(3, u32), @Vector(3, i8), .{ -1 << 7, -1, 0 });
            try testArgs(@Vector(3, u64), @Vector(3, i8), .{ -1 << 7, -1, 0 });
            try testArgs(@Vector(3, u128), @Vector(3, i8), .{ -1 << 7, -1, 0 });
            try testArgs(@Vector(3, u256), @Vector(3, i8), .{ -1 << 7, -1, 0 });
            try testArgs(@Vector(3, u512), @Vector(3, i8), .{ -1 << 7, -1, 0 });
            try testArgs(@Vector(3, u1024), @Vector(3, i8), .{ -1 << 7, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, u8), .{ 0, 1, 1 << 7 });
            try testArgs(@Vector(3, i16), @Vector(3, u8), .{ 0, 1, 1 << 7 });
            try testArgs(@Vector(3, i32), @Vector(3, u8), .{ 0, 1, 1 << 7 });
            try testArgs(@Vector(3, i64), @Vector(3, u8), .{ 0, 1, 1 << 7 });
            try testArgs(@Vector(3, i128), @Vector(3, u8), .{ 0, 1, 1 << 7 });
            try testArgs(@Vector(3, i256), @Vector(3, u8), .{ 0, 1, 1 << 7 });
            try testArgs(@Vector(3, i512), @Vector(3, u8), .{ 0, 1, 1 << 7 });
            try testArgs(@Vector(3, i1024), @Vector(3, u8), .{ 0, 1, 1 << 7 });

            try testArgs(@Vector(3, u8), @Vector(3, i9), .{ -1 << 8, -1, 0 });
            try testArgs(@Vector(3, u16), @Vector(3, i9), .{ -1 << 8, -1, 0 });
            try testArgs(@Vector(3, u32), @Vector(3, i9), .{ -1 << 8, -1, 0 });
            try testArgs(@Vector(3, u64), @Vector(3, i9), .{ -1 << 8, -1, 0 });
            try testArgs(@Vector(3, u128), @Vector(3, i9), .{ -1 << 8, -1, 0 });
            try testArgs(@Vector(3, u256), @Vector(3, i9), .{ -1 << 8, -1, 0 });
            try testArgs(@Vector(3, u512), @Vector(3, i9), .{ -1 << 8, -1, 0 });
            try testArgs(@Vector(3, u1024), @Vector(3, i9), .{ -1 << 8, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, u9), .{ 0, 1, 1 << 8 });
            try testArgs(@Vector(3, i16), @Vector(3, u9), .{ 0, 1, 1 << 8 });
            try testArgs(@Vector(3, i32), @Vector(3, u9), .{ 0, 1, 1 << 8 });
            try testArgs(@Vector(3, i64), @Vector(3, u9), .{ 0, 1, 1 << 8 });
            try testArgs(@Vector(3, i128), @Vector(3, u9), .{ 0, 1, 1 << 8 });
            try testArgs(@Vector(3, i256), @Vector(3, u9), .{ 0, 1, 1 << 8 });
            try testArgs(@Vector(3, i512), @Vector(3, u9), .{ 0, 1, 1 << 8 });
            try testArgs(@Vector(3, i1024), @Vector(3, u9), .{ 0, 1, 1 << 8 });

            try testArgs(@Vector(3, u8), @Vector(3, i15), .{ -1 << 14, -1, 0 });
            try testArgs(@Vector(3, u16), @Vector(3, i15), .{ -1 << 14, -1, 0 });
            try testArgs(@Vector(3, u32), @Vector(3, i15), .{ -1 << 14, -1, 0 });
            try testArgs(@Vector(3, u64), @Vector(3, i15), .{ -1 << 14, -1, 0 });
            try testArgs(@Vector(3, u128), @Vector(3, i15), .{ -1 << 14, -1, 0 });
            try testArgs(@Vector(3, u256), @Vector(3, i15), .{ -1 << 14, -1, 0 });
            try testArgs(@Vector(3, u512), @Vector(3, i15), .{ -1 << 14, -1, 0 });
            try testArgs(@Vector(3, u1024), @Vector(3, i15), .{ -1 << 14, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, u15), .{ 0, 1, 1 << 14 });
            try testArgs(@Vector(3, i16), @Vector(3, u15), .{ 0, 1, 1 << 14 });
            try testArgs(@Vector(3, i32), @Vector(3, u15), .{ 0, 1, 1 << 14 });
            try testArgs(@Vector(3, i64), @Vector(3, u15), .{ 0, 1, 1 << 14 });
            try testArgs(@Vector(3, i128), @Vector(3, u15), .{ 0, 1, 1 << 14 });
            try testArgs(@Vector(3, i256), @Vector(3, u15), .{ 0, 1, 1 << 14 });
            try testArgs(@Vector(3, i512), @Vector(3, u15), .{ 0, 1, 1 << 14 });
            try testArgs(@Vector(3, i1024), @Vector(3, u15), .{ 0, 1, 1 << 14 });

            try testArgs(@Vector(3, u8), @Vector(3, i16), .{ -1 << 15, -1, 0 });
            try testArgs(@Vector(3, u16), @Vector(3, i16), .{ -1 << 15, -1, 0 });
            try testArgs(@Vector(3, u32), @Vector(3, i16), .{ -1 << 15, -1, 0 });
            try testArgs(@Vector(3, u64), @Vector(3, i16), .{ -1 << 15, -1, 0 });
            try testArgs(@Vector(3, u128), @Vector(3, i16), .{ -1 << 15, -1, 0 });
            try testArgs(@Vector(3, u256), @Vector(3, i16), .{ -1 << 15, -1, 0 });
            try testArgs(@Vector(3, u512), @Vector(3, i16), .{ -1 << 15, -1, 0 });
            try testArgs(@Vector(3, u1024), @Vector(3, i16), .{ -1 << 15, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, u16), .{ 0, 1, 1 << 15 });
            try testArgs(@Vector(3, i16), @Vector(3, u16), .{ 0, 1, 1 << 15 });
            try testArgs(@Vector(3, i32), @Vector(3, u16), .{ 0, 1, 1 << 15 });
            try testArgs(@Vector(3, i64), @Vector(3, u16), .{ 0, 1, 1 << 15 });
            try testArgs(@Vector(3, i128), @Vector(3, u16), .{ 0, 1, 1 << 15 });
            try testArgs(@Vector(3, i256), @Vector(3, u16), .{ 0, 1, 1 << 15 });
            try testArgs(@Vector(3, i512), @Vector(3, u16), .{ 0, 1, 1 << 15 });
            try testArgs(@Vector(3, i1024), @Vector(3, u16), .{ 0, 1, 1 << 15 });

            try testArgs(@Vector(3, u8), @Vector(3, i17), .{ -1 << 16, -1, 0 });
            try testArgs(@Vector(3, u16), @Vector(3, i17), .{ -1 << 16, -1, 0 });
            try testArgs(@Vector(3, u32), @Vector(3, i17), .{ -1 << 16, -1, 0 });
            try testArgs(@Vector(3, u64), @Vector(3, i17), .{ -1 << 16, -1, 0 });
            try testArgs(@Vector(3, u128), @Vector(3, i17), .{ -1 << 16, -1, 0 });
            try testArgs(@Vector(3, u256), @Vector(3, i17), .{ -1 << 16, -1, 0 });
            try testArgs(@Vector(3, u512), @Vector(3, i17), .{ -1 << 16, -1, 0 });
            try testArgs(@Vector(3, u1024), @Vector(3, i17), .{ -1 << 16, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, u17), .{ 0, 1, 1 << 16 });
            try testArgs(@Vector(3, i16), @Vector(3, u17), .{ 0, 1, 1 << 16 });
            try testArgs(@Vector(3, i32), @Vector(3, u17), .{ 0, 1, 1 << 16 });
            try testArgs(@Vector(3, i64), @Vector(3, u17), .{ 0, 1, 1 << 16 });
            try testArgs(@Vector(3, i128), @Vector(3, u17), .{ 0, 1, 1 << 16 });
            try testArgs(@Vector(3, i256), @Vector(3, u17), .{ 0, 1, 1 << 16 });
            try testArgs(@Vector(3, i512), @Vector(3, u17), .{ 0, 1, 1 << 16 });
            try testArgs(@Vector(3, i1024), @Vector(3, u17), .{ 0, 1, 1 << 16 });

            try testArgs(@Vector(3, u8), @Vector(3, i31), .{ -1 << 30, -1, 0 });
            try testArgs(@Vector(3, u16), @Vector(3, i31), .{ -1 << 30, -1, 0 });
            try testArgs(@Vector(3, u32), @Vector(3, i31), .{ -1 << 30, -1, 0 });
            try testArgs(@Vector(3, u64), @Vector(3, i31), .{ -1 << 30, -1, 0 });
            try testArgs(@Vector(3, u128), @Vector(3, i31), .{ -1 << 30, -1, 0 });
            try testArgs(@Vector(3, u256), @Vector(3, i31), .{ -1 << 30, -1, 0 });
            try testArgs(@Vector(3, u512), @Vector(3, i31), .{ -1 << 30, -1, 0 });
            try testArgs(@Vector(3, u1024), @Vector(3, i31), .{ -1 << 30, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, u31), .{ 0, 1, 1 << 30 });
            try testArgs(@Vector(3, i16), @Vector(3, u31), .{ 0, 1, 1 << 30 });
            try testArgs(@Vector(3, i32), @Vector(3, u31), .{ 0, 1, 1 << 30 });
            try testArgs(@Vector(3, i64), @Vector(3, u31), .{ 0, 1, 1 << 30 });
            try testArgs(@Vector(3, i128), @Vector(3, u31), .{ 0, 1, 1 << 30 });
            try testArgs(@Vector(3, i256), @Vector(3, u31), .{ 0, 1, 1 << 30 });
            try testArgs(@Vector(3, i512), @Vector(3, u31), .{ 0, 1, 1 << 30 });
            try testArgs(@Vector(3, i1024), @Vector(3, u31), .{ 0, 1, 1 << 30 });

            try testArgs(@Vector(3, u8), @Vector(3, i32), .{ -1 << 31, -1, 0 });
            try testArgs(@Vector(3, u16), @Vector(3, i32), .{ -1 << 31, -1, 0 });
            try testArgs(@Vector(3, u32), @Vector(3, i32), .{ -1 << 31, -1, 0 });
            try testArgs(@Vector(3, u64), @Vector(3, i32), .{ -1 << 31, -1, 0 });
            try testArgs(@Vector(3, u128), @Vector(3, i32), .{ -1 << 31, -1, 0 });
            try testArgs(@Vector(3, u256), @Vector(3, i32), .{ -1 << 31, -1, 0 });
            try testArgs(@Vector(3, u512), @Vector(3, i32), .{ -1 << 31, -1, 0 });
            try testArgs(@Vector(3, u1024), @Vector(3, i32), .{ -1 << 31, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, u32), .{ 0, 1, 1 << 31 });
            try testArgs(@Vector(3, i16), @Vector(3, u32), .{ 0, 1, 1 << 31 });
            try testArgs(@Vector(3, i32), @Vector(3, u32), .{ 0, 1, 1 << 31 });
            try testArgs(@Vector(3, i64), @Vector(3, u32), .{ 0, 1, 1 << 31 });
            try testArgs(@Vector(3, i128), @Vector(3, u32), .{ 0, 1, 1 << 31 });
            try testArgs(@Vector(3, i256), @Vector(3, u32), .{ 0, 1, 1 << 31 });
            try testArgs(@Vector(3, i512), @Vector(3, u32), .{ 0, 1, 1 << 31 });
            try testArgs(@Vector(3, i1024), @Vector(3, u32), .{ 0, 1, 1 << 31 });

            try testArgs(@Vector(3, u8), @Vector(3, i33), .{ -1 << 32, -1, 0 });
            try testArgs(@Vector(3, u16), @Vector(3, i33), .{ -1 << 32, -1, 0 });
            try testArgs(@Vector(3, u32), @Vector(3, i33), .{ -1 << 32, -1, 0 });
            try testArgs(@Vector(3, u64), @Vector(3, i33), .{ -1 << 32, -1, 0 });
            try testArgs(@Vector(3, u128), @Vector(3, i33), .{ -1 << 32, -1, 0 });
            try testArgs(@Vector(3, u256), @Vector(3, i33), .{ -1 << 32, -1, 0 });
            try testArgs(@Vector(3, u512), @Vector(3, i33), .{ -1 << 32, -1, 0 });
            try testArgs(@Vector(3, u1024), @Vector(3, i33), .{ -1 << 32, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, u33), .{ 0, 1, 1 << 32 });
            try testArgs(@Vector(3, i16), @Vector(3, u33), .{ 0, 1, 1 << 32 });
            try testArgs(@Vector(3, i32), @Vector(3, u33), .{ 0, 1, 1 << 32 });
            try testArgs(@Vector(3, i64), @Vector(3, u33), .{ 0, 1, 1 << 32 });
            try testArgs(@Vector(3, i128), @Vector(3, u33), .{ 0, 1, 1 << 32 });
            try testArgs(@Vector(3, i256), @Vector(3, u33), .{ 0, 1, 1 << 32 });
            try testArgs(@Vector(3, i512), @Vector(3, u33), .{ 0, 1, 1 << 32 });
            try testArgs(@Vector(3, i1024), @Vector(3, u33), .{ 0, 1, 1 << 32 });

            try testArgs(@Vector(3, u8), @Vector(3, i63), .{ -1 << 62, -1, 0 });
            try testArgs(@Vector(3, u16), @Vector(3, i63), .{ -1 << 62, -1, 0 });
            try testArgs(@Vector(3, u32), @Vector(3, i63), .{ -1 << 62, -1, 0 });
            try testArgs(@Vector(3, u64), @Vector(3, i63), .{ -1 << 62, -1, 0 });
            try testArgs(@Vector(3, u128), @Vector(3, i63), .{ -1 << 62, -1, 0 });
            try testArgs(@Vector(3, u256), @Vector(3, i63), .{ -1 << 62, -1, 0 });
            try testArgs(@Vector(3, u512), @Vector(3, i63), .{ -1 << 62, -1, 0 });
            try testArgs(@Vector(3, u1024), @Vector(3, i63), .{ -1 << 62, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, u63), .{ 0, 1, 1 << 62 });
            try testArgs(@Vector(3, i16), @Vector(3, u63), .{ 0, 1, 1 << 62 });
            try testArgs(@Vector(3, i32), @Vector(3, u63), .{ 0, 1, 1 << 62 });
            try testArgs(@Vector(3, i64), @Vector(3, u63), .{ 0, 1, 1 << 62 });
            try testArgs(@Vector(3, i128), @Vector(3, u63), .{ 0, 1, 1 << 62 });
            try testArgs(@Vector(3, i256), @Vector(3, u63), .{ 0, 1, 1 << 62 });
            try testArgs(@Vector(3, i512), @Vector(3, u63), .{ 0, 1, 1 << 62 });
            try testArgs(@Vector(3, i1024), @Vector(3, u63), .{ 0, 1, 1 << 62 });

            try testArgs(@Vector(3, u8), @Vector(3, i64), .{ -1 << 63, -1, 0 });
            try testArgs(@Vector(3, u16), @Vector(3, i64), .{ -1 << 63, -1, 0 });
            try testArgs(@Vector(3, u32), @Vector(3, i64), .{ -1 << 63, -1, 0 });
            try testArgs(@Vector(3, u64), @Vector(3, i64), .{ -1 << 63, -1, 0 });
            try testArgs(@Vector(3, u128), @Vector(3, i64), .{ -1 << 63, -1, 0 });
            try testArgs(@Vector(3, u256), @Vector(3, i64), .{ -1 << 63, -1, 0 });
            try testArgs(@Vector(3, u512), @Vector(3, i64), .{ -1 << 63, -1, 0 });
            try testArgs(@Vector(3, u1024), @Vector(3, i64), .{ -1 << 63, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, u64), .{ 0, 1, 1 << 63 });
            try testArgs(@Vector(3, i16), @Vector(3, u64), .{ 0, 1, 1 << 63 });
            try testArgs(@Vector(3, i32), @Vector(3, u64), .{ 0, 1, 1 << 63 });
            try testArgs(@Vector(3, i64), @Vector(3, u64), .{ 0, 1, 1 << 63 });
            try testArgs(@Vector(3, i128), @Vector(3, u64), .{ 0, 1, 1 << 63 });
            try testArgs(@Vector(3, i256), @Vector(3, u64), .{ 0, 1, 1 << 63 });
            try testArgs(@Vector(3, i512), @Vector(3, u64), .{ 0, 1, 1 << 63 });
            try testArgs(@Vector(3, i1024), @Vector(3, u64), .{ 0, 1, 1 << 63 });

            try testArgs(@Vector(3, u8), @Vector(3, i65), .{ -1 << 64, -1, 0 });
            try testArgs(@Vector(3, u16), @Vector(3, i65), .{ -1 << 64, -1, 0 });
            try testArgs(@Vector(3, u32), @Vector(3, i65), .{ -1 << 64, -1, 0 });
            try testArgs(@Vector(3, u64), @Vector(3, i65), .{ -1 << 64, -1, 0 });
            try testArgs(@Vector(3, u128), @Vector(3, i65), .{ -1 << 64, -1, 0 });
            try testArgs(@Vector(3, u256), @Vector(3, i65), .{ -1 << 64, -1, 0 });
            try testArgs(@Vector(3, u512), @Vector(3, i65), .{ -1 << 64, -1, 0 });
            try testArgs(@Vector(3, u1024), @Vector(3, i65), .{ -1 << 64, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, u65), .{ 0, 1, 1 << 64 });
            try testArgs(@Vector(3, i16), @Vector(3, u65), .{ 0, 1, 1 << 64 });
            try testArgs(@Vector(3, i32), @Vector(3, u65), .{ 0, 1, 1 << 64 });
            try testArgs(@Vector(3, i64), @Vector(3, u65), .{ 0, 1, 1 << 64 });
            try testArgs(@Vector(3, i128), @Vector(3, u65), .{ 0, 1, 1 << 64 });
            try testArgs(@Vector(3, i256), @Vector(3, u65), .{ 0, 1, 1 << 64 });
            try testArgs(@Vector(3, i512), @Vector(3, u65), .{ 0, 1, 1 << 64 });
            try testArgs(@Vector(3, i1024), @Vector(3, u65), .{ 0, 1, 1 << 64 });

            try testArgs(@Vector(3, u8), @Vector(3, i95), .{ -1 << 94, -1, 0 });
            try testArgs(@Vector(3, u16), @Vector(3, i95), .{ -1 << 94, -1, 0 });
            try testArgs(@Vector(3, u32), @Vector(3, i95), .{ -1 << 94, -1, 0 });
            try testArgs(@Vector(3, u64), @Vector(3, i95), .{ -1 << 94, -1, 0 });
            try testArgs(@Vector(3, u128), @Vector(3, i95), .{ -1 << 94, -1, 0 });
            try testArgs(@Vector(3, u256), @Vector(3, i95), .{ -1 << 94, -1, 0 });
            try testArgs(@Vector(3, u512), @Vector(3, i95), .{ -1 << 94, -1, 0 });
            try testArgs(@Vector(3, u1024), @Vector(3, i95), .{ -1 << 94, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, u95), .{ 0, 1, 1 << 94 });
            try testArgs(@Vector(3, i16), @Vector(3, u95), .{ 0, 1, 1 << 94 });
            try testArgs(@Vector(3, i32), @Vector(3, u95), .{ 0, 1, 1 << 94 });
            try testArgs(@Vector(3, i64), @Vector(3, u95), .{ 0, 1, 1 << 94 });
            try testArgs(@Vector(3, i128), @Vector(3, u95), .{ 0, 1, 1 << 94 });
            try testArgs(@Vector(3, i256), @Vector(3, u95), .{ 0, 1, 1 << 94 });
            try testArgs(@Vector(3, i512), @Vector(3, u95), .{ 0, 1, 1 << 94 });
            try testArgs(@Vector(3, i1024), @Vector(3, u95), .{ 0, 1, 1 << 94 });

            try testArgs(@Vector(3, u8), @Vector(3, i96), .{ -1 << 95, -1, 0 });
            try testArgs(@Vector(3, u16), @Vector(3, i96), .{ -1 << 95, -1, 0 });
            try testArgs(@Vector(3, u32), @Vector(3, i96), .{ -1 << 95, -1, 0 });
            try testArgs(@Vector(3, u64), @Vector(3, i96), .{ -1 << 95, -1, 0 });
            try testArgs(@Vector(3, u128), @Vector(3, i96), .{ -1 << 95, -1, 0 });
            try testArgs(@Vector(3, u256), @Vector(3, i96), .{ -1 << 95, -1, 0 });
            try testArgs(@Vector(3, u512), @Vector(3, i96), .{ -1 << 95, -1, 0 });
            try testArgs(@Vector(3, u1024), @Vector(3, i96), .{ -1 << 95, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, u96), .{ 0, 1, 1 << 95 });
            try testArgs(@Vector(3, i16), @Vector(3, u96), .{ 0, 1, 1 << 95 });
            try testArgs(@Vector(3, i32), @Vector(3, u96), .{ 0, 1, 1 << 95 });
            try testArgs(@Vector(3, i64), @Vector(3, u96), .{ 0, 1, 1 << 95 });
            try testArgs(@Vector(3, i128), @Vector(3, u96), .{ 0, 1, 1 << 95 });
            try testArgs(@Vector(3, i256), @Vector(3, u96), .{ 0, 1, 1 << 95 });
            try testArgs(@Vector(3, i512), @Vector(3, u96), .{ 0, 1, 1 << 95 });
            try testArgs(@Vector(3, i1024), @Vector(3, u96), .{ 0, 1, 1 << 95 });

            try testArgs(@Vector(3, u8), @Vector(3, i97), .{ -1 << 96, -1, 0 });
            try testArgs(@Vector(3, u16), @Vector(3, i97), .{ -1 << 96, -1, 0 });
            try testArgs(@Vector(3, u32), @Vector(3, i97), .{ -1 << 96, -1, 0 });
            try testArgs(@Vector(3, u64), @Vector(3, i97), .{ -1 << 96, -1, 0 });
            try testArgs(@Vector(3, u128), @Vector(3, i97), .{ -1 << 96, -1, 0 });
            try testArgs(@Vector(3, u256), @Vector(3, i97), .{ -1 << 96, -1, 0 });
            try testArgs(@Vector(3, u512), @Vector(3, i97), .{ -1 << 96, -1, 0 });
            try testArgs(@Vector(3, u1024), @Vector(3, i97), .{ -1 << 96, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, u97), .{ 0, 1, 1 << 96 });
            try testArgs(@Vector(3, i16), @Vector(3, u97), .{ 0, 1, 1 << 96 });
            try testArgs(@Vector(3, i32), @Vector(3, u97), .{ 0, 1, 1 << 96 });
            try testArgs(@Vector(3, i64), @Vector(3, u97), .{ 0, 1, 1 << 96 });
            try testArgs(@Vector(3, i128), @Vector(3, u97), .{ 0, 1, 1 << 96 });
            try testArgs(@Vector(3, i256), @Vector(3, u97), .{ 0, 1, 1 << 96 });
            try testArgs(@Vector(3, i512), @Vector(3, u97), .{ 0, 1, 1 << 96 });
            try testArgs(@Vector(3, i1024), @Vector(3, u97), .{ 0, 1, 1 << 96 });

            try testArgs(@Vector(3, u8), @Vector(3, i127), .{ -1 << 126, -1, 0 });
            try testArgs(@Vector(3, u16), @Vector(3, i127), .{ -1 << 126, -1, 0 });
            try testArgs(@Vector(3, u32), @Vector(3, i127), .{ -1 << 126, -1, 0 });
            try testArgs(@Vector(3, u64), @Vector(3, i127), .{ -1 << 126, -1, 0 });
            try testArgs(@Vector(3, u128), @Vector(3, i127), .{ -1 << 126, -1, 0 });
            try testArgs(@Vector(3, u256), @Vector(3, i127), .{ -1 << 126, -1, 0 });
            try testArgs(@Vector(3, u512), @Vector(3, i127), .{ -1 << 126, -1, 0 });
            try testArgs(@Vector(3, u1024), @Vector(3, i127), .{ -1 << 126, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, u127), .{ 0, 1, 1 << 126 });
            try testArgs(@Vector(3, i16), @Vector(3, u127), .{ 0, 1, 1 << 126 });
            try testArgs(@Vector(3, i32), @Vector(3, u127), .{ 0, 1, 1 << 126 });
            try testArgs(@Vector(3, i64), @Vector(3, u127), .{ 0, 1, 1 << 126 });
            try testArgs(@Vector(3, i128), @Vector(3, u127), .{ 0, 1, 1 << 126 });
            try testArgs(@Vector(3, i256), @Vector(3, u127), .{ 0, 1, 1 << 126 });
            try testArgs(@Vector(3, i512), @Vector(3, u127), .{ 0, 1, 1 << 126 });
            try testArgs(@Vector(3, i1024), @Vector(3, u127), .{ 0, 1, 1 << 126 });

            try testArgs(@Vector(3, u8), @Vector(3, i128), .{ -1 << 127, -1, 0 });
            try testArgs(@Vector(3, u16), @Vector(3, i128), .{ -1 << 127, -1, 0 });
            try testArgs(@Vector(3, u32), @Vector(3, i128), .{ -1 << 127, -1, 0 });
            try testArgs(@Vector(3, u64), @Vector(3, i128), .{ -1 << 127, -1, 0 });
            try testArgs(@Vector(3, u128), @Vector(3, i128), .{ -1 << 127, -1, 0 });
            try testArgs(@Vector(3, u256), @Vector(3, i128), .{ -1 << 127, -1, 0 });
            try testArgs(@Vector(3, u512), @Vector(3, i128), .{ -1 << 127, -1, 0 });
            try testArgs(@Vector(3, u1024), @Vector(3, i128), .{ -1 << 127, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, u128), .{ 0, 1, 1 << 127 });
            try testArgs(@Vector(3, i16), @Vector(3, u128), .{ 0, 1, 1 << 127 });
            try testArgs(@Vector(3, i32), @Vector(3, u128), .{ 0, 1, 1 << 127 });
            try testArgs(@Vector(3, i64), @Vector(3, u128), .{ 0, 1, 1 << 127 });
            try testArgs(@Vector(3, i128), @Vector(3, u128), .{ 0, 1, 1 << 127 });
            try testArgs(@Vector(3, i256), @Vector(3, u128), .{ 0, 1, 1 << 127 });
            try testArgs(@Vector(3, i512), @Vector(3, u128), .{ 0, 1, 1 << 127 });
            try testArgs(@Vector(3, i1024), @Vector(3, u128), .{ 0, 1, 1 << 127 });

            try testArgs(@Vector(3, u8), @Vector(3, i129), .{ -1 << 128, -1, 0 });
            try testArgs(@Vector(3, u16), @Vector(3, i129), .{ -1 << 128, -1, 0 });
            try testArgs(@Vector(3, u32), @Vector(3, i129), .{ -1 << 128, -1, 0 });
            try testArgs(@Vector(3, u64), @Vector(3, i129), .{ -1 << 128, -1, 0 });
            try testArgs(@Vector(3, u128), @Vector(3, i129), .{ -1 << 128, -1, 0 });
            try testArgs(@Vector(3, u256), @Vector(3, i129), .{ -1 << 128, -1, 0 });
            try testArgs(@Vector(3, u512), @Vector(3, i129), .{ -1 << 128, -1, 0 });
            try testArgs(@Vector(3, u1024), @Vector(3, i129), .{ -1 << 128, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, u129), .{ 0, 1, 1 << 128 });
            try testArgs(@Vector(3, i16), @Vector(3, u129), .{ 0, 1, 1 << 128 });
            try testArgs(@Vector(3, i32), @Vector(3, u129), .{ 0, 1, 1 << 128 });
            try testArgs(@Vector(3, i64), @Vector(3, u129), .{ 0, 1, 1 << 128 });
            try testArgs(@Vector(3, i128), @Vector(3, u129), .{ 0, 1, 1 << 128 });
            try testArgs(@Vector(3, i256), @Vector(3, u129), .{ 0, 1, 1 << 128 });
            try testArgs(@Vector(3, i512), @Vector(3, u129), .{ 0, 1, 1 << 128 });
            try testArgs(@Vector(3, i1024), @Vector(3, u129), .{ 0, 1, 1 << 128 });

            try testArgs(@Vector(3, u8), @Vector(3, i159), .{ -1 << 158, -1, 0 });
            try testArgs(@Vector(3, u16), @Vector(3, i159), .{ -1 << 158, -1, 0 });
            try testArgs(@Vector(3, u32), @Vector(3, i159), .{ -1 << 158, -1, 0 });
            try testArgs(@Vector(3, u64), @Vector(3, i159), .{ -1 << 158, -1, 0 });
            try testArgs(@Vector(3, u128), @Vector(3, i159), .{ -1 << 158, -1, 0 });
            try testArgs(@Vector(3, u256), @Vector(3, i159), .{ -1 << 158, -1, 0 });
            try testArgs(@Vector(3, u512), @Vector(3, i159), .{ -1 << 158, -1, 0 });
            try testArgs(@Vector(3, u1024), @Vector(3, i159), .{ -1 << 158, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, u159), .{ 0, 1, 1 << 158 });
            try testArgs(@Vector(3, i16), @Vector(3, u159), .{ 0, 1, 1 << 158 });
            try testArgs(@Vector(3, i32), @Vector(3, u159), .{ 0, 1, 1 << 158 });
            try testArgs(@Vector(3, i64), @Vector(3, u159), .{ 0, 1, 1 << 158 });
            try testArgs(@Vector(3, i128), @Vector(3, u159), .{ 0, 1, 1 << 158 });
            try testArgs(@Vector(3, i256), @Vector(3, u159), .{ 0, 1, 1 << 158 });
            try testArgs(@Vector(3, i512), @Vector(3, u159), .{ 0, 1, 1 << 158 });
            try testArgs(@Vector(3, i1024), @Vector(3, u159), .{ 0, 1, 1 << 158 });

            try testArgs(@Vector(3, u8), @Vector(3, i160), .{ -1 << 159, -1, 0 });
            try testArgs(@Vector(3, u16), @Vector(3, i160), .{ -1 << 159, -1, 0 });
            try testArgs(@Vector(3, u32), @Vector(3, i160), .{ -1 << 159, -1, 0 });
            try testArgs(@Vector(3, u64), @Vector(3, i160), .{ -1 << 159, -1, 0 });
            try testArgs(@Vector(3, u128), @Vector(3, i160), .{ -1 << 159, -1, 0 });
            try testArgs(@Vector(3, u256), @Vector(3, i160), .{ -1 << 159, -1, 0 });
            try testArgs(@Vector(3, u512), @Vector(3, i160), .{ -1 << 159, -1, 0 });
            try testArgs(@Vector(3, u1024), @Vector(3, i160), .{ -1 << 159, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, u160), .{ 0, 1, 1 << 159 });
            try testArgs(@Vector(3, i16), @Vector(3, u160), .{ 0, 1, 1 << 159 });
            try testArgs(@Vector(3, i32), @Vector(3, u160), .{ 0, 1, 1 << 159 });
            try testArgs(@Vector(3, i64), @Vector(3, u160), .{ 0, 1, 1 << 159 });
            try testArgs(@Vector(3, i128), @Vector(3, u160), .{ 0, 1, 1 << 159 });
            try testArgs(@Vector(3, i256), @Vector(3, u160), .{ 0, 1, 1 << 159 });
            try testArgs(@Vector(3, i512), @Vector(3, u160), .{ 0, 1, 1 << 159 });
            try testArgs(@Vector(3, i1024), @Vector(3, u160), .{ 0, 1, 1 << 159 });

            try testArgs(@Vector(3, u8), @Vector(3, i161), .{ -1 << 160, -1, 0 });
            try testArgs(@Vector(3, u16), @Vector(3, i161), .{ -1 << 160, -1, 0 });
            try testArgs(@Vector(3, u32), @Vector(3, i161), .{ -1 << 160, -1, 0 });
            try testArgs(@Vector(3, u64), @Vector(3, i161), .{ -1 << 160, -1, 0 });
            try testArgs(@Vector(3, u128), @Vector(3, i161), .{ -1 << 160, -1, 0 });
            try testArgs(@Vector(3, u256), @Vector(3, i161), .{ -1 << 160, -1, 0 });
            try testArgs(@Vector(3, u512), @Vector(3, i161), .{ -1 << 160, -1, 0 });
            try testArgs(@Vector(3, u1024), @Vector(3, i161), .{ -1 << 160, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, u161), .{ 0, 1, 1 << 160 });
            try testArgs(@Vector(3, i16), @Vector(3, u161), .{ 0, 1, 1 << 160 });
            try testArgs(@Vector(3, i32), @Vector(3, u161), .{ 0, 1, 1 << 160 });
            try testArgs(@Vector(3, i64), @Vector(3, u161), .{ 0, 1, 1 << 160 });
            try testArgs(@Vector(3, i128), @Vector(3, u161), .{ 0, 1, 1 << 160 });
            try testArgs(@Vector(3, i256), @Vector(3, u161), .{ 0, 1, 1 << 160 });
            try testArgs(@Vector(3, i512), @Vector(3, u161), .{ 0, 1, 1 << 160 });
            try testArgs(@Vector(3, i1024), @Vector(3, u161), .{ 0, 1, 1 << 160 });

            try testArgs(@Vector(3, u8), @Vector(3, i191), .{ -1 << 190, -1, 0 });
            try testArgs(@Vector(3, u16), @Vector(3, i191), .{ -1 << 190, -1, 0 });
            try testArgs(@Vector(3, u32), @Vector(3, i191), .{ -1 << 190, -1, 0 });
            try testArgs(@Vector(3, u64), @Vector(3, i191), .{ -1 << 190, -1, 0 });
            try testArgs(@Vector(3, u128), @Vector(3, i191), .{ -1 << 190, -1, 0 });
            try testArgs(@Vector(3, u256), @Vector(3, i191), .{ -1 << 190, -1, 0 });
            try testArgs(@Vector(3, u512), @Vector(3, i191), .{ -1 << 190, -1, 0 });
            try testArgs(@Vector(3, u1024), @Vector(3, i191), .{ -1 << 190, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, u191), .{ 0, 1, 1 << 190 });
            try testArgs(@Vector(3, i16), @Vector(3, u191), .{ 0, 1, 1 << 190 });
            try testArgs(@Vector(3, i32), @Vector(3, u191), .{ 0, 1, 1 << 190 });
            try testArgs(@Vector(3, i64), @Vector(3, u191), .{ 0, 1, 1 << 190 });
            try testArgs(@Vector(3, i128), @Vector(3, u191), .{ 0, 1, 1 << 190 });
            try testArgs(@Vector(3, i256), @Vector(3, u191), .{ 0, 1, 1 << 190 });
            try testArgs(@Vector(3, i512), @Vector(3, u191), .{ 0, 1, 1 << 190 });
            try testArgs(@Vector(3, i1024), @Vector(3, u191), .{ 0, 1, 1 << 190 });

            try testArgs(@Vector(3, u8), @Vector(3, i192), .{ -1 << 191, -1, 0 });
            try testArgs(@Vector(3, u16), @Vector(3, i192), .{ -1 << 191, -1, 0 });
            try testArgs(@Vector(3, u32), @Vector(3, i192), .{ -1 << 191, -1, 0 });
            try testArgs(@Vector(3, u64), @Vector(3, i192), .{ -1 << 191, -1, 0 });
            try testArgs(@Vector(3, u128), @Vector(3, i192), .{ -1 << 191, -1, 0 });
            try testArgs(@Vector(3, u256), @Vector(3, i192), .{ -1 << 191, -1, 0 });
            try testArgs(@Vector(3, u512), @Vector(3, i192), .{ -1 << 191, -1, 0 });
            try testArgs(@Vector(3, u1024), @Vector(3, i192), .{ -1 << 191, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, u192), .{ 0, 1, 1 << 191 });
            try testArgs(@Vector(3, i16), @Vector(3, u192), .{ 0, 1, 1 << 191 });
            try testArgs(@Vector(3, i32), @Vector(3, u192), .{ 0, 1, 1 << 191 });
            try testArgs(@Vector(3, i64), @Vector(3, u192), .{ 0, 1, 1 << 191 });
            try testArgs(@Vector(3, i128), @Vector(3, u192), .{ 0, 1, 1 << 191 });
            try testArgs(@Vector(3, i256), @Vector(3, u192), .{ 0, 1, 1 << 191 });
            try testArgs(@Vector(3, i512), @Vector(3, u192), .{ 0, 1, 1 << 191 });
            try testArgs(@Vector(3, i1024), @Vector(3, u192), .{ 0, 1, 1 << 191 });

            try testArgs(@Vector(3, u8), @Vector(3, i193), .{ -1 << 192, -1, 0 });
            try testArgs(@Vector(3, u16), @Vector(3, i193), .{ -1 << 192, -1, 0 });
            try testArgs(@Vector(3, u32), @Vector(3, i193), .{ -1 << 192, -1, 0 });
            try testArgs(@Vector(3, u64), @Vector(3, i193), .{ -1 << 192, -1, 0 });
            try testArgs(@Vector(3, u128), @Vector(3, i193), .{ -1 << 192, -1, 0 });
            try testArgs(@Vector(3, u256), @Vector(3, i193), .{ -1 << 192, -1, 0 });
            try testArgs(@Vector(3, u512), @Vector(3, i193), .{ -1 << 192, -1, 0 });
            try testArgs(@Vector(3, u1024), @Vector(3, i193), .{ -1 << 192, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, u193), .{ 0, 1, 1 << 192 });
            try testArgs(@Vector(3, i16), @Vector(3, u193), .{ 0, 1, 1 << 192 });
            try testArgs(@Vector(3, i32), @Vector(3, u193), .{ 0, 1, 1 << 192 });
            try testArgs(@Vector(3, i64), @Vector(3, u193), .{ 0, 1, 1 << 192 });
            try testArgs(@Vector(3, i128), @Vector(3, u193), .{ 0, 1, 1 << 192 });
            try testArgs(@Vector(3, i256), @Vector(3, u193), .{ 0, 1, 1 << 192 });
            try testArgs(@Vector(3, i512), @Vector(3, u193), .{ 0, 1, 1 << 192 });
            try testArgs(@Vector(3, i1024), @Vector(3, u193), .{ 0, 1, 1 << 192 });

            try testArgs(@Vector(3, u8), @Vector(3, i223), .{ -1 << 222, -1, 0 });
            try testArgs(@Vector(3, u16), @Vector(3, i223), .{ -1 << 222, -1, 0 });
            try testArgs(@Vector(3, u32), @Vector(3, i223), .{ -1 << 222, -1, 0 });
            try testArgs(@Vector(3, u64), @Vector(3, i223), .{ -1 << 222, -1, 0 });
            try testArgs(@Vector(3, u128), @Vector(3, i223), .{ -1 << 222, -1, 0 });
            try testArgs(@Vector(3, u256), @Vector(3, i223), .{ -1 << 222, -1, 0 });
            try testArgs(@Vector(3, u512), @Vector(3, i223), .{ -1 << 222, -1, 0 });
            try testArgs(@Vector(3, u1024), @Vector(3, i223), .{ -1 << 222, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, u223), .{ 0, 1, 1 << 222 });
            try testArgs(@Vector(3, i16), @Vector(3, u223), .{ 0, 1, 1 << 222 });
            try testArgs(@Vector(3, i32), @Vector(3, u223), .{ 0, 1, 1 << 222 });
            try testArgs(@Vector(3, i64), @Vector(3, u223), .{ 0, 1, 1 << 222 });
            try testArgs(@Vector(3, i128), @Vector(3, u223), .{ 0, 1, 1 << 222 });
            try testArgs(@Vector(3, i256), @Vector(3, u223), .{ 0, 1, 1 << 222 });
            try testArgs(@Vector(3, i512), @Vector(3, u223), .{ 0, 1, 1 << 222 });
            try testArgs(@Vector(3, i1024), @Vector(3, u223), .{ 0, 1, 1 << 222 });

            try testArgs(@Vector(3, u8), @Vector(3, i224), .{ -1 << 223, -1, 0 });
            try testArgs(@Vector(3, u16), @Vector(3, i224), .{ -1 << 223, -1, 0 });
            try testArgs(@Vector(3, u32), @Vector(3, i224), .{ -1 << 223, -1, 0 });
            try testArgs(@Vector(3, u64), @Vector(3, i224), .{ -1 << 223, -1, 0 });
            try testArgs(@Vector(3, u128), @Vector(3, i224), .{ -1 << 223, -1, 0 });
            try testArgs(@Vector(3, u256), @Vector(3, i224), .{ -1 << 223, -1, 0 });
            try testArgs(@Vector(3, u512), @Vector(3, i224), .{ -1 << 223, -1, 0 });
            try testArgs(@Vector(3, u1024), @Vector(3, i224), .{ -1 << 223, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, u224), .{ 0, 1, 1 << 223 });
            try testArgs(@Vector(3, i16), @Vector(3, u224), .{ 0, 1, 1 << 223 });
            try testArgs(@Vector(3, i32), @Vector(3, u224), .{ 0, 1, 1 << 223 });
            try testArgs(@Vector(3, i64), @Vector(3, u224), .{ 0, 1, 1 << 223 });
            try testArgs(@Vector(3, i128), @Vector(3, u224), .{ 0, 1, 1 << 223 });
            try testArgs(@Vector(3, i256), @Vector(3, u224), .{ 0, 1, 1 << 223 });
            try testArgs(@Vector(3, i512), @Vector(3, u224), .{ 0, 1, 1 << 223 });
            try testArgs(@Vector(3, i1024), @Vector(3, u224), .{ 0, 1, 1 << 223 });

            try testArgs(@Vector(3, u8), @Vector(3, i225), .{ -1 << 224, -1, 0 });
            try testArgs(@Vector(3, u16), @Vector(3, i225), .{ -1 << 224, -1, 0 });
            try testArgs(@Vector(3, u32), @Vector(3, i225), .{ -1 << 224, -1, 0 });
            try testArgs(@Vector(3, u64), @Vector(3, i225), .{ -1 << 224, -1, 0 });
            try testArgs(@Vector(3, u128), @Vector(3, i225), .{ -1 << 224, -1, 0 });
            try testArgs(@Vector(3, u256), @Vector(3, i225), .{ -1 << 224, -1, 0 });
            try testArgs(@Vector(3, u512), @Vector(3, i225), .{ -1 << 224, -1, 0 });
            try testArgs(@Vector(3, u1024), @Vector(3, i225), .{ -1 << 224, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, u225), .{ 0, 1, 1 << 224 });
            try testArgs(@Vector(3, i16), @Vector(3, u225), .{ 0, 1, 1 << 224 });
            try testArgs(@Vector(3, i32), @Vector(3, u225), .{ 0, 1, 1 << 224 });
            try testArgs(@Vector(3, i64), @Vector(3, u225), .{ 0, 1, 1 << 224 });
            try testArgs(@Vector(3, i128), @Vector(3, u225), .{ 0, 1, 1 << 224 });
            try testArgs(@Vector(3, i256), @Vector(3, u225), .{ 0, 1, 1 << 224 });
            try testArgs(@Vector(3, i512), @Vector(3, u225), .{ 0, 1, 1 << 224 });
            try testArgs(@Vector(3, i1024), @Vector(3, u225), .{ 0, 1, 1 << 224 });

            try testArgs(@Vector(3, u8), @Vector(3, i255), .{ -1 << 254, -1, 0 });
            try testArgs(@Vector(3, u16), @Vector(3, i255), .{ -1 << 254, -1, 0 });
            try testArgs(@Vector(3, u32), @Vector(3, i255), .{ -1 << 254, -1, 0 });
            try testArgs(@Vector(3, u64), @Vector(3, i255), .{ -1 << 254, -1, 0 });
            try testArgs(@Vector(3, u128), @Vector(3, i255), .{ -1 << 254, -1, 0 });
            try testArgs(@Vector(3, u256), @Vector(3, i255), .{ -1 << 254, -1, 0 });
            try testArgs(@Vector(3, u512), @Vector(3, i255), .{ -1 << 254, -1, 0 });
            try testArgs(@Vector(3, u1024), @Vector(3, i255), .{ -1 << 254, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, u255), .{ 0, 1, 1 << 254 });
            try testArgs(@Vector(3, i16), @Vector(3, u255), .{ 0, 1, 1 << 254 });
            try testArgs(@Vector(3, i32), @Vector(3, u255), .{ 0, 1, 1 << 254 });
            try testArgs(@Vector(3, i64), @Vector(3, u255), .{ 0, 1, 1 << 254 });
            try testArgs(@Vector(3, i128), @Vector(3, u255), .{ 0, 1, 1 << 254 });
            try testArgs(@Vector(3, i256), @Vector(3, u255), .{ 0, 1, 1 << 254 });
            try testArgs(@Vector(3, i512), @Vector(3, u255), .{ 0, 1, 1 << 254 });
            try testArgs(@Vector(3, i1024), @Vector(3, u255), .{ 0, 1, 1 << 254 });

            try testArgs(@Vector(3, u8), @Vector(3, i256), .{ -1 << 255, -1, 0 });
            try testArgs(@Vector(3, u16), @Vector(3, i256), .{ -1 << 255, -1, 0 });
            try testArgs(@Vector(3, u32), @Vector(3, i256), .{ -1 << 255, -1, 0 });
            try testArgs(@Vector(3, u64), @Vector(3, i256), .{ -1 << 255, -1, 0 });
            try testArgs(@Vector(3, u128), @Vector(3, i256), .{ -1 << 255, -1, 0 });
            try testArgs(@Vector(3, u256), @Vector(3, i256), .{ -1 << 255, -1, 0 });
            try testArgs(@Vector(3, u512), @Vector(3, i256), .{ -1 << 255, -1, 0 });
            try testArgs(@Vector(3, u1024), @Vector(3, i256), .{ -1 << 255, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, u256), .{ 0, 1, 1 << 255 });
            try testArgs(@Vector(3, i16), @Vector(3, u256), .{ 0, 1, 1 << 255 });
            try testArgs(@Vector(3, i32), @Vector(3, u256), .{ 0, 1, 1 << 255 });
            try testArgs(@Vector(3, i64), @Vector(3, u256), .{ 0, 1, 1 << 255 });
            try testArgs(@Vector(3, i128), @Vector(3, u256), .{ 0, 1, 1 << 255 });
            try testArgs(@Vector(3, i256), @Vector(3, u256), .{ 0, 1, 1 << 255 });
            try testArgs(@Vector(3, i512), @Vector(3, u256), .{ 0, 1, 1 << 255 });
            try testArgs(@Vector(3, i1024), @Vector(3, u256), .{ 0, 1, 1 << 255 });

            try testArgs(@Vector(3, u8), @Vector(3, i257), .{ -1 << 256, -1, 0 });
            try testArgs(@Vector(3, u16), @Vector(3, i257), .{ -1 << 256, -1, 0 });
            try testArgs(@Vector(3, u32), @Vector(3, i257), .{ -1 << 256, -1, 0 });
            try testArgs(@Vector(3, u64), @Vector(3, i257), .{ -1 << 256, -1, 0 });
            try testArgs(@Vector(3, u128), @Vector(3, i257), .{ -1 << 256, -1, 0 });
            try testArgs(@Vector(3, u256), @Vector(3, i257), .{ -1 << 256, -1, 0 });
            try testArgs(@Vector(3, u512), @Vector(3, i257), .{ -1 << 256, -1, 0 });
            try testArgs(@Vector(3, u1024), @Vector(3, i257), .{ -1 << 256, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, u257), .{ 0, 1, 1 << 256 });
            try testArgs(@Vector(3, i16), @Vector(3, u257), .{ 0, 1, 1 << 256 });
            try testArgs(@Vector(3, i32), @Vector(3, u257), .{ 0, 1, 1 << 256 });
            try testArgs(@Vector(3, i64), @Vector(3, u257), .{ 0, 1, 1 << 256 });
            try testArgs(@Vector(3, i128), @Vector(3, u257), .{ 0, 1, 1 << 256 });
            try testArgs(@Vector(3, i256), @Vector(3, u257), .{ 0, 1, 1 << 256 });
            try testArgs(@Vector(3, i512), @Vector(3, u257), .{ 0, 1, 1 << 256 });
            try testArgs(@Vector(3, i1024), @Vector(3, u257), .{ 0, 1, 1 << 256 });

            try testArgs(@Vector(3, u8), @Vector(3, i511), .{ -1 << 510, -1, 0 });
            try testArgs(@Vector(3, u16), @Vector(3, i511), .{ -1 << 510, -1, 0 });
            try testArgs(@Vector(3, u32), @Vector(3, i511), .{ -1 << 510, -1, 0 });
            try testArgs(@Vector(3, u64), @Vector(3, i511), .{ -1 << 510, -1, 0 });
            try testArgs(@Vector(3, u128), @Vector(3, i511), .{ -1 << 510, -1, 0 });
            try testArgs(@Vector(3, u256), @Vector(3, i511), .{ -1 << 510, -1, 0 });
            try testArgs(@Vector(3, u512), @Vector(3, i511), .{ -1 << 510, -1, 0 });
            try testArgs(@Vector(3, u1024), @Vector(3, i511), .{ -1 << 510, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, u511), .{ 0, 1, 1 << 510 });
            try testArgs(@Vector(3, i16), @Vector(3, u511), .{ 0, 1, 1 << 510 });
            try testArgs(@Vector(3, i32), @Vector(3, u511), .{ 0, 1, 1 << 510 });
            try testArgs(@Vector(3, i64), @Vector(3, u511), .{ 0, 1, 1 << 510 });
            try testArgs(@Vector(3, i128), @Vector(3, u511), .{ 0, 1, 1 << 510 });
            try testArgs(@Vector(3, i256), @Vector(3, u511), .{ 0, 1, 1 << 510 });
            try testArgs(@Vector(3, i512), @Vector(3, u511), .{ 0, 1, 1 << 510 });
            try testArgs(@Vector(3, i1024), @Vector(3, u511), .{ 0, 1, 1 << 510 });

            try testArgs(@Vector(3, u8), @Vector(3, i512), .{ -1 << 511, -1, 0 });
            try testArgs(@Vector(3, u16), @Vector(3, i512), .{ -1 << 511, -1, 0 });
            try testArgs(@Vector(3, u32), @Vector(3, i512), .{ -1 << 511, -1, 0 });
            try testArgs(@Vector(3, u64), @Vector(3, i512), .{ -1 << 511, -1, 0 });
            try testArgs(@Vector(3, u128), @Vector(3, i512), .{ -1 << 511, -1, 0 });
            try testArgs(@Vector(3, u256), @Vector(3, i512), .{ -1 << 511, -1, 0 });
            try testArgs(@Vector(3, u512), @Vector(3, i512), .{ -1 << 511, -1, 0 });
            try testArgs(@Vector(3, u1024), @Vector(3, i512), .{ -1 << 511, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, u512), .{ 0, 1, 1 << 511 });
            try testArgs(@Vector(3, i16), @Vector(3, u512), .{ 0, 1, 1 << 511 });
            try testArgs(@Vector(3, i32), @Vector(3, u512), .{ 0, 1, 1 << 511 });
            try testArgs(@Vector(3, i64), @Vector(3, u512), .{ 0, 1, 1 << 511 });
            try testArgs(@Vector(3, i128), @Vector(3, u512), .{ 0, 1, 1 << 511 });
            try testArgs(@Vector(3, i256), @Vector(3, u512), .{ 0, 1, 1 << 511 });
            try testArgs(@Vector(3, i512), @Vector(3, u512), .{ 0, 1, 1 << 511 });
            try testArgs(@Vector(3, i1024), @Vector(3, u512), .{ 0, 1, 1 << 511 });

            try testArgs(@Vector(3, u8), @Vector(3, i513), .{ -1 << 512, -1, 0 });
            try testArgs(@Vector(3, u16), @Vector(3, i513), .{ -1 << 512, -1, 0 });
            try testArgs(@Vector(3, u32), @Vector(3, i513), .{ -1 << 512, -1, 0 });
            try testArgs(@Vector(3, u64), @Vector(3, i513), .{ -1 << 512, -1, 0 });
            try testArgs(@Vector(3, u128), @Vector(3, i513), .{ -1 << 512, -1, 0 });
            try testArgs(@Vector(3, u256), @Vector(3, i513), .{ -1 << 512, -1, 0 });
            try testArgs(@Vector(3, u512), @Vector(3, i513), .{ -1 << 512, -1, 0 });
            try testArgs(@Vector(3, u1024), @Vector(3, i513), .{ -1 << 512, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, u513), .{ 0, 1, 1 << 512 });
            try testArgs(@Vector(3, i16), @Vector(3, u513), .{ 0, 1, 1 << 512 });
            try testArgs(@Vector(3, i32), @Vector(3, u513), .{ 0, 1, 1 << 512 });
            try testArgs(@Vector(3, i64), @Vector(3, u513), .{ 0, 1, 1 << 512 });
            try testArgs(@Vector(3, i128), @Vector(3, u513), .{ 0, 1, 1 << 512 });
            try testArgs(@Vector(3, i256), @Vector(3, u513), .{ 0, 1, 1 << 512 });
            try testArgs(@Vector(3, i512), @Vector(3, u513), .{ 0, 1, 1 << 512 });
            try testArgs(@Vector(3, i1024), @Vector(3, u513), .{ 0, 1, 1 << 512 });

            try testArgs(@Vector(3, u8), @Vector(3, i1023), .{ -1 << 1022, -1, 0 });
            try testArgs(@Vector(3, u16), @Vector(3, i1023), .{ -1 << 1022, -1, 0 });
            try testArgs(@Vector(3, u32), @Vector(3, i1023), .{ -1 << 1022, -1, 0 });
            try testArgs(@Vector(3, u64), @Vector(3, i1023), .{ -1 << 1022, -1, 0 });
            try testArgs(@Vector(3, u128), @Vector(3, i1023), .{ -1 << 1022, -1, 0 });
            try testArgs(@Vector(3, u256), @Vector(3, i1023), .{ -1 << 1022, -1, 0 });
            try testArgs(@Vector(3, u512), @Vector(3, i1023), .{ -1 << 1022, -1, 0 });
            try testArgs(@Vector(3, u1024), @Vector(3, i1023), .{ -1 << 1022, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, u1023), .{ 0, 1, 1 << 1022 });
            try testArgs(@Vector(3, i16), @Vector(3, u1023), .{ 0, 1, 1 << 1022 });
            try testArgs(@Vector(3, i32), @Vector(3, u1023), .{ 0, 1, 1 << 1022 });
            try testArgs(@Vector(3, i64), @Vector(3, u1023), .{ 0, 1, 1 << 1022 });
            try testArgs(@Vector(3, i128), @Vector(3, u1023), .{ 0, 1, 1 << 1022 });
            try testArgs(@Vector(3, i256), @Vector(3, u1023), .{ 0, 1, 1 << 1022 });
            try testArgs(@Vector(3, i512), @Vector(3, u1023), .{ 0, 1, 1 << 1022 });
            try testArgs(@Vector(3, i1024), @Vector(3, u1023), .{ 0, 1, 1 << 1022 });

            try testArgs(@Vector(3, u8), @Vector(3, i1024), .{ -1 << 1023, -1, 0 });
            try testArgs(@Vector(3, u16), @Vector(3, i1024), .{ -1 << 1023, -1, 0 });
            try testArgs(@Vector(3, u32), @Vector(3, i1024), .{ -1 << 1023, -1, 0 });
            try testArgs(@Vector(3, u64), @Vector(3, i1024), .{ -1 << 1023, -1, 0 });
            try testArgs(@Vector(3, u128), @Vector(3, i1024), .{ -1 << 1023, -1, 0 });
            try testArgs(@Vector(3, u256), @Vector(3, i1024), .{ -1 << 1023, -1, 0 });
            try testArgs(@Vector(3, u512), @Vector(3, i1024), .{ -1 << 1023, -1, 0 });
            try testArgs(@Vector(3, u1024), @Vector(3, i1024), .{ -1 << 1023, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, u1024), .{ 0, 1, 1 << 1023 });
            try testArgs(@Vector(3, i16), @Vector(3, u1024), .{ 0, 1, 1 << 1023 });
            try testArgs(@Vector(3, i32), @Vector(3, u1024), .{ 0, 1, 1 << 1023 });
            try testArgs(@Vector(3, i64), @Vector(3, u1024), .{ 0, 1, 1 << 1023 });
            try testArgs(@Vector(3, i128), @Vector(3, u1024), .{ 0, 1, 1 << 1023 });
            try testArgs(@Vector(3, i256), @Vector(3, u1024), .{ 0, 1, 1 << 1023 });
            try testArgs(@Vector(3, i512), @Vector(3, u1024), .{ 0, 1, 1 << 1023 });
            try testArgs(@Vector(3, i1024), @Vector(3, u1024), .{ 0, 1, 1 << 1023 });

            try testArgs(@Vector(3, u8), @Vector(3, i1025), .{ -1 << 1024, -1, 0 });
            try testArgs(@Vector(3, u16), @Vector(3, i1025), .{ -1 << 1024, -1, 0 });
            try testArgs(@Vector(3, u32), @Vector(3, i1025), .{ -1 << 1024, -1, 0 });
            try testArgs(@Vector(3, u64), @Vector(3, i1025), .{ -1 << 1024, -1, 0 });
            try testArgs(@Vector(3, u128), @Vector(3, i1025), .{ -1 << 1024, -1, 0 });
            try testArgs(@Vector(3, u256), @Vector(3, i1025), .{ -1 << 1024, -1, 0 });
            try testArgs(@Vector(3, u512), @Vector(3, i1025), .{ -1 << 1024, -1, 0 });
            try testArgs(@Vector(3, u1024), @Vector(3, i1025), .{ -1 << 1024, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, u1025), .{ 0, 1, 1 << 1024 });
            try testArgs(@Vector(3, i16), @Vector(3, u1025), .{ 0, 1, 1 << 1024 });
            try testArgs(@Vector(3, i32), @Vector(3, u1025), .{ 0, 1, 1 << 1024 });
            try testArgs(@Vector(3, i64), @Vector(3, u1025), .{ 0, 1, 1 << 1024 });
            try testArgs(@Vector(3, i128), @Vector(3, u1025), .{ 0, 1, 1 << 1024 });
            try testArgs(@Vector(3, i256), @Vector(3, u1025), .{ 0, 1, 1 << 1024 });
            try testArgs(@Vector(3, i512), @Vector(3, u1025), .{ 0, 1, 1 << 1024 });
            try testArgs(@Vector(3, i1024), @Vector(3, u1025), .{ 0, 1, 1 << 1024 });
        }
        fn testFloatVectors() !void {
            @setEvalBranchQuota(6_700);

            try testArgs(@Vector(1, f16), @Vector(1, f16), .{
                1e0,
            });
            try testArgs(@Vector(2, f16), @Vector(2, f16), .{
                -inf(f16), -1e-2,
            });
            try testArgs(@Vector(4, f16), @Vector(4, f16), .{
                -1e2, 1e-1, fmax(f16), 1e-2,
            });
            try testArgs(@Vector(8, f16), @Vector(8, f16), .{
                -1e-1, tmin(f16), -1e3, fmin(f16), nan(f16), -1e-3, 1e1, 1e4,
            });
            try testArgs(@Vector(16, f16), @Vector(16, f16), .{
                -fmax(f16), -1e0, 1e-4, 1e2, -fmin(f16), -1e1, 0.0, -1e4, -0.0, 1e3, -nan(f16), -tmin(f16), -1e-4, inf(f16), 1e-3, -1e-1,
            });
            try testArgs(@Vector(32, f16), @Vector(32, f16), .{
                -1e3, -tmin(f16), inf(f16),   -1e4,      -0.0, fmax(f16), 1e2,       1e4, -nan(f16), 0.0,        -1e-4, -1e1, 1e0,   1e-1, nan(f16), -1e0,
                1e3,  -1e-3,      -fmin(f16), -inf(f16), 1e-3, tmin(f16), fmin(f16), 1e1, 1e-4,      -fmax(f16), -1e2,  1e-2, -1e-2, 1e3,  inf(f16), -fmin(f16),
            });

            try testArgs(@Vector(1, f32), @Vector(1, f16), .{
                1e0,
            });
            try testArgs(@Vector(2, f32), @Vector(2, f16), .{
                -inf(f16), -1e-2,
            });
            try testArgs(@Vector(4, f32), @Vector(4, f16), .{
                -1e2, 1e-1, fmax(f16), 1e-2,
            });
            try testArgs(@Vector(8, f32), @Vector(8, f16), .{
                -1e-1, tmin(f16), -1e3, fmin(f16), nan(f16), -1e-3, 1e1, 1e4,
            });
            try testArgs(@Vector(16, f32), @Vector(16, f16), .{
                -fmax(f16), -1e0, 1e-4, 1e2, -fmin(f16), -1e1, 0.0, -1e4, -0.0, 1e3, -nan(f16), -tmin(f16), -1e-4, inf(f16), 1e-3, -1e-1,
            });
            try testArgs(@Vector(32, f32), @Vector(32, f16), .{
                -1e3, -tmin(f16), inf(f16),   -1e4,      -0.0, fmax(f16), 1e2,       1e4, -nan(f16), 0.0,        -1e-4, -1e1, 1e0,   1e-1, nan(f16), -1e0,
                1e3,  -1e-3,      -fmin(f16), -inf(f16), 1e-3, tmin(f16), fmin(f16), 1e1, 1e-4,      -fmax(f16), -1e2,  1e-2, -1e-2, 1e3,  inf(f16), -fmin(f16),
            });

            try testArgs(@Vector(1, f64), @Vector(1, f16), .{
                1e0,
            });
            try testArgs(@Vector(2, f64), @Vector(2, f16), .{
                -inf(f16), -1e-2,
            });
            try testArgs(@Vector(4, f64), @Vector(4, f16), .{
                -1e2, 1e-1, fmax(f16), 1e-2,
            });
            try testArgs(@Vector(8, f64), @Vector(8, f16), .{
                -1e-1, tmin(f16), -1e3, fmin(f16), nan(f16), -1e-3, 1e1, 1e4,
            });
            try testArgs(@Vector(16, f64), @Vector(16, f16), .{
                -fmax(f16), -1e0, 1e-4, 1e2, -fmin(f16), -1e1, 0.0, -1e4, -0.0, 1e3, -nan(f16), -tmin(f16), -1e-4, inf(f16), 1e-3, -1e-1,
            });
            try testArgs(@Vector(32, f64), @Vector(32, f16), .{
                -1e3, -tmin(f16), inf(f16),   -1e4,      -0.0, fmax(f16), 1e2,       1e4, -nan(f16), 0.0,        -1e-4, -1e1, 1e0,   1e-1, nan(f16), -1e0,
                1e3,  -1e-3,      -fmin(f16), -inf(f16), 1e-3, tmin(f16), fmin(f16), 1e1, 1e-4,      -fmax(f16), -1e2,  1e-2, -1e-2, 1e3,  inf(f16), -fmin(f16),
            });

            try testArgs(@Vector(1, f80), @Vector(1, f16), .{
                1e0,
            });
            try testArgs(@Vector(2, f80), @Vector(2, f16), .{
                -inf(f16), -1e-2,
            });
            try testArgs(@Vector(4, f80), @Vector(4, f16), .{
                -1e2, 1e-1, fmax(f16), 1e-2,
            });
            try testArgs(@Vector(8, f80), @Vector(8, f16), .{
                -1e-1, tmin(f16), -1e3, fmin(f16), nan(f16), -1e-3, 1e1, 1e4,
            });
            try testArgs(@Vector(16, f80), @Vector(16, f16), .{
                -fmax(f16), -1e0, 1e-4, 1e2, -fmin(f16), -1e1, 0.0, -1e4, -0.0, 1e3, -nan(f16), -tmin(f16), -1e-4, inf(f16), 1e-3, -1e-1,
            });
            try testArgs(@Vector(32, f80), @Vector(32, f16), .{
                -1e3, -tmin(f16), inf(f16),   -1e4,      -0.0, fmax(f16), 1e2,       1e4, -nan(f16), 0.0,        -1e-4, -1e1, 1e0,   1e-1, nan(f16), -1e0,
                1e3,  -1e-3,      -fmin(f16), -inf(f16), 1e-3, tmin(f16), fmin(f16), 1e1, 1e-4,      -fmax(f16), -1e2,  1e-2, -1e-2, 1e3,  inf(f16), -fmin(f16),
            });

            try testArgs(@Vector(1, f128), @Vector(1, f16), .{
                1e0,
            });
            try testArgs(@Vector(2, f128), @Vector(2, f16), .{
                -inf(f16), -1e-2,
            });
            try testArgs(@Vector(4, f128), @Vector(4, f16), .{
                -1e2, 1e-1, fmax(f16), 1e-2,
            });
            try testArgs(@Vector(8, f128), @Vector(8, f16), .{
                -1e-1, tmin(f16), -1e3, fmin(f16), nan(f16), -1e-3, 1e1, 1e4,
            });
            try testArgs(@Vector(16, f128), @Vector(16, f16), .{
                -fmax(f16), -1e0, 1e-4, 1e2, -fmin(f16), -1e1, 0.0, -1e4, -0.0, 1e3, -nan(f16), -tmin(f16), -1e-4, inf(f16), 1e-3, -1e-1,
            });
            try testArgs(@Vector(32, f128), @Vector(32, f16), .{
                -1e3, -tmin(f16), inf(f16),   -1e4,      -0.0, fmax(f16), 1e2,       1e4, -nan(f16), 0.0,        -1e-4, -1e1, 1e0,   1e-1, nan(f16), -1e0,
                1e3,  -1e-3,      -fmin(f16), -inf(f16), 1e-3, tmin(f16), fmin(f16), 1e1, 1e-4,      -fmax(f16), -1e2,  1e-2, -1e-2, 1e3,  inf(f16), -fmin(f16),
            });

            try testArgs(@Vector(1, f16), @Vector(1, f32), .{
                1e0,
            });
            try testArgs(@Vector(2, f16), @Vector(2, f32), .{
                -inf(f32), -1e-2,
            });
            try testArgs(@Vector(4, f16), @Vector(4, f32), .{
                -1e2, 1e-1, fmax(f32), 1e-2,
            });
            try testArgs(@Vector(8, f16), @Vector(8, f32), .{
                -1e-1, tmin(f32), -1e3, fmin(f32), nan(f32), -1e-3, 1e1, 1e4,
            });
            try testArgs(@Vector(16, f16), @Vector(16, f32), .{
                -fmax(f32), -1e0, 1e-4, 1e2, -fmin(f32), -1e1, 0.0, -1e4, -0.0, 1e3, -nan(f32), -tmin(f32), -1e-4, inf(f32), 1e-3, -1e-1,
            });
            try testArgs(@Vector(32, f16), @Vector(32, f32), .{
                -1e3, -tmin(f32), inf(f32),   -1e4,      -0.0, fmax(f32), 1e2,       1e4, -nan(f32), 0.0,        -1e-4, -1e1, 1e0,   1e-1, nan(f32), -1e0,
                1e3,  -1e-3,      -fmin(f32), -inf(f32), 1e-3, tmin(f32), fmin(f32), 1e1, 1e-4,      -fmax(f32), -1e2,  1e-2, -1e-2, 1e3,  inf(f32), -fmin(f32),
            });

            try testArgs(@Vector(1, f32), @Vector(1, f32), .{
                1e0,
            });
            try testArgs(@Vector(2, f32), @Vector(2, f32), .{
                -inf(f32), -1e-2,
            });
            try testArgs(@Vector(4, f32), @Vector(4, f32), .{
                -1e2, 1e-1, fmax(f32), 1e-2,
            });
            try testArgs(@Vector(8, f32), @Vector(8, f32), .{
                -1e-1, tmin(f32), -1e3, fmin(f32), nan(f32), -1e-3, 1e1, 1e4,
            });
            try testArgs(@Vector(16, f32), @Vector(16, f32), .{
                -fmax(f32), -1e0, 1e-4, 1e2, -fmin(f32), -1e1, 0.0, -1e4, -0.0, 1e3, -nan(f32), -tmin(f32), -1e-4, inf(f32), 1e-3, -1e-1,
            });
            try testArgs(@Vector(32, f32), @Vector(32, f32), .{
                -1e3, -tmin(f32), inf(f32),   -1e4,      -0.0, fmax(f32), 1e2,       1e4, -nan(f32), 0.0,        -1e-4, -1e1, 1e0,   1e-1, nan(f32), -1e0,
                1e3,  -1e-3,      -fmin(f32), -inf(f32), 1e-3, tmin(f32), fmin(f32), 1e1, 1e-4,      -fmax(f32), -1e2,  1e-2, -1e-2, 1e3,  inf(f32), -fmin(f32),
            });

            try testArgs(@Vector(1, f64), @Vector(1, f32), .{
                1e0,
            });
            try testArgs(@Vector(2, f64), @Vector(2, f32), .{
                -inf(f32), -1e-2,
            });
            try testArgs(@Vector(4, f64), @Vector(4, f32), .{
                -1e2, 1e-1, fmax(f32), 1e-2,
            });
            try testArgs(@Vector(8, f64), @Vector(8, f32), .{
                -1e-1, tmin(f32), -1e3, fmin(f32), nan(f32), -1e-3, 1e1, 1e4,
            });
            try testArgs(@Vector(16, f64), @Vector(16, f32), .{
                -fmax(f32), -1e0, 1e-4, 1e2, -fmin(f32), -1e1, 0.0, -1e4, -0.0, 1e3, -nan(f32), -tmin(f32), -1e-4, inf(f32), 1e-3, -1e-1,
            });
            try testArgs(@Vector(32, f64), @Vector(32, f32), .{
                -1e3, -tmin(f32), inf(f32),   -1e4,      -0.0, fmax(f32), 1e2,       1e4, -nan(f32), 0.0,        -1e-4, -1e1, 1e0,   1e-1, nan(f32), -1e0,
                1e3,  -1e-3,      -fmin(f32), -inf(f32), 1e-3, tmin(f32), fmin(f32), 1e1, 1e-4,      -fmax(f32), -1e2,  1e-2, -1e-2, 1e3,  inf(f32), -fmin(f32),
            });

            try testArgs(@Vector(1, f80), @Vector(1, f32), .{
                1e0,
            });
            try testArgs(@Vector(2, f80), @Vector(2, f32), .{
                -inf(f32), -1e-2,
            });
            try testArgs(@Vector(4, f80), @Vector(4, f32), .{
                -1e2, 1e-1, fmax(f32), 1e-2,
            });
            try testArgs(@Vector(8, f80), @Vector(8, f32), .{
                -1e-1, tmin(f32), -1e3, fmin(f32), nan(f32), -1e-3, 1e1, 1e4,
            });
            try testArgs(@Vector(16, f80), @Vector(16, f32), .{
                -fmax(f32), -1e0, 1e-4, 1e2, -fmin(f32), -1e1, 0.0, -1e4, -0.0, 1e3, -nan(f32), -tmin(f32), -1e-4, inf(f32), 1e-3, -1e-1,
            });
            try testArgs(@Vector(32, f80), @Vector(32, f32), .{
                -1e3, -tmin(f32), inf(f32),   -1e4,      -0.0, fmax(f32), 1e2,       1e4, -nan(f32), 0.0,        -1e-4, -1e1, 1e0,   1e-1, nan(f32), -1e0,
                1e3,  -1e-3,      -fmin(f32), -inf(f32), 1e-3, tmin(f32), fmin(f32), 1e1, 1e-4,      -fmax(f32), -1e2,  1e-2, -1e-2, 1e3,  inf(f32), -fmin(f32),
            });

            try testArgs(@Vector(1, f128), @Vector(1, f32), .{
                1e0,
            });
            try testArgs(@Vector(2, f128), @Vector(2, f32), .{
                -inf(f32), -1e-2,
            });
            try testArgs(@Vector(4, f128), @Vector(4, f32), .{
                -1e2, 1e-1, fmax(f32), 1e-2,
            });
            try testArgs(@Vector(8, f128), @Vector(8, f32), .{
                -1e-1, tmin(f32), -1e3, fmin(f32), nan(f32), -1e-3, 1e1, 1e4,
            });
            try testArgs(@Vector(16, f128), @Vector(16, f32), .{
                -fmax(f32), -1e0, 1e-4, 1e2, -fmin(f32), -1e1, 0.0, -1e4, -0.0, 1e3, -nan(f32), -tmin(f32), -1e-4, inf(f32), 1e-3, -1e-1,
            });
            try testArgs(@Vector(32, f128), @Vector(32, f32), .{
                -1e3, -tmin(f32), inf(f32),   -1e4,      -0.0, fmax(f32), 1e2,       1e4, -nan(f32), 0.0,        -1e-4, -1e1, 1e0,   1e-1, nan(f32), -1e0,
                1e3,  -1e-3,      -fmin(f32), -inf(f32), 1e-3, tmin(f32), fmin(f32), 1e1, 1e-4,      -fmax(f32), -1e2,  1e-2, -1e-2, 1e3,  inf(f32), -fmin(f32),
            });

            try testArgs(@Vector(1, f16), @Vector(1, f64), .{
                1e0,
            });
            try testArgs(@Vector(2, f16), @Vector(2, f64), .{
                -inf(f64), -1e-2,
            });
            try testArgs(@Vector(4, f16), @Vector(4, f64), .{
                -1e2, 1e-1, fmax(f64), 1e-2,
            });
            try testArgs(@Vector(8, f16), @Vector(8, f64), .{
                -1e-1, tmin(f64), -1e3, fmin(f64), nan(f64), -1e-3, 1e1, 1e4,
            });
            try testArgs(@Vector(16, f16), @Vector(16, f64), .{
                -fmax(f64), -1e0, 1e-4, 1e2, -fmin(f64), -1e1, 0.0, -1e4, -0.0, 1e3, -nan(f64), -tmin(f64), -1e-4, inf(f64), 1e-3, -1e-1,
            });
            try testArgs(@Vector(32, f16), @Vector(32, f64), .{
                -1e3, -tmin(f64), inf(f64),   -1e4,      -0.0, fmax(f64), 1e2,       1e4, -nan(f64), 0.0,        -1e-4, -1e1, 1e0,   1e-1, nan(f64), -1e0,
                1e3,  -1e-3,      -fmin(f64), -inf(f64), 1e-3, tmin(f64), fmin(f64), 1e1, 1e-4,      -fmax(f64), -1e2,  1e-2, -1e-2, 1e3,  inf(f64), -fmin(f64),
            });

            try testArgs(@Vector(1, f32), @Vector(1, f64), .{
                1e0,
            });
            try testArgs(@Vector(2, f32), @Vector(2, f64), .{
                -inf(f64), -1e-2,
            });
            try testArgs(@Vector(4, f32), @Vector(4, f64), .{
                -1e2, 1e-1, fmax(f64), 1e-2,
            });
            try testArgs(@Vector(8, f32), @Vector(8, f64), .{
                -1e-1, tmin(f64), -1e3, fmin(f64), nan(f64), -1e-3, 1e1, 1e4,
            });
            try testArgs(@Vector(16, f32), @Vector(16, f64), .{
                -fmax(f64), -1e0, 1e-4, 1e2, -fmin(f64), -1e1, 0.0, -1e4, -0.0, 1e3, -nan(f64), -tmin(f64), -1e-4, inf(f64), 1e-3, -1e-1,
            });
            try testArgs(@Vector(32, f32), @Vector(32, f64), .{
                -1e3, -tmin(f64), inf(f64),   -1e4,      -0.0, fmax(f64), 1e2,       1e4, -nan(f64), 0.0,        -1e-4, -1e1, 1e0,   1e-1, nan(f64), -1e0,
                1e3,  -1e-3,      -fmin(f64), -inf(f64), 1e-3, tmin(f64), fmin(f64), 1e1, 1e-4,      -fmax(f64), -1e2,  1e-2, -1e-2, 1e3,  inf(f64), -fmin(f64),
            });

            try testArgs(@Vector(1, f64), @Vector(1, f64), .{
                1e0,
            });
            try testArgs(@Vector(2, f64), @Vector(2, f64), .{
                -inf(f64), -1e-2,
            });
            try testArgs(@Vector(4, f64), @Vector(4, f64), .{
                -1e2, 1e-1, fmax(f64), 1e-2,
            });
            try testArgs(@Vector(8, f64), @Vector(8, f64), .{
                -1e-1, tmin(f64), -1e3, fmin(f64), nan(f64), -1e-3, 1e1, 1e4,
            });
            try testArgs(@Vector(16, f64), @Vector(16, f64), .{
                -fmax(f64), -1e0, 1e-4, 1e2, -fmin(f64), -1e1, 0.0, -1e4, -0.0, 1e3, -nan(f64), -tmin(f64), -1e-4, inf(f64), 1e-3, -1e-1,
            });
            try testArgs(@Vector(32, f64), @Vector(32, f64), .{
                -1e3, -tmin(f64), inf(f64),   -1e4,      -0.0, fmax(f64), 1e2,       1e4, -nan(f64), 0.0,        -1e-4, -1e1, 1e0,   1e-1, nan(f64), -1e0,
                1e3,  -1e-3,      -fmin(f64), -inf(f64), 1e-3, tmin(f64), fmin(f64), 1e1, 1e-4,      -fmax(f64), -1e2,  1e-2, -1e-2, 1e3,  inf(f64), -fmin(f64),
            });

            try testArgs(@Vector(1, f80), @Vector(1, f64), .{
                1e0,
            });
            try testArgs(@Vector(2, f80), @Vector(2, f64), .{
                -inf(f64), -1e-2,
            });
            try testArgs(@Vector(4, f80), @Vector(4, f64), .{
                -1e2, 1e-1, fmax(f64), 1e-2,
            });
            try testArgs(@Vector(8, f80), @Vector(8, f64), .{
                -1e-1, tmin(f64), -1e3, fmin(f64), nan(f64), -1e-3, 1e1, 1e4,
            });
            try testArgs(@Vector(16, f80), @Vector(16, f64), .{
                -fmax(f64), -1e0, 1e-4, 1e2, -fmin(f64), -1e1, 0.0, -1e4, -0.0, 1e3, -nan(f64), -tmin(f64), -1e-4, inf(f64), 1e-3, -1e-1,
            });
            try testArgs(@Vector(32, f80), @Vector(32, f64), .{
                -1e3, -tmin(f64), inf(f64),   -1e4,      -0.0, fmax(f64), 1e2,       1e4, -nan(f64), 0.0,        -1e-4, -1e1, 1e0,   1e-1, nan(f64), -1e0,
                1e3,  -1e-3,      -fmin(f64), -inf(f64), 1e-3, tmin(f64), fmin(f64), 1e1, 1e-4,      -fmax(f64), -1e2,  1e-2, -1e-2, 1e3,  inf(f64), -fmin(f64),
            });

            try testArgs(@Vector(1, f128), @Vector(1, f64), .{
                1e0,
            });
            try testArgs(@Vector(2, f128), @Vector(2, f64), .{
                -inf(f64), -1e-2,
            });
            try testArgs(@Vector(4, f128), @Vector(4, f64), .{
                -1e2, 1e-1, fmax(f64), 1e-2,
            });
            try testArgs(@Vector(8, f128), @Vector(8, f64), .{
                -1e-1, tmin(f64), -1e3, fmin(f64), nan(f64), -1e-3, 1e1, 1e4,
            });
            try testArgs(@Vector(16, f128), @Vector(16, f64), .{
                -fmax(f64), -1e0, 1e-4, 1e2, -fmin(f64), -1e1, 0.0, -1e4, -0.0, 1e3, -nan(f64), -tmin(f64), -1e-4, inf(f64), 1e-3, -1e-1,
            });
            try testArgs(@Vector(32, f128), @Vector(32, f64), .{
                -1e3, -tmin(f64), inf(f64),   -1e4,      -0.0, fmax(f64), 1e2,       1e4, -nan(f64), 0.0,        -1e-4, -1e1, 1e0,   1e-1, nan(f64), -1e0,
                1e3,  -1e-3,      -fmin(f64), -inf(f64), 1e-3, tmin(f64), fmin(f64), 1e1, 1e-4,      -fmax(f64), -1e2,  1e-2, -1e-2, 1e3,  inf(f64), -fmin(f64),
            });

            try testArgs(@Vector(1, f16), @Vector(1, f80), .{
                1e0,
            });
            try testArgs(@Vector(2, f16), @Vector(2, f80), .{
                -inf(f80), -1e-2,
            });
            try testArgs(@Vector(4, f16), @Vector(4, f80), .{
                -1e2, 1e-1, fmax(f80), 1e-2,
            });
            try testArgs(@Vector(8, f16), @Vector(8, f80), .{
                -1e-1, tmin(f80), -1e3, fmin(f80), nan(f80), -1e-3, 1e1, 1e4,
            });
            try testArgs(@Vector(16, f16), @Vector(16, f80), .{
                -fmax(f80), -1e0, 1e-4, 1e2, -fmin(f80), -1e1, 0.0, -1e4, -0.0, 1e3, -nan(f80), -tmin(f80), -1e-4, inf(f80), 1e-3, -1e-1,
            });
            try testArgs(@Vector(32, f16), @Vector(32, f80), .{
                -1e3, -tmin(f80), inf(f80),   -1e4,      -0.0, fmax(f80), 1e2,       1e4, -nan(f80), 0.0,        -1e-4, -1e1, 1e0,   1e-1, nan(f80), -1e0,
                1e3,  -1e-3,      -fmin(f80), -inf(f80), 1e-3, tmin(f80), fmin(f80), 1e1, 1e-4,      -fmax(f80), -1e2,  1e-2, -1e-2, 1e3,  inf(f80), -fmin(f80),
            });

            try testArgs(@Vector(1, f32), @Vector(1, f80), .{
                1e0,
            });
            try testArgs(@Vector(2, f32), @Vector(2, f80), .{
                -inf(f80), -1e-2,
            });
            try testArgs(@Vector(4, f32), @Vector(4, f80), .{
                -1e2, 1e-1, fmax(f80), 1e-2,
            });
            try testArgs(@Vector(8, f32), @Vector(8, f80), .{
                -1e-1, tmin(f80), -1e3, fmin(f80), nan(f80), -1e-3, 1e1, 1e4,
            });
            try testArgs(@Vector(16, f32), @Vector(16, f80), .{
                -fmax(f80), -1e0, 1e-4, 1e2, -fmin(f80), -1e1, 0.0, -1e4, -0.0, 1e3, -nan(f80), -tmin(f80), -1e-4, inf(f80), 1e-3, -1e-1,
            });
            try testArgs(@Vector(32, f32), @Vector(32, f80), .{
                -1e3, -tmin(f80), inf(f80),   -1e4,      -0.0, fmax(f80), 1e2,       1e4, -nan(f80), 0.0,        -1e-4, -1e1, 1e0,   1e-1, nan(f80), -1e0,
                1e3,  -1e-3,      -fmin(f80), -inf(f80), 1e-3, tmin(f80), fmin(f80), 1e1, 1e-4,      -fmax(f80), -1e2,  1e-2, -1e-2, 1e3,  inf(f80), -fmin(f80),
            });

            try testArgs(@Vector(1, f64), @Vector(1, f80), .{
                1e0,
            });
            try testArgs(@Vector(2, f64), @Vector(2, f80), .{
                -inf(f80), -1e-2,
            });
            try testArgs(@Vector(4, f64), @Vector(4, f80), .{
                -1e2, 1e-1, fmax(f80), 1e-2,
            });
            try testArgs(@Vector(8, f64), @Vector(8, f80), .{
                -1e-1, tmin(f80), -1e3, fmin(f80), nan(f80), -1e-3, 1e1, 1e4,
            });
            try testArgs(@Vector(16, f64), @Vector(16, f80), .{
                -fmax(f80), -1e0, 1e-4, 1e2, -fmin(f80), -1e1, 0.0, -1e4, -0.0, 1e3, -nan(f80), -tmin(f80), -1e-4, inf(f80), 1e-3, -1e-1,
            });
            try testArgs(@Vector(32, f64), @Vector(32, f80), .{
                -1e3, -tmin(f80), inf(f80),   -1e4,      -0.0, fmax(f80), 1e2,       1e4, -nan(f80), 0.0,        -1e-4, -1e1, 1e0,   1e-1, nan(f80), -1e0,
                1e3,  -1e-3,      -fmin(f80), -inf(f80), 1e-3, tmin(f80), fmin(f80), 1e1, 1e-4,      -fmax(f80), -1e2,  1e-2, -1e-2, 1e3,  inf(f80), -fmin(f80),
            });

            try testArgs(@Vector(1, f80), @Vector(1, f80), .{
                1e0,
            });
            try testArgs(@Vector(2, f80), @Vector(2, f80), .{
                -inf(f80), -1e-2,
            });
            try testArgs(@Vector(4, f80), @Vector(4, f80), .{
                -1e2, 1e-1, fmax(f80), 1e-2,
            });
            try testArgs(@Vector(8, f80), @Vector(8, f80), .{
                -1e-1, tmin(f80), -1e3, fmin(f80), nan(f80), -1e-3, 1e1, 1e4,
            });
            try testArgs(@Vector(16, f80), @Vector(16, f80), .{
                -fmax(f80), -1e0, 1e-4, 1e2, -fmin(f80), -1e1, 0.0, -1e4, -0.0, 1e3, -nan(f80), -tmin(f80), -1e-4, inf(f80), 1e-3, -1e-1,
            });
            try testArgs(@Vector(32, f80), @Vector(32, f80), .{
                -1e3, -tmin(f80), inf(f80),   -1e4,      -0.0, fmax(f80), 1e2,       1e4, -nan(f80), 0.0,        -1e-4, -1e1, 1e0,   1e-1, nan(f80), -1e0,
                1e3,  -1e-3,      -fmin(f80), -inf(f80), 1e-3, tmin(f80), fmin(f80), 1e1, 1e-4,      -fmax(f80), -1e2,  1e-2, -1e-2, 1e3,  inf(f80), -fmin(f80),
            });

            try testArgs(@Vector(1, f128), @Vector(1, f80), .{
                1e0,
            });
            try testArgs(@Vector(2, f128), @Vector(2, f80), .{
                -inf(f80), -1e-2,
            });
            try testArgs(@Vector(4, f128), @Vector(4, f80), .{
                -1e2, 1e-1, fmax(f80), 1e-2,
            });
            try testArgs(@Vector(8, f128), @Vector(8, f80), .{
                -1e-1, tmin(f80), -1e3, fmin(f80), nan(f80), -1e-3, 1e1, 1e4,
            });
            try testArgs(@Vector(16, f128), @Vector(16, f80), .{
                -fmax(f80), -1e0, 1e-4, 1e2, -fmin(f80), -1e1, 0.0, -1e4, -0.0, 1e3, -nan(f80), -tmin(f80), -1e-4, inf(f80), 1e-3, -1e-1,
            });
            try testArgs(@Vector(32, f128), @Vector(32, f80), .{
                -1e3, -tmin(f80), inf(f80),   -1e4,      -0.0, fmax(f80), 1e2,       1e4, -nan(f80), 0.0,        -1e-4, -1e1, 1e0,   1e-1, nan(f80), -1e0,
                1e3,  -1e-3,      -fmin(f80), -inf(f80), 1e-3, tmin(f80), fmin(f80), 1e1, 1e-4,      -fmax(f80), -1e2,  1e-2, -1e-2, 1e3,  inf(f80), -fmin(f80),
            });

            try testArgs(@Vector(1, f16), @Vector(1, f128), .{
                1e0,
            });
            try testArgs(@Vector(2, f16), @Vector(2, f128), .{
                -inf(f128), -1e-2,
            });
            try testArgs(@Vector(4, f16), @Vector(4, f128), .{
                -1e2, 1e-1, fmax(f128), 1e-2,
            });
            try testArgs(@Vector(8, f16), @Vector(8, f128), .{
                -1e-1, tmin(f128), -1e3, fmin(f128), nan(f128), -1e-3, 1e1, 1e4,
            });
            try testArgs(@Vector(16, f16), @Vector(16, f128), .{
                -fmax(f128), -1e0, 1e-4, 1e2, -fmin(f128), -1e1, 0.0, -1e4, -0.0, 1e3, -nan(f128), -tmin(f128), -1e-4, inf(f128), 1e-3, -1e-1,
            });
            try testArgs(@Vector(32, f16), @Vector(32, f128), .{
                -1e3, -tmin(f128), inf(f128),   -1e4,       -0.0, fmax(f128), 1e2,        1e4, -nan(f128), 0.0,         -1e-4, -1e1, 1e0,   1e-1, nan(f128), -1e0,
                1e3,  -1e-3,       -fmin(f128), -inf(f128), 1e-3, tmin(f128), fmin(f128), 1e1, 1e-4,       -fmax(f128), -1e2,  1e-2, -1e-2, 1e3,  inf(f128), -fmin(f128),
            });

            try testArgs(@Vector(1, f32), @Vector(1, f128), .{
                1e0,
            });
            try testArgs(@Vector(2, f32), @Vector(2, f128), .{
                -inf(f128), -1e-2,
            });
            try testArgs(@Vector(4, f32), @Vector(4, f128), .{
                -1e2, 1e-1, fmax(f128), 1e-2,
            });
            try testArgs(@Vector(8, f32), @Vector(8, f128), .{
                -1e-1, tmin(f128), -1e3, fmin(f128), nan(f128), -1e-3, 1e1, 1e4,
            });
            try testArgs(@Vector(16, f32), @Vector(16, f128), .{
                -fmax(f128), -1e0, 1e-4, 1e2, -fmin(f128), -1e1, 0.0, -1e4, -0.0, 1e3, -nan(f128), -tmin(f128), -1e-4, inf(f128), 1e-3, -1e-1,
            });
            try testArgs(@Vector(32, f32), @Vector(32, f128), .{
                -1e3, -tmin(f128), inf(f128),   -1e4,       -0.0, fmax(f128), 1e2,        1e4, -nan(f128), 0.0,         -1e-4, -1e1, 1e0,   1e-1, nan(f128), -1e0,
                1e3,  -1e-3,       -fmin(f128), -inf(f128), 1e-3, tmin(f128), fmin(f128), 1e1, 1e-4,       -fmax(f128), -1e2,  1e-2, -1e-2, 1e3,  inf(f128), -fmin(f128),
            });

            try testArgs(@Vector(1, f64), @Vector(1, f128), .{
                1e0,
            });
            try testArgs(@Vector(2, f64), @Vector(2, f128), .{
                -inf(f128), -1e-2,
            });
            try testArgs(@Vector(4, f64), @Vector(4, f128), .{
                -1e2, 1e-1, fmax(f128), 1e-2,
            });
            try testArgs(@Vector(8, f64), @Vector(8, f128), .{
                -1e-1, tmin(f128), -1e3, fmin(f128), nan(f128), -1e-3, 1e1, 1e4,
            });
            try testArgs(@Vector(16, f64), @Vector(16, f128), .{
                -fmax(f128), -1e0, 1e-4, 1e2, -fmin(f128), -1e1, 0.0, -1e4, -0.0, 1e3, -nan(f128), -tmin(f128), -1e-4, inf(f128), 1e-3, -1e-1,
            });
            try testArgs(@Vector(32, f64), @Vector(32, f128), .{
                -1e3, -tmin(f128), inf(f128),   -1e4,       -0.0, fmax(f128), 1e2,        1e4, -nan(f128), 0.0,         -1e-4, -1e1, 1e0,   1e-1, nan(f128), -1e0,
                1e3,  -1e-3,       -fmin(f128), -inf(f128), 1e-3, tmin(f128), fmin(f128), 1e1, 1e-4,       -fmax(f128), -1e2,  1e-2, -1e-2, 1e3,  inf(f128), -fmin(f128),
            });

            try testArgs(@Vector(1, f80), @Vector(1, f128), .{
                1e0,
            });
            try testArgs(@Vector(2, f80), @Vector(2, f128), .{
                -inf(f128), -1e-2,
            });
            try testArgs(@Vector(4, f80), @Vector(4, f128), .{
                -1e2, 1e-1, fmax(f128), 1e-2,
            });
            try testArgs(@Vector(8, f80), @Vector(8, f128), .{
                -1e-1, tmin(f128), -1e3, fmin(f128), nan(f128), -1e-3, 1e1, 1e4,
            });
            try testArgs(@Vector(16, f80), @Vector(16, f128), .{
                -fmax(f128), -1e0, 1e-4, 1e2, -fmin(f128), -1e1, 0.0, -1e4, -0.0, 1e3, -nan(f128), -tmin(f128), -1e-4, inf(f128), 1e-3, -1e-1,
            });
            try testArgs(@Vector(32, f80), @Vector(32, f128), .{
                -1e3, -tmin(f128), inf(f128),   -1e4,       -0.0, fmax(f128), 1e2,        1e4, -nan(f128), 0.0,         -1e-4, -1e1, 1e0,   1e-1, nan(f128), -1e0,
                1e3,  -1e-3,       -fmin(f128), -inf(f128), 1e-3, tmin(f128), fmin(f128), 1e1, 1e-4,       -fmax(f128), -1e2,  1e-2, -1e-2, 1e3,  inf(f128), -fmin(f128),
            });

            try testArgs(@Vector(1, f128), @Vector(1, f128), .{
                1e0,
            });
            try testArgs(@Vector(2, f128), @Vector(2, f128), .{
                -inf(f128), -1e-2,
            });
            try testArgs(@Vector(4, f128), @Vector(4, f128), .{
                -1e2, 1e-1, fmax(f128), 1e-2,
            });
            try testArgs(@Vector(8, f128), @Vector(8, f128), .{
                -1e-1, tmin(f128), -1e3, fmin(f128), nan(f128), -1e-3, 1e1, 1e4,
            });
            try testArgs(@Vector(16, f128), @Vector(16, f128), .{
                -fmax(f128), -1e0, 1e-4, 1e2, -fmin(f128), -1e1, 0.0, -1e4, -0.0, 1e3, -nan(f128), -tmin(f128), -1e-4, inf(f128), 1e-3, -1e-1,
            });
            try testArgs(@Vector(32, f128), @Vector(32, f128), .{
                -1e3, -tmin(f128), inf(f128),   -1e4,       -0.0, fmax(f128), 1e2,        1e4, -nan(f128), 0.0,         -1e-4, -1e1, 1e0,   1e-1, nan(f128), -1e0,
                1e3,  -1e-3,       -fmin(f128), -inf(f128), 1e-3, tmin(f128), fmin(f128), 1e1, 1e-4,       -fmax(f128), -1e2,  1e-2, -1e-2, 1e3,  inf(f128), -fmin(f128),
            });
        }
        fn testIntsFromFloats() !void {
            @setEvalBranchQuota(2_600);

            try testArgs(i8, f16, -0x0.8p8);
            try testArgs(i8, f16, next(f16, -0x0.8p8, -0.0));
            try testArgs(i8, f16, next(f16, next(f16, -0x0.8p8, -0.0), -0.0));
            try testArgs(i8, f16, -1e2);
            try testArgs(i8, f16, -1e1);
            try testArgs(i8, f16, -1e0);
            try testArgs(i8, f16, -1e-1);
            try testArgs(i8, f16, -0.0);
            try testArgs(i8, f16, 0.0);
            try testArgs(i8, f16, 1e-1);
            try testArgs(i8, f16, 1e0);
            try testArgs(i8, f16, 1e1);
            try testArgs(i8, f16, 1e2);
            try testArgs(i8, f16, next(f16, next(f16, 0x0.8p8, 0.0), 0.0));
            try testArgs(i8, f16, next(f16, 0x0.8p8, 0.0));

            try testArgs(u8, f16, -0.0);
            try testArgs(u8, f16, 0.0);
            try testArgs(u8, f16, 1e-1);
            try testArgs(u8, f16, 1e0);
            try testArgs(u8, f16, 1e1);
            try testArgs(u8, f16, 1e2);
            try testArgs(u8, f16, next(f16, next(f16, 0x1p8, 0.0), 0.0));
            try testArgs(u8, f16, next(f16, 0x1p8, 0.0));

            try testArgs(i16, f16, -1e4);
            try testArgs(i16, f16, -1e3);
            try testArgs(i16, f16, -1e2);
            try testArgs(i16, f16, -1e1);
            try testArgs(i16, f16, -1e0);
            try testArgs(i16, f16, -1e-1);
            try testArgs(i16, f16, -0.0);
            try testArgs(i16, f16, 0.0);
            try testArgs(i16, f16, 1e-1);
            try testArgs(i16, f16, 1e0);
            try testArgs(i16, f16, 1e1);
            try testArgs(i16, f16, 1e2);
            try testArgs(i16, f16, 1e3);
            try testArgs(i16, f16, 1e4);
            try testArgs(i16, f16, next(f16, next(f16, 0x0.8p16, 0.0), 0.0));
            try testArgs(i16, f16, next(f16, 0x0.8p16, 0.0));

            try testArgs(u16, f16, -0.0);
            try testArgs(u16, f16, 0.0);
            try testArgs(u16, f16, 1e-1);
            try testArgs(u16, f16, 1e0);
            try testArgs(u16, f16, 1e1);
            try testArgs(u16, f16, 1e2);
            try testArgs(u16, f16, 1e3);
            try testArgs(u16, f16, 1e4);
            try testArgs(u16, f16, next(f16, next(f16, fmax(f16), 0.0), 0.0));
            try testArgs(u16, f16, next(f16, fmax(f16), 0.0));
            try testArgs(u16, f16, fmax(f16));

            try testArgs(i32, f16, -fmax(f16));
            try testArgs(i32, f16, next(f16, -fmax(f16), -0.0));
            try testArgs(i32, f16, next(f16, next(f16, -fmax(f16), -0.0), -0.0));
            try testArgs(i32, f16, -1e4);
            try testArgs(i32, f16, -1e3);
            try testArgs(i32, f16, -1e2);
            try testArgs(i32, f16, -1e1);
            try testArgs(i32, f16, -1e0);
            try testArgs(i32, f16, -1e-1);
            try testArgs(i32, f16, -0.0);
            try testArgs(i32, f16, 0.0);
            try testArgs(i32, f16, 1e-1);
            try testArgs(i32, f16, 1e0);
            try testArgs(i32, f16, 1e1);
            try testArgs(i32, f16, 1e2);
            try testArgs(i32, f16, 1e3);
            try testArgs(i32, f16, 1e4);
            try testArgs(i32, f16, next(f16, next(f16, fmax(f16), 0.0), 0.0));
            try testArgs(i32, f16, next(f16, fmax(f16), 0.0));
            try testArgs(i32, f16, fmax(f16));

            try testArgs(u32, f16, -0.0);
            try testArgs(u32, f16, 0.0);
            try testArgs(u32, f16, 1e-1);
            try testArgs(u32, f16, 1e0);
            try testArgs(u32, f16, 1e1);
            try testArgs(u32, f16, 1e2);
            try testArgs(u32, f16, 1e3);
            try testArgs(u32, f16, 1e4);
            try testArgs(u32, f16, next(f16, next(f16, fmax(f16), 0.0), 0.0));
            try testArgs(u32, f16, next(f16, fmax(f16), 0.0));
            try testArgs(u32, f16, fmax(f16));

            try testArgs(i64, f16, -fmax(f16));
            try testArgs(i64, f16, next(f16, -fmax(f16), -0.0));
            try testArgs(i64, f16, next(f16, next(f16, -fmax(f16), -0.0), -0.0));
            try testArgs(i64, f16, -1e4);
            try testArgs(i64, f16, -1e3);
            try testArgs(i64, f16, -1e2);
            try testArgs(i64, f16, -1e1);
            try testArgs(i64, f16, -1e0);
            try testArgs(i64, f16, -1e-1);
            try testArgs(i64, f16, -0.0);
            try testArgs(i64, f16, 0.0);
            try testArgs(i64, f16, 1e-1);
            try testArgs(i64, f16, 1e0);
            try testArgs(i64, f16, 1e1);
            try testArgs(i64, f16, 1e2);
            try testArgs(i64, f16, 1e3);
            try testArgs(i64, f16, 1e4);
            try testArgs(i64, f16, next(f16, next(f16, fmax(f16), 0.0), 0.0));
            try testArgs(i64, f16, next(f16, fmax(f16), 0.0));
            try testArgs(i64, f16, fmax(f16));

            try testArgs(u64, f16, -0.0);
            try testArgs(u64, f16, 0.0);
            try testArgs(u64, f16, 1e-1);
            try testArgs(u64, f16, 1e0);
            try testArgs(u64, f16, 1e1);
            try testArgs(u64, f16, 1e2);
            try testArgs(u64, f16, 1e3);
            try testArgs(u64, f16, 1e4);
            try testArgs(u64, f16, next(f16, next(f16, fmax(f16), 0.0), 0.0));
            try testArgs(u64, f16, next(f16, fmax(f16), 0.0));
            try testArgs(u64, f16, fmax(f16));

            try testArgs(i128, f16, -fmax(f16));
            try testArgs(i128, f16, next(f16, -fmax(f16), -0.0));
            try testArgs(i128, f16, next(f16, next(f16, -fmax(f16), -0.0), -0.0));
            try testArgs(i128, f16, -1e4);
            try testArgs(i128, f16, -1e3);
            try testArgs(i128, f16, -1e2);
            try testArgs(i128, f16, -1e1);
            try testArgs(i128, f16, -1e0);
            try testArgs(i128, f16, -1e-1);
            try testArgs(i128, f16, -0.0);
            try testArgs(i128, f16, 0.0);
            try testArgs(i128, f16, 1e-1);
            try testArgs(i128, f16, 1e0);
            try testArgs(i128, f16, 1e1);
            try testArgs(i128, f16, 1e2);
            try testArgs(i128, f16, 1e3);
            try testArgs(i128, f16, 1e4);
            try testArgs(i128, f16, next(f16, next(f16, fmax(f16), 0.0), 0.0));
            try testArgs(i128, f16, next(f16, fmax(f16), 0.0));
            try testArgs(i128, f16, fmax(f16));

            try testArgs(u128, f16, -0.0);
            try testArgs(u128, f16, 0.0);
            try testArgs(u128, f16, 1e-1);
            try testArgs(u128, f16, 1e0);
            try testArgs(u128, f16, 1e1);
            try testArgs(u128, f16, 1e2);
            try testArgs(u128, f16, 1e3);
            try testArgs(u128, f16, 1e4);
            try testArgs(u128, f16, next(f16, next(f16, fmax(f16), 0.0), 0.0));
            try testArgs(u128, f16, next(f16, fmax(f16), 0.0));
            try testArgs(u128, f16, fmax(f16));

            try testArgs(i256, f16, -fmax(f16));
            try testArgs(i256, f16, next(f16, -fmax(f16), -0.0));
            try testArgs(i256, f16, next(f16, next(f16, -fmax(f16), -0.0), -0.0));
            try testArgs(i256, f16, -1e4);
            try testArgs(i256, f16, -1e3);
            try testArgs(i256, f16, -1e2);
            try testArgs(i256, f16, -1e1);
            try testArgs(i256, f16, -1e0);
            try testArgs(i256, f16, -1e-1);
            try testArgs(i256, f16, -0.0);
            try testArgs(i256, f16, 0.0);
            try testArgs(i256, f16, 1e-1);
            try testArgs(i256, f16, 1e0);
            try testArgs(i256, f16, 1e1);
            try testArgs(i256, f16, 1e2);
            try testArgs(i256, f16, 1e3);
            try testArgs(i256, f16, 1e4);
            try testArgs(i256, f16, next(f16, next(f16, fmax(f16), 0.0), 0.0));
            try testArgs(i256, f16, next(f16, fmax(f16), 0.0));
            try testArgs(i256, f16, fmax(f16));

            try testArgs(u256, f16, -0.0);
            try testArgs(u256, f16, 0.0);
            try testArgs(u256, f16, 1e-1);
            try testArgs(u256, f16, 1e0);
            try testArgs(u256, f16, 1e1);
            try testArgs(u256, f16, 1e2);
            try testArgs(u256, f16, 1e3);
            try testArgs(u256, f16, 1e4);
            try testArgs(u256, f16, next(f16, next(f16, fmax(f16), 0.0), 0.0));
            try testArgs(u256, f16, next(f16, fmax(f16), 0.0));
            try testArgs(u256, f16, fmax(f16));

            try testArgs(i8, f32, -0x0.8p8);
            try testArgs(i8, f32, next(f32, -0x0.8p8, -0.0));
            try testArgs(i8, f32, next(f32, next(f32, -0x0.8p8, -0.0), -0.0));
            try testArgs(i8, f32, -1e2);
            try testArgs(i8, f32, -1e1);
            try testArgs(i8, f32, -1e0);
            try testArgs(i8, f32, -1e-1);
            try testArgs(i8, f32, -0.0);
            try testArgs(i8, f32, 0.0);
            try testArgs(i8, f32, 1e-1);
            try testArgs(i8, f32, 1e0);
            try testArgs(i8, f32, 1e1);
            try testArgs(i8, f32, 1e2);
            try testArgs(i8, f32, next(f32, next(f32, 0x0.8p8, 0.0), 0.0));
            try testArgs(i8, f32, next(f32, 0x0.8p8, 0.0));

            try testArgs(u8, f32, -0.0);
            try testArgs(u8, f32, 0.0);
            try testArgs(u8, f32, 1e-1);
            try testArgs(u8, f32, 1e0);
            try testArgs(u8, f32, 1e1);
            try testArgs(u8, f32, 1e2);
            try testArgs(u8, f32, next(f32, next(f32, 0x1p8, 0.0), 0.0));
            try testArgs(u8, f32, next(f32, 0x1p8, 0.0));

            try testArgs(i16, f32, -0x0.8p16);
            try testArgs(i16, f32, next(f32, -0x0.8p16, -0.0));
            try testArgs(i16, f32, next(f32, next(f32, -0x0.8p16, -0.0), -0.0));
            try testArgs(i16, f32, -1e4);
            try testArgs(i16, f32, -1e3);
            try testArgs(i16, f32, -1e2);
            try testArgs(i16, f32, -1e1);
            try testArgs(i16, f32, -1e0);
            try testArgs(i16, f32, -1e-1);
            try testArgs(i16, f32, -0.0);
            try testArgs(i16, f32, 0.0);
            try testArgs(i16, f32, 1e-1);
            try testArgs(i16, f32, 1e0);
            try testArgs(i16, f32, 1e1);
            try testArgs(i16, f32, 1e2);
            try testArgs(i16, f32, 1e3);
            try testArgs(i16, f32, 1e4);
            try testArgs(i16, f32, next(f32, next(f32, 0x0.8p16, 0.0), 0.0));
            try testArgs(i16, f32, next(f32, 0x0.8p16, 0.0));

            try testArgs(u16, f32, -0.0);
            try testArgs(u16, f32, 0.0);
            try testArgs(u16, f32, 1e-1);
            try testArgs(u16, f32, 1e0);
            try testArgs(u16, f32, 1e1);
            try testArgs(u16, f32, 1e2);
            try testArgs(u16, f32, 1e3);
            try testArgs(u16, f32, 1e4);
            try testArgs(u16, f32, next(f32, next(f32, 0x1p16, 0.0), 0.0));
            try testArgs(u16, f32, next(f32, 0x1p16, 0.0));

            try testArgs(i32, f32, -0x0.8p32);
            try testArgs(i32, f32, next(f32, -0x0.8p32, -0.0));
            try testArgs(i32, f32, next(f32, next(f32, -0x0.8p32, -0.0), -0.0));
            try testArgs(i32, f32, -1e9);
            try testArgs(i32, f32, -1e8);
            try testArgs(i32, f32, -1e7);
            try testArgs(i32, f32, -1e6);
            try testArgs(i32, f32, -1e5);
            try testArgs(i32, f32, -1e4);
            try testArgs(i32, f32, -1e3);
            try testArgs(i32, f32, -1e2);
            try testArgs(i32, f32, -1e1);
            try testArgs(i32, f32, -1e0);
            try testArgs(i32, f32, -1e-1);
            try testArgs(i32, f32, -0.0);
            try testArgs(i32, f32, 0.0);
            try testArgs(i32, f32, 1e-1);
            try testArgs(i32, f32, 1e0);
            try testArgs(i32, f32, 1e1);
            try testArgs(i32, f32, 1e2);
            try testArgs(i32, f32, 1e3);
            try testArgs(i32, f32, 1e4);
            try testArgs(i32, f32, 1e5);
            try testArgs(i32, f32, 1e6);
            try testArgs(i32, f32, 1e7);
            try testArgs(i32, f32, 1e8);
            try testArgs(i32, f32, 1e9);
            try testArgs(i32, f32, next(f32, next(f32, 0x0.8p32, 0.0), 0.0));
            try testArgs(i32, f32, next(f32, 0x0.8p32, 0.0));

            try testArgs(u32, f32, -0.0);
            try testArgs(u32, f32, 0.0);
            try testArgs(u32, f32, 1e-1);
            try testArgs(u32, f32, 1e0);
            try testArgs(u32, f32, 1e1);
            try testArgs(u32, f32, 1e2);
            try testArgs(u32, f32, 1e3);
            try testArgs(u32, f32, 1e4);
            try testArgs(u32, f32, 1e5);
            try testArgs(u32, f32, 1e6);
            try testArgs(u32, f32, 1e7);
            try testArgs(u32, f32, 1e8);
            try testArgs(u32, f32, 1e9);
            try testArgs(u32, f32, next(f32, next(f32, 0x1p32, 0.0), 0.0));
            try testArgs(u32, f32, next(f32, 0x1p32, 0.0));

            try testArgs(i64, f32, -0x0.8p64);
            try testArgs(i64, f32, next(f32, -0x0.8p64, -0.0));
            try testArgs(i64, f32, next(f32, next(f32, -0x0.8p64, -0.0), -0.0));
            try testArgs(i64, f32, -1e18);
            try testArgs(i64, f32, -1e16);
            try testArgs(i64, f32, -1e14);
            try testArgs(i64, f32, -1e12);
            try testArgs(i64, f32, -1e10);
            try testArgs(i64, f32, -1e8);
            try testArgs(i64, f32, -1e6);
            try testArgs(i64, f32, -1e4);
            try testArgs(i64, f32, -1e2);
            try testArgs(i64, f32, -1e0);
            try testArgs(i64, f32, -1e-1);
            try testArgs(i64, f32, -0.0);
            try testArgs(i64, f32, 0.0);
            try testArgs(i64, f32, 1e-1);
            try testArgs(i64, f32, 1e0);
            try testArgs(i64, f32, 1e2);
            try testArgs(i64, f32, 1e4);
            try testArgs(i64, f32, 1e6);
            try testArgs(i64, f32, 1e8);
            try testArgs(i64, f32, 1e10);
            try testArgs(i64, f32, 1e12);
            try testArgs(i64, f32, 1e14);
            try testArgs(i64, f32, 1e16);
            try testArgs(i64, f32, 1e18);
            try testArgs(i64, f32, next(f32, next(f32, 0x0.8p64, 0.0), 0.0));
            try testArgs(i64, f32, next(f32, 0x0.8p64, 0.0));

            try testArgs(u64, f32, -0.0);
            try testArgs(u64, f32, 0.0);
            try testArgs(u64, f32, 1e-1);
            try testArgs(u64, f32, 1e0);
            try testArgs(u64, f32, 1e2);
            try testArgs(u64, f32, 1e4);
            try testArgs(u64, f32, 1e6);
            try testArgs(u64, f32, 1e8);
            try testArgs(u64, f32, 1e10);
            try testArgs(u64, f32, 1e12);
            try testArgs(u64, f32, 1e14);
            try testArgs(u64, f32, 1e16);
            try testArgs(u64, f32, 1e18);
            try testArgs(u64, f32, next(f32, next(f32, 0x1p64, 0.0), 0.0));
            try testArgs(u64, f32, next(f32, 0x1p64, 0.0));

            try testArgs(i128, f32, -0x0.8p128);
            try testArgs(i128, f32, next(f32, -0x0.8p128, -0.0));
            try testArgs(i128, f32, next(f32, next(f32, -0x0.8p128, -0.0), -0.0));
            try testArgs(i128, f32, -1e38);
            try testArgs(i128, f32, -1e34);
            try testArgs(i128, f32, -1e30);
            try testArgs(i128, f32, -1e26);
            try testArgs(i128, f32, -1e22);
            try testArgs(i128, f32, -1e18);
            try testArgs(i128, f32, -1e14);
            try testArgs(i128, f32, -1e10);
            try testArgs(i128, f32, -1e6);
            try testArgs(i128, f32, -1e2);
            try testArgs(i128, f32, -1e0);
            try testArgs(i128, f32, -1e-1);
            try testArgs(i128, f32, -0.0);
            try testArgs(i128, f32, 0.0);
            try testArgs(i128, f32, 1e-1);
            try testArgs(i128, f32, 1e0);
            try testArgs(i128, f32, 1e2);
            try testArgs(i128, f32, 1e6);
            try testArgs(i128, f32, 1e10);
            try testArgs(i128, f32, 1e14);
            try testArgs(i128, f32, 1e18);
            try testArgs(i128, f32, 1e22);
            try testArgs(i128, f32, 1e26);
            try testArgs(i128, f32, 1e30);
            try testArgs(i128, f32, 1e34);
            try testArgs(i128, f32, 1e38);
            try testArgs(i128, f32, next(f32, next(f32, 0x0.8p128, 0.0), 0.0));
            try testArgs(i128, f32, next(f32, 0x0.8p128, 0.0));

            try testArgs(u128, f32, -0.0);
            try testArgs(u128, f32, 0.0);
            try testArgs(u128, f32, 1e-1);
            try testArgs(u128, f32, 1e0);
            try testArgs(u128, f32, 1e2);
            try testArgs(u128, f32, 1e6);
            try testArgs(u128, f32, 1e10);
            try testArgs(u128, f32, 1e14);
            try testArgs(u128, f32, 1e18);
            try testArgs(u128, f32, 1e22);
            try testArgs(u128, f32, 1e26);
            try testArgs(u128, f32, 1e30);
            try testArgs(u128, f32, 1e34);
            try testArgs(u128, f32, 1e38);
            try testArgs(u128, f32, next(f32, next(f32, fmax(f32), 0.0), 0.0));
            try testArgs(u128, f32, next(f32, fmax(f32), 0.0));

            try testArgs(i256, f32, -fmax(f32));
            try testArgs(i256, f32, next(f32, -fmax(f32), -0.0));
            try testArgs(i256, f32, next(f32, next(f32, -fmax(f32), -0.0), -0.0));
            try testArgs(i256, f32, -1e38);
            try testArgs(i256, f32, -1e34);
            try testArgs(i256, f32, -1e30);
            try testArgs(i256, f32, -1e26);
            try testArgs(i256, f32, -1e22);
            try testArgs(i256, f32, -1e18);
            try testArgs(i256, f32, -1e14);
            try testArgs(i256, f32, -1e10);
            try testArgs(i256, f32, -1e6);
            try testArgs(i256, f32, -1e2);
            try testArgs(i256, f32, -1e0);
            try testArgs(i256, f32, -1e-1);
            try testArgs(i256, f32, -0.0);
            try testArgs(i256, f32, 0.0);
            try testArgs(i256, f32, 1e-1);
            try testArgs(i256, f32, 1e0);
            try testArgs(i256, f32, 1e2);
            try testArgs(i256, f32, 1e6);
            try testArgs(i256, f32, 1e10);
            try testArgs(i256, f32, 1e14);
            try testArgs(i256, f32, 1e18);
            try testArgs(i256, f32, 1e22);
            try testArgs(i256, f32, 1e26);
            try testArgs(i256, f32, 1e30);
            try testArgs(i256, f32, 1e34);
            try testArgs(i256, f32, 1e38);
            try testArgs(i256, f32, next(f32, next(f32, fmax(f32), 0.0), 0.0));
            try testArgs(i256, f32, next(f32, fmax(f32), 0.0));

            try testArgs(u256, f32, -0.0);
            try testArgs(u256, f32, 0.0);
            try testArgs(u256, f32, 1e-1);
            try testArgs(u256, f32, 1e0);
            try testArgs(u256, f32, 1e2);
            try testArgs(u256, f32, 1e6);
            try testArgs(u256, f32, 1e10);
            try testArgs(u256, f32, 1e14);
            try testArgs(u256, f32, 1e18);
            try testArgs(u256, f32, 1e22);
            try testArgs(u256, f32, 1e26);
            try testArgs(u256, f32, 1e30);
            try testArgs(u256, f32, 1e34);
            try testArgs(u256, f32, 1e38);
            try testArgs(u256, f32, next(f32, next(f32, fmax(f32), 0.0), 0.0));
            try testArgs(u256, f32, next(f32, fmax(f32), 0.0));

            try testArgs(i8, f64, -0x0.8p8);
            try testArgs(i8, f64, next(f64, -0x0.8p8, -0.0));
            try testArgs(i8, f64, next(f64, next(f64, -0x0.8p8, -0.0), -0.0));
            try testArgs(i8, f64, -1e2);
            try testArgs(i8, f64, -1e1);
            try testArgs(i8, f64, -1e0);
            try testArgs(i8, f64, -1e-1);
            try testArgs(i8, f64, -0.0);
            try testArgs(i8, f64, 0.0);
            try testArgs(i8, f64, 1e-1);
            try testArgs(i8, f64, 1e0);
            try testArgs(i8, f64, 1e1);
            try testArgs(i8, f64, 1e2);
            try testArgs(i8, f64, next(f64, next(f64, 0x0.8p8, 0.0), 0.0));
            try testArgs(i8, f64, next(f64, 0x0.8p8, 0.0));

            try testArgs(u8, f64, -0.0);
            try testArgs(u8, f64, 0.0);
            try testArgs(u8, f64, 1e-1);
            try testArgs(u8, f64, 1e0);
            try testArgs(u8, f64, 1e1);
            try testArgs(u8, f64, 1e2);
            try testArgs(u8, f64, next(f64, next(f64, 0x1p8, 0.0), 0.0));
            try testArgs(u8, f64, next(f64, 0x1p8, 0.0));

            try testArgs(i16, f64, -0x0.8p16);
            try testArgs(i16, f64, next(f64, -0x0.8p16, -0.0));
            try testArgs(i16, f64, next(f64, next(f64, -0x0.8p16, -0.0), -0.0));
            try testArgs(i16, f64, -1e4);
            try testArgs(i16, f64, -1e3);
            try testArgs(i16, f64, -1e2);
            try testArgs(i16, f64, -1e1);
            try testArgs(i16, f64, -1e0);
            try testArgs(i16, f64, -1e-1);
            try testArgs(i16, f64, -0.0);
            try testArgs(i16, f64, 0.0);
            try testArgs(i16, f64, 1e-1);
            try testArgs(i16, f64, 1e0);
            try testArgs(i16, f64, 1e1);
            try testArgs(i16, f64, 1e2);
            try testArgs(i16, f64, 1e3);
            try testArgs(i16, f64, 1e4);
            try testArgs(i16, f64, next(f64, next(f64, 0x0.8p16, 0.0), 0.0));
            try testArgs(i16, f64, next(f64, 0x0.8p16, 0.0));

            try testArgs(u16, f64, -0.0);
            try testArgs(u16, f64, 0.0);
            try testArgs(u16, f64, 1e-1);
            try testArgs(u16, f64, 1e0);
            try testArgs(u16, f64, 1e1);
            try testArgs(u16, f64, 1e2);
            try testArgs(u16, f64, 1e3);
            try testArgs(u16, f64, 1e4);
            try testArgs(u16, f64, next(f64, next(f64, 0x1p16, 0.0), 0.0));
            try testArgs(u16, f64, next(f64, 0x1p16, 0.0));

            try testArgs(i32, f64, -0x0.8p32);
            try testArgs(i32, f64, next(f64, -0x0.8p32, -0.0));
            try testArgs(i32, f64, next(f64, next(f64, -0x0.8p32, -0.0), -0.0));
            try testArgs(i32, f64, -1e9);
            try testArgs(i32, f64, -1e8);
            try testArgs(i32, f64, -1e7);
            try testArgs(i32, f64, -1e6);
            try testArgs(i32, f64, -1e5);
            try testArgs(i32, f64, -1e4);
            try testArgs(i32, f64, -1e3);
            try testArgs(i32, f64, -1e2);
            try testArgs(i32, f64, -1e1);
            try testArgs(i32, f64, -1e0);
            try testArgs(i32, f64, -1e-1);
            try testArgs(i32, f64, -0.0);
            try testArgs(i32, f64, 0.0);
            try testArgs(i32, f64, 1e-1);
            try testArgs(i32, f64, 1e0);
            try testArgs(i32, f64, 1e1);
            try testArgs(i32, f64, 1e2);
            try testArgs(i32, f64, 1e3);
            try testArgs(i32, f64, 1e4);
            try testArgs(i32, f64, 1e5);
            try testArgs(i32, f64, 1e6);
            try testArgs(i32, f64, 1e7);
            try testArgs(i32, f64, 1e8);
            try testArgs(i32, f64, 1e9);
            try testArgs(i32, f64, next(f64, next(f64, 0x0.8p32, 0.0), 0.0));
            try testArgs(i32, f64, next(f64, 0x0.8p32, 0.0));

            try testArgs(u32, f64, -0.0);
            try testArgs(u32, f64, 0.0);
            try testArgs(u32, f64, 1e-1);
            try testArgs(u32, f64, 1e0);
            try testArgs(u32, f64, 1e1);
            try testArgs(u32, f64, 1e2);
            try testArgs(u32, f64, 1e3);
            try testArgs(u32, f64, 1e4);
            try testArgs(u32, f64, 1e5);
            try testArgs(u32, f64, 1e6);
            try testArgs(u32, f64, 1e7);
            try testArgs(u32, f64, 1e8);
            try testArgs(u32, f64, 1e9);
            try testArgs(u32, f64, next(f64, next(f64, 0x1p32, 0.0), 0.0));
            try testArgs(u32, f64, next(f64, 0x1p32, 0.0));

            try testArgs(i64, f64, -0x0.8p64);
            try testArgs(i64, f64, next(f64, -0x0.8p64, -0.0));
            try testArgs(i64, f64, next(f64, next(f64, -0x0.8p64, -0.0), -0.0));
            try testArgs(i64, f64, -1e18);
            try testArgs(i64, f64, -1e16);
            try testArgs(i64, f64, -1e14);
            try testArgs(i64, f64, -1e12);
            try testArgs(i64, f64, -1e10);
            try testArgs(i64, f64, -1e8);
            try testArgs(i64, f64, -1e6);
            try testArgs(i64, f64, -1e4);
            try testArgs(i64, f64, -1e2);
            try testArgs(i64, f64, -1e0);
            try testArgs(i64, f64, -1e-1);
            try testArgs(i64, f64, -0.0);
            try testArgs(i64, f64, 0.0);
            try testArgs(i64, f64, 1e-1);
            try testArgs(i64, f64, 1e0);
            try testArgs(i64, f64, 1e2);
            try testArgs(i64, f64, 1e4);
            try testArgs(i64, f64, 1e6);
            try testArgs(i64, f64, 1e8);
            try testArgs(i64, f64, 1e10);
            try testArgs(i64, f64, 1e12);
            try testArgs(i64, f64, 1e14);
            try testArgs(i64, f64, 1e16);
            try testArgs(i64, f64, 1e18);
            try testArgs(i64, f64, next(f64, next(f64, 0x0.8p64, 0.0), 0.0));
            try testArgs(i64, f64, next(f64, 0x0.8p64, 0.0));

            try testArgs(u64, f64, -0.0);
            try testArgs(u64, f64, 0.0);
            try testArgs(u64, f64, 1e-1);
            try testArgs(u64, f64, 1e0);
            try testArgs(u64, f64, 1e2);
            try testArgs(u64, f64, 1e4);
            try testArgs(u64, f64, 1e6);
            try testArgs(u64, f64, 1e8);
            try testArgs(u64, f64, 1e10);
            try testArgs(u64, f64, 1e12);
            try testArgs(u64, f64, 1e14);
            try testArgs(u64, f64, 1e16);
            try testArgs(u64, f64, 1e18);
            try testArgs(u64, f64, next(f64, next(f64, 0x1p64, 0.0), 0.0));
            try testArgs(u64, f64, next(f64, 0x1p64, 0.0));

            try testArgs(i128, f64, -0x0.8p128);
            try testArgs(i128, f64, next(f64, -0x0.8p128, -0.0));
            try testArgs(i128, f64, next(f64, next(f64, -0x0.8p128, -0.0), -0.0));
            try testArgs(i128, f64, -1e38);
            try testArgs(i128, f64, -1e34);
            try testArgs(i128, f64, -1e30);
            try testArgs(i128, f64, -1e26);
            try testArgs(i128, f64, -1e22);
            try testArgs(i128, f64, -1e18);
            try testArgs(i128, f64, -1e14);
            try testArgs(i128, f64, -1e10);
            try testArgs(i128, f64, -1e6);
            try testArgs(i128, f64, -1e2);
            try testArgs(i128, f64, -1e0);
            try testArgs(i128, f64, -1e-1);
            try testArgs(i128, f64, -0.0);
            try testArgs(i128, f64, 0.0);
            try testArgs(i128, f64, 1e-1);
            try testArgs(i128, f64, 1e0);
            try testArgs(i128, f64, 1e2);
            try testArgs(i128, f64, 1e6);
            try testArgs(i128, f64, 1e10);
            try testArgs(i128, f64, 1e14);
            try testArgs(i128, f64, 1e18);
            try testArgs(i128, f64, 1e22);
            try testArgs(i128, f64, 1e26);
            try testArgs(i128, f64, 1e30);
            try testArgs(i128, f64, 1e34);
            try testArgs(i128, f64, 1e38);
            try testArgs(i128, f64, next(f64, next(f64, 0x0.8p128, 0.0), 0.0));
            try testArgs(i128, f64, next(f64, 0x0.8p128, 0.0));

            try testArgs(u128, f64, -0.0);
            try testArgs(u128, f64, 0.0);
            try testArgs(u128, f64, 1e-1);
            try testArgs(u128, f64, 1e0);
            try testArgs(u128, f64, 1e2);
            try testArgs(u128, f64, 1e6);
            try testArgs(u128, f64, 1e10);
            try testArgs(u128, f64, 1e14);
            try testArgs(u128, f64, 1e18);
            try testArgs(u128, f64, 1e22);
            try testArgs(u128, f64, 1e26);
            try testArgs(u128, f64, 1e30);
            try testArgs(u128, f64, 1e34);
            try testArgs(u128, f64, 1e38);
            try testArgs(u128, f64, next(f64, next(f64, 0x1p128, 0.0), 0.0));
            try testArgs(u128, f64, next(f64, 0x1p128, 0.0));

            try testArgs(i256, f64, -0x0.8p256);
            try testArgs(i256, f64, next(f64, -0x0.8p256, -0.0));
            try testArgs(i256, f64, next(f64, next(f64, -0x0.8p256, -0.0), -0.0));
            try testArgs(i256, f64, -1e76);
            try testArgs(i256, f64, -1e69);
            try testArgs(i256, f64, -1e62);
            try testArgs(i256, f64, -1e55);
            try testArgs(i256, f64, -1e48);
            try testArgs(i256, f64, -1e41);
            try testArgs(i256, f64, -1e34);
            try testArgs(i256, f64, -1e27);
            try testArgs(i256, f64, -1e20);
            try testArgs(i256, f64, -1e13);
            try testArgs(i256, f64, -1e6);
            try testArgs(i256, f64, -1e0);
            try testArgs(i256, f64, -1e-1);
            try testArgs(i256, f64, -0.0);
            try testArgs(i256, f64, 0.0);
            try testArgs(i256, f64, 1e-1);
            try testArgs(i256, f64, 1e0);
            try testArgs(i256, f64, 1e6);
            try testArgs(i256, f64, 1e13);
            try testArgs(i256, f64, 1e20);
            try testArgs(i256, f64, 1e27);
            try testArgs(i256, f64, 1e34);
            try testArgs(i256, f64, 1e41);
            try testArgs(i256, f64, 1e48);
            try testArgs(i256, f64, 1e55);
            try testArgs(i256, f64, 1e62);
            try testArgs(i256, f64, 1e69);
            try testArgs(i256, f64, 1e76);
            try testArgs(i256, f64, next(f64, next(f64, 0x0.8p256, 0.0), 0.0));
            try testArgs(i256, f64, next(f64, 0x0.8p256, 0.0));

            try testArgs(u256, f64, -0.0);
            try testArgs(u256, f64, 0.0);
            try testArgs(u256, f64, 1e-1);
            try testArgs(u256, f64, 1e0);
            try testArgs(u256, f64, 1e7);
            try testArgs(u256, f64, 1e14);
            try testArgs(u256, f64, 1e21);
            try testArgs(u256, f64, 1e28);
            try testArgs(u256, f64, 1e35);
            try testArgs(u256, f64, 1e42);
            try testArgs(u256, f64, 1e49);
            try testArgs(u256, f64, 1e56);
            try testArgs(u256, f64, 1e63);
            try testArgs(u256, f64, 1e70);
            try testArgs(u256, f64, 1e77);
            try testArgs(u256, f64, next(f64, next(f64, 0x1p256, 0.0), 0.0));
            try testArgs(u256, f64, next(f64, 0x1p256, 0.0));

            try testArgs(i8, f80, -0x0.8p8);
            try testArgs(i8, f80, next(f80, -0x0.8p8, -0.0));
            try testArgs(i8, f80, next(f80, next(f80, -0x0.8p8, -0.0), -0.0));
            try testArgs(i8, f80, -1e2);
            try testArgs(i8, f80, -1e1);
            try testArgs(i8, f80, -1e0);
            try testArgs(i8, f80, -1e-1);
            try testArgs(i8, f80, -0.0);
            try testArgs(i8, f80, 0.0);
            try testArgs(i8, f80, 1e-1);
            try testArgs(i8, f80, 1e0);
            try testArgs(i8, f80, 1e1);
            try testArgs(i8, f80, 1e2);
            try testArgs(i8, f80, next(f80, next(f80, 0x0.8p8, 0.0), 0.0));
            try testArgs(i8, f80, next(f80, 0x0.8p8, 0.0));

            try testArgs(u8, f80, -0.0);
            try testArgs(u8, f80, 0.0);
            try testArgs(u8, f80, 1e-1);
            try testArgs(u8, f80, 1e0);
            try testArgs(u8, f80, 1e1);
            try testArgs(u8, f80, 1e2);
            try testArgs(u8, f80, next(f80, next(f80, 0x1p8, 0.0), 0.0));
            try testArgs(u8, f80, next(f80, 0x1p8, 0.0));

            try testArgs(i16, f80, -0x0.8p16);
            try testArgs(i16, f80, next(f80, -0x0.8p16, -0.0));
            try testArgs(i16, f80, next(f80, next(f80, -0x0.8p16, -0.0), -0.0));
            try testArgs(i16, f80, -1e4);
            try testArgs(i16, f80, -1e3);
            try testArgs(i16, f80, -1e2);
            try testArgs(i16, f80, -1e1);
            try testArgs(i16, f80, -1e0);
            try testArgs(i16, f80, -1e-1);
            try testArgs(i16, f80, -0.0);
            try testArgs(i16, f80, 0.0);
            try testArgs(i16, f80, 1e-1);
            try testArgs(i16, f80, 1e0);
            try testArgs(i16, f80, 1e1);
            try testArgs(i16, f80, 1e2);
            try testArgs(i16, f80, 1e3);
            try testArgs(i16, f80, 1e4);
            try testArgs(i16, f80, next(f80, next(f80, 0x0.8p16, 0.0), 0.0));
            try testArgs(i16, f80, next(f80, 0x0.8p16, 0.0));

            try testArgs(u16, f80, -0.0);
            try testArgs(u16, f80, 0.0);
            try testArgs(u16, f80, 1e-1);
            try testArgs(u16, f80, 1e0);
            try testArgs(u16, f80, 1e1);
            try testArgs(u16, f80, 1e2);
            try testArgs(u16, f80, 1e3);
            try testArgs(u16, f80, 1e4);
            try testArgs(u16, f80, next(f80, next(f80, 0x1p16, 0.0), 0.0));
            try testArgs(u16, f80, next(f80, 0x1p16, 0.0));

            try testArgs(i32, f80, -0x0.8p32);
            try testArgs(i32, f80, next(f80, -0x0.8p32, -0.0));
            try testArgs(i32, f80, next(f80, next(f80, -0x0.8p32, -0.0), -0.0));
            try testArgs(i32, f80, -1e9);
            try testArgs(i32, f80, -1e8);
            try testArgs(i32, f80, -1e7);
            try testArgs(i32, f80, -1e6);
            try testArgs(i32, f80, -1e5);
            try testArgs(i32, f80, -1e4);
            try testArgs(i32, f80, -1e3);
            try testArgs(i32, f80, -1e2);
            try testArgs(i32, f80, -1e1);
            try testArgs(i32, f80, -1e0);
            try testArgs(i32, f80, -1e-1);
            try testArgs(i32, f80, -0.0);
            try testArgs(i32, f80, 0.0);
            try testArgs(i32, f80, 1e-1);
            try testArgs(i32, f80, 1e0);
            try testArgs(i32, f80, 1e1);
            try testArgs(i32, f80, 1e2);
            try testArgs(i32, f80, 1e3);
            try testArgs(i32, f80, 1e4);
            try testArgs(i32, f80, 1e5);
            try testArgs(i32, f80, 1e6);
            try testArgs(i32, f80, 1e7);
            try testArgs(i32, f80, 1e8);
            try testArgs(i32, f80, 1e9);
            try testArgs(i32, f80, next(f80, next(f80, 0x0.8p32, 0.0), 0.0));
            try testArgs(i32, f80, next(f80, 0x0.8p32, 0.0));

            try testArgs(u32, f80, -0.0);
            try testArgs(u32, f80, 0.0);
            try testArgs(u32, f80, 1e-1);
            try testArgs(u32, f80, 1e0);
            try testArgs(u32, f80, 1e1);
            try testArgs(u32, f80, 1e2);
            try testArgs(u32, f80, 1e3);
            try testArgs(u32, f80, 1e4);
            try testArgs(u32, f80, 1e5);
            try testArgs(u32, f80, 1e6);
            try testArgs(u32, f80, 1e7);
            try testArgs(u32, f80, 1e8);
            try testArgs(u32, f80, 1e9);
            try testArgs(u32, f80, next(f80, next(f80, 0x1p32, 0.0), 0.0));
            try testArgs(u32, f80, next(f80, 0x1p32, 0.0));

            try testArgs(i64, f80, -0x0.8p64);
            try testArgs(i64, f80, next(f80, -0x0.8p64, -0.0));
            try testArgs(i64, f80, next(f80, next(f80, -0x0.8p64, -0.0), -0.0));
            try testArgs(i64, f80, -1e18);
            try testArgs(i64, f80, -1e16);
            try testArgs(i64, f80, -1e14);
            try testArgs(i64, f80, -1e12);
            try testArgs(i64, f80, -1e10);
            try testArgs(i64, f80, -1e8);
            try testArgs(i64, f80, -1e6);
            try testArgs(i64, f80, -1e4);
            try testArgs(i64, f80, -1e2);
            try testArgs(i64, f80, -1e0);
            try testArgs(i64, f80, -1e-1);
            try testArgs(i64, f80, -0.0);
            try testArgs(i64, f80, 0.0);
            try testArgs(i64, f80, 1e-1);
            try testArgs(i64, f80, 1e0);
            try testArgs(i64, f80, 1e2);
            try testArgs(i64, f80, 1e4);
            try testArgs(i64, f80, 1e6);
            try testArgs(i64, f80, 1e8);
            try testArgs(i64, f80, 1e10);
            try testArgs(i64, f80, 1e12);
            try testArgs(i64, f80, 1e14);
            try testArgs(i64, f80, 1e16);
            try testArgs(i64, f80, 1e18);
            try testArgs(i64, f80, next(f80, next(f80, 0x0.8p64, 0.0), 0.0));
            try testArgs(i64, f80, next(f80, 0x0.8p64, 0.0));

            try testArgs(u64, f80, -0.0);
            try testArgs(u64, f80, 0.0);
            try testArgs(u64, f80, 1e-1);
            try testArgs(u64, f80, 1e0);
            try testArgs(u64, f80, 1e2);
            try testArgs(u64, f80, 1e4);
            try testArgs(u64, f80, 1e6);
            try testArgs(u64, f80, 1e8);
            try testArgs(u64, f80, 1e10);
            try testArgs(u64, f80, 1e12);
            try testArgs(u64, f80, 1e14);
            try testArgs(u64, f80, 1e16);
            try testArgs(u64, f80, 1e18);
            try testArgs(u64, f80, next(f80, next(f80, 0x1p64, 0.0), 0.0));
            try testArgs(u64, f80, next(f80, 0x1p64, 0.0));

            try testArgs(i128, f80, -0x0.8p128);
            try testArgs(i128, f80, next(f80, -0x0.8p128, -0.0));
            try testArgs(i128, f80, next(f80, next(f80, -0x0.8p128, -0.0), -0.0));
            try testArgs(i128, f80, -1e38);
            try testArgs(i128, f80, -1e34);
            try testArgs(i128, f80, -1e30);
            try testArgs(i128, f80, -1e26);
            try testArgs(i128, f80, -1e22);
            try testArgs(i128, f80, -1e18);
            try testArgs(i128, f80, -1e14);
            try testArgs(i128, f80, -1e10);
            try testArgs(i128, f80, -1e6);
            try testArgs(i128, f80, -1e2);
            try testArgs(i128, f80, -1e0);
            try testArgs(i128, f80, -1e-1);
            try testArgs(i128, f80, -0.0);
            try testArgs(i128, f80, 0.0);
            try testArgs(i128, f80, 1e-1);
            try testArgs(i128, f80, 1e0);
            try testArgs(i128, f80, 1e2);
            try testArgs(i128, f80, 1e6);
            try testArgs(i128, f80, 1e10);
            try testArgs(i128, f80, 1e14);
            try testArgs(i128, f80, 1e18);
            try testArgs(i128, f80, 1e22);
            try testArgs(i128, f80, 1e26);
            try testArgs(i128, f80, 1e30);
            try testArgs(i128, f80, 1e34);
            try testArgs(i128, f80, 1e38);
            try testArgs(i128, f80, next(f80, next(f80, 0x0.8p128, 0.0), 0.0));
            try testArgs(i128, f80, next(f80, 0x0.8p128, 0.0));

            try testArgs(u128, f80, -0.0);
            try testArgs(u128, f80, 0.0);
            try testArgs(u128, f80, 1e-1);
            try testArgs(u128, f80, 1e0);
            try testArgs(u128, f80, 1e2);
            try testArgs(u128, f80, 1e6);
            try testArgs(u128, f80, 1e10);
            try testArgs(u128, f80, 1e14);
            try testArgs(u128, f80, 1e18);
            try testArgs(u128, f80, 1e22);
            try testArgs(u128, f80, 1e26);
            try testArgs(u128, f80, 1e30);
            try testArgs(u128, f80, 1e34);
            try testArgs(u128, f80, 1e38);
            try testArgs(u128, f80, next(f80, next(f80, 0x1p128, 0.0), 0.0));
            try testArgs(u128, f80, next(f80, 0x1p128, 0.0));

            try testArgs(i256, f80, -0x0.8p256);
            try testArgs(i256, f80, next(f80, -0x0.8p256, -0.0));
            try testArgs(i256, f80, next(f80, next(f80, -0x0.8p256, -0.0), -0.0));
            try testArgs(i256, f80, -1e76);
            try testArgs(i256, f80, -1e69);
            try testArgs(i256, f80, -1e62);
            try testArgs(i256, f80, -1e55);
            try testArgs(i256, f80, -1e48);
            try testArgs(i256, f80, -1e41);
            try testArgs(i256, f80, -1e34);
            try testArgs(i256, f80, -1e27);
            try testArgs(i256, f80, -1e20);
            try testArgs(i256, f80, -1e13);
            try testArgs(i256, f80, -1e6);
            try testArgs(i256, f80, -1e0);
            try testArgs(i256, f80, -1e-1);
            try testArgs(i256, f80, -0.0);
            try testArgs(i256, f80, 0.0);
            try testArgs(i256, f80, 1e-1);
            try testArgs(i256, f80, 1e0);
            try testArgs(i256, f80, 1e6);
            try testArgs(i256, f80, 1e13);
            try testArgs(i256, f80, 1e20);
            try testArgs(i256, f80, 1e27);
            try testArgs(i256, f80, 1e34);
            try testArgs(i256, f80, 1e41);
            try testArgs(i256, f80, 1e48);
            try testArgs(i256, f80, 1e55);
            try testArgs(i256, f80, 1e62);
            try testArgs(i256, f80, 1e69);
            try testArgs(i256, f80, 1e76);
            try testArgs(i256, f80, next(f80, next(f80, 0x0.8p256, 0.0), 0.0));
            try testArgs(i256, f80, next(f80, 0x0.8p256, 0.0));

            try testArgs(u256, f80, -0.0);
            try testArgs(u256, f80, 0.0);
            try testArgs(u256, f80, 1e-1);
            try testArgs(u256, f80, 1e0);
            try testArgs(u256, f80, 1e7);
            try testArgs(u256, f80, 1e14);
            try testArgs(u256, f80, 1e21);
            try testArgs(u256, f80, 1e28);
            try testArgs(u256, f80, 1e35);
            try testArgs(u256, f80, 1e42);
            try testArgs(u256, f80, 1e49);
            try testArgs(u256, f80, 1e56);
            try testArgs(u256, f80, 1e63);
            try testArgs(u256, f80, 1e70);
            try testArgs(u256, f80, 1e77);
            try testArgs(u256, f80, next(f80, next(f80, 0x1p256, 0.0), 0.0));
            try testArgs(u256, f80, next(f80, 0x1p256, 0.0));

            try testArgs(i8, f128, -0x0.8p8);
            try testArgs(i8, f128, next(f128, -0x0.8p8, -0.0));
            try testArgs(i8, f128, next(f128, next(f128, -0x0.8p8, -0.0), -0.0));
            try testArgs(i8, f128, -1e2);
            try testArgs(i8, f128, -1e1);
            try testArgs(i8, f128, -1e0);
            try testArgs(i8, f128, -1e-1);
            try testArgs(i8, f128, -0.0);
            try testArgs(i8, f128, 0.0);
            try testArgs(i8, f128, 1e-1);
            try testArgs(i8, f128, 1e0);
            try testArgs(i8, f128, 1e1);
            try testArgs(i8, f128, 1e2);
            try testArgs(i8, f128, next(f128, next(f128, 0x0.8p8, 0.0), 0.0));
            try testArgs(i8, f128, next(f128, 0x0.8p8, 0.0));

            try testArgs(u8, f128, -0.0);
            try testArgs(u8, f128, 0.0);
            try testArgs(u8, f128, 1e-1);
            try testArgs(u8, f128, 1e0);
            try testArgs(u8, f128, 1e1);
            try testArgs(u8, f128, 1e2);
            try testArgs(u8, f128, next(f128, next(f128, 0x1p8, 0.0), 0.0));
            try testArgs(u8, f128, next(f128, 0x1p8, 0.0));

            try testArgs(i16, f128, -0x0.8p16);
            try testArgs(i16, f128, next(f128, -0x0.8p16, -0.0));
            try testArgs(i16, f128, next(f128, next(f128, -0x0.8p16, -0.0), -0.0));
            try testArgs(i16, f128, -1e4);
            try testArgs(i16, f128, -1e3);
            try testArgs(i16, f128, -1e2);
            try testArgs(i16, f128, -1e1);
            try testArgs(i16, f128, -1e0);
            try testArgs(i16, f128, -1e-1);
            try testArgs(i16, f128, -0.0);
            try testArgs(i16, f128, 0.0);
            try testArgs(i16, f128, 1e-1);
            try testArgs(i16, f128, 1e0);
            try testArgs(i16, f128, 1e1);
            try testArgs(i16, f128, 1e2);
            try testArgs(i16, f128, 1e3);
            try testArgs(i16, f128, 1e4);
            try testArgs(i16, f128, next(f128, next(f128, 0x0.8p16, 0.0), 0.0));
            try testArgs(i16, f128, next(f128, 0x0.8p16, 0.0));

            try testArgs(u16, f128, -0.0);
            try testArgs(u16, f128, 0.0);
            try testArgs(u16, f128, 1e-1);
            try testArgs(u16, f128, 1e0);
            try testArgs(u16, f128, 1e1);
            try testArgs(u16, f128, 1e2);
            try testArgs(u16, f128, 1e3);
            try testArgs(u16, f128, 1e4);
            try testArgs(u16, f128, next(f128, next(f128, 0x1p16, 0.0), 0.0));
            try testArgs(u16, f128, next(f128, 0x1p16, 0.0));

            try testArgs(i32, f128, -0x0.8p32);
            try testArgs(i32, f128, next(f128, -0x0.8p32, -0.0));
            try testArgs(i32, f128, next(f128, next(f128, -0x0.8p32, -0.0), -0.0));
            try testArgs(i32, f128, -1e9);
            try testArgs(i32, f128, -1e8);
            try testArgs(i32, f128, -1e7);
            try testArgs(i32, f128, -1e6);
            try testArgs(i32, f128, -1e5);
            try testArgs(i32, f128, -1e4);
            try testArgs(i32, f128, -1e3);
            try testArgs(i32, f128, -1e2);
            try testArgs(i32, f128, -1e1);
            try testArgs(i32, f128, -1e0);
            try testArgs(i32, f128, -1e-1);
            try testArgs(i32, f128, -0.0);
            try testArgs(i32, f128, 0.0);
            try testArgs(i32, f128, 1e-1);
            try testArgs(i32, f128, 1e0);
            try testArgs(i32, f128, 1e1);
            try testArgs(i32, f128, 1e2);
            try testArgs(i32, f128, 1e3);
            try testArgs(i32, f128, 1e4);
            try testArgs(i32, f128, 1e5);
            try testArgs(i32, f128, 1e6);
            try testArgs(i32, f128, 1e7);
            try testArgs(i32, f128, 1e8);
            try testArgs(i32, f128, 1e9);
            try testArgs(i32, f128, next(f128, next(f128, 0x0.8p32, 0.0), 0.0));
            try testArgs(i32, f128, next(f128, 0x0.8p32, 0.0));

            try testArgs(u32, f128, -0.0);
            try testArgs(u32, f128, 0.0);
            try testArgs(u32, f128, 1e-1);
            try testArgs(u32, f128, 1e0);
            try testArgs(u32, f128, 1e1);
            try testArgs(u32, f128, 1e2);
            try testArgs(u32, f128, 1e3);
            try testArgs(u32, f128, 1e4);
            try testArgs(u32, f128, 1e5);
            try testArgs(u32, f128, 1e6);
            try testArgs(u32, f128, 1e7);
            try testArgs(u32, f128, 1e8);
            try testArgs(u32, f128, 1e9);
            try testArgs(u32, f128, next(f128, next(f128, 0x1p32, 0.0), 0.0));
            try testArgs(u32, f128, next(f128, 0x1p32, 0.0));

            try testArgs(i64, f128, -0x0.8p64);
            try testArgs(i64, f128, next(f128, -0x0.8p64, -0.0));
            try testArgs(i64, f128, next(f128, next(f128, -0x0.8p64, -0.0), -0.0));
            try testArgs(i64, f128, -1e18);
            try testArgs(i64, f128, -1e16);
            try testArgs(i64, f128, -1e14);
            try testArgs(i64, f128, -1e12);
            try testArgs(i64, f128, -1e10);
            try testArgs(i64, f128, -1e8);
            try testArgs(i64, f128, -1e6);
            try testArgs(i64, f128, -1e4);
            try testArgs(i64, f128, -1e2);
            try testArgs(i64, f128, -1e0);
            try testArgs(i64, f128, -1e-1);
            try testArgs(i64, f128, -0.0);
            try testArgs(i64, f128, 0.0);
            try testArgs(i64, f128, 1e-1);
            try testArgs(i64, f128, 1e0);
            try testArgs(i64, f128, 1e2);
            try testArgs(i64, f128, 1e4);
            try testArgs(i64, f128, 1e6);
            try testArgs(i64, f128, 1e8);
            try testArgs(i64, f128, 1e10);
            try testArgs(i64, f128, 1e11);
            try testArgs(i64, f128, 1e12);
            try testArgs(i64, f128, 1e13);
            try testArgs(i64, f128, 1e14);
            try testArgs(i64, f128, 1e15);
            try testArgs(i64, f128, 1e16);
            try testArgs(i64, f128, 1e17);
            try testArgs(i64, f128, 1e18);
            try testArgs(i64, f128, next(f128, next(f128, 0x0.8p64, 0.0), 0.0));
            try testArgs(i64, f128, next(f128, 0x0.8p64, 0.0));

            try testArgs(u64, f128, -0.0);
            try testArgs(u64, f128, 0.0);
            try testArgs(u64, f128, 1e-1);
            try testArgs(u64, f128, 1e0);
            try testArgs(u64, f128, 1e2);
            try testArgs(u64, f128, 1e4);
            try testArgs(u64, f128, 1e6);
            try testArgs(u64, f128, 1e8);
            try testArgs(u64, f128, 1e10);
            try testArgs(u64, f128, 1e12);
            try testArgs(u64, f128, 1e14);
            try testArgs(u64, f128, 1e16);
            try testArgs(u64, f128, 1e18);
            try testArgs(u64, f128, next(f128, next(f128, 0x1p64, 0.0), 0.0));
            try testArgs(u64, f128, next(f128, 0x1p64, 0.0));

            try testArgs(i128, f128, -0x0.8p128);
            try testArgs(i128, f128, next(f128, -0x0.8p128, -0.0));
            try testArgs(i128, f128, next(f128, next(f128, -0x0.8p128, -0.0), -0.0));
            try testArgs(i128, f128, -1e38);
            try testArgs(i128, f128, -1e34);
            try testArgs(i128, f128, -1e30);
            try testArgs(i128, f128, -1e26);
            try testArgs(i128, f128, -1e22);
            try testArgs(i128, f128, -1e18);
            try testArgs(i128, f128, -1e14);
            try testArgs(i128, f128, -1e10);
            try testArgs(i128, f128, -1e6);
            try testArgs(i128, f128, -1e2);
            try testArgs(i128, f128, -1e0);
            try testArgs(i128, f128, -1e-1);
            try testArgs(i128, f128, -0.0);
            try testArgs(i128, f128, 0.0);
            try testArgs(i128, f128, 1e-1);
            try testArgs(i128, f128, 1e0);
            try testArgs(i128, f128, 1e2);
            try testArgs(i128, f128, 1e6);
            try testArgs(i128, f128, 1e10);
            try testArgs(i128, f128, 1e14);
            try testArgs(i128, f128, 1e18);
            try testArgs(i128, f128, 1e22);
            try testArgs(i128, f128, 1e26);
            try testArgs(i128, f128, 1e30);
            try testArgs(i128, f128, 1e34);
            try testArgs(i128, f128, 1e38);
            try testArgs(i128, f128, next(f128, next(f128, 0x0.8p128, 0.0), 0.0));
            try testArgs(i128, f128, next(f128, 0x0.8p128, 0.0));

            try testArgs(u128, f128, -0.0);
            try testArgs(u128, f128, 0.0);
            try testArgs(u128, f128, 1e-1);
            try testArgs(u128, f128, 1e0);
            try testArgs(u128, f128, 1e2);
            try testArgs(u128, f128, 1e6);
            try testArgs(u128, f128, 1e10);
            try testArgs(u128, f128, 1e14);
            try testArgs(u128, f128, 1e18);
            try testArgs(u128, f128, 1e22);
            try testArgs(u128, f128, 1e26);
            try testArgs(u128, f128, 1e30);
            try testArgs(u128, f128, 1e34);
            try testArgs(u128, f128, 1e38);
            try testArgs(u128, f128, next(f128, next(f128, 0x1p128, 0.0), 0.0));
            try testArgs(u128, f128, next(f128, 0x1p128, 0.0));

            try testArgs(i256, f128, -0x0.8p256);
            try testArgs(i256, f128, next(f128, -0x0.8p256, -0.0));
            try testArgs(i256, f128, next(f128, next(f128, -0x0.8p256, -0.0), -0.0));
            try testArgs(i256, f128, -1e76);
            try testArgs(i256, f128, -1e69);
            try testArgs(i256, f128, -1e62);
            try testArgs(i256, f128, -1e55);
            try testArgs(i256, f128, -1e48);
            try testArgs(i256, f128, -1e41);
            try testArgs(i256, f128, -1e34);
            try testArgs(i256, f128, -1e27);
            try testArgs(i256, f128, -1e20);
            try testArgs(i256, f128, -1e13);
            try testArgs(i256, f128, -1e6);
            try testArgs(i256, f128, -1e0);
            try testArgs(i256, f128, -1e-1);
            try testArgs(i256, f128, -0.0);
            try testArgs(i256, f128, 0.0);
            try testArgs(i256, f128, 1e-1);
            try testArgs(i256, f128, 1e0);
            try testArgs(i256, f128, 1e6);
            try testArgs(i256, f128, 1e13);
            try testArgs(i256, f128, 1e20);
            try testArgs(i256, f128, 1e27);
            try testArgs(i256, f128, 1e34);
            try testArgs(i256, f128, 1e41);
            try testArgs(i256, f128, 1e48);
            try testArgs(i256, f128, 1e55);
            try testArgs(i256, f128, 1e62);
            try testArgs(i256, f128, 1e69);
            try testArgs(i256, f128, 1e76);
            try testArgs(i256, f128, next(f128, next(f128, 0x0.8p256, 0.0), 0.0));
            try testArgs(i256, f128, next(f128, 0x0.8p256, 0.0));

            try testArgs(u256, f128, -0.0);
            try testArgs(u256, f128, 0.0);
            try testArgs(u256, f128, 1e-1);
            try testArgs(u256, f128, 1e0);
            try testArgs(u256, f128, 1e7);
            try testArgs(u256, f128, 1e14);
            try testArgs(u256, f128, 1e21);
            try testArgs(u256, f128, 1e28);
            try testArgs(u256, f128, 1e35);
            try testArgs(u256, f128, 1e42);
            try testArgs(u256, f128, 1e49);
            try testArgs(u256, f128, 1e56);
            try testArgs(u256, f128, 1e63);
            try testArgs(u256, f128, 1e70);
            try testArgs(u256, f128, 1e77);
            try testArgs(u256, f128, next(f128, next(f128, 0x1p256, 0.0), 0.0));
            try testArgs(u256, f128, next(f128, 0x1p256, 0.0));
        }
        fn testFloatsFromInts() !void {
            try testArgs(f16, i8, imin(i8));
            try testArgs(f16, i8, imin(i8) + 1);
            try testArgs(f16, i8, -1e2);
            try testArgs(f16, i8, -1e1);
            try testArgs(f16, i8, -1e0);
            try testArgs(f16, i8, 0);
            try testArgs(f16, i8, 1e0);
            try testArgs(f16, i8, 1e1);
            try testArgs(f16, i8, 1e2);
            try testArgs(f16, i8, imax(i8) - 1);
            try testArgs(f16, i8, imax(i8));

            try testArgs(f16, u8, 0);
            try testArgs(f16, u8, 1e0);
            try testArgs(f16, u8, 1e1);
            try testArgs(f16, u8, 1e2);
            try testArgs(f16, u8, imax(u8) - 1);
            try testArgs(f16, u8, imax(u8));

            try testArgs(f16, i16, imin(i16));
            try testArgs(f16, i16, imin(i16) + 1);
            try testArgs(f16, i16, -1e4);
            try testArgs(f16, i16, -1e3);
            try testArgs(f16, i16, -1e2);
            try testArgs(f16, i16, -1e1);
            try testArgs(f16, i16, -1e0);
            try testArgs(f16, i16, 0);
            try testArgs(f16, i16, 1e0);
            try testArgs(f16, i16, 1e1);
            try testArgs(f16, i16, 1e2);
            try testArgs(f16, i16, 1e3);
            try testArgs(f16, i16, 1e4);
            try testArgs(f16, i16, imax(i16) - 1);
            try testArgs(f16, i16, imax(i16));

            try testArgs(f16, u16, 0);
            try testArgs(f16, u16, 1e0);
            try testArgs(f16, u16, 1e1);
            try testArgs(f16, u16, 1e2);
            try testArgs(f16, u16, 1e3);
            try testArgs(f16, u16, 1e4);
            try testArgs(f16, u16, imax(u16) - 1);
            try testArgs(f16, u16, imax(u16));

            try testArgs(f16, i32, imin(i32));
            try testArgs(f16, i32, imin(i32) + 1);
            try testArgs(f16, i32, -1e9);
            try testArgs(f16, i32, -1e8);
            try testArgs(f16, i32, -1e7);
            try testArgs(f16, i32, -1e6);
            try testArgs(f16, i32, -1e5);
            try testArgs(f16, i32, -1e4);
            try testArgs(f16, i32, -1e3);
            try testArgs(f16, i32, -1e2);
            try testArgs(f16, i32, -1e1);
            try testArgs(f16, i32, -1e0);
            try testArgs(f16, i32, 0);
            try testArgs(f16, i32, 1e0);
            try testArgs(f16, i32, 1e1);
            try testArgs(f16, i32, 1e2);
            try testArgs(f16, i32, 1e3);
            try testArgs(f16, i32, 1e4);
            try testArgs(f16, i32, 1e5);
            try testArgs(f16, i32, 1e6);
            try testArgs(f16, i32, 1e7);
            try testArgs(f16, i32, 1e8);
            try testArgs(f16, i32, 1e9);
            try testArgs(f16, i32, imax(i32) - 1);
            try testArgs(f16, i32, imax(i32));

            try testArgs(f16, u32, 0);
            try testArgs(f16, u32, 1e0);
            try testArgs(f16, u32, 1e1);
            try testArgs(f16, u32, 1e2);
            try testArgs(f16, u32, 1e3);
            try testArgs(f16, u32, 1e4);
            try testArgs(f16, u32, 1e5);
            try testArgs(f16, u32, 1e6);
            try testArgs(f16, u32, 1e7);
            try testArgs(f16, u32, 1e8);
            try testArgs(f16, u32, 1e9);
            try testArgs(f16, u32, imax(u32) - 1);
            try testArgs(f16, u32, imax(u32));

            try testArgs(f16, i64, imin(i64));
            try testArgs(f16, i64, imin(i64) + 1);
            try testArgs(f16, i64, -1e18);
            try testArgs(f16, i64, -1e16);
            try testArgs(f16, i64, -1e14);
            try testArgs(f16, i64, -1e12);
            try testArgs(f16, i64, -1e10);
            try testArgs(f16, i64, -1e8);
            try testArgs(f16, i64, -1e6);
            try testArgs(f16, i64, -1e4);
            try testArgs(f16, i64, -1e2);
            try testArgs(f16, i64, -1e0);
            try testArgs(f16, i64, 0);
            try testArgs(f16, i64, 1e0);
            try testArgs(f16, i64, 1e2);
            try testArgs(f16, i64, 1e4);
            try testArgs(f16, i64, 1e6);
            try testArgs(f16, i64, 1e8);
            try testArgs(f16, i64, 1e10);
            try testArgs(f16, i64, 1e12);
            try testArgs(f16, i64, 1e14);
            try testArgs(f16, i64, 1e16);
            try testArgs(f16, i64, 1e18);
            try testArgs(f16, i64, imax(i64) - 1);
            try testArgs(f16, i64, imax(i64));

            try testArgs(f16, u64, 0);
            try testArgs(f16, u64, 1e0);
            try testArgs(f16, u64, 1e2);
            try testArgs(f16, u64, 1e4);
            try testArgs(f16, u64, 1e6);
            try testArgs(f16, u64, 1e8);
            try testArgs(f16, u64, 1e10);
            try testArgs(f16, u64, 1e12);
            try testArgs(f16, u64, 1e14);
            try testArgs(f16, u64, 1e16);
            try testArgs(f16, u64, 1e18);
            try testArgs(f16, u64, imax(u64) - 1);
            try testArgs(f16, u64, imax(u64));

            try testArgs(f16, i128, imin(i128));
            try testArgs(f16, i128, imin(i128) + 1);
            try testArgs(f16, i128, -1e38);
            try testArgs(f16, i128, -1e34);
            try testArgs(f16, i128, -1e30);
            try testArgs(f16, i128, -1e26);
            try testArgs(f16, i128, -1e22);
            try testArgs(f16, i128, -1e18);
            try testArgs(f16, i128, -1e14);
            try testArgs(f16, i128, -1e10);
            try testArgs(f16, i128, -1e6);
            try testArgs(f16, i128, -1e2);
            try testArgs(f16, i128, -1e0);
            try testArgs(f16, i128, 0);
            try testArgs(f16, i128, 1e0);
            try testArgs(f16, i128, 1e2);
            try testArgs(f16, i128, 1e6);
            try testArgs(f16, i128, 1e10);
            try testArgs(f16, i128, 1e14);
            try testArgs(f16, i128, 1e18);
            try testArgs(f16, i128, 1e22);
            try testArgs(f16, i128, 1e26);
            try testArgs(f16, i128, 1e30);
            try testArgs(f16, i128, 1e34);
            try testArgs(f16, i128, 1e38);
            try testArgs(f16, i128, imax(i128) - 1);
            try testArgs(f16, i128, imax(i128));

            try testArgs(f16, u128, 0);
            try testArgs(f16, u128, 1e0);
            try testArgs(f16, u128, 1e2);
            try testArgs(f16, u128, 1e6);
            try testArgs(f16, u128, 1e10);
            try testArgs(f16, u128, 1e14);
            try testArgs(f16, u128, 1e18);
            try testArgs(f16, u128, 1e22);
            try testArgs(f16, u128, 1e26);
            try testArgs(f16, u128, 1e30);
            try testArgs(f16, u128, 1e34);
            try testArgs(f16, u128, 1e38);
            try testArgs(f16, u128, imax(u128) - 1);
            try testArgs(f16, u128, imax(u128));

            try testArgs(f16, i256, imin(i256));
            try testArgs(f16, i256, imin(i256) + 1);
            try testArgs(f16, i256, -1e76);
            try testArgs(f16, i256, -1e69);
            try testArgs(f16, i256, -1e62);
            try testArgs(f16, i256, -1e55);
            try testArgs(f16, i256, -1e48);
            try testArgs(f16, i256, -1e41);
            try testArgs(f16, i256, -1e34);
            try testArgs(f16, i256, -1e27);
            try testArgs(f16, i256, -1e20);
            try testArgs(f16, i256, -1e13);
            try testArgs(f16, i256, -1e6);
            try testArgs(f16, i256, -1e0);
            try testArgs(f16, i256, 0);
            try testArgs(f16, i256, 1e0);
            try testArgs(f16, i256, 1e6);
            try testArgs(f16, i256, 1e13);
            try testArgs(f16, i256, 1e20);
            try testArgs(f16, i256, 1e27);
            try testArgs(f16, i256, 1e34);
            try testArgs(f16, i256, 1e41);
            try testArgs(f16, i256, 1e48);
            try testArgs(f16, i256, 1e55);
            try testArgs(f16, i256, 1e62);
            try testArgs(f16, i256, 1e69);
            try testArgs(f16, i256, 1e76);
            try testArgs(f16, i256, imax(i256) - 1);
            try testArgs(f16, i256, imax(i256));

            try testArgs(f16, u256, 0);
            try testArgs(f16, u256, 1e0);
            try testArgs(f16, u256, 1e7);
            try testArgs(f16, u256, 1e14);
            try testArgs(f16, u256, 1e21);
            try testArgs(f16, u256, 1e28);
            try testArgs(f16, u256, 1e35);
            try testArgs(f16, u256, 1e42);
            try testArgs(f16, u256, 1e49);
            try testArgs(f16, u256, 1e56);
            try testArgs(f16, u256, 1e63);
            try testArgs(f16, u256, 1e70);
            try testArgs(f16, u256, 1e77);
            try testArgs(f16, u256, imax(u256) - 1);
            try testArgs(f16, u256, imax(u256));

            try testArgs(f32, i8, imin(i8));
            try testArgs(f32, i8, imin(i8) + 1);
            try testArgs(f32, i8, -1e2);
            try testArgs(f32, i8, -1e1);
            try testArgs(f32, i8, -1e0);
            try testArgs(f32, i8, 0);
            try testArgs(f32, i8, 1e0);
            try testArgs(f32, i8, 1e1);
            try testArgs(f32, i8, 1e2);
            try testArgs(f32, i8, imax(i8) - 1);
            try testArgs(f32, i8, imax(i8));

            try testArgs(f32, u8, 0);
            try testArgs(f32, u8, 1e0);
            try testArgs(f32, u8, 1e1);
            try testArgs(f32, u8, 1e2);
            try testArgs(f32, u8, imax(u8) - 1);
            try testArgs(f32, u8, imax(u8));

            try testArgs(f32, i16, imin(i16));
            try testArgs(f32, i16, imin(i16) + 1);
            try testArgs(f32, i16, -1e4);
            try testArgs(f32, i16, -1e3);
            try testArgs(f32, i16, -1e2);
            try testArgs(f32, i16, -1e1);
            try testArgs(f32, i16, -1e0);
            try testArgs(f32, i16, 0);
            try testArgs(f32, i16, 1e0);
            try testArgs(f32, i16, 1e1);
            try testArgs(f32, i16, 1e2);
            try testArgs(f32, i16, 1e3);
            try testArgs(f32, i16, 1e4);
            try testArgs(f32, i16, imax(i16) - 1);
            try testArgs(f32, i16, imax(i16));

            try testArgs(f32, u16, 0);
            try testArgs(f32, u16, 1e0);
            try testArgs(f32, u16, 1e1);
            try testArgs(f32, u16, 1e2);
            try testArgs(f32, u16, 1e3);
            try testArgs(f32, u16, 1e4);
            try testArgs(f32, u16, imax(u16) - 1);
            try testArgs(f32, u16, imax(u16));

            try testArgs(f32, i32, imin(i32));
            try testArgs(f32, i32, imin(i32) + 1);
            try testArgs(f32, i32, -1e9);
            try testArgs(f32, i32, -1e8);
            try testArgs(f32, i32, -1e7);
            try testArgs(f32, i32, -1e6);
            try testArgs(f32, i32, -1e5);
            try testArgs(f32, i32, -1e4);
            try testArgs(f32, i32, -1e3);
            try testArgs(f32, i32, -1e2);
            try testArgs(f32, i32, -1e1);
            try testArgs(f32, i32, -1e0);
            try testArgs(f32, i32, 0);
            try testArgs(f32, i32, 1e0);
            try testArgs(f32, i32, 1e1);
            try testArgs(f32, i32, 1e2);
            try testArgs(f32, i32, 1e3);
            try testArgs(f32, i32, 1e4);
            try testArgs(f32, i32, 1e5);
            try testArgs(f32, i32, 1e6);
            try testArgs(f32, i32, 1e7);
            try testArgs(f32, i32, 1e8);
            try testArgs(f32, i32, 1e9);
            try testArgs(f32, i32, imax(i32) - 1);
            try testArgs(f32, i32, imax(i32));

            try testArgs(f32, u32, 0);
            try testArgs(f32, u32, 1e0);
            try testArgs(f32, u32, 1e1);
            try testArgs(f32, u32, 1e2);
            try testArgs(f32, u32, 1e3);
            try testArgs(f32, u32, 1e4);
            try testArgs(f32, u32, 1e5);
            try testArgs(f32, u32, 1e6);
            try testArgs(f32, u32, 1e7);
            try testArgs(f32, u32, 1e8);
            try testArgs(f32, u32, 1e9);
            try testArgs(f32, u32, imax(u32) - 1);
            try testArgs(f32, u32, imax(u32));

            try testArgs(f32, i64, imin(i64));
            try testArgs(f32, i64, imin(i64) + 1);
            try testArgs(f32, i64, -1e18);
            try testArgs(f32, i64, -1e16);
            try testArgs(f32, i64, -1e14);
            try testArgs(f32, i64, -1e12);
            try testArgs(f32, i64, -1e10);
            try testArgs(f32, i64, -1e8);
            try testArgs(f32, i64, -1e6);
            try testArgs(f32, i64, -1e4);
            try testArgs(f32, i64, -1e2);
            try testArgs(f32, i64, -1e0);
            try testArgs(f32, i64, 0);
            try testArgs(f32, i64, 1e0);
            try testArgs(f32, i64, 1e2);
            try testArgs(f32, i64, 1e4);
            try testArgs(f32, i64, 1e6);
            try testArgs(f32, i64, 1e8);
            try testArgs(f32, i64, 1e10);
            try testArgs(f32, i64, 1e12);
            try testArgs(f32, i64, 1e14);
            try testArgs(f32, i64, 1e16);
            try testArgs(f32, i64, 1e18);
            try testArgs(f32, i64, imax(i64) - 1);
            try testArgs(f32, i64, imax(i64));

            try testArgs(f32, u64, 0);
            try testArgs(f32, u64, 1e0);
            try testArgs(f32, u64, 1e2);
            try testArgs(f32, u64, 1e4);
            try testArgs(f32, u64, 1e6);
            try testArgs(f32, u64, 1e8);
            try testArgs(f32, u64, 1e10);
            try testArgs(f32, u64, 1e12);
            try testArgs(f32, u64, 1e14);
            try testArgs(f32, u64, 1e16);
            try testArgs(f32, u64, 1e18);
            try testArgs(f32, u64, imax(u64) - 1);
            try testArgs(f32, u64, imax(u64));

            try testArgs(f32, i128, imin(i128));
            try testArgs(f32, i128, imin(i128) + 1);
            try testArgs(f32, i128, -1e38);
            try testArgs(f32, i128, -1e34);
            try testArgs(f32, i128, -1e30);
            try testArgs(f32, i128, -1e26);
            try testArgs(f32, i128, -1e22);
            try testArgs(f32, i128, -1e18);
            try testArgs(f32, i128, -1e14);
            try testArgs(f32, i128, -1e10);
            try testArgs(f32, i128, -1e6);
            try testArgs(f32, i128, -1e2);
            try testArgs(f32, i128, -1e0);
            try testArgs(f32, i128, 0);
            try testArgs(f32, i128, 1e0);
            try testArgs(f32, i128, 1e2);
            try testArgs(f32, i128, 1e6);
            try testArgs(f32, i128, 1e10);
            try testArgs(f32, i128, 1e14);
            try testArgs(f32, i128, 1e18);
            try testArgs(f32, i128, 1e22);
            try testArgs(f32, i128, 1e26);
            try testArgs(f32, i128, 1e30);
            try testArgs(f32, i128, 1e34);
            try testArgs(f32, i128, 1e38);
            try testArgs(f32, i128, imax(i128) - 1);
            try testArgs(f32, i128, imax(i128));

            try testArgs(f32, u128, 0);
            try testArgs(f32, u128, 1e0);
            try testArgs(f32, u128, 1e2);
            try testArgs(f32, u128, 1e6);
            try testArgs(f32, u128, 1e10);
            try testArgs(f32, u128, 1e14);
            try testArgs(f32, u128, 1e18);
            try testArgs(f32, u128, 1e22);
            try testArgs(f32, u128, 1e26);
            try testArgs(f32, u128, 1e30);
            try testArgs(f32, u128, 1e34);
            try testArgs(f32, u128, 1e38);
            try testArgs(f32, u128, imax(u128) - 1);
            try testArgs(f32, u128, imax(u128));

            try testArgs(f32, i256, imin(i256));
            try testArgs(f32, i256, imin(i256) + 1);
            try testArgs(f32, i256, -1e76);
            try testArgs(f32, i256, -1e69);
            try testArgs(f32, i256, -1e62);
            try testArgs(f32, i256, -1e55);
            try testArgs(f32, i256, -1e48);
            try testArgs(f32, i256, -1e41);
            try testArgs(f32, i256, -1e34);
            try testArgs(f32, i256, -1e27);
            try testArgs(f32, i256, -1e20);
            try testArgs(f32, i256, -1e13);
            try testArgs(f32, i256, -1e6);
            try testArgs(f32, i256, -1e0);
            try testArgs(f32, i256, 0);
            try testArgs(f32, i256, 1e0);
            try testArgs(f32, i256, 1e6);
            try testArgs(f32, i256, 1e13);
            try testArgs(f32, i256, 1e20);
            try testArgs(f32, i256, 1e27);
            try testArgs(f32, i256, 1e34);
            try testArgs(f32, i256, 1e41);
            try testArgs(f32, i256, 1e48);
            try testArgs(f32, i256, 1e55);
            try testArgs(f32, i256, 1e62);
            try testArgs(f32, i256, 1e69);
            try testArgs(f32, i256, 1e76);
            try testArgs(f32, i256, imax(i256) - 1);
            try testArgs(f32, i256, imax(i256));

            try testArgs(f32, u256, 0);
            try testArgs(f32, u256, 1e0);
            try testArgs(f32, u256, 1e7);
            try testArgs(f32, u256, 1e14);
            try testArgs(f32, u256, 1e21);
            try testArgs(f32, u256, 1e28);
            try testArgs(f32, u256, 1e35);
            try testArgs(f32, u256, 1e42);
            try testArgs(f32, u256, 1e49);
            try testArgs(f32, u256, 1e56);
            try testArgs(f32, u256, 1e63);
            try testArgs(f32, u256, 1e70);
            try testArgs(f32, u256, 1e77);
            try testArgs(f32, u256, imax(u256) - 1);
            try testArgs(f32, u256, imax(u256));

            try testArgs(f64, i8, imin(i8));
            try testArgs(f64, i8, imin(i8) + 1);
            try testArgs(f64, i8, -1e2);
            try testArgs(f64, i8, -1e1);
            try testArgs(f64, i8, -1e0);
            try testArgs(f64, i8, 0);
            try testArgs(f64, i8, 1e0);
            try testArgs(f64, i8, 1e1);
            try testArgs(f64, i8, 1e2);
            try testArgs(f64, i8, imax(i8) - 1);
            try testArgs(f64, i8, imax(i8));

            try testArgs(f64, u8, 0);
            try testArgs(f64, u8, 1e0);
            try testArgs(f64, u8, 1e1);
            try testArgs(f64, u8, 1e2);
            try testArgs(f64, u8, imax(u8) - 1);
            try testArgs(f64, u8, imax(u8));

            try testArgs(f64, i16, imin(i16));
            try testArgs(f64, i16, imin(i16) + 1);
            try testArgs(f64, i16, -1e4);
            try testArgs(f64, i16, -1e3);
            try testArgs(f64, i16, -1e2);
            try testArgs(f64, i16, -1e1);
            try testArgs(f64, i16, -1e0);
            try testArgs(f64, i16, 0);
            try testArgs(f64, i16, 1e0);
            try testArgs(f64, i16, 1e1);
            try testArgs(f64, i16, 1e2);
            try testArgs(f64, i16, 1e3);
            try testArgs(f64, i16, 1e4);
            try testArgs(f64, i16, imax(i16) - 1);
            try testArgs(f64, i16, imax(i16));

            try testArgs(f64, u16, 0);
            try testArgs(f64, u16, 1e0);
            try testArgs(f64, u16, 1e1);
            try testArgs(f64, u16, 1e2);
            try testArgs(f64, u16, 1e3);
            try testArgs(f64, u16, 1e4);
            try testArgs(f64, u16, imax(u16) - 1);
            try testArgs(f64, u16, imax(u16));

            try testArgs(f64, i32, imin(i32));
            try testArgs(f64, i32, imin(i32) + 1);
            try testArgs(f64, i32, -1e9);
            try testArgs(f64, i32, -1e8);
            try testArgs(f64, i32, -1e7);
            try testArgs(f64, i32, -1e6);
            try testArgs(f64, i32, -1e5);
            try testArgs(f64, i32, -1e4);
            try testArgs(f64, i32, -1e3);
            try testArgs(f64, i32, -1e2);
            try testArgs(f64, i32, -1e1);
            try testArgs(f64, i32, -1e0);
            try testArgs(f64, i32, 0);
            try testArgs(f64, i32, 1e0);
            try testArgs(f64, i32, 1e1);
            try testArgs(f64, i32, 1e2);
            try testArgs(f64, i32, 1e3);
            try testArgs(f64, i32, 1e4);
            try testArgs(f64, i32, 1e5);
            try testArgs(f64, i32, 1e6);
            try testArgs(f64, i32, 1e7);
            try testArgs(f64, i32, 1e8);
            try testArgs(f64, i32, 1e9);
            try testArgs(f64, i32, imax(i32) - 1);
            try testArgs(f64, i32, imax(i32));

            try testArgs(f64, u32, 0);
            try testArgs(f64, u32, 1e0);
            try testArgs(f64, u32, 1e1);
            try testArgs(f64, u32, 1e2);
            try testArgs(f64, u32, 1e3);
            try testArgs(f64, u32, 1e4);
            try testArgs(f64, u32, 1e5);
            try testArgs(f64, u32, 1e6);
            try testArgs(f64, u32, 1e7);
            try testArgs(f64, u32, 1e8);
            try testArgs(f64, u32, 1e9);
            try testArgs(f64, u32, imax(u32) - 1);
            try testArgs(f64, u32, imax(u32));

            try testArgs(f64, i64, imin(i64));
            try testArgs(f64, i64, imin(i64) + 1);
            try testArgs(f64, i64, -1e18);
            try testArgs(f64, i64, -1e16);
            try testArgs(f64, i64, -1e14);
            try testArgs(f64, i64, -1e12);
            try testArgs(f64, i64, -1e10);
            try testArgs(f64, i64, -1e8);
            try testArgs(f64, i64, -1e6);
            try testArgs(f64, i64, -1e4);
            try testArgs(f64, i64, -1e2);
            try testArgs(f64, i64, -1e0);
            try testArgs(f64, i64, 0);
            try testArgs(f64, i64, 1e0);
            try testArgs(f64, i64, 1e2);
            try testArgs(f64, i64, 1e4);
            try testArgs(f64, i64, 1e6);
            try testArgs(f64, i64, 1e8);
            try testArgs(f64, i64, 1e10);
            try testArgs(f64, i64, 1e12);
            try testArgs(f64, i64, 1e14);
            try testArgs(f64, i64, 1e16);
            try testArgs(f64, i64, 1e18);
            try testArgs(f64, i64, imax(i64) - 1);
            try testArgs(f64, i64, imax(i64));

            try testArgs(f64, u64, 0);
            try testArgs(f64, u64, 1e0);
            try testArgs(f64, u64, 1e2);
            try testArgs(f64, u64, 1e4);
            try testArgs(f64, u64, 1e6);
            try testArgs(f64, u64, 1e8);
            try testArgs(f64, u64, 1e10);
            try testArgs(f64, u64, 1e12);
            try testArgs(f64, u64, 1e14);
            try testArgs(f64, u64, 1e16);
            try testArgs(f64, u64, 1e18);
            try testArgs(f64, u64, imax(u64) - 1);
            try testArgs(f64, u64, imax(u64));

            try testArgs(f64, i128, imin(i128));
            try testArgs(f64, i128, imin(i128) + 1);
            try testArgs(f64, i128, -1e38);
            try testArgs(f64, i128, -1e34);
            try testArgs(f64, i128, -1e30);
            try testArgs(f64, i128, -1e26);
            try testArgs(f64, i128, -1e22);
            try testArgs(f64, i128, -1e18);
            try testArgs(f64, i128, -1e14);
            try testArgs(f64, i128, -1e10);
            try testArgs(f64, i128, -1e6);
            try testArgs(f64, i128, -1e2);
            try testArgs(f64, i128, -1e0);
            try testArgs(f64, i128, 0);
            try testArgs(f64, i128, 1e0);
            try testArgs(f64, i128, 1e2);
            try testArgs(f64, i128, 1e6);
            try testArgs(f64, i128, 1e10);
            try testArgs(f64, i128, 1e14);
            try testArgs(f64, i128, 1e18);
            try testArgs(f64, i128, 1e22);
            try testArgs(f64, i128, 1e26);
            try testArgs(f64, i128, 1e30);
            try testArgs(f64, i128, 1e34);
            try testArgs(f64, i128, 1e38);
            try testArgs(f64, i128, imax(i128) - 1);
            try testArgs(f64, i128, imax(i128));

            try testArgs(f64, u128, 0);
            try testArgs(f64, u128, 1e0);
            try testArgs(f64, u128, 1e2);
            try testArgs(f64, u128, 1e6);
            try testArgs(f64, u128, 1e10);
            try testArgs(f64, u128, 1e14);
            try testArgs(f64, u128, 1e18);
            try testArgs(f64, u128, 1e22);
            try testArgs(f64, u128, 1e26);
            try testArgs(f64, u128, 1e30);
            try testArgs(f64, u128, 1e34);
            try testArgs(f64, u128, 1e38);
            try testArgs(f64, u128, imax(u128) - 1);
            try testArgs(f64, u128, imax(u128));

            try testArgs(f64, i256, imin(i256));
            try testArgs(f64, i256, imin(i256) + 1);
            try testArgs(f64, i256, -1e76);
            try testArgs(f64, i256, -1e69);
            try testArgs(f64, i256, -1e62);
            try testArgs(f64, i256, -1e55);
            try testArgs(f64, i256, -1e48);
            try testArgs(f64, i256, -1e41);
            try testArgs(f64, i256, -1e34);
            try testArgs(f64, i256, -1e27);
            try testArgs(f64, i256, -1e20);
            try testArgs(f64, i256, -1e13);
            try testArgs(f64, i256, -1e6);
            try testArgs(f64, i256, -1e0);
            try testArgs(f64, i256, 0);
            try testArgs(f64, i256, 1e0);
            try testArgs(f64, i256, 1e6);
            try testArgs(f64, i256, 1e13);
            try testArgs(f64, i256, 1e20);
            try testArgs(f64, i256, 1e27);
            try testArgs(f64, i256, 1e34);
            try testArgs(f64, i256, 1e41);
            try testArgs(f64, i256, 1e48);
            try testArgs(f64, i256, 1e55);
            try testArgs(f64, i256, 1e62);
            try testArgs(f64, i256, 1e69);
            try testArgs(f64, i256, 1e76);
            try testArgs(f64, i256, imax(i256) - 1);
            try testArgs(f64, i256, imax(i256));

            try testArgs(f64, u256, 0);
            try testArgs(f64, u256, 1e0);
            try testArgs(f64, u256, 1e7);
            try testArgs(f64, u256, 1e14);
            try testArgs(f64, u256, 1e21);
            try testArgs(f64, u256, 1e28);
            try testArgs(f64, u256, 1e35);
            try testArgs(f64, u256, 1e42);
            try testArgs(f64, u256, 1e49);
            try testArgs(f64, u256, 1e56);
            try testArgs(f64, u256, 1e63);
            try testArgs(f64, u256, 1e70);
            try testArgs(f64, u256, 1e77);
            try testArgs(f64, u256, imax(u256) - 1);
            try testArgs(f64, u256, imax(u256));

            try testArgs(f80, i8, imin(i8));
            try testArgs(f80, i8, imin(i8) + 1);
            try testArgs(f80, i8, -1e2);
            try testArgs(f80, i8, -1e1);
            try testArgs(f80, i8, -1e0);
            try testArgs(f80, i8, 0);
            try testArgs(f80, i8, 1e0);
            try testArgs(f80, i8, 1e1);
            try testArgs(f80, i8, 1e2);
            try testArgs(f80, i8, imax(i8) - 1);
            try testArgs(f80, i8, imax(i8));

            try testArgs(f80, u8, 0);
            try testArgs(f80, u8, 1e0);
            try testArgs(f80, u8, 1e1);
            try testArgs(f80, u8, 1e2);
            try testArgs(f80, u8, imax(u8) - 1);
            try testArgs(f80, u8, imax(u8));

            try testArgs(f80, i16, imin(i16));
            try testArgs(f80, i16, imin(i16) + 1);
            try testArgs(f80, i16, -1e4);
            try testArgs(f80, i16, -1e3);
            try testArgs(f80, i16, -1e2);
            try testArgs(f80, i16, -1e1);
            try testArgs(f80, i16, -1e0);
            try testArgs(f80, i16, 0);
            try testArgs(f80, i16, 1e0);
            try testArgs(f80, i16, 1e1);
            try testArgs(f80, i16, 1e2);
            try testArgs(f80, i16, 1e3);
            try testArgs(f80, i16, 1e4);
            try testArgs(f80, i16, imax(i16) - 1);
            try testArgs(f80, i16, imax(i16));

            try testArgs(f80, u16, 0);
            try testArgs(f80, u16, 1e0);
            try testArgs(f80, u16, 1e1);
            try testArgs(f80, u16, 1e2);
            try testArgs(f80, u16, 1e3);
            try testArgs(f80, u16, 1e4);
            try testArgs(f80, u16, imax(u16) - 1);
            try testArgs(f80, u16, imax(u16));

            try testArgs(f80, i32, imin(i32));
            try testArgs(f80, i32, imin(i32) + 1);
            try testArgs(f80, i32, -1e9);
            try testArgs(f80, i32, -1e8);
            try testArgs(f80, i32, -1e7);
            try testArgs(f80, i32, -1e6);
            try testArgs(f80, i32, -1e5);
            try testArgs(f80, i32, -1e4);
            try testArgs(f80, i32, -1e3);
            try testArgs(f80, i32, -1e2);
            try testArgs(f80, i32, -1e1);
            try testArgs(f80, i32, -1e0);
            try testArgs(f80, i32, 0);
            try testArgs(f80, i32, 1e0);
            try testArgs(f80, i32, 1e1);
            try testArgs(f80, i32, 1e2);
            try testArgs(f80, i32, 1e3);
            try testArgs(f80, i32, 1e4);
            try testArgs(f80, i32, 1e5);
            try testArgs(f80, i32, 1e6);
            try testArgs(f80, i32, 1e7);
            try testArgs(f80, i32, 1e8);
            try testArgs(f80, i32, 1e9);
            try testArgs(f80, i32, imax(i32) - 1);
            try testArgs(f80, i32, imax(i32));

            try testArgs(f80, u32, 0);
            try testArgs(f80, u32, 1e0);
            try testArgs(f80, u32, 1e1);
            try testArgs(f80, u32, 1e2);
            try testArgs(f80, u32, 1e3);
            try testArgs(f80, u32, 1e4);
            try testArgs(f80, u32, 1e5);
            try testArgs(f80, u32, 1e6);
            try testArgs(f80, u32, 1e7);
            try testArgs(f80, u32, 1e8);
            try testArgs(f80, u32, 1e9);
            try testArgs(f80, u32, imax(u32) - 1);
            try testArgs(f80, u32, imax(u32));

            try testArgs(f80, i64, imin(i64));
            try testArgs(f80, i64, imin(i64) + 1);
            try testArgs(f80, i64, -1e18);
            try testArgs(f80, i64, -1e16);
            try testArgs(f80, i64, -1e14);
            try testArgs(f80, i64, -1e12);
            try testArgs(f80, i64, -1e10);
            try testArgs(f80, i64, -1e8);
            try testArgs(f80, i64, -1e6);
            try testArgs(f80, i64, -1e4);
            try testArgs(f80, i64, -1e2);
            try testArgs(f80, i64, -1e0);
            try testArgs(f80, i64, 0);
            try testArgs(f80, i64, 1e0);
            try testArgs(f80, i64, 1e2);
            try testArgs(f80, i64, 1e4);
            try testArgs(f80, i64, 1e6);
            try testArgs(f80, i64, 1e8);
            try testArgs(f80, i64, 1e10);
            try testArgs(f80, i64, 1e12);
            try testArgs(f80, i64, 1e14);
            try testArgs(f80, i64, 1e16);
            try testArgs(f80, i64, 1e18);
            try testArgs(f80, i64, imax(i64) - 1);
            try testArgs(f80, i64, imax(i64));

            try testArgs(f80, u64, 0);
            try testArgs(f80, u64, 1e0);
            try testArgs(f80, u64, 1e2);
            try testArgs(f80, u64, 1e4);
            try testArgs(f80, u64, 1e6);
            try testArgs(f80, u64, 1e8);
            try testArgs(f80, u64, 1e10);
            try testArgs(f80, u64, 1e12);
            try testArgs(f80, u64, 1e14);
            try testArgs(f80, u64, 1e16);
            try testArgs(f80, u64, 1e18);
            try testArgs(f80, u64, imax(u64) - 1);
            try testArgs(f80, u64, imax(u64));

            try testArgs(f80, i128, imin(i128));
            try testArgs(f80, i128, imin(i128) + 1);
            try testArgs(f80, i128, -1e38);
            try testArgs(f80, i128, -1e34);
            try testArgs(f80, i128, -1e30);
            try testArgs(f80, i128, -1e26);
            try testArgs(f80, i128, -1e22);
            try testArgs(f80, i128, -1e18);
            try testArgs(f80, i128, -1e14);
            try testArgs(f80, i128, -1e10);
            try testArgs(f80, i128, -1e6);
            try testArgs(f80, i128, -1e2);
            try testArgs(f80, i128, -1e0);
            try testArgs(f80, i128, 0);
            try testArgs(f80, i128, 1e0);
            try testArgs(f80, i128, 1e2);
            try testArgs(f80, i128, 1e6);
            try testArgs(f80, i128, 1e10);
            try testArgs(f80, i128, 1e14);
            try testArgs(f80, i128, 1e18);
            try testArgs(f80, i128, 1e22);
            try testArgs(f80, i128, 1e26);
            try testArgs(f80, i128, 1e30);
            try testArgs(f80, i128, 1e34);
            try testArgs(f80, i128, 1e38);
            try testArgs(f80, i128, imax(i128) - 1);
            try testArgs(f80, i128, imax(i128));

            try testArgs(f80, u128, 0);
            try testArgs(f80, u128, 1e0);
            try testArgs(f80, u128, 1e2);
            try testArgs(f80, u128, 1e6);
            try testArgs(f80, u128, 1e10);
            try testArgs(f80, u128, 1e14);
            try testArgs(f80, u128, 1e18);
            try testArgs(f80, u128, 1e22);
            try testArgs(f80, u128, 1e26);
            try testArgs(f80, u128, 1e30);
            try testArgs(f80, u128, 1e34);
            try testArgs(f80, u128, 1e38);
            try testArgs(f80, u128, imax(u128) - 1);
            try testArgs(f80, u128, imax(u128));

            try testArgs(f80, i256, imin(i256));
            try testArgs(f80, i256, imin(i256) + 1);
            try testArgs(f80, i256, -1e76);
            try testArgs(f80, i256, -1e69);
            try testArgs(f80, i256, -1e62);
            try testArgs(f80, i256, -1e55);
            try testArgs(f80, i256, -1e48);
            try testArgs(f80, i256, -1e41);
            try testArgs(f80, i256, -1e34);
            try testArgs(f80, i256, -1e27);
            try testArgs(f80, i256, -1e20);
            try testArgs(f80, i256, -1e13);
            try testArgs(f80, i256, -1e6);
            try testArgs(f80, i256, -1e0);
            try testArgs(f80, i256, 0);
            try testArgs(f80, i256, 1e0);
            try testArgs(f80, i256, 1e6);
            try testArgs(f80, i256, 1e13);
            try testArgs(f80, i256, 1e20);
            try testArgs(f80, i256, 1e27);
            try testArgs(f80, i256, 1e34);
            try testArgs(f80, i256, 1e41);
            try testArgs(f80, i256, 1e48);
            try testArgs(f80, i256, 1e55);
            try testArgs(f80, i256, 1e62);
            try testArgs(f80, i256, 1e69);
            try testArgs(f80, i256, 1e76);
            try testArgs(f80, i256, imax(i256) - 1);
            try testArgs(f80, i256, imax(i256));

            try testArgs(f80, u256, 0);
            try testArgs(f80, u256, 1e0);
            try testArgs(f80, u256, 1e7);
            try testArgs(f80, u256, 1e14);
            try testArgs(f80, u256, 1e21);
            try testArgs(f80, u256, 1e28);
            try testArgs(f80, u256, 1e35);
            try testArgs(f80, u256, 1e42);
            try testArgs(f80, u256, 1e49);
            try testArgs(f80, u256, 1e56);
            try testArgs(f80, u256, 1e63);
            try testArgs(f80, u256, 1e70);
            try testArgs(f80, u256, 1e77);
            try testArgs(f80, u256, imax(u256) - 1);
            try testArgs(f80, u256, imax(u256));

            try testArgs(f128, i8, imin(i8));
            try testArgs(f128, i8, imin(i8) + 1);
            try testArgs(f128, i8, -1e2);
            try testArgs(f128, i8, -1e1);
            try testArgs(f128, i8, -1e0);
            try testArgs(f128, i8, 0);
            try testArgs(f128, i8, 1e0);
            try testArgs(f128, i8, 1e1);
            try testArgs(f128, i8, 1e2);
            try testArgs(f128, i8, imax(i8) - 1);
            try testArgs(f128, i8, imax(i8));

            try testArgs(f128, u8, 0);
            try testArgs(f128, u8, 1e0);
            try testArgs(f128, u8, 1e1);
            try testArgs(f128, u8, 1e2);
            try testArgs(f128, u8, imax(u8) - 1);
            try testArgs(f128, u8, imax(u8));

            try testArgs(f128, i16, imin(i16));
            try testArgs(f128, i16, imin(i16) + 1);
            try testArgs(f128, i16, -1e4);
            try testArgs(f128, i16, -1e3);
            try testArgs(f128, i16, -1e2);
            try testArgs(f128, i16, -1e1);
            try testArgs(f128, i16, -1e0);
            try testArgs(f128, i16, 0);
            try testArgs(f128, i16, 1e0);
            try testArgs(f128, i16, 1e1);
            try testArgs(f128, i16, 1e2);
            try testArgs(f128, i16, 1e3);
            try testArgs(f128, i16, 1e4);
            try testArgs(f128, i16, imax(i16) - 1);
            try testArgs(f128, i16, imax(i16));

            try testArgs(f128, u16, 0);
            try testArgs(f128, u16, 1e0);
            try testArgs(f128, u16, 1e1);
            try testArgs(f128, u16, 1e2);
            try testArgs(f128, u16, 1e3);
            try testArgs(f128, u16, 1e4);
            try testArgs(f128, u16, imax(u16) - 1);
            try testArgs(f128, u16, imax(u16));

            try testArgs(f128, i32, imin(i32));
            try testArgs(f128, i32, imin(i32) + 1);
            try testArgs(f128, i32, -1e9);
            try testArgs(f128, i32, -1e8);
            try testArgs(f128, i32, -1e7);
            try testArgs(f128, i32, -1e6);
            try testArgs(f128, i32, -1e5);
            try testArgs(f128, i32, -1e4);
            try testArgs(f128, i32, -1e3);
            try testArgs(f128, i32, -1e2);
            try testArgs(f128, i32, -1e1);
            try testArgs(f128, i32, -1e0);
            try testArgs(f128, i32, 0);
            try testArgs(f128, i32, 1e0);
            try testArgs(f128, i32, 1e1);
            try testArgs(f128, i32, 1e2);
            try testArgs(f128, i32, 1e3);
            try testArgs(f128, i32, 1e4);
            try testArgs(f128, i32, 1e5);
            try testArgs(f128, i32, 1e6);
            try testArgs(f128, i32, 1e7);
            try testArgs(f128, i32, 1e8);
            try testArgs(f128, i32, 1e9);
            try testArgs(f128, i32, imax(i32) - 1);
            try testArgs(f128, i32, imax(i32));

            try testArgs(f128, u32, 0);
            try testArgs(f128, u32, 1e0);
            try testArgs(f128, u32, 1e1);
            try testArgs(f128, u32, 1e2);
            try testArgs(f128, u32, 1e3);
            try testArgs(f128, u32, 1e4);
            try testArgs(f128, u32, 1e5);
            try testArgs(f128, u32, 1e6);
            try testArgs(f128, u32, 1e7);
            try testArgs(f128, u32, 1e8);
            try testArgs(f128, u32, 1e9);
            try testArgs(f128, u32, imax(u32) - 1);
            try testArgs(f128, u32, imax(u32));

            try testArgs(f128, i64, imin(i64));
            try testArgs(f128, i64, imin(i64) + 1);
            try testArgs(f128, i64, -1e18);
            try testArgs(f128, i64, -1e16);
            try testArgs(f128, i64, -1e14);
            try testArgs(f128, i64, -1e12);
            try testArgs(f128, i64, -1e10);
            try testArgs(f128, i64, -1e8);
            try testArgs(f128, i64, -1e6);
            try testArgs(f128, i64, -1e4);
            try testArgs(f128, i64, -1e2);
            try testArgs(f128, i64, -1e0);
            try testArgs(f128, i64, 0);
            try testArgs(f128, i64, 1e0);
            try testArgs(f128, i64, 1e2);
            try testArgs(f128, i64, 1e4);
            try testArgs(f128, i64, 1e6);
            try testArgs(f128, i64, 1e8);
            try testArgs(f128, i64, 1e10);
            try testArgs(f128, i64, 1e12);
            try testArgs(f128, i64, 1e14);
            try testArgs(f128, i64, 1e16);
            try testArgs(f128, i64, 1e18);
            try testArgs(f128, i64, imax(i64) - 1);
            try testArgs(f128, i64, imax(i64));

            try testArgs(f128, u64, 0);
            try testArgs(f128, u64, 1e0);
            try testArgs(f128, u64, 1e2);
            try testArgs(f128, u64, 1e4);
            try testArgs(f128, u64, 1e6);
            try testArgs(f128, u64, 1e8);
            try testArgs(f128, u64, 1e10);
            try testArgs(f128, u64, 1e12);
            try testArgs(f128, u64, 1e14);
            try testArgs(f128, u64, 1e16);
            try testArgs(f128, u64, 1e18);
            try testArgs(f128, u64, imax(u64) - 1);
            try testArgs(f128, u64, imax(u64));

            try testArgs(f128, i128, imin(i128));
            try testArgs(f128, i128, imin(i128) + 1);
            try testArgs(f128, i128, -1e38);
            try testArgs(f128, i128, -1e34);
            try testArgs(f128, i128, -1e30);
            try testArgs(f128, i128, -1e26);
            try testArgs(f128, i128, -1e22);
            try testArgs(f128, i128, -1e18);
            try testArgs(f128, i128, -1e14);
            try testArgs(f128, i128, -1e10);
            try testArgs(f128, i128, -1e6);
            try testArgs(f128, i128, -1e2);
            try testArgs(f128, i128, -1e0);
            try testArgs(f128, i128, 0);
            try testArgs(f128, i128, 1e0);
            try testArgs(f128, i128, 1e2);
            try testArgs(f128, i128, 1e6);
            try testArgs(f128, i128, 1e10);
            try testArgs(f128, i128, 1e14);
            try testArgs(f128, i128, 1e18);
            try testArgs(f128, i128, 1e22);
            try testArgs(f128, i128, 1e26);
            try testArgs(f128, i128, 1e30);
            try testArgs(f128, i128, 1e34);
            try testArgs(f128, i128, 1e38);
            try testArgs(f128, i128, imax(i128) - 1);
            try testArgs(f128, i128, imax(i128));

            try testArgs(f128, u128, 0);
            try testArgs(f128, u128, 1e0);
            try testArgs(f128, u128, 1e2);
            try testArgs(f128, u128, 1e6);
            try testArgs(f128, u128, 1e10);
            try testArgs(f128, u128, 1e14);
            try testArgs(f128, u128, 1e18);
            try testArgs(f128, u128, 1e22);
            try testArgs(f128, u128, 1e26);
            try testArgs(f128, u128, 1e30);
            try testArgs(f128, u128, 1e34);
            try testArgs(f128, u128, 1e38);
            try testArgs(f128, u128, imax(u128) - 1);
            try testArgs(f128, u128, imax(u128));

            try testArgs(f128, i256, imin(i256));
            try testArgs(f128, i256, imin(i256) + 1);
            try testArgs(f128, i256, -1e76);
            try testArgs(f128, i256, -1e69);
            try testArgs(f128, i256, -1e62);
            try testArgs(f128, i256, -1e55);
            try testArgs(f128, i256, -1e48);
            try testArgs(f128, i256, -1e41);
            try testArgs(f128, i256, -1e34);
            try testArgs(f128, i256, -1e27);
            try testArgs(f128, i256, -1e20);
            try testArgs(f128, i256, -1e13);
            try testArgs(f128, i256, -1e6);
            try testArgs(f128, i256, -1e0);
            try testArgs(f128, i256, 0);
            try testArgs(f128, i256, 1e0);
            try testArgs(f128, i256, 1e6);
            try testArgs(f128, i256, 1e13);
            try testArgs(f128, i256, 1e20);
            try testArgs(f128, i256, 1e27);
            try testArgs(f128, i256, 1e34);
            try testArgs(f128, i256, 1e41);
            try testArgs(f128, i256, 1e48);
            try testArgs(f128, i256, 1e55);
            try testArgs(f128, i256, 1e62);
            try testArgs(f128, i256, 1e69);
            try testArgs(f128, i256, 1e76);
            try testArgs(f128, i256, imax(i256) - 1);
            try testArgs(f128, i256, imax(i256));

            try testArgs(f128, u256, 0);
            try testArgs(f128, u256, 1e0);
            try testArgs(f128, u256, 1e7);
            try testArgs(f128, u256, 1e14);
            try testArgs(f128, u256, 1e21);
            try testArgs(f128, u256, 1e28);
            try testArgs(f128, u256, 1e35);
            try testArgs(f128, u256, 1e42);
            try testArgs(f128, u256, 1e49);
            try testArgs(f128, u256, 1e56);
            try testArgs(f128, u256, 1e63);
            try testArgs(f128, u256, 1e70);
            try testArgs(f128, u256, 1e77);
            try testArgs(f128, u256, imax(u256) - 1);
            try testArgs(f128, u256, imax(u256));
        }
        fn testIntVectorsFromFloatVectors() !void {
            @setEvalBranchQuota(2_500);

            try testArgs(@Vector(1, i8), @Vector(1, f16), .{
                -0x0.8p8,
            });
            try testArgs(@Vector(2, i8), @Vector(2, f16), .{
                next(f16, -0x0.8p8, -0.0), next(f16, next(f16, -0x0.8p8, -0.0), -0.0),
            });
            try testArgs(@Vector(4, i8), @Vector(4, f16), .{
                -1e2, -1e1, -1e0, -1e-1,
            });
            try testArgs(@Vector(8, i8), @Vector(8, f16), .{
                -1e-2, -1e-3, -1e-4, -1e-5, -0.0, 0.0, 1e-5, 1e-4,
            });
            try testArgs(@Vector(16, i8), @Vector(16, f16), .{
                1e-3, 1e-2, 1e-1,  1e0,   1e1,   1e2,   next(f16, next(f16, 0x0.8p8, 0.0), 0.0), next(f16, 0x0.8p8, 0.0),
                -2e1, -2e0, -2e-1, -2e-2, -2e-3, -2e-4, -2e-5,                                   2e-5,
            });
            try testArgs(@Vector(32, i8), @Vector(32, f16), .{
                2e-4,  2e-3,  2e-2,  2e-1,  2e0,   2e1,  -3e1,  -3e0,
                -3e-1, -3e-2, -3e-3, -3e-4, -3e-5, 3e-5, 3e-4,  3e-3,
                3e-2,  3e-1,  3e0,   3e1,   -4e1,  -4e0, -4e-1, -4e-2,
                -4e-3, -4e-4, -4e-5, 4e-5,  4e-4,  4e-3, 4e-2,  4e-1,
            });
            try testArgs(@Vector(64, i8), @Vector(64, f16), .{
                4e0,   4e1,   -5e1,  -5e0,  -5e-1, -5e-2, -5e-3, -5e-4,
                -5e-5, 5e-5,  5e-4,  5e-3,  5e-2,  5e-1,  5e0,   5e1,
                -6e1,  -6e0,  -6e-1, -6e-2, -6e-3, -6e-4, -6e-5, 6e-5,
                6e-4,  6e-3,  6e-2,  6e-1,  6e0,   6e1,   -7e1,  -7e0,
                -7e-1, -7e-2, -7e-3, -7e-4, -7e-5, 7e-5,  7e-4,  7e-3,
                7e-2,  7e-1,  7e0,   7e1,   -8e1,  -8e0,  -8e-1, -8e-2,
                -8e-3, -8e-4, -8e-5, 8e-5,  8e-4,  8e-3,  8e-2,  8e-1,
                8e0,   8e1,   -9e1,  -9e0,  -9e-1, -9e-2, -9e-3, -9e-4,
            });
            try testArgs(@Vector(128, i8), @Vector(128, f16), .{
                -9e-5,  9e-5,   9e-4,   9e-3,   9e-2,   9e-1,   9e0,    9e1,
                -11e1,  -11e0,  -11e-1, -11e-2, -11e-3, -11e-4, -11e-5, 11e-5,
                11e-4,  11e-3,  11e-2,  11e-1,  11e0,   11e1,   -12e1,  -12e0,
                -12e-1, -12e-2, -12e-3, -12e-4, -12e-5, 12e-5,  12e-4,  12e-3,
                12e-2,  12e-1,  12e0,   12e1,   -13e0,  -13e-1, -13e-2, -13e-3,
                -13e-4, -13e-5, 13e-5,  13e-4,  13e-3,  13e-2,  13e-1,  13e0,
                -14e0,  -14e-1, -14e-2, -14e-3, -14e-4, -14e-5, 14e-5,  14e-4,
                14e-3,  14e-2,  14e-1,  14e0,   -15e0,  -15e-1, -15e-2, -15e-3,
                -15e-4, -15e-5, 15e-5,  15e-4,  15e-3,  15e-2,  15e-1,  15e0,
                -16e0,  -16e-1, -16e-2, -16e-3, -16e-4, -16e-5, 16e-5,  16e-4,
                16e-3,  16e-2,  16e-1,  16e0,   -17e0,  -17e-1, -17e-2, -17e-3,
                -17e-4, -17e-5, 17e-5,  17e-4,  17e-3,  17e-2,  17e-1,  17e0,
                -18e0,  -18e-1, -18e-2, -18e-3, -18e-4, -18e-5, 18e-5,  18e-4,
                18e-3,  18e-2,  18e-1,  18e0,   -19e0,  -19e-1, -19e-2, -19e-3,
                -19e-4, -19e-5, 19e-5,  19e-4,  19e-3,  19e-2,  19e-1,  19e0,
                -21e0,  -21e-1, -21e-2, -21e-3, -21e-4, -21e-5, 21e-5,  21e-4,
            });

            try testArgs(@Vector(1, u8), @Vector(1, f16), .{
                -0.0,
            });
            try testArgs(@Vector(2, u8), @Vector(2, f16), .{
                0.0, 1e-5,
            });
            try testArgs(@Vector(4, u8), @Vector(4, f16), .{
                1e-4, 1e-3, 1e-2, 1e-1,
            });
            try testArgs(@Vector(8, u8), @Vector(8, f16), .{
                1e0, 1e1, 1e2, next(f16, next(f16, 0x1p8, 0.0), 0.0), next(f16, 0x1p8, 0.0), 2e-5, 2e-4, 2e-3,
            });
            try testArgs(@Vector(16, u8), @Vector(16, f16), .{
                2e-2, 2e-1, 2e0, 2e1, 2e2,  3e-5, 3e-4, 3e-3,
                3e-2, 3e-1, 3e0, 3e1, 4e-5, 4e-4, 4e-3, 4e-2,
            });
            try testArgs(@Vector(32, u8), @Vector(32, f16), .{
                4e-1, 4e0,  4e1,  5e-5, 5e-4, 5e-3, 5e-2, 5e-1,
                5e0,  5e1,  6e-5, 6e-4, 6e-3, 6e-2, 6e-1, 6e0,
                6e1,  7e-5, 7e-4, 7e-3, 7e-2, 7e-1, 7e0,  7e1,
                8e-5, 8e-4, 8e-3, 8e-2, 8e-1, 8e0,  8e1,  9e-5,
            });
            try testArgs(@Vector(64, u8), @Vector(64, f16), .{
                9e-4,  9e-3,  9e-2,  9e-1,  9e0,   9e1,   11e-5, 11e-4,
                11e-3, 11e-2, 11e-1, 11e0,  11e1,  13e-5, 13e-4, 13e-3,
                13e-2, 13e-1, 13e0,  14e-5, 14e-4, 14e-3, 14e-2, 14e-1,
                14e0,  14e1,  15e-5, 15e-4, 15e-3, 15e-2, 15e-1, 15e0,
                15e1,  16e-5, 16e-4, 16e-3, 16e-2, 16e-1, 16e0,  16e1,
                17e-5, 17e-4, 17e-3, 17e-2, 17e-1, 17e0,  17e1,  18e-5,
                18e-4, 18e-3, 18e-2, 18e-1, 18e0,  18e1,  19e-5, 19e-4,
                19e-3, 19e-2, 19e-1, 19e0,  19e1,  21e-5, 21e-4, 21e-3,
            });
            try testArgs(@Vector(128, u8), @Vector(128, f16), .{
                21e-2, 21e-1, 21e0,  21e1,  22e-5, 22e-4, 22e-3, 22e-2,
                22e-1, 22e0,  22e1,  23e-5, 23e-4, 23e-3, 23e-2, 23e-1,
                23e0,  23e1,  24e-5, 24e-4, 24e-3, 24e-2, 24e-1, 24e0,
                24e1,  25e-5, 25e-4, 25e-3, 25e-2, 25e-1, 25e0,  25e1,
                26e-5, 26e-4, 26e-3, 26e-2, 26e-1, 26e0,  27e-5, 27e-4,
                27e-3, 27e-2, 27e-1, 27e0,  28e-5, 28e-4, 28e-3, 28e-2,
                28e-1, 28e0,  29e-5, 29e-4, 29e-3, 29e-2, 29e-1, 29e0,
                31e-5, 31e-4, 31e-3, 31e-2, 31e-1, 31e0,  32e-5, 32e-4,
                32e-3, 32e-2, 32e-1, 32e0,  33e-5, 33e-4, 33e-3, 33e-2,
                33e-1, 33e0,  34e-5, 34e-4, 34e-3, 34e-2, 34e-1, 34e0,
                35e-5, 35e-4, 35e-3, 35e-2, 35e-1, 35e0,  36e-5, 36e-4,
                36e-3, 36e-2, 36e-1, 36e0,  37e-5, 37e-4, 37e-3, 37e-2,
                37e-1, 37e0,  38e-5, 38e-4, 38e-3, 38e-2, 38e-1, 38e0,
                39e-5, 39e-4, 39e-3, 39e-2, 39e-1, 39e0,  41e-5, 41e-4,
                41e-3, 41e-2, 41e-1, 41e0,  42e-5, 42e-4, 42e-3, 42e-2,
                42e-1, 42e0,  43e-5, 43e-4, 43e-3, 43e-2, 43e-1, 43e0,
            });

            try testArgs(@Vector(1, i16), @Vector(1, f16), .{
                -0x0.8p16,
            });
            try testArgs(@Vector(2, i16), @Vector(2, f16), .{
                next(f16, -0x0.8p16, -0.0), next(f16, next(f16, -0x0.8p16, -0.0), -0.0),
            });
            try testArgs(@Vector(4, i16), @Vector(4, f16), .{
                -1e4, -1e3, -1e2, -1e1,
            });
            try testArgs(@Vector(8, i16), @Vector(8, f16), .{
                -1e0, -1e-1, -1e-2, -1e-3, -1e-4, -1e-5, -0.0, 0.0,
            });
            try testArgs(@Vector(16, i16), @Vector(16, f16), .{
                1e-5, 1e-4, 1e-3,                                     1e-2,                     1e-1, 1e0,  1e1,  1e2,
                1e3,  1e4,  next(f16, next(f16, 0x0.8p16, 0.0), 0.0), next(f16, 0x0.8p16, 0.0), -2e4, -2e3, -2e2, -2e1,
            });
            try testArgs(@Vector(32, i16), @Vector(32, f16), .{
                -2e0,  -2e-1, -2e-2, -2e-3, -2e-4, -2e-5, 2e-5,  2e-4,
                2e-3,  2e-2,  2e-1,  2e0,   2e1,   2e2,   2e3,   2e4,
                -3e4,  -3e3,  -3e2,  -3e1,  -3e0,  -3e-1, -3e-2, -3e-3,
                -3e-4, -3e-5, 3e-5,  3e-4,  3e-3,  3e-2,  3e-1,  3e0,
            });
            try testArgs(@Vector(64, i16), @Vector(64, f16), .{
                3e1,   3e2,   3e3,   3e4,   -4e3,  -4e2,  -4e1,  -4e0,
                -4e-1, -4e-2, -4e-3, -4e-4, -4e-5, 4e-5,  4e-4,  4e-3,
                4e-2,  4e-1,  4e0,   4e1,   4e2,   4e3,   -5e3,  -5e2,
                -5e1,  -5e0,  -5e-1, -5e-2, -5e-3, -5e-4, -5e-5, 5e-5,
                5e-4,  5e-3,  5e-2,  5e-1,  5e0,   5e1,   5e2,   5e3,
                -6e3,  -6e2,  -6e1,  -6e0,  -6e-1, -6e-2, -6e-3, -6e-4,
                -6e-5, 6e-5,  6e-4,  6e-3,  6e-2,  6e-1,  6e0,   6e1,
                6e2,   6e3,   -7e3,  -7e2,  -7e1,  -7e0,  -7e-1, -7e-2,
            });
            try testArgs(@Vector(128, i16), @Vector(128, f16), .{
                -7e-3,  -7e-4,  -7e-5,  7e-5,   7e-4,   7e-3,   7e-2,   7e-1,
                7e0,    7e1,    7e2,    7e3,    -8e3,   -8e2,   -8e1,   -8e0,
                -8e-1,  -8e-2,  -8e-3,  -8e-4,  -8e-5,  8e-5,   8e-4,   8e-3,
                8e-2,   8e-1,   8e0,    8e1,    8e2,    8e3,    -9e3,   -9e2,
                -9e1,   -9e0,   -9e-1,  -9e-2,  -9e-3,  -9e-4,  -9e-5,  9e-5,
                9e-4,   9e-3,   9e-2,   9e-1,   9e0,    9e1,    9e2,    9e3,
                -11e3,  -11e2,  -11e1,  -11e0,  -11e-1, -11e-2, -11e-3, -11e-4,
                -11e-5, 11e-5,  11e-4,  11e-3,  11e-2,  11e-1,  11e0,   11e1,
                11e2,   11e3,   -12e3,  -12e2,  -12e1,  -12e0,  -12e-1, -12e-2,
                -12e-3, -12e-4, -12e-5, 12e-5,  12e-4,  12e-3,  12e-2,  12e-1,
                12e0,   12e1,   12e2,   12e3,   -13e3,  -13e2,  -13e1,  -13e0,
                -13e-1, -13e-2, -13e-3, -13e-4, -13e-5, 13e-5,  13e-4,  13e-3,
                13e-2,  13e-1,  13e0,   13e1,   13e2,   -14e2,  -14e1,  -14e0,
                -14e-1, -14e-2, -14e-3, -14e-4, -14e-5, 14e-5,  14e-4,  14e-3,
                14e-2,  14e-1,  14e0,   14e1,   14e2,   14e3,   -15e3,  -15e2,
                -15e1,  -15e0,  -15e-1, -15e-2, -15e-3, -15e-4, -15e-5, 15e-5,
            });

            try testArgs(@Vector(1, u16), @Vector(1, f16), .{
                -0.0,
            });
            try testArgs(@Vector(2, u16), @Vector(2, f16), .{
                0.0, 1e-5,
            });
            try testArgs(@Vector(4, u16), @Vector(4, f16), .{
                1e-4, 1e-3, 1e-2, 1e-1,
            });
            try testArgs(@Vector(8, u16), @Vector(8, f16), .{
                1e0, 1e1, 1e2, 1e3, 1e4, next(f16, next(f16, 0x1p16, 0.0), 0.0), next(f16, 0x1p16, 0.0), 2e-5,
            });
            try testArgs(@Vector(16, u16), @Vector(16, f16), .{
                2e-4, 2e-3, 2e-2, 2e-1, 2e0,  2e1,  2e2, 2e3,
                2e4,  3e-5, 3e-4, 3e-3, 3e-2, 3e-1, 3e0, 3e1,
            });
            try testArgs(@Vector(32, u16), @Vector(32, f16), .{
                3e2,  3e3,  3e4, 4e-5, 4e-4, 4e-3, 4e-2, 4e-1,
                4e0,  4e1,  4e2, 4e3,  5e-5, 5e-4, 5e-3, 5e-2,
                5e-1, 5e0,  5e1, 5e2,  5e3,  6e-5, 6e-4, 6e-3,
                6e-2, 6e-1, 6e0, 6e1,  6e2,  6e3,  7e-5, 7e-4,
            });
            try testArgs(@Vector(64, u16), @Vector(64, f16), .{
                7e-3,  7e-2,  7e-1,  7e0,   7e1,   7e2,   7e3,   8e-5,
                8e-4,  8e-3,  8e-2,  8e-1,  8e0,   8e1,   8e2,   8e3,
                9e-5,  9e-4,  9e-3,  9e-2,  9e-1,  9e0,   9e1,   9e2,
                9e3,   11e-5, 11e-4, 11e-3, 11e-2, 11e-1, 11e0,  11e1,
                11e2,  11e3,  13e-5, 13e-4, 13e-3, 13e-2, 13e-1, 13e0,
                13e1,  13e2,  13e3,  14e-5, 14e-4, 14e-3, 14e-2, 14e-1,
                14e0,  14e1,  14e2,  14e3,  15e-5, 15e-4, 15e-3, 15e-2,
                15e-1, 15e0,  15e1,  15e2,  15e3,  16e-5, 16e-4, 16e-3,
            });
            try testArgs(@Vector(128, u16), @Vector(128, f16), .{
                16e-2, 16e-1, 16e0,  16e1,  16e2,  16e3,  17e-5, 17e-4,
                17e-3, 17e-2, 17e-1, 17e0,  17e1,  17e2,  17e3,  18e-5,
                18e-4, 18e-3, 18e-2, 18e-1, 18e0,  18e1,  18e2,  18e3,
                19e-5, 19e-4, 19e-3, 19e-2, 19e-1, 19e0,  19e1,  19e2,
                19e3,  21e-5, 21e-4, 21e-3, 21e-2, 21e-1, 21e0,  21e1,
                21e2,  21e3,  22e-5, 22e-4, 22e-3, 22e-2, 22e-1, 22e0,
                22e1,  22e2,  22e3,  23e-5, 23e-4, 23e-3, 23e-2, 23e-1,
                23e0,  23e1,  23e2,  23e3,  24e-5, 24e-4, 24e-3, 24e-2,
                24e-1, 24e0,  24e1,  24e2,  24e3,  25e-5, 25e-4, 25e-3,
                25e-2, 25e-1, 25e0,  25e1,  25e2,  25e3,  26e-5, 26e-4,
                26e-3, 26e-2, 26e-1, 26e0,  26e1,  26e2,  26e3,  27e-5,
                27e-4, 27e-3, 27e-2, 27e-1, 27e0,  27e1,  27e2,  27e3,
                28e-5, 28e-4, 28e-3, 28e-2, 28e-1, 28e0,  28e1,  28e2,
                28e3,  29e-5, 29e-4, 29e-3, 29e-2, 29e-1, 29e0,  29e1,
                29e2,  29e3,  31e-5, 31e-4, 31e-3, 31e-2, 31e-1, 31e0,
                31e1,  31e2,  31e3,  32e-5, 32e-4, 32e-3, 32e-2, 32e-1,
            });

            try testArgs(@Vector(1, i32), @Vector(1, f16), .{
                -fmax(f16),
            });
            try testArgs(@Vector(2, i32), @Vector(2, f16), .{
                next(f16, -fmax(f16), -0.0), next(f16, next(f16, -fmax(f16), -0.0), -0.0),
            });
            try testArgs(@Vector(4, i32), @Vector(4, f16), .{
                -1e4, -1e3, -1e2, -1e1,
            });
            try testArgs(@Vector(8, i32), @Vector(8, f16), .{
                -1e0, -1e-1, -1e-2, -1e-3, -1e-4, -1e-5, -0.0, 0.0,
            });
            try testArgs(@Vector(16, i32), @Vector(16, f16), .{
                1e-5, 1e-4, 1e-3,                                      1e-2,                      1e-1, 1e0,  1e1,  1e2,
                1e3,  1e4,  next(f16, next(f16, fmax(f16), 0.0), 0.0), next(f16, fmax(f16), 0.0), -2e4, -2e3, -2e2, -2e1,
            });
            try testArgs(@Vector(32, i32), @Vector(32, f16), .{
                -2e0,  -2e-1, -2e-2, -2e-3, -2e-4, -2e-5, 2e-5,  2e-4,
                2e-3,  2e-2,  2e-1,  2e0,   2e1,   2e2,   2e3,   2e4,
                -3e4,  -3e3,  -3e2,  -3e1,  -3e0,  -3e-1, -3e-2, -3e-3,
                -3e-4, -3e-5, 3e-5,  3e-4,  3e-3,  3e-2,  3e-1,  3e0,
            });
            try testArgs(@Vector(64, i32), @Vector(64, f16), .{
                3e1,   3e2,   3e3,   3e4,   -4e3,  -4e2,  -4e1,  -4e0,
                -4e-1, -4e-2, -4e-3, -4e-4, -4e-5, 4e-5,  4e-4,  4e-3,
                4e-2,  4e-1,  4e0,   4e1,   4e2,   4e3,   -5e3,  -5e2,
                -5e1,  -5e0,  -5e-1, -5e-2, -5e-3, -5e-4, -5e-5, 5e-5,
                5e-4,  5e-3,  5e-2,  5e-1,  5e0,   5e1,   5e2,   5e3,
                -6e3,  -6e2,  -6e1,  -6e0,  -6e-1, -6e-2, -6e-3, -6e-4,
                -6e-5, 6e-5,  6e-4,  6e-3,  6e-2,  6e-1,  6e0,   6e1,
                6e2,   6e3,   -7e3,  -7e2,  -7e1,  -7e0,  -7e-1, -7e-2,
            });
            try testArgs(@Vector(128, i32), @Vector(128, f16), .{
                -7e-3,  -7e-4,  -7e-5,  7e-5,   7e-4,   7e-3,   7e-2,   7e-1,
                7e0,    7e1,    7e2,    7e3,    -8e3,   -8e2,   -8e1,   -8e0,
                -8e-1,  -8e-2,  -8e-3,  -8e-4,  -8e-5,  8e-5,   8e-4,   8e-3,
                8e-2,   8e-1,   8e0,    8e1,    8e2,    8e3,    -9e3,   -9e2,
                -9e1,   -9e0,   -9e-1,  -9e-2,  -9e-3,  -9e-4,  -9e-5,  9e-5,
                9e-4,   9e-3,   9e-2,   9e-1,   9e0,    9e1,    9e2,    9e3,
                -11e3,  -11e2,  -11e1,  -11e0,  -11e-1, -11e-2, -11e-3, -11e-4,
                -11e-5, 11e-5,  11e-4,  11e-3,  11e-2,  11e-1,  11e0,   11e1,
                11e2,   11e3,   -12e3,  -12e2,  -12e1,  -12e0,  -12e-1, -12e-2,
                -12e-3, -12e-4, -12e-5, 12e-5,  12e-4,  12e-3,  12e-2,  12e-1,
                12e0,   12e1,   12e2,   12e3,   -13e3,  -13e2,  -13e1,  -13e0,
                -13e-1, -13e-2, -13e-3, -13e-4, -13e-5, 13e-5,  13e-4,  13e-3,
                13e-2,  13e-1,  13e0,   13e1,   13e2,   -14e2,  -14e1,  -14e0,
                -14e-1, -14e-2, -14e-3, -14e-4, -14e-5, 14e-5,  14e-4,  14e-3,
                14e-2,  14e-1,  14e0,   14e1,   14e2,   14e3,   -15e3,  -15e2,
                -15e1,  -15e0,  -15e-1, -15e-2, -15e-3, -15e-4, -15e-5, 15e-5,
            });

            try testArgs(@Vector(1, u32), @Vector(1, f16), .{
                -0.0,
            });
            try testArgs(@Vector(2, u32), @Vector(2, f16), .{
                0.0, 1e-5,
            });
            try testArgs(@Vector(4, u32), @Vector(4, f16), .{
                1e-4, 1e-3, 1e-2, 1e-1,
            });
            try testArgs(@Vector(8, u32), @Vector(8, f16), .{
                1e0, 1e1, 1e2, 1e3, 1e4, next(f16, next(f16, fmax(f16), 0.0), 0.0), next(f16, fmax(f16), 0.0), 2e-5,
            });
            try testArgs(@Vector(16, u32), @Vector(16, f16), .{
                2e-4, 2e-3, 2e-2, 2e-1, 2e0,  2e1,  2e2, 2e3,
                2e4,  3e-5, 3e-4, 3e-3, 3e-2, 3e-1, 3e0, 3e1,
            });
            try testArgs(@Vector(32, u32), @Vector(32, f16), .{
                3e2,  3e3,  3e4, 4e-5, 4e-4, 4e-3, 4e-2, 4e-1,
                4e0,  4e1,  4e2, 4e3,  5e-5, 5e-4, 5e-3, 5e-2,
                5e-1, 5e0,  5e1, 5e2,  5e3,  6e-5, 6e-4, 6e-3,
                6e-2, 6e-1, 6e0, 6e1,  6e2,  6e3,  7e-5, 7e-4,
            });
            try testArgs(@Vector(64, u32), @Vector(64, f16), .{
                7e-3,  7e-2,  7e-1,  7e0,   7e1,   7e2,   7e3,   8e-5,
                8e-4,  8e-3,  8e-2,  8e-1,  8e0,   8e1,   8e2,   8e3,
                9e-5,  9e-4,  9e-3,  9e-2,  9e-1,  9e0,   9e1,   9e2,
                9e3,   11e-5, 11e-4, 11e-3, 11e-2, 11e-1, 11e0,  11e1,
                11e2,  11e3,  13e-5, 13e-4, 13e-3, 13e-2, 13e-1, 13e0,
                13e1,  13e2,  13e3,  14e-5, 14e-4, 14e-3, 14e-2, 14e-1,
                14e0,  14e1,  14e2,  14e3,  15e-5, 15e-4, 15e-3, 15e-2,
                15e-1, 15e0,  15e1,  15e2,  15e3,  16e-5, 16e-4, 16e-3,
            });
            try testArgs(@Vector(128, u32), @Vector(128, f16), .{
                16e-2, 16e-1, 16e0,  16e1,  16e2,  16e3,  17e-5, 17e-4,
                17e-3, 17e-2, 17e-1, 17e0,  17e1,  17e2,  17e3,  18e-5,
                18e-4, 18e-3, 18e-2, 18e-1, 18e0,  18e1,  18e2,  18e3,
                19e-5, 19e-4, 19e-3, 19e-2, 19e-1, 19e0,  19e1,  19e2,
                19e3,  21e-5, 21e-4, 21e-3, 21e-2, 21e-1, 21e0,  21e1,
                21e2,  21e3,  22e-5, 22e-4, 22e-3, 22e-2, 22e-1, 22e0,
                22e1,  22e2,  22e3,  23e-5, 23e-4, 23e-3, 23e-2, 23e-1,
                23e0,  23e1,  23e2,  23e3,  24e-5, 24e-4, 24e-3, 24e-2,
                24e-1, 24e0,  24e1,  24e2,  24e3,  25e-5, 25e-4, 25e-3,
                25e-2, 25e-1, 25e0,  25e1,  25e2,  25e3,  26e-5, 26e-4,
                26e-3, 26e-2, 26e-1, 26e0,  26e1,  26e2,  26e3,  27e-5,
                27e-4, 27e-3, 27e-2, 27e-1, 27e0,  27e1,  27e2,  27e3,
                28e-5, 28e-4, 28e-3, 28e-2, 28e-1, 28e0,  28e1,  28e2,
                28e3,  29e-5, 29e-4, 29e-3, 29e-2, 29e-1, 29e0,  29e1,
                29e2,  29e3,  31e-5, 31e-4, 31e-3, 31e-2, 31e-1, 31e0,
                31e1,  31e2,  31e3,  32e-5, 32e-4, 32e-3, 32e-2, 32e-1,
            });

            try testArgs(@Vector(1, i64), @Vector(1, f16), .{
                -fmax(f16),
            });
            try testArgs(@Vector(2, i64), @Vector(2, f16), .{
                next(f16, -fmax(f16), -0.0), next(f16, next(f16, -fmax(f16), -0.0), -0.0),
            });
            try testArgs(@Vector(4, i64), @Vector(4, f16), .{
                -1e4, -1e3, -1e2, -1e1,
            });
            try testArgs(@Vector(8, i64), @Vector(8, f16), .{
                -1e0, -1e-1, -1e-2, -1e-3, -1e-4, -1e-5, -0.0, 0.0,
            });
            try testArgs(@Vector(16, i64), @Vector(16, f16), .{
                1e-5, 1e-4, 1e-3,                                      1e-2,                      1e-1, 1e0,  1e1,  1e2,
                1e3,  1e4,  next(f16, next(f16, fmax(f16), 0.0), 0.0), next(f16, fmax(f16), 0.0), -2e4, -2e3, -2e2, -2e1,
            });
            try testArgs(@Vector(32, i64), @Vector(32, f16), .{
                -2e0,  -2e-1, -2e-2, -2e-3, -2e-4, -2e-5, 2e-5,  2e-4,
                2e-3,  2e-2,  2e-1,  2e0,   2e1,   2e2,   2e3,   2e4,
                -3e4,  -3e3,  -3e2,  -3e1,  -3e0,  -3e-1, -3e-2, -3e-3,
                -3e-4, -3e-5, 3e-5,  3e-4,  3e-3,  3e-2,  3e-1,  3e0,
            });
            try testArgs(@Vector(64, i64), @Vector(64, f16), .{
                3e1,   3e2,   3e3,   3e4,   -4e3,  -4e2,  -4e1,  -4e0,
                -4e-1, -4e-2, -4e-3, -4e-4, -4e-5, 4e-5,  4e-4,  4e-3,
                4e-2,  4e-1,  4e0,   4e1,   4e2,   4e3,   -5e3,  -5e2,
                -5e1,  -5e0,  -5e-1, -5e-2, -5e-3, -5e-4, -5e-5, 5e-5,
                5e-4,  5e-3,  5e-2,  5e-1,  5e0,   5e1,   5e2,   5e3,
                -6e3,  -6e2,  -6e1,  -6e0,  -6e-1, -6e-2, -6e-3, -6e-4,
                -6e-5, 6e-5,  6e-4,  6e-3,  6e-2,  6e-1,  6e0,   6e1,
                6e2,   6e3,   -7e3,  -7e2,  -7e1,  -7e0,  -7e-1, -7e-2,
            });
            try testArgs(@Vector(128, i64), @Vector(128, f16), .{
                -7e-3,  -7e-4,  -7e-5,  7e-5,   7e-4,   7e-3,   7e-2,   7e-1,
                7e0,    7e1,    7e2,    7e3,    -8e3,   -8e2,   -8e1,   -8e0,
                -8e-1,  -8e-2,  -8e-3,  -8e-4,  -8e-5,  8e-5,   8e-4,   8e-3,
                8e-2,   8e-1,   8e0,    8e1,    8e2,    8e3,    -9e3,   -9e2,
                -9e1,   -9e0,   -9e-1,  -9e-2,  -9e-3,  -9e-4,  -9e-5,  9e-5,
                9e-4,   9e-3,   9e-2,   9e-1,   9e0,    9e1,    9e2,    9e3,
                -11e3,  -11e2,  -11e1,  -11e0,  -11e-1, -11e-2, -11e-3, -11e-4,
                -11e-5, 11e-5,  11e-4,  11e-3,  11e-2,  11e-1,  11e0,   11e1,
                11e2,   11e3,   -12e3,  -12e2,  -12e1,  -12e0,  -12e-1, -12e-2,
                -12e-3, -12e-4, -12e-5, 12e-5,  12e-4,  12e-3,  12e-2,  12e-1,
                12e0,   12e1,   12e2,   12e3,   -13e3,  -13e2,  -13e1,  -13e0,
                -13e-1, -13e-2, -13e-3, -13e-4, -13e-5, 13e-5,  13e-4,  13e-3,
                13e-2,  13e-1,  13e0,   13e1,   13e2,   -14e2,  -14e1,  -14e0,
                -14e-1, -14e-2, -14e-3, -14e-4, -14e-5, 14e-5,  14e-4,  14e-3,
                14e-2,  14e-1,  14e0,   14e1,   14e2,   14e3,   -15e3,  -15e2,
                -15e1,  -15e0,  -15e-1, -15e-2, -15e-3, -15e-4, -15e-5, 15e-5,
            });

            try testArgs(@Vector(1, u64), @Vector(1, f16), .{
                -0.0,
            });
            try testArgs(@Vector(2, u64), @Vector(2, f16), .{
                0.0, 1e-5,
            });
            try testArgs(@Vector(4, u64), @Vector(4, f16), .{
                1e-4, 1e-3, 1e-2, 1e-1,
            });
            try testArgs(@Vector(8, u64), @Vector(8, f16), .{
                1e0, 1e1, 1e2, 1e3, 1e4, next(f16, next(f16, fmax(f16), 0.0), 0.0), next(f16, fmax(f16), 0.0), 2e-5,
            });
            try testArgs(@Vector(16, u64), @Vector(16, f16), .{
                2e-4, 2e-3, 2e-2, 2e-1, 2e0,  2e1,  2e2, 2e3,
                2e4,  3e-5, 3e-4, 3e-3, 3e-2, 3e-1, 3e0, 3e1,
            });
            try testArgs(@Vector(32, u64), @Vector(32, f16), .{
                3e2,  3e3,  3e4, 4e-5, 4e-4, 4e-3, 4e-2, 4e-1,
                4e0,  4e1,  4e2, 4e3,  5e-5, 5e-4, 5e-3, 5e-2,
                5e-1, 5e0,  5e1, 5e2,  5e3,  6e-5, 6e-4, 6e-3,
                6e-2, 6e-1, 6e0, 6e1,  6e2,  6e3,  7e-5, 7e-4,
            });
            try testArgs(@Vector(64, u64), @Vector(64, f16), .{
                7e-3,  7e-2,  7e-1,  7e0,   7e1,   7e2,   7e3,   8e-5,
                8e-4,  8e-3,  8e-2,  8e-1,  8e0,   8e1,   8e2,   8e3,
                9e-5,  9e-4,  9e-3,  9e-2,  9e-1,  9e0,   9e1,   9e2,
                9e3,   11e-5, 11e-4, 11e-3, 11e-2, 11e-1, 11e0,  11e1,
                11e2,  11e3,  13e-5, 13e-4, 13e-3, 13e-2, 13e-1, 13e0,
                13e1,  13e2,  13e3,  14e-5, 14e-4, 14e-3, 14e-2, 14e-1,
                14e0,  14e1,  14e2,  14e3,  15e-5, 15e-4, 15e-3, 15e-2,
                15e-1, 15e0,  15e1,  15e2,  15e3,  16e-5, 16e-4, 16e-3,
            });
            try testArgs(@Vector(128, u64), @Vector(128, f16), .{
                16e-2, 16e-1, 16e0,  16e1,  16e2,  16e3,  17e-5, 17e-4,
                17e-3, 17e-2, 17e-1, 17e0,  17e1,  17e2,  17e3,  18e-5,
                18e-4, 18e-3, 18e-2, 18e-1, 18e0,  18e1,  18e2,  18e3,
                19e-5, 19e-4, 19e-3, 19e-2, 19e-1, 19e0,  19e1,  19e2,
                19e3,  21e-5, 21e-4, 21e-3, 21e-2, 21e-1, 21e0,  21e1,
                21e2,  21e3,  22e-5, 22e-4, 22e-3, 22e-2, 22e-1, 22e0,
                22e1,  22e2,  22e3,  23e-5, 23e-4, 23e-3, 23e-2, 23e-1,
                23e0,  23e1,  23e2,  23e3,  24e-5, 24e-4, 24e-3, 24e-2,
                24e-1, 24e0,  24e1,  24e2,  24e3,  25e-5, 25e-4, 25e-3,
                25e-2, 25e-1, 25e0,  25e1,  25e2,  25e3,  26e-5, 26e-4,
                26e-3, 26e-2, 26e-1, 26e0,  26e1,  26e2,  26e3,  27e-5,
                27e-4, 27e-3, 27e-2, 27e-1, 27e0,  27e1,  27e2,  27e3,
                28e-5, 28e-4, 28e-3, 28e-2, 28e-1, 28e0,  28e1,  28e2,
                28e3,  29e-5, 29e-4, 29e-3, 29e-2, 29e-1, 29e0,  29e1,
                29e2,  29e3,  31e-5, 31e-4, 31e-3, 31e-2, 31e-1, 31e0,
                31e1,  31e2,  31e3,  32e-5, 32e-4, 32e-3, 32e-2, 32e-1,
            });

            try testArgs(@Vector(1, i128), @Vector(1, f16), .{
                -fmax(f16),
            });
            try testArgs(@Vector(2, i128), @Vector(2, f16), .{
                next(f16, -fmax(f16), -0.0), next(f16, next(f16, -fmax(f16), -0.0), -0.0),
            });
            try testArgs(@Vector(4, i128), @Vector(4, f16), .{
                -1e4, -1e3, -1e2, -1e1,
            });
            try testArgs(@Vector(8, i128), @Vector(8, f16), .{
                -1e0, -1e-1, -1e-2, -1e-3, -1e-4, -1e-5, -0.0, 0.0,
            });
            try testArgs(@Vector(16, i128), @Vector(16, f16), .{
                1e-5, 1e-4, 1e-3,                                      1e-2,                      1e-1, 1e0,  1e1,  1e2,
                1e3,  1e4,  next(f16, next(f16, fmax(f16), 0.0), 0.0), next(f16, fmax(f16), 0.0), -2e4, -2e3, -2e2, -2e1,
            });
            try testArgs(@Vector(32, i128), @Vector(32, f16), .{
                -2e0,  -2e-1, -2e-2, -2e-3, -2e-4, -2e-5, 2e-5,  2e-4,
                2e-3,  2e-2,  2e-1,  2e0,   2e1,   2e2,   2e3,   2e4,
                -3e4,  -3e3,  -3e2,  -3e1,  -3e0,  -3e-1, -3e-2, -3e-3,
                -3e-4, -3e-5, 3e-5,  3e-4,  3e-3,  3e-2,  3e-1,  3e0,
            });
            try testArgs(@Vector(64, i128), @Vector(64, f16), .{
                3e1,   3e2,   3e3,   3e4,   -4e3,  -4e2,  -4e1,  -4e0,
                -4e-1, -4e-2, -4e-3, -4e-4, -4e-5, 4e-5,  4e-4,  4e-3,
                4e-2,  4e-1,  4e0,   4e1,   4e2,   4e3,   -5e3,  -5e2,
                -5e1,  -5e0,  -5e-1, -5e-2, -5e-3, -5e-4, -5e-5, 5e-5,
                5e-4,  5e-3,  5e-2,  5e-1,  5e0,   5e1,   5e2,   5e3,
                -6e3,  -6e2,  -6e1,  -6e0,  -6e-1, -6e-2, -6e-3, -6e-4,
                -6e-5, 6e-5,  6e-4,  6e-3,  6e-2,  6e-1,  6e0,   6e1,
                6e2,   6e3,   -7e3,  -7e2,  -7e1,  -7e0,  -7e-1, -7e-2,
            });

            try testArgs(@Vector(1, u128), @Vector(1, f16), .{
                -0.0,
            });
            try testArgs(@Vector(2, u128), @Vector(2, f16), .{
                0.0, 1e-5,
            });
            try testArgs(@Vector(4, u128), @Vector(4, f16), .{
                1e-4, 1e-3, 1e-2, 1e-1,
            });
            try testArgs(@Vector(8, u128), @Vector(8, f16), .{
                1e0, 1e1, 1e2, 1e3, 1e4, next(f16, next(f16, fmax(f16), 0.0), 0.0), next(f16, fmax(f16), 0.0), 2e-5,
            });
            try testArgs(@Vector(16, u128), @Vector(16, f16), .{
                2e-4, 2e-3, 2e-2, 2e-1, 2e0,  2e1,  2e2, 2e3,
                2e4,  3e-5, 3e-4, 3e-3, 3e-2, 3e-1, 3e0, 3e1,
            });
            try testArgs(@Vector(32, u128), @Vector(32, f16), .{
                3e2,  3e3,  3e4, 4e-5, 4e-4, 4e-3, 4e-2, 4e-1,
                4e0,  4e1,  4e2, 4e3,  5e-5, 5e-4, 5e-3, 5e-2,
                5e-1, 5e0,  5e1, 5e2,  5e3,  6e-5, 6e-4, 6e-3,
                6e-2, 6e-1, 6e0, 6e1,  6e2,  6e3,  7e-5, 7e-4,
            });
            try testArgs(@Vector(64, u128), @Vector(64, f16), .{
                7e-3,  7e-2,  7e-1,  7e0,   7e1,   7e2,   7e3,   8e-5,
                8e-4,  8e-3,  8e-2,  8e-1,  8e0,   8e1,   8e2,   8e3,
                9e-5,  9e-4,  9e-3,  9e-2,  9e-1,  9e0,   9e1,   9e2,
                9e3,   11e-5, 11e-4, 11e-3, 11e-2, 11e-1, 11e0,  11e1,
                11e2,  11e3,  13e-5, 13e-4, 13e-3, 13e-2, 13e-1, 13e0,
                13e1,  13e2,  13e3,  14e-5, 14e-4, 14e-3, 14e-2, 14e-1,
                14e0,  14e1,  14e2,  14e3,  15e-5, 15e-4, 15e-3, 15e-2,
                15e-1, 15e0,  15e1,  15e2,  15e3,  16e-5, 16e-4, 16e-3,
            });

            try testArgs(@Vector(1, i256), @Vector(1, f16), .{
                -fmax(f16),
            });
            try testArgs(@Vector(2, i256), @Vector(2, f16), .{
                next(f16, -fmax(f16), -0.0), next(f16, next(f16, -fmax(f16), -0.0), -0.0),
            });
            try testArgs(@Vector(4, i256), @Vector(4, f16), .{
                -1e4, -1e3, -1e2, -1e1,
            });
            try testArgs(@Vector(8, i256), @Vector(8, f16), .{
                -1e0, -1e-1, -1e-2, -1e-3, -1e-4, -1e-5, -0.0, 0.0,
            });
            try testArgs(@Vector(16, i256), @Vector(16, f16), .{
                1e-5, 1e-4, 1e-3,                                      1e-2,                      1e-1, 1e0,  1e1,  1e2,
                1e3,  1e4,  next(f16, next(f16, fmax(f16), 0.0), 0.0), next(f16, fmax(f16), 0.0), -2e4, -2e3, -2e2, -2e1,
            });
            try testArgs(@Vector(32, i256), @Vector(32, f16), .{
                -2e0,  -2e-1, -2e-2, -2e-3, -2e-4, -2e-5, 2e-5,  2e-4,
                2e-3,  2e-2,  2e-1,  2e0,   2e1,   2e2,   2e3,   2e4,
                -3e4,  -3e3,  -3e2,  -3e1,  -3e0,  -3e-1, -3e-2, -3e-3,
                -3e-4, -3e-5, 3e-5,  3e-4,  3e-3,  3e-2,  3e-1,  3e0,
            });
            try testArgs(@Vector(64, i256), @Vector(64, f16), .{
                3e1,   3e2,   3e3,   3e4,   -4e3,  -4e2,  -4e1,  -4e0,
                -4e-1, -4e-2, -4e-3, -4e-4, -4e-5, 4e-5,  4e-4,  4e-3,
                4e-2,  4e-1,  4e0,   4e1,   4e2,   4e3,   -5e3,  -5e2,
                -5e1,  -5e0,  -5e-1, -5e-2, -5e-3, -5e-4, -5e-5, 5e-5,
                5e-4,  5e-3,  5e-2,  5e-1,  5e0,   5e1,   5e2,   5e3,
                -6e3,  -6e2,  -6e1,  -6e0,  -6e-1, -6e-2, -6e-3, -6e-4,
                -6e-5, 6e-5,  6e-4,  6e-3,  6e-2,  6e-1,  6e0,   6e1,
                6e2,   6e3,   -7e3,  -7e2,  -7e1,  -7e0,  -7e-1, -7e-2,
            });

            try testArgs(@Vector(1, u256), @Vector(1, f16), .{
                -0.0,
            });
            try testArgs(@Vector(2, u256), @Vector(2, f16), .{
                0.0, 1e-5,
            });
            try testArgs(@Vector(4, u256), @Vector(4, f16), .{
                1e-4, 1e-3, 1e-2, 1e-1,
            });
            try testArgs(@Vector(8, u256), @Vector(8, f16), .{
                1e0, 1e1, 1e2, 1e3, 1e4, next(f16, next(f16, fmax(f16), 0.0), 0.0), next(f16, fmax(f16), 0.0), 2e-5,
            });
            try testArgs(@Vector(16, u256), @Vector(16, f16), .{
                2e-4, 2e-3, 2e-2, 2e-1, 2e0,  2e1,  2e2, 2e3,
                2e4,  3e-5, 3e-4, 3e-3, 3e-2, 3e-1, 3e0, 3e1,
            });
            try testArgs(@Vector(32, u256), @Vector(32, f16), .{
                3e2,  3e3,  3e4, 4e-5, 4e-4, 4e-3, 4e-2, 4e-1,
                4e0,  4e1,  4e2, 4e3,  5e-5, 5e-4, 5e-3, 5e-2,
                5e-1, 5e0,  5e1, 5e2,  5e3,  6e-5, 6e-4, 6e-3,
                6e-2, 6e-1, 6e0, 6e1,  6e2,  6e3,  7e-5, 7e-4,
            });
            try testArgs(@Vector(64, u256), @Vector(64, f16), .{
                7e-3,  7e-2,  7e-1,  7e0,   7e1,   7e2,   7e3,   8e-5,
                8e-4,  8e-3,  8e-2,  8e-1,  8e0,   8e1,   8e2,   8e3,
                9e-5,  9e-4,  9e-3,  9e-2,  9e-1,  9e0,   9e1,   9e2,
                9e3,   11e-5, 11e-4, 11e-3, 11e-2, 11e-1, 11e0,  11e1,
                11e2,  11e3,  13e-5, 13e-4, 13e-3, 13e-2, 13e-1, 13e0,
                13e1,  13e2,  13e3,  14e-5, 14e-4, 14e-3, 14e-2, 14e-1,
                14e0,  14e1,  14e2,  14e3,  15e-5, 15e-4, 15e-3, 15e-2,
                15e-1, 15e0,  15e1,  15e2,  15e3,  16e-5, 16e-4, 16e-3,
            });

            try testArgs(@Vector(1, i8), @Vector(1, f32), .{
                -0x0.8p8,
            });
            try testArgs(@Vector(2, i8), @Vector(2, f32), .{
                next(f32, -0x0.8p8, -0.0), next(f32, next(f32, -0x0.8p8, -0.0), -0.0),
            });
            try testArgs(@Vector(4, i8), @Vector(4, f32), .{
                -1e2, -1e1, -1e0, -1e-1,
            });
            try testArgs(@Vector(8, i8), @Vector(8, f32), .{
                -1e-2, -1e-3, -1e-4, -1e-5, -0.0, 0.0, 1e-5, 1e-4,
            });
            try testArgs(@Vector(16, i8), @Vector(16, f32), .{
                1e-3, 1e-2, 1e-1,  1e0,   1e1,   1e2,   next(f32, next(f32, 0x0.8p8, 0.0), 0.0), next(f32, 0x0.8p8, 0.0),
                -2e1, -2e0, -2e-1, -2e-2, -2e-3, -2e-4, -2e-5,                                   2e-5,
            });
            try testArgs(@Vector(32, i8), @Vector(32, f32), .{
                2e-4,  2e-3,  2e-2,  2e-1,  2e0,   2e1,  -3e1,  -3e0,
                -3e-1, -3e-2, -3e-3, -3e-4, -3e-5, 3e-5, 3e-4,  3e-3,
                3e-2,  3e-1,  3e0,   3e1,   -4e1,  -4e0, -4e-1, -4e-2,
                -4e-3, -4e-4, -4e-5, 4e-5,  4e-4,  4e-3, 4e-2,  4e-1,
            });
            try testArgs(@Vector(64, i8), @Vector(64, f32), .{
                4e0,   4e1,   -5e1,  -5e0,  -5e-1, -5e-2, -5e-3, -5e-4,
                -5e-5, 5e-5,  5e-4,  5e-3,  5e-2,  5e-1,  5e0,   5e1,
                -6e1,  -6e0,  -6e-1, -6e-2, -6e-3, -6e-4, -6e-5, 6e-5,
                6e-4,  6e-3,  6e-2,  6e-1,  6e0,   6e1,   -7e1,  -7e0,
                -7e-1, -7e-2, -7e-3, -7e-4, -7e-5, 7e-5,  7e-4,  7e-3,
                7e-2,  7e-1,  7e0,   7e1,   -8e1,  -8e0,  -8e-1, -8e-2,
                -8e-3, -8e-4, -8e-5, 8e-5,  8e-4,  8e-3,  8e-2,  8e-1,
                8e0,   8e1,   -9e1,  -9e0,  -9e-1, -9e-2, -9e-3, -9e-4,
            });
            try testArgs(@Vector(128, i8), @Vector(128, f32), .{
                -9e-5,  9e-5,   9e-4,   9e-3,   9e-2,   9e-1,   9e0,    9e1,
                -11e1,  -11e0,  -11e-1, -11e-2, -11e-3, -11e-4, -11e-5, 11e-5,
                11e-4,  11e-3,  11e-2,  11e-1,  11e0,   11e1,   -12e1,  -12e0,
                -12e-1, -12e-2, -12e-3, -12e-4, -12e-5, 12e-5,  12e-4,  12e-3,
                12e-2,  12e-1,  12e0,   12e1,   -13e0,  -13e-1, -13e-2, -13e-3,
                -13e-4, -13e-5, 13e-5,  13e-4,  13e-3,  13e-2,  13e-1,  13e0,
                -14e0,  -14e-1, -14e-2, -14e-3, -14e-4, -14e-5, 14e-5,  14e-4,
                14e-3,  14e-2,  14e-1,  14e0,   -15e0,  -15e-1, -15e-2, -15e-3,
                -15e-4, -15e-5, 15e-5,  15e-4,  15e-3,  15e-2,  15e-1,  15e0,
                -16e0,  -16e-1, -16e-2, -16e-3, -16e-4, -16e-5, 16e-5,  16e-4,
                16e-3,  16e-2,  16e-1,  16e0,   -17e0,  -17e-1, -17e-2, -17e-3,
                -17e-4, -17e-5, 17e-5,  17e-4,  17e-3,  17e-2,  17e-1,  17e0,
                -18e0,  -18e-1, -18e-2, -18e-3, -18e-4, -18e-5, 18e-5,  18e-4,
                18e-3,  18e-2,  18e-1,  18e0,   -19e0,  -19e-1, -19e-2, -19e-3,
                -19e-4, -19e-5, 19e-5,  19e-4,  19e-3,  19e-2,  19e-1,  19e0,
                -21e0,  -21e-1, -21e-2, -21e-3, -21e-4, -21e-5, 21e-5,  21e-4,
            });

            try testArgs(@Vector(1, u8), @Vector(1, f32), .{
                -0.0,
            });
            try testArgs(@Vector(2, u8), @Vector(2, f32), .{
                0.0, 1e-5,
            });
            try testArgs(@Vector(4, u8), @Vector(4, f32), .{
                1e-4, 1e-3, 1e-2, 1e-1,
            });
            try testArgs(@Vector(8, u8), @Vector(8, f32), .{
                1e0, 1e1, 1e2, next(f32, next(f32, 0x1p8, 0.0), 0.0), next(f32, 0x1p8, 0.0), 2e-5, 2e-4, 2e-3,
            });
            try testArgs(@Vector(16, u8), @Vector(16, f32), .{
                2e-2, 2e-1, 2e0, 2e1, 2e2,  3e-5, 3e-4, 3e-3,
                3e-2, 3e-1, 3e0, 3e1, 4e-5, 4e-4, 4e-3, 4e-2,
            });
            try testArgs(@Vector(32, u8), @Vector(32, f32), .{
                4e-1, 4e0,  4e1,  5e-5, 5e-4, 5e-3, 5e-2, 5e-1,
                5e0,  5e1,  6e-5, 6e-4, 6e-3, 6e-2, 6e-1, 6e0,
                6e1,  7e-5, 7e-4, 7e-3, 7e-2, 7e-1, 7e0,  7e1,
                8e-5, 8e-4, 8e-3, 8e-2, 8e-1, 8e0,  8e1,  9e-5,
            });
            try testArgs(@Vector(64, u8), @Vector(64, f32), .{
                9e-4,  9e-3,  9e-2,  9e-1,  9e0,   9e1,   11e-5, 11e-4,
                11e-3, 11e-2, 11e-1, 11e0,  11e1,  13e-5, 13e-4, 13e-3,
                13e-2, 13e-1, 13e0,  14e-5, 14e-4, 14e-3, 14e-2, 14e-1,
                14e0,  14e1,  15e-5, 15e-4, 15e-3, 15e-2, 15e-1, 15e0,
                15e1,  16e-5, 16e-4, 16e-3, 16e-2, 16e-1, 16e0,  16e1,
                17e-5, 17e-4, 17e-3, 17e-2, 17e-1, 17e0,  17e1,  18e-5,
                18e-4, 18e-3, 18e-2, 18e-1, 18e0,  18e1,  19e-5, 19e-4,
                19e-3, 19e-2, 19e-1, 19e0,  19e1,  21e-5, 21e-4, 21e-3,
            });
            try testArgs(@Vector(128, u8), @Vector(128, f32), .{
                21e-2, 21e-1, 21e0,  21e1,  22e-5, 22e-4, 22e-3, 22e-2,
                22e-1, 22e0,  22e1,  23e-5, 23e-4, 23e-3, 23e-2, 23e-1,
                23e0,  23e1,  24e-5, 24e-4, 24e-3, 24e-2, 24e-1, 24e0,
                24e1,  25e-5, 25e-4, 25e-3, 25e-2, 25e-1, 25e0,  25e1,
                26e-5, 26e-4, 26e-3, 26e-2, 26e-1, 26e0,  27e-5, 27e-4,
                27e-3, 27e-2, 27e-1, 27e0,  28e-5, 28e-4, 28e-3, 28e-2,
                28e-1, 28e0,  29e-5, 29e-4, 29e-3, 29e-2, 29e-1, 29e0,
                31e-5, 31e-4, 31e-3, 31e-2, 31e-1, 31e0,  32e-5, 32e-4,
                32e-3, 32e-2, 32e-1, 32e0,  33e-5, 33e-4, 33e-3, 33e-2,
                33e-1, 33e0,  34e-5, 34e-4, 34e-3, 34e-2, 34e-1, 34e0,
                35e-5, 35e-4, 35e-3, 35e-2, 35e-1, 35e0,  36e-5, 36e-4,
                36e-3, 36e-2, 36e-1, 36e0,  37e-5, 37e-4, 37e-3, 37e-2,
                37e-1, 37e0,  38e-5, 38e-4, 38e-3, 38e-2, 38e-1, 38e0,
                39e-5, 39e-4, 39e-3, 39e-2, 39e-1, 39e0,  41e-5, 41e-4,
                41e-3, 41e-2, 41e-1, 41e0,  42e-5, 42e-4, 42e-3, 42e-2,
                42e-1, 42e0,  43e-5, 43e-4, 43e-3, 43e-2, 43e-1, 43e0,
            });

            try testArgs(@Vector(1, i16), @Vector(1, f32), .{
                -0x0.8p16,
            });
            try testArgs(@Vector(2, i16), @Vector(2, f32), .{
                next(f32, -0x0.8p16, -0.0), next(f32, next(f32, -0x0.8p16, -0.0), -0.0),
            });
            try testArgs(@Vector(4, i16), @Vector(4, f32), .{
                -1e4, -1e3, -1e2, -1e1,
            });
            try testArgs(@Vector(8, i16), @Vector(8, f32), .{
                -1e0, -1e-1, -1e-2, -1e-3, -1e-4, -1e-5, -0.0, 0.0,
            });
            try testArgs(@Vector(16, i16), @Vector(16, f32), .{
                1e-5, 1e-4, 1e-3,                                     1e-2,                     1e-1, 1e0,  1e1,  1e2,
                1e3,  1e4,  next(f32, next(f32, 0x0.8p16, 0.0), 0.0), next(f32, 0x0.8p16, 0.0), -2e4, -2e3, -2e2, -2e1,
            });
            try testArgs(@Vector(32, i16), @Vector(32, f32), .{
                -2e0,  -2e-1, -2e-2, -2e-3, -2e-4, -2e-5, 2e-5,  2e-4,
                2e-3,  2e-2,  2e-1,  2e0,   2e1,   2e2,   2e3,   2e4,
                -3e4,  -3e3,  -3e2,  -3e1,  -3e0,  -3e-1, -3e-2, -3e-3,
                -3e-4, -3e-5, 3e-5,  3e-4,  3e-3,  3e-2,  3e-1,  3e0,
            });
            try testArgs(@Vector(64, i16), @Vector(64, f32), .{
                3e1,   3e2,   3e3,   3e4,   -4e3,  -4e2,  -4e1,  -4e0,
                -4e-1, -4e-2, -4e-3, -4e-4, -4e-5, 4e-5,  4e-4,  4e-3,
                4e-2,  4e-1,  4e0,   4e1,   4e2,   4e3,   -5e3,  -5e2,
                -5e1,  -5e0,  -5e-1, -5e-2, -5e-3, -5e-4, -5e-5, 5e-5,
                5e-4,  5e-3,  5e-2,  5e-1,  5e0,   5e1,   5e2,   5e3,
                -6e3,  -6e2,  -6e1,  -6e0,  -6e-1, -6e-2, -6e-3, -6e-4,
                -6e-5, 6e-5,  6e-4,  6e-3,  6e-2,  6e-1,  6e0,   6e1,
                6e2,   6e3,   -7e3,  -7e2,  -7e1,  -7e0,  -7e-1, -7e-2,
            });
            try testArgs(@Vector(128, i16), @Vector(128, f32), .{
                -7e-3,  -7e-4,  -7e-5,  7e-5,   7e-4,   7e-3,   7e-2,   7e-1,
                7e0,    7e1,    7e2,    7e3,    -8e3,   -8e2,   -8e1,   -8e0,
                -8e-1,  -8e-2,  -8e-3,  -8e-4,  -8e-5,  8e-5,   8e-4,   8e-3,
                8e-2,   8e-1,   8e0,    8e1,    8e2,    8e3,    -9e3,   -9e2,
                -9e1,   -9e0,   -9e-1,  -9e-2,  -9e-3,  -9e-4,  -9e-5,  9e-5,
                9e-4,   9e-3,   9e-2,   9e-1,   9e0,    9e1,    9e2,    9e3,
                -11e3,  -11e2,  -11e1,  -11e0,  -11e-1, -11e-2, -11e-3, -11e-4,
                -11e-5, 11e-5,  11e-4,  11e-3,  11e-2,  11e-1,  11e0,   11e1,
                11e2,   11e3,   -12e3,  -12e2,  -12e1,  -12e0,  -12e-1, -12e-2,
                -12e-3, -12e-4, -12e-5, 12e-5,  12e-4,  12e-3,  12e-2,  12e-1,
                12e0,   12e1,   12e2,   12e3,   -13e3,  -13e2,  -13e1,  -13e0,
                -13e-1, -13e-2, -13e-3, -13e-4, -13e-5, 13e-5,  13e-4,  13e-3,
                13e-2,  13e-1,  13e0,   13e1,   13e2,   -14e2,  -14e1,  -14e0,
                -14e-1, -14e-2, -14e-3, -14e-4, -14e-5, 14e-5,  14e-4,  14e-3,
                14e-2,  14e-1,  14e0,   14e1,   14e2,   14e3,   -15e3,  -15e2,
                -15e1,  -15e0,  -15e-1, -15e-2, -15e-3, -15e-4, -15e-5, 15e-5,
            });

            try testArgs(@Vector(1, u16), @Vector(1, f32), .{
                -0.0,
            });
            try testArgs(@Vector(2, u16), @Vector(2, f32), .{
                0.0, 1e-5,
            });
            try testArgs(@Vector(4, u16), @Vector(4, f32), .{
                1e-4, 1e-3, 1e-2, 1e-1,
            });
            try testArgs(@Vector(8, u16), @Vector(8, f32), .{
                1e0, 1e1, 1e2, 1e3, 1e4, next(f32, next(f32, 0x1p16, 0.0), 0.0), next(f32, 0x1p16, 0.0), 2e-5,
            });
            try testArgs(@Vector(16, u16), @Vector(16, f32), .{
                2e-4, 2e-3, 2e-2, 2e-1, 2e0,  2e1,  2e2, 2e3,
                2e4,  3e-5, 3e-4, 3e-3, 3e-2, 3e-1, 3e0, 3e1,
            });
            try testArgs(@Vector(32, u16), @Vector(32, f32), .{
                3e2,  3e3,  3e4, 4e-5, 4e-4, 4e-3, 4e-2, 4e-1,
                4e0,  4e1,  4e2, 4e3,  5e-5, 5e-4, 5e-3, 5e-2,
                5e-1, 5e0,  5e1, 5e2,  5e3,  6e-5, 6e-4, 6e-3,
                6e-2, 6e-1, 6e0, 6e1,  6e2,  6e3,  7e-5, 7e-4,
            });
            try testArgs(@Vector(64, u16), @Vector(64, f32), .{
                7e-3,  7e-2,  7e-1,  7e0,   7e1,   7e2,   7e3,   8e-5,
                8e-4,  8e-3,  8e-2,  8e-1,  8e0,   8e1,   8e2,   8e3,
                9e-5,  9e-4,  9e-3,  9e-2,  9e-1,  9e0,   9e1,   9e2,
                9e3,   11e-5, 11e-4, 11e-3, 11e-2, 11e-1, 11e0,  11e1,
                11e2,  11e3,  13e-5, 13e-4, 13e-3, 13e-2, 13e-1, 13e0,
                13e1,  13e2,  13e3,  14e-5, 14e-4, 14e-3, 14e-2, 14e-1,
                14e0,  14e1,  14e2,  14e3,  15e-5, 15e-4, 15e-3, 15e-2,
                15e-1, 15e0,  15e1,  15e2,  15e3,  16e-5, 16e-4, 16e-3,
            });
            try testArgs(@Vector(128, u16), @Vector(128, f32), .{
                16e-2, 16e-1, 16e0,  16e1,  16e2,  16e3,  17e-5, 17e-4,
                17e-3, 17e-2, 17e-1, 17e0,  17e1,  17e2,  17e3,  18e-5,
                18e-4, 18e-3, 18e-2, 18e-1, 18e0,  18e1,  18e2,  18e3,
                19e-5, 19e-4, 19e-3, 19e-2, 19e-1, 19e0,  19e1,  19e2,
                19e3,  21e-5, 21e-4, 21e-3, 21e-2, 21e-1, 21e0,  21e1,
                21e2,  21e3,  22e-5, 22e-4, 22e-3, 22e-2, 22e-1, 22e0,
                22e1,  22e2,  22e3,  23e-5, 23e-4, 23e-3, 23e-2, 23e-1,
                23e0,  23e1,  23e2,  23e3,  24e-5, 24e-4, 24e-3, 24e-2,
                24e-1, 24e0,  24e1,  24e2,  24e3,  25e-5, 25e-4, 25e-3,
                25e-2, 25e-1, 25e0,  25e1,  25e2,  25e3,  26e-5, 26e-4,
                26e-3, 26e-2, 26e-1, 26e0,  26e1,  26e2,  26e3,  27e-5,
                27e-4, 27e-3, 27e-2, 27e-1, 27e0,  27e1,  27e2,  27e3,
                28e-5, 28e-4, 28e-3, 28e-2, 28e-1, 28e0,  28e1,  28e2,
                28e3,  29e-5, 29e-4, 29e-3, 29e-2, 29e-1, 29e0,  29e1,
                29e2,  29e3,  31e-5, 31e-4, 31e-3, 31e-2, 31e-1, 31e0,
                31e1,  31e2,  31e3,  32e-5, 32e-4, 32e-3, 32e-2, 32e-1,
            });

            try testArgs(@Vector(1, i32), @Vector(1, f32), .{
                -0x0.8p32,
            });
            try testArgs(@Vector(2, i32), @Vector(2, f32), .{
                next(f32, -0x0.8p32, -0.0), next(f32, next(f32, -0x0.8p32, -0.0), -0.0),
            });
            try testArgs(@Vector(4, i32), @Vector(4, f32), .{
                -1e4, -1e3, -1e2, -1e1,
            });
            try testArgs(@Vector(8, i32), @Vector(8, f32), .{
                -1e0, -1e-1, -1e-2, -1e-3, -1e-4, -1e-5, -0.0, 0.0,
            });
            try testArgs(@Vector(16, i32), @Vector(16, f32), .{
                1e-5, 1e-4, 1e-3,                                     1e-2,                     1e-1, 1e0,  1e1,  1e2,
                1e3,  1e4,  next(f32, next(f32, 0x0.8p32, 0.0), 0.0), next(f32, 0x0.8p32, 0.0), -2e4, -2e3, -2e2, -2e1,
            });
            try testArgs(@Vector(32, i32), @Vector(32, f32), .{
                -2e0,  -2e-1, -2e-2, -2e-3, -2e-4, -2e-5, 2e-5,  2e-4,
                2e-3,  2e-2,  2e-1,  2e0,   2e1,   2e2,   2e3,   2e4,
                -3e4,  -3e3,  -3e2,  -3e1,  -3e0,  -3e-1, -3e-2, -3e-3,
                -3e-4, -3e-5, 3e-5,  3e-4,  3e-3,  3e-2,  3e-1,  3e0,
            });
            try testArgs(@Vector(64, i32), @Vector(64, f32), .{
                3e1,   3e2,   3e3,   3e4,   -4e3,  -4e2,  -4e1,  -4e0,
                -4e-1, -4e-2, -4e-3, -4e-4, -4e-5, 4e-5,  4e-4,  4e-3,
                4e-2,  4e-1,  4e0,   4e1,   4e2,   4e3,   -5e3,  -5e2,
                -5e1,  -5e0,  -5e-1, -5e-2, -5e-3, -5e-4, -5e-5, 5e-5,
                5e-4,  5e-3,  5e-2,  5e-1,  5e0,   5e1,   5e2,   5e3,
                -6e3,  -6e2,  -6e1,  -6e0,  -6e-1, -6e-2, -6e-3, -6e-4,
                -6e-5, 6e-5,  6e-4,  6e-3,  6e-2,  6e-1,  6e0,   6e1,
                6e2,   6e3,   -7e3,  -7e2,  -7e1,  -7e0,  -7e-1, -7e-2,
            });
            try testArgs(@Vector(128, i32), @Vector(128, f32), .{
                -7e-3,  -7e-4,  -7e-5,  7e-5,   7e-4,   7e-3,   7e-2,   7e-1,
                7e0,    7e1,    7e2,    7e3,    -8e3,   -8e2,   -8e1,   -8e0,
                -8e-1,  -8e-2,  -8e-3,  -8e-4,  -8e-5,  8e-5,   8e-4,   8e-3,
                8e-2,   8e-1,   8e0,    8e1,    8e2,    8e3,    -9e3,   -9e2,
                -9e1,   -9e0,   -9e-1,  -9e-2,  -9e-3,  -9e-4,  -9e-5,  9e-5,
                9e-4,   9e-3,   9e-2,   9e-1,   9e0,    9e1,    9e2,    9e3,
                -11e3,  -11e2,  -11e1,  -11e0,  -11e-1, -11e-2, -11e-3, -11e-4,
                -11e-5, 11e-5,  11e-4,  11e-3,  11e-2,  11e-1,  11e0,   11e1,
                11e2,   11e3,   -12e3,  -12e2,  -12e1,  -12e0,  -12e-1, -12e-2,
                -12e-3, -12e-4, -12e-5, 12e-5,  12e-4,  12e-3,  12e-2,  12e-1,
                12e0,   12e1,   12e2,   12e3,   -13e3,  -13e2,  -13e1,  -13e0,
                -13e-1, -13e-2, -13e-3, -13e-4, -13e-5, 13e-5,  13e-4,  13e-3,
                13e-2,  13e-1,  13e0,   13e1,   13e2,   -14e2,  -14e1,  -14e0,
                -14e-1, -14e-2, -14e-3, -14e-4, -14e-5, 14e-5,  14e-4,  14e-3,
                14e-2,  14e-1,  14e0,   14e1,   14e2,   14e3,   -15e3,  -15e2,
                -15e1,  -15e0,  -15e-1, -15e-2, -15e-3, -15e-4, -15e-5, 15e-5,
            });

            try testArgs(@Vector(1, u32), @Vector(1, f32), .{
                -0.0,
            });
            try testArgs(@Vector(2, u32), @Vector(2, f32), .{
                0.0, 1e-5,
            });
            try testArgs(@Vector(4, u32), @Vector(4, f32), .{
                1e-4, 1e-3, 1e-2, 1e-1,
            });
            try testArgs(@Vector(8, u32), @Vector(8, f32), .{
                1e0, 1e1, 1e2, 1e3, 1e4, next(f32, next(f32, 0x1p32, 0.0), 0.0), next(f32, 0x1p32, 0.0), 2e-5,
            });
            try testArgs(@Vector(16, u32), @Vector(16, f32), .{
                2e-4, 2e-3, 2e-2, 2e-1, 2e0,  2e1,  2e2, 2e3,
                2e4,  3e-5, 3e-4, 3e-3, 3e-2, 3e-1, 3e0, 3e1,
            });
            try testArgs(@Vector(32, u32), @Vector(32, f32), .{
                3e2,  3e3,  3e4, 4e-5, 4e-4, 4e-3, 4e-2, 4e-1,
                4e0,  4e1,  4e2, 4e3,  5e-5, 5e-4, 5e-3, 5e-2,
                5e-1, 5e0,  5e1, 5e2,  5e3,  6e-5, 6e-4, 6e-3,
                6e-2, 6e-1, 6e0, 6e1,  6e2,  6e3,  7e-5, 7e-4,
            });
            try testArgs(@Vector(64, u32), @Vector(64, f32), .{
                7e-3,  7e-2,  7e-1,  7e0,   7e1,   7e2,   7e3,   8e-5,
                8e-4,  8e-3,  8e-2,  8e-1,  8e0,   8e1,   8e2,   8e3,
                9e-5,  9e-4,  9e-3,  9e-2,  9e-1,  9e0,   9e1,   9e2,
                9e3,   11e-5, 11e-4, 11e-3, 11e-2, 11e-1, 11e0,  11e1,
                11e2,  11e3,  13e-5, 13e-4, 13e-3, 13e-2, 13e-1, 13e0,
                13e1,  13e2,  13e3,  14e-5, 14e-4, 14e-3, 14e-2, 14e-1,
                14e0,  14e1,  14e2,  14e3,  15e-5, 15e-4, 15e-3, 15e-2,
                15e-1, 15e0,  15e1,  15e2,  15e3,  16e-5, 16e-4, 16e-3,
            });
            try testArgs(@Vector(128, u32), @Vector(128, f32), .{
                16e-2, 16e-1, 16e0,  16e1,  16e2,  16e3,  17e-5, 17e-4,
                17e-3, 17e-2, 17e-1, 17e0,  17e1,  17e2,  17e3,  18e-5,
                18e-4, 18e-3, 18e-2, 18e-1, 18e0,  18e1,  18e2,  18e3,
                19e-5, 19e-4, 19e-3, 19e-2, 19e-1, 19e0,  19e1,  19e2,
                19e3,  21e-5, 21e-4, 21e-3, 21e-2, 21e-1, 21e0,  21e1,
                21e2,  21e3,  22e-5, 22e-4, 22e-3, 22e-2, 22e-1, 22e0,
                22e1,  22e2,  22e3,  23e-5, 23e-4, 23e-3, 23e-2, 23e-1,
                23e0,  23e1,  23e2,  23e3,  24e-5, 24e-4, 24e-3, 24e-2,
                24e-1, 24e0,  24e1,  24e2,  24e3,  25e-5, 25e-4, 25e-3,
                25e-2, 25e-1, 25e0,  25e1,  25e2,  25e3,  26e-5, 26e-4,
                26e-3, 26e-2, 26e-1, 26e0,  26e1,  26e2,  26e3,  27e-5,
                27e-4, 27e-3, 27e-2, 27e-1, 27e0,  27e1,  27e2,  27e3,
                28e-5, 28e-4, 28e-3, 28e-2, 28e-1, 28e0,  28e1,  28e2,
                28e3,  29e-5, 29e-4, 29e-3, 29e-2, 29e-1, 29e0,  29e1,
                29e2,  29e3,  31e-5, 31e-4, 31e-3, 31e-2, 31e-1, 31e0,
                31e1,  31e2,  31e3,  32e-5, 32e-4, 32e-3, 32e-2, 32e-1,
            });

            try testArgs(@Vector(1, i64), @Vector(1, f32), .{
                -0x0.8p64,
            });
            try testArgs(@Vector(2, i64), @Vector(2, f32), .{
                next(f32, -0x0.8p64, -0.0), next(f32, next(f32, -0x0.8p64, -0.0), -0.0),
            });
            try testArgs(@Vector(4, i64), @Vector(4, f32), .{
                -1e4, -1e3, -1e2, -1e1,
            });
            try testArgs(@Vector(8, i64), @Vector(8, f32), .{
                -1e0, -1e-1, -1e-2, -1e-3, -1e-4, -1e-5, -0.0, 0.0,
            });
            try testArgs(@Vector(16, i64), @Vector(16, f32), .{
                1e-5, 1e-4, 1e-3,                                     1e-2,                     1e-1, 1e0,  1e1,  1e2,
                1e3,  1e4,  next(f32, next(f32, 0x0.8p64, 0.0), 0.0), next(f32, 0x0.8p64, 0.0), -2e4, -2e3, -2e2, -2e1,
            });
            try testArgs(@Vector(32, i64), @Vector(32, f32), .{
                -2e0,  -2e-1, -2e-2, -2e-3, -2e-4, -2e-5, 2e-5,  2e-4,
                2e-3,  2e-2,  2e-1,  2e0,   2e1,   2e2,   2e3,   2e4,
                -3e4,  -3e3,  -3e2,  -3e1,  -3e0,  -3e-1, -3e-2, -3e-3,
                -3e-4, -3e-5, 3e-5,  3e-4,  3e-3,  3e-2,  3e-1,  3e0,
            });
            try testArgs(@Vector(64, i64), @Vector(64, f32), .{
                3e1,   3e2,   3e3,   3e4,   -4e3,  -4e2,  -4e1,  -4e0,
                -4e-1, -4e-2, -4e-3, -4e-4, -4e-5, 4e-5,  4e-4,  4e-3,
                4e-2,  4e-1,  4e0,   4e1,   4e2,   4e3,   -5e3,  -5e2,
                -5e1,  -5e0,  -5e-1, -5e-2, -5e-3, -5e-4, -5e-5, 5e-5,
                5e-4,  5e-3,  5e-2,  5e-1,  5e0,   5e1,   5e2,   5e3,
                -6e3,  -6e2,  -6e1,  -6e0,  -6e-1, -6e-2, -6e-3, -6e-4,
                -6e-5, 6e-5,  6e-4,  6e-3,  6e-2,  6e-1,  6e0,   6e1,
                6e2,   6e3,   -7e3,  -7e2,  -7e1,  -7e0,  -7e-1, -7e-2,
            });
            try testArgs(@Vector(128, i64), @Vector(128, f32), .{
                -7e-3,  -7e-4,  -7e-5,  7e-5,   7e-4,   7e-3,   7e-2,   7e-1,
                7e0,    7e1,    7e2,    7e3,    -8e3,   -8e2,   -8e1,   -8e0,
                -8e-1,  -8e-2,  -8e-3,  -8e-4,  -8e-5,  8e-5,   8e-4,   8e-3,
                8e-2,   8e-1,   8e0,    8e1,    8e2,    8e3,    -9e3,   -9e2,
                -9e1,   -9e0,   -9e-1,  -9e-2,  -9e-3,  -9e-4,  -9e-5,  9e-5,
                9e-4,   9e-3,   9e-2,   9e-1,   9e0,    9e1,    9e2,    9e3,
                -11e3,  -11e2,  -11e1,  -11e0,  -11e-1, -11e-2, -11e-3, -11e-4,
                -11e-5, 11e-5,  11e-4,  11e-3,  11e-2,  11e-1,  11e0,   11e1,
                11e2,   11e3,   -12e3,  -12e2,  -12e1,  -12e0,  -12e-1, -12e-2,
                -12e-3, -12e-4, -12e-5, 12e-5,  12e-4,  12e-3,  12e-2,  12e-1,
                12e0,   12e1,   12e2,   12e3,   -13e3,  -13e2,  -13e1,  -13e0,
                -13e-1, -13e-2, -13e-3, -13e-4, -13e-5, 13e-5,  13e-4,  13e-3,
                13e-2,  13e-1,  13e0,   13e1,   13e2,   -14e2,  -14e1,  -14e0,
                -14e-1, -14e-2, -14e-3, -14e-4, -14e-5, 14e-5,  14e-4,  14e-3,
                14e-2,  14e-1,  14e0,   14e1,   14e2,   14e3,   -15e3,  -15e2,
                -15e1,  -15e0,  -15e-1, -15e-2, -15e-3, -15e-4, -15e-5, 15e-5,
            });

            try testArgs(@Vector(1, u64), @Vector(1, f32), .{
                -0.0,
            });
            try testArgs(@Vector(2, u64), @Vector(2, f32), .{
                0.0, 1e-5,
            });
            try testArgs(@Vector(4, u64), @Vector(4, f32), .{
                1e-4, 1e-3, 1e-2, 1e-1,
            });
            try testArgs(@Vector(8, u64), @Vector(8, f32), .{
                1e0, 1e1, 1e2, 1e3, 1e4, next(f32, next(f32, 0x1p64, 0.0), 0.0), next(f32, 0x1p64, 0.0), 2e-5,
            });
            try testArgs(@Vector(16, u64), @Vector(16, f32), .{
                2e-4, 2e-3, 2e-2, 2e-1, 2e0,  2e1,  2e2, 2e3,
                2e4,  3e-5, 3e-4, 3e-3, 3e-2, 3e-1, 3e0, 3e1,
            });
            try testArgs(@Vector(32, u64), @Vector(32, f32), .{
                3e2,  3e3,  3e4, 4e-5, 4e-4, 4e-3, 4e-2, 4e-1,
                4e0,  4e1,  4e2, 4e3,  5e-5, 5e-4, 5e-3, 5e-2,
                5e-1, 5e0,  5e1, 5e2,  5e3,  6e-5, 6e-4, 6e-3,
                6e-2, 6e-1, 6e0, 6e1,  6e2,  6e3,  7e-5, 7e-4,
            });
            try testArgs(@Vector(64, u64), @Vector(64, f32), .{
                7e-3,  7e-2,  7e-1,  7e0,   7e1,   7e2,   7e3,   8e-5,
                8e-4,  8e-3,  8e-2,  8e-1,  8e0,   8e1,   8e2,   8e3,
                9e-5,  9e-4,  9e-3,  9e-2,  9e-1,  9e0,   9e1,   9e2,
                9e3,   11e-5, 11e-4, 11e-3, 11e-2, 11e-1, 11e0,  11e1,
                11e2,  11e3,  13e-5, 13e-4, 13e-3, 13e-2, 13e-1, 13e0,
                13e1,  13e2,  13e3,  14e-5, 14e-4, 14e-3, 14e-2, 14e-1,
                14e0,  14e1,  14e2,  14e3,  15e-5, 15e-4, 15e-3, 15e-2,
                15e-1, 15e0,  15e1,  15e2,  15e3,  16e-5, 16e-4, 16e-3,
            });
            try testArgs(@Vector(128, u64), @Vector(128, f32), .{
                16e-2, 16e-1, 16e0,  16e1,  16e2,  16e3,  17e-5, 17e-4,
                17e-3, 17e-2, 17e-1, 17e0,  17e1,  17e2,  17e3,  18e-5,
                18e-4, 18e-3, 18e-2, 18e-1, 18e0,  18e1,  18e2,  18e3,
                19e-5, 19e-4, 19e-3, 19e-2, 19e-1, 19e0,  19e1,  19e2,
                19e3,  21e-5, 21e-4, 21e-3, 21e-2, 21e-1, 21e0,  21e1,
                21e2,  21e3,  22e-5, 22e-4, 22e-3, 22e-2, 22e-1, 22e0,
                22e1,  22e2,  22e3,  23e-5, 23e-4, 23e-3, 23e-2, 23e-1,
                23e0,  23e1,  23e2,  23e3,  24e-5, 24e-4, 24e-3, 24e-2,
                24e-1, 24e0,  24e1,  24e2,  24e3,  25e-5, 25e-4, 25e-3,
                25e-2, 25e-1, 25e0,  25e1,  25e2,  25e3,  26e-5, 26e-4,
                26e-3, 26e-2, 26e-1, 26e0,  26e1,  26e2,  26e3,  27e-5,
                27e-4, 27e-3, 27e-2, 27e-1, 27e0,  27e1,  27e2,  27e3,
                28e-5, 28e-4, 28e-3, 28e-2, 28e-1, 28e0,  28e1,  28e2,
                28e3,  29e-5, 29e-4, 29e-3, 29e-2, 29e-1, 29e0,  29e1,
                29e2,  29e3,  31e-5, 31e-4, 31e-3, 31e-2, 31e-1, 31e0,
                31e1,  31e2,  31e3,  32e-5, 32e-4, 32e-3, 32e-2, 32e-1,
            });

            try testArgs(@Vector(1, i128), @Vector(1, f32), .{
                -0x0.8p128,
            });
            try testArgs(@Vector(2, i128), @Vector(2, f32), .{
                next(f32, -0x0.8p128, -0.0), next(f32, next(f32, -0x0.8p128, -0.0), -0.0),
            });
            try testArgs(@Vector(4, i128), @Vector(4, f32), .{
                -1e4, -1e3, -1e2, -1e1,
            });
            try testArgs(@Vector(8, i128), @Vector(8, f32), .{
                -1e0, -1e-1, -1e-2, -1e-3, -1e-4, -1e-5, -0.0, 0.0,
            });
            try testArgs(@Vector(16, i128), @Vector(16, f32), .{
                1e-5, 1e-4, 1e-3,                                      1e-2,                      1e-1, 1e0,  1e1,  1e2,
                1e3,  1e4,  next(f32, next(f32, 0x0.8p128, 0.0), 0.0), next(f32, 0x0.8p128, 0.0), -2e4, -2e3, -2e2, -2e1,
            });
            try testArgs(@Vector(32, i128), @Vector(32, f32), .{
                -2e0,  -2e-1, -2e-2, -2e-3, -2e-4, -2e-5, 2e-5,  2e-4,
                2e-3,  2e-2,  2e-1,  2e0,   2e1,   2e2,   2e3,   2e4,
                -3e4,  -3e3,  -3e2,  -3e1,  -3e0,  -3e-1, -3e-2, -3e-3,
                -3e-4, -3e-5, 3e-5,  3e-4,  3e-3,  3e-2,  3e-1,  3e0,
            });
            try testArgs(@Vector(64, i128), @Vector(64, f32), .{
                3e1,   3e2,   3e3,   3e4,   -4e3,  -4e2,  -4e1,  -4e0,
                -4e-1, -4e-2, -4e-3, -4e-4, -4e-5, 4e-5,  4e-4,  4e-3,
                4e-2,  4e-1,  4e0,   4e1,   4e2,   4e3,   -5e3,  -5e2,
                -5e1,  -5e0,  -5e-1, -5e-2, -5e-3, -5e-4, -5e-5, 5e-5,
                5e-4,  5e-3,  5e-2,  5e-1,  5e0,   5e1,   5e2,   5e3,
                -6e3,  -6e2,  -6e1,  -6e0,  -6e-1, -6e-2, -6e-3, -6e-4,
                -6e-5, 6e-5,  6e-4,  6e-3,  6e-2,  6e-1,  6e0,   6e1,
                6e2,   6e3,   -7e3,  -7e2,  -7e1,  -7e0,  -7e-1, -7e-2,
            });

            try testArgs(@Vector(1, u128), @Vector(1, f32), .{
                -0.0,
            });
            try testArgs(@Vector(2, u128), @Vector(2, f32), .{
                0.0, 1e-5,
            });
            try testArgs(@Vector(4, u128), @Vector(4, f32), .{
                1e-4, 1e-3, 1e-2, 1e-1,
            });
            try testArgs(@Vector(8, u128), @Vector(8, f32), .{
                1e0, 1e1, 1e2, 1e3, 1e4, next(f32, next(f32, fmax(f32), 0.0), 0.0), next(f32, fmax(f32), 0.0), 2e-5,
            });
            try testArgs(@Vector(16, u128), @Vector(16, f32), .{
                2e-4, 2e-3, 2e-2, 2e-1, 2e0,  2e1,  2e2, 2e3,
                2e4,  3e-5, 3e-4, 3e-3, 3e-2, 3e-1, 3e0, 3e1,
            });
            try testArgs(@Vector(32, u128), @Vector(32, f32), .{
                3e2,  3e3,  3e4, 4e-5, 4e-4, 4e-3, 4e-2, 4e-1,
                4e0,  4e1,  4e2, 4e3,  5e-5, 5e-4, 5e-3, 5e-2,
                5e-1, 5e0,  5e1, 5e2,  5e3,  6e-5, 6e-4, 6e-3,
                6e-2, 6e-1, 6e0, 6e1,  6e2,  6e3,  7e-5, 7e-4,
            });
            try testArgs(@Vector(64, u128), @Vector(64, f32), .{
                7e-3,  7e-2,  7e-1,  7e0,   7e1,   7e2,   7e3,   8e-5,
                8e-4,  8e-3,  8e-2,  8e-1,  8e0,   8e1,   8e2,   8e3,
                9e-5,  9e-4,  9e-3,  9e-2,  9e-1,  9e0,   9e1,   9e2,
                9e3,   11e-5, 11e-4, 11e-3, 11e-2, 11e-1, 11e0,  11e1,
                11e2,  11e3,  13e-5, 13e-4, 13e-3, 13e-2, 13e-1, 13e0,
                13e1,  13e2,  13e3,  14e-5, 14e-4, 14e-3, 14e-2, 14e-1,
                14e0,  14e1,  14e2,  14e3,  15e-5, 15e-4, 15e-3, 15e-2,
                15e-1, 15e0,  15e1,  15e2,  15e3,  16e-5, 16e-4, 16e-3,
            });

            try testArgs(@Vector(1, i256), @Vector(1, f32), .{
                -fmax(f32),
            });
            try testArgs(@Vector(2, i256), @Vector(2, f32), .{
                next(f32, -fmax(f32), -0.0), next(f32, next(f32, -fmax(f32), -0.0), -0.0),
            });
            try testArgs(@Vector(4, i256), @Vector(4, f32), .{
                -1e4, -1e3, -1e2, -1e1,
            });
            try testArgs(@Vector(8, i256), @Vector(8, f32), .{
                -1e0, -1e-1, -1e-2, -1e-3, -1e-4, -1e-5, -0.0, 0.0,
            });
            try testArgs(@Vector(16, i256), @Vector(16, f32), .{
                1e-5, 1e-4, 1e-3,                                      1e-2,                      1e-1, 1e0,  1e1,  1e2,
                1e3,  1e4,  next(f32, next(f32, fmax(f32), 0.0), 0.0), next(f32, fmax(f32), 0.0), -2e4, -2e3, -2e2, -2e1,
            });
            try testArgs(@Vector(32, i256), @Vector(32, f32), .{
                -2e0,  -2e-1, -2e-2, -2e-3, -2e-4, -2e-5, 2e-5,  2e-4,
                2e-3,  2e-2,  2e-1,  2e0,   2e1,   2e2,   2e3,   2e4,
                -3e4,  -3e3,  -3e2,  -3e1,  -3e0,  -3e-1, -3e-2, -3e-3,
                -3e-4, -3e-5, 3e-5,  3e-4,  3e-3,  3e-2,  3e-1,  3e0,
            });
            try testArgs(@Vector(64, i256), @Vector(64, f32), .{
                3e1,   3e2,   3e3,   3e4,   -4e3,  -4e2,  -4e1,  -4e0,
                -4e-1, -4e-2, -4e-3, -4e-4, -4e-5, 4e-5,  4e-4,  4e-3,
                4e-2,  4e-1,  4e0,   4e1,   4e2,   4e3,   -5e3,  -5e2,
                -5e1,  -5e0,  -5e-1, -5e-2, -5e-3, -5e-4, -5e-5, 5e-5,
                5e-4,  5e-3,  5e-2,  5e-1,  5e0,   5e1,   5e2,   5e3,
                -6e3,  -6e2,  -6e1,  -6e0,  -6e-1, -6e-2, -6e-3, -6e-4,
                -6e-5, 6e-5,  6e-4,  6e-3,  6e-2,  6e-1,  6e0,   6e1,
                6e2,   6e3,   -7e3,  -7e2,  -7e1,  -7e0,  -7e-1, -7e-2,
            });

            try testArgs(@Vector(1, u256), @Vector(1, f32), .{
                -0.0,
            });
            try testArgs(@Vector(2, u256), @Vector(2, f32), .{
                0.0, 1e-5,
            });
            try testArgs(@Vector(4, u256), @Vector(4, f32), .{
                1e-4, 1e-3, 1e-2, 1e-1,
            });
            try testArgs(@Vector(8, u256), @Vector(8, f32), .{
                1e0, 1e1, 1e2, 1e3, 1e4, next(f32, next(f32, fmax(f32), 0.0), 0.0), next(f32, fmax(f32), 0.0), 2e-5,
            });
            try testArgs(@Vector(16, u256), @Vector(16, f32), .{
                2e-4, 2e-3, 2e-2, 2e-1, 2e0,  2e1,  2e2, 2e3,
                2e4,  3e-5, 3e-4, 3e-3, 3e-2, 3e-1, 3e0, 3e1,
            });
            try testArgs(@Vector(32, u256), @Vector(32, f32), .{
                3e2,  3e3,  3e4, 4e-5, 4e-4, 4e-3, 4e-2, 4e-1,
                4e0,  4e1,  4e2, 4e3,  5e-5, 5e-4, 5e-3, 5e-2,
                5e-1, 5e0,  5e1, 5e2,  5e3,  6e-5, 6e-4, 6e-3,
                6e-2, 6e-1, 6e0, 6e1,  6e2,  6e3,  7e-5, 7e-4,
            });
            try testArgs(@Vector(64, u256), @Vector(64, f32), .{
                7e-3,  7e-2,  7e-1,  7e0,   7e1,   7e2,   7e3,   8e-5,
                8e-4,  8e-3,  8e-2,  8e-1,  8e0,   8e1,   8e2,   8e3,
                9e-5,  9e-4,  9e-3,  9e-2,  9e-1,  9e0,   9e1,   9e2,
                9e3,   11e-5, 11e-4, 11e-3, 11e-2, 11e-1, 11e0,  11e1,
                11e2,  11e3,  13e-5, 13e-4, 13e-3, 13e-2, 13e-1, 13e0,
                13e1,  13e2,  13e3,  14e-5, 14e-4, 14e-3, 14e-2, 14e-1,
                14e0,  14e1,  14e2,  14e3,  15e-5, 15e-4, 15e-3, 15e-2,
                15e-1, 15e0,  15e1,  15e2,  15e3,  16e-5, 16e-4, 16e-3,
            });

            try testArgs(@Vector(1, i8), @Vector(1, f64), .{
                -0x0.8p8,
            });
            try testArgs(@Vector(2, i8), @Vector(2, f64), .{
                next(f64, -0x0.8p8, -0.0), next(f64, next(f64, -0x0.8p8, -0.0), -0.0),
            });
            try testArgs(@Vector(4, i8), @Vector(4, f64), .{
                -1e2, -1e1, -1e0, -1e-1,
            });
            try testArgs(@Vector(8, i8), @Vector(8, f64), .{
                -1e-2, -1e-3, -1e-4, -1e-5, -0.0, 0.0, 1e-5, 1e-4,
            });
            try testArgs(@Vector(16, i8), @Vector(16, f64), .{
                1e-3, 1e-2, 1e-1,  1e0,   1e1,   1e2,   next(f64, next(f64, 0x0.8p8, 0.0), 0.0), next(f64, 0x0.8p8, 0.0),
                -2e1, -2e0, -2e-1, -2e-2, -2e-3, -2e-4, -2e-5,                                   2e-5,
            });
            try testArgs(@Vector(32, i8), @Vector(32, f64), .{
                2e-4,  2e-3,  2e-2,  2e-1,  2e0,   2e1,  -3e1,  -3e0,
                -3e-1, -3e-2, -3e-3, -3e-4, -3e-5, 3e-5, 3e-4,  3e-3,
                3e-2,  3e-1,  3e0,   3e1,   -4e1,  -4e0, -4e-1, -4e-2,
                -4e-3, -4e-4, -4e-5, 4e-5,  4e-4,  4e-3, 4e-2,  4e-1,
            });
            try testArgs(@Vector(64, i8), @Vector(64, f64), .{
                4e0,   4e1,   -5e1,  -5e0,  -5e-1, -5e-2, -5e-3, -5e-4,
                -5e-5, 5e-5,  5e-4,  5e-3,  5e-2,  5e-1,  5e0,   5e1,
                -6e1,  -6e0,  -6e-1, -6e-2, -6e-3, -6e-4, -6e-5, 6e-5,
                6e-4,  6e-3,  6e-2,  6e-1,  6e0,   6e1,   -7e1,  -7e0,
                -7e-1, -7e-2, -7e-3, -7e-4, -7e-5, 7e-5,  7e-4,  7e-3,
                7e-2,  7e-1,  7e0,   7e1,   -8e1,  -8e0,  -8e-1, -8e-2,
                -8e-3, -8e-4, -8e-5, 8e-5,  8e-4,  8e-3,  8e-2,  8e-1,
                8e0,   8e1,   -9e1,  -9e0,  -9e-1, -9e-2, -9e-3, -9e-4,
            });
            try testArgs(@Vector(128, i8), @Vector(128, f64), .{
                -9e-5,  9e-5,   9e-4,   9e-3,   9e-2,   9e-1,   9e0,    9e1,
                -11e1,  -11e0,  -11e-1, -11e-2, -11e-3, -11e-4, -11e-5, 11e-5,
                11e-4,  11e-3,  11e-2,  11e-1,  11e0,   11e1,   -12e1,  -12e0,
                -12e-1, -12e-2, -12e-3, -12e-4, -12e-5, 12e-5,  12e-4,  12e-3,
                12e-2,  12e-1,  12e0,   12e1,   -13e0,  -13e-1, -13e-2, -13e-3,
                -13e-4, -13e-5, 13e-5,  13e-4,  13e-3,  13e-2,  13e-1,  13e0,
                -14e0,  -14e-1, -14e-2, -14e-3, -14e-4, -14e-5, 14e-5,  14e-4,
                14e-3,  14e-2,  14e-1,  14e0,   -15e0,  -15e-1, -15e-2, -15e-3,
                -15e-4, -15e-5, 15e-5,  15e-4,  15e-3,  15e-2,  15e-1,  15e0,
                -16e0,  -16e-1, -16e-2, -16e-3, -16e-4, -16e-5, 16e-5,  16e-4,
                16e-3,  16e-2,  16e-1,  16e0,   -17e0,  -17e-1, -17e-2, -17e-3,
                -17e-4, -17e-5, 17e-5,  17e-4,  17e-3,  17e-2,  17e-1,  17e0,
                -18e0,  -18e-1, -18e-2, -18e-3, -18e-4, -18e-5, 18e-5,  18e-4,
                18e-3,  18e-2,  18e-1,  18e0,   -19e0,  -19e-1, -19e-2, -19e-3,
                -19e-4, -19e-5, 19e-5,  19e-4,  19e-3,  19e-2,  19e-1,  19e0,
                -21e0,  -21e-1, -21e-2, -21e-3, -21e-4, -21e-5, 21e-5,  21e-4,
            });

            try testArgs(@Vector(1, u8), @Vector(1, f64), .{
                -0.0,
            });
            try testArgs(@Vector(2, u8), @Vector(2, f64), .{
                0.0, 1e-5,
            });
            try testArgs(@Vector(4, u8), @Vector(4, f64), .{
                1e-4, 1e-3, 1e-2, 1e-1,
            });
            try testArgs(@Vector(8, u8), @Vector(8, f64), .{
                1e0, 1e1, 1e2, next(f64, next(f64, 0x1p8, 0.0), 0.0), next(f64, 0x1p8, 0.0), 2e-5, 2e-4, 2e-3,
            });
            try testArgs(@Vector(16, u8), @Vector(16, f64), .{
                2e-2, 2e-1, 2e0, 2e1, 2e2,  3e-5, 3e-4, 3e-3,
                3e-2, 3e-1, 3e0, 3e1, 4e-5, 4e-4, 4e-3, 4e-2,
            });
            try testArgs(@Vector(32, u8), @Vector(32, f64), .{
                4e-1, 4e0,  4e1,  5e-5, 5e-4, 5e-3, 5e-2, 5e-1,
                5e0,  5e1,  6e-5, 6e-4, 6e-3, 6e-2, 6e-1, 6e0,
                6e1,  7e-5, 7e-4, 7e-3, 7e-2, 7e-1, 7e0,  7e1,
                8e-5, 8e-4, 8e-3, 8e-2, 8e-1, 8e0,  8e1,  9e-5,
            });
            try testArgs(@Vector(64, u8), @Vector(64, f64), .{
                9e-4,  9e-3,  9e-2,  9e-1,  9e0,   9e1,   11e-5, 11e-4,
                11e-3, 11e-2, 11e-1, 11e0,  11e1,  13e-5, 13e-4, 13e-3,
                13e-2, 13e-1, 13e0,  14e-5, 14e-4, 14e-3, 14e-2, 14e-1,
                14e0,  14e1,  15e-5, 15e-4, 15e-3, 15e-2, 15e-1, 15e0,
                15e1,  16e-5, 16e-4, 16e-3, 16e-2, 16e-1, 16e0,  16e1,
                17e-5, 17e-4, 17e-3, 17e-2, 17e-1, 17e0,  17e1,  18e-5,
                18e-4, 18e-3, 18e-2, 18e-1, 18e0,  18e1,  19e-5, 19e-4,
                19e-3, 19e-2, 19e-1, 19e0,  19e1,  21e-5, 21e-4, 21e-3,
            });
            try testArgs(@Vector(128, u8), @Vector(128, f64), .{
                21e-2, 21e-1, 21e0,  21e1,  22e-5, 22e-4, 22e-3, 22e-2,
                22e-1, 22e0,  22e1,  23e-5, 23e-4, 23e-3, 23e-2, 23e-1,
                23e0,  23e1,  24e-5, 24e-4, 24e-3, 24e-2, 24e-1, 24e0,
                24e1,  25e-5, 25e-4, 25e-3, 25e-2, 25e-1, 25e0,  25e1,
                26e-5, 26e-4, 26e-3, 26e-2, 26e-1, 26e0,  27e-5, 27e-4,
                27e-3, 27e-2, 27e-1, 27e0,  28e-5, 28e-4, 28e-3, 28e-2,
                28e-1, 28e0,  29e-5, 29e-4, 29e-3, 29e-2, 29e-1, 29e0,
                31e-5, 31e-4, 31e-3, 31e-2, 31e-1, 31e0,  32e-5, 32e-4,
                32e-3, 32e-2, 32e-1, 32e0,  33e-5, 33e-4, 33e-3, 33e-2,
                33e-1, 33e0,  34e-5, 34e-4, 34e-3, 34e-2, 34e-1, 34e0,
                35e-5, 35e-4, 35e-3, 35e-2, 35e-1, 35e0,  36e-5, 36e-4,
                36e-3, 36e-2, 36e-1, 36e0,  37e-5, 37e-4, 37e-3, 37e-2,
                37e-1, 37e0,  38e-5, 38e-4, 38e-3, 38e-2, 38e-1, 38e0,
                39e-5, 39e-4, 39e-3, 39e-2, 39e-1, 39e0,  41e-5, 41e-4,
                41e-3, 41e-2, 41e-1, 41e0,  42e-5, 42e-4, 42e-3, 42e-2,
                42e-1, 42e0,  43e-5, 43e-4, 43e-3, 43e-2, 43e-1, 43e0,
            });

            try testArgs(@Vector(1, i16), @Vector(1, f64), .{
                -0x0.8p16,
            });
            try testArgs(@Vector(2, i16), @Vector(2, f64), .{
                next(f64, -0x0.8p16, -0.0), next(f64, next(f64, -0x0.8p16, -0.0), -0.0),
            });
            try testArgs(@Vector(4, i16), @Vector(4, f64), .{
                -1e4, -1e3, -1e2, -1e1,
            });
            try testArgs(@Vector(8, i16), @Vector(8, f64), .{
                -1e0, -1e-1, -1e-2, -1e-3, -1e-4, -1e-5, -0.0, 0.0,
            });
            try testArgs(@Vector(16, i16), @Vector(16, f64), .{
                1e-5, 1e-4, 1e-3,                                     1e-2,                     1e-1, 1e0,  1e1,  1e2,
                1e3,  1e4,  next(f64, next(f64, 0x0.8p16, 0.0), 0.0), next(f64, 0x0.8p16, 0.0), -2e4, -2e3, -2e2, -2e1,
            });
            try testArgs(@Vector(32, i16), @Vector(32, f64), .{
                -2e0,  -2e-1, -2e-2, -2e-3, -2e-4, -2e-5, 2e-5,  2e-4,
                2e-3,  2e-2,  2e-1,  2e0,   2e1,   2e2,   2e3,   2e4,
                -3e4,  -3e3,  -3e2,  -3e1,  -3e0,  -3e-1, -3e-2, -3e-3,
                -3e-4, -3e-5, 3e-5,  3e-4,  3e-3,  3e-2,  3e-1,  3e0,
            });
            try testArgs(@Vector(64, i16), @Vector(64, f64), .{
                3e1,   3e2,   3e3,   3e4,   -4e3,  -4e2,  -4e1,  -4e0,
                -4e-1, -4e-2, -4e-3, -4e-4, -4e-5, 4e-5,  4e-4,  4e-3,
                4e-2,  4e-1,  4e0,   4e1,   4e2,   4e3,   -5e3,  -5e2,
                -5e1,  -5e0,  -5e-1, -5e-2, -5e-3, -5e-4, -5e-5, 5e-5,
                5e-4,  5e-3,  5e-2,  5e-1,  5e0,   5e1,   5e2,   5e3,
                -6e3,  -6e2,  -6e1,  -6e0,  -6e-1, -6e-2, -6e-3, -6e-4,
                -6e-5, 6e-5,  6e-4,  6e-3,  6e-2,  6e-1,  6e0,   6e1,
                6e2,   6e3,   -7e3,  -7e2,  -7e1,  -7e0,  -7e-1, -7e-2,
            });
            try testArgs(@Vector(128, i16), @Vector(128, f64), .{
                -7e-3,  -7e-4,  -7e-5,  7e-5,   7e-4,   7e-3,   7e-2,   7e-1,
                7e0,    7e1,    7e2,    7e3,    -8e3,   -8e2,   -8e1,   -8e0,
                -8e-1,  -8e-2,  -8e-3,  -8e-4,  -8e-5,  8e-5,   8e-4,   8e-3,
                8e-2,   8e-1,   8e0,    8e1,    8e2,    8e3,    -9e3,   -9e2,
                -9e1,   -9e0,   -9e-1,  -9e-2,  -9e-3,  -9e-4,  -9e-5,  9e-5,
                9e-4,   9e-3,   9e-2,   9e-1,   9e0,    9e1,    9e2,    9e3,
                -11e3,  -11e2,  -11e1,  -11e0,  -11e-1, -11e-2, -11e-3, -11e-4,
                -11e-5, 11e-5,  11e-4,  11e-3,  11e-2,  11e-1,  11e0,   11e1,
                11e2,   11e3,   -12e3,  -12e2,  -12e1,  -12e0,  -12e-1, -12e-2,
                -12e-3, -12e-4, -12e-5, 12e-5,  12e-4,  12e-3,  12e-2,  12e-1,
                12e0,   12e1,   12e2,   12e3,   -13e3,  -13e2,  -13e1,  -13e0,
                -13e-1, -13e-2, -13e-3, -13e-4, -13e-5, 13e-5,  13e-4,  13e-3,
                13e-2,  13e-1,  13e0,   13e1,   13e2,   -14e2,  -14e1,  -14e0,
                -14e-1, -14e-2, -14e-3, -14e-4, -14e-5, 14e-5,  14e-4,  14e-3,
                14e-2,  14e-1,  14e0,   14e1,   14e2,   14e3,   -15e3,  -15e2,
                -15e1,  -15e0,  -15e-1, -15e-2, -15e-3, -15e-4, -15e-5, 15e-5,
            });

            try testArgs(@Vector(1, u16), @Vector(1, f64), .{
                -0.0,
            });
            try testArgs(@Vector(2, u16), @Vector(2, f64), .{
                0.0, 1e-5,
            });
            try testArgs(@Vector(4, u16), @Vector(4, f64), .{
                1e-4, 1e-3, 1e-2, 1e-1,
            });
            try testArgs(@Vector(8, u16), @Vector(8, f64), .{
                1e0, 1e1, 1e2, 1e3, 1e4, next(f64, next(f64, 0x1p16, 0.0), 0.0), next(f64, 0x1p16, 0.0), 2e-5,
            });
            try testArgs(@Vector(16, u16), @Vector(16, f64), .{
                2e-4, 2e-3, 2e-2, 2e-1, 2e0,  2e1,  2e2, 2e3,
                2e4,  3e-5, 3e-4, 3e-3, 3e-2, 3e-1, 3e0, 3e1,
            });
            try testArgs(@Vector(32, u16), @Vector(32, f64), .{
                3e2,  3e3,  3e4, 4e-5, 4e-4, 4e-3, 4e-2, 4e-1,
                4e0,  4e1,  4e2, 4e3,  5e-5, 5e-4, 5e-3, 5e-2,
                5e-1, 5e0,  5e1, 5e2,  5e3,  6e-5, 6e-4, 6e-3,
                6e-2, 6e-1, 6e0, 6e1,  6e2,  6e3,  7e-5, 7e-4,
            });
            try testArgs(@Vector(64, u16), @Vector(64, f64), .{
                7e-3,  7e-2,  7e-1,  7e0,   7e1,   7e2,   7e3,   8e-5,
                8e-4,  8e-3,  8e-2,  8e-1,  8e0,   8e1,   8e2,   8e3,
                9e-5,  9e-4,  9e-3,  9e-2,  9e-1,  9e0,   9e1,   9e2,
                9e3,   11e-5, 11e-4, 11e-3, 11e-2, 11e-1, 11e0,  11e1,
                11e2,  11e3,  13e-5, 13e-4, 13e-3, 13e-2, 13e-1, 13e0,
                13e1,  13e2,  13e3,  14e-5, 14e-4, 14e-3, 14e-2, 14e-1,
                14e0,  14e1,  14e2,  14e3,  15e-5, 15e-4, 15e-3, 15e-2,
                15e-1, 15e0,  15e1,  15e2,  15e3,  16e-5, 16e-4, 16e-3,
            });
            try testArgs(@Vector(128, u16), @Vector(128, f64), .{
                16e-2, 16e-1, 16e0,  16e1,  16e2,  16e3,  17e-5, 17e-4,
                17e-3, 17e-2, 17e-1, 17e0,  17e1,  17e2,  17e3,  18e-5,
                18e-4, 18e-3, 18e-2, 18e-1, 18e0,  18e1,  18e2,  18e3,
                19e-5, 19e-4, 19e-3, 19e-2, 19e-1, 19e0,  19e1,  19e2,
                19e3,  21e-5, 21e-4, 21e-3, 21e-2, 21e-1, 21e0,  21e1,
                21e2,  21e3,  22e-5, 22e-4, 22e-3, 22e-2, 22e-1, 22e0,
                22e1,  22e2,  22e3,  23e-5, 23e-4, 23e-3, 23e-2, 23e-1,
                23e0,  23e1,  23e2,  23e3,  24e-5, 24e-4, 24e-3, 24e-2,
                24e-1, 24e0,  24e1,  24e2,  24e3,  25e-5, 25e-4, 25e-3,
                25e-2, 25e-1, 25e0,  25e1,  25e2,  25e3,  26e-5, 26e-4,
                26e-3, 26e-2, 26e-1, 26e0,  26e1,  26e2,  26e3,  27e-5,
                27e-4, 27e-3, 27e-2, 27e-1, 27e0,  27e1,  27e2,  27e3,
                28e-5, 28e-4, 28e-3, 28e-2, 28e-1, 28e0,  28e1,  28e2,
                28e3,  29e-5, 29e-4, 29e-3, 29e-2, 29e-1, 29e0,  29e1,
                29e2,  29e3,  31e-5, 31e-4, 31e-3, 31e-2, 31e-1, 31e0,
                31e1,  31e2,  31e3,  32e-5, 32e-4, 32e-3, 32e-2, 32e-1,
            });

            try testArgs(@Vector(1, i32), @Vector(1, f64), .{
                -0x0.8p32,
            });
            try testArgs(@Vector(2, i32), @Vector(2, f64), .{
                next(f64, -0x0.8p32, -0.0), next(f64, next(f64, -0x0.8p32, -0.0), -0.0),
            });
            try testArgs(@Vector(4, i32), @Vector(4, f64), .{
                -1e4, -1e3, -1e2, -1e1,
            });
            try testArgs(@Vector(8, i32), @Vector(8, f64), .{
                -1e0, -1e-1, -1e-2, -1e-3, -1e-4, -1e-5, -0.0, 0.0,
            });
            try testArgs(@Vector(16, i32), @Vector(16, f64), .{
                1e-5, 1e-4, 1e-3,                                     1e-2,                     1e-1, 1e0,  1e1,  1e2,
                1e3,  1e4,  next(f64, next(f64, 0x0.8p32, 0.0), 0.0), next(f64, 0x0.8p32, 0.0), -2e4, -2e3, -2e2, -2e1,
            });
            try testArgs(@Vector(32, i32), @Vector(32, f64), .{
                -2e0,  -2e-1, -2e-2, -2e-3, -2e-4, -2e-5, 2e-5,  2e-4,
                2e-3,  2e-2,  2e-1,  2e0,   2e1,   2e2,   2e3,   2e4,
                -3e4,  -3e3,  -3e2,  -3e1,  -3e0,  -3e-1, -3e-2, -3e-3,
                -3e-4, -3e-5, 3e-5,  3e-4,  3e-3,  3e-2,  3e-1,  3e0,
            });
            try testArgs(@Vector(64, i32), @Vector(64, f64), .{
                3e1,   3e2,   3e3,   3e4,   -4e3,  -4e2,  -4e1,  -4e0,
                -4e-1, -4e-2, -4e-3, -4e-4, -4e-5, 4e-5,  4e-4,  4e-3,
                4e-2,  4e-1,  4e0,   4e1,   4e2,   4e3,   -5e3,  -5e2,
                -5e1,  -5e0,  -5e-1, -5e-2, -5e-3, -5e-4, -5e-5, 5e-5,
                5e-4,  5e-3,  5e-2,  5e-1,  5e0,   5e1,   5e2,   5e3,
                -6e3,  -6e2,  -6e1,  -6e0,  -6e-1, -6e-2, -6e-3, -6e-4,
                -6e-5, 6e-5,  6e-4,  6e-3,  6e-2,  6e-1,  6e0,   6e1,
                6e2,   6e3,   -7e3,  -7e2,  -7e1,  -7e0,  -7e-1, -7e-2,
            });
            try testArgs(@Vector(128, i32), @Vector(128, f64), .{
                -7e-3,  -7e-4,  -7e-5,  7e-5,   7e-4,   7e-3,   7e-2,   7e-1,
                7e0,    7e1,    7e2,    7e3,    -8e3,   -8e2,   -8e1,   -8e0,
                -8e-1,  -8e-2,  -8e-3,  -8e-4,  -8e-5,  8e-5,   8e-4,   8e-3,
                8e-2,   8e-1,   8e0,    8e1,    8e2,    8e3,    -9e3,   -9e2,
                -9e1,   -9e0,   -9e-1,  -9e-2,  -9e-3,  -9e-4,  -9e-5,  9e-5,
                9e-4,   9e-3,   9e-2,   9e-1,   9e0,    9e1,    9e2,    9e3,
                -11e3,  -11e2,  -11e1,  -11e0,  -11e-1, -11e-2, -11e-3, -11e-4,
                -11e-5, 11e-5,  11e-4,  11e-3,  11e-2,  11e-1,  11e0,   11e1,
                11e2,   11e3,   -12e3,  -12e2,  -12e1,  -12e0,  -12e-1, -12e-2,
                -12e-3, -12e-4, -12e-5, 12e-5,  12e-4,  12e-3,  12e-2,  12e-1,
                12e0,   12e1,   12e2,   12e3,   -13e3,  -13e2,  -13e1,  -13e0,
                -13e-1, -13e-2, -13e-3, -13e-4, -13e-5, 13e-5,  13e-4,  13e-3,
                13e-2,  13e-1,  13e0,   13e1,   13e2,   -14e2,  -14e1,  -14e0,
                -14e-1, -14e-2, -14e-3, -14e-4, -14e-5, 14e-5,  14e-4,  14e-3,
                14e-2,  14e-1,  14e0,   14e1,   14e2,   14e3,   -15e3,  -15e2,
                -15e1,  -15e0,  -15e-1, -15e-2, -15e-3, -15e-4, -15e-5, 15e-5,
            });

            try testArgs(@Vector(1, u32), @Vector(1, f64), .{
                -0.0,
            });
            try testArgs(@Vector(2, u32), @Vector(2, f64), .{
                0.0, 1e-5,
            });
            try testArgs(@Vector(4, u32), @Vector(4, f64), .{
                1e-4, 1e-3, 1e-2, 1e-1,
            });
            try testArgs(@Vector(8, u32), @Vector(8, f64), .{
                1e0, 1e1, 1e2, 1e3, 1e4, next(f64, next(f64, 0x1p32, 0.0), 0.0), next(f64, 0x1p32, 0.0), 2e-5,
            });
            try testArgs(@Vector(16, u32), @Vector(16, f64), .{
                2e-4, 2e-3, 2e-2, 2e-1, 2e0,  2e1,  2e2, 2e3,
                2e4,  3e-5, 3e-4, 3e-3, 3e-2, 3e-1, 3e0, 3e1,
            });
            try testArgs(@Vector(32, u32), @Vector(32, f64), .{
                3e2,  3e3,  3e4, 4e-5, 4e-4, 4e-3, 4e-2, 4e-1,
                4e0,  4e1,  4e2, 4e3,  5e-5, 5e-4, 5e-3, 5e-2,
                5e-1, 5e0,  5e1, 5e2,  5e3,  6e-5, 6e-4, 6e-3,
                6e-2, 6e-1, 6e0, 6e1,  6e2,  6e3,  7e-5, 7e-4,
            });
            try testArgs(@Vector(64, u32), @Vector(64, f64), .{
                7e-3,  7e-2,  7e-1,  7e0,   7e1,   7e2,   7e3,   8e-5,
                8e-4,  8e-3,  8e-2,  8e-1,  8e0,   8e1,   8e2,   8e3,
                9e-5,  9e-4,  9e-3,  9e-2,  9e-1,  9e0,   9e1,   9e2,
                9e3,   11e-5, 11e-4, 11e-3, 11e-2, 11e-1, 11e0,  11e1,
                11e2,  11e3,  13e-5, 13e-4, 13e-3, 13e-2, 13e-1, 13e0,
                13e1,  13e2,  13e3,  14e-5, 14e-4, 14e-3, 14e-2, 14e-1,
                14e0,  14e1,  14e2,  14e3,  15e-5, 15e-4, 15e-3, 15e-2,
                15e-1, 15e0,  15e1,  15e2,  15e3,  16e-5, 16e-4, 16e-3,
            });
            try testArgs(@Vector(128, u32), @Vector(128, f64), .{
                16e-2, 16e-1, 16e0,  16e1,  16e2,  16e3,  17e-5, 17e-4,
                17e-3, 17e-2, 17e-1, 17e0,  17e1,  17e2,  17e3,  18e-5,
                18e-4, 18e-3, 18e-2, 18e-1, 18e0,  18e1,  18e2,  18e3,
                19e-5, 19e-4, 19e-3, 19e-2, 19e-1, 19e0,  19e1,  19e2,
                19e3,  21e-5, 21e-4, 21e-3, 21e-2, 21e-1, 21e0,  21e1,
                21e2,  21e3,  22e-5, 22e-4, 22e-3, 22e-2, 22e-1, 22e0,
                22e1,  22e2,  22e3,  23e-5, 23e-4, 23e-3, 23e-2, 23e-1,
                23e0,  23e1,  23e2,  23e3,  24e-5, 24e-4, 24e-3, 24e-2,
                24e-1, 24e0,  24e1,  24e2,  24e3,  25e-5, 25e-4, 25e-3,
                25e-2, 25e-1, 25e0,  25e1,  25e2,  25e3,  26e-5, 26e-4,
                26e-3, 26e-2, 26e-1, 26e0,  26e1,  26e2,  26e3,  27e-5,
                27e-4, 27e-3, 27e-2, 27e-1, 27e0,  27e1,  27e2,  27e3,
                28e-5, 28e-4, 28e-3, 28e-2, 28e-1, 28e0,  28e1,  28e2,
                28e3,  29e-5, 29e-4, 29e-3, 29e-2, 29e-1, 29e0,  29e1,
                29e2,  29e3,  31e-5, 31e-4, 31e-3, 31e-2, 31e-1, 31e0,
                31e1,  31e2,  31e3,  32e-5, 32e-4, 32e-3, 32e-2, 32e-1,
            });

            try testArgs(@Vector(1, i64), @Vector(1, f64), .{
                -0x0.8p64,
            });
            try testArgs(@Vector(2, i64), @Vector(2, f64), .{
                next(f64, -0x0.8p64, -0.0), next(f64, next(f64, -0x0.8p64, -0.0), -0.0),
            });
            try testArgs(@Vector(4, i64), @Vector(4, f64), .{
                -1e4, -1e3, -1e2, -1e1,
            });
            try testArgs(@Vector(8, i64), @Vector(8, f64), .{
                -1e0, -1e-1, -1e-2, -1e-3, -1e-4, -1e-5, -0.0, 0.0,
            });
            try testArgs(@Vector(16, i64), @Vector(16, f64), .{
                1e-5, 1e-4, 1e-3,                                     1e-2,                     1e-1, 1e0,  1e1,  1e2,
                1e3,  1e4,  next(f64, next(f64, 0x0.8p64, 0.0), 0.0), next(f64, 0x0.8p64, 0.0), -2e4, -2e3, -2e2, -2e1,
            });
            try testArgs(@Vector(32, i64), @Vector(32, f64), .{
                -2e0,  -2e-1, -2e-2, -2e-3, -2e-4, -2e-5, 2e-5,  2e-4,
                2e-3,  2e-2,  2e-1,  2e0,   2e1,   2e2,   2e3,   2e4,
                -3e4,  -3e3,  -3e2,  -3e1,  -3e0,  -3e-1, -3e-2, -3e-3,
                -3e-4, -3e-5, 3e-5,  3e-4,  3e-3,  3e-2,  3e-1,  3e0,
            });
            try testArgs(@Vector(64, i64), @Vector(64, f64), .{
                3e1,   3e2,   3e3,   3e4,   -4e3,  -4e2,  -4e1,  -4e0,
                -4e-1, -4e-2, -4e-3, -4e-4, -4e-5, 4e-5,  4e-4,  4e-3,
                4e-2,  4e-1,  4e0,   4e1,   4e2,   4e3,   -5e3,  -5e2,
                -5e1,  -5e0,  -5e-1, -5e-2, -5e-3, -5e-4, -5e-5, 5e-5,
                5e-4,  5e-3,  5e-2,  5e-1,  5e0,   5e1,   5e2,   5e3,
                -6e3,  -6e2,  -6e1,  -6e0,  -6e-1, -6e-2, -6e-3, -6e-4,
                -6e-5, 6e-5,  6e-4,  6e-3,  6e-2,  6e-1,  6e0,   6e1,
                6e2,   6e3,   -7e3,  -7e2,  -7e1,  -7e0,  -7e-1, -7e-2,
            });
            try testArgs(@Vector(128, i64), @Vector(128, f64), .{
                -7e-3,  -7e-4,  -7e-5,  7e-5,   7e-4,   7e-3,   7e-2,   7e-1,
                7e0,    7e1,    7e2,    7e3,    -8e3,   -8e2,   -8e1,   -8e0,
                -8e-1,  -8e-2,  -8e-3,  -8e-4,  -8e-5,  8e-5,   8e-4,   8e-3,
                8e-2,   8e-1,   8e0,    8e1,    8e2,    8e3,    -9e3,   -9e2,
                -9e1,   -9e0,   -9e-1,  -9e-2,  -9e-3,  -9e-4,  -9e-5,  9e-5,
                9e-4,   9e-3,   9e-2,   9e-1,   9e0,    9e1,    9e2,    9e3,
                -11e3,  -11e2,  -11e1,  -11e0,  -11e-1, -11e-2, -11e-3, -11e-4,
                -11e-5, 11e-5,  11e-4,  11e-3,  11e-2,  11e-1,  11e0,   11e1,
                11e2,   11e3,   -12e3,  -12e2,  -12e1,  -12e0,  -12e-1, -12e-2,
                -12e-3, -12e-4, -12e-5, 12e-5,  12e-4,  12e-3,  12e-2,  12e-1,
                12e0,   12e1,   12e2,   12e3,   -13e3,  -13e2,  -13e1,  -13e0,
                -13e-1, -13e-2, -13e-3, -13e-4, -13e-5, 13e-5,  13e-4,  13e-3,
                13e-2,  13e-1,  13e0,   13e1,   13e2,   -14e2,  -14e1,  -14e0,
                -14e-1, -14e-2, -14e-3, -14e-4, -14e-5, 14e-5,  14e-4,  14e-3,
                14e-2,  14e-1,  14e0,   14e1,   14e2,   14e3,   -15e3,  -15e2,
                -15e1,  -15e0,  -15e-1, -15e-2, -15e-3, -15e-4, -15e-5, 15e-5,
            });

            try testArgs(@Vector(1, u64), @Vector(1, f64), .{
                -0.0,
            });
            try testArgs(@Vector(2, u64), @Vector(2, f64), .{
                0.0, 1e-5,
            });
            try testArgs(@Vector(4, u64), @Vector(4, f64), .{
                1e-4, 1e-3, 1e-2, 1e-1,
            });
            try testArgs(@Vector(8, u64), @Vector(8, f64), .{
                1e0, 1e1, 1e2, 1e3, 1e4, next(f64, next(f64, 0x1p64, 0.0), 0.0), next(f64, 0x1p64, 0.0), 2e-5,
            });
            try testArgs(@Vector(16, u64), @Vector(16, f64), .{
                2e-4, 2e-3, 2e-2, 2e-1, 2e0,  2e1,  2e2, 2e3,
                2e4,  3e-5, 3e-4, 3e-3, 3e-2, 3e-1, 3e0, 3e1,
            });
            try testArgs(@Vector(32, u64), @Vector(32, f64), .{
                3e2,  3e3,  3e4, 4e-5, 4e-4, 4e-3, 4e-2, 4e-1,
                4e0,  4e1,  4e2, 4e3,  5e-5, 5e-4, 5e-3, 5e-2,
                5e-1, 5e0,  5e1, 5e2,  5e3,  6e-5, 6e-4, 6e-3,
                6e-2, 6e-1, 6e0, 6e1,  6e2,  6e3,  7e-5, 7e-4,
            });
            try testArgs(@Vector(64, u64), @Vector(64, f64), .{
                7e-3,  7e-2,  7e-1,  7e0,   7e1,   7e2,   7e3,   8e-5,
                8e-4,  8e-3,  8e-2,  8e-1,  8e0,   8e1,   8e2,   8e3,
                9e-5,  9e-4,  9e-3,  9e-2,  9e-1,  9e0,   9e1,   9e2,
                9e3,   11e-5, 11e-4, 11e-3, 11e-2, 11e-1, 11e0,  11e1,
                11e2,  11e3,  13e-5, 13e-4, 13e-3, 13e-2, 13e-1, 13e0,
                13e1,  13e2,  13e3,  14e-5, 14e-4, 14e-3, 14e-2, 14e-1,
                14e0,  14e1,  14e2,  14e3,  15e-5, 15e-4, 15e-3, 15e-2,
                15e-1, 15e0,  15e1,  15e2,  15e3,  16e-5, 16e-4, 16e-3,
            });
            try testArgs(@Vector(128, u64), @Vector(128, f64), .{
                16e-2, 16e-1, 16e0,  16e1,  16e2,  16e3,  17e-5, 17e-4,
                17e-3, 17e-2, 17e-1, 17e0,  17e1,  17e2,  17e3,  18e-5,
                18e-4, 18e-3, 18e-2, 18e-1, 18e0,  18e1,  18e2,  18e3,
                19e-5, 19e-4, 19e-3, 19e-2, 19e-1, 19e0,  19e1,  19e2,
                19e3,  21e-5, 21e-4, 21e-3, 21e-2, 21e-1, 21e0,  21e1,
                21e2,  21e3,  22e-5, 22e-4, 22e-3, 22e-2, 22e-1, 22e0,
                22e1,  22e2,  22e3,  23e-5, 23e-4, 23e-3, 23e-2, 23e-1,
                23e0,  23e1,  23e2,  23e3,  24e-5, 24e-4, 24e-3, 24e-2,
                24e-1, 24e0,  24e1,  24e2,  24e3,  25e-5, 25e-4, 25e-3,
                25e-2, 25e-1, 25e0,  25e1,  25e2,  25e3,  26e-5, 26e-4,
                26e-3, 26e-2, 26e-1, 26e0,  26e1,  26e2,  26e3,  27e-5,
                27e-4, 27e-3, 27e-2, 27e-1, 27e0,  27e1,  27e2,  27e3,
                28e-5, 28e-4, 28e-3, 28e-2, 28e-1, 28e0,  28e1,  28e2,
                28e3,  29e-5, 29e-4, 29e-3, 29e-2, 29e-1, 29e0,  29e1,
                29e2,  29e3,  31e-5, 31e-4, 31e-3, 31e-2, 31e-1, 31e0,
                31e1,  31e2,  31e3,  32e-5, 32e-4, 32e-3, 32e-2, 32e-1,
            });

            try testArgs(@Vector(1, i128), @Vector(1, f64), .{
                -0x0.8p128,
            });
            try testArgs(@Vector(2, i128), @Vector(2, f64), .{
                next(f64, -0x0.8p128, -0.0), next(f64, next(f64, -0x0.8p128, -0.0), -0.0),
            });
            try testArgs(@Vector(4, i128), @Vector(4, f64), .{
                -1e4, -1e3, -1e2, -1e1,
            });
            try testArgs(@Vector(8, i128), @Vector(8, f64), .{
                -1e0, -1e-1, -1e-2, -1e-3, -1e-4, -1e-5, -0.0, 0.0,
            });
            try testArgs(@Vector(16, i128), @Vector(16, f64), .{
                1e-5, 1e-4, 1e-3,                                      1e-2,                      1e-1, 1e0,  1e1,  1e2,
                1e3,  1e4,  next(f64, next(f64, 0x0.8p128, 0.0), 0.0), next(f64, 0x0.8p128, 0.0), -2e4, -2e3, -2e2, -2e1,
            });
            try testArgs(@Vector(32, i128), @Vector(32, f64), .{
                -2e0,  -2e-1, -2e-2, -2e-3, -2e-4, -2e-5, 2e-5,  2e-4,
                2e-3,  2e-2,  2e-1,  2e0,   2e1,   2e2,   2e3,   2e4,
                -3e4,  -3e3,  -3e2,  -3e1,  -3e0,  -3e-1, -3e-2, -3e-3,
                -3e-4, -3e-5, 3e-5,  3e-4,  3e-3,  3e-2,  3e-1,  3e0,
            });
            try testArgs(@Vector(64, i128), @Vector(64, f64), .{
                3e1,   3e2,   3e3,   3e4,   -4e3,  -4e2,  -4e1,  -4e0,
                -4e-1, -4e-2, -4e-3, -4e-4, -4e-5, 4e-5,  4e-4,  4e-3,
                4e-2,  4e-1,  4e0,   4e1,   4e2,   4e3,   -5e3,  -5e2,
                -5e1,  -5e0,  -5e-1, -5e-2, -5e-3, -5e-4, -5e-5, 5e-5,
                5e-4,  5e-3,  5e-2,  5e-1,  5e0,   5e1,   5e2,   5e3,
                -6e3,  -6e2,  -6e1,  -6e0,  -6e-1, -6e-2, -6e-3, -6e-4,
                -6e-5, 6e-5,  6e-4,  6e-3,  6e-2,  6e-1,  6e0,   6e1,
                6e2,   6e3,   -7e3,  -7e2,  -7e1,  -7e0,  -7e-1, -7e-2,
            });

            try testArgs(@Vector(1, u128), @Vector(1, f64), .{
                -0.0,
            });
            try testArgs(@Vector(2, u128), @Vector(2, f64), .{
                0.0, 1e-5,
            });
            try testArgs(@Vector(4, u128), @Vector(4, f64), .{
                1e-4, 1e-3, 1e-2, 1e-1,
            });
            try testArgs(@Vector(8, u128), @Vector(8, f64), .{
                1e0, 1e1, 1e2, 1e3, 1e4, next(f64, next(f64, 0x1p128, 0.0), 0.0), next(f64, 0x1p128, 0.0), 2e-5,
            });
            try testArgs(@Vector(16, u128), @Vector(16, f64), .{
                2e-4, 2e-3, 2e-2, 2e-1, 2e0,  2e1,  2e2, 2e3,
                2e4,  3e-5, 3e-4, 3e-3, 3e-2, 3e-1, 3e0, 3e1,
            });
            try testArgs(@Vector(32, u128), @Vector(32, f64), .{
                3e2,  3e3,  3e4, 4e-5, 4e-4, 4e-3, 4e-2, 4e-1,
                4e0,  4e1,  4e2, 4e3,  5e-5, 5e-4, 5e-3, 5e-2,
                5e-1, 5e0,  5e1, 5e2,  5e3,  6e-5, 6e-4, 6e-3,
                6e-2, 6e-1, 6e0, 6e1,  6e2,  6e3,  7e-5, 7e-4,
            });
            try testArgs(@Vector(64, u128), @Vector(64, f64), .{
                7e-3,  7e-2,  7e-1,  7e0,   7e1,   7e2,   7e3,   8e-5,
                8e-4,  8e-3,  8e-2,  8e-1,  8e0,   8e1,   8e2,   8e3,
                9e-5,  9e-4,  9e-3,  9e-2,  9e-1,  9e0,   9e1,   9e2,
                9e3,   11e-5, 11e-4, 11e-3, 11e-2, 11e-1, 11e0,  11e1,
                11e2,  11e3,  13e-5, 13e-4, 13e-3, 13e-2, 13e-1, 13e0,
                13e1,  13e2,  13e3,  14e-5, 14e-4, 14e-3, 14e-2, 14e-1,
                14e0,  14e1,  14e2,  14e3,  15e-5, 15e-4, 15e-3, 15e-2,
                15e-1, 15e0,  15e1,  15e2,  15e3,  16e-5, 16e-4, 16e-3,
            });

            try testArgs(@Vector(1, i256), @Vector(1, f64), .{
                -0x0.8p256,
            });
            try testArgs(@Vector(2, i256), @Vector(2, f64), .{
                next(f64, -0x0.8p256, -0.0), next(f64, next(f64, -0x0.8p256, -0.0), -0.0),
            });
            try testArgs(@Vector(4, i256), @Vector(4, f64), .{
                -1e4, -1e3, -1e2, -1e1,
            });
            try testArgs(@Vector(8, i256), @Vector(8, f64), .{
                -1e0, -1e-1, -1e-2, -1e-3, -1e-4, -1e-5, -0.0, 0.0,
            });
            try testArgs(@Vector(16, i256), @Vector(16, f64), .{
                1e-5, 1e-4, 1e-3,                                      1e-2,                      1e-1, 1e0,  1e1,  1e2,
                1e3,  1e4,  next(f64, next(f64, 0x0.8p256, 0.0), 0.0), next(f64, 0x0.8p256, 0.0), -2e4, -2e3, -2e2, -2e1,
            });
            try testArgs(@Vector(32, i256), @Vector(32, f64), .{
                -2e0,  -2e-1, -2e-2, -2e-3, -2e-4, -2e-5, 2e-5,  2e-4,
                2e-3,  2e-2,  2e-1,  2e0,   2e1,   2e2,   2e3,   2e4,
                -3e4,  -3e3,  -3e2,  -3e1,  -3e0,  -3e-1, -3e-2, -3e-3,
                -3e-4, -3e-5, 3e-5,  3e-4,  3e-3,  3e-2,  3e-1,  3e0,
            });
            try testArgs(@Vector(64, i256), @Vector(64, f64), .{
                3e1,   3e2,   3e3,   3e4,   -4e3,  -4e2,  -4e1,  -4e0,
                -4e-1, -4e-2, -4e-3, -4e-4, -4e-5, 4e-5,  4e-4,  4e-3,
                4e-2,  4e-1,  4e0,   4e1,   4e2,   4e3,   -5e3,  -5e2,
                -5e1,  -5e0,  -5e-1, -5e-2, -5e-3, -5e-4, -5e-5, 5e-5,
                5e-4,  5e-3,  5e-2,  5e-1,  5e0,   5e1,   5e2,   5e3,
                -6e3,  -6e2,  -6e1,  -6e0,  -6e-1, -6e-2, -6e-3, -6e-4,
                -6e-5, 6e-5,  6e-4,  6e-3,  6e-2,  6e-1,  6e0,   6e1,
                6e2,   6e3,   -7e3,  -7e2,  -7e1,  -7e0,  -7e-1, -7e-2,
            });

            try testArgs(@Vector(1, u256), @Vector(1, f64), .{
                -0.0,
            });
            try testArgs(@Vector(2, u256), @Vector(2, f64), .{
                0.0, 1e-5,
            });
            try testArgs(@Vector(4, u256), @Vector(4, f64), .{
                1e-4, 1e-3, 1e-2, 1e-1,
            });
            try testArgs(@Vector(8, u256), @Vector(8, f64), .{
                1e0, 1e1, 1e2, 1e3, 1e4, next(f64, next(f64, 0x1p256, 0.0), 0.0), next(f64, 0x1p256, 0.0), 2e-5,
            });
            try testArgs(@Vector(16, u256), @Vector(16, f64), .{
                2e-4, 2e-3, 2e-2, 2e-1, 2e0,  2e1,  2e2, 2e3,
                2e4,  3e-5, 3e-4, 3e-3, 3e-2, 3e-1, 3e0, 3e1,
            });
            try testArgs(@Vector(32, u256), @Vector(32, f64), .{
                3e2,  3e3,  3e4, 4e-5, 4e-4, 4e-3, 4e-2, 4e-1,
                4e0,  4e1,  4e2, 4e3,  5e-5, 5e-4, 5e-3, 5e-2,
                5e-1, 5e0,  5e1, 5e2,  5e3,  6e-5, 6e-4, 6e-3,
                6e-2, 6e-1, 6e0, 6e1,  6e2,  6e3,  7e-5, 7e-4,
            });
            try testArgs(@Vector(64, u256), @Vector(64, f64), .{
                7e-3,  7e-2,  7e-1,  7e0,   7e1,   7e2,   7e3,   8e-5,
                8e-4,  8e-3,  8e-2,  8e-1,  8e0,   8e1,   8e2,   8e3,
                9e-5,  9e-4,  9e-3,  9e-2,  9e-1,  9e0,   9e1,   9e2,
                9e3,   11e-5, 11e-4, 11e-3, 11e-2, 11e-1, 11e0,  11e1,
                11e2,  11e3,  13e-5, 13e-4, 13e-3, 13e-2, 13e-1, 13e0,
                13e1,  13e2,  13e3,  14e-5, 14e-4, 14e-3, 14e-2, 14e-1,
                14e0,  14e1,  14e2,  14e3,  15e-5, 15e-4, 15e-3, 15e-2,
                15e-1, 15e0,  15e1,  15e2,  15e3,  16e-5, 16e-4, 16e-3,
            });

            try testArgs(@Vector(1, i8), @Vector(1, f80), .{
                -0x0.8p8,
            });
            try testArgs(@Vector(2, i8), @Vector(2, f80), .{
                next(f80, -0x0.8p8, -0.0), next(f80, next(f80, -0x0.8p8, -0.0), -0.0),
            });
            try testArgs(@Vector(4, i8), @Vector(4, f80), .{
                -1e2, -1e1, -1e0, -1e-1,
            });
            try testArgs(@Vector(8, i8), @Vector(8, f80), .{
                -1e-2, -1e-3, -1e-4, -1e-5, -0.0, 0.0, 1e-5, 1e-4,
            });
            try testArgs(@Vector(16, i8), @Vector(16, f80), .{
                1e-3, 1e-2, 1e-1,  1e0,   1e1,   1e2,   next(f80, next(f80, 0x0.8p8, 0.0), 0.0), next(f80, 0x0.8p8, 0.0),
                -2e1, -2e0, -2e-1, -2e-2, -2e-3, -2e-4, -2e-5,                                   2e-5,
            });
            try testArgs(@Vector(32, i8), @Vector(32, f80), .{
                2e-4,  2e-3,  2e-2,  2e-1,  2e0,   2e1,  -3e1,  -3e0,
                -3e-1, -3e-2, -3e-3, -3e-4, -3e-5, 3e-5, 3e-4,  3e-3,
                3e-2,  3e-1,  3e0,   3e1,   -4e1,  -4e0, -4e-1, -4e-2,
                -4e-3, -4e-4, -4e-5, 4e-5,  4e-4,  4e-3, 4e-2,  4e-1,
            });
            try testArgs(@Vector(64, i8), @Vector(64, f80), .{
                4e0,   4e1,   -5e1,  -5e0,  -5e-1, -5e-2, -5e-3, -5e-4,
                -5e-5, 5e-5,  5e-4,  5e-3,  5e-2,  5e-1,  5e0,   5e1,
                -6e1,  -6e0,  -6e-1, -6e-2, -6e-3, -6e-4, -6e-5, 6e-5,
                6e-4,  6e-3,  6e-2,  6e-1,  6e0,   6e1,   -7e1,  -7e0,
                -7e-1, -7e-2, -7e-3, -7e-4, -7e-5, 7e-5,  7e-4,  7e-3,
                7e-2,  7e-1,  7e0,   7e1,   -8e1,  -8e0,  -8e-1, -8e-2,
                -8e-3, -8e-4, -8e-5, 8e-5,  8e-4,  8e-3,  8e-2,  8e-1,
                8e0,   8e1,   -9e1,  -9e0,  -9e-1, -9e-2, -9e-3, -9e-4,
            });
            try testArgs(@Vector(128, i8), @Vector(128, f80), .{
                -9e-5,  9e-5,   9e-4,   9e-3,   9e-2,   9e-1,   9e0,    9e1,
                -11e1,  -11e0,  -11e-1, -11e-2, -11e-3, -11e-4, -11e-5, 11e-5,
                11e-4,  11e-3,  11e-2,  11e-1,  11e0,   11e1,   -12e1,  -12e0,
                -12e-1, -12e-2, -12e-3, -12e-4, -12e-5, 12e-5,  12e-4,  12e-3,
                12e-2,  12e-1,  12e0,   12e1,   -13e0,  -13e-1, -13e-2, -13e-3,
                -13e-4, -13e-5, 13e-5,  13e-4,  13e-3,  13e-2,  13e-1,  13e0,
                -14e0,  -14e-1, -14e-2, -14e-3, -14e-4, -14e-5, 14e-5,  14e-4,
                14e-3,  14e-2,  14e-1,  14e0,   -15e0,  -15e-1, -15e-2, -15e-3,
                -15e-4, -15e-5, 15e-5,  15e-4,  15e-3,  15e-2,  15e-1,  15e0,
                -16e0,  -16e-1, -16e-2, -16e-3, -16e-4, -16e-5, 16e-5,  16e-4,
                16e-3,  16e-2,  16e-1,  16e0,   -17e0,  -17e-1, -17e-2, -17e-3,
                -17e-4, -17e-5, 17e-5,  17e-4,  17e-3,  17e-2,  17e-1,  17e0,
                -18e0,  -18e-1, -18e-2, -18e-3, -18e-4, -18e-5, 18e-5,  18e-4,
                18e-3,  18e-2,  18e-1,  18e0,   -19e0,  -19e-1, -19e-2, -19e-3,
                -19e-4, -19e-5, 19e-5,  19e-4,  19e-3,  19e-2,  19e-1,  19e0,
                -21e0,  -21e-1, -21e-2, -21e-3, -21e-4, -21e-5, 21e-5,  21e-4,
            });

            try testArgs(@Vector(1, u8), @Vector(1, f80), .{
                -0.0,
            });
            try testArgs(@Vector(2, u8), @Vector(2, f80), .{
                0.0, 1e-5,
            });
            try testArgs(@Vector(4, u8), @Vector(4, f80), .{
                1e-4, 1e-3, 1e-2, 1e-1,
            });
            try testArgs(@Vector(8, u8), @Vector(8, f80), .{
                1e0, 1e1, 1e2, next(f80, next(f80, 0x1p8, 0.0), 0.0), next(f80, 0x1p8, 0.0), 2e-5, 2e-4, 2e-3,
            });
            try testArgs(@Vector(16, u8), @Vector(16, f80), .{
                2e-2, 2e-1, 2e0, 2e1, 2e2,  3e-5, 3e-4, 3e-3,
                3e-2, 3e-1, 3e0, 3e1, 4e-5, 4e-4, 4e-3, 4e-2,
            });
            try testArgs(@Vector(32, u8), @Vector(32, f80), .{
                4e-1, 4e0,  4e1,  5e-5, 5e-4, 5e-3, 5e-2, 5e-1,
                5e0,  5e1,  6e-5, 6e-4, 6e-3, 6e-2, 6e-1, 6e0,
                6e1,  7e-5, 7e-4, 7e-3, 7e-2, 7e-1, 7e0,  7e1,
                8e-5, 8e-4, 8e-3, 8e-2, 8e-1, 8e0,  8e1,  9e-5,
            });
            try testArgs(@Vector(64, u8), @Vector(64, f80), .{
                9e-4,  9e-3,  9e-2,  9e-1,  9e0,   9e1,   11e-5, 11e-4,
                11e-3, 11e-2, 11e-1, 11e0,  11e1,  13e-5, 13e-4, 13e-3,
                13e-2, 13e-1, 13e0,  14e-5, 14e-4, 14e-3, 14e-2, 14e-1,
                14e0,  14e1,  15e-5, 15e-4, 15e-3, 15e-2, 15e-1, 15e0,
                15e1,  16e-5, 16e-4, 16e-3, 16e-2, 16e-1, 16e0,  16e1,
                17e-5, 17e-4, 17e-3, 17e-2, 17e-1, 17e0,  17e1,  18e-5,
                18e-4, 18e-3, 18e-2, 18e-1, 18e0,  18e1,  19e-5, 19e-4,
                19e-3, 19e-2, 19e-1, 19e0,  19e1,  21e-5, 21e-4, 21e-3,
            });
            try testArgs(@Vector(128, u8), @Vector(128, f80), .{
                21e-2, 21e-1, 21e0,  21e1,  22e-5, 22e-4, 22e-3, 22e-2,
                22e-1, 22e0,  22e1,  23e-5, 23e-4, 23e-3, 23e-2, 23e-1,
                23e0,  23e1,  24e-5, 24e-4, 24e-3, 24e-2, 24e-1, 24e0,
                24e1,  25e-5, 25e-4, 25e-3, 25e-2, 25e-1, 25e0,  25e1,
                26e-5, 26e-4, 26e-3, 26e-2, 26e-1, 26e0,  27e-5, 27e-4,
                27e-3, 27e-2, 27e-1, 27e0,  28e-5, 28e-4, 28e-3, 28e-2,
                28e-1, 28e0,  29e-5, 29e-4, 29e-3, 29e-2, 29e-1, 29e0,
                31e-5, 31e-4, 31e-3, 31e-2, 31e-1, 31e0,  32e-5, 32e-4,
                32e-3, 32e-2, 32e-1, 32e0,  33e-5, 33e-4, 33e-3, 33e-2,
                33e-1, 33e0,  34e-5, 34e-4, 34e-3, 34e-2, 34e-1, 34e0,
                35e-5, 35e-4, 35e-3, 35e-2, 35e-1, 35e0,  36e-5, 36e-4,
                36e-3, 36e-2, 36e-1, 36e0,  37e-5, 37e-4, 37e-3, 37e-2,
                37e-1, 37e0,  38e-5, 38e-4, 38e-3, 38e-2, 38e-1, 38e0,
                39e-5, 39e-4, 39e-3, 39e-2, 39e-1, 39e0,  41e-5, 41e-4,
                41e-3, 41e-2, 41e-1, 41e0,  42e-5, 42e-4, 42e-3, 42e-2,
                42e-1, 42e0,  43e-5, 43e-4, 43e-3, 43e-2, 43e-1, 43e0,
            });

            try testArgs(@Vector(1, i16), @Vector(1, f80), .{
                -0x0.8p16,
            });
            try testArgs(@Vector(2, i16), @Vector(2, f80), .{
                next(f80, -0x0.8p16, -0.0), next(f80, next(f80, -0x0.8p16, -0.0), -0.0),
            });
            try testArgs(@Vector(4, i16), @Vector(4, f80), .{
                -1e4, -1e3, -1e2, -1e1,
            });
            try testArgs(@Vector(8, i16), @Vector(8, f80), .{
                -1e0, -1e-1, -1e-2, -1e-3, -1e-4, -1e-5, -0.0, 0.0,
            });
            try testArgs(@Vector(16, i16), @Vector(16, f80), .{
                1e-5, 1e-4, 1e-3,                                     1e-2,                     1e-1, 1e0,  1e1,  1e2,
                1e3,  1e4,  next(f80, next(f80, 0x0.8p16, 0.0), 0.0), next(f80, 0x0.8p16, 0.0), -2e4, -2e3, -2e2, -2e1,
            });
            try testArgs(@Vector(32, i16), @Vector(32, f80), .{
                -2e0,  -2e-1, -2e-2, -2e-3, -2e-4, -2e-5, 2e-5,  2e-4,
                2e-3,  2e-2,  2e-1,  2e0,   2e1,   2e2,   2e3,   2e4,
                -3e4,  -3e3,  -3e2,  -3e1,  -3e0,  -3e-1, -3e-2, -3e-3,
                -3e-4, -3e-5, 3e-5,  3e-4,  3e-3,  3e-2,  3e-1,  3e0,
            });
            try testArgs(@Vector(64, i16), @Vector(64, f80), .{
                3e1,   3e2,   3e3,   3e4,   -4e3,  -4e2,  -4e1,  -4e0,
                -4e-1, -4e-2, -4e-3, -4e-4, -4e-5, 4e-5,  4e-4,  4e-3,
                4e-2,  4e-1,  4e0,   4e1,   4e2,   4e3,   -5e3,  -5e2,
                -5e1,  -5e0,  -5e-1, -5e-2, -5e-3, -5e-4, -5e-5, 5e-5,
                5e-4,  5e-3,  5e-2,  5e-1,  5e0,   5e1,   5e2,   5e3,
                -6e3,  -6e2,  -6e1,  -6e0,  -6e-1, -6e-2, -6e-3, -6e-4,
                -6e-5, 6e-5,  6e-4,  6e-3,  6e-2,  6e-1,  6e0,   6e1,
                6e2,   6e3,   -7e3,  -7e2,  -7e1,  -7e0,  -7e-1, -7e-2,
            });
            try testArgs(@Vector(128, i16), @Vector(128, f80), .{
                -7e-3,  -7e-4,  -7e-5,  7e-5,   7e-4,   7e-3,   7e-2,   7e-1,
                7e0,    7e1,    7e2,    7e3,    -8e3,   -8e2,   -8e1,   -8e0,
                -8e-1,  -8e-2,  -8e-3,  -8e-4,  -8e-5,  8e-5,   8e-4,   8e-3,
                8e-2,   8e-1,   8e0,    8e1,    8e2,    8e3,    -9e3,   -9e2,
                -9e1,   -9e0,   -9e-1,  -9e-2,  -9e-3,  -9e-4,  -9e-5,  9e-5,
                9e-4,   9e-3,   9e-2,   9e-1,   9e0,    9e1,    9e2,    9e3,
                -11e3,  -11e2,  -11e1,  -11e0,  -11e-1, -11e-2, -11e-3, -11e-4,
                -11e-5, 11e-5,  11e-4,  11e-3,  11e-2,  11e-1,  11e0,   11e1,
                11e2,   11e3,   -12e3,  -12e2,  -12e1,  -12e0,  -12e-1, -12e-2,
                -12e-3, -12e-4, -12e-5, 12e-5,  12e-4,  12e-3,  12e-2,  12e-1,
                12e0,   12e1,   12e2,   12e3,   -13e3,  -13e2,  -13e1,  -13e0,
                -13e-1, -13e-2, -13e-3, -13e-4, -13e-5, 13e-5,  13e-4,  13e-3,
                13e-2,  13e-1,  13e0,   13e1,   13e2,   -14e2,  -14e1,  -14e0,
                -14e-1, -14e-2, -14e-3, -14e-4, -14e-5, 14e-5,  14e-4,  14e-3,
                14e-2,  14e-1,  14e0,   14e1,   14e2,   14e3,   -15e3,  -15e2,
                -15e1,  -15e0,  -15e-1, -15e-2, -15e-3, -15e-4, -15e-5, 15e-5,
            });

            try testArgs(@Vector(1, u16), @Vector(1, f80), .{
                -0.0,
            });
            try testArgs(@Vector(2, u16), @Vector(2, f80), .{
                0.0, 1e-5,
            });
            try testArgs(@Vector(4, u16), @Vector(4, f80), .{
                1e-4, 1e-3, 1e-2, 1e-1,
            });
            try testArgs(@Vector(8, u16), @Vector(8, f80), .{
                1e0, 1e1, 1e2, 1e3, 1e4, next(f80, next(f80, 0x1p16, 0.0), 0.0), next(f80, 0x1p16, 0.0), 2e-5,
            });
            try testArgs(@Vector(16, u16), @Vector(16, f80), .{
                2e-4, 2e-3, 2e-2, 2e-1, 2e0,  2e1,  2e2, 2e3,
                2e4,  3e-5, 3e-4, 3e-3, 3e-2, 3e-1, 3e0, 3e1,
            });
            try testArgs(@Vector(32, u16), @Vector(32, f80), .{
                3e2,  3e3,  3e4, 4e-5, 4e-4, 4e-3, 4e-2, 4e-1,
                4e0,  4e1,  4e2, 4e3,  5e-5, 5e-4, 5e-3, 5e-2,
                5e-1, 5e0,  5e1, 5e2,  5e3,  6e-5, 6e-4, 6e-3,
                6e-2, 6e-1, 6e0, 6e1,  6e2,  6e3,  7e-5, 7e-4,
            });
            try testArgs(@Vector(64, u16), @Vector(64, f80), .{
                7e-3,  7e-2,  7e-1,  7e0,   7e1,   7e2,   7e3,   8e-5,
                8e-4,  8e-3,  8e-2,  8e-1,  8e0,   8e1,   8e2,   8e3,
                9e-5,  9e-4,  9e-3,  9e-2,  9e-1,  9e0,   9e1,   9e2,
                9e3,   11e-5, 11e-4, 11e-3, 11e-2, 11e-1, 11e0,  11e1,
                11e2,  11e3,  13e-5, 13e-4, 13e-3, 13e-2, 13e-1, 13e0,
                13e1,  13e2,  13e3,  14e-5, 14e-4, 14e-3, 14e-2, 14e-1,
                14e0,  14e1,  14e2,  14e3,  15e-5, 15e-4, 15e-3, 15e-2,
                15e-1, 15e0,  15e1,  15e2,  15e3,  16e-5, 16e-4, 16e-3,
            });
            try testArgs(@Vector(128, u16), @Vector(128, f80), .{
                16e-2, 16e-1, 16e0,  16e1,  16e2,  16e3,  17e-5, 17e-4,
                17e-3, 17e-2, 17e-1, 17e0,  17e1,  17e2,  17e3,  18e-5,
                18e-4, 18e-3, 18e-2, 18e-1, 18e0,  18e1,  18e2,  18e3,
                19e-5, 19e-4, 19e-3, 19e-2, 19e-1, 19e0,  19e1,  19e2,
                19e3,  21e-5, 21e-4, 21e-3, 21e-2, 21e-1, 21e0,  21e1,
                21e2,  21e3,  22e-5, 22e-4, 22e-3, 22e-2, 22e-1, 22e0,
                22e1,  22e2,  22e3,  23e-5, 23e-4, 23e-3, 23e-2, 23e-1,
                23e0,  23e1,  23e2,  23e3,  24e-5, 24e-4, 24e-3, 24e-2,
                24e-1, 24e0,  24e1,  24e2,  24e3,  25e-5, 25e-4, 25e-3,
                25e-2, 25e-1, 25e0,  25e1,  25e2,  25e3,  26e-5, 26e-4,
                26e-3, 26e-2, 26e-1, 26e0,  26e1,  26e2,  26e3,  27e-5,
                27e-4, 27e-3, 27e-2, 27e-1, 27e0,  27e1,  27e2,  27e3,
                28e-5, 28e-4, 28e-3, 28e-2, 28e-1, 28e0,  28e1,  28e2,
                28e3,  29e-5, 29e-4, 29e-3, 29e-2, 29e-1, 29e0,  29e1,
                29e2,  29e3,  31e-5, 31e-4, 31e-3, 31e-2, 31e-1, 31e0,
                31e1,  31e2,  31e3,  32e-5, 32e-4, 32e-3, 32e-2, 32e-1,
            });

            try testArgs(@Vector(1, i32), @Vector(1, f80), .{
                -0x0.8p32,
            });
            try testArgs(@Vector(2, i32), @Vector(2, f80), .{
                next(f80, -0x0.8p32, -0.0), next(f80, next(f80, -0x0.8p32, -0.0), -0.0),
            });
            try testArgs(@Vector(4, i32), @Vector(4, f80), .{
                -1e4, -1e3, -1e2, -1e1,
            });
            try testArgs(@Vector(8, i32), @Vector(8, f80), .{
                -1e0, -1e-1, -1e-2, -1e-3, -1e-4, -1e-5, -0.0, 0.0,
            });
            try testArgs(@Vector(16, i32), @Vector(16, f80), .{
                1e-5, 1e-4, 1e-3,                                     1e-2,                     1e-1, 1e0,  1e1,  1e2,
                1e3,  1e4,  next(f80, next(f80, 0x0.8p32, 0.0), 0.0), next(f80, 0x0.8p32, 0.0), -2e4, -2e3, -2e2, -2e1,
            });
            try testArgs(@Vector(32, i32), @Vector(32, f80), .{
                -2e0,  -2e-1, -2e-2, -2e-3, -2e-4, -2e-5, 2e-5,  2e-4,
                2e-3,  2e-2,  2e-1,  2e0,   2e1,   2e2,   2e3,   2e4,
                -3e4,  -3e3,  -3e2,  -3e1,  -3e0,  -3e-1, -3e-2, -3e-3,
                -3e-4, -3e-5, 3e-5,  3e-4,  3e-3,  3e-2,  3e-1,  3e0,
            });
            try testArgs(@Vector(64, i32), @Vector(64, f80), .{
                3e1,   3e2,   3e3,   3e4,   -4e3,  -4e2,  -4e1,  -4e0,
                -4e-1, -4e-2, -4e-3, -4e-4, -4e-5, 4e-5,  4e-4,  4e-3,
                4e-2,  4e-1,  4e0,   4e1,   4e2,   4e3,   -5e3,  -5e2,
                -5e1,  -5e0,  -5e-1, -5e-2, -5e-3, -5e-4, -5e-5, 5e-5,
                5e-4,  5e-3,  5e-2,  5e-1,  5e0,   5e1,   5e2,   5e3,
                -6e3,  -6e2,  -6e1,  -6e0,  -6e-1, -6e-2, -6e-3, -6e-4,
                -6e-5, 6e-5,  6e-4,  6e-3,  6e-2,  6e-1,  6e0,   6e1,
                6e2,   6e3,   -7e3,  -7e2,  -7e1,  -7e0,  -7e-1, -7e-2,
            });
            try testArgs(@Vector(128, i32), @Vector(128, f80), .{
                -7e-3,  -7e-4,  -7e-5,  7e-5,   7e-4,   7e-3,   7e-2,   7e-1,
                7e0,    7e1,    7e2,    7e3,    -8e3,   -8e2,   -8e1,   -8e0,
                -8e-1,  -8e-2,  -8e-3,  -8e-4,  -8e-5,  8e-5,   8e-4,   8e-3,
                8e-2,   8e-1,   8e0,    8e1,    8e2,    8e3,    -9e3,   -9e2,
                -9e1,   -9e0,   -9e-1,  -9e-2,  -9e-3,  -9e-4,  -9e-5,  9e-5,
                9e-4,   9e-3,   9e-2,   9e-1,   9e0,    9e1,    9e2,    9e3,
                -11e3,  -11e2,  -11e1,  -11e0,  -11e-1, -11e-2, -11e-3, -11e-4,
                -11e-5, 11e-5,  11e-4,  11e-3,  11e-2,  11e-1,  11e0,   11e1,
                11e2,   11e3,   -12e3,  -12e2,  -12e1,  -12e0,  -12e-1, -12e-2,
                -12e-3, -12e-4, -12e-5, 12e-5,  12e-4,  12e-3,  12e-2,  12e-1,
                12e0,   12e1,   12e2,   12e3,   -13e3,  -13e2,  -13e1,  -13e0,
                -13e-1, -13e-2, -13e-3, -13e-4, -13e-5, 13e-5,  13e-4,  13e-3,
                13e-2,  13e-1,  13e0,   13e1,   13e2,   -14e2,  -14e1,  -14e0,
                -14e-1, -14e-2, -14e-3, -14e-4, -14e-5, 14e-5,  14e-4,  14e-3,
                14e-2,  14e-1,  14e0,   14e1,   14e2,   14e3,   -15e3,  -15e2,
                -15e1,  -15e0,  -15e-1, -15e-2, -15e-3, -15e-4, -15e-5, 15e-5,
            });

            try testArgs(@Vector(1, u32), @Vector(1, f80), .{
                -0.0,
            });
            try testArgs(@Vector(2, u32), @Vector(2, f80), .{
                0.0, 1e-5,
            });
            try testArgs(@Vector(4, u32), @Vector(4, f80), .{
                1e-4, 1e-3, 1e-2, 1e-1,
            });
            try testArgs(@Vector(8, u32), @Vector(8, f80), .{
                1e0, 1e1, 1e2, 1e3, 1e4, next(f80, next(f80, 0x1p32, 0.0), 0.0), next(f80, 0x1p32, 0.0), 2e-5,
            });
            try testArgs(@Vector(16, u32), @Vector(16, f80), .{
                2e-4, 2e-3, 2e-2, 2e-1, 2e0,  2e1,  2e2, 2e3,
                2e4,  3e-5, 3e-4, 3e-3, 3e-2, 3e-1, 3e0, 3e1,
            });
            try testArgs(@Vector(32, u32), @Vector(32, f80), .{
                3e2,  3e3,  3e4, 4e-5, 4e-4, 4e-3, 4e-2, 4e-1,
                4e0,  4e1,  4e2, 4e3,  5e-5, 5e-4, 5e-3, 5e-2,
                5e-1, 5e0,  5e1, 5e2,  5e3,  6e-5, 6e-4, 6e-3,
                6e-2, 6e-1, 6e0, 6e1,  6e2,  6e3,  7e-5, 7e-4,
            });
            try testArgs(@Vector(64, u32), @Vector(64, f80), .{
                7e-3,  7e-2,  7e-1,  7e0,   7e1,   7e2,   7e3,   8e-5,
                8e-4,  8e-3,  8e-2,  8e-1,  8e0,   8e1,   8e2,   8e3,
                9e-5,  9e-4,  9e-3,  9e-2,  9e-1,  9e0,   9e1,   9e2,
                9e3,   11e-5, 11e-4, 11e-3, 11e-2, 11e-1, 11e0,  11e1,
                11e2,  11e3,  13e-5, 13e-4, 13e-3, 13e-2, 13e-1, 13e0,
                13e1,  13e2,  13e3,  14e-5, 14e-4, 14e-3, 14e-2, 14e-1,
                14e0,  14e1,  14e2,  14e3,  15e-5, 15e-4, 15e-3, 15e-2,
                15e-1, 15e0,  15e1,  15e2,  15e3,  16e-5, 16e-4, 16e-3,
            });
            try testArgs(@Vector(128, u32), @Vector(128, f80), .{
                16e-2, 16e-1, 16e0,  16e1,  16e2,  16e3,  17e-5, 17e-4,
                17e-3, 17e-2, 17e-1, 17e0,  17e1,  17e2,  17e3,  18e-5,
                18e-4, 18e-3, 18e-2, 18e-1, 18e0,  18e1,  18e2,  18e3,
                19e-5, 19e-4, 19e-3, 19e-2, 19e-1, 19e0,  19e1,  19e2,
                19e3,  21e-5, 21e-4, 21e-3, 21e-2, 21e-1, 21e0,  21e1,
                21e2,  21e3,  22e-5, 22e-4, 22e-3, 22e-2, 22e-1, 22e0,
                22e1,  22e2,  22e3,  23e-5, 23e-4, 23e-3, 23e-2, 23e-1,
                23e0,  23e1,  23e2,  23e3,  24e-5, 24e-4, 24e-3, 24e-2,
                24e-1, 24e0,  24e1,  24e2,  24e3,  25e-5, 25e-4, 25e-3,
                25e-2, 25e-1, 25e0,  25e1,  25e2,  25e3,  26e-5, 26e-4,
                26e-3, 26e-2, 26e-1, 26e0,  26e1,  26e2,  26e3,  27e-5,
                27e-4, 27e-3, 27e-2, 27e-1, 27e0,  27e1,  27e2,  27e3,
                28e-5, 28e-4, 28e-3, 28e-2, 28e-1, 28e0,  28e1,  28e2,
                28e3,  29e-5, 29e-4, 29e-3, 29e-2, 29e-1, 29e0,  29e1,
                29e2,  29e3,  31e-5, 31e-4, 31e-3, 31e-2, 31e-1, 31e0,
                31e1,  31e2,  31e3,  32e-5, 32e-4, 32e-3, 32e-2, 32e-1,
            });

            try testArgs(@Vector(1, i64), @Vector(1, f80), .{
                -0x0.8p64,
            });
            try testArgs(@Vector(2, i64), @Vector(2, f80), .{
                next(f80, -0x0.8p64, -0.0), next(f80, next(f80, -0x0.8p64, -0.0), -0.0),
            });
            try testArgs(@Vector(4, i64), @Vector(4, f80), .{
                -1e4, -1e3, -1e2, -1e1,
            });
            try testArgs(@Vector(8, i64), @Vector(8, f80), .{
                -1e0, -1e-1, -1e-2, -1e-3, -1e-4, -1e-5, -0.0, 0.0,
            });
            try testArgs(@Vector(16, i64), @Vector(16, f80), .{
                1e-5, 1e-4, 1e-3,                                     1e-2,                     1e-1, 1e0,  1e1,  1e2,
                1e3,  1e4,  next(f80, next(f80, 0x0.8p64, 0.0), 0.0), next(f80, 0x0.8p64, 0.0), -2e4, -2e3, -2e2, -2e1,
            });
            try testArgs(@Vector(32, i64), @Vector(32, f80), .{
                -2e0,  -2e-1, -2e-2, -2e-3, -2e-4, -2e-5, 2e-5,  2e-4,
                2e-3,  2e-2,  2e-1,  2e0,   2e1,   2e2,   2e3,   2e4,
                -3e4,  -3e3,  -3e2,  -3e1,  -3e0,  -3e-1, -3e-2, -3e-3,
                -3e-4, -3e-5, 3e-5,  3e-4,  3e-3,  3e-2,  3e-1,  3e0,
            });
            try testArgs(@Vector(64, i64), @Vector(64, f80), .{
                3e1,   3e2,   3e3,   3e4,   -4e3,  -4e2,  -4e1,  -4e0,
                -4e-1, -4e-2, -4e-3, -4e-4, -4e-5, 4e-5,  4e-4,  4e-3,
                4e-2,  4e-1,  4e0,   4e1,   4e2,   4e3,   -5e3,  -5e2,
                -5e1,  -5e0,  -5e-1, -5e-2, -5e-3, -5e-4, -5e-5, 5e-5,
                5e-4,  5e-3,  5e-2,  5e-1,  5e0,   5e1,   5e2,   5e3,
                -6e3,  -6e2,  -6e1,  -6e0,  -6e-1, -6e-2, -6e-3, -6e-4,
                -6e-5, 6e-5,  6e-4,  6e-3,  6e-2,  6e-1,  6e0,   6e1,
                6e2,   6e3,   -7e3,  -7e2,  -7e1,  -7e0,  -7e-1, -7e-2,
            });
            try testArgs(@Vector(128, i64), @Vector(128, f80), .{
                -7e-3,  -7e-4,  -7e-5,  7e-5,   7e-4,   7e-3,   7e-2,   7e-1,
                7e0,    7e1,    7e2,    7e3,    -8e3,   -8e2,   -8e1,   -8e0,
                -8e-1,  -8e-2,  -8e-3,  -8e-4,  -8e-5,  8e-5,   8e-4,   8e-3,
                8e-2,   8e-1,   8e0,    8e1,    8e2,    8e3,    -9e3,   -9e2,
                -9e1,   -9e0,   -9e-1,  -9e-2,  -9e-3,  -9e-4,  -9e-5,  9e-5,
                9e-4,   9e-3,   9e-2,   9e-1,   9e0,    9e1,    9e2,    9e3,
                -11e3,  -11e2,  -11e1,  -11e0,  -11e-1, -11e-2, -11e-3, -11e-4,
                -11e-5, 11e-5,  11e-4,  11e-3,  11e-2,  11e-1,  11e0,   11e1,
                11e2,   11e3,   -12e3,  -12e2,  -12e1,  -12e0,  -12e-1, -12e-2,
                -12e-3, -12e-4, -12e-5, 12e-5,  12e-4,  12e-3,  12e-2,  12e-1,
                12e0,   12e1,   12e2,   12e3,   -13e3,  -13e2,  -13e1,  -13e0,
                -13e-1, -13e-2, -13e-3, -13e-4, -13e-5, 13e-5,  13e-4,  13e-3,
                13e-2,  13e-1,  13e0,   13e1,   13e2,   -14e2,  -14e1,  -14e0,
                -14e-1, -14e-2, -14e-3, -14e-4, -14e-5, 14e-5,  14e-4,  14e-3,
                14e-2,  14e-1,  14e0,   14e1,   14e2,   14e3,   -15e3,  -15e2,
                -15e1,  -15e0,  -15e-1, -15e-2, -15e-3, -15e-4, -15e-5, 15e-5,
            });

            try testArgs(@Vector(1, u64), @Vector(1, f80), .{
                -0.0,
            });
            try testArgs(@Vector(2, u64), @Vector(2, f80), .{
                0.0, 1e-5,
            });
            try testArgs(@Vector(4, u64), @Vector(4, f80), .{
                1e-4, 1e-3, 1e-2, 1e-1,
            });
            try testArgs(@Vector(8, u64), @Vector(8, f80), .{
                1e0, 1e1, 1e2, 1e3, 1e4, next(f80, next(f80, 0x1p64, 0.0), 0.0), next(f80, 0x1p64, 0.0), 2e-5,
            });
            try testArgs(@Vector(16, u64), @Vector(16, f80), .{
                2e-4, 2e-3, 2e-2, 2e-1, 2e0,  2e1,  2e2, 2e3,
                2e4,  3e-5, 3e-4, 3e-3, 3e-2, 3e-1, 3e0, 3e1,
            });
            try testArgs(@Vector(32, u64), @Vector(32, f80), .{
                3e2,  3e3,  3e4, 4e-5, 4e-4, 4e-3, 4e-2, 4e-1,
                4e0,  4e1,  4e2, 4e3,  5e-5, 5e-4, 5e-3, 5e-2,
                5e-1, 5e0,  5e1, 5e2,  5e3,  6e-5, 6e-4, 6e-3,
                6e-2, 6e-1, 6e0, 6e1,  6e2,  6e3,  7e-5, 7e-4,
            });
            try testArgs(@Vector(64, u64), @Vector(64, f80), .{
                7e-3,  7e-2,  7e-1,  7e0,   7e1,   7e2,   7e3,   8e-5,
                8e-4,  8e-3,  8e-2,  8e-1,  8e0,   8e1,   8e2,   8e3,
                9e-5,  9e-4,  9e-3,  9e-2,  9e-1,  9e0,   9e1,   9e2,
                9e3,   11e-5, 11e-4, 11e-3, 11e-2, 11e-1, 11e0,  11e1,
                11e2,  11e3,  13e-5, 13e-4, 13e-3, 13e-2, 13e-1, 13e0,
                13e1,  13e2,  13e3,  14e-5, 14e-4, 14e-3, 14e-2, 14e-1,
                14e0,  14e1,  14e2,  14e3,  15e-5, 15e-4, 15e-3, 15e-2,
                15e-1, 15e0,  15e1,  15e2,  15e3,  16e-5, 16e-4, 16e-3,
            });
            try testArgs(@Vector(128, u64), @Vector(128, f80), .{
                16e-2, 16e-1, 16e0,  16e1,  16e2,  16e3,  17e-5, 17e-4,
                17e-3, 17e-2, 17e-1, 17e0,  17e1,  17e2,  17e3,  18e-5,
                18e-4, 18e-3, 18e-2, 18e-1, 18e0,  18e1,  18e2,  18e3,
                19e-5, 19e-4, 19e-3, 19e-2, 19e-1, 19e0,  19e1,  19e2,
                19e3,  21e-5, 21e-4, 21e-3, 21e-2, 21e-1, 21e0,  21e1,
                21e2,  21e3,  22e-5, 22e-4, 22e-3, 22e-2, 22e-1, 22e0,
                22e1,  22e2,  22e3,  23e-5, 23e-4, 23e-3, 23e-2, 23e-1,
                23e0,  23e1,  23e2,  23e3,  24e-5, 24e-4, 24e-3, 24e-2,
                24e-1, 24e0,  24e1,  24e2,  24e3,  25e-5, 25e-4, 25e-3,
                25e-2, 25e-1, 25e0,  25e1,  25e2,  25e3,  26e-5, 26e-4,
                26e-3, 26e-2, 26e-1, 26e0,  26e1,  26e2,  26e3,  27e-5,
                27e-4, 27e-3, 27e-2, 27e-1, 27e0,  27e1,  27e2,  27e3,
                28e-5, 28e-4, 28e-3, 28e-2, 28e-1, 28e0,  28e1,  28e2,
                28e3,  29e-5, 29e-4, 29e-3, 29e-2, 29e-1, 29e0,  29e1,
                29e2,  29e3,  31e-5, 31e-4, 31e-3, 31e-2, 31e-1, 31e0,
                31e1,  31e2,  31e3,  32e-5, 32e-4, 32e-3, 32e-2, 32e-1,
            });

            try testArgs(@Vector(1, i128), @Vector(1, f80), .{
                -0x0.8p128,
            });
            try testArgs(@Vector(2, i128), @Vector(2, f80), .{
                next(f80, -0x0.8p128, -0.0), next(f80, next(f80, -0x0.8p128, -0.0), -0.0),
            });
            try testArgs(@Vector(4, i128), @Vector(4, f80), .{
                -1e4, -1e3, -1e2, -1e1,
            });
            try testArgs(@Vector(8, i128), @Vector(8, f80), .{
                -1e0, -1e-1, -1e-2, -1e-3, -1e-4, -1e-5, -0.0, 0.0,
            });
            try testArgs(@Vector(16, i128), @Vector(16, f80), .{
                1e-5, 1e-4, 1e-3,                                      1e-2,                      1e-1, 1e0,  1e1,  1e2,
                1e3,  1e4,  next(f80, next(f80, 0x0.8p128, 0.0), 0.0), next(f80, 0x0.8p128, 0.0), -2e4, -2e3, -2e2, -2e1,
            });
            try testArgs(@Vector(32, i128), @Vector(32, f80), .{
                -2e0,  -2e-1, -2e-2, -2e-3, -2e-4, -2e-5, 2e-5,  2e-4,
                2e-3,  2e-2,  2e-1,  2e0,   2e1,   2e2,   2e3,   2e4,
                -3e4,  -3e3,  -3e2,  -3e1,  -3e0,  -3e-1, -3e-2, -3e-3,
                -3e-4, -3e-5, 3e-5,  3e-4,  3e-3,  3e-2,  3e-1,  3e0,
            });
            try testArgs(@Vector(64, i128), @Vector(64, f80), .{
                3e1,   3e2,   3e3,   3e4,   -4e3,  -4e2,  -4e1,  -4e0,
                -4e-1, -4e-2, -4e-3, -4e-4, -4e-5, 4e-5,  4e-4,  4e-3,
                4e-2,  4e-1,  4e0,   4e1,   4e2,   4e3,   -5e3,  -5e2,
                -5e1,  -5e0,  -5e-1, -5e-2, -5e-3, -5e-4, -5e-5, 5e-5,
                5e-4,  5e-3,  5e-2,  5e-1,  5e0,   5e1,   5e2,   5e3,
                -6e3,  -6e2,  -6e1,  -6e0,  -6e-1, -6e-2, -6e-3, -6e-4,
                -6e-5, 6e-5,  6e-4,  6e-3,  6e-2,  6e-1,  6e0,   6e1,
                6e2,   6e3,   -7e3,  -7e2,  -7e1,  -7e0,  -7e-1, -7e-2,
            });

            try testArgs(@Vector(1, u128), @Vector(1, f80), .{
                -0.0,
            });
            try testArgs(@Vector(2, u128), @Vector(2, f80), .{
                0.0, 1e-5,
            });
            try testArgs(@Vector(4, u128), @Vector(4, f80), .{
                1e-4, 1e-3, 1e-2, 1e-1,
            });
            try testArgs(@Vector(8, u128), @Vector(8, f80), .{
                1e0, 1e1, 1e2, 1e3, 1e4, next(f80, next(f80, 0x1p128, 0.0), 0.0), next(f80, 0x1p128, 0.0), 2e-5,
            });
            try testArgs(@Vector(16, u128), @Vector(16, f80), .{
                2e-4, 2e-3, 2e-2, 2e-1, 2e0,  2e1,  2e2, 2e3,
                2e4,  3e-5, 3e-4, 3e-3, 3e-2, 3e-1, 3e0, 3e1,
            });
            try testArgs(@Vector(32, u128), @Vector(32, f80), .{
                3e2,  3e3,  3e4, 4e-5, 4e-4, 4e-3, 4e-2, 4e-1,
                4e0,  4e1,  4e2, 4e3,  5e-5, 5e-4, 5e-3, 5e-2,
                5e-1, 5e0,  5e1, 5e2,  5e3,  6e-5, 6e-4, 6e-3,
                6e-2, 6e-1, 6e0, 6e1,  6e2,  6e3,  7e-5, 7e-4,
            });
            try testArgs(@Vector(64, u128), @Vector(64, f80), .{
                7e-3,  7e-2,  7e-1,  7e0,   7e1,   7e2,   7e3,   8e-5,
                8e-4,  8e-3,  8e-2,  8e-1,  8e0,   8e1,   8e2,   8e3,
                9e-5,  9e-4,  9e-3,  9e-2,  9e-1,  9e0,   9e1,   9e2,
                9e3,   11e-5, 11e-4, 11e-3, 11e-2, 11e-1, 11e0,  11e1,
                11e2,  11e3,  13e-5, 13e-4, 13e-3, 13e-2, 13e-1, 13e0,
                13e1,  13e2,  13e3,  14e-5, 14e-4, 14e-3, 14e-2, 14e-1,
                14e0,  14e1,  14e2,  14e3,  15e-5, 15e-4, 15e-3, 15e-2,
                15e-1, 15e0,  15e1,  15e2,  15e3,  16e-5, 16e-4, 16e-3,
            });

            try testArgs(@Vector(1, i256), @Vector(1, f80), .{
                -0x0.8p256,
            });
            try testArgs(@Vector(2, i256), @Vector(2, f80), .{
                next(f80, -0x0.8p256, -0.0), next(f80, next(f80, -0x0.8p256, -0.0), -0.0),
            });
            try testArgs(@Vector(4, i256), @Vector(4, f80), .{
                -1e4, -1e3, -1e2, -1e1,
            });
            try testArgs(@Vector(8, i256), @Vector(8, f80), .{
                -1e0, -1e-1, -1e-2, -1e-3, -1e-4, -1e-5, -0.0, 0.0,
            });
            try testArgs(@Vector(16, i256), @Vector(16, f80), .{
                1e-5, 1e-4, 1e-3,                                      1e-2,                      1e-1, 1e0,  1e1,  1e2,
                1e3,  1e4,  next(f80, next(f80, 0x0.8p256, 0.0), 0.0), next(f80, 0x0.8p256, 0.0), -2e4, -2e3, -2e2, -2e1,
            });
            try testArgs(@Vector(32, i256), @Vector(32, f80), .{
                -2e0,  -2e-1, -2e-2, -2e-3, -2e-4, -2e-5, 2e-5,  2e-4,
                2e-3,  2e-2,  2e-1,  2e0,   2e1,   2e2,   2e3,   2e4,
                -3e4,  -3e3,  -3e2,  -3e1,  -3e0,  -3e-1, -3e-2, -3e-3,
                -3e-4, -3e-5, 3e-5,  3e-4,  3e-3,  3e-2,  3e-1,  3e0,
            });
            try testArgs(@Vector(64, i256), @Vector(64, f80), .{
                3e1,   3e2,   3e3,   3e4,   -4e3,  -4e2,  -4e1,  -4e0,
                -4e-1, -4e-2, -4e-3, -4e-4, -4e-5, 4e-5,  4e-4,  4e-3,
                4e-2,  4e-1,  4e0,   4e1,   4e2,   4e3,   -5e3,  -5e2,
                -5e1,  -5e0,  -5e-1, -5e-2, -5e-3, -5e-4, -5e-5, 5e-5,
                5e-4,  5e-3,  5e-2,  5e-1,  5e0,   5e1,   5e2,   5e3,
                -6e3,  -6e2,  -6e1,  -6e0,  -6e-1, -6e-2, -6e-3, -6e-4,
                -6e-5, 6e-5,  6e-4,  6e-3,  6e-2,  6e-1,  6e0,   6e1,
                6e2,   6e3,   -7e3,  -7e2,  -7e1,  -7e0,  -7e-1, -7e-2,
            });

            try testArgs(@Vector(1, u256), @Vector(1, f80), .{
                -0.0,
            });
            try testArgs(@Vector(2, u256), @Vector(2, f80), .{
                0.0, 1e-5,
            });
            try testArgs(@Vector(4, u256), @Vector(4, f80), .{
                1e-4, 1e-3, 1e-2, 1e-1,
            });
            try testArgs(@Vector(8, u256), @Vector(8, f80), .{
                1e0, 1e1, 1e2, 1e3, 1e4, next(f80, next(f80, 0x1p256, 0.0), 0.0), next(f80, 0x1p256, 0.0), 2e-5,
            });
            try testArgs(@Vector(16, u256), @Vector(16, f80), .{
                2e-4, 2e-3, 2e-2, 2e-1, 2e0,  2e1,  2e2, 2e3,
                2e4,  3e-5, 3e-4, 3e-3, 3e-2, 3e-1, 3e0, 3e1,
            });
            try testArgs(@Vector(32, u256), @Vector(32, f80), .{
                3e2,  3e3,  3e4, 4e-5, 4e-4, 4e-3, 4e-2, 4e-1,
                4e0,  4e1,  4e2, 4e3,  5e-5, 5e-4, 5e-3, 5e-2,
                5e-1, 5e0,  5e1, 5e2,  5e3,  6e-5, 6e-4, 6e-3,
                6e-2, 6e-1, 6e0, 6e1,  6e2,  6e3,  7e-5, 7e-4,
            });
            try testArgs(@Vector(64, u256), @Vector(64, f80), .{
                7e-3,  7e-2,  7e-1,  7e0,   7e1,   7e2,   7e3,   8e-5,
                8e-4,  8e-3,  8e-2,  8e-1,  8e0,   8e1,   8e2,   8e3,
                9e-5,  9e-4,  9e-3,  9e-2,  9e-1,  9e0,   9e1,   9e2,
                9e3,   11e-5, 11e-4, 11e-3, 11e-2, 11e-1, 11e0,  11e1,
                11e2,  11e3,  13e-5, 13e-4, 13e-3, 13e-2, 13e-1, 13e0,
                13e1,  13e2,  13e3,  14e-5, 14e-4, 14e-3, 14e-2, 14e-1,
                14e0,  14e1,  14e2,  14e3,  15e-5, 15e-4, 15e-3, 15e-2,
                15e-1, 15e0,  15e1,  15e2,  15e3,  16e-5, 16e-4, 16e-3,
            });

            try testArgs(@Vector(1, i8), @Vector(1, f128), .{
                -0x0.8p8,
            });
            try testArgs(@Vector(2, i8), @Vector(2, f128), .{
                next(f128, -0x0.8p8, -0.0), next(f128, next(f128, -0x0.8p8, -0.0), -0.0),
            });
            try testArgs(@Vector(4, i8), @Vector(4, f128), .{
                -1e2, -1e1, -1e0, -1e-1,
            });
            try testArgs(@Vector(8, i8), @Vector(8, f128), .{
                -1e-2, -1e-3, -1e-4, -1e-5, -0.0, 0.0, 1e-5, 1e-4,
            });
            try testArgs(@Vector(16, i8), @Vector(16, f128), .{
                1e-3, 1e-2, 1e-1,  1e0,   1e1,   1e2,   next(f128, next(f128, 0x0.8p8, 0.0), 0.0), next(f128, 0x0.8p8, 0.0),
                -2e1, -2e0, -2e-1, -2e-2, -2e-3, -2e-4, -2e-5,                                     2e-5,
            });
            try testArgs(@Vector(32, i8), @Vector(32, f128), .{
                2e-4,  2e-3,  2e-2,  2e-1,  2e0,   2e1,  -3e1,  -3e0,
                -3e-1, -3e-2, -3e-3, -3e-4, -3e-5, 3e-5, 3e-4,  3e-3,
                3e-2,  3e-1,  3e0,   3e1,   -4e1,  -4e0, -4e-1, -4e-2,
                -4e-3, -4e-4, -4e-5, 4e-5,  4e-4,  4e-3, 4e-2,  4e-1,
            });
            try testArgs(@Vector(64, i8), @Vector(64, f128), .{
                4e0,   4e1,   -5e1,  -5e0,  -5e-1, -5e-2, -5e-3, -5e-4,
                -5e-5, 5e-5,  5e-4,  5e-3,  5e-2,  5e-1,  5e0,   5e1,
                -6e1,  -6e0,  -6e-1, -6e-2, -6e-3, -6e-4, -6e-5, 6e-5,
                6e-4,  6e-3,  6e-2,  6e-1,  6e0,   6e1,   -7e1,  -7e0,
                -7e-1, -7e-2, -7e-3, -7e-4, -7e-5, 7e-5,  7e-4,  7e-3,
                7e-2,  7e-1,  7e0,   7e1,   -8e1,  -8e0,  -8e-1, -8e-2,
                -8e-3, -8e-4, -8e-5, 8e-5,  8e-4,  8e-3,  8e-2,  8e-1,
                8e0,   8e1,   -9e1,  -9e0,  -9e-1, -9e-2, -9e-3, -9e-4,
            });
            try testArgs(@Vector(128, i8), @Vector(128, f128), .{
                -9e-5,  9e-5,   9e-4,   9e-3,   9e-2,   9e-1,   9e0,    9e1,
                -11e1,  -11e0,  -11e-1, -11e-2, -11e-3, -11e-4, -11e-5, 11e-5,
                11e-4,  11e-3,  11e-2,  11e-1,  11e0,   11e1,   -12e1,  -12e0,
                -12e-1, -12e-2, -12e-3, -12e-4, -12e-5, 12e-5,  12e-4,  12e-3,
                12e-2,  12e-1,  12e0,   12e1,   -13e0,  -13e-1, -13e-2, -13e-3,
                -13e-4, -13e-5, 13e-5,  13e-4,  13e-3,  13e-2,  13e-1,  13e0,
                -14e0,  -14e-1, -14e-2, -14e-3, -14e-4, -14e-5, 14e-5,  14e-4,
                14e-3,  14e-2,  14e-1,  14e0,   -15e0,  -15e-1, -15e-2, -15e-3,
                -15e-4, -15e-5, 15e-5,  15e-4,  15e-3,  15e-2,  15e-1,  15e0,
                -16e0,  -16e-1, -16e-2, -16e-3, -16e-4, -16e-5, 16e-5,  16e-4,
                16e-3,  16e-2,  16e-1,  16e0,   -17e0,  -17e-1, -17e-2, -17e-3,
                -17e-4, -17e-5, 17e-5,  17e-4,  17e-3,  17e-2,  17e-1,  17e0,
                -18e0,  -18e-1, -18e-2, -18e-3, -18e-4, -18e-5, 18e-5,  18e-4,
                18e-3,  18e-2,  18e-1,  18e0,   -19e0,  -19e-1, -19e-2, -19e-3,
                -19e-4, -19e-5, 19e-5,  19e-4,  19e-3,  19e-2,  19e-1,  19e0,
                -21e0,  -21e-1, -21e-2, -21e-3, -21e-4, -21e-5, 21e-5,  21e-4,
            });

            try testArgs(@Vector(1, u8), @Vector(1, f128), .{
                -0.0,
            });
            try testArgs(@Vector(2, u8), @Vector(2, f128), .{
                0.0, 1e-5,
            });
            try testArgs(@Vector(4, u8), @Vector(4, f128), .{
                1e-4, 1e-3, 1e-2, 1e-1,
            });
            try testArgs(@Vector(8, u8), @Vector(8, f128), .{
                1e0, 1e1, 1e2, next(f128, next(f128, 0x1p8, 0.0), 0.0), next(f128, 0x1p8, 0.0), 2e-5, 2e-4, 2e-3,
            });
            try testArgs(@Vector(16, u8), @Vector(16, f128), .{
                2e-2, 2e-1, 2e0, 2e1, 2e2,  3e-5, 3e-4, 3e-3,
                3e-2, 3e-1, 3e0, 3e1, 4e-5, 4e-4, 4e-3, 4e-2,
            });
            try testArgs(@Vector(32, u8), @Vector(32, f128), .{
                4e-1, 4e0,  4e1,  5e-5, 5e-4, 5e-3, 5e-2, 5e-1,
                5e0,  5e1,  6e-5, 6e-4, 6e-3, 6e-2, 6e-1, 6e0,
                6e1,  7e-5, 7e-4, 7e-3, 7e-2, 7e-1, 7e0,  7e1,
                8e-5, 8e-4, 8e-3, 8e-2, 8e-1, 8e0,  8e1,  9e-5,
            });
            try testArgs(@Vector(64, u8), @Vector(64, f128), .{
                9e-4,  9e-3,  9e-2,  9e-1,  9e0,   9e1,   11e-5, 11e-4,
                11e-3, 11e-2, 11e-1, 11e0,  11e1,  13e-5, 13e-4, 13e-3,
                13e-2, 13e-1, 13e0,  14e-5, 14e-4, 14e-3, 14e-2, 14e-1,
                14e0,  14e1,  15e-5, 15e-4, 15e-3, 15e-2, 15e-1, 15e0,
                15e1,  16e-5, 16e-4, 16e-3, 16e-2, 16e-1, 16e0,  16e1,
                17e-5, 17e-4, 17e-3, 17e-2, 17e-1, 17e0,  17e1,  18e-5,
                18e-4, 18e-3, 18e-2, 18e-1, 18e0,  18e1,  19e-5, 19e-4,
                19e-3, 19e-2, 19e-1, 19e0,  19e1,  21e-5, 21e-4, 21e-3,
            });
            try testArgs(@Vector(128, u8), @Vector(128, f128), .{
                21e-2, 21e-1, 21e0,  21e1,  22e-5, 22e-4, 22e-3, 22e-2,
                22e-1, 22e0,  22e1,  23e-5, 23e-4, 23e-3, 23e-2, 23e-1,
                23e0,  23e1,  24e-5, 24e-4, 24e-3, 24e-2, 24e-1, 24e0,
                24e1,  25e-5, 25e-4, 25e-3, 25e-2, 25e-1, 25e0,  25e1,
                26e-5, 26e-4, 26e-3, 26e-2, 26e-1, 26e0,  27e-5, 27e-4,
                27e-3, 27e-2, 27e-1, 27e0,  28e-5, 28e-4, 28e-3, 28e-2,
                28e-1, 28e0,  29e-5, 29e-4, 29e-3, 29e-2, 29e-1, 29e0,
                31e-5, 31e-4, 31e-3, 31e-2, 31e-1, 31e0,  32e-5, 32e-4,
                32e-3, 32e-2, 32e-1, 32e0,  33e-5, 33e-4, 33e-3, 33e-2,
                33e-1, 33e0,  34e-5, 34e-4, 34e-3, 34e-2, 34e-1, 34e0,
                35e-5, 35e-4, 35e-3, 35e-2, 35e-1, 35e0,  36e-5, 36e-4,
                36e-3, 36e-2, 36e-1, 36e0,  37e-5, 37e-4, 37e-3, 37e-2,
                37e-1, 37e0,  38e-5, 38e-4, 38e-3, 38e-2, 38e-1, 38e0,
                39e-5, 39e-4, 39e-3, 39e-2, 39e-1, 39e0,  41e-5, 41e-4,
                41e-3, 41e-2, 41e-1, 41e0,  42e-5, 42e-4, 42e-3, 42e-2,
                42e-1, 42e0,  43e-5, 43e-4, 43e-3, 43e-2, 43e-1, 43e0,
            });

            try testArgs(@Vector(1, i16), @Vector(1, f128), .{
                -0x0.8p16,
            });
            try testArgs(@Vector(2, i16), @Vector(2, f128), .{
                next(f128, -0x0.8p16, -0.0), next(f128, next(f128, -0x0.8p16, -0.0), -0.0),
            });
            try testArgs(@Vector(4, i16), @Vector(4, f128), .{
                -1e4, -1e3, -1e2, -1e1,
            });
            try testArgs(@Vector(8, i16), @Vector(8, f128), .{
                -1e0, -1e-1, -1e-2, -1e-3, -1e-4, -1e-5, -0.0, 0.0,
            });
            try testArgs(@Vector(16, i16), @Vector(16, f128), .{
                1e-5, 1e-4, 1e-3,                                       1e-2,                      1e-1, 1e0,  1e1,  1e2,
                1e3,  1e4,  next(f128, next(f128, 0x0.8p16, 0.0), 0.0), next(f128, 0x0.8p16, 0.0), -2e4, -2e3, -2e2, -2e1,
            });
            try testArgs(@Vector(32, i16), @Vector(32, f128), .{
                -2e0,  -2e-1, -2e-2, -2e-3, -2e-4, -2e-5, 2e-5,  2e-4,
                2e-3,  2e-2,  2e-1,  2e0,   2e1,   2e2,   2e3,   2e4,
                -3e4,  -3e3,  -3e2,  -3e1,  -3e0,  -3e-1, -3e-2, -3e-3,
                -3e-4, -3e-5, 3e-5,  3e-4,  3e-3,  3e-2,  3e-1,  3e0,
            });
            try testArgs(@Vector(64, i16), @Vector(64, f128), .{
                3e1,   3e2,   3e3,   3e4,   -4e3,  -4e2,  -4e1,  -4e0,
                -4e-1, -4e-2, -4e-3, -4e-4, -4e-5, 4e-5,  4e-4,  4e-3,
                4e-2,  4e-1,  4e0,   4e1,   4e2,   4e3,   -5e3,  -5e2,
                -5e1,  -5e0,  -5e-1, -5e-2, -5e-3, -5e-4, -5e-5, 5e-5,
                5e-4,  5e-3,  5e-2,  5e-1,  5e0,   5e1,   5e2,   5e3,
                -6e3,  -6e2,  -6e1,  -6e0,  -6e-1, -6e-2, -6e-3, -6e-4,
                -6e-5, 6e-5,  6e-4,  6e-3,  6e-2,  6e-1,  6e0,   6e1,
                6e2,   6e3,   -7e3,  -7e2,  -7e1,  -7e0,  -7e-1, -7e-2,
            });
            try testArgs(@Vector(128, i16), @Vector(128, f128), .{
                -7e-3,  -7e-4,  -7e-5,  7e-5,   7e-4,   7e-3,   7e-2,   7e-1,
                7e0,    7e1,    7e2,    7e3,    -8e3,   -8e2,   -8e1,   -8e0,
                -8e-1,  -8e-2,  -8e-3,  -8e-4,  -8e-5,  8e-5,   8e-4,   8e-3,
                8e-2,   8e-1,   8e0,    8e1,    8e2,    8e3,    -9e3,   -9e2,
                -9e1,   -9e0,   -9e-1,  -9e-2,  -9e-3,  -9e-4,  -9e-5,  9e-5,
                9e-4,   9e-3,   9e-2,   9e-1,   9e0,    9e1,    9e2,    9e3,
                -11e3,  -11e2,  -11e1,  -11e0,  -11e-1, -11e-2, -11e-3, -11e-4,
                -11e-5, 11e-5,  11e-4,  11e-3,  11e-2,  11e-1,  11e0,   11e1,
                11e2,   11e3,   -12e3,  -12e2,  -12e1,  -12e0,  -12e-1, -12e-2,
                -12e-3, -12e-4, -12e-5, 12e-5,  12e-4,  12e-3,  12e-2,  12e-1,
                12e0,   12e1,   12e2,   12e3,   -13e3,  -13e2,  -13e1,  -13e0,
                -13e-1, -13e-2, -13e-3, -13e-4, -13e-5, 13e-5,  13e-4,  13e-3,
                13e-2,  13e-1,  13e0,   13e1,   13e2,   -14e2,  -14e1,  -14e0,
                -14e-1, -14e-2, -14e-3, -14e-4, -14e-5, 14e-5,  14e-4,  14e-3,
                14e-2,  14e-1,  14e0,   14e1,   14e2,   14e3,   -15e3,  -15e2,
                -15e1,  -15e0,  -15e-1, -15e-2, -15e-3, -15e-4, -15e-5, 15e-5,
            });

            try testArgs(@Vector(1, u16), @Vector(1, f128), .{
                -0.0,
            });
            try testArgs(@Vector(2, u16), @Vector(2, f128), .{
                0.0, 1e-5,
            });
            try testArgs(@Vector(4, u16), @Vector(4, f128), .{
                1e-4, 1e-3, 1e-2, 1e-1,
            });
            try testArgs(@Vector(8, u16), @Vector(8, f128), .{
                1e0, 1e1, 1e2, 1e3, 1e4, next(f128, next(f128, 0x1p16, 0.0), 0.0), next(f128, 0x1p16, 0.0), 2e-5,
            });
            try testArgs(@Vector(16, u16), @Vector(16, f128), .{
                2e-4, 2e-3, 2e-2, 2e-1, 2e0,  2e1,  2e2, 2e3,
                2e4,  3e-5, 3e-4, 3e-3, 3e-2, 3e-1, 3e0, 3e1,
            });
            try testArgs(@Vector(32, u16), @Vector(32, f128), .{
                3e2,  3e3,  3e4, 4e-5, 4e-4, 4e-3, 4e-2, 4e-1,
                4e0,  4e1,  4e2, 4e3,  5e-5, 5e-4, 5e-3, 5e-2,
                5e-1, 5e0,  5e1, 5e2,  5e3,  6e-5, 6e-4, 6e-3,
                6e-2, 6e-1, 6e0, 6e1,  6e2,  6e3,  7e-5, 7e-4,
            });
            try testArgs(@Vector(64, u16), @Vector(64, f128), .{
                7e-3,  7e-2,  7e-1,  7e0,   7e1,   7e2,   7e3,   8e-5,
                8e-4,  8e-3,  8e-2,  8e-1,  8e0,   8e1,   8e2,   8e3,
                9e-5,  9e-4,  9e-3,  9e-2,  9e-1,  9e0,   9e1,   9e2,
                9e3,   11e-5, 11e-4, 11e-3, 11e-2, 11e-1, 11e0,  11e1,
                11e2,  11e3,  13e-5, 13e-4, 13e-3, 13e-2, 13e-1, 13e0,
                13e1,  13e2,  13e3,  14e-5, 14e-4, 14e-3, 14e-2, 14e-1,
                14e0,  14e1,  14e2,  14e3,  15e-5, 15e-4, 15e-3, 15e-2,
                15e-1, 15e0,  15e1,  15e2,  15e3,  16e-5, 16e-4, 16e-3,
            });
            try testArgs(@Vector(128, u16), @Vector(128, f128), .{
                16e-2, 16e-1, 16e0,  16e1,  16e2,  16e3,  17e-5, 17e-4,
                17e-3, 17e-2, 17e-1, 17e0,  17e1,  17e2,  17e3,  18e-5,
                18e-4, 18e-3, 18e-2, 18e-1, 18e0,  18e1,  18e2,  18e3,
                19e-5, 19e-4, 19e-3, 19e-2, 19e-1, 19e0,  19e1,  19e2,
                19e3,  21e-5, 21e-4, 21e-3, 21e-2, 21e-1, 21e0,  21e1,
                21e2,  21e3,  22e-5, 22e-4, 22e-3, 22e-2, 22e-1, 22e0,
                22e1,  22e2,  22e3,  23e-5, 23e-4, 23e-3, 23e-2, 23e-1,
                23e0,  23e1,  23e2,  23e3,  24e-5, 24e-4, 24e-3, 24e-2,
                24e-1, 24e0,  24e1,  24e2,  24e3,  25e-5, 25e-4, 25e-3,
                25e-2, 25e-1, 25e0,  25e1,  25e2,  25e3,  26e-5, 26e-4,
                26e-3, 26e-2, 26e-1, 26e0,  26e1,  26e2,  26e3,  27e-5,
                27e-4, 27e-3, 27e-2, 27e-1, 27e0,  27e1,  27e2,  27e3,
                28e-5, 28e-4, 28e-3, 28e-2, 28e-1, 28e0,  28e1,  28e2,
                28e3,  29e-5, 29e-4, 29e-3, 29e-2, 29e-1, 29e0,  29e1,
                29e2,  29e3,  31e-5, 31e-4, 31e-3, 31e-2, 31e-1, 31e0,
                31e1,  31e2,  31e3,  32e-5, 32e-4, 32e-3, 32e-2, 32e-1,
            });

            try testArgs(@Vector(1, i32), @Vector(1, f128), .{
                -0x0.8p32,
            });
            try testArgs(@Vector(2, i32), @Vector(2, f128), .{
                next(f128, -0x0.8p32, -0.0), next(f128, next(f128, -0x0.8p32, -0.0), -0.0),
            });
            try testArgs(@Vector(4, i32), @Vector(4, f128), .{
                -1e4, -1e3, -1e2, -1e1,
            });
            try testArgs(@Vector(8, i32), @Vector(8, f128), .{
                -1e0, -1e-1, -1e-2, -1e-3, -1e-4, -1e-5, -0.0, 0.0,
            });
            try testArgs(@Vector(16, i32), @Vector(16, f128), .{
                1e-5, 1e-4, 1e-3,                                       1e-2,                      1e-1, 1e0,  1e1,  1e2,
                1e3,  1e4,  next(f128, next(f128, 0x0.8p32, 0.0), 0.0), next(f128, 0x0.8p32, 0.0), -2e4, -2e3, -2e2, -2e1,
            });
            try testArgs(@Vector(32, i32), @Vector(32, f128), .{
                -2e0,  -2e-1, -2e-2, -2e-3, -2e-4, -2e-5, 2e-5,  2e-4,
                2e-3,  2e-2,  2e-1,  2e0,   2e1,   2e2,   2e3,   2e4,
                -3e4,  -3e3,  -3e2,  -3e1,  -3e0,  -3e-1, -3e-2, -3e-3,
                -3e-4, -3e-5, 3e-5,  3e-4,  3e-3,  3e-2,  3e-1,  3e0,
            });
            try testArgs(@Vector(64, i32), @Vector(64, f128), .{
                3e1,   3e2,   3e3,   3e4,   -4e3,  -4e2,  -4e1,  -4e0,
                -4e-1, -4e-2, -4e-3, -4e-4, -4e-5, 4e-5,  4e-4,  4e-3,
                4e-2,  4e-1,  4e0,   4e1,   4e2,   4e3,   -5e3,  -5e2,
                -5e1,  -5e0,  -5e-1, -5e-2, -5e-3, -5e-4, -5e-5, 5e-5,
                5e-4,  5e-3,  5e-2,  5e-1,  5e0,   5e1,   5e2,   5e3,
                -6e3,  -6e2,  -6e1,  -6e0,  -6e-1, -6e-2, -6e-3, -6e-4,
                -6e-5, 6e-5,  6e-4,  6e-3,  6e-2,  6e-1,  6e0,   6e1,
                6e2,   6e3,   -7e3,  -7e2,  -7e1,  -7e0,  -7e-1, -7e-2,
            });
            try testArgs(@Vector(128, i32), @Vector(128, f128), .{
                -7e-3,  -7e-4,  -7e-5,  7e-5,   7e-4,   7e-3,   7e-2,   7e-1,
                7e0,    7e1,    7e2,    7e3,    -8e3,   -8e2,   -8e1,   -8e0,
                -8e-1,  -8e-2,  -8e-3,  -8e-4,  -8e-5,  8e-5,   8e-4,   8e-3,
                8e-2,   8e-1,   8e0,    8e1,    8e2,    8e3,    -9e3,   -9e2,
                -9e1,   -9e0,   -9e-1,  -9e-2,  -9e-3,  -9e-4,  -9e-5,  9e-5,
                9e-4,   9e-3,   9e-2,   9e-1,   9e0,    9e1,    9e2,    9e3,
                -11e3,  -11e2,  -11e1,  -11e0,  -11e-1, -11e-2, -11e-3, -11e-4,
                -11e-5, 11e-5,  11e-4,  11e-3,  11e-2,  11e-1,  11e0,   11e1,
                11e2,   11e3,   -12e3,  -12e2,  -12e1,  -12e0,  -12e-1, -12e-2,
                -12e-3, -12e-4, -12e-5, 12e-5,  12e-4,  12e-3,  12e-2,  12e-1,
                12e0,   12e1,   12e2,   12e3,   -13e3,  -13e2,  -13e1,  -13e0,
                -13e-1, -13e-2, -13e-3, -13e-4, -13e-5, 13e-5,  13e-4,  13e-3,
                13e-2,  13e-1,  13e0,   13e1,   13e2,   -14e2,  -14e1,  -14e0,
                -14e-1, -14e-2, -14e-3, -14e-4, -14e-5, 14e-5,  14e-4,  14e-3,
                14e-2,  14e-1,  14e0,   14e1,   14e2,   14e3,   -15e3,  -15e2,
                -15e1,  -15e0,  -15e-1, -15e-2, -15e-3, -15e-4, -15e-5, 15e-5,
            });

            try testArgs(@Vector(1, u32), @Vector(1, f128), .{
                -0.0,
            });
            try testArgs(@Vector(2, u32), @Vector(2, f128), .{
                0.0, 1e-5,
            });
            try testArgs(@Vector(4, u32), @Vector(4, f128), .{
                1e-4, 1e-3, 1e-2, 1e-1,
            });
            try testArgs(@Vector(8, u32), @Vector(8, f128), .{
                1e0, 1e1, 1e2, 1e3, 1e4, next(f128, next(f128, 0x1p32, 0.0), 0.0), next(f128, 0x1p32, 0.0), 2e-5,
            });
            try testArgs(@Vector(16, u32), @Vector(16, f128), .{
                2e-4, 2e-3, 2e-2, 2e-1, 2e0,  2e1,  2e2, 2e3,
                2e4,  3e-5, 3e-4, 3e-3, 3e-2, 3e-1, 3e0, 3e1,
            });
            try testArgs(@Vector(32, u32), @Vector(32, f128), .{
                3e2,  3e3,  3e4, 4e-5, 4e-4, 4e-3, 4e-2, 4e-1,
                4e0,  4e1,  4e2, 4e3,  5e-5, 5e-4, 5e-3, 5e-2,
                5e-1, 5e0,  5e1, 5e2,  5e3,  6e-5, 6e-4, 6e-3,
                6e-2, 6e-1, 6e0, 6e1,  6e2,  6e3,  7e-5, 7e-4,
            });
            try testArgs(@Vector(64, u32), @Vector(64, f128), .{
                7e-3,  7e-2,  7e-1,  7e0,   7e1,   7e2,   7e3,   8e-5,
                8e-4,  8e-3,  8e-2,  8e-1,  8e0,   8e1,   8e2,   8e3,
                9e-5,  9e-4,  9e-3,  9e-2,  9e-1,  9e0,   9e1,   9e2,
                9e3,   11e-5, 11e-4, 11e-3, 11e-2, 11e-1, 11e0,  11e1,
                11e2,  11e3,  13e-5, 13e-4, 13e-3, 13e-2, 13e-1, 13e0,
                13e1,  13e2,  13e3,  14e-5, 14e-4, 14e-3, 14e-2, 14e-1,
                14e0,  14e1,  14e2,  14e3,  15e-5, 15e-4, 15e-3, 15e-2,
                15e-1, 15e0,  15e1,  15e2,  15e3,  16e-5, 16e-4, 16e-3,
            });
            try testArgs(@Vector(128, u32), @Vector(128, f128), .{
                16e-2, 16e-1, 16e0,  16e1,  16e2,  16e3,  17e-5, 17e-4,
                17e-3, 17e-2, 17e-1, 17e0,  17e1,  17e2,  17e3,  18e-5,
                18e-4, 18e-3, 18e-2, 18e-1, 18e0,  18e1,  18e2,  18e3,
                19e-5, 19e-4, 19e-3, 19e-2, 19e-1, 19e0,  19e1,  19e2,
                19e3,  21e-5, 21e-4, 21e-3, 21e-2, 21e-1, 21e0,  21e1,
                21e2,  21e3,  22e-5, 22e-4, 22e-3, 22e-2, 22e-1, 22e0,
                22e1,  22e2,  22e3,  23e-5, 23e-4, 23e-3, 23e-2, 23e-1,
                23e0,  23e1,  23e2,  23e3,  24e-5, 24e-4, 24e-3, 24e-2,
                24e-1, 24e0,  24e1,  24e2,  24e3,  25e-5, 25e-4, 25e-3,
                25e-2, 25e-1, 25e0,  25e1,  25e2,  25e3,  26e-5, 26e-4,
                26e-3, 26e-2, 26e-1, 26e0,  26e1,  26e2,  26e3,  27e-5,
                27e-4, 27e-3, 27e-2, 27e-1, 27e0,  27e1,  27e2,  27e3,
                28e-5, 28e-4, 28e-3, 28e-2, 28e-1, 28e0,  28e1,  28e2,
                28e3,  29e-5, 29e-4, 29e-3, 29e-2, 29e-1, 29e0,  29e1,
                29e2,  29e3,  31e-5, 31e-4, 31e-3, 31e-2, 31e-1, 31e0,
                31e1,  31e2,  31e3,  32e-5, 32e-4, 32e-3, 32e-2, 32e-1,
            });

            try testArgs(@Vector(1, i64), @Vector(1, f128), .{
                -0x0.8p64,
            });
            try testArgs(@Vector(2, i64), @Vector(2, f128), .{
                next(f128, -0x0.8p64, -0.0), next(f128, next(f128, -0x0.8p64, -0.0), -0.0),
            });
            try testArgs(@Vector(4, i64), @Vector(4, f128), .{
                -1e4, -1e3, -1e2, -1e1,
            });
            try testArgs(@Vector(8, i64), @Vector(8, f128), .{
                -1e0, -1e-1, -1e-2, -1e-3, -1e-4, -1e-5, -0.0, 0.0,
            });
            try testArgs(@Vector(16, i64), @Vector(16, f128), .{
                1e-5, 1e-4, 1e-3,                                       1e-2,                      1e-1, 1e0,  1e1,  1e2,
                1e3,  1e4,  next(f128, next(f128, 0x0.8p64, 0.0), 0.0), next(f128, 0x0.8p64, 0.0), -2e4, -2e3, -2e2, -2e1,
            });
            try testArgs(@Vector(32, i64), @Vector(32, f128), .{
                -2e0,  -2e-1, -2e-2, -2e-3, -2e-4, -2e-5, 2e-5,  2e-4,
                2e-3,  2e-2,  2e-1,  2e0,   2e1,   2e2,   2e3,   2e4,
                -3e4,  -3e3,  -3e2,  -3e1,  -3e0,  -3e-1, -3e-2, -3e-3,
                -3e-4, -3e-5, 3e-5,  3e-4,  3e-3,  3e-2,  3e-1,  3e0,
            });
            try testArgs(@Vector(64, i64), @Vector(64, f128), .{
                3e1,   3e2,   3e3,   3e4,   -4e3,  -4e2,  -4e1,  -4e0,
                -4e-1, -4e-2, -4e-3, -4e-4, -4e-5, 4e-5,  4e-4,  4e-3,
                4e-2,  4e-1,  4e0,   4e1,   4e2,   4e3,   -5e3,  -5e2,
                -5e1,  -5e0,  -5e-1, -5e-2, -5e-3, -5e-4, -5e-5, 5e-5,
                5e-4,  5e-3,  5e-2,  5e-1,  5e0,   5e1,   5e2,   5e3,
                -6e3,  -6e2,  -6e1,  -6e0,  -6e-1, -6e-2, -6e-3, -6e-4,
                -6e-5, 6e-5,  6e-4,  6e-3,  6e-2,  6e-1,  6e0,   6e1,
                6e2,   6e3,   -7e3,  -7e2,  -7e1,  -7e0,  -7e-1, -7e-2,
            });
            try testArgs(@Vector(128, i64), @Vector(128, f128), .{
                -7e-3,  -7e-4,  -7e-5,  7e-5,   7e-4,   7e-3,   7e-2,   7e-1,
                7e0,    7e1,    7e2,    7e3,    -8e3,   -8e2,   -8e1,   -8e0,
                -8e-1,  -8e-2,  -8e-3,  -8e-4,  -8e-5,  8e-5,   8e-4,   8e-3,
                8e-2,   8e-1,   8e0,    8e1,    8e2,    8e3,    -9e3,   -9e2,
                -9e1,   -9e0,   -9e-1,  -9e-2,  -9e-3,  -9e-4,  -9e-5,  9e-5,
                9e-4,   9e-3,   9e-2,   9e-1,   9e0,    9e1,    9e2,    9e3,
                -11e3,  -11e2,  -11e1,  -11e0,  -11e-1, -11e-2, -11e-3, -11e-4,
                -11e-5, 11e-5,  11e-4,  11e-3,  11e-2,  11e-1,  11e0,   11e1,
                11e2,   11e3,   -12e3,  -12e2,  -12e1,  -12e0,  -12e-1, -12e-2,
                -12e-3, -12e-4, -12e-5, 12e-5,  12e-4,  12e-3,  12e-2,  12e-1,
                12e0,   12e1,   12e2,   12e3,   -13e3,  -13e2,  -13e1,  -13e0,
                -13e-1, -13e-2, -13e-3, -13e-4, -13e-5, 13e-5,  13e-4,  13e-3,
                13e-2,  13e-1,  13e0,   13e1,   13e2,   -14e2,  -14e1,  -14e0,
                -14e-1, -14e-2, -14e-3, -14e-4, -14e-5, 14e-5,  14e-4,  14e-3,
                14e-2,  14e-1,  14e0,   14e1,   14e2,   14e3,   -15e3,  -15e2,
                -15e1,  -15e0,  -15e-1, -15e-2, -15e-3, -15e-4, -15e-5, 15e-5,
            });

            try testArgs(@Vector(1, u64), @Vector(1, f128), .{
                -0.0,
            });
            try testArgs(@Vector(2, u64), @Vector(2, f128), .{
                0.0, 1e-5,
            });
            try testArgs(@Vector(4, u64), @Vector(4, f128), .{
                1e-4, 1e-3, 1e-2, 1e-1,
            });
            try testArgs(@Vector(8, u64), @Vector(8, f128), .{
                1e0, 1e1, 1e2, 1e3, 1e4, next(f128, next(f128, 0x1p64, 0.0), 0.0), next(f128, 0x1p64, 0.0), 2e-5,
            });
            try testArgs(@Vector(16, u64), @Vector(16, f128), .{
                2e-4, 2e-3, 2e-2, 2e-1, 2e0,  2e1,  2e2, 2e3,
                2e4,  3e-5, 3e-4, 3e-3, 3e-2, 3e-1, 3e0, 3e1,
            });
            try testArgs(@Vector(32, u64), @Vector(32, f128), .{
                3e2,  3e3,  3e4, 4e-5, 4e-4, 4e-3, 4e-2, 4e-1,
                4e0,  4e1,  4e2, 4e3,  5e-5, 5e-4, 5e-3, 5e-2,
                5e-1, 5e0,  5e1, 5e2,  5e3,  6e-5, 6e-4, 6e-3,
                6e-2, 6e-1, 6e0, 6e1,  6e2,  6e3,  7e-5, 7e-4,
            });
            try testArgs(@Vector(64, u64), @Vector(64, f128), .{
                7e-3,  7e-2,  7e-1,  7e0,   7e1,   7e2,   7e3,   8e-5,
                8e-4,  8e-3,  8e-2,  8e-1,  8e0,   8e1,   8e2,   8e3,
                9e-5,  9e-4,  9e-3,  9e-2,  9e-1,  9e0,   9e1,   9e2,
                9e3,   11e-5, 11e-4, 11e-3, 11e-2, 11e-1, 11e0,  11e1,
                11e2,  11e3,  13e-5, 13e-4, 13e-3, 13e-2, 13e-1, 13e0,
                13e1,  13e2,  13e3,  14e-5, 14e-4, 14e-3, 14e-2, 14e-1,
                14e0,  14e1,  14e2,  14e3,  15e-5, 15e-4, 15e-3, 15e-2,
                15e-1, 15e0,  15e1,  15e2,  15e3,  16e-5, 16e-4, 16e-3,
            });
            try testArgs(@Vector(128, u64), @Vector(128, f128), .{
                16e-2, 16e-1, 16e0,  16e1,  16e2,  16e3,  17e-5, 17e-4,
                17e-3, 17e-2, 17e-1, 17e0,  17e1,  17e2,  17e3,  18e-5,
                18e-4, 18e-3, 18e-2, 18e-1, 18e0,  18e1,  18e2,  18e3,
                19e-5, 19e-4, 19e-3, 19e-2, 19e-1, 19e0,  19e1,  19e2,
                19e3,  21e-5, 21e-4, 21e-3, 21e-2, 21e-1, 21e0,  21e1,
                21e2,  21e3,  22e-5, 22e-4, 22e-3, 22e-2, 22e-1, 22e0,
                22e1,  22e2,  22e3,  23e-5, 23e-4, 23e-3, 23e-2, 23e-1,
                23e0,  23e1,  23e2,  23e3,  24e-5, 24e-4, 24e-3, 24e-2,
                24e-1, 24e0,  24e1,  24e2,  24e3,  25e-5, 25e-4, 25e-3,
                25e-2, 25e-1, 25e0,  25e1,  25e2,  25e3,  26e-5, 26e-4,
                26e-3, 26e-2, 26e-1, 26e0,  26e1,  26e2,  26e3,  27e-5,
                27e-4, 27e-3, 27e-2, 27e-1, 27e0,  27e1,  27e2,  27e3,
                28e-5, 28e-4, 28e-3, 28e-2, 28e-1, 28e0,  28e1,  28e2,
                28e3,  29e-5, 29e-4, 29e-3, 29e-2, 29e-1, 29e0,  29e1,
                29e2,  29e3,  31e-5, 31e-4, 31e-3, 31e-2, 31e-1, 31e0,
                31e1,  31e2,  31e3,  32e-5, 32e-4, 32e-3, 32e-2, 32e-1,
            });

            try testArgs(@Vector(1, i128), @Vector(1, f128), .{
                -0x0.8p128,
            });
            try testArgs(@Vector(2, i128), @Vector(2, f128), .{
                next(f128, -0x0.8p128, -0.0), next(f128, next(f128, -0x0.8p128, -0.0), -0.0),
            });
            try testArgs(@Vector(4, i128), @Vector(4, f128), .{
                -1e4, -1e3, -1e2, -1e1,
            });
            try testArgs(@Vector(8, i128), @Vector(8, f128), .{
                -1e0, -1e-1, -1e-2, -1e-3, -1e-4, -1e-5, -0.0, 0.0,
            });
            try testArgs(@Vector(16, i128), @Vector(16, f128), .{
                1e-5, 1e-4, 1e-3,                                        1e-2,                       1e-1, 1e0,  1e1,  1e2,
                1e3,  1e4,  next(f128, next(f128, 0x0.8p128, 0.0), 0.0), next(f128, 0x0.8p128, 0.0), -2e4, -2e3, -2e2, -2e1,
            });
            try testArgs(@Vector(32, i128), @Vector(32, f128), .{
                -2e0,  -2e-1, -2e-2, -2e-3, -2e-4, -2e-5, 2e-5,  2e-4,
                2e-3,  2e-2,  2e-1,  2e0,   2e1,   2e2,   2e3,   2e4,
                -3e4,  -3e3,  -3e2,  -3e1,  -3e0,  -3e-1, -3e-2, -3e-3,
                -3e-4, -3e-5, 3e-5,  3e-4,  3e-3,  3e-2,  3e-1,  3e0,
            });
            try testArgs(@Vector(64, i128), @Vector(64, f128), .{
                3e1,   3e2,   3e3,   3e4,   -4e3,  -4e2,  -4e1,  -4e0,
                -4e-1, -4e-2, -4e-3, -4e-4, -4e-5, 4e-5,  4e-4,  4e-3,
                4e-2,  4e-1,  4e0,   4e1,   4e2,   4e3,   -5e3,  -5e2,
                -5e1,  -5e0,  -5e-1, -5e-2, -5e-3, -5e-4, -5e-5, 5e-5,
                5e-4,  5e-3,  5e-2,  5e-1,  5e0,   5e1,   5e2,   5e3,
                -6e3,  -6e2,  -6e1,  -6e0,  -6e-1, -6e-2, -6e-3, -6e-4,
                -6e-5, 6e-5,  6e-4,  6e-3,  6e-2,  6e-1,  6e0,   6e1,
                6e2,   6e3,   -7e3,  -7e2,  -7e1,  -7e0,  -7e-1, -7e-2,
            });

            try testArgs(@Vector(1, u128), @Vector(1, f128), .{
                -0.0,
            });
            try testArgs(@Vector(2, u128), @Vector(2, f128), .{
                0.0, 1e-5,
            });
            try testArgs(@Vector(4, u128), @Vector(4, f128), .{
                1e-4, 1e-3, 1e-2, 1e-1,
            });
            try testArgs(@Vector(8, u128), @Vector(8, f128), .{
                1e0, 1e1, 1e2, 1e3, 1e4, next(f128, next(f128, 0x1p128, 0.0), 0.0), next(f128, 0x1p128, 0.0), 2e-5,
            });
            try testArgs(@Vector(16, u128), @Vector(16, f128), .{
                2e-4, 2e-3, 2e-2, 2e-1, 2e0,  2e1,  2e2, 2e3,
                2e4,  3e-5, 3e-4, 3e-3, 3e-2, 3e-1, 3e0, 3e1,
            });
            try testArgs(@Vector(32, u128), @Vector(32, f128), .{
                3e2,  3e3,  3e4, 4e-5, 4e-4, 4e-3, 4e-2, 4e-1,
                4e0,  4e1,  4e2, 4e3,  5e-5, 5e-4, 5e-3, 5e-2,
                5e-1, 5e0,  5e1, 5e2,  5e3,  6e-5, 6e-4, 6e-3,
                6e-2, 6e-1, 6e0, 6e1,  6e2,  6e3,  7e-5, 7e-4,
            });
            try testArgs(@Vector(64, u128), @Vector(64, f128), .{
                7e-3,  7e-2,  7e-1,  7e0,   7e1,   7e2,   7e3,   8e-5,
                8e-4,  8e-3,  8e-2,  8e-1,  8e0,   8e1,   8e2,   8e3,
                9e-5,  9e-4,  9e-3,  9e-2,  9e-1,  9e0,   9e1,   9e2,
                9e3,   11e-5, 11e-4, 11e-3, 11e-2, 11e-1, 11e0,  11e1,
                11e2,  11e3,  13e-5, 13e-4, 13e-3, 13e-2, 13e-1, 13e0,
                13e1,  13e2,  13e3,  14e-5, 14e-4, 14e-3, 14e-2, 14e-1,
                14e0,  14e1,  14e2,  14e3,  15e-5, 15e-4, 15e-3, 15e-2,
                15e-1, 15e0,  15e1,  15e2,  15e3,  16e-5, 16e-4, 16e-3,
            });

            try testArgs(@Vector(1, i256), @Vector(1, f128), .{
                -0x0.8p256,
            });
            try testArgs(@Vector(2, i256), @Vector(2, f128), .{
                next(f128, -0x0.8p256, -0.0), next(f128, next(f128, -0x0.8p256, -0.0), -0.0),
            });
            try testArgs(@Vector(4, i256), @Vector(4, f128), .{
                -1e4, -1e3, -1e2, -1e1,
            });
            try testArgs(@Vector(8, i256), @Vector(8, f128), .{
                -1e0, -1e-1, -1e-2, -1e-3, -1e-4, -1e-5, -0.0, 0.0,
            });
            try testArgs(@Vector(16, i256), @Vector(16, f128), .{
                1e-5, 1e-4, 1e-3,                                        1e-2,                       1e-1, 1e0,  1e1,  1e2,
                1e3,  1e4,  next(f128, next(f128, 0x0.8p256, 0.0), 0.0), next(f128, 0x0.8p256, 0.0), -2e4, -2e3, -2e2, -2e1,
            });
            try testArgs(@Vector(32, i256), @Vector(32, f128), .{
                -2e0,  -2e-1, -2e-2, -2e-3, -2e-4, -2e-5, 2e-5,  2e-4,
                2e-3,  2e-2,  2e-1,  2e0,   2e1,   2e2,   2e3,   2e4,
                -3e4,  -3e3,  -3e2,  -3e1,  -3e0,  -3e-1, -3e-2, -3e-3,
                -3e-4, -3e-5, 3e-5,  3e-4,  3e-3,  3e-2,  3e-1,  3e0,
            });
            try testArgs(@Vector(64, i256), @Vector(64, f128), .{
                3e1,   3e2,   3e3,   3e4,   -4e3,  -4e2,  -4e1,  -4e0,
                -4e-1, -4e-2, -4e-3, -4e-4, -4e-5, 4e-5,  4e-4,  4e-3,
                4e-2,  4e-1,  4e0,   4e1,   4e2,   4e3,   -5e3,  -5e2,
                -5e1,  -5e0,  -5e-1, -5e-2, -5e-3, -5e-4, -5e-5, 5e-5,
                5e-4,  5e-3,  5e-2,  5e-1,  5e0,   5e1,   5e2,   5e3,
                -6e3,  -6e2,  -6e1,  -6e0,  -6e-1, -6e-2, -6e-3, -6e-4,
                -6e-5, 6e-5,  6e-4,  6e-3,  6e-2,  6e-1,  6e0,   6e1,
                6e2,   6e3,   -7e3,  -7e2,  -7e1,  -7e0,  -7e-1, -7e-2,
            });

            try testArgs(@Vector(1, u256), @Vector(1, f128), .{
                -0.0,
            });
            try testArgs(@Vector(2, u256), @Vector(2, f128), .{
                0.0, 1e-5,
            });
            try testArgs(@Vector(4, u256), @Vector(4, f128), .{
                1e-4, 1e-3, 1e-2, 1e-1,
            });
            try testArgs(@Vector(8, u256), @Vector(8, f128), .{
                1e0, 1e1, 1e2, 1e3, 1e4, next(f128, next(f128, 0x1p256, 0.0), 0.0), next(f128, 0x1p256, 0.0), 2e-5,
            });
            try testArgs(@Vector(16, u256), @Vector(16, f128), .{
                2e-4, 2e-3, 2e-2, 2e-1, 2e0,  2e1,  2e2, 2e3,
                2e4,  3e-5, 3e-4, 3e-3, 3e-2, 3e-1, 3e0, 3e1,
            });
            try testArgs(@Vector(32, u256), @Vector(32, f128), .{
                3e2,  3e3,  3e4, 4e-5, 4e-4, 4e-3, 4e-2, 4e-1,
                4e0,  4e1,  4e2, 4e3,  5e-5, 5e-4, 5e-3, 5e-2,
                5e-1, 5e0,  5e1, 5e2,  5e3,  6e-5, 6e-4, 6e-3,
                6e-2, 6e-1, 6e0, 6e1,  6e2,  6e3,  7e-5, 7e-4,
            });
            try testArgs(@Vector(64, u256), @Vector(64, f128), .{
                7e-3,  7e-2,  7e-1,  7e0,   7e1,   7e2,   7e3,   8e-5,
                8e-4,  8e-3,  8e-2,  8e-1,  8e0,   8e1,   8e2,   8e3,
                9e-5,  9e-4,  9e-3,  9e-2,  9e-1,  9e0,   9e1,   9e2,
                9e3,   11e-5, 11e-4, 11e-3, 11e-2, 11e-1, 11e0,  11e1,
                11e2,  11e3,  13e-5, 13e-4, 13e-3, 13e-2, 13e-1, 13e0,
                13e1,  13e2,  13e3,  14e-5, 14e-4, 14e-3, 14e-2, 14e-1,
                14e0,  14e1,  14e2,  14e3,  15e-5, 15e-4, 15e-3, 15e-2,
                15e-1, 15e0,  15e1,  15e2,  15e3,  16e-5, 16e-4, 16e-3,
            });
        }
        fn testFloatVectorsFromIntVectors() !void {
            @setEvalBranchQuota(2_700);

            try testArgs(@Vector(1, f16), @Vector(1, i8), .{
                imin(i8),
            });
            try testArgs(@Vector(2, f16), @Vector(2, i8), .{
                imin(i8) + 1, -1e2,
            });
            try testArgs(@Vector(4, f16), @Vector(4, i8), .{
                -1e1, -1e0, 0, 1e0,
            });
            try testArgs(@Vector(8, f16), @Vector(8, i8), .{
                1e1, 1e2, imax(i8) - 1, imax(i8), imin(i8) + 2, imin(i8) + 3, -2e1, -2e0,
            });
            try testArgs(@Vector(16, f16), @Vector(16, i8), .{
                2e0, 2e1, imax(i8) - 3, imax(i8) - 2, imin(i8) + 4, imin(i8) + 5, -3e1, -3e0,
                3e0, 3e1, imax(i8) - 5, imax(i8) - 4, imin(i8) + 6, imin(i8) + 7, -4e1, -4e0,
            });
            try testArgs(@Vector(32, f16), @Vector(32, i8), .{
                4e0, 4e1, imax(i8) - 7,  imax(i8) - 6,  imin(i8) + 8,  imin(i8) + 9,  -5e1, -5e0,
                5e0, 5e1, imax(i8) - 9,  imax(i8) - 8,  imin(i8) + 10, imin(i8) + 11, -6e1, -6e0,
                6e0, 6e1, imax(i8) - 11, imax(i8) - 10, imin(i8) + 12, imin(i8) + 13, -7e1, -7e0,
                7e0, 7e1, imax(i8) - 13, imax(i8) - 12, imin(i8) + 14, imin(i8) + 15, -8e1, -8e0,
            });
            try testArgs(@Vector(64, f16), @Vector(64, i8), .{
                8e0,           8e1,           imax(i8) - 15, imax(i8) - 14, imin(i8) + 16, imin(i8) + 17, -9e1,          -9e0,
                9e0,           9e1,           imax(i8) - 17, imax(i8) - 16, imin(i8) + 18, imin(i8) + 19, -11e1,         -11e0,
                11e0,          11e1,          imax(i8) - 19, imax(i8) - 18, imin(i8) + 20, imin(i8) + 21, -12e1,         -12e0,
                12e0,          12e1,          imax(i8) - 21, imax(i8) - 20, imin(i8) + 22, imin(i8) + 23, -13e0,         13e0,
                imax(i8) - 23, imax(i8) - 22, imin(i8) + 24, imin(i8) + 25, -14e0,         14e0,          imax(i8) - 25, imax(i8) - 24,
                imin(i8) + 26, imin(i8) + 27, -15e0,         15e0,          imax(i8) - 27, imax(i8) - 26, imin(i8) + 28, imin(i8) + 29,
                -16e0,         16e0,          imax(i8) - 29, imax(i8) - 28, imin(i8) + 30, imin(i8) + 31, -17e0,         17e0,
                imax(i8) - 31, imax(i8) - 30, imin(i8) + 32, imin(i8) + 33, -18e0,         18e0,          imax(i8) - 33, imax(i8) - 32,
            });
            try testArgs(@Vector(128, f16), @Vector(128, i8), .{
                imin(i8) + 34, imin(i8) + 35, -19e0,         19e0,          imax(i8) - 35, imax(i8) - 34, imin(i8) + 36, imin(i8) + 37,
                -21e0,         21e0,          imax(i8) - 37, imax(i8) - 36, imin(i8) + 38, imin(i8) + 39, -22e0,         22e0,
                imax(i8) - 39, imax(i8) - 38, imin(i8) + 40, imin(i8) + 41, -23e0,         23e0,          imax(i8) - 41, imax(i8) - 40,
                imin(i8) + 42, imin(i8) + 43, -24e0,         24e0,          imax(i8) - 43, imax(i8) - 42, imin(i8) + 44, imin(i8) + 45,
                -25e0,         25e0,          imax(i8) - 45, imax(i8) - 44, imin(i8) + 46, imin(i8) + 47, -26e0,         26e0,
                imax(i8) - 47, imax(i8) - 46, imin(i8) + 48, imin(i8) + 49, -27e0,         27e0,          imax(i8) - 49, imax(i8) - 48,
                imin(i8) + 50, imin(i8) + 51, -28e0,         28e0,          imax(i8) - 51, imax(i8) - 50, imin(i8) + 52, imin(i8) + 53,
                -29e0,         29e0,          imax(i8) - 53, imax(i8) - 52, imin(i8) + 54, imin(i8) + 55, -31e0,         31e0,
                imax(i8) - 55, imax(i8) - 54, imin(i8) + 56, imin(i8) + 57, -32e0,         32e0,          imax(i8) - 57, imax(i8) - 56,
                imin(i8) + 58, imin(i8) + 59, -33e0,         33e0,          imax(i8) - 59, imax(i8) - 58, imin(i8) + 60, imin(i8) + 61,
                -34e0,         34e0,          imax(i8) - 61, imax(i8) - 60, imin(i8) + 62, imin(i8) + 63, -35e0,         35e0,
                imax(i8) - 63, imax(i8) - 62, imin(i8) + 64, imin(i8) + 65, -36e0,         36e0,          imax(i8) - 65, imax(i8) - 64,
                imin(i8) + 66, imin(i8) + 67, -37e0,         37e0,          imax(i8) - 67, imax(i8) - 66, imin(i8) + 68, imin(i8) + 69,
                -38e0,         38e0,          imax(i8) - 69, imax(i8) - 68, imin(i8) + 70, imin(i8) + 71, -39e0,         39e0,
                imax(i8) - 71, imax(i8) - 70, imin(i8) + 72, imin(i8) + 73, -41e0,         41e0,          imax(i8) - 73, imax(i8) - 72,
                imin(i8) + 74, imin(i8) + 75, -42e0,         42e0,          imax(i8) - 75, imax(i8) - 74, imin(i8) + 76, imin(i8) + 77,
            });

            try testArgs(@Vector(1, f16), @Vector(1, u8), .{
                0,
            });
            try testArgs(@Vector(2, f16), @Vector(2, u8), .{
                1e0, 1e1,
            });
            try testArgs(@Vector(4, f16), @Vector(4, u8), .{
                1e2, imax(u8) - 1, imax(u8), 2e0,
            });
            try testArgs(@Vector(8, f16), @Vector(8, u8), .{
                2e1, 2e2, imax(u8) - 3, imax(u8) - 2, 3e0, 3e1, imax(u8) - 5, imax(u8) - 4,
            });
            try testArgs(@Vector(16, f16), @Vector(16, u8), .{
                imax(u8) - 7,  imax(u8) - 6,  5e0, 5e1, imax(u8) - 9,  imax(u8) - 8,  6e0, 6e1,
                imax(u8) - 11, imax(u8) - 10, 7e0, 7e1, imax(u8) - 13, imax(u8) - 12, 8e0, 8e1,
            });
            try testArgs(@Vector(32, f16), @Vector(32, u8), .{
                imax(u8) - 15, imax(u8) - 14, 9e0,  9e1,  imax(u8) - 17, imax(u8) - 16, 11e0, 11e1,
                imax(u8) - 19, imax(u8) - 18, 12e0, 12e1, imax(u8) - 21, imax(u8) - 20, 13e0, 13e1,
                imax(u8) - 23, imax(u8) - 22, 14e0, 14e1, imax(u8) - 25, imax(u8) - 24, 15e0, 15e1,
                imax(u8) - 27, imax(u8) - 26, 16e0, 16e1, imax(u8) - 29, imax(u8) - 28, 17e0, 17e1,
            });
            try testArgs(@Vector(64, f16), @Vector(64, u8), .{
                imax(u8) - 31, imax(u8) - 30, 18e0,          18e1,          imax(u8) - 33, imax(u8) - 32, 19e0,          19e1,
                imax(u8) - 35, imax(u8) - 34, 21e0,          21e1,          imax(u8) - 37, imax(u8) - 36, 22e0,          22e1,
                imax(u8) - 39, imax(u8) - 38, 23e0,          23e1,          imax(u8) - 41, imax(u8) - 40, 24e0,          24e1,
                imax(u8) - 43, imax(u8) - 42, 25e0,          25e1,          imax(u8) - 45, imax(u8) - 44, 26e0,          imax(u8) - 47,
                imax(u8) - 46, 27e0,          imax(u8) - 49, imax(u8) - 48, 28e0,          imax(u8) - 51, imax(u8) - 50, 29e0,
                imax(u8) - 53, imax(u8) - 52, 31e0,          imax(u8) - 55, imax(u8) - 54, 32e0,          imax(u8) - 57, imax(u8) - 56,
                33e0,          imax(u8) - 59, imax(u8) - 58, 34e0,          imax(u8) - 61, imax(u8) - 60, 35e0,          imax(u8) - 63,
                imax(u8) - 62, 36e0,          imax(u8) - 65, imax(u8) - 64, 37e0,          imax(u8) - 67, imax(u8) - 66, 38e0,
            });
            try testArgs(@Vector(128, f16), @Vector(128, u8), .{
                imax(u8) - 69,  imax(u8) - 68,  39e0,           imax(u8) - 71,  imax(u8) - 70,  41e0,           imax(u8) - 73,  imax(u8) - 72,
                42e0,           imax(u8) - 75,  imax(u8) - 74,  43e0,           imax(u8) - 77,  imax(u8) - 76,  44e0,           imax(u8) - 79,
                imax(u8) - 78,  45e0,           imax(u8) - 81,  imax(u8) - 80,  46e0,           imax(u8) - 83,  imax(u8) - 82,  47e0,
                imax(u8) - 85,  imax(u8) - 84,  48e0,           imax(u8) - 87,  imax(u8) - 86,  49e0,           imax(u8) - 89,  imax(u8) - 88,
                51e0,           imax(u8) - 91,  imax(u8) - 90,  52e0,           imax(u8) - 93,  imax(u8) - 92,  53e0,           imax(u8) - 95,
                imax(u8) - 94,  54e0,           imax(u8) - 97,  imax(u8) - 96,  55e0,           imax(u8) - 99,  imax(u8) - 98,  56e0,
                imax(u8) - 101, imax(u8) - 100, 57e0,           imax(u8) - 103, imax(u8) - 102, 58e0,           imax(u8) - 105, imax(u8) - 104,
                59e0,           imax(u8) - 107, imax(u8) - 106, 61e0,           imax(u8) - 109, imax(u8) - 108, 62e0,           imax(u8) - 111,
                imax(u8) - 110, 63e0,           imax(u8) - 113, imax(u8) - 112, 64e0,           imax(u8) - 115, imax(u8) - 114, 65e0,
                imax(u8) - 117, imax(u8) - 116, 66e0,           imax(u8) - 119, imax(u8) - 118, 67e0,           imax(u8) - 121, imax(u8) - 120,
                68e0,           imax(u8) - 123, imax(u8) - 122, 69e0,           imax(u8) - 125, imax(u8) - 124, 71e0,           imax(u8) - 127,
                imax(u8) - 126, 72e0,           imax(u8) - 129, imax(u8) - 128, 73e0,           imax(u8) - 131, imax(u8) - 130, 74e0,
                imax(u8) - 133, imax(u8) - 132, 75e0,           imax(u8) - 135, imax(u8) - 134, 76e0,           imax(u8) - 137, imax(u8) - 136,
                77e0,           imax(u8) - 139, imax(u8) - 138, 78e0,           imax(u8) - 141, imax(u8) - 140, 79e0,           imax(u8) - 143,
                imax(u8) - 142, 81e0,           imax(u8) - 145, imax(u8) - 144, 82e0,           imax(u8) - 147, imax(u8) - 146, 83e0,
                imax(u8) - 149, imax(u8) - 148, 84e0,           imax(u8) - 151, imax(u8) - 150, 85e0,           imax(u8) - 153, imax(u8) - 152,
            });

            try testArgs(@Vector(1, f16), @Vector(1, i16), .{
                imin(i16),
            });
            try testArgs(@Vector(2, f16), @Vector(2, i16), .{
                imin(i16) + 1, -1e4,
            });
            try testArgs(@Vector(4, f16), @Vector(4, i16), .{
                -1e3, -1e2, -1e1, -1e0,
            });
            try testArgs(@Vector(8, f16), @Vector(8, i16), .{
                0, 1e0, 1e1, 1e2, 1e3, 1e4, imax(i16) - 1, imax(i16),
            });
            try testArgs(@Vector(16, f16), @Vector(16, i16), .{
                imin(i16) + 2, imin(i16) + 3, -2e4, -2e3, -2e2,          -2e1,          -2e0,          2e0,
                2e1,           2e2,           2e3,  2e4,  imax(i16) - 3, imax(i16) - 2, imin(i16) + 4, imin(i16) + 5,
            });
            try testArgs(@Vector(32, f16), @Vector(32, i16), .{
                -3e4,          -3e3,          -3e2,          -3e1,          -3e0,          3e0,           3e1,           3e2,
                3e3,           3e4,           imax(i16) - 5, imax(i16) - 4, imin(i16) + 6, imin(i16) + 7, -4e3,          -4e2,
                -4e1,          -4e0,          4e0,           4e1,           4e2,           4e3,           imax(i16) - 7, imax(i16) - 6,
                imin(i16) + 8, imin(i16) + 9, -5e3,          -5e2,          -5e1,          -5e0,          5e0,           5e1,
            });
            try testArgs(@Vector(64, f16), @Vector(64, i16), .{
                5e2,            5e3,            imax(i16) - 9,  imax(i16) - 8,  imin(i16) + 10, imin(i16) + 11, -6e3,           -6e2,
                -6e1,           -6e0,           6e0,            6e1,            6e2,            6e3,            imax(i16) - 11, imax(i16) - 10,
                imin(i16) + 12, imin(i16) + 13, -7e3,           -7e2,           -7e1,           -7e0,           7e0,            7e1,
                7e2,            7e3,            imax(i16) - 13, imax(i16) - 12, imin(i16) + 14, imin(i16) + 15, -8e3,           -8e2,
                -8e1,           -8e0,           8e0,            8e1,            8e2,            8e3,            imax(i16) - 15, imax(i16) - 14,
                imin(i16) + 16, imin(i16) + 17, -9e3,           -9e2,           -9e1,           -9e0,           9e0,            9e1,
                9e2,            9e3,            imax(i16) - 17, imax(i16) - 16, imin(i16) + 18, imin(i16) + 19, -11e3,          -11e2,
                -11e1,          -11e0,          11e0,           11e1,           11e2,           11e3,           imax(i16) - 19, imax(i16) - 18,
            });
            try testArgs(@Vector(128, f16), @Vector(128, i16), .{
                imin(i16) + 20, imin(i16) + 21, -12e3,          -12e2,          -12e1,          -12e0,          12e0,           12e1,
                12e2,           12e3,           imax(i16) - 21, imax(i16) - 20, imin(i16) + 22, imin(i16) + 23, -13e3,          -13e2,
                -13e1,          -13e0,          13e0,           13e1,           13e2,           13e3,           imax(i16) - 23, imax(i16) - 22,
                imin(i16) + 24, imin(i16) + 25, -14e3,          -14e2,          -14e1,          -14e0,          14e0,           14e1,
                14e2,           14e3,           imax(i16) - 25, imax(i16) - 24, imin(i16) + 26, imin(i16) + 27, -15e3,          -15e2,
                -15e1,          -15e0,          15e0,           15e1,           15e2,           15e3,           imax(i16) - 27, imax(i16) - 26,
                imin(i16) + 28, imin(i16) + 29, -16e3,          -16e2,          -16e1,          -16e0,          16e0,           16e1,
                16e2,           16e3,           imax(i16) - 29, imax(i16) - 28, imin(i16) + 30, imin(i16) + 31, -17e3,          -17e2,
                -17e1,          -17e0,          17e0,           17e1,           17e2,           17e3,           imax(i16) - 31, imax(i16) - 30,
                imin(i16) + 32, imin(i16) + 33, -18e3,          -18e2,          -18e1,          -18e0,          18e0,           18e1,
                18e2,           18e3,           imax(i16) - 33, imax(i16) - 32, imin(i16) + 34, imin(i16) + 35, -19e3,          -19e2,
                -19e1,          -19e0,          19e0,           19e1,           19e2,           19e3,           imax(i16) - 35, imax(i16) - 34,
                imin(i16) + 36, imin(i16) + 37, -12e3,          -21e2,          -21e1,          -21e0,          21e0,           21e1,
                21e2,           21e3,           imax(i16) - 37, imax(i16) - 36, imin(i16) + 38, imin(i16) + 39, -22e3,          -22e2,
                -22e1,          -22e0,          22e0,           22e1,           22e2,           22e3,           imax(i16) - 39, imax(i16) - 38,
                imin(i16) + 40, imin(i16) + 41, -23e3,          -23e2,          -23e1,          -23e0,          23e0,           23e1,
            });

            try testArgs(@Vector(1, f16), @Vector(1, u16), .{
                0,
            });
            try testArgs(@Vector(2, f16), @Vector(2, u16), .{
                1e0, 1e1,
            });
            try testArgs(@Vector(4, f16), @Vector(4, u16), .{
                1e2, 1e3, 1e4, imax(u16) - 1,
            });
            try testArgs(@Vector(8, f16), @Vector(8, u16), .{
                imax(u16), 2e0, 2e1, 2e2, 2e3, 2e4, imax(u16) - 3, imax(u16) - 2,
            });
            try testArgs(@Vector(16, f16), @Vector(16, u16), .{
                3e0, 3e1, 3e2, 3e3, 3e4,           imax(u16) - 5, imax(u16) - 4, 4e0,
                4e1, 4e2, 4e3, 4e4, imax(u16) - 7, imax(u16) - 6, 5e0,           5e1,
            });
            try testArgs(@Vector(32, f16), @Vector(32, u16), .{
                5e2,            5e3,            5e4,            imax(u16) - 9,  imax(u16) - 8,  6e0,            6e1,            6e2,
                6e3,            6e4,            imax(u16) - 11, imax(u16) - 10, 7e0,            7e1,            7e2,            7e3,
                imax(u16) - 13, imax(u16) - 12, 8e0,            8e1,            8e2,            8e3,            imax(u16) - 15, imax(u16) - 14,
                9e0,            9e1,            9e2,            9e3,            imax(u16) - 17, imax(u16) - 16, 11e0,           11e1,
            });
            try testArgs(@Vector(64, f16), @Vector(64, u16), .{
                11e2,           11e3,           imax(u16) - 19, imax(u16) - 18, 12e0,           12e1,           12e2,           12e3,
                imax(u16) - 21, imax(u16) - 20, 13e0,           13e1,           13e2,           13e3,           imax(u16) - 23, imax(u16) - 22,
                14e0,           14e1,           14e2,           14e3,           imax(u16) - 25, imax(u16) - 24, 15e0,           15e1,
                15e2,           15e3,           imax(u16) - 27, imax(u16) - 26, 16e0,           16e1,           16e2,           16e3,
                imax(u16) - 29, imax(u16) - 28, 17e0,           17e1,           17e2,           17e3,           imax(u16) - 31, imax(u16) - 30,
                18e0,           18e1,           18e2,           18e3,           imax(u16) - 33, imax(u16) - 32, 19e0,           19e1,
                19e2,           19e3,           imax(u16) - 35, imax(u16) - 34, 21e0,           21e1,           21e2,           21e3,
                imax(u16) - 37, imax(u16) - 36, 22e0,           22e1,           22e2,           22e3,           imax(u16) - 39, imax(u16) - 38,
            });
            try testArgs(@Vector(128, f16), @Vector(128, u16), .{
                23e0,           23e1,           23e2,           23e3,           imax(u16) - 41, imax(u16) - 40, 24e0,           24e1,
                24e2,           24e3,           imax(u16) - 43, imax(u16) - 42, 25e0,           25e1,           25e2,           25e3,
                imax(u16) - 45, imax(u16) - 44, 26e0,           26e1,           26e2,           26e3,           imax(u16) - 47, imax(u16) - 46,
                27e0,           27e1,           27e2,           27e3,           imax(u16) - 49, imax(u16) - 48, 28e0,           28e1,
                28e2,           28e3,           imax(u16) - 51, imax(u16) - 50, 29e0,           29e1,           29e2,           29e3,
                imax(u16) - 53, imax(u16) - 52, 31e0,           31e1,           31e2,           31e3,           imax(u16) - 55, imax(u16) - 54,
                32e0,           32e1,           32e2,           32e3,           imax(u16) - 57, imax(u16) - 56, 33e0,           33e1,
                33e2,           33e3,           imax(u16) - 59, imax(u16) - 58, 34e0,           34e1,           34e2,           34e3,
                imax(u16) - 61, imax(u16) - 60, 35e0,           35e1,           35e2,           35e3,           imax(u16) - 63, imax(u16) - 62,
                36e0,           36e1,           36e2,           36e3,           imax(u16) - 65, imax(u16) - 64, 37e0,           37e1,
                37e2,           37e3,           imax(u16) - 67, imax(u16) - 66, 38e0,           38e1,           38e2,           38e3,
                imax(u16) - 69, imax(u16) - 68, 39e0,           39e1,           39e2,           39e3,           imax(u16) - 71, imax(u16) - 70,
                41e0,           41e1,           41e2,           41e3,           imax(u16) - 73, imax(u16) - 72, 42e0,           42e1,
                42e2,           42e3,           imax(u16) - 75, imax(u16) - 74, 43e0,           43e1,           43e2,           43e3,
                imax(u16) - 77, imax(u16) - 76, 44e0,           44e1,           44e2,           44e3,           imax(u16) - 79, imax(u16) - 78,
                45e0,           45e1,           45e2,           45e3,           imax(u16) - 81, imax(u16) - 80, 46e0,           46e1,
            });

            try testArgs(@Vector(1, f16), @Vector(1, i32), .{
                imin(i32),
            });
            try testArgs(@Vector(2, f16), @Vector(2, i32), .{
                imin(i32) + 1, -1e9,
            });
            try testArgs(@Vector(4, f16), @Vector(4, i32), .{
                -1e8, -1e7, -1e6, -1e5,
            });
            try testArgs(@Vector(8, f16), @Vector(8, i32), .{
                -1e4, -1e3, -1e2, -1e1, -1e0, 0, 1e0, 1e1,
            });
            try testArgs(@Vector(16, f16), @Vector(16, i32), .{
                1e2,           1e3,       1e4,           1e5,           1e6,  1e7,  1e8,  1e9,
                imax(i32) - 1, imax(i32), imin(i32) + 2, imin(i32) + 3, -2e9, -2e8, -2e7, -2e6,
            });
            try testArgs(@Vector(32, f16), @Vector(32, i32), .{
                -2e5,          -2e4,          -2e3,          -2e2,          -2e1, -2e0, 2e0,  2e1,
                2e2,           2e3,           2e4,           2e5,           2e6,  2e7,  2e8,  2e9,
                imax(i32) - 3, imax(i32) - 2, imin(i32) + 4, imin(i32) + 5, -3e8, -3e7, -3e6, -3e5,
                -3e4,          -3e3,          -3e2,          -3e1,          -3e0, 3e0,  3e1,  3e2,
            });
            try testArgs(@Vector(64, f16), @Vector(64, i32), .{
                3e3,           3e4,           3e5,           3e6,           3e7,            3e8,            imax(i32) - 5, imax(i32) - 4,
                imin(i32) + 6, imin(i32) + 7, -4e8,          -4e7,          -4e6,           -4e5,           -4e4,          -4e3,
                -4e2,          -4e1,          -4e0,          4e0,           4e1,            4e2,            4e3,           4e4,
                4e5,           4e6,           4e7,           4e8,           imax(i32) - 7,  imax(i32) - 6,  imin(i32) + 8, imin(i32) + 9,
                -5e8,          -5e7,          -5e6,          -5e5,          -5e4,           -5e3,           -5e2,          -5e1,
                -5e0,          5e0,           5e1,           5e2,           5e3,            5e4,            5e5,           5e6,
                5e7,           5e8,           imax(i32) - 9, imax(i32) - 8, imin(i32) + 10, imin(i32) + 11, -6e8,          -6e7,
                -6e6,          -6e5,          -6e4,          -6e3,          -6e2,           -6e1,           -6e0,          6e0,
            });
            try testArgs(@Vector(128, f16), @Vector(128, i32), .{
                6e1,            6e2,            6e3,            6e4,            6e5,            6e6,            6e7,            6e8,
                imax(i32) - 11, imax(i32) - 10, imin(i32) + 12, imin(i32) + 13, -7e8,           -7e7,           -7e6,           -7e5,
                -7e4,           -7e3,           -7e2,           -7e1,           -7e0,           7e0,            7e1,            7e2,
                7e3,            7e4,            7e5,            7e6,            7e7,            7e8,            imax(i32) - 13, imax(i32) - 12,
                imin(i32) + 14, imin(i32) + 15, -8e8,           -8e7,           -8e6,           -8e5,           -8e4,           -8e3,
                -8e2,           -8e1,           -8e0,           8e0,            8e1,            8e2,            8e3,            8e4,
                8e5,            8e6,            8e7,            8e8,            imax(i32) - 15, imax(i32) - 14, imin(i32) + 16, imin(i32) + 17,
                -9e8,           -9e7,           -9e6,           -9e5,           -9e4,           -9e3,           -9e2,           -9e1,
                -9e0,           9e0,            9e1,            9e2,            9e3,            9e4,            9e5,            9e6,
                9e7,            9e8,            imax(i32) - 17, imax(i32) - 16, imin(i32) + 18, imin(i32) + 19, -11e8,          -11e7,
                -11e6,          -11e5,          -11e4,          -11e3,          -11e2,          -11e1,          -11e0,          11e0,
                11e1,           11e2,           11e3,           11e4,           11e5,           11e6,           11e7,           11e8,
                imax(i32) - 19, imax(i32) - 18, imin(i32) + 20, imin(i32) + 21, -12e8,          -12e7,          -12e6,          -12e5,
                -12e4,          -12e3,          -12e2,          -12e1,          -12e0,          12e0,           12e1,           12e2,
                12e3,           12e4,           12e5,           12e6,           12e7,           12e8,           imax(i32) - 21, imax(i32) - 20,
                imin(i32) + 22, imin(i32) + 23, -13e8,          -13e7,          -13e6,          -13e5,          -13e4,          -13e3,
            });

            try testArgs(@Vector(1, f16), @Vector(1, u32), .{
                0,
            });
            try testArgs(@Vector(2, f16), @Vector(2, u32), .{
                1e0, 1e1,
            });
            try testArgs(@Vector(4, f16), @Vector(4, u32), .{
                1e2, 1e3, 1e4, imax(u32) - 1,
            });
            try testArgs(@Vector(8, f16), @Vector(8, u32), .{
                imax(u32), 2e0, 2e1, 2e2, 2e3, 2e4, imax(u32) - 3, imax(u32) - 2,
            });
            try testArgs(@Vector(16, f16), @Vector(16, u32), .{
                3e0, 3e1, 3e2, 3e3, 3e4,           imax(u32) - 5, imax(u32) - 4, 4e0,
                4e1, 4e2, 4e3, 4e4, imax(u32) - 7, imax(u32) - 6, 5e0,           5e1,
            });
            try testArgs(@Vector(32, f16), @Vector(32, u32), .{
                5e2,            5e3,            5e4,            imax(u32) - 9,  imax(u32) - 8,  6e0,            6e1,            6e2,
                6e3,            6e4,            imax(u32) - 11, imax(u32) - 10, 7e0,            7e1,            7e2,            7e3,
                imax(u32) - 13, imax(u32) - 12, 8e0,            8e1,            8e2,            8e3,            imax(u32) - 15, imax(u32) - 14,
                9e0,            9e1,            9e2,            9e3,            imax(u32) - 17, imax(u32) - 16, 11e0,           11e1,
            });
            try testArgs(@Vector(64, f16), @Vector(64, u32), .{
                11e2,           11e3,           imax(u32) - 19, imax(u32) - 18, 12e0,           12e1,           12e2,           12e3,
                imax(u32) - 21, imax(u32) - 20, 13e0,           13e1,           13e2,           13e3,           imax(u32) - 23, imax(u32) - 22,
                14e0,           14e1,           14e2,           14e3,           imax(u32) - 25, imax(u32) - 24, 15e0,           15e1,
                15e2,           15e3,           imax(u32) - 27, imax(u32) - 26, 16e0,           16e1,           16e2,           16e3,
                imax(u32) - 29, imax(u32) - 28, 17e0,           17e1,           17e2,           17e3,           imax(u32) - 31, imax(u32) - 30,
                18e0,           18e1,           18e2,           18e3,           imax(u32) - 33, imax(u32) - 32, 19e0,           19e1,
                19e2,           19e3,           imax(u32) - 35, imax(u32) - 34, 21e0,           21e1,           21e2,           21e3,
                imax(u32) - 37, imax(u32) - 36, 22e0,           22e1,           22e2,           22e3,           imax(u32) - 39, imax(u32) - 38,
            });
            try testArgs(@Vector(128, f16), @Vector(128, u32), .{
                23e0,           23e1,           23e2,           23e3,           imax(u32) - 41, imax(u32) - 40, 24e0,           24e1,
                24e2,           24e3,           imax(u32) - 43, imax(u32) - 42, 25e0,           25e1,           25e2,           25e3,
                imax(u32) - 45, imax(u32) - 44, 26e0,           26e1,           26e2,           26e3,           imax(u32) - 47, imax(u32) - 46,
                27e0,           27e1,           27e2,           27e3,           imax(u32) - 49, imax(u32) - 48, 28e0,           28e1,
                28e2,           28e3,           imax(u32) - 51, imax(u32) - 50, 29e0,           29e1,           29e2,           29e3,
                imax(u32) - 53, imax(u32) - 52, 31e0,           31e1,           31e2,           31e3,           imax(u32) - 55, imax(u32) - 54,
                32e0,           32e1,           32e2,           32e3,           imax(u32) - 57, imax(u32) - 56, 33e0,           33e1,
                33e2,           33e3,           imax(u32) - 59, imax(u32) - 58, 34e0,           34e1,           34e2,           34e3,
                imax(u32) - 61, imax(u32) - 60, 35e0,           35e1,           35e2,           35e3,           imax(u32) - 63, imax(u32) - 62,
                36e0,           36e1,           36e2,           36e3,           imax(u32) - 65, imax(u32) - 64, 37e0,           37e1,
                37e2,           37e3,           imax(u32) - 67, imax(u32) - 66, 38e0,           38e1,           38e2,           38e3,
                imax(u32) - 69, imax(u32) - 68, 39e0,           39e1,           39e2,           39e3,           imax(u32) - 71, imax(u32) - 70,
                41e0,           41e1,           41e2,           41e3,           imax(u32) - 73, imax(u32) - 72, 42e0,           42e1,
                42e2,           42e3,           imax(u32) - 75, imax(u32) - 74, 43e0,           43e1,           43e2,           43e3,
                imax(u32) - 77, imax(u32) - 76, 44e0,           44e1,           44e2,           44e3,           imax(u32) - 79, imax(u32) - 78,
                45e0,           45e1,           45e2,           45e3,           imax(u32) - 81, imax(u32) - 80, 46e0,           46e1,
            });

            try testArgs(@Vector(1, f16), @Vector(1, i64), .{
                imin(i64),
            });
            try testArgs(@Vector(2, f16), @Vector(2, i64), .{
                imin(i64) + 1, -1e18,
            });
            try testArgs(@Vector(4, f16), @Vector(4, i64), .{
                -1e17, -1e16, -1e15, -1e14,
            });
            try testArgs(@Vector(8, f16), @Vector(8, i64), .{
                -1e13, -1e12, -1e11, -1e10, -1e9, -1e8, -1e7, -1e6,
            });
            try testArgs(@Vector(16, f16), @Vector(16, i64), .{
                -1e5, -1e4, -1e3, -1e2, -1e1, -1e0, 0,   1e0,
                1e1,  1e2,  1e3,  1e4,  1e5,  1e6,  1e7, 1e8,
            });
            try testArgs(@Vector(32, f16), @Vector(32, i64), .{
                1e9,   1e10,  1e11,          1e12,      1e13,          1e14,          1e15,  1e16,
                1e17,  1e18,  imax(i64) - 1, imax(i64), imin(i64) + 2, imin(i64) + 3, -2e18, -2e17,
                -2e16, -2e15, -2e14,         -2e13,     -2e12,         -2e11,         -2e10, -2e9,
                -2e8,  -2e7,  -2e6,          -2e5,      -2e4,          -2e3,          -2e2,  -2e1,
            });
            try testArgs(@Vector(64, f16), @Vector(64, i64), .{
                -2e0,  2e0,   2e1,   2e2,   2e3,           2e4,           2e5,           2e6,
                2e7,   2e8,   2e9,   2e10,  2e11,          2e12,          2e13,          2e14,
                2e15,  2e16,  2e17,  2e18,  imax(i64) - 3, imax(i64) - 2, imin(i64) + 4, imin(i64) + 5,
                -3e18, -3e17, -3e16, -3e15, -3e14,         -3e13,         -3e12,         -3e11,
                -3e10, -3e9,  -3e8,  -3e7,  -3e6,          -3e5,          -3e4,          -3e3,
                -3e2,  -3e1,  -3e0,  3e0,   3e1,           3e2,           3e3,           3e4,
                3e5,   3e6,   3e7,   3e8,   3e9,           3e10,          3e11,          3e12,
                3e13,  3e14,  3e15,  3e16,  3e17,          3e18,          imax(i64) - 5, imax(i64) - 4,
            });
            try testArgs(@Vector(128, f16), @Vector(128, i64), .{
                imin(i64) + 6, imin(i64) + 7, -4e18,         -4e17,         -4e16,          -4e15,          -4e14,          -4e13,
                -4e12,         -4e11,         -4e10,         -4e9,          -4e8,           -4e7,           -4e6,           -4e5,
                -4e4,          -4e3,          -4e2,          -4e1,          -4e0,           4e0,            4e1,            4e2,
                4e3,           4e4,           4e5,           4e6,           4e7,            4e8,            4e9,            4e10,
                4e11,          4e12,          4e13,          4e14,          4e15,           4e16,           4e17,           4e18,
                imax(i64) - 7, imax(i64) - 6, imin(i64) + 8, imin(i64) + 9, -5e18,          -5e17,          -5e16,          -5e15,
                -5e14,         -5e13,         -5e12,         -5e11,         -5e10,          -5e9,           -5e8,           -5e7,
                -5e6,          -5e5,          -5e4,          -5e3,          -5e2,           -5e1,           -5e0,           5e0,
                5e1,           5e2,           5e3,           5e4,           5e5,            5e6,            5e7,            5e8,
                5e9,           5e10,          5e11,          5e12,          5e13,           5e14,           5e15,           5e16,
                5e17,          5e18,          imax(i64) - 9, imax(i64) - 8, imin(i64) + 10, imin(i64) + 11, -6e18,          -6e17,
                -6e16,         -6e15,         -6e14,         -6e13,         -6e12,          -6e11,          -6e10,          -6e9,
                -6e8,          -6e7,          -6e6,          -6e5,          -6e4,           -6e3,           -6e2,           -6e1,
                -6e0,          6e0,           6e1,           6e2,           6e3,            6e4,            6e5,            6e6,
                6e7,           6e8,           6e9,           6e10,          6e11,           6e12,           6e13,           6e14,
                6e15,          6e16,          6e17,          6e18,          imax(i64) - 11, imax(i64) - 10, imin(i64) + 12, imin(i64) + 13,
            });

            try testArgs(@Vector(1, f16), @Vector(1, u64), .{
                0,
            });
            try testArgs(@Vector(2, f16), @Vector(2, u64), .{
                1e0, 1e1,
            });
            try testArgs(@Vector(4, f16), @Vector(4, u64), .{
                1e2, 1e3, 1e4, 1e5,
            });
            try testArgs(@Vector(8, f16), @Vector(8, u64), .{
                1e6, 1e7, 1e8, 1e9, 1e10, 1e11, 1e12, 1e13,
            });
            try testArgs(@Vector(16, f16), @Vector(16, u64), .{
                1e14, 1e15, 1e16, 1e17, 1e18, 1e19, imax(u64) - 1, imax(u64),
                2e0,  2e1,  2e2,  2e3,  2e4,  2e5,  2e6,           2e7,
            });
            try testArgs(@Vector(32, f16), @Vector(32, u64), .{
                2e8,  2e9,  2e10, 2e11,          2e12,          2e13, 2e14, 2e15,
                2e16, 2e17, 2e18, imax(u64) - 3, imax(u64) - 2, 3e0,  3e1,  3e2,
                3e3,  3e4,  3e5,  3e6,           3e7,           3e8,  3e9,  3e10,
                3e11, 3e12, 3e13, 3e14,          3e15,          3e16, 3e17, 3e18,
            });
            try testArgs(@Vector(64, f16), @Vector(64, u64), .{
                imax(u64) - 5, imax(u64) - 4, 4e0,           4e1,           4e2,  4e3,           4e4,           4e5,
                4e6,           4e7,           4e8,           4e9,           4e10, 4e11,          4e12,          4e13,
                4e14,          4e15,          4e16,          4e17,          4e18, imax(u64) - 7, imax(u64) - 6, 5e0,
                5e1,           5e2,           5e3,           5e4,           5e5,  5e6,           5e7,           5e8,
                5e9,           5e10,          5e11,          5e12,          5e13, 5e14,          5e15,          5e16,
                5e17,          5e18,          imax(u64) - 9, imax(u64) - 8, 6e0,  6e1,           6e2,           6e3,
                6e4,           6e5,           6e6,           6e7,           6e8,  6e9,           6e10,          6e11,
                6e12,          6e13,          6e14,          6e15,          6e16, 6e17,          6e18,          imax(u64) - 11,
            });
            try testArgs(@Vector(128, f16), @Vector(128, u64), .{
                imax(u64) - 10, 7e0,            7e1,            7e2,            7e3,            7e4,            7e5,            7e6,
                7e7,            7e8,            7e9,            7e10,           7e11,           7e12,           7e13,           7e14,
                7e15,           7e16,           7e17,           7e18,           imax(u64) - 13, imax(u64) - 12, 8e0,            8e1,
                8e2,            8e3,            8e4,            8e5,            8e6,            8e7,            8e8,            8e9,
                8e10,           8e11,           8e12,           8e13,           8e14,           8e15,           8e16,           8e17,
                8e18,           imax(u64) - 15, imax(u64) - 14, 9e0,            9e1,            9e2,            9e3,            9e4,
                9e5,            9e6,            9e7,            9e8,            9e9,            9e10,           9e11,           9e12,
                9e13,           9e14,           9e15,           9e16,           9e17,           9e18,           imax(u64) - 17, imax(u64) - 16,
                11e0,           11e1,           11e2,           11e3,           11e4,           11e5,           11e6,           11e7,
                11e8,           11e9,           11e10,          11e11,          11e12,          11e13,          11e14,          11e15,
                11e16,          11e17,          11e18,          imax(u64) - 19, imax(u64) - 18, 12e0,           12e1,           12e2,
                12e3,           12e4,           12e5,           12e6,           12e7,           12e8,           12e9,           12e10,
                12e11,          12e12,          12e13,          12e14,          12e15,          12e16,          12e17,          12e18,
                imax(u64) - 21, imax(u64) - 20, 13e0,           13e1,           13e2,           13e3,           13e4,           13e5,
                13e6,           13e7,           13e8,           13e9,           13e10,          13e11,          13e12,          13e13,
                13e14,          13e15,          13e16,          13e17,          13e18,          imax(u64) - 23, imax(u64) - 22, 14e0,
            });

            try testArgs(@Vector(1, f16), @Vector(1, i128), .{
                imin(i128),
            });
            try testArgs(@Vector(2, f16), @Vector(2, i128), .{
                imin(i128) + 1, -1e38,
            });
            try testArgs(@Vector(4, f16), @Vector(4, i128), .{
                -1e37, -1e36, -1e35, -1e34,
            });
            try testArgs(@Vector(8, f16), @Vector(8, i128), .{
                -1e33, -1e32, -1e31, -1e30, -1e29, -1e28, -1e27, -1e26,
            });
            try testArgs(@Vector(16, f16), @Vector(16, i128), .{
                -1e25, -1e24, -1e23, -1e22, -1e21, -1e20, -1e19, -1e18,
                -1e17, -1e16, -1e15, -1e14, -1e13, -1e12, -1e11, -1e10,
            });
            try testArgs(@Vector(32, f16), @Vector(32, i128), .{
                -1e9, -1e8, -1e7, -1e6, -1e5, -1e4, -1e3, -1e2,
                -1e1, -1e0, 0,    1e0,  1e1,  1e2,  1e3,  1e4,
                1e5,  1e6,  1e7,  1e8,  1e9,  1e10, 1e11, 1e12,
                1e13, 1e14, 1e15, 1e16, 1e17, 1e18, 1e19, 1e20,
            });
            try testArgs(@Vector(64, f16), @Vector(64, i128), .{
                1e21,  1e22,  1e23,           1e24,       1e25,           1e26,           1e27,  1e28,
                1e29,  1e30,  1e31,           1e32,       1e33,           1e34,           1e35,  1e36,
                1e37,  1e38,  imax(i128) - 1, imax(i128), imin(i128) + 2, imin(i128) + 3, -2e37, -2e36,
                -2e35, -2e34, -2e33,          -2e32,      -2e31,          -2e30,          -2e29, -2e28,
                -2e27, -2e26, -2e25,          -2e24,      -2e23,          -2e22,          -2e21, -2e20,
                -2e19, -2e18, -2e17,          -2e16,      -2e15,          -2e14,          -2e13, -2e12,
                -2e11, -2e10, -2e9,           -2e8,       -2e7,           -2e6,           -2e5,  -2e4,
                -2e3,  -2e2,  -2e1,           -2e0,       2e0,            2e1,            2e2,   2e3,
            });
            try testArgs(@Vector(128, f16), @Vector(128, i128), .{
                2e4,   2e5,   2e6,            2e7,            2e8,            2e9,            2e10,  2e11,
                2e12,  2e13,  2e14,           2e15,           2e16,           2e17,           2e18,  2e19,
                2e20,  2e21,  2e22,           2e23,           2e24,           2e25,           2e26,  2e27,
                2e28,  2e29,  2e30,           2e31,           2e32,           2e33,           2e34,  2e35,
                2e36,  2e37,  imax(i128) - 3, imax(i128) - 2, imin(i128) + 4, imin(i128) + 5, -3e37, -3e36,
                -3e35, -3e34, -3e33,          -3e32,          -3e31,          -3e30,          -3e29, -3e28,
                -3e27, -3e26, -3e25,          -3e24,          -3e23,          -3e22,          -3e21, -3e20,
                -3e19, -3e18, -3e17,          -3e16,          -3e15,          -3e14,          -3e13, -3e12,
                -3e11, -3e10, -3e9,           -3e8,           -3e7,           -3e6,           -3e5,  -3e4,
                -3e3,  -3e2,  -3e1,           -3e0,           3e0,            3e1,            3e2,   3e3,
                3e4,   3e5,   3e6,            3e7,            3e8,            3e9,            3e10,  3e11,
                3e12,  3e13,  3e14,           3e15,           3e16,           3e17,           3e18,  3e19,
                3e20,  3e21,  3e22,           3e23,           3e24,           3e25,           3e26,  3e27,
                3e28,  3e29,  3e30,           3e31,           3e32,           3e33,           3e34,  3e35,
                3e36,  3e37,  imax(i128) - 5, imax(i128) - 4, imin(i128) + 6, imin(i128) + 7, -4e37, -4e36,
                -4e35, -4e34, -4e33,          -4e32,          -4e31,          -4e30,          -4e29, -4e28,
            });

            try testArgs(@Vector(1, f16), @Vector(1, u128), .{
                0,
            });
            try testArgs(@Vector(2, f16), @Vector(2, u128), .{
                1e0, 1e1,
            });
            try testArgs(@Vector(4, f16), @Vector(4, u128), .{
                1e2, 1e3, 1e4, 1e5,
            });
            try testArgs(@Vector(8, f16), @Vector(8, u128), .{
                1e6, 1e7, 1e8, 1e9, 1e10, 1e11, 1e12, 1e13,
            });
            try testArgs(@Vector(16, f16), @Vector(16, u128), .{
                1e14, 1e15, 1e16, 1e17, 1e18, 1e19, 1e20, 1e21,
                1e22, 1e23, 1e24, 1e25, 1e26, 1e27, 1e28, 1e29,
            });
            try testArgs(@Vector(32, f16), @Vector(32, u128), .{
                1e30, 1e31,           1e32,       1e33, 1e34, 1e35, 1e36, 1e37,
                1e38, imax(u128) - 1, imax(u128), 2e0,  2e1,  2e2,  2e3,  2e4,
                2e5,  2e6,            2e7,        2e8,  2e9,  2e10, 2e11, 2e12,
                2e13, 2e14,           2e15,       2e16, 2e17, 2e18, 2e19, 2e20,
            });
            try testArgs(@Vector(64, f16), @Vector(64, u128), .{
                2e21, 2e22, 2e23,           2e24,           2e25,           2e26, 2e27, 2e28,
                2e29, 2e30, 2e31,           2e32,           2e33,           2e34, 2e35, 2e36,
                2e37, 2e38, imax(u128) - 3, imax(u128) - 2, 3e0,            3e1,  3e2,  3e3,
                3e4,  3e5,  3e6,            3e7,            3e8,            3e9,  3e10, 3e11,
                3e12, 3e13, 3e14,           3e15,           3e16,           3e17, 3e18, 3e19,
                3e20, 3e21, 3e22,           3e23,           3e24,           3e25, 3e26, 3e27,
                3e28, 3e29, 3e30,           3e31,           3e32,           3e33, 3e34, 3e35,
                3e36, 3e37, 3e38,           imax(u128) - 5, imax(u128) - 4, 4e0,  4e1,  4e2,
            });
            try testArgs(@Vector(128, f16), @Vector(128, u128), .{
                4e3,  4e4,  4e5,  4e6,             4e7,             4e8,  4e9,  4e10,
                4e11, 4e12, 4e13, 4e14,            4e15,            4e16, 4e17, 4e18,
                4e19, 4e20, 4e21, 4e22,            4e23,            4e24, 4e25, 4e26,
                4e27, 4e28, 4e29, 4e30,            4e31,            4e32, 4e33, 4e34,
                4e35, 4e36, 4e37, imax(u128) - 7,  imax(u128) - 6,  5e0,  5e1,  5e2,
                5e3,  5e4,  5e5,  5e6,             5e7,             5e8,  5e9,  5e10,
                5e11, 5e12, 5e13, 5e14,            5e15,            5e16, 5e17, 5e18,
                5e19, 5e20, 5e21, 5e22,            5e23,            5e24, 5e25, 5e26,
                5e27, 5e28, 5e29, 5e30,            5e31,            5e32, 5e33, 5e34,
                5e35, 5e36, 5e37, imax(u128) - 9,  imax(u128) - 8,  6e0,  6e1,  6e2,
                6e3,  6e4,  6e5,  6e6,             6e7,             6e8,  6e9,  6e10,
                6e11, 6e12, 6e13, 6e14,            6e15,            6e16, 6e17, 6e18,
                6e19, 6e20, 6e21, 6e22,            6e23,            6e24, 6e25, 6e26,
                6e27, 6e28, 6e29, 6e30,            6e31,            6e32, 6e33, 6e34,
                6e35, 6e36, 6e37, imax(u128) - 11, imax(u128) - 10, 7e0,  7e1,  7e2,
                7e3,  7e4,  7e5,  7e6,             7e7,             7e8,  7e9,  7e10,
            });

            try testArgs(@Vector(1, f16), @Vector(1, i256), .{
                imin(i256),
            });
            try testArgs(@Vector(2, f16), @Vector(2, i256), .{
                imin(i256) + 1, -1e76,
            });
            try testArgs(@Vector(4, f16), @Vector(4, i256), .{
                -1e75, -1e74, -1e73, -1e72,
            });
            try testArgs(@Vector(8, f16), @Vector(8, i256), .{
                -1e71, -1e70, -1e69, -1e68, -1e67, -1e66, -1e65, -1e64,
            });
            try testArgs(@Vector(16, f16), @Vector(16, i256), .{
                -1e63, -1e62, -1e61, -1e60, -1e59, -1e58, -1e57, -1e56,
                -1e55, -1e54, -1e53, -1e52, -1e51, -1e50, -1e49, -1e48,
            });
            try testArgs(@Vector(32, f16), @Vector(32, i256), .{
                -1e47, -1e46, -1e45, -1e44, -1e43, -1e42, -1e41, -1e40,
                -1e39, -1e38, -1e37, -1e36, -1e35, -1e34, -1e33, -1e32,
                -1e31, -1e30, -1e29, -1e28, -1e27, -1e26, -1e25, -1e24,
                -1e23, -1e22, -1e21, -1e20, -1e19, -1e18, -1e17, -1e16,
            });
            try testArgs(@Vector(64, f16), @Vector(64, i256), .{
                -1e15, -1e14, -1e13, -1e12, -1e11, -1e10, -1e9, -1e8,
                -1e7,  -1e6,  -1e5,  -1e4,  -1e3,  -1e2,  -1e1, -1e0,
                0,     1e0,   1e1,   1e2,   1e3,   1e4,   1e5,  1e6,
                1e7,   1e8,   1e9,   1e10,  1e11,  1e12,  1e13, 1e14,
                1e15,  1e16,  1e17,  1e18,  1e19,  1e20,  1e21, 1e22,
                1e23,  1e24,  1e25,  1e26,  1e27,  1e28,  1e29, 1e30,
                1e31,  1e32,  1e33,  1e34,  1e35,  1e36,  1e37, 1e38,
                1e39,  1e40,  1e41,  1e42,  1e43,  1e44,  1e45, 1e46,
            });
            try testArgs(@Vector(128, f16), @Vector(128, i256), .{
                1e47,           1e48,           1e49,  1e50,  1e51,  1e52,  1e53,           1e54,
                1e55,           1e56,           1e57,  1e58,  1e59,  1e60,  1e61,           1e62,
                1e63,           1e64,           1e65,  1e66,  1e67,  1e68,  1e69,           1e70,
                1e71,           1e72,           1e73,  1e74,  1e75,  1e76,  imax(i256) - 1, imax(i256),
                imin(i256) + 2, imin(i256) + 3, -2e76, -2e75, -2e74, -2e73, -2e72,          -2e71,
                -2e70,          -2e69,          -2e68, -2e67, -2e66, -2e65, -2e64,          -2e63,
                -2e62,          -2e61,          -2e60, -2e59, -2e58, -2e57, -2e56,          -2e55,
                -2e54,          -2e53,          -2e52, -2e51, -2e50, -2e49, -2e48,          -2e47,
                -2e46,          -2e45,          -2e44, -2e43, -2e42, -2e41, -2e40,          -2e39,
                -2e38,          -2e37,          -2e36, -2e35, -2e34, -2e33, -2e32,          -2e31,
                -2e30,          -2e29,          -2e28, -2e27, -2e26, -2e25, -2e24,          -2e23,
                -2e22,          -2e21,          -2e20, -2e19, -2e18, -2e17, -2e16,          -2e15,
                -2e14,          -2e13,          -2e12, -2e11, -2e10, -2e9,  -2e8,           -2e7,
                -2e6,           -2e5,           -2e4,  -2e3,  -2e2,  -2e1,  -2e0,           2e0,
                2e1,            2e2,            2e3,   2e4,   2e5,   2e6,   2e7,            2e8,
                2e9,            2e10,           2e11,  2e12,  2e13,  2e14,  2e15,           2e16,
            });

            try testArgs(@Vector(1, f16), @Vector(1, u256), .{
                0,
            });
            try testArgs(@Vector(2, f16), @Vector(2, u256), .{
                1e0, 1e1,
            });
            try testArgs(@Vector(4, f16), @Vector(4, u256), .{
                1e2, 1e3, 1e4, 1e5,
            });
            try testArgs(@Vector(8, f16), @Vector(8, u256), .{
                1e6, 1e7, 1e8, 1e9, 1e10, 1e11, 1e12, 1e13,
            });
            try testArgs(@Vector(16, f16), @Vector(16, u256), .{
                1e14, 1e15, 1e16, 1e17, 1e18, 1e19, 1e20, 1e21,
                1e22, 1e23, 1e24, 1e25, 1e26, 1e27, 1e28, 1e29,
            });
            try testArgs(@Vector(32, f16), @Vector(32, u256), .{
                1e30, 1e31, 1e32, 1e33, 1e34, 1e35, 1e36, 1e37,
                1e38, 1e39, 1e40, 1e41, 1e42, 1e43, 1e44, 1e45,
                1e46, 1e47, 1e48, 1e49, 1e50, 1e51, 1e52, 1e53,
                1e54, 1e55, 1e56, 1e57, 1e58, 1e59, 1e60, 1e61,
            });
            try testArgs(@Vector(64, f16), @Vector(64, u256), .{
                1e62,           1e63,       1e64, 1e65, 1e66, 1e67, 1e68, 1e69,
                1e70,           1e71,       1e72, 1e73, 1e74, 1e75, 1e76, 1e77,
                imax(u256) - 1, imax(u256), 2e0,  2e1,  2e2,  2e3,  2e4,  2e5,
                2e6,            2e7,        2e8,  2e9,  2e10, 2e11, 2e12, 2e13,
                2e14,           2e15,       2e16, 2e17, 2e18, 2e19, 2e20, 2e21,
                2e22,           2e23,       2e24, 2e25, 2e26, 2e27, 2e28, 2e29,
                2e30,           2e31,       2e32, 2e33, 2e34, 2e35, 2e36, 2e37,
                2e38,           2e39,       2e40, 2e41, 2e42, 2e43, 2e44, 2e45,
            });
            try testArgs(@Vector(128, f16), @Vector(128, u256), .{
                2e46,           2e47, 2e48, 2e49, 2e50, 2e51, 2e52,           2e53,
                2e54,           2e55, 2e56, 2e57, 2e58, 2e59, 2e60,           2e61,
                2e62,           2e63, 2e64, 2e65, 2e66, 2e67, 2e68,           2e69,
                2e70,           2e71, 2e72, 2e73, 2e74, 2e75, 2e76,           imax(u256) - 3,
                imax(u256) - 2, 3e0,  3e1,  3e2,  3e3,  3e4,  3e5,            3e6,
                3e7,            3e8,  3e9,  3e10, 3e11, 3e12, 3e13,           3e14,
                3e15,           3e16, 3e17, 3e18, 3e19, 3e20, 3e21,           3e22,
                3e23,           3e24, 3e25, 3e26, 3e27, 3e28, 3e29,           3e30,
                3e31,           3e32, 3e33, 3e34, 3e35, 3e36, 3e37,           3e38,
                3e39,           3e40, 3e41, 3e42, 3e43, 3e44, 3e45,           3e46,
                3e47,           3e48, 3e49, 3e50, 3e51, 3e52, 3e53,           3e54,
                3e55,           3e56, 3e57, 3e58, 3e59, 3e60, 3e61,           3e62,
                3e63,           3e64, 3e65, 3e66, 3e67, 3e68, 3e69,           3e70,
                3e71,           3e72, 3e73, 3e74, 3e75, 3e76, imax(u256) - 5, imax(u256) - 4,
                4e0,            4e1,  4e2,  4e3,  4e4,  4e5,  4e6,            4e7,
                4e8,            4e9,  4e10, 4e11, 4e12, 4e13, 4e14,           4e15,
            });

            try testArgs(@Vector(1, f32), @Vector(1, i8), .{
                imin(i8),
            });
            try testArgs(@Vector(2, f32), @Vector(2, i8), .{
                imin(i8) + 1, -1e2,
            });
            try testArgs(@Vector(4, f32), @Vector(4, i8), .{
                -1e1, -1e0, 0, 1e0,
            });
            try testArgs(@Vector(8, f32), @Vector(8, i8), .{
                1e1, 1e2, imax(i8) - 1, imax(i8), imin(i8) + 2, imin(i8) + 3, -2e1, -2e0,
            });
            try testArgs(@Vector(16, f32), @Vector(16, i8), .{
                2e0, 2e1, imax(i8) - 3, imax(i8) - 2, imin(i8) + 4, imin(i8) + 5, -3e1, -3e0,
                3e0, 3e1, imax(i8) - 5, imax(i8) - 4, imin(i8) + 6, imin(i8) + 7, -4e1, -4e0,
            });
            try testArgs(@Vector(32, f32), @Vector(32, i8), .{
                4e0, 4e1, imax(i8) - 7,  imax(i8) - 6,  imin(i8) + 8,  imin(i8) + 9,  -5e1, -5e0,
                5e0, 5e1, imax(i8) - 9,  imax(i8) - 8,  imin(i8) + 10, imin(i8) + 11, -6e1, -6e0,
                6e0, 6e1, imax(i8) - 11, imax(i8) - 10, imin(i8) + 12, imin(i8) + 13, -7e1, -7e0,
                7e0, 7e1, imax(i8) - 13, imax(i8) - 12, imin(i8) + 14, imin(i8) + 15, -8e1, -8e0,
            });
            try testArgs(@Vector(64, f32), @Vector(64, i8), .{
                8e0,           8e1,           imax(i8) - 15, imax(i8) - 14, imin(i8) + 16, imin(i8) + 17, -9e1,          -9e0,
                9e0,           9e1,           imax(i8) - 17, imax(i8) - 16, imin(i8) + 18, imin(i8) + 19, -11e1,         -11e0,
                11e0,          11e1,          imax(i8) - 19, imax(i8) - 18, imin(i8) + 20, imin(i8) + 21, -12e1,         -12e0,
                12e0,          12e1,          imax(i8) - 21, imax(i8) - 20, imin(i8) + 22, imin(i8) + 23, -13e0,         13e0,
                imax(i8) - 23, imax(i8) - 22, imin(i8) + 24, imin(i8) + 25, -14e0,         14e0,          imax(i8) - 25, imax(i8) - 24,
                imin(i8) + 26, imin(i8) + 27, -15e0,         15e0,          imax(i8) - 27, imax(i8) - 26, imin(i8) + 28, imin(i8) + 29,
                -16e0,         16e0,          imax(i8) - 29, imax(i8) - 28, imin(i8) + 30, imin(i8) + 31, -17e0,         17e0,
                imax(i8) - 31, imax(i8) - 30, imin(i8) + 32, imin(i8) + 33, -18e0,         18e0,          imax(i8) - 33, imax(i8) - 32,
            });
            try testArgs(@Vector(128, f32), @Vector(128, i8), .{
                imin(i8) + 34, imin(i8) + 35, -19e0,         19e0,          imax(i8) - 35, imax(i8) - 34, imin(i8) + 36, imin(i8) + 37,
                -21e0,         21e0,          imax(i8) - 37, imax(i8) - 36, imin(i8) + 38, imin(i8) + 39, -22e0,         22e0,
                imax(i8) - 39, imax(i8) - 38, imin(i8) + 40, imin(i8) + 41, -23e0,         23e0,          imax(i8) - 41, imax(i8) - 40,
                imin(i8) + 42, imin(i8) + 43, -24e0,         24e0,          imax(i8) - 43, imax(i8) - 42, imin(i8) + 44, imin(i8) + 45,
                -25e0,         25e0,          imax(i8) - 45, imax(i8) - 44, imin(i8) + 46, imin(i8) + 47, -26e0,         26e0,
                imax(i8) - 47, imax(i8) - 46, imin(i8) + 48, imin(i8) + 49, -27e0,         27e0,          imax(i8) - 49, imax(i8) - 48,
                imin(i8) + 50, imin(i8) + 51, -28e0,         28e0,          imax(i8) - 51, imax(i8) - 50, imin(i8) + 52, imin(i8) + 53,
                -29e0,         29e0,          imax(i8) - 53, imax(i8) - 52, imin(i8) + 54, imin(i8) + 55, -31e0,         31e0,
                imax(i8) - 55, imax(i8) - 54, imin(i8) + 56, imin(i8) + 57, -32e0,         32e0,          imax(i8) - 57, imax(i8) - 56,
                imin(i8) + 58, imin(i8) + 59, -33e0,         33e0,          imax(i8) - 59, imax(i8) - 58, imin(i8) + 60, imin(i8) + 61,
                -34e0,         34e0,          imax(i8) - 61, imax(i8) - 60, imin(i8) + 62, imin(i8) + 63, -35e0,         35e0,
                imax(i8) - 63, imax(i8) - 62, imin(i8) + 64, imin(i8) + 65, -36e0,         36e0,          imax(i8) - 65, imax(i8) - 64,
                imin(i8) + 66, imin(i8) + 67, -37e0,         37e0,          imax(i8) - 67, imax(i8) - 66, imin(i8) + 68, imin(i8) + 69,
                -38e0,         38e0,          imax(i8) - 69, imax(i8) - 68, imin(i8) + 70, imin(i8) + 71, -39e0,         39e0,
                imax(i8) - 71, imax(i8) - 70, imin(i8) + 72, imin(i8) + 73, -41e0,         41e0,          imax(i8) - 73, imax(i8) - 72,
                imin(i8) + 74, imin(i8) + 75, -42e0,         42e0,          imax(i8) - 75, imax(i8) - 74, imin(i8) + 76, imin(i8) + 77,
            });

            try testArgs(@Vector(1, f32), @Vector(1, u8), .{
                0,
            });
            try testArgs(@Vector(2, f32), @Vector(2, u8), .{
                1e0, 1e1,
            });
            try testArgs(@Vector(4, f32), @Vector(4, u8), .{
                1e2, imax(u8) - 1, imax(u8), 2e0,
            });
            try testArgs(@Vector(8, f32), @Vector(8, u8), .{
                2e1, 2e2, imax(u8) - 3, imax(u8) - 2, 3e0, 3e1, imax(u8) - 5, imax(u8) - 4,
            });
            try testArgs(@Vector(16, f32), @Vector(16, u8), .{
                imax(u8) - 7,  imax(u8) - 6,  5e0, 5e1, imax(u8) - 9,  imax(u8) - 8,  6e0, 6e1,
                imax(u8) - 11, imax(u8) - 10, 7e0, 7e1, imax(u8) - 13, imax(u8) - 12, 8e0, 8e1,
            });
            try testArgs(@Vector(32, f32), @Vector(32, u8), .{
                imax(u8) - 15, imax(u8) - 14, 9e0,  9e1,  imax(u8) - 17, imax(u8) - 16, 11e0, 11e1,
                imax(u8) - 19, imax(u8) - 18, 12e0, 12e1, imax(u8) - 21, imax(u8) - 20, 13e0, 13e1,
                imax(u8) - 23, imax(u8) - 22, 14e0, 14e1, imax(u8) - 25, imax(u8) - 24, 15e0, 15e1,
                imax(u8) - 27, imax(u8) - 26, 16e0, 16e1, imax(u8) - 29, imax(u8) - 28, 17e0, 17e1,
            });
            try testArgs(@Vector(64, f32), @Vector(64, u8), .{
                imax(u8) - 31, imax(u8) - 30, 18e0,          18e1,          imax(u8) - 33, imax(u8) - 32, 19e0,          19e1,
                imax(u8) - 35, imax(u8) - 34, 21e0,          21e1,          imax(u8) - 37, imax(u8) - 36, 22e0,          22e1,
                imax(u8) - 39, imax(u8) - 38, 23e0,          23e1,          imax(u8) - 41, imax(u8) - 40, 24e0,          24e1,
                imax(u8) - 43, imax(u8) - 42, 25e0,          25e1,          imax(u8) - 45, imax(u8) - 44, 26e0,          imax(u8) - 47,
                imax(u8) - 46, 27e0,          imax(u8) - 49, imax(u8) - 48, 28e0,          imax(u8) - 51, imax(u8) - 50, 29e0,
                imax(u8) - 53, imax(u8) - 52, 31e0,          imax(u8) - 55, imax(u8) - 54, 32e0,          imax(u8) - 57, imax(u8) - 56,
                33e0,          imax(u8) - 59, imax(u8) - 58, 34e0,          imax(u8) - 61, imax(u8) - 60, 35e0,          imax(u8) - 63,
                imax(u8) - 62, 36e0,          imax(u8) - 65, imax(u8) - 64, 37e0,          imax(u8) - 67, imax(u8) - 66, 38e0,
            });
            try testArgs(@Vector(128, f32), @Vector(128, u8), .{
                imax(u8) - 69,  imax(u8) - 68,  39e0,           imax(u8) - 71,  imax(u8) - 70,  41e0,           imax(u8) - 73,  imax(u8) - 72,
                42e0,           imax(u8) - 75,  imax(u8) - 74,  43e0,           imax(u8) - 77,  imax(u8) - 76,  44e0,           imax(u8) - 79,
                imax(u8) - 78,  45e0,           imax(u8) - 81,  imax(u8) - 80,  46e0,           imax(u8) - 83,  imax(u8) - 82,  47e0,
                imax(u8) - 85,  imax(u8) - 84,  48e0,           imax(u8) - 87,  imax(u8) - 86,  49e0,           imax(u8) - 89,  imax(u8) - 88,
                51e0,           imax(u8) - 91,  imax(u8) - 90,  52e0,           imax(u8) - 93,  imax(u8) - 92,  53e0,           imax(u8) - 95,
                imax(u8) - 94,  54e0,           imax(u8) - 97,  imax(u8) - 96,  55e0,           imax(u8) - 99,  imax(u8) - 98,  56e0,
                imax(u8) - 101, imax(u8) - 100, 57e0,           imax(u8) - 103, imax(u8) - 102, 58e0,           imax(u8) - 105, imax(u8) - 104,
                59e0,           imax(u8) - 107, imax(u8) - 106, 61e0,           imax(u8) - 109, imax(u8) - 108, 62e0,           imax(u8) - 111,
                imax(u8) - 110, 63e0,           imax(u8) - 113, imax(u8) - 112, 64e0,           imax(u8) - 115, imax(u8) - 114, 65e0,
                imax(u8) - 117, imax(u8) - 116, 66e0,           imax(u8) - 119, imax(u8) - 118, 67e0,           imax(u8) - 121, imax(u8) - 120,
                68e0,           imax(u8) - 123, imax(u8) - 122, 69e0,           imax(u8) - 125, imax(u8) - 124, 71e0,           imax(u8) - 127,
                imax(u8) - 126, 72e0,           imax(u8) - 129, imax(u8) - 128, 73e0,           imax(u8) - 131, imax(u8) - 130, 74e0,
                imax(u8) - 133, imax(u8) - 132, 75e0,           imax(u8) - 135, imax(u8) - 134, 76e0,           imax(u8) - 137, imax(u8) - 136,
                77e0,           imax(u8) - 139, imax(u8) - 138, 78e0,           imax(u8) - 141, imax(u8) - 140, 79e0,           imax(u8) - 143,
                imax(u8) - 142, 81e0,           imax(u8) - 145, imax(u8) - 144, 82e0,           imax(u8) - 147, imax(u8) - 146, 83e0,
                imax(u8) - 149, imax(u8) - 148, 84e0,           imax(u8) - 151, imax(u8) - 150, 85e0,           imax(u8) - 153, imax(u8) - 152,
            });

            try testArgs(@Vector(1, f32), @Vector(1, i16), .{
                imin(i16),
            });
            try testArgs(@Vector(2, f32), @Vector(2, i16), .{
                imin(i16) + 1, -1e4,
            });
            try testArgs(@Vector(4, f32), @Vector(4, i16), .{
                -1e3, -1e2, -1e1, -1e0,
            });
            try testArgs(@Vector(8, f32), @Vector(8, i16), .{
                0, 1e0, 1e1, 1e2, 1e3, 1e4, imax(i16) - 1, imax(i16),
            });
            try testArgs(@Vector(16, f32), @Vector(16, i16), .{
                imin(i16) + 2, imin(i16) + 3, -2e4, -2e3, -2e2,          -2e1,          -2e0,          2e0,
                2e1,           2e2,           2e3,  2e4,  imax(i16) - 3, imax(i16) - 2, imin(i16) + 4, imin(i16) + 5,
            });
            try testArgs(@Vector(32, f32), @Vector(32, i16), .{
                -3e4,          -3e3,          -3e2,          -3e1,          -3e0,          3e0,           3e1,           3e2,
                3e3,           3e4,           imax(i16) - 5, imax(i16) - 4, imin(i16) + 6, imin(i16) + 7, -4e3,          -4e2,
                -4e1,          -4e0,          4e0,           4e1,           4e2,           4e3,           imax(i16) - 7, imax(i16) - 6,
                imin(i16) + 8, imin(i16) + 9, -5e3,          -5e2,          -5e1,          -5e0,          5e0,           5e1,
            });
            try testArgs(@Vector(64, f32), @Vector(64, i16), .{
                5e2,            5e3,            imax(i16) - 9,  imax(i16) - 8,  imin(i16) + 10, imin(i16) + 11, -6e3,           -6e2,
                -6e1,           -6e0,           6e0,            6e1,            6e2,            6e3,            imax(i16) - 11, imax(i16) - 10,
                imin(i16) + 12, imin(i16) + 13, -7e3,           -7e2,           -7e1,           -7e0,           7e0,            7e1,
                7e2,            7e3,            imax(i16) - 13, imax(i16) - 12, imin(i16) + 14, imin(i16) + 15, -8e3,           -8e2,
                -8e1,           -8e0,           8e0,            8e1,            8e2,            8e3,            imax(i16) - 15, imax(i16) - 14,
                imin(i16) + 16, imin(i16) + 17, -9e3,           -9e2,           -9e1,           -9e0,           9e0,            9e1,
                9e2,            9e3,            imax(i16) - 17, imax(i16) - 16, imin(i16) + 18, imin(i16) + 19, -11e3,          -11e2,
                -11e1,          -11e0,          11e0,           11e1,           11e2,           11e3,           imax(i16) - 19, imax(i16) - 18,
            });
            try testArgs(@Vector(128, f32), @Vector(128, i16), .{
                imin(i16) + 20, imin(i16) + 21, -12e3,          -12e2,          -12e1,          -12e0,          12e0,           12e1,
                12e2,           12e3,           imax(i16) - 21, imax(i16) - 20, imin(i16) + 22, imin(i16) + 23, -13e3,          -13e2,
                -13e1,          -13e0,          13e0,           13e1,           13e2,           13e3,           imax(i16) - 23, imax(i16) - 22,
                imin(i16) + 24, imin(i16) + 25, -14e3,          -14e2,          -14e1,          -14e0,          14e0,           14e1,
                14e2,           14e3,           imax(i16) - 25, imax(i16) - 24, imin(i16) + 26, imin(i16) + 27, -15e3,          -15e2,
                -15e1,          -15e0,          15e0,           15e1,           15e2,           15e3,           imax(i16) - 27, imax(i16) - 26,
                imin(i16) + 28, imin(i16) + 29, -16e3,          -16e2,          -16e1,          -16e0,          16e0,           16e1,
                16e2,           16e3,           imax(i16) - 29, imax(i16) - 28, imin(i16) + 30, imin(i16) + 31, -17e3,          -17e2,
                -17e1,          -17e0,          17e0,           17e1,           17e2,           17e3,           imax(i16) - 31, imax(i16) - 30,
                imin(i16) + 32, imin(i16) + 33, -18e3,          -18e2,          -18e1,          -18e0,          18e0,           18e1,
                18e2,           18e3,           imax(i16) - 33, imax(i16) - 32, imin(i16) + 34, imin(i16) + 35, -19e3,          -19e2,
                -19e1,          -19e0,          19e0,           19e1,           19e2,           19e3,           imax(i16) - 35, imax(i16) - 34,
                imin(i16) + 36, imin(i16) + 37, -12e3,          -21e2,          -21e1,          -21e0,          21e0,           21e1,
                21e2,           21e3,           imax(i16) - 37, imax(i16) - 36, imin(i16) + 38, imin(i16) + 39, -22e3,          -22e2,
                -22e1,          -22e0,          22e0,           22e1,           22e2,           22e3,           imax(i16) - 39, imax(i16) - 38,
                imin(i16) + 40, imin(i16) + 41, -23e3,          -23e2,          -23e1,          -23e0,          23e0,           23e1,
            });

            try testArgs(@Vector(1, f32), @Vector(1, u16), .{
                0,
            });
            try testArgs(@Vector(2, f32), @Vector(2, u16), .{
                1e0, 1e1,
            });
            try testArgs(@Vector(4, f32), @Vector(4, u16), .{
                1e2, 1e3, 1e4, imax(u16) - 1,
            });
            try testArgs(@Vector(8, f32), @Vector(8, u16), .{
                imax(u16), 2e0, 2e1, 2e2, 2e3, 2e4, imax(u16) - 3, imax(u16) - 2,
            });
            try testArgs(@Vector(16, f32), @Vector(16, u16), .{
                3e0, 3e1, 3e2, 3e3, 3e4,           imax(u16) - 5, imax(u16) - 4, 4e0,
                4e1, 4e2, 4e3, 4e4, imax(u16) - 7, imax(u16) - 6, 5e0,           5e1,
            });
            try testArgs(@Vector(32, f32), @Vector(32, u16), .{
                5e2,            5e3,            5e4,            imax(u16) - 9,  imax(u16) - 8,  6e0,            6e1,            6e2,
                6e3,            6e4,            imax(u16) - 11, imax(u16) - 10, 7e0,            7e1,            7e2,            7e3,
                imax(u16) - 13, imax(u16) - 12, 8e0,            8e1,            8e2,            8e3,            imax(u16) - 15, imax(u16) - 14,
                9e0,            9e1,            9e2,            9e3,            imax(u16) - 17, imax(u16) - 16, 11e0,           11e1,
            });
            try testArgs(@Vector(64, f32), @Vector(64, u16), .{
                11e2,           11e3,           imax(u16) - 19, imax(u16) - 18, 12e0,           12e1,           12e2,           12e3,
                imax(u16) - 21, imax(u16) - 20, 13e0,           13e1,           13e2,           13e3,           imax(u16) - 23, imax(u16) - 22,
                14e0,           14e1,           14e2,           14e3,           imax(u16) - 25, imax(u16) - 24, 15e0,           15e1,
                15e2,           15e3,           imax(u16) - 27, imax(u16) - 26, 16e0,           16e1,           16e2,           16e3,
                imax(u16) - 29, imax(u16) - 28, 17e0,           17e1,           17e2,           17e3,           imax(u16) - 31, imax(u16) - 30,
                18e0,           18e1,           18e2,           18e3,           imax(u16) - 33, imax(u16) - 32, 19e0,           19e1,
                19e2,           19e3,           imax(u16) - 35, imax(u16) - 34, 21e0,           21e1,           21e2,           21e3,
                imax(u16) - 37, imax(u16) - 36, 22e0,           22e1,           22e2,           22e3,           imax(u16) - 39, imax(u16) - 38,
            });
            try testArgs(@Vector(128, f32), @Vector(128, u16), .{
                23e0,           23e1,           23e2,           23e3,           imax(u16) - 41, imax(u16) - 40, 24e0,           24e1,
                24e2,           24e3,           imax(u16) - 43, imax(u16) - 42, 25e0,           25e1,           25e2,           25e3,
                imax(u16) - 45, imax(u16) - 44, 26e0,           26e1,           26e2,           26e3,           imax(u16) - 47, imax(u16) - 46,
                27e0,           27e1,           27e2,           27e3,           imax(u16) - 49, imax(u16) - 48, 28e0,           28e1,
                28e2,           28e3,           imax(u16) - 51, imax(u16) - 50, 29e0,           29e1,           29e2,           29e3,
                imax(u16) - 53, imax(u16) - 52, 31e0,           31e1,           31e2,           31e3,           imax(u16) - 55, imax(u16) - 54,
                32e0,           32e1,           32e2,           32e3,           imax(u16) - 57, imax(u16) - 56, 33e0,           33e1,
                33e2,           33e3,           imax(u16) - 59, imax(u16) - 58, 34e0,           34e1,           34e2,           34e3,
                imax(u16) - 61, imax(u16) - 60, 35e0,           35e1,           35e2,           35e3,           imax(u16) - 63, imax(u16) - 62,
                36e0,           36e1,           36e2,           36e3,           imax(u16) - 65, imax(u16) - 64, 37e0,           37e1,
                37e2,           37e3,           imax(u16) - 67, imax(u16) - 66, 38e0,           38e1,           38e2,           38e3,
                imax(u16) - 69, imax(u16) - 68, 39e0,           39e1,           39e2,           39e3,           imax(u16) - 71, imax(u16) - 70,
                41e0,           41e1,           41e2,           41e3,           imax(u16) - 73, imax(u16) - 72, 42e0,           42e1,
                42e2,           42e3,           imax(u16) - 75, imax(u16) - 74, 43e0,           43e1,           43e2,           43e3,
                imax(u16) - 77, imax(u16) - 76, 44e0,           44e1,           44e2,           44e3,           imax(u16) - 79, imax(u16) - 78,
                45e0,           45e1,           45e2,           45e3,           imax(u16) - 81, imax(u16) - 80, 46e0,           46e1,
            });

            try testArgs(@Vector(1, f32), @Vector(1, i32), .{
                imin(i32),
            });
            try testArgs(@Vector(2, f32), @Vector(2, i32), .{
                imin(i32) + 1, -1e9,
            });
            try testArgs(@Vector(4, f32), @Vector(4, i32), .{
                -1e8, -1e7, -1e6, -1e5,
            });
            try testArgs(@Vector(8, f32), @Vector(8, i32), .{
                -1e4, -1e3, -1e2, -1e1, -1e0, 0, 1e0, 1e1,
            });
            try testArgs(@Vector(16, f32), @Vector(16, i32), .{
                1e2,           1e3,       1e4,           1e5,           1e6,  1e7,  1e8,  1e9,
                imax(i32) - 1, imax(i32), imin(i32) + 2, imin(i32) + 3, -2e9, -2e8, -2e7, -2e6,
            });
            try testArgs(@Vector(32, f32), @Vector(32, i32), .{
                -2e5,          -2e4,          -2e3,          -2e2,          -2e1, -2e0, 2e0,  2e1,
                2e2,           2e3,           2e4,           2e5,           2e6,  2e7,  2e8,  2e9,
                imax(i32) - 3, imax(i32) - 2, imin(i32) + 4, imin(i32) + 5, -3e8, -3e7, -3e6, -3e5,
                -3e4,          -3e3,          -3e2,          -3e1,          -3e0, 3e0,  3e1,  3e2,
            });
            try testArgs(@Vector(64, f32), @Vector(64, i32), .{
                3e3,           3e4,           3e5,           3e6,           3e7,            3e8,            imax(i32) - 5, imax(i32) - 4,
                imin(i32) + 6, imin(i32) + 7, -4e8,          -4e7,          -4e6,           -4e5,           -4e4,          -4e3,
                -4e2,          -4e1,          -4e0,          4e0,           4e1,            4e2,            4e3,           4e4,
                4e5,           4e6,           4e7,           4e8,           imax(i32) - 7,  imax(i32) - 6,  imin(i32) + 8, imin(i32) + 9,
                -5e8,          -5e7,          -5e6,          -5e5,          -5e4,           -5e3,           -5e2,          -5e1,
                -5e0,          5e0,           5e1,           5e2,           5e3,            5e4,            5e5,           5e6,
                5e7,           5e8,           imax(i32) - 9, imax(i32) - 8, imin(i32) + 10, imin(i32) + 11, -6e8,          -6e7,
                -6e6,          -6e5,          -6e4,          -6e3,          -6e2,           -6e1,           -6e0,          6e0,
            });
            try testArgs(@Vector(128, f32), @Vector(128, i32), .{
                6e1,            6e2,            6e3,            6e4,            6e5,            6e6,            6e7,            6e8,
                imax(i32) - 11, imax(i32) - 10, imin(i32) + 12, imin(i32) + 13, -7e8,           -7e7,           -7e6,           -7e5,
                -7e4,           -7e3,           -7e2,           -7e1,           -7e0,           7e0,            7e1,            7e2,
                7e3,            7e4,            7e5,            7e6,            7e7,            7e8,            imax(i32) - 13, imax(i32) - 12,
                imin(i32) + 14, imin(i32) + 15, -8e8,           -8e7,           -8e6,           -8e5,           -8e4,           -8e3,
                -8e2,           -8e1,           -8e0,           8e0,            8e1,            8e2,            8e3,            8e4,
                8e5,            8e6,            8e7,            8e8,            imax(i32) - 15, imax(i32) - 14, imin(i32) + 16, imin(i32) + 17,
                -9e8,           -9e7,           -9e6,           -9e5,           -9e4,           -9e3,           -9e2,           -9e1,
                -9e0,           9e0,            9e1,            9e2,            9e3,            9e4,            9e5,            9e6,
                9e7,            9e8,            imax(i32) - 17, imax(i32) - 16, imin(i32) + 18, imin(i32) + 19, -11e8,          -11e7,
                -11e6,          -11e5,          -11e4,          -11e3,          -11e2,          -11e1,          -11e0,          11e0,
                11e1,           11e2,           11e3,           11e4,           11e5,           11e6,           11e7,           11e8,
                imax(i32) - 19, imax(i32) - 18, imin(i32) + 20, imin(i32) + 21, -12e8,          -12e7,          -12e6,          -12e5,
                -12e4,          -12e3,          -12e2,          -12e1,          -12e0,          12e0,           12e1,           12e2,
                12e3,           12e4,           12e5,           12e6,           12e7,           12e8,           imax(i32) - 21, imax(i32) - 20,
                imin(i32) + 22, imin(i32) + 23, -13e8,          -13e7,          -13e6,          -13e5,          -13e4,          -13e3,
            });

            try testArgs(@Vector(1, f32), @Vector(1, u32), .{
                0,
            });
            try testArgs(@Vector(2, f32), @Vector(2, u32), .{
                1e0, 1e1,
            });
            try testArgs(@Vector(4, f32), @Vector(4, u32), .{
                1e2, 1e3, 1e4, imax(u32) - 1,
            });
            try testArgs(@Vector(8, f32), @Vector(8, u32), .{
                imax(u32), 2e0, 2e1, 2e2, 2e3, 2e4, imax(u32) - 3, imax(u32) - 2,
            });
            try testArgs(@Vector(16, f32), @Vector(16, u32), .{
                3e0, 3e1, 3e2, 3e3, 3e4,           imax(u32) - 5, imax(u32) - 4, 4e0,
                4e1, 4e2, 4e3, 4e4, imax(u32) - 7, imax(u32) - 6, 5e0,           5e1,
            });
            try testArgs(@Vector(32, f32), @Vector(32, u32), .{
                5e2,            5e3,            5e4,            imax(u32) - 9,  imax(u32) - 8,  6e0,            6e1,            6e2,
                6e3,            6e4,            imax(u32) - 11, imax(u32) - 10, 7e0,            7e1,            7e2,            7e3,
                imax(u32) - 13, imax(u32) - 12, 8e0,            8e1,            8e2,            8e3,            imax(u32) - 15, imax(u32) - 14,
                9e0,            9e1,            9e2,            9e3,            imax(u32) - 17, imax(u32) - 16, 11e0,           11e1,
            });
            try testArgs(@Vector(64, f32), @Vector(64, u32), .{
                11e2,           11e3,           imax(u32) - 19, imax(u32) - 18, 12e0,           12e1,           12e2,           12e3,
                imax(u32) - 21, imax(u32) - 20, 13e0,           13e1,           13e2,           13e3,           imax(u32) - 23, imax(u32) - 22,
                14e0,           14e1,           14e2,           14e3,           imax(u32) - 25, imax(u32) - 24, 15e0,           15e1,
                15e2,           15e3,           imax(u32) - 27, imax(u32) - 26, 16e0,           16e1,           16e2,           16e3,
                imax(u32) - 29, imax(u32) - 28, 17e0,           17e1,           17e2,           17e3,           imax(u32) - 31, imax(u32) - 30,
                18e0,           18e1,           18e2,           18e3,           imax(u32) - 33, imax(u32) - 32, 19e0,           19e1,
                19e2,           19e3,           imax(u32) - 35, imax(u32) - 34, 21e0,           21e1,           21e2,           21e3,
                imax(u32) - 37, imax(u32) - 36, 22e0,           22e1,           22e2,           22e3,           imax(u32) - 39, imax(u32) - 38,
            });
            try testArgs(@Vector(128, f32), @Vector(128, u32), .{
                23e0,           23e1,           23e2,           23e3,           imax(u32) - 41, imax(u32) - 40, 24e0,           24e1,
                24e2,           24e3,           imax(u32) - 43, imax(u32) - 42, 25e0,           25e1,           25e2,           25e3,
                imax(u32) - 45, imax(u32) - 44, 26e0,           26e1,           26e2,           26e3,           imax(u32) - 47, imax(u32) - 46,
                27e0,           27e1,           27e2,           27e3,           imax(u32) - 49, imax(u32) - 48, 28e0,           28e1,
                28e2,           28e3,           imax(u32) - 51, imax(u32) - 50, 29e0,           29e1,           29e2,           29e3,
                imax(u32) - 53, imax(u32) - 52, 31e0,           31e1,           31e2,           31e3,           imax(u32) - 55, imax(u32) - 54,
                32e0,           32e1,           32e2,           32e3,           imax(u32) - 57, imax(u32) - 56, 33e0,           33e1,
                33e2,           33e3,           imax(u32) - 59, imax(u32) - 58, 34e0,           34e1,           34e2,           34e3,
                imax(u32) - 61, imax(u32) - 60, 35e0,           35e1,           35e2,           35e3,           imax(u32) - 63, imax(u32) - 62,
                36e0,           36e1,           36e2,           36e3,           imax(u32) - 65, imax(u32) - 64, 37e0,           37e1,
                37e2,           37e3,           imax(u32) - 67, imax(u32) - 66, 38e0,           38e1,           38e2,           38e3,
                imax(u32) - 69, imax(u32) - 68, 39e0,           39e1,           39e2,           39e3,           imax(u32) - 71, imax(u32) - 70,
                41e0,           41e1,           41e2,           41e3,           imax(u32) - 73, imax(u32) - 72, 42e0,           42e1,
                42e2,           42e3,           imax(u32) - 75, imax(u32) - 74, 43e0,           43e1,           43e2,           43e3,
                imax(u32) - 77, imax(u32) - 76, 44e0,           44e1,           44e2,           44e3,           imax(u32) - 79, imax(u32) - 78,
                45e0,           45e1,           45e2,           45e3,           imax(u32) - 81, imax(u32) - 80, 46e0,           46e1,
            });

            try testArgs(@Vector(1, f32), @Vector(1, i64), .{
                imin(i64),
            });
            try testArgs(@Vector(2, f32), @Vector(2, i64), .{
                imin(i64) + 1, -1e18,
            });
            try testArgs(@Vector(4, f32), @Vector(4, i64), .{
                -1e17, -1e16, -1e15, -1e14,
            });
            try testArgs(@Vector(8, f32), @Vector(8, i64), .{
                -1e13, -1e12, -1e11, -1e10, -1e9, -1e8, -1e7, -1e6,
            });
            try testArgs(@Vector(16, f32), @Vector(16, i64), .{
                -1e5, -1e4, -1e3, -1e2, -1e1, -1e0, 0,   1e0,
                1e1,  1e2,  1e3,  1e4,  1e5,  1e6,  1e7, 1e8,
            });
            try testArgs(@Vector(32, f32), @Vector(32, i64), .{
                1e9,   1e10,  1e11,          1e12,      1e13,          1e14,          1e15,  1e16,
                1e17,  1e18,  imax(i64) - 1, imax(i64), imin(i64) + 2, imin(i64) + 3, -2e18, -2e17,
                -2e16, -2e15, -2e14,         -2e13,     -2e12,         -2e11,         -2e10, -2e9,
                -2e8,  -2e7,  -2e6,          -2e5,      -2e4,          -2e3,          -2e2,  -2e1,
            });
            try testArgs(@Vector(64, f32), @Vector(64, i64), .{
                -2e0,  2e0,   2e1,   2e2,   2e3,           2e4,           2e5,           2e6,
                2e7,   2e8,   2e9,   2e10,  2e11,          2e12,          2e13,          2e14,
                2e15,  2e16,  2e17,  2e18,  imax(i64) - 3, imax(i64) - 2, imin(i64) + 4, imin(i64) + 5,
                -3e18, -3e17, -3e16, -3e15, -3e14,         -3e13,         -3e12,         -3e11,
                -3e10, -3e9,  -3e8,  -3e7,  -3e6,          -3e5,          -3e4,          -3e3,
                -3e2,  -3e1,  -3e0,  3e0,   3e1,           3e2,           3e3,           3e4,
                3e5,   3e6,   3e7,   3e8,   3e9,           3e10,          3e11,          3e12,
                3e13,  3e14,  3e15,  3e16,  3e17,          3e18,          imax(i64) - 5, imax(i64) - 4,
            });
            try testArgs(@Vector(128, f32), @Vector(128, i64), .{
                imin(i64) + 6, imin(i64) + 7, -4e18,         -4e17,         -4e16,          -4e15,          -4e14,          -4e13,
                -4e12,         -4e11,         -4e10,         -4e9,          -4e8,           -4e7,           -4e6,           -4e5,
                -4e4,          -4e3,          -4e2,          -4e1,          -4e0,           4e0,            4e1,            4e2,
                4e3,           4e4,           4e5,           4e6,           4e7,            4e8,            4e9,            4e10,
                4e11,          4e12,          4e13,          4e14,          4e15,           4e16,           4e17,           4e18,
                imax(i64) - 7, imax(i64) - 6, imin(i64) + 8, imin(i64) + 9, -5e18,          -5e17,          -5e16,          -5e15,
                -5e14,         -5e13,         -5e12,         -5e11,         -5e10,          -5e9,           -5e8,           -5e7,
                -5e6,          -5e5,          -5e4,          -5e3,          -5e2,           -5e1,           -5e0,           5e0,
                5e1,           5e2,           5e3,           5e4,           5e5,            5e6,            5e7,            5e8,
                5e9,           5e10,          5e11,          5e12,          5e13,           5e14,           5e15,           5e16,
                5e17,          5e18,          imax(i64) - 9, imax(i64) - 8, imin(i64) + 10, imin(i64) + 11, -6e18,          -6e17,
                -6e16,         -6e15,         -6e14,         -6e13,         -6e12,          -6e11,          -6e10,          -6e9,
                -6e8,          -6e7,          -6e6,          -6e5,          -6e4,           -6e3,           -6e2,           -6e1,
                -6e0,          6e0,           6e1,           6e2,           6e3,            6e4,            6e5,            6e6,
                6e7,           6e8,           6e9,           6e10,          6e11,           6e12,           6e13,           6e14,
                6e15,          6e16,          6e17,          6e18,          imax(i64) - 11, imax(i64) - 10, imin(i64) + 12, imin(i64) + 13,
            });

            try testArgs(@Vector(1, f32), @Vector(1, u64), .{
                0,
            });
            try testArgs(@Vector(2, f32), @Vector(2, u64), .{
                1e0, 1e1,
            });
            try testArgs(@Vector(4, f32), @Vector(4, u64), .{
                1e2, 1e3, 1e4, 1e5,
            });
            try testArgs(@Vector(8, f32), @Vector(8, u64), .{
                1e6, 1e7, 1e8, 1e9, 1e10, 1e11, 1e12, 1e13,
            });
            try testArgs(@Vector(16, f32), @Vector(16, u64), .{
                1e14, 1e15, 1e16, 1e17, 1e18, 1e19, imax(u64) - 1, imax(u64),
                2e0,  2e1,  2e2,  2e3,  2e4,  2e5,  2e6,           2e7,
            });
            try testArgs(@Vector(32, f32), @Vector(32, u64), .{
                2e8,  2e9,  2e10, 2e11,          2e12,          2e13, 2e14, 2e15,
                2e16, 2e17, 2e18, imax(u64) - 3, imax(u64) - 2, 3e0,  3e1,  3e2,
                3e3,  3e4,  3e5,  3e6,           3e7,           3e8,  3e9,  3e10,
                3e11, 3e12, 3e13, 3e14,          3e15,          3e16, 3e17, 3e18,
            });
            try testArgs(@Vector(64, f32), @Vector(64, u64), .{
                imax(u64) - 5, imax(u64) - 4, 4e0,           4e1,           4e2,  4e3,           4e4,           4e5,
                4e6,           4e7,           4e8,           4e9,           4e10, 4e11,          4e12,          4e13,
                4e14,          4e15,          4e16,          4e17,          4e18, imax(u64) - 7, imax(u64) - 6, 5e0,
                5e1,           5e2,           5e3,           5e4,           5e5,  5e6,           5e7,           5e8,
                5e9,           5e10,          5e11,          5e12,          5e13, 5e14,          5e15,          5e16,
                5e17,          5e18,          imax(u64) - 9, imax(u64) - 8, 6e0,  6e1,           6e2,           6e3,
                6e4,           6e5,           6e6,           6e7,           6e8,  6e9,           6e10,          6e11,
                6e12,          6e13,          6e14,          6e15,          6e16, 6e17,          6e18,          imax(u64) - 11,
            });
            try testArgs(@Vector(128, f32), @Vector(128, u64), .{
                imax(u64) - 10, 7e0,            7e1,            7e2,            7e3,            7e4,            7e5,            7e6,
                7e7,            7e8,            7e9,            7e10,           7e11,           7e12,           7e13,           7e14,
                7e15,           7e16,           7e17,           7e18,           imax(u64) - 13, imax(u64) - 12, 8e0,            8e1,
                8e2,            8e3,            8e4,            8e5,            8e6,            8e7,            8e8,            8e9,
                8e10,           8e11,           8e12,           8e13,           8e14,           8e15,           8e16,           8e17,
                8e18,           imax(u64) - 15, imax(u64) - 14, 9e0,            9e1,            9e2,            9e3,            9e4,
                9e5,            9e6,            9e7,            9e8,            9e9,            9e10,           9e11,           9e12,
                9e13,           9e14,           9e15,           9e16,           9e17,           9e18,           imax(u64) - 17, imax(u64) - 16,
                11e0,           11e1,           11e2,           11e3,           11e4,           11e5,           11e6,           11e7,
                11e8,           11e9,           11e10,          11e11,          11e12,          11e13,          11e14,          11e15,
                11e16,          11e17,          11e18,          imax(u64) - 19, imax(u64) - 18, 12e0,           12e1,           12e2,
                12e3,           12e4,           12e5,           12e6,           12e7,           12e8,           12e9,           12e10,
                12e11,          12e12,          12e13,          12e14,          12e15,          12e16,          12e17,          12e18,
                imax(u64) - 21, imax(u64) - 20, 13e0,           13e1,           13e2,           13e3,           13e4,           13e5,
                13e6,           13e7,           13e8,           13e9,           13e10,          13e11,          13e12,          13e13,
                13e14,          13e15,          13e16,          13e17,          13e18,          imax(u64) - 23, imax(u64) - 22, 14e0,
            });

            try testArgs(@Vector(1, f32), @Vector(1, i128), .{
                imin(i128),
            });
            try testArgs(@Vector(2, f32), @Vector(2, i128), .{
                imin(i128) + 1, -1e38,
            });
            try testArgs(@Vector(4, f32), @Vector(4, i128), .{
                -1e37, -1e36, -1e35, -1e34,
            });
            try testArgs(@Vector(8, f32), @Vector(8, i128), .{
                -1e33, -1e32, -1e31, -1e30, -1e29, -1e28, -1e27, -1e26,
            });
            try testArgs(@Vector(16, f32), @Vector(16, i128), .{
                -1e25, -1e24, -1e23, -1e22, -1e21, -1e20, -1e19, -1e18,
                -1e17, -1e16, -1e15, -1e14, -1e13, -1e12, -1e11, -1e10,
            });
            try testArgs(@Vector(32, f32), @Vector(32, i128), .{
                -1e9, -1e8, -1e7, -1e6, -1e5, -1e4, -1e3, -1e2,
                -1e1, -1e0, 0,    1e0,  1e1,  1e2,  1e3,  1e4,
                1e5,  1e6,  1e7,  1e8,  1e9,  1e10, 1e11, 1e12,
                1e13, 1e14, 1e15, 1e16, 1e17, 1e18, 1e19, 1e20,
            });
            try testArgs(@Vector(64, f32), @Vector(64, i128), .{
                1e21,  1e22,  1e23,           1e24,       1e25,           1e26,           1e27,  1e28,
                1e29,  1e30,  1e31,           1e32,       1e33,           1e34,           1e35,  1e36,
                1e37,  1e38,  imax(i128) - 1, imax(i128), imin(i128) + 2, imin(i128) + 3, -2e37, -2e36,
                -2e35, -2e34, -2e33,          -2e32,      -2e31,          -2e30,          -2e29, -2e28,
                -2e27, -2e26, -2e25,          -2e24,      -2e23,          -2e22,          -2e21, -2e20,
                -2e19, -2e18, -2e17,          -2e16,      -2e15,          -2e14,          -2e13, -2e12,
                -2e11, -2e10, -2e9,           -2e8,       -2e7,           -2e6,           -2e5,  -2e4,
                -2e3,  -2e2,  -2e1,           -2e0,       2e0,            2e1,            2e2,   2e3,
            });
            try testArgs(@Vector(128, f32), @Vector(128, i128), .{
                2e4,   2e5,   2e6,            2e7,            2e8,            2e9,            2e10,  2e11,
                2e12,  2e13,  2e14,           2e15,           2e16,           2e17,           2e18,  2e19,
                2e20,  2e21,  2e22,           2e23,           2e24,           2e25,           2e26,  2e27,
                2e28,  2e29,  2e30,           2e31,           2e32,           2e33,           2e34,  2e35,
                2e36,  2e37,  imax(i128) - 3, imax(i128) - 2, imin(i128) + 4, imin(i128) + 5, -3e37, -3e36,
                -3e35, -3e34, -3e33,          -3e32,          -3e31,          -3e30,          -3e29, -3e28,
                -3e27, -3e26, -3e25,          -3e24,          -3e23,          -3e22,          -3e21, -3e20,
                -3e19, -3e18, -3e17,          -3e16,          -3e15,          -3e14,          -3e13, -3e12,
                -3e11, -3e10, -3e9,           -3e8,           -3e7,           -3e6,           -3e5,  -3e4,
                -3e3,  -3e2,  -3e1,           -3e0,           3e0,            3e1,            3e2,   3e3,
                3e4,   3e5,   3e6,            3e7,            3e8,            3e9,            3e10,  3e11,
                3e12,  3e13,  3e14,           3e15,           3e16,           3e17,           3e18,  3e19,
                3e20,  3e21,  3e22,           3e23,           3e24,           3e25,           3e26,  3e27,
                3e28,  3e29,  3e30,           3e31,           3e32,           3e33,           3e34,  3e35,
                3e36,  3e37,  imax(i128) - 5, imax(i128) - 4, imin(i128) + 6, imin(i128) + 7, -4e37, -4e36,
                -4e35, -4e34, -4e33,          -4e32,          -4e31,          -4e30,          -4e29, -4e28,
            });

            try testArgs(@Vector(1, f32), @Vector(1, u128), .{
                0,
            });
            try testArgs(@Vector(2, f32), @Vector(2, u128), .{
                1e0, 1e1,
            });
            try testArgs(@Vector(4, f32), @Vector(4, u128), .{
                1e2, 1e3, 1e4, 1e5,
            });
            try testArgs(@Vector(8, f32), @Vector(8, u128), .{
                1e6, 1e7, 1e8, 1e9, 1e10, 1e11, 1e12, 1e13,
            });
            try testArgs(@Vector(16, f32), @Vector(16, u128), .{
                1e14, 1e15, 1e16, 1e17, 1e18, 1e19, 1e20, 1e21,
                1e22, 1e23, 1e24, 1e25, 1e26, 1e27, 1e28, 1e29,
            });
            try testArgs(@Vector(32, f32), @Vector(32, u128), .{
                1e30, 1e31,           1e32,       1e33, 1e34, 1e35, 1e36, 1e37,
                1e38, imax(u128) - 1, imax(u128), 2e0,  2e1,  2e2,  2e3,  2e4,
                2e5,  2e6,            2e7,        2e8,  2e9,  2e10, 2e11, 2e12,
                2e13, 2e14,           2e15,       2e16, 2e17, 2e18, 2e19, 2e20,
            });
            try testArgs(@Vector(64, f32), @Vector(64, u128), .{
                2e21, 2e22, 2e23,           2e24,           2e25,           2e26, 2e27, 2e28,
                2e29, 2e30, 2e31,           2e32,           2e33,           2e34, 2e35, 2e36,
                2e37, 2e38, imax(u128) - 3, imax(u128) - 2, 3e0,            3e1,  3e2,  3e3,
                3e4,  3e5,  3e6,            3e7,            3e8,            3e9,  3e10, 3e11,
                3e12, 3e13, 3e14,           3e15,           3e16,           3e17, 3e18, 3e19,
                3e20, 3e21, 3e22,           3e23,           3e24,           3e25, 3e26, 3e27,
                3e28, 3e29, 3e30,           3e31,           3e32,           3e33, 3e34, 3e35,
                3e36, 3e37, 3e38,           imax(u128) - 5, imax(u128) - 4, 4e0,  4e1,  4e2,
            });
            try testArgs(@Vector(128, f32), @Vector(128, u128), .{
                4e3,  4e4,  4e5,  4e6,             4e7,             4e8,  4e9,  4e10,
                4e11, 4e12, 4e13, 4e14,            4e15,            4e16, 4e17, 4e18,
                4e19, 4e20, 4e21, 4e22,            4e23,            4e24, 4e25, 4e26,
                4e27, 4e28, 4e29, 4e30,            4e31,            4e32, 4e33, 4e34,
                4e35, 4e36, 4e37, imax(u128) - 7,  imax(u128) - 6,  5e0,  5e1,  5e2,
                5e3,  5e4,  5e5,  5e6,             5e7,             5e8,  5e9,  5e10,
                5e11, 5e12, 5e13, 5e14,            5e15,            5e16, 5e17, 5e18,
                5e19, 5e20, 5e21, 5e22,            5e23,            5e24, 5e25, 5e26,
                5e27, 5e28, 5e29, 5e30,            5e31,            5e32, 5e33, 5e34,
                5e35, 5e36, 5e37, imax(u128) - 9,  imax(u128) - 8,  6e0,  6e1,  6e2,
                6e3,  6e4,  6e5,  6e6,             6e7,             6e8,  6e9,  6e10,
                6e11, 6e12, 6e13, 6e14,            6e15,            6e16, 6e17, 6e18,
                6e19, 6e20, 6e21, 6e22,            6e23,            6e24, 6e25, 6e26,
                6e27, 6e28, 6e29, 6e30,            6e31,            6e32, 6e33, 6e34,
                6e35, 6e36, 6e37, imax(u128) - 11, imax(u128) - 10, 7e0,  7e1,  7e2,
                7e3,  7e4,  7e5,  7e6,             7e7,             7e8,  7e9,  7e10,
            });

            try testArgs(@Vector(1, f32), @Vector(1, i256), .{
                imin(i256),
            });
            try testArgs(@Vector(2, f32), @Vector(2, i256), .{
                imin(i256) + 1, -1e76,
            });
            try testArgs(@Vector(4, f32), @Vector(4, i256), .{
                -1e75, -1e74, -1e73, -1e72,
            });
            try testArgs(@Vector(8, f32), @Vector(8, i256), .{
                -1e71, -1e70, -1e69, -1e68, -1e67, -1e66, -1e65, -1e64,
            });
            try testArgs(@Vector(16, f32), @Vector(16, i256), .{
                -1e63, -1e62, -1e61, -1e60, -1e59, -1e58, -1e57, -1e56,
                -1e55, -1e54, -1e53, -1e52, -1e51, -1e50, -1e49, -1e48,
            });
            try testArgs(@Vector(32, f32), @Vector(32, i256), .{
                -1e47, -1e46, -1e45, -1e44, -1e43, -1e42, -1e41, -1e40,
                -1e39, -1e38, -1e37, -1e36, -1e35, -1e34, -1e33, -1e32,
                -1e31, -1e30, -1e29, -1e28, -1e27, -1e26, -1e25, -1e24,
                -1e23, -1e22, -1e21, -1e20, -1e19, -1e18, -1e17, -1e16,
            });
            try testArgs(@Vector(64, f32), @Vector(64, i256), .{
                -1e15, -1e14, -1e13, -1e12, -1e11, -1e10, -1e9, -1e8,
                -1e7,  -1e6,  -1e5,  -1e4,  -1e3,  -1e2,  -1e1, -1e0,
                0,     1e0,   1e1,   1e2,   1e3,   1e4,   1e5,  1e6,
                1e7,   1e8,   1e9,   1e10,  1e11,  1e12,  1e13, 1e14,
                1e15,  1e16,  1e17,  1e18,  1e19,  1e20,  1e21, 1e22,
                1e23,  1e24,  1e25,  1e26,  1e27,  1e28,  1e29, 1e30,
                1e31,  1e32,  1e33,  1e34,  1e35,  1e36,  1e37, 1e38,
                1e39,  1e40,  1e41,  1e42,  1e43,  1e44,  1e45, 1e46,
            });
            try testArgs(@Vector(128, f32), @Vector(128, i256), .{
                1e47,           1e48,           1e49,  1e50,  1e51,  1e52,  1e53,           1e54,
                1e55,           1e56,           1e57,  1e58,  1e59,  1e60,  1e61,           1e62,
                1e63,           1e64,           1e65,  1e66,  1e67,  1e68,  1e69,           1e70,
                1e71,           1e72,           1e73,  1e74,  1e75,  1e76,  imax(i256) - 1, imax(i256),
                imin(i256) + 2, imin(i256) + 3, -2e76, -2e75, -2e74, -2e73, -2e72,          -2e71,
                -2e70,          -2e69,          -2e68, -2e67, -2e66, -2e65, -2e64,          -2e63,
                -2e62,          -2e61,          -2e60, -2e59, -2e58, -2e57, -2e56,          -2e55,
                -2e54,          -2e53,          -2e52, -2e51, -2e50, -2e49, -2e48,          -2e47,
                -2e46,          -2e45,          -2e44, -2e43, -2e42, -2e41, -2e40,          -2e39,
                -2e38,          -2e37,          -2e36, -2e35, -2e34, -2e33, -2e32,          -2e31,
                -2e30,          -2e29,          -2e28, -2e27, -2e26, -2e25, -2e24,          -2e23,
                -2e22,          -2e21,          -2e20, -2e19, -2e18, -2e17, -2e16,          -2e15,
                -2e14,          -2e13,          -2e12, -2e11, -2e10, -2e9,  -2e8,           -2e7,
                -2e6,           -2e5,           -2e4,  -2e3,  -2e2,  -2e1,  -2e0,           2e0,
                2e1,            2e2,            2e3,   2e4,   2e5,   2e6,   2e7,            2e8,
                2e9,            2e10,           2e11,  2e12,  2e13,  2e14,  2e15,           2e16,
            });

            try testArgs(@Vector(1, f32), @Vector(1, u256), .{
                0,
            });
            try testArgs(@Vector(2, f32), @Vector(2, u256), .{
                1e0, 1e1,
            });
            try testArgs(@Vector(4, f32), @Vector(4, u256), .{
                1e2, 1e3, 1e4, 1e5,
            });
            try testArgs(@Vector(8, f32), @Vector(8, u256), .{
                1e6, 1e7, 1e8, 1e9, 1e10, 1e11, 1e12, 1e13,
            });
            try testArgs(@Vector(16, f32), @Vector(16, u256), .{
                1e14, 1e15, 1e16, 1e17, 1e18, 1e19, 1e20, 1e21,
                1e22, 1e23, 1e24, 1e25, 1e26, 1e27, 1e28, 1e29,
            });
            try testArgs(@Vector(32, f32), @Vector(32, u256), .{
                1e30, 1e31, 1e32, 1e33, 1e34, 1e35, 1e36, 1e37,
                1e38, 1e39, 1e40, 1e41, 1e42, 1e43, 1e44, 1e45,
                1e46, 1e47, 1e48, 1e49, 1e50, 1e51, 1e52, 1e53,
                1e54, 1e55, 1e56, 1e57, 1e58, 1e59, 1e60, 1e61,
            });
            try testArgs(@Vector(64, f32), @Vector(64, u256), .{
                1e62,           1e63,       1e64, 1e65, 1e66, 1e67, 1e68, 1e69,
                1e70,           1e71,       1e72, 1e73, 1e74, 1e75, 1e76, 1e77,
                imax(u256) - 1, imax(u256), 2e0,  2e1,  2e2,  2e3,  2e4,  2e5,
                2e6,            2e7,        2e8,  2e9,  2e10, 2e11, 2e12, 2e13,
                2e14,           2e15,       2e16, 2e17, 2e18, 2e19, 2e20, 2e21,
                2e22,           2e23,       2e24, 2e25, 2e26, 2e27, 2e28, 2e29,
                2e30,           2e31,       2e32, 2e33, 2e34, 2e35, 2e36, 2e37,
                2e38,           2e39,       2e40, 2e41, 2e42, 2e43, 2e44, 2e45,
            });
            try testArgs(@Vector(128, f32), @Vector(128, u256), .{
                2e46,           2e47, 2e48, 2e49, 2e50, 2e51, 2e52,           2e53,
                2e54,           2e55, 2e56, 2e57, 2e58, 2e59, 2e60,           2e61,
                2e62,           2e63, 2e64, 2e65, 2e66, 2e67, 2e68,           2e69,
                2e70,           2e71, 2e72, 2e73, 2e74, 2e75, 2e76,           imax(u256) - 3,
                imax(u256) - 2, 3e0,  3e1,  3e2,  3e3,  3e4,  3e5,            3e6,
                3e7,            3e8,  3e9,  3e10, 3e11, 3e12, 3e13,           3e14,
                3e15,           3e16, 3e17, 3e18, 3e19, 3e20, 3e21,           3e22,
                3e23,           3e24, 3e25, 3e26, 3e27, 3e28, 3e29,           3e30,
                3e31,           3e32, 3e33, 3e34, 3e35, 3e36, 3e37,           3e38,
                3e39,           3e40, 3e41, 3e42, 3e43, 3e44, 3e45,           3e46,
                3e47,           3e48, 3e49, 3e50, 3e51, 3e52, 3e53,           3e54,
                3e55,           3e56, 3e57, 3e58, 3e59, 3e60, 3e61,           3e62,
                3e63,           3e64, 3e65, 3e66, 3e67, 3e68, 3e69,           3e70,
                3e71,           3e72, 3e73, 3e74, 3e75, 3e76, imax(u256) - 5, imax(u256) - 4,
                4e0,            4e1,  4e2,  4e3,  4e4,  4e5,  4e6,            4e7,
                4e8,            4e9,  4e10, 4e11, 4e12, 4e13, 4e14,           4e15,
            });

            try testArgs(@Vector(1, f64), @Vector(1, i8), .{
                imin(i8),
            });
            try testArgs(@Vector(2, f64), @Vector(2, i8), .{
                imin(i8) + 1, -1e2,
            });
            try testArgs(@Vector(4, f64), @Vector(4, i8), .{
                -1e1, -1e0, 0, 1e0,
            });
            try testArgs(@Vector(8, f64), @Vector(8, i8), .{
                1e1, 1e2, imax(i8) - 1, imax(i8), imin(i8) + 2, imin(i8) + 3, -2e1, -2e0,
            });
            try testArgs(@Vector(16, f64), @Vector(16, i8), .{
                2e0, 2e1, imax(i8) - 3, imax(i8) - 2, imin(i8) + 4, imin(i8) + 5, -3e1, -3e0,
                3e0, 3e1, imax(i8) - 5, imax(i8) - 4, imin(i8) + 6, imin(i8) + 7, -4e1, -4e0,
            });
            try testArgs(@Vector(32, f64), @Vector(32, i8), .{
                4e0, 4e1, imax(i8) - 7,  imax(i8) - 6,  imin(i8) + 8,  imin(i8) + 9,  -5e1, -5e0,
                5e0, 5e1, imax(i8) - 9,  imax(i8) - 8,  imin(i8) + 10, imin(i8) + 11, -6e1, -6e0,
                6e0, 6e1, imax(i8) - 11, imax(i8) - 10, imin(i8) + 12, imin(i8) + 13, -7e1, -7e0,
                7e0, 7e1, imax(i8) - 13, imax(i8) - 12, imin(i8) + 14, imin(i8) + 15, -8e1, -8e0,
            });
            try testArgs(@Vector(64, f64), @Vector(64, i8), .{
                8e0,           8e1,           imax(i8) - 15, imax(i8) - 14, imin(i8) + 16, imin(i8) + 17, -9e1,          -9e0,
                9e0,           9e1,           imax(i8) - 17, imax(i8) - 16, imin(i8) + 18, imin(i8) + 19, -11e1,         -11e0,
                11e0,          11e1,          imax(i8) - 19, imax(i8) - 18, imin(i8) + 20, imin(i8) + 21, -12e1,         -12e0,
                12e0,          12e1,          imax(i8) - 21, imax(i8) - 20, imin(i8) + 22, imin(i8) + 23, -13e0,         13e0,
                imax(i8) - 23, imax(i8) - 22, imin(i8) + 24, imin(i8) + 25, -14e0,         14e0,          imax(i8) - 25, imax(i8) - 24,
                imin(i8) + 26, imin(i8) + 27, -15e0,         15e0,          imax(i8) - 27, imax(i8) - 26, imin(i8) + 28, imin(i8) + 29,
                -16e0,         16e0,          imax(i8) - 29, imax(i8) - 28, imin(i8) + 30, imin(i8) + 31, -17e0,         17e0,
                imax(i8) - 31, imax(i8) - 30, imin(i8) + 32, imin(i8) + 33, -18e0,         18e0,          imax(i8) - 33, imax(i8) - 32,
            });
            try testArgs(@Vector(128, f64), @Vector(128, i8), .{
                imin(i8) + 34, imin(i8) + 35, -19e0,         19e0,          imax(i8) - 35, imax(i8) - 34, imin(i8) + 36, imin(i8) + 37,
                -21e0,         21e0,          imax(i8) - 37, imax(i8) - 36, imin(i8) + 38, imin(i8) + 39, -22e0,         22e0,
                imax(i8) - 39, imax(i8) - 38, imin(i8) + 40, imin(i8) + 41, -23e0,         23e0,          imax(i8) - 41, imax(i8) - 40,
                imin(i8) + 42, imin(i8) + 43, -24e0,         24e0,          imax(i8) - 43, imax(i8) - 42, imin(i8) + 44, imin(i8) + 45,
                -25e0,         25e0,          imax(i8) - 45, imax(i8) - 44, imin(i8) + 46, imin(i8) + 47, -26e0,         26e0,
                imax(i8) - 47, imax(i8) - 46, imin(i8) + 48, imin(i8) + 49, -27e0,         27e0,          imax(i8) - 49, imax(i8) - 48,
                imin(i8) + 50, imin(i8) + 51, -28e0,         28e0,          imax(i8) - 51, imax(i8) - 50, imin(i8) + 52, imin(i8) + 53,
                -29e0,         29e0,          imax(i8) - 53, imax(i8) - 52, imin(i8) + 54, imin(i8) + 55, -31e0,         31e0,
                imax(i8) - 55, imax(i8) - 54, imin(i8) + 56, imin(i8) + 57, -32e0,         32e0,          imax(i8) - 57, imax(i8) - 56,
                imin(i8) + 58, imin(i8) + 59, -33e0,         33e0,          imax(i8) - 59, imax(i8) - 58, imin(i8) + 60, imin(i8) + 61,
                -34e0,         34e0,          imax(i8) - 61, imax(i8) - 60, imin(i8) + 62, imin(i8) + 63, -35e0,         35e0,
                imax(i8) - 63, imax(i8) - 62, imin(i8) + 64, imin(i8) + 65, -36e0,         36e0,          imax(i8) - 65, imax(i8) - 64,
                imin(i8) + 66, imin(i8) + 67, -37e0,         37e0,          imax(i8) - 67, imax(i8) - 66, imin(i8) + 68, imin(i8) + 69,
                -38e0,         38e0,          imax(i8) - 69, imax(i8) - 68, imin(i8) + 70, imin(i8) + 71, -39e0,         39e0,
                imax(i8) - 71, imax(i8) - 70, imin(i8) + 72, imin(i8) + 73, -41e0,         41e0,          imax(i8) - 73, imax(i8) - 72,
                imin(i8) + 74, imin(i8) + 75, -42e0,         42e0,          imax(i8) - 75, imax(i8) - 74, imin(i8) + 76, imin(i8) + 77,
            });

            try testArgs(@Vector(1, f64), @Vector(1, u8), .{
                0,
            });
            try testArgs(@Vector(2, f64), @Vector(2, u8), .{
                1e0, 1e1,
            });
            try testArgs(@Vector(4, f64), @Vector(4, u8), .{
                1e2, imax(u8) - 1, imax(u8), 2e0,
            });
            try testArgs(@Vector(8, f64), @Vector(8, u8), .{
                2e1, 2e2, imax(u8) - 3, imax(u8) - 2, 3e0, 3e1, imax(u8) - 5, imax(u8) - 4,
            });
            try testArgs(@Vector(16, f64), @Vector(16, u8), .{
                imax(u8) - 7,  imax(u8) - 6,  5e0, 5e1, imax(u8) - 9,  imax(u8) - 8,  6e0, 6e1,
                imax(u8) - 11, imax(u8) - 10, 7e0, 7e1, imax(u8) - 13, imax(u8) - 12, 8e0, 8e1,
            });
            try testArgs(@Vector(32, f64), @Vector(32, u8), .{
                imax(u8) - 15, imax(u8) - 14, 9e0,  9e1,  imax(u8) - 17, imax(u8) - 16, 11e0, 11e1,
                imax(u8) - 19, imax(u8) - 18, 12e0, 12e1, imax(u8) - 21, imax(u8) - 20, 13e0, 13e1,
                imax(u8) - 23, imax(u8) - 22, 14e0, 14e1, imax(u8) - 25, imax(u8) - 24, 15e0, 15e1,
                imax(u8) - 27, imax(u8) - 26, 16e0, 16e1, imax(u8) - 29, imax(u8) - 28, 17e0, 17e1,
            });
            try testArgs(@Vector(64, f64), @Vector(64, u8), .{
                imax(u8) - 31, imax(u8) - 30, 18e0,          18e1,          imax(u8) - 33, imax(u8) - 32, 19e0,          19e1,
                imax(u8) - 35, imax(u8) - 34, 21e0,          21e1,          imax(u8) - 37, imax(u8) - 36, 22e0,          22e1,
                imax(u8) - 39, imax(u8) - 38, 23e0,          23e1,          imax(u8) - 41, imax(u8) - 40, 24e0,          24e1,
                imax(u8) - 43, imax(u8) - 42, 25e0,          25e1,          imax(u8) - 45, imax(u8) - 44, 26e0,          imax(u8) - 47,
                imax(u8) - 46, 27e0,          imax(u8) - 49, imax(u8) - 48, 28e0,          imax(u8) - 51, imax(u8) - 50, 29e0,
                imax(u8) - 53, imax(u8) - 52, 31e0,          imax(u8) - 55, imax(u8) - 54, 32e0,          imax(u8) - 57, imax(u8) - 56,
                33e0,          imax(u8) - 59, imax(u8) - 58, 34e0,          imax(u8) - 61, imax(u8) - 60, 35e0,          imax(u8) - 63,
                imax(u8) - 62, 36e0,          imax(u8) - 65, imax(u8) - 64, 37e0,          imax(u8) - 67, imax(u8) - 66, 38e0,
            });
            try testArgs(@Vector(128, f64), @Vector(128, u8), .{
                imax(u8) - 69,  imax(u8) - 68,  39e0,           imax(u8) - 71,  imax(u8) - 70,  41e0,           imax(u8) - 73,  imax(u8) - 72,
                42e0,           imax(u8) - 75,  imax(u8) - 74,  43e0,           imax(u8) - 77,  imax(u8) - 76,  44e0,           imax(u8) - 79,
                imax(u8) - 78,  45e0,           imax(u8) - 81,  imax(u8) - 80,  46e0,           imax(u8) - 83,  imax(u8) - 82,  47e0,
                imax(u8) - 85,  imax(u8) - 84,  48e0,           imax(u8) - 87,  imax(u8) - 86,  49e0,           imax(u8) - 89,  imax(u8) - 88,
                51e0,           imax(u8) - 91,  imax(u8) - 90,  52e0,           imax(u8) - 93,  imax(u8) - 92,  53e0,           imax(u8) - 95,
                imax(u8) - 94,  54e0,           imax(u8) - 97,  imax(u8) - 96,  55e0,           imax(u8) - 99,  imax(u8) - 98,  56e0,
                imax(u8) - 101, imax(u8) - 100, 57e0,           imax(u8) - 103, imax(u8) - 102, 58e0,           imax(u8) - 105, imax(u8) - 104,
                59e0,           imax(u8) - 107, imax(u8) - 106, 61e0,           imax(u8) - 109, imax(u8) - 108, 62e0,           imax(u8) - 111,
                imax(u8) - 110, 63e0,           imax(u8) - 113, imax(u8) - 112, 64e0,           imax(u8) - 115, imax(u8) - 114, 65e0,
                imax(u8) - 117, imax(u8) - 116, 66e0,           imax(u8) - 119, imax(u8) - 118, 67e0,           imax(u8) - 121, imax(u8) - 120,
                68e0,           imax(u8) - 123, imax(u8) - 122, 69e0,           imax(u8) - 125, imax(u8) - 124, 71e0,           imax(u8) - 127,
                imax(u8) - 126, 72e0,           imax(u8) - 129, imax(u8) - 128, 73e0,           imax(u8) - 131, imax(u8) - 130, 74e0,
                imax(u8) - 133, imax(u8) - 132, 75e0,           imax(u8) - 135, imax(u8) - 134, 76e0,           imax(u8) - 137, imax(u8) - 136,
                77e0,           imax(u8) - 139, imax(u8) - 138, 78e0,           imax(u8) - 141, imax(u8) - 140, 79e0,           imax(u8) - 143,
                imax(u8) - 142, 81e0,           imax(u8) - 145, imax(u8) - 144, 82e0,           imax(u8) - 147, imax(u8) - 146, 83e0,
                imax(u8) - 149, imax(u8) - 148, 84e0,           imax(u8) - 151, imax(u8) - 150, 85e0,           imax(u8) - 153, imax(u8) - 152,
            });

            try testArgs(@Vector(1, f64), @Vector(1, i16), .{
                imin(i16),
            });
            try testArgs(@Vector(2, f64), @Vector(2, i16), .{
                imin(i16) + 1, -1e4,
            });
            try testArgs(@Vector(4, f64), @Vector(4, i16), .{
                -1e3, -1e2, -1e1, -1e0,
            });
            try testArgs(@Vector(8, f64), @Vector(8, i16), .{
                0, 1e0, 1e1, 1e2, 1e3, 1e4, imax(i16) - 1, imax(i16),
            });
            try testArgs(@Vector(16, f64), @Vector(16, i16), .{
                imin(i16) + 2, imin(i16) + 3, -2e4, -2e3, -2e2,          -2e1,          -2e0,          2e0,
                2e1,           2e2,           2e3,  2e4,  imax(i16) - 3, imax(i16) - 2, imin(i16) + 4, imin(i16) + 5,
            });
            try testArgs(@Vector(32, f64), @Vector(32, i16), .{
                -3e4,          -3e3,          -3e2,          -3e1,          -3e0,          3e0,           3e1,           3e2,
                3e3,           3e4,           imax(i16) - 5, imax(i16) - 4, imin(i16) + 6, imin(i16) + 7, -4e3,          -4e2,
                -4e1,          -4e0,          4e0,           4e1,           4e2,           4e3,           imax(i16) - 7, imax(i16) - 6,
                imin(i16) + 8, imin(i16) + 9, -5e3,          -5e2,          -5e1,          -5e0,          5e0,           5e1,
            });
            try testArgs(@Vector(64, f64), @Vector(64, i16), .{
                5e2,            5e3,            imax(i16) - 9,  imax(i16) - 8,  imin(i16) + 10, imin(i16) + 11, -6e3,           -6e2,
                -6e1,           -6e0,           6e0,            6e1,            6e2,            6e3,            imax(i16) - 11, imax(i16) - 10,
                imin(i16) + 12, imin(i16) + 13, -7e3,           -7e2,           -7e1,           -7e0,           7e0,            7e1,
                7e2,            7e3,            imax(i16) - 13, imax(i16) - 12, imin(i16) + 14, imin(i16) + 15, -8e3,           -8e2,
                -8e1,           -8e0,           8e0,            8e1,            8e2,            8e3,            imax(i16) - 15, imax(i16) - 14,
                imin(i16) + 16, imin(i16) + 17, -9e3,           -9e2,           -9e1,           -9e0,           9e0,            9e1,
                9e2,            9e3,            imax(i16) - 17, imax(i16) - 16, imin(i16) + 18, imin(i16) + 19, -11e3,          -11e2,
                -11e1,          -11e0,          11e0,           11e1,           11e2,           11e3,           imax(i16) - 19, imax(i16) - 18,
            });
            try testArgs(@Vector(128, f64), @Vector(128, i16), .{
                imin(i16) + 20, imin(i16) + 21, -12e3,          -12e2,          -12e1,          -12e0,          12e0,           12e1,
                12e2,           12e3,           imax(i16) - 21, imax(i16) - 20, imin(i16) + 22, imin(i16) + 23, -13e3,          -13e2,
                -13e1,          -13e0,          13e0,           13e1,           13e2,           13e3,           imax(i16) - 23, imax(i16) - 22,
                imin(i16) + 24, imin(i16) + 25, -14e3,          -14e2,          -14e1,          -14e0,          14e0,           14e1,
                14e2,           14e3,           imax(i16) - 25, imax(i16) - 24, imin(i16) + 26, imin(i16) + 27, -15e3,          -15e2,
                -15e1,          -15e0,          15e0,           15e1,           15e2,           15e3,           imax(i16) - 27, imax(i16) - 26,
                imin(i16) + 28, imin(i16) + 29, -16e3,          -16e2,          -16e1,          -16e0,          16e0,           16e1,
                16e2,           16e3,           imax(i16) - 29, imax(i16) - 28, imin(i16) + 30, imin(i16) + 31, -17e3,          -17e2,
                -17e1,          -17e0,          17e0,           17e1,           17e2,           17e3,           imax(i16) - 31, imax(i16) - 30,
                imin(i16) + 32, imin(i16) + 33, -18e3,          -18e2,          -18e1,          -18e0,          18e0,           18e1,
                18e2,           18e3,           imax(i16) - 33, imax(i16) - 32, imin(i16) + 34, imin(i16) + 35, -19e3,          -19e2,
                -19e1,          -19e0,          19e0,           19e1,           19e2,           19e3,           imax(i16) - 35, imax(i16) - 34,
                imin(i16) + 36, imin(i16) + 37, -12e3,          -21e2,          -21e1,          -21e0,          21e0,           21e1,
                21e2,           21e3,           imax(i16) - 37, imax(i16) - 36, imin(i16) + 38, imin(i16) + 39, -22e3,          -22e2,
                -22e1,          -22e0,          22e0,           22e1,           22e2,           22e3,           imax(i16) - 39, imax(i16) - 38,
                imin(i16) + 40, imin(i16) + 41, -23e3,          -23e2,          -23e1,          -23e0,          23e0,           23e1,
            });

            try testArgs(@Vector(1, f64), @Vector(1, u16), .{
                0,
            });
            try testArgs(@Vector(2, f64), @Vector(2, u16), .{
                1e0, 1e1,
            });
            try testArgs(@Vector(4, f64), @Vector(4, u16), .{
                1e2, 1e3, 1e4, imax(u16) - 1,
            });
            try testArgs(@Vector(8, f64), @Vector(8, u16), .{
                imax(u16), 2e0, 2e1, 2e2, 2e3, 2e4, imax(u16) - 3, imax(u16) - 2,
            });
            try testArgs(@Vector(16, f64), @Vector(16, u16), .{
                3e0, 3e1, 3e2, 3e3, 3e4,           imax(u16) - 5, imax(u16) - 4, 4e0,
                4e1, 4e2, 4e3, 4e4, imax(u16) - 7, imax(u16) - 6, 5e0,           5e1,
            });
            try testArgs(@Vector(32, f64), @Vector(32, u16), .{
                5e2,            5e3,            5e4,            imax(u16) - 9,  imax(u16) - 8,  6e0,            6e1,            6e2,
                6e3,            6e4,            imax(u16) - 11, imax(u16) - 10, 7e0,            7e1,            7e2,            7e3,
                imax(u16) - 13, imax(u16) - 12, 8e0,            8e1,            8e2,            8e3,            imax(u16) - 15, imax(u16) - 14,
                9e0,            9e1,            9e2,            9e3,            imax(u16) - 17, imax(u16) - 16, 11e0,           11e1,
            });
            try testArgs(@Vector(64, f64), @Vector(64, u16), .{
                11e2,           11e3,           imax(u16) - 19, imax(u16) - 18, 12e0,           12e1,           12e2,           12e3,
                imax(u16) - 21, imax(u16) - 20, 13e0,           13e1,           13e2,           13e3,           imax(u16) - 23, imax(u16) - 22,
                14e0,           14e1,           14e2,           14e3,           imax(u16) - 25, imax(u16) - 24, 15e0,           15e1,
                15e2,           15e3,           imax(u16) - 27, imax(u16) - 26, 16e0,           16e1,           16e2,           16e3,
                imax(u16) - 29, imax(u16) - 28, 17e0,           17e1,           17e2,           17e3,           imax(u16) - 31, imax(u16) - 30,
                18e0,           18e1,           18e2,           18e3,           imax(u16) - 33, imax(u16) - 32, 19e0,           19e1,
                19e2,           19e3,           imax(u16) - 35, imax(u16) - 34, 21e0,           21e1,           21e2,           21e3,
                imax(u16) - 37, imax(u16) - 36, 22e0,           22e1,           22e2,           22e3,           imax(u16) - 39, imax(u16) - 38,
            });
            try testArgs(@Vector(128, f64), @Vector(128, u16), .{
                23e0,           23e1,           23e2,           23e3,           imax(u16) - 41, imax(u16) - 40, 24e0,           24e1,
                24e2,           24e3,           imax(u16) - 43, imax(u16) - 42, 25e0,           25e1,           25e2,           25e3,
                imax(u16) - 45, imax(u16) - 44, 26e0,           26e1,           26e2,           26e3,           imax(u16) - 47, imax(u16) - 46,
                27e0,           27e1,           27e2,           27e3,           imax(u16) - 49, imax(u16) - 48, 28e0,           28e1,
                28e2,           28e3,           imax(u16) - 51, imax(u16) - 50, 29e0,           29e1,           29e2,           29e3,
                imax(u16) - 53, imax(u16) - 52, 31e0,           31e1,           31e2,           31e3,           imax(u16) - 55, imax(u16) - 54,
                32e0,           32e1,           32e2,           32e3,           imax(u16) - 57, imax(u16) - 56, 33e0,           33e1,
                33e2,           33e3,           imax(u16) - 59, imax(u16) - 58, 34e0,           34e1,           34e2,           34e3,
                imax(u16) - 61, imax(u16) - 60, 35e0,           35e1,           35e2,           35e3,           imax(u16) - 63, imax(u16) - 62,
                36e0,           36e1,           36e2,           36e3,           imax(u16) - 65, imax(u16) - 64, 37e0,           37e1,
                37e2,           37e3,           imax(u16) - 67, imax(u16) - 66, 38e0,           38e1,           38e2,           38e3,
                imax(u16) - 69, imax(u16) - 68, 39e0,           39e1,           39e2,           39e3,           imax(u16) - 71, imax(u16) - 70,
                41e0,           41e1,           41e2,           41e3,           imax(u16) - 73, imax(u16) - 72, 42e0,           42e1,
                42e2,           42e3,           imax(u16) - 75, imax(u16) - 74, 43e0,           43e1,           43e2,           43e3,
                imax(u16) - 77, imax(u16) - 76, 44e0,           44e1,           44e2,           44e3,           imax(u16) - 79, imax(u16) - 78,
                45e0,           45e1,           45e2,           45e3,           imax(u16) - 81, imax(u16) - 80, 46e0,           46e1,
            });

            try testArgs(@Vector(1, f64), @Vector(1, i32), .{
                imin(i32),
            });
            try testArgs(@Vector(2, f64), @Vector(2, i32), .{
                imin(i32) + 1, -1e9,
            });
            try testArgs(@Vector(4, f64), @Vector(4, i32), .{
                -1e8, -1e7, -1e6, -1e5,
            });
            try testArgs(@Vector(8, f64), @Vector(8, i32), .{
                -1e4, -1e3, -1e2, -1e1, -1e0, 0, 1e0, 1e1,
            });
            try testArgs(@Vector(16, f64), @Vector(16, i32), .{
                1e2,           1e3,       1e4,           1e5,           1e6,  1e7,  1e8,  1e9,
                imax(i32) - 1, imax(i32), imin(i32) + 2, imin(i32) + 3, -2e9, -2e8, -2e7, -2e6,
            });
            try testArgs(@Vector(32, f64), @Vector(32, i32), .{
                -2e5,          -2e4,          -2e3,          -2e2,          -2e1, -2e0, 2e0,  2e1,
                2e2,           2e3,           2e4,           2e5,           2e6,  2e7,  2e8,  2e9,
                imax(i32) - 3, imax(i32) - 2, imin(i32) + 4, imin(i32) + 5, -3e8, -3e7, -3e6, -3e5,
                -3e4,          -3e3,          -3e2,          -3e1,          -3e0, 3e0,  3e1,  3e2,
            });
            try testArgs(@Vector(64, f64), @Vector(64, i32), .{
                3e3,           3e4,           3e5,           3e6,           3e7,            3e8,            imax(i32) - 5, imax(i32) - 4,
                imin(i32) + 6, imin(i32) + 7, -4e8,          -4e7,          -4e6,           -4e5,           -4e4,          -4e3,
                -4e2,          -4e1,          -4e0,          4e0,           4e1,            4e2,            4e3,           4e4,
                4e5,           4e6,           4e7,           4e8,           imax(i32) - 7,  imax(i32) - 6,  imin(i32) + 8, imin(i32) + 9,
                -5e8,          -5e7,          -5e6,          -5e5,          -5e4,           -5e3,           -5e2,          -5e1,
                -5e0,          5e0,           5e1,           5e2,           5e3,            5e4,            5e5,           5e6,
                5e7,           5e8,           imax(i32) - 9, imax(i32) - 8, imin(i32) + 10, imin(i32) + 11, -6e8,          -6e7,
                -6e6,          -6e5,          -6e4,          -6e3,          -6e2,           -6e1,           -6e0,          6e0,
            });
            try testArgs(@Vector(128, f64), @Vector(128, i32), .{
                6e1,            6e2,            6e3,            6e4,            6e5,            6e6,            6e7,            6e8,
                imax(i32) - 11, imax(i32) - 10, imin(i32) + 12, imin(i32) + 13, -7e8,           -7e7,           -7e6,           -7e5,
                -7e4,           -7e3,           -7e2,           -7e1,           -7e0,           7e0,            7e1,            7e2,
                7e3,            7e4,            7e5,            7e6,            7e7,            7e8,            imax(i32) - 13, imax(i32) - 12,
                imin(i32) + 14, imin(i32) + 15, -8e8,           -8e7,           -8e6,           -8e5,           -8e4,           -8e3,
                -8e2,           -8e1,           -8e0,           8e0,            8e1,            8e2,            8e3,            8e4,
                8e5,            8e6,            8e7,            8e8,            imax(i32) - 15, imax(i32) - 14, imin(i32) + 16, imin(i32) + 17,
                -9e8,           -9e7,           -9e6,           -9e5,           -9e4,           -9e3,           -9e2,           -9e1,
                -9e0,           9e0,            9e1,            9e2,            9e3,            9e4,            9e5,            9e6,
                9e7,            9e8,            imax(i32) - 17, imax(i32) - 16, imin(i32) + 18, imin(i32) + 19, -11e8,          -11e7,
                -11e6,          -11e5,          -11e4,          -11e3,          -11e2,          -11e1,          -11e0,          11e0,
                11e1,           11e2,           11e3,           11e4,           11e5,           11e6,           11e7,           11e8,
                imax(i32) - 19, imax(i32) - 18, imin(i32) + 20, imin(i32) + 21, -12e8,          -12e7,          -12e6,          -12e5,
                -12e4,          -12e3,          -12e2,          -12e1,          -12e0,          12e0,           12e1,           12e2,
                12e3,           12e4,           12e5,           12e6,           12e7,           12e8,           imax(i32) - 21, imax(i32) - 20,
                imin(i32) + 22, imin(i32) + 23, -13e8,          -13e7,          -13e6,          -13e5,          -13e4,          -13e3,
            });

            try testArgs(@Vector(1, f64), @Vector(1, u32), .{
                0,
            });
            try testArgs(@Vector(2, f64), @Vector(2, u32), .{
                1e0, 1e1,
            });
            try testArgs(@Vector(4, f64), @Vector(4, u32), .{
                1e2, 1e3, 1e4, imax(u32) - 1,
            });
            try testArgs(@Vector(8, f64), @Vector(8, u32), .{
                imax(u32), 2e0, 2e1, 2e2, 2e3, 2e4, imax(u32) - 3, imax(u32) - 2,
            });
            try testArgs(@Vector(16, f64), @Vector(16, u32), .{
                3e0, 3e1, 3e2, 3e3, 3e4,           imax(u32) - 5, imax(u32) - 4, 4e0,
                4e1, 4e2, 4e3, 4e4, imax(u32) - 7, imax(u32) - 6, 5e0,           5e1,
            });
            try testArgs(@Vector(32, f64), @Vector(32, u32), .{
                5e2,            5e3,            5e4,            imax(u32) - 9,  imax(u32) - 8,  6e0,            6e1,            6e2,
                6e3,            6e4,            imax(u32) - 11, imax(u32) - 10, 7e0,            7e1,            7e2,            7e3,
                imax(u32) - 13, imax(u32) - 12, 8e0,            8e1,            8e2,            8e3,            imax(u32) - 15, imax(u32) - 14,
                9e0,            9e1,            9e2,            9e3,            imax(u32) - 17, imax(u32) - 16, 11e0,           11e1,
            });
            try testArgs(@Vector(64, f64), @Vector(64, u32), .{
                11e2,           11e3,           imax(u32) - 19, imax(u32) - 18, 12e0,           12e1,           12e2,           12e3,
                imax(u32) - 21, imax(u32) - 20, 13e0,           13e1,           13e2,           13e3,           imax(u32) - 23, imax(u32) - 22,
                14e0,           14e1,           14e2,           14e3,           imax(u32) - 25, imax(u32) - 24, 15e0,           15e1,
                15e2,           15e3,           imax(u32) - 27, imax(u32) - 26, 16e0,           16e1,           16e2,           16e3,
                imax(u32) - 29, imax(u32) - 28, 17e0,           17e1,           17e2,           17e3,           imax(u32) - 31, imax(u32) - 30,
                18e0,           18e1,           18e2,           18e3,           imax(u32) - 33, imax(u32) - 32, 19e0,           19e1,
                19e2,           19e3,           imax(u32) - 35, imax(u32) - 34, 21e0,           21e1,           21e2,           21e3,
                imax(u32) - 37, imax(u32) - 36, 22e0,           22e1,           22e2,           22e3,           imax(u32) - 39, imax(u32) - 38,
            });
            try testArgs(@Vector(128, f64), @Vector(128, u32), .{
                23e0,           23e1,           23e2,           23e3,           imax(u32) - 41, imax(u32) - 40, 24e0,           24e1,
                24e2,           24e3,           imax(u32) - 43, imax(u32) - 42, 25e0,           25e1,           25e2,           25e3,
                imax(u32) - 45, imax(u32) - 44, 26e0,           26e1,           26e2,           26e3,           imax(u32) - 47, imax(u32) - 46,
                27e0,           27e1,           27e2,           27e3,           imax(u32) - 49, imax(u32) - 48, 28e0,           28e1,
                28e2,           28e3,           imax(u32) - 51, imax(u32) - 50, 29e0,           29e1,           29e2,           29e3,
                imax(u32) - 53, imax(u32) - 52, 31e0,           31e1,           31e2,           31e3,           imax(u32) - 55, imax(u32) - 54,
                32e0,           32e1,           32e2,           32e3,           imax(u32) - 57, imax(u32) - 56, 33e0,           33e1,
                33e2,           33e3,           imax(u32) - 59, imax(u32) - 58, 34e0,           34e1,           34e2,           34e3,
                imax(u32) - 61, imax(u32) - 60, 35e0,           35e1,           35e2,           35e3,           imax(u32) - 63, imax(u32) - 62,
                36e0,           36e1,           36e2,           36e3,           imax(u32) - 65, imax(u32) - 64, 37e0,           37e1,
                37e2,           37e3,           imax(u32) - 67, imax(u32) - 66, 38e0,           38e1,           38e2,           38e3,
                imax(u32) - 69, imax(u32) - 68, 39e0,           39e1,           39e2,           39e3,           imax(u32) - 71, imax(u32) - 70,
                41e0,           41e1,           41e2,           41e3,           imax(u32) - 73, imax(u32) - 72, 42e0,           42e1,
                42e2,           42e3,           imax(u32) - 75, imax(u32) - 74, 43e0,           43e1,           43e2,           43e3,
                imax(u32) - 77, imax(u32) - 76, 44e0,           44e1,           44e2,           44e3,           imax(u32) - 79, imax(u32) - 78,
                45e0,           45e1,           45e2,           45e3,           imax(u32) - 81, imax(u32) - 80, 46e0,           46e1,
            });

            try testArgs(@Vector(1, f64), @Vector(1, i64), .{
                imin(i64),
            });
            try testArgs(@Vector(2, f64), @Vector(2, i64), .{
                imin(i64) + 1, -1e18,
            });
            try testArgs(@Vector(4, f64), @Vector(4, i64), .{
                -1e17, -1e16, -1e15, -1e14,
            });
            try testArgs(@Vector(8, f64), @Vector(8, i64), .{
                -1e13, -1e12, -1e11, -1e10, -1e9, -1e8, -1e7, -1e6,
            });
            try testArgs(@Vector(16, f64), @Vector(16, i64), .{
                -1e5, -1e4, -1e3, -1e2, -1e1, -1e0, 0,   1e0,
                1e1,  1e2,  1e3,  1e4,  1e5,  1e6,  1e7, 1e8,
            });
            try testArgs(@Vector(32, f64), @Vector(32, i64), .{
                1e9,   1e10,  1e11,          1e12,      1e13,          1e14,          1e15,  1e16,
                1e17,  1e18,  imax(i64) - 1, imax(i64), imin(i64) + 2, imin(i64) + 3, -2e18, -2e17,
                -2e16, -2e15, -2e14,         -2e13,     -2e12,         -2e11,         -2e10, -2e9,
                -2e8,  -2e7,  -2e6,          -2e5,      -2e4,          -2e3,          -2e2,  -2e1,
            });
            try testArgs(@Vector(64, f64), @Vector(64, i64), .{
                -2e0,  2e0,   2e1,   2e2,   2e3,           2e4,           2e5,           2e6,
                2e7,   2e8,   2e9,   2e10,  2e11,          2e12,          2e13,          2e14,
                2e15,  2e16,  2e17,  2e18,  imax(i64) - 3, imax(i64) - 2, imin(i64) + 4, imin(i64) + 5,
                -3e18, -3e17, -3e16, -3e15, -3e14,         -3e13,         -3e12,         -3e11,
                -3e10, -3e9,  -3e8,  -3e7,  -3e6,          -3e5,          -3e4,          -3e3,
                -3e2,  -3e1,  -3e0,  3e0,   3e1,           3e2,           3e3,           3e4,
                3e5,   3e6,   3e7,   3e8,   3e9,           3e10,          3e11,          3e12,
                3e13,  3e14,  3e15,  3e16,  3e17,          3e18,          imax(i64) - 5, imax(i64) - 4,
            });
            try testArgs(@Vector(128, f64), @Vector(128, i64), .{
                imin(i64) + 6, imin(i64) + 7, -4e18,         -4e17,         -4e16,          -4e15,          -4e14,          -4e13,
                -4e12,         -4e11,         -4e10,         -4e9,          -4e8,           -4e7,           -4e6,           -4e5,
                -4e4,          -4e3,          -4e2,          -4e1,          -4e0,           4e0,            4e1,            4e2,
                4e3,           4e4,           4e5,           4e6,           4e7,            4e8,            4e9,            4e10,
                4e11,          4e12,          4e13,          4e14,          4e15,           4e16,           4e17,           4e18,
                imax(i64) - 7, imax(i64) - 6, imin(i64) + 8, imin(i64) + 9, -5e18,          -5e17,          -5e16,          -5e15,
                -5e14,         -5e13,         -5e12,         -5e11,         -5e10,          -5e9,           -5e8,           -5e7,
                -5e6,          -5e5,          -5e4,          -5e3,          -5e2,           -5e1,           -5e0,           5e0,
                5e1,           5e2,           5e3,           5e4,           5e5,            5e6,            5e7,            5e8,
                5e9,           5e10,          5e11,          5e12,          5e13,           5e14,           5e15,           5e16,
                5e17,          5e18,          imax(i64) - 9, imax(i64) - 8, imin(i64) + 10, imin(i64) + 11, -6e18,          -6e17,
                -6e16,         -6e15,         -6e14,         -6e13,         -6e12,          -6e11,          -6e10,          -6e9,
                -6e8,          -6e7,          -6e6,          -6e5,          -6e4,           -6e3,           -6e2,           -6e1,
                -6e0,          6e0,           6e1,           6e2,           6e3,            6e4,            6e5,            6e6,
                6e7,           6e8,           6e9,           6e10,          6e11,           6e12,           6e13,           6e14,
                6e15,          6e16,          6e17,          6e18,          imax(i64) - 11, imax(i64) - 10, imin(i64) + 12, imin(i64) + 13,
            });

            try testArgs(@Vector(1, f64), @Vector(1, u64), .{
                0,
            });
            try testArgs(@Vector(2, f64), @Vector(2, u64), .{
                1e0, 1e1,
            });
            try testArgs(@Vector(4, f64), @Vector(4, u64), .{
                1e2, 1e3, 1e4, 1e5,
            });
            try testArgs(@Vector(8, f64), @Vector(8, u64), .{
                1e6, 1e7, 1e8, 1e9, 1e10, 1e11, 1e12, 1e13,
            });
            try testArgs(@Vector(16, f64), @Vector(16, u64), .{
                1e14, 1e15, 1e16, 1e17, 1e18, 1e19, imax(u64) - 1, imax(u64),
                2e0,  2e1,  2e2,  2e3,  2e4,  2e5,  2e6,           2e7,
            });
            try testArgs(@Vector(32, f64), @Vector(32, u64), .{
                2e8,  2e9,  2e10, 2e11,          2e12,          2e13, 2e14, 2e15,
                2e16, 2e17, 2e18, imax(u64) - 3, imax(u64) - 2, 3e0,  3e1,  3e2,
                3e3,  3e4,  3e5,  3e6,           3e7,           3e8,  3e9,  3e10,
                3e11, 3e12, 3e13, 3e14,          3e15,          3e16, 3e17, 3e18,
            });
            try testArgs(@Vector(64, f64), @Vector(64, u64), .{
                imax(u64) - 5, imax(u64) - 4, 4e0,           4e1,           4e2,  4e3,           4e4,           4e5,
                4e6,           4e7,           4e8,           4e9,           4e10, 4e11,          4e12,          4e13,
                4e14,          4e15,          4e16,          4e17,          4e18, imax(u64) - 7, imax(u64) - 6, 5e0,
                5e1,           5e2,           5e3,           5e4,           5e5,  5e6,           5e7,           5e8,
                5e9,           5e10,          5e11,          5e12,          5e13, 5e14,          5e15,          5e16,
                5e17,          5e18,          imax(u64) - 9, imax(u64) - 8, 6e0,  6e1,           6e2,           6e3,
                6e4,           6e5,           6e6,           6e7,           6e8,  6e9,           6e10,          6e11,
                6e12,          6e13,          6e14,          6e15,          6e16, 6e17,          6e18,          imax(u64) - 11,
            });
            try testArgs(@Vector(128, f64), @Vector(128, u64), .{
                imax(u64) - 10, 7e0,            7e1,            7e2,            7e3,            7e4,            7e5,            7e6,
                7e7,            7e8,            7e9,            7e10,           7e11,           7e12,           7e13,           7e14,
                7e15,           7e16,           7e17,           7e18,           imax(u64) - 13, imax(u64) - 12, 8e0,            8e1,
                8e2,            8e3,            8e4,            8e5,            8e6,            8e7,            8e8,            8e9,
                8e10,           8e11,           8e12,           8e13,           8e14,           8e15,           8e16,           8e17,
                8e18,           imax(u64) - 15, imax(u64) - 14, 9e0,            9e1,            9e2,            9e3,            9e4,
                9e5,            9e6,            9e7,            9e8,            9e9,            9e10,           9e11,           9e12,
                9e13,           9e14,           9e15,           9e16,           9e17,           9e18,           imax(u64) - 17, imax(u64) - 16,
                11e0,           11e1,           11e2,           11e3,           11e4,           11e5,           11e6,           11e7,
                11e8,           11e9,           11e10,          11e11,          11e12,          11e13,          11e14,          11e15,
                11e16,          11e17,          11e18,          imax(u64) - 19, imax(u64) - 18, 12e0,           12e1,           12e2,
                12e3,           12e4,           12e5,           12e6,           12e7,           12e8,           12e9,           12e10,
                12e11,          12e12,          12e13,          12e14,          12e15,          12e16,          12e17,          12e18,
                imax(u64) - 21, imax(u64) - 20, 13e0,           13e1,           13e2,           13e3,           13e4,           13e5,
                13e6,           13e7,           13e8,           13e9,           13e10,          13e11,          13e12,          13e13,
                13e14,          13e15,          13e16,          13e17,          13e18,          imax(u64) - 23, imax(u64) - 22, 14e0,
            });

            try testArgs(@Vector(1, f64), @Vector(1, i128), .{
                imin(i128),
            });
            try testArgs(@Vector(2, f64), @Vector(2, i128), .{
                imin(i128) + 1, -1e38,
            });
            try testArgs(@Vector(4, f64), @Vector(4, i128), .{
                -1e37, -1e36, -1e35, -1e34,
            });
            try testArgs(@Vector(8, f64), @Vector(8, i128), .{
                -1e33, -1e32, -1e31, -1e30, -1e29, -1e28, -1e27, -1e26,
            });
            try testArgs(@Vector(16, f64), @Vector(16, i128), .{
                -1e25, -1e24, -1e23, -1e22, -1e21, -1e20, -1e19, -1e18,
                -1e17, -1e16, -1e15, -1e14, -1e13, -1e12, -1e11, -1e10,
            });
            try testArgs(@Vector(32, f64), @Vector(32, i128), .{
                -1e9, -1e8, -1e7, -1e6, -1e5, -1e4, -1e3, -1e2,
                -1e1, -1e0, 0,    1e0,  1e1,  1e2,  1e3,  1e4,
                1e5,  1e6,  1e7,  1e8,  1e9,  1e10, 1e11, 1e12,
                1e13, 1e14, 1e15, 1e16, 1e17, 1e18, 1e19, 1e20,
            });
            try testArgs(@Vector(64, f64), @Vector(64, i128), .{
                1e21,  1e22,  1e23,           1e24,       1e25,           1e26,           1e27,  1e28,
                1e29,  1e30,  1e31,           1e32,       1e33,           1e34,           1e35,  1e36,
                1e37,  1e38,  imax(i128) - 1, imax(i128), imin(i128) + 2, imin(i128) + 3, -2e37, -2e36,
                -2e35, -2e34, -2e33,          -2e32,      -2e31,          -2e30,          -2e29, -2e28,
                -2e27, -2e26, -2e25,          -2e24,      -2e23,          -2e22,          -2e21, -2e20,
                -2e19, -2e18, -2e17,          -2e16,      -2e15,          -2e14,          -2e13, -2e12,
                -2e11, -2e10, -2e9,           -2e8,       -2e7,           -2e6,           -2e5,  -2e4,
                -2e3,  -2e2,  -2e1,           -2e0,       2e0,            2e1,            2e2,   2e3,
            });
            try testArgs(@Vector(128, f64), @Vector(128, i128), .{
                2e4,   2e5,   2e6,            2e7,            2e8,            2e9,            2e10,  2e11,
                2e12,  2e13,  2e14,           2e15,           2e16,           2e17,           2e18,  2e19,
                2e20,  2e21,  2e22,           2e23,           2e24,           2e25,           2e26,  2e27,
                2e28,  2e29,  2e30,           2e31,           2e32,           2e33,           2e34,  2e35,
                2e36,  2e37,  imax(i128) - 3, imax(i128) - 2, imin(i128) + 4, imin(i128) + 5, -3e37, -3e36,
                -3e35, -3e34, -3e33,          -3e32,          -3e31,          -3e30,          -3e29, -3e28,
                -3e27, -3e26, -3e25,          -3e24,          -3e23,          -3e22,          -3e21, -3e20,
                -3e19, -3e18, -3e17,          -3e16,          -3e15,          -3e14,          -3e13, -3e12,
                -3e11, -3e10, -3e9,           -3e8,           -3e7,           -3e6,           -3e5,  -3e4,
                -3e3,  -3e2,  -3e1,           -3e0,           3e0,            3e1,            3e2,   3e3,
                3e4,   3e5,   3e6,            3e7,            3e8,            3e9,            3e10,  3e11,
                3e12,  3e13,  3e14,           3e15,           3e16,           3e17,           3e18,  3e19,
                3e20,  3e21,  3e22,           3e23,           3e24,           3e25,           3e26,  3e27,
                3e28,  3e29,  3e30,           3e31,           3e32,           3e33,           3e34,  3e35,
                3e36,  3e37,  imax(i128) - 5, imax(i128) - 4, imin(i128) + 6, imin(i128) + 7, -4e37, -4e36,
                -4e35, -4e34, -4e33,          -4e32,          -4e31,          -4e30,          -4e29, -4e28,
            });

            try testArgs(@Vector(1, f64), @Vector(1, u128), .{
                0,
            });
            try testArgs(@Vector(2, f64), @Vector(2, u128), .{
                1e0, 1e1,
            });
            try testArgs(@Vector(4, f64), @Vector(4, u128), .{
                1e2, 1e3, 1e4, 1e5,
            });
            try testArgs(@Vector(8, f64), @Vector(8, u128), .{
                1e6, 1e7, 1e8, 1e9, 1e10, 1e11, 1e12, 1e13,
            });
            try testArgs(@Vector(16, f64), @Vector(16, u128), .{
                1e14, 1e15, 1e16, 1e17, 1e18, 1e19, 1e20, 1e21,
                1e22, 1e23, 1e24, 1e25, 1e26, 1e27, 1e28, 1e29,
            });
            try testArgs(@Vector(32, f64), @Vector(32, u128), .{
                1e30, 1e31,           1e32,       1e33, 1e34, 1e35, 1e36, 1e37,
                1e38, imax(u128) - 1, imax(u128), 2e0,  2e1,  2e2,  2e3,  2e4,
                2e5,  2e6,            2e7,        2e8,  2e9,  2e10, 2e11, 2e12,
                2e13, 2e14,           2e15,       2e16, 2e17, 2e18, 2e19, 2e20,
            });
            try testArgs(@Vector(64, f64), @Vector(64, u128), .{
                2e21, 2e22, 2e23,           2e24,           2e25,           2e26, 2e27, 2e28,
                2e29, 2e30, 2e31,           2e32,           2e33,           2e34, 2e35, 2e36,
                2e37, 2e38, imax(u128) - 3, imax(u128) - 2, 3e0,            3e1,  3e2,  3e3,
                3e4,  3e5,  3e6,            3e7,            3e8,            3e9,  3e10, 3e11,
                3e12, 3e13, 3e14,           3e15,           3e16,           3e17, 3e18, 3e19,
                3e20, 3e21, 3e22,           3e23,           3e24,           3e25, 3e26, 3e27,
                3e28, 3e29, 3e30,           3e31,           3e32,           3e33, 3e34, 3e35,
                3e36, 3e37, 3e38,           imax(u128) - 5, imax(u128) - 4, 4e0,  4e1,  4e2,
            });
            try testArgs(@Vector(128, f64), @Vector(128, u128), .{
                4e3,  4e4,  4e5,  4e6,             4e7,             4e8,  4e9,  4e10,
                4e11, 4e12, 4e13, 4e14,            4e15,            4e16, 4e17, 4e18,
                4e19, 4e20, 4e21, 4e22,            4e23,            4e24, 4e25, 4e26,
                4e27, 4e28, 4e29, 4e30,            4e31,            4e32, 4e33, 4e34,
                4e35, 4e36, 4e37, imax(u128) - 7,  imax(u128) - 6,  5e0,  5e1,  5e2,
                5e3,  5e4,  5e5,  5e6,             5e7,             5e8,  5e9,  5e10,
                5e11, 5e12, 5e13, 5e14,            5e15,            5e16, 5e17, 5e18,
                5e19, 5e20, 5e21, 5e22,            5e23,            5e24, 5e25, 5e26,
                5e27, 5e28, 5e29, 5e30,            5e31,            5e32, 5e33, 5e34,
                5e35, 5e36, 5e37, imax(u128) - 9,  imax(u128) - 8,  6e0,  6e1,  6e2,
                6e3,  6e4,  6e5,  6e6,             6e7,             6e8,  6e9,  6e10,
                6e11, 6e12, 6e13, 6e14,            6e15,            6e16, 6e17, 6e18,
                6e19, 6e20, 6e21, 6e22,            6e23,            6e24, 6e25, 6e26,
                6e27, 6e28, 6e29, 6e30,            6e31,            6e32, 6e33, 6e34,
                6e35, 6e36, 6e37, imax(u128) - 11, imax(u128) - 10, 7e0,  7e1,  7e2,
                7e3,  7e4,  7e5,  7e6,             7e7,             7e8,  7e9,  7e10,
            });

            try testArgs(@Vector(1, f64), @Vector(1, i256), .{
                imin(i256),
            });
            try testArgs(@Vector(2, f64), @Vector(2, i256), .{
                imin(i256) + 1, -1e76,
            });
            try testArgs(@Vector(4, f64), @Vector(4, i256), .{
                -1e75, -1e74, -1e73, -1e72,
            });
            try testArgs(@Vector(8, f64), @Vector(8, i256), .{
                -1e71, -1e70, -1e69, -1e68, -1e67, -1e66, -1e65, -1e64,
            });
            try testArgs(@Vector(16, f64), @Vector(16, i256), .{
                -1e63, -1e62, -1e61, -1e60, -1e59, -1e58, -1e57, -1e56,
                -1e55, -1e54, -1e53, -1e52, -1e51, -1e50, -1e49, -1e48,
            });
            try testArgs(@Vector(32, f64), @Vector(32, i256), .{
                -1e47, -1e46, -1e45, -1e44, -1e43, -1e42, -1e41, -1e40,
                -1e39, -1e38, -1e37, -1e36, -1e35, -1e34, -1e33, -1e32,
                -1e31, -1e30, -1e29, -1e28, -1e27, -1e26, -1e25, -1e24,
                -1e23, -1e22, -1e21, -1e20, -1e19, -1e18, -1e17, -1e16,
            });
            try testArgs(@Vector(64, f64), @Vector(64, i256), .{
                -1e15, -1e14, -1e13, -1e12, -1e11, -1e10, -1e9, -1e8,
                -1e7,  -1e6,  -1e5,  -1e4,  -1e3,  -1e2,  -1e1, -1e0,
                0,     1e0,   1e1,   1e2,   1e3,   1e4,   1e5,  1e6,
                1e7,   1e8,   1e9,   1e10,  1e11,  1e12,  1e13, 1e14,
                1e15,  1e16,  1e17,  1e18,  1e19,  1e20,  1e21, 1e22,
                1e23,  1e24,  1e25,  1e26,  1e27,  1e28,  1e29, 1e30,
                1e31,  1e32,  1e33,  1e34,  1e35,  1e36,  1e37, 1e38,
                1e39,  1e40,  1e41,  1e42,  1e43,  1e44,  1e45, 1e46,
            });
            try testArgs(@Vector(128, f64), @Vector(128, i256), .{
                1e47,           1e48,           1e49,  1e50,  1e51,  1e52,  1e53,           1e54,
                1e55,           1e56,           1e57,  1e58,  1e59,  1e60,  1e61,           1e62,
                1e63,           1e64,           1e65,  1e66,  1e67,  1e68,  1e69,           1e70,
                1e71,           1e72,           1e73,  1e74,  1e75,  1e76,  imax(i256) - 1, imax(i256),
                imin(i256) + 2, imin(i256) + 3, -2e76, -2e75, -2e74, -2e73, -2e72,          -2e71,
                -2e70,          -2e69,          -2e68, -2e67, -2e66, -2e65, -2e64,          -2e63,
                -2e62,          -2e61,          -2e60, -2e59, -2e58, -2e57, -2e56,          -2e55,
                -2e54,          -2e53,          -2e52, -2e51, -2e50, -2e49, -2e48,          -2e47,
                -2e46,          -2e45,          -2e44, -2e43, -2e42, -2e41, -2e40,          -2e39,
                -2e38,          -2e37,          -2e36, -2e35, -2e34, -2e33, -2e32,          -2e31,
                -2e30,          -2e29,          -2e28, -2e27, -2e26, -2e25, -2e24,          -2e23,
                -2e22,          -2e21,          -2e20, -2e19, -2e18, -2e17, -2e16,          -2e15,
                -2e14,          -2e13,          -2e12, -2e11, -2e10, -2e9,  -2e8,           -2e7,
                -2e6,           -2e5,           -2e4,  -2e3,  -2e2,  -2e1,  -2e0,           2e0,
                2e1,            2e2,            2e3,   2e4,   2e5,   2e6,   2e7,            2e8,
                2e9,            2e10,           2e11,  2e12,  2e13,  2e14,  2e15,           2e16,
            });

            try testArgs(@Vector(1, f64), @Vector(1, u256), .{
                0,
            });
            try testArgs(@Vector(2, f64), @Vector(2, u256), .{
                1e0, 1e1,
            });
            try testArgs(@Vector(4, f64), @Vector(4, u256), .{
                1e2, 1e3, 1e4, 1e5,
            });
            try testArgs(@Vector(8, f64), @Vector(8, u256), .{
                1e6, 1e7, 1e8, 1e9, 1e10, 1e11, 1e12, 1e13,
            });
            try testArgs(@Vector(16, f64), @Vector(16, u256), .{
                1e14, 1e15, 1e16, 1e17, 1e18, 1e19, 1e20, 1e21,
                1e22, 1e23, 1e24, 1e25, 1e26, 1e27, 1e28, 1e29,
            });
            try testArgs(@Vector(32, f64), @Vector(32, u256), .{
                1e30, 1e31, 1e32, 1e33, 1e34, 1e35, 1e36, 1e37,
                1e38, 1e39, 1e40, 1e41, 1e42, 1e43, 1e44, 1e45,
                1e46, 1e47, 1e48, 1e49, 1e50, 1e51, 1e52, 1e53,
                1e54, 1e55, 1e56, 1e57, 1e58, 1e59, 1e60, 1e61,
            });
            try testArgs(@Vector(64, f64), @Vector(64, u256), .{
                1e62,           1e63,       1e64, 1e65, 1e66, 1e67, 1e68, 1e69,
                1e70,           1e71,       1e72, 1e73, 1e74, 1e75, 1e76, 1e77,
                imax(u256) - 1, imax(u256), 2e0,  2e1,  2e2,  2e3,  2e4,  2e5,
                2e6,            2e7,        2e8,  2e9,  2e10, 2e11, 2e12, 2e13,
                2e14,           2e15,       2e16, 2e17, 2e18, 2e19, 2e20, 2e21,
                2e22,           2e23,       2e24, 2e25, 2e26, 2e27, 2e28, 2e29,
                2e30,           2e31,       2e32, 2e33, 2e34, 2e35, 2e36, 2e37,
                2e38,           2e39,       2e40, 2e41, 2e42, 2e43, 2e44, 2e45,
            });
            try testArgs(@Vector(128, f64), @Vector(128, u256), .{
                2e46,           2e47, 2e48, 2e49, 2e50, 2e51, 2e52,           2e53,
                2e54,           2e55, 2e56, 2e57, 2e58, 2e59, 2e60,           2e61,
                2e62,           2e63, 2e64, 2e65, 2e66, 2e67, 2e68,           2e69,
                2e70,           2e71, 2e72, 2e73, 2e74, 2e75, 2e76,           imax(u256) - 3,
                imax(u256) - 2, 3e0,  3e1,  3e2,  3e3,  3e4,  3e5,            3e6,
                3e7,            3e8,  3e9,  3e10, 3e11, 3e12, 3e13,           3e14,
                3e15,           3e16, 3e17, 3e18, 3e19, 3e20, 3e21,           3e22,
                3e23,           3e24, 3e25, 3e26, 3e27, 3e28, 3e29,           3e30,
                3e31,           3e32, 3e33, 3e34, 3e35, 3e36, 3e37,           3e38,
                3e39,           3e40, 3e41, 3e42, 3e43, 3e44, 3e45,           3e46,
                3e47,           3e48, 3e49, 3e50, 3e51, 3e52, 3e53,           3e54,
                3e55,           3e56, 3e57, 3e58, 3e59, 3e60, 3e61,           3e62,
                3e63,           3e64, 3e65, 3e66, 3e67, 3e68, 3e69,           3e70,
                3e71,           3e72, 3e73, 3e74, 3e75, 3e76, imax(u256) - 5, imax(u256) - 4,
                4e0,            4e1,  4e2,  4e3,  4e4,  4e5,  4e6,            4e7,
                4e8,            4e9,  4e10, 4e11, 4e12, 4e13, 4e14,           4e15,
            });

            try testArgs(@Vector(1, f80), @Vector(1, i8), .{
                imin(i8),
            });
            try testArgs(@Vector(2, f80), @Vector(2, i8), .{
                imin(i8) + 1, -1e2,
            });
            try testArgs(@Vector(4, f80), @Vector(4, i8), .{
                -1e1, -1e0, 0, 1e0,
            });
            try testArgs(@Vector(8, f80), @Vector(8, i8), .{
                1e1, 1e2, imax(i8) - 1, imax(i8), imin(i8) + 2, imin(i8) + 3, -2e1, -2e0,
            });
            try testArgs(@Vector(16, f80), @Vector(16, i8), .{
                2e0, 2e1, imax(i8) - 3, imax(i8) - 2, imin(i8) + 4, imin(i8) + 5, -3e1, -3e0,
                3e0, 3e1, imax(i8) - 5, imax(i8) - 4, imin(i8) + 6, imin(i8) + 7, -4e1, -4e0,
            });
            try testArgs(@Vector(32, f80), @Vector(32, i8), .{
                4e0, 4e1, imax(i8) - 7,  imax(i8) - 6,  imin(i8) + 8,  imin(i8) + 9,  -5e1, -5e0,
                5e0, 5e1, imax(i8) - 9,  imax(i8) - 8,  imin(i8) + 10, imin(i8) + 11, -6e1, -6e0,
                6e0, 6e1, imax(i8) - 11, imax(i8) - 10, imin(i8) + 12, imin(i8) + 13, -7e1, -7e0,
                7e0, 7e1, imax(i8) - 13, imax(i8) - 12, imin(i8) + 14, imin(i8) + 15, -8e1, -8e0,
            });
            try testArgs(@Vector(64, f80), @Vector(64, i8), .{
                8e0,           8e1,           imax(i8) - 15, imax(i8) - 14, imin(i8) + 16, imin(i8) + 17, -9e1,          -9e0,
                9e0,           9e1,           imax(i8) - 17, imax(i8) - 16, imin(i8) + 18, imin(i8) + 19, -11e1,         -11e0,
                11e0,          11e1,          imax(i8) - 19, imax(i8) - 18, imin(i8) + 20, imin(i8) + 21, -12e1,         -12e0,
                12e0,          12e1,          imax(i8) - 21, imax(i8) - 20, imin(i8) + 22, imin(i8) + 23, -13e0,         13e0,
                imax(i8) - 23, imax(i8) - 22, imin(i8) + 24, imin(i8) + 25, -14e0,         14e0,          imax(i8) - 25, imax(i8) - 24,
                imin(i8) + 26, imin(i8) + 27, -15e0,         15e0,          imax(i8) - 27, imax(i8) - 26, imin(i8) + 28, imin(i8) + 29,
                -16e0,         16e0,          imax(i8) - 29, imax(i8) - 28, imin(i8) + 30, imin(i8) + 31, -17e0,         17e0,
                imax(i8) - 31, imax(i8) - 30, imin(i8) + 32, imin(i8) + 33, -18e0,         18e0,          imax(i8) - 33, imax(i8) - 32,
            });

            try testArgs(@Vector(1, f80), @Vector(1, u8), .{
                0,
            });
            try testArgs(@Vector(2, f80), @Vector(2, u8), .{
                1e0, 1e1,
            });
            try testArgs(@Vector(4, f80), @Vector(4, u8), .{
                1e2, imax(u8) - 1, imax(u8), 2e0,
            });
            try testArgs(@Vector(8, f80), @Vector(8, u8), .{
                2e1, 2e2, imax(u8) - 3, imax(u8) - 2, 3e0, 3e1, imax(u8) - 5, imax(u8) - 4,
            });
            try testArgs(@Vector(16, f80), @Vector(16, u8), .{
                imax(u8) - 7,  imax(u8) - 6,  5e0, 5e1, imax(u8) - 9,  imax(u8) - 8,  6e0, 6e1,
                imax(u8) - 11, imax(u8) - 10, 7e0, 7e1, imax(u8) - 13, imax(u8) - 12, 8e0, 8e1,
            });
            try testArgs(@Vector(32, f80), @Vector(32, u8), .{
                imax(u8) - 15, imax(u8) - 14, 9e0,  9e1,  imax(u8) - 17, imax(u8) - 16, 11e0, 11e1,
                imax(u8) - 19, imax(u8) - 18, 12e0, 12e1, imax(u8) - 21, imax(u8) - 20, 13e0, 13e1,
                imax(u8) - 23, imax(u8) - 22, 14e0, 14e1, imax(u8) - 25, imax(u8) - 24, 15e0, 15e1,
                imax(u8) - 27, imax(u8) - 26, 16e0, 16e1, imax(u8) - 29, imax(u8) - 28, 17e0, 17e1,
            });
            try testArgs(@Vector(64, f80), @Vector(64, u8), .{
                imax(u8) - 31, imax(u8) - 30, 18e0,          18e1,          imax(u8) - 33, imax(u8) - 32, 19e0,          19e1,
                imax(u8) - 35, imax(u8) - 34, 21e0,          21e1,          imax(u8) - 37, imax(u8) - 36, 22e0,          22e1,
                imax(u8) - 39, imax(u8) - 38, 23e0,          23e1,          imax(u8) - 41, imax(u8) - 40, 24e0,          24e1,
                imax(u8) - 43, imax(u8) - 42, 25e0,          25e1,          imax(u8) - 45, imax(u8) - 44, 26e0,          imax(u8) - 47,
                imax(u8) - 46, 27e0,          imax(u8) - 49, imax(u8) - 48, 28e0,          imax(u8) - 51, imax(u8) - 50, 29e0,
                imax(u8) - 53, imax(u8) - 52, 31e0,          imax(u8) - 55, imax(u8) - 54, 32e0,          imax(u8) - 57, imax(u8) - 56,
                33e0,          imax(u8) - 59, imax(u8) - 58, 34e0,          imax(u8) - 61, imax(u8) - 60, 35e0,          imax(u8) - 63,
                imax(u8) - 62, 36e0,          imax(u8) - 65, imax(u8) - 64, 37e0,          imax(u8) - 67, imax(u8) - 66, 38e0,
            });

            try testArgs(@Vector(1, f80), @Vector(1, i16), .{
                imin(i16),
            });
            try testArgs(@Vector(2, f80), @Vector(2, i16), .{
                imin(i16) + 1, -1e4,
            });
            try testArgs(@Vector(4, f80), @Vector(4, i16), .{
                -1e3, -1e2, -1e1, -1e0,
            });
            try testArgs(@Vector(8, f80), @Vector(8, i16), .{
                0, 1e0, 1e1, 1e2, 1e3, 1e4, imax(i16) - 1, imax(i16),
            });
            try testArgs(@Vector(16, f80), @Vector(16, i16), .{
                imin(i16) + 2, imin(i16) + 3, -2e4, -2e3, -2e2,          -2e1,          -2e0,          2e0,
                2e1,           2e2,           2e3,  2e4,  imax(i16) - 3, imax(i16) - 2, imin(i16) + 4, imin(i16) + 5,
            });
            try testArgs(@Vector(32, f80), @Vector(32, i16), .{
                -3e4,          -3e3,          -3e2,          -3e1,          -3e0,          3e0,           3e1,           3e2,
                3e3,           3e4,           imax(i16) - 5, imax(i16) - 4, imin(i16) + 6, imin(i16) + 7, -4e3,          -4e2,
                -4e1,          -4e0,          4e0,           4e1,           4e2,           4e3,           imax(i16) - 7, imax(i16) - 6,
                imin(i16) + 8, imin(i16) + 9, -5e3,          -5e2,          -5e1,          -5e0,          5e0,           5e1,
            });
            try testArgs(@Vector(64, f80), @Vector(64, i16), .{
                5e2,            5e3,            imax(i16) - 9,  imax(i16) - 8,  imin(i16) + 10, imin(i16) + 11, -6e3,           -6e2,
                -6e1,           -6e0,           6e0,            6e1,            6e2,            6e3,            imax(i16) - 11, imax(i16) - 10,
                imin(i16) + 12, imin(i16) + 13, -7e3,           -7e2,           -7e1,           -7e0,           7e0,            7e1,
                7e2,            7e3,            imax(i16) - 13, imax(i16) - 12, imin(i16) + 14, imin(i16) + 15, -8e3,           -8e2,
                -8e1,           -8e0,           8e0,            8e1,            8e2,            8e3,            imax(i16) - 15, imax(i16) - 14,
                imin(i16) + 16, imin(i16) + 17, -9e3,           -9e2,           -9e1,           -9e0,           9e0,            9e1,
                9e2,            9e3,            imax(i16) - 17, imax(i16) - 16, imin(i16) + 18, imin(i16) + 19, -11e3,          -11e2,
                -11e1,          -11e0,          11e0,           11e1,           11e2,           11e3,           imax(i16) - 19, imax(i16) - 18,
            });

            try testArgs(@Vector(1, f80), @Vector(1, u16), .{
                0,
            });
            try testArgs(@Vector(2, f80), @Vector(2, u16), .{
                1e0, 1e1,
            });
            try testArgs(@Vector(4, f80), @Vector(4, u16), .{
                1e2, 1e3, 1e4, imax(u16) - 1,
            });
            try testArgs(@Vector(8, f80), @Vector(8, u16), .{
                imax(u16), 2e0, 2e1, 2e2, 2e3, 2e4, imax(u16) - 3, imax(u16) - 2,
            });
            try testArgs(@Vector(16, f80), @Vector(16, u16), .{
                3e0, 3e1, 3e2, 3e3, 3e4,           imax(u16) - 5, imax(u16) - 4, 4e0,
                4e1, 4e2, 4e3, 4e4, imax(u16) - 7, imax(u16) - 6, 5e0,           5e1,
            });
            try testArgs(@Vector(32, f80), @Vector(32, u16), .{
                5e2,            5e3,            5e4,            imax(u16) - 9,  imax(u16) - 8,  6e0,            6e1,            6e2,
                6e3,            6e4,            imax(u16) - 11, imax(u16) - 10, 7e0,            7e1,            7e2,            7e3,
                imax(u16) - 13, imax(u16) - 12, 8e0,            8e1,            8e2,            8e3,            imax(u16) - 15, imax(u16) - 14,
                9e0,            9e1,            9e2,            9e3,            imax(u16) - 17, imax(u16) - 16, 11e0,           11e1,
            });
            try testArgs(@Vector(64, f80), @Vector(64, u16), .{
                11e2,           11e3,           imax(u16) - 19, imax(u16) - 18, 12e0,           12e1,           12e2,           12e3,
                imax(u16) - 21, imax(u16) - 20, 13e0,           13e1,           13e2,           13e3,           imax(u16) - 23, imax(u16) - 22,
                14e0,           14e1,           14e2,           14e3,           imax(u16) - 25, imax(u16) - 24, 15e0,           15e1,
                15e2,           15e3,           imax(u16) - 27, imax(u16) - 26, 16e0,           16e1,           16e2,           16e3,
                imax(u16) - 29, imax(u16) - 28, 17e0,           17e1,           17e2,           17e3,           imax(u16) - 31, imax(u16) - 30,
                18e0,           18e1,           18e2,           18e3,           imax(u16) - 33, imax(u16) - 32, 19e0,           19e1,
                19e2,           19e3,           imax(u16) - 35, imax(u16) - 34, 21e0,           21e1,           21e2,           21e3,
                imax(u16) - 37, imax(u16) - 36, 22e0,           22e1,           22e2,           22e3,           imax(u16) - 39, imax(u16) - 38,
            });

            try testArgs(@Vector(1, f80), @Vector(1, i32), .{
                imin(i32),
            });
            try testArgs(@Vector(2, f80), @Vector(2, i32), .{
                imin(i32) + 1, -1e9,
            });
            try testArgs(@Vector(4, f80), @Vector(4, i32), .{
                -1e8, -1e7, -1e6, -1e5,
            });
            try testArgs(@Vector(8, f80), @Vector(8, i32), .{
                -1e4, -1e3, -1e2, -1e1, -1e0, 0, 1e0, 1e1,
            });
            try testArgs(@Vector(16, f80), @Vector(16, i32), .{
                1e2,           1e3,       1e4,           1e5,           1e6,  1e7,  1e8,  1e9,
                imax(i32) - 1, imax(i32), imin(i32) + 2, imin(i32) + 3, -2e9, -2e8, -2e7, -2e6,
            });
            try testArgs(@Vector(32, f80), @Vector(32, i32), .{
                -2e5,          -2e4,          -2e3,          -2e2,          -2e1, -2e0, 2e0,  2e1,
                2e2,           2e3,           2e4,           2e5,           2e6,  2e7,  2e8,  2e9,
                imax(i32) - 3, imax(i32) - 2, imin(i32) + 4, imin(i32) + 5, -3e8, -3e7, -3e6, -3e5,
                -3e4,          -3e3,          -3e2,          -3e1,          -3e0, 3e0,  3e1,  3e2,
            });
            try testArgs(@Vector(64, f80), @Vector(64, i32), .{
                3e3,           3e4,           3e5,           3e6,           3e7,            3e8,            imax(i32) - 5, imax(i32) - 4,
                imin(i32) + 6, imin(i32) + 7, -4e8,          -4e7,          -4e6,           -4e5,           -4e4,          -4e3,
                -4e2,          -4e1,          -4e0,          4e0,           4e1,            4e2,            4e3,           4e4,
                4e5,           4e6,           4e7,           4e8,           imax(i32) - 7,  imax(i32) - 6,  imin(i32) + 8, imin(i32) + 9,
                -5e8,          -5e7,          -5e6,          -5e5,          -5e4,           -5e3,           -5e2,          -5e1,
                -5e0,          5e0,           5e1,           5e2,           5e3,            5e4,            5e5,           5e6,
                5e7,           5e8,           imax(i32) - 9, imax(i32) - 8, imin(i32) + 10, imin(i32) + 11, -6e8,          -6e7,
                -6e6,          -6e5,          -6e4,          -6e3,          -6e2,           -6e1,           -6e0,          6e0,
            });

            try testArgs(@Vector(1, f80), @Vector(1, u32), .{
                0,
            });
            try testArgs(@Vector(2, f80), @Vector(2, u32), .{
                1e0, 1e1,
            });
            try testArgs(@Vector(4, f80), @Vector(4, u32), .{
                1e2, 1e3, 1e4, imax(u32) - 1,
            });
            try testArgs(@Vector(8, f80), @Vector(8, u32), .{
                imax(u32), 2e0, 2e1, 2e2, 2e3, 2e4, imax(u32) - 3, imax(u32) - 2,
            });
            try testArgs(@Vector(16, f80), @Vector(16, u32), .{
                3e0, 3e1, 3e2, 3e3, 3e4,           imax(u32) - 5, imax(u32) - 4, 4e0,
                4e1, 4e2, 4e3, 4e4, imax(u32) - 7, imax(u32) - 6, 5e0,           5e1,
            });
            try testArgs(@Vector(32, f80), @Vector(32, u32), .{
                5e2,            5e3,            5e4,            imax(u32) - 9,  imax(u32) - 8,  6e0,            6e1,            6e2,
                6e3,            6e4,            imax(u32) - 11, imax(u32) - 10, 7e0,            7e1,            7e2,            7e3,
                imax(u32) - 13, imax(u32) - 12, 8e0,            8e1,            8e2,            8e3,            imax(u32) - 15, imax(u32) - 14,
                9e0,            9e1,            9e2,            9e3,            imax(u32) - 17, imax(u32) - 16, 11e0,           11e1,
            });
            try testArgs(@Vector(64, f80), @Vector(64, u32), .{
                11e2,           11e3,           imax(u32) - 19, imax(u32) - 18, 12e0,           12e1,           12e2,           12e3,
                imax(u32) - 21, imax(u32) - 20, 13e0,           13e1,           13e2,           13e3,           imax(u32) - 23, imax(u32) - 22,
                14e0,           14e1,           14e2,           14e3,           imax(u32) - 25, imax(u32) - 24, 15e0,           15e1,
                15e2,           15e3,           imax(u32) - 27, imax(u32) - 26, 16e0,           16e1,           16e2,           16e3,
                imax(u32) - 29, imax(u32) - 28, 17e0,           17e1,           17e2,           17e3,           imax(u32) - 31, imax(u32) - 30,
                18e0,           18e1,           18e2,           18e3,           imax(u32) - 33, imax(u32) - 32, 19e0,           19e1,
                19e2,           19e3,           imax(u32) - 35, imax(u32) - 34, 21e0,           21e1,           21e2,           21e3,
                imax(u32) - 37, imax(u32) - 36, 22e0,           22e1,           22e2,           22e3,           imax(u32) - 39, imax(u32) - 38,
            });

            try testArgs(@Vector(1, f80), @Vector(1, i64), .{
                imin(i64),
            });
            try testArgs(@Vector(2, f80), @Vector(2, i64), .{
                imin(i64) + 1, -1e18,
            });
            try testArgs(@Vector(4, f80), @Vector(4, i64), .{
                -1e17, -1e16, -1e15, -1e14,
            });
            try testArgs(@Vector(8, f80), @Vector(8, i64), .{
                -1e13, -1e12, -1e11, -1e10, -1e9, -1e8, -1e7, -1e6,
            });
            try testArgs(@Vector(16, f80), @Vector(16, i64), .{
                -1e5, -1e4, -1e3, -1e2, -1e1, -1e0, 0,   1e0,
                1e1,  1e2,  1e3,  1e4,  1e5,  1e6,  1e7, 1e8,
            });
            try testArgs(@Vector(32, f80), @Vector(32, i64), .{
                1e9,   1e10,  1e11,          1e12,      1e13,          1e14,          1e15,  1e16,
                1e17,  1e18,  imax(i64) - 1, imax(i64), imin(i64) + 2, imin(i64) + 3, -2e18, -2e17,
                -2e16, -2e15, -2e14,         -2e13,     -2e12,         -2e11,         -2e10, -2e9,
                -2e8,  -2e7,  -2e6,          -2e5,      -2e4,          -2e3,          -2e2,  -2e1,
            });
            try testArgs(@Vector(64, f80), @Vector(64, i64), .{
                -2e0,  2e0,   2e1,   2e2,   2e3,           2e4,           2e5,           2e6,
                2e7,   2e8,   2e9,   2e10,  2e11,          2e12,          2e13,          2e14,
                2e15,  2e16,  2e17,  2e18,  imax(i64) - 3, imax(i64) - 2, imin(i64) + 4, imin(i64) + 5,
                -3e18, -3e17, -3e16, -3e15, -3e14,         -3e13,         -3e12,         -3e11,
                -3e10, -3e9,  -3e8,  -3e7,  -3e6,          -3e5,          -3e4,          -3e3,
                -3e2,  -3e1,  -3e0,  3e0,   3e1,           3e2,           3e3,           3e4,
                3e5,   3e6,   3e7,   3e8,   3e9,           3e10,          3e11,          3e12,
                3e13,  3e14,  3e15,  3e16,  3e17,          3e18,          imax(i64) - 5, imax(i64) - 4,
            });

            try testArgs(@Vector(1, f80), @Vector(1, u64), .{
                0,
            });
            try testArgs(@Vector(2, f80), @Vector(2, u64), .{
                1e0, 1e1,
            });
            try testArgs(@Vector(4, f80), @Vector(4, u64), .{
                1e2, 1e3, 1e4, 1e5,
            });
            try testArgs(@Vector(8, f80), @Vector(8, u64), .{
                1e6, 1e7, 1e8, 1e9, 1e10, 1e11, 1e12, 1e13,
            });
            try testArgs(@Vector(16, f80), @Vector(16, u64), .{
                1e14, 1e15, 1e16, 1e17, 1e18, 1e19, imax(u64) - 1, imax(u64),
                2e0,  2e1,  2e2,  2e3,  2e4,  2e5,  2e6,           2e7,
            });
            try testArgs(@Vector(32, f80), @Vector(32, u64), .{
                2e8,  2e9,  2e10, 2e11,          2e12,          2e13, 2e14, 2e15,
                2e16, 2e17, 2e18, imax(u64) - 3, imax(u64) - 2, 3e0,  3e1,  3e2,
                3e3,  3e4,  3e5,  3e6,           3e7,           3e8,  3e9,  3e10,
                3e11, 3e12, 3e13, 3e14,          3e15,          3e16, 3e17, 3e18,
            });
            try testArgs(@Vector(64, f80), @Vector(64, u64), .{
                imax(u64) - 5, imax(u64) - 4, 4e0,           4e1,           4e2,  4e3,           4e4,           4e5,
                4e6,           4e7,           4e8,           4e9,           4e10, 4e11,          4e12,          4e13,
                4e14,          4e15,          4e16,          4e17,          4e18, imax(u64) - 7, imax(u64) - 6, 5e0,
                5e1,           5e2,           5e3,           5e4,           5e5,  5e6,           5e7,           5e8,
                5e9,           5e10,          5e11,          5e12,          5e13, 5e14,          5e15,          5e16,
                5e17,          5e18,          imax(u64) - 9, imax(u64) - 8, 6e0,  6e1,           6e2,           6e3,
                6e4,           6e5,           6e6,           6e7,           6e8,  6e9,           6e10,          6e11,
                6e12,          6e13,          6e14,          6e15,          6e16, 6e17,          6e18,          imax(u64) - 11,
            });

            try testArgs(@Vector(1, f80), @Vector(1, i128), .{
                imin(i128),
            });
            try testArgs(@Vector(2, f80), @Vector(2, i128), .{
                imin(i128) + 1, -1e38,
            });
            try testArgs(@Vector(4, f80), @Vector(4, i128), .{
                -1e37, -1e36, -1e35, -1e34,
            });
            try testArgs(@Vector(8, f80), @Vector(8, i128), .{
                -1e33, -1e32, -1e31, -1e30, -1e29, -1e28, -1e27, -1e26,
            });
            try testArgs(@Vector(16, f80), @Vector(16, i128), .{
                -1e25, -1e24, -1e23, -1e22, -1e21, -1e20, -1e19, -1e18,
                -1e17, -1e16, -1e15, -1e14, -1e13, -1e12, -1e11, -1e10,
            });
            try testArgs(@Vector(32, f80), @Vector(32, i128), .{
                -1e9, -1e8, -1e7, -1e6, -1e5, -1e4, -1e3, -1e2,
                -1e1, -1e0, 0,    1e0,  1e1,  1e2,  1e3,  1e4,
                1e5,  1e6,  1e7,  1e8,  1e9,  1e10, 1e11, 1e12,
                1e13, 1e14, 1e15, 1e16, 1e17, 1e18, 1e19, 1e20,
            });
            try testArgs(@Vector(64, f80), @Vector(64, i128), .{
                1e21,  1e22,  1e23,           1e24,       1e25,           1e26,           1e27,  1e28,
                1e29,  1e30,  1e31,           1e32,       1e33,           1e34,           1e35,  1e36,
                1e37,  1e38,  imax(i128) - 1, imax(i128), imin(i128) + 2, imin(i128) + 3, -2e37, -2e36,
                -2e35, -2e34, -2e33,          -2e32,      -2e31,          -2e30,          -2e29, -2e28,
                -2e27, -2e26, -2e25,          -2e24,      -2e23,          -2e22,          -2e21, -2e20,
                -2e19, -2e18, -2e17,          -2e16,      -2e15,          -2e14,          -2e13, -2e12,
                -2e11, -2e10, -2e9,           -2e8,       -2e7,           -2e6,           -2e5,  -2e4,
                -2e3,  -2e2,  -2e1,           -2e0,       2e0,            2e1,            2e2,   2e3,
            });

            try testArgs(@Vector(1, f80), @Vector(1, u128), .{
                0,
            });
            try testArgs(@Vector(2, f80), @Vector(2, u128), .{
                1e0, 1e1,
            });
            try testArgs(@Vector(4, f80), @Vector(4, u128), .{
                1e2, 1e3, 1e4, 1e5,
            });
            try testArgs(@Vector(8, f80), @Vector(8, u128), .{
                1e6, 1e7, 1e8, 1e9, 1e10, 1e11, 1e12, 1e13,
            });
            try testArgs(@Vector(16, f80), @Vector(16, u128), .{
                1e14, 1e15, 1e16, 1e17, 1e18, 1e19, 1e20, 1e21,
                1e22, 1e23, 1e24, 1e25, 1e26, 1e27, 1e28, 1e29,
            });
            try testArgs(@Vector(32, f80), @Vector(32, u128), .{
                1e30, 1e31,           1e32,       1e33, 1e34, 1e35, 1e36, 1e37,
                1e38, imax(u128) - 1, imax(u128), 2e0,  2e1,  2e2,  2e3,  2e4,
                2e5,  2e6,            2e7,        2e8,  2e9,  2e10, 2e11, 2e12,
                2e13, 2e14,           2e15,       2e16, 2e17, 2e18, 2e19, 2e20,
            });
            try testArgs(@Vector(64, f80), @Vector(64, u128), .{
                2e21, 2e22, 2e23,           2e24,           2e25,           2e26, 2e27, 2e28,
                2e29, 2e30, 2e31,           2e32,           2e33,           2e34, 2e35, 2e36,
                2e37, 2e38, imax(u128) - 3, imax(u128) - 2, 3e0,            3e1,  3e2,  3e3,
                3e4,  3e5,  3e6,            3e7,            3e8,            3e9,  3e10, 3e11,
                3e12, 3e13, 3e14,           3e15,           3e16,           3e17, 3e18, 3e19,
                3e20, 3e21, 3e22,           3e23,           3e24,           3e25, 3e26, 3e27,
                3e28, 3e29, 3e30,           3e31,           3e32,           3e33, 3e34, 3e35,
                3e36, 3e37, 3e38,           imax(u128) - 5, imax(u128) - 4, 4e0,  4e1,  4e2,
            });

            try testArgs(@Vector(1, f80), @Vector(1, i256), .{
                imin(i256),
            });
            try testArgs(@Vector(2, f80), @Vector(2, i256), .{
                imin(i256) + 1, -1e76,
            });
            try testArgs(@Vector(4, f80), @Vector(4, i256), .{
                -1e75, -1e74, -1e73, -1e72,
            });
            try testArgs(@Vector(8, f80), @Vector(8, i256), .{
                -1e71, -1e70, -1e69, -1e68, -1e67, -1e66, -1e65, -1e64,
            });
            try testArgs(@Vector(16, f80), @Vector(16, i256), .{
                -1e63, -1e62, -1e61, -1e60, -1e59, -1e58, -1e57, -1e56,
                -1e55, -1e54, -1e53, -1e52, -1e51, -1e50, -1e49, -1e48,
            });
            try testArgs(@Vector(32, f80), @Vector(32, i256), .{
                -1e47, -1e46, -1e45, -1e44, -1e43, -1e42, -1e41, -1e40,
                -1e39, -1e38, -1e37, -1e36, -1e35, -1e34, -1e33, -1e32,
                -1e31, -1e30, -1e29, -1e28, -1e27, -1e26, -1e25, -1e24,
                -1e23, -1e22, -1e21, -1e20, -1e19, -1e18, -1e17, -1e16,
            });
            try testArgs(@Vector(64, f80), @Vector(64, i256), .{
                -1e15, -1e14, -1e13, -1e12, -1e11, -1e10, -1e9, -1e8,
                -1e7,  -1e6,  -1e5,  -1e4,  -1e3,  -1e2,  -1e1, -1e0,
                0,     1e0,   1e1,   1e2,   1e3,   1e4,   1e5,  1e6,
                1e7,   1e8,   1e9,   1e10,  1e11,  1e12,  1e13, 1e14,
                1e15,  1e16,  1e17,  1e18,  1e19,  1e20,  1e21, 1e22,
                1e23,  1e24,  1e25,  1e26,  1e27,  1e28,  1e29, 1e30,
                1e31,  1e32,  1e33,  1e34,  1e35,  1e36,  1e37, 1e38,
                1e39,  1e40,  1e41,  1e42,  1e43,  1e44,  1e45, 1e46,
            });

            try testArgs(@Vector(1, f80), @Vector(1, u256), .{
                0,
            });
            try testArgs(@Vector(2, f80), @Vector(2, u256), .{
                1e0, 1e1,
            });
            try testArgs(@Vector(4, f80), @Vector(4, u256), .{
                1e2, 1e3, 1e4, 1e5,
            });
            try testArgs(@Vector(8, f80), @Vector(8, u256), .{
                1e6, 1e7, 1e8, 1e9, 1e10, 1e11, 1e12, 1e13,
            });
            try testArgs(@Vector(16, f80), @Vector(16, u256), .{
                1e14, 1e15, 1e16, 1e17, 1e18, 1e19, 1e20, 1e21,
                1e22, 1e23, 1e24, 1e25, 1e26, 1e27, 1e28, 1e29,
            });
            try testArgs(@Vector(32, f80), @Vector(32, u256), .{
                1e30, 1e31, 1e32, 1e33, 1e34, 1e35, 1e36, 1e37,
                1e38, 1e39, 1e40, 1e41, 1e42, 1e43, 1e44, 1e45,
                1e46, 1e47, 1e48, 1e49, 1e50, 1e51, 1e52, 1e53,
                1e54, 1e55, 1e56, 1e57, 1e58, 1e59, 1e60, 1e61,
            });
            try testArgs(@Vector(64, f80), @Vector(64, u256), .{
                1e62,           1e63,       1e64, 1e65, 1e66, 1e67, 1e68, 1e69,
                1e70,           1e71,       1e72, 1e73, 1e74, 1e75, 1e76, 1e77,
                imax(u256) - 1, imax(u256), 2e0,  2e1,  2e2,  2e3,  2e4,  2e5,
                2e6,            2e7,        2e8,  2e9,  2e10, 2e11, 2e12, 2e13,
                2e14,           2e15,       2e16, 2e17, 2e18, 2e19, 2e20, 2e21,
                2e22,           2e23,       2e24, 2e25, 2e26, 2e27, 2e28, 2e29,
                2e30,           2e31,       2e32, 2e33, 2e34, 2e35, 2e36, 2e37,
                2e38,           2e39,       2e40, 2e41, 2e42, 2e43, 2e44, 2e45,
            });

            try testArgs(@Vector(1, f128), @Vector(1, i8), .{
                imin(i8),
            });
            try testArgs(@Vector(2, f128), @Vector(2, i8), .{
                imin(i8) + 1, -1e2,
            });
            try testArgs(@Vector(4, f128), @Vector(4, i8), .{
                -1e1, -1e0, 0, 1e0,
            });
            try testArgs(@Vector(8, f128), @Vector(8, i8), .{
                1e1, 1e2, imax(i8) - 1, imax(i8), imin(i8) + 2, imin(i8) + 3, -2e1, -2e0,
            });
            try testArgs(@Vector(16, f128), @Vector(16, i8), .{
                2e0, 2e1, imax(i8) - 3, imax(i8) - 2, imin(i8) + 4, imin(i8) + 5, -3e1, -3e0,
                3e0, 3e1, imax(i8) - 5, imax(i8) - 4, imin(i8) + 6, imin(i8) + 7, -4e1, -4e0,
            });
            try testArgs(@Vector(32, f128), @Vector(32, i8), .{
                4e0, 4e1, imax(i8) - 7,  imax(i8) - 6,  imin(i8) + 8,  imin(i8) + 9,  -5e1, -5e0,
                5e0, 5e1, imax(i8) - 9,  imax(i8) - 8,  imin(i8) + 10, imin(i8) + 11, -6e1, -6e0,
                6e0, 6e1, imax(i8) - 11, imax(i8) - 10, imin(i8) + 12, imin(i8) + 13, -7e1, -7e0,
                7e0, 7e1, imax(i8) - 13, imax(i8) - 12, imin(i8) + 14, imin(i8) + 15, -8e1, -8e0,
            });
            try testArgs(@Vector(64, f128), @Vector(64, i8), .{
                8e0,           8e1,           imax(i8) - 15, imax(i8) - 14, imin(i8) + 16, imin(i8) + 17, -9e1,          -9e0,
                9e0,           9e1,           imax(i8) - 17, imax(i8) - 16, imin(i8) + 18, imin(i8) + 19, -11e1,         -11e0,
                11e0,          11e1,          imax(i8) - 19, imax(i8) - 18, imin(i8) + 20, imin(i8) + 21, -12e1,         -12e0,
                12e0,          12e1,          imax(i8) - 21, imax(i8) - 20, imin(i8) + 22, imin(i8) + 23, -13e0,         13e0,
                imax(i8) - 23, imax(i8) - 22, imin(i8) + 24, imin(i8) + 25, -14e0,         14e0,          imax(i8) - 25, imax(i8) - 24,
                imin(i8) + 26, imin(i8) + 27, -15e0,         15e0,          imax(i8) - 27, imax(i8) - 26, imin(i8) + 28, imin(i8) + 29,
                -16e0,         16e0,          imax(i8) - 29, imax(i8) - 28, imin(i8) + 30, imin(i8) + 31, -17e0,         17e0,
                imax(i8) - 31, imax(i8) - 30, imin(i8) + 32, imin(i8) + 33, -18e0,         18e0,          imax(i8) - 33, imax(i8) - 32,
            });

            try testArgs(@Vector(1, f128), @Vector(1, u8), .{
                0,
            });
            try testArgs(@Vector(2, f128), @Vector(2, u8), .{
                1e0, 1e1,
            });
            try testArgs(@Vector(4, f128), @Vector(4, u8), .{
                1e2, imax(u8) - 1, imax(u8), 2e0,
            });
            try testArgs(@Vector(8, f128), @Vector(8, u8), .{
                2e1, 2e2, imax(u8) - 3, imax(u8) - 2, 3e0, 3e1, imax(u8) - 5, imax(u8) - 4,
            });
            try testArgs(@Vector(16, f128), @Vector(16, u8), .{
                imax(u8) - 7,  imax(u8) - 6,  5e0, 5e1, imax(u8) - 9,  imax(u8) - 8,  6e0, 6e1,
                imax(u8) - 11, imax(u8) - 10, 7e0, 7e1, imax(u8) - 13, imax(u8) - 12, 8e0, 8e1,
            });
            try testArgs(@Vector(32, f128), @Vector(32, u8), .{
                imax(u8) - 15, imax(u8) - 14, 9e0,  9e1,  imax(u8) - 17, imax(u8) - 16, 11e0, 11e1,
                imax(u8) - 19, imax(u8) - 18, 12e0, 12e1, imax(u8) - 21, imax(u8) - 20, 13e0, 13e1,
                imax(u8) - 23, imax(u8) - 22, 14e0, 14e1, imax(u8) - 25, imax(u8) - 24, 15e0, 15e1,
                imax(u8) - 27, imax(u8) - 26, 16e0, 16e1, imax(u8) - 29, imax(u8) - 28, 17e0, 17e1,
            });
            try testArgs(@Vector(64, f128), @Vector(64, u8), .{
                imax(u8) - 31, imax(u8) - 30, 18e0,          18e1,          imax(u8) - 33, imax(u8) - 32, 19e0,          19e1,
                imax(u8) - 35, imax(u8) - 34, 21e0,          21e1,          imax(u8) - 37, imax(u8) - 36, 22e0,          22e1,
                imax(u8) - 39, imax(u8) - 38, 23e0,          23e1,          imax(u8) - 41, imax(u8) - 40, 24e0,          24e1,
                imax(u8) - 43, imax(u8) - 42, 25e0,          25e1,          imax(u8) - 45, imax(u8) - 44, 26e0,          imax(u8) - 47,
                imax(u8) - 46, 27e0,          imax(u8) - 49, imax(u8) - 48, 28e0,          imax(u8) - 51, imax(u8) - 50, 29e0,
                imax(u8) - 53, imax(u8) - 52, 31e0,          imax(u8) - 55, imax(u8) - 54, 32e0,          imax(u8) - 57, imax(u8) - 56,
                33e0,          imax(u8) - 59, imax(u8) - 58, 34e0,          imax(u8) - 61, imax(u8) - 60, 35e0,          imax(u8) - 63,
                imax(u8) - 62, 36e0,          imax(u8) - 65, imax(u8) - 64, 37e0,          imax(u8) - 67, imax(u8) - 66, 38e0,
            });

            try testArgs(@Vector(1, f128), @Vector(1, i16), .{
                imin(i16),
            });
            try testArgs(@Vector(2, f128), @Vector(2, i16), .{
                imin(i16) + 1, -1e4,
            });
            try testArgs(@Vector(4, f128), @Vector(4, i16), .{
                -1e3, -1e2, -1e1, -1e0,
            });
            try testArgs(@Vector(8, f128), @Vector(8, i16), .{
                0, 1e0, 1e1, 1e2, 1e3, 1e4, imax(i16) - 1, imax(i16),
            });
            try testArgs(@Vector(16, f128), @Vector(16, i16), .{
                imin(i16) + 2, imin(i16) + 3, -2e4, -2e3, -2e2,          -2e1,          -2e0,          2e0,
                2e1,           2e2,           2e3,  2e4,  imax(i16) - 3, imax(i16) - 2, imin(i16) + 4, imin(i16) + 5,
            });
            try testArgs(@Vector(32, f128), @Vector(32, i16), .{
                -3e4,          -3e3,          -3e2,          -3e1,          -3e0,          3e0,           3e1,           3e2,
                3e3,           3e4,           imax(i16) - 5, imax(i16) - 4, imin(i16) + 6, imin(i16) + 7, -4e3,          -4e2,
                -4e1,          -4e0,          4e0,           4e1,           4e2,           4e3,           imax(i16) - 7, imax(i16) - 6,
                imin(i16) + 8, imin(i16) + 9, -5e3,          -5e2,          -5e1,          -5e0,          5e0,           5e1,
            });
            try testArgs(@Vector(64, f128), @Vector(64, i16), .{
                5e2,            5e3,            imax(i16) - 9,  imax(i16) - 8,  imin(i16) + 10, imin(i16) + 11, -6e3,           -6e2,
                -6e1,           -6e0,           6e0,            6e1,            6e2,            6e3,            imax(i16) - 11, imax(i16) - 10,
                imin(i16) + 12, imin(i16) + 13, -7e3,           -7e2,           -7e1,           -7e0,           7e0,            7e1,
                7e2,            7e3,            imax(i16) - 13, imax(i16) - 12, imin(i16) + 14, imin(i16) + 15, -8e3,           -8e2,
                -8e1,           -8e0,           8e0,            8e1,            8e2,            8e3,            imax(i16) - 15, imax(i16) - 14,
                imin(i16) + 16, imin(i16) + 17, -9e3,           -9e2,           -9e1,           -9e0,           9e0,            9e1,
                9e2,            9e3,            imax(i16) - 17, imax(i16) - 16, imin(i16) + 18, imin(i16) + 19, -11e3,          -11e2,
                -11e1,          -11e0,          11e0,           11e1,           11e2,           11e3,           imax(i16) - 19, imax(i16) - 18,
            });

            try testArgs(@Vector(1, f128), @Vector(1, u16), .{
                0,
            });
            try testArgs(@Vector(2, f128), @Vector(2, u16), .{
                1e0, 1e1,
            });
            try testArgs(@Vector(4, f128), @Vector(4, u16), .{
                1e2, 1e3, 1e4, imax(u16) - 1,
            });
            try testArgs(@Vector(8, f128), @Vector(8, u16), .{
                imax(u16), 2e0, 2e1, 2e2, 2e3, 2e4, imax(u16) - 3, imax(u16) - 2,
            });
            try testArgs(@Vector(16, f128), @Vector(16, u16), .{
                3e0, 3e1, 3e2, 3e3, 3e4,           imax(u16) - 5, imax(u16) - 4, 4e0,
                4e1, 4e2, 4e3, 4e4, imax(u16) - 7, imax(u16) - 6, 5e0,           5e1,
            });
            try testArgs(@Vector(32, f128), @Vector(32, u16), .{
                5e2,            5e3,            5e4,            imax(u16) - 9,  imax(u16) - 8,  6e0,            6e1,            6e2,
                6e3,            6e4,            imax(u16) - 11, imax(u16) - 10, 7e0,            7e1,            7e2,            7e3,
                imax(u16) - 13, imax(u16) - 12, 8e0,            8e1,            8e2,            8e3,            imax(u16) - 15, imax(u16) - 14,
                9e0,            9e1,            9e2,            9e3,            imax(u16) - 17, imax(u16) - 16, 11e0,           11e1,
            });
            try testArgs(@Vector(64, f128), @Vector(64, u16), .{
                11e2,           11e3,           imax(u16) - 19, imax(u16) - 18, 12e0,           12e1,           12e2,           12e3,
                imax(u16) - 21, imax(u16) - 20, 13e0,           13e1,           13e2,           13e3,           imax(u16) - 23, imax(u16) - 22,
                14e0,           14e1,           14e2,           14e3,           imax(u16) - 25, imax(u16) - 24, 15e0,           15e1,
                15e2,           15e3,           imax(u16) - 27, imax(u16) - 26, 16e0,           16e1,           16e2,           16e3,
                imax(u16) - 29, imax(u16) - 28, 17e0,           17e1,           17e2,           17e3,           imax(u16) - 31, imax(u16) - 30,
                18e0,           18e1,           18e2,           18e3,           imax(u16) - 33, imax(u16) - 32, 19e0,           19e1,
                19e2,           19e3,           imax(u16) - 35, imax(u16) - 34, 21e0,           21e1,           21e2,           21e3,
                imax(u16) - 37, imax(u16) - 36, 22e0,           22e1,           22e2,           22e3,           imax(u16) - 39, imax(u16) - 38,
            });

            try testArgs(@Vector(1, f128), @Vector(1, i32), .{
                imin(i32),
            });
            try testArgs(@Vector(2, f128), @Vector(2, i32), .{
                imin(i32) + 1, -1e9,
            });
            try testArgs(@Vector(4, f128), @Vector(4, i32), .{
                -1e8, -1e7, -1e6, -1e5,
            });
            try testArgs(@Vector(8, f128), @Vector(8, i32), .{
                -1e4, -1e3, -1e2, -1e1, -1e0, 0, 1e0, 1e1,
            });
            try testArgs(@Vector(16, f128), @Vector(16, i32), .{
                1e2,           1e3,       1e4,           1e5,           1e6,  1e7,  1e8,  1e9,
                imax(i32) - 1, imax(i32), imin(i32) + 2, imin(i32) + 3, -2e9, -2e8, -2e7, -2e6,
            });
            try testArgs(@Vector(32, f128), @Vector(32, i32), .{
                -2e5,          -2e4,          -2e3,          -2e2,          -2e1, -2e0, 2e0,  2e1,
                2e2,           2e3,           2e4,           2e5,           2e6,  2e7,  2e8,  2e9,
                imax(i32) - 3, imax(i32) - 2, imin(i32) + 4, imin(i32) + 5, -3e8, -3e7, -3e6, -3e5,
                -3e4,          -3e3,          -3e2,          -3e1,          -3e0, 3e0,  3e1,  3e2,
            });
            try testArgs(@Vector(64, f128), @Vector(64, i32), .{
                3e3,           3e4,           3e5,           3e6,           3e7,            3e8,            imax(i32) - 5, imax(i32) - 4,
                imin(i32) + 6, imin(i32) + 7, -4e8,          -4e7,          -4e6,           -4e5,           -4e4,          -4e3,
                -4e2,          -4e1,          -4e0,          4e0,           4e1,            4e2,            4e3,           4e4,
                4e5,           4e6,           4e7,           4e8,           imax(i32) - 7,  imax(i32) - 6,  imin(i32) + 8, imin(i32) + 9,
                -5e8,          -5e7,          -5e6,          -5e5,          -5e4,           -5e3,           -5e2,          -5e1,
                -5e0,          5e0,           5e1,           5e2,           5e3,            5e4,            5e5,           5e6,
                5e7,           5e8,           imax(i32) - 9, imax(i32) - 8, imin(i32) + 10, imin(i32) + 11, -6e8,          -6e7,
                -6e6,          -6e5,          -6e4,          -6e3,          -6e2,           -6e1,           -6e0,          6e0,
            });

            try testArgs(@Vector(1, f128), @Vector(1, u32), .{
                0,
            });
            try testArgs(@Vector(2, f128), @Vector(2, u32), .{
                1e0, 1e1,
            });
            try testArgs(@Vector(4, f128), @Vector(4, u32), .{
                1e2, 1e3, 1e4, imax(u32) - 1,
            });
            try testArgs(@Vector(8, f128), @Vector(8, u32), .{
                imax(u32), 2e0, 2e1, 2e2, 2e3, 2e4, imax(u32) - 3, imax(u32) - 2,
            });
            try testArgs(@Vector(16, f128), @Vector(16, u32), .{
                3e0, 3e1, 3e2, 3e3, 3e4,           imax(u32) - 5, imax(u32) - 4, 4e0,
                4e1, 4e2, 4e3, 4e4, imax(u32) - 7, imax(u32) - 6, 5e0,           5e1,
            });
            try testArgs(@Vector(32, f128), @Vector(32, u32), .{
                5e2,            5e3,            5e4,            imax(u32) - 9,  imax(u32) - 8,  6e0,            6e1,            6e2,
                6e3,            6e4,            imax(u32) - 11, imax(u32) - 10, 7e0,            7e1,            7e2,            7e3,
                imax(u32) - 13, imax(u32) - 12, 8e0,            8e1,            8e2,            8e3,            imax(u32) - 15, imax(u32) - 14,
                9e0,            9e1,            9e2,            9e3,            imax(u32) - 17, imax(u32) - 16, 11e0,           11e1,
            });
            try testArgs(@Vector(64, f128), @Vector(64, u32), .{
                11e2,           11e3,           imax(u32) - 19, imax(u32) - 18, 12e0,           12e1,           12e2,           12e3,
                imax(u32) - 21, imax(u32) - 20, 13e0,           13e1,           13e2,           13e3,           imax(u32) - 23, imax(u32) - 22,
                14e0,           14e1,           14e2,           14e3,           imax(u32) - 25, imax(u32) - 24, 15e0,           15e1,
                15e2,           15e3,           imax(u32) - 27, imax(u32) - 26, 16e0,           16e1,           16e2,           16e3,
                imax(u32) - 29, imax(u32) - 28, 17e0,           17e1,           17e2,           17e3,           imax(u32) - 31, imax(u32) - 30,
                18e0,           18e1,           18e2,           18e3,           imax(u32) - 33, imax(u32) - 32, 19e0,           19e1,
                19e2,           19e3,           imax(u32) - 35, imax(u32) - 34, 21e0,           21e1,           21e2,           21e3,
                imax(u32) - 37, imax(u32) - 36, 22e0,           22e1,           22e2,           22e3,           imax(u32) - 39, imax(u32) - 38,
            });

            try testArgs(@Vector(1, f128), @Vector(1, i64), .{
                imin(i64),
            });
            try testArgs(@Vector(2, f128), @Vector(2, i64), .{
                imin(i64) + 1, -1e18,
            });
            try testArgs(@Vector(4, f128), @Vector(4, i64), .{
                -1e17, -1e16, -1e15, -1e14,
            });
            try testArgs(@Vector(8, f128), @Vector(8, i64), .{
                -1e13, -1e12, -1e11, -1e10, -1e9, -1e8, -1e7, -1e6,
            });
            try testArgs(@Vector(16, f128), @Vector(16, i64), .{
                -1e5, -1e4, -1e3, -1e2, -1e1, -1e0, 0,   1e0,
                1e1,  1e2,  1e3,  1e4,  1e5,  1e6,  1e7, 1e8,
            });
            try testArgs(@Vector(32, f128), @Vector(32, i64), .{
                1e9,   1e10,  1e11,          1e12,      1e13,          1e14,          1e15,  1e16,
                1e17,  1e18,  imax(i64) - 1, imax(i64), imin(i64) + 2, imin(i64) + 3, -2e18, -2e17,
                -2e16, -2e15, -2e14,         -2e13,     -2e12,         -2e11,         -2e10, -2e9,
                -2e8,  -2e7,  -2e6,          -2e5,      -2e4,          -2e3,          -2e2,  -2e1,
            });
            try testArgs(@Vector(64, f128), @Vector(64, i64), .{
                -2e0,  2e0,   2e1,   2e2,   2e3,           2e4,           2e5,           2e6,
                2e7,   2e8,   2e9,   2e10,  2e11,          2e12,          2e13,          2e14,
                2e15,  2e16,  2e17,  2e18,  imax(i64) - 3, imax(i64) - 2, imin(i64) + 4, imin(i64) + 5,
                -3e18, -3e17, -3e16, -3e15, -3e14,         -3e13,         -3e12,         -3e11,
                -3e10, -3e9,  -3e8,  -3e7,  -3e6,          -3e5,          -3e4,          -3e3,
                -3e2,  -3e1,  -3e0,  3e0,   3e1,           3e2,           3e3,           3e4,
                3e5,   3e6,   3e7,   3e8,   3e9,           3e10,          3e11,          3e12,
                3e13,  3e14,  3e15,  3e16,  3e17,          3e18,          imax(i64) - 5, imax(i64) - 4,
            });

            try testArgs(@Vector(1, f128), @Vector(1, u64), .{
                0,
            });
            try testArgs(@Vector(2, f128), @Vector(2, u64), .{
                1e0, 1e1,
            });
            try testArgs(@Vector(4, f128), @Vector(4, u64), .{
                1e2, 1e3, 1e4, 1e5,
            });
            try testArgs(@Vector(8, f128), @Vector(8, u64), .{
                1e6, 1e7, 1e8, 1e9, 1e10, 1e11, 1e12, 1e13,
            });
            try testArgs(@Vector(16, f128), @Vector(16, u64), .{
                1e14, 1e15, 1e16, 1e17, 1e18, 1e19, imax(u64) - 1, imax(u64),
                2e0,  2e1,  2e2,  2e3,  2e4,  2e5,  2e6,           2e7,
            });
            try testArgs(@Vector(32, f128), @Vector(32, u64), .{
                2e8,  2e9,  2e10, 2e11,          2e12,          2e13, 2e14, 2e15,
                2e16, 2e17, 2e18, imax(u64) - 3, imax(u64) - 2, 3e0,  3e1,  3e2,
                3e3,  3e4,  3e5,  3e6,           3e7,           3e8,  3e9,  3e10,
                3e11, 3e12, 3e13, 3e14,          3e15,          3e16, 3e17, 3e18,
            });
            try testArgs(@Vector(64, f128), @Vector(64, u64), .{
                imax(u64) - 5, imax(u64) - 4, 4e0,           4e1,           4e2,  4e3,           4e4,           4e5,
                4e6,           4e7,           4e8,           4e9,           4e10, 4e11,          4e12,          4e13,
                4e14,          4e15,          4e16,          4e17,          4e18, imax(u64) - 7, imax(u64) - 6, 5e0,
                5e1,           5e2,           5e3,           5e4,           5e5,  5e6,           5e7,           5e8,
                5e9,           5e10,          5e11,          5e12,          5e13, 5e14,          5e15,          5e16,
                5e17,          5e18,          imax(u64) - 9, imax(u64) - 8, 6e0,  6e1,           6e2,           6e3,
                6e4,           6e5,           6e6,           6e7,           6e8,  6e9,           6e10,          6e11,
                6e12,          6e13,          6e14,          6e15,          6e16, 6e17,          6e18,          imax(u64) - 11,
            });

            try testArgs(@Vector(1, f128), @Vector(1, i128), .{
                imin(i128),
            });
            try testArgs(@Vector(2, f128), @Vector(2, i128), .{
                imin(i128) + 1, -1e38,
            });
            try testArgs(@Vector(4, f128), @Vector(4, i128), .{
                -1e37, -1e36, -1e35, -1e34,
            });
            try testArgs(@Vector(8, f128), @Vector(8, i128), .{
                -1e33, -1e32, -1e31, -1e30, -1e29, -1e28, -1e27, -1e26,
            });
            try testArgs(@Vector(16, f128), @Vector(16, i128), .{
                -1e25, -1e24, -1e23, -1e22, -1e21, -1e20, -1e19, -1e18,
                -1e17, -1e16, -1e15, -1e14, -1e13, -1e12, -1e11, -1e10,
            });
            try testArgs(@Vector(32, f128), @Vector(32, i128), .{
                -1e9, -1e8, -1e7, -1e6, -1e5, -1e4, -1e3, -1e2,
                -1e1, -1e0, 0,    1e0,  1e1,  1e2,  1e3,  1e4,
                1e5,  1e6,  1e7,  1e8,  1e9,  1e10, 1e11, 1e12,
                1e13, 1e14, 1e15, 1e16, 1e17, 1e18, 1e19, 1e20,
            });
            try testArgs(@Vector(64, f128), @Vector(64, i128), .{
                1e21,  1e22,  1e23,           1e24,       1e25,           1e26,           1e27,  1e28,
                1e29,  1e30,  1e31,           1e32,       1e33,           1e34,           1e35,  1e36,
                1e37,  1e38,  imax(i128) - 1, imax(i128), imin(i128) + 2, imin(i128) + 3, -2e37, -2e36,
                -2e35, -2e34, -2e33,          -2e32,      -2e31,          -2e30,          -2e29, -2e28,
                -2e27, -2e26, -2e25,          -2e24,      -2e23,          -2e22,          -2e21, -2e20,
                -2e19, -2e18, -2e17,          -2e16,      -2e15,          -2e14,          -2e13, -2e12,
                -2e11, -2e10, -2e9,           -2e8,       -2e7,           -2e6,           -2e5,  -2e4,
                -2e3,  -2e2,  -2e1,           -2e0,       2e0,            2e1,            2e2,   2e3,
            });

            try testArgs(@Vector(1, f128), @Vector(1, u128), .{
                0,
            });
            try testArgs(@Vector(2, f128), @Vector(2, u128), .{
                1e0, 1e1,
            });
            try testArgs(@Vector(4, f128), @Vector(4, u128), .{
                1e2, 1e3, 1e4, 1e5,
            });
            try testArgs(@Vector(8, f128), @Vector(8, u128), .{
                1e6, 1e7, 1e8, 1e9, 1e10, 1e11, 1e12, 1e13,
            });
            try testArgs(@Vector(16, f128), @Vector(16, u128), .{
                1e14, 1e15, 1e16, 1e17, 1e18, 1e19, 1e20, 1e21,
                1e22, 1e23, 1e24, 1e25, 1e26, 1e27, 1e28, 1e29,
            });
            try testArgs(@Vector(32, f128), @Vector(32, u128), .{
                1e30, 1e31,           1e32,       1e33, 1e34, 1e35, 1e36, 1e37,
                1e38, imax(u128) - 1, imax(u128), 2e0,  2e1,  2e2,  2e3,  2e4,
                2e5,  2e6,            2e7,        2e8,  2e9,  2e10, 2e11, 2e12,
                2e13, 2e14,           2e15,       2e16, 2e17, 2e18, 2e19, 2e20,
            });
            try testArgs(@Vector(64, f128), @Vector(64, u128), .{
                2e21, 2e22, 2e23,           2e24,           2e25,           2e26, 2e27, 2e28,
                2e29, 2e30, 2e31,           2e32,           2e33,           2e34, 2e35, 2e36,
                2e37, 2e38, imax(u128) - 3, imax(u128) - 2, 3e0,            3e1,  3e2,  3e3,
                3e4,  3e5,  3e6,            3e7,            3e8,            3e9,  3e10, 3e11,
                3e12, 3e13, 3e14,           3e15,           3e16,           3e17, 3e18, 3e19,
                3e20, 3e21, 3e22,           3e23,           3e24,           3e25, 3e26, 3e27,
                3e28, 3e29, 3e30,           3e31,           3e32,           3e33, 3e34, 3e35,
                3e36, 3e37, 3e38,           imax(u128) - 5, imax(u128) - 4, 4e0,  4e1,  4e2,
            });

            try testArgs(@Vector(1, f128), @Vector(1, i256), .{
                imin(i256),
            });
            try testArgs(@Vector(2, f128), @Vector(2, i256), .{
                imin(i256) + 1, -1e76,
            });
            try testArgs(@Vector(4, f128), @Vector(4, i256), .{
                -1e75, -1e74, -1e73, -1e72,
            });
            try testArgs(@Vector(8, f128), @Vector(8, i256), .{
                -1e71, -1e70, -1e69, -1e68, -1e67, -1e66, -1e65, -1e64,
            });
            try testArgs(@Vector(16, f128), @Vector(16, i256), .{
                -1e63, -1e62, -1e61, -1e60, -1e59, -1e58, -1e57, -1e56,
                -1e55, -1e54, -1e53, -1e52, -1e51, -1e50, -1e49, -1e48,
            });
            try testArgs(@Vector(32, f128), @Vector(32, i256), .{
                -1e47, -1e46, -1e45, -1e44, -1e43, -1e42, -1e41, -1e40,
                -1e39, -1e38, -1e37, -1e36, -1e35, -1e34, -1e33, -1e32,
                -1e31, -1e30, -1e29, -1e28, -1e27, -1e26, -1e25, -1e24,
                -1e23, -1e22, -1e21, -1e20, -1e19, -1e18, -1e17, -1e16,
            });
            try testArgs(@Vector(64, f128), @Vector(64, i256), .{
                -1e15, -1e14, -1e13, -1e12, -1e11, -1e10, -1e9, -1e8,
                -1e7,  -1e6,  -1e5,  -1e4,  -1e3,  -1e2,  -1e1, -1e0,
                0,     1e0,   1e1,   1e2,   1e3,   1e4,   1e5,  1e6,
                1e7,   1e8,   1e9,   1e10,  1e11,  1e12,  1e13, 1e14,
                1e15,  1e16,  1e17,  1e18,  1e19,  1e20,  1e21, 1e22,
                1e23,  1e24,  1e25,  1e26,  1e27,  1e28,  1e29, 1e30,
                1e31,  1e32,  1e33,  1e34,  1e35,  1e36,  1e37, 1e38,
                1e39,  1e40,  1e41,  1e42,  1e43,  1e44,  1e45, 1e46,
            });

            try testArgs(@Vector(1, f128), @Vector(1, u256), .{
                0,
            });
            try testArgs(@Vector(2, f128), @Vector(2, u256), .{
                1e0, 1e1,
            });
            try testArgs(@Vector(4, f128), @Vector(4, u256), .{
                1e2, 1e3, 1e4, 1e5,
            });
            try testArgs(@Vector(8, f128), @Vector(8, u256), .{
                1e6, 1e7, 1e8, 1e9, 1e10, 1e11, 1e12, 1e13,
            });
            try testArgs(@Vector(16, f128), @Vector(16, u256), .{
                1e14, 1e15, 1e16, 1e17, 1e18, 1e19, 1e20, 1e21,
                1e22, 1e23, 1e24, 1e25, 1e26, 1e27, 1e28, 1e29,
            });
            try testArgs(@Vector(32, f128), @Vector(32, u256), .{
                1e30, 1e31, 1e32, 1e33, 1e34, 1e35, 1e36, 1e37,
                1e38, 1e39, 1e40, 1e41, 1e42, 1e43, 1e44, 1e45,
                1e46, 1e47, 1e48, 1e49, 1e50, 1e51, 1e52, 1e53,
                1e54, 1e55, 1e56, 1e57, 1e58, 1e59, 1e60, 1e61,
            });
            try testArgs(@Vector(64, f128), @Vector(64, u256), .{
                1e62,           1e63,       1e64, 1e65, 1e66, 1e67, 1e68, 1e69,
                1e70,           1e71,       1e72, 1e73, 1e74, 1e75, 1e76, 1e77,
                imax(u256) - 1, imax(u256), 2e0,  2e1,  2e2,  2e3,  2e4,  2e5,
                2e6,            2e7,        2e8,  2e9,  2e10, 2e11, 2e12, 2e13,
                2e14,           2e15,       2e16, 2e17, 2e18, 2e19, 2e20, 2e21,
                2e22,           2e23,       2e24, 2e25, 2e26, 2e27, 2e28, 2e29,
                2e30,           2e31,       2e32, 2e33, 2e34, 2e35, 2e36, 2e37,
                2e38,           2e39,       2e40, 2e41, 2e42, 2e43, 2e44, 2e45,
            });
        }
    };
}

inline fn intCast(comptime Result: type, comptime Type: type, rhs: Type, comptime ct_rhs: Type) Result {
    @setRuntimeSafety(false); // TODO
    const res_info = switch (@typeInfo(Result)) {
        .int => |info| info,
        .vector => |info| @typeInfo(info.child).int,
        else => @compileError(@typeName(Result)),
    };
    const rhs_info = @typeInfo(Scalar(Type)).int;
    const min_bits = @min(res_info.bits, rhs_info.bits);
    return @intCast(switch (@as(union(enum) {
        shift: Log2Int(Scalar(Type)),
        mask: Log2IntCeil(Scalar(Type)),
    }, switch (res_info.signedness) {
        .signed => switch (rhs_info.signedness) {
            .signed => .{ .shift = rhs_info.bits - min_bits },
            .unsigned => .{ .mask = min_bits - @intFromBool(res_info.bits <= rhs_info.bits) },
        },
        .unsigned => switch (rhs_info.signedness) {
            .signed => .{ .mask = min_bits - @intFromBool(res_info.bits >= rhs_info.bits) },
            .unsigned => .{ .mask = min_bits },
        },
    })) {
        // TODO: if (bits == 0) rhs else rhs >> bits,
        .shift => |bits| if (bits == 0) rhs else switch (@typeInfo(Type)) {
            .int => if (ct_rhs < 0)
                rhs | imin(Type) >> bits
            else
                rhs & imax(Type) >> bits,
            .vector => rhs | @select(
                Scalar(Type),
                ct_rhs < splat(Type, 0),
                splat(Type, imin(Scalar(Type)) >> bits),
                splat(Type, 0),
            ) & ~@select(
                Scalar(Type),
                ct_rhs >= splat(Type, 0),
                splat(Type, imin(Scalar(Type)) >> bits),
                splat(Type, 0),
            ),
            else => comptime unreachable,
        },
        .mask => |bits| if (bits == rhs_info.bits) rhs else rhs & splat(Type, (1 << bits) - 1),
    });
}
test intCast {
    const test_int_cast = cast(intCast, .{});
    try test_int_cast.testInts();
    try test_int_cast.testIntVectors();
}

inline fn truncate(comptime Result: type, comptime Type: type, rhs: Type, comptime _: Type) Result {
    return if (@typeInfo(Scalar(Result)).int.bits <= @typeInfo(Scalar(Type)).int.bits) @truncate(rhs) else rhs;
}
test truncate {
    const test_truncate = cast(truncate, .{});
    try test_truncate.testSameSignednessInts();
    try test_truncate.testSameSignednessIntVectors();
}

inline fn floatCast(comptime Result: type, comptime Type: type, rhs: Type, comptime _: Type) Result {
    return @floatCast(rhs);
}
test floatCast {
    const test_float_cast = cast(floatCast, .{ .compare = .strict });
    try test_float_cast.testFloats();
    try test_float_cast.testFloatVectors();
}

inline fn intFromFloatUnsafe(comptime Result: type, comptime Type: type, rhs: Type, comptime _: Type) Result {
    @setRuntimeSafety(false);
    return @intFromFloat(rhs);
}
test intFromFloatUnsafe {
    const test_int_from_float_unsafe = cast(intFromFloatUnsafe, .{ .compare = .strict });
    try test_int_from_float_unsafe.testIntsFromFloats();
    try test_int_from_float_unsafe.testIntVectorsFromFloatVectors();
}

inline fn intFromFloatSafe(comptime Result: type, comptime Type: type, rhs: Type, comptime _: Type) Result {
    @setRuntimeSafety(true);
    return @intFromFloat(rhs);
}
test intFromFloatSafe {
    const test_int_from_float_safe = cast(intFromFloatSafe, .{ .compare = .strict });
    try test_int_from_float_safe.testIntsFromFloats();
    try test_int_from_float_safe.testIntVectorsFromFloatVectors();
}

inline fn floatFromInt(comptime Result: type, comptime Type: type, rhs: Type, comptime _: Type) Result {
    return @floatFromInt(rhs);
}
test floatFromInt {
    const test_float_from_int = cast(floatFromInt, .{ .compare = .strict });
    try test_float_from_int.testFloatsFromInts();
    try test_float_from_int.testFloatVectorsFromIntVectors();
}
