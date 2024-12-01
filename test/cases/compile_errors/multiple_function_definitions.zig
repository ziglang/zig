fn a() void {}
fn a() void {}
export fn entry() void {
    a();
}

// error
//
// :1:4: error: duplicate struct member name 'a'
// :2:4: note: duplicate name here
// :1:1: note: struct declared here
