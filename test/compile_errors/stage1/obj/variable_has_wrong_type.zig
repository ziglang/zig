export fn f() i32 {
    const a = "a";
    return a;
}

// variable has wrong type
//
// tmp.zig:3:12: error: expected type 'i32', found '*const [1:0]u8'
