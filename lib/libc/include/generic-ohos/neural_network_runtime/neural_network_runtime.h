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
 * @file neural_network_runtime.h
 *
 * @brief Defines the Neural Network Runtime APIs. The AI inference framework uses the Native APIs provided by Neural Network Runtime
 *        to construct models.
 * 
 * Note: Currently, the APIs of Neural Network Runtime do not support multi-thread calling. \n
 *
 * include "neural_network_runtime/neural_network_runtime.h"
 * @library libneural_network_runtime.so
 * @kit Neural Network Runtime Kit
 * @syscap SystemCapability.Ai.NeuralNetworkRuntime
 * @since 9
 * @version 2.0
 */

#ifndef NEURAL_NETWORK_RUNTIME_H
#define NEURAL_NETWORK_RUNTIME_H

#include "neural_network_runtime_type.h"
#include "neural_network_core.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Creates a {@link NN_QuantParam} instance.
 *
 * After the {@link NN_QuantParam} instance is created, call {@link OH_NNQuantParam_SetScales}, {@link OH_NNQuantParam_SetZeroPoints}, 
 * {@link OH_NNQuantParam_SetNumBits} to set its attributes, and then call {@link OH_NNModel_SetTensorQuantParams} to set it 
 * to a tensor. After that you should destroy it by calling {@link OH_NNQuantParam_Destroy} to avoid memory leak. \n
 *
 * @return Pointer to a {@link NN_QuantParam} instance, or NULL if it fails to create.
 * @since 11
 * @version 1.0
 */
NN_QuantParam *OH_NNQuantParam_Create();

/**
 * @brief Sets the scales of the {@link NN_QuantParam} instance.
 *
 * The parameter <b>quantCount</b> is the number of quantization parameters of a tensor, e.g. the quantCount is the
 * channel count if the tensor is per-channel quantized.\n
 *
 * @param quantParams Pointer to the {@link NN_QuantParam} instance.
 * @param scales An array of scales for all quantization parameters of the tensor.
 * @param quantCount Number of quantization parameters of the tensor.
 * @return Execution result of the function.
 *         {@link OH_NN_SUCCESS} set scales of quant parameters successfully.\n
 *         {@link OH_NN_INVALID_PARAMETER} fail to set scales of quant parameters. The possible reason for failure
 *         is that the <b>quantParams</b> or <b>scales</b> is nullptr, or <b>quantCount</b> is 0.\n
 * @since 11
 * @version 1.0
 */
OH_NN_ReturnCode OH_NNQuantParam_SetScales(NN_QuantParam *quantParams, const double *scales, size_t quantCount);

/**
 * @brief Sets the zero points of the {@link NN_QuantParam} instance.
 *
 * The parameter <b>quantCount</b> is the number of quantization parameters of a tensor, e.g. the quantCount is the
 * channel count if the tensor is per-channel quantized.\n
 *
 * @param quantParams Pointer to the {@link NN_QuantParam} instance.
 * @param zeroPoints An array of zero points for all quantization parameters of the tensor.
 * @param quantCount Number of quantization parameters of the tensor.
 * @return Execution result of the function.
 *         {@link OH_NN_SUCCESS} set zero points of quant parameters successfully.\n
 *         {@link OH_NN_INVALID_PARAMETER} fail to set zero points of quant parameters. The possible reason for failure
 *         is that the <b>quantParams</b> or <b>zeroPoints</b> is nullptr, or <b>quantCount</b> is 0.\n
 * @since 11
 * @version 1.0
 */
OH_NN_ReturnCode OH_NNQuantParam_SetZeroPoints(NN_QuantParam *quantParams, const int32_t *zeroPoints, size_t quantCount);

/**
 * @brief Sets the number bits of the {@link NN_QuantParam} instance.
 *
 * The parameter <b>quantCount</b> is the number of quantization parameters of a tensor, e.g. the quantCount is the
 * channel count if the tensor is per-channel quantized.\n
 *
 * @param quantParams Pointer to the {@link NN_QuantParam} instance.
 * @param numBits An array of number bits for all quantization parameters of the tensor.
 * @param quantCount Number of quantization parameters of the tensor.
 * @return Execution result of the function.
 *         {@link OH_NN_SUCCESS} set num bits of quant parameters successfully.\n
 *         {@link OH_NN_INVALID_PARAMETER} fail to set num bits of quant parameters. The possible reason for failure
 *         is that the <b>quantParams</b> or <b>numBits</b> is nullptr, or <b>quantCount</b> is 0.\n
 * @since 11
 * @version 1.0
 */
OH_NN_ReturnCode OH_NNQuantParam_SetNumBits(NN_QuantParam *quantParams, const uint32_t *numBits, size_t quantCount);

