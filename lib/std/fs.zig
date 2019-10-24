const builtin = @import("builtin");
const std = @import("std.zig");
const os = std.os;
const mem = std.mem;
const base64 = std.base64;
const crypto = std.crypto;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

pub const path = @import("fs/path.zig");
pub const File = @import("fs/file.zig").File;

pub const symLink = os.symlink;
pub const symLinkC = os.symlinkC;
pub const deleteFile = os.unlink;
pub const deleteFileC = os.unlinkC;
pub const rename = os.rename;
pub const renameC = os.renameC;
pub const renameW = os.renameW;
pub const realpath = os.realpath;
pub const realpathC = os.realpathC;
pub const realpathW = os.realpathW;

pub const getAppDataDir = @import("fs/get_app_data_dir.zig").getAppDataDir;
pub const GetAppDataDirError = @import("fs/get_app_data_dir.zig").GetAppDataDirError;

/// This represents the maximum size of a UTF-8 encoded file path.
/// All file system operations which return a path are guaranteed to
/// fit into a UTF-8 encoded array of this length.
pub const MAX_PATH_BYTES = switch (builtin.os) {
    .linux, .macosx, .ios, .freebsd, .netbsd => os.PATH_MAX,
    // Each UTF-16LE character may be expanded to 3 UTF-8 bytes.
    // If it would require 4 UTF-8 bytes, then there would be a surrogate
    // pair in the UTF-16LE, and we (over)account 3 bytes for it that way.
    // +1 for the null byte at the end, which can be encoded in 1 byte.
    .windows => os.windows.PATH_MAX_WIDE * 3 + 1,
    else => @compileError("Unsupported OS"),
};

// here we replace the standard +/ with -_ so that it can be used in a file name
const b64_fs_encoder = base64.Base64Encoder.init("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_", base64.standard_pad_char);

/// TODO remove the allocator requirement from this API
pub fn atomicSymLink(allocator: *Allocator, existing_path: []const u8, new_path: []const u8) !void {
    if (symLink(existing_path, new_path)) {
        return;
    } else |err| switch (err) {
        error.PathAlreadyExists => {},
        else => return err, // TODO zig should know this set does not include PathAlreadyExists
    }

    const dirname = path.dirname(new_path) orelse ".";

    var rand_buf: [12]u8 = undefined;
    const tmp_path = try allocator.alloc(u8, dirname.len + 1 + base64.Base64Encoder.calcSize(rand_buf.len));
    defer allocator.free(tmp_path);
    mem.copy(u8, tmp_path[0..], dirname);
    tmp_path[dirname.len] = path.sep;
    while (true) {
        try crypto.randomBytes(rand_buf[0..]);
        b64_fs_encoder.encode(tmp_path[dirname.len + 1 ..], rand_buf);

        if (symLink(existing_path, tmp_path)) {
            return rename(tmp_path, new_path);
        } else |err| switch (err) {
            error.PathAlreadyExists => continue,
            else => return err, // TODO zig should know this set does not include PathAlreadyExists
        }
    }
}

// TODO fix enum literal not casting to error union
const PrevStatus = enum {
    stale,
    fresh,
};

pub fn updateFile(source_path: []const u8, dest_path: []const u8) !PrevStatus {
    return updateFileMode(source_path, dest_path, null);
}

/// Check the file size, mtime, and mode of `source_path` and `dest_path`. If they are equal, does nothing.
/// Otherwise, atomically copies `source_path` to `dest_path`. The destination file gains the mtime,
/// atime, and mode of the source file so that the next call to `updateFile` will not need a copy.
/// Returns the previous status of the file before updating.
/// If any of the directories do not exist for dest_path, they are created.
/// TODO https://github.com/ziglang/zig/issues/2885
pub fn updateFileMode(source_path: []const u8, dest_path: []const u8, mode: ?File.Mode) !PrevStatus {
    var src_file = try File.openRead(source_path);
    defer src_file.close();

    const src_stat = try src_file.stat();
    check_dest_stat: {
        const dest_stat = blk: {
            var dest_file = File.openRead(dest_path) catch |err| switch (err) {
                error.FileNotFound => break :check_dest_stat,
                else => |e| return e,
            };
            defer dest_file.close();

            break :blk try dest_file.stat();
        };

        if (src_stat.size == dest_stat.size and
            src_stat.mtime == dest_stat.mtime and
            src_stat.mode == dest_stat.mode)
        {
            return PrevStatus.fresh;
        }
    }
    const actual_mode = mode orelse src_stat.mode;

    // TODO this logic could be made more efficient by calling makePath, once
    // that API does not require an allocator
    var atomic_file = make_atomic_file: while (true) {
        const af = AtomicFile.init(dest_path, actual_mode) catch |err| switch (err) {
            error.FileNotFound => {
                var p = dest_path;
                while (path.dirname(p)) |dirname| {
                    makeDir(dirname) catch |e| switch (e) {
                        error.FileNotFound => {
                            p = dirname;
                            continue;
                        },
                        else => return e,
                    };
                    continue :make_atomic_file;
                } else {
                    return err;
                }
            },
            else => |e| return e,
        };
        break af;
    } else unreachable;
    defer atomic_file.deinit();

    const in_stream = &src_file.inStream().stream;

    var buf: [mem.page_size * 6]u8 = undefined;
    while (true) {
        const amt = try in_stream.readFull(buf[0..]);
        try atomic_file.file.write(buf[0..amt]);
        if (amt != buf.len) {
            try atomic_file.file.updateTimes(src_stat.atime, src_stat.mtime);
            try atomic_file.finish();
            return PrevStatus.stale;
        }
    }
}

