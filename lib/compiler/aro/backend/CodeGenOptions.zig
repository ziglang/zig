const std = @import("std");

/// place uninitialized global variables in a common block
common: bool,
/// Place each function into its own section in the output file if the target supports arbitrary sections
func_sections: bool,
/// Place each data item into its own section in the output file if the target supports arbitrary sections
data_sections: bool,
pic_level: PicLevel,
/// Generate position-independent code that can only be linked into executables
is_pie: bool,
optimization_level: OptimizationLevel,
/// Generate debug information
debug: DebugFormat,
dwarf_version: DwarfVersion,

pub const DebugFormat = union(enum) {
    strip,
    dwarf: std.dwarf.Format,
    code_view,
};

pub const DwarfVersion = enum(u3) {
    @"0" = 0,
    @"2" = 2,
    @"3" = 3,
    @"4" = 4,
    @"5" = 5,
};

pub const PicLevel = enum(u8) {
    /// Do not generate position-independent code
    none = 0,
    /// Generate position-independent code (PIC) suitable for use in a shared library, if supported for the target machine.
    one = 1,
    /// If supported for the target machine, emit position-independent code, suitable for dynamic linking and avoiding
    /// any limit on the size of the global offset table.
    two = 2,
};

pub const OptimizationLevel = enum {
    @"0",
    @"1",
    @"2",
    @"3",
    /// Optimize for size
    s,
    /// Disregard strict standards compliance
    fast,
    /// Optimize debugging experience
    g,
    /// Optimize aggressively for size rather than speed
    z,

    const level_map = std.StaticStringMap(OptimizationLevel).initComptime(.{
        .{ "0", .@"0" },
        .{ "1", .@"1" },
        .{ "2", .@"2" },
        .{ "3", .@"3" },
        .{ "s", .s },
        .{ "fast", .fast },
        .{ "g", .g },
        .{ "z", .z },
    });

    pub fn fromString(str: []const u8) ?OptimizationLevel {
        return level_map.get(str);
    }

    pub fn isSizeOptimized(self: OptimizationLevel) bool {
        return switch (self) {
            .s, .z => true,
            .@"0", .@"1", .@"2", .@"3", .fast, .g => false,
        };
    }

    pub fn hasAnyOptimizations(self: OptimizationLevel) bool {
        return switch (self) {
            .@"0" => false,
            .@"1", .@"2", .@"3", .s, .fast, .g, .z => true,
        };
    }
};

pub const default: @This() = .{
    .common = false,
    .func_sections = false,
    .data_sections = false,
    .pic_level = .none,
    .is_pie = false,
    .optimization_level = .@"0",
    .debug = .strip,
    .dwarf_version = .@"0",
};
