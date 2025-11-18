//! Deprecated in favor of `Io.Dir`.
const Dir = @This();

const builtin = @import("builtin");
const native_os = builtin.os.tag;

const std = @import("../std.zig");
const Io = std.Io;
const File = std.fs.File;
const AtomicFile = std.fs.AtomicFile;
const base64_encoder = fs.base64_encoder;
const posix = std.posix;
const mem = std.mem;
const path = fs.path;
const fs = std.fs;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const linux = std.os.linux;
const windows = std.os.windows;
const have_flock = @TypeOf(posix.system.flock) != void;

fd: Handle,

pub const Handle = posix.fd_t;

pub const default_mode = 0o755;

pub const Entry = struct {
    name: []const u8,
    kind: Kind,

    pub const Kind = File.Kind;
};

const IteratorError = error{
    AccessDenied,
    PermissionDenied,
    SystemResources,
} || posix.UnexpectedError;

pub const Iterator = switch (native_os) {
    .driverkit, .ios, .maccatalyst, .macos, .tvos, .visionos, .watchos, .freebsd, .netbsd, .dragonfly, .openbsd, .illumos => struct {
        dir: Dir,
        seek: i64,
        buf: [1024]u8 align(@alignOf(posix.system.dirent)),
        index: usize,
        end_index: usize,
        first_iter: bool,

        const Self = @This();

        pub const Error = IteratorError;

        /// Memory such as file names referenced in this returned entry becomes invalid
        /// with subsequent calls to `next`, as well as when this `Dir` is deinitialized.
        pub fn next(self: *Self) Error!?Entry {
            switch (native_os) {
                .driverkit, .ios, .maccatalyst, .macos, .tvos, .visionos, .watchos => return self.nextDarwin(),
                .freebsd, .netbsd, .dragonfly, .openbsd => return self.nextBsd(),
                .illumos => return self.nextIllumos(),
                else => @compileError("unimplemented"),
            }
        }

        fn nextDarwin(self: *Self) !?Entry {
            start_over: while (true) {
                if (self.index >= self.end_index) {
                    if (self.first_iter) {
                        posix.lseek_SET(self.dir.fd, 0) catch unreachable; // EBADF here likely means that the Dir was not opened with iteration permissions
                        self.first_iter = false;
                    }
                    const rc = posix.system.getdirentries(
                        self.dir.fd,
                        &self.buf,
                        self.buf.len,
                        &self.seek,
                    );
                    if (rc == 0) return null;
                    if (rc < 0) {
                        switch (posix.errno(rc)) {
                            .BADF => unreachable, // Dir is invalid or was opened without iteration ability
                            .FAULT => unreachable,
                            .NOTDIR => unreachable,
                            .INVAL => unreachable,
                            else => |err| return posix.unexpectedErrno(err),
                        }
                    }
                    self.index = 0;
                    self.end_index = @as(usize, @intCast(rc));
                }
                const darwin_entry = @as(*align(1) posix.system.dirent, @ptrCast(&self.buf[self.index]));
                const next_index = self.index + darwin_entry.reclen;
                self.index = next_index;

                const name = @as([*]u8, @ptrCast(&darwin_entry.name))[0..darwin_entry.namlen];

                if (mem.eql(u8, name, ".") or mem.eql(u8, name, "..") or (darwin_entry.ino == 0)) {
                    continue :start_over;
                }

                const entry_kind: Entry.Kind = switch (darwin_entry.type) {
                    posix.DT.BLK => .block_device,
                    posix.DT.CHR => .character_device,
                    posix.DT.DIR => .directory,
                    posix.DT.FIFO => .named_pipe,
                    posix.DT.LNK => .sym_link,
                    posix.DT.REG => .file,
                    posix.DT.SOCK => .unix_domain_socket,
                    posix.DT.WHT => .whiteout,
                    else => .unknown,
                };
                return Entry{
                    .name = name,
                    .kind = entry_kind,
                };
            }
        }

        fn nextIllumos(self: *Self) !?Entry {
            start_over: while (true) {
                if (self.index >= self.end_index) {
                    if (self.first_iter) {
                        posix.lseek_SET(self.dir.fd, 0) catch unreachable; // EBADF here likely means that the Dir was not opened with iteration permissions
                        self.first_iter = false;
                    }
                    const rc = posix.system.getdents(self.dir.fd, &self.buf, self.buf.len);
                    switch (posix.errno(rc)) {
                        .SUCCESS => {},
                        .BADF => unreachable, // Dir is invalid or was opened without iteration ability
                        .FAULT => unreachable,
                        .NOTDIR => unreachable,
                        .INVAL => unreachable,
                        else => |err| return posix.unexpectedErrno(err),
                    }
                    if (rc == 0) return null;
                    self.index = 0;
                    self.end_index = @as(usize, @intCast(rc));
                }
                const entry = @as(*align(1) posix.system.dirent, @ptrCast(&self.buf[self.index]));
                const next_index = self.index + entry.reclen;
                self.index = next_index;

                const name = mem.sliceTo(@as([*:0]u8, @ptrCast(&entry.name)), 0);
                if (mem.eql(u8, name, ".") or mem.eql(u8, name, ".."))
                    continue :start_over;

                // illumos dirent doesn't expose type, so we have to call stat to get it.
                const stat_info = posix.fstatat(
                    self.dir.fd,
                    name,
                    posix.AT.SYMLINK_NOFOLLOW,
                ) catch |err| switch (err) {
                    error.NameTooLong => unreachable,
                    error.SymLinkLoop => unreachable,
                    error.FileNotFound => unreachable, // lost the race
                    else => |e| return e,
                };
                const entry_kind: Entry.Kind = switch (stat_info.mode & posix.S.IFMT) {
                    posix.S.IFIFO => .named_pipe,
                    posix.S.IFCHR => .character_device,
                    posix.S.IFDIR => .directory,
                    posix.S.IFBLK => .block_device,
                    posix.S.IFREG => .file,
                    posix.S.IFLNK => .sym_link,
                    posix.S.IFSOCK => .unix_domain_socket,
                    posix.S.IFDOOR => .door,
                    posix.S.IFPORT => .event_port,
                    else => .unknown,
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
                    if (self.first_iter) {
                        posix.lseek_SET(self.dir.fd, 0) catch unreachable; // EBADF here likely means that the Dir was not opened with iteration permissions
                        self.first_iter = false;
                    }
                    const rc = posix.system.getdents(self.dir.fd, &self.buf, self.buf.len);
                    switch (posix.errno(rc)) {
                        .SUCCESS => {},
                        .BADF => unreachable, // Dir is invalid or was opened without iteration ability
                        .FAULT => unreachable,
                        .NOTDIR => unreachable,
                        .INVAL => unreachable,
                        // Introduced in freebsd 13.2: directory unlinked but still open.
                        // To be consistent, iteration ends if the directory being iterated is deleted during iteration.
                        .NOENT => return null,
                        else => |err| return posix.unexpectedErrno(err),
                    }
                    if (rc == 0) return null;
                    self.index = 0;
                    self.end_index = @as(usize, @intCast(rc));
                }
                const bsd_entry = @as(*align(1) posix.system.dirent, @ptrCast(&self.buf[self.index]));
                const next_index = self.index +
                    if (@hasField(posix.system.dirent, "reclen")) bsd_entry.reclen else bsd_entry.reclen();
                self.index = next_index;

                const name = @as([*]u8, @ptrCast(&bsd_entry.name))[0..bsd_entry.namlen];

                const skip_zero_fileno = switch (native_os) {
                    // fileno=0 is used to mark invalid entries or deleted files.
                    .openbsd, .netbsd => true,
                    else => false,
                };
                if (mem.eql(u8, name, ".") or mem.eql(u8, name, "..") or
                    (skip_zero_fileno and bsd_entry.fileno == 0))
                {
                    continue :start_over;
                }

                const entry_kind: Entry.Kind = switch (bsd_entry.type) {
                    posix.DT.BLK => .block_device,
                    posix.DT.CHR => .character_device,
                    posix.DT.DIR => .directory,
                    posix.DT.FIFO => .named_pipe,
                    posix.DT.LNK => .sym_link,
                    posix.DT.REG => .file,
                    posix.DT.SOCK => .unix_domain_socket,
                    posix.DT.WHT => .whiteout,
                    else => .unknown,
                };
                return Entry{
                    .name = name,
                    .kind = entry_kind,
                };
            }
        }

        pub fn reset(self: *Self) void {
            self.index = 0;
            self.end_index = 0;
            self.first_iter = true;
        }
    },
    .haiku => struct {
        dir: Dir,
        buf: [@sizeOf(DirEnt) + posix.PATH_MAX]u8 align(@alignOf(DirEnt)),
        offset: usize,
        index: usize,
        end_index: usize,
        first_iter: bool,

        const Self = @This();
        const DirEnt = posix.system.DirEnt;

        pub const Error = IteratorError;

        /// Memory such as file names referenced in this returned entry becomes invalid
        /// with subsequent calls to `next`, as well as when this `Dir` is deinitialized.
        pub fn next(self: *Self) Error!?Entry {
            while (true) {
                if (self.index >= self.end_index) {
                    if (self.first_iter) {
                        switch (@as(posix.E, @enumFromInt(posix.system._kern_rewind_dir(self.dir.fd)))) {
                            .SUCCESS => {},
                            .BADF => unreachable, // Dir is invalid
                            .FAULT => unreachable,
                            .NOTDIR => unreachable,
                            .INVAL => unreachable,
                            .ACCES => return error.AccessDenied,
                            .PERM => return error.PermissionDenied,
                            else => |err| return posix.unexpectedErrno(err),
                        }
                        self.first_iter = false;
                    }
                    const rc = posix.system._kern_read_dir(
                        self.dir.fd,
                        &self.buf,
                        self.buf.len,
                        self.buf.len / @sizeOf(DirEnt),
                    );
                    if (rc == 0) return null;
                    if (rc < 0) {
                        switch (@as(posix.E, @enumFromInt(rc))) {
                            .BADF => unreachable, // Dir is invalid
                            .FAULT => unreachable,
                            .NOTDIR => unreachable,
                            .INVAL => unreachable,
                            .OVERFLOW => unreachable,
                            .ACCES => return error.AccessDenied,
                            .PERM => return error.PermissionDenied,
                            else => |err| return posix.unexpectedErrno(err),
                        }
                    }
                    self.offset = 0;
                    self.index = 0;
                    self.end_index = @intCast(rc);
                }
                const dirent: *DirEnt = @ptrCast(@alignCast(&self.buf[self.offset]));
                self.offset += dirent.reclen;
                self.index += 1;
                const name = mem.span(dirent.getName());
                if (mem.eql(u8, name, ".") or mem.eql(u8, name, "..") or dirent.ino == 0) continue;

                var stat_info: posix.Stat = undefined;
                switch (@as(posix.E, @enumFromInt(posix.system._kern_read_stat(
                    self.dir.fd,
                    name,
                    false,
                    &stat_info,
                    @sizeOf(posix.Stat),
                )))) {
                    .SUCCESS => {},
                    .INVAL => unreachable,
                    .BADF => unreachable, // Dir is invalid
                    .NOMEM => return error.SystemResources,
                    .ACCES => return error.AccessDenied,
                    .PERM => return error.PermissionDenied,
                    .FAULT => unreachable,
                    .NAMETOOLONG => unreachable,
                    .LOOP => unreachable,
                    .NOENT => continue,
                    else => |err| return posix.unexpectedErrno(err),
                }
                const statmode = stat_info.mode & posix.S.IFMT;

                const entry_kind: Entry.Kind = switch (statmode) {
                    posix.S.IFDIR => .directory,
                    posix.S.IFBLK => .block_device,
                    posix.S.IFCHR => .character_device,
                    posix.S.IFLNK => .sym_link,
                    posix.S.IFREG => .file,
                    posix.S.IFIFO => .named_pipe,
                    else => .unknown,
                };

                return Entry{
                    .name = name,
                    .kind = entry_kind,
                };
            }
        }

        pub fn reset(self: *Self) void {
            self.index = 0;
            self.end_index = 0;
            self.first_iter = true;
        }
    },
    .linux => struct {
        dir: Dir,
        buf: [1024]u8 align(@alignOf(linux.dirent64)),
        index: usize,
        end_index: usize,
        first_iter: bool,

        const Self = @This();

        pub const Error = IteratorError;

        /// Memory such as file names referenced in this returned entry becomes invalid
        /// with subsequent calls to `next`, as well as when this `Dir` is deinitialized.
        pub fn next(self: *Self) Error!?Entry {
            return self.nextLinux() catch |err| switch (err) {
                // To be consistent across platforms, iteration ends if the directory being iterated is deleted during iteration.
                // This matches the behavior of non-Linux UNIX platforms.
                error.DirNotFound => null,
                else => |e| return e,
            };
        }

        pub const ErrorLinux = error{DirNotFound} || IteratorError;

        /// Implementation of `next` that can return `error.DirNotFound` if the directory being
        /// iterated was deleted during iteration (this error is Linux specific).
        pub fn nextLinux(self: *Self) ErrorLinux!?Entry {
            start_over: while (true) {
                if (self.index >= self.end_index) {
                    if (self.first_iter) {
                        posix.lseek_SET(self.dir.fd, 0) catch unreachable; // EBADF here likely means that the Dir was not opened with iteration permissions
                        self.first_iter = false;
                    }
                    const rc = linux.getdents64(self.dir.fd, &self.buf, self.buf.len);
                    switch (linux.E.init(rc)) {
                        .SUCCESS => {},
                        .BADF => unreachable, // Dir is invalid or was opened without iteration ability
                        .FAULT => unreachable,
                        .NOTDIR => unreachable,
                        .NOENT => return error.DirNotFound, // The directory being iterated was deleted during iteration.
                        .INVAL => return error.Unexpected, // Linux may in some cases return EINVAL when reading /proc/$PID/net.
                        .ACCES => return error.AccessDenied, // Do not have permission to iterate this directory.
                        else => |err| return posix.unexpectedErrno(err),
                    }
                    if (rc == 0) return null;
                    self.index = 0;
                    self.end_index = rc;
                }
                const linux_entry = @as(*align(1) linux.dirent64, @ptrCast(&self.buf[self.index]));
                const next_index = self.index + linux_entry.reclen;
                self.index = next_index;

                const name = mem.sliceTo(@as([*:0]u8, @ptrCast(&linux_entry.name)), 0);

                // skip . and .. entries
                if (mem.eql(u8, name, ".") or mem.eql(u8, name, "..")) {
                    continue :start_over;
                }

                const entry_kind: Entry.Kind = switch (linux_entry.type) {
                    linux.DT.BLK => .block_device,
                    linux.DT.CHR => .character_device,
                    linux.DT.DIR => .directory,
                    linux.DT.FIFO => .named_pipe,
                    linux.DT.LNK => .sym_link,
                    linux.DT.REG => .file,
                    linux.DT.SOCK => .unix_domain_socket,
                    else => .unknown,
                };
                return Entry{
                    .name = name,
                    .kind = entry_kind,
                };
            }
        }

        pub fn reset(self: *Self) void {
            self.index = 0;
            self.end_index = 0;
            self.first_iter = true;
        }
    },
    .windows => struct {
        dir: Dir,
        buf: [1024]u8 align(@alignOf(windows.FILE_BOTH_DIR_INFORMATION)),
        index: usize,
        end_index: usize,
        first_iter: bool,
        name_data: [fs.max_name_bytes]u8,

        const Self = @This();

        pub const Error = IteratorError;

        /// Memory such as file names referenced in this returned entry becomes invalid
        /// with subsequent calls to `next`, as well as when this `Dir` is deinitialized.
        pub fn next(self: *Self) Error!?Entry {
            const w = windows;
            while (true) {
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
                        if (self.first_iter) @as(w.BOOLEAN, w.TRUE) else @as(w.BOOLEAN, w.FALSE),
                    );
                    self.first_iter = false;
                    if (io.Information == 0) return null;
                    self.index = 0;
                    self.end_index = io.Information;
                    switch (rc) {
                        .SUCCESS => {},
                        .ACCESS_DENIED => return error.AccessDenied, // Double-check that the Dir was opened with iteration ability

                        else => return w.unexpectedStatus(rc),
                    }
                }

                // While the official api docs guarantee FILE_BOTH_DIR_INFORMATION to be aligned properly
                // this may not always be the case (e.g. due to faulty VM/Sandboxing tools)
                const dir_info: *align(2) w.FILE_BOTH_DIR_INFORMATION = @ptrCast(@alignCast(&self.buf[self.index]));
                if (dir_info.NextEntryOffset != 0) {
                    self.index += dir_info.NextEntryOffset;
                } else {
                    self.index = self.buf.len;
                }

                const name_wtf16le = @as([*]u16, @ptrCast(&dir_info.FileName))[0 .. dir_info.FileNameLength / 2];

                if (mem.eql(u16, name_wtf16le, &[_]u16{'.'}) or mem.eql(u16, name_wtf16le, &[_]u16{ '.', '.' }))
                    continue;
                const name_wtf8_len = std.unicode.wtf16LeToWtf8(self.name_data[0..], name_wtf16le);
                const name_wtf8 = self.name_data[0..name_wtf8_len];
                const kind: Entry.Kind = blk: {
                    const attrs = dir_info.FileAttributes;
                    if (attrs & w.FILE_ATTRIBUTE_DIRECTORY != 0) break :blk .directory;
                    if (attrs & w.FILE_ATTRIBUTE_REPARSE_POINT != 0) break :blk .sym_link;
                    break :blk .file;
                };
                return Entry{
                    .name = name_wtf8,
                    .kind = kind,
                };
            }
        }

        pub fn reset(self: *Self) void {
            self.index = 0;
            self.end_index = 0;
            self.first_iter = true;
        }
    },
    .wasi => struct {
        dir: Dir,
        buf: [1024]u8 align(@alignOf(std.os.wasi.dirent_t)),
        cookie: u64,
        index: usize,
        end_index: usize,

        const Self = @This();

        pub const Error = IteratorError;

        /// Memory such as file names referenced in this returned entry becomes invalid
        /// with subsequent calls to `next`, as well as when this `Dir` is deinitialized.
        pub fn next(self: *Self) Error!?Entry {
            return self.nextWasi() catch |err| switch (err) {
                // To be consistent across platforms, iteration ends if the directory being iterated is deleted during iteration.
                // This matches the behavior of non-Linux UNIX platforms.
                error.DirNotFound => null,
                else => |e| return e,
            };
        }

        pub const ErrorWasi = error{DirNotFound} || IteratorError;

        /// Implementation of `next` that can return platform-dependent errors depending on the host platform.
        /// When the host platform is Linux, `error.DirNotFound` can be returned if the directory being
        /// iterated was deleted during iteration.
        pub fn nextWasi(self: *Self) ErrorWasi!?Entry {
            // We intentinally use fd_readdir even when linked with libc,
            // since its implementation is exactly the same as below,
            // and we avoid the code complexity here.
            const w = std.os.wasi;
            start_over: while (true) {
                // According to the WASI spec, the last entry might be truncated,
                // so we need to check if the left buffer contains the whole dirent.
                if (self.end_index - self.index < @sizeOf(w.dirent_t)) {
                    var bufused: usize = undefined;
                    switch (w.fd_readdir(self.dir.fd, &self.buf, self.buf.len, self.cookie, &bufused)) {
                        .SUCCESS => {},
                        .BADF => unreachable, // Dir is invalid or was opened without iteration ability
                        .FAULT => unreachable,
                        .NOTDIR => unreachable,
                        .INVAL => unreachable,
                        .NOENT => return error.DirNotFound, // The directory being iterated was deleted during iteration.
                        .NOTCAPABLE => return error.AccessDenied,
                        else => |err| return posix.unexpectedErrno(err),
                    }
                    if (bufused == 0) return null;
                    self.index = 0;
                    self.end_index = bufused;
                }
                const entry = @as(*align(1) w.dirent_t, @ptrCast(&self.buf[self.index]));
                const entry_size = @sizeOf(w.dirent_t);
                const name_index = self.index + entry_size;
                if (name_index + entry.namlen > self.end_index) {
                    // This case, the name is truncated, so we need to call readdir to store the entire name.
                    self.end_index = self.index; // Force fd_readdir in the next loop.
                    continue :start_over;
                }
                const name = self.buf[name_index .. name_index + entry.namlen];

                const next_index = name_index + entry.namlen;
                self.index = next_index;
                self.cookie = entry.next;

                // skip . and .. entries
                if (mem.eql(u8, name, ".") or mem.eql(u8, name, "..")) {
                    continue :start_over;
                }

                const entry_kind: Entry.Kind = switch (entry.type) {
                    .BLOCK_DEVICE => .block_device,
                    .CHARACTER_DEVICE => .character_device,
                    .DIRECTORY => .directory,
                    .SYMBOLIC_LINK => .sym_link,
                    .REGULAR_FILE => .file,
                    .SOCKET_STREAM, .SOCKET_DGRAM => .unix_domain_socket,
                    else => .unknown,
                };
                return Entry{
                    .name = name,
                    .kind = entry_kind,
                };
            }
        }

        pub fn reset(self: *Self) void {
            self.index = 0;
            self.end_index = 0;
            self.cookie = std.os.wasi.DIRCOOKIE_START;
        }
    },
    else => @compileError("unimplemented"),
};

