pub export fn entry1() void {
    const x: i32 = 0;
    switch (x) {
        6...1 => {},
        else => unreachable,
    }
}
pub export fn entr2() void {
    const x: i32 = 0;
    switch (x) {
        -1...-5 => {},
        else => unreachable,
    }
}

// error
// backend=stage2
// target=native
//
// :4:9: error: range start value is greater than the end value
// :11:9: error: range start value is greater than the end value
