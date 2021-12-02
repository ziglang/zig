///! Contains all constants and types representing the wasm
///! binary format, as specified by:
///! https://webassembly.github.io/spec/core/
const std = @import("std.zig");
const testing = std.testing;

// TODO: Add support for multi-byte ops (e.g. table operations)

/// Wasm instruction opcodes
///
/// All instructions are defined as per spec:
/// https://webassembly.github.io/spec/core/appendix/index-instructions.html
pub const Opcode = enum(u8) {
    @"unreachable" = 0x00,
    nop = 0x01,
    block = 0x02,
    loop = 0x03,
    @"if" = 0x04,
    @"else" = 0x05,
    end = 0x0B,
    br = 0x0C,
    br_if = 0x0D,
    br_table = 0x0E,
    @"return" = 0x0F,
    call = 0x10,
    call_indirect = 0x11,
    drop = 0x1A,
    select = 0x1B,
    local_get = 0x20,
    local_set = 0x21,
    local_tee = 0x22,
    global_get = 0x23,
    global_set = 0x24,
    i32_load = 0x28,
    i64_load = 0x29,
    f32_load = 0x2A,
    f64_load = 0x2B,
    i32_load8_s = 0x2C,
    i32_load8_u = 0x2D,
    i32_load16_s = 0x2E,
    i32_load16_u = 0x2F,
    i64_load8_s = 0x30,
    i64_load8_u = 0x31,
    i64_load16_s = 0x32,
    i64_load16_u = 0x33,
    i64_load32_s = 0x34,
    i64_load32_u = 0x35,
    i32_store = 0x36,
    i64_store = 0x37,
    f32_store = 0x38,
    f64_store = 0x39,
    i32_store8 = 0x3A,
    i32_store16 = 0x3B,
    i64_store8 = 0x3C,
    i64_store16 = 0x3D,
    i64_store32 = 0x3E,
    memory_size = 0x3F,
    memory_grow = 0x40,
    i32_const = 0x41,
    i64_const = 0x42,
    f32_const = 0x43,
    f64_const = 0x44,
    i32_eqz = 0x45,
    i32_eq = 0x46,
    i32_ne = 0x47,
    i32_lt_s = 0x48,
    i32_lt_u = 0x49,
    i32_gt_s = 0x4A,
    i32_gt_u = 0x4B,
    i32_le_s = 0x4C,
    i32_le_u = 0x4D,
    i32_ge_s = 0x4E,
    i32_ge_u = 0x4F,
    i64_eqz = 0x50,
    i64_eq = 0x51,
    i64_ne = 0x52,
    i64_lt_s = 0x53,
    i64_lt_u = 0x54,
    i64_gt_s = 0x55,
    i64_gt_u = 0x56,
    i64_le_s = 0x57,
    i64_le_u = 0x58,
    i64_ge_s = 0x59,
    i64_ge_u = 0x5A,
    f32_eq = 0x5B,
    f32_ne = 0x5C,
    f32_lt = 0x5D,
    f32_gt = 0x5E,
    f32_le = 0x5F,
    f32_ge = 0x60,
    f64_eq = 0x61,
    f64_ne = 0x62,
    f64_lt = 0x63,
    f64_gt = 0x64,
    f64_le = 0x65,
    f64_ge = 0x66,
    i32_clz = 0x67,
    i32_ctz = 0x68,
    i32_popcnt = 0x69,
    i32_add = 0x6A,
    i32_sub = 0x6B,
    i32_mul = 0x6C,
    i32_div_s = 0x6D,
    i32_div_u = 0x6E,
    i32_rem_s = 0x6F,
    i32_rem_u = 0x70,
    i32_and = 0x71,
    i32_or = 0x72,
    i32_xor = 0x73,
    i32_shl = 0x74,
    i32_shr_s = 0x75,
    i32_shr_u = 0x76,
    i32_rotl = 0x77,
    i32_rotr = 0x78,
    i64_clz = 0x79,
    i64_ctz = 0x7A,
    i64_popcnt = 0x7B,
    i64_add = 0x7C,
    i64_sub = 0x7D,
    i64_mul = 0x7E,
    i64_div_s = 0x7F,
    i64_div_u = 0x80,
    i64_rem_s = 0x81,
    i64_rem_u = 0x82,
    i64_and = 0x83,
    i64_or = 0x84,
    i64_xor = 0x85,
    i64_shl = 0x86,
    i64_shr_s = 0x87,
    i64_shr_u = 0x88,
    i64_rotl = 0x89,
    i64_rotr = 0x8A,
    f32_abs = 0x8B,
    f32_neg = 0x8C,
    f32_ceil = 0x8D,
    f32_floor = 0x8E,
    f32_trunc = 0x8F,
    f32_nearest = 0x90,
    f32_sqrt = 0x91,
    f32_add = 0x92,
    f32_sub = 0x93,
    f32_mul = 0x94,
    f32_div = 0x95,
    f32_min = 0x96,
    f32_max = 0x97,
    f32_copysign = 0x98,
    f64_abs = 0x99,
    f64_neg = 0x9A,
    f64_ceil = 0x9B,
    f64_floor = 0x9C,
    f64_trunc = 0x9D,
    f64_nearest = 0x9E,
    f64_sqrt = 0x9F,
    f64_add = 0xA0,
    f64_sub = 0xA1,
    f64_mul = 0xA2,
    f64_div = 0xA3,
    f64_min = 0xA4,
    f64_max = 0xA5,
    f64_copysign = 0xA6,
    i32_wrap_i64 = 0xA7,
    i32_trunc_f32_s = 0xA8,
    i32_trunc_f32_u = 0xA9,
    i32_trunc_f64_s = 0xAA,
    i32_trunc_f64_u = 0xAB,
    i64_extend_i32_s = 0xAC,
    i64_extend_i32_u = 0xAD,
    i64_trunc_f32_s = 0xAE,
    i64_trunc_f32_u = 0xAF,
    i64_trunc_f64_s = 0xB0,
    i64_trunc_f64_u = 0xB1,
    f32_convert_i32_s = 0xB2,
    f32_convert_i32_u = 0xB3,
    f32_convert_i64_s = 0xB4,
    f32_convert_i64_u = 0xB5,
    f32_demote_f64 = 0xB6,
    f64_convert_i32_s = 0xB7,
    f64_convert_i32_u = 0xB8,
    f64_convert_i64_s = 0xB9,
    f64_convert_i64_u = 0xBA,
    f64_promote_f32 = 0xBB,
    i32_reinterpret_f32 = 0xBC,
    i64_reinterpret_f64 = 0xBD,
    f32_reinterpret_i32 = 0xBE,
    f64_reinterpret_i64 = 0xBF,
    i32_extend8_s = 0xC0,
    i32_extend16_s = 0xC1,
    i64_extend8_s = 0xC2,
    i64_extend16_s = 0xC3,
    i64_extend32_s = 0xC4,
    _,
};

