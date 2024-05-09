fd: posix.fd_t,

pub const default_mode = 0o755;

pub const Entry = struct {
    name: []const u8,
    kind: Kind,

    pub const Kind = File.Kind;
};

const IteratorError = error{
    AccessDenied,
    SystemResources,
    /// WASI-only. The path of an entry could not be encoded as valid UTF-8.
    /// WASI is unable to handle paths that cannot be encoded as well-formed UTF-8.
    /// https://github.com/WebAssembly/wasi-filesystem/issues/17#issuecomment-1430639353
    InvalidUtf8,
} || posix.UnexpectedError;

pub const Iterator = switch (native_os) {
    .macos, .ios, .freebsd, .netbsd, .dragonfly, .openbsd, .solaris, .illumos => struct {
        dir: Dir,
        seek: i64,
        buf: [1024]u8, // TODO align(@alignOf(posix.system.dirent)),
        index: usize,
        end_index: usize,
        first_iter: bool,

        const Self = @This();

        pub const Error = IteratorError;

        /// Memory such as file names referenced in this returned entry becomes invalid
        /// with subsequent calls to `next`, as well as when this `Dir` is deinitialized.
        pub fn next(self: *Self) Error!?Entry {
            switch (native_os) {
                .macos, .ios => return self.nextDarwin(),
                .freebsd, .netbsd, .dragonfly, .openbsd => return self.nextBsd(),
                .solaris, .illumos => return self.nextSolaris(),
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

        fn nextSolaris(self: *Self) !?Entry {
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

                // Solaris dirent doesn't expose type, so we have to call stat to get it.
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
                const next_index = self.index + if (@hasDecl(posix.system.dirent, "reclen")) bsd_entry.reclen() else bsd_entry.reclen;
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
                            .PERM => return error.AccessDenied,
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
                            .PERM => return error.AccessDenied,
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
                    0,
                )))) {
                    .SUCCESS => {},
                    .INVAL => unreachable,
                    .BADF => unreachable, // Dir is invalid
                    .NOMEM => return error.SystemResources,
                    .ACCES => return error.AccessDenied,
                    .PERM => return error.AccessDenied,
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
        // The if guard is solely there to prevent compile errors from missing `linux.dirent64`
        // definition when compiling for other OSes. It doesn't do anything when compiling for Linux.
        buf: [1024]u8 align(@alignOf(linux.dirent64)),
        index: usize,
        end_index: usize,
        first_iter: bool,

        const Self = @This();
        const linux = std.os.linux;

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
        name_data: [fs.MAX_NAME_BYTES]u8,

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
        buf: [1024]u8, // TODO align(@alignOf(posix.wasi.dirent_t)),
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
                        .ILSEQ => return error.InvalidUtf8, // An entry's name cannot be encoded as UTF-8.
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
        .macos,
        .ios,
        .freebsd,
        .netbsd,
        .dragonfly,
        .openbsd,
        .solaris,
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

pub const Walker = struct {
    stack: std.ArrayListUnmanaged(StackItem),
    name_buffer: std.ArrayListUnmanaged(u8),
    allocator: Allocator,

    pub const Entry = struct {
        /// The containing directory. This can be used to operate directly on `basename`
        /// rather than `path`, avoiding `error.NameTooLong` for deeply nested paths.
        /// The directory remains open until `next` or `deinit` is called.
        dir: Dir,
        basename: [:0]const u8,
        path: [:0]const u8,
        kind: Dir.Entry.Kind,
    };

    const StackItem = struct {
        iter: Dir.Iterator,
        dirname_len: usize,
    };

    /// After each call to this function, and on deinit(), the memory returned
    /// from this function becomes invalid. A copy must be made in order to keep
    /// a reference to the path.
    pub fn next(self: *Walker) !?Walker.Entry {
        const gpa = self.allocator;
        while (self.stack.items.len != 0) {
            // `top` and `containing` become invalid after appending to `self.stack`
            var top = &self.stack.items[self.stack.items.len - 1];
            var containing = top;
            var dirname_len = top.dirname_len;
            if (top.iter.next() catch |err| {
                // If we get an error, then we want the user to be able to continue
                // walking if they want, which means that we need to pop the directory
                // that errored from the stack. Otherwise, all future `next` calls would
                // likely just fail with the same error.
                var item = self.stack.pop();
                if (self.stack.items.len != 0) {
                    item.iter.dir.close();
                }
                return err;
            }) |base| {
                self.name_buffer.shrinkRetainingCapacity(dirname_len);
                if (self.name_buffer.items.len != 0) {
                    try self.name_buffer.append(gpa, fs.path.sep);
                    dirname_len += 1;
                }
                try self.name_buffer.ensureUnusedCapacity(gpa, base.name.len + 1);
                self.name_buffer.appendSliceAssumeCapacity(base.name);
                self.name_buffer.appendAssumeCapacity(0);
                if (base.kind == .directory) {
                    var new_dir = top.iter.dir.openDir(base.name, .{ .iterate = true }) catch |err| switch (err) {
                        error.NameTooLong => unreachable, // no path sep in base.name
                        else => |e| return e,
                    };
                    {
                        errdefer new_dir.close();
                        try self.stack.append(gpa, .{
                            .iter = new_dir.iterateAssumeFirstIteration(),
                            .dirname_len = self.name_buffer.items.len - 1,
                        });
                        top = &self.stack.items[self.stack.items.len - 1];
                        containing = &self.stack.items[self.stack.items.len - 2];
                    }
                }
                return .{
                    .dir = containing.iter.dir,
                    .basename = self.name_buffer.items[dirname_len .. self.name_buffer.items.len - 1 :0],
                    .path = self.name_buffer.items[0 .. self.name_buffer.items.len - 1 :0],
                    .kind = base.kind,
                };
            } else {
                var item = self.stack.pop();
                if (self.stack.items.len != 0) {
                    item.iter.dir.close();
                }
            }
        }
        return null;
    }

    pub fn deinit(self: *Walker) void {
        const gpa = self.allocator;
        // Close any remaining directories except the initial one (which is always at index 0)
        if (self.stack.items.len > 1) {
            for (self.stack.items[1..]) |*item| {
                item.iter.dir.close();
            }
        }
        self.stack.deinit(gpa);
        self.name_buffer.deinit(gpa);
    }
};

/// Recursively iterates over a directory.
///
/// `self` must have been opened with `OpenDirOptions{.iterate = true}`.
///
/// `Walker.deinit` releases allocated memory and directory handles.
///
/// The order of returned file system entries is undefined.
///
/// `self` will not be closed after walking it.
pub fn walk(self: Dir, allocator: Allocator) Allocator.Error!Walker {
    var stack: std.ArrayListUnmanaged(Walker.StackItem) = .{};

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
    /// WASI-only; file paths must be valid UTF-8.
    InvalidUtf8,
    /// Windows-only; file paths provided by the user must be valid WTF-8.
    /// https://simonsapin.github.io/wtf-8/
    InvalidWtf8,
    BadPathName,
    DeviceBusy,
    /// On Windows, `\\server` or `\\server\share` was not found.
    NetworkNotFound,
} || posix.UnexpectedError;

pub fn close(self: *Dir) void {
    posix.close(self.fd);
    self.* = undefined;
}

/// Opens a file for reading or writing, without attempting to create a new file.
/// To create a new file, see `createFile`.
/// Call `File.close` to release the resource.
/// Asserts that the path parameter has no null bytes.
/// On Windows, `sub_path` should be encoded as [WTF-8](https://simonsapin.github.io/wtf-8/).
/// On WASI, `sub_path` should be encoded as valid UTF-8.
/// On other platforms, `sub_path` is an opaque sequence of bytes with no particular encoding.
pub fn openFile(self: Dir, sub_path: []const u8, flags: File.OpenFlags) File.OpenError!File {
    if (native_os == .windows) {
        const path_w = try windows.sliceToPrefixedFileW(self.fd, sub_path);
        return self.openFileW(path_w.span(), flags);
    }
    if (native_os == .wasi and !builtin.link_libc) {
        var base: std.os.wasi.rights_t = .{};
        if (flags.isRead()) {
            base.FD_READ = true;
            base.FD_TELL = true;
            base.FD_SEEK = true;
            base.FD_FILESTAT_GET = true;
        }
        if (flags.isWrite()) {
            base.FD_WRITE = true;
            base.FD_TELL = true;
            base.FD_SEEK = true;
            base.FD_DATASYNC = true;
            base.FD_FDSTAT_SET_FLAGS = true;
            base.FD_SYNC = true;
            base.FD_ALLOCATE = true;
            base.FD_ADVISE = true;
            base.FD_FILESTAT_SET_TIMES = true;
            base.FD_FILESTAT_SET_SIZE = true;
        }
        const fd = try posix.openatWasi(self.fd, sub_path, .{}, .{}, .{}, base, .{});
        return .{ .handle = fd };
    }
    const path_c = try posix.toPosixPath(sub_path);
    return self.openFileZ(&path_c, flags);
}

/// Same as `openFile` but the path parameter is null-terminated.
pub fn openFileZ(self: Dir, sub_path: [*:0]const u8, flags: File.OpenFlags) File.OpenError!File {
    switch (native_os) {
        .windows => {
            const path_w = try windows.cStrToPrefixedFileW(self.fd, sub_path);
            return self.openFileW(path_w.span(), flags);
        },
        // Use the libc API when libc is linked because it implements things
        // such as opening absolute file paths.
        .wasi => if (!builtin.link_libc) {
            return openFile(self, mem.sliceTo(sub_path, 0), flags);
        },
        else => {},
    }

    var os_flags: posix.O = switch (native_os) {
        .wasi => .{
            .read = flags.mode != .write_only,
            .write = flags.mode != .read_only,
        },
        else => .{
            .ACCMODE = switch (flags.mode) {
                .read_only => .RDONLY,
                .write_only => .WRONLY,
                .read_write => .RDWR,
            },
        },
    };
    if (@hasField(posix.O, "CLOEXEC")) os_flags.CLOEXEC = true;
    if (@hasField(posix.O, "LARGEFILE")) os_flags.LARGEFILE = true;
    if (@hasField(posix.O, "NOCTTY")) os_flags.NOCTTY = !flags.allow_ctty;

    // Use the O locking flags if the os supports them to acquire the lock
    // atomically.
    const has_flock_open_flags = @hasField(posix.O, "EXLOCK");
    if (has_flock_open_flags) {
        // Note that the NONBLOCK flag is removed after the openat() call
        // is successful.
        switch (flags.lock) {
            .none => {},
            .shared => {
                os_flags.SHLOCK = true;
                os_flags.NONBLOCK = flags.lock_nonblocking;
            },
            .exclusive => {
                os_flags.EXLOCK = true;
                os_flags.NONBLOCK = flags.lock_nonblocking;
            },
        }
    }
    const fd = try posix.openatZ(self.fd, sub_path, os_flags, 0);
    errdefer posix.close(fd);

    if (@hasDecl(posix.system, "LOCK")) {
        if (!has_flock_open_flags and flags.lock != .none) {
            // TODO: integrate async I/O
            const lock_nonblocking: i32 = if (flags.lock_nonblocking) posix.LOCK.NB else 0;
            try posix.flock(fd, switch (flags.lock) {
                .none => unreachable,
                .shared => posix.LOCK.SH | lock_nonblocking,
                .exclusive => posix.LOCK.EX | lock_nonblocking,
            });
        }
    }

    if (has_flock_open_flags and flags.lock_nonblocking) {
        var fl_flags = posix.fcntl(fd, posix.F.GETFL, 0) catch |err| switch (err) {
            error.FileBusy => unreachable,
            error.Locked => unreachable,
            error.PermissionDenied => unreachable,
            error.DeadLock => unreachable,
            error.LockedRegionLimitExceeded => unreachable,
            else => |e| return e,
        };
        fl_flags &= ~@as(usize, 1 << @bitOffsetOf(posix.O, "NONBLOCK"));
        _ = posix.fcntl(fd, posix.F.SETFL, fl_flags) catch |err| switch (err) {
            error.FileBusy => unreachable,
            error.Locked => unreachable,
            error.PermissionDenied => unreachable,
            error.DeadLock => unreachable,
            error.LockedRegionLimitExceeded => unreachable,
            else => |e| return e,
        };
    }

    return .{ .handle = fd };
}

/// Same as `openFile` but Windows-only and the path parameter is
/// [WTF-16](https://simonsapin.github.io/wtf-8/#potentially-ill-formed-utf-16) encoded.
pub fn openFileW(self: Dir, sub_path_w: []const u16, flags: File.OpenFlags) File.OpenError!File {
    const w = windows;
    const file: File = .{
        .handle = try w.OpenFile(sub_path_w, .{
            .dir = self.fd,
            .access_mask = w.SYNCHRONIZE |
                (if (flags.isRead()) @as(u32, w.GENERIC_READ) else 0) |
                (if (flags.isWrite()) @as(u32, w.GENERIC_WRITE) else 0),
            .creation = w.FILE_OPEN,
        }),
    };
    errdefer file.close();
    var io: w.IO_STATUS_BLOCK = undefined;
    const range_off: w.LARGE_INTEGER = 0;
    const range_len: w.LARGE_INTEGER = 1;
    const exclusive = switch (flags.lock) {
        .none => return file,
        .shared => false,
        .exclusive => true,
    };
    try w.LockFile(
        file.handle,
        null,
        null,
        null,
        &io,
        &range_off,
        &range_len,
        null,
        @intFromBool(flags.lock_nonblocking),
        @intFromBool(exclusive),
    );
    return file;
}

/// Creates, opens, or overwrites a file with write access.
/// Call `File.close` on the result when done.
/// Asserts that the path parameter has no null bytes.
/// On Windows, `sub_path` should be encoded as [WTF-8](https://simonsapin.github.io/wtf-8/).
/// On WASI, `sub_path` should be encoded as valid UTF-8.
/// On other platforms, `sub_path` is an opaque sequence of bytes with no particular encoding.
pub fn createFile(self: Dir, sub_path: []const u8, flags: File.CreateFlags) File.OpenError!File {
    if (native_os == .windows) {
        const path_w = try windows.sliceToPrefixedFileW(self.fd, sub_path);
        return self.createFileW(path_w.span(), flags);
    }
    if (native_os == .wasi) {
        return .{
            .handle = try posix.openatWasi(self.fd, sub_path, .{}, .{
                .CREAT = true,
                .TRUNC = flags.truncate,
                .EXCL = flags.exclusive,
            }, .{}, .{
                .FD_READ = flags.read,
                .FD_WRITE = true,
                .FD_DATASYNC = true,
                .FD_SEEK = true,
                .FD_TELL = true,
                .FD_FDSTAT_SET_FLAGS = true,
                .FD_SYNC = true,
                .FD_ALLOCATE = true,
                .FD_ADVISE = true,
                .FD_FILESTAT_SET_TIMES = true,
                .FD_FILESTAT_SET_SIZE = true,
                .FD_FILESTAT_GET = true,
            }, .{}),
        };
    }
    const path_c = try posix.toPosixPath(sub_path);
    return self.createFileZ(&path_c, flags);
}

/// Same as `createFile` but the path parameter is null-terminated.
pub fn createFileZ(self: Dir, sub_path_c: [*:0]const u8, flags: File.CreateFlags) File.OpenError!File {
    switch (native_os) {
        .windows => {
            const path_w = try windows.cStrToPrefixedFileW(self.fd, sub_path_c);
            return self.createFileW(path_w.span(), flags);
        },
        .wasi => {
            return createFile(self, mem.sliceTo(sub_path_c, 0), flags);
        },
        else => {},
    }

    var os_flags: posix.O = .{
        .ACCMODE = if (flags.read) .RDWR else .WRONLY,
        .CREAT = true,
        .TRUNC = flags.truncate,
        .EXCL = flags.exclusive,
    };
    if (@hasField(posix.O, "LARGEFILE")) os_flags.LARGEFILE = true;
    if (@hasField(posix.O, "CLOEXEC")) os_flags.CLOEXEC = true;

    // Use the O locking flags if the os supports them to acquire the lock
    // atomically. Note that the NONBLOCK flag is removed after the openat()
    // call is successful.
    const has_flock_open_flags = @hasField(posix.O, "EXLOCK");
    if (has_flock_open_flags) switch (flags.lock) {
        .none => {},
        .shared => {
            os_flags.SHLOCK = true;
            os_flags.NONBLOCK = flags.lock_nonblocking;
        },
        .exclusive => {
            os_flags.EXLOCK = true;
            os_flags.NONBLOCK = flags.lock_nonblocking;
        },
    };

    const fd = try posix.openatZ(self.fd, sub_path_c, os_flags, flags.mode);
    errdefer posix.close(fd);

    if (!has_flock_open_flags and flags.lock != .none) {
        // TODO: integrate async I/O
        const lock_nonblocking: i32 = if (flags.lock_nonblocking) posix.LOCK.NB else 0;
        try posix.flock(fd, switch (flags.lock) {
            .none => unreachable,
            .shared => posix.LOCK.SH | lock_nonblocking,
            .exclusive => posix.LOCK.EX | lock_nonblocking,
        });
    }

    if (has_flock_open_flags and flags.lock_nonblocking) {
        var fl_flags = posix.fcntl(fd, posix.F.GETFL, 0) catch |err| switch (err) {
            error.FileBusy => unreachable,
            error.Locked => unreachable,
            error.PermissionDenied => unreachable,
            error.DeadLock => unreachable,
            error.LockedRegionLimitExceeded => unreachable,
            else => |e| return e,
        };
        fl_flags &= ~@as(usize, 1 << @bitOffsetOf(posix.O, "NONBLOCK"));
        _ = posix.fcntl(fd, posix.F.SETFL, fl_flags) catch |err| switch (err) {
            error.FileBusy => unreachable,
            error.Locked => unreachable,
            error.PermissionDenied => unreachable,
            error.DeadLock => unreachable,
            error.LockedRegionLimitExceeded => unreachable,
            else => |e| return e,
        };
    }

    return .{ .handle = fd };
}

/// Same as `createFile` but Windows-only and the path parameter is
/// [WTF-16](https://simonsapin.github.io/wtf-8/#potentially-ill-formed-utf-16) encoded.
pub fn createFileW(self: Dir, sub_path_w: []const u16, flags: File.CreateFlags) File.OpenError!File {
    const w = windows;
    const read_flag = if (flags.read) @as(u32, w.GENERIC_READ) else 0;
    const file: File = .{
        .handle = try w.OpenFile(sub_path_w, .{
            .dir = self.fd,
            .access_mask = w.SYNCHRONIZE | w.GENERIC_WRITE | read_flag,
            .creation = if (flags.exclusive)
                @as(u32, w.FILE_CREATE)
            else if (flags.truncate)
                @as(u32, w.FILE_OVERWRITE_IF)
            else
                @as(u32, w.FILE_OPEN_IF),
        }),
    };
    errdefer file.close();
    var io: w.IO_STATUS_BLOCK = undefined;
    const range_off: w.LARGE_INTEGER = 0;
    const range_len: w.LARGE_INTEGER = 1;
    const exclusive = switch (flags.lock) {
        .none => return file,
        .shared => false,
        .exclusive => true,
    };
    try w.LockFile(
        file.handle,
        null,
        null,
        null,
        &io,
        &range_off,
        &range_len,
        null,
        @intFromBool(flags.lock_nonblocking),
        @intFromBool(exclusive),
    );
    return file;
}

pub const MakeError = posix.MakeDirError;

/// Creates a single directory with a relative or absolute path.
/// To create multiple directories to make an entire path, see `makePath`.
/// To operate on only absolute paths, see `makeDirAbsolute`.
/// On Windows, `sub_path` should be encoded as [WTF-8](https://simonsapin.github.io/wtf-8/).
/// On WASI, `sub_path` should be encoded as valid UTF-8.
/// On other platforms, `sub_path` is an opaque sequence of bytes with no particular encoding.
pub fn makeDir(self: Dir, sub_path: []const u8) MakeError!void {
    try posix.mkdirat(self.fd, sub_path, default_mode);
}

/// Same as `makeDir`, but `sub_path` is null-terminated.
/// To create multiple directories to make an entire path, see `makePath`.
/// To operate on only absolute paths, see `makeDirAbsoluteZ`.
pub fn makeDirZ(self: Dir, sub_path: [*:0]const u8) MakeError!void {
    try posix.mkdiratZ(self.fd, sub_path, default_mode);
}

/// Creates a single directory with a relative or absolute null-terminated WTF-16 LE-encoded path.
/// To create multiple directories to make an entire path, see `makePath`.
/// To operate on only absolute paths, see `makeDirAbsoluteW`.
pub fn makeDirW(self: Dir, sub_path: [*:0]const u16) MakeError!void {
    try posix.mkdiratW(self.fd, sub_path, default_mode);
}

/// Calls makeDir iteratively to make an entire path
/// (i.e. creating any parent directories that do not exist).
/// Returns success if the path already exists and is a directory.
/// This function is not atomic, and if it returns an error, the file system may
/// have been modified regardless.
/// On Windows, `sub_path` should be encoded as [WTF-8](https://simonsapin.github.io/wtf-8/).
/// On WASI, `sub_path` should be encoded as valid UTF-8.
/// On other platforms, `sub_path` is an opaque sequence of bytes with no particular encoding.
///
/// Paths containing `..` components are handled differently depending on the platform:
/// - On Windows, `..` are resolved before the path is passed to NtCreateFile, meaning
///   a `sub_path` like "first/../second" will resolve to "second" and only a
///   `./second` directory will be created.
/// - On other platforms, `..` are not resolved before the path is passed to `mkdirat`,
///   meaning a `sub_path` like "first/../second" will create both a `./first`
///   and a `./second` directory.
pub fn makePath(self: Dir, sub_path: []const u8) (MakeError || StatFileError)!void {
    var it = try fs.path.componentIterator(sub_path);
    var component = it.last() orelse return;
    while (true) {
        self.makeDir(component.path) catch |err| switch (err) {
            error.PathAlreadyExists => {
                // stat the file and return an error if it's not a directory
                // this is important because otherwise a dangling symlink
                // could cause an infinite loop
                check_dir: {
                    // workaround for windows, see https://github.com/ziglang/zig/issues/16738
                    const fstat = self.statFile(component.path) catch |stat_err| switch (stat_err) {
                        error.IsDir => break :check_dir,
                        else => |e| return e,
                    };
                    if (fstat.kind != .directory) return error.NotDir;
                }
            },
            error.FileNotFound => |e| {
                component = it.previous() orelse return e;
                continue;
            },
            else => |e| return e,
        };
        component = it.next() orelse return;
    }
}

/// Windows only. Calls makeOpenDirAccessMaskW iteratively to make an entire path
/// (i.e. creating any parent directories that do not exist).
/// Opens the dir if the path already exists and is a directory.
/// This function is not atomic, and if it returns an error, the file system may
/// have been modified regardless.
/// `sub_path` should be encoded as [WTF-8](https://simonsapin.github.io/wtf-8/).
fn makeOpenPathAccessMaskW(self: Dir, sub_path: []const u8, access_mask: u32, no_follow: bool) (MakeError || OpenError || StatFileError)!Dir {
    const w = windows;
    var it = try fs.path.componentIterator(sub_path);
    // If there are no components in the path, then create a dummy component with the full path.
    var component = it.last() orelse fs.path.NativeComponentIterator.Component{
        .name = "",
        .path = sub_path,
    };

    while (true) {
        const sub_path_w = try w.sliceToPrefixedFileW(self.fd, component.path);
        const is_last = it.peekNext() == null;
        var result = self.makeOpenDirAccessMaskW(sub_path_w.span().ptr, access_mask, .{
            .no_follow = no_follow,
            .create_disposition = if (is_last) w.FILE_OPEN_IF else w.FILE_CREATE,
        }) catch |err| switch (err) {
            error.FileNotFound => |e| {
                component = it.previous() orelse return e;
                continue;
            },
            error.PathAlreadyExists => result: {
                assert(!is_last);
                // stat the file and return an error if it's not a directory
                // this is important because otherwise a dangling symlink
                // could cause an infinite loop
                check_dir: {
                    // workaround for windows, see https://github.com/ziglang/zig/issues/16738
                    const fstat = self.statFile(component.path) catch |stat_err| switch (stat_err) {
                        error.IsDir => break :check_dir,
                        else => |e| return e,
                    };
                    if (fstat.kind != .directory) return error.NotDir;
                }
                break :result null;
            },
            else => |e| return e,
        };
        // Don't leak the intermediate file handles
        errdefer if (result) |*dir| dir.close();

        component = it.next() orelse return result.?;
    }
}

/// This function performs `makePath`, followed by `openDir`.
/// If supported by the OS, this operation is atomic. It is not atomic on
/// all operating systems.
/// On Windows, `sub_path` should be encoded as [WTF-8](https://simonsapin.github.io/wtf-8/).
/// On WASI, `sub_path` should be encoded as valid UTF-8.
/// On other platforms, `sub_path` is an opaque sequence of bytes with no particular encoding.
pub fn makeOpenPath(self: Dir, sub_path: []const u8, open_dir_options: OpenDirOptions) (MakeError || OpenError || StatFileError)!Dir {
    return switch (native_os) {
        .windows => {
            const w = windows;
            const base_flags = w.STANDARD_RIGHTS_READ | w.FILE_READ_ATTRIBUTES | w.FILE_READ_EA |
                w.SYNCHRONIZE | w.FILE_TRAVERSE |
                (if (open_dir_options.iterate) w.FILE_LIST_DIRECTORY else @as(u32, 0));

            return self.makeOpenPathAccessMaskW(sub_path, base_flags, open_dir_options.no_follow);
        },
        else => {
            return self.openDir(sub_path, open_dir_options) catch |err| switch (err) {
                error.FileNotFound => {
                    try self.makePath(sub_path);
                    return self.openDir(sub_path, open_dir_options);
                },
                else => |e| return e,
            };
        },
    };
}

pub const RealPathError = posix.RealPathError;

///  This function returns the canonicalized absolute pathname of
/// `pathname` relative to this `Dir`. If `pathname` is absolute, ignores this
/// `Dir` handle and returns the canonicalized absolute pathname of `pathname`
/// argument.
/// On Windows, `sub_path` should be encoded as [WTF-8](https://simonsapin.github.io/wtf-8/).
/// On other platforms, `sub_path` is an opaque sequence of bytes with no particular encoding.
/// On Windows, the result is encoded as [WTF-8](https://simonsapin.github.io/wtf-8/).
/// On other platforms, the result is an opaque sequence of bytes with no particular encoding.
/// This function is not universally supported by all platforms.
/// Currently supported hosts are: Linux, macOS, and Windows.
/// See also `Dir.realpathZ`, `Dir.realpathW`, and `Dir.realpathAlloc`.
pub fn realpath(self: Dir, pathname: []const u8, out_buffer: []u8) RealPathError![]u8 {
    if (native_os == .wasi) {
        @compileError("realpath is not available on WASI");
    }
    if (native_os == .windows) {
        const pathname_w = try windows.sliceToPrefixedFileW(self.fd, pathname);
        return self.realpathW(pathname_w.span(), out_buffer);
    }
    const pathname_c = try posix.toPosixPath(pathname);
    return self.realpathZ(&pathname_c, out_buffer);
}

/// Same as `Dir.realpath` except `pathname` is null-terminated.
/// See also `Dir.realpath`, `realpathZ`.
pub fn realpathZ(self: Dir, pathname: [*:0]const u8, out_buffer: []u8) RealPathError![]u8 {
    if (native_os == .windows) {
        const pathname_w = try windows.cStrToPrefixedFileW(self.fd, pathname);
        return self.realpathW(pathname_w.span(), out_buffer);
    }

    const flags: posix.O = switch (native_os) {
        .linux => .{
            .NONBLOCK = true,
            .CLOEXEC = true,
            .PATH = true,
        },
        else => .{
            .NONBLOCK = true,
            .CLOEXEC = true,
        },
    };

    const fd = posix.openatZ(self.fd, pathname, flags, 0) catch |err| switch (err) {
        error.FileLocksNotSupported => return error.Unexpected,
        error.FileBusy => return error.Unexpected,
        error.WouldBlock => return error.Unexpected,
        error.InvalidUtf8 => unreachable, // WASI-only
        else => |e| return e,
    };
    defer posix.close(fd);

    var buffer: [fs.MAX_PATH_BYTES]u8 = undefined;
    const out_path = try std.os.getFdPath(fd, &buffer);

    if (out_path.len > out_buffer.len) {
        return error.NameTooLong;
    }

    const result = out_buffer[0..out_path.len];
    @memcpy(result, out_path);
    return result;
}

/// Windows-only. Same as `Dir.realpath` except `pathname` is WTF16 LE encoded.
/// The result is encoded as [WTF-8](https://simonsapin.github.io/wtf-8/).
/// See also `Dir.realpath`, `realpathW`.
pub fn realpathW(self: Dir, pathname: []const u16, out_buffer: []u8) RealPathError![]u8 {
    const w = windows;

    const access_mask = w.GENERIC_READ | w.SYNCHRONIZE;
    const share_access = w.FILE_SHARE_READ;
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

    var wide_buf: [w.PATH_MAX_WIDE]u16 = undefined;
    const wide_slice = try w.GetFinalPathNameByHandle(h_file, .{}, &wide_buf);
    var big_out_buf: [fs.MAX_PATH_BYTES]u8 = undefined;
    const end_index = std.unicode.wtf16LeToWtf8(&big_out_buf, wide_slice);
    if (end_index > out_buffer.len)
        return error.NameTooLong;
    const result = out_buffer[0..end_index];
    @memcpy(result, big_out_buf[0..end_index]);
    return result;
}

pub const RealPathAllocError = RealPathError || Allocator.Error;

/// Same as `Dir.realpath` except caller must free the returned memory.
/// See also `Dir.realpath`.
pub fn realpathAlloc(self: Dir, allocator: Allocator, pathname: []const u8) RealPathAllocError![]u8 {
    // Use of MAX_PATH_BYTES here is valid as the realpath function does not
    // have a variant that takes an arbitrary-size buffer.
    // TODO(#4812): Consider reimplementing realpath or using the POSIX.1-2008
    // NULL out parameter (GNU's canonicalize_file_name) to handle overelong
    // paths. musl supports passing NULL but restricts the output to PATH_MAX
    // anyway.
    var buf: [fs.MAX_PATH_BYTES]u8 = undefined;
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

pub const OpenDirOptions = struct {
    /// `true` means the opened directory can be used as the `Dir` parameter
    /// for functions which operate based on an open directory handle. When `false`,
    /// such operations are Illegal Behavior.
    access_sub_paths: bool = true,

    /// `true` means the opened directory can be scanned for the files and sub-directories
    /// of the result. It means the `iterate` function can be called.
    iterate: bool = false,

    /// `true` means it won't dereference the symlinks.
    no_follow: bool = false,
};

/// Opens a directory at the given path. The directory is a system resource that remains
/// open until `close` is called on the result.
/// The directory cannot be iterated unless the `iterate` option is set to `true`.
///
/// On Windows, `sub_path` should be encoded as [WTF-8](https://simonsapin.github.io/wtf-8/).
/// On WASI, `sub_path` should be encoded as valid UTF-8.
/// On other platforms, `sub_path` is an opaque sequence of bytes with no particular encoding.
/// Asserts that the path parameter has no null bytes.
pub fn openDir(self: Dir, sub_path: []const u8, args: OpenDirOptions) OpenError!Dir {
    switch (native_os) {
        .windows => {
            const sub_path_w = try windows.sliceToPrefixedFileW(self.fd, sub_path);
            return self.openDirW(sub_path_w.span().ptr, args);
        },
        .wasi => if (!builtin.link_libc) {
            var base: std.os.wasi.rights_t = .{
                .FD_FILESTAT_GET = true,
                .FD_FDSTAT_SET_FLAGS = true,
                .FD_FILESTAT_SET_TIMES = true,
            };
            if (args.access_sub_paths) {
                base.FD_READDIR = true;
                base.PATH_CREATE_DIRECTORY = true;
                base.PATH_CREATE_FILE = true;
                base.PATH_LINK_SOURCE = true;
                base.PATH_LINK_TARGET = true;
                base.PATH_OPEN = true;
                base.PATH_READLINK = true;
                base.PATH_RENAME_SOURCE = true;
                base.PATH_RENAME_TARGET = true;
                base.PATH_FILESTAT_GET = true;
                base.PATH_FILESTAT_SET_SIZE = true;
                base.PATH_FILESTAT_SET_TIMES = true;
                base.PATH_SYMLINK = true;
                base.PATH_REMOVE_DIRECTORY = true;
                base.PATH_UNLINK_FILE = true;
            }

            const result = posix.openatWasi(
                self.fd,
                sub_path,
                .{ .SYMLINK_FOLLOW = !args.no_follow },
                .{ .DIRECTORY = true },
                .{},
                base,
                base,
            );
            const fd = result catch |err| switch (err) {
                error.FileTooBig => unreachable, // can't happen for directories
                error.IsDir => unreachable, // we're setting DIRECTORY
                error.NoSpaceLeft => unreachable, // not setting CREAT
                error.PathAlreadyExists => unreachable, // not setting CREAT
                error.FileLocksNotSupported => unreachable, // locking folders is not supported
                error.WouldBlock => unreachable, // can't happen for directories
                error.FileBusy => unreachable, // can't happen for directories
                else => |e| return e,
            };
            return .{ .fd = fd };
        },
        else => {},
    }
    const sub_path_c = try posix.toPosixPath(sub_path);
    return self.openDirZ(&sub_path_c, args);
}

/// Same as `openDir` except the parameter is null-terminated.
pub fn openDirZ(self: Dir, sub_path_c: [*:0]const u8, args: OpenDirOptions) OpenError!Dir {
    switch (native_os) {
        .windows => {
            const sub_path_w = try windows.cStrToPrefixedFileW(self.fd, sub_path_c);
            return self.openDirW(sub_path_w.span().ptr, args);
        },
        // Use the libc API when libc is linked because it implements things
        // such as opening absolute directory paths.
        .wasi => if (!builtin.link_libc) {
            return openDir(self, mem.sliceTo(sub_path_c, 0), args);
        },
        .haiku => {
            const rc = posix.system._kern_open_dir(self.fd, sub_path_c);
            if (rc >= 0) return .{ .fd = rc };
            switch (@as(posix.E, @enumFromInt(rc))) {
                .FAULT => unreachable,
                .INVAL => unreachable,
                .BADF => unreachable,
                .ACCES => return error.AccessDenied,
                .LOOP => return error.SymLinkLoop,
                .MFILE => return error.ProcessFdQuotaExceeded,
                .NAMETOOLONG => return error.NameTooLong,
                .NFILE => return error.SystemFdQuotaExceeded,
                .NODEV => return error.NoDevice,
                .NOENT => return error.FileNotFound,
                .NOMEM => return error.SystemResources,
                .NOTDIR => return error.NotDir,
                .PERM => return error.AccessDenied,
                .BUSY => return error.DeviceBusy,
                else => |err| return posix.unexpectedErrno(err),
            }
        },
        else => {},
    }

    var symlink_flags: posix.O = switch (native_os) {
        .wasi => .{
            .read = true,
            .NOFOLLOW = args.no_follow,
            .DIRECTORY = true,
        },
        else => .{
            .ACCMODE = .RDONLY,
            .NOFOLLOW = args.no_follow,
            .DIRECTORY = true,
            .CLOEXEC = true,
        },
    };

    if (@hasField(posix.O, "PATH") and !args.iterate)
        symlink_flags.PATH = true;

    return self.openDirFlagsZ(sub_path_c, symlink_flags);
}

/// Same as `openDir` except the path parameter is WTF-16 LE encoded, NT-prefixed.
/// This function asserts the target OS is Windows.
pub fn openDirW(self: Dir, sub_path_w: [*:0]const u16, args: OpenDirOptions) OpenError!Dir {
    const w = windows;
    // TODO remove some of these flags if args.access_sub_paths is false
    const base_flags = w.STANDARD_RIGHTS_READ | w.FILE_READ_ATTRIBUTES | w.FILE_READ_EA |
        w.SYNCHRONIZE | w.FILE_TRAVERSE;
    const flags: u32 = if (args.iterate) base_flags | w.FILE_LIST_DIRECTORY else base_flags;
    const dir = self.makeOpenDirAccessMaskW(sub_path_w, flags, .{
        .no_follow = args.no_follow,
        .create_disposition = w.FILE_OPEN,
    }) catch |err| switch (err) {
        error.ReadOnlyFileSystem => unreachable,
        error.DiskQuota => unreachable,
        error.NoSpaceLeft => unreachable,
        error.PathAlreadyExists => unreachable,
        error.LinkQuotaExceeded => unreachable,
        else => |e| return e,
    };
    return dir;
}

/// Asserts `flags` has `DIRECTORY` set.
fn openDirFlagsZ(self: Dir, sub_path_c: [*:0]const u8, flags: posix.O) OpenError!Dir {
    assert(flags.DIRECTORY);
    const fd = posix.openatZ(self.fd, sub_path_c, flags, 0) catch |err| switch (err) {
        error.FileTooBig => unreachable, // can't happen for directories
        error.IsDir => unreachable, // we're setting DIRECTORY
        error.NoSpaceLeft => unreachable, // not setting CREAT
        error.PathAlreadyExists => unreachable, // not setting CREAT
        error.FileLocksNotSupported => unreachable, // locking folders is not supported
        error.WouldBlock => unreachable, // can't happen for directories
        error.FileBusy => unreachable, // can't happen for directories
        else => |e| return e,
    };
    return Dir{ .fd = fd };
}

const MakeOpenDirAccessMaskWOptions = struct {
    no_follow: bool,
    create_disposition: u32,
};

fn makeOpenDirAccessMaskW(self: Dir, sub_path_w: [*:0]const u16, access_mask: u32, flags: MakeOpenDirAccessMaskWOptions) (MakeError || OpenError)!Dir {
    const w = windows;

    var result = Dir{
        .fd = undefined,
    };

    const path_len_bytes = @as(u16, @intCast(mem.sliceTo(sub_path_w, 0).len * 2));
    var nt_name = w.UNICODE_STRING{
        .Length = path_len_bytes,
        .MaximumLength = path_len_bytes,
        .Buffer = @constCast(sub_path_w),
    };
    var attr = w.OBJECT_ATTRIBUTES{
        .Length = @sizeOf(w.OBJECT_ATTRIBUTES),
        .RootDirectory = if (fs.path.isAbsoluteWindowsW(sub_path_w)) null else self.fd,
        .Attributes = 0, // Note we do not use OBJ_CASE_INSENSITIVE here.
        .ObjectName = &nt_name,
        .SecurityDescriptor = null,
        .SecurityQualityOfService = null,
    };
    const open_reparse_point: w.DWORD = if (flags.no_follow) w.FILE_OPEN_REPARSE_POINT else 0x0;
    var io: w.IO_STATUS_BLOCK = undefined;
    const rc = w.ntdll.NtCreateFile(
        &result.fd,
        access_mask,
        &attr,
        &io,
        null,
        w.FILE_ATTRIBUTE_NORMAL,
        w.FILE_SHARE_READ | w.FILE_SHARE_WRITE,
        flags.create_disposition,
        w.FILE_DIRECTORY_FILE | w.FILE_SYNCHRONOUS_IO_NONALERT | w.FILE_OPEN_FOR_BACKUP_INTENT | open_reparse_point,
        null,
        0,
    );

    switch (rc) {
        .SUCCESS => return result,
        .OBJECT_NAME_INVALID => return error.BadPathName,
        .OBJECT_NAME_NOT_FOUND => return error.FileNotFound,
        .OBJECT_NAME_COLLISION => return error.PathAlreadyExists,
        .OBJECT_PATH_NOT_FOUND => return error.FileNotFound,
        .NOT_A_DIRECTORY => return error.NotDir,
        // This can happen if the directory has 'List folder contents' permission set to 'Deny'
        // and the directory is trying to be opened for iteration.
        .ACCESS_DENIED => return error.AccessDenied,
        .INVALID_PARAMETER => unreachable,
        else => return w.unexpectedStatus(rc),
    }
}

pub const DeleteFileError = posix.UnlinkError;

/// Delete a file name and possibly the file it refers to, based on an open directory handle.
/// On Windows, `sub_path` should be encoded as [WTF-8](https://simonsapin.github.io/wtf-8/).
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
        error.AccessDenied => |e| switch (native_os) {
            // non-Linux POSIX systems return EPERM when trying to delete a directory, so
            // we need to handle that case specifically and translate the error
            .macos, .ios, .freebsd, .netbsd, .dragonfly, .openbsd, .solaris, .illumos => {
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
    FileBusy,
    FileSystem,
    SymLinkLoop,
    NameTooLong,
    NotDir,
    SystemResources,
    ReadOnlyFileSystem,
    /// WASI-only; file paths must be valid UTF-8.
    InvalidUtf8,
    /// Windows-only; file paths provided by the user must be valid WTF-8.
    /// https://simonsapin.github.io/wtf-8/
    InvalidWtf8,
    BadPathName,
    /// On Windows, `\\server` or `\\server\share` was not found.
    NetworkNotFound,
    Unexpected,
};

/// Returns `error.DirNotEmpty` if the directory is not empty.
/// To delete a directory recursively, see `deleteTree`.
/// On Windows, `sub_path` should be encoded as [WTF-8](https://simonsapin.github.io/wtf-8/).
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
/// On Windows, both paths should be encoded as [WTF-8](https://simonsapin.github.io/wtf-8/).
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
    return posix.renameatW(self.fd, old_sub_path_w, self.fd, new_sub_path_w);
}

/// Use with `Dir.symLink` and `symLinkAbsolute` to specify whether the symlink
/// will point to a file or a directory. This value is ignored on all hosts
/// except Windows where creating symlinks to different resource types, requires
/// different flags. By default, `symLinkAbsolute` is assumed to point to a file.
pub const SymLinkFlags = struct {
    is_directory: bool = false,
};

/// Creates a symbolic link named `sym_link_path` which contains the string `target_path`.
/// A symbolic link (also known as a soft link) may point to an existing file or to a nonexistent
/// one; the latter case is known as a dangling link.
/// If `sym_link_path` exists, it will not be overwritten.
/// On Windows, both paths should be encoded as [WTF-8](https://simonsapin.github.io/wtf-8/).
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
        target_path_w.len = try std.unicode.wtf8ToWtf16Le(&target_path_w.data, target_path);
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

pub const ReadLinkError = posix.ReadLinkError;

/// Read value of a symbolic link.
/// The return value is a slice of `buffer`, from index `0`.
/// Asserts that the path parameter has no null bytes.
/// On Windows, `sub_path` should be encoded as [WTF-8](https://simonsapin.github.io/wtf-8/).
/// On WASI, `sub_path` should be encoded as valid UTF-8.
/// On other platforms, `sub_path` is an opaque sequence of bytes with no particular encoding.
pub fn readLink(self: Dir, sub_path: []const u8, buffer: []u8) ReadLinkError![]u8 {
    if (native_os == .wasi and !builtin.link_libc) {
        return self.readLinkWasi(sub_path, buffer);
    }
    if (native_os == .windows) {
        const sub_path_w = try windows.sliceToPrefixedFileW(self.fd, sub_path);
        return self.readLinkW(sub_path_w.span(), buffer);
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
        const sub_path_w = try windows.cStrToPrefixedFileW(self.fd, sub_path_c);
        return self.readLinkW(sub_path_w.span(), buffer);
    }
    return posix.readlinkatZ(self.fd, sub_path_c, buffer);
}

/// Windows-only. Same as `readLink` except the pathname parameter
/// is WTF16 LE encoded.
pub fn readLinkW(self: Dir, sub_path_w: []const u16, buffer: []u8) ![]u8 {
    return windows.ReadLink(self.fd, sub_path_w, buffer);
}

/// Read all of file contents using a preallocated buffer.
/// The returned slice has the same pointer as `buffer`. If the length matches `buffer.len`
/// the situation is ambiguous. It could either mean that the entire file was read, and
/// it exactly fits the buffer, or it could mean the buffer was not big enough for the
/// entire file.
/// On Windows, `file_path` should be encoded as [WTF-8](https://simonsapin.github.io/wtf-8/).
/// On WASI, `file_path` should be encoded as valid UTF-8.
/// On other platforms, `file_path` is an opaque sequence of bytes with no particular encoding.
pub fn readFile(self: Dir, file_path: []const u8, buffer: []u8) ![]u8 {
    var file = try self.openFile(file_path, .{});
    defer file.close();

    const end_index = try file.readAll(buffer);
    return buffer[0..end_index];
}

/// On success, caller owns returned buffer.
/// If the file is larger than `max_bytes`, returns `error.FileTooBig`.
/// On Windows, `file_path` should be encoded as [WTF-8](https://simonsapin.github.io/wtf-8/).
/// On WASI, `file_path` should be encoded as valid UTF-8.
/// On other platforms, `file_path` is an opaque sequence of bytes with no particular encoding.
pub fn readFileAlloc(self: Dir, allocator: mem.Allocator, file_path: []const u8, max_bytes: usize) ![]u8 {
    return self.readFileAllocOptions(allocator, file_path, max_bytes, null, @alignOf(u8), null);
}

/// On success, caller owns returned buffer.
/// If the file is larger than `max_bytes`, returns `error.FileTooBig`.
/// If `size_hint` is specified the initial buffer size is calculated using
/// that value, otherwise the effective file size is used instead.
/// Allows specifying alignment and a sentinel value.
/// On Windows, `file_path` should be encoded as [WTF-8](https://simonsapin.github.io/wtf-8/).
/// On WASI, `file_path` should be encoded as valid UTF-8.
/// On other platforms, `file_path` is an opaque sequence of bytes with no particular encoding.
pub fn readFileAllocOptions(
    self: Dir,
    allocator: mem.Allocator,
    file_path: []const u8,
    max_bytes: usize,
    size_hint: ?usize,
    comptime alignment: u29,
    comptime optional_sentinel: ?u8,
) !(if (optional_sentinel) |s| [:s]align(alignment) u8 else []align(alignment) u8) {
    var file = try self.openFile(file_path, .{});
    defer file.close();

    // If the file size doesn't fit a usize it'll be certainly greater than
    // `max_bytes`
    const stat_size = size_hint orelse std.math.cast(usize, try file.getEndPos()) orelse
        return error.FileTooBig;

    return file.readToEndAllocOptions(allocator, max_bytes, stat_size, alignment, optional_sentinel);
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

    /// WASI-only; file paths must be valid UTF-8.
    InvalidUtf8,

    /// Windows-only; file paths provided by the user must be valid WTF-8.
    /// https://simonsapin.github.io/wtf-8/
    InvalidWtf8,

    /// On Windows, file paths cannot contain these characters:
    /// '/', '*', '?', '"', '<', '>', '|'
    BadPathName,

    /// On Windows, `\\server` or `\\server\share` was not found.
    NetworkNotFound,
} || posix.UnexpectedError;

/// Whether `full_path` describes a symlink, file, or directory, this function
/// removes it. If it cannot be removed because it is a non-empty directory,
/// this function recursively removes its entries and then tries again.
/// This operation is not atomic on most file systems.
/// On Windows, `sub_path` should be encoded as [WTF-8](https://simonsapin.github.io/wtf-8/).
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
                            .no_follow = true,
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
                            error.SymLinkLoop,
                            error.ProcessFdQuotaExceeded,
                            error.NameTooLong,
                            error.SystemFdQuotaExceeded,
                            error.NoDevice,
                            error.SystemResources,
                            error.Unexpected,
                            error.InvalidUtf8,
                            error.InvalidWtf8,
                            error.BadPathName,
                            error.NetworkNotFound,
                            error.DeviceBusy,
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
                        error.InvalidUtf8,
                        error.InvalidWtf8,
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
                            .no_follow = true,
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
                            error.SymLinkLoop,
                            error.ProcessFdQuotaExceeded,
                            error.NameTooLong,
                            error.SystemFdQuotaExceeded,
                            error.NoDevice,
                            error.SystemResources,
                            error.Unexpected,
                            error.InvalidUtf8,
                            error.InvalidWtf8,
                            error.BadPathName,
                            error.NetworkNotFound,
                            error.DeviceBusy,
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
                            error.InvalidUtf8,
                            error.InvalidWtf8,
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
/// On Windows, `sub_path` should be encoded as [WTF-8](https://simonsapin.github.io/wtf-8/).
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

        // Valid use of MAX_PATH_BYTES because dir_name_buf will only
        // ever store a single path component that was returned from the
        // filesystem.
        var dir_name_buf: [fs.MAX_PATH_BYTES]u8 = undefined;
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
                            .no_follow = true,
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
                            error.SymLinkLoop,
                            error.ProcessFdQuotaExceeded,
                            error.NameTooLong,
                            error.SystemFdQuotaExceeded,
                            error.NoDevice,
                            error.SystemResources,
                            error.Unexpected,
                            error.InvalidUtf8,
                            error.InvalidWtf8,
                            error.BadPathName,
                            error.NetworkNotFound,
                            error.DeviceBusy,
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
                            error.InvalidUtf8,
                            error.InvalidWtf8,
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
                    .no_follow = true,
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
                    error.SymLinkLoop,
                    error.ProcessFdQuotaExceeded,
                    error.NameTooLong,
                    error.SystemFdQuotaExceeded,
                    error.NoDevice,
                    error.SystemResources,
                    error.Unexpected,
                    error.InvalidUtf8,
                    error.InvalidWtf8,
                    error.BadPathName,
                    error.DeviceBusy,
                    error.NetworkNotFound,
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
                    error.InvalidUtf8,
                    error.InvalidWtf8,
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
    /// On Windows, `sub_path` should be encoded as [WTF-8](https://simonsapin.github.io/wtf-8/).
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

pub const writeFile2 = @compileError("deprecated; renamed to writeFile");

pub const AccessError = posix.AccessError;

/// Test accessing `sub_path`.
/// On Windows, `sub_path` should be encoded as [WTF-8](https://simonsapin.github.io/wtf-8/).
/// On WASI, `sub_path` should be encoded as valid UTF-8.
/// On other platforms, `sub_path` is an opaque sequence of bytes with no particular encoding.
/// Be careful of Time-Of-Check-Time-Of-Use race conditions when using this function.
/// For example, instead of testing if a file exists and then opening it, just
/// open it and handle the error for file not found.
pub fn access(self: Dir, sub_path: []const u8, flags: File.OpenFlags) AccessError!void {
    if (native_os == .windows) {
        const sub_path_w = windows.sliceToPrefixedFileW(self.fd, sub_path) catch |err| switch (err) {
            error.AccessDenied => return error.PermissionDenied,
            else => |e| return e,
        };
        return self.accessW(sub_path_w.span().ptr, flags);
    }
    const path_c = try posix.toPosixPath(sub_path);
    return self.accessZ(&path_c, flags);
}

/// Same as `access` except the path parameter is null-terminated.
pub fn accessZ(self: Dir, sub_path: [*:0]const u8, flags: File.OpenFlags) AccessError!void {
    if (native_os == .windows) {
        const sub_path_w = windows.cStrToPrefixedFileW(self.fd, sub_path) catch |err| switch (err) {
            error.AccessDenied => return error.PermissionDenied,
            else => |e| return e,
        };
        return self.accessW(sub_path_w.span().ptr, flags);
    }
    const os_mode = switch (flags.mode) {
        .read_only => @as(u32, posix.F_OK),
        .write_only => @as(u32, posix.W_OK),
        .read_write => @as(u32, posix.R_OK | posix.W_OK),
    };
    const result = posix.faccessatZ(self.fd, sub_path, os_mode, 0);
    return result;
}

/// Same as `access` except asserts the target OS is Windows and the path parameter is
/// * WTF-16 LE encoded
/// * null-terminated
/// * relative or has the NT namespace prefix
/// TODO currently this ignores `flags`.
pub fn accessW(self: Dir, sub_path_w: [*:0]const u16, flags: File.OpenFlags) AccessError!void {
    _ = flags;
    return posix.faccessatW(self.fd, sub_path_w);
}

pub const CopyFileOptions = struct {
    /// When this is `null` the mode is copied from the source file.
    override_mode: ?File.Mode = null,
};

pub const PrevStatus = enum {
    stale,
    fresh,
};

/// Check the file size, mtime, and mode of `source_path` and `dest_path`. If they are equal, does nothing.
/// Otherwise, atomically copies `source_path` to `dest_path`. The destination file gains the mtime,
/// atime, and mode of the source file so that the next call to `updateFile` will not need a copy.
/// Returns the previous status of the file before updating.
/// If any of the directories do not exist for dest_path, they are created.
/// On Windows, both paths should be encoded as [WTF-8](https://simonsapin.github.io/wtf-8/).
/// On WASI, both paths should be encoded as valid UTF-8.
/// On other platforms, both paths are an opaque sequence of bytes with no particular encoding.
pub fn updateFile(
    source_dir: Dir,
    source_path: []const u8,
    dest_dir: Dir,
    dest_path: []const u8,
    options: CopyFileOptions,
) !PrevStatus {
    var src_file = try source_dir.openFile(source_path, .{});
    defer src_file.close();

    const src_stat = try src_file.stat();
    const actual_mode = options.override_mode orelse src_stat.mode;
    check_dest_stat: {
        const dest_stat = blk: {
            var dest_file = dest_dir.openFile(dest_path, .{}) catch |err| switch (err) {
                error.FileNotFound => break :check_dest_stat,
                else => |e| return e,
            };
            defer dest_file.close();

            break :blk try dest_file.stat();
        };

        if (src_stat.size == dest_stat.size and
            src_stat.mtime == dest_stat.mtime and
            actual_mode == dest_stat.mode)
        {
            return PrevStatus.fresh;
        }
    }

    if (fs.path.dirname(dest_path)) |dirname| {
        try dest_dir.makePath(dirname);
    }

    var atomic_file = try dest_dir.atomicFile(dest_path, .{ .mode = actual_mode });
    defer atomic_file.deinit();

    try atomic_file.file.writeFileAll(src_file, .{ .in_len = src_stat.size });
    try atomic_file.file.updateTimes(src_stat.atime, src_stat.mtime);
    try atomic_file.finish();
    return PrevStatus.stale;
}

pub const CopyFileError = File.OpenError || File.StatError ||
    AtomicFile.InitError || CopyFileRawError || AtomicFile.FinishError;

/// Guaranteed to be atomic.
/// On Linux, until https://patchwork.kernel.org/patch/9636735/ is merged and readily available,
/// there is a possibility of power loss or application termination leaving temporary files present
/// in the same directory as dest_path.
/// On Windows, both paths should be encoded as [WTF-8](https://simonsapin.github.io/wtf-8/).
/// On WASI, both paths should be encoded as valid UTF-8.
/// On other platforms, both paths are an opaque sequence of bytes with no particular encoding.
pub fn copyFile(
    source_dir: Dir,
    source_path: []const u8,
    dest_dir: Dir,
    dest_path: []const u8,
    options: CopyFileOptions,
) CopyFileError!void {
    var in_file = try source_dir.openFile(source_path, .{});
    defer in_file.close();

    var size: ?u64 = null;
    const mode = options.override_mode orelse blk: {
        const st = try in_file.stat();
        size = st.size;
        break :blk st.mode;
    };

    var atomic_file = try dest_dir.atomicFile(dest_path, .{ .mode = mode });
    defer atomic_file.deinit();

    try copy_file(in_file.handle, atomic_file.file.handle, size);
    try atomic_file.finish();
}

const CopyFileRawError = error{SystemResources} || posix.CopyFileRangeError || posix.SendFileError;

// Transfer all the data between two file descriptors in the most efficient way.
// The copy starts at offset 0, the initial offsets are preserved.
// No metadata is transferred over.
fn copy_file(fd_in: posix.fd_t, fd_out: posix.fd_t, maybe_size: ?u64) CopyFileRawError!void {
    if (comptime builtin.target.isDarwin()) {
        const rc = posix.system.fcopyfile(fd_in, fd_out, null, posix.system.COPYFILE_DATA);
        switch (posix.errno(rc)) {
            .SUCCESS => return,
            .INVAL => unreachable,
            .NOMEM => return error.SystemResources,
            // The source file is not a directory, symbolic link, or regular file.
            // Try with the fallback path before giving up.
            .OPNOTSUPP => {},
            else => |err| return posix.unexpectedErrno(err),
        }
    }

    if (native_os == .linux) {
        // Try copy_file_range first as that works at the FS level and is the
        // most efficient method (if available).
        var offset: u64 = 0;
        cfr_loop: while (true) {
            // The kernel checks the u64 value `offset+count` for overflow, use
            // a 32 bit value so that the syscall won't return EINVAL except for
            // impossibly large files (> 2^64-1 - 2^32-1).
            const amt = try posix.copy_file_range(fd_in, offset, fd_out, offset, std.math.maxInt(u32), 0);
            // Terminate as soon as we have copied size bytes or no bytes
            if (maybe_size) |s| {
                if (s == amt) break :cfr_loop;
            }
            if (amt == 0) break :cfr_loop;
            offset += amt;
        }
        return;
    }

    // Sendfile is a zero-copy mechanism iff the OS supports it, otherwise the
    // fallback code will copy the contents chunk by chunk.
    const empty_iovec = [0]posix.iovec_const{};
    var offset: u64 = 0;
    sendfile_loop: while (true) {
        const amt = try posix.sendfile(fd_out, fd_in, offset, 0, &empty_iovec, &empty_iovec, 0);
        // Terminate as soon as we have copied size bytes or no bytes
        if (maybe_size) |s| {
            if (s == amt) break :sendfile_loop;
        }
        if (amt == 0) break :sendfile_loop;
        offset += amt;
    }
}

pub const AtomicFileOptions = struct {
    mode: File.Mode = File.default_mode,
    make_path: bool = false,
};

/// Directly access the `.file` field, and then call `AtomicFile.finish` to
/// atomically replace `dest_path` with contents.
/// Always call `AtomicFile.deinit` to clean up, regardless of whether
/// `AtomicFile.finish` succeeded. `dest_path` must remain valid until
/// `AtomicFile.deinit` is called.
/// On Windows, `dest_path` should be encoded as [WTF-8](https://simonsapin.github.io/wtf-8/).
/// On WASI, `dest_path` should be encoded as valid UTF-8.
/// On other platforms, `dest_path` is an opaque sequence of bytes with no particular encoding.
pub fn atomicFile(self: Dir, dest_path: []const u8, options: AtomicFileOptions) !AtomicFile {
    if (fs.path.dirname(dest_path)) |dirname| {
        const dir = if (options.make_path)
            try self.makeOpenPath(dirname, .{})
        else
            try self.openDir(dirname, .{});

        return AtomicFile.init(fs.path.basename(dest_path), options.mode, dir, true);
    } else {
        return AtomicFile.init(dest_path, options.mode, self, false);
    }
}

pub const Stat = File.Stat;
pub const StatError = File.StatError;

pub fn stat(self: Dir) StatError!Stat {
    const file: File = .{ .handle = self.fd };
    return file.stat();
}

pub const StatFileError = File.OpenError || File.StatError || posix.FStatAtError;

/// Returns metadata for a file inside the directory.
///
/// On Windows, this requires three syscalls. On other operating systems, it
/// only takes one.
///
/// Symlinks are followed.
///
/// `sub_path` may be absolute, in which case `self` is ignored.
/// On Windows, `sub_path` should be encoded as [WTF-8](https://simonsapin.github.io/wtf-8/).
/// On WASI, `sub_path` should be encoded as valid UTF-8.
/// On other platforms, `sub_path` is an opaque sequence of bytes with no particular encoding.
pub fn statFile(self: Dir, sub_path: []const u8) StatFileError!Stat {
    if (native_os == .windows) {
        var file = try self.openFile(sub_path, .{});
        defer file.close();
        return file.stat();
    }
    if (native_os == .wasi and !builtin.link_libc) {
        const st = try std.os.fstatat_wasi(self.fd, sub_path, .{ .SYMLINK_FOLLOW = true });
        return Stat.fromWasi(st);
    }
    const st = try posix.fstatat(self.fd, sub_path, 0);
    return Stat.fromSystem(st);
}

pub const ChmodError = File.ChmodError;

/// Changes the mode of the directory.
/// The process must have the correct privileges in order to do this
/// successfully, or must have the effective user ID matching the owner
/// of the directory. Additionally, the directory must have been opened
/// with `OpenDirOptions{ .iterate = true }`.
pub fn chmod(self: Dir, new_mode: File.Mode) ChmodError!void {
    const file: File = .{ .handle = self.fd };
    try file.chmod(new_mode);
}

/// Changes the owner and group of the directory.
/// The process must have the correct privileges in order to do this
/// successfully. The group may be changed by the owner of the directory to
/// any group of which the owner is a member. Additionally, the directory
/// must have been opened with `OpenDirOptions{ .iterate = true }`. If the
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

const Metadata = File.Metadata;
pub const MetadataError = File.MetadataError;

/// Returns a `Metadata` struct, representing the permissions on the directory
pub fn metadata(self: Dir) MetadataError!Metadata {
    const file: File = .{ .handle = self.fd };
    return try file.metadata();
}

const Dir = @This();
const builtin = @import("builtin");
const std = @import("../std.zig");
const File = std.fs.File;
const AtomicFile = std.fs.AtomicFile;
const posix = std.posix;
const mem = std.mem;
const fs = std.fs;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const windows = std.os.windows;
const native_os = builtin.os.tag;
