/// MAC verification failed - The tag doesn't verify for the given ciphertext and secret key
pub const AuthenticationError = error{AuthenticationFailed};

/// The requested output length is too long for the chosen algorithm
pub const OutputTooLongError = error{OutputTooLong};

/// Finite field operation returned the identity element
pub const IdentityElementError = error{IdentityElement};

/// Encoded input cannot be decoded
pub const EncodingError = error{InvalidEncoding};

/// The signature does't verify for the given message and public key
pub const SignatureVerificationError = error{SignatureVerificationFailed};

/// Both a public and secret key have been provided, but they are incompatible
pub const KeyMismatchError = error{KeyMismatch};

/// Encoded input is not in canonical form
pub const NonCanonicalError = error{NonCanonical};

/// Square root has no solutions
pub const NotSquareError = error{NotSquare};

/// Verification string doesn't match the provided password and parameters
pub const PasswordVerificationError = error{PasswordVerificationFailed};

/// Parameters would be insecure to use
pub const WeakParametersError = error{WeakParameters};

/// Public key would be insecure to use
pub const WeakPublicKeyError = error{WeakPublicKey};

/// Any error related to cryptography operations
pub const Error = AuthenticationError || OutputTooLongError || IdentityElementError || EncodingError || SignatureVerificationError || KeyMismatchError || NonCanonicalError || NotSquareError || PasswordVerificationError || WeakParametersError || WeakPublicKeyError;
