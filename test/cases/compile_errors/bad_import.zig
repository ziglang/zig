const bogus = @import("bogus-does-not-exist.zig",);

// error
// backend=stage2
// target=native
//
// :1:23: error: unable to load '${DIR}bogus-does-not-exist.zig': FileNotFound