/**
 * @brief Releases a {@link NN_QuantParam} instance.
 *
 * The {@link NN_QuantParam} instance needs to be released to avoid memory leak after it is set to a {@link NN_TensorDesc}. \n
 * 
 * If <b>quantParams</b> or <b>*quantParams</b> is a null pointer, this method only prints warning logs and does not 
 * execute the release. \n
 *
 * @param quantParams Double pointer to the {@link NN_QuantParam} instance.
 * @return Execution result of the function.
 *         {@link OH_NN_SUCCESS} destroy quant parameters object successfully.\n
 *         {@link OH_NN_INVALID_PARAMETER} fail to destroy quant parameters object. The possible reason for failure
 *         is that the <b>quantParams</b> or <b>*quantParams</b> is nullptr.\n
 * @since 11
 * @version 1.0
 */
OH_NN_ReturnCode OH_NNQuantParam_Destroy(NN_QuantParam **quantParams);

/**
 * @brief Creates a model instance of the {@link OH_NNModel} type and uses other APIs provided by OH_NNModel to construct the model instance.
 *
 * Before composition, call {@link OH_NNModel_Construct} to create a model instance. Based on the model topology, 
 * call the {@link OH_NNModel_AddTensorToModel}, {@link OH_NNModel_AddOperation}, and {@link OH_NNModel_SetTensorData} methods 
 * to fill in the data and operator nodes of the model, and then call {@link OH_NNModel_SpecifyInputsAndOutputs} to specify the inputs and outputs of the model. 
 * After the model topology is constructed, call {@link OH_NNModel_Finish} to build the model. \n
 *
 * After a model instance is no longer used, you need to destroy it by calling {@link OH_NNModel_Destroy} to avoid memory leak. \n
 *
 * @return Pointer to a {@link OH_NNModel} instance, or NULL if it fails to create.
 * @since 9
 * @version 1.0
 */
OH_NNModel *OH_NNModel_Construct(void);

/**
 * @brief Adds a tensor to the model instance.
 *
 * The data node and operator parameters in the Neural Network Runtime model are composed of tensors of the model. 
 * This method is used to add tensors to a model instance based on the <b>tensorDesc</b> parameter with type of {@link NN_TensorDesc}. 
 * {@link NN_TensorDesc} contains some attributes such as shape, format, data type and provides corresponding APIs to access them. 
 * The order of adding tensors is specified by the indices recorded in the model. The {@link OH_NNModel_SetTensorData}, {@link OH_NNModel_AddOperation}, 
 * and {@link OH_NNModel_SpecifyInputsAndOutputs} methods specify tensors based on the indices. \n
 *
 * Neural Network Runtime supports inputs and outputs of the dynamic shape. When adding a data node with a dynamic shape, 
 * you need to set the dimensions that support dynamic changes to <b>-1</b>. 
 * For example, if the shape of a four-dimensional tensor is set to <b>[1, -1, 2, 2]</b>, the second dimension supports dynamic changes. \n
 *
 * @param model Pointer to the {@link OH_NNModel} instance.
 * @param tensorDesc Pointer to the {@link NN_TensorDesc} instance. The tensor descriptor specifies the attributes of the tensor added to the model instance.
 * @return Execution result of the function.
 *         {@link OH_NN_SUCCESS} add tensor to model successfully.\n
 *         {@link OH_NN_INVALID_PARAMETER} fail to add tensor to model. The possible reason for failure
 *         is that the <b>model</b> or <b>tensorDesc</b> is nullptr.\n
 *         {@link OH_NN_MEMORY_ERROR} fail to add tensor to model. The possible reason for failure
 *         is that the memory error occurred such as failure to create an object.\n
 * @since 11
 * @version 1.0
 */
OH_NN_ReturnCode OH_NNModel_AddTensorToModel(OH_NNModel *model, const NN_TensorDesc *tensorDesc);

/**
 * @brief Sets the tensor value.
 *
 * For tensors with constant values (such as model weights), you need to use this method to set their data. 
 * The index of a tensor is determined by the order in which the tensor is added to the model. 
 * For details about how to add a tensor, see {@link OH_NNModel_AddTensorToModel}. \n
 *
 * @param model Pointer to the {@link OH_NNModel} instance.
 * @param index Index of a tensor.
 * @param dataBuffer Pointer to real data.
 * @param length Length of the data buffer.
 * @return Execution result of the function.
 *         {@link OH_NN_SUCCESS} set tensor data successfully.\n
 *         {@link OH_NN_INVALID_PARAMETER} fail to set tensor data. The possible reason for failure is that the
 *         <b>model</b> or <b>dataBuffer</b> is nullptr, or <b>length</b> is 0, or <b>index</b> is out of range.\n
 *         {@link OH_NN_OPERATION_FORBIDDEN} fail to set tensor data. The possible reason for failure
 *         is that the model is invalid.\n
 * @since 9
 * @version 1.0
 */
