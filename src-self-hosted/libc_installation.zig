const std = @import("std");
const builtin = @import("builtin");
const event = std.event;
const util = @import("util.zig");
const Target = std.Target;
const c = @import("c.zig");
const fs = std.fs;
const Allocator = std.mem.Allocator;

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
        LibCRuntimeNotFound,
        LibCStdLibHeaderNotFound,
        LibCKernel32LibNotFound,
        UnsupportedArchitecture,
    };

    pub fn parse(
        self: *LibCInstallation,
        allocator: *Allocator,
        libc_file: []const u8,
        stderr: *std.io.OutStream(fs.File.WriteError),
    ) !void {
        self.initEmpty();

        const keys = [_][]const u8{
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

        var it = std.mem.tokenize(contents, "\n");
        while (it.next()) |line| {
            if (line.len == 0 or line[0] == '#') continue;
            var line_it = std.mem.separate(line, "=");
            const name = line_it.next() orelse {
                try stderr.print("missing equal sign after field name\n", .{});
                return error.ParseError;
            };
            const value = line_it.rest();
            inline for (keys) |key, i| {
                if (std.mem.eql(u8, name, key)) {
                    found_keys[i].found = true;
                    switch (@typeInfo(@TypeOf(@field(self, key)))) {
                        .Optional => {
                            if (value.len == 0) {
                                @field(self, key) = null;
                            } else {
                                found_keys[i].allocated = try std.mem.dupe(allocator, u8, value);
                                @field(self, key) = found_keys[i].allocated;
                            }
                        },
                        else => {
                            if (value.len == 0) {
                                try stderr.print("field cannot be empty: {}\n", .{key});
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
                try stderr.print("missing field: {}\n", .{keys[i]});
                return error.ParseError;
            }
        }
    }

    pub fn render(self: *const LibCInstallation, out: *std.io.OutStream(fs.File.WriteError)) !void {
        @setEvalBranchQuota(4000);
        const lib_dir = self.lib_dir orelse "";
        const static_lib_dir = self.static_lib_dir orelse "";
        const msvc_lib_dir = self.msvc_lib_dir orelse "";
        const kernel32_lib_dir = self.kernel32_lib_dir orelse "";
        const dynamic_linker_path = self.dynamic_linker_path orelse util.getDynamicLinkerPath(Target{ .Native = {} });
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
            \\# On Linux, can be found with `cc -print-file-name=crtbegin.o`.
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
        , .{ self.include_dir, lib_dir, static_lib_dir, msvc_lib_dir, kernel32_lib_dir, dynamic_linker_path });
    }

    /// Finds the default, native libc.
    pub fn findNative(self: *LibCInstallation, allocator: *Allocator) !void {
        self.initEmpty();
        var group = event.Group(FindError!void).init(allocator);
        errdefer group.wait() catch {};
        var windows_sdk: ?*c.ZigWindowsSDK = null;
        errdefer if (windows_sdk) |sdk| c.zig_free_windows_sdk(@ptrCast(?[*]c.ZigWindowsSDK, sdk));

        switch (builtin.os) {
            .windows => {
                var sdk: *c.ZigWindowsSDK = undefined;
                switch (c.zig_find_windows_sdk(@ptrCast(?[*]?[*]c.ZigWindowsSDK, &sdk))) {
                    c.ZigFindWindowsSdkError.None => {
                        windows_sdk = sdk;

                        if (sdk.msvc_lib_dir_ptr != 0) {
                            self.msvc_lib_dir = try std.mem.dupe(allocator, u8, sdk.msvc_lib_dir_ptr[0..sdk.msvc_lib_dir_len]);
                        }
                        try group.call(findNativeKernel32LibDir, .{ allocator, self, sdk });
                        try group.call(findNativeIncludeDirWindows, .{ self, allocator, sdk });
                        try group.call(findNativeLibDirWindows, .{ self, allocator, sdk });
                    },
                    c.ZigFindWindowsSdkError.OutOfMemory => return error.OutOfMemory,
                    c.ZigFindWindowsSdkError.NotFound => return error.NotFound,
                    c.ZigFindWindowsSdkError.PathTooLong => return error.NotFound,
                }
            },
            .linux => {
                try group.call(findNativeIncludeDirLinux, .{ self, allocator });
                try group.call(findNativeLibDirLinux, .{ self, allocator });
                try group.call(findNativeStaticLibDir, .{ self, allocator });
                try group.call(findNativeDynamicLinker, .{ self, allocator });
            },
            .macosx, .freebsd, .netbsd => {
                self.include_dir = try std.mem.dupe(allocator, u8, "/usr/include");
            },
            else => @compileError("unimplemented: find libc for this OS"),
        }
        return group.wait();
    }

    async fn findNativeIncludeDirLinux(self: *LibCInstallation, allocator: *Allocator) FindError!void {
        const cc_exe = std.os.getenv("CC") orelse "cc";
        const argv = [_][]const u8{
            cc_exe,
            "-E",
            "-Wp,-v",
            "-xc",
            "/dev/null",
        };
        // TODO make this use event loop
        const errorable_result = std.ChildProcess.exec(allocator, &argv, null, null, 1024 * 1024);
        const exec_result = if (std.debug.runtime_safety) blk: {
            break :blk errorable_result catch unreachable;
        } else blk: {
            break :blk errorable_result catch |err| switch (err) {
                error.OutOfMemory => return error.OutOfMemory,
                else => return error.UnableToSpawnCCompiler,
            };
        };
        defer {
            allocator.free(exec_result.stdout);
            allocator.free(exec_result.stderr);
        }

        switch (exec_result.term) {
            .Exited => |code| {
                if (code != 0) return error.CCompilerExitCode;
            },
            else => {
                return error.CCompilerCrashed;
            },
        }

        var it = std.mem.tokenize(exec_result.stderr, "\n\r");
        var search_paths = std.ArrayList([]const u8).init(allocator);
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
            const stdlib_path = try fs.path.join(allocator, &[_][]const u8{ search_path, "stdlib.h" });
            defer allocator.free(stdlib_path);

            if (try fileExists(stdlib_path)) {
                self.include_dir = try std.mem.dupe(allocator, u8, search_path);
                return;
            }
        }

        return error.LibCStdLibHeaderNotFound;
    }

    async fn findNativeIncludeDirWindows(self: *LibCInstallation, allocator: *Allocator, sdk: *c.ZigWindowsSDK) !void {
        var search_buf: [2]Search = undefined;
        const searches = fillSearch(&search_buf, sdk);

        var result_buf = try std.Buffer.initSize(allocator, 0);
        defer result_buf.deinit();

        for (searches) |search| {
            result_buf.shrink(0);
            const stream = &std.io.BufferOutStream.init(&result_buf).stream;
            try stream.print("{}\\Include\\{}\\ucrt", .{ search.path, search.version });

            const stdlib_path = try fs.path.join(
                allocator,
                [_][]const u8{ result_buf.toSliceConst(), "stdlib.h" },
            );
            defer allocator.free(stdlib_path);

            if (try fileExists(stdlib_path)) {
                self.include_dir = result_buf.toOwnedSlice();
                return;
            }
        }

        return error.LibCStdLibHeaderNotFound;
    }

    async fn findNativeLibDirWindows(self: *LibCInstallation, allocator: *Allocator, sdk: *c.ZigWindowsSDK) FindError!void {
        var search_buf: [2]Search = undefined;
        const searches = fillSearch(&search_buf, sdk);

        var result_buf = try std.Buffer.initSize(allocator, 0);
        defer result_buf.deinit();

        for (searches) |search| {
            result_buf.shrink(0);
            const stream = &std.io.BufferOutStream.init(&result_buf).stream;
            try stream.print("{}\\Lib\\{}\\ucrt\\", .{ search.path, search.version });
            switch (builtin.arch) {
                .i386 => try stream.write("x86"),
                .x86_64 => try stream.write("x64"),
                .aarch64 => try stream.write("arm"),
                else => return error.UnsupportedArchitecture,
            }
            const ucrt_lib_path = try fs.path.join(
                allocator,
                [_][]const u8{ result_buf.toSliceConst(), "ucrt.lib" },
            );
            defer allocator.free(ucrt_lib_path);
            if (try fileExists(ucrt_lib_path)) {
                self.lib_dir = result_buf.toOwnedSlice();
                return;
            }
        }
        return error.LibCRuntimeNotFound;
    }

    async fn findNativeLibDirLinux(self: *LibCInstallation, allocator: *Allocator) FindError!void {
        self.lib_dir = try ccPrintFileName(allocator, "crt1.o", true);
    }

    async fn findNativeStaticLibDir(self: *LibCInstallation, allocator: *Allocator) FindError!void {
        self.static_lib_dir = try ccPrintFileName(allocator, "crtbegin.o", true);
    }

    async fn findNativeDynamicLinker(self: *LibCInstallation, allocator: *Allocator) FindError!void {
        var dyn_tests = [_]DynTest{
            DynTest{
                .name = "ld-linux-x86-64.so.2",
                .result = null,
            },
            DynTest{
                .name = "ld-musl-x86_64.so.1",
                .result = null,
            },
        };
        var group = event.Group(FindError!void).init(allocator);
        errdefer group.wait() catch {};
        for (dyn_tests) |*dyn_test| {
            try group.call(testNativeDynamicLinker, .{ self, allocator, dyn_test });
        }
        try group.wait();
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

    async fn testNativeDynamicLinker(self: *LibCInstallation, allocator: *Allocator, dyn_test: *DynTest) FindError!void {
        if (ccPrintFileName(allocator, dyn_test.name, false)) |result| {
            dyn_test.result = result;
            return;
        } else |err| switch (err) {
            error.LibCRuntimeNotFound => return,
            else => return err,
        }
    }

    async fn findNativeKernel32LibDir(self: *LibCInstallation, allocator: *Allocator, sdk: *c.ZigWindowsSDK) FindError!void {
        var search_buf: [2]Search = undefined;
        const searches = fillSearch(&search_buf, sdk);

        var result_buf = try std.Buffer.initSize(allocator, 0);
        defer result_buf.deinit();

        for (searches) |search| {
            result_buf.shrink(0);
            const stream = &std.io.BufferOutStream.init(&result_buf).stream;
            try stream.print("{}\\Lib\\{}\\um\\", .{ search.path, search.version });
            switch (builtin.arch) {
                .i386 => try stream.write("x86\\"),
                .x86_64 => try stream.write("x64\\"),
                .aarch64 => try stream.write("arm\\"),
                else => return error.UnsupportedArchitecture,
            }
            const kernel32_path = try fs.path.join(
                allocator,
                [_][]const u8{ result_buf.toSliceConst(), "kernel32.lib" },
            );
            defer allocator.free(kernel32_path);
            if (try fileExists(kernel32_path)) {
                self.kernel32_lib_dir = result_buf.toOwnedSlice();
                return;
            }
        }
        return error.LibCKernel32LibNotFound;
    }

    fn initEmpty(self: *LibCInstallation) void {
        self.* = LibCInstallation{
            .include_dir = @as([*]const u8, undefined)[0..0],
            .lib_dir = null,
            .static_lib_dir = null,
            .msvc_lib_dir = null,
            .kernel32_lib_dir = null,
            .dynamic_linker_path = null,
        };
    }
};

/// caller owns returned memory
fn ccPrintFileName(allocator: *Allocator, o_file: []const u8, want_dirname: bool) ![]u8 {
    const cc_exe = std.os.getenv("CC") orelse "cc";
    const arg1 = try std.fmt.allocPrint(allocator, "-print-file-name={}", .{o_file});
    defer allocator.free(arg1);
    const argv = [_][]const u8{ cc_exe, arg1 };

    // TODO This simulates evented I/O for the child process exec
    event.Loop.startCpuBoundOperation();
    const errorable_result = std.ChildProcess.exec(allocator, &argv, null, null, 1024 * 1024);
    const exec_result = if (std.debug.runtime_safety) blk: {
        break :blk errorable_result catch unreachable;
    } else blk: {
        break :blk errorable_result catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            else => return error.UnableToSpawnCCompiler,
        };
    };
    defer {
        allocator.free(exec_result.stdout);
        allocator.free(exec_result.stderr);
    }
    switch (exec_result.term) {
        .Exited => |code| {
            if (code != 0) return error.CCompilerExitCode;
        },
        else => {
            return error.CCompilerCrashed;
        },
    }
    var it = std.mem.tokenize(exec_result.stdout, "\n\r");
    const line = it.next() orelse return error.LibCRuntimeNotFound;
    const dirname = fs.path.dirname(line) orelse return error.LibCRuntimeNotFound;

    if (want_dirname) {
        return std.mem.dupe(allocator, u8, dirname);
    } else {
        return std.mem.dupe(allocator, u8, line);
    }
}

const Search = struct {
    path: []const u8,
    version: []const u8,
};

fn fillSearch(search_buf: *[2]Search, sdk: *c.ZigWindowsSDK) []Search {
    var search_end: usize = 0;
    if (sdk.path10_ptr != 0) {
        if (sdk.version10_ptr != 0) {
            search_buf[search_end] = Search{
                .path = sdk.path10_ptr[0..sdk.path10_len],
                .version = sdk.version10_ptr[0..sdk.version10_len],
            };
            search_end += 1;
        }
    }
    if (sdk.path81_ptr != 0) {
        if (sdk.version81_ptr != 0) {
            search_buf[search_end] = Search{
                .path = sdk.path81_ptr[0..sdk.path81_len],
                .version = sdk.version81_ptr[0..sdk.version81_len],
            };
            search_end += 1;
        }
    }
    return search_buf[0..search_end];
}

fn fileExists(path: []const u8) !bool {
    if (fs.File.access(path)) |_| {
        return true;
    } else |err| switch (err) {
        error.FileNotFound => return false,
        else => return error.FileSystem,
    }
}
