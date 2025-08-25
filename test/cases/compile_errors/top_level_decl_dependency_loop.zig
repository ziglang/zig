const a: @TypeOf(b) = 0;
const b: @TypeOf(a) = 0;
export fn entry() void {
    const c = a + b;
    _ = c;
}

// error
// backend=stage2
// target=native
//
// :1:1: error: dependency loop detected
