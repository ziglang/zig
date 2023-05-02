//! All interned objects have both a value and a type.

map: std.AutoArrayHashMapUnmanaged(void, void) = .{},
items: std.MultiArrayList(Item) = .{},
extra: std.ArrayListUnmanaged(u32) = .{},

const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const BigIntConst = std.math.big.int.Const;

const InternPool = @This();
const DeclIndex = enum(u32) { _ };

const KeyAdapter = struct {
    intern_pool: *const InternPool,

    pub fn eql(ctx: @This(), a: Key, b_void: void, b_map_index: usize) bool {
        _ = b_void;
        return ctx.intern_pool.indexToKey(@intToEnum(Index, b_map_index)).eql(a);
    }

    pub fn hash(ctx: @This(), a: Key) u32 {
        _ = ctx;
        return a.hash32();
    }
};

pub const Key = union(enum) {
    int_type: IntType,
    ptr_type: struct {
        elem_type: Index,
        sentinel: Index = .none,
        alignment: u16 = 0,
        size: std.builtin.Type.Pointer.Size,
        is_const: bool = false,
        is_volatile: bool = false,
        is_allowzero: bool = false,
        address_space: std.builtin.AddressSpace = .generic,
    },
    array_type: struct {
        len: u64,
        child: Index,
        sentinel: Index,
    },
    vector_type: struct {
        len: u32,
        child: Index,
    },
    optional_type: struct {
        payload_type: Index,
    },
    error_union_type: struct {
        error_set_type: Index,
        payload_type: Index,
    },
    simple_type: SimpleType,
    simple_value: SimpleValue,
    extern_func: struct {
        ty: Index,
        /// The Decl that corresponds to the function itself.
        owner_decl: DeclIndex,
        /// Library name if specified.
        /// For example `extern "c" fn write(...) usize` would have 'c' as library name.
        /// Index into the string table bytes.
        lib_name: u32,
    },
    int: struct {
        ty: Index,
        big_int: BigIntConst,
    },
    enum_tag: struct {
        ty: Index,
        tag: BigIntConst,
    },
    struct_type: struct {
        fields_len: u32,
        // TODO move Module.Struct data to here
    },

    pub const IntType = std.builtin.Type.Int;

    pub fn hash32(key: Key) u32 {
        return @truncate(u32, key.hash64());
    }

    pub fn hash64(key: Key) u64 {
        var hasher = std.hash.Wyhash.init(0);
        key.hashWithHasher(&hasher);
        return hasher.final();
    }

    pub fn hashWithHasher(key: Key, hasher: *std.hash.Wyhash) void {
        switch (key) {
            .int_type => |int_type| {
                std.hash.autoHash(hasher, int_type);
            },
            .array_type => |array_type| {
                std.hash.autoHash(hasher, array_type);
            },
            else => @panic("TODO"),
        }
    }

    pub fn eql(a: Key, b: Key) bool {
        const KeyTag = std.meta.Tag(Key);
        const a_tag: KeyTag = a;
        const b_tag: KeyTag = b;
        if (a_tag != b_tag) return false;
        switch (a) {
            .int_type => |a_info| {
                const b_info = b.int_type;
                return std.meta.eql(a_info, b_info);
            },
            .array_type => |a_info| {
                const b_info = b.array_type;
                return std.meta.eql(a_info, b_info);
            },
            else => @panic("TODO"),
        }
    }

    pub fn typeOf(key: Key) Index {
        switch (key) {
            .int_type,
            .ptr_type,
            .array_type,
            .vector_type,
            .optional_type,
            .error_union_type,
            .simple_type,
            .struct_type,
            => return .type_type,

            .int => |x| return x.ty,
            .extern_func => |x| return x.ty,
            .enum_tag => |x| return x.ty,

            .simple_value => |s| switch (s) {
                .undefined => return .undefined_type,
                .void => return .void_type,
                .null => return .null_type,
                .false, .true => return .bool_type,
                .empty_struct => return .empty_struct_type,
                .@"unreachable" => return .noreturn_type,
                .generic_poison => unreachable,
            },
        }
    }
};

pub const Item = struct {
    tag: Tag,
    /// The doc comments on the respective Tag explain how to interpret this.
    data: u32,
};