OH_NN_ReturnCode OH_NNModel_SetTensorData(OH_NNModel *model, uint32_t index, const void *dataBuffer, size_t length);

/**
 * @brief Sets the quantization parameter of a tensor.
 *
 * @param model Pointer to the {@link OH_NNModel} instance.
 * @param index Index of a tensor.
 * @param quantParam Pointer to the quantization parameter instance.
 * @return Execution result of the function.
 *         {@link OH_NN_SUCCESS} set tensor quant parameters successfully.\n
 *         {@link OH_NN_INVALID_PARAMETER} fail to set tensor quant parameters. The possible reason for failure
 *         is that the <b>model</b> or <b>quantParam</b> is nullptr, or <b>index</b> is out of range.\n
 *         {@link OH_NN_OPERATION_FORBIDDEN} fail to set tensor quant parameters. The possible reason for failure
 *         is that the model is invalid.\n
 * @since 11
 * @version 1.0
 */
OH_NN_ReturnCode OH_NNModel_SetTensorQuantParams(OH_NNModel *model, uint32_t index, NN_QuantParam *quantParam);

/**
 * @brief Sets the tensor type. See {@link OH_NN_TensorType} for details.
 *
 * @param model Pointer to the {@link OH_NNModel} instance.
 * @param index Index of a tensor.
 * @param tensorType Tensor type of {@link OH_NN_TensorType}.
 * @return Execution result of the function.
 *         {@link OH_NN_SUCCESS} set tensor type successfully.\n
 *         {@link OH_NN_INVALID_PARAMETER} fail to set tensor type. The possible reason for failure
 *         is that the <b>model</b> is nullptr, or <b>index</b> is out of range, or <b>tensorType</b> is invalid.\n
 *         {@link OH_NN_OPERATION_FORBIDDEN} fail to set tensor type. The possible reason for failure
 *         is that the model is invalid.\n
 * @since 11
 * @version 1.0
 */
OH_NN_ReturnCode OH_NNModel_SetTensorType(OH_NNModel *model, uint32_t index, OH_NN_TensorType tensorType);

/**
 * @brief Adds an operator to a model instance.
 *
 * This method is used to add an operator to a model instance. The operator type is specified by <b>op</b>, and 
 * the operator parameters, inputs, and outputs are specified by <b>paramIndices</b>, <b>inputIndices</b>, and <b>outputIndices</b> respectively. 
 * This method verifies the attributes of operator parameters and the number of input and output parameters. 
 * These attributes must be correctly set when {@link OH_NNModel_AddTensorToModel} is called to add tensors. 
 * For details about the expected parameters, input attributes, and output attributes of each operator, see {@link OH_NN_OperationType}. \n
 *
 * <b>paramIndices</b>, <b>inputIndices</b>, and <b>outputIndices</b> store the indices of tensors. 
 * The indices are determined by the order in which tensors are added to the model. 
 * For details about how to add a tensor, see {@link OH_NNModel_AddTensorToModel}. \n
 *
 * If unnecessary parameters are added when adding an operator, this method returns {@link OH_NN_INVALID_PARAMETER}. 
 * If no operator parameter is set, the operator uses the default parameter value. 
 * For details about the default values, see {@link OH_NN_OperationType}. \n
 *
 * @param model Pointer to the {@link OH_NNModel} instance.
 * @param op Specifies the type of an operator to be added. For details, see the enumerated values of {@link OH_NN_OperationType}.
 * @param paramIndices Pointer to the <b>OH_NN_UInt32Array</b> instance, which is used to set operator parameters.
 * @param inputIndices Pointer to the <b>OH_NN_UInt32Array</b> instance, which is used to set the operator input.
 * @param outputIndices Pointer to the <b>OH_NN_UInt32Array</b> instance, which is used to set the operator output.
 * @return Execution result of the function.
 *         {@link OH_NN_SUCCESS} add operation to model successfully.\n
 *         {@link OH_NN_INVALID_PARAMETER} fail to add operation to model. The possible reason for failure is that the
 *         <b>model</b>, <b>paramIndices</b>, <b>inputIndices</b> or <b>outputIndices</b> is nullptr, or parameters are
 *         invalid.\n
 *         {@link OH_NN_OPERATION_FORBIDDEN} fail to add operation to model. The possible reason for failure
 *         is that the model is invalid.\n
 * @since 9
 * @version 1.0
 */
OH_NN_ReturnCode OH_NNModel_AddOperation(OH_NNModel *model,
                                         OH_NN_OperationType op,
                                         const OH_NN_UInt32Array *paramIndices,
                                         const OH_NN_UInt32Array *inputIndices,
                                         const OH_NN_UInt32Array *outputIndices);

