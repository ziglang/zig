/**
 * Copyright 2021 Huawei Technologies Co., Ltd
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/**
 * @addtogroup MindSpore
 * @{
 *
 * @brief provide the model reasoning related interfaces of MindSpore Lite.
 *
 * @Syscap SystemCapability.Ai.MindSpore
 * @since 9
 */

/**
 * @file model.h
 * @kit MindSporeLiteKit
 * @brief provide model-related interfaces that can be used for model creation, model reasoning, and more.
 *
 * @library libmindspore_lite_ndk.so
 * @since 9
 */
#ifndef MINDSPORE_INCLUDE_C_API_MODEL_C_H
#define MINDSPORE_INCLUDE_C_API_MODEL_C_H

#include "mindspore/tensor.h"
#include "mindspore/context.h"
#include "mindspore/status.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef void *OH_AI_ModelHandle;

typedef void *OH_AI_TrainCfgHandle;

typedef struct OH_AI_TensorHandleArray {
  size_t handle_num;
  OH_AI_TensorHandle *handle_list;
} OH_AI_TensorHandleArray;

#define OH_AI_MAX_SHAPE_NUM 32
typedef struct OH_AI_ShapeInfo {
  size_t shape_num;
  int64_t shape[OH_AI_MAX_SHAPE_NUM];
} OH_AI_ShapeInfo;

typedef struct OH_AI_CallBackParam {
  char *node_name;
  char *node_type;
} OH_AI_CallBackParam;

typedef bool (*OH_AI_KernelCallBack)(const OH_AI_TensorHandleArray inputs, const OH_AI_TensorHandleArray outputs,
                                     const OH_AI_CallBackParam kernel_Info);

/**
 * @brief Create a model object.
 *
 * @return Model object handle.
 * @since 9
 */
OH_AI_API OH_AI_ModelHandle OH_AI_ModelCreate(void);

/**
 * @brief Destroy the model object.
 *
 * @param model Model object handle address.
 * @since 9
 */
OH_AI_API void OH_AI_ModelDestroy(OH_AI_ModelHandle *model);

/**
 * @brief Build the model from model file buffer so that it can run on a device.
 *
 * @param model Model object handle.
 * @param model_data Define the buffer read from a model file.
 * @param data_size Define bytes number of model file buffer.
 * @param model_type Define The type of model file.
 * @param model_context Define the context used to store options during execution.
 * @return OH_AI_Status.
 * @since 9
 */
OH_AI_API OH_AI_Status OH_AI_ModelBuild(OH_AI_ModelHandle model, const void *model_data, size_t data_size,
                                        OH_AI_ModelType model_type, const OH_AI_ContextHandle model_context);

/**
 * @brief Load and build the model from model path so that it can run on a device.
 *
 * @param model Model object handle.
 * @param model_path Define the model file path.
 * @param model_type Define The type of model file.
 * @param model_context Define the context used to store options during execution.
 * @return OH_AI_Status.
 * @since 9
 */
OH_AI_API OH_AI_Status OH_AI_ModelBuildFromFile(OH_AI_ModelHandle model, const char *model_path,
                                                OH_AI_ModelType model_type, const OH_AI_ContextHandle model_context);

/**
 * @brief Resizes the shapes of inputs.
 *
 * @param model Model object handle.
 * @param inputs The array that includes all input tensor handles.
 * @param shape_infos Defines the new shapes of inputs, should be consistent with inputs.
 * @param shape_info_num The num of shape_infos.
 * @return OH_AI_Status.
 * @since 9
 */
OH_AI_API OH_AI_Status OH_AI_ModelResize(OH_AI_ModelHandle model, const OH_AI_TensorHandleArray inputs,
                                         OH_AI_ShapeInfo *shape_infos, size_t shape_info_num);

/**
 * @brief Inference model.
 *
 * @param model Model object handle.
 * @param inputs The array that includes all input tensor handles.
 * @param outputs The array that includes all output tensor handles.
 * @param before CallBack before predict.
 * @param after CallBack after predict.
 * @return OH_AI_Status.
 * @since 9
 */
OH_AI_API OH_AI_Status OH_AI_ModelPredict(OH_AI_ModelHandle model, const OH_AI_TensorHandleArray inputs,
                                          OH_AI_TensorHandleArray *outputs, const OH_AI_KernelCallBack before,
                                          const OH_AI_KernelCallBack after);

/**
 * @brief Obtains all input tensor handles of the model.
 *
 * @param model Model object handle.
 * @return The array that includes all input tensor handles.
 * @since 9
 */
OH_AI_API OH_AI_TensorHandleArray OH_AI_ModelGetInputs(const OH_AI_ModelHandle model);

/**
 * @brief Obtains all output tensor handles of the model.
 *
 * @param model Model object handle.
 * @return The array that includes all output tensor handles.
 * @since 9
 */
OH_AI_API OH_AI_TensorHandleArray OH_AI_ModelGetOutputs(const OH_AI_ModelHandle model);

