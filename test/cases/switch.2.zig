pub fn main() u8 {
    var val: u8 = 10;
    _ = &val;
    const a: u8 = switch (val) {
        0, 1 => 2,
        2 => 3,
        3 => 4,
        else => 5,
    };

    return a - 5;
}

// run
//
