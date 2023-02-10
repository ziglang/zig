export fn f1(x: u32) u32 {
    const y = -%x;
    return -y;
}
const V = @import("std").meta.Vector;
export fn f2(x: V(4, u32)) V(4, u32) {
    const y = -%x;
    return -y;
}

// error
// backend=stage2
// target=native
//
// :3:12: error: negation of type 'u32'
// :8:12: error: negation of type '@Vector(4, u32)'