pub fn iterate(self: Dir) Iterator {
    return self.iterateImpl(true);
}

/// Like `iterate`, but will not reset the directory cursor before the first
/// iteration. This should only be used in cases where it is known that the
/// `Dir` has not had its cursor modified yet (e.g. it was just opened).
pub fn iterateAssumeFirstIteration(self: Dir) Iterator {
    return self.iterateImpl(false);
}

fn iterateImpl(self: Dir, first_iter_start_value: bool) Iterator {
    switch (native_os) {
        .driverkit,
        .ios,
        .maccatalyst,
        .macos,
        .tvos,
        .visionos,
        .watchos,
        .freebsd,
        .netbsd,
        .dragonfly,
        .openbsd,
        .illumos,
        => return Iterator{
            .dir = self,
            .seek = 0,
            .index = 0,
            .end_index = 0,
            .buf = undefined,
            .first_iter = first_iter_start_value,
        },
        .linux => return Iterator{
            .dir = self,
            .index = 0,
            .end_index = 0,
            .buf = undefined,
            .first_iter = first_iter_start_value,
        },
        .haiku => return Iterator{
            .dir = self,
            .offset = 0,
            .index = 0,
            .end_index = 0,
            .buf = undefined,
            .first_iter = first_iter_start_value,
        },
        .windows => return Iterator{
            .dir = self,
            .index = 0,
            .end_index = 0,
            .first_iter = first_iter_start_value,
            .buf = undefined,
            .name_data = undefined,
        },
        .wasi => return Iterator{
            .dir = self,
            .cookie = std.os.wasi.DIRCOOKIE_START,
            .index = 0,
            .end_index = 0,
            .buf = undefined,
        },
        else => @compileError("unimplemented"),
    }
}

