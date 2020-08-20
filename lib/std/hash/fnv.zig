// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
// FNV1a - Fowler-Noll-Vo hash function
//
// FNV1a is a fast, non-cryptographic hash function with fairly good distribution properties.
//
// https://tools.ietf.org/html/draft-eastlake-fnv-14

const std = @import("../std.zig");
const testing = std.testing;

pub const Fnv1a_32 = Fnv1a(u32, 0x01000193, 0x811c9dc5);
pub const Fnv1a_64 = Fnv1a(u64, 0x100000001b3, 0xcbf29ce484222325);
pub const Fnv1a_128 = Fnv1a(u128, 0x1000000000000000000013b, 0x6c62272e07bb014262b821756295c58d);

fn Fnv1a(comptime T: type, comptime prime: T, comptime offset: T) type {
    return struct {
        const Self = @This();

        value: T,

        pub fn init() Self {
            return Self{ .value = offset };
        }

        pub fn update(self: *Self, input: []const u8) void {
            for (input) |b| {
                self.value ^= b;
                self.value *%= prime;
            }
        }

        pub fn final(self: *Self) T {
            return self.value;
        }

        pub fn hash(input: []const u8) T {
            var c = Self.init();
            c.update(input);
            return c.final();
        }
    };
}

test "fnv1a-32" {
    testing.expect(Fnv1a_32.hash("") == 0x811c9dc5);
    testing.expect(Fnv1a_32.hash("a") == 0xe40c292c);
    testing.expect(Fnv1a_32.hash("foobar") == 0xbf9cf968);
}

test "fnv1a-64" {
    testing.expect(Fnv1a_64.hash("") == 0xcbf29ce484222325);
    testing.expect(Fnv1a_64.hash("a") == 0xaf63dc4c8601ec8c);
    testing.expect(Fnv1a_64.hash("foobar") == 0x85944171f73967e8);
}

test "fnv1a-128" {
    testing.expect(Fnv1a_128.hash("") == 0x6c62272e07bb014262b821756295c58d);
    testing.expect(Fnv1a_128.hash("a") == 0xd228cb696f1a8caf78912b704e4a8964);
}
