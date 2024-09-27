//! See the render function implementation for documentation of the fields.

include_dir: ?[]const u8 = null,
sys_include_dir: ?[]const u8 = null,
crt_dir: ?[]const u8 = null,
msvc_lib_dir: ?[]const u8 = null,
kernel32_lib_dir: ?[]const u8 = null,
gcc_dir: ?[]const u8 = null,

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
    DarwinSdkNotFound,
    ZigIsTheCCompiler,
};

pub fn parse(
    allocator: Allocator,
    libc_file: []const u8,
    target: std.Target,
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

    const contents = try std.fs.cwd().readFileAlloc(allocator, libc_file, std.math.maxInt(usize));
    defer allocator.free(contents);

    var it = std.mem.tokenizeScalar(u8, contents, '\n');
    while (it.next()) |line| {
        if (line.len == 0 or line[0] == '#') continue;
        var line_it = std.mem.splitScalar(u8, line, '=');
        const name = line_it.first();
        const value = line_it.rest();
        inline for (fields, 0..) |field, i| {
            if (std.mem.eql(u8, name, field.name)) {
                found_keys[i].found = true;
                if (value.len == 0) {
                    @field(self, field.name) = null;
                } else {
                    found_keys[i].allocated = try allocator.dupeZ(u8, value);
                    @field(self, field.name) = found_keys[i].allocated;
                }
                break;
            }
        }
    }
    inline for (fields, 0..) |field, i| {
        if (!found_keys[i].found) {
            log.err("missing field: {s}", .{field.name});
            return error.ParseError;
        }
    }
    if (self.include_dir == null) {
        log.err("include_dir may not be empty", .{});
        return error.ParseError;
    }
    if (self.sys_include_dir == null) {
        log.err("sys_include_dir may not be empty", .{});
        return error.ParseError;
    }

    const os_tag = target.os.tag;
    if (self.crt_dir == null and !target.isDarwin()) {
        log.err("crt_dir may not be empty for {s}", .{@tagName(os_tag)});
        return error.ParseError;
    }

    if (self.msvc_lib_dir == null and os_tag == .windows and (target.abi == .msvc or target.abi == .itanium)) {
        log.err("msvc_lib_dir may not be empty for {s}-{s}", .{
            @tagName(os_tag),
            @tagName(target.abi),
        });
        return error.ParseError;
    }
    if (self.kernel32_lib_dir == null and os_tag == .windows and (target.abi == .msvc or target.abi == .itanium)) {
        log.err("kernel32_lib_dir may not be empty for {s}-{s}", .{
            @tagName(os_tag),
            @tagName(target.abi),
        });
        return error.ParseError;
    }

    if (self.gcc_dir == null and os_tag == .haiku) {
        log.err("gcc_dir may not be empty for {s}", .{@tagName(os_tag)});
        return error.ParseError;
    }

    return self;
}

pub fn render(self: LibCInstallation, out: anytype) !void {
    @setEvalBranchQuota(4000);
    const include_dir = self.include_dir orelse "";
    const sys_include_dir = self.sys_include_dir orelse "";
    const crt_dir = self.crt_dir orelse "";
    const msvc_lib_dir = self.msvc_lib_dir orelse "";
    const kernel32_lib_dir = self.kernel32_lib_dir orelse "";
    const gcc_dir = self.gcc_dir orelse "";

    try out.print(
        \\# The directory that contains `stdlib.h`.
        \\# On POSIX-like systems, include directories be found with: `cc -E -Wp,-v -xc /dev/null`
        \\include_dir={s}
        \\
        \\# The system-specific include directory. May be the same as `include_dir`.
        \\# On Windows it's the directory that includes `vcruntime.h`.
        \\# On POSIX it's the directory that includes `sys/errno.h`.
        \\sys_include_dir={s}
        \\
        \\# The directory that contains `crt1.o` or `crt2.o`.
        \\# On POSIX, can be found with `cc -print-file-name=crt1.o`.
        \\# Not needed when targeting MacOS.
        \\crt_dir={s}
        \\
        \\# The directory that contains `vcruntime.lib`.
        \\# Only needed when targeting MSVC on Windows.
        \\msvc_lib_dir={s}
        \\
        \\# The directory that contains `kernel32.lib`.
        \\# Only needed when targeting MSVC on Windows.
        \\kernel32_lib_dir={s}
        \\
        \\# The directory that contains `crtbeginS.o` and `crtendS.o`
        \\# Only needed when targeting Haiku.
        \\gcc_dir={s}
        \\
    , .{
        include_dir,
        sys_include_dir,
        crt_dir,
        msvc_lib_dir,
        kernel32_lib_dir,
        gcc_dir,
    });
}

