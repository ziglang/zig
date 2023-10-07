const std = @import("../std.zig");
const meta = std.meta;
const testing = std.testing;
const mem = std.mem;
const assert = std.debug.assert;
const Type = std.builtin.Type;

/// This is useful for saving memory when allocating an object that has many
/// optional components. The optional objects are allocated sequentially in
/// memory, and a single integer is used to represent each optional object
/// and whether it is present based on each corresponding bit.
pub fn TrailerFlags(comptime Fields: type) type {
    return struct {
        bits: Int,

        pub const Int = meta.Int(.unsigned, bit_count);
        pub const bit_count = @typeInfo(Fields).Struct.fields.len;

        pub const FieldEnum = std.meta.FieldEnum(Fields);

        pub const ActiveFields = std.enums.EnumFieldStruct(FieldEnum, bool, false);
        pub const FieldValues = blk: {
            comptime var fields: [bit_count]Type.StructField = undefined;
            inline for (@typeInfo(Fields).Struct.fields, 0..) |struct_field, i| {
                fields[i] = Type.StructField{
                    .name = struct_field.name,
                    .type = ?struct_field.type,
                    .default_value = &@as(?struct_field.type, null),
                    .is_comptime = false,
                    .alignment = @alignOf(?struct_field.type),
                };
            }
            break :blk @Type(.{
                .Struct = .{
                    .layout = .Auto,
                    .fields = &fields,
                    .decls = &.{},
                    .is_tuple = false,
                },
            });
        };

        pub const Self = @This();

        pub fn has(self: Self, comptime field: FieldEnum) bool {
            const field_index = @intFromEnum(field);
            return (self.bits & (1 << field_index)) != 0;
        }

        pub fn get(self: Self, p: [*]align(@alignOf(Fields)) const u8, comptime field: FieldEnum) ?Field(field) {
            if (!self.has(field))
                return null;
            return self.ptrConst(p, field).*;
        }

        pub fn setFlag(self: *Self, comptime field: FieldEnum) void {
            const field_index = @intFromEnum(field);
            self.bits |= 1 << field_index;
        }

        /// `fields` is a boolean struct where each active field is set to `true`
        pub fn init(fields: ActiveFields) Self {
            var self: Self = .{ .bits = 0 };
            inline for (@typeInfo(Fields).Struct.fields, 0..) |field, i| {
                if (@field(fields, field.name))
                    self.bits |= 1 << i;
            }
            return self;
        }

        /// `fields` is a struct with each field set to an optional value
        pub fn setMany(self: Self, p: [*]align(@alignOf(Fields)) u8, fields: FieldValues) void {
            inline for (@typeInfo(Fields).Struct.fields, 0..) |field, i| {
                if (@field(fields, field.name)) |value|
                    self.set(p, @as(FieldEnum, @enumFromInt(i)), value);
            }
        }

        pub fn set(
            self: Self,
            p: [*]align(@alignOf(Fields)) u8,
            comptime field: FieldEnum,
            value: Field(field),
        ) void {
            self.ptr(p, field).* = value;
        }

        pub fn ptr(self: Self, p: [*]align(@alignOf(Fields)) u8, comptime field: FieldEnum) *Field(field) {
            if (@sizeOf(Field(field)) == 0)
                return undefined;
            const off = self.offset(field);
            return @ptrCast(@alignCast(p + off));
        }

        pub fn ptrConst(self: Self, p: [*]align(@alignOf(Fields)) const u8, comptime field: FieldEnum) *const Field(field) {
            if (@sizeOf(Field(field)) == 0)
                return undefined;
            const off = self.offset(field);
            return @ptrCast(@alignCast(p + off));
        }

        pub fn offset(self: Self, comptime field: FieldEnum) usize {
            var off: usize = 0;
            inline for (@typeInfo(Fields).Struct.fields, 0..) |field_info, i| {
                const active = (self.bits & (1 << i)) != 0;
                if (i == @intFromEnum(field)) {
                    assert(active);
                    return mem.alignForward(usize, off, @alignOf(field_info.type));
                } else if (active) {
                    off = mem.alignForward(usize, off, @alignOf(field_info.type));
                    off += @sizeOf(field_info.type);
                }
            }
        }

        pub fn Field(comptime field: FieldEnum) type {
            return @typeInfo(Fields).Struct.fields[@intFromEnum(field)].type;
        }

        pub fn sizeInBytes(self: Self) usize {
            var off: usize = 0;
            inline for (@typeInfo(Fields).Struct.fields, 0..) |field, i| {
                if (@sizeOf(field.type) == 0)
                    continue;
                if ((self.bits & (1 << i)) != 0) {
                    off = mem.alignForward(usize, off, @alignOf(field.type));
                    off += @sizeOf(field.type);
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
    try testing.expectEqual(u2, meta.Tag(Flags.FieldEnum));

    var flags = Flags.init(.{
        .b = true,
        .c = true,
    });
    const slice = try testing.allocator.alignedAlloc(u8, 8, flags.sizeInBytes());
    defer testing.allocator.free(slice);

    flags.set(slice.ptr, .b, false);
    flags.set(slice.ptr, .c, 12345678);

    try testing.expect(flags.get(slice.ptr, .a) == null);
    try testing.expect(!flags.get(slice.ptr, .b).?);
    try testing.expect(flags.get(slice.ptr, .c).? == 12345678);

    flags.setMany(slice.ptr, .{
        .b = true,
        .c = 5678,
    });

    try testing.expect(flags.get(slice.ptr, .a) == null);
    try testing.expect(flags.get(slice.ptr, .b).?);
    try testing.expect(flags.get(slice.ptr, .c).? == 5678);
}
