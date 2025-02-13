index: CType.Index,

pub const @"void": CType = .{ .index = .void };
pub const @"bool": CType = .{ .index = .bool };
pub const @"i8": CType = .{ .index = .int8_t };
pub const @"u8": CType = .{ .index = .uint8_t };
pub const @"i16": CType = .{ .index = .int16_t };
pub const @"u16": CType = .{ .index = .uint16_t };
pub const @"i32": CType = .{ .index = .int32_t };
pub const @"u32": CType = .{ .index = .uint32_t };
pub const @"i64": CType = .{ .index = .int64_t };
pub const @"u64": CType = .{ .index = .uint64_t };
pub const @"i128": CType = .{ .index = .zig_i128 };
pub const @"u128": CType = .{ .index = .zig_u128 };
pub const @"isize": CType = .{ .index = .intptr_t };
pub const @"usize": CType = .{ .index = .uintptr_t };
pub const @"f16": CType = .{ .index = .zig_f16 };
pub const @"f32": CType = .{ .index = .zig_f32 };
pub const @"f64": CType = .{ .index = .zig_f64 };
pub const @"f80": CType = .{ .index = .zig_f80 };
pub const @"f128": CType = .{ .index = .zig_f128 };

pub fn fromPoolIndex(pool_index: usize) CType {
    return .{ .index = @enumFromInt(CType.Index.first_pool_index + pool_index) };
}

pub fn toPoolIndex(ctype: CType) ?u32 {
    const pool_index, const is_null =
        @subWithOverflow(@intFromEnum(ctype.index), CType.Index.first_pool_index);
    return switch (is_null) {
        0 => pool_index,
        1 => null,
    };
}

pub fn eql(lhs: CType, rhs: CType) bool {
    return lhs.index == rhs.index;
}

pub fn isBool(ctype: CType) bool {
    return switch (ctype.index) {
        ._Bool, .bool => true,
        else => false,
    };
}

pub fn isInteger(ctype: CType) bool {
    return switch (ctype.index) {
        .char,
        .@"signed char",
        .short,
        .int,
        .long,
        .@"long long",
        .@"unsigned char",
        .@"unsigned short",
        .@"unsigned int",
        .@"unsigned long",
        .@"unsigned long long",
        .size_t,
        .ptrdiff_t,
        .uint8_t,
        .int8_t,
        .uint16_t,
        .int16_t,
        .uint32_t,
        .int32_t,
        .uint64_t,
        .int64_t,
        .uintptr_t,
        .intptr_t,
        .zig_u128,
        .zig_i128,
        => true,
        else => false,
    };
}

pub fn signedness(ctype: CType, mod: *Module) std.builtin.Signedness {
    return switch (ctype.index) {
        .char => mod.resolved_target.result.charSignedness(),
        .@"signed char",
        .short,
        .int,
        .long,
        .@"long long",
        .ptrdiff_t,
        .int8_t,
        .int16_t,
        .int32_t,
        .int64_t,
        .intptr_t,
        .zig_i128,
        => .signed,
        .@"unsigned char",
        .@"unsigned short",
        .@"unsigned int",
        .@"unsigned long",
        .@"unsigned long long",
        .size_t,
        .uint8_t,
        .uint16_t,
        .uint32_t,
        .uint64_t,
        .uintptr_t,
        .zig_u128,
        => .unsigned,
        else => unreachable,
    };
}

pub fn isFloat(ctype: CType) bool {
    return switch (ctype.index) {
        .float,
        .double,
        .@"long double",
        .zig_f16,
        .zig_f32,
        .zig_f64,
        .zig_f80,
        .zig_f128,
        .zig_c_longdouble,
        => true,
        else => false,
    };
}

pub fn toSigned(ctype: CType) CType {
    return switch (ctype.index) {
        .char, .@"signed char", .@"unsigned char" => .{ .index = .@"signed char" },
        .short, .@"unsigned short" => .{ .index = .short },
        .int, .@"unsigned int" => .{ .index = .int },
        .long, .@"unsigned long" => .{ .index = .long },
        .@"long long", .@"unsigned long long" => .{ .index = .@"long long" },
        .size_t, .ptrdiff_t => .{ .index = .ptrdiff_t },
        .uint8_t, .int8_t => .{ .index = .int8_t },
        .uint16_t, .int16_t => .{ .index = .int16_t },
        .uint32_t, .int32_t => .{ .index = .int32_t },
        .uint64_t, .int64_t => .{ .index = .int64_t },
        .uintptr_t, .intptr_t => .{ .index = .intptr_t },
        .zig_u128, .zig_i128 => .{ .index = .zig_i128 },
        .float,
        .double,
        .@"long double",
        .zig_f16,
        .zig_f32,
        .zig_f80,
        .zig_f128,
        .zig_c_longdouble,
        => ctype,
        else => unreachable,
    };
}

pub fn toUnsigned(ctype: CType) CType {
    return switch (ctype.index) {
        .char, .@"signed char", .@"unsigned char" => .{ .index = .@"unsigned char" },
        .short, .@"unsigned short" => .{ .index = .@"unsigned short" },
        .int, .@"unsigned int" => .{ .index = .@"unsigned int" },
        .long, .@"unsigned long" => .{ .index = .@"unsigned long" },
        .@"long long", .@"unsigned long long" => .{ .index = .@"unsigned long long" },
        .size_t, .ptrdiff_t => .{ .index = .size_t },
        .uint8_t, .int8_t => .{ .index = .uint8_t },
        .uint16_t, .int16_t => .{ .index = .uint16_t },
        .uint32_t, .int32_t => .{ .index = .uint32_t },
        .uint64_t, .int64_t => .{ .index = .uint64_t },
        .uintptr_t, .intptr_t => .{ .index = .uintptr_t },
        .zig_u128, .zig_i128 => .{ .index = .zig_u128 },
        else => unreachable,
    };
}

pub fn toSignedness(ctype: CType, s: std.builtin.Signedness) CType {
    return switch (s) {
        .unsigned => ctype.toUnsigned(),
        .signed => ctype.toSigned(),
    };
}

pub fn getStandardDefineAbbrev(ctype: CType) ?[]const u8 {
    return switch (ctype.index) {
        .char => "CHAR",
        .@"signed char" => "SCHAR",
        .short => "SHRT",
        .int => "INT",
        .long => "LONG",
        .@"long long" => "LLONG",
        .@"unsigned char" => "UCHAR",
        .@"unsigned short" => "USHRT",
        .@"unsigned int" => "UINT",
        .@"unsigned long" => "ULONG",
        .@"unsigned long long" => "ULLONG",
        .float => "FLT",
        .double => "DBL",
        .@"long double" => "LDBL",
        .size_t => "SIZE",
        .ptrdiff_t => "PTRDIFF",
        .uint8_t => "UINT8",
        .int8_t => "INT8",
        .uint16_t => "UINT16",
        .int16_t => "INT16",
        .uint32_t => "UINT32",
        .int32_t => "INT32",
        .uint64_t => "UINT64",
        .int64_t => "INT64",
        .uintptr_t => "UINTPTR",
        .intptr_t => "INTPTR",
        else => null,
    };
}

pub fn renderLiteralPrefix(ctype: CType, writer: anytype, kind: Kind, pool: *const Pool) @TypeOf(writer).Error!void {
    switch (ctype.info(pool)) {
        .basic => |basic_info| switch (basic_info) {
            .void => unreachable,
            ._Bool,
            .char,
            .@"signed char",
            .short,
            .@"unsigned short",
            .bool,
            .size_t,
            .ptrdiff_t,
            .uintptr_t,
            .intptr_t,
            => switch (kind) {
                else => try writer.print("({s})", .{@tagName(basic_info)}),
                .global => {},
            },
            .int,
            .long,
            .@"long long",
            .@"unsigned char",
            .@"unsigned int",
            .@"unsigned long",
            .@"unsigned long long",
            .float,
            .double,
            .@"long double",
            => {},
            .uint8_t,
            .int8_t,
            .uint16_t,
            .int16_t,
            .uint32_t,
            .int32_t,
            .uint64_t,
            .int64_t,
            => try writer.print("{s}_C(", .{ctype.getStandardDefineAbbrev().?}),
            .zig_u128,
            .zig_i128,
            .zig_f16,
            .zig_f32,
            .zig_f64,
            .zig_f80,
            .zig_f128,
            .zig_c_longdouble,
            => try writer.print("zig_{s}_{s}(", .{
                switch (kind) {
                    else => "make",
                    .global => "init",
                },
                @tagName(basic_info)["zig_".len..],
            }),
            .va_list => unreachable,
            _ => unreachable,
        },
        .array, .vector => try writer.writeByte('{'),
        else => unreachable,
    }
}

pub fn renderLiteralSuffix(ctype: CType, writer: anytype, pool: *const Pool) @TypeOf(writer).Error!void {
    switch (ctype.info(pool)) {
        .basic => |basic_info| switch (basic_info) {
            .void => unreachable,
            ._Bool => {},
            .char,
            .@"signed char",
            .short,
            .int,
            => {},
            .long => try writer.writeByte('l'),
            .@"long long" => try writer.writeAll("ll"),
            .@"unsigned char",
            .@"unsigned short",
            .@"unsigned int",
            => try writer.writeByte('u'),
            .@"unsigned long",
            .size_t,
            .uintptr_t,
            => try writer.writeAll("ul"),
            .@"unsigned long long" => try writer.writeAll("ull"),
            .float => try writer.writeByte('f'),
            .double => {},
            .@"long double" => try writer.writeByte('l'),
            .bool,
            .ptrdiff_t,
            .intptr_t,
            => {},
            .uint8_t,
            .int8_t,
            .uint16_t,
            .int16_t,
            .uint32_t,
            .int32_t,
            .uint64_t,
            .int64_t,
            .zig_u128,
            .zig_i128,
            .zig_f16,
            .zig_f32,
            .zig_f64,
            .zig_f80,
            .zig_f128,
            .zig_c_longdouble,
            => try writer.writeByte(')'),
            .va_list => unreachable,
            _ => unreachable,
        },
        .array, .vector => try writer.writeByte('}'),
        else => unreachable,
    }
}

pub fn floatActiveBits(ctype: CType, mod: *Module) u16 {
    const target = &mod.resolved_target.result;
    return switch (ctype.index) {
        .float => target.cTypeBitSize(.float),
        .double => target.cTypeBitSize(.double),
        .@"long double", .zig_c_longdouble => target.cTypeBitSize(.longdouble),
        .zig_f16 => 16,
        .zig_f32 => 32,
        .zig_f64 => 64,
        .zig_f80 => 80,
        .zig_f128 => 128,
        else => unreachable,
    };
}

pub fn byteSize(ctype: CType, pool: *const Pool, mod: *Module) u64 {
    const target = &mod.resolved_target.result;
    return switch (ctype.info(pool)) {
        .basic => |basic_info| switch (basic_info) {
            .void => 0,
            .char, .@"signed char", ._Bool, .@"unsigned char", .bool, .uint8_t, .int8_t => 1,
            .short => target.cTypeByteSize(.short),
            .int => target.cTypeByteSize(.int),
            .long => target.cTypeByteSize(.long),
            .@"long long" => target.cTypeByteSize(.longlong),
            .@"unsigned short" => target.cTypeByteSize(.ushort),
            .@"unsigned int" => target.cTypeByteSize(.uint),
            .@"unsigned long" => target.cTypeByteSize(.ulong),
            .@"unsigned long long" => target.cTypeByteSize(.ulonglong),
            .float => target.cTypeByteSize(.float),
            .double => target.cTypeByteSize(.double),
            .@"long double" => target.cTypeByteSize(.longdouble),
            .size_t,
            .ptrdiff_t,
            .uintptr_t,
            .intptr_t,
            => @divExact(target.ptrBitWidth(), 8),
            .uint16_t, .int16_t, .zig_f16 => 2,
            .uint32_t, .int32_t, .zig_f32 => 4,
            .uint64_t, .int64_t, .zig_f64 => 8,
            .zig_u128, .zig_i128, .zig_f128 => 16,
            .zig_f80 => if (target.cTypeBitSize(.longdouble) == 80)
                target.cTypeByteSize(.longdouble)
            else
                16,
            .zig_c_longdouble => target.cTypeByteSize(.longdouble),
            .va_list => unreachable,
            _ => unreachable,
        },
        .pointer => @divExact(target.ptrBitWidth(), 8),
        .array, .vector => |sequence_info| sequence_info.elem_ctype.byteSize(pool, mod) * sequence_info.len,
        else => unreachable,
    };
}