/// Returns the integer value of an `Opcode`. Used by the Zig compiler
/// to write instructions to the wasm binary file
pub fn opcode(op: Opcode) u8 {
    return @enumToInt(op);
}

test "Wasm - opcodes" {
    // Ensure our opcodes values remain intact as certain values are skipped due to them being reserved
    const i32_const = opcode(.i32_const);
    const end = opcode(.end);
    const drop = opcode(.drop);
    const local_get = opcode(.local_get);
    const i64_extend32_s = opcode(.i64_extend32_s);

    try testing.expectEqual(@as(u16, 0x41), i32_const);
    try testing.expectEqual(@as(u16, 0x0B), end);
    try testing.expectEqual(@as(u16, 0x1A), drop);
    try testing.expectEqual(@as(u16, 0x20), local_get);
    try testing.expectEqual(@as(u16, 0xC4), i64_extend32_s);
}

/// Enum representing all Wasm value types as per spec:
/// https://webassembly.github.io/spec/core/binary/types.html
pub const Valtype = enum(u8) {
    i32 = 0x7F,
    i64 = 0x7E,
    f32 = 0x7D,
    f64 = 0x7C,
};

/// Returns the integer value of a `Valtype`
pub fn valtype(value: Valtype) u8 {
    return @enumToInt(value);
}

/// Reference types, where the funcref references to a function regardless of its type
/// and ref references an object from the embedder.
pub const RefType = enum(u8) {
    funcref = 0x70,
    externref = 0x6F,
};

/// Returns the integer value of a `Reftype`
pub fn reftype(value: RefType) u8 {
    return @enumToInt(value);
}

test "Wasm - valtypes" {
    const _i32 = valtype(.i32);
    const _i64 = valtype(.i64);
    const _f32 = valtype(.f32);
    const _f64 = valtype(.f64);

    try testing.expectEqual(@as(u8, 0x7F), _i32);
    try testing.expectEqual(@as(u8, 0x7E), _i64);
    try testing.expectEqual(@as(u8, 0x7D), _f32);
    try testing.expectEqual(@as(u8, 0x7C), _f64);
}

