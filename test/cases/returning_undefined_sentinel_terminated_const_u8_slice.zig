fn foo() [:0]const u8 {
    return undefined;
}
pub fn main() void {
    var guid: [*:0]const u8 = undefined;
    guid = foo();
}

// run
// backend=llvm
// target=native
