const builtin = @import("builtin");
const std = @import("../std.zig");
const Watch = @This();
const Step = std.Build.Step;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const fatal = std.zig.fatal;

dir_table: DirTable,
os: Os,
generation: Generation,

/// Key is the directory to watch which contains one or more files we are
/// interested in noticing changes to.
///
/// Value is generation.
const DirTable = std.ArrayHashMapUnmanaged(Cache.Path, void, Cache.Path.TableAdapter, false);

/// Special key of "." means any changes in this directory trigger the steps.
const ReactionSet = std.StringArrayHashMapUnmanaged(StepSet);
const StepSet = std.AutoArrayHashMapUnmanaged(*Step, Generation);

const Generation = u8;

const Hash = std.hash.Wyhash;
const Cache = std.Build.Cache;

const Os = switch (builtin.os.tag) {
    .linux => struct {
        const posix = std.posix;

        /// Keyed differently but indexes correspond 1:1 with `dir_table`.
        handle_table: HandleTable,
        poll_fds: [1]posix.pollfd,

        const HandleTable = std.ArrayHashMapUnmanaged(FileHandle, ReactionSet, FileHandle.Adapter, false);

        const fan_mask: std.os.linux.fanotify.MarkMask = .{
            .CLOSE_WRITE = true,
            .CREATE = true,
            .DELETE = true,
            .DELETE_SELF = true,
            .EVENT_ON_CHILD = true,
            .MOVED_FROM = true,
            .MOVED_TO = true,
            .MOVE_SELF = true,
            .ONDIR = true,
        };

        const FileHandle = struct {
            handle: *align(1) std.os.linux.file_handle,

            fn clone(lfh: FileHandle, gpa: Allocator) Allocator.Error!FileHandle {
                const bytes = lfh.slice();
                const new_ptr = try gpa.alignedAlloc(
                    u8,
                    @alignOf(std.os.linux.file_handle),
                    @sizeOf(std.os.linux.file_handle) + bytes.len,
                );
                const new_header: *std.os.linux.file_handle = @ptrCast(new_ptr);
                new_header.* = lfh.handle.*;
                const new: FileHandle = .{ .handle = new_header };
                @memcpy(new.slice(), lfh.slice());
                return new;
            }

            fn destroy(lfh: FileHandle, gpa: Allocator) void {
                const ptr: [*]u8 = @ptrCast(lfh.handle);
                const allocated_slice = ptr[0 .. @sizeOf(std.os.linux.file_handle) + lfh.handle.handle_bytes];
                return gpa.free(allocated_slice);
            }

            fn slice(lfh: FileHandle) []u8 {
                const ptr: [*]u8 = &lfh.handle.f_handle;
                return ptr[0..lfh.handle.handle_bytes];
            }

            const Adapter = struct {
                pub fn hash(self: Adapter, a: FileHandle) u32 {
                    _ = self;
                    const unsigned_type: u32 = @bitCast(a.handle.handle_type);
                    return @truncate(Hash.hash(unsigned_type, a.slice()));
                }
                pub fn eql(self: Adapter, a: FileHandle, b: FileHandle, b_index: usize) bool {
                    _ = self;
                    _ = b_index;
                    return a.handle.handle_type == b.handle.handle_type and std.mem.eql(u8, a.slice(), b.slice());
                }
            };
        };

        fn getDirHandle(gpa: Allocator, path: std.Build.Cache.Path) !FileHandle {
            var file_handle_buffer: [@sizeOf(std.os.linux.file_handle) + 128]u8 align(@alignOf(std.os.linux.file_handle)) = undefined;
            var mount_id: i32 = undefined;
            var buf: [std.fs.max_path_bytes]u8 = undefined;
            const adjusted_path = if (path.sub_path.len == 0) "./" else std.fmt.bufPrint(&buf, "{s}/", .{
                path.sub_path,
            }) catch return error.NameTooLong;
            const stack_ptr: *std.os.linux.file_handle = @ptrCast(&file_handle_buffer);
            stack_ptr.handle_bytes = file_handle_buffer.len - @sizeOf(std.os.linux.file_handle);
            try posix.name_to_handle_at(path.root_dir.handle.fd, adjusted_path, stack_ptr, &mount_id, std.os.linux.AT.HANDLE_FID);
            const stack_lfh: FileHandle = .{ .handle = stack_ptr };
            return stack_lfh.clone(gpa);
        }

        fn markDirtySteps(w: *Watch, gpa: Allocator) !bool {
            const fan_fd = w.os.getFanFd();
            const fanotify = std.os.linux.fanotify;
            const M = fanotify.event_metadata;
            var events_buf: [256 + 4096]u8 = undefined;
            var any_dirty = false;
            while (true) {
                var len = posix.read(fan_fd, &events_buf) catch |err| switch (err) {
                    error.WouldBlock => return any_dirty,
                    else => |e| return e,
                };
                var meta: [*]align(1) M = @ptrCast(&events_buf);
                while (len >= @sizeOf(M) and meta[0].event_len >= @sizeOf(M) and meta[0].event_len <= len) : ({
                    len -= meta[0].event_len;
                    meta = @ptrCast(@as([*]u8, @ptrCast(meta)) + meta[0].event_len);
                }) {
                    assert(meta[0].vers == M.VERSION);
                    if (meta[0].mask.Q_OVERFLOW) {
                        any_dirty = true;
                        std.log.warn("file system watch queue overflowed; falling back to fstat", .{});
                        markAllFilesDirty(w, gpa);
                        return true;
                    }
                    const fid: *align(1) fanotify.event_info_fid = @ptrCast(meta + 1);
                    switch (fid.hdr.info_type) {
                        .DFID_NAME => {
                            const file_handle: *align(1) std.os.linux.file_handle = @ptrCast(&fid.handle);
                            const file_name_z: [*:0]u8 = @ptrCast((&file_handle.f_handle).ptr + file_handle.handle_bytes);
                            const file_name = std.mem.span(file_name_z);
                            const lfh: FileHandle = .{ .handle = file_handle };
                            if (w.os.handle_table.getPtr(lfh)) |reaction_set| {
                                if (reaction_set.getPtr(".")) |glob_set|
                                    any_dirty = markStepSetDirty(gpa, glob_set, any_dirty);
                                if (reaction_set.getPtr(file_name)) |step_set|
                                    any_dirty = markStepSetDirty(gpa, step_set, any_dirty);
                            }
                        },
                        else => |t| std.log.warn("unexpected fanotify event '{s}'", .{@tagName(t)}),
                    }
                }
            }
        }

        fn getFanFd(os: *const @This()) posix.fd_t {
            return os.poll_fds[0].fd;
        }

        fn update(w: *Watch, gpa: Allocator, steps: []const *Step) !void {
            const fan_fd = w.os.getFanFd();
            // Add missing marks and note persisted ones.
            for (steps) |step| {
                for (step.inputs.table.keys(), step.inputs.table.values()) |path, *files| {
                    const reaction_set = rs: {
                        const gop = try w.dir_table.getOrPut(gpa, path);
                        if (!gop.found_existing) {
                            const dir_handle = try Os.getDirHandle(gpa, path);
                            // `dir_handle` may already be present in the table in
                            // the case that we have multiple Cache.Path instances
                            // that compare inequal but ultimately point to the same
                            // directory on the file system.
                            // In such case, we must revert adding this directory, but keep
                            // the additions to the step set.
                            const dh_gop = try w.os.handle_table.getOrPut(gpa, dir_handle);
                            if (dh_gop.found_existing) {
                                _ = w.dir_table.pop();
                            } else {
                                assert(dh_gop.index == gop.index);
                                dh_gop.value_ptr.* = .{};
                                posix.fanotify_mark(fan_fd, .{
                                    .ADD = true,
                                    .ONLYDIR = true,
                                }, fan_mask, path.root_dir.handle.fd, path.subPathOrDot()) catch |err| {
                                    fatal("unable to watch {}: {s}", .{ path, @errorName(err) });
                                };
                            }
                            break :rs dh_gop.value_ptr;
                        }
                        break :rs &w.os.handle_table.values()[gop.index];
                    };
                    for (files.items) |basename| {
                        const gop = try reaction_set.getOrPut(gpa, basename);
                        if (!gop.found_existing) gop.value_ptr.* = .{};
                        try gop.value_ptr.put(gpa, step, w.generation);
                    }
                }
            }

            {
                // Remove marks for files that are no longer inputs.
                var i: usize = 0;
                while (i < w.os.handle_table.entries.len) {
                    {
                        const reaction_set = &w.os.handle_table.values()[i];
                        var step_set_i: usize = 0;
                        while (step_set_i < reaction_set.entries.len) {
                            const step_set = &reaction_set.values()[step_set_i];
                            var dirent_i: usize = 0;
                            while (dirent_i < step_set.entries.len) {
                                const generations = step_set.values();
                                if (generations[dirent_i] == w.generation) {
                                    dirent_i += 1;
                                    continue;
                                }
                                step_set.swapRemoveAt(dirent_i);
                            }
                            if (step_set.entries.len > 0) {
                                step_set_i += 1;
                                continue;
                            }
                            reaction_set.swapRemoveAt(step_set_i);
                        }
                        if (reaction_set.entries.len > 0) {
                            i += 1;
                            continue;
                        }
                    }

                    const path = w.dir_table.keys()[i];

                    posix.fanotify_mark(fan_fd, .{
                        .REMOVE = true,
                        .ONLYDIR = true,
                    }, fan_mask, path.root_dir.handle.fd, path.subPathOrDot()) catch |err| switch (err) {
                        error.FileNotFound => {}, // Expected, harmless.
                        else => |e| std.log.warn("unable to unwatch '{}': {s}", .{ path, @errorName(e) }),
                    };

                    w.dir_table.swapRemoveAt(i);
                    w.os.handle_table.swapRemoveAt(i);
                }
                w.generation +%= 1;
            }
        }
    },
    .windows => struct {
        const windows = std.os.windows;

        /// Keyed differently but indexes correspond 1:1 with `dir_table`.
        handle_table: HandleTable,
        dir_list: std.AutoArrayHashMapUnmanaged(usize, *Directory),
        io_cp: ?windows.HANDLE,
        counter: usize = 0,

        const HandleTable = std.AutoArrayHashMapUnmanaged(FileId, ReactionSet);

        const FileId = struct {
            volumeSerialNumber: windows.ULONG,
            indexNumber: windows.LARGE_INTEGER,
        };

        const Directory = struct {
            handle: windows.HANDLE,
            id: FileId,
            overlapped: windows.OVERLAPPED,
            // 64 KB is the packet size limit when monitoring over a network.
            // https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-readdirectorychangesw#remarks
            buffer: [64 * 1024]u8 align(@alignOf(windows.FILE_NOTIFY_INFORMATION)) = undefined,

            /// Start listening for events, buffer field will be overwritten eventually.
            fn startListening(self: *@This()) !void {
                const r = windows.kernel32.ReadDirectoryChangesW(
                    self.handle,
                    @ptrCast(&self.buffer),
                    self.buffer.len,
                    0,
                    .{
                        .creation = true,
                        .dir_name = true,
                        .file_name = true,
                        .last_write = true,
                        .size = true,
                    },
                    null,
                    &self.overlapped,
                    null,
                );
                if (r == windows.FALSE) {
                    switch (windows.GetLastError()) {
                        .INVALID_FUNCTION => return error.ReadDirectoryChangesUnsupported,
                        else => |err| return windows.unexpectedError(err),
                    }
                }
            }

            fn init(gpa: Allocator, path: Cache.Path) !*@This() {
                // The following code is a drawn out NtCreateFile call. (mostly adapted from std.fs.Dir.makeOpenDirAccessMaskW)
                // It's necessary in order to get the specific flags that are required when calling ReadDirectoryChangesW.
                var dir_handle: windows.HANDLE = undefined;
                const root_fd = path.root_dir.handle.fd;
                const sub_path = path.subPathOrDot();
                const sub_path_w = try windows.sliceToPrefixedFileW(root_fd, sub_path);
                const path_len_bytes = std.math.cast(u16, sub_path_w.len * 2) orelse return error.NameTooLong;

                var nt_name = windows.UNICODE_STRING{
                    .Length = @intCast(path_len_bytes),
                    .MaximumLength = @intCast(path_len_bytes),
                    .Buffer = @constCast(sub_path_w.span().ptr),
                };
                var attr = windows.OBJECT_ATTRIBUTES{
                    .Length = @sizeOf(windows.OBJECT_ATTRIBUTES),
                    .RootDirectory = if (std.fs.path.isAbsoluteWindowsW(sub_path_w.span())) null else root_fd,
                    .Attributes = 0, // Note we do not use OBJ_CASE_INSENSITIVE here.
                    .ObjectName = &nt_name,
                    .SecurityDescriptor = null,
                    .SecurityQualityOfService = null,
                };
                var io: windows.IO_STATUS_BLOCK = undefined;

                switch (windows.ntdll.NtCreateFile(
                    &dir_handle,
                    windows.SYNCHRONIZE | windows.GENERIC_READ | windows.FILE_LIST_DIRECTORY,
                    &attr,
                    &io,
                    null,
                    0,
                    windows.FILE_SHARE_READ | windows.FILE_SHARE_WRITE | windows.FILE_SHARE_DELETE,
                    windows.FILE_OPEN,
                    windows.FILE_DIRECTORY_FILE | windows.FILE_OPEN_FOR_BACKUP_INTENT,
                    null,
                    0,
                )) {
                    .SUCCESS => {},
                    .OBJECT_NAME_INVALID => return error.BadPathName,
                    .OBJECT_NAME_NOT_FOUND => return error.FileNotFound,
                    .OBJECT_NAME_COLLISION => return error.PathAlreadyExists,
                    .OBJECT_PATH_NOT_FOUND => return error.FileNotFound,
                    .NOT_A_DIRECTORY => return error.NotDir,
                    // This can happen if the directory has 'List folder contents' permission set to 'Deny'
                    .ACCESS_DENIED => return error.AccessDenied,
                    .INVALID_PARAMETER => unreachable,
                    else => |rc| return windows.unexpectedStatus(rc),
                }
                assert(dir_handle != windows.INVALID_HANDLE_VALUE);
                errdefer windows.CloseHandle(dir_handle);

                const dir_id = try getFileId(dir_handle);

                const dir_ptr = try gpa.create(@This());
                dir_ptr.* = .{
                    .handle = dir_handle,
                    .id = dir_id,
                    .overlapped = std.mem.zeroes(windows.OVERLAPPED),
                };
                return dir_ptr;
            }

            fn deinit(self: *@This(), gpa: Allocator) void {
                _ = windows.kernel32.CancelIo(self.handle);
                windows.CloseHandle(self.handle);
                gpa.destroy(self);
            }
        };

        fn getFileId(handle: windows.HANDLE) !FileId {
            var file_id: FileId = undefined;
            var io_status: windows.IO_STATUS_BLOCK = undefined;
            var volume_info: windows.FILE_FS_VOLUME_INFORMATION = undefined;
            switch (windows.ntdll.NtQueryVolumeInformationFile(
                handle,
                &io_status,
                &volume_info,
                @sizeOf(windows.FILE_FS_VOLUME_INFORMATION),
                .FileFsVolumeInformation,
            )) {
                .SUCCESS => {},
                // Buffer overflow here indicates that there is more information available than was able to be stored in the buffer
                // size provided. This is treated as success because the type of variable-length information that this would be relevant for
                // (name, volume name, etc) we don't care about.
                .BUFFER_OVERFLOW => {},
                else => |rc| return windows.unexpectedStatus(rc),
            }
            file_id.volumeSerialNumber = volume_info.VolumeSerialNumber;
            var internal_info: windows.FILE_INTERNAL_INFORMATION = undefined;
            switch (windows.ntdll.NtQueryInformationFile(
                handle,
                &io_status,
                &internal_info,
                @sizeOf(windows.FILE_INTERNAL_INFORMATION),
                .FileInternalInformation,
            )) {
                .SUCCESS => {},
                else => |rc| return windows.unexpectedStatus(rc),
            }
            file_id.indexNumber = internal_info.IndexNumber;
            return file_id;
        }

        fn markDirtySteps(w: *Watch, gpa: Allocator, dir: *Directory) !bool {
            var any_dirty = false;
            const bytes_returned = try windows.GetOverlappedResult(dir.handle, &dir.overlapped, false);
            if (bytes_returned == 0) {
                std.log.warn("file system watch queue overflowed; falling back to fstat", .{});
                markAllFilesDirty(w, gpa);
                try dir.startListening();
                return true;
            }
            var file_name_buf: [std.fs.max_path_bytes]u8 = undefined;
            var notify: *align(1) windows.FILE_NOTIFY_INFORMATION = undefined;
            var offset: usize = 0;
            while (true) {
                notify = @ptrCast(&dir.buffer[offset]);
                const file_name_field: [*]u16 = @ptrFromInt(@intFromPtr(notify) + @sizeOf(windows.FILE_NOTIFY_INFORMATION));
                const file_name_len = std.unicode.wtf16LeToWtf8(&file_name_buf, file_name_field[0 .. notify.FileNameLength / 2]);
                const file_name = file_name_buf[0..file_name_len];
                if (w.os.handle_table.getIndex(dir.id)) |reaction_set_i| {
                    const reaction_set = w.os.handle_table.values()[reaction_set_i];
                    if (reaction_set.getPtr(".")) |glob_set|
                        any_dirty = markStepSetDirty(gpa, glob_set, any_dirty);
                    if (reaction_set.getPtr(file_name)) |step_set| {
                        any_dirty = markStepSetDirty(gpa, step_set, any_dirty);
                    }
                }
                if (notify.NextEntryOffset == 0)
                    break;

                offset += notify.NextEntryOffset;
            }

            // We call this now since at this point we have finished reading dir.buffer.
            try dir.startListening();
            return any_dirty;
        }

        fn update(w: *Watch, gpa: Allocator, steps: []const *Step) !void {
            // Add missing marks and note persisted ones.
            for (steps) |step| {
                for (step.inputs.table.keys(), step.inputs.table.values()) |path, *files| {
                    const reaction_set = rs: {
                        const gop = try w.dir_table.getOrPut(gpa, path);
                        if (!gop.found_existing) {
                            const dir = try Os.Directory.init(gpa, path);
                            errdefer dir.deinit(gpa);
                            // `dir.id` may already be present in the table in
                            // the case that we have multiple Cache.Path instances
                            // that compare inequal but ultimately point to the same
                            // directory on the file system.
                            // In such case, we must revert adding this directory, but keep
                            // the additions to the step set.
                            const dh_gop = try w.os.handle_table.getOrPut(gpa, dir.id);
                            if (dh_gop.found_existing) {
                                dir.deinit(gpa);
                                _ = w.dir_table.pop();
                            } else {
                                assert(dh_gop.index == gop.index);
                                dh_gop.value_ptr.* = .{};
                                try dir.startListening();
                                const key = w.os.counter;
                                w.os.counter +%= 1;
                                try w.os.dir_list.put(gpa, key, dir);
                                w.os.io_cp = try windows.CreateIoCompletionPort(
                                    dir.handle,
                                    w.os.io_cp,
                                    key,
                                    0,
                                );
                            }
                            break :rs &w.os.handle_table.values()[dh_gop.index];
                        }
                        break :rs &w.os.handle_table.values()[gop.index];
                    };
                    for (files.items) |basename| {
                        const gop = try reaction_set.getOrPut(gpa, basename);
                        if (!gop.found_existing) gop.value_ptr.* = .{};
                        try gop.value_ptr.put(gpa, step, w.generation);
                    }
                }
            }

            {
                // Remove marks for files that are no longer inputs.
                var i: usize = 0;
                while (i < w.os.handle_table.entries.len) {
                    {
                        const reaction_set = &w.os.handle_table.values()[i];
                        var step_set_i: usize = 0;
                        while (step_set_i < reaction_set.entries.len) {
                            const step_set = &reaction_set.values()[step_set_i];
                            var dirent_i: usize = 0;
                            while (dirent_i < step_set.entries.len) {
                                const generations = step_set.values();
                                if (generations[dirent_i] == w.generation) {
                                    dirent_i += 1;
                                    continue;
                                }
                                step_set.swapRemoveAt(dirent_i);
                            }
                            if (step_set.entries.len > 0) {
                                step_set_i += 1;
                                continue;
                            }
                            reaction_set.swapRemoveAt(step_set_i);
                        }
                        if (reaction_set.entries.len > 0) {
                            i += 1;
                            continue;
                        }
                    }

                    w.os.dir_list.values()[i].deinit(gpa);
                    w.os.dir_list.swapRemoveAt(i);
                    w.dir_table.swapRemoveAt(i);
                    w.os.handle_table.swapRemoveAt(i);
                }
                w.generation +%= 1;
            }
        }
    },
    else => void,
};

