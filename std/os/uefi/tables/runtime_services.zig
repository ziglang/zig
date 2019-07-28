const uefi = @import("std").os.uefi;
const Guid = uefi.Guid;
const TableHeader = uefi.tables.TableHeader;
const Time = uefi.Time;
const TimeCapabilities = uefi.TimeCapabilities;

/// UEFI Specification, Version 2.8, 4.5
///
/// As the runtime_services table may grow with new UEFI versions, it is important to check hdr.header_size.
///
/// Some functions may not be supported. Check the RuntimeServicesSupported variable using getVariable.
/// getVariable is one of the functions that may not be supported. See UEFI Specification, Version 2.8, 8.1.
///
/// Some functions may not be called while other functions are running. See UEFI Specification, Version 2.8, 8.1.
pub const RuntimeServices = extern struct {
    hdr: TableHeader,
    getTime: extern fn (*uefi.Time, ?*TimeCapabilities) usize,
    setTime: usize, // TODO
    getWakeupTime: usize, // TODO
    setWakeupTime: usize, // TODO
    setVirtualAddressMap: usize, // TODO
    convertPointer: usize, // TODO
    getVariable: extern fn ([*]const u16, *align(8) const Guid, ?*u32, *usize, ?*c_void) usize,
    getNextVariableName: extern fn (*usize, [*]u16, *align(8) Guid) usize,
    setVariable: extern fn ([*]const u16, *align(8) const Guid, u32, usize, *c_void) usize,
    getNextHighMonotonicCount: usize, // TODO
    resetSystem: extern fn (ResetType, usize, usize, ?*const c_void) noreturn,
    updateCapsule: usize, // TODO
    queryCapsuleCapabilities: usize, // TODO
    queryVariableInfo: usize, // TODO

    pub const signature: u64 = 0x56524553544e5552;
};

/// UEFI Specification, Version 2.8, 8.5.1
pub const ResetType = extern enum(u32) {
    ResetCold,
    ResetWarm,
    ResetShutdown,
    ResetPlatformSpecific,
};
