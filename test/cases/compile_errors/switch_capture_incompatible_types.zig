export fn f() void {
    const U = union(enum) { a: u32, b: *u8 };
    var u: U = undefined;
    switch ((&u).*) {
        .a, .b => |val| _ = val,
    }
}

export fn g() void {
    const U = union(enum) { a: u64, b: u32 };
    var u: U = undefined;
    switch ((&u).*) {
        .a, .b => |*ptr| _ = ptr,
    }
}

// error
// backend=stage2
// target=native
//
// :5:20: error: capture group with incompatible types
// :5:20: note: incompatible types: 'u32' and '*u8'
// :5:10: note: type 'u32' here
// :5:14: note: type '*u8' here
// :13:20: error: capture group with incompatible types
// :13:20: note: incompatible types: '*u64' and '*u32'
// :13:10: note: type '*u64' here
// :13:14: note: type '*u32' here
// :13:20: note: this coercion is only possible when capturing by value