/// Guaranteed to be atomic. However until https://patchwork.kernel.org/patch/9636735/ is
/// merged and readily available,
/// there is a possibility of power loss or application termination leaving temporary files present
/// in the same directory as dest_path.
/// Destination file will have the same mode as the source file.
pub fn copyFile(source_path: []const u8, dest_path: []const u8) !void {
    var in_file = try File.openRead(source_path);
    defer in_file.close();

    const mode = try in_file.mode();
    const in_stream = &in_file.inStream().stream;

    var atomic_file = try AtomicFile.init(dest_path, mode);
    defer atomic_file.deinit();

    var buf: [mem.page_size]u8 = undefined;
    while (true) {
        const amt = try in_stream.readFull(buf[0..]);
        try atomic_file.file.write(buf[0..amt]);
        if (amt != buf.len) {
            return atomic_file.finish();
        }
    }
}

/// Guaranteed to be atomic. However until https://patchwork.kernel.org/patch/9636735/ is
/// merged and readily available,
/// there is a possibility of power loss or application termination leaving temporary files present
pub fn copyFileMode(source_path: []const u8, dest_path: []const u8, mode: File.Mode) !void {
    var in_file = try File.openRead(source_path);
    defer in_file.close();

    var atomic_file = try AtomicFile.init(dest_path, mode);
    defer atomic_file.deinit();

    var buf: [mem.page_size * 6]u8 = undefined;
    while (true) {
        const amt = try in_file.read(buf[0..]);
        try atomic_file.file.write(buf[0..amt]);
        if (amt != buf.len) {
            return atomic_file.finish();
        }
    }
}

pub const AtomicFile = struct {
    file: File,
    tmp_path_buf: [MAX_PATH_BYTES]u8,
    dest_path: []const u8,
    finished: bool,

    const InitError = File.OpenError;

    /// dest_path must remain valid for the lifetime of AtomicFile
    /// call finish to atomically replace dest_path with contents
    /// TODO once we have null terminated pointers, use the
    /// openWriteNoClobberN function
    pub fn init(dest_path: []const u8, mode: File.Mode) InitError!AtomicFile {
        const dirname = path.dirname(dest_path);
        var rand_buf: [12]u8 = undefined;
        const dirname_component_len = if (dirname) |d| d.len + 1 else 0;
        const encoded_rand_len = comptime base64.Base64Encoder.calcSize(rand_buf.len);
        const tmp_path_len = dirname_component_len + encoded_rand_len;
        var tmp_path_buf: [MAX_PATH_BYTES]u8 = undefined;
        if (tmp_path_len >= tmp_path_buf.len) return error.NameTooLong;

        if (dirname) |dir| {
            mem.copy(u8, tmp_path_buf[0..], dir);
            tmp_path_buf[dir.len] = path.sep;
        }

        tmp_path_buf[tmp_path_len] = 0;

        while (true) {
            try crypto.randomBytes(rand_buf[0..]);
            b64_fs_encoder.encode(tmp_path_buf[dirname_component_len..tmp_path_len], rand_buf);

            const file = File.openWriteNoClobberC(&tmp_path_buf, mode) catch |err| switch (err) {
                error.PathAlreadyExists => continue,
                // TODO zig should figure out that this error set does not include PathAlreadyExists since
                // it is handled in the above switch
                else => return err,
            };

            return AtomicFile{
                .file = file,
                .tmp_path_buf = tmp_path_buf,
                .dest_path = dest_path,
                .finished = false,
            };
        }
    }

    /// always call deinit, even after successful finish()
    pub fn deinit(self: *AtomicFile) void {
        if (!self.finished) {
            self.file.close();
            deleteFileC(&self.tmp_path_buf) catch {};
            self.finished = true;
        }
    }

    pub fn finish(self: *AtomicFile) !void {
        assert(!self.finished);
        self.file.close();
        self.finished = true;
        if (builtin.os == .windows) {
            const dest_path_w = try os.windows.sliceToPrefixedFileW(self.dest_path);
            const tmp_path_w = try os.windows.cStrToPrefixedFileW(&self.tmp_path_buf);
            return os.renameW(&tmp_path_w, &dest_path_w);
        }
        const dest_path_c = try os.toPosixPath(self.dest_path);
        return os.renameC(&self.tmp_path_buf, &dest_path_c);
    }
};

const default_new_dir_mode = 0o755;

/// Create a new directory.
pub fn makeDir(dir_path: []const u8) !void {
    return os.mkdir(dir_path, default_new_dir_mode);
}

/// Same as `makeDir` except the parameter is a null-terminated UTF8-encoded string.
pub fn makeDirC(dir_path: [*]const u8) !void {
    return os.mkdirC(dir_path, default_new_dir_mode);
}

/// Same as `makeDir` except the parameter is a null-terminated UTF16LE-encoded string.
pub fn makeDirW(dir_path: [*]const u16) !void {
    return os.mkdirW(dir_path, default_new_dir_mode);
}

/// Calls makeDir recursively to make an entire path. Returns success if the path
/// already exists and is a directory.
/// This function is not atomic, and if it returns an error, the file system may
/// have been modified regardless.
/// TODO determine if we can remove the allocator requirement from this function
pub fn makePath(allocator: *Allocator, full_path: []const u8) !void {
    const resolved_path = try path.resolve(allocator, [_][]const u8{full_path});
    defer allocator.free(resolved_path);

    var end_index: usize = resolved_path.len;
    while (true) {
        makeDir(resolved_path[0..end_index]) catch |err| switch (err) {
            error.PathAlreadyExists => {
                // TODO stat the file and return an error if it's not a directory
                // this is important because otherwise a dangling symlink
                // could cause an infinite loop
                if (end_index == resolved_path.len) return;
            },
            error.FileNotFound => {
                // march end_index backward until next path component
                while (true) {
                    end_index -= 1;
                    if (path.isSep(resolved_path[end_index])) break;
                }
                continue;
            },
            else => return err,
        };
        if (end_index == resolved_path.len) return;
        // march end_index forward until next path component
        while (true) {
            end_index += 1;
            if (end_index == resolved_path.len or path.isSep(resolved_path[end_index])) break;
        }
    }
}