pub fn info(ctype: CType, pool: *const Pool) Info {
    const pool_index = ctype.toPoolIndex() orelse return .{ .basic = ctype.index };
    const item = pool.items.get(pool_index);
    switch (item.tag) {
        .basic => unreachable,
        .pointer => return .{ .pointer = .{
            .elem_ctype = .{ .index = @enumFromInt(item.data) },
        } },
        .pointer_const => return .{ .pointer = .{
            .elem_ctype = .{ .index = @enumFromInt(item.data) },
            .@"const" = true,
        } },
        .pointer_volatile => return .{ .pointer = .{
            .elem_ctype = .{ .index = @enumFromInt(item.data) },
            .@"volatile" = true,
        } },
        .pointer_const_volatile => return .{ .pointer = .{
            .elem_ctype = .{ .index = @enumFromInt(item.data) },
            .@"const" = true,
            .@"volatile" = true,
        } },
        .aligned => {
            const extra = pool.getExtra(Pool.Aligned, item.data);
            return .{ .aligned = .{
                .ctype = .{ .index = extra.ctype },
                .alignas = extra.flags.alignas,
            } };
        },
        .array_small => {
            const extra = pool.getExtra(Pool.SequenceSmall, item.data);
            return .{ .array = .{
                .elem_ctype = .{ .index = extra.elem_ctype },
                .len = extra.len,
            } };
        },
        .array_large => {
            const extra = pool.getExtra(Pool.SequenceLarge, item.data);
            return .{ .array = .{
                .elem_ctype = .{ .index = extra.elem_ctype },
                .len = extra.len(),
            } };
        },
        .vector => {
            const extra = pool.getExtra(Pool.SequenceSmall, item.data);
            return .{ .vector = .{
                .elem_ctype = .{ .index = extra.elem_ctype },
                .len = extra.len,
            } };
        },
        .fwd_decl_struct_anon => {
            const extra_trail = pool.getExtraTrail(Pool.FwdDeclAnon, item.data);
            return .{ .fwd_decl = .{
                .tag = .@"struct",
                .name = .{ .anon = .{
                    .extra_index = extra_trail.trail.extra_index,
                    .len = extra_trail.extra.fields_len,
                } },
            } };
        },
        .fwd_decl_union_anon => {
            const extra_trail = pool.getExtraTrail(Pool.FwdDeclAnon, item.data);
            return .{ .fwd_decl = .{
                .tag = .@"union",
                .name = .{ .anon = .{
                    .extra_index = extra_trail.trail.extra_index,
                    .len = extra_trail.extra.fields_len,
                } },
            } };
        },
        .fwd_decl_struct => return .{ .fwd_decl = .{
            .tag = .@"struct",
            .name = .{ .index = @enumFromInt(item.data) },
        } },
        .fwd_decl_union => return .{ .fwd_decl = .{
            .tag = .@"union",
            .name = .{ .index = @enumFromInt(item.data) },
        } },
        .aggregate_struct_anon => {
            const extra_trail = pool.getExtraTrail(Pool.AggregateAnon, item.data);
            return .{ .aggregate = .{
                .tag = .@"struct",
                .name = .{ .anon = .{
                    .index = extra_trail.extra.index,
                    .id = extra_trail.extra.id,
                } },
                .fields = .{
                    .extra_index = extra_trail.trail.extra_index,
                    .len = extra_trail.extra.fields_len,
                },
            } };
        },
        .aggregate_union_anon => {
            const extra_trail = pool.getExtraTrail(Pool.AggregateAnon, item.data);
            return .{ .aggregate = .{
                .tag = .@"union",
                .name = .{ .anon = .{
                    .index = extra_trail.extra.index,
                    .id = extra_trail.extra.id,
                } },
                .fields = .{
                    .extra_index = extra_trail.trail.extra_index,
                    .len = extra_trail.extra.fields_len,
                },
            } };
        },
        .aggregate_struct_packed_anon => {
            const extra_trail = pool.getExtraTrail(Pool.AggregateAnon, item.data);
            return .{ .aggregate = .{
                .tag = .@"struct",
                .@"packed" = true,
                .name = .{ .anon = .{
                    .index = extra_trail.extra.index,
                    .id = extra_trail.extra.id,
                } },
                .fields = .{
                    .extra_index = extra_trail.trail.extra_index,
                    .len = extra_trail.extra.fields_len,
                },
            } };
        },
        .aggregate_union_packed_anon => {
            const extra_trail = pool.getExtraTrail(Pool.AggregateAnon, item.data);
            return .{ .aggregate = .{
                .tag = .@"union",
                .@"packed" = true,
                .name = .{ .anon = .{
                    .index = extra_trail.extra.index,
                    .id = extra_trail.extra.id,
                } },
                .fields = .{
                    .extra_index = extra_trail.trail.extra_index,
                    .len = extra_trail.extra.fields_len,
                },
            } };
        },
        .aggregate_struct => {
            const extra_trail = pool.getExtraTrail(Pool.Aggregate, item.data);
            return .{ .aggregate = .{
                .tag = .@"struct",
                .name = .{ .fwd_decl = .{ .index = extra_trail.extra.fwd_decl } },
                .fields = .{
                    .extra_index = extra_trail.trail.extra_index,
                    .len = extra_trail.extra.fields_len,
                },
            } };
        },
        .aggregate_union => {
            const extra_trail = pool.getExtraTrail(Pool.Aggregate, item.data);
            return .{ .aggregate = .{
                .tag = .@"union",
                .name = .{ .fwd_decl = .{ .index = extra_trail.extra.fwd_decl } },
                .fields = .{
                    .extra_index = extra_trail.trail.extra_index,
                    .len = extra_trail.extra.fields_len,
                },
            } };
        },
        .aggregate_struct_packed => {
            const extra_trail = pool.getExtraTrail(Pool.Aggregate, item.data);
            return .{ .aggregate = .{
                .tag = .@"struct",
                .@"packed" = true,
                .name = .{ .fwd_decl = .{ .index = extra_trail.extra.fwd_decl } },
                .fields = .{
                    .extra_index = extra_trail.trail.extra_index,
                    .len = extra_trail.extra.fields_len,
                },
            } };
        },
        .aggregate_union_packed => {
            const extra_trail = pool.getExtraTrail(Pool.Aggregate, item.data);
            return .{ .aggregate = .{
                .tag = .@"union",
                .@"packed" = true,
                .name = .{ .fwd_decl = .{ .index = extra_trail.extra.fwd_decl } },
                .fields = .{
                    .extra_index = extra_trail.trail.extra_index,
                    .len = extra_trail.extra.fields_len,
                },
            } };
        },
        .function => {
            const extra_trail = pool.getExtraTrail(Pool.Function, item.data);
            return .{ .function = .{
                .return_ctype = .{ .index = extra_trail.extra.return_ctype },
                .param_ctypes = .{
                    .extra_index = extra_trail.trail.extra_index,
                    .len = extra_trail.extra.param_ctypes_len,
                },
                .varargs = false,
            } };
        },
        .function_varargs => {
            const extra_trail = pool.getExtraTrail(Pool.Function, item.data);
            return .{ .function = .{
                .return_ctype = .{ .index = extra_trail.extra.return_ctype },
                .param_ctypes = .{
                    .extra_index = extra_trail.trail.extra_index,
                    .len = extra_trail.extra.param_ctypes_len,
                },
                .varargs = true,
            } };
        },
    }
}

pub fn hash(ctype: CType, pool: *const Pool) Pool.Map.Hash {
    return if (ctype.toPoolIndex()) |pool_index|
        pool.map.entries.items(.hash)[pool_index]
    else
        CType.Index.basic_hashes[@intFromEnum(ctype.index)];
}

fn toForward(ctype: CType, pool: *Pool, allocator: std.mem.Allocator) !CType {
    return switch (ctype.info(pool)) {
        .basic, .pointer, .fwd_decl => ctype,
        .aligned => |aligned_info| pool.getAligned(allocator, .{
            .ctype = try aligned_info.ctype.toForward(pool, allocator),
            .alignas = aligned_info.alignas,
        }),
        .array => |array_info| pool.getArray(allocator, .{
            .elem_ctype = try array_info.elem_ctype.toForward(pool, allocator),
            .len = array_info.len,
        }),
        .vector => |vector_info| pool.getVector(allocator, .{
            .elem_ctype = try vector_info.elem_ctype.toForward(pool, allocator),
            .len = vector_info.len,
        }),
        .aggregate => |aggregate_info| switch (aggregate_info.name) {
            .anon => ctype,
            .fwd_decl => |fwd_decl| fwd_decl,
        },
        .function => unreachable,
    };
}

const Index = enum(u32) {
    void,

    // C basic types
    char,

    @"signed char",
    short,
    int,
    long,
    @"long long",

    _Bool,
    @"unsigned char",
    @"unsigned short",
    @"unsigned int",
    @"unsigned long",
    @"unsigned long long",

    float,
    double,
    @"long double",

    // C header types
    //  - stdbool.h
    bool,
    //  - stddef.h
    size_t,
    ptrdiff_t,
    //  - stdint.h
    uint8_t,
    int8_t,
    uint16_t,
    int16_t,
    uint32_t,
    int32_t,
    uint64_t,
    int64_t,
    uintptr_t,
    intptr_t,
    //  - stdarg.h
    va_list,

    // zig.h types
    zig_u128,
    zig_i128,
    zig_f16,
    zig_f32,
    zig_f64,
    zig_f80,
    zig_f128,
    zig_c_longdouble,

    _,

    const first_pool_index: u32 = @typeInfo(CType.Index).@"enum".fields.len;
    const basic_hashes = init: {
        @setEvalBranchQuota(1_600);
        var basic_hashes_init: [first_pool_index]Pool.Map.Hash = undefined;
        for (&basic_hashes_init, 0..) |*basic_hash, index| {
            const ctype_index: CType.Index = @enumFromInt(index);
            var hasher = Pool.Hasher.init;
            hasher.update(@intFromEnum(ctype_index));
            basic_hash.* = hasher.final(.basic);
        }
        break :init basic_hashes_init;
    };
};

const Slice = struct {
    extra_index: Pool.ExtraIndex,
    len: u32,

    pub fn at(slice: CType.Slice, index: usize, pool: *const Pool) CType {
        var extra: Pool.ExtraTrail = .{ .extra_index = slice.extra_index };
        return .{ .index = extra.next(slice.len, CType.Index, pool)[index] };
    }
};

pub const Kind = enum {
    forward,
    forward_parameter,
    complete,
    global,
    parameter,

    pub fn isForward(kind: Kind) bool {
        return switch (kind) {
            .forward, .forward_parameter => true,
            .complete, .global, .parameter => false,
        };
    }

    pub fn isParameter(kind: Kind) bool {
        return switch (kind) {
            .forward_parameter, .parameter => true,
            .forward, .complete, .global => false,
        };
    }

    pub fn asParameter(kind: Kind) Kind {
        return switch (kind) {
            .forward, .forward_parameter => .forward_parameter,
            .complete, .parameter, .global => .parameter,
        };
    }

    pub fn noParameter(kind: Kind) Kind {
        return switch (kind) {
            .forward, .forward_parameter => .forward,
            .complete, .parameter => .complete,
            .global => .global,
        };
    }

    pub fn asComplete(kind: Kind) Kind {
        return switch (kind) {
            .forward, .complete => .complete,
            .forward_parameter, .parameter => .parameter,
            .global => .global,
        };
    }
};

