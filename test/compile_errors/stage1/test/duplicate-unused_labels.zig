comptime {
    blk: { blk: while (false) {} }
}
comptime {
    blk: while (false) { blk: for (@as([0]void, undefined)) |_| {} }
}
comptime {
    blk: for (@as([0]void, undefined)) |_| { blk: {} }
}
comptime {
    blk: {}
}
comptime {
    blk: while(false) {}
}
comptime {
    blk: for(@as([0]void, undefined)) |_| {}
}

// duplicate/unused labels
//
// tmp.zig:2:12: error: redefinition of label 'blk'
// tmp.zig:2:5: note: previous definition here
// tmp.zig:5:26: error: redefinition of label 'blk'
// tmp.zig:5:5: note: previous definition here
// tmp.zig:8:46: error: redefinition of label 'blk'
// tmp.zig:8:5: note: previous definition here
// tmp.zig:11:5: error: unused block label
// tmp.zig:14:5: error: unused while loop label
// tmp.zig:17:5: error: unused for loop label