pub const SelectiveWalker = struct {
    stack: std.ArrayListUnmanaged(Walker.StackItem),
    name_buffer: std.ArrayListUnmanaged(u8),
    allocator: Allocator,

    pub const Error = IteratorError || Allocator.Error;

    /// After each call to this function, and on deinit(), the memory returned
    /// from this function becomes invalid. A copy must be made in order to keep
    /// a reference to the path.
    pub fn next(self: *SelectiveWalker) Error!?Walker.Entry {
        while (self.stack.items.len > 0) {
            const top = &self.stack.items[self.stack.items.len - 1];
            var dirname_len = top.dirname_len;
            if (top.iter.next() catch |err| {
                // If we get an error, then we want the user to be able to continue
                // walking if they want, which means that we need to pop the directory
                // that errored from the stack. Otherwise, all future `next` calls would
                // likely just fail with the same error.
                var item = self.stack.pop().?;
                if (self.stack.items.len != 0) {
                    item.iter.dir.close();
                }
                return err;
            }) |entry| {
                self.name_buffer.shrinkRetainingCapacity(dirname_len);
                if (self.name_buffer.items.len != 0) {
                    try self.name_buffer.append(self.allocator, fs.path.sep);
                    dirname_len += 1;
                }
                try self.name_buffer.ensureUnusedCapacity(self.allocator, entry.name.len + 1);
                self.name_buffer.appendSliceAssumeCapacity(entry.name);
                self.name_buffer.appendAssumeCapacity(0);
                const walker_entry: Walker.Entry = .{
                    .dir = top.iter.dir,
                    .basename = self.name_buffer.items[dirname_len .. self.name_buffer.items.len - 1 :0],
                    .path = self.name_buffer.items[0 .. self.name_buffer.items.len - 1 :0],
                    .kind = entry.kind,
                };
                return walker_entry;
            } else {
                var item = self.stack.pop().?;
                if (self.stack.items.len != 0) {
                    item.iter.dir.close();
                }
            }
        }
        return null;
    }

    /// Traverses into the directory, continuing walking one level down.
    pub fn enter(self: *SelectiveWalker, entry: Walker.Entry) !void {
        if (entry.kind != .directory) {
            @branchHint(.cold);
            return;
        }

        var new_dir = entry.dir.openDir(entry.basename, .{ .iterate = true }) catch |err| {
            switch (err) {
                error.NameTooLong => unreachable,
                else => |e| return e,
            }
        };
        errdefer new_dir.close();

        try self.stack.append(self.allocator, .{
            .iter = new_dir.iterateAssumeFirstIteration(),
            .dirname_len = self.name_buffer.items.len - 1,
        });
    }

    pub fn deinit(self: *SelectiveWalker) void {
        self.name_buffer.deinit(self.allocator);
        self.stack.deinit(self.allocator);
    }

    /// Leaves the current directory, continuing walking one level up.
    /// If the current entry is a directory entry, then the "current directory"
    /// will pertain to that entry if `enter` is called before `leave`.
    pub fn leave(self: *SelectiveWalker) void {
        var item = self.stack.pop().?;
        if (self.stack.items.len != 0) {
            @branchHint(.likely);
            item.iter.dir.close();
        }
    }
};

/// Recursively iterates over a directory, but requires the user to
/// opt-in to recursing into each directory entry.
///
/// `self` must have been opened with `OpenOptions{.iterate = true}`.
///
/// `Walker.deinit` releases allocated memory and directory handles.
///
/// The order of returned file system entries is undefined.
///
/// `self` will not be closed after walking it.
///
/// See also `walk`.
pub fn walkSelectively(self: Dir, allocator: Allocator) !SelectiveWalker {
    var stack: std.ArrayListUnmanaged(Walker.StackItem) = .empty;

    try stack.append(allocator, .{
        .iter = self.iterate(),
        .dirname_len = 0,
    });

    return .{
        .stack = stack,
        .name_buffer = .{},
        .allocator = allocator,
    };
}

pub const Walker = struct {
    inner: SelectiveWalker,

    pub const Entry = struct {
        /// The containing directory. This can be used to operate directly on `basename`
        /// rather than `path`, avoiding `error.NameTooLong` for deeply nested paths.
        /// The directory remains open until `next` or `deinit` is called.
        dir: Dir,
        basename: [:0]const u8,
        path: [:0]const u8,
        kind: Dir.Entry.Kind,

        /// Returns the depth of the entry relative to the initial directory.
        /// Returns 1 for a direct child of the initial directory, 2 for an entry
        /// within a direct child of the initial directory, etc.
        pub fn depth(self: Walker.Entry) usize {
            return mem.countScalar(u8, self.path, fs.path.sep) + 1;
        }
    };

    const StackItem = struct {
        iter: Dir.Iterator,
        dirname_len: usize,
    };

    /// After each call to this function, and on deinit(), the memory returned
    /// from this function becomes invalid. A copy must be made in order to keep
    /// a reference to the path.
    pub fn next(self: *Walker) !?Walker.Entry {
        const entry = try self.inner.next();
        if (entry != null and entry.?.kind == .directory) {
            try self.inner.enter(entry.?);
        }
        return entry;
    }

    pub fn deinit(self: *Walker) void {
        self.inner.deinit();
    }

    /// Leaves the current directory, continuing walking one level up.
    /// If the current entry is a directory entry, then the "current directory"
    /// is the directory pertaining to the current entry.
    pub fn leave(self: *Walker) void {
        self.inner.leave();
    }
};

/// Recursively iterates over a directory.
///
/// `self` must have been opened with `OpenOptions{.iterate = true}`.
///
/// `Walker.deinit` releases allocated memory and directory handles.
///
/// The order of returned file system entries is undefined.
///
/// `self` will not be closed after walking it.
///
/// See also `walkSelectively`.
pub fn walk(self: Dir, allocator: Allocator) Allocator.Error!Walker {
    return .{
        .inner = try walkSelectively(self, allocator),
    };
}

