export fn foo() void {
    test_a_thing();
}
fn test_a_thing() void {
    bad_fn_call();
}

// undeclared identifier error should mark fn as impure
//
// tmp.zig:5:5: error: use of undeclared identifier 'bad_fn_call'
