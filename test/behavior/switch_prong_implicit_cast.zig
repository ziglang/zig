const expect = @import("std").testing.expect;

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
    const result = switch (foo(2) catch unreachable) {
        FormValue.One => false,
        FormValue.Two => |x| x,
    };
    try expect(result);
}
