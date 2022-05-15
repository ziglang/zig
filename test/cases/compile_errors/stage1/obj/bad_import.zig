const bogus = @import("bogus-does-not-exist.zig",);

// error
// backend=stage1
// target=native
//
// tmp.zig:1:23: error: unable to load '${DIR}bogus-does-not-exist.zig': FileNotFound
