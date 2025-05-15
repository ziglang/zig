const Spork8 = @This();
const builtin = @import("builtin");
const build_options = @import("build_options");

const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const Path = std.Build.Cache.Path;
const log = std.log.scoped(.link);

const Air = @import("../Air.zig");
const InternPool = @import("../InternPool.zig");
const Zcu = @import("../Zcu.zig");
const CodeGen = @import("../arch/spork8/CodeGen.zig");
const Mir = @import("../arch/spork8/Mir.zig");
const link = @import("../link.zig");
const Compilation = @import("../Compilation.zig");
const Liveness = @import("../Liveness.zig");
const dev = @import("../dev.zig");
const Value = @import("../Value.zig");

base: link.File,
funcs: std.AutoArrayHashMapUnmanaged(InternPool.Index, CodeGen.Function) = .empty,
/// All MIR instructions for all Zcu functions.
mir_instructions: std.MultiArrayList(Mir.Inst) = .{},
/// Corresponds to `mir_instructions`.
mir_extra: std.ArrayListUnmanaged(u32) = .empty,

pub fn open(
    arena: Allocator,
    comp: *Compilation,
    emit: Path,
    options: link.File.OpenOptions,
) !*Spork8 {
    // TODO: restore saved linker state, don't truncate the file, and
    // participate in incremental compilation.
    return createEmpty(arena, comp, emit, options);
}

pub fn createEmpty(
    arena: Allocator,
    comp: *Compilation,
    emit: Path,
    options: link.File.OpenOptions,
) !*Spork8 {
    const target = comp.root_mod.resolved_target.result;
    assert(target.ofmt == .spork8);
    assert(comp.config.output_mode == .Exe);

    const spork8 = try arena.create(Spork8);
    spork8.* = .{
        .base = .{
            .tag = .spork8,
            .comp = comp,
            .emit = emit,
            .zcu_object_sub_path = null,
            .gc_sections = options.gc_sections orelse true,
            .print_gc_sections = options.print_gc_sections,
            .stack_size = options.stack_size orelse switch (target.os.tag) {
                .freestanding => 1 * 1024 * 1024, // 1 MiB
                else => 16 * 1024 * 1024, // 16 MiB
            },
            .allow_shlib_undefined = options.allow_shlib_undefined orelse false,
            .file = null,
            .disable_lld_caching = options.disable_lld_caching,
            .build_id = options.build_id,
        },
    };
    errdefer spork8.base.destroy();

    spork8.base.file = try emit.root_dir.handle.createFile(emit.sub_path, .{
        .truncate = true,
        .read = true,
    });

    return spork8;
}

pub fn deinit(spork8: *Spork8) void {
    const gpa = spork8.base.comp.gpa;
    _ = gpa;
}

pub fn updateFunc(
    spork8: *Spork8,
    pt: Zcu.PerThread,
    func_index: InternPool.Index,
    air: Air,
    liveness: Liveness,
) !void {
    if (build_options.skip_non_native and builtin.object_format != .spork8) {
        @panic("Attempted to compile for object format that was disabled by build configuration");
    }

    dev.check(.spork8_backend);

    const zcu = pt.zcu;
    const gpa = spork8.base.comp.gpa;

    const ip = &zcu.intern_pool;
    const owner_nav = zcu.funcInfo(func_index).owner_nav;
    log.debug("updateFunc {}", .{ip.getNav(owner_nav).fqn.fmt(ip)});

    const function = try CodeGen.function(spork8, pt, func_index, air, liveness);
    try spork8.funcs.put(gpa, func_index, function);
}

