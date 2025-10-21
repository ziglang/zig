const U = union(enum(u8)) {};

comptime {
    _ = U;
}

// error
//
// :1:22: error: expected noreturn tag type, found 'u8'
// :1:22: note: tagged union types with no fields must be tagged by noreturn
