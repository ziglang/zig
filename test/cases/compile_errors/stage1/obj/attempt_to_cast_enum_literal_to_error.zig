export fn entry() void {
    switch (error.Hi) {
        .Hi => {},
    }
}

// error
// backend=stage1
// target=native
//
// tmp.zig:3:9: error: expected type 'error{Hi}', found '@Type(.EnumLiteral)'
