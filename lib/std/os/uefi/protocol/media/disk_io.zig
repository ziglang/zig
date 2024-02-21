const bits = @import("../../bits.zig");

const cc = bits.cc;
const Status = @import("../../status.zig").Status;

const Guid = bits.Guid;

/// This protocol is used to abstract the block accesses of the Block I/O protocol to a more general offset-length
/// protocol. The firmware is responsible for adding this protocol to any Block I/O interface that appears in the
/// system that does not already have a Disk I/O protocol. File systems and other disk access code utilize the
/// Disk I/O protocol
pub const DiskIo = extern struct {
    revision: u64,
    _read_disk: *const fn (*const DiskIo, media_id: u32, offset: u64, buf_size: usize, buf: [*]u8) callconv(cc) Status,
    _write_disk: *const fn (*const DiskIo, media_id: u32, offset: u64, buf_size: usize, buf: [*]const u8) callconv(cc) Status,

    /// Reads a specified number of bytes from a device.
    pub fn read(
        self: *const DiskIo,
        /// The ID of the medium to read from.
        media_id: u32,
        /// The starting byte offset on the logical block I/O device to read from.
        offset: u64,
        /// The buffer to read data into
        buf: []u8,
    ) !void {
        try self._read_disk(self, media_id, offset, buf.len, buf.ptr).err();
    }

    /// Writes a specified number of bytes to a device.
    pub fn write(
        self: *const DiskIo,
        /// The ID of the medium to write to.
        media_id: u32,
        /// The starting byte offset on the logical block I/O device to write to.
        offset: u64,
        /// The buffer to write data from
        buf: []const u8,
    ) !void {
        try self._write_disk(self, media_id, offset, buf.len, buf.ptr).err();
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
