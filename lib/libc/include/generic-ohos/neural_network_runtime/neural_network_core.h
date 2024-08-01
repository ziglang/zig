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
 * @addtogroup NeuralNeworkRuntime
 * @{
 *
 * @brief Provides APIs of Neural Network Runtime for accelerating the model inference.
 *
 * @since 9
 * @version 2.0
 */

/**
 * @file neural_network_core.h
 *
 * @brief Defines the Neural Network Core APIs. The AI inference framework uses the Native APIs provided by
 *        Neural Network Core to compile models and perform inference and computing on acceleration hardware.
 *
 * Note: Currently, the APIs of Neural Network Core do not support multi-thread calling. \n
 *
 * include "neural_network_runtime/neural_network_core.h"
 * @library libneural_network_core.so
 * @kit Neural Network Runtime Kit
 * @syscap SystemCapability.Ai.NeuralNetworkRuntime
 * @since 11
 * @version 1.0
 */

#ifndef NEURAL_NETWORK_CORE_H
#define NEURAL_NETWORK_CORE_H

#include "neural_network_runtime_type.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Creates a compilation instance of the {@link OH_NNCompilation} type.
 *
 * After the OH_NNModel module completes model construction, APIs provided by the OH_NNCompilation module pass the
 * model to underlying device for compilation. This method creates a {@link OH_NNCompilation} instance
 * based on the passed {@link OH_NNModel} instance. The {@link OH_NNCompilation_SetDevice} method is called
 * to set the device to compile on, and {@link OH_NNCompilation_Build} is then called to complete compilation.\n
 *
 * In addition to computing device selection, the OH_NNCompilation module supports features such as model caching,
 * performance preference, priority setting, and float16 computing, which can be implemented by the following methods:\n
 * {@link OH_NNCompilation_SetCache}\n
 * {@link OH_NNCompilation_SetPerformanceMode}\n
 * {@link OH_NNCompilation_SetPriority}\n
 * {@link OH_NNCompilation_EnableFloat16}\n
 *
 * After {@link OH_NNCompilation_Build} is called, the {@link OH_NNModel} instance can be released.\n
 *
 * @param model Pointer to the {@link OH_NNModel} instance.
 * @return Pointer to a {@link OH_NNCompilation} instance, or NULL if it fails to create. The possible reason for
 *         failure is that the parameters of model are invalid or there is a problem with the model format.
 * @since 9
 * @version 1.0
 */
OH_NNCompilation *OH_NNCompilation_Construct(const OH_NNModel *model);

/**
 * @brief Creates a compilation instance based on an offline model file.
 *
 * This method conflicts with the way of passing an online built model or an offline model file buffer,
 * and you have to choose only one of the three construction methods. \n
 * 
 * Offline model is a type of model that is offline compiled by the model converter provided by a device vendor. 
 * So that the offline model can only be used on the specified device, but the compilation time of offline model is usually 
 * much less than {@link OH_NNModel}. \n 
 * 
 * You should perform the offline compilation during your development and deploy the offline model in your app package. \n
 * 
 * @param modelPath Offline model file path.
 * @return Pointer to an {@link OH_NNCompilation} instance, or NULL if it fails to create. The possible reason for
 *         failure is that the modelPath is invalid.
 * @since 11
 * @version 1.0
 */
OH_NNCompilation *OH_NNCompilation_ConstructWithOfflineModelFile(const char *modelPath);

/**
 * @brief Creates a compilation instance based on an offline model file buffer.
 *
 * This method conflicts with the way of passing an online built model or an offline model file path, 
 * and you have to choose only one of the three construction methods. \n
 * 
 * Note that the returned {@link OH_NNCompilation} instance only saves the <b>modelBuffer</b> pointer inside, instead of 
 * copying its data. You should not release <b>modelBuffer</b> before the {@link OH_NNCompilation} instance is destroied. \n
 *
 * @param modelBuffer Offline model file buffer.
 * @param modelSize Offfline model buffer size.
 * @return Pointer to an {@link OH_NNCompilation} instance, or NULL if it fails to create. The possible reason for
 *         failure is that the modelBuffer or modelSize is invalid.
 * @since 11
 * @version 1.0
 */
OH_NNCompilation *OH_NNCompilation_ConstructWithOfflineModelBuffer(const void *modelBuffer, size_t modelSize);

/**
 * @brief Creates a empty compilation instance for restoration from cache later.
 *
 * See {@link OH_NNCompilation_SetCache} for the description of cache.\n
 *
 * The restoration time from the cache is less than compilation with {@link OH_NNModel}.\n
 * 
 * You should call {@link OH_NNCompilation_SetCache} or {@link OH_NNCompilation_ImportCacheFromBuffer} first,
 * and then call {@link OH_NNCompilation_Build} to complete the restoration.\n
 *
 * @return Pointer to an {@link OH_NNCompilation} instance, or NULL if it fails to create. The possible reason for
 *         failure is that the cache file saved before is invalid.
 * @since 11
 * @version 1.0
 */
OH_NNCompilation *OH_NNCompilation_ConstructForCache();

/**
 * @brief Exports the cache to a given buffer.
 *
 * See {@link OH_NNCompilation_SetCache} for the description of cache.\n
 *
 * Note that the cache is the result of compilation building {@link OH_NNCompilation_Build},
 * so that this method must be called after {@link OH_NNCompilation_Build}.\n
 *
 * @param compilation Pointer to the {@link OH_NNCompilation} instance.
 * @param buffer Pointer to the given buffer.
 * @param length Buffer length.
 * @param modelSize Byte size of the model cache.
 * @return Execution result of the function.
 *         {@link OH_NN_SUCCESS} export cache to buffer successfully.\n
 *         {@link OH_NN_INVALID_PARAMETER} fail to export cache to buffer. The possible reason for failure
 *         is that the <b>compilation</b>, <b>buffer</b> or <b>modelSize</b> is nullptr, or <b>length</b> is 0,
 *         or <b>compilation</b> is invalid.\n
 *         {@link OH_NN_UNSUPPORTED} exporting cache to buffer is unsupported.\n
 * @since 11
 * @version 1.0
 */
OH_NN_ReturnCode OH_NNCompilation_ExportCacheToBuffer(OH_NNCompilation *compilation,
                                                      const void *buffer,
                                                      size_t length,
                                                      size_t *modelSize);

/**
 * @brief Imports the cache from a given buffer.
 *
 * See {@link OH_NNCompilation_SetCache} for the description of cache.\n
 *
 * {@link OH_NNCompilation_Build} should be called to complete the restoration after
 * {@link OH_NNCompilation_ImportCacheFromBuffer} is called.\n
 *
 * Note that <b>compilation</b> only saves the <b>buffer</b> pointer inside, instead of copying its data. You should not
 * release <b>buffer</b> before <b>compilation</b> is destroied.\n
 *
 * @param compilation Pointer to the {@link OH_NNCompilation} instance.
 * @param buffer Pointer to the given buffer.
 * @param modelSize Byte size of the model cache.
 * @return Execution result of the function.
 *         {@link OH_NN_SUCCESS} import cache from buffer successfully.\n
 *         {@link OH_NN_INVALID_PARAMETER} fail to import cache from buffer. The possible reason for failure is that
 *         the <b>compilation</b> or <b>buffer</b> is nullptr, or <b>modelSize</b> is 0, or content of <b>buffer</b>
 *         is invalid.\n
 * @since 11
 * @version 1.0
 */
OH_NN_ReturnCode OH_NNCompilation_ImportCacheFromBuffer(OH_NNCompilation *compilation,
                                                        const void *buffer,
                                                        size_t modelSize);

/**
 * @brief Adds an extension config for a custom hardware attribute.
 *
 * Some devices have their own specific attributes which have not been opened in NNRt. This method provides an additional way for you 
 * to set these custom hardware attributes of the device. You should query their names and values from the device 
 * vendor's documents, and add them into compilation instance one by one. These attributes will be passed directly to device 
 * driver, and this method will return error code if the driver cannot parse them. \n
 * 
 * After {@link OH_NNCompilation_Build} is called, the <b>configName</b> and <b>configValue</b> can be released. \n
 *
 * @param compilation Pointer to the {@link OH_NNCompilation} instance.
 * @param configName Config name.
 * @param configValue A byte buffer saving the config value.
 * @param configValueSize Byte size of the config value.
 * @return Execution result of the function.
 *         {@link OH_NN_SUCCESS} add extension config successfully.\n
 *         {@link OH_NN_INVALID_PARAMETER} fail to add extension config. The possible reason for failure is that the
 *         <b>compilation</b>, <b>configName</b> or <b>configValue</b> is nullptr, or <b>configValueSize</b> is 0.\n
 *         {@link OH_NN_FAILED} other failures, such as memory error during object creation.\n
 * @since 11
 * @version 1.0
 */
OH_NN_ReturnCode OH_NNCompilation_AddExtensionConfig(OH_NNCompilation *compilation,
                                                     const char *configName,
                                                     const void *configValue,
                                                     const size_t configValueSize);

/**
 * @brief Specifies the device for model compilation and computing.
 *
 * In the compilation phase, you need to specify the device for model compilation and computing. Call {@link OH_NNDevice_GetAllDevicesID} 
 * to obtain available device IDs. Call {@link OH_NNDevice_GetType} and {@link OH_NNDevice_GetName} to obtain device information 
 * and pass target device ID to this method for setting. \n
 *
 * 
 * @param compilation Pointer to the {@link OH_NNCompilation} instance.
 * @param deviceID Device id. If it is 0, the first device in the current device list will be used by default.
 * @return Execution result of the function.
 *         {@link OH_NN_SUCCESS} set device successfully.\n
 *         {@link OH_NN_INVALID_PARAMETER} fail to set device. The possible reason for failure
 *         is that the <b>compilation</b> is nullptr.\n
 * @since 9
 * @version 1.0
 */
OH_NN_ReturnCode OH_NNCompilation_SetDevice(OH_NNCompilation *compilation, size_t deviceID);

/**
 * @brief Set the cache directory and version of the compiled model.
 *
 * On the device that supports caching, a model can be saved as a cache file after being compiled on the device driver. 
 * The model can be directly read from the cache file in the next compilation, saving recompilation time. 
 * This method performs different operations based on the passed cache directory and version: \n
 *
 * - No file exists in the cache directory:
 * Caches the compiled model to the directory and sets the cache version to <b>version</b>. \n
 *
 * - A complete cache file exists in the cache directory, and its version is <b>version</b>:
 * Reads the cache file in the path and passes the data to the underlying device for conversion into executable model instances. \n
 *
 * - A complete cache file exists in the cache directory, and its version is earlier than <b>version</b>:
 * When model compilation is complete on the underlying device, overwrites the cache file and changes the version number to <b>version</b>. \n
 *
 * - A complete cache file exists in the cache directory, and its version is later than <b>version</b>:
 * Returns the {@link OH_NN_INVALID_PARAMETER} error code without reading the cache file. \n
 *
 * - The cache file in the cache directory is incomplete or you do not have the permission to access the cache file.
 * Returns the {@link OH_NN_INVALID_FILE} error code. \n
 *
 * - The cache directory does not exist or you do not have the access permission.
 * Returns the {@link OH_NN_INVALID_PATH} error code. \n
 *
 * @param compilation Pointer to the {@link OH_NNCompilation} instance.
 * @param cachePath Directory for storing model cache files. This method creates directories for different devices in the <b>cachePath</b> directory. 
 *                  You are advised to use a separate cache directory for each model.
 * @param version Cache version.
 * @return Execution result of the function.
 *         {@link OH_NN_SUCCESS} set cache path and version successfully.\n
 *         {@link OH_NN_INVALID_PARAMETER} fail to set cache path and version. The possible reason for failure
 *         is that the <b>compilation</b> or <b>cachePath</b> is nullptr.\n
 * @since 9
 * @version 1.0
 */
OH_NN_ReturnCode OH_NNCompilation_SetCache(OH_NNCompilation *compilation, const char *cachePath, uint32_t version);

/**
 * @brief Sets the performance mode for model computing.
 *
 * Allows you to set the performance mode for model computing to meet the requirements of low power consumption 
 * and ultimate performance. If this method is not called to set the performance mode in the compilation phase, the compilation instance assigns 
 * the {@link OH_NN_PERFORMANCE_NONE} mode for the model by default. In this case, the device performs computing in the default performance mode. \n
 *
 * If this method is called on the device that does not support the setting of the performance mode, the {@link OH_NN_UNAVALIDABLE_DEVICE} error code is returned. \n
 *
 * @param compilation Pointer to the {@link OH_NNCompilation} instance.
 * @param performanceMode Performance mode. For details about the available performance modes, see {@link OH_NN_PerformanceMode}. 
 * @return Execution result of the function.
 *         {@link OH_NN_SUCCESS} set performance mode successfully.\n
 *         {@link OH_NN_INVALID_PARAMETER} fail to set performance mode. The possible reason for failure
 *         is that the <b>compilation</b> is nullptr, or <b>performanceMode</b> is invalid.\n
 *         {@link OH_NN_FAILED} fail to query whether the backend device supports setting performance mode.\n
 *         {@link OH_NN_OPERATION_FORBIDDEN} the backend device is not supported to set performance mode.\n
 * @since 9
 * @version 1.0
 */
OH_NN_ReturnCode OH_NNCompilation_SetPerformanceMode(OH_NNCompilation *compilation,
                                                     OH_NN_PerformanceMode performanceMode);

/**
 * @brief Sets the model computing priority.
 *
 * Allows you to set computing priorities for models.  
 * The priorities apply only to models created by the process with the same UID. 
 * The settings will not affect models created by processes with different UIDs on different devices. \n
 *
 * If this method is called on the device that does not support the priority setting, the {@link OH_NN_UNAVALIDABLE_DEVICE} error code is returned. \n
 *
 * @param compilation Pointer to the {@link OH_NNCompilation} instance.
 * @param priority Priority. For details about the optional priorities, see {@link OH_NN_Priority}.
 * @return Execution result of the function.
 *         {@link OH_NN_SUCCESS} set priority successfully.\n
 *         {@link OH_NN_INVALID_PARAMETER} fail to set priority. The possible reason for failure
 *         is that the <b>compilation</b> is nullptr, or <b>priority</b> is invalid.\n
 *         {@link OH_NN_FAILED} fail to query whether the backend device supports setting priority.\n
 *         {@link OH_NN_OPERATION_FORBIDDEN} the backend device is not supported to set priority.\n
 * @since 9
 * @version 1.0
 */
OH_NN_ReturnCode OH_NNCompilation_SetPriority(OH_NNCompilation *compilation, OH_NN_Priority priority);

/**
 * @brief Enables float16 for computing.
 *
 * Float32 is used by default for the model of float type. If this method is called on a device that supports float16, 
 * float16 will be used for computing the float32 model to reduce memory usage and execution time. \n
 * 
 * This option is useless for the model of int type, e.g. int8 type. \n
 *
 * If this method is called on the device that does not support float16, the {@link OH_NN_UNAVALIDABLE_DEVICE} error code is returned. \n
 *
 * @param compilation Pointer to the {@link OH_NNCompilation} instance.
 * @param enableFloat16 Indicates whether to enable float16. If this parameter is set to <b>true</b>, float16 inference is performed. 
 *                      If this parameter is set to <b>false</b>, float32 inference is performed.
 * @return Execution result of the function.
 *         {@link OH_NN_SUCCESS} enable fp16 successfully.\n
 *         {@link OH_NN_INVALID_PARAMETER} fail to enable fp16. The possible reason for failure
 *         is that the <b>compilation</b> is nullptr.\n
 * @since 9
 * @version 1.0
 */
OH_NN_ReturnCode OH_NNCompilation_EnableFloat16(OH_NNCompilation *compilation, bool enableFloat16);

/**
 * @brief Compiles a model.
 *
 * After the compilation configuration is complete, call this method to return the compilation result. The compilation instance pushes the model and
 * compilation options to the device for compilation. After this method is called, additional compilation operations cannot be performed. \n
 * 
 * If the {@link OH_NNCompilation_SetDevice}, {@link OH_NNCompilation_SetCache}, {@link OH_NNCompilation_SetPerformanceMode}, 
 * {@link OH_NNCompilation_SetPriority}, and {@link OH_NNCompilation_EnableFloat16} methods are called, {@link OH_NN_OPERATION_FORBIDDEN} is returned. \n
 *
 * @param compilation Pointer to the {@link OH_NNCompilation} instance.
 * @return Execution result of the function.
 *         {@link OH_NN_SUCCESS} build model successfully.\n
 *         {@link OH_NN_INVALID_PARAMETER} fail to build model. The possible reason for failure
 *         is that the <b>compilation</b> is nullptr, or the parameters set before is invalid.\n
 *         {@link OH_NN_FAILED} fail to build model.\n
 *         {@link OH_NN_OPERATION_FORBIDDEN} the backend device is not supported the model.\n
 * @since 9
 * @version 1.0
 */
OH_NN_ReturnCode OH_NNCompilation_Build(OH_NNCompilation *compilation);

/**
 * @brief Releases the <b>Compilation</b> object.
 *
 * This method needs to be called to release the compilation instance created by {@link OH_NNCompilation_Construct}, 
 * {@link OH_NNCompilation_ConstructWithOfflineModelFile}, {@link OH_NNCompilation_ConstructWithOfflineModelBuffer} and 
 * {@link OH_NNCompilation_ConstructForCache}. Otherwise, the memory leak will occur. \n
 *
 * If <b>compilation</b> or <b>*compilation</b> is a null pointer, this method only prints warning logs and does not execute the release. \n
 *
 * @param compilation Double pointer to the {@link OH_NNCompilation} instance. After a compilation instance is destroyed, 
 *                    this method sets <b>*compilation</b> to a null pointer.
 * @since 9
 * @version 1.0
 */
void OH_NNCompilation_Destroy(OH_NNCompilation **compilation);


/**
 * @brief Creates an {@link NN_TensorDesc} instance.
 *
 * The {@link NN_TensorDesc} describes various tensor attributes, such as name/data type/shape/format, etc.\n
 *
 * The following methods can be called to create a {@link NN_Tensor} instance based on the passed {@link NN_TensorDesc}
 * instance:\n
 * {@link OH_NNTensor_Create}\n
 * {@link OH_NNTensor_CreateWithSize}\n
 * {@link OH_NNTensor_CreateWithFd}\n
 *
 * Note that these methods will copy the {@link NN_TensorDesc} instance into {@link NN_Tensor}. Therefore you can create
 * multiple {@link NN_Tensor} instances with the same {@link NN_TensorDesc} instance. And you should destroy the
 * {@link NN_TensorDesc} instance by {@link OH_NNTensorDesc_Destroy} when it is no longer used.\n
 *
 * @return Pointer to a {@link NN_TensorDesc} instance, or NULL if it fails to create. The possible reason for failure
 *         is that the memory error occurred during object creation.
 * @since 11
 * @version 1.0
 */
NN_TensorDesc *OH_NNTensorDesc_Create();

/**
 * @brief Releases an {@link NN_TensorDesc} instance.
 *
 * When the {@link NN_TensorDesc} instance is no longer used, this method needs to be called to release it. Otherwise, 
 * the memory leak will occur. \n
 * 
 * If <b>tensorDesc</b> or <b>*tensorDesc</b> is a null pointer, this method will return error code and does not execute the release. \n
 *
 * @param tensorDesc Double pointer to the {@link NN_TensorDesc} instance.
 * @return Execution result of the function.
 *         {@link OH_NN_SUCCESS} destroy tensor description successfully.\n
 *         {@link OH_NN_INVALID_PARAMETER} fail to destroy tensor description. The possible reason for failure
 *         is that the <b>tensorDesc</b> or <b>*tensorDesc</b> is nullptr.\n
 * @since 11
 * @version 1.0
 */
OH_NN_ReturnCode OH_NNTensorDesc_Destroy(NN_TensorDesc **tensorDesc);

/**
 * @brief Sets the name of a {@link NN_TensorDesc}.
 *
 * After the {@link NN_TensorDesc} instance is created, call this method to set the tensor name.
 * The value of <b>*name</b> is a C-style string ended with <b>'\0'</b>.\n
 *
 * if <b>tensorDesc</b> or <b>name</b> is a null pointer, this method will return error code.\n
 *
 * @param tensorDesc Pointer to the {@link NN_TensorDesc} instance.
 * @param name The name of the tensor that needs to be set.
 * @return Execution result of the function.
 *         {@link OH_NN_SUCCESS} set tensor name successfully.\n
 *         {@link OH_NN_INVALID_PARAMETER} fail to set tensor name. The possible reason for failure
 *         is that the <b>tensorDesc</b> or <b>name</b> is nullptr.\n
 * @since 11
 * @version 1.0
 */
OH_NN_ReturnCode OH_NNTensorDesc_SetName(NN_TensorDesc *tensorDesc, const char *name);

/**
 * @brief Gets the name of a {@link NN_TensorDesc}.
 *
 * Call this method to obtain the name of the specified {@link NN_TensorDesc} instance.
 * The value of <b>*name</b> is a C-style string ended with <b>'\0'</b>.\n
 *
 * if <b>tensorDesc</b> or <b>name</b> is a null pointer, this method will return error code. 
 * As an output parameter, <b>*name</b> must be a null pointer, otherwise the method will return an error code.
 * Fou example, you should define char* tensorName = NULL, and pass &tensorName as the argument of <b>name</b>.\n
 *
 * You do not need to release the memory of <b>name</b>. It will be released when <b>tensorDesc</b> is destroied.\n
 *
 * @param tensorDesc Pointer to the {@link NN_TensorDesc} instance.
 * @param name The retured name of the tensor.
 * @return Execution result of the function.
 *         {@link OH_NN_SUCCESS} get tensor name successfully.\n
 *         {@link OH_NN_INVALID_PARAMETER} fail to get tensor name. The possible reason for failure
 *         is that the <b>tensorDesc</b> or <b>name</b> is nullptr, or <b>*name</b> is not nullptr.\n
 * @since 11
 * @version 1.0
 */
OH_NN_ReturnCode OH_NNTensorDesc_GetName(const NN_TensorDesc *tensorDesc, const char **name);

/**
 * @brief Sets the data type of a {@link NN_TensorDesc}.
 *
 * After the {@link NN_TensorDesc} instance is created, call this method to set the tensor data type. \n
 * 
 * if <b>tensorDesc</b> is a null pointer, this method will return error code. \n
 *
 * @param tensorDesc Pointer to the {@link NN_TensorDesc} instance.
 * @param dataType The data type of the tensor that needs to be set.
 * @return Execution result of the function.
 *         {@link OH_NN_SUCCESS} set tensor data type successfully.\n
 *         {@link OH_NN_INVALID_PARAMETER} fail to set tensor data type. The possible reason for failure
 *         is that the <b>tensorDesc</b> is nullptr, or <b>dataType</b> is invalid.\n
 * @since 11
 * @version 1.0
 */
OH_NN_ReturnCode OH_NNTensorDesc_SetDataType(NN_TensorDesc *tensorDesc, OH_NN_DataType dataType);

/**
 * @brief Gets the data type of a {@link NN_TensorDesc}.
 *
 * Call this method to obtain the data type of the specified {@link NN_TensorDesc} instance. \n
 * 
 * if <b>tensorDesc</b> or <b>dataType</b> is a null pointer, this method will return error code. \n
 *
 * @param tensorDesc Pointer to the {@link NN_TensorDesc} instance.
 * @param dataType The returned data type of the tensor.
 * @return Execution result of the function.
 *         {@link OH_NN_SUCCESS} get tensor data type successfully.\n
 *         {@link OH_NN_INVALID_PARAMETER} fail to get tensor data type. The possible reason for failure
 *         is that the <b>tensorDesc</b> or <b>dataType</b> is nullptr.\n
 * @since 11
 * @version 1.0
 */
OH_NN_ReturnCode OH_NNTensorDesc_GetDataType(const NN_TensorDesc *tensorDesc, OH_NN_DataType *dataType);

/**
 * @brief Sets the shape of a {@link NN_TensorDesc}.
 *
 * After the {@link NN_TensorDesc} instance is created, call this method to set the tensor shape. \n
 * 
 * if <b>tensorDesc</b> or <b>shape</b> is a null pointer, or <b>shapeLength</b> is 0, this method will return error code. \n
 *
 * @param tensorDesc Pointer to the {@link NN_TensorDesc} instance.
 * @param shape The shape list of the tensor that needs to be set.
 * @param shapeLength The length of the shape list that needs to be set.
 * @return Execution result of the function.
 *         {@link OH_NN_SUCCESS} set tensor shape successfully.\n
 *         {@link OH_NN_INVALID_PARAMETER} fail to set tensor shape. The possible reason for failure
 *         is that the <b>tensorDesc</b> or <b>shape</b> is nullptr, or <b>shapeLength</b> is 0.\n
 * @since 11
 * @version 1.0
 */
OH_NN_ReturnCode OH_NNTensorDesc_SetShape(NN_TensorDesc *tensorDesc, const int32_t *shape, size_t shapeLength);

/**
 * @brief Gets the shape of a {@link NN_TensorDesc}.
 *
 * Call this method to obtain the shape of the specified {@link NN_TensorDesc} instance. \n
 * 
 * if <b>tensorDesc</b>, <b>shape</b> or <b>shapeLength</b> is a null pointer, this method will return error code. 
 * As an output parameter, <b>*shape</b> must be a null pointer, otherwise the method will return an error code. 
 * Fou example, you should define int32_t* tensorShape = NULL, and pass &tensorShape as the argument of <b>shape</b>. \n
 * 
 * You do not need to release the memory of <b>shape</b>. It will be released when <b>tensorDesc</b> is destroied. \n
 *
 * @param tensorDesc Pointer to the {@link NN_TensorDesc} instance.
 * @param shape Return the shape list of the tensor.
 * @param shapeLength The returned length of the shape list.
 * @return Execution result of the function.
 *         {@link OH_NN_SUCCESS} get tensor shape successfully.\n
 *         {@link OH_NN_INVALID_PARAMETER} fail to get tensor shape. The possible reason for failure is that the
 *         <b>tensorDesc</b>, <b>shape</b> or <b>shapeLength</b> is nullptr, or <b>*shape</b> is not nullptr.\n
 * @since 11
 * @version 1.0
 */
OH_NN_ReturnCode OH_NNTensorDesc_GetShape(const NN_TensorDesc *tensorDesc, int32_t **shape, size_t *shapeLength);

/**
 * @brief Sets the format of a {@link NN_TensorDesc}.
 *
 * After the {@link NN_TensorDesc} instance is created, call this method to set the tensor format. \n
 * 
 * if <b>tensorDesc</b> is a null pointer, this method will return error code. \n
 *
 * @param tensorDesc Pointer to the {@link NN_TensorDesc} instance.
 * @param format The format of the tensor that needs to be set.
 * @return Execution result of the function.
 *         {@link OH_NN_SUCCESS} set tensor format successfully.\n
 *         {@link OH_NN_INVALID_PARAMETER} fail to set tensor format. The possible reason for failure
 *         is that the <b>tensorDesc</b> is nullptr, or <b>format</b> is invalid.\n
 * @since 11
 * @version 1.0
 */
OH_NN_ReturnCode OH_NNTensorDesc_SetFormat(NN_TensorDesc *tensorDesc, OH_NN_Format format);

/**
 * @brief Gets the format of a {@link NN_TensorDesc}.
 *
 * Call this method to obtain the format of the specified {@link NN_TensorDesc} instance. \n
 * 
 * if <b>tensorDesc</b> or <b>format</b> is a null pointer, this method will return error code. \n
 *
 * @param tensorDesc Pointer to the {@link NN_TensorDesc} instance.
 * @param format The returned format of the tensor.
 * @return Execution result of the function.
 *         {@link OH_NN_SUCCESS} get tensor format successfully.\n
 *         {@link OH_NN_INVALID_PARAMETER} fail to get tensor format. The possible reason for failure
 *         is that the <b>tensorDesc</b> or <b>format</b> is nullptr.\n
 * @since 11
 * @version 1.0
 */
OH_NN_ReturnCode OH_NNTensorDesc_GetFormat(const NN_TensorDesc *tensorDesc, OH_NN_Format *format);

/**
 * @brief Gets the element count of a {@link NN_TensorDesc}.
 *
 * Call this method to obtain the element count of the specified {@link NN_TensorDesc} instance. 
 * If you need to obtain byte size of the tensor data, call {@link OH_NNTensorDesc_GetByteSize}. \n
 * 
 * If the tensor shape is dynamic, this method will return error code, and <b>elementCount</b> will be 0. \n
 * 
 * if <b>tensorDesc</b> or <b>elementCount</b> is a null pointer, this method will return error code. \n
 *
 * @param tensorDesc Pointer to the {@link NN_TensorDesc} instance.
 * @param elementCount The returned element count of the tensor.
 * @return Execution result of the function.
 *         {@link OH_NN_SUCCESS} get tensor element count successfully.\n
 *         {@link OH_NN_INVALID_PARAMETER} fail to get tensor element count. The possible reason for failure
 *         is that the <b>tensorDesc</b> or <b>elementCount</b> is nullptr.\n
 *         {@link OH_NN_DYNAMIC_SHAPE} dim is less than zero.\n
 * @since 11
 * @version 1.0
 */
OH_NN_ReturnCode OH_NNTensorDesc_GetElementCount(const NN_TensorDesc *tensorDesc, size_t *elementCount);

/**
 * @brief Gets the byte size of a {@link NN_TensorDesc}.
 *
 * Call this method to obtain the byte size of the specified {@link NN_TensorDesc} instance. \n
 * 
 * If the tensor shape is dynamic, this method will return error code, and <b>byteSize</b> will be 0. \n
 * 
 * If you need to obtain element count of the tensor data, call {@link OH_NNTensorDesc_GetElementCount}. \n
 * 
 * if <b>tensorDesc</b> or <b>byteSize</b> is a null pointer, this method will return error code. \n
 *
 * @param tensorDesc Pointer to the {@link NN_TensorDesc} instance.
 * @param byteSize The returned byte size of the tensor.
 * @return Execution result of the function.
 *         {@link OH_NN_SUCCESS} get tensor byte size successfully.\n
 *         {@link OH_NN_INVALID_PARAMETER} fail to get tensor byte size. The possible reason for failure
 *         is that the <b>tensorDesc</b> or <b>byteSize</b> is nullptr, or tensor data type is invalid.\n
 *         {@link OH_NN_DYNAMIC_SHAPE} dim is less than zero.\n
 * @since 11
 * @version 1.0
 */
OH_NN_ReturnCode OH_NNTensorDesc_GetByteSize(const NN_TensorDesc *tensorDesc, size_t *byteSize);

/**
 * @brief Creates a {@link NN_Tensor} instance from {@link NN_TensorDesc}.
 *
 * This method use {@link OH_NNTensorDesc_GetByteSize} to calculate the byte size of tensor data and allocate shared
 * memory on device for it. The device dirver will get the tensor data directly by the "zero-copy" way.\n
 *
 * Note that this method will copy the <b>tensorDesc</b> into {@link NN_Tensor}. Therefore you should destroy
 * <b>tensorDesc</b> by {@link OH_NNTensorDesc_Destroy} if it is no longer used.\n
 * 
 * If the tensor shape is dynamic, this method will return error code.\n
 *
 * <b>deviceID</b> indicates the selected device. If it is 0, the first device in the current device list will be used
 * by default.\n
 *
 * <b>tensorDesc</b> must be provided, and this method will return an error code if it is a null pointer.\n
 *
 * Call {@link OH_NNTensor_Destroy} to release the {@link NN_Tensor} instance if it is no longer used.\n
 *
 * @param deviceID Device id. If it is 0, the first device in the current device list will be used by default.
 * @param tensorDesc Pointer to the {@link NN_TensorDesc} instance.
 * @return Pointer to a {@link NN_Tensor} instance, or NULL if it fails to create. The possible reason for failure
 *         is that the <b>tensorDesc</b> is nullptr, or <b>deviceID</b> is invalid, or memory error occurred.
 * @since 11
 * @version 1.0
 */
NN_Tensor *OH_NNTensor_Create(size_t deviceID, NN_TensorDesc *tensorDesc);

/**
 * @brief Creates a {@link NN_Tensor} instance with specified size and {@link NN_TensorDesc}.
 *
 * This method use <b>size</b> as the byte size of tensor data and allocate shared memory on device for it.
 * The device dirver will get the tensor data directly by the "zero-copy" way.\n
 *
 * Note that this method will copy the <b>tensorDesc</b> into {@link NN_Tensor}. Therefore you should destroy
 * <b>tensorDesc</b> by {@link OH_NNTensorDesc_Destroy} if it is no longer used.\n
 *
 * <b>deviceID</b> indicates the selected device. If it is 0, the first device in the current device list will be used
 * by default.\n
 *
 * <b>tensorDesc</b> must be provided, if it is a null pointer, the method returns an error code.
 * <b>size</b> must be no less than the byte size of tensorDesc. Otherwise, this method will return an error code.
 * If the tensor shape is dynamic, the <b>size</b> will not be checked.\n
 *
 * Call {@link OH_NNTensor_Destroy} to release the {@link NN_Tensor} instance if it is no longer used.\n
 *
 * @param deviceID Device id. If it is 0, the first device in the current device list will be used by default.
 * @param tensorDesc Pointer to the {@link NN_TensorDesc} instance.
 * @param size Size of tensor data that need to be allocated.
 * @return Pointer to a {@link NN_Tensor} instance, or NULL if it fails to create. The possible reason for failure
 *         is that the <b>tensorDesc</b> is nullptr, or <b>deviceID</b> or size is invalid, or memory error occurred.
 * @since 11
 * @version 1.0
 */
NN_Tensor *OH_NNTensor_CreateWithSize(size_t deviceID, NN_TensorDesc *tensorDesc, size_t size);

/**
 * @brief Creates a {@link NN_Tensor} instance with specified file descriptor and {@link NN_TensorDesc}.
 *
 * This method reuses the shared memory corresponding to the file descriptor <b>fd</b> passed. It may comes from another
 * {@link NN_Tensor} instance. When you call the {@link OH_NNTensor_Destroy} method to release the tensor created by
 * this method, the tensor data memory will not be released.\n
 *
 * Note that this method will copy the <b>tensorDesc</b> into {@link NN_Tensor}. Therefore you should destroy
 *  <b>tensorDesc</b> by {@link OH_NNTensorDesc_Destroy} if it is no longer used.\n
 *
 * <b>deviceID</b> indicates the selected device. If it is 0, the first device in the current device list will be used
 * by default.\n 
 *
 * <b>tensorDesc</b> must be provided, if it is a null pointer, the method returns an error code.\n
 *
 * Call {@link OH_NNTensor_Destroy} to release the {@link NN_Tensor} instance if it is no longer used.\n
 *
 * @param deviceID Device id. If it is 0, the first device in the current device list will be used by default.
 * @param tensorDesc Pointer to the {@link NN_TensorDesc} instance.
 * @param fd file descriptor of the shared memory to be resued.
 * @param size Size of the shared memory to be resued.
 * @param offset Offset of the shared memory to be resued.
 * @return Pinter to a {@link NN_Tensor} instance, or NULL if it fails to create. The possible reason for failure
 *         is that the <b>tensorDesc</b> is nullptr, or <b>deviceID</b>, <b>fd</b>, <b>size</b> or <b>offset</b> is
 *         invalid, or memory error occurred.
 * @since 11
 * @version 1.0
 */
NN_Tensor *OH_NNTensor_CreateWithFd(size_t deviceID,
                                    NN_TensorDesc *tensorDesc,
                                    int fd,
                                    size_t size,
                                    size_t offset);

/**
 * @brief Releases a {@link NN_Tensor} instance.
 *
 * When the {@link NN_Tensor} instance is no longer used, this method needs to be called to release the instance.
 * Otherwise, the memory leak will occur.\n
 *
 * If <b>tensor</b> or <b>*tensor</b> is a null pointer, this method will return error code and does not execute the
 * release.\n
 *
 * @param tensor Double pointer to the {@link NN_Tensor} instance.
 * @return Execution result of the function.
 *         {@link OH_NN_SUCCESS} destroy tensor successfully.\n
 *         {@link OH_NN_INVALID_PARAMETER} fail to destroy tensor. The possible reason for failure
 *         is that the <b>tensor</b> is nullptr, or <b>*tensor</b> is not nullptr.\n
 * @since 11
 * @version 1.0
 */
OH_NN_ReturnCode OH_NNTensor_Destroy(NN_Tensor **tensor);

/**
 * @brief Gets the {@link NN_TensorDesc} instance of a {@link NN_Tensor}.
 *
 * Call this method to obtain the inner {@link NN_TensorDesc} instance pointer of the specified {@link NN_Tensor}
 * instance. You can get various types of the tensor attributes such as name/format/data type/shape from the returned
 * {@link NN_TensorDesc} instance.\n
 *
 * You should not destory the returned {@link NN_TensorDesc} instance because it points to the inner instance of
 * {@link NN_Tensor}. Otherwise, a menory corruption of double free will occur when {@link OH_NNTensor_Destroy}
 * is called.\n
 *
 * if <b>tensor</b> is a null pointer, this method will return null pointer.\n
 *
 * @param tensor Pointer to the {@link NN_Tensor} instance.
 * @return Pointer to the {@link NN_TensorDesc} instance, or NULL if it fails to create. The possible reason for
 *         failure is that the <b>tensor</b> is nullptr, or <b>tensor</b> is invalid.
 * @since 11
 * @version 1.0
 */
NN_TensorDesc *OH_NNTensor_GetTensorDesc(const NN_Tensor *tensor);

/**
 * @brief Gets the data buffer of a {@link NN_Tensor}.
 *
 * You can read/write data from/to the tensor data buffer. The buffer is mapped from a shared memory on device,
 * so the device dirver will get the tensor data directly by this "zero-copy" way.\n
 *
 * Note that the real tensor data only uses the segment [offset, size) of the shared memory. The offset can be got by
 * {@link OH_NNTensor_GetOffset} and the size can be got by {@link OH_NNTensor_GetSize}.\n
 * 
 * if <b>tensor</b> is a null pointer, this method will return null pointer.\n
 *
 * @param tensor Pointer to the {@link NN_Tensor} instance.
 * @return Pointer to data buffer of the tensor, or NULL if it fails to create. The possible reason for failure
 *         is that the <b>tensor</b> is nullptr, or <b>tensor</b> is invalid.
 * @since 11
 * @version 1.0
 */
void *OH_NNTensor_GetDataBuffer(const NN_Tensor *tensor);

/**
 * @brief Gets the file descriptor of the shared memory of a {@link NN_Tensor}.
 *
 * The file descriptor <b>fd</b> corresponds to the shared memory of the tensor data, and can be resued
 * by another {@link NN_Tensor} through {@link OH_NNTensor_CreateWithFd}.\n
 *
 * if <b>tensor</b> or <b>fd</b> is a null pointer, this method will return error code.\n
 *
 * @param tensor Pointer to the {@link NN_Tensor} instance.
 * @param fd The returned file descriptor of the shared memory.
 * @return Execution result of the function.
 *         {@link OH_NN_SUCCESS} get tensor fd successfully. The return value is saved in parameter fd.\n
 *         {@link OH_NN_INVALID_PARAMETER} fail to get tensor fd. The possible reason for failure
 *         is that the <b>tensor</b> or <b>fd</b> is nullptr.\n
 * @since 11
 * @version 1.0
 */
OH_NN_ReturnCode OH_NNTensor_GetFd(const NN_Tensor *tensor, int *fd);

/**
 * @brief Gets the size of the shared memory of a {@link NN_Tensor}.
 *
 * The <b>size</b> corresponds to the shared memory of the tensor data, and can be resued by another {@link NN_Tensor}
 * through {@link OH_NNTensor_CreateWithFd}.\n
 *
 * The <b>size</b> is as same as the argument <b>size</b> of {@link OH_NNTensor_CreateWithSize} and
 * {@link OH_NNTensor_CreateWithFd}. But for a tensor created by {@link OH_NNTensor_Create},
 * it equals to the tensor byte size.\n
 *
 * Note that the real tensor data only uses the segment [offset, size) of the shared memory. The offset can be got by
 * {@link OH_NNTensor_GetOffset} and the size can be got by {@link OH_NNTensor_GetSize}.\n
 *
 * if <b>tensor</b> or <b>size</b> is a null pointer, this method will return error code.\n
 *
 * @param tensor Pointer to the {@link NN_Tensor} instance.
 * @param size The returned size of tensor data.
 * @return Execution result of the function.
 *         {@link OH_NN_SUCCESS} get tensor size successfully. The return value is saved in <b>size</b>.\n
 *         {@link OH_NN_INVALID_PARAMETER} fail to get tensor size. The possible reason for failure
 *         is that the <b>tensor</b> or <b>size</b> is nullptr.\n
 * @since 11
 * @version 1.0
 */
OH_NN_ReturnCode OH_NNTensor_GetSize(const NN_Tensor *tensor, size_t *size);

/**
 * @brief Get the data offset of a tensor.
 *
 * The <b>offset</b> corresponds to the shared memory of the tensor data, and can be resued by another {@link NN_Tensor}
 * through {@link OH_NNTensor_CreateWithFd}.\n
 *
 * Note that the real tensor data only uses the segment [offset, size) of the shared memory. The offset can be got by
 * {@link OH_NNTensor_GetOffset} and the size can be got by {@link OH_NNTensor_GetSize}.\n
 *
 * if <b>tensor</b> or <b>offset</b> is a null pointer, this method will return error code.\n
 *
 * @param tensor Pointer to the {@link NN_Tensor} instance.
 * @param offset The returned offset of tensor data.
 * @return Execution result of the function.
 *         {@link OH_NN_SUCCESS} get tensor offset successfully. The return value is saved in <b>offset</b>.\n
 *         {@link OH_NN_INVALID_PARAMETER} fail to get tensor offset. The possible reason for failure
 *         is that the <b>tensor</b> or <b>offset</b> is nullptr.\n
 * @since 11
 * @version 1.0
 */
OH_NN_ReturnCode OH_NNTensor_GetOffset(const NN_Tensor *tensor, size_t *offset);

/**
 * @brief Creates an executor instance of the {@link OH_NNExecutor} type.
 *
 * This method constructs a model inference executor associated with the device based on the passed compilation. \n
 *
 * After the {@link OH_NNExecutor} instance is created, you can release the {@link OH_NNCompilation} 
 * instance if you do not need to create any other executors. \n
 *
 * @param compilation Pointer to the {@link OH_NNCompilation} instance.
 * @return Pointer to a {@link OH_NNExecutor} instance, or NULL if it fails to create. The possible reason for failure
 *         is that the <b>compilation</b> is nullptr, or memory error occurred.
 * @since 9
 * @version 1.0
 */
OH_NNExecutor *OH_NNExecutor_Construct(OH_NNCompilation *compilation);

/**
 * @brief Obtains the dimension information about the output tensor.
 *
 * After {@link OH_NNExecutor_Run} is called to complete a single inference, call this method to obtain the specified
 * output dimension information and number of dimensions. It is commonly used in dynamic shape input and output
 * scenarios.\n
 *
 * If the <b>outputIndex</b> is greater than or equal to the output tensor number, this method will return error code.
 * The output tensor number can be got by {@link OH_NNExecutor_GetOutputCount}.\n
 *
 * As an output parameter, <b>*shape</b> must be a null pointer, otherwise the method will return an error code.
 * Fou example, you should define int32_t* tensorShape = NULL, and pass &tensorShape as the argument of <b>shape</b>.\n
 *
 * You do not need to release the memory of <b>shape</b>. It will be released when <b>executor</b> is destroied.\n
 *
 * @param executor Pointer to the {@link OH_NNExecutor} instance.
 * @param outputIndex Output Index value, which is in the same sequence of the data output when
 *                    {@link OH_NNModel_SpecifyInputsAndOutputs} is called.
 *                    Assume that <b>outputIndices</b> is <b>{4, 6, 8}</b> when
 *                    {@link OH_NNModel_SpecifyInputsAndOutputs} is called.
 *                    When {@link OH_NNExecutor_GetOutputShape} is called to obtain dimension information about
 *                    the output tensor, <b>outputIndices</b> is <b>{0, 1, 2}</b>.
 * @param shape Pointer to the int32_t array. The value of each element in the array is the length of the output tensor
 *              in each dimension.
 * @param shapeLength Pointer to the uint32_t type. The number of output dimensions is returned.
 * @return Execution result of the function.
 *         {@link OH_NN_SUCCESS} get tensor output shape successfully. The return value is saved in
 *         <b>shape</b> and <b>shapeLength</b>.\n
 *         {@link OH_NN_INVALID_PARAMETER} fail to get tensor output shape. The possible reason for failure is that
 *         the <b>executor</b>, <b>shape</b> or <b>shapeLength</b> is nullptr, or <b>*shape</b> is not nullptr,
 *         or <b>outputIndex</b> is out of range.\n
 * @since 9
 * @version 1.0
 */
OH_NN_ReturnCode OH_NNExecutor_GetOutputShape(OH_NNExecutor *executor,
                                              uint32_t outputIndex,
                                              int32_t **shape,
                                              uint32_t *shapeLength);

/**
 * @brief Destroys an executor instance to release the memory occupied by the executor.
 *
 * This method needs to be called to release the executor instance created by calling {@link OH_NNExecutor_Construct}. Otherwise, 
 * the memory leak will occur. \n
 *
 * If <b>executor</b> or <b>*executor</b> is a null pointer, this method only prints warning logs and does not execute the release. \n
 *
 * @param executor Double pointer to the {@link OH_NNExecutor} instance.
 * @since 9
 * @version 1.0
 */
void OH_NNExecutor_Destroy(OH_NNExecutor **executor);

/**
 * @brief Gets the input tensor count.
 *
 * You can get the input tensor count from the executor, and then create an input tensor descriptor with its index by 
 * {@link OH_NNExecutor_CreateInputTensorDesc}. \n
 *
 * @param executor Pointer to the {@link OH_NNExecutor} instance.
 * @param inputCount Input tensor count returned.
 * @return Execution result of the function.
 *         {@link OH_NN_SUCCESS} get input count successfully. The return value is saved in <b>inputCount</b>.\n
 *         {@link OH_NN_INVALID_PARAMETER} fail to get input count. The possible reason for failure is that
 *         the <b>executor</b> or <b>inputCount</b> is nullptr.\n
 * @since 11
 * @version 1.0
 */
OH_NN_ReturnCode OH_NNExecutor_GetInputCount(const OH_NNExecutor *executor, size_t *inputCount);

/**
 * @brief Gets the output tensor count.
 *
 * You can get the output tensor count from the executor, and then create an output tensor descriptor with its index by 
 * {@link OH_NNExecutor_CreateOutputTensorDesc}. \n
 *
 * @param executor Pointer to the {@link OH_NNExecutor} instance.
 * @param OutputCount Output tensor count returned.
 * @return Execution result of the function.
 *         {@link OH_NN_SUCCESS} get output count successfully. The return value is saved in <b>outputCount</b>.\n
 *         {@link OH_NN_INVALID_PARAMETER} fail to get output count. The possible reason for failure is that
 *         the <b>executor</b> or <b>outputCount</b> is nullptr.\n
 * @since 11
 * @version 1.0
 */
OH_NN_ReturnCode OH_NNExecutor_GetOutputCount(const OH_NNExecutor *executor, size_t *outputCount);

/**
 * @brief Creates an input tensor descriptor with its index.
 *
 * The input tensor descriptor contains all attributes of the input tensor.
 * If the <b>index</b> is greater than or equal to the input tensor number, this method will return error code.
 * The input tensor number can be got by {@link OH_NNExecutor_GetInputCount}.\n
 *
 * @param executor Pointer to the {@link OH_NNExecutor} instance.
 * @param index Input tensor index.
 * @return Pointer to {@link NN_TensorDesc} instance, or NULL if it fails to create. The possible reason for
 *         failure is that the <b>executor</b> is nullptr, or <b>index</b> is out of range.
 * @since 11
 * @version 1.0
 */
NN_TensorDesc *OH_NNExecutor_CreateInputTensorDesc(const OH_NNExecutor *executor, size_t index);

/**
 * @brief Creates an output tensor descriptor with its index.
 *
 * The output tensor descriptor contains all attributes of the output tensor.
 * If the <b>index</b> is greater than or equal to the output tensor number, this method will return error code.
 * The output tensor number can be got by {@link OH_NNExecutor_GetOutputCount}.\n
 *
 * @param executor Pointer to the {@link OH_NNExecutor} instance.
 * @param index Output tensor index.
 * @return Pointer to {@link NN_TensorDesc} instance, or NULL if it fails to create. The possible reason for
 *         failure is that the <b>executor</b> is nullptr, or <b>index</b> is out of range.
 * @since 11
 * @version 1.0
 */
NN_TensorDesc *OH_NNExecutor_CreateOutputTensorDesc(const OH_NNExecutor *executor, size_t index);

/**
 * @brief Gets the dimension ranges of an input tensor.
 *
 * The supported dimension ranges of an input tensor with dynamic shape may be different among various devices.
 * You can call this method to get the dimension ranges of the input tensor supported by the device.
 * <b>*minInputDims</b> contains the minimum demensions of the input tensor, and <b>*maxInputDims</b> contains the
 * maximum, e.g. if an input tensor has dynamic shape [-1, -1, -1, 3], its <b>*minInputDims</b> may be [1, 10, 10, 3]
 * and <b>*maxInputDims</b> may be [100, 1024, 1024, 3] on the device.\n
 *
 * If the <b>index</b> is greater than or equal to the input tensor number, this method will return error code.
 * The input tensor number can be got by {@link OH_NNExecutor_GetInputCount}.\n
 *
 * As an output parameter, <b>*minInputDims</b> or <b>*maxInputDims</b> must be a null pointer, otherwise the method
 * will return an error code. For example, you should define int32_t* minInDims = NULL, and pass &minInDims as the
 * argument of <b>minInputDims</b>.\n
 *
 * You do not need to release the memory of <b>*minInputDims</b> or <b>*maxInputDims</b>.
 * It will be released when <b>executor</b> is destroied.\n
 *
 * @param executor Pointer to the {@link OH_NNExecutor} instance.
 * @param index Input tensor index.
 * @param minInputDims Returned pointer to an array contains the minimum dimensions of the input tensor.
 * @param maxInputDims Returned pointer to an array contains the maximum dimensions of the input tensor.
 * @param shapeLength Returned length of the shape of input tensor.
 * @return Execution result of the function.
 *         {@link OH_NN_SUCCESS} get input dim range successfully. The return value is saved in <b>minInputDims</b>,
 *         <b>maxInputDims</b> and <b>shapeLength</b>.\n
 *         {@link OH_NN_INVALID_PARAMETER} fail to get input dim range. The possible reason for failure is that
 *         the <b>executor</b>, <b>minInputDims</b>, <b>maxInputDims</b> or <b>shapeLength</b> is nullptr, or
 *         <b>*minInputDims</b> or <b>*maxInputDims</b> is not nullptr, or <b>index</b> is out of range.\n
 *         {@link OH_NN_OPERATION_FORBIDDEN} the backend device is not supported to get input dim range.\n
 * @since 11
 * @version 1.0
 */
OH_NN_ReturnCode OH_NNExecutor_GetInputDimRange(const OH_NNExecutor *executor,
                                                size_t index,
                                                size_t **minInputDims,
                                                size_t **maxInputDims,
                                                size_t *shapeLength);

/**
 * @brief Sets the callback function handle for the post-process when the asynchronous execution has been done.
 *
 * The definition fo the callback function: {@link NN_OnRunDone}. \n
 *
 * @param executor Pointer to the {@link OH_NNExecutor} instance.
 * @param onRunDone Callback function handle {@link NN_OnRunDone}.
 * @return Execution result of the function.
 *         {@link OH_NN_SUCCESS} set on run done successfully.\n
 *         {@link OH_NN_INVALID_PARAMETER} fail to set on run done. The possible reason for failure is that
 *         the <b>executor</b> or <b>onRunDone</b> is nullptr.\n
 *         {@link OH_NN_OPERATION_FORBIDDEN} the backend device is not supported to set on run done.\n
 * @since 11
 * @version 1.0
 */
OH_NN_ReturnCode OH_NNExecutor_SetOnRunDone(OH_NNExecutor *executor, NN_OnRunDone onRunDone);

/**
 * @brief Sets the callback function handle for the post-process when the device driver service is dead during asynchronous execution.
 *
 * The definition fo the callback function: {@link NN_OnServiceDied}. \n
 *
 * @param executor Pointer to the {@link OH_NNExecutor} instance.
 * @param onServiceDied Callback function handle {@link NN_OnServiceDied}.
 * @return Execution result of the function.
 *         {@link OH_NN_SUCCESS} set on service died successfully.\n
 *         {@link OH_NN_INVALID_PARAMETER} fail to set on service died. The possible reason for failure is that
 *         the <b>executor</b> or <b>onServiceDied</b> is nullptr.\n
 *         {@link OH_NN_OPERATION_FORBIDDEN} the backend device is not supported to set on service died.\n
 * @since 11
 * @version 1.0
 */
OH_NN_ReturnCode OH_NNExecutor_SetOnServiceDied(OH_NNExecutor *executor, NN_OnServiceDied onServiceDied);

/**
 * @brief Synchronous execution of the model inference.
 *
 * Input and output tensors should be created first by {@link OH_NNTensor_Create}, {@link OH_NNTensor_CreateWithSize} or 
 * {@link OH_NNTensor_CreateWithFd}. And then the input tensors data which is got by {@link OH_NNTensor_GetDataBuffer} must be filled. 
 * The executor will then yield out the results by inference execution and fill them into output tensors data for you to read. \n
 * 
 * In the case of dynamic shape, you can get the real output shape directly by {@link OH_NNExecutor_GetOutputShape}, or you 
 * can create a tensor descriptor from an output tensor by {@link OH_NNTensor_GetTensorDesc}, and then read its real shape 
 * by {@link OH_NNTensorDesc_GetShape}. \n
 *
 * @param executor Pointer to the {@link OH_NNExecutor} instance.
 * @param inputTensor An array of input tensors {@link NN_Tensor}.
 * @param inputCount Number of input tensors.
 * @param outputTensor An array of output tensors {@link NN_Tensor}.
 * @param outputCount Number of output tensors.
 * @return Execution result of the function.
 *         {@link OH_NN_SUCCESS} run successfully.\n
 *         {@link OH_NN_INVALID_PARAMETER} fail to run. The possible reason for failure is that the <b>executor</b>,
 *         <b>inputTensor</b> or <b>outputTensor</b> is nullptr, or <b>inputCount</b> or <b>outputCount</b> is 0.\n
 *         {@link OH_NN_FAILED} the backend device failed to run.\n
 *         {@link OH_NN_NULL_PTR} the parameters of input or output tensor is invalid.\n
 * @since 11
 * @version 1.0
 */
OH_NN_ReturnCode OH_NNExecutor_RunSync(OH_NNExecutor *executor,
                                       NN_Tensor *inputTensor[],
                                       size_t inputCount,
                                       NN_Tensor *outputTensor[],
                                       size_t outputCount);

/**
 * @brief Asynchronous execution of the model inference.
 *
 * Input and output tensors should be created first by {@link OH_NNTensor_Create}, {@link OH_NNTensor_CreateWithSize} or
 * {@link OH_NNTensor_CreateWithFd}. And then the input tensors data which is got by {@link OH_NNTensor_GetDataBuffer}
 * must be filled. The executor will yield out the results by inference execution and fill them into output tensors data
 * for you to read.\n
 *
 * In the case of dynamic shape, you can get the real output shape directly by {@link OH_NNExecutor_GetOutputShape}, or
 * you can create a tensor descriptor from an output tensor by {@link OH_NNTensor_GetTensorDesc}, and then read its real
 * shape by {@link OH_NNTensorDesc_GetShape}.\n
 *
 * The method is non-blocked and will return immediately.\n
 *
 * The callback function handles are set by {@link OH_NNExecutor_SetOnRunDone}
 * and {@link OH_NNExecutor_SetOnServiceDied}. The inference results and error code can be got by
 * {@link NN_OnRunDone}. And you can deal with the abnormal termination of device driver service during
 * asynchronous execution by {@link NN_OnServiceDied}.\n
 *
 * If the execution time reaches the <b>timeout</b>, the execution will be terminated
 * with no outputs, and the <b>errCode<b> returned in callback function {@link NN_OnRunDone} will be
 * {@link OH_NN_TIMEOUT}.\n
 *
 * The <b>userData</b> is asynchronous execution identifier and will be returned as the first parameter of the callback
 * function. You can input any value you want as long as it can identify different asynchronous executions.\n
 *
 * @param executor Pointer to the {@link OH_NNExecutor} instance.
 * @param inputTensor An array of input tensors {@link NN_Tensor}.
 * @param inputCount Number of input tensors.
 * @param outputTensor An array of output tensors {@link NN_Tensor}.
 * @param outputCount Number of output tensors.
 * @param timeout Time limit (millisecond) of the asynchronous execution, e.g. 1000.
 * @param userData Asynchronous execution identifier.
 * @return Execution result of the function.
 *         {@link OH_NN_SUCCESS} run successfully.\n
 *         {@link OH_NN_INVALID_PARAMETER} fail to run. The possible reason for failure is that the <b>executor</b>,
 *         <b>inputTensor</b>, <b>outputTensor</b> or <b>userData</b> is nullptr, or <b>inputCount</b> or
 *         <b>outputCount</b> is 0.\n
 *         {@link OH_NN_FAILED} the backend device failed to run.\n
 *         {@link OH_NN_NULL_PTR} the parameters of input or output tensor is invalid.\n
 *         {@link OH_NN_OPERATION_FORBIDDEN} the backend device is not supported to run async.\n
 * @since 11
 * @version 1.0
 */
OH_NN_ReturnCode OH_NNExecutor_RunAsync(OH_NNExecutor *executor,
                                        NN_Tensor *inputTensor[],
                                        size_t inputCount,
                                        NN_Tensor *outputTensor[],
                                        size_t outputCount,
                                        int32_t timeout,
                                        void *userData);

/**
 * @brief Obtains the IDs of all devices connected.
 *
 * Each device has an unique and fixed ID. This method returns device IDs on the current device through the uint32_t
 * array.\n
 *
 * Device IDs are returned through the size_t array. Each element of the array is the ID of a single device.\n
 *
 * The array memory is managed inside, so you do not need to care about it.
 * The data pointer is valid before this method is called next time.\n
 *
 * @param allDevicesID Pointer to the size_t array. The input <b>*allDevicesID</b> must be a null pointer.
 *                     Otherwise, {@link OH_NN_INVALID_PARAMETER} is returned.
 * @param deviceCount Pointer of the uint32_t type, which is used to return the length of <b>*allDevicesID</b>.
 * @return Execution result of the function.
 *         {@link OH_NN_SUCCESS} get all devices id successfully.\n
 *         {@link OH_NN_INVALID_PARAMETER} fail to get all devices id. The possible reason for failure is that
 *         the <b>allDevicesID</b> or <b>deviceCount</b> is nullptr, or <b>*allDevicesID</b> is not nullptr.\n
 * @since 9
 * @version 1.0
 */
OH_NN_ReturnCode OH_NNDevice_GetAllDevicesID(const size_t **allDevicesID, uint32_t *deviceCount);

/**
 * @brief Obtains the name of the specified device.
 *
 * <b>deviceID</b> specifies the device whose name will be obtained. The device ID needs to be obtained by calling
 * {@link OH_NNDevice_GetAllDevicesID}.
 * If it is 0, the first device in the current device list will be used by default.\n
 *
 * The value of <b>*name</b> is a C-style string ended with <b>'\0'</b>. <b>*name</b> must be a null pointer.
 * Otherwise, {@link OH_NN_INVALID_PARAMETER} is returned.
 * Fou example, you should define char* deviceName = NULL, and pass &deviceName as the argument of <b>name</b>.\n
 *
 * @param deviceID Device ID. If it is 0, the first device in the current device list will be used by default.
 * @param name The device name returned.
 * @return Execution result of the function.
 *         {@link OH_NN_SUCCESS} get name of specific device successfully.\n
 *         {@link OH_NN_INVALID_PARAMETER} fail to get name of specific device. The possible reason for failure is that
 *         the <b>name</b> is nullptr or <b>*name</b> is not nullptr.\n
 *         {@link OH_NN_FAILED} fail to get name of specific device. The possible reason for failure is that
 *         the <b>deviceID</b> is invalid.\n
 * @since 9
 * @version 1.0
 */
OH_NN_ReturnCode OH_NNDevice_GetName(size_t deviceID, const char **name);

/**
 * @brief Obtains the type information of the specified device.
 *
 * <b>deviceID</b> specifies the device whose type will be obtained. If it is 0, the first device in the current device 
 * list will be used. Currently the following device types are supported:
 * - <b>OH_NN_CPU</b>: CPU device.
 * - <b>OH_NN_GPU</b>: GPU device.
 * - <b>OH_NN_ACCELERATOR</b>: machine learning dedicated accelerator.
 * - <b>OH_NN_OTHERS</b>: other hardware types. \n
 *
 * @param deviceID Device ID. If it is 0, the first device in the current device list will be used by default.
 * @param deviceType The device type {@link OH_NN_DeviceType} returned.
 * @return Execution result of the function.
 *         {@link OH_NN_SUCCESS} get type of specific device successfully.\n
 *         {@link OH_NN_INVALID_PARAMETER} fail to get type of specific device. The possible reason for failure is that
 *         the <b>deviceType</b> is nullptr.\n
 *         {@link OH_NN_FAILED} fail to get type of specific device. The possible reason for failure is that
 *         the <b>deviceID</b> is invalid.\n
 * @since 9
 * @version 1.0
 */
OH_NN_ReturnCode OH_NNDevice_GetType(size_t deviceID, OH_NN_DeviceType *deviceType);

#ifdef __cplusplus
}
#endif // __cplusplus

/** @} */
#endif // NEURAL_NETWORK_CORE_H