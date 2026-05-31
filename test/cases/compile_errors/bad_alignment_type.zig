export fn entry1() void {
    const x: []align(true) i32 = undefined;
    _ = x;
}
export fn entry2() void {
    const x: *align(@as(f64, 12.34)) i32 = undefined;
    _ = x;
}

// error
//
// :2:22: error: expected type 'u29', found 'bool'
// :6:21: error: fractional component prevents float value '12.34' from coercion to type 'u29'
