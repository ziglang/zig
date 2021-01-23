// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("std");
const assert = std.debug.assert;
const meta = std.meta;
const Allocator = std.mem.Allocator;

/// Given a struct type, return a type managing growable, parallel slices
/// of the field type of all the struct's fields.
pub fn MultiArrayList(comptime S: type) type {
    return struct {
        const Self = @This();

        pub const Field = meta.FieldEnum(S);

        const fields = meta.fields(S);

        data: [fields.len][*]u8 = undefined,
        capacity: usize = 0,
        len: usize = 0,

        /// Init all lists to the given capacity
        pub fn initCapacity(allocator: *Allocator, capacity: usize) !Self {
            var self = Self{ .capacity = capacity };
            inline for (fields) |field, index| {
                errdefer {
                    comptime var i = 0;
                    inline while (i < index) : (i += 1) {
                        allocator.free(self.allocatedSlice(@intToEnum(Field, i)));
                    }
                }
                const slice = try allocator.allocAdvanced(field.field_type, field.alignment, capacity, .exact);
                self.data[index] = @ptrCast([*]u8, slice.ptr);
            }
            return self;
        }

        /// Free all memory and set the MultiArrayList to undefined
        pub fn deinit(self: *Self, allocator: *Allocator) void {
            inline for (fields) |_, i| {
                allocator.free(self.allocatedSlice(@intToEnum(Field, i)));
            }
            self.* = undefined;
        }

        pub fn items(self: *Self, comptime field: Field) []align(fieldAlign(field)) FieldType(field) {
            return self.allocatedSlice(field)[0..self.len];
        }

        pub fn allocatedSlice(self: *Self, comptime field: Field) []align(fieldAlign(field)) FieldType(field) {
            if (self.capacity == 0) return &[0]FieldType(field){};
            return @ptrCast(
                [*]FieldType(field),
                @alignCast(fieldAlign(field), self.data[@enumToInt(field)]),
            )[0..self.len];
        }

        fn FieldType(field: Field) type {
            return meta.fieldInfo(S, field).field_type;
        }

        fn fieldAlign(field: Field) comptime_int {
            return meta.fieldInfo(S, field).alignment;
        }

        /// Ensure that all lists have at least new_capacity, allocating if needed.
        pub fn ensureCapacity(self: *Self, allocator: *Allocator, new_capacity: usize) !void {
            var better_capacity = self.capacity;
            if (better_capacity >= new_capacity) return;

            while (true) {
                better_capacity += better_capacity / 2 + 8;
                if (better_capacity >= new_capacity) break;
            }

            // Realloc all lists, shrinking the already realloc'd lists back on error
            inline for (fields) |_, index| {
                errdefer {
                    comptime var i = 0;
                    inline while (i < index) : (i += 1) {
                        _ = allocator.shrink(self.allocatedSlice(@intToEnum(Field, i)), self.capacity);
                    }
                }
                const current_slice = self.allocatedSlice(@intToEnum(Field, index));
                const new_slice = try allocator.realloc(current_slice, better_capacity);
                self.data[index] = @ptrCast([*]u8, new_slice.ptr);
            }
            self.capacity = better_capacity;
        }

        pub fn shrinkAndFree(self: *Self, allocator: *Allocator, new_len: usize) void {
            assert(new_len <= self.len);
            inline for (fields) |_, i| {
                _ = allocator.shrink(self.allocatedSlice(@intToEnum(Field, i)), new_len);
            }
            self.len = new_len;
            self.capacity = new_len;
        }

        /// Add the value of each field of values to the end of the corresponding list
        pub fn append(self: *Self, allocator: *Allocator, values: S) !void {
            try self.ensureCapacity(allocator, self.len + 1);
            self.appendAssumeCapacity(values);
        }

        /// Add the value of each field of values to the end of the corresponding list
        pub fn appendAssumeCapacity(self: *Self, values: S) void {
            self.len += 1;
            inline for (meta.fields(S)) |field, i| {
                self.items(@intToEnum(Field, i))[self.len - 1] = @field(values, field.name);
            }
        }

        const OwnedSlices = @Type(blk: {
            const TypeInfo = std.builtin.TypeInfo;
            var owned_fields: [fields.len]TypeInfo.StructField = undefined;
            for (fields) |f, i| {
                const Slice = @Type(.{
                    .Pointer = .{
                        .size = .Slice,
                        .is_const = false,
                        .is_volatile = false,
                        .alignment = f.alignment,
                        .child = f.field_type,
                        .is_allowzero = false,
                        .sentinel = @as(?f.field_type, null),
                    },
                });
                owned_fields[i] = .{
                    .name = f.name,
                    .field_type = Slice,
                    .default_value = @as(?f.field_type, null),
                    .is_comptime = false,
                    .alignment = @alignOf(Slice),
                };
            }
            break :blk .{
                .Struct = .{
                    .layout = .Auto,
                    .fields = &owned_fields,
                    .decls = &[_]TypeInfo.Declaration{},
                    .is_tuple = false,
                },
            };
        });

        /// Returns a struct with a slice field for every field in S
        /// The returned slices are owned.
        /// This deinits the MultiArrayList, setting it to undefined
        pub fn toOwnedSlices(self: *Self, allocator: *Allocator) OwnedSlices {
            self.shrinkAndFree(allocator, self.len);
            var ret: OwnedSlices = undefined;
            inline for (fields) |field, i| {
                @field(ret, field.name) = self.items(@intToEnum(Field, i));
            }
            self.* = undefined;
            return ret;
        }
    };
}