/**
 * @brief Specifies the inputs and outputs of a model.
 *
 * A tensor must be specified as the end-to-end inputs and outputs of a model instance. This type of tensor cannot be set 
 * using {@link OH_NNModel_SetTensorData}. \n
 *
 * The index of a tensor is determined by the order in which the tensor is added to the model. 
 * For details about how to add a tensor, see {@link OH_NNModel_AddTensorToModel}. \n
 *
 * Currently, the model inputs and outputs cannot be set asynchronously. \n
 *
 * @param model Pointer to the {@link OH_NNModel} instance.
 * @param inputIndices Pointer to the <b>OH_NN_UInt32Array</b> instance, which is used to set the operator input.
 * @param outputIndices Pointer to the <b>OH_NN_UInt32Array</b> instance, which is used to set the operator output.
 * @return Execution result of the function.
 *         {@link OH_NN_SUCCESS} specify inputs and outputs successfully.\n
 *         {@link OH_NN_INVALID_PARAMETER} fail to specify inputs and outputs. The possible reason for failure is that
 *         the <b>model</b>, <b>inputIndices</b> or <b>outputIndices</b> is nullptr, or parameters are invalid.\n
 *         {@link OH_NN_OPERATION_FORBIDDEN} fail to specify inputs and outputs. The possible reason for failure
 *         is that the model is invalid.\n
 * @since 9
 * @version 1.0
 */
OH_NN_ReturnCode OH_NNModel_SpecifyInputsAndOutputs(OH_NNModel *model,
                                                    const OH_NN_UInt32Array *inputIndices,
                                                    const OH_NN_UInt32Array *outputIndices);

/**
 * @brief Completes model composition.
 *
 * After the model topology is set up, call this method to indicate that the composition is complete. After this method is called, 
 * additional composition operations cannot be performed. If {@link OH_NNModel_AddTensorToModel}, {@link OH_NNModel_AddOperation}, 
 * {@link OH_NNModel_SetTensorData}, and {@link OH_NNModel_SpecifyInputsAndOutputs} are called, 
 * {@link OH_NN_OPERATION_FORBIDDEN} is returned. \n
 *
 * Before calling {@link OH_NNModel_GetAvailableOperations} and {@link OH_NNCompilation_Construct}, 
 * you must call this method to complete composition. \n
 *
 * @param model Pointer to the {@link OH_NNModel} instance.
 * @return Execution result of the function.
 *         {@link OH_NN_SUCCESS} the composition is complete successfully.\n
 *         {@link OH_NN_INVALID_PARAMETER} composition failed. The possible reason for failure
 *         is that the <b>model</b> is nullptr, or parameters set before are invalid.\n
 *         {@link OH_NN_OPERATION_FORBIDDEN} composition failed. The possible reason for failure
 *         is that the model is invalid.\n
 *         {@link OH_NN_MEMORY_ERROR} composition failed. The possible reason for failure
 *         is that the memory error occurred such as failure to create an object.\n
 * @since 9
 * @version 1.0
 */
OH_NN_ReturnCode OH_NNModel_Finish(OH_NNModel *model);

/**
 * @brief Releases a model instance.
 *
 * This method needs to be called to release the model instance created by calling {@link OH_NNModel_Construct}. Otherwise, memory leak will occur. \n
 *
 * If <b>model</b> or <b>*model</b> is a null pointer, this method only prints warning logs and does not execute the release. \n
 *
 * @param model Double pointer to the {@link OH_NNModel} instance. After a model instance is destroyed, this method sets <b>*model</b> to a null pointer.
 * @since 9
 * @version 1.0
 */
void OH_NNModel_Destroy(OH_NNModel **model);

/**
 * @brief Queries whether the device supports operators in the model. The support status is indicated by the Boolean value.
 *
 * Queries whether underlying device supports operators in a model instance. The device is specified by <b>deviceID</b>, 
 * and the result is represented by the array pointed by <b>isSupported</b>. If the <i>i</i>th operator is supported, 
 * the value of <b>(*isSupported)</b>[<i>i</i>] is <b>true</b>. Otherwise, the value is <b>false</b>. \n
 *
 * After this method is successfully executed, <b>(*isSupported)</b> points to the bool array that records the operator support status. 
 * The operator quantity for the array length is the same as that for the model instance. The memory corresponding to this array is 
 * managed by Neural Network Runtime and is automatically destroyed after the model instance is destroyed or this method is called again. \n
 *
 * @param model Pointer to the {@link OH_NNModel} instance.
 * @param deviceID Device ID to be queried, which can be obtained by using {@link OH_NNDevice_GetAllDevicesID}.
 * @param isSupported Pointer to the bool array. When this method is called, <b>(*isSupported)</b> must be a null pointer. 
 *                    Otherwise, {@link OH_NN_INVALID_PARAMETER} is returned.
 * @param opCount Number of operators in a model instance, corresponding to the length of the <b>(*isSupported)</b> array.
 * @return Execution result of the function.
 *         {@link OH_NN_SUCCESS} get available operations successfully.\n
 *         {@link OH_NN_INVALID_PARAMETER} fail to get available operations. The possible reason for failure
 *         is that the <b>model</b>, <b>isSupported</b> or <b>opCount</b> is nullptr, or <b>*isSupported</b> is
 *         not nullptr.\n
 *         {@link OH_NN_OPERATION_FORBIDDEN} fail to get available operations. The possible reason for failure
 *         is that the model is invalid.\n
 *         {@link OH_NN_FAILED} fail to get available operations. The possible reason for failure
 *         is that the <b>deviceID</b> is invalid.\n
 * @since 9
 * @version 1.0
 */
