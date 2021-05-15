const std = @import("std");
const Allocator = std.mem.Allocator;
const Target = std.Target;
const log = std.log.scoped(.codegen);

const spec = @import("spirv/spec.zig");
const Module = @import("../Module.zig");
const Decl = Module.Decl;
const Type = @import("../type.zig").Type;
const Value = @import("../value.zig").Value;
const LazySrcLoc = Module.LazySrcLoc;
const ir = @import("../ir.zig");
const Inst = ir.Inst;

pub const TypeMap = std.HashMap(Type, u32, Type.hash, Type.eql, std.hash_map.default_max_load_percentage);
pub const ValueMap = std.AutoHashMap(*Inst, u32);

pub fn writeOpcode(code: *std.ArrayList(u32), opcode: spec.Opcode, arg_count: u32) !void {
    const word_count = arg_count + 1;
    try code.append((word_count << 16) | @enumToInt(opcode));
}

pub fn writeInstruction(code: *std.ArrayList(u32), opcode: spec.Opcode, args: []const u32) !void {
    try writeOpcode(code, opcode, @intCast(u32, args.len));
    try code.appendSlice(args);
}

/// This structure represents a SPIR-V binary module being compiled, and keeps track of relevant information
/// such as code for the different logical sections, and the next result-id.
pub const SPIRVModule = struct {
    next_result_id: u32,
    types_globals_constants: std.ArrayList(u32),
    fn_decls: std.ArrayList(u32),

    pub fn init(allocator: *Allocator) SPIRVModule {
        return .{
            .next_result_id = 1, // 0 is an invalid SPIR-V result ID.
            .types_globals_constants = std.ArrayList(u32).init(allocator),
            .fn_decls = std.ArrayList(u32).init(allocator),
        };
    }

    pub fn deinit(self: *SPIRVModule) void {
        self.types_globals_constants.deinit();
        self.fn_decls.deinit();
    }

    pub fn allocResultId(self: *SPIRVModule) u32 {
        defer self.next_result_id += 1;
        return self.next_result_id;
    }

    pub fn resultIdBound(self: *SPIRVModule) u32 {
        return self.next_result_id;
    }
};

