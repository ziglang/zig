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

// invalid deref on switch target
//
// tmp.zig:3:17: error: attempt to dereference non-pointer type 'Tile'
