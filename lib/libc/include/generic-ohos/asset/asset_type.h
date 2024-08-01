/*
 * Copyright (c) 2023 Huawei Device Co., Ltd.
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

#ifndef ASSET_TYPE_H
#define ASSET_TYPE_H

/**
 * @addtogroup AssetType
 * @{
 *
 * @brief Provides the enums, structs, and error codes used in the Asset APIs.
 *
 * @since 11
 */

/**
 * @file asset_type.h
 *
 * @brief Defines the enums, structs, and error codes used in the Asset APIs.
 *
 * @library libasset_ndk.z.so
 * @kit AssetStoreKit
 * @syscap SystemCapability.Security.Asset
 * @since 11
 */

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Enumerates the types of the asset attribute tags.
 *
 * @since 11
 */
typedef enum {
    /**
     * The asset attribute tag is a Boolean value.
     */
    ASSET_TYPE_BOOL = 0x1 << 28,
    /**
     * The asset attribute tag is a number.
     */
    ASSET_TYPE_NUMBER = 0x2 << 28,
    /**
     * The asset attribute tag is an array of bytes.
     */
    ASSET_TYPE_BYTES = 0x3 << 28,
} Asset_TagType;

/**
 * @brief Defines the mask used to obtain the type of the asset attribute tag.
 *
 * @since 11
 */
#define ASSET_TAG_TYPE_MASK (0xF << 28)

/**
 * @brief Enumerates the asset attribute tags.
 *
 * @since 11
 */
typedef enum {
    /**
     * Sensitive user data in the form of bytes, such as passwords and tokens.
     */
    ASSET_TAG_SECRET = ASSET_TYPE_BYTES | 0x01,
    /**
     * Asset alias (identifier) in the form of bytes.
     */
    ASSET_TAG_ALIAS = ASSET_TYPE_BYTES | 0x02,
    /**
     * Time when the asset is accessible. The value is of the uint32 type, which is a 32-bit unsigned integer.
     */
    ASSET_TAG_ACCESSIBILITY = ASSET_TYPE_NUMBER | 0x03,
    /**
     * A Boolean value indicating whether the asset is available only with a lock screen password.
     */
    ASSET_TAG_REQUIRE_PASSWORD_SET = ASSET_TYPE_BOOL | 0x04,
    /**
     * User authentication type for the asset. The value is of the uint32 type.
     */
    ASSET_TAG_AUTH_TYPE = ASSET_TYPE_NUMBER | 0x05,
    /**
     * Validity period of the user authentication, in seconds. The value is of the uint32 type.
     */
    ASSET_TAG_AUTH_VALIDITY_PERIOD = ASSET_TYPE_NUMBER | 0x06,
    /**
     * Challenge value, in the form of bytes, used for anti-replay during the authentication.
     */
    ASSET_TAG_AUTH_CHALLENGE = ASSET_TYPE_BYTES | 0x07,
    /**
     * Authentication token, in the form of bytes, obtained after a successful user authentication.
     */
    ASSET_TAG_AUTH_TOKEN = ASSET_TYPE_BYTES | 0x08,
    /**
     * Asset synchronization type. The value is of the uint32 type.
     */
    ASSET_TAG_SYNC_TYPE = ASSET_TYPE_NUMBER | 0x10,
    /**
     * A Boolean value indicating whether the asset needs to be stored persistently.
     * The ohos.permission.STORE_PERSISTENT_DATA permission is required if <b>OH_Asset_Add</b> is called with this tag.
     *
     * @permission ohos.permission.STORE_PERSISTENT_DATA
     */
    ASSET_TAG_IS_PERSISTENT = ASSET_TYPE_BOOL | 0x11,
    /**
     * An immutable custom field, in the form of bytes.
     */
    ASSET_TAG_DATA_LABEL_CRITICAL_1 = ASSET_TYPE_BYTES | 0x20,
    /**
     * An immutable custom field, in the form of bytes.
     */
    ASSET_TAG_DATA_LABEL_CRITICAL_2 = ASSET_TYPE_BYTES | 0x21,
    /**
     * An immutable custom field, in the form of bytes.
     */
    ASSET_TAG_DATA_LABEL_CRITICAL_3 = ASSET_TYPE_BYTES | 0x22,
    /**
     * An immutable custom field, in the form of bytes.
     */
    ASSET_TAG_DATA_LABEL_CRITICAL_4 = ASSET_TYPE_BYTES | 0x23,
    /**
     * A mutable custom field, in the form of bytes.
     */
    ASSET_TAG_DATA_LABEL_NORMAL_1 = ASSET_TYPE_BYTES | 0x30,
    /**
     * A mutable custom field, in the form of bytes.
     */
    ASSET_TAG_DATA_LABEL_NORMAL_2 = ASSET_TYPE_BYTES | 0x31,
    /**
     * A mutable custom field, in the form of bytes.
     */
    ASSET_TAG_DATA_LABEL_NORMAL_3 = ASSET_TYPE_BYTES | 0x32,
    /**
     * A mutable custom field, in the form of bytes.
     */
    ASSET_TAG_DATA_LABEL_NORMAL_4 = ASSET_TYPE_BYTES | 0x33,
    /**
     * A mutable custom field, in the form of bytes. The information of a local tag will not be synchronized.
     *
     * @since 12
     */
    ASSET_TAG_DATA_LABEL_NORMAL_LOCAL_1 = ASSET_TYPE_BYTES | 0x34,
    /**
     * A mutable custom field, in the form of bytes. The information of a local tag will not be synchronized.
     *
     * @since 12
     */
    ASSET_TAG_DATA_LABEL_NORMAL_LOCAL_2 = ASSET_TYPE_BYTES | 0x35,
    /**
     * A mutable custom field, in the form of bytes. The information of a local tag will not be synchronized.
     *
     * @since 12
     */
    ASSET_TAG_DATA_LABEL_NORMAL_LOCAL_3 = ASSET_TYPE_BYTES | 0x36,
    /**
     * A mutable custom field, in the form of bytes. The information of a local tag will not be synchronized.
     *
     * @since 12
     */
    ASSET_TAG_DATA_LABEL_NORMAL_LOCAL_4 = ASSET_TYPE_BYTES | 0x37,
    /**
     * Return type of the queried asset. The value is of the uint32 type.
     */
    ASSET_TAG_RETURN_TYPE = ASSET_TYPE_NUMBER | 0x40,
    /**
     * Maximum number of assets that can be returned at a time if multiple asset records match the specified conditions.
     * The value is of the uint32 type.
     */
    ASSET_TAG_RETURN_LIMIT = ASSET_TYPE_NUMBER | 0x41,
    /**
     * Offset that indicates the start asset when multiple asset records are returned. The value is of the uint32 type.
     */
    ASSET_TAG_RETURN_OFFSET = ASSET_TYPE_NUMBER | 0x42,
    /**
     * Sorting order of the assets in the query result. The value is of the uint32 type.
     */
    ASSET_TAG_RETURN_ORDERED_BY = ASSET_TYPE_NUMBER | 0x43,
    /**
     * Policy used to resolve the conflict occurred when an asset is added. The value is of the uint32 type.
     */
    ASSET_TAG_CONFLICT_RESOLUTION = ASSET_TYPE_NUMBER | 0x44,
    /**
     * A tag whose value is a byte array indicating the update time of an Asset.
     *
     * @since 12
     */
    ASSET_TAG_UPDATE_TIME = ASSET_TYPE_BYTES | 0x45,
    /**
     * A tag whose value is the uint32 type indicating the additional action.
     *
     * @since 12
     */
    ASSET_TAG_OPERATION_TYPE = ASSET_TYPE_NUMBER | 0x46,
} Asset_Tag;

