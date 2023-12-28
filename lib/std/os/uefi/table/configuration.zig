const bits = @import("../bits.zig");

const Guid = bits.Guid;

pub const Configuration = extern struct {
    vendor_guid: Guid,
    vendor_table: *const anyopaque,

    pub const acpi_20_table align(8) = Guid{
        .time_low = 0x8868e871,
        .time_mid = 0xe4f1,
        .time_high_and_version = 0x11d3,
        .clock_seq_high_and_reserved = 0xbc,
        .clock_seq_low = 0x22,
        .node = [_]u8{ 0x00, 0x80, 0xc7, 0x3c, 0x88, 0x81 },
    };

    pub const acpi_10_table align(8) = Guid{
        .time_low = 0xeb9d2d30,
        .time_mid = 0x2d88,
        .time_high_and_version = 0x11d3,
        .clock_seq_high_and_reserved = 0x9a,
        .clock_seq_low = 0x16,
        .node = [_]u8{ 0x00, 0x90, 0x27, 0x3f, 0xc1, 0x4d },
    };

    pub const sal_system_table align(8) = Guid{
        .time_low = 0xeb9d2d32,
        .time_mid = 0x2d88,
        .time_high_and_version = 0x113d,
        .clock_seq_high_and_reserved = 0x9a,
        .clock_seq_low = 0x16,
        .node = [_]u8{ 0x00, 0x90, 0x27, 0x3f, 0xc1, 0x4d },
    };

    pub const smbios_table align(8) = Guid{
        .time_low = 0xeb9d2d31,
        .time_mid = 0x2d88,
        .time_high_and_version = 0x11d3,
        .clock_seq_high_and_reserved = 0x9a,
        .clock_seq_low = 0x16,
        .node = [_]u8{ 0x00, 0x90, 0x27, 0x3f, 0xc1, 0x4d },
    };

    pub const smbios3_table align(8) = Guid{
        .time_low = 0xf2fd1544,
        .time_mid = 0x9794,
        .time_high_and_version = 0x4a2c,
        .clock_seq_high_and_reserved = 0x99,
        .clock_seq_low = 0x2e,
        .node = [_]u8{ 0xe5, 0xbb, 0xcf, 0x20, 0xe3, 0x94 },
    };

    pub const mps_table align(8) = Guid{
        .time_low = 0xeb9d2d2f,
        .time_mid = 0x2d88,
        .time_high_and_version = 0x11d3,
        .clock_seq_high_and_reserved = 0x9a,
        .clock_seq_low = 0x16,
        .node = [_]u8{ 0x00, 0x90, 0x27, 0x3f, 0xc1, 0x4d },
    };

    pub const json_config_data_table align(8) = Guid{
        .time_low = 0x87367f87,
        .time_mid = 0x1119,
        .time_high_and_version = 0x41ce,
        .clock_seq_high_and_reserved = 0xaa,
        .clock_seq_low = 0xec,
        .node = [_]u8{ 0x8b, 0xe0, 0x11, 0x1f, 0x55, 0x8a },
    };

    pub const json_capsule_data_table align(8) = Guid{
        .time_low = 0x35e7a725,
        .time_mid = 0x8dd2,
        .time_high_and_version = 0x4cac,
        .clock_seq_high_and_reserved = 0x80,
        .clock_seq_low = 0x11,
        .node = [_]u8{ 0x33, 0xcd, 0xa8, 0x10, 0x90, 0x56 },
    };

    pub const json_capsule_result_table align(8) = Guid{
        .time_low = 0xdbc461c3,
        .time_mid = 0xb3de,
        .time_high_and_version = 0x422a,
        .clock_seq_high_and_reserved = 0xb9,
        .clock_seq_low = 0xb4,
        .node = [_]u8{ 0x98, 0x86, 0xfd, 0x49, 0xa1, 0xe5 },
    };
};

/// This table should be published by a platform if it no longer supports all EFI runtime services once
/// `exitBootServices()` has been called by the OS. Note that this is merely a hint to the OS, which it is free to
/// ignore, as any unsupported runtime services will return `error.Unsupported` if called.
pub const RtPropertiesTable = extern struct {
    pub const Supported = packed struct(u32) {
        get_time: bool,
        set_time: bool,
        get_wakeup_time: bool,
        set_wakeup_time: bool,
        get_variable: bool,
        get_next_variable_name: bool,
        set_variable: bool,
        set_virtual_address_map: bool,
        convert_pointer: bool,
        get_next_high_monotonic_count: bool,
        reset_system: bool,
        update_capsule: bool,
        query_capsule_capabilities: bool,
        query_variable_info: bool,

        _pad1: u18 = 0,
    };

    /// Version of the table. Must be `1`.
    version: u16 = 0x1,

    /// Length of the table, in bytes. Must be `8`.
    length: u16 = 8,

    /// Bitmask of supported runtime services.
    supported: Supported,

    pub const guid align(8) = Guid{
        .time_low = 0xeb66918a,
        .time_mid = 0x7eef,
        .time_high_and_version = 0x402a,
        .clock_seq_high_and_reserved = 0x84,
        .clock_seq_low = 0x2e,
        .node = [_]u8{ 0x93, 0x1d, 0x21, 0xc3, 0x8a, 0xe9 },
    };
};

/// When published by the firmware, this table provides additional information about regions within the run-time memory
/// blocks defined in `MemoryDescriptor` entries.
pub const MemoryAttributes = extern struct {
    pub const Flags = packed struct(u32) {
        /// Implies that runtime code includes the forward control flow guard instruction.
        rt_forward_cfg: bool,

        _pad1: u31 = 0,
    };

    /// Version of the table. Must be `2`.
    version: u32 = 0x2,

    /// The number of `MemoryDescriptor`s following this table.
    entries: u32,

    /// The size of each `MemoryDescriptor` in bytes.
    descriptor_size: u32,

    flags: Flags,

    /// An iterator over the memory descriptors.
    pub const Iterator = struct {
        table: *const MemoryAttributes,

        /// The current index of the iterator.
        index: usize = 0,

        /// Returns the next memory descriptor in the table.
        pub fn next(iter: *Iterator) ?*bits.MemoryDescriptor {
            if (iter.index >= iter.table.entries)
                return null;

            const offset = iter.index * iter.table.descriptor_size;

            const addr = @intFromPtr(iter.table) + @sizeOf(MemoryAttributes) + offset;
            iter.index += 1;

            return @ptrFromInt(addr);
        }
    };

    /// Returns an iterator over the memory map.
    pub fn iterator(self: *const MemoryAttributes) Iterator {
        return Iterator{ .table = self };
    }

    /// Returns a pointer to the memory descriptor at the given index.
    pub fn at(self: *const MemoryAttributes, index: usize) ?*bits.MemoryDescriptor {
        if (index >= self.entries)
            return null;

        const offset = index * self.descriptor_size;

        const addr = @intFromPtr(self.table) + @sizeOf(self) + offset;
        return @ptrFromInt(addr);
    }

    pub const guid align(8) = Guid{
        .time_low = 0xdcfa911d,
        .time_mid = 0x26eb,
        .time_high_and_version = 0x469f,
        .clock_seq_high_and_reserved = 0xa2,
        .clock_seq_low = 0x20,
        .node = [_]u8{ 0x38, 0xb7, 0xdc, 0x46, 0x12, 0x20 },
    };
};
