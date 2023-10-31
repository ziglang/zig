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
const InternPool = @import("../InternPool.zig");

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

/// We want to store some extra facts about types as mapped from Zig to SPIR-V.
/// This structure is used to keep that extra information, as well as
/// the cached reference to the type.
const SpvTypeInfo = struct {
    ty_ref: CacheRef,
};

const TypeMap = std.AutoHashMapUnmanaged(InternPool.Index, SpvTypeInfo);

const IncomingBlock = struct {
    src_label_id: IdRef,
    break_value_id: IdRef,
};

const Block = struct {
    label_id: ?IdRef,
    incoming_blocks: std.ArrayListUnmanaged(IncomingBlock),
};

const BlockMap = std.AutoHashMapUnmanaged(Air.Inst.Index, *Block);

/// This structure holds information that is relevant to the entire compilation,
/// in contrast to `DeclGen`, which only holds relevant information about a
/// single decl.
pub const Object = struct {
    /// A general-purpose allocator that can be used for any allocation for this Object.
    gpa: Allocator,

    /// the SPIR-V module that represents the final binary.
    spv: SpvModule,

    /// The Zig module that this object file is generated for.
    /// A map of Zig decl indices to SPIR-V decl indices.
    decl_link: std.AutoHashMapUnmanaged(Decl.Index, SpvModule.Decl.Index) = .{},

    /// A map of Zig InternPool indices for anonymous decls to SPIR-V decl indices.
    anon_decl_link: std.AutoHashMapUnmanaged(struct { InternPool.Index, StorageClass }, SpvModule.Decl.Index) = .{},

    /// A map that maps AIR intern pool indices to SPIR-V cache references (which
    /// is basically the same thing except for SPIR-V).
    /// This map is typically only used for structures that are deemed heavy enough
    /// that it is worth to store them here. The SPIR-V module also interns types,
    /// and so the main purpose of this map is to avoid recomputation and to
    /// cache extra information about the type rather than to aid in validity
    /// of the SPIR-V module.
    type_map: TypeMap = .{},

    pub fn init(gpa: Allocator) Object {
        return .{
            .gpa = gpa,
            .spv = SpvModule.init(gpa),
        };
    }

    pub fn deinit(self: *Object) void {
        self.spv.deinit();
        self.decl_link.deinit(self.gpa);
        self.anon_decl_link.deinit(self.gpa);
        self.type_map.deinit(self.gpa);
    }

    fn genDecl(
        self: *Object,
        mod: *Module,
        decl_index: Decl.Index,
        air: Air,
        liveness: Liveness,
    ) !void {
        var decl_gen = DeclGen{
            .gpa = self.gpa,
            .object = self,
            .module = mod,
            .spv = &self.spv,
            .decl_index = decl_index,
            .air = air,
            .liveness = liveness,
            .type_map = &self.type_map,
            .current_block_label_id = undefined,
        };
        defer decl_gen.deinit();

        decl_gen.genDecl() catch |err| switch (err) {
            error.CodegenFail => {
                try mod.failed_decls.put(mod.gpa, decl_index, decl_gen.error_msg.?);
            },
            else => |other| {
                // There might be an error that happened *after* self.error_msg
                // was already allocated, so be sure to free it.
                if (decl_gen.error_msg) |error_msg| {
                    error_msg.deinit(mod.gpa);
                }

                return other;
            },
        };
    }

    pub fn updateFunc(
        self: *Object,
        mod: *Module,
        func_index: InternPool.Index,
        air: Air,
        liveness: Liveness,
    ) !void {
        const decl_index = mod.funcInfo(func_index).owner_decl;
        // TODO: Separate types for generating decls and functions?
        try self.genDecl(mod, decl_index, air, liveness);
    }

    pub fn updateDecl(
        self: *Object,
        mod: *Module,
        decl_index: Decl.Index,
    ) !void {
        try self.genDecl(mod, decl_index, undefined, undefined);
    }

    /// Fetch or allocate a result id for decl index. This function also marks the decl as alive.
    /// Note: Function does not actually generate the decl, it just allocates an index.
    pub fn resolveDecl(self: *Object, mod: *Module, decl_index: Decl.Index) !SpvModule.Decl.Index {
        const decl = mod.declPtr(decl_index);
        try mod.markDeclAlive(decl);

        const entry = try self.decl_link.getOrPut(self.gpa, decl_index);
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
};

/// This structure is used to compile a declaration, and contains all relevant meta-information to deal with that.
const DeclGen = struct {
    /// A general-purpose allocator that can be used for any allocations for this DeclGen.
    gpa: Allocator,

    /// The object that this decl is generated into.
    object: *Object,

    /// The Zig module that we are generating decls for.
    module: *Module,

    /// The SPIR-V module that instructions should be emitted into.
    /// This is the same as `self.object.spv`, repeated here for brevity.
    spv: *SpvModule,

    /// The decl we are currently generating code for.
    decl_index: Decl.Index,

    /// The intermediate code of the declaration we are currently generating. Note: If
    /// the declaration is not a function, this value will be undefined!
    air: Air,

    /// The liveness analysis of the intermediate code for the declaration we are currently generating.
    /// Note: If the declaration is not a function, this value will be undefined!
    liveness: Liveness,

    /// An array of function argument result-ids. Each index corresponds with the
    /// function argument of the same index.
    args: std.ArrayListUnmanaged(IdRef) = .{},

    /// A counter to keep track of how many `arg` instructions we've seen yet.
    next_arg_index: u32 = 0,

    /// A map keeping track of which instruction generated which result-id.
    inst_results: InstMap = .{},

    /// A map that maps AIR intern pool indices to SPIR-V cache references.
    /// See Object.type_map
    type_map: *TypeMap,

    /// Child types of pointers that are currently in progress of being resolved. If a pointer
    /// is already in this map, its recursive.
    wip_pointers: std.AutoHashMapUnmanaged(struct { InternPool.Index, StorageClass }, CacheRef) = .{},

    /// We need to keep track of result ids for block labels, as well as the 'incoming'
    /// blocks for a block.
    blocks: BlockMap = .{},

    /// The label of the SPIR-V block we are currently generating.
    current_block_label_id: IdRef,

    /// The code (prologue and body) for the function we are currently generating code for.
    func: SpvModule.Fn = .{},

    /// Stack of the base offsets of the current decl, which is what `dbg_stmt` is relative to.
    /// This is a stack to keep track of inline functions.
    base_line_stack: std.ArrayListUnmanaged(u32) = .{},

    /// If `gen` returned `Error.CodegenFail`, this contains an explanatory message.
    /// Memory is owned by `module.gpa`.
    error_msg: ?*Module.ErrorMsg = null,

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

        /// The number of bits required to store the type.
        /// For `integer` and `float`, this is equal to `bits`.
        /// For `strange_integer` and `bool` this is the size of the backing integer.
        /// For `composite_integer` this is 0 (TODO)
        backing_bits: u16,

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

    /// Free resources owned by the DeclGen.
    pub fn deinit(self: *DeclGen) void {
        self.args.deinit(self.gpa);
        self.inst_results.deinit(self.gpa);
        self.wip_pointers.deinit(self.gpa);
        self.blocks.deinit(self.gpa);
        self.func.deinit(self.gpa);
        self.base_line_stack.deinit(self.gpa);
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
                const spv_decl_index = try self.object.resolveDecl(mod, fn_decl_index);
                try self.func.decl_deps.put(self.spv.gpa, spv_decl_index, {});
                return self.spv.declPtr(spv_decl_index).result_id;
            }

            return try self.constant(ty, val, .direct);
        }
        const index = Air.refToIndex(inst).?;
        return self.inst_results.get(index).?; // Assertion means instruction does not dominate usage.
    }

    fn resolveAnonDecl(self: *DeclGen, val: InternPool.Index, storage_class: StorageClass) !IdRef {
        // TODO: This cannot be a function at this point, but it should probably be handled anyway.
        const spv_decl_index = blk: {
            const entry = try self.object.anon_decl_link.getOrPut(self.object.gpa, .{ val, storage_class });
            if (entry.found_existing) {
                try self.func.decl_deps.put(self.spv.gpa, entry.value_ptr.*, {});
                return self.spv.declPtr(entry.value_ptr.*).result_id;
            }

            const spv_decl_index = try self.spv.allocDecl(.global);
            try self.func.decl_deps.put(self.spv.gpa, spv_decl_index, {});
            entry.value_ptr.* = spv_decl_index;
            break :blk spv_decl_index;
        };

        const mod = self.module;
        const ty = mod.intern_pool.typeOf(val).toType();
        const ptr_ty_ref = try self.ptrType(ty, storage_class);

        const var_id = self.spv.declPtr(spv_decl_index).result_id;

        const section = &self.spv.sections.types_globals_constants;
        try section.emit(self.spv.gpa, .OpVariable, .{
            .id_result_type = self.typeId(ptr_ty_ref),
            .id_result = var_id,
            .storage_class = storage_class,
        });

        // TODO: At some point we will be able to generate this all constant here, but then all of
        //   constant() will need to be implemented such that it doesn't generate any at-runtime code.
        // NOTE: Because this is a global, we really only want to initialize it once. Therefore the
        //   constant lowering of this value will need to be deferred to some other function, which
        //   is then added to the list of initializers using endGlobal().

        // Save the current state so that we can temporarily generate into a different function.
        // TODO: This should probably be made a little more robust.
        const func = self.func;
        defer self.func = func;
        const block_label_id = self.current_block_label_id;
        defer self.current_block_label_id = block_label_id;

        self.func = .{};

        // TODO: Merge this with genDecl?
        const begin = self.spv.beginGlobal();

        const void_ty_ref = try self.resolveType(Type.void, .direct);
        const initializer_proto_ty_ref = try self.spv.resolve(.{ .function_type = .{
            .return_type = void_ty_ref,
            .parameters = &.{},
        } });

        const initializer_id = self.spv.allocId();
        try self.func.prologue.emit(self.spv.gpa, .OpFunction, .{
            .id_result_type = self.typeId(void_ty_ref),
            .id_result = initializer_id,
            .function_control = .{},
            .function_type = self.typeId(initializer_proto_ty_ref),
        });
        const root_block_id = self.spv.allocId();
        try self.func.prologue.emit(self.spv.gpa, .OpLabel, .{
            .id_result = root_block_id,
        });
        self.current_block_label_id = root_block_id;

        const val_id = try self.constant(ty, val.toValue(), .indirect);
        try self.func.body.emit(self.spv.gpa, .OpStore, .{
            .pointer = var_id,
            .object = val_id,
        });

        self.spv.endGlobal(spv_decl_index, begin, var_id, initializer_id);
        try self.func.body.emit(self.spv.gpa, .OpReturn, {});
        try self.func.body.emit(self.spv.gpa, .OpFunctionEnd, {});
        try self.spv.addFunction(spv_decl_index, self.func);

        try self.spv.debugNameFmt(var_id, "__anon_{d}", .{@intFromEnum(val)});
        try self.spv.debugNameFmt(initializer_id, "initializer of __anon_{d}", .{@intFromEnum(val)});

        return var_id;
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
                .backing_bits = self.backingIntBits(1).?,
                .is_vector = false,
                .signedness = .unsigned, // Technically, but doesn't matter for this class.
                .class = .bool,
            },
            .Float => ArithmeticTypeInfo{
                .bits = ty.floatBits(target),
                .backing_bits = ty.floatBits(target), // TODO: F80?
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
                    .backing_bits = maybe_backing_bits orelse 0,
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
            .Enum => return self.arithmeticTypeInfo(ty.intTagType(mod)),
            // As of yet, there is no vector support in the self-hosted compiler.
            .Vector => blk: {
                const child_type = ty.childType(mod);
                const child_ty_info = try self.arithmeticTypeInfo(child_type);
                break :blk ArithmeticTypeInfo{
                    .bits = child_ty_info.bits,
                    .backing_bits = child_ty_info.backing_bits,
                    .is_vector = true,
                    .signedness = child_ty_info.signedness,
                    .class = child_ty_info.class,
                };
            },
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
                return self.constInt(int_ty_ref, @intFromBool(value));
            },
            .direct => {
                const bool_ty_ref = try self.resolveType(Type.bool, .direct);
                return self.spv.constBool(bool_ty_ref, value);
            },
        }
    }

    /// Emits an integer constant.
    /// This function, unlike SpvModule.constInt, takes care to bitcast
    /// the value to an unsigned int first for Kernels.
    fn constInt(self: *DeclGen, ty_ref: CacheRef, value: anytype) !IdRef {
        if (value < 0) {
            const ty = self.spv.cache.lookup(ty_ref).int_type;
            // Manually truncate the value so that the resulting value
            // fits within the unsigned type.
            const bits: u64 = @bitCast(@as(i64, @intCast(value)));
            const truncated_bits = if (ty.bits == 64)
                bits
            else
                bits & (@as(u64, 1) << @intCast(ty.bits)) - 1;
            return try self.spv.constInt(ty_ref, truncated_bits);
        } else {
            return try self.spv.constInt(ty_ref, value);
        }
    }

    /// Construct a struct at runtime.
    /// ty must be a struct type.
    /// Constituents should be in `indirect` representation (as the elements of a struct should be).
    /// Result is in `direct` representation.
    fn constructStruct(self: *DeclGen, ty: Type, types: []const Type, constituents: []const IdRef) !IdRef {
        assert(types.len == constituents.len);
        // The Khronos LLVM-SPIRV translator crashes because it cannot construct structs which'
        // operands are not constant.
        // See https://github.com/KhronosGroup/SPIRV-LLVM-Translator/issues/1349
        // For now, just initialize the struct by setting the fields manually...
        // TODO: Make this OpCompositeConstruct when we can
        const ptr_composite_id = try self.alloc(ty, .{ .storage_class = .Function });
        for (constituents, types, 0..) |constitent_id, member_ty, index| {
            const ptr_member_ty_ref = try self.ptrType(member_ty, .Function);
            const ptr_id = try self.accessChain(ptr_member_ty_ref, ptr_composite_id, &.{@as(u32, @intCast(index))});
            try self.func.body.emit(self.spv.gpa, .OpStore, .{
                .pointer = ptr_id,
                .object = constitent_id,
            });
        }
        return try self.load(ty, ptr_composite_id, .{});
    }

    /// Construct an array at runtime.
    /// ty must be an array type.
    /// Constituents should be in `indirect` representation (as the elements of an array should be).
    /// Result is in `direct` representation.
    fn constructArray(self: *DeclGen, ty: Type, constituents: []const IdRef) !IdRef {
        // The Khronos LLVM-SPIRV translator crashes because it cannot construct structs which'
        // operands are not constant.
        // See https://github.com/KhronosGroup/SPIRV-LLVM-Translator/issues/1349
        // For now, just initialize the struct by setting the fields manually...
        // TODO: Make this OpCompositeConstruct when we can
        const mod = self.module;
        const ptr_composite_id = try self.alloc(ty, .{ .storage_class = .Function });
        const ptr_elem_ty_ref = try self.ptrType(ty.elemType2(mod), .Function);
        for (constituents, 0..) |constitent_id, index| {
            const ptr_id = try self.accessChain(ptr_elem_ty_ref, ptr_composite_id, &.{@as(u32, @intCast(index))});
            try self.func.body.emit(self.spv.gpa, .OpStore, .{
                .pointer = ptr_id,
                .object = constitent_id,
            });
        }

        return try self.load(ty, ptr_composite_id, .{});
    }

    /// This function generates a load for a constant in direct (ie, non-memory) representation.
    /// When the constant is simple, it can be generated directly using OpConstant instructions.
    /// When the constant is more complicated however, it needs to be constructed using multiple values. This
    /// is done by emitting a sequence of instructions that initialize the value.
    //
    /// This function should only be called during function code generation.
    fn constant(self: *DeclGen, ty: Type, arg_val: Value, repr: Repr) !IdRef {
        const mod = self.module;
        const target = self.getTarget();
        const result_ty_ref = try self.resolveType(ty, repr);
        const ip = &mod.intern_pool;

        const val = arg_val;

        log.debug("constant: ty = {}, val = {}", .{ ty.fmt(mod), val.fmtValue(ty, mod) });
        if (val.isUndefDeep(mod)) {
            return self.spv.constUndef(result_ty_ref);
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

            .undef => unreachable, // handled above

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

                .false, .true => return try self.constBool(val.toBool(), repr),
            },

            .int => {
                if (ty.isSignedInt(mod)) {
                    return try self.constInt(result_ty_ref, val.toSignedInt(mod));
                } else {
                    return try self.constInt(result_ty_ref, val.toUnsignedInt(mod));
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
                return try self.constInt(result_ty_ref, value);
            },
            .error_union => |error_union| {
                // TODO: Error unions may be constructed with constant instructions if the payload type
                // allows it. For now, just generate it here regardless.
                const err_int_ty = try mod.errorIntType();
                const err_ty = switch (error_union.val) {
                    .err_name => ty.errorUnionSet(mod),
                    .payload => err_int_ty,
                };
                const err_val = switch (error_union.val) {
                    .err_name => |err_name| (try mod.intern(.{ .err = .{
                        .ty = ty.errorUnionSet(mod).toIntern(),
                        .name = err_name,
                    } })).toValue(),
                    .payload => try mod.intValue(err_int_ty, 0),
                };
                const payload_ty = ty.errorUnionPayload(mod);
                const eu_layout = self.errorUnionLayout(payload_ty);
                if (!eu_layout.payload_has_bits) {
                    // We use the error type directly as the type.
                    return try self.constant(err_ty, err_val, .indirect);
                }

                const payload_val = switch (error_union.val) {
                    .err_name => try mod.intern(.{ .undef = payload_ty.toIntern() }),
                    .payload => |payload| payload,
                }.toValue();

                var constituents: [2]IdRef = undefined;
                var types: [2]Type = undefined;
                if (eu_layout.error_first) {
                    constituents[0] = try self.constant(err_ty, err_val, .indirect);
                    constituents[1] = try self.constant(payload_ty, payload_val, .indirect);
                    types = .{ err_ty, payload_ty };
                } else {
                    constituents[0] = try self.constant(payload_ty, payload_val, .indirect);
                    constituents[1] = try self.constant(err_ty, err_val, .indirect);
                    types = .{ payload_ty, err_ty };
                }

                return try self.constructStruct(ty, &types, &constituents);
            },
            .enum_tag => {
                const int_val = try val.intFromEnum(ty, mod);
                const int_ty = ty.intTagType(mod);
                return try self.constant(int_ty, int_val, repr);
            },
            .ptr => |ptr| {
                const ptr_ty = switch (ptr.len) {
                    .none => ty,
                    else => ty.slicePtrFieldType(mod),
                };
                const ptr_id = try self.constantPtr(ptr_ty, val);
                if (ptr.len == .none) {
                    return ptr_id;
                }

                const len_id = try self.constant(Type.usize, ptr.len.toValue(), .indirect);
                return try self.constructStruct(
                    ty,
                    &.{ ptr_ty, Type.usize },
                    &.{ ptr_id, len_id },
                );
            },
            .opt => {
                const payload_ty = ty.optionalChild(mod);
                const maybe_payload_val = val.optionalValue(mod);

                if (!payload_ty.hasRuntimeBits(mod)) {
                    return try self.constBool(maybe_payload_val != null, .indirect);
                } else if (ty.optionalReprIsPayload(mod)) {
                    // Optional representation is a nullable pointer or slice.
                    if (maybe_payload_val) |payload_val| {
                        return try self.constant(payload_ty, payload_val, .indirect);
                    } else {
                        const ptr_ty_ref = try self.resolveType(ty, .indirect);
                        return self.spv.constNull(ptr_ty_ref);
                    }
                }

                // Optional representation is a structure.
                // { Payload, Bool }

                const has_pl_id = try self.constBool(maybe_payload_val != null, .indirect);
                const payload_id = if (maybe_payload_val) |payload_val|
                    try self.constant(payload_ty, payload_val, .indirect)
                else
                    try self.spv.constUndef(try self.resolveType(payload_ty, .indirect));

                return try self.constructStruct(
                    ty,
                    &.{ payload_ty, Type.bool },
                    &.{ payload_id, has_pl_id },
                );
            },
            .aggregate => |aggregate| switch (ip.indexToKey(ty.ip_index)) {
                inline .array_type, .vector_type => |array_type, tag| {
                    const elem_ty = array_type.child.toType();
                    const elem_ty_ref = try self.resolveType(elem_ty, .indirect);

                    const constituents = try self.gpa.alloc(IdRef, @as(u32, @intCast(ty.arrayLenIncludingSentinel(mod))));
                    defer self.gpa.free(constituents);

                    switch (aggregate.storage) {
                        .bytes => |bytes| {
                            // TODO: This is really space inefficient, perhaps there is a better
                            // way to do it?
                            for (bytes, 0..) |byte, i| {
                                constituents[i] = try self.constInt(elem_ty_ref, byte);
                            }
                        },
                        .elems => |elems| {
                            for (0..@as(usize, @intCast(array_type.len))) |i| {
                                constituents[i] = try self.constant(elem_ty, elems[i].toValue(), .indirect);
                            }
                        },
                        .repeated_elem => |elem| {
                            const val_id = try self.constant(elem_ty, elem.toValue(), .indirect);
                            for (0..@as(usize, @intCast(array_type.len))) |i| {
                                constituents[i] = val_id;
                            }
                        },
                    }

                    switch (tag) {
                        inline .array_type => if (array_type.sentinel != .none) {
                            constituents[constituents.len - 1] = try self.constant(elem_ty, array_type.sentinel.toValue(), .indirect);
                        },
                        else => {},
                    }

                    return try self.constructArray(ty, constituents);
                },
                .struct_type => {
                    const struct_type = mod.typeToStruct(ty).?;
                    if (struct_type.layout == .Packed) {
                        return self.todo("packed struct constants", .{});
                    }

                    var types = std.ArrayList(Type).init(self.gpa);
                    defer types.deinit();

                    var constituents = std.ArrayList(IdRef).init(self.gpa);
                    defer constituents.deinit();

                    var it = struct_type.iterateRuntimeOrder(ip);
                    while (it.next()) |field_index| {
                        const field_ty = struct_type.field_types.get(ip)[field_index].toType();
                        if (!field_ty.hasRuntimeBitsIgnoreComptime(mod)) {
                            // This is a zero-bit field - we only needed it for the alignment.
                            continue;
                        }

                        // TODO: Padding?
                        const field_val = try val.fieldValue(mod, field_index);
                        const field_id = try self.constant(field_ty, field_val, .indirect);

                        try types.append(field_ty);
                        try constituents.append(field_id);
                    }

                    return try self.constructStruct(ty, types.items, constituents.items);
                },
                .anon_struct_type => unreachable, // TODO
                else => unreachable,
            },
            .un => |un| {
                const active_field = ty.unionTagFieldIndex(un.tag.toValue(), mod).?;
                const union_obj = mod.typeToUnion(ty).?;
                const field_ty = union_obj.field_types.get(ip)[active_field].toType();
                const payload = if (field_ty.hasRuntimeBitsIgnoreComptime(mod))
                    try self.constant(field_ty, un.val.toValue(), .direct)
                else
                    null;
                return try self.unionInit(ty, active_field, payload);
            },
            .memoized_call => unreachable,
        }
    }

    fn constantPtr(self: *DeclGen, ptr_ty: Type, ptr_val: Value) Error!IdRef {
        const result_ty_ref = try self.resolveType(ptr_ty, .direct);
        const mod = self.module;
        switch (mod.intern_pool.indexToKey(ptr_val.toIntern()).ptr.addr) {
            .decl => |decl| return try self.constantDeclRef(ptr_ty, decl),
            .mut_decl => |decl_mut| return try self.constantDeclRef(ptr_ty, decl_mut.decl),
            .anon_decl => |anon_decl| return try self.constantAnonDeclRef(ptr_ty, anon_decl),
            .int => |int| {
                const ptr_id = self.spv.allocId();
                // TODO: This can probably be an OpSpecConstantOp Bitcast, but
                // that is not implemented by Mesa yet. Therefore, just generate it
                // as a runtime operation.
                try self.func.body.emit(self.spv.gpa, .OpConvertUToPtr, .{
                    .id_result_type = self.typeId(result_ty_ref),
                    .id_result = ptr_id,
                    .integer_value = try self.constant(Type.usize, int.toValue(), .direct),
                });
                return ptr_id;
            },
            .eu_payload => unreachable, // TODO
            .opt_payload => unreachable, // TODO
            .comptime_field => unreachable,
            .elem => |elem_ptr| {
                const parent_ptr_ty = mod.intern_pool.typeOf(elem_ptr.base).toType();
                const parent_ptr_id = try self.constantPtr(parent_ptr_ty, elem_ptr.base.toValue());
                const size_ty_ref = try self.sizeType();
                const index_id = try self.constInt(size_ty_ref, elem_ptr.index);

                const elem_ptr_id = try self.ptrElemPtr(parent_ptr_ty, parent_ptr_id, index_id);

                // TODO: Can we consolidate this in ptrElemPtr?
                const elem_ty = parent_ptr_ty.elemType2(mod); // use elemType() so that we get T for *[N]T.
                const elem_ptr_ty_ref = try self.ptrType(elem_ty, spvStorageClass(parent_ptr_ty.ptrAddressSpace(mod)));

                if (elem_ptr_ty_ref == result_ty_ref) {
                    return elem_ptr_id;
                }
                // This may happen when we have pointer-to-array and the result is
                // another pointer-to-array instead of a pointer-to-element.
                const result_id = self.spv.allocId();
                try self.func.body.emit(self.spv.gpa, .OpBitcast, .{
                    .id_result_type = self.typeId(result_ty_ref),
                    .id_result = result_id,
                    .operand = elem_ptr_id,
                });
                return result_id;
            },
            .field => |field| {
                const base_ptr_ty = mod.intern_pool.typeOf(field.base).toType();
                const base_ptr = try self.constantPtr(base_ptr_ty, field.base.toValue());
                const field_index: u32 = @intCast(field.index);
                return try self.structFieldPtr(ptr_ty, base_ptr_ty, base_ptr, field_index);
            },
        }
    }

    fn constantAnonDeclRef(
        self: *DeclGen,
        ty: Type,
        anon_decl: InternPool.Key.Ptr.Addr.AnonDecl,
    ) !IdRef {
        // TODO: Merge this function with constantDeclRef.

        const mod = self.module;
        const ip = &mod.intern_pool;
        const ty_ref = try self.resolveType(ty, .direct);
        const decl_val = anon_decl.val;
        const decl_ty = ip.typeOf(decl_val).toType();

        if (decl_val.toValue().getFunction(mod)) |func| {
            _ = func;
            unreachable; // TODO
        } else if (decl_val.toValue().getExternFunc(mod)) |func| {
            _ = func;
            unreachable;
        }

        // const is_fn_body = decl_ty.zigTypeTag(mod) == .Fn;
        if (!decl_ty.isFnOrHasRuntimeBitsIgnoreComptime(mod)) {
            // Pointer to nothing - return undefoined
            return self.spv.constUndef(ty_ref);
        }

        if (decl_ty.zigTypeTag(mod) == .Fn) {
            unreachable; // TODO
        }

        const final_storage_class = spvStorageClass(ty.ptrAddressSpace(mod));
        const actual_storage_class = switch (final_storage_class) {
            .Generic => .CrossWorkgroup,
            else => |other| other,
        };

        const decl_id = try self.resolveAnonDecl(decl_val, actual_storage_class);
        const decl_ptr_ty_ref = try self.ptrType(decl_ty, final_storage_class);

        const ptr_id = switch (final_storage_class) {
            .Generic => blk: {
                const result_id = self.spv.allocId();
                try self.func.body.emit(self.spv.gpa, .OpPtrCastToGeneric, .{
                    .id_result_type = self.typeId(decl_ptr_ty_ref),
                    .id_result = result_id,
                    .pointer = decl_id,
                });
                break :blk result_id;
            },
            else => decl_id,
        };

        if (decl_ptr_ty_ref != ty_ref) {
            // Differing pointer types, insert a cast.
            const casted_ptr_id = self.spv.allocId();
            try self.func.body.emit(self.spv.gpa, .OpBitcast, .{
                .id_result_type = self.typeId(ty_ref),
                .id_result = casted_ptr_id,
                .operand = ptr_id,
            });
            return casted_ptr_id;
        } else {
            return ptr_id;
        }
    }

    fn constantDeclRef(self: *DeclGen, ty: Type, decl_index: Decl.Index) !IdRef {
        const mod = self.module;
        const ty_ref = try self.resolveType(ty, .direct);
        const ty_id = self.typeId(ty_ref);
        const decl = mod.declPtr(decl_index);
        switch (mod.intern_pool.indexToKey(decl.val.ip_index)) {
            .func => {
                // TODO: Properly lower function pointers. For now we are going to hack around it and
                // just generate an empty pointer. Function pointers are represented by a pointer to usize.
                return try self.spv.constUndef(ty_ref);
            },
            .extern_func => unreachable, // TODO
            else => {},
        }

        if (!decl.ty.isFnOrHasRuntimeBitsIgnoreComptime(mod)) {
            // Pointer to nothing - return undefined.
            return self.spv.constUndef(ty_ref);
        }

        const spv_decl_index = try self.object.resolveDecl(mod, decl_index);

        const decl_id = self.spv.declPtr(spv_decl_index).result_id;
        try self.func.decl_deps.put(self.spv.gpa, spv_decl_index, {});

        const final_storage_class = spvStorageClass(decl.@"addrspace");

        const decl_ptr_ty_ref = try self.ptrType(decl.ty, final_storage_class);

        const ptr_id = switch (final_storage_class) {
            .Generic => blk: {
                // Pointer should be Generic, but is actually placed in CrossWorkgroup.
                const result_id = self.spv.allocId();
                try self.func.body.emit(self.spv.gpa, .OpPtrCastToGeneric, .{
                    .id_result_type = self.typeId(decl_ptr_ty_ref),
                    .id_result = result_id,
                    .pointer = decl_id,
                });
                break :blk result_id;
            },
            else => decl_id,
        };

        if (decl_ptr_ty_ref != ty_ref) {
            // Differing pointer types, insert a cast.
            const casted_ptr_id = self.spv.allocId();
            try self.func.body.emit(self.spv.gpa, .OpBitcast, .{
                .id_result_type = ty_id,
                .id_result = casted_ptr_id,
                .operand = ptr_id,
            });
            return casted_ptr_id;
        } else {
            return ptr_id;
        }
    }

    // Turn a Zig type's name into a cache reference.
    fn resolveTypeName(self: *DeclGen, ty: Type) !CacheString {
        var name = std.ArrayList(u8).init(self.gpa);
        defer name.deinit();
        try ty.print(name.writer(), self.module);
        return try self.spv.resolveString(name.items);
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
        // Kernel only supports unsigned ints.
        // TODO: Only do this with Kernels
        return self.spv.intType(.unsigned, backing_bits);
    }

    /// Create an integer type that represents 'usize'.
    fn sizeType(self: *DeclGen) !CacheRef {
        return try self.intType(.unsigned, self.getTarget().ptrBitWidth());
    }

    fn ptrType(self: *DeclGen, child_ty: Type, storage_class: StorageClass) !CacheRef {
        const key = .{ child_ty.toIntern(), storage_class };
        const entry = try self.wip_pointers.getOrPut(self.gpa, key);
        if (entry.found_existing) {
            const fwd_ref = entry.value_ptr.*;
            try self.spv.cache.recursive_ptrs.put(self.spv.gpa, fwd_ref, {});
            return fwd_ref;
        }

        const fwd_ref = try self.spv.resolve(.{ .fwd_ptr_type = .{
            .zig_child_type = child_ty.toIntern(),
            .storage_class = storage_class,
        } });
        entry.value_ptr.* = fwd_ref;

        const child_ty_ref = try self.resolveType(child_ty, .indirect);
        _ = try self.spv.resolve(.{ .ptr_type = .{
            .storage_class = storage_class,
            .child_type = child_ty_ref,
            .fwd = fwd_ref,
        } });

        assert(self.wip_pointers.remove(key));

        return fwd_ref;
    }

    /// Generate a union type. Union types are always generated with the
    /// most aligned field active. If the tag alignment is greater
    /// than that of the payload, a regular union (non-packed, with both tag and
    /// payload), will be generated as follows:
    ///  struct {
    ///    tag: TagType,
    ///    payload: MostAlignedFieldType,
    ///    payload_padding: [payload_size - @sizeOf(MostAlignedFieldType)]u8,
    ///    padding: [padding_size]u8,
    ///  }
    /// If the payload alignment is greater than that of the tag:
    ///  struct {
    ///    payload: MostAlignedFieldType,
    ///    payload_padding: [payload_size - @sizeOf(MostAlignedFieldType)]u8,
    ///    tag: TagType,
    ///    padding: [padding_size]u8,
    ///  }
    /// If any of the fields' size is 0, it will be omitted.
    fn resolveUnionType(self: *DeclGen, ty: Type) !CacheRef {
        const mod = self.module;
        const ip = &mod.intern_pool;
        const union_obj = mod.typeToUnion(ty).?;

        if (union_obj.getLayout(ip) == .Packed) {
            return self.todo("packed union types", .{});
        }

        const layout = self.unionLayout(ty);
        if (!layout.has_payload) {
            // No payload, so represent this as just the tag type.
            return try self.resolveType(union_obj.enum_tag_ty.toType(), .indirect);
        }

        if (self.type_map.get(ty.toIntern())) |info| return info.ty_ref;

        var member_types: [4]CacheRef = undefined;
        var member_names: [4]CacheString = undefined;

        const u8_ty_ref = try self.intType(.unsigned, 8); // TODO: What if Int8Type is not enabled?

        if (layout.tag_size != 0) {
            const tag_ty_ref = try self.resolveType(union_obj.enum_tag_ty.toType(), .indirect);
            member_types[layout.tag_index] = tag_ty_ref;
            member_names[layout.tag_index] = try self.spv.resolveString("(tag)");
        }

        if (layout.payload_size != 0) {
            const payload_ty_ref = try self.resolveType(layout.payload_ty, .indirect);
            member_types[layout.payload_index] = payload_ty_ref;
            member_names[layout.payload_index] = try self.spv.resolveString("(payload)");
        }

        if (layout.payload_padding_size != 0) {
            const payload_padding_ty_ref = try self.spv.arrayType(@intCast(layout.payload_padding_size), u8_ty_ref);
            member_types[layout.payload_padding_index] = payload_padding_ty_ref;
            member_names[layout.payload_padding_index] = try self.spv.resolveString("(payload padding)");
        }

        if (layout.padding_size != 0) {
            const padding_ty_ref = try self.spv.arrayType(@intCast(layout.padding_size), u8_ty_ref);
            member_types[layout.padding_index] = padding_ty_ref;
            member_names[layout.padding_index] = try self.spv.resolveString("(padding)");
        }

        const ty_ref = try self.spv.resolve(.{ .struct_type = .{
            .name = try self.resolveTypeName(ty),
            .member_types = member_types[0..layout.total_fields],
            .member_names = member_names[0..layout.total_fields],
        } });

        try self.type_map.put(self.gpa, ty.toIntern(), .{ .ty_ref = ty_ref });
        return ty_ref;
    }

    fn resolveFnReturnType(self: *DeclGen, ret_ty: Type) !CacheRef {
        const mod = self.module;
        if (!ret_ty.hasRuntimeBitsIgnoreComptime(mod)) {
            // If the return type is an error set or an error union, then we make this
            // anyerror return type instead, so that it can be coerced into a function
            // pointer type which has anyerror as the return type.
            if (ret_ty.isError(mod)) {
                return self.resolveType(Type.anyerror, .direct);
            } else {
                return self.resolveType(Type.void, .direct);
            }
        }

        return try self.resolveType(ret_ty, .direct);
    }

    /// Turn a Zig type into a SPIR-V Type, and return a reference to it.
    fn resolveType(self: *DeclGen, ty: Type, repr: Repr) Error!CacheRef {
        const mod = self.module;
        const ip = &mod.intern_pool;
        log.debug("resolveType: ty = {}", .{ty.fmt(mod)});
        const target = self.getTarget();
        switch (ty.zigTypeTag(mod)) {
            .NoReturn => {
                assert(repr == .direct);
                return try self.spv.resolve(.void_type);
            },
            .Void => switch (repr) {
                .direct => return try self.spv.resolve(.void_type),
                // Pointers to void
                .indirect => return try self.spv.resolve(.{ .opaque_type = .{
                    .name = try self.spv.resolveString("void"),
                } }),
            },
            .Bool => switch (repr) {
                .direct => return try self.spv.resolve(.bool_type),
                .indirect => return try self.intType(.unsigned, 1),
            },
            .Int => {
                const int_info = ty.intInfo(mod);
                if (int_info.bits == 0) {
                    // Some times, the backend will be asked to generate a pointer to i0. OpTypeInt
                    // with 0 bits is invalid, so return an opaque type in this case.
                    assert(repr == .indirect);
                    return try self.spv.resolve(.{ .opaque_type = .{
                        .name = try self.spv.resolveString("u0"),
                    } });
                }
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
                if (self.type_map.get(ty.toIntern())) |info| return info.ty_ref;

                const elem_ty = ty.childType(mod);
                const elem_ty_ref = try self.resolveType(elem_ty, .indirect);
                var total_len = std.math.cast(u32, ty.arrayLenIncludingSentinel(mod)) orelse {
                    return self.fail("array type of {} elements is too large", .{ty.arrayLenIncludingSentinel(mod)});
                };
                const ty_ref = if (!elem_ty.hasRuntimeBitsIgnoreComptime(mod)) blk: {
                    // The size of the array would be 0, but that is not allowed in SPIR-V.
                    // This path can be reached when the backend is asked to generate a pointer to
                    // an array of some zero-bit type. This should always be an indirect path.
                    assert(repr == .indirect);

                    // We cannot use the child type here, so just use an opaque type.
                    break :blk try self.spv.resolve(.{ .opaque_type = .{
                        .name = try self.spv.resolveString("zero-sized array"),
                    } });
                } else if (total_len == 0) blk: {
                    // The size of the array would be 0, but that is not allowed in SPIR-V.
                    // This path can be reached for example when there is a slicing of a pointer
                    // that produces a zero-length array. In all cases where this type can be generated,
                    // this should be an indirect path.
                    assert(repr == .indirect);

                    // In this case, we have an array of a non-zero sized type. In this case,
                    // generate an array of 1 element instead, so that ptr_elem_ptr instructions
                    // can be lowered to ptrAccessChain instead of manually performing the math.
                    break :blk try self.spv.arrayType(1, elem_ty_ref);
                } else try self.spv.arrayType(total_len, elem_ty_ref);

                try self.type_map.put(self.gpa, ty.toIntern(), .{ .ty_ref = ty_ref });
                return ty_ref;
            },
            .Fn => switch (repr) {
                .direct => {
                    if (self.type_map.get(ty.toIntern())) |info| return info.ty_ref;

                    const fn_info = mod.typeToFunc(ty).?;
                    // TODO: Put this somewhere in Sema.zig
                    if (fn_info.is_var_args)
                        return self.fail("VarArgs functions are unsupported for SPIR-V", .{});

                    const param_ty_refs = try self.gpa.alloc(CacheRef, fn_info.param_types.len);
                    defer self.gpa.free(param_ty_refs);
                    var param_index: usize = 0;
                    for (fn_info.param_types.get(ip)) |param_ty_index| {
                        const param_ty = param_ty_index.toType();
                        if (!param_ty.hasRuntimeBitsIgnoreComptime(mod)) continue;

                        param_ty_refs[param_index] = try self.resolveType(param_ty, .direct);
                        param_index += 1;
                    }
                    const return_ty_ref = try self.resolveFnReturnType(fn_info.return_type.toType());

                    const ty_ref = try self.spv.resolve(.{ .function_type = .{
                        .return_type = return_ty_ref,
                        .parameters = param_ty_refs[0..param_index],
                    } });

                    try self.type_map.put(self.gpa, ty.toIntern(), .{ .ty_ref = ty_ref });
                    return ty_ref;
                },
                .indirect => {
                    // TODO: Represent function pointers properly.
                    // For now, just use an usize type.
                    return try self.sizeType();
                },
            },
            .Pointer => {
                const ptr_info = ty.ptrInfo(mod);

                // Note: Don't cache this pointer type, it would mess up the recursive pointer functionality
                // in ptrType()!

                const storage_class = spvStorageClass(ptr_info.flags.address_space);
                const ptr_ty_ref = try self.ptrType(ptr_info.child.toType(), storage_class);

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
                if (self.type_map.get(ty.toIntern())) |info| return info.ty_ref;

                const elem_ty = ty.childType(mod);
                const elem_ty_ref = try self.resolveType(elem_ty, .indirect);

                const ty_ref = try self.spv.arrayType(ty.vectorLen(mod), elem_ty_ref);
                try self.type_map.put(self.gpa, ty.toIntern(), .{ .ty_ref = ty_ref });
                return ty_ref;
            },
            .Struct => {
                if (self.type_map.get(ty.toIntern())) |info| return info.ty_ref;

                const struct_type = switch (ip.indexToKey(ty.toIntern())) {
                    .anon_struct_type => |tuple| {
                        const member_types = try self.gpa.alloc(CacheRef, tuple.values.len);
                        defer self.gpa.free(member_types);

                        var member_index: usize = 0;
                        for (tuple.types.get(ip), tuple.values.get(ip)) |field_ty, field_val| {
                            if (field_val != .none or !field_ty.toType().hasRuntimeBits(mod)) continue;

                            member_types[member_index] = try self.resolveType(field_ty.toType(), .indirect);
                            member_index += 1;
                        }

                        const ty_ref = try self.spv.resolve(.{ .struct_type = .{
                            .name = try self.resolveTypeName(ty),
                            .member_types = member_types[0..member_index],
                        } });

                        try self.type_map.put(self.gpa, ty.toIntern(), .{ .ty_ref = ty_ref });
                        return ty_ref;
                    },
                    .struct_type => |struct_type| struct_type,
                    else => unreachable,
                };

                if (struct_type.layout == .Packed) {
                    return try self.resolveType(struct_type.backingIntType(ip).toType(), .direct);
                }

                var member_types = std.ArrayList(CacheRef).init(self.gpa);
                defer member_types.deinit();

                var member_names = std.ArrayList(CacheString).init(self.gpa);
                defer member_names.deinit();

                var it = struct_type.iterateRuntimeOrder(ip);
                while (it.next()) |field_index| {
                    const field_ty = struct_type.field_types.get(ip)[field_index].toType();
                    if (!field_ty.hasRuntimeBitsIgnoreComptime(mod)) {
                        // This is a zero-bit field - we only needed it for the alignment.
                        continue;
                    }

                    const field_name = struct_type.fieldName(ip, field_index).unwrap() orelse
                        try ip.getOrPutStringFmt(mod.gpa, "{d}", .{field_index});
                    try member_types.append(try self.resolveType(field_ty, .indirect));
                    try member_names.append(try self.spv.resolveString(ip.stringToSlice(field_name)));
                }

                const ty_ref = try self.spv.resolve(.{ .struct_type = .{
                    .name = try self.resolveTypeName(ty),
                    .member_types = member_types.items,
                    .member_names = member_names.items,
                } });

                try self.type_map.put(self.gpa, ty.toIntern(), .{ .ty_ref = ty_ref });
                return ty_ref;
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

                if (self.type_map.get(ty.toIntern())) |info| return info.ty_ref;

                const bool_ty_ref = try self.resolveType(Type.bool, .indirect);

                const ty_ref = try self.spv.resolve(.{ .struct_type = .{
                    .member_types = &.{ payload_ty_ref, bool_ty_ref },
                    .member_names = &.{
                        try self.spv.resolveString("payload"),
                        try self.spv.resolveString("valid"),
                    },
                } });

                try self.type_map.put(self.gpa, ty.toIntern(), .{ .ty_ref = ty_ref });
                return ty_ref;
            },
            .Union => return try self.resolveUnionType(ty),
            .ErrorSet => return try self.intType(.unsigned, 16),
            .ErrorUnion => {
                const payload_ty = ty.errorUnionPayload(mod);
                const error_ty_ref = try self.resolveType(Type.anyerror, .indirect);

                const eu_layout = self.errorUnionLayout(payload_ty);
                if (!eu_layout.payload_has_bits) {
                    return error_ty_ref;
                }

                if (self.type_map.get(ty.toIntern())) |info| return info.ty_ref;

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

                const ty_ref = try self.spv.resolve(.{ .struct_type = .{
                    .name = try self.resolveTypeName(ty),
                    .member_types = &member_types,
                    .member_names = &member_names,
                } });

                try self.type_map.put(self.gpa, ty.toIntern(), .{ .ty_ref = ty_ref });
                return ty_ref;
            },
            .Opaque => {
                return try self.spv.resolve(.{
                    .opaque_type = .{
                        .name = .none, // TODO
                    },
                });
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

        const error_first = error_align.compare(.gt, payload_align);
        return .{
            .payload_has_bits = payload_ty.hasRuntimeBitsIgnoreComptime(mod),
            .error_first = error_first,
        };
    }

    const UnionLayout = struct {
        /// If false, this union is represented
        /// by only an integer of the tag type.
        has_payload: bool,
        tag_size: u32,
        tag_index: u32,
        /// Note: This is the size of the payload type itself, NOT the size of the ENTIRE payload.
        /// Use `has_payload` instead!!
        payload_ty: Type,
        payload_size: u32,
        payload_index: u32,
        payload_padding_size: u32,
        payload_padding_index: u32,
        padding_size: u32,
        padding_index: u32,
        total_fields: u32,
    };

    fn unionLayout(self: *DeclGen, ty: Type) UnionLayout {
        const mod = self.module;
        const ip = &mod.intern_pool;
        const layout = ty.unionGetLayout(self.module);
        const union_obj = mod.typeToUnion(ty).?;

        var union_layout = UnionLayout{
            .has_payload = layout.payload_size != 0,
            .tag_size = @intCast(layout.tag_size),
            .tag_index = undefined,
            .payload_ty = undefined,
            .payload_size = undefined,
            .payload_index = undefined,
            .payload_padding_size = undefined,
            .payload_padding_index = undefined,
            .padding_size = @intCast(layout.padding),
            .padding_index = undefined,
            .total_fields = undefined,
        };

        if (union_layout.has_payload) {
            const most_aligned_field = layout.most_aligned_field;
            const most_aligned_field_ty = union_obj.field_types.get(ip)[most_aligned_field].toType();
            union_layout.payload_ty = most_aligned_field_ty;
            union_layout.payload_size = @intCast(most_aligned_field_ty.abiSize(mod));
        } else {
            union_layout.payload_size = 0;
        }

        union_layout.payload_padding_size = @intCast(layout.payload_size - union_layout.payload_size);

        const tag_first = layout.tag_align.compare(.gte, layout.payload_align);
        var field_index: u32 = 0;

        if (union_layout.tag_size != 0 and tag_first) {
            union_layout.tag_index = field_index;
            field_index += 1;
        }

        if (union_layout.payload_size != 0) {
            union_layout.payload_index = field_index;
            field_index += 1;
        }

        if (union_layout.payload_padding_size != 0) {
            union_layout.payload_padding_index = field_index;
            field_index += 1;
        }

        if (union_layout.tag_size != 0 and !tag_first) {
            union_layout.tag_index = field_index;
            field_index += 1;
        }

        if (union_layout.padding_size != 0) {
            union_layout.padding_index = field_index;
            field_index += 1;
        }

        union_layout.total_fields = field_index;

        return union_layout;
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
        const ptr_anyerror_ty_ref = try self.ptrType(Type.anyerror, .CrossWorkgroup);
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
        // Note: Convert to direct not required.
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
        const spv_decl_index = try self.object.resolveDecl(mod, self.decl_index);

        const decl_id = self.spv.declPtr(spv_decl_index).result_id;

        try self.base_line_stack.append(self.gpa, decl.src_line);

        if (decl.val.getFunction(mod)) |_| {
            assert(decl.ty.zigTypeTag(mod) == .Fn);
            const fn_info = mod.typeToFunc(decl.ty).?;
            const return_ty_ref = try self.resolveFnReturnType(fn_info.return_type.toType());

            const prototype_id = try self.resolveTypeId(decl.ty);
            try self.func.prologue.emit(self.spv.gpa, .OpFunction, .{
                .id_result_type = self.typeId(return_ty_ref),
                .id_result = decl_id,
                .function_control = .{}, // TODO: We can set inline here if the type requires it.
                .function_type = prototype_id,
            });

            try self.args.ensureUnusedCapacity(self.gpa, fn_info.param_types.len);
            for (fn_info.param_types.get(ip)) |param_ty_index| {
                const param_ty = param_ty_index.toType();
                if (!param_ty.hasRuntimeBitsIgnoreComptime(mod)) continue;

                const param_type_id = try self.resolveTypeId(param_ty);
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
            try self.spv.debugName(decl_id, fqn);

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

            // Currently, initializers for CrossWorkgroup variables is not implemented
            // in Mesa. Therefore we generate an initialization kernel instead.

            const void_ty_ref = try self.resolveType(Type.void, .direct);

            const initializer_proto_ty_ref = try self.spv.resolve(.{ .function_type = .{
                .return_type = void_ty_ref,
                .parameters = &.{},
            } });

            // Generate the actual variable for the global...
            const final_storage_class = spvStorageClass(decl.@"addrspace");
            const actual_storage_class = switch (final_storage_class) {
                .Generic => .CrossWorkgroup,
                else => final_storage_class,
            };

            const ptr_ty_ref = try self.ptrType(decl.ty, actual_storage_class);

            const begin = self.spv.beginGlobal();
            try self.spv.globals.section.emit(self.spv.gpa, .OpVariable, .{
                .id_result_type = self.typeId(ptr_ty_ref),
                .id_result = decl_id,
                .storage_class = actual_storage_class,
            });

            // Now emit the instructions that initialize the variable.
            const initializer_id = self.spv.allocId();
            try self.func.prologue.emit(self.spv.gpa, .OpFunction, .{
                .id_result_type = self.typeId(void_ty_ref),
                .id_result = initializer_id,
                .function_control = .{},
                .function_type = self.typeId(initializer_proto_ty_ref),
            });
            const root_block_id = self.spv.allocId();
            try self.func.prologue.emit(self.spv.gpa, .OpLabel, .{
                .id_result = root_block_id,
            });
            self.current_block_label_id = root_block_id;

            const val_id = try self.constant(decl.ty, init_val, .indirect);
            try self.func.body.emit(self.spv.gpa, .OpStore, .{
                .pointer = decl_id,
                .object = val_id,
            });

            // TODO: We should be able to get rid of this by now...
            self.spv.endGlobal(spv_decl_index, begin, decl_id, initializer_id);

            try self.func.body.emit(self.spv.gpa, .OpReturn, {});
            try self.func.body.emit(self.spv.gpa, .OpFunctionEnd, {});
            try self.spv.addFunction(spv_decl_index, self.func);

            const fqn = ip.stringToSlice(try decl.getFullyQualifiedName(self.module));
            try self.spv.debugName(decl_id, fqn);
            try self.spv.debugNameFmt(initializer_id, "initializer of {s}", .{fqn});
        }
    }

    fn intFromBool(self: *DeclGen, result_ty_ref: CacheRef, condition_id: IdRef) !IdRef {
        const zero_id = try self.constInt(result_ty_ref, 0);
        const one_id = try self.constInt(result_ty_ref, 1);
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
                const zero_id = try self.constInt(indirect_bool_ty_ref, 0);
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

    const MemoryOptions = struct {
        is_volatile: bool = false,
    };

    fn load(self: *DeclGen, value_ty: Type, ptr_id: IdRef, options: MemoryOptions) !IdRef {
        const indirect_value_ty_ref = try self.resolveType(value_ty, .indirect);
        const result_id = self.spv.allocId();
        const access = spec.MemoryAccess.Extended{
            .Volatile = options.is_volatile,
        };
        try self.func.body.emit(self.spv.gpa, .OpLoad, .{
            .id_result_type = self.typeId(indirect_value_ty_ref),
            .id_result = result_id,
            .pointer = ptr_id,
            .memory_access = access,
        });
        return try self.convertToDirect(value_ty, result_id);
    }

    fn store(self: *DeclGen, value_ty: Type, ptr_id: IdRef, value_id: IdRef, options: MemoryOptions) !void {
        const indirect_value_id = try self.convertToIndirect(value_ty, value_id);
        const access = spec.MemoryAccess.Extended{
            .Volatile = options.is_volatile,
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

            .add_with_overflow => try self.airAddSubOverflow(inst, .OpIAdd, .OpULessThan, .OpSLessThan),
            .sub_with_overflow => try self.airAddSubOverflow(inst, .OpISub, .OpUGreaterThan, .OpSGreaterThan),

            .shuffle => try self.airShuffle(inst),

            .ptr_add => try self.airPtrAdd(inst),
            .ptr_sub => try self.airPtrSub(inst),

            .bit_and  => try self.airBinOpSimple(inst, .OpBitwiseAnd),
            .bit_or   => try self.airBinOpSimple(inst, .OpBitwiseOr),
            .xor      => try self.airBinOpSimple(inst, .OpBitwiseXor),
            .bool_and => try self.airBinOpSimple(inst, .OpLogicalAnd),
            .bool_or  => try self.airBinOpSimple(inst, .OpLogicalOr),

            .shl => try self.airShift(inst, .OpShiftLeftLogical),

            .min => try self.airMinMax(inst, .lt),
            .max => try self.airMinMax(inst, .gt),

            .bitcast         => try self.airBitCast(inst),
            .intcast, .trunc => try self.airIntCast(inst),
            .int_from_ptr    => try self.airIntFromPtr(inst),
            .float_from_int  => try self.airFloatFromInt(inst),
            .int_from_float  => try self.airIntFromFloat(inst),
            .fpext, .fptrunc => try self.airFloatCast(inst),
            .not             => try self.airNot(inst),

            .array_to_slice => try self.airArrayToSlice(inst),
            .slice          => try self.airSlice(inst),
            .aggregate_init => try self.airAggregateInit(inst),
            .memcpy         => return self.airMemcpy(inst),

            .slice_ptr      => try self.airSliceField(inst, 0),
            .slice_len      => try self.airSliceField(inst, 1),
            .slice_elem_ptr => try self.airSliceElemPtr(inst),
            .slice_elem_val => try self.airSliceElemVal(inst),
            .ptr_elem_ptr   => try self.airPtrElemPtr(inst),
            .ptr_elem_val   => try self.airPtrElemVal(inst),
            .array_elem_val => try self.airArrayElemVal(inst),

            .set_union_tag => return self.airSetUnionTag(inst),
            .get_union_tag => try self.airGetUnionTag(inst),
            .union_init => try self.airUnionInit(inst),

            .struct_field_val => try self.airStructFieldVal(inst),
            .field_parent_ptr => try self.airFieldParentPtr(inst),

            .struct_field_ptr_index_0 => try self.airStructFieldPtrIndex(inst, 0),
            .struct_field_ptr_index_1 => try self.airStructFieldPtrIndex(inst, 1),
            .struct_field_ptr_index_2 => try self.airStructFieldPtrIndex(inst, 2),
            .struct_field_ptr_index_3 => try self.airStructFieldPtrIndex(inst, 3),

            .cmp_eq     => try self.airCmp(inst, .eq),
            .cmp_neq    => try self.airCmp(inst, .neq),
            .cmp_gt     => try self.airCmp(inst, .gt),
            .cmp_gte    => try self.airCmp(inst, .gte),
            .cmp_lt     => try self.airCmp(inst, .lt),
            .cmp_lte    => try self.airCmp(inst, .lte),
            .cmp_vector => try self.airVectorCmp(inst),

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
            .loop           => return self.airLoop(inst),
            .ret            => return self.airRet(inst),
            .ret_load       => return self.airRetLoad(inst),
            .@"try"         => try self.airTry(inst),
            .switch_br      => return self.airSwitchBr(inst),
            .unreach, .trap => return self.airUnreach(),

            .dbg_stmt                  => return self.airDbgStmt(inst),
            .dbg_inline_begin          => return self.airDbgInlineBegin(inst),
            .dbg_inline_end            => return self.airDbgInlineEnd(inst),
            .dbg_var_ptr, .dbg_var_val => return self.airDbgVar(inst),
            .dbg_block_begin  => return,
            .dbg_block_end    => return,

            .unwrap_errunion_err => try self.airErrUnionErr(inst),
            .unwrap_errunion_payload => try self.airErrUnionPayload(inst),
            .wrap_errunion_err => try self.airWrapErrUnionErr(inst),
            .wrap_errunion_payload => try self.airWrapErrUnionPayload(inst),

            .is_null     => try self.airIsNull(inst, .is_null),
            .is_non_null => try self.airIsNull(inst, .is_non_null),
            .is_err      => try self.airIsErr(inst, .is_err),
            .is_non_err  => try self.airIsErr(inst, .is_non_err),

            .optional_payload => try self.airUnwrapOptional(inst),
            .wrap_optional    => try self.airWrapOptional(inst),

            .assembly => try self.airAssembly(inst),

            .call              => try self.airCall(inst, .auto),
            .call_always_tail  => try self.airCall(inst, .always_tail),
            .call_never_tail   => try self.airCall(inst, .never_tail),
            .call_never_inline => try self.airCall(inst, .never_inline),
            // zig fmt: on

            else => |tag| return self.todo("implement AIR tag {s}", .{@tagName(tag)}),
        };

        const result_id = maybe_result_id orelse return;
        try self.inst_results.putNoClobber(self.gpa, inst, result_id);
    }

    fn binOpSimple(self: *DeclGen, ty: Type, lhs_id: IdRef, rhs_id: IdRef, comptime opcode: Opcode) !IdRef {
        const mod = self.module;

        if (ty.isVector(mod)) {
            const child_ty = ty.childType(mod);
            const vector_len = ty.vectorLen(mod);

            var constituents = try self.gpa.alloc(IdRef, vector_len);
            defer self.gpa.free(constituents);

            for (constituents, 0..) |*constituent, i| {
                const lhs_index_id = try self.extractField(child_ty, lhs_id, @intCast(i));
                const rhs_index_id = try self.extractField(child_ty, rhs_id, @intCast(i));
                const result_id = try self.binOpSimple(child_ty, lhs_index_id, rhs_index_id, opcode);
                constituent.* = try self.convertToIndirect(child_ty, result_id);
            }

            return try self.constructArray(ty, constituents);
        }

        const result_id = self.spv.allocId();
        const result_type_id = try self.resolveTypeId(ty);
        try self.func.body.emit(self.spv.gpa, opcode, .{
            .id_result_type = result_type_id,
            .id_result = result_id,
            .operand_1 = lhs_id,
            .operand_2 = rhs_id,
        });
        return result_id;
    }

    fn airBinOpSimple(self: *DeclGen, inst: Air.Inst.Index, comptime opcode: Opcode) !?IdRef {
        if (self.liveness.isUnused(inst)) return null;

        const bin_op = self.air.instructions.items(.data)[inst].bin_op;
        const lhs_id = try self.resolve(bin_op.lhs);
        const rhs_id = try self.resolve(bin_op.rhs);
        const ty = self.typeOf(bin_op.lhs);

        return try self.binOpSimple(ty, lhs_id, rhs_id, opcode);
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

    fn airMinMax(self: *DeclGen, inst: Air.Inst.Index, op: std.math.CompareOperator) !?IdRef {
        if (self.liveness.isUnused(inst)) return null;

        const bin_op = self.air.instructions.items(.data)[inst].bin_op;
        const lhs_id = try self.resolve(bin_op.lhs);
        const rhs_id = try self.resolve(bin_op.rhs);
        const result_ty = self.typeOfIndex(inst);
        const result_ty_ref = try self.resolveType(result_ty, .direct);

        const info = try self.arithmeticTypeInfo(result_ty);
        // TODO: Use fmin for OpenCL
        const cmp_id = try self.cmp(op, Type.bool, result_ty, lhs_id, rhs_id);
        const selection_id = switch (info.class) {
            .float => blk: {
                // cmp uses OpFOrd. When we have 0 [<>] nan this returns false,
                // but we want it to pick lhs. Therefore we also have to check if
                // rhs is nan. We don't need to care about the result when both
                // are nan.
                const rhs_is_nan_id = self.spv.allocId();
                const bool_ty_ref = try self.resolveType(Type.bool, .direct);
                try self.func.body.emit(self.spv.gpa, .OpIsNan, .{
                    .id_result_type = self.typeId(bool_ty_ref),
                    .id_result = rhs_is_nan_id,
                    .x = rhs_id,
                });
                const float_cmp_id = self.spv.allocId();
                try self.func.body.emit(self.spv.gpa, .OpLogicalOr, .{
                    .id_result_type = self.typeId(bool_ty_ref),
                    .id_result = float_cmp_id,
                    .operand_1 = cmp_id,
                    .operand_2 = rhs_is_nan_id,
                });
                break :blk float_cmp_id;
            },
            else => cmp_id,
        };

        const result_id = self.spv.allocId();
        try self.func.body.emit(self.spv.gpa, .OpSelect, .{
            .id_result_type = self.typeId(result_ty_ref),
            .id_result = result_id,
            .condition = selection_id,
            .object_1 = lhs_id,
            .object_2 = rhs_id,
        });
        return result_id;
    }

    /// This function canonicalizes a "strange" integer value:
    /// For unsigned integers, the value is masked so that only the relevant bits can contain
    /// non-zeros.
    /// For signed integers, the value is also sign extended.
    fn normalizeInt(self: *DeclGen, ty_ref: CacheRef, value_id: IdRef, info: ArithmeticTypeInfo) !IdRef {
        assert(info.class != .composite_integer); // TODO
        if (info.bits == info.backing_bits) {
            return value_id;
        }

        switch (info.signedness) {
            .unsigned => {
                const mask_value = if (info.bits == 64) 0xFFFF_FFFF_FFFF_FFFF else (@as(u64, 1) << @as(u6, @intCast(info.bits))) - 1;
                const result_id = self.spv.allocId();
                const mask_id = try self.constInt(ty_ref, mask_value);
                try self.func.body.emit(self.spv.gpa, .OpBitwiseAnd, .{
                    .id_result_type = self.typeId(ty_ref),
                    .id_result = result_id,
                    .operand_1 = value_id,
                    .operand_2 = mask_id,
                });
                return result_id;
            },
            .signed => {
                // Shift left and right so that we can copy the sight bit that way.
                const shift_amt_id = try self.constInt(ty_ref, info.backing_bits - info.bits);
                const left_id = self.spv.allocId();
                try self.func.body.emit(self.spv.gpa, .OpShiftLeftLogical, .{
                    .id_result_type = self.typeId(ty_ref),
                    .id_result = left_id,
                    .base = value_id,
                    .shift = shift_amt_id,
                });
                const right_id = self.spv.allocId();
                try self.func.body.emit(self.spv.gpa, .OpShiftRightArithmetic, .{
                    .id_result_type = self.typeId(ty_ref),
                    .id_result = right_id,
                    .base = left_id,
                    .shift = shift_amt_id,
                });
                return right_id;
            },
        }
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
        const lhs_id = try self.resolve(bin_op.lhs);
        const rhs_id = try self.resolve(bin_op.rhs);

        assert(self.typeOf(bin_op.lhs).eql(ty, self.module));
        assert(self.typeOf(bin_op.rhs).eql(ty, self.module));

        return try self.arithOp(ty, lhs_id, rhs_id, fop, sop, uop, modular);
    }

    fn arithOp(
        self: *DeclGen,
        ty: Type,
        lhs_id_: IdRef,
        rhs_id_: IdRef,
        comptime fop: Opcode,
        comptime sop: Opcode,
        comptime uop: Opcode,
        /// true if this operation holds under modular arithmetic.
        comptime modular: bool,
    ) !IdRef {
        var rhs_id = rhs_id_;
        var lhs_id = lhs_id_;

        const mod = self.module;
        const result_ty_ref = try self.resolveType(ty, .direct);

        if (ty.isVector(mod)) {
            const child_ty = ty.childType(mod);
            const vector_len = ty.vectorLen(mod);
            var constituents = try self.gpa.alloc(IdRef, vector_len);
            defer self.gpa.free(constituents);

            for (constituents, 0..) |*constituent, i| {
                const lhs_index_id = try self.extractField(child_ty, lhs_id, @intCast(i));
                const rhs_index_id = try self.extractField(child_ty, rhs_id, @intCast(i));
                constituent.* = try self.arithOp(child_ty, lhs_index_id, rhs_index_id, fop, sop, uop, modular);
            }

            return self.constructArray(ty, constituents);
        }

        // Binary operations are generally applicable to both scalar and vector operations
        // in SPIR-V, but int and float versions of operations require different opcodes.
        const info = try self.arithmeticTypeInfo(ty);

        const opcode_index: usize = switch (info.class) {
            .composite_integer => {
                return self.todo("binary operations for composite integers", .{});
            },
            .strange_integer => blk: {
                if (!modular) {
                    lhs_id = try self.normalizeInt(result_ty_ref, lhs_id, info);
                    rhs_id = try self.normalizeInt(result_ty_ref, rhs_id, info);
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

    fn airAddSubOverflow(
        self: *DeclGen,
        inst: Air.Inst.Index,
        comptime add: Opcode,
        comptime ucmp: Opcode,
        comptime scmp: Opcode,
    ) !?IdRef {
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
        try self.func.body.emit(self.spv.gpa, add, .{
            .id_result_type = operand_ty_id,
            .id_result = value_id,
            .operand_1 = lhs,
            .operand_2 = rhs,
        });

        const overflowed_id = switch (info.signedness) {
            .unsigned => blk: {
                // Overflow happened if the result is smaller than either of the operands. It doesn't matter which.
                // For subtraction the conditions need to be swapped.
                const overflowed_id = self.spv.allocId();
                try self.func.body.emit(self.spv.gpa, ucmp, .{
                    .id_result_type = self.typeId(bool_ty_ref),
                    .id_result = overflowed_id,
                    .operand_1 = value_id,
                    .operand_2 = lhs,
                });
                break :blk overflowed_id;
            },
            .signed => blk: {
                // lhs - rhs
                // For addition, overflow happened if:
                // - rhs is negative and value > lhs
                // - rhs is positive and value < lhs
                // This can be shortened to:
                //   (rhs < 0 and value > lhs) or (rhs >= 0 and value <= lhs)
                // = (rhs < 0) == (value > lhs)
                // = (rhs < 0) == (lhs < value)
                // Note that signed overflow is also wrapping in spir-v.
                // For subtraction, overflow happened if:
                // - rhs is negative and value < lhs
                // - rhs is positive and value > lhs
                // This can be shortened to:
                //   (rhs < 0 and value < lhs) or (rhs >= 0 and value >= lhs)
                // = (rhs < 0) == (value < lhs)
                // = (rhs < 0) == (lhs > value)

                const rhs_lt_zero_id = self.spv.allocId();
                const zero_id = try self.constInt(operand_ty_ref, 0);
                try self.func.body.emit(self.spv.gpa, .OpSLessThan, .{
                    .id_result_type = self.typeId(bool_ty_ref),
                    .id_result = rhs_lt_zero_id,
                    .operand_1 = rhs,
                    .operand_2 = zero_id,
                });

                const value_gt_lhs_id = self.spv.allocId();
                try self.func.body.emit(self.spv.gpa, scmp, .{
                    .id_result_type = self.typeId(bool_ty_ref),
                    .id_result = value_gt_lhs_id,
                    .operand_1 = lhs,
                    .operand_2 = value_id,
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
        return try self.constructStruct(
            result_ty,
            &.{ operand_ty, ov_ty },
            &.{ value_id, ov_id },
        );
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

    fn indicesToIds(self: *DeclGen, indices: []const u32) ![]IdRef {
        const index_ty_ref = try self.intType(.unsigned, 32);
        const ids = try self.gpa.alloc(IdRef, indices.len);
        errdefer self.gpa.free(ids);
        for (indices, ids) |index, *id| {
            id.* = try self.constInt(index_ty_ref, index);
        }

        return ids;
    }

    fn accessChainId(
        self: *DeclGen,
        result_ty_ref: CacheRef,
        base: IdRef,
        indices: []const IdRef,
    ) !IdRef {
        const result_id = self.spv.allocId();
        try self.func.body.emit(self.spv.gpa, .OpInBoundsAccessChain, .{
            .id_result_type = self.typeId(result_ty_ref),
            .id_result = result_id,
            .base = base,
            .indexes = indices,
        });
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
        indices: []const u32,
    ) !IdRef {
        const ids = try self.indicesToIds(indices);
        defer self.gpa.free(ids);
        return try self.accessChainId(result_ty_ref, base, ids);
    }

    fn ptrAccessChain(
        self: *DeclGen,
        result_ty_ref: CacheRef,
        base: IdRef,
        element: IdRef,
        indices: []const u32,
    ) !IdRef {
        const ids = try self.indicesToIds(indices);
        defer self.gpa.free(ids);

        const result_id = self.spv.allocId();
        try self.func.body.emit(self.spv.gpa, .OpInBoundsPtrAccessChain, .{
            .id_result_type = self.typeId(result_ty_ref),
            .id_result = result_id,
            .base = base,
            .element = element,
            .indexes = ids,
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
                return try self.accessChainId(result_ty_ref, ptr_id, &.{offset_id});
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
        op: std.math.CompareOperator,
        result_ty: Type,
        ty: Type,
        lhs_id: IdRef,
        rhs_id: IdRef,
    ) !IdRef {
        const mod = self.module;
        var cmp_lhs_id = lhs_id;
        var cmp_rhs_id = rhs_id;
        const bool_ty_ref = try self.resolveType(Type.bool, .direct);
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
            .Optional => {
                const payload_ty = ty.optionalChild(mod);
                if (ty.optionalReprIsPayload(mod)) {
                    assert(payload_ty.hasRuntimeBitsIgnoreComptime(mod));
                    assert(!payload_ty.isSlice(mod));
                    return self.cmp(op, Type.bool, payload_ty, lhs_id, rhs_id);
                }

                const lhs_valid_id = if (payload_ty.hasRuntimeBitsIgnoreComptime(mod))
                    try self.extractField(Type.bool, lhs_id, 1)
                else
                    try self.convertToDirect(Type.bool, lhs_id);

                const rhs_valid_id = if (payload_ty.hasRuntimeBitsIgnoreComptime(mod))
                    try self.extractField(Type.bool, rhs_id, 1)
                else
                    try self.convertToDirect(Type.bool, rhs_id);

                const valid_cmp_id = try self.cmp(op, Type.bool, Type.bool, lhs_valid_id, rhs_valid_id);
                if (!payload_ty.hasRuntimeBitsIgnoreComptime(mod)) {
                    return valid_cmp_id;
                }

                // TODO: Should we short circuit here? It shouldn't affect correctness, but
                // perhaps it will generate more efficient code.

                const lhs_pl_id = try self.extractField(payload_ty, lhs_id, 0);
                const rhs_pl_id = try self.extractField(payload_ty, rhs_id, 0);

                const pl_cmp_id = try self.cmp(op, Type.bool, payload_ty, lhs_pl_id, rhs_pl_id);

                // op == .eq  => lhs_valid == rhs_valid && lhs_pl == rhs_pl
                // op == .neq => lhs_valid != rhs_valid || lhs_pl != rhs_pl

                const result_id = self.spv.allocId();
                const args = .{
                    .id_result_type = self.typeId(bool_ty_ref),
                    .id_result = result_id,
                    .operand_1 = valid_cmp_id,
                    .operand_2 = pl_cmp_id,
                };
                switch (op) {
                    .eq => try self.func.body.emit(self.spv.gpa, .OpLogicalAnd, args),
                    .neq => try self.func.body.emit(self.spv.gpa, .OpLogicalOr, args),
                    else => unreachable,
                }
                return result_id;
            },
            .Vector => {
                const child_ty = ty.childType(mod);
                const vector_len = ty.vectorLen(mod);

                var constituents = try self.gpa.alloc(IdRef, vector_len);
                defer self.gpa.free(constituents);

                for (constituents, 0..) |*constituent, i| {
                    const lhs_index_id = try self.extractField(child_ty, cmp_lhs_id, @intCast(i));
                    const rhs_index_id = try self.extractField(child_ty, cmp_rhs_id, @intCast(i));
                    const result_id = try self.cmp(op, Type.bool, child_ty, lhs_index_id, rhs_index_id);
                    constituent.* = try self.convertToIndirect(Type.bool, result_id);
                }

                return try self.constructArray(result_ty, constituents);
            },
            else => unreachable,
        };

        const opcode: Opcode = opcode: {
            const info = try self.arithmeticTypeInfo(op_ty);
            const signedness = switch (info.class) {
                .composite_integer => {
                    return self.todo("binary operations for composite integers", .{});
                },
                .float => break :opcode switch (op) {
                    .eq => .OpFOrdEqual,
                    .neq => .OpFUnordNotEqual,
                    .lt => .OpFOrdLessThan,
                    .lte => .OpFOrdLessThanEqual,
                    .gt => .OpFOrdGreaterThan,
                    .gte => .OpFOrdGreaterThanEqual,
                },
                .bool => break :opcode switch (op) {
                    .eq => .OpLogicalEqual,
                    .neq => .OpLogicalNotEqual,
                    else => unreachable,
                },
                .strange_integer => sign: {
                    const op_ty_ref = try self.resolveType(op_ty, .direct);
                    // Mask operands before performing comparison.
                    cmp_lhs_id = try self.normalizeInt(op_ty_ref, cmp_lhs_id, info);
                    cmp_rhs_id = try self.normalizeInt(op_ty_ref, cmp_rhs_id, info);
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
        self.func.body.writeOperand(spec.IdResultType, self.typeId(bool_ty_ref));
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
        const ty = self.typeOf(bin_op.lhs);
        const result_ty = self.typeOfIndex(inst);

        return try self.cmp(op, result_ty, ty, lhs_id, rhs_id);
    }

    fn airVectorCmp(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        if (self.liveness.isUnused(inst)) return null;

        const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
        const vec_cmp = self.air.extraData(Air.VectorCmp, ty_pl.payload).data;
        const lhs_id = try self.resolve(vec_cmp.lhs);
        const rhs_id = try self.resolve(vec_cmp.rhs);
        const op = vec_cmp.compareOperator();
        const ty = self.typeOf(vec_cmp.lhs);
        const result_ty = self.typeOfIndex(inst);

        return try self.cmp(op, result_ty, ty, lhs_id, rhs_id);
    }

    fn bitCast(
        self: *DeclGen,
        dst_ty: Type,
        src_ty: Type,
        src_id: IdRef,
    ) !IdRef {
        const mod = self.module;
        const src_ty_ref = try self.resolveType(src_ty, .direct);
        const dst_ty_ref = try self.resolveType(dst_ty, .direct);
        if (src_ty_ref == dst_ty_ref) {
            return src_id;
        }

        // TODO: Some more cases are missing here
        //   See fn bitCast in llvm.zig

        if (src_ty.zigTypeTag(mod) == .Int and dst_ty.isPtrAtRuntime(mod)) {
            const result_id = self.spv.allocId();
            try self.func.body.emit(self.spv.gpa, .OpConvertUToPtr, .{
                .id_result_type = self.typeId(dst_ty_ref),
                .id_result = result_id,
                .integer_value = src_id,
            });
            return result_id;
        }

        // We can only use OpBitcast for specific conversions: between numerical types, and
        // between pointers. If the resolved spir-v types fall into this category then emit OpBitcast,
        // otherwise use a temporary and perform a pointer cast.
        const src_key = self.spv.cache.lookup(src_ty_ref);
        const dst_key = self.spv.cache.lookup(dst_ty_ref);

        if ((src_key.isNumericalType() and dst_key.isNumericalType()) or (src_key == .ptr_type and dst_key == .ptr_type)) {
            const result_id = self.spv.allocId();
            try self.func.body.emit(self.spv.gpa, .OpBitcast, .{
                .id_result_type = self.typeId(dst_ty_ref),
                .id_result = result_id,
                .operand = src_id,
            });
            return result_id;
        }

        const dst_ptr_ty_ref = try self.ptrType(dst_ty, .Function);

        const tmp_id = try self.alloc(src_ty, .{ .storage_class = .Function });
        try self.store(src_ty, tmp_id, src_id, .{});
        const casted_ptr_id = self.spv.allocId();
        try self.func.body.emit(self.spv.gpa, .OpBitcast, .{
            .id_result_type = self.typeId(dst_ptr_ty_ref),
            .id_result = casted_ptr_id,
            .operand = tmp_id,
        });
        return try self.load(dst_ty, casted_ptr_id, .{});
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
        const src_ty = self.typeOf(ty_op.operand);
        const dst_ty = self.typeOfIndex(inst);
        const src_ty_ref = try self.resolveType(src_ty, .direct);
        const dst_ty_ref = try self.resolveType(dst_ty, .direct);

        const src_info = try self.arithmeticTypeInfo(src_ty);
        const dst_info = try self.arithmeticTypeInfo(dst_ty);

        // While intcast promises that the value already fits, the upper bits of a
        // strange integer may contain garbage. Therefore, mask/sign extend it before.
        const src_id = try self.normalizeInt(src_ty_ref, operand_id, src_info);

        if (src_info.backing_bits == dst_info.backing_bits) {
            return src_id;
        }

        const result_id = self.spv.allocId();
        switch (dst_info.signedness) {
            .signed => try self.func.body.emit(self.spv.gpa, .OpSConvert, .{
                .id_result_type = self.typeId(dst_ty_ref),
                .id_result = result_id,
                .signed_value = src_id,
            }),
            .unsigned => try self.func.body.emit(self.spv.gpa, .OpUConvert, .{
                .id_result_type = self.typeId(dst_ty_ref),
                .id_result = result_id,
                .unsigned_value = src_id,
            }),
        }
        return result_id;
    }

    fn intFromPtr(self: *DeclGen, operand_id: IdRef) !IdRef {
        const result_type_id = try self.resolveTypeId(Type.usize);
        const result_id = self.spv.allocId();
        try self.func.body.emit(self.spv.gpa, .OpConvertPtrToU, .{
            .id_result_type = result_type_id,
            .id_result = result_id,
            .pointer = operand_id,
        });
        return result_id;
    }

    fn airIntFromPtr(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        if (self.liveness.isUnused(inst)) return null;

        const un_op = self.air.instructions.items(.data)[inst].un_op;
        const operand_id = try self.resolve(un_op);
        return try self.intFromPtr(operand_id);
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

    fn airFloatCast(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        if (self.liveness.isUnused(inst)) return null;

        const ty_op = self.air.instructions.items(.data)[inst].ty_op;
        const operand_id = try self.resolve(ty_op.operand);
        const dest_ty = self.typeOfIndex(inst);
        const dest_ty_id = try self.resolveTypeId(dest_ty);

        const result_id = self.spv.allocId();
        try self.func.body.emit(self.spv.gpa, .OpFConvert, .{
            .id_result_type = dest_ty_id,
            .id_result = result_id,
            .float_value = operand_id,
        });
        return result_id;
    }

    fn airNot(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        if (self.liveness.isUnused(inst)) return null;
        const ty_op = self.air.instructions.items(.data)[inst].ty_op;
        const operand_id = try self.resolve(ty_op.operand);
        const result_ty = self.typeOfIndex(inst);
        const result_ty_id = try self.resolveTypeId(result_ty);
        const info = try self.arithmeticTypeInfo(result_ty);

        const result_id = self.spv.allocId();
        switch (info.class) {
            .bool => {
                try self.func.body.emit(self.spv.gpa, .OpLogicalNot, .{
                    .id_result_type = result_ty_id,
                    .id_result = result_id,
                    .operand = operand_id,
                });
            },
            .float => unreachable,
            .composite_integer => unreachable, // TODO
            .strange_integer, .integer => {
                // Note: strange integer bits will be masked before operations that do not hold under modulo.
                try self.func.body.emit(self.spv.gpa, .OpNot, .{
                    .id_result_type = result_ty_id,
                    .id_result = result_id,
                    .operand = operand_id,
                });
            },
        }

        return result_id;
    }

    fn airArrayToSlice(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        if (self.liveness.isUnused(inst)) return null;

        const mod = self.module;
        const ty_op = self.air.instructions.items(.data)[inst].ty_op;
        const array_ptr_ty = self.typeOf(ty_op.operand);
        const array_ty = array_ptr_ty.childType(mod);
        const slice_ty = self.typeOfIndex(inst);
        const elem_ptr_ty = slice_ty.slicePtrFieldType(mod);

        const elem_ptr_ty_ref = try self.resolveType(elem_ptr_ty, .direct);
        const size_ty_ref = try self.sizeType();

        const array_ptr_id = try self.resolve(ty_op.operand);
        const len_id = try self.constInt(size_ty_ref, array_ty.arrayLen(mod));

        const elem_ptr_id = if (!array_ty.hasRuntimeBitsIgnoreComptime(mod))
            // Note: The pointer is something like *opaque{}, so we need to bitcast it to the element type.
            try self.bitCast(elem_ptr_ty, array_ptr_ty, array_ptr_id)
        else
            // Convert the pointer-to-array to a pointer to the first element.
            try self.accessChain(elem_ptr_ty_ref, array_ptr_id, &.{0});

        return try self.constructStruct(
            slice_ty,
            &.{ elem_ptr_ty, Type.usize },
            &.{ elem_ptr_id, len_id },
        );
    }

    fn airSlice(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        if (self.liveness.isUnused(inst)) return null;

        const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
        const bin_op = self.air.extraData(Air.Bin, ty_pl.payload).data;
        const ptr_id = try self.resolve(bin_op.lhs);
        const len_id = try self.resolve(bin_op.rhs);
        const ptr_ty = self.typeOf(bin_op.lhs);
        const slice_ty = self.typeOfIndex(inst);

        // Note: Types should not need to be converted to direct, these types
        // dont need to be converted.
        return try self.constructStruct(
            slice_ty,
            &.{ ptr_ty, Type.usize },
            &.{ ptr_id, len_id },
        );
    }

    fn airAggregateInit(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        if (self.liveness.isUnused(inst)) return null;

        const mod = self.module;
        const ip = &mod.intern_pool;
        const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
        const result_ty = self.typeOfIndex(inst);
        const len: usize = @intCast(result_ty.arrayLen(mod));
        const elements: []const Air.Inst.Ref = @ptrCast(self.air.extra[ty_pl.payload..][0..len]);

        switch (result_ty.zigTypeTag(mod)) {
            .Vector => unreachable, // TODO
            .Struct => {
                if (mod.typeToPackedStruct(result_ty)) |struct_type| {
                    _ = struct_type;
                    unreachable; // TODO
                }

                const types = try self.gpa.alloc(Type, elements.len);
                defer self.gpa.free(types);
                const constituents = try self.gpa.alloc(IdRef, elements.len);
                defer self.gpa.free(constituents);
                var index: usize = 0;

                switch (ip.indexToKey(result_ty.toIntern())) {
                    .anon_struct_type => |tuple| {
                        for (tuple.types.get(ip), elements, 0..) |field_ty, element, i| {
                            if ((try result_ty.structFieldValueComptime(mod, i)) != null) continue;
                            assert(field_ty.toType().hasRuntimeBits(mod));

                            const id = try self.resolve(element);
                            types[index] = field_ty.toType();
                            constituents[index] = try self.convertToIndirect(field_ty.toType(), id);
                            index += 1;
                        }
                    },
                    .struct_type => |struct_type| {
                        var it = struct_type.iterateRuntimeOrder(ip);
                        for (elements, 0..) |element, i| {
                            const field_index = it.next().?;
                            if ((try result_ty.structFieldValueComptime(mod, i)) != null) continue;
                            const field_ty = struct_type.field_types.get(ip)[field_index].toType();
                            assert(field_ty.hasRuntimeBitsIgnoreComptime(mod));

                            const id = try self.resolve(element);
                            types[index] = field_ty;
                            constituents[index] = try self.convertToIndirect(field_ty, id);
                            index += 1;
                        }
                    },
                    else => unreachable,
                }

                return try self.constructStruct(
                    result_ty,
                    types[0..index],
                    constituents[0..index],
                );
            },
            .Array => {
                const array_info = result_ty.arrayInfo(mod);
                const n_elems: usize = @intCast(result_ty.arrayLenIncludingSentinel(mod));
                const elem_ids = try self.gpa.alloc(IdRef, n_elems);
                defer self.gpa.free(elem_ids);

                for (elements, 0..) |element, i| {
                    const id = try self.resolve(element);
                    elem_ids[i] = try self.convertToIndirect(array_info.elem_type, id);
                }

                if (array_info.sentinel) |sentinel_val| {
                    elem_ids[n_elems - 1] = try self.constant(array_info.elem_type, sentinel_val, .indirect);
                }

                return try self.constructArray(result_ty, elem_ids);
            },
            else => unreachable,
        }
    }

    fn sliceOrArrayLen(self: *DeclGen, operand_id: IdRef, ty: Type) !IdRef {
        const mod = self.module;
        switch (ty.ptrSize(mod)) {
            .Slice => return self.extractField(Type.usize, operand_id, 1),
            .One => {
                const array_ty = ty.childType(mod);
                const elem_ty = array_ty.childType(mod);
                const abi_size = elem_ty.abiSize(mod);
                const usize_ty_ref = try self.resolveType(Type.usize, .direct);
                return self.spv.constInt(usize_ty_ref, array_ty.arrayLenIncludingSentinel(mod) * abi_size);
            },
            .Many, .C => unreachable,
        }
    }

    fn sliceOrArrayPtr(self: *DeclGen, operand_id: IdRef, ty: Type) !IdRef {
        const mod = self.module;
        if (ty.isSlice(mod)) {
            const ptr_ty = ty.slicePtrFieldType(mod);
            return self.extractField(ptr_ty, operand_id, 0);
        }
        return operand_id;
    }

    fn airMemcpy(self: *DeclGen, inst: Air.Inst.Index) !void {
        const bin_op = self.air.instructions.items(.data)[inst].bin_op;
        const dest_slice = try self.resolve(bin_op.lhs);
        const src_slice = try self.resolve(bin_op.rhs);
        const dest_ty = self.typeOf(bin_op.lhs);
        const src_ty = self.typeOf(bin_op.rhs);
        const dest_ptr = try self.sliceOrArrayPtr(dest_slice, dest_ty);
        const src_ptr = try self.sliceOrArrayPtr(src_slice, src_ty);
        const len = try self.sliceOrArrayLen(dest_slice, dest_ty);
        try self.func.body.emit(self.spv.gpa, .OpCopyMemorySized, .{
            .target = dest_ptr,
            .source = src_ptr,
            .size = len,
        });
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
        const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
        const bin_op = self.air.extraData(Air.Bin, ty_pl.payload).data;
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
        return try self.load(slice_ty.childType(mod), elem_ptr, .{ .is_volatile = slice_ty.isVolatilePtr(mod) });
    }

    fn ptrElemPtr(self: *DeclGen, ptr_ty: Type, ptr_id: IdRef, index_id: IdRef) !IdRef {
        const mod = self.module;
        // Construct new pointer type for the resulting pointer
        const elem_ty = ptr_ty.elemType2(mod); // use elemType() so that we get T for *[N]T.
        const elem_ptr_ty_ref = try self.ptrType(elem_ty, spvStorageClass(ptr_ty.ptrAddressSpace(mod)));
        if (ptr_ty.isSinglePointer(mod)) {
            // Pointer-to-array. In this case, the resulting pointer is not of the same type
            // as the ptr_ty (we want a *T, not a *[N]T), and hence we need to use accessChain.
            return try self.accessChainId(elem_ptr_ty_ref, ptr_id, &.{index_id});
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
        const src_ptr_ty = self.typeOf(bin_op.lhs);
        const elem_ty = src_ptr_ty.childType(mod);
        const ptr_id = try self.resolve(bin_op.lhs);

        if (!elem_ty.hasRuntimeBitsIgnoreComptime(mod)) {
            const dst_ptr_ty = self.typeOfIndex(inst);
            return try self.bitCast(dst_ptr_ty, src_ptr_ty, ptr_id);
        }

        const index_id = try self.resolve(bin_op.rhs);
        return try self.ptrElemPtr(src_ptr_ty, ptr_id, index_id);
    }

    fn airArrayElemVal(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        if (self.liveness.isUnused(inst)) return null;

        const mod = self.module;
        const bin_op = self.air.instructions.items(.data)[inst].bin_op;
        const array_ty = self.typeOf(bin_op.lhs);
        const elem_ty = array_ty.childType(mod);
        const array_id = try self.resolve(bin_op.lhs);
        const index_id = try self.resolve(bin_op.rhs);

        // SPIR-V doesn't have an array indexing function for some damn reason.
        // For now, just generate a temporary and use that.
        // TODO: This backend probably also should use isByRef from llvm...

        const elem_ptr_ty_ref = try self.ptrType(elem_ty, .Function);

        const tmp_id = try self.alloc(array_ty, .{ .storage_class = .Function });
        try self.store(array_ty, tmp_id, array_id, .{});
        const elem_ptr_id = try self.accessChainId(elem_ptr_ty_ref, tmp_id, &.{index_id});
        return try self.load(elem_ty, elem_ptr_id, .{});
    }

    fn airPtrElemVal(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        if (self.liveness.isUnused(inst)) return null;

        const mod = self.module;
        const bin_op = self.air.instructions.items(.data)[inst].bin_op;
        const ptr_ty = self.typeOf(bin_op.lhs);
        const elem_ty = self.typeOfIndex(inst);
        const ptr_id = try self.resolve(bin_op.lhs);
        const index_id = try self.resolve(bin_op.rhs);
        const elem_ptr_id = try self.ptrElemPtr(ptr_ty, ptr_id, index_id);
        return try self.load(elem_ty, elem_ptr_id, .{ .is_volatile = ptr_ty.isVolatilePtr(mod) });
    }

    fn airSetUnionTag(self: *DeclGen, inst: Air.Inst.Index) !void {
        const mod = self.module;
        const bin_op = self.air.instructions.items(.data)[inst].bin_op;
        const un_ptr_ty = self.typeOf(bin_op.lhs);
        const un_ty = un_ptr_ty.childType(mod);
        const layout = self.unionLayout(un_ty);

        if (layout.tag_size == 0) return;

        const tag_ty = un_ty.unionTagTypeSafety(mod).?;
        const tag_ptr_ty_ref = try self.ptrType(tag_ty, spvStorageClass(un_ptr_ty.ptrAddressSpace(mod)));

        const union_ptr_id = try self.resolve(bin_op.lhs);
        const new_tag_id = try self.resolve(bin_op.rhs);

        if (!layout.has_payload) {
            try self.store(tag_ty, union_ptr_id, new_tag_id, .{ .is_volatile = un_ptr_ty.isVolatilePtr(mod) });
        } else {
            const ptr_id = try self.accessChain(tag_ptr_ty_ref, union_ptr_id, &.{layout.tag_index});
            try self.store(tag_ty, ptr_id, new_tag_id, .{ .is_volatile = un_ptr_ty.isVolatilePtr(mod) });
        }
    }

    fn airGetUnionTag(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        if (self.liveness.isUnused(inst)) return null;

        const ty_op = self.air.instructions.items(.data)[inst].ty_op;
        const un_ty = self.typeOf(ty_op.operand);

        const mod = self.module;
        const layout = self.unionLayout(un_ty);
        if (layout.tag_size == 0) return null;

        const union_handle = try self.resolve(ty_op.operand);
        if (!layout.has_payload) return union_handle;

        const tag_ty = un_ty.unionTagTypeSafety(mod).?;
        return try self.extractField(tag_ty, union_handle, layout.tag_index);
    }

    fn unionInit(
        self: *DeclGen,
        ty: Type,
        active_field: u32,
        payload: ?IdRef,
    ) !IdRef {
        // To initialize a union, generate a temporary variable with the
        // union type, then get the field pointer and pointer-cast it to the
        // right type to store it. Finally load the entire union.

        const mod = self.module;
        const ip = &mod.intern_pool;
        const union_ty = mod.typeToUnion(ty).?;

        if (union_ty.getLayout(ip) == .Packed) {
            unreachable; // TODO
        }

        const maybe_tag_ty = ty.unionTagTypeSafety(mod);
        const layout = self.unionLayout(ty);

        const tag_int = if (layout.tag_size != 0) blk: {
            const tag_ty = maybe_tag_ty.?;
            const union_field_name = union_ty.field_names.get(ip)[active_field];
            const enum_field_index = tag_ty.enumFieldIndex(union_field_name, mod).?;
            const tag_val = try mod.enumValueFieldIndex(tag_ty, enum_field_index);
            const tag_int_val = try tag_val.intFromEnum(tag_ty, mod);
            break :blk tag_int_val.toUnsignedInt(mod);
        } else 0;

        if (!layout.has_payload) {
            const tag_ty_ref = try self.resolveType(maybe_tag_ty.?, .direct);
            return try self.constInt(tag_ty_ref, tag_int);
        }

        const tmp_id = try self.alloc(ty, .{ .storage_class = .Function });

        if (layout.tag_size != 0) {
            const tag_ty_ref = try self.resolveType(maybe_tag_ty.?, .direct);
            const tag_ptr_ty_ref = try self.ptrType(maybe_tag_ty.?, .Function);
            const ptr_id = try self.accessChain(tag_ptr_ty_ref, tmp_id, &.{@as(u32, @intCast(layout.tag_index))});
            const tag_id = try self.constInt(tag_ty_ref, tag_int);
            try self.store(maybe_tag_ty.?, ptr_id, tag_id, .{});
        }

        const payload_ty = union_ty.field_types.get(ip)[active_field].toType();
        if (payload_ty.hasRuntimeBitsIgnoreComptime(mod)) {
            const pl_ptr_ty_ref = try self.ptrType(layout.payload_ty, .Function);
            const pl_ptr_id = try self.accessChain(pl_ptr_ty_ref, tmp_id, &.{layout.payload_index});
            const active_pl_ptr_ty_ref = try self.ptrType(payload_ty, .Function);
            const active_pl_ptr_id = self.spv.allocId();
            try self.func.body.emit(self.spv.gpa, .OpBitcast, .{
                .id_result_type = self.typeId(active_pl_ptr_ty_ref),
                .id_result = active_pl_ptr_id,
                .operand = pl_ptr_id,
            });

            try self.store(payload_ty, active_pl_ptr_id, payload.?, .{});
        } else {
            assert(payload == null);
        }

        // Just leave the padding fields uninitialized...
        // TODO: Or should we initialize them with undef explicitly?

        return try self.load(ty, tmp_id, .{});
    }

    fn airUnionInit(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        if (self.liveness.isUnused(inst)) return null;

        const mod = self.module;
        const ip = &mod.intern_pool;
        const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
        const extra = self.air.extraData(Air.UnionInit, ty_pl.payload).data;
        const ty = self.typeOfIndex(inst);

        const union_obj = mod.typeToUnion(ty).?;
        const field_ty = union_obj.field_types.get(ip)[extra.field_index].toType();
        const payload = if (field_ty.hasRuntimeBitsIgnoreComptime(mod))
            try self.resolve(extra.init)
        else
            null;
        return try self.unionInit(ty, extra.field_index, payload);
    }

    fn airStructFieldVal(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        if (self.liveness.isUnused(inst)) return null;

        const mod = self.module;
        const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
        const struct_field = self.air.extraData(Air.StructField, ty_pl.payload).data;

        const object_ty = self.typeOf(struct_field.struct_operand);
        const object_id = try self.resolve(struct_field.struct_operand);
        const field_index = struct_field.field_index;
        const field_ty = object_ty.structFieldType(field_index, mod);

        if (!field_ty.hasRuntimeBitsIgnoreComptime(mod)) return null;

        switch (object_ty.zigTypeTag(mod)) {
            .Struct => switch (object_ty.containerLayout(mod)) {
                .Packed => unreachable, // TODO
                else => return try self.extractField(field_ty, object_id, field_index),
            },
            .Union => switch (object_ty.containerLayout(mod)) {
                .Packed => unreachable, // TODO
                else => {
                    // Store, ptr-elem-ptr, pointer-cast, load
                    const layout = self.unionLayout(object_ty);
                    assert(layout.has_payload);

                    const tmp_id = try self.alloc(object_ty, .{ .storage_class = .Function });
                    try self.store(object_ty, tmp_id, object_id, .{});

                    const pl_ptr_ty_ref = try self.ptrType(layout.payload_ty, .Function);
                    const pl_ptr_id = try self.accessChain(pl_ptr_ty_ref, tmp_id, &.{layout.payload_index});

                    const active_pl_ptr_ty_ref = try self.ptrType(field_ty, .Function);
                    const active_pl_ptr_id = self.spv.allocId();
                    try self.func.body.emit(self.spv.gpa, .OpBitcast, .{
                        .id_result_type = self.typeId(active_pl_ptr_ty_ref),
                        .id_result = active_pl_ptr_id,
                        .operand = pl_ptr_id,
                    });
                    return try self.load(field_ty, active_pl_ptr_id, .{});
                },
            },
            else => unreachable,
        }
    }

    fn airFieldParentPtr(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        const mod = self.module;
        const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
        const extra = self.air.extraData(Air.FieldParentPtr, ty_pl.payload).data;

        const parent_ty = self.air.getRefType(ty_pl.ty).childType(mod);
        const res_ty = try self.resolveType(self.air.getRefType(ty_pl.ty), .indirect);
        const usize_ty = Type.usize;
        const usize_ty_ref = try self.resolveType(usize_ty, .direct);

        const field_ptr = try self.resolve(extra.field_ptr);
        const field_ptr_int = try self.intFromPtr(field_ptr);
        const field_offset = parent_ty.structFieldOffset(extra.field_index, mod);

        const base_ptr_int = base_ptr_int: {
            if (field_offset == 0) break :base_ptr_int field_ptr_int;

            const field_offset_id = try self.constInt(usize_ty_ref, field_offset);
            break :base_ptr_int try self.binOpSimple(usize_ty, field_ptr_int, field_offset_id, .OpISub);
        };

        const base_ptr = self.spv.allocId();
        try self.func.body.emit(self.spv.gpa, .OpConvertUToPtr, .{
            .id_result_type = self.spv.resultId(res_ty),
            .id_result = base_ptr,
            .integer_value = base_ptr_int,
        });

        return base_ptr;
    }

    fn structFieldPtr(
        self: *DeclGen,
        result_ptr_ty: Type,
        object_ptr_ty: Type,
        object_ptr: IdRef,
        field_index: u32,
    ) !IdRef {
        const result_ty_ref = try self.resolveType(result_ptr_ty, .direct);

        const mod = self.module;
        const object_ty = object_ptr_ty.childType(mod);
        switch (object_ty.zigTypeTag(mod)) {
            .Struct => switch (object_ty.containerLayout(mod)) {
                .Packed => unreachable, // TODO
                else => {
                    return try self.accessChain(result_ty_ref, object_ptr, &.{field_index});
                },
            },
            .Union => switch (object_ty.containerLayout(mod)) {
                .Packed => unreachable, // TODO
                else => {
                    const layout = self.unionLayout(object_ty);
                    if (!layout.has_payload) {
                        // Asked to get a pointer to a zero-sized field. Just lower this
                        // to undefined, there is no reason to make it be a valid pointer.
                        return try self.spv.constUndef(result_ty_ref);
                    }

                    const storage_class = spvStorageClass(object_ptr_ty.ptrAddressSpace(mod));
                    const pl_ptr_ty_ref = try self.ptrType(layout.payload_ty, storage_class);
                    const pl_ptr_id = try self.accessChain(pl_ptr_ty_ref, object_ptr, &.{layout.payload_index});

                    const active_pl_ptr_id = self.spv.allocId();
                    try self.func.body.emit(self.spv.gpa, .OpBitcast, .{
                        .id_result_type = self.typeId(result_ty_ref),
                        .id_result = active_pl_ptr_id,
                        .operand = pl_ptr_id,
                    });
                    return active_pl_ptr_id;
                },
            },
            else => unreachable,
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

    const AllocOptions = struct {
        initializer: ?IdRef = null,
        /// The final storage class of the pointer. This may be either `.Generic` or `.Function`.
        /// In either case, the local is allocated in the `.Function` storage class, and optionally
        /// cast back to `.Generic`.
        storage_class: StorageClass = .Generic,
    };

    // Allocate a function-local variable, with possible initializer.
    // This function returns a pointer to a variable of type `ty_ref`,
    // which is in the Generic address space. The variable is actually
    // placed in the Function address space.
    fn alloc(
        self: *DeclGen,
        ty: Type,
        options: AllocOptions,
    ) !IdRef {
        const ptr_fn_ty_ref = try self.ptrType(ty, .Function);

        // SPIR-V requires that OpVariable declarations for locals go into the first block, so we are just going to
        // directly generate them into func.prologue instead of the body.
        const var_id = self.spv.allocId();
        try self.func.prologue.emit(self.spv.gpa, .OpVariable, .{
            .id_result_type = self.typeId(ptr_fn_ty_ref),
            .id_result = var_id,
            .storage_class = .Function,
            .initializer = options.initializer,
        });

        switch (options.storage_class) {
            .Generic => {
                const ptr_gn_ty_ref = try self.ptrType(ty, .Generic);
                // Convert to a generic pointer
                const result_id = self.spv.allocId();
                try self.func.body.emit(self.spv.gpa, .OpPtrCastToGeneric, .{
                    .id_result_type = self.typeId(ptr_gn_ty_ref),
                    .id_result = result_id,
                    .pointer = var_id,
                });
                return result_id;
            },
            .Function => return var_id,
            else => unreachable,
        }
    }

    fn airAlloc(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        if (self.liveness.isUnused(inst)) return null;
        const mod = self.module;
        const ptr_ty = self.typeOfIndex(inst);
        assert(ptr_ty.ptrAddressSpace(mod) == .generic);
        const child_ty = ptr_ty.childType(mod);
        return try self.alloc(child_ty, .{});
    }

    fn airArg(self: *DeclGen) IdRef {
        defer self.next_arg_index += 1;
        return self.args.items[self.next_arg_index];
    }

    fn airBlock(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        // In AIR, a block doesn't really define an entry point like a block, but
        // more like a scope that breaks can jump out of and "return" a value from.
        // This cannot be directly modelled in SPIR-V, so in a block instruction,
        // we're going to split up the current block by first generating the code
        // of the block, then a label, and then generate the rest of the current
        // ir.Block in a different SPIR-V block.

        const mod = self.module;
        const ty = self.typeOfIndex(inst);
        const inst_datas = self.air.instructions.items(.data);
        const extra = self.air.extraData(Air.Block, inst_datas[inst].ty_pl.payload);
        const body = self.air.extra[extra.end..][0..extra.data.body_len];
        const have_block_result = ty.isFnOrHasRuntimeBitsIgnoreComptime(mod);

        // 4 chosen as arbitrary initial capacity.
        var block = Block{
            // Label id is lazily allocated if needed.
            .label_id = null,
            .incoming_blocks = try std.ArrayListUnmanaged(IncomingBlock).initCapacity(self.gpa, 4),
        };
        defer block.incoming_blocks.deinit(self.gpa);

        try self.blocks.putNoClobber(self.gpa, inst, &block);
        defer assert(self.blocks.remove(inst));

        try self.genBody(body);

        // Only begin a new block if there were actually any breaks towards it.
        if (block.label_id) |label_id| {
            try self.beginSpvBlock(label_id);
        }

        if (!have_block_result)
            return null;

        assert(block.label_id != null);
        const result_id = self.spv.allocId();
        const result_type_id = try self.resolveTypeId(ty);

        try self.func.body.emitRaw(self.spv.gpa, .OpPhi, 2 + @as(u16, @intCast(block.incoming_blocks.items.len * 2))); // result type + result + variable/parent...
        self.func.body.writeOperand(spec.IdResultType, result_type_id);
        self.func.body.writeOperand(spec.IdRef, result_id);

        for (block.incoming_blocks.items) |incoming| {
            self.func.body.writeOperand(spec.PairIdRefIdRef, .{ incoming.break_value_id, incoming.src_label_id });
        }

        return result_id;
    }

    fn airBr(self: *DeclGen, inst: Air.Inst.Index) !void {
        const br = self.air.instructions.items(.data)[inst].br;
        const operand_ty = self.typeOf(br.operand);
        const block = self.blocks.get(br.block_inst).?;

        const mod = self.module;
        if (operand_ty.isFnOrHasRuntimeBitsIgnoreComptime(mod)) {
            const operand_id = try self.resolve(br.operand);
            // current_block_label_id should not be undefined here, lest there is a br or br_void in the function's body.
            try block.incoming_blocks.append(self.gpa, .{
                .src_label_id = self.current_block_label_id,
                .break_value_id = operand_id,
            });
        }

        if (block.label_id == null) {
            block.label_id = self.spv.allocId();
        }

        try self.func.body.emit(self.spv.gpa, .OpBranch, .{ .target_label = block.label_id.? });
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

    fn airLoad(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        const mod = self.module;
        const ty_op = self.air.instructions.items(.data)[inst].ty_op;
        const ptr_ty = self.typeOf(ty_op.operand);
        const elem_ty = self.typeOfIndex(inst);
        const operand = try self.resolve(ty_op.operand);
        if (!ptr_ty.isVolatilePtr(mod) and self.liveness.isUnused(inst)) return null;

        return try self.load(elem_ty, operand, .{ .is_volatile = ptr_ty.isVolatilePtr(mod) });
    }

    fn airStore(self: *DeclGen, inst: Air.Inst.Index) !void {
        const bin_op = self.air.instructions.items(.data)[inst].bin_op;
        const ptr_ty = self.typeOf(bin_op.lhs);
        const elem_ty = ptr_ty.childType(self.module);
        const ptr = try self.resolve(bin_op.lhs);
        const value = try self.resolve(bin_op.rhs);

        try self.store(elem_ty, ptr, value, .{ .is_volatile = ptr_ty.isVolatilePtr(self.module) });
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
        const ret_ty = self.typeOf(operand);
        const mod = self.module;
        if (!ret_ty.hasRuntimeBitsIgnoreComptime(mod)) {
            const decl = mod.declPtr(self.decl_index);
            const fn_info = mod.typeToFunc(decl.ty).?;
            if (fn_info.return_type.toType().isError(mod)) {
                // Functions with an empty error set are emitted with an error code
                // return type and return zero so they can be function pointers coerced
                // to functions that return anyerror.
                const err_ty_ref = try self.resolveType(Type.anyerror, .direct);
                const no_err_id = try self.constInt(err_ty_ref, 0);
                return try self.func.body.emit(self.spv.gpa, .OpReturnValue, .{ .value = no_err_id });
            } else {
                return try self.func.body.emit(self.spv.gpa, .OpReturn, {});
            }
        }

        const operand_id = try self.resolve(operand);
        try self.func.body.emit(self.spv.gpa, .OpReturnValue, .{ .value = operand_id });
    }

    fn airRetLoad(self: *DeclGen, inst: Air.Inst.Index) !void {
        const mod = self.module;
        const un_op = self.air.instructions.items(.data)[inst].un_op;
        const ptr_ty = self.typeOf(un_op);
        const ret_ty = ptr_ty.childType(mod);

        if (!ret_ty.hasRuntimeBitsIgnoreComptime(mod)) {
            const decl = mod.declPtr(self.decl_index);
            const fn_info = mod.typeToFunc(decl.ty).?;
            if (fn_info.return_type.toType().isError(mod)) {
                // Functions with an empty error set are emitted with an error code
                // return type and return zero so they can be function pointers coerced
                // to functions that return anyerror.
                const err_ty_ref = try self.resolveType(Type.anyerror, .direct);
                const no_err_id = try self.constInt(err_ty_ref, 0);
                return try self.func.body.emit(self.spv.gpa, .OpReturnValue, .{ .value = no_err_id });
            } else {
                return try self.func.body.emit(self.spv.gpa, .OpReturn, {});
            }
        }

        const ptr = try self.resolve(un_op);
        const value = try self.load(ret_ty, ptr, .{ .is_volatile = ptr_ty.isVolatilePtr(mod) });
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

            const zero_id = try self.constInt(err_ty_ref, 0);
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

    fn airErrUnionPayload(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        if (self.liveness.isUnused(inst)) return null;

        const ty_op = self.air.instructions.items(.data)[inst].ty_op;
        const operand_id = try self.resolve(ty_op.operand);
        const payload_ty = self.typeOfIndex(inst);
        const eu_layout = self.errorUnionLayout(payload_ty);

        if (!eu_layout.payload_has_bits) {
            return null; // No error possible.
        }

        return try self.extractField(payload_ty, operand_id, eu_layout.payloadFieldIndex());
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

        var members: [2]IdRef = undefined;
        members[eu_layout.errorFieldIndex()] = operand_id;
        members[eu_layout.payloadFieldIndex()] = try self.spv.constUndef(payload_ty_ref);

        var types: [2]Type = undefined;
        types[eu_layout.errorFieldIndex()] = Type.anyerror;
        types[eu_layout.payloadFieldIndex()] = payload_ty;

        return try self.constructStruct(err_union_ty, &types, &members);
    }

    fn airWrapErrUnionPayload(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        if (self.liveness.isUnused(inst)) return null;

        const ty_op = self.air.instructions.items(.data)[inst].ty_op;
        const err_union_ty = self.typeOfIndex(inst);
        const operand_id = try self.resolve(ty_op.operand);
        const payload_ty = self.typeOf(ty_op.operand);
        const err_ty_ref = try self.resolveType(Type.anyerror, .direct);
        const eu_layout = self.errorUnionLayout(payload_ty);

        if (!eu_layout.payload_has_bits) {
            return try self.constInt(err_ty_ref, 0);
        }

        var members: [2]IdRef = undefined;
        members[eu_layout.errorFieldIndex()] = try self.constInt(err_ty_ref, 0);
        members[eu_layout.payloadFieldIndex()] = try self.convertToIndirect(payload_ty, operand_id);

        var types: [2]Type = undefined;
        types[eu_layout.errorFieldIndex()] = Type.anyerror;
        types[eu_layout.payloadFieldIndex()] = payload_ty;

        return try self.constructStruct(err_union_ty, &types, &members);
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
                try self.extractField(ptr_ty, operand_id, 0)
            else
                operand_id;

            const payload_ty_ref = try self.resolveType(ptr_ty, .direct);
            const null_id = try self.spv.constNull(payload_ty_ref);
            const op: std.math.CompareOperator = switch (pred) {
                .is_null => .eq,
                .is_non_null => .neq,
            };
            return try self.cmp(op, Type.bool, ptr_ty, ptr_id, null_id);
        }

        const is_non_null_id = if (payload_ty.hasRuntimeBitsIgnoreComptime(mod))
            try self.extractField(Type.bool, operand_id, 1)
        else
            // Optional representation is bool indicating whether the optional is set
            // Optionals with no payload are represented as an (indirect) bool, so convert
            // it back to the direct bool here.
            try self.convertToDirect(Type.bool, operand_id);

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

    fn airIsErr(self: *DeclGen, inst: Air.Inst.Index, pred: enum { is_err, is_non_err }) !?IdRef {
        if (self.liveness.isUnused(inst)) return null;

        const mod = self.module;
        const un_op = self.air.instructions.items(.data)[inst].un_op;
        const operand_id = try self.resolve(un_op);
        const err_union_ty = self.typeOf(un_op);

        if (err_union_ty.errorUnionSet(mod).errorSetIsEmpty(mod)) {
            return try self.constBool(pred == .is_non_err, .direct);
        }

        const payload_ty = err_union_ty.errorUnionPayload(mod);
        const eu_layout = self.errorUnionLayout(payload_ty);
        const bool_ty_ref = try self.resolveType(Type.bool, .direct);
        const err_ty_ref = try self.resolveType(Type.anyerror, .direct);

        const error_id = if (!eu_layout.payload_has_bits)
            operand_id
        else
            try self.extractField(Type.anyerror, operand_id, eu_layout.errorFieldIndex());

        const result_id = self.spv.allocId();
        const operands = .{
            .id_result_type = self.typeId(bool_ty_ref),
            .id_result = result_id,
            .operand_1 = error_id,
            .operand_2 = try self.constInt(err_ty_ref, 0),
        };
        switch (pred) {
            .is_err => try self.func.body.emit(self.spv.gpa, .OpINotEqual, operands),
            .is_non_err => try self.func.body.emit(self.spv.gpa, .OpIEqual, operands),
        }
        return result_id;
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
            return try self.constBool(true, .indirect);
        }

        const operand_id = try self.resolve(ty_op.operand);

        const optional_ty = self.typeOfIndex(inst);
        if (optional_ty.optionalReprIsPayload(mod)) {
            return operand_id;
        }

        const payload_id = try self.convertToIndirect(payload_ty, operand_id);
        const members = [_]IdRef{ payload_id, try self.constBool(true, .indirect) };
        const types = [_]Type{ payload_ty, Type.bool };
        return try self.constructStruct(optional_ty, &types, &members);
    }

    fn airSwitchBr(self: *DeclGen, inst: Air.Inst.Index) !void {
        const mod = self.module;
        const pl_op = self.air.instructions.items(.data)[inst].pl_op;
        const cond_ty = self.typeOf(pl_op.operand);
        const cond = try self.resolve(pl_op.operand);
        const cond_indirect = try self.convertToIndirect(cond_ty, cond);
        const switch_br = self.air.extraData(Air.SwitchBr, pl_op.payload);

        const cond_words: u32 = switch (cond_ty.zigTypeTag(mod)) {
            .Bool => 1,
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
            .ErrorSet => 1,
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
        self.func.body.writeOperand(IdRef, cond_indirect);
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
                        .Bool, .Int => if (cond_ty.isSignedInt(mod)) @as(u64, @bitCast(value.toSignedInt(mod))) else value.toUnsignedInt(mod),
                        .Enum => blk: {
                            // TODO: figure out of cond_ty is correct (something with enum literals)
                            break :blk (try value.intFromEnum(cond_ty, mod)).toUnsignedInt(mod); // TODO: composite integer constants
                        },
                        .ErrorSet => value.getErrorInt(mod),
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

    fn airDbgStmt(self: *DeclGen, inst: Air.Inst.Index) !void {
        const dbg_stmt = self.air.instructions.items(.data)[inst].dbg_stmt;
        const mod = self.module;
        const decl = mod.declPtr(self.decl_index);
        const path = decl.getFileScope(mod).sub_file_path;
        const src_fname_id = try self.spv.resolveSourceFileName(path);
        const base_line = self.base_line_stack.getLast();
        try self.func.body.emit(self.spv.gpa, .OpLine, .{
            .file = src_fname_id,
            .line = base_line + dbg_stmt.line + 1,
            .column = dbg_stmt.column + 1,
        });
    }

    fn airDbgInlineBegin(self: *DeclGen, inst: Air.Inst.Index) !void {
        const mod = self.module;
        const fn_ty = self.air.instructions.items(.data)[inst].ty_fn;
        const decl_index = mod.funcInfo(fn_ty.func).owner_decl;
        const decl = mod.declPtr(decl_index);
        try self.base_line_stack.append(self.gpa, decl.src_line);
    }

    fn airDbgInlineEnd(self: *DeclGen, inst: Air.Inst.Index) !void {
        _ = inst;
        _ = self.base_line_stack.pop();
    }

    fn airDbgVar(self: *DeclGen, inst: Air.Inst.Index) !void {
        const pl_op = self.air.instructions.items(.data)[inst].pl_op;
        const target_id = try self.resolve(pl_op.operand);
        const name = self.air.nullTerminatedString(pl_op.payload);
        try self.spv.debugName(target_id, name);
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
            // TODO: Check that the output type from assembly is the same as the type actually expected by Zig.
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

        const result_type_ref = try self.resolveFnReturnType(return_type.toType());
        const result_id = self.spv.allocId();
        const callee_id = try self.resolve(pl_op.operand);

        const params = try self.gpa.alloc(spec.IdRef, args.len);
        defer self.gpa.free(params);

        var n_params: usize = 0;
        for (args) |arg| {
            // Note: resolve() might emit instructions, so we need to call it
            // before starting to emit OpFunctionCall instructions. Hence the
            // temporary params buffer.
            const arg_ty = self.typeOf(arg);
            if (!arg_ty.hasRuntimeBitsIgnoreComptime(mod)) continue;
            const arg_id = try self.resolve(arg);

            params[n_params] = arg_id;
            n_params += 1;
        }

        try self.func.body.emit(self.spv.gpa, .OpFunctionCall, .{
            .id_result_type = self.typeId(result_type_ref),
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
