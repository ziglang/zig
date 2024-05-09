const std = @import("../../std.zig");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const process = std.process;
const mem = std.mem;

const NativePaths = @This();

arena: Allocator,
include_dirs: std.ArrayListUnmanaged([]const u8) = .{},
lib_dirs: std.ArrayListUnmanaged([]const u8) = .{},
framework_dirs: std.ArrayListUnmanaged([]const u8) = .{},
rpaths: std.ArrayListUnmanaged([]const u8) = .{},
warnings: std.ArrayListUnmanaged([]const u8) = .{},

pub fn detect(arena: Allocator, native_target: std.Target) !NativePaths {
    var self: NativePaths = .{ .arena = arena };
    var is_nix = false;
    if (process.getEnvVarOwned(arena, "NIX_CFLAGS_COMPILE")) |nix_cflags_compile| {
        is_nix = true;
        var it = mem.tokenizeScalar(u8, nix_cflags_compile, ' ');
        while (true) {
            const word = it.next() orelse break;
            if (mem.eql(u8, word, "-isystem")) {
                const include_path = it.next() orelse {
                    try self.addWarning("Expected argument after -isystem in NIX_CFLAGS_COMPILE");
                    break;
                };
                try self.addIncludeDir(include_path);
            } else if (mem.eql(u8, word, "-iframework")) {
                const framework_path = it.next() orelse {
                    try self.addWarning("Expected argument after -iframework in NIX_CFLAGS_COMPILE");
                    break;
                };
                try self.addFrameworkDir(framework_path);
            } else {
                if (mem.startsWith(u8, word, "-frandom-seed=")) {
                    continue;
                }
                try self.addWarningFmt("Unrecognized C flag from NIX_CFLAGS_COMPILE: {s}", .{word});
            }
        }
    } else |err| switch (err) {
        error.InvalidWtf8 => unreachable,
        error.EnvironmentVariableNotFound => {},
        error.OutOfMemory => |e| return e,
    }
    if (process.getEnvVarOwned(arena, "NIX_LDFLAGS")) |nix_ldflags| {
        is_nix = true;
        var it = mem.tokenizeScalar(u8, nix_ldflags, ' ');
        while (true) {
            const word = it.next() orelse break;
            if (mem.eql(u8, word, "-rpath")) {
                const rpath = it.next() orelse {
                    try self.addWarning("Expected argument after -rpath in NIX_LDFLAGS");
                    break;
                };
                try self.addRPath(rpath);
            } else if (mem.eql(u8, word, "-L") or mem.eql(u8, word, "-l")) {
                _ = it.next() orelse {
                    try self.addWarning("Expected argument after -L or -l in NIX_LDFLAGS");
                    break;
                };
            } else if (mem.startsWith(u8, word, "-L")) {
                const lib_path = word[2..];
                try self.addLibDir(lib_path);
                try self.addRPath(lib_path);
            } else if (mem.startsWith(u8, word, "-l")) {
                // Ignore this argument.
            } else {
                try self.addWarningFmt("Unrecognized C flag from NIX_LDFLAGS: {s}", .{word});
                break;
            }
        }
    } else |err| switch (err) {
        error.InvalidWtf8 => unreachable,
        error.EnvironmentVariableNotFound => {},
        error.OutOfMemory => |e| return e,
    }
    if (is_nix) {
        return self;
    }

    // TODO: consider also adding homebrew paths
    // TODO: consider also adding macports paths
    if (comptime builtin.target.isDarwin()) {
        if (std.zig.system.darwin.isSdkInstalled(arena)) sdk: {
            const sdk = std.zig.system.darwin.getSdk(arena, native_target) orelse break :sdk;
            try self.addLibDir(try std.fs.path.join(arena, &.{ sdk, "usr/lib" }));
            try self.addFrameworkDir(try std.fs.path.join(arena, &.{ sdk, "System/Library/Frameworks" }));
            try self.addIncludeDir(try std.fs.path.join(arena, &.{ sdk, "usr/include" }));
            return self;
        }
        return self;
    }

    if (builtin.os.tag.isSolarish()) {
        try self.addLibDir("/usr/lib/64");
        try self.addLibDir("/usr/local/lib/64");
        try self.addLibDir("/lib/64");

        try self.addIncludeDir("/usr/include");
        try self.addIncludeDir("/usr/local/include");

        return self;
    }

    if (builtin.os.tag == .haiku) {
        try self.addLibDir("/system/non-packaged/lib");
        try self.addLibDir("/system/develop/lib");
        try self.addLibDir("/system/lib");
        return self;
    }

    if (builtin.os.tag != .windows and builtin.os.tag != .wasi) {
        const triple = try native_target.linuxTriple(arena);

        const qual = native_target.ptrBitWidth();

        // TODO: $ ld --verbose | grep SEARCH_DIR
        // the output contains some paths that end with lib64, maybe include them too?
        // TODO: what is the best possible order of things?
        // TODO: some of these are suspect and should only be added on some systems. audit needed.

        try self.addIncludeDir("/usr/local/include");
        try self.addLibDirFmt("/usr/local/lib{d}", .{qual});
        try self.addLibDir("/usr/local/lib");

        try self.addIncludeDirFmt("/usr/include/{s}", .{triple});
        try self.addLibDirFmt("/usr/lib/{s}", .{triple});

        try self.addIncludeDir("/usr/include");
        try self.addLibDirFmt("/lib{d}", .{qual});
        try self.addLibDir("/lib");
        try self.addLibDirFmt("/usr/lib{d}", .{qual});
        try self.addLibDir("/usr/lib");

        // example: on a 64-bit debian-based linux distro, with zlib installed from apt:
        // zlib.h is in /usr/include (added above)
        // libz.so.1 is in /lib/x86_64-linux-gnu (added here)
        try self.addLibDirFmt("/lib/{s}", .{triple});

        // Distros like guix don't use FHS, so they rely on environment
        // variables to search for headers and libraries.
        // We use os.getenv here since this part won't be executed on
        // windows, to get rid of unnecessary error handling.
        if (std.posix.getenv("C_INCLUDE_PATH")) |c_include_path| {
            var it = mem.tokenizeScalar(u8, c_include_path, ':');
            while (it.next()) |dir| {
                try self.addIncludeDir(dir);
            }
        }

        if (std.posix.getenv("CPLUS_INCLUDE_PATH")) |cplus_include_path| {
            var it = mem.tokenizeScalar(u8, cplus_include_path, ':');
            while (it.next()) |dir| {
                try self.addIncludeDir(dir);
            }
        }

        if (std.posix.getenv("LIBRARY_PATH")) |library_path| {
            var it = mem.tokenizeScalar(u8, library_path, ':');
            while (it.next()) |dir| {
                try self.addLibDir(dir);
            }
        }
    }

    return self;
}

