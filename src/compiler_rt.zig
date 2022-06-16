const std = @import("std");
const builtin = @import("builtin");
const build_options = @import("build_options");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const mem = std.mem;
const tracy = @import("tracy.zig");
const trace = tracy.trace;

const Cache = @import("Cache.zig");
const Compilation = @import("Compilation.zig");
const CRTFile = Compilation.CRTFile;
const LinkObject = Compilation.LinkObject;
const Package = @import("Package.zig");

pub fn buildCompilerRtLib(comp: *Compilation, compiler_rt_lib: *?CRTFile) !void {
    const tracy_trace = trace(@src());
    defer tracy_trace.end();

    var arena_allocator = std.heap.ArenaAllocator.init(comp.gpa);
    defer arena_allocator.deinit();
    const arena = arena_allocator.allocator();

    const target = comp.getTarget();

    // Use the global cache directory.
    var cache_parent: Cache = .{
        .gpa = comp.gpa,
        .manifest_dir = try comp.global_cache_directory.handle.makeOpenPath("h", .{}),
    };
    defer cache_parent.manifest_dir.close();

    var cache = cache_parent.obtain();
    defer cache.deinit();

    cache.hash.add(sources.len);
    for (sources) |source| {
        const full_path = try comp.zig_lib_directory.join(arena, &[_][]const u8{source});
        _ = try cache.addFile(full_path, null);
    }

    cache.hash.addBytes(build_options.version);
    cache.hash.addBytes(comp.zig_lib_directory.path orelse ".");
    cache.hash.add(target.cpu.arch);
    cache.hash.add(target.os.tag);
    cache.hash.add(target.abi);

    const hit = try cache.hit();
    const digest = cache.final();
    const o_sub_path = try std.fs.path.join(arena, &[_][]const u8{ "o", &digest });

    var o_directory: Compilation.Directory = .{
        .handle = try comp.global_cache_directory.handle.makeOpenPath(o_sub_path, .{}),
        .path = try std.fs.path.join(arena, &[_][]const u8{ comp.global_cache_directory.path.?, o_sub_path }),
    };
    defer o_directory.handle.close();

    const ok_basename = "ok";
    const actual_hit = if (hit) blk: {
        o_directory.handle.access(ok_basename, .{}) catch |err| switch (err) {
            error.FileNotFound => break :blk false,
            else => |e| return e,
        };
        break :blk true;
    } else false;

    const root_name = "compiler_rt";
    const basename = try std.zig.binNameAlloc(arena, .{
        .root_name = root_name,
        .target = target,
        .output_mode = .Lib,
    });

    if (!actual_hit) {
        var progress: std.Progress = .{ .dont_print_on_dumb = true };
        var progress_node = progress.start("Compile Compiler-RT", sources.len + 1);
        defer progress_node.end();
        if (comp.color == .off) progress.terminal = null;

        progress_node.activate();

        var link_objects: [sources.len]LinkObject = undefined;
        for (sources) |source, i| {
            var obj_progress_node = progress_node.start(source, 0);
            obj_progress_node.activate();
            defer obj_progress_node.end();

            var tmp_crt_file: ?CRTFile = null;
            defer if (tmp_crt_file) |*crt| crt.deinit(comp.gpa);
            try comp.buildOutputFromZig(source, .Obj, &tmp_crt_file, .compiler_rt);
            link_objects[i] = .{
                .path = try arena.dupe(u8, tmp_crt_file.?.full_object_path),
                .must_link = true,
            };
        }

        var lib_progress_node = progress_node.start(root_name, 0);
        lib_progress_node.activate();
        defer lib_progress_node.end();

        // TODO: This is extracted into a local variable to work around a stage1 miscompilation.
        const emit_bin = Compilation.EmitLoc{
            .directory = o_directory, // Put it in the cache directory.
            .basename = basename,
        };
        const sub_compilation = try Compilation.create(comp.gpa, .{
            .local_cache_directory = comp.global_cache_directory,
            .global_cache_directory = comp.global_cache_directory,
            .zig_lib_directory = comp.zig_lib_directory,
            .cache_mode = .whole,
            .target = target,
            .root_name = root_name,
            .main_pkg = null,
            .output_mode = .Lib,
            .link_mode = .Static,
            .function_sections = true,
            .thread_pool = comp.thread_pool,
            .libc_installation = comp.bin_file.options.libc_installation,
            .emit_bin = emit_bin,
            .optimize_mode = comp.compilerRtOptMode(),
            .want_sanitize_c = false,
            .want_stack_check = false,
            .want_red_zone = comp.bin_file.options.red_zone,
            .omit_frame_pointer = comp.bin_file.options.omit_frame_pointer,
            .want_valgrind = false,
            .want_tsan = false,
            .want_pic = comp.bin_file.options.pic,
            .want_pie = comp.bin_file.options.pie,
            .want_lto = comp.bin_file.options.lto,
            .emit_h = null,
            .strip = comp.compilerRtStrip(),
            .is_native_os = comp.bin_file.options.is_native_os,
            .is_native_abi = comp.bin_file.options.is_native_abi,
            .self_exe_path = comp.self_exe_path,
            .link_objects = &link_objects,
            .verbose_cc = comp.verbose_cc,
            .verbose_link = comp.bin_file.options.verbose_link,
            .verbose_air = comp.verbose_air,
            .verbose_llvm_ir = comp.verbose_llvm_ir,
            .verbose_cimport = comp.verbose_cimport,
            .verbose_llvm_cpu_features = comp.verbose_llvm_cpu_features,
            .clang_passthrough_mode = comp.clang_passthrough_mode,
            .skip_linker_dependencies = true,
            .parent_compilation_link_libc = comp.bin_file.options.link_libc,
        });
        defer sub_compilation.destroy();

        try sub_compilation.updateSubCompilation();

        if (o_directory.handle.createFile(ok_basename, .{})) |file| {
            file.close();
        } else |err| {
            std.log.warn("compiler-rt lib: failed to mark completion: {s}", .{@errorName(err)});
        }
    }

    try cache.writeManifest();

    assert(compiler_rt_lib.* == null);
    compiler_rt_lib.* = .{
        .full_object_path = try std.fs.path.join(comp.gpa, &[_][]const u8{
            comp.global_cache_directory.path.?,
            o_sub_path,
            basename,
        }),
        .lock = cache.toOwnedLock(),
    };
}

