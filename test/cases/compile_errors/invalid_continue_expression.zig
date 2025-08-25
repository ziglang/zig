export fn f() void {
    continue;
}

// error
// backend=stage2
// target=native
//
// :2:5: error: continue expression outside loop
