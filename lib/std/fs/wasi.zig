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

pub const Preopens = struct {
    // Indexed by file descriptor number.
    names: []const []const u8,

    pub fn find(p: Preopens, name: []const u8) ?os.fd_t {
        for (p.names, 0..) |elem_name, i| {
            if (mem.eql(u8, elem_name, name)) {
                return @as(os.fd_t, @intCast(i));
            }
        }
        return null;
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
