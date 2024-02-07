pub const BootServices = @import("tables/boot_services.zig").BootServices;
pub const RuntimeServices = @import("tables/runtime_services.zig").RuntimeServices;
pub const ConfigurationTable = @import("tables/configuration_table.zig").ConfigurationTable;
pub const SystemTable = @import("tables/system_table.zig").SystemTable;
pub const TableHeader = @import("tables/table_header.zig").TableHeader;

pub const EfiEventNotify = *const fn (event: Event, ctx: *anyopaque) callconv(cc) void;

pub const TimerDelay = enum(u32) {
    TimerCancel,
    TimerPeriodic,
    TimerRelative,
};

pub const MemoryType = enum(u32) {
    ReservedMemoryType,
    LoaderCode,
    LoaderData,
    BootServicesCode,
    BootServicesData,
    RuntimeServicesCode,
    RuntimeServicesData,
    ConventionalMemory,
    UnusableMemory,
    ACPIReclaimMemory,
    ACPIMemoryNVS,
    MemoryMappedIO,
    MemoryMappedIOPortSpace,
    PalCode,
    PersistentMemory,
    MaxMemoryType,
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
    AllHandles,
    ByRegisterNotify,
    ByProtocol,
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

pub const EfiInterfaceType = enum(u32) {
    EfiNativeInterface,
};

pub const AllocateType = enum(u32) {
    AllocateAnyPages,
    AllocateMaxAddress,
    AllocateAddress,
};

pub const EfiPhysicalAddress = u64;

pub const CapsuleHeader = extern struct {
    capsuleGuid: Guid align(8),
    headerSize: u32,
    flags: u32,
    capsuleImageSize: u32,
};

pub const UefiCapsuleBlockDescriptor = extern struct {
    length: u64,
    address: extern union {
        dataBlock: EfiPhysicalAddress,
        continuationPointer: EfiPhysicalAddress,
    },
};

pub const ResetType = enum(u32) {
    ResetCold,
    ResetWarm,
    ResetShutdown,
    ResetPlatformSpecific,
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
