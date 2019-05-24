const std = @import("std.zig");
const os = std.os;
const mem = std.mem;

pub const path = @import("fs/path.zig");
pub const File = @import("fs/file.zig").File;

pub const symLink = os.symlink;
pub const symLinkC = os.symlinkC;
pub const deleteFile = os.unlink;
pub const deleteFileC = os.unlinkC;
pub const rename = os.rename;
pub const renameC = os.renameC;
pub const changeCurDir = os.chdir;
pub const changeCurDirC = os.chdirC;
pub const realpath = os.realpath;
pub const realpathC = os.realpathC;
pub const realpathW = os.realpathW;

pub const getAppDataDir = @import("fs/get_app_data_dir.zig").getAppDataDir;
pub const GetAppDataDirError = @import("fs/get_app_data_dir.zig").GetAppDataDirError;

/// This represents the maximum size of a UTF-8 encoded file path.
/// All file system operations which return a path are guaranteed to
/// fit into a UTF-8 encoded array of this length.
/// path being too long if it is this 0long
pub const MAX_PATH_BYTES = switch (builtin.os) {
    .linux, .macosx, .ios, .freebsd, .netbsd => posix.PATH_MAX,
    // Each UTF-16LE character may be expanded to 3 UTF-8 bytes.
    // If it would require 4 UTF-8 bytes, then there would be a surrogate
    // pair in the UTF-16LE, and we (over)account 3 bytes for it that way.
    // +1 for the null byte at the end, which can be encoded in 1 byte.
    .windows => posix.PATH_MAX_WIDE * 3 + 1,
    else => @compileError("Unsupported OS"),
};

/// The result is a slice of `out_buffer`, from index `0`.
pub fn getCwd(out_buffer: *[MAX_PATH_BYTES]u8) ![]u8 {
    return posix.getcwd(out_buffer);
}

/// Caller must free the returned memory.
pub fn getCwdAlloc(allocator: *Allocator) ![]u8 {
    var buf: [MAX_PATH_BYTES]u8 = undefined;
    return mem.dupe(allocator, u8, try posix.getcwd(&buf));
}

test "getCwdAlloc" {
    // at least call it so it gets compiled
    var buf: [1000]u8 = undefined;
    const allocator = &std.heap.FixedBufferAllocator.init(&buf).allocator;
    _ = getCwdAlloc(allocator) catch {};
}

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

    const dirname = os.path.dirname(new_path) orelse ".";

    var rand_buf: [12]u8 = undefined;
    const tmp_path = try allocator.alloc(u8, dirname.len + 1 + base64.Base64Encoder.calcSize(rand_buf.len));
    defer allocator.free(tmp_path);
    mem.copy(u8, tmp_path[0..], dirname);
    tmp_path[dirname.len] = os.path.sep;
    while (true) {
        try getRandomBytes(rand_buf[0..]);
        b64_fs_encoder.encode(tmp_path[dirname.len + 1 ..], rand_buf);

        if (symLink(existing_path, tmp_path)) {
            return rename(tmp_path, new_path);
        } else |err| switch (err) {
            error.PathAlreadyExists => continue,
            else => return err, // TODO zig should know this set does not include PathAlreadyExists
        }
    }
}

/// Guaranteed to be atomic. However until https://patchwork.kernel.org/patch/9636735/ is
/// merged and readily available,
/// there is a possibility of power loss or application termination leaving temporary files present
/// in the same directory as dest_path.
/// Destination file will have the same mode as the source file.
pub fn copyFile(source_path: []const u8, dest_path: []const u8) !void {
    var in_file = try os.File.openRead(source_path);
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
    var in_file = try os.File.openRead(source_path);
    defer in_file.close();

    var atomic_file = try AtomicFile.init(dest_path, mode);
    defer atomic_file.deinit();

    var buf: [mem.page_size]u8 = undefined;
    while (true) {
        const amt = try in_file.read(buf[0..]);
        try atomic_file.file.write(buf[0..amt]);
        if (amt != buf.len) {
            return atomic_file.finish();
        }
    }
}

