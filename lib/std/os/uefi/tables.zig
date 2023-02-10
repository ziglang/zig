pub usingnamespace @import("tables/boot_services.zig");
pub usingnamespace @import("tables/runtime_services.zig");
pub usingnamespace @import("tables/configuration_table.zig");
pub usingnamespace @import("tables/system_table.zig");
pub usingnamespace @import("tables/table_header.zig");

test {
    @import("std").testing.refAllDeclsRecursive(@This());
}
