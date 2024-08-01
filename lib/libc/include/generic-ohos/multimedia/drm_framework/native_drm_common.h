/*
 * Copyright (C) 2023 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/**
 * @addtogroup Drm
 * @{
 *
 * @brief Provides APIs of Drm.
 * @kit DrmKit.
 * @since 11
 * @version 1.0
 */

/**
 * @file native_drm_common.h
 *
 * @brief Defines the Drm common struct.
 * @library libnative_drm.z.so
 * @syscap SystemCapability.Multimedia.Drm.Core
 * @since 11
 * @version 1.0
 */

#ifndef NATIVE_DRM_COMMON_H
#define NATIVE_DRM_COMMON_H

#include <stdint.h>
#include <stdio.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
  *
  * @brief Enumerates event types of listener.
  * @since 11
  * @version 1.0
*/
typedef enum DRM_EventType {
    /**
     * DRM event base.
     */
    EVENT_DRM_BASE = 200,
    /**
     * Provision required event.
     */
    EVENT_PROVISION_REQUIRED = 201,
    /**
     * Media key required event.
     */
    EVENT_KEY_REQUIRED = 202,
    /**
     * Media key expired event.
     */
    EVENT_KEY_EXPIRED = 203,
    /**
     * Vendor defined event.
     */
    EVENT_VENDOR_DEFINED = 204,
    /**
     * Expiration update event.
     */
    EVENT_EXPIRATION_UPDATE = 206,
  } DRM_EventType;

/**
 * @brief Content potection level.
 * @syscap SystemCapability.Multimedia.Drm.Core
 * @since 11
 * @version 1.0
 */
typedef enum DRM_ContentProtectionLevel {
    /**
     * Content potection level unknown.
     */
    CONTENT_PROTECTION_LEVEL_UNKNOWN = 0,
    /**
     * Content potection level software crypto.
     */
    CONTENT_PROTECTION_LEVEL_SW_CRYPTO,
    /**
     * Content potection level hardware crypto.
     */
    CONTENT_PROTECTION_LEVEL_HW_CRYPTO,
    /**
     * Content potection level enhanced hardware crypto.
     */
    CONTENT_PROTECTION_LEVEL_ENHANCED_HW_CRYPTO,
    /**
     * Content potection level max stub.
     */
    CONTENT_PROTECTION_LEVEL_MAX,
} DRM_ContentProtectionLevel;

/**
 * @brief Media key type.
 * @syscap SystemCapability.Multimedia.Drm.Core
 * @since 11
 * @version 1.0
 */
typedef enum DRM_MediaKeyType {
    /**
     * Media key type offline.
     */
    MEDIA_KEY_TYPE_OFFLINE = 0,
    /**
     * Media key type online
     */
    MEDIA_KEY_TYPE_ONLINE,
} DRM_MediaKeyType;

/**
 * @brief Media key request type.
 * @syscap SystemCapability.Multimedia.Drm.Core
 * @since 11
 * @version 1.0
 */
typedef enum DRM_MediaKeyRequestType {
    /**
     * Media key request type unknown.
     */
    MEDIA_KEY_REQUEST_TYPE_UNKNOWN = 0,
    /**
     * Media key request type initial.
     */
    MEDIA_KEY_REQUEST_TYPE_INITIAL,
    /**
     * Media key request type renewal.
     */
    MEDIA_KEY_REQUEST_TYPE_RENEWAL,
    /**
     * Media key request type release.
     */
    MEDIA_KEY_REQUEST_TYPE_RELEASE,
    /**
     * Media key request type none.
     */
    MEDIA_KEY_REQUEST_TYPE_NONE,
    /**
     * Media key request type update.
     */
    MEDIA_KEY_REQUEST_TYPE_UPDATE,
} DRM_MediaKeyRequestType;

/**
 * @brief Offline media key status.
 * @syscap SystemCapability.Multimedia.Drm.Core
 * @since 11
 * @version 1.0
 */
typedef enum DRM_OfflineMediaKeyStatus {
    /**
     * Offline media key status unknown.
     */
    OFFLINE_MEDIA_KEY_STATUS_UNKNOWN = 0,
    /**
     * Offline media key status usable.
     */
    OFFLINE_MEDIA_KEY_STATUS_USABLE,
    /**
     * Offline media key status inactive.
     */
    OFFLINE_MEDIA_KEY_STATUS_INACTIVE,
} DRM_OfflineMediaKeyStatus;

/**
 * @brief Certificate status.
 * @syscap SystemCapability.Multimedia.Drm.Core
 * @since 11
 * @version 1.0
 */
