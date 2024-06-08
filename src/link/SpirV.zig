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
const assert = std.debug.assert;
const log = std.log.scoped(.link);

const Module = @import("../Module.zig");
const InternPool = @import("../InternPool.zig");
const Compilation = @import("../Compilation.zig");
const link = @import("../link.zig");
const codegen = @import("../codegen/spirv.zig");
const trace = @import("../tracy.zig").trace;
const build_options = @import("build_options");
const Air = @import("../Air.zig");
const Liveness = @import("../Liveness.zig");
const Value = @import("../Value.zig");

const SpvModule = @import("../codegen/spirv/Module.zig");
const Section = @import("../codegen/spirv/Section.zig");
const spec = @import("../codegen/spirv/spec.zig");
const IdResult = spec.IdResult;
const Word = spec.Word;

const BinaryModule = @import("SpirV/BinaryModule.zig");

base: link.File,

object: codegen.Object,

pub const base_tag: link.File.Tag = .spirv;

pub fn createEmpty(
    arena: Allocator,
    comp: *Compilation,
    emit: Compilation.Emit,
    options: link.File.OpenOptions,
) !*SpirV {
    const gpa = comp.gpa;
    const target = comp.root_mod.resolved_target.result;

    const self = try arena.create(SpirV);
    self.* = .{
        .base = .{
            .tag = .spirv,
            .comp = comp,
            .emit = emit,
            .gc_sections = options.gc_sections orelse false,
            .print_gc_sections = options.print_gc_sections,
            .stack_size = options.stack_size orelse 0,
            .allow_shlib_undefined = options.allow_shlib_undefined orelse false,
            .file = null,
            .disable_lld_caching = options.disable_lld_caching,
            .build_id = options.build_id,
            .rpath_list = options.rpath_list,
        },
        .object = codegen.Object.init(gpa),
    };
    errdefer self.deinit();

    switch (target.cpu.arch) {
        .spirv32, .spirv64 => {},
        else => unreachable, // Caught by Compilation.Config.resolve.
    }

    switch (target.os.tag) {
        .opencl, .glsl450, .vulkan => {},
        else => unreachable, // Caught by Compilation.Config.resolve.
    }

    return self;
}

pub fn open(
    arena: Allocator,
    comp: *Compilation,
    emit: Compilation.Emit,
    options: link.File.OpenOptions,
) !*SpirV {
    const target = comp.root_mod.resolved_target.result;
    const use_lld = build_options.have_llvm and comp.config.use_lld;
    const use_llvm = comp.config.use_llvm;

    assert(!use_llvm); // Caught by Compilation.Config.resolve.
    assert(!use_lld); // Caught by Compilation.Config.resolve.
    assert(target.ofmt == .spirv); // Caught by Compilation.Config.resolve.

    const spirv = try createEmpty(arena, comp, emit, options);
    errdefer spirv.base.destroy();

    // TODO: read the file and keep valid parts instead of truncating
    const file = try emit.directory.handle.createFile(emit.sub_path, .{
        .truncate = true,
        .read = true,
    });
    spirv.base.file = file;
    return spirv;
}

pub fn deinit(self: *SpirV) void {
    self.object.deinit();
}

pub fn updateFunc(self: *SpirV, module: *Module, func_index: InternPool.Index, air: Air, liveness: Liveness) !void {
    if (build_options.skip_non_native) {
        @panic("Attempted to compile for architecture that was disabled by build configuration");
    }

    const func = module.funcInfo(func_index);
    const decl = module.declPtr(func.owner_decl);
    log.debug("lowering function {}", .{decl.name.fmt(&module.intern_pool)});

    try self.object.updateFunc(module, func_index, air, liveness);
}

pub fn updateDecl(self: *SpirV, module: *Module, decl_index: InternPool.DeclIndex) !void {
    if (build_options.skip_non_native) {
        @panic("Attempted to compile for architecture that was disabled by build configuration");
    }

    const decl = module.declPtr(decl_index);
    log.debug("lowering declaration {}", .{decl.name.fmt(&module.intern_pool)});

    try self.object.updateDecl(module, decl_index);
}

pub fn updateExports(
    self: *SpirV,
    mod: *Module,
    exported: Module.Exported,
    exports: []const *Module.Export,
) !void {
    const decl_index = switch (exported) {
        .decl_index => |i| i,
        .value => |val| {
            _ = val;
            @panic("TODO: implement SpirV linker code for exporting a constant value");
        },
    };
    const decl = mod.declPtr(decl_index);
    if (decl.val.isFuncBody(mod)) {
        const target = mod.getTarget();
        const spv_decl_index = try self.object.resolveDecl(mod, decl_index);
        const execution_model = switch (decl.typeOf(mod).fnCallingConvention(mod)) {
            .Vertex => spec.ExecutionModel.Vertex,
            .Fragment => spec.ExecutionModel.Fragment,
            .Kernel => spec.ExecutionModel.Kernel,
            .C => return, // TODO: What to do here?
            else => unreachable,
        };
        const is_vulkan = target.os.tag == .vulkan;

        if ((!is_vulkan and execution_model == .Kernel) or
            (is_vulkan and (execution_model == .Fragment or execution_model == .Vertex)))
        {
            for (exports) |exp| {
                try self.object.spv.declareEntryPoint(
                    spv_decl_index,
                    exp.opts.name.toSlice(&mod.intern_pool),
                    execution_model,
                );
            }
        }
    }

    // TODO: Export regular functions, variables, etc using Linkage attributes.
}

