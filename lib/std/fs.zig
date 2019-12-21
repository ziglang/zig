const builtin = @import("builtin");
const std = @import("std.zig");
const os = std.os;
const mem = std.mem;
const base64 = std.base64;
const crypto = std.crypto;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const math = std.math;

pub const path = @import("fs/path.zig");
pub const File = @import("fs/file.zig").File;

pub const symLink = os.symlink;
pub const symLinkC = os.symlinkC;
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
/// The byte count includes room for a null sentinel byte.
pub const MAX_PATH_BYTES = switch (builtin.os) {
    .linux, .macosx, .ios, .freebsd, .netbsd, .dragonfly => os.PATH_MAX,
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
        b64_fs_encoder.encode(tmp_path[dirname.len + 1 ..], &rand_buf);

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
    const my_cwd = cwd();

    var src_file = try my_cwd.openFile(source_path, .{});
    defer src_file.close();

    const src_stat = try src_file.stat();
    check_dest_stat: {
        const dest_stat = blk: {
            var dest_file = my_cwd.openFile(dest_path, .{}) catch |err| switch (err) {
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
    var in_file = try cwd().openFile(source_path, .{});
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
    var in_file = try cwd().openFile(source_path, .{});
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
        const tmp_path_slice = tmp_path_buf[0..tmp_path_len :0];

        const my_cwd = cwd();

        while (true) {
            try crypto.randomBytes(rand_buf[0..]);
            b64_fs_encoder.encode(tmp_path_slice[dirname_component_len..tmp_path_len], &rand_buf);

            const file = my_cwd.createFileC(
                tmp_path_slice, 
                .{ .mode = mode, .exclusive = true },
            ) catch |err| switch (err) {
                error.PathAlreadyExists => continue,
                else => |e| return e,
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
            cwd().deleteFileC(@ptrCast([*:0]u8, &self.tmp_path_buf)) catch {};
            self.finished = true;
        }
    }

    pub fn finish(self: *AtomicFile) !void {
        assert(!self.finished);
        self.file.close();
        self.finished = true;
        if (builtin.os == .windows) {
            const dest_path_w = try os.windows.sliceToPrefixedFileW(self.dest_path);
            const tmp_path_w = try os.windows.cStrToPrefixedFileW(@ptrCast([*:0]u8, &self.tmp_path_buf));
            return os.renameW(&tmp_path_w, &dest_path_w);
        }
        const dest_path_c = try os.toPosixPath(self.dest_path);
        return os.renameC(@ptrCast([*:0]u8, &self.tmp_path_buf), &dest_path_c);
    }
};

const default_new_dir_mode = 0o755;

/// Create a new directory.
pub fn makeDir(dir_path: []const u8) !void {
    return os.mkdir(dir_path, default_new_dir_mode);
}

/// Same as `makeDir` except the parameter is a null-terminated UTF8-encoded string.
pub fn makeDirC(dir_path: [*:0]const u8) !void {
    return os.mkdirC(dir_path, default_new_dir_mode);
}

/// Same as `makeDir` except the parameter is a null-terminated UTF16LE-encoded string.
pub fn makeDirW(dir_path: [*:0]const u16) !void {
    return os.mkdirW(dir_path, default_new_dir_mode);
}

/// Calls makeDir recursively to make an entire path. Returns success if the path
/// already exists and is a directory.
/// This function is not atomic, and if it returns an error, the file system may
/// have been modified regardless.
/// TODO determine if we can remove the allocator requirement from this function
pub fn makePath(allocator: *Allocator, full_path: []const u8) !void {
    const resolved_path = try path.resolve(allocator, &[_][]const u8{full_path});
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
pub fn deleteDirC(dir_path: [*:0]const u8) !void {
    return os.rmdirC(dir_path);
}

/// Same as `deleteDir` except the parameter is a null-terminated UTF16LE-encoded string.
pub fn deleteDirW(dir_path: [*:0]const u16) !void {
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

        var dir = try cwd().openDirList(dirname);
        defer dir.close();

        return dir.deleteTree(path.basename(full_path));
    } else {
        return cwd().deleteTree(full_path);
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
        .macosx, .ios, .freebsd, .netbsd, .dragonfly => struct {
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
                    .freebsd, .netbsd, .dragonfly => return self.nextBsd(),
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
                    const next_index = self.index + darwin_entry.reclen();
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
                    const next_index = self.index + freebsd_entry.reclen();
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
                    const next_index = self.index + linux_entry.reclen();
                    self.index = next_index;

                    const name = mem.toSlice(u8, @ptrCast([*:0]u8, &linux_entry.d_name));

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
                            if (self.first) @as(w.BOOLEAN, w.TRUE) else @as(w.BOOLEAN, w.FALSE),
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

                    if (mem.eql(u16, name_utf16le, &[_]u16{'.'}) or mem.eql(u16, name_utf16le, &[_]u16{ '.', '.' }))
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
            .macosx, .ios, .freebsd, .netbsd, .dragonfly => return Iterator{
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

    /// Deprecated; call `cwd().openDirList` directly.
    pub fn open(dir_path: []const u8) OpenError!Dir {
        return cwd().openDirList(dir_path);
    }

    /// Deprecated; call `cwd().openDirListC` directly.
    pub fn openC(dir_path_c: [*:0]const u8) OpenError!Dir {
        return cwd().openDirListC(dir_path_c);
    }

    pub fn close(self: *Dir) void {
        os.close(self.fd);
        self.* = undefined;
    }

    /// Opens a file for reading or writing, without attempting to create a new file.
    /// Call `File.close` to release the resource.
    /// Asserts that the path parameter has no null bytes.
    pub fn openFile(self: Dir, sub_path: []const u8, flags: File.OpenFlags) File.OpenError!File {
        if (std.debug.runtime_safety) for (sub_path) |byte| assert(byte != 0);
        if (builtin.os == .windows) {
            const path_w = try os.windows.sliceToPrefixedFileW(sub_path);
            return self.openFileW(&path_w, flags);
        }
        const path_c = try os.toPosixPath(sub_path);
        return self.openFileC(&path_c, flags);
    }

    /// Same as `openFile` but the path parameter is null-terminated.
    pub fn openFileC(self: Dir, sub_path: [*:0]const u8, flags: File.OpenFlags) File.OpenError!File {
        if (builtin.os == .windows) {
            const path_w = try os.windows.cStrToPrefixedFileW(sub_path);
            return self.openFileW(&path_w, flags);
        }
        const O_LARGEFILE = if (@hasDecl(os, "O_LARGEFILE")) os.O_LARGEFILE else 0;
        const os_flags = O_LARGEFILE | os.O_CLOEXEC | if (flags.write and flags.read)
            @as(u32, os.O_RDWR)
        else if (flags.write)
            @as(u32, os.O_WRONLY)
        else
            @as(u32, os.O_RDONLY);
        const fd = try os.openatC(self.fd, sub_path, os_flags, 0);
        return File{ .handle = fd };
    }

    /// Same as `openFile` but Windows-only and the path parameter is
    /// [WTF-16](https://simonsapin.github.io/wtf-8/#potentially-ill-formed-utf-16) encoded.
    pub fn openFileW(self: Dir, sub_path_w: [*:0]const u16, flags: File.OpenFlags) File.OpenError!File {
        const w = os.windows;
        const access_mask = w.SYNCHRONIZE |
            (if (flags.read) @as(u32, w.GENERIC_READ) else 0) |
            (if (flags.write) @as(u32, w.GENERIC_WRITE) else 0);
        return self.openFileWindows(sub_path_w, access_mask, w.FILE_OPEN);
    }

    /// Creates, opens, or overwrites a file with write access.
    /// Call `File.close` on the result when done.
    /// Asserts that the path parameter has no null bytes.
    pub fn createFile(self: Dir, sub_path: []const u8, flags: File.CreateFlags) File.OpenError!File {
        if (std.debug.runtime_safety) for (sub_path) |byte| assert(byte != 0);
        if (builtin.os == .windows) {
            const path_w = try os.windows.sliceToPrefixedFileW(sub_path);
            return self.createFileW(&path_w, flags);
        }
        const path_c = try os.toPosixPath(sub_path);
        return self.createFileC(&path_c, flags);
    }

    /// Same as `createFile` but the path parameter is null-terminated.
    pub fn createFileC(self: Dir, sub_path_c: [*:0]const u8, flags: File.CreateFlags) File.OpenError!File {
        if (builtin.os == .windows) {
            const path_w = try os.windows.cStrToPrefixedFileW(sub_path_c);
            return self.createFileW(&path_w, flags);
        }
        const O_LARGEFILE = if (@hasDecl(os, "O_LARGEFILE")) os.O_LARGEFILE else 0;
        const os_flags = O_LARGEFILE | os.O_CREAT | os.O_CLOEXEC |
            (if (flags.truncate) @as(u32, os.O_TRUNC) else 0) |
            (if (flags.read) @as(u32, os.O_RDWR) else os.O_WRONLY) |
            (if (flags.exclusive) @as(u32, os.O_EXCL) else 0);
        const fd = try os.openatC(self.fd, sub_path_c, os_flags, flags.mode);
        return File{ .handle = fd };
    }

    /// Same as `createFile` but Windows-only and the path parameter is
    /// [WTF-16](https://simonsapin.github.io/wtf-8/#potentially-ill-formed-utf-16) encoded.
    pub fn createFileW(self: Dir, sub_path_w: [*:0]const u16, flags: File.CreateFlags) File.OpenError!File {
        const w = os.windows;
        const access_mask = w.SYNCHRONIZE | w.GENERIC_WRITE |
            (if (flags.read) @as(u32, w.GENERIC_READ) else 0);
        const creation = if (flags.exclusive)
            @as(u32, w.FILE_CREATE)
        else if (flags.truncate)
            @as(u32, w.FILE_OVERWRITE_IF)
        else
            @as(u32, w.FILE_OPEN_IF);
        return self.openFileWindows(sub_path_w, access_mask, creation);
    }

    /// Deprecated; call `openFile` directly.
    pub fn openRead(self: Dir, sub_path: []const u8) File.OpenError!File {
        return self.openFile(sub_path, .{});
    }

    /// Deprecated; call `openFileC` directly.
    pub fn openReadC(self: Dir, sub_path: [*:0]const u8) File.OpenError!File {
        return self.openFileC(sub_path, .{});
    }

    /// Deprecated; call `openFileW` directly.
    pub fn openReadW(self: Dir, sub_path: [*:0]const u16) File.OpenError!File {
        return self.openFileW(sub_path, .{});
    }

    pub fn openFileWindows(
        self: Dir,
        sub_path_w: [*:0]const u16,
        access_mask: os.windows.ACCESS_MASK,
        creation: os.windows.ULONG,
    ) File.OpenError!File {
        const w = os.windows;

        var result = File{ .handle = undefined };

        const path_len_bytes = math.cast(u16, mem.toSliceConst(u16, sub_path_w).len * 2) catch |err| switch (err) {
            error.Overflow => return error.NameTooLong,
        };
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
            return error.IsDir;
        }
        if (sub_path_w[0] == '.' and sub_path_w[1] == '.' and sub_path_w[2] == 0) {
            return error.IsDir;
        }
        var io: w.IO_STATUS_BLOCK = undefined;
        const rc = w.ntdll.NtCreateFile(
            &result.handle,
            access_mask,
            &attr,
            &io,
            null,
            w.FILE_ATTRIBUTE_NORMAL,
            w.FILE_SHARE_WRITE | w.FILE_SHARE_READ | w.FILE_SHARE_DELETE,
            creation,
            w.FILE_NON_DIRECTORY_FILE | w.FILE_SYNCHRONOUS_IO_NONALERT,
            null,
            0,
        );
        switch (rc) {
            w.STATUS.SUCCESS => return result,
            w.STATUS.OBJECT_NAME_INVALID => unreachable,
            w.STATUS.OBJECT_NAME_NOT_FOUND => return error.FileNotFound,
            w.STATUS.OBJECT_PATH_NOT_FOUND => return error.FileNotFound,
            w.STATUS.INVALID_PARAMETER => unreachable,
            w.STATUS.SHARING_VIOLATION => return error.SharingViolation,
            w.STATUS.ACCESS_DENIED => return error.AccessDenied,
            w.STATUS.PIPE_BUSY => return error.PipeBusy,
            w.STATUS.OBJECT_PATH_SYNTAX_BAD => unreachable,
            w.STATUS.OBJECT_NAME_COLLISION => return error.PathAlreadyExists,
            else => return w.unexpectedStatus(rc),
        }
    }

    /// Deprecated; call `openDirList` directly.
    pub fn openDir(self: Dir, sub_path: []const u8) OpenError!Dir {
        return self.openDirList(sub_path);
    }

    /// Deprecated; call `openDirListC` directly.
    pub fn openDirC(self: Dir, sub_path_c: [*:0]const u8) OpenError!Dir {
        return self.openDirListC(sub_path_c);
    }

    /// Opens a directory at the given path with the ability to access subpaths
    /// of the result. Calling `iterate` on the result is illegal behavior; to
    /// list the contents of a directory, open it with `openDirList`.
    ///
    /// Call `close` on the result when done.
    ///
    /// Asserts that the path parameter has no null bytes.
    pub fn openDirTraverse(self: Dir, sub_path: []const u8) OpenError!Dir {
        if (std.debug.runtime_safety) for (sub_path) |byte| assert(byte != 0);
        if (builtin.os == .windows) {
            const sub_path_w = try os.windows.sliceToPrefixedFileW(sub_path);
            return self.openDirTraverseW(&sub_path_w);
        }

        const sub_path_c = try os.toPosixPath(sub_path);
        return self.openDirTraverseC(&sub_path_c);
    }

    /// Opens a directory at the given path with the ability to access subpaths and list contents
    /// of the result. If the ability to list contents is unneeded, `openDirTraverse` acts the
    /// same and may be more efficient.
    ///
    /// Call `close` on the result when done.
    ///
    /// Asserts that the path parameter has no null bytes.
    pub fn openDirList(self: Dir, sub_path: []const u8) OpenError!Dir {
        if (std.debug.runtime_safety) for (sub_path) |byte| assert(byte != 0);
        if (builtin.os == .windows) {
            const sub_path_w = try os.windows.sliceToPrefixedFileW(sub_path);
            return self.openDirListW(&sub_path_w);
        }

        const sub_path_c = try os.toPosixPath(sub_path);
        return self.openDirListC(&sub_path_c);
    }

    /// Same as `openDirTraverse` except the parameter is null-terminated.
    pub fn openDirTraverseC(self: Dir, sub_path_c: [*:0]const u8) OpenError!Dir {
        if (builtin.os == .windows) {
            const sub_path_w = try os.windows.cStrToPrefixedFileW(sub_path_c);
            return self.openDirTraverseW(&sub_path_w);
        } else {
            const O_PATH = if (@hasDecl(os, "O_PATH")) os.O_PATH else 0;
            return self.openDirFlagsC(sub_path_c, os.O_RDONLY | os.O_CLOEXEC | O_PATH);
        }
    }

    /// Same as `openDirList` except the parameter is null-terminated.
    pub fn openDirListC(self: Dir, sub_path_c: [*:0]const u8) OpenError!Dir {
        if (builtin.os == .windows) {
            const sub_path_w = try os.windows.cStrToPrefixedFileW(sub_path_c);
            return self.openDirListW(&sub_path_w);
        } else {
            return self.openDirFlagsC(sub_path_c, os.O_RDONLY | os.O_CLOEXEC);
        }
    }

    fn openDirFlagsC(self: Dir, sub_path_c: [*:0]const u8, flags: u32) OpenError!Dir {
        const fd = os.openatC(self.fd, sub_path_c, flags | os.O_DIRECTORY, 0) catch |err| switch (err) {
            error.FileTooBig => unreachable, // can't happen for directories
            error.IsDir => unreachable, // we're providing O_DIRECTORY
            error.NoSpaceLeft => unreachable, // not providing O_CREAT
            error.PathAlreadyExists => unreachable, // not providing O_CREAT
            else => |e| return e,
        };
        return Dir{ .fd = fd };
    }

    /// Same as `openDirTraverse` except the path parameter is UTF16LE, NT-prefixed.
    /// This function is Windows-only.
    pub fn openDirTraverseW(self: Dir, sub_path_w: [*:0]const u16) OpenError!Dir {
        const w = os.windows;

        return self.openDirAccessMaskW(sub_path_w, w.STANDARD_RIGHTS_READ | w.FILE_READ_ATTRIBUTES | w.FILE_READ_EA | w.SYNCHRONIZE | w.FILE_TRAVERSE);
    }

    /// Same as `openDirList` except the path parameter is UTF16LE, NT-prefixed.
    /// This function is Windows-only.
    pub fn openDirListW(self: Dir, sub_path_w: [*:0]const u16) OpenError!Dir {
        const w = os.windows;

        return self.openDirAccessMaskW(sub_path_w, w.STANDARD_RIGHTS_READ | w.FILE_READ_ATTRIBUTES | w.FILE_READ_EA | w.SYNCHRONIZE | w.FILE_TRAVERSE | w.FILE_LIST_DIRECTORY);
    }

    fn openDirAccessMaskW(self: Dir, sub_path_w: [*:0]const u16, access_mask: u32) OpenError!Dir {
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
            access_mask,
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
    /// Asserts that the path parameter has no null bytes.
    pub fn deleteFile(self: Dir, sub_path: []const u8) DeleteFileError!void {
        os.unlinkat(self.fd, sub_path, 0) catch |err| switch (err) {
            error.DirNotEmpty => unreachable, // not passing AT_REMOVEDIR
            else => |e| return e,
        };
    }

    /// Same as `deleteFile` except the parameter is null-terminated.
    pub fn deleteFileC(self: Dir, sub_path_c: [*:0]const u8) DeleteFileError!void {
        os.unlinkatC(self.fd, sub_path_c, 0) catch |err| switch (err) {
            error.DirNotEmpty => unreachable, // not passing AT_REMOVEDIR
            else => |e| return e,
        };
    }

    /// Same as `deleteFile` except the parameter is WTF-16 encoded.
    pub fn deleteFileW(self: Dir, sub_path_w: [*:0]const u16) DeleteFileError!void {
        os.unlinkatW(self.fd, sub_path_w, 0) catch |err| switch (err) {
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
    /// Asserts that the path parameter has no null bytes.
    pub fn deleteDir(self: Dir, sub_path: []const u8) DeleteDirError!void {
        if (std.debug.runtime_safety) for (sub_path) |byte| assert(byte != 0);
        if (builtin.os == .windows) {
            const sub_path_w = try os.windows.sliceToPrefixedFileW(sub_path);
            return self.deleteDirW(&sub_path_w);
        }
        const sub_path_c = try os.toPosixPath(sub_path);
        return self.deleteDirC(&sub_path_c);
    }

    /// Same as `deleteDir` except the parameter is null-terminated.
    pub fn deleteDirC(self: Dir, sub_path_c: [*:0]const u8) DeleteDirError!void {
        os.unlinkatC(self.fd, sub_path_c, os.AT_REMOVEDIR) catch |err| switch (err) {
            error.IsDir => unreachable, // not possible since we pass AT_REMOVEDIR
            else => |e| return e,
        };
    }

    /// Same as `deleteDir` except the parameter is UTF16LE, NT prefixed.
    /// This function is Windows-only.
    pub fn deleteDirW(self: Dir, sub_path_w: [*:0]const u16) DeleteDirError!void {
        os.unlinkatW(self.fd, sub_path_w, os.AT_REMOVEDIR) catch |err| switch (err) {
            error.IsDir => unreachable, // not possible since we pass AT_REMOVEDIR
            else => |e| return e,
        };
    }

    /// Read value of a symbolic link.
    /// The return value is a slice of `buffer`, from index `0`.
    /// Asserts that the path parameter has no null bytes.
    pub fn readLink(self: Dir, sub_path: []const u8, buffer: *[MAX_PATH_BYTES]u8) ![]u8 {
        if (std.debug.runtime_safety) for (sub_path) |byte| assert(byte != 0);
        const sub_path_c = try os.toPosixPath(sub_path);
        return self.readLinkC(&sub_path_c, buffer);
    }

    /// Same as `readLink`, except the `pathname` parameter is null-terminated.
    pub fn readLinkC(self: Dir, sub_path_c: [*:0]const u8, buffer: *[MAX_PATH_BYTES]u8) ![]u8 {
        return os.readlinkatC(self.fd, sub_path_c, buffer);
    }

    /// On success, caller owns returned buffer.
    /// If the file is larger than `max_bytes`, returns `error.FileTooBig`.
    pub fn readFileAlloc(self: Dir, allocator: *mem.Allocator, file_path: []const u8, max_bytes: usize) ![]u8 {
        return self.readFileAllocAligned(allocator, file_path, max_bytes, @alignOf(u8));
    }

    /// On success, caller owns returned buffer.
    /// If the file is larger than `max_bytes`, returns `error.FileTooBig`.
    pub fn readFileAllocAligned(
        self: Dir,
        allocator: *mem.Allocator,
        file_path: []const u8,
        max_bytes: usize,
        comptime A: u29,
    ) ![]align(A) u8 {
        var file = try self.openRead(file_path);
        defer file.close();

        const size = math.cast(usize, try file.getEndPos()) catch math.maxInt(usize);
        if (size > max_bytes) return error.FileTooBig;

        const buf = try allocator.alignedAlloc(u8, A, size);
        errdefer allocator.free(buf);

        try file.inStream().stream.readNoEof(buf);
        return buf;
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
            var dir = self.openDirList(sub_path) catch |err| switch (err) {
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

                    const new_dir = dir.openDirList(entry.name) catch |err| switch (err) {
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

    /// Writes content to the file system, creating a new file if it does not exist, truncating
    /// if it already exists.
    pub fn writeFile(self: Dir, sub_path: []const u8, data: []const u8) !void {
        var file = try self.createFile(sub_path, .{});
        defer file.close();
        try file.write(data);
    }
};

/// Returns an handle to the current working directory that is open for traversal.
/// Closing the returned `Dir` is checked illegal behavior. Iterating over the result is illegal behavior.
/// On POSIX targets, this function is comptime-callable.
pub fn cwd() Dir {
    if (builtin.os == .windows) {
        return Dir{ .fd = os.windows.peb().ProcessParameters.CurrentDirectory.Handle };
    } else {
        return Dir{ .fd = os.AT_FDCWD };
    }
}

/// Opens a file for reading or writing, without attempting to create a new file, based on an absolute path.
/// Call `File.close` to release the resource.
/// Asserts that the path is absolute. See `Dir.openFile` for a function that
/// operates on both absolute and relative paths.
/// Asserts that the path parameter has no null bytes. See `openFileAbsoluteC` for a function
/// that accepts a null-terminated path.
pub fn openFileAbsolute(absolute_path: []const u8, flags: File.OpenFlags) File.OpenError!File {
    assert(path.isAbsolute(absolute_path));
    return cwd().openFile(absolute_path, flags);
}

/// Same as `openFileAbsolute` but the path parameter is null-terminated.
pub fn openFileAbsoluteC(absolute_path_c: [*:0]const u8, flags: File.OpenFlags) File.OpenError!File {
    assert(path.isAbsoluteC(absolute_path_c));
    return cwd().openFileC(absolute_path_c, flags);
}

/// Same as `openFileAbsolute` but the path parameter is WTF-16 encoded.
pub fn openFileAbsoluteW(absolute_path_w: [*:0]const u16, flags: File.OpenFlags) File.OpenError!File {
    assert(path.isAbsoluteW(absolute_path_w));
    return cwd().openFileW(absolute_path_w, flags);
}

/// Creates, opens, or overwrites a file with write access, based on an absolute path.
/// Call `File.close` to release the resource.
/// Asserts that the path is absolute. See `Dir.createFile` for a function that
/// operates on both absolute and relative paths.
/// Asserts that the path parameter has no null bytes. See `createFileAbsoluteC` for a function
/// that accepts a null-terminated path.
pub fn createFileAbsolute(absolute_path: []const u8, flags: File.CreateFlags) File.OpenError!File {
    assert(path.isAbsolute(absolute_path));
    return cwd().createFile(absolute_path, flags);
}

/// Same as `createFileAbsolute` but the path parameter is null-terminated.
pub fn createFileAbsoluteC(absolute_path_c: [*:0]const u8, flags: File.CreateFlags) File.OpenError!File {
    assert(path.isAbsoluteC(absolute_path_c));
    return cwd().createFileC(absolute_path_c, flags);
}

/// Same as `createFileAbsolute` but the path parameter is WTF-16 encoded.
pub fn createFileAbsoluteW(absolute_path_w: [*:0]const u16, flags: File.CreateFlags) File.OpenError!File {
    assert(path.isAbsoluteW(absolute_path_w));
    return cwd().createFileW(absolute_path_w, flags);
}

/// Delete a file name and possibly the file it refers to, based on an absolute path.
/// Asserts that the path is absolute. See `Dir.deleteFile` for a function that
/// operates on both absolute and relative paths.
/// Asserts that the path parameter has no null bytes.
pub fn deleteFileAbsolute(absolute_path: []const u8) DeleteFileError!void {
    assert(path.isAbsolute(absolute_path));
    return cwd().deleteFile(absolute_path);
}

/// Same as `deleteFileAbsolute` except the parameter is null-terminated.
pub fn deleteFileAbsoluteC(absolute_path_c: [*:0]const u8) DeleteFileError!void {
    assert(path.isAbsoluteC(absolute_path_c));
    return cwd().deleteFileC(absolute_path_c);
}

/// Same as `deleteFileAbsolute` except the parameter is WTF-16 encoded.
pub fn deleteFileAbsoluteW(absolute_path_w: [*:0]const u16) DeleteFileError!void {
    assert(path.isAbsoluteW(absolute_path_w));
    return cwd().deleteFileW(absolute_path_w);
}

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
                    var new_dir = top.dir_it.dir.openDirList(base.name) catch |err| switch (err) {
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
        while (self.stack.popOrNull()) |*item| item.dir_it.dir.close();
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

    var dir = try cwd().openDirList(dir_path);
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
        return openFileAbsoluteC("/proc/self/exe", .{});
    }
    if (builtin.os == .windows) {
        const wide_slice = selfExePathW();
        const prefixed_path_w = try os.windows.wToPrefixedFileW(wide_slice);
        return cwd().openReadW(&prefixed_path_w);
    }
    var buf: [MAX_PATH_BYTES]u8 = undefined;
    const self_exe_path = try selfExePath(&buf);
    buf[self_exe_path.len] = 0;
    return openFileAbsoluteC(self_exe_path[0..self_exe_path.len :0].ptr, .{});
}

test "openSelfExe" {
    switch (builtin.os) {
        .linux, .macosx, .ios, .windows, .freebsd, .dragonfly => (try openSelfExe()).close(),
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
        return mem.toSlice(u8, @ptrCast([*:0]u8, out_buffer));
    }
    switch (builtin.os) {
        .linux => return os.readlinkC("/proc/self/exe", out_buffer),
        .freebsd, .dragonfly => {
            var mib = [4]c_int{ os.CTL_KERN, os.KERN_PROC, os.KERN_PROC_PATHNAME, -1 };
            var out_len: usize = out_buffer.len;
            try os.sysctl(&mib, out_buffer, &out_len, null, 0);
            // TODO could this slice from 0 to out_len instead?
            return mem.toSlice(u8, @ptrCast([*:0]u8, out_buffer));
        },
        .netbsd => {
            var mib = [4]c_int{ os.CTL_KERN, os.KERN_PROC_ARGS, -1, os.KERN_PROC_PATHNAME };
            var out_len: usize = out_buffer.len;
            try os.sysctl(&mib, out_buffer, &out_len, null, 0);
            // TODO could this slice from 0 to out_len instead?
            return mem.toSlice(u8, @ptrCast([*:0]u8, out_buffer));
        },
        .windows => {
            const utf16le_slice = selfExePathW();
            // Trust that Windows gives us valid UTF-16LE.
            const end_index = std.unicode.utf16leToUtf8(out_buffer, utf16le_slice) catch unreachable;
            return out_buffer[0..end_index];
        },
        else => @compileError("std.fs.selfExePath not supported for this target"),
    }
}

/// The result is UTF16LE-encoded.
pub fn selfExePathW() [:0]const u16 {
    const image_path_name = &os.windows.peb().ProcessParameters.ImagePathName;
    return mem.toSliceConst(u16, @ptrCast([*:0]const u16, image_path_name.Buffer));
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
        const full_exe_path = try os.readlinkC("/proc/self/exe", out_buffer);
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
