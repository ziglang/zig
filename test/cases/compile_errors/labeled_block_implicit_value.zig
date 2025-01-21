export fn foo() void {
    const result: u32 = b: {
        if (false) break :b 1;
    };
    _ = result;
}

// error
//
// :2:28: error: expected type 'u32', found 'void'
