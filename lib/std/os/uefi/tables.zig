// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
pub const AllocateType = @import("tables/boot_services.zig").AllocateType;
pub const BootServices = @import("tables/boot_services.zig").BootServices;
pub const ConfigurationTable = @import("tables/configuration_table.zig").ConfigurationTable;
pub const global_variable align(8) = @import("tables/runtime_services.zig").global_variable;
pub const LocateSearchType = @import("tables/boot_services.zig").LocateSearchType;
pub const MemoryDescriptor = @import("tables/boot_services.zig").MemoryDescriptor;
pub const MemoryType = @import("tables/boot_services.zig").MemoryType;
pub const OpenProtocolAttributes = @import("tables/boot_services.zig").OpenProtocolAttributes;
pub const ProtocolInformationEntry = @import("tables/boot_services.zig").ProtocolInformationEntry;
pub const ResetType = @import("tables/runtime_services.zig").ResetType;
pub const RuntimeServices = @import("tables/runtime_services.zig").RuntimeServices;
pub const SystemTable = @import("tables/system_table.zig").SystemTable;
pub const TableHeader = @import("tables/table_header.zig").TableHeader;
pub const TimerDelay = @import("tables/boot_services.zig").TimerDelay;
