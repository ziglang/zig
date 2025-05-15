const std = @import("std");
const mem = std.mem;
const path = std.fs.path;

const Allocator = std.mem.Allocator;
const Compilation = @import("../Compilation.zig");
const build_options = @import("build_options");

pub const CrtFile = enum {
    crt1_reactor_o,
    crt1_command_o,
    libc_a,
    libdl_a,
    libwasi_emulated_process_clocks_a,
    libwasi_emulated_getpid_a,
    libwasi_emulated_mman_a,
    libwasi_emulated_signal_a,
};

pub fn getEmulatedLibCrtFile(lib_name: []const u8) ?CrtFile {
    if (mem.eql(u8, lib_name, "dl")) {
        return .libdl_a;
    }
    if (mem.eql(u8, lib_name, "wasi-emulated-process-clocks")) {
        return .libwasi_emulated_process_clocks_a;
    }
    if (mem.eql(u8, lib_name, "wasi-emulated-getpid")) {
        return .libwasi_emulated_getpid_a;
    }
    if (mem.eql(u8, lib_name, "wasi-emulated-mman")) {
        return .libwasi_emulated_mman_a;
    }
    if (mem.eql(u8, lib_name, "wasi-emulated-signal")) {
        return .libwasi_emulated_signal_a;
    }
    return null;
}

pub fn emulatedLibCRFileLibName(crt_file: CrtFile) []const u8 {
    return switch (crt_file) {
        .libdl_a => "libdl.a",
        .libwasi_emulated_process_clocks_a => "libwasi-emulated-process-clocks.a",
        .libwasi_emulated_getpid_a => "libwasi-emulated-getpid.a",
        .libwasi_emulated_mman_a => "libwasi-emulated-mman.a",
        .libwasi_emulated_signal_a => "libwasi-emulated-signal.a",
        else => unreachable,
    };
}

pub fn execModelCrtFile(wasi_exec_model: std.builtin.WasiExecModel) CrtFile {
    return switch (wasi_exec_model) {
        .reactor => CrtFile.crt1_reactor_o,
        .command => CrtFile.crt1_command_o,
    };
}

pub fn execModelCrtFileFullName(wasi_exec_model: std.builtin.WasiExecModel) []const u8 {
    return switch (execModelCrtFile(wasi_exec_model)) {
        .crt1_reactor_o => "crt1-reactor.o",
        .crt1_command_o => "crt1-command.o",
        else => unreachable,
    };
}

/// TODO replace anyerror with explicit error set, recording user-friendly errors with
/// setMiscFailure and returning error.SubCompilationFailed. see libcxx.zig for example.
pub fn buildCrtFile(comp: *Compilation, crt_file: CrtFile, prog_node: std.Progress.Node) anyerror!void {
    if (!build_options.have_llvm) {
        return error.ZigCompilerNotBuiltWithLLVMExtensions;
    }

    const gpa = comp.gpa;
    var arena_allocator = std.heap.ArenaAllocator.init(gpa);
    defer arena_allocator.deinit();
    const arena = arena_allocator.allocator();

    switch (crt_file) {
        .crt1_reactor_o => {
            var args = std.ArrayList([]const u8).init(arena);
            try addCCArgs(comp, arena, &args, .{});
            try addLibcBottomHalfIncludes(comp, arena, &args);
            var files = [_]Compilation.CSourceFile{
                .{
                    .src_path = try comp.zig_lib_directory.join(arena, &[_][]const u8{
                        "libc", try sanitize(arena, crt1_reactor_src_file),
                    }),
                    .extra_flags = args.items,
                    .owner = undefined,
                },
            };
            return comp.build_crt_file("crt1-reactor", .Obj, .@"wasi crt1-reactor.o", prog_node, &files, .{});
        },
        .crt1_command_o => {
            var args = std.ArrayList([]const u8).init(arena);
            try addCCArgs(comp, arena, &args, .{});
            try addLibcBottomHalfIncludes(comp, arena, &args);
            var files = [_]Compilation.CSourceFile{
                .{
                    .src_path = try comp.zig_lib_directory.join(arena, &[_][]const u8{
                        "libc", try sanitize(arena, crt1_command_src_file),
                    }),
                    .extra_flags = args.items,
                    .owner = undefined,
                },
            };
            return comp.build_crt_file("crt1-command", .Obj, .@"wasi crt1-command.o", prog_node, &files, .{});
        },
        .libc_a => {
            var libc_sources = std.ArrayList(Compilation.CSourceFile).init(arena);

            {
                // Compile emmalloc.
                var args = std.ArrayList([]const u8).init(arena);
                try addCCArgs(comp, arena, &args, .{ .want_O3 = true, .no_strict_aliasing = true });
                for (emmalloc_src_files) |file_path| {
                    try libc_sources.append(.{
                        .src_path = try comp.zig_lib_directory.join(arena, &[_][]const u8{
                            "libc", try sanitize(arena, file_path),
                        }),
                        .extra_flags = args.items,
                        .owner = undefined,
                    });
                }
            }

            {
                // Compile libc-bottom-half.
                var args = std.ArrayList([]const u8).init(arena);
                try addCCArgs(comp, arena, &args, .{ .want_O3 = true });
                try addLibcBottomHalfIncludes(comp, arena, &args);

                for (libc_bottom_half_src_files) |file_path| {
                    try libc_sources.append(.{
                        .src_path = try comp.zig_lib_directory.join(arena, &[_][]const u8{
                            "libc", try sanitize(arena, file_path),
                        }),
                        .extra_flags = args.items,
                        .owner = undefined,
                    });
                }
            }

            {
                // Compile libc-top-half.
                var args = std.ArrayList([]const u8).init(arena);
                try addCCArgs(comp, arena, &args, .{ .want_O3 = true });
                try addLibcTopHalfIncludes(comp, arena, &args);

                for (libc_top_half_src_files) |file_path| {
                    try libc_sources.append(.{
                        .src_path = try comp.zig_lib_directory.join(arena, &[_][]const u8{
                            "libc", try sanitize(arena, file_path),
                        }),
                        .extra_flags = args.items,
                        .owner = undefined,
                    });
                }
            }

            try comp.build_crt_file("c", .Lib, .@"wasi libc.a", prog_node, libc_sources.items, .{});
        },

        .libdl_a => {
            var args = std.ArrayList([]const u8).init(arena);
            try addCCArgs(comp, arena, &args, .{ .want_O3 = true });
            try addLibcBottomHalfIncludes(comp, arena, &args);

            var emu_dl_sources = std.ArrayList(Compilation.CSourceFile).init(arena);
            for (emulated_dl_src_files) |file_path| {
                try emu_dl_sources.append(.{
                    .src_path = try comp.zig_lib_directory.join(arena, &[_][]const u8{
                        "libc", try sanitize(arena, file_path),
                    }),
                    .extra_flags = args.items,
                    .owner = undefined,
                });
            }
            try comp.build_crt_file("dl", .Lib, .@"wasi libdl.a", prog_node, emu_dl_sources.items, .{});
        },

        .libwasi_emulated_process_clocks_a => {
            var args = std.ArrayList([]const u8).init(arena);
            try addCCArgs(comp, arena, &args, .{ .want_O3 = true });
            try addLibcBottomHalfIncludes(comp, arena, &args);

            var emu_clocks_sources = std.ArrayList(Compilation.CSourceFile).init(arena);
            for (emulated_process_clocks_src_files) |file_path| {
                try emu_clocks_sources.append(.{
                    .src_path = try comp.zig_lib_directory.join(arena, &[_][]const u8{
                        "libc", try sanitize(arena, file_path),
                    }),
                    .extra_flags = args.items,
                    .owner = undefined,
                });
            }
            try comp.build_crt_file("wasi-emulated-process-clocks", .Lib, .@"libwasi-emulated-process-clocks.a", prog_node, emu_clocks_sources.items, .{});
        },
        .libwasi_emulated_getpid_a => {
            var args = std.ArrayList([]const u8).init(arena);
            try addCCArgs(comp, arena, &args, .{ .want_O3 = true });
            try addLibcBottomHalfIncludes(comp, arena, &args);

            var emu_getpid_sources = std.ArrayList(Compilation.CSourceFile).init(arena);
            for (emulated_getpid_src_files) |file_path| {
                try emu_getpid_sources.append(.{
                    .src_path = try comp.zig_lib_directory.join(arena, &[_][]const u8{
                        "libc", try sanitize(arena, file_path),
                    }),
                    .extra_flags = args.items,
                    .owner = undefined,
                });
            }
            try comp.build_crt_file("wasi-emulated-getpid", .Lib, .@"libwasi-emulated-getpid.a", prog_node, emu_getpid_sources.items, .{});
        },
        .libwasi_emulated_mman_a => {
            var args = std.ArrayList([]const u8).init(arena);
            try addCCArgs(comp, arena, &args, .{ .want_O3 = true });
            try addLibcBottomHalfIncludes(comp, arena, &args);

            var emu_mman_sources = std.ArrayList(Compilation.CSourceFile).init(arena);
            for (emulated_mman_src_files) |file_path| {
                try emu_mman_sources.append(.{
                    .src_path = try comp.zig_lib_directory.join(arena, &[_][]const u8{
                        "libc", try sanitize(arena, file_path),
                    }),
                    .extra_flags = args.items,
                    .owner = undefined,
                });
            }
            try comp.build_crt_file("wasi-emulated-mman", .Lib, .@"libwasi-emulated-mman.a", prog_node, emu_mman_sources.items, .{});
        },
        .libwasi_emulated_signal_a => {
            var emu_signal_sources = std.ArrayList(Compilation.CSourceFile).init(arena);

            {
                var args = std.ArrayList([]const u8).init(arena);
                try addCCArgs(comp, arena, &args, .{ .want_O3 = true });

                for (emulated_signal_bottom_half_src_files) |file_path| {
                    try emu_signal_sources.append(.{
                        .src_path = try comp.zig_lib_directory.join(arena, &[_][]const u8{
                            "libc", try sanitize(arena, file_path),
                        }),
                        .extra_flags = args.items,
                        .owner = undefined,
                    });
                }
            }

            {
                var args = std.ArrayList([]const u8).init(arena);
                try addCCArgs(comp, arena, &args, .{ .want_O3 = true });
                try addLibcTopHalfIncludes(comp, arena, &args);
                try args.append("-D_WASI_EMULATED_SIGNAL");

                for (emulated_signal_top_half_src_files) |file_path| {
                    try emu_signal_sources.append(.{
                        .src_path = try comp.zig_lib_directory.join(arena, &[_][]const u8{
                            "libc", try sanitize(arena, file_path),
                        }),
                        .extra_flags = args.items,
                        .owner = undefined,
                    });
                }
            }

            try comp.build_crt_file("wasi-emulated-signal", .Lib, .@"libwasi-emulated-signal.a", prog_node, emu_signal_sources.items, .{});
        },
    }
}