pub const OpenError = Io.Dir.OpenError;

pub fn close(self: *Dir) void {
    posix.close(self.fd);
    self.* = undefined;
}

/// Deprecated in favor of `Io.Dir.openFile`.
pub fn openFile(self: Dir, sub_path: []const u8, flags: File.OpenFlags) File.OpenError!File {
    var threaded: Io.Threaded = .init_single_threaded;
    const io = threaded.ioBasic();
    return .adaptFromNewApi(try Io.Dir.openFile(self.adaptToNewApi(), io, sub_path, flags));
}

/// Deprecated in favor of `Io.Dir.createFile`.
pub fn createFile(self: Dir, sub_path: []const u8, flags: File.CreateFlags) File.OpenError!File {
    var threaded: Io.Threaded = .init_single_threaded;
    const io = threaded.ioBasic();
    const new_file = try Io.Dir.createFile(self.adaptToNewApi(), io, sub_path, flags);
    return .adaptFromNewApi(new_file);
}

/// Deprecated in favor of `Io.Dir.MakeError`.
pub const MakeError = Io.Dir.MakeError;

/// Deprecated in favor of `Io.Dir.makeDir`.
pub fn makeDir(self: Dir, sub_path: []const u8) MakeError!void {
    var threaded: Io.Threaded = .init_single_threaded;
    const io = threaded.ioBasic();
    return Io.Dir.makeDir(.{ .handle = self.fd }, io, sub_path);
}

/// Deprecated in favor of `Io.Dir.makeDir`.
pub fn makeDirZ(self: Dir, sub_path: [*:0]const u8) MakeError!void {
    try posix.mkdiratZ(self.fd, sub_path, default_mode);
}

/// Deprecated in favor of `Io.Dir.makeDir`.
pub fn makeDirW(self: Dir, sub_path: [*:0]const u16) MakeError!void {
    try posix.mkdiratW(self.fd, mem.span(sub_path), default_mode);
}

/// Deprecated in favor of `Io.Dir.makePath`.
pub fn makePath(self: Dir, sub_path: []const u8) MakePathError!void {
    _ = try self.makePathStatus(sub_path);
}

/// Deprecated in favor of `Io.Dir.MakePathStatus`.
pub const MakePathStatus = Io.Dir.MakePathStatus;
/// Deprecated in favor of `Io.Dir.MakePathError`.
pub const MakePathError = Io.Dir.MakePathError;

/// Deprecated in favor of `Io.Dir.makePathStatus`.
pub fn makePathStatus(self: Dir, sub_path: []const u8) MakePathError!MakePathStatus {
    var threaded: Io.Threaded = .init_single_threaded;
    const io = threaded.ioBasic();
    return Io.Dir.makePathStatus(.{ .handle = self.fd }, io, sub_path);
}

/// Deprecated in favor of `Io.Dir.makeOpenPath`.
pub fn makeOpenPath(dir: Dir, sub_path: []const u8, options: OpenOptions) Io.Dir.MakeOpenPathError!Dir {
    var threaded: Io.Threaded = .init_single_threaded;
    const io = threaded.ioBasic();
    return .adaptFromNewApi(try Io.Dir.makeOpenPath(dir.adaptToNewApi(), io, sub_path, options));
}

pub const RealPathError = posix.RealPathError || error{Canceled};

///  This function returns the canonicalized absolute pathname of
/// `pathname` relative to this `Dir`. If `pathname` is absolute, ignores this
/// `Dir` handle and returns the canonicalized absolute pathname of `pathname`
/// argument.
/// On Windows, `sub_path` should be encoded as [WTF-8](https://wtf-8.codeberg.page/).
/// On other platforms, `sub_path` is an opaque sequence of bytes with no particular encoding.
/// On Windows, the result is encoded as [WTF-8](https://wtf-8.codeberg.page/).
/// On other platforms, the result is an opaque sequence of bytes with no particular encoding.
/// This function is not universally supported by all platforms.
/// Currently supported hosts are: Linux, macOS, and Windows.
/// See also `Dir.realpathZ`, `Dir.realpathW`, and `Dir.realpathAlloc`.
pub fn realpath(self: Dir, pathname: []const u8, out_buffer: []u8) RealPathError![]u8 {
    if (native_os == .wasi) {
        @compileError("realpath is not available on WASI");
    }
    if (native_os == .windows) {
        var pathname_w = try windows.sliceToPrefixedFileW(self.fd, pathname);

        const wide_slice = try self.realpathW2(pathname_w.span(), &pathname_w.data);

        const len = std.unicode.calcWtf8Len(wide_slice);
        if (len > out_buffer.len)
            return error.NameTooLong;

        const end_index = std.unicode.wtf16LeToWtf8(out_buffer, wide_slice);
        return out_buffer[0..end_index];
    }
    const pathname_c = try posix.toPosixPath(pathname);
    return self.realpathZ(&pathname_c, out_buffer);
}

/// Same as `Dir.realpath` except `pathname` is null-terminated.
/// See also `Dir.realpath`, `realpathZ`.
pub fn realpathZ(self: Dir, pathname: [*:0]const u8, out_buffer: []u8) RealPathError![]u8 {
    if (native_os == .windows) {
        var pathname_w = try windows.cStrToPrefixedFileW(self.fd, pathname);

        const wide_slice = try self.realpathW2(pathname_w.span(), &pathname_w.data);

        const len = std.unicode.calcWtf8Len(wide_slice);
        if (len > out_buffer.len)
            return error.NameTooLong;

        const end_index = std.unicode.wtf16LeToWtf8(out_buffer, wide_slice);
        return out_buffer[0..end_index];
    }

    var flags: posix.O = .{};
    if (@hasField(posix.O, "NONBLOCK")) flags.NONBLOCK = true;
    if (@hasField(posix.O, "CLOEXEC")) flags.CLOEXEC = true;
    if (@hasField(posix.O, "PATH")) flags.PATH = true;

    const fd = posix.openatZ(self.fd, pathname, flags, 0) catch |err| switch (err) {
        error.FileLocksNotSupported => return error.Unexpected,
        error.FileBusy => return error.Unexpected,
        error.WouldBlock => return error.Unexpected,
        else => |e| return e,
    };
    defer posix.close(fd);

    var buffer: [fs.max_path_bytes]u8 = undefined;
    const out_path = try std.os.getFdPath(fd, &buffer);

    if (out_path.len > out_buffer.len) {
        return error.NameTooLong;
    }

    const result = out_buffer[0..out_path.len];
    @memcpy(result, out_path);
    return result;
}

/// Deprecated: use `realpathW2`.
///
/// Windows-only. Same as `Dir.realpath` except `pathname` is WTF16 LE encoded.
/// The result is encoded as [WTF-8](https://wtf-8.codeberg.page/).
/// See also `Dir.realpath`, `realpathW`.
pub fn realpathW(self: Dir, pathname: []const u16, out_buffer: []u8) RealPathError![]u8 {
    var wide_buf: [std.os.windows.PATH_MAX_WIDE]u16 = undefined;
    const wide_slice = try self.realpathW2(pathname, &wide_buf);

    const len = std.unicode.calcWtf8Len(wide_slice);
    if (len > out_buffer.len) return error.NameTooLong;

    const end_index = std.unicode.wtf16LeToWtf8(&out_buffer, wide_slice);
    return out_buffer[0..end_index];
}

/// Windows-only. Same as `Dir.realpath` except
/// * `pathname` and the result are WTF-16 LE encoded
/// * `pathname` is relative or has the NT namespace prefix. See `windows.wToPrefixedFileW` for details.
///
/// Additionally, `pathname` will never be accessed after `out_buffer` has been written to, so it
/// is safe to reuse a single buffer for both.
///
/// See also `Dir.realpath`, `realpathW`.
pub fn realpathW2(self: Dir, pathname: []const u16, out_buffer: []u16) RealPathError![]u16 {
    const w = windows;

    const access_mask = w.GENERIC_READ | w.SYNCHRONIZE;
    const share_access = w.FILE_SHARE_READ | w.FILE_SHARE_WRITE | w.FILE_SHARE_DELETE;
    const creation = w.FILE_OPEN;
    const h_file = blk: {
        const res = w.OpenFile(pathname, .{
            .dir = self.fd,
            .access_mask = access_mask,
            .share_access = share_access,
            .creation = creation,
            .filter = .any,
        }) catch |err| switch (err) {
            error.WouldBlock => unreachable,
            else => |e| return e,
        };
        break :blk res;
    };
    defer w.CloseHandle(h_file);

    return w.GetFinalPathNameByHandle(h_file, .{}, out_buffer);
}

pub const RealPathAllocError = RealPathError || Allocator.Error;

/// Same as `Dir.realpath` except caller must free the returned memory.
/// See also `Dir.realpath`.
pub fn realpathAlloc(self: Dir, allocator: Allocator, pathname: []const u8) RealPathAllocError![]u8 {
    // Use of max_path_bytes here is valid as the realpath function does not
    // have a variant that takes an arbitrary-size buffer.
    // TODO(#4812): Consider reimplementing realpath or using the POSIX.1-2008
    // NULL out parameter (GNU's canonicalize_file_name) to handle overelong
    // paths. musl supports passing NULL but restricts the output to PATH_MAX
    // anyway.
    var buf: [fs.max_path_bytes]u8 = undefined;
    return allocator.dupe(u8, try self.realpath(pathname, buf[0..]));
}

