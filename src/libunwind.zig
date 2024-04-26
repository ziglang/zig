const std = @import("std");
const path = std.fs.path;
const assert = std.debug.assert;

const target_util = @import("target.zig");
const Compilation = @import("Compilation.zig");
const Module = @import("Package/Module.zig");
const build_options = @import("build_options");
const trace = @import("tracy.zig").trace;

pub fn buildStaticLib(comp: *Compilation, prog_node: *std.Progress.Node) !void {
    if (!build_options.have_llvm) {
        return error.ZigCompilerNotBuiltWithLLVMExtensions;
    }

    const tracy = trace(@src());
    defer tracy.end();

    var arena_allocator = std.heap.ArenaAllocator.init(comp.gpa);
    defer arena_allocator.deinit();
    const arena = arena_allocator.allocator();

    const output_mode = .Lib;
    const config = try Compilation.Config.resolve(.{
        .output_mode = .Lib,
        .resolved_target = comp.root_mod.resolved_target,
        .is_test = false,
        .have_zcu = false,
        .emit_bin = true,
        .root_optimize_mode = comp.compilerRtOptMode(),
        .root_strip = comp.compilerRtStrip(),
        .link_libc = true,
        // Disable LTO to avoid https://github.com/llvm/llvm-project/issues/56825
        .lto = false,
    });
    const root_mod = try Module.create(arena, .{
        .global_cache_directory = comp.global_cache_directory,
        .paths = .{
            .root = .{ .root_dir = comp.zig_lib_directory },
            .root_src_path = "",
        },
        .fully_qualified_name = "root",
        .inherited = .{
            .resolved_target = comp.root_mod.resolved_target,
            .strip = comp.compilerRtStrip(),
            .stack_check = false,
            .stack_protector = 0,
            .red_zone = comp.root_mod.red_zone,
            .omit_frame_pointer = comp.root_mod.omit_frame_pointer,
            .valgrind = false,
            .sanitize_c = false,
            .sanitize_thread = false,
            .unwind_tables = false,
            .pic = comp.root_mod.pic,
            .optimize_mode = comp.compilerRtOptMode(),
        },
        .global = config,
        .cc_argv = &.{},
        .parent = null,
        .builtin_mod = null,
        .builtin_modules = null, // there is only one module in this compilation
    });

    const root_name = "unwind";
    const link_mode = .static;
    const target = comp.root_mod.resolved_target.result;
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
    var c_source_files: [unwind_src_list.len]Compilation.CSourceFile = undefined;
    for (unwind_src_list, 0..) |unwind_src, i| {
        var cflags = std.ArrayList([]const u8).init(arena);

        switch (Compilation.classifyFileExt(unwind_src)) {
            .c => {
                try cflags.append("-std=c11");
            },
            .cpp => {
                try cflags.appendSlice(&[_][]const u8{"-fno-rtti"});
            },
            .assembly_with_cpp => {},
            else => unreachable, // You can see the entire list of files just above.
        }
        try cflags.append("-I");
        try cflags.append(try comp.zig_lib_directory.join(arena, &[_][]const u8{ "libunwind", "include" }));
        if (target_util.supports_fpic(target)) {
            try cflags.append("-fPIC");
        }
        try cflags.append("-D_LIBUNWIND_DISABLE_VISIBILITY_ANNOTATIONS");
        try cflags.append("-Wa,--noexecstack");
        try cflags.append("-fvisibility=hidden");
        try cflags.append("-fvisibility-inlines-hidden");
        // necessary so that libunwind can unwind through its own stack frames
        try cflags.append("-funwind-tables");

        // This is intentionally always defined because the macro definition means, should it only
        // build for the target specified by compiler defines. Since we pass -target the compiler
        // defines will be correct.
        try cflags.append("-D_LIBUNWIND_IS_NATIVE_ONLY");

        if (comp.root_mod.optimize_mode == .Debug) {
            try cflags.append("-D_DEBUG");
        }
        if (!comp.config.any_non_single_threaded) {
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
            .owner = root_mod,
        };
    }
    const sub_compilation = try Compilation.create(comp.gpa, arena, .{
        .self_exe_path = comp.self_exe_path,
        .local_cache_directory = comp.global_cache_directory,
        .global_cache_directory = comp.global_cache_directory,
        .zig_lib_directory = comp.zig_lib_directory,
        .config = config,
        .root_mod = root_mod,
        .cache_mode = .whole,
        .root_name = root_name,
        .main_mod = null,
        .thread_pool = comp.thread_pool,
        .libc_installation = comp.libc_installation,
        .emit_bin = emit_bin,
        .function_sections = comp.function_sections,
        .c_source_files = &c_source_files,
        .verbose_cc = comp.verbose_cc,
        .verbose_link = comp.verbose_link,
        .verbose_air = comp.verbose_air,
        .verbose_llvm_ir = comp.verbose_llvm_ir,
        .verbose_llvm_bc = comp.verbose_llvm_bc,
        .verbose_cimport = comp.verbose_cimport,
        .verbose_llvm_cpu_features = comp.verbose_llvm_cpu_features,
        .clang_passthrough_mode = comp.clang_passthrough_mode,
        .skip_linker_dependencies = true,
    });
    defer sub_compilation.destroy();

    try comp.updateSubCompilation(sub_compilation, .libunwind, prog_node);

    assert(comp.libunwind_static_lib == null);
    comp.libunwind_static_lib = try sub_compilation.toCrtFile();
}

const unwind_src_list = [_][]const u8{
    "libunwind" ++ path.sep_str ++ "src" ++ path.sep_str ++ "libunwind.cpp",
    "libunwind" ++ path.sep_str ++ "src" ++ path.sep_str ++ "Unwind-EHABI.cpp",
    "libunwind" ++ path.sep_str ++ "src" ++ path.sep_str ++ "Unwind-seh.cpp",
    "libunwind" ++ path.sep_str ++ "src" ++ path.sep_str ++ "UnwindLevel1.c",
    "libunwind" ++ path.sep_str ++ "src" ++ path.sep_str ++ "UnwindLevel1-gcc-ext.c",
    "libunwind" ++ path.sep_str ++ "src" ++ path.sep_str ++ "Unwind-sjlj.c",
    "libunwind" ++ path.sep_str ++ "src" ++ path.sep_str ++ "Unwind-wasm.c",
    "libunwind" ++ path.sep_str ++ "src" ++ path.sep_str ++ "UnwindRegistersRestore.S",
    "libunwind" ++ path.sep_str ++ "src" ++ path.sep_str ++ "UnwindRegistersSave.S",
    "libunwind" ++ path.sep_str ++ "src" ++ path.sep_str ++ "Unwind_AIXExtras.cpp",
    "libunwind" ++ path.sep_str ++ "src" ++ path.sep_str ++ "gcc_personality_v0.c",
};
