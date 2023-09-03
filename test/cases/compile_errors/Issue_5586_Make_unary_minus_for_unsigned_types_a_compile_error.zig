export fn f1(x: u32) u32 {
    const y = -%x;
    return -y;
}
export fn f2(x: @Vector(4, u32)) @Vector(4, u32) {
    const y = -%x;
    return -y;
}

// error
// backend=stage2
// target=native
//
// :3:12: error: negation of type 'u32'
// :7:12: error: negation of type '@Vector(4, u32)'
