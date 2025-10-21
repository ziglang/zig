const E = enum(u8) {};

comptime {
    _ = E;
}

// error
//
// :1:16: error: expected noreturn tag type, found 'u8'
// :1:16: note: exhaustive enum types with no fields must be tagged by noreturn
