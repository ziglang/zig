const builtin = @import("builtin");
const std = @import("../../std.zig");
const uefi = @import("../uefi.zig");

pub const ino_t = u32;
pub const dev_t = u32;
pub const mode_t = u64;
pub const off_t = u64;
pub const blksize_t = u64;
pub const blkcnt_t = u64;
pub const ucontext_t = void;

pub const fd_t = union(enum) {
    file: *uefi.protocol.File,
    simple_output: *uefi.protocol.SimpleTextOutput,
    simple_input: *uefi.protocol.SimpleTextInput,
    none: void, // used to refer to a file descriptor that is not open and cannot do anything
    cwd: void, // used to refer to the current working directory
};

pub const PATH_MAX_WIDE = 4096;
pub const PATH_MAX = PATH_MAX_WIDE * 3 + 1;
pub const NAME_MAX = 255;

pub const IOV_MAX = 1024;

pub const F_OK = 0;
pub const R_OK = 1;
pub const W_OK = 2;

pub const O = packed struct {
    ACCMODE: std.posix.ACCMODE = .RDONLY,
    NONBLOCK: bool = false,
    CLOEXEC: bool = false,
    CREAT: bool = false,
    TRUNC: bool = false,
    EXCL: bool = false,
    NOFOLLOW: bool = false,
    DIRECTORY: bool = false,
};

pub const AT = struct {
    pub const FDCWD: fd_t = .cwd;
    pub const REMOVEDIR: u32 = 0x200;
    pub const SYMLINK_NOFOLLOW: u32 = 0x100;
};

pub const CLOCK = struct {
    pub const REALTIME = 0;
};

pub const LOCK = struct {
    pub const SH = 1;
    pub const EX = 2;
    pub const NB = 4;
    pub const UN = 8;
};

pub const S = struct {
    pub const IFMT = 0o170000;

    pub const IFDIR = 0o040000;
    pub const IFCHR = 0o020000;
    pub const IFBLK = 0o060000;
    pub const IFREG = 0o100000;
    pub const IFIFO = 0o010000;
    pub const IFLNK = 0o120000;
    pub const IFSOCK = 0o140000;
};

pub const timespec = struct {
    tv_sec: i64,
    tv_nsec: i64,
};

pub const utsname = struct {
    sysname: [8:0]u8,
    nodename: [8:0]u8,
    release: [32:0]u8,
    version: [5:0]u8,
    machine: [16:0]u8,
};

pub const Stat = struct {
    ino: ino_t,
    mode: mode_t,
    size: off_t,
    atim: timespec,
    mtim: timespec,
    ctim: timespec,

    pub fn atime(self: @This()) timespec {
        return self.atim;
    }

    pub fn mtime(self: @This()) timespec {
        return self.mtim;
    }

    pub fn ctime(self: @This()) timespec {
        return self.ctim;
    }
};

fn unexpectedError(err: anyerror) error{Unexpected} {
    std.log.err("unexpected error: {}\n", .{err});
    return error.Unexpected;
}

pub fn chdir(dir_path: []const u8) std.posix.ChangeCurDirError!void {
    var path_buffer: [PATH_MAX_WIDE]u16 = undefined;
    const len = try std.unicode.wtf8ToWtf16Le(&path_buffer, dir_path);
    path_buffer[len] = 0;

    const fd = openat(.cwd, path_buffer[0..len :0], .{}) catch |err| switch (err) {
        error.NotFound => return error.FileNotFound,
        error.NoMedia => return error.InputOutput,
        error.MediaChanged => return error.InputOutput,
        error.DeviceError => return error.InputOutput,
        error.VolumeCorrupted => return error.InputOutput,
        error.AccessDenied => return error.AccessDenied,
        error.OutOfResources => return error.SystemResources,
        else => |e| return unexpectedError(e),
    };
    defer fd.close();

    try fchdir(fd);
}

