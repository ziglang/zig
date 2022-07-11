export fn f() i32 {
    const a = "a";
    return a;
}

// error
// backend=stage2
// target=native
//
// :3:12: error: expected type 'i32', found '*const [1:0]u8'
// :1:15: note: function return type declared here
