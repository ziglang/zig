const std = @import("../../../../std.zig");
const bits = @import("../../bits.zig");

const cc = bits.cc;
const Status = @import("../../status.zig").Status;

const Guid = bits.Guid;

pub const BlockIo = extern struct {
    revision: u64,
    media: *const Media,

    _reset: *const fn (*const BlockIo, verify: bool) callconv(cc) Status,
    _read_blocks: *const fn (*const BlockIo, media_id: u32, lba: bits.LogicalBlockAddress, buffer_size: usize, buf: [*]u8) callconv(cc) Status,
    _write_blocks: *const fn (*const BlockIo, media_id: u32, lba: bits.LogicalBlockAddress, buffer_size: usize, buf: [*]const u8) callconv(cc) Status,
    _flush_blocks: *const fn (*const BlockIo) callconv(cc) Status,

    /// Resets the block device hardware.
    pub fn reset(
        self: *BlockIo,
        /// Indicates that the driver may perform a more exhaustive verification operation of the device during reset.
        verify: bool,
    ) !void {
        try self._reset(self, verify).err();
    }

    /// Reads the number of requested blocks from the device.
    pub fn readBlocks(
        self: *BlockIo,
        /// The media ID that the read request is for.
        media_id: u32,
        /// The starting logical block address to read from on the device.
        lba: bits.LogicalBlockAddress,
        /// The buffer into which the data is read.
        buffer: []u8,
    ) !void {
        try self._read_blocks(self, media_id, lba, buffer.len, buffer.ptr).err();
    }

    /// Writes a specified number of blocks to the device.
    pub fn writeBlocks(
        self: *BlockIo,
        /// The media ID that the write request is for.
        media_id: u32,
        /// The starting logical block address to write from on the device.
        lba: bits.LogicalBlockAddress,
        /// The buffer from which the data is written.
        buffer: []const u8,
    ) !void {
        try self._write_blocks(self, media_id, lba, buffer.len, buffer.ptr).err();
    }

    /// Flushes all modified data to a physical block device.
    pub fn flushBlocks(self: *BlockIo) !void {
        try self._flush_blocks(self).err();
    }

    pub const guid align(8) = Guid{
        .time_low = 0x964e5b21,
        .time_mid = 0x6459,
        .time_high_and_version = 0x11d2,
        .clock_seq_high_and_reserved = 0x8e,
        .clock_seq_low = 0x39,
        .node = [_]u8{ 0x00, 0xa0, 0xc9, 0x69, 0x72, 0x3b },
    };

    pub const Media = extern struct {
        /// The current media ID. If the media changes, this value is changed.
        media_id: u32,

        /// `true` if the media is removable; otherwise, `false`.
        removable_media: bool,
        /// `true` if there is a media currently present in the device
        media_present: bool,
        /// `true` if the `BlockIo` was produced to abstract partition structures on the disk. `false` if the `BlockIo`
        /// was produced to abstract the logical blocks on a hardware device.
        logical_partition: bool,
        /// `true` if the media is marked read-only otherwise, `false`. This field shows the read-only status as of the
        /// most recent `WriteBlocks()`
        read_only: bool,
        /// `true` if the WriteBlocks() function caches write data.
        write_caching: bool,

        /// The intrinsic block size of the device. If the media changes, then this field is updated. Returns the number
        /// of bytes per logical block.
        block_size: u32,
        /// Supplies the alignment requirement for any buffer used in a data transfer. IoAlign values of 0 and 1 mean
        /// that the buffer can be placed anywhere in memory. Otherwise, IoAlign must be a power of 2, and the
        /// requirement is that the start address of a buffer must be evenly divisible by `io_align` with no remainder.
        io_align: u32,
        /// The last LBA on the device. If the media changes, then this field is updated.
        last_block: u64,

        // Revision 2

        /// Returns the first LBA that is aligned to a physical block boundary. If `logical_partition` is true, then this
        /// field will be zero.
        lowest_aligned_lba: u64,

        /// Returns the number of logical blocks per physical block. A value of 0 means there is either one logical
        /// block per physical block, or there are more than one physical block per logical block. If `logical_partition`
        /// is true, then this field will be zero.
        logical_blocks_per_physical_block: u32,

        /// Returns the optimal transfer length granularity as a number of logical blocks. A value of 0 means there is
        /// no reported optimal transfer length granularity. If `logical_partition` is true, then this field will be zero.
        optimal_transfer_length_granularity: u32,
    };
};