pub const AtomicFile = struct {
    file: os.File,
    tmp_path_buf: [MAX_PATH_BYTES]u8,
    dest_path: []const u8,
    finished: bool,

    const InitError = os.File.OpenError;

    /// dest_path must remain valid for the lifetime of AtomicFile
    /// call finish to atomically replace dest_path with contents
    /// TODO once we have null terminated pointers, use the
    /// openWriteNoClobberN function
    pub fn init(dest_path: []const u8, mode: File.Mode) InitError!AtomicFile {
        const dirname = os.path.dirname(dest_path);
        var rand_buf: [12]u8 = undefined;
        const dirname_component_len = if (dirname) |d| d.len + 1 else 0;
        const encoded_rand_len = comptime base64.Base64Encoder.calcSize(rand_buf.len);
        const tmp_path_len = dirname_component_len + encoded_rand_len;
        var tmp_path_buf: [MAX_PATH_BYTES]u8 = undefined;
        if (tmp_path_len >= tmp_path_buf.len) return error.NameTooLong;

        if (dirname) |dir| {
            mem.copy(u8, tmp_path_buf[0..], dir);
            tmp_path_buf[dir.len] = os.path.sep;
        }

        tmp_path_buf[tmp_path_len] = 0;

        while (true) {
            try getRandomBytes(rand_buf[0..]);
            b64_fs_encoder.encode(tmp_path_buf[dirname_component_len..tmp_path_len], rand_buf);

            const file = os.File.openWriteNoClobberC(&tmp_path_buf, mode) catch |err| switch (err) {
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
        if (is_posix) {
            const dest_path_c = try toPosixPath(self.dest_path);
            return renameC(&self.tmp_path_buf, &dest_path_c);
        } else if (is_windows) {
            const dest_path_w = try posix.sliceToPrefixedFileW(self.dest_path);
            const tmp_path_w = try posix.cStrToPrefixedFileW(&self.tmp_path_buf);
            return renameW(&tmp_path_w, &dest_path_w);
        } else {
            @compileError("Unsupported OS");
        }
    }
};

const default_new_dir_mode = 0o755;

/// Create a new directory.
pub fn makeDir(dir_path: []const u8) !void {
    return posix.mkdir(dir_path, default_new_dir_mode);
}

/// Same as `makeDir` except the parameter is a null-terminated UTF8-encoded string.
pub fn makeDirC(dir_path: [*]const u8) !void {
    return posix.mkdirC(dir_path, default_new_dir_mode);
}

/// Same as `makeDir` except the parameter is a null-terminated UTF16LE-encoded string.
pub fn makeDirW(dir_path: [*]const u16) !void {
    return posix.mkdirW(dir_path, default_new_dir_mode);
}

/// Calls makeDir recursively to make an entire path. Returns success if the path
/// already exists and is a directory.
/// This function is not atomic, and if it returns an error, the file system may
/// have been modified regardless.
/// TODO determine if we can remove the allocator requirement from this function
pub fn makePath(allocator: *Allocator, full_path: []const u8) !void {
    const resolved_path = try path.resolve(allocator, [][]const u8{full_path});
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
                    if (os.path.isSep(resolved_path[end_index])) break;
                }
                continue;
            },
            else => return err,
        };
        if (end_index == resolved_path.len) return;
        // march end_index forward until next path component
        while (true) {
            end_index += 1;
            if (end_index == resolved_path.len or os.path.isSep(resolved_path[end_index])) break;
        }
    }
}

/// Returns `error.DirNotEmpty` if the directory is not empty.
/// To delete a directory recursively, see `deleteTree`.
pub fn deleteDir(dir_path: []const u8) DeleteDirError!void {
    return posix.rmdir(dir_path);
}

/// Same as `deleteDir` except the parameter is a null-terminated UTF8-encoded string.
pub fn deleteDirC(dir_path: [*]const u8) DeleteDirError!void {
    return posix.rmdirC(dir_path);
}

