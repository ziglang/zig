//! HTTP Methods
//! https://developer.mozilla.org/en-US/docs/Web/HTTP/Methods

// Style guide is violated here so that @tagName can be used effectively
/// https://datatracker.ietf.org/doc/html/rfc7231#section-4 Initial definiton
/// https://datatracker.ietf.org/doc/html/rfc5789#section-2 PATCH
pub const Method = enum {
    GET,
    HEAD,
    POST,
    PUT,
    DELETE,
    CONNECT,
    OPTIONS,
    TRACE,
    PATCH,
};