fn sanitize(arena: Allocator, file_path: []const u8) ![]const u8 {
    // TODO do this at comptime on the comptime data rather than at runtime
    // probably best to wait until self-hosted is done and our comptime execution
    // is faster and uses less memory.
    const out_path = if (path.sep != '/') blk: {
        const mutable_file_path = try arena.dupe(u8, file_path);
        for (mutable_file_path) |*c| {
            if (c.* == '/') {
                c.* = path.sep;
            }
        }
        break :blk mutable_file_path;
    } else file_path;
    return out_path;
}

const CCOptions = struct {
    want_O3: bool = false,
    no_strict_aliasing: bool = false,
};

fn addCCArgs(
    comp: *Compilation,
    arena: Allocator,
    args: *std.ArrayList([]const u8),
    options: CCOptions,
) error{OutOfMemory}!void {
    const target = comp.getTarget();
    const arch_name = std.zig.target.muslArchNameHeaders(target.cpu.arch);
    const os_name = @tagName(target.os.tag);
    const triple = try std.fmt.allocPrint(arena, "{s}-{s}-musl", .{ arch_name, os_name });
    const o_arg = if (options.want_O3) "-O3" else "-Os";

    try args.appendSlice(&[_][]const u8{
        "-std=gnu17",
        "-fno-trapping-math",
        "-w", // ignore all warnings

        o_arg,

        "-mthread-model",
        "single",

        "-isysroot",
        "/",

        "-iwithsysroot",
        try comp.zig_lib_directory.join(arena, &[_][]const u8{ "libc", "include", triple }),

        "-iwithsysroot",
        try comp.zig_lib_directory.join(arena, &[_][]const u8{ "libc", "include", "generic-musl" }),

        "-DBULK_MEMORY_THRESHOLD=32",
    });

    if (options.no_strict_aliasing) {
        try args.appendSlice(&[_][]const u8{"-fno-strict-aliasing"});
    }
}

fn addLibcBottomHalfIncludes(
    comp: *Compilation,
    arena: Allocator,
    args: *std.ArrayList([]const u8),
) error{OutOfMemory}!void {
    try args.appendSlice(&[_][]const u8{
        "-I",
        try comp.zig_lib_directory.join(arena, &[_][]const u8{
            "libc",
            "wasi",
            "libc-bottom-half",
            "headers",
            "private",
        }),

        "-I",
        try comp.zig_lib_directory.join(arena, &[_][]const u8{
            "libc",
            "wasi",
            "libc-bottom-half",
            "cloudlibc",
            "src",
            "include",
        }),

        "-I",
        try comp.zig_lib_directory.join(arena, &[_][]const u8{
            "libc",
            "wasi",
            "libc-bottom-half",
            "cloudlibc",
            "src",
        }),

        "-I",
        try comp.zig_lib_directory.join(arena, &[_][]const u8{
            "libc",
            "wasi",
            "libc-top-half",
            "musl",
            "src",
            "include",
        }),

        "-I",
        try comp.zig_lib_directory.join(arena, &[_][]const u8{
            "libc",
            "musl",
            "src",
            "include",
        }),

        "-I",
        try comp.zig_lib_directory.join(arena, &[_][]const u8{
            "libc",
            "wasi",
            "libc-top-half",
            "musl",
            "src",
            "internal",
        }),

        "-I",
        try comp.zig_lib_directory.join(arena, &[_][]const u8{
            "libc",
            "musl",
            "src",
            "internal",
        }),
    });
}

