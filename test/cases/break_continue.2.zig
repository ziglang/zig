pub fn main() void {
    var i: u64 = 0;
    while (true) : (i += 1) {
        if (i == 4) return;
        continue;
    }
}

// run
//
