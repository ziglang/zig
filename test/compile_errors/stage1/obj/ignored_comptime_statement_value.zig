export fn foo() void {
    comptime {1;}
}

// ignored comptime statement value
//
// tmp.zig:2:15: error: expression value is ignored
