const std = @import("std");
const expect = std.testing.expect;

test "@src" {
    doTheTest();
}

fn doTheTest() void {
    const src = @src();

    expect(src.line == 9);
    expect(src.column == 17);
    expect(std.mem.endsWith(u8, src.fn_name, "doTheTest"));
    expect(std.mem.endsWith(u8, src.file, "src.zig"));
    expect(src.fn_name[src.fn_name.len] == 0);
    expect(src.file[src.file.len] == 0);
}
