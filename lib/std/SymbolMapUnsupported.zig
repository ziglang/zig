//! This is so printing a stack trace on an unsupported platform just prints
//! with empty symbols instead of failing to build. This is important for
//! GeneralPurposeAllocator and similar.
//!
//! To implement actual debug symbols, use `root.debug_config.SymbolMap`
//! or `root.os.debug.SymbolMap`.

const std = @import("std.zig");
const SymbolInfo = std.debug.SymbolInfo;
const mem = std.mem;

const Self = @This();

pub fn init(allocator: *mem.Allocator) Self {
    return .{};
}

pub fn deinit(self: *Self) void {}

fn addressToSymbol(self: *Self, address: usize) !SymbolInfo {
    return SymbolInfo{};
}
