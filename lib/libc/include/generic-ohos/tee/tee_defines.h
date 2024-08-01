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

#ifndef __TEE_DEFINES_H
#define __TEE_DEFINES_H

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
 * @file tee_defines.h
 *
 * @brief Defines basic data types and data structures of TEE.
 *
 * @library NA
 * @kit TEE Kit
 * @syscap SystemCapability.Tee.TeeClient
 * @since 12
 * @version 1.0
 */

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif
#ifndef TA_EXPORT
#define TA_EXPORT
#endif

/**
 * @brief Defines the tee mutex handle.
 *
 * @since 12
 */
typedef int *tee_mutex_handle;

#define API_LEVEL1_1_1 2
#define API_LEVEL1_2   3

#define TEE_PARAMS_NUM 4
#undef true
#define true 1

#undef false
#define false 0

#ifndef NULL
#define NULL ((void *)0)
#endif

#define PARAM_NOT_USED(val) ((void)(val))

/**
 * @brief Enumerates the TEE parameter.
 *
 * @since 12
 */
typedef union {
    struct {
        void *buffer;
        size_t size;
    } memref;
    struct {
        unsigned int a;
        unsigned int b;
    } value;
    struct {
        void *buffer;
        size_t size;
    } sharedmem;
} TEE_Param;

#define TEE_PARAM_TYPES(param0Type, param1Type, param2Type, param3Type) \
    (((param3Type) << 12) | ((param2Type) << 8) | ((param1Type) << 4) | (param0Type))

#define TEE_PARAM_TYPE_GET(paramTypes, index) (((paramTypes) >> (4U * (index))) & 0x0F)

/**
 * @brief Checks parameter types.
 *
 * @param param_to_check Indicates the expected parameter values.
 * @param valid0 Indicates the first parameter type to check.
 * @param valid1 Indicates the second parameter type to check.
 * @param valid2 Indicates the third parameter type to check.
 * @param valid3 Indicates the fourth parameter type to check.
 *
 * @return Returns <b>true</b> if the parameter types are correct.
 *         Returns <b>false</b> otherwise.
 * @since 12
 */
static inline bool check_param_type(uint32_t param_to_check, uint32_t valid0, uint32_t valid1, uint32_t valid2,
                                    uint32_t valid3)
{
    return (TEE_PARAM_TYPES(valid0, valid1, valid2, valid3) == param_to_check);
}

/**
 * @brief Enumerates the types of the TEE parameter.
 *
 * @since 12
 */
enum TEE_ParamType {
    TEE_PARAM_TYPE_NONE             = 0x0,
    TEE_PARAM_TYPE_VALUE_INPUT      = 0x1,
    TEE_PARAM_TYPE_VALUE_OUTPUT     = 0x2,
    TEE_PARAM_TYPE_VALUE_INOUT      = 0x3,
    TEE_PARAM_TYPE_MEMREF_INPUT     = 0x5,
    TEE_PARAM_TYPE_MEMREF_OUTPUT    = 0x6,
    TEE_PARAM_TYPE_MEMREF_INOUT     = 0x7,
    TEE_PARAM_TYPE_ION_INPUT        = 0x8,
    TEE_PARAM_TYPE_ION_SGLIST_INPUT = 0x9,
    TEE_PARAM_TYPE_MEMREF_SHARED_INOUT = 0xa,
    TEE_PARAM_TYPE_RESMEM_INPUT        = 0xc,
    TEE_PARAM_TYPE_RESMEM_OUTPUT       = 0xd,
    TEE_PARAM_TYPE_RESMEM_INOUT        = 0xe,
};

#define S_VAR_NOT_USED(variable) \
    do {                         \
        (void)(variable);        \
    } while (0)

/**
 * @brief Defines an object information.
 *
 * @since 12
 */
typedef struct {
    uint32_t objectType;
    uint32_t objectSize;
    uint32_t maxObjectSize;
    uint32_t objectUsage;
    uint32_t dataSize;
    uint32_t dataPosition;
    uint32_t handleFlags;
} TEE_ObjectInfo;

/**
 * @brief Defines an object attribute.
 *
 * @since 12
 */