pub fn clock_getres(clk_id: i32, res: *uefi.timespec) std.posix.ClockGetTimeError!void {
    if (clk_id != CLOCK.REALTIME)
        return error.UnsupportedClock;

    const capabilities = uefi.system_table.runtime_services.getTimeCapabilities() catch return error.UnsupportedClock;

    if (capabilities.resolution == 0)
        return error.UnsupportedClock;

    res.tv_sec = 1 / capabilities.resolution;
    res.tv_nsec = (std.time.ns_per_s / capabilities.resolution) % std.time.ns_per_s;
}

pub fn clock_gettime(clk_id: i32, tp: *uefi.timespec) std.posix.ClockGetTimeError!void {
    if (clk_id != CLOCK.REALTIME)
        return error.UnsupportedClock;

    const time = uefi.system_table.runtime_services.getTime() catch return error.UnsupportedClock;

    const unix_ns = time.toUnixEpochNanoseconds();
    tp.tv_sec = @intCast(unix_ns / std.time.ns_per_s);
    tp.tv_nsec = @intCast(unix_ns % std.time.ns_per_s);
}

pub fn close(fd: fd_t) void {
    switch (fd) {
        .file => |p| p.close() catch {},
        .simple_output => |p| p.reset(true) catch {},
        .simple_input => |p| p.reset(true) catch {},
        .none => {},
        .cwd => {},
    }
}

pub fn exit(status: u8) noreturn {
    if (uefi.system_table.boot_services) |bs| {
        bs.exit(uefi.handle, @enumFromInt(status), null) catch {};
    }

    uefi.system_table.runtime_services.resetSystem(.cold, @enumFromInt(status), null);
}

pub fn faccessat(dirfd: fd_t, path: []const u8, mode: u32, flags: u32) std.posix.AccessError!void {
    switch (dirfd) {
        .file => |p| {
            var path_buffer: [PATH_MAX_WIDE]u16 = undefined;
            const len = try std.unicode.wtf8ToWtf16Le(&path_buffer, path);
            path_buffer[len] = 0;

            const fd = p.open(path_buffer[0..len :0], .{
                .write = mode & W_OK != 0,
            }, .{}) catch |err| switch (err) {
                error.NotFound => return error.FileNotFound,
                error.NoMedia => return error.InputOutput,
                error.MediaChanged => return error.InputOutput,
                error.DeviceError => return error.InputOutput,
                error.VolumeCorrupted => return error.InputOutput,
                error.AccessDenied => return error.PermissionDenied,
                error.OutOfResources => return error.SystemResources,
                else => |e| return unexpectedError(e),
            };
            defer fd.close();
        },
        .cwd => return faccessat(uefi.working_directory, path, mode, flags),
        else => return error.FileNotFound,
    }
}

pub fn fchdir(fd: fd_t) std.posix.FchdirError!void {
    switch (fd) {
        .file => {
            close(uefi.working_directory);
            uefi.working_directory = fd;
        },
        .simple_output => return error.NotDir,
        .simple_input => return error.NotDir,
        .none => return error.NotDir,
        .cwd => {},
    }
}

