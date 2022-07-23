const V = @Vector(8, u8);
const A = [8]u8;
comptime {
    var v: V = V{1};
    _ = v;
}
comptime {
    var v: V = V{};
    _ = v;
}
comptime {
    var a: A = A{1};
    _ = a;
}
comptime {
    var a: A = A{};
    _ = a;
}

// error
// backend=stage2
// target=native
//
// :4:17: error: expected 8 vector elements; found 1
// :8:17: error: expected 8 vector elements; found 0
// :12:17: error: expected 8 array elements; found 1
// :16:17: error: expected 8 array elements; found 0
