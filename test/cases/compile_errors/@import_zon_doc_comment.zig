export fn entry() void {
    const f: struct { foo: type } = @import("zon/doc_comment.zon");
    _ = f;
}

// error
// imports=zon/doc_comment.zon
//
// doc_comment.zon:1:1: error: expected expression, found 'a document comment'