pub const Info = union(enum) {
    basic: CType.Index,
    pointer: Pointer,
    aligned: Aligned,
    array: Sequence,
    vector: Sequence,
    fwd_decl: FwdDecl,
    aggregate: Aggregate,
    function: Function,

    const Tag = @typeInfo(Info).@"union".tag_type.?;

    pub const Pointer = struct {
        elem_ctype: CType,
        @"const": bool = false,
        @"volatile": bool = false,

        fn tag(pointer_info: Pointer) Pool.Tag {
            return @enumFromInt(@intFromEnum(Pool.Tag.pointer) +
                @as(u2, @bitCast(packed struct(u2) {
                @"const": bool,
                @"volatile": bool,
            }{
                .@"const" = pointer_info.@"const",
                .@"volatile" = pointer_info.@"volatile",
            })));
        }
    };

    pub const Aligned = struct {
        ctype: CType,
        alignas: AlignAs,
    };

    pub const Sequence = struct {
        elem_ctype: CType,
        len: u64,
    };

    pub const AggregateTag = enum { @"enum", @"struct", @"union" };

    pub const Field = struct {
        name: Pool.String,
        ctype: CType,
        alignas: AlignAs,

        pub const Slice = struct {
            extra_index: Pool.ExtraIndex,
            len: u32,

            pub fn at(slice: Field.Slice, index: usize, pool: *const Pool) Field {
                assert(index < slice.len);
                const extra = pool.getExtra(Pool.Field, @intCast(slice.extra_index +
                    index * @typeInfo(Pool.Field).@"struct".fields.len));
                return .{
                    .name = .{ .index = extra.name },
                    .ctype = .{ .index = extra.ctype },
                    .alignas = extra.flags.alignas,
                };
            }

            fn eqlAdapted(
                lhs_slice: Field.Slice,
                lhs_pool: *const Pool,
                rhs_slice: Field.Slice,
                rhs_pool: *const Pool,
                pool_adapter: anytype,
            ) bool {
                if (lhs_slice.len != rhs_slice.len) return false;
                for (0..lhs_slice.len) |index| {
                    if (!lhs_slice.at(index, lhs_pool).eqlAdapted(
                        lhs_pool,
                        rhs_slice.at(index, rhs_pool),
                        rhs_pool,
                        pool_adapter,
                    )) return false;
                }
                return true;
            }
        };

        fn eqlAdapted(
            lhs_field: Field,
            lhs_pool: *const Pool,
            rhs_field: Field,
            rhs_pool: *const Pool,
            pool_adapter: anytype,
        ) bool {
            if (!std.meta.eql(lhs_field.alignas, rhs_field.alignas)) return false;
            if (!pool_adapter.eql(lhs_field.ctype, rhs_field.ctype)) return false;
            return if (lhs_field.name.toPoolSlice(lhs_pool)) |lhs_name|
                if (rhs_field.name.toPoolSlice(rhs_pool)) |rhs_name|
                    std.mem.eql(u8, lhs_name, rhs_name)
                else
                    false
            else
                lhs_field.name.index == rhs_field.name.index;
        }
    };

    pub const FwdDecl = struct {
        tag: AggregateTag,
        name: union(enum) {
            anon: Field.Slice,
            index: InternPool.Index,
        },
    };

    pub const Aggregate = struct {
        tag: AggregateTag,
        @"packed": bool = false,
        name: union(enum) {
            anon: struct {
                index: InternPool.Index,
                id: u32,
            },
            fwd_decl: CType,
        },
        fields: Field.Slice,
    };

    pub const Function = struct {
        return_ctype: CType,
        param_ctypes: CType.Slice,
        varargs: bool = false,
    };

    pub fn eqlAdapted(
        lhs_info: Info,
        lhs_pool: *const Pool,
        rhs_ctype: CType,
        rhs_pool: *const Pool,
        pool_adapter: anytype,
    ) bool {
        const rhs_info = rhs_ctype.info(rhs_pool);
        if (@as(Info.Tag, lhs_info) != @as(Info.Tag, rhs_info)) return false;
        return switch (lhs_info) {
            .basic => |lhs_basic_info| lhs_basic_info == rhs_info.basic,
            .pointer => |lhs_pointer_info| lhs_pointer_info.@"const" == rhs_info.pointer.@"const" and
                lhs_pointer_info.@"volatile" == rhs_info.pointer.@"volatile" and
                pool_adapter.eql(lhs_pointer_info.elem_ctype, rhs_info.pointer.elem_ctype),
            .aligned => |lhs_aligned_info| std.meta.eql(lhs_aligned_info.alignas, rhs_info.aligned.alignas) and
                pool_adapter.eql(lhs_aligned_info.ctype, rhs_info.aligned.ctype),
            .array => |lhs_array_info| lhs_array_info.len == rhs_info.array.len and
                pool_adapter.eql(lhs_array_info.elem_ctype, rhs_info.array.elem_ctype),
            .vector => |lhs_vector_info| lhs_vector_info.len == rhs_info.vector.len and
                pool_adapter.eql(lhs_vector_info.elem_ctype, rhs_info.vector.elem_ctype),
            .fwd_decl => |lhs_fwd_decl_info| lhs_fwd_decl_info.tag == rhs_info.fwd_decl.tag and
                switch (lhs_fwd_decl_info.name) {
                .anon => |lhs_anon| rhs_info.fwd_decl.name == .anon and lhs_anon.eqlAdapted(
                    lhs_pool,
                    rhs_info.fwd_decl.name.anon,
                    rhs_pool,
                    pool_adapter,
                ),
                .index => |lhs_index| rhs_info.fwd_decl.name == .index and
                    lhs_index == rhs_info.fwd_decl.name.index,
            },
            .aggregate => |lhs_aggregate_info| lhs_aggregate_info.tag == rhs_info.aggregate.tag and
                lhs_aggregate_info.@"packed" == rhs_info.aggregate.@"packed" and
                switch (lhs_aggregate_info.name) {
                .anon => |lhs_anon| rhs_info.aggregate.name == .anon and
                    lhs_anon.index == rhs_info.aggregate.name.anon.index and
                    lhs_anon.id == rhs_info.aggregate.name.anon.id,
                .fwd_decl => |lhs_fwd_decl| rhs_info.aggregate.name == .fwd_decl and
                    pool_adapter.eql(lhs_fwd_decl, rhs_info.aggregate.name.fwd_decl),
            } and lhs_aggregate_info.fields.eqlAdapted(
                lhs_pool,
                rhs_info.aggregate.fields,
                rhs_pool,
                pool_adapter,
            ),
            .function => |lhs_function_info| lhs_function_info.param_ctypes.len ==
                rhs_info.function.param_ctypes.len and
                pool_adapter.eql(lhs_function_info.return_ctype, rhs_info.function.return_ctype) and
                for (0..lhs_function_info.param_ctypes.len) |param_index|
            {
                if (!pool_adapter.eql(
                    lhs_function_info.param_ctypes.at(param_index, lhs_pool),
                    rhs_info.function.param_ctypes.at(param_index, rhs_pool),
                )) break false;
            } else true,
        };
    }
};