/// Returns `error.DirNotEmpty` if the directory is not empty.
/// To delete a directory recursively, see `deleteTree`.
pub fn deleteDir(dir_path: []const u8) !void {
    return os.rmdir(dir_path);
}

/// Same as `deleteDir` except the parameter is a null-terminated UTF8-encoded string.
pub fn deleteDirC(dir_path: [*]const u8) !void {
    return os.rmdirC(dir_path);
}

/// Same as `deleteDir` except the parameter is a null-terminated UTF16LE-encoded string.
pub fn deleteDirW(dir_path: [*]const u16) !void {
    return os.rmdirW(dir_path);
}

/// Removes a symlink, file, or directory.
/// If `full_path` is relative, this is equivalent to `Dir.deleteTree` with the
/// current working directory as the open directory handle.
/// If `full_path` is absolute, this is equivalent to `Dir.deleteTree` with the
/// base directory.
pub fn deleteTree(full_path: []const u8) !void {
    if (path.isAbsolute(full_path)) {
        const dirname = path.dirname(full_path) orelse return error{
            /// Attempt to remove the root file system path.
            /// This error is unreachable if `full_path` is relative.
            CannotDeleteRootDirectory,
        }.CannotDeleteRootDirectory;

        var dir = try Dir.open(dirname);
        defer dir.close();

        return dir.deleteTree(path.basename(full_path));
    } else {
        return Dir.cwd().deleteTree(full_path);
    }
}

