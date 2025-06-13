const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const builtin = @import("builtin");

fn ShardedTable(comptime Key: type, comptime mask_bit_count: comptime_int, comptime V: type) type {
    const key_bits = @typeInfo(Key).int.bits;
    std.debug.assert(Key == std.meta.Int(.unsigned, key_bits));
    std.debug.assert(key_bits >= mask_bit_count);
    const shard_key_bits = mask_bit_count;
    const ShardKey = std.meta.Int(.unsigned, mask_bit_count);
    const shift_amount = key_bits - shard_key_bits;
    return struct {
        const Self = @This();
        shards: [1 << shard_key_bits]?*Node,

        pub fn create() Self {
            return Self{ .shards = [_]?*Node{null} ** (1 << shard_key_bits) };
        }

        fn getShardKey(key: Key) ShardKey {
            // https://github.com/ziglang/zig/issues/1544
            // this special case is needed because you can't u32 >> 32.
            if (ShardKey == u0) return 0;

            // this can be u1 >> u0
            const shard_key = key >> shift_amount;

            // TODO: https://github.com/ziglang/zig/issues/1544
            // This cast could be implicit if we teach the compiler that
            // u32 >> 30 -> u2
            return @as(ShardKey, @intCast(shard_key));
        }

        pub fn put(self: *Self, node: *Node) void {
            const shard_key = Self.getShardKey(node.key);
            node.next = self.shards[shard_key];
            self.shards[shard_key] = node;
        }

        pub fn get(self: *Self, key: Key) ?*Node {
            const shard_key = Self.getShardKey(key);
            var maybe_node = self.shards[shard_key];
            while (maybe_node) |node| : (maybe_node = node.next) {
                if (node.key == key) return node;
            }
            return null;
        }

        pub const Node = struct {
            key: Key,
            value: V,
            next: ?*Node,

            pub fn init(self: *Node, key: Key, value: V) void {
                self.key = key;
                self.value = value;
                self.next = null;
            }
        };
    };
}

test "sharded table" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv) return error.SkipZigTest;

    // realistic 16-way sharding
    try testShardedTable(u32, 4, 8);

    try testShardedTable(u5, 0, 32); // ShardKey == u0
    try testShardedTable(u5, 2, 32);
    try testShardedTable(u5, 5, 32);

    try testShardedTable(u1, 0, 2);
    try testShardedTable(u1, 1, 2); // this does u1 >> u0

    try testShardedTable(u0, 0, 1);
}

fn testShardedTable(comptime Key: type, comptime mask_bit_count: comptime_int, comptime node_count: comptime_int) !void {
    const Table = ShardedTable(Key, mask_bit_count, void);

    var table = Table.create();
    var node_buffer: [node_count]Table.Node = undefined;
    for (&node_buffer, 0..) |*node, i| {
        const key = @as(Key, @intCast(i));
        try expect(table.get(key) == null);
        node.init(key, {});
        table.put(node);
    }

    for (&node_buffer, 0..) |*node, i| {
        try expect(table.get(@as(Key, @intCast(i))) == node);
    }
}

// #2225
test "comptime shr of BigInt" {
    comptime {
        const n0 = 0xdeadbeef0000000000000000;
        try expect(n0 >> 64 == 0xdeadbeef);
        const n1 = 17908056155735594659;
        try expect(n1 >> 64 == 0);
    }
}

test "comptime shift safety check" {
    _ = @as(usize, 42) << @sizeOf(usize);
}

test "Saturating Shift Left where lhs is of a computed type" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const S = struct {
        fn getIntShiftType(comptime T: type) type {
            var unsigned_shift_type = @typeInfo(std.math.Log2Int(T)).int;
            unsigned_shift_type.signedness = .signed;

            return @Type(.{
                .int = unsigned_shift_type,
            });
        }

        pub fn FixedPoint(comptime ValueType: type) type {
            return struct {
                value: ValueType,
                exponent: ShiftType,

                const ShiftType: type = getIntShiftType(ValueType);

                pub fn shiftExponent(self: @This(), shift: ShiftType) @This() {
                    const shiftAbs = @abs(shift);
                    return .{ .value = if (shift >= 0) self.value >> shiftAbs else self.value <<| shiftAbs, .exponent = self.exponent + shift };
                }
            };
        }
    };

    const FP = S.FixedPoint(i32);

    const value = (FP{
        .value = 1,
        .exponent = 1,
    }).shiftExponent(-1);

    try expect(value.value == 2);
    try expect(value.exponent == 0);
}

comptime {
    var image: [1]u8 = undefined;
    _ = &image;
    _ = @shlExact(@as(u16, image[0]), 8);
}

test "Saturating Shift Left" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_spirv) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest;

    const S = struct {
        fn shlSat(x: anytype, y: std.math.Log2Int(@TypeOf(x))) @TypeOf(x) {
            // workaround https://github.com/ziglang/zig/issues/23033
            @setRuntimeSafety(false);
            return x <<| y;
        }

        fn testType(comptime T: type) !void {
            comptime var rhs: std.math.Log2Int(T) = 0;
            inline while (true) : (rhs += 1) {
                comptime var lhs: T = std.math.minInt(T);
                inline while (true) : (lhs += 1) {
                    try expectEqual(lhs <<| rhs, shlSat(lhs, rhs));
                    if (lhs == std.math.maxInt(T)) break;
                }
                if (rhs == @bitSizeOf(T) - 1) break;
            }
        }
    };

    try S.testType(u2);
    try S.testType(i2);
    try S.testType(u3);
    try S.testType(i3);
    try S.testType(u4);
    try S.testType(i4);

    try expectEqual(0xfffffffffffffff0fffffffffffffff0, S.shlSat(@as(u128, 0x0fffffffffffffff0fffffffffffffff), 4));
    try expectEqual(0xffffffffffffffffffffffffffffffff, S.shlSat(@as(u128, 0x0fffffffffffffff0fffffffffffffff), 5));
    try expectEqual(-0x80000000000000000000000000000000, S.shlSat(@as(i128, -0x0fffffffffffffff0fffffffffffffff), 5));

    try expectEqual(51146728248377216718956089012931236753385031969422887335676427626502090568823039920051095192592252455482604439493126109519019633529459266458258243583, S.shlSat(@as(i495, 0x2fe6bc5448c55ce18252e2c9d44777505dfe63ff249a8027a6626c7d8dd9893fd5731e51474727be556f757facb586a4e04bbc0148c6c7ad692302f46fbd), 0x31));
    try expectEqual(-57896044618658097711785492504343953926634992332820282019728792003956564819968, S.shlSat(@as(i256, -0x53d4148cee74ea43477a65b3daa7b8fdadcbf4508e793f4af113b8d8da5a7eb6), 0x91));
    try expectEqual(170141183460469231731687303715884105727, S.shlSat(@as(i128, 0x2fe6bc5448c55ce18252e2c9d4477750), 0x31));
    try expectEqual(0, S.shlSat(@as(i128, 0), 127));
}
