const std = @import("std");
const path = std.fs.path;
const assert = std.debug.assert;

const target_util = @import("target.zig");
const Compilation = @import("Compilation.zig");
const build_options = @import("build_options");
const trace = @import("tracy.zig").trace;

const libcxxabi_files = [_][]const u8{
    "src/abort_message.cpp",
    "src/cxa_aux_runtime.cpp",
    "src/cxa_default_handlers.cpp",
    "src/cxa_demangle.cpp",
    "src/cxa_exception.cpp",
    "src/cxa_exception_storage.cpp",
    "src/cxa_guard.cpp",
    "src/cxa_handlers.cpp",
    "src/cxa_noexception.cpp",
    "src/cxa_personality.cpp",
    "src/cxa_thread_atexit.cpp",
    "src/cxa_vector.cpp",
    "src/cxa_virtual.cpp",
    "src/fallback_malloc.cpp",
    "src/private_typeinfo.cpp",
    "src/stdlib_exception.cpp",
    "src/stdlib_new_delete.cpp",
    "src/stdlib_stdexcept.cpp",
    "src/stdlib_typeinfo.cpp",
};

const libcxx_files = [_][]const u8{
    "src/algorithm.cpp",
    "src/any.cpp",
    "src/atomic.cpp",
    "src/barrier.cpp",
    "src/bind.cpp",
    "src/charconv.cpp",
    "src/chrono.cpp",
    "src/condition_variable.cpp",
    "src/condition_variable_destructor.cpp",
    "src/debug.cpp",
    "src/exception.cpp",
    "src/experimental/memory_resource.cpp",
    "src/filesystem/directory_iterator.cpp",
    // omit int128_builtins.cpp because it provides __muloti4 which is already provided
    // by compiler_rt and crashes on Windows x86_64: https://github.com/ziglang/zig/issues/10719
    //"src/filesystem/int128_builtins.cpp",
    "src/filesystem/operations.cpp",
    "src/format.cpp",
    "src/functional.cpp",
    "src/future.cpp",
    "src/hash.cpp",
    "src/ios.cpp",
    "src/ios.instantiations.cpp",
    "src/iostream.cpp",
    "src/legacy_pointer_safety.cpp",
    "src/locale.cpp",
    "src/memory.cpp",
    "src/mutex.cpp",
    "src/mutex_destructor.cpp",
    "src/new.cpp",
    "src/optional.cpp",
    "src/random.cpp",
    "src/random_shuffle.cpp",
    "src/regex.cpp",
    "src/ryu/d2fixed.cpp",
    "src/ryu/d2s.cpp",
    "src/ryu/f2s.cpp",
    "src/shared_mutex.cpp",
    "src/stdexcept.cpp",
    "src/string.cpp",
    "src/strstream.cpp",
    "src/support/ibm/mbsnrtowcs.cpp",
    "src/support/ibm/wcsnrtombs.cpp",
    "src/support/ibm/xlocale_zos.cpp",
    "src/support/solaris/xlocale.cpp",
    "src/support/win32/locale_win32.cpp",
    "src/support/win32/support.cpp",
    "src/support/win32/thread_win32.cpp",
    "src/system_error.cpp",
    "src/thread.cpp",
    "src/typeinfo.cpp",
    "src/utility.cpp",
    "src/valarray.cpp",
    "src/variant.cpp",
    "src/vector.cpp",
};

