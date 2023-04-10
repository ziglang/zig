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

base: link.File,

spv: SpvModule,
spv_arena: ArenaAllocator,
decl_link: codegen.DeclLinkMap,

pub fn createEmpty(gpa: Allocator, options: link.Options) !*SpirV {
    const self = try gpa.create(SpirV);
    self.* = .{
        .base = .{
            .tag = .spirv,
            .options = options,
            .file = null,
            .allocator = gpa,
        },
        .spv = undefined,
        .spv_arena = ArenaAllocator.init(gpa),
        .decl_link = codegen.DeclLinkMap.init(self.base.allocator),
    };
    self.spv = SpvModule.init(gpa, self.spv_arena.allocator());
    errdefer self.deinit();

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

    return self;
}

pub fn openPath(allocator: Allocator, sub_path: []const u8, options: link.Options) !*SpirV {
    assert(options.target.ofmt == .spirv);

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
    self.spv.deinit();
    self.spv_arena.deinit();
    self.decl_link.deinit();
}

pub fn updateFunc(self: *SpirV, module: *Module, func: *Module.Fn, air: Air, liveness: Liveness) !void {
    if (build_options.skip_non_native) {
        @panic("Attempted to compile for architecture that was disabled by build configuration");
    }

    var decl_gen = codegen.DeclGen.init(self.base.allocator, module, &self.spv, &self.decl_link);
    defer decl_gen.deinit();

    if (try decl_gen.gen(func.owner_decl, air, liveness)) |msg| {
        try module.failed_decls.put(module.gpa, func.owner_decl, msg);
    }
}

pub fn updateDecl(self: *SpirV, module: *Module, decl_index: Module.Decl.Index) !void {
    if (build_options.skip_non_native) {
        @panic("Attempted to compile for architecture that was disabled by build configuration");
    }

    var decl_gen = codegen.DeclGen.init(self.base.allocator, module, &self.spv, &self.decl_link);
    defer decl_gen.deinit();

    if (try decl_gen.gen(decl_index, undefined, undefined)) |msg| {
        try module.failed_decls.put(module.gpa, decl_index, msg);
    }
}

pub fn updateDeclExports(
    self: *SpirV,
    module: *Module,
    decl_index: Module.Decl.Index,
    exports: []const *Module.Export,
) !void {
    const decl = module.declPtr(decl_index);
    if (decl.val.tag() == .function and decl.ty.fnCallingConvention() == .Kernel) {
        // TODO: Unify with resolveDecl in spirv.zig.
        const entry = try self.decl_link.getOrPut(decl_index);
        if (!entry.found_existing) {
            entry.value_ptr.* = try self.spv.allocDecl(.func);
        }
        const spv_decl_index = entry.value_ptr.*;

        for (exports) |exp| {
            try self.spv.declareEntryPoint(spv_decl_index, exp.options.name);
        }
    }

    // TODO: Export regular functions, variables, etc using Linkage attributes.
}

pub fn freeDecl(self: *SpirV, decl_index: Module.Decl.Index) void {
    _ = self;
    _ = decl_index;
}

pub fn flush(self: *SpirV, comp: *Compilation, prog_node: *std.Progress.Node) link.File.FlushError!void {
    if (build_options.have_llvm and self.base.options.use_lld) {
        return error.LLD_LinkingIsTODO_ForSpirV; // TODO: LLD Doesn't support SpirV at all.
    } else {
        return self.flushModule(comp, prog_node);
    }
}

pub fn flushModule(self: *SpirV, comp: *Compilation, prog_node: *std.Progress.Node) link.File.FlushError!void {
    if (build_options.skip_non_native) {
        @panic("Attempted to compile for architecture that was disabled by build configuration");
    }

    const tracy = trace(@src());
    defer tracy.end();

    var sub_prog_node = prog_node.start("Flush Module", 0);
    sub_prog_node.activate();
    defer sub_prog_node.end();

    const target = comp.getTarget();
    try writeCapabilities(&self.spv, target);
    try writeMemoryModel(&self.spv, target);

    // We need to export the list of error names somewhere so that we can pretty-print them in the
    // executor. This is not really an important thing though, so we can just dump it in any old
    // nonsemantic instruction. For now, just put it in OpSourceExtension with a special name.

    var error_info = std.ArrayList(u8).init(self.spv.arena);
    try error_info.appendSlice("zig_errors");
    const module = self.base.options.module.?;
    for (module.error_name_list.items) |name| {
        // Errors can contain pretty much any character - to encode them in a string we must escape
        // them somehow. Easiest here is to use some established scheme, one which also preseves the
        // name if it contains no strange characters is nice for debugging. URI encoding fits the bill.
        // We're using : as separator, which is a reserved character.

        const escaped_name = try std.Uri.escapeString(self.base.allocator, name);
        defer self.base.allocator.free(escaped_name);
        try error_info.writer().print(":{s}", .{escaped_name});
    }
    try self.spv.sections.debug_strings.emit(self.spv.gpa, .OpSourceExtension, .{
        .extension = error_info.items,
    });

    try self.spv.flush(self.base.file.?);
}

fn writeCapabilities(spv: *SpvModule, target: std.Target) !void {
    // TODO: Integrate with a hypothetical feature system
    const caps: []const spec.Capability = switch (target.os.tag) {
        .opencl => &.{ .Kernel, .Addresses, .Int8, .Int16, .Int64, .GenericPointer },
        .glsl450 => &.{.Shader},
        .vulkan => &.{.Shader},
        else => unreachable, // TODO
    };

    for (caps) |cap| {
        try spv.sections.capabilities.emit(spv.gpa, .OpCapability, .{
            .capability = cap,
        });
    }
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
        .vulkan => .GLSL450,
        else => unreachable,
    };

    // TODO: Put this in a proper section.
    try spv.sections.capabilities.emit(spv.gpa, .OpMemoryModel, .{
        .addressing_model = addressing_model,
        .memory_model = memory_model,
    });
}
