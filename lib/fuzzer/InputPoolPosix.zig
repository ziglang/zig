// The inputs are densly packed inside a file that all fuzzing processes have
// mapped into memory. To know where inputs start and end, there is a second
// file mapped by all fuzzing processes that stores the end index of every
// stored string and some metadata (see the meta field).
//
// When a process finds a new good input, it (under a lock) appends to both of
// these files. All other processes can immediately start working on this input
//
// We never shrink the corpus when fuzzing. One has to stop fuzzing and run a
// separate program. That is because erasing strings would require complicated
// synchronization between fuzzing processes. Finding good inputs seems to be
// rare enough for the input pool to never get too large.

const std = @import("std");
const assert = std.debug.assert;
const fatal = std.process.fatal;
const MemoryMappedList = @import("memory_mapped_list.zig").MemoryMappedList;
const File = std.fs.File;

/// maximum 2GiB of input data should be enough. 32th bit is delete flag
pub const Index = u31;

const InputPoolPosix = @This();

const LatestFormatVersion: u8 = 0;
const SignatureVersion: u32 = @bitCast([4]u8{ 117, 168, 125, LatestFormatVersion });

/// mmap-ed file. In reality we mapped 2 GiB but cropped to match the mmaped
/// file size. Doesn't need mremap when growing.
buffer: MemoryMappedList(u8),

/// mmap-ed file. In reality we mapped 2 GiB but cropped to match the mmaped
/// file size. Doesn't need mremap when growing.
///
/// layout of the meta file (v0):
/// [0] [3]u8 file signature + u8 format version
/// [1] u64 for a lock
/// [2] u32 deleted bytes
/// [3] u32 number of strings
/// [4..] data (string end offsets)
meta: MemoryMappedList(u32),

const MetaHeader = packed struct {
    signature_version: u32,
    lock: std.Thread.Mutex,
    deleted_bytes: u32,
    number_of_string: u32,
};

fn getHeader(m: MemoryMappedList(u32)) *align(std.mem.page_size) volatile MetaHeader {
    const size32 = @divExact(@sizeOf(MetaHeader), @sizeOf(u32));
    const bytes: *align(std.mem.page_size) volatile [size32]u32 = m.items[0..size32];
    return @ptrCast(bytes);
}

const Flags = packed struct(u32) {
    index: Index,
    delete: bool,
};

fn getData(m: MemoryMappedList(u32)) []volatile Flags {
    const size32 = @divExact(@sizeOf(MetaHeader), @sizeOf(u32));
    const rest: []volatile u32 = m.items[size32..];
    return @ptrCast(rest);
}

pub fn init(meta_file: File, buffer_file: File) InputPoolPosix {
    const buffer = MemoryMappedList(u8).init(buffer_file, std.math.maxInt(Index));
    var meta = MemoryMappedList(u32).init(meta_file, std.math.maxInt(Index));

    if (meta.items.len == 0) {
        const header: MetaHeader = .{
            .signature_version = SignatureVersion,
            .lock = std.Thread.Mutex{},
            .deleted_bytes = 0,
            .number_of_string = 0,
        };

        // []u8 to []u32 conversion
        const s = std.mem.asBytes(&header);
        const z: [*]const u32 = @ptrCast(s.ptr);
        const size32 = @divExact(@sizeOf(MetaHeader), @sizeOf(u32));

        meta.appendSlice(z[0..size32]);
    } else {
        const header = getHeader(meta);
        assert(header.signature_version == SignatureVersion);
    }

    return .{
        .buffer = buffer,
        .meta = meta,
    };
}

pub fn deinit(ip: *InputPoolPosix) void {
    ip.buffer.deinit();
    ip.meta.deinit();
}

pub fn insertString(ip: *InputPoolPosix, str: []const u8) void {
    const header = getHeader(ip.meta);
    header.lock.lock();
    defer header.lock.unlock();

    assert(ip.buffer.items.len + str.len < std.math.maxInt(Index));

    ip.buffer.appendSlice(str);
    ip.meta.append(@intCast(ip.buffer.items.len));
    header.number_of_string += 1;
}

const deleteMask: u32 = 0x8000_0000;

comptime {
    assert(~deleteMask == std.math.maxInt(Index));
}

/// Only marks the string for deletion. No memory is reused until corpus is
/// reduced by external program (not compatible with the fuzzing program
/// running at the same time)
pub fn deleteString(ip: *InputPoolPosix, index: Index) void {
    // the only write operation to this part of the shared memory is turning on
    // this bit
    const p = &ip.ends.items[index];
    @atomicStore(u32, p, p.* | deleteMask, .monotonic);
    const d: *volatile u32 = &getHeader(ip.meta).deleted_bytes;
    @atomicRmw(u32, d, .Add, ip.getString(index).len, .monotonic);
}

pub fn len(ip: *InputPoolPosix) u31 {
    return @intCast(getHeader(ip.meta).number_of_string);
}

pub fn getString(ip: InputPoolPosix, index: Index) []volatile u8 {
    const ends = getData(ip.meta);
    const start = if (index == 0) 0 else (ends[index - 1].index);
    const one_past_end = ends[index].index;
    return ip.buffer.items[start..one_past_end];
}

/// Shifts strings down to fill unused space. Only called when no processes are
/// fuzzing
pub fn repack(ip: InputPoolPosix) void {
    var poolWriteHead: usize = 0;
    var endsWriteHead: usize = 0;

    const ends = getData(ip.meta);

    for (0..ends.items.len) |i| {
        const start = if (i == 0) 0 else ends.items[i - 1].index;
        const one_past_end = ends.items[i].index;
        const str = ip.buffer.items[start..one_past_end];
        const dest = ip.buffer.items[poolWriteHead..][0..str.len];

        if (ends.items[i].delete) {
            continue;
        }

        if (str.ptr != dest.ptr) {
            std.mem.copyForwards(u8, dest, str);
            ip.ends.items[endsWriteHead].index = poolWriteHead + str.len;
        }
        poolWriteHead += str.len;
        endsWriteHead += 1;
    }

    ip.ends.items.len = endsWriteHead;
    ip.buffer.items.len = poolWriteHead;
}
