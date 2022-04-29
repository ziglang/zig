const x : u8 = 2;
fn f() u16 {
    return x << 8;
}
export fn entry() u16 { return f(); }

// error
// backend=stage1
// target=native
//
// tmp.zig:3:17: error: integer value 8 cannot be coerced to type 'u3'