/// Same as `deleteDir` except the parameter is a null-terminated UTF16LE-encoded string.
pub fn deleteDirW(dir_path: [*]const u16) DeleteDirError!void {
    return posix.rmdirW(dir_path);
}

/// Whether ::full_path describes a symlink, file, or directory, this function
/// removes it. If it cannot be removed because it is a non-empty directory,
/// this function recursively removes its entries and then tries again.
const DeleteTreeError = error{
    OutOfMemory,
    AccessDenied,
    FileTooBig,
    IsDir,
    SymLinkLoop,
    ProcessFdQuotaExceeded,
    NameTooLong,
    SystemFdQuotaExceeded,
    NoDevice,
    SystemResources,
    NoSpaceLeft,
    PathAlreadyExists,
    ReadOnlyFileSystem,
    NotDir,
    FileNotFound,
    FileSystem,
    FileBusy,
    DirNotEmpty,
    DeviceBusy,

    /// On Windows, file paths must be valid Unicode.
    InvalidUtf8,

    /// On Windows, file paths cannot contain these characters:
    /// '/', '*', '?', '"', '<', '>', '|'
    BadPathName,

    Unexpected,
};

/// TODO determine if we can remove the allocator requirement
pub fn deleteTree(allocator: *Allocator, full_path: []const u8) DeleteTreeError!void {
    start_over: while (true) {
        var got_access_denied = false;
        // First, try deleting the item as a file. This way we don't follow sym links.
        if (deleteFile(full_path)) {
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
            => return err,
        }
        {
            var dir = Dir.open(allocator, full_path) catch |err| switch (err) {
                error.NotDir => {
                    if (got_access_denied) {
                        return error.AccessDenied;
                    }
                    continue :start_over;
                },

                error.OutOfMemory,
                error.AccessDenied,
                error.FileTooBig,
                error.IsDir,
                error.SymLinkLoop,
                error.ProcessFdQuotaExceeded,
                error.NameTooLong,
                error.SystemFdQuotaExceeded,
                error.NoDevice,
                error.FileNotFound,
                error.SystemResources,
                error.NoSpaceLeft,
                error.PathAlreadyExists,
                error.Unexpected,
                error.InvalidUtf8,
                error.BadPathName,
                error.DeviceBusy,
                => return err,
            };
            defer dir.close();

            var full_entry_buf = ArrayList(u8).init(allocator);
            defer full_entry_buf.deinit();

            while (try dir.next()) |entry| {
                try full_entry_buf.resize(full_path.len + entry.name.len + 1);
                const full_entry_path = full_entry_buf.toSlice();
                mem.copy(u8, full_entry_path, full_path);
                full_entry_path[full_path.len] = path.sep;
                mem.copy(u8, full_entry_path[full_path.len + 1 ..], entry.name);

                try deleteTree(allocator, full_entry_path);
            }
        }
        return deleteDir(full_path);
    }
}

