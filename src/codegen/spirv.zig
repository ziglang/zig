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
const StorageClass = spec.StorageClass;

const SpvModule = @import("spirv/Module.zig");
const SpvSection = @import("spirv/Section.zig");
const SpvType = @import("spirv/type.zig").Type;
const SpvAssembler = @import("spirv/Assembler.zig");

const InstMap = std.AutoHashMapUnmanaged(Air.Inst.Index, IdRef);

const IncomingBlock = struct {
    src_label_id: IdRef,
    break_value_id: IdRef,
};

const BlockMap = std.AutoHashMapUnmanaged(Air.Inst.Index, struct {
    label_id: IdRef,
    incoming_blocks: *std.ArrayListUnmanaged(IncomingBlock),
});

/// Maps Zig decl indices to linking SPIR-V linking information.
pub const DeclLinkMap = std.AutoHashMap(Module.Decl.Index, SpvModule.Decl.Index);

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

    /// Maps Zig Decl indices to SPIR-V globals.
    decl_link: *DeclLinkMap,

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

    /// Data can be lowered into in two basic representations: indirect, which is when
    /// a type is stored in memory, and direct, which is how a type is stored when its
    /// a direct SPIR-V value.
    const Repr = enum {
        /// A SPIR-V value as it would be used in operations.
        direct,
        /// A SPIR-V value as it is stored in memory.
        indirect,
    };

    /// Initialize the common resources of a DeclGen. Some fields are left uninitialized,
    /// only set when `gen` is called.
    pub fn init(
        allocator: Allocator,
        module: *Module,
        spv: *SpvModule,
        decl_link: *DeclLinkMap,
    ) DeclGen {
        return .{
            .gpa = allocator,
            .module = module,
            .spv = spv,
            .decl_index = undefined,
            .air = undefined,
            .liveness = undefined,
            .decl_link = decl_link,
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
            const ty = self.air.typeOf(inst);
            if (ty.zigTypeTag() == .Fn) {
                const fn_decl_index = switch (val.tag()) {
                    .extern_fn => val.castTag(.extern_fn).?.data.owner_decl,
                    .function => val.castTag(.function).?.data.owner_decl,
                    else => unreachable,
                };
                const spv_decl_index = try self.resolveDecl(fn_decl_index);
                return self.spv.declPtr(spv_decl_index).result_id;
            }

            return try self.constant(ty, val);
        }
        const index = Air.refToIndex(inst).?;
        return self.inst_results.get(index).?; // Assertion means instruction does not dominate usage.
    }

    /// Fetch or allocate a result id for decl index. This function also marks the decl as alive.
    /// Note: Function does not actually generate the decl.
    fn resolveDecl(self: *DeclGen, decl_index: Module.Decl.Index) !SpvModule.Decl.Index {
        const decl = self.module.declPtr(decl_index);
        self.module.markDeclAlive(decl);

        const entry = try self.decl_link.getOrPut(decl_index);
        if (!entry.found_existing) {
            // TODO: Extern fn?
            const kind: SpvModule.DeclKind = if (decl.val.tag() == .function)
                .func
            else
                .global;

            entry.value_ptr.* = try self.spv.allocDecl(kind);
        }

        return entry.value_ptr.*;
    }

    /// Start a new SPIR-V block, Emits the label of the new block, and stores which
    /// block we are currently generating.
    /// Note that there is no such thing as nested blocks like in ZIR or AIR, so we don't need to
    /// keep track of the previous block.
    fn beginSpvBlock(self: *DeclGen, label_id: IdResult) !void {
        try self.func.body.emit(self.spv.gpa, .OpLabel, .{ .id_result = label_id });
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
            else => self.todo("implement arithmeticTypeInfo for {}", .{ty.fmt(self.module)}),
        };
    }

    fn genConstInt(self: *DeclGen, ty_ref: SpvType.Ref, result_id: IdRef, value: anytype) !void {
        const ty = self.spv.typeRefType(ty_ref);
        const ty_id = self.typeId(ty_ref);

        const Lit = spec.LiteralContextDependentNumber;
        const literal = switch (ty.intSignedness()) {
            .signed => switch (ty.intFloatBits()) {
                1...32 => Lit{ .int32 = @intCast(i32, value) },
                33...64 => Lit{ .int64 = @intCast(i64, value) },
                else => unreachable, // TODO: composite integer literals
            },
            .unsigned => switch (ty.intFloatBits()) {
                1...32 => Lit{ .uint32 = @intCast(u32, value) },
                33...64 => Lit{ .uint64 = @intCast(u64, value) },
                else => unreachable,
            },
        };

        try self.spv.emitConstant(ty_id, result_id, literal);
    }

    fn constInt(self: *DeclGen, ty_ref: SpvType.Ref, value: anytype) !IdRef {
        const result_id = self.spv.allocId();
        try self.genConstInt(ty_ref, result_id, value);
        return result_id;
    }

    fn genUndef(self: *DeclGen, ty_ref: SpvType.Ref) Error!IdRef {
        const result_id = self.spv.allocId();
        try self.spv.sections.types_globals_constants.emit(self.spv.gpa, .OpUndef, .{ .id_result_type = self.typeId(ty_ref), .id_result = result_id });
        return result_id;
    }

    const IndirectConstantLowering = struct {
        const undef = 0xAA;

        dg: *DeclGen,
        /// Cached reference of the u32 type.
        u32_ty_ref: SpvType.Ref,
        /// Cached type id of the u32 type.
        u32_ty_id: IdRef,
        /// The members of the resulting structure type
        members: std.ArrayList(SpvType.Payload.Struct.Member),
        /// The initializers of each of the members.
        initializers: std.ArrayList(IdRef),
        /// The current size of the structure. Includes
        /// the bytes in partial_word.
        size: u32 = 0,
        /// The partially filled last constant.
        /// If full, its flushed.
        partial_word: std.BoundedArray(u8, @sizeOf(Word)) = .{},
        /// The declaration dependencies of the constant we are lowering.
        decl_deps: std.ArrayList(SpvModule.Decl.Index),

        /// Utility function to get the section that instructions should be lowered to.
        fn section(self: *@This()) *SpvSection {
            return &self.dg.spv.globals.section;
        }

        /// Flush the partial_word to the members. If the partial_word is not
        /// filled, this adds padding bytes (which are undefined).
        fn flush(self: *@This()) !void {
            if (self.partial_word.len == 0) {
                // No need to add it there.
                return;
            }

            for (self.partial_word.unusedCapacitySlice()) |*unused| {
                // TODO: Perhaps we should generate OpUndef for these bytes?
                unused.* = undef;
            }

            const word = @bitCast(Word, self.partial_word.buffer);
            const result_id = self.dg.spv.allocId();
            // TODO: Integrate with caching mechanism
            try self.dg.spv.emitConstant(self.u32_ty_id, result_id, .{ .uint32 = word });
            try self.members.append(.{ .ty = self.u32_ty_ref });
            try self.initializers.append(result_id);

            self.partial_word.len = 0;
            self.size = std.mem.alignForwardGeneric(u32, self.size, @sizeOf(Word));
        }

        /// Fill the buffer with undefined values until the size is aligned to `align`.
        fn fillToAlign(self: *@This(), alignment: u32) !void {
            const target_size = std.mem.alignForwardGeneric(u32, self.size, alignment);
            try self.addUndef(target_size - self.size);
        }

        fn addUndef(self: *@This(), amt: u64) !void {
            for (0..@intCast(usize, amt)) |_| {
                try self.addByte(undef);
            }
        }

        /// Add a single byte of data to the constant.
        fn addByte(self: *@This(), data: u8) !void {
            self.partial_word.append(data) catch {
                try self.flush();
                self.partial_word.append(data) catch unreachable;
            };
            self.size += 1;
        }

        /// Add many bytes of data to the constnat.
        fn addBytes(self: *@This(), data: []const u8) !void {
            // TODO: Improve performance by adding in bulk, or something?
            for (data) |byte| {
                try self.addByte(byte);
            }
        }

        fn addPtr(self: *@This(), ptr_ty_ref: SpvType.Ref, ptr_id: IdRef) !void {
            // TODO: Double check pointer sizes here.
            // shared pointers might be u32...
            const target = self.dg.getTarget();
            const width = @divExact(target.cpu.arch.ptrBitWidth(), 8);
            if (self.size % width != 0) {
                return self.dg.todo("misaligned pointer constants", .{});
            }
            try self.members.append(.{ .ty = ptr_ty_ref });
            try self.initializers.append(ptr_id);
            self.size += width;
        }

        fn addNullPtr(self: *@This(), ptr_ty_ref: SpvType.Ref) !void {
            const result_id = self.dg.spv.allocId();
            try self.dg.spv.sections.types_globals_constants.emit(self.dg.spv.gpa, .OpConstantNull, .{
                .id_result_type = self.dg.typeId(ptr_ty_ref),
                .id_result = result_id,
            });
            try self.addPtr(ptr_ty_ref, result_id);
        }

        fn addConstInt(self: *@This(), comptime T: type, value: T) !void {
            if (@bitSizeOf(T) % 8 != 0) {
                @compileError("todo: non byte aligned int constants");
            }

            // TODO: Swap endianness if the compiler is big endian.
            try self.addBytes(std.mem.asBytes(&value));
        }

        fn addConstBool(self: *@This(), value: bool) !void {
            try self.addByte(@boolToInt(value)); // TODO: Keep in sync with something?
        }

        fn addInt(self: *@This(), ty: Type, val: Value) !void {
            const target = self.dg.getTarget();
            const int_info = ty.intInfo(target);
            const int_bits = switch (int_info.signedness) {
                .signed => @bitCast(u64, val.toSignedInt(target)),
                .unsigned => val.toUnsignedInt(target),
            };

            // TODO: Swap endianess if the compiler is big endian.
            const len = ty.abiSize(target);
            try self.addBytes(std.mem.asBytes(&int_bits)[0..@intCast(usize, len)]);
        }

        fn addDeclRef(self: *@This(), ty: Type, decl_index: Decl.Index) !void {
            const dg = self.dg;

            const ty_ref = try self.dg.resolveType(ty, .indirect);
            const ty_id = dg.typeId(ty_ref);

            const decl = dg.module.declPtr(decl_index);
            const spv_decl_index = try dg.resolveDecl(decl_index);

            switch (decl.val.tag()) {
                .function => {
                    // TODO: Properly lower function pointers. For now we are going to hack around it and
                    // just generate an empty pointer. Function pointers are represented by usize for now,
                    // though.
                    try self.addInt(Type.usize, Value.initTag(.zero));
                    return;
                },
                .extern_fn => unreachable, // TODO
                else => {
                    const result_id = dg.spv.allocId();
                    log.debug("addDeclRef {s} = {}", .{ decl.name, result_id.id });

                    try self.decl_deps.append(spv_decl_index);

                    const decl_id = dg.spv.declPtr(spv_decl_index).result_id;
                    // TODO: Do we need a storage class cast here?
                    // TODO: We can probably eliminate these casts
                    try dg.spv.globals.section.emitSpecConstantOp(dg.spv.gpa, .OpBitcast, .{
                        .id_result_type = ty_id,
                        .id_result = result_id,
                        .operand = decl_id,
                    });

                    try self.addPtr(ty_ref, result_id);
                },
            }
        }

        fn lower(self: *@This(), ty: Type, val: Value) !void {
            const target = self.dg.getTarget();
            const dg = self.dg;

            if (val.isUndef()) {
                const size = ty.abiSize(target);
                return try self.addUndef(size);
            }

            switch (ty.zigTypeTag()) {
                .Int => try self.addInt(ty, val),
                .Bool => try self.addConstBool(val.toBool()),
                .Array => switch (val.tag()) {
                    .aggregate => {
                        const elem_vals = val.castTag(.aggregate).?.data;
                        const elem_ty = ty.elemType();
                        const len = @intCast(u32, ty.arrayLenIncludingSentinel()); // TODO: limit spir-v to 32 bit arrays in a more elegant way.
                        for (elem_vals[0..len]) |elem_val| {
                            try self.lower(elem_ty, elem_val);
                        }
                    },
                    .repeated => {
                        const elem_val = val.castTag(.repeated).?.data;
                        const elem_ty = ty.elemType();
                        const len = @intCast(u32, ty.arrayLen());
                        for (0..len) |_| {
                            try self.lower(elem_ty, elem_val);
                        }
                        if (ty.sentinel()) |sentinel| {
                            try self.lower(elem_ty, sentinel);
                        }
                    },
                    .str_lit => {
                        const str_lit = val.castTag(.str_lit).?.data;
                        const bytes = dg.module.string_literal_bytes.items[str_lit.index..][0..str_lit.len];
                        try self.addBytes(bytes);
                        if (ty.sentinel()) |sentinel| {
                            try self.addByte(@intCast(u8, sentinel.toUnsignedInt(target)));
                        }
                    },
                    .bytes => {
                        const bytes = val.castTag(.bytes).?.data;
                        try self.addBytes(bytes);
                    },
                    else => |tag| return dg.todo("indirect array constant with tag {s}", .{@tagName(tag)}),
                },
                .Pointer => switch (val.tag()) {
                    .decl_ref_mut => {
                        const decl_index = val.castTag(.decl_ref_mut).?.data.decl_index;
                        try self.addDeclRef(ty, decl_index);
                    },
                    .decl_ref => {
                        const decl_index = val.castTag(.decl_ref).?.data;
                        try self.addDeclRef(ty, decl_index);
                    },
                    .slice => {
                        const slice = val.castTag(.slice).?.data;

                        var buf: Type.SlicePtrFieldTypeBuffer = undefined;
                        const ptr_ty = ty.slicePtrFieldType(&buf);

                        try self.lower(ptr_ty, slice.ptr);
                        try self.addInt(Type.usize, slice.len);
                    },
                    else => |tag| return dg.todo("pointer value of type {s}", .{@tagName(tag)}),
                },
                .Struct => {
                    if (ty.isSimpleTupleOrAnonStruct()) {
                        unreachable; // TODO
                    } else {
                        const struct_ty = ty.castTag(.@"struct").?.data;

                        if (struct_ty.layout == .Packed) {
                            return dg.todo("packed struct constants", .{});
                        }

                        const struct_begin = self.size;
                        const field_vals = val.castTag(.aggregate).?.data;
                        for (struct_ty.fields.values(), 0..) |field, i| {
                            if (field.is_comptime or !field.ty.hasRuntimeBits()) continue;
                            try self.lower(field.ty, field_vals[i]);

                            // Add padding if required.
                            // TODO: Add to type generation as well?
                            const unpadded_field_end = self.size - struct_begin;
                            const padded_field_end = ty.structFieldOffset(i + 1, target);
                            const padding = padded_field_end - unpadded_field_end;
                            try self.addUndef(padding);
                        }
                    }
                },
                .Optional => {
                    var opt_buf: Type.Payload.ElemType = undefined;
                    const payload_ty = ty.optionalChild(&opt_buf);
                    const has_payload = !val.isNull();
                    const abi_size = ty.abiSize(target);

                    if (!payload_ty.hasRuntimeBits()) {
                        try self.addConstBool(has_payload);
                        return;
                    } else if (ty.optionalReprIsPayload()) {
                        // Optional representation is a nullable pointer.
                        if (val.castTag(.opt_payload)) |payload| {
                            try self.lower(payload_ty, payload.data);
                        } else if (has_payload) {
                            try self.lower(payload_ty, val);
                        } else {
                            const ptr_ty_ref = try dg.resolveType(ty, .indirect);
                            try self.addNullPtr(ptr_ty_ref);
                        }
                        return;
                    }

                    // Optional representation is a structure.
                    // { Payload, Bool }

                    // Subtract 1 for @sizeOf(bool).
                    // TODO: Make this not hardcoded.
                    const payload_size = payload_ty.abiSize(target);
                    const padding = abi_size - payload_size - 1;

                    if (val.castTag(.opt_payload)) |payload| {
                        try self.lower(payload_ty, payload.data);
                    } else {
                        try self.addUndef(payload_size);
                    }
                    try self.addConstBool(has_payload);
                    try self.addUndef(padding);
                },
                .Enum => {
                    var int_val_buffer: Value.Payload.U64 = undefined;
                    const int_val = val.enumToInt(ty, &int_val_buffer);

                    var int_ty_buffer: Type.Payload.Bits = undefined;
                    const int_ty = ty.intTagType(&int_ty_buffer);

                    try self.lower(int_ty, int_val);
                },
                .Union => {
                    const tag_and_val = val.castTag(.@"union").?.data;
                    const layout = ty.unionGetLayout(target);

                    if (layout.payload_size == 0) {
                        return try self.lower(ty.unionTagTypeSafety().?, tag_and_val.tag);
                    }

                    const union_ty = ty.cast(Type.Payload.Union).?.data;
                    if (union_ty.layout == .Packed) {
                        return dg.todo("packed union constants", .{});
                    }

                    const active_field = ty.unionTagFieldIndex(tag_and_val.tag, dg.module).?;
                    const active_field_ty = union_ty.fields.values()[active_field].ty;

                    const has_tag = layout.tag_size != 0;
                    const tag_first = layout.tag_align >= layout.payload_align;

                    if (has_tag and tag_first) {
                        try self.lower(ty.unionTagTypeSafety().?, tag_and_val.tag);
                    }

                    const active_field_size = if (active_field_ty.hasRuntimeBitsIgnoreComptime()) blk: {
                        try self.lower(active_field_ty, tag_and_val.val);
                        break :blk active_field_ty.abiSize(target);
                    } else 0;

                    const payload_padding_len = layout.payload_size - active_field_size;
                    try self.addUndef(payload_padding_len);

                    if (has_tag and !tag_first) {
                        try self.lower(ty.unionTagTypeSafety().?, tag_and_val.tag);
                    }

                    try self.addUndef(layout.padding);
                },
                .ErrorSet => switch (val.tag()) {
                    .@"error" => {
                        const err_name = val.castTag(.@"error").?.data.name;
                        const kv = try dg.module.getErrorValue(err_name);
                        try self.addConstInt(u16, @intCast(u16, kv.value));
                    },
                    .zero => {
                        // Unactivated error set.
                        try self.addConstInt(u16, 0);
                    },
                    else => unreachable,
                },
                .ErrorUnion => {
                    const payload_ty = ty.errorUnionPayload();
                    const is_pl = val.errorUnionIsPayload();
                    const error_val = if (!is_pl) val else Value.initTag(.zero);

                    if (!payload_ty.hasRuntimeBitsIgnoreComptime()) {
                        return try self.lower(Type.anyerror, error_val);
                    }

                    const payload_align = payload_ty.abiAlignment(target);
                    const error_align = Type.anyerror.abiAlignment(target);

                    const payload_size = payload_ty.abiSize(target);
                    const error_size = Type.anyerror.abiAlignment(target);
                    const ty_size = ty.abiSize(target);
                    const padding = ty_size - payload_size - error_size;

                    const payload_val = if (val.castTag(.eu_payload)) |pl| pl.data else Value.initTag(.undef);

                    if (error_align > payload_align) {
                        try self.lower(Type.anyerror, error_val);
                        try self.lower(payload_ty, payload_val);
                    } else {
                        try self.lower(payload_ty, payload_val);
                        try self.lower(Type.anyerror, error_val);
                    }

                    try self.addUndef(padding);
                },
                else => |tag| return dg.todo("indirect constant of type {s}", .{@tagName(tag)}),
            }
        }
    };

    /// Returns a pointer to `val`. The value is placed directly
    /// into the storage class `storage_class`, and this is also where the resulting
    /// pointer points to. Note: result is not necessarily an OpVariable instruction!
    fn lowerIndirectConstant(
        self: *DeclGen,
        spv_decl_index: SpvModule.Decl.Index,
        ty: Type,
        val: Value,
        storage_class: StorageClass,
        cast_to_generic: bool,
        alignment: u32,
    ) Error!void {
        // To simplify constant generation, we're going to generate constants as a word-array, and
        // pointer cast the result to the right type.
        // This means that the final constant will be generated as follows:
        //   %T = OpTypeStruct %members...
        //   %P = OpTypePointer %T
        //   %U = OpTypePointer %ty
        //   %1 = OpConstantComposite %T %initializers...
        //   %2 = OpVariable %P %1
        //   %result_id = OpSpecConstantOp OpBitcast %U %2
        //
        // The members consist of two options:
        // - Literal values: ints, strings, etc. These are generated as u32 words.
        // - Relocations, such as pointers: These are generated by embedding the pointer into the
        //   to-be-generated structure. There are two options here, depending on the alignment of the
        //   pointer value itself (not the alignment of the pointee).
        //   - Natively or over-aligned values. These can just be generated directly.
        //   - Underaligned pointers. These need to be packed into the word array by using a mixture of
        //     OpSpecConstantOp instructions such as OpConvertPtrToU, OpBitcast, OpShift, etc.

        // TODO: Implement alignment here.
        //   This is hoing to require some hacks because there is no real way to
        //   set an OpVariable's alignment.
        _ = alignment;

        assert(storage_class != .Generic and storage_class != .Function);

        log.debug("lowerIndirectConstant: ty = {}, val = {}", .{ ty.fmt(self.module), val.fmtDebug() });

        const section = &self.spv.globals.section;

        const ty_ref = try self.resolveType(ty, .indirect);
        const ptr_ty_ref = try self.spv.ptrType(ty_ref, storage_class, 0);

        // const target = self.getTarget();

        // TODO: Fix the resulting global linking for these paths.
        // if (val.isUndef()) {
        //     // Special case: the entire value is undefined. In this case, we can just
        //     // generate an OpVariable with no initializer.
        //     return try section.emit(self.spv.gpa, .OpVariable, .{
        //         .id_result_type = self.typeId(ptr_ty_ref),
        //         .id_result = result_id,
        //         .storage_class = storage_class,
        //     });
        // } else if (ty.abiSize(target) == 0) {
        //     // Special case: if the type has no size, then return an undefined pointer.
        //     return try section.emit(self.spv.gpa, .OpUndef, .{
        //         .id_result_type = self.typeId(ptr_ty_ref),
        //         .id_result = result_id,
        //     });
        // }

        // TODO: Capture the above stuff in here as well...
        const begin_inst = self.spv.beginGlobal();

        const u32_ty_ref = try self.intType(.unsigned, 32);
        var icl = IndirectConstantLowering{
            .dg = self,
            .u32_ty_ref = u32_ty_ref,
            .u32_ty_id = self.typeId(u32_ty_ref),
            .members = std.ArrayList(SpvType.Payload.Struct.Member).init(self.gpa),
            .initializers = std.ArrayList(IdRef).init(self.gpa),
            .decl_deps = std.ArrayList(SpvModule.Decl.Index).init(self.gpa),
        };

        defer icl.members.deinit();
        defer icl.initializers.deinit();
        defer icl.decl_deps.deinit();

        try icl.lower(ty, val);
        try icl.flush();

        const constant_struct_ty_ref = try self.spv.simpleStructType(icl.members.items);
        const ptr_constant_struct_ty_ref = try self.spv.ptrType(constant_struct_ty_ref, storage_class, 0);

        const constant_struct_id = self.spv.allocId();
        try section.emit(self.spv.gpa, .OpSpecConstantComposite, .{
            .id_result_type = self.typeId(constant_struct_ty_ref),
            .id_result = constant_struct_id,
            .constituents = icl.initializers.items,
        });

        const var_id = self.spv.allocId();
        self.spv.globalPtr(spv_decl_index).?.result_id = var_id;
        try section.emit(self.spv.gpa, .OpVariable, .{
            .id_result_type = self.typeId(ptr_constant_struct_ty_ref),
            .id_result = var_id,
            .storage_class = storage_class,
            .initializer = constant_struct_id,
        });
        // TODO: Set alignment of OpVariable.
        // TODO: We may be able to eliminate these casts.

        const const_ptr_id = try self.makePointerConstant(section, ptr_constant_struct_ty_ref, var_id);
        const result_id = self.spv.declPtr(spv_decl_index).result_id;

        const bitcast_result_id = if (cast_to_generic)
            self.spv.allocId()
        else
            result_id;

        try section.emitSpecConstantOp(self.spv.gpa, .OpBitcast, .{
            .id_result_type = self.typeId(ptr_ty_ref),
            .id_result = bitcast_result_id,
            .operand = const_ptr_id,
        });

        if (cast_to_generic) {
            const generic_ptr_ty_ref = try self.spv.ptrType(ty_ref, .Generic, 0);
            try section.emitSpecConstantOp(self.spv.gpa, .OpPtrCastToGeneric, .{
                .id_result_type = self.typeId(generic_ptr_ty_ref),
                .id_result = result_id,
                .pointer = bitcast_result_id,
            });
        }

        try self.spv.declareDeclDeps(spv_decl_index, icl.decl_deps.items);
        self.spv.endGlobal(spv_decl_index, begin_inst);
    }

    /// This function generates a load for a constant in direct (ie, non-memory) representation.
    /// When the constant is simple, it can be generated directly using OpConstant instructions. When
    /// the constant is more complicated however, it needs to be lowered to an indirect constant, which
    /// is then loaded using OpLoad. Such values are loaded into the UniformConstant storage class by default.
    /// This function should only be called during function code generation.
    fn constant(self: *DeclGen, ty: Type, val: Value) !IdRef {
        const target = self.getTarget();
        const section = &self.spv.sections.types_globals_constants;
        const result_ty_ref = try self.resolveType(ty, .direct);
        const result_ty_id = self.typeId(result_ty_ref);
        const result_id = self.spv.allocId();

        if (val.isUndef()) {
            try section.emit(self.spv.gpa, .OpUndef, .{
                .id_result_type = result_ty_id,
                .id_result = result_id,
            });
            return result_id;
        }

        switch (ty.zigTypeTag()) {
            .Int => {
                const int_bits = if (ty.isSignedInt())
                    @bitCast(u64, val.toSignedInt(target))
                else
                    val.toUnsignedInt(target);
                try self.genConstInt(result_ty_ref, result_id, int_bits);
            },
            .Bool => {
                const operands = .{ .id_result_type = result_ty_id, .id_result = result_id };
                if (val.toBool()) {
                    try section.emit(self.spv.gpa, .OpConstantTrue, operands);
                } else {
                    try section.emit(self.spv.gpa, .OpConstantFalse, operands);
                }
            },
            // TODO: We can handle most pointers here (decl refs etc), because now they emit an extra
            // OpVariable that is not really required.
            else => {
                // The value cannot be generated directly, so generate it as an indirect constant,
                // and then perform an OpLoad.
                const alignment = ty.abiAlignment(target);
                const spv_decl_index = try self.spv.allocDecl(.global);

                try self.lowerIndirectConstant(
                    spv_decl_index,
                    ty,
                    val,
                    .UniformConstant,
                    false,
                    alignment,
                );
                try self.func.decl_deps.append(self.spv.gpa, spv_decl_index);

                try self.func.body.emit(self.spv.gpa, .OpLoad, .{
                    .id_result_type = result_ty_id,
                    .id_result = result_id,
                    .pointer = self.spv.declPtr(spv_decl_index).result_id,
                });
                // TODO: Convert bools? This logic should hook into `load`. It should be a dead
                // path though considering .Bool is handled above.
            },
        }

        return result_id;
    }

    /// Turn a Zig type into a SPIR-V Type, and return its type result-id.
    fn resolveTypeId(self: *DeclGen, ty: Type) !IdResultType {
        const type_ref = try self.resolveType(ty, .direct);
        return self.typeId(type_ref);
    }

    fn typeId(self: *DeclGen, ty_ref: SpvType.Ref) IdRef {
        return self.spv.typeId(ty_ref);
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

    /// Generate a union type, optionally with a known field. If the tag alignment is greater
    /// than that of the payload, a regular union (non-packed, with both tag and payload), will
    /// be generated as follows:
    /// If the active field is known:
    ///  struct {
    ///    tag: TagType,
    ///    payload: ActivePayloadType,
    ///    payload_padding: [payload_size - @sizeOf(ActivePayloadType)]u8,
    ///    padding: [padding_size]u8,
    ///  }
    /// If the payload alignment is greater than that of the tag:
    ///  struct {
    ///    payload: ActivePayloadType,
    ///    payload_padding: [payload_size - @sizeOf(ActivePayloadType)]u8,
    ///    tag: TagType,
    ///    padding: [padding_size]u8,
    ///  }
    /// If the active payload is unknown, it will default back to the most aligned field. This is
    /// to make sure that the overal struct has the correct alignment in spir-v.
    /// If any of the fields' size is 0, it will be omitted.
    /// NOTE: When the active field is set to something other than the most aligned field, the
    ///   resulting struct will be *underaligned*.
    fn resolveUnionType(self: *DeclGen, ty: Type, maybe_active_field: ?usize) !SpvType.Ref {
        const target = self.getTarget();
        const layout = ty.unionGetLayout(target);
        const union_ty = ty.cast(Type.Payload.Union).?.data;

        if (union_ty.layout == .Packed) {
            return self.todo("packed union types", .{});
        }

        const tag_ty_ref = try self.resolveType(union_ty.tag_ty, .indirect);
        if (layout.payload_size == 0) {
            // No payload, so represent this as just the tag type.
            return tag_ty_ref;
        }

        var members = std.BoundedArray(SpvType.Payload.Struct.Member, 4){};

        const has_tag = layout.tag_size != 0;
        const tag_first = layout.tag_align >= layout.payload_align;
        const tag_member = .{ .name = "tag", .ty = tag_ty_ref };
        const u8_ty_ref = try self.intType(.unsigned, 8); // TODO: What if Int8Type is not enabled?

        if (has_tag and tag_first) {
            members.appendAssumeCapacity(tag_member);
        }

        const active_field = maybe_active_field orelse layout.most_aligned_field;
        const active_field_ty = union_ty.fields.values()[active_field].ty;

        const active_field_size = if (active_field_ty.hasRuntimeBitsIgnoreComptime()) blk: {
            const active_payload_ty_ref = try self.resolveType(active_field_ty, .indirect);
            members.appendAssumeCapacity(.{ .name = "payload", .ty = active_payload_ty_ref });
            break :blk active_field_ty.abiSize(target);
        } else 0;

        const payload_padding_len = layout.payload_size - active_field_size;
        if (payload_padding_len != 0) {
            const payload_padding_ty_ref = try self.spv.arrayType(@intCast(u32, payload_padding_len), u8_ty_ref);
            members.appendAssumeCapacity(.{ .name = "padding_payload", .ty = payload_padding_ty_ref });
        }

        if (has_tag and !tag_first) {
            members.appendAssumeCapacity(tag_member);
        }

        if (layout.padding != 0) {
            const padding_ty_ref = try self.spv.arrayType(layout.padding, u8_ty_ref);
            members.appendAssumeCapacity(.{ .name = "padding", .ty = padding_ty_ref });
        }

        return try self.spv.simpleStructType(members.slice());
    }

    /// Turn a Zig type into a SPIR-V Type, and return a reference to it.
    fn resolveType(self: *DeclGen, ty: Type, repr: Repr) Error!SpvType.Ref {
        log.debug("resolveType: ty = {}", .{ty.fmt(self.module)});
        const target = self.getTarget();
        switch (ty.zigTypeTag()) {
            .Void, .NoReturn => return try self.spv.resolveType(SpvType.initTag(.void)),
            .Bool => switch (repr) {
                .direct => return try self.spv.resolveType(SpvType.initTag(.bool)),
                // SPIR-V booleans are opaque, which is fine for operations, but they cant be stored.
                // This function returns the *stored* type, for values directly we convert this into a bool when
                // it is loaded, and convert it back to this type when stored.
                .indirect => return try self.intType(.unsigned, 1),
            },
            .Int => {
                const int_info = ty.intInfo(target);
                return try self.intType(int_info.signedness, int_info.bits);
            },
            .Enum => {
                var buffer: Type.Payload.Bits = undefined;
                const tag_ty = ty.intTagType(&buffer);
                return self.resolveType(tag_ty, repr);
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
                const elem_ty_ref = try self.resolveType(elem_ty, .indirect);
                const total_len = std.math.cast(u32, ty.arrayLenIncludingSentinel()) orelse {
                    return self.fail("array type of {} elements is too large", .{ty.arrayLenIncludingSentinel()});
                };
                return try self.spv.arrayType(total_len, elem_ty_ref);
            },
            .Fn => switch (repr) {
                .direct => {
                    // TODO: Put this somewhere in Sema.zig
                    if (ty.fnIsVarArgs())
                        return self.fail("VarArgs functions are unsupported for SPIR-V", .{});

                    // TODO: Parameter passing convention etc.

                    const param_types = try self.spv.arena.alloc(SpvType.Ref, ty.fnParamLen());
                    for (param_types, 0..) |*param, i| {
                        param.* = try self.resolveType(ty.fnParamType(i), .direct);
                    }

                    const return_type = try self.resolveType(ty.fnReturnType(), .direct);

                    const payload = try self.spv.arena.create(SpvType.Payload.Function);
                    payload.* = .{ .return_type = return_type, .parameters = param_types };
                    return try self.spv.resolveType(SpvType.initPayload(&payload.base));
                },
                .indirect => {
                    // TODO: Represent function pointers properly.
                    // For now, just use an usize type.
                    return try self.sizeType();
                },
            },
            .Pointer => {
                const ptr_info = ty.ptrInfo().data;

                const storage_class = spvStorageClass(ptr_info.@"addrspace");
                const child_ty_ref = try self.resolveType(ptr_info.pointee_type, .indirect);
                const ptr_ty_ref = try self.spv.ptrType(child_ty_ref, storage_class, 0);

                if (ptr_info.size != .Slice) {
                    return ptr_ty_ref;
                }

                return try self.spv.simpleStructType(&.{
                    .{ .ty = ptr_ty_ref, .name = "ptr" },
                    .{ .ty = try self.sizeType(), .name = "len" },
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
                    .component_type = try self.resolveType(ty.elemType(), repr),
                    .component_count = @intCast(u32, ty.vectorLen()),
                };
                return try self.spv.resolveType(SpvType.initPayload(&payload.base));
            },
            .Struct => {
                if (ty.isSimpleTupleOrAnonStruct()) {
                    const tuple = ty.tupleFields();
                    const members = try self.spv.arena.alloc(SpvType.Payload.Struct.Member, tuple.types.len);
                    var member_index: u32 = 0;
                    for (tuple.types, 0..) |field_ty, i| {
                        const field_val = tuple.values[i];
                        if (field_val.tag() != .unreachable_value or !field_ty.hasRuntimeBitsIgnoreComptime()) continue;
                        members[member_index] = .{
                            .ty = try self.resolveType(field_ty, .indirect),
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
                    return try self.resolveType(struct_ty.backing_int_ty, .indirect);
                }

                const members = try self.spv.arena.alloc(SpvType.Payload.Struct.Member, struct_ty.fields.count());
                var member_index: usize = 0;
                for (struct_ty.fields.values(), 0..) |field, i| {
                    if (field.is_comptime or !field.ty.hasRuntimeBits()) continue;

                    members[member_index] = .{
                        .ty = try self.resolveType(field.ty, .indirect),
                        .name = struct_ty.fields.keys()[i],
                    };
                    member_index += 1;
                }

                const name = try struct_ty.getFullyQualifiedName(self.module);
                defer self.module.gpa.free(name);

                const payload = try self.spv.arena.create(SpvType.Payload.Struct);
                payload.* = .{
                    .members = members[0..member_index],
                    .name = try self.spv.arena.dupe(u8, name),
                };
                return try self.spv.resolveType(SpvType.initPayload(&payload.base));
            },
            .Optional => {
                var buf: Type.Payload.ElemType = undefined;
                const payload_ty = ty.optionalChild(&buf);
                if (!payload_ty.hasRuntimeBitsIgnoreComptime()) {
                    // Just use a bool.
                    // Note: Always generate the bool with indirect format, to save on some sanity
                    // Perform the converison to a direct bool when the field is extracted.
                    return try self.resolveType(Type.bool, .indirect);
                }

                const payload_ty_ref = try self.resolveType(payload_ty, .indirect);
                if (ty.optionalReprIsPayload()) {
                    // Optional is actually a pointer.
                    return payload_ty_ref;
                }

                const bool_ty_ref = try self.resolveType(Type.bool, .indirect);

                // its an actual optional
                return try self.spv.simpleStructType(&.{
                    .{ .ty = payload_ty_ref, .name = "payload" },
                    .{ .ty = bool_ty_ref, .name = "valid" },
                });
            },
            .Union => return try self.resolveUnionType(ty, null),
            .ErrorSet => return try self.intType(.unsigned, 16),
            .ErrorUnion => {
                const payload_ty = ty.errorUnionPayload();
                const error_ty_ref = try self.resolveType(Type.anyerror, .indirect);
                if (!payload_ty.hasRuntimeBitsIgnoreComptime()) {
                    return error_ty_ref;
                }

                const payload_ty_ref = try self.resolveType(payload_ty, .indirect);

                const payload_align = payload_ty.abiAlignment(target);
                const error_align = Type.anyerror.abiAlignment(target);

                var members = std.BoundedArray(SpvType.Payload.Struct.Member, 2){};
                // Similar to unions, we're going to put the most aligned member first.
                if (error_align > payload_align) {
                    // Put the error first
                    members.appendAssumeCapacity(.{ .ty = error_ty_ref, .name = "error" });
                    members.appendAssumeCapacity(.{ .ty = payload_ty_ref, .name = "payload" });
                    // TODO: ABI padding?
                } else {
                    // Put the payload first.
                    members.appendAssumeCapacity(.{ .ty = payload_ty_ref, .name = "payload" });
                    members.appendAssumeCapacity(.{ .ty = error_ty_ref, .name = "error" });
                    // TODO: ABI padding?
                }

                return try self.spv.simpleStructType(members.slice());
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

    fn spvStorageClass(as: std.builtin.AddressSpace) StorageClass {
        return switch (as) {
            .generic => .Generic,
            .shared => .Workgroup,
            .local => .Private,
            .global => .CrossWorkgroup,
            .constant => .UniformConstant,
            .gs,
            .fs,
            .ss,
            .param,
            .flash,
            .flash1,
            .flash2,
            .flash3,
            .flash4,
            .flash5,
            => unreachable,
        };
    }

    /// The SPIR-V backend is not yet advanced enough to support the std testing infrastructure.
    /// In order to be able to run tests, we "temporarily" lower test kernels into separate entry-
    /// points. The test executor will then be able to invoke these to run the tests.
    /// Note that tests are lowered according to std.builtin.TestFn, which is `fn () anyerror!void`.
    /// (anyerror!void has the same layout as anyerror).
    /// Each test declaration generates a function like.
    ///   %anyerror = OpTypeInt 0 16
    ///   %p_anyerror = OpTypePointer CrossWorkgroup %anyerror
    ///   %K = OpTypeFunction %void %p_anyerror
    ///
    ///   %test = OpFunction %void %K
    ///   %p_err = OpFunctionParameter %p_anyerror
    ///   %lbl = OpLabel
    ///   %result = OpFunctionCall %anyerror %func
    ///   OpStore %p_err %result
    ///   OpFunctionEnd
    /// TODO is to also write out the error as a function call parameter, and to somehow fetch
    /// the name of an error in the text executor.
    fn generateTestEntryPoint(self: *DeclGen, name: []const u8, spv_test_decl_index: SpvModule.Decl.Index) !void {
        const anyerror_ty_ref = try self.resolveType(Type.anyerror, .direct);
        const ptr_anyerror_ty_ref = try self.spv.ptrType(anyerror_ty_ref, .CrossWorkgroup, 0);
        const void_ty_ref = try self.resolveType(Type.void, .direct);

        const kernel_proto_ty_ref = blk: {
            const proto_payload = try self.spv.arena.create(SpvType.Payload.Function);
            proto_payload.* = .{
                .return_type = void_ty_ref,
                .parameters = try self.spv.arena.dupe(SpvType.Ref, &.{ptr_anyerror_ty_ref}),
            };
            break :blk try self.spv.resolveType(SpvType.initPayload(&proto_payload.base));
        };

        const test_id = self.spv.declPtr(spv_test_decl_index).result_id;

        const spv_decl_index = try self.spv.allocDecl(.func);
        const kernel_id = self.spv.declPtr(spv_decl_index).result_id;

        const error_id = self.spv.allocId();
        const p_error_id = self.spv.allocId();

        const section = &self.spv.sections.functions;
        try section.emit(self.spv.gpa, .OpFunction, .{
            .id_result_type = self.typeId(void_ty_ref),
            .id_result = kernel_id,
            .function_control = .{},
            .function_type = self.typeId(kernel_proto_ty_ref),
        });
        try section.emit(self.spv.gpa, .OpFunctionParameter, .{
            .id_result_type = self.typeId(ptr_anyerror_ty_ref),
            .id_result = p_error_id,
        });
        try section.emit(self.spv.gpa, .OpLabel, .{
            .id_result = self.spv.allocId(),
        });
        try section.emit(self.spv.gpa, .OpFunctionCall, .{
            .id_result_type = self.typeId(anyerror_ty_ref),
            .id_result = error_id,
            .function = test_id,
        });
        try section.emit(self.spv.gpa, .OpStore, .{
            .pointer = p_error_id,
            .object = error_id,
        });
        try section.emit(self.spv.gpa, .OpReturn, {});
        try section.emit(self.spv.gpa, .OpFunctionEnd, {});

        try self.spv.declareDeclDeps(spv_decl_index, &.{spv_test_decl_index});

        // Just generate a quick other name because the intel runtime crashes when the entry-
        // point name is the same as a different OpName.
        const test_name = try std.fmt.allocPrint(self.gpa, "test {s}", .{name});
        defer self.gpa.free(test_name);
        try self.spv.declareEntryPoint(spv_decl_index, test_name);
    }

    fn genDecl(self: *DeclGen) !void {
        const decl = self.module.declPtr(self.decl_index);
        const spv_decl_index = try self.resolveDecl(self.decl_index);

        const decl_id = self.spv.declPtr(spv_decl_index).result_id;
        log.debug("genDecl {s} = {}", .{ decl.name, decl_id });

        if (decl.val.castTag(.function)) |_| {
            assert(decl.ty.zigTypeTag() == .Fn);
            const prototype_id = try self.resolveTypeId(decl.ty);
            try self.func.prologue.emit(self.spv.gpa, .OpFunction, .{
                .id_result_type = try self.resolveTypeId(decl.ty.fnReturnType()),
                .id_result = decl_id,
                .function_control = .{}, // TODO: We can set inline here if the type requires it.
                .function_type = prototype_id,
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
                self.args.appendAssumeCapacity(arg_result_id);
            }

            // TODO: This could probably be done in a better way...
            const root_block_id = self.spv.allocId();

            // The root block of a function declaration should appear before OpVariable instructions,
            // so it is generated into the function's prologue.
            try self.func.prologue.emit(self.spv.gpa, .OpLabel, .{
                .id_result = root_block_id,
            });
            self.current_block_label_id = root_block_id;

            const main_body = self.air.getMainBody();
            try self.genBody(main_body);

            // Append the actual code into the functions section.
            try self.func.body.emit(self.spv.gpa, .OpFunctionEnd, {});
            try self.spv.addFunction(spv_decl_index, self.func);

            const fqn = try decl.getFullyQualifiedName(self.module);
            defer self.module.gpa.free(fqn);

            try self.spv.sections.debug_names.emit(self.gpa, .OpName, .{
                .target = decl_id,
                .name = fqn,
            });

            // Temporarily generate a test kernel declaration if this is a test function.
            if (self.module.test_functions.contains(self.decl_index)) {
                try self.generateTestEntryPoint(fqn, spv_decl_index);
            }
        } else {
            const init_val = if (decl.val.castTag(.variable)) |payload|
                payload.data.init
            else
                decl.val;

            if (init_val.tag() == .unreachable_value) {
                return self.todo("importing extern variables", .{});
            }

            // TODO: integrate with variable().

            const final_storage_class = spvStorageClass(decl.@"addrspace");
            const actual_storage_class = switch (final_storage_class) {
                .Generic => .CrossWorkgroup,
                else => final_storage_class,
            };

            try self.lowerIndirectConstant(
                spv_decl_index,
                decl.ty,
                init_val,
                actual_storage_class,
                final_storage_class == .Generic,
                decl.@"align",
            );
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

            .shl => try self.airShift(inst, .OpShiftLeftLogical),

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
            .store      => return self.airStore(inst),

            .br         => return self.airBr(inst),
            .breakpoint => return,
            .cond_br    => return self.airCondBr(inst),
            .constant   => unreachable,
            .const_ty   => unreachable,
            .dbg_stmt   => return self.airDbgStmt(inst),
            .loop       => return self.airLoop(inst),
            .ret        => return self.airRet(inst),
            .ret_load   => return self.airRetLoad(inst),
            .switch_br  => return self.airSwitchBr(inst),
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
        return result_id;
    }

    fn airShift(self: *DeclGen, inst: Air.Inst.Index, comptime opcode: Opcode) !?IdRef {
        if (self.liveness.isUnused(inst)) return null;
        const bin_op = self.air.instructions.items(.data)[inst].bin_op;
        const lhs_id = try self.resolve(bin_op.lhs);
        const rhs_id = try self.resolve(bin_op.rhs);
        const result_type_id = try self.resolveTypeId(self.air.typeOfIndex(inst));

        // the shift and the base must be the same type in SPIR-V, but in Zig the shift is a smaller int.
        const shift_id = self.spv.allocId();
        try self.func.body.emit(self.spv.gpa, .OpUConvert, .{
            .id_result_type = result_type_id,
            .id_result = shift_id,
            .unsigned_value = rhs_id,
        });

        const result_id = self.spv.allocId();
        try self.func.body.emit(self.spv.gpa, opcode, .{
            .id_result_type = result_type_id,
            .id_result = result_id,
            .base = lhs_id,
            .shift = shift_id,
        });
        return result_id;
    }

    fn maskStrangeInt(self: *DeclGen, ty_ref: SpvType.Ref, value_id: IdRef, bits: u16) !IdRef {
        const mask_value = if (bits == 64) 0xFFFF_FFFF_FFFF_FFFF else (@as(u64, 1) << @intCast(u6, bits)) - 1;
        const result_id = self.spv.allocId();
        const mask_id = try self.constInt(ty_ref, mask_value);
        try self.func.body.emit(self.spv.gpa, .OpBitwiseAnd, .{
            .id_result_type = self.typeId(ty_ref),
            .id_result = result_id,
            .operand_1 = value_id,
            .operand_2 = mask_id,
        });
        return result_id;
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

        const result_ty_ref = try self.resolveType(ty, .direct);

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
                    lhs_id = try self.maskStrangeInt(result_ty_ref, lhs_id, info.bits);
                    rhs_id = try self.maskStrangeInt(result_ty_ref, rhs_id, info.bits);
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

        const result_id = self.spv.allocId();
        const operands = .{
            .id_result_type = self.typeId(result_ty_ref),
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

        return result_id;
    }

    fn airOverflowArithOp(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        if (self.liveness.isUnused(inst)) return null;

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
        const overflow_member_ty_id = self.typeId(overflow_member_ty);

        const op_result_id = blk: {
            // Construct the SPIR-V result type.
            // It is almost the same as the zig one, except that the fields must be the same type
            // and they must be unsigned.
            const overflow_result_ty_ref = try self.spv.simpleStructType(&.{
                .{ .ty = overflow_member_ty, .name = "res" },
                .{ .ty = overflow_member_ty, .name = "ov" },
            });
            const result_id = self.spv.allocId();
            try self.func.body.emit(self.spv.gpa, .OpIAddCarry, .{
                .id_result_type = self.typeId(overflow_result_ty_ref),
                .id_result = result_id,
                .operand_1 = lhs,
                .operand_2 = rhs,
            });
            break :blk result_id;
        };

        // Now convert the SPIR-V flavor result into a Zig-flavor result.
        // First, extract the two fields.
        const unsigned_result = try self.extractField(overflow_member_ty_id, op_result_id, 0);
        const overflow = try self.extractField(overflow_member_ty_id, op_result_id, 1);

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
            break :blk result_id;
        };

        // TODO: If copying this function for borrow, make sure to convert -1 to 1 as appropriate.

        // Finally, construct the Zig type.
        // Layout is result, overflow.
        const result_id = self.spv.allocId();
        const constituents = [_]IdRef{ result, casted_overflow };
        try self.func.body.emit(self.spv.gpa, .OpCompositeConstruct, .{
            .id_result_type = result_type_id,
            .id_result = result_id,
            .constituents = &constituents,
        });
        return result_id;
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
        return result_id;
    }

    fn airCmp(self: *DeclGen, inst: Air.Inst.Index, comptime fop: Opcode, comptime sop: Opcode, comptime uop: Opcode) !?IdRef {
        if (self.liveness.isUnused(inst)) return null;
        const bin_op = self.air.instructions.items(.data)[inst].bin_op;
        var lhs_id = try self.resolve(bin_op.lhs);
        var rhs_id = try self.resolve(bin_op.rhs);
        const result_id = self.spv.allocId();
        const result_type_id = try self.resolveTypeId(Type.bool);
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
                const op_ty_ref = try self.resolveType(op_ty, .direct);
                lhs_id = try self.maskStrangeInt(op_ty_ref, lhs_id, info.bits);
                rhs_id = try self.maskStrangeInt(op_ty_ref, rhs_id, info.bits);
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

        return result_id;
    }

    fn bitcast(self: *DeclGen, target_type_id: IdResultType, value_id: IdRef) !IdRef {
        const result_id = self.spv.allocId();
        try self.func.body.emit(self.spv.gpa, .OpBitcast, .{
            .id_result_type = target_type_id,
            .id_result = result_id,
            .operand = value_id,
        });
        return result_id;
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
        return result_id;
    }

    fn airNot(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        if (self.liveness.isUnused(inst)) return null;
        const ty_op = self.air.instructions.items(.data)[inst].ty_op;
        const operand_id = try self.resolve(ty_op.operand);
        const result_id = self.spv.allocId();
        const result_type_id = try self.resolveTypeId(Type.bool);
        try self.func.body.emit(self.spv.gpa, .OpLogicalNot, .{
            .id_result_type = result_type_id,
            .id_result = result_id,
            .operand = operand_id,
        });
        return result_id;
    }

    fn extractField(self: *DeclGen, result_ty: IdResultType, object: IdRef, field: u32) !IdRef {
        const result_id = self.spv.allocId();
        const indexes = [_]u32{field};
        try self.func.body.emit(self.spv.gpa, .OpCompositeExtract, .{
            .id_result_type = result_ty,
            .id_result = result_id,
            .composite = object,
            .indexes = &indexes,
        });
        return result_id;
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
            break :blk result_id;
        };

        const result_id = self.spv.allocId();
        try self.func.body.emit(self.spv.gpa, .OpInBoundsPtrAccessChain, .{
            .id_result_type = spv_ptr_ty,
            .id_result = result_id,
            .base = slice_ptr,
            .element = index,
        });
        return result_id;
    }

    fn airSliceElemVal(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        const bin_op = self.air.instructions.items(.data)[inst].bin_op;
        const slice_ty = self.air.typeOf(bin_op.lhs);
        if (!slice_ty.isVolatilePtr() and self.liveness.isUnused(inst)) return null;

        const slice = try self.resolve(bin_op.lhs);
        const index = try self.resolve(bin_op.rhs);

        var slice_buf: Type.SlicePtrFieldTypeBuffer = undefined;
        const ptr_ty_id = try self.resolveTypeId(slice_ty.slicePtrFieldType(&slice_buf));

        const slice_ptr = blk: {
            const result_id = self.spv.allocId();
            try self.func.body.emit(self.spv.gpa, .OpCompositeExtract, .{
                .id_result_type = ptr_ty_id,
                .id_result = result_id,
                .composite = slice,
                .indexes = &.{0},
            });
            break :blk result_id;
        };

        const elem_ptr = blk: {
            const result_id = self.spv.allocId();
            try self.func.body.emit(self.spv.gpa, .OpInBoundsPtrAccessChain, .{
                .id_result_type = ptr_ty_id,
                .id_result = result_id,
                .base = slice_ptr,
                .element = index,
            });
            break :blk result_id;
        };

        return try self.load(slice_ty, elem_ptr);
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
        const indexes = [_]IdRef{rhs};
        try self.func.body.emit(self.spv.gpa, .OpInBoundsAccessChain, .{
            .id_result_type = result_type_id,
            .id_result = result_id,
            .base = base_ptr,
            .indexes = &indexes,
        });
        return result_id;
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
        const indexes = [_]u32{field_index};
        try self.func.body.emit(self.spv.gpa, .OpCompositeExtract, .{
            .id_result_type = field_ty_id,
            .id_result = result_id,
            .composite = object,
            .indexes = &indexes,
        });
        return result_id;
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
                    const u32_ty_id = self.typeId(try self.intType(.unsigned, 32));
                    const field_index_id = self.spv.allocId();
                    try self.spv.emitConstant(u32_ty_id, field_index_id, .{ .uint32 = field_index });
                    const result_id = self.spv.allocId();
                    const result_type_id = try self.resolveTypeId(result_ptr_ty);
                    const indexes = [_]IdRef{field_index_id};
                    try self.func.body.emit(self.spv.gpa, .OpInBoundsAccessChain, .{
                        .id_result_type = result_type_id,
                        .id_result = result_id,
                        .base = object_ptr,
                        .indexes = &indexes,
                    });
                    return result_id;
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

    /// We cannot use an OpVariable directly in an OpSpecConstantOp, but we can
    /// after we insert a dummy AccessChain...
    /// TODO: Get rid of this
    fn makePointerConstant(
        self: *DeclGen,
        section: *SpvSection,
        ptr_ty_ref: SpvType.Ref,
        ptr_id: IdRef,
    ) !IdRef {
        const result_id = self.spv.allocId();
        try section.emitSpecConstantOp(self.spv.gpa, .OpInBoundsAccessChain, .{
            .id_result_type = self.typeId(ptr_ty_ref),
            .id_result = result_id,
            .base = ptr_id,
        });
        return result_id;
    }

    fn variable(
        self: *DeclGen,
        comptime context: enum { function, global },
        result_id: IdRef,
        ptr_ty_ref: SpvType.Ref,
        initializer: ?IdRef,
    ) !void {
        const storage_class = self.spv.typeRefType(ptr_ty_ref).payload(.pointer).storage_class;
        const actual_storage_class = switch (storage_class) {
            .Generic => switch (context) {
                .function => .Function,
                .global => .CrossWorkgroup,
            },
            else => storage_class,
        };
        const actual_ptr_ty_ref = switch (storage_class) {
            .Generic => try self.spv.changePtrStorageClass(ptr_ty_ref, actual_storage_class),
            else => ptr_ty_ref,
        };
        const alloc_result_id = switch (storage_class) {
            .Generic => self.spv.allocId(),
            else => result_id,
        };

        const section = switch (actual_storage_class) {
            .Generic => unreachable,
            // SPIR-V requires that OpVariable declarations for locals go into the first block, so we are just going to
            // directly generate them into func.prologue instead of the body.
            .Function => &self.func.prologue,
            else => &self.spv.sections.types_globals_constants,
        };
        try section.emit(self.spv.gpa, .OpVariable, .{
            .id_result_type = self.typeId(actual_ptr_ty_ref),
            .id_result = alloc_result_id,
            .storage_class = actual_storage_class,
            .initializer = initializer,
        });

        if (storage_class != .Generic) {
            return;
        }

        // Now we need to convert the pointer.
        // If this is a function local, we need to perform the conversion at runtime. Otherwise, we can do
        // it ahead of time using OpSpecConstantOp.
        switch (actual_storage_class) {
            .Function => try self.func.body.emit(self.spv.gpa, .OpPtrCastToGeneric, .{
                .id_result_type = self.typeId(ptr_ty_ref),
                .id_result = result_id,
                .pointer = alloc_result_id,
            }),
            // TODO: Can we do without this cast or move it to runtime?
            else => {
                const const_ptr_id = try self.makePointerConstant(section, actual_ptr_ty_ref, alloc_result_id);
                try section.emitSpecConstantOp(self.spv.gpa, .OpPtrCastToGeneric, .{
                    .id_result_type = self.typeId(ptr_ty_ref),
                    .id_result = result_id,
                    .pointer = const_ptr_id,
                });
            },
        }
    }

    fn airAlloc(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        if (self.liveness.isUnused(inst)) return null;
        const ty = self.air.typeOfIndex(inst);
        const result_ty_ref = try self.resolveType(ty, .direct);
        const result_id = self.spv.allocId();
        try self.variable(.function, result_id, result_ty_ref, null);
        return result_id;
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
            .label_id = label_id,
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

        return result_id;
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
            .true_label = then_label_id,
            .false_label = else_label_id,
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

    fn airLoad(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        const ty_op = self.air.instructions.items(.data)[inst].ty_op;
        const ptr_ty = self.air.typeOf(ty_op.operand);
        const operand = try self.resolve(ty_op.operand);
        if (!ptr_ty.isVolatilePtr() and self.liveness.isUnused(inst)) return null;

        return try self.load(ptr_ty, operand);
    }

    fn load(self: *DeclGen, ptr_ty: Type, ptr: IdRef) !IdRef {
        const value_ty = ptr_ty.childType();
        const direct_result_ty_ref = try self.resolveType(value_ty, .direct);
        const indirect_result_ty_ref = try self.resolveType(value_ty, .indirect);
        const result_id = self.spv.allocId();
        const access = spec.MemoryAccess.Extended{
            .Volatile = ptr_ty.isVolatilePtr(),
        };
        try self.func.body.emit(self.spv.gpa, .OpLoad, .{
            .id_result_type = self.typeId(indirect_result_ty_ref),
            .id_result = result_id,
            .pointer = ptr,
            .memory_access = access,
        });
        if (value_ty.zigTypeTag() == .Bool) {
            // Convert indirect bool to direct bool
            const zero_id = try self.constInt(indirect_result_ty_ref, 0);
            const casted_result_id = self.spv.allocId();
            try self.func.body.emit(self.spv.gpa, .OpINotEqual, .{
                .id_result_type = self.typeId(direct_result_ty_ref),
                .id_result = casted_result_id,
                .operand_1 = result_id,
                .operand_2 = zero_id,
            });
            return casted_result_id;
        }
        return result_id;
    }

    fn airStore(self: *DeclGen, inst: Air.Inst.Index) !void {
        const bin_op = self.air.instructions.items(.data)[inst].bin_op;
        const ptr_ty = self.air.typeOf(bin_op.lhs);
        const ptr = try self.resolve(bin_op.lhs);
        const value = try self.resolve(bin_op.rhs);

        try self.store(ptr_ty, ptr, value);
    }

    fn store(self: *DeclGen, ptr_ty: Type, ptr: IdRef, value: IdRef) !void {
        const value_ty = ptr_ty.childType();
        const converted_value = switch (value_ty.zigTypeTag()) {
            .Bool => blk: {
                const indirect_bool_ty_ref = try self.resolveType(value_ty, .indirect);
                const result_id = self.spv.allocId();
                const zero = try self.constInt(indirect_bool_ty_ref, 0);
                const one = try self.constInt(indirect_bool_ty_ref, 1);
                try self.func.body.emit(self.spv.gpa, .OpSelect, .{
                    .id_result_type = self.typeId(indirect_bool_ty_ref),
                    .id_result = result_id,
                    .condition = value,
                    .object_1 = one,
                    .object_2 = zero,
                });
                break :blk result_id;
            },
            else => value,
        };
        const access = spec.MemoryAccess.Extended{
            .Volatile = ptr_ty.isVolatilePtr(),
        };
        try self.func.body.emit(self.spv.gpa, .OpStore, .{
            .pointer = ptr,
            .object = converted_value,
            .memory_access = access,
        });
    }

    fn airLoop(self: *DeclGen, inst: Air.Inst.Index) !void {
        const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
        const loop = self.air.extraData(Air.Block, ty_pl.payload);
        const body = self.air.extra[loop.end..][0..loop.data.body_len];
        const loop_label_id = self.spv.allocId();

        // Jump to the loop entry point
        try self.func.body.emit(self.spv.gpa, .OpBranch, .{ .target_label = loop_label_id });

        // TODO: Look into OpLoopMerge.
        try self.beginSpvBlock(loop_label_id);
        try self.genBody(body);

        try self.func.body.emit(self.spv.gpa, .OpBranch, .{ .target_label = loop_label_id });
    }

    fn airRet(self: *DeclGen, inst: Air.Inst.Index) !void {
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

        if (!ret_ty.hasRuntimeBitsIgnoreComptime()) {
            try self.func.body.emit(self.spv.gpa, .OpReturn, {});
            return;
        }

        const ptr = try self.resolve(un_op);
        const value = try self.load(ptr_ty, ptr);
        try self.func.body.emit(self.spv.gpa, .OpReturnValue, .{
            .value = value,
        });
    }

    fn airSwitchBr(self: *DeclGen, inst: Air.Inst.Index) !void {
        const target = self.getTarget();
        const pl_op = self.air.instructions.items(.data)[inst].pl_op;
        const cond = try self.resolve(pl_op.operand);
        const cond_ty = self.air.typeOf(pl_op.operand);
        const switch_br = self.air.extraData(Air.SwitchBr, pl_op.payload);

        const cond_words: u32 = switch (cond_ty.zigTypeTag()) {
            .Int => blk: {
                const bits = cond_ty.intInfo(target).bits;
                const backing_bits = self.backingIntBits(bits) orelse {
                    return self.todo("implement composite int switch", .{});
                };
                break :blk if (backing_bits <= 32) @as(u32, 1) else 2;
            },
            .Enum => blk: {
                var buffer: Type.Payload.Bits = undefined;
                const int_ty = cond_ty.intTagType(&buffer);
                const int_info = int_ty.intInfo(target);
                const backing_bits = self.backingIntBits(int_info.bits) orelse {
                    return self.todo("implement composite int switch", .{});
                };
                break :blk if (backing_bits <= 32) @as(u32, 1) else 2;
            },
            else => return self.todo("implement switch for type {s}", .{@tagName(cond_ty.zigTypeTag())}), // TODO: Figure out which types apply here, and work around them as we can only do integers.
        };

        const num_cases = switch_br.data.cases_len;

        // Compute the total number of arms that we need.
        // Zig switches are grouped by condition, so we need to loop through all of them
        const num_conditions = blk: {
            var extra_index: usize = switch_br.end;
            var case_i: u32 = 0;
            var num_conditions: u32 = 0;
            while (case_i < num_cases) : (case_i += 1) {
                const case = self.air.extraData(Air.SwitchBr.Case, extra_index);
                const case_body = self.air.extra[case.end + case.data.items_len ..][0..case.data.body_len];
                extra_index = case.end + case.data.items_len + case_body.len;
                num_conditions += case.data.items_len;
            }
            break :blk num_conditions;
        };

        // First, pre-allocate the labels for the cases.
        const first_case_label = self.spv.allocIds(num_cases);
        // We always need the default case - if zig has none, we will generate unreachable there.
        const default = self.spv.allocId();

        // Emit the instruction before generating the blocks.
        try self.func.body.emitRaw(self.spv.gpa, .OpSwitch, 2 + (cond_words + 1) * num_conditions);
        self.func.body.writeOperand(IdRef, cond);
        self.func.body.writeOperand(IdRef, default);

        // Emit each of the cases
        {
            var extra_index: usize = switch_br.end;
            var case_i: u32 = 0;
            while (case_i < num_cases) : (case_i += 1) {
                // SPIR-V needs a literal here, which' width depends on the case condition.
                const case = self.air.extraData(Air.SwitchBr.Case, extra_index);
                const items = @ptrCast([]const Air.Inst.Ref, self.air.extra[case.end..][0..case.data.items_len]);
                const case_body = self.air.extra[case.end + items.len ..][0..case.data.body_len];
                extra_index = case.end + case.data.items_len + case_body.len;

                const label = IdRef{ .id = first_case_label.id + case_i };

                for (items) |item| {
                    const value = self.air.value(item) orelse {
                        return self.todo("switch on runtime value???", .{});
                    };
                    const int_val = switch (cond_ty.zigTypeTag()) {
                        .Int => if (cond_ty.isSignedInt()) @bitCast(u64, value.toSignedInt(target)) else value.toUnsignedInt(target),
                        .Enum => blk: {
                            var int_buffer: Value.Payload.U64 = undefined;
                            // TODO: figure out of cond_ty is correct (something with enum literals)
                            break :blk value.enumToInt(cond_ty, &int_buffer).toUnsignedInt(target); // TODO: composite integer constants
                        },
                        else => unreachable,
                    };
                    const int_lit: spec.LiteralContextDependentNumber = switch (cond_words) {
                        1 => .{ .uint32 = @intCast(u32, int_val) },
                        2 => .{ .uint64 = int_val },
                        else => unreachable,
                    };
                    self.func.body.writeOperand(spec.LiteralContextDependentNumber, int_lit);
                    self.func.body.writeOperand(IdRef, label);
                }
            }
        }

        // Now, finally, we can start emitting each of the cases.
        var extra_index: usize = switch_br.end;
        var case_i: u32 = 0;
        while (case_i < num_cases) : (case_i += 1) {
            const case = self.air.extraData(Air.SwitchBr.Case, extra_index);
            const items = @ptrCast([]const Air.Inst.Ref, self.air.extra[case.end..][0..case.data.items_len]);
            const case_body = self.air.extra[case.end + items.len ..][0..case.data.body_len];
            extra_index = case.end + case.data.items_len + case_body.len;

            const label = IdResult{ .id = first_case_label.id + case_i };

            try self.beginSpvBlock(label);
            try self.genBody(case_body);
        }

        const else_body = self.air.extra[extra_index..][0..switch_br.data.else_body_len];
        try self.beginSpvBlock(default);
        if (else_body.len != 0) {
            try self.genBody(else_body);
        } else {
            try self.func.body.emit(self.spv.gpa, .OpUnreachable, {});
        }
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

    fn airCall(self: *DeclGen, inst: Air.Inst.Index, modifier: std.builtin.CallModifier) !?IdRef {
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

        return result_id;
    }
};
