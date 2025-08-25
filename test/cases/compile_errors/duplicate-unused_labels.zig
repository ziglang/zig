comptime {
    blk: {
        blk: while (false) {}
    }
}
comptime {
    blk: while (false) {
        blk: for (@as([0]void, undefined)) |_| {}
    }
}
comptime {
    blk: for (@as([0]void, undefined)) |_| {
        blk: {}
    }
}
comptime {
    blk: {}
}
comptime {
    blk: while (false) {}
}
comptime {
    blk: for (@as([0]void, undefined)) |_| {}
}
comptime {
    blk: switch (true) {
        else => {},
    }
}

// error
// target=native
//
// :3:9: error: redefinition of label 'blk'
// :2:5: note: previous definition here
// :8:9: error: redefinition of label 'blk'
// :7:5: note: previous definition here
// :13:9: error: redefinition of label 'blk'
// :12:5: note: previous definition here
// :17:5: error: unused block label
// :20:5: error: unused while loop label
// :23:5: error: unused for loop label
// :26:5: error: unused switch label
