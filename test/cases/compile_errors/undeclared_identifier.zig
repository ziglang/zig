export fn a() void {
    return b + c;
}

const x = @"a\nb";
const y = @"aäb";
const z = @"abc";

// error
// backend=stage2
// target=native
//
// :2:12: error: use of undeclared identifier 'b'
// :5:11: error: use of undeclared identifier @"a\nb"
// :6:11: error: use of undeclared identifier @"a\xc3\xa4b"
// :7:11: error: use of undeclared identifier 'abc'