pub const Dir = struct {
    handle: Handle,
    allocator: *Allocator,

    pub const Handle = switch (builtin.os) {
        Os.macosx, Os.ios, Os.freebsd, Os.netbsd => struct {
            fd: i32,
            seek: i64,
            buf: []u8,
            index: usize,
            end_index: usize,
        },
        Os.linux => struct {
            fd: i32,
            buf: []u8,
            index: usize,
            end_index: usize,
        },
        Os.windows => struct {
            handle: windows.HANDLE,
            find_file_data: windows.WIN32_FIND_DATAW,
            first: bool,
            name_data: [256]u8,
        },
        else => @compileError("unimplemented"),
    };

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

    pub const OpenError = error{
        FileNotFound,
        NotDir,
        AccessDenied,
        FileTooBig,
        IsDir,
        SymLinkLoop,
        ProcessFdQuotaExceeded,
        NameTooLong,
        SystemFdQuotaExceeded,
        NoDevice,
        SystemResources,
        NoSpaceLeft,
        PathAlreadyExists,
        OutOfMemory,
        InvalidUtf8,
        BadPathName,
        DeviceBusy,

        Unexpected,
    };

    /// TODO remove the allocator requirement from this API
    pub fn open(allocator: *Allocator, dir_path: []const u8) OpenError!Dir {
        return Dir{
            .allocator = allocator,
            .handle = switch (builtin.os) {
                Os.windows => blk: {
                    var find_file_data: windows.WIN32_FIND_DATAW = undefined;
                    const handle = try windows_util.windowsFindFirstFile(dir_path, &find_file_data);
                    break :blk Handle{
                        .handle = handle,
                        .find_file_data = find_file_data, // TODO guaranteed copy elision
                        .first = true,
                        .name_data = undefined,
                    };
                },
                Os.macosx, Os.ios, Os.freebsd, Os.netbsd => Handle{
                    .fd = try posixOpen(
                        dir_path,
                        posix.O_RDONLY | posix.O_NONBLOCK | posix.O_DIRECTORY | posix.O_CLOEXEC,
                        0,
                    ),
                    .seek = 0,
                    .index = 0,
                    .end_index = 0,
                    .buf = []u8{},
                },
                Os.linux => Handle{
                    .fd = try posixOpen(
                        dir_path,
                        posix.O_RDONLY | posix.O_DIRECTORY | posix.O_CLOEXEC,
                        0,
                    ),
                    .index = 0,
                    .end_index = 0,
                    .buf = []u8{},
                },
                else => @compileError("unimplemented"),
            },
        };
    }

    pub fn close(self: *Dir) void {
        switch (builtin.os) {
            Os.windows => {
                _ = windows.FindClose(self.handle.handle);
            },
            Os.macosx, Os.ios, Os.linux, Os.freebsd, Os.netbsd => {
                self.allocator.free(self.handle.buf);
                os.close(self.handle.fd);
            },
            else => @compileError("unimplemented"),
        }
    }

    /// Memory such as file names referenced in this returned entry becomes invalid
    /// with subsequent calls to next, as well as when this `Dir` is deinitialized.
    pub fn next(self: *Dir) !?Entry {
        switch (builtin.os) {
            Os.linux => return self.nextLinux(),
            Os.macosx, Os.ios => return self.nextDarwin(),
            Os.windows => return self.nextWindows(),
            Os.freebsd => return self.nextFreebsd(),
            Os.netbsd => return self.nextFreebsd(),
            else => @compileError("unimplemented"),
        }
    }

    fn nextDarwin(self: *Dir) !?Entry {
        start_over: while (true) {
            if (self.handle.index >= self.handle.end_index) {
                if (self.handle.buf.len == 0) {
                    self.handle.buf = try self.allocator.alloc(u8, mem.page_size);
                }

                while (true) {
                    const result = system.__getdirentries64(self.handle.fd, self.handle.buf.ptr, self.handle.buf.len, &self.handle.seek);
                    if (result == 0) return null;
                    if (result < 0) {
                        switch (system.getErrno(result)) {
                            posix.EBADF => unreachable,
                            posix.EFAULT => unreachable,
                            posix.ENOTDIR => unreachable,
                            posix.EINVAL => {
                                self.handle.buf = try self.allocator.realloc(self.handle.buf, self.handle.buf.len * 2);
                                continue;
                            },
                            else => return unexpectedErrorPosix(err),
                        }
                    }
                    self.handle.index = 0;
                    self.handle.end_index = @intCast(usize, result);
                    break;
                }
            }
            const darwin_entry = @ptrCast(*align(1) posix.dirent, &self.handle.buf[self.handle.index]);
            const next_index = self.handle.index + darwin_entry.d_reclen;
            self.handle.index = next_index;

            const name = @ptrCast([*]u8, &darwin_entry.d_name)[0..darwin_entry.d_namlen];

            if (mem.eql(u8, name, ".") or mem.eql(u8, name, "..")) {
                continue :start_over;
            }

            const entry_kind = switch (darwin_entry.d_type) {
                posix.DT_BLK => Entry.Kind.BlockDevice,
                posix.DT_CHR => Entry.Kind.CharacterDevice,
                posix.DT_DIR => Entry.Kind.Directory,
                posix.DT_FIFO => Entry.Kind.NamedPipe,
                posix.DT_LNK => Entry.Kind.SymLink,
                posix.DT_REG => Entry.Kind.File,
                posix.DT_SOCK => Entry.Kind.UnixDomainSocket,
                posix.DT_WHT => Entry.Kind.Whiteout,
                else => Entry.Kind.Unknown,
            };
            return Entry{
                .name = name,
                .kind = entry_kind,
            };
        }
    }

    fn nextWindows(self: *Dir) !?Entry {
        while (true) {
            if (self.handle.first) {
                self.handle.first = false;
            } else {
                if (!try posix.FindNextFile(self.handle.handle, &self.handle.find_file_data))
                    return null;
            }
            const name_utf16le = mem.toSlice(u16, self.handle.find_file_data.cFileName[0..].ptr);
            if (mem.eql(u16, name_utf16le, []u16{'.'}) or mem.eql(u16, name_utf16le, []u16{ '.', '.' }))
                continue;
            // Trust that Windows gives us valid UTF-16LE
            const name_utf8_len = std.unicode.utf16leToUtf8(self.handle.name_data[0..], name_utf16le) catch unreachable;
            const name_utf8 = self.handle.name_data[0..name_utf8_len];
            const kind = blk: {
                const attrs = self.handle.find_file_data.dwFileAttributes;
                if (attrs & windows.FILE_ATTRIBUTE_DIRECTORY != 0) break :blk Entry.Kind.Directory;
                if (attrs & windows.FILE_ATTRIBUTE_REPARSE_POINT != 0) break :blk Entry.Kind.SymLink;
                if (attrs & windows.FILE_ATTRIBUTE_NORMAL != 0) break :blk Entry.Kind.File;
                break :blk Entry.Kind.Unknown;
            };
            return Entry{
                .name = name_utf8,
                .kind = kind,
            };
        }
    }

    fn nextLinux(self: *Dir) !?Entry {
        start_over: while (true) {
            if (self.handle.index >= self.handle.end_index) {
                if (self.handle.buf.len == 0) {
                    self.handle.buf = try self.allocator.alloc(u8, mem.page_size);
                }

                while (true) {
                    const result = posix.getdents64(self.handle.fd, self.handle.buf.ptr, self.handle.buf.len);
                    const err = posix.getErrno(result);
                    if (err > 0) {
                        switch (err) {
                            posix.EBADF, posix.EFAULT, posix.ENOTDIR => unreachable,
                            posix.EINVAL => {
                                self.handle.buf = try self.allocator.realloc(self.handle.buf, self.handle.buf.len * 2);
                                continue;
                            },
                            else => return unexpectedErrorPosix(err),
                        }
                    }
                    if (result == 0) return null;
                    self.handle.index = 0;
                    self.handle.end_index = result;
                    break;
                }
            }
            const linux_entry = @ptrCast(*align(1) posix.dirent64, &self.handle.buf[self.handle.index]);
            const next_index = self.handle.index + linux_entry.d_reclen;
            self.handle.index = next_index;

            const name = cstr.toSlice(@ptrCast([*]u8, &linux_entry.d_name));

            // skip . and .. entries
            if (mem.eql(u8, name, ".") or mem.eql(u8, name, "..")) {
                continue :start_over;
            }

            const entry_kind = switch (linux_entry.d_type) {
                posix.DT_BLK => Entry.Kind.BlockDevice,
                posix.DT_CHR => Entry.Kind.CharacterDevice,
                posix.DT_DIR => Entry.Kind.Directory,
                posix.DT_FIFO => Entry.Kind.NamedPipe,
                posix.DT_LNK => Entry.Kind.SymLink,
                posix.DT_REG => Entry.Kind.File,
                posix.DT_SOCK => Entry.Kind.UnixDomainSocket,
                else => Entry.Kind.Unknown,
            };
            return Entry{
                .name = name,
                .kind = entry_kind,
            };
        }
    }

    fn nextFreebsd(self: *Dir) !?Entry {
        start_over: while (true) {
            if (self.handle.index >= self.handle.end_index) {
                if (self.handle.buf.len == 0) {
                    self.handle.buf = try self.allocator.alloc(u8, mem.page_size);
                }

                while (true) {
                    const result = posix.getdirentries(self.handle.fd, self.handle.buf.ptr, self.handle.buf.len, &self.handle.seek);
                    const err = posix.getErrno(result);
                    if (err > 0) {
                        switch (err) {
                            posix.EBADF, posix.EFAULT, posix.ENOTDIR => unreachable,
                            posix.EINVAL => {
                                self.handle.buf = try self.allocator.realloc(self.handle.buf, self.handle.buf.len * 2);
                                continue;
                            },
                            else => return unexpectedErrorPosix(err),
                        }
                    }
                    if (result == 0) return null;
                    self.handle.index = 0;
                    self.handle.end_index = result;
                    break;
                }
            }
            const freebsd_entry = @ptrCast(*align(1) posix.dirent, &self.handle.buf[self.handle.index]);
            const next_index = self.handle.index + freebsd_entry.d_reclen;
            self.handle.index = next_index;

            const name = @ptrCast([*]u8, &freebsd_entry.d_name)[0..freebsd_entry.d_namlen];

            if (mem.eql(u8, name, ".") or mem.eql(u8, name, "..")) {
                continue :start_over;
            }

            const entry_kind = switch (freebsd_entry.d_type) {
                posix.DT_BLK => Entry.Kind.BlockDevice,
                posix.DT_CHR => Entry.Kind.CharacterDevice,
                posix.DT_DIR => Entry.Kind.Directory,
                posix.DT_FIFO => Entry.Kind.NamedPipe,
                posix.DT_LNK => Entry.Kind.SymLink,
                posix.DT_REG => Entry.Kind.File,
                posix.DT_SOCK => Entry.Kind.UnixDomainSocket,
                posix.DT_WHT => Entry.Kind.Whiteout,
                else => Entry.Kind.Unknown,
            };
            return Entry{
                .name = name,
                .kind = entry_kind,
            };
        }
    }
};

