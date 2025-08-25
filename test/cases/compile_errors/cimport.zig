const b = @cDefine("foo", "1");
const c = @cImport({
    _ = @TypeOf(@cDefine("foo", "1"));
});
const d = @cImport({
    _ = @cImport(@cDefine("foo", "1"));
});

// error
// backend=stage2
// target=native
//
// :1:11: error: C define valid only inside C import block
// :3:17: error: C define valid only inside C import block
// :6:9: error: cannot nest @cImport
