const A = struct { a: i32 };
fn entry(a: *addrspace(.gs) A) *addrspace(.gs) i32 {
    return &a.a;
}
pub fn main() void {
    _ = entry;
}

// error
// output_mode=Exe
// backend=stage2,llvm
// target=x86_64-linux
//
