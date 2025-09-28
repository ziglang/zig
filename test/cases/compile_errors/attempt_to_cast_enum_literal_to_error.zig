export fn entry() void {
    switch (error.Hi) {
        .Hi => {},
    }
}

// error
//
// :3:10: error: expected type 'error{Hi}', found '@Type(.enum_literal)'
