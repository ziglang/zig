const std = @import("std");
const Allocator = std.mem.Allocator;
const Target = std.Target;
const log = std.log.scoped(.codegen);

const spec = @import("spirv/spec.zig");
const Opcode = spec.Opcode;

const Module = @import("../Module.zig");
const Decl = Module.Decl;
const Type = @import("../type.zig").Type;
const Value = @import("../value.zig").Value;
const LazySrcLoc = Module.LazySrcLoc;
const ir = @import("../ir.zig");
const Inst = ir.Inst;

pub const TypeMap = std.HashMap(Type, u32, Type.hash, Type.eql, std.hash_map.default_max_load_percentage);
pub const ValueMap = std.AutoHashMap(*Inst, u32);

pub fn writeOpcode(code: *std.ArrayList(u32), opcode: Opcode, arg_count: u32) !void {
    const word_count = arg_count + 1;
    try code.append((word_count << 16) | @enumToInt(opcode));
}

pub fn writeInstruction(code: *std.ArrayList(u32), opcode: Opcode, args: []const u32) !void {
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

    const Error = error{ AnalysisFail, OutOfMemory };

    /// This structure is used to return information about a type typically used for arithmetic operations.
    /// These types may either be integers, floats, or a vector of these. Most scalar operations also work on vectors,
    /// so we can easily represent those as arithmetic types.
    /// If the type is a scalar, 'inner type' refers to the scalar type. Otherwise, if its a vector, it refers
    /// to the vector's element type.
    const ArithmeticTypeInfo = struct {
        /// A classification of the inner type.
        const Class = enum {
            /// A boolean.
            bool,

            /// A regular, **native**, integer.
            /// This is only returned when the backend supports this int as a native type (when
            /// the relevant capability is enabled).
            integer,

            /// A regular float. These are all required to be natively supported. Floating points for
            /// which the relevant capability is not enabled are not emulated.
            float,

            /// An integer of a 'strange' size (which' bit size is not the same as its backing type. **Note**: this
            /// may **also** include power-of-2 integers for which the relevant capability is not enabled), but still
            /// within the limits of the largest natively supported integer type.
            strange_integer,

            /// An integer with more bits than the largest natively supported integer type.
            composite_integer,
        };

        /// The number of bits in the inner type.
        /// Note: this is the actual number of bits of the type, not the size of the backing integer.
        bits: u16,

        /// Whether the type is a vector.
        is_vector: bool,

        /// Whether the inner type is signed. Only relevant for integers.
        signedness: std.builtin.Signedness,

        /// A classification of the inner type. These scenarios
        /// will all have to be handled slightly different.
        class: Class,
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
    /// TODO: The extension SPV_INTEL_arbitrary_precision_integers allows any integer size (at least up to 32 bits).
    /// TODO: This probably needs an ABI-version as well (especially in combination with SPV_INTEL_arbitrary_precision_integers).
    /// TODO: Should the result of this function be cached?
    fn backingIntBits(self: *DeclGen, bits: u16) ?u16 {
        const target = self.module.getTarget();

        // TODO: Figure out what to do with u0/i0.
        std.debug.assert(bits != 0);

        // 8, 16 and 64-bit integers require the Int8, Int16 and Inr64 capabilities respectively.
        // 32-bit integers are always supported (see spec, 2.16.1, Data rules).
        const ints = [_]struct { bits: u16, feature: ?Target.spirv.Feature }{
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

            if (bits <= int.bits and has_feature) {
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
    fn largestSupportedIntBits(self: *DeclGen) u16 {
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

    fn arithmeticTypeInfo(self: *DeclGen, ty: Type) !ArithmeticTypeInfo {
        const target = self.module.getTarget();

        return switch (ty.zigTypeTag()) {
            .Bool => ArithmeticTypeInfo{
                .bits = 1, // Doesn't matter for this class.
                .is_vector = false,
                .signedness = .unsigned, // Technically, but doesn't matter for this class.
                .class = .bool,
            },
            .Float => ArithmeticTypeInfo{
                .bits = ty.floatBits(target),
                .is_vector = false,
                .signedness = .signed, // Technically, but doesn't matter for this class.
                .class = .float,
            },
            .Int => blk: {
                const int_info = ty.intInfo(target);
                // TODO: Maybe it's useful to also return this value.
                const maybe_backing_bits = self.backingIntBits(int_info.bits);
                break :blk ArithmeticTypeInfo{ .bits = int_info.bits, .is_vector = false, .signedness = int_info.signedness, .class = if (maybe_backing_bits) |backing_bits|
                    if (backing_bits == int_info.bits)
                        ArithmeticTypeInfo.Class.integer
                    else
                        ArithmeticTypeInfo.Class.strange_integer
                else
                    .composite_integer };
            },
            // As of yet, there is no vector support in the self-hosted compiler.
            .Vector => self.fail(.{ .node_offset = 0 }, "TODO: SPIR-V backend: implement arithmeticTypeInfo for Vector", .{}),
            // TODO: For which types is this the case?
            else => self.fail(.{ .node_offset = 0 }, "TODO: SPIR-V backend: implement arithmeticTypeInfo for {}", .{ty}),
        };
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
                const opcode: Opcode = if (val.toBool()) .OpConstantTrue else .OpConstantFalse;
                try writeInstruction(code, opcode, &[_]u32{ result_type_id, result_id });
            },
            .Float => {
                // At this point we are guaranteed that the target floating point type is supported, otherwise the function
                // would have exited at getOrGenType(ty).

                // f16 and f32 require one word of storage. f64 requires 2, low-order first.

                switch (val.tag()) {
                    .float_16 => try writeInstruction(code, .OpConstant, &[_]u32{ result_type_id, result_id, @bitCast(u16, val.castTag(.float_16).?.data) }),
                    .float_32 => try writeInstruction(code, .OpConstant, &[_]u32{ result_type_id, result_id, @bitCast(u32, val.castTag(.float_32).?.data) }),
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
                    else => return self.fail(.{ .node_offset = 0 }, "TODO: SPIR-V backend: float constant generation of value {s}\n", .{val.tag()}),
                }
            },
            else => return self.fail(.{ .node_offset = 0 }, "TODO: SPIR-V backend: constant generation of type {s}\n", .{ty.zigTypeTag()}),
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
            .Void => try writeInstruction(code, .OpTypeVoid, &[_]u32{result_id}),
            .Bool => try writeInstruction(code, .OpTypeBool, &[_]u32{result_id}),
            .Int => {
                const int_info = ty.intInfo(target);
                const backing_bits = self.backingIntBits(int_info.bits) orelse {
                    // Integers too big for any native type are represented as "composite integers": An array of largestSupportedIntBits.
                    return self.fail(.{ .node_offset = 0 }, "TODO: SPIR-V backend: implement composite ints {}", .{ty});
                };

                // TODO: If backing_bits != int_info.bits, a duplicate type might be generated here.
                try writeInstruction(code, .OpTypeInt, &[_]u32{
                    result_id,
                    backing_bits,
                    switch (int_info.signedness) {
                        .unsigned => 0,
                        .signed => 1,
                    },
                });
            },
            .Float => {
                // We can (and want) not really emulate floating points with other floating point types like with the integer types,
                // so if the float is not supported, just return an error.
                const bits = ty.floatBits(target);
                const supported = switch (bits) {
                    16 => Target.spirv.featureSetHas(target.cpu.features, .Float16),
                    // 32-bit floats are always supported (see spec, 2.16.1, Data rules).
                    32 => true,
                    64 => Target.spirv.featureSetHas(target.cpu.features, .Float64),
                    else => false,
                };

                if (!supported) {
                    return self.fail(.{ .node_offset = 0 }, "Floating point width of {} bits is not supported for the current SPIR-V feature set", .{bits});
                }

                try writeInstruction(code, .OpTypeFloat, &[_]u32{ result_id, bits });
            },
            .Fn => {
                // We only support zig-calling-convention functions, no varargs.
                if (ty.fnCallingConvention() != .Unspecified)
                    return self.fail(.{ .node_offset = 0 }, "Unsupported calling convention for SPIR-V", .{});
                if (ty.fnIsVarArgs())
                    return self.fail(.{ .node_offset = 0 }, "VarArgs unsupported for SPIR-V", .{});

                // In order to avoid a temporary here, first generate all the required types and then simply look them up
                // when generating the function type.
                const params = ty.fnParamLen();
                var i: usize = 0;
                while (i < params) : (i += 1) {
                    _ = try self.getOrGenType(ty.fnParamType(i));
                }

                const return_type_id = try self.getOrGenType(ty.fnReturnType());

                // result id + result type id + parameter type ids.
                try writeOpcode(code, .OpTypeFunction, 2 + @intCast(u32, ty.fnParamLen()));
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
                // TODO: The SPIR-V spec mentions that vector sizes may be quite restricted! look into which we can use, and whether OpTypeVector
                // is adequate at all for this.

                // TODO: Vectors are not yet supported by the self-hosted compiler itself it seems.
                return self.fail(.{ .node_offset = 0 }, "TODO: SPIR-V backend: implement type Vector", .{});
            },
            .Null,
            .Undefined,
            .EnumLiteral,
            .ComptimeFloat,
            .ComptimeInt,
            .Type,
            => unreachable, // Must be const or comptime.

            .BoundFn => unreachable, // this type will be deleted from the language.

            else => |tag| return self.fail(.{ .node_offset = 0 }, "TODO: SPIR-V backend: implement type {}s", .{tag}),
        }

        try self.types.putNoClobber(ty, result_id);
        return result_id;
    }

    pub fn gen(self: *DeclGen) !void {
        const decl = self.decl;
        const result_id = decl.fn_link.spirv.id;

        if (decl.val.castTag(.function)) |func_payload| {
            std.debug.assert(decl.ty.zigTypeTag() == .Fn);
            const prototype_id = try self.getOrGenType(decl.ty);
            try writeInstruction(&self.spv.fn_decls, .OpFunction, &[_]u32{
                self.types.get(decl.ty.fnReturnType()).?, // This type should be generated along with the prototype.
                result_id,
                @bitCast(u32, spec.FunctionControl{}), // TODO: We can set inline here if the type requires it.
                prototype_id,
            });

            const params = decl.ty.fnParamLen();
            var i: usize = 0;

            try self.args.ensureCapacity(params);
            while (i < params) : (i += 1) {
                const param_type_id = self.types.get(decl.ty.fnParamType(i)).?;
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
            return self.fail(.{ .node_offset = 0 }, "TODO: SPIR-V backend: generate decl type {}", .{decl.ty.zigTypeTag()});
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
            .add, .addwrap => try self.genBinOp(inst.castTag(.add).?),
            .sub, .subwrap => try self.genBinOp(inst.castTag(.sub).?),
            .mul, .mulwrap => try self.genBinOp(inst.castTag(.mul).?),
            .div => try self.genBinOp(inst.castTag(.div).?),
            .bit_and => try self.genBinOp(inst.castTag(.bit_and).?),
            .bit_or => try self.genBinOp(inst.castTag(.bit_or).?),
            .xor => try self.genBinOp(inst.castTag(.xor).?),
            .cmp_eq => try self.genBinOp(inst.castTag(.cmp_eq).?),
            .cmp_neq => try self.genBinOp(inst.castTag(.cmp_neq).?),
            .cmp_gt => try self.genBinOp(inst.castTag(.cmp_gt).?),
            .cmp_gte => try self.genBinOp(inst.castTag(.cmp_gte).?),
            .cmp_lt => try self.genBinOp(inst.castTag(.cmp_lt).?),
            .cmp_lte => try self.genBinOp(inst.castTag(.cmp_lte).?),
            .bool_and => try self.genBinOp(inst.castTag(.bool_and).?),
            .bool_or => try self.genBinOp(inst.castTag(.bool_or).?),
            .not => try self.genUnOp(inst.castTag(.not).?),
            .arg => self.genArg(),
            // TODO: Breakpoints won't be supported in SPIR-V, but the compiler seems to insert them
            // throughout the IR.
            .breakpoint => null,
            .dbg_stmt => null,
            .ret => self.genRet(inst.castTag(.ret).?),
            .retvoid => self.genRetVoid(),
            .unreach => self.genUnreach(),
            else => self.fail(.{ .node_offset = 0 }, "TODO: SPIR-V backend: implement inst {}", .{inst.tag}),
        };
    }

    fn genBinOp(self: *DeclGen, inst: *Inst.BinOp) !u32 {
        // TODO: Will lhs and rhs have the same type?
        const lhs_id = try self.resolve(inst.lhs);
        const rhs_id = try self.resolve(inst.rhs);

        const result_id = self.spv.allocResultId();
        const result_type_id = try self.getOrGenType(inst.base.ty);

        // TODO: Is the result the same as the argument types?
        // This is supposed to be the case for SPIR-V.
        std.debug.assert(inst.rhs.ty.eql(inst.lhs.ty));
        std.debug.assert(inst.base.ty.tag() == .bool or inst.base.ty.eql(inst.lhs.ty));

        // Binary operations are generally applicable to both scalar and vector operations in SPIR-V, but int and float
        // versions of operations require different opcodes.
        // For operations which produce bools, the information of inst.base.ty is not useful, so just pick either operand
        // instead.
        const info = try self.arithmeticTypeInfo(inst.lhs.ty);

        if (info.class == .composite_integer)
            return self.fail(.{ .node_offset = 0 }, "TODO: SPIR-V backend: binary operations for composite integers", .{});

        const is_bool = info.class == .bool;
        const is_float = info.class == .float;
        const is_signed = info.signedness == .signed;
        // **Note**: All these operations must be valid for vectors of floats, integers and bools as well!
        // For floating points, we generally want ordered operations (which return false if either operand is nan).
        const opcode = switch (inst.base.tag) {
            // The regular integer operations are all defined for wrapping. Since theyre only relevant for integers,
            // we can just switch on both cases here.
            .add, .addwrap => if (is_float) Opcode.OpFAdd else Opcode.OpIAdd,
            .sub, .subwrap => if (is_float) Opcode.OpFSub else Opcode.OpISub,
            .mul, .mulwrap => if (is_float) Opcode.OpFMul else Opcode.OpIMul,
            // TODO: Trap if divisor is 0?
            // TODO: Figure out of OpSDiv for unsigned/OpUDiv for signed does anything useful.
            //  => Those are probably for divTrunc and divFloor, though the compiler does not yet generate those.
            //  => TODO: Figure out how those work on the SPIR-V side.
            //  => TODO: Test these.
            .div => if (is_float) Opcode.OpFDiv else if (is_signed) Opcode.OpSDiv else Opcode.OpUDiv,
            // Only integer versions for these.
            .bit_and => Opcode.OpBitwiseAnd,
            .bit_or => Opcode.OpBitwiseOr,
            .xor => Opcode.OpBitwiseXor,
            // Int/bool/float -> bool operations.
            .cmp_eq => if (is_float) Opcode.OpFOrdEqual else if (is_bool) Opcode.OpLogicalEqual else Opcode.OpIEqual,
            .cmp_neq => if (is_float) Opcode.OpFOrdNotEqual else if (is_bool) Opcode.OpLogicalNotEqual else Opcode.OpINotEqual,
            // Int/float -> bool operations.
            // TODO: Verify that these OpFOrd type operations produce the right value.
            // TODO: Is there a more fundamental difference between OpU and OpS operations here than just the type?
            .cmp_gt => if (is_float) Opcode.OpFOrdGreaterThan else if (is_signed) Opcode.OpSGreaterThan else Opcode.OpUGreaterThan,
            .cmp_gte => if (is_float) Opcode.OpFOrdGreaterThanEqual else if (is_signed) Opcode.OpSGreaterThanEqual else Opcode.OpUGreaterThanEqual,
            .cmp_lt => if (is_float) Opcode.OpFOrdLessThan else if (is_signed) Opcode.OpSLessThan else Opcode.OpULessThan,
            .cmp_lte => if (is_float) Opcode.OpFOrdLessThanEqual else if (is_signed) Opcode.OpSLessThanEqual else Opcode.OpULessThanEqual,
            // Bool -> bool operations.
            .bool_and => Opcode.OpLogicalAnd,
            .bool_or => Opcode.OpLogicalOr,
            else => unreachable,
        };

        try writeInstruction(&self.spv.fn_decls, opcode, &[_]u32{ result_type_id, result_id, lhs_id, rhs_id });

        // TODO: Trap on overflow? Probably going to be annoying.
        // TODO: Look into SPV_KHR_no_integer_wrap_decoration which provides NoSignedWrap/NoUnsignedWrap.

        if (info.class != .strange_integer)
            return result_id;

        return self.fail(.{ .node_offset = 0 }, "TODO: SPIR-V backend: strange integer operation mask", .{});
    }

    fn genUnOp(self: *DeclGen, inst: *Inst.UnOp) !u32 {
        const operand_id = try self.resolve(inst.operand);

        const result_id = self.spv.allocResultId();
        const result_type_id = try self.getOrGenType(inst.base.ty);

        const info = try self.arithmeticTypeInfo(inst.operand.ty);

        const opcode = switch (inst.base.tag) {
            // Bool -> bool
            .not => Opcode.OpLogicalNot,
            else => unreachable,
        };

        try writeInstruction(&self.spv.fn_decls, opcode, &[_]u32{ result_type_id, result_id, operand_id });

        return result_id;
    }

    fn genArg(self: *DeclGen) u32 {
        defer self.next_arg_index += 1;
        return self.args.items[self.next_arg_index];
    }

    fn genRet(self: *DeclGen, inst: *Inst.UnOp) !?u32 {
        const operand_id = try self.resolve(inst.operand);
        // TODO: This instruction needs to be the last in a block. Is that guaranteed?
        try writeInstruction(&self.spv.fn_decls, .OpReturnValue, &[_]u32{operand_id});
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
