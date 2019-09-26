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

/// UEFI Specification, Version 2.8, 3.3
pub const global_variable align(8) = Guid{
    .time_low = 0x8be4df61,
    .time_mid = 0x93ca,
    .time_high_and_version = 0x11d2,
    .clock_seq_high_and_reserved = 0xaa,
    .clock_seq_low = 0x0d,
    .node = [_]u8{ 0x00, 0xe0, 0x98, 0x03, 0x2b, 0x8c },
};
