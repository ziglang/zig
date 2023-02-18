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

    pub fn find(p: Preopens, name: []const u8) ?os.fd_t {
        for (p.names) |elem_name, i| {
            if (mem.eql(u8, elem_name, name)) {
                return @intCast(os.fd_t, i);
            }
        }
        return null;
    }

    pub fn findDir(p: Preopens, full_path: []const u8, flags: std.fs.Dir.OpenDirOptions) std.fs.Dir.OpenError!std.fs.Dir {
        if (p.names.len <= 2)
            return std.fs.Dir.OpenError.BadPathName; // there are no preopens

        var prefix: []const u8 = "";
        var fd: usize = 0;
        for (p.names) |preopen, i| {
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
        const d = std.fs.Dir{ .fd = @intCast(os.fd_t, fd) };
        const rel = full_path[prefix.len + 1 .. full_path.len];
        return d.openDirWasi(rel, flags);
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
        const fd = @intCast(wasi.fd_t, names.items.len);
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

test "preopens" {
    if (builtin.os.tag != .wasi or builtin.link_libc) return error.SkipZigTest;

    // lifted from `testing`
    const random_bytes_count = 12;
    const buf_size = 256;
    const path = "/tmp";
    const tmp_file_name = "file.txt";
    const nonsense = "nonsense";

    var random_bytes: [random_bytes_count]u8 = undefined;
    var buf: [buf_size]u8 = undefined;

    std.crypto.random.bytes(&random_bytes);
    const sub_path = std.fs.base64_encoder.encode(&buf, &random_bytes);

    // find all preopens
    const allocator = std.heap.page_allocator;
    var wasi_preopens = try std.fs.wasi.preopensAlloc(allocator);

    // look for the exact "/tmp" preopen match
    const fd = std.fs.wasi.Preopens.find(wasi_preopens, path) orelse unreachable;
    const base_dir = std.fs.Dir{ .fd = fd };

    var tmp_path = base_dir.makeOpenPath(sub_path, .{}) catch
        @panic("unable to make tmp dir for testing: /tmp/<rand-path>");

    defer tmp_path.close();
    defer tmp_path.deleteTree(sub_path) catch {};

    // create a file under /tmp/<rand>/file.txt with contents "nonsense"
    try tmp_path.writeFile(tmp_file_name, nonsense);

    // now look for the file as a single path
    var tmp_dir_path_buf: [buf_size]u8 = undefined;
    const tmp_dir_path = try std.fmt.bufPrint(&tmp_dir_path_buf, "{s}/{s}", .{ path, sub_path });

    // find "/tmp/<rand>" using `findDir()`
    const tmp_file_dir = try wasi_preopens.findDir(tmp_dir_path, .{});

    const text = try tmp_file_dir.readFile(tmp_file_name, &buf);

    // ensure the file contents match "nonsense"
    try testing.expect(std.mem.eql(u8, nonsense, text));
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