pub fn fstat(fd: fd_t) std.posix.FStatError!Stat {
    switch (fd) {
        .file => |p| {
            var pool_allocator = std.os.uefi.PoolAllocator{};

            const buffer_size = p.getInfoSize(std.os.uefi.bits.FileInfo) catch return error.Unexpected;
            const buffer = pool_allocator.allocator().alignedAlloc(
                u8,
                @alignOf(std.os.uefi.bits.FileInfo),
                buffer_size,
            ) catch return error.SystemResources;
            defer pool_allocator.allocator().free(buffer);

            const info = p.getInfo(std.os.uefi.bits.FileInfo, buffer) catch return error.Unexpected;

            return .{
                .ino = 0,
                .mode = if (info.attribute.directory) S.IFDIR else S.IFREG,
                .size = info.file_size,
                .atim = timespec{ .tv_sec = @intCast(info.last_access_time.toUnixEpochSeconds()), .tv_nsec = info.last_access_time.nanosecond },
                .mtim = timespec{ .tv_sec = @intCast(info.modification_time.toUnixEpochSeconds()), .tv_nsec = info.modification_time.nanosecond },
                .ctim = timespec{ .tv_sec = @intCast(info.create_time.toUnixEpochSeconds()), .tv_nsec = info.create_time.nanosecond },
            };
        },
        .simple_input, .simple_output => return Stat{
            .ino = 0,
            .mode = S.IFCHR,
            .size = 0,
            .atim = timespec{ .tv_sec = 0, .tv_nsec = 0 },
            .mtim = timespec{ .tv_sec = 0, .tv_nsec = 0 },
            .ctim = timespec{ .tv_sec = 0, .tv_nsec = 0 },
        },
        .none => return error.AccessDenied,
        .cwd => return fstat(uefi.working_directory),
    }
}

pub fn fstatat(dirfd: fd_t, pathname: []const u8, flags: u32) std.posix.FStatAtError!Stat {
    _ = flags;

    const fd = openat(dirfd, pathname, .{}, 0) catch return error.FileNotFound;
    defer close(fd);

    return try fstat(fd);
}

pub fn fsync(fd: fd_t) std.posix.SyncError!void {
    switch (fd) {
        .file => |p| p.flush() catch return error.InputOutput,
        else => return error.NoSpaceLeft,
    }
}

pub fn ftruncate(fd: fd_t, length: u64) std.posix.TruncateError!void {
    if (fd != .file)
        return error.AccessDenied;

    const p = fd.file;

    var pool_allocator = std.os.uefi.PoolAllocator{};

    const buffer_size = p.getInfoSize(std.os.uefi.bits.FileInfo) catch return error.Unexpected;
    const buffer = pool_allocator.allocator().alignedAlloc(
        u8,
        @alignOf(std.os.uefi.bits.FileInfo),
        buffer_size,
    ) catch return error.Unexpected;
    defer pool_allocator.allocator().free(buffer);

    var info = p.getInfo(std.os.uefi.bits.FileInfo, buffer) catch return error.Unexpected;

    info.file_size = length;

    p.setInfo(std.os.uefi.bits.FileInfo, buffer[0..buffer_size]) catch return error.AccessDenied;
}

pub fn futimens(fd: fd_t, times: *const [2]timespec) std.posix.FutimensError!void {
    switch (fd) {
        .file => |p| {
            var pool_allocator = std.os.uefi.PoolAllocator{};

            const buffer_size = p.getInfoSize(std.os.uefi.bits.FileInfo) catch return error.Unexpected;
            const buffer = pool_allocator.allocator().alignedAlloc(
                u8,
                @alignOf(std.os.uefi.bits.FileInfo),
                buffer_size,
            ) catch return error.Unexpected;
            defer pool_allocator.allocator().free(buffer);

            var info = p.getInfo(std.os.uefi.bits.FileInfo, buffer) catch return error.Unexpected;

            info.last_access_time = uefi.bits.Time.fromEpochSeconds(@as(u64, @intCast(times[0].tv_sec)) -| uefi.bits.Time.unix_epoch_seconds);
            info.last_access_time.nanosecond = @intCast(times[0].tv_nsec);

            info.modification_time = uefi.bits.Time.fromEpochSeconds(@as(u64, @intCast(times[1].tv_sec)) -| uefi.bits.Time.unix_epoch_seconds);
            info.modification_time.nanosecond = @intCast(times[1].tv_nsec);

            p.setInfo(std.os.uefi.bits.FileInfo, buffer[0..buffer_size]) catch return error.AccessDenied;
        },
        .cwd => return futimens(uefi.working_directory, times),
        else => return error.AccessDenied,
    }
}

