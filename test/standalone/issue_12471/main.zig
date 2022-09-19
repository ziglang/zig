const c = @cImport({
    @cDefine("FOO", "FOO");
    @cDefine("BAR", "FOO");

    @cDefine("BAZ", "QUX");
    @cDefine("QUX", "QUX");
});

pub fn main() u8 {
    _ = c;
    return 0;
}
