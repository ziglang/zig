/// The OS-specific file descriptor or file handle.
handle: Handle,

pub const Handle = posix.fd_t;
pub const Mode = posix.mode_t;
pub const INode = posix.ino_t;
pub const Uid = posix.uid_t;
pub const Gid = posix.gid_t;

pub const Kind = enum {
    block_device,
    character_device,
    directory,
    named_pipe,
    sym_link,
    file,
    unix_domain_socket,
    whiteout,
    door,
    event_port,
    unknown,
};

/// This is the default mode given to POSIX operating systems for creating
/// files. `0o666` is "-rw-rw-rw-" which is counter-intuitive at first,
/// since most people would expect "-rw-r--r--", for example, when using
/// the `touch` command, which would correspond to `0o644`. However, POSIX
/// libc implementations use `0o666` inside `fopen` and then rely on the
/// process-scoped "umask" setting to adjust this number for file creation.
pub const default_mode = switch (builtin.os.tag) {
    .windows => 0,
    .wasi => 0,
    else => 0o666,
};

pub const OpenError = error{
    SharingViolation,
    PathAlreadyExists,
    FileNotFound,
    AccessDenied,
    PipeBusy,
    NoDevice,
    NameTooLong,
    /// WASI-only; file paths must be valid UTF-8.
    InvalidUtf8,
    /// Windows-only; file paths provided by the user must be valid WTF-8.
    /// https://simonsapin.github.io/wtf-8/
    InvalidWtf8,
    /// On Windows, file paths cannot contain these characters:
    /// '/', '*', '?', '"', '<', '>', '|'
    BadPathName,
    Unexpected,
    /// On Windows, `\\server` or `\\server\share` was not found.
    NetworkNotFound,
    ProcessNotFound,
    /// On Windows, antivirus software is enabled by default. It can be
    /// disabled, but Windows Update sometimes ignores the user's preference
    /// and re-enables it. When enabled, antivirus software on Windows
    /// intercepts file system operations and makes them significantly slower
    /// in addition to possibly failing with this error code.
    AntivirusInterference,
} || posix.OpenError || posix.FlockError;

pub const OpenMode = enum {
    read_only,
    write_only,
    read_write,
};

pub const Lock = enum {
    none,
    shared,
    exclusive,
};

pub const OpenFlags = struct {
    mode: OpenMode = .read_only,

    /// Open the file with an advisory lock to coordinate with other processes
    /// accessing it at the same time. An exclusive lock will prevent other
    /// processes from acquiring a lock. A shared lock will prevent other
    /// processes from acquiring a exclusive lock, but does not prevent
    /// other process from getting their own shared locks.
    ///
    /// The lock is advisory, except on Linux in very specific circumstances[1].
    /// This means that a process that does not respect the locking API can still get access
    /// to the file, despite the lock.
    ///
    /// On these operating systems, the lock is acquired atomically with
    /// opening the file:
    /// * Darwin
    /// * DragonFlyBSD
    /// * FreeBSD
    /// * Haiku
    /// * NetBSD
    /// * OpenBSD
    /// On these operating systems, the lock is acquired via a separate syscall
    /// after opening the file:
    /// * Linux
    /// * Windows
    ///
    /// [1]: https://www.kernel.org/doc/Documentation/filesystems/mandatory-locking.txt
    lock: Lock = .none,

    /// Sets whether or not to wait until the file is locked to return. If set to true,
    /// `error.WouldBlock` will be returned. Otherwise, the file will wait until the file
    /// is available to proceed.
    lock_nonblocking: bool = false,

    /// Set this to allow the opened file to automatically become the
    /// controlling TTY for the current process.
    allow_ctty: bool = false,

    pub fn isRead(self: OpenFlags) bool {
        return self.mode != .write_only;
    }

    pub fn isWrite(self: OpenFlags) bool {
        return self.mode != .read_only;
    }
};

pub const CreateFlags = struct {
    /// Whether the file will be created with read access.
    read: bool = false,

    /// If the file already exists, and is a regular file, and the access
    /// mode allows writing, it will be truncated to length 0.
    truncate: bool = true,

    /// Ensures that this open call creates the file, otherwise causes
    /// `error.PathAlreadyExists` to be returned.
    exclusive: bool = false,

    /// Open the file with an advisory lock to coordinate with other processes
    /// accessing it at the same time. An exclusive lock will prevent other
    /// processes from acquiring a lock. A shared lock will prevent other
    /// processes from acquiring a exclusive lock, but does not prevent
    /// other process from getting their own shared locks.
    ///
    /// The lock is advisory, except on Linux in very specific circumstances[1].
    /// This means that a process that does not respect the locking API can still get access
    /// to the file, despite the lock.
    ///
    /// On these operating systems, the lock is acquired atomically with
    /// opening the file:
    /// * Darwin
    /// * DragonFlyBSD
    /// * FreeBSD
    /// * Haiku
    /// * NetBSD
    /// * OpenBSD
    /// On these operating systems, the lock is acquired via a separate syscall
    /// after opening the file:
    /// * Linux
    /// * Windows
    ///
    /// [1]: https://www.kernel.org/doc/Documentation/filesystems/mandatory-locking.txt
    lock: Lock = .none,

    /// Sets whether or not to wait until the file is locked to return. If set to true,
    /// `error.WouldBlock` will be returned. Otherwise, the file will wait until the file
    /// is available to proceed.
    lock_nonblocking: bool = false,

    /// For POSIX systems this is the file system mode the file will
    /// be created with. On other systems this is always 0.
    mode: Mode = default_mode,
};

pub fn stdout() File {
    return .{ .handle = if (is_windows) windows.peb().ProcessParameters.hStdOutput else posix.STDOUT_FILENO };
}

pub fn stderr() File {
    return .{ .handle = if (is_windows) windows.peb().ProcessParameters.hStdError else posix.STDERR_FILENO };
}

pub fn stdin() File {
    return .{ .handle = if (is_windows) windows.peb().ProcessParameters.hStdInput else posix.STDIN_FILENO };
}

/// Upon success, the stream is in an uninitialized state. To continue using it,
/// you must use the open() function.
pub fn close(self: File) void {
    if (is_windows) {
        windows.CloseHandle(self.handle);
    } else {
        posix.close(self.handle);
    }
}

pub const SyncError = posix.SyncError;

/// Blocks until all pending file contents and metadata modifications
/// for the file have been synchronized with the underlying filesystem.
///
/// Note that this does not ensure that metadata for the
/// directory containing the file has also reached disk.
pub fn sync(self: File) SyncError!void {
    return posix.fsync(self.handle);
}

/// Test whether the file refers to a terminal.
/// See also `getOrEnableAnsiEscapeSupport` and `supportsAnsiEscapeCodes`.
pub fn isTty(self: File) bool {
    return posix.isatty(self.handle);
}

