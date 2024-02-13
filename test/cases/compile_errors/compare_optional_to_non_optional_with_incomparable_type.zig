export fn entry() void {
    const x: ?[3]i32 = undefined;
    const y: [3]i32 = undefined;
    _ = (x == y);
}

// error
// backend=llvm
// target=native
//
// :4:12: error: operator == not allowed for type '?[3]i32'