OH_NN_ReturnCode OH_NNModel_GetAvailableOperations(OH_NNModel *model,
                                                   size_t deviceID,
                                                   const bool **isSupported,
                                                   uint32_t *opCount);

/**
 * @brief Adds a tensor to a model instance.
 *
 * The data node and operator parameters in the Neural Network Runtime model are composed of tensors of the model.
 * This method is used to add tensors to a model instance based on the <b>tensor</b> parameter.
 * The sequence of adding tensors is specified by the index value recorded in the model.
 * The {@link OH_NNModel_SetTensorData}, {@link OH_NNModel_AddOperation},
 * and {@link OH_NNModel_SpecifyInputsAndOutputs} methods specifies tensors based on the index value.\n
 *
 * Neural Network Runtime supports inputs and outputs of the dynamic shape. When adding a data node with a dynamic
 * shape, you need to set the dimensions that support dynamic changes in <b>tensor.dimensions</b> to <b>-1</b>. 
 * For example, if <b>tensor.dimensions</b> of a four-dimensional tensor is set to <b>[1, -1, 2, 2]</b>,
 * the second dimension supports dynamic changes.\n
 *
 * @param model Pointer to the {@link OH_NNModel} instance.
 * @param tensor Pointer to the {@link OH_NN_Tensor} tensor. The tensor specifies the attributes of the tensor added to
 *               the model instance.
 * @return Execution result of the function.
 *         {@link OH_NN_SUCCESS} add tensor to model successfully.\n
 *         {@link OH_NN_INVALID_PARAMETER} fail to add tensor to model. The possible reason for failure
 *         is that the <b>model</b> or <b>tensor</b> is nullptr.\n
 *         {@link OH_NN_OPERATION_FORBIDDEN} fail to add tensor to model. The possible reason for failure
 *         is that the model is invalid.\n
 * @deprecated since 11
 * @useinstead {@link OH_NNModel_AddTensorToModel}
 * @since 9
 * @version 1.0
 */
OH_NN_ReturnCode OH_NNModel_AddTensor(OH_NNModel *model, const OH_NN_Tensor *tensor);

/**
 * @brief Sets the single input data for a model.
 *
 * This method copies the data whose length is specified by <b>length</b> (in bytes) in <b>dataBuffer</b> to the shared
 * memory of the underlying device. <b>inputIndex</b> specifies the input to be set and <b>tensor</b> sets information
 * such as the input shape, type, and quantization parameters.\n
 *
 * Neural Network Runtime supports models with dynamical shape input. For fixed shape input and dynamic shape input
 * scenarios, this method uses different processing policies.\n
 *
 * - Fixed shape input: The attributes of <b>tensor</b> must be the same as those of the tensor added by calling
 *   {@link OH_NNModel_AddTensor} in the composition phase.
 * - Dynamic shape input: In the composition phase, because the shape is not fixed, each value in
 *   <b>tensor.dimensions</b> must be greater than <b>0</b> in the method calls to determine the shape input in the
 *   calculation phase. When setting the shape, you can modify only the dimension whose value is <b>-1</b>.
 *   Assume that <b>[-1, 224, 224, 3]</b> is input as the the dimension of A in the composition phase.
 *   When this method is called, only the size of the first dimension can be modified, e.g. to <b>[3, 224, 224, 3]</b>.
 *   If other dimensions are adjusted, {@link OH_NN_INVALID_PARAMETER} is returned.\n
 *
 * @param executor Pointer to the {@link OH_NNExecutor} instance.
 * @param inputIndex Input index value, which is in the same sequence of the data input when
 *                   {@link OH_NNModel_SpecifyInputsAndOutputs} is called.
 *                   Assume that the value of <b>inputIndices</b> is <b>{1, 5, 9}</b> when
 *                   {@link OH_NNModel_SpecifyInputsAndOutputs} is called.
 *                   In input settings, the index value for the three inputs is <b>{0, 1, 2}</b>.\n
 * @param tensor Sets the tensor corresponding to the input data.
 * @param dataBuffer Pointer to the input data.
 * @param length Length of the data buffer, in bytes.
 * @return Execution result of the function.
 *         {@link OH_NN_SUCCESS} set model input successfully.\n
 *         {@link OH_NN_INVALID_PARAMETER} fail to set model input. The possible reason for failure
 *         is that the <b>executor</b>, <b>tensor</b> or <b>dataBuffer</b> is nullptr, or <b>inputIndex</b>
 *         is out of range, or <b>length</b> is 0.\n
 *         {@link OH_NN_MEMORY_ERROR} fail to set model input. The possible reason for failure
 *         is that the memory error occurred such as failure to create an object.\n
 * @deprecated since 11
 * @useinstead {@link OH_NNExecutor_RunSync}
 * @since 9
 * @version 1.0
 */
