const Bar = union(enum(u32)) {
    X: i32 = 1
};

fn testCompileLog(x: Bar) void {
    @compileLog(x);
}

pub fn main () void {
    comptime testCompileLog(Bar{.X = 123});
}

// error
// backend=stage1
// target=native
//
// tmp.zig:6:5: error: found compile log statement
