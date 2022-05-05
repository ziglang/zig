pub fn main() void {
    foo: while (true) {
        break :foo;
    }
}

// run
//
