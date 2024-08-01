/*
 * Copyright (C) 2023 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/**
 * @addtogroup Multimedia_Drm
 * @{
 *
 * @brief This feature enables third-party applications to implement the
 * media decapsulation and demultiplexing functions by themselves instead
 * of using the functions provided by the system.
 *
 * After the DRM instance and session are created, the decryption interface
 * provided by the DRM can be invoked for decryption. The decryption parameter
 * structure defines the transmission format of decryption parameters.
 *
 * @since 12
 */

/**
 * @file native_cencinfo.h
 *
 * @brief Provides a unified entry for the native module APIs.
 *
 * @library libnative_media_avcencinfo.so
 * @syscap SystemCapability.Multimedia.Media.Spliter
 * @since 12
 */

#ifndef NATIVE_AVCENCINFO_H
#define NATIVE_AVCENCINFO_H

#include <stdint.h>
#include "native_averrors.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief AVBuffer Structure.
 * @since 12
 * @version 1.0
 */
typedef struct OH_AVBuffer OH_AVBuffer;
/**
 * @brief AVCencInfo Structure.
 * @since 12
 * @version 1.0
 */
typedef struct OH_AVCencInfo OH_AVCencInfo;
/**
 * @brief Key id size.
 * @since 12
 * @version 1.0
 */
#define DRM_KEY_ID_SIZE 16
/**
 * @brief Iv size.
 * @since 12
 * @version 1.0
 */
#define DRM_KEY_IV_SIZE 16
/**
 * @brief Max subsample num.
 * @since 12
 * @version 1.0
 */
#define DRM_KEY_MAX_SUB_SAMPLE_NUM 64

/**
 * @brief Drm cenc algorithm type.
 * @since 12
 * @version 1.0
 */
typedef enum DrmCencAlgorithm {
    /**
     * Unencrypted.
     */
    DRM_ALG_CENC_UNENCRYPTED = 0x0,
    /**
     * Aes ctr.
     */
    DRM_ALG_CENC_AES_CTR = 0x1,
    /**
     * Aes wv.
     */
    DRM_ALG_CENC_AES_WV = 0x2,
    /**
     * Aes cbc.
     */
    DRM_ALG_CENC_AES_CBC = 0x3,
    /**
     * Sm4 cbc.
     */
    DRM_ALG_CENC_SM4_CBC = 0x4,
    /**
     * Sm4 ctr.
     */
    DRM_ALG_CENC_SM4_CTR = 0x5
} DrmCencAlgorithm;

/**
 * @brief Mode of cend info like set or not.
 * @since 12
 * @version 1.0
 */
typedef enum DrmCencInfoMode {
    /* key/iv/subsample set. */
    DRM_CENC_INFO_KEY_IV_SUBSAMPLES_SET = 0x0,
    /* key/iv/subsample not set. */
    DRM_CENC_INFO_KEY_IV_SUBSAMPLES_NOT_SET = 0x1
} DrmCencInfoMode;

/**
 * @brief Subsample info of media.
 * @since 12
 * @version 1.0
 */
typedef struct DrmSubsample {
    /* Clear header len. */
    uint32_t clearHeaderLen;
    /* Payload Len. */
    uint32_t payLoadLen;
} DrmSubsample;

/**
 * @brief Creates an OH_AVCencInfo instance for setting cencinfo.
 *
 * Free the resources of the instance by calling OH_AVCencInfo_Destory.
 * @syscap SystemCapability.Multimedia.Media.Spliter
 * @return Returns the newly created OH_AVCencInfo object. If nullptr is returned, the object failed to be created.
 *         The possible failure is due to the application address space being full,
 *         or the data in the initialization object has failed.
 * @since 12
 * @version 1.0
 */
OH_AVCencInfo *OH_AVCencInfo_Create();

/**
 * @brief Destroy the OH_AVCencInfo instance and free the internal resources.
 *
 * The same instance can only be destroyed once. The destroyed instance
 * should not be used before it is created again. It is recommended setting
 * the instance pointer to NULL right after the instance is destroyed successfully.
 * @syscap SystemCapability.Multimedia.Media.Spliter
 * @param cencInfo Pointer to an OH_AVCencInfo instance.
 * @return {@link AV_ERR_OK} 0 - Success
 *         {@link AV_ERR_INVALID_VAL} 3 - cencInfo is nullptr.
 * @since 12
 * @version 1.0
*/
OH_AVErrCode OH_AVCencInfo_Destroy(OH_AVCencInfo *cencInfo);

