//! This structure represents a SPIR-V (sections) module being compiled, and keeps track of all relevant information.
//! That includes the actual instructions, the current result-id bound, and data structures for querying result-id's
//! of data which needs to be persistent over different calls to Decl code generation.
//!
//! A SPIR-V binary module supports both little- and big endian layout. The layout is detected by the magic word in the
//! header. Therefore, we can ignore any byte order throughout the implementation, and just use the host byte order,
//! and make this a problem for the consumer.
const Module = @This();

const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const autoHashStrat = std.hash.autoHashStrat;
const Wyhash = std.hash.Wyhash;

const spec = @import("spec.zig");
const Word = spec.Word;
const IdRef = spec.IdRef;
const IdResult = spec.IdResult;
const IdResultType = spec.IdResultType;

const Section = @import("Section.zig");

/// This structure represents a function that isc in-progress of being emitted.
/// Commonly, the contents of this structure will be merged with the appropriate
/// sections of the module and re-used. Note that the SPIR-V module system makes
/// no attempt of compacting result-id's, so any Fn instance should ultimately
/// be merged into the module it's result-id's are allocated from.
pub const Fn = struct {
    /// The prologue of this function; this section contains the function's
    /// OpFunction, OpFunctionParameter, OpLabel and OpVariable instructions, and
    /// is separated from the actual function contents as OpVariable instructions
    /// must appear in the first block of a function definition.
    prologue: Section = .{},
    /// The code of the body of this function.
    /// This section should also contain the OpFunctionEnd instruction marking
    /// the end of this function definition.
    body: Section = .{},
    /// The decl dependencies that this function depends on.
    decl_deps: std.AutoArrayHashMapUnmanaged(Decl.Index, void) = .empty,

    /// Reset this function without deallocating resources, so that
    /// it may be used to emit code for another function.
    pub fn reset(self: *Fn) void {
        self.prologue.reset();
        self.body.reset();
        self.decl_deps.clearRetainingCapacity();
    }

    /// Free the resources owned by this function.
    pub fn deinit(self: *Fn, a: Allocator) void {
        self.prologue.deinit(a);
        self.body.deinit(a);
        self.decl_deps.deinit(a);
        self.* = undefined;
    }
};

/// Declarations, both functions and globals, can have dependencies. These are used for 2 things:
/// - Globals must be declared before they are used, also between globals. The compiler processes
///   globals unordered, so we must use the dependencies here to figure out how to order the globals
///   in the final module. The Globals structure is also used for that.
/// - Entry points must declare the complete list of OpVariable instructions that they access.
///   For these we use the same dependency structure.
/// In this mechanism, globals will only depend on other globals, while functions may depend on
/// globals or other functions.
pub const Decl = struct {
    /// Index to refer to a Decl by.
    pub const Index = enum(u32) { _ };

    /// Useful to tell what kind of decl this is, and hold the result-id or field index
    /// to be used for this decl.
    pub const Kind = enum {
        func,
        global,
        invocation_global,
    };

    /// See comment on Kind
    kind: Kind,
    /// The result-id associated to this decl. The specific meaning of this depends on `kind`:
    /// - For `func`, this is the result-id of the associated OpFunction instruction.
    /// - For `global`, this is the result-id of the associated OpVariable instruction.
    /// - For `invocation_global`, this is the result-id of the associated InvocationGlobal instruction.
    result_id: IdRef,
    /// The offset of the first dependency of this decl in the `decl_deps` array.
    begin_dep: u32,
    /// The past-end offset of the dependencies of this decl in the `decl_deps` array.
    end_dep: u32,
};

/// This models a kernel entry point.
pub const EntryPoint = struct {
    /// The declaration that should be exported.
    decl_index: ?Decl.Index = null,
    /// The name of the kernel to be exported.
    name: ?[]const u8 = null,
    /// Calling Convention
    exec_model: ?spec.ExecutionModel = null,
    exec_mode: ?spec.ExecutionMode = null,
};

/// A general-purpose allocator which may be used to allocate resources for this module
gpa: Allocator,

/// Arena for things that need to live for the length of this program.
arena: std.heap.ArenaAllocator,

/// Target info
target: std.Target,

/// The target SPIR-V version
version: spec.Version,

