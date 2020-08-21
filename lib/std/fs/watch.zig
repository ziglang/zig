// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("../std.zig");
const builtin = @import("builtin");
const event = std.event;
const assert = std.debug.assert;
const testing = std.testing;
const os = std.os;
const mem = std.mem;
const windows = os.windows;
const Loop = event.Loop;
const fd_t = os.fd_t;
const File = std.fs.File;
const Allocator = mem.Allocator;

const global_event_loop = Loop.instance orelse
    @compileError("std.fs.Watch currently only works with event-based I/O");

const WatchEventId = enum {
    CloseWrite,
    Delete,
};

fn eqlString(a: []const u16, b: []const u16) bool {
    if (a.len != b.len) return false;
    if (a.ptr == b.ptr) return true;
    return mem.compare(u16, a, b) == .Equal;
}

fn hashString(s: []const u16) u32 {
    return @truncate(u32, std.hash.Wyhash.hash(0, mem.sliceAsBytes(s)));
}

const WatchEventError = error{
    UserResourceLimitReached,
    SystemResources,
    AccessDenied,
    Unexpected, // TODO remove this possibility
};

pub fn Watch(comptime V: type) type {
    return struct {
        channel: *event.Channel(Event.Error!Event),
        os_data: OsData,
        allocator: *Allocator,

        const OsData = switch (builtin.os.tag) {
            // TODO https://github.com/ziglang/zig/issues/3778
            .macosx, .freebsd, .netbsd, .dragonfly => KqOsData,
            .linux => LinuxOsData,
            .windows => WindowsOsData,

            else => @compileError("Unsupported OS"),
        };

        const KqOsData = struct {
            file_table: FileTable,
            table_lock: event.Lock,

            const FileTable = std.StringHashMap(*Put);
            const Put = struct {
                putter_frame: @Frame(kqPutEvents),
                cancelled: bool = false,
                value: V,
            };
        };

        const WindowsOsData = struct {
            table_lock: event.Lock,
            dir_table: DirTable,
            all_putters: std.atomic.Queue(Put),
            ref_count: std.atomic.Int(usize),

            const Put = struct {
                putter: anyframe,
                cancelled: bool = false,
            };

            const DirTable = std.StringHashMap(*Dir);
            const FileTable = std.HashMap([]const u16, V, hashString, eqlString);

            const Dir = struct {
                putter_frame: @Frame(windowsDirReader),
                file_table: FileTable,
                table_lock: event.Lock,
            };
        };

        const LinuxOsData = struct {
            putter_frame: @Frame(linuxEventPutter),
            inotify_fd: i32,
            wd_table: WdTable,
            table_lock: event.Lock,
            cancelled: bool = false,

            const WdTable = std.AutoHashMap(i32, Dir);
            const FileTable = std.StringHashMap(V);

            const Dir = struct {
                dirname: []const u8,
                file_table: FileTable,
            };
        };

        const Self = @This();

        pub const Event = struct {
            id: Id,
            data: V,

            pub const Id = WatchEventId;
            pub const Error = WatchEventError;
        };

        pub fn init(allocator: *Allocator, event_buf_count: usize) !*Self {
            const channel = try allocator.create(event.Channel(Event.Error!Event));
            errdefer allocator.destroy(channel);
            var buf = try allocator.alloc(Event.Error!Event, event_buf_count);
            errdefer allocator.free(buf);
            channel.init(buf);
            errdefer channel.deinit();

            const self = try allocator.create(Self);
            errdefer allocator.destroy(self);

            switch (builtin.os.tag) {
                .linux => {
                    const inotify_fd = try os.inotify_init1(os.linux.IN_NONBLOCK | os.linux.IN_CLOEXEC);
                    errdefer os.close(inotify_fd);

                    self.* = Self{
                        .allocator = allocator,
                        .channel = channel,
                        .os_data = OsData{
                            .putter_frame = undefined,
                            .inotify_fd = inotify_fd,
                            .wd_table = OsData.WdTable.init(allocator),
                            .table_lock = event.Lock.init(),
                        },
                    };

                    self.os_data.putter_frame = async self.linuxEventPutter();
                    return self;
                },

                .windows => {
                    self.* = Self{
                        .allocator = allocator,
                        .channel = channel,
                        .os_data = OsData{
                            .table_lock = event.Lock.init(),
                            .dir_table = OsData.DirTable.init(allocator),
                            .ref_count = std.atomic.Int(usize).init(1),
                            .all_putters = std.atomic.Queue(anyframe).init(),
                        },
                    };
                    return self;
                },

                .macosx, .freebsd, .netbsd, .dragonfly => {
                    self.* = Self{
                        .allocator = allocator,
                        .channel = channel,
                        .os_data = OsData{
                            .table_lock = event.Lock.init(),
                            .file_table = OsData.FileTable.init(allocator),
                        },
                    };
                    return self;
                },
                else => @compileError("Unsupported OS"),
            }
        }

        /// All addFile calls and removeFile calls must have completed.
        pub fn deinit(self: *Self) void {
            switch (builtin.os.tag) {
                .macosx, .freebsd, .netbsd, .dragonfly => {
                    // TODO we need to cancel the frames before destroying the lock
                    self.os_data.table_lock.deinit();
                    var it = self.os_data.file_table.iterator();
                    while (it.next()) |entry| {
                        entry.cancelled = true;
                        await entry.value.putter;
                        self.allocator.free(entry.key);
                        self.allocator.free(entry.value);
                    }
                    self.channel.deinit();
                    self.allocator.destroy(self.channel.buffer_nodes);
                    self.allocator.destroy(self);
                },
                .linux => {
                    self.os_data.cancelled = true;
                    await self.os_data.putter_frame;
                    self.allocator.destroy(self);
                },
                .windows => {
                    while (self.os_data.all_putters.get()) |putter_node| {
                        putter_node.cancelled = true;
                        await putter_node.frame;
                    }
                    self.deref();
                },
                else => @compileError("Unsupported OS"),
            }
        }

        fn ref(self: *Self) void {
            _ = self.os_data.ref_count.incr();
        }

        fn deref(self: *Self) void {
            if (self.os_data.ref_count.decr() == 1) {
                self.os_data.table_lock.deinit();
                var it = self.os_data.dir_table.iterator();
                while (it.next()) |entry| {
                    self.allocator.free(entry.key);
                    self.allocator.destroy(entry.value);
                }
                self.os_data.dir_table.deinit();
                self.channel.deinit();
                self.allocator.destroy(self.channel.buffer_nodes);
                self.allocator.destroy(self);
            }
        }

        pub fn addFile(self: *Self, file_path: []const u8, value: V) !?V {
            switch (builtin.os.tag) {
                .macosx, .freebsd, .netbsd, .dragonfly => return addFileKEvent(self, file_path, value),
                .linux => return addFileLinux(self, file_path, value),
                .windows => return addFileWindows(self, file_path, value),
                else => @compileError("Unsupported OS"),
            }
        }

        fn addFileKEvent(self: *Self, file_path: []const u8, value: V) !?V {
            const resolved_path = try std.fs.path.resolve(self.allocator, [_][]const u8{file_path});
            var resolved_path_consumed = false;
            defer if (!resolved_path_consumed) self.allocator.free(resolved_path);

            var close_op = try CloseOperation.start(self.allocator);
            var close_op_consumed = false;
            defer if (!close_op_consumed) close_op.finish();

            const flags = if (comptime std.Target.current.isDarwin()) os.O_SYMLINK | os.O_EVTONLY else 0;
            const mode = 0;
            const fd = try openPosix(self.allocator, resolved_path, flags, mode);
            close_op.setHandle(fd);

            var put = try self.allocator.create(OsData.Put);
            errdefer self.allocator.destroy(put);
            put.* = OsData.Put{
                .value = value,
                .putter_frame = undefined,
            };
            put.putter_frame = async self.kqPutEvents(close_op, put);
            close_op_consumed = true;
            errdefer {
                put.cancelled = true;
                await put.putter_frame;
            }

            const result = blk: {
                const held = self.os_data.table_lock.acquire();
                defer held.release();

                const gop = try self.os_data.file_table.getOrPut(resolved_path);
                if (gop.found_existing) {
                    const prev_value = gop.kv.value.value;
                    await gop.kv.value.putter_frame;
                    gop.kv.value = put;
                    break :blk prev_value;
                } else {
                    resolved_path_consumed = true;
                    gop.kv.value = put;
                    break :blk null;
                }
            };

            return result;
        }

        fn kqPutEvents(self: *Self, close_op: *CloseOperation, put: *OsData.Put) void {
            global_event_loop.beginOneEvent();

            defer {
                close_op.finish();
                global_event_loop.finishOneEvent();
            }

            while (!put.cancelled) {
                if (global_event_loop.bsdWaitKev(
                    @intCast(usize, close_op.getHandle()),
                    os.EVFILT_VNODE,
                    os.NOTE_WRITE | os.NOTE_DELETE,
                )) |kev| {
                    // TODO handle EV_ERROR
                    if (kev.fflags & os.NOTE_DELETE != 0) {
                        self.channel.put(Self.Event{
                            .id = Event.Id.Delete,
                            .data = put.value,
                        });
                    } else if (kev.fflags & os.NOTE_WRITE != 0) {
                        self.channel.put(Self.Event{
                            .id = Event.Id.CloseWrite,
                            .data = put.value,
                        });
                    }
                } else |err| switch (err) {
                    error.EventNotFound => unreachable,
                    error.ProcessNotFound => unreachable,
                    error.Overflow => unreachable,
                    error.AccessDenied, error.SystemResources => |casted_err| {
                        self.channel.put(casted_err);
                    },
                }
            }
        }

        fn addFileLinux(self: *Self, file_path: []const u8, value: V) !?V {
            const dirname = std.fs.path.dirname(file_path) orelse ".";
            const dirname_with_null = try std.cstr.addNullByte(self.allocator, dirname);
            var dirname_with_null_consumed = false;
            defer if (!dirname_with_null_consumed) self.channel.free(dirname_with_null);

            const basename = std.fs.path.basename(file_path);
            const basename_with_null = try std.cstr.addNullByte(self.allocator, basename);
            var basename_with_null_consumed = false;
            defer if (!basename_with_null_consumed) self.allocator.free(basename_with_null);

            const wd = try os.inotify_add_watchZ(
                self.os_data.inotify_fd,
                dirname_with_null.ptr,
                os.linux.IN_CLOSE_WRITE | os.linux.IN_ONLYDIR | os.linux.IN_EXCL_UNLINK,
            );
            // wd is either a newly created watch or an existing one.

            const held = self.os_data.table_lock.acquire();
            defer held.release();

            const gop = try self.os_data.wd_table.getOrPut(wd);
            if (!gop.found_existing) {
                gop.kv.value = OsData.Dir{
                    .dirname = dirname_with_null,
                    .file_table = OsData.FileTable.init(self.allocator),
                };
                dirname_with_null_consumed = true;
            }
            const dir = &gop.kv.value;

            const file_table_gop = try dir.file_table.getOrPut(basename_with_null);
            if (file_table_gop.found_existing) {
                const prev_value = file_table_gop.kv.value;
                file_table_gop.kv.value = value;
                return prev_value;
            } else {
                file_table_gop.kv.value = value;
                basename_with_null_consumed = true;
                return null;
            }
        }

        fn addFileWindows(self: *Self, file_path: []const u8, value: V) !?V {
            // TODO we might need to convert dirname and basename to canonical file paths ("short"?)
            const dirname = try self.allocator.dupe(u8, std.fs.path.dirname(file_path) orelse ".");
            var dirname_consumed = false;
            defer if (!dirname_consumed) self.allocator.free(dirname);

            const dirname_utf16le = try std.unicode.utf8ToUtf16LeWithNull(self.allocator, dirname);
            defer self.allocator.free(dirname_utf16le);

            // TODO https://github.com/ziglang/zig/issues/265
            const basename = std.fs.path.basename(file_path);
            const basename_utf16le_null = try std.unicode.utf8ToUtf16LeWithNull(self.allocator, basename);
            var basename_utf16le_null_consumed = false;
            defer if (!basename_utf16le_null_consumed) self.allocator.free(basename_utf16le_null);
            const basename_utf16le_no_null = basename_utf16le_null[0 .. basename_utf16le_null.len - 1];

            const dir_handle = try windows.OpenFile(dirname_utf16le, .{
                .dir = std.fs.cwd().fd,
                .access_mask = windows.FILE_LIST_DIRECTORY,
                .creation = windows.FILE_OPEN,
                .io_mode = .blocking,
                .open_dir = true,
            });
            var dir_handle_consumed = false;
            defer if (!dir_handle_consumed) windows.CloseHandle(dir_handle);

            const held = self.os_data.table_lock.acquire();
            defer held.release();

            const gop = try self.os_data.dir_table.getOrPut(dirname);
            if (gop.found_existing) {
                const dir = gop.kv.value;
                const held_dir_lock = dir.table_lock.acquire();
                defer held_dir_lock.release();

                const file_gop = try dir.file_table.getOrPut(basename_utf16le_no_null);
                if (file_gop.found_existing) {
                    const prev_value = file_gop.kv.value;
                    file_gop.kv.value = value;
                    return prev_value;
                } else {
                    file_gop.kv.value = value;
                    basename_utf16le_null_consumed = true;
                    return null;
                }
            } else {
                errdefer _ = self.os_data.dir_table.remove(dirname);
                const dir = try self.allocator.create(OsData.Dir);
                errdefer self.allocator.destroy(dir);

                dir.* = OsData.Dir{
                    .file_table = OsData.FileTable.init(self.allocator),
                    .table_lock = event.Lock.init(),
                    .putter_frame = undefined,
                };
                gop.kv.value = dir;
                assert((try dir.file_table.put(basename_utf16le_no_null, value)) == null);
                basename_utf16le_null_consumed = true;

                dir.putter_frame = async self.windowsDirReader(dir_handle, dir);
                dir_handle_consumed = true;

                dirname_consumed = true;

                return null;
            }
        }

        fn windowsDirReader(self: *Self, dir_handle: windows.HANDLE, dir: *OsData.Dir) void {
            self.ref();
            defer self.deref();

            defer os.close(dir_handle);

            var putter_node = std.atomic.Queue(anyframe).Node{
                .data = .{ .putter = @frame() },
                .prev = null,
                .next = null,
            };
            self.os_data.all_putters.put(&putter_node);
            defer _ = self.os_data.all_putters.remove(&putter_node);

            var resume_node = Loop.ResumeNode.Basic{
                .base = Loop.ResumeNode{
                    .id = Loop.ResumeNode.Id.Basic,
                    .handle = @frame(),
                    .overlapped = windows.OVERLAPPED{
                        .Internal = 0,
                        .InternalHigh = 0,
                        .Offset = 0,
                        .OffsetHigh = 0,
                        .hEvent = null,
                    },
                },
            };
            var event_buf: [4096]u8 align(@alignOf(windows.FILE_NOTIFY_INFORMATION)) = undefined;

            // TODO handle this error not in the channel but in the setup
            _ = windows.CreateIoCompletionPort(
                dir_handle,
                global_event_loop.os_data.io_port,
                undefined,
                undefined,
            ) catch |err| {
                self.channel.put(err);
                return;
            };

            while (!putter_node.data.cancelled) {
                {
                    // TODO only 1 beginOneEvent for the whole function
                    global_event_loop.beginOneEvent();
                    errdefer global_event_loop.finishOneEvent();
                    errdefer {
                        _ = windows.kernel32.CancelIoEx(dir_handle, &resume_node.base.overlapped);
                    }
                    suspend {
                        _ = windows.kernel32.ReadDirectoryChangesW(
                            dir_handle,
                            &event_buf,
                            @intCast(windows.DWORD, event_buf.len),
                            windows.FALSE, // watch subtree
                            windows.FILE_NOTIFY_CHANGE_FILE_NAME | windows.FILE_NOTIFY_CHANGE_DIR_NAME |
                                windows.FILE_NOTIFY_CHANGE_ATTRIBUTES | windows.FILE_NOTIFY_CHANGE_SIZE |
                                windows.FILE_NOTIFY_CHANGE_LAST_WRITE | windows.FILE_NOTIFY_CHANGE_LAST_ACCESS |
                                windows.FILE_NOTIFY_CHANGE_CREATION | windows.FILE_NOTIFY_CHANGE_SECURITY,
                            null, // number of bytes transferred (unused for async)
                            &resume_node.base.overlapped,
                            null, // completion routine - unused because we use IOCP
                        );
                    }
                }
                var bytes_transferred: windows.DWORD = undefined;
                if (windows.kernel32.GetOverlappedResult(dir_handle, &resume_node.base.overlapped, &bytes_transferred, windows.FALSE) == 0) {
                    const err = switch (windows.kernel32.GetLastError()) {
                        else => |err| windows.unexpectedError(err),
                    };
                    self.channel.put(err);
                } else {
                    // can't use @bytesToSlice because of the special variable length name field
                    var ptr = event_buf[0..].ptr;
                    const end_ptr = ptr + bytes_transferred;
                    var ev: *windows.FILE_NOTIFY_INFORMATION = undefined;
                    while (@ptrToInt(ptr) < @ptrToInt(end_ptr)) : (ptr += ev.NextEntryOffset) {
                        ev = @ptrCast(*windows.FILE_NOTIFY_INFORMATION, ptr);
                        const emit = switch (ev.Action) {
                            windows.FILE_ACTION_REMOVED => WatchEventId.Delete,
                            windows.FILE_ACTION_MODIFIED => WatchEventId.CloseWrite,
                            else => null,
                        };
                        if (emit) |id| {
                            const basename_utf16le = ([*]u16)(&ev.FileName)[0 .. ev.FileNameLength / 2];
                            const user_value = blk: {
                                const held = dir.table_lock.acquire();
                                defer held.release();

                                if (dir.file_table.get(basename_utf16le)) |entry| {
                                    break :blk entry.value;
                                } else {
                                    break :blk null;
                                }
                            };
                            if (user_value) |v| {
                                self.channel.put(Event{
                                    .id = id,
                                    .data = v,
                                });
                            }
                        }
                        if (ev.NextEntryOffset == 0) break;
                    }
                }
            }
        }

        pub fn removeFile(self: *Self, file_path: []const u8) ?V {
            @panic("TODO");
        }

        fn linuxEventPutter(self: *Self) void {
            global_event_loop.beginOneEvent();

            defer {
                self.os_data.table_lock.deinit();
                var wd_it = self.os_data.wd_table.iterator();
                while (wd_it.next()) |wd_entry| {
                    var file_it = wd_entry.value.file_table.iterator();
                    while (file_it.next()) |file_entry| {
                        self.allocator.free(file_entry.key);
                    }
                    self.allocator.free(wd_entry.value.dirname);
                    wd_entry.value.file_table.deinit();
                }
                self.os_data.wd_table.deinit();
                global_event_loop.finishOneEvent();
                os.close(self.os_data.inotify_fd);
                self.channel.deinit();
                self.allocator.free(self.channel.buffer_nodes);
            }

            var event_buf: [4096]u8 align(@alignOf(os.linux.inotify_event)) = undefined;

            while (!self.os_data.cancelled) {
                const rc = os.linux.read(self.os_data.inotify_fd, &event_buf, event_buf.len);
                const errno = os.linux.getErrno(rc);
                switch (errno) {
                    0 => {
                        // can't use @bytesToSlice because of the special variable length name field
                        var ptr = event_buf[0..].ptr;
                        const end_ptr = ptr + event_buf.len;
                        var ev: *os.linux.inotify_event = undefined;
                        while (@ptrToInt(ptr) < @ptrToInt(end_ptr)) {
                            ev = @ptrCast(*os.linux.inotify_event, ptr);
                            if (ev.mask & os.linux.IN_CLOSE_WRITE == os.linux.IN_CLOSE_WRITE) {
                                const basename_ptr = ptr + @sizeOf(os.linux.inotify_event);
                                // `ev.len` counts all bytes in `ev.name` including terminating null byte.
                                const basename_with_null = basename_ptr[0..ev.len];
                                const user_value = blk: {
                                    const held = self.os_data.table_lock.acquire();
                                    defer held.release();

                                    const dir = &self.os_data.wd_table.get(ev.wd).?.value;
                                    if (dir.file_table.get(basename_with_null)) |entry| {
                                        break :blk entry.value;
                                    } else {
                                        break :blk null;
                                    }
                                };
                                if (user_value) |v| {
                                    self.channel.put(Event{
                                        .id = WatchEventId.CloseWrite,
                                        .data = v,
                                    });
                                }
                            }

                            ptr = @alignCast(@alignOf(os.linux.inotify_event), ptr + @sizeOf(os.linux.inotify_event) + ev.len);
                        }
                    },
                    os.linux.EINTR => continue,
                    os.linux.EINVAL => unreachable,
                    os.linux.EFAULT => unreachable,
                    os.linux.EAGAIN => {
                        global_event_loop.linuxWaitFd(self.os_data.inotify_fd, os.linux.EPOLLET | os.linux.EPOLLIN | os.EPOLLONESHOT);
                    },
                    else => unreachable,
                }
            }
        }
    };
}

