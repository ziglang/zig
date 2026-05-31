export fn entry() usize {
    return @alignOf(noreturn);
}

// error
//
// :2:21: error: no align available for type 'noreturn'
