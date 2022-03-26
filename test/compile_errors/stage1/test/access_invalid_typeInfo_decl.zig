const A = B;
test "Crash" {
    _ = @typeInfo(@This()).Struct.decls[0];
}

// access invalid @typeInfo decl
//
// tmp.zig:1:11: error: use of undeclared identifier 'B'
