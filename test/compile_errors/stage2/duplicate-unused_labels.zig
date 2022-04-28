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

// error
// target=native
//
// :2:12: error: redefinition of label 'blk'
// :2:5: note: previous definition here
// :5:26: error: redefinition of label 'blk'
// :5:5: note: previous definition here
// :8:46: error: redefinition of label 'blk'
// :8:5: note: previous definition here
// :11:5: error: unused block label
// :14:5: error: unused while loop label
// :17:5: error: unused for loop label
