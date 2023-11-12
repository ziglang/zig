const foo = union(enum) {
    f0: u8,
    f1: i8,
};

pub fn main() void {
    const x = foo{ .f0 = 0 };
    switch (&x) {
        else => {},
    }
}

// error
// backend=stage2
// target=native
//
// :8:12: error: switch on pointer value while enum or union is expected
