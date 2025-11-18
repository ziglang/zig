const std = @import("std");
const Allocator = std.mem.Allocator;
const Target = std.Target;
const Signedness = std.builtin.Signedness;
const assert = std.debug.assert;
const log = std.log.scoped(.codegen);

const Zcu = @import("../../Zcu.zig");
const Type = @import("../../Type.zig");
const Value = @import("../../Value.zig");
const Air = @import("../../Air.zig");
const InternPool = @import("../../InternPool.zig");
const Section = @import("Section.zig");
const Assembler = @import("Assembler.zig");

const spec = @import("spec.zig");
const Opcode = spec.Opcode;
const Word = spec.Word;
const Id = spec.Id;
const IdRange = spec.IdRange;
const StorageClass = spec.StorageClass;

const Module = @import("Module.zig");
const Decl = Module.Decl;
const Repr = Module.Repr;
const InternMap = Module.InternMap;
const PtrTypeMap = Module.PtrTypeMap;

const CodeGen = @This();

pub fn legalizeFeatures(_: *const std.Target) *const Air.Legalize.Features {
    return comptime &.initMany(&.{
        .expand_intcast_safe,
        .expand_int_from_float_safe,
        .expand_int_from_float_optimized_safe,
        .expand_add_safe,
        .expand_sub_safe,
        .expand_mul_safe,
    });
}

pub const zig_call_abi_ver = 3;

const ControlFlow = union(enum) {
    const Structured = struct {
        /// This type indicates the way that a block is terminated. The
        /// state of a particular block is used to track how a jump from
        /// inside the block must reach the outside.
        const Block = union(enum) {
            const Incoming = struct {
                src_label: Id,
                /// Instruction that returns an u32 value of the
                /// `Air.Inst.Index` that control flow should jump to.
                next_block: Id,
            };

            const SelectionMerge = struct {
                /// Incoming block from the `then` label.
                /// Note that hte incoming block from the `else` label is
                /// either given by the next element in the stack.
                incoming: Incoming,
                /// The label id of the cond_br's merge block.
                /// For the top-most element in the stack, this
                /// value is undefined.
                merge_block: Id,
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
                merge_stack: std.ArrayListUnmanaged(SelectionMerge) = .empty,
            },
            /// For a `loop` type block, we can early-exit the block by
            /// jumping to the loop exit node, and we don't need to generate
            /// an entire stack of merges.
            loop: struct {
                /// The next block to jump to can be determined from any number
                /// of conditions that jump to the loop exit.
                merges: std.ArrayListUnmanaged(Incoming) = .empty,
                /// The label id of the loop's merge block.
                merge_block: Id,
            },

            fn deinit(block: *Structured.Block, gpa: Allocator) void {
                switch (block.*) {
                    .selection => |*merge| merge.merge_stack.deinit(gpa),
                    .loop => |*merge| merge.merges.deinit(gpa),
                }
                block.* = undefined;
            }
        };
        /// This determines how exits from the current block must be handled.
        block_stack: std.ArrayListUnmanaged(*Structured.Block) = .empty,
        block_results: std.AutoHashMapUnmanaged(Air.Inst.Index, Id) = .empty,
    };

    const Unstructured = struct {
        const Incoming = struct {
            src_label: Id,
            break_value_id: Id,
        };

        const Block = struct {
            label: ?Id = null,
            incoming_blocks: std.ArrayListUnmanaged(Incoming) = .empty,
        };

        /// We need to keep track of result ids for block labels, as well as the 'incoming'
        /// blocks for a block.
        blocks: std.AutoHashMapUnmanaged(Air.Inst.Index, *Block) = .empty,
    };

    structured: Structured,
    unstructured: Unstructured,

    pub fn deinit(cg: *ControlFlow, gpa: Allocator) void {
        switch (cg.*) {
            .structured => |*cf| {
                cf.block_stack.deinit(gpa);
                cf.block_results.deinit(gpa);
            },
            .unstructured => |*cf| {
                cf.blocks.deinit(gpa);
            },
        }
        cg.* = undefined;
    }
};

pt: Zcu.PerThread,
air: Air,
liveness: Air.Liveness,
owner_nav: InternPool.Nav.Index,
module: *Module,
control_flow: ControlFlow,
base_line: u32,
block_label: Id = .none,
next_arg_index: u32 = 0,
args: std.ArrayListUnmanaged(Id) = .empty,
inst_results: std.AutoHashMapUnmanaged(Air.Inst.Index, Id) = .empty,
id_scratch: std.ArrayListUnmanaged(Id) = .empty,
prologue: Section = .{},
body: Section = .{},
error_msg: ?*Zcu.ErrorMsg = null,

pub fn deinit(cg: *CodeGen) void {
    const gpa = cg.module.gpa;
    cg.control_flow.deinit(gpa);
    cg.args.deinit(gpa);
    cg.inst_results.deinit(gpa);
    cg.id_scratch.deinit(gpa);
    cg.prologue.deinit(gpa);
    cg.body.deinit(gpa);
}

const Error = error{ CodegenFail, OutOfMemory };

pub fn genNav(cg: *CodeGen, do_codegen: bool) Error!void {
    const gpa = cg.module.gpa;
    const zcu = cg.module.zcu;
    const ip = &zcu.intern_pool;
    const target = zcu.getTarget();

    const nav = ip.getNav(cg.owner_nav);
    const val = zcu.navValue(cg.owner_nav);
    const ty = val.typeOf(zcu);

    if (!do_codegen and !ty.hasRuntimeBits(zcu)) return;

    const spv_decl_index = try cg.module.resolveNav(ip, cg.owner_nav);
    const decl = cg.module.declPtr(spv_decl_index);
    const result_id = decl.result_id;
    decl.begin_dep = cg.module.decl_deps.items.len;

    switch (decl.kind) {
        .func => {
            const fn_info = zcu.typeToFunc(ty).?;
            const return_ty_id = try cg.resolveFnReturnType(.fromInterned(fn_info.return_type));
            const is_test = zcu.test_functions.contains(cg.owner_nav);

            const func_result_id = if (is_test) cg.module.allocId() else result_id;
            const prototype_ty_id = try cg.resolveType(ty, .direct);
            try cg.prologue.emit(gpa, .OpFunction, .{
                .id_result_type = return_ty_id,
                .id_result = func_result_id,
                .function_type = prototype_ty_id,
                // Note: the backend will never be asked to generate an inline function
                // (this is handled in sema), so we don't need to set function_control here.
                .function_control = .{},
            });

            comptime assert(zig_call_abi_ver == 3);
            try cg.args.ensureUnusedCapacity(gpa, fn_info.param_types.len);
            for (fn_info.param_types.get(ip)) |param_ty_index| {
                const param_ty: Type = .fromInterned(param_ty_index);
                if (!param_ty.hasRuntimeBitsIgnoreComptime(zcu)) continue;

                const param_type_id = try cg.resolveType(param_ty, .direct);
                const arg_result_id = cg.module.allocId();
                try cg.prologue.emit(gpa, .OpFunctionParameter, .{
                    .id_result_type = param_type_id,
                    .id_result = arg_result_id,
                });
                cg.args.appendAssumeCapacity(arg_result_id);
            }

            // TODO: This could probably be done in a better way...
            const root_block_id = cg.module.allocId();

            // The root block of a function declaration should appear before OpVariable instructions,
            // so it is generated into the function's prologue.
            try cg.prologue.emit(gpa, .OpLabel, .{
                .id_result = root_block_id,
            });
            cg.block_label = root_block_id;

            const main_body = cg.air.getMainBody();
            switch (cg.control_flow) {
                .structured => {
                    _ = try cg.genStructuredBody(.selection, main_body);
                    // We always expect paths to here to end, but we still need the block
                    // to act as a dummy merge block.
                    try cg.body.emit(gpa, .OpUnreachable, {});
                },
                .unstructured => {
                    try cg.genBody(main_body);
                },
            }
            try cg.body.emit(gpa, .OpFunctionEnd, {});
            // Append the actual code into the functions section.
            try cg.module.sections.functions.append(gpa, cg.prologue);
            try cg.module.sections.functions.append(gpa, cg.body);

            // Temporarily generate a test kernel declaration if this is a test function.
            if (is_test) {
                try cg.generateTestEntryPoint(nav.fqn.toSlice(ip), spv_decl_index, func_result_id);
            }

            try cg.module.debugName(func_result_id, nav.fqn.toSlice(ip));
        },
        .global => {
            assert(ip.indexToKey(val.toIntern()) == .@"extern");

            const storage_class = cg.module.storageClass(nav.getAddrspace());
            assert(storage_class != .generic); // These should be instance globals

            const ty_id = try cg.resolveType(ty, .indirect);
            const ptr_ty_id = try cg.module.ptrType(ty_id, storage_class);

            try cg.module.sections.globals.emit(gpa, .OpVariable, .{
                .id_result_type = ptr_ty_id,
                .id_result = result_id,
                .storage_class = storage_class,
            });

            switch (target.os.tag) {
                .vulkan, .opengl => {
                    if (ty.zigTypeTag(zcu) == .@"struct") {
                        switch (storage_class) {
                            .uniform, .push_constant => try cg.module.decorate(ty_id, .block),
                            else => {},
                        }
                    }

                    switch (ip.indexToKey(ty.toIntern())) {
                        .func_type, .opaque_type => {},
                        else => {
                            try cg.module.decorate(ptr_ty_id, .{
                                .array_stride = .{ .array_stride = @intCast(ty.abiSize(zcu)) },
                            });
                        },
                    }
                },
                else => {},
            }

            if (std.meta.stringToEnum(spec.BuiltIn, nav.fqn.toSlice(ip))) |builtin| {
                try cg.module.decorate(result_id, .{ .built_in = .{ .built_in = builtin } });
            }

            try cg.module.debugName(result_id, nav.fqn.toSlice(ip));
        },
        .invocation_global => {
            const maybe_init_val: ?Value = switch (ip.indexToKey(val.toIntern())) {
                .func => unreachable,
                .variable => |variable| .fromInterned(variable.init),
                .@"extern" => null,
                else => val,
            };

            const ty_id = try cg.resolveType(ty, .indirect);
            const ptr_ty_id = try cg.module.ptrType(ty_id, .function);

            if (maybe_init_val) |init_val| {
                // TODO: Combine with resolveAnonDecl?
                const void_ty_id = try cg.resolveType(.void, .direct);
                const initializer_proto_ty_id = try cg.module.functionType(void_ty_id, &.{});

                const initializer_id = cg.module.allocId();
                try cg.prologue.emit(gpa, .OpFunction, .{
                    .id_result_type = try cg.resolveType(.void, .direct),
                    .id_result = initializer_id,
                    .function_control = .{},
                    .function_type = initializer_proto_ty_id,
                });

                const root_block_id = cg.module.allocId();
                try cg.prologue.emit(gpa, .OpLabel, .{
                    .id_result = root_block_id,
                });
                cg.block_label = root_block_id;

                const val_id = try cg.constant(ty, init_val, .indirect);
                try cg.body.emit(gpa, .OpStore, .{
                    .pointer = result_id,
                    .object = val_id,
                });

                try cg.body.emit(gpa, .OpReturn, {});
                try cg.body.emit(gpa, .OpFunctionEnd, {});
                try cg.module.sections.functions.append(gpa, cg.prologue);
                try cg.module.sections.functions.append(gpa, cg.body);

                try cg.module.debugNameFmt(initializer_id, "initializer of {f}", .{nav.fqn.fmt(ip)});

                try cg.module.sections.globals.emit(gpa, .OpExtInst, .{
                    .id_result_type = ptr_ty_id,
                    .id_result = result_id,
                    .set = try cg.module.importInstructionSet(.zig),
                    .instruction = .{ .inst = @intFromEnum(spec.Zig.InvocationGlobal) },
                    .id_ref_4 = &.{initializer_id},
                });
            } else {
                try cg.module.sections.globals.emit(gpa, .OpExtInst, .{
                    .id_result_type = ptr_ty_id,
                    .id_result = result_id,
                    .set = try cg.module.importInstructionSet(.zig),
                    .instruction = .{ .inst = @intFromEnum(spec.Zig.InvocationGlobal) },
                    .id_ref_4 = &.{},
                });
            }
        },
    }

    cg.module.declPtr(spv_decl_index).end_dep = cg.module.decl_deps.items.len;
}

pub fn fail(cg: *CodeGen, comptime format: []const u8, args: anytype) Error {
    @branchHint(.cold);
    const zcu = cg.module.zcu;
    const src_loc = zcu.navSrcLoc(cg.owner_nav);
    assert(cg.error_msg == null);
    cg.error_msg = try Zcu.ErrorMsg.create(zcu.gpa, src_loc, format, args);
    return error.CodegenFail;
}

pub fn todo(cg: *CodeGen, comptime format: []const u8, args: anytype) Error {
    return cg.fail("TODO (SPIR-V): " ++ format, args);
}

/// This imports the "default" extended instruction set for the target
/// For OpenCL, OpenCL.std.100. For Vulkan and OpenGL, GLSL.std.450.
fn importExtendedSet(cg: *CodeGen) !Id {
    const target = cg.module.zcu.getTarget();
    return switch (target.os.tag) {
        .opencl, .amdhsa => try cg.module.importInstructionSet(.@"OpenCL.std"),
        .vulkan, .opengl => try cg.module.importInstructionSet(.@"GLSL.std.450"),
        else => unreachable,
    };
}

/// Fetch the result-id for a previously generated instruction or constant.
fn resolve(cg: *CodeGen, inst: Air.Inst.Ref) !Id {
    const pt = cg.pt;
    const zcu = cg.module.zcu;
    const ip = &zcu.intern_pool;
    if (try cg.air.value(inst, pt)) |val| {
        const ty = cg.typeOf(inst);
        if (ty.zigTypeTag(zcu) == .@"fn") {
            const fn_nav = switch (zcu.intern_pool.indexToKey(val.ip_index)) {
                .@"extern" => |@"extern"| @"extern".owner_nav,
                .func => |func| func.owner_nav,
                else => unreachable,
            };
            const spv_decl_index = try cg.module.resolveNav(ip, fn_nav);
            try cg.module.decl_deps.append(cg.module.gpa, spv_decl_index);
            return cg.module.declPtr(spv_decl_index).result_id;
        }

        return try cg.constant(ty, val, .direct);
    }
    const index = inst.toIndex().?;
    return cg.inst_results.get(index).?; // Assertion means instruction does not dominate usage.
}

fn resolveUav(cg: *CodeGen, val: InternPool.Index) !Id {
    const gpa = cg.module.gpa;

    // TODO: This cannot be a function at this point, but it should probably be handled anyway.

    const zcu = cg.module.zcu;
    const ty: Type = .fromInterned(zcu.intern_pool.typeOf(val));
    const ty_id = try cg.resolveType(ty, .indirect);

    const spv_decl_index = blk: {
        const entry = try cg.module.uav_link.getOrPut(gpa, .{ val, .function });
        if (entry.found_existing) {
            try cg.addFunctionDep(entry.value_ptr.*, .function);
            return cg.module.declPtr(entry.value_ptr.*).result_id;
        }

        const spv_decl_index = try cg.module.allocDecl(.invocation_global);
        try cg.addFunctionDep(spv_decl_index, .function);
        entry.value_ptr.* = spv_decl_index;
        break :blk spv_decl_index;
    };

    // TODO: At some point we will be able to generate this all constant here, but then all of
    //   constant() will need to be implemented such that it doesn't generate any at-runtime code.
    // NOTE: Because this is a global, we really only want to initialize it once. Therefore the
    //   constant lowering of this value will need to be deferred to an initializer similar to
    //   other globals.

    const result_id = cg.module.declPtr(spv_decl_index).result_id;

    {
        // Save the current state so that we can temporarily generate into a different function.
        // TODO: This should probably be made a little more robust.
        const func_prologue = cg.prologue;
        const func_body = cg.body;
        const block_label = cg.block_label;
        defer {
            cg.prologue = func_prologue;
            cg.body = func_body;
            cg.block_label = block_label;
        }

        cg.prologue = .{};
        cg.body = .{};
        defer {
            cg.prologue.deinit(gpa);
            cg.body.deinit(gpa);
        }

        const void_ty_id = try cg.resolveType(.void, .direct);
        const initializer_proto_ty_id = try cg.module.functionType(void_ty_id, &.{});

        const initializer_id = cg.module.allocId();
        try cg.prologue.emit(gpa, .OpFunction, .{
            .id_result_type = try cg.resolveType(.void, .direct),
            .id_result = initializer_id,
            .function_control = .{},
            .function_type = initializer_proto_ty_id,
        });
        const root_block_id = cg.module.allocId();
        try cg.prologue.emit(gpa, .OpLabel, .{
            .id_result = root_block_id,
        });
        cg.block_label = root_block_id;

        const val_id = try cg.constant(ty, .fromInterned(val), .indirect);
        try cg.body.emit(gpa, .OpStore, .{
            .pointer = result_id,
            .object = val_id,
        });

        try cg.body.emit(gpa, .OpReturn, {});
        try cg.body.emit(gpa, .OpFunctionEnd, {});

        try cg.module.sections.functions.append(gpa, cg.prologue);
        try cg.module.sections.functions.append(gpa, cg.body);

        try cg.module.debugNameFmt(initializer_id, "initializer of __anon_{d}", .{@intFromEnum(val)});

        const fn_decl_ptr_ty_id = try cg.module.ptrType(ty_id, .function);
        try cg.module.sections.globals.emit(gpa, .OpExtInst, .{
            .id_result_type = fn_decl_ptr_ty_id,
            .id_result = result_id,
            .set = try cg.module.importInstructionSet(.zig),
            .instruction = .{ .inst = @intFromEnum(spec.Zig.InvocationGlobal) },
            .id_ref_4 = &.{initializer_id},
        });
    }

    return result_id;
}

fn addFunctionDep(cg: *CodeGen, decl_index: Module.Decl.Index, storage_class: StorageClass) !void {
    const gpa = cg.module.gpa;
    const target = cg.module.zcu.getTarget();
    if (target.cpu.has(.spirv, .v1_4)) {
        try cg.module.decl_deps.append(gpa, decl_index);
    } else {
        // Before version 1.4, the interface’s storage classes are limited to the Input and Output
        if (storage_class == .input or storage_class == .output) {
            try cg.module.decl_deps.append(gpa, decl_index);
        }
    }
}

/// Start a new SPIR-V block, Emits the label of the new block, and stores which
/// block we are currently generating.
/// Note that there is no such thing as nested blocks like in ZIR or AIR, so we don't need to
/// keep track of the previous block.
fn beginSpvBlock(cg: *CodeGen, label: Id) !void {
    try cg.body.emit(cg.module.gpa, .OpLabel, .{ .id_result = label });
    cg.block_label = label;
}

/// Return the amount of bits in the largest supported integer type. This is either 32 (always supported), or 64 (if
/// the Int64 capability is enabled).
/// Note: The extension SPV_INTEL_arbitrary_precision_integers allows any integer size (at least up to 32 bits).
/// In theory that could also be used, but since the spec says that it only guarantees support up to 32-bit ints there
/// is no way of knowing whether those are actually supported.
/// TODO: Maybe this should be cached?
fn largestSupportedIntBits(cg: *CodeGen) u16 {
    const target = cg.module.zcu.getTarget();
    if (target.cpu.has(.spirv, .int64) or target.cpu.arch == .spirv64) {
        return 64;
    }
    return 32;
}

const ArithmeticTypeInfo = struct {
    const Class = enum {
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

    /// A classification of the inner type.
    /// These scenarios will all have to be handled slightly different.
    class: Class,
    /// The number of bits in the inner type.
    /// This is the actual number of bits of the type, not the size of the backing integer.
    bits: u16,
    /// The number of bits required to store the type.
    /// For `integer` and `float`, this is equal to `bits`.
    /// For `strange_integer` and `bool` this is the size of the backing integer.
    /// For `composite_integer` this is the elements count.
    backing_bits: u16,
    /// Null if this type is a scalar, or the length of the vector otherwise.
    vector_len: ?u32,
    /// Whether the inner type is signed. Only relevant for integers.
    signedness: std.builtin.Signedness,
};

fn arithmeticTypeInfo(cg: *CodeGen, ty: Type) ArithmeticTypeInfo {
    const zcu = cg.module.zcu;
    const target = cg.module.zcu.getTarget();
    var scalar_ty = ty.scalarType(zcu);
    if (scalar_ty.zigTypeTag(zcu) == .@"enum") {
        scalar_ty = scalar_ty.intTagType(zcu);
    }
    const vector_len = if (ty.isVector(zcu)) ty.vectorLen(zcu) else null;
    return switch (scalar_ty.zigTypeTag(zcu)) {
        .bool => .{
            .bits = 1, // Doesn't matter for this class.
            .backing_bits = cg.module.backingIntBits(1).@"0",
            .vector_len = vector_len,
            .signedness = .unsigned, // Technically, but doesn't matter for this class.
            .class = .bool,
        },
        .float => .{
            .bits = scalar_ty.floatBits(target),
            .backing_bits = scalar_ty.floatBits(target), // TODO: F80?
            .vector_len = vector_len,
            .signedness = .signed, // Technically, but doesn't matter for this class.
            .class = .float,
        },
        .int => blk: {
            const int_info = scalar_ty.intInfo(zcu);
            // TODO: Maybe it's useful to also return this value.
            const backing_bits, const big_int = cg.module.backingIntBits(int_info.bits);
            break :blk .{
                .bits = int_info.bits,
                .backing_bits = backing_bits,
                .vector_len = vector_len,
                .signedness = int_info.signedness,
                .class = class: {
                    if (big_int) break :class .composite_integer;
                    break :class if (backing_bits == int_info.bits) .integer else .strange_integer;
                },
            };
        },
        .@"enum" => unreachable,
        .vector => unreachable,
        else => unreachable, // Unhandled arithmetic type
    };
}

/// Checks whether the type can be directly translated to SPIR-V vectors
fn isSpvVector(cg: *CodeGen, ty: Type) bool {
    const zcu = cg.module.zcu;
    const target = cg.module.zcu.getTarget();
    if (ty.zigTypeTag(zcu) != .vector) return false;

    // TODO: This check must be expanded for types that can be represented
    // as integers (enums / packed structs?) and types that are represented
    // by multiple SPIR-V values.
    const scalar_ty = ty.scalarType(zcu);
    switch (scalar_ty.zigTypeTag(zcu)) {
        .bool,
        .int,
        .float,
        => {},
        else => return false,
    }

    const elem_ty = ty.childType(zcu);
    const len = ty.vectorLen(zcu);

    if (elem_ty.isNumeric(zcu) or elem_ty.toIntern() == .bool_type) {
        if (len > 1 and len <= 4) return true;
        if (target.cpu.has(.spirv, .vector16)) return (len == 8 or len == 16);
    }

    return false;
}

/// Emits a bool constant in a particular representation.
fn constBool(cg: *CodeGen, value: bool, repr: Repr) !Id {
    return switch (repr) {
        .indirect => cg.constInt(.u1, @intFromBool(value)),
        .direct => cg.module.constBool(value),
    };
}

/// Emits an integer constant.
/// This function, unlike Module.constInt, takes care to bitcast
/// the value to an unsigned int first for Kernels.
fn constInt(cg: *CodeGen, ty: Type, value: anytype) !Id {
    const zcu = cg.module.zcu;
    const target = cg.module.zcu.getTarget();
    const scalar_ty = ty.scalarType(zcu);
    const int_info = scalar_ty.intInfo(zcu);
    // Use backing bits so that negatives are sign extended
    const backing_bits, const big_int = cg.module.backingIntBits(int_info.bits);
    assert(backing_bits != 0); // u0 is comptime

    const result_ty_id = try cg.resolveType(scalar_ty, .indirect);
    const signedness: Signedness = switch (@typeInfo(@TypeOf(value))) {
        .int => |int| int.signedness,
        .comptime_int => if (value < 0) .signed else .unsigned,
        else => unreachable,
    };
    if (@sizeOf(@TypeOf(value)) >= 4 and big_int) {
        const value64: u64 = switch (signedness) {
            .signed => @bitCast(@as(i64, @intCast(value))),
            .unsigned => @as(u64, @intCast(value)),
        };
        assert(backing_bits == 64);
        return cg.constructComposite(result_ty_id, &.{
            try cg.constInt(.u32, @as(u32, @truncate(value64))),
            try cg.constInt(.u32, @as(u32, @truncate(value64 << 32))),
        });
    }

    const final_value: spec.LiteralContextDependentNumber = switch (target.os.tag) {
        .opencl, .amdhsa => blk: {
            const value64: u64 = switch (signedness) {
                .signed => @bitCast(@as(i64, @intCast(value))),
                .unsigned => @as(u64, @intCast(value)),
            };

            // Manually truncate the value to the right amount of bits.
            const truncated_value = if (backing_bits == 64)
                value64
            else
                value64 & (@as(u64, 1) << @intCast(backing_bits)) - 1;

            break :blk switch (backing_bits) {
                1...32 => .{ .uint32 = @truncate(truncated_value) },
                33...64 => .{ .uint64 = truncated_value },
                else => unreachable,
            };
        },
        else => switch (backing_bits) {
            1...32 => if (signedness == .signed) .{ .int32 = @intCast(value) } else .{ .uint32 = @intCast(value) },
            33...64 => if (signedness == .signed) .{ .int64 = value } else .{ .uint64 = value },
            else => unreachable,
        },
    };

    const result_id = try cg.module.constant(result_ty_id, final_value);

    if (!ty.isVector(zcu)) return result_id;
    return cg.constructCompositeSplat(ty, result_id);
}

pub fn constructComposite(cg: *CodeGen, result_ty_id: Id, constituents: []const Id) !Id {
    const gpa = cg.module.gpa;
    const result_id = cg.module.allocId();
    try cg.body.emit(gpa, .OpCompositeConstruct, .{
        .id_result_type = result_ty_id,
        .id_result = result_id,
        .constituents = constituents,
    });
    return result_id;
}

/// Construct a composite at runtime with all lanes set to the same value.
/// ty must be an aggregate type.
fn constructCompositeSplat(cg: *CodeGen, ty: Type, constituent: Id) !Id {
    const gpa = cg.module.gpa;
    const zcu = cg.module.zcu;
    const n: usize = @intCast(ty.arrayLen(zcu));

    const scratch_top = cg.id_scratch.items.len;
    defer cg.id_scratch.shrinkRetainingCapacity(scratch_top);

    const constituents = try cg.id_scratch.addManyAsSlice(gpa, n);
    @memset(constituents, constituent);

    const result_ty_id = try cg.resolveType(ty, .direct);
    return cg.constructComposite(result_ty_id, constituents);
}

/// This function generates a load for a constant in direct (ie, non-memory) representation.
/// When the constant is simple, it can be generated directly using OpConstant instructions.
/// When the constant is more complicated however, it needs to be constructed using multiple values. This
/// is done by emitting a sequence of instructions that initialize the value.
//
/// This function should only be called during function code generation.
fn constant(cg: *CodeGen, ty: Type, val: Value, repr: Repr) Error!Id {
    const gpa = cg.module.gpa;

    // Note: Using intern_map can only be used with constants that DO NOT generate any runtime code!!
    // Ideally that should be all constants in the future, or it should be cleaned up somehow. For
    // now, only use the intern_map on case-by-case basis by breaking to :cache.
    if (cg.module.intern_map.get(.{ val.toIntern(), repr })) |id| {
        return id;
    }

    const pt = cg.pt;
    const zcu = cg.module.zcu;
    const target = cg.module.zcu.getTarget();
    const result_ty_id = try cg.resolveType(ty, repr);
    const ip = &zcu.intern_pool;

    log.debug("lowering constant: ty = {f}, val = {f}, key = {s}", .{ ty.fmt(pt), val.fmtValue(pt), @tagName(ip.indexToKey(val.toIntern())) });
    if (val.isUndef(zcu)) {
        return cg.module.constUndef(result_ty_id);
    }

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
            .tuple_type,
            .union_type,
            .opaque_type,
            .enum_type,
            .func_type,
            .error_set_type,
            .inferred_error_set_type,
            => unreachable, // types, not values

            .undef => unreachable, // handled above

            .variable,
            .@"extern",
            .func,
            .enum_literal,
            .empty_enum_value,
            => unreachable, // non-runtime values

            .simple_value => |simple_value| switch (simple_value) {
                .undefined,
                .void,
                .null,
                .empty_tuple,
                .@"unreachable",
                => unreachable, // non-runtime values

                .false, .true => break :cache try cg.constBool(val.toBool(), repr),
            },
            .int => {
                if (ty.isSignedInt(zcu)) {
                    break :cache try cg.constInt(ty, val.toSignedInt(zcu));
                } else {
                    break :cache try cg.constInt(ty, val.toUnsignedInt(zcu));
                }
            },
            .float => {
                const lit: spec.LiteralContextDependentNumber = switch (ty.floatBits(target)) {
                    16 => .{ .uint32 = @as(u16, @bitCast(val.toFloat(f16, zcu))) },
                    32 => .{ .float32 = val.toFloat(f32, zcu) },
                    64 => .{ .float64 = val.toFloat(f64, zcu) },
                    80, 128 => unreachable, // TODO
                    else => unreachable,
                };
                break :cache try cg.module.constant(result_ty_id, lit);
            },
            .err => |err| {
                const value = try pt.getErrorValue(err.name);
                break :cache try cg.constInt(ty, value);
            },
            .error_union => |error_union| {
                // TODO: Error unions may be constructed with constant instructions if the payload type
                // allows it. For now, just generate it here regardless.
                const err_ty = ty.errorUnionSet(zcu);
                const payload_ty = ty.errorUnionPayload(zcu);
                const err_val_id = switch (error_union.val) {
                    .err_name => |err_name| try cg.constInt(
                        err_ty,
                        try pt.getErrorValue(err_name),
                    ),
                    .payload => try cg.constInt(err_ty, 0),
                };
                const eu_layout = cg.errorUnionLayout(payload_ty);
                if (!eu_layout.payload_has_bits) {
                    // We use the error type directly as the type.
                    break :cache err_val_id;
                }

                const payload_val_id = switch (error_union.val) {
                    .err_name => try cg.constant(payload_ty, .undef, .indirect),
                    .payload => |p| try cg.constant(payload_ty, .fromInterned(p), .indirect),
                };

                var constituents: [2]Id = undefined;
                var types: [2]Type = undefined;
                if (eu_layout.error_first) {
                    constituents[0] = err_val_id;
                    constituents[1] = payload_val_id;
                    types = .{ err_ty, payload_ty };
                } else {
                    constituents[0] = payload_val_id;
                    constituents[1] = err_val_id;
                    types = .{ payload_ty, err_ty };
                }

                const comp_ty_id = try cg.resolveType(ty, .direct);
                return try cg.constructComposite(comp_ty_id, &constituents);
            },
            .enum_tag => {
                const int_val = try val.intFromEnum(ty, pt);
                const int_ty = ty.intTagType(zcu);
                break :cache try cg.constant(int_ty, int_val, repr);
            },
            .ptr => return cg.constantPtr(val),
            .slice => |slice| {
                const ptr_id = try cg.constantPtr(.fromInterned(slice.ptr));
                const len_id = try cg.constant(.usize, .fromInterned(slice.len), .indirect);
                const comp_ty_id = try cg.resolveType(ty, .direct);
                return try cg.constructComposite(comp_ty_id, &.{ ptr_id, len_id });
            },
            .opt => {
                const payload_ty = ty.optionalChild(zcu);
                const maybe_payload_val = val.optionalValue(zcu);

                if (!payload_ty.hasRuntimeBits(zcu)) {
                    break :cache try cg.constBool(maybe_payload_val != null, .indirect);
                } else if (ty.optionalReprIsPayload(zcu)) {
                    // Optional representation is a nullable pointer or slice.
                    if (maybe_payload_val) |payload_val| {
                        return try cg.constant(payload_ty, payload_val, .indirect);
                    } else {
                        break :cache try cg.module.constNull(result_ty_id);
                    }
                }

                // Optional representation is a structure.
                // { Payload, Bool }

                const has_pl_id = try cg.constBool(maybe_payload_val != null, .indirect);
                const payload_id = if (maybe_payload_val) |payload_val|
                    try cg.constant(payload_ty, payload_val, .indirect)
                else
                    try cg.module.constUndef(try cg.resolveType(payload_ty, .indirect));

                const comp_ty_id = try cg.resolveType(ty, .direct);
                return try cg.constructComposite(comp_ty_id, &.{ payload_id, has_pl_id });
            },
            .aggregate => |aggregate| switch (ip.indexToKey(ty.ip_index)) {
                inline .array_type, .vector_type => |array_type, tag| {
                    const elem_ty: Type = .fromInterned(array_type.child);

                    const scratch_top = cg.id_scratch.items.len;
                    defer cg.id_scratch.shrinkRetainingCapacity(scratch_top);
                    const constituents = try cg.id_scratch.addManyAsSlice(gpa, @intCast(ty.arrayLenIncludingSentinel(zcu)));

                    const child_repr: Repr = switch (tag) {
                        .array_type => .indirect,
                        .vector_type => .direct,
                        else => unreachable,
                    };

                    switch (aggregate.storage) {
                        .bytes => |bytes| {
                            // TODO: This is really space inefficient, perhaps there is a better
                            // way to do it?
                            for (constituents, bytes.toSlice(constituents.len, ip)) |*constituent, byte| {
                                constituent.* = try cg.constInt(elem_ty, byte);
                            }
                        },
                        .elems => |elems| {
                            for (constituents, elems) |*constituent, elem| {
                                constituent.* = try cg.constant(elem_ty, .fromInterned(elem), child_repr);
                            }
                        },
                        .repeated_elem => |elem| {
                            @memset(constituents, try cg.constant(elem_ty, .fromInterned(elem), child_repr));
                        },
                    }

                    const comp_ty_id = try cg.resolveType(ty, .direct);
                    return cg.constructComposite(comp_ty_id, constituents);
                },
                .struct_type => {
                    const struct_type = zcu.typeToStruct(ty).?;

                    if (struct_type.layout == .@"packed") {
                        // TODO: composite int
                        // TODO: endianness
                        const bits: u16 = @intCast(ty.bitSize(zcu));
                        const bytes = std.mem.alignForward(u16, cg.module.backingIntBits(bits).@"0", 8) / 8;
                        var limbs: [8]u8 = undefined;
                        @memset(&limbs, 0);
                        val.writeToPackedMemory(ty, pt, limbs[0..bytes], 0) catch unreachable;
                        const backing_ty: Type = .fromInterned(struct_type.backingIntTypeUnordered(ip));
                        return try cg.constInt(backing_ty, @as(u64, @bitCast(limbs)));
                    }

                    var types = std.array_list.Managed(Type).init(gpa);
                    defer types.deinit();

                    var constituents = std.array_list.Managed(Id).init(gpa);
                    defer constituents.deinit();

                    var it = struct_type.iterateRuntimeOrder(ip);
                    while (it.next()) |field_index| {
                        const field_ty: Type = .fromInterned(struct_type.field_types.get(ip)[field_index]);
                        if (!field_ty.hasRuntimeBitsIgnoreComptime(zcu)) {
                            // This is a zero-bit field - we only needed it for the alignment.
                            continue;
                        }

                        // TODO: Padding?
                        const field_val = try val.fieldValue(pt, field_index);
                        const field_id = try cg.constant(field_ty, field_val, .indirect);

                        try types.append(field_ty);
                        try constituents.append(field_id);
                    }

                    const comp_ty_id = try cg.resolveType(ty, .direct);
                    return try cg.constructComposite(comp_ty_id, constituents.items);
                },
                .tuple_type => return cg.todo("implement tuple types", .{}),
                else => unreachable,
            },
            .un => |un| {
                if (un.tag == .none) {
                    assert(ty.containerLayout(zcu) == .@"packed"); // TODO
                    const int_ty = try pt.intType(.unsigned, @intCast(ty.bitSize(zcu)));
                    return try cg.constInt(int_ty, Value.toUnsignedInt(.fromInterned(un.val), zcu));
                }
                const active_field = ty.unionTagFieldIndex(.fromInterned(un.tag), zcu).?;
                const union_obj = zcu.typeToUnion(ty).?;
                const field_ty: Type = .fromInterned(union_obj.field_types.get(ip)[active_field]);
                const payload = if (field_ty.hasRuntimeBitsIgnoreComptime(zcu))
                    try cg.constant(field_ty, .fromInterned(un.val), .direct)
                else
                    null;
                return try cg.unionInit(ty, active_field, payload);
            },
            .memoized_call => unreachable,
        }
    };

    try cg.module.intern_map.putNoClobber(gpa, .{ val.toIntern(), repr }, cacheable_id);

    return cacheable_id;
}