/// Read value of a symbolic link.
/// The return value is a slice of buffer, from index `0`.
pub fn readLink(buffer: *[posix.PATH_MAX]u8, pathname: []const u8) ![]u8 {
    return posix.readlink(pathname, buffer);
}

/// Same as `readLink`, except the `pathname` parameter is null-terminated.
pub fn readLinkC(buffer: *[posix.PATH_MAX]u8, pathname: [*]const u8) ![]u8 {
    return posix.readlinkC(pathname, buffer);
}

pub fn openSelfExe() !os.File {
    switch (builtin.os) {
        Os.linux => return os.File.openReadC(c"/proc/self/exe"),
        Os.macosx, Os.ios, Os.freebsd, Os.netbsd => {
            var buf: [MAX_PATH_BYTES]u8 = undefined;
            const self_exe_path = try selfExePath(&buf);
            buf[self_exe_path.len] = 0;
            return os.File.openReadC(self_exe_path.ptr);
        },
        Os.windows => {
            var buf: [posix.PATH_MAX_WIDE]u16 = undefined;
            const wide_slice = try selfExePathW(&buf);
            return os.File.openReadW(wide_slice.ptr);
        },
        else => @compileError("Unsupported OS"),
    }
}

test "openSelfExe" {
    switch (builtin.os) {
        Os.linux, Os.macosx, Os.ios, Os.windows, Os.freebsd => (try openSelfExe()).close(),
        else => return error.SkipZigTest, // Unsupported OS.
    }
}

