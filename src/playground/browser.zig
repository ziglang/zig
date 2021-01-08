const std = @import("std");
const Allocator = std.mem.Allocator;

const Compilation = @import("../Compilation.zig");

pub const active = std.Target.current.isWasm() and
    std.Target.current.os.tag == .freestanding;

pub const Directory = struct {
    path: ?[]const u8,
    handle: Dir,

    pub fn join(self: Directory, allocator: *Allocator, paths: []const []const u8) ![]u8 {
        return Compilation.joinPaths(self.path, allocator, paths);
    }
};

pub const Cache = struct {
    pub const Lock = struct {
        pub fn release(lock: *Lock) void {}
    };
    pub const Manifest = struct {};
};

pub const File = struct {
    pos: u64 = 0,

    pub const OpenError = error{};

    pub const CreateFlags = struct {
        read: bool = false,
        truncate: bool = true,
    };

    pub const WriteError = error{};

    pub fn write(self: File, bytes: []const u8) WriteError!usize {
        return bytes.len;
    }

    pub fn writeAll(self: File, bytes: []const u8) WriteError!void {}

    pub const PWriteError = error{};

    pub fn pwriteAll(self: File, bytes: []const u8, offset: u64) PWriteError!void {}

    pub const SetEndPosError = error{};

    pub fn setEndPos(self: File, length: u64) SetEndPosError!void {}

    pub const SeekError = error{};

    pub fn seekTo(self: File, offset: u64) SeekError!void {}

    pub fn seekBy(self: File, offset: i64) SeekError!void {}

    pub const GetPosError = error{};

    pub fn getPos(self: File) GetPosError!u64 {
        return self.pos;
    }

    pub fn close(self: File) void {}

    pub const Writer = std.io.Writer(File, WriteError, write);

    pub fn writer(file: File) Writer {
        return .{ .context = file };
    }
};

pub const Dir = struct {
    pub fn createFile(dir: Dir, sub_path: []const u8, flags: File.CreateFlags) File.OpenError!File {
        return File{};
    }

    pub fn readFileAllocOptions(
        self: Dir,
        allocator: *std.mem.Allocator,
        file_path: []const u8,
        max_bytes: usize,
        size_hint: ?usize,
        comptime alignment: u29,
        comptime optional_sentinel: ?u8,
    ) !(if (optional_sentinel) |s| [:s]align(alignment) u8 else []align(alignment) u8) {
        if (std.mem.eql(u8, file_path, "main.zig")) {
            return allocator.dupeZ(u8,
                \\export fn _start() f64 {
                \\    return 42.0;
                \\}
            );
        } else {
            return error.FileNotFound;
        }
    }

    pub fn writeFile(self: Dir, sub_path: []const u8, data: []const u8) !void {}

    pub fn close(dir: *Dir) void {}
};
