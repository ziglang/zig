map: std.AutoArrayHashMapUnmanaged(void, void) = .{},
items: std.MultiArrayList(Item) = .{},
extra: std.ArrayListUnmanaged(u32) = .{},

const InternPool = @This();
const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

const KeyAdapter = struct {
    intern_pool: *const InternPool,

    pub fn eql(ctx: @This(), a: Key, b_void: void, b_map_index: usize) bool {
        _ = b_void;
        return ctx.intern_pool.indexToKey(@intToEnum(Index, b_map_index)).eql(a);
    }

    pub fn hash(ctx: @This(), a: Key) u32 {
        _ = ctx;
        return a.hash();
    }
};

pub const Key = union(enum) {
    int_type: struct {
        signedness: std.builtin.Signedness,
        bits: u16,
    },
    ptr_type: struct {
        elem_type: Index,
        sentinel: Index,
        alignment: u16,
        size: std.builtin.Type.Pointer.Size,
        is_const: bool,
        is_volatile: bool,
        is_allowzero: bool,
        address_space: std.builtin.AddressSpace,
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
    simple: Simple,

    pub fn hash(key: Key) u32 {
        var hasher = std.hash.Wyhash.init(0);
        switch (key) {
            .int_type => |int_type| {
                std.hash.autoHash(&hasher, int_type);
            },
            .array_type => |array_type| {
                std.hash.autoHash(&hasher, array_type);
            },
            else => @panic("TODO"),
        }
        return @truncate(u32, hasher.final());
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
pub const Index = enum(u32) {
    none = std.math.maxInt(u32),
    _,
};

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
    /// A type or value that can be represented with only an enum tag.
    /// data is Simple enum value
    simple,
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
};

pub const Simple = enum(u32) {
    f16,
    f32,
    f64,
    f80,
    f128,
    usize,
    isize,
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
    null_type,
    undefined_type,
    enum_literal_type,
    @"undefined",
    void_value,
    @"null",
    bool_true,
    bool_false,
};

pub const Array = struct {
    len: u32,
    child: Index,
};

pub fn deinit(ip: *InternPool, gpa: Allocator) void {
    ip.map.deinit(gpa);
    ip.items.deinit(gpa);
    ip.extra.deinit(gpa);
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
        .simple => .{ .simple = @intToEnum(Simple, data) },

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
            const tag: Tag = switch (int_type.signedness) {
                .signed => .type_int_signed,
                .unsigned => .type_int_unsigned,
            };
            try ip.items.append(gpa, .{
                .tag = tag,
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

fn addExtra(ip: *InternPool, gpa: Allocator, extra: anytype) Allocator.Error!u32 {
    const fields = std.meta.fields(@TypeOf(extra));
    try ip.extra.ensureUnusedCapacity(gpa, fields.len);
    return ip.addExtraAssumeCapacity(extra);
}

fn addExtraAssumeCapacity(ip: *InternPool, extra: anytype) u32 {
    const fields = std.meta.fields(@TypeOf(extra));
    const result = @intCast(u32, ip.extra.items.len);
    inline for (fields) |field| {
        ip.extra.appendAssumeCapacity(switch (field.field_type) {
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
        @field(result, field.name) = switch (field.field_type) {
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