/// This structure is used to compile a declaration, and contains all relevant meta-information to deal with that.
pub const DeclGen = struct {
    module: *Module,
    spv: *SPIRVModule,

    args: std.ArrayList(u32),
    next_arg_index: u32,

    types: TypeMap,
    values: ValueMap,

    decl: *Decl,
    error_msg: ?*Module.ErrorMsg,

    const Error = error{
        AnalysisFail,
        OutOfMemory
    };

    fn fail(self: *DeclGen, src: LazySrcLoc, comptime format: []const u8, args: anytype) Error {
        @setCold(true);
        const src_loc = src.toSrcLocWithDecl(self.decl);
        self.error_msg = try Module.ErrorMsg.create(self.module.gpa, src_loc, format, args);
        return error.AnalysisFail;
    }

    fn resolve(self: *DeclGen, inst: *Inst) !u32 {
        if (inst.value()) |val| {
            return self.genConstant(inst.ty, val);
        }

        return self.values.get(inst).?; // Instruction does not dominate all uses!
    }

    /// SPIR-V requires enabling specific integer sizes through capabilities, and so if they are not enabled, we need
    /// to emulate them in other instructions/types. This function returns, given an integer bit width (signed or unsigned, sign
    /// included), the width of the underlying type which represents it, given the enabled features for the current target.
    /// If the result is `null`, the largest type the target platform supports natively is not able to perform computations using
    /// that size. In this case, multiple elements of the largest type should be used.
    /// The backing type will be chosen as the smallest supported integer larger or equal to it in number of bits.
    /// The result is valid to be used with OpTypeInt.
    /// asserts `ty` is an integer.
    /// TODO: The extension SPV_INTEL_arbitrary_precision_integers allows any integer size (at least up to 32 bits).
    /// TODO: This probably needs an ABI-version as well (especially in combination with SPV_INTEL_arbitrary_precision_integers).
    /// TODO: Should the result of this function be cached?
    fn backingIntBits(self: *DeclGen, ty: Type) ?u32 {
        const target = self.module.getTarget();
        const int_info = ty.intInfo(target);

        // TODO: Figure out what to do with u0/i0.
        std.debug.assert(int_info.bits != 0);

        // 8, 16 and 64-bit integers require the Int8, Int16 and Inr64 capabilities respectively.
        const ints = [_]struct{ bits: u32, feature: ?Target.spirv.Feature } {
            .{ .bits = 8, .feature = .Int8 },
            .{ .bits = 16, .feature = .Int16 },
            .{ .bits = 32, .feature = null },
            .{ .bits = 64, .feature = .Int64 },
        };

        for (ints) |int| {
            const has_feature = if (int.feature) |feature|
                Target.spirv.featureSetHas(target.cpu.features, feature)
            else
                true;

            if (int_info.bits <= int.bits and has_feature) {
                return int.bits;
            }
        }

        return null;
    }

    /// Return the amount of bits in the largest supported integer type. This is either 32 (always supported), or 64 (if
    /// the Int64 capability is enabled).
    /// Note: The extension SPV_INTEL_arbitrary_precision_integers allows any integer size (at least up to 32 bits).
    /// In theory that could also be used, but since the spec says that it only guarantees support up to 32-bit ints there
    /// is no way of knowing whether those are actually supported.
    /// TODO: Maybe this should be cached?
    fn largestSupportedIntBits(self: *DeclGen) u32 {
        const target = self.module.getTarget();
        return if (Target.spirv.featureSetHas(target.cpu.features, .Int64))
            64
        else
            32;
    }

    /// Checks whether the type is "composite int", an integer consisting of multiple native integers. These are represented by
    /// arrays of largestSupportedIntBits().
    /// Asserts `ty` is an integer.
    fn isCompositeInt(self: *DeclGen, ty: Type) bool {
        return self.backingIntBits(ty) == null;
    }

    /// Generate a constant representing `val`.
    /// TODO: Deduplication?
    fn genConstant(self: *DeclGen, ty: Type, val: Value) Error!u32 {
        const code = &self.spv.types_globals_constants;
        const result_id = self.spv.allocResultId();
        const result_type_id = try self.getOrGenType(ty);

        if (val.isUndef()) {
            try writeInstruction(code, .OpUndef, &[_]u32{ result_type_id, result_id });
            return result_id;
        }

        switch (ty.zigTypeTag()) {
            .Bool => {
                const opcode: spec.Opcode = if (val.toBool()) .OpConstantTrue else .OpConstantFalse;
                try writeInstruction(code, opcode, &[_]u32{ result_type_id, result_id });
            },
            .Float => {
                // At this point we are guaranteed that the target floating point type is supported, otherwise the function
                // would have exited at getOrGenType(ty).

                // f16 and f32 require one word of storage. f64 requires 2, low-order first.

                switch (val.tag()) {
                    .float_16 => try writeInstruction(code, .OpConstant, &[_]u32{
                        result_type_id,
                        result_id,
                        @bitCast(u16, val.castTag(.float_16).?.data)
                    }),
                    .float_32 => try writeInstruction(code, .OpConstant, &[_]u32{
                        result_type_id,
                        result_id,
                        @bitCast(u32, val.castTag(.float_32).?.data)
                    }),
                    .float_64 => {
                        const float_bits = @bitCast(u64, val.castTag(.float_64).?.data);
                        try writeInstruction(code, .OpConstant, &[_]u32{
                            result_type_id,
                            result_id,
                            @truncate(u32, float_bits),
                            @truncate(u32, float_bits >> 32),
                        });
                    },
                    .float_128 => unreachable, // Filtered out in the call to getOrGenType.
                    // TODO: What tags do we need to handle here anyway?
                    else => return self.fail(.{.node_offset = 0}, "TODO: SPIR-V backend: float constant generation of value {s}\n", .{ val.tag() }),
                }
            },
            else => return self.fail(.{.node_offset = 0}, "TODO: SPIR-V backend: constant generation of type {s}\n", .{ ty.zigTypeTag() }),
        }

        return result_id;
    }

    fn getOrGenType(self: *DeclGen, ty: Type) Error!u32 {
        // We can't use getOrPut here so we can recursively generate types.
        if (self.types.get(ty)) |already_generated| {
            return already_generated;
        }

        const target = self.module.getTarget();
        const code = &self.spv.types_globals_constants;
        const result_id = self.spv.allocResultId();

        switch (ty.zigTypeTag()) {
            .Void => try writeInstruction(code, .OpTypeVoid, &[_]u32{ result_id }),
            .Bool => try writeInstruction(code, .OpTypeBool, &[_]u32{ result_id }),
            .Int => {
                const backing_bits = self.backingIntBits(ty) orelse {
                    // Integers too big for any native type are represented as "composite integers": An array of largestSupportedIntBits.
                    return self.fail(.{.node_offset = 0}, "TODO: SPIR-V backend: implement composite ints {}", .{ ty });
                };

                // TODO: If backing_bits != int_info.bits, a duplicate type might be generated here.
                try writeInstruction(code, .OpTypeInt, &[_]u32{
                    result_id,
                    backing_bits,
                    @boolToInt(ty.isSignedInt()),
                });
            },
            .Float => {
                // We can (and want) not really emulate floating points with other floating point types like with the integer types,
                // so if the float is not supported, just return an error.
                const bits = ty.floatBits(target);
                const supported = switch (bits) {
                    16 => Target.spirv.featureSetHas(target.cpu.features, .Float16),
                    32 => true,
                    64 => Target.spirv.featureSetHas(target.cpu.features, .Float64),
                    else => false,
                };

                if (!supported) {
                    return self.fail(.{.node_offset = 0}, "Floating point width of {} bits is not supported for the current SPIR-V feature set", .{ bits });
                }

                try writeInstruction(code, .OpTypeFloat, &[_]u32{ result_id, bits });
            },
            .Fn => {
                // We only support zig-calling-convention functions, no varargs.
                if (ty.fnCallingConvention() != .Unspecified)
                    return self.fail(.{.node_offset = 0}, "Unsupported calling convention for SPIR-V", .{});
                if (ty.fnIsVarArgs())
                    return self.fail(.{.node_offset = 0}, "VarArgs unsupported for SPIR-V", .{});

                // In order to avoid a temporary here, first generate all the required types and then simply look them up
                // when generating the function type.
                const params = ty.fnParamLen();
                var i: usize = 0;
                while (i < params) : (i += 1) {
                    _ = try self.getOrGenType(ty.fnParamType(i));
                }

                const return_type_id = try self.getOrGenType(ty.fnReturnType());

                // result id + result type id + parameter type ids.
                try writeOpcode(code, .OpTypeFunction, 2 + @intCast(u32, ty.fnParamLen()) );
                try code.appendSlice(&.{ result_id, return_type_id });

                i = 0;
                while (i < params) : (i += 1) {
                    const param_type_id = self.types.get(ty.fnParamType(i)).?;
                    try code.append(param_type_id);
                }
            },
            .Vector => {
                // Although not 100% the same, Zig vectors map quite neatly to SPIR-V vectors (including many integer and float operations
                // which work on them), so simply use those.
                // Note: SPIR-V vectors only support bools, ints and floats, so pointer vectors need to be supported another way.
                // "composite integers" (larger than the largest supported native type) can probably be represented by an array of vectors.

                // TODO: Vectors are not yet supported by the self-hosted compiler itself it seems.
                return self.fail(.{.node_offset = 0}, "TODO: SPIR-V backend: implement type Vector", .{});
            },
            .Null,
            .Undefined,
            .EnumLiteral,
            .ComptimeFloat,
            .ComptimeInt,
            .Type,
            => unreachable, // Must be const or comptime.

            .BoundFn => unreachable, // this type will be deleted from the language.

            else => |tag| return self.fail(.{.node_offset = 0}, "TODO: SPIR-V backend: implement type {}s", .{ tag }),
        }

        try self.types.putNoClobber(ty, result_id);
        return result_id;
    }

    pub fn gen(self: *DeclGen) !void {
        const result_id = self.decl.fn_link.spirv.id;
        const tv = self.decl.typed_value.most_recent.typed_value;

        if (tv.val.castTag(.function)) |func_payload| {
            std.debug.assert(tv.ty.zigTypeTag() == .Fn);
            const prototype_id = try self.getOrGenType(tv.ty);
            try writeInstruction(&self.spv.fn_decls, .OpFunction, &[_]u32{
                self.types.get(tv.ty.fnReturnType()).?, // This type should be generated along with the prototype.
                result_id,
                @bitCast(u32, spec.FunctionControl{}), // TODO: We can set inline here if the type requires it.
                prototype_id,
            });

            const params = tv.ty.fnParamLen();
            var i: usize = 0;

            try self.args.ensureCapacity(params);
            while (i < params) : (i += 1) {
                const param_type_id = self.types.get(tv.ty.fnParamType(i)).?;
                const arg_result_id = self.spv.allocResultId();
                try writeInstruction(&self.spv.fn_decls, .OpFunctionParameter, &[_]u32{ param_type_id, arg_result_id });
                self.args.appendAssumeCapacity(arg_result_id);
            }

            // TODO: This could probably be done in a better way...
            const root_block_id = self.spv.allocResultId();
            _ = try writeInstruction(&self.spv.fn_decls, .OpLabel, &[_]u32{root_block_id});
            try self.genBody(func_payload.data.body);

            try writeInstruction(&self.spv.fn_decls, .OpFunctionEnd, &[_]u32{});
        } else {
            return self.fail(.{.node_offset = 0}, "TODO: SPIR-V backend: generate decl type {}", .{ tv.ty.zigTypeTag() });
        }
    }

    fn genBody(self: *DeclGen, body: ir.Body) !void {
        for (body.instructions) |inst| {
            const maybe_result_id = try self.genInst(inst);
            if (maybe_result_id) |result_id|
                try self.values.putNoClobber(inst, result_id);
        }
    }

    fn genInst(self: *DeclGen, inst: *Inst) !?u32 {
        return switch (inst.tag) {
            .arg => self.genArg(),
            // TODO: Breakpoints won't be supported in SPIR-V, but the compiler seems to insert them
            // throughout the IR.
            .breakpoint => null,
            .dbg_stmt => null,
            .ret => self.genRet(inst.castTag(.ret).?),
            .retvoid => self.genRetVoid(),
            .unreach => self.genUnreach(),
            else => self.fail(.{.node_offset = 0}, "TODO: SPIR-V backend: implement inst {}", .{inst.tag}),
        };
    }

    fn genArg(self: *DeclGen) u32 {
        defer self.next_arg_index += 1;
        return self.args.items[self.next_arg_index];
    }

    fn genRet(self: *DeclGen, inst: *Inst.UnOp) !?u32 {
        const operand_id = try self.resolve(inst.operand);
        // TODO: This instruction needs to be the last in a block. Is that guaranteed?
        try writeInstruction(&self.spv.fn_decls, .OpReturnValue, &[_]u32{ operand_id });
        return null;
    }

    fn genRetVoid(self: *DeclGen) !?u32 {
        // TODO: This instruction needs to be the last in a block. Is that guaranteed?
        try writeInstruction(&self.spv.fn_decls, .OpReturn, &[_]u32{});
        return null;
    }

    fn genUnreach(self: *DeclGen) !?u32 {
        // TODO: This instruction needs to be the last in a block. Is that guaranteed?
        try writeInstruction(&self.spv.fn_decls, .OpUnreachable, &[_]u32{});
        return null;
    }
};
