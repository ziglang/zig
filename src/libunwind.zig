const std = @import("std");
const path = std.fs.path;
const assert = std.debug.assert;

const target_util = @import("target.zig");
const Compilation = @import("Compilation.zig");
const build_options = @import("build_options");
const trace = @import("tracy.zig").trace;

pub fn buildStaticLib(comp: *Compilation) !void {
    if (!build_options.have_llvm) {
        return error.ZigCompilerNotBuiltWithLLVMExtensions;
    }

    const tracy = trace(@src());
    defer tracy.end();

    var arena_allocator = std.heap.ArenaAllocator.init(comp.gpa);
    defer arena_allocator.deinit();
    const arena = &arena_allocator.allocator;

    const root_name = "unwind";
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
    const unwind_src_list = [_][]const u8{
        "libunwind" ++ path.sep_str ++ "src" ++ path.sep_str ++ "libunwind.cpp",
        "libunwind" ++ path.sep_str ++ "src" ++ path.sep_str ++ "Unwind-EHABI.cpp",
        "libunwind" ++ path.sep_str ++ "src" ++ path.sep_str ++ "Unwind-seh.cpp",
        "libunwind" ++ path.sep_str ++ "src" ++ path.sep_str ++ "UnwindLevel1.c",
        "libunwind" ++ path.sep_str ++ "src" ++ path.sep_str ++ "UnwindLevel1-gcc-ext.c",
        "libunwind" ++ path.sep_str ++ "src" ++ path.sep_str ++ "Unwind-sjlj.c",
        "libunwind" ++ path.sep_str ++ "src" ++ path.sep_str ++ "UnwindRegistersRestore.S",
        "libunwind" ++ path.sep_str ++ "src" ++ path.sep_str ++ "UnwindRegistersSave.S",
        "libunwind" ++ path.sep_str ++ "src" ++ path.sep_str ++ "gcc_personality_v0.c",
    };
    var c_source_files: [unwind_src_list.len]Compilation.CSourceFile = undefined;
    for (unwind_src_list) |unwind_src, i| {
        var cflags = std.ArrayList([]const u8).init(arena);

        switch (Compilation.classifyFileExt(unwind_src)) {
            .c => {
                try cflags.append("-std=c99");
            },
            .cpp => {
                try cflags.appendSlice(&[_][]const u8{
                    "-fno-rtti",
                    "-I",
                    try comp.zig_lib_directory.join(arena, &[_][]const u8{ "libcxx", "include" }),
                });
            },
            .assembly => {},
            else => unreachable, // You can see the entire list of files just above.
        }
        try cflags.append("-I");
        try cflags.append(try comp.zig_lib_directory.join(arena, &[_][]const u8{ "libunwind", "include" }));
        if (target_util.supports_fpic(target)) {
            try cflags.append("-fPIC");
        }
        try cflags.append("-D_LIBUNWIND_DISABLE_VISIBILITY_ANNOTATIONS");
        try cflags.append("-Wa,--noexecstack");

        // This is intentionally always defined because the macro definition means, should it only
        // build for the target specified by compiler defines. Since we pass -target the compiler
        // defines will be correct.
        try cflags.append("-D_LIBUNWIND_IS_NATIVE_ONLY");

        if (comp.bin_file.options.optimize_mode == .Debug) {
            try cflags.append("-D_DEBUG");
        }
        if (comp.bin_file.options.single_threaded) {
            try cflags.append("-D_LIBUNWIND_HAS_NO_THREADS");
        }
        if (target.cpu.arch.isARM() and target.abi.floatAbi() == .hard) {
            try cflags.append("-DCOMPILER_RT_ARMHF_TARGET");
        }
        try cflags.append("-Wno-bitwise-conditional-parentheses");
        try cflags.append("-Wno-visibility");
        try cflags.append("-Wno-incompatible-pointer-types");

        c_source_files[i] = .{
            .src_path = try comp.zig_lib_directory.join(arena, &[_][]const u8{unwind_src}),
            .extra_flags = cflags.items,
        };
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
        .optimize_mode = comp.compilerRtOptMode(),
        .link_mode = link_mode,
        .want_sanitize_c = false,
        .want_stack_check = false,
        .want_red_zone = comp.bin_file.options.red_zone,
        .want_valgrind = false,
        .want_tsan = false,
        .want_pic = comp.bin_file.options.pic,
        .want_pie = comp.bin_file.options.pie,
        .emit_h = null,
        .strip = comp.compilerRtStrip(),
        .is_native_os = comp.bin_file.options.is_native_os,
        .is_native_abi = comp.bin_file.options.is_native_abi,
        .self_exe_path = comp.self_exe_path,
        .c_source_files = &c_source_files,
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
        .skip_linker_dependencies = true,
    });
    defer sub_compilation.destroy();

    try sub_compilation.updateSubCompilation();

    assert(comp.libunwind_static_lib == null);
    comp.libunwind_static_lib = Compilation.CRTFile{
        .full_object_path = try sub_compilation.bin_file.options.emit.?.directory.join(
            comp.gpa,
            &[_][]const u8{basename},
        ),
        .lock = sub_compilation.bin_file.toOwnedLock(),
    };
}
