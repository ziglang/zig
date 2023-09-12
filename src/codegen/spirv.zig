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
const CacheRef = SpvModule.CacheRef;
const CacheString = SpvModule.CacheString;

const SpvSection = @import("spirv/Section.zig");
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
        const mod = self.module;
        const src = LazySrcLoc.nodeOffset(0);
        const src_loc = src.toSrcLoc(self.module.declPtr(self.decl_index), mod);
        assert(self.error_msg == null);
        self.error_msg = try Module.ErrorMsg.create(self.module.gpa, src_loc, format, args);
        return error.CodegenFail;
    }

    pub fn todo(self: *DeclGen, comptime format: []const u8, args: anytype) Error {
        return self.fail("TODO (SPIR-V): " ++ format, args);
    }

    /// Fetch the result-id for a previously generated instruction or constant.
    fn resolve(self: *DeclGen, inst: Air.Inst.Ref) !IdRef {
        const mod = self.module;
        if (try self.air.value(inst, mod)) |val| {
            const ty = self.typeOf(inst);
            if (ty.zigTypeTag(mod) == .Fn) {
                const fn_decl_index = switch (mod.intern_pool.indexToKey(val.ip_index)) {
                    .extern_func => |extern_func| extern_func.decl,
                    .func => |func| func.owner_decl,
                    else => unreachable,
                };
                const spv_decl_index = try self.resolveDecl(fn_decl_index);
                try self.func.decl_deps.put(self.spv.gpa, spv_decl_index, {});
                return self.spv.declPtr(spv_decl_index).result_id;
            }

            return try self.constant(ty, val, .direct);
        }
        const index = Air.refToIndex(inst).?;
        return self.inst_results.get(index).?; // Assertion means instruction does not dominate usage.
    }

    /// Fetch or allocate a result id for decl index. This function also marks the decl as alive.
    /// Note: Function does not actually generate the decl.
    fn resolveDecl(self: *DeclGen, decl_index: Module.Decl.Index) !SpvModule.Decl.Index {
        const mod = self.module;
        const decl = mod.declPtr(decl_index);
        try mod.markDeclAlive(decl);

        const entry = try self.decl_link.getOrPut(decl_index);
        if (!entry.found_existing) {
            // TODO: Extern fn?
            const kind: SpvModule.DeclKind = if (decl.val.isFuncBody(mod))
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
        const mod = self.module;
        const target = self.getTarget();
        return switch (ty.zigTypeTag(mod)) {
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
                const int_info = ty.intInfo(mod);
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
            // else => self.todo("implement arithmeticTypeInfo for {}", .{ty.fmt(self.module)}),
            else => unreachable,
        };
    }

    /// Emits a bool constant in a particular representation.
    fn constBool(self: *DeclGen, value: bool, repr: Repr) !IdRef {
        switch (repr) {
            .indirect => {
                const int_ty_ref = try self.intType(.unsigned, 1);
                return self.spv.constInt(int_ty_ref, @intFromBool(value));
            },
            .direct => {
                const bool_ty_ref = try self.resolveType(Type.bool, .direct);
                return self.spv.constBool(bool_ty_ref, value);
            },
        }
    }

    /// Construct a struct at runtime.
    /// result_ty_ref must be a struct type.
    fn constructStruct(self: *DeclGen, result_ty_ref: CacheRef, constituents: []const IdRef) !IdRef {
        // The Khronos LLVM-SPIRV translator crashes because it cannot construct structs which'
        // operands are not constant.
        // See https://github.com/KhronosGroup/SPIRV-LLVM-Translator/issues/1349
        // For now, just initialize the struct by setting the fields manually...
        // TODO: Make this OpCompositeConstruct when we can
        const ptr_composite_id = try self.alloc(result_ty_ref, null);
        // Note: using 32-bit ints here because usize crashes the translator as well
        const index_ty_ref = try self.intType(.unsigned, 32);

        const spv_composite_ty = self.spv.cache.lookup(result_ty_ref).struct_type;
        const member_types = spv_composite_ty.member_types;

        for (constituents, member_types, 0..) |constitent_id, member_ty_ref, index| {
            const index_id = try self.spv.constInt(index_ty_ref, index);
            const ptr_member_ty_ref = try self.spv.ptrType(member_ty_ref, .Generic);
            const ptr_id = try self.accessChain(ptr_member_ty_ref, ptr_composite_id, &.{index_id});
            try self.func.body.emit(self.spv.gpa, .OpStore, .{
                .pointer = ptr_id,
                .object = constitent_id,
            });
        }
        const result_id = self.spv.allocId();
        try self.func.body.emit(self.spv.gpa, .OpLoad, .{
            .id_result_type = self.typeId(result_ty_ref),
            .id_result = result_id,
            .pointer = ptr_composite_id,
        });
        return result_id;
    }

    const IndirectConstantLowering = struct {
        const undef = 0xAA;

        dg: *DeclGen,
        /// Cached reference of the u32 type.
        u32_ty_ref: CacheRef,
        /// The members of the resulting structure type
        members: std.ArrayList(CacheRef),
        /// The initializers of each of the members.
        initializers: std.ArrayList(IdRef),
        /// The current size of the structure. Includes
        /// the bytes in partial_word.
        size: u32 = 0,
        /// The partially filled last constant.
        /// If full, its flushed.
        partial_word: std.BoundedArray(u8, @sizeOf(Word)) = .{},
        /// The declaration dependencies of the constant we are lowering.
        decl_deps: std.AutoArrayHashMap(SpvModule.Decl.Index, void),

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

            const word = @as(Word, @bitCast(self.partial_word.buffer));
            const result_id = try self.dg.spv.constInt(self.u32_ty_ref, word);
            try self.members.append(self.u32_ty_ref);
            try self.initializers.append(result_id);

            self.partial_word.len = 0;
            self.size = std.mem.alignForward(u32, self.size, @sizeOf(Word));
        }

        /// Fill the buffer with undefined values until the size is aligned to `align`.
        fn fillToAlign(self: *@This(), alignment: u32) !void {
            const target_size = std.mem.alignForward(u32, self.size, alignment);
            try self.addUndef(target_size - self.size);
        }

        fn addUndef(self: *@This(), amt: u64) !void {
            for (0..@as(usize, @intCast(amt))) |_| {
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

        fn addPtr(self: *@This(), ptr_ty_ref: CacheRef, ptr_id: IdRef) !void {
            // TODO: Double check pointer sizes here.
            // shared pointers might be u32...
            const target = self.dg.getTarget();
            const width = @divExact(target.ptrBitWidth(), 8);
            if (self.size % width != 0) {
                return self.dg.todo("misaligned pointer constants", .{});
            }
            try self.members.append(ptr_ty_ref);
            try self.initializers.append(ptr_id);
            self.size += width;
        }

        fn addNullPtr(self: *@This(), ptr_ty_ref: CacheRef) !void {
            const result_id = try self.dg.spv.constNull(ptr_ty_ref);
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
            try self.addByte(@intFromBool(value)); // TODO: Keep in sync with something?
        }

        fn addInt(self: *@This(), ty: Type, val: Value) !void {
            const mod = self.dg.module;
            const len = ty.abiSize(mod);
            if (val.isUndef(mod)) {
                try self.addUndef(len);
                return;
            }

            const int_info = ty.intInfo(mod);
            const int_bits = switch (int_info.signedness) {
                .signed => @as(u64, @bitCast(val.toSignedInt(mod))),
                .unsigned => val.toUnsignedInt(mod),
            };

            // TODO: Swap endianess if the compiler is big endian.
            try self.addBytes(std.mem.asBytes(&int_bits)[0..@as(usize, @intCast(len))]);
        }

        fn addFloat(self: *@This(), ty: Type, val: Value) !void {
            const mod = self.dg.module;
            const target = self.dg.getTarget();
            const len = ty.abiSize(mod);

            // TODO: Swap endianess if the compiler is big endian.
            switch (ty.floatBits(target)) {
                16 => {
                    const float_bits = val.toFloat(f16, mod);
                    try self.addBytes(std.mem.asBytes(&float_bits)[0..@as(usize, @intCast(len))]);
                },
                32 => {
                    const float_bits = val.toFloat(f32, mod);
                    try self.addBytes(std.mem.asBytes(&float_bits)[0..@as(usize, @intCast(len))]);
                },
                64 => {
                    const float_bits = val.toFloat(f64, mod);
                    try self.addBytes(std.mem.asBytes(&float_bits)[0..@as(usize, @intCast(len))]);
                },
                else => unreachable,
            }
        }

        fn addDeclRef(self: *@This(), ty: Type, decl_index: Decl.Index) !void {
            const dg = self.dg;
            const mod = dg.module;

            const ty_ref = try self.dg.resolveType(ty, .indirect);
            const ty_id = dg.typeId(ty_ref);

            const decl = dg.module.declPtr(decl_index);
            const spv_decl_index = try dg.resolveDecl(decl_index);

            switch (mod.intern_pool.indexToKey(decl.val.ip_index)) {
                .func => {
                    // TODO: Properly lower function pointers. For now we are going to hack around it and
                    // just generate an empty pointer. Function pointers are represented by usize for now,
                    // though.
                    try self.addInt(Type.usize, Value.zero_usize);
                    // TODO: Add dependency
                    return;
                },
                .extern_func => unreachable, // TODO
                else => {
                    const result_id = dg.spv.allocId();

                    try self.decl_deps.put(spv_decl_index, {});

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

        fn lower(self: *@This(), ty: Type, arg_val: Value) !void {
            const dg = self.dg;
            const mod = dg.module;
            const ip = &mod.intern_pool;

            var val = arg_val;
            switch (ip.indexToKey(val.toIntern())) {
                .runtime_value => |rt| val = rt.val.toValue(),
                else => {},
            }

            if (val.isUndefDeep(mod)) {
                const size = ty.abiSize(mod);
                return try self.addUndef(size);
            }

            switch (ip.indexToKey(val.toIntern())) {
                .int_type,
                .ptr_type,
                .array_type,
                .vector_type,
                .opt_type,
                .anyframe_type,
                .error_union_type,
                .simple_type,
                .struct_type,
                .anon_struct_type,
                .union_type,
                .opaque_type,
                .enum_type,
                .func_type,
                .error_set_type,
                .inferred_error_set_type,
                => unreachable, // types, not values

                .undef, .runtime_value => unreachable, // handled above
                .simple_value => |simple_value| switch (simple_value) {
                    .undefined,
                    .void,
                    .null,
                    .empty_struct,
                    .@"unreachable",
                    .generic_poison,
                    => unreachable, // non-runtime values
                    .false, .true => try self.addConstBool(val.toBool()),
                },
                .variable,
                .extern_func,
                .func,
                .enum_literal,
                .empty_enum_value,
                => unreachable, // non-runtime values
                .int => try self.addInt(ty, val),
                .err => |err| {
                    const int = try mod.getErrorValue(err.name);
                    try self.addConstInt(u16, @as(u16, @intCast(int)));
                },
                .error_union => |error_union| {
                    const err_ty = switch (error_union.val) {
                        .err_name => ty.errorUnionSet(mod),
                        .payload => Type.err_int,
                    };
                    const err_val = switch (error_union.val) {
                        .err_name => |err_name| (try mod.intern(.{ .err = .{
                            .ty = ty.errorUnionSet(mod).toIntern(),
                            .name = err_name,
                        } })).toValue(),
                        .payload => try mod.intValue(Type.err_int, 0),
                    };
                    const payload_ty = ty.errorUnionPayload(mod);
                    const eu_layout = dg.errorUnionLayout(payload_ty);
                    if (!eu_layout.payload_has_bits) {
                        // We use the error type directly as the type.
                        try self.lower(err_ty, err_val);
                        return;
                    }

                    const payload_size = payload_ty.abiSize(mod);
                    const error_size = err_ty.abiSize(mod);
                    const ty_size = ty.abiSize(mod);
                    const padding = ty_size - payload_size - error_size;

                    const payload_val = switch (error_union.val) {
                        .err_name => try mod.intern(.{ .undef = payload_ty.toIntern() }),
                        .payload => |payload| payload,
                    }.toValue();

                    if (eu_layout.error_first) {
                        try self.lower(err_ty, err_val);
                        try self.lower(payload_ty, payload_val);
                    } else {
                        try self.lower(payload_ty, payload_val);
                        try self.lower(err_ty, err_val);
                    }

                    try self.addUndef(padding);
                },
                .enum_tag => {
                    const int_val = try val.intFromEnum(ty, mod);

                    const int_ty = ty.intTagType(mod);

                    try self.lower(int_ty, int_val);
                },
                .float => try self.addFloat(ty, val),
                .ptr => |ptr| {
                    const ptr_ty = switch (ptr.len) {
                        .none => ty,
                        else => ty.slicePtrFieldType(mod),
                    };
                    switch (ptr.addr) {
                        .decl => |decl| try self.addDeclRef(ptr_ty, decl),
                        .mut_decl => |mut_decl| try self.addDeclRef(ptr_ty, mut_decl.decl),
                        .int => |int| try self.addInt(Type.usize, int.toValue()),
                        else => |tag| return dg.todo("pointer value of type {s}", .{@tagName(tag)}),
                    }
                    if (ptr.len != .none) {
                        try self.addInt(Type.usize, ptr.len.toValue());
                    }
                },
                .opt => {
                    const payload_ty = ty.optionalChild(mod);
                    const payload_val = val.optionalValue(mod);
                    const abi_size = ty.abiSize(mod);

                    if (!payload_ty.hasRuntimeBits(mod)) {
                        try self.addConstBool(payload_val != null);
                        return;
                    } else if (ty.optionalReprIsPayload(mod)) {
                        // Optional representation is a nullable pointer or slice.
                        if (payload_val) |pl_val| {
                            try self.lower(payload_ty, pl_val);
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
                    const payload_size = payload_ty.abiSize(mod);
                    const padding = abi_size - payload_size - 1;

                    if (payload_val) |pl_val| {
                        try self.lower(payload_ty, pl_val);
                    } else {
                        try self.addUndef(payload_size);
                    }
                    try self.addConstBool(payload_val != null);
                    try self.addUndef(padding);
                },
                .aggregate => |aggregate| switch (ip.indexToKey(ty.ip_index)) {
                    .array_type => |array_type| {
                        const elem_ty = array_type.child.toType();
                        switch (aggregate.storage) {
                            .bytes => |bytes| try self.addBytes(bytes),
                            .elems, .repeated_elem => {
                                for (0..@as(usize, @intCast(array_type.len))) |i| {
                                    try self.lower(elem_ty, switch (aggregate.storage) {
                                        .bytes => unreachable,
                                        .elems => |elem_vals| elem_vals[@as(usize, @intCast(i))].toValue(),
                                        .repeated_elem => |elem_val| elem_val.toValue(),
                                    });
                                }
                            },
                        }
                        if (array_type.sentinel != .none) {
                            try self.lower(elem_ty, array_type.sentinel.toValue());
                        }
                    },
                    .vector_type => return dg.todo("indirect constant of type {}", .{ty.fmt(mod)}),
                    .struct_type => {
                        const struct_ty = mod.typeToStruct(ty).?;
                        if (struct_ty.layout == .Packed) {
                            return dg.todo("packed struct constants", .{});
                        }

                        const struct_begin = self.size;
                        for (struct_ty.fields.values(), 0..) |field, i| {
                            if (field.is_comptime or !field.ty.hasRuntimeBits(mod)) continue;

                            const field_val = switch (aggregate.storage) {
                                .bytes => |bytes| try ip.get(mod.gpa, .{ .int = .{
                                    .ty = field.ty.toIntern(),
                                    .storage = .{ .u64 = bytes[i] },
                                } }),
                                .elems => |elems| elems[i],
                                .repeated_elem => |elem| elem,
                            };
                            try self.lower(field.ty, field_val.toValue());

                            // Add padding if required.
                            // TODO: Add to type generation as well?
                            const unpadded_field_end = self.size - struct_begin;
                            const padded_field_end = ty.structFieldOffset(i + 1, mod);
                            const padding = padded_field_end - unpadded_field_end;
                            try self.addUndef(padding);
                        }
                    },
                    .anon_struct_type => unreachable, // TODO
                    else => unreachable,
                },
                .un => |un| {
                    const layout = ty.unionGetLayout(mod);

                    if (layout.payload_size == 0) {
                        return try self.lower(ty.unionTagTypeSafety(mod).?, un.tag.toValue());
                    }

                    const union_obj = mod.typeToUnion(ty).?;
                    if (union_obj.getLayout(ip) == .Packed) {
                        return dg.todo("packed union constants", .{});
                    }

                    const active_field = ty.unionTagFieldIndex(un.tag.toValue(), dg.module).?;
                    const active_field_ty = union_obj.field_types.get(ip)[active_field].toType();

                    const has_tag = layout.tag_size != 0;
                    const tag_first = layout.tag_align >= layout.payload_align;

                    if (has_tag and tag_first) {
                        try self.lower(ty.unionTagTypeSafety(mod).?, un.tag.toValue());
                    }

                    const active_field_size = if (active_field_ty.hasRuntimeBitsIgnoreComptime(mod)) blk: {
                        try self.lower(active_field_ty, un.val.toValue());
                        break :blk active_field_ty.abiSize(mod);
                    } else 0;

                    const payload_padding_len = layout.payload_size - active_field_size;
                    try self.addUndef(payload_padding_len);

                    if (has_tag and !tag_first) {
                        try self.lower(ty.unionTagTypeSafety(mod).?, un.tag.toValue());
                    }

                    try self.addUndef(layout.padding);
                },
                .memoized_call => unreachable,
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

        const var_id = self.spv.allocId();
        log.debug("lowerIndirectConstant: id = {}, index = {}, ty = {}, val = {}", .{ var_id.id, @intFromEnum(spv_decl_index), ty.fmt(self.module), val.fmtDebug() });

        const section = &self.spv.globals.section;

        const ty_ref = try self.resolveType(ty, .indirect);
        const ptr_ty_ref = try self.spv.ptrType(ty_ref, storage_class);

        // const target = self.getTarget();

        // TODO: Fix the resulting global linking for these paths.
        // if (val.isUndef(mod)) {
        //     // Special case: the entire value is undefined. In this case, we can just
        //     // generate an OpVariable with no initializer.
        //     return try section.emit(self.spv.gpa, .OpVariable, .{
        //         .id_result_type = self.typeId(ptr_ty_ref),
        //         .id_result = result_id,
        //         .storage_class = storage_class,
        //     });
        // } else if (ty.abiSize(mod) == 0) {
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
            .members = std.ArrayList(CacheRef).init(self.gpa),
            .initializers = std.ArrayList(IdRef).init(self.gpa),
            .decl_deps = std.AutoArrayHashMap(SpvModule.Decl.Index, void).init(self.gpa),
        };

        defer icl.members.deinit();
        defer icl.initializers.deinit();
        defer icl.decl_deps.deinit();

        try icl.lower(ty, val);
        try icl.flush();

        const constant_struct_ty_ref = try self.spv.resolve(.{ .struct_type = .{
            .member_types = icl.members.items,
        } });
        const ptr_constant_struct_ty_ref = try self.spv.ptrType(constant_struct_ty_ref, storage_class);

        const constant_struct_id = self.spv.allocId();
        try section.emit(self.spv.gpa, .OpSpecConstantComposite, .{
            .id_result_type = self.typeId(constant_struct_ty_ref),
            .id_result = constant_struct_id,
            .constituents = icl.initializers.items,
        });

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
            const generic_ptr_ty_ref = try self.spv.ptrType(ty_ref, .Generic);
            try section.emitSpecConstantOp(self.spv.gpa, .OpPtrCastToGeneric, .{
                .id_result_type = self.typeId(generic_ptr_ty_ref),
                .id_result = result_id,
                .pointer = bitcast_result_id,
            });
        }

        try self.spv.declareDeclDeps(spv_decl_index, icl.decl_deps.keys());
        self.spv.endGlobal(spv_decl_index, begin_inst);
    }

    /// This function generates a load for a constant in direct (ie, non-memory) representation.
    /// When the constant is simple, it can be generated directly using OpConstant instructions. When
    /// the constant is more complicated however, it needs to be lowered to an indirect constant, which
    /// is then loaded using OpLoad. Such values are loaded into the UniformConstant storage class by default.
    /// This function should only be called during function code generation.
    fn constant(self: *DeclGen, ty: Type, arg_val: Value, repr: Repr) !IdRef {
        const mod = self.module;
        const target = self.getTarget();
        const result_ty_ref = try self.resolveType(ty, repr);

        var val = arg_val;
        switch (mod.intern_pool.indexToKey(val.toIntern())) {
            .runtime_value => |rt| val = rt.val.toValue(),
            else => {},
        }

        log.debug("constant: ty = {}, val = {}", .{ ty.fmt(self.module), val.fmtValue(ty, self.module) });
        if (val.isUndef(mod)) {
            return self.spv.constUndef(result_ty_ref);
        }

        switch (mod.intern_pool.indexToKey(val.toIntern())) {
            .int_type,
            .ptr_type,
            .array_type,
            .vector_type,
            .opt_type,
            .anyframe_type,
            .error_union_type,
            .simple_type,
            .struct_type,
            .anon_struct_type,
            .union_type,
            .opaque_type,
            .enum_type,
            .func_type,
            .error_set_type,
            .inferred_error_set_type,
            => unreachable, // types, not values

            .undef => unreachable, // handled above
            .runtime_value => unreachable, // ???

            .variable,
            .extern_func,
            .func,
            .enum_literal,
            .empty_enum_value,
            => unreachable, // non-runtime values

            .simple_value => |simple_value| switch (simple_value) {
                .undefined,
                .void,
                .null,
                .empty_struct,
                .@"unreachable",
                .generic_poison,
                => unreachable, // non-runtime values

                .false, .true => switch (repr) {
                    .direct => return try self.spv.constBool(result_ty_ref, val.toBool()),
                    .indirect => return try self.spv.constInt(result_ty_ref, @intFromBool(val.toBool())),
                },
            },

            .int => {
                if (ty.isSignedInt(mod)) {
                    return try self.spv.constInt(result_ty_ref, val.toSignedInt(mod));
                } else {
                    return try self.spv.constInt(result_ty_ref, val.toUnsignedInt(mod));
                }
            },
            .float => return switch (ty.floatBits(target)) {
                16 => try self.spv.resolveId(.{ .float = .{ .ty = result_ty_ref, .value = .{ .float16 = val.toFloat(f16, mod) } } }),
                32 => try self.spv.resolveId(.{ .float = .{ .ty = result_ty_ref, .value = .{ .float32 = val.toFloat(f32, mod) } } }),
                64 => try self.spv.resolveId(.{ .float = .{ .ty = result_ty_ref, .value = .{ .float64 = val.toFloat(f64, mod) } } }),
                80, 128 => unreachable, // TODO
                else => unreachable,
            },
            .err => |err| {
                const value = try mod.getErrorValue(err.name);
                return try self.spv.constInt(result_ty_ref, value);
            },
            // TODO: We can handle most pointers here (decl refs etc), because now they emit an extra
            // OpVariable that is not really required.
            else => {
                // The value cannot be generated directly, so generate it as an indirect constant,
                // and then perform an OpLoad.
                const result_id = self.spv.allocId();
                const alignment = ty.abiAlignment(mod);
                const spv_decl_index = try self.spv.allocDecl(.global);

                try self.lowerIndirectConstant(
                    spv_decl_index,
                    ty,
                    val,
                    .UniformConstant,
                    false,
                    alignment,
                );
                log.debug("indirect constant: index = {}", .{@intFromEnum(spv_decl_index)});
                try self.func.decl_deps.put(self.spv.gpa, spv_decl_index, {});

                try self.func.body.emit(self.spv.gpa, .OpLoad, .{
                    .id_result_type = self.typeId(result_ty_ref),
                    .id_result = result_id,
                    .pointer = self.spv.declPtr(spv_decl_index).result_id,
                });
                // TODO: Convert bools? This logic should hook into `load`. It should be a dead
                // path though considering .Bool is handled above.
                return result_id;
            },
        }
    }

    /// Turn a Zig type into a SPIR-V Type, and return its type result-id.
    fn resolveTypeId(self: *DeclGen, ty: Type) !IdResultType {
        const type_ref = try self.resolveType(ty, .direct);
        return self.spv.resultId(type_ref);
    }

    fn typeId(self: *DeclGen, ty_ref: CacheRef) IdRef {
        return self.spv.resultId(ty_ref);
    }

    /// Create an integer type suitable for storing at least 'bits' bits.
    /// The integer type that is returned by this function is the type that is used to perform
    /// actual operations (as well as store) a Zig type of a particular number of bits. To create
    /// a type with an exact size, use SpvModule.intType.
    fn intType(self: *DeclGen, signedness: std.builtin.Signedness, bits: u16) !CacheRef {
        const backing_bits = self.backingIntBits(bits) orelse {
            // TODO: Integers too big for any native type are represented as "composite integers":
            // An array of largestSupportedIntBits.
            return self.todo("Implement {s} composite int type of {} bits", .{ @tagName(signedness), bits });
        };
        return self.spv.intType(signedness, backing_bits);
    }

    /// Create an integer type that represents 'usize'.
    fn sizeType(self: *DeclGen) !CacheRef {
        return try self.intType(.unsigned, self.getTarget().ptrBitWidth());
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
    fn resolveUnionType(self: *DeclGen, ty: Type, maybe_active_field: ?usize) !CacheRef {
        const mod = self.module;
        const ip = &mod.intern_pool;
        const layout = ty.unionGetLayout(mod);
        const union_obj = mod.typeToUnion(ty).?;

        if (union_obj.getLayout(ip) == .Packed) {
            return self.todo("packed union types", .{});
        }

        if (layout.payload_size == 0) {
            // No payload, so represent this as just the tag type.
            return try self.resolveType(union_obj.enum_tag_ty.toType(), .indirect);
        }

        var member_types = std.BoundedArray(CacheRef, 4){};
        var member_names = std.BoundedArray(CacheString, 4){};

        const has_tag = layout.tag_size != 0;
        const tag_first = layout.tag_align >= layout.payload_align;
        const u8_ty_ref = try self.intType(.unsigned, 8); // TODO: What if Int8Type is not enabled?

        if (has_tag and tag_first) {
            const tag_ty_ref = try self.resolveType(union_obj.enum_tag_ty.toType(), .indirect);
            member_types.appendAssumeCapacity(tag_ty_ref);
            member_names.appendAssumeCapacity(try self.spv.resolveString("tag"));
        }

        const active_field = maybe_active_field orelse layout.most_aligned_field;
        const active_field_ty = union_obj.field_types.get(ip)[active_field].toType();

        const active_field_size = if (active_field_ty.hasRuntimeBitsIgnoreComptime(mod)) blk: {
            const active_payload_ty_ref = try self.resolveType(active_field_ty, .indirect);
            member_types.appendAssumeCapacity(active_payload_ty_ref);
            member_names.appendAssumeCapacity(try self.spv.resolveString("payload"));
            break :blk active_field_ty.abiSize(mod);
        } else 0;

        const payload_padding_len = layout.payload_size - active_field_size;
        if (payload_padding_len != 0) {
            const payload_padding_ty_ref = try self.spv.arrayType(@as(u32, @intCast(payload_padding_len)), u8_ty_ref);
            member_types.appendAssumeCapacity(payload_padding_ty_ref);
            member_names.appendAssumeCapacity(try self.spv.resolveString("payload_padding"));
        }

        if (has_tag and !tag_first) {
            const tag_ty_ref = try self.resolveType(union_obj.enum_tag_ty.toType(), .indirect);
            member_types.appendAssumeCapacity(tag_ty_ref);
            member_names.appendAssumeCapacity(try self.spv.resolveString("tag"));
        }

        if (layout.padding != 0) {
            const padding_ty_ref = try self.spv.arrayType(layout.padding, u8_ty_ref);
            member_types.appendAssumeCapacity(padding_ty_ref);
            member_names.appendAssumeCapacity(try self.spv.resolveString("padding"));
        }

        return try self.spv.resolve(.{ .struct_type = .{
            .member_types = member_types.slice(),
            .member_names = member_names.slice(),
        } });
    }

    /// Turn a Zig type into a SPIR-V Type, and return a reference to it.
    fn resolveType(self: *DeclGen, ty: Type, repr: Repr) Error!CacheRef {
        const mod = self.module;
        const ip = &mod.intern_pool;
        log.debug("resolveType: ty = {}", .{ty.fmt(self.module)});
        const target = self.getTarget();
        switch (ty.zigTypeTag(mod)) {
            .Void, .NoReturn => return try self.spv.resolve(.void_type),
            .Bool => switch (repr) {
                .direct => return try self.spv.resolve(.bool_type),
                .indirect => return try self.intType(.unsigned, 1),
            },
            .Int => {
                const int_info = ty.intInfo(mod);
                return try self.intType(int_info.signedness, int_info.bits);
            },
            .Enum => {
                const tag_ty = ty.intTagType(mod);
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

                return try self.spv.resolve(.{ .float_type = .{ .bits = bits } });
            },
            .Array => {
                const elem_ty = ty.childType(mod);
                const elem_ty_ref = try self.resolveType(elem_ty, .direct);
                const total_len = std.math.cast(u32, ty.arrayLenIncludingSentinel(mod)) orelse {
                    return self.fail("array type of {} elements is too large", .{ty.arrayLenIncludingSentinel(mod)});
                };
                return self.spv.arrayType(total_len, elem_ty_ref);
            },
            .Fn => switch (repr) {
                .direct => {
                    const fn_info = mod.typeToFunc(ty).?;
                    // TODO: Put this somewhere in Sema.zig
                    if (fn_info.is_var_args)
                        return self.fail("VarArgs functions are unsupported for SPIR-V", .{});

                    const param_ty_refs = try self.gpa.alloc(CacheRef, fn_info.param_types.len);
                    defer self.gpa.free(param_ty_refs);
                    for (param_ty_refs, fn_info.param_types.get(ip)) |*param_type, fn_param_type| {
                        param_type.* = try self.resolveType(fn_param_type.toType(), .direct);
                    }
                    const return_ty_ref = try self.resolveType(fn_info.return_type.toType(), .direct);

                    return try self.spv.resolve(.{ .function_type = .{
                        .return_type = return_ty_ref,
                        .parameters = param_ty_refs,
                    } });
                },
                .indirect => {
                    // TODO: Represent function pointers properly.
                    // For now, just use an usize type.
                    return try self.sizeType();
                },
            },
            .Pointer => {
                const ptr_info = ty.ptrInfo(mod);

                const storage_class = spvStorageClass(ptr_info.flags.address_space);
                const child_ty_ref = try self.resolveType(ptr_info.child.toType(), .indirect);
                const ptr_ty_ref = try self.spv.resolve(.{ .ptr_type = .{
                    .storage_class = storage_class,
                    .child_type = child_ty_ref,
                } });
                if (ptr_info.flags.size != .Slice) {
                    return ptr_ty_ref;
                }

                const size_ty_ref = try self.sizeType();
                return self.spv.resolve(.{ .struct_type = .{
                    .member_types = &.{ ptr_ty_ref, size_ty_ref },
                    .member_names = &.{
                        try self.spv.resolveString("ptr"),
                        try self.spv.resolveString("len"),
                    },
                } });
            },
            .Vector => {
                // Although not 100% the same, Zig vectors map quite neatly to SPIR-V vectors (including many integer and float operations
                // which work on them), so simply use those.
                // Note: SPIR-V vectors only support bools, ints and floats, so pointer vectors need to be supported another way.
                // "composite integers" (larger than the largest supported native type) can probably be represented by an array of vectors.
                // TODO: The SPIR-V spec mentions that vector sizes may be quite restricted! look into which we can use, and whether OpTypeVector
                // is adequate at all for this.

                // TODO: Properly verify sizes and child type.

                return try self.spv.resolve(.{ .vector_type = .{
                    .component_type = try self.resolveType(ty.childType(mod), repr),
                    .component_count = @as(u32, @intCast(ty.vectorLen(mod))),
                } });
            },
            .Struct => {
                const struct_ty = switch (ip.indexToKey(ty.toIntern())) {
                    .anon_struct_type => |tuple| {
                        const member_types = try self.gpa.alloc(CacheRef, tuple.values.len);
                        defer self.gpa.free(member_types);

                        var member_index: usize = 0;
                        for (tuple.types.get(ip), tuple.values.get(ip)) |field_ty, field_val| {
                            if (field_val != .none or !field_ty.toType().hasRuntimeBits(mod)) continue;

                            member_types[member_index] = try self.resolveType(field_ty.toType(), .indirect);
                            member_index += 1;
                        }

                        return try self.spv.resolve(.{ .struct_type = .{
                            .member_types = member_types[0..member_index],
                        } });
                    },
                    .struct_type => |struct_ty| struct_ty,
                    else => unreachable,
                };

                const struct_obj = mod.structPtrUnwrap(struct_ty.index).?;
                if (struct_obj.layout == .Packed) {
                    return try self.resolveType(struct_obj.backing_int_ty, .direct);
                }

                var member_types = std.ArrayList(CacheRef).init(self.gpa);
                defer member_types.deinit();

                var member_names = std.ArrayList(CacheString).init(self.gpa);
                defer member_names.deinit();

                var it = struct_obj.runtimeFieldIterator(mod);
                while (it.next()) |field_and_index| {
                    const field = field_and_index.field;
                    const index = field_and_index.index;
                    const field_name = ip.stringToSlice(struct_obj.fields.keys()[index]);
                    try member_types.append(try self.resolveType(field.ty, .indirect));
                    try member_names.append(try self.spv.resolveString(field_name));
                }

                const name = ip.stringToSlice(try struct_obj.getFullyQualifiedName(self.module));

                return try self.spv.resolve(.{ .struct_type = .{
                    .name = try self.spv.resolveString(name),
                    .member_types = member_types.items,
                    .member_names = member_names.items,
                } });
            },
            .Optional => {
                const payload_ty = ty.optionalChild(mod);
                if (!payload_ty.hasRuntimeBitsIgnoreComptime(mod)) {
                    // Just use a bool.
                    // Note: Always generate the bool with indirect format, to save on some sanity
                    // Perform the conversion to a direct bool when the field is extracted.
                    return try self.resolveType(Type.bool, .indirect);
                }

                const payload_ty_ref = try self.resolveType(payload_ty, .indirect);
                if (ty.optionalReprIsPayload(mod)) {
                    // Optional is actually a pointer or a slice.
                    return payload_ty_ref;
                }

                const bool_ty_ref = try self.resolveType(Type.bool, .indirect);

                return try self.spv.resolve(.{ .struct_type = .{
                    .member_types = &.{ payload_ty_ref, bool_ty_ref },
                    .member_names = &.{
                        try self.spv.resolveString("payload"),
                        try self.spv.resolveString("valid"),
                    },
                } });
            },
            .Union => return try self.resolveUnionType(ty, null),
            .ErrorSet => return try self.intType(.unsigned, 16),
            .ErrorUnion => {
                const payload_ty = ty.errorUnionPayload(mod);
                const error_ty_ref = try self.resolveType(Type.anyerror, .indirect);

                const eu_layout = self.errorUnionLayout(payload_ty);
                if (!eu_layout.payload_has_bits) {
                    return error_ty_ref;
                }

                const payload_ty_ref = try self.resolveType(payload_ty, .indirect);

                var member_types: [2]CacheRef = undefined;
                var member_names: [2]CacheString = undefined;
                if (eu_layout.error_first) {
                    // Put the error first
                    member_types = .{ error_ty_ref, payload_ty_ref };
                    member_names = .{
                        try self.spv.resolveString("error"),
                        try self.spv.resolveString("payload"),
                    };
                    // TODO: ABI padding?
                } else {
                    // Put the payload first.
                    member_types = .{ payload_ty_ref, error_ty_ref };
                    member_names = .{
                        try self.spv.resolveString("payload"),
                        try self.spv.resolveString("error"),
                    };
                    // TODO: ABI padding?
                }

                return try self.spv.resolve(.{ .struct_type = .{
                    .member_types = &member_types,
                    .member_names = &member_names,
                } });
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

    const ErrorUnionLayout = struct {
        payload_has_bits: bool,
        error_first: bool,

        fn errorFieldIndex(self: @This()) u32 {
            assert(self.payload_has_bits);
            return if (self.error_first) 0 else 1;
        }

        fn payloadFieldIndex(self: @This()) u32 {
            assert(self.payload_has_bits);
            return if (self.error_first) 1 else 0;
        }
    };

    fn errorUnionLayout(self: *DeclGen, payload_ty: Type) ErrorUnionLayout {
        const mod = self.module;

        const error_align = Type.anyerror.abiAlignment(mod);
        const payload_align = payload_ty.abiAlignment(mod);

        const error_first = error_align > payload_align;
        return .{
            .payload_has_bits = payload_ty.hasRuntimeBitsIgnoreComptime(mod),
            .error_first = error_first,
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
        const ptr_anyerror_ty_ref = try self.spv.ptrType(anyerror_ty_ref, .CrossWorkgroup);
        const void_ty_ref = try self.resolveType(Type.void, .direct);

        const kernel_proto_ty_ref = try self.spv.resolve(.{ .function_type = .{
            .return_type = void_ty_ref,
            .parameters = &.{ptr_anyerror_ty_ref},
        } });

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
        const mod = self.module;
        const ip = &mod.intern_pool;
        const decl = mod.declPtr(self.decl_index);
        const spv_decl_index = try self.resolveDecl(self.decl_index);

        const decl_id = self.spv.declPtr(spv_decl_index).result_id;

        if (decl.val.getFunction(mod)) |_| {
            assert(decl.ty.zigTypeTag(mod) == .Fn);
            const prototype_id = try self.resolveTypeId(decl.ty);
            try self.func.prologue.emit(self.spv.gpa, .OpFunction, .{
                .id_result_type = try self.resolveTypeId(decl.ty.fnReturnType(mod)),
                .id_result = decl_id,
                .function_control = .{}, // TODO: We can set inline here if the type requires it.
                .function_type = prototype_id,
            });

            const fn_info = mod.typeToFunc(decl.ty).?;

            try self.args.ensureUnusedCapacity(self.gpa, fn_info.param_types.len);
            for (0..fn_info.param_types.len) |i| {
                const param_type = fn_info.param_types.get(ip)[i];
                const param_type_id = try self.resolveTypeId(param_type.toType());
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

            const fqn = ip.stringToSlice(try decl.getFullyQualifiedName(self.module));

            try self.spv.sections.debug_names.emit(self.gpa, .OpName, .{
                .target = decl_id,
                .name = fqn,
            });

            // Temporarily generate a test kernel declaration if this is a test function.
            if (self.module.test_functions.contains(self.decl_index)) {
                try self.generateTestEntryPoint(fqn, spv_decl_index);
            }
        } else {
            const init_val = if (decl.val.getVariable(mod)) |payload|
                payload.init.toValue()
            else
                decl.val;

            if (init_val.ip_index == .unreachable_value) {
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
                @as(u32, @intCast(decl.alignment.toByteUnits(0))),
            );
        }
    }

    fn intFromBool(self: *DeclGen, result_ty_ref: CacheRef, condition_id: IdRef) !IdRef {
        const zero_id = try self.spv.constInt(result_ty_ref, 0);
        const one_id = try self.spv.constInt(result_ty_ref, 1);
        const result_id = self.spv.allocId();
        try self.func.body.emit(self.spv.gpa, .OpSelect, .{
            .id_result_type = self.typeId(result_ty_ref),
            .id_result = result_id,
            .condition = condition_id,
            .object_1 = one_id,
            .object_2 = zero_id,
        });
        return result_id;
    }

    /// Convert representation from indirect (in memory) to direct (in 'register')
    /// This converts the argument type from resolveType(ty, .indirect) to resolveType(ty, .direct).
    fn convertToDirect(self: *DeclGen, ty: Type, operand_id: IdRef) !IdRef {
        const mod = self.module;
        return switch (ty.zigTypeTag(mod)) {
            .Bool => blk: {
                const direct_bool_ty_ref = try self.resolveType(ty, .direct);
                const indirect_bool_ty_ref = try self.resolveType(ty, .indirect);
                const zero_id = try self.spv.constInt(indirect_bool_ty_ref, 0);
                const result_id = self.spv.allocId();
                try self.func.body.emit(self.spv.gpa, .OpINotEqual, .{
                    .id_result_type = self.typeId(direct_bool_ty_ref),
                    .id_result = result_id,
                    .operand_1 = operand_id,
                    .operand_2 = zero_id,
                });
                break :blk result_id;
            },
            else => operand_id,
        };
    }

    /// Convert representation from direct (in 'register) to direct (in memory)
    /// This converts the argument type from resolveType(ty, .direct) to resolveType(ty, .indirect).
    fn convertToIndirect(self: *DeclGen, ty: Type, operand_id: IdRef) !IdRef {
        const mod = self.module;
        return switch (ty.zigTypeTag(mod)) {
            .Bool => blk: {
                const indirect_bool_ty_ref = try self.resolveType(ty, .indirect);
                break :blk self.intFromBool(indirect_bool_ty_ref, operand_id);
            },
            else => operand_id,
        };
    }

    fn extractField(self: *DeclGen, result_ty: Type, object: IdRef, field: u32) !IdRef {
        const result_ty_ref = try self.resolveType(result_ty, .indirect);
        const result_id = self.spv.allocId();
        const indexes = [_]u32{field};
        try self.func.body.emit(self.spv.gpa, .OpCompositeExtract, .{
            .id_result_type = self.typeId(result_ty_ref),
            .id_result = result_id,
            .composite = object,
            .indexes = &indexes,
        });
        // Convert bools; direct structs have their field types as indirect values.
        return try self.convertToDirect(result_ty, result_id);
    }

    fn load(self: *DeclGen, ptr_ty: Type, ptr_id: IdRef) !IdRef {
        const mod = self.module;
        const value_ty = ptr_ty.childType(mod);
        const indirect_value_ty_ref = try self.resolveType(value_ty, .indirect);
        const result_id = self.spv.allocId();
        const access = spec.MemoryAccess.Extended{
            .Volatile = ptr_ty.isVolatilePtr(mod),
        };
        try self.func.body.emit(self.spv.gpa, .OpLoad, .{
            .id_result_type = self.typeId(indirect_value_ty_ref),
            .id_result = result_id,
            .pointer = ptr_id,
            .memory_access = access,
        });
        return try self.convertToDirect(value_ty, result_id);
    }

    fn store(self: *DeclGen, ptr_ty: Type, ptr_id: IdRef, value_id: IdRef) !void {
        const mod = self.module;
        const value_ty = ptr_ty.childType(mod);
        const indirect_value_id = try self.convertToIndirect(value_ty, value_id);
        const access = spec.MemoryAccess.Extended{
            .Volatile = ptr_ty.isVolatilePtr(mod),
        };
        try self.func.body.emit(self.spv.gpa, .OpStore, .{
            .pointer = ptr_id,
            .object = indirect_value_id,
            .memory_access = access,
        });
    }

    fn genBody(self: *DeclGen, body: []const Air.Inst.Index) Error!void {
        for (body) |inst| {
            try self.genInst(inst);
        }
    }

    fn genInst(self: *DeclGen, inst: Air.Inst.Index) !void {
        const mod = self.module;
        const ip = &mod.intern_pool;
        // TODO: remove now-redundant isUnused calls from AIR handler functions
        if (self.liveness.isUnused(inst) and !self.air.mustLower(inst, ip))
            return;

        const air_tags = self.air.instructions.items(.tag);
        const maybe_result_id: ?IdRef = switch (air_tags[inst]) {
            // zig fmt: off
            .add, .add_wrap => try self.airArithOp(inst, .OpFAdd, .OpIAdd, .OpIAdd, true),
            .sub, .sub_wrap => try self.airArithOp(inst, .OpFSub, .OpISub, .OpISub, true),
            .mul, .mul_wrap => try self.airArithOp(inst, .OpFMul, .OpIMul, .OpIMul, true),

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

            .ptr_add => try self.airPtrAdd(inst),
            .ptr_sub => try self.airPtrSub(inst),

            .bit_and  => try self.airBinOpSimple(inst, .OpBitwiseAnd),
            .bit_or   => try self.airBinOpSimple(inst, .OpBitwiseOr),
            .xor      => try self.airBinOpSimple(inst, .OpBitwiseXor),
            .bool_and => try self.airBinOpSimple(inst, .OpLogicalAnd),
            .bool_or  => try self.airBinOpSimple(inst, .OpLogicalOr),

            .shl => try self.airShift(inst, .OpShiftLeftLogical),

            .bitcast         => try self.airBitCast(inst),
            .intcast, .trunc => try self.airIntCast(inst),
            .int_from_ptr        => try self.airIntFromPtr(inst),
            .float_from_int    => try self.airFloatFromInt(inst),
            .int_from_float    => try self.airIntFromFloat(inst),
            .not             => try self.airNot(inst),

            .slice_ptr      => try self.airSliceField(inst, 0),
            .slice_len      => try self.airSliceField(inst, 1),
            .slice_elem_ptr => try self.airSliceElemPtr(inst),
            .slice_elem_val => try self.airSliceElemVal(inst),
            .ptr_elem_ptr   => try self.airPtrElemPtr(inst),
            .ptr_elem_val   => try self.airPtrElemVal(inst),

            .get_union_tag => try self.airGetUnionTag(inst),
            .struct_field_val => try self.airStructFieldVal(inst),

            .struct_field_ptr_index_0 => try self.airStructFieldPtrIndex(inst, 0),
            .struct_field_ptr_index_1 => try self.airStructFieldPtrIndex(inst, 1),
            .struct_field_ptr_index_2 => try self.airStructFieldPtrIndex(inst, 2),
            .struct_field_ptr_index_3 => try self.airStructFieldPtrIndex(inst, 3),

            .cmp_eq  => try self.airCmp(inst, .eq),
            .cmp_neq => try self.airCmp(inst, .neq),
            .cmp_gt  => try self.airCmp(inst, .gt),
            .cmp_gte => try self.airCmp(inst, .gte),
            .cmp_lt  => try self.airCmp(inst, .lt),
            .cmp_lte => try self.airCmp(inst, .lte),

            .arg     => self.airArg(),
            .alloc   => try self.airAlloc(inst),
            // TODO: We probably need to have a special implementation of this for the C abi.
            .ret_ptr => try self.airAlloc(inst),
            .block   => try self.airBlock(inst),

            .load               => try self.airLoad(inst),
            .store, .store_safe => return self.airStore(inst),

            .br             => return self.airBr(inst),
            .breakpoint     => return,
            .cond_br        => return self.airCondBr(inst),
            .dbg_stmt       => return self.airDbgStmt(inst),
            .loop           => return self.airLoop(inst),
            .ret            => return self.airRet(inst),
            .ret_load       => return self.airRetLoad(inst),
            .@"try"         => try self.airTry(inst),
            .switch_br      => return self.airSwitchBr(inst),
            .unreach, .trap => return self.airUnreach(),

            .unwrap_errunion_err => try self.airErrUnionErr(inst),
            .wrap_errunion_err => try self.airWrapErrUnionErr(inst),

            .is_null     => try self.airIsNull(inst, .is_null),
            .is_non_null => try self.airIsNull(inst, .is_non_null),

            .optional_payload => try self.airUnwrapOptional(inst),
            .wrap_optional    => try self.airWrapOptional(inst),

            .assembly => try self.airAssembly(inst),

            .call              => try self.airCall(inst, .auto),
            .call_always_tail  => try self.airCall(inst, .always_tail),
            .call_never_tail   => try self.airCall(inst, .never_tail),
            .call_never_inline => try self.airCall(inst, .never_inline),

            .dbg_inline_begin => return,
            .dbg_inline_end   => return,
            .dbg_var_ptr      => return,
            .dbg_var_val      => return,
            .dbg_block_begin  => return,
            .dbg_block_end    => return,
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
        const result_type_id = try self.resolveTypeId(self.typeOfIndex(inst));
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
        const result_type_id = try self.resolveTypeId(self.typeOfIndex(inst));

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

    fn maskStrangeInt(self: *DeclGen, ty_ref: CacheRef, value_id: IdRef, bits: u16) !IdRef {
        const mask_value = if (bits == 64) 0xFFFF_FFFF_FFFF_FFFF else (@as(u64, 1) << @as(u6, @intCast(bits))) - 1;
        const result_id = self.spv.allocId();
        const mask_id = try self.spv.constInt(ty_ref, mask_value);
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
        const ty = self.typeOfIndex(inst);
        const bin_op = self.air.instructions.items(.data)[inst].bin_op;
        var lhs_id = try self.resolve(bin_op.lhs);
        var rhs_id = try self.resolve(bin_op.rhs);

        const result_ty_ref = try self.resolveType(ty, .direct);

        assert(self.typeOf(bin_op.lhs).eql(ty, self.module));
        assert(self.typeOf(bin_op.rhs).eql(ty, self.module));

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

        const operand_ty = self.typeOf(extra.lhs);
        const result_ty = self.typeOfIndex(inst);

        const info = try self.arithmeticTypeInfo(operand_ty);
        switch (info.class) {
            .composite_integer => return self.todo("overflow ops for composite integers", .{}),
            .strange_integer => return self.todo("overflow ops for strange integers", .{}),
            .integer => {},
            .float, .bool => unreachable,
        }

        // The operand type must be the same as the result type in SPIR-V, which
        // is the same as in Zig.
        const operand_ty_ref = try self.resolveType(operand_ty, .direct);
        const operand_ty_id = self.typeId(operand_ty_ref);

        const bool_ty_ref = try self.resolveType(Type.bool, .direct);

        const ov_ty = result_ty.structFieldType(1, self.module);
        // Note: result is stored in a struct, so indirect representation.
        const ov_ty_ref = try self.resolveType(ov_ty, .indirect);

        // TODO: Operations other than addition.
        const value_id = self.spv.allocId();
        try self.func.body.emit(self.spv.gpa, .OpIAdd, .{
            .id_result_type = operand_ty_id,
            .id_result = value_id,
            .operand_1 = lhs,
            .operand_2 = rhs,
        });

        const overflowed_id = switch (info.signedness) {
            .unsigned => blk: {
                // Overflow happened if the result is smaller than either of the operands. It doesn't matter which.
                const overflowed_id = self.spv.allocId();
                try self.func.body.emit(self.spv.gpa, .OpULessThan, .{
                    .id_result_type = self.typeId(bool_ty_ref),
                    .id_result = overflowed_id,
                    .operand_1 = value_id,
                    .operand_2 = lhs,
                });
                break :blk overflowed_id;
            },
            .signed => blk: {
                // Overflow happened if:
                // - rhs is negative and value > lhs
                // - rhs is positive and value < lhs
                // This can be shortened to:
                //   (rhs < 0 && value > lhs) || (rhs >= 0 && value <= lhs)
                // = (rhs < 0) == (value > lhs)
                // Note that signed overflow is also wrapping in spir-v.

                const rhs_lt_zero_id = self.spv.allocId();
                const zero_id = try self.spv.constInt(operand_ty_ref, 0);
                try self.func.body.emit(self.spv.gpa, .OpSLessThan, .{
                    .id_result_type = self.typeId(bool_ty_ref),
                    .id_result = rhs_lt_zero_id,
                    .operand_1 = rhs,
                    .operand_2 = zero_id,
                });

                const value_gt_lhs_id = self.spv.allocId();
                try self.func.body.emit(self.spv.gpa, .OpSGreaterThan, .{
                    .id_result_type = self.typeId(bool_ty_ref),
                    .id_result = value_gt_lhs_id,
                    .operand_1 = value_id,
                    .operand_2 = lhs,
                });

                const overflowed_id = self.spv.allocId();
                try self.func.body.emit(self.spv.gpa, .OpLogicalEqual, .{
                    .id_result_type = self.typeId(bool_ty_ref),
                    .id_result = overflowed_id,
                    .operand_1 = rhs_lt_zero_id,
                    .operand_2 = value_gt_lhs_id,
                });
                break :blk overflowed_id;
            },
        };

        // Construct the struct that Zig wants as result.
        // The value should already be the correct type.
        const ov_id = try self.intFromBool(ov_ty_ref, overflowed_id);
        const result_ty_ref = try self.resolveType(result_ty, .direct);
        return try self.constructStruct(result_ty_ref, &.{
            value_id,
            ov_id,
        });
    }

    fn airShuffle(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        const mod = self.module;
        if (self.liveness.isUnused(inst)) return null;
        const ty = self.typeOfIndex(inst);
        const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
        const extra = self.air.extraData(Air.Shuffle, ty_pl.payload).data;
        const a = try self.resolve(extra.a);
        const b = try self.resolve(extra.b);
        const mask = extra.mask.toValue();
        const mask_len = extra.mask_len;
        const a_len = self.typeOf(extra.a).vectorLen(mod);

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
            const elem = try mask.elemValue(mod, i);
            if (elem.isUndef(mod)) {
                self.func.body.writeOperand(spec.LiteralInteger, 0xFFFF_FFFF);
            } else {
                const int = elem.toSignedInt(mod);
                const unsigned = if (int >= 0) @as(u32, @intCast(int)) else @as(u32, @intCast(~int + a_len));
                self.func.body.writeOperand(spec.LiteralInteger, unsigned);
            }
        }
        return result_id;
    }

    /// AccessChain is essentially PtrAccessChain with 0 as initial argument. The effective
    /// difference lies in whether the resulting type of the first dereference will be the
    /// same as that of the base pointer, or that of a dereferenced base pointer. AccessChain
    /// is the latter and PtrAccessChain is the former.
    fn accessChain(
        self: *DeclGen,
        result_ty_ref: CacheRef,
        base: IdRef,
        indexes: []const IdRef,
    ) !IdRef {
        const result_id = self.spv.allocId();
        try self.func.body.emit(self.spv.gpa, .OpInBoundsAccessChain, .{
            .id_result_type = self.typeId(result_ty_ref),
            .id_result = result_id,
            .base = base,
            .indexes = indexes,
        });
        return result_id;
    }

    fn ptrAccessChain(
        self: *DeclGen,
        result_ty_ref: CacheRef,
        base: IdRef,
        element: IdRef,
        indexes: []const IdRef,
    ) !IdRef {
        const result_id = self.spv.allocId();
        try self.func.body.emit(self.spv.gpa, .OpInBoundsPtrAccessChain, .{
            .id_result_type = self.typeId(result_ty_ref),
            .id_result = result_id,
            .base = base,
            .element = element,
            .indexes = indexes,
        });
        return result_id;
    }

    fn ptrAdd(self: *DeclGen, result_ty: Type, ptr_ty: Type, ptr_id: IdRef, offset_id: IdRef) !IdRef {
        const mod = self.module;
        const result_ty_ref = try self.resolveType(result_ty, .direct);

        switch (ptr_ty.ptrSize(mod)) {
            .One => {
                // Pointer to array
                // TODO: Is this correct?
                return try self.accessChain(result_ty_ref, ptr_id, &.{offset_id});
            },
            .C, .Many => {
                return try self.ptrAccessChain(result_ty_ref, ptr_id, offset_id, &.{});
            },
            .Slice => {
                // TODO: This is probably incorrect. A slice should be returned here, though this is what llvm does.
                const slice_ptr_id = try self.extractField(result_ty, ptr_id, 0);
                return try self.ptrAccessChain(result_ty_ref, slice_ptr_id, offset_id, &.{});
            },
        }
    }

    fn airPtrAdd(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        if (self.liveness.isUnused(inst)) return null;
        const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
        const bin_op = self.air.extraData(Air.Bin, ty_pl.payload).data;
        const ptr_id = try self.resolve(bin_op.lhs);
        const offset_id = try self.resolve(bin_op.rhs);
        const ptr_ty = self.typeOf(bin_op.lhs);
        const result_ty = self.typeOfIndex(inst);

        return try self.ptrAdd(result_ty, ptr_ty, ptr_id, offset_id);
    }

    fn airPtrSub(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        if (self.liveness.isUnused(inst)) return null;
        const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
        const bin_op = self.air.extraData(Air.Bin, ty_pl.payload).data;
        const ptr_id = try self.resolve(bin_op.lhs);
        const ptr_ty = self.typeOf(bin_op.lhs);
        const offset_id = try self.resolve(bin_op.rhs);
        const offset_ty = self.typeOf(bin_op.rhs);
        const offset_ty_ref = try self.resolveType(offset_ty, .direct);
        const result_ty = self.typeOfIndex(inst);

        const negative_offset_id = self.spv.allocId();
        try self.func.body.emit(self.spv.gpa, .OpSNegate, .{
            .id_result_type = self.typeId(offset_ty_ref),
            .id_result = negative_offset_id,
            .operand = offset_id,
        });
        return try self.ptrAdd(result_ty, ptr_ty, ptr_id, negative_offset_id);
    }

    fn cmp(
        self: *DeclGen,
        comptime op: std.math.CompareOperator,
        bool_ty_id: IdRef,
        ty: Type,
        lhs_id: IdRef,
        rhs_id: IdRef,
    ) !IdRef {
        const mod = self.module;
        var cmp_lhs_id = lhs_id;
        var cmp_rhs_id = rhs_id;
        const opcode: Opcode = opcode: {
            const op_ty = switch (ty.zigTypeTag(mod)) {
                .Int, .Bool, .Float => ty,
                .Enum => ty.intTagType(mod),
                .ErrorSet => Type.u16,
                .Pointer => blk: {
                    // Note that while SPIR-V offers OpPtrEqual and OpPtrNotEqual, they are
                    // currently not implemented in the SPIR-V LLVM translator. Thus, we emit these using
                    // OpConvertPtrToU...
                    cmp_lhs_id = self.spv.allocId();
                    cmp_rhs_id = self.spv.allocId();

                    const usize_ty_id = self.typeId(try self.sizeType());

                    try self.func.body.emit(self.spv.gpa, .OpConvertPtrToU, .{
                        .id_result_type = usize_ty_id,
                        .id_result = cmp_lhs_id,
                        .pointer = lhs_id,
                    });

                    try self.func.body.emit(self.spv.gpa, .OpConvertPtrToU, .{
                        .id_result_type = usize_ty_id,
                        .id_result = cmp_rhs_id,
                        .pointer = rhs_id,
                    });

                    break :blk Type.usize;
                },
                .Optional => unreachable, // TODO
                else => unreachable,
            };

            const info = try self.arithmeticTypeInfo(op_ty);
            const signedness = switch (info.class) {
                .composite_integer => {
                    return self.todo("binary operations for composite integers", .{});
                },
                .float => break :opcode switch (op) {
                    .eq => .OpFOrdEqual,
                    .neq => .OpFOrdNotEqual,
                    .lt => .OpFOrdLessThan,
                    .lte => .OpFOrdLessThanEqual,
                    .gt => .OpFOrdGreaterThan,
                    .gte => .OpFOrdGreaterThanEqual,
                },
                .bool => break :opcode switch (op) {
                    .eq => .OpIEqual,
                    .neq => .OpINotEqual,
                    else => unreachable,
                },
                .strange_integer => sign: {
                    const op_ty_ref = try self.resolveType(op_ty, .direct);
                    // Mask operands before performing comparison.
                    cmp_lhs_id = try self.maskStrangeInt(op_ty_ref, cmp_lhs_id, info.bits);
                    cmp_rhs_id = try self.maskStrangeInt(op_ty_ref, cmp_rhs_id, info.bits);
                    break :sign info.signedness;
                },
                .integer => info.signedness,
            };

            break :opcode switch (signedness) {
                .unsigned => switch (op) {
                    .eq => .OpIEqual,
                    .neq => .OpINotEqual,
                    .lt => .OpULessThan,
                    .lte => .OpULessThanEqual,
                    .gt => .OpUGreaterThan,
                    .gte => .OpUGreaterThanEqual,
                },
                .signed => switch (op) {
                    .eq => .OpIEqual,
                    .neq => .OpINotEqual,
                    .lt => .OpSLessThan,
                    .lte => .OpSLessThanEqual,
                    .gt => .OpSGreaterThan,
                    .gte => .OpSGreaterThanEqual,
                },
            };
        };

        const result_id = self.spv.allocId();
        try self.func.body.emitRaw(self.spv.gpa, opcode, 4);
        self.func.body.writeOperand(spec.IdResultType, bool_ty_id);
        self.func.body.writeOperand(spec.IdResult, result_id);
        self.func.body.writeOperand(spec.IdResultType, cmp_lhs_id);
        self.func.body.writeOperand(spec.IdResultType, cmp_rhs_id);
        return result_id;
    }

    fn airCmp(
        self: *DeclGen,
        inst: Air.Inst.Index,
        comptime op: std.math.CompareOperator,
    ) !?IdRef {
        if (self.liveness.isUnused(inst)) return null;
        const bin_op = self.air.instructions.items(.data)[inst].bin_op;
        const lhs_id = try self.resolve(bin_op.lhs);
        const rhs_id = try self.resolve(bin_op.rhs);
        const bool_ty_id = try self.resolveTypeId(Type.bool);
        const ty = self.typeOf(bin_op.lhs);
        assert(ty.eql(self.typeOf(bin_op.rhs), self.module));

        return try self.cmp(op, bool_ty_id, ty, lhs_id, rhs_id);
    }

    fn bitCast(
        self: *DeclGen,
        dst_ty: Type,
        src_ty: Type,
        src_id: IdRef,
    ) !IdRef {
        const mod = self.module;
        const dst_ty_ref = try self.resolveType(dst_ty, .direct);
        const result_id = self.spv.allocId();

        // TODO: Some more cases are missing here
        //   See fn bitCast in llvm.zig

        if (src_ty.zigTypeTag(mod) == .Int and dst_ty.isPtrAtRuntime(mod)) {
            try self.func.body.emit(self.spv.gpa, .OpConvertUToPtr, .{
                .id_result_type = self.typeId(dst_ty_ref),
                .id_result = result_id,
                .integer_value = src_id,
            });
        } else {
            try self.func.body.emit(self.spv.gpa, .OpBitcast, .{
                .id_result_type = self.typeId(dst_ty_ref),
                .id_result = result_id,
                .operand = src_id,
            });
        }
        return result_id;
    }

    fn airBitCast(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        if (self.liveness.isUnused(inst)) return null;
        const ty_op = self.air.instructions.items(.data)[inst].ty_op;
        const operand_id = try self.resolve(ty_op.operand);
        const operand_ty = self.typeOf(ty_op.operand);
        const result_ty = self.typeOfIndex(inst);
        return try self.bitCast(result_ty, operand_ty, operand_id);
    }

    fn airIntCast(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        if (self.liveness.isUnused(inst)) return null;

        const ty_op = self.air.instructions.items(.data)[inst].ty_op;
        const operand_id = try self.resolve(ty_op.operand);
        const dest_ty = self.typeOfIndex(inst);
        const dest_ty_id = try self.resolveTypeId(dest_ty);

        const mod = self.module;
        const dest_info = dest_ty.intInfo(mod);

        // TODO: Masking?

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

    fn airIntFromPtr(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        if (self.liveness.isUnused(inst)) return null;

        const un_op = self.air.instructions.items(.data)[inst].un_op;
        const operand_id = try self.resolve(un_op);
        const result_type_id = try self.resolveTypeId(Type.usize);

        const result_id = self.spv.allocId();
        try self.func.body.emit(self.spv.gpa, .OpConvertPtrToU, .{
            .id_result_type = result_type_id,
            .id_result = result_id,
            .pointer = operand_id,
        });
        return result_id;
    }

    fn airFloatFromInt(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        if (self.liveness.isUnused(inst)) return null;

        const ty_op = self.air.instructions.items(.data)[inst].ty_op;
        const operand_ty = self.typeOf(ty_op.operand);
        const operand_id = try self.resolve(ty_op.operand);
        const operand_info = try self.arithmeticTypeInfo(operand_ty);
        const dest_ty = self.typeOfIndex(inst);
        const dest_ty_id = try self.resolveTypeId(dest_ty);

        const result_id = self.spv.allocId();
        switch (operand_info.signedness) {
            .signed => try self.func.body.emit(self.spv.gpa, .OpConvertSToF, .{
                .id_result_type = dest_ty_id,
                .id_result = result_id,
                .signed_value = operand_id,
            }),
            .unsigned => try self.func.body.emit(self.spv.gpa, .OpConvertUToF, .{
                .id_result_type = dest_ty_id,
                .id_result = result_id,
                .unsigned_value = operand_id,
            }),
        }
        return result_id;
    }

    fn airIntFromFloat(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        if (self.liveness.isUnused(inst)) return null;

        const ty_op = self.air.instructions.items(.data)[inst].ty_op;
        const operand_id = try self.resolve(ty_op.operand);
        const dest_ty = self.typeOfIndex(inst);
        const dest_info = try self.arithmeticTypeInfo(dest_ty);
        const dest_ty_id = try self.resolveTypeId(dest_ty);

        const result_id = self.spv.allocId();
        switch (dest_info.signedness) {
            .signed => try self.func.body.emit(self.spv.gpa, .OpConvertFToS, .{
                .id_result_type = dest_ty_id,
                .id_result = result_id,
                .float_value = operand_id,
            }),
            .unsigned => try self.func.body.emit(self.spv.gpa, .OpConvertFToU, .{
                .id_result_type = dest_ty_id,
                .id_result = result_id,
                .float_value = operand_id,
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

    fn airSliceField(self: *DeclGen, inst: Air.Inst.Index, field: u32) !?IdRef {
        if (self.liveness.isUnused(inst)) return null;
        const ty_op = self.air.instructions.items(.data)[inst].ty_op;
        const field_ty = self.typeOfIndex(inst);
        const operand_id = try self.resolve(ty_op.operand);
        return try self.extractField(field_ty, operand_id, field);
    }

    fn airSliceElemPtr(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        const mod = self.module;
        const bin_op = self.air.instructions.items(.data)[inst].bin_op;
        const slice_ty = self.typeOf(bin_op.lhs);
        if (!slice_ty.isVolatilePtr(mod) and self.liveness.isUnused(inst)) return null;

        const slice_id = try self.resolve(bin_op.lhs);
        const index_id = try self.resolve(bin_op.rhs);

        const ptr_ty = self.typeOfIndex(inst);
        const ptr_ty_ref = try self.resolveType(ptr_ty, .direct);

        const slice_ptr = try self.extractField(ptr_ty, slice_id, 0);
        return try self.ptrAccessChain(ptr_ty_ref, slice_ptr, index_id, &.{});
    }

    fn airSliceElemVal(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        const mod = self.module;
        const bin_op = self.air.instructions.items(.data)[inst].bin_op;
        const slice_ty = self.typeOf(bin_op.lhs);
        if (!slice_ty.isVolatilePtr(mod) and self.liveness.isUnused(inst)) return null;

        const slice_id = try self.resolve(bin_op.lhs);
        const index_id = try self.resolve(bin_op.rhs);

        const ptr_ty = slice_ty.slicePtrFieldType(mod);
        const ptr_ty_ref = try self.resolveType(ptr_ty, .direct);

        const slice_ptr = try self.extractField(ptr_ty, slice_id, 0);
        const elem_ptr = try self.ptrAccessChain(ptr_ty_ref, slice_ptr, index_id, &.{});
        return try self.load(slice_ty, elem_ptr);
    }

    fn ptrElemPtr(self: *DeclGen, ptr_ty: Type, ptr_id: IdRef, index_id: IdRef) !IdRef {
        const mod = self.module;
        // Construct new pointer type for the resulting pointer
        const elem_ty = ptr_ty.elemType2(mod); // use elemType() so that we get T for *[N]T.
        const elem_ty_ref = try self.resolveType(elem_ty, .direct);
        const elem_ptr_ty_ref = try self.spv.ptrType(elem_ty_ref, spvStorageClass(ptr_ty.ptrAddressSpace(mod)));
        if (ptr_ty.isSinglePointer(mod)) {
            // Pointer-to-array. In this case, the resulting pointer is not of the same type
            // as the ptr_ty (we want a *T, not a *[N]T), and hence we need to use accessChain.
            return try self.accessChain(elem_ptr_ty_ref, ptr_id, &.{index_id});
        } else {
            // Resulting pointer type is the same as the ptr_ty, so use ptrAccessChain
            return try self.ptrAccessChain(elem_ptr_ty_ref, ptr_id, index_id, &.{});
        }
    }

    fn airPtrElemPtr(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        if (self.liveness.isUnused(inst)) return null;

        const mod = self.module;
        const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
        const bin_op = self.air.extraData(Air.Bin, ty_pl.payload).data;
        const ptr_ty = self.typeOf(bin_op.lhs);
        const elem_ty = ptr_ty.childType(mod);
        // TODO: Make this return a null ptr or something
        if (!elem_ty.hasRuntimeBitsIgnoreComptime(mod)) return null;

        const ptr_id = try self.resolve(bin_op.lhs);
        const index_id = try self.resolve(bin_op.rhs);
        return try self.ptrElemPtr(ptr_ty, ptr_id, index_id);
    }

    fn airPtrElemVal(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        const mod = self.module;
        const bin_op = self.air.instructions.items(.data)[inst].bin_op;
        const ptr_ty = self.typeOf(bin_op.lhs);
        const ptr_id = try self.resolve(bin_op.lhs);
        const index_id = try self.resolve(bin_op.rhs);

        const elem_ptr_id = try self.ptrElemPtr(ptr_ty, ptr_id, index_id);

        // If we have a pointer-to-array, construct an element pointer to use with load()
        // If we pass ptr_ty directly, it will attempt to load the entire array rather than
        // just an element.
        var elem_ptr_info = ptr_ty.ptrInfo(mod);
        elem_ptr_info.flags.size = .One;
        const elem_ptr_ty = try mod.intern_pool.get(mod.gpa, .{ .ptr_type = elem_ptr_info });

        return try self.load(elem_ptr_ty.toType(), elem_ptr_id);
    }

    fn airGetUnionTag(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        const ty_op = self.air.instructions.items(.data)[inst].ty_op;
        const un_ty = self.typeOf(ty_op.operand);

        const mod = self.module;
        const layout = un_ty.unionGetLayout(mod);
        if (layout.tag_size == 0) return null;

        const union_handle = try self.resolve(ty_op.operand);
        if (layout.payload_size == 0) return union_handle;

        const tag_ty = un_ty.unionTagTypeSafety(mod).?;
        const tag_index = @intFromBool(layout.tag_align < layout.payload_align);
        return try self.extractField(tag_ty, union_handle, tag_index);
    }

    fn airStructFieldVal(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        if (self.liveness.isUnused(inst)) return null;

        const mod = self.module;
        const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
        const struct_field = self.air.extraData(Air.StructField, ty_pl.payload).data;

        const struct_ty = self.typeOf(struct_field.struct_operand);
        const object_id = try self.resolve(struct_field.struct_operand);
        const field_index = struct_field.field_index;
        const field_ty = struct_ty.structFieldType(field_index, mod);

        if (!field_ty.hasRuntimeBitsIgnoreComptime(mod)) return null;

        assert(struct_ty.zigTypeTag(mod) == .Struct); // Cannot do unions yet.

        return try self.extractField(field_ty, object_id, field_index);
    }

    fn structFieldPtr(
        self: *DeclGen,
        result_ptr_ty: Type,
        object_ptr_ty: Type,
        object_ptr: IdRef,
        field_index: u32,
    ) !?IdRef {
        const mod = self.module;
        const object_ty = object_ptr_ty.childType(mod);
        switch (object_ty.zigTypeTag(mod)) {
            .Struct => switch (object_ty.containerLayout(mod)) {
                .Packed => unreachable, // TODO
                else => {
                    const field_index_ty_ref = try self.intType(.unsigned, 32);
                    const field_index_id = try self.spv.constInt(field_index_ty_ref, field_index);
                    const result_ty_ref = try self.resolveType(result_ptr_ty, .direct);
                    return try self.accessChain(result_ty_ref, object_ptr, &.{field_index_id});
                },
            },
            else => unreachable, // TODO
        }
    }

    fn airStructFieldPtrIndex(self: *DeclGen, inst: Air.Inst.Index, field_index: u32) !?IdRef {
        if (self.liveness.isUnused(inst)) return null;
        const ty_op = self.air.instructions.items(.data)[inst].ty_op;
        const struct_ptr = try self.resolve(ty_op.operand);
        const struct_ptr_ty = self.typeOf(ty_op.operand);
        const result_ptr_ty = self.typeOfIndex(inst);
        return try self.structFieldPtr(result_ptr_ty, struct_ptr_ty, struct_ptr, field_index);
    }

    /// We cannot use an OpVariable directly in an OpSpecConstantOp, but we can
    /// after we insert a dummy AccessChain...
    /// TODO: Get rid of this
    fn makePointerConstant(
        self: *DeclGen,
        section: *SpvSection,
        ptr_ty_ref: CacheRef,
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

    // Allocate a function-local variable, with possible initializer.
    // This function returns a pointer to a variable of type `ty_ref`,
    // which is in the Generic address space. The variable is actually
    // placed in the Function address space.
    fn alloc(
        self: *DeclGen,
        ty_ref: CacheRef,
        initializer: ?IdRef,
    ) !IdRef {
        const fn_ptr_ty_ref = try self.spv.ptrType(ty_ref, .Function);
        const general_ptr_ty_ref = try self.spv.ptrType(ty_ref, .Generic);

        // SPIR-V requires that OpVariable declarations for locals go into the first block, so we are just going to
        // directly generate them into func.prologue instead of the body.
        const var_id = self.spv.allocId();
        try self.func.prologue.emit(self.spv.gpa, .OpVariable, .{
            .id_result_type = self.typeId(fn_ptr_ty_ref),
            .id_result = var_id,
            .storage_class = .Function,
            .initializer = initializer,
        });

        // Convert to a generic pointer
        const result_id = self.spv.allocId();
        try self.func.body.emit(self.spv.gpa, .OpPtrCastToGeneric, .{
            .id_result_type = self.typeId(general_ptr_ty_ref),
            .id_result = result_id,
            .pointer = var_id,
        });
        return result_id;
    }

    fn airAlloc(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        if (self.liveness.isUnused(inst)) return null;
        const mod = self.module;
        const ptr_ty = self.typeOfIndex(inst);
        assert(ptr_ty.ptrAddressSpace(mod) == .generic);
        const child_ty = ptr_ty.childType(mod);
        const child_ty_ref = try self.resolveType(child_ty, .indirect);
        return try self.alloc(child_ty_ref, null);
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

        const mod = self.module;
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

        const ty = self.typeOfIndex(inst);
        const inst_datas = self.air.instructions.items(.data);
        const extra = self.air.extraData(Air.Block, inst_datas[inst].ty_pl.payload);
        const body = self.air.extra[extra.end..][0..extra.data.body_len];

        try self.genBody(body);
        try self.beginSpvBlock(label_id);

        // If this block didn't produce a value, simply return here.
        if (!ty.hasRuntimeBitsIgnoreComptime(mod))
            return null;

        // Combine the result from the blocks using the Phi instruction.
        const result_id = self.spv.allocId();

        // TODO: OpPhi is limited in the types that it may produce, such as pointers. Figure out which other types
        // are not allowed to be created from a phi node, and throw an error for those.
        const result_type_id = try self.resolveTypeId(ty);

        try self.func.body.emitRaw(self.spv.gpa, .OpPhi, 2 + @as(u16, @intCast(incoming_blocks.items.len * 2))); // result type + result + variable/parent...
        self.func.body.writeOperand(spec.IdResultType, result_type_id);
        self.func.body.writeOperand(spec.IdRef, result_id);

        for (incoming_blocks.items) |incoming| {
            self.func.body.writeOperand(spec.PairIdRefIdRef, .{ incoming.break_value_id, incoming.src_label_id });
        }

        return result_id;
    }

    fn airBr(self: *DeclGen, inst: Air.Inst.Index) !void {
        const br = self.air.instructions.items(.data)[inst].br;
        const block = self.blocks.get(br.block_inst).?;
        const operand_ty = self.typeOf(br.operand);

        const mod = self.module;
        if (operand_ty.hasRuntimeBits(mod)) {
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
        const src_fname_id = try self.spv.resolveSourceFileName(
            self.module,
            self.module.declPtr(self.decl_index),
        );
        try self.func.body.emit(self.spv.gpa, .OpLine, .{
            .file = src_fname_id,
            .line = dbg_stmt.line,
            .column = dbg_stmt.column,
        });
    }

    fn airLoad(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        const mod = self.module;
        const ty_op = self.air.instructions.items(.data)[inst].ty_op;
        const ptr_ty = self.typeOf(ty_op.operand);
        const operand = try self.resolve(ty_op.operand);
        if (!ptr_ty.isVolatilePtr(mod) and self.liveness.isUnused(inst)) return null;

        return try self.load(ptr_ty, operand);
    }

    fn airStore(self: *DeclGen, inst: Air.Inst.Index) !void {
        const mod = self.module;
        const bin_op = self.air.instructions.items(.data)[inst].bin_op;
        const ptr_ty = self.typeOf(bin_op.lhs);
        const ptr = try self.resolve(bin_op.lhs);
        const value = try self.resolve(bin_op.rhs);
        const ptr_ty_ref = try self.resolveType(ptr_ty, .direct);

        const val_is_undef = if (try self.air.value(bin_op.rhs, mod)) |val| val.isUndefDeep(mod) else false;
        if (val_is_undef) {
            const undef = try self.spv.constUndef(ptr_ty_ref);
            try self.store(ptr_ty, ptr, undef);
        } else {
            try self.store(ptr_ty, ptr, value);
        }
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
        const operand_ty = self.typeOf(operand);
        const mod = self.module;
        if (operand_ty.hasRuntimeBits(mod)) {
            const operand_id = try self.resolve(operand);
            try self.func.body.emit(self.spv.gpa, .OpReturnValue, .{ .value = operand_id });
        } else {
            try self.func.body.emit(self.spv.gpa, .OpReturn, {});
        }
    }

    fn airRetLoad(self: *DeclGen, inst: Air.Inst.Index) !void {
        const mod = self.module;
        const un_op = self.air.instructions.items(.data)[inst].un_op;
        const ptr_ty = self.typeOf(un_op);
        const ret_ty = ptr_ty.childType(mod);

        if (!ret_ty.hasRuntimeBitsIgnoreComptime(mod)) {
            try self.func.body.emit(self.spv.gpa, .OpReturn, {});
            return;
        }

        const ptr = try self.resolve(un_op);
        const value = try self.load(ptr_ty, ptr);
        try self.func.body.emit(self.spv.gpa, .OpReturnValue, .{
            .value = value,
        });
    }

    fn airTry(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        const mod = self.module;
        const pl_op = self.air.instructions.items(.data)[inst].pl_op;
        const err_union_id = try self.resolve(pl_op.operand);
        const extra = self.air.extraData(Air.Try, pl_op.payload);
        const body = self.air.extra[extra.end..][0..extra.data.body_len];

        const err_union_ty = self.typeOf(pl_op.operand);
        const payload_ty = self.typeOfIndex(inst);

        const err_ty_ref = try self.resolveType(Type.anyerror, .direct);
        const bool_ty_ref = try self.resolveType(Type.bool, .direct);

        const eu_layout = self.errorUnionLayout(payload_ty);

        if (!err_union_ty.errorUnionSet(mod).errorSetIsEmpty(mod)) {
            const err_id = if (eu_layout.payload_has_bits)
                try self.extractField(Type.anyerror, err_union_id, eu_layout.errorFieldIndex())
            else
                err_union_id;

            const zero_id = try self.spv.constInt(err_ty_ref, 0);
            const is_err_id = self.spv.allocId();
            try self.func.body.emit(self.spv.gpa, .OpINotEqual, .{
                .id_result_type = self.typeId(bool_ty_ref),
                .id_result = is_err_id,
                .operand_1 = err_id,
                .operand_2 = zero_id,
            });

            // When there is an error, we must evaluate `body`. Otherwise we must continue
            // with the current body.
            // Just generate a new block here, then generate a new block inline for the remainder of the body.

            const err_block = self.spv.allocId();
            const ok_block = self.spv.allocId();

            // TODO: Merge block
            try self.func.body.emit(self.spv.gpa, .OpBranchConditional, .{
                .condition = is_err_id,
                .true_label = err_block,
                .false_label = ok_block,
            });

            try self.beginSpvBlock(err_block);
            try self.genBody(body);

            try self.beginSpvBlock(ok_block);
            // Now just extract the payload, if required.
        }
        if (self.liveness.isUnused(inst)) {
            return null;
        }
        if (!eu_layout.payload_has_bits) {
            return null;
        }

        return try self.extractField(payload_ty, err_union_id, eu_layout.payloadFieldIndex());
    }

    fn airErrUnionErr(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        if (self.liveness.isUnused(inst)) return null;

        const mod = self.module;
        const ty_op = self.air.instructions.items(.data)[inst].ty_op;
        const operand_id = try self.resolve(ty_op.operand);
        const err_union_ty = self.typeOf(ty_op.operand);
        const err_ty_ref = try self.resolveType(Type.anyerror, .direct);

        if (err_union_ty.errorUnionSet(mod).errorSetIsEmpty(mod)) {
            // No error possible, so just return undefined.
            return try self.spv.constUndef(err_ty_ref);
        }

        const payload_ty = err_union_ty.errorUnionPayload(mod);
        const eu_layout = self.errorUnionLayout(payload_ty);

        if (!eu_layout.payload_has_bits) {
            // If no payload, error union is represented by error set.
            return operand_id;
        }

        return try self.extractField(Type.anyerror, operand_id, eu_layout.errorFieldIndex());
    }

    fn airWrapErrUnionErr(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        if (self.liveness.isUnused(inst)) return null;

        const mod = self.module;
        const ty_op = self.air.instructions.items(.data)[inst].ty_op;
        const err_union_ty = self.typeOfIndex(inst);
        const payload_ty = err_union_ty.errorUnionPayload(mod);
        const operand_id = try self.resolve(ty_op.operand);
        const eu_layout = self.errorUnionLayout(payload_ty);

        if (!eu_layout.payload_has_bits) {
            return operand_id;
        }

        const payload_ty_ref = try self.resolveType(payload_ty, .indirect);
        var members = std.BoundedArray(IdRef, 2){};
        const payload_id = try self.spv.constUndef(payload_ty_ref);
        if (eu_layout.error_first) {
            members.appendAssumeCapacity(operand_id);
            members.appendAssumeCapacity(payload_id);
            // TODO: ABI padding?
        } else {
            members.appendAssumeCapacity(payload_id);
            members.appendAssumeCapacity(operand_id);
            // TODO: ABI padding?
        }

        const err_union_ty_ref = try self.resolveType(err_union_ty, .direct);
        return try self.constructStruct(err_union_ty_ref, members.slice());
    }

    fn airIsNull(self: *DeclGen, inst: Air.Inst.Index, pred: enum { is_null, is_non_null }) !?IdRef {
        if (self.liveness.isUnused(inst)) return null;

        const mod = self.module;
        const un_op = self.air.instructions.items(.data)[inst].un_op;
        const operand_id = try self.resolve(un_op);
        const optional_ty = self.typeOf(un_op);

        const payload_ty = optional_ty.optionalChild(mod);

        const bool_ty_ref = try self.resolveType(Type.bool, .direct);

        if (optional_ty.optionalReprIsPayload(mod)) {
            // Pointer payload represents nullability: pointer or slice.

            const ptr_ty = if (payload_ty.isSlice(mod))
                payload_ty.slicePtrFieldType(mod)
            else
                payload_ty;

            const ptr_id = if (payload_ty.isSlice(mod))
                try self.extractField(Type.bool, operand_id, 0)
            else
                operand_id;

            const payload_ty_ref = try self.resolveType(ptr_ty, .direct);
            const null_id = try self.spv.constNull(payload_ty_ref);
            const result_id = self.spv.allocId();
            const operands = .{
                .id_result_type = self.typeId(bool_ty_ref),
                .id_result = result_id,
                .operand_1 = ptr_id,
                .operand_2 = null_id,
            };
            switch (pred) {
                .is_null => try self.func.body.emit(self.spv.gpa, .OpPtrEqual, operands),
                .is_non_null => try self.func.body.emit(self.spv.gpa, .OpPtrNotEqual, operands),
            }
            return result_id;
        }

        const is_non_null_id = if (optional_ty.hasRuntimeBitsIgnoreComptime(mod))
            try self.extractField(Type.bool, operand_id, 1)
        else
            // Optional representation is bool indicating whether the optional is set
            operand_id;

        return switch (pred) {
            .is_null => blk: {
                // Invert condition
                const result_id = self.spv.allocId();
                try self.func.body.emit(self.spv.gpa, .OpLogicalNot, .{
                    .id_result_type = self.typeId(bool_ty_ref),
                    .id_result = result_id,
                    .operand = is_non_null_id,
                });
                break :blk result_id;
            },
            .is_non_null => is_non_null_id,
        };
    }

    fn airUnwrapOptional(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        if (self.liveness.isUnused(inst)) return null;

        const mod = self.module;
        const ty_op = self.air.instructions.items(.data)[inst].ty_op;
        const operand_id = try self.resolve(ty_op.operand);
        const optional_ty = self.typeOf(ty_op.operand);
        const payload_ty = self.typeOfIndex(inst);

        if (!payload_ty.hasRuntimeBitsIgnoreComptime(mod)) return null;

        if (optional_ty.optionalReprIsPayload(mod)) {
            return operand_id;
        }

        return try self.extractField(payload_ty, operand_id, 0);
    }

    fn airWrapOptional(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        if (self.liveness.isUnused(inst)) return null;

        const mod = self.module;
        const ty_op = self.air.instructions.items(.data)[inst].ty_op;
        const payload_ty = self.typeOf(ty_op.operand);

        if (!payload_ty.hasRuntimeBitsIgnoreComptime(mod)) {
            return try self.constBool(true, .direct);
        }

        const operand_id = try self.resolve(ty_op.operand);
        const optional_ty = self.typeOfIndex(inst);
        if (optional_ty.optionalReprIsPayload(mod)) {
            return operand_id;
        }

        const optional_ty_ref = try self.resolveType(optional_ty, .direct);
        const members = [_]IdRef{ operand_id, try self.constBool(true, .indirect) };
        return try self.constructStruct(optional_ty_ref, &members);
    }

    fn airSwitchBr(self: *DeclGen, inst: Air.Inst.Index) !void {
        const mod = self.module;
        const pl_op = self.air.instructions.items(.data)[inst].pl_op;
        const cond = try self.resolve(pl_op.operand);
        const cond_ty = self.typeOf(pl_op.operand);
        const switch_br = self.air.extraData(Air.SwitchBr, pl_op.payload);

        const cond_words: u32 = switch (cond_ty.zigTypeTag(mod)) {
            .Int => blk: {
                const bits = cond_ty.intInfo(mod).bits;
                const backing_bits = self.backingIntBits(bits) orelse {
                    return self.todo("implement composite int switch", .{});
                };
                break :blk if (backing_bits <= 32) @as(u32, 1) else 2;
            },
            .Enum => blk: {
                const int_ty = cond_ty.intTagType(mod);
                const int_info = int_ty.intInfo(mod);
                const backing_bits = self.backingIntBits(int_info.bits) orelse {
                    return self.todo("implement composite int switch", .{});
                };
                break :blk if (backing_bits <= 32) @as(u32, 1) else 2;
            },
            else => return self.todo("implement switch for type {s}", .{@tagName(cond_ty.zigTypeTag(mod))}), // TODO: Figure out which types apply here, and work around them as we can only do integers.
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
                const items = @as([]const Air.Inst.Ref, @ptrCast(self.air.extra[case.end..][0..case.data.items_len]));
                const case_body = self.air.extra[case.end + items.len ..][0..case.data.body_len];
                extra_index = case.end + case.data.items_len + case_body.len;

                const label = IdRef{ .id = first_case_label.id + case_i };

                for (items) |item| {
                    const value = (try self.air.value(item, mod)) orelse {
                        return self.todo("switch on runtime value???", .{});
                    };
                    const int_val = switch (cond_ty.zigTypeTag(mod)) {
                        .Int => if (cond_ty.isSignedInt(mod)) @as(u64, @bitCast(value.toSignedInt(mod))) else value.toUnsignedInt(mod),
                        .Enum => blk: {
                            // TODO: figure out of cond_ty is correct (something with enum literals)
                            break :blk (try value.intFromEnum(cond_ty, mod)).toUnsignedInt(mod); // TODO: composite integer constants
                        },
                        else => unreachable,
                    };
                    const int_lit: spec.LiteralContextDependentNumber = switch (cond_words) {
                        1 => .{ .uint32 = @as(u32, @intCast(int_val)) },
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
            const items = @as([]const Air.Inst.Ref, @ptrCast(self.air.extra[case.end..][0..case.data.items_len]));
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
        const mod = self.module;
        const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
        const extra = self.air.extraData(Air.Asm, ty_pl.payload);

        const is_volatile = @as(u1, @truncate(extra.data.flags >> 31)) != 0;
        const clobbers_len = @as(u31, @truncate(extra.data.flags));

        if (!is_volatile and self.liveness.isUnused(inst)) return null;

        var extra_i: usize = extra.end;
        const outputs = @as([]const Air.Inst.Ref, @ptrCast(self.air.extra[extra_i..][0..extra.data.outputs_len]));
        extra_i += outputs.len;
        const inputs = @as([]const Air.Inst.Ref, @ptrCast(self.air.extra[extra_i..][0..extra.data.inputs_len]));
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
                const src_loc = loc.toSrcLoc(self.module.declPtr(self.decl_index), mod);
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

        const mod = self.module;
        const pl_op = self.air.instructions.items(.data)[inst].pl_op;
        const extra = self.air.extraData(Air.Call, pl_op.payload);
        const args = @as([]const Air.Inst.Ref, @ptrCast(self.air.extra[extra.end..][0..extra.data.args_len]));
        const callee_ty = self.typeOf(pl_op.operand);
        const zig_fn_ty = switch (callee_ty.zigTypeTag(mod)) {
            .Fn => callee_ty,
            .Pointer => return self.fail("cannot call function pointers", .{}),
            else => unreachable,
        };
        const fn_info = mod.typeToFunc(zig_fn_ty).?;
        const return_type = fn_info.return_type;

        const result_type_id = try self.resolveTypeId(return_type.toType());
        const result_id = self.spv.allocId();
        const callee_id = try self.resolve(pl_op.operand);

        const params = try self.gpa.alloc(spec.IdRef, args.len);
        defer self.gpa.free(params);

        var n_params: usize = 0;
        for (args) |arg| {
            // Note: resolve() might emit instructions, so we need to call it
            // before starting to emit OpFunctionCall instructions. Hence the
            // temporary params buffer.
            const arg_id = try self.resolve(arg);
            const arg_ty = self.typeOf(arg);
            if (!arg_ty.hasRuntimeBitsIgnoreComptime(mod)) continue;

            params[n_params] = arg_id;
            n_params += 1;
        }

        try self.func.body.emit(self.spv.gpa, .OpFunctionCall, .{
            .id_result_type = result_type_id,
            .id_result = result_id,
            .function = callee_id,
            .id_ref_3 = params[0..n_params],
        });

        if (return_type == .noreturn_type) {
            try self.func.body.emit(self.spv.gpa, .OpUnreachable, {});
        }

        if (self.liveness.isUnused(inst) or !return_type.toType().hasRuntimeBitsIgnoreComptime(mod)) {
            return null;
        }

        return result_id;
    }

    fn typeOf(self: *DeclGen, inst: Air.Inst.Ref) Type {
        const mod = self.module;
        return self.air.typeOf(inst, &mod.intern_pool);
    }

    fn typeOfIndex(self: *DeclGen, inst: Air.Inst.Index) Type {
        const mod = self.module;
        return self.air.typeOfIndex(inst, &mod.intern_pool);
    }
};
