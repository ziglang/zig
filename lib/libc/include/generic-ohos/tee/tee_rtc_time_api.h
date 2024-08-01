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

#ifndef __TEE_RTC_TIME_API_H
#define __TEE_RTC_TIME_API_H

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
 * @file tee_rtc_time_api.h
 *
 * @brief Provides APIs about rtc timer.
 *
 * @library NA
 * @kit TEE Kit
 * @syscap SystemCapability.Tee.TeeClient
 * @since 12
 * @version 1.0
 */

#include <tee_defines.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Create a secure timer.
 *
 * @param time_seconds Indicates the security duration.
 * @param timer_property Indicates the property of the timer, where only need to specify the timer type.
 *
 * @return Returns <b>TEE_SUCCESS</b> if the operation is successful.
 * @return Returns other values if the operation fails.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result tee_ext_create_timer(uint32_t time_seconds, TEE_timer_property *timer_property);

/**
 * @brief Destory a secure timer.
 *
 * @param timer_property Indicates the property of the timer, where only need to specify the timer type.
 *
 * @return Returns <b>TEE_SUCCESS</b> if the operation is successful.
 * @return Returns other values if the operation fails.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result tee_ext_destory_timer(TEE_timer_property *timer_property);

/**
 * @brief Obtain the set timing duration.
 *
 * @param timer_property Indicates the property of the timer, where only need to specify the timer type.
 * @param time_seconds Indicates the timing duration.
 *
 * @return Returns <b>TEE_SUCCESS</b> if the operation is successful.
 * @return Returns other values if the operation fails.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result tee_ext_get_timer_expire(TEE_timer_property *timer_property, uint32_t *time_seconds);

/**
 * @brief Obtain the remain timing duration.
 *
 * @param timer_property Indicates the property of the timer, where only need to specify the timer type.
 * @param time_seconds Indicates the remain timing duration.
 *
 * @return Returns <b>TEE_SUCCESS</b> if the operation is successful.
 * @return Returns other values if the operation fails.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result tee_ext_get_timer_remain(TEE_timer_property *timer_property, uint32_t *time_seconds);

/**
 * @brief Obtain the current timing of the RTC clock.
 * @attention The obtained time is in seconds and cannot be converted to universal time.
 *
 * @return The RTC clock count(in seconds).
 *
 * @since 12
 * @version 1.0
 */
unsigned int tee_get_secure_rtc_time(void);
#ifdef __cplusplus
}
#endif
/** @} */
#endif