//! NVidia PTX (Paralle Thread Execution)
//! https://docs.nvidia.com/cuda/parallel-thread-execution/index.html
//! For this we rely on the nvptx backend of LLVM
//! Kernel functions need to be marked both as "export" and "callconv(.PtxKernel)"

const NvPtx = @This();

const std = @import("std");
const builtin = @import("builtin");

const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const log = std.log.scoped(.link);

const Module = @import("../Module.zig");
const Compilation = @import("../Compilation.zig");
const link = @import("../link.zig");
const trace = @import("../tracy.zig").trace;
const build_options = @import("build_options");
const Air = @import("../Air.zig");
const Liveness = @import("../Liveness.zig");
const LlvmObject = @import("../codegen/llvm.zig").Object;

base: link.File,
llvm_object: *LlvmObject,

pub fn createEmpty(gpa: Allocator, options: link.Options) !*NvPtx {
    if (!build_options.have_llvm) return error.PtxArchNotSupported;
    if (!options.use_llvm) return error.PtxArchNotSupported;

    switch (options.target.cpu.arch) {
        .nvptx, .nvptx64 => {},
        else => return error.PtxArchNotSupported,
    }

    switch (options.target.os.tag) {
        // TODO: does it also work with nvcl ?
        .cuda => {},
        else => return error.PtxArchNotSupported,
    }

    const llvm_object = try LlvmObject.create(gpa, options);
    const nvptx = try gpa.create(NvPtx);
    nvptx.* = .{
        .base = .{
            .tag = .nvptx,
            .options = options,
            .file = null,
            .allocator = gpa,
        },
        .llvm_object = llvm_object,
    };

    return nvptx;
}

pub fn openPath(allocator: Allocator, sub_path: []const u8, options: link.Options) !*NvPtx {
    if (!build_options.have_llvm) @panic("nvptx target requires a zig compiler with llvm enabled.");
    if (!options.use_llvm) return error.PtxArchNotSupported;
    assert(options.object_format == .nvptx);

    const nvptx = try createEmpty(allocator, options);
    log.info("Opening .ptx target file {s}", .{sub_path});
    return nvptx;
}

pub fn deinit(self: *NvPtx) void {
    if (!build_options.have_llvm) return;
    self.llvm_object.destroy(self.base.allocator);
}

pub fn updateFunc(self: *NvPtx, module: *Module, func: *Module.Fn, air: Air, liveness: Liveness) !void {
    if (!build_options.have_llvm) return;
    try self.llvm_object.updateFunc(module, func, air, liveness);
}

pub fn updateDecl(self: *NvPtx, module: *Module, decl_index: Module.Decl.Index) !void {
    if (!build_options.have_llvm) return;
    return self.llvm_object.updateDecl(module, decl_index);
}

pub fn updateDeclExports(
    self: *NvPtx,
    module: *Module,
    decl_index: Module.Decl.Index,
    exports: []const *Module.Export,
) !void {
    if (!build_options.have_llvm) return;
    if (build_options.skip_non_native and builtin.object_format != .nvptx) {
        @panic("Attempted to compile for object format that was disabled by build configuration");
    }
    return self.llvm_object.updateDeclExports(module, decl_index, exports);
}

pub fn freeDecl(self: *NvPtx, decl_index: Module.Decl.Index) void {
    if (!build_options.have_llvm) return;
    return self.llvm_object.freeDecl(decl_index);
}

pub fn flush(self: *NvPtx, comp: *Compilation, prog_node: *std.Progress.Node) !void {
    return self.flushModule(comp, prog_node);
}

pub fn flushModule(self: *NvPtx, comp: *Compilation, prog_node: *std.Progress.Node) !void {
    if (!build_options.have_llvm) return;
    if (build_options.skip_non_native) {
        @panic("Attempted to compile for architecture that was disabled by build configuration");
    }
    const tracy = trace(@src());
    defer tracy.end();

    var hack_comp = comp;
    if (comp.bin_file.options.emit) |emit| {
        hack_comp.emit_asm = .{
            .directory = emit.directory,
            .basename = comp.bin_file.intermediary_basename.?,
        };
        hack_comp.bin_file.options.emit = null;
    }
    return try self.llvm_object.flushModule(hack_comp, prog_node);
}
