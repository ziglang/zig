const x = if (undefined) true else false;

export fn entry() usize {
    return @sizeOf(@TypeOf(x));
}

// error
//
// :1:15: error: use of undefined value here causes illegal behavior