pub const Dir = struct {
    fd: os.fd_t,

    pub const Entry = struct {
        name: []const u8,
        kind: Kind,

        pub const Kind = enum {
            BlockDevice,
            CharacterDevice,
            Directory,
            NamedPipe,
            SymLink,
            File,
            UnixDomainSocket,
            Whiteout,
            Unknown,
        };
    };

    const IteratorError = error{AccessDenied} || os.UnexpectedError;

    pub const Iterator = switch (builtin.os) {
        .macosx, .ios, .freebsd, .netbsd => struct {
            dir: Dir,
            seek: i64,
            buf: [8192]u8, // TODO align(@alignOf(os.dirent)),
            index: usize,
            end_index: usize,

            const Self = @This();

            pub const Error = IteratorError;

            /// Memory such as file names referenced in this returned entry becomes invalid
            /// with subsequent calls to `next`, as well as when this `Dir` is deinitialized.
            pub fn next(self: *Self) Error!?Entry {
                switch (builtin.os) {
                    .macosx, .ios => return self.nextDarwin(),
                    .freebsd, .netbsd => return self.nextBsd(),
                    else => @compileError("unimplemented"),
                }
            }

            fn nextDarwin(self: *Self) !?Entry {
                start_over: while (true) {
                    if (self.index >= self.end_index) {
                        const rc = os.system.__getdirentries64(
                            self.dir.fd,
                            &self.buf,
                            self.buf.len,
                            &self.seek,
                        );
                        if (rc == 0) return null;
                        if (rc < 0) {
                            switch (os.errno(rc)) {
                                os.EBADF => unreachable,
                                os.EFAULT => unreachable,
                                os.ENOTDIR => unreachable,
                                os.EINVAL => unreachable,
                                else => |err| return os.unexpectedErrno(err),
                            }
                        }
                        self.index = 0;
                        self.end_index = @intCast(usize, rc);
                    }
                    const darwin_entry = @ptrCast(*align(1) os.dirent, &self.buf[self.index]);
                    const next_index = self.index + darwin_entry.d_reclen;
                    self.index = next_index;

                    const name = @ptrCast([*]u8, &darwin_entry.d_name)[0..darwin_entry.d_namlen];

                    if (mem.eql(u8, name, ".") or mem.eql(u8, name, "..")) {
                        continue :start_over;
                    }

                    const entry_kind = switch (darwin_entry.d_type) {
                        os.DT_BLK => Entry.Kind.BlockDevice,
                        os.DT_CHR => Entry.Kind.CharacterDevice,
                        os.DT_DIR => Entry.Kind.Directory,
                        os.DT_FIFO => Entry.Kind.NamedPipe,
                        os.DT_LNK => Entry.Kind.SymLink,
                        os.DT_REG => Entry.Kind.File,
                        os.DT_SOCK => Entry.Kind.UnixDomainSocket,
                        os.DT_WHT => Entry.Kind.Whiteout,
                        else => Entry.Kind.Unknown,
                    };
                    return Entry{
                        .name = name,
                        .kind = entry_kind,
                    };
                }
            }

            fn nextBsd(self: *Self) !?Entry {
                start_over: while (true) {
                    if (self.index >= self.end_index) {
                        const rc = os.system.getdirentries(
                            self.dir.fd,
                            self.buf[0..].ptr,
                            self.buf.len,
                            &self.seek,
                        );
                        switch (os.errno(rc)) {
                            0 => {},
                            os.EBADF => unreachable,
                            os.EFAULT => unreachable,
                            os.ENOTDIR => unreachable,
                            os.EINVAL => unreachable,
                            else => |err| return os.unexpectedErrno(err),
                        }
                        if (rc == 0) return null;
                        self.index = 0;
                        self.end_index = @intCast(usize, rc);
                    }
                    const freebsd_entry = @ptrCast(*align(1) os.dirent, &self.buf[self.index]);
                    const next_index = self.index + freebsd_entry.d_reclen;
                    self.index = next_index;

                    const name = @ptrCast([*]u8, &freebsd_entry.d_name)[0..freebsd_entry.d_namlen];

                    if (mem.eql(u8, name, ".") or mem.eql(u8, name, "..")) {
                        continue :start_over;
                    }

                    const entry_kind = switch (freebsd_entry.d_type) {
                        os.DT_BLK => Entry.Kind.BlockDevice,
                        os.DT_CHR => Entry.Kind.CharacterDevice,
                        os.DT_DIR => Entry.Kind.Directory,
                        os.DT_FIFO => Entry.Kind.NamedPipe,
                        os.DT_LNK => Entry.Kind.SymLink,
                        os.DT_REG => Entry.Kind.File,
                        os.DT_SOCK => Entry.Kind.UnixDomainSocket,
                        os.DT_WHT => Entry.Kind.Whiteout,
                        else => Entry.Kind.Unknown,
                    };
                    return Entry{
                        .name = name,
                        .kind = entry_kind,
                    };
                }
            }
        },
        .linux => struct {
            dir: Dir,
            buf: [8192]u8, // TODO align(@alignOf(os.dirent64)),
            index: usize,
            end_index: usize,

            const Self = @This();

            pub const Error = IteratorError;

            /// Memory such as file names referenced in this returned entry becomes invalid
            /// with subsequent calls to `next`, as well as when this `Dir` is deinitialized.
            pub fn next(self: *Self) Error!?Entry {
                start_over: while (true) {
                    if (self.index >= self.end_index) {
                        const rc = os.linux.getdents64(self.dir.fd, &self.buf, self.buf.len);
                        switch (os.linux.getErrno(rc)) {
                            0 => {},
                            os.EBADF => unreachable,
                            os.EFAULT => unreachable,
                            os.ENOTDIR => unreachable,
                            os.EINVAL => unreachable,
                            else => |err| return os.unexpectedErrno(err),
                        }
                        if (rc == 0) return null;
                        self.index = 0;
                        self.end_index = rc;
                    }
                    const linux_entry = @ptrCast(*align(1) os.dirent64, &self.buf[self.index]);
                    const next_index = self.index + linux_entry.d_reclen;
                    self.index = next_index;

                    const name = mem.toSlice(u8, @ptrCast([*]u8, &linux_entry.d_name));

                    // skip . and .. entries
                    if (mem.eql(u8, name, ".") or mem.eql(u8, name, "..")) {
                        continue :start_over;
                    }

                    const entry_kind = switch (linux_entry.d_type) {
                        os.DT_BLK => Entry.Kind.BlockDevice,
                        os.DT_CHR => Entry.Kind.CharacterDevice,
                        os.DT_DIR => Entry.Kind.Directory,
                        os.DT_FIFO => Entry.Kind.NamedPipe,
                        os.DT_LNK => Entry.Kind.SymLink,
                        os.DT_REG => Entry.Kind.File,
                        os.DT_SOCK => Entry.Kind.UnixDomainSocket,
                        else => Entry.Kind.Unknown,
                    };
                    return Entry{
                        .name = name,
                        .kind = entry_kind,
                    };
                }
            }
        },
        .windows => struct {
            dir: Dir,
            buf: [8192]u8 align(@alignOf(os.windows.FILE_BOTH_DIR_INFORMATION)),
            index: usize,
            end_index: usize,
            first: bool,
            name_data: [256]u8,

            const Self = @This();

            pub const Error = IteratorError;

            pub fn next(self: *Self) Error!?Entry {
                start_over: while (true) {
                    const w = os.windows;
                    if (self.index >= self.end_index) {
                        var io: w.IO_STATUS_BLOCK = undefined;
                        const rc = w.ntdll.NtQueryDirectoryFile(
                            self.dir.fd,
                            null,
                            null,
                            null,
                            &io,
                            &self.buf,
                            self.buf.len,
                            .FileBothDirectoryInformation,
                            w.FALSE,
                            null,
                            if (self.first) w.BOOLEAN(w.TRUE) else w.BOOLEAN(w.FALSE),
                        );
                        self.first = false;
                        if (io.Information == 0) return null;
                        self.index = 0;
                        self.end_index = io.Information;
                        switch (rc) {
                            w.STATUS.SUCCESS => {},
                            w.STATUS.ACCESS_DENIED => return error.AccessDenied,
                            else => return w.unexpectedStatus(rc),
                        }
                    }

                    const aligned_ptr = @alignCast(@alignOf(w.FILE_BOTH_DIR_INFORMATION), &self.buf[self.index]);
                    const dir_info = @ptrCast(*w.FILE_BOTH_DIR_INFORMATION, aligned_ptr);
                    if (dir_info.NextEntryOffset != 0) {
                        self.index += dir_info.NextEntryOffset;
                    } else {
                        self.index = self.buf.len;
                    }

                    const name_utf16le = @ptrCast([*]u16, &dir_info.FileName)[0 .. dir_info.FileNameLength / 2];

                    if (mem.eql(u16, name_utf16le, [_]u16{'.'}) or mem.eql(u16, name_utf16le, [_]u16{ '.', '.' }))
                        continue;
                    // Trust that Windows gives us valid UTF-16LE
                    const name_utf8_len = std.unicode.utf16leToUtf8(self.name_data[0..], name_utf16le) catch unreachable;
                    const name_utf8 = self.name_data[0..name_utf8_len];
                    const kind = blk: {
                        const attrs = dir_info.FileAttributes;
                        if (attrs & w.FILE_ATTRIBUTE_DIRECTORY != 0) break :blk Entry.Kind.Directory;
                        if (attrs & w.FILE_ATTRIBUTE_REPARSE_POINT != 0) break :blk Entry.Kind.SymLink;
                        break :blk Entry.Kind.File;
                    };
                    return Entry{
                        .name = name_utf8,
                        .kind = kind,
                    };
                }
            }
        },
        else => @compileError("unimplemented"),
    };

    pub fn iterate(self: Dir) Iterator {
        switch (builtin.os) {
            .macosx, .ios, .freebsd, .netbsd => return Iterator{
                .dir = self,
                .seek = 0,
                .index = 0,
                .end_index = 0,
                .buf = undefined,
            },
            .linux => return Iterator{
                .dir = self,
                .index = 0,
                .end_index = 0,
                .buf = undefined,
            },
            .windows => return Iterator{
                .dir = self,
                .index = 0,
                .end_index = 0,
                .first = true,
                .buf = undefined,
                .name_data = undefined,
            },
            else => @compileError("unimplemented"),
        }
    }

    /// Returns an open handle to the current working directory.
    /// Closing the returned `Dir` is checked illegal behavior.
    /// On POSIX targets, this function is comptime-callable.
    pub fn cwd() Dir {
        if (builtin.os == .windows) {
            return Dir{ .fd = os.windows.peb().ProcessParameters.CurrentDirectory.Handle };
        } else {
            return Dir{ .fd = os.AT_FDCWD };
        }
    }

    pub const OpenError = error{
        FileNotFound,
        NotDir,
        AccessDenied,
        SymLinkLoop,
        ProcessFdQuotaExceeded,
        NameTooLong,
        SystemFdQuotaExceeded,
        NoDevice,
        SystemResources,
        InvalidUtf8,
        BadPathName,
        DeviceBusy,
    } || os.UnexpectedError;

    /// Call `close` to free the directory handle.
    pub fn open(dir_path: []const u8) OpenError!Dir {
        return cwd().openDir(dir_path);
    }

    /// Same as `open` except the parameter is null-terminated.
    pub fn openC(dir_path_c: [*]const u8) OpenError!Dir {
        return cwd().openDirC(dir_path_c);
    }

    pub fn close(self: *Dir) void {
        os.close(self.fd);
        self.* = undefined;
    }

    /// Call `File.close` on the result when done.
    pub fn openRead(self: Dir, sub_path: []const u8) File.OpenError!File {
        const path_c = try os.toPosixPath(sub_path);
        return self.openReadC(&path_c);
    }

    /// Call `File.close` on the result when done.
    pub fn openReadC(self: Dir, sub_path: [*]const u8) File.OpenError!File {
        const flags = os.O_LARGEFILE | os.O_RDONLY;
        const fd = try os.openatC(self.fd, sub_path, flags, 0);
        return File.openHandle(fd);
    }

    /// Call `close` on the result when done.
    pub fn openDir(self: Dir, sub_path: []const u8) OpenError!Dir {
        if (builtin.os == .windows) {
            const sub_path_w = try os.windows.sliceToPrefixedFileW(sub_path);
            return self.openDirW(&sub_path_w);
        }

        const sub_path_c = try os.toPosixPath(sub_path);
        return self.openDirC(&sub_path_c);
    }

    /// Same as `openDir` except the parameter is null-terminated.
    pub fn openDirC(self: Dir, sub_path_c: [*]const u8) OpenError!Dir {
        if (builtin.os == .windows) {
            const sub_path_w = try os.windows.cStrToPrefixedFileW(sub_path_c);
            return self.openDirW(&sub_path_w);
        }

        const flags = os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC;
        const fd = os.openatC(self.fd, sub_path_c, flags, 0) catch |err| switch (err) {
            error.FileTooBig => unreachable, // can't happen for directories
            error.IsDir => unreachable, // we're providing O_DIRECTORY
            error.NoSpaceLeft => unreachable, // not providing O_CREAT
            error.PathAlreadyExists => unreachable, // not providing O_CREAT
            else => |e| return e,
        };
        return Dir{ .fd = fd };
    }

    /// Same as `openDir` except the path parameter is UTF16LE, NT-prefixed.
    /// This function is Windows-only.
    pub fn openDirW(self: Dir, sub_path_w: [*]const u16) OpenError!Dir {
        const w = os.windows;

        var result = Dir{
            .fd = undefined,
        };

        const path_len_bytes = @intCast(u16, mem.toSliceConst(u16, sub_path_w).len * 2);
        var nt_name = w.UNICODE_STRING{
            .Length = path_len_bytes,
            .MaximumLength = path_len_bytes,
            .Buffer = @intToPtr([*]u16, @ptrToInt(sub_path_w)),
        };
        var attr = w.OBJECT_ATTRIBUTES{
            .Length = @sizeOf(w.OBJECT_ATTRIBUTES),
            .RootDirectory = if (path.isAbsoluteW(sub_path_w)) null else self.fd,
            .Attributes = 0, // Note we do not use OBJ_CASE_INSENSITIVE here.
            .ObjectName = &nt_name,
            .SecurityDescriptor = null,
            .SecurityQualityOfService = null,
        };
        if (sub_path_w[0] == '.' and sub_path_w[1] == 0) {
            // Windows does not recognize this, but it does work with empty string.
            nt_name.Length = 0;
        }
        if (sub_path_w[0] == '.' and sub_path_w[1] == '.' and sub_path_w[2] == 0) {
            // If you're looking to contribute to zig and fix this, see here for an example of how to
            // implement this: https://git.midipix.org/ntapi/tree/src/fs/ntapi_tt_open_physical_parent_directory.c
            @panic("TODO opening '..' with a relative directory handle is not yet implemented on Windows");
        }
        var io: w.IO_STATUS_BLOCK = undefined;
        const rc = w.ntdll.NtCreateFile(
            &result.fd,
            w.GENERIC_READ | w.SYNCHRONIZE,
            &attr,
            &io,
            null,
            0,
            w.FILE_SHARE_READ | w.FILE_SHARE_WRITE,
            w.FILE_OPEN,
            w.FILE_DIRECTORY_FILE | w.FILE_SYNCHRONOUS_IO_NONALERT | w.FILE_OPEN_FOR_BACKUP_INTENT,
            null,
            0,
        );
        switch (rc) {
            w.STATUS.SUCCESS => return result,
            w.STATUS.OBJECT_NAME_INVALID => unreachable,
            w.STATUS.OBJECT_NAME_NOT_FOUND => return error.FileNotFound,
            w.STATUS.OBJECT_PATH_NOT_FOUND => return error.FileNotFound,
            w.STATUS.INVALID_PARAMETER => unreachable,
            else => return w.unexpectedStatus(rc),
        }
    }

    pub const DeleteFileError = os.UnlinkError;

    /// Delete a file name and possibly the file it refers to, based on an open directory handle.
    pub fn deleteFile(self: Dir, sub_path: []const u8) DeleteFileError!void {
        const sub_path_c = try os.toPosixPath(sub_path);
        return self.deleteFileC(&sub_path_c);
    }

    /// Same as `deleteFile` except the parameter is null-terminated.
    pub fn deleteFileC(self: Dir, sub_path_c: [*]const u8) DeleteFileError!void {
        os.unlinkatC(self.fd, sub_path_c, 0) catch |err| switch (err) {
            error.DirNotEmpty => unreachable, // not passing AT_REMOVEDIR
            else => |e| return e,
        };
    }

    pub const DeleteDirError = error{
        DirNotEmpty,
        FileNotFound,
        AccessDenied,
        FileBusy,
        FileSystem,
        SymLinkLoop,
        NameTooLong,
        NotDir,
        SystemResources,
        ReadOnlyFileSystem,
        InvalidUtf8,
        BadPathName,
        Unexpected,
    };

    /// Returns `error.DirNotEmpty` if the directory is not empty.
    /// To delete a directory recursively, see `deleteTree`.
    pub fn deleteDir(self: Dir, sub_path: []const u8) DeleteDirError!void {
        if (builtin.os == .windows) {
            const sub_path_w = try os.windows.sliceToPrefixedFileW(sub_path);
            return self.deleteDirW(&sub_path_w);
        }
        const sub_path_c = try os.toPosixPath(sub_path);
        return self.deleteDirC(&sub_path_c);
    }

    /// Same as `deleteDir` except the parameter is null-terminated.
    pub fn deleteDirC(self: Dir, sub_path_c: [*]const u8) DeleteDirError!void {
        os.unlinkatC(self.fd, sub_path_c, os.AT_REMOVEDIR) catch |err| switch (err) {
            error.IsDir => unreachable, // not possible since we pass AT_REMOVEDIR
            else => |e| return e,
        };
    }

    /// Same as `deleteDir` except the parameter is UTF16LE, NT prefixed.
    /// This function is Windows-only.
    pub fn deleteDirW(self: Dir, sub_path_w: [*]const u16) DeleteDirError!void {
        os.unlinkatW(self.fd, sub_path_w, os.AT_REMOVEDIR) catch |err| switch (err) {
            error.IsDir => unreachable, // not possible since we pass AT_REMOVEDIR
            else => |e| return e,
        };
    }

    /// Read value of a symbolic link.
    /// The return value is a slice of `buffer`, from index `0`.
    pub fn readLink(self: Dir, sub_path: []const u8, buffer: *[MAX_PATH_BYTES]u8) ![]u8 {
        const sub_path_c = try os.toPosixPath(sub_path);
        return self.readLinkC(&sub_path_c, buffer);
    }

    /// Same as `readLink`, except the `pathname` parameter is null-terminated.
    pub fn readLinkC(self: Dir, sub_path_c: [*]const u8, buffer: *[MAX_PATH_BYTES]u8) ![]u8 {
        return os.readlinkatC(self.fd, sub_path_c, buffer);
    }

    pub const DeleteTreeError = error{
        AccessDenied,
        FileTooBig,
        SymLinkLoop,
        ProcessFdQuotaExceeded,
        NameTooLong,
        SystemFdQuotaExceeded,
        NoDevice,
        SystemResources,
        ReadOnlyFileSystem,
        FileSystem,
        FileBusy,
        DeviceBusy,

        /// One of the path components was not a directory.
        /// This error is unreachable if `sub_path` does not contain a path separator.
        NotDir,

        /// On Windows, file paths must be valid Unicode.
        InvalidUtf8,

        /// On Windows, file paths cannot contain these characters:
        /// '/', '*', '?', '"', '<', '>', '|'
        BadPathName,
    } || os.UnexpectedError;

    /// Whether `full_path` describes a symlink, file, or directory, this function
    /// removes it. If it cannot be removed because it is a non-empty directory,
    /// this function recursively removes its entries and then tries again.
    /// This operation is not atomic on most file systems.
    pub fn deleteTree(self: Dir, sub_path: []const u8) DeleteTreeError!void {
        start_over: while (true) {
            var got_access_denied = false;
            // First, try deleting the item as a file. This way we don't follow sym links.
            if (self.deleteFile(sub_path)) {
                return;
            } else |err| switch (err) {
                error.FileNotFound => return,
                error.IsDir => {},
                error.AccessDenied => got_access_denied = true,

                error.InvalidUtf8,
                error.SymLinkLoop,
                error.NameTooLong,
                error.SystemResources,
                error.ReadOnlyFileSystem,
                error.NotDir,
                error.FileSystem,
                error.FileBusy,
                error.BadPathName,
                error.Unexpected,
                => |e| return e,
            }
            var dir = self.openDir(sub_path) catch |err| switch (err) {
                error.NotDir => {
                    if (got_access_denied) {
                        return error.AccessDenied;
                    }
                    continue :start_over;
                },
                error.FileNotFound => {
                    // That's fine, we were trying to remove this directory anyway.
                    continue :start_over;
                },

                error.AccessDenied,
                error.SymLinkLoop,
                error.ProcessFdQuotaExceeded,
                error.NameTooLong,
                error.SystemFdQuotaExceeded,
                error.NoDevice,
                error.SystemResources,
                error.Unexpected,
                error.InvalidUtf8,
                error.BadPathName,
                error.DeviceBusy,
                => |e| return e,
            };
            var cleanup_dir_parent: ?Dir = null;
            defer if (cleanup_dir_parent) |*d| d.close();

            var cleanup_dir = true;
            defer if (cleanup_dir) dir.close();

            var dir_name_buf: [MAX_PATH_BYTES]u8 = undefined;
            var dir_name: []const u8 = sub_path;
            var parent_dir = self;

            // Here we must avoid recursion, in order to provide O(1) memory guarantee of this function.
            // Go through each entry and if it is not a directory, delete it. If it is a directory,
            // open it, and close the original directory. Repeat. Then start the entire operation over.

            scan_dir: while (true) {
                var dir_it = dir.iterate();
                while (try dir_it.next()) |entry| {
                    if (dir.deleteFile(entry.name)) {
                        continue;
                    } else |err| switch (err) {
                        error.FileNotFound => continue,

                        // Impossible because we do not pass any path separators.
                        error.NotDir => unreachable,

                        error.IsDir => {},
                        error.AccessDenied => got_access_denied = true,

                        error.InvalidUtf8,
                        error.SymLinkLoop,
                        error.NameTooLong,
                        error.SystemResources,
                        error.ReadOnlyFileSystem,
                        error.FileSystem,
                        error.FileBusy,
                        error.BadPathName,
                        error.Unexpected,
                        => |e| return e,
                    }

                    const new_dir = dir.openDir(entry.name) catch |err| switch (err) {
                        error.NotDir => {
                            if (got_access_denied) {
                                return error.AccessDenied;
                            }
                            continue :scan_dir;
                        },
                        error.FileNotFound => {
                            // That's fine, we were trying to remove this directory anyway.
                            continue :scan_dir;
                        },

                        error.AccessDenied,
                        error.SymLinkLoop,
                        error.ProcessFdQuotaExceeded,
                        error.NameTooLong,
                        error.SystemFdQuotaExceeded,
                        error.NoDevice,
                        error.SystemResources,
                        error.Unexpected,
                        error.InvalidUtf8,
                        error.BadPathName,
                        error.DeviceBusy,
                        => |e| return e,
                    };
                    if (cleanup_dir_parent) |*d| d.close();
                    cleanup_dir_parent = dir;
                    dir = new_dir;
                    mem.copy(u8, &dir_name_buf, entry.name);
                    dir_name = dir_name_buf[0..entry.name.len];
                    continue :scan_dir;
                }
                // Reached the end of the directory entries, which means we successfully deleted all of them.
                // Now to remove the directory itself.
                dir.close();
                cleanup_dir = false;

                if (cleanup_dir_parent) |d| {
                    d.deleteDir(dir_name) catch |err| switch (err) {
                        // These two things can happen due to file system race conditions.
                        error.FileNotFound, error.DirNotEmpty => continue :start_over,
                        else => |e| return e,
                    };
                    continue :start_over;
                } else {
                    self.deleteDir(sub_path) catch |err| switch (err) {
                        error.FileNotFound => return,
                        error.DirNotEmpty => continue :start_over,
                        else => |e| return e,
                    };
                    return;
                }
            }
        }
    }
};