OH_NN_ReturnCode OH_NNExecutor_SetInput(OH_NNExecutor *executor,
                                        uint32_t inputIndex,
                                        const OH_NN_Tensor *tensor,
                                        const void *dataBuffer,
                                        size_t length);

/**
 * @brief Sets the buffer for a single output of a model.
 *
 * This method binds the buffer to which <b>dataBuffer</b> points to the output specified by <b>outputIndex</b>.
 * The length of the buffer is specified by <b>length</b>.\n
 *
 * After {@link OH_NNExecutor_Run} is called to complete a single model inference, Neural Network Runtime compares
 * the length of the buffer to which <b>dataBuffer</b> points with the length of the output data and returns different
 * results based on the actual situation.\n
 *
 * - If the buffer length is greater than or equal to the data length, the inference result is copied to the buffer and
 *   {@link OH_NN_SUCCESS} is returned. You can read the inference result from <b>dataBuffer</b>. 
 * - If the buffer length is smaller than the data length, {@link OH_NNExecutor_Run} returns
 *   {@link OH_NN_INVALID_PARAMETER} and generates a log indicating that the buffer is too small.\n
 *
 * @param executor Pointer to the {@link OH_NNExecutor} instance.
 * @param outputIndex Output Index value, which is in the same sequence of the data output when
 *                    {@link OH_NNModel_SpecifyInputsAndOutputs} is called.
 *                    Assume that the value of <b>outputIndices</b> is <b>{4, 6, 8}</b> when
 *                    {@link OH_NNModel_SpecifyInputsAndOutputs} is called.
 *                    In output buffer settings, the index value for the three outputs is <b>{0, 1, 2}</b>.
 * @param dataBuffer Pointer to the output data.
 * @param length Length of the data buffer, in bytes.
 * @return Execution result of the function.
 *         {@link OH_NN_SUCCESS} set model output successfully.\n
 *         {@link OH_NN_INVALID_PARAMETER} fail to set model output. The possible reason for failure
 *         is that the <b>executor</b>, <b>tensor</b> or <b>dataBuffer</b> is nullptr, or <b>outputIndex</b>
 *         is out of range, or <b>length</b> is 0.\n
 *         {@link OH_NN_MEMORY_ERROR} fail to set model output. The possible reason for failure
 *         is that the memory error occurred such as failure to create an object.\n
 * @deprecated since 11
 * @useinstead {@link OH_NNExecutor_RunSync}
 * @since 9
 * @version 1.0
 */
OH_NN_ReturnCode OH_NNExecutor_SetOutput(OH_NNExecutor *executor,
                                         uint32_t outputIndex,
                                         void *dataBuffer,
                                         size_t length);

/**
 * @brief Performs inference.
 *
 * Performs end-to-end inference and computing of the model on the device associated with the executor.\n
 *
 * @param executor Pointer to the {@link OH_NNExecutor} instance.
 * @return Execution result of the function.
 *         {@link OH_NN_SUCCESS} run model successfully.\n
 *         {@link OH_NN_INVALID_PARAMETER} fail to run model. The possible reason for failure
 *         is that the <b>executor</b> is nullptr.\n
 *         {@link OH_NN_FAILED} fail to set model output. The possible reason for failure
 *         is that the backend device failed to run model.\n
 * @deprecated since 11
 * @useinstead {@link OH_NNExecutor_RunSync}
 * @since 9
 * @version 1.0
 */
OH_NN_ReturnCode OH_NNExecutor_Run(OH_NNExecutor *executor);

