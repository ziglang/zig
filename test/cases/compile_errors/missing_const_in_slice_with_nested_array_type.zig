const Geo3DTex2D = struct { vertices: [][2]f32 };
pub fn getGeo3DTex2D() Geo3DTex2D {
    return Geo3DTex2D{
        .vertices = [_][2]f32{
            [_]f32{ -0.5, -0.5 },
        },
    };
}
export fn entry() void {
    const geo_data = getGeo3DTex2D();
    _ = geo_data;
}

// error
// backend=llvm
// target=native
//
// :4:26: error: array literal requires address-of operator (&) to coerce to slice type '[][2]f32'