// Generate code for the "Nav", storing it in memory to be later written to
// the file on flush().
pub fn updateNav(spork8: *Spork8, pt: Zcu.PerThread, nav_index: InternPool.Nav.Index) !void {
    _ = spork8;
    if (build_options.skip_non_native and builtin.object_format != .spork8) {
        @panic("Attempted to compile for object format that was disabled by build configuration");
    }
    const zcu = pt.zcu;
    const ip = &zcu.intern_pool;
    const nav = ip.getNav(nav_index);

    const nav_init, const chased_nav_index = switch (ip.indexToKey(nav.status.fully_resolved.val)) {
        .func => return, // global const which is a function alias
        .@"extern" => |ext| {
            _ = ext;
            @panic("TODO updateNav extern func");
        },
        .variable => |variable| .{ variable.init, variable.owner_nav },
        else => .{ nav.status.fully_resolved.val, nav_index },
    };
    log.debug("updateNav {} {d}", .{ nav.fqn.fmt(ip), chased_nav_index });

    if (nav_init != .none and !Value.fromInterned(nav_init).typeOf(zcu).hasRuntimeBits(zcu)) {
        return;
    }
}

pub fn updateLineNumber(spork8: *Spork8, pt: Zcu.PerThread, ti_id: InternPool.TrackedInst.Index) !void {
    _ = spork8;
    _ = pt;
    _ = ti_id;
}

pub fn deleteExport(
    spork8: *Spork8,
    exported: Zcu.Exported,
    name: InternPool.NullTerminatedString,
) void {
    const zcu = spork8.base.comp.zcu.?;
    const ip = &zcu.intern_pool;
    const name_slice = name.toSlice(ip);
    switch (exported) {
        .nav => |nav_index| {
            log.debug("deleteExport '{s}' nav={d}", .{ name_slice, @intFromEnum(nav_index) });
        },
        .uav => |uav_index| {
            log.debug("deleteExport '{s}' uav={d}", .{ name_slice, @intFromEnum(uav_index) });
        },
    }
}

pub fn updateExports(
    spork8: *Spork8,
    pt: Zcu.PerThread,
    exported: Zcu.Exported,
    export_indices: []const Zcu.Export.Index,
) !void {
    _ = spork8;
    if (build_options.skip_non_native and builtin.object_format != .spork8) {
        @panic("Attempted to compile for object format that was disabled by build configuration");
    }

    const zcu = pt.zcu;
    const ip = &zcu.intern_pool;
    for (export_indices) |export_idx| {
        const exp = export_idx.ptr(zcu);
        const name_slice = exp.opts.name.toSlice(ip);
        switch (exported) {
            .nav => |nav_index| {
                log.debug("updateExports '{s}' nav={d}", .{ name_slice, @intFromEnum(nav_index) });
            },
            .uav => |uav_index| {
                log.debug("updateExports '{s}' uav={d}", .{ name_slice, @intFromEnum(uav_index) });
            },
        }
    }
}

pub fn loadInput(spork8: *Spork8, input: link.Input) !void {
    _ = input;
    const comp = spork8.base.comp;
    const diags = &comp.link_diags;
    return diags.failParse("spork8 does not support linking files together", .{});
}

pub fn flush(
    spork8: *Spork8,
    arena: Allocator,
    tid: Zcu.PerThread.Id,
    prog_node: std.Progress.Node,
) link.File.FlushError!void {
    return spork8.flushModule(arena, tid, prog_node);
}

pub fn prelink(spork8: *Spork8, prog_node: std.Progress.Node) link.File.FlushError!void {
    const sub_prog_node = prog_node.start("Spork8 Prelink", 0);
    defer sub_prog_node.end();

    _ = spork8;
}

pub fn flushModule(
    spork8: *Spork8,
    arena: Allocator,
    tid: Zcu.PerThread.Id,
    prog_node: std.Progress.Node,
) link.File.FlushError!void {
    // The goal is to never use this because it's only needed if we need to
    // write to InternPool, but flushModule is too late to be writing to the
    // InternPool.
    _ = tid;
    const comp = spork8.base.comp;
    const diags = &comp.link_diags;

    const sub_prog_node = prog_node.start("Spork8 Flush", 0);
    defer sub_prog_node.end();

    _ = arena;

    return diags.fail("TODO implement flushModule for spork8", .{});
}