/// Represents an index into `map`. It represents the canonical index
/// of a `Value` within this `InternPool`. The values are typed.
/// Two values which have the same type can be equality compared simply
/// by checking if their indexes are equal, provided they are both in
/// the same `InternPool`.
/// When adding a tag to this enum, consider adding a corresponding entry to
/// `primitives` in AstGen.zig.
pub const Index = enum(u32) {
    u1_type,
    u8_type,
    i8_type,
    u16_type,
    i16_type,
    u29_type,
    u32_type,
    i32_type,
    u64_type,
    i64_type,
    u80_type,
    u128_type,
    i128_type,
    usize_type,
    isize_type,
    c_char_type,
    c_short_type,
    c_ushort_type,
    c_int_type,
    c_uint_type,
    c_long_type,
    c_ulong_type,
    c_longlong_type,
    c_ulonglong_type,
    c_longdouble_type,
    f16_type,
    f32_type,
    f64_type,
    f80_type,
    f128_type,
    anyopaque_type,
    bool_type,
    void_type,
    type_type,
    anyerror_type,
    comptime_int_type,
    comptime_float_type,
    noreturn_type,
    anyframe_type,
    null_type,
    undefined_type,
    enum_literal_type,
    atomic_order_type,
    atomic_rmw_op_type,
    calling_convention_type,
    address_space_type,
    float_mode_type,
    reduce_op_type,
    call_modifier_type,
    prefetch_options_type,
    export_options_type,
    extern_options_type,
    type_info_type,
    manyptr_u8_type,
    manyptr_const_u8_type,
    single_const_pointer_to_comptime_int_type,
    const_slice_u8_type,
    anyerror_void_error_union_type,
    generic_poison_type,
    var_args_param_type,
    empty_struct_type,

    /// `undefined` (untyped)
    undef,
    /// `0` (comptime_int)
    zero,
    /// `0` (usize)
    zero_usize,
    /// `1` (comptime_int)
    one,
    /// `1` (usize)
    one_usize,
    /// `std.builtin.CallingConvention.C`
    calling_convention_c,
    /// `std.builtin.CallingConvention.Inline`
    calling_convention_inline,
    /// `{}`
    void_value,
    /// `unreachable` (noreturn type)
    unreachable_value,
    /// `null` (untyped)
    null_value,
    /// `true`
    bool_true,
    /// `false`
    bool_false,
    /// `.{}` (untyped)
    empty_struct,
    /// Used for generic parameters where the type and value
    /// is not known until generic function instantiation.
    generic_poison,

    none = std.math.maxInt(u32),

    _,

    pub fn toType(i: Index) @import("type.zig").Type {
        assert(i != .none);
        return .{
            .ip_index = i,
            .legacy = undefined,
        };
    }

    pub fn toValue(i: Index) @import("value.zig").Value {
        assert(i != .none);
        return .{
            .ip_index = i,
            .legacy = undefined,
        };
    }
};