pub const FindNativeOptions = struct {
    allocator: Allocator,
    target: std.Target,

    /// If enabled, will print human-friendly errors to stderr.
    verbose: bool = false,
};

/// Finds the default, native libc.
pub fn findNative(args: FindNativeOptions) FindError!LibCInstallation {
    var self: LibCInstallation = .{};

    if (is_darwin and args.target.isDarwin()) {
        if (!std.zig.system.darwin.isSdkInstalled(args.allocator))
            return error.DarwinSdkNotFound;
        const sdk = std.zig.system.darwin.getSdk(args.allocator, args.target) orelse
            return error.DarwinSdkNotFound;
        defer args.allocator.free(sdk);

        self.include_dir = try fs.path.join(args.allocator, &.{
            sdk, "usr/include",
        });
        self.sys_include_dir = try fs.path.join(args.allocator, &.{
            sdk, "usr/include",
        });
        return self;
    } else if (is_windows) {
        const sdk = std.zig.WindowsSdk.find(args.allocator) catch |err| switch (err) {
            error.NotFound => return error.WindowsSdkNotFound,
            error.PathTooLong => return error.WindowsSdkNotFound,
            error.OutOfMemory => return error.OutOfMemory,
        };
        defer sdk.free(args.allocator);

        try self.findNativeMsvcIncludeDir(args, sdk);
        try self.findNativeMsvcLibDir(args, sdk);
        try self.findNativeKernel32LibDir(args, sdk);
        try self.findNativeIncludeDirWindows(args, sdk);
        try self.findNativeCrtDirWindows(args, sdk);
    } else if (is_haiku) {
        try self.findNativeIncludeDirPosix(args);
        try self.findNativeGccDirHaiku(args);
        self.crt_dir = try args.allocator.dupeZ(u8, "/system/develop/lib");
    } else if (builtin.target.os.tag.isSolarish()) {
        // There is only one libc, and its headers/libraries are always in the same spot.
        self.include_dir = try args.allocator.dupeZ(u8, "/usr/include");
        self.sys_include_dir = try args.allocator.dupeZ(u8, "/usr/include");
        self.crt_dir = try args.allocator.dupeZ(u8, "/usr/lib/64");
    } else if (std.process.can_spawn) {
        try self.findNativeIncludeDirPosix(args);
        switch (builtin.target.os.tag) {
            .freebsd, .netbsd, .openbsd, .dragonfly => self.crt_dir = try args.allocator.dupeZ(u8, "/usr/lib"),
            .linux => try self.findNativeCrtDirPosix(args),
            else => {},
        }
    } else {
        return error.LibCRuntimeNotFound;
    }
    return self;
}

