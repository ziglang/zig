const Tag = enum { a, b };

const Union = union(Tag) {
    b,
    a,
};

const BaseUnion = union(enum) {
    a,
    b,
};

const GeneratedTagUnion = union(@typeInfo(BaseUnion).@"union".tag_type.?) {
    b,
    a,
};

export fn entry() usize {
    return @sizeOf(Union) + @sizeOf(GeneratedTagUnion);
}

// error
//
// :4:5: error: union field 'b' ordered differently than corresponding enum field
// :1:23: note: enum field here
// :14:5: error: union field 'b' ordered differently than corresponding enum field
// :10:5: note: enum field here
