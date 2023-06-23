const Number = enum { One, Two, Three };

pub fn main() void {
    var number1 = Number.One;
    var number2: Number = .Two;
    const number3 = @enumFromInt(Number, 2);
    assert(number1 != number2);
    assert(number2 != number3);
    assert(@intFromEnum(number1) == 0);
    assert(@intFromEnum(number2) == 1);
    assert(@intFromEnum(number3) == 2);
    var x: Number = .Two;
    assert(number2 == x);

    return;
}
fn assert(val: bool) void {
    if (!val) unreachable;
}

// run
//
