// https://github.com/ziglang/zig/issues/24323

export fn f() void {
    const x: u32 = 0;
    sw: switch (x) {
        else => if (false) continue :sw undefined,
    }
}

// compile
// backend=stage2,llvm
// target=native
