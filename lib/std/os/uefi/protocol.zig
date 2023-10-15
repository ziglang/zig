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

pub const GraphicsOutput = @import("protocol/graphics_output.zig").GraphicsOutput;

pub const edid = @import("protocol/edid.zig");

pub const SimpleNetwork = @import("protocol/simple_network.zig").SimpleNetwork;
pub const ManagedNetwork = @import("protocol/managed_network.zig").ManagedNetwork;

pub const Ip6ServiceBinding = @import("protocol/ip6_service_binding.zig").Ip6ServiceBinding;
pub const Ip6 = @import("protocol/ip6.zig").Ip6;
pub const Ip6Config = @import("protocol/ip6_config.zig").Ip6Config;

pub const Udp6ServiceBinding = @import("protocol/udp6_service_binding.zig").Udp6ServiceBinding;
pub const Udp6 = @import("protocol/udp6.zig").Udp6;

pub const HiiDatabase = @import("protocol/hii_database.zig").HiiDatabase;
pub const HiiPopup = @import("protocol/hii_popup.zig").HiiPopup;

test {
    @setEvalBranchQuota(2000);
    @import("std").testing.refAllDeclsRecursive(@This());
}