pub fn selfExePathW(out_buffer: *[posix.PATH_MAX_WIDE]u16) ![]u16 {
    const casted_len = @intCast(windows.DWORD, out_buffer.len); // TODO shouldn't need this cast
    const rc = windows.GetModuleFileNameW(null, out_buffer, casted_len);
    assert(rc <= out_buffer.len);
    if (rc == 0) {
        const err = windows.GetLastError();
        switch (err) {
            else => return windows.unexpectedError(err),
        }
    }
    return out_buffer[0..rc];
}

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
pub fn selfExePath(out_buffer: *[MAX_PATH_BYTES]u8) ![]u8 {
    switch (builtin.os) {
        Os.linux => return readLink(out_buffer, "/proc/self/exe"),
        Os.freebsd => {
            var mib = [4]c_int{ posix.CTL_KERN, posix.KERN_PROC, posix.KERN_PROC_PATHNAME, -1 };
            var out_len: usize = out_buffer.len;
            try posix.sysctl(&mib, out_buffer, &out_len, null, 0);
            // TODO could this slice from 0 to out_len instead?
            return mem.toSlice(u8, out_buffer);
        },
        Os.netbsd => {
            var mib = [4]c_int{ posix.CTL_KERN, posix.KERN_PROC_ARGS, -1, posix.KERN_PROC_PATHNAME };
            var out_len: usize = out_buffer.len;
            try posix.sysctl(&mib, out_buffer, &out_len, null, 0);
            // TODO could this slice from 0 to out_len instead?
            return mem.toSlice(u8, out_buffer);
        },
        Os.windows => {
            var utf16le_buf: [posix.PATH_MAX_WIDE]u16 = undefined;
            const utf16le_slice = try selfExePathW(&utf16le_buf);
            // Trust that Windows gives us valid UTF-16LE.
            const end_index = std.unicode.utf16leToUtf8(out_buffer, utf16le_slice) catch unreachable;
            return out_buffer[0..end_index];
        },
        Os.macosx, Os.ios => {
            var u32_len: u32 = @intCast(u32, out_buffer.len); // TODO shouldn't need this cast
            const rc = c._NSGetExecutablePath(out_buffer, &u32_len);
            if (rc != 0) return error.NameTooLong;
            return mem.toSlice(u8, out_buffer);
        },
        else => @compileError("Unsupported OS"),
    }
}