pub fn isCygwinPty(file: File) bool {
    if (builtin.os.tag != .windows) return false;

    const handle = file.handle;

    // If this is a MSYS2/cygwin pty, then it will be a named pipe with a name in one of these formats:
    //   msys-[...]-ptyN-[...]
    //   cygwin-[...]-ptyN-[...]
    //
    // Example: msys-1888ae32e00d56aa-pty0-to-master

    // First, just check that the handle is a named pipe.
    // This allows us to avoid the more costly NtQueryInformationFile call
    // for handles that aren't named pipes.
    {
        var io_status: windows.IO_STATUS_BLOCK = undefined;
        var device_info: windows.FILE_FS_DEVICE_INFORMATION = undefined;
        const rc = windows.ntdll.NtQueryVolumeInformationFile(handle, &io_status, &device_info, @sizeOf(windows.FILE_FS_DEVICE_INFORMATION), .FileFsDeviceInformation);
        switch (rc) {
            .SUCCESS => {},
            else => return false,
        }
        if (device_info.DeviceType != windows.FILE_DEVICE_NAMED_PIPE) return false;
    }

    const name_bytes_offset = @offsetOf(windows.FILE_NAME_INFO, "FileName");
    // `NAME_MAX` UTF-16 code units (2 bytes each)
    // This buffer may not be long enough to handle *all* possible paths
    // (PATH_MAX_WIDE would be necessary for that), but because we only care
    // about certain paths and we know they must be within a reasonable length,
    // we can use this smaller buffer and just return false on any error from
    // NtQueryInformationFile.
    const num_name_bytes = windows.MAX_PATH * 2;
    var name_info_bytes align(@alignOf(windows.FILE_NAME_INFO)) = [_]u8{0} ** (name_bytes_offset + num_name_bytes);

    var io_status_block: windows.IO_STATUS_BLOCK = undefined;
    const rc = windows.ntdll.NtQueryInformationFile(handle, &io_status_block, &name_info_bytes, @intCast(name_info_bytes.len), .FileNameInformation);
    switch (rc) {
        .SUCCESS => {},
        .INVALID_PARAMETER => unreachable,
        else => return false,
    }

    const name_info: *const windows.FILE_NAME_INFO = @ptrCast(&name_info_bytes);
    const name_bytes = name_info_bytes[name_bytes_offset .. name_bytes_offset + name_info.FileNameLength];
    const name_wide = std.mem.bytesAsSlice(u16, name_bytes);
    // The name we get from NtQueryInformationFile will be prefixed with a '\', e.g. \msys-1888ae32e00d56aa-pty0-to-master
    return (std.mem.startsWith(u16, name_wide, &[_]u16{ '\\', 'm', 's', 'y', 's', '-' }) or
        std.mem.startsWith(u16, name_wide, &[_]u16{ '\\', 'c', 'y', 'g', 'w', 'i', 'n', '-' })) and
        std.mem.indexOf(u16, name_wide, &[_]u16{ '-', 'p', 't', 'y' }) != null;
}

/// Returns whether or not ANSI escape codes will be treated as such,
/// and attempts to enable support for ANSI escape codes if necessary
/// (on Windows).
///
/// Returns `true` if ANSI escape codes are supported or support was
/// successfully enabled. Returns false if ANSI escape codes are not
/// supported or support was unable to be enabled.
///
/// See also `supportsAnsiEscapeCodes`.
pub fn getOrEnableAnsiEscapeSupport(self: File) bool {
    if (builtin.os.tag == .windows) {
        var original_console_mode: windows.DWORD = 0;

        // For Windows Terminal, VT Sequences processing is enabled by default.
        if (windows.kernel32.GetConsoleMode(self.handle, &original_console_mode) != 0) {
            if (original_console_mode & windows.ENABLE_VIRTUAL_TERMINAL_PROCESSING != 0) return true;

            // For Windows Console, VT Sequences processing support was added in Windows 10 build 14361, but disabled by default.
            // https://devblogs.microsoft.com/commandline/tmux-support-arrives-for-bash-on-ubuntu-on-windows/
            //
            // Note: In Microsoft's example for enabling virtual terminal processing, it
            // shows attempting to enable `DISABLE_NEWLINE_AUTO_RETURN` as well:
            // https://learn.microsoft.com/en-us/windows/console/console-virtual-terminal-sequences#example-of-enabling-virtual-terminal-processing
            // This is avoided because in the old Windows Console, that flag causes \n (as opposed to \r\n)
            // to behave unexpectedly (the cursor moves down 1 row but remains on the same column).
            // Additionally, the default console mode in Windows Terminal does not have
            // `DISABLE_NEWLINE_AUTO_RETURN` set, so by only enabling `ENABLE_VIRTUAL_TERMINAL_PROCESSING`
            // we end up matching the mode of Windows Terminal.
            const requested_console_modes = windows.ENABLE_VIRTUAL_TERMINAL_PROCESSING;
            const console_mode = original_console_mode | requested_console_modes;
            if (windows.kernel32.SetConsoleMode(self.handle, console_mode) != 0) return true;
        }

        return self.isCygwinPty();
    }
    return self.supportsAnsiEscapeCodes();
}

/// Test whether ANSI escape codes will be treated as such without
/// attempting to enable support for ANSI escape codes.
///
/// See also `getOrEnableAnsiEscapeSupport`.
pub fn supportsAnsiEscapeCodes(self: File) bool {
    if (builtin.os.tag == .windows) {
        var console_mode: windows.DWORD = 0;
        if (windows.kernel32.GetConsoleMode(self.handle, &console_mode) != 0) {
            if (console_mode & windows.ENABLE_VIRTUAL_TERMINAL_PROCESSING != 0) return true;
        }

        return self.isCygwinPty();
    }
    if (builtin.os.tag == .wasi) {
        // WASI sanitizes stdout when fd is a tty so ANSI escape codes
        // will not be interpreted as actual cursor commands, and
        // stderr is always sanitized.
        return false;
    }
    if (self.isTty()) {
        if (self.handle == posix.STDOUT_FILENO or self.handle == posix.STDERR_FILENO) {
            if (posix.getenvZ("TERM")) |term| {
                if (std.mem.eql(u8, term, "dumb"))
                    return false;
            }
        }
        return true;
    }
    return false;
}

pub const SetEndPosError = posix.TruncateError;

/// Shrinks or expands the file.
/// The file offset after this call is left unchanged.
pub fn setEndPos(self: File, length: u64) SetEndPosError!void {
    try posix.ftruncate(self.handle, length);
}

pub const SeekError = posix.SeekError;

/// Repositions read/write file offset relative to the current offset.
/// TODO: integrate with async I/O
pub fn seekBy(self: File, offset: i64) SeekError!void {
    return posix.lseek_CUR(self.handle, offset);
}

/// Repositions read/write file offset relative to the end.
/// TODO: integrate with async I/O
pub fn seekFromEnd(self: File, offset: i64) SeekError!void {
    return posix.lseek_END(self.handle, offset);
}

/// Repositions read/write file offset relative to the beginning.
/// TODO: integrate with async I/O
pub fn seekTo(self: File, offset: u64) SeekError!void {
    return posix.lseek_SET(self.handle, offset);
}

pub const GetSeekPosError = posix.SeekError || StatError;

/// TODO: integrate with async I/O
pub fn getPos(self: File) GetSeekPosError!u64 {
    return posix.lseek_CUR_get(self.handle);
}

pub const GetEndPosError = std.os.windows.GetFileSizeError || StatError;

