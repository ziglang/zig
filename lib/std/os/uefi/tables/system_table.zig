const uefi = @import("std").os.uefi;
const BootServices = uefi.tables.BootServices;
const ConfigurationTable = uefi.tables.ConfigurationTable;
const Handle = uefi.Handle;
const RuntimeServices = uefi.tables.RuntimeServices;
const SimpleTextInputProtocol = uefi.protocols.SimpleTextInputProtocol;
const SimpleTextOutputProtocol = uefi.protocols.SimpleTextOutputProtocol;
const TableHeader = uefi.tables.TableHeader;

/// The EFI System Table contains pointers to the runtime and boot services tables.
///
/// As the system_table may grow with new UEFI versions, it is important to check hdr.header_size.
///
/// After successfully calling boot_services.exitBootServices, console_in_handle,
/// con_in, console_out_handle, con_out, standard_error_handle, std_err, and
/// boot_services should be set to null. After setting these attributes to null,
/// hdr.crc32 must be recomputed.
pub const SystemTable = extern struct {
    hdr: TableHeader,

    /// A null-terminated string that identifies the vendor that produces the system firmware of the platform.
    firmware_vendor: [*:0]u16,
    firmware_revision: u32,
    console_in_handle: ?Handle,
    con_in: ?*SimpleTextInputProtocol,
    console_out_handle: ?Handle,
    con_out: ?*SimpleTextOutputProtocol,
    standard_error_handle: ?Handle,
    std_err: ?*SimpleTextOutputProtocol,
    runtime_services: *RuntimeServices,
    boot_services: ?*BootServices,
    number_of_table_entries: usize,
    configuration_table: [*]ConfigurationTable,

    pub const signature: u64 = 0x5453595320494249;
    pub const revision_1_02: u32 = (1 << 16) | 2;
    pub const revision_1_10: u32 = (1 << 16) | 10;
    pub const revision_2_00: u32 = (2 << 16);
    pub const revision_2_10: u32 = (2 << 16) | 10;
    pub const revision_2_20: u32 = (2 << 16) | 20;
    pub const revision_2_30: u32 = (2 << 16) | 30;
    pub const revision_2_31: u32 = (2 << 16) | 31;
    pub const revision_2_40: u32 = (2 << 16) | 40;
    pub const revision_2_50: u32 = (2 << 16) | 50;
    pub const revision_2_60: u32 = (2 << 16) | 60;
    pub const revision_2_70: u32 = (2 << 16) | 70;
    pub const revision_2_80: u32 = (2 << 16) | 80;
};
