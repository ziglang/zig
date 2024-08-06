const std = @import("std");
const testing = std.testing;
const mem = std.mem;
const ascii = std.ascii;
const Header = std.http.Header;
const ArrayList = std.ArrayList;
const fmt = std.fmt;

/// An IANA media type.
///
/// Read more: https://developer.mozilla.org/en-US/docs/Web/HTTP/Basics_of_HTTP/MIME_types
pub const Mime = struct {
    essence: []const u8 = "",

    // The basetype represents the general category into which the data type falls, such as video or text.
    basetype: []const u8 = "",

    // The subtype identifies the exact kind of data of the specified type the MIME type represents.
    // For example, for the MIME type text, the subtype might be plain (plain text),
    // html (HTML source code), or calendar (for iCalendar/.ics) files.
    subtype: []const u8 = "",

    // An optional parameter can be added to provide additional details:
    // type/subtype;parameter=value
    params: []Param = &[_]Param{},

    fn parseParam(param_string: []const u8) ?Param {
        // Find the equals sign (=) to split into key and value
        const equals_index = mem.indexOf(u8, param_string, "=");
        if (equals_index == null) {
            return null;
        }

        const equals_index_value = equals_index.?;
        if (equals_index_value == 0 or equals_index_value == param_string.len - 1) {
            return null;
        }

        var key = param_string[0..equals_index_value];
        key = mem.trimLeft(u8, key, " \t");
        // Add the parsed parameter to the list
        if (!isValidParamKey(key)) {
            return null;
        }

        var value = param_string[equals_index_value + 1 ..];
        value = mem.trimRight(u8, value, " \t");
        if (!isValidParamValue(value)) {
            return null;
        }

        return Param{ .key = key, .value = value };
    }

    // Function to parse parameters from a character sequence
    fn parseParams(params_string: []const u8) ?[]Param {
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        const allocator = gpa.allocator();
        var params = ArrayList(Param).init(allocator);

        // Split the input string by semicolons (;) to get individual parameters
        var param_list = mem.splitScalar(u8, params_string, ';');

        if (param_list.buffer.len == 0) {
            const param_part = parseParam(params_string);
            if (param_part == null) {
                return null;
            }

            params.append(param_part.?) catch return null;
        }

        while (true) {
            const p = param_list.next();
            if (p == null) {
                break;
            }
            const param_part = parseParam(p.?);
            if (param_part == null) {
                continue;
            }
            params.append(param_part.?) catch continue;
        }

        if (params.items.len == 0) {
            return null;
        }

        return params.items;
    }

    test parseParams {
        const params = parseParams("charset=utf-8; foo=bar");
        try testing.expect(params != null);
        try testing.expectEqual(2, params.?.len);
        try testing.expectEqualStrings("utf-8", params.?[0].value);
        try testing.expectEqualStrings("bar", params.?[1].value);
    }

    // Function to validate parameter keys
    fn isValidParamKey(key: []const u8) bool {
        if (key.len == 0) return false;
        // Example validation: Ensure the key contains only printable ASCII characters
        for (key) |c| {
            if (!ascii.isPrint(c)) {
                return false;
            }
        }
        if (key[0] == ' ' or key[key.len - 1] == ' ') {
            return false;
        }
        return true;
    }

    // Function to validate parameter values
    fn isValidParamValue(value: []const u8) bool {
        // Example validation: Ensure the value is non-empty
        if (value.len == 0) return false;

        // Example validation: Ensure the value contains only printable ASCII characters
        for (value) |c| {
            if (!ascii.isPrint(c)) {
                return false;
            }
        }
        if (value[0] == ' ' or value[value.len - 1] == ' ') {
            return false;
        }

        // Additional criteria can be added here based on application needs
        return true;
    }

    // Helper function to check if a part contains only valid characters
    fn isValidType(part: []const u8) bool {
        for (part) |c| {
            if (!ascii.isAlphanumeric(c) and c != '-') {
                return false;
            }
        }
        return true;
    }

    pub fn parse(mime_type: []const u8) ?Mime {

        // Must be at least "x/y" where x and y are non-empty
        if (mime_type.len < 3) {
            return null;
        }

        // const slash_index = mime_type.indexOf('/');
        const slash_index = mem.indexOf(u8, mime_type, "/");
        if (slash_index == null) return null; // Must contain '/'

        const type_part = mime_type[0..slash_index.?];
        var subtype_part = mime_type[slash_index.? + 1 ..];

        if (type_part.len == 0 or subtype_part.len == 0) return null; // Must have non-empty type and subtype

        if (!isValidType(type_part)) return null;

        const subtype_index = mem.indexOf(u8, subtype_part, ";");

        if (subtype_index == null) {
            // Remove any trailing HTTP whitespace from subtype.
            subtype_part = mem.trimRight(u8, subtype_part, " \t");
            if (!isValidType(subtype_part)) return null;

            return .{ .essence = mime_type, .basetype = type_part, .subtype = subtype_part, .params = &[_]Param{} };
        }

        var subtype = subtype_part[0..subtype_index.?];

        if (subtype.len == 0) return null; // Must have non-empty type and subtype

        // Remove any trailing HTTP whitespace from subtype.
        subtype = mem.trimRight(u8, subtype, " \t");
        if (!isValidType(subtype)) return null;

        // params should not be null
        var params_part = subtype_part[subtype_index.? + 1 ..];
        if (params_part.len == 0) return null;
        params_part = mem.trimLeft(u8, params_part, " \t");

        // Validate optional parameters
        const params = parseParams(params_part);
        if (params == null) return null;

        // return type_part.all(is_valid_char) and subtype_part.all(is_valid_char);
        return .{ .essence = mime_type, .basetype = type_part, .subtype = subtype, .params = params.? };
    }

    /// Create a new `Mime`.
    ///
    /// Follows the [WHATWG MIME parsing algorithm](https://mimesniff.spec.whatwg.org/#parsing-a-mime-type).
    pub fn init(self: Mime) ?Mime {
        if (!isValidType(self.basetype) or !isValidType(self.subtype)) {
            return null;
        }

        if (self.params.len == 0) {
            var gpa = std.heap.GeneralPurposeAllocator(.{}){};
            const allocator = gpa.allocator();

            // The essence is the full MIME type string.
            const essence_content = fmt.allocPrint(allocator, "{s}/{s}", .{ self.basetype, self.subtype }) catch return null;
            return .{
                .essence = essence_content,
                .basetype = self.basetype,
                .subtype = self.subtype,
            };
        }
        for (self.params) |param| {
            if (param.key.len == 0 or param.value.len == 0) {
                return null;
            }
            if (!isValidParamKey(param.key) or !isValidParamValue(param.value)) {
                return null;
            }
        }

        return .{
            .basetype = self.basetype,
            .subtype = self.subtype,
            .params = self.params,
        };
    }

    /// Get a reference to a param.
    pub fn getParam(self: *Mime, name: []const u8) ?[]const u8 {
        for (self.params) |pair| {
            if (ascii.eqlIgnoreCase(pair.key, name)) {
                return pair.value;
            }
        }
        return null;
    }

    /// Remove a param from the set. Returns the `ParamValue` if it was contained within the set.
    pub fn removeParam(self: *Mime, key: []const u8) ?[]const u8 {
        var index: usize = 0;
        while (index < self.params.len) : (index += 1) {
            if (mem.eql(u8, self.params[index].key, key)) {
                return self.params[index].value;
            }
        }
        return null;
    }

    pub fn toHeaderValues(self: *Mime) !ArrayList(Header) {
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        const allocator = gpa.allocator();
        var headers = ArrayList(Header).init(allocator);
        try headers.append(
            Header{ .name = "Content-Type", .value = self.essence },
        );
        return headers;
    }

    test toHeaderValues {
        var mime = Mime.init(.{
            .basetype = "text",
            .subtype = "plain",
        });
        try testing.expect(mime != null);
        const headers = try mime.?.toHeaderValues();
        try testing.expect(headers.items.len == 1);
        try testing.expectEqualStrings("Content-Type", headers.items[0].name);
        try testing.expectEqualStrings("text/plain", headers.items[0].value);
    }
};