/// TODO: integrate with async I/O
pub fn getEndPos(self: File) GetEndPosError!u64 {
    if (builtin.os.tag == .windows) {
        return windows.GetFileSizeEx(self.handle);
    }
    return (try self.stat()).size;
}

pub const ModeError = StatError;

/// TODO: integrate with async I/O
pub fn mode(self: File) ModeError!Mode {
    if (builtin.os.tag == .windows) {
        return 0;
    }
    return (try self.stat()).mode;
}

pub const Stat = struct {
    /// A number that the system uses to point to the file metadata. This
    /// number is not guaranteed to be unique across time, as some file
    /// systems may reuse an inode after its file has been deleted. Some
    /// systems may change the inode of a file over time.
    ///
    /// On Linux, the inode is a structure that stores the metadata, and
    /// the inode _number_ is what you see here: the index number of the
    /// inode.
    ///
    /// The FileIndex on Windows is similar. It is a number for a file that
    /// is unique to each filesystem.
    inode: INode,
    size: u64,
    /// This is available on POSIX systems and is always 0 otherwise.
    mode: Mode,
    kind: Kind,

    /// Last access time in nanoseconds, relative to UTC 1970-01-01.
    atime: i128,
    /// Last modification time in nanoseconds, relative to UTC 1970-01-01.
    mtime: i128,
    /// Last status/metadata change time in nanoseconds, relative to UTC 1970-01-01.
    ctime: i128,

    pub fn fromPosix(st: posix.Stat) Stat {
        const atime = st.atime();
        const mtime = st.mtime();
        const ctime = st.ctime();
        return .{
            .inode = st.ino,
            .size = @bitCast(st.size),
            .mode = st.mode,
            .kind = k: {
                const m = st.mode & posix.S.IFMT;
                switch (m) {
                    posix.S.IFBLK => break :k .block_device,
                    posix.S.IFCHR => break :k .character_device,
                    posix.S.IFDIR => break :k .directory,
                    posix.S.IFIFO => break :k .named_pipe,
                    posix.S.IFLNK => break :k .sym_link,
                    posix.S.IFREG => break :k .file,
                    posix.S.IFSOCK => break :k .unix_domain_socket,
                    else => {},
                }
                if (builtin.os.tag.isSolarish()) switch (m) {
                    posix.S.IFDOOR => break :k .door,
                    posix.S.IFPORT => break :k .event_port,
                    else => {},
                };

                break :k .unknown;
            },
            .atime = @as(i128, atime.sec) * std.time.ns_per_s + atime.nsec,
            .mtime = @as(i128, mtime.sec) * std.time.ns_per_s + mtime.nsec,
            .ctime = @as(i128, ctime.sec) * std.time.ns_per_s + ctime.nsec,
        };
    }

    pub fn fromLinux(stx: linux.Statx) Stat {
        const atime = stx.atime;
        const mtime = stx.mtime;
        const ctime = stx.ctime;

        return .{
            .inode = stx.ino,
            .size = stx.size,
            .mode = stx.mode,
            .kind = switch (stx.mode & linux.S.IFMT) {
                linux.S.IFDIR => .directory,
                linux.S.IFCHR => .character_device,
                linux.S.IFBLK => .block_device,
                linux.S.IFREG => .file,
                linux.S.IFIFO => .named_pipe,
                linux.S.IFLNK => .sym_link,
                linux.S.IFSOCK => .unix_domain_socket,
                else => .unknown,
            },
            .atime = @as(i128, atime.sec) * std.time.ns_per_s + atime.nsec,
            .mtime = @as(i128, mtime.sec) * std.time.ns_per_s + mtime.nsec,
            .ctime = @as(i128, ctime.sec) * std.time.ns_per_s + ctime.nsec,
        };
    }

    pub fn fromWasi(st: std.os.wasi.filestat_t) Stat {
        return .{
            .inode = st.ino,
            .size = @bitCast(st.size),
            .mode = 0,
            .kind = switch (st.filetype) {
                .BLOCK_DEVICE => .block_device,
                .CHARACTER_DEVICE => .character_device,
                .DIRECTORY => .directory,
                .SYMBOLIC_LINK => .sym_link,
                .REGULAR_FILE => .file,
                .SOCKET_STREAM, .SOCKET_DGRAM => .unix_domain_socket,
                else => .unknown,
            },
            .atime = st.atim,
            .mtime = st.mtim,
            .ctime = st.ctim,
        };
    }
};

pub const StatError = posix.FStatError;

/// Returns `Stat` containing basic information about the `File`.
/// TODO: integrate with async I/O
pub fn stat(self: File) StatError!Stat {
    if (builtin.os.tag == .windows) {
        var io_status_block: windows.IO_STATUS_BLOCK = undefined;
        var info: windows.FILE_ALL_INFORMATION = undefined;
        const rc = windows.ntdll.NtQueryInformationFile(self.handle, &io_status_block, &info, @sizeOf(windows.FILE_ALL_INFORMATION), .FileAllInformation);
        switch (rc) {
            .SUCCESS => {},
            // Buffer overflow here indicates that there is more information available than was able to be stored in the buffer
            // size provided. This is treated as success because the type of variable-length information that this would be relevant for
            // (name, volume name, etc) we don't care about.
            .BUFFER_OVERFLOW => {},
            .INVALID_PARAMETER => unreachable,
            .ACCESS_DENIED => return error.AccessDenied,
            else => return windows.unexpectedStatus(rc),
        }
        return .{
            .inode = info.InternalInformation.IndexNumber,
            .size = @as(u64, @bitCast(info.StandardInformation.EndOfFile)),
            .mode = 0,
            .kind = if (info.BasicInformation.FileAttributes & windows.FILE_ATTRIBUTE_REPARSE_POINT != 0) reparse_point: {
                var tag_info: windows.FILE_ATTRIBUTE_TAG_INFO = undefined;
                const tag_rc = windows.ntdll.NtQueryInformationFile(self.handle, &io_status_block, &tag_info, @sizeOf(windows.FILE_ATTRIBUTE_TAG_INFO), .FileAttributeTagInformation);
                switch (tag_rc) {
                    .SUCCESS => {},
                    // INFO_LENGTH_MISMATCH and ACCESS_DENIED are the only documented possible errors
                    // https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-fscc/d295752f-ce89-4b98-8553-266d37c84f0e
                    .INFO_LENGTH_MISMATCH => unreachable,
                    .ACCESS_DENIED => return error.AccessDenied,
                    else => return windows.unexpectedStatus(rc),
                }
                if (tag_info.ReparseTag & windows.reparse_tag_name_surrogate_bit != 0) {
                    break :reparse_point .sym_link;
                }
                // Unknown reparse point
                break :reparse_point .unknown;
            } else if (info.BasicInformation.FileAttributes & windows.FILE_ATTRIBUTE_DIRECTORY != 0)
                .directory
            else
                .file,
            .atime = windows.fromSysTime(info.BasicInformation.LastAccessTime),
            .mtime = windows.fromSysTime(info.BasicInformation.LastWriteTime),
            .ctime = windows.fromSysTime(info.BasicInformation.ChangeTime),
        };
    }

    if (builtin.os.tag == .wasi and !builtin.link_libc) {
        const st = try std.os.fstat_wasi(self.handle);
        return Stat.fromWasi(st);
    }

    if (builtin.os.tag == .linux) {
        var stx = std.mem.zeroes(linux.Statx);

        const rc = linux.statx(
            self.handle,
            "",
            linux.AT.EMPTY_PATH,
            linux.STATX_TYPE | linux.STATX_MODE | linux.STATX_ATIME | linux.STATX_MTIME | linux.STATX_CTIME,
            &stx,
        );

        return switch (linux.E.init(rc)) {
            .SUCCESS => Stat.fromLinux(stx),
            .ACCES => unreachable,
            .BADF => unreachable,
            .FAULT => unreachable,
            .INVAL => unreachable,
            .LOOP => unreachable,
            .NAMETOOLONG => unreachable,
            .NOENT => unreachable,
            .NOMEM => error.SystemResources,
            .NOTDIR => unreachable,
            else => |err| posix.unexpectedErrno(err),
        };
    }

    const st = try posix.fstat(self.handle);
    return Stat.fromPosix(st);
}

