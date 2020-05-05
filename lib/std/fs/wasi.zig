const std = @import("std");
const os = std.os;
const mem = std.mem;
const Allocator = mem.Allocator;

usingnamespace std.os.wasi;

pub const PreopenType = enum {
    Dir,
};

pub const Preopen = struct {
    fd: fd_t,
    @"type": union(PreopenType) {
        Dir: []const u8,
    },

    const Self = @This();

    pub fn newDir(fd: fd_t, path: []const u8) Self {
        return Self{
            .fd = fd,
            .@"type" = .{ .Dir = path },
        };
    }
};

pub const PreopenList = struct {
    const InnerList = std.ArrayList(Preopen);

    buffer: InnerList,

    const Self = @This();
    pub const Error = os.UnexpectedError || Allocator.Error;

    pub fn init(allocator: *Allocator) Self {
        return Self{ .buffer = InnerList.init(allocator) };
    }

    pub fn deinit(pm: Self) void {
        for (pm.buffer.items) |preopen| {
            switch (preopen.@"type") {
                PreopenType.Dir => |path| pm.buffer.allocator.free(path),
            }
        }
        pm.buffer.deinit();
    }

    pub fn populate(self: *Self) Error!void {
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

    pub fn asSlice(self: *const Self) []const Preopen {
        return self.buffer.items;
    }
};

pub fn openat(dir_fd: fd_t, file_path: []const u8, oflags: oflags_t, fdflags: fdflags_t, rights: rights_t) std.os.OpenError!fd_t {
    var fd: fd_t = undefined;
    switch (path_open(dir_fd, 0x0, file_path.ptr, file_path.len, oflags, rights, 0x0, fdflags, &fd)) {
        0 => {},
        // TODO map errors
        else => |err| return std.os.unexpectedErrno(err),
    }
    return fd;
}