fn addLibcTopHalfIncludes(
    comp: *Compilation,
    arena: Allocator,
    args: *std.ArrayList([]const u8),
) error{OutOfMemory}!void {
    try args.appendSlice(&[_][]const u8{
        "-I",
        try comp.zig_lib_directory.join(arena, &[_][]const u8{
            "libc",
            "wasi",
            "libc-top-half",
            "musl",
            "src",
            "include",
        }),

        "-I",
        try comp.zig_lib_directory.join(arena, &[_][]const u8{
            "libc",
            "musl",
            "src",
            "include",
        }),

        "-I",
        try comp.zig_lib_directory.join(arena, &[_][]const u8{
            "libc",
            "wasi",
            "libc-top-half",
            "musl",
            "src",
            "internal",
        }),

        "-I",
        try comp.zig_lib_directory.join(arena, &[_][]const u8{
            "libc",
            "musl",
            "src",
            "internal",
        }),

        "-I",
        try comp.zig_lib_directory.join(arena, &[_][]const u8{
            "libc",
            "wasi",
            "libc-top-half",
            "musl",
            "arch",
            "wasm32",
        }),

        "-I",
        try comp.zig_lib_directory.join(arena, &[_][]const u8{
            "libc",
            "musl",
            "arch",
            "generic",
        }),

        "-I",
        try comp.zig_lib_directory.join(arena, &[_][]const u8{
            "libc",
            "wasi",
            "libc-top-half",
            "headers",
            "private",
        }),
    });
}

const emmalloc_src_files = [_][]const u8{
    "wasi/emmalloc/emmalloc.c",
};

const libc_bottom_half_src_files = [_][]const u8{
    "wasi/libc-bottom-half/cloudlibc/src/libc/dirent/closedir.c",
    "wasi/libc-bottom-half/cloudlibc/src/libc/dirent/dirfd.c",
    "wasi/libc-bottom-half/cloudlibc/src/libc/dirent/fdclosedir.c",
    "wasi/libc-bottom-half/cloudlibc/src/libc/dirent/fdopendir.c",
    "wasi/libc-bottom-half/cloudlibc/src/libc/dirent/opendirat.c",
    "wasi/libc-bottom-half/cloudlibc/src/libc/dirent/readdir.c",
    "wasi/libc-bottom-half/cloudlibc/src/libc/dirent/rewinddir.c",
    "wasi/libc-bottom-half/cloudlibc/src/libc/dirent/scandirat.c",
    "wasi/libc-bottom-half/cloudlibc/src/libc/dirent/seekdir.c",
    "wasi/libc-bottom-half/cloudlibc/src/libc/dirent/telldir.c",
    "wasi/libc-bottom-half/cloudlibc/src/libc/errno/errno.c",
    "wasi/libc-bottom-half/cloudlibc/src/libc/fcntl/fcntl.c",
    "wasi/libc-bottom-half/cloudlibc/src/libc/fcntl/openat.c",
    "wasi/libc-bottom-half/cloudlibc/src/libc/fcntl/posix_fadvise.c",
    "wasi/libc-bottom-half/cloudlibc/src/libc/fcntl/posix_fallocate.c",
    "wasi/libc-bottom-half/cloudlibc/src/libc/poll/poll.c",
    "wasi/libc-bottom-half/cloudlibc/src/libc/sched/sched_yield.c",
    "wasi/libc-bottom-half/cloudlibc/src/libc/stdio/renameat.c",
    "wasi/libc-bottom-half/cloudlibc/src/libc/stdlib/_Exit.c",
    "wasi/libc-bottom-half/cloudlibc/src/libc/sys/ioctl/ioctl.c",
    "wasi/libc-bottom-half/cloudlibc/src/libc/sys/select/pselect.c",
    "wasi/libc-bottom-half/cloudlibc/src/libc/sys/select/select.c",
    "wasi/libc-bottom-half/cloudlibc/src/libc/sys/socket/getsockopt.c",
    "wasi/libc-bottom-half/cloudlibc/src/libc/sys/socket/recv.c",
    "wasi/libc-bottom-half/cloudlibc/src/libc/sys/socket/send.c",
    "wasi/libc-bottom-half/cloudlibc/src/libc/sys/socket/shutdown.c",
    "wasi/libc-bottom-half/cloudlibc/src/libc/sys/stat/fstat.c",
    "wasi/libc-bottom-half/cloudlibc/src/libc/sys/stat/fstatat.c",
    "wasi/libc-bottom-half/cloudlibc/src/libc/sys/stat/futimens.c",
    "wasi/libc-bottom-half/cloudlibc/src/libc/sys/stat/mkdirat.c",
    "wasi/libc-bottom-half/cloudlibc/src/libc/sys/stat/utimensat.c",
    "wasi/libc-bottom-half/cloudlibc/src/libc/sys/time/gettimeofday.c",
    "wasi/libc-bottom-half/cloudlibc/src/libc/sys/uio/preadv.c",
    "wasi/libc-bottom-half/cloudlibc/src/libc/sys/uio/pwritev.c",
    "wasi/libc-bottom-half/cloudlibc/src/libc/sys/uio/readv.c",
    "wasi/libc-bottom-half/cloudlibc/src/libc/sys/uio/writev.c",
    "wasi/libc-bottom-half/cloudlibc/src/libc/time/CLOCK_MONOTONIC.c",
    "wasi/libc-bottom-half/cloudlibc/src/libc/time/CLOCK_REALTIME.c",
    "wasi/libc-bottom-half/cloudlibc/src/libc/time/clock_getres.c",
    "wasi/libc-bottom-half/cloudlibc/src/libc/time/clock_gettime.c",
    "wasi/libc-bottom-half/cloudlibc/src/libc/time/clock_nanosleep.c",
    "wasi/libc-bottom-half/cloudlibc/src/libc/time/nanosleep.c",
    "wasi/libc-bottom-half/cloudlibc/src/libc/time/time.c",
    "wasi/libc-bottom-half/cloudlibc/src/libc/unistd/faccessat.c",
    "wasi/libc-bottom-half/cloudlibc/src/libc/unistd/fdatasync.c",
    "wasi/libc-bottom-half/cloudlibc/src/libc/unistd/fsync.c",
    "wasi/libc-bottom-half/cloudlibc/src/libc/unistd/ftruncate.c",
    "wasi/libc-bottom-half/cloudlibc/src/libc/unistd/linkat.c",
    "wasi/libc-bottom-half/cloudlibc/src/libc/unistd/lseek.c",
    "wasi/libc-bottom-half/cloudlibc/src/libc/unistd/pread.c",
    "wasi/libc-bottom-half/cloudlibc/src/libc/unistd/pwrite.c",
    "wasi/libc-bottom-half/cloudlibc/src/libc/unistd/read.c",
    "wasi/libc-bottom-half/cloudlibc/src/libc/unistd/readlinkat.c",
    "wasi/libc-bottom-half/cloudlibc/src/libc/unistd/sleep.c",
    "wasi/libc-bottom-half/cloudlibc/src/libc/unistd/symlinkat.c",
    "wasi/libc-bottom-half/cloudlibc/src/libc/unistd/unlinkat.c",
    "wasi/libc-bottom-half/cloudlibc/src/libc/unistd/usleep.c",
    "wasi/libc-bottom-half/cloudlibc/src/libc/unistd/write.c",
    "wasi/libc-bottom-half/sources/__errno_location.c",
    "wasi/libc-bottom-half/sources/__main_void.c",
    "wasi/libc-bottom-half/sources/__wasilibc_dt.c",
    "wasi/libc-bottom-half/sources/__wasilibc_environ.c",
    "wasi/libc-bottom-half/sources/__wasilibc_fd_renumber.c",
    "wasi/libc-bottom-half/sources/__wasilibc_initialize_environ.c",
    "wasi/libc-bottom-half/sources/__wasilibc_real.c",
    "wasi/libc-bottom-half/sources/__wasilibc_rmdirat.c",
    "wasi/libc-bottom-half/sources/__wasilibc_tell.c",
    "wasi/libc-bottom-half/sources/__wasilibc_unlinkat.c",
    "wasi/libc-bottom-half/sources/abort.c",
    "wasi/libc-bottom-half/sources/accept-wasip1.c",
    "wasi/libc-bottom-half/sources/at_fdcwd.c",
    "wasi/libc-bottom-half/sources/complex-builtins.c",
    "wasi/libc-bottom-half/sources/environ.c",
    "wasi/libc-bottom-half/sources/errno.c",
    "wasi/libc-bottom-half/sources/getcwd.c",
    "wasi/libc-bottom-half/sources/getentropy.c",
    "wasi/libc-bottom-half/sources/isatty.c",
    "wasi/libc-bottom-half/sources/math/fmin-fmax.c",
    "wasi/libc-bottom-half/sources/math/math-builtins.c",
    "wasi/libc-bottom-half/sources/posix.c",
    "wasi/libc-bottom-half/sources/preopens.c",
    "wasi/libc-bottom-half/sources/reallocarray.c",
    "wasi/libc-bottom-half/sources/sbrk.c",
    "wasi/libc-bottom-half/sources/truncate.c",
    "wasi/libc-bottom-half/sources/chdir.c",
};