pub const Pool = struct {
    map: Map,
    items: std.MultiArrayList(Item),
    extra: std.ArrayListUnmanaged(u32),

    string_map: Map,
    string_indices: std.ArrayListUnmanaged(u32),
    string_bytes: std.ArrayListUnmanaged(u8),

    const Map = std.AutoArrayHashMapUnmanaged(void, void);

    pub const String = struct {
        index: String.Index,

        const FormatData = struct { string: String, pool: *const Pool };
        fn format(
            data: FormatData,
            comptime fmt_str: []const u8,
            _: std.fmt.FormatOptions,
            writer: anytype,
        ) @TypeOf(writer).Error!void {
            if (fmt_str.len > 0) @compileError("invalid format string '" ++ fmt_str ++ "'");
            if (data.string.toSlice(data.pool)) |slice|
                try writer.writeAll(slice)
            else
                try writer.print("f{d}", .{@intFromEnum(data.string.index)});
        }
        pub fn fmt(str: String, pool: *const Pool) std.fmt.Formatter(format) {
            return .{ .data = .{ .string = str, .pool = pool } };
        }

        fn fromUnnamed(index: u31) String {
            return .{ .index = @enumFromInt(index) };
        }

        fn isNamed(str: String) bool {
            return @intFromEnum(str.index) >= String.Index.first_named_index;
        }

        pub fn toSlice(str: String, pool: *const Pool) ?[]const u8 {
            return str.toPoolSlice(pool) orelse if (str.isNamed()) @tagName(str.index) else null;
        }

        fn toPoolSlice(str: String, pool: *const Pool) ?[]const u8 {
            if (str.toPoolIndex()) |pool_index| {
                const start = pool.string_indices.items[pool_index + 0];
                const end = pool.string_indices.items[pool_index + 1];
                return pool.string_bytes.items[start..end];
            } else return null;
        }

        fn fromPoolIndex(pool_index: usize) String {
            return .{ .index = @enumFromInt(String.Index.first_pool_index + pool_index) };
        }

        fn toPoolIndex(str: String) ?u32 {
            const pool_index, const is_null =
                @subWithOverflow(@intFromEnum(str.index), String.Index.first_pool_index);
            return switch (is_null) {
                0 => pool_index,
                1 => null,
            };
        }

        const Index = enum(u32) {
            array = first_named_index,
            @"error",
            is_null,
            len,
            payload,
            ptr,
            tag,
            _,

            const first_named_index: u32 = 1 << 31;
            const first_pool_index: u32 = first_named_index + @typeInfo(String.Index).@"enum".fields.len;
        };

        const Adapter = struct {
            pool: *const Pool,
            pub fn hash(_: @This(), slice: []const u8) Map.Hash {
                return @truncate(Hasher.Impl.hash(1, slice));
            }
            pub fn eql(string_adapter: @This(), lhs_slice: []const u8, _: void, rhs_index: usize) bool {
                const rhs_string = String.fromPoolIndex(rhs_index);
                const rhs_slice = rhs_string.toPoolSlice(string_adapter.pool).?;
                return std.mem.eql(u8, lhs_slice, rhs_slice);
            }
        };
    };

    pub const empty: Pool = .{
        .map = .{},
        .items = .{},
        .extra = .{},

        .string_map = .{},
        .string_indices = .{},
        .string_bytes = .{},
    };

    pub fn init(pool: *Pool, allocator: std.mem.Allocator) !void {
        if (pool.string_indices.items.len == 0)
            try pool.string_indices.append(allocator, 0);
    }

    pub fn deinit(pool: *Pool, allocator: std.mem.Allocator) void {
        pool.map.deinit(allocator);
        pool.items.deinit(allocator);
        pool.extra.deinit(allocator);

        pool.string_map.deinit(allocator);
        pool.string_indices.deinit(allocator);
        pool.string_bytes.deinit(allocator);

        pool.* = undefined;
    }

    pub fn move(pool: *Pool) Pool {
        defer pool.* = empty;
        return pool.*;
    }

    pub fn clearRetainingCapacity(pool: *Pool) void {
        pool.map.clearRetainingCapacity();
        pool.items.shrinkRetainingCapacity(0);
        pool.extra.clearRetainingCapacity();

        pool.string_map.clearRetainingCapacity();
        pool.string_indices.shrinkRetainingCapacity(1);
        pool.string_bytes.clearRetainingCapacity();
    }

    pub fn freeUnusedCapacity(pool: *Pool, allocator: std.mem.Allocator) void {
        pool.map.shrinkAndFree(allocator, pool.map.count());
        pool.items.shrinkAndFree(allocator, pool.items.len);
        pool.extra.shrinkAndFree(allocator, pool.extra.items.len);

        pool.string_map.shrinkAndFree(allocator, pool.string_map.count());
        pool.string_indices.shrinkAndFree(allocator, pool.string_indices.items.len);
        pool.string_bytes.shrinkAndFree(allocator, pool.string_bytes.items.len);
    }

    pub fn getPointer(pool: *Pool, allocator: std.mem.Allocator, pointer_info: Info.Pointer) !CType {
        var hasher = Hasher.init;
        hasher.update(pointer_info.elem_ctype.hash(pool));
        return pool.tagData(
            allocator,
            hasher,
            pointer_info.tag(),
            @intFromEnum(pointer_info.elem_ctype.index),
        );
    }

    pub fn getAligned(pool: *Pool, allocator: std.mem.Allocator, aligned_info: Info.Aligned) !CType {
        return pool.tagExtra(allocator, .aligned, Aligned, .{
            .ctype = aligned_info.ctype.index,
            .flags = .{ .alignas = aligned_info.alignas },
        });
    }

    pub fn getArray(pool: *Pool, allocator: std.mem.Allocator, array_info: Info.Sequence) !CType {
        return if (std.math.cast(u32, array_info.len)) |small_len|
            pool.tagExtra(allocator, .array_small, SequenceSmall, .{
                .elem_ctype = array_info.elem_ctype.index,
                .len = small_len,
            })
        else
            pool.tagExtra(allocator, .array_large, SequenceLarge, .{
                .elem_ctype = array_info.elem_ctype.index,
                .len_lo = @truncate(array_info.len >> 0),
                .len_hi = @truncate(array_info.len >> 32),
            });
    }

    pub fn getVector(pool: *Pool, allocator: std.mem.Allocator, vector_info: Info.Sequence) !CType {
        return pool.tagExtra(allocator, .vector, SequenceSmall, .{
            .elem_ctype = vector_info.elem_ctype.index,
            .len = @intCast(vector_info.len),
        });
    }

    pub fn getFwdDecl(
        pool: *Pool,
        allocator: std.mem.Allocator,
        fwd_decl_info: struct {
            tag: Info.AggregateTag,
            name: union(enum) {
                anon: []const Info.Field,
                index: InternPool.Index,
            },
        },
    ) !CType {
        var hasher = Hasher.init;
        switch (fwd_decl_info.name) {
            .anon => |fields| {
                const ExpectedContents = [32]CType;
                var stack align(@max(
                    @alignOf(std.heap.StackFallbackAllocator(0)),
                    @alignOf(ExpectedContents),
                )) = std.heap.stackFallback(@sizeOf(ExpectedContents), allocator);
                const stack_allocator = stack.get();
                const field_ctypes = try stack_allocator.alloc(CType, fields.len);
                defer stack_allocator.free(field_ctypes);
                for (field_ctypes, fields) |*field_ctype, field|
                    field_ctype.* = try field.ctype.toForward(pool, allocator);
                const extra: FwdDeclAnon = .{ .fields_len = @intCast(fields.len) };
                const extra_index = try pool.addExtra(
                    allocator,
                    FwdDeclAnon,
                    extra,
                    fields.len * @typeInfo(Field).@"struct".fields.len,
                );
                for (fields, field_ctypes) |field, field_ctype| pool.addHashedExtraAssumeCapacity(
                    &hasher,
                    Field,
                    .{
                        .name = field.name.index,
                        .ctype = field_ctype.index,
                        .flags = .{ .alignas = field.alignas },
                    },
                );
                hasher.updateExtra(FwdDeclAnon, extra, pool);
                return pool.tagTrailingExtra(allocator, hasher, switch (fwd_decl_info.tag) {
                    .@"struct" => .fwd_decl_struct_anon,
                    .@"union" => .fwd_decl_union_anon,
                    .@"enum" => unreachable,
                }, extra_index);
            },
            .index => |index| {
                hasher.update(index);
                return pool.tagData(allocator, hasher, switch (fwd_decl_info.tag) {
                    .@"struct" => .fwd_decl_struct,
                    .@"union" => .fwd_decl_union,
                    .@"enum" => unreachable,
                }, @intFromEnum(index));
            },
        }
    }

    pub fn getAggregate(
        pool: *Pool,
        allocator: std.mem.Allocator,
        aggregate_info: struct {
            tag: Info.AggregateTag,
            @"packed": bool = false,
            name: union(enum) {
                anon: struct {
                    index: InternPool.Index,
                    id: u32,
                },
                fwd_decl: CType,
            },
            fields: []const Info.Field,
        },
    ) !CType {
        var hasher = Hasher.init;
        switch (aggregate_info.name) {
            .anon => |anon| {
                const extra: AggregateAnon = .{
                    .index = anon.index,
                    .id = anon.id,
                    .fields_len = @intCast(aggregate_info.fields.len),
                };
                const extra_index = try pool.addExtra(
                    allocator,
                    AggregateAnon,
                    extra,
                    aggregate_info.fields.len * @typeInfo(Field).@"struct".fields.len,
                );
                for (aggregate_info.fields) |field| pool.addHashedExtraAssumeCapacity(&hasher, Field, .{
                    .name = field.name.index,
                    .ctype = field.ctype.index,
                    .flags = .{ .alignas = field.alignas },
                });
                hasher.updateExtra(AggregateAnon, extra, pool);
                return pool.tagTrailingExtra(allocator, hasher, switch (aggregate_info.tag) {
                    .@"struct" => switch (aggregate_info.@"packed") {
                        false => .aggregate_struct_anon,
                        true => .aggregate_struct_packed_anon,
                    },
                    .@"union" => switch (aggregate_info.@"packed") {
                        false => .aggregate_union_anon,
                        true => .aggregate_union_packed_anon,
                    },
                    .@"enum" => unreachable,
                }, extra_index);
            },
            .fwd_decl => |fwd_decl| {
                const extra: Aggregate = .{
                    .fwd_decl = fwd_decl.index,
                    .fields_len = @intCast(aggregate_info.fields.len),
                };
                const extra_index = try pool.addExtra(
                    allocator,
                    Aggregate,
                    extra,
                    aggregate_info.fields.len * @typeInfo(Field).@"struct".fields.len,
                );
                for (aggregate_info.fields) |field| pool.addHashedExtraAssumeCapacity(&hasher, Field, .{
                    .name = field.name.index,
                    .ctype = field.ctype.index,
                    .flags = .{ .alignas = field.alignas },
                });
                hasher.updateExtra(Aggregate, extra, pool);
                return pool.tagTrailingExtra(allocator, hasher, switch (aggregate_info.tag) {
                    .@"struct" => switch (aggregate_info.@"packed") {
                        false => .aggregate_struct,
                        true => .aggregate_struct_packed,
                    },
                    .@"union" => switch (aggregate_info.@"packed") {
                        false => .aggregate_union,
                        true => .aggregate_union_packed,
                    },
                    .@"enum" => unreachable,
                }, extra_index);
            },
        }
    }

    pub fn getFunction(
        pool: *Pool,
        allocator: std.mem.Allocator,
        function_info: struct {
            return_ctype: CType,
            param_ctypes: []const CType,
            varargs: bool = false,
        },
    ) !CType {
        var hasher = Hasher.init;
        const extra: Function = .{
            .return_ctype = function_info.return_ctype.index,
            .param_ctypes_len = @intCast(function_info.param_ctypes.len),
        };
        const extra_index = try pool.addExtra(allocator, Function, extra, function_info.param_ctypes.len);
        for (function_info.param_ctypes) |param_ctype| {
            hasher.update(param_ctype.hash(pool));
            pool.extra.appendAssumeCapacity(@intFromEnum(param_ctype.index));
        }
        hasher.updateExtra(Function, extra, pool);
        return pool.tagTrailingExtra(allocator, hasher, switch (function_info.varargs) {
            false => .function,
            true => .function_varargs,
        }, extra_index);
    }

    pub fn fromFields(
        pool: *Pool,
        allocator: std.mem.Allocator,
        tag: Info.AggregateTag,
        fields: []Info.Field,
        kind: Kind,
    ) !CType {
        sortFields(fields);
        const fwd_decl = try pool.getFwdDecl(allocator, .{
            .tag = tag,
            .name = .{ .anon = fields },
        });
        return if (kind.isForward()) fwd_decl else pool.getAggregate(allocator, .{
            .tag = tag,
            .name = .{ .fwd_decl = fwd_decl },
            .fields = fields,
        });
    }

    pub fn fromIntInfo(
        pool: *Pool,
        allocator: std.mem.Allocator,
        int_info: std.builtin.Type.Int,
        mod: *Module,
        kind: Kind,
    ) !CType {
        switch (int_info.bits) {
            0 => return .void,
            1...8 => switch (int_info.signedness) {
                .signed => return .i8,
                .unsigned => return .u8,
            },
            9...16 => switch (int_info.signedness) {
                .signed => return .i16,
                .unsigned => return .u16,
            },
            17...32 => switch (int_info.signedness) {
                .signed => return .i32,
                .unsigned => return .u32,
            },
            33...64 => switch (int_info.signedness) {
                .signed => return .i64,
                .unsigned => return .u64,
            },
            65...128 => switch (int_info.signedness) {
                .signed => return .i128,
                .unsigned => return .u128,
            },
            else => {
                const target = &mod.resolved_target.result;
                const abi_align = Type.intAbiAlignment(int_info.bits, target.*);
                const abi_align_bytes = abi_align.toByteUnits().?;
                const array_ctype = try pool.getArray(allocator, .{
                    .len = @divExact(Type.intAbiSize(int_info.bits, target.*), abi_align_bytes),
                    .elem_ctype = try pool.fromIntInfo(allocator, .{
                        .signedness = .unsigned,
                        .bits = @intCast(abi_align_bytes * 8),
                    }, mod, kind.noParameter()),
                });
                if (!kind.isParameter()) return array_ctype;
                var fields = [_]Info.Field{
                    .{
                        .name = .{ .index = .array },
                        .ctype = array_ctype,
                        .alignas = AlignAs.fromAbiAlignment(abi_align),
                    },
                };
                return pool.fromFields(allocator, .@"struct", &fields, kind);
            },
        }
    }

    pub fn fromType(
        pool: *Pool,
        allocator: std.mem.Allocator,
        scratch: *std.ArrayListUnmanaged(u32),
        ty: Type,
        pt: Zcu.PerThread,
        mod: *Module,
        kind: Kind,
    ) !CType {
        const ip = &pt.zcu.intern_pool;
        const zcu = pt.zcu;
        switch (ty.toIntern()) {
            .u0_type,
            .i0_type,
            .anyopaque_type,
            .void_type,
            .empty_tuple_type,
            .type_type,
            .comptime_int_type,
            .comptime_float_type,
            .null_type,
            .undefined_type,
            .enum_literal_type,
            => return .void,
            .u1_type, .u8_type => return .u8,
            .i8_type => return .i8,
            .u16_type => return .u16,
            .i16_type => return .i16,
            .u29_type, .u32_type => return .u32,
            .i32_type => return .i32,
            .u64_type => return .u64,
            .i64_type => return .i64,
            .u80_type, .u128_type => return .u128,
            .i128_type => return .i128,
            .usize_type => return .usize,
            .isize_type => return .isize,
            .c_char_type => return .{ .index = .char },
            .c_short_type => return .{ .index = .short },
            .c_ushort_type => return .{ .index = .@"unsigned short" },
            .c_int_type => return .{ .index = .int },
            .c_uint_type => return .{ .index = .@"unsigned int" },
            .c_long_type => return .{ .index = .long },
            .c_ulong_type => return .{ .index = .@"unsigned long" },
            .c_longlong_type => return .{ .index = .@"long long" },
            .c_ulonglong_type => return .{ .index = .@"unsigned long long" },
            .c_longdouble_type => return .{ .index = .@"long double" },
            .f16_type => return .f16,
            .f32_type => return .f32,
            .f64_type => return .f64,
            .f80_type => return .f80,
            .f128_type => return .f128,
            .bool_type, .optional_noreturn_type => return .bool,
            .noreturn_type,
            .anyframe_type,
            .generic_poison_type,
            => unreachable,
            .anyerror_type,
            .anyerror_void_error_union_type,
            .adhoc_inferred_error_set_type,
            => return pool.fromIntInfo(allocator, .{
                .signedness = .unsigned,
                .bits = pt.zcu.errorSetBits(),
            }, mod, kind),

            .manyptr_u8_type,
            => return pool.getPointer(allocator, .{
                .elem_ctype = .u8,
            }),
            .manyptr_const_u8_type,
            .manyptr_const_u8_sentinel_0_type,
            => return pool.getPointer(allocator, .{
                .elem_ctype = .u8,
                .@"const" = true,
            }),
            .single_const_pointer_to_comptime_int_type,
            => return pool.getPointer(allocator, .{
                .elem_ctype = .void,
                .@"const" = true,
            }),
            .slice_const_u8_type,
            .slice_const_u8_sentinel_0_type,
            => {
                const target = &mod.resolved_target.result;
                var fields = [_]Info.Field{
                    .{
                        .name = .{ .index = .ptr },
                        .ctype = try pool.getPointer(allocator, .{
                            .elem_ctype = .u8,
                            .@"const" = true,
                        }),
                        .alignas = AlignAs.fromAbiAlignment(Type.ptrAbiAlignment(target.*)),
                    },
                    .{
                        .name = .{ .index = .len },
                        .ctype = .usize,
                        .alignas = AlignAs.fromAbiAlignment(
                            Type.intAbiAlignment(target.ptrBitWidth(), target.*),
                        ),
                    },
                };
                return pool.fromFields(allocator, .@"struct", &fields, kind);
            },

            .vector_16_i8_type => {
                const vector_ctype = try pool.getVector(allocator, .{
                    .elem_ctype = .i8,
                    .len = 16,
                });
                if (!kind.isParameter()) return vector_ctype;
                var fields = [_]Info.Field{
                    .{
                        .name = .{ .index = .array },
                        .ctype = vector_ctype,
                        .alignas = AlignAs.fromAbiAlignment(Type.i8.abiAlignment(zcu)),
                    },
                };
                return pool.fromFields(allocator, .@"struct", &fields, kind);
            },
            .vector_32_i8_type => {
                const vector_ctype = try pool.getVector(allocator, .{
                    .elem_ctype = .i8,
                    .len = 32,
                });
                if (!kind.isParameter()) return vector_ctype;
                var fields = [_]Info.Field{
                    .{
                        .name = .{ .index = .array },
                        .ctype = vector_ctype,
                        .alignas = AlignAs.fromAbiAlignment(Type.i8.abiAlignment(zcu)),
                    },
                };
                return pool.fromFields(allocator, .@"struct", &fields, kind);
            },
            .vector_16_u8_type => {
                const vector_ctype = try pool.getVector(allocator, .{
                    .elem_ctype = .u8,
                    .len = 16,
                });
                if (!kind.isParameter()) return vector_ctype;
                var fields = [_]Info.Field{
                    .{
                        .name = .{ .index = .array },
                        .ctype = vector_ctype,
                        .alignas = AlignAs.fromAbiAlignment(Type.u8.abiAlignment(zcu)),
                    },
                };
                return pool.fromFields(allocator, .@"struct", &fields, kind);
            },
            .vector_32_u8_type => {
                const vector_ctype = try pool.getVector(allocator, .{
                    .elem_ctype = .u8,
                    .len = 32,
                });
                if (!kind.isParameter()) return vector_ctype;
                var fields = [_]Info.Field{
                    .{
                        .name = .{ .index = .array },
                        .ctype = vector_ctype,
                        .alignas = AlignAs.fromAbiAlignment(Type.u8.abiAlignment(zcu)),
                    },
                };
                return pool.fromFields(allocator, .@"struct", &fields, kind);
            },
            .vector_8_i16_type => {
                const vector_ctype = try pool.getVector(allocator, .{
                    .elem_ctype = .i16,
                    .len = 8,
                });
                if (!kind.isParameter()) return vector_ctype;
                var fields = [_]Info.Field{
                    .{
                        .name = .{ .index = .array },
                        .ctype = vector_ctype,
                        .alignas = AlignAs.fromAbiAlignment(Type.i16.abiAlignment(zcu)),
                    },
                };
                return pool.fromFields(allocator, .@"struct", &fields, kind);
            },
            .vector_16_i16_type => {
                const vector_ctype = try pool.getVector(allocator, .{
                    .elem_ctype = .i16,
                    .len = 16,
                });
                if (!kind.isParameter()) return vector_ctype;
                var fields = [_]Info.Field{
                    .{
                        .name = .{ .index = .array },
                        .ctype = vector_ctype,
                        .alignas = AlignAs.fromAbiAlignment(Type.i16.abiAlignment(zcu)),
                    },
                };
                return pool.fromFields(allocator, .@"struct", &fields, kind);
            },
            .vector_8_u16_type => {
                const vector_ctype = try pool.getVector(allocator, .{
                    .elem_ctype = .u16,
                    .len = 8,
                });
                if (!kind.isParameter()) return vector_ctype;
                var fields = [_]Info.Field{
                    .{
                        .name = .{ .index = .array },
                        .ctype = vector_ctype,
                        .alignas = AlignAs.fromAbiAlignment(Type.u16.abiAlignment(zcu)),
                    },
                };
                return pool.fromFields(allocator, .@"struct", &fields, kind);
            },
            .vector_16_u16_type => {
                const vector_ctype = try pool.getVector(allocator, .{
                    .elem_ctype = .u16,
                    .len = 16,
                });
                if (!kind.isParameter()) return vector_ctype;
                var fields = [_]Info.Field{
                    .{
                        .name = .{ .index = .array },
                        .ctype = vector_ctype,
                        .alignas = AlignAs.fromAbiAlignment(Type.u16.abiAlignment(zcu)),
                    },
                };
                return pool.fromFields(allocator, .@"struct", &fields, kind);
            },
            .vector_4_i32_type => {
                const vector_ctype = try pool.getVector(allocator, .{
                    .elem_ctype = .i32,
                    .len = 4,
                });
                if (!kind.isParameter()) return vector_ctype;
                var fields = [_]Info.Field{
                    .{
                        .name = .{ .index = .array },
                        .ctype = vector_ctype,
                        .alignas = AlignAs.fromAbiAlignment(Type.i32.abiAlignment(zcu)),
                    },
                };
                return pool.fromFields(allocator, .@"struct", &fields, kind);
            },
            .vector_8_i32_type => {
                const vector_ctype = try pool.getVector(allocator, .{
                    .elem_ctype = .i32,
                    .len = 8,
                });
                if (!kind.isParameter()) return vector_ctype;
                var fields = [_]Info.Field{
                    .{
                        .name = .{ .index = .array },
                        .ctype = vector_ctype,
                        .alignas = AlignAs.fromAbiAlignment(Type.i32.abiAlignment(zcu)),
                    },
                };
                return pool.fromFields(allocator, .@"struct", &fields, kind);
            },
            .vector_4_u32_type => {
                const vector_ctype = try pool.getVector(allocator, .{
                    .elem_ctype = .u32,
                    .len = 4,
                });
                if (!kind.isParameter()) return vector_ctype;
                var fields = [_]Info.Field{
                    .{
                        .name = .{ .index = .array },
                        .ctype = vector_ctype,
                        .alignas = AlignAs.fromAbiAlignment(Type.u32.abiAlignment(zcu)),
                    },
                };
                return pool.fromFields(allocator, .@"struct", &fields, kind);
            },
            .vector_8_u32_type => {
                const vector_ctype = try pool.getVector(allocator, .{
                    .elem_ctype = .u32,
                    .len = 8,
                });
                if (!kind.isParameter()) return vector_ctype;
                var fields = [_]Info.Field{
                    .{
                        .name = .{ .index = .array },
                        .ctype = vector_ctype,
                        .alignas = AlignAs.fromAbiAlignment(Type.u32.abiAlignment(zcu)),
                    },
                };
                return pool.fromFields(allocator, .@"struct", &fields, kind);
            },
            .vector_2_i64_type => {
                const vector_ctype = try pool.getVector(allocator, .{
                    .elem_ctype = .i64,
                    .len = 2,
                });
                if (!kind.isParameter()) return vector_ctype;
                var fields = [_]Info.Field{
                    .{
                        .name = .{ .index = .array },
                        .ctype = vector_ctype,
                        .alignas = AlignAs.fromAbiAlignment(Type.i64.abiAlignment(zcu)),
                    },
                };
                return pool.fromFields(allocator, .@"struct", &fields, kind);
            },
            .vector_4_i64_type => {
                const vector_ctype = try pool.getVector(allocator, .{
                    .elem_ctype = .i64,
                    .len = 4,
                });
                if (!kind.isParameter()) return vector_ctype;
                var fields = [_]Info.Field{
                    .{
                        .name = .{ .index = .array },
                        .ctype = vector_ctype,
                        .alignas = AlignAs.fromAbiAlignment(Type.i64.abiAlignment(zcu)),
                    },
                };
                return pool.fromFields(allocator, .@"struct", &fields, kind);
            },
            .vector_2_u64_type => {
                const vector_ctype = try pool.getVector(allocator, .{
                    .elem_ctype = .u64,
                    .len = 2,
                });
                if (!kind.isParameter()) return vector_ctype;
                var fields = [_]Info.Field{
                    .{
                        .name = .{ .index = .array },
                        .ctype = vector_ctype,
                        .alignas = AlignAs.fromAbiAlignment(Type.u64.abiAlignment(zcu)),
                    },
                };
                return pool.fromFields(allocator, .@"struct", &fields, kind);
            },
            .vector_4_u64_type => {
                const vector_ctype = try pool.getVector(allocator, .{
                    .elem_ctype = .u64,
                    .len = 4,
                });
                if (!kind.isParameter()) return vector_ctype;
                var fields = [_]Info.Field{
                    .{
                        .name = .{ .index = .array },
                        .ctype = vector_ctype,
                        .alignas = AlignAs.fromAbiAlignment(Type.u64.abiAlignment(zcu)),
                    },
                };
                return pool.fromFields(allocator, .@"struct", &fields, kind);
            },
            .vector_4_f16_type => {
                const vector_ctype = try pool.getVector(allocator, .{
                    .elem_ctype = .f16,
                    .len = 4,
                });
                if (!kind.isParameter()) return vector_ctype;
                var fields = [_]Info.Field{
                    .{
                        .name = .{ .index = .array },
                        .ctype = vector_ctype,
                        .alignas = AlignAs.fromAbiAlignment(Type.f16.abiAlignment(zcu)),
                    },
                };
                return pool.fromFields(allocator, .@"struct", &fields, kind);
            },
            .vector_8_f16_type => {
                const vector_ctype = try pool.getVector(allocator, .{
                    .elem_ctype = .f16,
                    .len = 8,
                });
                if (!kind.isParameter()) return vector_ctype;
                var fields = [_]Info.Field{
                    .{
                        .name = .{ .index = .array },
                        .ctype = vector_ctype,
                        .alignas = AlignAs.fromAbiAlignment(Type.f16.abiAlignment(zcu)),
                    },
                };
                return pool.fromFields(allocator, .@"struct", &fields, kind);
            },
            .vector_2_f32_type => {
                const vector_ctype = try pool.getVector(allocator, .{
                    .elem_ctype = .f32,
                    .len = 2,
                });
                if (!kind.isParameter()) return vector_ctype;
                var fields = [_]Info.Field{
                    .{
                        .name = .{ .index = .array },
                        .ctype = vector_ctype,
                        .alignas = AlignAs.fromAbiAlignment(Type.f32.abiAlignment(zcu)),
                    },
                };
                return pool.fromFields(allocator, .@"struct", &fields, kind);
            },
            .vector_4_f32_type => {
                const vector_ctype = try pool.getVector(allocator, .{
                    .elem_ctype = .f32,
                    .len = 4,
                });
                if (!kind.isParameter()) return vector_ctype;
                var fields = [_]Info.Field{
                    .{
                        .name = .{ .index = .array },
                        .ctype = vector_ctype,
                        .alignas = AlignAs.fromAbiAlignment(Type.f32.abiAlignment(zcu)),
                    },
                };
                return pool.fromFields(allocator, .@"struct", &fields, kind);
            },
            .vector_8_f32_type => {
                const vector_ctype = try pool.getVector(allocator, .{
                    .elem_ctype = .f32,
                    .len = 8,
                });
                if (!kind.isParameter()) return vector_ctype;
                var fields = [_]Info.Field{
                    .{
                        .name = .{ .index = .array },
                        .ctype = vector_ctype,
                        .alignas = AlignAs.fromAbiAlignment(Type.f32.abiAlignment(zcu)),
                    },
                };
                return pool.fromFields(allocator, .@"struct", &fields, kind);
            },
            .vector_2_f64_type => {
                const vector_ctype = try pool.getVector(allocator, .{
                    .elem_ctype = .f64,
                    .len = 2,
                });
                if (!kind.isParameter()) return vector_ctype;
                var fields = [_]Info.Field{
                    .{
                        .name = .{ .index = .array },
                        .ctype = vector_ctype,
                        .alignas = AlignAs.fromAbiAlignment(Type.f64.abiAlignment(zcu)),
                    },
                };
                return pool.fromFields(allocator, .@"struct", &fields, kind);
            },
            .vector_4_f64_type => {
                const vector_ctype = try pool.getVector(allocator, .{
                    .elem_ctype = .f64,
                    .len = 4,
                });
                if (!kind.isParameter()) return vector_ctype;
                var fields = [_]Info.Field{
                    .{
                        .name = .{ .index = .array },
                        .ctype = vector_ctype,
                        .alignas = AlignAs.fromAbiAlignment(Type.f64.abiAlignment(zcu)),
                    },
                };
                return pool.fromFields(allocator, .@"struct", &fields, kind);
            },

            .undef,
            .zero,
            .zero_usize,
            .zero_u8,
            .one,
            .one_usize,
            .one_u8,
            .four_u8,
            .negative_one,
            .void_value,
            .unreachable_value,
            .null_value,
            .bool_true,
            .bool_false,
            .empty_tuple,
            .none,
            => unreachable,

            _ => |ip_index| switch (ip.indexToKey(ip_index)) {
                .int_type => |int_info| return pool.fromIntInfo(allocator, int_info, mod, kind),
                .ptr_type => |ptr_info| switch (ptr_info.flags.size) {
                    .one, .many, .c => {
                        const elem_ctype = elem_ctype: {
                            if (ptr_info.packed_offset.host_size > 0 and
                                ptr_info.flags.vector_index == .none)
                                break :elem_ctype try pool.fromIntInfo(allocator, .{
                                    .signedness = .unsigned,
                                    .bits = ptr_info.packed_offset.host_size * 8,
                                }, mod, .forward);
                            const elem: Info.Aligned = .{
                                .ctype = try pool.fromType(
                                    allocator,
                                    scratch,
                                    Type.fromInterned(ptr_info.child),
                                    pt,
                                    mod,
                                    .forward,
                                ),
                                .alignas = AlignAs.fromAlignment(.{
                                    .@"align" = ptr_info.flags.alignment,
                                    .abi = Type.fromInterned(ptr_info.child).abiAlignment(zcu),
                                }),
                            };
                            break :elem_ctype if (elem.alignas.abiOrder().compare(.gte))
                                elem.ctype
                            else
                                try pool.getAligned(allocator, elem);
                        };
                        const elem_tag: Info.Tag = switch (elem_ctype.info(pool)) {
                            .aligned => |aligned_info| aligned_info.ctype.info(pool),
                            else => |elem_tag| elem_tag,
                        };
                        return pool.getPointer(allocator, .{
                            .elem_ctype = elem_ctype,
                            .@"const" = switch (elem_tag) {
                                .basic,
                                .pointer,
                                .aligned,
                                .array,
                                .vector,
                                .fwd_decl,
                                .aggregate,
                                => ptr_info.flags.is_const,
                                .function => false,
                            },
                            .@"volatile" = ptr_info.flags.is_volatile,
                        });
                    },
                    .slice => {
                        const target = &mod.resolved_target.result;
                        var fields = [_]Info.Field{
                            .{
                                .name = .{ .index = .ptr },
                                .ctype = try pool.fromType(
                                    allocator,
                                    scratch,
                                    Type.fromInterned(ip.slicePtrType(ip_index)),
                                    pt,
                                    mod,
                                    kind,
                                ),
                                .alignas = AlignAs.fromAbiAlignment(Type.ptrAbiAlignment(target.*)),
                            },
                            .{
                                .name = .{ .index = .len },
                                .ctype = .usize,
                                .alignas = AlignAs.fromAbiAlignment(
                                    Type.intAbiAlignment(target.ptrBitWidth(), target.*),
                                ),
                            },
                        };
                        return pool.fromFields(allocator, .@"struct", &fields, kind);
                    },
                },
                .array_type => |array_info| {
                    const len = array_info.lenIncludingSentinel();
                    if (len == 0) return .void;
                    const elem_type = Type.fromInterned(array_info.child);
                    const elem_ctype = try pool.fromType(
                        allocator,
                        scratch,
                        elem_type,
                        pt,
                        mod,
                        kind.noParameter().asComplete(),
                    );
                    if (elem_ctype.index == .void) return .void;
                    const array_ctype = try pool.getArray(allocator, .{
                        .elem_ctype = elem_ctype,
                        .len = len,
                    });
                    if (!kind.isParameter()) return array_ctype;
                    var fields = [_]Info.Field{
                        .{
                            .name = .{ .index = .array },
                            .ctype = array_ctype,
                            .alignas = AlignAs.fromAbiAlignment(elem_type.abiAlignment(zcu)),
                        },
                    };
                    return pool.fromFields(allocator, .@"struct", &fields, kind);
                },
                .vector_type => |vector_info| {
                    if (vector_info.len == 0) return .void;
                    const elem_type = Type.fromInterned(vector_info.child);
                    const elem_ctype = try pool.fromType(
                        allocator,
                        scratch,
                        elem_type,
                        pt,
                        mod,
                        kind.noParameter().asComplete(),
                    );
                    if (elem_ctype.index == .void) return .void;
                    const vector_ctype = try pool.getVector(allocator, .{
                        .elem_ctype = elem_ctype,
                        .len = vector_info.len,
                    });
                    if (!kind.isParameter()) return vector_ctype;
                    var fields = [_]Info.Field{
                        .{
                            .name = .{ .index = .array },
                            .ctype = vector_ctype,
                            .alignas = AlignAs.fromAbiAlignment(elem_type.abiAlignment(zcu)),
                        },
                    };
                    return pool.fromFields(allocator, .@"struct", &fields, kind);
                },
                .opt_type => |payload_type| {
                    if (ip.isNoReturn(payload_type)) return .void;
                    const payload_ctype = try pool.fromType(
                        allocator,
                        scratch,
                        Type.fromInterned(payload_type),
                        pt,
                        mod,
                        kind.noParameter(),
                    );
                    if (payload_ctype.index == .void) return .bool;
                    switch (payload_type) {
                        .anyerror_type => return payload_ctype,
                        else => switch (ip.indexToKey(payload_type)) {
                            .ptr_type => |payload_ptr_info| if (payload_ptr_info.flags.size != .c and
                                !payload_ptr_info.flags.is_allowzero) return payload_ctype,
                            .error_set_type, .inferred_error_set_type => return payload_ctype,
                            else => {},
                        },
                    }
                    var fields = [_]Info.Field{
                        .{
                            .name = .{ .index = .is_null },
                            .ctype = .bool,
                            .alignas = AlignAs.fromAbiAlignment(.@"1"),
                        },
                        .{
                            .name = .{ .index = .payload },
                            .ctype = payload_ctype,
                            .alignas = AlignAs.fromAbiAlignment(
                                Type.fromInterned(payload_type).abiAlignment(zcu),
                            ),
                        },
                    };
                    return pool.fromFields(allocator, .@"struct", &fields, kind);
                },
                .anyframe_type => unreachable,
                .error_union_type => |error_union_info| {
                    const error_set_bits = pt.zcu.errorSetBits();
                    const error_set_ctype = try pool.fromIntInfo(allocator, .{
                        .signedness = .unsigned,
                        .bits = error_set_bits,
                    }, mod, kind);
                    if (ip.isNoReturn(error_union_info.payload_type)) return error_set_ctype;
                    const payload_type = Type.fromInterned(error_union_info.payload_type);
                    const payload_ctype = try pool.fromType(
                        allocator,
                        scratch,
                        payload_type,
                        pt,
                        mod,
                        kind.noParameter(),
                    );
                    if (payload_ctype.index == .void) return error_set_ctype;
                    const target = &mod.resolved_target.result;
                    var fields = [_]Info.Field{
                        .{
                            .name = .{ .index = .@"error" },
                            .ctype = error_set_ctype,
                            .alignas = AlignAs.fromAbiAlignment(
                                Type.intAbiAlignment(error_set_bits, target.*),
                            ),
                        },
                        .{
                            .name = .{ .index = .payload },
                            .ctype = payload_ctype,
                            .alignas = AlignAs.fromAbiAlignment(payload_type.abiAlignment(zcu)),
                        },
                    };
                    return pool.fromFields(allocator, .@"struct", &fields, kind);
                },
                .simple_type => unreachable,
                .struct_type => {
                    const loaded_struct = ip.loadStructType(ip_index);
                    switch (loaded_struct.layout) {
                        .auto, .@"extern" => {
                            const fwd_decl = try pool.getFwdDecl(allocator, .{
                                .tag = .@"struct",
                                .name = .{ .index = ip_index },
                            });
                            if (kind.isForward()) return if (ty.hasRuntimeBitsIgnoreComptime(zcu))
                                fwd_decl
                            else
                                .void;
                            const scratch_top = scratch.items.len;
                            defer scratch.shrinkRetainingCapacity(scratch_top);
                            try scratch.ensureUnusedCapacity(
                                allocator,
                                loaded_struct.field_types.len * @typeInfo(Field).@"struct".fields.len,
                            );
                            var hasher = Hasher.init;
                            var tag: Pool.Tag = .aggregate_struct;
                            var field_it = loaded_struct.iterateRuntimeOrder(ip);
                            while (field_it.next()) |field_index| {
                                const field_type = Type.fromInterned(
                                    loaded_struct.field_types.get(ip)[field_index],
                                );
                                const field_ctype = try pool.fromType(
                                    allocator,
                                    scratch,
                                    field_type,
                                    pt,
                                    mod,
                                    kind.noParameter(),
                                );
                                if (field_ctype.index == .void) continue;
                                const field_name = if (loaded_struct.fieldName(ip, field_index)
                                    .unwrap()) |field_name|
                                    try pool.string(allocator, field_name.toSlice(ip))
                                else
                                    String.fromUnnamed(@intCast(field_index));
                                const field_alignas = AlignAs.fromAlignment(.{
                                    .@"align" = loaded_struct.fieldAlign(ip, field_index),
                                    .abi = field_type.abiAlignment(zcu),
                                });
                                pool.addHashedExtraAssumeCapacityTo(scratch, &hasher, Field, .{
                                    .name = field_name.index,
                                    .ctype = field_ctype.index,
                                    .flags = .{ .alignas = field_alignas },
                                });
                                if (field_alignas.abiOrder().compare(.lt))
                                    tag = .aggregate_struct_packed;
                            }
                            const fields_len: u32 = @intCast(@divExact(
                                scratch.items.len - scratch_top,
                                @typeInfo(Field).@"struct".fields.len,
                            ));
                            if (fields_len == 0) return .void;
                            try pool.ensureUnusedCapacity(allocator, 1);
                            const extra_index = try pool.addHashedExtra(allocator, &hasher, Aggregate, .{
                                .fwd_decl = fwd_decl.index,
                                .fields_len = fields_len,
                            }, fields_len * @typeInfo(Field).@"struct".fields.len);
                            pool.extra.appendSliceAssumeCapacity(scratch.items[scratch_top..]);
                            return pool.tagTrailingExtraAssumeCapacity(hasher, tag, extra_index);
                        },
                        .@"packed" => return pool.fromType(
                            allocator,
                            scratch,
                            Type.fromInterned(loaded_struct.backingIntTypeUnordered(ip)),
                            pt,
                            mod,
                            kind,
                        ),
                    }
                },
                .tuple_type => |tuple_info| {
                    const scratch_top = scratch.items.len;
                    defer scratch.shrinkRetainingCapacity(scratch_top);
                    try scratch.ensureUnusedCapacity(allocator, tuple_info.types.len *
                        @typeInfo(Field).@"struct".fields.len);
                    var hasher = Hasher.init;
                    for (0..tuple_info.types.len) |field_index| {
                        if (tuple_info.values.get(ip)[field_index] != .none) continue;
                        const field_type = Type.fromInterned(
                            tuple_info.types.get(ip)[field_index],
                        );
                        const field_ctype = try pool.fromType(
                            allocator,
                            scratch,
                            field_type,
                            pt,
                            mod,
                            kind.noParameter(),
                        );
                        if (field_ctype.index == .void) continue;
                        const field_name = try pool.fmt(allocator, "f{d}", .{field_index});
                        pool.addHashedExtraAssumeCapacityTo(scratch, &hasher, Field, .{
                            .name = field_name.index,
                            .ctype = field_ctype.index,
                            .flags = .{ .alignas = AlignAs.fromAbiAlignment(
                                field_type.abiAlignment(zcu),
                            ) },
                        });
                    }
                    const fields_len: u32 = @intCast(@divExact(
                        scratch.items.len - scratch_top,
                        @typeInfo(Field).@"struct".fields.len,
                    ));
                    if (fields_len == 0) return .void;
                    if (kind.isForward()) {
                        try pool.ensureUnusedCapacity(allocator, 1);
                        const extra_index = try pool.addHashedExtra(
                            allocator,
                            &hasher,
                            FwdDeclAnon,
                            .{ .fields_len = fields_len },
                            fields_len * @typeInfo(Field).@"struct".fields.len,
                        );
                        pool.extra.appendSliceAssumeCapacity(scratch.items[scratch_top..]);
                        return pool.tagTrailingExtra(
                            allocator,
                            hasher,
                            .fwd_decl_struct_anon,
                            extra_index,
                        );
                    }
                    const fwd_decl = try pool.fromType(allocator, scratch, ty, pt, mod, .forward);
                    try pool.ensureUnusedCapacity(allocator, 1);
                    const extra_index = try pool.addHashedExtra(allocator, &hasher, Aggregate, .{
                        .fwd_decl = fwd_decl.index,
                        .fields_len = fields_len,
                    }, fields_len * @typeInfo(Field).@"struct".fields.len);
                    pool.extra.appendSliceAssumeCapacity(scratch.items[scratch_top..]);
                    return pool.tagTrailingExtraAssumeCapacity(hasher, .aggregate_struct, extra_index);
                },
                .union_type => {
                    const loaded_union = ip.loadUnionType(ip_index);
                    switch (loaded_union.flagsUnordered(ip).layout) {
                        .auto, .@"extern" => {
                            const has_tag = loaded_union.hasTag(ip);
                            const fwd_decl = try pool.getFwdDecl(allocator, .{
                                .tag = if (has_tag) .@"struct" else .@"union",
                                .name = .{ .index = ip_index },
                            });
                            if (kind.isForward()) return if (ty.hasRuntimeBitsIgnoreComptime(zcu))
                                fwd_decl
                            else
                                .void;
                            const loaded_tag = loaded_union.loadTagType(ip);
                            const scratch_top = scratch.items.len;
                            defer scratch.shrinkRetainingCapacity(scratch_top);
                            try scratch.ensureUnusedCapacity(
                                allocator,
                                loaded_union.field_types.len * @typeInfo(Field).@"struct".fields.len,
                            );
                            var hasher = Hasher.init;
                            var tag: Pool.Tag = .aggregate_union;
                            var payload_align: InternPool.Alignment = .@"1";
                            for (0..loaded_union.field_types.len) |field_index| {
                                const field_type = Type.fromInterned(
                                    loaded_union.field_types.get(ip)[field_index],
                                );
                                if (ip.isNoReturn(field_type.toIntern())) continue;
                                const field_ctype = try pool.fromType(
                                    allocator,
                                    scratch,
                                    field_type,
                                    pt,
                                    mod,
                                    kind.noParameter(),
                                );
                                if (field_ctype.index == .void) continue;
                                const field_name = try pool.string(
                                    allocator,
                                    loaded_tag.names.get(ip)[field_index].toSlice(ip),
                                );
                                const field_alignas = AlignAs.fromAlignment(.{
                                    .@"align" = loaded_union.fieldAlign(ip, field_index),
                                    .abi = field_type.abiAlignment(zcu),
                                });
                                pool.addHashedExtraAssumeCapacityTo(scratch, &hasher, Field, .{
                                    .name = field_name.index,
                                    .ctype = field_ctype.index,
                                    .flags = .{ .alignas = field_alignas },
                                });
                                if (field_alignas.abiOrder().compare(.lt))
                                    tag = .aggregate_union_packed;
                                payload_align = payload_align.maxStrict(field_alignas.@"align");
                            }
                            const fields_len: u32 = @intCast(@divExact(
                                scratch.items.len - scratch_top,
                                @typeInfo(Field).@"struct".fields.len,
                            ));
                            if (!has_tag) {
                                if (fields_len == 0) return .void;
                                try pool.ensureUnusedCapacity(allocator, 1);
                                const extra_index = try pool.addHashedExtra(
                                    allocator,
                                    &hasher,
                                    Aggregate,
                                    .{ .fwd_decl = fwd_decl.index, .fields_len = fields_len },
                                    fields_len * @typeInfo(Field).@"struct".fields.len,
                                );
                                pool.extra.appendSliceAssumeCapacity(scratch.items[scratch_top..]);
                                return pool.tagTrailingExtraAssumeCapacity(hasher, tag, extra_index);
                            }
                            try pool.ensureUnusedCapacity(allocator, 2);
                            var struct_fields: [2]Info.Field = undefined;
                            var struct_fields_len: usize = 0;
                            if (loaded_tag.tag_ty != .comptime_int_type) {
                                const tag_type = Type.fromInterned(loaded_tag.tag_ty);
                                const tag_ctype: CType = try pool.fromType(
                                    allocator,
                                    scratch,
                                    tag_type,
                                    pt,
                                    mod,
                                    kind.noParameter(),
                                );
                                if (tag_ctype.index != .void) {
                                    struct_fields[struct_fields_len] = .{
                                        .name = .{ .index = .tag },
                                        .ctype = tag_ctype,
                                        .alignas = AlignAs.fromAbiAlignment(tag_type.abiAlignment(zcu)),
                                    };
                                    struct_fields_len += 1;
                                }
                            }
                            if (fields_len > 0) {
                                const payload_ctype = payload_ctype: {
                                    const extra_index = try pool.addHashedExtra(
                                        allocator,
                                        &hasher,
                                        AggregateAnon,
                                        .{
                                            .index = ip_index,
                                            .id = 0,
                                            .fields_len = fields_len,
                                        },
                                        fields_len * @typeInfo(Field).@"struct".fields.len,
                                    );
                                    pool.extra.appendSliceAssumeCapacity(scratch.items[scratch_top..]);
                                    break :payload_ctype pool.tagTrailingExtraAssumeCapacity(
                                        hasher,
                                        switch (tag) {
                                            .aggregate_union => .aggregate_union_anon,
                                            .aggregate_union_packed => .aggregate_union_packed_anon,
                                            else => unreachable,
                                        },
                                        extra_index,
                                    );
                                };
                                if (payload_ctype.index != .void) {
                                    struct_fields[struct_fields_len] = .{
                                        .name = .{ .index = .payload },
                                        .ctype = payload_ctype,
                                        .alignas = AlignAs.fromAbiAlignment(payload_align),
                                    };
                                    struct_fields_len += 1;
                                }
                            }
                            if (struct_fields_len == 0) return .void;
                            sortFields(struct_fields[0..struct_fields_len]);
                            return pool.getAggregate(allocator, .{
                                .tag = .@"struct",
                                .name = .{ .fwd_decl = fwd_decl },
                                .fields = struct_fields[0..struct_fields_len],
                            });
                        },
                        .@"packed" => return pool.fromIntInfo(allocator, .{
                            .signedness = .unsigned,
                            .bits = @intCast(ty.bitSize(zcu)),
                        }, mod, kind),
                    }
                },
                .opaque_type => return .void,
                .enum_type => return pool.fromType(
                    allocator,
                    scratch,
                    Type.fromInterned(ip.loadEnumType(ip_index).tag_ty),
                    pt,
                    mod,
                    kind,
                ),
                .func_type => |func_info| if (func_info.is_generic) return .void else {
                    const scratch_top = scratch.items.len;
                    defer scratch.shrinkRetainingCapacity(scratch_top);
                    try scratch.ensureUnusedCapacity(allocator, func_info.param_types.len);
                    var hasher = Hasher.init;
                    const return_type = Type.fromInterned(func_info.return_type);
                    const return_ctype: CType =
                        if (!ip.isNoReturn(func_info.return_type)) try pool.fromType(
                        allocator,
                        scratch,
                        return_type,
                        pt,
                        mod,
                        kind.asParameter(),
                    ) else .void;
                    for (0..func_info.param_types.len) |param_index| {
                        const param_type = Type.fromInterned(
                            func_info.param_types.get(ip)[param_index],
                        );
                        const param_ctype = try pool.fromType(
                            allocator,
                            scratch,
                            param_type,
                            pt,
                            mod,
                            kind.asParameter(),
                        );
                        if (param_ctype.index == .void) continue;
                        hasher.update(param_ctype.hash(pool));
                        scratch.appendAssumeCapacity(@intFromEnum(param_ctype.index));
                    }
                    const param_ctypes_len: u32 = @intCast(scratch.items.len - scratch_top);
                    try pool.ensureUnusedCapacity(allocator, 1);
                    const extra_index = try pool.addHashedExtra(allocator, &hasher, Function, .{
                        .return_ctype = return_ctype.index,
                        .param_ctypes_len = param_ctypes_len,
                    }, param_ctypes_len);
                    pool.extra.appendSliceAssumeCapacity(scratch.items[scratch_top..]);
                    return pool.tagTrailingExtraAssumeCapacity(hasher, switch (func_info.is_var_args) {
                        false => .function,
                        true => .function_varargs,
                    }, extra_index);
                },
                .error_set_type,
                .inferred_error_set_type,
                => return pool.fromIntInfo(allocator, .{
                    .signedness = .unsigned,
                    .bits = pt.zcu.errorSetBits(),
                }, mod, kind),

                .undef,
                .simple_value,
                .variable,
                .@"extern",
                .func,
                .int,
                .err,
                .error_union,
                .enum_literal,
                .enum_tag,
                .empty_enum_value,
                .float,
                .ptr,
                .slice,
                .opt,
                .aggregate,
                .un,
                .memoized_call,
                => unreachable, // values, not types
            },
        }
    }

    pub fn getOrPutAdapted(
        pool: *Pool,
        allocator: std.mem.Allocator,
        source_pool: *const Pool,
        source_ctype: CType,
        pool_adapter: anytype,
    ) !struct { CType, bool } {
        const tag = source_pool.items.items(.tag)[
            source_ctype.toPoolIndex() orelse return .{ source_ctype, true }
        ];
        try pool.ensureUnusedCapacity(allocator, 1);
        const CTypeAdapter = struct {
            pool: *const Pool,
            source_pool: *const Pool,
            source_info: Info,
            pool_adapter: @TypeOf(pool_adapter),
            pub fn hash(map_adapter: @This(), key_ctype: CType) Map.Hash {
                return key_ctype.hash(map_adapter.source_pool);
            }
            pub fn eql(map_adapter: @This(), _: CType, _: void, pool_index: usize) bool {
                return map_adapter.source_info.eqlAdapted(
                    map_adapter.source_pool,
                    .fromPoolIndex(pool_index),
                    map_adapter.pool,
                    map_adapter.pool_adapter,
                );
            }
        };
        const source_info = source_ctype.info(source_pool);
        const gop = pool.map.getOrPutAssumeCapacityAdapted(source_ctype, CTypeAdapter{
            .pool = pool,
            .source_pool = source_pool,
            .source_info = source_info,
            .pool_adapter = pool_adapter,
        });
        errdefer _ = pool.map.pop();
        const ctype: CType = .fromPoolIndex(gop.index);
        if (!gop.found_existing) switch (source_info) {
            .basic => unreachable,
            .pointer => |pointer_info| pool.items.appendAssumeCapacity(.{
                .tag = tag,
                .data = @intFromEnum(pool_adapter.copy(pointer_info.elem_ctype).index),
            }),
            .aligned => |aligned_info| pool.items.appendAssumeCapacity(.{
                .tag = tag,
                .data = try pool.addExtra(allocator, Aligned, .{
                    .ctype = pool_adapter.copy(aligned_info.ctype).index,
                    .flags = .{ .alignas = aligned_info.alignas },
                }, 0),
            }),
            .array, .vector => |sequence_info| pool.items.appendAssumeCapacity(.{
                .tag = tag,
                .data = switch (tag) {
                    .array_small, .vector => try pool.addExtra(allocator, SequenceSmall, .{
                        .elem_ctype = pool_adapter.copy(sequence_info.elem_ctype).index,
                        .len = @intCast(sequence_info.len),
                    }, 0),
                    .array_large => try pool.addExtra(allocator, SequenceLarge, .{
                        .elem_ctype = pool_adapter.copy(sequence_info.elem_ctype).index,
                        .len_lo = @truncate(sequence_info.len >> 0),
                        .len_hi = @truncate(sequence_info.len >> 32),
                    }, 0),
                    else => unreachable,
                },
            }),
            .fwd_decl => |fwd_decl_info| switch (fwd_decl_info.name) {
                .anon => |fields| {
                    pool.items.appendAssumeCapacity(.{
                        .tag = tag,
                        .data = try pool.addExtra(allocator, FwdDeclAnon, .{
                            .fields_len = fields.len,
                        }, fields.len * @typeInfo(Field).@"struct".fields.len),
                    });
                    for (0..fields.len) |field_index| {
                        const field = fields.at(field_index, source_pool);
                        const field_name = if (field.name.toPoolSlice(source_pool)) |slice|
                            try pool.string(allocator, slice)
                        else
                            field.name;
                        pool.addExtraAssumeCapacity(Field, .{
                            .name = field_name.index,
                            .ctype = pool_adapter.copy(field.ctype).index,
                            .flags = .{ .alignas = field.alignas },
                        });
                    }
                },
                .index => |index| pool.items.appendAssumeCapacity(.{
                    .tag = tag,
                    .data = @intFromEnum(index),
                }),
            },
            .aggregate => |aggregate_info| {
                pool.items.appendAssumeCapacity(.{
                    .tag = tag,
                    .data = switch (aggregate_info.name) {
                        .anon => |anon| try pool.addExtra(allocator, AggregateAnon, .{
                            .index = anon.index,
                            .id = anon.id,
                            .fields_len = aggregate_info.fields.len,
                        }, aggregate_info.fields.len * @typeInfo(Field).@"struct".fields.len),
                        .fwd_decl => |fwd_decl| try pool.addExtra(allocator, Aggregate, .{
                            .fwd_decl = pool_adapter.copy(fwd_decl).index,
                            .fields_len = aggregate_info.fields.len,
                        }, aggregate_info.fields.len * @typeInfo(Field).@"struct".fields.len),
                    },
                });
                for (0..aggregate_info.fields.len) |field_index| {
                    const field = aggregate_info.fields.at(field_index, source_pool);
                    const field_name = if (field.name.toPoolSlice(source_pool)) |slice|
                        try pool.string(allocator, slice)
                    else
                        field.name;
                    pool.addExtraAssumeCapacity(Field, .{
                        .name = field_name.index,
                        .ctype = pool_adapter.copy(field.ctype).index,
                        .flags = .{ .alignas = field.alignas },
                    });
                }
            },
            .function => |function_info| {
                pool.items.appendAssumeCapacity(.{
                    .tag = tag,
                    .data = try pool.addExtra(allocator, Function, .{
                        .return_ctype = pool_adapter.copy(function_info.return_ctype).index,
                        .param_ctypes_len = function_info.param_ctypes.len,
                    }, function_info.param_ctypes.len),
                });
                for (0..function_info.param_ctypes.len) |param_index| pool.extra.appendAssumeCapacity(
                    @intFromEnum(pool_adapter.copy(
                        function_info.param_ctypes.at(param_index, source_pool),
                    ).index),
                );
            },
        };
        assert(source_info.eqlAdapted(source_pool, ctype, pool, pool_adapter));
        assert(source_ctype.hash(source_pool) == ctype.hash(pool));
        return .{ ctype, gop.found_existing };
    }

    pub fn string(pool: *Pool, allocator: std.mem.Allocator, slice: []const u8) !String {
        try pool.string_bytes.appendSlice(allocator, slice);
        return pool.trailingString(allocator);
    }

    pub fn fmt(
        pool: *Pool,
        allocator: std.mem.Allocator,
        comptime fmt_str: []const u8,
        fmt_args: anytype,
    ) !String {
        try pool.string_bytes.writer(allocator).print(fmt_str, fmt_args);
        return pool.trailingString(allocator);
    }

    fn ensureUnusedCapacity(pool: *Pool, allocator: std.mem.Allocator, len: u32) !void {
        try pool.map.ensureUnusedCapacity(allocator, len);
        try pool.items.ensureUnusedCapacity(allocator, len);
    }

    const Hasher = struct {
        const Impl = std.hash.Wyhash;
        impl: Impl,

        const init: Hasher = .{ .impl = Impl.init(0) };

        fn updateExtra(hasher: *Hasher, comptime Extra: type, extra: Extra, pool: *const Pool) void {
            inline for (@typeInfo(Extra).@"struct".fields) |field| {
                const value = @field(extra, field.name);
                switch (field.type) {
                    Pool.Tag, String, CType => unreachable,
                    CType.Index => hasher.update((CType{ .index = value }).hash(pool)),
                    String.Index => if ((String{ .index = value }).toPoolSlice(pool)) |slice|
                        hasher.update(slice)
                    else
                        hasher.update(@intFromEnum(value)),
                    else => hasher.update(value),
                }
            }
        }
        fn update(hasher: *Hasher, data: anytype) void {
            switch (@TypeOf(data)) {
                Pool.Tag => @compileError("pass tag to final"),
                CType, CType.Index => @compileError("hash ctype.hash(pool) instead"),
                String, String.Index => @compileError("hash string.slice(pool) instead"),
                u32, InternPool.Index, Aligned.Flags => hasher.impl.update(std.mem.asBytes(&data)),
                []const u8 => hasher.impl.update(data),
                else => @compileError("unhandled type: " ++ @typeName(@TypeOf(data))),
            }
        }

        fn final(hasher: Hasher, tag: Pool.Tag) Map.Hash {
            var impl = hasher.impl;
            impl.update(std.mem.asBytes(&tag));
            return @truncate(impl.final());
        }
    };

    fn tagData(
        pool: *Pool,
        allocator: std.mem.Allocator,
        hasher: Hasher,
        tag: Pool.Tag,
        data: u32,
    ) !CType {
        try pool.ensureUnusedCapacity(allocator, 1);
        const Key = struct { hash: Map.Hash, tag: Pool.Tag, data: u32 };
        const CTypeAdapter = struct {
            pool: *const Pool,
            pub fn hash(_: @This(), key: Key) Map.Hash {
                return key.hash;
            }
            pub fn eql(ctype_adapter: @This(), lhs_key: Key, _: void, rhs_index: usize) bool {
                const rhs_item = ctype_adapter.pool.items.get(rhs_index);
                return lhs_key.tag == rhs_item.tag and lhs_key.data == rhs_item.data;
            }
        };
        const gop = pool.map.getOrPutAssumeCapacityAdapted(
            Key{ .hash = hasher.final(tag), .tag = tag, .data = data },
            CTypeAdapter{ .pool = pool },
        );
        if (!gop.found_existing) pool.items.appendAssumeCapacity(.{ .tag = tag, .data = data });
        return .fromPoolIndex(gop.index);
    }

    fn tagExtra(
        pool: *Pool,
        allocator: std.mem.Allocator,
        tag: Pool.Tag,
        comptime Extra: type,
        extra: Extra,
    ) !CType {
        var hasher = Hasher.init;
        hasher.updateExtra(Extra, extra, pool);
        return pool.tagTrailingExtra(
            allocator,
            hasher,
            tag,
            try pool.addExtra(allocator, Extra, extra, 0),
        );
    }

    fn tagTrailingExtra(
        pool: *Pool,
        allocator: std.mem.Allocator,
        hasher: Hasher,
        tag: Pool.Tag,
        extra_index: ExtraIndex,
    ) !CType {
        try pool.ensureUnusedCapacity(allocator, 1);
        return pool.tagTrailingExtraAssumeCapacity(hasher, tag, extra_index);
    }

    fn tagTrailingExtraAssumeCapacity(
        pool: *Pool,
        hasher: Hasher,
        tag: Pool.Tag,
        extra_index: ExtraIndex,
    ) CType {
        const Key = struct { hash: Map.Hash, tag: Pool.Tag, extra: []const u32 };
        const CTypeAdapter = struct {
            pool: *const Pool,
            pub fn hash(_: @This(), key: Key) Map.Hash {
                return key.hash;
            }
            pub fn eql(ctype_adapter: @This(), lhs_key: Key, _: void, rhs_index: usize) bool {
                const rhs_item = ctype_adapter.pool.items.get(rhs_index);
                if (lhs_key.tag != rhs_item.tag) return false;
                const rhs_extra = ctype_adapter.pool.extra.items[rhs_item.data..];
                return std.mem.startsWith(u32, rhs_extra, lhs_key.extra);
            }
        };
        const gop = pool.map.getOrPutAssumeCapacityAdapted(
            Key{ .hash = hasher.final(tag), .tag = tag, .extra = pool.extra.items[extra_index..] },
            CTypeAdapter{ .pool = pool },
        );
        if (gop.found_existing)
            pool.extra.shrinkRetainingCapacity(extra_index)
        else
            pool.items.appendAssumeCapacity(.{ .tag = tag, .data = extra_index });
        return .fromPoolIndex(gop.index);
    }

    fn sortFields(fields: []Info.Field) void {
        std.mem.sort(Info.Field, fields, {}, struct {
            fn before(_: void, lhs_field: Info.Field, rhs_field: Info.Field) bool {
                return lhs_field.alignas.order(rhs_field.alignas).compare(.gt);
            }
        }.before);
    }

    fn trailingString(pool: *Pool, allocator: std.mem.Allocator) !String {
        const start = pool.string_indices.getLast();
        const slice: []const u8 = pool.string_bytes.items[start..];
        if (slice.len >= 2 and slice[0] == 'f' and switch (slice[1]) {
            '0' => slice.len == 2,
            '1'...'9' => true,
            else => false,
        }) if (std.fmt.parseInt(u31, slice[1..], 10)) |unnamed| {
            pool.string_bytes.shrinkRetainingCapacity(start);
            return String.fromUnnamed(unnamed);
        } else |_| {};
        if (std.meta.stringToEnum(String.Index, slice)) |index| {
            pool.string_bytes.shrinkRetainingCapacity(start);
            return .{ .index = index };
        }

        try pool.string_map.ensureUnusedCapacity(allocator, 1);
        try pool.string_indices.ensureUnusedCapacity(allocator, 1);

        const gop = pool.string_map.getOrPutAssumeCapacityAdapted(slice, String.Adapter{ .pool = pool });
        if (gop.found_existing)
            pool.string_bytes.shrinkRetainingCapacity(start)
        else
            pool.string_indices.appendAssumeCapacity(@intCast(pool.string_bytes.items.len));
        return String.fromPoolIndex(gop.index);
    }

    const Item = struct {
        tag: Pool.Tag,
        data: u32,
    };

    const ExtraIndex = u32;

    const Tag = enum(u8) {
        basic,
        pointer,
        pointer_const,
        pointer_volatile,
        pointer_const_volatile,
        aligned,
        array_small,
        array_large,
        vector,
        fwd_decl_struct_anon,
        fwd_decl_union_anon,
        fwd_decl_struct,
        fwd_decl_union,
        aggregate_struct_anon,
        aggregate_struct_packed_anon,
        aggregate_union_anon,
        aggregate_union_packed_anon,
        aggregate_struct,
        aggregate_struct_packed,
        aggregate_union,
        aggregate_union_packed,
        function,
        function_varargs,
    };

    const Aligned = struct {
        ctype: CType.Index,
        flags: Flags,

        const Flags = packed struct(u32) {
            alignas: AlignAs,
            _: u20 = 0,
        };
    };

    const SequenceSmall = struct {
        elem_ctype: CType.Index,
        len: u32,
    };

    const SequenceLarge = struct {
        elem_ctype: CType.Index,
        len_lo: u32,
        len_hi: u32,

        fn len(extra: SequenceLarge) u64 {
            return @as(u64, extra.len_lo) << 0 |
                @as(u64, extra.len_hi) << 32;
        }
    };

    const Field = struct {
        name: String.Index,
        ctype: CType.Index,
        flags: Flags,

        const Flags = Aligned.Flags;
    };

    const FwdDeclAnon = struct {
        fields_len: u32,
    };

    const AggregateAnon = struct {
        index: InternPool.Index,
        id: u32,
        fields_len: u32,
    };

    const Aggregate = struct {
        fwd_decl: CType.Index,
        fields_len: u32,
    };

    const Function = struct {
        return_ctype: CType.Index,
        param_ctypes_len: u32,
    };

    fn addExtra(
        pool: *Pool,
        allocator: std.mem.Allocator,
        comptime Extra: type,
        extra: Extra,
        trailing_len: usize,
    ) !ExtraIndex {
        try pool.extra.ensureUnusedCapacity(
            allocator,
            @typeInfo(Extra).@"struct".fields.len + trailing_len,
        );
        defer pool.addExtraAssumeCapacity(Extra, extra);
        return @intCast(pool.extra.items.len);
    }
    fn addExtraAssumeCapacity(pool: *Pool, comptime Extra: type, extra: Extra) void {
        addExtraAssumeCapacityTo(&pool.extra, Extra, extra);
    }
    fn addExtraAssumeCapacityTo(
        array: *std.ArrayListUnmanaged(u32),
        comptime Extra: type,
        extra: Extra,
    ) void {
        inline for (@typeInfo(Extra).@"struct".fields) |field| {
            const value = @field(extra, field.name);
            array.appendAssumeCapacity(switch (field.type) {
                u32 => value,
                CType.Index, String.Index, InternPool.Index => @intFromEnum(value),
                Aligned.Flags => @bitCast(value),
                else => @compileError("bad field type: " ++ field.name ++ ": " ++
                    @typeName(field.type)),
            });
        }
    }

    fn addHashedExtra(
        pool: *Pool,
        allocator: std.mem.Allocator,
        hasher: *Hasher,
        comptime Extra: type,
        extra: Extra,
        trailing_len: usize,
    ) !ExtraIndex {
        hasher.updateExtra(Extra, extra, pool);
        return pool.addExtra(allocator, Extra, extra, trailing_len);
    }
    fn addHashedExtraAssumeCapacity(
        pool: *Pool,
        hasher: *Hasher,
        comptime Extra: type,
        extra: Extra,
    ) void {
        hasher.updateExtra(Extra, extra, pool);
        pool.addExtraAssumeCapacity(Extra, extra);
    }
    fn addHashedExtraAssumeCapacityTo(
        pool: *Pool,
        array: *std.ArrayListUnmanaged(u32),
        hasher: *Hasher,
        comptime Extra: type,
        extra: Extra,
    ) void {
        hasher.updateExtra(Extra, extra, pool);
        addExtraAssumeCapacityTo(array, Extra, extra);
    }

    const ExtraTrail = struct {
        extra_index: ExtraIndex,

        fn next(
            extra_trail: *ExtraTrail,
            len: u32,
            comptime Extra: type,
            pool: *const Pool,
        ) []const Extra {
            defer extra_trail.extra_index += @intCast(len);
            return @ptrCast(pool.extra.items[extra_trail.extra_index..][0..len]);
        }
    };

    fn getExtraTrail(
        pool: *const Pool,
        comptime Extra: type,
        extra_index: ExtraIndex,
    ) struct { extra: Extra, trail: ExtraTrail } {
        var extra: Extra = undefined;
        const fields = @typeInfo(Extra).@"struct".fields;
        inline for (fields, pool.extra.items[extra_index..][0..fields.len]) |field, value|
            @field(extra, field.name) = switch (field.type) {
                u32 => value,
                CType.Index, String.Index, InternPool.Index => @enumFromInt(value),
                Aligned.Flags => @bitCast(value),
                else => @compileError("bad field type: " ++ field.name ++ ": " ++ @typeName(field.type)),
            };
        return .{
            .extra = extra,
            .trail = .{ .extra_index = extra_index + @as(ExtraIndex, @intCast(fields.len)) },
        };
    }

    fn getExtra(pool: *const Pool, comptime Extra: type, extra_index: ExtraIndex) Extra {
        return pool.getExtraTrail(Extra, extra_index).extra;
    }
};

