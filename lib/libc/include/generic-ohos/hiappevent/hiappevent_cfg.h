/*
 * Copyright (c) 2021 Huawei Device Co., Ltd.
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

#ifndef HIVIEWDFX_HIAPPEVENT_CONFIG_H
#define HIVIEWDFX_HIAPPEVENT_CONFIG_H

/**
 * @addtogroup HiAppEvent
 * @{
 *
 * @brief Provides application event logging functions.
 *
 * Provides the event logging function for applications to log the fault, statistical, security, and user behavior
 * events reported during running. Based on event information, you will be able to analyze the running status of
 * applications.
 *
 * @syscap SystemCapability.HiviewDFX.HiAppEvent
 *
 * @since 8
 * @version 1.0
 */

/**
 * @file hiappevent_cfg.h
 *
 * @brief Defines the names of all the configuration items of the event logging configuration function.
 *
 * If you want to configure the event logging function, you can directly use the configuration item constants.
 *
 * Sample code:
 * <pre>
 *     bool res = OH_HiAppEvent_Configure(MAX_STORAGE, "100M");
 * </pre>
 *
 * @since 8
 * @version 1.0
 */

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Event logging switch.
 *
 * @since 8
 * @version 1.0
 */
#define DISABLE "disable"

/**
 * @brief Event file directory storage quota size.
 *
 * @since 8
 * @version 1.0
 */
#define MAX_STORAGE "max_storage"

#ifdef __cplusplus
}
#endif
/** @} */
#endif // HIVIEWDFX_HIAPPEVENT_CONFIG_H