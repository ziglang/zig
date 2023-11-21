const E = enum {
    a,
    b,
};
pub export fn entry() void {
    const e: E = .b;
    switch (e) {
        .a => {},
        .b => {},
        _ => {},
    }
}

// error
// backend=stage2
// target=native
//
// :7:5: error: '_' prong only allowed when switching on non-exhaustive enums
// :10:11: note: '_' prong here
// :7:5: note: consider using 'else'
