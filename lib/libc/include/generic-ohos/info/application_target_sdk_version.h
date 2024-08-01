/*
 * Copyright (c) 2022 Huawei Device Co., Ltd.
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

#ifndef _INFO_APPLICATION_TARGET_SDK_VERSION_H
#define _INFO_APPLICATION_TARGET_SDK_VERSION_H

#ifdef __cplusplus
extern "C" {
#endif

#define SDK_VERSION_FUTURE 9999
#define SDK_VERSION_7 7
#define SDK_VERSION_8 8
#define SDK_VERSION_9 9

/**
  * @brief Get the target sdk version number of the application.
  * @return The target sdk version number.
  */
int get_application_target_sdk_version(void);

/**
  * @brief Set the target sdk version number of the application.
  * @param target The target sdk version number.
  */
void set_application_target_sdk_version(int target);

#ifdef __cplusplus
}
#endif

#endif // _INFO_APPLICATION_TARGET_SDK_VERSION_H