/**
 * @brief Allocates shared memory to a single input on a device.
 *
 * Neural Network Runtime provides a method for proactively allocating shared memory on a device.
 * By specifying the executor and input index value, this method allocates shared memory whose size is specified by
 * <b>length</b> on the device associated with a single input and returns the operation result through the
 * {@link OH_NN_Memory} instance.\n
 *
 * @param executor Pointer to the {@link OH_NNExecutor} instance.
 * @param inputIndex Input index value, which is in the same sequence of the data input when
 *                   {@link OH_NNModel_SpecifyInputsAndOutputs} is called.
 *                   Assume that the value of <b>inputIndices</b> is <b>{1, 5, 9}</b> when
 *                   {@link OH_NNModel_SpecifyInputsAndOutputs} is called.
 *                   In the memory input application, the index value for the three inputs is <b>{0, 1, 2}</b>.
 * @param length Memory size to be applied for, in bytes.
 * @return Pointer to a {@link OH_NN_Memory} instance, or NULL if it fails to create.
 * @deprecated since 11
 * @useinstead {@link OH_NNTensor_CreateWithSize}
 * @since 9
 * @version 1.0
 */
OH_NN_Memory *OH_NNExecutor_AllocateInputMemory(OH_NNExecutor *executor, uint32_t inputIndex, size_t length);

/**
 * @brief Allocates shared memory to a single output on a device.
 *
 * Neural Network Runtime provides a method for proactively allocating shared memory on a device.
 * By specifying the executor and output index value, this method allocates shared memory whose size is specified by
 * <b>length</b> on the device associated with a single output and returns the operation result through the
 * {@link OH_NN_Memory} instance.\n
 *
 * @param executor Pointer to the {@link OH_NNExecutor} instance.
 * @param outputIndex Output Index value, which is in the same sequence of the data output when
 *                    {@link OH_NNModel_SpecifyInputsAndOutputs} is called.
 *                    Assume that the value of <b>outputIndices</b> is <b>{4, 6, 8}</b> when
 *                    {@link OH_NNModel_SpecifyInputsAndOutputs} is called.
 *                    In output memory application, the index value for the three outputs is <b>{0, 1, 2}</b>.
 * @param length Memory size to be applied for, in bytes.
 * @return Pointer to a {@link OH_NN_Memory} instance, or NULL if it fails to create.
 * @deprecated since 11
 * @useinstead {@link OH_NNTensor_CreateWithSize}
 * @since 9
 * @version 1.0
 */
OH_NN_Memory *OH_NNExecutor_AllocateOutputMemory(OH_NNExecutor *executor, uint32_t outputIndex, size_t length);

/**
 * @brief Releases the input memory to which the {@link OH_NN_Memory} instance points.
 *
 * This method needs to be called to release the memory instance created by calling
 * {@link OH_NNExecutor_AllocateInputMemory}. Otherwise, memory leak will occur.
 * The mapping between <b>inputIndex</b> and <b>memory</b> must be the same as that in memory instance creation.\n
 *
 * If <b>memory</b> or <b>*memory</b> is a null pointer, this method only prints warning logs and does not execute
 * the release logic.\n
 *
 * @param executor Pointer to the {@link OH_NNExecutor} instance.
 * @param inputIndex Input index value, which is in the same sequence of the data input when
 *                   {@link OH_NNModel_SpecifyInputsAndOutputs} is called.
 *                   Assume that the value of <b>inputIndices</b> is <b>{1, 5, 9}</b> when
 *                   {@link OH_NNModel_SpecifyInputsAndOutputs} is called.
 *                   In memory input release, the index value for the three inputs is <b>{0, 1, 2}</b>.
 * @param memory Double pointer to the {@link OH_NN_Memory} instance. After shared memory is destroyed,
 *               this method sets <b>*memory</b> to a null pointer.
 * @deprecated since 11
 * @useinstead {@link OH_NNTensor_Destroy}
 * @since 9
 * @version 1.0
 */
void OH_NNExecutor_DestroyInputMemory(OH_NNExecutor *executor, uint32_t inputIndex, OH_NN_Memory **memory);

/**
 * @brief Releases the output memory to which the {@link OH_NN_Memory} instance points.
 *
 * This method needs to be called to release the memory instance created by calling
 * {@link OH_NNExecutor_AllocateOutputMemory}. Otherwise, memory leak will occur.
 * The mapping between <b>outputIndex</b> and <b>memory</b> must be the same as that in memory instance creation.\n
 *
 * If <b>memory</b> or <b>*memory</b> is a null pointer, this method only prints warning logs and does not execute
 * the release logic.\n
 *
 * @param executor Pointer to the {@link OH_NNExecutor} instance.
 * @param outputIndex Output Index value, which is in the same sequence of the data output when
 *                    {@link OH_NNModel_SpecifyInputsAndOutputs} is called.
 *                    Assume that the value of <b>outputIndices</b> is <b>{4, 6, 8}</b> when
 *                    {@link OH_NNModel_SpecifyInputsAndOutputs} is called.
 *                    In output memory release, the index value for the three outputs is <b>{0, 1, 2}</b>.
 * @param memory Double pointer to the {@link OH_NN_Memory} instance. After shared memory is destroyed,
 *               this method sets <b>*memory</b> to a null pointer.
 * @deprecated since 11
 * @useinstead {@link OH_NNTensor_Destroy} 
 * @since 9
 * @version 1.0
 */
