//! NVidia PTX (Paralle Thread Execution)
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
const Compilation = @import("../Compilation.zig");
const link = @import("../link.zig");
const trace = @import("../tracy.zig").trace;
const build_options = @import("build_options");
const Air = @import("../Air.zig");
const Liveness = @import("../Liveness.zig");
const LlvmObject = @import("../codegen/llvm.zig").Object;

base: link.File,
llvm_object: *LlvmObject,
ptx_file_name: []const u8,

pub fn createEmpty(gpa: Allocator, options: link.Options) !*NvPtx {
    if (!build_options.have_llvm) return error.PtxArchNotSupported;
    if (!options.use_llvm) return error.PtxArchNotSupported;

    if (!options.target.cpu.arch.isNvptx()) return error.PtxArchNotSupported;

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
        .ptx_file_name = try std.mem.join(gpa, "", &[_][]const u8{ options.root_name, ".ptx" }),
    };

    return nvptx;
}

pub fn openPath(allocator: Allocator, sub_path: []const u8, options: link.Options) !*NvPtx {
    if (!build_options.have_llvm) @panic("nvptx target requires a zig compiler with llvm enabled.");
    if (!options.use_llvm) return error.PtxArchNotSupported;
    assert(options.target.ofmt == .nvptx);

    log.debug("Opening .ptx target file {s}", .{sub_path});
    return createEmpty(allocator, options);
}

pub fn deinit(self: *NvPtx) void {
    if (!build_options.have_llvm) return;
    self.llvm_object.destroy(self.base.allocator);
    self.base.allocator.free(self.ptx_file_name);
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

pub fn flush(self: *NvPtx, comp: *Compilation, prog_node: *std.Progress.Node) link.File.FlushError!void {
    return self.flushModule(comp, prog_node);
}

pub fn flushModule(self: *NvPtx, comp: *Compilation, prog_node: *std.Progress.Node) link.File.FlushError!void {
    if (!build_options.have_llvm) return;
    if (build_options.skip_non_native) {
        @panic("Attempted to compile for architecture that was disabled by build configuration");
    }
    const tracy = trace(@src());
    defer tracy.end();

    const outfile = comp.bin_file.options.emit.?;
    // We modify 'comp' before passing it to LLVM, but restore value afterwards.
    // We tell LLVM to not try to build a .o, only an "assembly" file.
    // This is required by the LLVM PTX backend.
    comp.bin_file.options.emit = null;
    comp.emit_asm = .{
        // 'null' means using the default cache dir: zig-cache/o/...
        .directory = null,
        .basename = self.ptx_file_name,
    };
    defer {
        comp.bin_file.options.emit = outfile;
        comp.emit_asm = null;
    }

    try self.llvm_object.flushModule(comp, prog_node);
}
