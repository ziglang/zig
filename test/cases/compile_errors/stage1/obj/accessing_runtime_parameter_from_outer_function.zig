fn outer(y: u32) fn (u32) u32 {
    const st = struct {
        fn get(z: u32) u32 {
            return z + y;
        }
    };
    return st.get;
}
export fn entry() void {
    var func = outer(10);
    var x = func(3);
    _ = x;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:4:24: error: 'y' not accessible from inner function
// tmp.zig:3:28: note: crossed function definition here
// tmp.zig:1:10: note: declared here
