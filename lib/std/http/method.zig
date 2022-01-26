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
    /// Actual behavior from servers may vary and should still be checked
    pub fn requestHasBody(self: Method) bool {
        return switch (self) {
            .POST, .PUT, .PATCH => true,
            .GET, .HEAD, .DELETE, .CONNECT, .OPTIONS, .TRACE => false,
        };
    }

    /// Returns true if a response to this method is allowed to have a body
    /// Actual behavior from clients may vary and should still be checked
    pub fn responseHasBody(self: Method) bool {
        return switch (self) {
            .GET, .POST, .DELETE, .CONNECT, .OPTIONS, .PATCH => true,
            .HEAD, .PUT, .TRACE => false,
        };
    }

    /// An HTTP method is safe if it doesn't alter the state of the server.
    /// https://developer.mozilla.org/en-US/docs/Glossary/Safe/HTTP
    /// https://datatracker.ietf.org/doc/html/rfc7231#section-4.2.1
    pub fn safe(self: Method) bool {
        return switch (self) {
            .GET, .HEAD, .OPTIONS, .TRACE => true,
            .POST, .PUT, .DELETE, .CONNECT, .PATCH => false,
        };
    }

    /// An HTTP method is idempotent if an identical request can be made once or several times in a row with the same effect while leaving the server in the same state.
    /// https://developer.mozilla.org/en-US/docs/Glossary/Idempotent
    /// https://datatracker.ietf.org/doc/html/rfc7231#section-4.2.2
    pub fn idempotent(self: Method) bool {
        return switch (self) {
            .GET, .HEAD, .PUT, .DELETE, .OPTIONS, .TRACE => true,
            .CONNECT, .POST, .PATCH => false,
        };
    }

    /// A cacheable response is an HTTP response that can be cached, that is stored to be retrieved and used later, saving a new request to the server.
    /// https://developer.mozilla.org/en-US/docs/Glossary/cacheable
    /// https://datatracker.ietf.org/doc/html/rfc7231#section-4.2.3
    pub fn cacheable(self: Method) bool {
        return switch (self) {
            .GET, .HEAD => true,
            .POST, .PUT, .DELETE, .CONNECT, .OPTIONS, .TRACE, .PATCH => false,
        };
    }
};
