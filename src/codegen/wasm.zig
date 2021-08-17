const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const assert = std.debug.assert;
const testing = std.testing;
const leb = std.leb;
const mem = std.mem;
const wasm = std.wasm;

const Module = @import("../Module.zig");
const Decl = Module.Decl;
const Type = @import("../type.zig").Type;
const Value = @import("../value.zig").Value;
const Compilation = @import("../Compilation.zig");
const LazySrcLoc = Module.LazySrcLoc;
const link = @import("../link.zig");
const TypedValue = @import("../TypedValue.zig");
const Air = @import("../Air.zig");
const Liveness = @import("../Liveness.zig");

/// Wasm Value, created when generating an instruction
const WValue = union(enum) {
    /// May be referenced but is unused
    none: void,
    /// Index of the local variable
    local: u32,
    /// Holds a memoized typed value
    constant: TypedValue,
    /// Offset position in the list of bytecode instructions
    code_offset: usize,
    /// Used for variables that create multiple locals on the stack when allocated
    /// such as structs and optionals.
    multi_value: struct {
        /// The index of the first local variable
        index: u32,
        /// The count of local variables this `WValue` consists of.
        /// i.e. an ErrorUnion has a 'count' of 2.
        count: u32,
    },
};

/// Wasm ops, but without input/output/signedness information
/// Used for `buildOpcode`
const Op = enum {
    @"unreachable",
    nop,
    block,
    loop,
    @"if",
    @"else",
    end,
    br,
    br_if,
    br_table,
    @"return",
    call,
    call_indirect,
    drop,
    select,
    local_get,
    local_set,
    local_tee,
    global_get,
    global_set,
    load,
    store,
    memory_size,
    memory_grow,
    @"const",
    eqz,
    eq,
    ne,
    lt,
    gt,
    le,
    ge,
    clz,
    ctz,
    popcnt,
    add,
    sub,
    mul,
    div,
    rem,
    @"and",
    @"or",
    xor,
    shl,
    shr,
    rotl,
    rotr,
    abs,
    neg,
    ceil,
    floor,
    trunc,
    nearest,
    sqrt,
    min,
    max,
    copysign,
    wrap,
    convert,
    demote,
    promote,
    reinterpret,
    extend,
};

/// Contains the settings needed to create an `Opcode` using `buildOpcode`.
///
/// The fields correspond to the opcode name. Here is an example
///          i32_trunc_f32_s
///          ^   ^     ^   ^
///          |   |     |   |
///   valtype1   |     |   |
///     = .i32   |     |   |
///              |     |   |
///             op     |   |
///       = .trunc     |   |
///                    |   |
///             valtype2   |
///               = .f32   |
///                        |
///                width   |
///               = null   |
///                        |
///                   signed
///                   = true
///
/// There can be missing fields, here are some more examples:
///   i64_load8_u
///     --> .{ .valtype1 = .i64, .op = .load, .width = 8, signed = false }
///   i32_mul
///     --> .{ .valtype1 = .i32, .op = .trunc }
///   nop
///     --> .{ .op = .nop }
const OpcodeBuildArguments = struct {
    /// First valtype in the opcode (usually represents the type of the output)
    valtype1: ?wasm.Valtype = null,
    /// The operation (e.g. call, unreachable, div, min, sqrt, etc.)
    op: Op,
    /// Width of the operation (e.g. 8 for i32_load8_s, 16 for i64_extend16_i32_s)
    width: ?u8 = null,
    /// Second valtype in the opcode name (usually represents the type of the input)
    valtype2: ?wasm.Valtype = null,
    /// Signedness of the op
    signedness: ?std.builtin.Signedness = null,
};