typedef struct {
    uint32_t attributeID;
    union {
        struct {
            void *buffer;
            size_t length;
        } ref;
        struct {
            uint32_t a;
            uint32_t b;
        } value;
    } content;
} TEE_Attribute;

/**
 * @brief Enumerates the types of object attribute.
 *
 * @since 12
 */
enum TEE_ObjectAttribute {
    TEE_ATTR_SECRET_VALUE          = 0xC0000000,
    TEE_ATTR_RSA_MODULUS           = 0xD0000130,
    TEE_ATTR_RSA_PUBLIC_EXPONENT   = 0xD0000230,
    TEE_ATTR_RSA_PRIVATE_EXPONENT  = 0xC0000330,
    TEE_ATTR_RSA_PRIME1            = 0xC0000430,
    TEE_ATTR_RSA_PRIME2            = 0xC0000530,
    TEE_ATTR_RSA_EXPONENT1         = 0xC0000630,
    TEE_ATTR_RSA_EXPONENT2         = 0xC0000730,
    TEE_ATTR_RSA_COEFFICIENT       = 0xC0000830,
    TEE_ATTR_RSA_MGF1_HASH         = 0xF0000830,
    TEE_ATTR_DSA_PRIME             = 0xD0001031,
    TEE_ATTR_DSA_SUBPRIME          = 0xD0001131,
    TEE_ATTR_DSA_BASE              = 0xD0001231,
    TEE_ATTR_DSA_PUBLIC_VALUE      = 0xD0000131,
    TEE_ATTR_DSA_PRIVATE_VALUE     = 0xC0000231,
    TEE_ATTR_DH_PRIME              = 0xD0001032,
    TEE_ATTR_DH_SUBPRIME           = 0xD0001132,
    TEE_ATTR_DH_BASE               = 0xD0001232,
    TEE_ATTR_DH_X_BITS             = 0xF0001332,
    TEE_ATTR_DH_PUBLIC_VALUE       = 0xD0000132,
    TEE_ATTR_DH_PRIVATE_VALUE      = 0xC0000232,
    TEE_ATTR_RSA_OAEP_LABEL        = 0xD0000930,
    TEE_ATTR_RSA_PSS_SALT_LENGTH   = 0xF0000A30,
    TEE_ATTR_ECC_PUBLIC_VALUE_X    = 0xD0000141,
    TEE_ATTR_ECC_PUBLIC_VALUE_Y    = 0xD0000241,
    TEE_ATTR_ECC_PRIVATE_VALUE     = 0xC0000341,
    TEE_ATTR_ECC_CURVE             = 0xF0000441,
    TEE_ATTR_ED25519_CTX           = 0xD0000643,
    TEE_ATTR_ED25519_PUBLIC_VALUE  = 0xD0000743,
    TEE_ATTR_ED25519_PRIVATE_VALUE = 0xC0000843,
    TEE_ATTR_ED25519_PH            = 0xF0000543,
    TEE_ATTR_X25519_PUBLIC_VALUE   = 0xD0000944,
    TEE_ATTR_X25519_PRIVATE_VALUE  = 0xC0000A44,
    TEE_ATTR_PBKDF2_HMAC_PASSWORD  = 0xD0000133,
    TEE_ATTR_PBKDF2_HMAC_SALT      = 0xD0000134,
    TEE_ATTR_PBKDF2_HMAC_DIGEST    = 0xF0000135,
};

/**
 * @brief Enumerates the types of object.
 *
 * @since 12
 */
