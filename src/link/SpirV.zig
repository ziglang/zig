//! SPIR-V Spec documentation: https://www.khronos.org/registry/spir-v/specs/unified1/SPIRV.html
//! According to above documentation, a SPIR-V module has the following logical layout:
//! Header.
//! OpCapability instructions.
//! OpExtension instructions.
//! OpExtInstImport instructions.
//! A single OpMemoryModel instruction.
//! All entry points, declared with OpEntryPoint instructions.
//! All execution-mode declarators; OpExecutionMode and OpExecutionModeId instructions.
//! Debug instructions:
//! - First, OpString, OpSourceExtension, OpSource, OpSourceContinued (no forward references).
//! - OpName and OpMemberName instructions.
//! - OpModuleProcessed instructions.
//! All annotation (decoration) instructions.
//! All type declaration instructions, constant instructions, global variable declarations, (preferably) OpUndef instructions.
//! All function declarations without a body (extern functions presumably).
//! All regular functions.

// Because SPIR-V requires re-compilation anyway, and so hot swapping will not work
// anyway, we simply generate all the code in flushModule. This keeps
// things considerably simpler.

const SpirV = @This();

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
const assert = std.debug.assert;
const log = std.log.scoped(.link);

const Module = @import("../Module.zig");
const Compilation = @import("../Compilation.zig");
const link = @import("../link.zig");
const codegen = @import("../codegen/spirv.zig");
const trace = @import("../tracy.zig").trace;
const build_options = @import("build_options");
const Air = @import("../Air.zig");
const Liveness = @import("../Liveness.zig");
const Value = @import("../value.zig").Value;

const SpvModule = @import("../codegen/spirv/Module.zig");
const spec = @import("../codegen/spirv/spec.zig");
const IdResult = spec.IdResult;

// TODO: Should this struct be used at all rather than just a hashmap of aux data for every decl?
pub const FnData = struct {
    // We're going to fill these in flushModule, and we're going to fill them unconditionally,
    // so just set it to undefined.
    id: IdResult = undefined,
};

base: link.File,

/// This linker backend does not try to incrementally link output SPIR-V code.
/// Instead, it tracks all declarations in this table, and iterates over it
/// in the flush function.
decl_table: std.AutoArrayHashMapUnmanaged(Module.Decl.Index, DeclGenContext) = .{},

const DeclGenContext = struct {
    air: Air,
    air_value_arena: ArenaAllocator.State,
    liveness: Liveness,

    fn deinit(self: *DeclGenContext, gpa: Allocator) void {
        self.air.deinit(gpa);
        self.liveness.deinit(gpa);
        self.air_value_arena.promote(gpa).deinit();
        self.* = undefined;
    }
};

pub fn createEmpty(gpa: Allocator, options: link.Options) !*SpirV {
    const spirv = try gpa.create(SpirV);
    spirv.* = .{
        .base = .{
            .tag = .spirv,
            .options = options,
            .file = null,
            .allocator = gpa,
        },
    };

    // TODO: Figure out where to put all of these
    switch (options.target.cpu.arch) {
        .spirv32, .spirv64 => {},
        else => return error.TODOArchNotSupported,
    }

    switch (options.target.os.tag) {
        .opencl, .glsl450, .vulkan => {},
        else => return error.TODOOsNotSupported,
    }

    if (options.target.abi != .none) {
        return error.TODOAbiNotSupported;
    }

    return spirv;
}

pub fn openPath(allocator: Allocator, sub_path: []const u8, options: link.Options) !*SpirV {
    assert(options.object_format == .spirv);

    if (options.use_llvm) return error.LLVM_BackendIsTODO_ForSpirV; // TODO: LLVM Doesn't support SpirV at all.
    if (options.use_lld) return error.LLD_LinkingIsTODO_ForSpirV; // TODO: LLD Doesn't support SpirV at all.

    const spirv = try createEmpty(allocator, options);
    errdefer spirv.base.destroy();

    // TODO: read the file and keep valid parts instead of truncating
    const file = try options.emit.?.directory.handle.createFile(sub_path, .{ .truncate = true, .read = true });
    spirv.base.file = file;
    return spirv;
}

pub fn deinit(self: *SpirV) void {
    self.decl_table.deinit(self.base.allocator);
}

pub fn updateFunc(self: *SpirV, module: *Module, func: *Module.Fn, air: Air, liveness: Liveness) !void {
    if (build_options.skip_non_native) {
        @panic("Attempted to compile for architecture that was disabled by build configuration");
    }
    _ = module;

    // Keep track of all decls so we can iterate over them on flush().
    const result = try self.decl_table.getOrPut(self.base.allocator, func.owner_decl);
    if (result.found_existing) {
        result.value_ptr.deinit(self.base.allocator);
    }

    var arena = ArenaAllocator.init(self.base.allocator);
    errdefer arena.deinit();

    var new_air = try cloneAir(air, self.base.allocator, arena.allocator());
    errdefer new_air.deinit(self.base.allocator);

    var new_liveness = try cloneLiveness(liveness, self.base.allocator);
    errdefer new_liveness.deinit(self.base.allocator);

    result.value_ptr.* = .{
        .air = new_air,
        .air_value_arena = arena.state,
        .liveness = new_liveness,
    };
}

pub fn updateDecl(self: *SpirV, module: *Module, decl_index: Module.Decl.Index) !void {
    if (build_options.skip_non_native) {
        @panic("Attempted to compile for architecture that was disabled by build configuration");
    }
    _ = module;
    // Keep track of all decls so we can iterate over them on flush().
    _ = try self.decl_table.getOrPut(self.base.allocator, decl_index);
}

