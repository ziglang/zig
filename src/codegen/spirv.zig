const std = @import("std");
const Allocator = std.mem.Allocator;
const Target = std.Target;
const log = std.log.scoped(.codegen);
const assert = std.debug.assert;

const Module = @import("../Module.zig");
const Decl = Module.Decl;
const Type = @import("../type.zig").Type;
const Value = @import("../Value.zig");
const LazySrcLoc = std.zig.LazySrcLoc;
const Air = @import("../Air.zig");
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

const SpvSection = @import("spirv/Section.zig");
const SpvAssembler = @import("spirv/Assembler.zig");

const InstMap = std.AutoHashMapUnmanaged(Air.Inst.Index, IdRef);

pub const zig_call_abi_ver = 3;

const InternMap = std.AutoHashMapUnmanaged(struct { InternPool.Index, DeclGen.Repr }, IdResult);
const PtrTypeMap = std.AutoHashMapUnmanaged(
    struct { InternPool.Index, StorageClass },
    struct { ty_id: IdRef, fwd_emitted: bool },
);

const ControlFlow = union(enum) {
    const Structured = struct {
        /// This type indicates the way that a block is terminated. The
        /// state of a particular block is used to track how a jump from
        /// inside the block must reach the outside.
        const Block = union(enum) {
            const Incoming = struct {
                src_label: IdRef,
                /// Instruction that returns an u32 value of the
                /// `Air.Inst.Index` that control flow should jump to.
                next_block: IdRef,
            };

            const SelectionMerge = struct {
                /// Incoming block from the `then` label.
                /// Note that hte incoming block from the `else` label is
                /// either given by the next element in the stack.
                incoming: Incoming,
                /// The label id of the cond_br's merge block.
                /// For the top-most element in the stack, this
                /// value is undefined.
                merge_block: IdRef,
            };

            /// For a `selection` type block, we cannot use early exits, and we
            /// must generate a 'merge ladder' of OpSelection instructions. To that end,
            /// we keep a stack of the merges that still must be closed at the end of
            /// a block.
            ///
            /// This entire structure basically just resembles a tree like
            ///     a   x
            ///      \ /
            ///   b   o   merge
            ///    \ /
            /// c   o   merge
            ///  \ /
            ///   o   merge
            ///  /
            /// o   jump to next block
            selection: struct {
                /// In order to know which merges we still need to do, we need to keep
                /// a stack of those.
                merge_stack: std.ArrayListUnmanaged(SelectionMerge) = .{},
            },
            /// For a `loop` type block, we can early-exit the block by
            /// jumping to the loop exit node, and we don't need to generate
            /// an entire stack of merges.
            loop: struct {
                /// The next block to jump to can be determined from any number
                /// of conditions that jump to the loop exit.
                merges: std.ArrayListUnmanaged(Incoming) = .{},
                /// The label id of the loop's merge block.
                merge_block: IdRef,
            },

            fn deinit(self: *Structured.Block, a: Allocator) void {
                switch (self.*) {
                    .selection => |*merge| merge.merge_stack.deinit(a),
                    .loop => |*merge| merge.merges.deinit(a),
                }
                self.* = undefined;
            }
        };
        /// The stack of (structured) blocks that we are currently in. This determines
        /// how exits from the current block must be handled.
        block_stack: std.ArrayListUnmanaged(*Structured.Block) = .{},
        /// Maps `block` inst indices to the variable that the block's result
        /// value must be written to.
        block_results: std.AutoHashMapUnmanaged(Air.Inst.Index, IdRef) = .{},
    };

    const Unstructured = struct {
        const Incoming = struct {
            src_label: IdRef,
            break_value_id: IdRef,
        };

        const Block = struct {
            label: ?IdRef = null,
            incoming_blocks: std.ArrayListUnmanaged(Incoming) = .{},
        };

        /// We need to keep track of result ids for block labels, as well as the 'incoming'
        /// blocks for a block.
        blocks: std.AutoHashMapUnmanaged(Air.Inst.Index, *Block) = .{},
    };

    structured: Structured,
    unstructured: Unstructured,

    pub fn deinit(self: *ControlFlow, a: Allocator) void {
        switch (self.*) {
            .structured => |*cf| {
                cf.block_stack.deinit(a);
                cf.block_results.deinit(a);
            },
            .unstructured => |*cf| {
                cf.blocks.deinit(a);
            },
        }
        self.* = undefined;
    }
};

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
    decl_link: std.AutoHashMapUnmanaged(InternPool.DeclIndex, SpvModule.Decl.Index) = .{},

    /// A map of Zig InternPool indices for anonymous decls to SPIR-V decl indices.
    anon_decl_link: std.AutoHashMapUnmanaged(struct { InternPool.Index, StorageClass }, SpvModule.Decl.Index) = .{},

    /// A map that maps AIR intern pool indices to SPIR-V result-ids.
    intern_map: InternMap = .{},

    /// This map serves a dual purpose:
    /// - It keeps track of pointers that are currently being emitted, so that we can tell
    ///   if they are recursive and need an OpTypeForwardPointer.
    /// - It caches pointers by child-type. This is required because sometimes we rely on
    ///   ID-equality for pointers, and pointers constructed via `ptrType()` aren't interned
    ///   via the usual `intern_map` mechanism.
    ptr_types: PtrTypeMap = .{},

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
        self.intern_map.deinit(self.gpa);
        self.ptr_types.deinit(self.gpa);
    }

    fn genDecl(
        self: *Object,
        mod: *Module,
        decl_index: InternPool.DeclIndex,
        air: Air,
        liveness: Liveness,
    ) !void {
        const decl = mod.declPtr(decl_index);
        const namespace = mod.namespacePtr(decl.src_namespace);
        const structured_cfg = namespace.file_scope.mod.structured_cfg;

        var decl_gen = DeclGen{
            .gpa = self.gpa,
            .object = self,
            .module = mod,
            .spv = &self.spv,
            .decl_index = decl_index,
            .air = air,
            .liveness = liveness,
            .intern_map = &self.intern_map,
            .ptr_types = &self.ptr_types,
            .control_flow = switch (structured_cfg) {
                true => .{ .structured = .{} },
                false => .{ .unstructured = .{} },
            },
            .current_block_label = undefined,
            .base_line = decl.src_line,
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
        decl_index: InternPool.DeclIndex,
    ) !void {
        try self.genDecl(mod, decl_index, undefined, undefined);
    }

    /// Fetch or allocate a result id for decl index. This function also marks the decl as alive.
    /// Note: Function does not actually generate the decl, it just allocates an index.
    pub fn resolveDecl(self: *Object, mod: *Module, decl_index: InternPool.DeclIndex) !SpvModule.Decl.Index {
        const decl = mod.declPtr(decl_index);
        assert(decl.has_tv); // TODO: Do we need to handle a situation where this is false?

        const entry = try self.decl_link.getOrPut(self.gpa, decl_index);
        if (!entry.found_existing) {
            // TODO: Extern fn?
            const kind: SpvModule.Decl.Kind = if (decl.val.isFuncBody(mod))
                .func
            else switch (decl.@"addrspace") {
                .generic => .invocation_global,
                else => .global,
            };

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
    decl_index: InternPool.DeclIndex,

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

    /// A map that maps AIR intern pool indices to SPIR-V result-ids.
    /// See `Object.intern_map`.
    intern_map: *InternMap,

    /// Module's pointer types, see `Object.ptr_types`.
    ptr_types: *PtrTypeMap,

    /// This field keeps track of the current state wrt structured or unstructured control flow.
    control_flow: ControlFlow,

    /// The label of the SPIR-V block we are currently generating.
    current_block_label: IdRef,

    /// The code (prologue and body) for the function we are currently generating code for.
    func: SpvModule.Fn = .{},

    /// The base offset of the current decl, which is what `dbg_stmt` is relative to.
    base_line: u32,

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

        /// Null if this type is a scalar, or the length
        /// of the vector otherwise.
        vector_len: ?u32,

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
        self.control_flow.deinit(self.gpa);
        self.func.deinit(self.gpa);
    }

    /// Return the target which we are currently compiling for.
    pub fn getTarget(self: *DeclGen) std.Target {
        return self.module.getTarget();
    }

    pub fn fail(self: *DeclGen, comptime format: []const u8, args: anytype) Error {
        @setCold(true);
        const mod = self.module;
        const src_loc = self.module.declPtr(self.decl_index).srcLoc(mod);
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
        const index = inst.toIndex().?;
        return self.inst_results.get(index).?; // Assertion means instruction does not dominate usage.
    }

    fn resolveAnonDecl(self: *DeclGen, val: InternPool.Index) !IdRef {
        // TODO: This cannot be a function at this point, but it should probably be handled anyway.

        const mod = self.module;
        const ty = Type.fromInterned(mod.intern_pool.typeOf(val));
        const decl_ptr_ty_id = try self.ptrType(ty, .Generic);

        const spv_decl_index = blk: {
            const entry = try self.object.anon_decl_link.getOrPut(self.object.gpa, .{ val, .Function });
            if (entry.found_existing) {
                try self.addFunctionDep(entry.value_ptr.*, .Function);

                const result_id = self.spv.declPtr(entry.value_ptr.*).result_id;
                return try self.castToGeneric(decl_ptr_ty_id, result_id);
            }

            const spv_decl_index = try self.spv.allocDecl(.invocation_global);
            try self.addFunctionDep(spv_decl_index, .Function);
            entry.value_ptr.* = spv_decl_index;
            break :blk spv_decl_index;
        };

        // TODO: At some point we will be able to generate this all constant here, but then all of
        //   constant() will need to be implemented such that it doesn't generate any at-runtime code.
        // NOTE: Because this is a global, we really only want to initialize it once. Therefore the
        //   constant lowering of this value will need to be deferred to an initializer similar to
        //   other globals.

        const result_id = self.spv.declPtr(spv_decl_index).result_id;

        {
            // Save the current state so that we can temporarily generate into a different function.
            // TODO: This should probably be made a little more robust.
            const func = self.func;
            defer self.func = func;
            const block_label = self.current_block_label;
            defer self.current_block_label = block_label;

            self.func = .{};
            defer self.func.deinit(self.gpa);

            const initializer_proto_ty_id = try self.functionType(Type.void, &.{});

            const initializer_id = self.spv.allocId();
            try self.func.prologue.emit(self.spv.gpa, .OpFunction, .{
                .id_result_type = try self.resolveType(Type.void, .direct),
                .id_result = initializer_id,
                .function_control = .{},
                .function_type = initializer_proto_ty_id,
            });
            const root_block_id = self.spv.allocId();
            try self.func.prologue.emit(self.spv.gpa, .OpLabel, .{
                .id_result = root_block_id,
            });
            self.current_block_label = root_block_id;

            const val_id = try self.constant(ty, Value.fromInterned(val), .indirect);
            try self.func.body.emit(self.spv.gpa, .OpStore, .{
                .pointer = result_id,
                .object = val_id,
            });

            try self.func.body.emit(self.spv.gpa, .OpReturn, {});
            try self.func.body.emit(self.spv.gpa, .OpFunctionEnd, {});
            try self.spv.addFunction(spv_decl_index, self.func);

            try self.spv.debugNameFmt(initializer_id, "initializer of __anon_{d}", .{@intFromEnum(val)});

            const fn_decl_ptr_ty_id = try self.ptrType(ty, .Function);
            try self.spv.sections.types_globals_constants.emit(self.spv.gpa, .OpExtInst, .{
                .id_result_type = fn_decl_ptr_ty_id,
                .id_result = result_id,
                .set = try self.spv.importInstructionSet(.zig),
                .instruction = .{ .inst = 0 }, // TODO: Put this definition somewhere...
                .id_ref_4 = &.{initializer_id},
            });
        }

        return try self.castToGeneric(decl_ptr_ty_id, result_id);
    }

    fn addFunctionDep(self: *DeclGen, decl_index: SpvModule.Decl.Index, storage_class: StorageClass) !void {
        const target = self.getTarget();
        if (target.os.tag == .vulkan) {
            // Shader entry point dependencies must be variables with Input or Output storage class
            switch (storage_class) {
                .Input, .Output => {
                    try self.func.decl_deps.put(self.spv.gpa, decl_index, {});
                },
                else => {},
            }
        } else {
            try self.func.decl_deps.put(self.spv.gpa, decl_index, {});
        }
    }

    fn castToGeneric(self: *DeclGen, type_id: IdRef, ptr_id: IdRef) !IdRef {
        const target = self.getTarget();

        if (target.os.tag == .vulkan) {
            return ptr_id;
        } else {
            const result_id = self.spv.allocId();
            try self.func.body.emit(self.spv.gpa, .OpPtrCastToGeneric, .{
                .id_result_type = type_id,
                .id_result = result_id,
                .pointer = ptr_id,
            });
            return result_id;
        }
    }

    /// Start a new SPIR-V block, Emits the label of the new block, and stores which
    /// block we are currently generating.
    /// Note that there is no such thing as nested blocks like in ZIR or AIR, so we don't need to
    /// keep track of the previous block.
    fn beginSpvBlock(self: *DeclGen, label: IdResult) !void {
        try self.func.body.emit(self.spv.gpa, .OpLabel, .{ .id_result = label });
        self.current_block_label = label;
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

    /// Checks whether the type can be directly translated to SPIR-V vectors
    fn isVector(self: *DeclGen, ty: Type) bool {
        const mod = self.module;
        const target = self.getTarget();
        if (ty.zigTypeTag(mod) != .Vector) return false;
        const elem_ty = ty.childType(mod);

        const len = ty.vectorLen(mod);
        const is_scalar = elem_ty.isNumeric(mod) or elem_ty.toIntern() == .bool_type;
        const spirv_len = len > 1 and len <= 4;
        const opencl_len = if (target.os.tag == .opencl) (len == 8 or len == 16) else false;
        return is_scalar and (spirv_len or opencl_len);
    }

    fn arithmeticTypeInfo(self: *DeclGen, ty: Type) ArithmeticTypeInfo {
        const mod = self.module;
        const target = self.getTarget();
        var scalar_ty = ty.scalarType(mod);
        if (scalar_ty.zigTypeTag(mod) == .Enum) {
            scalar_ty = scalar_ty.intTagType(mod);
        }
        const vector_len = if (ty.isVector(mod)) ty.vectorLen(mod) else null;
        return switch (scalar_ty.zigTypeTag(mod)) {
            .Bool => ArithmeticTypeInfo{
                .bits = 1, // Doesn't matter for this class.
                .backing_bits = self.backingIntBits(1).?,
                .vector_len = vector_len,
                .signedness = .unsigned, // Technically, but doesn't matter for this class.
                .class = .bool,
            },
            .Float => ArithmeticTypeInfo{
                .bits = scalar_ty.floatBits(target),
                .backing_bits = scalar_ty.floatBits(target), // TODO: F80?
                .vector_len = vector_len,
                .signedness = .signed, // Technically, but doesn't matter for this class.
                .class = .float,
            },
            .Int => blk: {
                const int_info = scalar_ty.intInfo(mod);
                // TODO: Maybe it's useful to also return this value.
                const maybe_backing_bits = self.backingIntBits(int_info.bits);
                break :blk ArithmeticTypeInfo{
                    .bits = int_info.bits,
                    .backing_bits = maybe_backing_bits orelse 0,
                    .vector_len = vector_len,
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
            .Enum => unreachable,
            .Vector => unreachable,
            else => unreachable, // Unhandled arithmetic type
        };
    }

    /// Emits a bool constant in a particular representation.
    fn constBool(self: *DeclGen, value: bool, repr: Repr) !IdRef {
        // TODO: Cache?

        const section = &self.spv.sections.types_globals_constants;
        switch (repr) {
            .indirect => {
                return try self.constInt(Type.u1, @intFromBool(value), .indirect);
            },
            .direct => {
                const result_ty_id = try self.resolveType(Type.bool, .direct);
                const result_id = self.spv.allocId();
                const operands = .{
                    .id_result_type = result_ty_id,
                    .id_result = result_id,
                };
                switch (value) {
                    true => try section.emit(self.spv.gpa, .OpConstantTrue, operands),
                    false => try section.emit(self.spv.gpa, .OpConstantFalse, operands),
                }
                return result_id;
            },
        }
    }

    /// Emits an integer constant.
    /// This function, unlike SpvModule.constInt, takes care to bitcast
    /// the value to an unsigned int first for Kernels.
    fn constInt(self: *DeclGen, ty: Type, value: anytype, repr: Repr) !IdRef {
        // TODO: Cache?
        const mod = self.module;
        const scalar_ty = ty.scalarType(mod);
        const int_info = scalar_ty.intInfo(mod);
        // Use backing bits so that negatives are sign extended
        const backing_bits = self.backingIntBits(int_info.bits).?; // Assertion failure means big int

        const bits: u64 = switch (int_info.signedness) {
            // Intcast needed to silence compile errors for when the wrong path is compiled.
            // Lazy fix.
            .signed => @bitCast(@as(i64, @intCast(value))),
            .unsigned => @as(u64, @intCast(value)),
        };

        // Manually truncate the value to the right amount of bits.
        const truncated_bits = if (backing_bits == 64)
            bits
        else
            bits & (@as(u64, 1) << @intCast(backing_bits)) - 1;

        const result_ty_id = try self.resolveType(scalar_ty, repr);
        const result_id = self.spv.allocId();

        const section = &self.spv.sections.types_globals_constants;
        switch (backing_bits) {
            0 => unreachable, // u0 is comptime
            1...32 => try section.emit(self.spv.gpa, .OpConstant, .{
                .id_result_type = result_ty_id,
                .id_result = result_id,
                .value = .{ .uint32 = @truncate(truncated_bits) },
            }),
            33...64 => try section.emit(self.spv.gpa, .OpConstant, .{
                .id_result_type = result_ty_id,
                .id_result = result_id,
                .value = .{ .uint64 = truncated_bits },
            }),
            else => unreachable, // TODO: Large integer constants
        }

        if (!ty.isVector(mod)) {
            return result_id;
        }

        const n = ty.vectorLen(mod);
        const ids = try self.gpa.alloc(IdRef, n);
        defer self.gpa.free(ids);
        @memset(ids, result_id);

        const vec_ty_id = try self.resolveType(ty, repr);
        const vec_result_id = self.spv.allocId();
        try self.func.body.emit(self.spv.gpa, .OpCompositeConstruct, .{
            .id_result_type = vec_ty_id,
            .id_result = vec_result_id,
            .constituents = ids,
        });
        return vec_result_id;
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
            const ptr_member_ty_id = try self.ptrType(member_ty, .Function);
            const ptr_id = try self.accessChain(ptr_member_ty_id, ptr_composite_id, &.{@as(u32, @intCast(index))});
            try self.func.body.emit(self.spv.gpa, .OpStore, .{
                .pointer = ptr_id,
                .object = constitent_id,
            });
        }
        return try self.load(ty, ptr_composite_id, .{});
    }

    /// Construct a vector at runtime.
    /// ty must be an vector type.
    /// Constituents should be in `indirect` representation (as the elements of an vector should be).
    /// Result is in `direct` representation.
    fn constructVector(self: *DeclGen, ty: Type, constituents: []const IdRef) !IdRef {
        // The Khronos LLVM-SPIRV translator crashes because it cannot construct structs which'
        // operands are not constant.
        // See https://github.com/KhronosGroup/SPIRV-LLVM-Translator/issues/1349
        // For now, just initialize the struct by setting the fields manually...
        // TODO: Make this OpCompositeConstruct when we can
        const mod = self.module;
        const ptr_composite_id = try self.alloc(ty, .{ .storage_class = .Function });
        const ptr_elem_ty_id = try self.ptrType(ty.elemType2(mod), .Function);
        for (constituents, 0..) |constitent_id, index| {
            const ptr_id = try self.accessChain(ptr_elem_ty_id, ptr_composite_id, &.{@as(u32, @intCast(index))});
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
        const ptr_elem_ty_id = try self.ptrType(ty.elemType2(mod), .Function);
        for (constituents, 0..) |constitent_id, index| {
            const ptr_id = try self.accessChain(ptr_elem_ty_id, ptr_composite_id, &.{@as(u32, @intCast(index))});
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
    fn constant(self: *DeclGen, ty: Type, val: Value, repr: Repr) !IdRef {
        // Note: Using intern_map can only be used with constants that DO NOT generate any runtime code!!
        // Ideally that should be all constants in the future, or it should be cleaned up somehow. For
        // now, only use the intern_map on case-by-case basis by breaking to :cache.
        if (self.intern_map.get(.{ val.toIntern(), repr })) |id| {
            return id;
        }

        const mod = self.module;
        const target = self.getTarget();
        const result_ty_id = try self.resolveType(ty, repr);
        const ip = &mod.intern_pool;

        log.debug("lowering constant: ty = {}, val = {}", .{ ty.fmt(mod), val.fmtValue(mod, null) });
        if (val.isUndefDeep(mod)) {
            return self.spv.constUndef(result_ty_id);
        }

        const section = &self.spv.sections.types_globals_constants;

        const cacheable_id = cache: {
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

                    .false, .true => break :cache try self.constBool(val.toBool(), repr),
                },
                .int => {
                    if (ty.isSignedInt(mod)) {
                        break :cache try self.constInt(ty, val.toSignedInt(mod), repr);
                    } else {
                        break :cache try self.constInt(ty, val.toUnsignedInt(mod), repr);
                    }
                },
                .float => {
                    const lit: spec.LiteralContextDependentNumber = switch (ty.floatBits(target)) {
                        16 => .{ .uint32 = @as(u16, @bitCast(val.toFloat(f16, mod))) },
                        32 => .{ .float32 = val.toFloat(f32, mod) },
                        64 => .{ .float64 = val.toFloat(f64, mod) },
                        80, 128 => unreachable, // TODO
                        else => unreachable,
                    };
                    const result_id = self.spv.allocId();
                    try section.emit(self.spv.gpa, .OpConstant, .{
                        .id_result_type = result_ty_id,
                        .id_result = result_id,
                        .value = lit,
                    });
                    break :cache result_id;
                },
                .err => |err| {
                    const value = try mod.getErrorValue(err.name);
                    break :cache try self.constInt(ty, value, repr);
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
                        .err_name => |err_name| Value.fromInterned((try mod.intern(.{ .err = .{
                            .ty = ty.errorUnionSet(mod).toIntern(),
                            .name = err_name,
                        } }))),
                        .payload => try mod.intValue(err_int_ty, 0),
                    };
                    const payload_ty = ty.errorUnionPayload(mod);
                    const eu_layout = self.errorUnionLayout(payload_ty);
                    if (!eu_layout.payload_has_bits) {
                        // We use the error type directly as the type.
                        break :cache try self.constant(err_ty, err_val, .indirect);
                    }

                    const payload_val = Value.fromInterned(switch (error_union.val) {
                        .err_name => try mod.intern(.{ .undef = payload_ty.toIntern() }),
                        .payload => |payload| payload,
                    });

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
                    break :cache try self.constant(int_ty, int_val, repr);
                },
                .ptr => return self.constantPtr(val),
                .slice => |slice| {
                    const ptr_ty = ty.slicePtrFieldType(mod);
                    const ptr_id = try self.constantPtr(Value.fromInterned(slice.ptr));
                    const len_id = try self.constant(Type.usize, Value.fromInterned(slice.len), .indirect);
                    return self.constructStruct(
                        ty,
                        &.{ ptr_ty, Type.usize },
                        &.{ ptr_id, len_id },
                    );
                },
                .opt => {
                    const payload_ty = ty.optionalChild(mod);
                    const maybe_payload_val = val.optionalValue(mod);

                    if (!payload_ty.hasRuntimeBits(mod)) {
                        break :cache try self.constBool(maybe_payload_val != null, .indirect);
                    } else if (ty.optionalReprIsPayload(mod)) {
                        // Optional representation is a nullable pointer or slice.
                        if (maybe_payload_val) |payload_val| {
                            return try self.constant(payload_ty, payload_val, .indirect);
                        } else {
                            break :cache try self.spv.constNull(result_ty_id);
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
                        const elem_ty = Type.fromInterned(array_type.child);

                        const constituents = try self.gpa.alloc(IdRef, @intCast(ty.arrayLenIncludingSentinel(mod)));
                        defer self.gpa.free(constituents);

                        switch (aggregate.storage) {
                            .bytes => |bytes| {
                                // TODO: This is really space inefficient, perhaps there is a better
                                // way to do it?
                                for (constituents, bytes.toSlice(constituents.len, ip)) |*constituent, byte| {
                                    constituent.* = try self.constInt(elem_ty, byte, .indirect);
                                }
                            },
                            .elems => |elems| {
                                for (constituents, elems) |*constituent, elem| {
                                    constituent.* = try self.constant(elem_ty, Value.fromInterned(elem), .indirect);
                                }
                            },
                            .repeated_elem => |elem| {
                                @memset(constituents, try self.constant(elem_ty, Value.fromInterned(elem), .indirect));
                            },
                        }

                        switch (tag) {
                            .array_type => return self.constructArray(ty, constituents),
                            .vector_type => return self.constructVector(ty, constituents),
                            else => unreachable,
                        }
                    },
                    .struct_type => {
                        const struct_type = mod.typeToStruct(ty).?;
                        if (struct_type.layout == .@"packed") {
                            return self.todo("packed struct constants", .{});
                        }

                        var types = std.ArrayList(Type).init(self.gpa);
                        defer types.deinit();

                        var constituents = std.ArrayList(IdRef).init(self.gpa);
                        defer constituents.deinit();

                        var it = struct_type.iterateRuntimeOrder(ip);
                        while (it.next()) |field_index| {
                            const field_ty = Type.fromInterned(struct_type.field_types.get(ip)[field_index]);
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
                    const active_field = ty.unionTagFieldIndex(Value.fromInterned(un.tag), mod).?;
                    const union_obj = mod.typeToUnion(ty).?;
                    const field_ty = Type.fromInterned(union_obj.field_types.get(ip)[active_field]);
                    const payload = if (field_ty.hasRuntimeBitsIgnoreComptime(mod))
                        try self.constant(field_ty, Value.fromInterned(un.val), .direct)
                    else
                        null;
                    return try self.unionInit(ty, active_field, payload);
                },
                .memoized_call => unreachable,
            }
        };

        try self.intern_map.putNoClobber(self.gpa, .{ val.toIntern(), repr }, cacheable_id);

        return cacheable_id;
    }

    fn constantPtr(self: *DeclGen, ptr_val: Value) Error!IdRef {
        // TODO: Caching??

        const zcu = self.module;

        if (ptr_val.isUndef(zcu)) {
            const result_ty = ptr_val.typeOf(zcu);
            const result_ty_id = try self.resolveType(result_ty, .direct);
            return self.spv.constUndef(result_ty_id);
        }

        var arena = std.heap.ArenaAllocator.init(self.gpa);
        defer arena.deinit();

        const derivation = try ptr_val.pointerDerivation(arena.allocator(), zcu);
        return self.derivePtr(derivation);
    }

    fn derivePtr(self: *DeclGen, derivation: Value.PointerDeriveStep) Error!IdRef {
        const zcu = self.module;
        switch (derivation) {
            .comptime_alloc_ptr, .comptime_field_ptr => unreachable,
            .int => |int| {
                const result_ty_id = try self.resolveType(int.ptr_ty, .direct);
                // TODO: This can probably be an OpSpecConstantOp Bitcast, but
                // that is not implemented by Mesa yet. Therefore, just generate it
                // as a runtime operation.
                const result_ptr_id = self.spv.allocId();
                try self.func.body.emit(self.spv.gpa, .OpConvertUToPtr, .{
                    .id_result_type = result_ty_id,
                    .id_result = result_ptr_id,
                    .integer_value = try self.constant(Type.usize, try zcu.intValue(Type.usize, int.addr), .direct),
                });
                return result_ptr_id;
            },
            .decl_ptr => |decl| {
                const result_ptr_ty = try zcu.declPtr(decl).declPtrType(zcu);
                return self.constantDeclRef(result_ptr_ty, decl);
            },
            .anon_decl_ptr => |ad| {
                const result_ptr_ty = Type.fromInterned(ad.orig_ty);
                return self.constantAnonDeclRef(result_ptr_ty, ad);
            },
            .eu_payload_ptr => @panic("TODO"),
            .opt_payload_ptr => @panic("TODO"),
            .field_ptr => |field| {
                const parent_ptr_id = try self.derivePtr(field.parent.*);
                const parent_ptr_ty = try field.parent.ptrType(zcu);
                return self.structFieldPtr(field.result_ptr_ty, parent_ptr_ty, parent_ptr_id, field.field_idx);
            },
            .elem_ptr => |elem| {
                const parent_ptr_id = try self.derivePtr(elem.parent.*);
                const parent_ptr_ty = try elem.parent.ptrType(zcu);
                const index_id = try self.constInt(Type.usize, elem.elem_idx, .direct);
                return self.ptrElemPtr(parent_ptr_ty, parent_ptr_id, index_id);
            },
            .offset_and_cast => |oac| {
                const parent_ptr_id = try self.derivePtr(oac.parent.*);
                const parent_ptr_ty = try oac.parent.ptrType(zcu);
                disallow: {
                    if (oac.byte_offset != 0) break :disallow;
                    // Allow changing the pointer type child only to restructure arrays.
                    // e.g. [3][2]T to T is fine, as is [2]T -> [2][1]T.
                    const src_base_ty = parent_ptr_ty.arrayBase(zcu)[0];
                    const dest_base_ty = oac.new_ptr_ty.arrayBase(zcu)[0];
                    if (self.getTarget().os.tag == .vulkan and src_base_ty.toIntern() != dest_base_ty.toIntern()) break :disallow;

                    const result_ty_id = try self.resolveType(oac.new_ptr_ty, .direct);
                    const result_ptr_id = self.spv.allocId();
                    try self.func.body.emit(self.spv.gpa, .OpBitcast, .{
                        .id_result_type = result_ty_id,
                        .id_result = result_ptr_id,
                        .operand = parent_ptr_id,
                    });
                    return result_ptr_id;
                }
                return self.fail("Cannot perform pointer cast: '{}' to '{}'", .{
                    parent_ptr_ty.fmt(zcu),
                    oac.new_ptr_ty.fmt(zcu),
                });
            },
        }
    }

    fn constantAnonDeclRef(
        self: *DeclGen,
        ty: Type,
        anon_decl: InternPool.Key.Ptr.BaseAddr.AnonDecl,
    ) !IdRef {
        // TODO: Merge this function with constantDeclRef.

        const mod = self.module;
        const ip = &mod.intern_pool;
        const ty_id = try self.resolveType(ty, .direct);
        const decl_val = anon_decl.val;
        const decl_ty = Type.fromInterned(ip.typeOf(decl_val));

        if (Value.fromInterned(decl_val).getFunction(mod)) |func| {
            _ = func;
            unreachable; // TODO
        } else if (Value.fromInterned(decl_val).getExternFunc(mod)) |func| {
            _ = func;
            unreachable;
        }

        // const is_fn_body = decl_ty.zigTypeTag(mod) == .Fn;
        if (!decl_ty.isFnOrHasRuntimeBitsIgnoreComptime(mod)) {
            // Pointer to nothing - return undefoined
            return self.spv.constUndef(ty_id);
        }

        if (decl_ty.zigTypeTag(mod) == .Fn) {
            unreachable; // TODO
        }

        // Anon decl refs are always generic.
        assert(ty.ptrAddressSpace(mod) == .generic);
        const decl_ptr_ty_id = try self.ptrType(decl_ty, .Generic);
        const ptr_id = try self.resolveAnonDecl(decl_val);

        if (decl_ptr_ty_id != ty_id) {
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

    fn constantDeclRef(self: *DeclGen, ty: Type, decl_index: InternPool.DeclIndex) !IdRef {
        const mod = self.module;
        const ty_id = try self.resolveType(ty, .direct);
        const decl = mod.declPtr(decl_index);

        switch (mod.intern_pool.indexToKey(decl.val.ip_index)) {
            .func => {
                // TODO: Properly lower function pointers. For now we are going to hack around it and
                // just generate an empty pointer. Function pointers are represented by a pointer to usize.
                return try self.spv.constUndef(ty_id);
            },
            .extern_func => unreachable, // TODO
            else => {},
        }

        if (!decl.typeOf(mod).isFnOrHasRuntimeBitsIgnoreComptime(mod)) {
            // Pointer to nothing - return undefined.
            return self.spv.constUndef(ty_id);
        }

        const spv_decl_index = try self.object.resolveDecl(mod, decl_index);
        const spv_decl = self.spv.declPtr(spv_decl_index);

        const decl_id = switch (spv_decl.kind) {
            .func => unreachable, // TODO: Is this possible?
            .global, .invocation_global => spv_decl.result_id,
        };

        const final_storage_class = self.spvStorageClass(decl.@"addrspace");
        try self.addFunctionDep(spv_decl_index, final_storage_class);

        const decl_ptr_ty_id = try self.ptrType(decl.typeOf(mod), final_storage_class);

        const ptr_id = switch (final_storage_class) {
            .Generic => try self.castToGeneric(decl_ptr_ty_id, decl_id),
            else => decl_id,
        };

        if (decl_ptr_ty_id != ty_id) {
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
    fn resolveTypeName(self: *DeclGen, ty: Type) ![]const u8 {
        var name = std.ArrayList(u8).init(self.gpa);
        defer name.deinit();
        try ty.print(name.writer(), self.module);
        return try name.toOwnedSlice();
    }

    /// Create an integer type suitable for storing at least 'bits' bits.
    /// The integer type that is returned by this function is the type that is used to perform
    /// actual operations (as well as store) a Zig type of a particular number of bits. To create
    /// a type with an exact size, use SpvModule.intType.
    fn intType(self: *DeclGen, signedness: std.builtin.Signedness, bits: u16) !IdRef {
        const backing_bits = self.backingIntBits(bits) orelse {
            // TODO: Integers too big for any native type are represented as "composite integers":
            // An array of largestSupportedIntBits.
            return self.todo("Implement {s} composite int type of {} bits", .{ @tagName(signedness), bits });
        };

        // Kernel only supports unsigned ints.
        if (self.getTarget().os.tag == .vulkan) {
            return self.spv.intType(signedness, backing_bits);
        }

        return self.spv.intType(.unsigned, backing_bits);
    }

    fn arrayType(self: *DeclGen, len: u32, child_ty: IdRef) !IdRef {
        // TODO: Cache??
        const len_id = try self.constInt(Type.u32, len, .direct);
        const result_id = self.spv.allocId();

        try self.spv.sections.types_globals_constants.emit(self.spv.gpa, .OpTypeArray, .{
            .id_result = result_id,
            .element_type = child_ty,
            .length = len_id,
        });
        return result_id;
    }

    fn ptrType(self: *DeclGen, child_ty: Type, storage_class: StorageClass) !IdRef {
        const key = .{ child_ty.toIntern(), storage_class };
        const entry = try self.ptr_types.getOrPut(self.gpa, key);
        if (entry.found_existing) {
            const fwd_id = entry.value_ptr.ty_id;
            if (!entry.value_ptr.fwd_emitted) {
                try self.spv.sections.types_globals_constants.emit(self.spv.gpa, .OpTypeForwardPointer, .{
                    .pointer_type = fwd_id,
                    .storage_class = storage_class,
                });
                entry.value_ptr.fwd_emitted = true;
            }
            return fwd_id;
        }

        const result_id = self.spv.allocId();
        entry.value_ptr.* = .{
            .ty_id = result_id,
            .fwd_emitted = false,
        };

        const child_ty_id = try self.resolveType(child_ty, .indirect);

        try self.spv.sections.types_globals_constants.emit(self.spv.gpa, .OpTypePointer, .{
            .id_result = result_id,
            .storage_class = storage_class,
            .type = child_ty_id,
        });

        return result_id;
    }

    fn functionType(self: *DeclGen, return_ty: Type, param_types: []const Type) !IdRef {
        // TODO: Cache??

        const param_ids = try self.gpa.alloc(IdRef, param_types.len);
        defer self.gpa.free(param_ids);

        for (param_types, param_ids) |param_ty, *param_id| {
            param_id.* = try self.resolveType(param_ty, .direct);
        }

        const ty_id = self.spv.allocId();
        try self.spv.sections.types_globals_constants.emit(self.spv.gpa, .OpTypeFunction, .{
            .id_result = ty_id,
            .return_type = try self.resolveFnReturnType(return_ty),
            .id_ref_2 = param_ids,
        });

        return ty_id;
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
    fn resolveUnionType(self: *DeclGen, ty: Type) !IdRef {
        const mod = self.module;
        const ip = &mod.intern_pool;
        const union_obj = mod.typeToUnion(ty).?;

        if (union_obj.getLayout(ip) == .@"packed") {
            return self.todo("packed union types", .{});
        }

        const layout = self.unionLayout(ty);
        if (!layout.has_payload) {
            // No payload, so represent this as just the tag type.
            return try self.resolveType(Type.fromInterned(union_obj.enum_tag_ty), .indirect);
        }

        var member_types: [4]IdRef = undefined;
        var member_names: [4][]const u8 = undefined;

        const u8_ty_id = try self.resolveType(Type.u8, .direct); // TODO: What if Int8Type is not enabled?

        if (layout.tag_size != 0) {
            const tag_ty_id = try self.resolveType(Type.fromInterned(union_obj.enum_tag_ty), .indirect);
            member_types[layout.tag_index] = tag_ty_id;
            member_names[layout.tag_index] = "(tag)";
        }

        if (layout.payload_size != 0) {
            const payload_ty_id = try self.resolveType(layout.payload_ty, .indirect);
            member_types[layout.payload_index] = payload_ty_id;
            member_names[layout.payload_index] = "(payload)";
        }

        if (layout.payload_padding_size != 0) {
            const payload_padding_ty_id = try self.arrayType(@intCast(layout.payload_padding_size), u8_ty_id);
            member_types[layout.payload_padding_index] = payload_padding_ty_id;
            member_names[layout.payload_padding_index] = "(payload padding)";
        }

        if (layout.padding_size != 0) {
            const padding_ty_id = try self.arrayType(@intCast(layout.padding_size), u8_ty_id);
            member_types[layout.padding_index] = padding_ty_id;
            member_names[layout.padding_index] = "(padding)";
        }

        const result_id = try self.spv.structType(member_types[0..layout.total_fields], member_names[0..layout.total_fields]);
        const type_name = try self.resolveTypeName(ty);
        defer self.gpa.free(type_name);
        try self.spv.debugName(result_id, type_name);
        return result_id;
    }

    fn resolveFnReturnType(self: *DeclGen, ret_ty: Type) !IdRef {
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
    fn resolveType(self: *DeclGen, ty: Type, repr: Repr) Error!IdRef {
        if (self.intern_map.get(.{ ty.toIntern(), repr })) |id| {
            return id;
        }

        const id = try self.resolveTypeInner(ty, repr);
        try self.intern_map.put(self.gpa, .{ ty.toIntern(), repr }, id);
        return id;
    }

    fn resolveTypeInner(self: *DeclGen, ty: Type, repr: Repr) Error!IdRef {
        const mod = self.module;
        const ip = &mod.intern_pool;
        log.debug("resolveType: ty = {}", .{ty.fmt(mod)});
        const target = self.getTarget();

        const section = &self.spv.sections.types_globals_constants;

        switch (ty.zigTypeTag(mod)) {
            .NoReturn => {
                assert(repr == .direct);
                return try self.spv.voidType();
            },
            .Void => switch (repr) {
                .direct => {
                    return try self.spv.voidType();
                },
                // Pointers to void
                .indirect => {
                    const result_id = self.spv.allocId();
                    try section.emit(self.spv.gpa, .OpTypeOpaque, .{
                        .id_result = result_id,
                        .literal_string = "void",
                    });
                    return result_id;
                },
            },
            .Bool => switch (repr) {
                .direct => return try self.spv.boolType(),
                .indirect => return try self.resolveType(Type.u1, .indirect),
            },
            .Int => {
                const int_info = ty.intInfo(mod);
                if (int_info.bits == 0) {
                    // Some times, the backend will be asked to generate a pointer to i0. OpTypeInt
                    // with 0 bits is invalid, so return an opaque type in this case.
                    assert(repr == .indirect);
                    const result_id = self.spv.allocId();
                    try section.emit(self.spv.gpa, .OpTypeOpaque, .{
                        .id_result = result_id,
                        .literal_string = "u0",
                    });
                    return result_id;
                }
                return try self.intType(int_info.signedness, int_info.bits);
            },
            .Enum => {
                const tag_ty = ty.intTagType(mod);
                return try self.resolveType(tag_ty, repr);
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

                return try self.spv.floatType(bits);
            },
            .Array => {
                const elem_ty = ty.childType(mod);
                const elem_ty_id = try self.resolveType(elem_ty, .indirect);
                const total_len = std.math.cast(u32, ty.arrayLenIncludingSentinel(mod)) orelse {
                    return self.fail("array type of {} elements is too large", .{ty.arrayLenIncludingSentinel(mod)});
                };

                if (!elem_ty.hasRuntimeBitsIgnoreComptime(mod)) {
                    // The size of the array would be 0, but that is not allowed in SPIR-V.
                    // This path can be reached when the backend is asked to generate a pointer to
                    // an array of some zero-bit type. This should always be an indirect path.
                    assert(repr == .indirect);

                    // We cannot use the child type here, so just use an opaque type.
                    const result_id = self.spv.allocId();
                    try section.emit(self.spv.gpa, .OpTypeOpaque, .{
                        .id_result = result_id,
                        .literal_string = "zero-sized array",
                    });
                    return result_id;
                } else if (total_len == 0) {
                    // The size of the array would be 0, but that is not allowed in SPIR-V.
                    // This path can be reached for example when there is a slicing of a pointer
                    // that produces a zero-length array. In all cases where this type can be generated,
                    // this should be an indirect path.
                    assert(repr == .indirect);

                    // In this case, we have an array of a non-zero sized type. In this case,
                    // generate an array of 1 element instead, so that ptr_elem_ptr instructions
                    // can be lowered to ptrAccessChain instead of manually performing the math.
                    return try self.arrayType(1, elem_ty_id);
                } else {
                    return try self.arrayType(total_len, elem_ty_id);
                }
            },
            .Fn => switch (repr) {
                .direct => {
                    const fn_info = mod.typeToFunc(ty).?;

                    comptime assert(zig_call_abi_ver == 3);
                    switch (fn_info.cc) {
                        .Unspecified, .Kernel, .Fragment, .Vertex, .C => {},
                        else => unreachable, // TODO
                    }

                    // TODO: Put this somewhere in Sema.zig
                    if (fn_info.is_var_args)
                        return self.fail("VarArgs functions are unsupported for SPIR-V", .{});

                    // Note: Logic is different from functionType().
                    const param_ty_ids = try self.gpa.alloc(IdRef, fn_info.param_types.len);
                    defer self.gpa.free(param_ty_ids);
                    var param_index: usize = 0;
                    for (fn_info.param_types.get(ip)) |param_ty_index| {
                        const param_ty = Type.fromInterned(param_ty_index);
                        if (!param_ty.hasRuntimeBitsIgnoreComptime(mod)) continue;

                        param_ty_ids[param_index] = try self.resolveType(param_ty, .direct);
                        param_index += 1;
                    }

                    const return_ty_id = try self.resolveFnReturnType(Type.fromInterned(fn_info.return_type));

                    const result_id = self.spv.allocId();
                    try section.emit(self.spv.gpa, .OpTypeFunction, .{
                        .id_result = result_id,
                        .return_type = return_ty_id,
                        .id_ref_2 = param_ty_ids[0..param_index],
                    });

                    return result_id;
                },
                .indirect => {
                    // TODO: Represent function pointers properly.
                    // For now, just use an usize type.
                    return try self.resolveType(Type.usize, .indirect);
                },
            },
            .Pointer => {
                const ptr_info = ty.ptrInfo(mod);

                const storage_class = self.spvStorageClass(ptr_info.flags.address_space);
                const ptr_ty_id = try self.ptrType(Type.fromInterned(ptr_info.child), storage_class);

                if (ptr_info.flags.size != .Slice) {
                    return ptr_ty_id;
                }

                const size_ty_id = try self.resolveType(Type.usize, .direct);
                return self.spv.structType(
                    &.{ ptr_ty_id, size_ty_id },
                    &.{ "ptr", "len" },
                );
            },
            .Vector => {
                const elem_ty = ty.childType(mod);
                // TODO: Make `.direct`.
                const elem_ty_id = try self.resolveType(elem_ty, .indirect);
                const len = ty.vectorLen(mod);

                if (self.isVector(ty)) {
                    return try self.spv.vectorType(len, elem_ty_id);
                } else {
                    return try self.arrayType(len, elem_ty_id);
                }
            },
            .Struct => {
                const struct_type = switch (ip.indexToKey(ty.toIntern())) {
                    .anon_struct_type => |tuple| {
                        const member_types = try self.gpa.alloc(IdRef, tuple.values.len);
                        defer self.gpa.free(member_types);

                        var member_index: usize = 0;
                        for (tuple.types.get(ip), tuple.values.get(ip)) |field_ty, field_val| {
                            if (field_val != .none or !Type.fromInterned(field_ty).hasRuntimeBits(mod)) continue;

                            member_types[member_index] = try self.resolveType(Type.fromInterned(field_ty), .indirect);
                            member_index += 1;
                        }

                        const result_id = try self.spv.structType(member_types[0..member_index], null);
                        const type_name = try self.resolveTypeName(ty);
                        defer self.gpa.free(type_name);
                        try self.spv.debugName(result_id, type_name);
                        return result_id;
                    },
                    .struct_type => ip.loadStructType(ty.toIntern()),
                    else => unreachable,
                };

                if (struct_type.layout == .@"packed") {
                    return try self.resolveType(Type.fromInterned(struct_type.backingIntType(ip).*), .direct);
                }

                var member_types = std.ArrayList(IdRef).init(self.gpa);
                defer member_types.deinit();

                var member_names = std.ArrayList([]const u8).init(self.gpa);
                defer member_names.deinit();

                var it = struct_type.iterateRuntimeOrder(ip);
                while (it.next()) |field_index| {
                    const field_ty = Type.fromInterned(struct_type.field_types.get(ip)[field_index]);
                    if (!field_ty.hasRuntimeBitsIgnoreComptime(mod)) {
                        // This is a zero-bit field - we only needed it for the alignment.
                        continue;
                    }

                    const field_name = struct_type.fieldName(ip, field_index).unwrap() orelse
                        try ip.getOrPutStringFmt(mod.gpa, "{d}", .{field_index}, .no_embedded_nulls);
                    try member_types.append(try self.resolveType(field_ty, .indirect));
                    try member_names.append(field_name.toSlice(ip));
                }

                const result_id = try self.spv.structType(member_types.items, member_names.items);
                const type_name = try self.resolveTypeName(ty);
                defer self.gpa.free(type_name);
                try self.spv.debugName(result_id, type_name);
                return result_id;
            },
            .Optional => {
                const payload_ty = ty.optionalChild(mod);
                if (!payload_ty.hasRuntimeBitsIgnoreComptime(mod)) {
                    // Just use a bool.
                    // Note: Always generate the bool with indirect format, to save on some sanity
                    // Perform the conversion to a direct bool when the field is extracted.
                    return try self.resolveType(Type.bool, .indirect);
                }

                const payload_ty_id = try self.resolveType(payload_ty, .indirect);
                if (ty.optionalReprIsPayload(mod)) {
                    // Optional is actually a pointer or a slice.
                    return payload_ty_id;
                }

                const bool_ty_id = try self.resolveType(Type.bool, .indirect);

                return try self.spv.structType(
                    &.{ payload_ty_id, bool_ty_id },
                    &.{ "payload", "valid" },
                );
            },
            .Union => return try self.resolveUnionType(ty),
            .ErrorSet => return try self.resolveType(Type.u16, repr),
            .ErrorUnion => {
                const payload_ty = ty.errorUnionPayload(mod);
                const error_ty_id = try self.resolveType(Type.anyerror, .indirect);

                const eu_layout = self.errorUnionLayout(payload_ty);
                if (!eu_layout.payload_has_bits) {
                    return error_ty_id;
                }

                const payload_ty_id = try self.resolveType(payload_ty, .indirect);

                var member_types: [2]IdRef = undefined;
                var member_names: [2][]const u8 = undefined;
                if (eu_layout.error_first) {
                    // Put the error first
                    member_types = .{ error_ty_id, payload_ty_id };
                    member_names = .{ "error", "payload" };
                    // TODO: ABI padding?
                } else {
                    // Put the payload first.
                    member_types = .{ payload_ty_id, error_ty_id };
                    member_names = .{ "payload", "error" };
                    // TODO: ABI padding?
                }

                return try self.spv.structType(&member_types, &member_names);
            },
            .Opaque => {
                const type_name = try self.resolveTypeName(ty);
                defer self.gpa.free(type_name);

                const result_id = self.spv.allocId();
                try section.emit(self.spv.gpa, .OpTypeOpaque, .{
                    .id_result = result_id,
                    .literal_string = type_name,
                });
                return result_id;
            },

            .Null,
            .Undefined,
            .EnumLiteral,
            .ComptimeFloat,
            .ComptimeInt,
            .Type,
            => unreachable, // Must be comptime.

            .Frame, .AnyFrame => unreachable, // TODO
        }
    }

    fn spvStorageClass(self: *DeclGen, as: std.builtin.AddressSpace) StorageClass {
        const target = self.getTarget();
        return switch (as) {
            .generic => switch (target.os.tag) {
                .vulkan => .Private,
                else => .Generic,
            },
            .shared => .Workgroup,
            .local => .Private,
            .global => .CrossWorkgroup,
            .constant => .UniformConstant,
            .input => .Input,
            .output => .Output,
            .uniform => .Uniform,
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
            const most_aligned_field_ty = Type.fromInterned(union_obj.field_types.get(ip)[most_aligned_field]);
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

    /// This structure is used as helper for element-wise operations. It is intended
    /// to be used with vectors, fake vectors (arrays) and single elements.
    const WipElementWise = struct {
        dg: *DeclGen,
        result_ty: Type,
        ty: Type,
        /// Always in direct representation.
        ty_id: IdRef,
        /// True if the input is an array type.
        is_array: bool,
        /// The element-wise operation should fill these results before calling finalize().
        /// These should all be in **direct** representation! `finalize()` will convert
        /// them to indirect if required.
        results: []IdRef,

        fn deinit(wip: *WipElementWise) void {
            wip.dg.gpa.free(wip.results);
        }

        /// Utility function to extract the element at a particular index in an
        /// input array. This type is expected to be a fake vector (array) if `wip.is_array`, and
        /// a vector or scalar otherwise.
        fn elementAt(wip: WipElementWise, ty: Type, value: IdRef, index: usize) !IdRef {
            const mod = wip.dg.module;
            if (wip.is_array) {
                assert(ty.isVector(mod));
                return try wip.dg.extractField(ty.childType(mod), value, @intCast(index));
            } else {
                assert(index == 0);
                return value;
            }
        }

        /// Turns the results of this WipElementWise into a result. This can be
        /// vectors, fake vectors (arrays) and single elements, depending on `result_ty`.
        /// After calling this function, this WIP is no longer usable.
        /// Results is in `direct` representation.
        fn finalize(wip: *WipElementWise) !IdRef {
            if (wip.is_array) {
                // Convert all the constituents to indirect, as required for the array.
                for (wip.results) |*result| {
                    result.* = try wip.dg.convertToIndirect(wip.ty, result.*);
                }
                return try wip.dg.constructArray(wip.result_ty, wip.results);
            } else {
                return wip.results[0];
            }
        }

        /// Allocate a result id at a particular index, and return it.
        fn allocId(wip: *WipElementWise, index: usize) IdRef {
            assert(wip.is_array or index == 0);
            wip.results[index] = wip.dg.spv.allocId();
            return wip.results[index];
        }
    };

    /// Create a new element-wise operation.
    fn elementWise(self: *DeclGen, result_ty: Type, force_element_wise: bool) !WipElementWise {
        const mod = self.module;
        const is_array = result_ty.isVector(mod) and (!self.isVector(result_ty) or force_element_wise);
        const num_results = if (is_array) result_ty.vectorLen(mod) else 1;
        const results = try self.gpa.alloc(IdRef, num_results);
        @memset(results, undefined);

        const ty = if (is_array) result_ty.scalarType(mod) else result_ty;
        const ty_id = try self.resolveType(ty, .direct);

        return .{
            .dg = self,
            .result_ty = result_ty,
            .ty = ty,
            .ty_id = ty_id,
            .is_array = is_array,
            .results = results,
        };
    }

    /// The SPIR-V backend is not yet advanced enough to support the std testing infrastructure.
    /// In order to be able to run tests, we "temporarily" lower test kernels into separate entry-
    /// points. The test executor will then be able to invoke these to run the tests.
    /// Note that tests are lowered according to std.builtin.TestFn, which is `fn () anyerror!void`.
    /// (anyerror!void has the same layout as anyerror).
    /// Each test declaration generates a function like.
    ///   %anyerror = OpTypeInt 0 16
    ///   %p_invocation_globals_struct_ty = ...
    ///   %p_anyerror = OpTypePointer CrossWorkgroup %anyerror
    ///   %K = OpTypeFunction %void %p_invocation_globals_struct_ty %p_anyerror
    ///
    ///   %test = OpFunction %void %K
    ///   %p_invocation_globals = OpFunctionParameter p_invocation_globals_struct_ty
    ///   %p_err = OpFunctionParameter %p_anyerror
    ///   %lbl = OpLabel
    ///   %result = OpFunctionCall %anyerror %func %p_invocation_globals
    ///   OpStore %p_err %result
    ///   OpFunctionEnd
    /// TODO is to also write out the error as a function call parameter, and to somehow fetch
    /// the name of an error in the text executor.
    fn generateTestEntryPoint(self: *DeclGen, name: []const u8, spv_test_decl_index: SpvModule.Decl.Index) !void {
        const anyerror_ty_id = try self.resolveType(Type.anyerror, .direct);
        const ptr_anyerror_ty = try self.module.ptrType(.{
            .child = Type.anyerror.toIntern(),
            .flags = .{ .address_space = .global },
        });
        const ptr_anyerror_ty_id = try self.resolveType(ptr_anyerror_ty, .direct);
        const kernel_proto_ty_id = try self.functionType(Type.void, &.{ptr_anyerror_ty});

        const test_id = self.spv.declPtr(spv_test_decl_index).result_id;

        const spv_decl_index = try self.spv.allocDecl(.func);
        const kernel_id = self.spv.declPtr(spv_decl_index).result_id;

        const error_id = self.spv.allocId();
        const p_error_id = self.spv.allocId();

        const section = &self.spv.sections.functions;
        try section.emit(self.spv.gpa, .OpFunction, .{
            .id_result_type = try self.resolveType(Type.void, .direct),
            .id_result = kernel_id,
            .function_control = .{},
            .function_type = kernel_proto_ty_id,
        });
        try section.emit(self.spv.gpa, .OpFunctionParameter, .{
            .id_result_type = ptr_anyerror_ty_id,
            .id_result = p_error_id,
        });
        try section.emit(self.spv.gpa, .OpLabel, .{
            .id_result = self.spv.allocId(),
        });
        try section.emit(self.spv.gpa, .OpFunctionCall, .{
            .id_result_type = anyerror_ty_id,
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
        try self.spv.declareEntryPoint(spv_decl_index, test_name, .Kernel);
    }

    fn genDecl(self: *DeclGen) !void {
        const mod = self.module;
        const ip = &mod.intern_pool;
        const decl = mod.declPtr(self.decl_index);
        const spv_decl_index = try self.object.resolveDecl(mod, self.decl_index);
        const result_id = self.spv.declPtr(spv_decl_index).result_id;

        switch (self.spv.declPtr(spv_decl_index).kind) {
            .func => {
                assert(decl.typeOf(mod).zigTypeTag(mod) == .Fn);
                const fn_info = mod.typeToFunc(decl.typeOf(mod)).?;
                const return_ty_id = try self.resolveFnReturnType(Type.fromInterned(fn_info.return_type));

                const prototype_ty_id = try self.resolveType(decl.typeOf(mod), .direct);
                try self.func.prologue.emit(self.spv.gpa, .OpFunction, .{
                    .id_result_type = return_ty_id,
                    .id_result = result_id,
                    .function_control = switch (fn_info.cc) {
                        .Inline => .{ .Inline = true },
                        else => .{},
                    },
                    .function_type = prototype_ty_id,
                });

                comptime assert(zig_call_abi_ver == 3);
                try self.args.ensureUnusedCapacity(self.gpa, fn_info.param_types.len);
                for (fn_info.param_types.get(ip)) |param_ty_index| {
                    const param_ty = Type.fromInterned(param_ty_index);
                    if (!param_ty.hasRuntimeBitsIgnoreComptime(mod)) continue;

                    const param_type_id = try self.resolveType(param_ty, .direct);
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
                self.current_block_label = root_block_id;

                const main_body = self.air.getMainBody();
                switch (self.control_flow) {
                    .structured => {
                        _ = try self.genStructuredBody(.selection, main_body);
                        // We always expect paths to here to end, but we still need the block
                        // to act as a dummy merge block.
                        try self.func.body.emit(self.spv.gpa, .OpUnreachable, {});
                    },
                    .unstructured => {
                        try self.genBody(main_body);
                    },
                }
                try self.func.body.emit(self.spv.gpa, .OpFunctionEnd, {});
                // Append the actual code into the functions section.
                try self.spv.addFunction(spv_decl_index, self.func);

                const fqn = try decl.fullyQualifiedName(self.module);
                try self.spv.debugName(result_id, fqn.toSlice(ip));

                // Temporarily generate a test kernel declaration if this is a test function.
                if (self.module.test_functions.contains(self.decl_index)) {
                    try self.generateTestEntryPoint(fqn.toSlice(ip), spv_decl_index);
                }
            },
            .global => {
                const maybe_init_val: ?Value = blk: {
                    if (decl.val.getVariable(mod)) |payload| {
                        if (payload.is_extern) break :blk null;
                        break :blk Value.fromInterned(payload.init);
                    }
                    break :blk decl.val;
                };
                assert(maybe_init_val == null); // TODO

                const final_storage_class = self.spvStorageClass(decl.@"addrspace");
                assert(final_storage_class != .Generic); // These should be instance globals

                const ptr_ty_id = try self.ptrType(decl.typeOf(mod), final_storage_class);

                try self.spv.sections.types_globals_constants.emit(self.spv.gpa, .OpVariable, .{
                    .id_result_type = ptr_ty_id,
                    .id_result = result_id,
                    .storage_class = final_storage_class,
                });

                const fqn = try decl.fullyQualifiedName(self.module);
                try self.spv.debugName(result_id, fqn.toSlice(ip));
                try self.spv.declareDeclDeps(spv_decl_index, &.{});
            },
            .invocation_global => {
                const maybe_init_val: ?Value = blk: {
                    if (decl.val.getVariable(mod)) |payload| {
                        if (payload.is_extern) break :blk null;
                        break :blk Value.fromInterned(payload.init);
                    }
                    break :blk decl.val;
                };

                try self.spv.declareDeclDeps(spv_decl_index, &.{});

                const ptr_ty_id = try self.ptrType(decl.typeOf(mod), .Function);

                if (maybe_init_val) |init_val| {
                    // TODO: Combine with resolveAnonDecl?
                    const initializer_proto_ty_id = try self.functionType(Type.void, &.{});

                    const initializer_id = self.spv.allocId();
                    try self.func.prologue.emit(self.spv.gpa, .OpFunction, .{
                        .id_result_type = try self.resolveType(Type.void, .direct),
                        .id_result = initializer_id,
                        .function_control = .{},
                        .function_type = initializer_proto_ty_id,
                    });

                    const root_block_id = self.spv.allocId();
                    try self.func.prologue.emit(self.spv.gpa, .OpLabel, .{
                        .id_result = root_block_id,
                    });
                    self.current_block_label = root_block_id;

                    const val_id = try self.constant(decl.typeOf(mod), init_val, .indirect);
                    try self.func.body.emit(self.spv.gpa, .OpStore, .{
                        .pointer = result_id,
                        .object = val_id,
                    });

                    try self.func.body.emit(self.spv.gpa, .OpReturn, {});
                    try self.func.body.emit(self.spv.gpa, .OpFunctionEnd, {});
                    try self.spv.addFunction(spv_decl_index, self.func);

                    const fqn = try decl.fullyQualifiedName(self.module);
                    try self.spv.debugNameFmt(initializer_id, "initializer of {}", .{fqn.fmt(ip)});

                    try self.spv.sections.types_globals_constants.emit(self.spv.gpa, .OpExtInst, .{
                        .id_result_type = ptr_ty_id,
                        .id_result = result_id,
                        .set = try self.spv.importInstructionSet(.zig),
                        .instruction = .{ .inst = 0 }, // TODO: Put this definition somewhere...
                        .id_ref_4 = &.{initializer_id},
                    });
                } else {
                    try self.spv.sections.types_globals_constants.emit(self.spv.gpa, .OpExtInst, .{
                        .id_result_type = ptr_ty_id,
                        .id_result = result_id,
                        .set = try self.spv.importInstructionSet(.zig),
                        .instruction = .{ .inst = 0 }, // TODO: Put this definition somewhere...
                        .id_ref_4 = &.{},
                    });
                }
            },
        }
    }

    fn intFromBool(self: *DeclGen, ty: Type, condition_id: IdRef) !IdRef {
        const zero_id = try self.constInt(ty, 0, .direct);
        const one_id = try self.constInt(ty, 1, .direct);
        const result_id = self.spv.allocId();
        try self.func.body.emit(self.spv.gpa, .OpSelect, .{
            .id_result_type = try self.resolveType(ty, .direct),
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
                const result_id = self.spv.allocId();
                try self.func.body.emit(self.spv.gpa, .OpINotEqual, .{
                    .id_result_type = try self.resolveType(Type.bool, .direct),
                    .id_result = result_id,
                    .operand_1 = operand_id,
                    .operand_2 = try self.constBool(false, .indirect),
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
            .Bool => try self.intFromBool(Type.u1, operand_id),
            else => operand_id,
        };
    }

    fn extractField(self: *DeclGen, result_ty: Type, object: IdRef, field: u32) !IdRef {
        const result_ty_id = try self.resolveType(result_ty, .indirect);
        const result_id = self.spv.allocId();
        const indexes = [_]u32{field};
        try self.func.body.emit(self.spv.gpa, .OpCompositeExtract, .{
            .id_result_type = result_ty_id,
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
        const indirect_value_ty_id = try self.resolveType(value_ty, .indirect);
        const result_id = self.spv.allocId();
        const access = spec.MemoryAccess.Extended{
            .Volatile = options.is_volatile,
        };
        try self.func.body.emit(self.spv.gpa, .OpLoad, .{
            .id_result_type = indirect_value_ty_id,
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
        if (self.liveness.isUnused(inst) and !self.air.mustLower(inst, ip))
            return;

        const air_tags = self.air.instructions.items(.tag);
        const maybe_result_id: ?IdRef = switch (air_tags[@intFromEnum(inst)]) {
            // zig fmt: off
            .add, .add_wrap, .add_optimized => try self.airArithOp(inst, .OpFAdd, .OpIAdd, .OpIAdd),
            .sub, .sub_wrap, .sub_optimized => try self.airArithOp(inst, .OpFSub, .OpISub, .OpISub),
            .mul, .mul_wrap, .mul_optimized => try self.airArithOp(inst, .OpFMul, .OpIMul, .OpIMul),


            .abs => try self.airAbs(inst),
            .floor => try self.airFloor(inst),

            .div_floor => try self.airDivFloor(inst),

            .div_float,
            .div_float_optimized,
            .div_trunc,
            .div_trunc_optimized => try self.airArithOp(inst, .OpFDiv, .OpSDiv, .OpUDiv),
            .rem, .rem_optimized => try self.airArithOp(inst, .OpFRem, .OpSRem, .OpSRem),
            .mod, .mod_optimized => try self.airArithOp(inst, .OpFMod, .OpSMod, .OpSMod),


            .add_with_overflow => try self.airAddSubOverflow(inst, .OpIAdd, .OpULessThan, .OpSLessThan),
            .sub_with_overflow => try self.airAddSubOverflow(inst, .OpISub, .OpUGreaterThan, .OpSGreaterThan),
            .mul_with_overflow => try self.airMulOverflow(inst),
            .shl_with_overflow => try self.airShlOverflow(inst),

            .mul_add => try self.airMulAdd(inst),

            .ctz => try self.airClzCtz(inst, .ctz),
            .clz => try self.airClzCtz(inst, .clz),

            .splat => try self.airSplat(inst),
            .reduce, .reduce_optimized => try self.airReduce(inst),
            .shuffle                   => try self.airShuffle(inst),

            .ptr_add => try self.airPtrAdd(inst),
            .ptr_sub => try self.airPtrSub(inst),

            .bit_and  => try self.airBinOpSimple(inst, .OpBitwiseAnd),
            .bit_or   => try self.airBinOpSimple(inst, .OpBitwiseOr),
            .xor      => try self.airBinOpSimple(inst, .OpBitwiseXor),
            .bool_and => try self.airBinOpSimple(inst, .OpLogicalAnd),
            .bool_or  => try self.airBinOpSimple(inst, .OpLogicalOr),

            .shl, .shl_exact => try self.airShift(inst, .OpShiftLeftLogical, .OpShiftLeftLogical),
            .shr, .shr_exact => try self.airShift(inst, .OpShiftRightLogical, .OpShiftRightArithmetic),

            .min => try self.airMinMax(inst, .lt),
            .max => try self.airMinMax(inst, .gt),

            .bitcast         => try self.airBitCast(inst),
            .intcast, .trunc => try self.airIntCast(inst),
            .int_from_ptr    => try self.airIntFromPtr(inst),
            .float_from_int  => try self.airFloatFromInt(inst),
            .int_from_float  => try self.airIntFromFloat(inst),
            .int_from_bool   => try self.airIntFromBool(inst),
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

            .vector_store_elem  => return self.airVectorStoreElem(inst),

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
            .ret_safe       => return self.airRet(inst), // TODO
            .ret_load       => return self.airRetLoad(inst),
            .@"try"         => try self.airTry(inst),
            .switch_br      => return self.airSwitchBr(inst),
            .unreach, .trap => return self.airUnreach(),

            .dbg_stmt                  => return self.airDbgStmt(inst),
            .dbg_inline_block          => try self.airDbgInlineBlock(inst),
            .dbg_var_ptr, .dbg_var_val => return self.airDbgVar(inst),

            .unwrap_errunion_err => try self.airErrUnionErr(inst),
            .unwrap_errunion_payload => try self.airErrUnionPayload(inst),
            .wrap_errunion_err => try self.airWrapErrUnionErr(inst),
            .wrap_errunion_payload => try self.airWrapErrUnionPayload(inst),

            .is_null         => try self.airIsNull(inst, false, .is_null),
            .is_non_null     => try self.airIsNull(inst, false, .is_non_null),
            .is_null_ptr     => try self.airIsNull(inst, true, .is_null),
            .is_non_null_ptr => try self.airIsNull(inst, true, .is_non_null),
            .is_err          => try self.airIsErr(inst, .is_err),
            .is_non_err      => try self.airIsErr(inst, .is_non_err),

            .optional_payload     => try self.airUnwrapOptional(inst),
            .optional_payload_ptr => try self.airUnwrapOptionalPtr(inst),
            .wrap_optional        => try self.airWrapOptional(inst),

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
        var wip = try self.elementWise(ty, false);
        defer wip.deinit();
        for (0..wip.results.len) |i| {
            try self.func.body.emit(self.spv.gpa, opcode, .{
                .id_result_type = wip.ty_id,
                .id_result = wip.allocId(i),
                .operand_1 = try wip.elementAt(ty, lhs_id, i),
                .operand_2 = try wip.elementAt(ty, rhs_id, i),
            });
        }
        return try wip.finalize();
    }

    fn airBinOpSimple(self: *DeclGen, inst: Air.Inst.Index, comptime opcode: Opcode) !?IdRef {
        const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
        const lhs_id = try self.resolve(bin_op.lhs);
        const rhs_id = try self.resolve(bin_op.rhs);
        const ty = self.typeOf(bin_op.lhs);

        return try self.binOpSimple(ty, lhs_id, rhs_id, opcode);
    }

    fn airShift(self: *DeclGen, inst: Air.Inst.Index, comptime unsigned: Opcode, comptime signed: Opcode) !?IdRef {
        const mod = self.module;
        const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
        const lhs_id = try self.resolve(bin_op.lhs);
        const rhs_id = try self.resolve(bin_op.rhs);

        const result_ty = self.typeOfIndex(inst);
        const shift_ty = self.typeOf(bin_op.rhs);
        const scalar_result_ty_id = try self.resolveType(result_ty.scalarType(mod), .direct);
        const scalar_shift_ty_id = try self.resolveType(shift_ty.scalarType(mod), .direct);

        const info = self.arithmeticTypeInfo(result_ty);
        switch (info.class) {
            .composite_integer => return self.todo("shift ops for composite integers", .{}),
            .integer, .strange_integer => {},
            .float, .bool => unreachable,
        }

        var wip = try self.elementWise(result_ty, false);
        defer wip.deinit();
        for (wip.results, 0..) |*result_id, i| {
            const lhs_elem_id = try wip.elementAt(result_ty, lhs_id, i);
            const rhs_elem_id = try wip.elementAt(shift_ty, rhs_id, i);

            // Sometimes Zig doesn't make both of the arguments the same types here. SPIR-V expects that,
            // so just manually upcast it if required.
            const shift_id = if (scalar_shift_ty_id != scalar_result_ty_id) blk: {
                const shift_id = self.spv.allocId();
                try self.func.body.emit(self.spv.gpa, .OpUConvert, .{
                    .id_result_type = wip.ty_id,
                    .id_result = shift_id,
                    .unsigned_value = rhs_elem_id,
                });
                break :blk shift_id;
            } else rhs_elem_id;

            const value_id = self.spv.allocId();
            const args = .{
                .id_result_type = wip.ty_id,
                .id_result = value_id,
                .base = lhs_elem_id,
                .shift = shift_id,
            };

            if (result_ty.isSignedInt(mod)) {
                try self.func.body.emit(self.spv.gpa, signed, args);
            } else {
                try self.func.body.emit(self.spv.gpa, unsigned, args);
            }

            result_id.* = try self.normalize(wip.ty, value_id, info);
        }
        return try wip.finalize();
    }

    fn airMinMax(self: *DeclGen, inst: Air.Inst.Index, op: std.math.CompareOperator) !?IdRef {
        const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
        const lhs_id = try self.resolve(bin_op.lhs);
        const rhs_id = try self.resolve(bin_op.rhs);
        const result_ty = self.typeOfIndex(inst);

        return try self.minMax(result_ty, op, lhs_id, rhs_id);
    }

    fn minMax(self: *DeclGen, result_ty: Type, op: std.math.CompareOperator, lhs_id: IdRef, rhs_id: IdRef) !IdRef {
        const info = self.arithmeticTypeInfo(result_ty);
        const target = self.getTarget();

        const use_backup_codegen = target.os.tag == .opencl and info.class != .float;
        var wip = try self.elementWise(result_ty, use_backup_codegen);
        defer wip.deinit();

        for (wip.results, 0..) |*result_id, i| {
            const lhs_elem_id = try wip.elementAt(result_ty, lhs_id, i);
            const rhs_elem_id = try wip.elementAt(result_ty, rhs_id, i);

            if (use_backup_codegen) {
                const cmp_id = try self.cmp(op, Type.bool, wip.ty, lhs_elem_id, rhs_elem_id);
                result_id.* = self.spv.allocId();
                try self.func.body.emit(self.spv.gpa, .OpSelect, .{
                    .id_result_type = wip.ty_id,
                    .id_result = result_id.*,
                    .condition = cmp_id,
                    .object_1 = lhs_elem_id,
                    .object_2 = rhs_elem_id,
                });
            } else {
                const ext_inst: Word = switch (target.os.tag) {
                    .opencl => switch (op) {
                        .lt => 28, // fmin
                        .gt => 27, // fmax
                        else => unreachable,
                    },
                    .vulkan => switch (info.class) {
                        .float => switch (op) {
                            .lt => 37, // FMin
                            .gt => 40, // FMax
                            else => unreachable,
                        },
                        .integer, .strange_integer => switch (info.signedness) {
                            .signed => switch (op) {
                                .lt => 39, // SMin
                                .gt => 42, // SMax
                                else => unreachable,
                            },
                            .unsigned => switch (op) {
                                .lt => 38, // UMin
                                .gt => 41, // UMax
                                else => unreachable,
                            },
                        },
                        .composite_integer => unreachable, // TODO
                        .bool => unreachable,
                    },
                    else => unreachable,
                };
                const set_id = switch (target.os.tag) {
                    .opencl => try self.spv.importInstructionSet(.@"OpenCL.std"),
                    .vulkan => try self.spv.importInstructionSet(.@"GLSL.std.450"),
                    else => unreachable,
                };

                result_id.* = self.spv.allocId();
                try self.func.body.emit(self.spv.gpa, .OpExtInst, .{
                    .id_result_type = wip.ty_id,
                    .id_result = result_id.*,
                    .set = set_id,
                    .instruction = .{ .inst = ext_inst },
                    .id_ref_4 = &.{ lhs_elem_id, rhs_elem_id },
                });
            }
        }
        return wip.finalize();
    }

    /// This function normalizes values to a canonical representation
    /// after some arithmetic operation. This mostly consists of wrapping
    /// behavior for strange integers:
    /// - Unsigned integers are bitwise masked with a mask that only passes
    ///   the valid bits through.
    /// - Signed integers are also sign extended if they are negative.
    /// All other values are returned unmodified (this makes strange integer
    /// wrapping easier to use in generic operations).
    fn normalize(self: *DeclGen, ty: Type, value_id: IdRef, info: ArithmeticTypeInfo) !IdRef {
        switch (info.class) {
            .integer, .bool, .float => return value_id,
            .composite_integer => unreachable, // TODO
            .strange_integer => switch (info.signedness) {
                .unsigned => {
                    const mask_value = if (info.bits == 64) 0xFFFF_FFFF_FFFF_FFFF else (@as(u64, 1) << @as(u6, @intCast(info.bits))) - 1;
                    const result_id = self.spv.allocId();
                    const mask_id = try self.constInt(ty, mask_value, .direct);
                    try self.func.body.emit(self.spv.gpa, .OpBitwiseAnd, .{
                        .id_result_type = try self.resolveType(ty, .direct),
                        .id_result = result_id,
                        .operand_1 = value_id,
                        .operand_2 = mask_id,
                    });
                    return result_id;
                },
                .signed => {
                    // Shift left and right so that we can copy the sight bit that way.
                    const shift_amt_id = try self.constInt(ty, info.backing_bits - info.bits, .direct);
                    const left_id = self.spv.allocId();
                    try self.func.body.emit(self.spv.gpa, .OpShiftLeftLogical, .{
                        .id_result_type = try self.resolveType(ty, .direct),
                        .id_result = left_id,
                        .base = value_id,
                        .shift = shift_amt_id,
                    });
                    const right_id = self.spv.allocId();
                    try self.func.body.emit(self.spv.gpa, .OpShiftRightArithmetic, .{
                        .id_result_type = try self.resolveType(ty, .direct),
                        .id_result = right_id,
                        .base = left_id,
                        .shift = shift_amt_id,
                    });
                    return right_id;
                },
            },
        }
    }

    fn airDivFloor(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
        const lhs_id = try self.resolve(bin_op.lhs);
        const rhs_id = try self.resolve(bin_op.rhs);
        const ty = self.typeOfIndex(inst);
        const ty_id = try self.resolveType(ty, .direct);
        const info = self.arithmeticTypeInfo(ty);
        switch (info.class) {
            .composite_integer => unreachable, // TODO
            .integer, .strange_integer => {
                const zero_id = try self.constInt(ty, 0, .direct);
                const one_id = try self.constInt(ty, 1, .direct);

                // (a ^ b) > 0
                const bin_bitwise_id = try self.binOpSimple(ty, lhs_id, rhs_id, .OpBitwiseXor);
                const is_positive_id = try self.cmp(.gt, Type.bool, ty, bin_bitwise_id, zero_id);

                // a / b
                const positive_div_id = try self.arithOp(ty, lhs_id, rhs_id, .OpFDiv, .OpSDiv, .OpUDiv);

                // - (abs(a) + abs(b) - 1) / abs(b)
                const lhs_abs = try self.abs(ty, ty, lhs_id);
                const rhs_abs = try self.abs(ty, ty, rhs_id);
                const negative_div_lhs = try self.arithOp(
                    ty,
                    try self.arithOp(ty, lhs_abs, rhs_abs, .OpFAdd, .OpIAdd, .OpIAdd),
                    one_id,
                    .OpFSub,
                    .OpISub,
                    .OpISub,
                );
                const negative_div_id = try self.arithOp(ty, negative_div_lhs, rhs_abs, .OpFDiv, .OpSDiv, .OpUDiv);
                const negated_negative_div_id = self.spv.allocId();
                try self.func.body.emit(self.spv.gpa, .OpSNegate, .{
                    .id_result_type = ty_id,
                    .id_result = negated_negative_div_id,
                    .operand = negative_div_id,
                });

                const result_id = self.spv.allocId();
                try self.func.body.emit(self.spv.gpa, .OpSelect, .{
                    .id_result_type = ty_id,
                    .id_result = result_id,
                    .condition = is_positive_id,
                    .object_1 = positive_div_id,
                    .object_2 = negated_negative_div_id,
                });
                return result_id;
            },
            .float => {
                const div_id = try self.arithOp(ty, lhs_id, rhs_id, .OpFDiv, .OpSDiv, .OpUDiv);
                return try self.floor(ty, div_id);
            },
            .bool => unreachable,
        }
    }

    fn airFloor(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
        const operand_id = try self.resolve(un_op);
        const result_ty = self.typeOfIndex(inst);
        return try self.floor(result_ty, operand_id);
    }

    fn floor(self: *DeclGen, ty: Type, operand_id: IdRef) !IdRef {
        const target = self.getTarget();
        const ty_id = try self.resolveType(ty, .direct);
        const ext_inst: Word = switch (target.os.tag) {
            .opencl => 25,
            .vulkan => 8,
            else => unreachable,
        };
        const set_id = switch (target.os.tag) {
            .opencl => try self.spv.importInstructionSet(.@"OpenCL.std"),
            .vulkan => try self.spv.importInstructionSet(.@"GLSL.std.450"),
            else => unreachable,
        };

        const result_id = self.spv.allocId();
        try self.func.body.emit(self.spv.gpa, .OpExtInst, .{
            .id_result_type = ty_id,
            .id_result = result_id,
            .set = set_id,
            .instruction = .{ .inst = ext_inst },
            .id_ref_4 = &.{operand_id},
        });
        return result_id;
    }

    fn airArithOp(
        self: *DeclGen,
        inst: Air.Inst.Index,
        comptime fop: Opcode,
        comptime sop: Opcode,
        comptime uop: Opcode,
    ) !?IdRef {
        // LHS and RHS are guaranteed to have the same type, and AIR guarantees
        // the result to be the same as the LHS and RHS, which matches SPIR-V.
        const ty = self.typeOfIndex(inst);
        const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
        const lhs_id = try self.resolve(bin_op.lhs);
        const rhs_id = try self.resolve(bin_op.rhs);

        assert(self.typeOf(bin_op.lhs).eql(ty, self.module));
        assert(self.typeOf(bin_op.rhs).eql(ty, self.module));

        return try self.arithOp(ty, lhs_id, rhs_id, fop, sop, uop);
    }

    fn arithOp(
        self: *DeclGen,
        ty: Type,
        lhs_id: IdRef,
        rhs_id: IdRef,
        comptime fop: Opcode,
        comptime sop: Opcode,
        comptime uop: Opcode,
    ) !IdRef {
        // Binary operations are generally applicable to both scalar and vector operations
        // in SPIR-V, but int and float versions of operations require different opcodes.
        const info = self.arithmeticTypeInfo(ty);

        const opcode_index: usize = switch (info.class) {
            .composite_integer => {
                return self.todo("binary operations for composite integers", .{});
            },
            .integer, .strange_integer => switch (info.signedness) {
                .signed => 1,
                .unsigned => 2,
            },
            .float => 0,
            .bool => unreachable,
        };

        var wip = try self.elementWise(ty, false);
        defer wip.deinit();
        for (wip.results, 0..) |*result_id, i| {
            const lhs_elem_id = try wip.elementAt(ty, lhs_id, i);
            const rhs_elem_id = try wip.elementAt(ty, rhs_id, i);

            const value_id = self.spv.allocId();
            const operands = .{
                .id_result_type = wip.ty_id,
                .id_result = value_id,
                .operand_1 = lhs_elem_id,
                .operand_2 = rhs_elem_id,
            };

            switch (opcode_index) {
                0 => try self.func.body.emit(self.spv.gpa, fop, operands),
                1 => try self.func.body.emit(self.spv.gpa, sop, operands),
                2 => try self.func.body.emit(self.spv.gpa, uop, operands),
                else => unreachable,
            }

            // TODO: Trap on overflow? Probably going to be annoying.
            // TODO: Look into SPV_KHR_no_integer_wrap_decoration which provides NoSignedWrap/NoUnsignedWrap.
            result_id.* = try self.normalize(wip.ty, value_id, info);
        }

        return try wip.finalize();
    }

    fn airAbs(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
        const operand_id = try self.resolve(ty_op.operand);
        // Note: operand_ty may be signed, while ty is always unsigned!
        const operand_ty = self.typeOf(ty_op.operand);
        const result_ty = self.typeOfIndex(inst);
        return try self.abs(result_ty, operand_ty, operand_id);
    }

    fn abs(self: *DeclGen, result_ty: Type, operand_ty: Type, operand_id: IdRef) !IdRef {
        const target = self.getTarget();
        const operand_info = self.arithmeticTypeInfo(operand_ty);

        var wip = try self.elementWise(result_ty, false);
        defer wip.deinit();

        for (wip.results, 0..) |*result_id, i| {
            const elem_id = try wip.elementAt(operand_ty, operand_id, i);

            const ext_inst: Word = switch (target.os.tag) {
                .opencl => switch (operand_info.class) {
                    .float => 23, // fabs
                    .integer, .strange_integer => switch (operand_info.signedness) {
                        .signed => 141, // s_abs
                        .unsigned => 201, // u_abs
                    },
                    .composite_integer => unreachable, // TODO
                    .bool => unreachable,
                },
                .vulkan => switch (operand_info.class) {
                    .float => 4, // FAbs
                    .integer, .strange_integer => 5, // SAbs
                    .composite_integer => unreachable, // TODO
                    .bool => unreachable,
                },
                else => unreachable,
            };
            const set_id = switch (target.os.tag) {
                .opencl => try self.spv.importInstructionSet(.@"OpenCL.std"),
                .vulkan => try self.spv.importInstructionSet(.@"GLSL.std.450"),
                else => unreachable,
            };

            result_id.* = self.spv.allocId();
            try self.func.body.emit(self.spv.gpa, .OpExtInst, .{
                .id_result_type = wip.ty_id,
                .id_result = result_id.*,
                .set = set_id,
                .instruction = .{ .inst = ext_inst },
                .id_ref_4 = &.{elem_id},
            });
        }
        return try wip.finalize();
    }

    fn airAddSubOverflow(
        self: *DeclGen,
        inst: Air.Inst.Index,
        comptime add: Opcode,
        comptime ucmp: Opcode,
        comptime scmp: Opcode,
    ) !?IdRef {
        const mod = self.module;
        const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
        const extra = self.air.extraData(Air.Bin, ty_pl.payload).data;
        const lhs = try self.resolve(extra.lhs);
        const rhs = try self.resolve(extra.rhs);

        const result_ty = self.typeOfIndex(inst);
        const operand_ty = self.typeOf(extra.lhs);
        const ov_ty = result_ty.structFieldType(1, self.module);

        const bool_ty_id = try self.resolveType(Type.bool, .direct);
        const cmp_ty_id = if (self.isVector(operand_ty))
            // TODO: Resolving a vector type with .direct should return a SPIR-V vector
            try self.spv.vectorType(operand_ty.vectorLen(mod), try self.resolveType(Type.bool, .direct))
        else
            bool_ty_id;

        const info = self.arithmeticTypeInfo(operand_ty);
        switch (info.class) {
            .composite_integer => return self.todo("overflow ops for composite integers", .{}),
            .strange_integer, .integer => {},
            .float, .bool => unreachable,
        }

        var wip_result = try self.elementWise(operand_ty, false);
        defer wip_result.deinit();
        var wip_ov = try self.elementWise(ov_ty, false);
        defer wip_ov.deinit();
        for (wip_result.results, wip_ov.results, 0..) |*result_id, *ov_id, i| {
            const lhs_elem_id = try wip_result.elementAt(operand_ty, lhs, i);
            const rhs_elem_id = try wip_result.elementAt(operand_ty, rhs, i);

            // Normalize both so that we can properly check for overflow
            const value_id = self.spv.allocId();

            try self.func.body.emit(self.spv.gpa, add, .{
                .id_result_type = wip_result.ty_id,
                .id_result = value_id,
                .operand_1 = lhs_elem_id,
                .operand_2 = rhs_elem_id,
            });

            // Normalize the result so that the comparisons go well
            result_id.* = try self.normalize(wip_result.ty, value_id, info);

            const overflowed_id = switch (info.signedness) {
                .unsigned => blk: {
                    // Overflow happened if the result is smaller than either of the operands. It doesn't matter which.
                    // For subtraction the conditions need to be swapped.
                    const overflowed_id = self.spv.allocId();
                    try self.func.body.emit(self.spv.gpa, ucmp, .{
                        .id_result_type = cmp_ty_id,
                        .id_result = overflowed_id,
                        .operand_1 = result_id.*,
                        .operand_2 = lhs_elem_id,
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
                    const zero_id = try self.constInt(wip_result.ty, 0, .direct);
                    try self.func.body.emit(self.spv.gpa, .OpSLessThan, .{
                        .id_result_type = cmp_ty_id,
                        .id_result = rhs_lt_zero_id,
                        .operand_1 = rhs_elem_id,
                        .operand_2 = zero_id,
                    });

                    const value_gt_lhs_id = self.spv.allocId();
                    try self.func.body.emit(self.spv.gpa, scmp, .{
                        .id_result_type = cmp_ty_id,
                        .id_result = value_gt_lhs_id,
                        .operand_1 = lhs_elem_id,
                        .operand_2 = result_id.*,
                    });

                    const overflowed_id = self.spv.allocId();
                    try self.func.body.emit(self.spv.gpa, .OpLogicalEqual, .{
                        .id_result_type = cmp_ty_id,
                        .id_result = overflowed_id,
                        .operand_1 = rhs_lt_zero_id,
                        .operand_2 = value_gt_lhs_id,
                    });
                    break :blk overflowed_id;
                },
            };

            ov_id.* = try self.intFromBool(wip_ov.ty, overflowed_id);
        }

        return try self.constructStruct(
            result_ty,
            &.{ operand_ty, ov_ty },
            &.{ try wip_result.finalize(), try wip_ov.finalize() },
        );
    }

    fn airMulOverflow(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
        const extra = self.air.extraData(Air.Bin, ty_pl.payload).data;
        const lhs = try self.resolve(extra.lhs);
        const rhs = try self.resolve(extra.rhs);

        const result_ty = self.typeOfIndex(inst);
        const operand_ty = self.typeOf(extra.lhs);
        const ov_ty = result_ty.structFieldType(1, self.module);

        const info = self.arithmeticTypeInfo(operand_ty);
        switch (info.class) {
            .composite_integer => return self.todo("overflow ops for composite integers", .{}),
            .strange_integer, .integer => {},
            .float, .bool => unreachable,
        }

        var wip_result = try self.elementWise(operand_ty, true);
        defer wip_result.deinit();
        var wip_ov = try self.elementWise(ov_ty, true);
        defer wip_ov.deinit();

        const zero_id = try self.constInt(wip_result.ty, 0, .direct);
        const zero_ov_id = try self.constInt(wip_ov.ty, 0, .direct);
        const one_ov_id = try self.constInt(wip_ov.ty, 1, .direct);

        for (wip_result.results, wip_ov.results, 0..) |*result_id, *ov_id, i| {
            const lhs_elem_id = try wip_result.elementAt(operand_ty, lhs, i);
            const rhs_elem_id = try wip_result.elementAt(operand_ty, rhs, i);

            result_id.* = try self.arithOp(wip_result.ty, lhs_elem_id, rhs_elem_id, .OpFMul, .OpIMul, .OpIMul);

            // (a != 0) and (x / a != b)
            const not_zero_id = try self.cmp(.neq, Type.bool, wip_result.ty, lhs_elem_id, zero_id);
            const res_rhs_id = try self.arithOp(wip_result.ty, result_id.*, lhs_elem_id, .OpFDiv, .OpSDiv, .OpUDiv);
            const res_rhs_not_rhs_id = try self.cmp(.neq, Type.bool, wip_result.ty, res_rhs_id, rhs_elem_id);
            const cond_id = try self.binOpSimple(Type.bool, not_zero_id, res_rhs_not_rhs_id, .OpLogicalAnd);

            ov_id.* = self.spv.allocId();
            try self.func.body.emit(self.spv.gpa, .OpSelect, .{
                .id_result_type = wip_ov.ty_id,
                .id_result = ov_id.*,
                .condition = cond_id,
                .object_1 = one_ov_id,
                .object_2 = zero_ov_id,
            });
        }

        return try self.constructStruct(
            result_ty,
            &.{ operand_ty, ov_ty },
            &.{ try wip_result.finalize(), try wip_ov.finalize() },
        );
    }

    fn airShlOverflow(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        const mod = self.module;
        const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
        const extra = self.air.extraData(Air.Bin, ty_pl.payload).data;
        const lhs = try self.resolve(extra.lhs);
        const rhs = try self.resolve(extra.rhs);

        const result_ty = self.typeOfIndex(inst);
        const operand_ty = self.typeOf(extra.lhs);
        const shift_ty = self.typeOf(extra.rhs);
        const scalar_shift_ty_id = try self.resolveType(shift_ty.scalarType(mod), .direct);
        const scalar_operand_ty_id = try self.resolveType(operand_ty.scalarType(mod), .direct);

        const ov_ty = result_ty.structFieldType(1, self.module);

        const bool_ty_id = try self.resolveType(Type.bool, .direct);
        const cmp_ty_id = if (self.isVector(operand_ty))
            // TODO: Resolving a vector type with .direct should return a SPIR-V vector
            try self.spv.vectorType(operand_ty.vectorLen(mod), try self.resolveType(Type.bool, .direct))
        else
            bool_ty_id;

        const info = self.arithmeticTypeInfo(operand_ty);
        switch (info.class) {
            .composite_integer => return self.todo("overflow shift for composite integers", .{}),
            .integer, .strange_integer => {},
            .float, .bool => unreachable,
        }

        var wip_result = try self.elementWise(operand_ty, false);
        defer wip_result.deinit();
        var wip_ov = try self.elementWise(ov_ty, false);
        defer wip_ov.deinit();
        for (wip_result.results, wip_ov.results, 0..) |*result_id, *ov_id, i| {
            const lhs_elem_id = try wip_result.elementAt(operand_ty, lhs, i);
            const rhs_elem_id = try wip_result.elementAt(shift_ty, rhs, i);

            // Sometimes Zig doesn't make both of the arguments the same types here. SPIR-V expects that,
            // so just manually upcast it if required.
            const shift_id = if (scalar_shift_ty_id != scalar_operand_ty_id) blk: {
                const shift_id = self.spv.allocId();
                try self.func.body.emit(self.spv.gpa, .OpUConvert, .{
                    .id_result_type = wip_result.ty_id,
                    .id_result = shift_id,
                    .unsigned_value = rhs_elem_id,
                });
                break :blk shift_id;
            } else rhs_elem_id;

            const value_id = self.spv.allocId();
            try self.func.body.emit(self.spv.gpa, .OpShiftLeftLogical, .{
                .id_result_type = wip_result.ty_id,
                .id_result = value_id,
                .base = lhs_elem_id,
                .shift = shift_id,
            });
            result_id.* = try self.normalize(wip_result.ty, value_id, info);

            const right_shift_id = self.spv.allocId();
            switch (info.signedness) {
                .signed => {
                    try self.func.body.emit(self.spv.gpa, .OpShiftRightArithmetic, .{
                        .id_result_type = wip_result.ty_id,
                        .id_result = right_shift_id,
                        .base = result_id.*,
                        .shift = shift_id,
                    });
                },
                .unsigned => {
                    try self.func.body.emit(self.spv.gpa, .OpShiftRightLogical, .{
                        .id_result_type = wip_result.ty_id,
                        .id_result = right_shift_id,
                        .base = result_id.*,
                        .shift = shift_id,
                    });
                },
            }

            const overflowed_id = self.spv.allocId();
            try self.func.body.emit(self.spv.gpa, .OpINotEqual, .{
                .id_result_type = cmp_ty_id,
                .id_result = overflowed_id,
                .operand_1 = lhs_elem_id,
                .operand_2 = right_shift_id,
            });

            ov_id.* = try self.intFromBool(wip_ov.ty, overflowed_id);
        }

        return try self.constructStruct(
            result_ty,
            &.{ operand_ty, ov_ty },
            &.{ try wip_result.finalize(), try wip_ov.finalize() },
        );
    }

    fn airMulAdd(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        const pl_op = self.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
        const extra = self.air.extraData(Air.Bin, pl_op.payload).data;

        const mulend1 = try self.resolve(extra.lhs);
        const mulend2 = try self.resolve(extra.rhs);
        const addend = try self.resolve(pl_op.operand);

        const ty = self.typeOfIndex(inst);

        const info = self.arithmeticTypeInfo(ty);
        assert(info.class == .float); // .mul_add is only emitted for floats

        var wip = try self.elementWise(ty, false);
        defer wip.deinit();
        for (0..wip.results.len) |i| {
            const mul_result = self.spv.allocId();
            try self.func.body.emit(self.spv.gpa, .OpFMul, .{
                .id_result_type = wip.ty_id,
                .id_result = mul_result,
                .operand_1 = try wip.elementAt(ty, mulend1, i),
                .operand_2 = try wip.elementAt(ty, mulend2, i),
            });

            try self.func.body.emit(self.spv.gpa, .OpFAdd, .{
                .id_result_type = wip.ty_id,
                .id_result = wip.allocId(i),
                .operand_1 = mul_result,
                .operand_2 = try wip.elementAt(ty, addend, i),
            });
        }
        return try wip.finalize();
    }

    fn airClzCtz(self: *DeclGen, inst: Air.Inst.Index, op: enum { clz, ctz }) !?IdRef {
        if (self.liveness.isUnused(inst)) return null;

        const mod = self.module;
        const target = self.getTarget();
        const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
        const result_ty = self.typeOfIndex(inst);
        const operand_ty = self.typeOf(ty_op.operand);
        const operand = try self.resolve(ty_op.operand);

        const info = self.arithmeticTypeInfo(operand_ty);
        switch (info.class) {
            .composite_integer => unreachable, // TODO
            .integer, .strange_integer => {},
            .float, .bool => unreachable,
        }

        var wip = try self.elementWise(result_ty, false);
        defer wip.deinit();

        const elem_ty = if (wip.is_array) operand_ty.scalarType(mod) else operand_ty;
        const elem_ty_id = try self.resolveType(elem_ty, .direct);

        for (wip.results, 0..) |*result_id, i| {
            const elem = try wip.elementAt(operand_ty, operand, i);

            switch (target.os.tag) {
                .opencl => {
                    const set = try self.spv.importInstructionSet(.@"OpenCL.std");
                    const ext_inst: u32 = switch (op) {
                        .clz => 151, // clz
                        .ctz => 152, // ctz
                    };

                    // Note: result of OpenCL ctz/clz returns operand_ty, and we want result_ty.
                    // result_ty is always large enough to hold the result, so we might have to down
                    // cast it.
                    const tmp = self.spv.allocId();
                    try self.func.body.emit(self.spv.gpa, .OpExtInst, .{
                        .id_result_type = elem_ty_id,
                        .id_result = tmp,
                        .set = set,
                        .instruction = .{ .inst = ext_inst },
                        .id_ref_4 = &.{elem},
                    });

                    // TODO: Comparison should be removed..
                    // Its valid because SpvModule caches numeric types
                    if (wip.ty_id == elem_ty_id) {
                        result_id.* = tmp;
                        continue;
                    }

                    result_id.* = self.spv.allocId();
                    if (result_ty.scalarType(mod).isSignedInt(mod)) {
                        assert(elem_ty.scalarType(mod).isSignedInt(mod));
                        try self.func.body.emit(self.spv.gpa, .OpSConvert, .{
                            .id_result_type = wip.ty_id,
                            .id_result = result_id.*,
                            .signed_value = tmp,
                        });
                    } else {
                        assert(elem_ty.scalarType(mod).isUnsignedInt(mod));
                        try self.func.body.emit(self.spv.gpa, .OpUConvert, .{
                            .id_result_type = wip.ty_id,
                            .id_result = result_id.*,
                            .unsigned_value = tmp,
                        });
                    }
                },
                .vulkan => unreachable, // TODO
                else => unreachable,
            }
        }

        return try wip.finalize();
    }

    fn airSplat(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
        const operand_id = try self.resolve(ty_op.operand);
        const result_ty = self.typeOfIndex(inst);
        var wip = try self.elementWise(result_ty, true);
        defer wip.deinit();
        @memset(wip.results, operand_id);
        return try wip.finalize();
    }

    fn airReduce(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        const mod = self.module;
        const reduce = self.air.instructions.items(.data)[@intFromEnum(inst)].reduce;
        const operand = try self.resolve(reduce.operand);
        const operand_ty = self.typeOf(reduce.operand);
        const scalar_ty = operand_ty.scalarType(mod);
        const scalar_ty_id = try self.resolveType(scalar_ty, .direct);

        const info = self.arithmeticTypeInfo(operand_ty);

        var result_id = try self.extractField(scalar_ty, operand, 0);
        const len = operand_ty.vectorLen(mod);

        switch (reduce.operation) {
            .Min, .Max => |op| {
                const cmp_op: std.math.CompareOperator = if (op == .Max) .gt else .lt;
                for (1..len) |i| {
                    const lhs = result_id;
                    const rhs = try self.extractField(scalar_ty, operand, @intCast(i));
                    result_id = try self.minMax(scalar_ty, cmp_op, lhs, rhs);
                }

                return result_id;
            },
            else => {},
        }

        const opcode: Opcode = switch (info.class) {
            .bool => switch (reduce.operation) {
                .And => .OpLogicalAnd,
                .Or => .OpLogicalOr,
                .Xor => .OpLogicalNotEqual,
                else => unreachable,
            },
            .strange_integer, .integer => switch (reduce.operation) {
                .And => .OpBitwiseAnd,
                .Or => .OpBitwiseOr,
                .Xor => .OpBitwiseXor,
                .Add => .OpIAdd,
                .Mul => .OpIMul,
                else => unreachable,
            },
            .float => switch (reduce.operation) {
                .Add => .OpFAdd,
                .Mul => .OpFMul,
                else => unreachable,
            },
            .composite_integer => unreachable, // TODO
        };

        for (1..len) |i| {
            const lhs = result_id;
            const rhs = try self.extractField(scalar_ty, operand, @intCast(i));
            result_id = self.spv.allocId();

            try self.func.body.emitRaw(self.spv.gpa, opcode, 4);
            self.func.body.writeOperand(spec.IdResultType, scalar_ty_id);
            self.func.body.writeOperand(spec.IdResult, result_id);
            self.func.body.writeOperand(spec.IdResultType, lhs);
            self.func.body.writeOperand(spec.IdResultType, rhs);
        }

        return result_id;
    }

    fn airShuffle(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        const mod = self.module;
        const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
        const extra = self.air.extraData(Air.Shuffle, ty_pl.payload).data;
        const a = try self.resolve(extra.a);
        const b = try self.resolve(extra.b);
        const mask = Value.fromInterned(extra.mask);

        const ty = self.typeOfIndex(inst);

        var wip = try self.elementWise(ty, true);
        defer wip.deinit();
        for (wip.results, 0..) |*result_id, i| {
            const elem = try mask.elemValue(mod, i);
            if (elem.isUndef(mod)) {
                result_id.* = try self.spv.constUndef(wip.ty_id);
                continue;
            }

            const index = elem.toSignedInt(mod);
            if (index >= 0) {
                result_id.* = try self.extractField(wip.ty, a, @intCast(index));
            } else {
                result_id.* = try self.extractField(wip.ty, b, @intCast(~index));
            }
        }
        return try wip.finalize();
    }

    fn indicesToIds(self: *DeclGen, indices: []const u32) ![]IdRef {
        const ids = try self.gpa.alloc(IdRef, indices.len);
        errdefer self.gpa.free(ids);
        for (indices, ids) |index, *id| {
            id.* = try self.constInt(Type.u32, index, .direct);
        }

        return ids;
    }

    fn accessChainId(
        self: *DeclGen,
        result_ty_id: IdRef,
        base: IdRef,
        indices: []const IdRef,
    ) !IdRef {
        const result_id = self.spv.allocId();
        try self.func.body.emit(self.spv.gpa, .OpInBoundsAccessChain, .{
            .id_result_type = result_ty_id,
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
        result_ty_id: IdRef,
        base: IdRef,
        indices: []const u32,
    ) !IdRef {
        const ids = try self.indicesToIds(indices);
        defer self.gpa.free(ids);
        return try self.accessChainId(result_ty_id, base, ids);
    }

    fn ptrAccessChain(
        self: *DeclGen,
        result_ty_id: IdRef,
        base: IdRef,
        element: IdRef,
        indices: []const u32,
    ) !IdRef {
        const ids = try self.indicesToIds(indices);
        defer self.gpa.free(ids);

        const result_id = self.spv.allocId();
        try self.func.body.emit(self.spv.gpa, .OpInBoundsPtrAccessChain, .{
            .id_result_type = result_ty_id,
            .id_result = result_id,
            .base = base,
            .element = element,
            .indexes = ids,
        });
        return result_id;
    }

    fn ptrAdd(self: *DeclGen, result_ty: Type, ptr_ty: Type, ptr_id: IdRef, offset_id: IdRef) !IdRef {
        const mod = self.module;
        const result_ty_id = try self.resolveType(result_ty, .direct);

        switch (ptr_ty.ptrSize(mod)) {
            .One => {
                // Pointer to array
                // TODO: Is this correct?
                return try self.accessChainId(result_ty_id, ptr_id, &.{offset_id});
            },
            .C, .Many => {
                return try self.ptrAccessChain(result_ty_id, ptr_id, offset_id, &.{});
            },
            .Slice => {
                // TODO: This is probably incorrect. A slice should be returned here, though this is what llvm does.
                const slice_ptr_id = try self.extractField(result_ty, ptr_id, 0);
                return try self.ptrAccessChain(result_ty_id, slice_ptr_id, offset_id, &.{});
            },
        }
    }

    fn airPtrAdd(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
        const bin_op = self.air.extraData(Air.Bin, ty_pl.payload).data;
        const ptr_id = try self.resolve(bin_op.lhs);
        const offset_id = try self.resolve(bin_op.rhs);
        const ptr_ty = self.typeOf(bin_op.lhs);
        const result_ty = self.typeOfIndex(inst);

        return try self.ptrAdd(result_ty, ptr_ty, ptr_id, offset_id);
    }

    fn airPtrSub(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
        const bin_op = self.air.extraData(Air.Bin, ty_pl.payload).data;
        const ptr_id = try self.resolve(bin_op.lhs);
        const ptr_ty = self.typeOf(bin_op.lhs);
        const offset_id = try self.resolve(bin_op.rhs);
        const offset_ty = self.typeOf(bin_op.rhs);
        const offset_ty_id = try self.resolveType(offset_ty, .direct);
        const result_ty = self.typeOfIndex(inst);

        const negative_offset_id = self.spv.allocId();
        try self.func.body.emit(self.spv.gpa, .OpSNegate, .{
            .id_result_type = offset_ty_id,
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
        const bool_ty_id = try self.resolveType(Type.bool, .direct);
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

                const usize_ty_id = try self.resolveType(Type.usize, .direct);

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

                if (!payload_ty.hasRuntimeBitsIgnoreComptime(mod)) {
                    return try self.cmp(op, Type.bool, Type.bool, lhs_valid_id, rhs_valid_id);
                }

                // a = lhs_valid
                // b = rhs_valid
                // c = lhs_pl == rhs_pl
                //
                // For op == .eq we have:
                //   a == b && a -> c
                // = a == b && (!a || c)
                //
                // For op == .neq we have
                //   a == b && a -> c
                // = !(a == b && a -> c)
                // = a != b || !(a -> c
                // = a != b || !(!a || c)
                // = a != b || a && !c

                const lhs_pl_id = try self.extractField(payload_ty, lhs_id, 0);
                const rhs_pl_id = try self.extractField(payload_ty, rhs_id, 0);

                switch (op) {
                    .eq => {
                        const valid_eq_id = try self.cmp(.eq, Type.bool, Type.bool, lhs_valid_id, rhs_valid_id);
                        const pl_eq_id = try self.cmp(op, Type.bool, payload_ty, lhs_pl_id, rhs_pl_id);
                        const lhs_not_valid_id = self.spv.allocId();
                        try self.func.body.emit(self.spv.gpa, .OpLogicalNot, .{
                            .id_result_type = bool_ty_id,
                            .id_result = lhs_not_valid_id,
                            .operand = lhs_valid_id,
                        });
                        const impl_id = self.spv.allocId();
                        try self.func.body.emit(self.spv.gpa, .OpLogicalOr, .{
                            .id_result_type = bool_ty_id,
                            .id_result = impl_id,
                            .operand_1 = lhs_not_valid_id,
                            .operand_2 = pl_eq_id,
                        });
                        const result_id = self.spv.allocId();
                        try self.func.body.emit(self.spv.gpa, .OpLogicalAnd, .{
                            .id_result_type = bool_ty_id,
                            .id_result = result_id,
                            .operand_1 = valid_eq_id,
                            .operand_2 = impl_id,
                        });
                        return result_id;
                    },
                    .neq => {
                        const valid_neq_id = try self.cmp(.neq, Type.bool, Type.bool, lhs_valid_id, rhs_valid_id);
                        const pl_neq_id = try self.cmp(op, Type.bool, payload_ty, lhs_pl_id, rhs_pl_id);

                        const impl_id = self.spv.allocId();
                        try self.func.body.emit(self.spv.gpa, .OpLogicalAnd, .{
                            .id_result_type = bool_ty_id,
                            .id_result = impl_id,
                            .operand_1 = lhs_valid_id,
                            .operand_2 = pl_neq_id,
                        });
                        const result_id = self.spv.allocId();
                        try self.func.body.emit(self.spv.gpa, .OpLogicalOr, .{
                            .id_result_type = bool_ty_id,
                            .id_result = result_id,
                            .operand_1 = valid_neq_id,
                            .operand_2 = impl_id,
                        });
                        return result_id;
                    },
                    else => unreachable,
                }
            },
            .Vector => {
                var wip = try self.elementWise(result_ty, true);
                defer wip.deinit();
                const scalar_ty = ty.scalarType(mod);
                for (wip.results, 0..) |*result_id, i| {
                    const lhs_elem_id = try wip.elementAt(ty, lhs_id, i);
                    const rhs_elem_id = try wip.elementAt(ty, rhs_id, i);
                    result_id.* = try self.cmp(op, Type.bool, scalar_ty, lhs_elem_id, rhs_elem_id);
                }
                return wip.finalize();
            },
            else => unreachable,
        };

        const opcode: Opcode = opcode: {
            const info = self.arithmeticTypeInfo(op_ty);
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
                .integer, .strange_integer => info.signedness,
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
        const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
        const lhs_id = try self.resolve(bin_op.lhs);
        const rhs_id = try self.resolve(bin_op.rhs);
        const ty = self.typeOf(bin_op.lhs);
        const result_ty = self.typeOfIndex(inst);

        return try self.cmp(op, result_ty, ty, lhs_id, rhs_id);
    }

    fn airVectorCmp(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
        const vec_cmp = self.air.extraData(Air.VectorCmp, ty_pl.payload).data;
        const lhs_id = try self.resolve(vec_cmp.lhs);
        const rhs_id = try self.resolve(vec_cmp.rhs);
        const op = vec_cmp.compareOperator();
        const ty = self.typeOf(vec_cmp.lhs);
        const result_ty = self.typeOfIndex(inst);

        return try self.cmp(op, result_ty, ty, lhs_id, rhs_id);
    }

    /// Bitcast one type to another. Note: both types, input, output are expected in **direct** representation.
    fn bitCast(
        self: *DeclGen,
        dst_ty: Type,
        src_ty: Type,
        src_id: IdRef,
    ) !IdRef {
        const mod = self.module;
        const src_ty_id = try self.resolveType(src_ty, .direct);
        const dst_ty_id = try self.resolveType(dst_ty, .direct);

        const result_id = blk: {
            if (src_ty_id == dst_ty_id) {
                break :blk src_id;
            }

            // TODO: Some more cases are missing here
            //   See fn bitCast in llvm.zig

            if (src_ty.zigTypeTag(mod) == .Int and dst_ty.isPtrAtRuntime(mod)) {
                const result_id = self.spv.allocId();
                try self.func.body.emit(self.spv.gpa, .OpConvertUToPtr, .{
                    .id_result_type = dst_ty_id,
                    .id_result = result_id,
                    .integer_value = src_id,
                });
                break :blk result_id;
            }

            // We can only use OpBitcast for specific conversions: between numerical types, and
            // between pointers. If the resolved spir-v types fall into this category then emit OpBitcast,
            // otherwise use a temporary and perform a pointer cast.
            const can_bitcast = (src_ty.isNumeric(mod) and dst_ty.isNumeric(mod)) or (src_ty.isPtrAtRuntime(mod) and dst_ty.isPtrAtRuntime(mod));
            if (can_bitcast) {
                const result_id = self.spv.allocId();
                try self.func.body.emit(self.spv.gpa, .OpBitcast, .{
                    .id_result_type = dst_ty_id,
                    .id_result = result_id,
                    .operand = src_id,
                });

                break :blk result_id;
            }

            const dst_ptr_ty_id = try self.ptrType(dst_ty, .Function);

            const tmp_id = try self.alloc(src_ty, .{ .storage_class = .Function });
            try self.store(src_ty, tmp_id, src_id, .{});
            const casted_ptr_id = self.spv.allocId();
            try self.func.body.emit(self.spv.gpa, .OpBitcast, .{
                .id_result_type = dst_ptr_ty_id,
                .id_result = casted_ptr_id,
                .operand = tmp_id,
            });
            break :blk try self.load(dst_ty, casted_ptr_id, .{});
        };

        // Because strange integers use sign-extended representation, we may need to normalize
        // the result here.
        // TODO: This detail could cause stuff like @as(*const i1, @ptrCast(&@as(u1, 1))) to break
        // should we change the representation of strange integers?
        if (dst_ty.zigTypeTag(mod) == .Int) {
            const info = self.arithmeticTypeInfo(dst_ty);
            return try self.normalize(dst_ty, result_id, info);
        }

        return result_id;
    }

    fn airBitCast(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
        const operand_id = try self.resolve(ty_op.operand);
        const operand_ty = self.typeOf(ty_op.operand);
        const result_ty = self.typeOfIndex(inst);
        return try self.bitCast(result_ty, operand_ty, operand_id);
    }

    fn airIntCast(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
        const operand_id = try self.resolve(ty_op.operand);
        const src_ty = self.typeOf(ty_op.operand);
        const dst_ty = self.typeOfIndex(inst);

        const src_info = self.arithmeticTypeInfo(src_ty);
        const dst_info = self.arithmeticTypeInfo(dst_ty);

        if (src_info.backing_bits == dst_info.backing_bits) {
            return operand_id;
        }

        var wip = try self.elementWise(dst_ty, false);
        defer wip.deinit();
        for (wip.results, 0..) |*result_id, i| {
            const elem_id = try wip.elementAt(src_ty, operand_id, i);
            const value_id = self.spv.allocId();
            switch (dst_info.signedness) {
                .signed => try self.func.body.emit(self.spv.gpa, .OpSConvert, .{
                    .id_result_type = wip.ty_id,
                    .id_result = value_id,
                    .signed_value = elem_id,
                }),
                .unsigned => try self.func.body.emit(self.spv.gpa, .OpUConvert, .{
                    .id_result_type = wip.ty_id,
                    .id_result = value_id,
                    .unsigned_value = elem_id,
                }),
            }

            // Make sure to normalize the result if shrinking.
            // Because strange ints are sign extended in their backing
            // type, we don't need to normalize when growing the type. The
            // representation is already the same.
            if (dst_info.bits < src_info.bits) {
                result_id.* = try self.normalize(wip.ty, value_id, dst_info);
            } else {
                result_id.* = value_id;
            }
        }
        return try wip.finalize();
    }

    fn intFromPtr(self: *DeclGen, operand_id: IdRef) !IdRef {
        const result_type_id = try self.resolveType(Type.usize, .direct);
        const result_id = self.spv.allocId();
        try self.func.body.emit(self.spv.gpa, .OpConvertPtrToU, .{
            .id_result_type = result_type_id,
            .id_result = result_id,
            .pointer = operand_id,
        });
        return result_id;
    }

    fn airIntFromPtr(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
        const operand_id = try self.resolve(un_op);
        return try self.intFromPtr(operand_id);
    }

    fn airFloatFromInt(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
        const operand_ty = self.typeOf(ty_op.operand);
        const operand_id = try self.resolve(ty_op.operand);
        const result_ty = self.typeOfIndex(inst);
        return try self.floatFromInt(result_ty, operand_ty, operand_id);
    }

    fn floatFromInt(self: *DeclGen, result_ty: Type, operand_ty: Type, operand_id: IdRef) !IdRef {
        const operand_info = self.arithmeticTypeInfo(operand_ty);
        const result_id = self.spv.allocId();
        const result_ty_id = try self.resolveType(result_ty, .direct);
        switch (operand_info.signedness) {
            .signed => try self.func.body.emit(self.spv.gpa, .OpConvertSToF, .{
                .id_result_type = result_ty_id,
                .id_result = result_id,
                .signed_value = operand_id,
            }),
            .unsigned => try self.func.body.emit(self.spv.gpa, .OpConvertUToF, .{
                .id_result_type = result_ty_id,
                .id_result = result_id,
                .unsigned_value = operand_id,
            }),
        }
        return result_id;
    }

    fn airIntFromFloat(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
        const operand_id = try self.resolve(ty_op.operand);
        const result_ty = self.typeOfIndex(inst);
        return try self.intFromFloat(result_ty, operand_id);
    }

    fn intFromFloat(self: *DeclGen, result_ty: Type, operand_id: IdRef) !IdRef {
        const result_info = self.arithmeticTypeInfo(result_ty);
        const result_ty_id = try self.resolveType(result_ty, .direct);
        const result_id = self.spv.allocId();
        switch (result_info.signedness) {
            .signed => try self.func.body.emit(self.spv.gpa, .OpConvertFToS, .{
                .id_result_type = result_ty_id,
                .id_result = result_id,
                .float_value = operand_id,
            }),
            .unsigned => try self.func.body.emit(self.spv.gpa, .OpConvertFToU, .{
                .id_result_type = result_ty_id,
                .id_result = result_id,
                .float_value = operand_id,
            }),
        }
        return result_id;
    }

    fn airIntFromBool(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
        const operand_id = try self.resolve(un_op);
        const result_ty = self.typeOfIndex(inst);

        var wip = try self.elementWise(result_ty, false);
        defer wip.deinit();
        for (wip.results, 0..) |*result_id, i| {
            const elem_id = try wip.elementAt(Type.bool, operand_id, i);
            result_id.* = try self.intFromBool(wip.ty, elem_id);
        }
        return try wip.finalize();
    }

    fn airFloatCast(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
        const operand_id = try self.resolve(ty_op.operand);
        const dest_ty = self.typeOfIndex(inst);
        const dest_ty_id = try self.resolveType(dest_ty, .direct);

        const result_id = self.spv.allocId();
        try self.func.body.emit(self.spv.gpa, .OpFConvert, .{
            .id_result_type = dest_ty_id,
            .id_result = result_id,
            .float_value = operand_id,
        });
        return result_id;
    }

    fn airNot(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
        const operand_id = try self.resolve(ty_op.operand);
        const result_ty = self.typeOfIndex(inst);
        const info = self.arithmeticTypeInfo(result_ty);

        var wip = try self.elementWise(result_ty, false);
        defer wip.deinit();

        for (0..wip.results.len) |i| {
            const args = .{
                .id_result_type = wip.ty_id,
                .id_result = wip.allocId(i),
                .operand = try wip.elementAt(result_ty, operand_id, i),
            };
            switch (info.class) {
                .bool => {
                    try self.func.body.emit(self.spv.gpa, .OpLogicalNot, args);
                },
                .float => unreachable,
                .composite_integer => unreachable, // TODO
                .strange_integer, .integer => {
                    // Note: strange integer bits will be masked before operations that do not hold under modulo.
                    try self.func.body.emit(self.spv.gpa, .OpNot, args);
                },
            }
        }

        return try wip.finalize();
    }

    fn airArrayToSlice(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        const mod = self.module;
        const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
        const array_ptr_ty = self.typeOf(ty_op.operand);
        const array_ty = array_ptr_ty.childType(mod);
        const slice_ty = self.typeOfIndex(inst);
        const elem_ptr_ty = slice_ty.slicePtrFieldType(mod);

        const elem_ptr_ty_id = try self.resolveType(elem_ptr_ty, .direct);

        const array_ptr_id = try self.resolve(ty_op.operand);
        const len_id = try self.constInt(Type.usize, array_ty.arrayLen(mod), .direct);

        const elem_ptr_id = if (!array_ty.hasRuntimeBitsIgnoreComptime(mod))
            // Note: The pointer is something like *opaque{}, so we need to bitcast it to the element type.
            try self.bitCast(elem_ptr_ty, array_ptr_ty, array_ptr_id)
        else
            // Convert the pointer-to-array to a pointer to the first element.
            try self.accessChain(elem_ptr_ty_id, array_ptr_id, &.{0});

        return try self.constructStruct(
            slice_ty,
            &.{ elem_ptr_ty, Type.usize },
            &.{ elem_ptr_id, len_id },
        );
    }

    fn airSlice(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
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
        const mod = self.module;
        const ip = &mod.intern_pool;
        const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
        const result_ty = self.typeOfIndex(inst);
        const len: usize = @intCast(result_ty.arrayLen(mod));
        const elements: []const Air.Inst.Ref = @ptrCast(self.air.extra[ty_pl.payload..][0..len]);

        switch (result_ty.zigTypeTag(mod)) {
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
                            assert(Type.fromInterned(field_ty).hasRuntimeBits(mod));

                            const id = try self.resolve(element);
                            types[index] = Type.fromInterned(field_ty);
                            constituents[index] = try self.convertToIndirect(Type.fromInterned(field_ty), id);
                            index += 1;
                        }
                    },
                    .struct_type => {
                        const struct_type = ip.loadStructType(result_ty.toIntern());
                        var it = struct_type.iterateRuntimeOrder(ip);
                        for (elements, 0..) |element, i| {
                            const field_index = it.next().?;
                            if ((try result_ty.structFieldValueComptime(mod, i)) != null) continue;
                            const field_ty = Type.fromInterned(struct_type.field_types.get(ip)[field_index]);
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
            .Vector => {
                const n_elems = result_ty.vectorLen(mod);
                const elem_ids = try self.gpa.alloc(IdRef, n_elems);
                defer self.gpa.free(elem_ids);

                for (elements, 0..) |element, i| {
                    const id = try self.resolve(element);
                    elem_ids[i] = try self.convertToIndirect(result_ty.childType(mod), id);
                }

                return try self.constructVector(result_ty, elem_ids);
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
                const size = array_ty.arrayLenIncludingSentinel(mod) * abi_size;
                return try self.constInt(Type.usize, size, .direct);
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
        const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
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
        const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
        const field_ty = self.typeOfIndex(inst);
        const operand_id = try self.resolve(ty_op.operand);
        return try self.extractField(field_ty, operand_id, field);
    }

    fn airSliceElemPtr(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        const mod = self.module;
        const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
        const bin_op = self.air.extraData(Air.Bin, ty_pl.payload).data;
        const slice_ty = self.typeOf(bin_op.lhs);
        if (!slice_ty.isVolatilePtr(mod) and self.liveness.isUnused(inst)) return null;

        const slice_id = try self.resolve(bin_op.lhs);
        const index_id = try self.resolve(bin_op.rhs);

        const ptr_ty = self.typeOfIndex(inst);
        const ptr_ty_id = try self.resolveType(ptr_ty, .direct);

        const slice_ptr = try self.extractField(ptr_ty, slice_id, 0);
        return try self.ptrAccessChain(ptr_ty_id, slice_ptr, index_id, &.{});
    }

    fn airSliceElemVal(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        const mod = self.module;
        const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
        const slice_ty = self.typeOf(bin_op.lhs);
        if (!slice_ty.isVolatilePtr(mod) and self.liveness.isUnused(inst)) return null;

        const slice_id = try self.resolve(bin_op.lhs);
        const index_id = try self.resolve(bin_op.rhs);

        const ptr_ty = slice_ty.slicePtrFieldType(mod);
        const ptr_ty_id = try self.resolveType(ptr_ty, .direct);

        const slice_ptr = try self.extractField(ptr_ty, slice_id, 0);
        const elem_ptr = try self.ptrAccessChain(ptr_ty_id, slice_ptr, index_id, &.{});
        return try self.load(slice_ty.childType(mod), elem_ptr, .{ .is_volatile = slice_ty.isVolatilePtr(mod) });
    }

    fn ptrElemPtr(self: *DeclGen, ptr_ty: Type, ptr_id: IdRef, index_id: IdRef) !IdRef {
        const mod = self.module;
        // Construct new pointer type for the resulting pointer
        const elem_ty = ptr_ty.elemType2(mod); // use elemType() so that we get T for *[N]T.
        const elem_ptr_ty_id = try self.ptrType(elem_ty, self.spvStorageClass(ptr_ty.ptrAddressSpace(mod)));
        if (ptr_ty.isSinglePointer(mod)) {
            // Pointer-to-array. In this case, the resulting pointer is not of the same type
            // as the ptr_ty (we want a *T, not a *[N]T), and hence we need to use accessChain.
            return try self.accessChainId(elem_ptr_ty_id, ptr_id, &.{index_id});
        } else {
            // Resulting pointer type is the same as the ptr_ty, so use ptrAccessChain
            return try self.ptrAccessChain(elem_ptr_ty_id, ptr_id, index_id, &.{});
        }
    }

    fn airPtrElemPtr(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        const mod = self.module;
        const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
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
        const mod = self.module;
        const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
        const array_ty = self.typeOf(bin_op.lhs);
        const elem_ty = array_ty.childType(mod);
        const array_id = try self.resolve(bin_op.lhs);
        const index_id = try self.resolve(bin_op.rhs);

        // SPIR-V doesn't have an array indexing function for some damn reason.
        // For now, just generate a temporary and use that.
        // TODO: This backend probably also should use isByRef from llvm...

        const elem_ptr_ty_id = try self.ptrType(elem_ty, .Function);

        const tmp_id = try self.alloc(array_ty, .{ .storage_class = .Function });
        try self.store(array_ty, tmp_id, array_id, .{});
        const elem_ptr_id = try self.accessChainId(elem_ptr_ty_id, tmp_id, &.{index_id});
        return try self.load(elem_ty, elem_ptr_id, .{});
    }

    fn airPtrElemVal(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        const mod = self.module;
        const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
        const ptr_ty = self.typeOf(bin_op.lhs);
        const elem_ty = self.typeOfIndex(inst);
        const ptr_id = try self.resolve(bin_op.lhs);
        const index_id = try self.resolve(bin_op.rhs);
        const elem_ptr_id = try self.ptrElemPtr(ptr_ty, ptr_id, index_id);
        return try self.load(elem_ty, elem_ptr_id, .{ .is_volatile = ptr_ty.isVolatilePtr(mod) });
    }

    fn airVectorStoreElem(self: *DeclGen, inst: Air.Inst.Index) !void {
        const mod = self.module;
        const data = self.air.instructions.items(.data)[@intFromEnum(inst)].vector_store_elem;
        const extra = self.air.extraData(Air.Bin, data.payload).data;

        const vector_ptr_ty = self.typeOf(data.vector_ptr);
        const vector_ty = vector_ptr_ty.childType(mod);
        const scalar_ty = vector_ty.scalarType(mod);

        const storage_class = self.spvStorageClass(vector_ptr_ty.ptrAddressSpace(mod));
        const scalar_ptr_ty_id = try self.ptrType(scalar_ty, storage_class);

        const vector_ptr = try self.resolve(data.vector_ptr);
        const index = try self.resolve(extra.lhs);
        const operand = try self.resolve(extra.rhs);

        const elem_ptr_id = try self.accessChainId(scalar_ptr_ty_id, vector_ptr, &.{index});
        try self.store(scalar_ty, elem_ptr_id, operand, .{
            .is_volatile = vector_ptr_ty.isVolatilePtr(mod),
        });
    }

    fn airSetUnionTag(self: *DeclGen, inst: Air.Inst.Index) !void {
        const mod = self.module;
        const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
        const un_ptr_ty = self.typeOf(bin_op.lhs);
        const un_ty = un_ptr_ty.childType(mod);
        const layout = self.unionLayout(un_ty);

        if (layout.tag_size == 0) return;

        const tag_ty = un_ty.unionTagTypeSafety(mod).?;
        const tag_ptr_ty_id = try self.ptrType(tag_ty, self.spvStorageClass(un_ptr_ty.ptrAddressSpace(mod)));

        const union_ptr_id = try self.resolve(bin_op.lhs);
        const new_tag_id = try self.resolve(bin_op.rhs);

        if (!layout.has_payload) {
            try self.store(tag_ty, union_ptr_id, new_tag_id, .{ .is_volatile = un_ptr_ty.isVolatilePtr(mod) });
        } else {
            const ptr_id = try self.accessChain(tag_ptr_ty_id, union_ptr_id, &.{layout.tag_index});
            try self.store(tag_ty, ptr_id, new_tag_id, .{ .is_volatile = un_ptr_ty.isVolatilePtr(mod) });
        }
    }

    fn airGetUnionTag(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
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

        // Note: The result here is not cached, because it generates runtime code.

        const mod = self.module;
        const ip = &mod.intern_pool;
        const union_ty = mod.typeToUnion(ty).?;
        const tag_ty = Type.fromInterned(union_ty.enum_tag_ty);

        if (union_ty.getLayout(ip) == .@"packed") {
            unreachable; // TODO
        }

        const layout = self.unionLayout(ty);

        const tag_int = if (layout.tag_size != 0) blk: {
            const tag_val = try mod.enumValueFieldIndex(tag_ty, active_field);
            const tag_int_val = try tag_val.intFromEnum(tag_ty, mod);
            break :blk tag_int_val.toUnsignedInt(mod);
        } else 0;

        if (!layout.has_payload) {
            return try self.constInt(tag_ty, tag_int, .direct);
        }

        const tmp_id = try self.alloc(ty, .{ .storage_class = .Function });

        if (layout.tag_size != 0) {
            const tag_ptr_ty_id = try self.ptrType(tag_ty, .Function);
            const ptr_id = try self.accessChain(tag_ptr_ty_id, tmp_id, &.{@as(u32, @intCast(layout.tag_index))});
            const tag_id = try self.constInt(tag_ty, tag_int, .direct);
            try self.store(tag_ty, ptr_id, tag_id, .{});
        }

        const payload_ty = Type.fromInterned(union_ty.field_types.get(ip)[active_field]);
        if (payload_ty.hasRuntimeBitsIgnoreComptime(mod)) {
            const pl_ptr_ty_id = try self.ptrType(layout.payload_ty, .Function);
            const pl_ptr_id = try self.accessChain(pl_ptr_ty_id, tmp_id, &.{layout.payload_index});
            const active_pl_ptr_ty_id = try self.ptrType(payload_ty, .Function);
            const active_pl_ptr_id = self.spv.allocId();
            try self.func.body.emit(self.spv.gpa, .OpBitcast, .{
                .id_result_type = active_pl_ptr_ty_id,
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
        const mod = self.module;
        const ip = &mod.intern_pool;
        const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
        const extra = self.air.extraData(Air.UnionInit, ty_pl.payload).data;
        const ty = self.typeOfIndex(inst);

        const union_obj = mod.typeToUnion(ty).?;
        const field_ty = Type.fromInterned(union_obj.field_types.get(ip)[extra.field_index]);
        const payload = if (field_ty.hasRuntimeBitsIgnoreComptime(mod))
            try self.resolve(extra.init)
        else
            null;
        return try self.unionInit(ty, extra.field_index, payload);
    }

    fn airStructFieldVal(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        const mod = self.module;
        const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
        const struct_field = self.air.extraData(Air.StructField, ty_pl.payload).data;

        const object_ty = self.typeOf(struct_field.struct_operand);
        const object_id = try self.resolve(struct_field.struct_operand);
        const field_index = struct_field.field_index;
        const field_ty = object_ty.structFieldType(field_index, mod);

        if (!field_ty.hasRuntimeBitsIgnoreComptime(mod)) return null;

        switch (object_ty.zigTypeTag(mod)) {
            .Struct => switch (object_ty.containerLayout(mod)) {
                .@"packed" => unreachable, // TODO
                else => return try self.extractField(field_ty, object_id, field_index),
            },
            .Union => switch (object_ty.containerLayout(mod)) {
                .@"packed" => unreachable, // TODO
                else => {
                    // Store, ptr-elem-ptr, pointer-cast, load
                    const layout = self.unionLayout(object_ty);
                    assert(layout.has_payload);

                    const tmp_id = try self.alloc(object_ty, .{ .storage_class = .Function });
                    try self.store(object_ty, tmp_id, object_id, .{});

                    const pl_ptr_ty_id = try self.ptrType(layout.payload_ty, .Function);
                    const pl_ptr_id = try self.accessChain(pl_ptr_ty_id, tmp_id, &.{layout.payload_index});

                    const active_pl_ptr_ty_id = try self.ptrType(field_ty, .Function);
                    const active_pl_ptr_id = self.spv.allocId();
                    try self.func.body.emit(self.spv.gpa, .OpBitcast, .{
                        .id_result_type = active_pl_ptr_ty_id,
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
        const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
        const extra = self.air.extraData(Air.FieldParentPtr, ty_pl.payload).data;

        const parent_ty = ty_pl.ty.toType().childType(mod);
        const result_ty_id = try self.resolveType(ty_pl.ty.toType(), .indirect);

        const field_ptr = try self.resolve(extra.field_ptr);
        const field_ptr_int = try self.intFromPtr(field_ptr);
        const field_offset = parent_ty.structFieldOffset(extra.field_index, mod);

        const base_ptr_int = base_ptr_int: {
            if (field_offset == 0) break :base_ptr_int field_ptr_int;

            const field_offset_id = try self.constInt(Type.usize, field_offset, .direct);
            break :base_ptr_int try self.binOpSimple(Type.usize, field_ptr_int, field_offset_id, .OpISub);
        };

        const base_ptr = self.spv.allocId();
        try self.func.body.emit(self.spv.gpa, .OpConvertUToPtr, .{
            .id_result_type = result_ty_id,
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
        const result_ty_id = try self.resolveType(result_ptr_ty, .direct);

        const zcu = self.module;
        const object_ty = object_ptr_ty.childType(zcu);
        switch (object_ty.zigTypeTag(zcu)) {
            .Pointer => {
                assert(object_ty.isSlice(zcu));
                return self.accessChain(result_ty_id, object_ptr, &.{field_index});
            },
            .Struct => switch (object_ty.containerLayout(zcu)) {
                .@"packed" => unreachable, // TODO
                else => {
                    return try self.accessChain(result_ty_id, object_ptr, &.{field_index});
                },
            },
            .Union => switch (object_ty.containerLayout(zcu)) {
                .@"packed" => unreachable, // TODO
                else => {
                    const layout = self.unionLayout(object_ty);
                    if (!layout.has_payload) {
                        // Asked to get a pointer to a zero-sized field. Just lower this
                        // to undefined, there is no reason to make it be a valid pointer.
                        return try self.spv.constUndef(result_ty_id);
                    }

                    const storage_class = self.spvStorageClass(object_ptr_ty.ptrAddressSpace(zcu));
                    const pl_ptr_ty_id = try self.ptrType(layout.payload_ty, storage_class);
                    const pl_ptr_id = try self.accessChain(pl_ptr_ty_id, object_ptr, &.{layout.payload_index});

                    const active_pl_ptr_id = self.spv.allocId();
                    try self.func.body.emit(self.spv.gpa, .OpBitcast, .{
                        .id_result_type = result_ty_id,
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
        const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
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
    // This function returns a pointer to a variable of type `ty`,
    // which is in the Generic address space. The variable is actually
    // placed in the Function address space.
    fn alloc(
        self: *DeclGen,
        ty: Type,
        options: AllocOptions,
    ) !IdRef {
        const ptr_fn_ty_id = try self.ptrType(ty, .Function);

        // SPIR-V requires that OpVariable declarations for locals go into the first block, so we are just going to
        // directly generate them into func.prologue instead of the body.
        const var_id = self.spv.allocId();
        try self.func.prologue.emit(self.spv.gpa, .OpVariable, .{
            .id_result_type = ptr_fn_ty_id,
            .id_result = var_id,
            .storage_class = .Function,
            .initializer = options.initializer,
        });

        const target = self.getTarget();
        if (target.os.tag == .vulkan) {
            return var_id;
        }

        switch (options.storage_class) {
            .Generic => {
                const ptr_gn_ty_id = try self.ptrType(ty, .Generic);
                // Convert to a generic pointer
                return self.castToGeneric(ptr_gn_ty_id, var_id);
            },
            .Function => return var_id,
            else => unreachable,
        }
    }

    fn airAlloc(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
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

    /// Given a slice of incoming block connections, returns the block-id of the next
    /// block to jump to. This function emits instructions, so it should be emitted
    /// inside the merge block of the block.
    /// This function should only be called with structured control flow generation.
    fn structuredNextBlock(self: *DeclGen, incoming: []const ControlFlow.Structured.Block.Incoming) !IdRef {
        assert(self.control_flow == .structured);

        const result_id = self.spv.allocId();
        const block_id_ty_id = try self.resolveType(Type.u32, .direct);
        try self.func.body.emitRaw(self.spv.gpa, .OpPhi, @intCast(2 + incoming.len * 2)); // result type + result + variable/parent...
        self.func.body.writeOperand(spec.IdResultType, block_id_ty_id);
        self.func.body.writeOperand(spec.IdRef, result_id);

        for (incoming) |incoming_block| {
            self.func.body.writeOperand(spec.PairIdRefIdRef, .{ incoming_block.next_block, incoming_block.src_label });
        }

        return result_id;
    }

    /// Jumps to the block with the target block-id. This function must only be called when
    /// terminating a body, there should be no instructions after it.
    /// This function should only be called with structured control flow generation.
    fn structuredBreak(self: *DeclGen, target_block: IdRef) !void {
        assert(self.control_flow == .structured);

        const sblock = self.control_flow.structured.block_stack.getLast();
        const merge_block = switch (sblock.*) {
            .selection => |*merge| blk: {
                const merge_label = self.spv.allocId();
                try merge.merge_stack.append(self.gpa, .{
                    .incoming = .{
                        .src_label = self.current_block_label,
                        .next_block = target_block,
                    },
                    .merge_block = merge_label,
                });
                break :blk merge_label;
            },
            // Loop blocks do not end in a break. Not through a direct break,
            // and also not through another instruction like cond_br or unreachable (these
            // situations are replaced by `cond_br` in sema, or there is a `block` instruction
            // placed around them).
            .loop => unreachable,
        };

        try self.func.body.emitBranch(self.spv.gpa, merge_block);
    }

    /// Generate a body in a way that exits the body using only structured constructs.
    /// Returns the block-id of the next block to jump to. After this function, a jump
    /// should still be emitted to the block that should follow this structured body.
    /// This function should only be called with structured control flow generation.
    fn genStructuredBody(
        self: *DeclGen,
        /// This parameter defines the method that this structured body is exited with.
        block_merge_type: union(enum) {
            /// Using selection; early exits from this body are surrounded with
            /// if() statements.
            selection,
            /// Using loops; loops can be early exited by jumping to the merge block at
            /// any time.
            loop: struct {
                merge_label: IdRef,
                continue_label: IdRef,
            },
        },
        body: []const Air.Inst.Index,
    ) !IdRef {
        assert(self.control_flow == .structured);

        var sblock: ControlFlow.Structured.Block = switch (block_merge_type) {
            .loop => |merge| .{ .loop = .{
                .merge_block = merge.merge_label,
            } },
            .selection => .{ .selection = .{} },
        };
        defer sblock.deinit(self.gpa);

        {
            try self.control_flow.structured.block_stack.append(self.gpa, &sblock);
            defer _ = self.control_flow.structured.block_stack.pop();

            try self.genBody(body);
        }

        switch (sblock) {
            .selection => |merge| {
                // Now generate the merge block for all merges that
                // still need to be performed.
                const merge_stack = merge.merge_stack.items;

                // If no merges on the stack, this block didn't generate any jumps (all paths
                // ended with a return or an unreachable). In that case, we don't need to do
                // any merging.
                if (merge_stack.len == 0) {
                    // We still need to return a value of a next block to jump to.
                    // For example, if we have code like
                    //  if (x) {
                    //    if (y) return else return;
                    //  } else {}
                    // then we still need the outer to have an OpSelectionMerge and consequently
                    // a phi node. In that case we can just return bogus, since we know that its
                    // path will never be taken.

                    // Make sure that we are still in a block when exiting the function.
                    // TODO: Can we get rid of that?
                    try self.beginSpvBlock(self.spv.allocId());
                    const block_id_ty_id = try self.resolveType(Type.u32, .direct);
                    return try self.spv.constUndef(block_id_ty_id);
                }

                // The top-most merge actually only has a single source, the
                // final jump of the block, or the merge block of a sub-block, cond_br,
                // or loop. Therefore we just need to generate a block with a jump to the
                // next merge block.
                try self.beginSpvBlock(merge_stack[merge_stack.len - 1].merge_block);

                // Now generate a merge ladder for the remaining merges in the stack.
                var incoming = ControlFlow.Structured.Block.Incoming{
                    .src_label = self.current_block_label,
                    .next_block = merge_stack[merge_stack.len - 1].incoming.next_block,
                };
                var i = merge_stack.len - 1;
                while (i > 0) {
                    i -= 1;
                    const step = merge_stack[i];
                    try self.func.body.emitBranch(self.spv.gpa, step.merge_block);
                    try self.beginSpvBlock(step.merge_block);
                    const next_block = try self.structuredNextBlock(&.{ incoming, step.incoming });
                    incoming = .{
                        .src_label = step.merge_block,
                        .next_block = next_block,
                    };
                }

                return incoming.next_block;
            },
            .loop => |merge| {
                // Close the loop by jumping to the continue label
                try self.func.body.emitBranch(self.spv.gpa, block_merge_type.loop.continue_label);
                // For blocks we must simple merge all the incoming blocks to get the next block.
                try self.beginSpvBlock(merge.merge_block);
                return try self.structuredNextBlock(merge.merges.items);
            },
        }
    }

    fn airBlock(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        const inst_datas = self.air.instructions.items(.data);
        const extra = self.air.extraData(Air.Block, inst_datas[@intFromEnum(inst)].ty_pl.payload);
        return self.lowerBlock(inst, @ptrCast(self.air.extra[extra.end..][0..extra.data.body_len]));
    }

    fn lowerBlock(self: *DeclGen, inst: Air.Inst.Index, body: []const Air.Inst.Index) !?IdRef {
        // In AIR, a block doesn't really define an entry point like a block, but
        // more like a scope that breaks can jump out of and "return" a value from.
        // This cannot be directly modelled in SPIR-V, so in a block instruction,
        // we're going to split up the current block by first generating the code
        // of the block, then a label, and then generate the rest of the current
        // ir.Block in a different SPIR-V block.

        const mod = self.module;
        const ty = self.typeOfIndex(inst);
        const have_block_result = ty.isFnOrHasRuntimeBitsIgnoreComptime(mod);

        const cf = switch (self.control_flow) {
            .structured => |*cf| cf,
            .unstructured => |*cf| {
                var block = ControlFlow.Unstructured.Block{};
                defer block.incoming_blocks.deinit(self.gpa);

                // 4 chosen as arbitrary initial capacity.
                try block.incoming_blocks.ensureUnusedCapacity(self.gpa, 4);

                try cf.blocks.putNoClobber(self.gpa, inst, &block);
                defer assert(cf.blocks.remove(inst));

                try self.genBody(body);

                // Only begin a new block if there were actually any breaks towards it.
                if (block.label) |label| {
                    try self.beginSpvBlock(label);
                }

                if (!have_block_result)
                    return null;

                assert(block.label != null);
                const result_id = self.spv.allocId();
                const result_type_id = try self.resolveType(ty, .direct);

                try self.func.body.emitRaw(
                    self.spv.gpa,
                    .OpPhi,
                    // result type + result + variable/parent...
                    2 + @as(u16, @intCast(block.incoming_blocks.items.len * 2)),
                );
                self.func.body.writeOperand(spec.IdResultType, result_type_id);
                self.func.body.writeOperand(spec.IdRef, result_id);

                for (block.incoming_blocks.items) |incoming| {
                    self.func.body.writeOperand(
                        spec.PairIdRefIdRef,
                        .{ incoming.break_value_id, incoming.src_label },
                    );
                }

                return result_id;
            },
        };

        const maybe_block_result_var_id = if (have_block_result) blk: {
            const block_result_var_id = try self.alloc(ty, .{ .storage_class = .Function });
            try cf.block_results.putNoClobber(self.gpa, inst, block_result_var_id);
            break :blk block_result_var_id;
        } else null;
        defer if (have_block_result) assert(cf.block_results.remove(inst));

        const next_block = try self.genStructuredBody(.selection, body);

        // When encountering a block instruction, we are always at least in the function's scope,
        // so there always has to be another entry.
        assert(cf.block_stack.items.len > 0);

        // Check if the target of the branch was this current block.
        const this_block = try self.constInt(Type.u32, @intFromEnum(inst), .direct);
        const jump_to_this_block_id = self.spv.allocId();
        const bool_ty_id = try self.resolveType(Type.bool, .direct);
        try self.func.body.emit(self.spv.gpa, .OpIEqual, .{
            .id_result_type = bool_ty_id,
            .id_result = jump_to_this_block_id,
            .operand_1 = next_block,
            .operand_2 = this_block,
        });

        const sblock = cf.block_stack.getLast();

        if (ty.isNoReturn(mod)) {
            // If this block is noreturn, this instruction is the last of a block,
            // and we must simply jump to the block's merge unconditionally.
            try self.structuredBreak(next_block);
        } else {
            switch (sblock.*) {
                .selection => |*merge| {
                    // To jump out of a selection block, push a new entry onto its merge stack and
                    // generate a conditional branch to there and to the instructions following this block.
                    const merge_label = self.spv.allocId();
                    const then_label = self.spv.allocId();
                    try self.func.body.emit(self.spv.gpa, .OpSelectionMerge, .{
                        .merge_block = merge_label,
                        .selection_control = .{},
                    });
                    try self.func.body.emit(self.spv.gpa, .OpBranchConditional, .{
                        .condition = jump_to_this_block_id,
                        .true_label = then_label,
                        .false_label = merge_label,
                    });
                    try merge.merge_stack.append(self.gpa, .{
                        .incoming = .{
                            .src_label = self.current_block_label,
                            .next_block = next_block,
                        },
                        .merge_block = merge_label,
                    });

                    try self.beginSpvBlock(then_label);
                },
                .loop => |*merge| {
                    // To jump out of a loop block, generate a conditional that exits the block
                    // to the loop merge if the target ID is not the one of this block.
                    const continue_label = self.spv.allocId();
                    try self.func.body.emit(self.spv.gpa, .OpBranchConditional, .{
                        .condition = jump_to_this_block_id,
                        .true_label = continue_label,
                        .false_label = merge.merge_block,
                    });
                    try merge.merges.append(self.gpa, .{
                        .src_label = self.current_block_label,
                        .next_block = next_block,
                    });
                    try self.beginSpvBlock(continue_label);
                },
            }
        }

        if (maybe_block_result_var_id) |block_result_var_id| {
            return try self.load(ty, block_result_var_id, .{});
        }

        return null;
    }

    fn airBr(self: *DeclGen, inst: Air.Inst.Index) !void {
        const mod = self.module;
        const br = self.air.instructions.items(.data)[@intFromEnum(inst)].br;
        const operand_ty = self.typeOf(br.operand);

        switch (self.control_flow) {
            .structured => |*cf| {
                if (operand_ty.isFnOrHasRuntimeBitsIgnoreComptime(mod)) {
                    const operand_id = try self.resolve(br.operand);
                    const block_result_var_id = cf.block_results.get(br.block_inst).?;
                    try self.store(operand_ty, block_result_var_id, operand_id, .{});
                }

                const next_block = try self.constInt(Type.u32, @intFromEnum(br.block_inst), .direct);
                try self.structuredBreak(next_block);
            },
            .unstructured => |cf| {
                const block = cf.blocks.get(br.block_inst).?;
                if (operand_ty.isFnOrHasRuntimeBitsIgnoreComptime(mod)) {
                    const operand_id = try self.resolve(br.operand);
                    // current_block_label should not be undefined here, lest there
                    // is a br or br_void in the function's body.
                    try block.incoming_blocks.append(self.gpa, .{
                        .src_label = self.current_block_label,
                        .break_value_id = operand_id,
                    });
                }

                if (block.label == null) {
                    block.label = self.spv.allocId();
                }

                try self.func.body.emitBranch(self.spv.gpa, block.label.?);
            },
        }
    }

    fn airCondBr(self: *DeclGen, inst: Air.Inst.Index) !void {
        const pl_op = self.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
        const cond_br = self.air.extraData(Air.CondBr, pl_op.payload);
        const then_body: []const Air.Inst.Index = @ptrCast(self.air.extra[cond_br.end..][0..cond_br.data.then_body_len]);
        const else_body: []const Air.Inst.Index = @ptrCast(self.air.extra[cond_br.end + then_body.len ..][0..cond_br.data.else_body_len]);
        const condition_id = try self.resolve(pl_op.operand);

        const then_label = self.spv.allocId();
        const else_label = self.spv.allocId();

        switch (self.control_flow) {
            .structured => {
                const merge_label = self.spv.allocId();

                try self.func.body.emit(self.spv.gpa, .OpSelectionMerge, .{
                    .merge_block = merge_label,
                    .selection_control = .{},
                });
                try self.func.body.emit(self.spv.gpa, .OpBranchConditional, .{
                    .condition = condition_id,
                    .true_label = then_label,
                    .false_label = else_label,
                });

                try self.beginSpvBlock(then_label);
                const then_next = try self.genStructuredBody(.selection, then_body);
                const then_incoming = ControlFlow.Structured.Block.Incoming{
                    .src_label = self.current_block_label,
                    .next_block = then_next,
                };
                try self.func.body.emitBranch(self.spv.gpa, merge_label);

                try self.beginSpvBlock(else_label);
                const else_next = try self.genStructuredBody(.selection, else_body);
                const else_incoming = ControlFlow.Structured.Block.Incoming{
                    .src_label = self.current_block_label,
                    .next_block = else_next,
                };
                try self.func.body.emitBranch(self.spv.gpa, merge_label);

                try self.beginSpvBlock(merge_label);
                const next_block = try self.structuredNextBlock(&.{ then_incoming, else_incoming });

                try self.structuredBreak(next_block);
            },
            .unstructured => {
                try self.func.body.emit(self.spv.gpa, .OpBranchConditional, .{
                    .condition = condition_id,
                    .true_label = then_label,
                    .false_label = else_label,
                });

                try self.beginSpvBlock(then_label);
                try self.genBody(then_body);
                try self.beginSpvBlock(else_label);
                try self.genBody(else_body);
            },
        }
    }

    fn airLoop(self: *DeclGen, inst: Air.Inst.Index) !void {
        const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
        const loop = self.air.extraData(Air.Block, ty_pl.payload);
        const body: []const Air.Inst.Index = @ptrCast(self.air.extra[loop.end..][0..loop.data.body_len]);

        const body_label = self.spv.allocId();

        switch (self.control_flow) {
            .structured => {
                const header_label = self.spv.allocId();
                const merge_label = self.spv.allocId();
                const continue_label = self.spv.allocId();

                // The back-edge must point to the loop header, so generate a separate block for the
                // loop header so that we don't accidentally include some instructions from there
                // in the loop.
                try self.func.body.emitBranch(self.spv.gpa, header_label);
                try self.beginSpvBlock(header_label);

                // Emit loop header and jump to loop body
                try self.func.body.emit(self.spv.gpa, .OpLoopMerge, .{
                    .merge_block = merge_label,
                    .continue_target = continue_label,
                    .loop_control = .{},
                });
                try self.func.body.emitBranch(self.spv.gpa, body_label);

                try self.beginSpvBlock(body_label);

                const next_block = try self.genStructuredBody(.{ .loop = .{
                    .merge_label = merge_label,
                    .continue_label = continue_label,
                } }, body);
                try self.structuredBreak(next_block);

                try self.beginSpvBlock(continue_label);
                try self.func.body.emitBranch(self.spv.gpa, header_label);
            },
            .unstructured => {
                try self.func.body.emitBranch(self.spv.gpa, body_label);
                try self.beginSpvBlock(body_label);
                try self.genBody(body);
                try self.func.body.emitBranch(self.spv.gpa, body_label);
            },
        }
    }

    fn airLoad(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        const mod = self.module;
        const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
        const ptr_ty = self.typeOf(ty_op.operand);
        const elem_ty = self.typeOfIndex(inst);
        const operand = try self.resolve(ty_op.operand);
        if (!ptr_ty.isVolatilePtr(mod) and self.liveness.isUnused(inst)) return null;

        return try self.load(elem_ty, operand, .{ .is_volatile = ptr_ty.isVolatilePtr(mod) });
    }

    fn airStore(self: *DeclGen, inst: Air.Inst.Index) !void {
        const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
        const ptr_ty = self.typeOf(bin_op.lhs);
        const elem_ty = ptr_ty.childType(self.module);
        const ptr = try self.resolve(bin_op.lhs);
        const value = try self.resolve(bin_op.rhs);

        try self.store(elem_ty, ptr, value, .{ .is_volatile = ptr_ty.isVolatilePtr(self.module) });
    }

    fn airRet(self: *DeclGen, inst: Air.Inst.Index) !void {
        const operand = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
        const ret_ty = self.typeOf(operand);
        const mod = self.module;
        if (!ret_ty.hasRuntimeBitsIgnoreComptime(mod)) {
            const decl = mod.declPtr(self.decl_index);
            const fn_info = mod.typeToFunc(decl.typeOf(mod)).?;
            if (Type.fromInterned(fn_info.return_type).isError(mod)) {
                // Functions with an empty error set are emitted with an error code
                // return type and return zero so they can be function pointers coerced
                // to functions that return anyerror.
                const no_err_id = try self.constInt(Type.anyerror, 0, .direct);
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
        const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
        const ptr_ty = self.typeOf(un_op);
        const ret_ty = ptr_ty.childType(mod);

        if (!ret_ty.hasRuntimeBitsIgnoreComptime(mod)) {
            const decl = mod.declPtr(self.decl_index);
            const fn_info = mod.typeToFunc(decl.typeOf(mod)).?;
            if (Type.fromInterned(fn_info.return_type).isError(mod)) {
                // Functions with an empty error set are emitted with an error code
                // return type and return zero so they can be function pointers coerced
                // to functions that return anyerror.
                const no_err_id = try self.constInt(Type.anyerror, 0, .direct);
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
        const pl_op = self.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
        const err_union_id = try self.resolve(pl_op.operand);
        const extra = self.air.extraData(Air.Try, pl_op.payload);
        const body: []const Air.Inst.Index = @ptrCast(self.air.extra[extra.end..][0..extra.data.body_len]);

        const err_union_ty = self.typeOf(pl_op.operand);
        const payload_ty = self.typeOfIndex(inst);

        const bool_ty_id = try self.resolveType(Type.bool, .direct);

        const eu_layout = self.errorUnionLayout(payload_ty);

        if (!err_union_ty.errorUnionSet(mod).errorSetIsEmpty(mod)) {
            const err_id = if (eu_layout.payload_has_bits)
                try self.extractField(Type.anyerror, err_union_id, eu_layout.errorFieldIndex())
            else
                err_union_id;

            const zero_id = try self.constInt(Type.anyerror, 0, .direct);
            const is_err_id = self.spv.allocId();
            try self.func.body.emit(self.spv.gpa, .OpINotEqual, .{
                .id_result_type = bool_ty_id,
                .id_result = is_err_id,
                .operand_1 = err_id,
                .operand_2 = zero_id,
            });

            // When there is an error, we must evaluate `body`. Otherwise we must continue
            // with the current body.
            // Just generate a new block here, then generate a new block inline for the remainder of the body.

            const err_block = self.spv.allocId();
            const ok_block = self.spv.allocId();

            switch (self.control_flow) {
                .structured => {
                    // According to AIR documentation, this block is guaranteed
                    // to not break and end in a return instruction. Thus,
                    // for structured control flow, we can just naively use
                    // the ok block as the merge block here.
                    try self.func.body.emit(self.spv.gpa, .OpSelectionMerge, .{
                        .merge_block = ok_block,
                        .selection_control = .{},
                    });
                },
                .unstructured => {},
            }

            try self.func.body.emit(self.spv.gpa, .OpBranchConditional, .{
                .condition = is_err_id,
                .true_label = err_block,
                .false_label = ok_block,
            });

            try self.beginSpvBlock(err_block);
            try self.genBody(body);

            try self.beginSpvBlock(ok_block);
        }

        if (!eu_layout.payload_has_bits) {
            return null;
        }

        // Now just extract the payload, if required.
        return try self.extractField(payload_ty, err_union_id, eu_layout.payloadFieldIndex());
    }

    fn airErrUnionErr(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        const mod = self.module;
        const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
        const operand_id = try self.resolve(ty_op.operand);
        const err_union_ty = self.typeOf(ty_op.operand);
        const err_ty_id = try self.resolveType(Type.anyerror, .direct);

        if (err_union_ty.errorUnionSet(mod).errorSetIsEmpty(mod)) {
            // No error possible, so just return undefined.
            return try self.spv.constUndef(err_ty_id);
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
        const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
        const operand_id = try self.resolve(ty_op.operand);
        const payload_ty = self.typeOfIndex(inst);
        const eu_layout = self.errorUnionLayout(payload_ty);

        if (!eu_layout.payload_has_bits) {
            return null; // No error possible.
        }

        return try self.extractField(payload_ty, operand_id, eu_layout.payloadFieldIndex());
    }

    fn airWrapErrUnionErr(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        const mod = self.module;
        const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
        const err_union_ty = self.typeOfIndex(inst);
        const payload_ty = err_union_ty.errorUnionPayload(mod);
        const operand_id = try self.resolve(ty_op.operand);
        const eu_layout = self.errorUnionLayout(payload_ty);

        if (!eu_layout.payload_has_bits) {
            return operand_id;
        }

        const payload_ty_id = try self.resolveType(payload_ty, .indirect);

        var members: [2]IdRef = undefined;
        members[eu_layout.errorFieldIndex()] = operand_id;
        members[eu_layout.payloadFieldIndex()] = try self.spv.constUndef(payload_ty_id);

        var types: [2]Type = undefined;
        types[eu_layout.errorFieldIndex()] = Type.anyerror;
        types[eu_layout.payloadFieldIndex()] = payload_ty;

        return try self.constructStruct(err_union_ty, &types, &members);
    }

    fn airWrapErrUnionPayload(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
        const err_union_ty = self.typeOfIndex(inst);
        const operand_id = try self.resolve(ty_op.operand);
        const payload_ty = self.typeOf(ty_op.operand);
        const eu_layout = self.errorUnionLayout(payload_ty);

        if (!eu_layout.payload_has_bits) {
            return try self.constInt(Type.anyerror, 0, .direct);
        }

        var members: [2]IdRef = undefined;
        members[eu_layout.errorFieldIndex()] = try self.constInt(Type.anyerror, 0, .direct);
        members[eu_layout.payloadFieldIndex()] = try self.convertToIndirect(payload_ty, operand_id);

        var types: [2]Type = undefined;
        types[eu_layout.errorFieldIndex()] = Type.anyerror;
        types[eu_layout.payloadFieldIndex()] = payload_ty;

        return try self.constructStruct(err_union_ty, &types, &members);
    }

    fn airIsNull(self: *DeclGen, inst: Air.Inst.Index, is_pointer: bool, pred: enum { is_null, is_non_null }) !?IdRef {
        const mod = self.module;
        const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
        const operand_id = try self.resolve(un_op);
        const operand_ty = self.typeOf(un_op);
        const optional_ty = if (is_pointer) operand_ty.childType(mod) else operand_ty;
        const payload_ty = optional_ty.optionalChild(mod);

        const bool_ty_id = try self.resolveType(Type.bool, .direct);

        if (optional_ty.optionalReprIsPayload(mod)) {
            // Pointer payload represents nullability: pointer or slice.
            const loaded_id = if (is_pointer)
                try self.load(optional_ty, operand_id, .{})
            else
                operand_id;

            const ptr_ty = if (payload_ty.isSlice(mod))
                payload_ty.slicePtrFieldType(mod)
            else
                payload_ty;

            const ptr_id = if (payload_ty.isSlice(mod))
                try self.extractField(ptr_ty, loaded_id, 0)
            else
                loaded_id;

            const payload_ty_id = try self.resolveType(ptr_ty, .direct);
            const null_id = try self.spv.constNull(payload_ty_id);
            const op: std.math.CompareOperator = switch (pred) {
                .is_null => .eq,
                .is_non_null => .neq,
            };
            return try self.cmp(op, Type.bool, ptr_ty, ptr_id, null_id);
        }

        const is_non_null_id = blk: {
            if (is_pointer) {
                if (payload_ty.hasRuntimeBitsIgnoreComptime(mod)) {
                    const storage_class = self.spvStorageClass(operand_ty.ptrAddressSpace(mod));
                    const bool_ptr_ty_id = try self.ptrType(Type.bool, storage_class);
                    const tag_ptr_id = try self.accessChain(bool_ptr_ty_id, operand_id, &.{1});
                    break :blk try self.load(Type.bool, tag_ptr_id, .{});
                }

                break :blk try self.load(Type.bool, operand_id, .{});
            }

            break :blk if (payload_ty.hasRuntimeBitsIgnoreComptime(mod))
                try self.extractField(Type.bool, operand_id, 1)
            else
                // Optional representation is bool indicating whether the optional is set
                // Optionals with no payload are represented as an (indirect) bool, so convert
                // it back to the direct bool here.
                try self.convertToDirect(Type.bool, operand_id);
        };

        return switch (pred) {
            .is_null => blk: {
                // Invert condition
                const result_id = self.spv.allocId();
                try self.func.body.emit(self.spv.gpa, .OpLogicalNot, .{
                    .id_result_type = bool_ty_id,
                    .id_result = result_id,
                    .operand = is_non_null_id,
                });
                break :blk result_id;
            },
            .is_non_null => is_non_null_id,
        };
    }

    fn airIsErr(self: *DeclGen, inst: Air.Inst.Index, pred: enum { is_err, is_non_err }) !?IdRef {
        const mod = self.module;
        const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
        const operand_id = try self.resolve(un_op);
        const err_union_ty = self.typeOf(un_op);

        if (err_union_ty.errorUnionSet(mod).errorSetIsEmpty(mod)) {
            return try self.constBool(pred == .is_non_err, .direct);
        }

        const payload_ty = err_union_ty.errorUnionPayload(mod);
        const eu_layout = self.errorUnionLayout(payload_ty);
        const bool_ty_id = try self.resolveType(Type.bool, .direct);

        const error_id = if (!eu_layout.payload_has_bits)
            operand_id
        else
            try self.extractField(Type.anyerror, operand_id, eu_layout.errorFieldIndex());

        const result_id = self.spv.allocId();
        const operands = .{
            .id_result_type = bool_ty_id,
            .id_result = result_id,
            .operand_1 = error_id,
            .operand_2 = try self.constInt(Type.anyerror, 0, .direct),
        };
        switch (pred) {
            .is_err => try self.func.body.emit(self.spv.gpa, .OpINotEqual, operands),
            .is_non_err => try self.func.body.emit(self.spv.gpa, .OpIEqual, operands),
        }
        return result_id;
    }

    fn airUnwrapOptional(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        const mod = self.module;
        const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
        const operand_id = try self.resolve(ty_op.operand);
        const optional_ty = self.typeOf(ty_op.operand);
        const payload_ty = self.typeOfIndex(inst);

        if (!payload_ty.hasRuntimeBitsIgnoreComptime(mod)) return null;

        if (optional_ty.optionalReprIsPayload(mod)) {
            return operand_id;
        }

        return try self.extractField(payload_ty, operand_id, 0);
    }

    fn airUnwrapOptionalPtr(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        const mod = self.module;
        const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
        const operand_id = try self.resolve(ty_op.operand);
        const operand_ty = self.typeOf(ty_op.operand);
        const optional_ty = operand_ty.childType(mod);
        const payload_ty = optional_ty.optionalChild(mod);
        const result_ty = self.typeOfIndex(inst);
        const result_ty_id = try self.resolveType(result_ty, .direct);

        if (!payload_ty.hasRuntimeBitsIgnoreComptime(mod)) {
            // There is no payload, but we still need to return a valid pointer.
            // We can just return anything here, so just return a pointer to the operand.
            return try self.bitCast(result_ty, operand_ty, operand_id);
        }

        if (optional_ty.optionalReprIsPayload(mod)) {
            // They are the same value.
            return try self.bitCast(result_ty, operand_ty, operand_id);
        }

        return try self.accessChain(result_ty_id, operand_id, &.{0});
    }

    fn airWrapOptional(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        const mod = self.module;
        const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
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
        const target = self.getTarget();
        const pl_op = self.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
        const cond_ty = self.typeOf(pl_op.operand);
        const cond = try self.resolve(pl_op.operand);
        var cond_indirect = try self.convertToIndirect(cond_ty, cond);
        const switch_br = self.air.extraData(Air.SwitchBr, pl_op.payload);

        const cond_words: u32 = switch (cond_ty.zigTypeTag(mod)) {
            .Bool, .ErrorSet => 1,
            .Int => blk: {
                const bits = cond_ty.intInfo(mod).bits;
                const backing_bits = self.backingIntBits(bits) orelse {
                    return self.todo("implement composite int switch", .{});
                };
                break :blk if (backing_bits <= 32) 1 else 2;
            },
            .Enum => blk: {
                const int_ty = cond_ty.intTagType(mod);
                const int_info = int_ty.intInfo(mod);
                const backing_bits = self.backingIntBits(int_info.bits) orelse {
                    return self.todo("implement composite int switch", .{});
                };
                break :blk if (backing_bits <= 32) 1 else 2;
            },
            .Pointer => blk: {
                cond_indirect = try self.intFromPtr(cond_indirect);
                break :blk target.ptrBitWidth() / 32;
            },
            // TODO: Figure out which types apply here, and work around them as we can only do integers.
            else => return self.todo("implement switch for type {s}", .{@tagName(cond_ty.zigTypeTag(mod))}),
        };

        const num_cases = switch_br.data.cases_len;

        // Compute the total number of arms that we need.
        // Zig switches are grouped by condition, so we need to loop through all of them
        const num_conditions = blk: {
            var extra_index: usize = switch_br.end;
            var num_conditions: u32 = 0;
            for (0..num_cases) |_| {
                const case = self.air.extraData(Air.SwitchBr.Case, extra_index);
                const case_body = self.air.extra[case.end + case.data.items_len ..][0..case.data.body_len];
                extra_index = case.end + case.data.items_len + case_body.len;
                num_conditions += case.data.items_len;
            }
            break :blk num_conditions;
        };

        // First, pre-allocate the labels for the cases.
        const case_labels = self.spv.allocIds(num_cases);
        // We always need the default case - if zig has none, we will generate unreachable there.
        const default = self.spv.allocId();

        const merge_label = switch (self.control_flow) {
            .structured => self.spv.allocId(),
            .unstructured => null,
        };

        if (self.control_flow == .structured) {
            try self.func.body.emit(self.spv.gpa, .OpSelectionMerge, .{
                .merge_block = merge_label.?,
                .selection_control = .{},
            });
        }

        // Emit the instruction before generating the blocks.
        try self.func.body.emitRaw(self.spv.gpa, .OpSwitch, 2 + (cond_words + 1) * num_conditions);
        self.func.body.writeOperand(IdRef, cond_indirect);
        self.func.body.writeOperand(IdRef, default);

        // Emit each of the cases
        {
            var extra_index: usize = switch_br.end;
            for (0..num_cases) |case_i| {
                // SPIR-V needs a literal here, which' width depends on the case condition.
                const case = self.air.extraData(Air.SwitchBr.Case, extra_index);
                const items: []const Air.Inst.Ref = @ptrCast(self.air.extra[case.end..][0..case.data.items_len]);
                const case_body = self.air.extra[case.end + items.len ..][0..case.data.body_len];
                extra_index = case.end + case.data.items_len + case_body.len;

                const label = case_labels.at(case_i);

                for (items) |item| {
                    const value = (try self.air.value(item, mod)) orelse unreachable;
                    const int_val: u64 = switch (cond_ty.zigTypeTag(mod)) {
                        .Bool, .Int => if (cond_ty.isSignedInt(mod)) @bitCast(value.toSignedInt(mod)) else value.toUnsignedInt(mod),
                        .Enum => blk: {
                            // TODO: figure out of cond_ty is correct (something with enum literals)
                            break :blk (try value.intFromEnum(cond_ty, mod)).toUnsignedInt(mod); // TODO: composite integer constants
                        },
                        .ErrorSet => value.getErrorInt(mod),
                        .Pointer => value.toUnsignedInt(mod),
                        else => unreachable,
                    };
                    const int_lit: spec.LiteralContextDependentNumber = switch (cond_words) {
                        1 => .{ .uint32 = @intCast(int_val) },
                        2 => .{ .uint64 = int_val },
                        else => unreachable,
                    };
                    self.func.body.writeOperand(spec.LiteralContextDependentNumber, int_lit);
                    self.func.body.writeOperand(IdRef, label);
                }
            }
        }

        var incoming_structured_blocks = std.ArrayListUnmanaged(ControlFlow.Structured.Block.Incoming){};
        defer incoming_structured_blocks.deinit(self.gpa);

        if (self.control_flow == .structured) {
            try incoming_structured_blocks.ensureUnusedCapacity(self.gpa, num_cases + 1);
        }

        // Now, finally, we can start emitting each of the cases.
        var extra_index: usize = switch_br.end;
        for (0..num_cases) |case_i| {
            const case = self.air.extraData(Air.SwitchBr.Case, extra_index);
            const items: []const Air.Inst.Ref = @ptrCast(self.air.extra[case.end..][0..case.data.items_len]);
            const case_body: []const Air.Inst.Index = @ptrCast(self.air.extra[case.end + items.len ..][0..case.data.body_len]);
            extra_index = case.end + case.data.items_len + case_body.len;

            const label = case_labels.at(case_i);

            try self.beginSpvBlock(label);

            switch (self.control_flow) {
                .structured => {
                    const next_block = try self.genStructuredBody(.selection, case_body);
                    incoming_structured_blocks.appendAssumeCapacity(.{
                        .src_label = self.current_block_label,
                        .next_block = next_block,
                    });
                    try self.func.body.emitBranch(self.spv.gpa, merge_label.?);
                },
                .unstructured => {
                    try self.genBody(case_body);
                },
            }
        }

        const else_body: []const Air.Inst.Index = @ptrCast(self.air.extra[extra_index..][0..switch_br.data.else_body_len]);
        try self.beginSpvBlock(default);
        if (else_body.len != 0) {
            switch (self.control_flow) {
                .structured => {
                    const next_block = try self.genStructuredBody(.selection, else_body);
                    incoming_structured_blocks.appendAssumeCapacity(.{
                        .src_label = self.current_block_label,
                        .next_block = next_block,
                    });
                    try self.func.body.emitBranch(self.spv.gpa, merge_label.?);
                },
                .unstructured => {
                    try self.genBody(else_body);
                },
            }
        } else {
            try self.func.body.emit(self.spv.gpa, .OpUnreachable, {});
        }

        if (self.control_flow == .structured) {
            try self.beginSpvBlock(merge_label.?);
            const next_block = try self.structuredNextBlock(incoming_structured_blocks.items);
            try self.structuredBreak(next_block);
        }
    }

    fn airUnreach(self: *DeclGen) !void {
        try self.func.body.emit(self.spv.gpa, .OpUnreachable, {});
    }

    fn airDbgStmt(self: *DeclGen, inst: Air.Inst.Index) !void {
        const dbg_stmt = self.air.instructions.items(.data)[@intFromEnum(inst)].dbg_stmt;
        const mod = self.module;
        const decl = mod.declPtr(self.decl_index);
        const path = decl.getFileScope(mod).sub_file_path;
        try self.func.body.emit(self.spv.gpa, .OpLine, .{
            .file = try self.spv.resolveString(path),
            .line = self.base_line + dbg_stmt.line + 1,
            .column = dbg_stmt.column + 1,
        });
    }

    fn airDbgInlineBlock(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        const mod = self.module;
        const inst_datas = self.air.instructions.items(.data);
        const extra = self.air.extraData(Air.DbgInlineBlock, inst_datas[@intFromEnum(inst)].ty_pl.payload);
        const decl = mod.funcOwnerDeclPtr(extra.data.func);
        const old_base_line = self.base_line;
        defer self.base_line = old_base_line;
        self.base_line = decl.src_line;
        return self.lowerBlock(inst, @ptrCast(self.air.extra[extra.end..][0..extra.data.body_len]));
    }

    fn airDbgVar(self: *DeclGen, inst: Air.Inst.Index) !void {
        const pl_op = self.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
        const target_id = try self.resolve(pl_op.operand);
        const name = self.air.nullTerminatedString(pl_op.payload);
        try self.spv.debugName(target_id, name);
    }

    fn airAssembly(self: *DeclGen, inst: Air.Inst.Index) !?IdRef {
        const mod = self.module;
        const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
        const extra = self.air.extraData(Air.Asm, ty_pl.payload);

        const is_volatile = @as(u1, @truncate(extra.data.flags >> 31)) != 0;
        const clobbers_len: u31 = @truncate(extra.data.flags);

        if (!is_volatile and self.liveness.isUnused(inst)) return null;

        var extra_i: usize = extra.end;
        const outputs: []const Air.Inst.Ref = @ptrCast(self.air.extra[extra_i..][0..extra.data.outputs_len]);
        extra_i += outputs.len;
        const inputs: []const Air.Inst.Ref = @ptrCast(self.air.extra[extra_i..][0..extra.data.inputs_len]);
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
                const src_loc = self.module.declPtr(self.decl_index).srcLoc(mod);
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
        const pl_op = self.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
        const extra = self.air.extraData(Air.Call, pl_op.payload);
        const args: []const Air.Inst.Ref = @ptrCast(self.air.extra[extra.end..][0..extra.data.args_len]);
        const callee_ty = self.typeOf(pl_op.operand);
        const zig_fn_ty = switch (callee_ty.zigTypeTag(mod)) {
            .Fn => callee_ty,
            .Pointer => return self.fail("cannot call function pointers", .{}),
            else => unreachable,
        };
        const fn_info = mod.typeToFunc(zig_fn_ty).?;
        const return_type = fn_info.return_type;

        const result_type_id = try self.resolveFnReturnType(Type.fromInterned(return_type));
        const result_id = self.spv.allocId();
        const callee_id = try self.resolve(pl_op.operand);

        comptime assert(zig_call_abi_ver == 3);
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
            .id_result_type = result_type_id,
            .id_result = result_id,
            .function = callee_id,
            .id_ref_3 = params[0..n_params],
        });

        if (return_type == .noreturn_type) {
            try self.func.body.emit(self.spv.gpa, .OpUnreachable, {});
        }

        if (self.liveness.isUnused(inst) or !Type.fromInterned(return_type).hasRuntimeBitsIgnoreComptime(mod)) {
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
