const bogus = @import(
    "bogus-does-not-exist.zig",
);

// error
//
// bogus-does-not-exist.zig:1:1: error: unable to load 'bogus-does-not-exist.zig': FileNotFound
// :2:5: note: file imported here
