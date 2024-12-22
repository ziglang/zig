pub fn main() void {
    const f: struct { foo: type } = @import("zon/doc_comment.zon");
    _ = f;
}

// error
// backend=stage2
// output_mode=Exe
// imports=zon/doc_comment.zon
//
// doc_comment.zon:1:1: error: expected expression, found 'a document comment'
