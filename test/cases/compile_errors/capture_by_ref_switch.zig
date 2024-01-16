test {
    switch (undefined) {
        .a => |*ident| {},
    }
}

// error
// backend=stage2
// target=native
//
// :3:17: error: unused capture
