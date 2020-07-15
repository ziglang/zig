const std = @import("../std.zig");
const meta = std.meta;
const testing = std.testing;
const mem = std.mem;
const assert = std.debug.assert;

/// This is useful for saving memory when allocating an object that has many
/// optional components. The optional objects are allocated sequentially in
/// memory, and a single integer is used to represent each optional object
/// and whether it is present based on each corresponding bit.
pub fn TrailerFlags(comptime Fields: type) type {
    return struct {
        bits: Int,

        pub const Int = @Type(.{ .Int = .{ .bits = bit_count, .is_signed = false } });
        pub const bit_count = @typeInfo(Fields).Struct.fields.len;

        pub const Self = @This();

        pub fn has(self: Self, comptime name: []const u8) bool {
            const field_index = meta.fieldIndex(Fields, name).?;
            return (self.bits & (1 << field_index)) != 0;
        }

        pub fn get(self: Self, p: [*]align(@alignOf(Fields)) const u8, comptime name: []const u8) ?Field(name) {
            if (!self.has(name))
                return null;
            return self.ptrConst(p, name).*;
        }

        pub fn setFlag(self: *Self, comptime name: []const u8) void {
            const field_index = meta.fieldIndex(Fields, name).?;
            self.bits |= 1 << field_index;
        }

        /// `fields` is a struct with each field set to an optional value.
        /// Missing fields are assumed to be `null`.
        /// Only the non-null bits are observed and are used to set the flag bits.
        pub fn init(fields: anytype) Self {
            var self: Self = .{ .bits = 0 };
            inline for (@typeInfo(@TypeOf(fields)).Struct.fields) |field| {
                const opt: ?Field(field.name) = @field(fields, field.name);
                const field_index = meta.fieldIndex(Fields, field.name).?;
                self.bits |= @as(Int, @boolToInt(opt != null)) << field_index;
            }
            return self;
        }

        /// `fields` is a struct with each field set to an optional value (same as `init`).
        /// Missing fields are assumed to be `null`.
        pub fn setMany(self: Self, p: [*]align(@alignOf(Fields)) u8, fields: anytype) void {
            inline for (@typeInfo(@TypeOf(fields)).Struct.fields) |field| {
                const opt: ?Field(field.name) = @field(fields, field.name);
                if (opt) |value| {
                    self.set(p, field.name, value);
                }
            }
        }

        pub fn set(
            self: Self,
            p: [*]align(@alignOf(Fields)) u8,
            comptime name: []const u8,
            value: Field(name),
        ) void {
            self.ptr(p, name).* = value;
        }

        pub fn ptr(self: Self, p: [*]align(@alignOf(Fields)) u8, comptime name: []const u8) *Field(name) {
            if (@sizeOf(Field(name)) == 0)
                return undefined;
            const off = self.offset(p, name);
            return @ptrCast(*Field(name), @alignCast(@alignOf(Field(name)), p + off));
        }

        pub fn ptrConst(self: Self, p: [*]align(@alignOf(Fields)) const u8, comptime name: []const u8) *const Field(name) {
            if (@sizeOf(Field(name)) == 0)
                return undefined;
            const off = self.offset(p, name);
            return @ptrCast(*const Field(name), @alignCast(@alignOf(Field(name)), p + off));
        }

        pub fn offset(self: Self, p: [*]align(@alignOf(Fields)) const u8, comptime name: []const u8) usize {
            var off: usize = 0;
            inline for (@typeInfo(Fields).Struct.fields) |field, i| {
                const active = (self.bits & (1 << i)) != 0;
                if (comptime mem.eql(u8, field.name, name)) {
                    assert(active);
                    return mem.alignForwardGeneric(usize, off, @alignOf(field.field_type));
                } else if (active) {
                    off = mem.alignForwardGeneric(usize, off, @alignOf(field.field_type));
                    off += @sizeOf(field.field_type);
                }
            }
            @compileError("no field named " ++ name ++ " in type " ++ @typeName(Fields));
        }

        pub fn Field(comptime name: []const u8) type {
            return meta.fieldInfo(Fields, name).field_type;
        }

        pub fn sizeInBytes(self: Self) usize {
            var off: usize = 0;
            inline for (@typeInfo(Fields).Struct.fields) |field, i| {
                if (@sizeOf(field.field_type) == 0)
                    continue;
                if ((self.bits & (1 << i)) != 0) {
                    off = mem.alignForwardGeneric(usize, off, @alignOf(field.field_type));
                    off += @sizeOf(field.field_type);
                }
            }
            return off;
        }
    };
}

test "TrailerFlags" {
    const Flags = TrailerFlags(struct {
        a: i32,
        b: bool,
        c: u64,
    });
    var flags = Flags.init(.{
        .b = true,
        .c = 1234,
    });
    const slice = try testing.allocator.allocAdvanced(u8, 8, flags.sizeInBytes(), .exact);
    defer testing.allocator.free(slice);

    flags.set(slice.ptr, "b", false);
    flags.set(slice.ptr, "c", 12345678);

    testing.expect(flags.get(slice.ptr, "a") == null);
    testing.expect(!flags.get(slice.ptr, "b").?);
    testing.expect(flags.get(slice.ptr, "c").? == 12345678);

    flags.setMany(slice.ptr, .{
        .b = true,
        .c = 5678,
    });

    testing.expect(flags.get(slice.ptr, "a") == null);
    testing.expect(flags.get(slice.ptr, "b").?);
    testing.expect(flags.get(slice.ptr, "c").? == 5678);
}
