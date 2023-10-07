export fn foo() void {
    var bar: u32 = 3;
    asm volatile (""
        : [baz] "+r" (bar),
        :
        : ""
    );
}

// error
// backend=stage1
// target=native
//
// tmp.zig:3:5: error: invalid modifier starting output constraint for 'baz': '+', only '=' is supported. Compiler TODO: see https://github.com/ziglang/zig/issues/215
