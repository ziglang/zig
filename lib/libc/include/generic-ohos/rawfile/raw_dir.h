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
 * @file raw_dir.h
 *
 * @brief Declares native functions related to raw file directories.
 *
 * For example, you can use the functions to traverse and close a raw file directory, and reset its index.
 *
 * @since 8
 * @version 1.0
 */
#ifndef GLOBAL_RAW_DIR_H
#define GLOBAL_RAW_DIR_H

#ifdef __cplusplus
extern "C" {
#endif

struct RawDir;

/**
 * @brief Provides access to a raw file directory.
 *
 *
 *
 * @since 8
 * @version 1.0
 */
typedef struct RawDir RawDir;

/**
 * @brief Obtains the name of the file according to the index.
 *
 * You can use this method to traverse a raw file directory.
 *
 * @param rawDir Indicates the pointer to {@link RawDir}.
 * @param index Indicates the file index in {@link RawDir}.
 * @return Returns the name of the file according to the index,
 * which can be passed to {@link OH_ResourceManager_OpenRawFile} as an input parameter;
 * returns <b>NULL</b> if all files are returned.
 * @see OH_ResourceManager_OpenRawFile
 * @since 8
 * @version 1.0
 */
const char *OH_ResourceManager_GetRawFileName(RawDir *rawDir, int index);

/**
 * @brief get the count of the raw files in {@link RawDir}.
 *
 * You can use this method to get the valid index of {@link OH_ResourceManager_GetRawFileName}.
 *
 * @param rawDir Indicates the pointer to {@link RawDir}.
 * @see OH_ResourceManager_GetRawFileName
 * @since 8
 * @version 1.0
 */
int OH_ResourceManager_GetRawFileCount(RawDir *rawDir);

/**
 * @brief Closes an opened {@link RawDir} and releases all associated resources.
 *
 *
 *
 * @param rawDir Indicates the pointer to {@link RawDir}.
 * @see OH_ResourceManager_OpenRawDir
 * @since 8
 * @version 1.0
 */
void OH_ResourceManager_CloseRawDir(RawDir *rawDir);

#ifdef __cplusplus
};
#endif

/** @} */
#endif // GLOBAL_RAW_DIR_H