fn constantPtr(cg: *CodeGen, ptr_val: Value) !Id {
    const pt = cg.pt;
    const zcu = cg.module.zcu;
    const gpa = cg.module.gpa;

    if (ptr_val.isUndef(zcu)) {
        const result_ty = ptr_val.typeOf(zcu);
        const result_ty_id = try cg.resolveType(result_ty, .direct);
        return cg.module.constUndef(result_ty_id);
    }

    var arena = std.heap.ArenaAllocator.init(gpa);
    defer arena.deinit();

    const derivation = try ptr_val.pointerDerivation(arena.allocator(), pt);
    return cg.derivePtr(derivation);
}

fn derivePtr(cg: *CodeGen, derivation: Value.PointerDeriveStep) !Id {
    const gpa = cg.module.gpa;
    const pt = cg.pt;
    const zcu = cg.module.zcu;
    const target = zcu.getTarget();
    switch (derivation) {
        .comptime_alloc_ptr, .comptime_field_ptr => unreachable,
        .int => |int| {
            if (target.os.tag != .opencl) {
                if (int.ptr_ty.ptrAddressSpace(zcu) != .physical_storage_buffer) {
                    return cg.fail(
                        "cannot cast integer to pointer with address space '{s}'",
                        .{@tagName(int.ptr_ty.ptrAddressSpace(zcu))},
                    );
                }
            }
            const result_ty_id = try cg.resolveType(int.ptr_ty, .direct);
            // TODO: This can probably be an OpSpecConstantOp Bitcast, but
            // that is not implemented by Mesa yet. Therefore, just generate it
            // as a runtime operation.
            const result_ptr_id = cg.module.allocId();
            const value_id = try cg.constInt(.usize, int.addr);
            try cg.body.emit(gpa, .OpConvertUToPtr, .{
                .id_result_type = result_ty_id,
                .id_result = result_ptr_id,
                .integer_value = value_id,
            });
            return result_ptr_id;
        },
        .nav_ptr => |nav| {
            const result_ptr_ty = try pt.navPtrType(nav);
            return cg.constantNavRef(result_ptr_ty, nav);
        },
        .uav_ptr => |uav| {
            const result_ptr_ty: Type = .fromInterned(uav.orig_ty);
            return cg.constantUavRef(result_ptr_ty, uav);
        },
        .eu_payload_ptr => @panic("TODO"),
        .opt_payload_ptr => @panic("TODO"),
        .field_ptr => |field| {
            const parent_ptr_id = try cg.derivePtr(field.parent.*);
            const parent_ptr_ty = try field.parent.ptrType(pt);
            return cg.structFieldPtr(field.result_ptr_ty, parent_ptr_ty, parent_ptr_id, field.field_idx);
        },
        .elem_ptr => |elem| {
            const parent_ptr_id = try cg.derivePtr(elem.parent.*);
            const parent_ptr_ty = try elem.parent.ptrType(pt);
            const index_id = try cg.constInt(.usize, elem.elem_idx);
            return cg.ptrElemPtr(parent_ptr_ty, parent_ptr_id, index_id);
        },
        .offset_and_cast => |oac| {
            const parent_ptr_id = try cg.derivePtr(oac.parent.*);
            const parent_ptr_ty = try oac.parent.ptrType(pt);
            const result_ty_id = try cg.resolveType(oac.new_ptr_ty, .direct);
            const child_size = oac.new_ptr_ty.childType(zcu).abiSize(zcu);

            if (parent_ptr_ty.childType(zcu).isVector(zcu) and oac.byte_offset % child_size == 0) {
                // Vector element ptr accesses are derived as offset_and_cast.
                // We can just use OpAccessChain.
                return cg.accessChain(
                    result_ty_id,
                    parent_ptr_id,
                    &.{@intCast(@divExact(oac.byte_offset, child_size))},
                );
            }

            if (oac.byte_offset == 0) {
                // Allow changing the pointer type child only to restructure arrays.
                // e.g. [3][2]T to T is fine, as is [2]T -> [2][1]T.
                const result_ptr_id = cg.module.allocId();
                try cg.body.emit(gpa, .OpBitcast, .{
                    .id_result_type = result_ty_id,
                    .id_result = result_ptr_id,
                    .operand = parent_ptr_id,
                });
                return result_ptr_id;
            }

            return cg.fail("cannot perform pointer cast: '{f}' to '{f}'", .{
                parent_ptr_ty.fmt(pt),
                oac.new_ptr_ty.fmt(pt),
            });
        },
    }
}

fn constantUavRef(
    cg: *CodeGen,
    ty: Type,
    uav: InternPool.Key.Ptr.BaseAddr.Uav,
) !Id {
    // TODO: Merge this function with constantDeclRef.

    const zcu = cg.module.zcu;
    const ip = &zcu.intern_pool;
    const ty_id = try cg.resolveType(ty, .direct);
    const uav_ty: Type = .fromInterned(ip.typeOf(uav.val));

    switch (ip.indexToKey(uav.val)) {
        .func => unreachable, // TODO
        .@"extern" => assert(!ip.isFunctionType(uav_ty.toIntern())),
        else => {},
    }

    // const is_fn_body = decl_ty.zigTypeTag(zcu) == .@"fn";
    if (!uav_ty.isFnOrHasRuntimeBitsIgnoreComptime(zcu)) {
        // Pointer to nothing - return undefined
        return cg.module.constUndef(ty_id);
    }

    // Uav refs are always generic.
    assert(ty.ptrAddressSpace(zcu) == .generic);
    const uav_ty_id = try cg.resolveType(uav_ty, .indirect);
    const decl_ptr_ty_id = try cg.module.ptrType(uav_ty_id, .function);
    const ptr_id = try cg.resolveUav(uav.val);

    if (decl_ptr_ty_id != ty_id) {
        // Differing pointer types, insert a cast.
        const casted_ptr_id = cg.module.allocId();
        try cg.body.emit(cg.module.gpa, .OpBitcast, .{
            .id_result_type = ty_id,
            .id_result = casted_ptr_id,
            .operand = ptr_id,
        });
        return casted_ptr_id;
    } else {
        return ptr_id;
    }
}

fn constantNavRef(cg: *CodeGen, ty: Type, nav_index: InternPool.Nav.Index) !Id {
    const zcu = cg.module.zcu;
    const ip = &zcu.intern_pool;
    const ty_id = try cg.resolveType(ty, .direct);
    const nav = ip.getNav(nav_index);
    const nav_ty: Type = .fromInterned(nav.typeOf(ip));

    switch (nav.status) {
        .unresolved => unreachable,
        .type_resolved => {}, // this is not a function or extern
        .fully_resolved => |r| switch (ip.indexToKey(r.val)) {
            .func => {
                // TODO: Properly lower function pointers. For now we are going to hack around it and
                // just generate an empty pointer. Function pointers are represented by a pointer to usize.
                return try cg.module.constUndef(ty_id);
            },
            .@"extern" => if (ip.isFunctionType(nav_ty.toIntern())) @panic("TODO"),
            else => {},
        },
    }

    if (!nav_ty.isFnOrHasRuntimeBitsIgnoreComptime(zcu)) {
        // Pointer to nothing - return undefined.
        return cg.module.constUndef(ty_id);
    }

    const spv_decl_index = try cg.module.resolveNav(ip, nav_index);
    const spv_decl = cg.module.declPtr(spv_decl_index);
    const spv_decl_result_id = spv_decl.result_id;
    assert(spv_decl.kind != .func);

    const storage_class = cg.module.storageClass(nav.getAddrspace());
    try cg.addFunctionDep(spv_decl_index, storage_class);

    const nav_ty_id = try cg.resolveType(nav_ty, .indirect);
    const decl_ptr_ty_id = try cg.module.ptrType(nav_ty_id, storage_class);

    if (decl_ptr_ty_id != ty_id) {
        // Differing pointer types, insert a cast.
        const casted_ptr_id = cg.module.allocId();
        try cg.body.emit(cg.module.gpa, .OpBitcast, .{
            .id_result_type = ty_id,
            .id_result = casted_ptr_id,
            .operand = spv_decl_result_id,
        });
        return casted_ptr_id;
    }

    return spv_decl_result_id;
}

