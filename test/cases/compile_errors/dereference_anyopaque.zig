export fn foo(ptr: *anyopaque) void {
    _ = ptr.*;
}

// error
//
// :2:12: error: cannot load opaque type 'anyopaque'
