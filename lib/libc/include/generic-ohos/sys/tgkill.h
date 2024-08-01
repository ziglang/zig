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

#ifndef _SYS_TGKILL_H
#define _SYS_TGKILL_H
#ifdef __cplusplus
extern "C"
{
#endif
/** 
  * @brief send any signal to any process group or process.
  * @param tgid the group ID of the calling process.
  * @param tid the thread ID of the calling process.
  * @param sig the actual signal.
  * @return tgkill result.
  * @retval 0 is returned on success.
  * @retval -1 is returned on failure, and errno is set to indicate the error.
  */
int tgkill(int tgid, int tid, int sig);

#ifdef __cplusplus
}
#endif
#endif