/// Must be the same allocator passed to `parse` or `findNative`.
pub fn deinit(self: *LibCInstallation, allocator: Allocator) void {
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

    // Detect infinite loops.
    var env_map = std.process.getEnvMap(allocator) catch |err| switch (err) {
        error.Unexpected => unreachable, // WASI-only
        else => |e| return e,
    };
    defer env_map.deinit();
    const skip_cc_env_var = if (env_map.get(inf_loop_env_key)) |phase| blk: {
        if (std.mem.eql(u8, phase, "1")) {
            try env_map.put(inf_loop_env_key, "2");
            break :blk true;
        } else {
            return error.ZigIsTheCCompiler;
        }
    } else blk: {
        try env_map.put(inf_loop_env_key, "1");
        break :blk false;
    };

    const dev_null = if (is_windows) "nul" else "/dev/null";

    var argv = std.ArrayList([]const u8).init(allocator);
    defer argv.deinit();

    try appendCcExe(&argv, skip_cc_env_var);
    try argv.appendSlice(&.{
        "-E",
        "-Wp,-v",
        "-xc",
        dev_null,
    });

    const run_res = std.process.Child.run(.{
        .allocator = allocator,
        .argv = argv.items,
        .max_output_bytes = 1024 * 1024,
        .env_map = &env_map,
        // Some C compilers, such as Clang, are known to rely on argv[0] to find the path
        // to their own executable, without even bothering to resolve PATH. This results in the message:
        // error: unable to execute command: Executable "" doesn't exist!
        // So we use the expandArg0 variant of ChildProcess to give them a helping hand.
        .expand_arg0 = .expand,
    }) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => {
            printVerboseInvocation(argv.items, null, args.verbose, null);
            return error.UnableToSpawnCCompiler;
        },
    };
    defer {
        allocator.free(run_res.stdout);
        allocator.free(run_res.stderr);
    }
    switch (run_res.term) {
        .Exited => |code| if (code != 0) {
            printVerboseInvocation(argv.items, null, args.verbose, run_res.stderr);
            return error.CCompilerExitCode;
        },
        else => {
            printVerboseInvocation(argv.items, null, args.verbose, run_res.stderr);
            return error.CCompilerCrashed;
        },
    }

    var it = std.mem.tokenizeAny(u8, run_res.stderr, "\n\r");
    var search_paths = std.ArrayList([]const u8).init(allocator);
    defer search_paths.deinit();
    while (it.next()) |line| {
        if (line.len != 0 and line[0] == ' ') {
            try search_paths.append(line);
        }
    }
    if (search_paths.items.len == 0) {
        return error.CCompilerCannotFindHeaders;
    }

    const include_dir_example_file = if (is_haiku) "posix/stdlib.h" else "stdlib.h";
    const sys_include_dir_example_file = if (is_windows)
        "sys\\types.h"
    else if (is_haiku)
        "errno.h"
    else
        "sys/errno.h";

    var path_i: usize = 0;
    while (path_i < search_paths.items.len) : (path_i += 1) {
        // search in reverse order
        const search_path_untrimmed = search_paths.items[search_paths.items.len - path_i - 1];
        const search_path = std.mem.trimLeft(u8, search_path_untrimmed, " ");
        var search_dir = fs.cwd().openDir(search_path, .{}) catch |err| switch (err) {
            error.FileNotFound,
            error.NotDir,
            error.NoDevice,
            => continue,

            else => return error.FileSystem,
        };
        defer search_dir.close();

        if (self.include_dir == null) {
            if (search_dir.accessZ(include_dir_example_file, .{})) |_| {
                self.include_dir = try allocator.dupeZ(u8, search_path);
            } else |err| switch (err) {
                error.FileNotFound => {},
                else => return error.FileSystem,
            }
        }

        if (self.sys_include_dir == null) {
            if (search_dir.accessZ(sys_include_dir_example_file, .{})) |_| {
                self.sys_include_dir = try allocator.dupeZ(u8, search_path);
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
    sdk: std.zig.WindowsSdk,
) FindError!void {
    const allocator = args.allocator;

    var install_buf: [2]std.zig.WindowsSdk.Installation = undefined;
    const installs = fillInstallations(&install_buf, sdk);

    var result_buf = std.ArrayList(u8).init(allocator);
    defer result_buf.deinit();

    for (installs) |install| {
        result_buf.shrinkAndFree(0);
        try result_buf.writer().print("{s}\\Include\\{s}\\ucrt", .{ install.path, install.version });

        var dir = fs.cwd().openDir(result_buf.items, .{}) catch |err| switch (err) {
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

        self.include_dir = try result_buf.toOwnedSlice();
        return;
    }

    return error.LibCStdLibHeaderNotFound;
}

fn findNativeCrtDirWindows(
    self: *LibCInstallation,
    args: FindNativeOptions,
    sdk: std.zig.WindowsSdk,
) FindError!void {
    const allocator = args.allocator;

    var install_buf: [2]std.zig.WindowsSdk.Installation = undefined;
    const installs = fillInstallations(&install_buf, sdk);

    var result_buf = std.ArrayList(u8).init(allocator);
    defer result_buf.deinit();

    const arch_sub_dir = switch (builtin.target.cpu.arch) {
        .x86 => "x86",
        .x86_64 => "x64",
        .arm, .armeb => "arm",
        .aarch64 => "arm64",
        else => return error.UnsupportedArchitecture,
    };

    for (installs) |install| {
        result_buf.shrinkAndFree(0);
        try result_buf.writer().print("{s}\\Lib\\{s}\\ucrt\\{s}", .{ install.path, install.version, arch_sub_dir });

        var dir = fs.cwd().openDir(result_buf.items, .{}) catch |err| switch (err) {
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

        self.crt_dir = try result_buf.toOwnedSlice();
        return;
    }
    return error.LibCRuntimeNotFound;
}

fn findNativeCrtDirPosix(self: *LibCInstallation, args: FindNativeOptions) FindError!void {
    self.crt_dir = try ccPrintFileName(.{
        .allocator = args.allocator,
        .search_basename = switch (args.target.os.tag) {
            .linux => if (args.target.isAndroid()) "crtbegin_dynamic.o" else "crt1.o",
            else => "crt1.o",
        },
        .want_dirname = .only_dir,
        .verbose = args.verbose,
    });
}

fn findNativeGccDirHaiku(self: *LibCInstallation, args: FindNativeOptions) FindError!void {
    self.gcc_dir = try ccPrintFileName(.{
        .allocator = args.allocator,
        .search_basename = "crtbeginS.o",
        .want_dirname = .only_dir,
        .verbose = args.verbose,
    });
}

fn findNativeKernel32LibDir(
    self: *LibCInstallation,
    args: FindNativeOptions,
    sdk: std.zig.WindowsSdk,
) FindError!void {
    const allocator = args.allocator;

    var install_buf: [2]std.zig.WindowsSdk.Installation = undefined;
    const installs = fillInstallations(&install_buf, sdk);

    var result_buf = std.ArrayList(u8).init(allocator);
    defer result_buf.deinit();

    const arch_sub_dir = switch (builtin.target.cpu.arch) {
        .x86 => "x86",
        .x86_64 => "x64",
        .arm, .armeb => "arm",
        .aarch64 => "arm64",
        else => return error.UnsupportedArchitecture,
    };

    for (installs) |install| {
        result_buf.shrinkAndFree(0);
        const stream = result_buf.writer();
        try stream.print("{s}\\Lib\\{s}\\um\\{s}", .{ install.path, install.version, arch_sub_dir });

        var dir = fs.cwd().openDir(result_buf.items, .{}) catch |err| switch (err) {
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

        self.kernel32_lib_dir = try result_buf.toOwnedSlice();
        return;
    }
    return error.LibCKernel32LibNotFound;
}

fn findNativeMsvcIncludeDir(
    self: *LibCInstallation,
    args: FindNativeOptions,
    sdk: std.zig.WindowsSdk,
) FindError!void {
    const allocator = args.allocator;

    const msvc_lib_dir = sdk.msvc_lib_dir orelse return error.LibCStdLibHeaderNotFound;
    const up1 = fs.path.dirname(msvc_lib_dir) orelse return error.LibCStdLibHeaderNotFound;
    const up2 = fs.path.dirname(up1) orelse return error.LibCStdLibHeaderNotFound;

    const dir_path = try fs.path.join(allocator, &[_][]const u8{ up2, "include" });
    errdefer allocator.free(dir_path);

    var dir = fs.cwd().openDir(dir_path, .{}) catch |err| switch (err) {
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

    self.sys_include_dir = dir_path;
}

fn findNativeMsvcLibDir(
    self: *LibCInstallation,
    args: FindNativeOptions,
    sdk: std.zig.WindowsSdk,
) FindError!void {
    const allocator = args.allocator;
    const msvc_lib_dir = sdk.msvc_lib_dir orelse return error.LibCRuntimeNotFound;
    self.msvc_lib_dir = try allocator.dupe(u8, msvc_lib_dir);
}

pub const CCPrintFileNameOptions = struct {
    allocator: Allocator,
    search_basename: []const u8,
    want_dirname: enum { full_path, only_dir },
    verbose: bool = false,
};

/// caller owns returned memory
fn ccPrintFileName(args: CCPrintFileNameOptions) ![:0]u8 {
    const allocator = args.allocator;

    // Detect infinite loops.
    var env_map = std.process.getEnvMap(allocator) catch |err| switch (err) {
        error.Unexpected => unreachable, // WASI-only
        else => |e| return e,
    };
    defer env_map.deinit();
    const skip_cc_env_var = if (env_map.get(inf_loop_env_key)) |phase| blk: {
        if (std.mem.eql(u8, phase, "1")) {
            try env_map.put(inf_loop_env_key, "2");
            break :blk true;
        } else {
            return error.ZigIsTheCCompiler;
        }
    } else blk: {
        try env_map.put(inf_loop_env_key, "1");
        break :blk false;
    };

    var argv = std.ArrayList([]const u8).init(allocator);
    defer argv.deinit();

    const arg1 = try std.fmt.allocPrint(allocator, "-print-file-name={s}", .{args.search_basename});
    defer allocator.free(arg1);

    try appendCcExe(&argv, skip_cc_env_var);
    try argv.append(arg1);

    const run_res = std.process.Child.run(.{
        .allocator = allocator,
        .argv = argv.items,
        .max_output_bytes = 1024 * 1024,
        .env_map = &env_map,
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
        allocator.free(run_res.stdout);
        allocator.free(run_res.stderr);
    }
    switch (run_res.term) {
        .Exited => |code| if (code != 0) {
            printVerboseInvocation(argv.items, args.search_basename, args.verbose, run_res.stderr);
            return error.CCompilerExitCode;
        },
        else => {
            printVerboseInvocation(argv.items, args.search_basename, args.verbose, run_res.stderr);
            return error.CCompilerCrashed;
        },
    }

    var it = std.mem.tokenizeAny(u8, run_res.stdout, "\n\r");
    const line = it.next() orelse return error.LibCRuntimeNotFound;
    // When this command fails, it returns exit code 0 and duplicates the input file name.
    // So we detect failure by checking if the output matches exactly the input.
    if (std.mem.eql(u8, line, args.search_basename)) return error.LibCRuntimeNotFound;
    switch (args.want_dirname) {
        .full_path => return allocator.dupeZ(u8, line),
        .only_dir => {
            const dirname = fs.path.dirname(line) orelse return error.LibCRuntimeNotFound;
            return allocator.dupeZ(u8, dirname);
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
        std.debug.print("Zig attempted to find the file '{s}' by executing this command:\n", .{s});
    } else {
        std.debug.print("Zig attempted to find the path to native system libc headers by executing this command:\n", .{});
    }
    for (argv, 0..) |arg, i| {
        if (i != 0) std.debug.print(" ", .{});
        std.debug.print("{s}", .{arg});
    }
    std.debug.print("\n", .{});
    if (stderr) |s| {
        std.debug.print("Output:\n==========\n{s}\n==========\n", .{s});
    }
}

fn fillInstallations(
    installs: *[2]std.zig.WindowsSdk.Installation,
    sdk: std.zig.WindowsSdk,
) []std.zig.WindowsSdk.Installation {
    var installs_len: usize = 0;
    if (sdk.windows10sdk) |windows10sdk| {
        installs[installs_len] = windows10sdk;
        installs_len += 1;
    }
    if (sdk.windows81sdk) |windows81sdk| {
        installs[installs_len] = windows81sdk;
        installs_len += 1;
    }
    return installs[0..installs_len];
}

const inf_loop_env_key = "ZIG_IS_DETECTING_LIBC_PATHS";

fn appendCcExe(args: *std.ArrayList([]const u8), skip_cc_env_var: bool) !void {
    const default_cc_exe = if (is_windows) "cc.exe" else "cc";
    try args.ensureUnusedCapacity(1);
    if (skip_cc_env_var) {
        args.appendAssumeCapacity(default_cc_exe);
        return;
    }
    const cc_env_var = std.zig.EnvVar.CC.getPosix() orelse {
        args.appendAssumeCapacity(default_cc_exe);
        return;
    };
    // Respect space-separated flags to the C compiler.
    var it = std.mem.tokenizeScalar(u8, cc_env_var, ' ');
    while (it.next()) |arg| {
        try args.append(arg);
    }
}

const LibCInstallation = @This();
const std = @import("std");
const builtin = @import("builtin");
const Target = std.Target;
const fs = std.fs;
const Allocator = std.mem.Allocator;

const is_darwin = builtin.target.isDarwin();
const is_windows = builtin.target.os.tag == .windows;
const is_haiku = builtin.target.os.tag == .haiku;

const log = std.log.scoped(.libc_installation);
