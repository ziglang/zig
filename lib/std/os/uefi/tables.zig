pub const BootServices = @import("tables/boot_services.zig").BootServices;
pub const RuntimeServices = @import("tables/runtime_services.zig").RuntimeServices;
pub const ConfigurationTable = @import("tables/configuration_table.zig").ConfigurationTable;
pub const SystemTable = @import("tables/system_table.zig").SystemTable;
pub const TableHeader = @import("tables/table_header.zig").TableHeader;

pub const EventNotify = *const fn (event: Event, ctx: *anyopaque) callconv(cc) void;

pub const TimerDelay = enum(u32) {
    timer_cancel,
    timer_periodic,
    timer_relative,
};

pub const MemoryType = enum(u32) {
    reserved_memory_type,
    loader_code,
    loader_data,
    boot_services_code,
    boot_services_data,
    runtime_services_code,
    runtime_services_data,
    conventional_memory,
    unusable_memory,
    acpi_reclaim_memory,
    acpi_memory_nvs,
    memory_mapped_io,
    memory_mapped_io_port_space,
    pal_code,
    persistent_memory,
    max_memory_type,
    _,
};

pub const MemoryDescriptorAttribute = packed struct(u64) {
    uc: bool,
    wc: bool,
    wt: bool,
    wb: bool,
    uce: bool,
    _pad1: u7 = 0,
    wp: bool,
    rp: bool,
    xp: bool,
    nv: bool,
    more_reliable: bool,
    ro: bool,
    sp: bool,
    cpu_crypto: bool,
    _pad2: u43 = 0,
    memory_runtime: bool,
};

pub const MemoryDescriptor = extern struct {
    type: MemoryType,
    physical_start: u64,
    virtual_start: u64,
    number_of_pages: u64,
    attribute: MemoryDescriptorAttribute,
};

pub const LocateSearchType = enum(u32) {
    all_handles,
    by_register_notify,
    by_protocol,
};

pub const OpenProtocolAttributes = packed struct(u32) {
    by_handle_protocol: bool = false,
    get_protocol: bool = false,
    test_protocol: bool = false,
    by_child_controller: bool = false,
    by_driver: bool = false,
    exclusive: bool = false,
    reserved: u26 = 0,
};

pub const ProtocolInformationEntry = extern struct {
    agent_handle: ?Handle,
    controller_handle: ?Handle,
    attributes: OpenProtocolAttributes,
    open_count: u32,
};

pub const InterfaceType = enum(u32) {
    efi_native_interface,
};

pub const AllocateType = enum(u32) {
    allocate_any_pages,
    allocate_max_address,
    allocate_address,
};

pub const PhysicalAddress = u64;

pub const CapsuleHeader = extern struct {
    capsule_guid: Guid align(8),
    header_size: u32,
    flags: u32,
    capsule_image_size: u32,
};

pub const UefiCapsuleBlockDescriptor = extern struct {
    length: u64,
    address: extern union {
        data_block: PhysicalAddress,
        continuation_pointer: PhysicalAddress,
    },
};

pub const ResetType = enum(u32) {
    reset_cold,
    reset_warm,
    reset_shutdown,
    reset_platform_specific,
};

pub const global_variable align(8) = Guid{
    .time_low = 0x8be4df61,
    .time_mid = 0x93ca,
    .time_high_and_version = 0x11d2,
    .clock_seq_high_and_reserved = 0xaa,
    .clock_seq_low = 0x0d,
    .node = [_]u8{ 0x00, 0xe0, 0x98, 0x03, 0x2b, 0x8c },
};

test {
    std.testing.refAllDeclsRecursive(@This());
}

const std = @import("std");
const uefi = std.os.uefi;
const Handle = uefi.Handle;
const Event = uefi.Event;
const Guid = uefi.Guid;
const cc = uefi.cc;