/// Module layout, according to SPIR-V Spec section 2.4, "Logical Layout of a Module".
sections: struct {
    /// Capability instructions
    capabilities: Section = .{},
    /// OpExtension instructions
    extensions: Section = .{},
    /// OpExtInstImport
    extended_instruction_set: Section = .{},
    /// memory model defined by target
    memory_model: Section = .{},
    /// OpEntryPoint instructions - Handled by `self.entry_points`.
    /// OpExecutionMode and OpExecutionModeId instructions.
    execution_modes: Section = .{},
    /// OpString, OpSourcExtension, OpSource, OpSourceContinued.
    debug_strings: Section = .{},
    // OpName, OpMemberName.
    debug_names: Section = .{},
    // OpModuleProcessed - skip for now.
    /// Annotation instructions (OpDecorate etc).
    annotations: Section = .{},
    /// Type declarations, constants, global variables
    /// From this section, OpLine and OpNoLine is allowed.
    /// According to the SPIR-V documentation, this section normally
    /// also holds type and constant instructions. These are managed
    /// via the cache instead, which is the sole structure that
    /// manages that section. These will be inserted between this and
    /// the previous section when emitting the final binary.
    /// TODO: Do we need this section? Globals are also managed with another mechanism.
    types_globals_constants: Section = .{},
    // Functions without a body - skip for now.
    /// Regular function definitions.
    functions: Section = .{},
} = .{},

/// SPIR-V instructions return result-ids. This variable holds the module-wide counter for these.
next_result_id: Word,

/// Cache for results of OpString instructions.
strings: std.StringArrayHashMapUnmanaged(IdRef) = .empty,

/// Some types shouldn't be emitted more than one time, but cannot be caught by
/// the `intern_map` during codegen. Sometimes, IDs are compared to check if
/// types are the same, so we can't delay until the dedup pass. Therefore,
/// this is an ad-hoc structure to cache types where required.
/// According to the SPIR-V specification, section 2.8, this includes all non-aggregate
/// non-pointer types.
/// Additionally, this is used for other values which can be cached, for example,
/// built-in variables.
cache: struct {
    bool_type: ?IdRef = null,
    void_type: ?IdRef = null,
    int_types: std.AutoHashMapUnmanaged(std.builtin.Type.Int, IdRef) = .empty,
    float_types: std.AutoHashMapUnmanaged(std.builtin.Type.Float, IdRef) = .empty,
    vector_types: std.AutoHashMapUnmanaged(struct { IdRef, u32 }, IdRef) = .empty,
    array_types: std.AutoHashMapUnmanaged(struct { IdRef, IdRef }, IdRef) = .empty,

    capabilities: std.AutoHashMapUnmanaged(spec.Capability, void) = .empty,
    extensions: std.StringHashMapUnmanaged(void) = .empty,
    extended_instruction_set: std.AutoHashMapUnmanaged(spec.InstructionSet, IdRef) = .empty,
    decorations: std.AutoHashMapUnmanaged(struct { IdRef, spec.Decoration }, void) = .empty,
    builtins: std.AutoHashMapUnmanaged(struct { IdRef, spec.BuiltIn }, Decl.Index) = .empty,

    bool_const: [2]?IdRef = .{ null, null },
} = .{},

/// Set of Decls, referred to by Decl.Index.
decls: std.ArrayListUnmanaged(Decl) = .empty,

/// List of dependencies, per decl. This list holds all the dependencies, sliced by the
/// begin_dep and end_dep in `self.decls`.
decl_deps: std.ArrayListUnmanaged(Decl.Index) = .empty,

/// The list of entry points that should be exported from this module.
entry_points: std.AutoArrayHashMapUnmanaged(IdRef, EntryPoint) = .empty,

pub fn init(gpa: Allocator, target: std.Target) Module {
    const version_minor: u8 = blk: {
        // Prefer higher versions
        if (target.cpu.has(.spirv, .v1_6)) break :blk 6;
        if (target.cpu.has(.spirv, .v1_5)) break :blk 5;
        if (target.cpu.has(.spirv, .v1_4)) break :blk 4;
        if (target.cpu.has(.spirv, .v1_3)) break :blk 3;
        if (target.cpu.has(.spirv, .v1_2)) break :blk 2;
        if (target.cpu.has(.spirv, .v1_1)) break :blk 1;
        break :blk 0;
    };

    return .{
        .gpa = gpa,
        .arena = std.heap.ArenaAllocator.init(gpa),
        .target = target,
        .version = .{ .major = 1, .minor = version_minor },
        .next_result_id = 1, // 0 is an invalid SPIR-V result id, so start counting at 1.
    };
}

