pub fn main() void {
    var i: u64 = 0;
    foo: while (true) : (i += 1) {
        if (i == 4) return;
        continue :foo;
    }
}

// run
//
