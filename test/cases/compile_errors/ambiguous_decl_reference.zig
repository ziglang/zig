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
//
// :5:13: error: ambiguous reference
// :7:9: note: declared here
// :1:1: note: also declared here
