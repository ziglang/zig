const x = 0;
comptime {
    x += foo();
}

fn foo() !usize {
    return 0;
}

// error
//
// :3:13: error: expected type 'comptime_int', found 'error{}!usize'
