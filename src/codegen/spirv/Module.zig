//! This structure represents a SPIR-V (sections) module being compiled, and keeps
//! track of all relevant information. That includes the actual instructions, the
//! current result-id bound, and data structures for querying result-id's of data
//! which needs to be persistent over different calls to Decl code generation.
//!
//! A SPIR-V binary module supports both little- and big endian layout. The layout
//! is detected by the magic word in the header. Therefore, we can ignore any byte
//! order throughout the implementation, and just use the host byte order, and make
//! this a problem for the consumer.
const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

const Zcu = @import("../../Zcu.zig");
const InternPool = @import("../../InternPool.zig");
const Section = @import("Section.zig");
const spec = @import("spec.zig");
const Word = spec.Word;
const Id = spec.Id;

const Module = @This();

gpa: Allocator,
arena: Allocator,
zcu: *Zcu,
nav_link: std.AutoHashMapUnmanaged(InternPool.Nav.Index, Decl.Index) = .empty,
uav_link: std.AutoHashMapUnmanaged(struct { InternPool.Index, spec.StorageClass }, Decl.Index) = .empty,
intern_map: std.AutoHashMapUnmanaged(struct { InternPool.Index, Repr }, Id) = .empty,
decls: std.ArrayListUnmanaged(Decl) = .empty,
decl_deps: std.ArrayListUnmanaged(Decl.Index) = .empty,
entry_points: std.AutoArrayHashMapUnmanaged(Id, EntryPoint) = .empty,
/// This map serves a dual purpose:
/// - It keeps track of pointers that are currently being emitted, so that we can tell
///   if they are recursive and need an OpTypeForwardPointer.
/// - It caches pointers by child-type. This is required because sometimes we rely on
///   ID-equality for pointers, and pointers constructed via `ptrType()` aren't interned
///   via the usual `intern_map` mechanism.
ptr_types: std.AutoHashMapUnmanaged(struct { Id, spec.StorageClass }, Id) = .{},
/// For test declarations compiled for Vulkan target, we have to add a buffer.
/// We only need to generate this once, this holds the link information related to that.
error_buffer: ?Decl.Index = null,
/// SPIR-V instructions return result-ids.
/// This variable holds the module-wide counter for these.
next_result_id: Word = 1,
/// Some types shouldn't be emitted more than one time, but cannot be caught by
/// the `intern_map` during codegen. Sometimes, IDs are compared to check if
/// types are the same, so we can't delay until the dedup pass. Therefore,
/// this is an ad-hoc structure to cache types where required.
/// According to the SPIR-V specification, section 2.8, this includes all non-aggregate
/// non-pointer types.
/// Additionally, this is used for other values which can be cached, for example,
/// built-in variables.
cache: struct {
    bool_type: ?Id = null,
    void_type: ?Id = null,
    opaque_types: std.StringHashMapUnmanaged(Id) = .empty,
    int_types: std.AutoHashMapUnmanaged(std.builtin.Type.Int, Id) = .empty,
    float_types: std.AutoHashMapUnmanaged(std.builtin.Type.Float, Id) = .empty,
    vector_types: std.AutoHashMapUnmanaged(struct { Id, u32 }, Id) = .empty,
    array_types: std.AutoHashMapUnmanaged(struct { Id, Id }, Id) = .empty,
    struct_types: std.ArrayHashMapUnmanaged(StructType, Id, StructType.HashContext, true) = .empty,
    fn_types: std.ArrayHashMapUnmanaged(FnType, Id, FnType.HashContext, true) = .empty,

    capabilities: std.AutoHashMapUnmanaged(spec.Capability, void) = .empty,
    extensions: std.StringHashMapUnmanaged(void) = .empty,
    extended_instruction_set: std.AutoHashMapUnmanaged(spec.InstructionSet, Id) = .empty,
    decorations: std.AutoHashMapUnmanaged(struct { Id, spec.Decoration }, void) = .empty,
    builtins: std.AutoHashMapUnmanaged(struct { spec.BuiltIn, spec.StorageClass }, Decl.Index) = .empty,
    strings: std.StringArrayHashMapUnmanaged(Id) = .empty,

    bool_const: [2]?Id = .{ null, null },
    constants: std.ArrayHashMapUnmanaged(Constant, Id, Constant.HashContext, true) = .empty,
} = .{},
/// Module layout, according to SPIR-V Spec section 2.4, "Logical Layout of a Module".
sections: struct {
    capabilities: Section = .{},
    extensions: Section = .{},
    extended_instruction_set: Section = .{},
    memory_model: Section = .{},
    execution_modes: Section = .{},
    debug_strings: Section = .{},
    debug_names: Section = .{},
    annotations: Section = .{},
    globals: Section = .{},
    functions: Section = .{},
} = .{},

