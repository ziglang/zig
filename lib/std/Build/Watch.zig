const std = @import("../std.zig");
const Watch = @This();
const Step = std.Build.Step;
const Allocator = std.mem.Allocator;

dir_table: DirTable,
/// Keyed differently but indexes correspond 1:1 with `dir_table`.
handle_table: HandleTable,
fan_fd: std.posix.fd_t,
generation: Generation,

pub const fan_mask: std.os.linux.fanotify.MarkMask = .{
    .CLOSE_WRITE = true,
    .DELETE = true,
    .MOVED_FROM = true,
    .MOVED_TO = true,
    .EVENT_ON_CHILD = true,
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

pub fn getFileHandle(gpa: Allocator, path: std.Build.Cache.Path, basename: []const u8) !LinuxFileHandle {
    var file_handle_buffer: [@sizeOf(std.os.linux.file_handle) + 128]u8 align(@alignOf(std.os.linux.file_handle)) = undefined;
    var mount_id: i32 = undefined;
    var buf: [std.fs.max_path_bytes]u8 = undefined;
    const joined_path = if (path.sub_path.len == 0) basename else path: {
        break :path std.fmt.bufPrint(&buf, "{s}/{s}", .{
            path.sub_path, basename,
        }) catch return error.NameTooLong;
    };
    const stack_ptr: *std.os.linux.file_handle = @ptrCast(&file_handle_buffer);
    stack_ptr.handle_bytes = file_handle_buffer.len - @sizeOf(std.os.linux.file_handle);
    try std.posix.name_to_handle_at(path.root_dir.handle.fd, joined_path, stack_ptr, &mount_id, 0);
    const stack_lfh: LinuxFileHandle = .{ .handle = stack_ptr };
    return stack_lfh.clone(gpa);
}

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
