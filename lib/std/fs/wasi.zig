const std = @import("std");
const os = std.os;
const mem = std.mem;
const Allocator = mem.Allocator;

usingnamespace std.os.wasi;

/// Type of WASI preopen.
///
/// WASI currently offers only `Dir` as a valid preopen resource.
pub const PreopenType = enum {
    Dir,
};

/// WASI preopen struct. This struct consists of a WASI file descriptor
/// and type of WASI preopen. It can be obtained directly from the WASI
/// runtime using `PreopenList.populate()` method.
pub const Preopen = struct {
    /// WASI file descriptor.
    fd: fd_t,

    /// Type of the preopen.
    @"type": union(PreopenType) {
        /// Path to a preopened directory.
        Dir: []const u8,
    },

    const Self = @This();

    /// Construct new `Preopen` instance of type `PreopenType.Dir` from
    /// WASI file descriptor and WASI path.
    pub fn newDir(fd: fd_t, path: []const u8) Self {
        return Self{
            .fd = fd,
            .@"type" = .{ .Dir = path },
        };
    }
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

    pub const Error = os.UnexpectedError || Allocator.Error;

    /// Deinitialize with `deinit`.
    pub fn init(allocator: *Allocator) Self {
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
            switch (fd_prestat_get(fd, &buf)) {
                ESUCCESS => {},
                ENOTSUP => {
                    // not a preopen, so keep going
                    continue;
                },
                EBADF => {
                    // OK, no more fds available
                    break;
                },
                else => |err| return os.unexpectedErrno(err),
            }
            const preopen_len = buf.u.dir.pr_name_len;
            const path_buf = try self.buffer.allocator.alloc(u8, preopen_len);
            mem.set(u8, path_buf, 0);
            switch (fd_prestat_dir_name(fd, path_buf.ptr, preopen_len)) {
                ESUCCESS => {},
                else => |err| return os.unexpectedErrno(err),
            }
            const preopen = Preopen.newDir(fd, path_buf);
            try self.buffer.append(preopen);
            fd += 1;
        }
    }

    /// Find preopen by path. If the preopen exists, return it.
    /// Otherwise, return `null`.
    ///
    /// TODO make the function more generic by searching by `PreopenType` union. This will
    /// be needed in the future when WASI extends its capabilities to resources
    /// other than preopened directories.
    pub fn find(self: *const Self, path: []const u8) ?*const Preopen {
        for (self.buffer.items) |preopen| {
            switch (preopen.@"type") {
                PreopenType.Dir => |preopen_path| {
                    if (mem.eql(u8, path, preopen_path)) return &preopen;
                },
            }
        }
        return null;
    }

    /// Return the inner buffer as read-only slice.
    pub fn asSlice(self: *const Self) []const Preopen {
        return self.buffer.items;
    }

    /// The caller owns the returned memory. ArrayList becomes empty.
    pub fn toOwnedSlice(self: *Self) []Preopen {
        return self.buffer.toOwnedSlice();
    }
};

/// Convenience wrapper for `std.os.wasi.path_open` syscall.
pub fn openat(dir_fd: fd_t, file_path: []const u8, oflags: oflags_t, fdflags: fdflags_t, rights: rights_t) os.OpenError!fd_t {
    var fd: fd_t = undefined;
    switch (path_open(dir_fd, 0x0, file_path.ptr, file_path.len, oflags, rights, 0x0, fdflags, &fd)) {
        0 => {},
        // TODO map errors
        else => |err| return std.os.unexpectedErrno(err),
    }
    return fd;
}
