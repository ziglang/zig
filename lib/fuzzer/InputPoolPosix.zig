//! The inputs are densly packed inside a file that all fuzzing processes have
//! mapped into memory. To know where inputs start and end, there is a second
//! file mapped by all fuzzing processes that stores the end index of every
//! stored string and some metadata (see the meta field).
//!
//! When a process finds a new good input, it (under a lock) appends to both of
//! these files. All other processes can immediately start working on this
//! input
//!
//! We never shrink the corpus when fuzzing. One has to stop fuzzing and run a
//! separate program. That is because erasing strings would require complicated
//! synchronization between fuzzing processes. Finding good inputs seems to be
//! rare enough for the input pool to never get too large.

const std = @import("std");
const assert = std.debug.assert;
const fatal = std.process.fatal;
const MemoryMappedList = @import("memory_mapped_list.zig").MemoryMappedList;
const File = std.fs.File;

/// arbitrary limit 2GiB of input data should be enough. 32th bit is delete
/// flag. Note that we only store 'good' inputs, which are rare.
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
/// * MetaHeader
/// * string end offsets (trailing data)
meta: MemoryMappedList(u32),

const MetaHeader = extern struct {
    signature_version: u32,
    lock: u64, // space for a lock. Locks can't be placed in extern structs
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

    // maxInt is not a special value! We allocate 2GiB of virtual address
    // space. See comment in memory_mapped_list_posix.zig
    const buffer = MemoryMappedList(u8).init(buffer_file, std.math.maxInt(Index));
    var meta = MemoryMappedList(u32).init(meta_file, std.math.maxInt(Index));

    std.log.info("{} {}", .{ buffer.items.len, meta.items.len });

    if (meta.fileLen() == 0) {
        var header: MetaHeader = .{
            .signature_version = SignatureVersion,
            .lock = undefined,
            .deleted_bytes = 0,
            .number_of_string = 0,
        };

        const lock_ptr: *std.Thread.Mutex = @ptrCast(&header.lock);
        lock_ptr.* = std.Thread.Mutex{}; // TODO: make this a inter-process lock

        // []u8 to []u32 conversion
        const s = std.mem.asBytes(&header);
        const z: [*]const u32 = @ptrCast(s.ptr);
        const size32 = @divExact(@sizeOf(MetaHeader), @sizeOf(u32));

        meta.appendSlice(z[0..size32]);
    } else {
        const header: *volatile MetaHeader = getHeader(meta);
        const sign: *volatile u32 = &header.signature_version;
        std.log.info("sign{x} header@{x}", .{ @intFromPtr(sign), @intFromPtr(header) });
        if (sign.* != SignatureVersion) {
            fatal(
                "input pool file signature is invalid (wanted {x}, got {x})",
                .{ SignatureVersion, header.signature_version },
            );
        }
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

    // mutex methods don't accept volatile pointers. There is not much I can do
    const lock_ptr: *std.Thread.Mutex = @volatileCast(@ptrCast(&header.lock));
    lock_ptr.lock();
    defer lock_ptr.unlock();

    const fileLen = ip.buffer.fileLen();

    ip.buffer.appendSlice(str);
    ip.meta.append(@intCast(fileLen));
    header.number_of_string += 1;
}

pub fn len(ip: *InputPoolPosix) u31 {
    // number_of_string can't be u31 because the struct is extern and 31 is not
    // a power of two
    return @intCast(getHeader(ip.meta).number_of_string);
}

pub fn getString(ip: InputPoolPosix, index: Index) []volatile u8 {
    const ends = getData(ip.meta);
    const start = if (index == 0) 0 else (ends[index - 1].index);
    const one_past_end = ends[index].index;
    return ip.buffer.items[start..one_past_end];
}

/// Note that this is currently never used as the corpus minimalization is not
/// yet implemented
///
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

    ip.ends.setFileLen(endsWriteHead + @sizeOf(MetaHeader));
    ip.buffer.setFileLen(poolWriteHead);
}