pub const Walker = struct {
    stack: std.ArrayList(StackItem),
    name_buffer: std.Buffer,

    pub const Entry = struct {
        /// The containing directory. This can be used to operate directly on `basename`
        /// rather than `path`, avoiding `error.NameTooLong` for deeply nested paths.
        /// The directory remains open until `next` or `deinit` is called.
        dir: Dir,
        basename: []const u8,

        path: []const u8,
        kind: Dir.Entry.Kind,
    };

    const StackItem = struct {
        dir_it: Dir.Iterator,
        dirname_len: usize,
    };

    /// After each call to this function, and on deinit(), the memory returned
    /// from this function becomes invalid. A copy must be made in order to keep
    /// a reference to the path.
    pub fn next(self: *Walker) !?Entry {
        while (true) {
            if (self.stack.len == 0) return null;
            // `top` becomes invalid after appending to `self.stack`.
            const top = &self.stack.toSlice()[self.stack.len - 1];
            const dirname_len = top.dirname_len;
            if (try top.dir_it.next()) |base| {
                self.name_buffer.shrink(dirname_len);
                try self.name_buffer.appendByte(path.sep);
                try self.name_buffer.append(base.name);
                if (base.kind == .Directory) {
                    var new_dir = top.dir_it.dir.openDir(base.name) catch |err| switch (err) {
                        error.NameTooLong => unreachable, // no path sep in base.name
                        else => |e| return e,
                    };
                    {
                        errdefer new_dir.close();
                        try self.stack.append(StackItem{
                            .dir_it = new_dir.iterate(),
                            .dirname_len = self.name_buffer.len(),
                        });
                    }
                }
                return Entry{
                    .dir = top.dir_it.dir,
                    .basename = self.name_buffer.toSliceConst()[dirname_len + 1 ..],
                    .path = self.name_buffer.toSliceConst(),
                    .kind = base.kind,
                };
            } else {
                self.stack.pop().dir_it.dir.close();
            }
        }
    }

    pub fn deinit(self: *Walker) void {
        while (self.stack.popOrNull()) |*item| item.dir_it.close();
        self.stack.deinit();
        self.name_buffer.deinit();
    }
};

