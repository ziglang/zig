comptime {
    var tile = Tile.Empty;
    switch (tile.*) {
        Tile.Empty => {},
        Tile.Filled => {},
    }
}
const Tile = enum {
    Empty,
    Filled,
};

// error
// backend=stage1
// target=native
//
// tmp.zig:3:17: error: attempt to dereference non-pointer type 'Tile'
