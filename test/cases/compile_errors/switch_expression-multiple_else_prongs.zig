fn f(x: u32) void {
    const value: bool = switch (x) {
        1234 => false,
        else => true,
        else => true,
    };
}
fn g(x: error{ Foo, Bar, Baz }!u32) void {
    const value: bool = if (x) |_| true else |e| switch (e) {
        error.Foo => false,
        else => true,
        else => true,
    };
}
fn h(x: error{ Foo, Bar, Baz }!u32) void {
    const value: u32 = x catch |e| switch (e) {
        error.Foo => 1,
        else => 2,
        else => 3,
    };
}
export fn entry() void {
    f(1234);
    g(1234);
    h(1234);
}

// error
// backend=stage2
// target=native
//
// :5:9: error: multiple else prongs in switch expression
// :4:9: note: previous else prong here
// :12:9: error: multiple else prongs in switch expression
// :11:9: note: previous else prong here
// :19:9: error: multiple else prongs in switch expression
// :18:9: note: previous else prong here
