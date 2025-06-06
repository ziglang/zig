//! Stub linker support for GOFF based on LLVM.

const Goff = @This();

const std = @import("std");
const builtin = @import("builtin");

const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const log = std.log.scoped(.link);
const Path = std.Build.Cache.Path;

const Zcu = @import("../Zcu.zig");
const InternPool = @import("../InternPool.zig");
const Compilation = @import("../Compilation.zig");
const codegen = @import("../codegen.zig");
const link = @import("../link.zig");
const trace = @import("../tracy.zig").trace;
const build_options = @import("build_options");
const Air = @import("../Air.zig");

base: link.File,

pub fn createEmpty(
    arena: Allocator,
    comp: *Compilation,
    emit: Path,
    options: link.File.OpenOptions,
) !*Goff {
    const target = comp.root_mod.resolved_target.result;
    const use_lld = build_options.have_llvm and comp.config.use_lld;
    const use_llvm = comp.config.use_llvm;

    assert(use_llvm); // Caught by Compilation.Config.resolve.
    assert(!use_lld); // Caught by Compilation.Config.resolve.
    assert(target.os.tag == .zos); // Caught by Compilation.Config.resolve.

    const goff = try arena.create(Goff);
    goff.* = .{
        .base = .{
            .tag = .goff,
            .comp = comp,
            .emit = emit,
            .zcu_object_basename = emit.sub_path,
            .gc_sections = options.gc_sections orelse false,
            .print_gc_sections = options.print_gc_sections,
            .stack_size = options.stack_size orelse 0,
            .allow_shlib_undefined = options.allow_shlib_undefined orelse false,
            .file = null,
            .build_id = options.build_id,
        },
    };

    return goff;
}

pub fn open(
    arena: Allocator,
    comp: *Compilation,
    emit: Path,
    options: link.File.OpenOptions,
) !*Goff {
    const target = comp.root_mod.resolved_target.result;
    assert(target.ofmt == .goff);
    return createEmpty(arena, comp, emit, options);
}

pub fn deinit(self: *Goff) void {
    _ = self;
}

pub fn updateFunc(
    self: *Goff,
    pt: Zcu.PerThread,
    func_index: InternPool.Index,
    mir: *const codegen.AnyMir,
    maybe_undef_air: *const Air,
) link.File.UpdateNavError!void {
    _ = self;
    _ = pt;
    _ = func_index;
    _ = mir;
    _ = maybe_undef_air;
    unreachable; // we always use llvm
}

pub fn updateNav(self: *Goff, pt: Zcu.PerThread, nav: InternPool.Nav.Index) link.File.UpdateNavError!void {
    _ = self;
    _ = pt;
    _ = nav;
    unreachable; // we always use llvm
}

pub fn updateExports(
    self: *Goff,
    pt: Zcu.PerThread,
    exported: Zcu.Exported,
    export_indices: []const Zcu.Export.Index,
) !void {
    _ = self;
    _ = pt;
    _ = exported;
    _ = export_indices;
    unreachable; // we always use llvm
}

pub fn flush(self: *Goff, arena: Allocator, tid: Zcu.PerThread.Id, prog_node: std.Progress.Node) link.File.FlushError!void {
    _ = self;
    _ = arena;
    _ = tid;
    _ = prog_node;
    unreachable; // we always use llvm
}
