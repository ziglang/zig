const uefi = @import("std").os.uefi;
const Guid = uefi.Guid;
const TableHeader = uefi.tables.TableHeader;
const Time = uefi.Time;
const TimeCapabilities = uefi.TimeCapabilities;

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
    getTime: extern fn (*uefi.Time, ?*TimeCapabilities) usize,

    setTime: usize, // TODO
    getWakeupTime: usize, // TODO
    setWakeupTime: usize, // TODO
    setVirtualAddressMap: usize, // TODO
    convertPointer: usize, // TODO

    /// Returns the value of a variable.
    getVariable: extern fn ([*:0]const u16, *align(8) const Guid, ?*u32, *usize, ?*c_void) usize,

    /// Enumerates the current variable names.
    getNextVariableName: extern fn (*usize, [*]u16, *align(8) Guid) usize,

    /// Sets the value of a variable.
    setVariable: extern fn ([*:0]const u16, *align(8) const Guid, u32, usize, *c_void) usize,

    getNextHighMonotonicCount: usize, // TODO

    /// Resets the entire platform.
    resetSystem: extern fn (ResetType, usize, usize, ?*const c_void) noreturn,

    updateCapsule: usize, // TODO
    queryCapsuleCapabilities: usize, // TODO
    queryVariableInfo: usize, // TODO

    pub const signature: u64 = 0x56524553544e5552;
};

pub const ResetType = extern enum(u32) {
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
