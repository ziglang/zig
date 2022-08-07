extern fn printf([*:0]const u8, ...) c_int;

pub export fn entry() void {
    _ = printf("%d %d %d %d\n", 1, 2, 3, 4);
}

// error
// backend=stage2
// target=native
//
// :4:33: error: integer and float literals in var args function must be casted
