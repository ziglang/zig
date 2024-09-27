pub fn main() !void {
    errdefer |_| _ = @"_";
}

// error
//
// :2:15: error: discard of error capture; omit it instead