pub fn deinit(self: *Module) void {
    self.sections.capabilities.deinit(self.gpa);
    self.sections.extensions.deinit(self.gpa);
    self.sections.extended_instruction_set.deinit(self.gpa);
    self.sections.memory_model.deinit(self.gpa);
    self.sections.execution_modes.deinit(self.gpa);
    self.sections.debug_strings.deinit(self.gpa);
    self.sections.debug_names.deinit(self.gpa);
    self.sections.annotations.deinit(self.gpa);
    self.sections.types_globals_constants.deinit(self.gpa);
    self.sections.functions.deinit(self.gpa);

    self.strings.deinit(self.gpa);

    self.cache.int_types.deinit(self.gpa);
    self.cache.float_types.deinit(self.gpa);
    self.cache.vector_types.deinit(self.gpa);
    self.cache.array_types.deinit(self.gpa);
    self.cache.capabilities.deinit(self.gpa);
    self.cache.extensions.deinit(self.gpa);
    self.cache.extended_instruction_set.deinit(self.gpa);
    self.cache.decorations.deinit(self.gpa);
    self.cache.builtins.deinit(self.gpa);

    self.decls.deinit(self.gpa);
    self.decl_deps.deinit(self.gpa);
    self.entry_points.deinit(self.gpa);

    self.arena.deinit();

    self.* = undefined;
}

pub const IdRange = struct {
    base: u32,
    len: u32,

    pub fn at(range: IdRange, i: usize) IdResult {
        assert(i < range.len);
        return @enumFromInt(range.base + i);
    }
};

pub fn allocIds(self: *Module, n: u32) IdRange {
    defer self.next_result_id += n;
    return .{
        .base = self.next_result_id,
        .len = n,
    };
}

pub fn allocId(self: *Module) IdResult {
    return self.allocIds(1).at(0);
}

pub fn idBound(self: Module) Word {
    return self.next_result_id;
}

pub fn hasFeature(self: *Module, feature: std.Target.spirv.Feature) bool {
    return self.target.cpu.has(.spirv, feature);
}

fn addEntryPointDeps(
    self: *Module,
    decl_index: Decl.Index,
    seen: *std.DynamicBitSetUnmanaged,
    interface: *std.ArrayList(IdRef),
) !void {
    const decl = self.declPtr(decl_index);
    const deps = self.decl_deps.items[decl.begin_dep..decl.end_dep];

    if (seen.isSet(@intFromEnum(decl_index))) {
        return;
    }

    seen.set(@intFromEnum(decl_index));

    if (decl.kind == .global) {
        try interface.append(decl.result_id);
    }

    for (deps) |dep| {
        try self.addEntryPointDeps(dep, seen, interface);
    }
}

fn entryPoints(self: *Module) !Section {
    var entry_points = Section{};
    errdefer entry_points.deinit(self.gpa);

    var interface = std.ArrayList(IdRef).init(self.gpa);
    defer interface.deinit();

    var seen = try std.DynamicBitSetUnmanaged.initEmpty(self.gpa, self.decls.items.len);
    defer seen.deinit(self.gpa);

    for (self.entry_points.keys(), self.entry_points.values()) |entry_point_id, entry_point| {
        interface.items.len = 0;
        seen.setRangeValue(.{ .start = 0, .end = self.decls.items.len }, false);

        try self.addEntryPointDeps(entry_point.decl_index.?, &seen, &interface);
        try entry_points.emit(self.gpa, .OpEntryPoint, .{
            .execution_model = entry_point.exec_model.?,
            .entry_point = entry_point_id,
            .name = entry_point.name.?,
            .interface = interface.items,
        });

        if (entry_point.exec_mode == null and entry_point.exec_model == .Fragment) {
            switch (self.target.os.tag) {
                .vulkan, .opengl => |tag| {
                    try self.sections.execution_modes.emit(self.gpa, .OpExecutionMode, .{
                        .entry_point = entry_point_id,
                        .mode = if (tag == .vulkan) .OriginUpperLeft else .OriginLowerLeft,
                    });
                },
                .opencl => {},
                else => unreachable,
            }
        }
    }

    return entry_points;
}

