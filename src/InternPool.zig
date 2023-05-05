//! All interned objects have both a value and a type.

map: std.AutoArrayHashMapUnmanaged(void, void) = .{},
items: std.MultiArrayList(Item) = .{},
extra: std.ArrayListUnmanaged(u32) = .{},
/// On 32-bit systems, this array is ignored and extra is used for everything.
/// On 64-bit systems, this array is used for big integers and associated metadata.
limbs: std.ArrayListUnmanaged(u64) = .{},

const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const BigIntConst = std.math.big.int.Const;
const BigIntMutable = std.math.big.int.Mutable;

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
    ptr_type: PtrType,
    array_type: ArrayType,
    vector_type: VectorType,
    opt_type: Index,
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
    int: Key.Int,
    enum_tag: struct {
        ty: Index,
        tag: BigIntConst,
    },
    struct_type: struct {
        fields_len: u32,
        // TODO move Module.Struct data to InternPool
    },
    union_type: struct {
        fields_len: u32,
        // TODO move Module.Union data to InternPool
    },

    pub const IntType = std.builtin.Type.Int;

    pub const PtrType = struct {
        elem_type: Index,
        sentinel: Index = .none,
        /// If zero use pointee_type.abiAlignment()
        /// When creating pointer types, if alignment is equal to pointee type
        /// abi alignment, this value should be set to 0 instead.
        alignment: u16 = 0,
        /// If this is non-zero it means the pointer points to a sub-byte
        /// range of data, which is backed by a "host integer" with this
        /// number of bytes.
        /// When host_size=pointee_abi_size and bit_offset=0, this must be
        /// represented with host_size=0 instead.
        host_size: u16 = 0,
        bit_offset: u16 = 0,
        vector_index: VectorIndex = .none,
        size: std.builtin.Type.Pointer.Size = .One,
        is_const: bool = false,
        is_volatile: bool = false,
        is_allowzero: bool = false,
        /// See src/target.zig defaultAddressSpace function for how to obtain
        /// an appropriate value for this field.
        address_space: std.builtin.AddressSpace = .generic,

        pub const VectorIndex = enum(u32) {
            none = std.math.maxInt(u32),
            runtime = std.math.maxInt(u32) - 1,
            _,
        };
    };

    pub const ArrayType = struct {
        len: u64,
        child: Index,
        sentinel: Index,
    };

    pub const VectorType = struct {
        len: u32,
        child: Index,
    };

    pub const Int = struct {
        ty: Index,
        storage: Storage,

        pub const Storage = union(enum) {
            u64: u64,
            i64: i64,
            big_int: BigIntConst,

            /// Big enough to fit any non-BigInt value
            pub const BigIntSpace = struct {
                /// The +1 is headroom so that operations such as incrementing once
                /// or decrementing once are possible without using an allocator.
                limbs: [(@sizeOf(u64) / @sizeOf(std.math.big.Limb)) + 1]std.math.big.Limb,
            };

            pub fn toBigInt(storage: Storage, space: *BigIntSpace) BigIntConst {
                return switch (storage) {
                    .big_int => |x| x,
                    .u64 => |x| BigIntMutable.init(&space.limbs, x).toConst(),
                    .i64 => |x| BigIntMutable.init(&space.limbs, x).toConst(),
                };
            }
        };
    };

    pub fn hash32(key: Key) u32 {
        return @truncate(u32, key.hash64());
    }

    pub fn hash64(key: Key) u64 {
        var hasher = std.hash.Wyhash.init(0);
        key.hashWithHasher(&hasher);
        return hasher.final();
    }

    pub fn hashWithHasher(key: Key, hasher: *std.hash.Wyhash) void {
        const KeyTag = @typeInfo(Key).Union.tag_type.?;
        const key_tag: KeyTag = key;
        std.hash.autoHash(hasher, key_tag);
        switch (key) {
            inline .int_type,
            .ptr_type,
            .array_type,
            .vector_type,
            .opt_type,
            .error_union_type,
            .simple_type,
            .simple_value,
            .extern_func,
            => |info| std.hash.autoHash(hasher, info),

            .int => |int| {
                // Canonicalize all integers by converting them to BigIntConst.
                var buffer: Key.Int.Storage.BigIntSpace = undefined;
                const big_int = int.storage.toBigInt(&buffer);

                std.hash.autoHash(hasher, int.ty);
                std.hash.autoHash(hasher, big_int.positive);
                for (big_int.limbs) |limb| std.hash.autoHash(hasher, limb);
            },

            .enum_tag => |enum_tag| {
                std.hash.autoHash(hasher, enum_tag.ty);
                std.hash.autoHash(hasher, enum_tag.tag.positive);
                for (enum_tag.tag.limbs) |limb| std.hash.autoHash(hasher, limb);
            },

            .struct_type => |struct_type| {
                if (struct_type.fields_len != 0) {
                    @panic("TODO");
                }
            },
            .union_type => |union_type| {
                _ = union_type;
                @panic("TODO");
            },
        }
    }

    pub fn eql(a: Key, b: Key) bool {
        const KeyTag = @typeInfo(Key).Union.tag_type.?;
        const a_tag: KeyTag = a;
        const b_tag: KeyTag = b;
        if (a_tag != b_tag) return false;
        switch (a) {
            .int_type => |a_info| {
                const b_info = b.int_type;
                return std.meta.eql(a_info, b_info);
            },
            .ptr_type => |a_info| {
                const b_info = b.ptr_type;
                return std.meta.eql(a_info, b_info);
            },
            .array_type => |a_info| {
                const b_info = b.array_type;
                return std.meta.eql(a_info, b_info);
            },
            .vector_type => |a_info| {
                const b_info = b.vector_type;
                return std.meta.eql(a_info, b_info);
            },
            .opt_type => |a_info| {
                const b_info = b.opt_type;
                return std.meta.eql(a_info, b_info);
            },
            .error_union_type => |a_info| {
                const b_info = b.error_union_type;
                return std.meta.eql(a_info, b_info);
            },
            .simple_type => |a_info| {
                const b_info = b.simple_type;
                return a_info == b_info;
            },
            .simple_value => |a_info| {
                const b_info = b.simple_value;
                return a_info == b_info;
            },
            .extern_func => |a_info| {
                const b_info = b.extern_func;
                return std.meta.eql(a_info, b_info);
            },

            .int => |a_info| {
                const b_info = b.int;
                _ = a_info;
                _ = b_info;
                @panic("TODO");
            },

            .enum_tag => |a_info| {
                const b_info = b.enum_tag;
                _ = a_info;
                _ = b_info;
                @panic("TODO");
            },

            .struct_type => |a_info| {
                const b_info = b.struct_type;

                // TODO: remove this special case for empty_struct
                if (a_info.fields_len == 0 and b_info.fields_len == 0)
                    return true;

                @panic("TODO");
            },

            .union_type => |a_info| {
                const b_info = b.union_type;

                _ = a_info;
                _ = b_info;
                @panic("TODO");
            },
        }
    }

    pub fn typeOf(key: Key) Index {
        switch (key) {
            .int_type,
            .ptr_type,
            .array_type,
            .vector_type,
            .opt_type,
            .error_union_type,
            .simple_type,
            .struct_type,
            .union_type,
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
    pub const first_type: Index = .u1_type;
    pub const last_type: Index = .empty_struct_type;
    pub const first_value: Index = .undef;
    pub const last_value: Index = .empty_struct;

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
    manyptr_const_u8_sentinel_0_type,
    single_const_pointer_to_comptime_int_type,
    const_slice_u8_type,
    const_slice_u8_sentinel_0_type,
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
    /// `0` (u8)
    zero_u8,
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

    // manyptr_const_u8_type
    .{ .ptr_type = .{
        .elem_type = .u8_type,
        .size = .Many,
        .is_const = true,
    } },

    // manyptr_const_u8_sentinel_0_type
    .{ .ptr_type = .{
        .elem_type = .u8_type,
        .sentinel = .zero_u8,
        .size = .Many,
        .is_const = true,
    } },

    .{ .ptr_type = .{
        .elem_type = .comptime_int_type,
        .size = .One,
        .is_const = true,
    } },

    // const_slice_u8_type
    .{ .ptr_type = .{
        .elem_type = .u8_type,
        .size = .Slice,
        .is_const = true,
    } },

    // const_slice_u8_sentinel_0_type
    .{ .ptr_type = .{
        .elem_type = .u8_type,
        .sentinel = .zero_u8,
        .size = .Slice,
        .is_const = true,
    } },

    // anyerror_void_error_union_type
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
        .storage = .{ .u64 = 0 },
    } },

    .{ .int = .{
        .ty = .usize_type,
        .storage = .{ .u64 = 0 },
    } },

    .{ .int = .{
        .ty = .u8_type,
        .storage = .{ .u64 = 0 },
    } },

    .{ .int = .{
        .ty = .comptime_int_type,
        .storage = .{ .u64 = 1 },
    } },

    .{ .int = .{
        .ty = .usize_type,
        .storage = .{ .u64 = 1 },
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
    /// An array type that has no sentinel and whose length fits in 32 bits.
    /// data is payload to Vector.
    type_array,
    /// A vector type.
    /// data is payload to Vector.
    type_vector,
    /// A fully explicitly specified pointer type.
    /// data is payload to Pointer.
    type_pointer,
    /// An optional type.
    /// data is the child type.
    type_optional,
    /// An error union type.
    /// data is payload to ErrorUnion.
    type_error_union,
    /// Represents the data that an enum declaration provides, when the fields
    /// are auto-numbered, and there are no declarations.
    /// data is payload index to `EnumSimple`.
    type_enum_simple,

    /// A type that can be represented with only an enum tag.
    /// data is SimpleType enum value.
    simple_type,
    /// A value that can be represented with only an enum tag.
    /// data is SimpleValue enum value.
    simple_value,
    /// The SimpleType and SimpleValue enums are exposed via the InternPool API using
    /// SimpleType and SimpleValue as the Key data themselves.
    /// This tag is for miscellaneous types and values that can be represented with
    /// only an enum tag, but will be presented via the API with a different Key.
    /// data is SimpleInternal enum value.
    simple_internal,
    /// Type: u32
    /// data is integer value
    int_u32,
    /// Type: i32
    /// data is integer value bitcasted to u32.
    int_i32,
    /// A usize that fits in 32 bits.
    /// data is integer value.
    int_usize,
    /// A comptime_int that fits in a u32.
    /// data is integer value.
    int_comptime_int_u32,
    /// A comptime_int that fits in an i32.
    /// data is integer value bitcasted to u32.
    int_comptime_int_i32,
    /// A positive integer value.
    /// data is a limbs index to Int.
    int_positive,
    /// A negative integer value.
    /// data is a limbs index to Int.
    int_negative,
    /// An enum tag identified by a positive integer value.
    /// data is a limbs index to Int.
    enum_tag_positive,
    /// An enum tag identified by a negative integer value.
    /// data is a limbs index to Int.
    enum_tag_negative,
    /// An f32 value.
    /// data is float value bitcasted to u32.
    float_f32,
    /// An f64 value.
    /// data is payload index to Float64.
    float_f64,
    /// An f128 value.
    /// data is payload index to Float128.
    float_f128,
    /// An extern function.
    extern_func,
    /// A regular function.
    func,
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

pub const SimpleInternal = enum(u32) {
    /// This is the empty struct type. Note that empty_struct value is exposed
    /// via SimpleValue.
    type_empty_struct,
};

pub const Pointer = struct {
    child: Index,
    sentinel: Index,
    flags: Flags,
    packed_offset: PackedOffset,
    vector_index: VectorIndex,

    pub const Flags = packed struct(u32) {
        alignment: u16,
        is_const: bool,
        is_volatile: bool,
        is_allowzero: bool,
        size: Size,
        address_space: AddressSpace,
        _: u7 = undefined,
    };

    pub const PackedOffset = packed struct(u32) {
        host_size: u16,
        bit_offset: u16,
    };

    pub const Size = std.builtin.Type.Pointer.Size;
    pub const AddressSpace = std.builtin.AddressSpace;
    pub const VectorIndex = Key.PtrType.VectorIndex;
};

/// Used for non-sentineled arrays that have length fitting in u32, as well as
/// vectors.
pub const Vector = struct {
    len: u32,
    child: Index,
};

pub const ErrorUnion = struct {
    error_set_type: Index,
    payload_type: Index,
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

/// Trailing: Limb for every limbs_len
pub const Int = struct {
    ty: Index,
    limbs_len: u32,
};

pub fn init(ip: *InternPool, gpa: Allocator) !void {
    assert(ip.items.len == 0);

    // So that we can use `catch unreachable` below.
    try ip.items.ensureUnusedCapacity(gpa, static_keys.len);
    try ip.map.ensureUnusedCapacity(gpa, static_keys.len);
    try ip.extra.ensureUnusedCapacity(gpa, static_keys.len);
    try ip.limbs.ensureUnusedCapacity(gpa, 2);

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
    ip.limbs.deinit(gpa);
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
            const array_info = ip.extraData(Vector, data);
            return .{ .array_type = .{
                .len = array_info.len,
                .child = array_info.child,
                .sentinel = .none,
            } };
        },
        .simple_type => .{ .simple_type = @intToEnum(SimpleType, data) },
        .simple_value => .{ .simple_value = @intToEnum(SimpleValue, data) },

        .type_vector => {
            const vector_info = ip.extraData(Vector, data);
            return .{ .vector_type = .{
                .len = vector_info.len,
                .child = vector_info.child,
            } };
        },

        .type_pointer => {
            const ptr_info = ip.extraData(Pointer, data);
            return .{ .ptr_type = .{
                .elem_type = ptr_info.child,
                .sentinel = ptr_info.sentinel,
                .alignment = ptr_info.flags.alignment,
                .size = ptr_info.flags.size,
                .is_const = ptr_info.flags.is_const,
                .is_volatile = ptr_info.flags.is_volatile,
                .is_allowzero = ptr_info.flags.is_allowzero,
                .address_space = ptr_info.flags.address_space,
                .vector_index = ptr_info.vector_index,
                .host_size = ptr_info.packed_offset.host_size,
                .bit_offset = ptr_info.packed_offset.bit_offset,
            } };
        },

        .type_optional => .{ .opt_type = @intToEnum(Index, data) },

        .type_error_union => @panic("TODO"),
        .type_enum_simple => @panic("TODO"),
        .simple_internal => @panic("TODO"),
        .int_u32 => return .{ .int = .{
            .ty = .u32_type,
            .storage = .{ .u64 = data },
        } },
        .int_i32 => return .{ .int = .{
            .ty = .i32_type,
            .storage = .{ .i64 = @bitCast(i32, data) },
        } },
        .int_usize => return .{ .int = .{
            .ty = .usize_type,
            .storage = .{ .u64 = data },
        } },
        .int_comptime_int_u32 => return .{ .int = .{
            .ty = .comptime_int_type,
            .storage = .{ .u64 = data },
        } },
        .int_comptime_int_i32 => return .{ .int = .{
            .ty = .comptime_int_type,
            .storage = .{ .i64 = @bitCast(i32, data) },
        } },
        .int_positive => @panic("TODO"),
        .int_negative => @panic("TODO"),
        .enum_tag_positive => @panic("TODO"),
        .enum_tag_negative => @panic("TODO"),
        .float_f32 => @panic("TODO"),
        .float_f64 => @panic("TODO"),
        .float_f128 => @panic("TODO"),
        .extern_func => @panic("TODO"),
        .func => @panic("TODO"),
    };
}

pub fn get(ip: *InternPool, gpa: Allocator, key: Key) Allocator.Error!Index {
    const adapter: KeyAdapter = .{ .intern_pool = ip };
    const gop = try ip.map.getOrPutAdapted(gpa, key, adapter);
    if (gop.found_existing) {
        return @intToEnum(Index, gop.index);
    }
    try ip.items.ensureUnusedCapacity(gpa, 1);
    switch (key) {
        .int_type => |int_type| {
            const t: Tag = switch (int_type.signedness) {
                .signed => .type_int_signed,
                .unsigned => .type_int_unsigned,
            };
            ip.items.appendAssumeCapacity(.{
                .tag = t,
                .data = int_type.bits,
            });
        },
        .ptr_type => |ptr_type| {
            // TODO introduce more pointer encodings
            ip.items.appendAssumeCapacity(.{
                .tag = .type_pointer,
                .data = try ip.addExtra(gpa, Pointer{
                    .child = ptr_type.elem_type,
                    .sentinel = ptr_type.sentinel,
                    .flags = .{
                        .alignment = ptr_type.alignment,
                        .is_const = ptr_type.is_const,
                        .is_volatile = ptr_type.is_volatile,
                        .is_allowzero = ptr_type.is_allowzero,
                        .size = ptr_type.size,
                        .address_space = ptr_type.address_space,
                    },
                    .packed_offset = .{
                        .host_size = ptr_type.host_size,
                        .bit_offset = ptr_type.bit_offset,
                    },
                    .vector_index = ptr_type.vector_index,
                }),
            });
        },
        .array_type => |array_type| {
            const len = @intCast(u32, array_type.len); // TODO have a big_array encoding
            assert(array_type.sentinel == .none); // TODO have a sentinel_array encoding
            ip.items.appendAssumeCapacity(.{
                .tag = .type_array,
                .data = try ip.addExtra(gpa, Vector{
                    .len = len,
                    .child = array_type.child,
                }),
            });
        },
        .vector_type => |vector_type| {
            ip.items.appendAssumeCapacity(.{
                .tag = .type_vector,
                .data = try ip.addExtra(gpa, Vector{
                    .len = vector_type.len,
                    .child = vector_type.child,
                }),
            });
        },
        .opt_type => |opt_type| {
            ip.items.appendAssumeCapacity(.{
                .tag = .type_optional,
                .data = @enumToInt(opt_type),
            });
        },
        .error_union_type => |error_union_type| {
            ip.items.appendAssumeCapacity(.{
                .tag = .type_error_union,
                .data = try ip.addExtra(gpa, ErrorUnion{
                    .error_set_type = error_union_type.error_set_type,
                    .payload_type = error_union_type.payload_type,
                }),
            });
        },
        .simple_type => |simple_type| {
            ip.items.appendAssumeCapacity(.{
                .tag = .simple_type,
                .data = @enumToInt(simple_type),
            });
        },
        .simple_value => |simple_value| {
            ip.items.appendAssumeCapacity(.{
                .tag = .simple_value,
                .data = @enumToInt(simple_value),
            });
        },
        .extern_func => @panic("TODO"),

        .int => |int| b: {
            switch (int.ty) {
                .u32_type => switch (int.storage) {
                    .big_int => |big_int| {
                        if (big_int.to(u32)) |casted| {
                            ip.items.appendAssumeCapacity(.{
                                .tag = .int_u32,
                                .data = casted,
                            });
                            break :b;
                        } else |_| {}
                    },
                    inline .u64, .i64 => |x| {
                        if (std.math.cast(u32, x)) |casted| {
                            ip.items.appendAssumeCapacity(.{
                                .tag = .int_u32,
                                .data = casted,
                            });
                            break :b;
                        }
                    },
                },
                .i32_type => switch (int.storage) {
                    .big_int => |big_int| {
                        if (big_int.to(i32)) |casted| {
                            ip.items.appendAssumeCapacity(.{
                                .tag = .int_i32,
                                .data = @bitCast(u32, casted),
                            });
                            break :b;
                        } else |_| {}
                    },
                    inline .u64, .i64 => |x| {
                        if (std.math.cast(i32, x)) |casted| {
                            ip.items.appendAssumeCapacity(.{
                                .tag = .int_u32,
                                .data = @bitCast(u32, casted),
                            });
                            break :b;
                        }
                    },
                },
                .usize_type => switch (int.storage) {
                    .big_int => |big_int| {
                        if (big_int.to(u32)) |casted| {
                            ip.items.appendAssumeCapacity(.{
                                .tag = .int_usize,
                                .data = casted,
                            });
                            break :b;
                        } else |_| {}
                    },
                    inline .u64, .i64 => |x| {
                        if (std.math.cast(u32, x)) |casted| {
                            ip.items.appendAssumeCapacity(.{
                                .tag = .int_usize,
                                .data = casted,
                            });
                            break :b;
                        }
                    },
                },
                .comptime_int_type => switch (int.storage) {
                    .big_int => |big_int| {
                        if (big_int.to(u32)) |casted| {
                            ip.items.appendAssumeCapacity(.{
                                .tag = .int_comptime_int_u32,
                                .data = casted,
                            });
                            break :b;
                        } else |_| {}
                        if (big_int.to(i32)) |casted| {
                            ip.items.appendAssumeCapacity(.{
                                .tag = .int_comptime_int_i32,
                                .data = @bitCast(u32, casted),
                            });
                            break :b;
                        } else |_| {}
                    },
                    inline .u64, .i64 => |x| {
                        if (std.math.cast(u32, x)) |casted| {
                            ip.items.appendAssumeCapacity(.{
                                .tag = .int_comptime_int_u32,
                                .data = casted,
                            });
                            break :b;
                        }
                        if (std.math.cast(i32, x)) |casted| {
                            ip.items.appendAssumeCapacity(.{
                                .tag = .int_comptime_int_i32,
                                .data = @bitCast(u32, casted),
                            });
                            break :b;
                        }
                    },
                },
                else => {},
            }
            switch (int.storage) {
                .big_int => |big_int| {
                    const tag: Tag = if (big_int.positive) .int_positive else .int_negative;
                    try addInt(ip, gpa, int.ty, tag, big_int.limbs);
                },
                inline .i64, .u64 => |x| {
                    var buf: [2]usize = undefined;
                    const big_int = BigIntMutable.init(&buf, x).toConst();
                    const tag: Tag = if (big_int.positive) .int_positive else .int_negative;
                    try addInt(ip, gpa, int.ty, tag, big_int.limbs);
                },
            }
        },

        .enum_tag => |enum_tag| {
            const tag: Tag = if (enum_tag.tag.positive) .enum_tag_positive else .enum_tag_negative;
            try addInt(ip, gpa, enum_tag.ty, tag, enum_tag.tag.limbs);
        },

        .struct_type => |struct_type| {
            if (struct_type.fields_len != 0) {
                @panic("TODO"); // handle structs other than empty_struct
            }
            ip.items.appendAssumeCapacity(.{
                .tag = .simple_internal,
                .data = @enumToInt(SimpleInternal.type_empty_struct),
            });
        },

        .union_type => |union_type| {
            _ = union_type;
            @panic("TODO");
        },
    }
    return @intToEnum(Index, ip.items.len - 1);
}

fn addInt(ip: *InternPool, gpa: Allocator, ty: Index, tag: Tag, limbs: []const usize) !void {
    const limbs_len = @intCast(u32, limbs.len);
    try ip.reserveLimbs(gpa, @typeInfo(Int).Struct.fields.len + limbs_len);
    ip.items.appendAssumeCapacity(.{
        .tag = tag,
        .data = ip.addLimbsExtraAssumeCapacity(Int{
            .ty = ty,
            .limbs_len = limbs_len,
        }),
    });
    ip.addLimbsAssumeCapacity(limbs);
}

fn addExtra(ip: *InternPool, gpa: Allocator, extra: anytype) Allocator.Error!u32 {
    const fields = @typeInfo(@TypeOf(extra)).Struct.fields;
    try ip.extra.ensureUnusedCapacity(gpa, fields.len);
    return ip.addExtraAssumeCapacity(extra);
}

fn addExtraAssumeCapacity(ip: *InternPool, extra: anytype) u32 {
    const result = @intCast(u32, ip.extra.items.len);
    inline for (@typeInfo(@TypeOf(extra)).Struct.fields) |field| {
        ip.extra.appendAssumeCapacity(switch (field.type) {
            u32 => @field(extra, field.name),
            Index => @enumToInt(@field(extra, field.name)),
            i32 => @bitCast(u32, @field(extra, field.name)),
            Pointer.Flags => @bitCast(u32, @field(extra, field.name)),
            Pointer.PackedOffset => @bitCast(u32, @field(extra, field.name)),
            Pointer.VectorIndex => @enumToInt(@field(extra, field.name)),
            else => @compileError("bad field type: " ++ @typeName(field.type)),
        });
    }
    return result;
}

fn reserveLimbs(ip: *InternPool, gpa: Allocator, n: usize) !void {
    switch (@sizeOf(usize)) {
        @sizeOf(u32) => try ip.extra.ensureUnusedCapacity(gpa, n),
        @sizeOf(u64) => try ip.limbs.ensureUnusedCapacity(gpa, n),
        else => @compileError("unsupported host"),
    }
}

fn addLimbsExtraAssumeCapacity(ip: *InternPool, extra: anytype) u32 {
    switch (@sizeOf(usize)) {
        @sizeOf(u32) => return addExtraAssumeCapacity(ip, extra),
        @sizeOf(u64) => {},
        else => @compileError("unsupported host"),
    }
    const result = @intCast(u32, ip.extra.items.len);
    inline for (@typeInfo(@TypeOf(extra)).Struct.fields, 0..) |field, i| {
        const new: u32 = switch (field.type) {
            u32 => @field(extra, field.name),
            Index => @enumToInt(@field(extra, field.name)),
            else => @compileError("bad field type: " ++ @typeName(field.type)),
        };
        if (i % 2 == 0) {
            ip.limbs.appendAssumeCapacity(new);
        } else {
            ip.limbs.items[ip.limbs.items.len - 1] |= @as(u64, new) << 32;
        }
    }
    return result;
}

fn addLimbsAssumeCapacity(ip: *InternPool, limbs: []const usize) void {
    switch (@sizeOf(usize)) {
        @sizeOf(u32) => ip.extra.appendSliceAssumeCapacity(limbs),
        @sizeOf(u64) => ip.limbs.appendSliceAssumeCapacity(limbs),
        else => @compileError("unsupported host"),
    }
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
            Pointer.Flags => @bitCast(Pointer.Flags, ip.extra.items[i]),
            Pointer.PackedOffset => @bitCast(Pointer.PackedOffset, ip.extra.items[i]),
            Pointer.VectorIndex => @intToEnum(Pointer.VectorIndex, ip.extra.items[i]),
            else => @compileError("bad field type: " ++ @typeName(field.type)),
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

pub fn childType(ip: InternPool, i: Index) Index {
    return switch (ip.indexToKey(i)) {
        .ptr_type => |ptr_type| ptr_type.elem_type,
        .vector_type => |vector_type| vector_type.child,
        .array_type => |array_type| array_type.child,
        .opt_type => |child| child,
        else => unreachable,
    };
}