// Turn a Zig type's name into a cache reference.
fn resolveTypeName(cg: *CodeGen, ty: Type) ![]const u8 {
    const gpa = cg.module.gpa;
    var aw: std.Io.Writer.Allocating = .init(gpa);
    defer aw.deinit();
    ty.print(&aw.writer, cg.pt, null) catch |err| switch (err) {
        error.WriteFailed => return error.OutOfMemory,
    };
    return try aw.toOwnedSlice();
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
fn resolveUnionType(cg: *CodeGen, ty: Type) !Id {
    const gpa = cg.module.gpa;
    const zcu = cg.module.zcu;
    const ip = &zcu.intern_pool;
    const union_obj = zcu.typeToUnion(ty).?;

    if (union_obj.flagsUnordered(ip).layout == .@"packed") {
        return try cg.module.intType(.unsigned, @intCast(ty.bitSize(zcu)));
    }

    const layout = cg.unionLayout(ty);
    if (!layout.has_payload) {
        // No payload, so represent this as just the tag type.
        return try cg.resolveType(.fromInterned(union_obj.enum_tag_ty), .indirect);
    }

    var member_types: [4]Id = undefined;
    var member_names: [4][]const u8 = undefined;

    const u8_ty_id = try cg.resolveType(.u8, .direct);

    if (layout.tag_size != 0) {
        const tag_ty_id = try cg.resolveType(.fromInterned(union_obj.enum_tag_ty), .indirect);
        member_types[layout.tag_index] = tag_ty_id;
        member_names[layout.tag_index] = "(tag)";
    }

    if (layout.payload_size != 0) {
        const payload_ty_id = try cg.resolveType(layout.payload_ty, .indirect);
        member_types[layout.payload_index] = payload_ty_id;
        member_names[layout.payload_index] = "(payload)";
    }

    if (layout.payload_padding_size != 0) {
        const len_id = try cg.constInt(.u32, layout.payload_padding_size);
        const payload_padding_ty_id = try cg.module.arrayType(len_id, u8_ty_id);
        member_types[layout.payload_padding_index] = payload_padding_ty_id;
        member_names[layout.payload_padding_index] = "(payload padding)";
    }

    if (layout.padding_size != 0) {
        const len_id = try cg.constInt(.u32, layout.padding_size);
        const padding_ty_id = try cg.module.arrayType(len_id, u8_ty_id);
        member_types[layout.padding_index] = padding_ty_id;
        member_names[layout.padding_index] = "(padding)";
    }

    const result_id = try cg.module.structType(
        member_types[0..layout.total_fields],
        member_names[0..layout.total_fields],
        null,
        .none,
    );

    const type_name = try cg.resolveTypeName(ty);
    defer gpa.free(type_name);
    try cg.module.debugName(result_id, type_name);

    return result_id;
}

fn resolveFnReturnType(cg: *CodeGen, ret_ty: Type) !Id {
    const zcu = cg.module.zcu;
    if (!ret_ty.hasRuntimeBitsIgnoreComptime(zcu)) {
        // If the return type is an error set or an error union, then we make this
        // anyerror return type instead, so that it can be coerced into a function
        // pointer type which has anyerror as the return type.
        if (ret_ty.isError(zcu)) {
            return cg.resolveType(.anyerror, .direct);
        } else {
            return cg.resolveType(.void, .direct);
        }
    }

    return try cg.resolveType(ret_ty, .direct);
}

fn resolveType(cg: *CodeGen, ty: Type, repr: Repr) Error!Id {
    const gpa = cg.module.gpa;
    const pt = cg.pt;
    const zcu = cg.module.zcu;
    const ip = &zcu.intern_pool;
    const target = cg.module.zcu.getTarget();

    log.debug("resolveType: ty = {f}", .{ty.fmt(pt)});

    switch (ty.zigTypeTag(zcu)) {
        .noreturn => {
            assert(repr == .direct);
            return try cg.module.voidType();
        },
        .void => switch (repr) {
            .direct => return try cg.module.voidType(),
            .indirect => {
                if (target.os.tag != .opencl) return cg.fail("cannot generate opaque type", .{});
                return try cg.module.opaqueType("void");
            },
        },
        .bool => switch (repr) {
            .direct => return try cg.module.boolType(),
            .indirect => return try cg.resolveType(.u1, .indirect),
        },
        .int => {
            const int_info = ty.intInfo(zcu);
            if (int_info.bits == 0) {
                assert(repr == .indirect);
                if (target.os.tag != .opencl) return cg.fail("cannot generate opaque type", .{});
                return try cg.module.opaqueType("u0");
            }
            return try cg.module.intType(int_info.signedness, int_info.bits);
        },
        .@"enum" => return try cg.resolveType(ty.intTagType(zcu), repr),
        .float => {
            const bits = ty.floatBits(target);
            const supported = switch (bits) {
                16 => target.cpu.has(.spirv, .float16),
                32 => true,
                64 => target.cpu.has(.spirv, .float64),
                else => false,
            };

            if (!supported) {
                return cg.fail(
                    "floating point width of {} bits is not supported for the current SPIR-V feature set",
                    .{bits},
                );
            }

            return try cg.module.floatType(bits);
        },
        .array => {
            const elem_ty = ty.childType(zcu);
            const elem_ty_id = try cg.resolveType(elem_ty, .indirect);
            const total_len = std.math.cast(u32, ty.arrayLenIncludingSentinel(zcu)) orelse {
                return cg.fail("array type of {} elements is too large", .{ty.arrayLenIncludingSentinel(zcu)});
            };

            if (!elem_ty.hasRuntimeBitsIgnoreComptime(zcu)) {
                assert(repr == .indirect);
                if (target.os.tag != .opencl) return cg.fail("cannot generate opaque type", .{});
                return try cg.module.opaqueType("zero-sized-array");
            } else if (total_len == 0) {
                // The size of the array would be 0, but that is not allowed in SPIR-V.
                // This path can be reached for example when there is a slicing of a pointer
                // that produces a zero-length array. In all cases where this type can be generated,
                // this should be an indirect path.
                assert(repr == .indirect);
                // In this case, we have an array of a non-zero sized type. In this case,
                // generate an array of 1 element instead, so that ptr_elem_ptr instructions
                // can be lowered to ptrAccessChain instead of manually performing the math.
                const len_id = try cg.constInt(.u32, 1);
                return try cg.module.arrayType(len_id, elem_ty_id);
            } else {
                const total_len_id = try cg.constInt(.u32, total_len);
                const result_id = try cg.module.arrayType(total_len_id, elem_ty_id);
                switch (target.os.tag) {
                    .vulkan, .opengl => {
                        try cg.module.decorate(result_id, .{
                            .array_stride = .{
                                .array_stride = @intCast(elem_ty.abiSize(zcu)),
                            },
                        });
                    },
                    else => {},
                }
                return result_id;
            }
        },
        .vector => {
            const elem_ty = ty.childType(zcu);
            const elem_ty_id = try cg.resolveType(elem_ty, repr);
            const len = ty.vectorLen(zcu);
            if (cg.isSpvVector(ty)) return try cg.module.vectorType(len, elem_ty_id);
            const len_id = try cg.constInt(.u32, len);
            return try cg.module.arrayType(len_id, elem_ty_id);
        },
        .@"fn" => switch (repr) {
            .direct => {
                const fn_info = zcu.typeToFunc(ty).?;

                comptime assert(zig_call_abi_ver == 3);
                assert(!fn_info.is_var_args);
                switch (fn_info.cc) {
                    .auto,
                    .spirv_kernel,
                    .spirv_fragment,
                    .spirv_vertex,
                    .spirv_device,
                    => {},
                    else => unreachable,
                }

                const return_ty_id = try cg.resolveFnReturnType(.fromInterned(fn_info.return_type));

                const scratch_top = cg.id_scratch.items.len;
                defer cg.id_scratch.shrinkRetainingCapacity(scratch_top);
                const param_ty_ids = try cg.id_scratch.addManyAsSlice(gpa, fn_info.param_types.len);

                var param_index: usize = 0;
                for (fn_info.param_types.get(ip)) |param_ty_index| {
                    const param_ty: Type = .fromInterned(param_ty_index);
                    if (!param_ty.hasRuntimeBitsIgnoreComptime(zcu)) continue;

                    param_ty_ids[param_index] = try cg.resolveType(param_ty, .direct);
                    param_index += 1;
                }

                return try cg.module.functionType(return_ty_id, param_ty_ids[0..param_index]);
            },
            .indirect => {
                // TODO: Represent function pointers properly.
                // For now, just use an usize type.
                return try cg.resolveType(.usize, .indirect);
            },
        },
        .pointer => {
            const ptr_info = ty.ptrInfo(zcu);

            const child_ty: Type = .fromInterned(ptr_info.child);
            const child_ty_id = try cg.resolveType(child_ty, .indirect);
            const storage_class = cg.module.storageClass(ptr_info.flags.address_space);
            const ptr_ty_id = try cg.module.ptrType(child_ty_id, storage_class);

            if (ptr_info.flags.size != .slice) {
                return ptr_ty_id;
            }

            const size_ty_id = try cg.resolveType(.usize, .direct);
            return try cg.module.structType(
                &.{ ptr_ty_id, size_ty_id },
                &.{ "ptr", "len" },
                null,
                .none,
            );
        },
        .@"struct" => {
            const struct_type = switch (ip.indexToKey(ty.toIntern())) {
                .tuple_type => |tuple| {
                    const scratch_top = cg.id_scratch.items.len;
                    defer cg.id_scratch.shrinkRetainingCapacity(scratch_top);
                    const member_types = try cg.id_scratch.addManyAsSlice(gpa, tuple.values.len);

                    var member_index: usize = 0;
                    for (tuple.types.get(ip), tuple.values.get(ip)) |field_ty, field_val| {
                        if (field_val != .none or !Type.fromInterned(field_ty).hasRuntimeBits(zcu)) continue;

                        member_types[member_index] = try cg.resolveType(.fromInterned(field_ty), .indirect);
                        member_index += 1;
                    }

                    const result_id = try cg.module.structType(
                        member_types[0..member_index],
                        null,
                        null,
                        .none,
                    );
                    const type_name = try cg.resolveTypeName(ty);
                    defer gpa.free(type_name);
                    try cg.module.debugName(result_id, type_name);
                    return result_id;
                },
                .struct_type => ip.loadStructType(ty.toIntern()),
                else => unreachable,
            };

            if (struct_type.layout == .@"packed") {
                return try cg.resolveType(.fromInterned(struct_type.backingIntTypeUnordered(ip)), .direct);
            }

            var member_types = std.array_list.Managed(Id).init(gpa);
            defer member_types.deinit();

            var member_names = std.array_list.Managed([]const u8).init(gpa);
            defer member_names.deinit();

            var member_offsets = std.array_list.Managed(u32).init(gpa);
            defer member_offsets.deinit();

            var it = struct_type.iterateRuntimeOrder(ip);
            while (it.next()) |field_index| {
                const field_ty: Type = .fromInterned(struct_type.field_types.get(ip)[field_index]);
                if (!field_ty.hasRuntimeBitsIgnoreComptime(zcu)) continue;

                const field_name = struct_type.fieldName(ip, field_index);
                try member_types.append(try cg.resolveType(field_ty, .indirect));
                try member_names.append(field_name.toSlice(ip));
                try member_offsets.append(@intCast(ty.structFieldOffset(field_index, zcu)));
            }

            const result_id = try cg.module.structType(
                member_types.items,
                member_names.items,
                member_offsets.items,
                ty.toIntern(),
            );

            const type_name = try cg.resolveTypeName(ty);
            defer gpa.free(type_name);
            try cg.module.debugName(result_id, type_name);

            return result_id;
        },
        .optional => {
            const payload_ty = ty.optionalChild(zcu);
            if (!payload_ty.hasRuntimeBitsIgnoreComptime(zcu)) {
                // Just use a bool.
                // Note: Always generate the bool with indirect format, to save on some sanity
                // Perform the conversion to a direct bool when the field is extracted.
                return try cg.resolveType(.bool, .indirect);
            }

            const payload_ty_id = try cg.resolveType(payload_ty, .indirect);
            if (ty.optionalReprIsPayload(zcu)) {
                // Optional is actually a pointer or a slice.
                return payload_ty_id;
            }

            const bool_ty_id = try cg.resolveType(.bool, .indirect);

            return try cg.module.structType(
                &.{ payload_ty_id, bool_ty_id },
                &.{ "payload", "valid" },
                null,
                .none,
            );
        },
        .@"union" => return try cg.resolveUnionType(ty),
        .error_set => {
            const err_int_ty = try pt.errorIntType();
            return try cg.resolveType(err_int_ty, repr);
        },
        .error_union => {
            const payload_ty = ty.errorUnionPayload(zcu);
            const err_ty = ty.errorUnionSet(zcu);
            const error_ty_id = try cg.resolveType(err_ty, .indirect);

            const eu_layout = cg.errorUnionLayout(payload_ty);
            if (!eu_layout.payload_has_bits) {
                return error_ty_id;
            }

            const payload_ty_id = try cg.resolveType(payload_ty, .indirect);

            var member_types: [2]Id = undefined;
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

            return try cg.module.structType(&member_types, &member_names, null, .none);
        },
        .@"opaque" => {
            if (target.os.tag != .opencl) return cg.fail("cannot generate opaque type", .{});
            const type_name = try cg.resolveTypeName(ty);
            defer gpa.free(type_name);
            return try cg.module.opaqueType(type_name);
        },

        .null,
        .undefined,
        .enum_literal,
        .comptime_float,
        .comptime_int,
        .type,
        => unreachable, // Must be comptime.

        .frame, .@"anyframe" => unreachable, // TODO
    }
}

const ErrorUnionLayout = struct {
    payload_has_bits: bool,
    error_first: bool,

    fn errorFieldIndex(cg: @This()) u32 {
        assert(cg.payload_has_bits);
        return if (cg.error_first) 0 else 1;
    }

    fn payloadFieldIndex(cg: @This()) u32 {
        assert(cg.payload_has_bits);
        return if (cg.error_first) 1 else 0;
    }
};

fn errorUnionLayout(cg: *CodeGen, payload_ty: Type) ErrorUnionLayout {
    const zcu = cg.module.zcu;

    const error_align = Type.abiAlignment(.anyerror, zcu);
    const payload_align = payload_ty.abiAlignment(zcu);

    const error_first = error_align.compare(.gt, payload_align);
    return .{
        .payload_has_bits = payload_ty.hasRuntimeBitsIgnoreComptime(zcu),
        .error_first = error_first,
    };
}

const UnionLayout = struct {
    /// If false, this union is represented
    /// by only an integer of the tag type.
    has_payload: bool,
    tag_size: u32,
    tag_index: u32,
    /// Note: This is the size of the payload type itcg, NOT the size of the ENTIRE payload.
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

fn unionLayout(cg: *CodeGen, ty: Type) UnionLayout {
    const zcu = cg.module.zcu;
    const ip = &zcu.intern_pool;
    const layout = ty.unionGetLayout(zcu);
    const union_obj = zcu.typeToUnion(ty).?;

    var union_layout: UnionLayout = .{
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
        const most_aligned_field_ty: Type = .fromInterned(union_obj.field_types.get(ip)[most_aligned_field]);
        union_layout.payload_ty = most_aligned_field_ty;
        union_layout.payload_size = @intCast(most_aligned_field_ty.abiSize(zcu));
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

/// This structure represents a "temporary" value: Something we are currently
/// operating on. It typically lives no longer than the function that
/// implements a particular AIR operation. These are used to easier
/// implement vectorizable operations (see Vectorization and the build*
/// functions), and typically are only used for vectors of primitive types.
const Temporary = struct {
    /// The type of the temporary. This is here mainly
    /// for easier bookkeeping. Because we will never really
    /// store Temporaries, they only cause extra stack space,
    /// therefore no real storage is wasted.
    ty: Type,
    /// The value that this temporary holds. This is not necessarily
    /// a value that is actually usable, or a single value: It is virtual
    /// until materialize() is called, at which point is turned into
    /// the usual SPIR-V representation of `cg.ty`.
    value: Temporary.Value,

    const Value = union(enum) {
        singleton: Id,
        exploded_vector: IdRange,
    };

    fn init(ty: Type, singleton: Id) Temporary {
        return .{ .ty = ty, .value = .{ .singleton = singleton } };
    }

    fn materialize(temp: Temporary, cg: *CodeGen) !Id {
        const gpa = cg.module.gpa;
        const zcu = cg.module.zcu;
        switch (temp.value) {
            .singleton => |id| return id,
            .exploded_vector => |range| {
                assert(temp.ty.isVector(zcu));
                assert(temp.ty.vectorLen(zcu) == range.len);

                const scratch_top = cg.id_scratch.items.len;
                defer cg.id_scratch.shrinkRetainingCapacity(scratch_top);
                const constituents = try cg.id_scratch.addManyAsSlice(gpa, range.len);
                for (constituents, 0..range.len) |*id, i| {
                    id.* = range.at(i);
                }

                const result_ty_id = try cg.resolveType(temp.ty, .direct);
                return cg.constructComposite(result_ty_id, constituents);
            },
        }
    }

    fn vectorization(temp: Temporary, cg: *CodeGen) Vectorization {
        return .fromType(temp.ty, cg);
    }

    fn pun(temp: Temporary, new_ty: Type) Temporary {
        return .{
            .ty = new_ty,
            .value = temp.value,
        };
    }

    /// 'Explode' a temporary into separate elements. This turns a vector
    /// into a bag of elements.
    fn explode(temp: Temporary, cg: *CodeGen) !IdRange {
        const zcu = cg.module.zcu;

        // If the value is a scalar, then this is a no-op.
        if (!temp.ty.isVector(zcu)) {
            return switch (temp.value) {
                .singleton => |id| .{ .base = @intFromEnum(id), .len = 1 },
                .exploded_vector => |range| range,
            };
        }

        const ty_id = try cg.resolveType(temp.ty.scalarType(zcu), .direct);
        const n = temp.ty.vectorLen(zcu);
        const results = cg.module.allocIds(n);

        const id = switch (temp.value) {
            .singleton => |id| id,
            .exploded_vector => |range| return range,
        };

        for (0..n) |i| {
            const indexes = [_]u32{@intCast(i)};
            try cg.body.emit(cg.module.gpa, .OpCompositeExtract, .{
                .id_result_type = ty_id,
                .id_result = results.at(i),
                .composite = id,
                .indexes = &indexes,
            });
        }

        return results;
    }
};

/// Initialize a `Temporary` from an AIR value.
fn temporary(cg: *CodeGen, inst: Air.Inst.Ref) !Temporary {
    return .{
        .ty = cg.typeOf(inst),
        .value = .{ .singleton = try cg.resolve(inst) },
    };
}

/// This union describes how a particular operation should be vectorized.
/// That depends on the operation and number of components of the inputs.
const Vectorization = union(enum) {
    /// This is an operation between scalars.
    scalar,
    /// This operation is unrolled into separate operations.
    /// Inputs may still be SPIR-V vectors, for example,
    /// when the operation can't be vectorized in SPIR-V.
    /// Value is number of components.
    unrolled: u32,

    /// Derive a vectorization from a particular type
    fn fromType(ty: Type, cg: *CodeGen) Vectorization {
        const zcu = cg.module.zcu;
        if (!ty.isVector(zcu)) return .scalar;
        return .{ .unrolled = ty.vectorLen(zcu) };
    }

    /// Given two vectorization methods, compute a "unification": a fallback
    /// that works for both, according to the following rules:
    /// - Scalars may broadcast
    /// - SPIR-V vectorized operations will unroll
    /// - Prefer scalar > unrolled
    fn unify(a: Vectorization, b: Vectorization) Vectorization {
        if (a == .scalar and b == .scalar) return .scalar;
        if (a == .unrolled or b == .unrolled) {
            if (a == .unrolled and b == .unrolled) assert(a.components() == b.components());
            if (a == .unrolled) return .{ .unrolled = a.components() };
            return .{ .unrolled = b.components() };
        }
        unreachable;
    }

    /// Query the number of components that inputs of this operation have.
    /// Note: for broadcasting scalars, this returns the number of elements
    /// that the broadcasted vector would have.
    fn components(vec: Vectorization) u32 {
        return switch (vec) {
            .scalar => 1,
            .unrolled => |n| n,
        };
    }

    /// Turns `ty` into the result-type of the entire operation.
    /// `ty` may be a scalar or vector, it doesn't matter.
    fn resultType(vec: Vectorization, cg: *CodeGen, ty: Type) !Type {
        const pt = cg.pt;
        const zcu = cg.module.zcu;
        const scalar_ty = ty.scalarType(zcu);
        return switch (vec) {
            .scalar => scalar_ty,
            .unrolled => |n| try pt.vectorType(.{ .len = n, .child = scalar_ty.toIntern() }),
        };
    }

    /// Before a temporary can be used, some setup may need to be one. This function implements
    /// this setup, and returns a new type that holds the relevant information on how to access
    /// elements of the input.
    fn prepare(vec: Vectorization, cg: *CodeGen, tmp: Temporary) !PreparedOperand {
        const zcu = cg.module.zcu;
        const is_vector = tmp.ty.isVector(zcu);
        const value: PreparedOperand.Value = switch (tmp.value) {
            .singleton => |id| switch (vec) {
                .scalar => blk: {
                    assert(!is_vector);
                    break :blk .{ .scalar = id };
                },
                .unrolled => blk: {
                    if (is_vector) break :blk .{ .vector_exploded = try tmp.explode(cg) };
                    break :blk .{ .scalar_broadcast = id };
                },
            },
            .exploded_vector => |range| switch (vec) {
                .scalar => unreachable,
                .unrolled => |n| blk: {
                    assert(range.len == n);
                    break :blk .{ .vector_exploded = range };
                },
            },
        };

        return .{
            .ty = tmp.ty,
            .value = value,
        };
    }

    /// Finalize the results of an operation back into a temporary. `results` is
    /// a list of result-ids of the operation.
    fn finalize(vec: Vectorization, ty: Type, results: IdRange) Temporary {
        assert(vec.components() == results.len);
        return .{
            .ty = ty,
            .value = switch (vec) {
                .scalar => .{ .singleton = results.at(0) },
                .unrolled => .{ .exploded_vector = results },
            },
        };
    }

    /// This struct represents an operand that has gone through some setup, and is
    /// ready to be used as part of an operation.
    const PreparedOperand = struct {
        ty: Type,
        value: PreparedOperand.Value,

        /// The types of value that a prepared operand can hold internally. Depends
        /// on the operation and input value.
        const Value = union(enum) {
            /// A single scalar value that is used by a scalar operation.
            scalar: Id,
            /// A single scalar that is broadcasted in an unrolled operation.
            scalar_broadcast: Id,
            /// A vector represented by a consecutive list of IDs that is used in an unrolled operation.
            vector_exploded: IdRange,
        };

        /// Query the value at a particular index of the operation. Note that
        /// the index is *not* the component/lane, but the index of the *operation*.
        fn at(op: PreparedOperand, i: usize) Id {
            switch (op.value) {
                .scalar => |id| {
                    assert(i == 0);
                    return id;
                },
                .scalar_broadcast => |id| return id,
                .vector_exploded => |range| return range.at(i),
            }
        }
    };
};

/// A utility function to compute the vectorization style of
/// a list of values. These values may be any of the following:
/// - A `Vectorization` instance
/// - A Type, in which case the vectorization is computed via `Vectorization.fromType`.
/// - A Temporary, in which case the vectorization is computed via `Temporary.vectorization`.
fn vectorization(cg: *CodeGen, args: anytype) Vectorization {
    var v: Vectorization = undefined;
    assert(args.len >= 1);
    inline for (args, 0..) |arg, i| {
        const iv: Vectorization = switch (@TypeOf(arg)) {
            Vectorization => arg,
            Type => Vectorization.fromType(arg, cg),
            Temporary => arg.vectorization(cg),
            else => @compileError("invalid type"),
        };
        if (i == 0) {
            v = iv;
        } else {
            v = v.unify(iv);
        }
    }
    return v;
}

/// This function builds an OpSConvert of OpUConvert depending on the
/// signedness of the types.
fn buildConvert(cg: *CodeGen, dst_ty: Type, src: Temporary) !Temporary {
    const zcu = cg.module.zcu;

    const dst_ty_id = try cg.resolveType(dst_ty.scalarType(zcu), .direct);
    const src_ty_id = try cg.resolveType(src.ty.scalarType(zcu), .direct);

    const v = cg.vectorization(.{ dst_ty, src });
    const result_ty = try v.resultType(cg, dst_ty);

    // We can directly compare integers, because those type-IDs are cached.
    if (dst_ty_id == src_ty_id) {
        // Nothing to do, type-pun to the right value.
        // Note, Caller guarantees that the types fit (or caller will normalize after),
        // so we don't have to normalize here.
        // Note, dst_ty may be a scalar type even if we expect a vector, so we have to
        // convert to the right type here.
        return src.pun(result_ty);
    }

    const ops = v.components();
    const results = cg.module.allocIds(ops);

    const op_result_ty = dst_ty.scalarType(zcu);
    const op_result_ty_id = try cg.resolveType(op_result_ty, .direct);

    const opcode: Opcode = blk: {
        if (dst_ty.scalarType(zcu).isAnyFloat()) break :blk .OpFConvert;
        if (dst_ty.scalarType(zcu).isSignedInt(zcu)) break :blk .OpSConvert;
        break :blk .OpUConvert;
    };

    const op_src = try v.prepare(cg, src);

    for (0..ops) |i| {
        try cg.body.emitRaw(cg.module.gpa, opcode, 3);
        cg.body.writeOperand(Id, op_result_ty_id);
        cg.body.writeOperand(Id, results.at(i));
        cg.body.writeOperand(Id, op_src.at(i));
    }

    return v.finalize(result_ty, results);
}

fn buildFma(cg: *CodeGen, a: Temporary, b: Temporary, c: Temporary) !Temporary {
    const zcu = cg.module.zcu;
    const target = cg.module.zcu.getTarget();

    const v = cg.vectorization(.{ a, b, c });
    const ops = v.components();
    const results = cg.module.allocIds(ops);

    const op_result_ty = a.ty.scalarType(zcu);
    const op_result_ty_id = try cg.resolveType(op_result_ty, .direct);
    const result_ty = try v.resultType(cg, a.ty);

    const op_a = try v.prepare(cg, a);
    const op_b = try v.prepare(cg, b);
    const op_c = try v.prepare(cg, c);

    const set = try cg.importExtendedSet();
    const opcode: u32 = switch (target.os.tag) {
        .opencl => @intFromEnum(spec.OpenClOpcode.fma),
        // NOTE: Vulkan's FMA instruction does *NOT* produce the right values!
        //       its precision guarantees do NOT match zigs and it does NOT match OpenCLs!
        //       it needs to be emulated!
        .vulkan, .opengl => @intFromEnum(spec.GlslOpcode.Fma),
        else => unreachable,
    };

    for (0..ops) |i| {
        try cg.body.emit(cg.module.gpa, .OpExtInst, .{
            .id_result_type = op_result_ty_id,
            .id_result = results.at(i),
            .set = set,
            .instruction = .{ .inst = opcode },
            .id_ref_4 = &.{ op_a.at(i), op_b.at(i), op_c.at(i) },
        });
    }

    return v.finalize(result_ty, results);
}

fn buildSelect(cg: *CodeGen, condition: Temporary, lhs: Temporary, rhs: Temporary) !Temporary {
    const zcu = cg.module.zcu;

    const v = cg.vectorization(.{ condition, lhs, rhs });
    const ops = v.components();
    const results = cg.module.allocIds(ops);

    const op_result_ty = lhs.ty.scalarType(zcu);
    const op_result_ty_id = try cg.resolveType(op_result_ty, .direct);
    const result_ty = try v.resultType(cg, lhs.ty);

    assert(condition.ty.scalarType(zcu).zigTypeTag(zcu) == .bool);

    const cond = try v.prepare(cg, condition);
    const object_1 = try v.prepare(cg, lhs);
    const object_2 = try v.prepare(cg, rhs);

    for (0..ops) |i| {
        try cg.body.emit(cg.module.gpa, .OpSelect, .{
            .id_result_type = op_result_ty_id,
            .id_result = results.at(i),
            .condition = cond.at(i),
            .object_1 = object_1.at(i),
            .object_2 = object_2.at(i),
        });
    }

    return v.finalize(result_ty, results);
}

fn buildCmp(cg: *CodeGen, opcode: Opcode, lhs: Temporary, rhs: Temporary) !Temporary {
    const v = cg.vectorization(.{ lhs, rhs });
    const ops = v.components();
    const results = cg.module.allocIds(ops);

    const op_result_ty: Type = .bool;
    const op_result_ty_id = try cg.resolveType(op_result_ty, .direct);
    const result_ty = try v.resultType(cg, Type.bool);

    const op_lhs = try v.prepare(cg, lhs);
    const op_rhs = try v.prepare(cg, rhs);

    for (0..ops) |i| {
        try cg.body.emitRaw(cg.module.gpa, opcode, 4);
        cg.body.writeOperand(Id, op_result_ty_id);
        cg.body.writeOperand(Id, results.at(i));
        cg.body.writeOperand(Id, op_lhs.at(i));
        cg.body.writeOperand(Id, op_rhs.at(i));
    }

    return v.finalize(result_ty, results);
}

const UnaryOp = enum {
    l_not,
    bit_not,
    i_neg,
    f_neg,
    i_abs,
    f_abs,
    clz,
    ctz,
    floor,
    ceil,
    trunc,
    round,
    sqrt,
    sin,
    cos,
    tan,
    exp,
    exp2,
    log,
    log2,
    log10,

    pub fn extInstOpcode(op: UnaryOp, target: *const std.Target) ?u32 {
        return switch (target.os.tag) {
            .opencl => @intFromEnum(@as(spec.OpenClOpcode, switch (op) {
                .i_abs => .s_abs,
                .f_abs => .fabs,
                .clz => .clz,
                .ctz => .ctz,
                .floor => .floor,
                .ceil => .ceil,
                .trunc => .trunc,
                .round => .round,
                .sqrt => .sqrt,
                .sin => .sin,
                .cos => .cos,
                .tan => .tan,
                .exp => .exp,
                .exp2 => .exp2,
                .log => .log,
                .log2 => .log2,
                .log10 => .log10,
                else => return null,
            })),
            // Note: We'll need to check these for floating point accuracy
            // Vulkan does not put tight requirements on these, for correction
            // we might want to emulate them at some point.
            .vulkan, .opengl => @intFromEnum(@as(spec.GlslOpcode, switch (op) {
                .i_abs => .SAbs,
                .f_abs => .FAbs,
                .floor => .Floor,
                .ceil => .Ceil,
                .trunc => .Trunc,
                .round => .Round,
                .sin => .Sin,
                .cos => .Cos,
                .tan => .Tan,
                .sqrt => .Sqrt,
                .exp => .Exp,
                .exp2 => .Exp2,
                .log => .Log,
                .log2 => .Log2,
                else => return null,
            })),
            else => unreachable,
        };
    }
};

fn buildUnary(cg: *CodeGen, op: UnaryOp, operand: Temporary) !Temporary {
    const zcu = cg.module.zcu;
    const target = cg.module.zcu.getTarget();
    const v = cg.vectorization(.{operand});
    const ops = v.components();
    const results = cg.module.allocIds(ops);
    const op_result_ty = operand.ty.scalarType(zcu);
    const op_result_ty_id = try cg.resolveType(op_result_ty, .direct);
    const result_ty = try v.resultType(cg, operand.ty);
    const op_operand = try v.prepare(cg, operand);

    if (op.extInstOpcode(target)) |opcode| {
        const set = try cg.importExtendedSet();
        for (0..ops) |i| {
            try cg.body.emit(cg.module.gpa, .OpExtInst, .{
                .id_result_type = op_result_ty_id,
                .id_result = results.at(i),
                .set = set,
                .instruction = .{ .inst = opcode },
                .id_ref_4 = &.{op_operand.at(i)},
            });
        }
    } else {
        const opcode: Opcode = switch (op) {
            .l_not => .OpLogicalNot,
            .bit_not => .OpNot,
            .i_neg => .OpSNegate,
            .f_neg => .OpFNegate,
            else => return cg.todo(
                "implement unary operation '{s}' for {s} os",
                .{ @tagName(op), @tagName(target.os.tag) },
            ),
        };
        for (0..ops) |i| {
            try cg.body.emitRaw(cg.module.gpa, opcode, 3);
            cg.body.writeOperand(Id, op_result_ty_id);
            cg.body.writeOperand(Id, results.at(i));
            cg.body.writeOperand(Id, op_operand.at(i));
        }
    }

    return v.finalize(result_ty, results);
}

fn buildBinary(cg: *CodeGen, opcode: Opcode, lhs: Temporary, rhs: Temporary) !Temporary {
    const zcu = cg.module.zcu;

    const v = cg.vectorization(.{ lhs, rhs });
    const ops = v.components();
    const results = cg.module.allocIds(ops);

    const op_result_ty = lhs.ty.scalarType(zcu);
    const op_result_ty_id = try cg.resolveType(op_result_ty, .direct);
    const result_ty = try v.resultType(cg, lhs.ty);

    const op_lhs = try v.prepare(cg, lhs);
    const op_rhs = try v.prepare(cg, rhs);

    for (0..ops) |i| {
        try cg.body.emitRaw(cg.module.gpa, opcode, 4);
        cg.body.writeOperand(Id, op_result_ty_id);
        cg.body.writeOperand(Id, results.at(i));
        cg.body.writeOperand(Id, op_lhs.at(i));
        cg.body.writeOperand(Id, op_rhs.at(i));
    }

    return v.finalize(result_ty, results);
}

/// This function builds an extended multiplication, either OpSMulExtended or OpUMulExtended on Vulkan,
/// or OpIMul and s_mul_hi or u_mul_hi on OpenCL.
fn buildWideMul(
    cg: *CodeGen,
    signedness: std.builtin.Signedness,
    lhs: Temporary,
    rhs: Temporary,
) !struct { Temporary, Temporary } {
    const pt = cg.pt;
    const zcu = cg.module.zcu;
    const target = cg.module.zcu.getTarget();
    const ip = &zcu.intern_pool;

    const v = lhs.vectorization(cg).unify(rhs.vectorization(cg));
    const ops = v.components();

    const arith_op_ty = lhs.ty.scalarType(zcu);
    const arith_op_ty_id = try cg.resolveType(arith_op_ty, .direct);

    const lhs_op = try v.prepare(cg, lhs);
    const rhs_op = try v.prepare(cg, rhs);

    const value_results = cg.module.allocIds(ops);
    const overflow_results = cg.module.allocIds(ops);

    switch (target.os.tag) {
        .opencl => {
            // Currently, SPIRV-LLVM-Translator based backends cannot deal with OpSMulExtended and
            // OpUMulExtended. For these we will use the OpenCL s_mul_hi to compute the high-order bits
            // instead.
            const set = try cg.importExtendedSet();
            const overflow_inst: spec.OpenClOpcode = switch (signedness) {
                .signed => .s_mul_hi,
                .unsigned => .u_mul_hi,
            };

            for (0..ops) |i| {
                try cg.body.emit(cg.module.gpa, .OpIMul, .{
                    .id_result_type = arith_op_ty_id,
                    .id_result = value_results.at(i),
                    .operand_1 = lhs_op.at(i),
                    .operand_2 = rhs_op.at(i),
                });

                try cg.body.emit(cg.module.gpa, .OpExtInst, .{
                    .id_result_type = arith_op_ty_id,
                    .id_result = overflow_results.at(i),
                    .set = set,
                    .instruction = .{ .inst = @intFromEnum(overflow_inst) },
                    .id_ref_4 = &.{ lhs_op.at(i), rhs_op.at(i) },
                });
            }
        },
        .vulkan, .opengl => {
            // Operations return a struct{T, T}
            // where T is maybe vectorized.
            const op_result_ty: Type = .fromInterned(try ip.getTupleType(zcu.gpa, pt.tid, .{
                .types = &.{ arith_op_ty.toIntern(), arith_op_ty.toIntern() },
                .values = &.{ .none, .none },
            }));
            const op_result_ty_id = try cg.resolveType(op_result_ty, .direct);

            const opcode: Opcode = switch (signedness) {
                .signed => .OpSMulExtended,
                .unsigned => .OpUMulExtended,
            };

            for (0..ops) |i| {
                const op_result = cg.module.allocId();

                try cg.body.emitRaw(cg.module.gpa, opcode, 4);
                cg.body.writeOperand(Id, op_result_ty_id);
                cg.body.writeOperand(Id, op_result);
                cg.body.writeOperand(Id, lhs_op.at(i));
                cg.body.writeOperand(Id, rhs_op.at(i));

                // The above operation returns a struct. We might want to expand
                // Temporary to deal with the fact that these are structs eventually,
                // but for now, take the struct apart and return two separate vectors.

                try cg.body.emit(cg.module.gpa, .OpCompositeExtract, .{
                    .id_result_type = arith_op_ty_id,
                    .id_result = value_results.at(i),
                    .composite = op_result,
                    .indexes = &.{0},
                });

                try cg.body.emit(cg.module.gpa, .OpCompositeExtract, .{
                    .id_result_type = arith_op_ty_id,
                    .id_result = overflow_results.at(i),
                    .composite = op_result,
                    .indexes = &.{1},
                });
            }
        },
        else => unreachable,
    }

    const result_ty = try v.resultType(cg, lhs.ty);
    return .{
        v.finalize(result_ty, value_results),
        v.finalize(result_ty, overflow_results),
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
fn generateTestEntryPoint(
    cg: *CodeGen,
    name: []const u8,
    spv_decl_index: Module.Decl.Index,
    test_id: Id,
) !void {
    const gpa = cg.module.gpa;
    const zcu = cg.module.zcu;
    const target = cg.module.zcu.getTarget();

    const anyerror_ty_id = try cg.resolveType(.anyerror, .direct);
    const ptr_anyerror_ty = try cg.pt.ptrType(.{
        .child = .anyerror_type,
        .flags = .{ .address_space = .global },
    });
    const ptr_anyerror_ty_id = try cg.resolveType(ptr_anyerror_ty, .direct);

    const kernel_id = cg.module.declPtr(spv_decl_index).result_id;

    const section = &cg.module.sections.functions;

    const p_error_id = cg.module.allocId();
    switch (target.os.tag) {
        .opencl, .amdhsa => {
            const void_ty_id = try cg.resolveType(.void, .direct);
            const kernel_proto_ty_id = try cg.module.functionType(void_ty_id, &.{ptr_anyerror_ty_id});

            try section.emit(gpa, .OpFunction, .{
                .id_result_type = try cg.resolveType(.void, .direct),
                .id_result = kernel_id,
                .function_control = .{},
                .function_type = kernel_proto_ty_id,
            });

            try section.emit(gpa, .OpFunctionParameter, .{
                .id_result_type = ptr_anyerror_ty_id,
                .id_result = p_error_id,
            });

            try section.emit(gpa, .OpLabel, .{
                .id_result = cg.module.allocId(),
            });
        },
        .vulkan, .opengl => {
            if (cg.module.error_buffer == null) {
                const spv_err_decl_index = try cg.module.allocDecl(.global);
                const err_buf_result_id = cg.module.declPtr(spv_err_decl_index).result_id;

                const buffer_struct_ty_id = try cg.module.structType(
                    &.{anyerror_ty_id},
                    &.{"error_out"},
                    null,
                    .none,
                );
                try cg.module.decorate(buffer_struct_ty_id, .block);
                try cg.module.decorateMember(buffer_struct_ty_id, 0, .{ .offset = .{ .byte_offset = 0 } });

                const ptr_buffer_struct_ty_id = cg.module.allocId();
                try cg.module.sections.globals.emit(gpa, .OpTypePointer, .{
                    .id_result = ptr_buffer_struct_ty_id,
                    .storage_class = cg.module.storageClass(.global),
                    .type = buffer_struct_ty_id,
                });

                try cg.module.sections.globals.emit(gpa, .OpVariable, .{
                    .id_result_type = ptr_buffer_struct_ty_id,
                    .id_result = err_buf_result_id,
                    .storage_class = cg.module.storageClass(.global),
                });
                try cg.module.decorate(err_buf_result_id, .{ .descriptor_set = .{ .descriptor_set = 0 } });
                try cg.module.decorate(err_buf_result_id, .{ .binding = .{ .binding_point = 0 } });

                cg.module.error_buffer = spv_err_decl_index;
            }

            try cg.module.sections.execution_modes.emit(gpa, .OpExecutionMode, .{
                .entry_point = kernel_id,
                .mode = .{ .local_size = .{
                    .x_size = 1,
                    .y_size = 1,
                    .z_size = 1,
                } },
            });

            const void_ty_id = try cg.resolveType(.void, .direct);
            const kernel_proto_ty_id = try cg.module.functionType(void_ty_id, &.{});
            try section.emit(gpa, .OpFunction, .{
                .id_result_type = try cg.resolveType(.void, .direct),
                .id_result = kernel_id,
                .function_control = .{},
                .function_type = kernel_proto_ty_id,
            });
            try section.emit(gpa, .OpLabel, .{
                .id_result = cg.module.allocId(),
            });

            const spv_err_decl_index = cg.module.error_buffer.?;
            const buffer_id = cg.module.declPtr(spv_err_decl_index).result_id;
            try cg.module.decl_deps.append(gpa, spv_err_decl_index);

            const zero_id = try cg.constInt(.u32, 0);
            try section.emit(gpa, .OpInBoundsAccessChain, .{
                .id_result_type = ptr_anyerror_ty_id,
                .id_result = p_error_id,
                .base = buffer_id,
                .indexes = &.{zero_id},
            });
        },
        else => unreachable,
    }

    const error_id = cg.module.allocId();
    try section.emit(gpa, .OpFunctionCall, .{
        .id_result_type = anyerror_ty_id,
        .id_result = error_id,
        .function = test_id,
    });
    // Note: Convert to direct not required.
    try section.emit(gpa, .OpStore, .{
        .pointer = p_error_id,
        .object = error_id,
        .memory_access = .{
            .aligned = .{ .literal_integer = @intCast(Type.abiAlignment(.anyerror, zcu).toByteUnits().?) },
        },
    });
    try section.emit(gpa, .OpReturn, {});
    try section.emit(gpa, .OpFunctionEnd, {});

    // Just generate a quick other name because the intel runtime crashes when the entry-
    // point name is the same as a different OpName.
    const test_name = try std.fmt.allocPrint(cg.module.arena, "test {s}", .{name});

    const execution_mode: spec.ExecutionModel = switch (target.os.tag) {
        .vulkan, .opengl => .gl_compute,
        .opencl, .amdhsa => .kernel,
        else => unreachable,
    };

    try cg.module.declareEntryPoint(spv_decl_index, test_name, execution_mode, null);
}

fn intFromBool(cg: *CodeGen, value: Temporary, result_ty: Type) !Temporary {
    const zero_id = try cg.constInt(result_ty, 0);
    const one_id = try cg.constInt(result_ty, 1);

    return try cg.buildSelect(
        value,
        Temporary.init(result_ty, one_id),
        Temporary.init(result_ty, zero_id),
    );
}

/// Convert representation from indirect (in memory) to direct (in 'register')
/// This converts the argument type from resolveType(ty, .indirect) to resolveType(ty, .direct).
fn convertToDirect(cg: *CodeGen, ty: Type, operand_id: Id) !Id {
    const pt = cg.pt;
    const zcu = cg.module.zcu;
    switch (ty.scalarType(zcu).zigTypeTag(zcu)) {
        .bool => {
            const false_id = try cg.constBool(false, .indirect);
            const operand_ty = blk: {
                if (!ty.isVector(zcu)) break :blk Type.u1;
                break :blk try pt.vectorType(.{
                    .len = ty.vectorLen(zcu),
                    .child = .u1_type,
                });
            };

            const result = try cg.buildCmp(
                .OpINotEqual,
                Temporary.init(operand_ty, operand_id),
                Temporary.init(.u1, false_id),
            );
            return try result.materialize(cg);
        },
        else => return operand_id,
    }
}

/// Convert representation from direct (in 'register) to direct (in memory)
/// This converts the argument type from resolveType(ty, .direct) to resolveType(ty, .indirect).
fn convertToIndirect(cg: *CodeGen, ty: Type, operand_id: Id) !Id {
    const zcu = cg.module.zcu;
    switch (ty.scalarType(zcu).zigTypeTag(zcu)) {
        .bool => {
            const result = try cg.intFromBool(.init(ty, operand_id), .u1);
            return try result.materialize(cg);
        },
        else => return operand_id,
    }
}

fn extractField(cg: *CodeGen, result_ty: Type, object: Id, field: u32) !Id {
    const result_ty_id = try cg.resolveType(result_ty, .indirect);
    const result_id = cg.module.allocId();
    const indexes = [_]u32{field};
    try cg.body.emit(cg.module.gpa, .OpCompositeExtract, .{
        .id_result_type = result_ty_id,
        .id_result = result_id,
        .composite = object,
        .indexes = &indexes,
    });
    // Convert bools; direct structs have their field types as indirect values.
    return try cg.convertToDirect(result_ty, result_id);
}

fn extractVectorComponent(cg: *CodeGen, result_ty: Type, vector_id: Id, field: u32) !Id {
    const result_ty_id = try cg.resolveType(result_ty, .direct);
    const result_id = cg.module.allocId();
    const indexes = [_]u32{field};
    try cg.body.emit(cg.module.gpa, .OpCompositeExtract, .{
        .id_result_type = result_ty_id,
        .id_result = result_id,
        .composite = vector_id,
        .indexes = &indexes,
    });
    // Vector components are already stored in direct representation.
    return result_id;
}

const MemoryOptions = struct {
    is_volatile: bool = false,
};

fn load(cg: *CodeGen, value_ty: Type, ptr_id: Id, options: MemoryOptions) !Id {
    const zcu = cg.module.zcu;
    const alignment: u32 = @intCast(value_ty.abiAlignment(zcu).toByteUnits().?);
    const indirect_value_ty_id = try cg.resolveType(value_ty, .indirect);
    const result_id = cg.module.allocId();
    const access: spec.MemoryAccess.Extended = .{
        .@"volatile" = options.is_volatile,
        .aligned = .{ .literal_integer = alignment },
    };
    try cg.body.emit(cg.module.gpa, .OpLoad, .{
        .id_result_type = indirect_value_ty_id,
        .id_result = result_id,
        .pointer = ptr_id,
        .memory_access = access,
    });
    return try cg.convertToDirect(value_ty, result_id);
}

fn store(cg: *CodeGen, value_ty: Type, ptr_id: Id, value_id: Id, options: MemoryOptions) !void {
    const indirect_value_id = try cg.convertToIndirect(value_ty, value_id);
    const access: spec.MemoryAccess.Extended = .{ .@"volatile" = options.is_volatile };
    try cg.body.emit(cg.module.gpa, .OpStore, .{
        .pointer = ptr_id,
        .object = indirect_value_id,
        .memory_access = access,
    });
}

fn genBody(cg: *CodeGen, body: []const Air.Inst.Index) !void {
    for (body) |inst| {
        try cg.genInst(inst);
    }
}

fn genInst(cg: *CodeGen, inst: Air.Inst.Index) Error!void {
    const gpa = cg.module.gpa;
    const zcu = cg.module.zcu;
    const ip = &zcu.intern_pool;
    if (cg.liveness.isUnused(inst) and !cg.air.mustLower(inst, ip))
        return;

    const air_tags = cg.air.instructions.items(.tag);
    const maybe_result_id: ?Id = switch (air_tags[@intFromEnum(inst)]) {
        // zig fmt: off
            .add, .add_wrap, .add_optimized => try cg.airArithOp(inst, .OpFAdd, .OpIAdd, .OpIAdd),
            .sub, .sub_wrap, .sub_optimized => try cg.airArithOp(inst, .OpFSub, .OpISub, .OpISub),
            .mul, .mul_wrap, .mul_optimized => try cg.airArithOp(inst, .OpFMul, .OpIMul, .OpIMul),

            .sqrt => try cg.airUnOpSimple(inst, .sqrt),
            .sin => try cg.airUnOpSimple(inst, .sin),
            .cos => try cg.airUnOpSimple(inst, .cos),
            .tan => try cg.airUnOpSimple(inst, .tan),
            .exp => try cg.airUnOpSimple(inst, .exp),
            .exp2 => try cg.airUnOpSimple(inst, .exp2),
            .log => try cg.airUnOpSimple(inst, .log),
            .log2 => try cg.airUnOpSimple(inst, .log2),
            .log10 => try cg.airUnOpSimple(inst, .log10),
            .abs => try cg.airAbs(inst),
            .floor => try cg.airUnOpSimple(inst, .floor),
            .ceil => try cg.airUnOpSimple(inst, .ceil),
            .round => try cg.airUnOpSimple(inst, .round),
            .trunc_float => try cg.airUnOpSimple(inst, .trunc),
            .neg, .neg_optimized => try cg.airUnOpSimple(inst, .f_neg),

            .div_float, .div_float_optimized => try cg.airArithOp(inst, .OpFDiv, .OpSDiv, .OpUDiv),
            .div_floor, .div_floor_optimized => try cg.airDivFloor(inst),
            .div_trunc, .div_trunc_optimized => try cg.airDivTrunc(inst),

            .rem, .rem_optimized => try cg.airArithOp(inst, .OpFRem, .OpSRem, .OpUMod),
            .mod, .mod_optimized => try cg.airArithOp(inst, .OpFMod, .OpSMod, .OpUMod),

            .add_with_overflow => try cg.airAddSubOverflow(inst, .OpIAdd, .OpULessThan, .OpSLessThan),
            .sub_with_overflow => try cg.airAddSubOverflow(inst, .OpISub, .OpUGreaterThan, .OpSGreaterThan),
            .mul_with_overflow => try cg.airMulOverflow(inst),
            .shl_with_overflow => try cg.airShlOverflow(inst),

            .mul_add => try cg.airMulAdd(inst),

            .ctz => try cg.airClzCtz(inst, .ctz),
            .clz => try cg.airClzCtz(inst, .clz),

            .select => try cg.airSelect(inst),

            .splat => try cg.airSplat(inst),
            .reduce, .reduce_optimized => try cg.airReduce(inst),
            .shuffle_one               => try cg.airShuffleOne(inst),
            .shuffle_two               => try cg.airShuffleTwo(inst),

            .ptr_add => try cg.airPtrAdd(inst),
            .ptr_sub => try cg.airPtrSub(inst),

            .bit_and  => try cg.airBinOpSimple(inst, .OpBitwiseAnd),
            .bit_or   => try cg.airBinOpSimple(inst, .OpBitwiseOr),
            .xor      => try cg.airBinOpSimple(inst, .OpBitwiseXor),
            .bool_and => try cg.airBinOpSimple(inst, .OpLogicalAnd),
            .bool_or  => try cg.airBinOpSimple(inst, .OpLogicalOr),

            .shl, .shl_exact => try cg.airShift(inst, .OpShiftLeftLogical, .OpShiftLeftLogical),
            .shr, .shr_exact => try cg.airShift(inst, .OpShiftRightLogical, .OpShiftRightArithmetic),

            .min => try cg.airMinMax(inst, .min),
            .max => try cg.airMinMax(inst, .max),

            .bitcast         => try cg.airBitCast(inst),
            .intcast, .trunc => try cg.airIntCast(inst),
            .float_from_int  => try cg.airFloatFromInt(inst),
            .int_from_float  => try cg.airIntFromFloat(inst),
            .fpext, .fptrunc => try cg.airFloatCast(inst),
            .not             => try cg.airNot(inst),

            .array_to_slice => try cg.airArrayToSlice(inst),
            .slice          => try cg.airSlice(inst),
            .aggregate_init => try cg.airAggregateInit(inst),
            .memcpy         => return cg.airMemcpy(inst),
            .memmove        => return cg.airMemmove(inst),

            .slice_ptr      => try cg.airSliceField(inst, 0),
            .slice_len      => try cg.airSliceField(inst, 1),
            .slice_elem_ptr => try cg.airSliceElemPtr(inst),
            .slice_elem_val => try cg.airSliceElemVal(inst),
            .ptr_elem_ptr   => try cg.airPtrElemPtr(inst),
            .ptr_elem_val   => try cg.airPtrElemVal(inst),
            .array_elem_val => try cg.airArrayElemVal(inst),

            .set_union_tag => return cg.airSetUnionTag(inst),
            .get_union_tag => try cg.airGetUnionTag(inst),
            .union_init => try cg.airUnionInit(inst),

            .struct_field_val => try cg.airStructFieldVal(inst),
            .field_parent_ptr => try cg.airFieldParentPtr(inst),

            .struct_field_ptr_index_0 => try cg.airStructFieldPtrIndex(inst, 0),
            .struct_field_ptr_index_1 => try cg.airStructFieldPtrIndex(inst, 1),
            .struct_field_ptr_index_2 => try cg.airStructFieldPtrIndex(inst, 2),
            .struct_field_ptr_index_3 => try cg.airStructFieldPtrIndex(inst, 3),

            .cmp_eq     => try cg.airCmp(inst, .eq),
            .cmp_neq    => try cg.airCmp(inst, .neq),
            .cmp_gt     => try cg.airCmp(inst, .gt),
            .cmp_gte    => try cg.airCmp(inst, .gte),
            .cmp_lt     => try cg.airCmp(inst, .lt),
            .cmp_lte    => try cg.airCmp(inst, .lte),
            .cmp_vector => try cg.airVectorCmp(inst),

            .arg     => cg.airArg(),
            .alloc   => try cg.airAlloc(inst),
            // TODO: We probably need to have a special implementation of this for the C abi.
            .ret_ptr => try cg.airAlloc(inst),
            .block   => try cg.airBlock(inst),

            .load               => try cg.airLoad(inst),
            .store, .store_safe => return cg.airStore(inst),

            .br             => return cg.airBr(inst),
            // For now just ignore this instruction. This effectively falls back on the old implementation,
            // this doesn't change anything for us.
            .repeat         => return,
            .breakpoint     => return,
            .cond_br        => return cg.airCondBr(inst),
            .loop           => return cg.airLoop(inst),
            .ret            => return cg.airRet(inst),
            .ret_safe       => return cg.airRet(inst), // TODO
            .ret_load       => return cg.airRetLoad(inst),
            .@"try"         => try cg.airTry(inst),
            .switch_br      => return cg.airSwitchBr(inst),
            .unreach, .trap => return cg.airUnreach(),

            .dbg_empty_stmt            => return,
            .dbg_stmt                  => return cg.airDbgStmt(inst),
            .dbg_inline_block          => try cg.airDbgInlineBlock(inst),
            .dbg_var_ptr, .dbg_var_val, .dbg_arg_inline => return cg.airDbgVar(inst),

            .unwrap_errunion_err => try cg.airErrUnionErr(inst),
            .unwrap_errunion_payload => try cg.airErrUnionPayload(inst),
            .wrap_errunion_err => try cg.airWrapErrUnionErr(inst),
            .wrap_errunion_payload => try cg.airWrapErrUnionPayload(inst),

            .is_null         => try cg.airIsNull(inst, false, .is_null),
            .is_non_null     => try cg.airIsNull(inst, false, .is_non_null),
            .is_null_ptr     => try cg.airIsNull(inst, true, .is_null),
            .is_non_null_ptr => try cg.airIsNull(inst, true, .is_non_null),
            .is_err          => try cg.airIsErr(inst, .is_err),
            .is_non_err      => try cg.airIsErr(inst, .is_non_err),

            .optional_payload     => try cg.airUnwrapOptional(inst),
            .optional_payload_ptr => try cg.airUnwrapOptionalPtr(inst),
            .wrap_optional        => try cg.airWrapOptional(inst),

            .assembly => try cg.airAssembly(inst),

            .call              => try cg.airCall(inst, .auto),
            .call_always_tail  => try cg.airCall(inst, .always_tail),
            .call_never_tail   => try cg.airCall(inst, .never_tail),
            .call_never_inline => try cg.airCall(inst, .never_inline),

            .work_item_id => try cg.airWorkItemId(inst),
            .work_group_size => try cg.airWorkGroupSize(inst),
            .work_group_id => try cg.airWorkGroupId(inst),

            // zig fmt: on

        else => |tag| return cg.todo("implement AIR tag {s}", .{@tagName(tag)}),
    };

    const result_id = maybe_result_id orelse return;
    try cg.inst_results.putNoClobber(gpa, inst, result_id);
}

fn airBinOpSimple(cg: *CodeGen, inst: Air.Inst.Index, op: Opcode) !?Id {
    const bin_op = cg.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const lhs = try cg.temporary(bin_op.lhs);
    const rhs = try cg.temporary(bin_op.rhs);

    const result = try cg.buildBinary(op, lhs, rhs);
    return try result.materialize(cg);
}

fn airShift(cg: *CodeGen, inst: Air.Inst.Index, unsigned: Opcode, signed: Opcode) !?Id {
    const zcu = cg.module.zcu;
    const bin_op = cg.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;

    if (cg.typeOf(bin_op.lhs).isVector(zcu) and !cg.typeOf(bin_op.rhs).isVector(zcu)) {
        return cg.fail("vector shift with scalar rhs", .{});
    }

    const base = try cg.temporary(bin_op.lhs);
    const shift = try cg.temporary(bin_op.rhs);

    const result_ty = cg.typeOfIndex(inst);

    const info = cg.arithmeticTypeInfo(result_ty);
    switch (info.class) {
        .composite_integer => return cg.todo("shift ops for composite integers", .{}),
        .integer, .strange_integer => {},
        .float, .bool => unreachable,
    }

    // Sometimes Zig doesn't make both of the arguments the same types here. SPIR-V expects that,
    // so just manually upcast it if required.

    // Note: The sign may differ here between the shift and the base type, in case
    // of an arithmetic right shift. SPIR-V still expects the same type,
    // so in that case we have to cast convert to signed.
    const casted_shift = try cg.buildConvert(base.ty.scalarType(zcu), shift);

    const shifted = switch (info.signedness) {
        .unsigned => try cg.buildBinary(unsigned, base, casted_shift),
        .signed => try cg.buildBinary(signed, base, casted_shift),
    };

    const result = try cg.normalize(shifted, info);
    return try result.materialize(cg);
}

const MinMax = enum {
    min,
    max,

    pub fn extInstOpcode(
        op: MinMax,
        target: *const std.Target,
        info: ArithmeticTypeInfo,
    ) u32 {
        return switch (target.os.tag) {
            .opencl => @intFromEnum(@as(spec.OpenClOpcode, switch (info.class) {
                .float => switch (op) {
                    .min => .fmin,
                    .max => .fmax,
                },
                .integer, .strange_integer, .composite_integer => switch (info.signedness) {
                    .signed => switch (op) {
                        .min => .s_min,
                        .max => .s_max,
                    },
                    .unsigned => switch (op) {
                        .min => .u_min,
                        .max => .u_max,
                    },
                },
                .bool => unreachable,
            })),
            .vulkan, .opengl => @intFromEnum(@as(spec.GlslOpcode, switch (info.class) {
                .float => switch (op) {
                    .min => .FMin,
                    .max => .FMax,
                },
                .integer, .strange_integer, .composite_integer => switch (info.signedness) {
                    .signed => switch (op) {
                        .min => .SMin,
                        .max => .SMax,
                    },
                    .unsigned => switch (op) {
                        .min => .UMin,
                        .max => .UMax,
                    },
                },
                .bool => unreachable,
            })),
            else => unreachable,
        };
    }
};

fn airMinMax(cg: *CodeGen, inst: Air.Inst.Index, op: MinMax) !?Id {
    const bin_op = cg.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;

    const lhs = try cg.temporary(bin_op.lhs);
    const rhs = try cg.temporary(bin_op.rhs);

    const result = try cg.minMax(lhs, rhs, op);
    return try result.materialize(cg);
}

fn minMax(cg: *CodeGen, lhs: Temporary, rhs: Temporary, op: MinMax) !Temporary {
    const zcu = cg.module.zcu;
    const target = zcu.getTarget();
    const info = cg.arithmeticTypeInfo(lhs.ty);

    const v = cg.vectorization(.{ lhs, rhs });
    const ops = v.components();
    const results = cg.module.allocIds(ops);

    const op_result_ty = lhs.ty.scalarType(zcu);
    const op_result_ty_id = try cg.resolveType(op_result_ty, .direct);
    const result_ty = try v.resultType(cg, lhs.ty);

    const op_lhs = try v.prepare(cg, lhs);
    const op_rhs = try v.prepare(cg, rhs);

    const set = try cg.importExtendedSet();
    const opcode = op.extInstOpcode(target, info);
    for (0..ops) |i| {
        try cg.body.emit(cg.module.gpa, .OpExtInst, .{
            .id_result_type = op_result_ty_id,
            .id_result = results.at(i),
            .set = set,
            .instruction = .{ .inst = opcode },
            .id_ref_4 = &.{ op_lhs.at(i), op_rhs.at(i) },
        });
    }

    return v.finalize(result_ty, results);
}

/// This function normalizes values to a canonical representation
/// after some arithmetic operation. This mostly consists of wrapping
/// behavior for strange integers:
/// - Unsigned integers are bitwise masked with a mask that only passes
///   the valid bits through.
/// - Signed integers are also sign extended if they are negative.
/// All other values are returned unmodified (this makes strange integer
/// wrapping easier to use in generic operations).
fn normalize(cg: *CodeGen, value: Temporary, info: ArithmeticTypeInfo) !Temporary {
    const zcu = cg.module.zcu;
    const ty = value.ty;
    switch (info.class) {
        .composite_integer, .integer, .bool, .float => return value,
        .strange_integer => switch (info.signedness) {
            .unsigned => {
                const mask_value = @as(u64, std.math.maxInt(u64)) >> @as(u6, @intCast(64 - info.bits));
                const mask_id = try cg.constInt(ty.scalarType(zcu), mask_value);
                return try cg.buildBinary(.OpBitwiseAnd, value, Temporary.init(ty.scalarType(zcu), mask_id));
            },
            .signed => {
                // Shift left and right so that we can copy the sight bit that way.
                const shift_amt_id = try cg.constInt(ty.scalarType(zcu), info.backing_bits - info.bits);
                const shift_amt: Temporary = .init(ty.scalarType(zcu), shift_amt_id);
                const left = try cg.buildBinary(.OpShiftLeftLogical, value, shift_amt);
                return try cg.buildBinary(.OpShiftRightArithmetic, left, shift_amt);
            },
        },
    }
}

fn airDivFloor(cg: *CodeGen, inst: Air.Inst.Index) !?Id {
    const bin_op = cg.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;

    const lhs = try cg.temporary(bin_op.lhs);
    const rhs = try cg.temporary(bin_op.rhs);

    const info = cg.arithmeticTypeInfo(lhs.ty);
    switch (info.class) {
        .composite_integer => unreachable, // TODO
        .integer, .strange_integer => {
            switch (info.signedness) {
                .unsigned => {
                    const result = try cg.buildBinary(.OpUDiv, lhs, rhs);
                    return try result.materialize(cg);
                },
                .signed => {},
            }

            // For signed integers:
            //   (a / b) - (a % b != 0 && a < 0 != b < 0);
            // There shouldn't be any overflow issues.

            const div = try cg.buildBinary(.OpSDiv, lhs, rhs);
            const rem = try cg.buildBinary(.OpSRem, lhs, rhs);
            const zero: Temporary = .init(lhs.ty, try cg.constInt(lhs.ty, 0));
            const rem_non_zero = try cg.buildCmp(.OpINotEqual, rem, zero);
            const lhs_rhs_xor = try cg.buildBinary(.OpBitwiseXor, lhs, rhs);
            const signs_differ = try cg.buildCmp(.OpSLessThan, lhs_rhs_xor, zero);
            const adjust = try cg.buildBinary(.OpLogicalAnd, rem_non_zero, signs_differ);
            const result = try cg.buildBinary(.OpISub, div, try cg.intFromBool(adjust, div.ty));
            return try result.materialize(cg);
        },
        .float => {
            const div = try cg.buildBinary(.OpFDiv, lhs, rhs);
            const result = try cg.buildUnary(.floor, div);
            return try result.materialize(cg);
        },
        .bool => unreachable,
    }
}

fn airDivTrunc(cg: *CodeGen, inst: Air.Inst.Index) !?Id {
    const bin_op = cg.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const lhs = try cg.temporary(bin_op.lhs);
    const rhs = try cg.temporary(bin_op.rhs);
    const info = cg.arithmeticTypeInfo(lhs.ty);
    switch (info.class) {
        .composite_integer => unreachable, // TODO
        .integer, .strange_integer => switch (info.signedness) {
            .unsigned => {
                const result = try cg.buildBinary(.OpUDiv, lhs, rhs);
                return try result.materialize(cg);
            },
            .signed => {
                const result = try cg.buildBinary(.OpSDiv, lhs, rhs);
                return try result.materialize(cg);
            },
        },
        .float => {
            const div = try cg.buildBinary(.OpFDiv, lhs, rhs);
            const result = try cg.buildUnary(.trunc, div);
            return try result.materialize(cg);
        },
        .bool => unreachable,
    }
}

fn airUnOpSimple(cg: *CodeGen, inst: Air.Inst.Index, op: UnaryOp) !?Id {
    const un_op = cg.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
    const operand = try cg.temporary(un_op);
    const result = try cg.buildUnary(op, operand);
    return try result.materialize(cg);
}

fn airArithOp(
    cg: *CodeGen,
    inst: Air.Inst.Index,
    comptime fop: Opcode,
    comptime sop: Opcode,
    comptime uop: Opcode,
) !?Id {
    const bin_op = cg.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const lhs = try cg.temporary(bin_op.lhs);
    const rhs = try cg.temporary(bin_op.rhs);
    const info = cg.arithmeticTypeInfo(lhs.ty);
    const result = switch (info.class) {
        .composite_integer => unreachable, // TODO
        .integer, .strange_integer => switch (info.signedness) {
            .signed => try cg.buildBinary(sop, lhs, rhs),
            .unsigned => try cg.buildBinary(uop, lhs, rhs),
        },
        .float => try cg.buildBinary(fop, lhs, rhs),
        .bool => unreachable,
    };
    return try result.materialize(cg);
}

fn airAbs(cg: *CodeGen, inst: Air.Inst.Index) !?Id {
    const ty_op = cg.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const operand = try cg.temporary(ty_op.operand);
    // Note: operand_ty may be signed, while ty is always unsigned!
    const result_ty = cg.typeOfIndex(inst);
    const result = try cg.abs(result_ty, operand);
    return try result.materialize(cg);
}

fn abs(cg: *CodeGen, result_ty: Type, value: Temporary) !Temporary {
    const zcu = cg.module.zcu;
    const target = cg.module.zcu.getTarget();
    const operand_info = cg.arithmeticTypeInfo(value.ty);
    switch (operand_info.class) {
        .float => return try cg.buildUnary(.f_abs, value),
        .integer, .strange_integer => {
            const abs_value = try cg.buildUnary(.i_abs, value);
            switch (target.os.tag) {
                .vulkan, .opengl => {
                    if (value.ty.intInfo(zcu).signedness == .signed) {
                        return cg.todo("perform bitcast after @abs", .{});
                    }
                },
                else => {},
            }
            return try cg.normalize(abs_value, cg.arithmeticTypeInfo(result_ty));
        },
        .composite_integer => unreachable, // TODO
        .bool => unreachable,
    }
}

fn airAddSubOverflow(
    cg: *CodeGen,
    inst: Air.Inst.Index,
    comptime add: Opcode,
    u_opcode: Opcode,
    s_opcode: Opcode,
) !?Id {
    // Note: OpIAddCarry and OpISubBorrow are not really useful here: For unsigned numbers,
    // there is in both cases only one extra operation required. For signed operations,
    // the overflow bit is set then going from 0x80.. to 0x00.., but this doesn't actually
    // normally set a carry bit. So the SPIR-V overflow operations are not particularly
    // useful here.

    _ = s_opcode;

    const ty_pl = cg.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const extra = cg.air.extraData(Air.Bin, ty_pl.payload).data;
    const lhs = try cg.temporary(extra.lhs);
    const rhs = try cg.temporary(extra.rhs);
    const result_ty = cg.typeOfIndex(inst);

    const info = cg.arithmeticTypeInfo(lhs.ty);
    switch (info.class) {
        .composite_integer => unreachable, // TODO
        .strange_integer, .integer => {},
        .float, .bool => unreachable,
    }

    const sum = try cg.buildBinary(add, lhs, rhs);
    const result = try cg.normalize(sum, info);
    const overflowed = switch (info.signedness) {
        // Overflow happened if the result is smaller than either of the operands. It doesn't matter which.
        // For subtraction the conditions need to be swapped.
        .unsigned => try cg.buildCmp(u_opcode, result, lhs),
        // For signed operations, we check the signs of the operands and the result.
        .signed => blk: {
            // Signed overflow detection using the sign bits of the operands and the result.
            // For addition (a + b), overflow occurs if the operands have the same sign
            // and the result's sign is different from the operands' sign.
            //   (sign(a) == sign(b)) && (sign(a) != sign(result))
            // For subtraction (a - b), overflow occurs if the operands have different signs
            // and the result's sign is different from the minuend's (a's) sign.
            //   (sign(a) != sign(b)) && (sign(a) != sign(result))
            const zero: Temporary = .init(rhs.ty, try cg.constInt(rhs.ty, 0));
            const lhs_is_neg = try cg.buildCmp(.OpSLessThan, lhs, zero);
            const rhs_is_neg = try cg.buildCmp(.OpSLessThan, rhs, zero);
            const result_is_neg = try cg.buildCmp(.OpSLessThan, result, zero);
            const signs_match = try cg.buildCmp(.OpLogicalEqual, lhs_is_neg, rhs_is_neg);
            const result_sign_differs = try cg.buildCmp(.OpLogicalNotEqual, lhs_is_neg, result_is_neg);
            const overflow_condition = switch (add) {
                .OpIAdd => signs_match,
                .OpISub => try cg.buildUnary(.l_not, signs_match),
                else => unreachable,
            };
            break :blk try cg.buildCmp(.OpLogicalAnd, overflow_condition, result_sign_differs);
        },
    };

    const ov = try cg.intFromBool(overflowed, .u1);
    const result_ty_id = try cg.resolveType(result_ty, .direct);
    return try cg.constructComposite(result_ty_id, &.{ try result.materialize(cg), try ov.materialize(cg) });
}

fn airMulOverflow(cg: *CodeGen, inst: Air.Inst.Index) !?Id {
    const pt = cg.pt;
    const ty_pl = cg.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const extra = cg.air.extraData(Air.Bin, ty_pl.payload).data;
    const lhs = try cg.temporary(extra.lhs);
    const rhs = try cg.temporary(extra.rhs);
    const result_ty = cg.typeOfIndex(inst);

    const info = cg.arithmeticTypeInfo(lhs.ty);
    switch (info.class) {
        .composite_integer => unreachable, // TODO
        .strange_integer, .integer => {},
        .float, .bool => unreachable,
    }

    // There are 3 cases which we have to deal with:
    // - If info.bits < 32 / 2, we will upcast to 32 and check the higher bits
    // - If info.bits > 32 / 2, we have to use extended multiplication
    // - Additionally, if info.bits != 32, we'll have to check the high bits
    //   of the result too.

    const largest_int_bits = cg.largestSupportedIntBits();
    // If non-null, the number of bits that the multiplication should be performed in. If
    // null, we have to use wide multiplication.
    const maybe_op_ty_bits: ?u16 = switch (info.bits) {
        0 => unreachable,
        1...16 => 32,
        17...32 => if (largest_int_bits > 32) 64 else null, // Upcast if we can.
        33...64 => null, // Always use wide multiplication.
        else => unreachable, // TODO: Composite integers
    };

    const result, const overflowed = switch (info.signedness) {
        .unsigned => blk: {
            if (maybe_op_ty_bits) |op_ty_bits| {
                const op_ty = try pt.intType(.unsigned, op_ty_bits);
                const casted_lhs = try cg.buildConvert(op_ty, lhs);
                const casted_rhs = try cg.buildConvert(op_ty, rhs);
                const full_result = try cg.buildBinary(.OpIMul, casted_lhs, casted_rhs);
                const low_bits = try cg.buildConvert(lhs.ty, full_result);
                const result = try cg.normalize(low_bits, info);
                // Shift the result bits away to get the overflow bits.
                const shift: Temporary = .init(full_result.ty, try cg.constInt(full_result.ty, info.bits));
                const overflow = try cg.buildBinary(.OpShiftRightLogical, full_result, shift);
                // Directly check if its zero in the op_ty without converting first.
                const zero: Temporary = .init(full_result.ty, try cg.constInt(full_result.ty, 0));
                const overflowed = try cg.buildCmp(.OpINotEqual, zero, overflow);
                break :blk .{ result, overflowed };
            }

            const low_bits, const high_bits = try cg.buildWideMul(.unsigned, lhs, rhs);

            // Truncate the result, if required.
            const result = try cg.normalize(low_bits, info);

            // Overflow happened if the high-bits of the result are non-zero OR if the
            // high bits of the low word of the result (those outside the range of the
            // int) are nonzero.
            const zero: Temporary = .init(lhs.ty, try cg.constInt(lhs.ty, 0));
            const high_overflowed = try cg.buildCmp(.OpINotEqual, zero, high_bits);

            // If no overflow bits in low_bits, no extra work needs to be done.
            if (info.backing_bits == info.bits) break :blk .{ result, high_overflowed };

            // Shift the result bits away to get the overflow bits.
            const shift: Temporary = .init(lhs.ty, try cg.constInt(lhs.ty, info.bits));
            const low_overflow = try cg.buildBinary(.OpShiftRightLogical, low_bits, shift);
            const low_overflowed = try cg.buildCmp(.OpINotEqual, zero, low_overflow);

            const overflowed = try cg.buildCmp(.OpLogicalOr, low_overflowed, high_overflowed);

            break :blk .{ result, overflowed };
        },
        .signed => blk: {
            // - lhs >= 0, rhxs >= 0: expect positive; overflow should be  0
            // - lhs == 0          : expect positive; overflow should be  0
            // -           rhs == 0: expect positive; overflow should be  0
            // - lhs  > 0, rhs  < 0: expect negative; overflow should be -1
            // - lhs  < 0, rhs  > 0: expect negative; overflow should be -1
            // - lhs <= 0, rhs <= 0: expect positive; overflow should be  0
            // ------
            // overflow should be -1 when
            //   (lhs > 0 && rhs < 0) || (lhs < 0 && rhs > 0)

            const zero: Temporary = .init(lhs.ty, try cg.constInt(lhs.ty, 0));
            const lhs_negative = try cg.buildCmp(.OpSLessThan, lhs, zero);
            const rhs_negative = try cg.buildCmp(.OpSLessThan, rhs, zero);
            const lhs_positive = try cg.buildCmp(.OpSGreaterThan, lhs, zero);
            const rhs_positive = try cg.buildCmp(.OpSGreaterThan, rhs, zero);

            // Set to `true` if we expect -1.
            const expected_overflow_bit = try cg.buildBinary(
                .OpLogicalOr,
                try cg.buildCmp(.OpLogicalAnd, lhs_positive, rhs_negative),
                try cg.buildCmp(.OpLogicalAnd, lhs_negative, rhs_positive),
            );

            if (maybe_op_ty_bits) |op_ty_bits| {
                const op_ty = try pt.intType(.signed, op_ty_bits);
                // Assume normalized; sign bit is set. We want a sign extend.
                const casted_lhs = try cg.buildConvert(op_ty, lhs);
                const casted_rhs = try cg.buildConvert(op_ty, rhs);

                const full_result = try cg.buildBinary(.OpIMul, casted_lhs, casted_rhs);

                // Truncate to the result type.
                const low_bits = try cg.buildConvert(lhs.ty, full_result);
                const result = try cg.normalize(low_bits, info);

                // Now, we need to check the overflow bits AND the sign
                // bit for the expected overflow bits.
                // To do that, shift out everything bit the sign bit and
                // then check what remains.
                const shift: Temporary = .init(full_result.ty, try cg.constInt(full_result.ty, info.bits - 1));
                // Use SRA so that any sign bits are duplicated. Now we can just check if ALL bits are set
                // for negative cases.
                const overflow = try cg.buildBinary(.OpShiftRightArithmetic, full_result, shift);

                const long_all_set: Temporary = .init(full_result.ty, try cg.constInt(full_result.ty, -1));
                const long_zero: Temporary = .init(full_result.ty, try cg.constInt(full_result.ty, 0));
                const mask = try cg.buildSelect(expected_overflow_bit, long_all_set, long_zero);

                const overflowed = try cg.buildCmp(.OpINotEqual, mask, overflow);

                break :blk .{ result, overflowed };
            }

            const low_bits, const high_bits = try cg.buildWideMul(.signed, lhs, rhs);

            // Truncate result if required.
            const result = try cg.normalize(low_bits, info);

            const all_set: Temporary = .init(lhs.ty, try cg.constInt(lhs.ty, -1));
            const mask = try cg.buildSelect(expected_overflow_bit, all_set, zero);

            // Like with unsigned, overflow happened if high_bits are not the ones we expect,
            // and we also need to check some ones from the low bits.

            const high_overflowed = try cg.buildCmp(.OpINotEqual, mask, high_bits);

            // If no overflow bits in low_bits, no extra work needs to be done.
            // Careful, we still have to check the sign bit, so this branch
            // only goes for i33 and such.
            if (info.backing_bits == info.bits + 1) break :blk .{ result, high_overflowed };

            // Shift the result bits away to get the overflow bits.
            const shift: Temporary = .init(lhs.ty, try cg.constInt(lhs.ty, info.bits - 1));
            // Use SRA so that any sign bits are duplicated. Now we can just check if ALL bits are set
            // for negative cases.
            const low_overflow = try cg.buildBinary(.OpShiftRightArithmetic, low_bits, shift);
            const low_overflowed = try cg.buildCmp(.OpINotEqual, mask, low_overflow);

            const overflowed = try cg.buildCmp(.OpLogicalOr, low_overflowed, high_overflowed);

            break :blk .{ result, overflowed };
        },
    };

    const ov = try cg.intFromBool(overflowed, .u1);

    const result_ty_id = try cg.resolveType(result_ty, .direct);
    return try cg.constructComposite(result_ty_id, &.{ try result.materialize(cg), try ov.materialize(cg) });
}

fn airShlOverflow(cg: *CodeGen, inst: Air.Inst.Index) !?Id {
    const zcu = cg.module.zcu;

    const ty_pl = cg.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const extra = cg.air.extraData(Air.Bin, ty_pl.payload).data;

    if (cg.typeOf(extra.lhs).isVector(zcu) and !cg.typeOf(extra.rhs).isVector(zcu)) {
        return cg.fail("vector shift with scalar rhs", .{});
    }

    const base = try cg.temporary(extra.lhs);
    const shift = try cg.temporary(extra.rhs);

    const result_ty = cg.typeOfIndex(inst);

    const info = cg.arithmeticTypeInfo(base.ty);
    switch (info.class) {
        .composite_integer => unreachable, // TODO
        .integer, .strange_integer => {},
        .float, .bool => unreachable,
    }

    // Sometimes Zig doesn't make both of the arguments the same types here. SPIR-V expects that,
    // so just manually upcast it if required.
    const casted_shift = try cg.buildConvert(base.ty.scalarType(zcu), shift);

    const left = try cg.buildBinary(.OpShiftLeftLogical, base, casted_shift);
    const result = try cg.normalize(left, info);

    const right = switch (info.signedness) {
        .unsigned => try cg.buildBinary(.OpShiftRightLogical, result, casted_shift),
        .signed => try cg.buildBinary(.OpShiftRightArithmetic, result, casted_shift),
    };

    const overflowed = try cg.buildCmp(.OpINotEqual, base, right);
    const ov = try cg.intFromBool(overflowed, .u1);

    const result_ty_id = try cg.resolveType(result_ty, .direct);
    return try cg.constructComposite(result_ty_id, &.{ try result.materialize(cg), try ov.materialize(cg) });
}

fn airMulAdd(cg: *CodeGen, inst: Air.Inst.Index) !?Id {
    const pl_op = cg.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
    const extra = cg.air.extraData(Air.Bin, pl_op.payload).data;

    const a = try cg.temporary(extra.lhs);
    const b = try cg.temporary(extra.rhs);
    const c = try cg.temporary(pl_op.operand);

    const result_ty = cg.typeOfIndex(inst);
    const info = cg.arithmeticTypeInfo(result_ty);
    assert(info.class == .float); // .mul_add is only emitted for floats

    const result = try cg.buildFma(a, b, c);
    return try result.materialize(cg);
}

fn airClzCtz(cg: *CodeGen, inst: Air.Inst.Index, op: UnaryOp) !?Id {
    if (cg.liveness.isUnused(inst)) return null;

    const zcu = cg.module.zcu;
    const ty_op = cg.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const operand = try cg.temporary(ty_op.operand);

    const scalar_result_ty = cg.typeOfIndex(inst).scalarType(zcu);

    const info = cg.arithmeticTypeInfo(operand.ty);
    switch (info.class) {
        .composite_integer => unreachable, // TODO
        .integer, .strange_integer => {},
        .float, .bool => unreachable,
    }

    const count = try cg.buildUnary(op, operand);

    // Result of OpenCL ctz/clz returns operand.ty, and we want result_ty.
    // result_ty is always large enough to hold the result, so we might have to down
    // cast it.
    const result = try cg.buildConvert(scalar_result_ty, count);
    return try result.materialize(cg);
}

fn airSelect(cg: *CodeGen, inst: Air.Inst.Index) !?Id {
    const pl_op = cg.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
    const extra = cg.air.extraData(Air.Bin, pl_op.payload).data;
    const pred = try cg.temporary(pl_op.operand);
    const a = try cg.temporary(extra.lhs);
    const b = try cg.temporary(extra.rhs);

    const result = try cg.buildSelect(pred, a, b);
    return try result.materialize(cg);
}

fn airSplat(cg: *CodeGen, inst: Air.Inst.Index) !?Id {
    const ty_op = cg.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;

    const operand_id = try cg.resolve(ty_op.operand);
    const result_ty = cg.typeOfIndex(inst);

    return try cg.constructCompositeSplat(result_ty, operand_id);
}

fn airReduce(cg: *CodeGen, inst: Air.Inst.Index) !?Id {
    const zcu = cg.module.zcu;
    const reduce = cg.air.instructions.items(.data)[@intFromEnum(inst)].reduce;
    const operand = try cg.resolve(reduce.operand);
    const operand_ty = cg.typeOf(reduce.operand);
    const scalar_ty = operand_ty.scalarType(zcu);
    const scalar_ty_id = try cg.resolveType(scalar_ty, .direct);
    const info = cg.arithmeticTypeInfo(operand_ty);
    const len = operand_ty.vectorLen(zcu);
    const first = try cg.extractVectorComponent(scalar_ty, operand, 0);

    switch (reduce.operation) {
        .Min, .Max => |op| {
            var result: Temporary = .init(scalar_ty, first);
            const cmp_op: MinMax = switch (op) {
                .Max => .max,
                .Min => .min,
                else => unreachable,
            };
            for (1..len) |i| {
                const lhs = result;
                const rhs_id = try cg.extractVectorComponent(scalar_ty, operand, @intCast(i));
                const rhs: Temporary = .init(scalar_ty, rhs_id);

                result = try cg.minMax(lhs, rhs, cmp_op);
            }

            return try result.materialize(cg);
        },
        else => {},
    }

    var result_id = first;

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
        const rhs = try cg.extractVectorComponent(scalar_ty, operand, @intCast(i));
        result_id = cg.module.allocId();

        try cg.body.emitRaw(cg.module.gpa, opcode, 4);
        cg.body.writeOperand(Id, scalar_ty_id);
        cg.body.writeOperand(Id, result_id);
        cg.body.writeOperand(Id, lhs);
        cg.body.writeOperand(Id, rhs);
    }

    return result_id;
}

fn airShuffleOne(cg: *CodeGen, inst: Air.Inst.Index) !?Id {
    const zcu = cg.module.zcu;
    const gpa = zcu.gpa;

    const unwrapped = cg.air.unwrapShuffleOne(zcu, inst);
    const mask = unwrapped.mask;
    const result_ty = unwrapped.result_ty;
    const elem_ty = result_ty.childType(zcu);
    const operand = try cg.resolve(unwrapped.operand);

    const scratch_top = cg.id_scratch.items.len;
    defer cg.id_scratch.shrinkRetainingCapacity(scratch_top);
    const constituents = try cg.id_scratch.addManyAsSlice(gpa, mask.len);

    for (constituents, mask) |*id, mask_elem| {
        id.* = switch (mask_elem.unwrap()) {
            .elem => |idx| try cg.extractVectorComponent(elem_ty, operand, idx),
            .value => |val| try cg.constant(elem_ty, .fromInterned(val), .direct),
        };
    }

    const result_ty_id = try cg.resolveType(result_ty, .direct);
    return try cg.constructComposite(result_ty_id, constituents);
}

fn airShuffleTwo(cg: *CodeGen, inst: Air.Inst.Index) !?Id {
    const zcu = cg.module.zcu;
    const gpa = zcu.gpa;

    const unwrapped = cg.air.unwrapShuffleTwo(zcu, inst);
    const mask = unwrapped.mask;
    const result_ty = unwrapped.result_ty;
    const elem_ty = result_ty.childType(zcu);
    const elem_ty_id = try cg.resolveType(elem_ty, .direct);
    const operand_a = try cg.resolve(unwrapped.operand_a);
    const operand_b = try cg.resolve(unwrapped.operand_b);

    const scratch_top = cg.id_scratch.items.len;
    defer cg.id_scratch.shrinkRetainingCapacity(scratch_top);
    const constituents = try cg.id_scratch.addManyAsSlice(gpa, mask.len);

    for (constituents, mask) |*id, mask_elem| {
        id.* = switch (mask_elem.unwrap()) {
            .a_elem => |idx| try cg.extractVectorComponent(elem_ty, operand_a, idx),
            .b_elem => |idx| try cg.extractVectorComponent(elem_ty, operand_b, idx),
            .undef => try cg.module.constUndef(elem_ty_id),
        };
    }

    const result_ty_id = try cg.resolveType(result_ty, .direct);
    return try cg.constructComposite(result_ty_id, constituents);
}

fn accessChainId(
    cg: *CodeGen,
    result_ty_id: Id,
    base: Id,
    indices: []const Id,
) !Id {
    const result_id = cg.module.allocId();
    try cg.body.emit(cg.module.gpa, .OpInBoundsAccessChain, .{
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
    cg: *CodeGen,
    result_ty_id: Id,
    base: Id,
    indices: []const u32,
) !Id {
    const gpa = cg.module.gpa;
    const scratch_top = cg.id_scratch.items.len;
    defer cg.id_scratch.shrinkRetainingCapacity(scratch_top);
    const ids = try cg.id_scratch.addManyAsSlice(gpa, indices.len);
    for (indices, ids) |index, *id| {
        id.* = try cg.constInt(.u32, index);
    }
    return try cg.accessChainId(result_ty_id, base, ids);
}

fn ptrAccessChain(
    cg: *CodeGen,
    result_ty_id: Id,
    base: Id,
    element: Id,
    indices: []const u32,
) !Id {
    const gpa = cg.module.gpa;
    const target = cg.module.zcu.getTarget();

    const scratch_top = cg.id_scratch.items.len;
    defer cg.id_scratch.shrinkRetainingCapacity(scratch_top);
    const ids = try cg.id_scratch.addManyAsSlice(gpa, indices.len);
    for (indices, ids) |index, *id| {
        id.* = try cg.constInt(.u32, index);
    }

    const result_id = cg.module.allocId();
    switch (target.os.tag) {
        .opencl, .amdhsa => {
            try cg.body.emit(gpa, .OpInBoundsPtrAccessChain, .{
                .id_result_type = result_ty_id,
                .id_result = result_id,
                .base = base,
                .element = element,
                .indexes = ids,
            });
        },
        .vulkan, .opengl => {
            try cg.body.emit(gpa, .OpPtrAccessChain, .{
                .id_result_type = result_ty_id,
                .id_result = result_id,
                .base = base,
                .element = element,
                .indexes = ids,
            });
        },
        else => unreachable,
    }
    return result_id;
}

fn ptrAdd(cg: *CodeGen, result_ty: Type, ptr_ty: Type, ptr_id: Id, offset_id: Id) !Id {
    const zcu = cg.module.zcu;
    const result_ty_id = try cg.resolveType(result_ty, .direct);

    switch (ptr_ty.ptrSize(zcu)) {
        .one => {
            // Pointer to array
            // TODO: Is this correct?
            return try cg.accessChainId(result_ty_id, ptr_id, &.{offset_id});
        },
        .c, .many => {
            return try cg.ptrAccessChain(result_ty_id, ptr_id, offset_id, &.{});
        },
        .slice => {
            // TODO: This is probably incorrect. A slice should be returned here, though this is what llvm does.
            const slice_ptr_id = try cg.extractField(result_ty, ptr_id, 0);
            return try cg.ptrAccessChain(result_ty_id, slice_ptr_id, offset_id, &.{});
        },
    }
}

fn airPtrAdd(cg: *CodeGen, inst: Air.Inst.Index) !?Id {
    const ty_pl = cg.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const bin_op = cg.air.extraData(Air.Bin, ty_pl.payload).data;
    const ptr_id = try cg.resolve(bin_op.lhs);
    const offset_id = try cg.resolve(bin_op.rhs);
    const ptr_ty = cg.typeOf(bin_op.lhs);
    const result_ty = cg.typeOfIndex(inst);

    return try cg.ptrAdd(result_ty, ptr_ty, ptr_id, offset_id);
}

fn airPtrSub(cg: *CodeGen, inst: Air.Inst.Index) !?Id {
    const ty_pl = cg.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const bin_op = cg.air.extraData(Air.Bin, ty_pl.payload).data;
    const ptr_id = try cg.resolve(bin_op.lhs);
    const ptr_ty = cg.typeOf(bin_op.lhs);
    const offset_id = try cg.resolve(bin_op.rhs);
    const offset_ty = cg.typeOf(bin_op.rhs);
    const offset_ty_id = try cg.resolveType(offset_ty, .direct);
    const result_ty = cg.typeOfIndex(inst);

    const negative_offset_id = cg.module.allocId();
    try cg.body.emit(cg.module.gpa, .OpSNegate, .{
        .id_result_type = offset_ty_id,
        .id_result = negative_offset_id,
        .operand = offset_id,
    });
    return try cg.ptrAdd(result_ty, ptr_ty, ptr_id, negative_offset_id);
}

fn cmp(
    cg: *CodeGen,
    op: std.math.CompareOperator,
    lhs: Temporary,
    rhs: Temporary,
) !Temporary {
    const gpa = cg.module.gpa;
    const pt = cg.pt;
    const zcu = cg.module.zcu;
    const ip = &zcu.intern_pool;
    const scalar_ty = lhs.ty.scalarType(zcu);
    const is_vector = lhs.ty.isVector(zcu);

    switch (scalar_ty.zigTypeTag(zcu)) {
        .int, .bool, .float => {},
        .@"enum" => {
            assert(!is_vector);
            const ty = lhs.ty.intTagType(zcu);
            return try cg.cmp(op, lhs.pun(ty), rhs.pun(ty));
        },
        .@"struct" => {
            const struct_ty = zcu.typeToPackedStruct(scalar_ty).?;
            const ty: Type = .fromInterned(struct_ty.backingIntTypeUnordered(ip));
            return try cg.cmp(op, lhs.pun(ty), rhs.pun(ty));
        },
        .error_set => {
            assert(!is_vector);
            const err_int_ty = try pt.errorIntType();
            return try cg.cmp(op, lhs.pun(err_int_ty), rhs.pun(err_int_ty));
        },
        .pointer => {
            assert(!is_vector);
            // Note that while SPIR-V offers OpPtrEqual and OpPtrNotEqual, they are
            // currently not implemented in the SPIR-V LLVM translator. Thus, we emit these using
            // OpConvertPtrToU...

            const usize_ty_id = try cg.resolveType(.usize, .direct);

            const lhs_int_id = cg.module.allocId();
            try cg.body.emit(gpa, .OpConvertPtrToU, .{
                .id_result_type = usize_ty_id,
                .id_result = lhs_int_id,
                .pointer = try lhs.materialize(cg),
            });

            const rhs_int_id = cg.module.allocId();
            try cg.body.emit(gpa, .OpConvertPtrToU, .{
                .id_result_type = usize_ty_id,
                .id_result = rhs_int_id,
                .pointer = try rhs.materialize(cg),
            });

            const lhs_int: Temporary = .init(.usize, lhs_int_id);
            const rhs_int: Temporary = .init(.usize, rhs_int_id);
            return try cg.cmp(op, lhs_int, rhs_int);
        },
        .optional => {
            assert(!is_vector);

            const ty = lhs.ty;

            const payload_ty = ty.optionalChild(zcu);
            if (ty.optionalReprIsPayload(zcu)) {
                assert(payload_ty.hasRuntimeBitsIgnoreComptime(zcu));
                assert(!payload_ty.isSlice(zcu));

                return try cg.cmp(op, lhs.pun(payload_ty), rhs.pun(payload_ty));
            }

            const lhs_id = try lhs.materialize(cg);
            const rhs_id = try rhs.materialize(cg);

            const lhs_valid_id = if (payload_ty.hasRuntimeBitsIgnoreComptime(zcu))
                try cg.extractField(.bool, lhs_id, 1)
            else
                try cg.convertToDirect(.bool, lhs_id);

            const rhs_valid_id = if (payload_ty.hasRuntimeBitsIgnoreComptime(zcu))
                try cg.extractField(.bool, rhs_id, 1)
            else
                try cg.convertToDirect(.bool, rhs_id);

            const lhs_valid: Temporary = .init(.bool, lhs_valid_id);
            const rhs_valid: Temporary = .init(.bool, rhs_valid_id);

            if (!payload_ty.hasRuntimeBitsIgnoreComptime(zcu)) {
                return try cg.cmp(op, lhs_valid, rhs_valid);
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

            const lhs_pl_id = try cg.extractField(payload_ty, lhs_id, 0);
            const rhs_pl_id = try cg.extractField(payload_ty, rhs_id, 0);

            const lhs_pl: Temporary = .init(payload_ty, lhs_pl_id);
            const rhs_pl: Temporary = .init(payload_ty, rhs_pl_id);

            return switch (op) {
                .eq => try cg.buildBinary(
                    .OpLogicalAnd,
                    try cg.cmp(.eq, lhs_valid, rhs_valid),
                    try cg.buildBinary(
                        .OpLogicalOr,
                        try cg.buildUnary(.l_not, lhs_valid),
                        try cg.cmp(.eq, lhs_pl, rhs_pl),
                    ),
                ),
                .neq => try cg.buildBinary(
                    .OpLogicalOr,
                    try cg.cmp(.neq, lhs_valid, rhs_valid),
                    try cg.buildBinary(
                        .OpLogicalAnd,
                        lhs_valid,
                        try cg.cmp(.neq, lhs_pl, rhs_pl),
                    ),
                ),
                else => unreachable,
            };
        },
        else => |ty| return cg.todo("implement cmp operation for '{s}' type", .{@tagName(ty)}),
    }

    const info = cg.arithmeticTypeInfo(scalar_ty);
    const pred: Opcode = switch (info.class) {
        .composite_integer => unreachable, // TODO
        .float => switch (op) {
            .eq => .OpFOrdEqual,
            .neq => .OpFUnordNotEqual,
            .lt => .OpFOrdLessThan,
            .lte => .OpFOrdLessThanEqual,
            .gt => .OpFOrdGreaterThan,
            .gte => .OpFOrdGreaterThanEqual,
        },
        .bool => switch (op) {
            .eq => .OpLogicalEqual,
            .neq => .OpLogicalNotEqual,
            else => unreachable,
        },
        .integer, .strange_integer => switch (info.signedness) {
            .signed => switch (op) {
                .eq => .OpIEqual,
                .neq => .OpINotEqual,
                .lt => .OpSLessThan,
                .lte => .OpSLessThanEqual,
                .gt => .OpSGreaterThan,
                .gte => .OpSGreaterThanEqual,
            },
            .unsigned => switch (op) {
                .eq => .OpIEqual,
                .neq => .OpINotEqual,
                .lt => .OpULessThan,
                .lte => .OpULessThanEqual,
                .gt => .OpUGreaterThan,
                .gte => .OpUGreaterThanEqual,
            },
        },
    };

    return try cg.buildCmp(pred, lhs, rhs);
}

fn airCmp(
    cg: *CodeGen,
    inst: Air.Inst.Index,
    comptime op: std.math.CompareOperator,
) !?Id {
    const bin_op = cg.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const lhs = try cg.temporary(bin_op.lhs);
    const rhs = try cg.temporary(bin_op.rhs);

    const result = try cg.cmp(op, lhs, rhs);
    return try result.materialize(cg);
}

fn airVectorCmp(cg: *CodeGen, inst: Air.Inst.Index) !?Id {
    const ty_pl = cg.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const vec_cmp = cg.air.extraData(Air.VectorCmp, ty_pl.payload).data;
    const lhs = try cg.temporary(vec_cmp.lhs);
    const rhs = try cg.temporary(vec_cmp.rhs);
    const op = vec_cmp.compareOperator();

    const result = try cg.cmp(op, lhs, rhs);
    return try result.materialize(cg);
}

/// Bitcast one type to another. Note: both types, input, output are expected in **direct** representation.
fn bitCast(
    cg: *CodeGen,
    dst_ty: Type,
    src_ty: Type,
    src_id: Id,
) !Id {
    const gpa = cg.module.gpa;
    const zcu = cg.module.zcu;
    const target = zcu.getTarget();
    const src_ty_id = try cg.resolveType(src_ty, .direct);
    const dst_ty_id = try cg.resolveType(dst_ty, .direct);

    const result_id = blk: {
        if (src_ty_id == dst_ty_id) break :blk src_id;

        // TODO: Some more cases are missing here
        //   See fn bitCast in llvm.zig

        if (src_ty.zigTypeTag(zcu) == .int and dst_ty.isPtrAtRuntime(zcu)) {
            if (target.os.tag != .opencl) {
                if (dst_ty.ptrAddressSpace(zcu) != .physical_storage_buffer) {
                    return cg.fail(
                        "cannot cast integer to pointer with address space '{s}'",
                        .{@tagName(dst_ty.ptrAddressSpace(zcu))},
                    );
                }
            }

            const result_id = cg.module.allocId();
            try cg.body.emit(gpa, .OpConvertUToPtr, .{
                .id_result_type = dst_ty_id,
                .id_result = result_id,
                .integer_value = src_id,
            });
            break :blk result_id;
        }

        // We can only use OpBitcast for specific conversions: between numerical types, and
        // between pointers. If the resolved spir-v types fall into this category then emit OpBitcast,
        // otherwise use a temporary and perform a pointer cast.
        const can_bitcast = (src_ty.isNumeric(zcu) and dst_ty.isNumeric(zcu)) or (src_ty.isPtrAtRuntime(zcu) and dst_ty.isPtrAtRuntime(zcu));
        if (can_bitcast) {
            const result_id = cg.module.allocId();
            try cg.body.emit(gpa, .OpBitcast, .{
                .id_result_type = dst_ty_id,
                .id_result = result_id,
                .operand = src_id,
            });

            break :blk result_id;
        }

        const dst_ptr_ty_id = try cg.module.ptrType(dst_ty_id, .function);

        const src_ty_indirect_id = try cg.resolveType(src_ty, .indirect);
        const tmp_id = try cg.alloc(src_ty_indirect_id, null);
        try cg.store(src_ty, tmp_id, src_id, .{});
        const casted_ptr_id = cg.module.allocId();
        try cg.body.emit(gpa, .OpBitcast, .{
            .id_result_type = dst_ptr_ty_id,
            .id_result = casted_ptr_id,
            .operand = tmp_id,
        });
        break :blk try cg.load(dst_ty, casted_ptr_id, .{});
    };

    // Because strange integers use sign-extended representation, we may need to normalize
    // the result here.
    // TODO: This detail could cause stuff like @as(*const i1, @ptrCast(&@as(u1, 1))) to break
    // should we change the representation of strange integers?
    if (dst_ty.zigTypeTag(zcu) == .int) {
        const info = cg.arithmeticTypeInfo(dst_ty);
        const result = try cg.normalize(Temporary.init(dst_ty, result_id), info);
        return try result.materialize(cg);
    }

    return result_id;
}

fn airBitCast(cg: *CodeGen, inst: Air.Inst.Index) !?Id {
    const ty_op = cg.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const operand_ty = cg.typeOf(ty_op.operand);
    const result_ty = cg.typeOfIndex(inst);
    if (operand_ty.toIntern() == .bool_type) {
        const operand = try cg.temporary(ty_op.operand);
        const result = try cg.intFromBool(operand, .u1);
        return try result.materialize(cg);
    }
    const operand_id = try cg.resolve(ty_op.operand);
    return try cg.bitCast(result_ty, operand_ty, operand_id);
}

fn airIntCast(cg: *CodeGen, inst: Air.Inst.Index) !?Id {
    const ty_op = cg.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const src = try cg.temporary(ty_op.operand);
    const dst_ty = cg.typeOfIndex(inst);

    const src_info = cg.arithmeticTypeInfo(src.ty);
    const dst_info = cg.arithmeticTypeInfo(dst_ty);

    if (src_info.backing_bits == dst_info.backing_bits) {
        return try src.materialize(cg);
    }

    const converted = try cg.buildConvert(dst_ty, src);

    // Make sure to normalize the result if shrinking.
    // Because strange ints are sign extended in their backing
    // type, we don't need to normalize when growing the type. The
    // representation is already the same.
    const result = if (dst_info.bits < src_info.bits)
        try cg.normalize(converted, dst_info)
    else
        converted;

    return try result.materialize(cg);
}

fn intFromPtr(cg: *CodeGen, operand_id: Id) !Id {
    const result_type_id = try cg.resolveType(.usize, .direct);
    const result_id = cg.module.allocId();
    try cg.body.emit(cg.module.gpa, .OpConvertPtrToU, .{
        .id_result_type = result_type_id,
        .id_result = result_id,
        .pointer = operand_id,
    });
    return result_id;
}

fn airFloatFromInt(cg: *CodeGen, inst: Air.Inst.Index) !?Id {
    const ty_op = cg.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const operand_ty = cg.typeOf(ty_op.operand);
    const operand_id = try cg.resolve(ty_op.operand);
    const result_ty = cg.typeOfIndex(inst);
    return try cg.floatFromInt(result_ty, operand_ty, operand_id);
}

fn floatFromInt(cg: *CodeGen, result_ty: Type, operand_ty: Type, operand_id: Id) !Id {
    const gpa = cg.module.gpa;
    const operand_info = cg.arithmeticTypeInfo(operand_ty);
    const result_id = cg.module.allocId();
    const result_ty_id = try cg.resolveType(result_ty, .direct);
    switch (operand_info.signedness) {
        .signed => try cg.body.emit(gpa, .OpConvertSToF, .{
            .id_result_type = result_ty_id,
            .id_result = result_id,
            .signed_value = operand_id,
        }),
        .unsigned => try cg.body.emit(gpa, .OpConvertUToF, .{
            .id_result_type = result_ty_id,
            .id_result = result_id,
            .unsigned_value = operand_id,
        }),
    }
    return result_id;
}

fn airIntFromFloat(cg: *CodeGen, inst: Air.Inst.Index) !?Id {
    const ty_op = cg.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const operand_id = try cg.resolve(ty_op.operand);
    const result_ty = cg.typeOfIndex(inst);
    return try cg.intFromFloat(result_ty, operand_id);
}

fn intFromFloat(cg: *CodeGen, result_ty: Type, operand_id: Id) !Id {
    const gpa = cg.module.gpa;
    const result_info = cg.arithmeticTypeInfo(result_ty);
    const result_ty_id = try cg.resolveType(result_ty, .direct);
    const result_id = cg.module.allocId();
    switch (result_info.signedness) {
        .signed => try cg.body.emit(gpa, .OpConvertFToS, .{
            .id_result_type = result_ty_id,
            .id_result = result_id,
            .float_value = operand_id,
        }),
        .unsigned => try cg.body.emit(gpa, .OpConvertFToU, .{
            .id_result_type = result_ty_id,
            .id_result = result_id,
            .float_value = operand_id,
        }),
    }
    return result_id;
}

fn airFloatCast(cg: *CodeGen, inst: Air.Inst.Index) !?Id {
    const ty_op = cg.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const operand = try cg.temporary(ty_op.operand);
    const dest_ty = cg.typeOfIndex(inst);
    const result = try cg.buildConvert(dest_ty, operand);
    return try result.materialize(cg);
}

fn airNot(cg: *CodeGen, inst: Air.Inst.Index) !?Id {
    const ty_op = cg.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const operand = try cg.temporary(ty_op.operand);
    const result_ty = cg.typeOfIndex(inst);
    const info = cg.arithmeticTypeInfo(result_ty);

    const result = switch (info.class) {
        .bool => try cg.buildUnary(.l_not, operand),
        .float => unreachable,
        .composite_integer => unreachable, // TODO
        .strange_integer, .integer => blk: {
            const complement = try cg.buildUnary(.bit_not, operand);
            break :blk try cg.normalize(complement, info);
        },
    };

    return try result.materialize(cg);
}

fn airArrayToSlice(cg: *CodeGen, inst: Air.Inst.Index) !?Id {
    const zcu = cg.module.zcu;
    const ty_op = cg.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const array_ptr_ty = cg.typeOf(ty_op.operand);
    const array_ty = array_ptr_ty.childType(zcu);
    const slice_ty = cg.typeOfIndex(inst);
    const elem_ptr_ty = slice_ty.slicePtrFieldType(zcu);

    const elem_ptr_ty_id = try cg.resolveType(elem_ptr_ty, .direct);

    const array_ptr_id = try cg.resolve(ty_op.operand);
    const len_id = try cg.constInt(.usize, array_ty.arrayLen(zcu));

    const elem_ptr_id = if (!array_ty.hasRuntimeBitsIgnoreComptime(zcu))
        // Note: The pointer is something like *opaque{}, so we need to bitcast it to the element type.
        try cg.bitCast(elem_ptr_ty, array_ptr_ty, array_ptr_id)
    else
        // Convert the pointer-to-array to a pointer to the first element.
        try cg.accessChain(elem_ptr_ty_id, array_ptr_id, &.{0});

    const slice_ty_id = try cg.resolveType(slice_ty, .direct);
    return try cg.constructComposite(slice_ty_id, &.{ elem_ptr_id, len_id });
}

fn airSlice(cg: *CodeGen, inst: Air.Inst.Index) !?Id {
    const ty_pl = cg.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const bin_op = cg.air.extraData(Air.Bin, ty_pl.payload).data;
    const ptr_id = try cg.resolve(bin_op.lhs);
    const len_id = try cg.resolve(bin_op.rhs);
    const slice_ty = cg.typeOfIndex(inst);
    const slice_ty_id = try cg.resolveType(slice_ty, .direct);
    return try cg.constructComposite(slice_ty_id, &.{ ptr_id, len_id });
}

fn airAggregateInit(cg: *CodeGen, inst: Air.Inst.Index) !?Id {
    const gpa = cg.module.gpa;
    const pt = cg.pt;
    const zcu = cg.module.zcu;
    const ip = &zcu.intern_pool;
    const target = cg.module.zcu.getTarget();
    const ty_pl = cg.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const result_ty = cg.typeOfIndex(inst);
    const len: usize = @intCast(result_ty.arrayLen(zcu));
    const elements: []const Air.Inst.Ref = @ptrCast(cg.air.extra.items[ty_pl.payload..][0..len]);

    switch (result_ty.zigTypeTag(zcu)) {
        .@"struct" => {
            if (zcu.typeToPackedStruct(result_ty)) |struct_type| {
                comptime assert(Type.packed_struct_layout_version == 2);
                const backing_int_ty: Type = .fromInterned(struct_type.backingIntTypeUnordered(ip));
                var running_int_id = try cg.constInt(backing_int_ty, 0);
                var running_bits: u16 = 0;
                for (struct_type.field_types.get(ip), elements) |field_ty_ip, element| {
                    const field_ty: Type = .fromInterned(field_ty_ip);
                    if (!field_ty.hasRuntimeBitsIgnoreComptime(zcu)) continue;
                    const field_id = try cg.resolve(element);
                    const ty_bit_size: u16 = @intCast(field_ty.bitSize(zcu));
                    const field_int_ty = try cg.pt.intType(.unsigned, ty_bit_size);
                    const field_int_id = blk: {
                        if (field_ty.isPtrAtRuntime(zcu)) {
                            assert(target.cpu.arch == .spirv64 and
                                field_ty.ptrAddressSpace(zcu) == .storage_buffer);
                            break :blk try cg.intFromPtr(field_id);
                        }
                        break :blk try cg.bitCast(field_int_ty, field_ty, field_id);
                    };
                    const shift_rhs = try cg.constInt(backing_int_ty, running_bits);
                    const extended_int_conv = try cg.buildConvert(backing_int_ty, .{
                        .ty = field_int_ty,
                        .value = .{ .singleton = field_int_id },
                    });
                    const shifted = try cg.buildBinary(.OpShiftLeftLogical, extended_int_conv, .{
                        .ty = backing_int_ty,
                        .value = .{ .singleton = shift_rhs },
                    });
                    const running_int_tmp = try cg.buildBinary(
                        .OpBitwiseOr,
                        .{ .ty = backing_int_ty, .value = .{ .singleton = running_int_id } },
                        shifted,
                    );
                    running_int_id = try running_int_tmp.materialize(cg);
                    running_bits += ty_bit_size;
                }
                return running_int_id;
            }

            const scratch_top = cg.id_scratch.items.len;
            defer cg.id_scratch.shrinkRetainingCapacity(scratch_top);
            const constituents = try cg.id_scratch.addManyAsSlice(gpa, elements.len);

            const types = try gpa.alloc(Type, elements.len);
            defer gpa.free(types);

            var index: usize = 0;

            switch (ip.indexToKey(result_ty.toIntern())) {
                .tuple_type => |tuple| {
                    for (tuple.types.get(ip), elements, 0..) |field_ty, element, i| {
                        if ((try result_ty.structFieldValueComptime(pt, i)) != null) continue;
                        assert(Type.fromInterned(field_ty).hasRuntimeBits(zcu));

                        const id = try cg.resolve(element);
                        types[index] = .fromInterned(field_ty);
                        constituents[index] = try cg.convertToIndirect(.fromInterned(field_ty), id);
                        index += 1;
                    }
                },
                .struct_type => {
                    const struct_type = ip.loadStructType(result_ty.toIntern());
                    var it = struct_type.iterateRuntimeOrder(ip);
                    for (elements, 0..) |element, i| {
                        const field_index = it.next().?;
                        if ((try result_ty.structFieldValueComptime(pt, i)) != null) continue;
                        const field_ty: Type = .fromInterned(struct_type.field_types.get(ip)[field_index]);
                        assert(field_ty.hasRuntimeBitsIgnoreComptime(zcu));

                        const id = try cg.resolve(element);
                        types[index] = field_ty;
                        constituents[index] = try cg.convertToIndirect(field_ty, id);
                        index += 1;
                    }
                },
                else => unreachable,
            }

            const result_ty_id = try cg.resolveType(result_ty, .direct);
            return try cg.constructComposite(result_ty_id, constituents[0..index]);
        },
        .vector => {
            const n_elems = result_ty.vectorLen(zcu);
            const scratch_top = cg.id_scratch.items.len;
            defer cg.id_scratch.shrinkRetainingCapacity(scratch_top);
            const elem_ids = try cg.id_scratch.addManyAsSlice(gpa, n_elems);

            for (elements, 0..) |element, i| {
                elem_ids[i] = try cg.resolve(element);
            }

            const result_ty_id = try cg.resolveType(result_ty, .direct);
            return try cg.constructComposite(result_ty_id, elem_ids);
        },
        .array => {
            const array_info = result_ty.arrayInfo(zcu);
            const n_elems: usize = @intCast(result_ty.arrayLenIncludingSentinel(zcu));
            const scratch_top = cg.id_scratch.items.len;
            defer cg.id_scratch.shrinkRetainingCapacity(scratch_top);
            const elem_ids = try cg.id_scratch.addManyAsSlice(gpa, n_elems);

            for (elements, 0..) |element, i| {
                const id = try cg.resolve(element);
                elem_ids[i] = try cg.convertToIndirect(array_info.elem_type, id);
            }

            if (array_info.sentinel) |sentinel_val| {
                elem_ids[n_elems - 1] = try cg.constant(array_info.elem_type, sentinel_val, .indirect);
            }

            const result_ty_id = try cg.resolveType(result_ty, .direct);
            return try cg.constructComposite(result_ty_id, elem_ids);
        },
        else => unreachable,
    }
}

fn sliceOrArrayLen(cg: *CodeGen, operand_id: Id, ty: Type) !Id {
    const zcu = cg.module.zcu;
    switch (ty.ptrSize(zcu)) {
        .slice => return cg.extractField(.usize, operand_id, 1),
        .one => {
            const array_ty = ty.childType(zcu);
            const elem_ty = array_ty.childType(zcu);
            const abi_size = elem_ty.abiSize(zcu);
            const size = array_ty.arrayLenIncludingSentinel(zcu) * abi_size;
            return try cg.constInt(.usize, size);
        },
        .many, .c => unreachable,
    }
}

fn sliceOrArrayPtr(cg: *CodeGen, operand_id: Id, ty: Type) !Id {
    const zcu = cg.module.zcu;
    if (ty.isSlice(zcu)) {
        const ptr_ty = ty.slicePtrFieldType(zcu);
        return cg.extractField(ptr_ty, operand_id, 0);
    }
    return operand_id;
}

fn airMemcpy(cg: *CodeGen, inst: Air.Inst.Index) !void {
    const bin_op = cg.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const dest_slice = try cg.resolve(bin_op.lhs);
    const src_slice = try cg.resolve(bin_op.rhs);
    const dest_ty = cg.typeOf(bin_op.lhs);
    const src_ty = cg.typeOf(bin_op.rhs);
    const dest_ptr = try cg.sliceOrArrayPtr(dest_slice, dest_ty);
    const src_ptr = try cg.sliceOrArrayPtr(src_slice, src_ty);
    const len = try cg.sliceOrArrayLen(dest_slice, dest_ty);
    try cg.body.emit(cg.module.gpa, .OpCopyMemorySized, .{
        .target = dest_ptr,
        .source = src_ptr,
        .size = len,
    });
}

fn airMemmove(cg: *CodeGen, inst: Air.Inst.Index) !void {
    _ = inst;
    return cg.fail("TODO implement airMemcpy for spirv", .{});
}

fn airSliceField(cg: *CodeGen, inst: Air.Inst.Index, field: u32) !?Id {
    const ty_op = cg.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const field_ty = cg.typeOfIndex(inst);
    const operand_id = try cg.resolve(ty_op.operand);
    return try cg.extractField(field_ty, operand_id, field);
}

fn airSliceElemPtr(cg: *CodeGen, inst: Air.Inst.Index) !?Id {
    const zcu = cg.module.zcu;
    const ty_pl = cg.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const bin_op = cg.air.extraData(Air.Bin, ty_pl.payload).data;
    const slice_ty = cg.typeOf(bin_op.lhs);
    if (!slice_ty.isVolatilePtr(zcu) and cg.liveness.isUnused(inst)) return null;

    const slice_id = try cg.resolve(bin_op.lhs);
    const index_id = try cg.resolve(bin_op.rhs);

    const ptr_ty = cg.typeOfIndex(inst);
    const ptr_ty_id = try cg.resolveType(ptr_ty, .direct);

    const slice_ptr = try cg.extractField(ptr_ty, slice_id, 0);
    return try cg.ptrAccessChain(ptr_ty_id, slice_ptr, index_id, &.{});
}

fn airSliceElemVal(cg: *CodeGen, inst: Air.Inst.Index) !?Id {
    const zcu = cg.module.zcu;
    const bin_op = cg.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const slice_ty = cg.typeOf(bin_op.lhs);
    if (!slice_ty.isVolatilePtr(zcu) and cg.liveness.isUnused(inst)) return null;

    const slice_id = try cg.resolve(bin_op.lhs);
    const index_id = try cg.resolve(bin_op.rhs);

    const ptr_ty = slice_ty.slicePtrFieldType(zcu);
    const ptr_ty_id = try cg.resolveType(ptr_ty, .direct);

    const slice_ptr = try cg.extractField(ptr_ty, slice_id, 0);
    const elem_ptr = try cg.ptrAccessChain(ptr_ty_id, slice_ptr, index_id, &.{});
    return try cg.load(slice_ty.childType(zcu), elem_ptr, .{ .is_volatile = slice_ty.isVolatilePtr(zcu) });
}

fn ptrElemPtr(cg: *CodeGen, ptr_ty: Type, ptr_id: Id, index_id: Id) !Id {
    const zcu = cg.module.zcu;
    // Construct new pointer type for the resulting pointer
    const elem_ty = ptr_ty.elemType2(zcu); // use elemType() so that we get T for *[N]T.
    const elem_ty_id = try cg.resolveType(elem_ty, .indirect);
    const elem_ptr_ty_id = try cg.module.ptrType(elem_ty_id, cg.module.storageClass(ptr_ty.ptrAddressSpace(zcu)));
    if (ptr_ty.isSinglePointer(zcu)) {
        // Pointer-to-array. In this case, the resulting pointer is not of the same type
        // as the ptr_ty (we want a *T, not a *[N]T), and hence we need to use accessChain.
        return try cg.accessChainId(elem_ptr_ty_id, ptr_id, &.{index_id});
    } else {
        // Resulting pointer type is the same as the ptr_ty, so use ptrAccessChain
        return try cg.ptrAccessChain(elem_ptr_ty_id, ptr_id, index_id, &.{});
    }
}

fn airPtrElemPtr(cg: *CodeGen, inst: Air.Inst.Index) !?Id {
    const zcu = cg.module.zcu;
    const ty_pl = cg.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const bin_op = cg.air.extraData(Air.Bin, ty_pl.payload).data;
    const src_ptr_ty = cg.typeOf(bin_op.lhs);
    const elem_ty = src_ptr_ty.childType(zcu);
    const ptr_id = try cg.resolve(bin_op.lhs);

    if (!elem_ty.hasRuntimeBitsIgnoreComptime(zcu)) {
        const dst_ptr_ty = cg.typeOfIndex(inst);
        return try cg.bitCast(dst_ptr_ty, src_ptr_ty, ptr_id);
    }

    const index_id = try cg.resolve(bin_op.rhs);
    return try cg.ptrElemPtr(src_ptr_ty, ptr_id, index_id);
}

fn airArrayElemVal(cg: *CodeGen, inst: Air.Inst.Index) !?Id {
    const gpa = cg.module.gpa;
    const zcu = cg.module.zcu;
    const bin_op = cg.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const array_ty = cg.typeOf(bin_op.lhs);
    const elem_ty = array_ty.childType(zcu);
    const array_id = try cg.resolve(bin_op.lhs);
    const index_id = try cg.resolve(bin_op.rhs);

    // SPIR-V doesn't have an array indexing function for some damn reason.
    // For now, just generate a temporary and use that.
    // TODO: This backend probably also should use isByRef from llvm...

    const is_vector = array_ty.isVector(zcu);
    const elem_repr: Repr = if (is_vector) .direct else .indirect;
    const array_ty_id = try cg.resolveType(array_ty, .direct);
    const elem_ty_id = try cg.resolveType(elem_ty, elem_repr);
    const ptr_array_ty_id = try cg.module.ptrType(array_ty_id, .function);
    const ptr_elem_ty_id = try cg.module.ptrType(elem_ty_id, .function);

    const tmp_id = cg.module.allocId();
    try cg.prologue.emit(gpa, .OpVariable, .{
        .id_result_type = ptr_array_ty_id,
        .id_result = tmp_id,
        .storage_class = .function,
    });

    try cg.body.emit(gpa, .OpStore, .{
        .pointer = tmp_id,
        .object = array_id,
    });

    const elem_ptr_id = try cg.accessChainId(ptr_elem_ty_id, tmp_id, &.{index_id});

    const result_id = cg.module.allocId();
    try cg.body.emit(gpa, .OpLoad, .{
        .id_result_type = try cg.resolveType(elem_ty, elem_repr),
        .id_result = result_id,
        .pointer = elem_ptr_id,
    });

    if (is_vector) {
        // Result is already in direct representation
        return result_id;
    }

    // This is an array type; the elements are stored in indirect representation.
    // We have to convert the type to direct.

    return try cg.convertToDirect(elem_ty, result_id);
}

fn airPtrElemVal(cg: *CodeGen, inst: Air.Inst.Index) !?Id {
    const zcu = cg.module.zcu;
    const bin_op = cg.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const ptr_ty = cg.typeOf(bin_op.lhs);
    const elem_ty = cg.typeOfIndex(inst);
    const ptr_id = try cg.resolve(bin_op.lhs);
    const index_id = try cg.resolve(bin_op.rhs);
    const elem_ptr_id = try cg.ptrElemPtr(ptr_ty, ptr_id, index_id);
    return try cg.load(elem_ty, elem_ptr_id, .{ .is_volatile = ptr_ty.isVolatilePtr(zcu) });
}

fn airSetUnionTag(cg: *CodeGen, inst: Air.Inst.Index) !void {
    const zcu = cg.module.zcu;
    const bin_op = cg.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const un_ptr_ty = cg.typeOf(bin_op.lhs);
    const un_ty = un_ptr_ty.childType(zcu);
    const layout = cg.unionLayout(un_ty);

    if (layout.tag_size == 0) return;

    const tag_ty = un_ty.unionTagTypeSafety(zcu).?;
    const tag_ty_id = try cg.resolveType(tag_ty, .indirect);
    const tag_ptr_ty_id = try cg.module.ptrType(tag_ty_id, cg.module.storageClass(un_ptr_ty.ptrAddressSpace(zcu)));

    const union_ptr_id = try cg.resolve(bin_op.lhs);
    const new_tag_id = try cg.resolve(bin_op.rhs);

    if (!layout.has_payload) {
        try cg.store(tag_ty, union_ptr_id, new_tag_id, .{ .is_volatile = un_ptr_ty.isVolatilePtr(zcu) });
    } else {
        const ptr_id = try cg.accessChain(tag_ptr_ty_id, union_ptr_id, &.{layout.tag_index});
        try cg.store(tag_ty, ptr_id, new_tag_id, .{ .is_volatile = un_ptr_ty.isVolatilePtr(zcu) });
    }
}

fn airGetUnionTag(cg: *CodeGen, inst: Air.Inst.Index) !?Id {
    const ty_op = cg.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const un_ty = cg.typeOf(ty_op.operand);

    const zcu = cg.module.zcu;
    const layout = cg.unionLayout(un_ty);
    if (layout.tag_size == 0) return null;

    const union_handle = try cg.resolve(ty_op.operand);
    if (!layout.has_payload) return union_handle;

    const tag_ty = un_ty.unionTagTypeSafety(zcu).?;
    return try cg.extractField(tag_ty, union_handle, layout.tag_index);
}

fn unionInit(
    cg: *CodeGen,
    ty: Type,
    active_field: u32,
    payload: ?Id,
) !Id {
    // To initialize a union, generate a temporary variable with the
    // union type, then get the field pointer and pointer-cast it to the
    // right type to store it. Finally load the entire union.

    // Note: The result here is not cached, because it generates runtime code.

    const pt = cg.pt;
    const zcu = cg.module.zcu;
    const ip = &zcu.intern_pool;
    const union_ty = zcu.typeToUnion(ty).?;
    const tag_ty: Type = .fromInterned(union_ty.enum_tag_ty);

    const layout = cg.unionLayout(ty);
    const payload_ty: Type = .fromInterned(union_ty.field_types.get(ip)[active_field]);

    if (union_ty.flagsUnordered(ip).layout == .@"packed") {
        if (!payload_ty.hasRuntimeBitsIgnoreComptime(zcu)) {
            const int_ty = try pt.intType(.unsigned, @intCast(ty.bitSize(zcu)));
            return cg.constInt(int_ty, 0);
        }

        assert(payload != null);
        if (payload_ty.isInt(zcu)) {
            if (ty.bitSize(zcu) == payload_ty.bitSize(zcu)) {
                return cg.bitCast(ty, payload_ty, payload.?);
            }

            const trunc = try cg.buildConvert(ty, .{ .ty = payload_ty, .value = .{ .singleton = payload.? } });
            return try trunc.materialize(cg);
        }

        const payload_int_ty = try pt.intType(.unsigned, @intCast(payload_ty.bitSize(zcu)));
        const payload_int = if (payload_ty.ip_index == .bool_type)
            try cg.convertToIndirect(payload_ty, payload.?)
        else
            try cg.bitCast(payload_int_ty, payload_ty, payload.?);
        const trunc = try cg.buildConvert(ty, .{ .ty = payload_int_ty, .value = .{ .singleton = payload_int } });
        return try trunc.materialize(cg);
    }

    const tag_int = if (layout.tag_size != 0) blk: {
        const tag_val = try pt.enumValueFieldIndex(tag_ty, active_field);
        const tag_int_val = try tag_val.intFromEnum(tag_ty, pt);
        break :blk tag_int_val.toUnsignedInt(zcu);
    } else 0;

    if (!layout.has_payload) {
        return try cg.constInt(tag_ty, tag_int);
    }

    const ty_id = try cg.resolveType(ty, .indirect);
    const tmp_id = try cg.alloc(ty_id, null);

    if (layout.tag_size != 0) {
        const tag_ty_id = try cg.resolveType(tag_ty, .indirect);
        const tag_ptr_ty_id = try cg.module.ptrType(tag_ty_id, .function);
        const ptr_id = try cg.accessChain(tag_ptr_ty_id, tmp_id, &.{@as(u32, @intCast(layout.tag_index))});
        const tag_id = try cg.constInt(tag_ty, tag_int);
        try cg.store(tag_ty, ptr_id, tag_id, .{});
    }

    if (payload_ty.hasRuntimeBitsIgnoreComptime(zcu)) {
        const layout_payload_ty_id = try cg.resolveType(layout.payload_ty, .indirect);
        const pl_ptr_ty_id = try cg.module.ptrType(layout_payload_ty_id, .function);
        const pl_ptr_id = try cg.accessChain(pl_ptr_ty_id, tmp_id, &.{layout.payload_index});
        const active_pl_ptr_id = if (!layout.payload_ty.eql(payload_ty, zcu)) blk: {
            const payload_ty_id = try cg.resolveType(payload_ty, .indirect);
            const active_pl_ptr_ty_id = try cg.module.ptrType(payload_ty_id, .function);
            const active_pl_ptr_id = cg.module.allocId();
            try cg.body.emit(cg.module.gpa, .OpBitcast, .{
                .id_result_type = active_pl_ptr_ty_id,
                .id_result = active_pl_ptr_id,
                .operand = pl_ptr_id,
            });
            break :blk active_pl_ptr_id;
        } else pl_ptr_id;

        try cg.store(payload_ty, active_pl_ptr_id, payload.?, .{});
    } else {
        assert(payload == null);
    }

    // Just leave the padding fields uninitialized...
    // TODO: Or should we initialize them with undef explicitly?

    return try cg.load(ty, tmp_id, .{});
}

fn airUnionInit(cg: *CodeGen, inst: Air.Inst.Index) !?Id {
    const zcu = cg.module.zcu;
    const ip = &zcu.intern_pool;
    const ty_pl = cg.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const extra = cg.air.extraData(Air.UnionInit, ty_pl.payload).data;
    const ty = cg.typeOfIndex(inst);

    const union_obj = zcu.typeToUnion(ty).?;
    const field_ty: Type = .fromInterned(union_obj.field_types.get(ip)[extra.field_index]);
    const payload = if (field_ty.hasRuntimeBitsIgnoreComptime(zcu))
        try cg.resolve(extra.init)
    else
        null;
    return try cg.unionInit(ty, extra.field_index, payload);
}

fn airStructFieldVal(cg: *CodeGen, inst: Air.Inst.Index) !?Id {
    const pt = cg.pt;
    const zcu = cg.module.zcu;
    const ty_pl = cg.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const struct_field = cg.air.extraData(Air.StructField, ty_pl.payload).data;

    const object_ty = cg.typeOf(struct_field.struct_operand);
    const object_id = try cg.resolve(struct_field.struct_operand);
    const field_index = struct_field.field_index;
    const field_ty = object_ty.fieldType(field_index, zcu);

    if (!field_ty.hasRuntimeBitsIgnoreComptime(zcu)) return null;

    switch (object_ty.zigTypeTag(zcu)) {
        .@"struct" => switch (object_ty.containerLayout(zcu)) {
            .@"packed" => {
                const struct_ty = zcu.typeToPackedStruct(object_ty).?;
                const struct_backing_int_bits = cg.module.backingIntBits(@intCast(object_ty.bitSize(zcu))).@"0";
                const bit_offset = zcu.structPackedFieldBitOffset(struct_ty, field_index);
                // We use the same int type the packed struct is backed by, because even though it would
                // be valid SPIR-V to use an smaller type like u16, some implementations like PoCL will complain.
                const bit_offset_id = try cg.constInt(object_ty, bit_offset);
                const signedness = if (field_ty.isInt(zcu)) field_ty.intInfo(zcu).signedness else .unsigned;
                const field_bit_size: u16 = @intCast(field_ty.bitSize(zcu));
                const field_int_ty = try pt.intType(signedness, field_bit_size);
                const shift_lhs: Temporary = .{ .ty = object_ty, .value = .{ .singleton = object_id } };
                const shift = try cg.buildBinary(.OpShiftRightLogical, shift_lhs, .{ .ty = object_ty, .value = .{ .singleton = bit_offset_id } });
                const mask_id = try cg.constInt(object_ty, (@as(u64, 1) << @as(u6, @intCast(field_bit_size))) - 1);
                const masked = try cg.buildBinary(.OpBitwiseAnd, shift, .{ .ty = object_ty, .value = .{ .singleton = mask_id } });
                const result_id = blk: {
                    if (cg.module.backingIntBits(field_bit_size).@"0" == struct_backing_int_bits)
                        break :blk try cg.bitCast(field_int_ty, object_ty, try masked.materialize(cg));
                    const trunc = try cg.buildConvert(field_int_ty, masked);
                    break :blk try trunc.materialize(cg);
                };
                if (field_ty.ip_index == .bool_type) return try cg.convertToDirect(.bool, result_id);
                if (field_ty.isInt(zcu)) return result_id;
                return try cg.bitCast(field_ty, field_int_ty, result_id);
            },
            else => return try cg.extractField(field_ty, object_id, field_index),
        },
        .@"union" => switch (object_ty.containerLayout(zcu)) {
            .@"packed" => {
                const backing_int_ty = try pt.intType(.unsigned, @intCast(object_ty.bitSize(zcu)));
                const signedness = if (field_ty.isInt(zcu)) field_ty.intInfo(zcu).signedness else .unsigned;
                const field_bit_size: u16 = @intCast(field_ty.bitSize(zcu));
                const int_ty = try pt.intType(signedness, field_bit_size);
                const mask_id = try cg.constInt(backing_int_ty, (@as(u64, 1) << @as(u6, @intCast(field_bit_size))) - 1);
                const masked = try cg.buildBinary(
                    .OpBitwiseAnd,
                    .{ .ty = backing_int_ty, .value = .{ .singleton = object_id } },
                    .{ .ty = backing_int_ty, .value = .{ .singleton = mask_id } },
                );
                const result_id = blk: {
                    if (cg.module.backingIntBits(field_bit_size).@"0" == cg.module.backingIntBits(@intCast(backing_int_ty.bitSize(zcu))).@"0")
                        break :blk try cg.bitCast(int_ty, backing_int_ty, try masked.materialize(cg));
                    const trunc = try cg.buildConvert(int_ty, masked);
                    break :blk try trunc.materialize(cg);
                };
                if (field_ty.ip_index == .bool_type) return try cg.convertToDirect(.bool, result_id);
                if (field_ty.isInt(zcu)) return result_id;
                return try cg.bitCast(field_ty, int_ty, result_id);
            },
            else => {
                // Store, ptr-elem-ptr, pointer-cast, load
                const layout = cg.unionLayout(object_ty);
                assert(layout.has_payload);

                const object_ty_id = try cg.resolveType(object_ty, .indirect);
                const tmp_id = try cg.alloc(object_ty_id, null);
                try cg.store(object_ty, tmp_id, object_id, .{});

                const layout_payload_ty_id = try cg.resolveType(layout.payload_ty, .indirect);
                const pl_ptr_ty_id = try cg.module.ptrType(layout_payload_ty_id, .function);
                const pl_ptr_id = try cg.accessChain(pl_ptr_ty_id, tmp_id, &.{layout.payload_index});

                const field_ty_id = try cg.resolveType(field_ty, .indirect);
                const active_pl_ptr_ty_id = try cg.module.ptrType(field_ty_id, .function);
                const active_pl_ptr_id = cg.module.allocId();
                try cg.body.emit(cg.module.gpa, .OpBitcast, .{
                    .id_result_type = active_pl_ptr_ty_id,
                    .id_result = active_pl_ptr_id,
                    .operand = pl_ptr_id,
                });
                return try cg.load(field_ty, active_pl_ptr_id, .{});
            },
        },
        else => unreachable,
    }
}

fn airFieldParentPtr(cg: *CodeGen, inst: Air.Inst.Index) !?Id {
    const zcu = cg.module.zcu;
    const target = zcu.getTarget();
    const ty_pl = cg.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const extra = cg.air.extraData(Air.FieldParentPtr, ty_pl.payload).data;

    const parent_ptr_ty = ty_pl.ty.toType();
    const parent_ty = parent_ptr_ty.childType(zcu);
    const result_ty_id = try cg.resolveType(parent_ptr_ty, .indirect);

    const field_ptr = try cg.resolve(extra.field_ptr);
    const field_ptr_ty = cg.typeOf(extra.field_ptr);
    const field_ptr_int = try cg.intFromPtr(field_ptr);
    const field_offset = parent_ty.structFieldOffset(extra.field_index, zcu);

    const base_ptr_int = base_ptr_int: {
        if (field_offset == 0) break :base_ptr_int field_ptr_int;

        const field_offset_id = try cg.constInt(.usize, field_offset);
        const field_ptr_tmp: Temporary = .init(.usize, field_ptr_int);
        const field_offset_tmp: Temporary = .init(.usize, field_offset_id);
        const result = try cg.buildBinary(.OpISub, field_ptr_tmp, field_offset_tmp);
        break :base_ptr_int try result.materialize(cg);
    };

    if (target.os.tag != .opencl) {
        if (field_ptr_ty.ptrAddressSpace(zcu) != .physical_storage_buffer) {
            return cg.fail(
                "cannot cast integer to pointer with address space '{s}'",
                .{@tagName(field_ptr_ty.ptrAddressSpace(zcu))},
            );
        }
    }

    const base_ptr = cg.module.allocId();
    try cg.body.emit(cg.module.gpa, .OpConvertUToPtr, .{
        .id_result_type = result_ty_id,
        .id_result = base_ptr,
        .integer_value = base_ptr_int,
    });

    return base_ptr;
}

fn structFieldPtr(
    cg: *CodeGen,
    result_ptr_ty: Type,
    object_ptr_ty: Type,
    object_ptr: Id,
    field_index: u32,
) !Id {
    const result_ty_id = try cg.resolveType(result_ptr_ty, .direct);

    const zcu = cg.module.zcu;
    const object_ty = object_ptr_ty.childType(zcu);
    switch (object_ty.zigTypeTag(zcu)) {
        .pointer => {
            assert(object_ty.isSlice(zcu));
            return cg.accessChain(result_ty_id, object_ptr, &.{field_index});
        },
        .@"struct" => switch (object_ty.containerLayout(zcu)) {
            .@"packed" => return cg.todo("implement field access for packed structs", .{}),
            else => {
                return try cg.accessChain(result_ty_id, object_ptr, &.{field_index});
            },
        },
        .@"union" => {
            const layout = cg.unionLayout(object_ty);
            if (!layout.has_payload) {
                // Asked to get a pointer to a zero-sized field. Just lower this
                // to undefined, there is no reason to make it be a valid pointer.
                return try cg.module.constUndef(result_ty_id);
            }

            const storage_class = cg.module.storageClass(object_ptr_ty.ptrAddressSpace(zcu));
            const layout_payload_ty_id = try cg.resolveType(layout.payload_ty, .indirect);
            const pl_ptr_ty_id = try cg.module.ptrType(layout_payload_ty_id, storage_class);
            const pl_ptr_id = blk: {
                if (object_ty.containerLayout(zcu) == .@"packed") break :blk object_ptr;
                break :blk try cg.accessChain(pl_ptr_ty_id, object_ptr, &.{layout.payload_index});
            };

            const active_pl_ptr_id = cg.module.allocId();
            try cg.body.emit(cg.module.gpa, .OpBitcast, .{
                .id_result_type = result_ty_id,
                .id_result = active_pl_ptr_id,
                .operand = pl_ptr_id,
            });
            return active_pl_ptr_id;
        },
        else => unreachable,
    }
}

fn airStructFieldPtrIndex(cg: *CodeGen, inst: Air.Inst.Index, field_index: u32) !?Id {
    const ty_op = cg.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const struct_ptr = try cg.resolve(ty_op.operand);
    const struct_ptr_ty = cg.typeOf(ty_op.operand);
    const result_ptr_ty = cg.typeOfIndex(inst);
    return try cg.structFieldPtr(result_ptr_ty, struct_ptr_ty, struct_ptr, field_index);
}

fn alloc(cg: *CodeGen, ty_id: Id, initializer: ?Id) !Id {
    const ptr_ty_id = try cg.module.ptrType(ty_id, .function);
    const result_id = cg.module.allocId();
    try cg.prologue.emit(cg.module.gpa, .OpVariable, .{
        .id_result_type = ptr_ty_id,
        .id_result = result_id,
        .storage_class = .function,
        .initializer = initializer,
    });
    return result_id;
}

fn airAlloc(cg: *CodeGen, inst: Air.Inst.Index) !?Id {
    const zcu = cg.module.zcu;
    const target = zcu.getTarget();
    const ptr_ty = cg.typeOfIndex(inst);
    const child_ty = ptr_ty.childType(zcu);
    const child_ty_id = try cg.resolveType(child_ty, .indirect);
    const ptr_align = ptr_ty.ptrAlignment(zcu);
    const result_id = try cg.alloc(child_ty_id, null);
    if (ptr_align != child_ty.abiAlignment(zcu)) {
        if (target.os.tag != .opencl) return cg.fail("cannot apply alignment to variables", .{});
        try cg.module.decorate(result_id, .{
            .alignment = .{ .alignment = @intCast(ptr_align.toByteUnits().?) },
        });
    }
    return result_id;
}

fn airArg(cg: *CodeGen) Id {
    defer cg.next_arg_index += 1;
    return cg.args.items[cg.next_arg_index];
}

/// Given a slice of incoming block connections, returns the block-id of the next
/// block to jump to. This function emits instructions, so it should be emitted
/// inside the merge block of the block.
/// This function should only be called with structured control flow generation.
fn structuredNextBlock(cg: *CodeGen, incoming: []const ControlFlow.Structured.Block.Incoming) !Id {
    assert(cg.control_flow == .structured);

    const result_id = cg.module.allocId();
    const block_id_ty_id = try cg.resolveType(.u32, .direct);
    try cg.body.emitRaw(cg.module.gpa, .OpPhi, @intCast(2 + incoming.len * 2)); // result type + result + variable/parent...
    cg.body.writeOperand(Id, block_id_ty_id);
    cg.body.writeOperand(Id, result_id);

    for (incoming) |incoming_block| {
        cg.body.writeOperand(spec.PairIdRefIdRef, .{ incoming_block.next_block, incoming_block.src_label });
    }

    return result_id;
}

/// Jumps to the block with the target block-id. This function must only be called when
/// terminating a body, there should be no instructions after it.
/// This function should only be called with structured control flow generation.
fn structuredBreak(cg: *CodeGen, target_block: Id) !void {
    assert(cg.control_flow == .structured);

    const gpa = cg.module.gpa;
    const sblock = cg.control_flow.structured.block_stack.getLast();
    const merge_block = switch (sblock.*) {
        .selection => |*merge| blk: {
            const merge_label = cg.module.allocId();
            try merge.merge_stack.append(gpa, .{
                .incoming = .{
                    .src_label = cg.block_label,
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

    try cg.body.emit(gpa, .OpBranch, .{ .target_label = merge_block });
}

/// Generate a body in a way that exits the body using only structured constructs.
/// Returns the block-id of the next block to jump to. After this function, a jump
/// should still be emitted to the block that should follow this structured body.
/// This function should only be called with structured control flow generation.
fn genStructuredBody(
    cg: *CodeGen,
    /// This parameter defines the method that this structured body is exited with.
    block_merge_type: union(enum) {
        /// Using selection; early exits from this body are surrounded with
        /// if() statements.
        selection,
        /// Using loops; loops can be early exited by jumping to the merge block at
        /// any time.
        loop: struct {
            merge_label: Id,
            continue_label: Id,
        },
    },
    body: []const Air.Inst.Index,
) !Id {
    assert(cg.control_flow == .structured);

    const gpa = cg.module.gpa;

    var sblock: ControlFlow.Structured.Block = switch (block_merge_type) {
        .loop => |merge| .{ .loop = .{
            .merge_block = merge.merge_label,
        } },
        .selection => .{ .selection = .{} },
    };
    defer sblock.deinit(gpa);

    {
        try cg.control_flow.structured.block_stack.append(gpa, &sblock);
        defer _ = cg.control_flow.structured.block_stack.pop();

        try cg.genBody(body);
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
                try cg.beginSpvBlock(cg.module.allocId());
                const block_id_ty_id = try cg.resolveType(.u32, .direct);
                return try cg.module.constUndef(block_id_ty_id);
            }

            // The top-most merge actually only has a single source, the
            // final jump of the block, or the merge block of a sub-block, cond_br,
            // or loop. Therefore we just need to generate a block with a jump to the
            // next merge block.
            try cg.beginSpvBlock(merge_stack[merge_stack.len - 1].merge_block);

            // Now generate a merge ladder for the remaining merges in the stack.
            var incoming: ControlFlow.Structured.Block.Incoming = .{
                .src_label = cg.block_label,
                .next_block = merge_stack[merge_stack.len - 1].incoming.next_block,
            };
            var i = merge_stack.len - 1;
            while (i > 0) {
                i -= 1;
                const step = merge_stack[i];

                try cg.body.emit(gpa, .OpBranch, .{ .target_label = step.merge_block });
                try cg.beginSpvBlock(step.merge_block);
                const next_block = try cg.structuredNextBlock(&.{ incoming, step.incoming });
                incoming = .{
                    .src_label = step.merge_block,
                    .next_block = next_block,
                };
            }

            return incoming.next_block;
        },
        .loop => |merge| {
            // Close the loop by jumping to the continue label

            try cg.body.emit(gpa, .OpBranch, .{ .target_label = block_merge_type.loop.continue_label });
            // For blocks we must simple merge all the incoming blocks to get the next block.
            try cg.beginSpvBlock(merge.merge_block);
            return try cg.structuredNextBlock(merge.merges.items);
        },
    }
}

fn airBlock(cg: *CodeGen, inst: Air.Inst.Index) !?Id {
    const inst_datas = cg.air.instructions.items(.data);
    const extra = cg.air.extraData(Air.Block, inst_datas[@intFromEnum(inst)].ty_pl.payload);
    return cg.lowerBlock(inst, @ptrCast(cg.air.extra.items[extra.end..][0..extra.data.body_len]));
}

fn lowerBlock(cg: *CodeGen, inst: Air.Inst.Index, body: []const Air.Inst.Index) !?Id {
    // In AIR, a block doesn't really define an entry point like a block, but
    // more like a scope that breaks can jump out of and "return" a value from.
    // This cannot be directly modelled in SPIR-V, so in a block instruction,
    // we're going to split up the current block by first generating the code
    // of the block, then a label, and then generate the rest of the current
    // ir.Block in a different SPIR-V block.

    const gpa = cg.module.gpa;
    const zcu = cg.module.zcu;
    const ty = cg.typeOfIndex(inst);
    const have_block_result = ty.isFnOrHasRuntimeBitsIgnoreComptime(zcu);

    const cf = switch (cg.control_flow) {
        .structured => |*cf| cf,
        .unstructured => |*cf| {
            var block: ControlFlow.Unstructured.Block = .{};
            defer block.incoming_blocks.deinit(gpa);

            // 4 chosen as arbitrary initial capacity.
            try block.incoming_blocks.ensureUnusedCapacity(gpa, 4);

            try cf.blocks.putNoClobber(gpa, inst, &block);
            defer assert(cf.blocks.remove(inst));

            try cg.genBody(body);

            // Only begin a new block if there were actually any breaks towards it.
            if (block.label) |label| {
                try cg.beginSpvBlock(label);
            }

            if (!have_block_result)
                return null;

            assert(block.label != null);
            const result_id = cg.module.allocId();
            const result_type_id = try cg.resolveType(ty, .direct);

            try cg.body.emitRaw(
                gpa,
                .OpPhi,
                // result type + result + variable/parent...
                2 + @as(u16, @intCast(block.incoming_blocks.items.len * 2)),
            );
            cg.body.writeOperand(Id, result_type_id);
            cg.body.writeOperand(Id, result_id);

            for (block.incoming_blocks.items) |incoming| {
                cg.body.writeOperand(
                    spec.PairIdRefIdRef,
                    .{ incoming.break_value_id, incoming.src_label },
                );
            }

            return result_id;
        },
    };

    const maybe_block_result_var_id = if (have_block_result) blk: {
        const ty_id = try cg.resolveType(ty, .indirect);
        const block_result_var_id = try cg.alloc(ty_id, null);
        try cf.block_results.putNoClobber(gpa, inst, block_result_var_id);
        break :blk block_result_var_id;
    } else null;
    defer if (have_block_result) assert(cf.block_results.remove(inst));

    const next_block = try cg.genStructuredBody(.selection, body);

    // When encountering a block instruction, we are always at least in the function's scope,
    // so there always has to be another entry.
    assert(cf.block_stack.items.len > 0);

    // Check if the target of the branch was this current block.
    const this_block = try cg.constInt(.u32, @intFromEnum(inst));
    const jump_to_this_block_id = cg.module.allocId();
    const bool_ty_id = try cg.resolveType(.bool, .direct);
    try cg.body.emit(gpa, .OpIEqual, .{
        .id_result_type = bool_ty_id,
        .id_result = jump_to_this_block_id,
        .operand_1 = next_block,
        .operand_2 = this_block,
    });

    const sblock = cf.block_stack.getLast();

    if (ty.isNoReturn(zcu)) {
        // If this block is noreturn, this instruction is the last of a block,
        // and we must simply jump to the block's merge unconditionally.
        try cg.structuredBreak(next_block);
    } else {
        switch (sblock.*) {
            .selection => |*merge| {
                // To jump out of a selection block, push a new entry onto its merge stack and
                // generate a conditional branch to there and to the instructions following this block.
                const merge_label = cg.module.allocId();
                const then_label = cg.module.allocId();
                try cg.body.emit(gpa, .OpSelectionMerge, .{
                    .merge_block = merge_label,
                    .selection_control = .{},
                });
                try cg.body.emit(gpa, .OpBranchConditional, .{
                    .condition = jump_to_this_block_id,
                    .true_label = then_label,
                    .false_label = merge_label,
                });
                try merge.merge_stack.append(gpa, .{
                    .incoming = .{
                        .src_label = cg.block_label,
                        .next_block = next_block,
                    },
                    .merge_block = merge_label,
                });

                try cg.beginSpvBlock(then_label);
            },
            .loop => |*merge| {
                // To jump out of a loop block, generate a conditional that exits the block
                // to the loop merge if the target ID is not the one of this block.
                const continue_label = cg.module.allocId();
                try cg.body.emit(gpa, .OpBranchConditional, .{
                    .condition = jump_to_this_block_id,
                    .true_label = continue_label,
                    .false_label = merge.merge_block,
                });
                try merge.merges.append(gpa, .{
                    .src_label = cg.block_label,
                    .next_block = next_block,
                });
                try cg.beginSpvBlock(continue_label);
            },
        }
    }

    if (maybe_block_result_var_id) |block_result_var_id| {
        return try cg.load(ty, block_result_var_id, .{});
    }

    return null;
}

fn airBr(cg: *CodeGen, inst: Air.Inst.Index) !void {
    const gpa = cg.module.gpa;
    const zcu = cg.module.zcu;
    const br = cg.air.instructions.items(.data)[@intFromEnum(inst)].br;
    const operand_ty = cg.typeOf(br.operand);

    switch (cg.control_flow) {
        .structured => |*cf| {
            if (operand_ty.isFnOrHasRuntimeBitsIgnoreComptime(zcu)) {
                const operand_id = try cg.resolve(br.operand);
                const block_result_var_id = cf.block_results.get(br.block_inst).?;
                try cg.store(operand_ty, block_result_var_id, operand_id, .{});
            }

            const next_block = try cg.constInt(.u32, @intFromEnum(br.block_inst));
            try cg.structuredBreak(next_block);
        },
        .unstructured => |cf| {
            const block = cf.blocks.get(br.block_inst).?;
            if (operand_ty.isFnOrHasRuntimeBitsIgnoreComptime(zcu)) {
                const operand_id = try cg.resolve(br.operand);
                // block_label should not be undefined here, lest there
                // is a br or br_void in the function's body.
                try block.incoming_blocks.append(gpa, .{
                    .src_label = cg.block_label,
                    .break_value_id = operand_id,
                });
            }

            if (block.label == null) {
                block.label = cg.module.allocId();
            }

            try cg.body.emit(gpa, .OpBranch, .{ .target_label = block.label.? });
        },
    }
}

fn airCondBr(cg: *CodeGen, inst: Air.Inst.Index) !void {
    const gpa = cg.module.gpa;
    const pl_op = cg.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
    const cond_br = cg.air.extraData(Air.CondBr, pl_op.payload);
    const then_body: []const Air.Inst.Index = @ptrCast(cg.air.extra.items[cond_br.end..][0..cond_br.data.then_body_len]);
    const else_body: []const Air.Inst.Index = @ptrCast(cg.air.extra.items[cond_br.end + then_body.len ..][0..cond_br.data.else_body_len]);
    const condition_id = try cg.resolve(pl_op.operand);

    const then_label = cg.module.allocId();
    const else_label = cg.module.allocId();

    switch (cg.control_flow) {
        .structured => {
            const merge_label = cg.module.allocId();

            try cg.body.emit(gpa, .OpSelectionMerge, .{
                .merge_block = merge_label,
                .selection_control = .{},
            });
            try cg.body.emit(gpa, .OpBranchConditional, .{
                .condition = condition_id,
                .true_label = then_label,
                .false_label = else_label,
            });

            try cg.beginSpvBlock(then_label);
            const then_next = try cg.genStructuredBody(.selection, then_body);
            const then_incoming: ControlFlow.Structured.Block.Incoming = .{
                .src_label = cg.block_label,
                .next_block = then_next,
            };

            try cg.body.emit(gpa, .OpBranch, .{ .target_label = merge_label });

            try cg.beginSpvBlock(else_label);
            const else_next = try cg.genStructuredBody(.selection, else_body);
            const else_incoming: ControlFlow.Structured.Block.Incoming = .{
                .src_label = cg.block_label,
                .next_block = else_next,
            };

            try cg.body.emit(gpa, .OpBranch, .{ .target_label = merge_label });

            try cg.beginSpvBlock(merge_label);
            const next_block = try cg.structuredNextBlock(&.{ then_incoming, else_incoming });

            try cg.structuredBreak(next_block);
        },
        .unstructured => {
            try cg.body.emit(gpa, .OpBranchConditional, .{
                .condition = condition_id,
                .true_label = then_label,
                .false_label = else_label,
            });

            try cg.beginSpvBlock(then_label);
            try cg.genBody(then_body);
            try cg.beginSpvBlock(else_label);
            try cg.genBody(else_body);
        },
    }
}

fn airLoop(cg: *CodeGen, inst: Air.Inst.Index) !void {
    const gpa = cg.module.gpa;
    const ty_pl = cg.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const loop = cg.air.extraData(Air.Block, ty_pl.payload);
    const body: []const Air.Inst.Index = @ptrCast(cg.air.extra.items[loop.end..][0..loop.data.body_len]);

    const body_label = cg.module.allocId();

    switch (cg.control_flow) {
        .structured => {
            const header_label = cg.module.allocId();
            const merge_label = cg.module.allocId();
            const continue_label = cg.module.allocId();

            // The back-edge must point to the loop header, so generate a separate block for the
            // loop header so that we don't accidentally include some instructions from there
            // in the loop.

            try cg.body.emit(gpa, .OpBranch, .{ .target_label = header_label });
            try cg.beginSpvBlock(header_label);

            // Emit loop header and jump to loop body
            try cg.body.emit(gpa, .OpLoopMerge, .{
                .merge_block = merge_label,
                .continue_target = continue_label,
                .loop_control = .{},
            });

            try cg.body.emit(gpa, .OpBranch, .{ .target_label = body_label });

            try cg.beginSpvBlock(body_label);

            const next_block = try cg.genStructuredBody(.{ .loop = .{
                .merge_label = merge_label,
                .continue_label = continue_label,
            } }, body);
            try cg.structuredBreak(next_block);

            try cg.beginSpvBlock(continue_label);

            try cg.body.emit(gpa, .OpBranch, .{ .target_label = header_label });
        },
        .unstructured => {
            try cg.body.emit(gpa, .OpBranch, .{ .target_label = body_label });
            try cg.beginSpvBlock(body_label);
            try cg.genBody(body);

            try cg.body.emit(gpa, .OpBranch, .{ .target_label = body_label });
        },
    }
}

fn airLoad(cg: *CodeGen, inst: Air.Inst.Index) !?Id {
    const zcu = cg.module.zcu;
    const ty_op = cg.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const ptr_ty = cg.typeOf(ty_op.operand);
    const elem_ty = cg.typeOfIndex(inst);
    const operand = try cg.resolve(ty_op.operand);
    if (!ptr_ty.isVolatilePtr(zcu) and cg.liveness.isUnused(inst)) return null;

    return try cg.load(elem_ty, operand, .{ .is_volatile = ptr_ty.isVolatilePtr(zcu) });
}

fn airStore(cg: *CodeGen, inst: Air.Inst.Index) !void {
    const zcu = cg.module.zcu;
    const bin_op = cg.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const ptr_ty = cg.typeOf(bin_op.lhs);
    const elem_ty = ptr_ty.childType(zcu);
    const ptr = try cg.resolve(bin_op.lhs);
    const value = try cg.resolve(bin_op.rhs);

    try cg.store(elem_ty, ptr, value, .{ .is_volatile = ptr_ty.isVolatilePtr(zcu) });
}

fn airRet(cg: *CodeGen, inst: Air.Inst.Index) !void {
    const gpa = cg.module.gpa;
    const zcu = cg.module.zcu;
    const operand = cg.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
    const ret_ty = cg.typeOf(operand);
    if (!ret_ty.hasRuntimeBitsIgnoreComptime(zcu)) {
        const fn_info = zcu.typeToFunc(zcu.navValue(cg.owner_nav).typeOf(zcu)).?;
        if (Type.fromInterned(fn_info.return_type).isError(zcu)) {
            // Functions with an empty error set are emitted with an error code
            // return type and return zero so they can be function pointers coerced
            // to functions that return anyerror.
            const no_err_id = try cg.constInt(.anyerror, 0);
            return try cg.body.emit(gpa, .OpReturnValue, .{ .value = no_err_id });
        } else {
            return try cg.body.emit(gpa, .OpReturn, {});
        }
    }

    const operand_id = try cg.resolve(operand);
    try cg.body.emit(gpa, .OpReturnValue, .{ .value = operand_id });
}

fn airRetLoad(cg: *CodeGen, inst: Air.Inst.Index) !void {
    const gpa = cg.module.gpa;
    const zcu = cg.module.zcu;
    const un_op = cg.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
    const ptr_ty = cg.typeOf(un_op);
    const ret_ty = ptr_ty.childType(zcu);

    if (!ret_ty.hasRuntimeBitsIgnoreComptime(zcu)) {
        const fn_info = zcu.typeToFunc(zcu.navValue(cg.owner_nav).typeOf(zcu)).?;
        if (Type.fromInterned(fn_info.return_type).isError(zcu)) {
            // Functions with an empty error set are emitted with an error code
            // return type and return zero so they can be function pointers coerced
            // to functions that return anyerror.
            const no_err_id = try cg.constInt(.anyerror, 0);
            return try cg.body.emit(gpa, .OpReturnValue, .{ .value = no_err_id });
        } else {
            return try cg.body.emit(gpa, .OpReturn, {});
        }
    }

    const ptr = try cg.resolve(un_op);
    const value = try cg.load(ret_ty, ptr, .{ .is_volatile = ptr_ty.isVolatilePtr(zcu) });
    try cg.body.emit(gpa, .OpReturnValue, .{
        .value = value,
    });
}

fn airTry(cg: *CodeGen, inst: Air.Inst.Index) !?Id {
    const gpa = cg.module.gpa;
    const zcu = cg.module.zcu;
    const pl_op = cg.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
    const err_union_id = try cg.resolve(pl_op.operand);
    const extra = cg.air.extraData(Air.Try, pl_op.payload);
    const body: []const Air.Inst.Index = @ptrCast(cg.air.extra.items[extra.end..][0..extra.data.body_len]);

    const err_union_ty = cg.typeOf(pl_op.operand);
    const payload_ty = cg.typeOfIndex(inst);

    const bool_ty_id = try cg.resolveType(.bool, .direct);

    const eu_layout = cg.errorUnionLayout(payload_ty);

    if (!err_union_ty.errorUnionSet(zcu).errorSetIsEmpty(zcu)) {
        const err_id = if (eu_layout.payload_has_bits)
            try cg.extractField(.anyerror, err_union_id, eu_layout.errorFieldIndex())
        else
            err_union_id;

        const zero_id = try cg.constInt(.anyerror, 0);
        const is_err_id = cg.module.allocId();
        try cg.body.emit(gpa, .OpINotEqual, .{
            .id_result_type = bool_ty_id,
            .id_result = is_err_id,
            .operand_1 = err_id,
            .operand_2 = zero_id,
        });

        // When there is an error, we must evaluate `body`. Otherwise we must continue
        // with the current body.
        // Just generate a new block here, then generate a new block inline for the remainder of the body.

        const err_block = cg.module.allocId();
        const ok_block = cg.module.allocId();

        switch (cg.control_flow) {
            .structured => {
                // According to AIR documentation, this block is guaranteed
                // to not break and end in a return instruction. Thus,
                // for structured control flow, we can just naively use
                // the ok block as the merge block here.
                try cg.body.emit(gpa, .OpSelectionMerge, .{
                    .merge_block = ok_block,
                    .selection_control = .{},
                });
            },
            .unstructured => {},
        }

        try cg.body.emit(gpa, .OpBranchConditional, .{
            .condition = is_err_id,
            .true_label = err_block,
            .false_label = ok_block,
        });

        try cg.beginSpvBlock(err_block);
        try cg.genBody(body);

        try cg.beginSpvBlock(ok_block);
    }

    if (!eu_layout.payload_has_bits) {
        return null;
    }

    // Now just extract the payload, if required.
    return try cg.extractField(payload_ty, err_union_id, eu_layout.payloadFieldIndex());
}

fn airErrUnionErr(cg: *CodeGen, inst: Air.Inst.Index) !?Id {
    const zcu = cg.module.zcu;
    const ty_op = cg.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const operand_id = try cg.resolve(ty_op.operand);
    const err_union_ty = cg.typeOf(ty_op.operand);
    const err_ty_id = try cg.resolveType(.anyerror, .direct);

    if (err_union_ty.errorUnionSet(zcu).errorSetIsEmpty(zcu)) {
        // No error possible, so just return undefined.
        return try cg.module.constUndef(err_ty_id);
    }

    const payload_ty = err_union_ty.errorUnionPayload(zcu);
    const eu_layout = cg.errorUnionLayout(payload_ty);

    if (!eu_layout.payload_has_bits) {
        // If no payload, error union is represented by error set.
        return operand_id;
    }

    return try cg.extractField(.anyerror, operand_id, eu_layout.errorFieldIndex());
}

fn airErrUnionPayload(cg: *CodeGen, inst: Air.Inst.Index) !?Id {
    const ty_op = cg.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const operand_id = try cg.resolve(ty_op.operand);
    const payload_ty = cg.typeOfIndex(inst);
    const eu_layout = cg.errorUnionLayout(payload_ty);

    if (!eu_layout.payload_has_bits) {
        return null; // No error possible.
    }

    return try cg.extractField(payload_ty, operand_id, eu_layout.payloadFieldIndex());
}

fn airWrapErrUnionErr(cg: *CodeGen, inst: Air.Inst.Index) !?Id {
    const zcu = cg.module.zcu;
    const ty_op = cg.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const err_union_ty = cg.typeOfIndex(inst);
    const payload_ty = err_union_ty.errorUnionPayload(zcu);
    const operand_id = try cg.resolve(ty_op.operand);
    const eu_layout = cg.errorUnionLayout(payload_ty);

    if (!eu_layout.payload_has_bits) {
        return operand_id;
    }

    const payload_ty_id = try cg.resolveType(payload_ty, .indirect);

    var members: [2]Id = undefined;
    members[eu_layout.errorFieldIndex()] = operand_id;
    members[eu_layout.payloadFieldIndex()] = try cg.module.constUndef(payload_ty_id);

    var types: [2]Type = undefined;
    types[eu_layout.errorFieldIndex()] = .anyerror;
    types[eu_layout.payloadFieldIndex()] = payload_ty;

    const err_union_ty_id = try cg.resolveType(err_union_ty, .direct);
    return try cg.constructComposite(err_union_ty_id, &members);
}

fn airWrapErrUnionPayload(cg: *CodeGen, inst: Air.Inst.Index) !?Id {
    const ty_op = cg.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const err_union_ty = cg.typeOfIndex(inst);
    const operand_id = try cg.resolve(ty_op.operand);
    const payload_ty = cg.typeOf(ty_op.operand);
    const eu_layout = cg.errorUnionLayout(payload_ty);

    if (!eu_layout.payload_has_bits) {
        return try cg.constInt(.anyerror, 0);
    }

    var members: [2]Id = undefined;
    members[eu_layout.errorFieldIndex()] = try cg.constInt(.anyerror, 0);
    members[eu_layout.payloadFieldIndex()] = try cg.convertToIndirect(payload_ty, operand_id);

    var types: [2]Type = undefined;
    types[eu_layout.errorFieldIndex()] = .anyerror;
    types[eu_layout.payloadFieldIndex()] = payload_ty;

    const err_union_ty_id = try cg.resolveType(err_union_ty, .direct);
    return try cg.constructComposite(err_union_ty_id, &members);
}

fn airIsNull(cg: *CodeGen, inst: Air.Inst.Index, is_pointer: bool, pred: enum { is_null, is_non_null }) !?Id {
    const zcu = cg.module.zcu;
    const un_op = cg.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
    const operand_id = try cg.resolve(un_op);
    const operand_ty = cg.typeOf(un_op);
    const optional_ty = if (is_pointer) operand_ty.childType(zcu) else operand_ty;
    const payload_ty = optional_ty.optionalChild(zcu);

    const bool_ty_id = try cg.resolveType(.bool, .direct);

    if (optional_ty.optionalReprIsPayload(zcu)) {
        // Pointer payload represents nullability: pointer or slice.
        const loaded_id = if (is_pointer)
            try cg.load(optional_ty, operand_id, .{})
        else
            operand_id;

        const ptr_ty = if (payload_ty.isSlice(zcu))
            payload_ty.slicePtrFieldType(zcu)
        else
            payload_ty;

        const ptr_id = if (payload_ty.isSlice(zcu))
            try cg.extractField(ptr_ty, loaded_id, 0)
        else
            loaded_id;

        const ptr_ty_id = try cg.resolveType(ptr_ty, .direct);
        const null_id = try cg.module.constNull(ptr_ty_id);
        const null_tmp: Temporary = .init(ptr_ty, null_id);
        const ptr: Temporary = .init(ptr_ty, ptr_id);

        const op: std.math.CompareOperator = switch (pred) {
            .is_null => .eq,
            .is_non_null => .neq,
        };
        const result = try cg.cmp(op, ptr, null_tmp);
        return try result.materialize(cg);
    }

    const is_non_null_id = blk: {
        if (is_pointer) {
            if (payload_ty.hasRuntimeBitsIgnoreComptime(zcu)) {
                const storage_class = cg.module.storageClass(operand_ty.ptrAddressSpace(zcu));
                const bool_indirect_ty_id = try cg.resolveType(.bool, .indirect);
                const bool_ptr_ty_id = try cg.module.ptrType(bool_indirect_ty_id, storage_class);
                const tag_ptr_id = try cg.accessChain(bool_ptr_ty_id, operand_id, &.{1});
                break :blk try cg.load(.bool, tag_ptr_id, .{});
            }

            break :blk try cg.load(.bool, operand_id, .{});
        }

        break :blk if (payload_ty.hasRuntimeBitsIgnoreComptime(zcu))
            try cg.extractField(.bool, operand_id, 1)
        else
            // Optional representation is bool indicating whether the optional is set
            // Optionals with no payload are represented as an (indirect) bool, so convert
            // it back to the direct bool here.
            try cg.convertToDirect(.bool, operand_id);
    };

    return switch (pred) {
        .is_null => blk: {
            // Invert condition
            const result_id = cg.module.allocId();
            try cg.body.emit(cg.module.gpa, .OpLogicalNot, .{
                .id_result_type = bool_ty_id,
                .id_result = result_id,
                .operand = is_non_null_id,
            });
            break :blk result_id;
        },
        .is_non_null => is_non_null_id,
    };
}

fn airIsErr(cg: *CodeGen, inst: Air.Inst.Index, pred: enum { is_err, is_non_err }) !?Id {
    const zcu = cg.module.zcu;
    const un_op = cg.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
    const operand_id = try cg.resolve(un_op);
    const err_union_ty = cg.typeOf(un_op);

    if (err_union_ty.errorUnionSet(zcu).errorSetIsEmpty(zcu)) {
        return try cg.constBool(pred == .is_non_err, .direct);
    }

    const payload_ty = err_union_ty.errorUnionPayload(zcu);
    const eu_layout = cg.errorUnionLayout(payload_ty);
    const bool_ty_id = try cg.resolveType(.bool, .direct);

    const error_id = if (!eu_layout.payload_has_bits)
        operand_id
    else
        try cg.extractField(.anyerror, operand_id, eu_layout.errorFieldIndex());

    const result_id = cg.module.allocId();
    switch (pred) {
        inline else => |pred_ct| try cg.body.emit(
            cg.module.gpa,
            switch (pred_ct) {
                .is_err => .OpINotEqual,
                .is_non_err => .OpIEqual,
            },
            .{
                .id_result_type = bool_ty_id,
                .id_result = result_id,
                .operand_1 = error_id,
                .operand_2 = try cg.constInt(.anyerror, 0),
            },
        ),
    }
    return result_id;
}

fn airUnwrapOptional(cg: *CodeGen, inst: Air.Inst.Index) !?Id {
    const zcu = cg.module.zcu;
    const ty_op = cg.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const operand_id = try cg.resolve(ty_op.operand);
    const optional_ty = cg.typeOf(ty_op.operand);
    const payload_ty = cg.typeOfIndex(inst);

    if (!payload_ty.hasRuntimeBitsIgnoreComptime(zcu)) return null;

    if (optional_ty.optionalReprIsPayload(zcu)) {
        return operand_id;
    }

    return try cg.extractField(payload_ty, operand_id, 0);
}

fn airUnwrapOptionalPtr(cg: *CodeGen, inst: Air.Inst.Index) !?Id {
    const zcu = cg.module.zcu;
    const ty_op = cg.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const operand_id = try cg.resolve(ty_op.operand);
    const operand_ty = cg.typeOf(ty_op.operand);
    const optional_ty = operand_ty.childType(zcu);
    const payload_ty = optional_ty.optionalChild(zcu);
    const result_ty = cg.typeOfIndex(inst);
    const result_ty_id = try cg.resolveType(result_ty, .direct);

    if (!payload_ty.hasRuntimeBitsIgnoreComptime(zcu)) {
        // There is no payload, but we still need to return a valid pointer.
        // We can just return anything here, so just return a pointer to the operand.
        return try cg.bitCast(result_ty, operand_ty, operand_id);
    }

    if (optional_ty.optionalReprIsPayload(zcu)) {
        // They are the same value.
        return try cg.bitCast(result_ty, operand_ty, operand_id);
    }

    return try cg.accessChain(result_ty_id, operand_id, &.{0});
}

fn airWrapOptional(cg: *CodeGen, inst: Air.Inst.Index) !?Id {
    const zcu = cg.module.zcu;
    const ty_op = cg.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const payload_ty = cg.typeOf(ty_op.operand);

    if (!payload_ty.hasRuntimeBitsIgnoreComptime(zcu)) {
        return try cg.constBool(true, .indirect);
    }

    const operand_id = try cg.resolve(ty_op.operand);

    const optional_ty = cg.typeOfIndex(inst);
    if (optional_ty.optionalReprIsPayload(zcu)) {
        return operand_id;
    }

    const payload_id = try cg.convertToIndirect(payload_ty, operand_id);
    const members = [_]Id{ payload_id, try cg.constBool(true, .indirect) };
    const optional_ty_id = try cg.resolveType(optional_ty, .direct);
    return try cg.constructComposite(optional_ty_id, &members);
}

fn airSwitchBr(cg: *CodeGen, inst: Air.Inst.Index) !void {
    const gpa = cg.module.gpa;
    const pt = cg.pt;
    const zcu = cg.module.zcu;
    const target = cg.module.zcu.getTarget();
    const switch_br = cg.air.unwrapSwitch(inst);
    const cond_ty = cg.typeOf(switch_br.operand);
    const cond = try cg.resolve(switch_br.operand);
    var cond_indirect = try cg.convertToIndirect(cond_ty, cond);

    const cond_words: u32 = switch (cond_ty.zigTypeTag(zcu)) {
        .bool, .error_set => 1,
        .int => blk: {
            const bits = cond_ty.intInfo(zcu).bits;
            const backing_bits, const big_int = cg.module.backingIntBits(bits);
            if (big_int) return cg.todo("implement composite int switch", .{});
            break :blk if (backing_bits <= 32) 1 else 2;
        },
        .@"enum" => blk: {
            const int_ty = cond_ty.intTagType(zcu);
            const int_info = int_ty.intInfo(zcu);
            const backing_bits, const big_int = cg.module.backingIntBits(int_info.bits);
            if (big_int) return cg.todo("implement composite int switch", .{});
            break :blk if (backing_bits <= 32) 1 else 2;
        },
        .pointer => blk: {
            cond_indirect = try cg.intFromPtr(cond_indirect);
            break :blk target.ptrBitWidth() / 32;
        },
        // TODO: Figure out which types apply here, and work around them as we can only do integers.
        else => return cg.todo("implement switch for type {s}", .{@tagName(cond_ty.zigTypeTag(zcu))}),
    };

    const num_cases = switch_br.cases_len;

    // Compute the total number of arms that we need.
    // Zig switches are grouped by condition, so we need to loop through all of them
    const num_conditions = blk: {
        var num_conditions: u32 = 0;
        var it = switch_br.iterateCases();
        while (it.next()) |case| {
            if (case.ranges.len > 0) return cg.todo("switch with ranges", .{});
            num_conditions += @intCast(case.items.len);
        }
        break :blk num_conditions;
    };

    // First, pre-allocate the labels for the cases.
    const case_labels = cg.module.allocIds(num_cases);
    // We always need the default case - if zig has none, we will generate unreachable there.
    const default = cg.module.allocId();

    const merge_label = switch (cg.control_flow) {
        .structured => cg.module.allocId(),
        .unstructured => null,
    };

    if (cg.control_flow == .structured) {
        try cg.body.emit(gpa, .OpSelectionMerge, .{
            .merge_block = merge_label.?,
            .selection_control = .{},
        });
    }

    // Emit the instruction before generating the blocks.
    try cg.body.emitRaw(gpa, .OpSwitch, 2 + (cond_words + 1) * num_conditions);
    cg.body.writeOperand(Id, cond_indirect);
    cg.body.writeOperand(Id, default);

    // Emit each of the cases
    {
        var it = switch_br.iterateCases();
        while (it.next()) |case| {
            // SPIR-V needs a literal here, which' width depends on the case condition.
            const label = case_labels.at(case.idx);

            for (case.items) |item| {
                const value = (try cg.air.value(item, pt)) orelse unreachable;
                const int_val: u64 = switch (cond_ty.zigTypeTag(zcu)) {
                    .bool, .int => if (cond_ty.isSignedInt(zcu)) @bitCast(value.toSignedInt(zcu)) else value.toUnsignedInt(zcu),
                    .@"enum" => blk: {
                        // TODO: figure out of cond_ty is correct (something with enum literals)
                        break :blk (try value.intFromEnum(cond_ty, pt)).toUnsignedInt(zcu); // TODO: composite integer constants
                    },
                    .error_set => value.getErrorInt(zcu),
                    .pointer => value.toUnsignedInt(zcu),
                    else => unreachable,
                };
                const int_lit: spec.LiteralContextDependentNumber = switch (cond_words) {
                    1 => .{ .uint32 = @intCast(int_val) },
                    2 => .{ .uint64 = int_val },
                    else => unreachable,
                };
                cg.body.writeOperand(spec.LiteralContextDependentNumber, int_lit);
                cg.body.writeOperand(Id, label);
            }
        }
    }

    var incoming_structured_blocks: std.ArrayListUnmanaged(ControlFlow.Structured.Block.Incoming) = .empty;
    defer incoming_structured_blocks.deinit(gpa);

    if (cg.control_flow == .structured) {
        try incoming_structured_blocks.ensureUnusedCapacity(gpa, num_cases + 1);
    }

    // Now, finally, we can start emitting each of the cases.
    var it = switch_br.iterateCases();
    while (it.next()) |case| {
        const label = case_labels.at(case.idx);

        try cg.beginSpvBlock(label);

        switch (cg.control_flow) {
            .structured => {
                const next_block = try cg.genStructuredBody(.selection, case.body);
                incoming_structured_blocks.appendAssumeCapacity(.{
                    .src_label = cg.block_label,
                    .next_block = next_block,
                });

                try cg.body.emit(gpa, .OpBranch, .{ .target_label = merge_label.? });
            },
            .unstructured => {
                try cg.genBody(case.body);
            },
        }
    }

    const else_body = it.elseBody();
    try cg.beginSpvBlock(default);
    if (else_body.len != 0) {
        switch (cg.control_flow) {
            .structured => {
                const next_block = try cg.genStructuredBody(.selection, else_body);
                incoming_structured_blocks.appendAssumeCapacity(.{
                    .src_label = cg.block_label,
                    .next_block = next_block,
                });

                try cg.body.emit(gpa, .OpBranch, .{ .target_label = merge_label.? });
            },
            .unstructured => {
                try cg.genBody(else_body);
            },
        }
    } else {
        try cg.body.emit(gpa, .OpUnreachable, {});
    }

    if (cg.control_flow == .structured) {
        try cg.beginSpvBlock(merge_label.?);
        const next_block = try cg.structuredNextBlock(incoming_structured_blocks.items);
        try cg.structuredBreak(next_block);
    }
}

fn airUnreach(cg: *CodeGen) !void {
    try cg.body.emit(cg.module.gpa, .OpUnreachable, {});
}

fn airDbgStmt(cg: *CodeGen, inst: Air.Inst.Index) !void {
    const zcu = cg.module.zcu;
    const dbg_stmt = cg.air.instructions.items(.data)[@intFromEnum(inst)].dbg_stmt;
    const path = zcu.navFileScope(cg.owner_nav).sub_file_path;

    if (zcu.comp.config.root_strip) return;

    try cg.body.emit(cg.module.gpa, .OpLine, .{
        .file = try cg.module.debugString(path),
        .line = cg.base_line + dbg_stmt.line + 1,
        .column = dbg_stmt.column + 1,
    });
}

fn airDbgInlineBlock(cg: *CodeGen, inst: Air.Inst.Index) !?Id {
    const zcu = cg.module.zcu;
    const inst_datas = cg.air.instructions.items(.data);
    const extra = cg.air.extraData(Air.DbgInlineBlock, inst_datas[@intFromEnum(inst)].ty_pl.payload);
    const old_base_line = cg.base_line;
    defer cg.base_line = old_base_line;
    cg.base_line = zcu.navSrcLine(zcu.funcInfo(extra.data.func).owner_nav);
    return cg.lowerBlock(inst, @ptrCast(cg.air.extra.items[extra.end..][0..extra.data.body_len]));
}

fn airDbgVar(cg: *CodeGen, inst: Air.Inst.Index) !void {
    const pl_op = cg.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
    const target_id = try cg.resolve(pl_op.operand);
    const name: Air.NullTerminatedString = @enumFromInt(pl_op.payload);
    try cg.module.debugName(target_id, name.toSlice(cg.air));
}

fn airAssembly(cg: *CodeGen, inst: Air.Inst.Index) !?Id {
    const gpa = cg.module.gpa;
    const zcu = cg.module.zcu;
    const ty_pl = cg.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const extra = cg.air.extraData(Air.Asm, ty_pl.payload);

    const is_volatile = extra.data.flags.is_volatile;
    const outputs_len = extra.data.flags.outputs_len;

    if (!is_volatile and cg.liveness.isUnused(inst)) return null;

    var extra_i: usize = extra.end;
    const outputs: []const Air.Inst.Ref = @ptrCast(cg.air.extra.items[extra_i..][0..outputs_len]);
    extra_i += outputs.len;
    const inputs: []const Air.Inst.Ref = @ptrCast(cg.air.extra.items[extra_i..][0..extra.data.inputs_len]);
    extra_i += inputs.len;

    if (outputs.len > 1) {
        return cg.todo("implement inline asm with more than 1 output", .{});
    }

    var ass: Assembler = .{ .cg = cg };
    defer ass.deinit();

    var output_extra_i = extra_i;
    for (outputs) |output| {
        if (output != .none) {
            return cg.todo("implement inline asm with non-returned output", .{});
        }
        const extra_bytes = std.mem.sliceAsBytes(cg.air.extra.items[extra_i..]);
        const constraint = std.mem.sliceTo(std.mem.sliceAsBytes(cg.air.extra.items[extra_i..]), 0);
        const name = std.mem.sliceTo(extra_bytes[constraint.len + 1 ..], 0);
        extra_i += (constraint.len + name.len + (2 + 3)) / 4;
        // TODO: Record output and use it somewhere.
    }

    for (inputs) |input| {
        const extra_bytes = std.mem.sliceAsBytes(cg.air.extra.items[extra_i..]);
        const constraint = std.mem.sliceTo(extra_bytes, 0);
        const name = std.mem.sliceTo(extra_bytes[constraint.len + 1 ..], 0);
        // This equation accounts for the fact that even if we have exactly 4 bytes
        // for the string, we still use the next u32 for the null terminator.
        extra_i += (constraint.len + name.len + (2 + 3)) / 4;

        const input_ty = cg.typeOf(input);

        if (std.mem.eql(u8, constraint, "c")) {
            // constant
            const val = (try cg.air.value(input, cg.pt)) orelse {
                return cg.fail("assembly inputs with 'c' constraint have to be compile-time known", .{});
            };

            // TODO: This entire function should be handled a bit better...
            const ip = &zcu.intern_pool;
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
                .union_type,
                .opaque_type,
                .enum_type,
                .func_type,
                .error_set_type,
                .inferred_error_set_type,
                => unreachable, // types, not values

                .undef => return cg.fail("assembly input with 'c' constraint cannot be undefined", .{}),

                .int => try ass.value_map.put(gpa, name, .{ .constant = @intCast(val.toUnsignedInt(zcu)) }),
                .enum_literal => |str| try ass.value_map.put(gpa, name, .{ .string = str.toSlice(ip) }),

                else => unreachable, // TODO
            }
        } else if (std.mem.eql(u8, constraint, "t")) {
            // type
            if (input_ty.zigTypeTag(zcu) == .type) {
                // This assembly input is a type instead of a value.
                // That's fine for now, just make sure to resolve it as such.
                const val = (try cg.air.value(input, cg.pt)).?;
                const ty_id = try cg.resolveType(val.toType(), .direct);
                try ass.value_map.put(gpa, name, .{ .ty = ty_id });
            } else {
                const ty_id = try cg.resolveType(input_ty, .direct);
                try ass.value_map.put(gpa, name, .{ .ty = ty_id });
            }
        } else {
            if (input_ty.zigTypeTag(zcu) == .type) {
                return cg.fail("use the 't' constraint to supply types to SPIR-V inline assembly", .{});
            }

            const val_id = try cg.resolve(input);
            try ass.value_map.put(gpa, name, .{ .value = val_id });
        }
    }

    // TODO: do something with clobbers
    _ = extra.data.clobbers;

    const asm_source = std.mem.sliceAsBytes(cg.air.extra.items[extra_i..])[0..extra.data.source_len];

    ass.assemble(asm_source) catch |err| switch (err) {
        error.AssembleFail => {
            // TODO: For now the compiler only supports a single error message per decl,
            // so to translate the possible multiple errors from the assembler, emit
            // them as notes here.
            // TODO: Translate proper error locations.
            assert(ass.errors.items.len != 0);
            assert(cg.error_msg == null);
            const src_loc = zcu.navSrcLoc(cg.owner_nav);
            cg.error_msg = try Zcu.ErrorMsg.create(zcu.gpa, src_loc, "failed to assemble SPIR-V inline assembly", .{});
            const notes = try zcu.gpa.alloc(Zcu.ErrorMsg, ass.errors.items.len);

            // Sub-scope to prevent `return error.CodegenFail` from running the errdefers.
            {
                errdefer zcu.gpa.free(notes);
                var i: usize = 0;
                errdefer for (notes[0..i]) |*note| {
                    note.deinit(zcu.gpa);
                };

                while (i < ass.errors.items.len) : (i += 1) {
                    notes[i] = try Zcu.ErrorMsg.init(zcu.gpa, src_loc, "{s}", .{ass.errors.items[i].msg});
                }
            }
            cg.error_msg.?.notes = notes;
            return error.CodegenFail;
        },
        else => |others| return others,
    };

    for (outputs) |output| {
        _ = output;
        const extra_bytes = std.mem.sliceAsBytes(cg.air.extra.items[output_extra_i..]);
        const constraint = std.mem.sliceTo(std.mem.sliceAsBytes(cg.air.extra.items[output_extra_i..]), 0);
        const name = std.mem.sliceTo(extra_bytes[constraint.len + 1 ..], 0);
        output_extra_i += (constraint.len + name.len + (2 + 3)) / 4;

        const result = ass.value_map.get(name) orelse return {
            return cg.fail("invalid asm output '{s}'", .{name});
        };

        switch (result) {
            .just_declared, .unresolved_forward_reference => unreachable,
            .ty => return cg.fail("cannot return spir-v type as value from assembly", .{}),
            .value => |ref| return ref,
            .constant, .string => return cg.fail("cannot return constant from assembly", .{}),
        }

        // TODO: Multiple results
        // TODO: Check that the output type from assembly is the same as the type actually expected by Zig.
    }

    return null;
}

fn airCall(cg: *CodeGen, inst: Air.Inst.Index, modifier: std.builtin.CallModifier) !?Id {
    _ = modifier;

    const gpa = cg.module.gpa;
    const zcu = cg.module.zcu;
    const pl_op = cg.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
    const extra = cg.air.extraData(Air.Call, pl_op.payload);
    const args: []const Air.Inst.Ref = @ptrCast(cg.air.extra.items[extra.end..][0..extra.data.args_len]);
    const callee_ty = cg.typeOf(pl_op.operand);
    const zig_fn_ty = switch (callee_ty.zigTypeTag(zcu)) {
        .@"fn" => callee_ty,
        .pointer => return cg.fail("cannot call function pointers", .{}),
        else => unreachable,
    };
    const fn_info = zcu.typeToFunc(zig_fn_ty).?;
    const return_type = fn_info.return_type;

    const result_type_id = try cg.resolveFnReturnType(.fromInterned(return_type));
    const result_id = cg.module.allocId();
    const callee_id = try cg.resolve(pl_op.operand);

    comptime assert(zig_call_abi_ver == 3);

    const scratch_top = cg.id_scratch.items.len;
    defer cg.id_scratch.shrinkRetainingCapacity(scratch_top);
    const params = try cg.id_scratch.addManyAsSlice(gpa, args.len);

    var n_params: usize = 0;
    for (args) |arg| {
        // Note: resolve() might emit instructions, so we need to call it
        // before starting to emit OpFunctionCall instructions. Hence the
        // temporary params buffer.
        const arg_ty = cg.typeOf(arg);
        if (!arg_ty.hasRuntimeBitsIgnoreComptime(zcu)) continue;
        const arg_id = try cg.resolve(arg);

        params[n_params] = arg_id;
        n_params += 1;
    }

    try cg.body.emit(gpa, .OpFunctionCall, .{
        .id_result_type = result_type_id,
        .id_result = result_id,
        .function = callee_id,
        .id_ref_3 = params[0..n_params],
    });

    if (cg.liveness.isUnused(inst) or !Type.fromInterned(return_type).hasRuntimeBitsIgnoreComptime(zcu)) {
        return null;
    }

    return result_id;
}

fn builtin3D(
    cg: *CodeGen,
    result_ty: Type,
    builtin: spec.BuiltIn,
    dimension: u32,
    out_of_range_value: anytype,
) !Id {
    const gpa = cg.module.gpa;
    if (dimension >= 3) return try cg.constInt(result_ty, out_of_range_value);
    const u32_ty_id = try cg.module.intType(.unsigned, 32);
    const vec_ty_id = try cg.module.vectorType(3, u32_ty_id);
    const ptr_ty_id = try cg.module.ptrType(vec_ty_id, .input);
    const spv_decl_index = try cg.module.builtin(ptr_ty_id, builtin, .input);
    try cg.module.decl_deps.append(gpa, spv_decl_index);
    const ptr_id = cg.module.declPtr(spv_decl_index).result_id;
    const vec_id = cg.module.allocId();
    try cg.body.emit(gpa, .OpLoad, .{
        .id_result_type = vec_ty_id,
        .id_result = vec_id,
        .pointer = ptr_id,
    });
    return try cg.extractVectorComponent(result_ty, vec_id, dimension);
}

fn airWorkItemId(cg: *CodeGen, inst: Air.Inst.Index) !?Id {
    if (cg.liveness.isUnused(inst)) return null;
    const pl_op = cg.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
    const dimension = pl_op.payload;
    return try cg.builtin3D(.u32, .local_invocation_id, dimension, 0);
}

// TODO: this must be an OpConstant/OpSpec but even then the driver crashes.
fn airWorkGroupSize(cg: *CodeGen, inst: Air.Inst.Index) !?Id {
    if (cg.liveness.isUnused(inst)) return null;
    const pl_op = cg.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
    const dimension = pl_op.payload;
    return try cg.builtin3D(.u32, .workgroup_size, dimension, 0);
}

fn airWorkGroupId(cg: *CodeGen, inst: Air.Inst.Index) !?Id {
    if (cg.liveness.isUnused(inst)) return null;
    const pl_op = cg.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
    const dimension = pl_op.payload;
    return try cg.builtin3D(.u32, .workgroup_id, dimension, 0);
}

fn typeOf(cg: *CodeGen, inst: Air.Inst.Ref) Type {
    const zcu = cg.module.zcu;
    return cg.air.typeOf(inst, &zcu.intern_pool);
}

fn typeOfIndex(cg: *CodeGen, inst: Air.Inst.Index) Type {
    const zcu = cg.module.zcu;
    return cg.air.typeOfIndex(inst, &zcu.intern_pool);
}