pub const ChmodError = posix.FChmodError;

/// Changes the mode of the file.
/// The process must have the correct privileges in order to do this
/// successfully, or must have the effective user ID matching the owner
/// of the file.
pub fn chmod(self: File, new_mode: Mode) ChmodError!void {
    try posix.fchmod(self.handle, new_mode);
}

pub const ChownError = posix.FChownError;

/// Changes the owner and group of the file.
/// The process must have the correct privileges in order to do this
/// successfully. The group may be changed by the owner of the file to
/// any group of which the owner is a member. If the owner or group is
/// specified as `null`, the ID is not changed.
pub fn chown(self: File, owner: ?Uid, group: ?Gid) ChownError!void {
    try posix.fchown(self.handle, owner, group);
}

/// Cross-platform representation of permissions on a file.
/// The `readonly` and `setReadonly` are the only methods available across all platforms.
/// Platform-specific functionality is available through the `inner` field.
pub const Permissions = struct {
    /// You may use the `inner` field to use platform-specific functionality
    inner: switch (builtin.os.tag) {
        .windows => PermissionsWindows,
        else => PermissionsUnix,
    },

    const Self = @This();

    /// Returns `true` if permissions represent an unwritable file.
    /// On Unix, `true` is returned only if no class has write permissions.
    pub fn readOnly(self: Self) bool {
        return self.inner.readOnly();
    }

    /// Sets whether write permissions are provided.
    /// On Unix, this affects *all* classes. If this is undesired, use `unixSet`.
    /// This method *DOES NOT* set permissions on the filesystem: use `File.setPermissions(permissions)`
    pub fn setReadOnly(self: *Self, read_only: bool) void {
        self.inner.setReadOnly(read_only);
    }
};

pub const PermissionsWindows = struct {
    attributes: windows.DWORD,

    const Self = @This();

    /// Returns `true` if permissions represent an unwritable file.
    pub fn readOnly(self: Self) bool {
        return self.attributes & windows.FILE_ATTRIBUTE_READONLY != 0;
    }

    /// Sets whether write permissions are provided.
    /// This method *DOES NOT* set permissions on the filesystem: use `File.setPermissions(permissions)`
    pub fn setReadOnly(self: *Self, read_only: bool) void {
        if (read_only) {
            self.attributes |= windows.FILE_ATTRIBUTE_READONLY;
        } else {
            self.attributes &= ~@as(windows.DWORD, windows.FILE_ATTRIBUTE_READONLY);
        }
    }
};

pub const PermissionsUnix = struct {
    mode: Mode,

    const Self = @This();

    /// Returns `true` if permissions represent an unwritable file.
    /// `true` is returned only if no class has write permissions.
    pub fn readOnly(self: Self) bool {
        return self.mode & 0o222 == 0;
    }

    /// Sets whether write permissions are provided.
    /// This affects *all* classes. If this is undesired, use `unixSet`.
    /// This method *DOES NOT* set permissions on the filesystem: use `File.setPermissions(permissions)`
    pub fn setReadOnly(self: *Self, read_only: bool) void {
        if (read_only) {
            self.mode &= ~@as(Mode, 0o222);
        } else {
            self.mode |= @as(Mode, 0o222);
        }
    }

    pub const Class = enum(u2) {
        user = 2,
        group = 1,
        other = 0,
    };

    pub const Permission = enum(u3) {
        read = 0o4,
        write = 0o2,
        execute = 0o1,
    };

    /// Returns `true` if the chosen class has the selected permission.
    /// This method is only available on Unix platforms.
    pub fn unixHas(self: Self, class: Class, permission: Permission) bool {
        const mask = @as(Mode, @intFromEnum(permission)) << @as(u3, @intFromEnum(class)) * 3;
        return self.mode & mask != 0;
    }

    /// Sets the permissions for the chosen class. Any permissions set to `null` are left unchanged.
    /// This method *DOES NOT* set permissions on the filesystem: use `File.setPermissions(permissions)`
    pub fn unixSet(self: *Self, class: Class, permissions: struct {
        read: ?bool = null,
        write: ?bool = null,
        execute: ?bool = null,
    }) void {
        const shift = @as(u3, @intFromEnum(class)) * 3;
        if (permissions.read) |r| {
            if (r) {
                self.mode |= @as(Mode, 0o4) << shift;
            } else {
                self.mode &= ~(@as(Mode, 0o4) << shift);
            }
        }
        if (permissions.write) |w| {
            if (w) {
                self.mode |= @as(Mode, 0o2) << shift;
            } else {
                self.mode &= ~(@as(Mode, 0o2) << shift);
            }
        }
        if (permissions.execute) |x| {
            if (x) {
                self.mode |= @as(Mode, 0o1) << shift;
            } else {
                self.mode &= ~(@as(Mode, 0o1) << shift);
            }
        }
    }

    /// Returns a `Permissions` struct representing the permissions from the passed mode.
    pub fn unixNew(new_mode: Mode) Self {
        return Self{
            .mode = new_mode,
        };
    }
};

pub const SetPermissionsError = ChmodError;

/// Sets permissions according to the provided `Permissions` struct.
/// This method is *NOT* available on WASI
pub fn setPermissions(self: File, permissions: Permissions) SetPermissionsError!void {
    switch (builtin.os.tag) {
        .windows => {
            var io_status_block: windows.IO_STATUS_BLOCK = undefined;
            var info = windows.FILE_BASIC_INFORMATION{
                .CreationTime = 0,
                .LastAccessTime = 0,
                .LastWriteTime = 0,
                .ChangeTime = 0,
                .FileAttributes = permissions.inner.attributes,
            };
            const rc = windows.ntdll.NtSetInformationFile(
                self.handle,
                &io_status_block,
                &info,
                @sizeOf(windows.FILE_BASIC_INFORMATION),
                .FileBasicInformation,
            );
            switch (rc) {
                .SUCCESS => return,
                .INVALID_HANDLE => unreachable,
                .ACCESS_DENIED => return error.AccessDenied,
                else => return windows.unexpectedStatus(rc),
            }
        },
        .wasi => @compileError("Unsupported OS"), // Wasi filesystem does not *yet* support chmod
        else => {
            try self.chmod(permissions.inner.mode);
        },
    }
}

