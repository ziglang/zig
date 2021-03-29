pub const Error = error{
    /// MAC verification failed - The tag doesn't verify for the given ciphertext and secret key
    AuthenticationFailed,

    /// The requested output length is too long for the chosen algorithm
    OutputTooLong,

    /// Finite field operation returned the identity element
    IdentityElement,

    /// Encoded input cannot be decoded
    InvalidEncoding,

    /// The signature does't verify for the given message and public key
    SignatureVerificationFailed,

    /// Both a public and secret key have been provided, but they are incompatible
    KeyMismatch,

    /// Encoded input is not in canonical form
    NonCanonical,

    /// Square root has no solutions
    NotSquare,

    /// Verification string doesn't match the provided password and parameters
    PasswordVerificationFailed,

    /// Parameters would be insecure to use
    WeakParameters,

    /// Public key would be insecure to use
    WeakPublicKey,
};
