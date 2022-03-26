export fn foo() void {
    comptime 1;
}

// ignored comptime value
//
// tmp.zig:2:5: error: expression value is ignored
