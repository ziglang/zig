fn f(x: u32) void {
    const value: bool = switch (x) {
        1234 => false,
        else => true,
        else => true,
    };
}
export fn entry() void {
    f(1234);
}

// error
// backend=stage2
// target=native
//
// :5:9: error: multiple else prongs in switch expression
// :4:9: note: previous else prong here