pub fn buildLibCXX(comp: *Compilation) !void {
    if (!build_options.have_llvm) {
        return error.ZigCompilerNotBuiltWithLLVMExtensions;
    }

    const tracy = trace(@src());
    defer tracy.end();

    var arena_allocator = std.heap.ArenaAllocator.init(comp.gpa);
    defer arena_allocator.deinit();
    const arena = arena_allocator.allocator();

    const root_name = "c++";
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

    const cxxabi_include_path = try comp.zig_lib_directory.join(arena, &[_][]const u8{ "libcxxabi", "include" });
    const cxx_include_path = try comp.zig_lib_directory.join(arena, &[_][]const u8{ "libcxx", "include" });
    const cxx_src_include_path = try comp.zig_lib_directory.join(arena, &[_][]const u8{ "libcxx", "src" });
    var c_source_files = try std.ArrayList(Compilation.CSourceFile).initCapacity(arena, libcxx_files.len);

    for (libcxx_files) |cxx_src| {
        var cflags = std.ArrayList([]const u8).init(arena);

        if ((target.os.tag == .windows and target.abi == .msvc) or target.os.tag == .wasi) {
            // Filesystem stuff isn't supported on WASI and Windows (MSVC).
            if (std.mem.startsWith(u8, cxx_src, "src/filesystem/"))
                continue;
        }

        if (std.mem.startsWith(u8, cxx_src, "src/support/win32/") and target.os.tag != .windows)
            continue;
        if (std.mem.startsWith(u8, cxx_src, "src/support/solaris/") and target.os.tag != .solaris)
            continue;
        if (std.mem.startsWith(u8, cxx_src, "src/support/ibm/") and target.os.tag != .zos)
            continue;
        if (comp.bin_file.options.single_threaded) {
            if (std.mem.startsWith(u8, cxx_src, "src/support/win32/thread_win32.cpp")) {
                continue;
            }
            try cflags.append("-D_LIBCPP_HAS_NO_THREADS");
        }

        try cflags.append("-DNDEBUG");
        try cflags.append("-D_LIBCPP_BUILDING_LIBRARY");
        try cflags.append("-D_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER");
        try cflags.append("-DLIBCXX_BUILDING_LIBCXXABI");
        try cflags.append("-D_LIBCXXABI_DISABLE_VISIBILITY_ANNOTATIONS");
        try cflags.append("-D_LIBCPP_DISABLE_VISIBILITY_ANNOTATIONS");
        try cflags.append("-D_LIBCPP_DISABLE_NEW_DELETE_DEFINITIONS");
        try cflags.append("-D_LIBCPP_HAS_NO_VENDOR_AVAILABILITY_ANNOTATIONS");
        try cflags.append("-fvisibility=hidden");
        try cflags.append("-fvisibility-inlines-hidden");

        if (target.abi.isMusl()) {
            try cflags.append("-D_LIBCPP_HAS_MUSL_LIBC");
        }

        if (target.os.tag == .wasi) {
            // WASI doesn't support exceptions yet.
            try cflags.append("-fno-exceptions");
        }

        if (target.os.tag == .zos) {
            try cflags.append("-fno-aligned-allocation");
        } else {
            try cflags.append("-faligned-allocation");
        }

        try cflags.append("-I");
        try cflags.append(cxx_include_path);

        try cflags.append("-I");
        try cflags.append(cxxabi_include_path);

        try cflags.append("-I");
        try cflags.append(cxx_src_include_path);

        if (target_util.supports_fpic(target)) {
            try cflags.append("-fPIC");
        }
        try cflags.append("-nostdinc++");
        try cflags.append("-std=c++20");
        try cflags.append("-Wno-user-defined-literals");

        c_source_files.appendAssumeCapacity(.{
            .src_path = try comp.zig_lib_directory.join(arena, &[_][]const u8{ "libcxx", cxx_src }),
            .extra_flags = cflags.items,
        });
    }

    const sub_compilation = try Compilation.create(comp.gpa, .{
        .local_cache_directory = comp.global_cache_directory,
        .global_cache_directory = comp.global_cache_directory,
        .zig_lib_directory = comp.zig_lib_directory,
        .cache_mode = .whole,
        .target = target,
        .root_name = root_name,
        .main_pkg = null,
        .output_mode = output_mode,
        .thread_pool = comp.thread_pool,
        .libc_installation = comp.bin_file.options.libc_installation,
        .emit_bin = emit_bin,
        .optimize_mode = comp.compilerRtOptMode(),
        .link_mode = link_mode,
        .want_sanitize_c = false,
        .want_stack_check = false,
        .want_red_zone = comp.bin_file.options.red_zone,
        .omit_frame_pointer = comp.bin_file.options.omit_frame_pointer,
        .want_valgrind = false,
        .want_tsan = comp.bin_file.options.tsan,
        .want_pic = comp.bin_file.options.pic,
        .want_pie = comp.bin_file.options.pie,
        .want_lto = comp.bin_file.options.lto,
        .function_sections = comp.bin_file.options.function_sections,
        .emit_h = null,
        .strip = comp.compilerRtStrip(),
        .is_native_os = comp.bin_file.options.is_native_os,
        .is_native_abi = comp.bin_file.options.is_native_abi,
        .self_exe_path = comp.self_exe_path,
        .c_source_files = c_source_files.items,
        .verbose_cc = comp.verbose_cc,
        .verbose_link = comp.bin_file.options.verbose_link,
        .verbose_air = comp.verbose_air,
        .verbose_llvm_ir = comp.verbose_llvm_ir,
        .verbose_cimport = comp.verbose_cimport,
        .verbose_llvm_cpu_features = comp.verbose_llvm_cpu_features,
        .clang_passthrough_mode = comp.clang_passthrough_mode,
        .link_libc = true,
        .skip_linker_dependencies = true,
    });
    defer sub_compilation.destroy();

    try sub_compilation.updateSubCompilation();

    assert(comp.libcxx_static_lib == null);
    comp.libcxx_static_lib = Compilation.CRTFile{
        .full_object_path = try sub_compilation.bin_file.options.emit.?.directory.join(comp.gpa, &[_][]const u8{
            sub_compilation.bin_file.options.emit.?.sub_path,
        }),
        .lock = sub_compilation.bin_file.toOwnedLock(),
    };
}