/**
 * @brief Obtains the input tensor handle of the model by name.
 *
 * @param model Model object handle.
 * @param tensor_name The name of tensor.
 * @return The input tensor handle with the given name, if the name is not found, an NULL is returned.
 * @since 9
 */
OH_AI_API OH_AI_TensorHandle OH_AI_ModelGetInputByTensorName(const OH_AI_ModelHandle model, const char *tensor_name);

/**
 * @brief Obtains the output tensor handle of the model by name.
 *
 * @param model Model object handle.
 * @param tensor_name The name of tensor.
 * @return The output tensor handle with the given name, if the name is not found, an NULL is returned.
 * @since 9
 */
OH_AI_API OH_AI_TensorHandle OH_AI_ModelGetOutputByTensorName(const OH_AI_ModelHandle model, const char *tensor_name);

/**
 * @brief Create a TrainCfg object. Only valid for Lite Train.
 *
 * @return TrainCfg object handle.
 * @since 11
 */
OH_AI_API OH_AI_TrainCfgHandle OH_AI_TrainCfgCreate();

/**
 * @brief Destroy the train_cfg object. Only valid for Lite Train.
 *
 * @param train_cfg TrainCfg object handle.
 * @since 11
 */
OH_AI_API void OH_AI_TrainCfgDestroy(OH_AI_TrainCfgHandle *train_cfg);

/**
 * @brief Obtains part of the name that identify a loss kernel. Only valid for Lite Train.
 *
 * @param train_cfg TrainCfg object handle.
 * @param num The num of loss_name.
 * @return loss_name.
 * @since 11
 */
OH_AI_API char **OH_AI_TrainCfgGetLossName(OH_AI_TrainCfgHandle train_cfg, size_t *num);

/**
 * @brief Set part of the name that identify a loss kernel. Only valid for Lite Train.
 *
 * @param train_cfg TrainCfg object handle.
 * @param loss_name Define part of the name that identify a loss kernel.
 * @param num The num of loss_name.
 * @since 11
 */
OH_AI_API void OH_AI_TrainCfgSetLossName(OH_AI_TrainCfgHandle train_cfg, const char **loss_name, size_t num);

/**
 * @brief Obtains optimization level of the train_cfg. Only valid for Lite Train.
 *
 * @param train_cfg TrainCfg object handle.
 * @return OH_AI_OptimizationLevel.
 * @since 11
 */
OH_AI_API OH_AI_OptimizationLevel OH_AI_TrainCfgGetOptimizationLevel(OH_AI_TrainCfgHandle train_cfg);

/**
 * @brief Set optimization level of the train_cfg. Only valid for Lite Train.
 *
 * @param train_cfg TrainCfg object handle.
 * @param level The optimization level of train_cfg.
 * @since 11
 */
OH_AI_API void OH_AI_TrainCfgSetOptimizationLevel(OH_AI_TrainCfgHandle train_cfg, OH_AI_OptimizationLevel level);

/**
 * @brief Build the train model from model buffer so that it can run on a device. Only valid for Lite Train.
 *
 * @param model Model object handle.
 * @param model_data Define the buffer read from a model file.
 * @param data_size Define bytes number of model file buffer.
 * @param model_type Define The type of model file.
 * @param model_context Define the context used to store options during execution.
 * @param train_cfg Define the config used by training.
 * @return OH_AI_Status.
 * @since 11
 */
OH_AI_API OH_AI_Status OH_AI_TrainModelBuild(OH_AI_ModelHandle model, const void *model_data, size_t data_size,
                                             OH_AI_ModelType model_type, const OH_AI_ContextHandle model_context,
                                             const OH_AI_TrainCfgHandle train_cfg);

/**
 * @brief Build the train model from model file buffer so that it can run on a device. Only valid for Lite Train.
 *
 * @param model Model object handle.
 * @param model_path Define the model path.
 * @param model_type Define The type of model file.
 * @param model_context Define the context used to store options during execution.
 * @param train_cfg Define the config used by training.
 * @return OH_AI_Status.
 * @since 11
 */
OH_AI_API OH_AI_Status OH_AI_TrainModelBuildFromFile(OH_AI_ModelHandle model, const char *model_path,
                                                     OH_AI_ModelType model_type,
                                                     const OH_AI_ContextHandle model_context,
                                                     const OH_AI_TrainCfgHandle train_cfg);

/**
 * @brief Train model by step. Only valid for Lite Train.
 *
 * @param model Model object handle.
 * @param before CallBack before predict.
 * @param after CallBack after predict.
 * @return OH_AI_Status.
 * @since 11
 */
OH_AI_API OH_AI_Status OH_AI_RunStep(OH_AI_ModelHandle model, const OH_AI_KernelCallBack before,
                                     const OH_AI_KernelCallBack after);

/**
 * @brief Sets the Learning Rate of the training. Only valid for Lite Train.
 *
 * @param learning_rate to set.
 * @return OH_AI_Status of operation.
 * @since 11
 */
