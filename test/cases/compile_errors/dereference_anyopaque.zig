const std = @import("std");

const Error = error{Something};

fn next() Error!void {
    return;
}

fn parse(comptime T: type, allocator: std.mem.Allocator) !void {
    parseFree(T, undefined, allocator);
    _ = (try next()) != null;
}

fn parseFree(comptime T: type, value: T, allocator: std.mem.Allocator) void {
    switch (@typeInfo(T)) {
        .Struct => |structInfo| {
            inline for (structInfo.fields) |field| {
                if (!field.is_comptime)
                    parseFree(field.type, undefined, allocator);
            }
        },
        .Pointer => |ptrInfo| {
            switch (ptrInfo.size) {
                .One => {
                    parseFree(ptrInfo.child, value.*, allocator);
                },
                .Slice => {
                    for (value) |v|
                        parseFree(ptrInfo.child, v, allocator);
                },
                else => unreachable,
            }
        },
        else => unreachable,
    }
}

pub export fn entry() void {
    const allocator = std.testing.failing_allocator;
    _ = parse(std.StringArrayHashMap(bool), allocator) catch return;
}

// error
// target=native
// backend=llvm
//
// :11:22: error: comparison of 'void' with null
// :25:51: error: cannot load opaque type 'anyopaque'
// :25:51: error: values of type 'fn (*anyopaque, usize, u8, usize) ?[*]u8' must be comptime-known, but operand value is runtime-known
// :25:51: note: use '*const fn (*anyopaque, usize, u8, usize) ?[*]u8' for a function pointer type
// :25:51: error: values of type 'fn (*anyopaque, []u8, u8, usize, usize) bool' must be comptime-known, but operand value is runtime-known
// :25:51: note: use '*const fn (*anyopaque, []u8, u8, usize, usize) bool' for a function pointer type
// :25:51: error: values of type 'fn (*anyopaque, []u8, u8, usize) void' must be comptime-known, but operand value is runtime-known
// :25:51: note: use '*const fn (*anyopaque, []u8, u8, usize) void' for a function pointer type
