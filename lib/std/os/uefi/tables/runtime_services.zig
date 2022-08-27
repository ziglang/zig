const std = @import("std");
const uefi = std.os.uefi;
const Guid = uefi.Guid;
const TableHeader = uefi.tables.TableHeader;
const Time = uefi.Time;
const TimeCapabilities = uefi.TimeCapabilities;
const Status = uefi.Status;
const MemoryDescriptor = uefi.tables.MemoryDescriptor;

/// Runtime services are provided by the firmware before and after exitBootServices has been called.
///
/// As the runtime_services table may grow with new UEFI versions, it is important to check hdr.header_size.
///
/// Some functions may not be supported. Check the RuntimeServicesSupported variable using getVariable.
/// getVariable is one of the functions that may not be supported.
///
/// Some functions may not be called while other functions are running.
pub const RuntimeServices = extern struct {
    hdr: TableHeader,

    /// Returns the current time and date information, and the time-keeping capabilities of the hardware platform.
    getTime: std.meta.FnPtr(fn (time: *uefi.Time, capabilities: ?*TimeCapabilities) callconv(.C) Status),

    /// Sets the current local time and date information
    setTime: std.meta.FnPtr(fn (time: *uefi.Time) callconv(.C) Status),

    /// Returns the current wakeup alarm clock setting
    getWakeupTime: std.meta.FnPtr(fn (enabled: *bool, pending: *bool, time: *uefi.Time) callconv(.C) Status),

    /// Sets the system wakeup alarm clock time
    setWakeupTime: std.meta.FnPtr(fn (enable: *bool, time: ?*uefi.Time) callconv(.C) Status),

    /// Changes the runtime addressing mode of EFI firmware from physical to virtual.
    setVirtualAddressMap: std.meta.FnPtr(fn (mmap_size: usize, descriptor_size: usize, descriptor_version: u32, virtual_map: [*]MemoryDescriptor) callconv(.C) Status),

    /// Determines the new virtual address that is to be used on subsequent memory accesses.
    convertPointer: std.meta.FnPtr(fn (debug_disposition: usize, address: **anyopaque) callconv(.C) Status),

    /// Returns the value of a variable.
    getVariable: std.meta.FnPtr(fn (var_name: [*:0]const u16, vendor_guid: *align(8) const Guid, attributes: ?*u32, data_size: *usize, data: ?*anyopaque) callconv(.C) Status),

    /// Enumerates the current variable names.
    getNextVariableName: std.meta.FnPtr(fn (var_name_size: *usize, var_name: [*:0]u16, vendor_guid: *align(8) Guid) callconv(.C) Status),

    /// Sets the value of a variable.
    setVariable: std.meta.FnPtr(fn (var_name: [*:0]const u16, vendor_guid: *align(8) const Guid, attributes: u32, data_size: usize, data: *anyopaque) callconv(.C) Status),

    /// Return the next high 32 bits of the platform's monotonic counter
    getNextHighMonotonicCount: std.meta.FnPtr(fn (high_count: *u32) callconv(.C) Status),

    /// Resets the entire platform.
    resetSystem: std.meta.FnPtr(fn (reset_type: ResetType, reset_status: Status, data_size: usize, reset_data: ?*const anyopaque) callconv(.C) noreturn),

    /// Passes capsules to the firmware with both virtual and physical mapping.
    /// Depending on the intended consumption, the firmware may process the capsule immediately.
    /// If the payload should persist across a system reset, the reset value returned from
    /// `queryCapsuleCapabilities` must be passed into resetSystem and will cause the capsule
    /// to be processed by the firmware as part of the reset process.
    updateCapsule: std.meta.FnPtr(fn (capsule_header_array: **CapsuleHeader, capsule_count: usize, scatter_gather_list: EfiPhysicalAddress) callconv(.C) Status),

    /// Returns if the capsule can be supported via `updateCapsule`
    queryCapsuleCapabilities: std.meta.FnPtr(fn (capsule_header_array: **CapsuleHeader, capsule_count: usize, maximum_capsule_size: *usize, resetType: ResetType) callconv(.C) Status),

    /// Returns information about the EFI variables
    queryVariableInfo: std.meta.FnPtr(fn (attributes: *u32, maximum_variable_storage_size: *u64, remaining_variable_storage_size: *u64, maximum_variable_size: *u64) callconv(.C) Status),

    pub const signature: u64 = 0x56524553544e5552;
};

const EfiPhysicalAddress = u64;

pub const CapsuleHeader = extern struct {
    capsuleGuid: Guid align(8),
    headerSize: u32,
    flags: u32,
    capsuleImageSize: u32,
};

pub const UefiCapsuleBlockDescriptor = extern struct {
    length: u64,
    address: union {
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
