export fn a() void {
    var x: u32 = 10;
    _ = &x;
    _ = @expect(x);
}

// error
// backend=stage2
// target=native
//
// :4:17: error: expected type 'bool', found 'u32'