/// `selfExeDirPath` except allocates the result on the heap.
/// Caller owns returned memory.
pub fn selfExeDirPathAlloc(allocator: *Allocator) ![]u8 {
    var buf: [MAX_PATH_BYTES]u8 = undefined;
    return mem.dupe(allocator, u8, try selfExeDirPath(&buf));
}

/// Get the directory path that contains the current executable.
/// Returned value is a slice of out_buffer.
pub fn selfExeDirPath(out_buffer: *[MAX_PATH_BYTES]u8) ![]const u8 {
    switch (builtin.os) {
        Os.linux => {
            // If the currently executing binary has been deleted,
            // the file path looks something like `/a/b/c/exe (deleted)`
            // This path cannot be opened, but it's valid for determining the directory
            // the executable was in when it was run.
            const full_exe_path = try readLinkC(out_buffer, c"/proc/self/exe");
            // Assume that /proc/self/exe has an absolute path, and therefore dirname
            // will not return null.
            return path.dirname(full_exe_path).?;
        },
        Os.windows, Os.macosx, Os.ios, Os.freebsd, Os.netbsd => {
            const self_exe_path = try selfExePath(out_buffer);
            // Assume that the OS APIs return absolute paths, and therefore dirname
            // will not return null.
            return path.dirname(self_exe_path).?;
        },
        else => @compileError("Unsupported OS"),
    }
}

/// `realpath`, except caller must free the returned memory.
pub fn realAlloc(allocator: *Allocator, pathname: []const u8) ![]u8 {
    var buf: [MAX_PATH_BYTES]u8 = undefined;
    return mem.dupe(allocator, u8, try realpath(pathname, &buf));
}

test "" {
    _ = @import("fs/path.zig");
    _ = @import("fs/file.zig");
    _ = @import("fs/get_app_data_dir.zig");
}
