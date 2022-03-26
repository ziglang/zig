export fn foo() void {
    defer {1;}
}

// ignored deferred statement value
//
// tmp.zig:2:12: error: expression value is ignored
