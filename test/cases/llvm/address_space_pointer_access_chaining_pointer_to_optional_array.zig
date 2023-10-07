fn entry(a: *addrspace(.gs) ?[1]i32) *addrspace(.gs) i32 {
    return &a.*.?[0];
}
pub fn main() void {
    _ = &entry;
}

// compile
// output_mode=Exe
// backend=llvm
// target=x86_64-linux,x86_64-macos
//
