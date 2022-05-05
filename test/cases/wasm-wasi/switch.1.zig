pub fn main() u8 {
    var val: u8 = 2;
    var a: u8 = switch (val) {
        0, 1 => 2,
        2 => 3,
        3 => 4,
        else => 5,
    };

    return a - 3;
}

// run
//
