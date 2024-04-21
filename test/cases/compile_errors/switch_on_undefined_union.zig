export fn entry() void {
    const U = union(enum) { a: bool, b: bool };
    switch (@as(U, undefined)) {
        .a, .b => {},
    }
}

// error
// backend=stage2
// target=native
//
// :3:5: error: use of undefined value here causes undefined behavior
