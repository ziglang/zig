const std = @import("std");
const Allocator = std.mem.Allocator;
const Target = std.Target;
const log = std.log.scoped(.codegen);
const assert = std.debug.assert;

const Module = @import("../Module.zig");
const Decl = Module.Decl;
const Type = @import("../type.zig").Type;
const Value = @import("../value.zig").Value;
const LazySrcLoc = Module.LazySrcLoc;
const Air = @import("../Air.zig");
const Zir = @import("../Zir.zig");
const Liveness = @import("../Liveness.zig");

const spec = @import("spirv/spec.zig");
const Opcode = spec.Opcode;
const Word = spec.Word;
const IdRef = spec.IdRef;
const IdResult = spec.IdResult;
const IdResultType = spec.IdResultType;

const SpvModule = @import("spirv/Module.zig");
const SpvSection = @import("spirv/Section.zig");
const SpvType = @import("spirv/type.zig").Type;
const SpvAssembler = @import("spirv/Assembler.zig");

const InstMap = std.AutoHashMapUnmanaged(Air.Inst.Index, IdRef);

const IncomingBlock = struct {
    src_label_id: IdRef,
    break_value_id: IdRef,
};

pub const BlockMap = std.AutoHashMapUnmanaged(Air.Inst.Index, struct {
    label_id: IdRef,
    incoming_blocks: *std.ArrayListUnmanaged(IncomingBlock),
});

