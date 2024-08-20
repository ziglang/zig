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
const Path = std.Build.Cache.Path;

const Zcu = @import("../Zcu.zig");
const InternPool = @import("../InternPool.zig");
const Compilation = @import("../Compilation.zig");
const link = @import("../link.zig");
const trace = @import("../tracy.zig").trace;
const build_options = @import("build_options");
const Air = @import("../Air.zig");
const Liveness = @import("../Liveness.zig");
const LlvmObject = @import("../codegen/llvm.zig").Object;

base: link.File,
llvm_object: LlvmObject.Ptr,

pub fn createEmpty(
    arena: Allocator,
    comp: *Compilation,
    emit: Path,
    options: link.File.OpenOptions,
) !*NvPtx {
    const target = comp.root_mod.resolved_target.result;
    const use_lld = build_options.have_llvm and comp.config.use_lld;
    const use_llvm = comp.config.use_llvm;

    assert(use_llvm); // Caught by Compilation.Config.resolve.
    assert(!use_lld); // Caught by Compilation.Config.resolve.
    assert(target.cpu.arch.isNvptx()); // Caught by Compilation.Config.resolve.

    switch (target.os.tag) {
        // TODO: does it also work with nvcl ?
        .cuda => {},
        else => return error.PtxArchNotSupported,
    }

    const llvm_object = try LlvmObject.create(arena, comp);
    const nvptx = try arena.create(NvPtx);
    nvptx.* = .{
        .base = .{
            .tag = .nvptx,
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
        .llvm_object = llvm_object,
    };

    return nvptx;
}

pub fn open(
    arena: Allocator,
    comp: *Compilation,
    emit: Path,
    options: link.File.OpenOptions,
) !*NvPtx {
    const target = comp.root_mod.resolved_target.result;
    assert(target.ofmt == .nvptx);
    return createEmpty(arena, comp, emit, options);
}

pub fn deinit(self: *NvPtx) void {
    self.llvm_object.deinit();
}

pub fn updateFunc(self: *NvPtx, pt: Zcu.PerThread, func_index: InternPool.Index, air: Air, liveness: Liveness) !void {
    try self.llvm_object.updateFunc(pt, func_index, air, liveness);
}

pub fn updateNav(self: *NvPtx, pt: Zcu.PerThread, nav: InternPool.Nav.Index) !void {
    return self.llvm_object.updateNav(pt, nav);
}

pub fn updateExports(
    self: *NvPtx,
    pt: Zcu.PerThread,
    exported: Zcu.Exported,
    export_indices: []const u32,
) !void {
    if (build_options.skip_non_native and builtin.object_format != .nvptx)
        @panic("Attempted to compile for object format that was disabled by build configuration");

    return self.llvm_object.updateExports(pt, exported, export_indices);
}

pub fn freeDecl(self: *NvPtx, decl_index: InternPool.DeclIndex) void {
    return self.llvm_object.freeDecl(decl_index);
}

pub fn flush(self: *NvPtx, arena: Allocator, tid: Zcu.PerThread.Id, prog_node: std.Progress.Node) link.File.FlushError!void {
    return self.flushModule(arena, tid, prog_node);
}

pub fn flushModule(self: *NvPtx, arena: Allocator, tid: Zcu.PerThread.Id, prog_node: std.Progress.Node) link.File.FlushError!void {
    if (build_options.skip_non_native)
        @panic("Attempted to compile for architecture that was disabled by build configuration");

    // The code that was here before mutated the Compilation's file emission mechanism.
    // That's not supposed to happen in flushModule, so I deleted the code.
    _ = arena;
    _ = self;
    _ = prog_node;
    _ = tid;
    @panic("TODO: rewrite the NvPtx.flushModule function");
}
