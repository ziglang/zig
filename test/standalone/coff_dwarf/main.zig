const std = @import("std");
const fatal = std.process.fatal;

extern fn add(a: u32, b: u32, addr: *usize) u32;

pub fn main() void {
    var debug_alloc_inst: std.heap.DebugAllocator(.{}) = .init;
    defer std.debug.assert(debug_alloc_inst.deinit() == .ok);
    const gpa = debug_alloc_inst.allocator();

    var di: std.debug.SelfInfo = .init;
    defer di.deinit(gpa);

    var add_addr: usize = undefined;
    _ = add(1, 2, &add_addr);

    const symbol = di.getSymbol(gpa, add_addr) catch |err| fatal("failed to get symbol: {t}", .{err});
    defer if (symbol.source_location) |sl| gpa.free(sl.file_name);

    if (symbol.name == null) fatal("failed to resolve symbol name", .{});
    if (symbol.compile_unit_name == null) fatal("failed to resolve compile unit", .{});
    if (symbol.source_location == null) fatal("failed to resolve source location", .{});

    if (!std.mem.eql(u8, symbol.name.?, "add")) {
        fatal("incorrect symbol name '{s}'", .{symbol.name.?});
    }
    const sl = &symbol.source_location.?;
    if (!std.mem.eql(u8, std.fs.path.basename(sl.file_name), "shared_lib.c")) {
        fatal("incorrect file name '{s}'", .{sl.file_name});
    }
    if (sl.line != 3 or sl.column != 0) {
        fatal("incorrect line/column :{d}:{d}", .{ sl.line, sl.column });
    }
}
