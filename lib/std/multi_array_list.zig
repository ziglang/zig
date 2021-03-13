// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("std.zig");
const assert = std.debug.assert;
const meta = std.meta;
const mem = std.mem;
const Allocator = mem.Allocator;
const testing = std.testing;

pub fn MultiArrayList(comptime S: type) type {
    return struct {
        bytes: [*]align(@alignOf(S)) u8 = undefined,
        len: usize = 0,
        capacity: usize = 0,

        pub const Elem = S;

        pub const Field = meta.FieldEnum(S);

        pub const Slice = struct {
            /// This array is indexed by the field index which can be obtained
            /// by using @enumToInt() on the Field enum
            ptrs: [fields.len][*]u8,
            len: usize,
            capacity: usize,

            pub fn items(self: Slice, comptime field: Field) []FieldType(field) {
                const F = FieldType(field);
                if (self.len == 0) {
                    return &[_]F{};
                }
                const byte_ptr = self.ptrs[@enumToInt(field)];
                const casted_ptr = @ptrCast([*]F, @alignCast(@alignOf(F), byte_ptr));
                return casted_ptr[0..self.len];
            }

            pub fn toMultiArrayList(self: Slice) Self {
                if (self.ptrs.len == 0) {
                    return .{};
                }
                const unaligned_ptr = self.ptrs[sizes.fields[0]];
                const aligned_ptr = @alignCast(@alignOf(S), unaligned_ptr);
                const casted_ptr = @ptrCast([*]align(@alignOf(S)) u8, aligned_ptr);
                return .{
                    .bytes = casted_ptr,
                    .len = self.len,
                    .capacity = self.capacity,
                };
            }

            pub fn deinit(self: *Slice, gpa: *Allocator) void {
                var other = self.toMultiArrayList();
                other.deinit(gpa);
                self.* = undefined;
            }
        };

        const Self = @This();

        const fields = meta.fields(S);
        /// `sizes.bytes` is an array of @sizeOf each S field. Sorted by alignment, descending.
        /// `sizes.fields` is an array mapping from `sizes.bytes` array index to field index.
        const sizes = blk: {
            const Data = struct {
                size: usize,
                size_index: usize,
                alignment: usize,
            };
            var data: [fields.len]Data = undefined;
            for (fields) |field_info, i| {
                data[i] = .{
                    .size = @sizeOf(field_info.field_type),
                    .size_index = i,
                    .alignment = field_info.alignment,
                };
            }
            const Sort = struct {
                fn lessThan(trash: *i32, lhs: Data, rhs: Data) bool {
                    return lhs.alignment >= rhs.alignment;
                }
            };
            var trash: i32 = undefined; // workaround for stage1 compiler bug
            std.sort.sort(Data, &data, &trash, Sort.lessThan);
            var sizes_bytes: [fields.len]usize = undefined;
            var field_indexes: [fields.len]usize = undefined;
            for (data) |elem, i| {
                sizes_bytes[i] = elem.size;
                field_indexes[i] = elem.size_index;
            }
            break :blk .{
                .bytes = sizes_bytes,
                .fields = field_indexes,
            };
        };

        /// Release all allocated memory.
        pub fn deinit(self: *Self, gpa: *Allocator) void {
            gpa.free(self.allocatedBytes());
            self.* = undefined;
        }

        /// The caller owns the returned memory. Empties this MultiArrayList.
        pub fn toOwnedSlice(self: *Self) Slice {
            const result = self.slice();
            self.* = .{};
            return result;
        }

        pub fn slice(self: Self) Slice {
            var result: Slice = .{
                .ptrs = undefined,
                .len = self.len,
                .capacity = self.capacity,
            };
            var ptr: [*]u8 = self.bytes;
            for (sizes.bytes) |field_size, i| {
                result.ptrs[sizes.fields[i]] = ptr;
                ptr += field_size * self.capacity;
            }
            return result;
        }

        pub fn items(self: Self, comptime field: Field) []FieldType(field) {
            return self.slice().items(field);
        }

        /// Overwrite one array element with new data.
        pub fn set(self: *Self, index: usize, elem: S) void {
            const slices = self.slice();
            inline for (fields) |field_info, i| {
                slices.items(@intToEnum(Field, i))[index] = @field(elem, field_info.name);
            }
        }

        /// Obtain all the data for one array element.
        pub fn get(self: *Self, index: usize) S {
            const slices = self.slice();
            var result: S = undefined;
            inline for (fields) |field_info, i| {
                @field(result, field_info.name) = slices.items(@intToEnum(Field, i))[index];
            }
            return result;
        }

        /// Extend the list by 1 element. Allocates more memory as necessary.
        pub fn append(self: *Self, gpa: *Allocator, elem: S) !void {
            try self.ensureCapacity(gpa, self.len + 1);
            self.appendAssumeCapacity(elem);
        }

        /// Extend the list by 1 element, but asserting `self.capacity`
        /// is sufficient to hold an additional item.
        pub fn appendAssumeCapacity(self: *Self, elem: S) void {
            assert(self.len < self.capacity);
            self.len += 1;
            self.set(self.len - 1, elem);
        }

        /// Adjust the list's length to `new_len`.
        /// Does not initialize added items, if any.
        pub fn resize(self: *Self, gpa: *Allocator, new_len: usize) !void {
            try self.ensureCapacity(gpa, new_len);
            self.len = new_len;
        }

        /// Attempt to reduce allocated capacity to `new_len`.
        /// If `new_len` is greater than zero, this may fail to reduce the capacity,
        /// but the data remains intact and the length is updated to new_len.
        pub fn shrinkAndFree(self: *Self, gpa: *Allocator, new_len: usize) void {
            if (new_len == 0) {
                gpa.free(self.allocatedBytes());
                self.* = .{};
                return;
            }
            assert(new_len <= self.capacity);
            assert(new_len <= self.len);

            const other_bytes = gpa.allocAdvanced(
                u8,
                @alignOf(S),
                capacityInBytes(new_len),
                .exact,
            ) catch {
                const self_slice = self.slice();
                inline for (fields) |field_info, i| {
                    const field = @intToEnum(Field, i);
                    const dest_slice = self_slice.items(field)[new_len..];
                    const byte_count = dest_slice.len * @sizeOf(field_info.field_type);
                    // We use memset here for more efficient codegen in safety-checked,
                    // valgrind-enabled builds. Otherwise the valgrind client request
                    // will be repeated for every element.
                    @memset(@ptrCast([*]u8, dest_slice.ptr), undefined, byte_count);
                }
                self.len = new_len;
                return;
            };
            var other = Self{
                .bytes = other_bytes.ptr,
                .capacity = new_len,
                .len = new_len,
            };
            self.len = new_len;
            const self_slice = self.slice();
            const other_slice = other.slice();
            inline for (fields) |field_info, i| {
                const field = @intToEnum(Field, i);
                // TODO we should be able to use std.mem.copy here but it causes a
                // test failure on aarch64 with -OReleaseFast
                const src_slice = mem.sliceAsBytes(self_slice.items(field));
                const dst_slice = mem.sliceAsBytes(other_slice.items(field));
                @memcpy(dst_slice.ptr, src_slice.ptr, src_slice.len);
            }
            gpa.free(self.allocatedBytes());
            self.* = other;
        }

        /// Reduce length to `new_len`.
        /// Invalidates pointers to elements `items[new_len..]`.
        /// Keeps capacity the same.
        pub fn shrinkRetainingCapacity(self: *Self, new_len: usize) void {
            self.len = new_len;
        }

        /// Modify the array so that it can hold at least `new_capacity` items.
        /// Implements super-linear growth to achieve amortized O(1) append operations.
        /// Invalidates pointers if additional memory is needed.
        pub fn ensureCapacity(self: *Self, gpa: *Allocator, new_capacity: usize) !void {
            var better_capacity = self.capacity;
            if (better_capacity >= new_capacity) return;

            while (true) {
                better_capacity += better_capacity / 2 + 8;
                if (better_capacity >= new_capacity) break;
            }

            return self.setCapacity(gpa, better_capacity);
        }

        /// Modify the array so that it can hold exactly `new_capacity` items.
        /// Invalidates pointers if additional memory is needed.
        /// `new_capacity` must be greater or equal to `len`.
        pub fn setCapacity(self: *Self, gpa: *Allocator, new_capacity: usize) !void {
            assert(new_capacity >= self.len);
            const new_bytes = try gpa.allocAdvanced(
                u8,
                @alignOf(S),
                capacityInBytes(new_capacity),
                .exact,
            );
            if (self.len == 0) {
                gpa.free(self.allocatedBytes());
                self.bytes = new_bytes.ptr;
                self.capacity = new_capacity;
                return;
            }
            var other = Self{
                .bytes = new_bytes.ptr,
                .capacity = new_capacity,
                .len = self.len,
            };
            const self_slice = self.slice();
            const other_slice = other.slice();
            inline for (fields) |field_info, i| {
                const field = @intToEnum(Field, i);
                // TODO we should be able to use std.mem.copy here but it causes a
                // test failure on aarch64 with -OReleaseFast
                const src_slice = mem.sliceAsBytes(self_slice.items(field));
                const dst_slice = mem.sliceAsBytes(other_slice.items(field));
                @memcpy(dst_slice.ptr, src_slice.ptr, src_slice.len);
            }
            gpa.free(self.allocatedBytes());
            self.* = other;
        }

        fn capacityInBytes(capacity: usize) usize {
            const sizes_vector: std.meta.Vector(sizes.bytes.len, usize) = sizes.bytes;
            const capacity_vector = @splat(sizes.bytes.len, capacity);
            return @reduce(.Add, capacity_vector * sizes_vector);
        }

        fn allocatedBytes(self: Self) []align(@alignOf(S)) u8 {
            return self.bytes[0..capacityInBytes(self.capacity)];
        }

        fn FieldType(field: Field) type {
            return meta.fieldInfo(S, field).field_type;
        }
    };
}

