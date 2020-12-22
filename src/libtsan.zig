const std = @import("std");
const assert = std.debug.assert;

const Compilation = @import("Compilation.zig");
const build_options = @import("build_options");
const trace = @import("tracy.zig").trace;

pub fn buildTsan(comp: *Compilation) !void {
    if (!build_options.have_llvm) {
        return error.ZigCompilerNotBuiltWithLLVMExtensions;
    }

    const tracy = trace(@src());
    defer tracy.end();

    var arena_allocator = std.heap.ArenaAllocator.init(comp.gpa);
    defer arena_allocator.deinit();
    const arena = &arena_allocator.allocator;

    const root_name = "tsan";
    const output_mode = .Lib;
    const link_mode = .Static;
    const target = comp.getTarget();
    const basename = try std.zig.binNameAlloc(arena, .{
        .root_name = root_name,
        .target = target,
        .output_mode = output_mode,
        .link_mode = link_mode,
    });

    const emit_bin = Compilation.EmitLoc{
        .directory = null, // Put it in the cache directory.
        .basename = basename,
    };

    var c_source_files = std.ArrayList(Compilation.CSourceFile).init(arena);
    try c_source_files.ensureCapacity(tsan_sources.len + sanitizer_common_sources.len);

    const tsan_include_path = try comp.zig_lib_directory.join(arena, &[_][]const u8{"tsan"});
    for (tsan_sources) |tsan_src| {
        var cflags = std.ArrayList([]const u8).init(arena);

        try cflags.append("-I");
        try cflags.append(tsan_include_path);

        try cflags.append("-O3");
        try cflags.append("-DNDEBUG");
        try cflags.append("-nostdinc++");
        try cflags.append("-fvisibility-inlines-hidden");
        try cflags.append("-std=c++14");

        c_source_files.appendAssumeCapacity(.{
            .src_path = try comp.zig_lib_directory.join(arena, &[_][]const u8{ "tsan", tsan_src }),
            .extra_flags = cflags.items,
        });
    }

    const sanitizer_common_include_path = try comp.zig_lib_directory.join(arena, &[_][]const u8{
        "tsan", "sanitizer_common",
    });
    for (sanitizer_common_sources) |common_src| {
        var cflags = std.ArrayList([]const u8).init(arena);

        try cflags.append("-I");
        try cflags.append(sanitizer_common_include_path);

        try cflags.append("-O3");
        try cflags.append("-DNDEBUG");
        try cflags.append("-nostdinc++");
        try cflags.append("-fvisibility-inlines-hidden");
        try cflags.append("-std=c++14");

        c_source_files.appendAssumeCapacity(.{
            .src_path = try comp.zig_lib_directory.join(arena, &[_][]const u8{
                "tsan", "sanitizer_common", common_src,
            }),
            .extra_flags = cflags.items,
        });
    }

    const sub_compilation = try Compilation.create(comp.gpa, .{
        .local_cache_directory = comp.global_cache_directory,
        .global_cache_directory = comp.global_cache_directory,
        .zig_lib_directory = comp.zig_lib_directory,
        .target = target,
        .root_name = root_name,
        .root_pkg = null,
        .output_mode = output_mode,
        .thread_pool = comp.thread_pool,
        .libc_installation = comp.bin_file.options.libc_installation,
        .emit_bin = emit_bin,
        .optimize_mode = comp.bin_file.options.optimize_mode,
        .link_mode = link_mode,
        .want_sanitize_c = false,
        .want_stack_check = false,
        .want_valgrind = false,
        .want_tsan = false,
        .want_pic = true,
        .want_pie = true,
        .emit_h = null,
        .strip = comp.bin_file.options.strip,
        .is_native_os = comp.bin_file.options.is_native_os,
        .is_native_abi = comp.bin_file.options.is_native_abi,
        .self_exe_path = comp.self_exe_path,
        .c_source_files = c_source_files.items,
        .verbose_cc = comp.verbose_cc,
        .verbose_link = comp.bin_file.options.verbose_link,
        .verbose_tokenize = comp.verbose_tokenize,
        .verbose_ast = comp.verbose_ast,
        .verbose_ir = comp.verbose_ir,
        .verbose_llvm_ir = comp.verbose_llvm_ir,
        .verbose_cimport = comp.verbose_cimport,
        .verbose_llvm_cpu_features = comp.verbose_llvm_cpu_features,
        .clang_passthrough_mode = comp.clang_passthrough_mode,
        .link_libc = true,
    });
    defer sub_compilation.destroy();

    try sub_compilation.updateSubCompilation();

    assert(comp.tsan_static_lib == null);
    comp.tsan_static_lib = Compilation.CRTFile{
        .full_object_path = try sub_compilation.bin_file.options.emit.?.directory.join(
            comp.gpa,
            &[_][]const u8{basename},
        ),
        .lock = sub_compilation.bin_file.toOwnedLock(),
    };
}