pub fn buildLibCXXABI(comp: *Compilation) !void {
    if (!build_options.have_llvm) {
        return error.ZigCompilerNotBuiltWithLLVMExtensions;
    }

    const tracy = trace(@src());
    defer tracy.end();

    var arena_allocator = std.heap.ArenaAllocator.init(comp.gpa);
    defer arena_allocator.deinit();
    const arena = arena_allocator.allocator();

    const root_name = "c++abi";
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

    const cxxabi_include_path = try comp.zig_lib_directory.join(arena, &[_][]const u8{ "libcxxabi", "include" });
    const cxx_include_path = try comp.zig_lib_directory.join(arena, &[_][]const u8{ "libcxx", "include" });
    const cxx_src_include_path = try comp.zig_lib_directory.join(arena, &[_][]const u8{ "libcxx", "src" });
    var c_source_files = try std.ArrayList(Compilation.CSourceFile).initCapacity(arena, libcxxabi_files.len);

    for (libcxxabi_files) |cxxabi_src| {
        var cflags = std.ArrayList([]const u8).init(arena);

        if (target.os.tag == .wasi) {
            // WASI doesn't support exceptions yet.
            if (std.mem.startsWith(u8, cxxabi_src, "src/cxa_exception.cpp") or
                std.mem.startsWith(u8, cxxabi_src, "src/cxa_personality.cpp"))
                continue;
            try cflags.append("-fno-exceptions");
        }

        // WASM targets are single threaded.
        if (comp.bin_file.options.single_threaded) {
            if (std.mem.startsWith(u8, cxxabi_src, "src/cxa_thread_atexit.cpp")) {
                continue;
            }
            try cflags.append("-D_LIBCXXABI_HAS_NO_THREADS");
            try cflags.append("-D_LIBCPP_HAS_NO_THREADS");
        } else {
            try cflags.append("-DHAVE___CXA_THREAD_ATEXIT_IMPL");
        }

        try cflags.append("-D_LIBCPP_DISABLE_EXTERN_TEMPLATE");
        try cflags.append("-D_LIBCPP_ENABLE_CXX17_REMOVED_UNEXPECTED_FUNCTIONS");
        try cflags.append("-D_LIBCXXABI_BUILDING_LIBRARY");
        try cflags.append("-D_LIBCXXABI_DISABLE_VISIBILITY_ANNOTATIONS");
        try cflags.append("-D_LIBCPP_DISABLE_VISIBILITY_ANNOTATIONS");
        try cflags.append("-fvisibility=hidden");
        try cflags.append("-fvisibility-inlines-hidden");

        if (target.abi.isMusl()) {
            try cflags.append("-D_LIBCPP_HAS_MUSL_LIBC");
        }

        try cflags.append("-I");
        try cflags.append(cxxabi_include_path);

        try cflags.append("-I");
        try cflags.append(cxx_include_path);

        try cflags.append("-I");
        try cflags.append(cxx_src_include_path);

        if (target_util.supports_fpic(target)) {
            try cflags.append("-fPIC");
        }
        try cflags.append("-nostdinc++");
        try cflags.append("-fstrict-aliasing");
        try cflags.append("-funwind-tables");
        try cflags.append("-std=c++11");

        c_source_files.appendAssumeCapacity(.{
            .src_path = try comp.zig_lib_directory.join(arena, &[_][]const u8{ "libcxxabi", cxxabi_src }),
            .extra_flags = cflags.items,
        });
    }

    const sub_compilation = try Compilation.create(comp.gpa, .{
        .local_cache_directory = comp.global_cache_directory,
        .global_cache_directory = comp.global_cache_directory,
        .zig_lib_directory = comp.zig_lib_directory,
        .cache_mode = .whole,
        .target = target,
        .root_name = root_name,
        .main_pkg = null,
        .output_mode = output_mode,
        .thread_pool = comp.thread_pool,
        .libc_installation = comp.bin_file.options.libc_installation,
        .emit_bin = emit_bin,
        .optimize_mode = comp.compilerRtOptMode(),
        .link_mode = link_mode,
        .want_sanitize_c = false,
        .want_stack_check = false,
        .want_red_zone = comp.bin_file.options.red_zone,
        .omit_frame_pointer = comp.bin_file.options.omit_frame_pointer,
        .want_valgrind = false,
        .want_tsan = comp.bin_file.options.tsan,
        .want_pic = comp.bin_file.options.pic,
        .want_pie = comp.bin_file.options.pie,
        .want_lto = comp.bin_file.options.lto,
        .function_sections = comp.bin_file.options.function_sections,
        .emit_h = null,
        .strip = comp.compilerRtStrip(),
        .is_native_os = comp.bin_file.options.is_native_os,
        .is_native_abi = comp.bin_file.options.is_native_abi,
        .self_exe_path = comp.self_exe_path,
        .c_source_files = c_source_files.items,
        .verbose_cc = comp.verbose_cc,
        .verbose_link = comp.bin_file.options.verbose_link,
        .verbose_air = comp.verbose_air,
        .verbose_llvm_ir = comp.verbose_llvm_ir,
        .verbose_cimport = comp.verbose_cimport,
        .verbose_llvm_cpu_features = comp.verbose_llvm_cpu_features,
        .clang_passthrough_mode = comp.clang_passthrough_mode,
        .link_libc = true,
        .skip_linker_dependencies = true,
    });
    defer sub_compilation.destroy();

    try sub_compilation.updateSubCompilation();

    assert(comp.libcxxabi_static_lib == null);
    comp.libcxxabi_static_lib = Compilation.CRTFile{
        .full_object_path = try sub_compilation.bin_file.options.emit.?.directory.join(comp.gpa, &[_][]const u8{
            sub_compilation.bin_file.options.emit.?.sub_path,
        }),
        .lock = sub_compilation.bin_file.toOwnedLock(),
    };
}
