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
#ifndef TEE_DRV_CLIENT_H
#define TEE_DRV_CLIENT_H

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
 * @file tee_drv_client.h
 *
 * @brief Declare tee driver client API.
 *
 * @library NA
 * @kit TEE Kit
 * @syscap SystemCapability.Tee.TeeClient
 * @since 12
 * @version 1.0
 */

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Open the specified driver in the TEE.
 *
 * @param drv_name [IN] The driver name.
 * @param param [IN] The parameter information.
 * @param param_len [IN] The length of the parameter.
 *
 * @return Returns greater than 0, which means the fd of the corresponding driver.
 *         Returns less than or equal to 0, which means falied to open the driver.
 *
 * @since 12
 * @version 1.0
 */
int64_t tee_drv_open(const char *drv_name, const void *param, uint32_t param_len);

/**
 * @brief Cancels an operation.
 *
 * @param fd [IN] The file descriptor of the driver.
 * @param cmd_id [IN] The command id.
 * @param param [IN] The parameter information.
 * @param param_len [IN] The length of the parameter.
 *
 * @return Returns <b>0</b> if the operation is successful.
 *         Returns <b>-1</b> if the operation is failed.
 *
 * @since 12
 * @version 1.0
 */
int64_t tee_drv_ioctl(int64_t fd, uint32_t cmd_id, const void *param, uint32_t param_len);

/**
 * @brief Open the specified driver in the TEE.
 *
 * @param fd [IN] The file descriptor of the driver.
 *
 * @return Returns <b>0</b> if the operation is successful.
 *         Returns <b>-1</b> if the operation is failed.
 *
 * @since 12
 * @version 1.0
 */
int64_t tee_drv_close(int64_t fd);

#ifdef __cplusplus
}
#endif
/** @} */
#endif