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
const DirTable = std.ArrayHashMapUnmanaged(Cache.Path, MountId, Cache.Path.TableAdapter, false);

/// Special key of "." means any changes in this directory trigger the steps.
const ReactionSet = std.StringArrayHashMapUnmanaged(StepSet);
const StepSet = std.AutoArrayHashMapUnmanaged(*Step, Generation);

const Generation = u8;

const MountId = i32;

const Hash = std.hash.Wyhash;
const Cache = std.Build.Cache;

const Os = switch (builtin.os.tag) {
    .linux => struct {
        const posix = std.posix;

        /// Keyed differently but indexes correspond 1:1 with `dir_table`.
        handle_table: HandleTable,
        // mount_id -> fanotify
        poll_fds: std.AutoArrayHashMapUnmanaged(MountId, posix.pollfd),

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

        fn getDirHandle(gpa: Allocator, path: std.Build.Cache.Path, mount_id: *MountId) !FileHandle {
            var file_handle_buffer: [@sizeOf(std.os.linux.file_handle) + 128]u8 align(@alignOf(std.os.linux.file_handle)) = undefined;
            var buf: [std.fs.max_path_bytes]u8 = undefined;
            const adjusted_path = if (path.sub_path.len == 0) "./" else std.fmt.bufPrint(&buf, "{s}/", .{
                path.sub_path,
            }) catch return error.NameTooLong;
            const stack_ptr: *std.os.linux.file_handle = @ptrCast(&file_handle_buffer);
            stack_ptr.handle_bytes = file_handle_buffer.len - @sizeOf(std.os.linux.file_handle);
            try posix.name_to_handle_at(path.root_dir.handle.fd, adjusted_path, stack_ptr, mount_id, std.os.linux.AT.HANDLE_FID);
            const stack_lfh: FileHandle = .{ .handle = stack_ptr };
            return stack_lfh.clone(gpa);
        }

        fn markDirtySteps(w: *Watch, gpa: Allocator, fan_fd: posix.fd_t) !bool {
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

        fn update(w: *Watch, gpa: Allocator, steps: []const *Step) !void {
            // Add missing marks and note persisted ones.
            for (steps) |step| {
                for (step.inputs.table.keys(), step.inputs.table.values()) |path, *files| {
                    const reaction_set = rs: {
                        const gop = try w.dir_table.getOrPut(gpa, path);
                        if (!gop.found_existing) {
                            var mount_id: MountId = undefined;
                            const dir_handle = try Os.getDirHandle(gpa, path, &mount_id);

                            const fan_fd = blk: {
                                const fd_gop = try w.os.poll_fds.getOrPut(gpa, mount_id);
                                if (!fd_gop.found_existing) {
                                    const fd = try std.posix.fanotify_init(.{
                                        .CLASS = .NOTIF,
                                        .CLOEXEC = true,
                                        .NONBLOCK = true,
                                        .REPORT_NAME = true,
                                        .REPORT_DIR_FID = true,
                                        .REPORT_FID = true,
                                        .REPORT_TARGET_FID = true,
                                    }, 0);
                                    fd_gop.value_ptr.* = .{
                                        .fd = fd,
                                        .events = std.posix.POLL.IN,
                                        .revents = undefined,
                                    };
                                }
                                break :blk fd_gop.value_ptr.*.fd;
                            };
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
                                    std.log.err("unable to watch {}: {s}", .{ path, @errorName(err) });
                                };
                            }
                            gop.value_ptr.* = mount_id;
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
                    const mount_fd = w.dir_table.values()[i];
                    const fan_fd = w.os.poll_fds.getEntry(mount_fd).?.value_ptr.fd;
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
    else => void,
};

pub fn init() !Watch {
    switch (builtin.os.tag) {
        .linux => {
            return .{
                .dir_table = .{},
                .os = switch (builtin.os.tag) {
                    .linux => .{
                        .handle_table = .{},
                        .poll_fds = .{},
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
        .linux => return Os.update(w, gpa, steps),
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
            const events_len = try std.posix.poll(w.os.poll_fds.values(), timeout.to_i32_ms());

            if (events_len == 0)
                return .timeout;

            for (w.os.poll_fds.values()) |poll_fd| {
                var any_dirty: bool = false;
                if (poll_fd.revents & std.posix.POLL.IN == std.posix.POLL.IN and
                    try Os.markDirtySteps(w, gpa, poll_fd.fd))
                    any_dirty = true;
                if (any_dirty) return .dirty;
            }

            return .clean;
        },
        else => @compileError("unimplemented"),
    }
}