test "basic usage" {
    const ally = testing.allocator;

    const Foo = struct {
        a: u32,
        b: []const u8,
        c: u8,
    };

    var list = MultiArrayList(Foo){};
    defer list.deinit(ally);

    testing.expectEqual(@as(usize, 0), list.items(.a).len);

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

    list.shrinkAndFree(ally, 3);

    testing.expectEqualSlices(u32, list.items(.a), &[_]u32{ 1, 2, 3 });
    testing.expectEqualSlices(u8, list.items(.c), &[_]u8{ 'a', 'b', 'c' });

    testing.expectEqual(@as(usize, 3), list.items(.b).len);
    testing.expectEqualStrings("foobar", list.items(.b)[0]);
    testing.expectEqualStrings("zigzag", list.items(.b)[1]);
    testing.expectEqualStrings("fizzbuzz", list.items(.b)[2]);
}

// This was observed to fail on aarch64 with LLVM 11, when the capacityInBytes
// function used the @reduce code path.
test "regression test for @reduce bug" {
    const ally = testing.allocator;
    var list = MultiArrayList(struct {
        tag: std.zig.Token.Tag,
        start: u32,
    }){};
    defer list.deinit(ally);

    try list.ensureCapacity(ally, 20);

    try list.append(ally, .{ .tag = .keyword_const, .start = 0 });
    try list.append(ally, .{ .tag = .identifier, .start = 6 });
    try list.append(ally, .{ .tag = .equal, .start = 10 });
    try list.append(ally, .{ .tag = .builtin, .start = 12 });
    try list.append(ally, .{ .tag = .l_paren, .start = 19 });
    try list.append(ally, .{ .tag = .string_literal, .start = 20 });
    try list.append(ally, .{ .tag = .r_paren, .start = 25 });
    try list.append(ally, .{ .tag = .semicolon, .start = 26 });
    try list.append(ally, .{ .tag = .keyword_pub, .start = 29 });
    try list.append(ally, .{ .tag = .keyword_fn, .start = 33 });
    try list.append(ally, .{ .tag = .identifier, .start = 36 });
    try list.append(ally, .{ .tag = .l_paren, .start = 40 });
    try list.append(ally, .{ .tag = .r_paren, .start = 41 });
    try list.append(ally, .{ .tag = .identifier, .start = 43 });
    try list.append(ally, .{ .tag = .bang, .start = 51 });
    try list.append(ally, .{ .tag = .identifier, .start = 52 });
    try list.append(ally, .{ .tag = .l_brace, .start = 57 });
    try list.append(ally, .{ .tag = .identifier, .start = 63 });
    try list.append(ally, .{ .tag = .period, .start = 66 });
    try list.append(ally, .{ .tag = .identifier, .start = 67 });
    try list.append(ally, .{ .tag = .period, .start = 70 });
    try list.append(ally, .{ .tag = .identifier, .start = 71 });
    try list.append(ally, .{ .tag = .l_paren, .start = 75 });
    try list.append(ally, .{ .tag = .string_literal, .start = 76 });
    try list.append(ally, .{ .tag = .comma, .start = 113 });
    try list.append(ally, .{ .tag = .period, .start = 115 });
    try list.append(ally, .{ .tag = .l_brace, .start = 116 });
    try list.append(ally, .{ .tag = .r_brace, .start = 117 });
    try list.append(ally, .{ .tag = .r_paren, .start = 118 });
    try list.append(ally, .{ .tag = .semicolon, .start = 119 });
    try list.append(ally, .{ .tag = .r_brace, .start = 121 });
    try list.append(ally, .{ .tag = .eof, .start = 123 });

    const tags = list.items(.tag);
    testing.expectEqual(tags[1], .identifier);
    testing.expectEqual(tags[2], .equal);
    testing.expectEqual(tags[3], .builtin);
    testing.expectEqual(tags[4], .l_paren);
    testing.expectEqual(tags[5], .string_literal);
    testing.expectEqual(tags[6], .r_paren);
    testing.expectEqual(tags[7], .semicolon);
    testing.expectEqual(tags[8], .keyword_pub);
    testing.expectEqual(tags[9], .keyword_fn);
    testing.expectEqual(tags[10], .identifier);
    testing.expectEqual(tags[11], .l_paren);
    testing.expectEqual(tags[12], .r_paren);
    testing.expectEqual(tags[13], .identifier);
    testing.expectEqual(tags[14], .bang);
    testing.expectEqual(tags[15], .identifier);
    testing.expectEqual(tags[16], .l_brace);
    testing.expectEqual(tags[17], .identifier);
    testing.expectEqual(tags[18], .period);
    testing.expectEqual(tags[19], .identifier);
    testing.expectEqual(tags[20], .period);
    testing.expectEqual(tags[21], .identifier);
    testing.expectEqual(tags[22], .l_paren);
    testing.expectEqual(tags[23], .string_literal);
    testing.expectEqual(tags[24], .comma);
    testing.expectEqual(tags[25], .period);
    testing.expectEqual(tags[26], .l_brace);
    testing.expectEqual(tags[27], .r_brace);
    testing.expectEqual(tags[28], .r_paren);
    testing.expectEqual(tags[29], .semicolon);
    testing.expectEqual(tags[30], .r_brace);
    testing.expectEqual(tags[31], .eof);
}

