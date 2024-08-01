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
 * @addtogroup NeuralNeworkRuntime
 * @{
 *
 * @brief Provides APIs for accelerating the Neural Network Runtime model inference.
 *
 * @since 9
 * @version 2.0
 */

/**
 * @file neural_network_runtime_type.h
 *
 * @brief Defines the structure and enumeration.
 * 
 * include "neural_network_runtime/neural_network_runtime_type.h"
 * @library libneural_network_runtime.so
 * @kit Neural Network Runtime Kit
 * @syscap SystemCapability.Ai.NeuralNetworkRuntime
 * @since 9
 * @version 2.0
 */

#ifndef NEURAL_NETWORK_RUNTIME_TYPE_H
#define NEURAL_NETWORK_RUNTIME_TYPE_H

#include <cstddef>
#include <cstdint>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Defines the handles of models.
 *
 * @since 9
 * @version 1.0
 */
typedef struct OH_NNModel OH_NNModel;

/**
 * @brief Defines the compilation handle.
 *
 * @since 9
 * @version 1.0
 */
typedef struct OH_NNCompilation OH_NNCompilation;

/**
 * @brief Defines the executor handle.
 *
 * @since 9
 * @version 1.0
 */
typedef struct OH_NNExecutor OH_NNExecutor;

/**
 * @brief Defines the quantization parameter handle.
 *
 * @since 11
 * @version 1.0
 */
typedef struct NN_QuantParam NN_QuantParam;

/**
 * @brief Defines the tensor descriptor handle.
 *
 * @since 11
 * @version 1.0
 */
typedef struct NN_TensorDesc NN_TensorDesc;

/**
 * @brief Defines the tensor handle.
 *
 * @since 11
 * @version 1.0
 */
typedef struct NN_Tensor NN_Tensor;

/**
 * @brief Defines the hardware performance mode.
 *
 * @since 9
 * @version 1.0
 */
typedef enum {
    /** No performance mode preference */
    OH_NN_PERFORMANCE_NONE = 0,
    /** Low power consumption mode*/
    OH_NN_PERFORMANCE_LOW = 1,
    /** Medium performance mode */
    OH_NN_PERFORMANCE_MEDIUM = 2,
    /** High performance mode */
    OH_NN_PERFORMANCE_HIGH = 3,
    /** Ultimate performance mode */
    OH_NN_PERFORMANCE_EXTREME = 4
} OH_NN_PerformanceMode;

/**
 * @brief Defines the model inference task priority.
 *
 * @since 9
 * @version 1.0
 */
typedef enum {
    /** No priority preference */
    OH_NN_PRIORITY_NONE = 0,
    /** Low priority */
    OH_NN_PRIORITY_LOW = 1,
    /** Medium priority */
    OH_NN_PRIORITY_MEDIUM = 2,
    /** High priority */
    OH_NN_PRIORITY_HIGH = 3
} OH_NN_Priority;

/**
 * @brief Defines error codes.
 *
 * @since 9
 * @version 2.0
 */
typedef enum {
    /** The operation is successful. */
    OH_NN_SUCCESS = 0,
    /** The operation failed. */
    OH_NN_FAILED = 1,
    /** Invalid parameter. */
    OH_NN_INVALID_PARAMETER = 2,
    /** Memory-related error, for example, insufficient memory, memory data copy failure, or memory application failure. */
    OH_NN_MEMORY_ERROR = 3,
    /** Invalid operation. */
    OH_NN_OPERATION_FORBIDDEN = 4,
    /** Null pointer exception */
    OH_NN_NULL_PTR = 5,
    /** Invalid file. */
    OH_NN_INVALID_FILE = 6,
    /** A hardware error occurs, for example, HDL service crash. 
     * @deprecated since 11
     * @useinstead {@link OH_NN_UNAVAILABLE_DEVICE}
     */
    OH_NN_UNAVALIDABLE_DEVICE = 7,
    /** Invalid path. */
    OH_NN_INVALID_PATH = 8,
    /** Timeout. 
     * @since 11
     */
    OH_NN_TIMEOUT = 9,
    /** Unsupported. 
     * @since 11
     */
    OH_NN_UNSUPPORTED = 10,
    /** Connection Exception. 
     * @since 11
     */
    OH_NN_CONNECTION_EXCEPTION = 11,
    /** Save cache exception.
     * @since 11
     */
    OH_NN_SAVE_CACHE_EXCEPTION = 12,
    /** Dynamic shape.
     * @since 11
     */
    OH_NN_DYNAMIC_SHAPE = 13,
    /** A hardware error occurs, for example, HDL service crash. 
     * @since 11
     */
    OH_NN_UNAVAILABLE_DEVICE = 14
} OH_NN_ReturnCode;


/**
 * @brief Defines the callback function handle for the post-process when the asynchronous execution has been done.
 * 
 * Use <b>userData</b> to identify the asynchronous execution you want to get.
 * It is the argument <b>userData</b> passed to {@link OH_NNExecutor_RunAsync}.\n
 * 
 * Use <b>errCode</b> of type {@link OH_NN_ReturnCode} to get the error code returned by the asynchronous execution.\n
 * 
 * The <b>outputTensor</b> and <b>outputCount</b> are the inference results, which is the same as ones passed to
 * {@link OH_NNExecutor_RunAsync}.\n
 * 
 * @param userData Asynchronous execution identifier, which is the argument <b>userData</b> passed to
 *                 {@link OH_NNExecutor_RunAsync}.
 * @param errCode Error code {@link OH_NN_ReturnCode} returned by the asynchronous execution.
 * @param outputTensor An array of output tensors {@link NN_Tensor} of the model, which is the same as the argument
 *                     <b>outputTensor</b> passed to {@link OH_NNExecutor_RunAsync}.
 * @param outputCount Output tensor count, which is the same as the argument <b>outputCount</b> passed to
 *                    {@link OH_NNExecutor_RunAsync}.
 * @since 11
 * @version 1.0
 */
typedef void (*NN_OnRunDone)(void *userData, OH_NN_ReturnCode errCode, void *outputTensor[], int32_t outputCount);

/**
 * @brief Defines the callback function handle for the post-process when the device driver service is dead during
 *        asynchronous execution.
 * 
 * You should recompile the model if this callback function is called.\n
 * 
 * Use <b>userData</b> to identify the asynchronous execution you want to get.
 * It is the argument <b>userData</b> passed to {@link OH_NNExecutor_RunAsync}.\n
 * 
 * @param userData Asynchronous execution identifier, which is the argument <b>userData</b> passed to
 *                 {@link OH_NNExecutor_RunAsync}.
 * @since 11
 * @version 1.0
 */
typedef void (*NN_OnServiceDied)(void *userData);

/**
 * @brief Defines activation function types in the fusion operator.
 *
 * @since 9
 * @version 1.0
 */
typedef enum : int8_t {
    /** The fusion activation function is not specified. */
    OH_NN_FUSED_NONE = 0,
    /** Fusion relu activation function */
    OH_NN_FUSED_RELU = 1,
    /** Fusion relu6 activation function */
    OH_NN_FUSED_RELU6 = 2
} OH_NN_FuseType;

/**
 * @brief Defines the layout type of tensor data.
 *
 * @since 9
 * @version 2.0
 */
typedef enum {
    /** The tensor does not have a specific layout type (such as scalar or vector). */
    OH_NN_FORMAT_NONE = 0,
    /** The tensor arranges data in NCHW format.*/
    OH_NN_FORMAT_NCHW = 1,
    /** The tensor arranges data in NHWC format.*/
    OH_NN_FORMAT_NHWC = 2,
    /** The tensor arranges data in ND format.
     * @since 11
     */
    OH_NN_FORMAT_ND = 3
} OH_NN_Format;

/**
 * @brief Defines device types.
 *
 * @since 9
 * @version 1.0
 */
typedef enum {
    /** Devices that are not CPU, GPU, or dedicated accelerator*/
    OH_NN_OTHERS = 0,
    /** CPU device */
    OH_NN_CPU = 1,
    /** GPU device */
    OH_NN_GPU = 2,
    /** Dedicated hardware accelerator */
    OH_NN_ACCELERATOR = 3,
} OH_NN_DeviceType;

/**
 * @brief Defines tensor data types.
 *
 * @since 9
 * @version 1.0
 */
typedef enum {
    /** Unknown type */
    OH_NN_UNKNOWN = 0,
    /** bool */
    OH_NN_BOOL = 1,
    /** int8 */
    OH_NN_INT8 = 2,
    /** int16 */
    OH_NN_INT16 = 3,
    /** int32 */
    OH_NN_INT32 = 4,
    /** int64 */
    OH_NN_INT64 = 5,
    /** uint8 */
    OH_NN_UINT8 = 6,
    /** uint16 */
    OH_NN_UINT16 = 7,
    /** uint32 */
    OH_NN_UINT32 = 8,
    /** uint64 */
    OH_NN_UINT64 = 9,
    /** float16 */
    OH_NN_FLOAT16 = 10,
    /** float32 */
    OH_NN_FLOAT32 = 11,
    /** float64 */
    OH_NN_FLOAT64 = 12
} OH_NN_DataType;


/**
 * @brief Defines operator types.
 *
 * @since 9
 * @version 1.0
 */
typedef enum {
    /**
     * Returns the tensor of the sum of the elements corresponding to two input tensors.
     *
     * Inputs:
     *
     * * <b>input1</b>: first input tensor, of the Boolean or number type.
     * * <b>input2</b>: second input tensor, whose data type must be the same as that of the first tensor.
     *
     * Parameters:
     *
     * * <b>activationType</b> is an integer constant which is contained in <b>FuseType</b>.
     *       The specified activation function is called before output.
     *
     * Outputs:
     *
     * * <b>output</b>: sum of <b>input1</b> and <b>input2</b>. 
     *       The data shape is the same as that of the input after broadcasting, 
     *       and the data type is the same as that of the input with a higher precision.
     */
    OH_NN_OPS_ADD = 1,

    /**
     * Apply 2D average pooling to the input tensor, which now must be in NHWC format. The int8 quantization input is supported.
     *
     * If the input contains the <b>padMode</b> parameter:
     *
     * Inputs:
     *
     * * <b>input</b>: tensor.
     *
     * Parameters:
     *
     * * <b>kernelSize</b> indicates the kernel size used to obtain the average value. It is an int array [kernel_height, kernel_width].
     *       The first number indicates the kernel height, and the second number indicates the kernel width.
     * * <b>strides</b> indicates the distance of kernel moving. The value is an int array [stride_height, stride_width].
     *       The first number indicates the moving step in height, and the second number indicates the moving step in width.
     * * <b>padMode</b>: padding mode, which is optional. The value is of the int type and can be <b>0</b> (same) or <b>1</b> (valid). 
     *       The nearest neighbor value is used for padding.
     *       <b>0</b> (same): The height and width of the output are the same as those of the input. 
     *       The total padding quantity is calculated horizontally and vertically and evenly distributed to the top, bottom, left, and right if possible.
     *       Otherwise, the last additional padding will be completed from the bottom and right.
     *       <b>1</b> (valid): The possible maximum height and width of the output will be returned in case of no padding. Excessive pixels will be discarded.
     * * <b>activationType</b> is an integer constant which is contained in <b>FuseType</b>.
     *       The specified activation function is called before output.
     *
     * If the input contains the <b>padList</b> parameter:
     *
     * Inputs:
     *
     * * <b>input</b>: tensor.
     *
     * Parameters:
     *
     * * <b>kernelSize</b> indicates the kernel size used to obtain the average value. It is an int array [kernel_height, kernel_width].
     *       The first number indicates the kernel height, and the second number indicates the kernel width.
     * * <b>strides</b> indicates the distance of kernel moving. The value is an int array [stride_height, stride_width].
     *       The first number indicates the moving step in height, and the second number indicates the moving step in width.
     * * <b>padList</b>: padding around <b>input</b>. It is an int array [top, bottom, left, right], and the nearest neighbor values are used for padding.
     * * <b>activationType</b> is an integer constant which is contained in <b>FuseType</b>.
     *       The specified activation function is called before output.
     *
     * Outputs:
     *
     * * <b>output</b>: average pooling result of the input.
     */
    OH_NN_OPS_AVG_POOL = 2,

    /**
     * Batch normalization is performed on a tensor to scale and shift tensor elements, relieving potential covariate shift in a batch of data.
     *
     * Inputs:
     *
     * * <b>input</b>: <i>n</i>-dimensional tensor of shape [N, ..., C]. The <i>n</i>th dimension is the number of channels.
     * * <b>scale</b>: 1D tensor of the scaling factor used to scale the first normalized tensor.
     * * <b>offset</b>: 1D tensor used to move to the first normalized tensor.
     * * <b>mean</b>: 1D tensor of the overall mean value. It is used only for inference. In case of training, this parameter must be left empty.
     * * <b>variance</b>: 1D tensor used for the overall variance. It is used only for inference. In case of training, this parameter must be left empty.
     *
     * Parameters:
     *
     * * <b>epsilon</b>: fixed small additional value.
     *
     * Outputs:
     *
     * * <b>output</b>: <i>n</i>-dimensional output tensor whose shape and data type are the same as those of the input.
     */
    OH_NN_OPS_BATCH_NORM = 3,

    /**
     * Divides the batch dimension of a 4D tensor into small blocks by <b>block_shape</b>, and interleaves these blocks back into the spatial dimension.
     *
     * Parameters:
     *
     * * <b>input</b>: input tensor. The dimension will be divided into small blocks, and these blocks will be interleaved into the spatial dimension.
     *
     * Outputs:
     *
     * * <b>blockSize</b>: size of each block to be interleaved into the spatial dimension. The value is an array [height_block, width_block].
     * * <b>crops</b>: elements truncated from the spatial dimension of the output. The value is a 2D array [[crop0_start, crop0_end], 
     *       [crop1_start, crop1_end]] with the shape of (2, 2).
     *      
     *
     * Outputs:
     *
     * * <b>output</b>. Assume that the shape of <b>input</b> is (n,h,w,c) and the shape of <b>output</b> is (n',h',w',c'):
     *       n' = n / (block_shape[0] * block_shape[1])
     *       h' = h * block_shape[0] - crops[0][0] - crops[0][1]
     *       w' = w * block_shape[1] - crops[1][0] - crops[1][1]
     *       c'= c
     */
    OH_NN_OPS_BATCH_TO_SPACE_ND = 4,

    /**
     * Offsets the data in each dimension of the input tensor.
     *
     * Inputs:
     *
     * * <b>input</b>: input tensor, which can have two to five dimensions.
     * * <b>bias</b>: offset of the number of input dimensions.
     *
     * Outputs:
     *
     * * <b>output</b>: sum of the input tensor and the bias in each dimension.
     */
    OH_NN_OPS_BIAS_ADD = 5,

    /**
     * Converts the data type in the input tensor.
     *
     * Inputs:
     *
     * * <b>input</b>: input tensor.
     * * <b>type</b>: converted data type.
     *
     * Outputs:
     *
     * * <b>output</b>: converted tensor.
     */
    OH_NN_OPS_CAST = 6,

    /**
     * Connects tensors in a specified dimension.
     *
     * Inputs:
     *
     * * <b>input</b>: <i>N</i> input tensors.
     *
     * Parameters:
     *
     * * <b>axis</b>: dimension for connecting tensors.
     *
     * Outputs:
     *
     * * <b>output</b>: result of connecting <i>N</i> tensors along the axis.
     */
    OH_NN_OPS_CONCAT = 7,

    /**
     * 2D convolutional layer.
     *
     * If the input contains the <b>padMode</b> parameter:
     *
     * Inputs:
     *
     * * <b>input</b>: input tensor.
     * * <b>weight</b>: convolution weight in [outChannel, kernelHeight, kernelWidth, inChannel/group] format. 
     *       The value of <b>inChannel</b> must be exactly divided by the value of <b>group</b>.
     *      
     * * <b>bias</b>: bias of the convolution. It is an array with a length of <b>[outChannel]</b>. 
     *       In quantization scenarios, the <b>bias</b> parameter does not require quantization parameters. 
     *       The quantization version requires data input of the <b>OH_NN_INT32</b> type. 
     *       The actual quantization parameters are determined by <b>input</b> and <b>weight</b>.
     *
     * Parameters:
     *
     * * <b>stride</b>: movement stride of the convolution kernel in height and width. It is an int array [strideHeight, strideWidth].
     * * <b>dilation</b>: dilation size of the convolution kernel in height and width. It is an int array [dilationHeight, dilationWidth]. 
     *       The value must be greater than or equal to <b>1</b> and cannot exceed the height and width of <b>input</b>.
     *      
     * * <b>padMode</b>: padding mode of <b>input</b>. The value is of the int type and can be <b>0</b> (same) or <b>1</b> (valid).
     *       <b>0</b> (same): The height and width of the output are the same as those of the input. 
     *       The total padding quantity is calculated horizontally and vertically and evenly distributed to the top, bottom, left, and right if possible. 
     *       Otherwise, the last additional padding will be completed from the bottom and right.
     *      
     *       <b>1</b> (valid): The possible maximum height and width of the output will be returned in case of no padding. The excessive pixels will be discarded.
     * * <b>group</b>: number of groups in which the input is divided by <b>in_channel</b>. The value is of the int type.
     *       If <b>group</b> is <b>1</b>, it is a conventional convolution. If <b>group</b> is greater than <b>1</b> and 
     *       less than or equal to <b>in_channel</b>, it is a group convolution.
     * * <b>activationType</b> is an integer constant which is contained in <b>FuseType</b>. The specified activation function is called before output.
     *
     * If the input contains the <b>padList</b> parameter:
     *
     * Inputs:
     *
     * * <b>input</b>: input tensor.
     * * <b>weight</b>: convolution weight in [outChannel, kernelHeight, kernelWidth, inChannel/group] format. 
     *       The value of <b>inChannel</b> must be exactly divided by the value of <b>group</b>.
     *      
     * * <b>bias</b>: bias of the convolution. It is an array with a length of <b>[outChannel]</b>. 
     *       In quantization scenarios, the <b>bias</b> parameter does not require quantization parameters. 
     *       The quantization version requires data input of the <b>OH_NN_INT32</b> type. 
     *       The actual quantization parameters are determined by <b>input</b> and <b>weight</b>.
     *
     * Parameters:
     *
     * * <b>stride</b>: movement stride of the convolution kernel in height and width. It is an int array [strideHeight, strideWidth].
     * * <b>dilation</b>: dilation size of the convolution kernel in height and width. It is an int array [dilationHeight, dilationWidth].
     *       The value must be greater than or equal to <b>1</b> and cannot exceed the height and width of <b>input</b>.
     * * <b>padList</b>: padding around <b>input</b>. It is an int array [top, bottom, left, right].
     * * <b>group</b>: number of groups in which the input is divided by <b>in_channel</b>. The value is of the int type.
     *       If <b>group</b> is <b>1</b>, it is a conventional convolution.
     *       If <b>group</b> is <b>in_channel</b>, it is depthwiseConv2d. In this case, group==in_channel==out_channel.
     *       If <b>group</b> is greater than <b>1</b> and less than <b>in_channel</b>, it is a group convolution. In this case, out_channel==group.
     * * <b>activationType</b> is an integer constant which is contained in <b>FuseType</b>.
     *       The specified activation function is called before output.
     *
     * Outputs:
     *
     * * <b>output</b>: convolution computing result.
     */
    OH_NN_OPS_CONV2D = 8,

    /**
     * 2D convolution transposition.
     *
     * If the input contains the <b>padMode</b> parameter:
     *
     * Inputs:
     *
     * * <b>input</b>: input tensor.
     * * <b>weight</b>: convolution weight in [outChannel, kernelHeight, kernelWidth, inChannel/group] format. 
     *       The value of <b>inChannel</b> must be exactly divided by the value of <b>group</b>.
     *      
     * * <b>bias</b>: bias of the convolution. It is an array with a length of <b>[outChannel]</b>. 
     *       In quantization scenarios, the <b>bias</b> parameter does not require quantization parameters. 
     *       The quantization version requires data input of the <b>OH_NN_INT32</b> type. 
     *       The actual quantization parameters are determined by <b>input</b> and <b>weight</b>.
     *      
     * * <b>stride</b>: movement stride of the convolution kernel in height and width. It is an int array [strideHeight, strideWidth].
     *
     * Parameters:
     *
     * * <b>dilation</b>: dilation size of the convolution kernel in height and width. It is an int array [dilationHeight, dilationWidth].
     *       The value must be greater than or equal to <b>1</b> and cannot exceed the height and width of <b>input</b>.
     * * <b>padMode</b>: padding mode of <b>input</b>. The value is of the int type and can be <b>0</b> (same) or <b>1</b> (valid).
     *       <b>0</b> (same): The height and width of the output are the same as those of the input.
     *       The total padding quantity is calculated horizontally and vertically and evenly distributed to the top, bottom, left, and right if possible. 
     *       Otherwise, the last additional padding will be completed from the bottom and right.
     *       <b>1</b> (valid): The possible maximum height and width of the output will be returned in case of no padding. The excessive pixels will be discarded.
     * * <b>group</b>: number of groups in which the input is divided by <b>in_channel</b>. The value is of the int type. 
     *       If <b>group</b> is <b>1</b>, it is a conventional convolution. If <b>group</b> is greater than <b>1</b> and 
     *       less than or equal to <b>in_channel</b>, it is a group convolution.
     * * <b>outputPads</b>: padding along the height and width of the output tensor. The value is an int or a tuple. 
     *       It can be a single integer to specify the same value for all spatial dimensions. The amount of output 
     *       padding along a dimension must be less than the stride along this dimension.
     *      
     * * <b>activationType</b> is an integer constant which is contained in <b>FuseType</b>.
     *       The specified activation function is called before output.
     *
     * If the input contains the <b>padList</b> parameter:
     *
     * Inputs:
     *
     * * <b>input</b>: input tensor.
     * * <b>weight</b>: convolution weight in [outChannel, kernelHeight, kernelWidth, inChannel/group] format. 
     *       The value of <b>inChannel</b> must be exactly divided by the value of <b>group</b>.      
     * * <b>bias</b>: bias of the convolution. It is an array with a length of <b>[outChannel]</b>. 
     *       In quantization scenarios, the <b>bias</b> parameter does not require quantization parameters. 
     *       The quantization version requires data input of the <b>OH_NN_INT32</b> type. 
     *       The actual quantization parameters are determined by <b>input</b> and <b>weight</b>.
     * 
     * Parameters:
     *
     * * <b>stride</b>: movement stride of the convolution kernel in height and width. It is an int array [strideHeight, strideWidth].
     * * <b>dilation</b>: dilation size of the convolution kernel in height and width. It is an int array [dilationHeight, dilationWidth].
     *       The value must be greater than or equal to <b>1</b> and cannot exceed the height and width of <b>input</b>.
     * * <b>padList</b>: padding around <b>input</b>. It is an int array [top, bottom, left, right].
     * * <b>group</b>: number of groups in which the input is divided by <b>in_channel</b>. The value is of the int type. 
     *       If <b>group</b> is <b>1</b>, it is a conventional convolution. If <b>group</b> is greater than <b>1</b> 
     *       and less than or equal to <b>in_channel</b>, it is a group convolution.
     * * <b>outputPads</b>: padding along the height and width of the output tensor. The value is an int or a tuple. 
     *       It can be a single integer to specify the same value for all spatial dimensions. The amount of output padding 
     *       along a dimension must be less than the stride along this dimension.
     *      
     * * <b>activationType</b> is an integer constant which is contained in <b>FuseType</b>.
     *       The specified activation function is called before output.
     *
     * Outputs:
     *
     * * <b>output</b>: computing result after convolution and transposition.
     */
    OH_NN_OPS_CONV2D_TRANSPOSE = 9,

    /**
     * 2D depthwise separable convolution.
     *
     * If the input contains the <b>padMode</b> parameter:
     *
     * Inputs:
     *
     * * <b>input</b>: input tensor.
     * * <b>weight</b>: convolution weight in [outChannel, kernelHeight, kernelWidth, 1] format. 
     *       <b>outChannel</b> is equal to <b>channelMultiplier</b> multiplied by <b>inChannel</b>.
     * * <b>bias</b>: bias of the convolution. It is an array with a length of <b>[outChannel]</b>. 
     *       In quantization scenarios, the <b>bias</b> parameter does not require quantization parameters. 
     *       The quantization version requires data input of the <b>OH_NN_INT32</b> type. 
     *       The actual quantization parameters are determined by <b>input</b> and <b>weight</b>.
     *
     * Parameters:
     *
     * * <b>stride</b>: movement stride of the convolution kernel in height and width. It is an int array [strideHeight, strideWidth].
     * * <b>dilation</b>: dilation size of the convolution kernel in height and width. It is an int array [dilationHeight, dilationWidth].
     *       The value must be greater than or equal to <b>1</b> and cannot exceed the height and width of <b>input</b>.
     * * <b>padMode</b>: padding mode of <b>input</b>. The value is of the int type and can be <b>0</b> (same) or <b>1</b> (valid).
     *       <b>0</b> (same): The height and width of the output are the same as those of the input. 
     *       The total padding quantity is calculated horizontally and vertically and evenly distributed to the top, bottom, left, and right if possible.
     *       Otherwise, the last additional padding will be completed from the bottom and right.
     *      
     *       <b>1</b> (valid): The possible maximum height and width of the output will be returned in case of no padding. The excessive pixels will be discarded.
     * * <b>activationType</b> is an integer constant which is contained in <b>FuseType</b>.
     *       The specified activation function is called before output.
     *
     * If the input contains the <b>padList</b> parameter:
     *
     * Inputs:
     *
     * * <b>input</b>: input tensor.
     * * <b>weight</b>: convolution weight in [outChannel, kernelHeight, kernelWidth, 1] format. 
     *       <b>outChannel</b> is equal to <b>channelMultiplier</b> multiplied by <b>inChannel</b>.
     * * <b>bias</b>: bias of the convolution. It is an array with a length of <b>[outChannel]</b>. 
     *       In quantization scenarios, the <b>bias</b> parameter does not require quantization parameters. 
     *       The quantization version requires data input of the <b>OH_NN_INT32</b> type. 
     *       The actual quantization parameters are determined by <b>input</b> and <b>weight</b>.
     *
     * Parameters:
     *
     * * <b>stride</b>: movement stride of the convolution kernel in height and width. It is an int array [strideHeight, strideWidth].
     * * <b>dilation</b>: dilation size of the convolution kernel in height and width. It is an int array [dilationHeight, dilationWidth].
     *       The value must be greater than or equal to <b>1</b> and cannot exceed the height and width of <b>input</b>.
     * * <b>padList</b>: padding around <b>input</b>. It is an int array [top, bottom, left, right].
     * * <b>activationType</b> is an integer constant which is contained in <b>FuseType</b>.
     *       The specified activation function is called before output.
     *
     * Outputs:
     *
     * * <b>output</b>: convolution computing result.
     */
    OH_NN_OPS_DEPTHWISE_CONV2D_NATIVE = 10,

    /**
     * Divides two input scalars or tensors.
     *
     * Inputs:
     *
     * * <b>input1</b>: first input, which is a number, a bool, or a tensor whose data type is number or Boolean.
     * * <b>input2</b>: second input, which must meet the following requirements: 
     *       If the first input is a tensor, the second input can be a real number, a Boolean value, or a tensor whose data type is real number or Boolean value.
     *       If the first input is a real number or Boolean value, the second input must be a tensor whose data type is real number or Boolean value.
     *
     * Parameters:
     *
     * * <b>activationType</b> is an integer constant which is contained in <b>FuseType</b>.
     *       The specified activation function is called before output.
     *
     * Outputs:
     *
     * * <b>output</b>: result of dividing <b>input1</b> by <b>input2</b>.
     */
    OH_NN_OPS_DIV = 11,

    /**
     * Sets parameters to perform product (dot product), sum (addition and subtraction), or max (larger value) on the input.
     *
     * Inputs:
     *
     * * <b>input1</b>: first input tensor.
     * * <b>input2</b>: second input tensor.
     *
     * Parameters:
     *
     * * <b>mode</b>: operation mode. The value is an enumerated value.
     *
     * Outputs:
     *
     * * <b>output</b>: computing result, which has the same data type and shape of <b>output</b> and <b>input1</b>.
     */
    OH_NN_OPS_ELTWISE = 12,

    /**
     * Adds an additional dimension to a tensor in the given dimension.
     *
     * Inputs:
     *
     * * <b>input</b>: input tensor.
     * * <b>axis</b>: index of the dimension to be added. The value is of the int32_t type and must be a constant in the range [-dim-1, dim].
     *
     * Outputs:
     *
     * * <b>output</b>: tensor after dimension expansion.
     */
    OH_NN_OPS_EXPAND_DIMS = 13,

    /**
     * Creates a tensor of the specified dimensions and fills it with a scalar.
     *
     * Inputs:
     *
     * * <b>value</b>: scalar used to fill the tensor.
     * * <b>shape</b>: dimensions of the tensor to be created.
     *
     * Outputs:
     *
     * * <b>output</b>: generated tensor, which has the same data type as <b>value</b>. The tensor shape is specified by the <b>shape</b> parameter.
     */
    OH_NN_OPS_FILL = 14,

    /**
     * Full connection. The entire input is used as the feature map for feature extraction.
     *
     * Inputs:
     *
     * * <b>input</b>: full-connection input tensor.
     * * <b>weight</b>: weight tensor for a full connection.
     * * <b>bias</b>: full-connection bias. In quantization scenarios, no quantized parameter is required for this parameter.
     *       If quantization is required, the data must be of the OH_NN_INT32 type. 
     *       The actual quantization parameters are determined by <b>input</b> and <b>weight</b>.
     *
     * Parameters:
     *
     * * <b>activationType</b> is an integer constant which is contained in <b>FuseType</b>.
     *       The specified activation function is called before output.
     *
     * Outputs:
     *
     * * <b>output</b>: computed tensor.
     *
     * If the input contains the <b>axis</b> parameter:
     *
     * Inputs:
     *
     * * <b>input</b>: full-connection input tensor.
     * * <b>weight</b>: weight tensor for a full connection.
     * * <b>bias</b>: full-connection bias. In quantization scenarios, no quantized parameter is required for this parameter.
     *       If quantization is required, the data must be of the OH_NN_INT32 type. The actual quantization parameters
     *       are determined by <b>input</b> and <b>weight</b>.      
     *
     * Parameters:
     *
     * * <b>axis</b>: axis in which the full connection is applied. The specified axis and its following axes are
     *       converted into a 1D tensor for applying the full connection.
     * * <b>activationType</b> is an integer constant which is contained in <b>FuseType</b>.
     *       The specified activation function is called before output.
     *
     * Outputs:
     *
     * * <b>output</b>: computed tensor.
     */
    OH_NN_OPS_FULL_CONNECTION = 15,

    /**
     * Returns the slice of the input tensor based on the specified index and axis.
     *
     * Inputs:
     *
     * * <b>input</b>: tensor to be sliced.
     * * <b>inputIndices</b>: indices of the specified input on the axis. The value is an array of the int type
     *       and must be in the range [0,input.shape[axis]).
     * * <b>axis</b>: axis on which <b>input</b> is sliced. The value is an array with one element of the int32_t type.
     *
     * Outputs:
     *
     * * <b>output</b>: sliced tensor.
     */
    OH_NN_OPS_GATHER = 16,

    /**
     * Calculate the <b>Hswish</b> activation value of the input.
     *
     * Inputs:
     *
     * * An <i>n</i>-dimensional input tensor.
     *
     * Outputs:
     *
     * * <b>output</b>: <i>n</i>-dimensional <b>Hswish</b> activation value. The data type is the same as that of <b>shape</b> and <b>input</b>.
     */
    OH_NN_OPS_HSWISH = 17,

    /**
     * For <b>input1</b> and <b>input2</b>, calculate the result of input1[i]<=input2[i] for each pair of elements,
     * where i is the index of each element in the input tensor.
     *
     * Inputs:
     *
     * * <b>input1</b>, which can be a real number, Boolean value, or tensor whose data type is real number or NN_BOOL.
     * * <b>input2</b>, which can be a real number or a Boolean value if <b>input1</b> is a tensor and must be a tensor
     *       with the data type of real number or NN_BOOL if <b>input1</b> is not a tensor.
     *
     * Outputs:
     *
     * * A tensor of the data type NN_BOOL. When a quantization model is used, the quantization parameters of the output
     *   cannot be omitted. However, values of the quantization parameters do not affect the result.
     */
    OH_NN_OPS_LESS_EQUAL = 18,

    /**
     * Calculate the inner product of <b>input1</b> and <b>input2</b>.
     *
     * Inputs:
     *
     * * <b>input1</b>: <i>n</i>-dimensional input tensor.
     * * <b>input2</b>: <i>n</i>-dimensional input tensor.
     *
     * Parameters:
     *
     * * <b>TransposeX</b>: Boolean value indicating whether to transpose <b>input1</b>.
     * * <b>TransposeY</b>: Boolean value indicating whether to transpose <b>input2</b>.
     *
     * Outputs:
     *
     * * <b>output</b>: inner product obtained after calculation. In case of type!=NN_UNKNOWN, the output data type is
     *       determined by <b>type</b>. In case of type==NN_UNKNOWN, the output data type depends on the data type
     *       converted during computing of <b>inputX</b> and <b>inputY</b>.
     *      
     */
    OH_NN_OPS_MATMUL = 19,

    /**
     * Calculates the maximum of <b>input1</b> and <b>input2</b> element-wise. The inputs of <b>input1</b> and <b>input2</b>
     * comply with the implicit type conversion rules to make the data types consistent. * The inputs must be two tensors or one tensor and one scalar.
     * When the inputs are two tensors, their data types cannot be both NN_BOOL. Their shapes can be broadcast to the same size.
     * When the inputs are one tensor and one scalar, the scalar must be a constant.
     *
     * Inputs:
     *
     * * <b>input1</b>: <i>n</i>-dimensional input tensor of the real number or NN_BOOL type.
     * * <b>input2</b>: <i>n</i>-dimensional input tensor of the real number or NN_BOOL type.
     *
     * Outputs:
     *
     * * <b>output</b>: <i>n</i>-dimensional output tensor. The <b>shape</b> and data type of
     *       <b>output</b> are the same as those of the two inputs with a higher precision.
     */
    OH_NN_OPS_MAXIMUM = 20,

    /**
     * Applies 2D maximum pooling to the input tensor.
     *
     * If the input contains the <b>padMode</b> parameter:
     *
     * Inputs:
     *
     * * <b>input</b>: tensor.
     *
     * Parameters:
     *
     * * <b>kernelSize</b>: kernel size used to obtain the maximum. It is an int array [kernel_height, kernel_width].
     *       The first number indicates the kernel height, and the second number indicates the kernel width.
     * * <b>strides</b> indicates the distance of kernel moving. The value is an int array [stride_height, stride_width].
     *       The first number indicates the moving step in height, and the second number indicates the moving step in width.
     * * <b>padMode</b>: padding mode, which is optional. The value is of the int type and can be <b>0</b> (same)
     *       or <b>1</b> (valid). The nearest neighbor value is used for padding.
     *       <b>0</b> (same): The height and width of the output are the same as those of the input. 
     *       The total padding quantity is calculated horizontally and vertically and evenly distributed to the top, bottom, left, and right if possible.
     *       Otherwise, the last additional padding will be completed from the bottom and right.  
     *       <b>1</b> (valid): The possible maximum height and width of the output will be returned in case of no padding. The excessive pixels will be discarded.
     * * <b>activationType</b> is an integer constant which is contained in <b>FuseType</b>.
     *       The specified activation function is called before output.
     *
     * If the input contains the <b>padList</b> parameter:
     *
     * Inputs:
     *
     * * <b>input</b>: tensor.
     *
     * Parameters:
     *
     * * <b>kernelSize</b>: kernel size used to obtain the maximum. It is an int array [kernel_height, kernel_width].
     *       The first number indicates the kernel height, and the second number indicates the kernel width.
     * * <b>strides</b> indicates the distance of kernel moving. The value is an int array [stride_height, stride_width].
     *       The first number indicates the moving step in height, and the second number indicates the moving step in width.
     * * <b>padList</b>: padding around <b>input</b>. It is an int array [top, bottom, left, right], 
     *       and the nearest neighbor values are used for padding.
     * * <b>activationType</b> is an integer constant which is contained in <b>FuseType</b>.
     *       The specified activation function is called before output.
     *
     * Outputs:
     *
     * * <b>output</b>: tensor obtained after maximum pooling is applied to the input.
     */
    OH_NN_OPS_MAX_POOL = 21,

    /**
     * Multiplies elements in the same positions of <b>inputX</b> and <b>inputY</b> to obtain the output.
     * If <b>inputX</b> and <b>inputY</b> have different shapes, expand them to the same shape
     * through broadcast and then perform multiplication.
     *
     * Inputs:
     *
     * * <b>input1</b>: <i>n</i>-dimensional tensor.
     * * <b>input2</b>: <i>n</i>-dimensional tensor.
     *
     * Parameters:
     *
     * * <b>activationType</b> is an integer constant which is contained in <b>FuseType</b>.
     *       The specified activation function is called before output.
     *
     * Outputs:
     *
     * * Product of each element of <b>input1</b> and <b>input2</b>.
     */
    OH_NN_OPS_MUL = 22,

    /**
     * Generates a one-hot tensor based on the positions specified by <b>indices</b>. The positions specified by <b>indices</b>
     * are determined by <b>on_value</b>, and other positions are determined by <b>off_value</b>.
     *
     * Inputs:
     *
     * * <b>indices</b>: <i>n</i>-dimensional tensor. Each element in <b>indices</b> determines the position of
     *       <b>on_value</b> in each one-hot vector.
     * * <b>depth</b>: integer scalar that determines the depth of the one-hot vector. The value of <b>depth</b>
     *       must be greater than <b>0</b>.
     * * <b>on_value</b>: scalar that specifies a valid value in the one-hot vector.
     * * <b>off_value</b>: scalar that specifies the values of other posistions in the one-hot vector except the valid value.
     *
     * Parameters:
     *
     * * <b>axis</b>: integer scalar that specifies the dimension for inserting the one-hot. Assume that the shape
     *       of <b>indices</b> is [N, C], and the value of <b>depth</b> is D. 
     *       When <b>axis</b> is <b>0</b>, the shape of the output is [D, N, C].
     *       When <b>axis</b> is <b>-1</b>, the shape of the output is [N, C, D].
     *       When <b>axis</b> is <b>1</b>, the shape of the output is [N, D, C].
     *
     * Outputs:
     *
     * * <b>output</b>: (<i>n</i>+1)-dimensional tensor if <b>indices</b> is an <i>n</i>-dimensional tensor.
     *       The output shape is determined by <b>indices</b> and <b>axis</b>.
     */
    OH_NN_OPS_ONE_HOT = 23,

    /**
     * Pads <b>inputX</b> in the specified dimensions.
     *
     * Inputs:
     *
     * * <b>inputX</b>: <i>n</i>-dimensional tensor in [BatchSize, ...] format.
     * * <b>paddings</b>: 2D tensor that specifies the length to pad in each dimension. The shape is [n, 2]. 
     *       For example, <b>paddings[i][0]</b> indicates the number of paddings to be added preceding <b>inputX</b> in the <i>i</i>th dimension.
     *       <b>paddings[i][1]</b> indicates the number of paddings to be added following <b>inputX</b> in the <i>i</i>th dimension.
     *
     * Parameters:
     *
     * * <b>padValues</b>: value to be added to the pad operation. The value is a constant with the same data type as <b>inputX</b>.
     *
     * Outputs:
     *
     * * <b>output</b>: <i>n</i>-dimensional tensor after padding, with the same dimensions and data type as <b>inputX</b>.
     *       The shape is determined by <b>inputX</b> and <b>paddings</b>.
     *       output.shape[i] = input.shape[i] + paddings[i][0]+paddings[i][1]
     */
    OH_NN_OPS_PAD = 24,

    /**
     * Calculates the <b>y</b> power of each element in <b>input</b>. The inputs must be two tensors or one tensor and one scalar.
     * When the inputs are two tensors, their data types cannot be both NN_BOOL, and their shapes must be the same.
     * When the inputs are one tensor and one scalar, the scalar must be a constant.
     *
     * Inputs:
     *
     * * <b>input</b>: real number, Boolean value, or tensor whose data type is real number or NN_BOOL.
     * * <b>y</b>: real number, Boolean value, or tensor whose data type is real number or NN_BOOL.
     *
     * Outputs:
     *
     * * <b>output</b>: tensor, whose shape is determined by the shape of <b>input</b> and <b>y</b> after broadcasting.
     */
    OH_NN_OPS_POW = 25,

    /**
     * Scales a tensor.
     *
     * Inputs:
     *
     * * <b>input</b>: <i>n</i>-dimensional tensor.
     * * <b>scale</b>: scaling tensor.
     * * <b>bias</b>: bias tensor.
     *
     * Parameters:
     *
     * * <b>axis</b>: dimensions to be scaled.
     * * <b>activationType</b> is an integer constant which is contained in <b>FuseType</b>.
     *       The specified activation function is called before output.
     *
     * Outputs:
     *
     * * <b>output</b>: scaled <i>n</i>-dimensional tensor, whose data type is the same as that of <b>input</b> and
     *       shape is determined by <b>axis</b>.
     */
    OH_NN_OPS_SCALE = 26,

    /**
     * Calculates the shape of the input tensor.
     *
     * Inputs:
     *
     * * <b>input</b>: <i>n</i>-dimensional tensor.
     *
     * Outputs:
     *
     * * <b>output</b>: integer array representing the dimensions of the input tensor.
     */
    OH_NN_OPS_SHAPE = 27,

    /**
     * Applies the <b>sigmoid</b> operation to the input tensor.
     *
     * Inputs:
     *
     * * <b>input</b>: <i>n</i>-dimensional tensor.
     *
     * Outputs:
     *
     * * <b>output</b>: result of the <b>sigmoid</b> operation. It is an <i>n</i>-dimensional tensor
     *       with the same data type and shape as <b>input</b>.
     */
    OH_NN_OPS_SIGMOID = 28,

    /**
     * Slices a tensor of the specified size from the input in each dimension.
     *
     * Inputs:
     *
     * * <b>input</b>: <i>n</i>-dimensional input tensor.
     * * <b>begin</b>: start of the slice, which is an array of integers greater than or equal to 0.
     * * <b>size</b>: slice length, which is an array of integers greater than or equal to 0. 
     *       Assume that a dimension is <b>i</b> and 1<=size[i]<=input.shape[i]-begin[i].
     *
     * Outputs:
     *
     * * <b>output</b>: <i>n</i>-dimensional tensor obtained by slicing. 
     *       The <b>TensorType</b>, shape, and size of the output are the same as those of the input.
     */
    OH_NN_OPS_SLICE = 29,

    /**
     * Applies the <b>softmax</b> operation to the input tensor.
     *
     * Inputs:
     *
     * * <b>input</b>: <i>n</i>-dimensional input tensor.
     *
     * Parameters:
     *
     * * <b>axis</b>: dimension in which the <b>softmax</b> operation is performed.
     *       The value is of the int64 type. It is an integer in the range [-n, n).
     *
     * Outputs:
     *
     * * <b>output</b>: result of the <b>softmax</b> operation. It is an <i>n</i>-dimensional tensor with
     *       the same data type and shape as <b>input</b>.
     */
    OH_NN_OPS_SOFTMAX = 30,

    /**
     * Divides a 4D tensor into small blocks and combines these blocks in the original batch.
     * The number of blocks is <b>blockShape[0]</b> multiplied by <b>blockShape[1]</b>.
     *
     * Inputs:
     *
     * * <b>input</b>: 4D tensor.
     *
     * Parameters:
     *
     * * <b>blockShape</b>: a pair of integers. Each of them is greater than or equal to <b>1</b>.
     * * <b>paddings</b>: a pair of arrays. Each of them consists of two integers. The four integers that form <b>paddings</b> 
     *       must be greater than or equal to <b>0</b>. <b>paddings[0][0]</b> and <b>paddings[0][1]</b>
     *       specify the number of paddings in the third dimension, and <b>paddings[1][0]</b> and <b>paddings[1][1]</b>
     *       specify the number of paddings in the fourth dimension.
     *
     * Outputs:
     *
     * * <b>output</b>: 4D tensor with the same data type as <b>input</b>. The shape is determined by <b>input</b>,
     *       <b>blockShape</b>, and <b>paddings</b>. Assume that the input shape is [n,c,h,w], then:
     *       output.shape[0] = n * blockShape[0] * blockShape[1]
     *       output.shape[1] = c
     *       output.shape[2] = (h + paddings[0][0] + paddings[0][1]) / blockShape[0]
     *       output.shape[3] = (w + paddings[1][0] + paddings[1][1]) / blockShape[1]
     *       (h + paddings[0][0] + paddings[0][1]) and (w + paddings[1][0] + paddings[1][1]) is exactly divisible by 
     *       (h + paddings[0][0] + paddings[0][1]) and (w + paddings[1][0] + paddings[1][1]).
     *      
     */
    OH_NN_OPS_SPACE_TO_BATCH_ND = 31,

    /**
     * Splits the input into multiple tensors along the axis dimension. The number of tensors is specified by <b>outputNum</b>.
     *
     * Inputs:
     *
     * * <b>input</b>: <i>n</i>-dimensional tensor.
     *
     * Parameters:
     *
     * * <b>outputNum</b>: number of output tensors. The data type is long.
     * * <b>size_splits</b>: size of each tensor split from the input. The value is a 1D tensor of the int type.
     *       If <b>size_splits</b> is empty, the input will be evenly split into tensors of the same size. In this case,
     *       <b>input.shape[axis]</b> can be exactly divisible by <b>outputNum</b>.
     *       If <b>size_splits</b> is not empty, the sum of all its elements must be equal to <b>input.shape[axis]</b>.
     * * <b>axis</b>: splitting dimension of the int type.
     *
     * Outputs:
     *
     * * <b>outputs</b>: array of <i>n</i>-dimensional tensors, with the same data type and dimensions. 
     *       The data type of each tensor is the same as that of <b>input</b>.
     */
    OH_NN_OPS_SPLIT = 32,

    /**
     * Calculates the square root of a tensor.
     *
     * Inputs:
     *
     * * <b>input</b>: <i>n</i>-dimensional tensor.
     *
     * Outputs:
     *
     * * <b>output</b>: square root of the input. It is an <i>n</i>-dimensional tensor with the same data type and shape as <b>input</b>.
     */
    OH_NN_OPS_SQRT = 33,

    /**
     * Calculates the square of the difference between two tensors. The <b>SquaredDifference</b> operator supports tensor and tensor subtraction.
     * If two tensors have different <b>TensorTypes</b>, the Sub operator converts the low-precision tensor to a high-precision one.
     * If two tensors have different shapes, the two tensors can be extended to tensors with the same shape through broadcast.
     *
     * Inputs:
     *
     * * <b>input1</b>: minuend, which is a tensor of the NN_FLOAT16, NN_FLOAT32, NN_INT32, or NN_BOOL type.
     * * <b>input2</b>: subtrahend, which is a tensor of the NN_FLOAT16, NN_FLOAT32, NN_INT32, or NN_BOOL type.
     *
     * Outputs:
     *
     * * <b>output</b>: square of the difference between two inputs. The output shape is determined
     *       by<b>input1</b> and <b>input2</b>. If they have the same shape, the output tensor has the same shape as them.
     *       If they have different shapes, perform the broadcast operation on <b>input1</b> and <b>input2</b> and perform subtraction.
     *       <b>TensorType</b> of the output is the same as that of the input tensor with higher precision.
     */
    OH_NN_OPS_SQUARED_DIFFERENCE = 34,

    /**
     * Removes the dimension with a length of 1 from the specified axis. The int8 quantization input is supported.
     * Assume that the input shape is [2, 1, 1, 2, 2] and axis is [0,1], the output shape is [2, 1, 2, 2],
     * which means the dimension whose length is 0 between dimensions 0 and dimension 1 is removed.
     *
     * Inputs:
     *
     * * <b>input</b>: <i>n</i>-dimensional tensor.
     *
     * Parameters:
     *
     * * <b>axis</b>: dimension to be removed. The value is of int64_t type and can be an integer in the range [-n, n) or an array.
     *
     * Outputs:
     *
     * * <b>output</b>: output tensor.
     */
    OH_NN_OPS_SQUEEZE = 35,

    /**
     * Stacks multiple tensors along the specified axis. If each tensor has <i>n</i> dimensions before stacking,
     * the output tensor will have <i>n</i>+1 dimensions.
     *
     * Inputs:
     *
     * * <b>input</b>: input for stacking, which can contain multiple <i>n</i>-dimensional tensors.
     *       Each of them must have the same shape and type.
     *
     * Parameters:
     *
     * * <b>axis</b>: dimension for tensor stacking, which is an integer. The value range is [-(n+1),(n+1)),
     *       which means a negative number is allowed.
     *
     * Outputs:
     *
     * * <b>output</b>: stacking result of the input along the axis dimension. The value is an <i>n</i>+1-dimensional tensor
     *       and has the same <b>TensorType</b> as the input.
     */
    OH_NN_OPS_STACK = 36,

    /**
     * Slices a tensor with the specified stride.
     *
     * Inputs:
     *
     * * <b>input</b>: <i>n</i>-dimensional input tensor.
     * * <b>begin</b>: start of slicing, which is a 1D tensor. The length of <b>begin</b> is <i>n</i>. 
     *       <b>begin[i]</b> specifies the start of slicing in the <i>i</i>th dimension.
     * * <b>end</b>: end of slicing, which is a 1D tensor. The length of <b>end</b> is <i>n</i>. 
     *       <b>end[i]</b> specifies the end of slicing in the <i>i</i>th dimension.
     * * <b>strides</b>: slicing stride, which is a 1D tensor. The length of <b>strides</b> is <i>n</i>. 
     *       strides[i] specifies the stride at which the tensor is sliced in the <i>i</i>th dimension.
     *
     * Parameters:
     *
     * * <b>beginMask</b>: an integer used to mask <b>begin</b>. <b>beginMask</b> is represented in binary code. 
     *       In case of binary(beginMask)[i]==1, for the <i>i</i>th dimension, elements are sliced from the first element 
     *       at <b>strides[i]</b> until the end[i]-1 element.
     *      
     * * <b>endMask</b>: an integer used to mask <b>end</b>. <b>endMask</b> is represented in binary code. 
     *       In case of binary(endMask)[i]==1, elements are sliced from the element at the <b>begin[i]</b> position 
     *       in the <i>i</i>th dimension until the tensor boundary at <b>strides[i]</b>.
     *      
     * * <b>ellipsisMask</b>: integer used to mask <b>begin</b> and <b>end</b>. <b>ellipsisMask</b> is represented in binary code. 
     *       In case of binary(ellipsisMask)[i]==1, elements are sliced from the first element at <b>strides[i]</b> in the <i>i</i>th dimension
     *       until the tensor boundary. Only one bit of <b>binary(ellipsisMask)</b> can be a non-zero value.
     *      
     * * <b>newAxisMask</b>: new dimension, which is an integer. <b>newAxisMask</b> is represented in binary code. 
     *       In case of binary(newAxisMask)[i]==1, a new dimension whose length is 1 is inserted into the <i>i</i>th dimension.
     * * <b>shrinkAxisMask</b>: shrinking dimension, which is an integer. * <b>shrinkAxisMask</b> is represented in binary code.
     *       In the case of binary(shrinkAxisMask)[i]==1, all elements in the <i>i</i>th dimension will be discarded, 
     *       and the length of the <i>i</i>th dimension is shrunk to <b>1</b>.
     *
     * Outputs:
     *
     * * A tensor, with the same data type as <b>input</b>. The number of dimensions of the output tensor is rank(input[0])+1.
     */
    OH_NN_OPS_STRIDED_SLICE = 37,

    /**
     * Calculates the difference between two tensors.
     *
     * Inputs:
     *
     * * <b>input1</b>: minuend, which is a tensor.
     * * <b>input2</b>: subtrahend, which is a tensor.
     *
     * Parameters:
     *
     * * <b>activationType</b> is an integer constant which is contained in <b>FuseType</b>.
     *       The specified activation function is called before output.
     *
     * Outputs:
     *
     * * <b>output</b>: difference between the two tensors. The output shape is determined by<b>input1</b> and <b>input2</b>.
     *       If they have the same shape, the output tensor has the same shape as them.
     *       If they have different shapes, perform the broadcast operation on <b>input1</b> and <b>input2</b> and perform subtraction.
     *       <b>TensorType</b> of the output is the same as that of the input tensor with higher precision.
     */
    OH_NN_OPS_SUB = 38,

    /**
     * Computes hyperbolic tangent of the input tensor.
     *
     * Inputs:
     *
     * * <b>input</b>: <i>n</i>-dimensional tensor.
     *
     * Outputs:
     *
     * * <b>output</b>: hyperbolic tangent of the input. The <b>TensorType</b> and tensor shape are the same as those of the input.
     */
    OH_NN_OPS_TANH = 39,

    /**
     * Copies a tensor the specified times.
     *
     * Inputs:
     * * <b>input</b>: <i>n</i>-dimensional tensor.
     * * <b>multiples</b>: number of times that the input tensor is copied in each dimension. The value is a 1D tensor.
     *       The length <i>m</i> is not less than the number of dimensions, that is, <i>n</i>.
     *
     * Outputs:
     * * An <i>m</i>-dimensional tensor whose <b>TensorType</b> is the same as that of the input. If <b>input</b> and
     *       <b>multiples</b> have the same length, <b>input</b> and <b>output</b> have the same number of dimensions.
     *       If the length of <b>multiples</b> is greater than <i>n</i>, 1 is used to fill the input dimension, 
     *       and then the input is copied in each dimension the specified times to obtain the <i>m</i>-dimensional tensor.
     */
    OH_NN_OPS_TILE = 40,

    /**
     * Transposes data of <b>input 0</b> based on <b>permutation</b>.
     *
     * Inputs:
     *
     * * <b>input</b>: <i>n</i>-dimensional tensor to be transposed.
     * * <b>permutation</b>: The value is a 1D tensor whose length is the same as the number of dimensions of <b>input 0</b>.
     *
     * Outputs:
     *
     * * <b>output</b>: <i>n</i>-dimensional tensor. <b>TensorType</b> of <b>output 0</b> is the same as that of <b>input 0</b>,
     *       and the output shape is determined by the shape and <b>permutation</b> of <b>input 0</b>.
     */
    OH_NN_OPS_TRANSPOSE = 41,

    /**
     * Calculates the average value in the specified dimension. If <b>keepDims</b> is set to <b>false</b>, the number of dimensions
     * is reduced for the input; if <b>keepDims</b> is set to <b>true</b>, the number of dimensions is retained.
     *
     * Inputs:
     *
     * * <b>input</b>: <i>n</i>-dimensional input tensor, where <i>n</i> is less than 8.
     * * <b>axis</b>: dimension used to calculate the average value. The value is a 1D tensor. The value range of each element in <b>axis</b> is [–n, n).
     *
     * Parameters:
     *
     * * <b>keepDims</b>: indicates whether to retain the dimension. The value is a Boolean value.
     *
     * Outputs:
     *
     * * <b>output</b>: <i>m</i>-dimensional output tensor whose data type is the same as that of the input. If <b>keepDims</b> is
     *       <b>false</b>, m==n. If <b>keepDims</b> is <b>true</b>, m<n.
     */
    OH_NN_OPS_REDUCE_MEAN = 42,

    /**
     * The Bilinear method is used to deform the input based on the given parameters.
     *
     * Inputs:
     *
     * * <b>input</b>: 4D input tensor. Each element in the input cannot be less than 0. The input layout must be [batchSize, height, width, channels].
     *
     * Parameters:
     *
     * * <b>newHeight</b>: resized height of the 4D tensor.
     * * <b>newWidth</b>: resized width of the 4D tensor.
     * * <b>preserveAspectRatio</b>: indicates whether to maintain the height/width ratio of <b>input</b> after resizing.
     * * <b>coordinateTransformMode</b>: coordinate transformation method used by the resize operation. The value is an int32 integer.
     *       Currently, the following methods are supported:
     * * <b>excludeOutside</b>: an int64 floating point number. When its value is <b>1</b>, the sampling weight of the part that
     *       exceeds the boundary of <b>input</b> is set to <b>0</b>, and other weights are normalized.
     *
     * Outputs:
     *
     * * <b>output</b>: <i>n</i>-dimensional tensor, with the same shape and data type as <b>input</b>. 
     */
    OH_NN_OPS_RESIZE_BILINEAR = 43,

    /**
     * Calculates the reciprocal of the square root of a tensor.
     *
     * Inputs:
     *
     * * <b>input</b>: <i>n</i>-dimensional tensor, where <i>n</i> is less than 8. Each element of the tensor cannot be less than 0.
     *
     * Outputs:
     *
     * * <b>output</b>: <i>n</i>-dimensional tensor, with the same shape and data type as <b>input</b>.
     */
    OH_NN_OPS_RSQRT = 44,

    /**
     * Reshapes a tensor.
     *
     * Inputs:
     *
     * * <b>input</b>: <i>n</i>-dimensional input tensor.
     * * <b>InputShape</b>: shape of the output tensor. The value is a 1D constant tensor.
     *
     * Outputs:
     *
     * * <b>output</b>: tensor whose data type is the same as that of <b>input</b> and shape is determined by <b>InputShape</b>.
     */
    OH_NN_OPS_RESHAPE = 45,

    /**
     * Calculates the PReLU activation value of <b>input</b> and <b>weight</b>.
     *
     * Inputs:
     *
     * * <b>input</b>: <i>n</i>-dimensional tensor. If <i>n</i> is greater than or equal to 2, <b>inputX</b> must be [BatchSize, ..., Channels]. 
     *       The second dimension is the number of channels.
     * * <b>weight</b>: 1D tensor. The length of <b>weight</b> must be 1 or equal to the number of channels. If the length of <b>weight</b> is 1, 
     *       all channels share the same weight.
     *       If the length of <b>weight</b> is equal to the number of channels, each channel exclusively has a weight. 
     *       If <i>n</i> is less than 2 for <b>inputX</b>, the <b>weight</b> length must be 1.
     *
     * Outputs:
     *
     * * <b>output</b>: PReLU activation value of <b>x</b>, with the same shape and data type as <b>inputX</b>.
     */
    OH_NN_OPS_PRELU = 46,

    /**
     * Calculates the Relu activation value of <b>input</b>.
     *
     * Inputs:
     *
     * * <b>input</b>: <i>n</i>-dimensional input tensor.
     *
     * Outputs:
     *
     * * <b>output</b>: <i>n</i>-dimensional tensor, with the same data type and shape as the input tensor.
     */
    OH_NN_OPS_RELU = 47,

    /**
     * Calculates the Relu6 activation value of the input, that is, calculate min(max(x, 0), 6) for each element x in the input.
     *
     * Inputs:
     *
     * * <b>input</b>: <i>n</i>-dimensional input tensor.
     *
     * Outputs:
     *
     * * <b>output</b>: <i>n</i>-dimensional Relu6 tensor, with the same data type and shape as the input tensor.
     */
    OH_NN_OPS_RELU6 = 48,

    /**
     * Applies layer normalization for a tensor from the specified axis.
     *
     * Inputs:
     *
     * * <b>input</b>: <i>n</i>-dimensional input tensor.
     * * <b>gamma</b>: <i>m</i>-dimensional tensor. The dimensions of <b>gamma</b> must be the same as
     *       the shape of the part of the input tensor to normalize.
     * * <b>beta</b>: <i>m</i>-dimensional tensor with the same shape as <b>gamma</b>.
     *
     * Parameters:
     *
     * * <b>beginAxis</b> is an NN_INT32 scalar that specifies the axis from which normalization starts. The value range is [1, rank(input)).
     * * <b>epsilon</b> is a scalar of NN_FLOAT32. It is a tiny amount in the normalization formula. The common value is 1e-7.
     *
     * Outputs:
     *
     * * <b>output</b>: <i>n</i>-dimensional tensor, with the same data type and shape as the input tensor.
     */
    OH_NN_OPS_LAYER_NORM = 49,

    /**
     * Calculates the accumulated value for a tensor along the specified dimension.
     *
     * Inputs:
     *
     * * <b>input</b>: <i>n</i>-dimensional input tensor, where <i>n</i> is less than 8.
     * * <b>axis</b>: dimension used to calculate the product. The value is a 1D tensor. The value range of each element in <b>axis</b> is [–n, n).
     *
     * Parameters:
     *
     * * <b>keepDims</b>: indicates whether to retain the dimension. The value is a Boolean value.
     *       When its value is <b>true</b>, the number of output dimensions is the same as that of the input.
     *       When its value is <b>false</b>, the number of output dimensions is reduced.
     *
     * Outputs:
     *
     * * <b>output</b>: <i>m</i>-dimensional output tensor whose data type is the same as that of the input.
     *       If <b>keepDims</b> is <b>false</b>, m==n. If <b>keepDims</b> is <b>true</b>, m<n.
     */
    OH_NN_OPS_REDUCE_PROD = 50,

    /**
     * Operates the logical OR in the specified dimension. If <b>keepDims</b> is set to <b>false</b>, 
     * the number of dimensions is reduced for the input; if <b>keepDims</b> is set to <b>true</b>, the number of dimensions is retained.
     *
     * Inputs:
     *
     * * A <i>n</i>-dimensional input tensor, where <i>n</i> is less than 8.
     * * A 1D tensor specifying the dimension used to operate the logical OR. The value range of each element in <b>axis</b> is [–n, n).
     *
     * Parameters:
     *
     * * <b>keepDims</b>: indicates whether to retain the dimension. The value is a Boolean value.
     *
     * Outputs:
     * * <b>output</b>: <i>m</i>-dimensional output tensor whose data type is the same as that of the input. 
     *       If <b>keepDims</b> is <b>false</b>, m==n. If <b>keepDims</b> is <b>true</b>, m<n.
     */
    OH_NN_OPS_REDUCE_ALL = 51,

    /**
     * Converts the data type.
     *
     * Inputs:
     *
     * * <b>input</b>: <i>n</i>-dimensional tensor.
     *
     * Parameters:
     *
     * * <b>src_t</b>: data type of the input.
     * * <b>dst_t</b>: data type of the output.
     *
     * Outputs:
     *
     * * <b>output</b>: <i>n</i>-dimensional tensor. The data type is determined by <b>input2</b>. 
     *       The output shape is the same as the input shape.
     */
    OH_NN_OPS_QUANT_DTYPE_CAST = 52,

    /**
     * Obtains the values and indices of the largest <i>k</i> entries in the last dimension.
     *
     * Inputs:
     *
     * * <b>input</b>: <i>n</i>-dimensional tensor.
     * * <b>input</b> <i>k</i>: first <i>k</i> records of data and their indices.
     *
     * Parameters:
     *
     * * <b>sorted</b>: order of sorting. The value <b>true</b> means descending and <b>false</b> means ascending.
     *
     * Outputs:
     *
     * * <b>output0</b>: largest <i>k</i> elements in each slice of the last dimension.
     * * <b>output1</b>: index of the value in the last dimension of the input.
     */
    OH_NN_OPS_TOP_K = 53,

    /**
     * Returns the index of the maximum tensor value across axes.
     *
     * Inputs:
     *
     * * <b>input</b>: <i>n</i>-dimensional tensor (N, ∗), where ∗ means any number of additional dimensions.
     *
     * Parameters:
     *
     * * <b>axis</b>: dimension for calculating the index of the maximum.
     * * <b>keep_dims</b>: indicates whether to maintain the input tensor dimension. The value is a Boolean value.
     *
     * Outputs:
     * * <b>output</b>: index of the maximum input tensor on the axis. The value is a tensor.
     */
    OH_NN_OPS_ARG_MAX = 54,

    /**
     * Adds a dimension based on the value of <b>axis</b>.
     *
     * Inputs:
     * * <b>input</b>: <i>n</i>-dimensional tensor.
     *
     * Parameters:
     *
     * * <b>axis</b>: dimension to be added. The value of <b>axis</b> can be an integer or an array of integers. 
     *       The value range of the integer is [-n, n).
     *
     * Outputs:
     * * <b>output</b>: output tensor.
     */
    OH_NN_OPS_UNSQUEEZE = 55,

    /**
     * Gaussian error linear unit activation function. The int quantization input is not supported. output=0.5∗input∗(1+tanh(input/2)) 
     *
     * Inputs:
     * * An <i>n</i>-dimensional input tensor.
     *
     * Outputs:
     * * <b>output</b>: <i>n</i>-dimensional tensor, with the same data type and shape as the input tensor.
     */
    OH_NN_OPS_GELU = 56,
} OH_NN_OperationType;

/**
 * @brief Enumerates the tensor data types.
 *
 * Tensors are usually used to set the input, output, and operator parameters of a model. When a tensor is used 
 * as the input or output of a model (or operator), set the tensor type to {@link OH_NN_TENSOR}. 
 * When the tensor is used as an operator parameter, select an enumerated value other than {@link OH_NN_TENSOR} as the tensor type.
 * Assume that the <b>pad</b> parameter of the {@link OH_NN_OPS_CONV2D} operator is being set. 
 * You need to set the <b>type</b> attribute of the {@link OH_NN_Tensor} instance to {@link OH_NN_CONV2D_PAD}.
 * The settings of other operator parameters are similar. The enumerated values are named
 * in the format OH_NN_{<i>Operator name</i>}_{<i>Attribute name</i>}.
 *
 * @since 9
 * @version 1.0
 */
typedef enum {
    /** This enumerated value is used when the tensor is used as the input or output of a model (or operator). */
    OH_NN_TENSOR = 0,

    /** This enumerated value is used when the tensor is used as the <b>activationType</b> parameter of the Add operator. */
    OH_NN_ADD_ACTIVATIONTYPE = 1,

    /** This enumerated value is used when the tensor is used as the <b>kernel_size</b> parameter of the AvgPool operator. */
    OH_NN_AVG_POOL_KERNEL_SIZE = 2,
    /** This enumerated value is used when the tensor is used as the <b>stride</b> parameter of the AvgPool operator. */
    OH_NN_AVG_POOL_STRIDE = 3,
    /** This enumerated value is used when the tensor is used as the <b>pad_mode</b> parameter of the AvgPool operator. */
    OH_NN_AVG_POOL_PAD_MODE = 4,
    /** This enumerated value is used when the tensor is used as the <b>pad</b> parameter of the AvgPool operator. */
    OH_NN_AVG_POOL_PAD = 5,
    /** This enumerated value is used when the tensor is used as the <b>activation_type</b> parameter of the AvgPool operator. */
    OH_NN_AVG_POOL_ACTIVATION_TYPE = 6,

    /** This enumerated value is used when the tensor is used as the <b>eosilon</b> parameter of the BatchNorm operator. */
    OH_NN_BATCH_NORM_EPSILON = 7,

    /** This enumerated value is used when the tensor is used as the <b>blockSize</b> parameter of the BatchToSpaceND operator. */
    OH_NN_BATCH_TO_SPACE_ND_BLOCKSIZE = 8,
    /** This enumerated value is used when the tensor is used as the <b>crops</b> parameter of the BatchToSpaceND operator. */
    OH_NN_BATCH_TO_SPACE_ND_CROPS = 9,

    /** This enumerated value is used when the tensor is used as the <b>axis</b> parameter of the Concat operator. */
    OH_NN_CONCAT_AXIS = 10,

    /** This enumerated value is used when the tensor is used as the <b>strides</b> parameter of the Conv2D operator. */
    OH_NN_CONV2D_STRIDES = 11,
    /** This enumerated value is used when the tensor is used as the <b>pad</b> parameter of the Conv2D operator. */
    OH_NN_CONV2D_PAD = 12,
    /** This enumerated value is used when the tensor is used as the <b>dilation</b> parameter of the Conv2D operator. */
    OH_NN_CONV2D_DILATION = 13,
    /** This enumerated value is used when the tensor is used as the <b>padMode</b> parameter of the Conv2D operator. */
    OH_NN_CONV2D_PAD_MODE = 14,
    /** This enumerated value is used when the tensor is used as the <b>activationType</b> parameter of the Conv2D operator. */
    OH_NN_CONV2D_ACTIVATION_TYPE = 15,
    /** This enumerated value is used when the tensor is used as the <b>group</b> parameter of the Conv2D operator. */
    OH_NN_CONV2D_GROUP = 16,

    /** This enumerated value is used when the tensor is used as the <b>strides</b> parameter of the Conv2DTranspose operator. */
    OH_NN_CONV2D_TRANSPOSE_STRIDES = 17,
    /** This enumerated value is used when the tensor is used as the <b>pad</b> parameter of the Conv2DTranspose operator. */
    OH_NN_CONV2D_TRANSPOSE_PAD = 18,
    /** This enumerated value is used when the tensor is used as the <b>dilation</b> parameter of the Conv2DTranspose operator. */
    OH_NN_CONV2D_TRANSPOSE_DILATION = 19,
    /** This enumerated value is used when the tensor is used as the <b>outputPaddings</b> parameter of the Conv2DTranspose operator. */
    OH_NN_CONV2D_TRANSPOSE_OUTPUT_PADDINGS = 20,
    /** This enumerated value is used when the tensor is used as the <b>padMode</b> parameter of the Conv2DTranspose operator. */
    OH_NN_CONV2D_TRANSPOSE_PAD_MODE = 21,
    /** This enumerated value is used when the tensor is used as the <b>activationType</b> parameter of the Conv2DTranspose operator. */
    OH_NN_CONV2D_TRANSPOSE_ACTIVATION_TYPE = 22,
    /** This enumerated value is used when the tensor is used as the <b>group</b> parameter of the Conv2DTranspose operator. */
    OH_NN_CONV2D_TRANSPOSE_GROUP = 23,

    /** This enumerated value is used when the tensor is used as the <b>strides</b> parameter of the DepthwiseConv2dNative operator. */
    OH_NN_DEPTHWISE_CONV2D_NATIVE_STRIDES = 24,
    /** This enumerated value is used when the tensor is used as the <b>pad</b> parameter of the DepthwiseConv2dNative operator. */
    OH_NN_DEPTHWISE_CONV2D_NATIVE_PAD = 25,
    /** This enumerated value is used when the tensor is used as the <b>dilation</b> parameter of the DepthwiseConv2dNative operator. */
    OH_NN_DEPTHWISE_CONV2D_NATIVE_DILATION = 26,
    /** This enumerated value is used when the tensor is used as the <b>padMode</b> parameter of the DepthwiseConv2dNative operator. */
    OH_NN_DEPTHWISE_CONV2D_NATIVE_PAD_MODE = 27,
    /** This enumerated value is used when the tensor is used as the <b>activationType</b> parameter of the DepthwiseConv2dNative operator. */
    OH_NN_DEPTHWISE_CONV2D_NATIVE_ACTIVATION_TYPE = 28,

    /** This enumerated value is used when the tensor is used as the <b>activationType</b> parameter of the Div operator. */
    OH_NN_DIV_ACTIVATIONTYPE = 29,

    /** This enumerated value is used when the tensor is used as the <b>mode</b> parameter of the Eltwise operator. */
    OH_NN_ELTWISE_MODE = 30,

    /** This enumerated value is used when the tensor is used as the <b>axis</b> parameter of the FullConnection operator. */
    OH_NN_FULL_CONNECTION_AXIS = 31,
    /** This enumerated value is used when the tensor is used as the <b>activationType</b> parameter of the FullConnection operator. */
    OH_NN_FULL_CONNECTION_ACTIVATIONTYPE = 32,

    /** This enumerated value is used when the tensor is used as the <b>transposeA</b> parameter of the Matmul operator. */
    OH_NN_MATMUL_TRANSPOSE_A = 33,
    /** This enumerated value is used when the tensor is used as the <b>transposeB</b> parameter of the Matmul operator. */
    OH_NN_MATMUL_TRANSPOSE_B = 34,
    /** This enumerated value is used when the tensor is used as the <b>activationType</b> parameter of the Matmul operator. */
    OH_NN_MATMUL_ACTIVATION_TYPE = 35,

    /** This enumerated value is used when the tensor is used as the <b>kernel_size</b> parameter of the MaxPool operator. */
    OH_NN_MAX_POOL_KERNEL_SIZE = 36,
    /** This enumerated value is used when the tensor is used as the <b>stride</b> parameter of the MaxPool operator. */
    OH_NN_MAX_POOL_STRIDE = 37,
    /** This enumerated value is used when the tensor is used as the <b>pad_mode</b> parameter of the MaxPool operator. */
    OH_NN_MAX_POOL_PAD_MODE = 38,
    /** This enumerated value is used when the tensor is used as the <b>pad</b> parameter of the MaxPool operator. */
    OH_NN_MAX_POOL_PAD = 39,
    /** This enumerated value is used when the tensor is used as the <b>activation_type</b> parameter of the MaxPool operator. */
    OH_NN_MAX_POOL_ACTIVATION_TYPE = 40,

    /** This enumerated value is used when the tensor is used as the <b>activationType</b> parameter of the Mul operator. */
    OH_NN_MUL_ACTIVATION_TYPE = 41,

    /** This enumerated value is used when the tensor is used as the <b>axis</b> parameter of the OneHot operator. */
    OH_NN_ONE_HOT_AXIS = 42,

    /** This enumerated value is used when the tensor is used as the <b>constant_value</b> parameter of the Pad operator. */
    OH_NN_PAD_CONSTANT_VALUE = 43,

    /** This enumerated value is used when the tensor is used as the <b>activationType</b> parameter of the Scale operator. */
    OH_NN_SCALE_ACTIVATIONTYPE = 44,
    /** This enumerated value is used when the tensor is used as the <b>axis</b> parameter of the Scale operator. */
    OH_NN_SCALE_AXIS = 45,

    /** This enumerated value is used when the tensor is used as the <b>axis</b> parameter of the Softmax operator. */
    OH_NN_SOFTMAX_AXIS = 46,

    /** This enumerated value is used when the tensor is used as the <b>BlockShape</b> parameter of the SpaceToBatchND operator. */
    OH_NN_SPACE_TO_BATCH_ND_BLOCK_SHAPE = 47,
    /** This enumerated value is used when the tensor is used as the <b>Paddings</b> parameter of the SpaceToBatchND operator. */
    OH_NN_SPACE_TO_BATCH_ND_PADDINGS = 48,

    /** This enumerated value is used when the tensor is used as the <b>Axis</b> parameter of the Split operator. */
    OH_NN_SPLIT_AXIS = 49,
    /** This enumerated value is used when the tensor is used as the <b>OutputNum</b> parameter of the Split operator. */
    OH_NN_SPLIT_OUTPUT_NUM = 50,
    /** This enumerated value is used when the tensor is used as the <b>SizeSplits</b> parameter of the Split operator. */
    OH_NN_SPLIT_SIZE_SPLITS = 51,

    /** This enumerated value is used when the tensor is used as the <b>Axis</b> parameter of the Squeeze operator. */
    OH_NN_SQUEEZE_AXIS = 52,

    /** This enumerated value is used when the tensor is used as the <b>Axis</b> parameter of the Stack operator. */
    OH_NN_STACK_AXIS = 53,

    /** This enumerated value is used when the tensor is used as the <b>BeginMask</b> parameter of the StridedSlice operator. */
    OH_NN_STRIDED_SLICE_BEGIN_MASK = 54,
    /** This enumerated value is used when the tensor is used as the <b>EndMask</b> parameter of the StridedSlice operator. */
    OH_NN_STRIDED_SLICE_END_MASK = 55,
    /** This enumerated value is used when the tensor is used as the <b>EllipsisMask</b> parameter of the StridedSlice operator. */
    OH_NN_STRIDED_SLICE_ELLIPSIS_MASK = 56,
    /** This enumerated value is used when the tensor is used as the <b>NewAxisMask</b> parameter of the StridedSlice operator. */
    OH_NN_STRIDED_SLICE_NEW_AXIS_MASK = 57,
    /** This enumerated value is used when the tensor is used as the <b>ShrinkAxisMask</b> parameter of the StridedSlice operator. */
    OH_NN_STRIDED_SLICE_SHRINK_AXIS_MASK = 58,

    /** This enumerated value is used when the tensor is used as the <b>ActivationType</b> parameter of the Sub operator. */
    OH_NN_SUB_ACTIVATIONTYPE = 59,

    /** This enumerated value is used when the tensor is used as the <b>keep_dims</b> parameter of the ReduceMean operator. */
    OH_NN_REDUCE_MEAN_KEEP_DIMS = 60,

    /** This enumerated value is used when the tensor is used as the <b>new_height</b> parameter of the ResizeBilinear operator. */
    OH_NN_RESIZE_BILINEAR_NEW_HEIGHT = 61,
    /** This enumerated value is used when the tensor is used as the <b>new_width</b> parameter of the ResizeBilinear operator. */
    OH_NN_RESIZE_BILINEAR_NEW_WIDTH = 62,
    /** This enumerated value is used when the tensor is used as the <b>preserve_aspect_ratio</b> parameter of the ResizeBilinear operator. */
    OH_NN_RESIZE_BILINEAR_PRESERVE_ASPECT_RATIO = 63,
    /** This enumerated value is used when the tensor is used as the <b>coordinate_transform_mode</b> parameter of the ResizeBilinear operator. */
    OH_NN_RESIZE_BILINEAR_COORDINATE_TRANSFORM_MODE = 64,
    /** This enumerated value is used when the tensor is used as the <b>exclude_outside</b> parameter of the ResizeBilinear operator. */
    OH_NN_RESIZE_BILINEAR_EXCLUDE_OUTSIDE = 65,

    /** This enumerated value is used when the tensor is used as the <b>beginNormAxis</b> parameter of the LayerNorm operator. */
    OH_NN_LAYER_NORM_BEGIN_NORM_AXIS = 66,
    /** This enumerated value is used when the tensor is used as the <b>epsilon</b> parameter of the LayerNorm operator. */
    OH_NN_LAYER_NORM_EPSILON = 67,
    /** This enumerated value is used when the tensor is used as the <b>beginParamsAxis</b> parameter of the LayerNorm operator. */
    OH_NN_LAYER_NORM_BEGIN_PARAM_AXIS = 68,
    /** This enumerated value is used when the tensor is used as the <b>elementwiseAffine</b> parameter of the LayerNorm operator. */
    OH_NN_LAYER_NORM_ELEMENTWISE_AFFINE = 69,

    /** This enumerated value is used when the tensor is used as the <b>keep_dims</b> parameter of the ReduceProd operator. */
    OH_NN_REDUCE_PROD_KEEP_DIMS = 70,

    /** This enumerated value is used when the tensor is used as the <b>keep_dims</b> parameter of the ReduceAll operator. */
    OH_NN_REDUCE_ALL_KEEP_DIMS = 71,

    /** This enumerated value is used when the tensor is used as the <b>src_t</b> parameter of the QuantDTypeCast operator. */
    OH_NN_QUANT_DTYPE_CAST_SRC_T = 72,
    /** This enumerated value is used when the tensor is used as the <b>dst_t</b> parameter of the QuantDTypeCast operator. */
    OH_NN_QUANT_DTYPE_CAST_DST_T = 73,

    /** This enumerated value is used when the tensor is used as the <b>Sorted</b> parameter of the Topk operator. */
    OH_NN_TOP_K_SORTED = 74,

    /** This enumerated value is used when the tensor is used as the <b>axis</b> parameter of the ArgMax operator. */
    OH_NN_ARG_MAX_AXIS = 75,
    /** This enumerated value is used when the tensor is used as the <b>keepDims</b> parameter of the ArgMax operator. */
    OH_NN_ARG_MAX_KEEPDIMS = 76,

    /** This enumerated value is used when the tensor is used as the <b>Axis</b> parameter of the Unsqueeze operator. */
    OH_NN_UNSQUEEZE_AXIS = 77,
} OH_NN_TensorType;

/**
 * @brief This structure is used to store a 32-bit unsigned integer array.
 *
 * @since 9
 * @version 1.0
 */
typedef struct OH_NN_UInt32Array {
    /** Pointer to the unsigned integer array */
    uint32_t *data;
    /** Array length */
    uint32_t size;
} OH_NN_UInt32Array;

/**
 * @brief Quantization information.
 *
 * In quantization scenarios, the 32-bit floating-point data type is quantized into the fixed-point data type according to the following formula:
 \f[
    q = clamp(round(\frac{r}{s}+z), q_{min}, q_{max})
 \f]
 * s and z are quantization parameters, which are stored by <b>scale</b> and <b>zeroPoint</b> in {@link OH_NN_QuantParam}. 
 * r is a floating point number, q is the quantization result, q_min is the lower bound of the quantization result, and 
 * q_max is an upper bound of a quantization result. The calculation method is as follows:
 * 
 \f[
  \text{clamp}(x,min,max) = 
  \begin{cases}
       q_{min} = -(1 << (numBits - 1)) \\
       q_{max} = (1 << (numBits - 1)) \\
   \end{cases}
 \f]
 * The clamp function is defined as follows:
 \f[
  \text{clamp}(x,min,max) = 
  \begin{cases}
       \text{max} & \text{ if } x > \text{ max } \\
       \text{min} & \text{ if } x < \text{ min } \\
       x & \text{ otherwise } \\
   \end{cases}
 \f]
 * 
 * @deprecated since 11
 * @useinstead {@link NN_QuantParam}
 * @since 9
 * @version 1.0
 */
typedef struct OH_NN_QuantParam {
    /** Specifies the length of the numBits, scale, and zeroPoint arrays. In the per-layer quantization scenario, 
     *  <b>quantCount</b> is usually set to <b>1</b>. That is, all channels of a tensor share a set of quantization parameters.
     *  In the per-channel quantization scenario, <b>quantCount</b> is usually the same as the number of tensor channels, 
     *  and each channel uses its own quantization parameters.
     */
    uint32_t quantCount;
    /** Number of quantization bits */
    const uint32_t *numBits;
    /** Pointer to the scale data in the quantization formula */
    const double *scale;
    /** Pointer to the zero point data in the quantization formula */
    const int32_t *zeroPoint;
} OH_NN_QuantParam;

/**
 * @brief Defines the tensor structure.
 *
 * It is usually used to construct data nodes and operator parameters in a model graph. When constructing a tensor,
 * you need to specify the data type, number of dimensions, dimension information, and quantization information.
 *
 * @deprecated since 11
 * @useinstead {@link NN_TensorDesc}
 * @since 9
 * @version 1.0
 */
typedef struct OH_NN_Tensor {
    /** Data type of the specified tensor. The value must be an enumerated value of {@link OH_NN_DataType}. */
    OH_NN_DataType dataType;
    /** Number of dimensions of the specified tensor */
    uint32_t dimensionCount;
    /** Dimension information (shape) of the specified tensor*/
    const int32_t *dimensions;
    /** Quantization information of the specified tensor. The data type must be {@link OH_NN_QuantParam}. */
    const OH_NN_QuantParam *quantParam;
    /** Specifies the tensor type. The value of <b>type</b> is related to the tensor usage. 
     *  When the tensor is used as the input or output of the model, set <b>type</b> to {@link OH_NN_TENSOR}.
     *  When a tensor is used as an operator parameter, select any enumerated value except {@link OH_NN_TENSOR} from {@link OH_NN_TensorType}.
     */
    OH_NN_TensorType type;
} OH_NN_Tensor;

/**
 * @brief Defines the memory structure.
 *
 * @deprecated since 11
 * @useinstead {@link NN_Tensor}
 * @since 9
 * @version 1.0
 */
typedef struct OH_NN_Memory {
    /** Pointer to the shared memory. The shared memory is usually allocated by the underlying hardware driver. */
    void * const data;
    /** Records the length of the shared memory, in bytes. */
    const size_t length;
} OH_NN_Memory;

#ifdef __cplusplus
}
#endif // __cplusplus

/** @} */
#endif // NEURAL_NETWORK_RUNTIME_TYPE_H