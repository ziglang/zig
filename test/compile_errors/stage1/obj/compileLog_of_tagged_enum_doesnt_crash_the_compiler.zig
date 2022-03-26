const Bar = union(enum(u32)) {
    X: i32 = 1
};

fn testCompileLog(x: Bar) void {
    @compileLog(x);
}

pub fn main () void {
    comptime testCompileLog(Bar{.X = 123});
}

// compileLog of tagged enum doesn't crash the compiler
//
// tmp.zig:6:5: error: found compile log statement
