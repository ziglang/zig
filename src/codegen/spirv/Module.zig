//! This structure represents a SPIR-V (sections) module being compiled, and keeps track of all relevant information.
//! That includes the actual instructions, the current result-id bound, and data structures for querying result-id's
//! of data which needs to be persistent over different calls to Decl code generation.
//!
//! A SPIR-V binary module supports both little- and big endian layout. The layout is detected by the magic word in the
//! header. Therefore, we can ignore any byte order throughout the implementation, and just use the host byte order,
//! and make this a problem for the consumer.
const Module = @This();

const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

const spec = @import("spec.zig");
const Word = spec.Word;
const IdRef = spec.IdRef;
const IdResult = spec.IdResult;
const IdResultType = spec.IdResultType;

const Section = @import("Section.zig");

const Cache = @import("Cache.zig");
pub const CacheKey = Cache.Key;
pub const CacheRef = Cache.Ref;
pub const CacheString = Cache.String;

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
    decl_deps: std.AutoArrayHashMapUnmanaged(Decl.Index, void) = .{},

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

    /// The result-id to be used for this declaration. This is the final result-id
    /// of the decl, which may be an OpFunction, OpVariable, or the result of a sequence
    /// of OpSpecConstantOp operations.
    result_id: IdRef,
    /// The offset of the first dependency of this decl in the `decl_deps` array.
    begin_dep: u32,
    /// The past-end offset of the dependencies of this decl in the `decl_deps` array.
    end_dep: u32,
};

/// Globals must be kept in order: operations involving globals must be ordered
/// so that the global declaration precedes any usage.
pub const Global = struct {
    /// This is the result-id of the OpVariable instruction that declares the global.
    result_id: IdRef,
    /// The offset into `self.globals.section` of the first instruction of this global
    /// declaration.
    begin_inst: u32,
    /// The past-end offset into `self.flobals.section`.
    end_inst: u32,
    /// The result-id of the function that initializes this value.
    initializer_id: ?IdRef,
};

/// This models a kernel entry point.
pub const EntryPoint = struct {
    /// The declaration that should be exported.
    decl_index: Decl.Index,
    /// The name of the kernel to be exported.
    name: CacheString,
    /// Calling Convention
    execution_model: spec.ExecutionModel,
};

/// A general-purpose allocator which may be used to allocate resources for this module
gpa: Allocator,

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

/// Cache for results of OpString instructions for module file names fed to OpSource.
/// Since OpString is pretty much only used for those, we don't need to keep track of all strings,
/// just the ones for OpLine. Note that OpLine needs the result of OpString, and not that of OpSource.
source_file_names: std.AutoArrayHashMapUnmanaged(CacheString, IdRef) = .{},

/// SPIR-V type- and constant cache. This structure is used to store information about these in a more
/// efficient manner.
cache: Cache = .{},

/// Set of Decls, referred to by Decl.Index.
decls: std.ArrayListUnmanaged(Decl) = .{},

/// List of dependencies, per decl. This list holds all the dependencies, sliced by the
/// begin_dep and end_dep in `self.decls`.
decl_deps: std.ArrayListUnmanaged(Decl.Index) = .{},

/// The list of entry points that should be exported from this module.
entry_points: std.ArrayListUnmanaged(EntryPoint) = .{},

/// The fields in this structure help to maintain the required order for global variables.
globals: struct {
    /// Set of globals, referred to by Decl.Index.
    globals: std.AutoArrayHashMapUnmanaged(Decl.Index, Global) = .{},
    /// This pseudo-section contains the initialization code for all the globals. Instructions from
    /// here are reordered when flushing the module. Its contents should be part of the
    /// `types_globals_constants` SPIR-V section when the module is emitted.
    section: Section = .{},
} = .{},

/// The list of extended instruction sets that should be imported.
extended_instruction_set: std.AutoHashMapUnmanaged(ExtendedInstructionSet, IdRef) = .{},

