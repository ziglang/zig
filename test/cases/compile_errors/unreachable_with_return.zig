fn a() noreturn {
    return;
}
export fn entry() void {
    a();
}

// error
// backend=stage2
// target=native
//
// :2:5: error: function declared 'noreturn' returns
// :1:8: note: 'noreturn' declared here