test "ensure capacity on empty list" {
    const ally = testing.allocator;

    const Foo = struct {
        a: u32,
        b: u8,
    };

    var list = MultiArrayList(Foo){};
    defer list.deinit(ally);

    try list.ensureCapacity(ally, 2);
    list.appendAssumeCapacity(.{ .a = 1, .b = 2 });
    list.appendAssumeCapacity(.{ .a = 3, .b = 4 });

    testing.expectEqualSlices(u32, &[_]u32{ 1, 3 }, list.items(.a));
    testing.expectEqualSlices(u8, &[_]u8{ 2, 4 }, list.items(.b));

    list.len = 0;
    list.appendAssumeCapacity(.{ .a = 5, .b = 6 });
    list.appendAssumeCapacity(.{ .a = 7, .b = 8 });

    testing.expectEqualSlices(u32, &[_]u32{ 5, 7 }, list.items(.a));
    testing.expectEqualSlices(u8, &[_]u8{ 6, 8 }, list.items(.b));

    list.len = 0;
    try list.ensureCapacity(ally, 16);

    list.appendAssumeCapacity(.{ .a = 9, .b = 10 });
    list.appendAssumeCapacity(.{ .a = 11, .b = 12 });

    testing.expectEqualSlices(u32, &[_]u32{ 9, 11 }, list.items(.a));
    testing.expectEqualSlices(u8, &[_]u8{ 10, 12 }, list.items(.b));
}
