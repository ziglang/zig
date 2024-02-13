const JasonHM = u8;
const JasonList = *JsonNode;

const JsonOA = union(enum) {
    JSONArray: JsonList,
    JSONObject: JasonHM,
};

const JsonType = union(enum) {
    JSONNull: void,
    JSONInteger: isize,
    JSONDouble: f64,
    JSONBool: bool,
    JSONString: []u8,
    JSONArray: void,
    JSONObject: void,
};

pub const JsonNode = struct {
    kind: JsonType,
    jobject: ?JsonOA,
};

fn foo() void {
    var jll: JasonList = undefined;
    jll.init(1234);
    const jd = JsonNode{ .kind = JsonType.JSONArray, .jobject = JsonOA.JSONArray{jll} };
    _ = jd;
}

export fn entry() usize {
    return @sizeOf(@TypeOf(foo));
}

// error
// backend=stage2
// target=native
//
// :5:16: error: use of undeclared identifier 'JsonList'