pub fn finalize(self: *Module, a: Allocator) ![]Word {
    // Emit capabilities and extensions
    for (std.Target.spirv.all_features) |feature| {
        if (self.target.cpu.features.isEnabled(feature.index)) {
            const feature_tag: std.Target.spirv.Feature = @enumFromInt(feature.index);
            switch (feature_tag) {
                // Versions
                .v1_0, .v1_1, .v1_2, .v1_3, .v1_4, .v1_5, .v1_6 => {},
                // Features with no dependencies
                .int64 => try self.addCapability(.Int64),
                .float16 => try self.addCapability(.Float16),
                .float64 => try self.addCapability(.Float64),
                .matrix => try self.addCapability(.Matrix),
                .storage_push_constant16 => {
                    try self.addExtension("SPV_KHR_16bit_storage");
                    try self.addCapability(.StoragePushConstant16);
                },
                .arbitrary_precision_integers => {
                    try self.addExtension("SPV_INTEL_arbitrary_precision_integers");
                    try self.addCapability(.ArbitraryPrecisionIntegersINTEL);
                },
                .addresses => try self.addCapability(.Addresses),
                // Kernel
                .kernel => try self.addCapability(.Kernel),
                .generic_pointer => try self.addCapability(.GenericPointer),
                .vector16 => try self.addCapability(.Vector16),
                // Shader
                .shader => try self.addCapability(.Shader),
                .variable_pointers => {
                    try self.addExtension("SPV_KHR_variable_pointers");
                    try self.addCapability(.VariablePointersStorageBuffer);
                    try self.addCapability(.VariablePointers);
                },
                .physical_storage_buffer => {
                    try self.addExtension("SPV_KHR_physical_storage_buffer");
                    try self.addCapability(.PhysicalStorageBufferAddresses);
                },
            }
        }
    }
    // These are well supported
    try self.addCapability(.Int8);
    try self.addCapability(.Int16);

    // Emit memory model
    const addressing_model: spec.AddressingModel = blk: {
        if (self.hasFeature(.shader)) {
            if (self.hasFeature(.physical_storage_buffer)) {
                assert(self.target.cpu.arch == .spirv64);
                break :blk .PhysicalStorageBuffer64;
            }
            assert(self.target.cpu.arch == .spirv);
            break :blk .Logical;
        }

        assert(self.hasFeature(.kernel));
        break :blk switch (self.target.cpu.arch) {
            .spirv32 => .Physical32,
            .spirv64 => .Physical64,
            else => unreachable,
        };
    };
    try self.sections.memory_model.emit(self.gpa, .OpMemoryModel, .{
        .addressing_model = addressing_model,
        .memory_model = switch (self.target.os.tag) {
            .opencl => .OpenCL,
            .vulkan, .opengl => .GLSL450,
            else => unreachable,
        },
    });

    // See SPIR-V Spec section 2.3, "Physical Layout of a SPIR-V Module and Instruction"
    // TODO: Audit calls to allocId() in this function to make it idempotent.
    var entry_points = try self.entryPoints();
    defer entry_points.deinit(self.gpa);

    const header = [_]Word{
        spec.magic_number,
        self.version.toWord(),
        spec.zig_generator_id,
        self.idBound(),
        0, // Schema (currently reserved for future use)
    };

    var source = Section{};
    defer source.deinit(self.gpa);
    try self.sections.debug_strings.emit(self.gpa, .OpSource, .{
        .source_language = .Zig,
        .version = 0,
        // We cannot emit these because the Khronos translator does not parse this instruction
        // correctly.
        // See https://github.com/KhronosGroup/SPIRV-LLVM-Translator/issues/2188
        .file = null,
        .source = null,
    });

    // Note: needs to be kept in order according to section 2.3!
    const buffers = &[_][]const Word{
        &header,
        self.sections.capabilities.toWords(),
        self.sections.extensions.toWords(),
        self.sections.extended_instruction_set.toWords(),
        self.sections.memory_model.toWords(),
        entry_points.toWords(),
        self.sections.execution_modes.toWords(),
        source.toWords(),
        self.sections.debug_strings.toWords(),
        self.sections.debug_names.toWords(),
        self.sections.annotations.toWords(),
        self.sections.types_globals_constants.toWords(),
        self.sections.functions.toWords(),
    };

    var total_result_size: usize = 0;
    for (buffers) |buffer| {
        total_result_size += buffer.len;
    }
    const result = try a.alloc(Word, total_result_size);
    errdefer a.free(result);

    var offset: usize = 0;
    for (buffers) |buffer| {
        @memcpy(result[offset..][0..buffer.len], buffer);
        offset += buffer.len;
    }

    return result;
}

