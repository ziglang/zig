export fn entry() void {
    switch (error.Hi) {
        .Hi => {},
    }
}

// error
// backend=stage2
// target=native
//
// :3:10: error: expected type 'error{Hi}', found '@TypeOf(.enum_literal)'