pub fn init() !Watch {
    switch (builtin.os.tag) {
        .linux => {
            const fan_fd = std.posix.fanotify_init(.{
                .CLASS = .NOTIF,
                .CLOEXEC = true,
                .NONBLOCK = true,
                .REPORT_NAME = true,
                .REPORT_DIR_FID = true,
                .REPORT_FID = true,
                .REPORT_TARGET_FID = true,
            }, 0) catch |err| switch (err) {
                error.UnsupportedFlags => fatal("fanotify_init failed due to old kernel; requires 5.17+", .{}),
                else => |e| return e,
            };
            return .{
                .dir_table = .{},
                .os = switch (builtin.os.tag) {
                    .linux => .{
                        .handle_table = .{},
                        .poll_fds = .{
                            .{
                                .fd = fan_fd,
                                .events = std.posix.POLL.IN,
                                .revents = undefined,
                            },
                        },
                    },
                    else => {},
                },
                .generation = 0,
            };
        },
        .windows => {
            return .{
                .dir_table = .{},
                .os = switch (builtin.os.tag) {
                    .windows => .{
                        .handle_table = .{},
                        .dir_list = .{},
                        .io_cp = null,
                    },
                    else => {},
                },
                .generation = 0,
            };
        },
        else => @panic("unimplemented"),
    }
}

