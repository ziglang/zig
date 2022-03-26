export fn entry() bool {
    return @ptrToInt(&{}) == @ptrToInt(&{});
}

// @ptrToInt on *void
//
// tmp.zig:2:23: error: pointer to size 0 type has no address
