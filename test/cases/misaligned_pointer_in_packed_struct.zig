const X = packed struct {
    a: i3,
    b: *i64,
};

pub fn main() void {
    var i: i64 = 1;
    const x = X{ .a = 2, .b = &i };
    _ = x;
}

// run
//
