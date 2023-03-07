const std = @import("std");
const builtin = @import("builtin");
const os = std.os;
const mem = std.mem;
const math = std.math;
const fs = std.fs;
const assert = std.debug.assert;
const Allocator = mem.Allocator;
const wasi = std.os.wasi;
const fd_t = wasi.fd_t;
const prestat_t = wasi.prestat_t;
const testing = std.testing;

pub const Preopens = struct {
    // Indexed by file descriptor number.
    names: []const []const u8,

    /// Looks for a given `name` (path) in the list of preopens.
    /// Returns the corresponding file descriptor if an exact match is found.
    /// Otherwise returns `null`.
    pub fn find(p: Preopens, name: []const u8) ?os.fd_t {
        for (p.names, 0..) |elem_name, i| {
            if (mem.eql(u8, elem_name, name)) {
                return @as(os.fd_t, @intCast(i));
            }
        }
        return null;
    }

    // A pair of <preopened dir, relative path to the given preopen>
    const PreopenMatch = struct {
        dir: std.fs.Dir,
        relativePath: []const u8,
    };

    /// Looks for a given `full_path` in the list of preopens.
    /// Returns a `std.fs.Dir` if the given `full_path` exists and can be opened.
    /// If there are no preopened paths that match, it returns a `std.fs.Dir.OpenError`.
    /// A preopened path matches if it is a prefix of the given `full_path`.
    /// If multiple preopens match, then the longest match is returned.
    /// e.g. if `/` and `/tmp` are preopened, and `full_path` is `/tmp/myfile.txt`,
    /// `myfile.txt` is looked under the `/tmp` preopen and not under `/`.
    pub fn findDir(p: Preopens, full_path: []const u8, flags: std.fs.Dir.OpenDirOptions) std.fs.Dir.OpenError!std.fs.Dir {
        const m = try findPreopenMatch(p, full_path);
        return m.dir.openDirWasi(m.relativePath, flags);
    }

    fn findPreopenMatch(p: Preopens, full_path: []const u8) std.fs.Dir.OpenError!PreopenMatch {
        if (p.names.len <= 2)
            return std.fs.Dir.OpenError.BadPathName; // there are no preopens

        var prefix: []const u8 = "";
        var fd: usize = 0;
        for (p.names, 0..) |preopen, i| {
            if (i > 2 and wasiPathPrefixMatches(preopen, full_path)) {
                if (preopen.len > prefix.len) {
                    prefix = preopen;
                    fd = i;
                }
            }
        }

        // still no match
        if (fd == 0) {
            return std.fs.Dir.OpenError.FileNotFound;
        }
        const d = std.fs.Dir{ .fd = @intCast(os.fd_t) };
        const rel = full_path[prefix.len + 1 .. full_path.len];
        return PreopenMatch{ .dir = d, .relativePath = rel };
    }

    /// Matches when the given `prefix` is a prefix of `path`
    fn wasiPathPrefixMatches(prefix: []const u8, path: []const u8) bool {
        if (path[0] != '/' and prefix.len == 0)
            return true;

        if (path.len < prefix.len)
            return false;

        if (prefix.len == 1) {
            return prefix[0] == path[0];
        }

        if (!std.mem.eql(u8, path[0..prefix.len], prefix)) {
            return false;
        }

        return path.len == prefix.len or
            path[prefix.len] == '/';
    }

    test "wasiPathPrefixMatches" {
        try testing.expect(wasiPathPrefixMatches("/", "/foo"));
        try testing.expect(wasiPathPrefixMatches("/testcases", "/testcases/test.txt"));
        try testing.expect(wasiPathPrefixMatches("", "foo"));
        try testing.expect(wasiPathPrefixMatches("foo", "foo"));
        try testing.expect(wasiPathPrefixMatches("foo", "foo/bar"));
        try testing.expect(!wasiPathPrefixMatches("bar", "foo/bar"));
        try testing.expect(!wasiPathPrefixMatches("bar", "foo"));
        try testing.expect(wasiPathPrefixMatches("foo", "foo/bar"));
        try testing.expect(!wasiPathPrefixMatches("fooo", "foo"));
        try testing.expect(!wasiPathPrefixMatches("foo", "fooo"));
        try testing.expect(!wasiPathPrefixMatches("foo/bar", "foo"));
        try testing.expect(!wasiPathPrefixMatches("bar/foo", "foo"));
        try testing.expect(wasiPathPrefixMatches("/foo", "/foo"));
        try testing.expect(wasiPathPrefixMatches("/foo", "/foo"));
        try testing.expect(wasiPathPrefixMatches("/foo", "/foo/"));
    }

    test "Preopens.findPreopenMatch" {
        if (builtin.os.tag != .wasi or builtin.link_libc) return error.SkipZigTest;

        const wasi_preopens: Preopens = .{
            .names = &.{
                "stdin",
                "stdout",
                "stderr",
                ".",
                "/tmp",
            },
        };

        const p1 = findPreopenMatch(wasi_preopens, "/blah") catch
            @panic("unable to find matching preopen");
        try testing.expect(p1.dir.fd == 3);
        try testing.expect(std.mem.eql(u8, p1.relativePath, "/blah"));

        const p2 = findPreopenMatch(wasi_preopens, "/tmp/blah") catch
            @panic("unable to find matching preopen");

        try testing.expect(p2.dir.fd == 4);
        try testing.expect(std.mem.eql(u8, p2.relativePath, "/blah"));
    }
};

pub fn preopensAlloc(gpa: Allocator) Allocator.Error!Preopens {
    var names: std.ArrayListUnmanaged([]const u8) = .{};
    defer names.deinit(gpa);

    try names.ensureUnusedCapacity(gpa, 3);

    names.appendAssumeCapacity("stdin"); // 0
    names.appendAssumeCapacity("stdout"); // 1
    names.appendAssumeCapacity("stderr"); // 2
    while (true) {
        const fd = @as(wasi.fd_t, @intCast(names.items.len));
        var prestat: prestat_t = undefined;
        switch (wasi.fd_prestat_get(fd, &prestat)) {
            .SUCCESS => {},
            .OPNOTSUPP, .BADF => return .{ .names = try names.toOwnedSlice(gpa) },
            else => @panic("fd_prestat_get: unexpected error"),
        }
        try names.ensureUnusedCapacity(gpa, 1);
        // This length does not include a null byte. Let's keep it this way to
        // gently encourage WASI implementations to behave properly.
        const name_len = prestat.u.dir.pr_name_len;
        const name = try gpa.alloc(u8, name_len);
        errdefer gpa.free(name);
        switch (wasi.fd_prestat_dir_name(fd, name.ptr, name.len)) {
            .SUCCESS => {},
            else => @panic("fd_prestat_dir_name: unexpected error"),
        }
        names.appendAssumeCapacity(name);
    }
}
