export fn entry() void {
    switch (error.Hi) {
        .Hi => {},
    }
}

// attempt to cast enum literal to error
//
// tmp.zig:3:9: error: expected type 'error{Hi}', found '@Type(.EnumLiteral)'