/// Merge the sections making up a function declaration into this module.
pub fn addFunction(self: *Module, decl_index: Decl.Index, func: Fn) !void {
    try self.sections.functions.append(self.gpa, func.prologue);
    try self.sections.functions.append(self.gpa, func.body);
    try self.declareDeclDeps(decl_index, func.decl_deps.keys());
}

pub fn addCapability(self: *Module, cap: spec.Capability) !void {
    const entry = try self.cache.capabilities.getOrPut(self.gpa, cap);
    if (entry.found_existing) return;
    try self.sections.capabilities.emit(self.gpa, .OpCapability, .{ .capability = cap });
}

pub fn addExtension(self: *Module, ext: []const u8) !void {
    const entry = try self.cache.extensions.getOrPut(self.gpa, ext);
    if (entry.found_existing) return;
    try self.sections.extensions.emit(self.gpa, .OpExtension, .{ .name = ext });
}

/// Imports or returns the existing id of an extended instruction set
pub fn importInstructionSet(self: *Module, set: spec.InstructionSet) !IdRef {
    assert(set != .core);

    const gop = try self.cache.extended_instruction_set.getOrPut(self.gpa, set);
    if (gop.found_existing) return gop.value_ptr.*;

    const result_id = self.allocId();
    try self.sections.extended_instruction_set.emit(self.gpa, .OpExtInstImport, .{
        .id_result = result_id,
        .name = @tagName(set),
    });
    gop.value_ptr.* = result_id;

    return result_id;
}

/// Fetch the result-id of an instruction corresponding to a string.
pub fn resolveString(self: *Module, string: []const u8) !IdRef {
    if (self.strings.get(string)) |id| {
        return id;
    }

    const id = self.allocId();
    try self.strings.put(self.gpa, try self.arena.allocator().dupe(u8, string), id);

    try self.sections.debug_strings.emit(self.gpa, .OpString, .{
        .id_result = id,
        .string = string,
    });

    return id;
}

pub fn structType(self: *Module, result_id: IdResult, types: []const IdRef, maybe_names: ?[]const []const u8) !void {
    try self.sections.types_globals_constants.emit(self.gpa, .OpTypeStruct, .{
        .id_result = result_id,
        .id_ref = types,
    });

    if (maybe_names) |names| {
        assert(names.len == types.len);
        for (names, 0..) |name, i| {
            try self.memberDebugName(result_id, @intCast(i), name);
        }
    }
}

pub fn boolType(self: *Module) !IdRef {
    if (self.cache.bool_type) |id| return id;

    const result_id = self.allocId();
    try self.sections.types_globals_constants.emit(self.gpa, .OpTypeBool, .{
        .id_result = result_id,
    });
    self.cache.bool_type = result_id;
    return result_id;
}

pub fn voidType(self: *Module) !IdRef {
    if (self.cache.void_type) |id| return id;

    const result_id = self.allocId();
    try self.sections.types_globals_constants.emit(self.gpa, .OpTypeVoid, .{
        .id_result = result_id,
    });
    self.cache.void_type = result_id;
    try self.debugName(result_id, "void");
    return result_id;
}

