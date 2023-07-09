const A = struct { a: ?[1]i32 };
fn entry(a: *addrspace(.gs) [1]A) *addrspace(.gs) i32 {
    return &a[0].a.?[0];
}
pub fn main() void {
    _ = &entry;
}

// compile
// output_mode=Exe
// backend=llvm
// target=x86_64-linux,x86_64-macos
//
