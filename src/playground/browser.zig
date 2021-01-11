const std = @import("std");
const Allocator = std.mem.Allocator;

const Compilation = @import("../Compilation.zig");
const playground = @import("../playground.zig");
const arena = &playground.arena_allocator.allocator;

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
    handle: usize,

    pub const OpenError = error{};

    pub const CreateFlags = struct {
        read: bool = false,
        truncate: bool = true,
    };

    pub const WriteError = error{NoSpaceLeft};

    pub fn write(self: File, bytes: []const u8) WriteError!usize {
        return actual_files[self.handle].write(bytes);
    }

    pub fn writeAll(self: File, bytes: []const u8) WriteError!void {
        var index: usize = 0;
        while (index < bytes.len) {
            index += try self.write(bytes[index..]);
        }
    }

    pub const PWriteError = error{NoSpaceLeft};

    pub fn pwrite(self: File, bytes: []const u8, offset: u64) PWriteError!usize {
        return actual_files[self.handle].pwrite(bytes, offset);
    }

    pub fn pwriteAll(self: File, bytes: []const u8, offset: u64) PWriteError!void {
        var index: usize = 0;
        while (index < bytes.len) {
            index += try self.pwrite(bytes[index..], offset + index);
        }
    }

    pub const SetEndPosError = error{NoSpaceLeft};

    pub fn setEndPos(self: File, length: u64) SetEndPosError!void {
        return actual_files[self.handle].setEndPos(length);
    }

    pub const SeekError = error{};

    pub fn seekTo(self: File, offset: u64) SeekError!void {
        return actual_files[self.handle].seekTo(offset);
    }

    pub fn seekBy(self: File, offset: i64) SeekError!void {
        return actual_files[self.handle].seekBy(offset);
    }

    pub const GetPosError = error{};

    pub fn getPos(self: File) GetPosError!u64 {
        return actual_files[self.handle].pos;
    }

    pub fn close(self: File) void {
        return actual_files[self.handle].close();
    }

    pub const Writer = std.io.Writer(File, WriteError, write);

    pub fn writer(file: File) Writer {
        return .{ .context = file };
    }
};

pub const Dir = struct {
    pub fn createFile(dir: Dir, sub_path: []const u8, flags: File.CreateFlags) File.OpenError!File {
        if (std.mem.eql(u8, sub_path, "main.wasm")) {
            actual_files[main_wasm_index] = .{
                .pos = 0,
                .data = .{},
            };
            return File{ .handle = main_wasm_index };
        } else {
            std.log.emerg("unknown file to create: {s}", .{sub_path});
            @panic("createFile failed");
        }
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
        } else if (std.mem.eql(u8, file_path, "main.wasm")) {
            const af = &actual_files[main_wasm_index];
            if (optional_sentinel) |s| {
                try af.data.append(arena, s);
                return af.data.items[0 .. af.data.items.len - 1 :s];
            } else {
                return af.data.items;
            }
        } else {
            std.log.err("file not found: {s}", .{file_path});
            return error.FileNotFound;
        }
    }

    pub fn writeFile(self: Dir, sub_path: []const u8, data: []const u8) !void {
        std.log.err("unknown file to write: {s}", .{sub_path});
        return error.FileNotFound;
    }

    pub fn close(dir: *Dir) void {}
};

const ActualFile = struct {
    pos: usize,
    data: std.ArrayListUnmanaged(u8),

    fn write(af: *ActualFile, bytes: []const u8) File.WriteError!usize {
        const new_min_len = af.pos + bytes.len;
        if (af.data.items.len < new_min_len) {
            af.data.resize(arena, new_min_len) catch return error.NoSpaceLeft;
        }
        std.mem.copy(u8, af.data.items[af.pos..], bytes);
        af.pos += bytes.len;
        return bytes.len;
    }

    fn pwrite(af: *ActualFile, bytes: []const u8, offset: u64) File.PWriteError!usize {
        const off = std.math.cast(usize, offset) catch return error.NoSpaceLeft;
        const new_min_len = off + bytes.len;
        if (af.data.items.len < new_min_len) {
            af.data.resize(arena, new_min_len) catch return error.NoSpaceLeft;
        }
        std.mem.copy(u8, af.data.items[off..], bytes);
        return bytes.len;
    }

    fn setEndPos(af: *ActualFile, length: u64) File.SetEndPosError!void {
        const len = std.math.cast(usize, length) catch return error.NoSpaceLeft;
        af.data.resize(arena, len) catch return error.NoSpaceLeft;
    }

    fn seekTo(af: *ActualFile, offset: u64) File.SeekError!void {
        af.pos = std.math.cast(usize, offset) catch @panic("out of memory");
    }

    fn seekBy(af: *ActualFile, offset: i64) File.SeekError!void {
        const new_pos = @as(i64, af.pos) + offset;
        af.pos = std.math.cast(usize, new_pos) catch @panic("out of memory");
    }

    fn close(af: *ActualFile) void {}
};
var actual_files: [1]ActualFile = undefined;
const main_wasm_index = 0;