enum TEE_ObjectType {
    TEE_TYPE_AES                = 0xA0000010,
    TEE_TYPE_DES                = 0xA0000011,
    TEE_TYPE_DES3               = 0xA0000013,
    TEE_TYPE_HMAC_MD5           = 0xA0000001,
    TEE_TYPE_HMAC_SHA1          = 0xA0000002,
    TEE_TYPE_HMAC_SHA224        = 0xA0000003,
    TEE_TYPE_HMAC_SHA256        = 0xA0000004,
    TEE_TYPE_HMAC_SHA384        = 0xA0000005,
    TEE_TYPE_HMAC_SHA512        = 0xA0000006,
    TEE_TYPE_RSA_PUBLIC_KEY     = 0xA0000030,
    TEE_TYPE_RSA_KEYPAIR        = 0xA1000030,
    TEE_TYPE_DSA_PUBLIC_KEY     = 0xA0000031,
    TEE_TYPE_DSA_KEYPAIR        = 0xA1000031,
    TEE_TYPE_DH_KEYPAIR         = 0xA1000032,
    TEE_TYPE_GENERIC_SECRET     = 0xA0000000,
    TEE_TYPE_DATA               = 0xA1000033,
    TEE_TYPE_DATA_GP1_1         = 0xA00000BF,
    TEE_TYPE_ECDSA_PUBLIC_KEY   = 0xA0000041,
    TEE_TYPE_ECDSA_KEYPAIR      = 0xA1000041,
    TEE_TYPE_ECDH_PUBLIC_KEY    = 0xA0000042,
    TEE_TYPE_ECDH_KEYPAIR       = 0xA1000042,
    TEE_TYPE_ED25519_PUBLIC_KEY = 0xA0000043,
    TEE_TYPE_ED25519_KEYPAIR    = 0xA1000043,
    TEE_TYPE_X25519_PUBLIC_KEY  = 0xA0000044,
    TEE_TYPE_X25519_KEYPAIR     = 0xA1000044,
    TEE_TYPE_SM2_DSA_PUBLIC_KEY = 0xA0000045,
    TEE_TYPE_SM2_DSA_KEYPAIR    = 0xA1000045,
    TEE_TYPE_SM2_KEP_PUBLIC_KEY = 0xA0000046,
    TEE_TYPE_SM2_KEP_KEYPAIR    = 0xA1000046,
    TEE_TYPE_SM2_PKE_PUBLIC_KEY = 0xA0000047,
    TEE_TYPE_SM2_PKE_KEYPAIR    = 0xA1000047,
    TEE_TYPE_HMAC_SM3           = 0xA0000007,
    TEE_TYPE_SM4                = 0xA0000014,
    TEE_TYPE_SIP_HASH           = 0xF0000002,
    TEE_TYPE_PBKDF2_HMAC        = 0xF0000004,

    TEE_TYPE_CORRUPTED_OBJECT = 0xA00000BE,
};

#define OBJECT_NAME_LEN_MAX 255

/**
 * @brief Defines an object handle.
 *
 * @since 12
 */
struct __TEE_ObjectHandle {
    void *dataPtr;
    uint32_t dataLen;
    uint8_t dataName[OBJECT_NAME_LEN_MAX];
    TEE_ObjectInfo *ObjectInfo;
    TEE_Attribute *Attribute;
    uint32_t attributesLen;
    uint32_t CRTMode;
    void *infoattrfd;
    uint32_t generate_flag;
    uint32_t storage_id;
};

/**
 * @brief Defines the <b>__TEE_ObjectHandle</b> struct.
 *
 * @see __TEE_ObjectHandle
 *
 * @since 12
 */
typedef struct __TEE_ObjectHandle *TEE_ObjectHandle;

#define NODE_LEN 8

/**
 * @brief Defines an UUID of TA.
 *
 * @since 12
 */
typedef struct tee_uuid {
    uint32_t timeLow;
    uint16_t timeMid;
    uint16_t timeHiAndVersion;
    uint8_t clockSeqAndNode[NODE_LEN];
} TEE_UUID;

/**
 * @brief Defines the type of spawn UUID.
 *
 * @since 12
 */
typedef struct spawn_uuid {
    uint64_t uuid_valid;
    TEE_UUID uuid;
} spawn_uuid_t;

/**
 * @brief Enumerates the result codes used in the TEE Kit APIs.
 *
 * @since 12
 */
