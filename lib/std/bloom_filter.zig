// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const builtin = @import("builtin");
const std = @import("std.zig");
const math = std.math;
const debug = std.debug;
const assert = std.debug.assert;
const testing = std.testing;

/// There is a trade off of how quickly to fill a bloom filter;
/// the number of items is:
///     n_items / K * ln(2)
/// the rate of false positives is:
///     (1-e^(-K*N/n_items))^K
/// where N is the number of items
pub fn BloomFilter(
    /// Size of bloom filter in cells, must be a power of two.
    comptime n_items: usize,
    /// Number of cells to set per item
    comptime K: usize,
    /// Cell type, should be:
    ///  - `bool` for a standard bloom filter
    ///  - an unsigned integer type for a counting bloom filter
    comptime Cell: type,
    /// endianess of the Cell
    comptime endian: builtin.Endian,
    /// Hash function to use
    comptime hash: fn (out: []u8, Ki: usize, in: []const u8) void,
) type {
    assert(n_items > 0);
    assert(math.isPowerOfTwo(n_items));
    assert(K > 0);
    const cellEmpty = if (Cell == bool) false else @as(Cell, 0);
    const cellMax = if (Cell == bool) true else math.maxInt(Cell);
    const n_bytes = (n_items * comptime std.meta.bitCount(Cell)) / 8;
    assert(n_bytes > 0);
    const Io = std.packed_int_array.PackedIntIo(Cell, endian);

    return struct {
        const Self = @This();
        pub const items = n_items;
        pub const Index = math.IntFittingRange(0, n_items - 1);

        data: [n_bytes]u8 = [_]u8{0} ** n_bytes,

        pub fn reset(self: *Self) void {
            std.mem.set(u8, self.data[0..], 0);
        }

        pub fn @"union"(x: Self, y: Self) Self {
            var r = Self{ .data = undefined };
            inline for (x.data) |v, i| {
                r.data[i] = v | y.data[i];
            }
            return r;
        }

        pub fn intersection(x: Self, y: Self) Self {
            var r = Self{ .data = undefined };
            inline for (x.data) |v, i| {
                r.data[i] = v & y.data[i];
            }
            return r;
        }

        pub fn getCell(self: Self, cell: Index) Cell {
            return Io.get(&self.data, cell, 0);
        }

        pub fn incrementCell(self: *Self, cell: Index) void {
            if (Cell == bool or Cell == u1) {
                // skip the 'get' operation
                Io.set(&self.data, cell, 0, cellMax);
            } else {
                const old = Io.get(&self.data, cell, 0);
                if (old != cellMax) {
                    Io.set(&self.data, cell, 0, old + 1);
                }
            }
        }

        pub fn clearCell(self: *Self, cell: Index) void {
            Io.set(&self.data, cell, 0, cellEmpty);
        }

        pub fn add(self: *Self, item: []const u8) void {
            comptime var i = 0;
            inline while (i < K) : (i += 1) {
                var K_th_bit: packed struct {
                    x: Index,
                } = undefined;
                hash(std.mem.asBytes(&K_th_bit), i, item);
                incrementCell(self, K_th_bit.x);
            }
        }

        pub fn contains(self: Self, item: []const u8) bool {
            comptime var i = 0;
            inline while (i < K) : (i += 1) {
                var K_th_bit: packed struct {
                    x: Index,
                } = undefined;
                hash(std.mem.asBytes(&K_th_bit), i, item);
                if (getCell(self, K_th_bit.x) == cellEmpty)
                    return false;
            }
            return true;
        }

        pub fn resize(self: Self, comptime newsize: usize) BloomFilter(newsize, K, Cell, endian, hash) {
            var r: BloomFilter(newsize, K, Cell, endian, hash) = undefined;
            if (newsize < n_items) {
                std.mem.copy(u8, r.data[0..], self.data[0..r.data.len]);
                var copied: usize = r.data.len;
                while (copied < self.data.len) : (copied += r.data.len) {
                    for (self.data[copied .. copied + r.data.len]) |s, i| {
                        r.data[i] |= s;
                    }
                }
            } else if (newsize == n_items) {
                r = self;
            } else if (newsize > n_items) {
                var copied: usize = 0;
                while (copied < r.data.len) : (copied += self.data.len) {
                    std.mem.copy(u8, r.data[copied .. copied + self.data.len], &self.data);
                }
            }
            return r;
        }

        /// Returns number of non-zero cells
        pub fn popCount(self: Self) Index {
            var n: Index = 0;
            if (Cell == bool or Cell == u1) {
                for (self.data) |b, i| {
                    n += @popCount(u8, b);
                }
            } else {
                var i: usize = 0;
                while (i < n_items) : (i += 1) {
                    const cell = self.getCell(@intCast(Index, i));
                    n += if (if (Cell == bool) cell else cell > 0) @as(Index, 1) else @as(Index, 0);
                }
            }
            return n;
        }

        pub fn estimateItems(self: Self) f64 {
            const m = comptime @intToFloat(f64, n_items);
            const k = comptime @intToFloat(f64, K);
            const X = @intToFloat(f64, self.popCount());
            return (comptime (-m / k)) * math.log1p(X * comptime (-1 / m));
        }
    };
}

