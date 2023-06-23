pub fn main() void {
    const large_slice = @ptrFromInt([*]const u8, 1)[0..(0xffffffffffffffff >> 3)];
    _ = large_slice;
}

// compile
// backend=llvm
// target=x86_64-linux,x86_64-macos
//