const test_tmp_dir = "std_event_fs_test";

test "write a file, watch it, write it again" {
    // TODO re-enable this test
    if (true) return error.SkipZigTest;

    try fs.cwd().makePath(test_tmp_dir);
    defer fs.cwd().deleteTree(test_tmp_dir) catch {};

    const allocator = std.heap.page_allocator;
    return testFsWatch(&allocator);
}

fn testFsWatch(allocator: *Allocator) !void {
    const file_path = try std.fs.path.join(allocator, [_][]const u8{ test_tmp_dir, "file.txt" });
    defer allocator.free(file_path);

    const contents =
        \\line 1
        \\line 2
    ;
    const line2_offset = 7;

    // first just write then read the file
    try writeFile(allocator, file_path, contents);

    const read_contents = try readFile(allocator, file_path, 1024 * 1024);
    testing.expectEqualSlices(u8, contents, read_contents);

    // now watch the file
    var watch = try Watch(void).init(allocator, 0);
    defer watch.deinit();

    testing.expect((try watch.addFile(file_path, {})) == null);

    const ev = watch.channel.get();
    var ev_consumed = false;
    defer if (!ev_consumed) await ev;

    // overwrite line 2
    const fd = try await openReadWrite(file_path, File.default_mode);
    {
        defer os.close(fd);

        try pwritev(allocator, fd, []const []const u8{"lorem ipsum"}, line2_offset);
    }

    ev_consumed = true;
    switch ((try await ev).id) {
        WatchEventId.CloseWrite => {},
        WatchEventId.Delete => @panic("wrong event"),
    }
    const contents_updated = try readFile(allocator, file_path, 1024 * 1024);
    testing.expectEqualSlices(u8,
        \\line 1
        \\lorem ipsum
    , contents_updated);

    // TODO test deleting the file and then re-adding it. we should get events for both
}
