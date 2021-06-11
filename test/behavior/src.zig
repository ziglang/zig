const std = @import("std");
const expect = std.testing.expect;

test "@src" {
    try doTheTest();
}

fn doTheTest() !void {
    const src = @src();

    try expect(src.line == 9);
    try expect(src.column == 17);
    try expect(std.mem.endsWith(u8, src.fn_name, "doTheTest"));
    try expect(std.mem.endsWith(u8, src.file, "src.zig"));
    try expect(src.fn_name[src.fn_name.len] == 0);
    try expect(src.file[src.file.len] == 0);
}