const Param = struct {
    key: []const u8,
    value: []const u8,
};

test "Valid mime type" {
    // See more at https://mimesniff.spec.whatwg.org/#example-valid-mime-type-string
    const valid_case = [_][]const u8{
        "text/html",
        // text_plain_uppercase
        "TEXT/PLAIN",
        // text_plain_charset_utf8
        "text/plain; charset=utf-8",
        // text_plain_charset_utf8_uppercase
        "TEXT/PLAIN; CHARSET=UTF-8",
        // text_plain_charset_utf8_quoted
        "text/plain; charset=\"utf-8\"",
        // charset_utf8_extra_spaces
        "text/plain  ;  charset=utf-8  ;  foo=bar",
        // text_plain_charset_utf8_extra
        "text/plain; charset=utf-8; foo=bar",
        // text_plain_charset_utf8_extra_uppercase
        "TEXT/PLAIN; CHARSET=UTF-8; FOO=BAR",
        // subtype_space_before_params
        "text/plain ; charset=utf-8",
        // params_space_before_semi
        "text/plain; charset=utf-8 ; foo=bar",
    };
    for (valid_case) |s| {
        const mime_type = Mime.parse(s);
        try testing.expect(mime_type != null);
    }
}

test "Invalid mime type" {
    // See more at https://mimesniff.spec.whatwg.org/#example-valid-mime-type-string
    const invalid_case = [_][]const u8{
        // empty
        "",
        // slash_only
        "/",
        // slash_only_space
        " / ",
        // slash_only_space_before_params
        " / foo=bar",
        // slash_only_space_after_params
        "/html; charset=utf-8",
        "text/html;",
        // error_type_spaces
        "te xt/plain",
        // error_type_lf
        "te\nxt/plain",
        // error_type_cr
        "te\rxt/plain",
        // error_subtype_spaces
        "text/plai n",
        // error_subtype_crlf
        "text/\r\nplain",
        // error_param_name_crlf,
        "text/plain;\r\ncharset=utf-8",
        // error_param_value_quoted_crlf
        "text/plain;charset=\"\r\nutf-8\"",
        // error_param_space_before_equals
        "text/plain; charset =utf-8",
        // error_param_space_after_equals
        "text/plain; charset= utf-8",
    };

    for (invalid_case) |invalid_s| {
        const invalid_type = Mime.parse(invalid_s);
        try testing.expect(invalid_type == null);
    }
}

test "parse and params" {
    var mime = Mime.parse("text/plain; charset=utf-8; foo=bar");
    try testing.expect(mime != null);
    try testing.expect(mem.eql(u8, mime.?.essence, "text/plain; charset=utf-8; foo=bar"));
    try testing.expect(mem.eql(u8, mime.?.basetype, "text"));
    try testing.expect(mem.eql(u8, mime.?.subtype, "plain"));

    const charset = mime.?.getParam("charset");
    try testing.expect(charset != null);
    try testing.expectEqualStrings("utf-8", charset.?);

    const foo = mime.?.getParam("foo");
    try testing.expect(foo != null);

    try testing.expectEqualStrings("bar", foo.?);
    const bar = mime.?.getParam("bar");
    try testing.expect(bar == null);
}

const ParseError = error{
    /// a slash (/) was missing between the type and subtype
    MissingSlash,
    /// an equals sign (=) was missing between a parameter and its value
    MissingEqual,
    /// a quote (\") was missing from a parameter value
    MissingQuote,
    /// invalid token
    InvalidToken,
    /// unexpected asterisk
    InvalidRange,
    /// the string is too long
    TooLong,
};
