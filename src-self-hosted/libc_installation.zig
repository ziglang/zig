const std = @import("std");
const builtin = @import("builtin");
const event = std.event;
const Target = @import("target.zig").Target;
const c = @import("c.zig");

/// See the render function implementation for documentation of the fields.
pub const LibCInstallation = struct {
    include_dir: []const u8,
    lib_dir: ?[]const u8,
    static_lib_dir: ?[]const u8,
    msvc_lib_dir: ?[]const u8,
    kernel32_lib_dir: ?[]const u8,
    dynamic_linker_path: ?[]const u8,

    pub const FindError = error{
        OutOfMemory,
        FileSystem,
        UnableToSpawnCCompiler,
        CCompilerExitCode,
        CCompilerCrashed,
        CCompilerCannotFindHeaders,
        CCompilerCannotFindCRuntime,
        LibCStdLibHeaderNotFound,
    };

    pub fn parse(
        self: *LibCInstallation,
        allocator: *std.mem.Allocator,
        libc_file: []const u8,
        stderr: *std.io.OutStream(std.io.FileOutStream.Error),
    ) !void {
        self.initEmpty();

        const keys = []const []const u8{
            "include_dir",
            "lib_dir",
            "static_lib_dir",
            "msvc_lib_dir",
            "kernel32_lib_dir",
            "dynamic_linker_path",
        };
        const FoundKey = struct {
            found: bool,
            allocated: ?[]u8,
        };
        var found_keys = [1]FoundKey{FoundKey{ .found = false, .allocated = null }} ** keys.len;
        errdefer {
            self.initEmpty();
            for (found_keys) |found_key| {
                if (found_key.allocated) |s| allocator.free(s);
            }
        }

        const contents = try std.io.readFileAlloc(allocator, libc_file);
        defer allocator.free(contents);

        var it = std.mem.split(contents, "\n");
        while (it.next()) |line| {
            if (line.len == 0 or line[0] == '#') continue;
            var line_it = std.mem.split(line, "=");
            const name = line_it.next() orelse {
                try stderr.print("missing equal sign after field name\n");
                return error.ParseError;
            };
            const value = line_it.rest();
            inline for (keys) |key, i| {
                if (std.mem.eql(u8, name, key)) {
                    found_keys[i].found = true;
                    switch (@typeInfo(@typeOf(@field(self, key)))) {
                        builtin.TypeId.Optional => {
                            if (value.len == 0) {
                                @field(self, key) = null;
                            } else {
                                found_keys[i].allocated = try std.mem.dupe(allocator, u8, value);
                                @field(self, key) = found_keys[i].allocated;
                            }
                        },
                        else => {
                            if (value.len == 0) {
                                try stderr.print("field cannot be empty: {}\n", key);
                                return error.ParseError;
                            }
                            const dupe = try std.mem.dupe(allocator, u8, value);
                            found_keys[i].allocated = dupe;
                            @field(self, key) = dupe;
                        },
                    }
                    break;
                }
            }
        }
        for (found_keys) |found_key, i| {
            if (!found_key.found) {
                try stderr.print("missing field: {}\n", keys[i]);
                return error.ParseError;
            }
        }
    }

    pub fn render(self: *const LibCInstallation, out: *std.io.OutStream(std.io.FileOutStream.Error)) !void {
        @setEvalBranchQuota(4000);
        try out.print(
            \\# The directory that contains `stdlib.h`.
            \\# On Linux, can be found with: `cc -E -Wp,-v -xc /dev/null`
            \\include_dir={}
            \\
            \\# The directory that contains `crt1.o`.
            \\# On Linux, can be found with `cc -print-file-name=crt1.o`.
            \\# Not needed when targeting MacOS.
            \\lib_dir={}
            \\
            \\# The directory that contains `crtbegin.o`.
            \\# On Linux, can be found with `cc -print-file-name=crt1.o`.
            \\# Not needed when targeting MacOS or Windows.
            \\static_lib_dir={}
            \\
            \\# The directory that contains `vcruntime.lib`.
            \\# Only needed when targeting Windows.
            \\msvc_lib_dir={}
            \\
            \\# The directory that contains `kernel32.lib`.
            \\# Only needed when targeting Windows.
            \\kernel32_lib_dir={}
            \\
            \\# The full path to the dynamic linker, on the target system.
            \\# Only needed when targeting Linux.
            \\dynamic_linker_path={}
            \\
        ,
            self.include_dir,
            self.lib_dir orelse "",
            self.static_lib_dir orelse "",
            self.msvc_lib_dir orelse "",
            self.kernel32_lib_dir orelse "",
            self.dynamic_linker_path orelse Target(Target.Native).getDynamicLinkerPath(),
        );
    }

    /// Finds the default, native libc.
    pub async fn findNative(self: *LibCInstallation, loop: *event.Loop) !void {
        self.initEmpty();
        var group = event.Group(FindError!void).init(loop);
        errdefer group.cancelAll();
        switch (builtin.os) {
            builtin.Os.windows => {
                var sdk: *c.ZigWindowsSDK = undefined;
                switch (c.zig_find_windows_sdk(@ptrCast(?[*]?[*]c.ZigWindowsSDK, &sdk))) {
                    c.ZigFindWindowsSdkError.None => {
                        defer c.zig_free_windows_sdk(@ptrCast(?[*]c.ZigWindowsSDK, sdk));

                        errdefer if (self.msvc_lib_dir) |s| loop.allocator.free(s);
                        if (sdk.msvc_lib_dir_ptr) |ptr| {
                            self.msvc_lib_dir = try std.mem.dupe(loop.allocator, u8, ptr[0..sdk.msvc_lib_dir_len]);
                        }
                        //try group.call(findNativeIncludeDirWindows, self, loop);
                        //try group.call(findNativeLibDirWindows, self, loop);
                        //try group.call(findNativeMsvcLibDir, self, loop);
                        //try group.call(findNativeKernel32LibDir, self, loop);
                    },
                    c.ZigFindWindowsSdkError.OutOfMemory => return error.OutOfMemory,
                    c.ZigFindWindowsSdkError.NotFound => return error.NotFound,
                    c.ZigFindWindowsSdkError.PathTooLong => return error.NotFound,
                }
            },
            builtin.Os.linux => {
                try group.call(findNativeIncludeDirLinux, self, loop);
                try group.call(findNativeLibDirLinux, self, loop);
                try group.call(findNativeStaticLibDir, self, loop);
                try group.call(findNativeDynamicLinker, self, loop);
            },
            builtin.Os.macosx => {
                self.include_dir = try std.mem.dupe(loop.allocator, u8, "/usr/include");
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

    async fn findNativeLibDirWindows(self: *LibCInstallation, loop: *event.Loop) FindError!void {
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

    async fn findNativeLibDirLinux(self: *LibCInstallation, loop: *event.Loop) FindError!void {
        self.lib_dir = try await (async ccPrintFileName(loop, "crt1.o", true) catch unreachable);
    }

    async fn findNativeStaticLibDir(self: *LibCInstallation, loop: *event.Loop) FindError!void {
        self.static_lib_dir = try await (async ccPrintFileName(loop, "crtbegin.o", true) catch unreachable);
    }

    async fn findNativeDynamicLinker(self: *LibCInstallation, loop: *event.Loop) FindError!void {
        var dyn_tests = []DynTest{
            DynTest{
                .name = "ld-linux-x86-64.so.2",
                .result = null,
            },
            DynTest{
                .name = "ld-musl-x86_64.so.1",
                .result = null,
            },
        };
        var group = event.Group(FindError!void).init(loop);
        errdefer group.cancelAll();
        for (dyn_tests) |*dyn_test| {
            try group.call(testNativeDynamicLinker, self, loop, dyn_test);
        }
        try await (async group.wait() catch unreachable);
        for (dyn_tests) |*dyn_test| {
            if (dyn_test.result) |result| {
                self.dynamic_linker_path = result;
                return;
            }
        }
    }

    const DynTest = struct {
        name: []const u8,
        result: ?[]const u8,
    };

    async fn testNativeDynamicLinker(self: *LibCInstallation, loop: *event.Loop, dyn_test: *DynTest) FindError!void {
        if (await (async ccPrintFileName(loop, dyn_test.name, false) catch unreachable)) |result| {
            dyn_test.result = result;
            return;
        } else |err| switch (err) {
            error.CCompilerCannotFindCRuntime => return,
            else => return err,
        }
    }

    async fn findNativeMsvcLibDir(self: *LibCInstallation, loop: *event.Loop) FindError!void {
        @panic("TODO");
    }

    async fn findNativeKernel32LibDir(self: *LibCInstallation, loop: *event.Loop) FindError!void {
        @panic("TODO");
    }

    fn initEmpty(self: *LibCInstallation) void {
        self.* = LibCInstallation{
            .include_dir = ([*]const u8)(undefined)[0..0],
            .lib_dir = null,
            .static_lib_dir = null,
            .msvc_lib_dir = null,
            .kernel32_lib_dir = null,
            .dynamic_linker_path = null,
        };
    }
};

/// caller owns returned memory
async fn ccPrintFileName(loop: *event.Loop, o_file: []const u8, want_dirname: bool) ![]u8 {
    const cc_exe = std.os.getEnvPosix("CC") orelse "cc";
    const arg1 = try std.fmt.allocPrint(loop.allocator, "-print-file-name={}", o_file);
    defer loop.allocator.free(arg1);
    const argv = []const []const u8{ cc_exe, arg1 };

    // TODO This simulates evented I/O for the child process exec
    await (async loop.yield() catch unreachable);
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

    if (want_dirname) {
        return std.mem.dupe(loop.allocator, u8, dirname);
    } else {
        return std.mem.dupe(loop.allocator, u8, line);
    }
}
