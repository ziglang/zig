const std = @import("std");
const uefi = std.os.uefi;

pub const ServiceBinding = @import("protocol/service_binding.zig").ServiceBinding;

pub const LoadedImage = @import("protocol/loaded_image.zig").LoadedImage;
pub const DevicePath = @import("protocol/device_path.zig").DevicePath;
pub const Rng = @import("protocol/rng.zig").Rng;
pub const ShellParameters = @import("protocol/shell_parameters.zig").ShellParameters;

pub const SimpleFileSystem = @import("protocol/simple_file_system.zig").SimpleFileSystem;
pub const File = @import("protocol/file.zig").File;
pub const BlockIo = @import("protocol/block_io.zig").BlockIo;

pub const SimpleTextInput = @import("protocol/simple_text_input.zig").SimpleTextInput;
pub const SimpleTextInputEx = @import("protocol/simple_text_input_ex.zig").SimpleTextInputEx;
pub const SimpleTextOutput = @import("protocol/simple_text_output.zig").SimpleTextOutput;

pub const SimplePointer = @import("protocol/simple_pointer.zig").SimplePointer;
pub const AbsolutePointer = @import("protocol/absolute_pointer.zig").AbsolutePointer;

pub const SerialIo = @import("protocol/serial_io.zig").SerialIo;

pub const GraphicsOutput = @import("protocol/graphics_output.zig").GraphicsOutput;

pub const edid = @import("protocol/edid.zig");

pub const SimpleNetwork = @import("protocol/simple_network.zig").SimpleNetwork;
pub const ManagedNetwork = @import("protocol/managed_network.zig").ManagedNetwork;

pub const Ip6ServiceBinding = ServiceBinding(.{
    .time_low = 0xec835dd3,
    .time_mid = 0xfe0f,
    .time_high_and_version = 0x617b,
    .clock_seq_high_and_reserved = 0xa6,
    .clock_seq_low = 0x21,
    .node = [_]u8{ 0xb3, 0x50, 0xc3, 0xe1, 0x33, 0x88 },
});
pub const Ip6 = @import("protocol/ip6.zig").Ip6;
pub const Ip6Config = @import("protocol/ip6_config.zig").Ip6Config;

pub const Udp6ServiceBinding = ServiceBinding(.{
    .time_low = 0x66ed4721,
    .time_mid = 0x3c98,
    .time_high_and_version = 0x4d3e,
    .clock_seq_high_and_reserved = 0x81,
    .clock_seq_low = 0xe3,
    .node = [_]u8{ 0xd0, 0x3d, 0xd3, 0x9a, 0x72, 0x54 },
});
pub const Udp6 = @import("protocol/udp6.zig").Udp6;

pub const HiiDatabase = @import("protocol/hii_database.zig").HiiDatabase;
pub const HiiPopup = @import("protocol/hii_popup.zig").HiiPopup;

test {
    @setEvalBranchQuota(2000);
    @import("std").testing.refAllDeclsRecursive(@This());
}
