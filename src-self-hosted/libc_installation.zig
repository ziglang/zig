const std = @import("std");
const builtin = @import("builtin");
const event = std.event;

pub const LibCInstallation = struct {
    /// The directory that contains `stdlib.h`.
    /// On Linux, can be found with: `cc -E -Wp,-v -xc /dev/null`
    include_dir: []const u8,

    /// The directory that contains `crt1.o`.
    /// On Linux, can be found with `cc -print-file-name=crt1.o`.
    /// Not needed when targeting MacOS.
    lib_dir: ?[]const u8,

    /// The directory that contains `crtbegin.o`.
    /// On Linux, can be found with `cc -print-file-name=crt1.o`.
    /// Not needed when targeting MacOS or Windows.
    static_lib_dir: ?[]const u8,

    /// The directory that contains `vcruntime.lib`.
    /// Only needed when targeting Windows.
    msvc_lib_dir: ?[]const u8,

    /// The directory that contains `kernel32.lib`.
    /// Only needed when targeting Windows.
    kernel32_lib_dir: ?[]const u8,

    pub const Error = error{
        OutOfMemory,
        FileSystem,
        UnableToSpawnCCompiler,
        CCompilerExitCode,
        CCompilerCrashed,
        CCompilerCannotFindHeaders,
        CCompilerCannotFindCRuntime,
        LibCStdLibHeaderNotFound,
    };

    /// Finds the default, native libc.
    pub async fn findNative(self: *LibCInstallation, loop: *event.Loop) !void {
        self.* = LibCInstallation{
            .lib_dir = null,
            .include_dir = ([*]const u8)(undefined)[0..0],
            .static_lib_dir = null,
            .msvc_lib_dir = null,
            .kernel32_lib_dir = null,
        };
        var group = event.Group(Error!void).init(loop);
        switch (builtin.os) {
            builtin.Os.windows => {
                try group.call(findNativeIncludeDirWindows, self, loop);
                try group.call(findNativeLibDirWindows, self, loop);
                try group.call(findNativeMsvcLibDir, self, loop);
                try group.call(findNativeKernel32LibDir, self, loop);
            },
            builtin.Os.linux => {
                try group.call(findNativeIncludeDirLinux, self, loop);
                try group.call(findNativeLibDirLinux, self, loop);
                try group.call(findNativeStaticLibDir, self, loop);
            },
            builtin.Os.macosx => {
                try group.call(findNativeIncludeDirMacOS, self, loop);
            },
            else => @compileError("unimplemented: find libc for this OS"),
        }
        return await (async group.wait() catch unreachable);
    }

    async fn findNativeIncludeDirLinux(self: *LibCInstallation, loop: *event.Loop) !void {
        const cc_exe = std.os.getEnvPosix("CC") orelse "cc";
        const argv = []const []const u8{
            cc_exe,
            "-E",
            "-Wp,-v",
            "-xc",
            "/dev/null",
        };
        // TODO make this use event loop
        const errorable_result = std.os.ChildProcess.exec(loop.allocator, argv, null, null, 1024 * 1024);
        const exec_result = if (std.debug.runtime_safety) blk: {
            break :blk errorable_result catch unreachable;
        } else blk: {
            break :blk errorable_result catch |err| switch (err) {
                error.OutOfMemory => return error.OutOfMemory,
                else => return error.UnableToSpawnCCompiler,
            };
        };
        defer {
            loop.allocator.free(exec_result.stdout);
            loop.allocator.free(exec_result.stderr);
        }

        switch (exec_result.term) {
            std.os.ChildProcess.Term.Exited => |code| {
                if (code != 0) return error.CCompilerExitCode;
            },
            else => {
                return error.CCompilerCrashed;
            },
        }

        var it = std.mem.split(exec_result.stderr, "\n\r");
        var search_paths = std.ArrayList([]const u8).init(loop.allocator);
        defer search_paths.deinit();
        while (it.next()) |line| {
            if (line.len != 0 and line[0] == ' ') {
                try search_paths.append(line);
            }
        }
        if (search_paths.len == 0) {
            return error.CCompilerCannotFindHeaders;
        }

        // search in reverse order
        var path_i: usize = 0;
        while (path_i < search_paths.len) : (path_i += 1) {
            const search_path_untrimmed = search_paths.at(search_paths.len - path_i - 1);
            const search_path = std.mem.trimLeft(u8, search_path_untrimmed, " ");
            const stdlib_path = try std.os.path.join(loop.allocator, search_path, "stdlib.h");
            defer loop.allocator.free(stdlib_path);

            if (std.os.File.access(loop.allocator, stdlib_path)) |_| {
                self.include_dir = try std.mem.dupe(loop.allocator, u8, search_path);
                return;
            } else |err| switch (err) {
                error.NotFound, error.PermissionDenied => continue,
                error.OutOfMemory => return error.OutOfMemory,
                else => return error.FileSystem,
            }
        }

        return error.LibCStdLibHeaderNotFound;
    }

    async fn findNativeIncludeDirWindows(self: *LibCInstallation, loop: *event.Loop) !void {
        // TODO
        //ZigWindowsSDK *sdk = get_windows_sdk(g);
        //g->libc_include_dir = buf_alloc();
        //if (os_get_win32_ucrt_include_path(sdk, g->libc_include_dir)) {
        //    fprintf(stderr, "Unable to determine libc include path. --libc-include-dir");
        //    exit(1);
        //}
        @panic("TODO");
    }

    async fn findNativeIncludeDirMacOS(self: *LibCInstallation, loop: *event.Loop) !void {
        self.include_dir = try std.mem.dupe(loop.allocator, u8, "/usr/include");
    }

    async fn findNativeLibDirWindows(self: *LibCInstallation, loop: *event.Loop) Error!void {
        // TODO
        //ZigWindowsSDK *sdk = get_windows_sdk(g);

        //if (g->msvc_lib_dir == nullptr) {
        //    Buf* vc_lib_dir = buf_alloc();
        //    if (os_get_win32_vcruntime_path(vc_lib_dir, g->zig_target.arch.arch)) {
        //        fprintf(stderr, "Unable to determine vcruntime path. --msvc-lib-dir");
        //        exit(1);
        //    }
        //    g->msvc_lib_dir = vc_lib_dir;
        //}

        //if (g->libc_lib_dir == nullptr) {
        //    Buf* ucrt_lib_path = buf_alloc();
        //    if (os_get_win32_ucrt_lib_path(sdk, ucrt_lib_path, g->zig_target.arch.arch)) {
        //        fprintf(stderr, "Unable to determine ucrt path. --libc-lib-dir");
        //        exit(1);
        //    }
        //    g->libc_lib_dir = ucrt_lib_path;
        //}

        //if (g->kernel32_lib_dir == nullptr) {
        //    Buf* kern_lib_path = buf_alloc();
        //    if (os_get_win32_kern32_path(sdk, kern_lib_path, g->zig_target.arch.arch)) {
        //        fprintf(stderr, "Unable to determine kernel32 path. --kernel32-lib-dir");
        //        exit(1);
        //    }
        //    g->kernel32_lib_dir = kern_lib_path;
        //}
        @panic("TODO");
    }

    async fn findNativeLibDirLinux(self: *LibCInstallation, loop: *event.Loop) Error!void {
        self.lib_dir = try await (async ccPrintFileNameDir(loop, "crt1.o") catch unreachable);
    }

    async fn findNativeStaticLibDir(self: *LibCInstallation, loop: *event.Loop) Error!void {
        self.static_lib_dir = try await (async ccPrintFileNameDir(loop, "crtbegin.o") catch unreachable);
    }

    async fn findNativeMsvcLibDir(self: *LibCInstallation, loop: *event.Loop) Error!void {
        @panic("TODO");
    }

    async fn findNativeKernel32LibDir(self: *LibCInstallation, loop: *event.Loop) Error!void {
        @panic("TODO");
    }
};

