const uefi = @import("std").os.uefi;
const Guid = uefi.Guid;
const Handle = uefi.Handle;
const SystemTable = uefi.tables.SystemTable;
const MemoryType = uefi.tables.MemoryType;
const DevicePathProtocol = uefi.protocols.DevicePathProtocol;

pub const LoadedImageProtocol = extern struct {
    revision: u32,
    parent_handle: Handle,
    system_table: *SystemTable,
    device_handle: ?Handle,
    file_path: *DevicePathProtocol,
    reserved: *c_void,
    load_options_size: u32,
    load_options: *c_void,
    image_base: [*]u8,
    image_size: u64,
    image_code_type: MemoryType,
    image_data_type: MemoryType,
    _unload: extern fn (*const LoadedImageProtocol, Handle) usize,

    /// Unloads an image from memory.
    pub fn unload(self: *const LoadedImageProtocol, handle: Handle) usize {
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
