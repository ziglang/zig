/*
 * Copyright (c) 2022-2023 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#ifndef NATIVE_OH_HUKS_TYPE_H
#define NATIVE_OH_HUKS_TYPE_H

/**
 * @addtogroup HuksTypeApi
 * @{
 *
 * @brief Defines the macros, enumerated values, data structures,
 *    and error codes used by OpenHarmony Universal KeyStore (HUKS) APIs.
 *
 * @syscap SystemCapability.Security.Huks
 * @since 9
 * @version 1.0
 */

/**
 * @file native_huks_type.h
 *
 * @brief Defines the structure and enumeration.
 *
 * @kit UniversalKeystoreKit
 * @since 9
 * @version 1.0
 */

#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

#ifdef __cplusplus
extern "C" {
#endif

#define OH_HUKS_AE_TAG_LEN 16
#define OH_HUKS_BITS_PER_BYTE 8
#define OH_HUKS_MAX_KEY_SIZE 2048
#define OH_HUKS_AE_NONCE_LEN 12
#define OH_HUKS_MAX_KEY_ALIAS_LEN 64
#define OH_HUKS_MAX_PROCESS_NAME_LEN 50
#define OH_HUKS_MAX_RANDOM_LEN 1024
#define OH_HUKS_SIGNATURE_MIN_SIZE 64
#define OH_HUKS_MAX_OUT_BLOB_SIZE (5 * 1024 * 1024)
#define OH_HUKS_WRAPPED_FORMAT_MAX_SIZE (1024 * 1024)
#define OH_HUKS_IMPORT_WRAPPED_KEY_TOTAL_BLOBS 10
#define TOKEN_CHALLENGE_LEN 32
#define SHA256_SIGN_LEN 32
#define TOKEN_SIZE 32
#define MAX_AUTH_TIMEOUT_SECOND 60
#define SECURE_SIGN_VERSION 0x01000001

/**
 * @brief Enumerates the key purposes.
 *
 * @since 9
 * @version 1.0
 */
enum OH_Huks_KeyPurpose {
    /** Used to encrypt the plaintext. */
    OH_HUKS_KEY_PURPOSE_ENCRYPT = 1,
    /** Used to decrypt the cipher text. */
    OH_HUKS_KEY_PURPOSE_DECRYPT = 2,
    /** Used to sign data. */
    OH_HUKS_KEY_PURPOSE_SIGN = 4,
    /** Used to verify the signature. */
    OH_HUKS_KEY_PURPOSE_VERIFY = 8,
    /** Used to derive a key. */
    OH_HUKS_KEY_PURPOSE_DERIVE = 16,
    /** Used for an encrypted export. */
    OH_HUKS_KEY_PURPOSE_WRAP = 32,
    /** Used for an encrypted import. */
    OH_HUKS_KEY_PURPOSE_UNWRAP = 64,
    /** Used to generate a message authentication code (MAC). */
    OH_HUKS_KEY_PURPOSE_MAC = 128,
    /** Used for key agreement. */
    OH_HUKS_KEY_PURPOSE_AGREE = 256,
};

/**
 * @brief Enumerates the digest algorithms.
 *
 * @since 9
 * @version 1.0
 */
enum OH_Huks_KeyDigest {
    /** No digest algorithm. */
    OH_HUKS_DIGEST_NONE = 0,
    /** MD5. */
    OH_HUKS_DIGEST_MD5 = 1,
    /** SM3. */
    OH_HUKS_DIGEST_SM3 = 2,
    /** SHA-1. */
    OH_HUKS_DIGEST_SHA1 = 10,
    /** SHA-224. */
    OH_HUKS_DIGEST_SHA224 = 11,
    /** SHA-256. */
    OH_HUKS_DIGEST_SHA256 = 12,
    /** SHA-384. */
    OH_HUKS_DIGEST_SHA384 = 13,
    /** SHA-512. */
    OH_HUKS_DIGEST_SHA512 = 14,
};

/**
 * @brief Enumerates the padding algorithms.
 *
 * @since 9
 * @version 1.0
 */
enum OH_Huks_KeyPadding {
    /** No padding algorithm. */
    OH_HUKS_PADDING_NONE = 0,
    /** Optimal Asymmetric Encryption Padding (OAEP). */
    OH_HUKS_PADDING_OAEP = 1,
    /** Probabilistic Signature Scheme (PSS). */
    OH_HUKS_PADDING_PSS = 2,
    /** Public Key Cryptography Standards (PKCS) #1 v1.5. */
    OH_HUKS_PADDING_PKCS1_V1_5 = 3,
    /** PKCS #5. */
    OH_HUKS_PADDING_PKCS5 = 4,
    /** PKCS #7. */
    OH_HUKS_PADDING_PKCS7 = 5,
};

/**
 * @brief Enumerates the cipher modes.
 *
 * @since 9
 * @version 1.0
 */
enum OH_Huks_CipherMode {
    /** Electronic Code Block (ECB) mode. */
    OH_HUKS_MODE_ECB = 1,
    /** Cipher Block Chaining (CBC) mode. */
    OH_HUKS_MODE_CBC = 2,
    /** Counter (CTR) mode. */
    OH_HUKS_MODE_CTR = 3,
    /** Output Feedback (OFB) mode. */
    OH_HUKS_MODE_OFB = 4,
    /**
     * Cipher Feedback (CFB) mode.
     * @since 12
     */
    OH_HUKS_MODE_CFB = 5,
    /** Counter with CBC-MAC (CCM) mode. */
    OH_HUKS_MODE_CCM = 31,
    /** Galois/Counter (GCM) mode. */
    OH_HUKS_MODE_GCM = 32,
};

/**
 * @brief Enumerates the key sizes.
 *
 * @since 9
 * @version 1.0
 */
enum OH_Huks_KeySize {
    /** Rivest-Shamir-Adleman (RSA) key of 512 bits. */
    OH_HUKS_RSA_KEY_SIZE_512 = 512,
    /** RSA key of 768 bits. */
    OH_HUKS_RSA_KEY_SIZE_768 = 768,
    /** RSA key of 1024 bits. */
    OH_HUKS_RSA_KEY_SIZE_1024 = 1024,
    /** RSA key of 2048 bits. */
    OH_HUKS_RSA_KEY_SIZE_2048 = 2048,
    /** RSA key of 3072 bits. */
    OH_HUKS_RSA_KEY_SIZE_3072 = 3072,
    /** RSA key of 4096 bits. */
    OH_HUKS_RSA_KEY_SIZE_4096 = 4096,

    /** Elliptic Curve Cryptography (ECC) key of 224 bits. */
    OH_HUKS_ECC_KEY_SIZE_224 = 224,
    /** ECC key of 256 bits. */
    OH_HUKS_ECC_KEY_SIZE_256 = 256,
    /** ECC key of 384 bits. */
    OH_HUKS_ECC_KEY_SIZE_384 = 384,
    /** ECC key of 521 bits. */
    OH_HUKS_ECC_KEY_SIZE_521 = 521,

    /** Advanced Encryption Standard (AES) key of 128 bits. */
    OH_HUKS_AES_KEY_SIZE_128 = 128,
    /** AES key of 192 bits. */
    OH_HUKS_AES_KEY_SIZE_192 = 192,
    /** AES key of 256 bits. */
    OH_HUKS_AES_KEY_SIZE_256 = 256,
    /** AES key of 512 bits. */
    OH_HUKS_AES_KEY_SIZE_512 = 512,

    /** Curve25519 key of 256 bits. */
    OH_HUKS_CURVE25519_KEY_SIZE_256 = 256,

    /** Diffie-Hellman (DH) key of 2048 bits. */
    OH_HUKS_DH_KEY_SIZE_2048 = 2048,
    /** DH key of 3072 bits. */
    OH_HUKS_DH_KEY_SIZE_3072 = 3072,
    /** DH key of 4096 bits. */
    OH_HUKS_DH_KEY_SIZE_4096 = 4096,

    /** ShangMi2 (SM2) key of 256 bits. */
    OH_HUKS_SM2_KEY_SIZE_256 = 256,
    /** ShangMi4 (SM4) key of 128 bits. */
    OH_HUKS_SM4_KEY_SIZE_128 = 128,
};

/**
 * @brief Enumerates the key algorithms.
 *
 * @since 9
 * @version 1.0
 */
enum OH_Huks_KeyAlg {
    /** RSA. */
    OH_HUKS_ALG_RSA = 1,
    /** ECC. */
    OH_HUKS_ALG_ECC = 2,
    /** DSA. */
    OH_HUKS_ALG_DSA = 3,

    /** AES. */
    OH_HUKS_ALG_AES = 20,
    /** HMAC. */
    OH_HUKS_ALG_HMAC = 50,
    /** HKDF. */
    OH_HUKS_ALG_HKDF = 51,
    /** PBKDF2. */
    OH_HUKS_ALG_PBKDF2 = 52,

    /** ECDH. */
    OH_HUKS_ALG_ECDH = 100,
    /** X25519. */
    OH_HUKS_ALG_X25519 = 101,
    /** Ed25519. */
    OH_HUKS_ALG_ED25519 = 102,
    /** DH. */
    OH_HUKS_ALG_DH = 103,

    /** SM2. */
    OH_HUKS_ALG_SM2 = 150,
    /** SM3. */
    OH_HUKS_ALG_SM3 = 151,
    /** SM4. */
    OH_HUKS_ALG_SM4 = 152,
};

/**
 * @brief Enumerates the algorithm suites required for ciphertext imports.
 *
 * @since 9
 * @version 1.0
 */
enum OH_Huks_AlgSuite {
    /** Key material format (Length-Value format), X25519 key agreement, and AES-256-GCM encryption and decryption.
     *  | x25519_plain_pubkey_length  (4 Byte) | x25519_plain_pubkey |  agreekey_aad_length (4 Byte) | agreekey_aad
     *  |   agreekey_nonce_length     (4 Byte) |   agreekey_nonce    |
     *  |   agreekey_aead_tag_len     (4 Byte) |  agreekey_aead_tag  |
     *  |    kek_enc_data_length      (4 Byte) |    kek_enc_data     |    kek_aad_length    (4 Byte) | kek_aad
     *  |      kek_nonce_length       (4 Byte) |      kek_nonce      |   kek_aead_tag_len   (4 Byte) | kek_aead_tag
     *  |   key_material_size_len     (4 Byte) |  key_material_size  |   key_mat_enc_length (4 Byte) | key_mat_enc_data
     */
    OH_HUKS_UNWRAP_SUITE_X25519_AES_256_GCM_NOPADDING = 1,

    /** Key material format (Length-Value format), ECDH-p256 key agreement, and AES-256-GCM encryption and decryption.
     *  |  ECC_plain_pubkey_length    (4 Byte) |  ECC_plain_pubkey   |  agreekey_aad_length (4 Byte) | agreekey_aad
     *  |   agreekey_nonce_length     (4 Byte) |   agreekey_nonce    |
     *  |   agreekey_aead_tag_len     (4 Byte) | agreekey_aead_tag   |
     *  |    kek_enc_data_length      (4 Byte) |    kek_enc_data     |    kek_aad_length    (4 Byte) | kek_aad
     *  |      kek_nonce_length       (4 Byte) |      kek_nonce      |   kek_aead_tag_len   (4 Byte) | kek_aead_tag
     *  |   key_material_size_len     (4 Byte) |  key_material_size  |   key_mat_enc_length (4 Byte) | key_mat_enc_data
     */
    OH_HUKS_UNWRAP_SUITE_ECDH_AES_256_GCM_NOPADDING = 2,
};

/**
 * @brief Enumerates the key generation types.
 *
 * @since 9
 * @version 1.0
 */
enum OH_Huks_KeyGenerateType {
    /** Key generated by default. */
    OH_HUKS_KEY_GENERATE_TYPE_DEFAULT = 0,
    /** Derived key. */
    OH_HUKS_KEY_GENERATE_TYPE_DERIVE = 1,
    /** Key obtained by key agreement. */
    OH_HUKS_KEY_GENERATE_TYPE_AGREE = 2,
};

/**
 * @brief Enumerates the key generation modes.
 *
 * @since 9
 * @version 1.0
 */
enum OH_Huks_KeyFlag {
    /** Import a public key using an API. */
    OH_HUKS_KEY_FLAG_IMPORT_KEY = 1,
    /** Generate a key by using an API. */
    OH_HUKS_KEY_FLAG_GENERATE_KEY = 2,
    /** Generate a key by using a key agreement API. */
    OH_HUKS_KEY_FLAG_AGREE_KEY = 3,
    /** Derive a key by using an API. */
    OH_HUKS_KEY_FLAG_DERIVE_KEY = 4,
};

/**
 * @brief Enumerates the key storage modes.
 *
 * @since 9
 * @version 1.0
 */
enum OH_Huks_KeyStorageType {
    /** The key is managed locally. */
    OH_HUKS_STORAGE_TEMP = 0,
    /** The key is managed by the HUKS service. */
    OH_HUKS_STORAGE_PERSISTENT = 1,
    /** The key is only used in huks. */
    OH_HUKS_STORAGE_ONLY_USED_IN_HUKS = 2,
    /** The key can be allowed to export. */
    OH_HUKS_STORAGE_KEY_EXPORT_ALLOWED = 3,
};

/**
 * @brief Enumerates the types of keys to import. By default,
 *    a public key is imported. This field is not required when a symmetric key is imported.
 *
 * @since 9
 * @version 1.0
 */
enum OH_Huks_ImportKeyType {
    /** Public key. */
    OH_HUKS_KEY_TYPE_PUBLIC_KEY = 0,
    /** Private key. */
    OH_HUKS_KEY_TYPE_PRIVATE_KEY = 1,
    /** Public and private key pair. */
    OH_HUKS_KEY_TYPE_KEY_PAIR = 2,
};

/**
 * @brief Enumerates the key storage modes.
 *
 * @since 10
 * @version 1.0
 */
enum OH_Huks_RsaPssSaltLenType {
    /** Salt length matches digest. */
    OH_HUKS_RSA_PSS_SALT_LEN_DIGEST = 0,
    /** Set salt length to maximum possible, default type. */
    OH_HUKS_RSA_PSS_SALT_LEN_MAX = 1,
};

/**
 * @brief Enumerates the error codes.
 *
 * @since 9
 * @version 1.0
 */
enum  OH_Huks_ErrCode {
    /** The operation is successful. */
    OH_HUKS_SUCCESS = 0,
    /** Permission verification failed. */
    OH_HUKS_ERR_CODE_PERMISSION_FAIL = 201,
    /** Invalid parameters are detected. */
    OH_HUKS_ERR_CODE_ILLEGAL_ARGUMENT = 401,
    /** The API is not supported. */
    OH_HUKS_ERR_CODE_NOT_SUPPORTED_API = 801,

    /** The feature is not supported. */
    OH_HUKS_ERR_CODE_FEATURE_NOT_SUPPORTED = 12000001,
    /** Key algorithm parameters are missing. */
    OH_HUKS_ERR_CODE_MISSING_CRYPTO_ALG_ARGUMENT = 12000002,
    /** Invalid key algorithm parameters are detected. */
    OH_HUKS_ERR_CODE_INVALID_CRYPTO_ALG_ARGUMENT = 12000003,
    /** Failed to operate the file. */
    OH_HUKS_ERR_CODE_FILE_OPERATION_FAIL = 12000004,
    /** The process communication failed. */
    OH_HUKS_ERR_CODE_COMMUNICATION_FAIL = 12000005,
    /** Failed to operate the algorithm library. */
    OH_HUKS_ERR_CODE_CRYPTO_FAIL = 12000006,
    /** Failed to access the key because the key has expired. */
    OH_HUKS_ERR_CODE_KEY_AUTH_PERMANENTLY_INVALIDATED = 12000007,
    /** Failed to access the key because the authentication has failed. */
    OH_HUKS_ERR_CODE_KEY_AUTH_VERIFY_FAILED = 12000008,
    /** Key access timed out. */
    OH_HUKS_ERR_CODE_KEY_AUTH_TIME_OUT = 12000009,
    /** The number of key operation sessions has reached the limit. */
    OH_HUKS_ERR_CODE_SESSION_LIMIT = 12000010,
    /** The entity does not exist. */
    OH_HUKS_ERR_CODE_ITEM_NOT_EXIST = 12000011,
    /** Internal error. */
    OH_HUKS_ERR_CODE_INTERNAL_ERROR = 12000012,
    /** The authentication credential does not exist. */
    OH_HUKS_ERR_CODE_CREDENTIAL_NOT_EXIST = 12000013,
    /** The memory is not sufficient. */
    OH_HUKS_ERR_CODE_INSUFFICIENT_MEMORY = 12000014,
    /** Failed to call service. */
    OH_HUKS_ERR_CODE_CALL_SERVICE_FAILED = 12000015,
    /**
     * A device password is required but not set.
     *
     * @since 11
     */
    OH_HUKS_ERR_CODE_DEVICE_PASSWORD_UNSET = 12000016,
};

/**
 * @brief Enumerates the tag types.
 * @see OH_Huks_Param
 *
 * @since 9
 * @version 1.0
 */
enum OH_Huks_TagType {
    /** Invalid tag type. */
    OH_HUKS_TAG_TYPE_INVALID = 0 << 28,
    /** int32_t. */
    OH_HUKS_TAG_TYPE_INT = 1 << 28,
    /** uin32_t. */
    OH_HUKS_TAG_TYPE_UINT = 2 << 28,
    /** uin64_t. */
    OH_HUKS_TAG_TYPE_ULONG = 3 << 28,
    /** Boolean. */
    OH_HUKS_TAG_TYPE_BOOL = 4 << 28,
    /** OH_Huks_Blob. */
    OH_HUKS_TAG_TYPE_BYTES = 5 << 28,
};

/**
 * @brief Enumerates the user authentication types.
 *
 * @since 9
 * @version 1.0
 */
enum OH_Huks_UserAuthType {
    /** Fingerprint authentication. */
    OH_HUKS_USER_AUTH_TYPE_FINGERPRINT = 1 << 0,
    /** Facial authentication. */
    OH_HUKS_USER_AUTH_TYPE_FACE = 1 << 1,
    /** PIN authentication. */
    OH_HUKS_USER_AUTH_TYPE_PIN = 1 << 2,
};

/**
 * @brief Enumerates the access control types.
 *
 * @since 9
 * @version 1.0
 */
enum OH_Huks_AuthAccessType {
    /** The key is invalid after the password is cleared. */
    OH_HUKS_AUTH_ACCESS_INVALID_CLEAR_PASSWORD = 1 << 0,
    /** The key is invalid after a new biometric feature is enrolled. */
    OH_HUKS_AUTH_ACCESS_INVALID_NEW_BIO_ENROLL = 1 << 1,
    /**
     * The key is always valid.
     *
     * @since 11
     */
    OH_HUKS_AUTH_ACCESS_ALWAYS_VALID = 1 << 2,
};

/**
 * @brief Enumerates key file storage authentication levels.
 *
 * @since 11
 */
enum OH_Huks_AuthStorageLevel {
    /**
     * Key file storage security level for device encryption standard.
     * @since 11
     */
    OH_HUKS_AUTH_STORAGE_LEVEL_DE = 0,
    /**
     * Key file storage security level for credential encryption standard.
     * @since 11
     */
    OH_HUKS_AUTH_STORAGE_LEVEL_CE = 1,
    /**
     * Key file storage security level for enhanced credential encryption standard.
     * @since 11
     */
    OH_HUKS_AUTH_STORAGE_LEVEL_ECE = 2,
};

/**
 * @brief Enumerates the types of the challenges generated when a key is used.
 * @see OH_Huks_ChallengePosition
 *
 * @since 9
 * @version 1.0
 */
enum OH_Huks_ChallengeType {
    /** Normal challenge, which is of 32 bytes by default. */
    OH_HUKS_CHALLENGE_TYPE_NORMAL = 0,
    /** Custom challenge, which supports only one authentication for multiple keys.
     *  The valid value of a custom challenge is of 8 bytes.
     */
    OH_HUKS_CHALLENGE_TYPE_CUSTOM = 1,
    /** Challenge is not required. */
    OH_HUKS_CHALLENGE_TYPE_NONE = 2,
};

/**
 * @brief Enumerates the positions of the 8-byte valid value in a custom challenge generated.
 *
 * @since 9
 * @version 1.0
 */
enum OH_Huks_ChallengePosition {
    /** Bytes 0 to 7. */
    OH_HUKS_CHALLENGE_POS_0 = 0,
    /** Bytes 8 to 15. */
    OH_HUKS_CHALLENGE_POS_1,
    /** Bytes 16 to 23. */
    OH_HUKS_CHALLENGE_POS_2,
    /** Bytes 24 to 31. */
    OH_HUKS_CHALLENGE_POS_3,
};

/**
 * @brief Enumerates the signature types of the keys generated or imported.
 *
 * @since 9
 * @version 1.0
 */
enum OH_Huks_SecureSignType {
    /**
     *  The signature carries authentication information. This field is specified when a key
     *  is generated or imported. When the key is used to sign data, the data will be added with
     *  the authentication information and then be signed.
     */
    OH_HUKS_SECURE_SIGN_WITH_AUTHINFO = 1,
};

/**
 * @brief Enumerates the tag values used in parameter sets.
 *
 * @since 9
 * @version 1.0
 */
enum OH_Huks_Tag {
    /** Tags for key parameters. The value range is 1 to 200. */
    /** Algorithm. */
    OH_HUKS_TAG_ALGORITHM = OH_HUKS_TAG_TYPE_UINT | 1,
    /** Key purpose. */
    OH_HUKS_TAG_PURPOSE = OH_HUKS_TAG_TYPE_UINT | 2,
    /** Key size. */
    OH_HUKS_TAG_KEY_SIZE = OH_HUKS_TAG_TYPE_UINT | 3,
    /** Digest algorithm. */
    OH_HUKS_TAG_DIGEST = OH_HUKS_TAG_TYPE_UINT | 4,
    /** Padding algorithm. */
    OH_HUKS_TAG_PADDING = OH_HUKS_TAG_TYPE_UINT | 5,
    /** Cipher mode. */
    OH_HUKS_TAG_BLOCK_MODE = OH_HUKS_TAG_TYPE_UINT | 6,
    /** Key type. */
    OH_HUKS_TAG_KEY_TYPE = OH_HUKS_TAG_TYPE_UINT | 7,
    /** Associated authentication data. */
    OH_HUKS_TAG_ASSOCIATED_DATA = OH_HUKS_TAG_TYPE_BYTES | 8,
    /** Field for key encryption and decryption. */
    OH_HUKS_TAG_NONCE = OH_HUKS_TAG_TYPE_BYTES | 9,
    /** Initialized vector (IV). */
    OH_HUKS_TAG_IV = OH_HUKS_TAG_TYPE_BYTES | 10,

    /** Information generated during key derivation. */
    OH_HUKS_TAG_INFO = OH_HUKS_TAG_TYPE_BYTES | 11,
    /** Salt value used for key derivation. */
    OH_HUKS_TAG_SALT = OH_HUKS_TAG_TYPE_BYTES | 12,
    /** Number of iterations for key derivation. */
    OH_HUKS_TAG_ITERATION = OH_HUKS_TAG_TYPE_UINT | 14,

    /** Type of the generated key. For details, see {@link OH_Huks_KeyGenerateType}. */
    OH_HUKS_TAG_KEY_GENERATE_TYPE = OH_HUKS_TAG_TYPE_UINT | 15,
    /** Algorithm used in key agreement. */
    OH_HUKS_TAG_AGREE_ALG = OH_HUKS_TAG_TYPE_UINT | 19,
    /** Alias of the public key used for key agreement. */
    OH_HUKS_TAG_AGREE_PUBLIC_KEY_IS_KEY_ALIAS = OH_HUKS_TAG_TYPE_BOOL | 20,
    /** Alias of the private key used for key agreement. */
    OH_HUKS_TAG_AGREE_PRIVATE_KEY_ALIAS = OH_HUKS_TAG_TYPE_BYTES | 21,
    /** Public key used for key agreement. */
    OH_HUKS_TAG_AGREE_PUBLIC_KEY = OH_HUKS_TAG_TYPE_BYTES | 22,
    /** Alias of the key. */
    OH_HUKS_TAG_KEY_ALIAS = OH_HUKS_TAG_TYPE_BYTES | 23,
    /** Size of the derived key. */
    OH_HUKS_TAG_DERIVE_KEY_SIZE = OH_HUKS_TAG_TYPE_UINT | 24,
    /** Type of the key to import. For details, see {@link OH_Huks_ImportKeyType}. */
    OH_HUKS_TAG_IMPORT_KEY_TYPE = OH_HUKS_TAG_TYPE_UINT | 25,
    /** Algorithm suite required for encrypted imports. */
    OH_HUKS_TAG_UNWRAP_ALGORITHM_SUITE = OH_HUKS_TAG_TYPE_UINT | 26,
    /** Storage mode of derived or agree keys. For details, see {@link OH_Huks_KeyStorageType}. */
    OH_HUKS_TAG_DERIVED_AGREED_KEY_STORAGE_FLAG = OH_HUKS_TAG_TYPE_UINT | 29,
    /** Type of rsa pss salt length. */
    OH_HUKS_TAG_RSA_PSS_SALT_LEN_TYPE = OH_HUKS_TAG_TYPE_UINT | 30,

    /** Tags for access control and user authentication. The value range is 301 to 500. */
    /** All users in the multi-user scenario. */
    OH_HUKS_TAG_ALL_USERS = OH_HUKS_TAG_TYPE_BOOL | 301,
    /** Multi-user ID. */
    OH_HUKS_TAG_USER_ID = OH_HUKS_TAG_TYPE_UINT | 302,
    /** Specifies whether key access control is required. */
    OH_HUKS_TAG_NO_AUTH_REQUIRED = OH_HUKS_TAG_TYPE_BOOL | 303,
    /** User authentication type in key access control. */
    OH_HUKS_TAG_USER_AUTH_TYPE = OH_HUKS_TAG_TYPE_UINT | 304,
    /** Timeout duration for key access. */
    OH_HUKS_TAG_AUTH_TIMEOUT = OH_HUKS_TAG_TYPE_UINT | 305,
    /** Authentication token for the key. */
    OH_HUKS_TAG_AUTH_TOKEN = OH_HUKS_TAG_TYPE_BYTES | 306,
    /**
     *  Access control type. For details, see {@link OH_Huks_AuthAccessType}.
     *  This parameter must be set together with the user authentication type.
     */
    OH_HUKS_TAG_KEY_AUTH_ACCESS_TYPE = OH_HUKS_TAG_TYPE_UINT | 307,
    /** Signature type for the key to be generated or imported. */
    OH_HUKS_TAG_KEY_SECURE_SIGN_TYPE = OH_HUKS_TAG_TYPE_UINT | 308,
    /** Challenge type. For details, see {@link OH_Huks_ChallengeType}. */
    OH_HUKS_TAG_CHALLENGE_TYPE = OH_HUKS_TAG_TYPE_UINT | 309,
    /**
     *  Position of the 8-byte valid value in a custom challenge.
     *  For details, see {@link OH_Huks_ChallengePosition}.
     */
    OH_HUKS_TAG_CHALLENGE_POS = OH_HUKS_TAG_TYPE_UINT | 310,

    /** Purpose of key authentication */
    OH_HUKS_TAG_KEY_AUTH_PURPOSE = OH_HUKS_TAG_TYPE_UINT | 311,

    /**
     * Security level of access control for key file storage, whose optional values are from OH_Huks_AuthStorageLevel.
     *
     * @since 11
     */
    OH_HUKS_TAG_AUTH_STORAGE_LEVEL = OH_HUKS_TAG_TYPE_UINT | 316,

    /** Tags for key attestation. The value range is 501 to 600. */
    /** Challenge value used in the attestation. */
    OH_HUKS_TAG_ATTESTATION_CHALLENGE = OH_HUKS_TAG_TYPE_BYTES | 501,
    /** Application ID used in the attestation. */
    OH_HUKS_TAG_ATTESTATION_APPLICATION_ID = OH_HUKS_TAG_TYPE_BYTES | 502,
    /** Alias of the key. */
    OH_HUKS_TAG_ATTESTATION_ID_ALIAS = OH_HUKS_TAG_TYPE_BYTES | 511,
    /** Security level used in the attestation. */
    OH_HUKS_TAG_ATTESTATION_ID_SEC_LEVEL_INFO = OH_HUKS_TAG_TYPE_BYTES | 514,
    /** Version information used in the attestation. */
    OH_HUKS_TAG_ATTESTATION_ID_VERSION_INFO = OH_HUKS_TAG_TYPE_BYTES | 515,

    /**
     * 601 to 1000 are reserved for other tags.
     *
     * Extended tags. The value range is 1001 to 9999.
     */
    /** Specifies whether it is a key alias. */
    OH_HUKS_TAG_IS_KEY_ALIAS = OH_HUKS_TAG_TYPE_BOOL | 1001,
    /** Key storage mode. For details, see {@link OH_Huks_KeyStorageType}. */
    OH_HUKS_TAG_KEY_STORAGE_FLAG = OH_HUKS_TAG_TYPE_UINT | 1002,
    /** Specifies whether to allow the key to be wrapped. */
    OH_HUKS_TAG_IS_ALLOWED_WRAP = OH_HUKS_TAG_TYPE_BOOL | 1003,
    /** Key wrap type. */
    OH_HUKS_TAG_KEY_WRAP_TYPE = OH_HUKS_TAG_TYPE_UINT | 1004,
    /** Authentication ID. */
    OH_HUKS_TAG_KEY_AUTH_ID = OH_HUKS_TAG_TYPE_BYTES | 1005,
    /** Role of the key. */
    OH_HUKS_TAG_KEY_ROLE = OH_HUKS_TAG_TYPE_UINT | 1006,
    /** Key flag. For details, see {@link OH_Huks_KeyFlag}. */
    OH_HUKS_TAG_KEY_FLAG = OH_HUKS_TAG_TYPE_UINT | 1007,
    /** Specifies whether this API is asynchronous. */
    OH_HUKS_TAG_IS_ASYNCHRONIZED = OH_HUKS_TAG_TYPE_UINT | 1008,
    /** Key domain. */
    OH_HUKS_TAG_KEY_DOMAIN = OH_HUKS_TAG_TYPE_UINT | 1011,
    /**
     * Key access control based on device password setting status.
     * True means the key can only be generated and used when the password is set.
     *
     * @since 11
     */
    OH_HUKS_TAG_IS_DEVICE_PASSWORD_SET = OH_HUKS_TAG_TYPE_BOOL | 1012,

    /** Authenticated Encryption. */
    OH_HUKS_TAG_AE_TAG = OH_HUKS_TAG_TYPE_BYTES | 10009,

    /**
     * 11000 to 12000 are reserved.
     *
     * 20001 to N are reserved for other tags.
     */
    /** Symmetric key data. */
    OH_HUKS_TAG_SYMMETRIC_KEY_DATA = OH_HUKS_TAG_TYPE_BYTES | 20001,
    /** Public key data of the asymmetric key pair. */
    OH_HUKS_TAG_ASYMMETRIC_PUBLIC_KEY_DATA = OH_HUKS_TAG_TYPE_BYTES | 20002,
    /** Private key data of the asymmetric key pair. */
    OH_HUKS_TAG_ASYMMETRIC_PRIVATE_KEY_DATA = OH_HUKS_TAG_TYPE_BYTES | 20003,
};

/**
 * @brief Defines the return data, including the result code and message.
 *
 * @since 9
 * @version 1.0
 */
struct OH_Huks_Result {
    /** Result code. */
    int32_t errorCode;
    /** Description of the result code. */
    const char *errorMsg;
    /** Other data returned. */
    uint8_t *data;
};

/**
 * @brief Defines the structure for storing data.
 *
 * @since 9
 * @version 1.0
 */
struct OH_Huks_Blob {
    /** Data size. */
    uint32_t size;
    /** Pointer to the memory in which the data is stored. */
    uint8_t *data;
};

/**
 * @brief Defines the parameter structure in a parameter set.
 *
 * @since 9
 * @version 1.0
 */
struct OH_Huks_Param {
    /** Tag value. */
    uint32_t tag;

    union {
        /** Parameter of the Boolean type. */
        bool boolParam;
        /** Parameter of the int32_t type. */
        int32_t int32Param;
        /** Parameter of the uint32_t type. */
        uint32_t uint32Param;
        /** Parameter of the uint64_t type. */
        uint64_t uint64Param;
        /** Parameter of the struct OH_Huks_Blob type. */
        struct OH_Huks_Blob blob;
    };
};

/**
 * @brief Defines the structure of the parameter set.
 *
 * @since 9
 * @version 1.0
 */
struct OH_Huks_ParamSet {
    /** Memory size of the parameter set. */
    uint32_t paramSetSize;
    /** Number of parameters in the parameter set. */
    uint32_t paramsCnt;
    /** Parameter array. */
    struct OH_Huks_Param params[];
};

/**
 * @brief Defines the structure of the certificate chain.
 *
 * @since 9
 * @version 1.0
 */
struct OH_Huks_CertChain {
    /** Pointer to the certificate data. */
    struct OH_Huks_Blob *certs;
    /** Number of certificates. */
    uint32_t certsCount;
};

/**
 * @brief Defines the key information structure.
 *
 * @since 9
 * @version 1.0
 */
struct OH_Huks_KeyInfo {
    /** Alias of the key. */
    struct OH_Huks_Blob alias;
    /** Pointer to the key parameter set. */
    struct OH_Huks_ParamSet *paramSet;
};

/**
 * @brief Defines the structure of a public key.
 *
 * @since 9
 * @version 1.0
 */
struct OH_Huks_PubKeyInfo {
    /** Algorithm of the public key. */
    enum OH_Huks_KeyAlg keyAlg;
    /** Length of the public key. */
    uint32_t keySize;
    /** Length of the n or X value. */
    uint32_t nOrXSize;
    /** Length of the e or Y value. */
    uint32_t eOrYSize;
    /** Placeholder size. */
    uint32_t placeHolder;
};

/**
 * @brief Defines the structure of an RSA key.
 *
 * @since 9
 * @version 1.0
 */
struct OH_Huks_KeyMaterialRsa {
    /** Algorithm of the key. */
    enum OH_Huks_KeyAlg keyAlg;
    /** Length of the key. */
    uint32_t keySize;
    /** Length of the n value. */
    uint32_t nSize;
    /** Length of the e value. */
    uint32_t eSize;
    /** Length of the d value. */
    uint32_t dSize;
};

/**
 * @brief Defines the structure of an ECC key.
 *
 * @since 9
 * @version 1.0
 */
struct OH_Huks_KeyMaterialEcc {
    /** Algorithm of the key. */
    enum OH_Huks_KeyAlg keyAlg;
    /** Length of the key. */
    uint32_t keySize;
    /** Length of the x value. */
    uint32_t xSize;
    /** Length of the y value. */
    uint32_t ySize;
    /** Length of the z value. */
    uint32_t zSize;
};

/**
 * @brief Defines the structure of a DSA key.
 *
 * @since 9
 * @version 1.0
 */
struct OH_Huks_KeyMaterialDsa {
    /** Algorithm of the key. */
    enum OH_Huks_KeyAlg keyAlg;
    /** Length of the key. */
    uint32_t keySize;
    /** Length of the x value. */
    uint32_t xSize;
    /** Length of the y value. */
    uint32_t ySize;
    /** Length of the p value. */
    uint32_t pSize;
    /** Length of the q value. */
    uint32_t qSize;
    /** Length of the g value. */
    uint32_t gSize;
};

/**
 * @brief Defines the structure of a DH key.
 *
 * @since 9
 * @version 1.0
 */
struct OH_Huks_KeyMaterialDh {
    /** Algorithm of the key. */
    enum OH_Huks_KeyAlg keyAlg;
    /** Length of the DH key. */
    uint32_t keySize;
    /** Length of the public key. */
    uint32_t pubKeySize;
    /** Length of the private key. */
    uint32_t priKeySize;
    /** Reserved. */
    uint32_t reserved;
};

/**
 * @brief Defines the structure of a 25519 key.
 *
 * @since 9
 * @version 1.0
 */
struct OH_Huks_KeyMaterial25519 {
    /** Algorithm of the key. */
    enum OH_Huks_KeyAlg keyAlg;
    /** Length of the 25519 key. */
    uint32_t keySize;
    /** Length of the public key. */
    uint32_t pubKeySize;
    /** Length of the private key. */
    uint32_t priKeySize;
    /** Reserved. */
    uint32_t reserved;
};

#ifdef __cplusplus
}
#endif

/** @} */
#endif /* NATIVE_OH_HUKS_TYPE_H */