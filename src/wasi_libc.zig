const std = @import("std");
const mem = std.mem;
const path = std.fs.path;

const Allocator = std.mem.Allocator;
const Compilation = @import("Compilation.zig");
const build_options = @import("build_options");
const target_util = @import("target.zig");
const musl = @import("musl.zig");

pub const CRTFile = enum {
    crt1_reactor_o,
    crt1_command_o,
    libc_a,
    libwasi_emulated_process_clocks_a,
    libwasi_emulated_getpid_a,
    libwasi_emulated_mman_a,
    libwasi_emulated_signal_a,
};

pub fn getEmulatedLibCRTFile(lib_name: []const u8) ?CRTFile {
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

pub fn emulatedLibCRFileLibName(crt_file: CRTFile) []const u8 {
    return switch (crt_file) {
        .libwasi_emulated_process_clocks_a => "libwasi-emulated-process-clocks.a",
        .libwasi_emulated_getpid_a => "libwasi-emulated-getpid.a",
        .libwasi_emulated_mman_a => "libwasi-emulated-mman.a",
        .libwasi_emulated_signal_a => "libwasi-emulated-signal.a",
        else => unreachable,
    };
}

pub fn execModelCrtFile(wasi_exec_model: std.builtin.WasiExecModel) CRTFile {
    return switch (wasi_exec_model) {
        .reactor => CRTFile.crt1_reactor_o,
        .command => CRTFile.crt1_command_o,
    };
}

pub fn execModelCrtFileFullName(wasi_exec_model: std.builtin.WasiExecModel) []const u8 {
    return switch (execModelCrtFile(wasi_exec_model)) {
        .crt1_reactor_o => "crt1-reactor.o",
        .crt1_command_o => "crt1-command.o",
        else => unreachable,
    };
}

pub fn buildCRTFile(comp: *Compilation, crt_file: CRTFile) !void {
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
            try addCCArgs(comp, arena, &args, false);
            try addLibcBottomHalfIncludes(comp, arena, &args);
            return comp.build_crt_file("crt1-reactor", .Obj, &[1]Compilation.CSourceFile{
                .{
                    .src_path = try comp.zig_lib_directory.join(arena, &[_][]const u8{
                        "libc", try sanitize(arena, crt1_reactor_src_file),
                    }),
                    .extra_flags = args.items,
                },
            });
        },
        .crt1_command_o => {
            var args = std.ArrayList([]const u8).init(arena);
            try addCCArgs(comp, arena, &args, false);
            try addLibcBottomHalfIncludes(comp, arena, &args);
            return comp.build_crt_file("crt1-command", .Obj, &[1]Compilation.CSourceFile{
                .{
                    .src_path = try comp.zig_lib_directory.join(arena, &[_][]const u8{
                        "libc", try sanitize(arena, crt1_command_src_file),
                    }),
                    .extra_flags = args.items,
                },
            });
        },
        .libc_a => {
            var libc_sources = std.ArrayList(Compilation.CSourceFile).init(arena);

            {
                // Compile emmalloc.
                var args = std.ArrayList([]const u8).init(arena);
                try addCCArgs(comp, arena, &args, true);
                for (emmalloc_src_files) |file_path| {
                    try libc_sources.append(.{
                        .src_path = try comp.zig_lib_directory.join(arena, &[_][]const u8{
                            "libc", try sanitize(arena, file_path),
                        }),
                        .extra_flags = args.items,
                    });
                }
            }

            {
                // Compile libc-bottom-half.
                var args = std.ArrayList([]const u8).init(arena);
                try addCCArgs(comp, arena, &args, true);
                try addLibcBottomHalfIncludes(comp, arena, &args);

                for (libc_bottom_half_src_files) |file_path| {
                    try libc_sources.append(.{
                        .src_path = try comp.zig_lib_directory.join(arena, &[_][]const u8{
                            "libc", try sanitize(arena, file_path),
                        }),
                        .extra_flags = args.items,
                    });
                }
            }

            {
                // Compile libc-top-half.
                var args = std.ArrayList([]const u8).init(arena);
                try addCCArgs(comp, arena, &args, true);
                try addLibcTopHalfIncludes(comp, arena, &args);

                for (libc_top_half_src_files) |file_path| {
                    try libc_sources.append(.{
                        .src_path = try comp.zig_lib_directory.join(arena, &[_][]const u8{
                            "libc", try sanitize(arena, file_path),
                        }),
                        .extra_flags = args.items,
                    });
                }
            }

            try comp.build_crt_file("c", .Lib, libc_sources.items);
        },
        .libwasi_emulated_process_clocks_a => {
            var args = std.ArrayList([]const u8).init(arena);
            try addCCArgs(comp, arena, &args, true);
            try addLibcBottomHalfIncludes(comp, arena, &args);

            var emu_clocks_sources = std.ArrayList(Compilation.CSourceFile).init(arena);
            for (emulated_process_clocks_src_files) |file_path| {
                try emu_clocks_sources.append(.{
                    .src_path = try comp.zig_lib_directory.join(arena, &[_][]const u8{
                        "libc", try sanitize(arena, file_path),
                    }),
                    .extra_flags = args.items,
                });
            }
            try comp.build_crt_file("wasi-emulated-process-clocks", .Lib, emu_clocks_sources.items);
        },
        .libwasi_emulated_getpid_a => {
            var args = std.ArrayList([]const u8).init(arena);
            try addCCArgs(comp, arena, &args, true);
            try addLibcBottomHalfIncludes(comp, arena, &args);

            var emu_getpid_sources = std.ArrayList(Compilation.CSourceFile).init(arena);
            for (emulated_getpid_src_files) |file_path| {
                try emu_getpid_sources.append(.{
                    .src_path = try comp.zig_lib_directory.join(arena, &[_][]const u8{
                        "libc", try sanitize(arena, file_path),
                    }),
                    .extra_flags = args.items,
                });
            }
            try comp.build_crt_file("wasi-emulated-getpid", .Lib, emu_getpid_sources.items);
        },
        .libwasi_emulated_mman_a => {
            var args = std.ArrayList([]const u8).init(arena);
            try addCCArgs(comp, arena, &args, true);
            try addLibcBottomHalfIncludes(comp, arena, &args);

            var emu_mman_sources = std.ArrayList(Compilation.CSourceFile).init(arena);
            for (emulated_mman_src_files) |file_path| {
                try emu_mman_sources.append(.{
                    .src_path = try comp.zig_lib_directory.join(arena, &[_][]const u8{
                        "libc", try sanitize(arena, file_path),
                    }),
                    .extra_flags = args.items,
                });
            }
            try comp.build_crt_file("wasi-emulated-mman", .Lib, emu_mman_sources.items);
        },
        .libwasi_emulated_signal_a => {
            var emu_signal_sources = std.ArrayList(Compilation.CSourceFile).init(arena);

            {
                var args = std.ArrayList([]const u8).init(arena);
                try addCCArgs(comp, arena, &args, true);

                for (emulated_signal_bottom_half_src_files) |file_path| {
                    try emu_signal_sources.append(.{
                        .src_path = try comp.zig_lib_directory.join(arena, &[_][]const u8{
                            "libc", try sanitize(arena, file_path),
                        }),
                        .extra_flags = args.items,
                    });
                }
            }

            {
                var args = std.ArrayList([]const u8).init(arena);
                try addCCArgs(comp, arena, &args, true);
                try addLibcTopHalfIncludes(comp, arena, &args);
                try args.append("-D_WASI_EMULATED_SIGNAL");

                for (emulated_signal_top_half_src_files) |file_path| {
                    try emu_signal_sources.append(.{
                        .src_path = try comp.zig_lib_directory.join(arena, &[_][]const u8{
                            "libc", try sanitize(arena, file_path),
                        }),
                        .extra_flags = args.items,
                    });
                }
            }

            try comp.build_crt_file("wasi-emulated-signal", .Lib, emu_signal_sources.items);
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

fn addCCArgs(
    comp: *Compilation,
    arena: Allocator,
    args: *std.ArrayList([]const u8),
    want_O3: bool,
) error{OutOfMemory}!void {
    const target = comp.getTarget();
    const arch_name = musl.archName(target.cpu.arch);
    const os_name = @tagName(target.os.tag);
    const triple = try std.fmt.allocPrint(arena, "{s}-{s}-musl", .{ arch_name, os_name });
    const o_arg = if (want_O3) "-O3" else "-Os";

    try args.appendSlice(&[_][]const u8{
        "-std=gnu17",
        "-fno-trapping-math",
        "-fno-stack-protector",
        "-w", // ignore all warnings

        o_arg,

        "-mthread-model",
        "single",

        "-isysroot",
        "/",

        "-iwithsysroot",
        try comp.zig_lib_directory.join(arena, &[_][]const u8{ "libc", "include", triple }),

        "-DBULK_MEMORY_THRESHOLD=32",
    });
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
            "wasi",
            "libc-top-half",
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
            "wasi",
            "libc-top-half",
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
            "wasi",
            "libc-top-half",
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
    "wasi/libc-bottom-half/cloudlibc/src/libc/unistd/close.c",
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
    "wasi/libc-bottom-half/sources/accept.c",
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
    // TODO apparently, due to a bug in LLD, the weak refs are garbled
    // unless chdir.c is last in the archive
    // https://reviews.llvm.org/D85567
    "wasi/libc-bottom-half/sources/chdir.c",
};

const libc_top_half_src_files = [_][]const u8{
    "wasi/libc-top-half/musl/src/misc/a64l.c",
    "wasi/libc-top-half/musl/src/misc/basename.c",
    "wasi/libc-top-half/musl/src/misc/dirname.c",
    "wasi/libc-top-half/musl/src/misc/ffs.c",
    "wasi/libc-top-half/musl/src/misc/ffsl.c",
    "wasi/libc-top-half/musl/src/misc/ffsll.c",
    "wasi/libc-top-half/musl/src/misc/fmtmsg.c",
    "wasi/libc-top-half/musl/src/misc/getdomainname.c",
    "wasi/libc-top-half/musl/src/misc/gethostid.c",
    "wasi/libc-top-half/musl/src/misc/getopt.c",
    "wasi/libc-top-half/musl/src/misc/getopt_long.c",
    "wasi/libc-top-half/musl/src/misc/getsubopt.c",
    "wasi/libc-top-half/musl/src/misc/uname.c",
    "wasi/libc-top-half/musl/src/misc/nftw.c",
    "wasi/libc-top-half/musl/src/errno/strerror.c",
    "wasi/libc-top-half/musl/src/network/htonl.c",
    "wasi/libc-top-half/musl/src/network/htons.c",
    "wasi/libc-top-half/musl/src/network/ntohl.c",
    "wasi/libc-top-half/musl/src/network/ntohs.c",
    "wasi/libc-top-half/musl/src/network/inet_ntop.c",
    "wasi/libc-top-half/musl/src/network/inet_pton.c",
    "wasi/libc-top-half/musl/src/network/inet_aton.c",
    "wasi/libc-top-half/musl/src/network/in6addr_any.c",
    "wasi/libc-top-half/musl/src/network/in6addr_loopback.c",
    "wasi/libc-top-half/musl/src/fenv/fenv.c",
    "wasi/libc-top-half/musl/src/fenv/fesetround.c",
    "wasi/libc-top-half/musl/src/fenv/feupdateenv.c",
    "wasi/libc-top-half/musl/src/fenv/fesetexceptflag.c",
    "wasi/libc-top-half/musl/src/fenv/fegetexceptflag.c",
    "wasi/libc-top-half/musl/src/fenv/feholdexcept.c",
    "wasi/libc-top-half/musl/src/exit/exit.c",
    "wasi/libc-top-half/musl/src/exit/atexit.c",
    "wasi/libc-top-half/musl/src/exit/assert.c",
    "wasi/libc-top-half/musl/src/exit/quick_exit.c",
    "wasi/libc-top-half/musl/src/exit/at_quick_exit.c",
    "wasi/libc-top-half/musl/src/time/strftime.c",
    "wasi/libc-top-half/musl/src/time/asctime.c",
    "wasi/libc-top-half/musl/src/time/asctime_r.c",
    "wasi/libc-top-half/musl/src/time/ctime.c",
    "wasi/libc-top-half/musl/src/time/ctime_r.c",
    "wasi/libc-top-half/musl/src/time/wcsftime.c",
    "wasi/libc-top-half/musl/src/time/strptime.c",
    "wasi/libc-top-half/musl/src/time/difftime.c",
    "wasi/libc-top-half/musl/src/time/timegm.c",
    "wasi/libc-top-half/musl/src/time/ftime.c",
    "wasi/libc-top-half/musl/src/time/gmtime.c",
    "wasi/libc-top-half/musl/src/time/gmtime_r.c",
    "wasi/libc-top-half/musl/src/time/timespec_get.c",
    "wasi/libc-top-half/musl/src/time/getdate.c",
    "wasi/libc-top-half/musl/src/time/localtime.c",
    "wasi/libc-top-half/musl/src/time/localtime_r.c",
    "wasi/libc-top-half/musl/src/time/mktime.c",
    "wasi/libc-top-half/musl/src/time/__tm_to_secs.c",
    "wasi/libc-top-half/musl/src/time/__month_to_secs.c",
    "wasi/libc-top-half/musl/src/time/__secs_to_tm.c",
    "wasi/libc-top-half/musl/src/time/__year_to_secs.c",
    "wasi/libc-top-half/musl/src/time/__tz.c",
    "wasi/libc-top-half/musl/src/fcntl/creat.c",
    "wasi/libc-top-half/musl/src/dirent/alphasort.c",
    "wasi/libc-top-half/musl/src/dirent/versionsort.c",
    "wasi/libc-top-half/musl/src/env/__stack_chk_fail.c",
    "wasi/libc-top-half/musl/src/env/clearenv.c",
    "wasi/libc-top-half/musl/src/env/getenv.c",
    "wasi/libc-top-half/musl/src/env/putenv.c",
    "wasi/libc-top-half/musl/src/env/setenv.c",
    "wasi/libc-top-half/musl/src/env/unsetenv.c",
    "wasi/libc-top-half/musl/src/unistd/posix_close.c",
    "wasi/libc-top-half/musl/src/stat/futimesat.c",
    "wasi/libc-top-half/musl/src/legacy/getpagesize.c",
    "wasi/libc-top-half/musl/src/thread/thrd_sleep.c",
    "wasi/libc-top-half/musl/src/internal/defsysinfo.c",
    "wasi/libc-top-half/musl/src/internal/floatscan.c",
    "wasi/libc-top-half/musl/src/internal/intscan.c",
    "wasi/libc-top-half/musl/src/internal/libc.c",
    "wasi/libc-top-half/musl/src/internal/shgetc.c",
    "wasi/libc-top-half/musl/src/stdio/__fclose_ca.c",
    "wasi/libc-top-half/musl/src/stdio/__fdopen.c",
    "wasi/libc-top-half/musl/src/stdio/__fmodeflags.c",
    "wasi/libc-top-half/musl/src/stdio/__fopen_rb_ca.c",
    "wasi/libc-top-half/musl/src/stdio/__overflow.c",
    "wasi/libc-top-half/musl/src/stdio/__stdio_close.c",
    "wasi/libc-top-half/musl/src/stdio/__stdio_exit.c",
    "wasi/libc-top-half/musl/src/stdio/__stdio_read.c",
    "wasi/libc-top-half/musl/src/stdio/__stdio_seek.c",
    "wasi/libc-top-half/musl/src/stdio/__stdio_write.c",
    "wasi/libc-top-half/musl/src/stdio/__stdout_write.c",
    "wasi/libc-top-half/musl/src/stdio/__toread.c",
    "wasi/libc-top-half/musl/src/stdio/__towrite.c",
    "wasi/libc-top-half/musl/src/stdio/__uflow.c",
    "wasi/libc-top-half/musl/src/stdio/asprintf.c",
    "wasi/libc-top-half/musl/src/stdio/clearerr.c",
    "wasi/libc-top-half/musl/src/stdio/dprintf.c",
    "wasi/libc-top-half/musl/src/stdio/ext.c",
    "wasi/libc-top-half/musl/src/stdio/ext2.c",
    "wasi/libc-top-half/musl/src/stdio/fclose.c",
    "wasi/libc-top-half/musl/src/stdio/feof.c",
    "wasi/libc-top-half/musl/src/stdio/ferror.c",
    "wasi/libc-top-half/musl/src/stdio/fflush.c",
    "wasi/libc-top-half/musl/src/stdio/fgetc.c",
    "wasi/libc-top-half/musl/src/stdio/fgetln.c",
    "wasi/libc-top-half/musl/src/stdio/fgetpos.c",
    "wasi/libc-top-half/musl/src/stdio/fgets.c",
    "wasi/libc-top-half/musl/src/stdio/fgetwc.c",
    "wasi/libc-top-half/musl/src/stdio/fgetws.c",
    "wasi/libc-top-half/musl/src/stdio/fileno.c",
    "wasi/libc-top-half/musl/src/stdio/fmemopen.c",
    "wasi/libc-top-half/musl/src/stdio/fopen.c",
    "wasi/libc-top-half/musl/src/stdio/fopencookie.c",
    "wasi/libc-top-half/musl/src/stdio/fprintf.c",
    "wasi/libc-top-half/musl/src/stdio/fputc.c",
    "wasi/libc-top-half/musl/src/stdio/fputs.c",
    "wasi/libc-top-half/musl/src/stdio/fputwc.c",
    "wasi/libc-top-half/musl/src/stdio/fputws.c",
    "wasi/libc-top-half/musl/src/stdio/fread.c",
    "wasi/libc-top-half/musl/src/stdio/freopen.c",
    "wasi/libc-top-half/musl/src/stdio/fscanf.c",
    "wasi/libc-top-half/musl/src/stdio/fseek.c",
    "wasi/libc-top-half/musl/src/stdio/fsetpos.c",
    "wasi/libc-top-half/musl/src/stdio/ftell.c",
    "wasi/libc-top-half/musl/src/stdio/fwide.c",
    "wasi/libc-top-half/musl/src/stdio/fwprintf.c",
    "wasi/libc-top-half/musl/src/stdio/fwrite.c",
    "wasi/libc-top-half/musl/src/stdio/fwscanf.c",
    "wasi/libc-top-half/musl/src/stdio/getc.c",
    "wasi/libc-top-half/musl/src/stdio/getc_unlocked.c",
    "wasi/libc-top-half/musl/src/stdio/getchar.c",
    "wasi/libc-top-half/musl/src/stdio/getchar_unlocked.c",
    "wasi/libc-top-half/musl/src/stdio/getdelim.c",
    "wasi/libc-top-half/musl/src/stdio/getline.c",
    "wasi/libc-top-half/musl/src/stdio/getw.c",
    "wasi/libc-top-half/musl/src/stdio/getwc.c",
    "wasi/libc-top-half/musl/src/stdio/getwchar.c",
    "wasi/libc-top-half/musl/src/stdio/ofl.c",
    "wasi/libc-top-half/musl/src/stdio/ofl_add.c",
    "wasi/libc-top-half/musl/src/stdio/open_memstream.c",
    "wasi/libc-top-half/musl/src/stdio/open_wmemstream.c",
    "wasi/libc-top-half/musl/src/stdio/perror.c",
    "wasi/libc-top-half/musl/src/stdio/printf.c",
    "wasi/libc-top-half/musl/src/stdio/putc.c",
    "wasi/libc-top-half/musl/src/stdio/putc_unlocked.c",
    "wasi/libc-top-half/musl/src/stdio/putchar.c",
    "wasi/libc-top-half/musl/src/stdio/putchar_unlocked.c",
    "wasi/libc-top-half/musl/src/stdio/puts.c",
    "wasi/libc-top-half/musl/src/stdio/putw.c",
    "wasi/libc-top-half/musl/src/stdio/putwc.c",
    "wasi/libc-top-half/musl/src/stdio/putwchar.c",
    "wasi/libc-top-half/musl/src/stdio/rewind.c",
    "wasi/libc-top-half/musl/src/stdio/scanf.c",
    "wasi/libc-top-half/musl/src/stdio/setbuf.c",
    "wasi/libc-top-half/musl/src/stdio/setbuffer.c",
    "wasi/libc-top-half/musl/src/stdio/setlinebuf.c",
    "wasi/libc-top-half/musl/src/stdio/setvbuf.c",
    "wasi/libc-top-half/musl/src/stdio/snprintf.c",
    "wasi/libc-top-half/musl/src/stdio/sprintf.c",
    "wasi/libc-top-half/musl/src/stdio/sscanf.c",
    "wasi/libc-top-half/musl/src/stdio/stderr.c",
    "wasi/libc-top-half/musl/src/stdio/stdin.c",
    "wasi/libc-top-half/musl/src/stdio/stdout.c",
    "wasi/libc-top-half/musl/src/stdio/swprintf.c",
    "wasi/libc-top-half/musl/src/stdio/swscanf.c",
    "wasi/libc-top-half/musl/src/stdio/ungetc.c",
    "wasi/libc-top-half/musl/src/stdio/ungetwc.c",
    "wasi/libc-top-half/musl/src/stdio/vasprintf.c",
    "wasi/libc-top-half/musl/src/stdio/vdprintf.c",
    "wasi/libc-top-half/musl/src/stdio/vfprintf.c",
    "wasi/libc-top-half/musl/src/stdio/vfscanf.c",
    "wasi/libc-top-half/musl/src/stdio/vfwprintf.c",
    "wasi/libc-top-half/musl/src/stdio/vfwscanf.c",
    "wasi/libc-top-half/musl/src/stdio/vprintf.c",
    "wasi/libc-top-half/musl/src/stdio/vscanf.c",
    "wasi/libc-top-half/musl/src/stdio/vsnprintf.c",
    "wasi/libc-top-half/musl/src/stdio/vsprintf.c",
    "wasi/libc-top-half/musl/src/stdio/vsscanf.c",
    "wasi/libc-top-half/musl/src/stdio/vswprintf.c",
    "wasi/libc-top-half/musl/src/stdio/vswscanf.c",
    "wasi/libc-top-half/musl/src/stdio/vwprintf.c",
    "wasi/libc-top-half/musl/src/stdio/vwscanf.c",
    "wasi/libc-top-half/musl/src/stdio/wprintf.c",
    "wasi/libc-top-half/musl/src/stdio/wscanf.c",
    "wasi/libc-top-half/musl/src/string/bcmp.c",
    "wasi/libc-top-half/musl/src/string/bcopy.c",
    "wasi/libc-top-half/musl/src/string/bzero.c",
    "wasi/libc-top-half/musl/src/string/explicit_bzero.c",
    "wasi/libc-top-half/musl/src/string/index.c",
    "wasi/libc-top-half/musl/src/string/memccpy.c",
    "wasi/libc-top-half/musl/src/string/memchr.c",
    "wasi/libc-top-half/musl/src/string/memcmp.c",
    "wasi/libc-top-half/musl/src/string/memcpy.c",
    "wasi/libc-top-half/musl/src/string/memmem.c",
    "wasi/libc-top-half/musl/src/string/memmove.c",
    "wasi/libc-top-half/musl/src/string/mempcpy.c",
    "wasi/libc-top-half/musl/src/string/memrchr.c",
    "wasi/libc-top-half/musl/src/string/memset.c",
    "wasi/libc-top-half/musl/src/string/rindex.c",
    "wasi/libc-top-half/musl/src/string/stpcpy.c",
    "wasi/libc-top-half/musl/src/string/stpncpy.c",
    "wasi/libc-top-half/musl/src/string/strcasecmp.c",
    "wasi/libc-top-half/musl/src/string/strcasestr.c",
    "wasi/libc-top-half/musl/src/string/strcat.c",
    "wasi/libc-top-half/musl/src/string/strchr.c",
    "wasi/libc-top-half/musl/src/string/strchrnul.c",
    "wasi/libc-top-half/musl/src/string/strcmp.c",
    "wasi/libc-top-half/musl/src/string/strcpy.c",
    "wasi/libc-top-half/musl/src/string/strcspn.c",
    "wasi/libc-top-half/musl/src/string/strdup.c",
    "wasi/libc-top-half/musl/src/string/strerror_r.c",
    "wasi/libc-top-half/musl/src/string/strlcat.c",
    "wasi/libc-top-half/musl/src/string/strlcpy.c",
    "wasi/libc-top-half/musl/src/string/strlen.c",
    "wasi/libc-top-half/musl/src/string/strncasecmp.c",
    "wasi/libc-top-half/musl/src/string/strncat.c",
    "wasi/libc-top-half/musl/src/string/strncmp.c",
    "wasi/libc-top-half/musl/src/string/strncpy.c",
    "wasi/libc-top-half/musl/src/string/strndup.c",
    "wasi/libc-top-half/musl/src/string/strnlen.c",
    "wasi/libc-top-half/musl/src/string/strpbrk.c",
    "wasi/libc-top-half/musl/src/string/strrchr.c",
    "wasi/libc-top-half/musl/src/string/strsep.c",
    "wasi/libc-top-half/musl/src/string/strspn.c",
    "wasi/libc-top-half/musl/src/string/strstr.c",
    "wasi/libc-top-half/musl/src/string/strtok.c",
    "wasi/libc-top-half/musl/src/string/strtok_r.c",
    "wasi/libc-top-half/musl/src/string/strverscmp.c",
    "wasi/libc-top-half/musl/src/string/swab.c",
    "wasi/libc-top-half/musl/src/string/wcpcpy.c",
    "wasi/libc-top-half/musl/src/string/wcpncpy.c",
    "wasi/libc-top-half/musl/src/string/wcscasecmp.c",
    "wasi/libc-top-half/musl/src/string/wcscasecmp_l.c",
    "wasi/libc-top-half/musl/src/string/wcscat.c",
    "wasi/libc-top-half/musl/src/string/wcschr.c",
    "wasi/libc-top-half/musl/src/string/wcscmp.c",
    "wasi/libc-top-half/musl/src/string/wcscpy.c",
    "wasi/libc-top-half/musl/src/string/wcscspn.c",
    "wasi/libc-top-half/musl/src/string/wcsdup.c",
    "wasi/libc-top-half/musl/src/string/wcslen.c",
    "wasi/libc-top-half/musl/src/string/wcsncasecmp.c",
    "wasi/libc-top-half/musl/src/string/wcsncasecmp_l.c",
    "wasi/libc-top-half/musl/src/string/wcsncat.c",
    "wasi/libc-top-half/musl/src/string/wcsncmp.c",
    "wasi/libc-top-half/musl/src/string/wcsncpy.c",
    "wasi/libc-top-half/musl/src/string/wcsnlen.c",
    "wasi/libc-top-half/musl/src/string/wcspbrk.c",
    "wasi/libc-top-half/musl/src/string/wcsrchr.c",
    "wasi/libc-top-half/musl/src/string/wcsspn.c",
    "wasi/libc-top-half/musl/src/string/wcsstr.c",
    "wasi/libc-top-half/musl/src/string/wcstok.c",
    "wasi/libc-top-half/musl/src/string/wcswcs.c",
    "wasi/libc-top-half/musl/src/string/wmemchr.c",
    "wasi/libc-top-half/musl/src/string/wmemcmp.c",
    "wasi/libc-top-half/musl/src/string/wmemcpy.c",
    "wasi/libc-top-half/musl/src/string/wmemmove.c",
    "wasi/libc-top-half/musl/src/string/wmemset.c",
    "wasi/libc-top-half/musl/src/locale/__lctrans.c",
    "wasi/libc-top-half/musl/src/locale/__mo_lookup.c",
    "wasi/libc-top-half/musl/src/locale/c_locale.c",
    "wasi/libc-top-half/musl/src/locale/catclose.c",
    "wasi/libc-top-half/musl/src/locale/catgets.c",
    "wasi/libc-top-half/musl/src/locale/catopen.c",
    "wasi/libc-top-half/musl/src/locale/duplocale.c",
    "wasi/libc-top-half/musl/src/locale/freelocale.c",
    "wasi/libc-top-half/musl/src/locale/iconv.c",
    "wasi/libc-top-half/musl/src/locale/iconv_close.c",
    "wasi/libc-top-half/musl/src/locale/langinfo.c",
    "wasi/libc-top-half/musl/src/locale/locale_map.c",
    "wasi/libc-top-half/musl/src/locale/localeconv.c",
    "wasi/libc-top-half/musl/src/locale/newlocale.c",
    "wasi/libc-top-half/musl/src/locale/pleval.c",
    "wasi/libc-top-half/musl/src/locale/setlocale.c",
    "wasi/libc-top-half/musl/src/locale/strcoll.c",
    "wasi/libc-top-half/musl/src/locale/strfmon.c",
    "wasi/libc-top-half/musl/src/locale/strtod_l.c",
    "wasi/libc-top-half/musl/src/locale/strxfrm.c",
    "wasi/libc-top-half/musl/src/locale/uselocale.c",
    "wasi/libc-top-half/musl/src/locale/wcscoll.c",
    "wasi/libc-top-half/musl/src/locale/wcsxfrm.c",
    "wasi/libc-top-half/musl/src/stdlib/abs.c",
    "wasi/libc-top-half/musl/src/stdlib/atof.c",
    "wasi/libc-top-half/musl/src/stdlib/atoi.c",
    "wasi/libc-top-half/musl/src/stdlib/atol.c",
    "wasi/libc-top-half/musl/src/stdlib/atoll.c",
    "wasi/libc-top-half/musl/src/stdlib/bsearch.c",
    "wasi/libc-top-half/musl/src/stdlib/div.c",
    "wasi/libc-top-half/musl/src/stdlib/ecvt.c",
    "wasi/libc-top-half/musl/src/stdlib/fcvt.c",
    "wasi/libc-top-half/musl/src/stdlib/gcvt.c",
    "wasi/libc-top-half/musl/src/stdlib/imaxabs.c",
    "wasi/libc-top-half/musl/src/stdlib/imaxdiv.c",
    "wasi/libc-top-half/musl/src/stdlib/labs.c",
    "wasi/libc-top-half/musl/src/stdlib/ldiv.c",
    "wasi/libc-top-half/musl/src/stdlib/llabs.c",
    "wasi/libc-top-half/musl/src/stdlib/lldiv.c",
    "wasi/libc-top-half/musl/src/stdlib/qsort.c",
    "wasi/libc-top-half/musl/src/stdlib/qsort_nr.c",
    "wasi/libc-top-half/musl/src/stdlib/strtod.c",
    "wasi/libc-top-half/musl/src/stdlib/strtol.c",
    "wasi/libc-top-half/musl/src/stdlib/wcstod.c",
    "wasi/libc-top-half/musl/src/stdlib/wcstol.c",
    "wasi/libc-top-half/musl/src/search/hsearch.c",
    "wasi/libc-top-half/musl/src/search/insque.c",
    "wasi/libc-top-half/musl/src/search/lsearch.c",
    "wasi/libc-top-half/musl/src/search/tdelete.c",
    "wasi/libc-top-half/musl/src/search/tdestroy.c",
    "wasi/libc-top-half/musl/src/search/tfind.c",
    "wasi/libc-top-half/musl/src/search/tsearch.c",
    "wasi/libc-top-half/musl/src/search/twalk.c",
    "wasi/libc-top-half/musl/src/multibyte/btowc.c",
    "wasi/libc-top-half/musl/src/multibyte/c16rtomb.c",
    "wasi/libc-top-half/musl/src/multibyte/c32rtomb.c",
    "wasi/libc-top-half/musl/src/multibyte/internal.c",
    "wasi/libc-top-half/musl/src/multibyte/mblen.c",
    "wasi/libc-top-half/musl/src/multibyte/mbrlen.c",
    "wasi/libc-top-half/musl/src/multibyte/mbrtoc16.c",
    "wasi/libc-top-half/musl/src/multibyte/mbrtoc32.c",
    "wasi/libc-top-half/musl/src/multibyte/mbrtowc.c",
    "wasi/libc-top-half/musl/src/multibyte/mbsinit.c",
    "wasi/libc-top-half/musl/src/multibyte/mbsnrtowcs.c",
    "wasi/libc-top-half/musl/src/multibyte/mbsrtowcs.c",
    "wasi/libc-top-half/musl/src/multibyte/mbstowcs.c",
    "wasi/libc-top-half/musl/src/multibyte/mbtowc.c",
    "wasi/libc-top-half/musl/src/multibyte/wcrtomb.c",
    "wasi/libc-top-half/musl/src/multibyte/wcsnrtombs.c",
    "wasi/libc-top-half/musl/src/multibyte/wcsrtombs.c",
    "wasi/libc-top-half/musl/src/multibyte/wcstombs.c",
    "wasi/libc-top-half/musl/src/multibyte/wctob.c",
    "wasi/libc-top-half/musl/src/multibyte/wctomb.c",
    "wasi/libc-top-half/musl/src/regex/fnmatch.c",
    "wasi/libc-top-half/musl/src/regex/glob.c",
    "wasi/libc-top-half/musl/src/regex/regcomp.c",
    "wasi/libc-top-half/musl/src/regex/regerror.c",
    "wasi/libc-top-half/musl/src/regex/regexec.c",
    "wasi/libc-top-half/musl/src/regex/tre-mem.c",
    "wasi/libc-top-half/musl/src/prng/__rand48_step.c",
    "wasi/libc-top-half/musl/src/prng/__seed48.c",
    "wasi/libc-top-half/musl/src/prng/drand48.c",
    "wasi/libc-top-half/musl/src/prng/lcong48.c",
    "wasi/libc-top-half/musl/src/prng/lrand48.c",
    "wasi/libc-top-half/musl/src/prng/mrand48.c",
    "wasi/libc-top-half/musl/src/prng/rand.c",
    "wasi/libc-top-half/musl/src/prng/rand_r.c",
    "wasi/libc-top-half/musl/src/prng/random.c",
    "wasi/libc-top-half/musl/src/prng/seed48.c",
    "wasi/libc-top-half/musl/src/prng/srand48.c",
    "wasi/libc-top-half/musl/src/conf/confstr.c",
    "wasi/libc-top-half/musl/src/conf/fpathconf.c",
    "wasi/libc-top-half/musl/src/conf/legacy.c",
    "wasi/libc-top-half/musl/src/conf/pathconf.c",
    "wasi/libc-top-half/musl/src/conf/sysconf.c",
    "wasi/libc-top-half/musl/src/ctype/__ctype_b_loc.c",
    "wasi/libc-top-half/musl/src/ctype/__ctype_get_mb_cur_max.c",
    "wasi/libc-top-half/musl/src/ctype/__ctype_tolower_loc.c",
    "wasi/libc-top-half/musl/src/ctype/__ctype_toupper_loc.c",
    "wasi/libc-top-half/musl/src/ctype/isalnum.c",
    "wasi/libc-top-half/musl/src/ctype/isalpha.c",
    "wasi/libc-top-half/musl/src/ctype/isascii.c",
    "wasi/libc-top-half/musl/src/ctype/isblank.c",
    "wasi/libc-top-half/musl/src/ctype/iscntrl.c",
    "wasi/libc-top-half/musl/src/ctype/isdigit.c",
    "wasi/libc-top-half/musl/src/ctype/isgraph.c",
    "wasi/libc-top-half/musl/src/ctype/islower.c",
    "wasi/libc-top-half/musl/src/ctype/isprint.c",
    "wasi/libc-top-half/musl/src/ctype/ispunct.c",
    "wasi/libc-top-half/musl/src/ctype/isspace.c",
    "wasi/libc-top-half/musl/src/ctype/isupper.c",
    "wasi/libc-top-half/musl/src/ctype/iswalnum.c",
    "wasi/libc-top-half/musl/src/ctype/iswalpha.c",
    "wasi/libc-top-half/musl/src/ctype/iswblank.c",
    "wasi/libc-top-half/musl/src/ctype/iswcntrl.c",
    "wasi/libc-top-half/musl/src/ctype/iswctype.c",
    "wasi/libc-top-half/musl/src/ctype/iswdigit.c",
    "wasi/libc-top-half/musl/src/ctype/iswgraph.c",
    "wasi/libc-top-half/musl/src/ctype/iswlower.c",
    "wasi/libc-top-half/musl/src/ctype/iswprint.c",
    "wasi/libc-top-half/musl/src/ctype/iswpunct.c",
    "wasi/libc-top-half/musl/src/ctype/iswspace.c",
    "wasi/libc-top-half/musl/src/ctype/iswupper.c",
    "wasi/libc-top-half/musl/src/ctype/iswxdigit.c",
    "wasi/libc-top-half/musl/src/ctype/isxdigit.c",
    "wasi/libc-top-half/musl/src/ctype/toascii.c",
    "wasi/libc-top-half/musl/src/ctype/tolower.c",
    "wasi/libc-top-half/musl/src/ctype/toupper.c",
    "wasi/libc-top-half/musl/src/ctype/towctrans.c",
    "wasi/libc-top-half/musl/src/ctype/wcswidth.c",
    "wasi/libc-top-half/musl/src/ctype/wctrans.c",
    "wasi/libc-top-half/musl/src/ctype/wcwidth.c",
    "wasi/libc-top-half/musl/src/math/__cos.c",
    "wasi/libc-top-half/musl/src/math/__cosdf.c",
    "wasi/libc-top-half/musl/src/math/__cosl.c",
    "wasi/libc-top-half/musl/src/math/__expo2.c",
    "wasi/libc-top-half/musl/src/math/__expo2f.c",
    "wasi/libc-top-half/musl/src/math/__invtrigl.c",
    "wasi/libc-top-half/musl/src/math/__math_divzero.c",
    "wasi/libc-top-half/musl/src/math/__math_divzerof.c",
    "wasi/libc-top-half/musl/src/math/__math_invalid.c",
    "wasi/libc-top-half/musl/src/math/__math_invalidf.c",
    "wasi/libc-top-half/musl/src/math/__math_invalidl.c",
    "wasi/libc-top-half/musl/src/math/__math_oflow.c",
    "wasi/libc-top-half/musl/src/math/__math_oflowf.c",
    "wasi/libc-top-half/musl/src/math/__math_uflow.c",
    "wasi/libc-top-half/musl/src/math/__math_uflowf.c",
    "wasi/libc-top-half/musl/src/math/__math_xflow.c",
    "wasi/libc-top-half/musl/src/math/__math_xflowf.c",
    "wasi/libc-top-half/musl/src/math/__polevll.c",
    "wasi/libc-top-half/musl/src/math/__rem_pio2.c",
    "wasi/libc-top-half/musl/src/math/__rem_pio2_large.c",
    "wasi/libc-top-half/musl/src/math/__rem_pio2f.c",
    "wasi/libc-top-half/musl/src/math/__rem_pio2l.c",
    "wasi/libc-top-half/musl/src/math/__sin.c",
    "wasi/libc-top-half/musl/src/math/__sindf.c",
    "wasi/libc-top-half/musl/src/math/__sinl.c",
    "wasi/libc-top-half/musl/src/math/__tan.c",
    "wasi/libc-top-half/musl/src/math/__tandf.c",
    "wasi/libc-top-half/musl/src/math/__tanl.c",
    "wasi/libc-top-half/musl/src/math/acos.c",
    "wasi/libc-top-half/musl/src/math/acosf.c",
    "wasi/libc-top-half/musl/src/math/acosh.c",
    "wasi/libc-top-half/musl/src/math/acoshf.c",
    "wasi/libc-top-half/musl/src/math/acoshl.c",
    "wasi/libc-top-half/musl/src/math/acosl.c",
    "wasi/libc-top-half/musl/src/math/asin.c",
    "wasi/libc-top-half/musl/src/math/asinf.c",
    "wasi/libc-top-half/musl/src/math/asinh.c",
    "wasi/libc-top-half/musl/src/math/asinhf.c",
    "wasi/libc-top-half/musl/src/math/asinhl.c",
    "wasi/libc-top-half/musl/src/math/asinl.c",
    "wasi/libc-top-half/musl/src/math/atan.c",
    "wasi/libc-top-half/musl/src/math/atan2.c",
    "wasi/libc-top-half/musl/src/math/atan2f.c",
    "wasi/libc-top-half/musl/src/math/atan2l.c",
    "wasi/libc-top-half/musl/src/math/atanf.c",
    "wasi/libc-top-half/musl/src/math/atanh.c",
    "wasi/libc-top-half/musl/src/math/atanhf.c",
    "wasi/libc-top-half/musl/src/math/atanhl.c",
    "wasi/libc-top-half/musl/src/math/atanl.c",
    "wasi/libc-top-half/musl/src/math/cbrt.c",
    "wasi/libc-top-half/musl/src/math/cbrtf.c",
    "wasi/libc-top-half/musl/src/math/cbrtl.c",
    "wasi/libc-top-half/musl/src/math/ceill.c",
    "wasi/libc-top-half/musl/src/math/copysignl.c",
    "wasi/libc-top-half/musl/src/math/cos.c",
    "wasi/libc-top-half/musl/src/math/cosf.c",
    "wasi/libc-top-half/musl/src/math/cosh.c",
    "wasi/libc-top-half/musl/src/math/coshf.c",
    "wasi/libc-top-half/musl/src/math/coshl.c",
    "wasi/libc-top-half/musl/src/math/cosl.c",
    "wasi/libc-top-half/musl/src/math/erf.c",
    "wasi/libc-top-half/musl/src/math/erff.c",
    "wasi/libc-top-half/musl/src/math/erfl.c",
    "wasi/libc-top-half/musl/src/math/exp.c",
    "wasi/libc-top-half/musl/src/math/exp10.c",
    "wasi/libc-top-half/musl/src/math/exp10f.c",
    "wasi/libc-top-half/musl/src/math/exp10l.c",
    "wasi/libc-top-half/musl/src/math/exp2.c",
    "wasi/libc-top-half/musl/src/math/exp2f.c",
    "wasi/libc-top-half/musl/src/math/exp2f_data.c",
    "wasi/libc-top-half/musl/src/math/exp2l.c",
    "wasi/libc-top-half/musl/src/math/exp_data.c",
    "wasi/libc-top-half/musl/src/math/expf.c",
    "wasi/libc-top-half/musl/src/math/expl.c",
    "wasi/libc-top-half/musl/src/math/expm1.c",
    "wasi/libc-top-half/musl/src/math/expm1f.c",
    "wasi/libc-top-half/musl/src/math/expm1l.c",
    "wasi/libc-top-half/musl/src/math/fabsl.c",
    "wasi/libc-top-half/musl/src/math/fdim.c",
    "wasi/libc-top-half/musl/src/math/fdimf.c",
    "wasi/libc-top-half/musl/src/math/fdiml.c",
    "wasi/libc-top-half/musl/src/math/finite.c",
    "wasi/libc-top-half/musl/src/math/finitef.c",
    "wasi/libc-top-half/musl/src/math/floorl.c",
    "wasi/libc-top-half/musl/src/math/fma.c",
    "wasi/libc-top-half/musl/src/math/fmaf.c",
    "wasi/libc-top-half/musl/src/math/fmal.c",
    "wasi/libc-top-half/musl/src/math/fmaxl.c",
    "wasi/libc-top-half/musl/src/math/fminl.c",
    "wasi/libc-top-half/musl/src/math/fmod.c",
    "wasi/libc-top-half/musl/src/math/fmodf.c",
    "wasi/libc-top-half/musl/src/math/fmodl.c",
    "wasi/libc-top-half/musl/src/math/frexp.c",
    "wasi/libc-top-half/musl/src/math/frexpf.c",
    "wasi/libc-top-half/musl/src/math/frexpl.c",
    "wasi/libc-top-half/musl/src/math/hypot.c",
    "wasi/libc-top-half/musl/src/math/hypotf.c",
    "wasi/libc-top-half/musl/src/math/hypotl.c",
    "wasi/libc-top-half/musl/src/math/ilogb.c",
    "wasi/libc-top-half/musl/src/math/ilogbf.c",
    "wasi/libc-top-half/musl/src/math/ilogbl.c",
    "wasi/libc-top-half/musl/src/math/j0.c",
    "wasi/libc-top-half/musl/src/math/j0f.c",
    "wasi/libc-top-half/musl/src/math/j1.c",
    "wasi/libc-top-half/musl/src/math/j1f.c",
    "wasi/libc-top-half/musl/src/math/jn.c",
    "wasi/libc-top-half/musl/src/math/jnf.c",
    "wasi/libc-top-half/musl/src/math/ldexp.c",
    "wasi/libc-top-half/musl/src/math/ldexpf.c",
    "wasi/libc-top-half/musl/src/math/ldexpl.c",
    "wasi/libc-top-half/musl/src/math/lgamma.c",
    "wasi/libc-top-half/musl/src/math/lgamma_r.c",
    "wasi/libc-top-half/musl/src/math/lgammaf.c",
    "wasi/libc-top-half/musl/src/math/lgammaf_r.c",
    "wasi/libc-top-half/musl/src/math/lgammal.c",
    "wasi/libc-top-half/musl/src/math/llrint.c",
    "wasi/libc-top-half/musl/src/math/llrintf.c",
    "wasi/libc-top-half/musl/src/math/llrintl.c",
    "wasi/libc-top-half/musl/src/math/llround.c",
    "wasi/libc-top-half/musl/src/math/llroundf.c",
    "wasi/libc-top-half/musl/src/math/llroundl.c",
    "wasi/libc-top-half/musl/src/math/log.c",
    "wasi/libc-top-half/musl/src/math/log10.c",
    "wasi/libc-top-half/musl/src/math/log10f.c",
    "wasi/libc-top-half/musl/src/math/log10l.c",
    "wasi/libc-top-half/musl/src/math/log1p.c",
    "wasi/libc-top-half/musl/src/math/log1pf.c",
    "wasi/libc-top-half/musl/src/math/log1pl.c",
    "wasi/libc-top-half/musl/src/math/log2.c",
    "wasi/libc-top-half/musl/src/math/log2_data.c",
    "wasi/libc-top-half/musl/src/math/log2f.c",
    "wasi/libc-top-half/musl/src/math/log2f_data.c",
    "wasi/libc-top-half/musl/src/math/log2l.c",
    "wasi/libc-top-half/musl/src/math/log_data.c",
    "wasi/libc-top-half/musl/src/math/logb.c",
    "wasi/libc-top-half/musl/src/math/logbf.c",
    "wasi/libc-top-half/musl/src/math/logbl.c",
    "wasi/libc-top-half/musl/src/math/logf.c",
    "wasi/libc-top-half/musl/src/math/logf_data.c",
    "wasi/libc-top-half/musl/src/math/logl.c",
    "wasi/libc-top-half/musl/src/math/lrint.c",
    "wasi/libc-top-half/musl/src/math/lrintf.c",
    "wasi/libc-top-half/musl/src/math/lrintl.c",
    "wasi/libc-top-half/musl/src/math/lround.c",
    "wasi/libc-top-half/musl/src/math/lroundf.c",
    "wasi/libc-top-half/musl/src/math/lroundl.c",
    "wasi/libc-top-half/musl/src/math/modf.c",
    "wasi/libc-top-half/musl/src/math/modff.c",
    "wasi/libc-top-half/musl/src/math/modfl.c",
    "wasi/libc-top-half/musl/src/math/nan.c",
    "wasi/libc-top-half/musl/src/math/nanf.c",
    "wasi/libc-top-half/musl/src/math/nanl.c",
    "wasi/libc-top-half/musl/src/math/nearbyintl.c",
    "wasi/libc-top-half/musl/src/math/nextafter.c",
    "wasi/libc-top-half/musl/src/math/nextafterf.c",
    "wasi/libc-top-half/musl/src/math/nextafterl.c",
    "wasi/libc-top-half/musl/src/math/nexttoward.c",
    "wasi/libc-top-half/musl/src/math/nexttowardf.c",
    "wasi/libc-top-half/musl/src/math/nexttowardl.c",
    "wasi/libc-top-half/musl/src/math/pow.c",
    "wasi/libc-top-half/musl/src/math/pow_data.c",
    "wasi/libc-top-half/musl/src/math/powf.c",
    "wasi/libc-top-half/musl/src/math/powf_data.c",
    "wasi/libc-top-half/musl/src/math/powl.c",
    "wasi/libc-top-half/musl/src/math/remainder.c",
    "wasi/libc-top-half/musl/src/math/remainderf.c",
    "wasi/libc-top-half/musl/src/math/remainderl.c",
    "wasi/libc-top-half/musl/src/math/remquo.c",
    "wasi/libc-top-half/musl/src/math/remquof.c",
    "wasi/libc-top-half/musl/src/math/remquol.c",
    "wasi/libc-top-half/musl/src/math/rintl.c",
    "wasi/libc-top-half/musl/src/math/round.c",
    "wasi/libc-top-half/musl/src/math/roundf.c",
    "wasi/libc-top-half/musl/src/math/roundl.c",
    "wasi/libc-top-half/musl/src/math/scalb.c",
    "wasi/libc-top-half/musl/src/math/scalbf.c",
    "wasi/libc-top-half/musl/src/math/scalbln.c",
    "wasi/libc-top-half/musl/src/math/scalblnf.c",
    "wasi/libc-top-half/musl/src/math/scalblnl.c",
    "wasi/libc-top-half/musl/src/math/scalbn.c",
    "wasi/libc-top-half/musl/src/math/scalbnf.c",
    "wasi/libc-top-half/musl/src/math/scalbnl.c",
    "wasi/libc-top-half/musl/src/math/signgam.c",
    "wasi/libc-top-half/musl/src/math/significand.c",
    "wasi/libc-top-half/musl/src/math/significandf.c",
    "wasi/libc-top-half/musl/src/math/sin.c",
    "wasi/libc-top-half/musl/src/math/sincos.c",
    "wasi/libc-top-half/musl/src/math/sincosf.c",
    "wasi/libc-top-half/musl/src/math/sincosl.c",
    "wasi/libc-top-half/musl/src/math/sinf.c",
    "wasi/libc-top-half/musl/src/math/sinh.c",
    "wasi/libc-top-half/musl/src/math/sinhf.c",
    "wasi/libc-top-half/musl/src/math/sinhl.c",
    "wasi/libc-top-half/musl/src/math/sinl.c",
    "wasi/libc-top-half/musl/src/math/sqrt_data.c",
    "wasi/libc-top-half/musl/src/math/sqrtl.c",
    "wasi/libc-top-half/musl/src/math/tan.c",
    "wasi/libc-top-half/musl/src/math/tanf.c",
    "wasi/libc-top-half/musl/src/math/tanh.c",
    "wasi/libc-top-half/musl/src/math/tanhf.c",
    "wasi/libc-top-half/musl/src/math/tanhl.c",
    "wasi/libc-top-half/musl/src/math/tanl.c",
    "wasi/libc-top-half/musl/src/math/tgamma.c",
    "wasi/libc-top-half/musl/src/math/tgammaf.c",
    "wasi/libc-top-half/musl/src/math/tgammal.c",
    "wasi/libc-top-half/musl/src/math/truncl.c",
    "wasi/libc-top-half/musl/src/complex/__cexp.c",
    "wasi/libc-top-half/musl/src/complex/__cexpf.c",
    "wasi/libc-top-half/musl/src/complex/cabs.c",
    "wasi/libc-top-half/musl/src/complex/cabsf.c",
    "wasi/libc-top-half/musl/src/complex/cabsl.c",
    "wasi/libc-top-half/musl/src/complex/cacos.c",
    "wasi/libc-top-half/musl/src/complex/cacosf.c",
    "wasi/libc-top-half/musl/src/complex/cacosh.c",
    "wasi/libc-top-half/musl/src/complex/cacoshf.c",
    "wasi/libc-top-half/musl/src/complex/cacoshl.c",
    "wasi/libc-top-half/musl/src/complex/cacosl.c",
    "wasi/libc-top-half/musl/src/complex/carg.c",
    "wasi/libc-top-half/musl/src/complex/cargf.c",
    "wasi/libc-top-half/musl/src/complex/cargl.c",
    "wasi/libc-top-half/musl/src/complex/casin.c",
    "wasi/libc-top-half/musl/src/complex/casinf.c",
    "wasi/libc-top-half/musl/src/complex/casinh.c",
    "wasi/libc-top-half/musl/src/complex/casinhf.c",
    "wasi/libc-top-half/musl/src/complex/casinhl.c",
    "wasi/libc-top-half/musl/src/complex/casinl.c",
    "wasi/libc-top-half/musl/src/complex/catan.c",
    "wasi/libc-top-half/musl/src/complex/catanf.c",
    "wasi/libc-top-half/musl/src/complex/catanh.c",
    "wasi/libc-top-half/musl/src/complex/catanhf.c",
    "wasi/libc-top-half/musl/src/complex/catanhl.c",
    "wasi/libc-top-half/musl/src/complex/catanl.c",
    "wasi/libc-top-half/musl/src/complex/ccos.c",
    "wasi/libc-top-half/musl/src/complex/ccosf.c",
    "wasi/libc-top-half/musl/src/complex/ccosh.c",
    "wasi/libc-top-half/musl/src/complex/ccoshf.c",
    "wasi/libc-top-half/musl/src/complex/ccoshl.c",
    "wasi/libc-top-half/musl/src/complex/ccosl.c",
    "wasi/libc-top-half/musl/src/complex/cexp.c",
    "wasi/libc-top-half/musl/src/complex/cexpf.c",
    "wasi/libc-top-half/musl/src/complex/cexpl.c",
    "wasi/libc-top-half/musl/src/complex/clog.c",
    "wasi/libc-top-half/musl/src/complex/clogf.c",
    "wasi/libc-top-half/musl/src/complex/clogl.c",
    "wasi/libc-top-half/musl/src/complex/conj.c",
    "wasi/libc-top-half/musl/src/complex/conjf.c",
    "wasi/libc-top-half/musl/src/complex/conjl.c",
    "wasi/libc-top-half/musl/src/complex/cpow.c",
    "wasi/libc-top-half/musl/src/complex/cpowf.c",
    "wasi/libc-top-half/musl/src/complex/cpowl.c",
    "wasi/libc-top-half/musl/src/complex/cproj.c",
    "wasi/libc-top-half/musl/src/complex/cprojf.c",
    "wasi/libc-top-half/musl/src/complex/cprojl.c",
    "wasi/libc-top-half/musl/src/complex/csin.c",
    "wasi/libc-top-half/musl/src/complex/csinf.c",
    "wasi/libc-top-half/musl/src/complex/csinh.c",
    "wasi/libc-top-half/musl/src/complex/csinhf.c",
    "wasi/libc-top-half/musl/src/complex/csinhl.c",
    "wasi/libc-top-half/musl/src/complex/csinl.c",
    "wasi/libc-top-half/musl/src/complex/csqrt.c",
    "wasi/libc-top-half/musl/src/complex/csqrtf.c",
    "wasi/libc-top-half/musl/src/complex/csqrtl.c",
    "wasi/libc-top-half/musl/src/complex/ctan.c",
    "wasi/libc-top-half/musl/src/complex/ctanf.c",
    "wasi/libc-top-half/musl/src/complex/ctanh.c",
    "wasi/libc-top-half/musl/src/complex/ctanhf.c",
    "wasi/libc-top-half/musl/src/complex/ctanhl.c",
    "wasi/libc-top-half/musl/src/complex/ctanl.c",
    "wasi/libc-top-half/musl/src/crypt/crypt.c",
    "wasi/libc-top-half/musl/src/crypt/crypt_blowfish.c",
    "wasi/libc-top-half/musl/src/crypt/crypt_des.c",
    "wasi/libc-top-half/musl/src/crypt/crypt_md5.c",
    "wasi/libc-top-half/musl/src/crypt/crypt_r.c",
    "wasi/libc-top-half/musl/src/crypt/crypt_sha256.c",
    "wasi/libc-top-half/musl/src/crypt/crypt_sha512.c",
    "wasi/libc-top-half/musl/src/crypt/encrypt.c",
    "wasi/libc-top-half/sources/arc4random.c",
};

const crt1_command_src_file = "wasi/libc-bottom-half/crt/crt1-command.c";
const crt1_reactor_src_file = "wasi/libc-bottom-half/crt/crt1-reactor.c";

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
    "wasi/libc-top-half/musl/src/signal/psignal.c",
    "wasi/libc-top-half/musl/src/string/strsignal.c",
};
