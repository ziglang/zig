const S = struct {
    next: ?*align(1) S align(128),
};

export fn entry() usize {
    return @alignOf(S);
}

// error
//
// :1:11: error: struct layout depends on being pointer aligned
