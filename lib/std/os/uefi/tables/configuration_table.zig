// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const uefi = @import("std").os.uefi;
const Guid = uefi.Guid;

pub const ConfigurationTable = extern struct {
    vendor_guid: Guid,
    vendor_table: *c_void,

    pub const acpi_20_table_guid align(8) = Guid{
        .time_low = 0x8868e871,
        .time_mid = 0xe4f1,
        .time_high_and_version = 0x11d3,
        .clock_seq_high_and_reserved = 0xbc,
        .clock_seq_low = 0x22,
        .node = [_]u8{ 0x00, 0x80, 0xc7, 0x3c, 0x88, 0x81 },
    };
    pub const acpi_10_table_guid align(8) = Guid{
        .time_low = 0xeb9d2d30,
        .time_mid = 0x2d88,
        .time_high_and_version = 0x11d3,
        .clock_seq_high_and_reserved = 0x9a,
        .clock_seq_low = 0x16,
        .node = [_]u8{ 0x00, 0x90, 0x27, 0x3f, 0xc1, 0x4d },
    };
    pub const sal_system_table_guid align(8) = Guid{
        .time_low = 0xeb9d2d32,
        .time_mid = 0x2d88,
        .time_high_and_version = 0x113d,
        .clock_seq_high_and_reserved = 0x9a,
        .clock_seq_low = 0x16,
        .node = [_]u8{ 0x00, 0x90, 0x27, 0x3f, 0xc1, 0x4d },
    };
    pub const smbios_table_guid align(8) = Guid{
        .time_low = 0xeb9d2d31,
        .time_mid = 0x2d88,
        .time_high_and_version = 0x11d3,
        .clock_seq_high_and_reserved = 0x9a,
        .clock_seq_low = 0x16,
        .node = [_]u8{ 0x00, 0x90, 0x27, 0x3f, 0xc1, 0x4d },
    };
    pub const smbios3_table_guid align(8) = Guid{
        .time_low = 0xf2fd1544,
        .time_mid = 0x9794,
        .time_high_and_version = 0x4a2c,
        .clock_seq_high_and_reserved = 0x99,
        .clock_seq_low = 0x2e,
        .node = [_]u8{ 0xe5, 0xbb, 0xcf, 0x20, 0xe3, 0x94 },
    };
    pub const mps_table_guid align(8) = Guid{
        .time_low = 0xeb9d2d2f,
        .time_mid = 0x2d88,
        .time_high_and_version = 0x11d3,
        .clock_seq_high_and_reserved = 0x9a,
        .clock_seq_low = 0x16,
        .node = [_]u8{ 0x00, 0x90, 0x27, 0x3f, 0xc1, 0x4d },
    };
    pub const json_config_data_table_guid align(8) = Guid{
        .time_low = 0x87367f87,
        .time_mid = 0x1119,
        .time_high_and_version = 0x41ce,
        .clock_seq_high_and_reserved = 0xaa,
        .clock_seq_low = 0xec,
        .node = [_]u8{ 0x8b, 0xe0, 0x11, 0x1f, 0x55, 0x8a },
    };
    pub const json_capsule_data_table_guid align(8) = Guid{
        .time_low = 0x35e7a725,
        .time_mid = 0x8dd2,
        .time_high_and_version = 0x4cac,
        .clock_seq_high_and_reserved = 0x80,
        .clock_seq_low = 0x11,
        .node = [_]u8{ 0x33, 0xcd, 0xa8, 0x10, 0x90, 0x56 },
    };
    pub const json_capsule_result_table_guid align(8) = Guid{
        .time_low = 0xdbc461c3,
        .time_mid = 0xb3de,
        .time_high_and_version = 0x422a,
        .clock_seq_high_and_reserved = 0xb9,
        .clock_seq_low = 0xb4,
        .node = [_]u8{ 0x98, 0x86, 0xfd, 0x49, 0xa1, 0xe5 },
    };
};
