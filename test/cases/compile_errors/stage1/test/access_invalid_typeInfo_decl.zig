const A = B;
test "Crash" {
    _ = @typeInfo(@This()).Struct.decls[0];
}

// error
// backend=stage1
// target=native
// is_test=1
//
// tmp.zig:1:11: error: use of undeclared identifier 'B'
