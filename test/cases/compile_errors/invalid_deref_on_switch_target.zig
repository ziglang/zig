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
// backend=stage2
// target=native
//
// :3:17: error: cannot dereference non-pointer type 'tmp.Tile'
