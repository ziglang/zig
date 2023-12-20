pub const Header = @import("table/header.zig").Header;
pub const BootServices = @import("table/boot_services.zig").BootServices;
pub const RuntimeServices = @import("table/runtime_services.zig").RuntimeServices;
pub const SystemTable = @import("table/system.zig").SystemTable;

const configuration_table = @import("table/configuration.zig");
pub const ConfigurationTable = configuration_table.ConfigurationTable;
pub const RtPropertiesTable = configuration_table.RtPropertiesTable;
pub const MemoryAttributesTable = configuration_table.MemoryAttributesTable;

test {
    @import("std").testing.refAllDeclsRecursive(@This());
}