pub const big_int_bits = 32;

/// Data can be lowered into in two basic representations: indirect, which is when
/// a type is stored in memory, and direct, which is how a type is stored when its
/// a direct SPIR-V value.
pub const Repr = enum {
    /// A SPIR-V value as it would be used in operations.
    direct,
    /// A SPIR-V value as it is stored in memory.
    indirect,
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
    result_id: Id,
    /// The offset of the first dependency of this decl in the `decl_deps` array.
    begin_dep: usize = 0,
    /// The past-end offset of the dependencies of this decl in the `decl_deps` array.
    end_dep: usize = 0,
};

/// This models a kernel entry point.
pub const EntryPoint = struct {
    /// The declaration that should be exported.
    decl_index: Decl.Index,
    /// The name of the kernel to be exported.
    name: []const u8,
    /// Calling Convention
    exec_model: spec.ExecutionModel,
    exec_mode: ?spec.ExecutionMode = null,
};

const StructType = struct {
    fields: []const Id,
    ip_index: InternPool.Index,

    const HashContext = struct {
        pub fn hash(_: @This(), ty: StructType) u32 {
            var hasher = std.hash.Wyhash.init(0);
            hasher.update(std.mem.sliceAsBytes(ty.fields));
            hasher.update(std.mem.asBytes(&ty.ip_index));
            return @truncate(hasher.final());
        }

        pub fn eql(_: @This(), a: StructType, b: StructType, _: usize) bool {
            return a.ip_index == b.ip_index and std.mem.eql(Id, a.fields, b.fields);
        }
    };
};

const FnType = struct {
    return_ty: Id,
    params: []const Id,

    const HashContext = struct {
        pub fn hash(_: @This(), ty: FnType) u32 {
            var hasher = std.hash.Wyhash.init(0);
            hasher.update(std.mem.asBytes(&ty.return_ty));
            hasher.update(std.mem.sliceAsBytes(ty.params));
            return @truncate(hasher.final());
        }

        pub fn eql(_: @This(), a: FnType, b: FnType, _: usize) bool {
            return a.return_ty == b.return_ty and
                std.mem.eql(Id, a.params, b.params);
        }
    };
};

const Constant = struct {
    ty: Id,
    value: spec.LiteralContextDependentNumber,

    const HashContext = struct {
        pub fn hash(_: @This(), value: Constant) u32 {
            const Tag = @typeInfo(spec.LiteralContextDependentNumber).@"union".tag_type.?;
            var hasher = std.hash.Wyhash.init(0);
            hasher.update(std.mem.asBytes(&value.ty));
            hasher.update(std.mem.asBytes(&@as(Tag, value.value)));
            switch (value.value) {
                inline else => |v| hasher.update(std.mem.asBytes(&v)),
            }
            return @truncate(hasher.final());
        }

        pub fn eql(_: @This(), a: Constant, b: Constant, _: usize) bool {
            if (a.ty != b.ty) return false;
            const Tag = @typeInfo(spec.LiteralContextDependentNumber).@"union".tag_type.?;
            if (@as(Tag, a.value) != @as(Tag, b.value)) return false;
            return switch (a.value) {
                inline else => |v, tag| v == @field(b.value, @tagName(tag)),
            };
        }
    };
};