pub fn getcwd(out_buffer: []u8) std.posix.GetCwdError![]u8 {
    const fd = uefi.working_directory;
    if (fd == .none)
        return error.CurrentWorkingDirectoryUnlinked;

    var buffer: [PATH_MAX]u8 = undefined;
    const path = std.os.getFdPath(fd, &buffer) catch return error.NameTooLong;
    if (path.len > out_buffer.len)
        return error.NameTooLong;

    @memcpy(out_buffer[0..path.len], path);
    return out_buffer[0..path.len];
}

pub fn getrandom(buf: []u8) std.posix.GetRandomError!void {
    if (uefi.system_table.boot_services) |boot_services| {
        const rng = (boot_services.locateProtocol(uefi.protocol.Rng, .{}) catch return error.NoDevice) orelse return error.NoDevice;

        while (true) {
            rng.getRNG(null, buf.len, buf.ptr) catch |err| switch (err) {
                error.NotReady => continue,
                else => return error.FileNotFound,
            };

            break;
        }
    } else {
        return error.NoDevice;
    }
}

pub fn isatty(fd: fd_t) bool {
    switch (fd) {
        .simple_input, .simple_output => return true,
        else => return false,
    }
}

pub fn lseek_SET(fd: fd_t, pos: u64) std.posix.SeekError!void {
    switch (fd) {
        .file => |p| {
            return p.setPosition(pos) catch return error.Unseekable;
        },
        else => return error.Unseekable, // cannot read
    }
}

pub fn lseek_CUR(fd: fd_t, offset: i64) std.posix.SeekError!void {
    switch (fd) {
        .file => |p| {
            const end = p.getEndPosition() catch return error.Unseekable;
            const pos = p.getPosition() catch return error.Unseekable;
            const new_pos = @as(i64, @intCast(pos)) + offset;

            var abs_pos: u64 = 0;
            if (new_pos > end)
                abs_pos = uefi.protocol.File.position_end_of_file
            else if (new_pos > 0)
                abs_pos = @intCast(new_pos);

            return p.setPosition(abs_pos) catch return error.Unseekable;
        },
        else => return error.Unseekable, // cannot read
    }
}

pub fn lseek_END(fd: fd_t, offset: i64) std.posix.SeekError!void {
    switch (fd) {
        .file => |p| {
            const end = p.getEndPosition() catch return error.Unseekable;
            const new_pos = @as(i64, @intCast(end)) + offset;

            var abs_pos: u64 = 0;
            if (new_pos > end)
                abs_pos = uefi.protocol.File.position_end_of_file
            else if (new_pos > 0)
                abs_pos = @intCast(new_pos);

            return p.setPosition(abs_pos) catch return error.Unseekable;
        },
        else => return error.Unseekable, // cannot read
    }
}

pub fn lseek_CUR_get(fd: fd_t) std.posix.SeekError!u64 {
    switch (fd) {
        .file => |p| {
            return p.getPosition() catch return error.Unseekable;
        },
        else => return error.Unseekable, // cannot read
    }
}

pub fn mkdirat(dir_fd: fd_t, sub_dir_path: []const u8, mode: u32) std.posix.MakeDirError!void {
    switch (dir_fd) {
        .file => |p| {
            var path_buffer: [PATH_MAX_WIDE]u16 = undefined;
            const len = try std.unicode.wtf8ToWtf16Le(&path_buffer, sub_dir_path);
            path_buffer[len] = 0;

            if (p.open(path_buffer[0..len :0], .{}, .{})) |fd| {
                fd.close();

                return error.PathAlreadyExists;
            } else |_| {}

            const fd = p.open(path_buffer[0..len :0], .{
                .write = true,
                .create = true,
            }, .{
                .directory = true,
            }) catch |err| switch (err) {
                error.NoMedia => return error.NoDevice,
                error.MediaChanged => return error.NoDevice,
                error.DeviceError => return error.NoDevice,
                error.VolumeCorrupted => return error.NoDevice,
                error.WriteProtected => return error.AccessDenied,
                error.AccessDenied => return error.AccessDenied,
                error.OutOfResources => return error.SystemResources,
                else => |e| return unexpectedError(e),
            };
            defer fd.close();
        },
        .simple_output => return error.NotDir,
        .simple_input => return error.NotDir,
        .none => return error.NotDir,
        .cwd => return mkdirat(uefi.working_directory, sub_dir_path, mode),
    }
}

