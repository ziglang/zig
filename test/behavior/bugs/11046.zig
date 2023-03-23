const builtin = @import("builtin");

fn foo() !void {
    var a = true;
    if (a) return error.Foo;
    return error.Bar;
}
fn bar() !void {
    try foo();
}

test "fixed" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    bar() catch |err| switch (err) {
        error.Foo => {}, // error: expected (inferred error set of bar), found error{Foo}
        error.Bar => {},
    };
}
