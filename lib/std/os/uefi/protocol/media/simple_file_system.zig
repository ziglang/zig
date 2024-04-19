const bits = @import("../../bits.zig");
const protocol = @import("../../protocol.zig");

const cc = bits.cc;
const Status = @import("../../status.zig").Status;
const FileProtocol = protocol.File;

const Guid = bits.Guid;

pub const SimpleFileSystem = extern struct {
    revision: u64,
    _open_volume: *const fn (*const SimpleFileSystem, fd: **const FileProtocol) callconv(cc) Status,

    /// Opens the root directory on a volume.
    pub fn openVolume(self: *const SimpleFileSystem) !*const FileProtocol {
        var root: *const FileProtocol = undefined;
        try self._open_volume(self, &root).err();
        return root;
    }

    pub const guid align(8) = Guid{
        .time_low = 0x0964e5b22,
        .time_mid = 0x6459,
        .time_high_and_version = 0x11d2,
        .clock_seq_high_and_reserved = 0x8e,
        .clock_seq_low = 0x39,
        .node = [_]u8{ 0x00, 0xa0, 0xc9, 0x69, 0x72, 0x3b },
    };
};