pub const static_keys = [_]Key{
    .{ .int_type = .{
        .signedness = .unsigned,
        .bits = 1,
    } },

    .{ .int_type = .{
        .signedness = .unsigned,
        .bits = 8,
    } },

    .{ .int_type = .{
        .signedness = .signed,
        .bits = 8,
    } },

    .{ .int_type = .{
        .signedness = .unsigned,
        .bits = 16,
    } },

    .{ .int_type = .{
        .signedness = .signed,
        .bits = 16,
    } },

    .{ .int_type = .{
        .signedness = .unsigned,
        .bits = 29,
    } },

    .{ .int_type = .{
        .signedness = .unsigned,
        .bits = 32,
    } },

    .{ .int_type = .{
        .signedness = .signed,
        .bits = 32,
    } },

    .{ .int_type = .{
        .signedness = .unsigned,
        .bits = 64,
    } },

    .{ .int_type = .{
        .signedness = .signed,
        .bits = 64,
    } },

    .{ .int_type = .{
        .signedness = .unsigned,
        .bits = 80,
    } },

    .{ .int_type = .{
        .signedness = .unsigned,
        .bits = 128,
    } },

    .{ .int_type = .{
        .signedness = .signed,
        .bits = 128,
    } },

    .{ .simple_type = .usize },
    .{ .simple_type = .isize },
    .{ .simple_type = .c_char },
    .{ .simple_type = .c_short },
    .{ .simple_type = .c_ushort },
    .{ .simple_type = .c_int },
    .{ .simple_type = .c_uint },
    .{ .simple_type = .c_long },
    .{ .simple_type = .c_ulong },
    .{ .simple_type = .c_longlong },
    .{ .simple_type = .c_ulonglong },
    .{ .simple_type = .c_longdouble },
    .{ .simple_type = .f16 },
    .{ .simple_type = .f32 },
    .{ .simple_type = .f64 },
    .{ .simple_type = .f80 },
    .{ .simple_type = .f128 },
    .{ .simple_type = .anyopaque },
    .{ .simple_type = .bool },
    .{ .simple_type = .void },
    .{ .simple_type = .type },
    .{ .simple_type = .anyerror },
    .{ .simple_type = .comptime_int },
    .{ .simple_type = .comptime_float },
    .{ .simple_type = .noreturn },
    .{ .simple_type = .@"anyframe" },
    .{ .simple_type = .null },
    .{ .simple_type = .undefined },
    .{ .simple_type = .enum_literal },
    .{ .simple_type = .atomic_order },
    .{ .simple_type = .atomic_rmw_op },
    .{ .simple_type = .calling_convention },
    .{ .simple_type = .address_space },
    .{ .simple_type = .float_mode },
    .{ .simple_type = .reduce_op },
    .{ .simple_type = .call_modifier },
    .{ .simple_type = .prefetch_options },
    .{ .simple_type = .export_options },
    .{ .simple_type = .extern_options },
    .{ .simple_type = .type_info },

    .{ .ptr_type = .{
        .elem_type = .u8_type,
        .size = .Many,
    } },

    .{ .ptr_type = .{
        .elem_type = .u8_type,
        .size = .Many,
        .is_const = true,
    } },

    .{ .ptr_type = .{
        .elem_type = .comptime_int_type,
        .size = .One,
        .is_const = true,
    } },

    .{ .ptr_type = .{
        .elem_type = .u8_type,
        .size = .Slice,
        .is_const = true,
    } },

    .{ .error_union_type = .{
        .error_set_type = .anyerror_type,
        .payload_type = .void_type,
    } },

    // generic_poison_type
    .{ .simple_type = .generic_poison },

    // var_args_param_type
    .{ .simple_type = .var_args_param },

    // empty_struct_type
    .{ .struct_type = .{
        .fields_len = 0,
    } },

    .{ .simple_value = .undefined },

    .{ .int = .{
        .ty = .comptime_int_type,
        .big_int = .{
            .limbs = &.{0},
            .positive = true,
        },
    } },

    .{ .int = .{
        .ty = .usize_type,
        .big_int = .{
            .limbs = &.{0},
            .positive = true,
        },
    } },

    .{ .int = .{
        .ty = .comptime_int_type,
        .big_int = .{
            .limbs = &.{1},
            .positive = true,
        },
    } },

    .{ .int = .{
        .ty = .usize_type,
        .big_int = .{
            .limbs = &.{1},
            .positive = true,
        },
    } },

    .{ .enum_tag = .{
        .ty = .calling_convention_type,
        .tag = .{
            .limbs = &.{@enumToInt(std.builtin.CallingConvention.C)},
            .positive = true,
        },
    } },

    .{ .enum_tag = .{
        .ty = .calling_convention_type,
        .tag = .{
            .limbs = &.{@enumToInt(std.builtin.CallingConvention.Inline)},
            .positive = true,
        },
    } },

    .{ .simple_value = .void },
    .{ .simple_value = .@"unreachable" },
    .{ .simple_value = .null },
    .{ .simple_value = .true },
    .{ .simple_value = .false },
    .{ .simple_value = .empty_struct },
    .{ .simple_value = .generic_poison },
};

/// How many items in the InternPool are statically known.
pub const static_len: u32 = static_keys.len;