/// Changes the current working directory to the open directory handle.
/// This modifies global state and can have surprising effects in multi-
/// threaded applications. Most applications and especially libraries should
/// not call this function as a general rule, however it can have use cases
/// in, for example, implementing a shell, or child process execution.
/// Not all targets support this. For example, WASI does not have the concept
/// of a current working directory.
pub fn setAsCwd(self: Dir) !void {
    if (native_os == .wasi) {
        @compileError("changing cwd is not currently possible in WASI");
    }
    if (native_os == .windows) {
        var dir_path_buffer: [windows.PATH_MAX_WIDE]u16 = undefined;
        const dir_path = try windows.GetFinalPathNameByHandle(self.fd, .{}, &dir_path_buffer);
        if (builtin.link_libc) {
            return posix.chdirW(dir_path);
        }
        return windows.SetCurrentDirectory(dir_path);
    }
    try posix.fchdir(self.fd);
}

/// Deprecated in favor of `Io.Dir.OpenOptions`.
pub const OpenOptions = Io.Dir.OpenOptions;

/// Deprecated in favor of `Io.Dir.openDir`.
pub fn openDir(self: Dir, sub_path: []const u8, args: OpenOptions) OpenError!Dir {
    var threaded: Io.Threaded = .init_single_threaded;
    const io = threaded.ioBasic();
    return .adaptFromNewApi(try Io.Dir.openDir(.{ .handle = self.fd }, io, sub_path, args));
}

pub const DeleteFileError = posix.UnlinkError;

/// Delete a file name and possibly the file it refers to, based on an open directory handle.
/// On Windows, `sub_path` should be encoded as [WTF-8](https://wtf-8.codeberg.page/).
/// On WASI, `sub_path` should be encoded as valid UTF-8.
/// On other platforms, `sub_path` is an opaque sequence of bytes with no particular encoding.
/// Asserts that the path parameter has no null bytes.
pub fn deleteFile(self: Dir, sub_path: []const u8) DeleteFileError!void {
    if (native_os == .windows) {
        const sub_path_w = try windows.sliceToPrefixedFileW(self.fd, sub_path);
        return self.deleteFileW(sub_path_w.span());
    } else if (native_os == .wasi and !builtin.link_libc) {
        posix.unlinkat(self.fd, sub_path, 0) catch |err| switch (err) {
            error.DirNotEmpty => unreachable, // not passing AT.REMOVEDIR
            else => |e| return e,
        };
    } else {
        const sub_path_c = try posix.toPosixPath(sub_path);
        return self.deleteFileZ(&sub_path_c);
    }
}

/// Same as `deleteFile` except the parameter is null-terminated.
pub fn deleteFileZ(self: Dir, sub_path_c: [*:0]const u8) DeleteFileError!void {
    posix.unlinkatZ(self.fd, sub_path_c, 0) catch |err| switch (err) {
        error.DirNotEmpty => unreachable, // not passing AT.REMOVEDIR
        error.AccessDenied, error.PermissionDenied => |e| switch (native_os) {
            // non-Linux POSIX systems return permission errors when trying to delete a
            // directory, so we need to handle that case specifically and translate the error
            .driverkit, .ios, .maccatalyst, .macos, .tvos, .visionos, .watchos, .freebsd, .netbsd, .dragonfly, .openbsd, .illumos => {
                // Don't follow symlinks to match unlinkat (which acts on symlinks rather than follows them)
                const fstat = posix.fstatatZ(self.fd, sub_path_c, posix.AT.SYMLINK_NOFOLLOW) catch return e;
                const is_dir = fstat.mode & posix.S.IFMT == posix.S.IFDIR;
                return if (is_dir) error.IsDir else e;
            },
            else => return e,
        },
        else => |e| return e,
    };
}

/// Same as `deleteFile` except the parameter is WTF-16 LE encoded.
pub fn deleteFileW(self: Dir, sub_path_w: []const u16) DeleteFileError!void {
    posix.unlinkatW(self.fd, sub_path_w, 0) catch |err| switch (err) {
        error.DirNotEmpty => unreachable, // not passing AT.REMOVEDIR
        else => |e| return e,
    };
}

pub const DeleteDirError = error{
    DirNotEmpty,
    FileNotFound,
    AccessDenied,
    PermissionDenied,
    FileBusy,
    FileSystem,
    SymLinkLoop,
    NameTooLong,
    NotDir,
    SystemResources,
    ReadOnlyFileSystem,
    /// WASI: file paths must be valid UTF-8.
    /// Windows: file paths provided by the user must be valid WTF-8.
    /// https://wtf-8.codeberg.page/
    BadPathName,
    /// On Windows, `\\server` or `\\server\share` was not found.
    NetworkNotFound,
    ProcessNotFound,
    Unexpected,
};

/// Returns `error.DirNotEmpty` if the directory is not empty.
/// To delete a directory recursively, see `deleteTree`.
/// On Windows, `sub_path` should be encoded as [WTF-8](https://wtf-8.codeberg.page/).
/// On WASI, `sub_path` should be encoded as valid UTF-8.
/// On other platforms, `sub_path` is an opaque sequence of bytes with no particular encoding.
/// Asserts that the path parameter has no null bytes.
pub fn deleteDir(self: Dir, sub_path: []const u8) DeleteDirError!void {
    if (native_os == .windows) {
        const sub_path_w = try windows.sliceToPrefixedFileW(self.fd, sub_path);
        return self.deleteDirW(sub_path_w.span());
    } else if (native_os == .wasi and !builtin.link_libc) {
        posix.unlinkat(self.fd, sub_path, posix.AT.REMOVEDIR) catch |err| switch (err) {
            error.IsDir => unreachable, // not possible since we pass AT.REMOVEDIR
            else => |e| return e,
        };
    } else {
        const sub_path_c = try posix.toPosixPath(sub_path);
        return self.deleteDirZ(&sub_path_c);
    }
}

/// Same as `deleteDir` except the parameter is null-terminated.
pub fn deleteDirZ(self: Dir, sub_path_c: [*:0]const u8) DeleteDirError!void {
    posix.unlinkatZ(self.fd, sub_path_c, posix.AT.REMOVEDIR) catch |err| switch (err) {
        error.IsDir => unreachable, // not possible since we pass AT.REMOVEDIR
        else => |e| return e,
    };
}

/// Same as `deleteDir` except the parameter is WTF16LE, NT prefixed.
/// This function is Windows-only.
pub fn deleteDirW(self: Dir, sub_path_w: []const u16) DeleteDirError!void {
    posix.unlinkatW(self.fd, sub_path_w, posix.AT.REMOVEDIR) catch |err| switch (err) {
        error.IsDir => unreachable, // not possible since we pass AT.REMOVEDIR
        else => |e| return e,
    };
}

pub const RenameError = posix.RenameError;

/// Change the name or location of a file or directory.
/// If new_sub_path already exists, it will be replaced.
/// Renaming a file over an existing directory or a directory
/// over an existing file will fail with `error.IsDir` or `error.NotDir`
/// On Windows, both paths should be encoded as [WTF-8](https://wtf-8.codeberg.page/).
/// On WASI, both paths should be encoded as valid UTF-8.
/// On other platforms, both paths are an opaque sequence of bytes with no particular encoding.
pub fn rename(self: Dir, old_sub_path: []const u8, new_sub_path: []const u8) RenameError!void {
    return posix.renameat(self.fd, old_sub_path, self.fd, new_sub_path);
}

/// Same as `rename` except the parameters are null-terminated.
pub fn renameZ(self: Dir, old_sub_path_z: [*:0]const u8, new_sub_path_z: [*:0]const u8) RenameError!void {
    return posix.renameatZ(self.fd, old_sub_path_z, self.fd, new_sub_path_z);
}

/// Same as `rename` except the parameters are WTF16LE, NT prefixed.
/// This function is Windows-only.
pub fn renameW(self: Dir, old_sub_path_w: []const u16, new_sub_path_w: []const u16) RenameError!void {
    return posix.renameatW(self.fd, old_sub_path_w, self.fd, new_sub_path_w, windows.TRUE);
}

/// Use with `Dir.symLink`, `Dir.atomicSymLink`, and `symLinkAbsolute` to
/// specify whether the symlink will point to a file or a directory. This value
/// is ignored on all hosts except Windows where creating symlinks to different
/// resource types, requires different flags. By default, `symLinkAbsolute` is
/// assumed to point to a file.
pub const SymLinkFlags = struct {
    is_directory: bool = false,
};

/// Creates a symbolic link named `sym_link_path` which contains the string `target_path`.
/// A symbolic link (also known as a soft link) may point to an existing file or to a nonexistent
/// one; the latter case is known as a dangling link.
/// If `sym_link_path` exists, it will not be overwritten.
/// On Windows, both paths should be encoded as [WTF-8](https://wtf-8.codeberg.page/).
/// On WASI, both paths should be encoded as valid UTF-8.
/// On other platforms, both paths are an opaque sequence of bytes with no particular encoding.
pub fn symLink(
    self: Dir,
    target_path: []const u8,
    sym_link_path: []const u8,
    flags: SymLinkFlags,
) !void {
    if (native_os == .wasi and !builtin.link_libc) {
        return self.symLinkWasi(target_path, sym_link_path, flags);
    }
    if (native_os == .windows) {
        // Target path does not use sliceToPrefixedFileW because certain paths
        // are handled differently when creating a symlink than they would be
        // when converting to an NT namespaced path. CreateSymbolicLink in
        // symLinkW will handle the necessary conversion.
        var target_path_w: windows.PathSpace = undefined;
        target_path_w.len = try windows.wtf8ToWtf16Le(&target_path_w.data, target_path);
        target_path_w.data[target_path_w.len] = 0;
        // However, we need to canonicalize any path separators to `\`, since if
        // the target path is relative, then it must use `\` as the path separator.
        mem.replaceScalar(
            u16,
            target_path_w.data[0..target_path_w.len],
            mem.nativeToLittle(u16, '/'),
            mem.nativeToLittle(u16, '\\'),
        );

        const sym_link_path_w = try windows.sliceToPrefixedFileW(self.fd, sym_link_path);
        return self.symLinkW(target_path_w.span(), sym_link_path_w.span(), flags);
    }
    const target_path_c = try posix.toPosixPath(target_path);
    const sym_link_path_c = try posix.toPosixPath(sym_link_path);
    return self.symLinkZ(&target_path_c, &sym_link_path_c, flags);
}

