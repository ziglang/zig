pub fn main() u8 {
    var val: ?u8 = 5;
    while (val) |*v| {
        v.* -= 1;
        if (v.* == 2) {
            val = null;
        }
    }
    return 0;
}

// run
//
