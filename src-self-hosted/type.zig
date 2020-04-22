const std = @import("std");
const Value = @import("value.zig").Value;
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const Target = std.Target;

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
            .@"u8",
            .@"i8",
            .@"isize",
            .@"usize",
            .@"c_short",
            .@"c_ushort",
            .@"c_int",
            .@"c_uint",
            .@"c_long",
            .@"c_ulong",
            .@"c_longlong",
            .@"c_ulonglong",
            .@"c_longdouble",
            => return .Int,

            .@"f16",
            .@"f32",
            .@"f64",
            .@"f128",
            => return .Float,

            .@"c_void" => return .Opaque,
            .@"bool" => return .Bool,
            .@"void" => return .Void,
            .@"type" => return .Type,
            .@"anyerror" => return .ErrorSet,
            .@"comptime_int" => return .ComptimeInt,
            .@"comptime_float" => return .ComptimeFloat,
            .@"noreturn" => return .NoReturn,

            .fn_naked_noreturn_no_args => return .Fn,

            .array, .array_u8_sentinel_0 => return .Array,
            .single_const_pointer => return .Pointer,
            .single_const_pointer_to_comptime_int => return .Pointer,
            .const_slice_u8 => return .Pointer,
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

    pub fn cast(self: Type, comptime T: type) ?*T {
        if (self.tag_if_small_enough < Tag.no_payload_count)
            return null;

        const expected_tag = std.meta.fieldInfo(T, "base").default_value.?.tag;
        if (self.ptr_otherwise.tag != expected_tag)
            return null;

        return @fieldParentPtr(T, "base", self.ptr_otherwise);
    }

    pub fn eql(self: Type, other: Type) bool {
        //std.debug.warn("test {} == {}\n", .{ self, other });
        // As a shortcut, if the small tags / addresses match, we're done.
        if (self.tag_if_small_enough == other.tag_if_small_enough)
            return true;
        const zig_tag_a = self.zigTypeTag();
        const zig_tag_b = self.zigTypeTag();
        if (zig_tag_a != zig_tag_b)
            return false;
        switch (zig_tag_a) {
            .Type => return true,
            .Void => return true,
            .Bool => return true,
            .NoReturn => return true,
            .ComptimeFloat => return true,
            .ComptimeInt => return true,
            .Undefined => return true,
            .Null => return true,
            .Pointer => {
                const is_slice_a = isSlice(self);
                const is_slice_b = isSlice(other);
                if (is_slice_a != is_slice_b)
                    return false;
                @panic("TODO implement more pointer Type equality comparison");
            },
            .Int => {
                if (self.tag() != other.tag()) {
                    // Detect that e.g. u64 != usize, even if the bits match on a particular target.
                    return false;
                }
                // The target will not be branched upon, because we handled target-dependent cases above.
                const info_a = self.intInfo(@as(Target, undefined));
                const info_b = self.intInfo(@as(Target, undefined));
                return info_a.signed == info_b.signed and info_a.bits == info_b.bits;
            },
            .Float,
            .Array,
            .Struct,
            .Optional,
            .ErrorUnion,
            .ErrorSet,
            .Enum,
            .Union,
            .Fn,
            .BoundFn,
            .Opaque,
            .Frame,
            .AnyFrame,
            .Vector,
            .EnumLiteral,
            => @panic("TODO implement more Type equality comparison"),
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
            const t = ty.tag();
            switch (t) {
                .@"u8",
                .@"i8",
                .@"isize",
                .@"usize",
                .@"c_short",
                .@"c_ushort",
                .@"c_int",
                .@"c_uint",
                .@"c_long",
                .@"c_ulong",
                .@"c_longlong",
                .@"c_ulonglong",
                .@"c_longdouble",
                .@"c_void",
                .@"f16",
                .@"f32",
                .@"f64",
                .@"f128",
                .@"bool",
                .@"void",
                .@"type",
                .@"anyerror",
                .@"comptime_int",
                .@"comptime_float",
                .@"noreturn",
                => return out_stream.writeAll(@tagName(t)),

                .const_slice_u8 => return out_stream.writeAll("[]const u8"),
                .fn_naked_noreturn_no_args => return out_stream.writeAll("fn() callconv(.Naked) noreturn"),
                .single_const_pointer_to_comptime_int => return out_stream.writeAll("*const comptime_int"),

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

    pub fn toValue(self: Type, allocator: *Allocator) Allocator.Error!Value {
        switch (self.tag()) {
            .@"u8" => return Value.initTag(.u8_type),
            .@"i8" => return Value.initTag(.i8_type),
            .@"isize" => return Value.initTag(.isize_type),
            .@"usize" => return Value.initTag(.usize_type),
            .@"c_short" => return Value.initTag(.c_short_type),
            .@"c_ushort" => return Value.initTag(.c_ushort_type),
            .@"c_int" => return Value.initTag(.c_int_type),
            .@"c_uint" => return Value.initTag(.c_uint_type),
            .@"c_long" => return Value.initTag(.c_long_type),
            .@"c_ulong" => return Value.initTag(.c_ulong_type),
            .@"c_longlong" => return Value.initTag(.c_longlong_type),
            .@"c_ulonglong" => return Value.initTag(.c_ulonglong_type),
            .@"c_longdouble" => return Value.initTag(.c_longdouble_type),
            .@"c_void" => return Value.initTag(.c_void_type),
            .@"f16" => return Value.initTag(.f16_type),
            .@"f32" => return Value.initTag(.f32_type),
            .@"f64" => return Value.initTag(.f64_type),
            .@"f128" => return Value.initTag(.f128_type),
            .@"bool" => return Value.initTag(.bool_type),
            .@"void" => return Value.initTag(.void_type),
            .@"type" => return Value.initTag(.type_type),
            .@"anyerror" => return Value.initTag(.anyerror_type),
            .@"comptime_int" => return Value.initTag(.comptime_int_type),
            .@"comptime_float" => return Value.initTag(.comptime_float_type),
            .@"noreturn" => return Value.initTag(.noreturn_type),
            .fn_naked_noreturn_no_args => return Value.initTag(.fn_naked_noreturn_no_args_type),
            .single_const_pointer_to_comptime_int => return Value.initTag(.single_const_pointer_to_comptime_int_type),
            .const_slice_u8 => return Value.initTag(.const_slice_u8_type),
            else => {
                const ty_payload = try allocator.create(Value.Payload.Ty);
                ty_payload.* = .{ .ty = self };
                return Value.initPayload(&ty_payload.base);
            },
        }
    }

    pub fn isSinglePointer(self: Type) bool {
        return switch (self.tag()) {
            .@"u8",
            .@"i8",
            .@"isize",
            .@"usize",
            .@"c_short",
            .@"c_ushort",
            .@"c_int",
            .@"c_uint",
            .@"c_long",
            .@"c_ulong",
            .@"c_longlong",
            .@"c_ulonglong",
            .@"c_longdouble",
            .@"f16",
            .@"f32",
            .@"f64",
            .@"f128",
            .@"c_void",
            .@"bool",
            .@"void",
            .@"type",
            .@"anyerror",
            .@"comptime_int",
            .@"comptime_float",
            .@"noreturn",
            .array,
            .array_u8_sentinel_0,
            .const_slice_u8,
            .fn_naked_noreturn_no_args,
            => false,

            .single_const_pointer,
            .single_const_pointer_to_comptime_int,
            => true,
        };
    }

    pub fn isSlice(self: Type) bool {
        return switch (self.tag()) {
            .@"u8",
            .@"i8",
            .@"isize",
            .@"usize",
            .@"c_short",
            .@"c_ushort",
            .@"c_int",
            .@"c_uint",
            .@"c_long",
            .@"c_ulong",
            .@"c_longlong",
            .@"c_ulonglong",
            .@"c_longdouble",
            .@"f16",
            .@"f32",
            .@"f64",
            .@"f128",
            .@"c_void",
            .@"bool",
            .@"void",
            .@"type",
            .@"anyerror",
            .@"comptime_int",
            .@"comptime_float",
            .@"noreturn",
            .array,
            .array_u8_sentinel_0,
            .single_const_pointer,
            .single_const_pointer_to_comptime_int,
            .fn_naked_noreturn_no_args,
            => false,

            .const_slice_u8 => true,
        };
    }

    /// Asserts the type is a pointer type.
    pub fn pointerIsConst(self: Type) bool {
        return switch (self.tag()) {
            .@"u8",
            .@"i8",
            .@"isize",
            .@"usize",
            .@"c_short",
            .@"c_ushort",
            .@"c_int",
            .@"c_uint",
            .@"c_long",
            .@"c_ulong",
            .@"c_longlong",
            .@"c_ulonglong",
            .@"c_longdouble",
            .@"f16",
            .@"f32",
            .@"f64",
            .@"f128",
            .@"c_void",
            .@"bool",
            .@"void",
            .@"type",
            .@"anyerror",
            .@"comptime_int",
            .@"comptime_float",
            .@"noreturn",
            .array,
            .array_u8_sentinel_0,
            .fn_naked_noreturn_no_args,
            => unreachable,

            .single_const_pointer,
            .single_const_pointer_to_comptime_int,
            .const_slice_u8,
            => true,
        };
    }

    /// Asserts the type is a pointer or array type.
    pub fn elemType(self: Type) Type {
        return switch (self.tag()) {
            .@"u8",
            .@"i8",
            .@"isize",
            .@"usize",
            .@"c_short",
            .@"c_ushort",
            .@"c_int",
            .@"c_uint",
            .@"c_long",
            .@"c_ulong",
            .@"c_longlong",
            .@"c_ulonglong",
            .@"c_longdouble",
            .@"f16",
            .@"f32",
            .@"f64",
            .@"f128",
            .@"c_void",
            .@"bool",
            .@"void",
            .@"type",
            .@"anyerror",
            .@"comptime_int",
            .@"comptime_float",
            .@"noreturn",
            .fn_naked_noreturn_no_args,
            => unreachable,

            .array => self.cast(Payload.Array).?.elem_type,
            .single_const_pointer => self.cast(Payload.SingleConstPointer).?.pointee_type,
            .array_u8_sentinel_0, .const_slice_u8 => Type.initTag(.u8),
            .single_const_pointer_to_comptime_int => Type.initTag(.comptime_int),
        };
    }

    /// Asserts the type is an array.
    pub fn arrayLen(self: Type) u64 {
        return switch (self.tag()) {
            .u8,
            .i8,
            .isize,
            .usize,
            .c_short,
            .c_ushort,
            .c_int,
            .c_uint,
            .c_long,
            .c_ulong,
            .c_longlong,
            .c_ulonglong,
            .c_longdouble,
            .f16,
            .f32,
            .f64,
            .f128,
            .c_void,
            .bool,
            .void,
            .type,
            .anyerror,
            .comptime_int,
            .comptime_float,
            .noreturn,
            .fn_naked_noreturn_no_args,
            .single_const_pointer,
            .single_const_pointer_to_comptime_int,
            .const_slice_u8,
            => unreachable,

            .array => self.cast(Payload.Array).?.len,
            .array_u8_sentinel_0 => self.cast(Payload.Array_u8_Sentinel0).?.len,
        };
    }

    /// Asserts the type is a fixed-width integer.
    pub fn intInfo(self: Type, target: Target) struct { signed: bool, bits: u16 } {
        return switch (self.tag()) {
            .@"f16",
            .@"f32",
            .@"f64",
            .@"f128",
            .@"c_longdouble",
            .@"c_void",
            .@"bool",
            .@"void",
            .@"type",
            .@"anyerror",
            .@"comptime_int",
            .@"comptime_float",
            .@"noreturn",
            .fn_naked_noreturn_no_args,
            .array,
            .single_const_pointer,
            .single_const_pointer_to_comptime_int,
            .array_u8_sentinel_0,
            .const_slice_u8,
            => unreachable,

            .@"u8" => .{ .signed = false, .bits = 8 },
            .@"i8" => .{ .signed = true, .bits = 8 },
            .@"usize" => .{ .signed = false, .bits = target.cpu.arch.ptrBitWidth() },
            .@"isize" => .{ .signed = true, .bits = target.cpu.arch.ptrBitWidth() },
            .@"c_short" => .{ .signed = true, .bits = CInteger.short.sizeInBits(target) },
            .@"c_ushort" => .{ .signed = false, .bits = CInteger.ushort.sizeInBits(target) },
            .@"c_int" => .{ .signed = true, .bits = CInteger.int.sizeInBits(target) },
            .@"c_uint" => .{ .signed = false, .bits = CInteger.uint.sizeInBits(target) },
            .@"c_long" => .{ .signed = true, .bits = CInteger.long.sizeInBits(target) },
            .@"c_ulong" => .{ .signed = false, .bits = CInteger.ulong.sizeInBits(target) },
            .@"c_longlong" => .{ .signed = true, .bits = CInteger.longlong.sizeInBits(target) },
            .@"c_ulonglong" => .{ .signed = false, .bits = CInteger.ulonglong.sizeInBits(target) },
        };
    }

    /// Asserts the type is a function.
    pub fn fnParamLen(self: Type) usize {
        return switch (self.tag()) {
            .fn_naked_noreturn_no_args => 0,

            .f16,
            .f32,
            .f64,
            .f128,
            .c_longdouble,
            .c_void,
            .bool,
            .void,
            .type,
            .anyerror,
            .comptime_int,
            .comptime_float,
            .noreturn,
            .array,
            .single_const_pointer,
            .single_const_pointer_to_comptime_int,
            .array_u8_sentinel_0,
            .const_slice_u8,
            .u8,
            .i8,
            .usize,
            .isize,
            .c_short,
            .c_ushort,
            .c_int,
            .c_uint,
            .c_long,
            .c_ulong,
            .c_longlong,
            .c_ulonglong,
            => unreachable,
        };
    }

    /// Asserts the type is a function. The length of the slice must be at least the length
    /// given by `fnParamLen`.
    pub fn fnParamTypes(self: Type, types: []Type) void {
        switch (self.tag()) {
            .fn_naked_noreturn_no_args => return,

            .f16,
            .f32,
            .f64,
            .f128,
            .c_longdouble,
            .c_void,
            .bool,
            .void,
            .type,
            .anyerror,
            .comptime_int,
            .comptime_float,
            .noreturn,
            .array,
            .single_const_pointer,
            .single_const_pointer_to_comptime_int,
            .array_u8_sentinel_0,
            .const_slice_u8,
            .u8,
            .i8,
            .usize,
            .isize,
            .c_short,
            .c_ushort,
            .c_int,
            .c_uint,
            .c_long,
            .c_ulong,
            .c_longlong,
            .c_ulonglong,
            => unreachable,
        }
    }

    /// Asserts the type is a function.
    pub fn fnReturnType(self: Type) Type {
        return switch (self.tag()) {
            .fn_naked_noreturn_no_args => Type.initTag(.noreturn),

            .f16,
            .f32,
            .f64,
            .f128,
            .c_longdouble,
            .c_void,
            .bool,
            .void,
            .type,
            .anyerror,
            .comptime_int,
            .comptime_float,
            .noreturn,
            .array,
            .single_const_pointer,
            .single_const_pointer_to_comptime_int,
            .array_u8_sentinel_0,
            .const_slice_u8,
            .u8,
            .i8,
            .usize,
            .isize,
            .c_short,
            .c_ushort,
            .c_int,
            .c_uint,
            .c_long,
            .c_ulong,
            .c_longlong,
            .c_ulonglong,
            => unreachable,
        };
    }

    /// Asserts the type is a function.
    pub fn fnCallingConvention(self: Type) std.builtin.CallingConvention {
        return switch (self.tag()) {
            .fn_naked_noreturn_no_args => .Naked,

            .f16,
            .f32,
            .f64,
            .f128,
            .c_longdouble,
            .c_void,
            .bool,
            .void,
            .type,
            .anyerror,
            .comptime_int,
            .comptime_float,
            .noreturn,
            .array,
            .single_const_pointer,
            .single_const_pointer_to_comptime_int,
            .array_u8_sentinel_0,
            .const_slice_u8,
            .u8,
            .i8,
            .usize,
            .isize,
            .c_short,
            .c_ushort,
            .c_int,
            .c_uint,
            .c_long,
            .c_ulong,
            .c_longlong,
            .c_ulonglong,
            => unreachable,
        };
    }

    /// This enum does not directly correspond to `std.builtin.TypeId` because
    /// it has extra enum tags in it, as a way of using less memory. For example,
    /// even though Zig recognizes `*align(10) i32` and `*i32` both as Pointer types
    /// but with different alignment values, in this data structure they are represented
    /// with different enum tags, because the the former requires more payload data than the latter.
    /// See `zigTypeTag` for the function that corresponds to `std.builtin.TypeId`.
    pub const Tag = enum {
        // The first section of this enum are tags that require no payload.
        u8,
        i8,
        isize,
        usize,
        c_short,
        c_ushort,
        c_int,
        c_uint,
        c_long,
        c_ulong,
        c_longlong,
        c_ulonglong,
        c_longdouble,
        c_void,
        f16,
        f32,
        f64,
        f128,
        bool,
        void,
        type,
        anyerror,
        comptime_int,
        comptime_float,
        noreturn,
        fn_naked_noreturn_no_args,
        single_const_pointer_to_comptime_int,
        const_slice_u8, // See last_no_payload_tag below.
        // After this, the tag requires a payload.

        array_u8_sentinel_0,
        array,
        single_const_pointer,

        pub const last_no_payload_tag = Tag.const_slice_u8;
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

pub const CInteger = enum {
    short,
    ushort,
    int,
    uint,
    long,
    ulong,
    longlong,
    ulonglong,

    pub fn sizeInBits(self: CInteger, target: Target) u16 {
        const arch = target.cpu.arch;
        switch (target.os.tag) {
            .freestanding, .other => switch (target.cpu.arch) {
                .msp430 => switch (self) {
                    .short,
                    .ushort,
                    .int,
                    .uint,
                    => return 16,
                    .long,
                    .ulong,
                    => return 32,
                    .longlong,
                    .ulonglong,
                    => return 64,
                },
                else => switch (self) {
                    .short,
                    .ushort,
                    => return 16,
                    .int,
                    .uint,
                    => return 32,
                    .long,
                    .ulong,
                    => return target.cpu.arch.ptrBitWidth(),
                    .longlong,
                    .ulonglong,
                    => return 64,
                },
            },

            .linux,
            .macosx,
            .freebsd,
            .netbsd,
            .dragonfly,
            .openbsd,
            .wasi,
            .emscripten,
            => switch (self) {
                .short,
                .ushort,
                => return 16,
                .int,
                .uint,
                => return 32,
                .long,
                .ulong,
                => return target.cpu.arch.ptrBitWidth(),
                .longlong,
                .ulonglong,
                => return 64,
            },

            .windows, .uefi => switch (self) {
                .short,
                .ushort,
                => return 16,
                .int,
                .uint,
                .long,
                .ulong,
                => return 32,
                .longlong,
                .ulonglong,
                => return 64,
            },

            .ios => switch (self) {
                .short,
                .ushort,
                => return 16,
                .int,
                .uint,
                => return 32,
                .long,
                .ulong,
                .longlong,
                .ulonglong,
                => return 64,
            },

            .ananas,
            .cloudabi,
            .fuchsia,
            .kfreebsd,
            .lv2,
            .solaris,
            .haiku,
            .minix,
            .rtems,
            .nacl,
            .cnk,
            .aix,
            .cuda,
            .nvcl,
            .amdhsa,
            .ps4,
            .elfiamcu,
            .tvos,
            .watchos,
            .mesa3d,
            .contiki,
            .amdpal,
            .hermit,
            .hurd,
            => @panic("TODO specify the C integer type sizes for this OS"),
        }
    }
};
