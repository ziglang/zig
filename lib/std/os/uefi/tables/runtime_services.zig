const std = @import("std");
const uefi = std.os.uefi;
const Guid = uefi.Guid;
const TableHeader = uefi.tables.TableHeader;
const Time = uefi.Time;
const TimeCapabilities = uefi.TimeCapabilities;
const Status = uefi.Status;
const MemoryDescriptor = uefi.tables.MemoryDescriptor;
const ResetType = uefi.tables.ResetType;
const CapsuleHeader = uefi.tables.CapsuleHeader;
const PhysicalAddress = uefi.tables.PhysicalAddress;
const cc = uefi.cc;

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
    getTime: *const fn (time: *uefi.Time, capabilities: ?*TimeCapabilities) callconv(cc) Status,

    /// Sets the current local time and date information
    setTime: *const fn (time: *uefi.Time) callconv(cc) Status,

    /// Returns the current wakeup alarm clock setting
    getWakeupTime: *const fn (enabled: *bool, pending: *bool, time: *uefi.Time) callconv(cc) Status,

    /// Sets the system wakeup alarm clock time
    setWakeupTime: *const fn (enable: *bool, time: ?*uefi.Time) callconv(cc) Status,

    /// Changes the runtime addressing mode of EFI firmware from physical to virtual.
    setVirtualAddressMap: *const fn (mmap_size: usize, descriptor_size: usize, descriptor_version: u32, virtual_map: [*]MemoryDescriptor) callconv(cc) Status,

    /// Determines the new virtual address that is to be used on subsequent memory accesses.
    convertPointer: *const fn (debug_disposition: usize, address: **anyopaque) callconv(cc) Status,

    /// Returns the value of a variable.
    getVariable: *const fn (var_name: [*:0]const u16, vendor_guid: *align(8) const Guid, attributes: ?*u32, data_size: *usize, data: ?*anyopaque) callconv(cc) Status,

    /// Enumerates the current variable names.
    getNextVariableName: *const fn (var_name_size: *usize, var_name: [*:0]u16, vendor_guid: *align(8) Guid) callconv(cc) Status,

    /// Sets the value of a variable.
    setVariable: *const fn (var_name: [*:0]const u16, vendor_guid: *align(8) const Guid, attributes: u32, data_size: usize, data: *anyopaque) callconv(cc) Status,

    /// Return the next high 32 bits of the platform's monotonic counter
    getNextHighMonotonicCount: *const fn (high_count: *u32) callconv(cc) Status,

    /// Resets the entire platform.
    resetSystem: *const fn (reset_type: ResetType, reset_status: Status, data_size: usize, reset_data: ?*const anyopaque) callconv(cc) noreturn,

    /// Passes capsules to the firmware with both virtual and physical mapping.
    /// Depending on the intended consumption, the firmware may process the capsule immediately.
    /// If the payload should persist across a system reset, the reset value returned from
    /// `queryCapsuleCapabilities` must be passed into resetSystem and will cause the capsule
    /// to be processed by the firmware as part of the reset process.
    updateCapsule: *const fn (capsule_header_array: **CapsuleHeader, capsule_count: usize, scatter_gather_list: PhysicalAddress) callconv(cc) Status,

    /// Returns if the capsule can be supported via `updateCapsule`
    queryCapsuleCapabilities: *const fn (capsule_header_array: **CapsuleHeader, capsule_count: usize, maximum_capsule_size: *usize, reset_type: ResetType) callconv(cc) Status,

    /// Returns information about the EFI variables
    queryVariableInfo: *const fn (attributes: *u32, maximum_variable_storage_size: *u64, remaining_variable_storage_size: *u64, maximum_variable_size: *u64) callconv(cc) Status,

    pub const signature: u64 = 0x56524553544e5552;
};
