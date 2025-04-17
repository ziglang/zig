export fn entry() void {
    const U = union(enum) { a: bool, b: bool };
    switch (@as(U, undefined)) {
        .a, .b => {},
    }
}

// error
//
// :3:5: error: use of undefined value here causes illegal behavior