/// caller owns returned memory
async fn ccPrintFileNameDir(loop: *event.Loop, o_file: []const u8) ![]u8 {
    const cc_exe = std.os.getEnvPosix("CC") orelse "cc";
    const arg1 = try std.fmt.allocPrint(loop.allocator, "-print-file-name={}", o_file);
    defer loop.allocator.free(arg1);
    const argv = []const []const u8{ cc_exe, arg1 };

    // TODO evented I/O
    const errorable_result = std.os.ChildProcess.exec(loop.allocator, argv, null, null, 1024 * 1024);
    const exec_result = if (std.debug.runtime_safety) blk: {
        break :blk errorable_result catch unreachable;
    } else blk: {
        break :blk errorable_result catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            else => return error.UnableToSpawnCCompiler,
        };
    };
    defer {
        loop.allocator.free(exec_result.stdout);
        loop.allocator.free(exec_result.stderr);
    }
    switch (exec_result.term) {
        std.os.ChildProcess.Term.Exited => |code| {
            if (code != 0) return error.CCompilerExitCode;
        },
        else => {
            return error.CCompilerCrashed;
        },
    }
    var it = std.mem.split(exec_result.stdout, "\n\r");
    const line = it.next() orelse return error.CCompilerCannotFindCRuntime;
    const dirname = std.os.path.dirname(line) orelse return error.CCompilerCannotFindCRuntime;

    return std.mem.dupe(loop.allocator, u8, dirname);
}
