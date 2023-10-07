fn a() void {}
fn a() void {}
export fn entry() void {
    a();
}

// error
// backend=stage2
// target=native
//
// :2:1: error: redeclaration of 'a'
// :1:1: note: other declaration here