/// Helper function that builds an Opcode given the arguments needed
fn buildOpcode(args: OpcodeBuildArguments) wasm.Opcode {
    switch (args.op) {
        .@"unreachable" => return .@"unreachable",
        .nop => return .nop,
        .block => return .block,
        .loop => return .loop,
        .@"if" => return .@"if",
        .@"else" => return .@"else",
        .end => return .end,
        .br => return .br,
        .br_if => return .br_if,
        .br_table => return .br_table,
        .@"return" => return .@"return",
        .call => return .call,
        .call_indirect => return .call_indirect,
        .drop => return .drop,
        .select => return .select,
        .local_get => return .local_get,
        .local_set => return .local_set,
        .local_tee => return .local_tee,
        .global_get => return .global_get,
        .global_set => return .global_set,

        .load => if (args.width) |width| switch (width) {
            8 => switch (args.valtype1.?) {
                .i32 => if (args.signedness.? == .signed) return .i32_load8_s else return .i32_load8_u,
                .i64 => if (args.signedness.? == .signed) return .i64_load8_s else return .i64_load8_u,
                .f32, .f64 => unreachable,
            },
            16 => switch (args.valtype1.?) {
                .i32 => if (args.signedness.? == .signed) return .i32_load16_s else return .i32_load16_u,
                .i64 => if (args.signedness.? == .signed) return .i64_load16_s else return .i64_load16_u,
                .f32, .f64 => unreachable,
            },
            32 => switch (args.valtype1.?) {
                .i64 => if (args.signedness.? == .signed) return .i64_load32_s else return .i64_load32_u,
                .i32, .f32, .f64 => unreachable,
            },
            else => unreachable,
        } else switch (args.valtype1.?) {
            .i32 => return .i32_load,
            .i64 => return .i64_load,
            .f32 => return .f32_load,
            .f64 => return .f64_load,
        },
        .store => if (args.width) |width| {
            switch (width) {
                8 => switch (args.valtype1.?) {
                    .i32 => return .i32_store8,
                    .i64 => return .i64_store8,
                    .f32, .f64 => unreachable,
                },
                16 => switch (args.valtype1.?) {
                    .i32 => return .i32_store16,
                    .i64 => return .i64_store16,
                    .f32, .f64 => unreachable,
                },
                32 => switch (args.valtype1.?) {
                    .i64 => return .i64_store32,
                    .i32, .f32, .f64 => unreachable,
                },
                else => unreachable,
            }
        } else {
            switch (args.valtype1.?) {
                .i32 => return .i32_store,
                .i64 => return .i64_store,
                .f32 => return .f32_store,
                .f64 => return .f64_store,
            }
        },

        .memory_size => return .memory_size,
        .memory_grow => return .memory_grow,

        .@"const" => switch (args.valtype1.?) {
            .i32 => return .i32_const,
            .i64 => return .i64_const,
            .f32 => return .f32_const,
            .f64 => return .f64_const,
        },

        .eqz => switch (args.valtype1.?) {
            .i32 => return .i32_eqz,
            .i64 => return .i64_eqz,
            .f32, .f64 => unreachable,
        },
        .eq => switch (args.valtype1.?) {
            .i32 => return .i32_eq,
            .i64 => return .i64_eq,
            .f32 => return .f32_eq,
            .f64 => return .f64_eq,
        },
        .ne => switch (args.valtype1.?) {
            .i32 => return .i32_ne,
            .i64 => return .i64_ne,
            .f32 => return .f32_ne,
            .f64 => return .f64_ne,
        },

        .lt => switch (args.valtype1.?) {
            .i32 => if (args.signedness.? == .signed) return .i32_lt_s else return .i32_lt_u,
            .i64 => if (args.signedness.? == .signed) return .i64_lt_s else return .i64_lt_u,
            .f32 => return .f32_lt,
            .f64 => return .f64_lt,
        },
        .gt => switch (args.valtype1.?) {
            .i32 => if (args.signedness.? == .signed) return .i32_gt_s else return .i32_gt_u,
            .i64 => if (args.signedness.? == .signed) return .i64_gt_s else return .i64_gt_u,
            .f32 => return .f32_gt,
            .f64 => return .f64_gt,
        },
        .le => switch (args.valtype1.?) {
            .i32 => if (args.signedness.? == .signed) return .i32_le_s else return .i32_le_u,
            .i64 => if (args.signedness.? == .signed) return .i64_le_s else return .i64_le_u,
            .f32 => return .f32_le,
            .f64 => return .f64_le,
        },
        .ge => switch (args.valtype1.?) {
            .i32 => if (args.signedness.? == .signed) return .i32_ge_s else return .i32_ge_u,
            .i64 => if (args.signedness.? == .signed) return .i64_ge_s else return .i64_ge_u,
            .f32 => return .f32_ge,
            .f64 => return .f64_ge,
        },

        .clz => switch (args.valtype1.?) {
            .i32 => return .i32_clz,
            .i64 => return .i64_clz,
            .f32, .f64 => unreachable,
        },
        .ctz => switch (args.valtype1.?) {
            .i32 => return .i32_ctz,
            .i64 => return .i64_ctz,
            .f32, .f64 => unreachable,
        },
        .popcnt => switch (args.valtype1.?) {
            .i32 => return .i32_popcnt,
            .i64 => return .i64_popcnt,
            .f32, .f64 => unreachable,
        },

        .add => switch (args.valtype1.?) {
            .i32 => return .i32_add,
            .i64 => return .i64_add,
            .f32 => return .f32_add,
            .f64 => return .f64_add,
        },
        .sub => switch (args.valtype1.?) {
            .i32 => return .i32_sub,
            .i64 => return .i64_sub,
            .f32 => return .f32_sub,
            .f64 => return .f64_sub,
        },
        .mul => switch (args.valtype1.?) {
            .i32 => return .i32_mul,
            .i64 => return .i64_mul,
            .f32 => return .f32_mul,
            .f64 => return .f64_mul,
        },

        .div => switch (args.valtype1.?) {
            .i32 => if (args.signedness.? == .signed) return .i32_div_s else return .i32_div_u,
            .i64 => if (args.signedness.? == .signed) return .i64_div_s else return .i64_div_u,
            .f32 => return .f32_div,
            .f64 => return .f64_div,
        },
        .rem => switch (args.valtype1.?) {
            .i32 => if (args.signedness.? == .signed) return .i32_rem_s else return .i32_rem_u,
            .i64 => if (args.signedness.? == .signed) return .i64_rem_s else return .i64_rem_u,
            .f32, .f64 => unreachable,
        },

        .@"and" => switch (args.valtype1.?) {
            .i32 => return .i32_and,
            .i64 => return .i64_and,
            .f32, .f64 => unreachable,
        },
        .@"or" => switch (args.valtype1.?) {
            .i32 => return .i32_or,
            .i64 => return .i64_or,
            .f32, .f64 => unreachable,
        },
        .xor => switch (args.valtype1.?) {
            .i32 => return .i32_xor,
            .i64 => return .i64_xor,
            .f32, .f64 => unreachable,
        },

        .shl => switch (args.valtype1.?) {
            .i32 => return .i32_shl,
            .i64 => return .i64_shl,
            .f32, .f64 => unreachable,
        },
        .shr => switch (args.valtype1.?) {
            .i32 => if (args.signedness.? == .signed) return .i32_shr_s else return .i32_shr_u,
            .i64 => if (args.signedness.? == .signed) return .i64_shr_s else return .i64_shr_u,
            .f32, .f64 => unreachable,
        },
        .rotl => switch (args.valtype1.?) {
            .i32 => return .i32_rotl,
            .i64 => return .i64_rotl,
            .f32, .f64 => unreachable,
        },
        .rotr => switch (args.valtype1.?) {
            .i32 => return .i32_rotr,
            .i64 => return .i64_rotr,
            .f32, .f64 => unreachable,
        },

        .abs => switch (args.valtype1.?) {
            .i32, .i64 => unreachable,
            .f32 => return .f32_abs,
            .f64 => return .f64_abs,
        },
        .neg => switch (args.valtype1.?) {
            .i32, .i64 => unreachable,
            .f32 => return .f32_neg,
            .f64 => return .f64_neg,
        },
        .ceil => switch (args.valtype1.?) {
            .i32, .i64 => unreachable,
            .f32 => return .f32_ceil,
            .f64 => return .f64_ceil,
        },
        .floor => switch (args.valtype1.?) {
            .i32, .i64 => unreachable,
            .f32 => return .f32_floor,
            .f64 => return .f64_floor,
        },
        .trunc => switch (args.valtype1.?) {
            .i32 => switch (args.valtype2.?) {
                .i32 => unreachable,
                .i64 => unreachable,
                .f32 => if (args.signedness.? == .signed) return .i32_trunc_f32_s else return .i32_trunc_f32_u,
                .f64 => if (args.signedness.? == .signed) return .i32_trunc_f64_s else return .i32_trunc_f64_u,
            },
            .i64 => unreachable,
            .f32 => return .f32_trunc,
            .f64 => return .f64_trunc,
        },
        .nearest => switch (args.valtype1.?) {
            .i32, .i64 => unreachable,
            .f32 => return .f32_nearest,
            .f64 => return .f64_nearest,
        },
        .sqrt => switch (args.valtype1.?) {
            .i32, .i64 => unreachable,
            .f32 => return .f32_sqrt,
            .f64 => return .f64_sqrt,
        },
        .min => switch (args.valtype1.?) {
            .i32, .i64 => unreachable,
            .f32 => return .f32_min,
            .f64 => return .f64_min,
        },
        .max => switch (args.valtype1.?) {
            .i32, .i64 => unreachable,
            .f32 => return .f32_max,
            .f64 => return .f64_max,
        },
        .copysign => switch (args.valtype1.?) {
            .i32, .i64 => unreachable,
            .f32 => return .f32_copysign,
            .f64 => return .f64_copysign,
        },

        .wrap => switch (args.valtype1.?) {
            .i32 => switch (args.valtype2.?) {
                .i32 => unreachable,
                .i64 => return .i32_wrap_i64,
                .f32, .f64 => unreachable,
            },
            .i64, .f32, .f64 => unreachable,
        },
        .convert => switch (args.valtype1.?) {
            .i32, .i64 => unreachable,
            .f32 => switch (args.valtype2.?) {
                .i32 => if (args.signedness.? == .signed) return .f32_convert_i32_s else return .f32_convert_i32_u,
                .i64 => if (args.signedness.? == .signed) return .f32_convert_i64_s else return .f32_convert_i64_u,
                .f32, .f64 => unreachable,
            },
            .f64 => switch (args.valtype2.?) {
                .i32 => if (args.signedness.? == .signed) return .f64_convert_i32_s else return .f64_convert_i32_u,
                .i64 => if (args.signedness.? == .signed) return .f64_convert_i64_s else return .f64_convert_i64_u,
                .f32, .f64 => unreachable,
            },
        },
        .demote => if (args.valtype1.? == .f32 and args.valtype2.? == .f64) return .f32_demote_f64 else unreachable,
        .promote => if (args.valtype1.? == .f64 and args.valtype2.? == .f32) return .f64_promote_f32 else unreachable,
        .reinterpret => switch (args.valtype1.?) {
            .i32 => if (args.valtype2.? == .f32) return .i32_reinterpret_f32 else unreachable,
            .i64 => if (args.valtype2.? == .f64) return .i64_reinterpret_f64 else unreachable,
            .f32 => if (args.valtype2.? == .i32) return .f32_reinterpret_i32 else unreachable,
            .f64 => if (args.valtype2.? == .i64) return .f64_reinterpret_i64 else unreachable,
        },
        .extend => switch (args.valtype1.?) {
            .i32 => switch (args.width.?) {
                8 => if (args.signedness.? == .signed) return .i32_extend8_s else unreachable,
                16 => if (args.signedness.? == .signed) return .i32_extend16_s else unreachable,
                else => unreachable,
            },
            .i64 => switch (args.width.?) {
                8 => if (args.signedness.? == .signed) return .i64_extend8_s else unreachable,
                16 => if (args.signedness.? == .signed) return .i64_extend16_s else unreachable,
                32 => if (args.signedness.? == .signed) return .i64_extend32_s else unreachable,
                else => unreachable,
            },
            .f32, .f64 => unreachable,
        },
    }
}

test "Wasm - buildOpcode" {
    // Make sure buildOpcode is referenced, and test some examples
    const i32_const = buildOpcode(.{ .op = .@"const", .valtype1 = .i32 });
    const end = buildOpcode(.{ .op = .end });
    const local_get = buildOpcode(.{ .op = .local_get });
    const i64_extend32_s = buildOpcode(.{ .op = .extend, .valtype1 = .i64, .width = 32, .signedness = .signed });
    const f64_reinterpret_i64 = buildOpcode(.{ .op = .reinterpret, .valtype1 = .f64, .valtype2 = .i64 });

    try testing.expectEqual(@as(wasm.Opcode, .i32_const), i32_const);
    try testing.expectEqual(@as(wasm.Opcode, .end), end);
    try testing.expectEqual(@as(wasm.Opcode, .local_get), local_get);
    try testing.expectEqual(@as(wasm.Opcode, .i64_extend32_s), i64_extend32_s);
    try testing.expectEqual(@as(wasm.Opcode, .f64_reinterpret_i64), f64_reinterpret_i64);
}

