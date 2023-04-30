const Bad = struct {
    u32 = 10,
};

const Good = struct {
    comptime u32 = 10,
};

// error
// backend=stage2
// target=native
//
// :2:5: error: non-comptime tuple fields cannot have default values
