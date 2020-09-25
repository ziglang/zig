// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
/// A protocol is an interface identified by a GUID.
pub const protocols = @import("uefi/protocols.zig");

/// Status codes returned by EFI interfaces
pub const Status = @import("uefi/status.zig").Status;
pub const tables = @import("uefi/tables.zig");

/// The EFI image's handle that is passed to its entry point.
pub var handle: Handle = undefined;

/// A pointer to the EFI System Table that is passed to the EFI image's entry point.
pub var system_table: *tables.SystemTable = undefined;

/// A handle to an event structure.
pub const Event = *opaque {};

/// GUIDs must be align(8)
pub const Guid = extern struct {
    time_low: u32,
    time_mid: u16,
    time_high_and_version: u16,
    clock_seq_high_and_reserved: u8,
    clock_seq_low: u8,
    node: [6]u8,

    /// Format GUID into hexadecimal lowercase xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx format
    pub fn format(
        self: @This(),
        comptime f: []const u8,
        options: std.fmt.FormatOptions,
        out_stream: anytype,
    ) Errors!void {
        if (f.len == 0) {
            return std.fmt.format(out_stream, "{x:0>8}-{x:0>4}-{x:0>4}-{x:0>2}{x:0>2}-{x:0>12}", .{
                self.time_low,
                self.time_mid,
                self.time_high_and_version,
                self.clock_seq_high_and_reserved,
                self.clock_seq_low,
                self.node,
            });
        } else {
            @compileError("Unknown format character: '" ++ f ++ "'");
        }
    }
};

/// An EFI Handle represents a collection of related interfaces.
pub const Handle = *opaque {};

/// This structure represents time information.
pub const Time = extern struct {
    /// 1900 - 9999
    year: u16,

    /// 1 - 12
    month: u8,

    /// 1 - 31
    day: u8,

    /// 0 - 23
    hour: u8,

    /// 0 - 59
    minute: u8,

    /// 0 - 59
    second: u8,
    _pad1: u8,

    /// 0 - 999999999
    nanosecond: u32,

    /// The time's offset in minutes from UTC.
    /// Allowed values are -1440 to 1440 or unspecified_timezone
    timezone: i16,
    daylight: packed struct {
        _pad1: u6,

        /// If true, the time has been adjusted for daylight savings time.
        in_daylight: bool,

        /// If true, the time is affected by daylight savings time.
        adjust_daylight: bool,
    },
    _pad2: u8,

    /// Time is to be interpreted as local time
    pub const unspecified_timezone: i16 = 0x7ff;
};

/// Capabilities of the clock device
pub const TimeCapabilities = extern struct {
    /// Resolution in Hz
    resolution: u32,

    /// Accuracy in an error rate of 1e-6 parts per million.
    accuracy: u32,

    /// If true, a time set operation clears the device's time below the resolution level.
    sets_to_zero: bool,
};

/// File Handle as specified in the EFI Shell Spec
pub const FileHandle = *opaque {};