pub const Result = union(enum) {
    /// The codegen bytes have been appended to `Context.code`
    appended: void,
    /// The data is managed externally and are part of the `Result`
    externally_managed: []const u8,
};

/// Hashmap to store generated `WValue` for each `Air.Inst.Ref`
pub const ValueTable = std.AutoHashMapUnmanaged(Air.Inst.Index, WValue);

/// Code represents the `Code` section of wasm that
/// belongs to a function
pub const Context = struct {
    /// Reference to the function declaration the code
    /// section belongs to
    decl: *Decl,
    air: Air,
    liveness: Liveness,
    gpa: *mem.Allocator,
    /// Table to save `WValue`'s generated by an `Air.Inst`
    values: ValueTable,
    /// Mapping from Air.Inst.Index to block ids
    blocks: std.AutoArrayHashMapUnmanaged(Air.Inst.Index, u32) = .{},
    /// `bytes` contains the wasm bytecode belonging to the 'code' section.
    code: ArrayList(u8),
    /// Contains the generated function type bytecode for the current function
    /// found in `decl`
    func_type_data: ArrayList(u8),
    /// The index the next local generated will have
    /// NOTE: arguments share the index with locals therefore the first variable
    /// will have the index that comes after the last argument's index
    local_index: u32 = 0,
    /// If codegen fails, an error messages will be allocated and saved in `err_msg`
    err_msg: *Module.ErrorMsg,
    /// Current block depth. Used to calculate the relative difference between a break
    /// and block
    block_depth: u32 = 0,
    /// List of all locals' types generated throughout this declaration
    /// used to emit locals count at start of 'code' section.
    locals: std.ArrayListUnmanaged(u8),
    /// The Target we're emitting (used to call intInfo)
    target: std.Target,
    /// Table with the global error set. Consists of every error found in
    /// the compiled code. Each error name maps to a `Module.ErrorInt` which is emitted
    /// during codegen to determine the error value.
    global_error_set: std.StringHashMapUnmanaged(Module.ErrorInt),

    const InnerError = error{
        OutOfMemory,
        CodegenFail,
        /// Can occur when dereferencing a pointer that points to a `Decl` of which the analysis has failed
        AnalysisFail,
    };

    pub fn deinit(self: *Context) void {
        self.values.deinit(self.gpa);
        self.blocks.deinit(self.gpa);
        self.locals.deinit(self.gpa);
        self.* = undefined;
    }

    /// Sets `err_msg` on `Context` and returns `error.CodegemFail` which is caught in link/Wasm.zig
    fn fail(self: *Context, comptime fmt: []const u8, args: anytype) InnerError {
        const src: LazySrcLoc = .{ .node_offset = 0 };
        const src_loc = src.toSrcLocWithDecl(self.decl);
        self.err_msg = try Module.ErrorMsg.create(self.gpa, src_loc, fmt, args);
        return error.CodegenFail;
    }

    /// Resolves the `WValue` for the given instruction `inst`
    /// When the given instruction has a `Value`, it returns a constant instead
    fn resolveInst(self: Context, ref: Air.Inst.Ref) WValue {
        const inst_index = Air.refToIndex(ref) orelse {
            const tv = Air.Inst.Ref.typed_value_map[@enumToInt(ref)];
            if (!tv.ty.hasCodeGenBits()) {
                return WValue.none;
            }
            return WValue{ .constant = tv };
        };

        const inst_type = self.air.typeOfIndex(inst_index);
        if (!inst_type.hasCodeGenBits()) return .none;

        if (self.air.instructions.items(.tag)[inst_index] == .constant) {
            const ty_pl = self.air.instructions.items(.data)[inst_index].ty_pl;
            return WValue{ .constant = .{ .ty = inst_type, .val = self.air.values[ty_pl.payload] } };
        }

        return self.values.get(inst_index).?; // Instruction does not dominate all uses!
    }

    /// Using a given `Type`, returns the corresponding wasm Valtype
    fn typeToValtype(self: *Context, ty: Type) InnerError!wasm.Valtype {
        return switch (ty.zigTypeTag()) {
            .Float => blk: {
                const bits = ty.floatBits(self.target);
                if (bits == 16 or bits == 32) break :blk wasm.Valtype.f32;
                if (bits == 64) break :blk wasm.Valtype.f64;
                return self.fail("Float bit size not supported by wasm: '{d}'", .{bits});
            },
            .Int => blk: {
                const info = ty.intInfo(self.target);
                if (info.bits <= 32) break :blk wasm.Valtype.i32;
                if (info.bits > 32 and info.bits <= 64) break :blk wasm.Valtype.i64;
                return self.fail("Integer bit size not supported by wasm: '{d}'", .{info.bits});
            },
            .Enum => switch (ty.tag()) {
                .enum_simple => wasm.Valtype.i32,
                else => self.typeToValtype(ty.cast(Type.Payload.EnumFull).?.data.tag_ty),
            },
            .Bool,
            .Pointer,
            .ErrorSet,
            => wasm.Valtype.i32,
            .Struct, .ErrorUnion, .Optional => unreachable, // Multi typed, must be handled individually.
            else => |tag| self.fail("TODO - Wasm valtype for type '{s}'", .{tag}),
        };
    }

    /// Using a given `Type`, returns the byte representation of its wasm value type
    fn genValtype(self: *Context, ty: Type) InnerError!u8 {
        return wasm.valtype(try self.typeToValtype(ty));
    }

    /// Using a given `Type`, returns the corresponding wasm value type
    /// Differently from `genValtype` this also allows `void` to create a block
    /// with no return type
    fn genBlockType(self: *Context, ty: Type) InnerError!u8 {
        return switch (ty.tag()) {
            .void, .noreturn => wasm.block_empty,
            else => self.genValtype(ty),
        };
    }

    /// Writes the bytecode depending on the given `WValue` in `val`
    fn emitWValue(self: *Context, val: WValue) InnerError!void {
        const writer = self.code.writer();
        switch (val) {
            .multi_value => unreachable, // multi_value can never be written directly, and must be accessed individually
            .none, .code_offset => {}, // no-op
            .local => |idx| {
                try writer.writeByte(wasm.opcode(.local_get));
                try leb.writeULEB128(writer, idx);
            },
            .constant => |tv| try self.emitConstant(tv.val, tv.ty), // Creates a new constant on the stack
        }
    }

    /// Creates one or multiple locals for a given `Type`.
    /// Returns a corresponding `Wvalue` that can either be of tag
    /// local or multi_value
    fn allocLocal(self: *Context, ty: Type) InnerError!WValue {
        const initial_index = self.local_index;
        switch (ty.zigTypeTag()) {
            .Struct => {
                // for each struct field, generate a local
                const struct_data: *Module.Struct = ty.castTag(.@"struct").?.data;
                const fields_len = @intCast(u32, struct_data.fields.count());
                try self.locals.ensureUnusedCapacity(self.gpa, fields_len);
                for (struct_data.fields.values()) |*value| {
                    const val_type = try self.genValtype(value.ty);
                    self.locals.appendAssumeCapacity(val_type);
                    self.local_index += 1;
                }
                return WValue{ .multi_value = .{
                    .index = initial_index,
                    .count = fields_len,
                } };
            },
            .ErrorUnion => {
                const payload_type = ty.errorUnionPayload();
                const val_type = try self.genValtype(payload_type);

                // we emit the error value as the first local, and the payload as the following.
                // The first local is also used to find the index of the error and payload.
                //
                // TODO: Add support where the payload is a type that contains multiple locals such as a struct.
                try self.locals.ensureUnusedCapacity(self.gpa, 2);
                self.locals.appendAssumeCapacity(wasm.valtype(.i32)); // error values are always i32
                self.locals.appendAssumeCapacity(val_type);
                self.local_index += 2;

                return WValue{ .multi_value = .{
                    .index = initial_index,
                    .count = 2,
                } };
            },
            .Optional => {
                var opt_buf: Type.Payload.ElemType = undefined;
                const child_type = ty.optionalChild(&opt_buf);
                if (ty.isPtrLikeOptional()) {
                    return self.fail("TODO: wasm optional pointer", .{});
                }

                try self.locals.ensureUnusedCapacity(self.gpa, 2);
                self.locals.appendAssumeCapacity(wasm.valtype(.i32)); // optional 'tag' for null-checking is always i32
                self.locals.appendAssumeCapacity(try self.genValtype(child_type));
                self.local_index += 2;

                return WValue{ .multi_value = .{
                    .index = initial_index,
                    .count = 2,
                } };
            },
            else => {
                const valtype = try self.genValtype(ty);
                try self.locals.append(self.gpa, valtype);
                self.local_index += 1;
                return WValue{ .local = initial_index };
            },
        }
    }

    fn genFunctype(self: *Context) InnerError!void {
        assert(self.decl.has_tv);
        const ty = self.decl.ty;
        const writer = self.func_type_data.writer();

        try writer.writeByte(wasm.function_type);

        // param types
        try leb.writeULEB128(writer, @intCast(u32, ty.fnParamLen()));
        if (ty.fnParamLen() != 0) {
            const params = try self.gpa.alloc(Type, ty.fnParamLen());
            defer self.gpa.free(params);
            ty.fnParamTypes(params);
            for (params) |param_type| {
                // Can we maybe get the source index of each param?
                const val_type = try self.genValtype(param_type);
                try writer.writeByte(val_type);
            }
        }

        // return type
        const return_type = ty.fnReturnType();
        switch (return_type.zigTypeTag()) {
            .Void, .NoReturn => try leb.writeULEB128(writer, @as(u32, 0)),
            .Struct => return self.fail("TODO: Implement struct as return type for wasm", .{}),
            .Optional => return self.fail("TODO: Implement optionals as return type for wasm", .{}),
            .ErrorUnion => {
                const val_type = try self.genValtype(return_type.errorUnionPayload());

                // write down the amount of return values
                try leb.writeULEB128(writer, @as(u32, 2));
                try writer.writeByte(wasm.valtype(.i32)); // error code is always an i32 integer.
                try writer.writeByte(val_type);
            },
            else => {
                try leb.writeULEB128(writer, @as(u32, 1));
                // Can we maybe get the source index of the return type?
                const val_type = try self.genValtype(return_type);
                try writer.writeByte(val_type);
            },
        }
    }

    pub fn genFunc(self: *Context) InnerError!Result {
        try self.genFunctype();
        // TODO: check for and handle death of instructions

        // Reserve space to write the size after generating the code as well as space for locals count
        try self.code.resize(10);

        try self.genBody(self.air.getMainBody());

        // finally, write our local types at the 'offset' position
        {
            leb.writeUnsignedFixed(5, self.code.items[5..10], @intCast(u32, self.locals.items.len));

            // offset into 'code' section where we will put our locals types
            var local_offset: usize = 10;

            // emit the actual locals amount
            for (self.locals.items) |local| {
                var buf: [6]u8 = undefined;
                leb.writeUnsignedFixed(5, buf[0..5], @as(u32, 1));
                buf[5] = local;
                try self.code.insertSlice(local_offset, &buf);
                local_offset += 6;
            }
        }

        const writer = self.code.writer();
        try writer.writeByte(wasm.opcode(.end));

        // Fill in the size of the generated code to the reserved space at the
        // beginning of the buffer.
        const size = self.code.items.len - 5 + self.decl.fn_link.wasm.idx_refs.items.len * 5;
        leb.writeUnsignedFixed(5, self.code.items[0..5], @intCast(u32, size));

        // codegen data has been appended to `code`
        return Result.appended;
    }

    /// Generates the wasm bytecode for the declaration belonging to `Context`
    pub fn gen(self: *Context, ty: Type, val: Value) InnerError!Result {
        switch (ty.zigTypeTag()) {
            .Fn => {
                try self.genFunctype();
                if (val.tag() == .extern_fn) {
                    return Result.appended; // don't need code body for extern functions
                }
                return self.fail("TODO implement wasm codegen for function pointers", .{});
            },
            .Array => {
                if (val.castTag(.bytes)) |payload| {
                    if (ty.sentinel()) |sentinel| {
                        try self.code.appendSlice(payload.data);

                        switch (try self.gen(ty.elemType(), sentinel)) {
                            .appended => return Result.appended,
                            .externally_managed => |data| {
                                try self.code.appendSlice(data);
                                return Result.appended;
                            },
                        }
                    }
                    return Result{ .externally_managed = payload.data };
                } else return self.fail("TODO implement gen for more kinds of arrays", .{});
            },
            .Int => {
                const info = ty.intInfo(self.target);
                if (info.bits == 8 and info.signedness == .unsigned) {
                    const int_byte = val.toUnsignedInt();
                    try self.code.append(@intCast(u8, int_byte));
                    return Result.appended;
                }
                return self.fail("TODO: Implement codegen for int type: '{}'", .{ty});
            },
            .Enum => {
                try self.emitConstant(val, ty);
                return Result.appended;
            },
            else => |tag| return self.fail("TODO: Implement zig type codegen for type: '{s}'", .{tag}),
        }
    }

    fn genInst(self: *Context, inst: Air.Inst.Index) !WValue {
        const air_tags = self.air.instructions.items(.tag);
        return switch (air_tags[inst]) {
            .add => self.airBinOp(inst, .add),
            .addwrap => self.airWrapBinOp(inst, .add),
            .sub => self.airBinOp(inst, .sub),
            .subwrap => self.airWrapBinOp(inst, .sub),
            .mul => self.airBinOp(inst, .mul),
            .mulwrap => self.airWrapBinOp(inst, .mul),
            .div => self.airBinOp(inst, .div),
            .bit_and => self.airBinOp(inst, .@"and"),
            .bit_or => self.airBinOp(inst, .@"or"),
            .bool_and => self.airBinOp(inst, .@"and"),
            .bool_or => self.airBinOp(inst, .@"or"),
            .xor => self.airBinOp(inst, .xor),

            .cmp_eq => self.airCmp(inst, .eq),
            .cmp_gte => self.airCmp(inst, .gte),
            .cmp_gt => self.airCmp(inst, .gt),
            .cmp_lte => self.airCmp(inst, .lte),
            .cmp_lt => self.airCmp(inst, .lt),
            .cmp_neq => self.airCmp(inst, .neq),

            .alloc => self.airAlloc(inst),
            .arg => self.airArg(inst),
            .bitcast => self.airBitcast(inst),
            .block => self.airBlock(inst),
            .breakpoint => self.airBreakpoint(inst),
            .br => self.airBr(inst),
            .call => self.airCall(inst),
            .cond_br => self.airCondBr(inst),
            .constant => unreachable,
            .dbg_stmt => WValue.none,
            .intcast => self.airIntcast(inst),

            .is_err => self.airIsErr(inst, .i32_ne),
            .is_non_err => self.airIsErr(inst, .i32_eq),

            .is_null => self.airIsNull(inst, .i32_ne),
            .is_non_null => self.airIsNull(inst, .i32_eq),
            .is_null_ptr => self.airIsNull(inst, .i32_ne),
            .is_non_null_ptr => self.airIsNull(inst, .i32_eq),

            .load => self.airLoad(inst),
            .loop => self.airLoop(inst),
            .not => self.airNot(inst),
            .ret => self.airRet(inst),
            .store => self.airStore(inst),
            .struct_field_ptr => self.airStructFieldPtr(inst),
            .struct_field_ptr_index_0 => self.airStructFieldPtrIndex(inst, 0),
            .struct_field_ptr_index_1 => self.airStructFieldPtrIndex(inst, 1),
            .struct_field_ptr_index_2 => self.airStructFieldPtrIndex(inst, 2),
            .struct_field_ptr_index_3 => self.airStructFieldPtrIndex(inst, 3),
            .switch_br => self.airSwitchBr(inst),
            .unreach => self.airUnreachable(inst),
            .wrap_optional => self.airWrapOptional(inst),

            .unwrap_errunion_payload => self.airUnwrapErrUnionPayload(inst),
            .wrap_errunion_payload => self.airWrapErrUnionPayload(inst),

            .optional_payload => self.airOptionalPayload(inst),
            .optional_payload_ptr => self.airOptionalPayload(inst),
            else => |tag| self.fail("TODO: Implement wasm inst: {s}", .{@tagName(tag)}),
        };
    }

    fn genBody(self: *Context, body: []const Air.Inst.Index) InnerError!void {
        for (body) |inst| {
            const result = try self.genInst(inst);
            try self.values.putNoClobber(self.gpa, inst, result);
        }
    }

    fn airRet(self: *Context, inst: Air.Inst.Index) InnerError!WValue {
        const un_op = self.air.instructions.items(.data)[inst].un_op;
        const operand = self.resolveInst(un_op);
        try self.emitWValue(operand);
        try self.code.append(wasm.opcode(.@"return"));
        return .none;
    }

    fn airCall(self: *Context, inst: Air.Inst.Index) InnerError!WValue {
        const pl_op = self.air.instructions.items(.data)[inst].pl_op;
        const extra = self.air.extraData(Air.Call, pl_op.payload);
        const args = self.air.extra[extra.end..][0..extra.data.args_len];

        const target: *Decl = blk: {
            const func_val = self.air.value(pl_op.operand).?;

            if (func_val.castTag(.function)) |func| {
                break :blk func.data.owner_decl;
            } else if (func_val.castTag(.extern_fn)) |ext_fn| {
                break :blk ext_fn.data;
            }
            return self.fail("Expected a function, but instead found type '{s}'", .{func_val.tag()});
        };

        for (args) |arg| {
            const arg_val = self.resolveInst(@intToEnum(Air.Inst.Ref, arg));
            try self.emitWValue(arg_val);
        }

        try self.code.append(wasm.opcode(.call));

        // The function index immediate argument will be filled in using this data
        // in link.Wasm.flush().
        try self.decl.fn_link.wasm.idx_refs.append(self.gpa, .{
            .offset = @intCast(u32, self.code.items.len),
            .decl = target,
        });

        return .none;
    }

    fn airAlloc(self: *Context, inst: Air.Inst.Index) InnerError!WValue {
        const elem_type = self.air.typeOfIndex(inst).elemType();
        return self.allocLocal(elem_type);
    }

    fn airStore(self: *Context, inst: Air.Inst.Index) InnerError!WValue {
        const bin_op = self.air.instructions.items(.data)[inst].bin_op;
        const writer = self.code.writer();

        const lhs = self.resolveInst(bin_op.lhs);
        const rhs = self.resolveInst(bin_op.rhs);

        switch (lhs) {
            .multi_value => |multi_value| switch (rhs) {
                // When assigning a value to a multi_value such as a struct,
                // we simply assign the local_index to the rhs one.
                // This allows us to update struct fields without having to individually
                // set each local as each field's index will be calculated off the struct's base index
                .multi_value => self.values.put(self.gpa, Air.refToIndex(bin_op.lhs).?, rhs) catch unreachable, // Instruction does not dominate all uses!
                .constant, .none => {
                    // emit all values onto the stack if constant
                    try self.emitWValue(rhs);

                    // for each local, pop the stack value into the local
                    // As the last element is on top of the stack, we must populate the locals
                    // in reverse.
                    var i: u32 = multi_value.count;
                    while (i > 0) : (i -= 1) {
                        try writer.writeByte(wasm.opcode(.local_set));
                        try leb.writeULEB128(writer, multi_value.index + i - 1);
                    }
                },
                .local => {
                    // This can occur when we wrap a single value into a multi-value,
                    // such as wrapping a non-optional value into an optional.
                    // This means we must zero the null-tag, and set the payload.
                    assert(multi_value.count == 2);
                    // set null-tag
                    try writer.writeByte(wasm.opcode(.i32_const));
                    try leb.writeULEB128(writer, @as(u32, 0));
                    try writer.writeByte(wasm.opcode(.local_set));
                    try leb.writeULEB128(writer, multi_value.index);

                    // set payload
                    try self.emitWValue(rhs);
                    try writer.writeByte(wasm.opcode(.local_set));
                    try leb.writeULEB128(writer, multi_value.index + 1);
                },
                else => unreachable,
            },
            .local => |local| {
                try self.emitWValue(rhs);
                try writer.writeByte(wasm.opcode(.local_set));
                try leb.writeULEB128(writer, local);
            },
            else => unreachable,
        }
        return .none;
    }

    fn airLoad(self: *Context, inst: Air.Inst.Index) InnerError!WValue {
        const ty_op = self.air.instructions.items(.data)[inst].ty_op;
        return self.resolveInst(ty_op.operand);
    }

    fn airArg(self: *Context, inst: Air.Inst.Index) InnerError!WValue {
        _ = inst;
        // arguments share the index with locals
        defer self.local_index += 1;
        return WValue{ .local = self.local_index };
    }

    fn airBinOp(self: *Context, inst: Air.Inst.Index, op: Op) InnerError!WValue {
        const bin_op = self.air.instructions.items(.data)[inst].bin_op;
        const lhs = self.resolveInst(bin_op.lhs);
        const rhs = self.resolveInst(bin_op.rhs);

        // it's possible for both lhs and/or rhs to return an offset as well,
        // in which case we return the first offset occurance we find.
        const offset = blk: {
            if (lhs == .code_offset) break :blk lhs.code_offset;
            if (rhs == .code_offset) break :blk rhs.code_offset;
            break :blk self.code.items.len;
        };

        try self.emitWValue(lhs);
        try self.emitWValue(rhs);

        const bin_ty = self.air.typeOf(bin_op.lhs);
        const opcode: wasm.Opcode = buildOpcode(.{
            .op = op,
            .valtype1 = try self.typeToValtype(bin_ty),
            .signedness = if (bin_ty.isSignedInt()) .signed else .unsigned,
        });
        try self.code.append(wasm.opcode(opcode));
        return WValue{ .code_offset = offset };
    }

    fn airWrapBinOp(self: *Context, inst: Air.Inst.Index, op: Op) InnerError!WValue {
        const bin_op = self.air.instructions.items(.data)[inst].bin_op;
        const lhs = self.resolveInst(bin_op.lhs);
        const rhs = self.resolveInst(bin_op.rhs);

        // it's possible for both lhs and/or rhs to return an offset as well,
        // in which case we return the first offset occurance we find.
        const offset = blk: {
            if (lhs == .code_offset) break :blk lhs.code_offset;
            if (rhs == .code_offset) break :blk rhs.code_offset;
            break :blk self.code.items.len;
        };

        try self.emitWValue(lhs);
        try self.emitWValue(rhs);

        const bin_ty = self.air.typeOf(bin_op.lhs);
        const opcode: wasm.Opcode = buildOpcode(.{
            .op = op,
            .valtype1 = try self.typeToValtype(bin_ty),
            .signedness = if (bin_ty.isSignedInt()) .signed else .unsigned,
        });
        try self.code.append(wasm.opcode(opcode));

        const int_info = bin_ty.intInfo(self.target);
        const bitsize = int_info.bits;
        const is_signed = int_info.signedness == .signed;
        // if target type bitsize is x < 32 and 32 > x < 64, we perform
        // result & ((1<<N)-1) where N = bitsize or bitsize -1 incase of signed.
        if (bitsize != 32 and bitsize < 64) {
            // first check if we can use a single instruction,
            // wasm provides those if the integers are signed and 8/16-bit.
            // For arbitrary integer sizes, we use the algorithm mentioned above.
            if (is_signed and bitsize == 8) {
                try self.code.append(wasm.opcode(.i32_extend8_s));
            } else if (is_signed and bitsize == 16) {
                try self.code.append(wasm.opcode(.i32_extend16_s));
            } else {
                const result = (@as(u64, 1) << @intCast(u6, bitsize - @boolToInt(is_signed))) - 1;
                if (bitsize < 32) {
                    try self.code.append(wasm.opcode(.i32_const));
                    try leb.writeILEB128(self.code.writer(), @bitCast(i32, @intCast(u32, result)));
                    try self.code.append(wasm.opcode(.i32_and));
                } else {
                    try self.code.append(wasm.opcode(.i64_const));
                    try leb.writeILEB128(self.code.writer(), @bitCast(i64, result));
                    try self.code.append(wasm.opcode(.i64_and));
                }
            }
        } else if (int_info.bits > 64) {
            return self.fail("TODO wasm: Integer wrapping for bitsizes larger than 64", .{});
        }

        return WValue{ .code_offset = offset };
    }

    fn emitConstant(self: *Context, val: Value, ty: Type) InnerError!void {
        const writer = self.code.writer();
        switch (ty.zigTypeTag()) {
            .Int => {
                // write opcode
                const opcode: wasm.Opcode = buildOpcode(.{
                    .op = .@"const",
                    .valtype1 = try self.typeToValtype(ty),
                });
                try writer.writeByte(wasm.opcode(opcode));
                const int_info = ty.intInfo(self.target);
                // write constant
                switch (int_info.signedness) {
                    .signed => try leb.writeILEB128(writer, val.toSignedInt()),
                    .unsigned => switch (int_info.bits) {
                        0...32 => try leb.writeILEB128(writer, @bitCast(i32, @intCast(u32, val.toUnsignedInt()))),
                        33...64 => try leb.writeILEB128(writer, @bitCast(i64, val.toUnsignedInt())),
                        else => |bits| return self.fail("Wasm TODO: emitConstant for integer with {d} bits", .{bits}),
                    },
                }
            },
            .Bool => {
                // write opcode
                try writer.writeByte(wasm.opcode(.i32_const));
                // write constant
                try leb.writeILEB128(writer, val.toSignedInt());
            },
            .Float => {
                // write opcode
                const opcode: wasm.Opcode = buildOpcode(.{
                    .op = .@"const",
                    .valtype1 = try self.typeToValtype(ty),
                });
                try writer.writeByte(wasm.opcode(opcode));
                // write constant
                switch (ty.floatBits(self.target)) {
                    0...32 => try writer.writeIntLittle(u32, @bitCast(u32, val.toFloat(f32))),
                    64 => try writer.writeIntLittle(u64, @bitCast(u64, val.toFloat(f64))),
                    else => |bits| return self.fail("Wasm TODO: emitConstant for float with {d} bits", .{bits}),
                }
            },
            .Pointer => {
                if (val.castTag(.decl_ref)) |payload| {
                    const decl = payload.data;
                    decl.alive = true;

                    // offset into the offset table within the 'data' section
                    const ptr_width = self.target.cpu.arch.ptrBitWidth() / 8;
                    try writer.writeByte(wasm.opcode(.i32_const));
                    try leb.writeULEB128(writer, decl.link.wasm.offset_index * ptr_width);

                    // memory instruction followed by their memarg immediate
                    // memarg ::== x:u32, y:u32 => {align x, offset y}
                    try writer.writeByte(wasm.opcode(.i32_load));
                    try leb.writeULEB128(writer, @as(u32, 0));
                    try leb.writeULEB128(writer, @as(u32, 0));
                } else return self.fail("Wasm TODO: emitConstant for other const pointer tag {s}", .{val.tag()});
            },
            .Void => {},
            .Enum => {
                if (val.castTag(.enum_field_index)) |field_index| {
                    switch (ty.tag()) {
                        .enum_simple => {
                            try writer.writeByte(wasm.opcode(.i32_const));
                            try leb.writeULEB128(writer, field_index.data);
                        },
                        .enum_full, .enum_nonexhaustive => {
                            const enum_full = ty.cast(Type.Payload.EnumFull).?.data;
                            if (enum_full.values.count() != 0) {
                                const tag_val = enum_full.values.keys()[field_index.data];
                                try self.emitConstant(tag_val, enum_full.tag_ty);
                            } else {
                                try writer.writeByte(wasm.opcode(.i32_const));
                                try leb.writeULEB128(writer, field_index.data);
                            }
                        },
                        else => unreachable,
                    }
                } else {
                    var int_tag_buffer: Type.Payload.Bits = undefined;
                    const int_tag_ty = ty.intTagType(&int_tag_buffer);
                    try self.emitConstant(val, int_tag_ty);
                }
            },
            .ErrorSet => {
                const error_index = self.global_error_set.get(val.getError().?).?;
                try writer.writeByte(wasm.opcode(.i32_const));
                try leb.writeULEB128(writer, error_index);
            },
            .ErrorUnion => {
                const error_type = ty.errorUnionSet();
                const payload_type = ty.errorUnionPayload();
                if (val.castTag(.eu_payload)) |pl| {
                    const payload_val = pl.data;
                    // no error, so write a '0' const
                    try writer.writeByte(wasm.opcode(.i32_const));
                    try leb.writeULEB128(writer, @as(u32, 0));
                    // after the error code, we emit the payload
                    try self.emitConstant(payload_val, payload_type);
                } else {
                    // write the error val
                    try self.emitConstant(val, error_type);

                    // no payload, so write a '0' const
                    const opcode: wasm.Opcode = buildOpcode(.{
                        .op = .@"const",
                        .valtype1 = try self.typeToValtype(payload_type),
                    });
                    try writer.writeByte(wasm.opcode(opcode));
                    try leb.writeULEB128(writer, @as(u32, 0));
                }
            },
            .Optional => {
                var buf: Type.Payload.ElemType = undefined;
                const payload_type = ty.optionalChild(&buf);
                if (ty.isPtrLikeOptional()) {
                    return self.fail("Wasm TODO: emitConstant for optional pointer", .{});
                }

                // When constant has value 'null', set is_null local to '1'
                // and payload to '0'
                if (val.castTag(.opt_payload)) |pl| {
                    const payload_val = pl.data;
                    try writer.writeByte(wasm.opcode(.i32_const));
                    try leb.writeILEB128(writer, @as(i32, 0));
                    try self.emitConstant(payload_val, payload_type);
                } else {
                    try writer.writeByte(wasm.opcode(.i32_const));
                    try leb.writeILEB128(writer, @as(i32, 1));

                    const opcode: wasm.Opcode = buildOpcode(.{
                        .op = .@"const",
                        .valtype1 = try self.typeToValtype(payload_type),
                    });
                    try writer.writeByte(wasm.opcode(opcode));
                    try leb.writeULEB128(writer, @as(u32, 0));
                }
            },
            else => |zig_type| return self.fail("Wasm TODO: emitConstant for zigTypeTag {s}", .{zig_type}),
        }
    }

    /// Returns a `Value` as a signed 32 bit value.
    /// It's illegal to provide a value with a type that cannot be represented
    /// as an integer value.
    fn valueAsI32(self: Context, val: Value, ty: Type) i32 {
        switch (ty.zigTypeTag()) {
            .Enum => {
                if (val.castTag(.enum_field_index)) |field_index| {
                    switch (ty.tag()) {
                        .enum_simple => return @bitCast(i32, field_index.data),
                        .enum_full, .enum_nonexhaustive => {
                            const enum_full = ty.cast(Type.Payload.EnumFull).?.data;
                            if (enum_full.values.count() != 0) {
                                const tag_val = enum_full.values.keys()[field_index.data];
                                return self.valueAsI32(tag_val, enum_full.tag_ty);
                            } else return @bitCast(i32, field_index.data);
                        },
                        else => unreachable,
                    }
                } else {
                    var int_tag_buffer: Type.Payload.Bits = undefined;
                    const int_tag_ty = ty.intTagType(&int_tag_buffer);
                    return self.valueAsI32(val, int_tag_ty);
                }
            },
            .Int => switch (ty.intInfo(self.target).signedness) {
                .signed => return @truncate(i32, val.toSignedInt()),
                .unsigned => return @bitCast(i32, @truncate(u32, val.toUnsignedInt())),
            },
            .ErrorSet => {
                const error_index = self.global_error_set.get(val.getError().?).?;
                return @bitCast(i32, error_index);
            },
            else => unreachable, // Programmer called this function for an illegal type
        }
    }

    fn airBlock(self: *Context, inst: Air.Inst.Index) InnerError!WValue {
        const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
        const block_ty = try self.genBlockType(self.air.getRefType(ty_pl.ty));
        const extra = self.air.extraData(Air.Block, ty_pl.payload);
        const body = self.air.extra[extra.end..][0..extra.data.body_len];

        try self.startBlock(.block, block_ty, null);
        // Here we set the current block idx, so breaks know the depth to jump
        // to when breaking out.
        try self.blocks.putNoClobber(self.gpa, inst, self.block_depth);
        try self.genBody(body);
        try self.endBlock();

        return .none;
    }

    /// appends a new wasm block to the code section and increases the `block_depth` by 1
    fn startBlock(self: *Context, block_type: wasm.Opcode, valtype: u8, with_offset: ?usize) !void {
        self.block_depth += 1;
        if (with_offset) |offset| {
            try self.code.insert(offset, wasm.opcode(block_type));
            try self.code.insert(offset + 1, valtype);
        } else {
            try self.code.append(wasm.opcode(block_type));
            try self.code.append(valtype);
        }
    }

    /// Ends the current wasm block and decreases the `block_depth` by 1
    fn endBlock(self: *Context) !void {
        try self.code.append(wasm.opcode(.end));
        self.block_depth -= 1;
    }

    fn airLoop(self: *Context, inst: Air.Inst.Index) InnerError!WValue {
        const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
        const loop = self.air.extraData(Air.Block, ty_pl.payload);
        const body = self.air.extra[loop.end..][0..loop.data.body_len];

        // result type of loop is always 'noreturn', meaning we can always
        // emit the wasm type 'block_empty'.
        try self.startBlock(.loop, wasm.block_empty, null);
        try self.genBody(body);

        // breaking to the index of a loop block will continue the loop instead
        try self.code.append(wasm.opcode(.br));
        try leb.writeULEB128(self.code.writer(), @as(u32, 0));

        try self.endBlock();

        return .none;
    }

    fn airCondBr(self: *Context, inst: Air.Inst.Index) InnerError!WValue {
        const pl_op = self.air.instructions.items(.data)[inst].pl_op;
        const condition = self.resolveInst(pl_op.operand);
        const extra = self.air.extraData(Air.CondBr, pl_op.payload);
        const then_body = self.air.extra[extra.end..][0..extra.data.then_body_len];
        const else_body = self.air.extra[extra.end + then_body.len ..][0..extra.data.else_body_len];
        const writer = self.code.writer();
        // TODO: Handle death instructions for then and else body

        // insert blocks at the position of `offset` so
        // the condition can jump to it
        const offset = switch (condition) {
            .code_offset => |offset| offset,
            else => blk: {
                const offset = self.code.items.len;
                try self.emitWValue(condition);
                break :blk offset;
            },
        };

        // result type is always noreturn, so use `block_empty` as type.
        try self.startBlock(.block, wasm.block_empty, offset);

        // we inserted the block in front of the condition
        // so now check if condition matches. If not, break outside this block
        // and continue with the then codepath
        try writer.writeByte(wasm.opcode(.br_if));
        try leb.writeULEB128(writer, @as(u32, 0));

        try self.genBody(else_body);
        try self.endBlock();

        // Outer block that matches the condition
        try self.genBody(then_body);

        return .none;
    }

    fn airCmp(self: *Context, inst: Air.Inst.Index, op: std.math.CompareOperator) InnerError!WValue {
        // save offset, so potential conditions can insert blocks in front of
        // the comparison that we can later jump back to
        const offset = self.code.items.len;

        const data: Air.Inst.Data = self.air.instructions.items(.data)[inst];
        const lhs = self.resolveInst(data.bin_op.lhs);
        const rhs = self.resolveInst(data.bin_op.rhs);
        const lhs_ty = self.air.typeOf(data.bin_op.lhs);

        try self.emitWValue(lhs);
        try self.emitWValue(rhs);

        const signedness: std.builtin.Signedness = blk: {
            // by default we tell the operand type is unsigned (i.e. bools and enum values)
            if (lhs_ty.zigTypeTag() != .Int) break :blk .unsigned;

            // incase of an actual integer, we emit the correct signedness
            break :blk lhs_ty.intInfo(self.target).signedness;
        };
        const opcode: wasm.Opcode = buildOpcode(.{
            .valtype1 = try self.typeToValtype(lhs_ty),
            .op = switch (op) {
                .lt => .lt,
                .lte => .le,
                .eq => .eq,
                .neq => .ne,
                .gte => .ge,
                .gt => .gt,
            },
            .signedness = signedness,
        });
        try self.code.append(wasm.opcode(opcode));
        return WValue{ .code_offset = offset };
    }

    fn airBr(self: *Context, inst: Air.Inst.Index) InnerError!WValue {
        const br = self.air.instructions.items(.data)[inst].br;

        // if operand has codegen bits we should break with a value
        if (self.air.typeOf(br.operand).hasCodeGenBits()) {
            try self.emitWValue(self.resolveInst(br.operand));
        }

        // We map every block to its block index.
        // We then determine how far we have to jump to it by substracting it from current block depth
        const idx: u32 = self.block_depth - self.blocks.get(br.block_inst).?;
        const writer = self.code.writer();
        try writer.writeByte(wasm.opcode(.br));
        try leb.writeULEB128(writer, idx);

        return .none;
    }

    fn airNot(self: *Context, inst: Air.Inst.Index) InnerError!WValue {
        const ty_op = self.air.instructions.items(.data)[inst].ty_op;
        const offset = self.code.items.len;

        const operand = self.resolveInst(ty_op.operand);
        try self.emitWValue(operand);

        // wasm does not have booleans nor the `not` instruction, therefore compare with 0
        // to create the same logic
        const writer = self.code.writer();
        try writer.writeByte(wasm.opcode(.i32_const));
        try leb.writeILEB128(writer, @as(i32, 0));

        try writer.writeByte(wasm.opcode(.i32_eq));

        return WValue{ .code_offset = offset };
    }

    fn airBreakpoint(self: *Context, inst: Air.Inst.Index) InnerError!WValue {
        _ = self;
        _ = inst;
        // unsupported by wasm itself. Can be implemented once we support DWARF
        // for wasm
        return .none;
    }

    fn airUnreachable(self: *Context, inst: Air.Inst.Index) InnerError!WValue {
        _ = inst;
        try self.code.append(wasm.opcode(.@"unreachable"));
        return .none;
    }

    fn airBitcast(self: *Context, inst: Air.Inst.Index) InnerError!WValue {
        const ty_op = self.air.instructions.items(.data)[inst].ty_op;
        return self.resolveInst(ty_op.operand);
    }

    fn airStructFieldPtr(self: *Context, inst: Air.Inst.Index) InnerError!WValue {
        const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
        const extra = self.air.extraData(Air.StructField, ty_pl.payload);
        const struct_ptr = self.resolveInst(extra.data.struct_operand);
        return structFieldPtr(struct_ptr, extra.data.field_index);
    }
    fn airStructFieldPtrIndex(self: *Context, inst: Air.Inst.Index, index: u32) InnerError!WValue {
        const ty_op = self.air.instructions.items(.data)[inst].ty_op;
        const struct_ptr = self.resolveInst(ty_op.operand);
        return structFieldPtr(struct_ptr, index);
    }
    fn structFieldPtr(struct_ptr: WValue, index: u32) InnerError!WValue {
        return WValue{ .local = struct_ptr.multi_value.index + index };
    }

    fn airSwitchBr(self: *Context, inst: Air.Inst.Index) InnerError!WValue {
        // result type is always 'noreturn'
        const blocktype = wasm.block_empty;
        const pl_op = self.air.instructions.items(.data)[inst].pl_op;
        const target = self.resolveInst(pl_op.operand);
        const target_ty = self.air.typeOf(pl_op.operand);
        const switch_br = self.air.extraData(Air.SwitchBr, pl_op.payload);
        var extra_index: usize = switch_br.end;
        var case_i: u32 = 0;

        // a list that maps each value with its value and body based on the order inside the list.
        const CaseValue = struct { integer: i32, value: Value };
        var case_list = try std.ArrayList(struct {
            values: []const CaseValue,
            body: []const Air.Inst.Index,
        }).initCapacity(self.gpa, switch_br.data.cases_len);
        defer for (case_list.items) |case| {
            self.gpa.free(case.values);
        } else case_list.deinit();

        var lowest: i32 = 0;
        var highest: i32 = 0;
        while (case_i < switch_br.data.cases_len) : (case_i += 1) {
            const case = self.air.extraData(Air.SwitchBr.Case, extra_index);
            const items = @bitCast([]const Air.Inst.Ref, self.air.extra[case.end..][0..case.data.items_len]);
            const case_body = self.air.extra[case.end + items.len ..][0..case.data.body_len];
            extra_index = case.end + items.len + case_body.len;
            const values = try self.gpa.alloc(CaseValue, items.len);
            errdefer self.gpa.free(values);

            for (items) |ref, i| {
                const item_val = self.air.value(ref).?;
                const int_val = self.valueAsI32(item_val, target_ty);
                if (int_val < lowest) {
                    lowest = int_val;
                }
                if (int_val > highest) {
                    highest = int_val;
                }
                values[i] = .{ .integer = int_val, .value = item_val };
            }

            case_list.appendAssumeCapacity(.{ .values = values, .body = case_body });
            try self.startBlock(.block, blocktype, null);
        }

        // When the highest and lowest values are seperated by '50',
        // we define it as sparse and use an if/else-chain, rather than a jump table.
        // When the target is an integer size larger than u32, we have no way to use the value
        // as an index, therefore we also use an if/else-chain for those cases.
        // TODO: Benchmark this to find a proper value, LLVM seems to draw the line at '40~45'.
        const is_sparse = highest - lowest > 50 or target_ty.bitSize(self.target) > 32;

        const else_body = self.air.extra[extra_index..][0..switch_br.data.else_body_len];
        const has_else_body = else_body.len != 0;
        if (has_else_body) {
            try self.startBlock(.block, blocktype, null);
        }

        if (!is_sparse) {
            // Generate the jump table 'br_table' when the prongs are not sparse.
            // The value 'target' represents the index into the table.
            // Each index in the table represents a label to the branch
            // to jump to.
            try self.startBlock(.block, blocktype, null);
            try self.emitWValue(target);
            if (lowest < 0) {
                // since br_table works using indexes, starting from '0', we must ensure all values
                // we put inside, are atleast 0.
                try self.code.append(wasm.opcode(.i32_const));
                try leb.writeILEB128(self.code.writer(), lowest * -1);
                try self.code.append(wasm.opcode(.i32_add));
            }
            try self.code.append(wasm.opcode(.br_table));
            const depth = highest - lowest + @boolToInt(has_else_body);
            try leb.writeILEB128(self.code.writer(), depth);
            while (lowest <= highest) : (lowest += 1) {
                // idx represents the branch we jump to
                const idx = blk: {
                    for (case_list.items) |case, idx| {
                        for (case.values) |case_value| {
                            if (case_value.integer == lowest) break :blk @intCast(u32, idx);
                        }
                    }
                    break :blk if (has_else_body) case_i else unreachable;
                };
                try leb.writeULEB128(self.code.writer(), idx);
            } else if (has_else_body) {
                try leb.writeULEB128(self.code.writer(), @as(u32, case_i)); // default branch
            }
            try self.endBlock();
        }

        const signedness: std.builtin.Signedness = blk: {
            // by default we tell the operand type is unsigned (i.e. bools and enum values)
            if (target_ty.zigTypeTag() != .Int) break :blk .unsigned;

            // incase of an actual integer, we emit the correct signedness
            break :blk target_ty.intInfo(self.target).signedness;
        };

        for (case_list.items) |case| {
            // when sparse, we use if/else-chain, so emit conditional checks
            if (is_sparse) {
                // for single value prong we can emit a simple if
                if (case.values.len == 1) {
                    try self.emitWValue(target);
                    try self.emitConstant(case.values[0].value, target_ty);
                    const opcode = buildOpcode(.{
                        .valtype1 = try self.typeToValtype(target_ty),
                        .op = .ne, // not equal, because we want to jump out of this block if it does not match the condition.
                        .signedness = signedness,
                    });
                    try self.code.append(wasm.opcode(opcode));
                    try self.code.append(wasm.opcode(.br_if));
                    try leb.writeULEB128(self.code.writer(), @as(u32, 0));
                } else {
                    // in multi-value prongs we must check if any prongs match the target value.
                    try self.startBlock(.block, blocktype, null);
                    for (case.values) |value| {
                        try self.emitWValue(target);
                        try self.emitConstant(value.value, target_ty);
                        const opcode = buildOpcode(.{
                            .valtype1 = try self.typeToValtype(target_ty),
                            .op = .eq,
                            .signedness = signedness,
                        });
                        try self.code.append(wasm.opcode(opcode));
                        try self.code.append(wasm.opcode(.br_if));
                        try leb.writeULEB128(self.code.writer(), @as(u32, 0));
                    }
                    // value did not match any of the prong values
                    try self.code.append(wasm.opcode(.br));
                    try leb.writeULEB128(self.code.writer(), @as(u32, 1));
                    try self.endBlock();
                }
            }
            try self.genBody(case.body);
            try self.endBlock();
        }

        if (has_else_body) {
            try self.genBody(else_body);
            try self.endBlock();
        }
        return .none;
    }

    fn airIsErr(self: *Context, inst: Air.Inst.Index, opcode: wasm.Opcode) InnerError!WValue {
        const un_op = self.air.instructions.items(.data)[inst].un_op;
        const operand = self.resolveInst(un_op);
        const offset = self.code.items.len;
        const writer = self.code.writer();

        // load the error value which is positioned at multi_value's index
        try self.emitWValue(.{ .local = operand.multi_value.index });
        // Compare the error value with '0'
        try writer.writeByte(wasm.opcode(.i32_const));
        try leb.writeILEB128(writer, @as(i32, 0));

        try writer.writeByte(@enumToInt(opcode));

        return WValue{ .code_offset = offset };
    }

    fn airUnwrapErrUnionPayload(self: *Context, inst: Air.Inst.Index) InnerError!WValue {
        const ty_op = self.air.instructions.items(.data)[inst].ty_op;
        const operand = self.resolveInst(ty_op.operand);
        // The index of multi_value contains the error code. To get the initial index of the payload we get
        // the following index. Next, convert it to a `WValue.local`
        //
        // TODO: Check if payload is a type that requires a multi_value as well and emit that instead. i.e. a struct.
        return WValue{ .local = operand.multi_value.index + 1 };
    }

    fn airWrapErrUnionPayload(self: *Context, inst: Air.Inst.Index) InnerError!WValue {
        const ty_op = self.air.instructions.items(.data)[inst].ty_op;
        return self.resolveInst(ty_op.operand);
    }

    fn airIntcast(self: *Context, inst: Air.Inst.Index) InnerError!WValue {
        const ty_op = self.air.instructions.items(.data)[inst].ty_op;
        const ty = self.air.getRefType(ty_op.ty);
        const operand = self.resolveInst(ty_op.operand);
        const ref_ty = self.air.typeOf(ty_op.operand);
        const ref_info = ref_ty.intInfo(self.target);
        const op_bits = ref_info.bits;
        const wanted_bits = ty.intInfo(self.target).bits;

        try self.emitWValue(operand);
        if (op_bits > 32 and wanted_bits <= 32) {
            try self.code.append(wasm.opcode(.i32_wrap_i64));
        } else if (op_bits <= 32 and wanted_bits > 32) {
            try self.code.append(wasm.opcode(switch (ref_info.signedness) {
                .signed => .i64_extend_i32_s,
                .unsigned => .i64_extend_i32_u,
            }));
        }

        // other cases are no-op
        return .none;
    }

    fn airIsNull(self: *Context, inst: Air.Inst.Index, opcode: wasm.Opcode) InnerError!WValue {
        const un_op = self.air.instructions.items(.data)[inst].un_op;
        const operand = self.resolveInst(un_op);
        // const offset = self.code.items.len;
        const writer = self.code.writer();

        // load the null value which is positioned at multi_value's index
        try self.emitWValue(.{ .local = operand.multi_value.index });
        // Compare the null value with '0'
        try writer.writeByte(wasm.opcode(.i32_const));
        try leb.writeILEB128(writer, @as(i32, 0));

        try writer.writeByte(@enumToInt(opcode));

        // we save the result in a new local
        const local = try self.allocLocal(Type.initTag(.i32));
        try writer.writeByte(wasm.opcode(.local_set));
        try leb.writeULEB128(writer, local.local);

        return local;
    }

    fn airOptionalPayload(self: *Context, inst: Air.Inst.Index) InnerError!WValue {
        const ty_op = self.air.instructions.items(.data)[inst].ty_op;
        const operand = self.resolveInst(ty_op.operand);
        return WValue{ .local = operand.multi_value.index + 1 };
    }

    fn airWrapOptional(self: *Context, inst: Air.Inst.Index) InnerError!WValue {
        const ty_op = self.air.instructions.items(.data)[inst].ty_op;
        return self.resolveInst(ty_op.operand);
    }
};
