const src: [10]u8 = @splat(0);
var dest: [10]u16 = undefined;

export fn foo() void {
    @memcpy(&dest, &src);
}

// error
//
// :5:5: error: pointer element type 'u8' cannot coerce into element type 'u16'
