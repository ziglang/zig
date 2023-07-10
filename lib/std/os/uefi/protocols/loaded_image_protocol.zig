const std = @import("std");
const uefi = std.os.uefi;
const Guid = uefi.Guid;
const Handle = uefi.Handle;
const Status = uefi.Status;
const SystemTable = uefi.tables.SystemTable;
const MemoryType = uefi.tables.MemoryType;
const DevicePathProtocol = uefi.protocols.DevicePathProtocol;
const cc = uefi.cc;

pub const LoadedImageProtocol = extern struct {
    revision: u32,
    parent_handle: Handle,
    system_table: *SystemTable,
    device_handle: ?Handle,
    file_path: *DevicePathProtocol,
    reserved: *anyopaque,
    load_options_size: u32,
    load_options: ?*anyopaque,
    image_base: [*]u8,
    image_size: u64,
    image_code_type: MemoryType,
    image_data_type: MemoryType,
    _unload: *const fn (*const LoadedImageProtocol, Handle) callconv(cc) Status,

    /// Unloads an image from memory.
    pub fn unload(self: *const LoadedImageProtocol, handle: Handle) Status {
        return self._unload(self, handle);
    }

    pub const guid align(8) = Guid{
        .time_low = 0x5b1b31a1,
        .time_mid = 0x9562,
        .time_high_and_version = 0x11d2,
        .clock_seq_high_and_reserved = 0x8e,
        .clock_seq_low = 0x3f,
        .node = [_]u8{ 0x00, 0xa0, 0xc9, 0x69, 0x72, 0x3b },
    };
};

pub const loaded_image_device_path_protocol_guid align(8) = Guid{
    .time_low = 0xbc62157e,
    .time_mid = 0x3e33,
    .time_high_and_version = 0x4fec,
    .clock_seq_high_and_reserved = 0x99,
    .clock_seq_low = 0x20,
    .node = [_]u8{ 0x2d, 0x3b, 0x36, 0xd7, 0x50, 0xdf },
};
