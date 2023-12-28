const std = @import("../../std.zig");

const time = std.time;

/// The calling convention used for all external functions part of the UEFI API.
pub const cc = switch (@import("builtin").target.cpu.arch) {
    .x86_64 => .Win64,
    else => .C,
};

/// A pointer in physical address space.
pub const PhysicalAddress = u64;

/// A pointer in virtual address space.
pub const VirtualAddress = u64;

/// A logical block address
pub const LogicalBlockAddress = u64;

/// An EFI Handle represents a collection of related interfaces.
pub const Handle = *const opaque {};

/// A handle to an event structure.
pub const Event = *const opaque {};

/// File Handle as specified in the EFI Shell Spec
pub const FileHandle = *const opaque {};

pub const Crc32 = std.hash.crc.Crc32IsoHdlc;

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

    /// Returns the time in seconds since 1900-01-01 00:00:00.
    pub fn toEpochSeconds(self: Time) u64 {
        var year: u16 = 1900;
        var days: u32 = 0;

        while (year < self.year) : (year += 1) {
            days += time.epoch.getDaysInYear(year);
        }

        var month: u8 = 1;
        while (month < self.month) : (month += 1) {
            const leap_kind: time.epoch.YearLeapKind = if (time.epoch.isLeapYear(self.year)) .leap else .not_leap;

            days += time.epoch.getDaysInMonth(leap_kind, @enumFromInt(month));
        }

        days += self.day - 1;

        return days * time.s_per_day +
            @as(u32, self.hour) * time.s_per_hour +
            @as(u16, self.minute) * time.s_per_min +
            self.second;
    }

    /// Returns the time in nanoseconds since 1900-01-01 00:00:00.
    pub fn toEpochNanoseconds(self: Time) u128 {
        return @as(u128, self.toEpochSeconds()) * time.ns_per_s + self.nanosecond;
    }

    /// Returns the time in nanoseconds since 1970-01-01 00:00:00, or null if the time does not fit.
    pub fn toUnixEpochNanoseconds(self: Time) ?u64 {
        const nanoseconds = self.toEpochNanoseconds();

        if (nanoseconds < time.epoch.unix_epoch_nanoseconds) {
            return null;
        }

        const unix = nanoseconds - time.epoch.unix_epoch_nanoseconds;
        if (unix > std.math.maxInt(u64)) {
            return null;
        }

        return @intCast(unix);
    }

    pub const unix_epoch = Time{
        .year = 1970,
        .month = 1,
        .day = 1,
        .hour = 0,
        .minute = 0,
        .second = 0,
        .nanosecond = 0,
        .timezone = 0,
        .daylight = .{ .in_daylight = false, .adjust_daylight = false },
    };

    pub const unix_epoch_nanoseconds = unix_epoch.toEpochNanoseconds();
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

pub const MemoryDescriptor = extern struct {
    pub const Type = enum(u32) {
        /// Not usable.
        reserved,

        /// The code portions of a loaded application.
        loader_code,

        /// The data portions of a loaded application and the default data allocation type used by an application to
        /// allocate pool memory.
        loader_data,

        /// The code portions of a loaded Boot Services Driver.
        boot_services_code,

        /// The data portions of a loaded Boot Services Driver, and the default data allocation type used by a Boot
        /// Services Driver to allocate pool memory.
        boot_services_data,

        /// The code portions of a loaded Runtime Services Driver.
        runtime_services_code,

        /// The data portions of a loaded Runtime Services Driver and the default data allocation type used by a Runtime
        /// Services Driver to allocate pool memory.
        runtime_services_data,

        /// Free (unallocated) memory.
        conventional,

        /// Memory in which errors have been detected.
        unusable,

        /// Memory that holds the ACPI tables.
        acpi_reclaim,

        /// Address space reserved for use by the firmware.
        acpi_nvs,

        /// Used by system firmware to request that a memory-mapped IO region be mapped by the OS to a virtual address so
        /// it can be accessed by EFI runtime services.
        memory_mapped_io,

        /// System memory-mapped IO region that is used to translate memory cycles to IO cycles by the processor.
        memory_mapped_io_port_space,

        /// Address space reserved by the firmware for code that is part of the processor.
        pal_code,

        /// A memory region that operates as `conventional`, but additionally supports byte-addressable non-volatility.
        persistent,

        /// A memory region that represents unaccepted memory that must be accepted by the boot target before it can be used.
        /// For platforms that support unaccepted memory, all unaccepted valid memory will be reported in the memory map.
        /// Unreported memory addresses must be treated as non-present memory.
        unaccepted,

        _,
    };

    pub const Attribute = packed struct(u64) {
        /// The memory region supports being configured as not cacheable.
        non_cacheable: bool,

        /// The memory region supports being configured as write combining.
        write_combining: bool,

        /// The memory region supports being configured as cacheable with a "write-through". Writes that hit in the cache
        /// will also be written to main memory.
        write_through: bool,

        /// The memory region supports being configured as cacheable with a "write-back". Reads and writes that hit in the
        /// cache do not propagate to main memory. Dirty data is written back to main memory when a new cache line is
        /// allocated.
        write_back: bool,

        /// The memory region supports being configured as not cacheable, exported, and supports the "fetch and add"
        /// semaphore mechanism.
        non_cacheable_exported: bool,

        _pad1: u7 = 0,

        /// The memory region supports being configured as write-protected by system hardware. This is typically used as a
        /// cacheability attribute today. The memory region supports being configured as cacheable with a "write protected"
        /// policy. Reads come from cache lines when possible, and read misses cause cache fills. Writes are propagated to
        /// the system bus and cause corresponding cache lines on all processors to be invalidated.
        write_protect: bool,

        /// The memory region supports being configured as read-protected by system hardware.
        read_protect: bool,

        /// The memory region supports being configured so it is protected by system hardware from executing code.
        execute_protect: bool,

        /// The memory region refers to persistent memory.
        non_volatile: bool,

        /// The memory region provides higher reliability relative to other memory in the system. If all memory has the same
        /// reliability, then this bit is not used.
        more_reliable: bool,

        /// The memory region supports making this memory range read-only by system hardware.
        read_only: bool,

        /// The memory region is earmarked for specific purposes such as for specific device drivers or applications. This
        /// attribute serves as a hint to the OS to avoid allocation this memory for core OS data or code that cannot be
        /// relocated. Prolonged use of this memory for purposes other than the intended purpose may result in suboptimal
        /// platform performance.
        specific_purpose: bool,

        /// The memory region is capable of being protected with the CPU's memory cryptographic capabilities.
        cpu_crypto: bool,

        _pad2: u24 = 0,

        /// When `memory_isa_valid` is set, this field contains ISA specific cacheability attributes not covered above.
        memory_isa: u16,

        _pad3: u2 = 0,

        /// If set, then `memory_isa` is valid.
        memory_isa_valid: bool,

        /// This memory must be given a virtual mapping by the operating system when `setVirtualAddressMap()` is called.
        memory_runtime: bool,
    };

    pub const revision: u32 = 1;

    type: Type,
    physical_start: PhysicalAddress,
    virtual_start: VirtualAddress,
    number_of_pages: u64,
    attribute: Attribute,
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

    pub fn eql(a: Guid, b: Guid) bool {
        return a.time_low == b.time_low and
            a.time_mid == b.time_mid and
            a.time_high_and_version == b.time_high_and_version and
            a.clock_seq_high_and_reserved == b.clock_seq_high_and_reserved and
            a.clock_seq_low == b.clock_seq_low and
            std.mem.eql(u8, &a.node, &b.node);
    }

    test format {
        const bytes = [_]u8{ 137, 60, 203, 50, 128, 128, 124, 66, 186, 19, 80, 73, 135, 59, 194, 135 };
        const guid: Guid = @bitCast(bytes);

        const str = try std.fmt.allocPrint(std.testing.allocator, "{}", .{guid});
        defer std.testing.allocator.free(str);

        try std.testing.expect(std.mem.eql(u8, str, "32cb3c89-8080-427c-ba13-5049873bc287"));
    }
};

