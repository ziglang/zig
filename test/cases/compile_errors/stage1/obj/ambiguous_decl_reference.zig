fn foo() void {}
fn bar() void {
    const S = struct {
        fn baz() void {
            foo();
        }
        fn foo() void {}
    };
    S.baz();
}
export fn entry() void {
    bar();
}

// error
// backend=stage1
// target=native
//
// tmp.zig:5:13: error: ambiguous reference
// tmp.zig:7:9: note: declared here
// tmp.zig:1:1: note: also declared here