/**
 * @brief Enumerates the result codes used in the ASSET APIs.
 *
 * @since 11
 */
typedef enum {
    /** @error The operation is successful. */
    ASSET_SUCCESS = 0,
    /** @error The caller doesn't have the permission. */
    ASSET_PERMISSION_DENIED = 201,
    /** @error The parameter is invalid. */
    ASSET_INVALID_ARGUMENT = 401,
    /** @error The ASSET service is unavailable. */
    ASSET_SERVICE_UNAVAILABLE = 24000001,
    /** @error The asset is not found. */
    ASSET_NOT_FOUND = 24000002,
    /** @error The asset already exists. */
    ASSET_DUPLICATED = 24000003,
    /** @error Access to the asset is denied. */
    ASSET_ACCESS_DENIED = 24000004,
    /** @error The screen lock status does not match. */
    ASSET_STATUS_MISMATCH = 24000005,
    /** @error Insufficient memory. */
    ASSET_OUT_OF_MEMORY = 24000006,
    /** @error The asset is corrupted. */
    ASSET_DATA_CORRUPTED = 24000007,
    /** @error The database operation failed. */
    ASSET_DATABASE_ERROR = 24000008,
    /** @error The cryptography operation failed. */
    ASSET_CRYPTO_ERROR = 24000009,
    /** @error IPC failed. */
    ASSET_IPC_ERROR = 24000010,
    /** @error Calling the Bundle Manager service failed. */
    ASSET_BMS_ERROR = 24000011,
    /** @error Calling the OS Account service failed. */
    ASSET_ACCOUNT_ERROR = 24000012,
    /** @error Calling the Access Token service failed. */
    ASSET_ACCESS_TOKEN_ERROR = 24000013,
    /** @error The file operation failed. */
    ASSET_FILE_OPERATION_ERROR = 24000014,
    /** @error Getting the system time failed. */
    ASSET_GET_SYSTEM_TIME_ERROR = 24000015,
    /** @error The cache exceeds the limit. */
    ASSET_LIMIT_EXCEEDED = 24000016,
    /** @error The capability is not supported. */
    ASSET_UNSUPPORTED = 24000017,
} Asset_ResultCode;