/**
 * @brief Method to set algo of cencinfo.
 *
 * @syscap SystemCapability.Multimedia.Media.Spliter
 * @param cencInfo Pointer to an OH_AVCencInfo instance.
 * @param algo Cenc algo.
 * @return {@link AV_ERR_OK} 0 - Success
 *         {@link AV_ERR_INVALID_VAL} 3 - cencInfo is nullptr.
 * @since 12
 * @version 1.0
 */
OH_AVErrCode OH_AVCencInfo_SetAlgorithm(OH_AVCencInfo *cencInfo, enum DrmCencAlgorithm algo);

/**
 * @brief Method to set key id and iv of cencinfo.
 *
 * @syscap SystemCapability.Multimedia.Media.Spliter
 * @param cencInfo Pointer to an OH_AVCencInfo instance.
 * @param keyId Key id.
 * @param keyIdLen Key id len.
 * @param iv Iv.
 * @param ivLen Iv len.
 * @return {@link AV_ERR_OK} 0 - Success
 *         {@link AV_ERR_INVALID_VAL} 3 - If cencInfo is nullptr, or keyId is nullptr, or keyIdLen != DRM_KEY_ID_SIZE,
 *         or iv is nullptr, or ivLen != DRM_KEY_IV_SIZE, or keyId copy fails, or iv copy fails.
 * @since 12
 * @version 1.0
 */
OH_AVErrCode OH_AVCencInfo_SetKeyIdAndIv(OH_AVCencInfo *cencInfo, uint8_t *keyId,
    uint32_t keyIdLen, uint8_t *iv, uint32_t ivLen);

/**
 * @brief Method to set subsample info of cencinfo.
 *
 * @syscap SystemCapability.Multimedia.Media.Spliter
 * @param cencInfo Pointer to an OH_AVCencInfo instance.
 * @param encryptedBlockCount Number of encrypted blocks.
 * @param skippedBlockCount Number of skip(clear) blocks.
 * @param firstEncryptedOffset Offset of first encrypted payload.
 * @param subsampleCount Subsample num.
 * @param subsamples Subsample info
 * @return {@link AV_ERR_OK} 0 - Success
 *         {@link AV_ERR_INVALID_VAL} 3 - If cencInfo is nullptr, or subsampleCount > DRM_KEY_MAX_SUB_SAMPLE_NUM,
 *         or subsamples is nullptr.
 * @since 12
 * @version 1.0
 */
OH_AVErrCode OH_AVCencInfo_SetSubsampleInfo(OH_AVCencInfo *cencInfo, uint32_t encryptedBlockCount,
    uint32_t skippedBlockCount, uint32_t firstEncryptedOffset, uint32_t subsampleCount, DrmSubsample *subsamples);

/**
 * @brief Method to set mode of cencinfo.
 *
 * @syscap SystemCapability.Multimedia.Media.Spliter
 * @param cencInfo Pointer to an OH_AVCencInfo instance.
 * @param mode Cenc mode, indicate whether key/iv/subsample set or not.
 * @return {@link AV_ERR_OK} 0 - Success
 *         {@link AV_ERR_INVALID_VAL} 3 - cencInfo is nullptr.
 * @since 12
 * @version 1.0
 */
OH_AVErrCode OH_AVCencInfo_SetMode(OH_AVCencInfo *cencInfo, enum DrmCencInfoMode mode);

/**
 * @brief Method to attach cencinfo to AVBuffer.
 *
 * @syscap SystemCapability.Multimedia.Media.Spliter
 * @param cencInfo Pointer to an OH_AVCencInfo instance.
 * @param buffer AVBuffer to attach cencinfo.
 * @return {@link AV_ERR_OK} 0 - Success
 *         {@link AV_ERR_INVALID_VAL} 3 - If cencInfo is nullptr, or buffer is nullptr, or buffer->buffer_ is nullptr,
 *         or buffer->buffer_->meta_ is nullptr.
 * @since 12
 * @version 1.0
 */
OH_AVErrCode OH_AVCencInfo_SetAVBuffer(OH_AVCencInfo *cencInfo, OH_AVBuffer *buffer);

#ifdef __cplusplus
}
#endif

#endif // NATIVE_AVCENCINFO_H