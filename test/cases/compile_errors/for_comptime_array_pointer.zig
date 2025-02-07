export fn foo() void {
    comptime var elems: [3]u32 = undefined;
    for (&elems) |*elem| {
        _ = elem;
    }
}

// error
//
// :3:10: error: runtime value contains reference to comptime var
// :3:10: note: comptime var pointers are not available at runtime
// :2:34: note: 'runtime_value' points to comptime var declared here