const libc_top_half_src_files = [_][]const u8{
    "musl/src/complex/cabs.c",
    "musl/src/complex/cabsf.c",
    "musl/src/complex/cabsl.c",
    "musl/src/complex/cacos.c",
    "musl/src/complex/cacosf.c",
    "musl/src/complex/cacosh.c",
    "musl/src/complex/cacoshf.c",
    "musl/src/complex/cacoshl.c",
    "musl/src/complex/cacosl.c",
    "musl/src/complex/carg.c",
    "musl/src/complex/cargf.c",
    "musl/src/complex/cargl.c",
    "musl/src/complex/casin.c",
    "musl/src/complex/casinf.c",
    "musl/src/complex/casinh.c",
    "musl/src/complex/casinhf.c",
    "musl/src/complex/casinhl.c",
    "musl/src/complex/casinl.c",
    "musl/src/complex/catan.c",
    "musl/src/complex/catanf.c",
    "musl/src/complex/catanh.c",
    "musl/src/complex/catanhf.c",
    "musl/src/complex/catanhl.c",
    "musl/src/complex/catanl.c",
    "musl/src/complex/ccos.c",
    "musl/src/complex/ccosf.c",
    "musl/src/complex/ccosh.c",
    "musl/src/complex/ccoshf.c",
    "musl/src/complex/ccoshl.c",
    "musl/src/complex/ccosl.c",
    "musl/src/complex/__cexp.c",
    "musl/src/complex/cexp.c",
    "musl/src/complex/__cexpf.c",
    "musl/src/complex/cexpf.c",
    "musl/src/complex/cexpl.c",
    "musl/src/complex/clog.c",
    "musl/src/complex/clogf.c",
    "musl/src/complex/clogl.c",
    "musl/src/complex/conj.c",
    "musl/src/complex/conjf.c",
    "musl/src/complex/conjl.c",
    "musl/src/complex/cpow.c",
    "musl/src/complex/cpowf.c",
    "musl/src/complex/cpowl.c",
    "musl/src/complex/cproj.c",
    "musl/src/complex/cprojf.c",
    "musl/src/complex/cprojl.c",
    "musl/src/complex/csin.c",
    "musl/src/complex/csinf.c",
    "musl/src/complex/csinh.c",
    "musl/src/complex/csinhf.c",
    "musl/src/complex/csinhl.c",
    "musl/src/complex/csinl.c",
    "musl/src/complex/csqrt.c",
    "musl/src/complex/csqrtf.c",
    "musl/src/complex/csqrtl.c",
    "musl/src/complex/ctan.c",
    "musl/src/complex/ctanf.c",
    "musl/src/complex/ctanh.c",
    "musl/src/complex/ctanhf.c",
    "musl/src/complex/ctanhl.c",
    "musl/src/complex/ctanl.c",
    "musl/src/conf/legacy.c",
    "musl/src/conf/pathconf.c",
    "musl/src/crypt/crypt_blowfish.c",
    "musl/src/crypt/crypt.c",
    "musl/src/crypt/crypt_des.c",
    "musl/src/crypt/crypt_md5.c",
    "musl/src/crypt/crypt_r.c",
    "musl/src/crypt/crypt_sha256.c",
    "musl/src/crypt/crypt_sha512.c",
    "musl/src/crypt/encrypt.c",
    "musl/src/ctype/__ctype_b_loc.c",
    "musl/src/ctype/__ctype_get_mb_cur_max.c",
    "musl/src/ctype/__ctype_tolower_loc.c",
    "musl/src/ctype/__ctype_toupper_loc.c",
    "musl/src/ctype/isalnum.c",
    "musl/src/ctype/isalpha.c",
    "musl/src/ctype/isascii.c",
    "musl/src/ctype/isblank.c",
    "musl/src/ctype/iscntrl.c",
    "musl/src/ctype/isdigit.c",
    "musl/src/ctype/isgraph.c",
    "musl/src/ctype/islower.c",
    "musl/src/ctype/isprint.c",
    "musl/src/ctype/ispunct.c",
    "musl/src/ctype/isspace.c",
    "musl/src/ctype/isupper.c",
    "musl/src/ctype/iswalnum.c",
    "musl/src/ctype/iswalpha.c",
    "musl/src/ctype/iswblank.c",
    "musl/src/ctype/iswcntrl.c",
    "musl/src/ctype/iswctype.c",
    "musl/src/ctype/iswdigit.c",
    "musl/src/ctype/iswgraph.c",
    "musl/src/ctype/iswlower.c",
    "musl/src/ctype/iswprint.c",
    "musl/src/ctype/iswpunct.c",
    "musl/src/ctype/iswspace.c",
    "musl/src/ctype/iswupper.c",
    "musl/src/ctype/iswxdigit.c",
    "musl/src/ctype/isxdigit.c",
    "musl/src/ctype/toascii.c",
    "musl/src/ctype/tolower.c",
    "musl/src/ctype/toupper.c",
    "musl/src/ctype/towctrans.c",
    "musl/src/ctype/wcswidth.c",
    "musl/src/ctype/wctrans.c",
    "musl/src/ctype/wcwidth.c",
    "musl/src/env/setenv.c",
    "musl/src/exit/assert.c",
    "musl/src/exit/quick_exit.c",
    "musl/src/fenv/fegetexceptflag.c",
    "musl/src/fenv/feholdexcept.c",
    "musl/src/fenv/fenv.c",
    "musl/src/fenv/fesetexceptflag.c",
    "musl/src/fenv/fesetround.c",
    "musl/src/fenv/feupdateenv.c",
    "musl/src/legacy/getpagesize.c",
    "musl/src/locale/c_locale.c",
    "musl/src/locale/duplocale.c",
    "musl/src/locale/freelocale.c",
    "musl/src/locale/iconv.c",
    "musl/src/locale/iconv_close.c",
    "musl/src/locale/langinfo.c",
    "musl/src/locale/__lctrans.c",
    "musl/src/locale/localeconv.c",
    "musl/src/locale/__mo_lookup.c",
    "musl/src/locale/pleval.c",
    "musl/src/locale/setlocale.c",
    "musl/src/locale/strcoll.c",
    "musl/src/locale/strfmon.c",
    "musl/src/locale/strtod_l.c",
    "musl/src/locale/strxfrm.c",
    "musl/src/locale/wcscoll.c",
    "musl/src/locale/wcsxfrm.c",
    "musl/src/math/acos.c",
    "musl/src/math/acosf.c",
    "musl/src/math/acosh.c",
    "musl/src/math/acoshf.c",
    "musl/src/math/acoshl.c",
    "musl/src/math/acosl.c",
    "musl/src/math/asin.c",
    "musl/src/math/asinf.c",
    "musl/src/math/asinh.c",
    "musl/src/math/asinhf.c",
    "musl/src/math/asinhl.c",
    "musl/src/math/asinl.c",
    "musl/src/math/atan2.c",
    "musl/src/math/atan2f.c",
    "musl/src/math/atan2l.c",
    "musl/src/math/atan.c",
    "musl/src/math/atanf.c",
    "musl/src/math/atanh.c",
    "musl/src/math/atanhf.c",
    "musl/src/math/atanhl.c",
    "musl/src/math/atanl.c",
    "musl/src/math/cbrt.c",
    "musl/src/math/cbrtf.c",
    "musl/src/math/cbrtl.c",
    "musl/src/math/ceill.c",
    "musl/src/math/copysignl.c",
    "musl/src/math/__cos.c",
    "musl/src/math/cos.c",
    "musl/src/math/__cosdf.c",
    "musl/src/math/cosf.c",
    "musl/src/math/coshl.c",
    "musl/src/math/__cosl.c",
    "musl/src/math/cosl.c",
    "musl/src/math/erf.c",
    "musl/src/math/erff.c",
    "musl/src/math/erfl.c",
    "musl/src/math/exp10.c",
    "musl/src/math/exp10f.c",
    "musl/src/math/exp10l.c",
    "musl/src/math/exp2.c",
    "musl/src/math/exp2f.c",
    "musl/src/math/exp2f_data.c",
    "musl/src/math/exp2l.c",
    "musl/src/math/exp.c",
    "musl/src/math/exp_data.c",
    "musl/src/math/expf.c",
    "musl/src/math/expl.c",
    "musl/src/math/expm1.c",
    "musl/src/math/expm1f.c",
    "musl/src/math/expm1l.c",
    "musl/src/math/fabsl.c",
    "musl/src/math/fdim.c",
    "musl/src/math/fdimf.c",
    "musl/src/math/fdiml.c",
    "musl/src/math/finite.c",
    "musl/src/math/finitef.c",
    "musl/src/math/floorl.c",
    "musl/src/math/fma.c",
    "musl/src/math/fmaf.c",
    "musl/src/math/fmaxl.c",
    "musl/src/math/fminl.c",
    "musl/src/math/fmod.c",
    "musl/src/math/fmodf.c",
    "musl/src/math/fmodl.c",
    "musl/src/math/frexp.c",
    "musl/src/math/frexpf.c",
    "musl/src/math/frexpl.c",
    "musl/src/math/hypot.c",
    "musl/src/math/hypotf.c",
    "musl/src/math/hypotl.c",
    "musl/src/math/ilogb.c",
    "musl/src/math/ilogbf.c",
    "musl/src/math/ilogbl.c",
    "musl/src/math/__invtrigl.c",
    "musl/src/math/j0.c",
    "musl/src/math/j0f.c",
    "musl/src/math/j1.c",
    "musl/src/math/j1f.c",
    "musl/src/math/jn.c",
    "musl/src/math/jnf.c",
    "musl/src/math/ldexp.c",
    "musl/src/math/ldexpf.c",
    "musl/src/math/ldexpl.c",
    "musl/src/math/lgamma.c",
    "musl/src/math/lgammaf.c",
    "musl/src/math/lgammaf_r.c",
    "musl/src/math/lgammal.c",
    "musl/src/math/lgamma_r.c",
    "musl/src/math/llrint.c",
    "musl/src/math/llrintf.c",
    "musl/src/math/llrintl.c",
    "musl/src/math/llround.c",
    "musl/src/math/llroundf.c",
    "musl/src/math/llroundl.c",
    "musl/src/math/log10.c",
    "musl/src/math/log10f.c",
    "musl/src/math/log10l.c",
    "musl/src/math/log1p.c",
    "musl/src/math/log1pf.c",
    "musl/src/math/log1pl.c",
    "musl/src/math/log2.c",
    "musl/src/math/log2_data.c",
    "musl/src/math/log2f.c",
    "musl/src/math/log2f_data.c",
    "musl/src/math/log2l.c",
    "musl/src/math/logb.c",
    "musl/src/math/logbf.c",
    "musl/src/math/logbl.c",
    "musl/src/math/log.c",
    "musl/src/math/log_data.c",
    "musl/src/math/logf.c",
    "musl/src/math/logf_data.c",
    "musl/src/math/logl.c",
    "musl/src/math/lrint.c",
    "musl/src/math/lrintf.c",
    "musl/src/math/lrintl.c",
    "musl/src/math/lround.c",
    "musl/src/math/lroundf.c",
    "musl/src/math/lroundl.c",
    "musl/src/math/__math_divzero.c",
    "musl/src/math/__math_divzerof.c",
    "musl/src/math/__math_invalid.c",
    "musl/src/math/__math_invalidf.c",
    "musl/src/math/__math_invalidl.c",
    "musl/src/math/__math_oflow.c",
    "musl/src/math/__math_oflowf.c",
    "musl/src/math/__math_uflow.c",
    "musl/src/math/__math_uflowf.c",
    "musl/src/math/__math_xflow.c",
    "musl/src/math/__math_xflowf.c",
    "musl/src/math/modf.c",
    "musl/src/math/modff.c",
    "musl/src/math/modfl.c",
    "musl/src/math/nan.c",
    "musl/src/math/nanf.c",
    "musl/src/math/nanl.c",
    "musl/src/math/nearbyintl.c",
    "musl/src/math/nextafter.c",
    "musl/src/math/nextafterf.c",
    "musl/src/math/nextafterl.c",
    "musl/src/math/nexttoward.c",
    "musl/src/math/nexttowardf.c",
    "musl/src/math/nexttowardl.c",
    "musl/src/math/__polevll.c",
    "musl/src/math/pow.c",
    "musl/src/math/pow_data.c",
    "musl/src/math/powf.c",
    "musl/src/math/powf_data.c",
    "musl/src/math/remainder.c",
    "musl/src/math/remainderf.c",
    "musl/src/math/remainderl.c",
    "musl/src/math/__rem_pio2_large.c",
    "musl/src/math/remquo.c",
    "musl/src/math/remquof.c",
    "musl/src/math/remquol.c",
    "musl/src/math/rintl.c",
    "musl/src/math/round.c",
    "musl/src/math/roundf.c",
    "musl/src/math/roundl.c",
    "musl/src/math/scalb.c",
    "musl/src/math/scalbf.c",
    "musl/src/math/scalbln.c",
    "musl/src/math/scalblnf.c",
    "musl/src/math/scalblnl.c",
    "musl/src/math/scalbn.c",
    "musl/src/math/scalbnf.c",
    "musl/src/math/scalbnl.c",
    "musl/src/math/signgam.c",
    "musl/src/math/significand.c",
    "musl/src/math/significandf.c",
    "musl/src/math/__sin.c",
    "musl/src/math/sin.c",
    "musl/src/math/sincos.c",
    "musl/src/math/sincosf.c",
    "musl/src/math/sincosl.c",
    "musl/src/math/__sindf.c",
    "musl/src/math/sinf.c",
    "musl/src/math/sinhl.c",
    "musl/src/math/__sinl.c",
    "musl/src/math/sinl.c",
    "musl/src/math/sqrt_data.c",
    "musl/src/math/sqrtl.c",
    "musl/src/math/__tan.c",
    "musl/src/math/tan.c",
    "musl/src/math/__tandf.c",
    "musl/src/math/tanf.c",
    "musl/src/math/tanh.c",
    "musl/src/math/tanhf.c",
    "musl/src/math/tanhl.c",
    "musl/src/math/__tanl.c",
    "musl/src/math/tanl.c",
    "musl/src/math/tgamma.c",
    "musl/src/math/tgammaf.c",
    "musl/src/math/tgammal.c",
    "musl/src/math/truncl.c",
    "musl/src/misc/a64l.c",
    "musl/src/misc/basename.c",
    "musl/src/misc/dirname.c",
    "musl/src/misc/ffs.c",
    "musl/src/misc/ffsl.c",
    "musl/src/misc/ffsll.c",
    "musl/src/misc/getdomainname.c",
    "musl/src/misc/gethostid.c",
    "musl/src/misc/getopt.c",
    "musl/src/misc/getopt_long.c",
    "musl/src/misc/getsubopt.c",
    "musl/src/misc/realpath.c",
    "musl/src/multibyte/btowc.c",
    "musl/src/multibyte/c16rtomb.c",
    "musl/src/multibyte/c32rtomb.c",
    "musl/src/multibyte/internal.c",
    "musl/src/multibyte/mblen.c",
    "musl/src/multibyte/mbrlen.c",
    "musl/src/multibyte/mbrtoc16.c",
    "musl/src/multibyte/mbrtoc32.c",
    "musl/src/multibyte/mbrtowc.c",
    "musl/src/multibyte/mbsinit.c",
    "musl/src/multibyte/mbsnrtowcs.c",
    "musl/src/multibyte/mbsrtowcs.c",
    "musl/src/multibyte/mbstowcs.c",
    "musl/src/multibyte/mbtowc.c",
    "musl/src/multibyte/wcrtomb.c",
    "musl/src/multibyte/wcsnrtombs.c",
    "musl/src/multibyte/wcsrtombs.c",
    "musl/src/multibyte/wcstombs.c",
    "musl/src/multibyte/wctob.c",
    "musl/src/multibyte/wctomb.c",
    "musl/src/network/htonl.c",
    "musl/src/network/htons.c",
    "musl/src/network/in6addr_any.c",
    "musl/src/network/in6addr_loopback.c",
    "musl/src/network/inet_aton.c",
    "musl/src/network/inet_ntop.c",
    "musl/src/network/inet_pton.c",
    "musl/src/network/ntohl.c",
    "musl/src/network/ntohs.c",
    "musl/src/prng/drand48.c",
    "musl/src/prng/lcong48.c",
    "musl/src/prng/lrand48.c",
    "musl/src/prng/mrand48.c",
    "musl/src/prng/__rand48_step.c",
    "musl/src/prng/rand.c",
    "musl/src/prng/rand_r.c",
    "musl/src/prng/__seed48.c",
    "musl/src/prng/seed48.c",
    "musl/src/prng/srand48.c",
    "musl/src/regex/fnmatch.c",
    "musl/src/regex/regerror.c",
    "musl/src/search/hsearch.c",
    "musl/src/search/insque.c",
    "musl/src/search/lsearch.c",
    "musl/src/search/tdelete.c",
    "musl/src/search/tdestroy.c",
    "musl/src/search/tfind.c",
    "musl/src/search/tsearch.c",
    "musl/src/search/twalk.c",
    "musl/src/stdio/asprintf.c",
    "musl/src/stdio/clearerr.c",
    "musl/src/stdio/dprintf.c",
    "musl/src/stdio/ext2.c",
    "musl/src/stdio/ext.c",
    "musl/src/stdio/fclose.c",
    "musl/src/stdio/__fclose_ca.c",
    "musl/src/stdio/feof.c",
    "musl/src/stdio/ferror.c",
    "musl/src/stdio/fflush.c",
    "musl/src/stdio/fgetln.c",
    "musl/src/stdio/fgets.c",
    "musl/src/stdio/fgetwc.c",
    "musl/src/stdio/fgetws.c",
    "musl/src/stdio/fileno.c",
    "musl/src/stdio/__fmodeflags.c",
    "musl/src/stdio/fopencookie.c",
    "musl/src/stdio/fprintf.c",
    "musl/src/stdio/fputs.c",
    "musl/src/stdio/fputwc.c",
    "musl/src/stdio/fputws.c",
    "musl/src/stdio/fread.c",
    "musl/src/stdio/fscanf.c",
    "musl/src/stdio/fwide.c",
    "musl/src/stdio/fwprintf.c",
    "musl/src/stdio/fwrite.c",
    "musl/src/stdio/fwscanf.c",
    "musl/src/stdio/getchar_unlocked.c",
    "musl/src/stdio/getc_unlocked.c",
    "musl/src/stdio/getdelim.c",
    "musl/src/stdio/getline.c",
    "musl/src/stdio/getw.c",
    "musl/src/stdio/getwc.c",
    "musl/src/stdio/getwchar.c",
    "musl/src/stdio/ofl_add.c",
    "musl/src/stdio/__overflow.c",
    "musl/src/stdio/perror.c",
    "musl/src/stdio/putchar_unlocked.c",
    "musl/src/stdio/putc_unlocked.c",
    "musl/src/stdio/puts.c",
    "musl/src/stdio/putw.c",
    "musl/src/stdio/putwc.c",
    "musl/src/stdio/putwchar.c",
    "musl/src/stdio/rewind.c",
    "musl/src/stdio/scanf.c",
    "musl/src/stdio/setbuf.c",
    "musl/src/stdio/setbuffer.c",
    "musl/src/stdio/setlinebuf.c",
    "musl/src/stdio/setvbuf.c",
    "musl/src/stdio/snprintf.c",
    "musl/src/stdio/sprintf.c",
    "musl/src/stdio/sscanf.c",
    "musl/src/stdio/__stdio_exit.c",
    "musl/src/stdio/swprintf.c",
    "musl/src/stdio/swscanf.c",
    "musl/src/stdio/__toread.c",
    "musl/src/stdio/__towrite.c",
    "musl/src/stdio/__uflow.c",
    "musl/src/stdio/ungetwc.c",
    "musl/src/stdio/vasprintf.c",
    "musl/src/stdio/vprintf.c",
    "musl/src/stdio/vscanf.c",
    "musl/src/stdio/vsprintf.c",
    "musl/src/stdio/vwprintf.c",
    "musl/src/stdio/vwscanf.c",
    "musl/src/stdio/wprintf.c",
    "musl/src/stdio/wscanf.c",
    "musl/src/stdlib/abs.c",
    "musl/src/stdlib/atof.c",
    "musl/src/stdlib/atoi.c",
    "musl/src/stdlib/atol.c",
    "musl/src/stdlib/atoll.c",
    "musl/src/stdlib/bsearch.c",
    "musl/src/stdlib/div.c",
    "musl/src/stdlib/ecvt.c",
    "musl/src/stdlib/fcvt.c",
    "musl/src/stdlib/gcvt.c",
    "musl/src/stdlib/imaxabs.c",
    "musl/src/stdlib/imaxdiv.c",
    "musl/src/stdlib/labs.c",
    "musl/src/stdlib/ldiv.c",
    "musl/src/stdlib/llabs.c",
    "musl/src/stdlib/lldiv.c",
    "musl/src/stdlib/qsort.c",
    "musl/src/stdlib/qsort_nr.c",
    "musl/src/string/bcmp.c",
    "musl/src/string/bcopy.c",
    "musl/src/string/explicit_bzero.c",
    "musl/src/string/index.c",
    "musl/src/string/memccpy.c",
    "musl/src/string/memchr.c",
    "musl/src/string/memcmp.c",
    "musl/src/string/memmem.c",
    "musl/src/string/mempcpy.c",
    "musl/src/string/memrchr.c",
    "musl/src/string/rindex.c",
    "musl/src/string/stpcpy.c",
    "musl/src/string/stpncpy.c",
    "musl/src/string/strcasestr.c",
    "musl/src/string/strcat.c",
    "musl/src/string/strchr.c",
    "musl/src/string/strchrnul.c",
    "musl/src/string/strcpy.c",
    "musl/src/string/strcspn.c",
    "musl/src/string/strdup.c",
    "musl/src/string/strerror_r.c",
    "musl/src/string/strlcat.c",
    "musl/src/string/strlcpy.c",
    "musl/src/string/strncat.c",
    "musl/src/string/strncpy.c",
    "musl/src/string/strndup.c",
    "musl/src/string/strnlen.c",
    "musl/src/string/strpbrk.c",
    "musl/src/string/strrchr.c",
    "musl/src/string/strsep.c",
    "musl/src/string/strspn.c",
    "musl/src/string/strstr.c",
    "musl/src/string/strtok.c",
    "musl/src/string/strtok_r.c",
    "musl/src/string/strverscmp.c",
    "musl/src/string/swab.c",
    "musl/src/string/wcpcpy.c",
    "musl/src/string/wcpncpy.c",
    "musl/src/string/wcscasecmp.c",
    "musl/src/string/wcscasecmp_l.c",
    "musl/src/string/wcscat.c",
    "musl/src/string/wcschr.c",
    "musl/src/string/wcscmp.c",
    "musl/src/string/wcscpy.c",
    "musl/src/string/wcscspn.c",
    "musl/src/string/wcsdup.c",
    "musl/src/string/wcslen.c",
    "musl/src/string/wcsncasecmp.c",
    "musl/src/string/wcsncasecmp_l.c",
    "musl/src/string/wcsncat.c",
    "musl/src/string/wcsncmp.c",
    "musl/src/string/wcsncpy.c",
    "musl/src/string/wcsnlen.c",
    "musl/src/string/wcspbrk.c",
    "musl/src/string/wcsrchr.c",
    "musl/src/string/wcsspn.c",
    "musl/src/string/wcsstr.c",
    "musl/src/string/wcstok.c",
    "musl/src/string/wcswcs.c",
    "musl/src/string/wmemchr.c",
    "musl/src/string/wmemcmp.c",
    "musl/src/string/wmemcpy.c",
    "musl/src/string/wmemmove.c",
    "musl/src/string/wmemset.c",
    "musl/src/thread/thrd_sleep.c",
    "musl/src/time/asctime.c",
    "musl/src/time/asctime_r.c",
    "musl/src/time/ctime.c",
    "musl/src/time/ctime_r.c",
    "musl/src/time/difftime.c",
    "musl/src/time/ftime.c",
    "musl/src/time/__month_to_secs.c",
    "musl/src/time/strptime.c",
    "musl/src/time/timespec_get.c",
    "musl/src/time/__year_to_secs.c",
    "musl/src/unistd/posix_close.c",

    "wasi/libc-top-half/musl/src/conf/confstr.c",
    "wasi/libc-top-half/musl/src/conf/fpathconf.c",
    "wasi/libc-top-half/musl/src/conf/sysconf.c",
    "wasi/libc-top-half/musl/src/dirent/alphasort.c",
    "wasi/libc-top-half/musl/src/dirent/versionsort.c",
    "wasi/libc-top-half/musl/src/env/clearenv.c",
    "wasi/libc-top-half/musl/src/env/getenv.c",
    "wasi/libc-top-half/musl/src/env/putenv.c",
    "wasi/libc-top-half/musl/src/env/__stack_chk_fail.c",
    "wasi/libc-top-half/musl/src/env/unsetenv.c",
    "wasi/libc-top-half/musl/src/errno/strerror.c",
    "wasi/libc-top-half/musl/src/exit/atexit.c",
    "wasi/libc-top-half/musl/src/exit/at_quick_exit.c",
    "wasi/libc-top-half/musl/src/exit/exit.c",
    "wasi/libc-top-half/musl/src/fcntl/creat.c",
    "wasi/libc-top-half/musl/src/internal/defsysinfo.c",
    "wasi/libc-top-half/musl/src/internal/floatscan.c",
    "wasi/libc-top-half/musl/src/internal/intscan.c",
    "wasi/libc-top-half/musl/src/internal/libc.c",
    "wasi/libc-top-half/musl/src/internal/shgetc.c",
    "wasi/libc-top-half/musl/src/locale/catclose.c",
    "wasi/libc-top-half/musl/src/locale/catgets.c",
    "wasi/libc-top-half/musl/src/locale/catopen.c",
    "wasi/libc-top-half/musl/src/locale/locale_map.c",
    "wasi/libc-top-half/musl/src/locale/newlocale.c",
    "wasi/libc-top-half/musl/src/locale/uselocale.c",
    "wasi/libc-top-half/musl/src/math/cosh.c",
    "wasi/libc-top-half/musl/src/math/coshf.c",
    "wasi/libc-top-half/musl/src/math/__expo2.c",
    "wasi/libc-top-half/musl/src/math/__expo2f.c",
    "wasi/libc-top-half/musl/src/math/fmal.c",
    "wasi/libc-top-half/musl/src/math/powl.c",
    "wasi/libc-top-half/musl/src/math/__rem_pio2.c",
    "wasi/libc-top-half/musl/src/math/__rem_pio2f.c",
    "wasi/libc-top-half/musl/src/math/__rem_pio2l.c",
    "wasi/libc-top-half/musl/src/math/sinh.c",
    "wasi/libc-top-half/musl/src/math/sinhf.c",
    "wasi/libc-top-half/musl/src/misc/fmtmsg.c",
    "wasi/libc-top-half/musl/src/misc/nftw.c",
    "wasi/libc-top-half/musl/src/misc/uname.c",
    "wasi/libc-top-half/musl/src/prng/random.c",
    "wasi/libc-top-half/musl/src/regex/regcomp.c",
    "wasi/libc-top-half/musl/src/regex/regexec.c",
    "wasi/libc-top-half/musl/src/regex/glob.c",
    "wasi/libc-top-half/musl/src/regex/tre-mem.c",
    "wasi/libc-top-half/musl/src/stat/futimesat.c",
    "wasi/libc-top-half/musl/src/stdio/__fdopen.c",
    "wasi/libc-top-half/musl/src/stdio/fgetc.c",
    "wasi/libc-top-half/musl/src/stdio/fgetpos.c",
    "wasi/libc-top-half/musl/src/stdio/fmemopen.c",
    "wasi/libc-top-half/musl/src/stdio/fopen.c",
    "wasi/libc-top-half/musl/src/stdio/__fopen_rb_ca.c",
    "wasi/libc-top-half/musl/src/stdio/fputc.c",
    "wasi/libc-top-half/musl/src/stdio/freopen.c",
    "wasi/libc-top-half/musl/src/stdio/fseek.c",
    "wasi/libc-top-half/musl/src/stdio/fsetpos.c",
    "wasi/libc-top-half/musl/src/stdio/ftell.c",
    "wasi/libc-top-half/musl/src/stdio/getc.c",
    "wasi/libc-top-half/musl/src/stdio/getchar.c",
    "wasi/libc-top-half/musl/src/stdio/ofl.c",
    "wasi/libc-top-half/musl/src/stdio/open_memstream.c",
    "wasi/libc-top-half/musl/src/stdio/open_wmemstream.c",
    "wasi/libc-top-half/musl/src/stdio/printf.c",
    "wasi/libc-top-half/musl/src/stdio/putc.c",
    "wasi/libc-top-half/musl/src/stdio/putchar.c",
    "wasi/libc-top-half/musl/src/stdio/stderr.c",
    "wasi/libc-top-half/musl/src/stdio/stdin.c",
    "wasi/libc-top-half/musl/src/stdio/__stdio_close.c",
    "wasi/libc-top-half/musl/src/stdio/__stdio_read.c",
    "wasi/libc-top-half/musl/src/stdio/__stdio_seek.c",
    "wasi/libc-top-half/musl/src/stdio/__stdio_write.c",
    "wasi/libc-top-half/musl/src/stdio/stdout.c",
    "wasi/libc-top-half/musl/src/stdio/__stdout_write.c",
    "wasi/libc-top-half/musl/src/stdio/ungetc.c",
    "wasi/libc-top-half/musl/src/stdio/vdprintf.c",
    "wasi/libc-top-half/musl/src/stdio/vfprintf.c",
    "wasi/libc-top-half/musl/src/stdio/vfscanf.c",
    "wasi/libc-top-half/musl/src/stdio/vfwprintf.c",
    "wasi/libc-top-half/musl/src/stdio/vfwscanf.c",
    "wasi/libc-top-half/musl/src/stdio/vsnprintf.c",
    "wasi/libc-top-half/musl/src/stdio/vsscanf.c",
    "wasi/libc-top-half/musl/src/stdio/vswprintf.c",
    "wasi/libc-top-half/musl/src/stdio/vswscanf.c",
    "wasi/libc-top-half/musl/src/stdlib/strtod.c",
    "wasi/libc-top-half/musl/src/stdlib/strtol.c",
    "wasi/libc-top-half/musl/src/stdlib/wcstod.c",
    "wasi/libc-top-half/musl/src/stdlib/wcstol.c",
    "wasi/libc-top-half/musl/src/string/memset.c",
    "wasi/libc-top-half/musl/src/time/getdate.c",
    "wasi/libc-top-half/musl/src/time/gmtime.c",
    "wasi/libc-top-half/musl/src/time/gmtime_r.c",
    "wasi/libc-top-half/musl/src/time/localtime.c",
    "wasi/libc-top-half/musl/src/time/localtime_r.c",
    "wasi/libc-top-half/musl/src/time/mktime.c",
    "wasi/libc-top-half/musl/src/time/__secs_to_tm.c",
    "wasi/libc-top-half/musl/src/time/strftime.c",
    "wasi/libc-top-half/musl/src/time/timegm.c",
    "wasi/libc-top-half/musl/src/time/__tm_to_secs.c",
    "wasi/libc-top-half/musl/src/time/__tz.c",
    "wasi/libc-top-half/musl/src/time/wcsftime.c",

    "wasi/libc-top-half/sources/arc4random.c",
};

const crt1_command_src_file = "wasi/libc-bottom-half/crt/crt1-command.c";
const crt1_reactor_src_file = "wasi/libc-bottom-half/crt/crt1-reactor.c";

const emulated_dl_src_files = &[_][]const u8{
    "wasi/libc-top-half/musl/src/misc/dl.c",
};

const emulated_process_clocks_src_files = &[_][]const u8{
    "wasi/libc-bottom-half/clocks/clock.c",
    "wasi/libc-bottom-half/clocks/getrusage.c",
    "wasi/libc-bottom-half/clocks/times.c",
};

const emulated_getpid_src_files = &[_][]const u8{
    "wasi/libc-bottom-half/getpid/getpid.c",
};

const emulated_mman_src_files = &[_][]const u8{
    "wasi/libc-bottom-half/mman/mman.c",
};

const emulated_signal_bottom_half_src_files = &[_][]const u8{
    "wasi/libc-bottom-half/signal/signal.c",
};

const emulated_signal_top_half_src_files = &[_][]const u8{
    "musl/src/signal/psignal.c",
    "musl/src/string/strsignal.c",
};
