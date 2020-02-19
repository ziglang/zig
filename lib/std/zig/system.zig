const std = @import("../std.zig");
const mem = std.mem;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const assert = std.debug.assert;
const process = std.process;

pub const NativePaths = struct {
    include_dirs: ArrayList([:0]u8),
    lib_dirs: ArrayList([:0]u8),
    rpaths: ArrayList([:0]u8),
    warnings: ArrayList([:0]u8),

    pub fn detect(allocator: *Allocator) !NativePaths {
        var self: NativePaths = .{
            .include_dirs = ArrayList([:0]u8).init(allocator),
            .lib_dirs = ArrayList([:0]u8).init(allocator),
            .rpaths = ArrayList([:0]u8).init(allocator),
            .warnings = ArrayList([:0]u8).init(allocator),
        };
        errdefer self.deinit();

        var is_nix = false;
        if (std.os.getenvZ("NIX_CFLAGS_COMPILE")) |nix_cflags_compile| {
            is_nix = true;
            var it = mem.tokenize(nix_cflags_compile, " ");
            while (true) {
                const word = it.next() orelse break;
                if (mem.eql(u8, word, "-isystem")) {
                    const include_path = it.next() orelse {
                        try self.addWarning("Expected argument after -isystem in NIX_CFLAGS_COMPILE");
                        break;
                    };
                    try self.addIncludeDir(include_path);
                } else {
                    try self.addWarningFmt("Unrecognized C flag from NIX_CFLAGS_COMPILE: {}", .{word});
                    break;
                }
            }
        }
        if (std.os.getenvZ("NIX_LDFLAGS")) |nix_ldflags| {
            is_nix = true;
            var it = mem.tokenize(nix_ldflags, " ");
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
                } else {
                    try self.addWarningFmt("Unrecognized C flag from NIX_LDFLAGS: {}", .{word});
                    break;
                }
            }
        }
        if (is_nix) {
            return self;
        }

        switch (std.builtin.os) {
            .windows => {},
            else => {
                const triple = try std.Target.current.linuxTriple(allocator);

                // TODO: $ ld --verbose | grep SEARCH_DIR
                // the output contains some paths that end with lib64, maybe include them too?
                // TODO: what is the best possible order of things?
                // TODO: some of these are suspect and should only be added on some systems. audit needed.

                try self.addIncludeDir("/usr/local/include");
                try self.addLibDir("/usr/local/lib");
                try self.addLibDir("/usr/local/lib64");

                try self.addIncludeDirFmt("/usr/include/{}", .{triple});
                try self.addLibDirFmt("/usr/lib/{}", .{triple});

                try self.addIncludeDir("/usr/include");
                try self.addLibDir("/lib");
                try self.addLibDir("/lib64");
                try self.addLibDir("/usr/lib");
                try self.addLibDir("/usr/lib64");

                // example: on a 64-bit debian-based linux distro, with zlib installed from apt:
                // zlib.h is in /usr/include (added above)
                // libz.so.1 is in /lib/x86_64-linux-gnu (added here)
                try self.addLibDirFmt("/lib/{}", .{triple});
            },
        }

        return self;
    }

    pub fn deinit(self: *NativePaths) void {
        deinitArray(&self.include_dirs);
        deinitArray(&self.lib_dirs);
        deinitArray(&self.rpaths);
        deinitArray(&self.warnings);
        self.* = undefined;
    }

    fn deinitArray(array: *ArrayList([:0]u8)) void {
        for (array.toSlice()) |item| {
            array.allocator.free(item);
        }
        array.deinit();
    }

    pub fn addIncludeDir(self: *NativePaths, s: []const u8) !void {
        return self.appendArray(&self.include_dirs, s);
    }

    pub fn addIncludeDirFmt(self: *NativePaths, comptime fmt: []const u8, args: var) !void {
        const item = try std.fmt.allocPrint0(self.include_dirs.allocator, fmt, args);
        errdefer self.include_dirs.allocator.free(item);
        try self.include_dirs.append(item);
    }

    pub fn addLibDir(self: *NativePaths, s: []const u8) !void {
        return self.appendArray(&self.lib_dirs, s);
    }

    pub fn addLibDirFmt(self: *NativePaths, comptime fmt: []const u8, args: var) !void {
        const item = try std.fmt.allocPrint0(self.lib_dirs.allocator, fmt, args);
        errdefer self.lib_dirs.allocator.free(item);
        try self.lib_dirs.append(item);
    }

    pub fn addWarning(self: *NativePaths, s: []const u8) !void {
        return self.appendArray(&self.warnings, s);
    }

    pub fn addWarningFmt(self: *NativePaths, comptime fmt: []const u8, args: var) !void {
        const item = try std.fmt.allocPrint0(self.warnings.allocator, fmt, args);
        errdefer self.warnings.allocator.free(item);
        try self.warnings.append(item);
    }

    pub fn addRPath(self: *NativePaths, s: []const u8) !void {
        return self.appendArray(&self.rpaths, s);
    }

    fn appendArray(self: *NativePaths, array: *ArrayList([:0]u8), s: []const u8) !void {
        const item = try std.mem.dupeZ(array.allocator, u8, s);
        errdefer array.allocator.free(item);
        try array.append(item);
    }
};
