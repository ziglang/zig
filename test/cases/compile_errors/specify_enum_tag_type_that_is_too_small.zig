const Small = enum(u2) {
    One,
    Two,
    Three,
    Four,
    Five,
};

const SmallUnion = union(enum(u2)) {
    one = 1,
    two,
    three,
    four,
};

comptime {
    _ = Small;
}
comptime {
    _ = SmallUnion;
}

// error
//
// :6:5: error: enumeration value '4' too large for type 'u2'
// :13:5: error: enumeration value '4' too large for type 'u2'