pub const Match = struct {
    /// Relative to the watched directory, the file path that triggers this
    /// match.
    basename: []const u8,
    /// The step to re-run when file corresponding to `basename` is changed.
    step: *Step,

    pub const Context = struct {
        pub fn hash(self: Context, a: Match) u32 {
            _ = self;
            var hasher = Hash.init(0);
            std.hash.autoHash(&hasher, a.step);
            hasher.update(a.basename);
            return @truncate(hasher.final());
        }
        pub fn eql(self: Context, a: Match, b: Match, b_index: usize) bool {
            _ = self;
            _ = b_index;
            return a.step == b.step and std.mem.eql(u8, a.basename, b.basename);
        }
    };
};

fn markAllFilesDirty(w: *Watch, gpa: Allocator) void {
    for (w.os.handle_table.values()) |reaction_set| {
        for (reaction_set.values()) |step_set| {
            for (step_set.keys()) |step| {
                step.recursiveReset(gpa);
            }
        }
    }
}

fn markStepSetDirty(gpa: Allocator, step_set: *StepSet, any_dirty: bool) bool {
    var this_any_dirty = false;
    for (step_set.keys()) |step| {
        if (step.state != .precheck_done) {
            step.recursiveReset(gpa);
            this_any_dirty = true;
        }
    }
    return any_dirty or this_any_dirty;
}

