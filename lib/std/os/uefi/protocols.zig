// Misc
pub usingnamespace @import("protocols/loaded_image_protocol.zig");
pub usingnamespace @import("protocols/device_path_protocol.zig");
pub usingnamespace @import("protocols/rng_protocol.zig");
pub usingnamespace @import("protocols/shell_parameters_protocol.zig");

// Files / IO
pub usingnamespace @import("protocols/simple_file_system_protocol.zig");
pub usingnamespace @import("protocols/file_protocol.zig");
pub usingnamespace @import("protocols/block_io_protocol.zig");

// Text
pub usingnamespace @import("protocols/simple_text_input_protocol.zig");
pub usingnamespace @import("protocols/simple_text_input_ex_protocol.zig");
pub usingnamespace @import("protocols/simple_text_output_protocol.zig");

// Pointer
pub usingnamespace @import("protocols/simple_pointer_protocol.zig");
pub usingnamespace @import("protocols/absolute_pointer_protocol.zig");

pub usingnamespace @import("protocols/graphics_output_protocol.zig");

// edid
pub usingnamespace @import("protocols/edid_discovered_protocol.zig");
pub usingnamespace @import("protocols/edid_active_protocol.zig");
pub usingnamespace @import("protocols/edid_override_protocol.zig");

// Network
pub usingnamespace @import("protocols/simple_network_protocol.zig");
pub usingnamespace @import("protocols/managed_network_service_binding_protocol.zig");
pub usingnamespace @import("protocols/managed_network_protocol.zig");

// ip6
pub usingnamespace @import("protocols/ip6_service_binding_protocol.zig");
pub usingnamespace @import("protocols/ip6_protocol.zig");
pub usingnamespace @import("protocols/ip6_config_protocol.zig");

// udp6
pub usingnamespace @import("protocols/udp6_service_binding_protocol.zig");
pub usingnamespace @import("protocols/udp6_protocol.zig");

// hii
pub const hii = @import("protocols/hii.zig");
pub usingnamespace @import("protocols/hii_database_protocol.zig");
pub usingnamespace @import("protocols/hii_popup_protocol.zig");

test {
    @setEvalBranchQuota(2000);
    @import("std").testing.refAllDeclsRecursive(@This());
}
