// There are two implementations of CRC32 implemented with the following key characteristics:
//
// - Crc32WithPoly uses 8Kb of tables but is ~10x faster than the small method.
//
// - Crc32SmallWithPoly uses only 64 bytes of memory but is slower. Be aware that this is
//   still moderately fast just slow relative to the slicing approach.

const std = @import("../std.zig");
const builtin = @import("builtin");
const debug = std.debug;
const testing = std.testing;

pub usingnamespace @import("crc/catalog.zig");

pub fn Algorithm(comptime W: type) type {
    return struct {
        polynomial: W,
        initial: W,
        reflect_input: bool,
        reflect_output: bool,
        xor_output: W,
    };
}

pub fn Crc(comptime W: type, comptime algorithm: Algorithm(W)) type {
    return struct {
        const Self = @This();
        const I = if (@bitSizeOf(W) < 8) u8 else W;
        const lookup_table = blk: {
            @setEvalBranchQuota(2500);

            const poly = if (algorithm.reflect_input)
                @bitReverse(@as(I, algorithm.polynomial)) >> (@bitSizeOf(I) - @bitSizeOf(W))
            else
                @as(I, algorithm.polynomial) << (@bitSizeOf(I) - @bitSizeOf(W));

            var table: [256]I = undefined;
            for (&table, 0..) |*e, i| {
                var crc: I = i;
                if (algorithm.reflect_input) {
                    var j: usize = 0;
                    while (j < 8) : (j += 1) {
                        crc = (crc >> 1) ^ ((crc & 1) * poly);
                    }
                } else {
                    crc <<= @bitSizeOf(I) - 8;
                    var j: usize = 0;
                    while (j < 8) : (j += 1) {
                        crc = (crc << 1) ^ (((crc >> (@bitSizeOf(I) - 1)) & 1) * poly);
                    }
                }
                e.* = crc;
            }
            break :blk table;
        };

        crc: I,

        pub fn init() Self {
            const initial = if (algorithm.reflect_input)
                @bitReverse(@as(I, algorithm.initial)) >> (@bitSizeOf(I) - @bitSizeOf(W))
            else
                @as(I, algorithm.initial) << (@bitSizeOf(I) - @bitSizeOf(W));
            return Self{ .crc = initial };
        }

        inline fn tableEntry(index: I) I {
            return lookup_table[@as(u8, @intCast(index & 0xFF))];
        }

        pub fn update(self: *Self, bytes: []const u8) void {
            var i: usize = 0;
            if (@bitSizeOf(I) <= 8) {
                while (i < bytes.len) : (i += 1) {
                    self.crc = tableEntry(self.crc ^ bytes[i]);
                }
            } else if (algorithm.reflect_input) {
                while (i < bytes.len) : (i += 1) {
                    const table_index = self.crc ^ bytes[i];
                    self.crc = tableEntry(table_index) ^ (self.crc >> 8);
                }
            } else {
                while (i < bytes.len) : (i += 1) {
                    const table_index = (self.crc >> (@bitSizeOf(I) - 8)) ^ bytes[i];
                    self.crc = tableEntry(table_index) ^ (self.crc << 8);
                }
            }
        }

        pub fn final(self: Self) W {
            var c = self.crc;
            if (algorithm.reflect_input != algorithm.reflect_output) {
                c = @bitReverse(c);
            }
            if (!algorithm.reflect_output) {
                c >>= @bitSizeOf(I) - @bitSizeOf(W);
            }
            return @as(W, @intCast(c ^ algorithm.xor_output));
        }

        pub fn hash(bytes: []const u8) W {
            var c = Self.init();
            c.update(bytes);
            return c.final();
        }
    };
}

pub const Polynomial = enum(u32) {
    IEEE = 0xedb88320,
    Castagnoli = 0x82f63b78,
    Koopman = 0xeb31d82e,
    _,
};

// IEEE is by far the most common CRC and so is aliased by default.
pub const Crc32 = Crc32WithPoly(.IEEE);

