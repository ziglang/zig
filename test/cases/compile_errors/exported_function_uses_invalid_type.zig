export fn foo() void {
    const S = struct { x: u32 = "bad default" };
    const s: S = undefined;
    _ = s;
}

// This test case explicitly runs on the LLVM backend as well as self-hosted, as
// the original bug leading to this test occurred only with the LLVM backend.

// error
//
// :2:33: error: expected type 'u32', found '*const [11:0]u8'
