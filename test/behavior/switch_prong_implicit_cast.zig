const expect = @import("std").testing.expect;
const builtin = @import("builtin");

const FormValue = union(enum) {
    One: void,
    Two: bool,
};

fn foo(id: u64) !FormValue {
    return switch (id) {
        2 => FormValue{ .Two = true },
        1 => FormValue{ .One = {} },
        else => return error.Whatever,
    };
}

test "switch prong implicit cast" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const result = switch (foo(2) catch unreachable) {
        FormValue.One => false,
        FormValue.Two => |x| x,
    };
    try expect(result);
}
