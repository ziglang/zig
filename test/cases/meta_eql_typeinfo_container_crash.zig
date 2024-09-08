comptime {
    if (!eql(@typeInfo(opaque {}), @typeInfo(opaque {}))) unreachable;
}

pub fn eql(a: anytype, b: @TypeOf(a)) bool {
    switch (@typeInfo(@TypeOf(a))) {
        .@"struct" => |info| {
            inline for (info.fields) |field_info| {
                if (!eql(@field(a, field_info.name), @field(b, field_info.name))) return false;
            }
            return true;
        },
        .@"union" => |info| {
            if (info.tag_type) |UnionTag| {
                inline for (info.fields) |field_info| {
                    if (@field(UnionTag, field_info.name) == @as(UnionTag, a)) {
                        return eql(@field(a, field_info.name), @field(b, field_info.name));
                    }
                }
                return false;
            }
            unreachable;
        },
        .pointer => return a.ptr == b.ptr and a.len == b.len,
        else => unreachable,
    }
}

// compile
//
