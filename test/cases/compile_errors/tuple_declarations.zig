const E = enum {
    *u32,
};
const U = union {
    *u32,
};
const S = struct {
    a: u32,
    *u32,
};
const T = struct {
    u32,
    []const u8,

    const a = 1;
};

// error
// backend=stage2
// target=native
//
// :2:5: error: enum field missing name
// :5:5: error: union field missing name
// :9:5: error: struct field needs a name and a type
// :8:5: note: to make this a tuple type, remove all field names
// :15:5: error: tuple declarations cannot contain declarations
// :12:5: note: tuple field here
