pub export fn entry() void { }
comptime {
    @export(entry, .{ .name = "" });
}

// error
// backend=llvm
// target=native
//
// :3:21: error: exported symbol name cannot be empty
