const std = @import("std");
const builtin = @import("builtin");
const os = std.os;
const mem = std.mem;
const math = std.math;
const Allocator = mem.Allocator;
const wasi = std.os.wasi;
const fd_t = wasi.fd_t;
const prestat_t = wasi.prestat_t;

/// Type-tag of WASI preopen.
///
/// WASI currently offers only `Dir` as a valid preopen resource.
pub const PreopenTypeTag = enum {
    Dir,
};

/// Type of WASI preopen.
///
/// WASI currently offers only `Dir` as a valid preopen resource.
pub const PreopenType = union(PreopenTypeTag) {
    /// Preopened directory type.
    Dir: []const u8,

    const Self = @This();

    pub fn eql(self: Self, other: PreopenType) bool {
        if (std.meta.activeTag(self) != std.meta.activeTag(other)) return false;

        switch (self) {
            PreopenTypeTag.Dir => |this_path| return mem.eql(u8, this_path, other.Dir),
        }
    }

    // Checks whether `other` refers to a subdirectory of `self` and, if so,
    // returns the relative path to `other` from `self`
    pub fn getRelativePath(self: Self, other: PreopenType) ?[]const u8 {
        if (std.meta.activeTag(self) != std.meta.activeTag(other)) return null;

        switch (self) {
            PreopenTypeTag.Dir => |this_path| {
                const other_path = other.Dir;
                if (mem.indexOfDiff(u8, this_path, other_path)) |index| {
                    if (index < this_path.len) return null;
                }
                return other_path[this_path.len..];
            },
        }
    }

    pub fn format(self: Self, comptime fmt: []const u8, options: std.fmt.FormatOptions, out_stream: anytype) !void {
        _ = fmt;
        _ = options;
        try out_stream.print("PreopenType{{ ", .{});
        switch (self) {
            PreopenType.Dir => |path| try out_stream.print(".Dir = '{}'", .{std.zig.fmtId(path)}),
        }
        return out_stream.print(" }}", .{});
    }
};

/// WASI preopen struct. This struct consists of a WASI file descriptor
/// and type of WASI preopen. It can be obtained directly from the WASI
/// runtime using `PreopenList.populate()` method.
pub const Preopen = struct {
    /// WASI file descriptor.
    fd: fd_t,

    /// Type of the preopen.
    @"type": PreopenType,

    /// Construct new `Preopen` instance.
    pub fn new(fd: fd_t, preopen_type: PreopenType) Preopen {
        return Preopen{
            .fd = fd,
            .@"type" = preopen_type,
        };
    }
};

/// WASI resource identifier struct. This is effectively a path within
/// a WASI Preopen.
pub const PreopenUri = struct {
    /// WASI Preopen containing the resource.
    base: Preopen,
    /// Path to resource within `base`.
    relative_path: []const u8,
};