pub const UpdateTimesError = posix.FutimensError || windows.SetFileTimeError;

/// The underlying file system may have a different granularity than nanoseconds,
/// and therefore this function cannot guarantee any precision will be stored.
/// Further, the maximum value is limited by the system ABI. When a value is provided
/// that exceeds this range, the value is clamped to the maximum.
/// TODO: integrate with async I/O
pub fn updateTimes(
    self: File,
    /// access timestamp in nanoseconds
    atime: i128,
    /// last modification timestamp in nanoseconds
    mtime: i128,
) UpdateTimesError!void {
    if (builtin.os.tag == .windows) {
        const atime_ft = windows.nanoSecondsToFileTime(atime);
        const mtime_ft = windows.nanoSecondsToFileTime(mtime);
        return windows.SetFileTime(self.handle, null, &atime_ft, &mtime_ft);
    }
    const times = [2]posix.timespec{
        posix.timespec{
            .sec = math.cast(isize, @divFloor(atime, std.time.ns_per_s)) orelse maxInt(isize),
            .nsec = math.cast(isize, @mod(atime, std.time.ns_per_s)) orelse maxInt(isize),
        },
        posix.timespec{
            .sec = math.cast(isize, @divFloor(mtime, std.time.ns_per_s)) orelse maxInt(isize),
            .nsec = math.cast(isize, @mod(mtime, std.time.ns_per_s)) orelse maxInt(isize),
        },
    };
    try posix.futimens(self.handle, &times);
}

pub const ReadError = posix.ReadError;
pub const PReadError = posix.PReadError;

pub fn read(self: File, buffer: []u8) ReadError!usize {
    if (is_windows) {
        return windows.ReadFile(self.handle, buffer, null);
    }

    return posix.read(self.handle, buffer);
}

/// On Windows, this function currently does alter the file pointer.
/// https://github.com/ziglang/zig/issues/12783
pub fn pread(self: File, buffer: []u8, offset: u64) PReadError!usize {
    if (is_windows) {
        return windows.ReadFile(self.handle, buffer, offset);
    }

    return posix.pread(self.handle, buffer, offset);
}

/// See https://github.com/ziglang/zig/issues/7699
pub fn readv(self: File, iovecs: []const posix.iovec) ReadError!usize {
    if (is_windows) {
        if (iovecs.len == 0) return 0;
        const first = iovecs[0];
        return windows.ReadFile(self.handle, first.base[0..first.len], null);
    }

    return posix.readv(self.handle, iovecs);
}

/// See https://github.com/ziglang/zig/issues/7699
/// On Windows, this function currently does alter the file pointer.
/// https://github.com/ziglang/zig/issues/12783
pub fn preadv(self: File, iovecs: []const posix.iovec, offset: u64) PReadError!usize {
    if (is_windows) {
        if (iovecs.len == 0) return 0;
        const first = iovecs[0];
        return windows.ReadFile(self.handle, first.base[0..first.len], offset);
    }

    return posix.preadv(self.handle, iovecs, offset);
}

pub const WriteError = posix.WriteError;
pub const PWriteError = posix.PWriteError;

pub fn write(self: File, bytes: []const u8) WriteError!usize {
    if (is_windows) {
        return windows.WriteFile(self.handle, bytes, null);
    }

    return posix.write(self.handle, bytes);
}

/// One-shot alternative to `std.io.BufferedWriter.writeAll` via `writer`.
pub fn writeAll(self: File, bytes: []const u8) WriteError!void {
    var index: usize = 0;
    while (index < bytes.len) {
        index += try self.write(bytes[index..]);
    }
}

/// On Windows, this function currently does alter the file pointer.
/// https://github.com/ziglang/zig/issues/12783
pub fn pwrite(self: File, bytes: []const u8, offset: u64) PWriteError!usize {
    if (is_windows) {
        return windows.WriteFile(self.handle, bytes, offset);
    }

    return posix.pwrite(self.handle, bytes, offset);
}

/// See https://github.com/ziglang/zig/issues/7699
pub fn writev(self: File, iovecs: []const posix.iovec_const) WriteError!usize {
    if (is_windows) {
        // TODO improve this to use WriteFileScatter
        if (iovecs.len == 0) return 0;
        const first = iovecs[0];
        return windows.WriteFile(self.handle, first.base[0..first.len], null);
    }

    return posix.writev(self.handle, iovecs);
}

/// See https://github.com/ziglang/zig/issues/7699
/// On Windows, this function currently does alter the file pointer.
/// https://github.com/ziglang/zig/issues/12783
pub fn pwritev(self: File, iovecs: []posix.iovec_const, offset: u64) PWriteError!usize {
    if (is_windows) {
        if (iovecs.len == 0) return 0;
        const first = iovecs[0];
        return windows.WriteFile(self.handle, first.base[0..first.len], offset);
    }

    return posix.pwritev(self.handle, iovecs, offset);
}

pub const WriteFileError = PReadError || WriteError;

pub fn writeFileAll(self: File, in_file: File, options: BufferedWriter.WriteFileOptions) WriteFileError!void {
    var file_writer = self.writer();
    var buffer: [2000]u8 = undefined;
    var bw = file_writer.interface().buffered(&buffer);
    bw.writeFileAll(in_file, options) catch |err| switch (err) {
        error.WriteFailed => return file_writer.err.?,
        else => |e| return e,
    };
}

