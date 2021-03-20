//! Misc utility functions for creating a `SymbolMap` for `std.debug`
//! TODO: better name for this file?

const std = @import("std.zig");
const SymbolInfo = std.debug.SymbolInfo;
const mem = std.mem;
const DW = std.dwarf;

pub fn SymbolMapFromModuleInfo(Module: type) type {
    return struct {
        const Self = @This();

        pub const AddressMap = std.AutoHashMap(usize, *Module);

        allocator: *mem.Allocator,
        address_map: AddressMap,

        pub fn init(allocator: *mem.Allocator) DebugInfo {
            return DebugInfo{
                .allocator = allocator,
                .address_map = std.AutoHashMap(usize, *Module).init(allocator),
            };
        }

        pub fn deinit(self: *Self) void {
            self.address_map.deinit();
        }

        fn addressToSymbol(self: *Self, address: usize) !SymbolInfo {
            const module = Module.lookup(self.allocator, &self.address_map, address) catch |err|
                return if (std.meta.errorInSet(err, BaseError)) SymbolInfo{} else return err;
            return module.addressToSymbol(address);
        }
    };
}

pub const BaseError = error{
    MissingDebugInfo,
    InvalidDebugInfo,
    UnsupportedOperatingSystem,
};

pub fn chopSlice(ptr: []const u8, offset: u64, size: u64) ![]const u8 {
    const start = try math.cast(usize, offset);
    const end = start + try math.cast(usize, size);
    return ptr[start..end];
}

/// `file` is expected to have been opened with .intended_io_mode == .blocking.
/// Takes ownership of file, even on error.
/// TODO it's weird to take ownership even on error, rework this code.
pub fn mapWholeFile(file: File) ![]align(mem.page_size) const u8 {
    nosuspend {
        defer file.close();

        const file_len = try math.cast(usize, try file.getEndPos());
        const mapped_mem = try os.mmap(
            null,
            file_len,
            os.PROT_READ,
            os.MAP_SHARED,
            file.handle,
            0,
        );
        errdefer os.munmap(mapped_mem);

        return mapped_mem;
    }
}

pub fn dwarfAddressToSymbolInfo(dwarf: *DW.DwarfInfo, relocated_address: usize) !SymbolInfo {
    const compile_unit = nosuspend dwarf.findCompileUnit(relocated_address) catch |err|
        return if (std.meta.errorInSet(err, BaseError)) SymbolInfo{} else err;

    return SymbolInfo{
        .symbol_name = nosuspend dwarf.getSymbolName(relocated_address) orelse "???",
        .compile_unit_name = compile_unit.die.getAttrString(dwarf, DW.AT_name) catch |err|
            if (std.meta.errorInSet(err, BaseError)) "???" else return err,
        .line_info = nosuspend dwarf.getLineNumberInfo(compile_unit.*, relocated_address) catch |err|
            if (std.meta.errorInSet(err, BaseError)) null else return err,
    };
}
