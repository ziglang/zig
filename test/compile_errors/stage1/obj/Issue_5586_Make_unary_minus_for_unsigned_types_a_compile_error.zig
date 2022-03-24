export fn f1(x: u32) u32 {
    const y = -%x;
    return -y;
}
const V = @import("std").meta.Vector;
export fn f2(x: V(4, u32)) V(4, u32) {
    const y = -%x;
    return -y;
}

// Issue #5586: Make unary minus for unsigned types a compile error
//
// tmp.zig:3:12: error: negation of type 'u32'
// tmp.zig:8:12: error: negation of type 'u32'