pub fn deinit(module: *Module) void {
    module.nav_link.deinit(module.gpa);
    module.uav_link.deinit(module.gpa);
    module.intern_map.deinit(module.gpa);
    module.ptr_types.deinit(module.gpa);

    module.sections.capabilities.deinit(module.gpa);
    module.sections.extensions.deinit(module.gpa);
    module.sections.extended_instruction_set.deinit(module.gpa);
    module.sections.memory_model.deinit(module.gpa);
    module.sections.execution_modes.deinit(module.gpa);
    module.sections.debug_strings.deinit(module.gpa);
    module.sections.debug_names.deinit(module.gpa);
    module.sections.annotations.deinit(module.gpa);
    module.sections.globals.deinit(module.gpa);
    module.sections.functions.deinit(module.gpa);

    module.cache.opaque_types.deinit(module.gpa);
    module.cache.int_types.deinit(module.gpa);
    module.cache.float_types.deinit(module.gpa);
    module.cache.vector_types.deinit(module.gpa);
    module.cache.array_types.deinit(module.gpa);
    module.cache.struct_types.deinit(module.gpa);
    module.cache.fn_types.deinit(module.gpa);
    module.cache.capabilities.deinit(module.gpa);
    module.cache.extensions.deinit(module.gpa);
    module.cache.extended_instruction_set.deinit(module.gpa);
    module.cache.decorations.deinit(module.gpa);
    module.cache.builtins.deinit(module.gpa);
    module.cache.strings.deinit(module.gpa);

    module.cache.constants.deinit(module.gpa);

    module.decls.deinit(module.gpa);
    module.decl_deps.deinit(module.gpa);
    module.entry_points.deinit(module.gpa);

    module.* = undefined;
}

/// Fetch or allocate a result id for nav index. This function also marks the nav as alive.
/// Note: Function does not actually generate the nav, it just allocates an index.
pub fn resolveNav(module: *Module, ip: *InternPool, nav_index: InternPool.Nav.Index) !Decl.Index {
    const entry = try module.nav_link.getOrPut(module.gpa, nav_index);
    if (!entry.found_existing) {
        const nav = ip.getNav(nav_index);
        // TODO: Extern fn?
        const kind: Decl.Kind = if (ip.isFunctionType(nav.typeOf(ip)))
            .func
        else switch (nav.getAddrspace()) {
            .generic => .invocation_global,
            else => .global,
        };
        entry.value_ptr.* = try module.allocDecl(kind);
    }

    return entry.value_ptr.*;
}

pub fn allocIds(module: *Module, n: u32) spec.IdRange {
    defer module.next_result_id += n;
    return .{ .base = module.next_result_id, .len = n };
}

pub fn allocId(module: *Module) Id {
    return module.allocIds(1).at(0);
}

pub fn idBound(module: Module) Word {
    return module.next_result_id;
}

pub fn addEntryPointDeps(
    module: *Module,
    decl_index: Decl.Index,
    seen: *std.DynamicBitSetUnmanaged,
    interface: *std.ArrayList(Id),
) !void {
    const decl = module.declPtr(decl_index);
    const deps = module.decl_deps.items[decl.begin_dep..decl.end_dep];

    if (seen.isSet(@intFromEnum(decl_index))) {
        return;
    }

    seen.set(@intFromEnum(decl_index));

    if (decl.kind == .global) {
        try interface.append(decl.result_id);
    }

    for (deps) |dep| {
        try module.addEntryPointDeps(dep, seen, interface);
    }
}

fn entryPoints(module: *Module) !Section {
    const target = module.zcu.getTarget();

    var entry_points = Section{};
    errdefer entry_points.deinit(module.gpa);

    var interface = std.ArrayList(Id).init(module.gpa);
    defer interface.deinit();

    var seen = try std.DynamicBitSetUnmanaged.initEmpty(module.gpa, module.decls.items.len);
    defer seen.deinit(module.gpa);

    for (module.entry_points.keys(), module.entry_points.values()) |entry_point_id, entry_point| {
        interface.items.len = 0;
        seen.setRangeValue(.{ .start = 0, .end = module.decls.items.len }, false);

        try module.addEntryPointDeps(entry_point.decl_index, &seen, &interface);
        try entry_points.emit(module.gpa, .OpEntryPoint, .{
            .execution_model = entry_point.exec_model,
            .entry_point = entry_point_id,
            .name = entry_point.name,
            .interface = interface.items,
        });

        if (entry_point.exec_mode == null and entry_point.exec_model == .fragment) {
            switch (target.os.tag) {
                .vulkan, .opengl => |tag| {
                    try module.sections.execution_modes.emit(module.gpa, .OpExecutionMode, .{
                        .entry_point = entry_point_id,
                        .mode = if (tag == .vulkan) .origin_upper_left else .origin_lower_left,
                    });
                },
                .opencl => {},
                else => unreachable,
            }
        }
    }

    return entry_points;
}

