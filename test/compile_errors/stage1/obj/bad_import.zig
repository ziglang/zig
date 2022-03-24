const bogus = @import("bogus-does-not-exist.zig",);

// bad import
//
// tmp.zig:1:23: error: unable to load '${DIR}bogus-does-not-exist.zig': FileNotFound