pub fn openat(dir_fd: fd_t, file_path: []const u8, flags: O, mode: mode_t) std.posix.OpenError!fd_t {
    switch (dir_fd) {
        .file => |p| {
            var path_buffer: [PATH_MAX_WIDE]u16 = undefined;
            const len = try std.unicode.wtf8ToWtf16Le(&path_buffer, file_path);
            path_buffer[len] = 0;

            const fd = p.open(path_buffer[0..len :0], .{
                .read = true,
                .write = flags.CREAT or flags.TRUNC or flags.ACCMODE != .RDONLY,
                .create = flags.CREAT,
            }, .{}) catch |err| switch (err) {
                error.NoMedia => return error.NoDevice,
                error.MediaChanged => return error.NoDevice,
                error.DeviceError => return error.NoDevice,
                error.VolumeCorrupted => return error.NoDevice,
                error.WriteProtected => return error.AccessDenied,
                error.AccessDenied => return error.AccessDenied,
                error.OutOfResources => return error.SystemResources,
                error.InvalidParameter => return error.FileNotFound,
                else => |e| return unexpectedError(e),
            };

            return .{ .file = fd };
        },
        .simple_output => return error.NotDir,
        .simple_input => return error.NotDir,
        .none => return error.NotDir,
        .cwd => return openat(uefi.working_directory, file_path, flags, mode),
    }
}

pub fn read(fd: fd_t, buf: []u8) std.posix.ReadError!usize {
    switch (fd) {
        .file => |p| return p.read(buf) catch |err| switch (err) {
            error.NoMedia => return error.InputOutput,
            error.DeviceError => return error.InputOutput,
            error.VolumeCorrupted => return error.InputOutput,
            else => |e| return unexpectedError(e),
        },
        .simple_input => |p| {
            var index: usize = 0;
            while (index == 0) {
                while (p.readKeyStroke() catch |err| switch (err) {
                    error.NotReady => null,
                    error.DeviceError => return error.InputOutput,
                    else => |e| return unexpectedError(e),
                }) |key| {
                    if (key.unicode_char != 0) {
                        // this definitely isn't the right way to handle this, and it may fail on towards the limit of a single utf16 item.
                        index += std.unicode.utf16LeToUtf8(buf, &.{key.unicode_char}) catch continue;
                    }
                }
            }
            return @intCast(index);
        },
        else => return error.NotOpenForReading, // cannot read
    }
}

pub fn readlinkat(dirfd: fd_t, file_path: []const u8, out_buffer: []u8) std.posix.ReadLinkError![]u8 {
    const fd = openat(dirfd, file_path, .{}, 0) catch return error.FileNotFound;

    var buffer: [PATH_MAX]u8 = undefined;
    const path = std.os.getFdPath(fd, &buffer) catch return error.NameTooLong;
    if (path.len > out_buffer.len)
        return error.NameTooLong;

    @memcpy(out_buffer[0..path.len], path);
    return path;
}

pub fn realpath(pathname: []const u8, out_buffer: *[PATH_MAX]u8) std.posix.RealPathError![]u8 {
    const fd = openat(.cwd, pathname, .{}, 0) catch |err| switch (err) {
        error.WouldBlock => return error.DeviceBusy,
        error.InvalidUtf8 => unreachable,
        error.FileLocksNotSupported => unreachable,
        error.FileBusy => return error.DeviceBusy,
        else => |e| return unexpectedError(e),
    };
    defer close(fd);

    return std.os.getFdPath(fd, out_buffer);
}

