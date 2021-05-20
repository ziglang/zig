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

pub const Word = u32;
pub const ResultId = u32;

pub const TypeMap = std.HashMap(Type, ResultId, Type.hash, Type.eql, std.hash_map.default_max_load_percentage);
pub const InstMap = std.AutoHashMap(*Inst, ResultId);

const IncomingBlock = struct {
    src_label_id: ResultId,
    break_value_id: ResultId,
};

pub const BlockMap = std.AutoHashMap(*Inst.Block, struct {
    label_id: ResultId,
    incoming_blocks: *std.ArrayListUnmanaged(IncomingBlock),
});

pub fn writeOpcode(code: *std.ArrayList(Word), opcode: Opcode, arg_count: u16) !void {
    const word_count: Word = arg_count + 1;
    try code.append((word_count << 16) | @enumToInt(opcode));
}

pub fn writeInstruction(code: *std.ArrayList(Word), opcode: Opcode, args: []const Word) !void {
    try writeOpcode(code, opcode, @intCast(u16, args.len));
    try code.appendSlice(args);
}

/// This structure represents a SPIR-V (binary) module being compiled, and keeps track of all relevant information.
/// That includes the actual instructions, the current result-id bound, and data structures for querying result-id's
/// of data which needs to be persistent over different calls to Decl code generation.
pub const SPIRVModule = struct {
    next_result_id: ResultId,

    binary: struct {
        types_globals_constants: std.ArrayList(Word),
        fn_decls: std.ArrayList(Word),
    },

    types: TypeMap,

    pub fn init(gpa: *Allocator) SPIRVModule {
        return .{
            .next_result_id = 1, // 0 is an invalid SPIR-V result ID.
            .binary = .{
                .types_globals_constants = std.ArrayList(Word).init(gpa),
                .fn_decls = std.ArrayList(Word).init(gpa),
            },
            .types = TypeMap.init(gpa),
        };
    }

    pub fn deinit(self: *SPIRVModule) void {
        self.binary.types_globals_constants.deinit();
        self.binary.fn_decls.deinit();
        self.types.deinit();
    }

    pub fn allocResultId(self: *SPIRVModule) Word {
        defer self.next_result_id += 1;
        return self.next_result_id;
    }

    pub fn resultIdBound(self: *SPIRVModule) Word {
        return self.next_result_id;
    }
};

