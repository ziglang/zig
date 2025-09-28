test {
    switch (undefined) {
        .a => |*ident| {},
    }
}

// error
//
// :3:17: error: unused capture