/// Memoizes key information about a file handle such as:
/// * The size from calling stat, or the error that occurred therein.
/// * The current seek position.
/// * The error that occurred when trying to seek.
/// * Whether reading should be done positionally or streaming.
/// * Whether reading should be done via fd-to-fd syscalls (e.g. `sendfile`)
///   versus plain variants (e.g. `read`).
///
/// Fulfills the `std.io.Reader` interface.
pub const Reader = struct {
    file: File,
    err: ?ReadError = null,
    mode: Reader.Mode = .positional,
    pos: u64 = 0,
    size: ?u64 = null,
    size_err: ?GetEndPosError = null,
    seek_err: ?SeekError = null,

    pub const Mode = enum {
        streaming,
        positional,
        streaming_reading,
        positional_reading,

        pub fn toStreaming(m: @This()) @This() {
            return switch (m) {
                .positional => .streaming,
                .positional_reading => .streaming_reading,
                else => unreachable,
            };
        }
    };

    pub fn interface(r: *Reader) std.io.Reader {
        return .{
            .context = r,
            .vtable = &.{
                .read = Reader.read,
                .readVec = Reader.readVec,
                .discard = Reader.discard,
            },
        };
    }

    pub fn readable(r: *Reader, buffer: []u8) std.io.BufferedReader {
        return interface(r).buffered(buffer);
    }

    pub fn getSize(r: *Reader) GetEndPosError!u64 {
        return r.size orelse {
            if (r.size_err) |err| return err;
            if (r.file.getEndPos()) |size| {
                r.size = size;
                return size;
            } else |err| {
                r.size_err = err;
                return err;
            }
        };
    }

    pub fn seekBy(r: *Reader, offset: i64) SeekError!void {
        switch (r.mode) {
            .positional, .positional_reading => {
                r.pos += offset;
            },
            .streaming, .streaming_reading => {
                const seek_err = r.seek_err orelse e: {
                    if (posix.lseek_CUR(r.file.handle, offset)) |_| {
                        r.pos += offset;
                        return;
                    } else |err| {
                        r.seek_err = err;
                        break :e err;
                    }
                };
                if (offset < 0) return seek_err;
                var remaining = offset;
                while (remaining > 0) {
                    const n = discard(r, .limited(remaining)) catch |err| switch (err) {};
                    r.pos += n;
                    remaining -= n;
                }
            },
        }
    }

    pub fn seekTo(r: *Reader, offset: u64) SeekError!void {
        switch (r.mode) {
            .positional, .positional_reading => {
                r.pos = offset;
            },
            .streaming, .streaming_reading => {
                if (offset >= r.pos) return Reader.seekBy(r, offset - r.pos);
                if (r.seek_err) |err| return err;
                posix.lseek_SET(r.file.handle, offset) catch |err| {
                    r.seek_err = err;
                    return err;
                };
            },
        }
    }

    /// Number of slices to store on the stack, when trying to send as many byte
    /// vectors through the underlying read calls as possible.
    const max_buffers_len = 16;

    fn read(
        context: ?*anyopaque,
        bw: *BufferedWriter,
        limit: std.io.Reader.Limit,
    ) std.io.Reader.RwError!usize {
        const r: *Reader = @ptrCast(@alignCast(context));
        const file = r.file;
        const pos = r.pos;
        switch (r.mode) {
            .positional => {
                const size = r.size orelse {
                    if (file.getEndPos()) |size| {
                        r.size = size;
                    } else |err| {
                        r.size_err = err;
                        r.mode = .streaming;
                    }
                    return 0;
                };
                const new_limit = limit.min(.limited(size - pos));
                const n = bw.writeFile(file, .init(pos), new_limit, &.{}, 0) catch |err| switch (err) {
                    error.WriteFailed => return error.WriteFailed,
                    error.Unseekable => {
                        r.mode = .streaming;
                        if (pos != 0) @panic("TODO need to seek here");
                        return 0;
                    },
                    error.Unimplemented => {
                        r.mode = .positional_reading;
                        return 0;
                    },
                    else => |e| {
                        r.err = e;
                        return error.ReadFailed;
                    },
                };
                r.pos = pos + n;
                return n;
            },
            .streaming => {
                const n = bw.writeFile(file, .none, limit, &.{}, 0) catch |err| switch (err) {
                    error.WriteFailed => return error.WriteFailed,
                    error.Unseekable => unreachable, // Passing `Offset.none`.
                    error.Unimplemented => {
                        r.mode = .streaming_reading;
                        return 0;
                    },
                    else => |e| {
                        r.err = e;
                        return error.ReadFailed;
                    },
                };
                r.pos = pos + n;
                return n;
            },
            .positional_reading => {
                const dest = limit.slice(try bw.writableSliceGreedy(1));
                const n = file.pread(dest, pos) catch |err| switch (err) {
                    error.Unseekable => {
                        r.mode = .streaming_reading;
                        if (pos != 0) @panic("TODO need to seek here");
                        return 0;
                    },
                    else => |e| {
                        r.err = e;
                        return error.ReadFailed;
                    },
                };
                if (n == 0) return error.EndOfStream;
                r.pos = pos + n;
                bw.advance(n);
                return n;
            },
            .streaming_reading => {
                const dest = limit.slice(try bw.writableSliceGreedy(1));
                const n = file.read(dest) catch |err| {
                    r.err = err;
                    return error.ReadFailed;
                };
                if (n == 0) return error.EndOfStream;
                r.pos = pos + n;
                bw.advance(n);
                return n;
            },
        }
    }

    fn readVec(context: ?*anyopaque, data: []const []u8) std.io.Reader.Error!usize {
        const r: *Reader = @ptrCast(@alignCast(context));
        const handle = r.file.handle;
        const pos = r.pos;

        switch (r.mode) {
            .positional, .positional_reading => {
                if (is_windows) {
                    // Unfortunately, `ReadFileScatter` cannot be used since it requires
                    // page alignment, so we are stuck using only the first slice.
                    // Avoid empty slices to prevent false positive end detections.
                    var i: usize = 0;
                    while (true) : (i += 1) {
                        if (i >= data.len) return .{};
                        if (data[i].len > 0) break;
                    }
                    const n = windows.ReadFile(handle, data[i], pos) catch |err| {
                        r.err = err;
                        return error.ReadFailed;
                    };
                    if (n == 0) return error.EndOfFile;
                    r.pos = pos + n;
                    return n;
                }

                var iovecs: [max_buffers_len]std.posix.iovec = undefined;
                var iovecs_i: usize = 0;
                for (data) |d| {
                    // Since the OS checks pointer address before length, we must omit
                    // length-zero vectors.
                    if (d.len == 0) continue;
                    iovecs[iovecs_i] = .{ .base = d.ptr, .len = d.len };
                    iovecs_i += 1;
                    if (iovecs_i >= iovecs.len) break;
                }
                const send_vecs = iovecs[0..iovecs_i];
                if (send_vecs.len == 0) return 0; // Prevent false positive end detection on empty `data`.
                const n = posix.preadv(handle, send_vecs, pos) catch |err| switch (err) {
                    error.Unseekable => {
                        r.mode = r.mode.toStreaming();
                        assert(pos == 0);
                        return 0;
                    },
                    else => |e| {
                        r.err = e;
                        return error.ReadFailed;
                    },
                };
                if (n == 0) return error.EndOfStream;
                r.pos = pos + n;
                return n;
            },
            .streaming, .streaming_reading => {
                if (is_windows) {
                    // Unfortunately, `ReadFileScatter` cannot be used since it requires
                    // page alignment, so we are stuck using only the first slice.
                    // Avoid empty slices to prevent false positive end detections.
                    var i: usize = 0;
                    while (true) : (i += 1) {
                        if (i >= data.len) return .{};
                        if (data[i].len > 0) break;
                    }
                    const n = windows.ReadFile(handle, data[i], null) catch |err| {
                        r.err = err;
                        return error.ReadFailed;
                    };
                    if (n == 0) return error.EndOfFile;
                    r.pos = pos + n;
                    return n;
                }

                var iovecs: [max_buffers_len]std.posix.iovec = undefined;
                var iovecs_i: usize = 0;
                for (data) |d| {
                    // Since the OS checks pointer address before length, we must omit
                    // length-zero vectors.
                    if (d.len == 0) continue;
                    iovecs[iovecs_i] = .{ .base = d.ptr, .len = d.len };
                    iovecs_i += 1;
                    if (iovecs_i >= iovecs.len) break;
                }
                const send_vecs = iovecs[0..iovecs_i];
                if (send_vecs.len == 0) return 0; // Prevent false positive end detection on empty `data`.
                const n = posix.readv(handle, send_vecs) catch |err| {
                    r.err = err;
                    return error.ReadFailed;
                };
                if (n == 0) return error.EndOfStream;
                r.pos = pos + n;
                return n;
            },
        }
    }

    fn discard(context: ?*anyopaque, limit: std.io.Reader.Limit) std.io.Reader.Error!usize {
        const r: *Reader = @ptrCast(@alignCast(context));
        const file = r.file;
        const pos = r.pos;
        switch (r.mode) {
            .positional, .positional_reading => {
                const size = r.size orelse {
                    if (file.getEndPos()) |size| {
                        r.size = size;
                    } else |err| {
                        r.size_err = err;
                        r.mode = r.mode.toStreaming();
                    }
                    return 0;
                };
                const delta = @min(@intFromEnum(limit), size - pos);
                r.pos = pos + delta;
                return delta;
            },
            .streaming, .streaming_reading => {
                // Unfortunately we can't seek forward without knowing the
                // size because the seek syscalls provided to us will not
                // return the true end position if a seek would exceed the
                // end.
                fallback: {
                    if (r.size_err == null and r.seek_err == null) break :fallback;
                    var trash_buffer: [128]u8 = undefined;
                    const trash = &trash_buffer;
                    if (is_windows) {
                        const n = windows.ReadFile(file.handle, trash, null) catch |err| {
                            r.err = err;
                            return error.ReadFailed;
                        };
                        if (n == 0) return error.EndOfStream;
                        r.pos = pos + n;
                        return n;
                    }
                    var iovecs: [max_buffers_len]std.posix.iovec = undefined;
                    var iovecs_i: usize = 0;
                    var remaining = @intFromEnum(limit);
                    while (remaining > 0 and iovecs_i < iovecs.len) {
                        iovecs[iovecs_i] = .{ .base = trash, .len = @min(trash.len, remaining) };
                        remaining -= iovecs[iovecs_i].len;
                        iovecs_i += 1;
                    }
                    const n = posix.readv(file.handle, iovecs[0..iovecs_i]) catch |err| {
                        r.err = err;
                        return error.ReadFailed;
                    };
                    if (n == 0) return error.EndOfStream;
                    r.pos = pos + n;
                    return n;
                }
                const size = r.size orelse {
                    if (file.getEndPos()) |size| {
                        r.size = size;
                    } else |err| {
                        r.size_err = err;
                    }
                    return 0;
                };
                const n = @min(size - pos, std.math.maxInt(i64), @intFromEnum(limit));
                file.seekBy(n) catch |err| {
                    r.seek_err = err;
                    return 0;
                };
                r.pos = pos + n;
                return n;
            },
        }
    }
};

