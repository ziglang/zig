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

#ifndef HIVIEWDFX_HIAPPEVENT_PARAM_H
#define HIVIEWDFX_HIAPPEVENT_PARAM_H

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
 * @file hiappevent_param.h
 *
 * @brief Defines the param names of all predefined events.
 *
 * In addition to custom events associated with specific apps, you can also use predefined events for logging.
 *
 * Sample code:
 * <pre>
 *     ParamList list = OH_HiAppEvent_CreateParamList();
 *     OH_HiAppEvent_AddInt32Param(list, PARAM_USER_ID, 123);
 *     int res = OH_HiAppEvent_Write("user_domain", EVENT_USER_LOGIN, BEHAVIOR, list);
 *     OH_HiAppEvent_DestroyParamList(list);
 * </pre>
 *
 * @since 8
 * @version 1.0
 */
#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Preset param name, user id param.
 *
 * @since 8
 * @version 1.0
 */
#define PARAM_USER_ID "user_id"

/**
 * @brief Preset param name, distributed service name param.
 *
 * @since 8
 * @version 1.0
 */
#define PARAM_DISTRIBUTED_SERVICE_NAME "ds_name"

/**
 * @brief Preset param name, distributed service instance id param.
 *
 * @since 8
 * @version 1.0
 */
#define PARAM_DISTRIBUTED_SERVICE_INSTANCE_ID "ds_instance_id"

#ifdef __cplusplus
}
#endif
/** @} */
#endif // HIVIEWDFX_HIAPPEVENT_PARAM_H