fn dummy(_: u32) void {}

export fn foo() void {
    dummy(.{ 1, 2 });
}

// error
// backend=stage2
// target=native
//
// :4:12: error: type 'u32' does not support array initialization syntax
