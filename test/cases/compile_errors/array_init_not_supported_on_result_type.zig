fn dummy(_: u32) void {}

export fn foo() void {
    dummy(.{ 1, 2 });
}

// error
//
// :4:12: error: type 'u32' does not support array initialization syntax
