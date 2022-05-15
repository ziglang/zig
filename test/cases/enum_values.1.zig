const Number = enum { One, Two, Three };

pub fn main() void {
    var number1 = Number.One;
    var number2: Number = .Two;
    const number3 = @intToEnum(Number, 2);
    assert(number1 != number2);
    assert(number2 != number3);
    assert(@enumToInt(number1) == 0);
    assert(@enumToInt(number2) == 1);
    assert(@enumToInt(number3) == 2);
    var x: Number = .Two;
    assert(number2 == x);

    return;
}
fn assert(val: bool) void {
    if (!val) unreachable;
}

// run
//
