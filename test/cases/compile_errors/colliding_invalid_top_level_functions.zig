fn func() bogus {}
fn func() bogus {}
export fn entry() usize {
    return @sizeOf(@TypeOf(func));
}

// error
//
// :1:4: error: duplicate struct member name 'func'
// :2:4: note: duplicate name here
// :1:1: note: struct declared here
// :1:11: error: use of undeclared identifier 'bogus'
// :2:11: error: use of undeclared identifier 'bogus'
