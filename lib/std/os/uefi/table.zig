pub const Header = @import("table/header.zig").Header;
pub const BootServices = @import("table/boot_services.zig").BootServices;
pub const RuntimeServices = @import("table/runtime_services.zig").RuntimeServices;
pub const System = @import("table/system.zig").System;

const configuration_table = @import("table/configuration.zig");
pub const Configuration = configuration_table.Configuration;
pub const RtProperties = configuration_table.RtProperties;
pub const MemoryAttributes = configuration_table.MemoryAttributes;

test {
    @import("std").testing.refAllDeclsRecursive(@This());
}
