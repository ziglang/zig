const bits = @import("../../bits.zig");
const protocol = @import("../../protocol.zig");

const cc = bits.cc;
const Status = @import("../../status.zig").Status;
const DevicePathProtocol = protocol.DevicePath;

const Guid = bits.Guid;

/// Used to obtain files, that are primarily boot options, from arbitrary devices.
pub const LoadFile = extern struct {
    _load_file: *const fn (*const LoadFile, file_path: *const DevicePathProtocol, is_boot_policy: bool, buf_size: *usize, buf: ?[*]u8) callconv(cc) Status,

    /// Determines the size of buffer required to hold the specified file.
    pub fn loadFileSize(
        self: *const LoadFile,
        /// The device specific path of the file to load.
        file_path: *const DevicePathProtocol,
        /// If true, the request originates from the boot manager, and that the boot manager is attempting to load the
        /// file as a boot selection. If false, the file path must match an exact file to be loaded.
        boot_policy: bool,
    ) !usize {
        var size: usize = 0;
        self._load_file(self, file_path, boot_policy, &size, null).err() catch |err| switch (err) {
            error.BufferTooSmall => {},
            else => |e| return e,
        };

        return size;
    }

    /// Causes the driver to load a specified file.
    pub fn loadFile(
        self: *const LoadFile,
        /// The device specific path of the file to load.
        file_path: *const DevicePathProtocol,
        /// If true, the request originates from the boot manager, and that the boot manager is attempting to load the
        /// file as a boot selection. If false, the file path must match an exact file to be loaded.
        boot_policy: bool,
        /// The memory buffer to transfer the file to.
        buffer: []u8,
    ) !usize {
        var size: usize = buffer.len;
        try self._load_file(self, file_path, boot_policy, &size, buffer.ptr).err();
        return size;
    }

    pub const guid align(8) = Guid{
        .time_low = 0x56ec3091,
        .time_mid = 0x954c,
        .time_high_and_version = 0x11d2,
        .clock_seq_high_and_reserved = 0x8e,
        .clock_seq_low = 0x3f,
        .node = [_]u8{ 0x00, 0xa0, 0xc9, 0x69, 0x72, 0x3b },
    };
};
