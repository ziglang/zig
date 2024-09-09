const T = struct {
    v: i32,
    pub fn f1(self: *@This()) void {
        self.v += 1;
    }
};

pub fn main() anyerror!void {
    comptime var r = T{ .v = 0 };
    _ = r.f1();
}

// error
// target=native
// backend=stage2
//
// :10:10: error: runtime value contains reference to comptime var
// :10:10: note: comptime var pointers are not available at runtime
