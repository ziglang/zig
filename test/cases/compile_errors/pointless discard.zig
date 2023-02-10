export fn foo() void {
    var x: i32 = 1234;
    x += 1;
    _ = x;
}
export fn bar() void {
    var b: u32 = 1;
    _ = blk: {
        const a = 1;
        b = a;
        break :blk a;
    };
}

// error
// backend=stage2
// target=native
//
// :4:9: error: pointless discard of local variable
// :3:5: note: used here
