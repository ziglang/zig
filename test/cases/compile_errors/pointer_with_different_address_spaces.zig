fn entry(a: *addrspace(.gs) i32) *addrspace(.fs) i32 {
    return a;
}
export fn entry2() void {
    _ = &entry;
}

// error
// output_mode=Obj
// backend=stage2,llvm
// target=x86_64-linux,x86_64-macos
//
// :2:12: error: expected type '*addrspace(.fs) i32', found '*addrspace(.gs) i32'
// :2:12: note: address space 'gs' cannot cast into address space 'fs'
// :1:34: note: function return type declared here
