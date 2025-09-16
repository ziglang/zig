comptime {
    const tile = Tile.Empty;
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
//
// :3:17: error: cannot dereference non-pointer type 'tmp.Tile'
// :8:14: note: enum declared here