/**
 * @brief Enumerates the types of the access control based on the lock screen status.
 *
 * @since 11
 */
typedef enum {
    /**
     * The asset can be accessed after the device is powered on.
     */
    ASSET_ACCESSIBILITY_DEVICE_POWERED_ON = 0,
    /**
     * The asset can be accessed only after the device is unlocked for the first time.
     */
    ASSET_ACCESSIBILITY_DEVICE_FIRST_UNLOCKED = 1,
    /**
     * The asset can be accessed only after the device is unlocked.
     */
    ASSET_ACCESSIBILITY_DEVICE_UNLOCKED = 2,
} Asset_Accessibility;

/**
 * @brief Enumerates the user authentication types supported for assets.
 *
 * @since 11
 */
typedef enum {
    /**
     * No user authentication is required before the asset is accessed.
     */
    ASSET_AUTH_TYPE_NONE = 0x00,
    /**
     * The asset can be accessed if any user authentication (such as PIN, facial, or fingerprint authentication) is
     * successful.
     */
    ASSET_AUTH_TYPE_ANY = 0xFF,
} Asset_AuthType;

/**
 * @brief Enumerates the asset synchronization types.
 *
 * @since 11
 */
typedef enum {
    /**
     * Asset synchronization is not allowed.
     */
    ASSET_SYNC_TYPE_NEVER = 0,
    /**
     * Asset synchronization is allowed only on the local device, for example, in data restoration on the local device.
     */
    ASSET_SYNC_TYPE_THIS_DEVICE = 1 << 0,
    /**
     * Asset synchronization is allowed only between trusted devices, for example, in the case of cloning.
     */
    ASSET_SYNC_TYPE_TRUSTED_DEVICE = 1 << 1,
    /**
     * Asset synchronization is allowed only between devices with trusted accounts.
     *
     * @since 12
     */
    ASSET_SYNC_TYPE_TRUSTED_ACCOUNT = 1 << 2,
} Asset_SyncType;

/**
 * @brief Enumerates the policies for resolving the conflict (for example, duplicate alias) occurred when
 * an asset is added.
 *
 * @since 11
 */
typedef enum {
    /**
     * Overwrite the existing asset.
     */
    ASSET_CONFLICT_OVERWRITE = 0,
    /**
     * Throw an exception for the service to perform subsequent processing.
     */
    ASSET_CONFLICT_THROW_ERROR = 1,
} Asset_ConflictResolution;

/**
 * @brief Enumerates the types of the asset query result.
 *
 * @since 11
 */
typedef enum {
    /**
     * The query result contains the asset in plaintext and its attributes.
     */
    ASSET_RETURN_ALL = 0,
    /**
     * The query result contains only the asset attributes.
     */
    ASSET_RETURN_ATTRIBUTES = 1,
} Asset_ReturnType;

/**
 * @brief Enumerates the types of the additional action.
 *
 * @since 12
 */
typedef enum {
    /**
     * Synchronization is required during operation.
     */
    ASSET_NEED_SYNC = 0,
    /**
     * Logout is required during operation.
     */
    ASSET_NEED_LOGOUT = 1,
} Asset_OperationType;

/**
 * @brief Defines an asset value in the forma of a binary array, that is, a variable-length byte array.
 *
 * @since 11
 */
typedef struct {
    /**
     * Size of the byte array.
     */
    uint32_t size;
    /**
     * Pointer to the byte array.
     */
    uint8_t *data;
} Asset_Blob;

/**
 * @brief Defines the value (content) of an asset attribute.
 *
 * @since 11
 */
typedef union {
    /**
     * Asset of the Boolean type.
     */
    bool boolean;
    /**
     * Asset of the uint32 type.
     */
    uint32_t u32;
    /**
     * Asset of the bytes type.
     */
    Asset_Blob blob;
} Asset_Value;

/**
 * @brief Defines an asset attribute.
 *
 * @since 11
 */
typedef struct {
    /**
     * Tag of the asset attribute.
     */
    uint32_t tag;
    /**
     * Value of the asset attribute.
     */
    Asset_Value value;
} Asset_Attr;

/**
 * @brief Represents information about an asset.
 *
 * @since 11
 */
typedef struct {
    /**
     * Number of asset attributes.
     */
    uint32_t count;
    /**
     * Pointer to the array of the asset attributes.
     */
    Asset_Attr *attrs;
} Asset_Result;

/**
 * @brief Represents information about a set of assets.
 *
 * @since 11
 */
typedef struct {
    /**
     * Number of assets.
     */
    uint32_t count;
    /**
     * Pointer to the array of the assets.
     */
    Asset_Result *results;
} Asset_ResultSet;

#ifdef __cplusplus
}
#endif

/** @} */
#endif // ASSET_TYPE_H