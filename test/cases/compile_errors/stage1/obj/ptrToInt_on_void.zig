export fn entry() bool {
    return @ptrToInt(&{}) == @ptrToInt(&{});
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:23: error: pointer to size 0 type has no address
