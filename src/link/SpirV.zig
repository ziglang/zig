const std = @import("std");
const Allocator = std.mem.Allocator;
const Path = std.Build.Cache.Path;
const assert = std.debug.assert;
const log = std.log.scoped(.link);

const Zcu = @import("../Zcu.zig");
const InternPool = @import("../InternPool.zig");
const Compilation = @import("../Compilation.zig");
const link = @import("../link.zig");
const Air = @import("../Air.zig");
const Type = @import("../Type.zig");
const CodeGen = @import("../codegen/spirv/CodeGen.zig");
const Module = @import("../codegen/spirv/Module.zig");
const trace = @import("../tracy.zig").trace;
const BinaryModule = @import("SpirV/BinaryModule.zig");
const lower_invocation_globals = @import("SpirV/lower_invocation_globals.zig");

const spec = @import("../codegen/spirv/spec.zig");
const Id = spec.Id;
const Word = spec.Word;

const Linker = @This();

base: link.File,
module: Module,
cg: CodeGen,

pub fn createEmpty(
    arena: Allocator,
    comp: *Compilation,
    emit: Path,
    options: link.File.OpenOptions,
) !*Linker {
    const gpa = comp.gpa;
    const target = &comp.root_mod.resolved_target.result;

    assert(!comp.config.use_lld); // Caught by Compilation.Config.resolve
    assert(!comp.config.use_llvm); // Caught by Compilation.Config.resolve
    assert(target.ofmt == .spirv); // Caught by Compilation.Config.resolve
    switch (target.cpu.arch) {
        .spirv32, .spirv64 => {},
        else => unreachable, // Caught by Compilation.Config.resolve.
    }
    switch (target.os.tag) {
        .opencl, .opengl, .vulkan => {},
        else => unreachable, // Caught by Compilation.Config.resolve.
    }

    const linker = try arena.create(Linker);
    linker.* = .{
        .base = .{
            .tag = .spirv,
            .comp = comp,
            .emit = emit,
            .gc_sections = options.gc_sections orelse false,
            .print_gc_sections = options.print_gc_sections,
            .stack_size = options.stack_size orelse 0,
            .allow_shlib_undefined = options.allow_shlib_undefined orelse false,
            .file = null,
            .build_id = options.build_id,
        },
        .module = .{
            .gpa = gpa,
            .arena = arena,
            .zcu = comp.zcu.?,
        },
        .cg = .{
            // These fields are populated in generate()
            .pt = undefined,
            .air = undefined,
            .liveness = undefined,
            .owner_nav = undefined,
            .module = undefined,
            .control_flow = .{ .structured = .{} },
            .base_line = undefined,
        },
    };
    errdefer linker.deinit();

    linker.base.file = try emit.root_dir.handle.createFile(emit.sub_path, .{
        .truncate = true,
        .read = true,
    });

    return linker;
}

pub fn open(
    arena: Allocator,
    comp: *Compilation,
    emit: Path,
    options: link.File.OpenOptions,
) !*Linker {
    return createEmpty(arena, comp, emit, options);
}

pub fn deinit(linker: *Linker) void {
    linker.cg.deinit();
    linker.module.deinit();
}

fn generate(
    linker: *Linker,
    pt: Zcu.PerThread,
    nav_index: InternPool.Nav.Index,
    air: Air,
    liveness: Air.Liveness,
    do_codegen: bool,
) !void {
    const zcu = pt.zcu;
    const gpa = zcu.gpa;
    const structured_cfg = zcu.navFileScope(nav_index).mod.?.structured_cfg;

    linker.cg.control_flow.deinit(gpa);
    linker.cg.args.clearRetainingCapacity();
    linker.cg.inst_results.clearRetainingCapacity();
    linker.cg.id_scratch.clearRetainingCapacity();
    linker.cg.prologue.reset();
    linker.cg.body.reset();

    linker.cg = .{
        .pt = pt,
        .air = air,
        .liveness = liveness,
        .owner_nav = nav_index,
        .module = &linker.module,
        .control_flow = switch (structured_cfg) {
            true => .{ .structured = .{} },
            false => .{ .unstructured = .{} },
        },
        .base_line = zcu.navSrcLine(nav_index),

        .args = linker.cg.args,
        .inst_results = linker.cg.inst_results,
        .id_scratch = linker.cg.id_scratch,
        .prologue = linker.cg.prologue,
        .body = linker.cg.body,
    };

    linker.cg.genNav(do_codegen) catch |err| switch (err) {
        error.CodegenFail => switch (zcu.codegenFailMsg(nav_index, linker.cg.error_msg.?)) {
            error.CodegenFail => {},
            error.OutOfMemory => |e| return e,
        },
        else => |other| {
            // There might be an error that happened *after* linker.error_msg
            // was already allocated, so be sure to free it.
            if (linker.cg.error_msg) |error_msg| {
                error_msg.deinit(gpa);
            }

            return other;
        },
    };
}

