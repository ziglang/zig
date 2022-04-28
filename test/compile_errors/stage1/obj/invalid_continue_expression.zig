export fn f() void {
    continue;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:5: error: continue expression outside loop