/// Limits classify the size range of resizeable storage associated with memory types and table types.
pub const Limits = struct {
    min: u32,
    max: ?u32,
};

/// Initialization expressions are used to set the initial value on an object
/// when a wasm module is being loaded.
pub const InitExpression = union(enum) {
    i32_const: i32,
    i64_const: i64,
    f32_const: f32,
    f64_const: f64,
    global_get: u32,
};

///
pub const Func = struct {
    type_index: u32,
};

/// Tables are used to hold pointers to opaque objects.
/// This can either by any function, or an object from the host.
pub const Table = struct {
    limits: Limits,
    reftype: RefType,
};

/// Describes the layout of the memory where `min` represents
/// the minimal amount of pages, and the optional `max` represents
/// the max pages. When `null` will allow the host to determine the
/// amount of pages.
pub const Memory = struct {
    limits: Limits,
};

/// Represents the type of a `Global` or an imported global.
pub const GlobalType = struct {
    valtype: Valtype,
    mutable: bool,
};

pub const Global = struct {
    global_type: GlobalType,
    init: InitExpression,
};

/// Notates an object to be exported from wasm
/// to the host.
pub const Export = struct {
    name: []const u8,
    kind: ExternalKind,
    index: u32,
};

/// Element describes the layout of the table that can
/// be found at `table_index`
pub const Element = struct {
    table_index: u32,
    offset: InitExpression,
    func_indexes: []const u32,
};

/// Imports are used to import objects from the host
pub const Import = struct {
    module_name: []const u8,
    name: []const u8,
    kind: Kind,

    pub const Kind = union(ExternalKind) {
        function: u32,
        table: Table,
        memory: Limits,
        global: GlobalType,
    };
};

/// `Type` represents a function signature type containing both
/// a slice of parameters as well as a slice of return values.
pub const Type = struct {
    params: []const Valtype,
    returns: []const Valtype,

    pub fn format(self: Type, comptime fmt: []const u8, opt: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = opt;
        try writer.writeByte('(');
        for (self.params) |param, i| {
            try writer.print("{s}", .{@tagName(param)});
            if (i + 1 != self.params.len) {
                try writer.writeAll(", ");
            }
        }
        try writer.writeAll(") -> ");
        if (self.returns.len == 0) {
            try writer.writeAll("nil");
        } else {
            for (self.returns) |return_ty, i| {
                try writer.print("{s}", .{@tagName(return_ty)});
                if (i + 1 != self.returns.len) {
                    try writer.writeAll(", ");
                }
            }
        }
    }

    pub fn eql(self: Type, other: Type) bool {
        return std.mem.eql(Valtype, self.params, other.params) and
            std.mem.eql(Valtype, self.returns, other.returns);
    }

    pub fn deinit(self: *Type, gpa: std.mem.Allocator) void {
        gpa.free(self.params);
        gpa.free(self.returns);
        self.* = undefined;
    }
};

/// Wasm module sections as per spec:
/// https://webassembly.github.io/spec/core/binary/modules.html
pub const Section = enum(u8) {
    custom,
    type,
    import,
    function,
    table,
    memory,
    global,
    @"export",
    start,
    element,
    code,
    data,
    data_count,
    _,
};

/// Returns the integer value of a given `Section`
pub fn section(val: Section) u8 {
    return @enumToInt(val);
}

/// The kind of the type when importing or exporting to/from the host environment
/// https://webassembly.github.io/spec/core/syntax/modules.html
pub const ExternalKind = enum(u8) {
    function,
    table,
    memory,
    global,
};

/// Returns the integer value of a given `ExternalKind`
pub fn externalKind(val: ExternalKind) u8 {
    return @enumToInt(val);
}

// type constants
pub const element_type: u8 = 0x70;
pub const function_type: u8 = 0x60;
pub const result_type: u8 = 0x40;

/// Represents a block which will not return a value
pub const block_empty: u8 = 0x40;

// binary constants
pub const magic = [_]u8{ 0x00, 0x61, 0x73, 0x6D }; // \0asm
pub const version = [_]u8{ 0x01, 0x00, 0x00, 0x00 }; // version 1 (MVP)

// Each wasm page size is 64kB
pub const page_size = 64 * 1024;