pub const Tag = enum(u8) {
    /// An integer type.
    /// data is number of bits
    type_int_signed,
    /// An integer type.
    /// data is number of bits
    type_int_unsigned,
    /// An array type.
    /// data is payload to Array.
    type_array,
    /// A type that can be represented with only an enum tag.
    /// data is SimpleType enum value.
    simple_type,
    /// A value that can be represented with only an enum tag.
    /// data is SimpleValue enum value.
    simple_value,
    /// An unsigned integer value that can be represented by u32.
    /// data is integer value
    int_u32,
    /// An unsigned integer value that can be represented by i32.
    /// data is integer value bitcasted to u32.
    int_i32,
    /// A positive integer value that does not fit in 32 bits.
    /// data is a extra index to BigInt.
    int_big_positive,
    /// A negative integer value that does not fit in 32 bits.
    /// data is a extra index to BigInt.
    int_big_negative,
    /// A float value that can be represented by f32.
    /// data is float value bitcasted to u32.
    float_f32,
    /// A float value that can be represented by f64.
    /// data is payload index to Float64.
    float_f64,
    /// A float value that can be represented by f128.
    /// data is payload index to Float128.
    float_f128,
    /// An extern function.
    extern_func,
    /// A regular function.
    func,
    /// Represents the data that an enum declaration provides, when the fields
    /// are auto-numbered, and there are no declarations.
    /// data is payload index to `EnumSimple`.
    enum_simple,
};

/// Having `SimpleType` and `SimpleValue` in separate enums makes it easier to
/// implement logic that only wants to deal with types because the logic can
/// ignore all simple values. Note that technically, types are values.
pub const SimpleType = enum(u32) {
    f16,
    f32,
    f64,
    f80,
    f128,
    usize,
    isize,
    c_char,
    c_short,
    c_ushort,
    c_int,
    c_uint,
    c_long,
    c_ulong,
    c_longlong,
    c_ulonglong,
    c_longdouble,
    anyopaque,
    bool,
    void,
    type,
    anyerror,
    comptime_int,
    comptime_float,
    noreturn,
    @"anyframe",
    null,
    undefined,
    enum_literal,

    atomic_order,
    atomic_rmw_op,
    calling_convention,
    address_space,
    float_mode,
    reduce_op,
    call_modifier,
    prefetch_options,
    export_options,
    extern_options,
    type_info,

    generic_poison,
    var_args_param,
};

pub const SimpleValue = enum(u32) {
    undefined,
    void,
    null,
    empty_struct,
    true,
    false,
    @"unreachable",

    generic_poison,
};

pub const Array = struct {
    len: u32,
    child: Index,
};

/// Trailing:
/// 0. field name: null-terminated string index for each fields_len; declaration order
pub const EnumSimple = struct {
    /// The Decl that corresponds to the enum itself.
    owner_decl: DeclIndex,
    /// An integer type which is used for the numerical value of the enum. This
    /// is inferred by Zig to be the smallest power of two unsigned int that
    /// fits the number of fields. It is stored here to avoid unnecessary
    /// calculations and possibly allocation failure when querying the tag type
    /// of enums.
    int_tag_ty: Index,
    fields_len: u32,
};

pub fn init(ip: *InternPool, gpa: Allocator) !void {
    assert(ip.items.len == 0);

    // So that we can use `catch unreachable` below.
    try ip.items.ensureUnusedCapacity(gpa, static_keys.len);
    try ip.map.ensureUnusedCapacity(gpa, static_keys.len);
    try ip.extra.ensureUnusedCapacity(gpa, static_keys.len);

    // This inserts all the statically-known values into the intern pool in the
    // order expected.
    for (static_keys) |key| _ = ip.get(gpa, key) catch unreachable;

    // Sanity check.
    assert(ip.indexToKey(.bool_true).simple_value == .true);
    assert(ip.indexToKey(.bool_false).simple_value == .false);

    assert(ip.items.len == static_keys.len);
}

pub fn deinit(ip: *InternPool, gpa: Allocator) void {
    ip.map.deinit(gpa);
    ip.items.deinit(gpa);
    ip.extra.deinit(gpa);
    ip.* = undefined;
}