void OH_NNExecutor_DestroyOutputMemory(OH_NNExecutor *executor, uint32_t outputIndex, OH_NN_Memory **memory);

/**
 * @brief Specifies the hardware shared memory pointed to by the {@link OH_NN_Memory} instance as the shared memory
 *        used by a single input.
 *
 * In scenarios where memory needs to be managed by yourself, this method binds the execution input to the
 * {@link OH_NN_Memory} memory instance. During computing, the underlying device reads the input data from the shared
 * memory pointed to by the memory instance. By using this method, concurrent execution of input setting, computing,
 * and read can be implemented to improve inference efficiency of a data flow.\n
 *
 * @param executor Pointer to the {@link OH_NNExecutor} instance.
 * @param inputIndex Input index value, which is in the same sequence of the data input when
 *                   {@link OH_NNModel_SpecifyInputsAndOutputs} is called.
 *                   Assume that the value of <b>inputIndices</b> is <b>{1, 5, 9}</b> when
 *                   {@link OH_NNModel_SpecifyInputsAndOutputs} is called.
 *                   When the input shared memory is specified, the index value for the three inputs is
 *                   <b>{0, 1, 2}</b>.
 * @param tensor Pointer to {@link OH_NN_Tensor}, used to set the tensor corresponding to a single input.
 * @param memory Pointer to {@link OH_NN_Memory}.
 * @return Execution result of the function.
 *         {@link OH_NN_SUCCESS} set input with memory successfully.\n
 *         {@link OH_NN_INVALID_PARAMETER} fail to set input with memory. The possible reason for failure
 *         is that the <b>executor</b>, <b>tensor</b> or <b>memory</b> is nullptr, or <b>inputIndex</b> is out of range,
 *         or memory length is less than tensor length.\n
 *         {@link OH_NN_MEMORY_ERROR} fail to set input with memory. The possible reason for failure
 *         is that the memory error occurred such as failure to create an object.\n
 * @deprecated since 11
 * @useinstead {@link OH_NNExecutor_RunSync}
 * @since 9
 * @version 1.0
 */
OH_NN_ReturnCode OH_NNExecutor_SetInputWithMemory(OH_NNExecutor *executor,
                                                  uint32_t inputIndex,
                                                  const OH_NN_Tensor *tensor,
                                                  const OH_NN_Memory *memory);

/**
 * @brief Specifies the hardware shared memory pointed to by the {@link OH_NN_Memory} instance as the shared memory
 *        used by a single output.
 *
 * In scenarios where memory needs to be managed by yourself, this method binds the execution output to the
 * {@link OH_NN_Memory} memory instance. When computing is performed, the underlying hardware directly writes the
 * computing result to the shared memory to which the memory instance points. By using this method, concurrent execution
 * of input setting, computing, and read can be implemented to improve inference efficiency of a data flow.\n
 *
 * @param executor Executor.
 * @param outputIndex Output Index value, which is in the same sequence of the data output when
 *                    {@link OH_NNModel_SpecifyInputsAndOutputs} is called.
 *                    Assume that the value of <b>outputIndices</b> is <b>{4, 6, 8}</b> when
 *                    {@link OH_NNModel_SpecifyInputsAndOutputs} is called.
 *                    When the output shared memory is specified, the index value for the three outputs is
 *                    <b>{0, 1, 2}</b>.
 * @param memory Pointer to {@link OH_NN_Memory}.
 * @return Execution result of the function.
 *         {@link OH_NN_SUCCESS} set output with memory successfully.\n
 *         {@link OH_NN_INVALID_PARAMETER} fail to set output with memory. The possible reason for failure
 *         is that the <b>executor</b>, <b>tensor</b> or <b>memory</b> is nullptr, or <b>outputIndex</b> is
 *         out of range, or memory length is less than tensor length.\n
 *         {@link OH_NN_MEMORY_ERROR} fail to set output with memory. The possible reason for failure
 *         is that the memory error occurred such as failure to create an object.\n
 * @deprecated since 11
 * @useinstead {@link OH_NNExecutor_RunSync}
 * @since 9
 * @version 1.0
 */
OH_NN_ReturnCode OH_NNExecutor_SetOutputWithMemory(OH_NNExecutor *executor,
                                                   uint32_t outputIndex,
                                                   const OH_NN_Memory *memory);

#ifdef __cplusplus
}
#endif // __cplusplus

/** @} */
#endif // NEURAL_NETWORK_RUNTIME_H