/// Recursively iterates over a directory.
/// Must call `Walker.deinit` when done.
/// `dir_path` must not end in a path separator.
/// The order of returned file system entries is undefined.
pub fn walkPath(allocator: *Allocator, dir_path: []const u8) !Walker {
    assert(!mem.endsWith(u8, dir_path, path.sep_str));

    var dir = try Dir.open(dir_path);
    errdefer dir.close();

    var name_buffer = try std.Buffer.init(allocator, dir_path);
    errdefer name_buffer.deinit();

    var walker = Walker{
        .stack = std.ArrayList(Walker.StackItem).init(allocator),
        .name_buffer = name_buffer,
    };

    try walker.stack.append(Walker.StackItem{
        .dir_it = dir.iterate(),
        .dirname_len = dir_path.len,
    });

    return walker;
}

/// Read value of a symbolic link.
/// The return value is a slice of buffer, from index `0`.
pub fn readLink(pathname: []const u8, buffer: *[MAX_PATH_BYTES]u8) ![]u8 {
    return os.readlink(pathname, buffer);
}

/// Same as `readLink`, except the parameter is null-terminated.
pub fn readLinkC(pathname_c: [*]const u8, buffer: *[MAX_PATH_BYTES]u8) ![]u8 {
    return os.readlinkC(pathname_c, buffer);
}