pub fn renameat(
    old_dir_fd: fd_t,
    old_path: []const u8,
    new_dir_fd: fd_t,
    new_path: []const u8,
) std.posix.RenameError!void {
    switch (old_dir_fd) {
        .file => |old_dir_p| switch (new_dir_fd) {
            .file => |new_dir_p| {
                var old_path_buffer: [PATH_MAX_WIDE]u16 = undefined;
                const old_len = try std.unicode.wtf8ToWtf16Le(&old_path_buffer, old_path);
                old_path_buffer[old_len] = 0;

                var new_path_buffer: [PATH_MAX_WIDE]u16 = undefined;
                const new_len = try std.unicode.wtf8ToWtf16Le(&new_path_buffer, new_path);
                new_path_buffer[new_len] = 0;

                const old_fd = old_dir_p.open(old_path_buffer[0..old_len :0], .{}, .{}) catch |err| switch (err) {
                    error.NotFound => return error.FileNotFound,
                    error.NoMedia => return error.NoDevice,
                    error.MediaChanged => return error.NoDevice,
                    error.DeviceError => return error.NoDevice,
                    error.VolumeCorrupted => return error.NoDevice,
                    error.WriteProtected => return error.AccessDenied,
                    error.AccessDenied => return error.AccessDenied,
                    error.OutOfResources => return error.SystemResources,
                    else => |e| return unexpectedError(e),
                };
                errdefer old_fd.close();

                const new_fd = new_dir_p.open(new_path_buffer[0..new_len :0], .{ .write = true, .create = true }, .{}) catch |err| switch (err) {
                    error.NotFound => return error.FileNotFound,
                    error.NoMedia => return error.NoDevice,
                    error.MediaChanged => return error.NoDevice,
                    error.DeviceError => return error.NoDevice,
                    error.VolumeCorrupted => return error.NoDevice,
                    error.WriteProtected => return error.AccessDenied,
                    error.AccessDenied => return error.AccessDenied,
                    error.OutOfResources => return error.SystemResources,
                    else => |e| return unexpectedError(e),
                };
                defer new_fd.close();

                var buffer: [8192]u8 = undefined;
                while (true) {
                    const nread = old_fd.read(&buffer) catch |err| switch (err) {
                        error.NoMedia => return error.NoDevice,
                        error.DeviceError => return error.NoDevice,
                        error.VolumeCorrupted => return error.NoDevice,
                        else => |e| return unexpectedError(e),
                    };
                    if (nread == 0)
                        break;

                    var index: usize = 0;
                    while (index < nread) {
                        const written = new_fd.write(buffer[index..nread]) catch |err| switch (err) {
                            error.NoMedia => return error.NoDevice,
                            error.DeviceError => return error.NoDevice,
                            error.VolumeCorrupted => return error.NoDevice,
                            else => |e| return unexpectedError(e),
                        };
                        index += written;
                    }
                }

                _ = old_fd.delete();
            },
            .simple_output => return error.NotDir,
            .simple_input => return error.NotDir,
            .none => return error.NotDir,
            .cwd => return renameat(old_dir_fd, old_path, uefi.working_directory, new_path),
        },
        .simple_output => return error.NotDir,
        .simple_input => return error.NotDir,
        .none => return error.NotDir,
        .cwd => return renameat(uefi.working_directory, old_path, new_dir_fd, new_path),
    }
}

pub fn uname() utsname {
    var uts: utsname = undefined;

    @memcpy(&uts.sysname, "zig-uefi");
    uts.sysname[8] = 0;

    @memcpy(&uts.nodename, "zig-uefi");
    uts.nodename[8] = 0;

    const release = builtin.zig_version_string;
    @memcpy(uts.release[0..release.len], release);
    uts.release[release.len] = 0;

    @memcpy(&uts.version, "2.0.0");
    uts.version[5] = 0;

    const machine = @tagName(builtin.cpu.arch);
    @memcpy(uts.machine[0..machine.len], machine);
    uts.machine[machine.len] = 0;
}

