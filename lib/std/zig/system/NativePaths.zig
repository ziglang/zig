const std = @import("../../std.zig");
const builtin = @import("builtin");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const process = std.process;
const mem = std.mem;

const NativePaths = @This();

include_dirs: ArrayList([:0]u8),
lib_dirs: ArrayList([:0]u8),
framework_dirs: ArrayList([:0]u8),
rpaths: ArrayList([:0]u8),
warnings: ArrayList([:0]u8),

pub fn isNix() bool {
    return process.hasEnvVarConstant("NIX_CFLAGS_COMPILE") and process.hasEnvVarConstant("NIX_LDFLAGS");
}

pub fn detect(allocator: Allocator, native_target: std.Target) !NativePaths {
    var self: NativePaths = .{
        .include_dirs = ArrayList([:0]u8).init(allocator),
        .lib_dirs = ArrayList([:0]u8).init(allocator),
        .framework_dirs = ArrayList([:0]u8).init(allocator),
        .rpaths = ArrayList([:0]u8).init(allocator),
        .warnings = ArrayList([:0]u8).init(allocator),
    };
    errdefer self.deinit();

    if (isNix()) {
        const nix_cflags_compile = try process.getEnvVarOwned(allocator, "NIX_CFLAGS_COMPILE");
        defer allocator.free(nix_cflags_compile);

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

        const nix_ldflags = try process.getEnvVarOwned(allocator, "NIX_LDFLAGS");
        defer allocator.free(nix_ldflags);

        it = mem.tokenizeScalar(u8, nix_ldflags, ' ');
        while (true) {
            const word = it.next() orelse break;
            if (mem.eql(u8, word, "-rpath")) {
                const rpath = it.next() orelse {
                    try self.addWarning("Expected argument after -rpath in NIX_LDFLAGS");
                    break;
                };
                try self.addRPath(rpath);
            } else if (word.len > 2 and word[0] == '-' and word[1] == 'L') {
                const lib_path = word[2..];
                try self.addLibDir(lib_path);
                try self.addRPath(lib_path);
            } else {
                try self.addWarningFmt("Unrecognized C flag from NIX_LDFLAGS: {s}", .{word});
                break;
            }
        }

        return self;
    }

    if (comptime builtin.target.isDarwin()) {
        try self.addIncludeDir("/usr/include");
        try self.addLibDir("/usr/lib");
        try self.addFrameworkDir("/System/Library/Frameworks");

        if (builtin.target.os.version_range.semver.min.major < 11) {
            try self.addIncludeDir("/usr/local/include");
            try self.addLibDir("/usr/local/lib");
            try self.addFrameworkDir("/Library/Frameworks");
        }

        return self;
    }

    if (builtin.os.tag == .solaris) {
        try self.addLibDir("/usr/lib/64");
        try self.addLibDir("/usr/local/lib/64");
        try self.addLibDir("/lib/64");

        try self.addIncludeDir("/usr/include");
        try self.addIncludeDir("/usr/local/include");

        return self;
    }

    if (builtin.os.tag != .windows) {
        const triple = try native_target.linuxTriple(allocator);
        defer allocator.free(triple);

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
        if (std.os.getenv("C_INCLUDE_PATH")) |c_include_path| {
            var it = mem.tokenizeScalar(u8, c_include_path, ':');
            while (it.next()) |dir| {
                try self.addIncludeDir(dir);
            }
        }

        if (std.os.getenv("CPLUS_INCLUDE_PATH")) |cplus_include_path| {
            var it = mem.tokenizeScalar(u8, cplus_include_path, ':');
            while (it.next()) |dir| {
                try self.addIncludeDir(dir);
            }
        }

        if (std.os.getenv("LIBRARY_PATH")) |library_path| {
            var it = mem.tokenizeScalar(u8, library_path, ':');
            while (it.next()) |dir| {
                try self.addLibDir(dir);
            }
        }
    }

    return self;
}

pub fn deinit(self: *NativePaths) void {
    deinitArray(&self.include_dirs);
    deinitArray(&self.lib_dirs);
    deinitArray(&self.framework_dirs);
    deinitArray(&self.rpaths);
    deinitArray(&self.warnings);
    self.* = undefined;
}

fn deinitArray(array: *ArrayList([:0]u8)) void {
    for (array.items) |item| {
        array.allocator.free(item);
    }
    array.deinit();
}

pub fn addIncludeDir(self: *NativePaths, s: []const u8) !void {
    return self.appendArray(&self.include_dirs, s);
}

pub fn addIncludeDirFmt(self: *NativePaths, comptime fmt: []const u8, args: anytype) !void {
    const item = try std.fmt.allocPrintZ(self.include_dirs.allocator, fmt, args);
    errdefer self.include_dirs.allocator.free(item);
    try self.include_dirs.append(item);
}

pub fn addLibDir(self: *NativePaths, s: []const u8) !void {
    return self.appendArray(&self.lib_dirs, s);
}

pub fn addLibDirFmt(self: *NativePaths, comptime fmt: []const u8, args: anytype) !void {
    const item = try std.fmt.allocPrintZ(self.lib_dirs.allocator, fmt, args);
    errdefer self.lib_dirs.allocator.free(item);
    try self.lib_dirs.append(item);
}

pub fn addWarning(self: *NativePaths, s: []const u8) !void {
    return self.appendArray(&self.warnings, s);
}

pub fn addFrameworkDir(self: *NativePaths, s: []const u8) !void {
    return self.appendArray(&self.framework_dirs, s);
}

pub fn addFrameworkDirFmt(self: *NativePaths, comptime fmt: []const u8, args: anytype) !void {
    const item = try std.fmt.allocPrintZ(self.framework_dirs.allocator, fmt, args);
    errdefer self.framework_dirs.allocator.free(item);
    try self.framework_dirs.append(item);
}

pub fn addWarningFmt(self: *NativePaths, comptime fmt: []const u8, args: anytype) !void {
    const item = try std.fmt.allocPrintZ(self.warnings.allocator, fmt, args);
    errdefer self.warnings.allocator.free(item);
    try self.warnings.append(item);
}

pub fn addRPath(self: *NativePaths, s: []const u8) !void {
    return self.appendArray(&self.rpaths, s);
}

fn appendArray(self: *NativePaths, array: *ArrayList([:0]u8), s: []const u8) !void {
    _ = self;
    const item = try array.allocator.dupeZ(u8, s);
    errdefer array.allocator.free(item);
    try array.append(item);
}