OH_AI_API OH_AI_Status OH_AI_ModelSetLearningRate(OH_AI_ModelHandle model, float learning_rate);

/**
 * @brief Obtains the Learning Rate of the optimizer. Only valid for Lite Train.
 *
 * @param model Model object handle.
 * @return Learning rate. 0.0 if no optimizer was found.
 * @since 11
 */
OH_AI_API float OH_AI_ModelGetLearningRate(OH_AI_ModelHandle model);

/**
 * @brief Obtains all weights tensors of the model. Only valid for Lite Train.
 *
 * @param model Model object handle.
 * @return The vector that includes all gradient tensors.
 * @since 11
 */
OH_AI_API OH_AI_TensorHandleArray OH_AI_ModelGetWeights(OH_AI_ModelHandle model);

/**
 * @brief update weights tensors of the model. Only valid for Lite Train.
 *
 * @param new_weights A vector new weights.
 * @return OH_AI_Status
 * @since 11
 */
OH_AI_API OH_AI_Status OH_AI_ModelUpdateWeights(OH_AI_ModelHandle model, const OH_AI_TensorHandleArray new_weights);

/**
 * @brief Get the model running mode.
 *
 * @param model Model object handle.
 * @return Is Train Mode or not.
 * @since 11
 */
OH_AI_API bool OH_AI_ModelGetTrainMode(OH_AI_ModelHandle model);

/**
 * @brief Set the model running mode. Only valid for Lite Train.
 *
 * @param model Model object handle.
 * @param train True means model runs in Train Mode, otherwise Eval Mode.
 * @return OH_AI_Status.
 * @since 11
 */
OH_AI_API OH_AI_Status OH_AI_ModelSetTrainMode(OH_AI_ModelHandle model, bool train);

/**
 * @brief Setup training with virtual batches. Only valid for Lite Train.
 *
 * @param model Model object handle.
 * @param virtual_batch_multiplier Virtual batch multiplier, use any number < 1 to disable.
 * @param lr Learning rate to use for virtual batch, -1 for internal configuration.
 * @param momentum Batch norm momentum to use for virtual batch, -1 for internal configuration.
 * @return OH_AI_Status.
 * @since 11
 */
OH_AI_API OH_AI_Status OH_AI_ModelSetupVirtualBatch(OH_AI_ModelHandle model, int virtual_batch_multiplier, float lr,
                                                    float momentum);

/**
 * @brief Export training model from file. Only valid for Lite Train.
 *
 * @param model The model data.
 * @param model_type The model file type.
 * @param model_file The exported model file.
 * @param quantization_type The quantification type.
 * @param export_inference_only Whether to export a reasoning only model.
 * @param output_tensor_name The set the name of the output tensor of the exported reasoning model, default as
 *        empty, and export the complete reasoning model.
 * @param num The number of output_tensor_name.
 * @return OH_AI_Status.
 * @since 11
 */
OH_AI_API OH_AI_Status OH_AI_ExportModel(OH_AI_ModelHandle model, OH_AI_ModelType model_type, const char *model_file,
                                         OH_AI_QuantizationType quantization_type, bool export_inference_only,
                                         char **output_tensor_name, size_t num);

/**
 * @brief Export training model from buffer. Only valid for Lite Train.
 *
 * @param model The model data.
 * @param model_type The model file type.
 * @param model_data The exported model buffer.
 * @param data_size The exported model buffer size.
 * @param quantization_type The quantification type.
 * @param export_inference_only Whether to export a reasoning only model.
 * @param output_tensor_name The set the name of the output tensor of the exported reasoning model, default as
 *        empty, and export the complete reasoning model.
 * @param num The number of output_tensor_name.
 * @return OH_AI_Status.
 * @since 11
 */
OH_AI_API OH_AI_Status OH_AI_ExportModelBuffer(OH_AI_ModelHandle model, OH_AI_ModelType model_type, void *model_data,
                                               size_t *data_size, OH_AI_QuantizationType quantization_type,
                                               bool export_inference_only, char **output_tensor_name, size_t num);

/**
 * @brief Export model's weights, which can be used in micro only. Only valid for Lite Train.
 *
 * @param model The model data.
 * @param model_type The model file type.
 * @param weight_file The path of exported weight file.
 * @param is_inference Whether to export weights from a reasoning model. Currently, only support this is `true`.
 * @param enable_fp16 Float-weight is whether to be saved in float16 format.
 * @param changeable_weights_name The set the name of these weight tensors, whose shape is changeable.
 * @param num The number of changeable_weights_name.
 * @return OH_AI_Status.
 * @since 11
 */
OH_AI_API OH_AI_Status OH_AI_ExportWeightsCollaborateWithMicro(OH_AI_ModelHandle model, OH_AI_ModelType model_type,
                                                               const char *weight_file, bool is_inference,
                                                               bool enable_fp16, char **changeable_weights_name,
                                                               size_t num);

#ifdef __cplusplus
}
#endif
#endif  // MINDSPORE_INCLUDE_C_API_MODEL_C_H