pub fn init(gpa: Allocator) Module {
    return .{
        .gpa = gpa,
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

    self.source_file_names.deinit(self.gpa);
    self.cache.deinit(self);

    self.decls.deinit(self.gpa);
    self.decl_deps.deinit(self.gpa);

    self.entry_points.deinit(self.gpa);

    self.globals.globals.deinit(self.gpa);
    self.globals.section.deinit(self.gpa);

    self.extended_instruction_set.deinit(self.gpa);

    self.* = undefined;
}

pub fn allocId(self: *Module) spec.IdResult {
    defer self.next_result_id += 1;
    return .{ .id = self.next_result_id };
}

pub fn allocIds(self: *Module, n: u32) spec.IdResult {
    defer self.next_result_id += n;
    return .{ .id = self.next_result_id };
}

pub fn idBound(self: Module) Word {
    return self.next_result_id;
}

pub fn resolve(self: *Module, key: CacheKey) !CacheRef {
    return self.cache.resolve(self, key);
}

pub fn resultId(self: *const Module, ref: CacheRef) IdResult {
    return self.cache.resultId(ref);
}

pub fn resolveId(self: *Module, key: CacheKey) !IdResult {
    return self.resultId(try self.resolve(key));
}

pub fn resolveString(self: *Module, str: []const u8) !CacheString {
    return try self.cache.addString(self, str);
}

fn orderGlobalsInto(
    self: *Module,
    decl_index: Decl.Index,
    section: *Section,
    seen: *std.DynamicBitSetUnmanaged,
) !void {
    const decl = self.declPtr(decl_index);
    const deps = self.decl_deps.items[decl.begin_dep..decl.end_dep];
    const global = self.globalPtr(decl_index).?;
    const insts = self.globals.section.instructions.items[global.begin_inst..global.end_inst];

    seen.set(@intFromEnum(decl_index));

    for (deps) |dep| {
        if (!seen.isSet(@intFromEnum(dep))) {
            try self.orderGlobalsInto(dep, section, seen);
        }
    }

    try section.instructions.appendSlice(self.gpa, insts);
}

fn orderGlobals(self: *Module) !Section {
    const globals = self.globals.globals.keys();

    var seen = try std.DynamicBitSetUnmanaged.initEmpty(self.gpa, self.decls.items.len);
    defer seen.deinit(self.gpa);

    var ordered_globals = Section{};
    errdefer ordered_globals.deinit(self.gpa);

    for (globals) |decl_index| {
        if (!seen.isSet(@intFromEnum(decl_index))) {
            try self.orderGlobalsInto(decl_index, &ordered_globals, &seen);
        }
    }

    return ordered_globals;
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

    if (self.globalPtr(decl_index)) |global| {
        try interface.append(global.result_id);
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

    for (self.entry_points.items) |entry_point| {
        interface.items.len = 0;
        seen.setRangeValue(.{ .start = 0, .end = self.decls.items.len }, false);

        try self.addEntryPointDeps(entry_point.decl_index, &seen, &interface);

        const entry_point_id = self.declPtr(entry_point.decl_index).result_id;
        try entry_points.emit(self.gpa, .OpEntryPoint, .{
            .execution_model = entry_point.execution_model,
            .entry_point = entry_point_id,
            .name = self.cache.getString(entry_point.name).?,
            .interface = interface.items,
        });
    }

    return entry_points;
}

/// Generate a function that calls all initialization functions,
/// in unspecified order (an order should not be required here).
/// It generated as follows:
/// %init = OpFunction %void None
/// foreach %initializer:
/// OpFunctionCall %initializer
/// OpReturn
/// OpFunctionEnd
fn initializer(self: *Module, entry_points: *Section) !Section {
    var section = Section{};
    errdefer section.deinit(self.gpa);

    // const void_ty_ref = try self.resolveType(Type.void, .direct);
    const void_ty_ref = try self.resolve(.void_type);
    const void_ty_id = self.resultId(void_ty_ref);
    const init_proto_ty_ref = try self.resolve(.{ .function_type = .{
        .return_type = void_ty_ref,
        .parameters = &.{},
    } });

    const init_id = self.allocId();
    try section.emit(self.gpa, .OpFunction, .{
        .id_result_type = void_ty_id,
        .id_result = init_id,
        .function_control = .{},
        .function_type = self.resultId(init_proto_ty_ref),
    });
    try section.emit(self.gpa, .OpLabel, .{
        .id_result = self.allocId(),
    });

    var seen = try std.DynamicBitSetUnmanaged.initEmpty(self.gpa, self.decls.items.len);
    defer seen.deinit(self.gpa);

    var interface = std.ArrayList(IdRef).init(self.gpa);
    defer interface.deinit();

    for (self.globals.globals.keys(), self.globals.globals.values()) |decl_index, global| {
        try self.addEntryPointDeps(decl_index, &seen, &interface);
        if (global.initializer_id) |initializer_id| {
            try section.emit(self.gpa, .OpFunctionCall, .{
                .id_result_type = void_ty_id,
                .id_result = self.allocId(),
                .function = initializer_id,
            });
        }
    }

    try section.emit(self.gpa, .OpReturn, {});
    try section.emit(self.gpa, .OpFunctionEnd, {});

    try entry_points.emit(self.gpa, .OpEntryPoint, .{
        // TODO: Rusticl does not support this because its poorly defined.
        // Do we need to generate a workaround here?
        .execution_model = .Kernel,
        .entry_point = init_id,
        .name = "zig global initializer",
        .interface = interface.items,
    });

    try self.sections.execution_modes.emit(self.gpa, .OpExecutionMode, .{
        .entry_point = init_id,
        .mode = .Initializer,
    });

    return section;
}

/// Emit this module as a spir-v binary.
pub fn flush(self: *Module, file: std.fs.File, target: std.Target) !void {
    // See SPIR-V Spec section 2.3, "Physical Layout of a SPIR-V Module and Instruction"

    // TODO: Perform topological sort on the globals.
    var globals = try self.orderGlobals();
    defer globals.deinit(self.gpa);

    var entry_points = try self.entryPoints();
    defer entry_points.deinit(self.gpa);

    var types_constants = try self.cache.materialize(self);
    defer types_constants.deinit(self.gpa);

    // // TODO: Pass global variables as function parameters
    // var init_func = if (target.os.tag != .vulkan)
    //     try self.initializer(&entry_points)
    // else
    //     Section{};
    // defer init_func.deinit(self.gpa);

    const header = [_]Word{
        spec.magic_number,
        // TODO: From cpu features
        spec.Version.toWord(.{
            .major = 1,
            .minor = switch (target.os.tag) {
                // Emit SPIR-V 1.3 for now. This is the highest version that Vulkan 1.1 supports.
                .vulkan => 3,
                // Emit SPIR-V 1.4 for now. This is the highest version that Intel's CPU OpenCL supports.
                else => 4,
            },
        }),
        0, // TODO: Register Zig compiler magic number.
        self.idBound(),
        0, // Schema (currently reserved for future use)
    };

    var source = Section{};
    defer source.deinit(self.gpa);
    try self.sections.debug_strings.emit(self.gpa, .OpSource, .{
        .source_language = .Unknown,
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
        types_constants.toWords(),
        self.sections.types_globals_constants.toWords(),
        globals.toWords(),
        self.sections.functions.toWords(),
    };

    if (builtin.zig_backend == .stage2_x86_64) {
        for (buffers) |buf| {
            try file.writeAll(std.mem.sliceAsBytes(buf));
        }
    } else {
        // miscompiles with x86_64 backend
        var iovc_buffers: [buffers.len]std.os.iovec_const = undefined;
        var file_size: u64 = 0;
        for (&iovc_buffers, 0..) |*iovc, i| {
            // Note, since spir-v supports both little and big endian we can ignore byte order here and
            // just treat the words as a sequence of bytes.
            const bytes = std.mem.sliceAsBytes(buffers[i]);
            iovc.* = .{ .iov_base = bytes.ptr, .iov_len = bytes.len };
            file_size += bytes.len;
        }

        try file.seekTo(0);
        try file.setEndPos(file_size);
        try file.pwritevAll(&iovc_buffers, 0);
    }
}

/// Merge the sections making up a function declaration into this module.
pub fn addFunction(self: *Module, decl_index: Decl.Index, func: Fn) !void {
    try self.sections.functions.append(self.gpa, func.prologue);
    try self.sections.functions.append(self.gpa, func.body);
    try self.declareDeclDeps(decl_index, func.decl_deps.keys());
}

pub const ExtendedInstructionSet = enum {
    glsl,
    opencl,
};

/// Imports or returns the existing id of an extended instruction set
pub fn importInstructionSet(self: *Module, set: ExtendedInstructionSet) !IdRef {
    const gop = try self.extended_instruction_set.getOrPut(self.gpa, set);
    if (gop.found_existing) return gop.value_ptr.*;

    const result_id = self.allocId();
    try self.sections.extended_instruction_set.emit(self.gpa, .OpExtInstImport, .{
        .id_result = result_id,
        .name = switch (set) {
            .glsl => "GLSL.std.450",
            .opencl => "OpenCL.std",
        },
    });
    gop.value_ptr.* = result_id;

    return result_id;
}

/// Fetch the result-id of an OpString instruction that encodes the path of the source
/// file of the decl. This function may also emit an OpSource with source-level information regarding
/// the decl.
pub fn resolveSourceFileName(self: *Module, path: []const u8) !IdRef {
    const path_ref = try self.resolveString(path);
    const result = try self.source_file_names.getOrPut(self.gpa, path_ref);
    if (!result.found_existing) {
        const file_result_id = self.allocId();
        result.value_ptr.* = file_result_id;
        try self.sections.debug_strings.emit(self.gpa, .OpString, .{
            .id_result = file_result_id,
            .string = path,
        });
    }

    return result.value_ptr.*;
}

pub fn intType(self: *Module, signedness: std.builtin.Signedness, bits: u16) !CacheRef {
    return try self.resolve(.{ .int_type = .{
        .signedness = signedness,
        .bits = bits,
    } });
}

pub fn vectorType(self: *Module, len: u32, elem_ty_ref: CacheRef) !CacheRef {
    return try self.resolve(.{ .vector_type = .{
        .component_type = elem_ty_ref,
        .component_count = len,
    } });
}

pub fn arrayType(self: *Module, len: u32, elem_ty_ref: CacheRef) !CacheRef {
    const len_ty_ref = try self.resolve(.{ .int_type = .{
        .signedness = .unsigned,
        .bits = 32,
    } });
    const len_ref = try self.resolve(.{ .int = .{
        .ty = len_ty_ref,
        .value = .{ .uint64 = len },
    } });
    return try self.resolve(.{ .array_type = .{
        .element_type = elem_ty_ref,
        .length = len_ref,
    } });
}

pub fn constInt(self: *Module, ty_ref: CacheRef, value: anytype) !IdRef {
    const ty = self.cache.lookup(ty_ref).int_type;
    const Value = Cache.Key.Int.Value;
    return try self.resolveId(.{ .int = .{
        .ty = ty_ref,
        .value = switch (ty.signedness) {
            .signed => Value{ .int64 = @as(i64, @intCast(value)) },
            .unsigned => Value{ .uint64 = @as(u64, @intCast(value)) },
        },
    } });
}

pub fn constUndef(self: *Module, ty_ref: CacheRef) !IdRef {
    return try self.resolveId(.{ .undef = .{ .ty = ty_ref } });
}

pub fn constNull(self: *Module, ty_ref: CacheRef) !IdRef {
    return try self.resolveId(.{ .null = .{ .ty = ty_ref } });
}

pub fn constBool(self: *Module, ty_ref: CacheRef, value: bool) !IdRef {
    return try self.resolveId(.{ .bool = .{ .ty = ty_ref, .value = value } });
}

pub fn constComposite(self: *Module, ty_ref: CacheRef, members: []const IdRef) !IdRef {
    const result_id = self.allocId();
    try self.sections.types_globals_constants.emit(self.gpa, .OpSpecConstantComposite, .{
        .id_result_type = self.resultId(ty_ref),
        .id_result = result_id,
        .constituents = members,
    });
    return result_id;
}

/// Decorate a result-id.
pub fn decorate(
    self: *Module,
    target: IdRef,
    decoration: spec.Decoration.Extended,
) !void {
    try self.sections.annotations.emit(self.gpa, .OpDecorate, .{
        .target = target,
        .decoration = decoration,
    });
}

/// Decorate a result-id which is a member of some struct.
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

pub const DeclKind = enum {
    func,
    global,
};

pub fn allocDecl(self: *Module, kind: DeclKind) !Decl.Index {
    try self.decls.append(self.gpa, .{
        .result_id = self.allocId(),
        .begin_dep = undefined,
        .end_dep = undefined,
    });
    const index = @as(Decl.Index, @enumFromInt(@as(u32, @intCast(self.decls.items.len - 1))));
    switch (kind) {
        .func => {},
        // If the decl represents a global, also allocate a global node.
        .global => try self.globals.globals.putNoClobber(self.gpa, index, .{
            .result_id = undefined,
            .begin_inst = undefined,
            .end_inst = undefined,
            .initializer_id = undefined,
        }),
    }

    return index;
}

pub fn declPtr(self: *Module, index: Decl.Index) *Decl {
    return &self.decls.items[@intFromEnum(index)];
}

pub fn globalPtr(self: *Module, index: Decl.Index) ?*Global {
    return self.globals.globals.getPtr(index);
}

/// Declare ALL dependencies for a decl.
pub fn declareDeclDeps(self: *Module, decl_index: Decl.Index, deps: []const Decl.Index) !void {
    const begin_dep = @as(u32, @intCast(self.decl_deps.items.len));
    try self.decl_deps.appendSlice(self.gpa, deps);
    const end_dep = @as(u32, @intCast(self.decl_deps.items.len));

    const decl = self.declPtr(decl_index);
    decl.begin_dep = begin_dep;
    decl.end_dep = end_dep;
}

pub fn beginGlobal(self: *Module) u32 {
    return @as(u32, @intCast(self.globals.section.instructions.items.len));
}

pub fn endGlobal(
    self: *Module,
    global_index: Decl.Index,
    begin_inst: u32,
    result_id: IdRef,
    initializer_id: ?IdRef,
) void {
    const global = self.globalPtr(global_index).?;
    global.* = .{
        .result_id = result_id,
        .begin_inst = begin_inst,
        .end_inst = @intCast(self.globals.section.instructions.items.len),
        .initializer_id = initializer_id,
    };
}

pub fn declareEntryPoint(
    self: *Module,
    decl_index: Decl.Index,
    name: []const u8,
    execution_model: spec.ExecutionModel,
) !void {
    try self.entry_points.append(self.gpa, .{
        .decl_index = decl_index,
        .name = try self.resolveString(name),
        .execution_model = execution_model,
    });
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
