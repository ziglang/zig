const x: u8 = 2;
fn f() u16 {
    return x << 8;
}
export fn entry() u16 {
    return f();
}

// error
// backend=stage2
// target=native
//
// :3:17: error: type 'u3' cannot represent integer value '8'
