export fn entry() i32 {
    return @as(i32, 12.34);
}

// error
// backend=stage2
// target=native
//
// :2:21: error: fractional component prevents float value '12.34' from coercion to type 'i32'