pub const Writer = struct {
    file: File,
    err: ?WriteError = null,
    mode: Writer.Mode = .positional,
    pos: u64 = 0,
    sendfile_err: ?SendfileError = null,
    read_err: ?ReadError = null,
    seek_err: ?SeekError = null,

    pub const Mode = Reader.Mode;

    pub const SendfileError = error{
        UnsupportedOperation,
        Unexpected,
    };

    /// Number of slices to store on the stack, when trying to send as many byte
    /// vectors through the underlying write calls as possible.
    const max_buffers_len = 16;

    pub fn interface(w: *Writer) std.io.Writer {
        return .{
            .context = w,
            .vtable = &.{
                .writeSplat = writeSplat,
                .writeFile = writeFile,
            },
        };
    }

    pub fn writable(w: *Writer, buffer: []u8) std.io.BufferedWriter {
        return interface(w).buffered(buffer);
    }

    pub fn moveToReader(w: *Writer) Reader {
        defer w.* = undefined;
        return .{
            .file = w.file,
            .mode = w.mode,
            .pos = w.pos,
            .seek_err = w.seek_err,
        };
    }

    pub fn writeSplat(context: ?*anyopaque, data: []const []const u8, splat: usize) std.io.Writer.Error!usize {
        const w: *Writer = @ptrCast(@alignCast(context));
        const handle = w.file.handle;
        var splat_buffer: [256]u8 = undefined;
        if (is_windows) {
            if (data.len == 1 and splat == 0) return 0;
            return windows.WriteFile(handle, data[0], null);
        }
        var iovecs: [max_buffers_len]std.posix.iovec_const = undefined;
        var len: usize = @min(iovecs.len, data.len);
        for (iovecs[0..len], data[0..len]) |*v, d| v.* = .{
            .base = if (d.len == 0) "" else d.ptr, // OS sadly checks ptr addr before length.
            .len = d.len,
        };
        switch (splat) {
            0 => return std.posix.writev(handle, iovecs[0 .. len - 1]) catch |err| {
                w.err = err;
                return error.WriteFailed;
            },
            1 => return std.posix.writev(handle, iovecs[0..len]) catch |err| {
                w.err = err;
                return error.WriteFailed;
            },
            else => {
                const pattern = data[data.len - 1];
                if (pattern.len == 1) {
                    const memset_len = @min(splat_buffer.len, splat);
                    const buf = splat_buffer[0..memset_len];
                    @memset(buf, pattern[0]);
                    iovecs[len - 1] = .{ .base = buf.ptr, .len = buf.len };
                    var remaining_splat = splat - buf.len;
                    while (remaining_splat > splat_buffer.len and len < iovecs.len) {
                        iovecs[len] = .{ .base = &splat_buffer, .len = splat_buffer.len };
                        remaining_splat -= splat_buffer.len;
                        len += 1;
                    }
                    if (remaining_splat > 0 and len < iovecs.len) {
                        iovecs[len] = .{ .base = &splat_buffer, .len = remaining_splat };
                        len += 1;
                    }
                    return std.posix.writev(handle, iovecs[0..len]) catch |err| {
                        w.err = err;
                        return error.WriteFailed;
                    };
                }
            },
        }
        return std.posix.writev(handle, iovecs[0..len]) catch |err| {
            w.err = err;
            return error.WriteFailed;
        };
    }

    pub fn writeFile(
        context: ?*anyopaque,
        in_file: std.fs.File,
        in_offset: std.io.Writer.Offset,
        in_limit: std.io.Limit,
        headers_and_trailers: []const []const u8,
        headers_len: usize,
    ) std.io.Writer.FileError!usize {
        const w: *Writer = @ptrCast(@alignCast(context));
        const out_fd = w.file.handle;
        const in_fd = in_file.handle;
        // TODO try using copy_file_range on Linux
        // TODO try using copy_file_range on FreeBSD
        // TODO try using sendfile on macOS
        // TODO try using sendfile on FreeBSD
        if (native_os == .linux and w.mode == .streaming) sf: {
            // Try using sendfile on Linux.
            if (w.sendfile_err != null) break :sf;
            // Linux sendfile does not support headers or trailers but it does
            // support a streaming read from in_file.
            if (headers_len > 0) return writeSplat(context, headers_and_trailers[0..headers_len], 1);
            const max_count = 0x7ffff000; // Avoid EINVAL.
            const smaller_len = in_limit.minInt(max_count);
            var off: std.os.linux.off_t = undefined;
            const off_ptr: ?*std.os.linux.off_t = if (in_offset.toInt()) |offset| b: {
                off = std.math.cast(std.os.linux.off_t, offset) orelse
                    return writeSplat(context, headers_and_trailers, 1);
                break :b &off;
            } else null;
            const n = std.os.linux.wrapped.sendfile(out_fd, in_fd, off_ptr, smaller_len) catch |err| switch (err) {
                // Errors that imply sendfile should be avoided on the next write.
                error.UnsupportedOperation,
                error.Unexpected,
                => |e| {
                    w.sendfile_err = e;
                    break :sf;
                },
                else => |e| return e,
            };
            w.pos += n;
            return n;
        }
        return error.Unimplemented;
    }

    pub fn seekTo(w: *Writer, offset: u64) SeekError!void {
        if (w.seek_err) |err| return err;
        switch (w.mode) {
            .positional, .positional_reading => {
                w.pos = offset;
            },
            .streaming, .streaming_reading => {
                posix.lseek_SET(w.file.handle, offset) catch |err| {
                    w.seek_err = err;
                    return err;
                };
            },
        }
    }
};