pub fn intType(self: *Module, signedness: std.builtin.Signedness, bits: u16) !IdRef {
    assert(bits > 0);
    const entry = try self.cache.int_types.getOrPut(self.gpa, .{ .signedness = signedness, .bits = bits });
    if (!entry.found_existing) {
        const result_id = self.allocId();
        entry.value_ptr.* = result_id;
        try self.sections.types_globals_constants.emit(self.gpa, .OpTypeInt, .{
            .id_result = result_id,
            .width = bits,
            .signedness = switch (signedness) {
                .signed => 1,
                .unsigned => 0,
            },
        });

        switch (signedness) {
            .signed => try self.debugNameFmt(result_id, "i{}", .{bits}),
            .unsigned => try self.debugNameFmt(result_id, "u{}", .{bits}),
        }
    }
    return entry.value_ptr.*;
}

pub fn floatType(self: *Module, bits: u16) !IdRef {
    assert(bits > 0);
    const entry = try self.cache.float_types.getOrPut(self.gpa, .{ .bits = bits });
    if (!entry.found_existing) {
        const result_id = self.allocId();
        entry.value_ptr.* = result_id;
        try self.sections.types_globals_constants.emit(self.gpa, .OpTypeFloat, .{
            .id_result = result_id,
            .width = bits,
        });
        try self.debugNameFmt(result_id, "f{}", .{bits});
    }
    return entry.value_ptr.*;
}

pub fn vectorType(self: *Module, len: u32, child_ty_id: IdRef) !IdRef {
    const entry = try self.cache.vector_types.getOrPut(self.gpa, .{ child_ty_id, len });
    if (!entry.found_existing) {
        const result_id = self.allocId();
        entry.value_ptr.* = result_id;
        try self.sections.types_globals_constants.emit(self.gpa, .OpTypeVector, .{
            .id_result = result_id,
            .component_type = child_ty_id,
            .component_count = len,
        });
    }
    return entry.value_ptr.*;
}

pub fn arrayType(self: *Module, len_id: IdRef, child_ty_id: IdRef) !IdRef {
    const entry = try self.cache.array_types.getOrPut(self.gpa, .{ child_ty_id, len_id });
    if (!entry.found_existing) {
        const result_id = self.allocId();
        entry.value_ptr.* = result_id;
        try self.sections.types_globals_constants.emit(self.gpa, .OpTypeArray, .{
            .id_result = result_id,
            .element_type = child_ty_id,
            .length = len_id,
        });
    }
    return entry.value_ptr.*;
}

pub fn functionType(self: *Module, return_ty_id: IdRef, param_type_ids: []const IdRef) !IdRef {
    const result_id = self.allocId();
    try self.sections.types_globals_constants.emit(self.gpa, .OpTypeFunction, .{
        .id_result = result_id,
        .return_type = return_ty_id,
        .id_ref_2 = param_type_ids,
    });
    return result_id;
}

pub fn constant(self: *Module, result_ty_id: IdRef, value: spec.LiteralContextDependentNumber) !IdRef {
    const result_id = self.allocId();
    const section = &self.sections.types_globals_constants;
    try section.emit(self.gpa, .OpConstant, .{
        .id_result_type = result_ty_id,
        .id_result = result_id,
        .value = value,
    });
    return result_id;
}

pub fn constBool(self: *Module, value: bool) !IdRef {
    if (self.cache.bool_const[@intFromBool(value)]) |b| return b;

    const result_ty_id = try self.boolType();
    const result_id = self.allocId();
    self.cache.bool_const[@intFromBool(value)] = result_id;

    switch (value) {
        inline else => |value_ct| try self.sections.types_globals_constants.emit(
            self.gpa,
            if (value_ct) .OpConstantTrue else .OpConstantFalse,
            .{
                .id_result_type = result_ty_id,
                .id_result = result_id,
            },
        ),
    }

    return result_id;
}

/// Return a pointer to a builtin variable. `result_ty_id` must be a **pointer**
/// with storage class `.Input`.
pub fn builtin(self: *Module, result_ty_id: IdRef, spirv_builtin: spec.BuiltIn) !Decl.Index {
    const entry = try self.cache.builtins.getOrPut(self.gpa, .{ result_ty_id, spirv_builtin });
    if (!entry.found_existing) {
        const decl_index = try self.allocDecl(.global);
        const result_id = self.declPtr(decl_index).result_id;
        entry.value_ptr.* = decl_index;
        try self.sections.types_globals_constants.emit(self.gpa, .OpVariable, .{
            .id_result_type = result_ty_id,
            .id_result = result_id,
            .storage_class = .Input,
        });
        try self.decorate(result_id, .{ .BuiltIn = .{ .built_in = spirv_builtin } });
        try self.declareDeclDeps(decl_index, &.{});
    }
    return entry.value_ptr.*;
}