pub fn update(w: *Watch, gpa: Allocator, steps: []const *Step) !void {
    switch (builtin.os.tag) {
        .linux, .windows => return Os.update(w, gpa, steps),
        else => @compileError("unimplemented"),
    }
}

pub const Timeout = union(enum) {
    none,
    ms: u16,

    pub fn to_i32_ms(t: Timeout) i32 {
        return switch (t) {
            .none => -1,
            .ms => |ms| ms,
        };
    }
};

pub const WaitResult = enum {
    timeout,
    /// File system watching triggered on files that were marked as inputs to at least one Step.
    /// Relevant steps have been marked dirty.
    dirty,
    /// File system watching triggered but none of the events were relevant to
    /// what we are listening to. There is nothing to do.
    clean,
};

pub fn wait(w: *Watch, gpa: Allocator, timeout: Timeout) !WaitResult {
    switch (builtin.os.tag) {
        .linux => {
            const events_len = try std.posix.poll(&w.os.poll_fds, timeout.to_i32_ms());
            return if (events_len == 0)
                .timeout
            else if (try Os.markDirtySteps(w, gpa))
                .dirty
            else
                .clean;
        },
        .windows => {
            var bytes_transferred: std.os.windows.DWORD = undefined;
            var key: usize = undefined;
            var overlapped_ptr: ?*std.os.windows.OVERLAPPED = undefined;
            return while (true) switch (std.os.windows.GetQueuedCompletionStatus(
                w.os.io_cp.?,
                &bytes_transferred,
                &key,
                &overlapped_ptr,
                @bitCast(timeout.to_i32_ms()),
            )) {
                .Normal => {
                    if (bytes_transferred == 0)
                        break error.Unexpected;

                    // This 'orelse' detects a race condition that happens when we receive a
                    // completion notification for a directory that no longer exists in our list.
                    const dir = w.os.dir_list.get(key) orelse break .clean;

                    break if (try Os.markDirtySteps(w, gpa, dir))
                        .dirty
                    else
                        .clean;
                },
                .Timeout => break .timeout,
                // This status is issued because CancelIo was called, skip and try again.
                .Cancelled => continue,
                else => break error.Unexpected,
            };
        },
        else => @compileError("unimplemented"),
    }
}
