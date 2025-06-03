//! Optimized for performance in debug builds.

// TODO I'm pretty sure this can be deleted thanks to the new std.io.Reader semantics

const std = @import("../std.zig");
const MemoryAccessor = std.debug.MemoryAccessor;

const FixedBufferReader = @This();

buf: []const u8,
pos: usize = 0,
endian: std.builtin.Endian,

pub const Error = error{ EndOfStream, Overflow, InvalidBuffer };

pub fn seekTo(fbr: *FixedBufferReader, pos: u64) Error!void {
    if (pos > fbr.buf.len) return error.EndOfStream;
    fbr.pos = @intCast(pos);
}

pub fn seekForward(fbr: *FixedBufferReader, amount: u64) Error!void {
    if (fbr.buf.len - fbr.pos < amount) return error.EndOfStream;
    fbr.pos += @intCast(amount);
}

pub inline fn readByte(fbr: *FixedBufferReader) Error!u8 {
    if (fbr.pos >= fbr.buf.len) return error.EndOfStream;
    defer fbr.pos += 1;
    return fbr.buf[fbr.pos];
}

pub fn readByteSigned(fbr: *FixedBufferReader) Error!i8 {
    return @bitCast(try fbr.readByte());
}

pub fn readInt(fbr: *FixedBufferReader, comptime T: type) Error!T {
    const size = @divExact(@typeInfo(T).int.bits, 8);
    if (fbr.buf.len - fbr.pos < size) return error.EndOfStream;
    defer fbr.pos += size;
    return std.mem.readInt(T, fbr.buf[fbr.pos..][0..size], fbr.endian);
}

pub fn readIntChecked(
    fbr: *FixedBufferReader,
    comptime T: type,
    ma: *MemoryAccessor,
) Error!T {
    if (ma.load(T, @intFromPtr(fbr.buf[fbr.pos..].ptr)) == null)
        return error.InvalidBuffer;

    return fbr.readInt(T);
}

pub fn readLeb128(fbr: *FixedBufferReader, comptime T: type) Error!T {
    var br: std.io.Reader = .fixed(fbr.buf);
    br.seek = fbr.pos;
    const result = br.takeLeb128(T);
    fbr.pos = br.seek;
    return result catch |err| switch (err) {
        error.ReadFailed => return error.EndOfStream,
        else => |e| return e,
    };
}

pub fn readUleb128(fbr: *FixedBufferReader, comptime T: type) Error!T {
    return fbr.readLeb128(T);
}

pub fn readIleb128(fbr: *FixedBufferReader, comptime T: type) Error!T {
    return fbr.readLeb128(T);
}

pub fn readAddress(fbr: *FixedBufferReader, format: std.dwarf.Format) Error!u64 {
    return switch (format) {
        .@"32" => try fbr.readInt(u32),
        .@"64" => try fbr.readInt(u64),
    };
}

pub fn readAddressChecked(
    fbr: *FixedBufferReader,
    format: std.dwarf.Format,
    ma: *MemoryAccessor,
) Error!u64 {
    return switch (format) {
        .@"32" => try fbr.readIntChecked(u32, ma),
        .@"64" => try fbr.readIntChecked(u64, ma),
    };
}

pub fn readBytes(fbr: *FixedBufferReader, len: usize) Error![]const u8 {
    if (fbr.buf.len - fbr.pos < len) return error.EndOfStream;
    defer fbr.pos += len;
    return fbr.buf[fbr.pos..][0..len];
}

pub fn readBytesTo(fbr: *FixedBufferReader, comptime sentinel: u8) Error![:sentinel]const u8 {
    const end = @call(.always_inline, std.mem.indexOfScalarPos, .{
        u8,
        fbr.buf,
        fbr.pos,
        sentinel,
    }) orelse return error.EndOfStream;
    defer fbr.pos = end + 1;
    return fbr.buf[fbr.pos..end :sentinel];
}
