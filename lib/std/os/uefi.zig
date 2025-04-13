const std = @import("../std.zig");

/// A protocol is an interface identified by a GUID.
pub const protocol = @import("uefi/protocol.zig");
pub const DevicePath = @import("uefi/device_path.zig").DevicePath;
pub const hii = @import("uefi/hii.zig");

/// Status codes returned by EFI interfaces
pub const Status = @import("uefi/status.zig").Status;
pub const Error = UnexpectedError || Status.Error;
pub const tables = @import("uefi/tables.zig");

/// The memory type to allocate when using the pool.
/// Defaults to `.loader_data`, the default data allocation type
/// used by UEFI applications to allocate pool memory.
pub var efi_pool_memory_type: tables.MemoryType = .loader_data;
pub const pool_allocator = @import("uefi/pool_allocator.zig").pool_allocator;
pub const raw_pool_allocator = @import("uefi/pool_allocator.zig").raw_pool_allocator;

/// The EFI image's handle that is passed to its entry point.
pub var handle: Handle = undefined;

/// A pointer to the EFI System Table that is passed to the EFI image's entry point.
pub var system_table: *tables.SystemTable = undefined;

/// UEFI's memory interfaces exclusively act on 4096-byte pages.
pub const Page = [4096]u8;

/// A handle to an event structure.
pub const Event = *opaque {};

pub const EventRegistration = *const anyopaque;

pub const EventType = packed struct(u32) {
    lo_context: u8 = 0,
    /// If an event of this type is not already in the signaled state, then
    /// the event’s NotificationFunction will be queued at the event’s NotifyTpl
    /// whenever the event is being waited on via EFI_BOOT_SERVICES.WaitForEvent()
    /// or EFI_BOOT_SERVICES.CheckEvent() .
    wait: bool = false,
    /// The event’s NotifyFunction is queued whenever the event is signaled.
    signal: bool = false,
    hi_context: u20 = 0,
    /// The event is allocated from runtime memory. If an event is to be signaled
    /// after the call to EFI_BOOT_SERVICES.ExitBootServices() the event’s data
    /// structure and notification function need to be allocated from runtime
    /// memory.
    runtime: bool = false,
    timer: bool = false,

    /// This event should not be combined with any other event types. This event
    /// type is functionally equivalent to the EFI_EVENT_GROUP_EXIT_BOOT_SERVICES
    /// event group.
    pub const signal_exit_boot_services: EventType = .{
        .signal = true,
        .lo_context = 1,
    };

    /// The event is to be notified by the system when SetVirtualAddressMap()
    /// is performed. This event type is a composite of EVT_NOTIFY_SIGNAL,
    /// EVT_RUNTIME, and EVT_RUNTIME_CONTEXT and should not be combined with
    /// any other event types.
    pub const signal_virtual_address_change: EventType = .{
        .runtime = true,
        .hi_context = 0x20000,
        .signal = true,
        .lo_context = 2,
    };
};

/// The calling convention used for all external functions part of the UEFI API.
pub const cc: std.builtin.CallingConvention = switch (@import("builtin").target.cpu.arch) {
    .x86_64 => .{ .x86_64_win = .{} },
    else => .c,
};

pub const MacAddress = extern struct {
    address: [32]u8,
};

pub const Ipv4Address = extern struct {
    address: [4]u8,
};

pub const Ipv6Address = extern struct {
    address: [16]u8,
};

pub const IpAddress = extern union {
    v4: Ipv4Address,
    v6: Ipv6Address,
};

/// GUIDs are align(8) unless otherwise specified.
pub const Guid = extern struct {
    time_low: u32 align(8),
    time_mid: u16,
    time_high_and_version: u16,
    clock_seq_high_and_reserved: u8,
    clock_seq_low: u8,
    node: [6]u8,

    /// Format GUID into hexadecimal lowercase xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx format
    pub fn format(
        self: Guid,
        comptime f: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = options;
        if (f.len == 0) {
            const fmt = std.fmt.fmtSliceHexLower;

            const time_low = @byteSwap(self.time_low);
            const time_mid = @byteSwap(self.time_mid);
            const time_high_and_version = @byteSwap(self.time_high_and_version);

            return std.fmt.format(writer, "{:0>8}-{:0>4}-{:0>4}-{:0>2}{:0>2}-{:0>12}", .{
                fmt(std.mem.asBytes(&time_low)),
                fmt(std.mem.asBytes(&time_mid)),
                fmt(std.mem.asBytes(&time_high_and_version)),
                fmt(std.mem.asBytes(&self.clock_seq_high_and_reserved)),
                fmt(std.mem.asBytes(&self.clock_seq_low)),
                fmt(std.mem.asBytes(&self.node)),
            });
        } else {
            std.fmt.invalidFmtError(f, self);
        }
    }

    pub fn eql(a: Guid, b: Guid) bool {
        return a.time_low == b.time_low and
            a.time_mid == b.time_mid and
            a.time_high_and_version == b.time_high_and_version and
            a.clock_seq_high_and_reserved == b.clock_seq_high_and_reserved and
            a.clock_seq_low == b.clock_seq_low and
            std.mem.eql(u8, &a.node, &b.node);
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
    daylight: packed struct(u8) {
        /// If true, the time has been adjusted for daylight savings time.
        in_daylight: bool,

        /// If true, the time is affected by daylight savings time.
        adjust_daylight: bool,

        _: u6,
    },

    _pad2: u8,

    comptime {
        std.debug.assert(@sizeOf(Time) == 16);
    }

    /// Time is to be interpreted as local time
    pub const unspecified_timezone: i16 = 0x7ff;

    fn daysInYear(year: u16, max_month: u4) u9 {
        var days: u9 = 0;
        var month: u4 = 0;
        while (month < max_month) : (month += 1) {
            days += std.time.epoch.getDaysInMonth(year, @enumFromInt(month + 1));
        }
        return days;
    }

    pub fn toEpoch(self: std.os.uefi.Time) u64 {
        var year: u16 = 0;
        var days: u32 = 0;

        while (year < (self.year - 1971)) : (year += 1) {
            days += daysInYear(year + 1970, 12);
        }

        days += daysInYear(self.year, @as(u4, @intCast(self.month)) - 1) + self.day;
        const hours: u64 = self.hour + (days * 24);
        const minutes: u64 = self.minute + (hours * 60);
        const seconds: u64 = self.second + (minutes * std.time.s_per_min);
        return self.nanosecond + (seconds * std.time.ns_per_s);
    }
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

test "GUID formatting" {
    const bytes = [_]u8{ 137, 60, 203, 50, 128, 128, 124, 66, 186, 19, 80, 73, 135, 59, 194, 135 };
    const guid: Guid = @bitCast(bytes);

    const str = try std.fmt.allocPrint(std.testing.allocator, "{}", .{guid});
    defer std.testing.allocator.free(str);

    try std.testing.expect(std.mem.eql(u8, str, "32cb3c89-8080-427c-ba13-5049873bc287"));
}

test {
    _ = tables;
    _ = protocol;
}

pub const UnexpectedError = error{Unexpected};

pub fn unexpectedStatus(status: Status) UnexpectedError {
    // TODO: debug printing the encountered error? maybe handle warnings?
    _ = status;
    return error.Unexpected;
}
