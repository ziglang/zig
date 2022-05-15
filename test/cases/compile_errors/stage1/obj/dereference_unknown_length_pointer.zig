export fn entry(x: [*]i32) i32 {
    return x.*;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:13: error: index syntax required for unknown-length pointer type '[*]i32'