pub const OpenSelfExeError = os.OpenError || os.windows.CreateFileError || SelfExePathError;

pub fn openSelfExe() OpenSelfExeError!File {
    if (builtin.os == .linux) {
        return File.openReadC(c"/proc/self/exe");
    }
    if (builtin.os == .windows) {
        var buf: [os.windows.PATH_MAX_WIDE]u16 = undefined;
        const wide_slice = try selfExePathW(&buf);
        return File.openReadW(wide_slice.ptr);
    }
    var buf: [MAX_PATH_BYTES]u8 = undefined;
    const self_exe_path = try selfExePath(&buf);
    buf[self_exe_path.len] = 0;
    return File.openReadC(self_exe_path.ptr);
}

test "openSelfExe" {
    switch (builtin.os) {
        .linux, .macosx, .ios, .windows, .freebsd => (try openSelfExe()).close(),
        else => return error.SkipZigTest, // Unsupported OS.
    }
}

pub const SelfExePathError = os.ReadLinkError || os.SysCtlError;

/// Get the path to the current executable.
/// If you only need the directory, use selfExeDirPath.
/// If you only want an open file handle, use openSelfExe.
/// This function may return an error if the current executable
/// was deleted after spawning.
/// Returned value is a slice of out_buffer.
///
/// On Linux, depends on procfs being mounted. If the currently executing binary has
/// been deleted, the file path looks something like `/a/b/c/exe (deleted)`.
/// TODO make the return type of this a null terminated pointer
pub fn selfExePath(out_buffer: *[MAX_PATH_BYTES]u8) SelfExePathError![]u8 {
    if (comptime std.Target.current.isDarwin()) {
        var u32_len: u32 = out_buffer.len;
        const rc = std.c._NSGetExecutablePath(out_buffer, &u32_len);
        if (rc != 0) return error.NameTooLong;
        return mem.toSlice(u8, out_buffer);
    }
    switch (builtin.os) {
        .linux => return os.readlinkC(c"/proc/self/exe", out_buffer),
        .freebsd => {
            var mib = [4]c_int{ os.CTL_KERN, os.KERN_PROC, os.KERN_PROC_PATHNAME, -1 };
            var out_len: usize = out_buffer.len;
            try os.sysctl(&mib, out_buffer, &out_len, null, 0);
            // TODO could this slice from 0 to out_len instead?
            return mem.toSlice(u8, out_buffer);
        },
        .netbsd => {
            var mib = [4]c_int{ os.CTL_KERN, os.KERN_PROC_ARGS, -1, os.KERN_PROC_PATHNAME };
            var out_len: usize = out_buffer.len;
            try os.sysctl(&mib, out_buffer, &out_len, null, 0);
            // TODO could this slice from 0 to out_len instead?
            return mem.toSlice(u8, out_buffer);
        },
        .windows => {
            var utf16le_buf: [os.windows.PATH_MAX_WIDE]u16 = undefined;
            const utf16le_slice = try selfExePathW(&utf16le_buf);
            // Trust that Windows gives us valid UTF-16LE.
            const end_index = std.unicode.utf16leToUtf8(out_buffer, utf16le_slice) catch unreachable;
            return out_buffer[0..end_index];
        },
        else => @compileError("std.fs.selfExePath not supported for this target"),
    }
}

