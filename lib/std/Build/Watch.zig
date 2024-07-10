const std = @import("../std.zig");
const Watch = @This();
const Step = std.Build.Step;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

dir_table: DirTable,
/// Keyed differently but indexes correspond 1:1 with `dir_table`.
handle_table: HandleTable,
fan_fd: std.posix.fd_t,
generation: Generation,

pub const fan_mask: std.os.linux.fanotify.MarkMask = .{
    .CLOSE_WRITE = true,
    .CREATE = true,
    .DELETE = true,
    .DELETE_SELF = true,
    .EVENT_ON_CHILD = true,
    .MOVED_FROM = true,
    .MOVED_TO = true,
    .MOVE_SELF = true,
};

pub const init: Watch = .{
    .dir_table = .{},
    .handle_table = .{},
    .fan_fd = -1,
    .generation = 0,
};

/// Key is the directory to watch which contains one or more files we are
/// interested in noticing changes to.
///
/// Value is generation.
const DirTable = std.ArrayHashMapUnmanaged(Cache.Path, void, Cache.Path.TableAdapter, false);

const HandleTable = std.ArrayHashMapUnmanaged(LinuxFileHandle, ReactionSet, LinuxFileHandle.Adapter, false);
/// Special key of "." means any changes in this directory trigger the steps.
const ReactionSet = std.StringArrayHashMapUnmanaged(StepSet);
const StepSet = std.AutoArrayHashMapUnmanaged(*Step, Generation);

const Generation = u8;

const Hash = std.hash.Wyhash;
const Cache = std.Build.Cache;

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

pub const LinuxFileHandle = struct {
    handle: *align(1) std.os.linux.file_handle,

    pub fn clone(lfh: LinuxFileHandle, gpa: Allocator) Allocator.Error!LinuxFileHandle {
        const bytes = lfh.slice();
        const new_ptr = try gpa.alignedAlloc(
            u8,
            @alignOf(std.os.linux.file_handle),
            @sizeOf(std.os.linux.file_handle) + bytes.len,
        );
        const new_header: *std.os.linux.file_handle = @ptrCast(new_ptr);
        new_header.* = lfh.handle.*;
        const new: LinuxFileHandle = .{ .handle = new_header };
        @memcpy(new.slice(), lfh.slice());
        return new;
    }

    pub fn destroy(lfh: LinuxFileHandle, gpa: Allocator) void {
        const ptr: [*]u8 = @ptrCast(lfh.handle);
        const allocated_slice = ptr[0 .. @sizeOf(std.os.linux.file_handle) + lfh.handle.handle_bytes];
        return gpa.free(allocated_slice);
    }

    pub fn slice(lfh: LinuxFileHandle) []u8 {
        const ptr: [*]u8 = &lfh.handle.f_handle;
        return ptr[0..lfh.handle.handle_bytes];
    }

    pub const Adapter = struct {
        pub fn hash(self: Adapter, a: LinuxFileHandle) u32 {
            _ = self;
            const unsigned_type: u32 = @bitCast(a.handle.handle_type);
            return @truncate(Hash.hash(unsigned_type, a.slice()));
        }
        pub fn eql(self: Adapter, a: LinuxFileHandle, b: LinuxFileHandle, b_index: usize) bool {
            _ = self;
            _ = b_index;
            return a.handle.handle_type == b.handle.handle_type and std.mem.eql(u8, a.slice(), b.slice());
        }
    };
};

pub fn getDirHandle(gpa: Allocator, path: std.Build.Cache.Path) !LinuxFileHandle {
    var file_handle_buffer: [@sizeOf(std.os.linux.file_handle) + 128]u8 align(@alignOf(std.os.linux.file_handle)) = undefined;
    var mount_id: i32 = undefined;
    var buf: [std.fs.max_path_bytes]u8 = undefined;
    const adjusted_path = if (path.sub_path.len == 0) "./" else std.fmt.bufPrint(&buf, "{s}/", .{
        path.sub_path,
    }) catch return error.NameTooLong;
    const stack_ptr: *std.os.linux.file_handle = @ptrCast(&file_handle_buffer);
    stack_ptr.handle_bytes = file_handle_buffer.len - @sizeOf(std.os.linux.file_handle);
    try std.posix.name_to_handle_at(path.root_dir.handle.fd, adjusted_path, stack_ptr, &mount_id, std.os.linux.AT.HANDLE_FID);
    const stack_lfh: LinuxFileHandle = .{ .handle = stack_ptr };
    return stack_lfh.clone(gpa);
}

pub fn markDirtySteps(w: *Watch, gpa: Allocator) !bool {
    const fanotify = std.os.linux.fanotify;
    const M = fanotify.event_metadata;
    var events_buf: [256 + 4096]u8 = undefined;
    var any_dirty = false;
    while (true) {
        var len = std.posix.read(w.fan_fd, &events_buf) catch |err| switch (err) {
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
                    const lfh: Watch.LinuxFileHandle = .{ .handle = file_handle };
                    if (w.handle_table.getPtr(lfh)) |reaction_set| {
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

pub fn markFailedStepsDirty(gpa: Allocator, all_steps: []const *Step) void {
    for (all_steps) |step| switch (step.state) {
        .dependency_failure, .failure, .skipped => step.recursiveReset(gpa),
        else => continue,
    };
    // Now that all dirty steps have been found, the remaining steps that
    // succeeded from last run shall be marked "cached".
    for (all_steps) |step| switch (step.state) {
        .success => step.result_cached = true,
        else => continue,
    };
}

fn markAllFilesDirty(w: *Watch, gpa: Allocator) void {
    for (w.handle_table.values()) |reaction_set| {
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
