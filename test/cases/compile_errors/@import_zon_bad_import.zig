export fn entry() void {
    _ = @import(
        "bogus-does-not-exist.zon",
    );
}

// error
//
// :3:9: error: unable to open 'bogus-does-not-exist.zon': FileNotFound
