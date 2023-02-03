export fn foo() void {
    const a = 1;
    struct {
        test a {}
    };
}

// error
// backend=stage2
// target=native
//
// :4:14: error: cannot test a local constant
// :2:11: note: local constant declared here
