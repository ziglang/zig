export fn entry() void {
    nosuspend {
        const bar = async foo();
        suspend {}
        resume bar;
    }
}
fn foo() void {}

// error
// backend=stage1
// target=native
// is_test=1
//
// tmp.zig:4:9: error: suspend inside nosuspend block
// tmp.zig:2:5: note: nosuspend block here