fn hashFunc(out: []u8, Ki: usize, in: []const u8) void {
    var st = std.crypto.hash.Gimli.init(.{});
    st.update(std.mem.asBytes(&Ki));
    st.update(in);
    st.final(out);
}

test "std.BloomFilter" {
    // https://github.com/ziglang/zig/issues/5127
    if (std.Target.current.cpu.arch == .mips) return error.SkipZigTest;

    inline for ([_]type{ bool, u1, u2, u3, u4 }) |Cell| {
        const emptyCell = if (Cell == bool) false else @as(Cell, 0);
        const BF = BloomFilter(128 * 8, 8, Cell, builtin.endian, hashFunc);
        var bf = BF{};
        var i: usize = undefined;
        // confirm that it is initialised to the empty filter
        i = 0;
        while (i < BF.items) : (i += 1) {
            testing.expectEqual(emptyCell, bf.getCell(@intCast(BF.Index, i)));
        }
        testing.expectEqual(@as(BF.Index, 0), bf.popCount());
        testing.expectEqual(@as(f64, 0), bf.estimateItems());
        // fill in a few items
        bf.incrementCell(42);
        bf.incrementCell(255);
        bf.incrementCell(256);
        bf.incrementCell(257);
        // check that they were set
        testing.expectEqual(true, bf.getCell(42) != emptyCell);
        testing.expectEqual(true, bf.getCell(255) != emptyCell);
        testing.expectEqual(true, bf.getCell(256) != emptyCell);
        testing.expectEqual(true, bf.getCell(257) != emptyCell);
        // clear just one of them; make sure the rest are still set
        bf.clearCell(256);
        testing.expectEqual(true, bf.getCell(42) != emptyCell);
        testing.expectEqual(true, bf.getCell(255) != emptyCell);
        testing.expectEqual(false, bf.getCell(256) != emptyCell);
        testing.expectEqual(true, bf.getCell(257) != emptyCell);
        // reset any of the ones we've set and confirm we're back to the empty filter
        bf.clearCell(42);
        bf.clearCell(255);
        bf.clearCell(257);
        i = 0;
        while (i < BF.items) : (i += 1) {
            testing.expectEqual(emptyCell, bf.getCell(@intCast(BF.Index, i)));
        }
        testing.expectEqual(@as(BF.Index, 0), bf.popCount());
        testing.expectEqual(@as(f64, 0), bf.estimateItems());

        // Lets add a string
        bf.add("foo");
        testing.expectEqual(true, bf.contains("foo"));
        {
            // try adding same string again. make sure popcount is the same
            const old_popcount = bf.popCount();
            testing.expect(old_popcount > 0);
            bf.add("foo");
            testing.expectEqual(true, bf.contains("foo"));
            testing.expectEqual(old_popcount, bf.popCount());
        }

        // Get back to empty filter via .reset
        bf.reset();
        // Double check that .reset worked
        i = 0;
        while (i < BF.items) : (i += 1) {
            testing.expectEqual(emptyCell, bf.getCell(@intCast(BF.Index, i)));
        }
        testing.expectEqual(@as(BF.Index, 0), bf.popCount());
        testing.expectEqual(@as(f64, 0), bf.estimateItems());

        comptime var teststrings = [_][]const u8{
            "foo",
            "bar",
            "a longer string",
            "some more",
            "the quick brown fox",
            "unique string",
        };
        inline for (teststrings) |str| {
            bf.add(str);
        }
        inline for (teststrings) |str| {
            testing.expectEqual(true, bf.contains(str));
        }

        { // estimate should be close for low packing
            const est = bf.estimateItems();
            testing.expect(est > @intToFloat(f64, teststrings.len) - 1);
            testing.expect(est < @intToFloat(f64, teststrings.len) + 1);
        }

        const larger_bf = bf.resize(4096);
        inline for (teststrings) |str| {
            testing.expectEqual(true, larger_bf.contains(str));
        }
        testing.expectEqual(@as(u12, bf.popCount()) * (4096 / 1024), larger_bf.popCount());

        const smaller_bf = bf.resize(64);
        inline for (teststrings) |str| {
            testing.expectEqual(true, smaller_bf.contains(str));
        }
        testing.expect(bf.popCount() <= @as(u10, smaller_bf.popCount()) * (1024 / 64));
    }
}