/// WASI-only. Same as `symLink` except targeting WASI.
pub fn symLinkWasi(
    self: Dir,
    target_path: []const u8,
    sym_link_path: []const u8,
    _: SymLinkFlags,
) !void {
    return posix.symlinkat(target_path, self.fd, sym_link_path);
}

/// Same as `symLink`, except the pathname parameters are null-terminated.
pub fn symLinkZ(
    self: Dir,
    target_path_c: [*:0]const u8,
    sym_link_path_c: [*:0]const u8,
    flags: SymLinkFlags,
) !void {
    if (native_os == .windows) {
        const target_path_w = try windows.cStrToPrefixedFileW(self.fd, target_path_c);
        const sym_link_path_w = try windows.cStrToPrefixedFileW(self.fd, sym_link_path_c);
        return self.symLinkW(target_path_w.span(), sym_link_path_w.span(), flags);
    }
    return posix.symlinkatZ(target_path_c, self.fd, sym_link_path_c);
}

/// Windows-only. Same as `symLink` except the pathname parameters
/// are WTF16 LE encoded.
pub fn symLinkW(
    self: Dir,
    /// WTF-16, does not need to be NT-prefixed. The NT-prefixing
    /// of this path is handled by CreateSymbolicLink.
    /// Any path separators must be `\`, not `/`.
    target_path_w: [:0]const u16,
    /// WTF-16, must be NT-prefixed or relative
    sym_link_path_w: []const u16,
    flags: SymLinkFlags,
) !void {
    return windows.CreateSymbolicLink(self.fd, sym_link_path_w, target_path_w, flags.is_directory);
}

/// Same as `symLink`, except tries to create the symbolic link until it
/// succeeds or encounters an error other than `error.PathAlreadyExists`.
///
/// * On Windows, both paths should be encoded as [WTF-8](https://wtf-8.codeberg.page/).
/// * On WASI, both paths should be encoded as valid UTF-8.
/// * On other platforms, both paths are an opaque sequence of bytes with no particular encoding.
pub fn atomicSymLink(
    dir: Dir,
    target_path: []const u8,
    sym_link_path: []const u8,
    flags: SymLinkFlags,
) !void {
    if (dir.symLink(target_path, sym_link_path, flags)) {
        return;
    } else |err| switch (err) {
        error.PathAlreadyExists => {},
        else => |e| return e,
    }

    const dirname = path.dirname(sym_link_path) orelse ".";

    const rand_len = @sizeOf(u64) * 2;
    const temp_path_len = dirname.len + 1 + rand_len;
    var temp_path_buf: [fs.max_path_bytes]u8 = undefined;

    if (temp_path_len > temp_path_buf.len) return error.NameTooLong;
    @memcpy(temp_path_buf[0..dirname.len], dirname);
    temp_path_buf[dirname.len] = path.sep;

    const temp_path = temp_path_buf[0..temp_path_len];

    while (true) {
        const random_integer = std.crypto.random.int(u64);
        temp_path[dirname.len + 1 ..][0..rand_len].* = std.fmt.hex(random_integer);

        if (dir.symLink(target_path, temp_path, flags)) {
            return dir.rename(temp_path, sym_link_path);
        } else |err| switch (err) {
            error.PathAlreadyExists => continue,
            else => |e| return e,
        }
    }
}

pub const ReadLinkError = posix.ReadLinkError;

/// Read value of a symbolic link.
/// The return value is a slice of `buffer`, from index `0`.
/// Asserts that the path parameter has no null bytes.
/// On Windows, `sub_path` should be encoded as [WTF-8](https://wtf-8.codeberg.page/).
/// On WASI, `sub_path` should be encoded as valid UTF-8.
/// On other platforms, `sub_path` is an opaque sequence of bytes with no particular encoding.
pub fn readLink(self: Dir, sub_path: []const u8, buffer: []u8) ReadLinkError![]u8 {
    if (native_os == .wasi and !builtin.link_libc) {
        return self.readLinkWasi(sub_path, buffer);
    }
    if (native_os == .windows) {
        var sub_path_w = try windows.sliceToPrefixedFileW(self.fd, sub_path);
        const result_w = try self.readLinkW(sub_path_w.span(), &sub_path_w.data);

        const len = std.unicode.calcWtf8Len(result_w);
        if (len > buffer.len) return error.NameTooLong;

        const end_index = std.unicode.wtf16LeToWtf8(buffer, result_w);
        return buffer[0..end_index];
    }
    const sub_path_c = try posix.toPosixPath(sub_path);
    return self.readLinkZ(&sub_path_c, buffer);
}

/// WASI-only. Same as `readLink` except targeting WASI.
pub fn readLinkWasi(self: Dir, sub_path: []const u8, buffer: []u8) ![]u8 {
    return posix.readlinkat(self.fd, sub_path, buffer);
}

/// Same as `readLink`, except the `sub_path_c` parameter is null-terminated.
pub fn readLinkZ(self: Dir, sub_path_c: [*:0]const u8, buffer: []u8) ![]u8 {
    if (native_os == .windows) {
        var sub_path_w = try windows.cStrToPrefixedFileW(self.fd, sub_path_c);
        const result_w = try self.readLinkW(sub_path_w.span(), &sub_path_w.data);

        const len = std.unicode.calcWtf8Len(result_w);
        if (len > buffer.len) return error.NameTooLong;

        const end_index = std.unicode.wtf16LeToWtf8(buffer, result_w);
        return buffer[0..end_index];
    }
    return posix.readlinkatZ(self.fd, sub_path_c, buffer);
}

/// Windows-only. Same as `readLink` except the path parameter
/// is WTF-16 LE encoded, NT-prefixed.
///
/// `sub_path_w` will never be accessed after `buffer` has been written to, so it
/// is safe to reuse a single buffer for both.
pub fn readLinkW(self: Dir, sub_path_w: []const u16, buffer: []u16) ![]u16 {
    return windows.ReadLink(self.fd, sub_path_w, buffer);
}

/// Deprecated in favor of `Io.Dir.readFile`.
pub fn readFile(self: Dir, file_path: []const u8, buffer: []u8) ![]u8 {
    var threaded: Io.Threaded = .init_single_threaded;
    const io = threaded.ioBasic();
    return Io.Dir.readFile(.{ .handle = self.fd }, io, file_path, buffer);
}

pub const ReadFileAllocError = File.OpenError || File.ReadError || Allocator.Error || error{
    /// File size reached or exceeded the provided limit.
    StreamTooLong,
};

/// Reads all the bytes from the named file. On success, caller owns returned
/// buffer.
///
/// If the file size is already known, a better alternative is to initialize a
/// `File.Reader`.
///
/// If the file size cannot be obtained, an error is returned. If
/// this is a realistic possibility, a better alternative is to initialize a
/// `File.Reader` which handles this seamlessly.
pub fn readFileAlloc(
    dir: Dir,
    /// On Windows, should be encoded as [WTF-8](https://wtf-8.codeberg.page/).
    /// On WASI, should be encoded as valid UTF-8.
    /// On other platforms, an opaque sequence of bytes with no particular encoding.
    sub_path: []const u8,
    /// Used to allocate the result.
    gpa: Allocator,
    /// If reached or exceeded, `error.StreamTooLong` is returned instead.
    limit: Io.Limit,
) ReadFileAllocError![]u8 {
    return readFileAllocOptions(dir, sub_path, gpa, limit, .of(u8), null);
}

/// Reads all the bytes from the named file. On success, caller owns returned
/// buffer.
///
/// If the file size is already known, a better alternative is to initialize a
/// `File.Reader`.
///
/// TODO move this function to Io.Dir
pub fn readFileAllocOptions(
    dir: Dir,
    /// On Windows, should be encoded as [WTF-8](https://wtf-8.codeberg.page/).
    /// On WASI, should be encoded as valid UTF-8.
    /// On other platforms, an opaque sequence of bytes with no particular encoding.
    sub_path: []const u8,
    /// Used to allocate the result.
    gpa: Allocator,
    /// If reached or exceeded, `error.StreamTooLong` is returned instead.
    limit: Io.Limit,
    comptime alignment: std.mem.Alignment,
    comptime sentinel: ?u8,
) ReadFileAllocError!(if (sentinel) |s| [:s]align(alignment.toByteUnits()) u8 else []align(alignment.toByteUnits()) u8) {
    var threaded: Io.Threaded = .init_single_threaded;
    const io = threaded.ioBasic();

    var file = try dir.openFile(sub_path, .{});
    defer file.close();
    var file_reader = file.reader(io, &.{});
    return file_reader.interface.allocRemainingAlignedSentinel(gpa, limit, alignment, sentinel) catch |err| switch (err) {
        error.ReadFailed => return file_reader.err.?,
        error.OutOfMemory, error.StreamTooLong => |e| return e,
    };
}

