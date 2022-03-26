export fn f1() usize {
    var _: usize = 2;
    return _;
}

// `_` is not a declarable symbol
//
// tmp.zig:2:9: error: '_' used as an identifier without @"_" syntax
