const bogus = @import(
    "bogus-does-not-exist.zig",
);

// error
// backend=stage2
// target=native
//
// bogus-does-not-exist.zig': FileNotFound