typedef enum DRM_CertificateStatus {
    /**
     * Device already provisioned.
     */
    CERT_STATUS_PROVISIONED = 0,
    /**
     * Device not provisioned.
     */
    CERT_STATUS_NOT_PROVISIONED,
    /**
     * Cert already expired.
     */
    CERT_STATUS_EXPIRED,
    /**
     * Certs are invalid.
     */
    CERT_STATUS_INVALID,
    /**
     * Get certs status failed.
     */
    CERT_STATUS_UNAVAILABLE,
} DRM_CertificateStatus;

/**
 * @brief Max count of media key request option.
 * @since 11
 * @version 1.0
 */
#define MAX_MEDIA_KEY_REQUEST_OPTION_COUNT 16
/**
 * @brief Max len of media key request option name.
 * @since 11
 * @version 1.0
 */
#define MAX_MEDIA_KEY_REQUEST_OPTION_NAME_LEN 64
/**
 * @brief Max len of media key request option data.
 * @since 11
 * @version 1.0
 */
#define MAX_MEDIA_KEY_REQUEST_OPTION_DATA_LEN 128
/**
 * @brief Max len of media key request init data.
 * @since 11
 * @version 1.0
 */
#define MAX_INIT_DATA_LEN 2048
/**
 * @brief Max len of media mimetype.
 * @since 11
 * @version 1.0
 */
#define MAX_MIMETYPE_LEN 64

/**
 * @brief Media key request info.
 * @since 11
 * @version 1.0
 */
typedef struct DRM_MediaKeyRequestInfo {
    /**
     * Offline or online media key type.
     */
    DRM_MediaKeyType type;
    /**
     * Initial data len.
     */
    int32_t initDataLen;
    /**
     * Initial data format as PSSH after base64 encoding.
     */
    uint8_t initData[MAX_INIT_DATA_LEN];
    /**
     * Media content mime type.
     */
    char mimeType[MAX_MIMETYPE_LEN];
    /**
     * OptionsData count.
     */
    uint32_t optionsCount;
    /**
     * Options name the application set to drm framework.
     */
    char optionName[MAX_MEDIA_KEY_REQUEST_OPTION_COUNT][MAX_MEDIA_KEY_REQUEST_OPTION_NAME_LEN];
    /**
     * Options data the application set to drm framework.
     */
    char optionData[MAX_MEDIA_KEY_REQUEST_OPTION_COUNT][MAX_MEDIA_KEY_REQUEST_OPTION_DATA_LEN];
} DRM_MediaKeyRequestInfo;

/**
 * @brief Max len of media key request.
 * @since 11
 * @version 1.0
 */
#define MAX_MEDIA_KEY_REQUEST_DATA_LEN 8192
/**
 * @brief Max len of URL.
 * @since 11
 * @version 1.0
 */
#define MAX_DEFAULT_URL_LEN 2048
/**
 * @brief Media key request.
 * @since 11
 * @version 1.0
 */
typedef struct DRM_MediaKeyRequest {
    /**
     * Media key request type.
     */
    DRM_MediaKeyRequestType type;
    /**
     * Media key request data len.
     */
    int32_t dataLen;
    /**
     * Media key request data sent to media key server.
     */
    uint8_t data[MAX_MEDIA_KEY_REQUEST_DATA_LEN];
    /**
     * Media key server URL.
     */
    char defaultUrl[MAX_DEFAULT_URL_LEN];
} DRM_MediaKeyRequest;

/**
 * @brief Max count of statistics item.
 * @since 11
 * @version 1.0
 */
#define MAX_STATISTICS_COUNT 10
/**
 * @brief Max len of statistics item name.
 * @since 11
 * @version 1.0
 */
#define MAX_STATISTICS_NAME_LEN 64
/**
 * @brief Max len of statistics item buffer.
 * @since 11
 * @version 1.0
 */
#define MAX_STATISTICS_BUFFER_LEN 256

/**
 * @brief Statistics of MediaKeySystem.
 * @since 11
 * @version 1.0
 */
typedef struct DRM_Statistics {
    /* Statistics count. */
    uint32_t statisticsCount;
    /* Statistics name. */
    char statisticsName[MAX_STATISTICS_COUNT][MAX_STATISTICS_NAME_LEN];
    /* Statistics description. */
    char statisticsDescription[MAX_STATISTICS_COUNT][MAX_STATISTICS_BUFFER_LEN];
} DRM_Statistics;

/**
 * @brief Max count of offline media key id.
 * @since 11
 * @version 1.0
 */
#define MAX_OFFLINE_MEDIA_KEY_ID_COUNT 512
/**
 * @brief Max len of offline media key id.
 * @since 11
 * @version 1.0
 */
#define MAX_OFFLINE_MEDIA_KEY_ID_LEN 64

/**
 * @brief Offline media key ids array.
 * @since 11
 * @version 1.0
 */