pub fn updateFunc(
    linker: *Linker,
    pt: Zcu.PerThread,
    func_index: InternPool.Index,
    air: *const Air,
    liveness: *const ?Air.Liveness,
) !void {
    const nav = pt.zcu.funcInfo(func_index).owner_nav;
    // TODO: Separate types for generating decls and functions?
    try linker.generate(pt, nav, air.*, liveness.*.?, true);
}

pub fn updateNav(linker: *Linker, pt: Zcu.PerThread, nav: InternPool.Nav.Index) link.File.UpdateNavError!void {
    const ip = &pt.zcu.intern_pool;
    log.debug("lowering nav {f}({d})", .{ ip.getNav(nav).fqn.fmt(ip), nav });
    try linker.generate(pt, nav, undefined, undefined, false);
}

pub fn updateExports(
    linker: *Linker,
    pt: Zcu.PerThread,
    exported: Zcu.Exported,
    export_indices: []const Zcu.Export.Index,
) !void {
    const zcu = pt.zcu;
    const ip = &zcu.intern_pool;
    const nav_index = switch (exported) {
        .nav => |nav| nav,
        .uav => |uav| {
            _ = uav;
            @panic("TODO: implement Linker linker code for exporting a constant value");
        },
    };
    const nav_ty = ip.getNav(nav_index).typeOf(ip);
    const target = zcu.getTarget();
    if (ip.isFunctionType(nav_ty)) {
        const spv_decl_index = try linker.module.resolveNav(ip, nav_index);
        const cc = Type.fromInterned(nav_ty).fnCallingConvention(zcu);
        const exec_model: spec.ExecutionModel = switch (target.os.tag) {
            .vulkan, .opengl => switch (cc) {
                .spirv_vertex => .vertex,
                .spirv_fragment => .fragment,
                .spirv_kernel => .gl_compute,
                // TODO: We should integrate with the Linkage capability and export this function
                .spirv_device => return,
                else => unreachable,
            },
            .opencl => switch (cc) {
                .spirv_kernel => .kernel,
                // TODO: We should integrate with the Linkage capability and export this function
                .spirv_device => return,
                else => unreachable,
            },
            else => unreachable,
        };

        for (export_indices) |export_idx| {
            const exp = export_idx.ptr(zcu);
            try linker.module.declareEntryPoint(
                spv_decl_index,
                exp.opts.name.toSlice(ip),
                exec_model,
                null,
            );
        }
    }

    // TODO: Export regular functions, variables, etc using Linkage attributes.
}

pub fn flush(
    linker: *Linker,
    arena: Allocator,
    tid: Zcu.PerThread.Id,
    prog_node: std.Progress.Node,
) link.File.FlushError!void {
    // The goal is to never use this because it's only needed if we need to
    // write to InternPool, but flush is too late to be writing to the
    // InternPool.
    _ = tid;

    const tracy = trace(@src());
    defer tracy.end();

    const sub_prog_node = prog_node.start("Flush Module", 0);
    defer sub_prog_node.end();

    const comp = linker.base.comp;
    const diags = &comp.link_diags;
    const gpa = comp.gpa;

    // We need to export the list of error names somewhere so that we can pretty-print them in the
    // executor. This is not really an important thing though, so we can just dump it in any old
    // nonsemantic instruction. For now, just put it in OpSourceExtension with a special name.
    var error_info: std.io.Writer.Allocating = .init(linker.module.gpa);
    defer error_info.deinit();

    error_info.writer.writeAll("zig_errors:") catch return error.OutOfMemory;
    const ip = &linker.base.comp.zcu.?.intern_pool;
    for (ip.global_error_set.getNamesFromMainThread()) |name| {
        // Errors can contain pretty much any character - to encode them in a string we must escape
        // them somehow. Easiest here is to use some established scheme, one which also preseves the
        // name if it contains no strange characters is nice for debugging. URI encoding fits the bill.
        // We're using : as separator, which is a reserved character.
        error_info.writer.writeByte(':') catch return error.OutOfMemory;
        std.Uri.Component.percentEncode(
            &error_info.writer,
            name.toSlice(ip),
            struct {
                fn isValidChar(c: u8) bool {
                    return switch (c) {
                        0, '%', ':' => false,
                        else => true,
                    };
                }
            }.isValidChar,
        ) catch return error.OutOfMemory;
    }
    try linker.module.sections.debug_strings.emit(gpa, .OpSourceExtension, .{
        .extension = error_info.getWritten(),
    });

    const module = try linker.module.finalize(arena);
    errdefer arena.free(module);

    const linked_module = linkModule(arena, module, sub_prog_node) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => |other| return diags.fail("error while linking: {s}", .{@errorName(other)}),
    };

    linker.base.file.?.writeAll(std.mem.sliceAsBytes(linked_module)) catch |err|
        return diags.fail("failed to write: {s}", .{@errorName(err)});
}

fn linkModule(arena: Allocator, module: []Word, progress: std.Progress.Node) ![]Word {
    var parser = try BinaryModule.Parser.init(arena);
    defer parser.deinit();
    var binary = try parser.parse(module);
    try lower_invocation_globals.run(&parser, &binary, progress);
    return binary.finalize(arena);
}