// slicing-by-8 crc32 implementation.
pub fn Crc32WithPoly(comptime poly: Polynomial) type {
    return struct {
        const Self = @This();
        const lookup_tables = block: {
            @setEvalBranchQuota(20000);
            var tables: [8][256]u32 = undefined;

            for (&tables[0], 0..) |*e, i| {
                var crc = @as(u32, @intCast(i));
                var j: usize = 0;
                while (j < 8) : (j += 1) {
                    if (crc & 1 == 1) {
                        crc = (crc >> 1) ^ @intFromEnum(poly);
                    } else {
                        crc = (crc >> 1);
                    }
                }
                e.* = crc;
            }

            var i: usize = 0;
            while (i < 256) : (i += 1) {
                var crc = tables[0][i];
                var j: usize = 1;
                while (j < 8) : (j += 1) {
                    const index: u8 = @truncate(crc);
                    crc = tables[0][index] ^ (crc >> 8);
                    tables[j][i] = crc;
                }
            }

            break :block tables;
        };

        crc: u32,

        pub fn init() Self {
            return Self{ .crc = 0xffffffff };
        }

        pub fn update(self: *Self, input: []const u8) void {
            var i: usize = 0;
            while (i + 8 <= input.len) : (i += 8) {
                const p = input[i..][0..8];

                // Unrolling this way gives ~50Mb/s increase
                self.crc ^= std.mem.readIntLittle(u32, p[0..4]);

                self.crc =
                    lookup_tables[0][p[7]] ^
                    lookup_tables[1][p[6]] ^
                    lookup_tables[2][p[5]] ^
                    lookup_tables[3][p[4]] ^
                    lookup_tables[4][@as(u8, @truncate(self.crc >> 24))] ^
                    lookup_tables[5][@as(u8, @truncate(self.crc >> 16))] ^
                    lookup_tables[6][@as(u8, @truncate(self.crc >> 8))] ^
                    lookup_tables[7][@as(u8, @truncate(self.crc >> 0))];
            }

            while (i < input.len) : (i += 1) {
                const index = @as(u8, @truncate(self.crc)) ^ input[i];
                self.crc = (self.crc >> 8) ^ lookup_tables[0][index];
            }
        }

        pub fn final(self: *Self) u32 {
            return ~self.crc;
        }

        pub fn hash(input: []const u8) u32 {
            var c = Self.init();
            c.update(input);
            return c.final();
        }
    };
}

test "crc32 ieee" {
    const Crc32Ieee = Crc32WithPoly(.IEEE);

    try testing.expect(Crc32Ieee.hash("") == 0x00000000);
    try testing.expect(Crc32Ieee.hash("a") == 0xe8b7be43);
    try testing.expect(Crc32Ieee.hash("abc") == 0x352441c2);
}

test "crc32 castagnoli" {
    const Crc32Castagnoli = Crc32WithPoly(.Castagnoli);

    try testing.expect(Crc32Castagnoli.hash("") == 0x00000000);
    try testing.expect(Crc32Castagnoli.hash("a") == 0xc1d04330);
    try testing.expect(Crc32Castagnoli.hash("abc") == 0x364b3fb7);
}

// half-byte lookup table implementation.
pub fn Crc32SmallWithPoly(comptime poly: Polynomial) type {
    return struct {
        const Self = @This();
        const lookup_table = block: {
            var table: [16]u32 = undefined;

            for (&table, 0..) |*e, i| {
                var crc = @as(u32, @intCast(i * 16));
                var j: usize = 0;
                while (j < 8) : (j += 1) {
                    if (crc & 1 == 1) {
                        crc = (crc >> 1) ^ @intFromEnum(poly);
                    } else {
                        crc = (crc >> 1);
                    }
                }
                e.* = crc;
            }

            break :block table;
        };

        crc: u32,

        pub fn init() Self {
            return Self{ .crc = 0xffffffff };
        }

        pub fn update(self: *Self, input: []const u8) void {
            for (input) |b| {
                self.crc = lookup_table[@as(u4, @truncate(self.crc ^ (b >> 0)))] ^ (self.crc >> 4);
                self.crc = lookup_table[@as(u4, @truncate(self.crc ^ (b >> 4)))] ^ (self.crc >> 4);
            }
        }

        pub fn final(self: *Self) u32 {
            return ~self.crc;
        }

        pub fn hash(input: []const u8) u32 {
            var c = Self.init();
            c.update(input);
            return c.final();
        }
    };
}

test "small crc32 ieee" {
    const Crc32Ieee = Crc32SmallWithPoly(.IEEE);

    try testing.expect(Crc32Ieee.hash("") == 0x00000000);
    try testing.expect(Crc32Ieee.hash("a") == 0xe8b7be43);
    try testing.expect(Crc32Ieee.hash("abc") == 0x352441c2);
}

test "small crc32 castagnoli" {
    const Crc32Castagnoli = Crc32SmallWithPoly(.Castagnoli);

    try testing.expect(Crc32Castagnoli.hash("") == 0x00000000);
    try testing.expect(Crc32Castagnoli.hash("a") == 0xc1d04330);
    try testing.expect(Crc32Castagnoli.hash("abc") == 0x364b3fb7);
}
