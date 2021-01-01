// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("std.zig");
const assert = std.debug.assert;
const testing = std.testing;

pub fn EnumSet(comptime Enum: type) type {
    const EnumInfo = @typeInfo(Enum).Enum;

    comptime var min: comptime_int = undefined;
    comptime var max: comptime_int = undefined;
    comptime var flag_count: comptime_int = undefined;
    comptime var is_sparse: bool = undefined;
    if (EnumInfo.is_exhaustive) {
        min = std.math.maxInt(EnumInfo.tag_type);
        max = std.math.minInt(EnumInfo.tag_type);
        flag_count = 0;
        for (EnumInfo.fields) |enum_field| {
            min = std.math.min(min, enum_field.value);
            max = std.math.max(max, enum_field.value);
            flag_count += 1;
        }
        is_sparse = flag_count != max - min + 1;
    } else {
        min = std.math.minInt(EnumInfo.tag_type);
        max = std.math.maxInt(EnumInfo.tag_type);
        flag_count = max - min + 1;
        is_sparse = false;
    }

    // TODO: when sparse, set up a mapping so that flags is only `flag_count` in size

    return struct {
        flags: std.PackedIntArray(u1, max - min + 1),

        const IndexInt = std.math.IntFittingRange(0, max - min + 1);
        fn enumToFlagIndex(value: Enum) IndexInt {
            const unsigned_tag_type = std.meta.Int(.unsigned, @typeInfo(EnumInfo.tag_type).Int.bits);
            return @intCast(IndexInt, @bitCast(unsigned_tag_type, @enumToInt(value) -% min));
        }

        const Self = @This();

        pub const Empty = Self{
            .flags = std.PackedIntArray(u1, max - min + 1).initAllTo(@boolToInt(false)),
        };

        pub const Full = Self{
            .flags = std.PackedIntArray(u1, max - min + 1).initAllTo(@boolToInt(true)),
        };

        pub fn init(members: []const Enum) Self {
            var self = Empty;
            for (members) |e| {
                assert(!self.exists(e)); // duplicate
                self.put(e);
            }
            return self;
        }

        pub fn put(self: *Self, value: Enum) void {
            self.flags.set(enumToFlagIndex(value), @boolToInt(true));
        }

        pub fn delete(self: *Self, value: Enum) void {
            self.flags.set(enumToFlagIndex(value), @boolToInt(false));
        }

        pub fn exists(self: Self, value: Enum) bool {
            return self.flags.get(enumToFlagIndex(value)) != 0;
        }

        pub const Iterator = struct {
            enum_set: *const Self,

            index: std.math.IntFittingRange(min, max + 1) = min,

            pub fn next(it: *Iterator) ?Enum {
                assert(it.index <= max + 1);
                if (is_sparse) {
                    @compileError("TODO: iterating over sparse enums");
                }
                while (it.index <= max) {
                    const field = @intToEnum(Enum, @intCast(EnumInfo.tag_type, it.index));
                    it.index += 1;
                    if (it.enum_set.exists(field)) return field;
                }
                return null;
            }
        };

        pub fn iterator(self: *const Self) Iterator {
            return Iterator{ .enum_set = self };
        }

        const CountInt = std.math.IntFittingRange(0, flag_count - 1);

        /// Returns number of values present in the set
        pub fn count(self: Self) CountInt {
            // TODO: this should somehow result in a popcount instruction
            var n: CountInt = 0;
            var it = self.iterator();
            while (it.next()) |_| n += 1;
            return n;
        }
    };
}

test "EnumSet" {
    inline for ([_]type{
        enum { a = 0, b = 1, c = 2 },

        // min > 0
        enum(u8) { a = 10, b = 11, c = 12 },

        // min < 0
        enum(i8) { a = -12, b = -11, c = -10 },

        // non-exhaustive
        enum(u4) { a = 0, b = 1, c = 2, _ },

        extern enum(u8) { a = 0, b = 1, c = 2 },
        packed enum(u3) { a = 0, b = 1, c = 2 },
    }) |e| {
        var s = EnumSet(e).Empty;

        testing.expect(!s.exists(.a));
        testing.expect(!s.exists(.b));
        testing.expect(!s.exists(.c));

        testing.expectEqual(@as(usize, 0), s.count());

        s.put(.b);
        s.put(.b); // put an already present item
        s.put(.c);
        testing.expect(!s.exists(.a));
        testing.expect(s.exists(.b));
        testing.expect(s.exists(.c));

        var it = s.iterator();
        var it_count: u8 = 0;
        while (it.next()) |entry| : (it_count += 1) {
            switch (it_count) {
                0 => testing.expectEqual(e.b, entry),
                1 => testing.expectEqual(e.c, entry),
                else => unreachable,
            }
        }
        testing.expectEqual(@as(u8, 2), it_count);
        testing.expectEqual(@as(usize, 2), s.count());

        s.delete(.a); // delete an unset item
        s.delete(.b);
        testing.expect(!s.exists(.a));
        testing.expect(!s.exists(.b));
        testing.expect(s.exists(.c));
    }
}
