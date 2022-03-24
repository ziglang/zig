export fn entry() i32 {
    return @as(i32, 12.34);
}

// explicit cast float literal to integer when there is a fraction component
//
// tmp.zig:2:21: error: fractional component prevents float value 12.340000 from being casted to type 'i32'