pub fn freeDecl(self: *SpirV, decl_index: InternPool.DeclIndex) void {
    _ = self;
    _ = decl_index;
}

pub fn flush(self: *SpirV, arena: Allocator, prog_node: std.Progress.Node) link.File.FlushError!void {
    return self.flushModule(arena, prog_node);
}

pub fn flushModule(self: *SpirV, arena: Allocator, prog_node: std.Progress.Node) link.File.FlushError!void {
    if (build_options.skip_non_native) {
        @panic("Attempted to compile for architecture that was disabled by build configuration");
    }

    const tracy = trace(@src());
    defer tracy.end();

    const sub_prog_node = prog_node.start("Flush Module", 0);
    defer sub_prog_node.end();

    const spv = &self.object.spv;

    const comp = self.base.comp;
    const gpa = comp.gpa;
    const target = comp.getTarget();

    try writeCapabilities(spv, target);
    try writeMemoryModel(spv, target);

    // We need to export the list of error names somewhere so that we can pretty-print them in the
    // executor. This is not really an important thing though, so we can just dump it in any old
    // nonsemantic instruction. For now, just put it in OpSourceExtension with a special name.

    var error_info = std.ArrayList(u8).init(self.object.gpa);
    defer error_info.deinit();

    try error_info.appendSlice("zig_errors");
    const mod = self.base.comp.module.?;
    for (mod.global_error_set.keys()) |name| {
        // Errors can contain pretty much any character - to encode them in a string we must escape
        // them somehow. Easiest here is to use some established scheme, one which also preseves the
        // name if it contains no strange characters is nice for debugging. URI encoding fits the bill.
        // We're using : as separator, which is a reserved character.

        try std.Uri.Component.percentEncode(
            error_info.writer(),
            name.toSlice(&mod.intern_pool),
            struct {
                fn isValidChar(c: u8) bool {
                    return switch (c) {
                        0, '%', ':' => false,
                        else => true,
                    };
                }
            }.isValidChar,
        );
    }
    try spv.sections.debug_strings.emit(gpa, .OpSourceExtension, .{
        .extension = error_info.items,
    });

    const module = try spv.finalize(arena, target);
    errdefer arena.free(module);

    const linked_module = self.linkModule(arena, module, sub_prog_node) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => |other| {
            log.err("error while linking: {s}\n", .{@errorName(other)});
            return error.FlushFailure;
        },
    };

    try self.base.file.?.writeAll(std.mem.sliceAsBytes(linked_module));
}

fn linkModule(self: *SpirV, a: Allocator, module: []Word, progress: std.Progress.Node) ![]Word {
    _ = self;

    const lower_invocation_globals = @import("SpirV/lower_invocation_globals.zig");
    const prune_unused = @import("SpirV/prune_unused.zig");
    const dedup = @import("SpirV/deduplicate.zig");

    var parser = try BinaryModule.Parser.init(a);
    defer parser.deinit();
    var binary = try parser.parse(module);

    try lower_invocation_globals.run(&parser, &binary, progress);
    try prune_unused.run(&parser, &binary, progress);
    try dedup.run(&parser, &binary, progress);

    return binary.finalize(a);
}

fn writeCapabilities(spv: *SpvModule, target: std.Target) !void {
    const gpa = spv.gpa;
    // TODO: Integrate with a hypothetical feature system
    const caps: []const spec.Capability = switch (target.os.tag) {
        .opencl => &.{ .Kernel, .Addresses, .Int8, .Int16, .Int64, .Float64, .Float16, .Vector16, .GenericPointer },
        .glsl450 => &.{.Shader},
        .vulkan => &.{ .Shader, .VariablePointersStorageBuffer, .Int8, .Int16, .Int64, .Float64, .Float16 },
        else => unreachable, // TODO
    };

    for (caps) |cap| {
        try spv.sections.capabilities.emit(gpa, .OpCapability, .{
            .capability = cap,
        });
    }
}

fn writeMemoryModel(spv: *SpvModule, target: std.Target) !void {
    const gpa = spv.gpa;

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

    try spv.sections.memory_model.emit(gpa, .OpMemoryModel, .{
        .addressing_model = addressing_model,
        .memory_model = memory_model,
    });
}