/// Same as `selfExePath` except the result is UTF16LE-encoded.
pub fn selfExePathW(out_buffer: *[os.windows.PATH_MAX_WIDE]u16) SelfExePathError![]u16 {
    return os.windows.GetModuleFileNameW(null, out_buffer, out_buffer.len);
}

/// `selfExeDirPath` except allocates the result on the heap.
/// Caller owns returned memory.
pub fn selfExeDirPathAlloc(allocator: *Allocator) ![]u8 {
    var buf: [MAX_PATH_BYTES]u8 = undefined;
    return mem.dupe(allocator, u8, try selfExeDirPath(&buf));
}

/// Get the directory path that contains the current executable.
/// Returned value is a slice of out_buffer.
pub fn selfExeDirPath(out_buffer: *[MAX_PATH_BYTES]u8) SelfExePathError![]const u8 {
    if (builtin.os == .linux) {
        // If the currently executing binary has been deleted,
        // the file path looks something like `/a/b/c/exe (deleted)`
        // This path cannot be opened, but it's valid for determining the directory
        // the executable was in when it was run.
        const full_exe_path = try os.readlinkC(c"/proc/self/exe", out_buffer);
        // Assume that /proc/self/exe has an absolute path, and therefore dirname
        // will not return null.
        return path.dirname(full_exe_path).?;
    }
    const self_exe_path = try selfExePath(out_buffer);
    // Assume that the OS APIs return absolute paths, and therefore dirname
    // will not return null.
    return path.dirname(self_exe_path).?;
}

/// `realpath`, except caller must free the returned memory.
pub fn realpathAlloc(allocator: *Allocator, pathname: []const u8) ![]u8 {
    var buf: [MAX_PATH_BYTES]u8 = undefined;
    return mem.dupe(allocator, u8, try os.realpath(pathname, &buf));
}

test "" {
    _ = @import("fs/path.zig");
    _ = @import("fs/file.zig");
    _ = @import("fs/get_app_data_dir.zig");
}
