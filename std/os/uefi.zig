pub const protocols = @import("uefi/protocols.zig");
pub const status = @import("uefi/status.zig");
pub const tables = @import("uefi/tables.zig");

const builtin = @import("builtin");
pub const is_the_target = builtin.os == .uefi;

pub var handle: Handle = undefined;
pub var system_table: *tables.SystemTable = undefined;

pub const Event = *@OpaqueType();
// GUIDs must be align(8)
pub const Guid = extern struct {
    time_low: u32,
    time_mid: u16,
    time_high_and_version: u16,
    clock_seq_high_and_reserved: u8,
    clock_seq_low: u8,
    node: [6]u8,
};
pub const Handle = *@OpaqueType();
pub const Time = extern struct {
    year: u16,
    month: u8,
    day: u8,
    hour: u8,
    minute: u8,
    second: u8,
    _pad1: u8,
    nanosecond: u32,
    timezone: i16,
    daylight: packed struct {
        _pad1: u6,
        in_daylight: bool,
        adjust_daylight: bool,
    },
    _pad2: u8,

    pub const unspecified_timezone: i16 = 0x7ff;
};
pub const TimeCapabilities = extern struct {
    resolution: u32,
    accuracy: u32,
    sets_to_zero: bool,
};
