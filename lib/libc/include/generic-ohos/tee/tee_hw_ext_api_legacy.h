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

#ifndef __TEE_HW_EXT_API_LEGACY_H__
#define __TEE_HW_EXT_API_LEGACY_H__

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
 * @file tee_hw_ext_api_legacy.h
 *
 * @brief Provides extended interfaces.
 *
 * @library NA
 * @kit TEE Kit
 * @syscap SystemCapability.Tee.TeeClient
 * @since 12
 * @version 1.0
 */

#include "tee_defines.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Derive key from device root key.
 *
 * @param salt [IN] Indicates the data for salt.
 * @param size [IN] Indicates the length of salt.
 * @param key [OUT] Indicates the pointer where key is saved.
 * @param key_size [IN] Indicates the size of the key, which must be integer times of 16.
 *
 * @return Returns {@code TEE_SUCCESS} if the operation is successful.
 *         Returns {@code TEE_ERROR_BAD_PARAMETERS} if input parameter is incorrect.
 *         Returns {@code TEE_ERROR_GENERIC} if the processing failed.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_EXT_DeriveTARootKey(const uint8_t *salt, uint32_t size, uint8_t *key, uint32_t key_size);

/**
 * @brief Derive key from device root key by HUK2.
 * @attention If the device does not support HUK2, the key is derived by HUK.
 *
 * @param salt [IN] Indicates the data for salt.
 * @param size [IN] Indicates the length of salt.
 * @param key [OUT] Indicates the pointer where key is saved.
 * @param key_size [IN] Indicates the size of the key, which must be integer times of 16.
 *
 * @return Returns {@code TEE_SUCCESS} if the operation is successful.
 *         Returns {@code TEE_ERROR_BAD_PARAMETERS} if input parameter is incorrect.
 *         Returns {@code TEE_ERROR_GENERIC} if the processing failed.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result tee_ext_derive_ta_root_key_by_huk2(const uint8_t *salt, uint32_t size, uint8_t *key, uint32_t key_size);

/**
 * @brief Derive key from device root key by HUK2.
 * @attention If the device does not support HUK2, the key is derived by HUK.
 *
 * @param secret [IN] Indicates the input secret.
 * @param secret_len [IN] Indicates the length of the input secret.
 * @param key [OUT] Indicates the derived key.
 * @param key_len [IN] Indicates the length of the derived key.
 *
 * @return Returns {@code TEE_SUCCESS} if the operation is successful.
 *         Returns {@code TEE_ERROR_BAD_PARAMETERS} if input parameter is incorrect.
 *         Returns {@code TEE_ERROR_GENERIC} if the processing failed.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result tee_ext_root_derive_key2_by_huk2(const uint8_t *secret, uint32_t secret_len, uint8_t *key, uint32_t key_len);

/**
 * @brief Derive key from device root key and UUID of the current task by HUK2.
 * @attention If the device does not support HUK2, the key is derived by HUK.
 *
 * @param salt [IN] Indicates the data for salt.
 * @param size [IN] Indicates the length of salt.
 * @param key [OUT] Indicates the pointer where key is saved.
 * @param key_size [IN] Indicates the size of the generated key, fix-size 32 bytes.
 *
 * @return Returns {@code TEE_SUCCESS} if the operation is successful.
 *         Returns {@code TEE_ERROR_BAD_PARAMETERS} if input parameter is incorrect.
 *         Returns {@code TEE_ERROR_GENERIC} if the processing failed.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result tee_ext_root_uuid_derive_key_by_huk2(const uint8_t *salt, uint32_t size, uint8_t *key, uint32_t key_size);

#ifdef __cplusplus
}
#endif
/** @} */
#endif