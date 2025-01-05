export fn entry() void {
    _ = @import(
        "bogus-does-not-exist.zon",
    );
}

// error
// target=native
//
// :3:9: error: unable to open 'bogus-does-not-exist.zon': FileNotFound