test "basic usage" {
    const testing = std.testing;
    const ally = testing.allocator;

    const Foo = struct {
        a: u32,
        b: []const u8,
        c: u8,
    };

    // no defer as we call toOwnedSlices() below
    var list = MultiArrayList(Foo){};

    try list.ensureCapacity(ally, 2);

    list.appendAssumeCapacity(.{
        .a = 1,
        .b = "foobar",
        .c = 'a',
    });

    list.appendAssumeCapacity(.{
        .a = 2,
        .b = "zigzag",
        .c = 'b',
    });

    testing.expectEqualSlices(u32, list.items(.a), &[_]u32{ 1, 2 });
    testing.expectEqualSlices(u8, list.items(.c), &[_]u8{ 'a', 'b' });

    testing.expectEqual(@as(usize, 2), list.items(.b).len);
    testing.expectEqualStrings("foobar", list.items(.b)[0]);
    testing.expectEqualStrings("zigzag", list.items(.b)[1]);

    try list.append(ally, .{
        .a = 3,
        .b = "fizzbuzz",
        .c = 'c',
    });

    testing.expectEqualSlices(u32, list.items(.a), &[_]u32{ 1, 2, 3 });
    testing.expectEqualSlices(u8, list.items(.c), &[_]u8{ 'a', 'b', 'c' });

    testing.expectEqual(@as(usize, 3), list.items(.b).len);
    testing.expectEqualStrings("foobar", list.items(.b)[0]);
    testing.expectEqualStrings("zigzag", list.items(.b)[1]);
    testing.expectEqualStrings("fizzbuzz", list.items(.b)[2]);

    // Add 6 more things to force a capacity increase.
    var i: usize = 0;
    while (i < 6) : (i += 1) {
        try list.append(ally, .{
            .a = @intCast(u32, 4 + i),
            .b = "whatever",
            .c = @intCast(u8, 'd' + i),
        });
    }

    testing.expectEqualSlices(
        u32,
        &[_]u32{ 1, 2, 3, 4, 5, 6, 7, 8, 9 },
        list.items(.a),
    );
    testing.expectEqualSlices(
        u8,
        &[_]u8{ 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i' },
        list.items(.c),
    );

    list.len = 3;
    const slices = list.toOwnedSlices(ally);
    defer {
        ally.free(slices.a);
        ally.free(slices.b);
        ally.free(slices.c);
    }

    testing.expectEqualSlices(u32, &[_]u32{ 1, 2, 3 }, slices.a);
    testing.expectEqualSlices(u8, &[_]u8{ 'a', 'b', 'c' }, slices.c);

    testing.expectEqual(@as(usize, 3), slices.b.len);
    testing.expectEqualStrings("foobar", slices.b[0]);
    testing.expectEqualStrings("zigzag", slices.b[1]);
    testing.expectEqualStrings("fizzbuzz", slices.b[2]);
}
