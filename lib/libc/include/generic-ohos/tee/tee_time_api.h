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

#ifndef __TEE_TIME_API_H
#define __TEE_TIME_API_H

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
 * @file tee_time_api.h
 *
 * @brief Provides APIs for managing the Trusted Execution Environment (TEE) time.
 *
 * You can use these APIs to implement time-related features in a TEE.
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
 * @brief Obtains the current TEE system time.
 *
 * @param time Indicates the pointer to the current system time obtained.
 *
 * @since 12
 * @version 1.0
 */
void TEE_GetSystemTime(TEE_Time *time);

/**
 * @brief Waits for the specified period of time, in milliseconds.
 *
 * @param timeout Indicates the period of time to wait, in milliseconds.
 *
 * @return Returns <b>TEE_SUCCESS</b> if the operation is successful.
 * @return Returns <b>TEE_ERROR_CANCEL</b> if the wait is canceled.
 * @return Returns <b>TEE_ERROR_OUT_OF_MEMORY</b> if the memory is not sufficient to complete the operation.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_Wait(uint32_t timeout);

/**
 * @brief Obtains the persistent time of this trusted application (TA).
 *
 * @param time Indicates the pointer to the persistent time of the TA.
 *
 * @return Returns <b>TEE_SUCCESS</b> if the operation is successful.
 * @return Returns <b>TEE_ERROR_TIME_NOT_SET</b> if the persistent time has not been set.
 * @return Returns <b>TEE_ERROR_TIME_NEEDS_RESET</b> if the persistent time is corrupted and
 * the application is not longer trusted.
 * @return Returns <b>TEE_ERROR_OVERFLOW</b> if the number of seconds in the TA persistent time
 * exceeds the range of <b>uint32_t</b>.
 * @return Returns <b>TEE_ERROR_OUT_OF_MEMORY</b> if the memory is not sufficient to complete the operation.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_GetTAPersistentTime(TEE_Time *time);

/**
 * @brief Sets the persistent time for this TA.
 *
 * @param time Indicates the pointer to the persistent time of the TA.
 *
 * @return Returns <b>TEE_SUCCESS</b> if the operation is successful.
 * @return Returns <b>TEE_ERROR_OUT_OF_MEMORY</b> if the memory is not sufficient to complete the operation.
 * @return Returns <b>TEE_ERROR_STORAGE_NO_SPACE</b> if the storage space is not sufficient to complete the operation.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_SetTAPersistentTime(TEE_Time *time);

/**
 * @brief Obtains the current Rich Execution Environment (REE) system time.
 *
 * @param time Indicates the pointer to the REE system time obtained.
 *
 * @since 12
 * @version 1.0
 */
void TEE_GetREETime(TEE_Time *time);

/**
 * @brief Obtains the string format of the current Rich Execution Environment (REE) system time.
 *
 * @param tim_str Indicates the REE system time string.
 * @param time_str_len Indicates the length of the string.
 *
 * @since 12
 * @version 1.0
 */
void TEE_GetREETimeStr(char *tim_str, uint32_t time_str_len);

#ifdef __cplusplus
}
#endif
/** @} */
#endif