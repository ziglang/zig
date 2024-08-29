// we have 2 memory mapped files.
// one for string data, second for bookkeeping

const std = @import("std");
const assert = std.debug.assert;
const util = @import("util.zig");
const check = util.check;
const MemoryMappedList = @import("memory_mapped_list.zig").MemoryMappedList;

pub const Index = u31; // total 2GiB of input data should be enough

const InputPoolPosix = @This();

const LatestFormatVersion: u8 = 0;
const SignatureVersion: u32 = @bitCast([4]u8{ 'V', 'N', 'S', LatestFormatVersion });

// mmap-ed file. In reallity we mapped 2 GiB here but to gain oob checks we
// set the slice length to the file length
buffer: MemoryMappedList(u8),

// mmap-ed file
// layout of the meta file (v0):
// [0] [3]u8 file signature + u8 format version
// [1] u32 for xcmpchg (mutex in the stdlib is not FUTEX_SHARED)
// [2] u32 deleted bytes
// [3] u32 number of strings
// [4..] data (string end offsets)
meta: MemoryMappedList(u32),

pub fn init(dir: std.fs.Dir, pc_digest: u64) InputPoolPosix {
    const hex_digest = std.fmt.hex(pc_digest);

    const buffer_file_path = "v/" ++ hex_digest ++ "buffer";
    const meta_file_path = "v/" ++ hex_digest ++ "meta";
    const buffer_file = check(@src(), dir.createFile(buffer_file_path, .{
        .read = true,
        .truncate = false,
    }), .{ .file = buffer_file_path });
    const meta_file = check(@src(), dir.createFile(meta_file_path, .{
        .read = true,
        .truncate = false,
    }), .{ .file = meta_file_path });

    const buffer = MemoryMappedList(u8).init(buffer_file, std.math.maxInt(Index));
    var meta = MemoryMappedList(u32).init(meta_file, std.math.maxInt(Index));

    if (meta.items.len == 0) {
        meta.appendSlice(&.{
            SignatureVersion, // signature
            Unlocked, // mutex
            0, // deleted bytes
            0, // number of strings
        });
    }

    return .{
        .buffer = buffer,
        .meta = meta,
    };
}

pub fn deinit(ip: InputPoolPosix) void {
    ip.buffer.deinit();
    ip.meta.deinit();
}

// Primitive spin lock implementation
const Locked: u32 = 1;
const Unlocked: u32 = 0;

fn lock(ip: *InputPoolPosix) void {
    while (true) {
        const res = @cmpxchgWeak(u32, &ip.meta.items[1], Unlocked, Locked, .acquire, .monotonic);
        if (res) |v| {
            assert(v == Locked);
        } else {
            return;
        }
    }
}

fn unlock(ip: *InputPoolPosix) void {
    const res = @atomicRmw(u32, &ip.meta.items[1], .Xchg, Unlocked, .release);
    assert(res == Locked);
}

pub fn insertString(ip: *InputPoolPosix, str: []const u8) void {
    ip.lock();
    defer ip.unlock();

    assert(ip.buffer.items.len + str.len < std.math.maxInt(Index));

    ip.buffer.appendSlice(str);
    ip.meta.append(@intCast(ip.buffer.items.len));
    ip.meta.items[3] += 1;
}

const deleteMask: u32 = 0x8000_0000;

comptime {
    assert(~deleteMask == std.math.maxInt(Index));
}

pub fn deleteString(ip: *InputPoolPosix, index: Index) void {
    // the only write operation to this part of the shared memory is turning on
    // this bit
    const p = &ip.ends.items[index];
    @atomicStore(u32, p, p.* | deleteMask, .monotonic);
    @atomicRmw(u32, &ip.meta.items[2], .Add, ip.getString(index).len, .monotonic);
}

pub fn len(ip: *InputPoolPosix) u31 {
    return @intCast(ip.meta.items[3]);
}

pub fn getString(ip: InputPoolPosix, index: Index) []volatile u8 {
    const ends = ip.meta.items[4..];
    const start = if (index == 0) 0 else (ends[index - 1] & ~deleteMask);
    const one_past_end = ends[index] & ~deleteMask;
    return ip.buffer.items[start..one_past_end];
}

pub fn maybeRepack(ip: *InputPoolPosix) void {
    // TODO
    _ = ip;
}
