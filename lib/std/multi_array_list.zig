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
                const byte_ptr = self.ptrs[@enumToInt(field)];
                const F = FieldType(field);
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
                @field(elem, field_info.name) = slices.items(@intToEnum(Field, i))[index];
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
                mem.copy(field_info.field_type, other_slice.items(field), self_slice.items(field));
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
                mem.copy(field_info.field_type, other_slice.items(field), self_slice.items(field));
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
    const testing = std.testing;
    const ally = testing.allocator;

    const Foo = struct {
        a: u32,
        b: []const u8,
        c: u8,
    };

    var list = MultiArrayList(Foo){};
    defer list.deinit(ally);

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
