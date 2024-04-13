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
    decl_index: Decl.Index,
    /// The name of the kernel to be exported.
    name: []const u8,
    /// Calling Convention
    execution_model: spec.ExecutionModel,
};

/// A general-purpose allocator which may be used to allocate resources for this module
gpa: Allocator,

/// Arena for things that need to live for the length of this program.
arena: std.heap.ArenaAllocator,

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
strings: std.StringArrayHashMapUnmanaged(IdRef) = .{},

/// Some types shouldn't be emitted more than one time, but cannot be caught by
/// the `intern_map` during codegen. Sometimes, IDs are compared to check if
/// types are the same, so we can't delay until the dedup pass. Therefore,
/// this is an ad-hoc structure to cache types where required.
/// According to the SPIR-V specification, section 2.8, this includes all non-aggregate
/// non-pointer types.
cache: struct {
    bool_type: ?IdRef = null,
    void_type: ?IdRef = null,
    int_types: std.AutoHashMapUnmanaged(std.builtin.Type.Int, IdRef) = .{},
    float_types: std.AutoHashMapUnmanaged(std.builtin.Type.Float, IdRef) = .{},
} = .{},

/// Set of Decls, referred to by Decl.Index.
decls: std.ArrayListUnmanaged(Decl) = .{},

/// List of dependencies, per decl. This list holds all the dependencies, sliced by the
/// begin_dep and end_dep in `self.decls`.
decl_deps: std.ArrayListUnmanaged(Decl.Index) = .{},

/// The list of entry points that should be exported from this module.
entry_points: std.ArrayListUnmanaged(EntryPoint) = .{},

/// The list of extended instruction sets that should be imported.
extended_instruction_set: std.AutoHashMapUnmanaged(spec.InstructionSet, IdRef) = .{},

pub fn init(gpa: Allocator) Module {
    return .{
        .gpa = gpa,
        .arena = std.heap.ArenaAllocator.init(gpa),
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

    self.decls.deinit(self.gpa);
    self.decl_deps.deinit(self.gpa);

    self.entry_points.deinit(self.gpa);

    self.extended_instruction_set.deinit(self.gpa);
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

    for (self.entry_points.items) |entry_point| {
        interface.items.len = 0;
        seen.setRangeValue(.{ .start = 0, .end = self.decls.items.len }, false);

        try self.addEntryPointDeps(entry_point.decl_index, &seen, &interface);

        const entry_point_id = self.declPtr(entry_point.decl_index).result_id;
        try entry_points.emit(self.gpa, .OpEntryPoint, .{
            .execution_model = entry_point.execution_model,
            .entry_point = entry_point_id,
            .name = entry_point.name,
            .interface = interface.items,
        });
    }

    return entry_points;
}

pub fn finalize(self: *Module, a: Allocator, target: std.Target) ![]Word {
    // See SPIR-V Spec section 2.3, "Physical Layout of a SPIR-V Module and Instruction"
    // TODO: Audit calls to allocId() in this function to make it idempotent.

    var entry_points = try self.entryPoints();
    defer entry_points.deinit(self.gpa);

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
        spec.zig_generator_id,
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

/// Imports or returns the existing id of an extended instruction set
pub fn importInstructionSet(self: *Module, set: spec.InstructionSet) !IdRef {
    assert(set != .core);

    const gop = try self.extended_instruction_set.getOrPut(self.gpa, set);
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

pub fn structType(self: *Module, types: []const IdRef, maybe_names: ?[]const []const u8) !IdRef {
    const result_id = self.allocId();

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

    return result_id;
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

pub fn vectorType(self: *Module, len: u32, child_id: IdRef) !IdRef {
    const result_id = self.allocId();
    try self.sections.types_globals_constants.emit(self.gpa, .OpTypeVector, .{
        .id_result = result_id,
        .component_type = child_id,
        .component_count = len,
    });
    return result_id;
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
    execution_model: spec.ExecutionModel,
) !void {
    try self.entry_points.append(self.gpa, .{
        .decl_index = decl_index,
        .name = try self.arena.allocator().dupe(u8, name),
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