const sources = &[_][]const u8{
    "compiler_rt/absvdi2.zig",
    "compiler_rt/absvsi2.zig",
    "compiler_rt/absvti2.zig",
    "compiler_rt/adddf3.zig",
    "compiler_rt/addo.zig",
    "compiler_rt/addsf3.zig",
    "compiler_rt/addtf3.zig",
    "compiler_rt/addxf3.zig",
    "compiler_rt/arm.zig",
    "compiler_rt/atomics.zig",
    "compiler_rt/aulldiv.zig",
    "compiler_rt/aullrem.zig",
    "compiler_rt/bswap.zig",
    "compiler_rt/ceil.zig",
    "compiler_rt/clear_cache.zig",
    "compiler_rt/cmp.zig",
    "compiler_rt/cmpdf2.zig",
    "compiler_rt/cmpsf2.zig",
    "compiler_rt/cmptf2.zig",
    "compiler_rt/cmpxf2.zig",
    "compiler_rt/cos.zig",
    "compiler_rt/count0bits.zig",
    "compiler_rt/divdf3.zig",
    "compiler_rt/divsf3.zig",
    "compiler_rt/divtf3.zig",
    "compiler_rt/divti3.zig",
    "compiler_rt/divxf3.zig",
    "compiler_rt/emutls.zig",
    "compiler_rt/exp.zig",
    "compiler_rt/exp2.zig",
    "compiler_rt/extenddftf2.zig",
    "compiler_rt/extenddfxf2.zig",
    "compiler_rt/extendhfsf2.zig",
    "compiler_rt/extendhftf2.zig",
    "compiler_rt/extendhfxf2.zig",
    "compiler_rt/extendsfdf2.zig",
    "compiler_rt/extendsftf2.zig",
    "compiler_rt/extendsfxf2.zig",
    "compiler_rt/extendxftf2.zig",
    "compiler_rt/fabs.zig",
    "compiler_rt/fixdfdi.zig",
    "compiler_rt/fixdfsi.zig",
    "compiler_rt/fixdfti.zig",
    "compiler_rt/fixhfdi.zig",
    "compiler_rt/fixhfsi.zig",
    "compiler_rt/fixhfti.zig",
    "compiler_rt/fixsfdi.zig",
    "compiler_rt/fixsfsi.zig",
    "compiler_rt/fixsfti.zig",
    "compiler_rt/fixtfdi.zig",
    "compiler_rt/fixtfsi.zig",
    "compiler_rt/fixtfti.zig",
    "compiler_rt/fixunsdfdi.zig",
    "compiler_rt/fixunsdfsi.zig",
    "compiler_rt/fixunsdfti.zig",
    "compiler_rt/fixunshfdi.zig",
    "compiler_rt/fixunshfsi.zig",
    "compiler_rt/fixunshfti.zig",
    "compiler_rt/fixunssfdi.zig",
    "compiler_rt/fixunssfsi.zig",
    "compiler_rt/fixunssfti.zig",
    "compiler_rt/fixunstfdi.zig",
    "compiler_rt/fixunstfsi.zig",
    "compiler_rt/fixunstfti.zig",
    "compiler_rt/fixunsxfdi.zig",
    "compiler_rt/fixunsxfsi.zig",
    "compiler_rt/fixunsxfti.zig",
    "compiler_rt/fixxfdi.zig",
    "compiler_rt/fixxfsi.zig",
    "compiler_rt/fixxfti.zig",
    "compiler_rt/floatdidf.zig",
    "compiler_rt/floatdihf.zig",
    "compiler_rt/floatdisf.zig",
    "compiler_rt/floatditf.zig",
    "compiler_rt/floatdixf.zig",
    "compiler_rt/floatsidf.zig",
    "compiler_rt/floatsihf.zig",
    "compiler_rt/floatsisf.zig",
    "compiler_rt/floatsitf.zig",
    "compiler_rt/floatsixf.zig",
    "compiler_rt/floattidf.zig",
    "compiler_rt/floattihf.zig",
    "compiler_rt/floattisf.zig",
    "compiler_rt/floattitf.zig",
    "compiler_rt/floattixf.zig",
    "compiler_rt/floatundidf.zig",
    "compiler_rt/floatundihf.zig",
    "compiler_rt/floatundisf.zig",
    "compiler_rt/floatunditf.zig",
    "compiler_rt/floatundixf.zig",
    "compiler_rt/floatunsidf.zig",
    "compiler_rt/floatunsihf.zig",
    "compiler_rt/floatunsisf.zig",
    "compiler_rt/floatunsitf.zig",
    "compiler_rt/floatunsixf.zig",
    "compiler_rt/floatuntidf.zig",
    "compiler_rt/floatuntihf.zig",
    "compiler_rt/floatuntisf.zig",
    "compiler_rt/floatuntitf.zig",
    "compiler_rt/floatuntixf.zig",
    "compiler_rt/floor.zig",
    "compiler_rt/fma.zig",
    "compiler_rt/fmax.zig",
    "compiler_rt/fmin.zig",
    "compiler_rt/fmod.zig",
    "compiler_rt/gedf2.zig",
    "compiler_rt/gesf2.zig",
    "compiler_rt/getf2.zig",
    "compiler_rt/gexf2.zig",
    "compiler_rt/int.zig",
    "compiler_rt/log.zig",
    "compiler_rt/log10.zig",
    "compiler_rt/log2.zig",
    "compiler_rt/modti3.zig",
    "compiler_rt/muldf3.zig",
    "compiler_rt/muldi3.zig",
    "compiler_rt/mulf3.zig",
    "compiler_rt/mulo.zig",
    "compiler_rt/mulsf3.zig",
    "compiler_rt/multf3.zig",
    "compiler_rt/multi3.zig",
    "compiler_rt/mulxf3.zig",
    "compiler_rt/negXf2.zig",
    "compiler_rt/negXi2.zig",
    "compiler_rt/negv.zig",
    "compiler_rt/os_version_check.zig",
    "compiler_rt/parity.zig",
    "compiler_rt/popcount.zig",
    "compiler_rt/round.zig",
    "compiler_rt/shift.zig",
    "compiler_rt/sin.zig",
    "compiler_rt/sincos.zig",
    "compiler_rt/sqrt.zig",
    "compiler_rt/stack_probe.zig",
    "compiler_rt/subdf3.zig",
    "compiler_rt/subo.zig",
    "compiler_rt/subsf3.zig",
    "compiler_rt/subtf3.zig",
    "compiler_rt/subxf3.zig",
    "compiler_rt/tan.zig",
    "compiler_rt/trunc.zig",
    "compiler_rt/truncdfhf2.zig",
    "compiler_rt/truncdfsf2.zig",
    "compiler_rt/truncsfhf2.zig",
    "compiler_rt/trunctfdf2.zig",
    "compiler_rt/trunctfhf2.zig",
    "compiler_rt/trunctfsf2.zig",
    "compiler_rt/trunctfxf2.zig",
    "compiler_rt/truncxfdf2.zig",
    "compiler_rt/truncxfhf2.zig",
    "compiler_rt/truncxfsf2.zig",
    "compiler_rt/udivmodti4.zig",
    "compiler_rt/udivti3.zig",
    "compiler_rt/umodti3.zig",
    "compiler_rt/unorddf2.zig",
    "compiler_rt/unordsf2.zig",
    "compiler_rt/unordtf2.zig",
};
