export fn foo() void {
    const a = 1;
    _ = struct {
        test a {}
    };
}

// error
//
// :4:14: error: cannot test a local constant
// :2:11: note: local constant declared here
