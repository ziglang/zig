const std = @import("std");
const builtin = @import("builtin");
const util = @import("util.zig");
const Target = std.Target;
const fs = std.fs;
const Allocator = std.mem.Allocator;
const Batch = std.event.Batch;

const is_darwin = Target.current.isDarwin();
const is_windows = Target.current.isWindows();
const is_freebsd = Target.current.isFreeBSD();
const is_netbsd = Target.current.isNetBSD();
const is_linux = Target.current.isLinux();
const is_dragonfly = Target.current.isDragonFlyBSD();
const is_gnu = Target.current.isGnu();

usingnamespace @import("windows_sdk.zig");

/// See the render function implementation for documentation of the fields.
pub const LibCInstallation = struct {
    include_dir: ?[:0]const u8 = null,
    sys_include_dir: ?[:0]const u8 = null,
    crt_dir: ?[:0]const u8 = null,
    static_crt_dir: ?[:0]const u8 = null,
    msvc_lib_dir: ?[:0]const u8 = null,
    kernel32_lib_dir: ?[:0]const u8 = null,

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
        WindowsSdkNotFound,
    };

    pub fn parse(
        allocator: *Allocator,
        libc_file: []const u8,
        stderr: *std.io.OutStream(fs.File.WriteError),
    ) !LibCInstallation {
        var self: LibCInstallation = .{};

        const fields = std.meta.fields(LibCInstallation);
        const FoundKey = struct {
            found: bool,
            allocated: ?[:0]u8,
        };
        var found_keys = [1]FoundKey{FoundKey{ .found = false, .allocated = null }} ** fields.len;
        errdefer {
            self = .{};
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
            inline for (fields) |field, i| {
                if (std.mem.eql(u8, name, field.name)) {
                    found_keys[i].found = true;
                    if (value.len == 0) {
                        @field(self, field.name) = null;
                    } else {
                        found_keys[i].allocated = try std.mem.dupeZ(allocator, u8, value);
                        @field(self, field.name) = found_keys[i].allocated;
                    }
                    break;
                }
            }
        }
        inline for (fields) |field, i| {
            if (!found_keys[i].found) {
                try stderr.print("missing field: {}\n", .{field.name});
                return error.ParseError;
            }
        }
        if (self.include_dir == null) {
            try stderr.print("include_dir may not be empty\n", .{});
            return error.ParseError;
        }
        if (self.sys_include_dir == null) {
            try stderr.print("sys_include_dir may not be empty\n", .{});
            return error.ParseError;
        }
        if (self.crt_dir == null and !is_darwin) {
            try stderr.print("crt_dir may not be empty for {}\n", .{@tagName(Target.current.getOs())});
            return error.ParseError;
        }
        if (self.static_crt_dir == null and is_windows and is_gnu) {
            try stderr.print("static_crt_dir may not be empty for {}-{}\n", .{
                @tagName(Target.current.getOs()),
                @tagName(Target.current.getAbi()),
            });
            return error.ParseError;
        }
        if (self.msvc_lib_dir == null and is_windows and !is_gnu) {
            try stderr.print("msvc_lib_dir may not be empty for {}-{}\n", .{
                @tagName(Target.current.getOs()),
                @tagName(Target.current.getAbi()),
            });
            return error.ParseError;
        }
        if (self.kernel32_lib_dir == null and is_windows and !is_gnu) {
            try stderr.print("kernel32_lib_dir may not be empty for {}-{}\n", .{
                @tagName(Target.current.getOs()),
                @tagName(Target.current.getAbi()),
            });
            return error.ParseError;
        }

        return self;
    }

    pub fn render(self: LibCInstallation, out: *std.io.OutStream(fs.File.WriteError)) !void {
        @setEvalBranchQuota(4000);
        const include_dir = self.include_dir orelse "";
        const sys_include_dir = self.sys_include_dir orelse "";
        const crt_dir = self.crt_dir orelse "";
        const static_crt_dir = self.static_crt_dir orelse "";
        const msvc_lib_dir = self.msvc_lib_dir orelse "";
        const kernel32_lib_dir = self.kernel32_lib_dir orelse "";

        try out.print(
            \\# The directory that contains `stdlib.h`.
            \\# On POSIX-like systems, include directories be found with: `cc -E -Wp,-v -xc /dev/null`
            \\include_dir={}
            \\
            \\# The system-specific include directory. May be the same as `include_dir`.
            \\# On Windows it's the directory that includes `vcruntime.h`.
            \\# On POSIX it's the directory that includes `sys/errno.h`.
            \\sys_include_dir={}
            \\
            \\# The directory that contains `crt1.o` or `crt2.o`.
            \\# On POSIX, can be found with `cc -print-file-name=crt1.o`.
            \\# Not needed when targeting MacOS.
            \\crt_dir={}
            \\
            \\# The directory that contains `crtbegin.o`.
            \\# On POSIX, can be found with `cc -print-file-name=crtbegin.o`.
            \\# Only needed when targeting MinGW-w64 on Windows.
            \\static_crt_dir={}
            \\
            \\# The directory that contains `vcruntime.lib`.
            \\# Only needed when targeting MSVC on Windows.
            \\msvc_lib_dir={}
            \\
            \\# The directory that contains `kernel32.lib`.
            \\# Only needed when targeting MSVC on Windows.
            \\kernel32_lib_dir={}
            \\
        , .{
            include_dir,
            sys_include_dir,
            crt_dir,
            static_crt_dir,
            msvc_lib_dir,
            kernel32_lib_dir,
        });
    }

    pub const FindNativeOptions = struct {
        allocator: *Allocator,

        /// If enabled, will print human-friendly errors to stderr.
        verbose: bool = false,
    };

    /// Finds the default, native libc.
    pub fn findNative(args: FindNativeOptions) FindError!LibCInstallation {
        var self: LibCInstallation = .{};

        if (is_windows) {
            if (is_gnu) {
                var batch = Batch(FindError!void, 3, .auto_async).init();
                batch.add(&async self.findNativeIncludeDirPosix(args));
                batch.add(&async self.findNativeCrtDirPosix(args));
                batch.add(&async self.findNativeStaticCrtDirPosix(args));
                try batch.wait();
            } else {
                var sdk: *ZigWindowsSDK = undefined;
                switch (zig_find_windows_sdk(&sdk)) {
                    .None => {
                        defer zig_free_windows_sdk(sdk);

                        var batch = Batch(FindError!void, 5, .auto_async).init();
                        batch.add(&async self.findNativeMsvcIncludeDir(args, sdk));
                        batch.add(&async self.findNativeMsvcLibDir(args, sdk));
                        batch.add(&async self.findNativeKernel32LibDir(args, sdk));
                        batch.add(&async self.findNativeIncludeDirWindows(args, sdk));
                        batch.add(&async self.findNativeCrtDirWindows(args, sdk));
                        try batch.wait();
                    },
                    .OutOfMemory => return error.OutOfMemory,
                    .NotFound => return error.WindowsSdkNotFound,
                    .PathTooLong => return error.WindowsSdkNotFound,
                }
            }
        } else {
            try blk: {
                var batch = Batch(FindError!void, 2, .auto_async).init();
                errdefer batch.wait() catch {};
                batch.add(&async self.findNativeIncludeDirPosix(args));
                if (is_freebsd or is_netbsd) {
                    self.crt_dir = try std.mem.dupeZ(args.allocator, u8, "/usr/lib");
                } else if (is_linux or is_dragonfly) {
                    batch.add(&async self.findNativeCrtDirPosix(args));
                }
                break :blk batch.wait();
            };
        }
        return self;
    }

    /// Must be the same allocator passed to `parse` or `findNative`.
    pub fn deinit(self: *LibCInstallation, allocator: *Allocator) void {
        const fields = std.meta.fields(LibCInstallation);
        inline for (fields) |field| {
            if (@field(self, field.name)) |payload| {
                allocator.free(payload);
            }
        }
        self.* = undefined;
    }

    fn findNativeIncludeDirPosix(self: *LibCInstallation, args: FindNativeOptions) FindError!void {
        const allocator = args.allocator;
        const dev_null = if (is_windows) "nul" else "/dev/null";
        const cc_exe = std.os.getenvZ("CC") orelse default_cc_exe;
        const argv = [_][]const u8{
            cc_exe,
            "-E",
            "-Wp,-v",
            "-xc",
            dev_null,
        };
        const exec_res = std.ChildProcess.exec2(.{
            .allocator = allocator,
            .argv = &argv,
            .max_output_bytes = 1024 * 1024,
            // Some C compilers, such as Clang, are known to rely on argv[0] to find the path
            // to their own executable, without even bothering to resolve PATH. This results in the message:
            // error: unable to execute command: Executable "" doesn't exist!
            // So we use the expandArg0 variant of ChildProcess to give them a helping hand.
            .expand_arg0 = .expand,
        }) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            else => {
                printVerboseInvocation(&argv, null, args.verbose, null);
                return error.UnableToSpawnCCompiler;
            },
        };
        defer {
            allocator.free(exec_res.stdout);
            allocator.free(exec_res.stderr);
        }
        switch (exec_res.term) {
            .Exited => |code| if (code != 0) {
                printVerboseInvocation(&argv, null, args.verbose, exec_res.stderr);
                return error.CCompilerExitCode;
            },
            else => {
                printVerboseInvocation(&argv, null, args.verbose, exec_res.stderr);
                return error.CCompilerCrashed;
            },
        }

        var it = std.mem.tokenize(exec_res.stderr, "\n\r");
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

        const include_dir_example_file = "stdlib.h";
        const sys_include_dir_example_file = if (is_windows) "sys\\types.h" else "sys/errno.h";

        var path_i: usize = 0;
        while (path_i < search_paths.len) : (path_i += 1) {
            // search in reverse order
            const search_path_untrimmed = search_paths.at(search_paths.len - path_i - 1);
            const search_path = std.mem.trimLeft(u8, search_path_untrimmed, " ");
            var search_dir = fs.cwd().openDirList(search_path) catch |err| switch (err) {
                error.FileNotFound,
                error.NotDir,
                error.NoDevice,
                => continue,

                else => return error.FileSystem,
            };
            defer search_dir.close();

            if (self.include_dir == null) {
                if (search_dir.accessZ(include_dir_example_file, .{})) |_| {
                    self.include_dir = try std.mem.dupeZ(allocator, u8, search_path);
                } else |err| switch (err) {
                    error.FileNotFound => {},
                    else => return error.FileSystem,
                }
            }

            if (self.sys_include_dir == null) {
                if (search_dir.accessZ(sys_include_dir_example_file, .{})) |_| {
                    self.sys_include_dir = try std.mem.dupeZ(allocator, u8, search_path);
                } else |err| switch (err) {
                    error.FileNotFound => {},
                    else => return error.FileSystem,
                }
            }

            if (self.include_dir != null and self.sys_include_dir != null) {
                // Success.
                return;
            }
        }

        return error.LibCStdLibHeaderNotFound;
    }

    fn findNativeIncludeDirWindows(
        self: *LibCInstallation,
        args: FindNativeOptions,
        sdk: *ZigWindowsSDK,
    ) FindError!void {
        const allocator = args.allocator;

        var search_buf: [2]Search = undefined;
        const searches = fillSearch(&search_buf, sdk);

        var result_buf = try std.Buffer.initSize(allocator, 0);
        defer result_buf.deinit();

        for (searches) |search| {
            result_buf.shrink(0);
            const stream = &std.io.BufferOutStream.init(&result_buf).stream;
            try stream.print("{}\\Include\\{}\\ucrt", .{ search.path, search.version });

            var dir = fs.cwd().openDirList(result_buf.toSliceConst()) catch |err| switch (err) {
                error.FileNotFound,
                error.NotDir,
                error.NoDevice,
                => continue,

                else => return error.FileSystem,
            };
            defer dir.close();

            dir.accessZ("stdlib.h", .{}) catch |err| switch (err) {
                error.FileNotFound => continue,
                else => return error.FileSystem,
            };

            self.include_dir = result_buf.toOwnedSlice();
            return;
        }

        return error.LibCStdLibHeaderNotFound;
    }

    fn findNativeCrtDirWindows(
        self: *LibCInstallation,
        args: FindNativeOptions,
        sdk: *ZigWindowsSDK,
    ) FindError!void {
        const allocator = args.allocator;

        var search_buf: [2]Search = undefined;
        const searches = fillSearch(&search_buf, sdk);

        var result_buf = try std.Buffer.initSize(allocator, 0);
        defer result_buf.deinit();

        const arch_sub_dir = switch (builtin.arch) {
            .i386 => "x86",
            .x86_64 => "x64",
            .arm, .armeb => "arm",
            else => return error.UnsupportedArchitecture,
        };

        for (searches) |search| {
            result_buf.shrink(0);
            const stream = &std.io.BufferOutStream.init(&result_buf).stream;
            try stream.print("{}\\Lib\\{}\\ucrt\\{}", .{ search.path, search.version, arch_sub_dir });

            var dir = fs.cwd().openDirList(result_buf.toSliceConst()) catch |err| switch (err) {
                error.FileNotFound,
                error.NotDir,
                error.NoDevice,
                => continue,

                else => return error.FileSystem,
            };
            defer dir.close();

            dir.accessZ("ucrt.lib", .{}) catch |err| switch (err) {
                error.FileNotFound => continue,
                else => return error.FileSystem,
            };

            self.crt_dir = result_buf.toOwnedSlice();
            return;
        }
        return error.LibCRuntimeNotFound;
    }

    fn findNativeCrtDirPosix(self: *LibCInstallation, args: FindNativeOptions) FindError!void {
        self.crt_dir = try ccPrintFileName(.{
            .allocator = args.allocator,
            .search_basename = "crt1.o",
            .want_dirname = .only_dir,
            .verbose = args.verbose,
        });
    }

    fn findNativeStaticCrtDirPosix(self: *LibCInstallation, args: FindNativeOptions) FindError!void {
        self.static_crt_dir = try ccPrintFileName(.{
            .allocator = args.allocator,
            .search_basename = "crtbegin.o",
            .want_dirname = .only_dir,
            .verbose = args.verbose,
        });
    }

    fn findNativeKernel32LibDir(
        self: *LibCInstallation,
        args: FindNativeOptions,
        sdk: *ZigWindowsSDK,
    ) FindError!void {
        const allocator = args.allocator;

        var search_buf: [2]Search = undefined;
        const searches = fillSearch(&search_buf, sdk);

        var result_buf = try std.Buffer.initSize(allocator, 0);
        defer result_buf.deinit();

        const arch_sub_dir = switch (builtin.arch) {
            .i386 => "x86",
            .x86_64 => "x64",
            .arm, .armeb => "arm",
            else => return error.UnsupportedArchitecture,
        };

        for (searches) |search| {
            result_buf.shrink(0);
            const stream = &std.io.BufferOutStream.init(&result_buf).stream;
            try stream.print("{}\\Lib\\{}\\um\\{}", .{ search.path, search.version, arch_sub_dir });

            var dir = fs.cwd().openDirList(result_buf.toSliceConst()) catch |err| switch (err) {
                error.FileNotFound,
                error.NotDir,
                error.NoDevice,
                => continue,

                else => return error.FileSystem,
            };
            defer dir.close();

            dir.accessZ("kernel32.lib", .{}) catch |err| switch (err) {
                error.FileNotFound => continue,
                else => return error.FileSystem,
            };

            self.kernel32_lib_dir = result_buf.toOwnedSlice();
            return;
        }
        return error.LibCKernel32LibNotFound;
    }

    fn findNativeMsvcIncludeDir(
        self: *LibCInstallation,
        args: FindNativeOptions,
        sdk: *ZigWindowsSDK,
    ) FindError!void {
        const allocator = args.allocator;

        const msvc_lib_dir_ptr = sdk.msvc_lib_dir_ptr orelse return error.LibCStdLibHeaderNotFound;
        const msvc_lib_dir = msvc_lib_dir_ptr[0..sdk.msvc_lib_dir_len];
        const up1 = fs.path.dirname(msvc_lib_dir) orelse return error.LibCStdLibHeaderNotFound;
        const up2 = fs.path.dirname(up1) orelse return error.LibCStdLibHeaderNotFound;

        var result_buf = try std.Buffer.init(allocator, up2);
        defer result_buf.deinit();

        try result_buf.append("\\include");

        var dir = fs.cwd().openDirList(result_buf.toSliceConst()) catch |err| switch (err) {
            error.FileNotFound,
            error.NotDir,
            error.NoDevice,
            => return error.LibCStdLibHeaderNotFound,

            else => return error.FileSystem,
        };
        defer dir.close();

        dir.accessZ("vcruntime.h", .{}) catch |err| switch (err) {
            error.FileNotFound => return error.LibCStdLibHeaderNotFound,
            else => return error.FileSystem,
        };

        self.sys_include_dir = result_buf.toOwnedSlice();
    }

    fn findNativeMsvcLibDir(
        self: *LibCInstallation,
        args: FindNativeOptions,
        sdk: *ZigWindowsSDK,
    ) FindError!void {
        const allocator = args.allocator;
        const msvc_lib_dir_ptr = sdk.msvc_lib_dir_ptr orelse return error.LibCRuntimeNotFound;
        self.msvc_lib_dir = try std.mem.dupeZ(allocator, u8, msvc_lib_dir_ptr[0..sdk.msvc_lib_dir_len]);
    }
};

