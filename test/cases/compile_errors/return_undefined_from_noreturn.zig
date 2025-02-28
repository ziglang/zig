export fn entry() noreturn {
    return undefined;
}

// error
// backend=stage2
// target=native
//
// :2:12: error: function declared 'noreturn' returns
// :1:19: note: 'noreturn' declared here