pub fn updateDeclExports(
    self: *SpirV,
    module: *Module,
    decl_index: Module.Decl.Index,
    exports: []const *Module.Export,
) !void {
    _ = self;
    _ = module;
    _ = decl_index;
    _ = exports;
}

pub fn freeDecl(self: *SpirV, decl_index: Module.Decl.Index) void {
    const index = self.decl_table.getIndex(decl_index).?;
    const module = self.base.options.module.?;
    const decl = module.declPtr(decl_index);
    if (decl.val.tag() == .function) {
        self.decl_table.values()[index].deinit(self.base.allocator);
    }
    self.decl_table.swapRemoveAt(index);
}

pub fn flush(self: *SpirV, comp: *Compilation, prog_node: *std.Progress.Node) !void {
    if (build_options.have_llvm and self.base.options.use_lld) {
        return error.LLD_LinkingIsTODO_ForSpirV; // TODO: LLD Doesn't support SpirV at all.
    } else {
        return self.flushModule(comp, prog_node);
    }
}

pub fn flushModule(self: *SpirV, comp: *Compilation, prog_node: *std.Progress.Node) !void {
    if (build_options.skip_non_native) {
        @panic("Attempted to compile for architecture that was disabled by build configuration");
    }

    const tracy = trace(@src());
    defer tracy.end();

    var sub_prog_node = prog_node.start("Flush Module", 0);
    sub_prog_node.activate();
    defer sub_prog_node.end();

    const module = self.base.options.module.?;
    const target = comp.getTarget();

    var arena = std.heap.ArenaAllocator.init(self.base.allocator);
    defer arena.deinit();

    var spv = SpvModule.init(self.base.allocator, arena.allocator());
    defer spv.deinit();

    // Allocate an ID for every declaration before generating code,
    // so that we can access them before processing them.
    // TODO: We're allocating an ID unconditionally now, are there
    // declarations which don't generate a result?
    // TODO: fn_link is used here, but thats probably not the right field. It will work anyway though.
    for (self.decl_table.keys()) |decl_index| {
        const decl = module.declPtr(decl_index);
        if (decl.has_tv) {
            decl.fn_link.spirv.id = spv.allocId();
        }
    }

    // Now, actually generate the code for all declarations.
    var decl_gen = codegen.DeclGen.init(module, &spv);
    defer decl_gen.deinit();

    var it = self.decl_table.iterator();
    while (it.next()) |entry| {
        const decl_index = entry.key_ptr.*;
        const decl = module.declPtr(decl_index);
        if (!decl.has_tv) continue;

        const air = entry.value_ptr.air;
        const liveness = entry.value_ptr.liveness;

        // Note, if `decl` is not a function, air/liveness may be undefined.
        if (try decl_gen.gen(decl, air, liveness)) |msg| {
            try module.failed_decls.put(module.gpa, decl_index, msg);
            return; // TODO: Attempt to generate more decls?
        }
    }

    try writeCapabilities(&spv, target);
    try writeMemoryModel(&spv, target);

    try spv.flush(self.base.file.?);
}

fn writeCapabilities(spv: *SpvModule, target: std.Target) !void {
    // TODO: Integrate with a hypothetical feature system
    const cap: spec.Capability = switch (target.os.tag) {
        .opencl => .Kernel,
        .glsl450 => .Shader,
        .vulkan => .VulkanMemoryModel,
        else => unreachable, // TODO
    };

    try spv.sections.capabilities.emit(spv.gpa, .OpCapability, .{
        .capability = cap,
    });
}

fn writeMemoryModel(spv: *SpvModule, target: std.Target) !void {
    const addressing_model = switch (target.os.tag) {
        .opencl => switch (target.cpu.arch) {
            .spirv32 => spec.AddressingModel.Physical32,
            .spirv64 => spec.AddressingModel.Physical64,
            else => unreachable, // TODO
        },
        .glsl450, .vulkan => spec.AddressingModel.Logical,
        else => unreachable, // TODO
    };

    const memory_model: spec.MemoryModel = switch (target.os.tag) {
        .opencl => .OpenCL,
        .glsl450 => .GLSL450,
        .vulkan => .Vulkan,
        else => unreachable,
    };

    // TODO: Put this in a proper section.
    try spv.sections.capabilities.emit(spv.gpa, .OpMemoryModel, .{
        .addressing_model = addressing_model,
        .memory_model = memory_model,
    });
}

fn cloneLiveness(l: Liveness, gpa: Allocator) !Liveness {
    const tomb_bits = try gpa.dupe(usize, l.tomb_bits);
    errdefer gpa.free(tomb_bits);

    const extra = try gpa.dupe(u32, l.extra);
    errdefer gpa.free(extra);

    return Liveness{
        .tomb_bits = tomb_bits,
        .extra = extra,
        .special = try l.special.clone(gpa),
    };
}

fn cloneAir(air: Air, gpa: Allocator, value_arena: Allocator) !Air {
    const values = try gpa.alloc(Value, air.values.len);
    errdefer gpa.free(values);

    for (values) |*value, i| {
        value.* = try air.values[i].copy(value_arena);
    }

    var instructions = try air.instructions.toMultiArrayList().clone(gpa);
    errdefer instructions.deinit(gpa);

    return Air{
        .instructions = instructions.slice(),
        .extra = try gpa.dupe(u32, air.extra),
        .values = values,
    };
}
