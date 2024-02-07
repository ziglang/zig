const std = @import("../../../../std.zig");
const bits = @import("../../bits.zig");

const cc = bits.cc;
const Status = @import("../../status.zig").Status;

const Guid = bits.Guid;

pub const DiskIo = extern struct {
    revision: u64,

    _read: *const fn (*const DiskIo, media_id: u32, offset: u64, buffer_size: usize, buf: [*]u8) callconv(cc) Status,
    _write: *const fn (*const DiskIo, media_id: u32, offset: u64, buffer_size: usize, buf: [*]const u8) callconv(cc) Status,

    /// Reads a specified number of bytes from a device.
    pub fn read(
        self: *DiskIo,
        /// The media ID that the read request is for.
        media_id: u32,
        /// The starting byte offset on the logical block I/O device to read from.
        offset: u64,
        /// The buffer into which the data is read.
        buffer: []u8,
    ) !void {
        try self._read(self, media_id, offset, buffer.len, buffer.ptr).err();
    }

    /// Writes a specified number of bytes to the device.
    pub fn write(
        self: *DiskIo,
        /// The media ID that the write request is for.
        media_id: u32,
        /// The starting byte offset on the logical block I/O device to write to.
        offset: u64,
        /// The buffer from which the data is written.
        buffer: []const u8,
    ) !void {
        try self._write(self, media_id, offset, buffer.len, buffer.ptr).err();
    }

    pub const guid align(8) = Guid{
        .time_low = 0xce345171,
        .time_mid = 0xba0b,
        .time_high_and_version = 0x11d2,
        .clock_seq_high_and_reserved = 0x8e,
        .clock_seq_low = 0x4f,
        .node = [_]u8{ 0x00, 0xa0, 0xc9, 0x69, 0x72, 0x3b },
    };
};
