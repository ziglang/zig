/*
* Copyright (c) 2023 Huawei Device Co., Ltd.
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

#ifndef OH_VALUE_OBJECT_H
#define OH_VALUE_OBJECT_H

/**
 * @addtogroup RDB
 * @{
 *
 * @brief The relational database (RDB) store manages data based on relational models.
 * With the underlying SQLite database, the RDB store provides a complete mechanism for managing local databases.
 * To satisfy different needs in complicated scenarios, the RDB store offers a series of APIs for performing operations
 * such as adding, deleting, modifying, and querying data, and supports direct execution of SQL statements.
 *
 * @syscap SystemCapability.DistributedDataManager.RelationalStore.Core
 * @since 10
 */

/**
 * @file oh_value_object.h
 *
 * @brief Provides numeric type conversion functions.
 *
 * @since 10
 */

#include <cstdint>
#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Define the OH_VObject structure type.
 *
 * @since 10
 */
typedef struct OH_VObject {
    /**
     * The id used to uniquely identify the OH_VObject struct.
     */
    int64_t id;

    /**
     * @brief Convert the int64 input parameter to a value of type {@link OH_VObject}.
     *
     * @param valueObject Represents a pointer to an {@link OH_VObject} instance.
     * @param value Represents a pointer to an int64_t input parameter or the array of type int64_t.
     * @param count If value is a pointer to a single numerical value, count = 1;
     * if value is a pointer to an array, count is the size of the array.
     * @return Returns the status code of the execution.
     * @see OH_VObject.
     * @since 10
     */
    int (*putInt64)(OH_VObject *valueObject, int64_t *value, uint32_t count);

    /**
     * @brief Convert the double input parameter to a value of type {@link OH_VObject}.
     *
     * @param valueObject Represents a pointer to an {@link OH_VObject} instance.
     * @param value Represents a pointer to an double input parameter or the array of type double.
     * @param count If value is a pointer to a single numerical value, count = 1;
     * if value is a pointer to an array, count is the size of the array.
     * @return Returns the status code of the execution.
     * @see OH_VObject.
     * @since 10
     */
    int (*putDouble)(OH_VObject *valueObject, double *value, uint32_t count);

    /**
     * @brief Convert the char input parameter to a value of type {@link OH_VObject}.
     *
     * @param valueObject Represents a pointer to an {@link OH_VObject} instance.
     * @param value Indicates the const char * input parameter.
     * @return Returns the status code of the execution.
     * @see OH_VObject.
     * @since 10
     */
    int (*putText)(OH_VObject *valueObject, const char *value);

    /**
     * @brief Convert the char * array input parameter to a value of type {@link OH_VObject}.
     *
     * @param valueObject Represents a pointer to an {@link OH_VObject} instance.
     * @param value Indicates the const char * array input parameter.
     * @param count Indicates the size of the value.
     * @return Returns the status code of the execution.
     * @see OH_VObject.
     * @since 10
     */
    int (*putTexts)(OH_VObject *valueObject, const char **value, uint32_t count);

    /**
     * @brief Destroy the {@link OH_VObject} object and reclaim the memory occupied by the object.
     *
     * @param valueObject Represents a pointer to an {@link OH_VObject} instance.
     * @return Returns the status code of the execution.
     * @see OH_VObject.
     * @since 10
     */
    int (*destroy)(OH_VObject *valueObject);
} OH_VObject;

#ifdef __cplusplus
};
#endif

#endif // OH_VALUE_OBJECT_H