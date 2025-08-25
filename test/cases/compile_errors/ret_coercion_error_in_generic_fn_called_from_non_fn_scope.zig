fn foo() fn () void {
    return struct {};
}
comptime {
    _ = foo();
}

// error
//
// :2:12: error: expected type 'fn () void', found 'type'
// :1:10: note: function return type declared here
// :5:12: note: called at comptime here
