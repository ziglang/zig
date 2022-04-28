export fn f1() usize {
    var _: usize = 2;
    return _;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:9: error: '_' used as an identifier without @"_" syntax