enum TEE_Result_Value {
    /* The operation is successful. */
    TEE_SUCCESS                        = 0x00000000,
    /* The command is invalid. */
    TEE_ERROR_INVALID_CMD              = 0x00000001,
    /* The service does not exist. */
    TEE_ERROR_SERVICE_NOT_EXIST        = 0x00000002,
    /* The session does not exist. */
    TEE_ERROR_SESSION_NOT_EXIST        = 0x00000003,
    /* The number of sessions exceeds the limit. */
    TEE_ERROR_SESSION_MAXIMUM          = 0x00000004,
    /* The service has been already registered. */
    TEE_ERROR_REGISTER_EXIST_SERVICE   = 0x00000005,
    /* An internal error occurs. */
    TEE_ERROR_TARGET_DEAD_FATAL        = 0x00000006,
    /* Failed to read data. */
    TEE_ERROR_READ_DATA                = 0x00000007,
    /* Failed to write data. */
    TEE_ERROR_WRITE_DATA               = 0x00000008,
    /* Failed to truncate data. */
    TEE_ERROR_TRUNCATE_OBJECT          = 0x00000009,
    /* Failed to seek data. */
    TEE_ERROR_SEEK_DATA                = 0x0000000A,
    /* Failed to synchronize data. */
    TEE_ERROR_SYNC_DATA                = 0x0000000B,
    /* Failed to rename the file. */
    TEE_ERROR_RENAME_OBJECT            = 0x0000000C,
    /* An error occurs when the TA is loaded. */
    TEE_ERROR_TRUSTED_APP_LOAD_ERROR   = 0x0000000D,
    /* An I/O error occurs when data is stored. */
    TEE_ERROR_STORAGE_EIO              = 0x80001001,
    /* The storage section is unavailable. */
    TEE_ERROR_STORAGE_EAGAIN           = 0x80001002,
    /* The operation target is not a directory. */
    TEE_ERROR_STORAGE_ENOTDIR          = 0x80001003,
    /* This operation cannot be performed on a directory. */
    TEE_ERROR_STORAGE_EISDIR           = 0x80001004,
    /* The number of opened files exceeds the limit in system. */
    TEE_ERROR_STORAGE_ENFILE           = 0x80001005,
    /* The number of files opened for the process exceeds the limit.*/
    TEE_ERROR_STORAGE_EMFILE           = 0x80001006,
    /* The storage section is read only. */
    TEE_ERROR_STORAGE_EROFS            = 0x80001007,
    /* The file path is not correct. */
    TEE_ERROR_STORAGE_PATH_WRONG       = 0x8000100A,
    /* The service message queue overflows. */
    TEE_ERROR_MSG_QUEUE_OVERFLOW       = 0x8000100B,
    /* The file object is corrupted. */
    TEE_ERROR_CORRUPT_OBJECT           = 0xF0100001,
    /* The storage section is unavailable. */
    TEE_ERROR_STORAGE_NOT_AVAILABLE    = 0xF0100003,
    /* The cipher text is incorrect. */
    TEE_ERROR_CIPHERTEXT_INVALID       = 0xF0100006,
    /* Protocol error in socket connection. */
    TEE_ISOCKET_ERROR_PROTOCOL         = 0xF1007001,
    /* The socket is closed by the remote end. */
    TEE_ISOCKET_ERROR_REMOTE_CLOSED    = 0xF1007002,
    /* The socket connection timed out. */
    TEE_ISOCKET_ERROR_TIMEOUT          = 0xF1007003,
    /* There is no resource available for the socket connection. */
    TEE_ISOCKET_ERROR_OUT_OF_RESOURCES = 0xF1007004,
    /* The buffer is too large for the socket connection. */
    TEE_ISOCKET_ERROR_LARGE_BUFFER     = 0xF1007005,
    /* A warning is given in the socket connection. */
    TEE_ISOCKET_WARNING_PROTOCOL       = 0xF1007006,
    /* Generic error. */
    TEE_ERROR_GENERIC                  = 0xFFFF0000,
    /* The access is denied. */
    TEE_ERROR_ACCESS_DENIED            = 0xFFFF0001,
    /* The operation has been canceled. */
    TEE_ERROR_CANCEL                   = 0xFFFF0002,
    /* An access conflict occurs. */
    TEE_ERROR_ACCESS_CONFLICT          = 0xFFFF0003,
    /* The data size exceeds the maximum. */
    TEE_ERROR_EXCESS_DATA              = 0xFFFF0004,
    /* Incorrect data format. */
    TEE_ERROR_BAD_FORMAT               = 0xFFFF0005,
    /* Incorrect parameters. */
    TEE_ERROR_BAD_PARAMETERS           = 0xFFFF0006,
    /* The current state does not support the operation. */
    TEE_ERROR_BAD_STATE                = 0xFFFF0007,
    /* Failed to find the target item. */
    TEE_ERROR_ITEM_NOT_FOUND           = 0xFFFF0008,
    /* The API is not implemented. */
    TEE_ERROR_NOT_IMPLEMENTED          = 0xFFFF0009,
    /* The API is not supported. */
    TEE_ERROR_NOT_SUPPORTED            = 0xFFFF000A,
    /* There is no data available for this operation. */
    TEE_ERROR_NO_DATA                  = 0xFFFF000B,
    /* There is no memory available for this operation. */
    TEE_ERROR_OUT_OF_MEMORY            = 0xFFFF000C,
    /* The system does not respond to this operation. */
    TEE_ERROR_BUSY                     = 0xFFFF000D,
    /* Failed to communicate with the target. */
    TEE_ERROR_COMMUNICATION            = 0xFFFF000E,
    /* A security error occurs. */
    TEE_ERROR_SECURITY                 = 0xFFFF000F,
    /* The buffer is insufficient for this operation. */
    TEE_ERROR_SHORT_BUFFER             = 0xFFFF0010,
    /* The operation has been canceled. */
    TEE_ERROR_EXTERNAL_CANCEL          = 0xFFFF0011,
    /* The service is in the pending state (asynchronous state). */
    TEE_PENDING                        = 0xFFFF2000,
    /* The service is in the pending state(). */
    TEE_PENDING2                       = 0xFFFF2001,
    /* Reserved. */
    TEE_PENDING3                       = 0xFFFF2002,
    /* The operation timed out. */
    TEE_ERROR_TIMEOUT                  = 0xFFFF3001,
    /* Overflow occurs. */
    TEE_ERROR_OVERFLOW                 = 0xFFFF300f,
    /* The TA is crashed. */
    TEE_ERROR_TARGET_DEAD              = 0xFFFF3024,
    /* There is no enough space to store data. */
    TEE_ERROR_STORAGE_NO_SPACE         = 0xFFFF3041,
    /* The MAC operation failed. */
    TEE_ERROR_MAC_INVALID              = 0xFFFF3071,
    /* The signature verification failed. */
    TEE_ERROR_SIGNATURE_INVALID        = 0xFFFF3072,
    /* Interrupted by CFC. Broken control flow is detected. */
    TEE_CLIENT_INTR                    = 0xFFFF4000,
    /* Time is not set. */
    TEE_ERROR_TIME_NOT_SET             = 0xFFFF5000,
    /* Time needs to be reset. */
    TEE_ERROR_TIME_NEEDS_RESET         = 0xFFFF5001,
    /* System error. */
    TEE_FAIL                           = 0xFFFF5002,
    /* Base value of the timer error code. */
    TEE_ERROR_TIMER                    = 0xFFFF6000,
    /* Failed to create the timer. */
    TEE_ERROR_TIMER_CREATE_FAILED      = 0xFFFF6001,
    /* Failed to destroy the timer. */
    TEE_ERROR_TIMER_DESTORY_FAILED     = 0xFFFF6002,
    /* The timer is not found. */
    TEE_ERROR_TIMER_NOT_FOUND          = 0xFFFF6003,
    /* Generic error of RPMB operations. */
    TEE_ERROR_RPMB_GENERIC             = 0xFFFF7001,
    /* Verify MAC failed in RPMB operations. */
    TEE_ERROR_RPMB_MAC_FAIL            = 0xFFFF7002,
    /* Incorrect message data MAC in RPMB response. */
    TEE_ERROR_RPMB_RESP_UNEXPECT_MAC   = 0xFFFF7105,
    /* The file is not found in RPMB.  */
    TEE_ERROR_RPMB_FILE_NOT_FOUND      = 0xFFFF7106,
    /* No spece left for RPMB operations. */
    TEE_ERROR_RPMB_NOSPC               = 0xFFFF7107,
    /* sec flash is not available. */
    TEE_ERROR_SEC_FLASH_NOT_AVAILABLE  = 0xFFFF7118,
    /* The BIO service is not available. */
    TEE_ERROR_BIOSRV_NOT_AVAILABLE     = 0xFFFF711A,
    /* The ROT service is not available.  */
    TEE_ERROR_ROTSRV_NOT_AVAILABLE     = 0xFFFF711B,
    /* The TA Anti-Rollback service is not available. */
    TEE_ERROR_ARTSRV_NOT_AVAILABLE     = 0xFFFF711C,
    /* The HSM service is not available. */
    TEE_ERROR_HSMSRV_NOT_AVAILABLE     = 0xFFFF711D,
    /* Failed to verify AntiRoot response. */
    TEE_ERROR_ANTIROOT_RSP_FAIL        = 0xFFFF9110,
    /* AntiRoot error in invokeCmd(). */
    TEE_ERROR_ANTIROOT_INVOKE_ERROR    = 0xFFFF9111,
    /* Audit failed. */
    TEE_ERROR_AUDIT_FAIL               = 0xFFFF9112,
    /* Unused. */
    TEE_FAIL2                          = 0xFFFF9113,
};