pub fn unlinkat(dirfd: fd_t, file_path: []const u8, flags: u32) std.posix.UnlinkatError!void {
    switch (dirfd) {
        .file => |p| {
            var path_buffer: [PATH_MAX_WIDE]u16 = undefined;
            const len = try std.unicode.wtf8ToWtf16Le(&path_buffer, file_path);
            path_buffer[len] = 0;

            const fd = p.open(path_buffer[0..len :0], .{ .write = true }, .{}) catch |err| switch (err) {
                error.NotFound => return error.FileNotFound,
                error.NoMedia => return error.FileSystem,
                error.MediaChanged => return error.FileSystem,
                error.DeviceError => return error.FileSystem,
                error.VolumeCorrupted => return error.FileSystem,
                error.WriteProtected => return error.AccessDenied,
                error.AccessDenied => return error.AccessDenied,
                error.OutOfResources => return error.SystemResources,
                else => |e| return unexpectedError(e),
            };
            errdefer fd.close();

            const stat = try fstat(.{ .file = fd });

            // fd is a directory and AT_REMOVEDIR is not set
            if (stat.mode & S.IFDIR != 0 and flags & AT.REMOVEDIR != 0)
                return error.IsDir;

            if (!fd.delete()) {
                // delete failed, likely because this is a directory and not empty
                return error.DirNotEmpty;
            }
        },
        .simple_output => return error.NotDir,
        .simple_input => return error.NotDir,
        .none => return error.NotDir,
        .cwd => return unlinkat(uefi.working_directory, file_path, flags),
    }
}

pub fn write(fd: fd_t, buf: []const u8) std.posix.WriteError!usize {
    switch (fd) {
        .file => |p| return p.write(buf) catch |err| switch (err) {
            error.NoMedia => return error.NoDevice,
            error.DeviceError => return error.SystemResources,
            error.VolumeCorrupted => return error.InputOutput,
            error.WriteProtected => return error.AccessDenied,
            error.AccessDenied => return error.AccessDenied,
            else => |e| return unexpectedError(e),
        },
        .simple_output => |p| {
            const view = std.unicode.Utf8View.init(buf) catch unreachable;
            var iter = view.iterator();

            // rudimentary utf16 writer
            var index: usize = 0;
            var utf16: [256]u16 = undefined;
            while (iter.nextCodepoint()) |codepoint| {
                if (index + 2 >= utf16.len) {
                    utf16[index] = 0;
                    _ = p.outputString(utf16[0..index :0]) catch |err| switch (err) {
                        error.DeviceError => return error.InputOutput,
                        error.Unsupported => return error.NotOpenForWriting,
                        else => return error.Unexpected,
                    };
                    index = 0;
                }

                if (codepoint < 0x10000) {
                    if (codepoint == '\n') {
                        utf16[index] = '\r';
                        index += 1;
                    }

                    utf16[index] = @intCast(codepoint);
                    index += 1;
                } else {
                    const high = @as(u16, @intCast((codepoint - 0x10000) >> 10)) + 0xD800;
                    const low = @as(u16, @intCast(codepoint & 0x3FF)) + 0xDC00;
                    switch (builtin.cpu.arch.endian()) {
                        .little => {
                            utf16[index] = high;
                            utf16[index] = low;
                        },
                        .big => {
                            utf16[index] = low;
                            utf16[index] = high;
                        },
                    }
                    index += 2;
                }
            }

            if (index != 0) {
                utf16[index] = 0;
                _ = p.outputString(utf16[0..index :0]) catch |err| switch (err) {
                    error.DeviceError => return error.InputOutput,
                    error.Unsupported => return error.NotOpenForWriting,
                    else => return error.Unexpected,
                };
            }

            return @intCast(buf.len);
        },
        else => return error.NotOpenForWriting, // cannot write
    }
}
