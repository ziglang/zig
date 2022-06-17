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
const WaitGroup = @import("WaitGroup.zig");

pub fn buildCompilerRtLib(comp: *Compilation, progress_node: *std.Progress.Node) !void {
    var arena_allocator = std.heap.ArenaAllocator.init(comp.gpa);
    defer arena_allocator.deinit();
    const arena = arena_allocator.allocator();

    const target = comp.getTarget();

    const root_name = "compiler_rt";
    const basename = try std.zig.binNameAlloc(arena, .{
        .root_name = root_name,
        .target = target,
        .output_mode = .Lib,
    });

    var link_objects: [sources.len]LinkObject = undefined;
    var crt_files = [1]?CRTFile{null} ** sources.len;
    defer deinitCrtFiles(comp, crt_files);

    {
        var wg: WaitGroup = .{};
        defer comp.thread_pool.waitAndWork(&wg);

        for (sources) |source, i| {
            wg.start();
            try comp.thread_pool.spawn(workerBuildObject, .{
                comp, progress_node, &wg, source, &crt_files[i],
            });
        }
    }

    for (link_objects) |*link_object, i| {
        link_object.* = .{
            .path = crt_files[i].?.full_object_path,
        };
    }

    var link_progress_node = progress_node.start("link", 0);
    link_progress_node.activate();
    defer link_progress_node.end();

    // TODO: This is extracted into a local variable to work around a stage1 miscompilation.
    const emit_bin = Compilation.EmitLoc{
        .directory = null, // Put it in the cache directory.
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

    assert(comp.compiler_rt_lib == null);
    comp.compiler_rt_lib = .{
        .full_object_path = try sub_compilation.bin_file.options.emit.?.directory.join(comp.gpa, &[_][]const u8{
            sub_compilation.bin_file.options.emit.?.sub_path,
        }),
        .lock = sub_compilation.bin_file.toOwnedLock(),
    };
}

fn deinitCrtFiles(comp: *Compilation, crt_files: [sources.len]?CRTFile) void {
    const gpa = comp.gpa;

    for (crt_files) |opt_crt_file| {
        var crt_file = opt_crt_file orelse continue;
        crt_file.deinit(gpa);
    }
}

fn workerBuildObject(
    comp: *Compilation,
    progress_node: *std.Progress.Node,
    wg: *WaitGroup,
    src_basename: []const u8,
    out: *?CRTFile,
) void {
    defer wg.finish();

    var obj_progress_node = progress_node.start(src_basename, 0);
    obj_progress_node.activate();
    defer obj_progress_node.end();

    buildObject(comp, src_basename, out) catch |err| switch (err) {
        error.SubCompilationFailed => return, // error reported already
        else => comp.lockAndSetMiscFailure(
            .compiler_rt,
            "unable to build compiler_rt: {s}",
            .{@errorName(err)},
        ),
    };
}

fn buildObject(comp: *Compilation, src_basename: []const u8, out: *?CRTFile) !void {
    const gpa = comp.gpa;

    var root_src_path_buf: [64]u8 = undefined;
    const root_src_path = std.fmt.bufPrint(
        &root_src_path_buf,
        "compiler_rt" ++ std.fs.path.sep_str ++ "{s}",
        .{src_basename},
    ) catch unreachable;

    var main_pkg: Package = .{
        .root_src_directory = comp.zig_lib_directory,
        .root_src_path = root_src_path,
    };
    defer main_pkg.deinitTable(gpa);
    const root_name = src_basename[0 .. src_basename.len - std.fs.path.extension(src_basename).len];
    const target = comp.getTarget();
    const output_mode: std.builtin.OutputMode = .Obj;
    const bin_basename = try std.zig.binNameAlloc(gpa, .{
        .root_name = root_name,
        .target = target,
        .output_mode = output_mode,
    });
    defer gpa.free(bin_basename);

    const emit_bin = Compilation.EmitLoc{
        .directory = null, // Put it in the cache directory.
        .basename = bin_basename,
    };
    const sub_compilation = try Compilation.create(gpa, .{
        .global_cache_directory = comp.global_cache_directory,
        .local_cache_directory = comp.global_cache_directory,
        .zig_lib_directory = comp.zig_lib_directory,
        .cache_mode = .whole,
        .target = target,
        .root_name = root_name,
        .main_pkg = &main_pkg,
        .output_mode = output_mode,
        .thread_pool = comp.thread_pool,
        .libc_installation = comp.bin_file.options.libc_installation,
        .emit_bin = emit_bin,
        .optimize_mode = comp.compilerRtOptMode(),
        .link_mode = .Static,
        .function_sections = true,
        .want_sanitize_c = false,
        .want_stack_check = false,
        .want_red_zone = comp.bin_file.options.red_zone,
        .omit_frame_pointer = comp.bin_file.options.omit_frame_pointer,
        .want_valgrind = false,
        .want_tsan = false,
        .want_pic = comp.bin_file.options.pic,
        .want_pie = comp.bin_file.options.pie,
        .emit_h = null,
        .strip = comp.compilerRtStrip(),
        .is_native_os = comp.bin_file.options.is_native_os,
        .is_native_abi = comp.bin_file.options.is_native_abi,
        .self_exe_path = comp.self_exe_path,
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

    try sub_compilation.update();
    // Look for compilation errors in this sub_compilation.
    var keep_errors = false;
    var errors = try sub_compilation.getAllErrorsAlloc();
    defer if (!keep_errors) errors.deinit(sub_compilation.gpa);

    if (errors.list.len != 0) {
        const misc_task_tag: Compilation.MiscTask = .compiler_rt;

        comp.mutex.lock();
        defer comp.mutex.unlock();

        try comp.misc_failures.ensureUnusedCapacity(gpa, 1);
        comp.misc_failures.putAssumeCapacityNoClobber(misc_task_tag, .{
            .msg = try std.fmt.allocPrint(gpa, "sub-compilation of {s} failed", .{
                @tagName(misc_task_tag),
            }),
            .children = errors,
        });
        keep_errors = true;
        return error.SubCompilationFailed;
    }

    assert(out.* == null);
    out.* = Compilation.CRTFile{
        .full_object_path = try sub_compilation.bin_file.options.emit.?.directory.join(gpa, &[_][]const u8{
            sub_compilation.bin_file.options.emit.?.sub_path,
        }),
        .lock = sub_compilation.bin_file.toOwnedLock(),
    };
}

pub const sources = &[_][]const u8{
    "absvdi2.zig",
    "absvsi2.zig",
    "absvti2.zig",
    "adddf3.zig",
    "addo.zig",
    "addsf3.zig",
    "addtf3.zig",
    "addxf3.zig",
    "arm.zig",
    "atomics.zig",
    "aulldiv.zig",
    "aullrem.zig",
    "bswap.zig",
    "ceil.zig",
    "clear_cache.zig",
    "cmp.zig",
    "cmpdf2.zig",
    "cmpsf2.zig",
    "cmptf2.zig",
    "cmpxf2.zig",
    "cos.zig",
    "count0bits.zig",
    "divdf3.zig",
    "divsf3.zig",
    "divtf3.zig",
    "divti3.zig",
    "divxf3.zig",
    "emutls.zig",
    "exp.zig",
    "exp2.zig",
    "extenddftf2.zig",
    "extenddfxf2.zig",
    "extendhfsf2.zig",
    "extendhftf2.zig",
    "extendhfxf2.zig",
    "extendsfdf2.zig",
    "extendsftf2.zig",
    "extendsfxf2.zig",
    "extendxftf2.zig",
    "fabs.zig",
    "fixdfdi.zig",
    "fixdfsi.zig",
    "fixdfti.zig",
    "fixhfdi.zig",
    "fixhfsi.zig",
    "fixhfti.zig",
    "fixsfdi.zig",
    "fixsfsi.zig",
    "fixsfti.zig",
    "fixtfdi.zig",
    "fixtfsi.zig",
    "fixtfti.zig",
    "fixunsdfdi.zig",
    "fixunsdfsi.zig",
    "fixunsdfti.zig",
    "fixunshfdi.zig",
    "fixunshfsi.zig",
    "fixunshfti.zig",
    "fixunssfdi.zig",
    "fixunssfsi.zig",
    "fixunssfti.zig",
    "fixunstfdi.zig",
    "fixunstfsi.zig",
    "fixunstfti.zig",
    "fixunsxfdi.zig",
    "fixunsxfsi.zig",
    "fixunsxfti.zig",
    "fixxfdi.zig",
    "fixxfsi.zig",
    "fixxfti.zig",
    "floatdidf.zig",
    "floatdihf.zig",
    "floatdisf.zig",
    "floatditf.zig",
    "floatdixf.zig",
    "floatsidf.zig",
    "floatsihf.zig",
    "floatsisf.zig",
    "floatsitf.zig",
    "floatsixf.zig",
    "floattidf.zig",
    "floattihf.zig",
    "floattisf.zig",
    "floattitf.zig",
    "floattixf.zig",
    "floatundidf.zig",
    "floatundihf.zig",
    "floatundisf.zig",
    "floatunditf.zig",
    "floatundixf.zig",
    "floatunsidf.zig",
    "floatunsihf.zig",
    "floatunsisf.zig",
    "floatunsitf.zig",
    "floatunsixf.zig",
    "floatuntidf.zig",
    "floatuntihf.zig",
    "floatuntisf.zig",
    "floatuntitf.zig",
    "floatuntixf.zig",
    "floor.zig",
    "fma.zig",
    "fmax.zig",
    "fmin.zig",
    "fmod.zig",
    "gedf2.zig",
    "gesf2.zig",
    "getf2.zig",
    "gexf2.zig",
    "int.zig",
    "log.zig",
    "log10.zig",
    "log2.zig",
    "modti3.zig",
    "muldf3.zig",
    "muldi3.zig",
    "mulf3.zig",
    "mulo.zig",
    "mulsf3.zig",
    "multf3.zig",
    "multi3.zig",
    "mulxf3.zig",
    "negXf2.zig",
    "negXi2.zig",
    "negv.zig",
    "os_version_check.zig",
    "parity.zig",
    "popcount.zig",
    "round.zig",
    "shift.zig",
    "sin.zig",
    "sincos.zig",
    "sqrt.zig",
    "stack_probe.zig",
    "subdf3.zig",
    "subo.zig",
    "subsf3.zig",
    "subtf3.zig",
    "subxf3.zig",
    "tan.zig",
    "trunc.zig",
    "truncdfhf2.zig",
    "truncdfsf2.zig",
    "truncsfhf2.zig",
    "trunctfdf2.zig",
    "trunctfhf2.zig",
    "trunctfsf2.zig",
    "trunctfxf2.zig",
    "truncxfdf2.zig",
    "truncxfhf2.zig",
    "truncxfsf2.zig",
    "udivmodti4.zig",
    "udivti3.zig",
    "umodti3.zig",
    "unorddf2.zig",
    "unordsf2.zig",
    "unordtf2.zig",
};
