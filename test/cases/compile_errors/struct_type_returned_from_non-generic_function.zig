pub export fn entry(param: usize) usize {
    return struct { @TypeOf(param) };
}

// error
//
// :2:12: error: expected type 'usize', found 'type'
// :1:35: note: function return type declared here
