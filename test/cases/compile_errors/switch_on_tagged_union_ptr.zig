const foo = union(enum) {
    f0: u8,
    f1: i8,
};

pub fn main() void {
    const x = foo{ .f0 = 0 };
    switch (&x) {
        .f0 => unreachable,
        else => {},
    }
}

// error
// backend=stage2
// target=native
//
// :9:10: error: expected type '*const tmp.foo', found '@TypeOf(.enum_literal)'
// :8:13: note: consider using '.*'
