export fn entry1() void {
    var x: []align(true) i32 = undefined;
    _ = x;
}
export fn entry2() void {
    var x: *align(@as(f64, 12.34)) i32 = undefined;
    _ = x;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:20: error: expected type 'u29', found 'bool'
// tmp.zig:6:19: error: fractional component prevents float value 12.340000 from being casted to type 'u29'
