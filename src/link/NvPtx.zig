//! NVidia PTX (Parallel Thread Execution)
//! https://docs.nvidia.com/cuda/parallel-thread-execution/index.html
//! For this we rely on the nvptx backend of LLVM
//! Kernel functions need to be marked both as "export" and "callconv(.Kernel)"

const NvPtx = @This();

const std = @import("std");
const builtin = @import("builtin");

const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const log = std.log.scoped(.link);

const Module = @import("../Module.zig");
const InternPool = @import("../InternPool.zig");
const Compilation = @import("../Compilation.zig");
const link = @import("../link.zig");
const trace = @import("../tracy.zig").trace;
const build_options = @import("build_options");
const Air = @import("../Air.zig");
const Liveness = @import("../Liveness.zig");
const LlvmObject = @import("../codegen/llvm.zig").Object;

base: link.File,
llvm_object: *LlvmObject,

pub fn createEmpty(arena: Allocator, options: link.File.OpenOptions) !*NvPtx {
    if (build_options.only_c) unreachable;

    const target = options.comp.root_mod.resolved_target.result;
    const use_lld = build_options.have_llvm and options.comp.config.use_lld;
    const use_llvm = options.comp.config.use_llvm;

    assert(use_llvm); // Caught by Compilation.Config.resolve.
    assert(!use_lld); // Caught by Compilation.Config.resolve.
    assert(target.cpu.arch.isNvptx()); // Caught by Compilation.Config.resolve.

    switch (target.os.tag) {
        // TODO: does it also work with nvcl ?
        .cuda => {},
        else => return error.PtxArchNotSupported,
    }

    const llvm_object = try LlvmObject.create(arena, options);
    const nvptx = try arena.create(NvPtx);
    nvptx.* = .{
        .base = .{
            .tag = .nvptx,
            .comp = options.comp,
            .emit = options.emit,
            .gc_sections = options.gc_sections orelse false,
            .stack_size = options.stack_size orelse 0,
            .allow_shlib_undefined = options.allow_shlib_undefined orelse false,
            .file = null,
            .disable_lld_caching = options.disable_lld_caching,
            .build_id = options.build_id,
            .rpath_list = options.rpath_list,
            .force_undefined_symbols = options.force_undefined_symbols,
            .debug_format = options.debug_format orelse .{ .dwarf = .@"32" },
            .function_sections = options.function_sections,
            .data_sections = options.data_sections,
        },
        .llvm_object = llvm_object,
    };

    return nvptx;
}

pub fn open(arena: Allocator, options: link.File.OpenOptions) !*NvPtx {
    const target = options.comp.root_mod.resolved_target.result;
    assert(target.ofmt == .nvptx);
    return createEmpty(arena, options);
}

pub fn deinit(self: *NvPtx) void {
    self.llvm_object.deinit();
}

pub fn updateFunc(self: *NvPtx, module: *Module, func_index: InternPool.Index, air: Air, liveness: Liveness) !void {
    try self.llvm_object.updateFunc(module, func_index, air, liveness);
}

pub fn updateDecl(self: *NvPtx, module: *Module, decl_index: InternPool.DeclIndex) !void {
    return self.llvm_object.updateDecl(module, decl_index);
}

pub fn updateExports(
    self: *NvPtx,
    module: *Module,
    exported: Module.Exported,
    exports: []const *Module.Export,
) !void {
    if (build_options.skip_non_native and builtin.object_format != .nvptx) {
        @panic("Attempted to compile for object format that was disabled by build configuration");
    }
    return self.llvm_object.updateExports(module, exported, exports);
}

pub fn freeDecl(self: *NvPtx, decl_index: InternPool.DeclIndex) void {
    return self.llvm_object.freeDecl(decl_index);
}

pub fn flush(self: *NvPtx, comp: *Compilation, prog_node: *std.Progress.Node) link.File.FlushError!void {
    return self.flushModule(comp, prog_node);
}

pub fn flushModule(self: *NvPtx, comp: *Compilation, prog_node: *std.Progress.Node) link.File.FlushError!void {
    if (build_options.skip_non_native) {
        @panic("Attempted to compile for architecture that was disabled by build configuration");
    }
    const outfile = comp.bin_file.options.emit orelse return;

    const tracy = trace(@src());
    defer tracy.end();

    // We modify 'comp' before passing it to LLVM, but restore value afterwards.
    // We tell LLVM to not try to build a .o, only an "assembly" file.
    // This is required by the LLVM PTX backend.
    comp.bin_file.options.emit = null;
    comp.emit_asm = .{
        // 'null' means using the default cache dir: zig-cache/o/...
        .directory = null,
        .basename = self.base.emit.sub_path,
    };
    defer {
        comp.bin_file.options.emit = outfile;
        comp.emit_asm = null;
    }

    try self.llvm_object.flushModule(comp, prog_node);
}