pub const DeleteTreeError = error{
    AccessDenied,
    PermissionDenied,
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
    ProcessNotFound,
    /// One of the path components was not a directory.
    /// This error is unreachable if `sub_path` does not contain a path separator.
    NotDir,
    /// WASI: file paths must be valid UTF-8.
    /// Windows: file paths provided by the user must be valid WTF-8.
    /// https://wtf-8.codeberg.page/
    /// On Windows, file paths cannot contain these characters:
    /// '/', '*', '?', '"', '<', '>', '|'
    BadPathName,
    /// On Windows, `\\server` or `\\server\share` was not found.
    NetworkNotFound,

    Canceled,
} || posix.UnexpectedError;

/// Whether `sub_path` describes a symlink, file, or directory, this function
/// removes it. If it cannot be removed because it is a non-empty directory,
/// this function recursively removes its entries and then tries again.
/// This operation is not atomic on most file systems.
/// On Windows, `sub_path` should be encoded as [WTF-8](https://wtf-8.codeberg.page/).
/// On WASI, `sub_path` should be encoded as valid UTF-8.
/// On other platforms, `sub_path` is an opaque sequence of bytes with no particular encoding.
pub fn deleteTree(self: Dir, sub_path: []const u8) DeleteTreeError!void {
    var initial_iterable_dir = (try self.deleteTreeOpenInitialSubpath(sub_path, .file)) orelse return;

    const StackItem = struct {
        name: []const u8,
        parent_dir: Dir,
        iter: Dir.Iterator,

        fn closeAll(items: []@This()) void {
            for (items) |*item| item.iter.dir.close();
        }
    };

    var stack_buffer: [16]StackItem = undefined;
    var stack = std.ArrayListUnmanaged(StackItem).initBuffer(&stack_buffer);
    defer StackItem.closeAll(stack.items);

    stack.appendAssumeCapacity(.{
        .name = sub_path,
        .parent_dir = self,
        .iter = initial_iterable_dir.iterateAssumeFirstIteration(),
    });

    process_stack: while (stack.items.len != 0) {
        var top = &stack.items[stack.items.len - 1];
        while (try top.iter.next()) |entry| {
            var treat_as_dir = entry.kind == .directory;
            handle_entry: while (true) {
                if (treat_as_dir) {
                    if (stack.unusedCapacitySlice().len >= 1) {
                        var iterable_dir = top.iter.dir.openDir(entry.name, .{
                            .follow_symlinks = false,
                            .iterate = true,
                        }) catch |err| switch (err) {
                            error.NotDir => {
                                treat_as_dir = false;
                                continue :handle_entry;
                            },
                            error.FileNotFound => {
                                // That's fine, we were trying to remove this directory anyway.
                                break :handle_entry;
                            },

                            error.AccessDenied,
                            error.PermissionDenied,
                            error.SymLinkLoop,
                            error.ProcessFdQuotaExceeded,
                            error.NameTooLong,
                            error.SystemFdQuotaExceeded,
                            error.NoDevice,
                            error.SystemResources,
                            error.Unexpected,
                            error.BadPathName,
                            error.NetworkNotFound,
                            error.DeviceBusy,
                            error.Canceled,
                            => |e| return e,
                        };
                        stack.appendAssumeCapacity(.{
                            .name = entry.name,
                            .parent_dir = top.iter.dir,
                            .iter = iterable_dir.iterateAssumeFirstIteration(),
                        });
                        continue :process_stack;
                    } else {
                        try top.iter.dir.deleteTreeMinStackSizeWithKindHint(entry.name, entry.kind);
                        break :handle_entry;
                    }
                } else {
                    if (top.iter.dir.deleteFile(entry.name)) {
                        break :handle_entry;
                    } else |err| switch (err) {
                        error.FileNotFound => break :handle_entry,

                        // Impossible because we do not pass any path separators.
                        error.NotDir => unreachable,

                        error.IsDir => {
                            treat_as_dir = true;
                            continue :handle_entry;
                        },

                        error.AccessDenied,
                        error.PermissionDenied,
                        error.SymLinkLoop,
                        error.NameTooLong,
                        error.SystemResources,
                        error.ReadOnlyFileSystem,
                        error.FileSystem,
                        error.FileBusy,
                        error.BadPathName,
                        error.NetworkNotFound,
                        error.Unexpected,
                        => |e| return e,
                    }
                }
            }
        }

        // On Windows, we can't delete until the dir's handle has been closed, so
        // close it before we try to delete.
        top.iter.dir.close();

        // In order to avoid double-closing the directory when cleaning up
        // the stack in the case of an error, we save the relevant portions and
        // pop the value from the stack.
        const parent_dir = top.parent_dir;
        const name = top.name;
        stack.items.len -= 1;

        var need_to_retry: bool = false;
        parent_dir.deleteDir(name) catch |err| switch (err) {
            error.FileNotFound => {},
            error.DirNotEmpty => need_to_retry = true,
            else => |e| return e,
        };

        if (need_to_retry) {
            // Since we closed the handle that the previous iterator used, we
            // need to re-open the dir and re-create the iterator.
            var iterable_dir = iterable_dir: {
                var treat_as_dir = true;
                handle_entry: while (true) {
                    if (treat_as_dir) {
                        break :iterable_dir parent_dir.openDir(name, .{
                            .follow_symlinks = false,
                            .iterate = true,
                        }) catch |err| switch (err) {
                            error.NotDir => {
                                treat_as_dir = false;
                                continue :handle_entry;
                            },
                            error.FileNotFound => {
                                // That's fine, we were trying to remove this directory anyway.
                                continue :process_stack;
                            },

                            error.AccessDenied,
                            error.PermissionDenied,
                            error.SymLinkLoop,
                            error.ProcessFdQuotaExceeded,
                            error.NameTooLong,
                            error.SystemFdQuotaExceeded,
                            error.NoDevice,
                            error.SystemResources,
                            error.Unexpected,
                            error.BadPathName,
                            error.NetworkNotFound,
                            error.DeviceBusy,
                            error.Canceled,
                            => |e| return e,
                        };
                    } else {
                        if (parent_dir.deleteFile(name)) {
                            continue :process_stack;
                        } else |err| switch (err) {
                            error.FileNotFound => continue :process_stack,

                            // Impossible because we do not pass any path separators.
                            error.NotDir => unreachable,

                            error.IsDir => {
                                treat_as_dir = true;
                                continue :handle_entry;
                            },

                            error.AccessDenied,
                            error.PermissionDenied,
                            error.SymLinkLoop,
                            error.NameTooLong,
                            error.SystemResources,
                            error.ReadOnlyFileSystem,
                            error.FileSystem,
                            error.FileBusy,
                            error.BadPathName,
                            error.NetworkNotFound,
                            error.Unexpected,
                            => |e| return e,
                        }
                    }
                }
            };
            // We know there is room on the stack since we are just re-adding
            // the StackItem that we previously popped.
            stack.appendAssumeCapacity(.{
                .name = name,
                .parent_dir = parent_dir,
                .iter = iterable_dir.iterateAssumeFirstIteration(),
            });
            continue :process_stack;
        }
    }
}

/// Like `deleteTree`, but only keeps one `Iterator` active at a time to minimize the function's stack size.
/// This is slower than `deleteTree` but uses less stack space.
/// On Windows, `sub_path` should be encoded as [WTF-8](https://wtf-8.codeberg.page/).
/// On WASI, `sub_path` should be encoded as valid UTF-8.
/// On other platforms, `sub_path` is an opaque sequence of bytes with no particular encoding.
pub fn deleteTreeMinStackSize(self: Dir, sub_path: []const u8) DeleteTreeError!void {
    return self.deleteTreeMinStackSizeWithKindHint(sub_path, .file);
}

