const bits = @import("../bits.zig");
const table = @import("../table.zig");
const protocol = @import("../protocol.zig");

const cc = bits.cc;
const Status = @import("../status.zig").Status;

const Guid = bits.Guid;
const Handle = bits.Handle;

pub const LoadedImage = extern struct {
    revision: u32,
    parent_handle: Handle,
    system_table: *table.System,
    device_handle: ?Handle,
    file_path: *const protocol.DevicePath,
    reserved: *anyopaque,
    load_options_size: u32,
    load_options: ?*anyopaque,
    image_base: [*]u8,
    image_size: u64,
    image_code_type: bits.MemoryDescriptor.Type,
    image_data_type: bits.MemoryDescriptor.Type,
    _unload: *const fn (Handle) callconv(cc) Status,

    /// Unloads an image from memory.
    pub fn unload(self: *const LoadedImage, handle: Handle) Status {
        return self._unload(handle);
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