pub const AlignAs = packed struct {
    @"align": InternPool.Alignment,
    abi: InternPool.Alignment,

    pub fn fromAlignment(alignas: AlignAs) AlignAs {
        assert(alignas.abi != .none);
        return .{
            .@"align" = if (alignas.@"align" != .none) alignas.@"align" else alignas.abi,
            .abi = alignas.abi,
        };
    }
    pub fn fromAbiAlignment(abi: InternPool.Alignment) AlignAs {
        assert(abi != .none);
        return .{ .@"align" = abi, .abi = abi };
    }
    pub fn fromByteUnits(@"align": u64, abi: u64) AlignAs {
        return fromAlignment(.{
            .@"align" = InternPool.Alignment.fromByteUnits(@"align"),
            .abi = InternPool.Alignment.fromNonzeroByteUnits(abi),
        });
    }

    pub fn order(lhs: AlignAs, rhs: AlignAs) std.math.Order {
        return lhs.@"align".order(rhs.@"align");
    }
    pub fn abiOrder(alignas: AlignAs) std.math.Order {
        return alignas.@"align".order(alignas.abi);
    }
    pub fn toByteUnits(alignas: AlignAs) u64 {
        return alignas.@"align".toByteUnits().?;
    }
};

const assert = std.debug.assert;
const CType = @This();
const InternPool = @import("../../InternPool.zig");
const Module = @import("../../Package/Module.zig");
const std = @import("std");
const Type = @import("../../Type.zig");
const Zcu = @import("../../Zcu.zig");
