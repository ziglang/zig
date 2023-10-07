fn entry(a: *addrspace(.fs) *addrspace(.gs) *i32) *i32 {
    return a.*.*;
}
pub fn main() void {
    _ = &entry;
}

// compile
// output_mode=Exe
// backend=stage2,llvm
// target=x86_64-linux,x86_64-macos
//
