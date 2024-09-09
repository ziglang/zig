pub const A = struct {
    a: i32,
    pub fn init() !A {
        return A{ .a = 5 };
    }
};

pub const B = struct {
    a: A = A.init(),
};

pub fn main() void {
    const b = B{};
    _ = b;
}

// error
// target=native
// backend=stage2
//
// :9:18: error: expected type 'tmp.A', found 'error{}!tmp.A'
// :9:18: note: cannot convert error union to payload type
// :9:18: note: consider using 'try', 'catch', or 'if'
// :1:15: note: struct declared here
