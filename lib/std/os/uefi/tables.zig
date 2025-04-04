pub const BootServices = @import("tables/boot_services.zig").BootServices;
pub const RuntimeServices = @import("tables/runtime_services.zig").RuntimeServices;
pub const ConfigurationTable = @import("tables/configuration_table.zig").ConfigurationTable;
pub const SystemTable = @import("tables/system_table.zig").SystemTable;
pub const TableHeader = @import("tables/table_header.zig").TableHeader;

pub const EventNotify = *const fn (event: Event, ctx: *anyopaque) callconv(cc) void;

pub const TimerDelay = enum(u32) {
    cancel,
    periodic,
    relative,
};

pub const MemoryType = enum(u32) {
    /// can only be allocated using .allocate_any_pages mode unless you are explicitly targeting an interface that states otherwise
    reserved_memory_type,
    loader_code,
    loader_data,
    boot_services_code,
    boot_services_data,
    /// can only be allocated using .allocate_any_pages mode unless you are explicitly targeting an interface that states otherwise
    runtime_services_code,
    /// can only be allocated using .allocate_any_pages mode unless you are explicitly targeting an interface that states otherwise
    runtime_services_data,
    conventional_memory,
    unusable_memory,
    /// can only be allocated using .allocate_any_pages mode unless you are explicitly targeting an interface that states otherwise
    acpi_reclaim_memory,
    /// can only be allocated using .allocate_any_pages mode unless you are explicitly targeting an interface that states otherwise
    acpi_memory_nvs,
    memory_mapped_io,
    memory_mapped_io_port_space,
    pal_code,
    persistent_memory,
    unaccepted_memory,
    max_memory_type,
    // per https://github.com/tianocore/edk2/blob/59805c7697c801be8b08e5169bc2300d821c419d/MdePkg/Include/Uefi/UefiSpec.h#L191-L195
    max_invalid_memory_type = 0x6FFFFFFF,
    oem_start = 0x70000000,
    oem_end = 0x7FFFFFFF,
    vendor_start = 0x80000000,
    vendor_end = 0xFFFFFFFF,
    _,

    pub fn isInvalid(self: MemoryType) bool {
        const as_int = @intFromEnum(self);
        return as_int >= @intFromEnum(MemoryType.max_memory_type) and
            as_int <= @intFromEnum(MemoryType.max_invalid_memory_type);
    }

    pub fn isOem(self: MemoryType) bool {
        const as_int = @intFromEnum(self);
        return as_int >= @intFromEnum(MemoryType.oem_start) and
            as_int <= @intFromEnum(MemoryType.oem_end);
    }

    pub fn isVendor(self: MemoryType) bool {
        const as_int = @intFromEnum(self);
        return as_int >= @intFromEnum(MemoryType.vendor_start) and
            as_int <= @intFromEnum(MemoryType.vendor_end);
    }
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

pub const MemoryMapKey = enum(usize) { _ };

pub const MemoryDescriptor = extern struct {
    type: MemoryType,
    physical_start: u64,
    virtual_start: u64,
    number_of_pages: u64,
    attribute: MemoryDescriptorAttribute,
};

pub const MemoryMapInfo = struct {
    key: MemoryMapKey,
    descriptor_size: usize,
    descriptor_version: u32,
    len: usize,
};

pub const MemoryMapSlice = struct {
    info: MemoryMapInfo,
    ptr: [*]align(@alignOf(MemoryDescriptor)) u8,

    pub fn iterator(self: MemoryMapSlice) MemoryDescriptorIterator {
        return .{ .ctx = self };
    }

    pub fn get(self: MemoryMapSlice, index: usize) ?*MemoryDescriptor {
        if (index >= self.info.len) return null;
        return self.getUnchecked(index);
    }

    pub fn getUnchecked(self: MemoryMapSlice, index: usize) *MemoryDescriptor {
        const offset: usize = index * self.info.descriptor_size;
        return @ptrCast(self.ptr[offset..]);
    }
};

pub const MemoryDescriptorIterator = struct {
    ctx: MemoryMapSlice,
    index: usize = 0,

    pub fn next(self: *MemoryDescriptorIterator) ?*MemoryDescriptor {
        const md = self.ctx.get(self.index) orelse return null;
        self.index += 1;
        return md;
    }
};

pub const LocateSearchType = enum(u32) {
    all_handles,
    by_register_notify,
    by_protocol,
};

pub const LocateSearch = union(LocateSearchType) {
    all_handles,
    by_register_notify: uefi.EventRegistration,
    by_protocol: *align(8) const Guid,
};

pub const OpenProtocolAttributes = enum(u32) {
    pub const Bits = packed struct(u32) {
        by_handle_protocol: bool = false,
        get_protocol: bool = false,
        test_protocol: bool = false,
        by_child_controller: bool = false,
        by_driver: bool = false,
        exclusive: bool = false,
        reserved: u26 = 0,
    };

    by_handle_protocol = @bitCast(Bits{ .by_handle_protocol = true }),
    get_protocol = @bitCast(Bits{ .get_protocol = true }),
    test_protocol = @bitCast(Bits{ .test_protocol = true }),
    by_child_controller = @bitCast(Bits{ .by_child_controller = true }),
    by_driver = @bitCast(Bits{ .by_driver = true }),
    by_driver_exclusive = @bitCast(Bits{ .by_driver = true, .exclusive = true }),
    exclusive = @bitCast(Bits{ .exclusive = true }),
};

pub const OpenProtocolArgs = union(OpenProtocolAttributes) {
    /// Used in the implementation of `handleProtocol`.
    by_handle_protocol: struct { agent: ?Handle = null, controller: ?Handle = null },
    /// Used by a driver to get a protocol interface from a handle. Care must be
    /// taken when using this open mode because the driver that opens a protocol
    /// interface in this manner will not be informed if the protocol interface
    /// is uninstalled or reinstalled. The caller is also not required to close
    /// the protocol interface with `closeProtocol`.
    get_protocol: struct { agent: ?Handle = null, controller: ?Handle = null },
    /// Used by a driver to test for the existence of a protocol interface on a
    /// handle. The caller only use the return status code. The caller is also
    /// not required to close the protocol interface with `closeProtocol`.
    test_protocol: struct { agent: ?Handle = null, controller: ?Handle = null },
    /// Used by bus drivers to show that a protocol interface is being used by one
    /// of the child controllers of a bus. This information is used by
    /// `BootServices.connectController` to recursively connect all child controllers
    /// and by `BootServices.disconnectController` to get the list of child
    /// controllers that a bus driver created.
    by_child_controller: struct { agent: Handle, controller: Handle },
    /// Used by a driver to gain access to a protocol interface. When this mode
    /// is used, the driver’s Stop() function will be called by
    /// `BootServices.disconnectController` if the protocol interface is reinstalled
    /// or uninstalled. Once a protocol interface is opened by a driver with this
    /// attribute, no other drivers will be allowed to open the same protocol interface
    /// with the `.by_driver` attribute.
    by_driver: struct { agent: Handle, controller: Handle },
    /// Used by a driver to gain exclusive access to a protocol interface. If any
    /// other drivers have the protocol interface opened with an attribute of
    /// `.by_driver`, then an attempt will be made to remove them with
    /// `BootServices.disconnectController`.
    by_driver_exclusive: struct { agent: Handle, controller: Handle },
    /// Used by applications to gain exclusive access to a protocol interface. If
    /// any drivers have the protocol interface opened with an attribute of
    /// `.by_driver`, then an attempt will be made to remove them by calling the
    /// driver’s Stop() function.
    exclusive: struct { agent: Handle, controller: ?Handle = null },
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

pub const AllocateLocation = union(AllocateType) {
    allocate_any_pages,
    allocate_max_address: [*]align(4096) uefi.Page,
    allocate_address: [*]align(4096) uefi.Page,
};

pub const AllocateType = enum(u32) {
    allocate_any_pages,
    allocate_max_address,
    allocate_address,
    _,
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
    cold,
    warm,
    shutdown,
    platform_specific,
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
