export fn entry(x: u8, y: u8) u8 {
    return x << y;
}

// error
// backend=stage2
// target=native
//
// :2:17: error: expected type 'u3', found 'u8'
