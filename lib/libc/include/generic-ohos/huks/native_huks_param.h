/*
 * Copyright (c) 2022-2024 Huawei Device Co., Ltd.
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

#ifndef NATIVE_HUKS_PARAM_H
#define NATIVE_HUKS_PARAM_H

/**
 * @addtogroup HuksParamSetApi
 * @{
 *
 * @brief Defines the capabilities of OpenHarmony Universal KeyStore (HUKS) parameter sets.
 *    The HUKS APIs can be used to perform parameter set lifecycle management,
 *    including initializing a parameter set, adding parameters to a parameter set, constructing
 *    a parameter set, and destroying a parameter set.
 *    They can also be used to obtain parameters, copy parameter sets, and check parameter validity.
 *
 * @syscap SystemCapability.Security.Huks
 * @since 9
 * @version 1.0
 */

/**
 * @file native_huks_param.h
 *
 * @brief Provides APIs for constructing, using, and destroying parameter sets.
 *
 * include "huks/include/native_huks_type.h"
 * @kit UniversalKeystoreKit
 * @since 9
 * @version 1.0
 */

#include "native_huks_type.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Initializes a parameter set.
 *
 * @param paramSet Indicates the double pointer to the parameter set to initialize.
 * @return {@link OH_Huks_ErrCode#OH_HUKS_SUCCESS} 0 - If the initialization is successful.
 *         {@link OH_Huks_ErrCode#OH_HUKS_ERR_CODE_INSUFFICIENT_MEMORY} 12000014 - If the memory is insufficient.
 *         {@link OH_Huks_ErrCode#OH_HUKS_ERR_CODE_ILLEGAL_ARGUMENT} 401 - If the paramset is null.
 * @since 9
 * @version 1.0
 */
struct OH_Huks_Result OH_Huks_InitParamSet(struct OH_Huks_ParamSet **paramSet);

/**
 * @brief Adds parameters to a parameter set.
 *
 * @param paramSet Indicates the pointer to the parameter set to which parameters are to be added.
 * @param params Indicates the pointer to the array of parameters to add.
 * @param paramCnt Indicates the number of parameters to add.
 * @return {@link OH_Huks_ErrCode#OH_HUKS_SUCCESS} 0 - If the operation is successful.
 *         {@link OH_Huks_ErrCode#OH_HUKS_ERR_CODE_ILLEGAL_ARGUMENT} 401 - If params is null or paramSet is invalid.
 * @since 9
 * @version 1.0
 */
struct OH_Huks_Result OH_Huks_AddParams(struct OH_Huks_ParamSet *paramSet,
    const struct OH_Huks_Param *params, uint32_t paramCnt);

/**
 * @brief Constructs a parameter set.
 *
 * @param paramSet Indicates the double pointer to the parameter set to construct.
 * @return {@link OH_Huks_ErrCode#OH_HUKS_SUCCESS} 0 - If the operation is successful.
 *         {@link OH_Huks_ErrCode#OH_HUKS_ERR_CODE_ILLEGAL_ARGUMENT} 401 - If paramSet is invalid.
 *         {@link OH_Huks_ErrCode#OH_HUKS_ERR_CODE_INSUFFICIENT_MEMORY} 12000014 - If the memory is insufficient.
 * @since 9
 * @version 1.0
 */
struct OH_Huks_Result OH_Huks_BuildParamSet(struct OH_Huks_ParamSet **paramSet);

/**
 * @brief Destroys a parameter set.
 *
 * @param paramSet Indicates the double pointer to the parameter set to destroy.
 * @since 9
 * @version 1.0
 */
void OH_Huks_FreeParamSet(struct OH_Huks_ParamSet **paramSet);

/**
 * @brief Copies a parameter set (deep copy).
 *
 * @param fromParamSet Indicates the pointer to the parameter set to copy.
 * @param fromParamSetSize Indicates the memory size occupied by the source parameter set.
 * @param paramSet Indicates the double pointer to the new parameter set generated.
 * @return {@link OH_Huks_ErrCode#OH_HUKS_SUCCESS} 0 - If the operation is successful.
 *         {@link OH_Huks_ErrCode#OH_HUKS_ERR_CODE_ILLEGAL_ARGUMENT} 401 - If fromParamSet or fromParamSetSize
 *             or paramSet is invalid.
 *         {@link OH_Huks_ErrCode#OH_HUKS_ERR_CODE_INSUFFICIENT_MEMORY} 12000014 - If the memory is insufficient.
 * @since 9
 * @version 1.0
 */
struct OH_Huks_Result OH_Huks_CopyParamSet(const struct OH_Huks_ParamSet *fromParamSet,
    uint32_t fromParamSetSize, struct OH_Huks_ParamSet **paramSet);

/**
 * @brief Obtains parameters from a parameter set.
 *
 * @param paramSet Indicates the pointer to the target parameter set.
 * @param tag Indicates the value of the parameter to be obtained.
 * @param param Indicates the double pointer to the parameter obtained.
 * @return {@link OH_Huks_ErrCode#OH_HUKS_SUCCESS} 0 - If the operation is successful,
 *         {@link OH_Huks_ErrCode#OH_HUKS_ERR_CODE_ILLEGAL_ARGUMENT} 401 - If paramSet or param is invalid,
 *             or if the param doesn't exist in the pararmset.
 * @since 9
 * @version 1.0
 */
struct OH_Huks_Result OH_Huks_GetParam(const struct OH_Huks_ParamSet *paramSet, uint32_t tag,
    struct OH_Huks_Param **param);

/**
 * @brief Refreshes data of the <b>Blob</b> type in a parameter set.
 *
 * @param paramSet Indicates the pointer to the target parameter set.
 * @param isCopy Specifies whether to copy the data of the <b>Blob</b> type to the parameter set.
 *    If yes, the data of the <b>Blob</b> type will be copied to the parameter set.
 *    Otherwise, only the address of the <b>Blob</b> data will be refreshed.
 * @return {@link OH_Huks_ErrCode#OH_HUKS_SUCCESS} 0 - If operation is successful.
 *         {@link OH_Huks_ErrCode#OH_HUKS_ERR_CODE_ILLEGAL_ARGUMENT} 401 - If paramSet is invalid.
 *         {@link OH_Huks_ErrCode#OH_HUKS_ERR_CODE_INSUFFICIENT_MEMORY} 12000014 - If the memory is insufficient.
 * @since 9
 * @version 1.0
 */
struct OH_Huks_Result OH_Huks_FreshParamSet(struct OH_Huks_ParamSet *paramSet, bool isCopy);

/**
 * @brief Checks whether the parameters in a parameter set are valid.
 *
 * @param paramSet Indicates the pointer to the parameter set to check.
 * @return {@link OH_Huks_ErrCode#OH_HUKS_SUCCESS} 0 - If the parameters in the parameter set are valid.
 *         {@link OH_Huks_ErrCode#OH_HUKS_ERR_CODE_ILLEGAL_ARGUMENT} 401 - If paramSet is invalid or
 *             the parameter set has invalid, duplicate, or incorrect tags.
 * @since 9
 * @version 1.0
 */
struct OH_Huks_Result OH_Huks_IsParamSetTagValid(const struct OH_Huks_ParamSet *paramSet);

/**
 * @brief Checks whether a parameter set is of the valid size.
 *
 * @param paramSet Indicates the pointer to the parameter set to check.
 * @param size Indicates the memory size occupied by the parameter set.
 * @return {@link OH_Huks_ErrCode#OH_HUKS_SUCCESS} 0 - If the parameter set is of the valid size.
 *         {@link OH_Huks_ErrCode#OH_HUKS_ERR_CODE_ILLEGAL_ARGUMENT} 401 - If paramSet is invalid.
 * @since 9
 * @version 1.0
 */
struct OH_Huks_Result OH_Huks_IsParamSetValid(const struct OH_Huks_ParamSet *paramSet, uint32_t size);

/**
 * @brief Checks whether two parameters are the same.
 *
 * @param baseParam Indicates the pointer to the first parameter.
 * @param param Indicates the pointer to the second parameter.
 * @return {@link OH_Huks_ErrCode#OH_HUKS_SUCCESS} 0 - If the two parameters are the same.
 *         {@link OH_Huks_ErrCode#OH_HUKS_ERR_CODE_ILLEGAL_ARGUMENT} 401 - If one of the paramSet is invalid,
 *             or if the params don't match, or if the tag inside is invalid.
 * @since 9
 * @version 1.0
 */
struct OH_Huks_Result OH_Huks_CheckParamMatch(const struct OH_Huks_Param *baseParam, const struct OH_Huks_Param *param);

#ifdef __cplusplus
}
#endif

/** @} */
#endif /* NATIVE_HUKS_PARAM_H */