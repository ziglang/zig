pub export fn entry(param: usize) usize {
    return struct { param };
}

// error
// backend=stage2
// target=native
//
// :2:12: error: expected type 'usize', found 'type'
// :1:35: note: function return type declared here