/// This structure is used to compile a declaration, and contains all relevant meta-information to deal with that.
pub const DeclGen = struct {
    /// A general-purpose allocator that can be used for any allocations for this DeclGen.
    gpa: Allocator,

    /// The Zig module that we are generating decls for.
    module: *Module,

    /// The SPIR-V module that instructions should be emitted into.
    spv: *SpvModule,

    /// The decl we are currently generating code for.
    decl_index: Decl.Index,

    /// The intermediate code of the declaration we are currently generating. Note: If
    /// the declaration is not a function, this value will be undefined!
    air: Air,

    /// The liveness analysis of the intermediate code for the declaration we are currently generating.
    /// Note: If the declaration is not a function, this value will be undefined!
    liveness: Liveness,

    ids: *const std.AutoHashMap(Decl.Index, IdResult),

    /// An array of function argument result-ids. Each index corresponds with the
    /// function argument of the same index.
    args: std.ArrayListUnmanaged(IdRef) = .{},

    /// A counter to keep track of how many `arg` instructions we've seen yet.
    next_arg_index: u32,

    /// A map keeping track of which instruction generated which result-id.
    inst_results: InstMap = .{},

    /// We need to keep track of result ids for block labels, as well as the 'incoming'
    /// blocks for a block.
    blocks: BlockMap = .{},

    /// The label of the SPIR-V block we are currently generating.
    current_block_label_id: IdRef,

    /// The code (prologue and body) for the function we are currently generating code for.
    func: SpvModule.Fn = .{},

    /// If `gen` returned `Error.CodegenFail`, this contains an explanatory message.
    /// Memory is owned by `module.gpa`.
    error_msg: ?*Module.ErrorMsg,

    /// Possible errors the `genDecl` function may return.
    const Error = error{ CodegenFail, OutOfMemory };

    /// This structure is used to return information about a type typically used for
    /// arithmetic operations. These types may either be integers, floats, or a vector
    /// of these. Most scalar operations also work on vectors, so we can easily represent
    /// those as arithmetic types. If the type is a scalar, 'inner type' refers to the
    /// scalar type. Otherwise, if its a vector, it refers to the vector's element type.
    const ArithmeticTypeInfo = struct {
        /// A classification of the inner type.
        const Class = enum {
            /// A boolean.
            bool,

            /// A regular, **native**, integer.
            /// This is only returned when the backend supports this int as a native type (when
            /// the relevant capability is enabled).
            integer,

            /// A regular float. These are all required to be natively supported. Floating points
            /// for which the relevant capability is not enabled are not emulated.
            float,

            /// An integer of a 'strange' size (which' bit size is not the same as its backing
            /// type. **Note**: this may **also** include power-of-2 integers for which the
            /// relevant capability is not enabled), but still within the limits of the largest
            /// natively supported integer type.
            strange_integer,

            /// An integer with more bits than the largest natively supported integer type.
            composite_integer,
        };

        /// The number of bits in the inner type.
        /// This is the actual number of bits of the type, not the size of the backing integer.
        bits: u16,

        /// Whether the type is a vector.
        is_vector: bool,

        /// Whether the inner type is signed. Only relevant for integers.
        signedness: std.builtin.Signedness,

        /// A classification of the inner type. These scenarios
        /// will all have to be handled slightly different.
        class: Class,
    };

    /// Initialize the common resources of a DeclGen. Some fields are left uninitialized,
    /// only set when `gen` is called.
    pub fn init(
        allocator: Allocator,
        module: *Module,
        spv: *SpvModule,
        ids: *const std.AutoHashMap(Decl.Index, IdResult),
    ) DeclGen {
        return .{
            .gpa = allocator,
            .module = module,
            .spv = spv,
            .decl_index = undefined,
            .air = undefined,
            .liveness = undefined,
            .ids = ids,
            .next_arg_index = undefined,
            .current_block_label_id = undefined,
            .error_msg = undefined,
        };
    }

    /// Generate the code for `decl`. If a reportable error occurred during code generation,
    /// a message is returned by this function. Callee owns the memory. If this function
    /// returns such a reportable error, it is valid to be called again for a different decl.
    pub fn gen(self: *DeclGen, decl_index: Decl.Index, air: Air, liveness: Liveness) !?*Module.ErrorMsg {
        // Reset internal resources, we don't want to re-allocate these.
        self.decl_index = decl_index;
        self.air = air;
        self.liveness = liveness;
        self.args.items.len = 0;
        self.next_arg_index = 0;
        self.inst_results.clearRetainingCapacity();
        self.blocks.clearRetainingCapacity();
        self.current_block_label_id = undefined;
        self.func.reset();
        self.error_msg = null;

        self.genDecl() catch |err| switch (err) {
            error.CodegenFail => return self.error_msg,
            else => |others| {
                // There might be an error that happened *after* self.error_msg
                // was already allocated, so be sure to free it.
                if (self.error_msg) |error_msg| {
                    error_msg.deinit(self.module.gpa);
                }
                return others;
            },
        };

        return null;
    }

    /// Free resources owned by the DeclGen.
    pub fn deinit(self: *DeclGen) void {
        self.args.deinit(self.gpa);
        self.inst_results.deinit(self.gpa);
        self.blocks.deinit(self.gpa);
        self.func.deinit(self.gpa);
    }

    /// Return the target which we are currently compiling for.
    pub fn getTarget(self: *DeclGen) std.Target {
        return self.module.getTarget();
    }

    pub fn fail(self: *DeclGen, comptime format: []const u8, args: anytype) Error {
        @setCold(true);
        const src = LazySrcLoc.nodeOffset(0);
        const src_loc = src.toSrcLoc(self.module.declPtr(self.decl_index));
        assert(self.error_msg == null);
        self.error_msg = try Module.ErrorMsg.create(self.module.gpa, src_loc, format, args);
        return error.CodegenFail;
    }

    pub fn todo(self: *DeclGen, comptime format: []const u8, args: anytype) Error {
        return self.fail("TODO (SPIR-V): " ++ format, args);
    }

    /// Fetch the result-id for a previously generated instruction or constant.
    fn resolve(self: *DeclGen, inst: Air.Inst.Ref) !IdRef {
        if (self.air.value(inst)) |val| {
            return self.genConstant(self.air.typeOf(inst), val);
        }
        const index = Air.refToIndex(inst).?;
        return self.inst_results.get(index).?; // Assertion means instruction does not dominate usage.
    }

    /// Start a new SPIR-V block, Emits the label of the new block, and stores which
    /// block we are currently generating.
    /// Note that there is no such thing as nested blocks like in ZIR or AIR, so we don't need to
    /// keep track of the previous block.
    fn beginSpvBlock(self: *DeclGen, label_id: IdResult) !void {
        try self.func.body.emit(self.spv.gpa, .OpLabel, .{ .id_result = label_id });
        self.current_block_label_id = label_id.toRef();
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
        const target = self.getTarget();

        // The backend will never be asked to compiler a 0-bit integer, so we won't have to handle those in this function.
        assert(bits != 0);

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
        const target = self.getTarget();
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
        const target = self.getTarget();
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
                break :blk ArithmeticTypeInfo{
                    .bits = int_info.bits,
                    .is_vector = false,
                    .signedness = int_info.signedness,
                    .class = if (maybe_backing_bits) |backing_bits|
                        if (backing_bits == int_info.bits)
                            ArithmeticTypeInfo.Class.integer
                        else
                            ArithmeticTypeInfo.Class.strange_integer
                    else
                        .composite_integer,
                };
            },
            // As of yet, there is no vector support in the self-hosted compiler.
            .Vector => self.todo("implement arithmeticTypeInfo for Vector", .{}),
            // TODO: For which types is this the case?
            else => self.todo("implement arithmeticTypeInfo for {}", .{ty.fmtDebug()}),
        };
    }

    /// Generate a constant representing `val`.
    /// TODO: Deduplication?
    fn genConstant(self: *DeclGen, ty: Type, val: Value) Error!IdRef {
        if (ty.zigTypeTag() == .Fn) {
            const fn_decl_index = switch (val.tag()) {
                .extern_fn => val.castTag(.extern_fn).?.data.owner_decl,
                .function => val.castTag(.function).?.data.owner_decl,
                else => unreachable,
            };
            const decl = self.module.declPtr(fn_decl_index);
            self.module.markDeclAlive(decl);
            return self.ids.get(fn_decl_index).?.toRef();
        }

        const target = self.getTarget();
        const section = &self.spv.sections.types_globals_constants;
        const result_id = self.spv.allocId();
        const result_type_id = try self.resolveTypeId(ty);

        if (val.isUndef()) {
            try section.emit(self.spv.gpa, .OpUndef, .{ .id_result_type = result_type_id, .id_result = result_id });
            return result_id.toRef();
        }

        switch (ty.zigTypeTag()) {
            .Int => {
                const int_info = ty.intInfo(target);
                const backing_bits = self.backingIntBits(int_info.bits) orelse {
                    // Integers too big for any native type are represented as "composite integers": An array of largestSupportedIntBits.
                    return self.todo("implement composite int constants for {}", .{ty.fmtDebug()});
                };

                // We can just use toSignedInt/toUnsignedInt here as it returns u64 - a type large enough to hold any
                // SPIR-V native type (up to i/u64 with Int64). If SPIR-V ever supports native ints of a larger size, this
                // might need to be updated.
                assert(self.largestSupportedIntBits() <= @bitSizeOf(u64));

                // Note, value is required to be sign-extended, so we don't need to mask off the upper bits.
                // See https://www.khronos.org/registry/SPIR-V/specs/unified1/SPIRV.html#Literal
                var int_bits = if (ty.isSignedInt()) @bitCast(u64, val.toSignedInt(target)) else val.toUnsignedInt(target);

                const value: spec.LiteralContextDependentNumber = switch (backing_bits) {
                    1...32 => .{ .uint32 = @truncate(u32, int_bits) },
                    33...64 => .{ .uint64 = int_bits },
                    else => unreachable,
                };

                try section.emit(self.spv.gpa, .OpConstant, .{
                    .id_result_type = result_type_id,
                    .id_result = result_id,
                    .value = value,
                });
            },
            .Bool => {
                const operands = .{ .id_result_type = result_type_id, .id_result = result_id };
                if (val.toBool()) {
                    try section.emit(self.spv.gpa, .OpConstantTrue, operands);
                } else {
                    try section.emit(self.spv.gpa, .OpConstantFalse, operands);
                }
            },
            .Float => {
                // At this point we are guaranteed that the target floating point type is supported, otherwise the function
                // would have exited at resolveTypeId(ty).

                const value: spec.LiteralContextDependentNumber = switch (ty.floatBits(target)) {
                    // Prevent upcasting to f32 by bitcasting and writing as a uint32.
                    16 => .{ .uint32 = @bitCast(u16, val.toFloat(f16)) },
                    32 => .{ .float32 = val.toFloat(f32) },
                    64 => .{ .float64 = val.toFloat(f64) },
                    128 => unreachable, // Filtered out in the call to resolveTypeId.
                    // TODO: Insert case for long double when the layout for that is determined?
                    else => unreachable,
                };

                try section.emit(self.spv.gpa, .OpConstant, .{
                    .id_result_type = result_type_id,
                    .id_result = result_id,
                    .value = value,
                });
            },
            .Array => switch (val.tag()) {
                .aggregate => { // todo: combine with Vector
                    const elem_vals = val.castTag(.aggregate).?.data;
                    const elem_ty = ty.elemType();
                    const len = @intCast(u32, ty.arrayLenIncludingSentinel()); // TODO: limit spir-v to 32 bit arrays in a more elegant way.
                    const constituents = try self.spv.gpa.alloc(IdRef, len);
                    defer self.spv.gpa.free(constituents);
                    for (elem_vals[0..len]) |elem_val, i| {
                        constituents[i] = try self.genConstant(elem_ty, elem_val);
                    }
                    try section.emit(self.spv.gpa, .OpConstantComposite, .{
                        .id_result_type = result_type_id,
                        .id_result = result_id,
                        .constituents = constituents,
                    });
                },
                .repeated => {
                    const elem_val = val.castTag(.repeated).?.data;
                    const elem_ty = ty.elemType();
                    const len = @intCast(u32, ty.arrayLenIncludingSentinel()); // TODO: limit spir-v to 32 bit arrays in a more elegant way.
                    const constituents = try self.spv.gpa.alloc(IdRef, len);
                    defer self.spv.gpa.free(constituents);

                    const elem_val_id = try self.genConstant(elem_ty, elem_val);
                    for (constituents[0..len]) |*elem| {
                        elem.* = elem_val_id;
                    }
                    if (ty.sentinel()) |sentinel| {
                        constituents[len] = try self.genConstant(elem_ty, sentinel);
                    }
                    try section.emit(self.spv.gpa, .OpConstantComposite, .{
                        .id_result_type = result_type_id,
                        .id_result = result_id,
                        .constituents = constituents,
                    });
                },
                else => return self.todo("array constant with tag {s}", .{@tagName(val.tag())}),
            },
            .Vector => switch (val.tag()) {
                .aggregate => {
                    const elem_vals = val.castTag(.aggregate).?.data;
                    const vector_len = @intCast(usize, ty.vectorLen());
                    const elem_ty = ty.elemType();

                    const elem_refs = try self.gpa.alloc(IdRef, vector_len);
                    defer self.gpa.free(elem_refs);
                    for (elem_refs, 0..) |*elem, i| {
                        elem.* = try self.genConstant(elem_ty, elem_vals[i]);
                    }
                    try section.emit(self.spv.gpa, .OpConstantComposite, .{
                        .id_result_type = result_type_id,
                        .id_result = result_id,
                        .constituents = elem_refs,
                    });
                },
                else => return self.todo("vector constant with tag {s}", .{@tagName(val.tag())}),
            },
            .Enum => {
                var ty_buffer: Type.Payload.Bits = undefined;
                const int_ty = ty.intTagType(&ty_buffer);
                const int_info = int_ty.intInfo(target);

                const backing_bits = self.backingIntBits(int_info.bits) orelse {
                    return self.todo("implement composite int constants for {}", .{int_ty.fmtDebug()});
                };

                var int_buffer: Value.Payload.U64 = undefined;
                const int_val = val.enumToInt(ty, &int_buffer).toUnsignedInt(target); // TODO: composite integer constants

                const value: spec.LiteralContextDependentNumber = switch (backing_bits) {
                    1...32 => .{ .uint32 = @truncate(u32, int_val) },
                    33...64 => .{ .uint64 = int_val },
                    else => unreachable,
                };

                try section.emit(self.spv.gpa, .OpConstant, .{
                    .id_result_type = result_type_id,
                    .id_result = result_id,
                    .value = value,
                });
            },
            .Struct => {
                const constituents = if (ty.isSimpleTupleOrAnonStruct()) blk: {
                    const tuple = ty.tupleFields();
                    const constituents = try self.spv.gpa.alloc(IdRef, tuple.types.len);
                    errdefer self.spv.gpa.free(constituents);

                    var member_index: usize = 0;
                    for (tuple.types) |field_ty, i| {
                        const field_val = tuple.values[i];
                        if (field_val.tag() != .unreachable_value or !field_ty.hasRuntimeBits()) continue;
                        constituents[member_index] = try self.genConstant(field_ty, field_val);
                        member_index += 1;
                    }

                    break :blk constituents[0..member_index];
                } else blk: {
                    const struct_ty = ty.castTag(.@"struct").?.data;

                    if (struct_ty.layout == .Packed) {
                        return self.todo("packed struct constants", .{});
                    }

                    const field_vals = val.castTag(.aggregate).?.data;
                    const constituents = try self.spv.gpa.alloc(IdRef, struct_ty.fields.count());
                    errdefer self.spv.gpa.free(constituents);
                    var member_index: usize = 0;
                    for (struct_ty.fields.values()) |field, i| {
                        if (field.is_comptime or !field.ty.hasRuntimeBits()) continue;
                        constituents[member_index] = try self.genConstant(field.ty, field_vals[i]);
                        member_index += 1;
                    }

                    break :blk constituents[0..member_index];
                };
                defer self.spv.gpa.free(constituents);

                try section.emit(self.spv.gpa, .OpConstantComposite, .{
                    .id_result_type = result_type_id,
                    .id_result = result_id,
                    .constituents = constituents,
                });
            },
            .Void => unreachable,
            .Fn => unreachable,
            else => return self.todo("constant generation of type {s}: {}", .{ @tagName(ty.zigTypeTag()), ty.fmtDebug() }),
        }

        return result_id.toRef();
    }

    /// Turn a Zig type into a SPIR-V Type, and return its type result-id.
    fn resolveTypeId(self: *DeclGen, ty: Type) !IdResultType {
        const type_ref = try self.resolveType(ty);
        return self.spv.typeResultId(type_ref);
    }

    /// Create an integer type suitable for storing at least 'bits' bits.
    fn intType(self: *DeclGen, signedness: std.builtin.Signedness, bits: u16) !SpvType.Ref {
        const backing_bits = self.backingIntBits(bits) orelse {
            // TODO: Integers too big for any native type are represented as "composite integers":
            // An array of largestSupportedIntBits.
            return self.todo("Implement {s} composite int type of {} bits", .{ @tagName(signedness), bits });
        };

        return try self.spv.resolveType(try SpvType.int(self.spv.arena, signedness, backing_bits));
    }

    /// Create an integer type that represents 'usize'.
    fn sizeType(self: *DeclGen) !SpvType.Ref {
        return try self.intType(.unsigned, self.getTarget().cpu.arch.ptrBitWidth());
    }

    /// Construct a simple struct type which consists of some members, and no decorations.
    /// `members` lifetime only needs to last for this function as it is copied.
    fn simpleStructType(self: *DeclGen, members: []const SpvType.Payload.Struct.Member) !SpvType.Ref {
        const payload = try self.spv.arena.create(SpvType.Payload.Struct);
        payload.* = .{
            .members = try self.spv.arena.dupe(SpvType.Payload.Struct.Member, members),
            .decorations = .{},
        };
        return try self.spv.resolveType(SpvType.initPayload(&payload.base));
    }

    fn simpleStructTypeId(self: *DeclGen, members: []const SpvType.Payload.Struct.Member) !IdResultType {
        const type_ref = try self.simpleStructType(members);
        return self.spv.typeResultId(type_ref);
    }

    /// Turn a Zig type into a SPIR-V Type, and return a reference to it.
    fn resolveType(self: *DeclGen, ty: Type) Error!SpvType.Ref {
        const target = self.getTarget();
        switch (ty.zigTypeTag()) {
            .Void, .NoReturn => return try self.spv.resolveType(SpvType.initTag(.void)),
            .Bool => {
                // TODO: SPIR-V booleans are opaque. For local variables this is fine, but for structs
                // members we want to use integer types instead.
                return try self.spv.resolveType(SpvType.initTag(.bool));
            },
            .Int => {
                const int_info = ty.intInfo(target);
                return try self.intType(int_info.signedness, int_info.bits);
            },
            .Enum => {
                var buffer: Type.Payload.Bits = undefined;
                const int_ty = ty.intTagType(&buffer);
                const int_info = int_ty.intInfo(target);
                return try self.intType(.unsigned, int_info.bits);
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
                    return self.fail("Floating point width of {} bits is not supported for the current SPIR-V feature set", .{bits});
                }

                return try self.spv.resolveType(SpvType.float(bits));
            },
            .Array => {
                const elem_ty = ty.childType();
                const total_len = std.math.cast(u32, ty.arrayLenIncludingSentinel()) orelse {
                    return self.fail("array type of {} elements is too large", .{ty.arrayLenIncludingSentinel()});
                };

                const payload = try self.spv.arena.create(SpvType.Payload.Array);
                payload.* = .{
                    .element_type = try self.resolveType(elem_ty),
                    .length = total_len,
                    .array_stride = @intCast(u32, ty.abiSize(target)),
                };
                return try self.spv.resolveType(SpvType.initPayload(&payload.base));
            },
            .Fn => {
                // TODO: Put this somewhere in Sema.zig
                if (ty.fnIsVarArgs())
                    return self.fail("VarArgs functions are unsupported for SPIR-V", .{});

                const param_types = try self.spv.arena.alloc(SpvType.Ref, ty.fnParamLen());
                for (param_types, 0..) |*param, i| {
                    param.* = try self.resolveType(ty.fnParamType(i));
                }

                const return_type = try self.resolveType(ty.fnReturnType());

                const payload = try self.spv.arena.create(SpvType.Payload.Function);
                payload.* = .{ .return_type = return_type, .parameters = param_types };
                return try self.spv.resolveType(SpvType.initPayload(&payload.base));
            },
            .Pointer => {
                const ptr_info = ty.ptrInfo().data;

                const ptr_payload = try self.spv.arena.create(SpvType.Payload.Pointer);
                ptr_payload.* = .{
                    .storage_class = spirvStorageClass(ptr_info.@"addrspace"),
                    .child_type = try self.resolveType(ptr_info.pointee_type),
                    // TODO: ???
                    .array_stride = 0,
                    // Note: only available in Kernels!
                    .alignment = ty.ptrAlignment(target) * 8,
                    .max_byte_offset = null,
                };
                const spv_ptr_ty = try self.spv.resolveType(SpvType.initPayload(&ptr_payload.base));

                if (ptr_info.size != .Slice) {
                    return spv_ptr_ty;
                }

                var buf: Type.SlicePtrFieldTypeBuffer = undefined;
                const ptr_ty = ty.slicePtrFieldType(&buf);
                const len_ty = Type.usize;

                const ptr_size = ptr_ty.abiSize(target);
                const len_align = len_ty.abiAlignment(target);
                const len_offset = std.mem.alignForwardGeneric(u64, ptr_size, len_align);

                return try self.simpleStructType(&.{
                    .{ .ty = spv_ptr_ty, .offset = 0 },
                    .{ .ty = try self.sizeType(), .offset = @intCast(u32, len_offset) },
                });
            },
            .Vector => {
                // Although not 100% the same, Zig vectors map quite neatly to SPIR-V vectors (including many integer and float operations
                // which work on them), so simply use those.
                // Note: SPIR-V vectors only support bools, ints and floats, so pointer vectors need to be supported another way.
                // "composite integers" (larger than the largest supported native type) can probably be represented by an array of vectors.
                // TODO: The SPIR-V spec mentions that vector sizes may be quite restricted! look into which we can use, and whether OpTypeVector
                // is adequate at all for this.

                // TODO: Properly verify sizes and child type.

                const payload = try self.spv.arena.create(SpvType.Payload.Vector);
                payload.* = .{
                    .component_type = try self.resolveType(ty.elemType()),
                    .component_count = @intCast(u32, ty.vectorLen()),
                };
                return try self.spv.resolveType(SpvType.initPayload(&payload.base));
            },
            .Struct => {
                if (ty.isSimpleTupleOrAnonStruct()) {
                    const tuple = ty.tupleFields();
                    const members = try self.spv.arena.alloc(SpvType.Payload.Struct.Member, tuple.types.len);
                    var member_index: usize = 0;
                    for (tuple.types) |field_ty, i| {
                        const field_val = tuple.values[i];
                        if (field_val.tag() != .unreachable_value or !field_ty.hasRuntimeBits()) continue;

                        members[member_index] = .{
                            .ty = try self.resolveType(field_ty),
                            .offset = 0,
                        };
                        member_index += 1;
                    }

                    const payload = try self.spv.arena.create(SpvType.Payload.Struct);
                    payload.* = .{
                        .members = members[0..member_index],
                    };
                    return try self.spv.resolveType(SpvType.initPayload(&payload.base));
                }

                const struct_ty = ty.castTag(.@"struct").?.data;

                if (struct_ty.layout == .Packed) {
                    return try self.resolveType(struct_ty.backing_int_ty);
                }

                const members = try self.spv.arena.alloc(SpvType.Payload.Struct.Member, struct_ty.fields.count());
                var member_index: usize = 0;
                for (struct_ty.fields.values()) |field| {
                    if (field.is_comptime or !field.ty.hasRuntimeBits()) continue;

                    members[member_index] = .{
                        .ty = try self.resolveType(field.ty),
                        .offset = field.offset,
                    };
                }

                const payload = try self.spv.arena.create(SpvType.Payload.Struct);
                payload.* = .{
                    .members = members[0..member_index],
                };
                return try self.spv.resolveType(SpvType.initPayload(&payload.base));
            },
            .Null,
            .Undefined,
            .EnumLiteral,
            .ComptimeFloat,
            .ComptimeInt,
            .Type,
            => unreachable, // Must be comptime.

            else => |tag| return self.todo("Implement zig type '{}'", .{tag}),
        }
    }

    fn spirvStorageClass(as: std.builtin.AddressSpace) spec.StorageClass {
        return switch (as) {
            .generic => .Generic, // TODO: Disallow?
            .gs, .fs, .ss => unreachable,
            .shared => .Workgroup,
            .local => .Private,
            .global, .param, .constant, .flash, .flash1, .flash2, .flash3, .flash4, .flash5 => unreachable,
        };
    }

    fn genDecl(self: *DeclGen) !void {
        const result_id = self.ids.get(self.decl_index).?;
        const decl = self.module.declPtr(self.decl_index);

        if (decl.val.castTag(.function)) |_| {
            assert(decl.ty.zigTypeTag() == .Fn);
            const prototype_id = try self.resolveTypeId(decl.ty);
            try self.func.prologue.emit(self.spv.gpa, .OpFunction, .{
                .id_result_type = try self.resolveTypeId(decl.ty.fnReturnType()),
                .id_result = result_id,
                .function_control = .{}, // TODO: We can set inline here if the type requires it.
                .function_type = prototype_id.toRef(),
            });

            const params = decl.ty.fnParamLen();
            var i: usize = 0;

            try self.args.ensureUnusedCapacity(self.gpa, params);
            while (i < params) : (i += 1) {
                const param_type_id = try self.resolveTypeId(decl.ty.fnParamType(i));
                const arg_result_id = self.spv.allocId();
                try self.func.prologue.emit(self.spv.gpa, .OpFunctionParameter, .{
                    .id_result_type = param_type_id,
                    .id_result = arg_result_id,
                });
                self.args.appendAssumeCapacity(arg_result_id.toRef());
            }

            // TODO: This could probably be done in a better way...
            const root_block_id = self.spv.allocId();

            // The root block of a function declaration should appear before OpVariable instructions,
            // so it is generated into the function's prologue.
            try self.func.prologue.emit(self.spv.gpa, .OpLabel, .{
                .id_result = root_block_id,
            });
            self.current_block_label_id = root_block_id.toRef();

            const main_body = self.air.getMainBody();
            try self.genBody(main_body);

            // Append the actual code into the functions section.
            try self.func.body.emit(self.spv.gpa, .OpFunctionEnd, {});
            try self.spv.addFunction(self.func);
        } else {
            // TODO
            // return self.todo("generate decl type {}", .{decl.ty.zigTypeTag()});
        }
    }

    fn genBody(self: *DeclGen, body: []const Air.Inst.Index) Error!void {
        for (body) |inst| {
            try self.genInst(inst);
        }
    }

    fn genInst(self: *DeclGen, inst: Air.Inst.Index) !void {
        const air_tags = self.air.instructions.items(.tag);
        const maybe_result_id: ?IdRef = switch (air_tags[inst]) {
            // zig fmt: off
            .add, .addwrap => try self.airArithOp(inst, .OpFAdd, .OpIAdd, .OpIAdd, true),
            .sub, .subwrap => try self.airArithOp(inst, .OpFSub, .OpISub, .OpISub, true),
            .mul, .mulwrap => try self.airArithOp(inst, .OpFMul, .OpIMul, .OpIMul, true),

            .div_float,
            .div_float_optimized,
            // TODO: Check that this is the right operation.
            .div_trunc,
            .div_trunc_optimized,
            => try self.airArithOp(inst, .OpFDiv, .OpSDiv, .OpUDiv, false),
            // TODO: Check if this is the right operation
            // TODO: Make airArithOp for rem not emit a mask for the LHS.
            .rem,
            .rem_optimized,
            => try self.airArithOp(inst, .OpFRem, .OpSRem, .OpSRem, false),

            .add_with_overflow => try self.airOverflowArithOp(inst),

            .shuffle => try self.airShuffle(inst),

            .bit_and  => try self.airBinOpSimple(inst, .OpBitwiseAnd),
            .bit_or   => try self.airBinOpSimple(inst, .OpBitwiseOr),
            .xor      => try self.airBinOpSimple(inst, .OpBitwiseXor),
            .bool_and => try self.airBinOpSimple(inst, .OpLogicalAnd),
            .bool_or  => try self.airBinOpSimple(inst, .OpLogicalOr),

            .bitcast => try self.airBitcast(inst),
            .intcast => try self.airIntcast(inst),
            .not     => try self.airNot(inst),

            .slice_ptr      => try self.airSliceField(inst, 0),
            .slice_len      => try self.airSliceField(inst, 1),
            .slice_elem_ptr => try self.airSliceElemPtr(inst),
            .slice_elem_val => try self.airSliceElemVal(inst),
            .ptr_elem_ptr   => try self.airPtrElemPtr(inst),

            .struct_field_val => try self.airStructFieldVal(inst),

            .struct_field_ptr_index_0 => try self.airStructFieldPtrIndex(inst, 0),
            .struct_field_ptr_index_1 => try self.airStructFieldPtrIndex(inst, 1),
            .struct_field_ptr_index_2 => try self.airStructFieldPtrIndex(inst, 2),
            .struct_field_ptr_index_3 => try self.airStructFieldPtrIndex(inst, 3),

            .cmp_eq  => try self.airCmp(inst, .OpFOrdEqual,            .OpLogicalEqual,      .OpIEqual),
            .cmp_neq => try self.airCmp(inst, .OpFOrdNotEqual,         .OpLogicalNotEqual,   .OpINotEqual),
            .cmp_gt  => try self.airCmp(inst, .OpFOrdGreaterThan,      .OpSGreaterThan,      .OpUGreaterThan),
            .cmp_gte => try self.airCmp(inst, .OpFOrdGreaterThanEqual, .OpSGreaterThanEqual, .OpUGreaterThanEqual),
            .cmp_lt  => try self.airCmp(inst, .OpFOrdLessThan,         .OpSLessThan,         .OpULessThan),
            .cmp_lte => try self.airCmp(inst, .OpFOrdLessThanEqual,    .OpSLessThanEqual,    .OpULessThanEqual),

            .arg     => self.airArg(),
            .alloc   => try self.airAlloc(inst),
            // TODO: We probably need to have a special implementation of this for the C abi.
            .ret_ptr => try self.airAlloc(inst),
            .block   => try self.airBlock(inst),
            .load    => try self.airLoad(inst),

            .br         => return self.airBr(inst),
            .breakpoint => return,
            .cond_br    => return self.airCondBr(inst),
            .constant   => unreachable,
            .dbg_stmt   => return self.airDbgStmt(inst),
            .loop       => return self.airLoop(inst),
            .ret        => return self.airRet(inst),
            .ret_load   => return self.airRetLoad(inst),
            .store      => return self.airStore(inst),
            .unreach    => return self.airUnreach(),

            .assembly => try self.airAssembly(inst),

            .call              => try self.airCall(inst, .auto),
            .call_always_tail  => try self.airCall(inst, .always_tail),
            .call_never_tail   => try self.airCall(inst, .never_tail),
            .call_never_inline => try self.airCall(inst, .never_inline),

            .dbg_var_ptr => return,
            .dbg_var_val => return,
            .dbg_block_begin => return,
            .dbg_block_end => return,
            // zig fmt: on

            else => |tag| return self.todo("implement AIR tag {s}", .{@tagName(tag)}),
        };

        const result_id = maybe_result_id orelse return;
        try self.inst_results.putNoClobber(self.gpa, inst, result_id);
    }

    fn airBinOpSimple(self: *DeclGen, inst: Air.Inst.Index, comptime opcode: Opcode) !?IdRef {
        if (self.liveness.isUnused(inst)) return null;
        const bin_op = self.air.instructions.items(.data)[inst].bin_op;
        const lhs_id = try self.resolve(bin_op.lhs);
        const rhs_id = try self.resolve(bin_op.rhs);
        const result_id = self.spv.allocId();
        const result_type_id = try self.resolveTypeId(self.air.typeOfIndex(inst));
        try self.func.body.emit(self.spv.gpa, opcode, .{
            .id_result_type = result_type_id,
            .id_result = result_id,
            .operand_1 = lhs_id,
            .operand_2 = rhs_id,
        });
        return result_id.toRef();
    }

    fn maskStrangeInt(self: *DeclGen, ty_id: IdResultType, int_id: IdRef, bits: u16) !IdRef {
        const backing_bits = self.backingIntBits(bits).?;
        const mask_value = if (bits == 64) 0xFFFF_FFFF_FFFF_FFFF else (@as(u64, 1) << @intCast(u6, bits)) - 1;
        const mask_lit: spec.LiteralContextDependentNumber = switch (backing_bits) {
            1...32 => .{ .uint32 = @truncate(u32, mask_value) },
            33...64 => .{ .uint64 = mask_value },
            else => unreachable,
        };
        // TODO: We should probably optimize these constants a bit.
        const mask_id = self.spv.allocId();
        try self.spv.sections.types_globals_constants.emit(self.spv.gpa, .OpConstant, .{
            .id_result_type = ty_id,
            .id_result = mask_id,
            .value = mask_lit,
        });
        const result_id = self.spv.allocId();
        try self.func.body.emit(self.spv.gpa, .OpBitwiseAnd, .{
            .id_result_type = ty_id,
            .id_result = result_id,
            .operand_1 = int_id,
            .operand_2 = mask_id.toRef(),
        });
        return result_id.toRef();
    }

    fn airArithOp(
        self: *DeclGen,
        inst: Air.Inst.Index,
        comptime fop: Opcode,
        comptime sop: Opcode,
        comptime uop: Opcode,
        /// true if this operation holds under modular arithmetic.
        comptime modular: bool,
    ) !?IdRef {
        if (self.liveness.isUnused(inst)) return null;
        // LHS and RHS are guaranteed to have the same type, and AIR guarantees
        // the result to be the same as the LHS and RHS, which matches SPIR-V.
        const ty = self.air.typeOfIndex(inst);
        const bin_op = self.air.instructions.items(.data)[inst].bin_op;
        var lhs_id = try self.resolve(bin_op.lhs);
        var rhs_id = try self.resolve(bin_op.rhs);

        const result_id = self.spv.allocId();
        const result_type_id = try self.resolveTypeId(ty);

        assert(self.air.typeOf(bin_op.lhs).eql(ty, self.module));
        assert(self.air.typeOf(bin_op.rhs).eql(ty, self.module));

        // Binary operations are generally applicable to both scalar and vector operations
        // in SPIR-V, but int and float versions of operations require different opcodes.
        const info = try self.arithmeticTypeInfo(ty);

        const opcode_index: usize = switch (info.class) {
            .composite_integer => {
                return self.todo("binary operations for composite integers", .{});
            },
            .strange_integer => blk: {
                if (!modular) {
                    lhs_id = try self.maskStrangeInt(result_type_id, lhs_id, info.bits);
                    rhs_id = try self.maskStrangeInt(result_type_id, rhs_id, info.bits);
                }
                break :blk switch (info.signedness) {
                    .signed => @as(usize, 1),
                    .unsigned => @as(usize, 2),
                };
            },
            .integer => switch (info.signedness) {
                .signed => @as(usize, 1),
                .unsigned => @as(usize, 2),
            },
            .float => 0,
            .bool => unreachable,
        };

        const operands = .{
            .id_result_type = result_type_id,
            .id_result = result_id,
            .operand_1 = lhs_id,
            .operand_2 = rhs_id,
        };

        switch (opcode_index) {
            0 => try self.func.body.emit(self.spv.gpa, fop, operands),
            1 => try self.func.body.emit(self.spv.gpa, sop, operands),
            2 => try self.func.body.emit(self.spv.gpa, uop, operands),
            else => unreachable,
        }
        // TODO: Trap on overflow? Probably going to be annoying.
        // TODO: Look into SPV_KHR_no_integer_wrap_decoration which provides NoSignedWrap/NoUnsignedWrap.

        return result_id.toRef();
    }

    fn airOverflowArithOp(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        if (self.liveness.isUnused(inst)) return null;

        const target = self.getTarget();

        const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
        const extra = self.air.extraData(Air.Bin, ty_pl.payload).data;
        const lhs = try self.resolve(extra.lhs);
        const rhs = try self.resolve(extra.rhs);

        const operand_ty = self.air.typeOf(extra.lhs);
        const result_ty = self.air.typeOfIndex(inst);

        const info = try self.arithmeticTypeInfo(operand_ty);
        switch (info.class) {
            .composite_integer => return self.todo("overflow ops for composite integers", .{}),
            .strange_integer => return self.todo("overflow ops for strange integers", .{}),
            .integer => {},
            .float, .bool => unreachable,
        }

        const operand_ty_id = try self.resolveTypeId(operand_ty);
        const result_type_id = try self.resolveTypeId(result_ty);

        const overflow_member_ty = try self.intType(.unsigned, info.bits);
        const overflow_member_ty_id = self.spv.typeResultId(overflow_member_ty);

        const op_result_id = blk: {
            // Construct the SPIR-V result type.
            // It is almost the same as the zig one, except that the fields must be the same type
            // and they must be unsigned.
            const overflow_result_ty = try self.simpleStructTypeId(&.{
                .{ .ty = overflow_member_ty, .offset = 0 },
                .{ .ty = overflow_member_ty, .offset = @intCast(u32, operand_ty.abiSize(target)) },
            });
            const result_id = self.spv.allocId();
            try self.func.body.emit(self.spv.gpa, .OpIAddCarry, .{
                .id_result_type = overflow_result_ty,
                .id_result = result_id,
                .operand_1 = lhs,
                .operand_2 = rhs,
            });
            break :blk result_id.toRef();
        };

        // Now convert the SPIR-V flavor result into a Zig-flavor result.
        // First, extract the two fields.
        const unsigned_result = try self.extractField(overflow_member_ty_id, op_result_id, 0);
        const overflow = try self.extractField(overflow_member_ty_id, op_result_id, 0);

        // We need to convert the results to the types that Zig expects here.
        // The `result` is the same type except unsigned, so we can just bitcast that.
        const result = try self.bitcast(operand_ty_id, unsigned_result);

        // The overflow needs to be converted into whatever is used to represent it in Zig.
        const casted_overflow = blk: {
            const ov_ty = result_ty.tupleFields().types[1];
            const ov_ty_id = try self.resolveTypeId(ov_ty);
            const result_id = self.spv.allocId();
            try self.func.body.emit(self.spv.gpa, .OpUConvert, .{
                .id_result_type = ov_ty_id,
                .id_result = result_id,
                .unsigned_value = overflow,
            });
            break :blk result_id.toRef();
        };

        // TODO: If copying this function for borrow, make sure to convert -1 to 1 as appropriate.

        // Finally, construct the Zig type.
        // Layout is result, overflow.
        const result_id = self.spv.allocId();
        try self.func.body.emit(self.spv.gpa, .OpCompositeConstruct, .{
            .id_result_type = result_type_id,
            .id_result = result_id,
            .constituents = &.{
                result,
                casted_overflow,
            },
        });
        return result_id.toRef();
    }

    fn airShuffle(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        if (self.liveness.isUnused(inst)) return null;
        const ty = self.air.typeOfIndex(inst);
        const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
        const extra = self.air.extraData(Air.Shuffle, ty_pl.payload).data;
        const a = try self.resolve(extra.a);
        const b = try self.resolve(extra.b);
        const mask = self.air.values[extra.mask];
        const mask_len = extra.mask_len;
        const a_len = self.air.typeOf(extra.a).vectorLen();

        const result_id = self.spv.allocId();
        const result_type_id = try self.resolveTypeId(ty);
        // Similar to LLVM, SPIR-V uses indices larger than the length of the first vector
        // to index into the second vector.
        try self.func.body.emitRaw(self.spv.gpa, .OpVectorShuffle, 4 + mask_len);
        self.func.body.writeOperand(spec.IdResultType, result_type_id);
        self.func.body.writeOperand(spec.IdResult, result_id);
        self.func.body.writeOperand(spec.IdRef, a);
        self.func.body.writeOperand(spec.IdRef, b);

        var i: usize = 0;
        while (i < mask_len) : (i += 1) {
            var buf: Value.ElemValueBuffer = undefined;
            const elem = mask.elemValueBuffer(self.module, i, &buf);
            if (elem.isUndef()) {
                self.func.body.writeOperand(spec.LiteralInteger, 0xFFFF_FFFF);
            } else {
                const int = elem.toSignedInt(self.getTarget());
                const unsigned = if (int >= 0) @intCast(u32, int) else @intCast(u32, ~int + a_len);
                self.func.body.writeOperand(spec.LiteralInteger, unsigned);
            }
        }
        return result_id.toRef();
    }

    fn airCmp(self: *DeclGen, inst: Air.Inst.Index, comptime fop: Opcode, comptime sop: Opcode, comptime uop: Opcode) !?IdRef {
        if (self.liveness.isUnused(inst)) return null;
        const bin_op = self.air.instructions.items(.data)[inst].bin_op;
        var lhs_id = try self.resolve(bin_op.lhs);
        var rhs_id = try self.resolve(bin_op.rhs);
        const result_id = self.spv.allocId();
        const result_type_id = try self.resolveTypeId(Type.initTag(.bool));
        const op_ty = self.air.typeOf(bin_op.lhs);
        assert(op_ty.eql(self.air.typeOf(bin_op.rhs), self.module));

        // Comparisons are generally applicable to both scalar and vector operations in SPIR-V,
        // but int and float versions of operations require different opcodes.
        const info = try self.arithmeticTypeInfo(op_ty);

        const opcode_index: usize = switch (info.class) {
            .composite_integer => {
                return self.todo("binary operations for composite integers", .{});
            },
            .float => 0,
            .bool => 1,
            .strange_integer => blk: {
                lhs_id = try self.maskStrangeInt(result_type_id, lhs_id, info.bits);
                rhs_id = try self.maskStrangeInt(result_type_id, rhs_id, info.bits);
                break :blk switch (info.signedness) {
                    .signed => @as(usize, 1),
                    .unsigned => @as(usize, 2),
                };
            },
            .integer => switch (info.signedness) {
                .signed => @as(usize, 1),
                .unsigned => @as(usize, 2),
            },
        };

        const operands = .{
            .id_result_type = result_type_id,
            .id_result = result_id,
            .operand_1 = lhs_id,
            .operand_2 = rhs_id,
        };

        switch (opcode_index) {
            0 => try self.func.body.emit(self.spv.gpa, fop, operands),
            1 => try self.func.body.emit(self.spv.gpa, sop, operands),
            2 => try self.func.body.emit(self.spv.gpa, uop, operands),
            else => unreachable,
        }

        return result_id.toRef();
    }

    fn bitcast(self: *DeclGen, target_type_id: IdResultType, value_id: IdRef) !IdRef {
        const result_id = self.spv.allocId();
        try self.func.body.emit(self.spv.gpa, .OpBitcast, .{
            .id_result_type = target_type_id,
            .id_result = result_id,
            .operand = value_id,
        });
        return result_id.toRef();
    }

    fn airBitcast(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        if (self.liveness.isUnused(inst)) return null;
        const ty_op = self.air.instructions.items(.data)[inst].ty_op;
        const operand_id = try self.resolve(ty_op.operand);
        const result_type_id = try self.resolveTypeId(self.air.typeOfIndex(inst));
        return try self.bitcast(result_type_id, operand_id);
    }

    fn airIntcast(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        if (self.liveness.isUnused(inst)) return null;

        const ty_op = self.air.instructions.items(.data)[inst].ty_op;
        const operand_id = try self.resolve(ty_op.operand);
        const dest_ty = self.air.typeOfIndex(inst);
        const dest_info = try self.arithmeticTypeInfo(dest_ty);
        const dest_ty_id = try self.resolveTypeId(dest_ty);

        const result_id = self.spv.allocId();
        switch (dest_info.signedness) {
            .signed => try self.func.body.emit(self.spv.gpa, .OpSConvert, .{
                .id_result_type = dest_ty_id,
                .id_result = result_id,
                .signed_value = operand_id,
            }),
            .unsigned => try self.func.body.emit(self.spv.gpa, .OpUConvert, .{
                .id_result_type = dest_ty_id,
                .id_result = result_id,
                .unsigned_value = operand_id,
            }),
        }
        return result_id.toRef();
    }

    fn airNot(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        if (self.liveness.isUnused(inst)) return null;
        const ty_op = self.air.instructions.items(.data)[inst].ty_op;
        const operand_id = try self.resolve(ty_op.operand);
        const result_id = self.spv.allocId();
        const result_type_id = try self.resolveTypeId(Type.initTag(.bool));
        try self.func.body.emit(self.spv.gpa, .OpLogicalNot, .{
            .id_result_type = result_type_id,
            .id_result = result_id,
            .operand = operand_id,
        });
        return result_id.toRef();
    }

    fn extractField(self: *DeclGen, result_ty: IdResultType, object: IdRef, field: u32) !IdRef {
        const result_id = self.spv.allocId();
        try self.func.body.emit(self.spv.gpa, .OpCompositeExtract, .{
            .id_result_type = result_ty,
            .id_result = result_id,
            .composite = object,
            .indexes = &.{field},
        });
        return result_id.toRef();
    }

    fn airSliceField(self: *DeclGen, inst: Air.Inst.Index, field: u32) !?IdRef {
        if (self.liveness.isUnused(inst)) return null;
        const ty_op = self.air.instructions.items(.data)[inst].ty_op;
        return try self.extractField(
            try self.resolveTypeId(self.air.typeOfIndex(inst)),
            try self.resolve(ty_op.operand),
            field,
        );
    }

    fn airSliceElemPtr(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        const bin_op = self.air.instructions.items(.data)[inst].bin_op;
        const slice_ty = self.air.typeOf(bin_op.lhs);
        if (!slice_ty.isVolatilePtr() and self.liveness.isUnused(inst)) return null;

        const slice = try self.resolve(bin_op.lhs);
        const index = try self.resolve(bin_op.rhs);

        const spv_ptr_ty = try self.resolveTypeId(self.air.typeOfIndex(inst));

        const slice_ptr = blk: {
            const result_id = self.spv.allocId();
            try self.func.body.emit(self.spv.gpa, .OpCompositeExtract, .{
                .id_result_type = spv_ptr_ty,
                .id_result = result_id,
                .composite = slice,
                .indexes = &.{0},
            });
            break :blk result_id.toRef();
        };

        const result_id = self.spv.allocId();
        try self.func.body.emit(self.spv.gpa, .OpInBoundsAccessChain, .{
            .id_result_type = spv_ptr_ty,
            .id_result = result_id,
            .base = slice_ptr,
            .indexes = &.{index},
        });
        return result_id.toRef();
    }

    fn airSliceElemVal(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        const bin_op = self.air.instructions.items(.data)[inst].bin_op;
        const slice_ty = self.air.typeOf(bin_op.lhs);
        if (!slice_ty.isVolatilePtr() and self.liveness.isUnused(inst)) return null;

        const slice = try self.resolve(bin_op.lhs);
        const index = try self.resolve(bin_op.rhs);

        const spv_elem_ty = try self.resolveTypeId(self.air.typeOfIndex(inst));
        var slice_buf: Type.SlicePtrFieldTypeBuffer = undefined;
        const spv_ptr_ty = try self.resolveTypeId(slice_ty.slicePtrFieldType(&slice_buf));

        const slice_ptr = blk: {
            const result_id = self.spv.allocId();
            try self.func.body.emit(self.spv.gpa, .OpCompositeExtract, .{
                .id_result_type = spv_ptr_ty,
                .id_result = result_id,
                .composite = slice,
                .indexes = &.{0},
            });
            break :blk result_id.toRef();
        };

        const elem_ptr = blk: {
            const result_id = self.spv.allocId();
            try self.func.body.emit(self.spv.gpa, .OpInBoundsAccessChain, .{
                .id_result_type = spv_ptr_ty,
                .id_result = result_id,
                .base = slice_ptr,
                .indexes = &.{index},
            });
            break :blk result_id.toRef();
        };

        const result_id = self.spv.allocId();
        try self.func.body.emit(self.spv.gpa, .OpLoad, .{
            .id_result_type = spv_elem_ty,
            .id_result = result_id,
            .pointer = elem_ptr,
        });
        return result_id.toRef();
    }

    fn airPtrElemPtr(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        if (self.liveness.isUnused(inst)) return null;

        const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
        const bin_op = self.air.extraData(Air.Bin, ty_pl.payload).data;
        const ptr_ty = self.air.typeOf(bin_op.lhs);
        const result_ty = self.air.typeOfIndex(inst);
        const elem_ty = ptr_ty.childType();
        // TODO: Make this return a null ptr or something
        if (!elem_ty.hasRuntimeBitsIgnoreComptime()) return null;

        const result_type_id = try self.resolveTypeId(result_ty);
        const base_ptr = try self.resolve(bin_op.lhs);
        const rhs = try self.resolve(bin_op.rhs);

        const result_id = self.spv.allocId();
        try self.func.body.emit(self.spv.gpa, .OpInBoundsAccessChain, .{
            .id_result_type = result_type_id,
            .id_result = result_id,
            .base = base_ptr,
            .indexes = &.{rhs},
        });
        return result_id.toRef();
    }

    fn airStructFieldVal(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        if (self.liveness.isUnused(inst)) return null;

        const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
        const struct_field = self.air.extraData(Air.StructField, ty_pl.payload).data;

        const struct_ty = self.air.typeOf(struct_field.struct_operand);
        const object = try self.resolve(struct_field.struct_operand);
        const field_index = struct_field.field_index;
        const field_ty = struct_ty.structFieldType(field_index);
        const field_ty_id = try self.resolveTypeId(field_ty);

        if (!field_ty.hasRuntimeBitsIgnoreComptime()) return null;

        assert(struct_ty.zigTypeTag() == .Struct); // Cannot do unions yet.

        const result_id = self.spv.allocId();
        try self.func.body.emit(self.spv.gpa, .OpCompositeExtract, .{
            .id_result_type = field_ty_id,
            .id_result = result_id,
            .composite = object,
            .indexes = &.{field_index},
        });
        return result_id.toRef();
    }

    fn structFieldPtr(
        self: *DeclGen,
        result_ptr_ty: Type,
        object_ptr_ty: Type,
        object_ptr: IdRef,
        field_index: u32,
    ) !?IdRef {
        const object_ty = object_ptr_ty.childType();
        switch (object_ty.zigTypeTag()) {
            .Struct => switch (object_ty.containerLayout()) {
                .Packed => unreachable, // TODO
                else => {
                    const field_index_id = self.spv.allocId();
                    const u32_ty_id = self.spv.typeResultId(try self.intType(.unsigned, 32));
                    try self.func.body.emit(self.spv.gpa, .OpConstant, .{
                        .id_result_type = u32_ty_id,
                        .id_result = field_index_id,
                        .value = .{ .uint32 = field_index },
                    });
                    const result_id = self.spv.allocId();
                    const result_type_id = try self.resolveTypeId(result_ptr_ty);
                    try self.func.body.emit(self.spv.gpa, .OpInBoundsAccessChain, .{
                        .id_result_type = result_type_id,
                        .id_result = result_id,
                        .base = object_ptr,
                        .indexes = &.{field_index_id.toRef()},
                    });
                    return result_id.toRef();
                },
            },
            else => unreachable, // TODO
        }
    }

    fn airStructFieldPtrIndex(self: *DeclGen, inst: Air.Inst.Index, field_index: u32) !?IdRef {
        if (self.liveness.isUnused(inst)) return null;
        const ty_op = self.air.instructions.items(.data)[inst].ty_op;
        const struct_ptr = try self.resolve(ty_op.operand);
        const struct_ptr_ty = self.air.typeOf(ty_op.operand);
        const result_ptr_ty = self.air.typeOfIndex(inst);
        return try self.structFieldPtr(result_ptr_ty, struct_ptr_ty, struct_ptr, field_index);
    }

    fn airAlloc(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        if (self.liveness.isUnused(inst)) return null;
        const ty = self.air.typeOfIndex(inst);
        const result_type_id = try self.resolveTypeId(ty);
        const result_id = self.spv.allocId();

        // Rather than generating into code here, we're just going to generate directly into the functions section so that
        // variable declarations appear in the first block of the function.
        const storage_class = spirvStorageClass(ty.ptrAddressSpace());
        const section = if (storage_class == .Function or storage_class == .Generic)
            &self.func.prologue
        else
            &self.spv.sections.types_globals_constants;

        try section.emit(self.spv.gpa, .OpVariable, .{
            .id_result_type = result_type_id,
            .id_result = result_id,
            .storage_class = storage_class,
        });
        return result_id.toRef();
    }

    fn airArg(self: *DeclGen) IdRef {
        defer self.next_arg_index += 1;
        return self.args.items[self.next_arg_index];
    }

    fn airBlock(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        // In AIR, a block doesn't really define an entry point like a block, but more like a scope that breaks can jump out of and
        // "return" a value from. This cannot be directly modelled in SPIR-V, so in a block instruction, we're going to split up
        // the current block by first generating the code of the block, then a label, and then generate the rest of the current
        // ir.Block in a different SPIR-V block.

        const label_id = self.spv.allocId();

        // 4 chosen as arbitrary initial capacity.
        var incoming_blocks = try std.ArrayListUnmanaged(IncomingBlock).initCapacity(self.gpa, 4);

        try self.blocks.putNoClobber(self.gpa, inst, .{
            .label_id = label_id.toRef(),
            .incoming_blocks = &incoming_blocks,
        });
        defer {
            assert(self.blocks.remove(inst));
            incoming_blocks.deinit(self.gpa);
        }

        const ty = self.air.typeOfIndex(inst);
        const inst_datas = self.air.instructions.items(.data);
        const extra = self.air.extraData(Air.Block, inst_datas[inst].ty_pl.payload);
        const body = self.air.extra[extra.end..][0..extra.data.body_len];

        try self.genBody(body);
        try self.beginSpvBlock(label_id);

        // If this block didn't produce a value, simply return here.
        if (!ty.hasRuntimeBitsIgnoreComptime())
            return null;

        // Combine the result from the blocks using the Phi instruction.

        const result_id = self.spv.allocId();

        // TODO: OpPhi is limited in the types that it may produce, such as pointers. Figure out which other types
        // are not allowed to be created from a phi node, and throw an error for those.
        const result_type_id = try self.resolveTypeId(ty);
        _ = result_type_id;

        try self.func.body.emitRaw(self.spv.gpa, .OpPhi, 2 + @intCast(u16, incoming_blocks.items.len * 2)); // result type + result + variable/parent...

        for (incoming_blocks.items) |incoming| {
            self.func.body.writeOperand(spec.PairIdRefIdRef, .{ incoming.break_value_id, incoming.src_label_id });
        }

        return result_id.toRef();
    }

    fn airBr(self: *DeclGen, inst: Air.Inst.Index) !void {
        const br = self.air.instructions.items(.data)[inst].br;
        const block = self.blocks.get(br.block_inst).?;
        const operand_ty = self.air.typeOf(br.operand);

        if (operand_ty.hasRuntimeBits()) {
            const operand_id = try self.resolve(br.operand);
            // current_block_label_id should not be undefined here, lest there is a br or br_void in the function's body.
            try block.incoming_blocks.append(self.gpa, .{ .src_label_id = self.current_block_label_id, .break_value_id = operand_id });
        }

        try self.func.body.emit(self.spv.gpa, .OpBranch, .{ .target_label = block.label_id });
    }

    fn airCondBr(self: *DeclGen, inst: Air.Inst.Index) !void {
        const pl_op = self.air.instructions.items(.data)[inst].pl_op;
        const cond_br = self.air.extraData(Air.CondBr, pl_op.payload);
        const then_body = self.air.extra[cond_br.end..][0..cond_br.data.then_body_len];
        const else_body = self.air.extra[cond_br.end + then_body.len ..][0..cond_br.data.else_body_len];
        const condition_id = try self.resolve(pl_op.operand);

        // These will always generate a new SPIR-V block, since they are ir.Body and not ir.Block.
        const then_label_id = self.spv.allocId();
        const else_label_id = self.spv.allocId();

        // TODO: We can generate OpSelectionMerge here if we know the target block that both of these will resolve to,
        // but i don't know if those will always resolve to the same block.

        try self.func.body.emit(self.spv.gpa, .OpBranchConditional, .{
            .condition = condition_id,
            .true_label = then_label_id.toRef(),
            .false_label = else_label_id.toRef(),
        });

        try self.beginSpvBlock(then_label_id);
        try self.genBody(then_body);
        try self.beginSpvBlock(else_label_id);
        try self.genBody(else_body);
    }

    fn airDbgStmt(self: *DeclGen, inst: Air.Inst.Index) !void {
        const dbg_stmt = self.air.instructions.items(.data)[inst].dbg_stmt;
        const src_fname_id = try self.spv.resolveSourceFileName(self.module.declPtr(self.decl_index));
        try self.func.body.emit(self.spv.gpa, .OpLine, .{
            .file = src_fname_id,
            .line = dbg_stmt.line,
            .column = dbg_stmt.column,
        });
    }

    fn airLoad(self: *DeclGen, inst: Air.Inst.Index) !IdRef {
        const ty_op = self.air.instructions.items(.data)[inst].ty_op;
        const operand_id = try self.resolve(ty_op.operand);
        const ty = self.air.typeOfIndex(inst);

        const result_type_id = try self.resolveTypeId(ty);
        const result_id = self.spv.allocId();

        const access = spec.MemoryAccess.Extended{
            .Volatile = ty.isVolatilePtr(),
        };

        try self.func.body.emit(self.spv.gpa, .OpLoad, .{
            .id_result_type = result_type_id,
            .id_result = result_id,
            .pointer = operand_id,
            .memory_access = access,
        });

        return result_id.toRef();
    }

    fn airLoop(self: *DeclGen, inst: Air.Inst.Index) !void {
        const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
        const loop = self.air.extraData(Air.Block, ty_pl.payload);
        const body = self.air.extra[loop.end..][0..loop.data.body_len];
        const loop_label_id = self.spv.allocId();

        // Jump to the loop entry point
        try self.func.body.emit(self.spv.gpa, .OpBranch, .{ .target_label = loop_label_id.toRef() });

        // TODO: Look into OpLoopMerge.
        try self.beginSpvBlock(loop_label_id);
        try self.genBody(body);

        try self.func.body.emit(self.spv.gpa, .OpBranch, .{ .target_label = loop_label_id.toRef() });
    }

    fn airRet(self: *DeclGen, inst: Air.Inst.Index) !void {
        if (self.liveness.isUnused(inst)) return;
        const operand = self.air.instructions.items(.data)[inst].un_op;
        const operand_ty = self.air.typeOf(operand);
        if (operand_ty.hasRuntimeBits()) {
            const operand_id = try self.resolve(operand);
            try self.func.body.emit(self.spv.gpa, .OpReturnValue, .{ .value = operand_id });
        } else {
            try self.func.body.emit(self.spv.gpa, .OpReturn, {});
        }
    }

    fn airRetLoad(self: *DeclGen, inst: Air.Inst.Index) !void {
        const un_op = self.air.instructions.items(.data)[inst].un_op;
        const ptr_ty = self.air.typeOf(un_op);
        const ret_ty = ptr_ty.childType();
        const ret_ty_id = try self.resolveTypeId(ret_ty);

        if (!ret_ty.hasRuntimeBitsIgnoreComptime()) {
            try self.func.body.emit(self.spv.gpa, .OpReturn, {});
            return;
        }

        const ptr = try self.resolve(un_op);
        const result_id = self.spv.allocId();
        try self.func.body.emit(self.spv.gpa, .OpLoad, .{
            .id_result_type = ret_ty_id,
            .id_result = result_id,
            .pointer = ptr,
        });
        try self.func.body.emit(self.spv.gpa, .OpReturnValue, .{ .value = result_id.toRef() });
    }

    fn airStore(self: *DeclGen, inst: Air.Inst.Index) !void {
        const bin_op = self.air.instructions.items(.data)[inst].bin_op;
        const dst_ptr_id = try self.resolve(bin_op.lhs);
        const src_val_id = try self.resolve(bin_op.rhs);
        const lhs_ty = self.air.typeOf(bin_op.lhs);

        const access = spec.MemoryAccess.Extended{
            .Volatile = lhs_ty.isVolatilePtr(),
        };

        try self.func.body.emit(self.spv.gpa, .OpStore, .{
            .pointer = dst_ptr_id,
            .object = src_val_id,
            .memory_access = access,
        });
    }

    fn airUnreach(self: *DeclGen) !void {
        try self.func.body.emit(self.spv.gpa, .OpUnreachable, {});
    }

    fn airAssembly(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
        const extra = self.air.extraData(Air.Asm, ty_pl.payload);

        const is_volatile = @truncate(u1, extra.data.flags >> 31) != 0;
        const clobbers_len = @truncate(u31, extra.data.flags);

        if (!is_volatile and self.liveness.isUnused(inst)) return null;

        var extra_i: usize = extra.end;
        const outputs = @ptrCast([]const Air.Inst.Ref, self.air.extra[extra_i..][0..extra.data.outputs_len]);
        extra_i += outputs.len;
        const inputs = @ptrCast([]const Air.Inst.Ref, self.air.extra[extra_i..][0..extra.data.inputs_len]);
        extra_i += inputs.len;

        if (outputs.len > 1) {
            return self.todo("implement inline asm with more than 1 output", .{});
        }

        var output_extra_i = extra_i;
        for (outputs) |output| {
            if (output != .none) {
                return self.todo("implement inline asm with non-returned output", .{});
            }
            const extra_bytes = std.mem.sliceAsBytes(self.air.extra[extra_i..]);
            const constraint = std.mem.sliceTo(std.mem.sliceAsBytes(self.air.extra[extra_i..]), 0);
            const name = std.mem.sliceTo(extra_bytes[constraint.len + 1 ..], 0);
            extra_i += (constraint.len + name.len + (2 + 3)) / 4;
            // TODO: Record output and use it somewhere.
        }

        var input_extra_i = extra_i;
        for (inputs) |input| {
            const extra_bytes = std.mem.sliceAsBytes(self.air.extra[extra_i..]);
            const constraint = std.mem.sliceTo(extra_bytes, 0);
            const name = std.mem.sliceTo(extra_bytes[constraint.len + 1 ..], 0);
            // This equation accounts for the fact that even if we have exactly 4 bytes
            // for the string, we still use the next u32 for the null terminator.
            extra_i += (constraint.len + name.len + (2 + 3)) / 4;
            // TODO: Record input and use it somewhere.
            _ = input;
        }

        {
            var clobber_i: u32 = 0;
            while (clobber_i < clobbers_len) : (clobber_i += 1) {
                const clobber = std.mem.sliceTo(std.mem.sliceAsBytes(self.air.extra[extra_i..]), 0);
                extra_i += clobber.len / 4 + 1;
                // TODO: Record clobber and use it somewhere.
            }
        }

        const asm_source = std.mem.sliceAsBytes(self.air.extra[extra_i..])[0..extra.data.source_len];

        var as = SpvAssembler{
            .gpa = self.gpa,
            .src = asm_source,
            .spv = self.spv,
            .func = &self.func,
        };
        defer as.deinit();

        for (inputs) |input| {
            const extra_bytes = std.mem.sliceAsBytes(self.air.extra[input_extra_i..]);
            const constraint = std.mem.sliceTo(extra_bytes, 0);
            const name = std.mem.sliceTo(extra_bytes[constraint.len + 1 ..], 0);
            // This equation accounts for the fact that even if we have exactly 4 bytes
            // for the string, we still use the next u32 for the null terminator.
            input_extra_i += (constraint.len + name.len + (2 + 3)) / 4;

            const value = try self.resolve(input);
            try as.value_map.put(as.gpa, name, .{ .value = value });
        }

        as.assemble() catch |err| switch (err) {
            error.AssembleFail => {
                // TODO: For now the compiler only supports a single error message per decl,
                // so to translate the possible multiple errors from the assembler, emit
                // them as notes here.
                // TODO: Translate proper error locations.
                assert(as.errors.items.len != 0);
                assert(self.error_msg == null);
                const loc = LazySrcLoc.nodeOffset(0);
                const src_loc = loc.toSrcLoc(self.module.declPtr(self.decl_index));
                self.error_msg = try Module.ErrorMsg.create(self.module.gpa, src_loc, "failed to assemble SPIR-V inline assembly", .{});
                const notes = try self.module.gpa.alloc(Module.ErrorMsg, as.errors.items.len);

                // Sub-scope to prevent `return error.CodegenFail` from running the errdefers.
                {
                    errdefer self.module.gpa.free(notes);
                    var i: usize = 0;
                    errdefer for (notes[0..i]) |*note| {
                        note.deinit(self.module.gpa);
                    };

                    while (i < as.errors.items.len) : (i += 1) {
                        notes[i] = try Module.ErrorMsg.init(self.module.gpa, src_loc, "{s}", .{as.errors.items[i].msg});
                    }
                }
                self.error_msg.?.notes = notes;
                return error.CodegenFail;
            },
            else => |others| return others,
        };

        for (outputs) |output| {
            _ = output;
            const extra_bytes = std.mem.sliceAsBytes(self.air.extra[output_extra_i..]);
            const constraint = std.mem.sliceTo(std.mem.sliceAsBytes(self.air.extra[output_extra_i..]), 0);
            const name = std.mem.sliceTo(extra_bytes[constraint.len + 1 ..], 0);
            output_extra_i += (constraint.len + name.len + (2 + 3)) / 4;

            const result = as.value_map.get(name) orelse return {
                return self.fail("invalid asm output '{s}'", .{name});
            };

            switch (result) {
                .just_declared, .unresolved_forward_reference => unreachable,
                .ty => return self.fail("cannot return spir-v type as value from assembly", .{}),
                .value => |ref| return ref,
            }

            // TODO: Multiple results
        }

        return null;
    }

    fn airCall(self: *DeclGen, inst: Air.Inst.Index, modifier: std.builtin.CallOptions.Modifier) !?IdRef {
        _ = modifier;

        const pl_op = self.air.instructions.items(.data)[inst].pl_op;
        const extra = self.air.extraData(Air.Call, pl_op.payload);
        const args = @ptrCast([]const Air.Inst.Ref, self.air.extra[extra.end..][0..extra.data.args_len]);
        const callee_ty = self.air.typeOf(pl_op.operand);
        const zig_fn_ty = switch (callee_ty.zigTypeTag()) {
            .Fn => callee_ty,
            .Pointer => return self.fail("cannot call function pointers", .{}),
            else => unreachable,
        };
        const fn_info = zig_fn_ty.fnInfo();
        const return_type = fn_info.return_type;

        const result_type_id = try self.resolveTypeId(return_type);
        const result_id = self.spv.allocId();
        const callee_id = try self.resolve(pl_op.operand);

        try self.func.body.emitRaw(self.spv.gpa, .OpFunctionCall, 3 + args.len);
        self.func.body.writeOperand(spec.IdResultType, result_type_id);
        self.func.body.writeOperand(spec.IdResult, result_id);
        self.func.body.writeOperand(spec.IdRef, callee_id);

        for (args) |arg| {
            const arg_id = try self.resolve(arg);
            const arg_ty = self.air.typeOf(arg);
            if (!arg_ty.hasRuntimeBitsIgnoreComptime()) continue;

            self.func.body.writeOperand(spec.IdRef, arg_id);
        }

        if (return_type.isNoReturn()) {
            try self.func.body.emit(self.spv.gpa, .OpUnreachable, {});
        }

        if (self.liveness.isUnused(inst) or !return_type.hasRuntimeBitsIgnoreComptime()) {
            return null;
        }

        return result_id.toRef();
    }
};