const default_cc_exe = if (is_windows) "cc.exe" else "cc";

pub const CCPrintFileNameOptions = struct {
    allocator: *Allocator,
    search_basename: []const u8,
    want_dirname: enum { full_path, only_dir },
    verbose: bool = false,
};

/// caller owns returned memory
fn ccPrintFileName(args: CCPrintFileNameOptions) ![:0]u8 {
    const allocator = args.allocator;

    const cc_exe = std.os.getenvZ("CC") orelse default_cc_exe;
    const arg1 = try std.fmt.allocPrint(allocator, "-print-file-name={}", .{args.search_basename});
    defer allocator.free(arg1);
    const argv = [_][]const u8{ cc_exe, arg1 };

    const exec_res = std.ChildProcess.exec2(.{
        .allocator = allocator,
        .argv = &argv,
        .max_output_bytes = 1024 * 1024,
        // Some C compilers, such as Clang, are known to rely on argv[0] to find the path
        // to their own executable, without even bothering to resolve PATH. This results in the message:
        // error: unable to execute command: Executable "" doesn't exist!
        // So we use the expandArg0 variant of ChildProcess to give them a helping hand.
        .expand_arg0 = .expand,
    }) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => return error.UnableToSpawnCCompiler,
    };
    defer {
        allocator.free(exec_res.stdout);
        allocator.free(exec_res.stderr);
    }
    switch (exec_res.term) {
        .Exited => |code| if (code != 0) {
            printVerboseInvocation(&argv, args.search_basename, args.verbose, exec_res.stderr);
            return error.CCompilerExitCode;
        },
        else => {
            printVerboseInvocation(&argv, args.search_basename, args.verbose, exec_res.stderr);
            return error.CCompilerCrashed;
        },
    }

    var it = std.mem.tokenize(exec_res.stdout, "\n\r");
    const line = it.next() orelse return error.LibCRuntimeNotFound;
    // When this command fails, it returns exit code 0 and duplicates the input file name.
    // So we detect failure by checking if the output matches exactly the input.
    if (std.mem.eql(u8, line, args.search_basename)) return error.LibCRuntimeNotFound;
    switch (args.want_dirname) {
        .full_path => return std.mem.dupeZ(allocator, u8, line),
        .only_dir => {
            const dirname = fs.path.dirname(line) orelse return error.LibCRuntimeNotFound;
            return std.mem.dupeZ(allocator, u8, dirname);
        },
    }
}

