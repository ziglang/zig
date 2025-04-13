const std = @import("std");
const uefi = std.os.uefi;
const Guid = uefi.Guid;
const File = uefi.protocol.File;
const Status = uefi.Status;
const cc = uefi.cc;
const Error = Status.Error;

pub const SimpleFileSystem = extern struct {
    revision: u64,
    _open_volume: *const fn (*const SimpleFileSystem, **File) callconv(cc) Status,

    pub const OpenVolumeError = uefi.UnexpectedError || error{
        Unsupported,
        NoMedia,
        DeviceError,
        VolumeCorrupted,
        AccessDenied,
        OutOfResources,
        MediaChanged,
    };

    pub fn openVolume(self: *const SimpleFileSystem) OpenVolumeError!*File {
        var root: *File = undefined;
        switch (self._open_volume(self, &root)) {
            .success => return root,
            .unsupported => return Error.Unsupported,
            .no_media => return Error.NoMedia,
            .device_error => return Error.DeviceError,
            .volume_corrupted => return Error.VolumeCorrupted,
            .access_denied => return Error.AccessDenied,
            .out_of_resources => return Error.OutOfResources,
            .media_changed => return Error.MediaChanged,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    pub const guid = Guid{
        .time_low = 0x0964e5b22,
        .time_mid = 0x6459,
        .time_high_and_version = 0x11d2,
        .clock_seq_high_and_reserved = 0x8e,
        .clock_seq_low = 0x39,
        .node = [_]u8{ 0x00, 0xa0, 0xc9, 0x69, 0x72, 0x3b },
    };
};