/**
 * @brief Login type definitions
 *
 * @since 12
 */
enum TEE_LoginMethod {
    TEE_LOGIN_PUBLIC = 0x0,
    TEE_LOGIN_USER,
    TEE_LOGIN_GROUP,
    TEE_LOGIN_APPLICATION      = 0x4,
    TEE_LOGIN_USER_APPLICATION = 0x5,
    TEE_LOGIN_GROUP_APPLICATION = 0x6,
    TEE_LOGIN_IDENTIFY = 0x7, /* Customized login type */
};

/**
 * @brief Definitions the TEE Identity.
 *
 * @since 12
 */
typedef struct {
    uint32_t login;
    TEE_UUID uuid;
} TEE_Identity;

/**
 * @brief Defines the return values.
 *
 * @since 12
 * @version 1.0
 */
typedef uint32_t TEE_Result;

/**
 * @brief Defines the return values.
 *
 * @since 12
 * @version 1.0
 */
typedef TEE_Result TEEC_Result;

#define TEE_ORIGIN_TEE             0x00000003
#define TEE_ORIGIN_TRUSTED_APP     0x00000004

#ifndef _TEE_TA_SESSION_HANDLE
#define _TEE_TA_SESSION_HANDLE
/**
 * @brief Defines the handle of TA session.
 *
 * @since 12
 */
