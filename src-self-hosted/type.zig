const std = @import("std");
const Value = @import("value.zig").Value;
const assert = std.debug.assert;

/// This is the raw data, with no bookkeeping, no memory awareness, no de-duplication.
/// It's important for this struct to be small.
/// It is not copyable since it may contain references to its inner data.
/// Types are not de-duplicated, which helps with multi-threading since it obviates the requirement
/// of obtaining a lock on a global type table, as well as making the
/// garbage collection bookkeeping simpler.
/// This union takes advantage of the fact that the first page of memory
/// is unmapped, giving us 4096 possible enum tags that have no payload.
pub const Type = extern union {
    /// If the tag value is less than Tag.no_payload_count, then no pointer
    /// dereference is needed.
    tag_if_small_enough: usize,
    ptr_otherwise: *Payload,

    pub fn zigTypeTag(self: Type) std.builtin.TypeId {
        switch (self.tag()) {
            .@"u8", .@"usize" => return .Int,
            .array_u8, .array_u8_sentinel_0 => return .Array,
            .single_const_pointer => return .Pointer,
        }
    }

    pub fn initTag(comptime small_tag: Tag) Type {
        comptime assert(@enumToInt(small_tag) < Tag.no_payload_count);
        return .{ .tag_if_small_enough = @enumToInt(small_tag) };
    }

    pub fn initPayload(payload: *Payload) Type {
        assert(@enumToInt(payload.tag) >= Tag.no_payload_count);
        return .{ .ptr_otherwise = payload };
    }

    pub fn tag(self: Type) Tag {
        if (self.tag_if_small_enough < Tag.no_payload_count) {
            return @intToEnum(Tag, @intCast(@TagType(Tag), self.tag_if_small_enough));
        } else {
            return self.ptr_otherwise.tag;
        }
    }

    pub fn format(
        self: Type,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        out_stream: var,
    ) !void {
        comptime assert(fmt.len == 0);
        var ty = self;
        while (true) {
            switch (ty.tag()) {
                @"u8",
                @"i8",
                @"isize",
                @"usize",
                @"noreturn",
                @"void",
                @"c_short",
                @"c_ushort",
                @"c_int",
                @"c_uint",
                @"c_long",
                @"c_ulong",
                @"c_longlong",
                @"c_ulonglong",
                @"c_longdouble",
                @"c_void",
                @"f16",
                @"f32",
                @"f64",
                @"f128",
                @"bool",
                @"void",
                @"type",
                @"anyerror",
                @"comptime_int",
                @"comptime_float",
                @"noreturn",
                => |t| return out_stream.writeAll(@tagName(t)),

                .array_u8_sentinel_0 => {
                    const payload = @fieldParentPtr(Payload.Array_u8_Sentinel0, "base", ty.ptr_otherwise);
                    return out_stream.print("[{}:0]u8", .{payload.len});
                },
                .array => {
                    const payload = @fieldParentPtr(Payload.Array, "base", ty.ptr_otherwise);
                    try out_stream.print("[{}]", .{payload.len});
                    ty = payload.elem_type;
                    continue;
                },
                .single_const_pointer => {
                    const payload = @fieldParentPtr(Payload.SingleConstPointer, "base", ty.ptr_otherwise);
                    try out_stream.writeAll("*const ");
                    ty = payload.pointee_type;
                    continue;
                },
            }
            unreachable;
        }
    }

    /// This enum does not directly correspond to `std.builtin.TypeId` because
    /// it has extra enum tags in it, as a way of using less memory. For example,
    /// even though Zig recognizes `*align(10) i32` and `*i32` both as Pointer types
    /// but with different alignment values, in this data structure they are represented
    /// with different enum tags, because the the former requires more payload data than the latter.
    /// See `zigTypeTag` for the function that corresponds to `std.builtin.TypeId`.
    pub const Tag = enum {
        // The first section of this enum are tags that require no payload.
        @"u8",
        @"i8",
        @"isize",
        @"usize",
        @"c_short",
        @"c_ushort",
        @"c_int",
        @"c_uint",
        @"c_long",
        @"c_ulong",
        @"c_longlong",
        @"c_ulonglong",
        @"c_longdouble",
        @"c_void",
        @"f16",
        @"f32",
        @"f64",
        @"f128",
        @"bool",
        @"void",
        @"type",
        @"anyerror",
        @"comptime_int",
        @"comptime_float",
        @"noreturn", // See last_no_payload_tag below.
        // After this, the tag requires a payload.

        array_u8_sentinel_0,
        array,
        single_const_pointer,

        pub const last_no_payload_tag = Tag.@"noreturn";
        pub const no_payload_count = @enumToInt(last_no_payload_tag) + 1;
    };

    pub const Payload = struct {
        tag: Tag,

        pub const Array_u8_Sentinel0 = struct {
            base: Payload = Payload{ .tag = .array_u8_sentinel_0 },

            len: u64,
        };

        pub const Array = struct {
            base: Payload = Payload{ .tag = .array },

            elem_type: Type,
            len: u64,
        };

        pub const SingleConstPointer = struct {
            base: Payload = Payload{ .tag = .single_const_pointer },

            pointee_type: Type,
        };
    };
};
