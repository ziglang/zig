const expect = @import("std").testing.expect;
const builtin = @import("builtin");

fn a(b: []u3, c: u3) void {
    switch (c) {
        0...1 => b[c] = c,
        2...3 => b[c] = c,
        4...7 => |d| b[d] = c,
    }
}
test {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    var arr: [8]u3 = undefined;
    a(&arr, 5);
    try expect(arr[5] == 5);
}