pub const Parity = enum(u8) {
    default = 0,
    none = 1,
    even = 2,
    odd = 3,
    mark = 4,
    space = 5,
};

pub const StopBits = enum(u8) {
    default = 0,
    one = 1,
    one_and_half = 2,
    two = 3,
    _,
};

/// Provides generic file information.
pub const FileInfo = extern struct {
    size: u64,

    /// The size of the file in bytes.
    file_size: u64,

    /// The amount of physical space the file consumes of the file system volume.
    physical_size: u64,

    /// The time the file was created.
    create_time: Time,

    /// The time the file was last accessed.
    last_access_time: Time,

    /// The time the file's contents were last modified.
    modification_time: Time,

    /// The attributes of the file.
    attribute: Attributes,

    /// The null-terminated name of the file. For the root directory, this is an empty string.
    pub fn getFileName(self: *const FileInfo) [:0]const u16 {
        const ptr: [*:0]const u16 = @ptrCast(self);
        const file_name = ptr + @divExact(@sizeOf(FileInfo), 2);

        return std.mem.span(file_name);
    }

    /// The attributes of a file.
    pub const Attributes = packed struct(u64) {
        read_only: bool = true,
        hidden: bool = false,
        system: bool = false,
        reserved: bool = false,
        directory: bool = false,
        archive: bool = false,

        _pad: u58 = 0,
    };

    pub const guid align(8) = Guid{
        .time_low = 0x09576e92,
        .time_mid = 0x6d3f,
        .time_high_and_version = 0x11d2,
        .clock_seq_high_and_reserved = 0x8e,
        .clock_seq_low = 0x39,
        .node = [_]u8{ 0x00, 0xa0, 0xc9, 0x69, 0x72, 0x3b },
    };
};

/// Provides information about the system volume and volume label.
pub const FileSystemInfo = extern struct {
    size: u64,

    /// If true, the file system is read-only.
    read_only: bool,

    /// The number of bytes managed by the file system.
    volume_size: u64,

    /// The number of available bytes for use by the file system.
    free_space: u64,

    /// The nominal block size by which files are typically grown.
    block_size: u32,

    /// The null-terminated string that is the volume's label.
    pub fn getVolumeLabel(self: *const FileSystemInfo) [:0]const u16 {
        const ptr: [*:0]const u16 = @ptrCast(self);
        const file_name = ptr + @divExact(@sizeOf(FileSystemInfo), 2);

        return std.mem.span(file_name);
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

/// Provides information about the volume label. Can safely be cast to and from `[*:0]const u16`.
pub const FileSystemVolumeLabel = extern struct {
    /// The null-terminated string that is the volume's label.
    pub fn getVolumeLabel(self: *const FileSystemVolumeLabel) [:0]const u16 {
        const ptr: [*:0]const u16 = @ptrCast(self);

        return std.mem.span(ptr);
    }

    pub const guid align(8) = Guid{
        .time_low = 0xdb47d7d3,
        .time_mid = 0xfe81,
        .time_high_and_version = 0x11d3,
        .clock_seq_high_and_reserved = 0x9a,
        .clock_seq_low = 0x35,
        .node = [_]u8{ 0x00, 0x90, 0x27, 0x3f, 0xc1, 0x4d },
    };
};
