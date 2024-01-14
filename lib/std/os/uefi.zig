const std = @import("../std.zig");

/// A protocol is an interface identified by a GUID.
pub const protocol = @import("uefi/protocol.zig");
pub const DevicePath = @import("uefi/device_path.zig").DevicePath;
pub const hii = @import("uefi/hii.zig");

/// Status codes returned by EFI interfaces
pub const Status = @import("uefi/status.zig").Status;
pub const tables = @import("uefi/tables.zig");

/// The memory type to allocate when using the pool
/// Defaults to .LoaderData, the default data allocation type
/// used by UEFI applications to allocate pool memory.
pub var efi_pool_memory_type: tables.MemoryType = .LoaderData;
pub const pool_allocator = @import("uefi/pool_allocator.zig").pool_allocator;
pub const raw_pool_allocator = @import("uefi/pool_allocator.zig").raw_pool_allocator;

/// The EFI image's handle that is passed to its entry point.
pub var handle: Handle = undefined;

/// A pointer to the EFI System Table that is passed to the EFI image's entry point.
pub var system_table: *tables.SystemTable = undefined;

/// A handle to an event structure.
pub const Event = *opaque {};

/// The calling convention used for all external functions part of the UEFI API.
pub const cc = switch (@import("builtin").target.cpu.arch) {
    .x86_64 => .Win64,
    else => .C,
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

/// GUIDs are align(8) unless otherwise specified.
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

    pub fn eql(a: std.os.uefi.Guid, b: std.os.uefi.Guid) bool {
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

    /// Time is to be interpreted as local time
    pub const unspecified_timezone: i16 = 0x7ff;

    fn daysInYear(year: u16, maxMonth: u4) u32 {
        const leapYear: std.time.epoch.YearLeapKind = if (std.time.epoch.isLeapYear(year)) .leap else .not_leap;
        var days: u32 = 0;
        var month: u4 = 0;
        while (month < maxMonth) : (month += 1) {
            days += std.time.epoch.getDaysInMonth(leapYear, @enumFromInt(month + 1));
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
        const hours = self.hour + (days * 24);
        const minutes = self.minute + (hours * 60);
        const seconds = self.second + (minutes * std.time.s_per_min);
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

pub const FileInfo = extern struct {
    size: u64,
    file_size: u64,
    physical_size: u64,
    create_time: Time,
    last_access_time: Time,
    modification_time: Time,
    attribute: u64,

    pub fn getFileName(self: *const FileInfo) [*:0]const u16 {
        return @ptrCast(@alignCast(@as([*]const u8, @ptrCast(self)) + @sizeOf(FileInfo)));
    }

    pub const efi_file_read_only: u64 = 0x0000000000000001;
    pub const efi_file_hidden: u64 = 0x0000000000000002;
    pub const efi_file_system: u64 = 0x0000000000000004;
    pub const efi_file_reserved: u64 = 0x0000000000000008;
    pub const efi_file_directory: u64 = 0x0000000000000010;
    pub const efi_file_archive: u64 = 0x0000000000000020;
    pub const efi_file_valid_attr: u64 = 0x0000000000000037;

    pub const guid align(8) = Guid{
        .time_low = 0x09576e92,
        .time_mid = 0x6d3f,
        .time_high_and_version = 0x11d2,
        .clock_seq_high_and_reserved = 0x8e,
        .clock_seq_low = 0x39,
        .node = [_]u8{ 0x00, 0xa0, 0xc9, 0x69, 0x72, 0x3b },
    };
};

pub const FileSystemInfo = extern struct {
    size: u64,
    read_only: bool,
    volume_size: u64,
    free_space: u64,
    block_size: u32,
    _volume_label: u16,

    pub fn getVolumeLabel(self: *const FileSystemInfo) [*:0]const u16 {
        return @as([*:0]const u16, @ptrCast(&self._volume_label));
    }

    pub const guid align(8) = Guid{
        .time_low = 0x09576e93,
        .time_mid = 0x6d3f,
        .time_high_and_version = 0x11d2,
        .clock_seq_high_and_reserved = 0x8e,
        .clock_seq_low = 0x39,
        .node = [_]u8{ 0x00, 0xa0, 0xc9, 0x69, 0x72, 0x3b },
    };
};

test {
    _ = tables;
    _ = protocol;
}
