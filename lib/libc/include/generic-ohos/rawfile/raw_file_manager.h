/*
 * Copyright (c) 2022-2023 Huawei Device Co., Ltd.
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
 * @addtogroup rawfile
 * @{
 *
 * @brief Provides native functions for the resource manager to operate raw file directories and their raw files.
 *
 * You can use the resource manager to traverse, open, seek, read, and close raw files.
 *
 * @since 8
 * @version 1.0
 */

/**
 * @file raw_file_manager.h
 *
 * @brief Declares native functions for the resource manager.
 *
 * You can use the resource manager to open raw files for subsequent operations, such as seeking and reading.
 *
 * @since 8
 * @version 1.0
 */
#ifndef GLOBAL_NATIVE_RESOURCE_MANAGER_H
#define GLOBAL_NATIVE_RESOURCE_MANAGER_H

#include "napi/native_api.h"
#include "raw_dir.h"
#include "raw_file.h"

#ifdef __cplusplus
extern "C" {
#endif

struct NativeResourceManager;

/**
 * @brief Presents the resource manager.
 *
 * This class encapsulates the native implementation of the JavaScript resource manager. The pointer to a
 * <b>ResourceManager</b> object can be obtained by calling {@link OH_ResourceManager_InitNativeResourceManager}.
 *
 * @since 8
 * @version 1.0
 */
typedef struct NativeResourceManager NativeResourceManager;

/**
 * @brief Obtains the native resource manager based on the JavaScipt resource manager.
 *
 * You need to obtain the resource manager to process raw files as required.
 *
 * @param env Indicates the pointer to the JavaScipt Native Interface (napi) environment.
 * @param jsResMgr Indicates the JavaScipt resource manager.
 * @return Returns the pointer to {@link NativeResourceManager}. If failed returns nullptr.
 * @since 8
 * @version 1.0
 */
NativeResourceManager *OH_ResourceManager_InitNativeResourceManager(napi_env env, napi_value jsResMgr);

/**
 * @brief Releases the native resource manager.
 *
 *
 *
 * @param resMgr Indicates the pointer to {@link RawDir}.
 * @since 8
 * @version 1.0
 */
void OH_ResourceManager_ReleaseNativeResourceManager(NativeResourceManager *resMgr);

/**
 * @brief Opens a raw file directory.
 *
 * After it is opened, you can traverse its raw files.
 *
 * @param mgr Indicates the pointer to {@link NativeResourceManager} obtained by calling
 * {@link OH_ResourceManager_InitNativeResourceManager}.
 * @param dirName Indicates the name of the raw file directory to open. You can pass an empty string to open the
 * top-level raw file directory.
 * @return Returns the pointer to {@link RawDir}. If failed or mgr is nullptr also returns nullptr.
 *         After you finish using the pointer, call {@link OH_ResourceManager_CloseRawDir} to release it.
 * @see OH_ResourceManager_InitNativeResourceManager
 * @see OH_ResourceManager_CloseRawDir
 * @since 8
 * @version 1.0
 */
RawDir *OH_ResourceManager_OpenRawDir(const NativeResourceManager *mgr, const char *dirName);

/**
 * @brief Opens a raw file.
 *
 * After it is opened, you can read its data.
 *
 * @param mgr Indicates the pointer to {@link NativeResourceManager} obtained by calling
 * {@link OH_ResourceManager_InitNativeResourceManager}.
 * @param fileName Indicates the file path relative to the top-level raw file directory.
 * @return Returns the pointer to {@link RawFile}. If failed or mgr and fileName is nullptr also returns nullptr.
 * After you finish using the pointer, call {@link OH_ResourceManager_CloseRawFile} to release it.
 * @see OH_ResourceManager_InitNativeResourceManager
 * @see OH_ResourceManager_CloseRawFile
 * @since 8
 * @version 1.0
 */
RawFile *OH_ResourceManager_OpenRawFile(const NativeResourceManager *mgr, const char *fileName);

/**
 * @brief Opens a raw file.
 *
 * After it is opened, you can read its data.
 *
 * @param mgr Indicates the pointer to {@link NativeResourceManager} obtained by calling
 * {@link OH_ResourceManager_InitNativeResourceManager}.
 * @param fileName Indicates the file path relative to the top-level raw file directory.
 * @return Returns the pointer to {@link RawFile64}. If failed or mgr and fileName is nullptr also returns nullptr.
 * After you finish using the pointer, call {@link OH_ResourceManager_CloseRawFile64} to release it.
 * @see OH_ResourceManager_InitNativeResourceManager
 * @see OH_ResourceManager_CloseRawFile64
 * @since 11
 * @version 1.0
 */
RawFile64 *OH_ResourceManager_OpenRawFile64(const NativeResourceManager *mgr, const char *fileName);

/**
 * @brief Whether the rawfile resource is a directory or not.
 *
 * @param mgr Indicates the pointer to {@link NativeResourceManager} obtained by calling
 * {@link OH_ResourceManager_InitNativeResourceManager}.
 * @param path Indicates the rawfile resource relative path.
 * @return Returns true means the file path is directory, else false.
 * @since 12
 * @version 1.0
 */
bool OH_ResourceManager_IsRawDir(const NativeResourceManager *mgr, const char *path);

#ifdef __cplusplus
};
#endif

/** @} */
#endif // GLOBAL_NATIVE_RESOURCE_MANAGER_H