typedef uint32_t TEE_TASessionHandle;
#endif

/**
 * @brief Defines the pointer to <b>TEE_ObjectEnumHandle</b>.
 *
 * @see __TEE_ObjectEnumHandle
 *
 * @since 12
 */
typedef struct __TEE_ObjectEnumHandle *TEE_ObjectEnumHandle;

/**
 * @brief Defines the pointer to <b>__TEE_OperationHandle</b>.
 *
 * @see __TEE_OperationHandle
 *
 * @since 12
 */
typedef struct __TEE_OperationHandle *TEE_OperationHandle;

#define TEE_TIMEOUT_INFINITE (0xFFFFFFFF)

/**
 * @brief Definitions the TEE time.
 *
 * @since 12
 */
typedef struct {
    uint32_t seconds;
    uint32_t millis;
} TEE_Time;

/**
 * @brief Definitions the date time of TEE.
 *
 * @since 12
 */
typedef struct {
    int32_t seconds;
    int32_t millis;
    int32_t min;
    int32_t hour;
    int32_t day;
    int32_t month;
    int32_t year;
} TEE_Date_Time;

/**
 * @brief Definitions the timer property of TEE.
 *
 * @since 12
 */
typedef struct {
    uint32_t type;
    uint32_t timer_id;
    uint32_t timer_class;
    uint32_t reserved2;
} TEE_timer_property;

#ifdef __cplusplus
}
#endif
/** @} */
#endif