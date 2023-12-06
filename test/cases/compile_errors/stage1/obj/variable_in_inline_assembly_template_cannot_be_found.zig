export fn entry() void {
    var sp = asm volatile ("mov %[foo], sp"
        : [bar] "=r" (-> usize),
    );
    _ = &sp;
}

// error
// backend=stage1
// target=x86_64-linux-gnu
//
// tmp.zig:2:14: error: could not find 'foo' in the inputs or outputs
