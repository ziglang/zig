const Number = enum { One, Two, Three };

pub fn main() void {
    var number1 = Number.One;
    var number2: Number = .Two;
    if (false) {
        &number1;
        &number2;
    }
    const number3: Number = @enumFromInt(2);
    if (@intFromEnum(number3) != 2) {
        unreachable;
    }
    return;
}

// run
//
