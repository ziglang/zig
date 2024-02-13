fn outer(y: u32) *const fn (u32) u32 {
    const st = struct {
        fn get(z: u32) u32 {
            return z + y;
        }
    };
    return st.get;
}
export fn entry() void {
    const func = outer(10);
    const x = func(3);
    _ = x;
}

// error
// backend=stage2
// target=native
//
// :4:24: error: 'y' not accessible from inner function
// :3:9: note: crossed function definition here
