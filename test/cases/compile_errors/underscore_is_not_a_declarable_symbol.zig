export fn f1() usize {
    var _: usize = 2;
    return _;
}

// error
// backend=stage2
// target=native
//
// :2:9: error: '_' used as an identifier without @"_" syntax