typedef struct DRM_OfflineMediakeyIdArray {
    /* Ids count. */
    uint32_t idsCount;
    /* Ids len. */
    int32_t idsLen[MAX_OFFLINE_MEDIA_KEY_ID_COUNT];
    /* Ids. */
    uint8_t ids[MAX_OFFLINE_MEDIA_KEY_ID_COUNT][MAX_OFFLINE_MEDIA_KEY_ID_LEN];
} DRM_OfflineMediakeyIdArray;

/**
 * @brief Max count of key info.
 * @since 11
 * @version 1.0
 */
#define MAX_KEY_INFO_COUNT 64
/**
 * @brief Max len of key id.
 * @since 11
 * @version 1.0
 */
#define MAX_KEY_ID_LEN 16
/**
 * @brief Max len of key status value.
 * @since 11
 * @version 1.0
 */
#define MAX_KEY_STATUS_VALUE_LEN 128

/**
 * @brief Media key info.
 * @since 11
 * @version 1.0
 */
typedef struct DRM_KeysInfo {
    /* Keys count. */
    uint32_t keysInfoCount;
    /* Key id. */
    uint8_t keyId[MAX_KEY_INFO_COUNT][MAX_KEY_ID_LEN];
    /* Key status value. */
    char statusValue[MAX_KEY_INFO_COUNT][MAX_KEY_STATUS_VALUE_LEN];
} DRM_KeysInfo;

/**
 * @brief Max count of media key status.
 * @since 11
 * @version 1.0
 */
#define MAX_MEDIA_KEY_STATUS_COUNT 64
/**
 * @brief Max len of media key status name.
 * @since 11
 * @version 1.0
 */
#define MAX_MEDIA_KEY_STATUS_NAME_LEN 64
/**
 * @brief Max len of media key status value.
 * @since 11
 * @version 1.0
 */
#define MAX_MEDIA_KEY_STATUS_VALUE_LEN 256

/**
 * @brief Media key status like pocily etc.
 * @since 11
 * @version 1.0
 */
typedef struct DRM_MediaKeyStatus {
    /* Status count. */
    uint32_t statusCount;
    /* Status name. */
    char statusName[MAX_MEDIA_KEY_STATUS_COUNT][MAX_MEDIA_KEY_STATUS_NAME_LEN];
    /* Status value. */
    char statusValue[MAX_MEDIA_KEY_STATUS_COUNT][MAX_MEDIA_KEY_STATUS_VALUE_LEN];
} DRM_MediaKeyStatus;

/**
 * @brief Drm system uuid len.
 * @since 11
 * @version 1.0
 */
#define DRM_UUID_LEN 16
/**
 * @brief Max len of PSSH data.
 * @since 11
 * @version 1.0
 */
#define MAX_PSSH_DATA_LEN 2048

/**
 * @brief PSSH info by uuid.
 * @since 11
 * @version 1.0
 */
typedef struct DRM_PsshInfo {
    /**
     * Uuid.
     */
    uint8_t uuid[DRM_UUID_LEN];
    /**
     * PSSH data len.
     */
    int32_t dataLen;
    /**
     * uint8_t PSSH data.
     */
    uint8_t data[MAX_PSSH_DATA_LEN];
} DRM_PsshInfo;

/**
 * @brief Max count of PSSH info.
 * @since 11
 * @version 1.0
 */
#define MAX_PSSH_INFO_COUNT 8

/**
 * @brief MediaKeySystemInfo used for player to get media key system info from media source.
 * @since 11
 * @version 1.0
 */
typedef struct DRM_MediaKeySystemInfo {
    /* PSSH count. */
    uint32_t psshCount;
    /* PSSH info. */
    DRM_PsshInfo psshInfo[MAX_PSSH_INFO_COUNT];
} DRM_MediaKeySystemInfo;

typedef void (*DRM_MediaKeySystemInfoCallback)(DRM_MediaKeySystemInfo *mediaKeySystemInfo);

/**
 * @brief Media key system struct.
 * @since 11
 * @version 1.0
 */
typedef struct MediaKeySystem MediaKeySystem;

/**
 * @brief Media key session struct.
 * @since 11
 * @version 1.0
 */
typedef struct MediaKeySession MediaKeySession;
/**
 * @brief Max len of media key system name.
 * @since 12
 * @version 1.0
 */
#define MAX_MEDIA_KEY_SYSTEM_NAME_LEN 128

/**
 * @brief Max num of media key system supported
 * @since 12
 * @version 1.0
 */
#define MAX_MEDIA_KEY_SYSTEM_NUM 8

/**
 * @brief Name and UUID of DRM plugin.
 * @since 12
 * @version 1.0
 */
typedef struct DRM_MediaKeySystemDescription {
    /* Name of DRM plugin. */
    char name[MAX_MEDIA_KEY_SYSTEM_NAME_LEN];
    /* uuid. */
    uint8_t uuid[DRM_UUID_LEN];
} DRM_MediaKeySystemDescription;

#ifdef __cplusplus
}
#endif

#endif // NATIVE_DRM_COMMON_H