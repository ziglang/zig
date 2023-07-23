const std = @import("std");
const uefi = std.os.uefi;
const Guid = uefi.Guid;
const FileProtocol = uefi.protocols.FileProtocol;
const Status = uefi.Status;
const cc = uefi.cc;

pub const SimpleFileSystemProtocol = extern struct {
    revision: u64,
    _open_volume: *const fn (*const SimpleFileSystemProtocol, **const FileProtocol) callconv(cc) Status,

    pub fn openVolume(self: *const SimpleFileSystemProtocol, root: **const FileProtocol) Status {
        return self._open_volume(self, root);
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
