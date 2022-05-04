export fn entry(x: u8, y: u8) u8 {
    return x << y;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:17: error: expected type 'u3', found 'u8'