fn deleteTreeMinStackSizeWithKindHint(self: Dir, sub_path: []const u8, kind_hint: File.Kind) DeleteTreeError!void {
    start_over: while (true) {
        var dir = (try self.deleteTreeOpenInitialSubpath(sub_path, kind_hint)) orelse return;
        var cleanup_dir_parent: ?Dir = null;
        defer if (cleanup_dir_parent) |*d| d.close();

        var cleanup_dir = true;
        defer if (cleanup_dir) dir.close();

        // Valid use of max_path_bytes because dir_name_buf will only
        // ever store a single path component that was returned from the
        // filesystem.
        var dir_name_buf: [fs.max_path_bytes]u8 = undefined;
        var dir_name: []const u8 = sub_path;

        // Here we must avoid recursion, in order to provide O(1) memory guarantee of this function.
        // Go through each entry and if it is not a directory, delete it. If it is a directory,
        // open it, and close the original directory. Repeat. Then start the entire operation over.

        scan_dir: while (true) {
            var dir_it = dir.iterateAssumeFirstIteration();
            dir_it: while (try dir_it.next()) |entry| {
                var treat_as_dir = entry.kind == .directory;
                handle_entry: while (true) {
                    if (treat_as_dir) {
                        const new_dir = dir.openDir(entry.name, .{
                            .follow_symlinks = false,
                            .iterate = true,
                        }) catch |err| switch (err) {
                            error.NotDir => {
                                treat_as_dir = false;
                                continue :handle_entry;
                            },
                            error.FileNotFound => {
                                // That's fine, we were trying to remove this directory anyway.
                                continue :dir_it;
                            },

                            error.AccessDenied,
                            error.PermissionDenied,
                            error.SymLinkLoop,
                            error.ProcessFdQuotaExceeded,
                            error.NameTooLong,
                            error.SystemFdQuotaExceeded,
                            error.NoDevice,
                            error.SystemResources,
                            error.Unexpected,
                            error.BadPathName,
                            error.NetworkNotFound,
                            error.DeviceBusy,
                            error.Canceled,
                            => |e| return e,
                        };
                        if (cleanup_dir_parent) |*d| d.close();
                        cleanup_dir_parent = dir;
                        dir = new_dir;
                        const result = dir_name_buf[0..entry.name.len];
                        @memcpy(result, entry.name);
                        dir_name = result;
                        continue :scan_dir;
                    } else {
                        if (dir.deleteFile(entry.name)) {
                            continue :dir_it;
                        } else |err| switch (err) {
                            error.FileNotFound => continue :dir_it,

                            // Impossible because we do not pass any path separators.
                            error.NotDir => unreachable,

                            error.IsDir => {
                                treat_as_dir = true;
                                continue :handle_entry;
                            },

                            error.AccessDenied,
                            error.PermissionDenied,
                            error.SymLinkLoop,
                            error.NameTooLong,
                            error.SystemResources,
                            error.ReadOnlyFileSystem,
                            error.FileSystem,
                            error.FileBusy,
                            error.BadPathName,
                            error.NetworkNotFound,
                            error.Unexpected,
                            => |e| return e,
                        }
                    }
                }
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

/// On successful delete, returns null.
fn deleteTreeOpenInitialSubpath(self: Dir, sub_path: []const u8, kind_hint: File.Kind) !?Dir {
    return iterable_dir: {
        // Treat as a file by default
        var treat_as_dir = kind_hint == .directory;

        handle_entry: while (true) {
            if (treat_as_dir) {
                break :iterable_dir self.openDir(sub_path, .{
                    .follow_symlinks = false,
                    .iterate = true,
                }) catch |err| switch (err) {
                    error.NotDir => {
                        treat_as_dir = false;
                        continue :handle_entry;
                    },
                    error.FileNotFound => {
                        // That's fine, we were trying to remove this directory anyway.
                        return null;
                    },

                    error.AccessDenied,
                    error.PermissionDenied,
                    error.SymLinkLoop,
                    error.ProcessFdQuotaExceeded,
                    error.NameTooLong,
                    error.SystemFdQuotaExceeded,
                    error.NoDevice,
                    error.SystemResources,
                    error.Unexpected,
                    error.BadPathName,
                    error.DeviceBusy,
                    error.NetworkNotFound,
                    error.Canceled,
                    => |e| return e,
                };
            } else {
                if (self.deleteFile(sub_path)) {
                    return null;
                } else |err| switch (err) {
                    error.FileNotFound => return null,

                    error.IsDir => {
                        treat_as_dir = true;
                        continue :handle_entry;
                    },

                    error.AccessDenied,
                    error.PermissionDenied,
                    error.SymLinkLoop,
                    error.NameTooLong,
                    error.SystemResources,
                    error.ReadOnlyFileSystem,
                    error.NotDir,
                    error.FileSystem,
                    error.FileBusy,
                    error.BadPathName,
                    error.NetworkNotFound,
                    error.Unexpected,
                    => |e| return e,
                }
            }
        }
    };
}

pub const WriteFileError = File.WriteError || File.OpenError;

pub const WriteFileOptions = struct {
    /// On Windows, `sub_path` should be encoded as [WTF-8](https://wtf-8.codeberg.page/).
    /// On WASI, `sub_path` should be encoded as valid UTF-8.
    /// On other platforms, `sub_path` is an opaque sequence of bytes with no particular encoding.
    sub_path: []const u8,
    data: []const u8,
    flags: File.CreateFlags = .{},
};

/// Writes content to the file system, using the file creation flags provided.
pub fn writeFile(self: Dir, options: WriteFileOptions) WriteFileError!void {
    var file = try self.createFile(options.sub_path, options.flags);
    defer file.close();
    try file.writeAll(options.data);
}

/// Deprecated in favor of `Io.Dir.AccessError`.
pub const AccessError = Io.Dir.AccessError;

/// Deprecated in favor of `Io.Dir.access`.
pub fn access(self: Dir, sub_path: []const u8, options: Io.Dir.AccessOptions) AccessError!void {
    var threaded: Io.Threaded = .init_single_threaded;
    const io = threaded.ioBasic();
    return Io.Dir.access(self.adaptToNewApi(), io, sub_path, options);
}

pub const CopyFileOptions = struct {
    /// When this is `null` the mode is copied from the source file.
    override_mode: ?File.Mode = null,
};

pub const CopyFileError = File.OpenError || File.StatError ||
    AtomicFile.InitError || AtomicFile.FinishError ||
    File.ReadError || File.WriteError || error{InvalidFileName};

/// Atomically creates a new file at `dest_path` within `dest_dir` with the
/// same contents as `source_path` within `source_dir`, overwriting any already
/// existing file.
///
/// On Linux, until https://patchwork.kernel.org/patch/9636735/ is merged and
/// readily available, there is a possibility of power loss or application
/// termination leaving temporary files present in the same directory as
/// dest_path.
///
/// On Windows, both paths should be encoded as
/// [WTF-8](https://wtf-8.codeberg.page/). On WASI, both paths should be
/// encoded as valid UTF-8. On other platforms, both paths are an opaque
/// sequence of bytes with no particular encoding.
///
/// TODO move this function to Io.Dir
pub fn copyFile(
    source_dir: Dir,
    source_path: []const u8,
    dest_dir: Dir,
    dest_path: []const u8,
    options: CopyFileOptions,
) CopyFileError!void {
    var threaded: Io.Threaded = .init_single_threaded;
    const io = threaded.ioBasic();

    const file = try source_dir.openFile(source_path, .{});
    var file_reader: File.Reader = .init(.{ .handle = file.handle }, io, &.{});
    defer file_reader.file.close(io);

    const mode = options.override_mode orelse blk: {
        const st = try file_reader.file.stat(io);
        file_reader.size = st.size;
        break :blk st.mode;
    };

    var buffer: [1024]u8 = undefined; // Used only when direct fd-to-fd is not available.
    var atomic_file = try dest_dir.atomicFile(dest_path, .{
        .mode = mode,
        .write_buffer = &buffer,
    });
    defer atomic_file.deinit();

    _ = atomic_file.file_writer.interface.sendFileAll(&file_reader, .unlimited) catch |err| switch (err) {
        error.ReadFailed => return file_reader.err.?,
        error.WriteFailed => return atomic_file.file_writer.err.?,
    };

    try atomic_file.finish();
}

pub const AtomicFileOptions = struct {
    mode: File.Mode = File.default_mode,
    make_path: bool = false,
    write_buffer: []u8,
};

/// Directly access the `.file` field, and then call `AtomicFile.finish` to
/// atomically replace `dest_path` with contents.
/// Always call `AtomicFile.deinit` to clean up, regardless of whether
/// `AtomicFile.finish` succeeded. `dest_path` must remain valid until
/// `AtomicFile.deinit` is called.
/// On Windows, `dest_path` should be encoded as [WTF-8](https://wtf-8.codeberg.page/).
/// On WASI, `dest_path` should be encoded as valid UTF-8.
/// On other platforms, `dest_path` is an opaque sequence of bytes with no particular encoding.
pub fn atomicFile(self: Dir, dest_path: []const u8, options: AtomicFileOptions) !AtomicFile {
    if (fs.path.dirname(dest_path)) |dirname| {
        const dir = if (options.make_path)
            try self.makeOpenPath(dirname, .{})
        else
            try self.openDir(dirname, .{});

        return .init(fs.path.basename(dest_path), options.mode, dir, true, options.write_buffer);
    } else {
        return .init(dest_path, options.mode, self, false, options.write_buffer);
    }
}

pub const Stat = File.Stat;
pub const StatError = File.StatError;

/// Deprecated in favor of `Io.Dir.stat`.
pub fn stat(self: Dir) StatError!Stat {
    const file: File = .{ .handle = self.fd };
    return file.stat();
}

pub const StatFileError = File.OpenError || File.StatError || posix.FStatAtError;

/// Deprecated in favor of `Io.Dir.statPath`.
pub fn statFile(self: Dir, sub_path: []const u8) StatFileError!Stat {
    var threaded: Io.Threaded = .init_single_threaded;
    const io = threaded.ioBasic();
    return Io.Dir.statPath(.{ .handle = self.fd }, io, sub_path, .{});
}

pub const ChmodError = File.ChmodError;

/// Changes the mode of the directory.
/// The process must have the correct privileges in order to do this
/// successfully, or must have the effective user ID matching the owner
/// of the directory. Additionally, the directory must have been opened
/// with `OpenOptions{ .iterate = true }`.
pub fn chmod(self: Dir, new_mode: File.Mode) ChmodError!void {
    const file: File = .{ .handle = self.fd };
    try file.chmod(new_mode);
}

/// Changes the owner and group of the directory.
/// The process must have the correct privileges in order to do this
/// successfully. The group may be changed by the owner of the directory to
/// any group of which the owner is a member. Additionally, the directory
/// must have been opened with `OpenOptions{ .iterate = true }`. If the
/// owner or group is specified as `null`, the ID is not changed.
pub fn chown(self: Dir, owner: ?File.Uid, group: ?File.Gid) ChownError!void {
    const file: File = .{ .handle = self.fd };
    try file.chown(owner, group);
}

pub const ChownError = File.ChownError;

const Permissions = File.Permissions;
pub const SetPermissionsError = File.SetPermissionsError;

/// Sets permissions according to the provided `Permissions` struct.
/// This method is *NOT* available on WASI
pub fn setPermissions(self: Dir, permissions: Permissions) SetPermissionsError!void {
    const file: File = .{ .handle = self.fd };
    try file.setPermissions(permissions);
}

pub fn adaptToNewApi(dir: Dir) Io.Dir {
    return .{ .handle = dir.fd };
}

pub fn adaptFromNewApi(dir: Io.Dir) Dir {
    return .{ .fd = dir.handle };
}