pub fn indexToKey(ip: InternPool, index: Index) Key {
    const item = ip.items.get(@enumToInt(index));
    const data = item.data;
    return switch (item.tag) {
        .type_int_signed => .{
            .int_type = .{
                .signedness = .signed,
                .bits = @intCast(u16, data),
            },
        },
        .type_int_unsigned => .{
            .int_type = .{
                .signedness = .unsigned,
                .bits = @intCast(u16, data),
            },
        },
        .type_array => {
            const array_info = ip.extraData(Array, data);
            return .{ .array_type = .{
                .len = array_info.len,
                .child = array_info.child,
                .sentinel = .none,
            } };
        },
        .simple_type => .{ .simple_type = @intToEnum(SimpleType, data) },
        .simple_value => .{ .simple_value = @intToEnum(SimpleValue, data) },

        else => @panic("TODO"),
    };
}

pub fn get(ip: *InternPool, gpa: Allocator, key: Key) Allocator.Error!Index {
    const adapter: KeyAdapter = .{ .intern_pool = ip };
    const gop = try ip.map.getOrPutAdapted(gpa, key, adapter);
    if (gop.found_existing) {
        return @intToEnum(Index, gop.index);
    }
    switch (key) {
        .int_type => |int_type| {
            const t: Tag = switch (int_type.signedness) {
                .signed => .type_int_signed,
                .unsigned => .type_int_unsigned,
            };
            try ip.items.append(gpa, .{
                .tag = t,
                .data = int_type.bits,
            });
        },
        .array_type => |array_type| {
            const len = @intCast(u32, array_type.len); // TODO have a big_array encoding
            assert(array_type.sentinel == .none); // TODO have a sentinel_array encoding
            try ip.items.append(gpa, .{
                .tag = .type_array,
                .data = try ip.addExtra(gpa, Array{
                    .len = len,
                    .child = array_type.child,
                }),
            });
        },
        else => @panic("TODO"),
    }
    return @intToEnum(Index, ip.items.len - 1);
}

pub fn tag(ip: InternPool, index: Index) Tag {
    const tags = ip.items.items(.tag);
    return tags[@enumToInt(index)];
}

fn addExtra(ip: *InternPool, gpa: Allocator, extra: anytype) Allocator.Error!u32 {
    const fields = std.meta.fields(@TypeOf(extra));
    try ip.extra.ensureUnusedCapacity(gpa, fields.len);
    return ip.addExtraAssumeCapacity(extra);
}

fn addExtraAssumeCapacity(ip: *InternPool, extra: anytype) u32 {
    const fields = std.meta.fields(@TypeOf(extra));
    const result = @intCast(u32, ip.extra.items.len);
    inline for (fields) |field| {
        ip.extra.appendAssumeCapacity(switch (field.type) {
            u32 => @field(extra, field.name),
            Index => @enumToInt(@field(extra, field.name)),
            i32 => @bitCast(u32, @field(extra, field.name)),
            else => @compileError("bad field type"),
        });
    }
    return result;
}

fn extraData(ip: InternPool, comptime T: type, index: usize) T {
    const fields = std.meta.fields(T);
    var i: usize = index;
    var result: T = undefined;
    inline for (fields) |field| {
        @field(result, field.name) = switch (field.type) {
            u32 => ip.extra.items[i],
            Index => @intToEnum(Index, ip.extra.items[i]),
            i32 => @bitCast(i32, ip.extra.items[i]),
            else => @compileError("bad field type"),
        };
        i += 1;
    }
    return result;
}

test "basic usage" {
    const gpa = std.testing.allocator;

    var ip: InternPool = .{};
    defer ip.deinit(gpa);

    const i32_type = try ip.get(gpa, .{ .int_type = .{
        .signedness = .signed,
        .bits = 32,
    } });
    const array_i32 = try ip.get(gpa, .{ .array_type = .{
        .len = 10,
        .child = i32_type,
        .sentinel = .none,
    } });

    const another_i32_type = try ip.get(gpa, .{ .int_type = .{
        .signedness = .signed,
        .bits = 32,
    } });
    try std.testing.expect(another_i32_type == i32_type);

    const another_array_i32 = try ip.get(gpa, .{ .array_type = .{
        .len = 10,
        .child = i32_type,
        .sentinel = .none,
    } });
    try std.testing.expect(another_array_i32 == array_i32);
}