/// Dynamically-sized array list of WASI preopens. This struct is a
/// convenience wrapper for issuing `std.os.wasi.fd_prestat_get` and
/// `std.os.wasi.fd_prestat_dir_name` syscalls to the WASI runtime, and
/// collecting the returned preopens.
///
/// This struct is intended to be used in any WASI program which intends
/// to use the capabilities as passed on by the user of the runtime.
pub const PreopenList = struct {
    const InnerList = std.ArrayList(Preopen);

    /// Internal dynamically-sized buffer for storing the gathered preopens.
    buffer: InnerList,

    const Self = @This();

    pub const Error = error{ OutOfMemory, Overflow } || os.UnexpectedError;

    /// Deinitialize with `deinit`.
    pub fn init(allocator: Allocator) Self {
        return Self{ .buffer = InnerList.init(allocator) };
    }

    /// Release all allocated memory.
    pub fn deinit(pm: Self) void {
        for (pm.buffer.items) |preopen| {
            switch (preopen.@"type") {
                PreopenType.Dir => |path| pm.buffer.allocator.free(path),
            }
        }
        pm.buffer.deinit();
    }

    /// Populate the list with the preopens by issuing `std.os.wasi.fd_prestat_get`
    /// and `std.os.wasi.fd_prestat_dir_name` syscalls to the runtime.
    ///
    /// If called more than once, it will clear its contents every time before
    /// issuing the syscalls.
    ///
    /// In the unlinkely event of overflowing the number of available file descriptors,
    /// returns `error.Overflow`. In this case, even though an error condition was reached
    /// the preopen list still contains all valid preopened file descriptors that are valid
    /// for use. Therefore, it is fine to call `find`, `asSlice`, or `toOwnedSlice`. Finally,
    /// `deinit` still must be called!
    pub fn populate(self: *Self) Error!void {
        // Clear contents if we're being called again
        for (self.toOwnedSlice()) |preopen| {
            switch (preopen.@"type") {
                PreopenType.Dir => |path| self.buffer.allocator.free(path),
            }
        }
        errdefer self.deinit();
        var fd: fd_t = 3; // start fd has to be beyond stdio fds

        while (true) {
            var buf: prestat_t = undefined;
            switch (wasi.fd_prestat_get(fd, &buf)) {
                .SUCCESS => {},
                .OPNOTSUPP => {
                    // not a preopen, so keep going
                    fd = try math.add(fd_t, fd, 1);
                    continue;
                },
                .BADF => {
                    // OK, no more fds available
                    break;
                },
                else => |err| return os.unexpectedErrno(err),
            }
            const preopen_len = buf.u.dir.pr_name_len;
            const path_buf = try self.buffer.allocator.alloc(u8, preopen_len);
            mem.set(u8, path_buf, 0);
            switch (wasi.fd_prestat_dir_name(fd, path_buf.ptr, preopen_len)) {
                .SUCCESS => {},
                else => |err| return os.unexpectedErrno(err),
            }

            const preopen = Preopen.new(fd, PreopenType{ .Dir = path_buf });
            try self.buffer.append(preopen);
            fd = try math.add(fd_t, fd, 1);
        }
    }

    /// Find a preopen which includes access to `preopen_type`.
    ///
    /// If the preopen exists, `relative_path` is updated to point to the relative
    /// portion of `preopen_type` and the matching Preopen is returned. If multiple
    /// preopens match the provided resource, the most recent one is used.
    pub fn findContaining(self: Self, preopen_type: PreopenType) ?PreopenUri {
        // Search in reverse, so that most recently added preopens take precedence
        var k: usize = self.buffer.items.len;
        while (k > 0) {
            k -= 1;

            const preopen = self.buffer.items[k];
            if (preopen.@"type".getRelativePath(preopen_type)) |rel_path_orig| {
                var rel_path = rel_path_orig;
                while (rel_path.len > 0 and rel_path[0] == '/') rel_path = rel_path[1..];

                return PreopenUri{
                    .base = preopen,
                    .relative_path = if (rel_path.len == 0) "." else rel_path,
                };
            }
        }
        return null;
    }

    /// Find preopen by type. If the preopen exists, return it.
    /// Otherwise, return `null`.
    pub fn find(self: Self, preopen_type: PreopenType) ?*const Preopen {
        for (self.buffer.items) |*preopen| {
            if (preopen.@"type".eql(preopen_type)) {
                return preopen;
            }
        }
        return null;
    }

    /// Return the inner buffer as read-only slice.
    pub fn asSlice(self: Self) []const Preopen {
        return self.buffer.items;
    }

    /// The caller owns the returned memory. ArrayList becomes empty.
    pub fn toOwnedSlice(self: *Self) []Preopen {
        return self.buffer.toOwnedSlice();
    }
};

test "extracting WASI preopens" {
    if (builtin.os.tag != .wasi or builtin.link_libc) return error.SkipZigTest;

    var preopens = PreopenList.init(std.testing.allocator);
    defer preopens.deinit();

    try preopens.populate();

    const preopen = preopens.find(PreopenType{ .Dir = "/cwd" }) orelse unreachable;
    try std.testing.expect(preopen.@"type".eql(PreopenType{ .Dir = "/cwd" }));
}
