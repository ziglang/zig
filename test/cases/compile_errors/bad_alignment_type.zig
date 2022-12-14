export fn entry1() void {
    var x: []align(true) i32 = undefined;
    _ = x;
}
export fn entry2() void {
    var x: *align(@as(f64, 12.34)) i32 = undefined;
    _ = x;
}

// error
// backend=stage2
// target=native
//
// :2:20: error: expected type 'u32', found 'bool'
// :6:19: error: fractional component prevents float value '12.34' from coercion to type 'u32'