pub fn finalize(module: *Module, gpa: Allocator) ![]Word {
    const target = module.zcu.getTarget();

    // Emit capabilities and extensions
    switch (target.os.tag) {
        .opengl => {
            try module.addCapability(.shader);
            try module.addCapability(.matrix);
        },
        .vulkan => {
            try module.addCapability(.shader);
            try module.addCapability(.matrix);
            if (target.cpu.arch == .spirv64) {
                try module.addExtension("SPV_KHR_physical_storage_buffer");
                try module.addCapability(.physical_storage_buffer_addresses);
            }
        },
        .opencl, .amdhsa => {
            try module.addCapability(.kernel);
            try module.addCapability(.addresses);
        },
        else => unreachable,
    }
    if (target.cpu.arch == .spirv64) try module.addCapability(.int64);
    if (target.cpu.has(.spirv, .int64)) try module.addCapability(.int64);
    if (target.cpu.has(.spirv, .float16)) {
        if (target.os.tag == .opencl) try module.addExtension("cl_khr_fp16");
        try module.addCapability(.float16);
    }
    if (target.cpu.has(.spirv, .float64)) try module.addCapability(.float64);
    if (target.cpu.has(.spirv, .generic_pointer)) try module.addCapability(.generic_pointer);
    if (target.cpu.has(.spirv, .vector16)) try module.addCapability(.vector16);
    if (target.cpu.has(.spirv, .storage_push_constant16)) {
        try module.addExtension("SPV_KHR_16bit_storage");
        try module.addCapability(.storage_push_constant16);
    }
    if (target.cpu.has(.spirv, .arbitrary_precision_integers)) {
        try module.addExtension("SPV_INTEL_arbitrary_precision_integers");
        try module.addCapability(.arbitrary_precision_integers_intel);
    }
    if (target.cpu.has(.spirv, .variable_pointers)) {
        try module.addExtension("SPV_KHR_variable_pointers");
        try module.addCapability(.variable_pointers_storage_buffer);
        try module.addCapability(.variable_pointers);
    }
    // These are well supported
    try module.addCapability(.int8);
    try module.addCapability(.int16);

    // Emit memory model
    const addressing_model: spec.AddressingModel = switch (target.os.tag) {
        .opengl => .logical,
        .vulkan => if (target.cpu.arch == .spirv32) .logical else .physical_storage_buffer64,
        .opencl => if (target.cpu.arch == .spirv32) .physical32 else .physical64,
        .amdhsa => .physical64,
        else => unreachable,
    };
    try module.sections.memory_model.emit(module.gpa, .OpMemoryModel, .{
        .addressing_model = addressing_model,
        .memory_model = switch (target.os.tag) {
            .opencl => .open_cl,
            .vulkan, .opengl => .glsl450,
            else => unreachable,
        },
    });

    var entry_points = try module.entryPoints();
    defer entry_points.deinit(module.gpa);

    const version: spec.Version = .{
        .major = 1,
        .minor = blk: {
            // Prefer higher versions
            if (target.cpu.has(.spirv, .v1_6)) break :blk 6;
            if (target.cpu.has(.spirv, .v1_5)) break :blk 5;
            if (target.cpu.has(.spirv, .v1_4)) break :blk 4;
            if (target.cpu.has(.spirv, .v1_3)) break :blk 3;
            if (target.cpu.has(.spirv, .v1_2)) break :blk 2;
            if (target.cpu.has(.spirv, .v1_1)) break :blk 1;
            break :blk 0;
        },
    };

    const header = [_]Word{
        spec.magic_number,
        version.toWord(),
        spec.zig_generator_id,
        module.idBound(),
        0, // Schema (currently reserved for future use)
    };

    var source = Section{};
    defer source.deinit(module.gpa);
    try module.sections.debug_strings.emit(module.gpa, .OpSource, .{
        .source_language = .zig,
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
        module.sections.capabilities.toWords(),
        module.sections.extensions.toWords(),
        module.sections.extended_instruction_set.toWords(),
        module.sections.memory_model.toWords(),
        entry_points.toWords(),
        module.sections.execution_modes.toWords(),
        source.toWords(),
        module.sections.debug_strings.toWords(),
        module.sections.debug_names.toWords(),
        module.sections.annotations.toWords(),
        module.sections.globals.toWords(),
        module.sections.functions.toWords(),
    };

    var total_result_size: usize = 0;
    for (buffers) |buffer| {
        total_result_size += buffer.len;
    }
    const result = try gpa.alloc(Word, total_result_size);
    errdefer comptime unreachable;

    var offset: usize = 0;
    for (buffers) |buffer| {
        @memcpy(result[offset..][0..buffer.len], buffer);
        offset += buffer.len;
    }

    return result;
}

pub fn addCapability(module: *Module, cap: spec.Capability) !void {
    const entry = try module.cache.capabilities.getOrPut(module.gpa, cap);
    if (entry.found_existing) return;
    try module.sections.capabilities.emit(module.gpa, .OpCapability, .{ .capability = cap });
}

pub fn addExtension(module: *Module, ext: []const u8) !void {
    const entry = try module.cache.extensions.getOrPut(module.gpa, ext);
    if (entry.found_existing) return;
    try module.sections.extensions.emit(module.gpa, .OpExtension, .{ .name = ext });
}

/// Imports or returns the existing id of an extended instruction set
pub fn importInstructionSet(module: *Module, set: spec.InstructionSet) !Id {
    assert(set != .core);

    const gop = try module.cache.extended_instruction_set.getOrPut(module.gpa, set);
    if (gop.found_existing) return gop.value_ptr.*;

    const result_id = module.allocId();
    try module.sections.extended_instruction_set.emit(module.gpa, .OpExtInstImport, .{
        .id_result = result_id,
        .name = @tagName(set),
    });
    gop.value_ptr.* = result_id;

    return result_id;
}

pub fn boolType(module: *Module) !Id {
    if (module.cache.bool_type) |id| return id;

    const result_id = module.allocId();
    try module.sections.globals.emit(module.gpa, .OpTypeBool, .{
        .id_result = result_id,
    });
    module.cache.bool_type = result_id;
    return result_id;
}

pub fn voidType(module: *Module) !Id {
    if (module.cache.void_type) |id| return id;

    const result_id = module.allocId();
    try module.sections.globals.emit(module.gpa, .OpTypeVoid, .{
        .id_result = result_id,
    });
    module.cache.void_type = result_id;
    try module.debugName(result_id, "void");
    return result_id;
}

pub fn opaqueType(module: *Module, name: []const u8) !Id {
    if (module.cache.opaque_types.get(name)) |id| return id;
    const result_id = module.allocId();
    const name_dup = try module.arena.dupe(u8, name);
    try module.sections.globals.emit(module.gpa, .OpTypeOpaque, .{
        .id_result = result_id,
        .literal_string = name_dup,
    });
    try module.debugName(result_id, name_dup);
    try module.cache.opaque_types.put(module.gpa, name_dup, result_id);
    return result_id;
}

pub fn backingIntBits(module: *Module, bits: u16) struct { u16, bool } {
    assert(bits != 0);
    const target = module.zcu.getTarget();

    if (target.cpu.has(.spirv, .arbitrary_precision_integers) and bits <= 32) {
        return .{ bits, false };
    }

    // We require Int8 and Int16 capabilities and benefit Int64 when available.
    // 32-bit integers are always supported (see spec, 2.16.1, Data rules).
    const ints = [_]struct { bits: u16, enabled: bool }{
        .{ .bits = 8, .enabled = true },
        .{ .bits = 16, .enabled = true },
        .{ .bits = 32, .enabled = true },
        .{
            .bits = 64,
            .enabled = target.cpu.has(.spirv, .int64) or target.cpu.arch == .spirv64,
        },
    };

    for (ints) |int| {
        if (bits <= int.bits and int.enabled) return .{ int.bits, false };
    }

    // Big int
    return .{ std.mem.alignForward(u16, bits, big_int_bits), true };
}

pub fn intType(module: *Module, signedness: std.builtin.Signedness, bits: u16) !Id {
    assert(bits > 0);

    const target = module.zcu.getTarget();
    const actual_signedness = switch (target.os.tag) {
        // Kernel only supports unsigned ints.
        .opencl, .amdhsa => .unsigned,
        else => signedness,
    };
    const backing_bits, const big_int = module.backingIntBits(bits);
    if (big_int) {
        // TODO: support composite integers larger than 64 bit
        assert(backing_bits <= 64);
        const u32_ty = try module.intType(.unsigned, 32);
        const len_id = try module.constant(u32_ty, .{ .uint32 = backing_bits / big_int_bits });
        return module.arrayType(len_id, u32_ty);
    }

    const entry = try module.cache.int_types.getOrPut(module.gpa, .{ .signedness = actual_signedness, .bits = backing_bits });
    if (!entry.found_existing) {
        const result_id = module.allocId();
        entry.value_ptr.* = result_id;
        try module.sections.globals.emit(module.gpa, .OpTypeInt, .{
            .id_result = result_id,
            .width = backing_bits,
            .signedness = switch (actual_signedness) {
                .signed => 1,
                .unsigned => 0,
            },
        });

        switch (actual_signedness) {
            .signed => try module.debugNameFmt(result_id, "i{}", .{backing_bits}),
            .unsigned => try module.debugNameFmt(result_id, "u{}", .{backing_bits}),
        }
    }
    return entry.value_ptr.*;
}

pub fn floatType(module: *Module, bits: u16) !Id {
    assert(bits > 0);
    const entry = try module.cache.float_types.getOrPut(module.gpa, .{ .bits = bits });
    if (!entry.found_existing) {
        const result_id = module.allocId();
        entry.value_ptr.* = result_id;
        try module.sections.globals.emit(module.gpa, .OpTypeFloat, .{
            .id_result = result_id,
            .width = bits,
        });
        try module.debugNameFmt(result_id, "f{}", .{bits});
    }
    return entry.value_ptr.*;
}

pub fn vectorType(module: *Module, len: u32, child_ty_id: Id) !Id {
    const entry = try module.cache.vector_types.getOrPut(module.gpa, .{ child_ty_id, len });
    if (!entry.found_existing) {
        const result_id = module.allocId();
        entry.value_ptr.* = result_id;
        try module.sections.globals.emit(module.gpa, .OpTypeVector, .{
            .id_result = result_id,
            .component_type = child_ty_id,
            .component_count = len,
        });
    }
    return entry.value_ptr.*;
}

pub fn arrayType(module: *Module, len_id: Id, child_ty_id: Id) !Id {
    const entry = try module.cache.array_types.getOrPut(module.gpa, .{ child_ty_id, len_id });
    if (!entry.found_existing) {
        const result_id = module.allocId();
        entry.value_ptr.* = result_id;
        try module.sections.globals.emit(module.gpa, .OpTypeArray, .{
            .id_result = result_id,
            .element_type = child_ty_id,
            .length = len_id,
        });
    }
    return entry.value_ptr.*;
}

pub fn ptrType(module: *Module, child_ty_id: Id, storage_class: spec.StorageClass) !Id {
    const key = .{ child_ty_id, storage_class };
    const gop = try module.ptr_types.getOrPut(module.gpa, key);
    if (!gop.found_existing) {
        gop.value_ptr.* = module.allocId();
        try module.sections.globals.emit(module.gpa, .OpTypePointer, .{
            .id_result = gop.value_ptr.*,
            .storage_class = storage_class,
            .type = child_ty_id,
        });
        return gop.value_ptr.*;
    }
    return gop.value_ptr.*;
}

pub fn structType(
    module: *Module,
    types: []const Id,
    maybe_names: ?[]const []const u8,
    maybe_offsets: ?[]const u32,
    ip_index: InternPool.Index,
) !Id {
    const target = module.zcu.getTarget();
    const actual_ip_index = if (module.zcu.comp.config.root_strip) .none else ip_index;

    if (module.cache.struct_types.get(.{ .fields = types, .ip_index = actual_ip_index })) |id| return id;
    const result_id = module.allocId();
    const types_dup = try module.arena.dupe(Id, types);
    try module.sections.globals.emit(module.gpa, .OpTypeStruct, .{
        .id_result = result_id,
        .id_ref = types_dup,
    });

    if (maybe_names) |names| {
        assert(names.len == types.len);
        for (names, 0..) |name, i| {
            try module.memberDebugName(result_id, @intCast(i), name);
        }
    }

    switch (target.os.tag) {
        .vulkan, .opengl => {
            if (maybe_offsets) |offsets| {
                assert(offsets.len == types.len);
                for (offsets, 0..) |offset, i| {
                    try module.decorateMember(
                        result_id,
                        @intCast(i),
                        .{ .offset = .{ .byte_offset = offset } },
                    );
                }
            }
        },
        else => {},
    }

    try module.cache.struct_types.put(
        module.gpa,
        .{ .fields = types_dup, .ip_index = actual_ip_index },
        result_id,
    );
    return result_id;
}

pub fn functionType(module: *Module, return_ty_id: Id, param_type_ids: []const Id) !Id {
    if (module.cache.fn_types.get(.{
        .return_ty = return_ty_id,
        .params = param_type_ids,
    })) |id| return id;
    const result_id = module.allocId();
    const params_dup = try module.arena.dupe(Id, param_type_ids);
    try module.sections.globals.emit(module.gpa, .OpTypeFunction, .{
        .id_result = result_id,
        .return_type = return_ty_id,
        .id_ref_2 = params_dup,
    });
    try module.cache.fn_types.put(module.gpa, .{
        .return_ty = return_ty_id,
        .params = params_dup,
    }, result_id);
    return result_id;
}

pub fn constant(module: *Module, ty_id: Id, value: spec.LiteralContextDependentNumber) !Id {
    const gop = try module.cache.constants.getOrPut(module.gpa, .{ .ty = ty_id, .value = value });
    if (!gop.found_existing) {
        gop.value_ptr.* = module.allocId();
        try module.sections.globals.emit(module.gpa, .OpConstant, .{
            .id_result_type = ty_id,
            .id_result = gop.value_ptr.*,
            .value = value,
        });
    }
    return gop.value_ptr.*;
}

pub fn constBool(module: *Module, value: bool) !Id {
    if (module.cache.bool_const[@intFromBool(value)]) |b| return b;

    const result_ty_id = try module.boolType();
    const result_id = module.allocId();
    module.cache.bool_const[@intFromBool(value)] = result_id;

    switch (value) {
        inline else => |value_ct| try module.sections.globals.emit(
            module.gpa,
            if (value_ct) .OpConstantTrue else .OpConstantFalse,
            .{
                .id_result_type = result_ty_id,
                .id_result = result_id,
            },
        ),
    }

    return result_id;
}

pub fn builtin(
    module: *Module,
    result_ty_id: Id,
    spirv_builtin: spec.BuiltIn,
    storage_class: spec.StorageClass,
) !Decl.Index {
    const gop = try module.cache.builtins.getOrPut(module.gpa, .{ spirv_builtin, storage_class });
    if (!gop.found_existing) {
        const decl_index = try module.allocDecl(.global);
        const decl = module.declPtr(decl_index);

        gop.value_ptr.* = decl_index;
        try module.sections.globals.emit(module.gpa, .OpVariable, .{
            .id_result_type = result_ty_id,
            .id_result = decl.result_id,
            .storage_class = storage_class,
        });
        try module.decorate(decl.result_id, .{ .built_in = .{ .built_in = spirv_builtin } });
    }
    return gop.value_ptr.*;
}

pub fn constUndef(module: *Module, ty_id: Id) !Id {
    const result_id = module.allocId();
    try module.sections.globals.emit(module.gpa, .OpUndef, .{
        .id_result_type = ty_id,
        .id_result = result_id,
    });
    return result_id;
}

pub fn constNull(module: *Module, ty_id: Id) !Id {
    const result_id = module.allocId();
    try module.sections.globals.emit(module.gpa, .OpConstantNull, .{
        .id_result_type = ty_id,
        .id_result = result_id,
    });
    return result_id;
}

/// Decorate a result-id.
pub fn decorate(
    module: *Module,
    target: Id,
    decoration: spec.Decoration.Extended,
) !void {
    const gop = try module.cache.decorations.getOrPut(module.gpa, .{ target, decoration });
    if (!gop.found_existing) {
        try module.sections.annotations.emit(module.gpa, .OpDecorate, .{
            .target = target,
            .decoration = decoration,
        });
    }
}

/// Decorate a result-id which is a member of some struct.
/// We really don't have to and shouldn't need to cache this.
pub fn decorateMember(
    module: *Module,
    structure_type: Id,
    member: u32,
    decoration: spec.Decoration.Extended,
) !void {
    try module.sections.annotations.emit(module.gpa, .OpMemberDecorate, .{
        .structure_type = structure_type,
        .member = member,
        .decoration = decoration,
    });
}

pub fn allocDecl(module: *Module, kind: Decl.Kind) !Decl.Index {
    try module.decls.append(module.gpa, .{
        .kind = kind,
        .result_id = module.allocId(),
    });

    return @as(Decl.Index, @enumFromInt(@as(u32, @intCast(module.decls.items.len - 1))));
}

pub fn declPtr(module: *Module, index: Decl.Index) *Decl {
    return &module.decls.items[@intFromEnum(index)];
}

/// Declare a SPIR-V function as an entry point. This causes an extra wrapper
/// function to be generated, which is then exported as the real entry point. The purpose of this
/// wrapper is to allocate and initialize the structure holding the instance globals.
pub fn declareEntryPoint(
    module: *Module,
    decl_index: Decl.Index,
    name: []const u8,
    exec_model: spec.ExecutionModel,
    exec_mode: ?spec.ExecutionMode,
) !void {
    const gop = try module.entry_points.getOrPut(module.gpa, module.declPtr(decl_index).result_id);
    gop.value_ptr.decl_index = decl_index;
    gop.value_ptr.name = name;
    gop.value_ptr.exec_model = exec_model;
    // Might've been set by assembler
    if (!gop.found_existing) gop.value_ptr.exec_mode = exec_mode;
}

pub fn debugName(module: *Module, target: Id, name: []const u8) !void {
    if (module.zcu.comp.config.root_strip) return;
    try module.sections.debug_names.emit(module.gpa, .OpName, .{
        .target = target,
        .name = name,
    });
}

pub fn debugNameFmt(module: *Module, target: Id, comptime fmt: []const u8, args: anytype) !void {
    if (module.zcu.comp.config.root_strip) return;
    const name = try std.fmt.allocPrint(module.gpa, fmt, args);
    defer module.gpa.free(name);
    try module.debugName(target, name);
}

pub fn memberDebugName(module: *Module, target: Id, member: u32, name: []const u8) !void {
    if (module.zcu.comp.config.root_strip) return;
    try module.sections.debug_names.emit(module.gpa, .OpMemberName, .{
        .type = target,
        .member = member,
        .name = name,
    });
}

pub fn debugString(module: *Module, string: []const u8) !Id {
    const entry = try module.cache.strings.getOrPut(module.gpa, string);
    if (!entry.found_existing) {
        entry.value_ptr.* = module.allocId();
        try module.sections.debug_strings.emit(module.gpa, .OpString, .{
            .id_result = entry.value_ptr.*,
            .string = string,
        });
    }
    return entry.value_ptr.*;
}

pub fn storageClass(module: *Module, as: std.builtin.AddressSpace) spec.StorageClass {
    const target = module.zcu.getTarget();
    return switch (as) {
        .generic => .function,
        .global => switch (target.os.tag) {
            .opencl, .amdhsa => .cross_workgroup,
            else => .storage_buffer,
        },
        .push_constant => .push_constant,
        .output => .output,
        .uniform => .uniform,
        .storage_buffer => .storage_buffer,
        .physical_storage_buffer => .physical_storage_buffer,
        .constant => .uniform_constant,
        .shared => .workgroup,
        .local => .function,
        .input => .input,
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
        .cog,
        .lut,
        .hub,
        => unreachable,
    };
}
