const std = @import("std");
const uefi = std.os.uefi;
const Status = uefi.Status;
const cc = uefi.cc;
const Error = Status.Error;

pub const BlockIo = extern struct {
    const Self = @This();

    revision: u64,
    media: *BlockMedia,

    _reset: *const fn (*BlockIo, extended_verification: bool) callconv(cc) Status,
    _read_blocks: *const fn (*BlockIo, media_id: u32, lba: u64, buffer_size: usize, buf: [*]u8) callconv(cc) Status,
    _write_blocks: *const fn (*BlockIo, media_id: u32, lba: u64, buffer_size: usize, buf: [*]u8) callconv(cc) Status,
    _flush_blocks: *const fn (*BlockIo) callconv(cc) Status,

    /// Resets the block device hardware.
    pub fn reset(self: *Self, extended_verification: bool) !void {
        switch (self._reset(self, extended_verification)) {
            .success => {},
            .device_error => return Error.DeviceError,
            else => |err| uefi.unexpectedError(err),
        }
    }

    /// Reads the number of requested blocks from the device.
    pub fn readBlocks(self: *Self, media_id: u32, lba: u64, buf: []u8) !void {
        switch (self._read_blocks(self, media_id, lba, buf.len, buf.ptr)) {
            .success => {},
            .device_error => Error.DeviceError,
            .no_media => Error.NoMedia,
            .bad_buffer_size => Error.BadBufferSize,
            .invalid_parameter => Error.InvalidParameter,
            else => |err| uefi.unexpectedError(err),
        }
    }

    /// Writes a specified number of blocks to the device.
    pub fn writeBlocks(self: *Self, media_id: u32, lba: u64, buf: []const u8) !void {
        switch (self._write_blocks(self, media_id, lba, buf.len, buf.ptr)) {
            .success => {},
            .write_protected => Error.WriteProtected,
            .no_media => Error.NoMedia,
            .media_changed => Error.MediaChanged,
            .device_error => Error.DeviceError,
            .bad_buffer_size => Error.BadBufferSize,
            .invalid_parameter => Error.InvalidParameter,
            else => |err| uefi.unexpectedError(err),
        }
    }

    /// Flushes all modified data to a physical block device.
    pub fn flushBlocks(self: *Self) !void {
        switch (self._flush_blocks(self)) {
            .success => {},
            .device_error => Error.DeviceError,
            .no_media => Error.NoMedia,
            else => |err| uefi.unexpectedError(err),
        }
    }

    pub const guid align(8) = uefi.Guid{
        .time_low = 0x964e5b21,
        .time_mid = 0x6459,
        .time_high_and_version = 0x11d2,
        .clock_seq_high_and_reserved = 0x8e,
        .clock_seq_low = 0x39,
        .node = [_]u8{ 0x00, 0xa0, 0xc9, 0x69, 0x72, 0x3b },
    };

    pub const BlockMedia = extern struct {
        /// The current media ID. If the media changes, this value is changed.
        media_id: u32,

        /// `true` if the media is removable; otherwise, `false`.
        removable_media: bool,
        /// `true` if there is a media currently present in the device
        media_present: bool,
        /// `true` if the `BlockIo` was produced to abstract
        /// partition structures on the disk. `false` if the `BlockIo` was
        /// produced to abstract the logical blocks on a hardware device.
        logical_partition: bool,
        /// `true` if the media is marked read-only otherwise, `false`. This field
        /// shows the read-only status as of the most recent `WriteBlocks()`
        read_only: bool,
        /// `true` if the WriteBlocks() function caches write data.
        write_caching: bool,

        /// The intrinsic block size of the device. If the media changes, then this
        // field is updated. Returns the number of bytes per logical block.
        block_size: u32,
        /// Supplies the alignment requirement for any buffer used in a data
        /// transfer. IoAlign values of 0 and 1 mean that the buffer can be
        /// placed anywhere in memory. Otherwise, IoAlign must be a power of
        /// 2, and the requirement is that the start address of a buffer must be
        /// evenly divisible by IoAlign with no remainder.
        io_align: u32,
        /// The last LBA on the device. If the media changes, then this field is updated.
        last_block: u64,

        // Revision 2
        lowest_aligned_lba: u64,
        logical_blocks_per_physical_block: u32,
        optimal_transfer_length_granularity: u32,
    };
};
