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

    /// Returns true if a request of this method is allowed to have a body
    /// Returns null if it also depends on other conditions
    pub fn requestHasBody(self: Method) ?bool {
        return switch (self) {
            .GET => false,
            .HEAD => false,
            .POST => true,
            .PUT => true,
            .DELETE => null,
            .CONNECT => false,
            .OPTIONS => false,
            .TRACE => false,
            .PATCH => true,
        };
    }

    /// Returns true if a response to this method is allowed to have a body
    /// Returns null if it also depends on other conditions
    pub fn responseHasBody(self: Method) ?bool {
        return switch (self) {
            .GET => true,
            .HEAD => false,
            .POST => true,
            .PUT => false,
            .DELETE => null,
            .CONNECT => true,
            .OPTIONS => true,
            .TRACE => false,
            .PATCH => true,
        };
    }

    /// An HTTP method is safe if it doesn't alter the state of the server.
    /// https://developer.mozilla.org/en-US/docs/Glossary/Safe/HTTP
    /// https://datatracker.ietf.org/doc/html/rfc7231#section-4.2.1
    pub fn safe(self: Method) bool {
        return switch (self) {
            .GET => true,
            .HEAD => true,
            .POST => false,
            .PUT => false,
            .DELETE => false,
            .CONNECT => false,
            .OPTIONS => true,
            .TRACE => true,
            .PATCH => false,
        };
    }

    /// An HTTP method is idempotent if an identical request can be made once or several times in a row with the same effect while leaving the server in the same state.
    /// https://developer.mozilla.org/en-US/docs/Glossary/Idempotent
    /// https://datatracker.ietf.org/doc/html/rfc7231#section-4.2.2
    pub fn idempotent(self: Method) bool {
        return switch (self) {
            .GET => true,
            .HEAD => true,
            .POST => false,
            .PUT => true,
            .DELETE => true,
            .CONNECT => false,
            .OPTIONS => true,
            .TRACE => true,
            .PATCH => false,
        };
    }

    /// A cacheable response is an HTTP response that can be cached, that is stored to be retrieved and used later, saving a new request to the server.
    /// https://developer.mozilla.org/en-US/docs/Glossary/cacheable
    /// https://datatracker.ietf.org/doc/html/rfc7231#section-4.2.3
    pub fn cacheable(self: Method) bool {
        return switch (self) {
            .GET => true,
            .HEAD => true,
            .POST => false,
            .PUT => false,
            .DELETE => false,
            .CONNECT => false,
            .OPTIONS => false,
            .TRACE => false,
            .PATCH => false,
        };
    }
};
