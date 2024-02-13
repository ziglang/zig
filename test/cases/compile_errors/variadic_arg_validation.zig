extern fn printf([*:0]const u8, ...) c_int;

pub export fn entry() void {
    _ = printf("%d %d %d %d\n", 1, 2, 3, 4);
}

pub export fn entry1() void {
    var arr: [2]u8 = undefined;
    _ = printf("%d\n", arr);
    _ = &arr;
}

pub export fn entry2() void {
    _ = printf("%d\n", @as(u48, 2));
}

pub export fn entry3() void {
    _ = printf("%d\n", {});
}

// error
// backend=stage2
// target=native
//
// :4:33: error: integer and float literals passed to variadic function must be casted to a fixed-size number type
// :9:24: error: arrays must be passed by reference to variadic function
// :14:24: error: cannot pass 'u48' to variadic function
// :14:24: note: only integers with 0 or power of two bits are extern compatible
// :18:24: error: cannot pass 'void' to variadic function
// :18:24: note: 'void' is a zero bit type; for C 'void' use 'anyopaque'