pub fn constUndef(self: *Module, ty_id: IdRef) !IdRef {
    const result_id = self.allocId();
    try self.sections.types_globals_constants.emit(self.gpa, .OpUndef, .{
        .id_result_type = ty_id,
        .id_result = result_id,
    });
    return result_id;
}

pub fn constNull(self: *Module, ty_id: IdRef) !IdRef {
    const result_id = self.allocId();
    try self.sections.types_globals_constants.emit(self.gpa, .OpConstantNull, .{
        .id_result_type = ty_id,
        .id_result = result_id,
    });
    return result_id;
}

/// Decorate a result-id.
pub fn decorate(
    self: *Module,
    target: IdRef,
    decoration: spec.Decoration.Extended,
) !void {
    const entry = try self.cache.decorations.getOrPut(self.gpa, .{ target, decoration });
    if (!entry.found_existing) {
        try self.sections.annotations.emit(self.gpa, .OpDecorate, .{
            .target = target,
            .decoration = decoration,
        });
    }
}

/// Decorate a result-id which is a member of some struct.
/// We really don't have to and shouldn't need to cache this.
pub fn decorateMember(
    self: *Module,
    structure_type: IdRef,
    member: u32,
    decoration: spec.Decoration.Extended,
) !void {
    try self.sections.annotations.emit(self.gpa, .OpMemberDecorate, .{
        .structure_type = structure_type,
        .member = member,
        .decoration = decoration,
    });
}

pub fn allocDecl(self: *Module, kind: Decl.Kind) !Decl.Index {
    try self.decls.append(self.gpa, .{
        .kind = kind,
        .result_id = self.allocId(),
        .begin_dep = undefined,
        .end_dep = undefined,
    });

    return @as(Decl.Index, @enumFromInt(@as(u32, @intCast(self.decls.items.len - 1))));
}

pub fn declPtr(self: *Module, index: Decl.Index) *Decl {
    return &self.decls.items[@intFromEnum(index)];
}

/// Declare ALL dependencies for a decl.
pub fn declareDeclDeps(self: *Module, decl_index: Decl.Index, deps: []const Decl.Index) !void {
    const begin_dep: u32 = @intCast(self.decl_deps.items.len);
    try self.decl_deps.appendSlice(self.gpa, deps);
    const end_dep: u32 = @intCast(self.decl_deps.items.len);

    const decl = self.declPtr(decl_index);
    decl.begin_dep = begin_dep;
    decl.end_dep = end_dep;
}

/// Declare a SPIR-V function as an entry point. This causes an extra wrapper
/// function to be generated, which is then exported as the real entry point. The purpose of this
/// wrapper is to allocate and initialize the structure holding the instance globals.
pub fn declareEntryPoint(
    self: *Module,
    decl_index: Decl.Index,
    name: []const u8,
    exec_model: spec.ExecutionModel,
    exec_mode: ?spec.ExecutionMode,
) !void {
    const gop = try self.entry_points.getOrPut(self.gpa, self.declPtr(decl_index).result_id);
    gop.value_ptr.decl_index = decl_index;
    gop.value_ptr.name = try self.arena.allocator().dupe(u8, name);
    gop.value_ptr.exec_model = exec_model;
    // Might've been set by assembler
    if (!gop.found_existing) gop.value_ptr.exec_mode = exec_mode;
}

pub fn debugName(self: *Module, target: IdResult, name: []const u8) !void {
    try self.sections.debug_names.emit(self.gpa, .OpName, .{
        .target = target,
        .name = name,
    });
}

pub fn debugNameFmt(self: *Module, target: IdResult, comptime fmt: []const u8, args: anytype) !void {
    const name = try std.fmt.allocPrint(self.gpa, fmt, args);
    defer self.gpa.free(name);
    try self.debugName(target, name);
}

pub fn memberDebugName(self: *Module, target: IdResult, member: u32, name: []const u8) !void {
    try self.sections.debug_names.emit(self.gpa, .OpMemberName, .{
        .type = target,
        .member = member,
        .name = name,
    });
}