/// This structure is used to compile a declaration, and contains all relevant meta-information to deal with that.
pub const DeclGen = struct {
    /// The parent module.
    module: *Module,

    /// The SPIR-V module  code should be put in.
    spv: *SPIRVModule,

    /// An array of function argument result-ids. Each index corresponds with the function argument of the same index.
    args: std.ArrayList(ResultId),

    /// A counter to keep track of how many `arg` instructions we've seen yet.
    next_arg_index: u32,

    /// A map keeping track of which instruction generated which result-id.
    inst_results: InstMap,

    /// We need to keep track of result ids for block labels, as well as the 'incoming' blocks for a block.
    blocks: BlockMap,

    /// The label of the SPIR-V block we are currently generating.
    current_block_label_id: ResultId,

    /// The decl we are currently generating code for.
    decl: *Decl,

    /// If `gen` returned `Error.AnalysisFail`, this contains an explanatory message. Memory is owned by
    /// `module.gpa`.
    error_msg: ?*Module.ErrorMsg,

    /// Possible errors the `gen` function may return.
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

    /// Initialize the common resources of a DeclGen. Some fields are left uninitialized, only set when `gen` is called.
    pub fn init(gpa: *Allocator, module: *Module, spv: *SPIRVModule) DeclGen {
        return .{
            .module = module,
            .spv = spv,
            .args = std.ArrayList(ResultId).init(gpa),
            .next_arg_index = undefined,
            .inst_results = InstMap.init(gpa),
            .blocks = BlockMap.init(gpa),
            .current_block_label_id = undefined,
            .decl = undefined,
            .error_msg = undefined,
        };
    }

    /// Generate the code for `decl`. If a reportable error occured during code generation,
    /// a message is returned by this function. Callee owns the memory. If this function returns such
    /// a reportable error, it is valid to be called again for a different decl.
    pub fn gen(self: *DeclGen, decl: *Decl) !?*Module.ErrorMsg {
        // Reset internal resources, we don't want to re-allocate these.
        self.args.items.len = 0;
        self.next_arg_index = 0;
        self.inst_results.clearRetainingCapacity();
        self.blocks.clearRetainingCapacity();
        self.current_block_label_id = undefined;
        self.decl = decl;
        self.error_msg = null;

        try self.genDecl();
        return self.error_msg;
    }

    /// Free resources owned by the DeclGen.
    pub fn deinit(self: *DeclGen) void {
        self.args.deinit();
        self.inst_results.deinit();
        self.blocks.deinit();
    }

    fn fail(self: *DeclGen, src: LazySrcLoc, comptime format: []const u8, args: anytype) Error {
        @setCold(true);
        const src_loc = src.toSrcLocWithDecl(self.decl);
        self.error_msg = try Module.ErrorMsg.create(self.module.gpa, src_loc, format, args);
        return error.AnalysisFail;
    }

    fn resolve(self: *DeclGen, inst: *Inst) !ResultId {
        if (inst.value()) |val| {
            return self.genConstant(inst.src, inst.ty, val);
        }

        return self.inst_results.get(inst).?; // Instruction does not dominate all uses!
    }

    fn beginSPIRVBlock(self: *DeclGen, label_id: ResultId) !void {
        try writeInstruction(&self.spv.binary.fn_decls, .OpLabel, &[_]Word{label_id});
        self.current_block_label_id = label_id;
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

        // The backend will never be asked to compiler a 0-bit integer, so we won't have to handle those in this function.
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
    fn genConstant(self: *DeclGen, src: LazySrcLoc, ty: Type, val: Value) Error!ResultId {
        const target = self.module.getTarget();
        const code = &self.spv.binary.types_globals_constants;
        const result_id = self.spv.allocResultId();
        const result_type_id = try self.genType(src, ty);

        if (val.isUndef()) {
            try writeInstruction(code, .OpUndef, &[_]Word{ result_type_id, result_id });
            return result_id;
        }

        switch (ty.zigTypeTag()) {
            .Int => {
                const int_info = ty.intInfo(target);
                const backing_bits = self.backingIntBits(int_info.bits) orelse {
                    // Integers too big for any native type are represented as "composite integers": An array of largestSupportedIntBits.
                    return self.fail(src, "TODO: SPIR-V backend: implement composite int constants for {}", .{ty});
                };

                // We can just use toSignedInt/toUnsignedInt here as it returns u64 - a type large enough to hold any
                // SPIR-V native type (up to i/u64 with Int64). If SPIR-V ever supports native ints of a larger size, this
                // might need to be updated.
                std.debug.assert(self.largestSupportedIntBits() <= std.meta.bitCount(u64));
                var int_bits = if (ty.isSignedInt()) @bitCast(u64, val.toSignedInt()) else val.toUnsignedInt();

                // Mask the low bits which make up the actual integer. This is to make sure that negative values
                // only use the actual bits of the type.
                // TODO: Should this be the backing type bits or the actual type bits?
                int_bits &= (@as(u64, 1) << @intCast(u6, backing_bits)) - 1;

                switch (backing_bits) {
                    0 => unreachable,
                    1...32 => try writeInstruction(code, .OpConstant, &[_]Word{
                        result_type_id,
                        result_id,
                        @truncate(u32, int_bits),
                    }),
                    33...64 => try writeInstruction(code, .OpConstant, &[_]Word{
                        result_type_id,
                        result_id,
                        @truncate(u32, int_bits),
                        @truncate(u32, int_bits >> @bitSizeOf(u32)),
                    }),
                    else => unreachable, // backing_bits is bounded by largestSupportedIntBits.
                }
            },
            .Bool => {
                const opcode: Opcode = if (val.toBool()) .OpConstantTrue else .OpConstantFalse;
                try writeInstruction(code, opcode, &[_]Word{ result_type_id, result_id });
            },
            .Float => {
                // At this point we are guaranteed that the target floating point type is supported, otherwise the function
                // would have exited at genType(ty).

                // f16 and f32 require one word of storage. f64 requires 2, low-order first.

                switch (ty.floatBits(target)) {
                    16 => try writeInstruction(code, .OpConstant, &[_]Word{ result_type_id, result_id, @bitCast(u16, val.toFloat(f16)) }),
                    32 => try writeInstruction(code, .OpConstant, &[_]Word{ result_type_id, result_id, @bitCast(u32, val.toFloat(f32)) }),
                    64 => {
                        const float_bits = @bitCast(u64, val.toFloat(f64));
                        try writeInstruction(code, .OpConstant, &[_]Word{
                            result_type_id,
                            result_id,
                            @truncate(u32, float_bits),
                            @truncate(u32, float_bits >> @bitSizeOf(u32)),
                        });
                    },
                    128 => unreachable, // Filtered out in the call to genType.
                    // TODO: Insert case for long double when the layout for that is determined.
                    else => unreachable,
                }
            },
            .Void => unreachable,
            else => return self.fail(src, "TODO: SPIR-V backend: constant generation of type {}", .{ty}),
        }

        return result_id;
    }

    fn genType(self: *DeclGen, src: LazySrcLoc, ty: Type) Error!ResultId {
        // We can't use getOrPut here so we can recursively generate types.
        if (self.spv.types.get(ty)) |already_generated| {
            return already_generated;
        }

        const target = self.module.getTarget();
        const code = &self.spv.binary.types_globals_constants;
        const result_id = self.spv.allocResultId();

        switch (ty.zigTypeTag()) {
            .Void => try writeInstruction(code, .OpTypeVoid, &[_]Word{result_id}),
            .Bool => try writeInstruction(code, .OpTypeBool, &[_]Word{result_id}),
            .Int => {
                const int_info = ty.intInfo(target);
                const backing_bits = self.backingIntBits(int_info.bits) orelse {
                    // Integers too big for any native type are represented as "composite integers": An array of largestSupportedIntBits.
                    return self.fail(src, "TODO: SPIR-V backend: implement composite int {}", .{ty});
                };

                // TODO: If backing_bits != int_info.bits, a duplicate type might be generated here.
                try writeInstruction(code, .OpTypeInt, &[_]Word{
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
                    return self.fail(src, "Floating point width of {} bits is not supported for the current SPIR-V feature set", .{bits});
                }

                try writeInstruction(code, .OpTypeFloat, &[_]Word{ result_id, bits });
            },
            .Fn => {
                // We only support zig-calling-convention functions, no varargs.
                if (ty.fnCallingConvention() != .Unspecified)
                    return self.fail(src, "Unsupported calling convention for SPIR-V", .{});
                if (ty.fnIsVarArgs())
                    return self.fail(src, "VarArgs unsupported for SPIR-V", .{});

                // In order to avoid a temporary here, first generate all the required types and then simply look them up
                // when generating the function type.
                const params = ty.fnParamLen();
                var i: usize = 0;
                while (i < params) : (i += 1) {
                    _ = try self.genType(src, ty.fnParamType(i));
                }

                const return_type_id = try self.genType(src, ty.fnReturnType());

                // result id + result type id + parameter type ids.
                try writeOpcode(code, .OpTypeFunction, 2 + @intCast(u16, ty.fnParamLen()));
                try code.appendSlice(&.{ result_id, return_type_id });

                i = 0;
                while (i < params) : (i += 1) {
                    const param_type_id = self.spv.types.get(ty.fnParamType(i)).?;
                    try code.append(param_type_id);
                }
            },
            // When recursively generating a type, we cannot infer the pointer's storage class. See genPointerType.
            .Pointer => return self.fail(src, "Cannot create pointer with unkown storage class", .{}),
            .Vector => {
                // Although not 100% the same, Zig vectors map quite neatly to SPIR-V vectors (including many integer and float operations
                // which work on them), so simply use those.
                // Note: SPIR-V vectors only support bools, ints and floats, so pointer vectors need to be supported another way.
                // "composite integers" (larger than the largest supported native type) can probably be represented by an array of vectors.
                // TODO: The SPIR-V spec mentions that vector sizes may be quite restricted! look into which we can use, and whether OpTypeVector
                // is adequate at all for this.

                // TODO: Vectors are not yet supported by the self-hosted compiler itself it seems.
                return self.fail(src, "TODO: SPIR-V backend: implement type Vector", .{});
            },
            .Null,
            .Undefined,
            .EnumLiteral,
            .ComptimeFloat,
            .ComptimeInt,
            .Type,
            => unreachable, // Must be const or comptime.

            .BoundFn => unreachable, // this type will be deleted from the language.

            else => |tag| return self.fail(src, "TODO: SPIR-V backend: implement type {}s", .{tag}),
        }

        try self.spv.types.putNoClobber(ty, result_id);
        return result_id;
    }

    /// SPIR-V requires pointers to have a storage class (address space), and so we have a special function for that.
    /// TODO: The result of this needs to be cached.
    fn genPointerType(self: *DeclGen, src: LazySrcLoc, ty: Type, storage_class: spec.StorageClass) !ResultId {
        std.debug.assert(ty.zigTypeTag() == .Pointer);

        const code = &self.spv.binary.types_globals_constants;
        const result_id = self.spv.allocResultId();

        // TODO: There are many constraints which are ignored for now: We may only create pointers to certain types, and to other types
        // if more capabilities are enabled. For example, we may only create pointers to f16 if Float16Buffer is enabled.
        // These also relates to the pointer's address space.
        const child_id = try self.genType(src, ty.elemType());

        try writeInstruction(code, .OpTypePointer, &[_]Word{ result_id, @enumToInt(storage_class), child_id });

        return result_id;
    }

    fn genDecl(self: *DeclGen) !void {
        const decl = self.decl;
        const result_id = decl.fn_link.spirv.id;

        if (decl.val.castTag(.function)) |func_payload| {
            std.debug.assert(decl.ty.zigTypeTag() == .Fn);
            const prototype_id = try self.genType(.{ .node_offset = 0 }, decl.ty);
            try writeInstruction(&self.spv.binary.fn_decls, .OpFunction, &[_]Word{
                self.spv.types.get(decl.ty.fnReturnType()).?, // This type should be generated along with the prototype.
                result_id,
                @bitCast(Word, spec.FunctionControl{}), // TODO: We can set inline here if the type requires it.
                prototype_id,
            });

            const params = decl.ty.fnParamLen();
            var i: usize = 0;

            try self.args.ensureCapacity(params);
            while (i < params) : (i += 1) {
                const param_type_id = self.spv.types.get(decl.ty.fnParamType(i)).?;
                const arg_result_id = self.spv.allocResultId();
                try writeInstruction(&self.spv.binary.fn_decls, .OpFunctionParameter, &[_]Word{ param_type_id, arg_result_id });
                self.args.appendAssumeCapacity(arg_result_id);
            }

            // TODO: This could probably be done in a better way...
            const root_block_id = self.spv.allocResultId();
            try self.beginSPIRVBlock(root_block_id);
            try self.genBody(func_payload.data.body);

            try writeInstruction(&self.spv.binary.fn_decls, .OpFunctionEnd, &[_]Word{});
        } else {
            return self.fail(.{ .node_offset = 0 }, "TODO: SPIR-V backend: generate decl type {}", .{decl.ty.zigTypeTag()});
        }
    }

    fn genBody(self: *DeclGen, body: ir.Body) Error!void {
        for (body.instructions) |inst| {
            const maybe_result_id = try self.genInst(inst);
            if (maybe_result_id) |result_id|
                try self.inst_results.putNoClobber(inst, result_id);
        }
    }

    fn genInst(self: *DeclGen, inst: *Inst) !?ResultId {
        return switch (inst.tag) {
            .add, .addwrap => try self.genBinOp(inst.castTag(.add).?),
            .sub, .subwrap => try self.genBinOp(inst.castTag(.sub).?),
            .mul, .mulwrap => try self.genBinOp(inst.castTag(.mul).?),
            .div => try self.genBinOp(inst.castTag(.div).?),
            .bit_and => try self.genBinOp(inst.castTag(.bit_and).?),
            .bit_or => try self.genBinOp(inst.castTag(.bit_or).?),
            .xor => try self.genBinOp(inst.castTag(.xor).?),
            .cmp_eq => try self.genCmp(inst.castTag(.cmp_eq).?),
            .cmp_neq => try self.genCmp(inst.castTag(.cmp_neq).?),
            .cmp_gt => try self.genCmp(inst.castTag(.cmp_gt).?),
            .cmp_gte => try self.genCmp(inst.castTag(.cmp_gte).?),
            .cmp_lt => try self.genCmp(inst.castTag(.cmp_lt).?),
            .cmp_lte => try self.genCmp(inst.castTag(.cmp_lte).?),
            .bool_and => try self.genBinOp(inst.castTag(.bool_and).?),
            .bool_or => try self.genBinOp(inst.castTag(.bool_or).?),
            .not => try self.genUnOp(inst.castTag(.not).?),
            .alloc => try self.genAlloc(inst.castTag(.alloc).?),
            .arg => self.genArg(),
            .block => try self.genBlock(inst.castTag(.block).?),
            .br => try self.genBr(inst.castTag(.br).?),
            .br_void => try self.genBrVoid(inst.castTag(.br_void).?),
            // TODO: Breakpoints won't be supported in SPIR-V, but the compiler seems to insert them
            // throughout the IR.
            .breakpoint => null,
            .condbr => try self.genCondBr(inst.castTag(.condbr).?),
            .constant => unreachable,
            .dbg_stmt => null,
            .load => try self.genLoad(inst.castTag(.load).?),
            .loop => try self.genLoop(inst.castTag(.loop).?),
            .ret => try self.genRet(inst.castTag(.ret).?),
            .retvoid => try self.genRetVoid(),
            .store => try self.genStore(inst.castTag(.store).?),
            .unreach => try self.genUnreach(),
            else => self.fail(inst.src, "TODO: SPIR-V backend: implement inst {s}", .{@tagName(inst.tag)}),
        };
    }

    fn genBinOp(self: *DeclGen, inst: *Inst.BinOp) !ResultId {
        // TODO: Will lhs and rhs have the same type?
        const lhs_id = try self.resolve(inst.lhs);
        const rhs_id = try self.resolve(inst.rhs);

        const result_id = self.spv.allocResultId();
        const result_type_id = try self.genType(inst.base.src, inst.base.ty);

        // TODO: Is the result the same as the argument types?
        // This is supposed to be the case for SPIR-V.
        std.debug.assert(inst.rhs.ty.eql(inst.lhs.ty));
        std.debug.assert(inst.base.ty.tag() == .bool or inst.base.ty.eql(inst.lhs.ty));

        // Binary operations are generally applicable to both scalar and vector operations in SPIR-V, but int and float
        // versions of operations require different opcodes.
        // For operations which produce bools, the information of inst.base.ty is not useful, so just pick either operand
        // instead.
        const info = try self.arithmeticTypeInfo(inst.lhs.ty);

        if (info.class == .composite_integer) {
            return self.fail(inst.base.src, "TODO: SPIR-V backend: binary operations for composite integers", .{});
        } else if (info.class == .strange_integer) {
            return self.fail(inst.base.src, "TODO: SPIR-V backend: binary operations for strange integers", .{});
        }

        const is_bool = info.class == .bool;
        const is_float = info.class == .float;
        const is_signed = info.signedness == .signed;
        // **Note**: All these operations must be valid for vectors as well!
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
            // Bool -> bool operations.
            .bool_and => Opcode.OpLogicalAnd,
            .bool_or => Opcode.OpLogicalOr,
            else => unreachable,
        };

        try writeInstruction(&self.spv.binary.fn_decls, opcode, &[_]Word{ result_type_id, result_id, lhs_id, rhs_id });

        // TODO: Trap on overflow? Probably going to be annoying.
        // TODO: Look into SPV_KHR_no_integer_wrap_decoration which provides NoSignedWrap/NoUnsignedWrap.

        if (info.class != .strange_integer)
            return result_id;

        return self.fail(inst.base.src, "TODO: SPIR-V backend: strange integer operation mask", .{});
    }

    fn genCmp(self: *DeclGen, inst: *Inst.BinOp) !ResultId {
        const lhs_id = try self.resolve(inst.lhs);
        const rhs_id = try self.resolve(inst.rhs);

        const result_id = self.spv.allocResultId();
        const result_type_id = try self.genType(inst.base.src, inst.base.ty);

        // All of these operations should be 2 equal types -> bool
        std.debug.assert(inst.rhs.ty.eql(inst.lhs.ty));
        std.debug.assert(inst.base.ty.tag() == .bool);

        // Comparisons are generally applicable to both scalar and vector operations in SPIR-V, but int and float
        // versions of operations require different opcodes.
        // Since inst.base.ty is always bool and so not very useful, and because both arguments must be the same, just get the info
        // from either of the operands.
        const info = try self.arithmeticTypeInfo(inst.lhs.ty);

        if (info.class == .composite_integer) {
            return self.fail(inst.base.src, "TODO: SPIR-V backend: binary operations for composite integers", .{});
        } else if (info.class == .strange_integer) {
            return self.fail(inst.base.src, "TODO: SPIR-V backend: comparison for strange integers", .{});
        }

        const is_bool = info.class == .bool;
        const is_float = info.class == .float;
        const is_signed = info.signedness == .signed;

        // **Note**: All these operations must be valid for vectors as well!
        // For floating points, we generally want ordered operations (which return false if either operand is nan).
        const opcode = switch (inst.base.tag) {
            .cmp_eq => if (is_float) Opcode.OpFOrdEqual else if (is_bool) Opcode.OpLogicalEqual else Opcode.OpIEqual,
            .cmp_neq => if (is_float) Opcode.OpFOrdNotEqual else if (is_bool) Opcode.OpLogicalNotEqual else Opcode.OpINotEqual,
            // TODO: Verify that these OpFOrd type operations produce the right value.
            // TODO: Is there a more fundamental difference between OpU and OpS operations here than just the type?
            .cmp_gt => if (is_float) Opcode.OpFOrdGreaterThan else if (is_signed) Opcode.OpSGreaterThan else Opcode.OpUGreaterThan,
            .cmp_gte => if (is_float) Opcode.OpFOrdGreaterThanEqual else if (is_signed) Opcode.OpSGreaterThanEqual else Opcode.OpUGreaterThanEqual,
            .cmp_lt => if (is_float) Opcode.OpFOrdLessThan else if (is_signed) Opcode.OpSLessThan else Opcode.OpULessThan,
            .cmp_lte => if (is_float) Opcode.OpFOrdLessThanEqual else if (is_signed) Opcode.OpSLessThanEqual else Opcode.OpULessThanEqual,
            else => unreachable,
        };

        try writeInstruction(&self.spv.binary.fn_decls, opcode, &[_]Word{ result_type_id, result_id, lhs_id, rhs_id });
        return result_id;
    }

    fn genUnOp(self: *DeclGen, inst: *Inst.UnOp) !ResultId {
        const operand_id = try self.resolve(inst.operand);

        const result_id = self.spv.allocResultId();
        const result_type_id = try self.genType(inst.base.src, inst.base.ty);

        const info = try self.arithmeticTypeInfo(inst.operand.ty);

        const opcode = switch (inst.base.tag) {
            // Bool -> bool
            .not => Opcode.OpLogicalNot,
            else => unreachable,
        };

        try writeInstruction(&self.spv.binary.fn_decls, opcode, &[_]Word{ result_type_id, result_id, operand_id });

        return result_id;
    }

    fn genAlloc(self: *DeclGen, inst: *Inst.NoOp) !ResultId {
        const storage_class = spec.StorageClass.Function;
        const result_type_id = try self.genPointerType(inst.base.src, inst.base.ty, storage_class);
        const result_id = self.spv.allocResultId();

        try writeInstruction(&self.spv.binary.fn_decls, .OpVariable, &[_]Word{ result_type_id, result_id, @enumToInt(storage_class) });

        return result_id;
    }

    fn genArg(self: *DeclGen) ResultId {
        defer self.next_arg_index += 1;
        return self.args.items[self.next_arg_index];
    }

    fn genBlock(self: *DeclGen, inst: *Inst.Block) !?ResultId {
        // In IR, a block doesn't really define an entry point like a block, but more like a scope that breaks can jump out of and
        // "return" a value from. This cannot be directly modelled in SPIR-V, so in a block instruction, we're going to split up
        // the current block by first generating the code of the block, then a label, and then generate the rest of the current
        // ir.Block in a different SPIR-V block.

        const label_id = self.spv.allocResultId();

        // 4 chosen as arbitrary initial capacity.
        var incoming_blocks = try std.ArrayListUnmanaged(IncomingBlock).initCapacity(self.module.gpa, 4);

        try self.blocks.putNoClobber(inst, .{
            .label_id = label_id,
            .incoming_blocks = &incoming_blocks,
        });
        defer {
            self.blocks.removeAssertDiscard(inst);
            incoming_blocks.deinit(self.module.gpa);
        }

        try self.genBody(inst.body);
        try self.beginSPIRVBlock(label_id);

        // If this block didn't produce a value, simply return here.
        if (!inst.base.ty.hasCodeGenBits())
            return null;

        // Combine the result from the blocks using the Phi instruction.

        const result_id = self.spv.allocResultId();

        // TODO: OpPhi is limited in the types that it may produce, such as pointers. Figure out which other types
        // are not allowed to be created from a phi node, and throw an error for those. For now, genType already throws
        // an error for pointers.
        const result_type_id = try self.genType(inst.base.src, inst.base.ty);

        try writeOpcode(&self.spv.binary.fn_decls, .OpPhi, 2 + @intCast(u16, incoming_blocks.items.len * 2)); // result type + result + variable/parent...

        for (incoming_blocks.items) |incoming| {
            try self.spv.binary.fn_decls.appendSlice(&[_]Word{ incoming.break_value_id, incoming.src_label_id });
        }

        return result_id;
    }

    fn genBr(self: *DeclGen, inst: *Inst.Br) !?ResultId {
        // TODO: This instruction needs to be the last in a block. Is that guaranteed?
        const target = self.blocks.get(inst.block).?;

        // TODO: For some reason, br is emitted with void parameters.
        if (inst.operand.ty.hasCodeGenBits()) {
            const operand_id = try self.resolve(inst.operand);
            // current_block_label_id should not be undefined here, lest there is a br or br_void in the function's body.
            try target.incoming_blocks.append(self.module.gpa, .{
                .src_label_id = self.current_block_label_id,
                .break_value_id = operand_id
            });
        }

        try writeInstruction(&self.spv.binary.fn_decls, .OpBranch, &[_]Word{target.label_id});

        return null;
    }

    fn genBrVoid(self: *DeclGen, inst: *Inst.BrVoid) !?ResultId {
        // TODO: This instruction needs to be the last in a block. Is that guaranteed?
        const target = self.blocks.get(inst.block).?;
        // Don't need to add this to the incoming block list, as there is no value to insert in the phi node anyway.
        try writeInstruction(&self.spv.binary.fn_decls, .OpBranch, &[_]Word{target.label_id});
        return null;
    }

    fn genCondBr(self: *DeclGen, inst: *Inst.CondBr) !?ResultId {
        // TODO: This instruction needs to be the last in a block. Is that guaranteed?
        const condition_id = try self.resolve(inst.condition);

        // These will always generate a new SPIR-V block, since they are ir.Body and not ir.Block.
        const then_label_id = self.spv.allocResultId();
        const else_label_id = self.spv.allocResultId();

        // TODO: We can generate OpSelectionMerge here if we know the target block that both of these will resolve to,
        // but i don't know if those will always resolve to the same block.

        try writeInstruction(&self.spv.binary.fn_decls, .OpBranchConditional, &[_]Word{
            condition_id,
            then_label_id,
            else_label_id,
        });

        try self.beginSPIRVBlock(then_label_id);
        try self.genBody(inst.then_body);
        try self.beginSPIRVBlock(else_label_id);
        try self.genBody(inst.else_body);

        return null;
    }

    fn genLoad(self: *DeclGen, inst: *Inst.UnOp) !ResultId {
        const operand_id = try self.resolve(inst.operand);

        const result_type_id = try self.genType(inst.base.src, inst.base.ty);
        const result_id = self.spv.allocResultId();

        const operands = if (inst.base.ty.isVolatilePtr())
            &[_]Word{ result_type_id, result_id, operand_id, @bitCast(u32, spec.MemoryAccess{.Volatile = true}) }
        else
            &[_]Word{ result_type_id, result_id, operand_id};

        try writeInstruction(&self.spv.binary.fn_decls, .OpLoad, operands);

        return result_id;
    }

    fn genLoop(self: *DeclGen, inst: *Inst.Loop) !?ResultId {
        // TODO: This instruction needs to be the last in a block. Is that guaranteed?
        const loop_label_id = self.spv.allocResultId();

        // Jump to the loop entry point
        try writeInstruction(&self.spv.binary.fn_decls, .OpBranch, &[_]Word{ loop_label_id });

        // TODO: Look into OpLoopMerge.

        try self.beginSPIRVBlock(loop_label_id);
        try self.genBody(inst.body);

        try writeInstruction(&self.spv.binary.fn_decls, .OpBranch, &[_]Word{ loop_label_id });
        return null;
    }

    fn genRet(self: *DeclGen, inst: *Inst.UnOp) !?ResultId {
        const operand_id = try self.resolve(inst.operand);
        // TODO: This instruction needs to be the last in a block. Is that guaranteed?
        try writeInstruction(&self.spv.binary.fn_decls, .OpReturnValue, &[_]Word{operand_id});
        return null;
    }

    fn genRetVoid(self: *DeclGen) !?ResultId {
        // TODO: This instruction needs to be the last in a block. Is that guaranteed?
        try writeInstruction(&self.spv.binary.fn_decls, .OpReturn, &[_]Word{});
        return null;
    }

    fn genStore(self: *DeclGen, inst: *Inst.BinOp) !?ResultId {
        const dst_ptr_id = try self.resolve(inst.lhs);
        const src_val_id = try self.resolve(inst.rhs);

        const operands = if (inst.lhs.ty.isVolatilePtr())
            &[_]Word{ dst_ptr_id, src_val_id, @bitCast(u32, spec.MemoryAccess{.Volatile = true}) }
        else
            &[_]Word{ dst_ptr_id, src_val_id };

        try writeInstruction(&self.spv.binary.fn_decls, .OpStore, operands);
        return null;
    }

    fn genUnreach(self: *DeclGen) !?ResultId {
        // TODO: This instruction needs to be the last in a block. Is that guaranteed?
        try writeInstruction(&self.spv.binary.fn_decls, .OpUnreachable, &[_]Word{});
        return null;
    }
};