const tsan_sources = [_][]const u8{
    "tsan_clock.cpp",
    "tsan_debugging.cpp",
    "tsan_external.cpp",
    "tsan_fd.cpp",
    "tsan_flags.cpp",
    "tsan_ignoreset.cpp",
    "tsan_interceptors_posix.cpp",
    "tsan_interface.cpp",
    "tsan_interface_ann.cpp",
    "tsan_interface_atomic.cpp",
    "tsan_interface_java.cpp",
    "tsan_malloc_mac.cpp",
    "tsan_md5.cpp",
    "tsan_mman.cpp",
    "tsan_mutex.cpp",
    "tsan_mutexset.cpp",
    "tsan_preinit.cpp",
    "tsan_report.cpp",
    "tsan_rtl.cpp",
    "tsan_rtl_mutex.cpp",
    "tsan_rtl_proc.cpp",
    "tsan_rtl_report.cpp",
    "tsan_rtl_thread.cpp",
    "tsan_stack_trace.cpp",
    "tsan_stat.cpp",
    "tsan_suppressions.cpp",
    "tsan_symbolize.cpp",
    "tsan_sync.cpp",
};

const sanitizer_common_sources = [_][]const u8{
    "sanitizer_allocator.cpp",
    "sanitizer_common.cpp",
    "sanitizer_deadlock_detector1.cpp",
    "sanitizer_deadlock_detector2.cpp",
    "sanitizer_errno.cpp",
    "sanitizer_file.cpp",
    "sanitizer_flags.cpp",
    "sanitizer_flag_parser.cpp",
    "sanitizer_fuchsia.cpp",
    "sanitizer_libc.cpp",
    "sanitizer_libignore.cpp",
    "sanitizer_linux.cpp",
    "sanitizer_linux_s390.cpp",
    "sanitizer_mac.cpp",
    "sanitizer_netbsd.cpp",
    "sanitizer_openbsd.cpp",
    "sanitizer_persistent_allocator.cpp",
    "sanitizer_platform_limits_freebsd.cpp",
    "sanitizer_platform_limits_linux.cpp",
    "sanitizer_platform_limits_netbsd.cpp",
    "sanitizer_platform_limits_openbsd.cpp",
    "sanitizer_platform_limits_posix.cpp",
    "sanitizer_platform_limits_solaris.cpp",
    "sanitizer_posix.cpp",
    "sanitizer_printf.cpp",
    "sanitizer_procmaps_common.cpp",
    "sanitizer_procmaps_bsd.cpp",
    "sanitizer_procmaps_fuchsia.cpp",
    "sanitizer_procmaps_linux.cpp",
    "sanitizer_procmaps_mac.cpp",
    "sanitizer_procmaps_solaris.cpp",
    "sanitizer_rtems.cpp",
    "sanitizer_solaris.cpp",
    "sanitizer_stoptheworld_fuchsia.cpp",
    "sanitizer_stoptheworld_mac.cpp",
    "sanitizer_suppressions.cpp",
    "sanitizer_termination.cpp",
    "sanitizer_tls_get_addr.cpp",
    "sanitizer_thread_registry.cpp",
    "sanitizer_type_traits.cpp",
    "sanitizer_win.cpp",
};

// TODO This is next up
//const sanitizer_nolibc_sources = [_][]const u8{
//    "sanitizer_common_nolibc.cpp",
//};
//
//const sanitizer_libcdep_sources = [_][]const u8{
//    "sanitizer_common_libcdep.cpp",
//    "sanitizer_allocator_checks.cpp",
//    "sanitizer_linux_libcdep.cpp",
//    "sanitizer_mac_libcdep.cpp",
//    "sanitizer_posix_libcdep.cpp",
//    "sanitizer_stoptheworld_linux_libcdep.cpp",
//    "sanitizer_stoptheworld_netbsd_libcdep.cpp",
//};
