/*
 * Copyright (c) 2024 Huawei Device Co., Ltd.
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

#ifndef TEE_CRYPTO_API_H
#define TEE_CRYPTO_API_H

/**
 * @addtogroup TeeTrusted
 * @{
 *
 * @brief TEE(Trusted Excution Environment) API.
 * Provides security capability APIs such as trusted storage, encryption and decryption,
 * and trusted time for trusted application development.
 *
 * @since 12
 */

/**
 * @file tee_crypto_api.h
 *
 * @brief Provides APIs for cryptographic operations.
 *
 * You can use these APIs to implement encryption and decryption.
 *
 * @library NA
 * @kit TEE Kit
 * @syscap SystemCapability.Tee.TeeClient
 * @since 12
 * @version 1.0
 */

#include <pthread.h> /* pthread_mutex_t */
#include <tee_defines.h>
#include <tee_mem_mgmt_api.h>

#ifdef __cplusplus
extern "C" {
#endif

#ifndef NULL
/**
 * @brief Definition of <b>NULL</b>.
 *
 * @since 12
 */
#define NULL ((void *)0)
#endif
/**
 * @brief Defines the maximum key length, in bits.
 *
 * @since 12
 */
#define TEE_MAX_KEY_SIZE_IN_BITS      (1024 * 8)
/**
 * @brief Defines the length of the SW_RSA key, in bytes.
 *
 * @since 12
 */
#define SW_RSA_KEYLEN                 1024
/**
 * @brief Defines the maximum length of other Diffie-Hellman (DH) information, in bytes.
 *
 * @since 12
 */
#define TEE_DH_MAX_SIZE_OF_OTHER_INFO 64 /* bytes */

/**
 * @brief Enumerates the cryptographic operation handles.
 *
 * @since 12
 */
enum __TEE_Operation_Constants {
    /** Cipher */
    TEE_OPERATION_CIPHER               = 0x1,
    /** MAC */
    TEE_OPERATION_MAC                  = 3,
    /** AE */
    TEE_OPERATION_AE                   = 4,
    /** Digest */
    TEE_OPERATION_DIGEST               = 5,
    /** Asymmetric Cipher */
    TEE_OPERATION_ASYMMETRIC_CIPHER    = 6,
    /** Asymmetric Signature */
    TEE_OPERATION_ASYMMETRIC_SIGNATURE = 7,
    /** Key Derivation */
    TEE_OPERATION_KEY_DERIVATION       = 8,
};

/**
 * @brief Enumerates the cryptographic algorithms.
 *
 * @since 12
 */
enum __tee_crypto_algorithm_id {
    /** Invalid algorithm */
    TEE_ALG_INVALID                      = 0x0,
    /** AES_ECB_NOPAD */
    TEE_ALG_AES_ECB_NOPAD                = 0x10000010,
    /** AES_CBC_NOPAD */
    TEE_ALG_AES_CBC_NOPAD                = 0x10000110,
    /** AES_CTR */
    TEE_ALG_AES_CTR                      = 0x10000210,
    /** AES_CTS */
    TEE_ALG_AES_CTS                      = 0x10000310,
    /** AES_XTS */
    TEE_ALG_AES_XTS                      = 0x10000410,
    /** AES_CBC_MAC_NOPAD */
    TEE_ALG_AES_CBC_MAC_NOPAD            = 0x30000110,
    /** AES_CBC_MAC_PKCS5 */
    TEE_ALG_AES_CBC_MAC_PKCS5            = 0x30000510,
    /** AES_CMAC */
    TEE_ALG_AES_CMAC                     = 0x30000610,
    /** AES_GMAC */
    TEE_ALG_AES_GMAC                     = 0x30000810,
    /** AES_CCM */
    TEE_ALG_AES_CCM                      = 0x40000710,
    /** AES_GCM */
    TEE_ALG_AES_GCM                      = 0x40000810,
    /** DES_ECB_NOPAD */
    TEE_ALG_DES_ECB_NOPAD                = 0x10000011,
    /** DES_CBC_NOPAD */
    TEE_ALG_DES_CBC_NOPAD                = 0x10000111,
    /** DES_CBC_MAC_NOPAD */
    TEE_ALG_DES_CBC_MAC_NOPAD            = 0x30000111,
    /** DES_CBC_MAC_PKCS5 */
    TEE_ALG_DES_CBC_MAC_PKCS5            = 0x30000511,
    /** DES3_ECB_NOPAD */
    TEE_ALG_DES3_ECB_NOPAD               = 0x10000013,
    /** DES3_CBC_NOPAD */
    TEE_ALG_DES3_CBC_NOPAD               = 0x10000113,
    /** DES3_CBC_MAC_NOPAD */
    TEE_ALG_DES3_CBC_MAC_NOPAD           = 0x30000113,
    /** DES3_CBC_MAC_PKCS5 */
    TEE_ALG_DES3_CBC_MAC_PKCS5           = 0x30000513,
    /** RSASSA_PKCS1_V1_5_MD5 */
    TEE_ALG_RSASSA_PKCS1_V1_5_MD5        = 0x70001830,
    /** RSASSA_PKCS1_V1_5_SHA1 */
    TEE_ALG_RSASSA_PKCS1_V1_5_SHA1       = 0x70002830,
    /** RSASSA_PKCS1_V1_5_SHA224 */
    TEE_ALG_RSASSA_PKCS1_V1_5_SHA224     = 0x70003830,
    /** RSASSA_PKCS1_V1_5_SHA256 */
    TEE_ALG_RSASSA_PKCS1_V1_5_SHA256     = 0x70004830,
    /** RSASSA_PKCS1_V1_5_SHA384 */
    TEE_ALG_RSASSA_PKCS1_V1_5_SHA384     = 0x70005830,
    /** RSASSA_PKCS1_V1_5_SHA512 */
    TEE_ALG_RSASSA_PKCS1_V1_5_SHA512     = 0x70006830,
    /** RSASSA_PKCS1_PSS_MGF1_MD5 */
    TEE_ALG_RSASSA_PKCS1_PSS_MGF1_MD5    = 0x70111930,
    /** RSASSA_PKCS1_PSS_MGF1_SHA1 */
    TEE_ALG_RSASSA_PKCS1_PSS_MGF1_SHA1   = 0x70212930,
    /** RSASSA_PKCS1_PSS_MGF1_SHA224 */
    TEE_ALG_RSASSA_PKCS1_PSS_MGF1_SHA224 = 0x70313930,
    /** RSASSA_PKCS1_PSS_MGF1_SHA256 */
    TEE_ALG_RSASSA_PKCS1_PSS_MGF1_SHA256 = 0x70414930,
    /** RSASSA_PKCS1_PSS_MGF1_SHA384 */
    TEE_ALG_RSASSA_PKCS1_PSS_MGF1_SHA384 = 0x70515930,
    /** RSASSA_PKCS1_PSS_MGF1_SHA512 */
    TEE_ALG_RSASSA_PKCS1_PSS_MGF1_SHA512 = 0x70616930,
    /** RSAES_PKCS1_V1_5 */
    TEE_ALG_RSAES_PKCS1_V1_5             = 0x60000130,
    /** RSAES_PKCS1_OAEP_MGF1_SHA1 */
    TEE_ALG_RSAES_PKCS1_OAEP_MGF1_SHA1   = 0x60210230,
    /** RSAES_PKCS1_OAEP_MGF1_SHA224 */
    TEE_ALG_RSAES_PKCS1_OAEP_MGF1_SHA224 = 0x60211230,
    /** RSAES_PKCS1_OAEP_MGF1_SHA256 */
    TEE_ALG_RSAES_PKCS1_OAEP_MGF1_SHA256 = 0x60212230,
    /** RSAES_PKCS1_OAEP_MGF1_SHA384 */
    TEE_ALG_RSAES_PKCS1_OAEP_MGF1_SHA384 = 0x60213230,
    /** RSAES_PKCS1_OAEP_MGF1_SHA512 */
    TEE_ALG_RSAES_PKCS1_OAEP_MGF1_SHA512 = 0x60214230,
    /** RSA_NOPAD */
    TEE_ALG_RSA_NOPAD                    = 0x60000030,
    /** DSA_SHA1 */
    TEE_ALG_DSA_SHA1                     = 0x70002131,
    /** DSA_SHA224 */
    TEE_ALG_DSA_SHA224                   = 0x70003131,
    /** DSA_SHA256 */
    TEE_ALG_DSA_SHA256                   = 0x70004131,
    /** DH_DERIVE_SHARED_SECRET */
    TEE_ALG_DH_DERIVE_SHARED_SECRET      = 0x80000032,
    /** MD5 */
    TEE_ALG_MD5                          = 0x50000001,
    /** SHA1 */
    TEE_ALG_SHA1                         = 0x50000002,
    /** SHA224 */
    TEE_ALG_SHA224                       = 0x50000003,
    /** SHA256 */
    TEE_ALG_SHA256                       = 0x50000004,
    /** SHA384 */
    TEE_ALG_SHA384                       = 0x50000005,
    /** SHA512 */
    TEE_ALG_SHA512                       = 0x50000006,
    /** HMAC_MD5 */
    TEE_ALG_HMAC_MD5                     = 0x30000001,
    /** HMAC_SHA1 */
    TEE_ALG_HMAC_SHA1                    = 0x30000002,
    /** HMAC_SHA1 */
    TEE_ALG_HMAC_SHA224                  = 0x30000003,
    /** HMAC_SHA224 */
    TEE_ALG_HMAC_SHA256                  = 0x30000004,
    /** HMAC_SHA256 */
    TEE_ALG_HMAC_SHA384                  = 0x30000005,
    /** HMAC_SHA384 */
    TEE_ALG_HMAC_SHA512                  = 0x30000006,
    /** HMAC_SHA512 */
    TEE_ALG_HMAC_SM3                     = 0x30000007,
    /** HMAC_SM3 */
    TEE_ALG_AES_ECB_PKCS5                = 0x10000020,
    /** AES_ECB_PKCS5 */
    TEE_ALG_AES_CBC_PKCS5                = 0x10000220,
    /** AES_CBC_PKCS5 */
    TEE_ALG_ECDSA_SHA1                   = 0x70001042,
    /** ECDSA_SHA1 */
    TEE_ALG_ECDSA_SHA224                 = 0x70002042,
    /** ECDSA_SHA224 */
    TEE_ALG_ECDSA_SHA256                 = 0x70003042,
    /** ECDSA_SHA256 */
    TEE_ALG_ECDSA_SHA384                 = 0x70004042,
    /** ECDSA_SHA384 */
    TEE_ALG_ECDSA_SHA512                 = 0x70005042,
    /** ECDSA_SHA512 */
    TEE_ALG_ED25519                      = 0x70005043,
    /** ED25519 */
    TEE_ALG_ECDH_DERIVE_SHARED_SECRET    = 0x80000042,
    /** ECDH_DERIVE_SHARED_SECRET */
    TEE_ALG_X25519                       = 0x80000044,
    /** X25519 */
    TEE_ALG_ECC                          = 0x80000001,
    /** ECC */
    TEE_ALG_ECDSA_P192                   = 0x70001042,
    /** ECDSA_P192 */
    TEE_ALG_ECDSA_P224                   = 0x70002042,
    /** ECDSA_P224 */
    TEE_ALG_ECDSA_P256                   = 0x70003042,
    /** ECDSA_P256 */
    TEE_ALG_ECDSA_P384                   = 0x70004042,
    /** ECDSA_P521 */
    TEE_ALG_ECDSA_P521                   = 0x70005042,
    /** ECDH_P192 */
    TEE_ALG_ECDH_P192                    = 0x80001042,
    /** ECDH_P224 */
    TEE_ALG_ECDH_P224                    = 0x80002042,
    /** ECDH_P256 */
    TEE_ALG_ECDH_P256                    = 0x80003042,
    /** ECDH_P384 */
    TEE_ALG_ECDH_P384                    = 0x80004042,
    /** ECDH_P521 */
    TEE_ALG_ECDH_P521                    = 0x80005042,
    /** SIP_HASH */
    TEE_ALG_SIP_HASH                     = 0xF0000002,
    /** SM2_DSA_SM3 */
    TEE_ALG_SM2_DSA_SM3                  = 0x70006045,
    /** SM2_PKE */
    TEE_ALG_SM2_PKE                      = 0x80000045,
    /** SM3 */
    TEE_ALG_SM3                          = 0x50000007,
    /** SM4_ECB_NOPAD */
    TEE_ALG_SM4_ECB_NOPAD                = 0x10000014,
    /** SM4_CBC_NOPAD */
    TEE_ALG_SM4_CBC_NOPAD                = 0x10000114,
    /** SM4_CBC_PKCS7 */
    TEE_ALG_SM4_CBC_PKCS7                = 0xF0000003,
    /** SM4_CTR */
    TEE_ALG_SM4_CTR                      = 0x10000214,
    /** SM4_CFB128 */
    TEE_ALG_SM4_CFB128                   = 0xF0000000,
    /** SM4_XTS */
    TEE_ALG_SM4_XTS                      = 0x10000414,
    /** SM4_OFB */
    TEE_ALG_SM4_OFB                      = 0x10000514,
    /** AES_OFB */
    TEE_ALG_AES_OFB                      = 0x10000510,
    /** SM4_GCM */
    TEE_ALG_SM4_GCM                      = 0xF0000005,
};

/**
 * @see __tee_crypto_algorithm_id
 */
typedef enum __tee_crypto_algorithm_id tee_crypto_algorithm_id;
/**
 * @brief No element is available.
 *
 * @since 12
 */
#define TEE_OPTIONAL_ELEMENT_NONE 0x00000000

/**
 * @brief Enumerates the Elliptic-Curve Cryptography (ECC) curves supported.
 *
 * @since 12
 */
typedef enum {
    /** CURVE_NIST_P192 */
    TEE_ECC_CURVE_NIST_P192 = 0x00000001,
    /** CURVE_NIST_P224 */
    TEE_ECC_CURVE_NIST_P224 = 0x00000002,
    /** CURVE_NIST_P256 */
    TEE_ECC_CURVE_NIST_P256 = 0x00000003,
    /** CURVE_NIST_P384 */
    TEE_ECC_CURVE_NIST_P384 = 0x00000004,
    /** CURVE_NIST_P521 */
    TEE_ECC_CURVE_NIST_P521 = 0x00000005,
    /** CURVE_SM2 256 bits */
    TEE_ECC_CURVE_SM2       = 0x00000300,
    /** CURVE_25519 256 bits */
    TEE_ECC_CURVE_25519     = 0x00000200,
} TEE_ECC_CURVE;

/**
 * @brief Enumerates the Mask Generation Function (MGF1) modes.
 *
 * @since 12
 */
typedef enum {
    TEE_DH_HASH_SHA1_mode   = 0,
    TEE_DH_HASH_SHA224_mode = 1,
    TEE_DH_HASH_SHA256_mode = 2,
    TEE_DH_HASH_SHA384_mode = 3,
    TEE_DH_HASH_SHA512_mode = 4,
    TEE_DH_HASH_NumOfModes,
} TEE_DH_HASH_Mode;

/**
 * @brief Enumerates the cryptographic operation modes.
 *
 * @since 12
 */
enum __TEE_OperationMode {
    /** Encryption */
    TEE_MODE_ENCRYPT = 0x0,
    /** Decryption */
    TEE_MODE_DECRYPT,
    /** Signing */
    TEE_MODE_SIGN,
    /** Signature verification */
    TEE_MODE_VERIFY,
    /** MAC */
    TEE_MODE_MAC,
    /** Digest */
    TEE_MODE_DIGEST,
    /** Key derivation */
    TEE_MODE_DERIVE
};

/**
 * @brief Enumerates the cryptographic operation states.
 *
 * @since 12
 */
enum tee_operation_state {
    /** Initial */
    TEE_OPERATION_STATE_INITIAL = 0x00000000,
    /** Active */
    TEE_OPERATION_STATE_ACTIVE  = 0x00000001,
};

/**
 * @see __TEE_OperationMode
 */
typedef uint32_t TEE_OperationMode;

/**
 * @brief Defines the operation information.
 *
 * @since 12
 */
struct __TEE_OperationInfo {
    /** Algorithm ID */
    uint32_t algorithm;        /* #__TEE_CRYPTO_ALGORITHM_ID */
    /** Operation type */
    uint32_t operationClass;   /* #__TEE_Operation_Constants */
    /** Operation mode */
    uint32_t mode;             /* #__TEE_OperationMode */
    /** Digest length */
    uint32_t digestLength;
    /** Maximum key length */
    uint32_t maxKeySize;
    /** Key length*/
    uint32_t keySize;
    /** Required key usage */
    uint32_t requiredKeyUsage;
    /** Handle state */
    uint32_t handleState;
    /** Key */
    void *keyValue;
};

/**
 * @brief Defines the <b>__TEE_OperationInfo</b> struct.
 *
 * @see __TEE_OperationInfo
 */
typedef struct __TEE_OperationInfo TEE_OperationInfo;

/**
 * @brief Defines the key information stored in the <b>OperationInfo</b>.
 *
 * @since 12
 */
typedef struct {
    /** Key length */
    uint32_t keySize;
    /** Required key usage */
    uint32_t requiredKeyUsage;
} TEE_OperationInfoKey;

/**
 * @brief Defines information about an operation.
 *
 * @since 12
 */
typedef struct {
    /** Algorithm ID */
    uint32_t algorithm;
    /** Operation type */
    uint32_t operationClass;
    /** Operation mode */
    uint32_t mode;
    /** Digest length */
    uint32_t digestLength;
    /** Maximum key length */
    uint32_t maxKeySize;
    /** Handle state */
    uint32_t handleState;
    /** Operation state */
    uint32_t operationState;
    /** Number of keys */
    uint32_t numberOfKeys;
    /** Key information */
    TEE_OperationInfoKey keyInformation[];
} TEE_OperationInfoMultiple;

/**
 * @brief Defines the cryptographic operation handle.
 *
 * @since 12
 */
struct __TEE_OperationHandle {
    /** Algorithm ID */
    uint32_t algorithm;
    /** Operation type */
    uint32_t operationClass;
    /** Operation mode */
    uint32_t mode;
    /** Digest length */
    uint32_t digestLength;
    /** Maximum key length */
    uint32_t maxKeySize;
    /** Key length */
    uint32_t keySize;
    /** Key length */
    uint32_t keySize2;
    /** Required key usage */
    uint32_t requiredKeyUsage;
    /** Handle state */
    uint32_t handleState;
    /** Key */
    void *keyValue;
    /** Key */
    void *keyValue2;
    /** */
    void *crypto_ctxt;
    /** */
    void *hmac_rest_ctext;
    /** iv */
    void *IV;
    /** Public key */
    void *publicKey;
    /** Length of the public key */
    uint32_t publicKeyLen;
    /** Private key */
    void *privateKey;
    /** Length of the private key */
    uint32_t privateKeyLen;
    /** Length of the IV */
    uint32_t IVLen;
    /** Operation lock */
    pthread_mutex_t operation_lock;
    /** HAL information */
    void *hal_info;
};

/**
 * @brief Defines the data used for conversion of integers.
 *
 * @since 12
 */
typedef struct {
    /** Source */
    uint32_t src;
    /** Destination */
    uint32_t dest;
} crypto_uint2uint;

/**
 * @brief Defines the maximum length of an RSA public key.
 *
 * @since 12
 */
#define RSA_PUBKEY_MAXSIZE sizeof(CRYS_RSAUserPubKey_t)
/**
 * @brief Defines the maximum length of an RES private key.
 *
 * @since 12
 */
#define RSA_PRIVKEY_MAXSIZE sizeof(CRYS_RSAUserPrivKey_t)

/**
 * @brief Defines a structure to hold the input and output data.
 *
 * @since 12
 */
typedef struct {
    /** Source data */
    void *src_data;
    /** Length of the source data */
    size_t src_len;
    /** Destination data */
    void *dest_data;
    /** Length of the destination data */
    size_t *dest_len;
} operation_src_dest;

/**
 * @brief Defines the AE initialization data.
 *
 * @since 12
 */
typedef struct {
    /** nonce */
    void *nonce;
    /** Leng of nonce */
    size_t nonce_len;
    /** Length of the tag */
    uint32_t tag_len;
    /** Length of the additional authenticated data (AAD) */
    size_t aad_len;
    /** Length of the payload */
    size_t payload_len;
} operation_ae_init;

/**
 * @brief Defines the pointer to <b>__TEE_OperationHandle</b>.
 *
 * @see __TEE_OperationHandle
 *
 * @since 12
 */
typedef struct __TEE_OperationHandle *TEE_OperationHandle;

/**
 * @brief Defines the <b>__TEE_OperationHandle</b> struct.
 *
 * @see __TEE_OperationHandle
 *
 * @since 12
 */
typedef struct __TEE_OperationHandle TEE_OperationHandleVar;

/**
 * @brief Defines the <b>__TEE_ObjectHandle</b> struct.
 *
 * @since 12
 */
typedef struct __TEE_ObjectHandle TEE_ObjectHandleVar;

/**
 * @brief Allocates an operation handle.
 *
 * @param operation Indicates the pointer to the operation handle.
 * @param algorithm Indicates the cipher algorithm.
 * @param mode Indicates the operation mode.
 * @param maxKeySize Indicates the maximum length of the key.
 *
 * @return Returns <b>TEE_SUCCESS</b> if the operation handle is allocated.
 *         Returns <b>TEE_ERROR_OUT_OF_MEMORY</b> if there is no enough memory for this operation.
 *         Returns <b>TEE_ERROR_NOT_SUPPORTED</b> if the specified algorithm is not supported.
 *         Returns <b>TEE_ERROR_GENERIC</b> if the operation fails due to other errors.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_AllocateOperation(TEE_OperationHandle *operation, uint32_t algorithm, uint32_t mode,
                                 uint32_t maxKeySize);

/**
 * @brief Releases an operation handle.
 *
 * @param operation Indicates the operation handle to release.
 *
 * @since 12
 * @version 1.0
 */
void TEE_FreeOperation(TEE_OperationHandle operation);

/**
 * @brief Obtains operation information.
 *
 * @param operation Indicates the operation handle.
 * @param operationInfo Indicates the pointer to the operation information.
 *
 * @since 12
 * @version 1.0
 */
void TEE_GetOperationInfo(const TEE_OperationHandle operation, TEE_OperationInfo *operationInfo);

/**
 * @brief Resets an operation handle.
 *
 * @param operation Indicates the operation handle to reset.
 *
 * @since 12
 * @version 1.0
 */
void TEE_ResetOperation(TEE_OperationHandle operation);

/**
 * @brief Sets the key for an operation.
 *
 * @param operation Indicates the operation handle.
 * @param key Indicates the key.
 *
 * @return Returns <b>TEE_SUCCESS</b> if the operation is successful.
 *         Returns <b>TEE_ERROR_BAD_PARAMETERS</b> if the operation fails due to invalid parameters.
 *         Returns <b>TEE_ERROR_OUT_OF_MEMORY</b> if there is no enough memory for this operation.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_SetOperationKey(TEE_OperationHandle operation, const TEE_ObjectHandle key);

/**
 * @brief Sets two keys for an operation.
 *
 * @param operation Indicates the operation handle.
 * @param key1 Indicates key 1.
 * @param key2 Indicates key 2.
 *
 * @return Returns <b>TEE_SUCCESS</b> if the operation is successful.
 *         Returns <b>TEE_ERROR_BAD_PARAMETERS</b> if the operation fails due to invalid parameters.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_SetOperationKey2(TEE_OperationHandle operation, const TEE_ObjectHandle key1,
                                const TEE_ObjectHandle key2);

/**
 * @brief Copies an operation handle.
 *
 * @param dstOperation Indicates the destination operation handle.
 * @param srcOperation Indicates the source operation handle.
 *
 * @since 12
 * @version 1.0
 */
void TEE_CopyOperation(TEE_OperationHandle dstOperation, const TEE_OperationHandle srcOperation);

/**
 * @brief Initializes the context to start a cipher operation.
 *
 * @param operation Indicates the operation handle.
 * @param IV Indicates the pointer to the buffer storing the operation IV. If this parameter is not used,
 * set it to <b>NULL</b>.
 * @param IVLen Indicates the length of the IV buffer.
 *
 * @since 12
 * @version 1.0
 */
void TEE_CipherInit(TEE_OperationHandle operation, const void *IV, size_t IVLen);

/**
 * @brief Updates the data for a cipher operation.
 *
 * @param operation Indicates the operation handle.
 * @param srcData Indicates the pointer to the source data.
 * @param srcLen Indicates the length of the source data.
 * @param destData Indicates the pointer to the destination data.
 * @param destLen Indicates the pointer to the destination data length.
 *
 * @return Returns <b>TEE_SUCCESS</b> if the operation is successful.
 *         Returns <b>TEE_ERROR_BAD_PARAMETERS</b> if the operation fails due to invalid parameters.
 *         Returns <b>TEE_ERROR_GENERIC</b> if the operation fails due to other errors.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_CipherUpdate(TEE_OperationHandle operation, const void *srcData, size_t srcLen, void *destData,
                            size_t *destLen);

/**
 * @brief Finalizes a cipher operation.
 *
 * @param operation Indicates the operation handle.
 * @param srcData Indicates the pointer to the source data.
 * @param srcLen Indicates the length of the source data.
 * @param destData Indicates the pointer to the destination data.
 * @param destLen Indicates the pointer to the destination data length.
 *
 * @return Returns <b>TEE_SUCCESS</b> if the operation is successful.
 *         Returns <b>TEE_ERROR_BAD_PARAMETERS</b> if the operation fails due to invalid parameters.
 *         Returns <b>TEE_ERROR_GENERIC</b> if the operation fails due to other errors.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_CipherDoFinal(TEE_OperationHandle operation, const void *srcData, size_t srcLen, void *destData,
                             size_t *destLen);

/**
 * @brief Updates the digest.
 *
 * @param operation Indicates the operation handle.
 * @param chunk Indicates the pointer to the chunk of data to be hashed.
 * @param chunkSize Indicates the length of the chunk.
 *
 * @since 12
 * @version 1.0
 */
void TEE_DigestUpdate(TEE_OperationHandle operation, const void *chunk, size_t chunkSize);

/**
 * @brief Finalizes the message digest operation.
 *
 * @param operation Indicates the operation handle.
 * @param chunk Indicates the pointer to the chunk of data to be hashed.
 * @param chunkLen Indicates the length of the chunk.
 * @param hash Indicates the pointer to the buffer storing the message hash.
 * @param hashLen
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_DigestDoFinal(TEE_OperationHandle operation, const void *chunk, size_t chunkLen, void *hash,
                             size_t *hashLen);

/**
 * @brief Initializes a MAC operation.
 *
 * @param operation Indicates the operation handle.
 * @param IV Indicates the pointer to the buffer storing the operation IV. If this parameter is not used,
 * set it to <b>NULL</b>.
 * @param IVLen Indicates the length of the IV buffer.
 *
 * @since 12
 * @version 1.0
 */
void TEE_MACInit(TEE_OperationHandle operation, void *IV, size_t IVLen);

/**
 * @brief Updates the MAC.
 *
 * @param operation Indicates the operation handle.
 * @param chunk Indicates the pointer to the chunk of MAC data.
 * @param chunkSize Indicates the size of the chunk.
 *
 * @since 12
 * @version 1.0
 */
void TEE_MACUpdate(TEE_OperationHandle operation, const void *chunk, size_t chunkSize);

/**
 * @brief MAC Finalizes the MAC operation with a last chunk of message and computes the MAC.
 *
 * @param operation Indicates the operation handle.
 * @param message Indicates the pointer to the buffer containing the last message chunk to MAC.
 * @param messageLen Indicates the length of the message buffer.
 * @param mac Indicates the pointer to the buffer storing the computed MAC.
 * @param macLen Indicates the pointer to the MAC buffer length.
 *
 * @return Returns <b>TEE_SUCCESS</b> if the operation is successful.
 *         Returns <b>TEE_ERROR_GENERIC</b> if the operation fails due to other errors.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_MACComputeFinal(TEE_OperationHandle operation, const void *message, size_t messageLen, void *mac,
                               size_t *macLen);

/**
 * @brief Finalizes the MAC operation and compares the MAC with the one passed in.
 *
 * @param operation Indicates the operation handle.
 * @param message Indicates the pointer to the buffer containing the last message chunk to MAC.
 * @param messageLen Indicates the length of the buffer.
 * @param mac Indicates the pointer to the buffer storing the computed MAC.
 * @param macLen Indicates the MAC buffer length.
 *
 * @return Returns <b>TEE_SUCCESS</b> if the operation is successful.
 *         Returns <b>TEE_ERROR_GENERIC</b> if the operation fails due to other errors.
 *         Returns <b>TEE_ERROR_MAC_INVALID</b> if the computed MAC is not the same as that passed in.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_MACCompareFinal(TEE_OperationHandle operation, const void *message, size_t messageLen, const void *mac,
                               const size_t macLen);

/**
 * @brief Derives a key.
 *
 * @param operation Indicates the operation handle.
 * @param params Indicates the pointer to the parameters for this operation.
 * @param paramCount Indicates the number of parameters.
 * @param derivedKey Indicates the derived key.
 *
 * @since 12
 * @version 1.0
 */
void TEE_DeriveKey(TEE_OperationHandle operation, const TEE_Attribute *params, uint32_t paramCount,
                   TEE_ObjectHandle derivedKey);

/**
 * @brief Generates random data.
 *
 * @param randomBuffer Indicates the pointer to the buffer storing the random data generated.
 * @param randomBufferLen Indicates the length of the buffer storing the random data.
 *
 * @since 12
 * @version 1.0
 */
void TEE_GenerateRandom(void *randomBuffer, size_t randomBufferLen);

/**
 * @brief Initializes an AE operation.
 *
 * @param operation Indicates the operation handle.
 * @param nonce Indicates the pointer to the buffer for storing the nonce.
 * @param nonceLen Indicates the length of the nonce.
 * @param tagLen Indicates the length of the tag.
 * @param AADLen Indicates the length of the AAD.
 * @param payloadLen Indicates the length of the payload.
 *
 * @return Returns <b>TEE_SUCCESS</b> if the operation is successful.
 *         Returns <b>TEE_ERROR_GENERIC</b> if the operation fails due to other errors.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_AEInit(TEE_OperationHandle operation, void *nonce, size_t nonceLen, uint32_t tagLen, size_t AADLen,
                      size_t payloadLen);

/**
 * @brief Updates the AAD in an AE operation.
 *
 * @param operation Indicates the operation handle.
 * @param AADdata Indicates the pointer to the new AAD.
 * @param AADdataLen Indicates the length of the new AAD.
 *
 * @since 12
 * @version 1.0
 */
void TEE_AEUpdateAAD(TEE_OperationHandle operation, const void *AADdata, size_t AADdataLen);

/**
 * @brief Updates data for an AE operation.
 *
 * @param operation Indicates the operation handle.
 * @param srcData Indicates the pointer to the source data.
 * @param srcLen Indicates the length of the source data.
 * @param destData Indicates the pointer to the destination data.
 * @param destLen Indicates the pointer to the destination data length.
 *
 * @return Returns <b>TEE_SUCCESS</b> if the operation is successful.
 *         Returns <b>TEE_ERROR_GENERIC</b> if the operation fails due to other errors.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_AEUpdate(TEE_OperationHandle operation, void *srcData, size_t srcLen, void *destData, size_t *destLen);

/**
 * @brief Finalizes the AE encryption operation.
 *
 * @param operation Indicates the operation handle.
 * @param srcData Indicates the pointer to the source data.
 * @param srcLen Indicates the length of the source data.
 * @param destData Indicates the pointer to the destination data.
 * @param destLen Indicates the pointer to the destination data length.
 * @param tag Indicates the pointer to the buffer storing the computed tag.
 * @param tagLen Indicates the pointer to the tag buffer length.
 *
 * @return Returns <b>TEE_SUCCESS</b> if the operation is successful.
 *         Returns <b>TEE_ERROR_GENERIC</b> if the operation fails due to other errors.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_AEEncryptFinal(TEE_OperationHandle operation, void *srcData, size_t srcLen, void *destData,
                              size_t *destLen, void *tag, size_t *tagLen);

/**
 * @brief Finalizes an AE decryption operation.
 *
 * @param operation Indicates the operation handle.
 * @param srcData Indicates the pointer to the source data.
 * @param srcLen Indicates the length of the source data.
 * @param destData Indicates the pointer to the destination data.
 * @param destLen Indicates the pointer to the destination data length.
 * @param tag Indicates the pointer to the buffer storing the computed tag.
 * @param tagLen Indicates the tag buffer length.
 *
 * @return Returns <b>TEE_SUCCESS</b> if the operation is successful.
 *         Returns <b>TEE_ERROR_MAC_INVALID</b> if the computed tag does not match the provided tag.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_AEDecryptFinal(TEE_OperationHandle operation, void *srcData, size_t srcLen, void *destData,
                              size_t *destLen, void *tag, size_t tagLen);

/**
 * @brief Performs asymmetric encryption.
 *
 * @param operation Indicates the operation handle.
 * @param params Indicates the pointer to the parameters for this operation.
 * @param paramCount Indicates the number of parameters.
 * @param srcData Indicates the pointer to the source data.
 * @param srcLen Indicates the length of the source data.
 * @param destData Indicates the pointer to the destination data.
 * @param destLen Indicates the pointer to the destination data length.
 *
 * @return Returns <b>TEE_SUCCESS</b> if the operation is successful.
 *         Returns <b>TEE_ERROR_BAD_PARAMETERS</b> if the operation fails due to invalid parameters.
 *         Returns <b>TEE_ERROR_GENERIC</b> if the operation fails due to other errors.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_AsymmetricEncrypt(TEE_OperationHandle operation, const TEE_Attribute *params, uint32_t paramCount,
                                 void *srcData, size_t srcLen, void *destData, size_t *destLen);

/**
 * @brief Performs asymmetric decryption.
 *
 * @param operation Indicates the operation handle.
 * @param params Indicates the pointer to the parameters for this operation.
 * @param paramCount Indicates the number of parameters.
 * @param srcData Indicates the pointer to the source data.
 * @param srcLen Indicates the length of the source data.
 * @param destData Indicates the pointer to the destination data.
 * @param destLen Indicates the pointer to the destination data length.
 *
 * @return Returns <b>TEE_SUCCESS</b> if the operation is successful.
 *         Returns <b>TEE_ERROR_BAD_PARAMETERS</b> if the operation fails due to invalid parameters.
 *         Returns <b>TEE_ERROR_GENERIC</b> if the operation fails due to other errors.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_AsymmetricDecrypt(TEE_OperationHandle operation, const TEE_Attribute *params, uint32_t paramCount,
                                 void *srcData, size_t srcLen, void *destData, size_t *destLen);

/**
 * @brief Signs a message digest in an asymmetric operation.
 *
 * @param operation Indicates the operation handle.
 * @param params Indicates the pointer to the parameters for this operation.
 * @param paramCount Indicates the number of parameters.
 * @param digest Indicates the pointer to the message digest.
 * @param digestLen Indicates the digest length.
 * @param signature Indicates the pointer to the signature.
 * @param signatureLen Indicates the pointer to the signature length.
 *
 * @return Returns <b>TEE_SUCCESS</b> if the operation is successful.
 *         Returns <b>TEE_ERROR_BAD_PARAMETERS</b> if the operation fails due to invalid parameters.
 *         Returns <b>TEE_ERROR_GENERIC</b> if the operation fails due to other errors.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_AsymmetricSignDigest(TEE_OperationHandle operation, const TEE_Attribute *params, uint32_t paramCount,
                                    void *digest, size_t digestLen, void *signature, size_t *signatureLen);

/**
 * @brief Verifies a message digest signature in an asymmetric operation.
 *
 * @param operation Indicates the operation handle.
 * @param params Indicates the pointer to the parameters for this operation.
 * @param paramCount Indicates the number of parameters.
 * @param digest Indicates the pointer to the message digest.
 * @param digestLen Indicates the digest length.
 * @param signature Indicates the pointer to the signature.
 * @param signatureLen Indicates the signature length.
 *
 * @return Returns <b>TEE_SUCCESS</b> if the operation is successful.
 *         Returns <b>TEE_ERROR_BAD_PARAMETERS</b> if the operation fails due to invalid parameters.
 *         Returns <b>TEE_ERROR_GENERIC</b> if the operation fails due to other errors.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_AsymmetricVerifyDigest(TEE_OperationHandle operation, const TEE_Attribute *params, uint32_t paramCount,
                                      void *digest, size_t digestLen, void *signature, size_t signatureLen);

/**
 * @brief Obtains information about the operation involving multiple keys.
 *
 * @param operation Indicates the operation handle.
 * @param operationInfoMultiple Indicates the pointer to the operation information obtained.
 * @param operationSize [IN/OUT] Indicates the pointer to the operation information size.
 *
 * @return Returns <b>TEE_SUCCESS</b> if the operation is successful.
 *         Returns <b>TEE_ERROR_BAD_PARAMETERS</b> if the operation fails due to invalid parameters.
 *         Returns <b>TEE_ERROR_SHORT_BUFFER</b> if the operationInfo buffer is not large enough to
 * hold the information obtained.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_GetOperationInfoMultiple(TEE_OperationHandle operation, TEE_OperationInfoMultiple *operationInfoMultiple,
                                        const size_t *operationSize);

/**
 * @brief Checks whether the algorithm is supported.
 *
 * @param algId Indicates the algorithm to check.
 * @param element Indicates the cryptographic element.
 *
 * @return Returns <b>TEE_SUCCESS</b> if the algorithm is supported.
 *         Returns <b>TEE_ERROR_NOT_SUPPORTED</b> otherwise.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_IsAlgorithmSupported(uint32_t algId, uint32_t element);

#ifdef __cplusplus
}
#endif
/** @} */
#endif