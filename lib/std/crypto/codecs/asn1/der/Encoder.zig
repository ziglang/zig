//! A buffered DER encoder.
//!
//! Prefers calling container's `fn encodeDer(self: @This(), encoder: *der.Encoder)`.
//! That function should encode values, lengths, then tags.
buffer: ArrayListReverse,
/// The field tag set by a parent container.
/// This is needed because we might visit an implicitly tagged container with a `fn encodeDer`.
field_tag: ?FieldTag = null,

pub fn init(allocator: std.mem.Allocator) Encoder {
    return Encoder{ .buffer = ArrayListReverse.init(allocator) };
}

pub fn deinit(self: *Encoder) void {
    self.buffer.deinit();
}

/// Encode any value.
pub fn any(self: *Encoder, val: anytype) !void {
    const T = @TypeOf(val);
    try self.anyTag(Tag.fromZig(T), val);
}

fn anyTag(self: *Encoder, tag_: Tag, val: anytype) !void {
    const T = @TypeOf(val);
    if (std.meta.hasFn(T, "encodeDer")) return try val.encodeDer(self);
    const start = self.buffer.data.len;
    const merged_tag = self.mergedTag(tag_);

    switch (@typeInfo(T)) {
        .@"struct" => |info| {
            inline for (0..info.fields.len) |i| {
                const f = info.fields[info.fields.len - i - 1];
                const field_val = @field(val, f.name);
                const field_tag = FieldTag.fromContainer(T, f.name);

                // > The encoding of a set value or sequence value shall not include an encoding for any
                // > component value which is equal to its default value.
                const is_default = if (f.is_comptime) false else if (f.default_value_ptr) |v| brk: {
                    const default_val: *const f.type = @alignCast(@ptrCast(v));
                    break :brk std.mem.eql(u8, std.mem.asBytes(default_val), std.mem.asBytes(&field_val));
                } else false;

                if (!is_default) {
                    const start2 = self.buffer.data.len;
                    self.field_tag = field_tag;
                    // will merge with self.field_tag.
                    // may mutate self.field_tag.
                    try self.anyTag(Tag.fromZig(f.type), field_val);
                    if (field_tag) |ft| {
                        if (ft.explicit) {
                            try self.length(self.buffer.data.len - start2);
                            try self.tag(ft.toTag());
                            self.field_tag = null;
                        }
                    }
                }
            }
        },
        .bool => try self.buffer.prependSlice(&[_]u8{if (val) 0xff else 0}),
        .int => try self.int(T, val),
        .@"enum" => |e| {
            if (@hasDecl(T, "oids")) {
                return self.any(T.oids.enumToOid(val));
            } else {
                try self.int(e.tag_type, @intFromEnum(val));
            }
        },
        .optional => if (val) |v| return try self.anyTag(tag_, v),
        .null => {},
        else => @compileError("cannot encode type " ++ @typeName(T)),
    }

    try self.length(self.buffer.data.len - start);
    try self.tag(merged_tag);
}

/// Encode a tag.
pub fn tag(self: *Encoder, tag_: Tag) !void {
    const t = self.mergedTag(tag_);
    try t.encode(self.writer());
}

fn mergedTag(self: *Encoder, tag_: Tag) Tag {
    var res = tag_;
    if (self.field_tag) |ft| {
        if (!ft.explicit) {
            res.number = @enumFromInt(ft.number);
            res.class = ft.class;
        }
    }
    return res;
}

/// Encode a length.
pub fn length(self: *Encoder, len: usize) !void {
    const writer_ = self.writer();
    if (len < 128) {
        try writer_.writeInt(u8, @intCast(len), .big);
        return;
    }
    inline for ([_]type{ u8, u16, u32 }) |T| {
        if (len < std.math.maxInt(T)) {
            try writer_.writeInt(T, @intCast(len), .big);
            try writer_.writeInt(u8, @sizeOf(T) | 0x80, .big);
            return;
        }
    }
    return error.InvalidLength;
}

/// Encode a tag and length-prefixed bytes.
pub fn tagBytes(self: *Encoder, tag_: Tag, bytes: []const u8) !void {
    try self.buffer.prependSlice(bytes);
    try self.length(bytes.len);
    try self.tag(tag_);
}

/// Warning: This writer writes backwards. `fn print` will NOT work as expected.
pub fn writer(self: *Encoder) ArrayListReverse.Writer {
    return self.buffer.writer();
}

fn int(self: *Encoder, comptime T: type, value: T) !void {
    const big = std.mem.nativeTo(T, value, .big);
    const big_bytes = std.mem.asBytes(&big);

    const bits_needed = @bitSizeOf(T) - @clz(value);
    const needs_padding: u1 = if (value == 0)
        1
    else if (bits_needed > 8) brk: {
        const RightShift = std.meta.Int(.unsigned, @bitSizeOf(@TypeOf(bits_needed)) - 1);
        const right_shift: RightShift = @intCast(bits_needed - 9);
        break :brk if (value >> right_shift == 0x1ff) 1 else 0;
    } else 0;
    const bytes_needed = try std.math.divCeil(usize, bits_needed, 8) + needs_padding;

    const writer_ = self.writer();
    for (0..bytes_needed - needs_padding) |i| try writer_.writeByte(big_bytes[big_bytes.len - i - 1]);
    if (needs_padding == 1) try writer_.writeByte(0);
}

test int {
    const allocator = std.testing.allocator;
    var encoder = Encoder.init(allocator);
    defer encoder.deinit();

    try encoder.int(u8, 0);
    try std.testing.expectEqualSlices(u8, &[_]u8{0}, encoder.buffer.data);

    encoder.buffer.clearAndFree();
    try encoder.int(u16, 0x00ff);
    try std.testing.expectEqualSlices(u8, &[_]u8{0xff}, encoder.buffer.data);

    encoder.buffer.clearAndFree();
    try encoder.int(u32, 0xffff);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0, 0xff, 0xff }, encoder.buffer.data);
}

const std = @import("std");
const Oid = @import("../Oid.zig");
const asn1 = @import("../../asn1.zig");
const ArrayListReverse = @import("./ArrayListReverse.zig");
const Tag = asn1.Tag;
const FieldTag = asn1.FieldTag;
const Encoder = @This();
