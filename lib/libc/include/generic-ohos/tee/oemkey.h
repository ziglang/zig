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

#ifndef OEMKEY_H
#define OEMKEY_H
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
 * @file oemkey.h
 *
 * @brief Provides the method for obtaining the hardware provision key.
 *
 * @library NA
 * @kit TEE Kit
 * @syscap SystemCapability.Tee.TeeClient
 * @since 12
 * @version 1.0
 */

#include <stdint.h>
#include <stdlib.h>

#ifdef __cplusplus
extern "C" {
#endif
/**
 * @brief Obtains the provision key.
 *
 * @param oem_key Indicates the pointer to the buffer for storing the provision key.
 * @param key_size Indicates the length of the buffer used to store the provision key, which is 16.
 *
 * @return Returns <b>0</b> if the operation is successful.
 * @return Returns other values otherwise.
 *
 * @since 12
 */
uint32_t tee_hal_get_provision_key(uint8_t *oem_key, size_t key_size);

#ifdef __cplusplus
}
#endif

/** @} */
#endif