fn printVerboseInvocation(
    argv: []const []const u8,
    search_basename: ?[]const u8,
    verbose: bool,
    stderr: ?[]const u8,
) void {
    if (!verbose) return;

    if (search_basename) |s| {
        std.debug.warn("Zig attempted to find the file '{}' by executing this command:\n", .{s});
    } else {
        std.debug.warn("Zig attempted to find the path to native system libc headers by executing this command:\n", .{});
    }
    for (argv) |arg, i| {
        if (i != 0) std.debug.warn(" ", .{});
        std.debug.warn("{}", .{arg});
    }
    std.debug.warn("\n", .{});
    if (stderr) |s| {
        std.debug.warn("Output:\n==========\n{}\n==========\n", .{s});
    }
}

/// Caller owns returned memory.
pub fn detectNativeDynamicLinker(allocator: *Allocator) error{
    OutOfMemory,
    TargetHasNoDynamicLinker,
    UnknownDynamicLinkerPath,
}![:0]u8 {
    if (!comptime Target.current.hasDynamicLinker()) {
        return error.TargetHasNoDynamicLinker;
    }

    // The current target's ABI cannot be relied on for this. For example, we may build the zig
    // compiler for target riscv64-linux-musl and provide a tarball for users to download.
    // A user could then run that zig compiler on riscv64-linux-gnu. This use case is well-defined
    // and supported by Zig. But that means that we must detect the system ABI here rather than
    // relying on `std.Target.current`.

    const LdInfo = struct {
        ld_path: []u8,
        abi: Target.Abi,
    };
    var ld_info_list = std.ArrayList(LdInfo).init(allocator);
    defer {
        for (ld_info_list.toSlice()) |ld_info| allocator.free(ld_info.ld_path);
        ld_info_list.deinit();
    }

    const all_abis = comptime blk: {
        const fields = std.meta.fields(Target.Abi);
        var array: [fields.len]Target.Abi = undefined;
        inline for (fields) |field, i| {
            array[i] = @field(Target.Abi, field.name);
        }
        break :blk array;
    };
    for (all_abis) |abi| {
        // This may be a nonsensical parameter. We detect this with error.UnknownDynamicLinkerPath and
        // skip adding it to `ld_info_list`.
        const target: Target = .{
            .Cross = .{
                .cpu = Target.Cpu.baseline(Target.current.getArch()),
                .os = Target.current.getOs(),
                .abi = abi,
            },
        };
        const standard_ld_path = target.getStandardDynamicLinkerPath(allocator) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            error.UnknownDynamicLinkerPath, error.TargetHasNoDynamicLinker => continue,
        };
        errdefer allocator.free(standard_ld_path);
        try ld_info_list.append(.{
            .ld_path = standard_ld_path,
            .abi = abi,
        });
    }

    // Best case scenario: the zig compiler is dynamically linked, and we can iterate
    // over our own shared objects and find a dynamic linker.
    {
        const lib_paths = try std.process.getSelfExeSharedLibPaths(allocator);
        defer allocator.free(lib_paths);

        // This is O(N^M) but typical case here is N=2 and M=10.
        for (lib_paths) |lib_path| {
            for (ld_info_list.toSlice()) |ld_info| {
                const standard_ld_basename = fs.path.basename(ld_info.ld_path);
                if (std.mem.endsWith(u8, lib_path, standard_ld_basename)) {
                    return std.mem.dupeZ(allocator, u8, lib_path);
                }
            }
        }
    }

    // If Zig is statically linked, such as via distributed binary static builds, the above
    // trick won't work. What are we left with? Try to run the system C compiler and get
    // it to tell us the dynamic linker path.
    // TODO: instead of this, look at the shared libs of /usr/bin/env.
    for (ld_info_list.toSlice()) |ld_info| {
        const standard_ld_basename = fs.path.basename(ld_info.ld_path);

        const full_ld_path = ccPrintFileName(.{
            .allocator = allocator,
            .search_basename = standard_ld_basename,
            .want_dirname = .full_path,
        }) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            error.LibCRuntimeNotFound,
            error.CCompilerExitCode,
            error.CCompilerCrashed,
            error.UnableToSpawnCCompiler,
            => continue,
        };
        return full_ld_path;
    }

    // Finally, we fall back on the standard path.
    return Target.current.getStandardDynamicLinkerPath(allocator);
}

const Search = struct {
    path: []const u8,
    version: []const u8,
};

fn fillSearch(search_buf: *[2]Search, sdk: *ZigWindowsSDK) []Search {
    var search_end: usize = 0;
    if (sdk.path10_ptr) |path10_ptr| {
        if (sdk.version10_ptr) |version10_ptr| {
            search_buf[search_end] = Search{
                .path = path10_ptr[0..sdk.path10_len],
                .version = version10_ptr[0..sdk.version10_len],
            };
            search_end += 1;
        }
    }
    if (sdk.path81_ptr) |path81_ptr| {
        if (sdk.version81_ptr) |version81_ptr| {
            search_buf[search_end] = Search{
                .path = path81_ptr[0..sdk.path81_len],
                .version = version81_ptr[0..sdk.version81_len],
            };
            search_end += 1;
        }
    }
    return search_buf[0..search_end];
}