/// Defaults to positional reading; falls back to streaming.
///
/// Positional is more threadsafe, since the global seek position is not
/// affected.
pub fn reader(file: File) Reader {
    return .{ .file = file };
}

/// Positional is more threadsafe, since the global seek position is not
/// affected, but when such syscalls are not available, preemptively choosing
/// `Reader.Mode.streaming` will skip a failed syscall.
pub fn readerStreaming(file: File) Reader {
    return .{
        .file = file,
        .mode = .streaming,
        .seek_err = error.Unseekable,
    };
}

/// Defaults to positional reading; falls back to streaming.
///
/// Positional is more threadsafe, since the global seek position is not
/// affected.
pub fn writer(file: File) Writer {
    return .{ .file = file };
}

/// Positional is more threadsafe, since the global seek position is not
/// affected, but when such syscalls are not available, preemptively choosing
/// `Writer.Mode.streaming` will skip a failed syscall.
pub fn writerStreaming(file: File) Writer {
    return .{
        .file = file,
        .mode = .streaming,
    };
}

const range_off: windows.LARGE_INTEGER = 0;
const range_len: windows.LARGE_INTEGER = 1;

pub const LockError = error{
    SystemResources,
    FileLocksNotSupported,
} || posix.UnexpectedError;

/// Blocks when an incompatible lock is held by another process.
/// A process may hold only one type of lock (shared or exclusive) on
/// a file. When a process terminates in any way, the lock is released.
///
/// Assumes the file is unlocked.
///
/// TODO: integrate with async I/O
pub fn lock(file: File, l: Lock) LockError!void {
    if (is_windows) {
        var io_status_block: windows.IO_STATUS_BLOCK = undefined;
        const exclusive = switch (l) {
            .none => return,
            .shared => false,
            .exclusive => true,
        };
        return windows.LockFile(
            file.handle,
            null,
            null,
            null,
            &io_status_block,
            &range_off,
            &range_len,
            null,
            windows.FALSE, // non-blocking=false
            @intFromBool(exclusive),
        ) catch |err| switch (err) {
            error.WouldBlock => unreachable, // non-blocking=false
            else => |e| return e,
        };
    } else {
        return posix.flock(file.handle, switch (l) {
            .none => posix.LOCK.UN,
            .shared => posix.LOCK.SH,
            .exclusive => posix.LOCK.EX,
        }) catch |err| switch (err) {
            error.WouldBlock => unreachable, // non-blocking=false
            else => |e| return e,
        };
    }
}

/// Assumes the file is locked.
pub fn unlock(file: File) void {
    if (is_windows) {
        var io_status_block: windows.IO_STATUS_BLOCK = undefined;
        return windows.UnlockFile(
            file.handle,
            &io_status_block,
            &range_off,
            &range_len,
            null,
        ) catch |err| switch (err) {
            error.RangeNotLocked => unreachable, // Function assumes unlocked.
            error.Unexpected => unreachable, // Resource deallocation must succeed.
        };
    } else {
        return posix.flock(file.handle, posix.LOCK.UN) catch |err| switch (err) {
            error.WouldBlock => unreachable, // unlocking can't block
            error.SystemResources => unreachable, // We are deallocating resources.
            error.FileLocksNotSupported => unreachable, // We already got the lock.
            error.Unexpected => unreachable, // Resource deallocation must succeed.
        };
    }
}

/// Attempts to obtain a lock, returning `true` if the lock is
/// obtained, and `false` if there was an existing incompatible lock held.
/// A process may hold only one type of lock (shared or exclusive) on
/// a file. When a process terminates in any way, the lock is released.
///
/// Assumes the file is unlocked.
///
/// TODO: integrate with async I/O
pub fn tryLock(file: File, l: Lock) LockError!bool {
    if (is_windows) {
        var io_status_block: windows.IO_STATUS_BLOCK = undefined;
        const exclusive = switch (l) {
            .none => return,
            .shared => false,
            .exclusive => true,
        };
        windows.LockFile(
            file.handle,
            null,
            null,
            null,
            &io_status_block,
            &range_off,
            &range_len,
            null,
            windows.TRUE, // non-blocking=true
            @intFromBool(exclusive),
        ) catch |err| switch (err) {
            error.WouldBlock => return false,
            else => |e| return e,
        };
    } else {
        posix.flock(file.handle, switch (l) {
            .none => posix.LOCK.UN,
            .shared => posix.LOCK.SH | posix.LOCK.NB,
            .exclusive => posix.LOCK.EX | posix.LOCK.NB,
        }) catch |err| switch (err) {
            error.WouldBlock => return false,
            else => |e| return e,
        };
    }
    return true;
}

/// Assumes the file is already locked in exclusive mode.
/// Atomically modifies the lock to be in shared mode, without releasing it.
///
/// TODO: integrate with async I/O
pub fn downgradeLock(file: File) LockError!void {
    if (is_windows) {
        // On Windows it works like a semaphore + exclusivity flag. To implement this
        // function, we first obtain another lock in shared mode. This changes the
        // exclusivity flag, but increments the semaphore to 2. So we follow up with
        // an NtUnlockFile which decrements the semaphore but does not modify the
        // exclusivity flag.
        var io_status_block: windows.IO_STATUS_BLOCK = undefined;
        windows.LockFile(
            file.handle,
            null,
            null,
            null,
            &io_status_block,
            &range_off,
            &range_len,
            null,
            windows.TRUE, // non-blocking=true
            windows.FALSE, // exclusive=false
        ) catch |err| switch (err) {
            error.WouldBlock => unreachable, // File was not locked in exclusive mode.
            else => |e| return e,
        };
        return windows.UnlockFile(
            file.handle,
            &io_status_block,
            &range_off,
            &range_len,
            null,
        ) catch |err| switch (err) {
            error.RangeNotLocked => unreachable, // File was not locked.
            error.Unexpected => unreachable, // Resource deallocation must succeed.
        };
    } else {
        return posix.flock(file.handle, posix.LOCK.SH | posix.LOCK.NB) catch |err| switch (err) {
            error.WouldBlock => unreachable, // File was not locked in exclusive mode.
            else => |e| return e,
        };
    }
}

const builtin = @import("builtin");
const Os = std.builtin.Os;
const native_os = builtin.os.tag;
const is_windows = native_os == .windows;

const File = @This();
const std = @import("../std.zig");
const Allocator = std.mem.Allocator;
const posix = std.posix;
const io = std.io;
const math = std.math;
const assert = std.debug.assert;
const linux = std.os.linux;
const windows = std.os.windows;
const maxInt = std.math.maxInt;
const Alignment = std.mem.Alignment;
const BufferedWriter = std.io.BufferedWriter;