pub fn addIncludeDir(self: *NativePaths, s: []const u8) !void {
    return self.include_dirs.append(self.arena, s);
}

pub fn addIncludeDirFmt(self: *NativePaths, comptime fmt: []const u8, args: anytype) !void {
    const item = try std.fmt.allocPrint(self.arena, fmt, args);
    try self.include_dirs.append(self.arena, item);
}

pub fn addLibDir(self: *NativePaths, s: []const u8) !void {
    try self.lib_dirs.append(self.arena, s);
}

pub fn addLibDirFmt(self: *NativePaths, comptime fmt: []const u8, args: anytype) !void {
    const item = try std.fmt.allocPrint(self.arena, fmt, args);
    try self.lib_dirs.append(self.arena, item);
}

pub fn addWarning(self: *NativePaths, s: []const u8) !void {
    return self.warnings.append(self.arena, s);
}

pub fn addFrameworkDir(self: *NativePaths, s: []const u8) !void {
    return self.framework_dirs.append(self.arena, s);
}

pub fn addFrameworkDirFmt(self: *NativePaths, comptime fmt: []const u8, args: anytype) !void {
    const item = try std.fmt.allocPrint(self.arena, fmt, args);
    try self.framework_dirs.append(self.arena, item);
}

pub fn addWarningFmt(self: *NativePaths, comptime fmt: []const u8, args: anytype) !void {
    const item = try std.fmt.allocPrint(self.arena, fmt, args);
    try self.warnings.append(self.arena, item);
}

pub fn addRPath(self: *NativePaths, s: []const u8) !void {
    try self.rpaths.append(self.arena, s);
}
