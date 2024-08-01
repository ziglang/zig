/*
 * Copyright (c) 2024 Huawei Device Co., Ltd.
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
 * @addtogroup ArkUI_NativeModule
 * @{
 *
 * @brief Provides UI capabilities of ArkUI on the native side, such as UI component creation and destruction,
 * tree node operations, attribute setting, and event listening.
 *
 * @since 12
 */

/**
 * @file native_node.h
 *
 * @brief Provides type definitions for <b>NativeNode</b> APIs.
 *
 * @library libace_ndk.z.so
 * @syscap SystemCapability.ArkUI.ArkUI.Full
 * @since 12
 */

#ifndef ARKUI_NATIVE_NODE_H
#define ARKUI_NATIVE_NODE_H

#include "native_type.h"
#include "ui_input_event.h"

#ifdef __cplusplus
extern "C" {
#endif

#define MAX_NODE_SCOPE_NUM 1000

/**
 * @brief Enumerates ArkUI component types that can be created on the native side.
 *
 * @since 12
 */
typedef enum {
    /** Custom node. */
    ARKUI_NODE_CUSTOM = 0,
    /** Text. */
    ARKUI_NODE_TEXT = 1,
    /** Text span. */
    ARKUI_NODE_SPAN = 2,
    /** Image span. */
    ARKUI_NODE_IMAGE_SPAN = 3,
    /** Image. */
    ARKUI_NODE_IMAGE = 4,
    /** Toggle. */
    ARKUI_NODE_TOGGLE = 5,
    /** Loading icon. */
    ARKUI_NODE_LOADING_PROGRESS = 6,
    /** Single-line text input. */
    ARKUI_NODE_TEXT_INPUT = 7,
    /** Multi-line text input. */
    ARKUI_NODE_TEXT_AREA = 8,
    /** Button. */
    ARKUI_NODE_BUTTON = 9,
    /** Progress indicator. */
    ARKUI_NODE_PROGRESS = 10,
    /** Check box. */
    ARKUI_NODE_CHECKBOX = 11,
    /** XComponent. */
    ARKUI_NODE_XCOMPONENT = 12,
    /** Date picker. */
    ARKUI_NODE_DATE_PICKER = 13,
    /** Time picker. */
    ARKUI_NODE_TIME_PICKER = 14,
    /** Text picker. */
    ARKUI_NODE_TEXT_PICKER = 15,
    /** Calendar picker. */
    ARKUI_NODE_CALENDAR_PICKER = 16,
    /** Slider. */
    ARKUI_NODE_SLIDER = 17,
    /** Radio */
    ARKUI_NODE_RADIO = 18,
    /** Stack container. */
    ARKUI_NODE_STACK = MAX_NODE_SCOPE_NUM,
    /** Swiper. */
    ARKUI_NODE_SWIPER,
    /** Scrolling container. */
    ARKUI_NODE_SCROLL,
    /** List. */
    ARKUI_NODE_LIST,
    /** List item. */
    ARKUI_NODE_LIST_ITEM,
    /** List item group. */
    ARKUI_NODE_LIST_ITEM_GROUP,
    /** Column container. */
    ARKUI_NODE_COLUMN,
    /** Row container. */
    ARKUI_NODE_ROW,
    /** Flex container. */
    ARKUI_NODE_FLEX,
    /** Refresh component. */
    ARKUI_NODE_REFRESH,
    /** Water flow container. */
    ARKUI_NODE_WATER_FLOW,
    /** Water flow item. */
    ARKUI_NODE_FLOW_ITEM,
    /** Relative layout component. */
    ARKUI_NODE_RELATIVE_CONTAINER,
    /** Grid. */
    ARKUI_NODE_GRID,
    /** Grid item. */
    ARKUI_NODE_GRID_ITEM,
} ArkUI_NodeType;

/**
 * @brief Defines the general input parameter structure of the {@link setAttribute} function.
 *
 * @since 12
 */
typedef struct {
    /** Numeric array. */
    const ArkUI_NumberValue* value;
    /** Size of the numeric array. */
    int32_t size;
    /** String type. */
    const char* string;
    /** Object type. */
    void* object;
} ArkUI_AttributeItem;

/**
 * @brief Defines the ArkUI style attributes that can be set on the native side.
 *
 * @since 12
 */
typedef enum {
    /**
     * @brief Defines the width attribute, which can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].f32: width, in vp.\n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].f32: width, in vp.\n
     *
     */
    NODE_WIDTH = 0,
    /**
     * @brief Defines the height attribute, which can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].f32: height, in vp.\n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].f32: height, in vp.\n
     *
     */
    NODE_HEIGHT,
    /**
     * @brief Defines the background color attribute, which can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].u32: background color. The value is in 0xARGB format. For example, 0xFFFF0000 indicates red.\n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].u32: background color. The value is in 0xARGB format. For example, 0xFFFF0000 indicates red.\n
     *
     */
    NODE_BACKGROUND_COLOR,
    /**
     * @brief Defines the background image attribute, which can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .string: image address;\n
     * .value[0]?.i32: whether to repeat the image. Optional. The parameter type is {@link ArkUI_ImageRepeat}.
     * .object: The parameter type is {@link ArkUI_DrawableDescriptor}. Either .string or .object must be set.\n
     * The default value is <b>ARKUI_IMAGE_REPEAT_NONE</b>.\n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .string: image address;\n
     * .value[0].i32: whether to repeat the image. The parameter type is {@link ArkUI_ImageRepeat}.\n
     * .object: The parameter type is {@link ArkUI_DrawableDescriptor}.\n
     *
     */
    NODE_BACKGROUND_IMAGE,
    /**
     * @brief Defines the padding attribute, which can be set, reset, and obtained as required through APIs.
     *
     * There are two formats of {@link ArkUI_AttributeItem} for setting the attribute value:\n
     * 1: Specify the same padding for the four directions. \n
     * .value[0].f32: padding, in vp.\n
     * 2: Specify different paddings for different directions. \n
     * .value[0].f32: top padding, in vp.\n
     * .value[1].f32: right padding, in vp.\n
     * .value[2].f32: bottom padding, in vp.\n
     * .value[3].f32: left padding, in vp.\n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].f32: top padding, in vp.\n
     * .value[1].f32: right padding, in vp.\n
     * .value[2].f32: bottom padding, in vp.\n
     * .value[3].f32: left padding, in vp.\n
     *
     */
    NODE_PADDING,
    /**
     * @brief Defines the component ID attribute, which can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .string: component ID.\n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .string: component ID.\n
     *
     */
    NODE_ID,
    /**
     * @brief Defines the interactivity attribute, which can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: The value <b>true</b> means that the component can interact with users, and <b>false</b> means the opposite.\n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: The value <b>1</b> means that the component can interact with users, and <b>0</b> means the opposite. \n
     *
     */
    NODE_ENABLED,
    /**
     * @brief Defines the margin attribute, which can be set, reset, and obtained as required through APIs.
     *
     * There are two formats of {@link ArkUI_AttributeItem} for setting the attribute value:\n
     * 1: Specify the same margin for the four directions. \n
     * .value[0].f32: margin, in vp.\n
     * 2: Specify different margins for different directions. \n
     * .value[0].f32: top margin, in vp.\n
     * .value[1].f32: right margin, in vp.\n
     * .value[2].f32: bottom margin, in vp.\n
     * .value[3].f32: left margin, in vp.\n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].f32: top margin, in vp.\n
     * .value[1].f32: right margin, in vp.\n
     * .value[2].f32: bottom margin, in vp.\n
     * .value[3].f32: left margin, in vp.\n
     *
     */
    NODE_MARGIN,
    /**
     * @brief Defines the translate attribute, which can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].f32: distance to translate along the x-axis, in vp. The default value is <b>0</b>.\n
     * .value[1].f32: distance to translate along the y-axis, in vp. The default value is <b>0</b>.\n
     * .value[2].f32: distance to translate along the z-axis, in vp. The default value is <b>0</b>. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].f32: distance to translate along the x-axis, in vp.\n
     * .value[1].f32: distance to translate along the y-axis, in vp.\n
     * .value[2].f32: distance to translate along the z-axis, in vp. \n
     *
     */
    NODE_TRANSLATE,
    /**
     * @brief Defines the scale attribute, which can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].f32: scale factor along the x-axis. The default value is <b>1</b>.\n
     * .value[1].f32: scale factor along the y-axis. The default value is <b>1</b>. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].f32: scale factor along the x-axis.\n
     * .value[1].f32: scale factor along the y-axis. \n
     *
     */
    NODE_SCALE,
    /**
     * @brief Defines the rotate attribute, which can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].f32: X coordinate of the rotation axis vector. The default value is <b>0</b>.\n
     * .value[1].f32: Y coordinate of the rotation axis vector. The default value is <b>0</b>.\n
     * .value[2].f32: Z coordinate of the rotation axis vector. The default value is <b>0</b>.\n
     * .value[3].f32: rotation angle. The default value is <b>0</b>.\n
     * .value[4].f32: line of sight, that is, the distance from the viewpoint to the z=0 plane, in vp.
     * The default value is <b>0</b>. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].f32: X coordinate of the rotation axis vector.\n
     * .value[1].f32: Y coordinate of the rotation axis vector.\n
     * .value[2].f32: Z coordinate of the rotation axis vector.\n
     * .value[3].f32: rotation angle.\n
     * .value[4].f32: line of sight, that is, the distance from the viewpoint to the z=0 plane, in vp. \n
     *
     */
    NODE_ROTATE,
    /**
     * @brief Sets the brightness attribute, which can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].f32: brightness value. The default value is <b>1.0</b>, and the recommended value range is [0, 2]. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].f32: brightness value. \n
     *
     */
    NODE_BRIGHTNESS,
    /**
     * @brief Sets the saturation attribute, which can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute: \n
     * .value[0].f32: saturation value. The default value is <b>1.0</b>, and the recommended value range is [0, 50). \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}: \n
     * .value[0].f32: saturation value. \n
     *
     */
    NODE_SATURATION,
    /**
     * @brief Sets the blur attribute, which can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute: \n
     * .value[0].f32: blur radius. A larger value indicates a higher blur degree. If the value is <b>0</b>,
     * the component is not blurred. The unit is vp. The default value is <b>0.0</b>. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].f32: blur radius. The larger the fuzzy radius, the more blurred the image. If the value is <b>0</b>,
     * the image is not blurred. The unit is vp. \n
     *
     */
    NODE_BLUR,
    /**
     * @brief Sets the gradient attribute, which can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].f32: start angle of the linear gradient. A positive value indicates a clockwise rotation from the
     * origin, (0, 0). The default value is <b>180</b>. \n
     * .value[1].i32: direction of the linear gradient. It does not take effect when <b>angle</b> is set.
     * The parameter type is {@link ArkUI_LinearGradientDirection}: \n
     * .value[2].i32: whether the colors are repeated. The default value is <b>false</b>. \n
     * .object: array of color stops, each of which consists of a color and its stop position.
     * Invalid colors are automatically skipped. \n
     * colors: colors of the color stops. \n
     * stops: stop positions of the color stops. \n
     * size: number of colors. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}: \n
     * .value[0].f32: start angle of the linear gradient. \n
     * .value[1].i32: direction of the linear gradient. It does not take effect when <b>angle</b> is set. \n
     * .value[0].i32: whether the colors are repeated. \n
     * .object: array of color stops, each of which consists of a color and its stop position.
     * Invalid colors are automatically skipped. \n
     * colors: colors of the color stops. \n
     * stops: stop positions of the color stops. \n
     * size: number of colors. \n
     *
     */
    NODE_LINEAR_GRADIENT,
    /**
     * @brief Sets the alignment attribute, which can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: alignment mode. The data type is {@link ArkUI_Alignment}.
     * The default value is <b>ARKUI_ALIGNMENT_CENTER</b>. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: alignment mode. The data type is {@link ArkUI_Alignment}. \n
     *
     */
    NODE_ALIGNMENT,
    /**
     * @brief Defines the opacity attribute, which can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].f32: opacity value. The value ranges from 0 to 1. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].f32: opacity value. The value ranges from 0 to 1. \n
     *
     */
    NODE_OPACITY,
    /**
     * @brief Defines the border width attribute, which can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * 1: .value[0].f32: width of the four borders. \n
     * 2: .value[0].f32: width of the top border. \n
     * .value[1].f32: width of the right border. \n
     * .value[2].f32: width of the bottom border. \n
     * .value[3].f32: width of the left border. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].f32: width of the top border. \n
     * .value[1].f32: width of the right border. \n
     * .value[2].f32: width of the bottom border. \n
     * .value[3].f32: width of the left border. \n
     *
     */
    NODE_BORDER_WIDTH,
    /**
     * @brief Defines the border corner radius attribute, which can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * 1: .value[0].f32: radius of the four corners. \n
     * 2: .value[0].f32: radius of the upper left corner. \n
     * .value[1].f32: radius of the upper right corner. \n
     * .value[2].f32: radius of the lower left corner. \n
     * .value[3].f32: radius of the lower right corner. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].f32: radius of the upper left corner. \n
     * .value[1].f32: radius of the upper right corner. \n
     * .value[2].f32: radius of the lower left corner. \n
     * .value[3].f32: radius of the lower right corner. \n
     *
     */
    NODE_BORDER_RADIUS,
    /**
     * @brief Defines the border color attribute, which can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * 1: .value[0].u32: color of the four borders, in 0xARGB format, for example, <b>0xFFFF11FF</b>. \n
     * 2: .value[0].u32: color of the top border, in 0xARGB format, for example, <b>0xFFFF11FF</b>. \n
     * .value[1].u32: color of the right border, in 0xARGB format, for example, <b>0xFFFF11FF</b>. \n
     * .value[2].u32: color of the lower border, in 0xARGB format, for example, <b>0xFFFF11FF</b>. \n
     * .value[3].u32: color of the left border, in 0xARGB format, for example, <b>0xFFFF11FF</b>. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].u32: color of the top border, in 0xARGB format, for example, <b>0xFFFF11FF</b>. \n
     * .value[1].u32: color of the right border, in 0xARGB format, for example, <b>0xFFFF11FF</b>. \n
     * .value[2].u32: color of the lower border, in 0xARGB format, for example, <b>0xFFFF11FF</b>. \n
     * .value[3].u32: color of the left border, in 0xARGB format, for example, <b>0xFFFF11FF</b>. \n
     *
     */
    NODE_BORDER_COLOR,
    /**
     * @brief Defines the border line style attribute, which can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * 1: .value[0].i32: line style of the four borders. The parameter type is {@link ArkUI_BorderStyle}.
     * The default value is <b>ARKUI_BORDER_STYLE_SOLID</b>. \n
     * 2: .value[0].i32: line style of the top border. The parameter type is {@link ArkUI_BorderStyle}.
     * The default value is <b>ARKUI_BORDER_STYLE_SOLID</b>. \n
     * .value[1].i32: line style of the right border. The parameter type is {@link ArkUI_BorderStyle}.
     * The default value is <b>ARKUI_BORDER_STYLE_SOLID</b>. \n
     * .value[2].i32: line style of the bottom border. The parameter type is {@link ArkUI_BorderStyle}.
     * The default value is <b>ARKUI_BORDER_STYLE_SOLID</b>. \n
     * .value[3].i32: line style of the left border. The parameter type is {@link ArkUI_BorderStyle}.
     * The default value is <b>ARKUI_BORDER_STYLE_SOLID</b>. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: line style of the top border. \n
     * .value[1].i32: line style of the right border. \n
     * .value[2].i32: line style of the bottom border. \n
     * .value[3].i32: line style of the left border. \n
     *
     */
    NODE_BORDER_STYLE,
    /**
     * @brief Defines the z-index attribute for the stack sequence.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].f32: z-index value. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].f32: z-index value. \n
     *
     */
    NODE_Z_INDEX,
    /**
     * @brief Defines the visibility attribute, which can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: whether to show or hide the component. The parameter type is {@link ArkUI_Visibility}.
     * The default value is <b>ARKUI_VISIBILITY_VISIBLE</b>. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: whether to show or hide the component. The parameter type is {@link ArkUI_Visibility}.
     * The default value is <b>ARKUI_VISIBILITY_VISIBLE</b>. \n
     *
     */
    NODE_VISIBILITY,
    /**
     * @brief Defines the clip attribute, which can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: whether to clip the component based on the parent container bounds.
     * The value <b>0</b> means to clip the component, and <b>1</b> means the opposite. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: whether to clip the component based on the parent container bounds.
     * The value <b>0</b> means to clip the component, and <b>1</b> means the opposite. \n
     *
     */
    NODE_CLIP,
    /**
     * @brief Defines the clipping region on the component.
     * This attribute can be set and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute,
     * which supports five types of shapes:\n
     * 1. Rectangle:\n
     * .value[0].i32: type of shape. The parameter type is {@link ArkUI_ClipType}.
     * The value is <b>ARKUI_CLIP_TYPE_RECTANGLE</b> for the rectangle shape.\n
     * .value[1].f32: width of the rectangle.\n
     * .value[2].f32: height of rectangle.\n
     * .value[3].f32: width of the rounded corner of the rectangle.\n
     * .value[4].f32: height of the rounded corner of the rectangle.\n
     * 2. Circle:\n
     * .value[0].i32: type of shape. The parameter type is {@link ArkUI_ClipType}.
     * The value is <b>ARKUI_CLIP_TYPE_CIRCLE</b> for the circle shape.\n
     * .value[1].f32: width of the circle.\n
     * .value[2].f32: height of the circle.\n
     * 3.Ellipse:\n
     * .value[0].i32: type of shape. The parameter type is {@link ArkUI_ClipType}.
     * The value is <b>ARKUI_CLIP_TYPE_ELLIPSE</b> for the ellipse shape.\n
     * .value[1].f32: width of the ellipse.\n
     * .value[2].f32: height of the ellipse.\n
     * 4. Path:\n
     * .value[0].i32: type of shape. The parameter type is {@link ArkUI_ClipType}.
     * The value is <b>ARKUI_CLIP_TYPE_PATH</b> for the path shape.\n
     * .value[1].f32: width of the path.\n
     * .value[2].f32: height of the path.\n
     * .string: command for drawing the path.\n
     * Format of the return value {@link ArkUI_AttributeItem}, which supports five types of shapes:\n
     * 1. Rectangle:\n
     * .value[0].i32: type of shape. The parameter type is {@link ArkUI_ClipType}.
     * The value is <b>ARKUI_CLIP_TYPE_RECTANGLE</b> for the rectangle shape.\n
     * .value[1].f32: width of the rectangle.\n
     * .value[2].f32: height of rectangle.\n
     * .value[3].f32: width of the rounded corner of the rectangle.\n
     * .value[4].f32: height of the rounded corner of the rectangle.\n
     * 2. Circle:\n
     * .value[0].i32: type of shape. The parameter type is {@link ArkUI_ClipType}.
     * The value is <b>ARKUI_CLIP_TYPE_CIRCLE</b> for the circle shape.\n
     * .value[1].f32: width of the circle.\n
     * .value[2].f32: height of the circle.\n
     * 3.Ellipse:\n
     * .value[0].i32: type of shape. The parameter type is {@link ArkUI_ClipType}.
     * The value is <b>ARKUI_CLIP_TYPE_ELLIPSE</b> for the ellipse shape.\n
     * .value[1].f32: width of the ellipse.\n
     * .value[2].f32: height of the ellipse.\n
     * 4. Path:\n
     * .value[0].i32: type of shape. The parameter type is {@link ArkUI_ClipType}.
     * The value is <b>ARKUI_CLIP_TYPE_PATH</b> for the path shape.\n
     * .value[1].f32: width of the path.\n
     * .value[2].f32: height of the path.\n
     * .string: command for drawing the path.\n
     *
     */
    NODE_CLIP_SHAPE,
    /**
     * @brief Defines the transform attribute, which can be used to translate, rotate, and scale images.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0...15].f32: 16 floating-point numbers. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0...15].f32: 16 floating-point numbers. \n
     *
     */
    NODE_TRANSFORM,
    /**
     * @brief Defines the hit test behavior attribute, which can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: hit test mode. The parameter type is {@link ArkUI_HitTestMode}.
     * The default value is <b>ARKUI_HIT_TEST_MODE_DEFAULT</b>. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: hit test mode. The parameter type is {@link ArkUI_HitTestMode}.
     * The default value is <b>ARKUI_HIT_TEST_MODE_DEFAULT</b>. \n
     *
     */
    NODE_HIT_TEST_BEHAVIOR,
    /**
     * @brief Defines the offset attribute, which specifies the offset of the component's upper left corner relative
     * to the parent container's. This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].f32: X coordinate. \n
     * .value[1].f32: Y coordinate. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].f32: X coordinate. \n
     * .value[1].f32: Y coordinate. \n
     *
     */
    NODE_POSITION,
    /**
     * @brief Defines the shadow attribute, which can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: shadow effect. The parameter type is {@link ArkUI_ShadowStyle}. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: shadow effect. The parameter type is {@link ArkUI_ShadowStyle}. \n
     *
     */
    NODE_SHADOW,
    /**
     * @brief Defines the custom shadow effect. This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0]?.f32: blur radius of the shadow, in vp.\n
     * .value[1]?.i32: whether to enable the coloring strategy. The value <b>1</b> means to enable the coloring
     * strategy, and <b>0</b> (default value) means the opposite.\n
     * .value[2]?.f32: offset of the shadow along the x-axis, in vp.\n
     * .value[3]?.f32: offset of the shadow along the y-axis, in vp.\n
     * .value[4]?.i32: shadow type {@link ArkUI_ShadowType}. The default value is <b>ARKUI_SHADOW_TYPE_COLOR</b>.\n
     * .value[5]?.u32: shadow color, in 0xARGB format. For example, 0xFFFF0000 indicates red.\n
     * .value[6]?.u32: whether to fill the shadow. The value <b>1</b> means to fill the shadow, and <b>0</b>
     * means the opposite.\n
     *
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].f32: blur radius of the shadow, in vp.\n
     * .value[1].i32: whether to enable the coloring strategy. \n
     * .value[2].f32: offset of the shadow along the x-axis, in vp.\n
     * .value[3].f32: offset of the shadow along the y-axis, in vp.\n
     * .value[4].i32: shadow type {@link ArkUI_ShadowType}. The default value is <b>ARKUI_SHADOW_TYPE_COLOR</b>.\n
     * .value[5].u32: shadow color, in 0xARGB format. For example, 0xFFFF0000 indicates red.\n
     * .value[6].u32: whether to fill the shadow. The value <b>1</b> means to fill the shadow, and <b>0</b>
     * means the opposite.\n
     *
     */
    NODE_CUSTOM_SHADOW,
    /**
     * @brief Defines the background image width and height.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].f32: width of the image. The value range is [0, +∞), and the unit is vp. \n
     * .value[1].f32: height of the image. The value range is [0, +∞), and the unit is vp. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].f32: width of the image, in vp. \n
     * .value[1].f32: height of the image, in vp. \n
     *
     */
    NODE_BACKGROUND_IMAGE_SIZE,
    /**
     * @brief Defines the background image size.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: size of the background image. The value is an enum of {@link ArkUI_ImageSize}. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: size of the background image. The value is an enum of {@link ArkUI_ImageSize}. \n
     *
     */
    NODE_BACKGROUND_IMAGE_SIZE_WITH_STYLE,
    /**
     * @brief Defines the background blur attribute, which can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: blue type. The value is an enum of {@link ArkUI_BlurStyle}. \n
     * .value[1]?.i32: color mode. The value is an enum of {@link ArkUI_ColorMode}. \n
     * .value[2]?.i32: adaptive color mode. The value is an enum of {@link ArkUI_AdaptiveColor}. \n
     * .value[3]?.f32: blur degree. The value range is [0.0, 1.0]. \n
     * .value[4]?.f32: start boundary of grayscale blur. \n
     * .value[5]?.f32: end boundary of grayscale blur. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: blue type. The value is an enum of {@link ArkUI_BlurStyle}. \n
     * .value[1].i32: color mode. The value is an enum of {@link ArkUI_ColorMode}. \n
     * .value[2].i32: adaptive color mode. The value is an enum of {@link ArkUI_AdaptiveColor}. \n
     * .value[3].f32: blur degree. The value range is [0.0, 1.0]. \n
     * .value[4].f32: start boundary of grayscale blur. \n
     * .value[5].f32: end boundary of grayscale blur. \n
     *
     */
    NODE_BACKGROUND_BLUR_STYLE,
    /**
     * @brief Defines the transform center attribute, which can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0]?.f32: X coordinate of the center point, in vp.\n
     * .value[1]?.f32: Y coordinate of the center point, in vp.\n
     * .value[2]?.f32: Z coordinate of the center point, in vp.\n
     * .value[3]?.f32 : X coordinate of the center point, expressed in a number that represents a percentage.
     * For example, 0.2 indicates 20%. This attribute overwrites value[0].f32. The default value is <b>0.5f</b>. \n
     * .value[4]?.f32 : Y coordinate of the center point, expressed in a number that represents a percentage.
     * For example, 0.2 indicates 20%. This attribute overwrites value[1].f32. The default value is <b>0.5f</b>. \n
     * .value[5]?.f32 : Z coordinate of the center point, expressed in a number that represents a percentage.
     * For example, 0.2 indicates 20%. This attribute overwrites value[2].f32. The default value is <b>0.0f</b>. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].f32: X coordinate of the center point, in vp.\n
     * .value[1].f32: Y coordinate of the center point, in vp.\n
     * .value[2].f32: Z coordinate of the center point, in vp.\n
     * Note: If the coordinate is expressed in a number that represents a percentage, the attribute obtaining API
     * returns the calculated value in vp.
     *
     */
    NODE_TRANSFORM_CENTER,
    /**
     * @brief Defines the transition opacity attribute, which can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].f32: opacity values of the start and end points.\n
     * .value[1].i32: animation duration, in milliseconds.\n
     * .value[2].i32: animation curve type. The value is an enum of {@link ArkUI_AnimationCurve}.\n
     * .value[3]?.i32: animation delay duration, in milliseconds.\n
     * .value[4]?.i32: number of times that the animation is played.\n
     * .value[5]?.i32: animation playback mode. The value is an enum of {@link ArkUI_AnimationPlayMode}.\n
     * .value[6]?.f32: animation playback speed.\n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].f32: opacity values of the start and end points.\n
     * .value[1].i32: animation duration, in milliseconds.\n
     * .value[2].i32: animation curve type. The value is an enum of {@link ArkUI_AnimationCurve}.\n
     * .value[3].i32: animation delay duration, in milliseconds. \n
     * .value[4].i32: number of times that the animation is played. \n
     * .value[5].i32: animation playback mode. The value is an enum of {@link ArkUI_AnimationPlayMode}. \n
     * .value[6].f32: animation playback speed. \n
     *
     */
    NODE_OPACITY_TRANSITION,
    /**
     * @brief Defines the transition rotation attribute, which can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].f32: X-component of the rotation vector. \n
     * .value[1].f32: Y-component of the rotation vector. \n
     * .value[2].f32: Z-component of the rotation vector \n
     * .value[3].f32: angle. \n
     * .value[4].f32: line of sight. The default value is <b>0.0f</b>. \n
     * .value[5].i32: animation duration, in milliseconds. \n
     * .value[6].i32: animation curve type. The value is an enum of {@link ArkUI_AnimationCurve}.\n \n
     * .value[7]?.i32: animation delay duration, in milliseconds. \n
     * .value[8]?.i32: number of times that the animation is played. \n
     * .value[9]?.i32: animation playback mode. The value is an enum of {@link ArkUI_AnimationPlayMode}. \n
     * .value[10]?.f32: animation playback speed. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].f32: X-component of the rotation vector. \n
     * .value[1].f32: Y-component of the rotation vector. \n
     * .value[2].f32: Z-component of the rotation vector \n
     * .value[3].f32: angle. \n
     * .value[4].f32: line of sight. \n
     * .value[5].i32: animation duration, in milliseconds. \n
     * .value[6].i32: animation curve type. The value is an enum of {@link ArkUI_AnimationCurve}.\n \n
     * .value[7].i32: animation delay duration, in milliseconds. \n
     * .value[8].i32: number of times that the animation is played. \n
     * .value[9].i32: animation playback mode. The value is an enum of {@link ArkUI_AnimationPlayMode}. \n
     * .value[10].f32: animation playback speed. \n
     *
     */
    NODE_ROTATE_TRANSITION,
    /**
     * @brief Defines the transition scaling attribute, which can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].f32: scale factor along the x-axis. \n
     * .value[1].f32: scale factor along the y-axis. \n
     * .value[2].f32: scale factor along the z-axis. \n
     * .value[3].i32: animation duration, in milliseconds. \n
     * .value[4].i32: animation curve type. The value is an enum of {@link ArkUI_AnimationCurve}.\n \n
     * .value[5]?.i32: animation delay duration, in milliseconds. \n
     * .value[6]?.i32: number of times that the animation is played. \n
     * .value[7]?.i32: animation playback mode. The value is an enum of {@link ArkUI_AnimationPlayMode}. \n
     * .value[8]?.f32: animation playback speed. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].f32: scale factor along the x-axis. \n
     * .value[1].f32: scale factor along the y-axis. \n
     * .value[2].f32: scale factor along the z-axis. \n
     * .value[3].i32: animation duration, in milliseconds. \n
     * .value[4].i32: animation curve type. The value is an enum of {@link ArkUI_AnimationCurve}.\n \n
     * .value[5].i32: animation delay duration, in milliseconds. \n
     * .value[6].i32: number of times that the animation is played. \n
     * .value[7].i32: animation playback mode. The value is an enum of {@link ArkUI_AnimationPlayMode}. \n
     * .value[8].f32: animation playback speed. \n
     *
     */
    NODE_SCALE_TRANSITION,
    /**
     * @brief Defines the transition translation attribute.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * value[0].f32: translation distance along the x-axis, in vp.\n
     * value[1].f32: translation distance along the y-axis, in vp.\n
     * value[2].f32: translation distance along the z-axis, in vp.\n
     * value[3].i32: animation duration, in milliseconds. \n
     * value[4].i32: animation curve type. The value is an enum of {@link ArkUI_AnimationCurve}.\n \n
     * value[5]?.i32: animation delay duration, in milliseconds. \n
     * value[6]?.i32: number of times that the animation is played. \n
     * value[7]?.i32: animation playback mode. The value is an enum of {@link ArkUI_AnimationPlayMode}. \n
     * value[8]?.f32: animation playback speed. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * value[0].f32: translation distance along the x-axis, in vp.\n
     * value[1].f32: translation distance along the y-axis, in vp.\n
     * value[2].f32: translation distance along the z-axis, in vp.\n
     * value[3].i32: animation duration, in milliseconds. \n
     * value[4].i32: animation curve type. The value is an enum of {@link ArkUI_AnimationCurve}.\n \n
     * value[5].i32: animation delay duration, in milliseconds. \n
     * value[6].i32: number of times that the animation is played. \n
     * value[7].i32: animation playback mode. The value is an enum of {@link ArkUI_AnimationPlayMode}. \n
     * value[8].f32: animation playback speed. \n
     *
     */
    NODE_TRANSLATE_TRANSITION,
    /**
     * @brief Defines the slide-in and slide-out of the component from the screen edge during transition.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * value[0].i32: The parameter type is {@link ArkUI_TransitionEdge}. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * value[0].i32: The parameter type is {@link ArkUI_TransitionEdge}. \n
     *
     */
    NODE_MOVE_TRANSITION,

    /**
     * @brief Defines the focus attribute, which can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: The parameter type is 1 or 0.
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: The parameter type is 1 or 0.
     *
     */
    NODE_FOCUSABLE,

    /**
     * @brief Defines the default focus attribute, which can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * value[0].i32: The parameter type is 1 or 0.
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * value[0].i32: The parameter type is 1 or 0.
     *
     */
    NODE_DEFAULT_FOCUS,

    /**
     * @brief Defines the touch target attribute, which can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .data[0].f32: X coordinate of the touch point relative to the upper left corner of the component, in vp. \n
     * .data[1].f32: Y coordinate of the touch point relative to the upper left corner of the component, in vp. \n
     * .data[2].f32: width of the touch target, in %. \n
     * .data[3].f32: height of the touch target, in %. \n
     * .data[4...].f32: Multiple touch targets can be set. The sequence of the parameters is the same as the preceding.
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .data[0].f32: X coordinate of the touch point relative to the upper left corner of the component, in vp. \n
     * .data[1].f32: Y coordinate of the touch point relative to the upper left corner of the component, in vp. \n
     * .data[2].f32: width of the touch target, in %. \n
     * .data[3].f32: height of the touch target, in %. \n
     * .data[4...].f32: Multiple touch targets can be set. The sequence of the parameters is the same as the preceding.
     *
     */
    NODE_RESPONSE_REGION,

    /**
     * @brief Defines the overlay attribute, which can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .string: mask text.\n
     * .value[0]?.i32: position of the overlay relative to the component. Optional.
     * The parameter type is {@link ArkUI_Alignment}.
     * The default value is <b>ARKUI_ALIGNMENT_TOP_START.</b> \n
     * .value[1]?.f32: offset of the overlay relative to the upper left corner of itself on the x-axis, in vp. Optional. \n
     * .value[2]?.f32: offset of the overlay relative to the upper left corner of itself on the y-axis, in vp. Optional.
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .string: mask text.\n
     * .value[0].i32: position of the overlay relative to the component.
     * The parameter type is {@link ArkUI_Alignment}.
     * The default value is <b>ARKUI_ALIGNMENT_TOP_START.</b> \n
     * .value[1].f32: offset of the overlay relative to the upper left corner of itself on the x-axis, in vp. \n
     * .value[2].f32: offset of the overlay relative to the upper left corner of itself on the y-axis, in vp.
     *
     */
    NODE_OVERLAY,
    /**
     * @brief Defines the sweep gradient effect.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0]?.f32: X coordinate of the sweep gradient center relative to the upper left corner of the component.\n
     * .value[1]?.f32: Y coordinate of the sweep gradient center relative to the upper left corner of the component.\n
     * .value[2]?.f32: start point of the sweep gradient. The default value is <b>0</b>. \n
     * .value[3]?.f32: end point of the sweep gradient. The default value is <b>0</b>. \n
     * .value[4]?.f32: rotation angle of the sweep gradient. The default value is <b>0</b>. \n
     * .value[5]?.i32: whether the colors are repeated. The value <b>1</b> means that the colors are repeated,
     * and <b>0</b> means the opposite.\n
     * .object: array of color stops, each of which consists of a color and its stop position. Invalid colors are
     * automatically skipped.\n
     * colors: colors of the color stops. \n
     * stops: stop positions of the color stops. \n
     * size: number of colors. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].f32: X coordinate of the sweep gradient center relative to the upper left corner of the component. \n
     * .value[1].f32: Y coordinate of the sweep gradient center relative to the upper left corner of the component. \n
     * .value[2].f32: start point of the sweep gradient. The default value is <b>0</b>. \n
     * .value[3].f32: end point of the sweep gradient. The default value is <b>0</b>. \n
     * .value[4].f32: rotation angle of the sweep gradient. The default value is <b>0</b>. \n
     * .value[5].i32: whether the colors are repeated. The value <b>1</b> means that the colors are repeated,
     * and <b>0</b> means the opposite.\n
     * .object: array of color stops, each of which consists of a color and its stop position. Invalid colors are
     * automatically skipped.\n
     * colors: colors of the color stops. \n
     * stops: stop positions of the color stops. \n
     * size: number of colors. \n
     *
     */
    NODE_SWEEP_GRADIENT,
    /**
     * @brief Defines the radial gradient effect.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute: \n
     * .value[0]?.f32: X coordinate of the radial gradient center relative to the upper left corner of the component. \n
     * .value[1]?.f32: Y coordinate of the radial gradient center relative to the upper left corner of the component. \n
     * .value[2]?.f32: radius of the radial gradient. The default value is <b>0</b>. \n
     * .value[3]?.i32: whether the colors are repeated. The value <b>1</b> means that the colors are repeated,
     * and <b>0</b> means the opposite. \n
     * .object: array of color stops, each of which consists of a color and its stop position. Invalid colors are
     * automatically skipped. \n
     * colors: colors of the color stops. \n
     * stops: stop positions of the color stops. \n
     * size: number of colors. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].f32: X coordinate of the radial gradient center relative to the upper left corner of the component. \n
     * .value[1].f32: Y coordinate of the radial gradient center relative to the upper left corner of the component. \n
     * .value[2].f32: radius of the radial gradient. The default value is <b>0</b>. \n
     * .value[3].i32: whether the colors are repeated. The value <b>1</b> means that the colors are repeated,
     * and <b>0</b> means the opposite.\n
     * .object: array of color stops, each of which consists of a color and its stop position. Invalid colors are
     * automatically skipped. \n
     * colors: colors of the color stops. \n
     * stops: stop positions of the color stops. \n
     * size: number of colors. \n
     *
     */
    NODE_RADIAL_GRADIENT,
    /**
     * @brief Adds a mask of the specified shape to the component.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute, which supports five types of
     * shapes:\n
     * 1. Rectangle:\n
     * .value[0].u32 fill color, in 0xARGB format. \n
     * .value[1].u32: stroke color, in 0xARGB format. \n
     * .value[2].f32: stroke width, in vp. \n
     * .value[3].i32: mask type. The parameter type is {@link ArkUI_MaskType}.
     * The value is <b>ARKUI_MASK_TYPE_RECTANGLE</b> for the rectangle shape.\n
     * .value[4].f32: width of the rectangle.\n
     * .value[5].f32: height of the rectangle.\n
     * .value[6].f32: width of the rounded corner of the rectangle.\n
     * .value[7].f32: height of the rounded corner of the rectangle.\n
     * 2. Circle:\n
     * .value[0].u32 fill color, in 0xARGB format. \n
     * .value[1].u32: stroke color, in 0xARGB format. \n
     * .value[2].f32: stroke width, in vp. \n
     * .value[3].i32: mask type. The parameter type is {@link ArkUI_MaskType}.
     * The value is <b>ARKUI_MASK_TYPE_CIRCLE</b> for the circle shape.\n
     * .value[4].f32: width of the circle.\n
     * .value[5].f32: height of the circle.\n
     * 3. Ellipse:\n
     * .value[0].u32 fill color, in 0xARGB format. \n
     * .value[1].u32: stroke color, in 0xARGB format. \n
     * .value[2].f32: stroke width, in vp. \n
      * .value[3].i32: mask type. The parameter type is {@link ArkUI_MaskType}.
      * The value is <b>ARKUI_MASK_TYPE_ELLIPSE</b> for the ellipse shape.\n
     * .value[4].f32: width of the ellipse.\n
     * .value[5].f32: height of the ellipse.\n
     * 4. Path:\n
     * .value[0].u32 fill color, in 0xARGB format. \n
     * .value[1].u32: stroke color, in 0xARGB format. \n
     * .value[2].f32: stroke width, in vp. \n
     * .value[3].i32: mask type. The parameter type is {@link ArkUI_MaskType}.
     * The value is <b>ARKUI_MASK_TYPE_PATH</b> for the path shape.\n
     * .value[4].f32: width of the path.\n
     * .value[5].f32: height of the path.\n
     * .string: command for drawing the path.\n
     * 5. Progress:\n
     * .value[0].i32: mask type. The parameter type is {@link ArkUI_MaskType}.
     * The value is <b>ARKUI_MASK_TYPE_PROSGRESS</b> for the progress shape.\n
     * .value[1].f32: current value of the progress indicator.\n
     * .value[2].f32: maximum value of the progress indicator.\n
     * .value[3].u32: color of the progress indicator.\n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}, which supports five types of shapes:\n
     * 1. Rectangle:\n
     * .value[0].u32 fill color, in 0xARGB format. \n
     * .value[1].u32: stroke color, in 0xARGB format. \n
     * .value[2].f32: stroke width, in vp. \n
     * .value[3].i32: mask type.\n
     * .value[4].f32: width of the rectangle.\n
     * .value[5].f32: height of the rectangle.\n
     * .value[6].f32: width of the rounded corner of the rectangle.\n
     * .value[7].f32: height of the rounded corner of the rectangle.\n
     * 2. Circle:\n
     * .value[0].u32 fill color, in 0xARGB format. \n
     * .value[1].u32: stroke color, in 0xARGB format. \n
     * .value[2].f32: stroke width, in vp. \n
     * .value[3].i32: mask type.\n
     * .value[4].f32: width of the circle.\n
     * .value[5].f32: height of the circle.\n
     * 3. Ellipse:\n
     * .value[0].u32 fill color, in 0xARGB format. \n
     * .value[1].u32: stroke color, in 0xARGB format. \n
     * .value[2].f32: stroke width, in vp. \n
     * .value[3].i32: mask type.\n
     * .value[4].f32: width of the ellipse.\n
     * .value[5].f32: height of the ellipse.\n
     * 4. Path:\n
     * .value[0].u32 fill color, in 0xARGB format. \n
     * .value[1].u32: stroke color, in 0xARGB format. \n
     * .value[2].f32: stroke width, in vp. \n
     * .value[3].i32: mask type.\n
     * .value[4].f32: width of the path.\n
     * .value[5].f32: height of the path.\n
     * .string: command for drawing the path.\n
     * 5. Progress:\n
     * .value[0].i32: mask type.\n
     * .value[1].f32: current value of the progress indicator.\n
     * .value[2].f32: maximum value of the progress indicator.\n
     * .value[3].u32: color of the progress indicator.\n
     *
     */
    NODE_MASK,
    /**
     * @brief Blends the component's background with the content of the component's child node.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: blend mode. The parameter type is {@link ArkUI_BlendMode}. The default value is
     * <b>ARKUI_BLEND_MODE_NONE</b>. \n
     * .value[1].?i32: how the specified blend mode is applied. The parameter type is {@link ArkUI_BlendApplyType}.
     * The default value is <b>ARKUI_BLEND_APPLY_TYPE_FAST</b>. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: blend mode. The parameter type is {@link ArkUI_BlendMode}. The default value is
     * <b>ARKUI_BLEND_MODE_NONE</b>. \n
     * .value[1].i32: how the specified blend mode is applied. The parameter type is {@link ArkUI_BlendApplyType}.
     * The default value is <b>ARKUI_BLEND_APPLY_TYPE_FAST</b>. \n
     *
     */
    NODE_BLEND_MODE,
    /**
     * @brief Sets the direction of the main axis.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: direction of the main axis.\n
     * The parameter type is {@link ArkUI_Direction}. The default value is <b>ARKUI_DIRECTION_AUTO</b>. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: direction of the main axis.\n
     * The parameter type is {@link ArkUI_Direction}. The default value is <b>ARKUI_DIRECTION_AUTO</b>. \n
     *
     */
    NODE_DIRECTION,
    /**
     * @brief Defines the size constraints.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].f32: minimum width, in vp.\n
     * .value[1].f32: maximum width, in vp.\n
     * .value[2].f32: minimum height, in vp.\n
     * .value[3].f32: maximum height, in vp.\n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].f32: minimum width, in vp.\n
     * .value[1].f32: maximum width, in vp.\n
     * .value[2].f32: minimum height, in vp.\n
     * .value[3].f32: maximum height, in vp.\n
     *
     */
    NODE_CONSTRAINT_SIZE,
    /**
     * @brief Defines the grayscale effect.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].f32: grayscale conversion ratio. The value ranges from 0 to 1.
     * For example, 0.5 indicates a 50% grayscale conversion ratio. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].f32: grayscale conversion ratio. The value ranges from 0 to 1.\n
     *
     */
    NODE_GRAY_SCALE,
    /**
     * @brief Inverts the image.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].f32: image inversion ratio. The value ranges from 0 to 1.
     * For example, 0.5 indicates a 50% image inversion ratio.\n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].f32: image inversion ratio. The value ranges from 0 to 1.\n
     *
     */
    NODE_INVERT,
    /**
     * @brief Defines the sepia conversion ratio.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].f32: sepia conversion ratio. The value ranges from 0 to 1.
     * For example, 0.5 indicates that a 50% sepia conversion ratio.\n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].f32: sepia conversion ratio. The value ranges from 0 to 1.\n
     *
     */
    NODE_SEPIA,
    /**
     * @brief Defines the contrast attribute, which can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].f32: contrast. If the value is <b>1</b>, the source image is displayed.
     * A larger value indicates a higher contrast. Value range: [0, 10).\n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].f32: contrast. Value range: [0, 10).\n
     *
     */
    NODE_CONTRAST,
    /**
     * @brief Defines the foreground color attribute, which can be set, reset, and obtained as required through APIs.
     *
     * There are two formats of {@link ArkUI_AttributeItem} for setting the attribute value:\n
     * 1: .value[0].u32: color value, in 0xARGB format. For example, 0xFFFF0000 indicates red.\n
     * 2: .value[0].i32: color enum {@link ArkUI_ColoringStrategy}.\n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].u32: color value, in 0xARGB format.\n
     *
     */
    NODE_FOREGROUND_COLOR,

    /**
     * @brief Defines the offset of the component's child relative to the component.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].f32 : offset along the x-axis, in vp. \n
     * .value[1].f32 : offset along the y-axis, in vp. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].f32 : offset along the x-axis, in vp. \n
     * .value[1].f32 : offset along the y-axis, in vp. \n
     *
     */
    NODE_OFFSET,
    /**
     * @brief Sets the anchor for locating the component's child.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].f32: X coordinate of the anchor, in vp.\n
     * .value[1].f32: Y coordinate of the anchor, in vp.\n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].f32: X coordinate of the anchor, in vp.\n
     * .value[1].f32: Y coordinate of the anchor, in vp.\n
     *
     */
    NODE_MARK_ANCHOR,
    /**
     * @brief Defines the position of the background image in the component, that is, the coordinates relative to
     * the upper left corner of the component. This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].f32: position along the x-axis, in vp. \n
     * .value[1].f32: position along the y-axis, in vp. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].f32: position along the x-axis, in vp. \n
     * .value[1].f32: position along the y-axis, in vp. \n
     *
     */
    NODE_BACKGROUND_IMAGE_POSITION,
    /**
     * @brief Sets the alignment rules in the relative container.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .object: Use the {@link ArkUI_AlignmentRuleOption} object as the component’s alignment rule. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .object: Use the {@link ArkUI_AlignmentRuleOption} object as the component’s alignment rule. \n
     *
     */
    NODE_ALIGN_RULES,
    /**
     * @brief Sets the alignment mode of the child components along the cross axis of the parent container.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: alignment mode of the child components along the cross axis of the parent container.\n
     * The parameter type is {@link ArkUI_ItemAlignment}. The default value is <b>ARKUI_ITEM_ALIGNMENT_AUTO</b>. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: alignment mode of the child components along the cross axis of the parent container.\n
     * The parameter type is {@link ArkUI_ItemAlignment}. The default value is <b>ARKUI_ITEM_ALIGNMENT_AUTO</b>. \n
     *
     */
    NODE_ALIGN_SELF,
    /**
     * @brief Sets the percentage of the parent container's remaining space that is allocated to the component.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].f32: percentage of the parent container's remaining space that is allocated to the component. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].f32: percentage of the parent container's remaining space that is allocated to the component. \n
     *
     */
    NODE_FLEX_GROW,
    /**
     * @brief Sets the percentage of the parent container's shrink size that is allocated to the component.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].f32: percentage of the parent container's shrink size that is allocated to the component. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].f32: percentage of the parent container's shrink size that is allocated to the component. \n
     *
     */
    NODE_FLEX_SHRINK,
    /**
     * @brief Sets the base size of the component.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].f32: percentage of the parent container's remaining space that is allocated to the component. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].f32: percentage of the parent container's remaining space that is allocated to the component. \n
     *
     */
    NODE_FLEX_BASIS,
    /**
     * @brief Sets the accessibility group. This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: Accessibility group. The value <b>1</b> means that the component and all its child components
     * form an entire selectable component.
     * In this case, the accessibility service will no longer be available for the content of its child components.
     * The value is <b>1</b> or <b>0</b>.
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: Accessibility group. The value <b>1</b> means that the component and all its child components
     * form an entire selectable component.
     * In this case, the accessibility service will no longer be available for the content of its child components.
     * The value is <b>1</b> or <b>0</b>.
     *
     */
    NODE_ACCESSIBILITY_GROUP,

    /**
     * @brief Sets the accessibility text. This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .string: accessibility text.
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .string: accessibility text.
     *
     */
    NODE_ACCESSIBILITY_TEXT,

    /**
     * @brief Sets the accessibility service model. This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: accessibility service model. The parameter type is {@link ArkUI_AccessibilityMode}.
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: accessibility service model. The parameter type is {@link ArkUI_AccessibilityMode}.
     *
     */
    NODE_ACCESSIBILITY_MODE,

    /**
     * @brief Sets the accessibility description.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .string: accessibility description.
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .string: accessibility description.
     *
     */
    NODE_ACCESSIBILITY_DESCRIPTION,

    /**
     * @brief Defines the focused state. This attribute can be set and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: The parameter type is 1 or 0.
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: The parameter type is 1 or 0.
     *
     */
    NODE_FOCUS_STATUS,
    /**
     * @brief Defines the aspect ratio attribute, which can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].f32: aspect ratio of the component, in width/height format. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].f32: aspect ratio of the component, in width/height format. \n
     *
     */
    NODE_ASPECT_RATIO,
    /**
     * @brief Defines the weight of the component within its row, column, or flex container for proportional
     * distribution of available space within the container.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].u32: weight of the component along the main axis. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].u32: weight of the component along the main axis. \n
     *
     */
    NODE_LAYOUT_WEIGHT,
    /**
     * @brief Sets the display priority for the component in the row, column, or flex  (single-line) container.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].u32: display priority of the component in the container. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].u32: display priority of the component in the container. \n
     *
     */
    NODE_DISPLAY_PRIORITY,
    /**
     * @brief Sets the thickness of an element's outline.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].f32: thickness of the left outline. \n
     * .value[1].f32: thickness of the top outline. \n
     * .value[2].f32: thickness of the right outline. \n
     * .value[3].f32: thickness of the bottom outline. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].f32: thickness of the left outline. \n
     * .value[1].f32: thickness of the top outline. \n
     * .value[2].f32: thickness of the right outline. \n
     * .value[3].f32: thickness of the bottom outline. \n
     *
     */
    NODE_OUTLINE_WIDTH,
    /**
     * @brief Defines the width attribute, which can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].f32: width, in percentage.\n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].f32: width, in percentage.\n
     *
     */
    NODE_WIDTH_PERCENT,
    /**
     * @brief Defines the height attribute, which can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].f32: height, in percentage.\n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].f32: height, in percentage.\n
     *
     */
    NODE_HEIGHT_PERCENT,
    /**
     * @brief Defines the padding attribute, which can be set, reset, and obtained as required through APIs.
     *
     * There are two formats of {@link ArkUI_AttributeItem} for setting the attribute value:\n
     * 1: Specify the same padding for the four directions. \n
     * .value[0].f32: padding, in percentage.\n
     * 2: Specify different paddings for different directions. \n
     * .value[0].f32: top padding, in percentage.\n
     * .value[1].f32: right padding, in percentage.\n
     * .value[2].f32: bottom padding, in percentage.\n
     * .value[3].f32: left padding, in percentage.\n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].f32: top padding, in percentage.\n
     * .value[1].f32: right padding, in percentage.\n
     * .value[2].f32: bottom padding, in percentage.\n
     * .value[3].f32: left padding, in percentage.\n
     *
     */
    NODE_PADDING_PERCENT,
    /**
     * @brief Defines the margin attribute, which can be set, reset, and obtained as required through APIs.
     *
     * There are two formats of {@link ArkUI_AttributeItem} for setting the attribute value:\n
     * 1: Specify the same margin for the four directions. \n
     * .value[0].f32: margin, in percentage.\n
     * 2: Specify different margins for different directions. \n
     * .value[0].f32: top margin, in percentage.\n
     * .value[1].f32: right margin, in percentage.\n
     * .value[2].f32: bottom margin, in percentage.\n
     * .value[3].f32: left margin, in percentage.\n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].f32: top margin, in percentage.\n
     * .value[1].f32: right margin, in percentage.\n
     * .value[2].f32: bottom margin, in percentage.\n
     * .value[3].f32: left margin, in percentage.\n
     *
     */
    NODE_MARGIN_PERCENT,

    /**
      * @brief The implicit shared element transition within the component supports attribute setting,
      * attribute reset, and attribute acquisition interfaces.
      *
      * Attribute setting method parameter {@link ArkUI_AttributeItem} format: \n
      * .value[0]?.i32: The parameter type is 1 or 0. 2 components that share element bindings,
      * Whether to continue to participate in the shared element animation when the appearance element is not deleted,
      * the default is false, and the original position will remain unchanged if not involved. \n
      * .string is used to set the binding relationship. Set the id to "" to
      * clear the binding relationship to avoid participating in sharing behavior. \n
      * The id can be changed and the binding relationship re-established.
      * The same ID can only be bound to two components and they are in/out roles of different types.
      * Multiple components cannot be bound to the same id. \n
      *\n
      * Attribute acquisition method return value {@link ArkUI_AttributeItem} format: \n
      * .value[0].i32: The parameter type is 1 or 0. 2 components that share element bindings,
      * Whether to continue to participate in the shared element animation when the appearance element is not deleted,
      * the default is not false, if not involved, the original position will remain unchanged. \n
      * .string is used to set the binding relationship. Set the id to "" to
      * clear the binding relationship to avoid participating in sharing behavior. \n
      * The id can be changed and the binding relationship re-established.
      * The same ID can only be bound to two components and they are in/out roles of different types.
      * Multiple components cannot be bound to the same id. \n
      */
    NODE_GEOMETRY_TRANSITION,

    /**
      * @brief specifies the parameters of the chain formed by this component as the chain head,
      * and supports attribute setting, attribute reset and attribute acquisition interfaces.
      *
      * Only takes effect when the parent container is RelativeContainer
      *
      * Attribute setting method parameter {@link ArkUI_AttributeItem} format: \n
      * .value[0].i32: The direction of the chain. Enum {@link ArkUI_Axis}. \n
      * .value[1].i32: Chain style. Enum {@link ArkUI_RelativeLayoutChainStyle}. \n
      *\n
      * .value[0].i32: The direction of the chain. Enum {@link ArkUI_Axis}. \n
      * .value[1].i32: Chain style. Enum {@link ArkUI_RelativeLayoutChainStyle}. \n
      */
    NODE_RELATIVE_LAYOUT_CHAIN_MODE,

    /**
     * @brief Set the component content filling method in the process of width and height animation,
     * support property setting, property reset, property acquisition interface.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32 Content filling mode {@link ArkUI_RenderFit}.\n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32 Content filling mode {@link ArkUI_RenderFit}.\n
     *
     */
    NODE_RENDER_FIT,

    /**
     * @brief External stroke color properties, support property setting,
     * property reset and property acquisition interface.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * 1: .value[0].u32: Set the border color of the four sides uniformly, using 0xargb, such as 0xFFFF11FF. \n
     * 2: .value[0].u32: Set the top border color, represented by 0xargb, such as 0xFFFF11FF. \n
     * .value[1].u32: Set the right border color, represented by 0xargb, such as 0xFFFF11FF. \n
     * .value[2].u32: Set the lower side box color, denoted by 0xargb, such as 0xFFFF11FF. \n
     * .value[3].u32: Set the left border color, denoted by 0xargb, such as 0xFFFF11FF. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].u32: Set the top border color, represented by 0xargb, such as 0xFFFF11FF. \n
     * .value[1].u32: Set the right border color, represented by 0xargb, such as 0xFFFF11FF. \n
     * .value[2].u32: Set the lower side box color, denoted by 0xargb, such as 0xFFFF11FF. \n
     * .value[3].u32: Set the left border color, denoted by 0xargb, such as 0xFFFF11FF. \n
     *
     */
    NODE_OUTLINE_COLOR,

    /**
     * @brief Set the height and width dimensions, support property setting,
     * property reset and property acquisition interface.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].f32: Width value, unit is vp;\n
     * .value[1].f32: Height value, unit is vp;\n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].f32: Width value, unit is vp;\n
     * .value[1].f32: Height value, unit is vp;\n
     *
     */
    NODE_SIZE,

    /**
     * @brief Set whether the current component and child component are
     * rendered off the screen first and then fused with the parent control,
     * supporting property setting, property reset and property acquisition.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: The parameter type is 1 or 0.
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: The parameter type is 1 or 0.
     *
     */
    NODE_RENDER_GROUP,

    /**
     * @brief Add color overlay effect to components, support property setting,
     * property reset and property acquisition interface.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].u32: The color of the overlay is represented by 0xargb, such as 0xFFFF11FF. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].u32: The color of the overlay is represented by 0xargb, such as 0xFFFF11FF. \n
     *
     */
    NODE_COLOR_BLEND,

    /**
     * @brief Provide content ambiguity capability for the current component,
     * support property setting, property reset, property acquisition interface.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32 Represents the content blurring style, and uses the {@link ArkUI_BlurStyle} enumeration value.\n
     * .value[1]?.i32 Represents the dark and light mode used by the content blur effect,\n
     * with the {@link ArkUI_ThemeColorMode} enumeration value.\n
     * .value[2]?.i32 The color extraction mode used to represent the content blur effect takes\n
     * the {@link ArkUI_AdaptiveColor} enumeration value.\n
     * .value[3]?.i32 It is a gray-level fuzzy parameter. The value range is [0,127].\n
     * .value[4]?.i32 It is a gray-level fuzzy parameter. The value range is [0,127].\n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32 Represents the content blurring style, and uses the {@link ArkUI_BlurStyle} enumeration value.\n
     * .value[1].i32 Represents the dark and light mode used by the content blur effect,\n
     * with the {@link ArkUI_ThemeColorMode} enumeration value.\n
     * .value[2].i32 The color extraction mode used to represent the content blur effect takes\n
     * the {@link ArkUI_AdaptiveColor} enumeration value.\n
     * .value[3].i32 It is a gray-level fuzzy parameter. The value range is [0,127].\n
     * .value[4].i32 It is a gray-level fuzzy parameter. The value range is [0,127].\n
     *
     */
    NODE_FOREGROUND_BLUR_STYLE,

    /**
     * @brief Defines layout rect attribute, which can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: x position of the component.
     * .value[1].i32: y position of the component.
     * .value[2].i32: width of the component.
     * .value[3].i32: height of the component.
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: x position of the component.
     * .value[1].i32: y position of the component.
     * .value[2].i32: width of the component.
     * .value[3].i32: height of the component.
     *
     */
    NODE_LAYOUT_RECT,

    /**
     * @brief Whether the current component supports click-to-focus capability,
     * which can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: The parameter type is 1 or 0.
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: The parameter type is 1 or 0.
     *
     */
    NODE_FOCUS_ON_TOUCH,

    /**
     * @brief Defines the text content attribute, which can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .string: text content.\n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .string: text content.\n
     *
     */
    NODE_TEXT_CONTENT = MAX_NODE_SCOPE_NUM * ARKUI_NODE_TEXT,
    /**
     * @brief Defines the font color attribute, which can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].u32: font color, in 0xARGB format. For example, 0xFFFF0000 indicates red.\n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
      * .value[0].u32: font color value, in 0xARGB format.\n
     *
     */
    NODE_FONT_COLOR,
    /**
     * @brief Defines the font size attribute, which can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].f32: font size, in fp.\n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].f32: font size, in fp.\n
     *
     */
    NODE_FONT_SIZE,
    /**
     * @brief Defines the font style attribute, which can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: font style {@link ArkUI_FontStyle}. The default value is <b>ARKUI_FONT_STYLE_NORMAL</b>.\n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: font style {@link ArkUI_FontStyle}.\n
     *
     */
    NODE_FONT_STYLE,
    /**
     * @brief Defines the font weight attribute, which can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: font weight {@link ArkUI_FontWeight}. The default value is <b>ARKUI_FONT_WEIGHT_NORMAL</b>.\n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: font weight {@link ArkUI_FontWeight}.\n
     *
     */
    NODE_FONT_WEIGHT,
    /**
     * @brief Defines the text line height attribute, which can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].f32: line height, in fp.\n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].f32: line height, in fp.\n
     *
     */
    NODE_TEXT_LINE_HEIGHT,
    /**
     * @brief Defines the text decoration style and color.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: text decoration type {@link ArkUI_TextDecorationType}.
     * The default value is <b>ARKUI_TEXT_DECORATION_TYPE_NONE</b>.\n
     * .value[1]?.u32: text decoration color, in 0xARGB format. For example, 0xFFFF0000 indicates red. Optional.\n
     * .value[2]?.i32: text decoration style {@link ArkUI_TextDecorationStyle}. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: text decoration type {@link ArkUI_TextDecorationType}.\n
     * .value[1].u32: text decoration color, in 0xARGB format. \n
     * .value[2].i32: text decoration style {@link ArkUI_TextDecorationStyle}. \n
     *
     */
    NODE_TEXT_DECORATION,
    /**
     * @brief Defines the text case attribute, which can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: text case.\n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: text case.\n
     *
     */
    NODE_TEXT_CASE,
    /**
     * @brief Defines the letter spacing attribute, which can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].f32: letter spacing, in fp.\n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].f32: letter spacing, in fp.\n
     *
     */
    NODE_TEXT_LETTER_SPACING,
    /**
     * @brief Sets the maximum number of lines in the text.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: maximum number of lines in the text.\n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: maximum number of lines in the text.\n
     *
     */
    NODE_TEXT_MAX_LINES,
    /**
     * @brief Horizontal alignment mode of the text.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: horizontal alignment mode of the text. The value is an enum of {@link ArkUI_TextAlignment}. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: horizontal alignment mode of the text. The value is an enum of {@link ArkUI_TextAlignment}. \n
     *
     */
    NODE_TEXT_ALIGN,
    /**
     * @brief Defines the text overflow attribute, which can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: display mode when the text is too long. {@ArkUI_TextOverflow}\n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: display mode when the text is too long. {@ArkUI_TextOverflow}\n
     *
     */
    NODE_TEXT_OVERFLOW,
    /**
     * @brief Defines the font family attribute, which can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .string: fonts, separated by commas (,).
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .string: fonts, separated by commas (,).
     *
     */
    NODE_FONT_FAMILY,
    /**
     * @brief Defines the copy option attribute, which can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: copy option {@link ArkUI_CopyOptions}. The default value is <b>ARKUI_COPY_OPTIONS_NONE</b>.\n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: copy option {@link ArkUI_CopyOptions. \n
     *
     */
    NODE_TEXT_COPY_OPTION,
    /**
     * @brief Defines the text baseline offset attribute
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].f32: baseline offset, in fp.\n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].f32: baseline offset, in fp. \n
     *
     */
    NODE_TEXT_BASELINE_OFFSET,
    /**
     * @brief Defines the text shadow attribute, which can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].f32: blur radius of the shadow, in vp.\n
     * .value[1].i32: shadow type {@link ArkUI_ShadowType}. The default value is <b>ARKUI_SHADOW_TYPE_COLOR</b>.\n
     * .value[2].u32: shadow color, in 0xARGB format. For example, 0xFFFF0000 indicates red.\n
     * .value[3].f32: offset of the shadow along the x-axis, in vp.\n
     * .value[4].f32: offset of the shadow along the y-axis, in vp.\n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].f32: blur radius of the shadow, in vp.\n
     * .value[1].i32: shadow type {@link ArkUI_ShadowType}.\n
     * .value[2].u32: shadow color, in 0xARGB format.\n
     * .value[3].f32: offset of the shadow along the x-axis, in vp.\n
     * .value[4].f32: offset of the shadow along the y-axis, in vp.\n
     *
     */
    NODE_TEXT_TEXT_SHADOW,
    /**
     * @brief Defines the minimum font size attribute, which can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].f32: minimum font size, in fp.
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].f32: minimum font size, in fp.
     *
     */
    NODE_TEXT_MIN_FONT_SIZE,

    /**
     * @brief Defines the maximum font size attribute, which can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].f32: maximum font size, in fp.
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].f32: maximum font size, in fp.
     *
     */
    NODE_TEXT_MAX_FONT_SIZE,

    /**
     * @brief Defines the text style attribute, which can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .string?: font family. Optional. Use commas (,) to separate multiple fonts. \n
     * .value[0].f32: font size, in fp. \n
     * .value[1]?.i32: font weight. Optional. The parameter type is {@link ArkUI_FontWeight}.
     * The default value is <b>ARKUI_FONT_WEIGHT_NORMAL</b>. \n
     * .value[2]?.i32: font style. Optional. The parameter type is {@link ArkUI_FontStyle}.
     * The default value is <b>ARKUI_FONT_STYLE_NORMAL</b>.
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .string: font family. Use commas (,) to separate multiple fonts. \n
     * .value[0].f32: font size, in fp. \n
     * .value[1].i32: font weight. The parameter type is {@link ArkUI_FontWeight}.
     * The default value is <b>ARKUI_FONT_WEIGHT_NORMAL</b>. \n
     * .value[2].i32: font style. The parameter type is {@link ArkUI_FontStyle}.
     * The default value is <b>ARKUI_FONT_STYLE_NORMAL</b>.
     *
     */
    NODE_TEXT_FONT,

    /**
     * @brief Defines how the adaptive height is determined for the text.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: how the adaptive height is determined for the text.
     * The parameter type is {@link ArkUI_TextHeightAdaptivePolicy}.
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: how the adaptive height is determined for the text.
     * The parameter type is {@link ArkUI_TextHeightAdaptivePolicy}
     *
     */
    NODE_TEXT_HEIGHT_ADAPTIVE_POLICY,
    /**
     * @brief Defines the indentation of the first line.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].f32: indentation of the first line. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].f32: indentation of the first line. \n
     *
     */
    NODE_TEXT_INDENT,
    /**
     * @brief Defines the line break rule. This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: The parameter type is {@link ArkUI_WordBreak}. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: The parameter type is {@link ArkUI_WordBreak}. \n
     *
     */
    NODE_TEXT_WORD_BREAK,
    /**
     * @brief Defines the ellipsis position. This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: The parameter type is {@link ArkUI_EllipsisMode}. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: The parameter type is {@link ArkUI_EllipsisMode}. \n
     *
     */
    NODE_TEXT_ELLIPSIS_MODE,
    /**
     * @brief Defines the text line spacing attribute, which can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].f32: line spacing, in fp.\n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].f32: line spacing, in fp.\n
     *
     */
    NODE_TEXT_LINE_SPACING,
    /**
     * @brief  Set the text feature effect and the NODE_FONT_FEATURE attribute,
     * NODE_FONT_FEATURE is the advanced typesetting capability of OpenType
     * Features such as ligatures and equal-width digits are generally used in customized fonts. \n
     * The capabilities need to be supported by the fonts, \n
     * Interfaces for setting, resetting, and obtaining attributes are supported. \n
     * Attribute setting method parameter {@Link ArkUI_AttributeItem} format: \n
     * .string: complies with the text feature format. The format is normal | \n
     * is in the format of [ | on | off],\n.
     * There can be multiple values separated by commas (,). \n
     * For example, the input format of a number with the same width is ss01 on. \n
     * \n
     * Attribute obtaining method return value {@Link ArkUI_AttributeItem} format:\n
     * .string indicates the content of the text feature. Multiple text features are separated by commas (,). \n
     */
    NODE_FONT_FEATURE,
    /**
     * @brief Setting Enable Text Recognition.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32:Enable text recognition, default value false.\n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32：Enable Text Recognition\n
     *
     */
    NODE_TEXT_ENABLE_DATA_DETECTOR,
    /**
     * @brief Set the text recognition configuration.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0...].i32: Array of entity types, parameter types{@link ArkUI_TextDataDetectorType}。\n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0...].i32：Array of entity types, parameter types{@link ArkUI_TextDataDetectorType}。\n
     *
     */
    NODE_TEXT_ENABLE_DATA_DETECTOR_CONFIG,
    /**
     * @brief Defines the background color of the selected text.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].u32: color value, in 0xARGB format. For example, 0xFFFF0000 indicates red. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].u32: color value, in 0xARGB format. \n
     *
     */
    NODE_TEXT_SELECTED_BACKGROUND_COLOR,

    /**
     * @brief The text component uses a formatted string object to set text content properties,
     * and supports property setting, property reset, and property acquisition interfaces.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .object indicates ArkUI_StyledString formatted string data. The parameter type is {@link ArkUI_StyledString}. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .object indicates ArkUI_StyledString formatted string data. The parameter type is {@link ArkUI_StyledString}. \n
     */
    NODE_TEXT_CONTENT_WITH_STYLED_STRING,

    /**
     * @brief Defines the text content attribute, which can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .string: content of the text span. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .string: content of the text span. \n
     *
     */
    NODE_SPAN_CONTENT = MAX_NODE_SCOPE_NUM * ARKUI_NODE_SPAN,
    /**
     * @brief Defines the text background style.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].u32: color of the text background, in 0xARGB format, for example, <b>0xFFFF0000</b> indicating red. \n
     * The second parameter indicates the rounded corners of the text background. Two setting modes are available: \n
     * 1: .value[1].f32: radius of the four corners, in vp. \n
     * 2: .value[1].f32: radius of the upper left corner, in vp. \n
     * .value[2].f32: radius of the upper right corner, in vp. \n
     * .value[3].f32: radius of the lower left corner, in vp. \n
     * .value[4].f32: radius of the lower right corner, in vp. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].u32: color of the text background, in 0xARGB format. \n
     * .value[1].f32: radius of the upper left corner, in vp. \n
     * .value[2].f32: radius of the upper right corner, in vp. \n
     * .value[3].f32: radius of the lower left corner, in vp. \n
     * .value[4].f32: radius of the lower right corner, in vp. \n
     *
     */
    NODE_SPAN_TEXT_BACKGROUND_STYLE,
    /**
     * @brief Defines the text baseline offset attribute
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].f32: baseline offset, in fp.\n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].f32: baseline offset, in fp. \n
     *
     */
    NODE_SPAN_BASELINE_OFFSET,
    /**
     * @brief Defines the image source of the image span.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .string: image address of the image span.\n
     * .object: The parameter type is {@link ArkUI_DrawableDescriptor}. Either .string or .object must be set.\n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .string: image address of the image span.\n
     * .object: The parameter type is {@link ArkUI_DrawableDescriptor}.\n
     *
     */
    NODE_IMAGE_SPAN_SRC = MAX_NODE_SCOPE_NUM * ARKUI_NODE_IMAGE_SPAN,
    /**
     * @brief Defines the alignment mode of the image with the text.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: alignment mode of the image with the text.
     * The value is an enum of {@link ArkUI_ImageSpanAlignment}. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: alignment mode of the image with the text.
     * The value is an enum of {@link ArkUI_ImageSpanAlignment}. \n
     *
     */
    NODE_IMAGE_SPAN_VERTICAL_ALIGNMENT,
    /**
     * @brief Defines the placeholder image source.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .string: placeholder image source. \n
     * .object: The parameter type is {@link ArkUI_DrawableDescriptor}. Either .string or .object must be set.\n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .string: placeholder image source. \n
     * .object: The parameter type is {@link ArkUI_DrawableDescriptor}.\n
     *
     */
    NODE_IMAGE_SPAN_ALT,
    /**
     * @brief Defines the image source of the <Image> component.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .string: image source.\n
     * .object: The parameter type is {@link ArkUI_DrawableDescriptor}. Either .string or .object must be set.\n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .string: image source.\n
     * .object: The parameter type is {@link ArkUI_DrawableDescriptor}.\n
     *
     */
    NODE_IMAGE_SRC = MAX_NODE_SCOPE_NUM * ARKUI_NODE_IMAGE,
    /**
     * @brief Defines how the image is resized to fit its container.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: how the image is resized to fit its container. The value is an enum of {@link ArkUI_ObjectFit}. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: how the image is resized to fit its container. The value is an enum of {@link ArkUI_ObjectFit}. \n
     *
     */
    NODE_IMAGE_OBJECT_FIT,
    /**
     * @brief Defines the interpolation effect of the image.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: interpolation effect of the image. The value is an enum of {@link ArkUI_ImageInterpolation}. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: interpolation effect of the image. The value is an enum of {@link ArkUI_ImageInterpolation}. \n
     *
     */
    NODE_IMAGE_INTERPOLATION,
    /**
     * @brief Defines how the image is repeated.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: how the image is repeated. The value is an enum of {@link ArkUI_ImageRepeat}. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: how the image is repeated. The value is an enum of {@link ArkUI_ImageRepeat}. \n
     *
     */
    NODE_IMAGE_OBJECT_REPEAT,
    /**
     * @brief Defines the color filter of the image.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].f32 to .value[19].f32: filter matrix array. \n
     * .size: 5 x 4 filter array size. \n
     * .object: the pointer to OH_Drawing_ColorFilter. Either .value or .object is set. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].f32 to .value[19].f32: filter matrix array. \n
     * .size: 5 x 4 filter array size. \n
     * .object: the pointer to OH_Drawing_ColorFilter. \n
     *
     */
    NODE_IMAGE_COLOR_FILTER,
    /**
     * @brief Defines the auto resize attribute, which can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32 : whether to resize the image source. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32 : whether to resize the image source. \n
     *
     */
    NODE_IMAGE_AUTO_RESIZE,
    /**
     * @brief Defines the placeholder image source.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .string: placeholder image source. \n
     * .object: The parameter type is {@link ArkUI_DrawableDescriptor}. Either .string or .object must be set.\n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .string: placeholder image source. \n
     * .object: The parameter type is {@link ArkUI_DrawableDescriptor}.\n
     *
     */
    NODE_IMAGE_ALT,
    /**
     * @brief Defines whether the image is draggable.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: whether the image is draggable. The value <b>true</b> means that the image is draggable. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: whether the image is draggable. \n
     *
     */
    NODE_IMAGE_DRAGGABLE,
    /**
     * @brief Defines the image rendering mode. This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: The parameter type is {@link ArkUI_ImageRenderMode}. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: The parameter type is {@link ArkUI_ImageRenderMode}. \n
     *
     */
    NODE_IMAGE_RENDER_MODE,
    /**
     * @brief Defines whether the image display size follows the image source size.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: wheter to follow, true means to follow.\n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: wheter to follow, true means to follow.\n
     *
     */
    NODE_IMAGE_FIT_ORIGINAL_SIZE,
    /**
     * @brief Defines the fill color of the swiper.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].u32: fill color, in 0xARGB format. For example, 0xFFFF0000 indicates red. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].u32: fill color, in 0xARGB format. \n
     *
     */
    NODE_IMAGE_FILL_COLOR,
    /**
     * @brief Sets the resizable image options.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].f32: width of the left edge. The unit is vp. \n
     * .value[1].f32: width of the top edge. The unit is vp. \n
     * .value[2].f32: width of the right edge. The unit is vp. \n
     * .value[3].f32: width of the bottom edge. The unit is vp. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].f32: width of the left edge. The unit is vp. \n
     * .value[1].f32: width of the top edge. The unit is vp. \n
     * .value[2].f32: width of the right edge. The unit is vp. \n
     * .value[3].f32: width of the bottom edge. The unit is vp. \n
     *
     */
    NODE_IMAGE_RESIZABLE,
    /**
     * @brief Defines the color of the component when it is selected.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].u32: background color, in 0xARGB format. For example, 0xFFFF0000 indicates red. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].u32: background color, in 0xARGB format. \n
     *
     */
    NODE_TOGGLE_SELECTED_COLOR = MAX_NODE_SCOPE_NUM * ARKUI_NODE_TOGGLE,
    /**
     * @brief Defines the color of the circular slider for the component of the switch type.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].u32: color of the circular slider, in 0xARGB format. For example, 0xFFFF0000 indicates red. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].u32: color of the circular slider, in 0xARGB format. \n
     *
     */
    NODE_TOGGLE_SWITCH_POINT_COLOR,
    /**
     * @brief Defines the toggle switch value. This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: whether to enable the toggle. The value <b>true</b> means to enable the toggle. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: whether to enable the toggle. \n
     *
     */
    NODE_TOGGLE_VALUE,

    /**
     * @brief Defines the color of the component when it is deselected.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     *.value[0].u32: background color, in 0xARGB format. For example, 0xFFFF0000 indicates red. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].u32: background color, in 0xARGB format. \n
     *
     */
    NODE_TOGGLE_UNSELECTED_COLOR,

    /**
     * @brief Defines the foreground color of the loading progress bar.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].u32: foreground color, in 0xARGB format. For example, 0xFFFF0000 indicates red. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].u32: foreground color, in 0xARGB format. \n
     *
     */
    NODE_LOADING_PROGRESS_COLOR = MAX_NODE_SCOPE_NUM * ARKUI_NODE_LOADING_PROGRESS,
    /**
     * @brief Defines whether to show the loading animation for the <LoadingProgress> component.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: whether to show the loading animation.
     * The value <b>true</b> means to show the loading animation, and <b>false</b> means the opposite.\n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: The value <b>1</b> means to show the loading animation, and <b>0</b> means the opposite. \n
     *
     */
    NODE_LOADING_PROGRESS_ENABLE_LOADING,

    /**
     * @brief Defines the default placeholder text of the single-line text box.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .string: default placeholder text. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .string: default placeholder text. \n
     *
     */
    NODE_TEXT_INPUT_PLACEHOLDER = MAX_NODE_SCOPE_NUM * ARKUI_NODE_TEXT_INPUT,
    /**
     * @brief Defines the default text content of the single-line text box.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .string: default text content. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .string: default text content. \n
     *
     */
    NODE_TEXT_INPUT_TEXT,
    /**
     * @brief Defines the caret color attribute.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].u32: caret color, in 0xARGB format. For example, 0xFFFF0000 indicates red.\n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].u32: caret color, in 0xARGB format. \n
     *
     */
    NODE_TEXT_INPUT_CARET_COLOR,
    /**
     * @brief Defines the caret style attribute.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].f32: caret width, in vp.\n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].f32: caret width, in vp. \n
     *
     */
    NODE_TEXT_INPUT_CARET_STYLE,
    /**
     * @brief Defines the underline attribute of the single-line text box.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: whether to show an underline.
     * The value <b>true</b> means to show an underline, and <b>false</b> means the opposite.\n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: The value <b>1</b> means to show an underline, and <b>0</b> means the opposite. \n
     *
     */
    NODE_TEXT_INPUT_SHOW_UNDERLINE,
    /**
     * @brief Defines the maximum number of characters in the text input.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: maximum number of characters in the text input, without a unit. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: maximum number of characters in the text input. \n
     *
     */
    NODE_TEXT_INPUT_MAX_LENGTH,
    /**
     * @brief Defines the type of the Enter key.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: type of the Enter key{@link ArkUI_EnterKeyType}. The default value is <b>ARKUI_ENTER_KEY_TYPE_DONE</b>. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: type of the Enter key{@link ArkUI_EnterKeyType}. \n
     *
     */
    NODE_TEXT_INPUT_ENTER_KEY_TYPE,
    /**
     * @brief Defines the placeholder text color.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].u32: color value, in 0xARGB format. For example, 0xFFFF0000 indicates red. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].u32: color value, in 0xARGB format. \n
     *
     */
    NODE_TEXT_INPUT_PLACEHOLDER_COLOR,
    /**
     * @brief Defines the placeholder text font.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0]?.f32: font size, in fp. Optional. The default value is <b>16.0</b>.\n
     * .value[1]?.i32: font style {@link ArkUI_FontStyle}. Optional.
     * The default value is <b>ARKUI_FONT_STYLE_NORMAL</b>. \n
     * .value[2]?.i32: font weight {@link ArkUI_FontWeight}. Optional.
     * The default value is <b>ARKUI_FONT_WEIGHT_NORMAL</b>. \n
     * ?.string: font family. Multiple font families are separated by commas (,).
     * Example: "font weight; font family 1, font family 2". \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].f32: font size, in fp.\n
     * .value[1].i32: font style {@link ArkUI_FontStyle}.\n
     * .value[2].i32: font weight {@link ArkUI_FontWeight}.\n
     * .string: font family. Multiple font families are separated by commas (,). \n
     *
     */
    NODE_TEXT_INPUT_PLACEHOLDER_FONT,
    /**
     * @brief Defines whether to enable the input method when the component obtains focus.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: whether to enable the input method when the component obtains focus.
     * The value <b>true</b> means to enable the input method, and <b>false</b> means the opposite.\n \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
      * .value[0].i32: The value <b>1</b> means to enable the input method when the component obtains focus,
      * and <b>0</b> means the opposite. \n
     *
     */
    NODE_TEXT_INPUT_ENABLE_KEYBOARD_ON_FOCUS,
    /**
     * @brief Defines the text box type. This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: text box type {@link ArkUI_TextInputType}.
     * The default value is <b>ARKUI_TEXTINPUT_TYPE_NORMAL</b>. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: text box type {@link ArkUI_TextInputType}. \n
     *
     */
    NODE_TEXT_INPUT_TYPE,
    /**
     * @brief Defines the background color of the selected text.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].u32: color value, in 0xARGB format. For example, 0xFFFF0000 indicates red. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].u32: color value, in 0xARGB format. \n
     *
     */
    NODE_TEXT_INPUT_SELECTED_BACKGROUND_COLOR,
    /**
     * @brief Defines whether to display the password icon at the end of the password text box.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: whether to display the password icon at the end of the password text box.
     * The value <b>true</b> means to display the password icon, and <b>false</b> means the opposite.\n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: The value <b>1</b> means to display the password icon at the end of the password text box,
     * and <b>0</b> means the opposite. \n
     *
     */
    NODE_TEXT_INPUT_SHOW_PASSWORD_ICON,
    /**
     * @brief Defines the editable state for the single-line text box.
     * This attribute can be set as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute: \n
     * .value[0].i32: whether to remain in the editable state. The value
     * <b>true</b> means to remain in the editable state, and <b>false</b> means to exit the editable state. \n
     * \n
     * Format of the {@link ArkUI_AttributeItem} parameter for obtaining the attribute:
     * .value[0].i32: whether to remain in the editable state. The value <b>true</b> means to remain in the editable
     * state, and <b>false</b> means to exit the editable state. \n
     *
     */
    NODE_TEXT_INPUT_EDITING,
    /**
     * @brief Defines the style of the cancel button on the right of the single-line text box.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute: \n
     * .value[0].i32: button style {@link ArkUI_CancelButtonStyle}.
     * The default value is <b>ARKUI_CANCELBUTTON_STYLE_INPUT</b>.\n
     * .value[1]?.f32: button icon size, in vp.\n
     * .value[2]?.u32: button icon color, in 0xARGB format. For example, 0xFFFF0000 indicates red. \n
     * ?.string: button icon image source. The value is the local address of the image, for example, /pages/icon.png. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: button style {@link ArkUI_CancelButtonStyle}.\n
     * .value[1].f32: icon size, in vp.\n
     * .value[2].u32: button icon color, in 0xARGB format.\n
     * .string: button icon image source. \n
     *
     */
    NODE_TEXT_INPUT_CANCEL_BUTTON,
    /**
     * @brief Sets the text selection area, which will be highlighted.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: start position of the text selection. \n
     * .value[1].i32: end position of the text selection. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: start position of the text selection. \n
     * .value[1].i32: end position of the text selection. \n
     *
     */
    NODE_TEXT_INPUT_TEXT_SELECTION,
    /**
    * @brief Sets the color of the text underline when it is enabled.
    *
    * The default underline color configured for the theme is <b>'0x33182431'</b>.
    *
    * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
    * .value[0].u32: color of the underline applied to the text being typed in.
    * The value is in 0xARGB format. \n
    * .value[1].u32: color of the underline applied to the text in the normal state.
    * The value is in 0xARGB format. \n
    * .value[2].u32: color of the underline applied to the text when an error is detected.
    * The value is in 0xARGB format. \n
    * .value[3].u32: color of the underline applied to the text when it is disabled.
    * The value is in 0xARGB format. \n
    * \n
    * Format of the return value {@link ArkUI_AttributeItem}:\n
    * .value[0].u32: color of the underline applied to the text being typed in. The value is in 0xARGB format. \n
    * .value[1].u32: color of the underline applied to the text in the normal state. The value is in 0xARGB format. \n
    * .value[2].u32: color of the underline applied to the text when an error is detected.
    * The value is in 0xARGB format. \n
    * .value[3].u32: color of the underline applied to the text when it is disabled. The value is in 0xARGB format. \n
    *
    */
    NODE_TEXT_INPUT_UNDERLINE_COLOR,
    /**
    * @brief Sets whether to enable autofill.
    *
    * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
    * .value[0].i32: whether to enable autofill. The default value is <b>true</b>. \n
    * \n
    * Format of the return value {@link ArkUI_AttributeItem}:\n
    * .value[0].i32: whether to enable autofill. \n
    *
    */
    NODE_TEXT_INPUT_ENABLE_AUTO_FILL,
    /**
    * @brief Sets the autofill type.
    *
    * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
    * .value[0].i32: autofill type. The parameter type is {@link ArkUI_TextInputContentType}. \n
    * \n
    * Format of the return value {@link ArkUI_AttributeItem}:\n
    * .value[0].i32: autofill type. The parameter type is {@link ArkUI_TextInputContentType}. \n
    *
    */
    NODE_TEXT_INPUT_CONTENT_TYPE,
    /**
    * @brief Defines the rules for generating passwords. When autofill is used, these rules are transparently
    * transmitted to Password Vault for generating a new password.
    *
    * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
    * .string: rules for generating passwords. \n
    * \n
    * Format of the return value {@link ArkUI_AttributeItem}:\n
    * .string: rules for generating passwords. \n
    *
    */
    NODE_TEXT_INPUT_PASSWORD_RULES,
    /**
    * @brief Sets whether to select all text in the initial state. The inline mode is not supported.
    *
    * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
    * .value[0].i32: whether to select all text in the initial state. The default value is b>false</b>. \n
    * \n
    * Format of the return value {@link ArkUI_AttributeItem}:\n
    * .value[0].i32: whether to select all text in the initial state. \n
    *
    */
    NODE_TEXT_INPUT_SELECT_ALL,
    /**
    * @brief Sets the regular expression for input filtering.
    * Only inputs that comply with the regular expression can be displayed.
    * Other inputs are filtered out. The specified regular expression can match single characters,
    * but not strings.
    *
    * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
    * .string: regular expression. \n
    * \n
    * Format of the return value {@link ArkUI_AttributeItem}:\n
    * .string: regular expression. \n
    *
    */
    NODE_TEXT_INPUT_INPUT_FILTER,
    /**
    * @brief Sets the text box to the default style or inline input style.
    *
    * For the inline input style, only <b>InputType.Normal</b> is supported.
    *
    * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
    * .value[0].i32: text input style. The parameter type is {@link ArkUI_TextInputStyle}. \n
    * \n
    * Format of the return value {@link ArkUI_AttributeItem}:\n
    * .value[0].i32: text input style. The parameter type is {@link ArkUI_TextInputStyle}. \n
    *
    */
    NODE_TEXT_INPUT_STYLE,
    /**
    * @brief Sets or obtains the caret position.
    *
    * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
    * In the case of setting the caret position:
    * .value[0].i32: character count from the beginning of a string to the caret position. \n
    * 
    * Format of the return value {@link ArkUI_AttributeItem}:\n
    * In the case of obtaining the caret position: If this API is called when the caret position is updated in the
    * current frame, it will not take effect.
    * .value[0].i32: index of the caret position. \n
    * .value[1].f32: X coordinate of the caret relative to the text box. \n
    * .value[2].f32: Y coordinate of the caret relative to the text box. \n
    */
    NODE_TEXT_INPUT_CARET_OFFSET,
    /**
    * @brief Obtains the position of the edited text area relative to the component and its size.
    * 
    * Format of the return value {@link ArkUI_AttributeItem}:\n
    * .value[0].f32: horizontal coordinate. \n
    * .value[1].f32: vertical coordinate. \n
    * .value[2].f32: content width. \n
    * .value[3].f32: content height. \n
    *
    */
    NODE_TEXT_INPUT_CONTENT_RECT,
    /**
    * @brief Obtains the number of lines of the edited text.
    * 
    * Format of the return value {@link ArkUI_AttributeItem}:\n
    * .value[0].i32: number of lines of the edited text. \n
    *
    */
    NODE_TEXT_INPUT_CONTENT_LINE_COUNT,
    /**
     * @brief Sets whether to hide the text selection menu when the text box is long-pressed, double-click, or
     * right-clicked. This attribute can be set, reset, and obtained as required through APIs.
     * 
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: whether to hide the text selection menu when the text box is long-pressed, double-click, or
     * right-clicked. The default value is <b>false</b>. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: whether to hide the text selection menu when the text box is long-pressed, double-click, or
     * right-clicked. \n
     *
     */
    NODE_TEXT_INPUT_SELECTION_MENU_HIDDEN,
    /**
     * @brief Sets whether the text box loses focus after the Enter key is pressed to submit information.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: whether the text box loses focus. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: whether the text box loses focus. \n
     *
     */
    NODE_TEXT_INPUT_BLUR_ON_SUBMIT,
    /**
     * @brief Set up a custom keyboard.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .object：custom keyboard,The parameter type is{@Link ArkUI_NodeHandle}。\n
     * .value[0]?.i32：Sets whether the custom keyboard supports the avoidance feature, default value false.\n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .object:custom keyboard,The parameter type is{@Link ArkUI_NodeHandle}。\n
     * .value[0].i32：Set whether the custom keyboard supports the avoidance function.\n
     *
     */
    NODE_TEXT_INPUT_CUSTOM_KEYBOARD,
    /**
     * @brief Defines the line break rule. This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: The parameter type is {@link ArkUI_WordBreak}. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: The parameter type is {@link ArkUI_WordBreak}. \n
     *
     */
    NODE_TEXT_INPUT_WORD_BREAK,

    /**
     * @brief Sets whether the keyboard pops up when the input box gains focus.
     * It supports property setting, property reset and property acquisition interfaces.
     *
     * Attribute setting method parameter {@link ArkUI_AttributeItem} format:\n
     * .value[0].i32: Whether to pop up the keyboard. \n
     * \n
     * Attribute acquisition method return value {@link ArkUI_AttributeItem} format: \n
     * .value[0].i32: Whether to pop up the keyboard. \n
     *
     */
    NODE_TEXT_INPUT_SHOW_KEYBOARD_ON_FOCUS,

    /**
     * @brief When this property is set, the height of the textInput component is calculated using this property.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: set the value of numberOfLines.\n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: the value of numberOfLines.\n
     *
     */
    NODE_TEXT_INPUT_NUMBER_OF_LINES,

    /**
     * @brief Defines the default placeholder text for the multi-line text box.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .string: default placeholder text. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .string: default placeholder text. \n
     *
     */
    NODE_TEXT_AREA_PLACEHOLDER = MAX_NODE_SCOPE_NUM * ARKUI_NODE_TEXT_AREA,
    /**
     * @brief Defines the default text content for the multi-line text box.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .string: default text content. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .string: default text content. \n
     *
     */
    NODE_TEXT_AREA_TEXT,
    /**
     * @brief Defines the maximum number of characters in the text input.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: maximum number of characters in the text input. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: maximum number of characters in the text input. \n
     *
     */
    NODE_TEXT_AREA_MAX_LENGTH,
    /**
     * @brief Defines the placeholder text color.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].u32: color value, in 0xARGB format. For example, 0xFFFF0000 indicates red. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].u32: color value, in 0xARGB format. \n
     *
     */
    NODE_TEXT_AREA_PLACEHOLDER_COLOR,
    /**
     * @brief Defines the placeholder text font.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0]?.f32: font size, in fp. Optional. The default value is <b>16.0</b>.\n
     * .value[1]?.i32: font style {@link ArkUI_FontStyle}. Optional. The default value is <b>ARKUI_FONT_STYLE_NORMAL</b>.\n
     * .value[2]?.i32: font weight {@link ArkUI_FontWeight}. Optional. The default value is <b>ARKUI_FONT_WEIGHT_NORMAL</b>.\n
     * ?.string: font family. Multiple font families are separated by commas (,). For example, "font weight; font family 1, font family 2". \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].f32: font size, in fp.\n
     * .value[1].i32: font style {@link ArkUI_FontStyle}.\n
     * .value[2].i32: font weight {@link ArkUI_FontWeight}.\n
     * .string: font family. Multiple font families are separated by commas (,). \n
     *
     */
    NODE_TEXT_AREA_PLACEHOLDER_FONT,
    /**
     * @brief Defines the caret color attribute.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].u32: background color, in 0xARGB format. For example, 0xFFFF0000 indicates red. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].u32: background color, in 0xARGB format. \n
     *
     */
    NODE_TEXT_AREA_CARET_COLOR,
    /**
     * @brief Defines the editable state for the multi-line text box.
     * This attribute can be set as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: whether to remain in the editable state. The value <b>true</b> means to remain in the
     * editable state, and <b>false</b> means to exit the editable state.\n \n
     * \n
     * Format of the {@link ArkUI_AttributeItem} parameter for obtaining the attribute:
     * .value[0].i32: whether to remain in the editable state. The value <b>true</b> means to remain in the editable
     * state, and <b>false</b> means to exit the editable state.\n \n
     *
     */
    NODE_TEXT_AREA_EDITING,
    /**
     * @brief Defines the text box type. This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: text box type {@link ArkUI_TextAreaType}.
     * The default value is <b>ARKUI_TEXTAREA_TYPE_NORMAL</b>. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: text box type {@link ArkUI_TextAreaType}. \n
     *
     */
    NODE_TEXT_AREA_TYPE,
    /**
     * @brief Defines the counter settings. This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: whether to show a character counter. The value <b>true</b> means to show a character counter. \n
     * .value[1]?.f32: threshold percentage for displaying the character counter. The character counter is displayed
     * when the number of characters that have been entered is greater than the maximum number of characters multiplied
     * by the threshold percentage value. The value range is 1 to 100. If the value is a decimal, it is rounded down. \n
     * .value[2]?.i32: whether to highlight the border when the number of entered characters reaches the maximum. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: whether to show a character counter. \n
     * .value[1].f32: threshold percentage for displaying the character counter. The character counter is displayed
     * when the number of characters that have been entered is greater than the maximum number of characters multiplied
     * by the threshold percentage value. The value range is 1 to 100. \n
     * .value[2].i32: whether to highlight the border when the number of entered characters reaches the maximum.
     * The default value is <b>true</b>. \n
     *
     */
    NODE_TEXT_AREA_SHOW_COUNTER,
    /**
     * @brief Sets whether to hide the text selection menu when the text box is long-pressed, double-click,
     * or right-clicked. This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: whether to hide the text selection menu when the text box is long-pressed, double-click,
     * or right-clicked. The default value is <b>false</b>. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: whether to hide the text selection menu when the text box is long-pressed, double-click,
     * or right-clicked. \n
     *
     */
    NODE_TEXT_AREA_SELECTION_MENU_HIDDEN,
    /**
     * @brief Sets whether the multi-line text box loses focus after the Enter key is pressed to submit information.
     * 
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: whether the text box loses focus. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: whether the text box loses focus. \n
     *
     */
    NODE_TEXT_AREA_BLUR_ON_SUBMIT,
    /**
     * @brief Sets the regular expression for input filtering.
     * Only inputs that comply with the regular expression can be displayed.
     * Other inputs are filtered out. The specified regular expression can match single characters,
     * but not strings.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .string: regular expression. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .string: regular expression. \n
     *
     */
    NODE_TEXT_AREA_INPUT_FILTER,
    /**
     * @brief Defines the background color of the selected text.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].u32: color value, in 0xARGB format. For example, 0xFFFF0000 indicates red. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].u32: color value, in 0xARGB format. \n
     *
     */
    NODE_TEXT_AREA_SELECTED_BACKGROUND_COLOR,
    /**
     * @brief Defines the type of the Enter key.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: type of the Enter key{@link ArkUI_EnterKeyType}. The default value is <b>ARKUI_ENTER_KEY_TYPE_DONE</b>. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: type of the Enter key{@link ArkUI_EnterKeyType}. \n
     *
     */
    NODE_TEXT_AREA_ENTER_KEY_TYPE,
    /**
     * @brief Defines whether to enable the input method when the component obtains focus.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: whether to enable the input method when the component obtains focus.
     * The value <b>true</b> means to enable the input method, and <b>false</b> means the opposite.\n \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: The value <b>1</b> means to enable the input method when the component obtains focus,
     * and <b>0</b> means the opposite. \n
     *
     */
    NODE_TEXT_AREA_ENABLE_KEYBOARD_ON_FOCUS,
    /**
     * @brief Defines whether to enable the input method when the component obtains focus.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: whether to enable the input method when the component obtains focus.
     * The value <b>true</b> means to enable the input method, and <b>false</b> means the opposite.\n \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: The value <b>1</b> means to enable the input method when the component obtains focus,
     * and <b>0</b> means the opposite. \n
     *
     */
    NODE_TEXT_AREA_CARET_OFFSET,
    /**
     * @brief Obtains the position of the edited text area relative to the component and its size.
     * 
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].f32: horizontal coordinate. \n
     * .value[1].f32: vertical coordinate. \n
     * .value[2].f32: content width. \n
     * .value[3].f32: content height. \n
     *
     */
    NODE_TEXT_AREA_CONTENT_RECT,
    /**
     * @brief Obtains the number of lines of the edited text.
     * 
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: number of lines of the edited text. \n
     *
     */
    NODE_TEXT_AREA_CONTENT_LINE_COUNT,
    /**
     * @brief Sets the text selection area, which will be highlighted.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: start position of the text selection. \n
     * .value[1].i32: end position of the text selection. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: start position of the text selection. \n
     * .value[1].i32: end position of the text selection. \n
     *
     */
    NODE_TEXT_AREA_TEXT_SELECTION,
    /**
     * @brief Sets whether to enable autofill.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: whether to enable autofill. The default value is <b>true</b>. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: whether to enable autofill. \n
     *
     */
    NODE_TEXT_AREA_ENABLE_AUTO_FILL,
    /**
     * @brief Sets the autofill type.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: autofill type. The parameter type is {@link ArkUI_TextInputContentType}. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: autofill type. The parameter type is {@link ArkUI_TextInputContentType}. \n
     *
     */
    NODE_TEXT_AREA_CONTENT_TYPE,

    /**
     * @brief Sets whether the keyboard pops up when the input box gains focus.
     * It supports property setting, property reset and property acquisition interfaces.
     *
     * Attribute setting method parameter {@link ArkUI_AttributeItem} format:\n
     * .value[0].i32: Whether to pop up the keyboard. \n
     * \n
     * Attribute acquisition method return value {@link ArkUI_AttributeItem} format: \n
     * .value[0].i32: Whether to pop up the keyboard. \n
     *
     */
    NODE_TEXT_AREA_SHOW_KEYBOARD_ON_FOCUS,

    /**
     * @brief When this property is set, the height of the textArea component is calculated using this property.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: set the value of numberOfLines.\n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: Set the value of numberOfLines\n
     *
     */
    NODE_TEXT_AREA_NUMBER_OF_LINES,
    /**
     * @brief Defines the button text content. This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .string: default text content. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .string: default text content. \n
     *
     */
    NODE_BUTTON_LABEL = MAX_NODE_SCOPE_NUM * ARKUI_NODE_BUTTON,

    /**
     * @brief Sets the button type. This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: button type. The parameter type is {@link ArkUI_ButtonType}.
     * The default value is <b>ARKUI_BUTTON_TYPE_CAPSULE</b>. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: button type. The parameter type is {@link ArkUI_ButtonType}.
     * The default value is <b>ARKUI_BUTTON_TYPE_CAPSULE</b>. \n
     *
     */
    NODE_BUTTON_TYPE,

    /**
     * @brief Defines the current value of the progress indicator.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].f32: current value of the progress indicator. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].f32: current value of the progress indicator. \n
     *
     */
    NODE_PROGRESS_VALUE = MAX_NODE_SCOPE_NUM * ARKUI_NODE_PROGRESS,
    /**
     * @brief Defines the total value of the progress indicator.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].f32: total value of the progress indicator. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].f32: total value of the progress indicator. \n
     *
     */
    NODE_PROGRESS_TOTAL,
    /**
     * @brief Defines the color for the progress value on the progress indicator.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].u32: color value, in 0xARGB format. For example, 0xFFFF0000 indicates red. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].u32: color value, in 0xARGB format. \n
     *
     */
    NODE_PROGRESS_COLOR,
    /**
     * @brief Defines the type of the progress indicator.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: type of the progress indicator {@link ArkUI_ProgressType}.
     * The default value is <b>ARKUI_PROGRESS_TYPE_LINEAR</b>. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: type of the progress indicator {@link ArkUI_ProgressType}. \n
     *
     */
    NODE_PROGRESS_TYPE,

    /**
     * @brief Defines whether the check box is selected.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: whether the check box is selected.
     * The value <b>1</b> means that the check box is selected, and <b>0</b> means the opposite. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: The value <b>1</b> means that the check box is selected, and <b>0</b> means the opposite. \n
     * 
     */
    NODE_CHECKBOX_SELECT = MAX_NODE_SCOPE_NUM * ARKUI_NODE_CHECKBOX,

    /**
     * @brief Defines the color of the check box when it is selected.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].u32: color of the check box when it is selected, in 0xARGB format, for example, <b>0xFF1122FF</b>. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].u32: color of the check box when it is selected, in 0xARGB format, for example, <b>0xFF1122FF</b>.
     *
     */
    NODE_CHECKBOX_SELECT_COLOR,

    /**
     * @brief Defines the border color of the check box when it is not selected.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].u32: border color, in 0xARGB format, for example, <b>0xFF1122FF</b>. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].u32: border color, in 0xARGB format, for example, <b>0xFF1122FF</b>.
     * 
     */
    NODE_CHECKBOX_UNSELECT_COLOR,

    /**
     * @brief Defines the internal icon style of the check box.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].u32: border color, in 0xARGB format, for example, <b>0xFF1122FF</b>.\n
     * .value[1]?.f32: size of the internal mark, in vp. Optional.\n
     * .value[2]?.f32: stroke width of the internal mark, in vp. Optional. The default value is <b>2</b>. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].u32: border color, in 0xARGB format, for example, <b>0xFF1122FF</b>.\n
     * .value[1].f32: size of the internal mark, in vp. \n
     * .value[2].f32: stroke width of the internal mark, in vp. The default value is <b>2</b>. \n
     *
     */
    NODE_CHECKBOX_MARK,

    /**
     * @brief Defines the shape of the check box.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: component shape. The parameter type is {@link ArkUI_CheckboxShape}. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: component shape. The parameter type is {@link ArkUI_CheckboxShape}.
     *
     */
    NODE_CHECKBOX_SHAPE,

    /**
     * @brief Defines the ID of the <b><XComponent></b> component.
     * This attribute can be set and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .string: component ID. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .string: component ID. \n
     *
     */
    NODE_XCOMPONENT_ID = MAX_NODE_SCOPE_NUM * ARKUI_NODE_XCOMPONENT,
    /**
     * @brief Defines the type of the <b><XComponent></b> component.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: type {@link ArkUI_XComponentType}. The default value is <b>ARKUI_XCOMPONENT_TYPE_SURFACE</b>. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: type {@link ArkUI_XComponentType}. \n
     *
     */
    NODE_XCOMPONENT_TYPE,
    /**
     * @brief Defines the width and height of the <b><XComponent></b> component.
     * This attribute can be set and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].u32: width, in px. \n
     * .value[1].u32: height, in px. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].u32: width, in px. \n
     * .value[1].u32: height, in px. \n
     *
     */
    NODE_XCOMPONENT_SURFACE_SIZE,

    /**
     * @brief Defines whether to display the lunar calendar in the date picker.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: whether to display the lunar calendar in the date picker. The default value is <b>false</b>. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: whether to display the lunar calendar in the date picker.
     *
     */
    NODE_DATE_PICKER_LUNAR = MAX_NODE_SCOPE_NUM * ARKUI_NODE_DATE_PICKER,
    /**
     * @brief Defines the start date of the date picker.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .string: date. The default value is <b>"1970-1-1"</b>. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .string: date. \n
     *
     */
    NODE_DATE_PICKER_START,
    /**
     * @brief Defines the end date of the date picker.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .string: date. The default value is <b>"2100-12-31"</b>. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .string: date. \n
     *
     */
    NODE_DATE_PICKER_END,
    /**
     * @brief Defines the selected date of the date picker.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .string: date. The default value is <b>"2024-01-22"</b>. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .string: date.
     *
     */
    NODE_DATE_PICKER_SELECTED,
    /**
     * @brief Defines the font color, font size, and font weight for the top and bottom items in the date picker.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .string: array of five parameters of the string type, separated by semicolons (;).\n
     * Parameter 1: font color, in #ARGB format.\n
     * Parameter 2: font size, in fp. The value is a number.\n
     * Parameter 3: font weight. Available options are ("bold", "normal", "bolder", "lighter", "medium", "regular").\n.
     * Parameter 4: fonts, separated by commas (,).\n
     * Parameter 5: font style. Available options are ("normal", "italic").\n
     * Example: "#ff182431;14;normal;Arial,HarmonyOS Sans;normal". \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .string: array of five parameters of the string type, separated by semicolons (;).\n
     * Parameter 1: font color, in #ARGB format.\n
     * Parameter 2: font size, in fp. The value is a number.\n
     * Parameter 3: font weight. Available options are ("bold", "normal", "bolder", "lighter", "medium", "regular").\n.
     * Parameter 4: fonts, separated by commas (,).\n
     * Parameter 5: font style. Available options are ("normal", "italic").\n
     * Example: "#ff182431;14;normal;Arial,HarmonyOS Sans;normal". \n
     *
     */
    NODE_DATE_PICKER_DISAPPEAR_TEXT_STYLE,
    /**
     * @brief Defines the font color, font size, and font weight of all items except the top, bottom, and selected
     * items in the date picker. This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .string: array of five parameters of the string type, separated by semicolons (;).\n
     * Parameter 1: font color, in #ARGB format.\n
     * Parameter 2: font size, in fp. The value is a number.\n
     * Parameter 3: font weight. Available options are ("bold", "normal", "bolder", "lighter", "medium", "regular").\n.
     * Parameter 4: fonts, separated by commas (,).\n
     * Parameter 5: font style. Available options are ("normal", "italic").\n
     * Example: "#ff182431;14;normal;Arial,HarmonyOS Sans;normal". \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .string: array of five parameters of the string type, separated by semicolons (;).\n
     * Parameter 1: font color, in #ARGB format.\n
     * Parameter 2: font size, in fp. The value is a number.\n
     * Parameter 3: font weight. Available options are ("bold", "normal", "bolder", "lighter", "medium", "regular").\n.
     * Parameter 4: fonts, separated by commas (,).\n
     * Parameter 5: font style. Available options are ("normal", "italic").\n
     * Example: "#ff182431;14;normal;Arial,HarmonyOS Sans;normal". \n
     *
     */
    NODE_DATE_PICKER_TEXT_STYLE,
    /**
     * @brief Defines the font color, font size, and font weight of the selected item in the date picker.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .string: array of five parameters of the string type, separated by semicolons (;).\n
     * Parameter 1: font color, in #ARGB format.\n
     * Parameter 2: font size, in fp. The value is a number.\n
     * Parameter 3: font weight. Available options are ("bold", "normal", "bolder", "lighter", "medium", "regular").\n.
     * Parameter 4: fonts, separated by commas (,).\n
     * Parameter 5: font style. Available options are ("normal", "italic").\n
     * Example: "#ff182431;14;normal;Arial,HarmonyOS Sans;normal". \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .string: array of five parameters of the string type, separated by semicolons (;).\n
     * Parameter 1: font color, in #ARGB format.\n
     * Parameter 2: font size, in fp. The value is a number.\n
     * Parameter 3: font weight. Available options are ("bold", "normal", "bolder", "lighter", "medium", "regular").\n.
     * Parameter 4: fonts, separated by commas (,).\n
     * Parameter 5: font style. Available options are ("normal", "italic").\n
     * Example: "#ff182431;14;normal;Arial,HarmonyOS Sans;normal". \n
     *
     */
    NODE_DATE_PICKER_SELECTED_TEXT_STYLE,
    /**
     * @brief Defines the time of the selected item. in the timer picker.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .string: time. The default value is the current system time. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .string: time.
     *
     */

    NODE_TIME_PICKER_SELECTED = MAX_NODE_SCOPE_NUM * ARKUI_NODE_TIME_PICKER,
    /**
     * @brief Defines whether the display time is in 24-hour format.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: whether the display time is in 24-hour format. The default value is <b>false</b>. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: whether the display time is in 24-hour format.
     *
     */
    NODE_TIME_PICKER_USE_MILITARY_TIME,
    /**
     * @brief Defines the font color, font size, and font weight for the top and bottom items in the time picker.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .string: array of five parameters of the string type, separated by semicolons (;).\n
     * Parameter 1: font color, in #ARGB format.\n
     * Parameter 2: font size, in fp. The value is a number.\n
     * Parameter 3: font weight. Available options are ("bold", "normal", "bolder", "lighter", "medium", "regular").\n.
     * Parameter 4: fonts, separated by commas (,).\n
     * Parameter 5: font style. Available options are ("normal", "italic").\n
     * Example: "#ff182431;14;normal;Arial,HarmonyOS Sans;normal". \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .string: array of five parameters of the string type, separated by semicolons (;).\n
     * Parameter 1: font color, in #ARGB format.\n
     * Parameter 2: font size, in fp. The value is a number.\n
     * Parameter 3: font weight. Available options are ("bold", "normal", "bolder", "lighter", "medium", "regular").\n.
     * Parameter 4: fonts, separated by commas (,).\n
     * Parameter 5: font style. Available options are ("normal", "italic").\n
     * Example: "#ff182431;14;normal;Arial,HarmonyOS Sans;normal". \n
     *
     */
    NODE_TIME_PICKER_DISAPPEAR_TEXT_STYLE,
    /**
     * @brief Defines the font color, font size, and font weight of all items except the top, bottom, and selected items
     * in the time picker. This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .string: array of five parameters of the string type, separated by semicolons (;).\n
     * Parameter 1: font color, in #ARGB format.\n
     * Parameter 2: font size, in fp. The value is a number.\n
     * Parameter 3: font weight. Available options are ("bold", "normal", "bolder", "lighter", "medium", "regular").\n.
     * Parameter 4: fonts, separated by commas (,).\n
     * Parameter 5: font style. Available options are ("normal", "italic").\n
     * Example: "#ff182431;14;normal;Arial,HarmonyOS Sans;normal". \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .string: array of five parameters of the string type, separated by semicolons (;).\n
     * Parameter 1: font color, in #ARGB format.\n
     * Parameter 2: font size, in fp. The value is a number.\n
     * Parameter 3: font weight. Available options are ("bold", "normal", "bolder", "lighter", "medium", "regular").\n.
     * Parameter 4: fonts, separated by commas (,).\n
     * Parameter 5: font style. Available options are ("normal", "italic").\n
     * Example: "#ff182431;14;normal;Arial,HarmonyOS Sans;normal". \n
     *
     */
    NODE_TIME_PICKER_TEXT_STYLE,
    /**
     * @brief Defines the font color, font size, and font weight of the selected item in the time picker.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .string: array of five parameters of the string type, separated by semicolons (;).\n
     * Parameter 1: font color, in #ARGB format.\n
     * Parameter 2: font size, in fp. The value is a number.\n
     * Parameter 3: font weight. Available options are ("bold", "normal", "bolder", "lighter", "medium", "regular").\n.
     * Parameter 4: fonts, separated by commas (,).\n
     * Parameter 5: font style. Available options are ("normal", "italic").\n
     * Example: "#ff182431;14;normal;Arial,HarmonyOS Sans;normal". \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .string: array of five parameters of the string type, separated by semicolons (;).\n
     * Parameter 1: font color, in #ARGB format.\n
     * Parameter 2: font size, in fp. The value is a number.\n
     * Parameter 3: font weight. Available options are ("bold", "normal", "bolder", "lighter", "medium", "regular").\n.
     * Parameter 4: fonts, separated by commas (,).\n
     * Parameter 5: font style. Available options are ("normal", "italic").\n
     * Example: "#ff182431;14;normal;Arial,HarmonyOS Sans;normal". \n
     *
     */
    NODE_TIME_PICKER_SELECTED_TEXT_STYLE,

    /**
     * @brief Defines the data selection range of the text picker.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: type of the text picker {@link ArkUI_TextPickerRangeType}.
     * The default value is <b>ARKUI_TEXTPICKER_RANGETYPE_SINGLE</b>. \n
     * ?.string: string input, whose format varies by picker type.\n
     * 1: single-column picker. The input format is a group of strings separated by semicolons (;).\n
     * 2: multi-column picker. Multiple pairs of plain text strings are supported. The pairs are separated by
     * semicolons (;), and strings within each pair are separated by commas (,). \n
     * ?.object: Object input, whose format varies by picker type.\n
     * 1: single-column picker with image support. The input structure is {@link ARKUI_TextPickerRangeContent}.\n
     * 2: multi-column interconnected picker. The input structure is {@link ARKUI_TextPickerCascadeRangeContent}.\n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: type of the text picker {@link ArkUI_TextPickerRangeType}.\n
     * ?.string: string output, whose format varies by picker type.\n
     * 1: single-column picker. The output format is a group of strings separated by semicolons (;).\n
     * 2: multi-column picker. Multiple pairs of plain text strings are supported. The pairs are separated by
     * semicolons (;), and strings within each pair are separated by commas (,). \n
     * ?.string: Object output, whose format varies by picker type.\n
     * 1: single-column picker with image support. The output structure is {@link ARKUI_TextPickerRangeContent}.\n
     * 2: multi-column interconnected picker. The output structure is {@link ARKUI_TextPickerCascadeRangeContent}.\n
     *
     */
    NODE_TEXT_PICKER_OPTION_RANGE = MAX_NODE_SCOPE_NUM * ARKUI_NODE_TEXT_PICKER,
    /**
     * @brief Defines the index of the default selected item in the data selection range of the text picker.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].u32: index. If there are multiple index values, add them one by one. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].u32: index. If there are multiple index values, add them one by one.\n
     *
     */
    NODE_TEXT_PICKER_OPTION_SELECTED,
    /**
     * @brief Defines the value of the default selected item in the text picker.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .string: value of the selected item. If there are multiple values, add them one by one and
     * separate them with semicolons (;). \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .string: value of the selected item. If there are multiple values, add them one by one and
     * separate them with semicolons (;).\n
     *
     */
    NODE_TEXT_PICKER_OPTION_VALUE,
    /**
     * @brief Defines the font color, font size, and font weight for the top and bottom items in the text picker.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .string: array of five parameters of the string type, separated by semicolons (;).\n
     * Parameter 1: font color, in #ARGB format.\n
     * Parameter 2: font size, in fp. The value is a number.\n
     * Parameter 3: font weight. Available options are ("bold", "normal", "bolder", "lighter", "medium", "regular").\n.
     * Parameter 4: fonts, separated by commas (,).\n
     * Parameter 5: font style. Available options are ("normal", "italic").\n
     * Example: "#ff182431;14;normal;Arial,HarmonyOS Sans;normal". \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .string: array of five parameters of the string type, separated by semicolons (;).\n
     * Parameter 1: font color, in #ARGB format.\n
     * Parameter 2: font size, in fp. The value is a number.\n
     * Parameter 3: font weight. Available options are ("bold", "normal", "bolder", "lighter", "medium", "regular").\n.
     * Parameter 4: fonts, separated by commas (,).\n
     * Parameter 5: font style. Available options are ("normal", "italic").\n
     * Example: "#ff182431;14;normal;Arial,HarmonyOS Sans;normal". \n
     *
     */
    NODE_TEXT_PICKER_DISAPPEAR_TEXT_STYLE,
    /**
     * @brief Defines the font color, font size, and font weight for all items except the top, bottom, and selected
     * items in the text picker. This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .string: array of five parameters of the string type, separated by semicolons (;).\n
     * Parameter 1: font color, in #ARGB format.\n
     * Parameter 2: font size, in fp. The value is a number.\n
     * Parameter 3: font weight. Available options are ("bold", "normal", "bolder", "lighter", "medium", "regular").\n.
     * Parameter 4: fonts, separated by commas (,).\n
     * Parameter 5: font style. Available options are ("normal", "italic").\n
     * Example: "#ff182431;14;normal;Arial,HarmonyOS Sans;normal". \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .string: array of five parameters of the string type, separated by semicolons (;).\n
     * Parameter 1: font color, in #ARGB format.\n
     * Parameter 2: font size, in fp. The value is a number.\n
     * Parameter 3: font weight. Available options are ("bold", "normal", "bolder", "lighter", "medium", "regular").\n.
     * Parameter 4: fonts, separated by commas (,).\n
     * Parameter 5: font style. Available options are ("normal", "italic").\n
     * Example: "#ff182431;14;normal;Arial,HarmonyOS Sans;normal". \n
     *
     */
    NODE_TEXT_PICKER_TEXT_STYLE,
    /**
     * @brief Defines the font color, font size, and font weight for the selected item in the text picker.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .string: array of five parameters of the string type, separated by semicolons (;).\n
     * Parameter 1: font color, in #ARGB format.\n
     * Parameter 2: font size, in fp. The value is a number.\n
     * Parameter 3: font weight. Available options are ("bold", "normal", "bolder", "lighter", "medium", "regular").\n.
     * Parameter 4: fonts, separated by commas (,).\n
     * Parameter 5: font style. Available options are ("normal", "italic").\n
     * Example: "#ff182431;14;normal;Arial,HarmonyOS Sans;normal". \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .string: array of five parameters of the string type, separated by semicolons (;).\n
     * Parameter 1: font color, in #ARGB format.\n
     * Parameter 2: font size, in fp. The value is a number.\n
     * Parameter 3: font weight. Available options are ("bold", "normal", "bolder", "lighter", "medium", "regular").\n.
     * Parameter 4: fonts, separated by commas (,).\n
     * Parameter 5: font style. Available options are ("normal", "italic").\n
     * Example: "#ff182431;14;normal;Arial,HarmonyOS Sans;normal". \n
     *
     */
    NODE_TEXT_PICKER_SELECTED_TEXT_STYLE,
    /**
     * @brief Defines the index of the default selected item in the data selection range of the text picker.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0...].i32: index of the default item in the data selection range.
     *
     */
    NODE_TEXT_PICKER_SELECTED_INDEX,
    /**
     * @brief Defines whether to support scroll looping for the text picker.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: whether to support scroll looping. The value <b>true</b> means to support scroll looping, and
     * <b>false</b> means the opposite.\n \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * value[0].i32: The value <b>1</b> means to support scroll looping, and <b>0</b> means the opposite. \n
     *
     */
    NODE_TEXT_PICKER_CAN_LOOP,
    /**
     * @brief Defines the height of each item in the picker. This attribute can be set, reset, and obtained as required
     * through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].f32: item height, in vp. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * value[0].f32: item height, in vp. \n
     *
     */
    NODE_TEXT_PICKER_DEFAULT_PICKER_ITEM_HEIGHT,
    /**
     * @brief Defines the style of the background in the selected state of the calendar picker.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].f32: style of the background in the selected state of the calendar picker.
     * The value range is [0, +∞). If the value is <b>0</b>, the background is a rectangle with square corners.
     If the value is in the 0–16 range, the background is a rectangle with rounded corners. If the value is equal to
     * or greater than 16, the background is a circle. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].f32: style of the background in the selected state of the calendar picker. The value range is [0, +∞).
     * If the value is <b>0</b>, the background is a rectangle with square corners.
     If the value is in the 0–16 range, the background is a rectangle with rounded corners. If the value is equal to or
     * greater than 16, the background is a circle. \n
     *
     */
    NODE_CALENDAR_PICKER_HINT_RADIUS = MAX_NODE_SCOPE_NUM * ARKUI_NODE_CALENDAR_PICKER,
    /**
     * @brief Defines the date of the selected item in the calendar picker.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].u32: year of the selected date. \n
     * .value[1].u32: month of the selected date. \n
     * .value[2].u32: day of the selected date. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].u32: year of the selected date. \n
     * .value[1].u32: month of the selected date. \n
     * .value[2].u32: day of the selected date. \n
     *
     */
    NODE_CALENDAR_PICKER_SELECTED_DATE,
    /**
     * @brief Defines how the calendar picker is aligned with the entry component.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: alignment mode. The parameter type is {@link ArkUI_CalendarAlignment}. \n
     * .value[1]?.f32: offset of the picker relative to the entry component along the x-axis after alignment based on
     * the specified alignment mode. \n
     * .value[2]?.f32: offset of the picker relative to the entry component along the y-axis after alignment based on
     * the specified alignment mode. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: alignment mode. The parameter type is {@link ArkUI_CalendarAlignment}. \n
     * .value[1]?.f32: offset of the picker relative to the entry component along the x-axis after alignment based on
     * the specified alignment mode. \n
     * .value[2]?.f32: offset of the picker relative to the entry component along the y-axis after alignment based on
     * the specified alignment mode. \n
     *
     */
    NODE_CALENDAR_PICKER_EDGE_ALIGNMENT,
    /**
     * @brief Defines the font color, font size, and font weight in the entry area of the calendar picker.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0]?.u32: font color of the entry area. \n
     * .value[1]?.f32: font size of the entry area, in fp. \n
     * .value[2]?.i32: font weight of the entry area. The parameter type is {@link ArkUI_FontWeight}. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].u32: font color of the entry area. \n
     * .value[1].f32: font size of the entry area, in fp. \n
     * .value[2].i32: font weight of the entry area. The parameter type is {@link ArkUI_FontWeight}. \n
     *
     */
    NODE_CALENDAR_PICKER_TEXT_STYLE,
    /**
     * @brief Defines the color of the slider. This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].u32: color of the slider, in 0xARGB format, for example, <b>0xFF1122FF</b>.
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].u32: color of the slider, in 0xARGB format, for example, <b>0xFF1122FF</b>.
     *
     */
    NODE_SLIDER_BLOCK_COLOR = MAX_NODE_SCOPE_NUM * ARKUI_NODE_SLIDER,

    /**
     * @brief Defines the background color of the slider. This attribute can be set, reset, and obtained as required
     * through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].u32: background color, in 0xARGB format, for example, <b>0xFF1122FF</b>. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].u32: background color, in 0xARGB format, for example, <b>0xFF1122FF</b>.
     *
     */
    NODE_SLIDER_TRACK_COLOR,

    /**
     * @brief Defines the color of the selected part of the slider track. This attribute can be set, reset, and obtained
     * as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].u32: color of the selected part of the slider track, in 0xARGB format, for example, <b>0xFF1122FF</b>. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].u32: color of the selected part of the slider track, in 0xARGB format, for example, <b>0xFF1122FF</b>.
     *
     */
    NODE_SLIDER_SELECTED_COLOR,

    /**
     * @brief Sets whether to display the stepping value. This attribute can be set, reset, and obtained as required
     * through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: whether to display the stepping value. The value <b>1</b> means to display the stepping value,
     * and <b>0</b> (default value) means the opposite. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: whether to display the stepping value. The value <b>1</b> means to display the stepping value,
     * and <b>0</b> (default value) means the opposite. \n
     *
     */
    NODE_SLIDER_SHOW_STEPS,

    /**
     * @brief Defines the slider shape, which can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: shape. The parameter type is {@link ArkUI_SliderBlockStyle}. \n
     * .string?: depending on the shape. Optional. \n
     * ARKUI_SLIDER_BLOCK_STYLE_IMAGE: image resource of the slider. Example: /pages/common/icon.png. \n
     * ARKUI_SLIDER_BLOCK_STYLE_SHAPE: custom shape of the slider. \n
     * There are five types:\n
     * 1. Rectangle:\n
     * .value[1].i32: type of shape. The parameter type is {@link ArkUI_ShapeType}.
     * The value is <b>ARKUI_SHAPE_TYPE_RECTANGLE</b> for the rectangle shape.\n
     * .value[2].f32: width of the rectangle.\n
     * .value[3].f32: height of the rectangle.\n
     * .value[4].f32: width of the rounded corner of the rectangle.\n
     * .value[5].f32: height of the rounded corner of the rectangle.\n
     * 2. Circle:\n
     * .value[1].i32: type of shape. The parameter type is {@link ArkUI_ShapeType}.
     * The value is <b>ARKUI_SHAPE_TYPE_CIRCLE</b> for the circle shape.\n
     * .value[2].f32: width of the circle.\n
     * .value[3].f32: height of the circle.\n
     * 3.Ellipse:\n
     * .value[1].i32: type of shape. The parameter type is {@link ArkUI_ShapeType}.
     * The value is <b>ARKUI_SHAPE_TYPE_ELLIPSE</b> for the ellipse shape.\n
     * .value[2].f32: width of the ellipse.\n
     * .value[3].f32: height of the ellipse;\n
     * 4. Path:\n
     * .value[1].i32: type of shape. The parameter type is {@link ArkUI_ShapeType}.
     * The value is <b>ARKUI_SHAPE_TYPE_PATH</b> for the path shape.\n
     * .value[2].f32: width of the path.\n
     * .value[3].f32: height of the path.\n
     * .string: command for drawing the path.\n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: shape. The parameter type is {@link ArkUI_SliderBlockStyle}. \n
     * .string?: depending on the shape. Optional. \n
     * ARKUI_SLIDER_BLOCK_STYLE_IMAGE: image resource of the slider. Example: /pages/common/icon.png. \n
     * ARKUI_SLIDER_BLOCK_STYLE_SHAPE: custom shape of the slider. \n
      * There are five types:\n
     * 1. Rectangle:\n
     * .value[1].i32: type of shape. The parameter type is {@link ArkUI_ShapeType}.
     * The value is <b>ARKUI_SHAPE_TYPE_RECTANGLE</b> for the rectangle shape.\n
     * .value[2].f32: width of the rectangle.\n
     * .value[3].f32: height of the rectangle.\n
     * .value[4].f32: width of the rounded corner of the rectangle.\n
     * .value[5].f32: height of the rounded corner of the rectangle.\n
     * 2. Circle:\n
     * .value[1].i32: type of shape. The parameter type is {@link ArkUI_ShapeType}.
     * The value is <b>ARKUI_SHAPE_TYPE_CIRCLE</b> for the circle shape.\n
     * .value[2].f32: width of the circle.\n
     * .value[3].f32: height of the circle.\n
     * 3.Ellipse:\n
     * .value[1].i32: type of shape. The parameter type is {@link ArkUI_ShapeType}.
     * The value is <b>ARKUI_SHAPE_TYPE_ELLIPSE</b> for the ellipse shape.\n
     * .value[2].f32: width of the ellipse.\n
     * .value[3].f32: height of the ellipse;\n
     * 4. Path:\n
     * .value[1].i32: type of shape. The parameter type is {@link ArkUI_ShapeType}.
     * The value is <b>ARKUI_SHAPE_TYPE_PATH</b> for the path shape.\n
     * .value[2].f32: width of the path.\n
     * .value[3].f32: height of the path.\n
     * .string: command for drawing the path.\n
     *
     */
    NODE_SLIDER_BLOCK_STYLE,

    /**
     * @brief Defines the current value of the slider. This attribute can be set, reset, and obtained as required
     * through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].f32: current value. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].f32: current value.
     *
     */
    NODE_SLIDER_VALUE,

    /**
     * @brief Defines the minimum value of the slider. This attribute can be set, reset, and obtained as required
     * through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].f32: minimum value. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].f32: minimum value.
     *
     */
    NODE_SLIDER_MIN_VALUE,

    /**
     * @brief Defines the maximum value of the slider. This attribute can be set, reset, and obtained as required
     * through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].f32: maximum value. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].f32: maximum value.
     *
     */
    NODE_SLIDER_MAX_VALUE,

    /**
     * @brief Defines the step of the slider. This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].f32: step. The value range is [0.01, 100]. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].f32: step. The value range is [0.01, 100].
     *
     */
    NODE_SLIDER_STEP,

    /**
     * @brief Defines whether the slider moves horizontally or vertically. This attribute can be set, reset, and
     * obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: whether the slider moves horizontally or vertically.
     * The parameter type is {@link ArkUI_SliderDirection}. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: whether the slider moves horizontally or vertically.
     *
     */
    NODE_SLIDER_DIRECTION,

    /**
     * @brief Defines whether the slider values are reversed. This attribute can be set, reset, and obtained as required
     * through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: whether the slider values are reversed. The value <b>1</b> means that the slider values are
     * reversed, and <b>0</b> means the opposite. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: whether the slider values are reversed. The value <b>1</b> means that the slider values are
     * reversed, and <b>0</b> means the opposite.
     *
     */
    NODE_SLIDER_REVERSE,

    /**
     * @brief Defines the style of the slider thumb and track. This attribute can be set, reset, and obtained
     * as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: style of the slider thumb and track. The parameter type is {@link ArkUI_SliderStyle}. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: style of the slider thumb and track. The parameter type is {@link ArkUI_SliderStyle}.
     *
     */
    NODE_SLIDER_STYLE,

    /**
     * @brief Sets the track thickness of the slider.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].f32: track thickness of the slider, in vp. The default value is 4.0 vp when <b>NODE_SLIDER_STYLE</b>
     * is set to <b>ARKUI_SLIDER_STYLE_OUT_SET</b> and 20.0 vp when <b>NODE_SLIDER_STYLE</b> is set to
     * <b>ARKUI_SLIDER_STYLE_IN_SET</b>. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].f32: track thickness of the slider, in vp. \n
     *
     */
    NODE_SLIDER_TRACK_THICKNESS,

    /**
     * @brief Set the selection status of an option button. Attribute setting,
     * attribute resetting, and attribute obtaining are supported.
     * Attribute setting method {@Link ArkUI_AttributeItem} Parameter format:\n
     * .value[0].i32: check status of an option button. The default value is false.
     * Attribute obtaining method return value {@Link ArkUI_AttributeItem} format:\n
     * .value[0].i32: selection status of an option button.
     */
    NODE_RADIO_CHECKED = MAX_NODE_SCOPE_NUM * ARKUI_NODE_RADIO,
    /**
     * @brief Set the styles of the selected and deselected states of the option button.
     * The attribute setting, attribute resetting, and attribute obtaining are supported.
     * Attribute setting method {@Link ArkUI_AttributeItem} Parameter format:\n
     * .value[0]?. u32: color of the mother board in enabled state. \n
     * The type is 0xARGB, and the default value is 0xFF007DFF. \n
     * .value[1]?. u32: stroke color in the close state. The type is 0xARGB, \n
     * and the default value is 0xFF182431. \n
     * .value[2]?. u32: color of the internal round pie in the enabled state. \n
     * The type is 0xARGB, and the default value is 0xFFFFFFFF. \n
     * Attribute obtaining method return value {@Link ArkUI_AttributeItem} format:\n
     * .value[0]. u32: color of the mother board in enabled state. \n
     * The type is 0xARGB, and the default value is 0xFF007DFF. \n
     * .value[1]. u32: stroke color in the close state. The type is 0xARGB, \n
     * and the default value is 0xFF182431. \n
     * .value[2]. u32: color of the internal round pie in the enabled state. \n
     * The type is 0xARGB, and the default value is 0xFFFFFFF. \n
     */
    NODE_RADIO_STYLE,
    /**
     * @brief Sets the value of the current radio.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Attribute setting method {@Link ArkUI_AttributeItem} Parameter format:\n
     * .string: radio value.\n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .string: radio value.\n
     *
     */
    NODE_RADIO_VALUE,
    /**
     * @brief Set the group name of the current Radio group, only one radio of the same group can be selected.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Attribute setting method {@Link ArkUI_AttributeItem} Parameter format:\n
     * .string: name of the group to which the current option box belongs.\n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .string: name of the group to which the current option box belongs.\n
     *
     */
    NODE_RADIO_GROUP,

    /**
     * @brief Defines the alignment mode of the child components in the container. This attribute can be set, reset,
     * and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: alignment mode. The data type is {@link ArkUI_Alignment}.
     * The default value is <b>ARKUI_ALIGNMENT_CENTER</b>. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: alignment mode. The data type is {@link ArkUI_Alignment}. \n
     *
     */
    NODE_STACK_ALIGN_CONTENT = MAX_NODE_SCOPE_NUM * ARKUI_NODE_STACK,

    /**
     * @brief Defines the scrollbar status. This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: scrollbar status. The parameter type is {@link ArkUI_ScrollBarDisplayMode}. The default value is
     * <b>ARKUI_SCROLL_BAR_DISPLAY_MODE_AUTO</b>. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: scrollbar status. The parameter type is {@link ArkUI_ScrollBarDisplayMode}. \n
     *
     */
    NODE_SCROLL_BAR_DISPLAY_MODE = MAX_NODE_SCOPE_NUM * ARKUI_NODE_SCROLL,
    /**
     * @brief Defines the width of the scrollbar. This attribute can be set, reset, and obtained as required
     * through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].f32: width of the scrollbar, in vp. The default value is <b>4</b>. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].f32: width of the scrollbar, in vp. \n
     *
     */
    NODE_SCROLL_BAR_WIDTH,
    /**
     * @brief Defines the color of the scrollbar. This attribute can be set, reset, and obtained as required
     * through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .data[0].u32: color of the scrollbar, in 0xARGB format. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .data[0].u32: color of the scrollbar, in 0xARGB format. \n
     *
     */
    NODE_SCROLL_BAR_COLOR,
    /**
     * @brief Defines the scroll direction. This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: scroll direction. The parameter type is {@link ArkUI_ScrollDirection}.
     * The default value is <b>ARKUI_SCROLL_DIRECTION_VERTICAL</b>. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: scroll direction. The parameter type is {@link ArkUI_ScrollDirection}. \n
     *
     */
    NODE_SCROLL_SCROLL_DIRECTION,
    /**
     * @brief Defines the effect used at the edges of the component when the boundary of the scrollable content is
     * reached. This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: effect used at the edges of the component when the boundary of the scrollable content is reached.
     * The parameter type is {@link ArkUI_EdgeEffect}. The default value is <b>ARKUI_EDGE_EFFECT_NONE</b>.\n
     * .value[1]?.i32: whether to enable the scroll effect when the component content size is smaller than the
     * component itself. Optional. The value <b>1</b> means to enable the scroll effect, and <b>0</b> means the
     * opposite. The default value is <b>1</b>. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: effect used at the edges of the component when the boundary of the scrollable content is reached.
     * The parameter type is {@link ArkUI_EdgeEffect}. \n
     * .value[1].i32: whether to enable the scroll effect when the component content size is smaller than the component
     * itself. Optional. The value <b>1</b> means to enable the scroll effect, and <b>0</b> means the opposite. \n
     *
     */
    NODE_SCROLL_EDGE_EFFECT,
    /**
     * @brief Defines whether to support scroll gestures. When this attribute is set to <b>false</b>, scrolling by
     * finger or mouse is not supported, but the scroll controller API is not affected.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: whether to support scroll gestures. The default value is <b>true</b>. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: whether to support scroll gestures. \n
     *
     */
    NODE_SCROLL_ENABLE_SCROLL_INTERACTION,
    /**
     * @brief Defines the friction coefficient. It applies only to gestures in the scrolling area, and it affects only
     * indirectly the scroll chaining during the inertial scrolling process.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].f32: friction coefficient. The default value is <b>0.6</b> for non-wearable devices and <b>0.9</b>
     * for wearable devices. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].f32: friction coefficient.
     *
     */
    NODE_SCROLL_FRICTION,
    /**
     * @brief Defines the scroll snapping mode. This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: alignment mode for the scroll snap position. The parameter type is {@link ArkUI_ScrollSnapAlign}.
     * The default value is <b>ARKUI_SCROLL_SNAP_ALIGN_NONE</b>.\n
     * .value[1].i32: whether to enable the snap to start feature. When scroll snapping is defined for the
     * <b><Scroll></b> component, setting this attribute to <b>false</b> enables the component to scroll between the
     * start edge and the first snap point. The default value is <b>true</b>. It is valid only when there are multiple
     * snap points.\n
     * .value[2].i32: Whether to enable the snap to end feature. When scroll snapping is defined for the
     * <b><Scroll></b> component, setting this attribute to <b>false</b> enables the component to scroll between the
     * end edge and the last snap point. The default value is <b>true</b>. It is valid only when there are multiple
     * snap points.\n
     * .value[3...].f32: snap points for the <b><Scroll></b> component. Each snap point defines the offset from an
     * edge to which the <b><Scroll></b> component can scroll.  \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: alignment mode for the scroll snap position. The parameter type is {@link ArkUI_ScrollSnapAlign}.\n
     * .value[1].i32: whether to enable the snap to start feature. When scroll snapping is defined for the
     * <b><Scroll></b> component, setting this attribute to <b>false</b> enables the component to scroll between the
     * start edge and the first snap point.\n
     * .value[2].i32: Whether to enable the snap to end feature. When scroll snapping is defined for the
     * <b><Scroll></b> component, setting this attribute to <b>false</b> enables the component to scroll between the
     * end edge and the last snap point.\n
     * .value[3...].f32: snap points for the <b><Scroll></b> component. Each snap point defines the offset from an edge
     * to which the <b><Scroll></b> component can scroll. \n
     *
     */
    NODE_SCROLL_SNAP,

    /**
     * @brief Defines the nested scrolling options. This attribute can be set, reset, and obtained as required
     * through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: nested scrolling option when the component scrolls forward.
     * The parameter type is {@link ArkUI_ScrollNestedMode}. \n
     * .value[1].i32: nested scrolling option when the component scrolls backward.
     * The parameter type is {@link ArkUI_ScrollNestedMode}. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: nested scrolling option when the component scrolls forward.
     * The parameter type is {@link ArkUI_ScrollNestedMode}. \n
     * .value[1].i32: nested scrolling option when the component scrolls backward.
     * The parameter type is {@link ArkUI_ScrollNestedMode}.
     *
     */
    NODE_SCROLL_NESTED_SCROLL,
    /**
     * @brief Defines the specified position to scroll to. This attribute can be set, reset, and obtained as required
     * through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].f32: horizontal scrolling offset, in vp. \n
     * .value[1].f32: vertical scrolling offset, in vp. \n
     * .value[2]?.i32: scrolling duration, in milliseconds. Optional. \n
     * .value[3]?.i32: scrolling curve. Optional. The parameter type is {@link ArkUI_AnimationCurve}.
     * The default value is <b>ARKUI_CURVE_EASE</b>. \n
     * .value[4]?.i32: whether to enable the default spring animation. Optional. The default value <b>0</b> means not
     * to enable the default spring animation. \n
     * .value[5]?.i32: Optional value, sets whether scrolling can cross the boundary. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].f32: horizontal scrolling offset, in vp. \n
     * .value[1].f32: vertical scrolling offset, in vp. \n
     *
     */
    NODE_SCROLL_OFFSET,

    /**
     * @brief Defines the edge position to scroll to. This attribute can be set and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: edge position to scroll to. The parameter type is {@link ArkUI_ScrollEdge}. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: whether the container at the edge position. The value <b>-1</b> means that the container is not
     * at the edge position. If the container is at the edge position, the parameter type is {@link ArkUI_ScrollEdge}.
     *
     */
    NODE_SCROLL_EDGE,

    /**
     * @brief Defines whether to enable the swipe-to-turn-pages feature. This attribute can be set, reset, and obtained
     * as required through APIs.
     *
     * If both <b>enablePaging</b> and <b>scrollSnap</b> are set, <b>scrollSnap</b> takes effect, but
     * <b>enablePaging</b> does not. \n
     * \n
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: whether to enable the swipe-to-turn-pages feature. The default value is <b>false</b>. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: whether to enable the swipe-to-turn-pages feature. \n
     *
     */
    NODE_SCROLL_ENABLE_PAGING,

    /**
     * @brief Scroll to the next or previous page.
     * 
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32 Indicates whether to scroll to next page. Value 1 indicates scroll to next page and value 0
     * indicates scroll to previous page. \n
     * .value[1]?.i32 Indicates whether to enable animation. Value 1 indicates enable and 0 indicates disable. \n
     *
     */
    NODE_SCROLL_PAGE,

    /**
     * @brief Scroll a specified distance.
     * 
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].f32：Horizontal scrolling distance in vp; \n
     * .value[1].f32: Vertical scrolling distance in vp; \n
     *
     */
    NODE_SCROLL_BY,

    /**
     * @brief Defines the direction in which the list items are arranged. This attribute can be set, reset, and
     * obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: direction in which the list items are arranged. The parameter type is {@link ArkUI_Axis}.
     * The default value is <b>ARKUI_AXIS_VERTICAL</b>. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: direction in which the list items are arranged. The parameter type is {@link ArkUI_Axis}. \n
     *
     */
    NODE_LIST_DIRECTION = MAX_NODE_SCOPE_NUM * ARKUI_NODE_LIST,
    /**
     * @brief Defines whether to pin the header to the top or the footer to the bottom in the <b><ListItemGroup></b>
     * component. This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: whether to pin the header to the top or the footer to the bottom in the <b><ListItemGroup></b>
     * component. It is used together with the <b><ListItemGroup></b> component. The parameter type is
     * {@link ArkUI_StickyStyle}. The default value is <b>ARKUI_STICKY_STYLE_NONE</b>. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: whether to pin the header to the top or the footer to the bottom in the <b><ListItemGroup></b>
     * component. It is used together with the <b><ListItemGroup></b> component. The parameter type is
     * {@link ArkUI_StickyStyle}.
     *
     */
    NODE_LIST_STICKY,
    /**
     * @brief Defines the spacing between list items. This attribute can be set, reset, and obtained as required
     * through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].f32: spacing between list items along the main axis. The default value is <b>0</b>. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].f32: spacing between list items along the main axis. \n
     *
     */
    NODE_LIST_SPACE,
    /**
    * @brief Defines the list adapter. The attribute can be set, reset, and obtained as required through APIs.
    *
    * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
    * .object: {@link ArkUI_NodeAdapter} object as the adapter. \n
    */
    NODE_LIST_NODE_ADAPTER,

    /**
    * @brief Sets the number of cached items in the list adapter.
    * This attribute can be set, reset, and obtained as required through APIs.
    *
    * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
    * .value[0].i32: number of cached items in the list adapter. \n
    */
    NODE_LIST_CACHED_COUNT,

    /**
     * @brief Scroll to the specified index.
     * 
     * When activating the smooth animation, all items passed through will be loaded and layout calculated, which can
     * lead to performance issues when loading a large number of items.\n
     * \n
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32：The index value of the target element to be slid to in the current container.\n
     * .value[1]?.i32：Set whether there is an action when sliding to the index value of a list item in the list, where
     * 1 indicates an action and 0 indicates no action. Default value: 0。\n
     * .value[2]?.i32：Specify the alignment of the sliding element with the current container,The parameter type is
     * {@link ArkUI_ScrollAlignment}, default value is ARKUI_SCROLL_ALIGNMENT_START. \n
     *
     */
    NODE_LIST_SCROLL_TO_INDEX,
    /**
     * @brief Sets the alignment mode of list items along the cross axis when the cross-axis width of the list is
     * greater than the cross-axis width of list items multiplied by the value of lanes.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: alignment mode of list items along the cross axis.
     * The parameter type is {@link ArkUI_ListItemAlignment}. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: alignment mode of list items along the cross axis.
     * The parameter type is {@link ArkUI_ListItemAlignment}. \n
    */
    NODE_LIST_ALIGN_LIST_ITEM,

    /**
     * @brief Set the default spindle size for the List subcomponent.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .object: The parameter format is {@ ArkUI-ListChildrenMainSize} \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .object: The parameter format is {@ ArkUI-ListChildrenMainSize} \n
     */
    NODE_LIST_CHILDREN_MAIN_SIZE = 1003007,

    /**
     * @brief Defines whether to enable loop playback for the swiper.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: whether to enable loop playback. The value <b>1</b> means to enable loop playback, and <b>0</b>
     * means the opposite. The default value is <b>1/b>. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: whether to enable loop playback. The value <b>1</b> means to enable loop playback, and <b>0</b>
     * means the opposite. The default value is <b>1</b>. \n
     *
     */
    NODE_SWIPER_LOOP = MAX_NODE_SCOPE_NUM * ARKUI_NODE_SWIPER,
    /**
     * @brief Defines whether to enable automatic playback for child component switching in the swiper.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: whether to enable automatic playback for child component switching. The value <b>1</b>
     * means to enable automatic playback, and <b>0</b> means the opposite. The default value is <b>0</b>. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: whether to enable automatic playback for child component switching. The value <b>1</b> means
     * to enable automatic playback, and <b>0</b> means the opposite. The default value is <b>0</b>. \n
     *
     */
    NODE_SWIPER_AUTO_PLAY,
    /**
     * @brief Defines whether to enable the navigation point indicator for the swiper. This attribute can be set,
     * reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: whether to enable the navigation point indicator. The value <b>1</b> means to enable the
     * navigation point indicator, and <b>0</b> means the opposite. The default value is <b>1</b>. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: whether to enable the navigation point indicator. The value <b>1</b> means to enable the
     * navigation point indicator, and <b>0</b> means the opposite. The default value is <b>1</b>. \n
     *
     */
    NODE_SWIPER_SHOW_INDICATOR,
    /**
     * @brief Defines the interval for automatic playback. This attribute can be set, reset, and obtained as required
     * through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].f32: interval for automatic playback, in milliseconds. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].f32: interval for automatic playback, in milliseconds. \n
     *
     */
    NODE_SWIPER_INTERVAL,
    /**
     * @brief Defines whether vertical swiping is used for the swiper. This attribute can be set, reset, and obtained
     * as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: whether vertical swiping is used. The value <b>1</b> means that vertical swiping is used, and
     * <b>0</b> means the opposite. The default value is <b>0</b>. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: whether vertical swiping is used. The value <b>1</b> means that vertical swiping is used, and
     * <b>0</b> means the opposite. The default value is <b>0</b>. \n
     *
     */
    NODE_SWIPER_VERTICAL,

    /**
     * @brief Defines the duration of the animation for switching child components. This attribute can be set, reset,
     * and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].f32: duration of the animation for switching child components, in milliseconds. The default value is
     * <b>400</b>. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].f32: duration of the animation for switching child components, in milliseconds. The default value is
     * <b>400</b>. \n
     *
     */
    NODE_SWIPER_DURATION,

    /**
     * @brief Defines the animation curve for the swiper. This attribute can be set, reset, and obtained as required
     * through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: animation curve. The parameter type is {@link ArkUI_AnimationCurve}.
     * The default value is <b>ARKUI_CURVE_LINEAR</b>. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: animation curve. The parameter type is {@link ArkUI_AnimationCurve}.
     * The default value is <b>ARKUI_CURVE_LINEAR</b>. \n
     *
     */
    NODE_SWIPER_CURVE,

    /**
     * @brief Defines the spacing between child components in the swiper.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].f32: spacing between child components. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].f32: spacing between child components. \n
     *
     */
    NODE_SWIPER_ITEM_SPACE,

    /**
     * @brief Defines the index of the child component currently displayed in the swiper.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: index value of the child component. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: index value of the child component. \n
     *
     */
    NODE_SWIPER_INDEX,

    /**
     * @brief Defines the number of elements to display per page.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: index value of the child component. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: index value of the child component. \n
     *
     */
    NODE_SWIPER_DISPLAY_COUNT,

    /**
     * @brief Defines whether to disable the swipe feature.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: whether to disable the swipe feature. The value <b>1</b> means to disable
     * the swipe feature, and <b>0</b> means the opposite. The default value is <b>0</b>. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: whether to disable the swipe feature. The value <b>1</b> means to disable the swipe
     * feature, and <b>0</b> means the opposite. The default value is <b>0</b>. \n
     *
     */
    NODE_SWIPER_DISABLE_SWIPE,

    /**
     * @brief Defines whether to show the arrow when the mouse pointer hovers over the navigation point indicator.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: whether to show the arrow when the mouse pointer hovers over the navigation point indicator.
     * The parameter type is {@link ArkUI_SwiperArrow}.\n
     * The default value is <b>ARKUI_SWIPER_ARROW_HIDE</b>. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: whether to show the arrow when the mouse pointer hovers over the navigation point indicator.
     * The parameter type is {@link ArkUI_SwiperArrow}.\n
     * The default value is <b>ARKUI_SWIPER_ARROW_HIDE</b>. \n
     *
     */
    NODE_SWIPER_SHOW_DISPLAY_ARROW,

    /**
     * @brief Defines the effect used at the edges of the swiper when the boundary of the scrollable content is reached.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: effect used at the edges of the swiper when the boundary of the scrollable content is reached.
     * The parameter type is {@link ArkUI_EdgeEffect}.\n
     * The default value is <b>ARKUI_EDGE_EFFECT_SPRING</b>. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: effect used at the edges of the swiper when the boundary of the scrollable content is reached.
     * The parameter type is {@link ArkUI_EdgeEffect}. \n
     *
     */
    NODE_SWIPER_EDGE_EFFECT_MODE,

    /**
    * @brief Defines the swiper adapter. The attribute can be set, reset, and obtained as required through APIs.
    *
    * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
    * .object: {@link ArkUI_NodeAdapter} object as the adapter. \n
    */
    NODE_SWIPER_NODE_ADAPTER,

    /**
    * @brief Sets the number of cached items in the swiper adapter.
    * This attribute can be set, reset, and obtained as required through APIs.
    *
    * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
    * .value[0].i32: number of cached items in the swiper adapter. \n
    */
    NODE_SWIPER_CACHED_COUNT,

    /**
     * @brief Defines the front margin of the wiper.
     * The attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].f32: the front margin. The unit is vp. The default value is <b>0.0</b>\n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].f32: the front margin, the unit is vp. \n
     *
     */
    NODE_SWIPER_PREV_MARGIN,

    /**
     * @brief Defines the back margin of the wiper.
     * The attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].f32: the back margin. The unit is vp. The default value is <b>0.0</b>\n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].f32: the back margin, the unit is vp. \n
     */
    NODE_SWIPER_NEXT_MARGIN,

    /**
     * @brief Defines the navigation indicator type of the swiper.
     * The attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: navigation indicator type, the parameter type is {@link ArkUI_SwiperIndicatorType}.\n
     * .object: The parameter type is {@link ArkUI_SwiperIndicator}.\n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: navigation indicator type, the parameter type is {@link ArkUI_SwiperIndicatorType}.\n
     * .object: The parameter type is {@link ArkUI_SwiperIndicator}.\n
     *
     */
    NODE_SWIPER_INDICATOR,
    /**
     * @brief Set the nested scrolling mode for the Swiper component and parent component.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32：Nested scrolling patterns for Swiper components and parent components. The parameter type is
     * {@link ArkUI_SwiperNestedScrollMode} \n
     * The default value is <b>ARKUI_SWIPER_NESTED_SRCOLL_SELF_ONLY<b> \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32：Nested scrolling patterns for Swiper components and parent components. The parameter type is
     * {@link ArkUI_SwiperNestedScrollMode} \n
     */
    NODE_SWIPER_NESTED_SCROLL,

    /**
     * @brief Set the switcher component to flip to the specified page.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32：Specify the index value of the page in Swiper.\n
     * .value[1]?.i32：Set whether there is an animation effect when flipping to the specified page. 1 indicates active
     * effect, 0 indicates no active effect, default value is 0。\n
     */
    NODE_SWIPER_SWIPE_TO_INDEX,

    /**
     * @brief: Set the delineation component of the ListItem, supporting property settings, property resets, and
     * property acquisition interfaces.
     *
     * Attribute setting method parameter {@link ArkUI_AttributeItem} format: \n
     * .object: Construct using the {@link ArkUI_ListitemSwipeActionOption} object. \n
     * \n
     * The return value of the attribute acquisition method {@link ArkUI_AttributeItem} format: \n
     * .object: Construct using the {@link ArkUI_ListitemSwipeActionOption} object. \n
     *
     */
    NODE_LIST_ITEM_SWIPE_ACTION = MAX_NODE_SCOPE_NUM * ARKUI_NODE_LIST_ITEM,

    /**
     * @brief Defines the header of the list item group.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .object: {@link ArkUI_NodeHandle} object to be used as the header of the list item group. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .object: {@link ArkUI_NodeHandle} object to be used as the header of the list item group. \n
     *
     */
    NODE_LIST_ITEM_GROUP_SET_HEADER = MAX_NODE_SCOPE_NUM * ARKUI_NODE_LIST_ITEM_GROUP,
    /**
     * @brief Defines the footer of the list item group. This attribute can be set, reset, and obtained as
     * required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .object: {@link ArkUI_NodeHandle} object to be used as the footer of the list item group. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .object: {@link ArkUI_NodeHandle} object to be used as the footer of the list item group. \n
     *
     */
    NODE_LIST_ITEM_GROUP_SET_FOOTER,
    /**
     * @brief Defines the style of the divider for the list items. This attribute can be set, reset, and obtained
     * as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].u32: color of the divider, in 0xARGB format.\n
     * .value[1].f32: stroke width of the divider, in vp.\n
     * .value[2].f32: distance between the divider and the start of the list, in vp.\n
     * .value[3].f32: distance between the divider and the end of the list, in vp.\n \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].u32: color of the divider, in 0xARGB format.\n
     * .value[1].f32: stroke width of the divider, in vp.\n
     * .value[2].f32: distance between the divider and the start of the list, in vp.\n
     * .value[3].f32: distance between the divider and the end of the list, in vp.\n \n
     *
     */
    NODE_LIST_ITEM_GROUP_SET_DIVIDER,

    /**
     * @brief Set the default spindle size for the ListItem Group subcomponent.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .object: The parameter format is {@ ArkUI-ListChildrenMainSize} \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .object: The parameter format is {@ ArkUI-ListChildrenMainSize} \n
     */
    NODE_LIST_ITEM_GROUP_CHILDREN_MAIN_SIZE = 1005003,

    /**
     * @brief Defines the horizontal alignment mode of child components in the column.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: horizontal alignment mode of child components.
     * The parameter type is {@link ArkUI_HorizontalAlignment}.\n
     * Default value: <b>ARKUI_HORIZONTAL_ALIGNMENT_CENTER</b>. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: horizontal alignment mode of child components.
     * The parameter type is {@link ArkUI_HorizontalAlignment}. \n
     *
     */
    NODE_COLUMN_ALIGN_ITEMS = MAX_NODE_SCOPE_NUM * ARKUI_NODE_COLUMN,
    /**
     * @brief Defines the vertical alignment mode of child components in the column.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: vertical alignment mode of child components. The parameter type is {@link ArkUI_FlexAlignment}.\n
     * Default value: <b>ARKUI_FLEX_ALIGNMENT_START</b>. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: vertical alignment mode of child components. The parameter type is {@link ArkUI_FlexAlignment}. \n
     *
     */
    NODE_COLUMN_JUSTIFY_CONTENT,

    /**
     * @brief Defines the vertical alignment mode of child components in the row.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: vertical alignment mode of child components.
     * The parameter type is {@link ArkUI_VerticalAlignment}.\n
     * Default value: <b>ARKUI_VERTICAL_ALIGNMENT_CENTER</b>. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: vertical alignment mode of child components.
     * The parameter type is {@link ArkUI_VerticalAlignment}. \n
     *
     */
    NODE_ROW_ALIGN_ITEMS = MAX_NODE_SCOPE_NUM * ARKUI_NODE_ROW,
    /**
     * @brief Defines the horizontal alignment mode of child components in the row.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: horizontal alignment mode of child components.
     * The parameter type is {@link ArkUI_FlexAlignment}.\n
     * Default value: <b>ARKUI_FLEX_ALIGNMENT_START</b>. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: horizontal alignment mode of child components.
     * The parameter type is {@link ArkUI_FlexAlignment}. \n
     *
     */
    NODE_ROW_JUSTIFY_CONTENT,

    /**
     * @brief Defines the flex attribute. This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0]?.i32: direction in which flex items are arranged. The parameter type is {@link ArkUI_FlexDirection}.
     * The default value is <b>ARKUI_FLEX_DIRECTION_ROW</b>.\n
     * .value[1]?.i32: how the flex items are wrapped. The parameter type is {@link ArkUI_FlexWrap}.
     * The default value is <b>ARKUI_FLEX_WRAP_NO_WRAP</b>.\n
     * .value[2]?.i32: alignment mode along the main axis. The parameter type is {@link ArkUI_FlexAlignment}.
     * The default value is <b>ARKUI_FLEX_ALIGNMENT_START</b>.\n
     * .value[3]?.i32: alignment mode along the cross axis. The parameter type is {@link ArkUI_ItemAlignment}.
     * The default value is <b>ARKUI_ITEM_ALIGNMENT_START</b>.\n
     * .value[4]?.i32: alignment mode along the cross axis for multi-line content. The parameter type is
     * {@link ArkUI_FlexAlignment}. The default value is <b>ARKUI_FLEX_ALIGNMENT_START</b>.\n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: direction in which flex items are arranged. \n
     * .value[1].i32: how the flex items are wrapped. \n
     * .value[2].i32: alignment mode along the main axis. \n
     * .value[3].i32: alignment mode along the cross axis. \n
     * .value[4].i32: alignment mode along the cross axis for multi-line content.\n
     *
     */
    NODE_FLEX_OPTION = MAX_NODE_SCOPE_NUM * ARKUI_NODE_FLEX,

    /**
     * @brief Sets whether the component is being refreshed.
     * This attribute can be set and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: The parameter type is 1 or 0.
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: The parameter type is 1 or 0.
     *
     */
    NODE_REFRESH_REFRESHING = MAX_NODE_SCOPE_NUM * ARKUI_NODE_REFRESH,
    /**
     * @brief Sets the custom content in the pull-down area.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .object: The parameter type is {@Link ArkUI_NodeHandle}.
     *
     */
    NODE_REFRESH_CONTENT,

    /**
     * @brief Defines the main axis direction of the <b><WaterFlow></b> component layout.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: main axis direction. The parameter type is {@Link ArkUI_FlexDirection}.
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].i32: main axis direction. The parameter type is {@Link ArkUI_FlexDirection}.
     *
     */
    NODE_WATER_FLOW_LAYOUT_DIRECTION = MAX_NODE_SCOPE_NUM * ARKUI_NODE_WATER_FLOW,

    /**
     * @brief Sets the number of columns in the water flow layout. If this parameter is not set, one column is used
     * by default. This attribute can be set, reset, and obtained as required through APIs.
     * For example, <b>'1fr 1fr 2fr'</b> indicates three columns, with the first column taking up 1/4 of the parent
     * component's full width, the second column 1/4, and the third column 2/4.
     * You can use <b>columnsTemplate('repeat(auto-fill,track-size)')</b> to automatically calculate the number of
     * columns based on the specified column width <b>track-size</b>.
     * <b>repeat</b> and <b>auto-fill</b> are keywords. The units for <b>track-size</b> can be px, vp (default), %,
     * or a valid number.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .string: number of columns in the layout.\n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .string: number of columns in the layout.\n
     *
     */
    NODE_WATER_FLOW_COLUMN_TEMPLATE,

    /**
     * @brief Sets the number of rows in the water flow layout. If this parameter is not set, one row is used
     * by default. This attribute can be set, reset, and obtained as required through APIs.
     * For example, <b>'1fr 1fr 2fr'</b> indicates three rows, with the first row taking up 1/4 of the parent
     * component's full height, the second row 1/4, and the third row 2/4.
     * You can use <b>rowsTemplate('repeat(auto-fill,track-size)')</b> to automatically calculate the number of rows
     * based on the specified row height <b>track-size</b>.
     * <b>repeat</b> and <b>auto-fill</b> are keywords. The units for <b>track-size</b> can be px, vp (default), %,
     * or a valid number.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .string: number of rows in the layout. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .string: number of rows in the layout. \n
     *
     */
    NODE_WATER_FLOW_ROW_TEMPLATE,

    /**
     * @brief Sets the gap between columns. This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].f32: gap between columns, in vp.\n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].f32: gap between columns, in vp.\n
     *
     */
    NODE_WATER_FLOW_COLUMN_GAP,

    /**
     * @brief Sets the gap between rows. This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].f32: gap between lines, in vp.\n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].f32: gap between lines, in vp.\n
     *
     */
    NODE_WATER_FLOW_ROW_GAP,

    /**
     * @brief Defines the water flow section configuration.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32: An index calculated from 0 is converted to an integer,
     * indicating that you want to start changing the position of the group.
     * .object: {@ArkUI_WaterFlowSectionOption} object.\n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .object: {@ArkUI_WaterFlowSectionOption} object.\n
     *
     */
    NODE_WATER_FLOW_SECTION_OPTION,

    /**
    * @brief Defines the water flow adapter. The attribute can be set, reset, and obtained as required through APIs.
    *
    * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
    * .object: {@link ArkUI_NodeAdapter} object as the adapter. \n
    */
    NODE_WATER_FLOW_NODE_ADAPTER,

    /**
    * @brief Sets the number of cached items in the water flow adapter.
    * This attribute can be set, reset, and obtained as required through APIs.
    *
    * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
    * .value[0].i32: number of cached items in the water flowadapter. \n
    */
    NODE_WATER_FLOW_CACHED_COUNT,

    /**
     * @brief Set the custom display component at the end of the waterfall flow component.
     *
     * Attribute setting method {@link ArkUI_AttributeItem} parameter format: \n
     * .object: Parameter type {@link ArkUI_NodeHandle}.
     *
     */
    NODE_WATER_FLOW_FOOTER,

    /**
     * @brief Scroll to the specified index.
     * 
     * When activating the smooth animation, all items passed through will be loaded and layout calculated, which can
     * lead to performance issues when loading a large number of items.\n
     * \n
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].i32：The index value of the target element to be slid to in the current container.\n
     * .value[1]?.i32：Set whether there is an action when sliding to the index value of a list item in the list, where
     * 1 indicates an action and 0 indicates no action. Default value is 0。\n
     * .value[2]?.i32：Specify the alignment of the sliding element with the current container，The parameter type is
     * {@link ArkUI_ScrollAlignment}. Default value is </b>ARKUI_SCROLL_ALIGNMENT_START</b>。\n
     *
     */
    NODE_WATER_FLOW_SCROLL_TO_INDEX,

    /**
     * @brief Defines the size constraints to apply to water flow items.
     * This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].f32: minimum width, in vp.\n
     * .value[1].f32: maximum width, in vp.\n
     * .value[2].f32: minimum height, in vp.\n
     * .value[3].f32: maximum height, in vp.\n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].f32: minimum width, in vp.\n
     * .value[1].f32: maximum width, in vp.\n
     * .value[2].f32: minimum height, in vp.\n
     * .value[3].f32: maximum height, in vp.\n
     *
     */
    NODE_WATER_FLOW_ITEM_CONSTRAINT_SIZE,

    /**
     * @brief Set the auxiliary line in the RelativeContaine container, supporting property setting,
     * property reset and property acquisition interfaces.
     *
     * Attribute setting method parameter {@link ArkUI_AttributeItem} format: \n
     * .object: Auxiliary lines within the RelativeContaine container: \n
     *\n
     * Attribute acquisition method return value {@link ArkUI_AttributeItem} format: \n
     * .object: Auxiliary lines within the RelativeContaine container: \n
     *
     */
    NODE_RELATIVE_CONTAINER_GUIDE_LINE = MAX_NODE_SCOPE_NUM * ARKUI_NODE_RELATIVE_CONTAINER,

    /**
     * @brief Sets the barrier within the RelativeContaine container and supports property setting,
     * property reset and property acquisition interfaces.
     *
     * Attribute setting method parameter {@link ArkUI_AttributeItem} format: \n
     * .object: Auxiliary lines within the RelativeContaine container: \n
     *\n
     * Attribute acquisition method return value {@link ArkUI_AttributeItem} format: \n
     * .object: Barrier within the RelativeContaine container: \n
     *
     */
    NODE_RELATIVE_CONTAINER_BARRIER,

    /**
     * @brief Sets the number of columns in the grid layout. If this parameter is not set, one column is used
     * by default. This attribute can be set, reset, and obtained as required through APIs.
     * For example, <b>'1fr 1fr 2fr'</b> indicates three columns, with the first column taking up 1/4 of the parent
     * component's full width, the second column 1/4, and the third column 2/4.
     * You can use <b>columnsTemplate('repeat(auto-fill,track-size)')</b> to automatically calculate the number of
     * columns based on the specified column width <b>track-size</b>.
     * <b>repeat</b> and <b>auto-fill</b> are keywords. The units for <b>track-size</b> can be px, vp (default), %,
     * or a valid number.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .string: number of columns in the layout.\n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .string: number of columns in the layout.\n
     *
     */
    NODE_GRID_COLUMN_TEMPLATE = MAX_NODE_SCOPE_NUM * ARKUI_NODE_GRID,

    /**
     * @brief Sets the number of rows in the grid layout. If this parameter is not set, one row is used
     * by default. This attribute can be set, reset, and obtained as required through APIs.
     * For example, <b>'1fr 1fr 2fr'</b> indicates three rows, with the first row taking up 1/4 of the parent
     * component's full height, the second row 1/4, and the third row 2/4.
     * You can use <b>rowsTemplate('repeat(auto-fill,track-size)')</b> to automatically calculate the number of rows
     * based on the specified row height <b>track-size</b>.
     * <b>repeat</b> and <b>auto-fill</b> are keywords. The units for <b>track-size</b> can be px, vp (default), %,
     * or a valid number.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .string: number of rows in the layout. \n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .string: number of rows in the layout. \n
     *
     */
    NODE_GRID_ROW_TEMPLATE,

    /**
     * @brief Sets the gap between columns. This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].f32: gap between columns, in vp.\n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].f32: gap between columns, in vp.\n
     *
     */
    NODE_GRID_COLUMN_GAP,

    /**
     * @brief Sets the gap between rows. This attribute can be set, reset, and obtained as required through APIs.
     *
     * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
     * .value[0].f32: gap between lines, in vp.\n
     * \n
     * Format of the return value {@link ArkUI_AttributeItem}:\n
     * .value[0].f32: gap between lines, in vp.\n
     *
     */
    NODE_GRID_ROW_GAP,

    /**
    * @brief Defines the grid adapter. The attribute can be set, reset, and obtained as required through APIs.
    *
    * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
    * .object: {@link ArkUI_NodeAdapter} object as the adapter. \n
    */
    NODE_GRID_NODE_ADAPTER,

    /**
    * @brief Sets the number of cached items in the grid adapter.
    * This attribute can be set, reset, and obtained as required through APIs.
    *
    * Format of the {@link ArkUI_AttributeItem} parameter for setting the attribute:\n
    * .value[0].i32: number of cached items in the grid adapter. \n
    */
    NODE_GRID_CACHED_COUNT,
} ArkUI_NodeAttributeType;

#define MAX_COMPONENT_EVENT_ARG_NUM 12
/**
 * @brief Defines the parameter type of the component callback event.
 *
 * @since 12
 */
typedef struct {
    /** Data array object. */
    ArkUI_NumberValue data[MAX_COMPONENT_EVENT_ARG_NUM];
} ArkUI_NodeComponentEvent;

/**
 * @brief Defines the string type parameter used by the component callback event.
 *
 * @since 12
 */
typedef struct {
    /** String. */
    const char* pStr;
} ArkUI_StringAsyncEvent;

/**
 * @brief Enumerates the event types supported by the NativeNode component.
 *
 * @since 12
 */
typedef enum {
    /**
     * @brief Defines the gesture event type.
     *
     * When the event callback occurs, the union type in the {@link ArkUI_NodeEvent} object is
     * {@link ArkUI_UIInputEvent}.
     */
    NODE_TOUCH_EVENT = 0,

    /**
     * @brief Defines the mount event.
     *
     * This event is triggered when the component is mounted and displayed. \n
     * When the event callback occurs, the union type in the {@link ArkUI_NodeEvent} object is
     * {@link ArkUI_NodeComponentEvent}. \n
     * {@link ArkUI_NodeComponentEvent} does not contain parameters.
     */
    NODE_EVENT_ON_APPEAR,
    /**
     * @brief Defines the unmount event.
     *
     * This event is triggered when the component is unmounted and hidden. \n
     * When the event callback occurs, the union type in the {@link ArkUI_NodeEvent} object is
     * {@link ArkUI_NodeComponentEvent}. \n
     * {@link ArkUI_NodeComponentEvent} does not contain parameters.
     */
    NODE_EVENT_ON_DISAPPEAR,

    /**
     * @brief Defines the area change event.
     *
     * This event is triggered when the component's size, position, or any other attribute that may
     * affect its display area changes. \n
     * When the event callback occurs, the union type in the {@link ArkUI_NodeEvent} object is
     *  {@link ArkUI_NodeComponentEvent}. \n
     * {@link ArkUI_NodeComponentEvent} contains 12 parameters:\n
     * <b>ArkUI_NodeComponentEvent.data[0].f32</b>: original width of the target element, in vp.
     * The value type is number. \n
     * <b>ArkUI_NodeComponentEvent.data[1].f32</b>: original height of the target element, in vp.
     * The value type is number. \n
     * <b>ArkUI_NodeComponentEvent.data[2].f32</b>: original X coordinate of the target element's upper left corner
     * relative to the parent element's, in vp. The value type is number. \n
     * <b>ArkUI_NodeComponentEvent.data[3].f32</b>: original Y coordinate of the target element's upper left corner
     * relative to the parent element's, in vp. The value type is number. \n
     * <b>ArkUI_NodeComponentEvent.data[4].f32</b>: original X coordinate of the target element's upper left corner
     * relative to the page's, in vp. The value type is number. \n
     * <b>ArkUI_NodeComponentEvent.data[5].f32</b>: original Y coordinate of the target element's upper left corner
     * relative to the page's, in vp. The value type is number. \n
     * <b>ArkUI_NodeComponentEvent.data[6].f32</b>: new width of the target element, in vp. The value is a number. \n
     * <b>ArkUI_NodeComponentEvent.data[7].f32</b>: new height of the target element, in vp. The value is a number. \n
     * <b>ArkUI_NodeComponentEvent.data[8].f32</b>: new X coordinate of the target element's upper left corner relative
     * to the parent element's, in vp. The value type is number. \n
     * <b>ArkUI_NodeComponentEvent.data[9].f32</b>: new Y coordinate of the target element's upper left corner relative
     * to the parent element's, in vp. The value type is number. \n
     * <b>ArkUI_NodeComponentEvent.data[10].f32</b>: new X coordinate of the target element's upper left corner relative
     * to the page's, in vp. The value type is number. \n
     * <b>ArkUI_NodeComponentEvent.data[11].f32</b>: new Y coordinate of the target element's upper left corner relative
     * to the page's, in vp. The value type is number. \n
     */
    NODE_EVENT_ON_AREA_CHANGE,
    /**
     * @brief Defines the focus event.
     *
     * This event is triggered when the component obtains the focus. \n
     * When the event callback occurs, the union type in the {@link ArkUI_NodeEvent} object is
     * {@link ArkUI_NodeComponentEvent}. \n
     * {@link ArkUI_NodeComponentEvent} does not contain parameters.
     */
    NODE_ON_FOCUS,
    /**
     * @brief Defines the blur event.
     *
     * This event is triggered when the component loses the focus. \n
     * When the event callback occurs, the union type in the {@link ArkUI_NodeEvent} object is
     * {@link ArkUI_NodeComponentEvent}. \n
     * {@link ArkUI_NodeComponentEvent} does not contain parameters.
     */
    NODE_ON_BLUR,
    /**
     * @brief Defines the click event.
     *
     * This event is triggered when the component is clicked. \n
     * When the event callback occurs, the union type in the {@link ArkUI_NodeEvent} object is
     * {@link ArkUI_NodeComponentEvent}. \n
     * {@link ArkUI_NodeComponentEvent} contains 12 parameters:\n
     * <b>ArkUI_NodeComponentEvent.data[0].f32</b>: X coordinate of the click relative to the upper left corner of the
     * clicked component's original area, in vp. \n
     * <b>ArkUI_NodeComponentEvent.data[1].f32</b>: Y coordinate of the click relative to the upper left corner of the
     * clicked component's original area, in vp. \n
     * <b>ArkUI_NodeComponentEvent.data[2].f32</b>: event timestamp. It is the interval between the time when the event
     * is triggered and the time when the system starts, in microseconds. \n
     * <b>ArkUI_NodeComponentEvent.data[3].i32</b>: event input device. The value <b>1</b> indicates the mouse,
     * <b>2</b> indicates the touchscreen, and <b>4</b> indicates the key. \n
     * <b>ArkUI_NodeComponentEvent.data[4].f32</b>: X coordinate of the click relative to the upper left corner of the
     * application window, in vp. \n
     * <b>ArkUI_NodeComponentEvent.data[5].f32</b>: Y coordinate of the click relative to the upper left corner of the
     * application window, in vp. \n
     * <b>ArkUI_NodeComponentEvent.data[6].f32</b>: X coordinate of the click relative to the upper left corner of the
     * application screen, in vp. \n
     * <b>ArkUI_NodeComponentEvent.data[7].f32</b>: Y coordinate of the click relative to the upper left corner of the
     * application screen, in vp. \n
     */
    NODE_ON_CLICK,
    /**
     * @brief Defines event interception.
     *
     * This event is triggered when the component is touched. \n
     * When the event callback occurs, the union type in the {@link ArkUI_NodeEvent} object is
     * {@link ArkUI_UIInputEvent}. \n
     */
    NODE_ON_TOUCH_INTERCEPT,
    /**
     * @brief Defines the visible area change event.
     *
     * This event is triggered when the ratio of the component's visible area to its total area is greater than or less
     * than the threshold. \n
     * The format of the input parameter {@link ArkUI_AttributeItem} is as follows:\n
     * .value[0...].f32: threshold array. Each threshold represents a ratio of the component's visible area to the
     * component's total area. The value range of the threshold is [0.0, 1.0]. \n
     * When the event callback occurs, the union type in the {@link ArkUI_NodeEvent} object is
     * {@link ArkUI_NodeComponentEvent}. \n
     * {@link ArkUI_NodeComponentEvent} contains two parameters:\n
     * <b>ArkUI_NodeComponentEvent.data[0].i32</b>: how the ratio of the component's visible area to its total area
     * changes compared to the previous one. The value <b>1</b> indicates an increase, and <b>0</b> indicates a
     * decrease. \n
     * <b>ArkUI_NodeComponentEvent.data[1].f32</b>: ratio of the component's visible area to its total area when this
     * callback is invoked. \n
     */
    NODE_EVENT_ON_VISIBLE_AREA_CHANGE,
    /**
     * @brief Defines the event triggered when the mouse pointer is moved over or away from the component.
     *
      \n
     * When the event callback occurs, the union type in the {@link ArkUI_NodeEvent} object is
     * {@link ArkUI_NodeComponentEvent}. \n
     * {@link ArkUI_NodeComponentEvent} contains one parameter:\n
     * <b>ArkUI_NodeComponentEvent.data[0].i32</b>: whether the mouse pointer is hovered over the component.
     * The value <b>1</b> indicates that the mouse pointer is hovered over the component, and <b>0</b> indicates that
     * the mouse pointer is moved away from the component. \n
     */
    NODE_ON_HOVER,
    /**
     * @brief Defines the click event.
     *
     * This event is triggered when the component is clicked by a mouse device button or when the mouse pointer moves
     * within the component. \n
     * When the event callback occurs, the union type in the {@link ArkUI_NodeEvent} object is
     * {@link ArkUI_UIInputEvent}. \n
     */
    NODE_ON_MOUSE,
    /**
     * @brief Defines the attach event.
     *
     * This event is triggered when the component is attached. \n
     * When the event callback occurs, the union type in the {@link ArkUI_NodeEvent} object is
     * {@link ArkUI_NodeComponentEvent}. \n
     * {@link ArkUI_NodeComponentEvent} does not contain parameters.
     */
    NODE_EVENT_ON_ATTACH,
    /**
     * @brief Defines the detach event.
     *
     * This event is triggered when the component is detached. \n
     * When the event callback occurs, the union type in the {@link ArkUI_NodeEvent} object is
     * {@link ArkUI_NodeComponentEvent}. \n
     * {@link ArkUI_NodeComponentEvent} does not contain parameters.
     */
    NODE_EVENT_ON_DETACH,

    /**
     * @brief Triggers onDetectResultUpdate callback
     * when the text is set to TextDataDetectorConfig and recognized successfully.
     *
     * Trigger this event when TextDataDetectorConfig is set and recognized successfully.\n
     * When the event callback occurs, the event parameter{@link ArkUI_NodeEvent}The union type in the object is
     * {@link ArkUI_StringAsyncEvent}.\n
     * {@link ArkUI_StringAsyncEvent}contains 1 parameter\n
     * <b>ArkUI_StringAsyncEvent.pStr</b>：Indicates the result of text recognition, in Json format.\n
     *
     */
    NODE_TEXT_ON_DETECT_RESULT_UPDATE = MAX_NODE_SCOPE_NUM * ARKUI_NODE_TEXT,
    /**
     * @brief Defines the image loading success event.
     *
     * This event is triggered when an image is successfully loaded or decoded. \n
     * When the event callback occurs, the union type in the {@link ArkUI_NodeEvent} object is
     * {@link ArkUI_NodeComponentEvent}. \n
     * {@link ArkUI_NodeComponentEvent} contains nine parameters:\n
     * <b>ArkUI_NodeComponentEvent.data[0].i32</b>: loading status. The value <b>0</b> indicates that the image is
     * loaded successfully, and the value <b>1</b> indicates that the image is decoded successfully. \n
     * <b>ArkUI_NodeComponentEvent.data[1].f32</b>: width of the image, in px. \n
     * <b>ArkUI_NodeComponentEvent.data[2].f32</b>: height of the image, in px. \n
     * <b>ArkUI_NodeComponentEvent.data[3].f32</b>: width of the component, in px. \n
     * <b>ArkUI_NodeComponentEvent.data[4].f32</b>: height of the component, in px. \n
     * <b>ArkUI_NodeComponentEvent.data[5].f32</b>: offset of the rendered content relative to the component on the
     * x-axis, in px. \n
     * <b>ArkUI_NodeComponentEvent.data[6].f32</b>: offset of the rendered content relative to the component on the
     * y-axis, in px. \n
     * <b>ArkUI_NodeComponentEvent.data[7].f32</b>: actual rendered width of the image, in px. \n
     * <b>ArkUI_NodeComponentEvent.data[8].f32</b>: actual rendered height of the image, in px. \n
     */
    NODE_IMAGE_ON_COMPLETE = MAX_NODE_SCOPE_NUM * ARKUI_NODE_IMAGE,
    /**
     * @brief Defines the image loading failure event.
     *
     * This event is triggered when an error occurs during image loading. \n
     * When the event callback occurs, the union type in the {@link ArkUI_NodeEvent} object is
     * {@link ArkUI_NodeComponentEvent}. \n
     * {@link ArkUI_NodeComponentEvent} contains one parameter:\n
     * <b>ArkUI_NodeComponentEvent.data[0].i32</b>error code:\n
     * 401: The image could not be obtained because the image path is invalid. \n
     * 103101: The image format is not supported. \n
     */
    NODE_IMAGE_ON_ERROR,
    /**
     * @brief Defines the SVG animation playback completion event.
     *
     * This event is triggered when the animation playback in the loaded SVG image is complete. \n
     * When the event callback occurs, the union type in the {@link ArkUI_NodeEvent} object is
     * {@link ArkUI_NodeComponentEvent}. \n
     * {@link ArkUI_NodeComponentEvent} does not contain parameters.
     */
    NODE_IMAGE_ON_SVG_PLAY_FINISH,
    /**
     * @brief Defines image download process event.
     *
     * This event is triggered when downloading webpage images from page components.\n
     * When the event callback occurs, the union type in the {@link ArkUI_NodeEvent} object is
     * {@link ArkUI_NodeComponentEvent}. \n
     * {@link ArkUI_NodeComponentEvent} contains two parameter:\n
     * <b>ArkUI_NodeComponentEvent.data[0].u32</b>: the num of bytes downloaded. \n
     * <b>ArkUI_NodeComponentEvent.data[1].u32</b>: the total number of bytes to download. \n
     */
    NODE_IMAGE_ON_DOWNLOAD_PROGRESS,
    /**
     * @brief Defines the event triggered when the toggle status changes.
     *
      \n
     * When the event callback occurs, the union type in the {@link ArkUI_NodeEvent} object is
     * {@link ArkUI_NodeComponentEvent}. \n
     * {@link ArkUI_NodeComponentEvent} contains one parameter: \n
     * <b>ArkUI_NodeComponentEvent.data[0].i32</b>: toggle status. <b>1</b>: on; <b>0</b>: off.
     *
     */
    NODE_TOGGLE_ON_CHANGE = MAX_NODE_SCOPE_NUM * ARKUI_NODE_TOGGLE,
    /**
     * @brief Defines the event triggered when the text input content changes.
     *
      \n
     * When the event callback occurs, the union type in the {@link ArkUI_NodeEvent} object is
     * {@link ArkUI_StringAsyncEvent}. \n
     * {@link ArkUI_StringAsyncEvent} contains one parameter:\n
     * <b>ArkUI_StringAsyncEvent.pStr</b>: text input.
     *
     */
    NODE_TEXT_INPUT_ON_CHANGE = MAX_NODE_SCOPE_NUM * ARKUI_NODE_TEXT_INPUT,
    /**
     * @brief Defines the event triggered when the Enter key of the text input method is pressed.
     *
      \n
     * When the event callback occurs, the union type in the {@link ArkUI_NodeEvent} object is
     * {@link ArkUI_NodeComponentEvent}. \n
     * {@link ArkUI_NodeComponentEvent} contains one parameter:\n
     * <b>ArkUI_NodeComponentEvent.data[0].i32</b>: Enter key type of the input method.
     *
     */
    NODE_TEXT_INPUT_ON_SUBMIT,
    /**
     * @brief Defines the event triggered when the cut button on the pasteboard, which displays when the text box
     * is long pressed, is clicked.
     *
      \n
     * When the event callback occurs, the union type in the {@link ArkUI_NodeEvent} object is
     * {@link ArkUI_StringAsyncEvent}. \n
     * {@link ArkUI_StringAsyncEvent} contains one parameter:\n
     * <b>ArkUI_StringAsyncEvent.pStr</b>: text that is cut.
     *
     */
    NODE_TEXT_INPUT_ON_CUT,
    /**
     * @brief Defines the event triggered when the paste button on the pasteboard, which displays when the text box
     * is long pressed, is clicked.
     *
      \n
     * When the event callback occurs, the union type in the {@link ArkUI_NodeEvent} object is
     * {@link ArkUI_StringAsyncEvent}. \n
     * {@link ArkUI_StringAsyncEvent} contains one parameter:\n
     * <b>ArkUI_StringAsyncEvent.pStr</b>: text that is pasted
     *
     */
    NODE_TEXT_INPUT_ON_PASTE,
    /**
     * @brief Defines the event triggered when the text selection position changes.
     *
      \n
     * When the event callback occurs, the union type in the {@link ArkUI_NodeEvent} object is
     * {@link ArkUI_NodeComponentEvent}. \n
     * {@link ArkUI_NodeComponentEvent} contains two parameters:\n
     * <b>ArkUI_NodeComponentEvent.data[0].i32</b>: start position of the text selection area. \n
     * <b>ArkUI_NodeComponentEvent.data[1].i32</b>: end position of the text selection area. \n
     *
     */
    NODE_TEXT_INPUT_ON_TEXT_SELECTION_CHANGE,

    /**
     * @brief Defines the event triggered when the input status changes.
     *
      \n
     * When the event callback occurs, the union type in the {@link ArkUI_NodeEvent} object is
     * {@link ArkUI_NodeComponentEvent}. \n
     * {@link ArkUI_NodeComponentEvent} contains one parameter:\n
     * <b>ArkUI_NodeComponentEvent.data[0].i32</b>: <b>true</b> indicates that text input is in progress. \n
     *
     */
    NODE_TEXT_INPUT_ON_EDIT_CHANGE,

    /**
      * @brief textInput This event is triggered when the input content changes.
      *
      * Conditions for triggering this event: When the input content changes. \n
      * When the event callback occurs, the union type in the event parameter
      * {@link ArkUI_NodeEvent} object is {@link ArkUI_NodeComponentEvent}. \n
      * {@link ArkUI_NodeComponentEvent} contains 2 parameters:\n
      * <b>ArkUI_NodeComponentEvent.data[0].f32</b>: Indicates the width of the text. \n
      * <b>ArkUI_NodeComponentEvent.data[1].f32</b>: Indicates the height of the text. \n
      *
      */
    NODE_TEXT_INPUT_ON_CONTENT_SIZE_CHANGE,

    /**
     * @brief Defines the event triggered when matching with the regular expression specified by
     * <b>NODE_TEXT_INPUT_INPUT_FILTER</b> fails.
     *
      \n
     * When the event callback occurs, the union type in the {@link ArkUI_NodeEvent} object is
     * {@link ArkUI_StringAsyncEvent}. \n
     * {@link ArkUI_StringAsyncEvent} contains one parameter:\n
     * <b>ArkUI_StringAsyncEvent.pStr</b>: content that is filtered out when regular expression matching fails. \n
     *
     */
    NODE_TEXT_INPUT_ON_INPUT_FILTER_ERROR,
    /**
     * @brief This callback is triggered when the text content is scrolled.
     *
      \n
     * When the event callback occurs, the union type in the {@link ArkUI_NodeEvent} object is
     * {@link ArkUI_NodeComponentEvent}. \n
     * {@link ArkUI_NodeComponentEvent} contains two parameters:\n
     * <b>ArkUI_NodeComponentEvent.data[0].i32</b>: Indicates the horizontal offset of the text in the content area. \n
     * <b>ArkUI_NodeComponentEvent.data[1].i32</b>: Indicates the vertical coordinate offset of \n
     * the text in the content area. \n
     *
     */
    NODE_TEXT_INPUT_ON_CONTENT_SCROLL,
    /**
     * @brief Defines the event triggered when the input in the text box changes.
     *
      \n
     * When the event callback occurs, the union type in the {@link ArkUI_NodeEvent} object is
     * {@link ArkUI_StringAsyncEvent}. \n
     * {@link ArkUI_StringAsyncEvent} contains one parameter:\n
     * <b>ArkUI_StringAsyncEvent.pStr</b>: text entered.
     *
     */
    NODE_TEXT_AREA_ON_CHANGE = MAX_NODE_SCOPE_NUM * ARKUI_NODE_TEXT_AREA,
    /**
     * @brief Defines the event triggered when the paste button on the pasteboard, which displays when the text box is
     * long pressed, is clicked.
     *
      \n
     * When the event callback occurs, the union type in the {@link ArkUI_NodeEvent} object is
     * {@link ArkUI_StringAsyncEvent}. \n
     * {@link ArkUI_StringAsyncEvent} contains one parameter:\n
     * <b>ArkUI_StringAsyncEvent.pStr</b>: text that is pasted
     *
     */
    NODE_TEXT_AREA_ON_PASTE,
    /**
     * @brief Defines the event triggered when the text selection position changes.
     *
      \n
     * When the event callback occurs, the union type in the {@link ArkUI_NodeEvent} object is
     * {@link ArkUI_NodeComponentEvent}. \n
     * {@link ArkUI_NodeComponentEvent} contains two parameters:\n
     * <b>ArkUI_NodeComponentEvent.data[0].i32</b>: start position of the text selection area. \n
     * <b>ArkUI_NodeComponentEvent.data[1].i32</b>: end position of the text selection area. \n
     *
     */
    NODE_TEXT_AREA_ON_TEXT_SELECTION_CHANGE,
    /**
     * @brief Defines the event triggered when matching with the regular expression specified by
     * <b>NODE_TEXT_AREA_INPUT_FILTER</b> fails.
     *
      \n
     * When the event callback occurs, the union type in the {@link ArkUI_NodeEvent} object is
     * {@link ArkUI_StringAsyncEvent}. \n
     * {@link ArkUI_StringAsyncEvent} contains one parameter:\n
     * <b>ArkUI_StringAsyncEvent.pStr</b>: content that is filtered out when regular expression matching fails. \n
     *
     */
    NODE_TEXT_AREA_ON_INPUT_FILTER_ERROR,
    /**
     * @brief This callback is triggered when the text content is scrolled.
     *
      \n
     * When the event callback occurs, the union type in the {@link ArkUI_NodeEvent} object is
     * {@link ArkUI_NodeComponentEvent}. \n
     * {@link ArkUI_NodeComponentEvent} contains two parameters:\n
     * <b>ArkUI_NodeComponentEvent.data[0].i32</b>: Indicates the horizontal offset of the text in the content area. \n
     * <b>ArkUI_NodeComponentEvent.data[1].i32</b>: Indicates the vertical coordinate offset of \n
     * the text in the content area. \n
     *
     */
    NODE_TEXT_AREA_ON_CONTENT_SCROLL,

    /**
     * @brief Defines the event triggered when the input status changes.
     *
      \n
     * When the event callback occurs, the union type in the {@link ArkUI_NodeEvent} object is \n
     * {@link ArkUI_NodeComponentEvent}. \n
     * {@link ArkUI_NodeComponentEvent} contains one parameter:\n
     * <b>ArkUI_NodeComponentEvent.data[0].i32</b>: <b>true</b> indicates that text input is in progress. \n
     *
     */
    NODE_TEXT_AREA_ON_EDIT_CHANGE,

    /**
     * @brief Defines the event triggered when the Enter key on the keyboard is pressed for the multi-line text box.
     *
     * This event is not triggered when <b>keyType</b> is <b>ARKUI_ENTER_KEY_TYPE_NEW_LINE</b>. \n
     * When the event callback occurs, the union type in the {@link ArkUI_NodeEvent} object is \n
     * {@link ArkUI_NodeComponentEvent}. \n
     * {@link ArkUI_NodeComponentEvent} contains one parameter:\n
     * <b>ArkUI_NodeComponentEvent.data[0].i32</b>: type of the Enter key.
     *
     */
    NODE_TEXT_AREA_ON_SUBMIT,

    /**
      * @brief textArea This event is triggered when the input content changes.
      *
      * Conditions for triggering this event: When the input content changes. \n
      * When the event callback occurs, the union type in the event parameter {@link ArkUI_NodeEvent} object is \n
      * {@link ArkUI_NodeComponentEvent}.\n
      * {@link ArkUI_NodeComponentEvent} contains 2 parameters:\n
      * <b>ArkUI_NodeComponentEvent.data[0].f32</b>: Indicates the width of the text. \n
      * <b>ArkUI_NodeComponentEvent.data[1].f32</b>: Indicates the height of the text. \n
      *
      */
    NODE_TEXT_AREA_ON_CONTENT_SIZE_CHANGE,

    /**
     * @brief Defines the event triggered when the selected status of the <b>ARKUI_NODE_CHECKBOX</b> component changes.
     *
     * When the event callback occurs, the union type in the {@link ArkUI_NodeEvent} object is
     * {@link ArkUI_NodeComponentEvent}. \n
     * <b>ArkUI_NodeComponentEvent.data[0].i32</b><b>1</b>: selected; <b>0</b>: not selected.\n
     */
    NODE_CHECKBOX_EVENT_ON_CHANGE = MAX_NODE_SCOPE_NUM * ARKUI_NODE_CHECKBOX,

    /**
     * @brief Defines the event triggered when a date is selected in the <b>ARKUI_NODE_DATE_PICKER</b> component.
     *
      \n
     * When the event callback occurs, the union type in the {@link ArkUI_NodeEvent} object is
     * {@link ArkUI_NodeComponentEvent}. \n
     * {@link ArkUI_NodeComponentEvent} contains three parameters:\n
     * <b>ArkUI_NodeComponentEvent.data[0].i32</b>: year of the selected date. \n
     * <b>ArkUI_NodeComponentEvent.data[1].i32</b>: month of the selected date. Value range: [0-11]. \n
     * <b>ArkUI_NodeComponentEvent.data[2].i32</b>: day of the selected date. \n
     */
    NODE_DATE_PICKER_EVENT_ON_DATE_CHANGE = MAX_NODE_SCOPE_NUM * ARKUI_NODE_DATE_PICKER,

    /**
     * @brief Defines the event triggered when a time is selected in the <b>ARKUI_NODE_TIME_PICKER</b> component.
     *
      \n
     * When the event callback occurs, the union type in the {@link ArkUI_NodeEvent} object is
     * {@link ArkUI_NodeComponentEvent}. \n
     * {@link ArkUI_NodeComponentEvent} contains two parameters:\n
     * <b>ArkUI_NodeComponentEvent.data[0].i32</b>: hour of the selected time. Value range: [0-23]. \n
     * <b>ArkUI_NodeComponentEvent.data[1].i32</b>: minute of the selected time. Value range: [0-59]. \n
     */
    NODE_TIME_PICKER_EVENT_ON_CHANGE = MAX_NODE_SCOPE_NUM * ARKUI_NODE_TIME_PICKER,

    /**
     * @brief Defines the event triggered when an item is selected in the <b>ARKUI_NODE_TEXT_PICKER</b> component.
     *
      \n
     * When the event callback occurs, the union type in the {@link ArkUI_NodeEvent} object is
     * {@link ArkUI_NodeComponentEvent}. \n
     * {@link ArkUI_NodeComponentEvent} contains one parameter:\n
     * <b>ArkUI_NodeComponentEvent.data[0...11].i32</b>: value of the selected item. \n
     */
    NODE_TEXT_PICKER_EVENT_ON_CHANGE = MAX_NODE_SCOPE_NUM * ARKUI_NODE_TEXT_PICKER,

    /**
     * @brief Defines the event triggered when a date is selected in the <b>NODE_CALENDAR_PICKER</b>.
     *
     * When the event callback occurs, the union type in the {@link ArkUI_NodeEvent} object is
     * {@link ArkUI_NodeComponentEvent}. \n
     * <b>ArkUI_NodeComponent.data[0].u32</b>: year of the selected date. \n
     * <b>ArkUI_NodeComponent.data[1].u32</b>: month of the selected date. \n
     * <b>ArkUI_NodeComponent.data[2].u32</b>: day of the selected date. \n
     */
    NODE_CALENDAR_PICKER_EVENT_ON_CHANGE = MAX_NODE_SCOPE_NUM * ARKUI_NODE_CALENDAR_PICKER,

    /**
     * @brief Defines the event triggered when the <b>ARKUI_NODE_SLIDER</b> component is dragged or clicked.
     *
     * When the event callback occurs, the union type in the {@link ArkUI_NodeEvent} object is
     * {@link ArkUI_NodeComponentEvent}. \n
     * {@link ArkUI_NodeComponentEvent} contains two parameters:\n
     * <b>ArkUI_NodeComponentEvent.data[0].f32</b>: current slider value. \n
     * <b>ArkUI_NodeComponentEvent.data[1].i32</b>: state triggered by the event.\n
     */
    NODE_SLIDER_EVENT_ON_CHANGE = MAX_NODE_SCOPE_NUM * ARKUI_NODE_SLIDER,

    /**
     * @brief Defines the event callback function triggered when an object is dragged or clicked by ARKUI_NODE_RADIO.
     * When the event callback occurs, the union type in the {@Link ArkUI_NodeEvent} object is \n
     * {@Link ArkUI_NodeComponentEvent}. \n
     * {@Link ArkUI_NodeComponentEvent} contains one parameter:\n
     * ArkUI_NodeComponentEvent.data[0].i32: option button status. \n
     */
    NODE_RADIO_EVENT_ON_CHANGE = MAX_NODE_SCOPE_NUM * ARKUI_NODE_RADIO,

    /**
     * @brief Defines the event triggered when the index of the currently displayed element of this
     * <b>ARKUI_NODE_SWIPER</b> instance changes.
     *
     * When the event callback occurs, the union type in the {@link ArkUI_NodeEvent} object is
     * {@link ArkUI_NodeComponentEvent}. \n
     * {@link ArkUI_NodeComponentEvent} contains one parameter:\n
     * <b>ArkUI_NodeComponentEvent.data[0].i32</b>: index of the currently displayed element. \n
     */
    NODE_SWIPER_EVENT_ON_CHANGE = MAX_NODE_SCOPE_NUM * ARKUI_NODE_SWIPER,

    /**
     * @brief Defines the event triggered when the switching animation of this <b>ARKUI_NODE_SWIPER</b> instance starts.
     *
     * When the event callback occurs, the union type in the {@link ArkUI_NodeEvent} object is
     * {@link ArkUI_NodeComponentEvent}. \n
     * {@link ArkUI_NodeComponentEvent} contains five parameters: \n
     * <b>ArkUI_NodeComponentEvent.data[0].i32</b>: index of the currently displayed element. \n
     * <b>ArkUI_NodeComponentEvent.data[1].i32</b>: index of the target element to switch to. \n
     * <b>ArkUI_NodeComponentEvent.data[2].f32</b>: offset of the currently displayed element relative to the
     * start position of the swiper along the main axis. \n
     * <b>ArkUI_NodeComponentEvent.data[3].f32</b>: offset of the target element relative to the start position
     * of the swiper along the main axis. \n
     * <b>ArkUI_NodeComponentEvent.data[4].f32</b>: hands-off velocity. \n
     */
    NODE_SWIPER_EVENT_ON_ANIMATION_START,

    /**
     * @brief Defines the event triggered when the switching animation of this <b>ARKUI_NODE_SWIPER</b> instance ends.
     *
     * When the event callback occurs, the union type in the {@link ArkUI_NodeEvent} object is
     * {@link ArkUI_NodeComponentEvent}. \n
     * {@link ArkUI_NodeComponentEvent} contains two parameters:\n
     * <b>ArkUI_NodeComponentEvent.data[0].i32</b>: index of the currently displayed element. \n
     * <b>ArkUI_NodeComponentEvent.data[1].f32</b>: offset of the currently displayed element relative to the
     * start position of the swiper along the main axis. \n
     */
    NODE_SWIPER_EVENT_ON_ANIMATION_END,

    /**
     * @brief Defines the event triggered on a frame-by-frame basis when the page is turned by a swipe in this
     * <b>ARKUI_NODE_SWIPER</b> instance.
     *
     * When the event callback occurs, the union type in the {@link ArkUI_NodeEvent} object is
     * {@link ArkUI_NodeComponentEvent}. \n
     * {@link ArkUI_NodeComponentEvent} contains two parameters:\n
     * <b>ArkUI_NodeComponentEvent.data[0].i32</b>: index of the currently displayed element. \n
     * <b>ArkUI_NodeComponentEvent.data[1].f32</b>: offset of the currently displayed element relative to the
     * start position of the swiper along the main axis. \n
     */
    NODE_SWIPER_EVENT_ON_GESTURE_SWIPE,

    /**
     * @brief Define the <b>ARKUI_NODE_SWIPER</b> to listen for Swiper page slide events.
     * Instruction: \n
     * 1. If the {@link ArkUI_SwiperDisplayModeType} attribute is set to \n
     * ARKUI_SWIPER_DISPLAY_MODE_AUTO_LINEAR, the interface does not take effect. \n
     * 2, circular scenario, set prevMargin and nextMargin attributes, \n
     * so that Swiper front and back end display the same page, the interface does not take effect. \n
     * 3. During page sliding, the ContentDidScrollCallback callback is \n
     * triggered frame-by-frame for all pages in the window. \n
     * For example, when there are two pages in the window with subscripts 0 and 1, \n
     * callbacks with index values 0 and 1 are triggered twice per frame. \n
     * 4, set the swipeByGroup parameter of the displayCount property to \n
     * true if at least one page in the same group is in the window, \n
     * A callback is triggered for all pages in the group. \n
     * When the event callback occurs, the union type in the {@link ArkUI_NodeEvent} object is
     * {@link ArkUI_NodeComponentEvent}. \n
     * {@link ArkUI_NodeComponentEvent} contains four parameters:\n
     * <b>ArkUI_NodeComponentEvent.data[0].i32</b> : indicates the index of the Swiper component, \n
     * which is consistent with the index change in the onChange event. \n
     * <b>ArkUI_NodeComponentEvent.data[1].i32</b> : The index of a page in the window. \n
     * <b>ArkUI_NodeComponentEvent.data[2].f32</b> : The proportion of page movement relative to \n
     * the start position of the Swiper spindle (selectedIndex corresponds to the start position of the page). \n
     * <b>ArkUI_NodeComponentEvent.data[3].f32</b> : The length of the page in the axis direction. \n
     */
    NODE_SWIPER_EVENT_ON_CONTENT_DID_SCROLL,

    /**
     * @brief Defines the event triggered when the <b>ARKUI_NODE_SCROLL</b> component scrolls.
     *
     * Notes for triggering the event:\n
     * 1. This event is triggered when scrolling is started by the <b>ARKUI_NODE_SCROLL</b> component or other input
     * settings, such as keyboard and mouse operations. \n
     * 2. Scrolling can be initiated by calling the controller API. \n
     * 3. The out-of-bounds bounce effect is supported. \n
     * When the event callback occurs, the union type in the {@link ArkUI_NodeEvent} object is
     * {@link ArkUI_NodeComponentEvent}. \n
     * {@link ArkUI_NodeComponentEvent} contains two parameters:\n
     * <b>ArkUI_NodeComponentEvent.data[0].f32</b>: horizontal scrolling offset. \n
     * <b>ArkUI_NodeComponentEvent.data[1].f32</b>: vertical scrolling offset. \n
     */
    NODE_SCROLL_EVENT_ON_SCROLL = MAX_NODE_SCOPE_NUM * ARKUI_NODE_SCROLL,
    /**
     * @brief Defines the event triggered when each frame scrolling starts in the <b>ARKUI_NODE_SCROLL</b> component.
     *
     * Notes for triggering the event:\n
     * 1. This event is triggered when scrolling is started by the <b>ARKUI_NODE_SCROLL</b> component or other input
     * settings, such as keyboard and mouse operations. \n
     * 2. This event is not triggered when the controller API is called. \n
     * 3. This event does not support the out-of-bounds bounce effect. \n
     * When the event callback occurs, the union type in the {@link ArkUI_NodeEvent} object is
     * {@link ArkUI_NodeComponentEvent}. \n
     * {@link ArkUI_NodeComponentEvent} contains two parameters:\n
     * <b>ArkUI_NodeComponentEvent.data[0].f32</b>: amount to scroll by. \n
     * <b>ArkUI_NodeComponentEvent.data[1].i32</b>: current scrolling state. \n
     * <b>::ArkUI_NodeComponentEvent</b> contains one return value:\n
     * <b>ArkUI_NodeComponentEvent.data[0].f32</b>: The event handler can work out the amount by which the component
     * needs to scroll based on the real-world situation and return the result in this parameter. \n
     */
    NODE_SCROLL_EVENT_ON_SCROLL_FRAME_BEGIN,

    /**
     * @brief Define the enumeration value of the pre sliding trigger event for the scrolling container component.
     *
     * The conditions that trigger this event: \n
     * 1. When the scrolling component triggers scrolling, it supports input settings such as keyboard and mouse
     * operations that trigger scrolling.\n
     * 2. Called through the rolling controller API interface.\n
     * 3. Cross boundary rebound.\n
     * When an event callback occurs, the union type in the event parameter {@ link ArkUI_NodeEvent} object is
     * {@link ArkUI_NodeComponentEvent}. \n
     * {@link ArkUI_NodeComponentEvent} contains three parameters: \n
     * <b>ArkUI_NodeComponentEvent.data[0].f32</b>: The offset for each frame of scrolling is positive when scrolling to
     * the left and negative when scrolling to the right, measured in vp. \n
     * <b>ArkUI_NodeComponentEvent.data[1].f32</b>: The offset of each frame scrolling, with a positive offset when
     * scrolling up and a negative offset when scrolling down, measured in vp. \n
     * <b>ArkUI_NodeComponentEvent.data[2].i32</b>: Current sliding state,\n
     * parameter type is {@link ArkUI_ScrollState}.\n
     */
    NODE_SCROLL_EVENT_ON_WILL_SCROLL,
    /**
     * @brief Define the event enumeration value triggered when sliding a scrolling container component.
     *
     * The conditions that trigger this event: \n
     * 1. When the scrolling component triggers scrolling, it supports input settings such as keyboard and mouse
     * operations that trigger scrolling.\n
     * 2. Called through the rolling controller API interface.\n
     * 3. Cross boundary rebound.\n
     * When an event callback occurs, the union type in the event parameter {@ link ArkUI_NodeEvent} object is
     * {@link ArkUI_NodeComponentEvent}. \n
     * {@link ArkUI_NodeComponentEvent} contains three parameters: \n
     * <b>ArkUI_NodeComponentEvent.data[0].f32</b>: The offset for each frame of scrolling is positive when scrolling to
     * the left and negative when scrolling to the right, measured in vp. \n
     * <b>ArkUI_NodeComponentEvent.data[1].f32</b>: The offset of each frame scrolling, with a positive offset when
     * scrolling up and a negative offset when scrolling down, measured in vp. \n
     * <b>ArkUI_NodeComponentEvent.data[2].i32</b>: Current sliding state, \n
     parameter type is {@link ArkUI_ScrollState}. \n
     */
    NODE_SCROLL_EVENT_ON_DID_SCROLL,

    /**
     * @brief Defines the event triggered when scrolling starts in the <b>ARKUI_NODE_SCROLL</b> component.
     *
     * Notes for triggering the event:\n
     * 1. This event is triggered when scrolling is started, with support for other input settings, such as keyboard
     * and mouse operations. \n
     * 2. This event is triggered when the controller API is called, accompanied by a transition animation. \n
     * When the event callback occurs, the union type in the {@link ArkUI_NodeEvent} object is
     * {@link ArkUI_NodeComponentEvent}. \n
     * {@link ArkUI_NodeComponentEvent} does not contain parameters. \n
     */
    NODE_SCROLL_EVENT_ON_SCROLL_START,
    /**
     * @brief Defines the event triggered when scrolling of the <b>ARKUI_NODE_SCROLL</b> component stops.
     *
     * Notes for triggering the event:\n
     * 1. This event is triggered when scrolling is stopped by the <b>ARKUI_NODE_SCROLL</b> component or other input
     * settings, such as keyboard and mouse operations. \n
     * 2. This event is triggered when the controller API is called, accompanied by a transition animation. \n
     * When the event callback occurs, the union type in the {@link ArkUI_NodeEvent} object is
     * {@link ArkUI_NodeComponentEvent}. \n
     * {@link ArkUI_NodeComponentEvent} does not contain parameters. \n
     */
    NODE_SCROLL_EVENT_ON_SCROLL_STOP,
    /**
     * @brief Defines the event triggered when scrolling of the <b>ARKUI_NODE_SCROLL</b> component reaches
     * one of the edges.
     *
     * Notes for triggering the event:\n
     * 1. This event is triggered when scrolling reaches the edge after being started by the <b>ARKUI_NODE_SCROLL</b>
     * component or other input settings, such as keyboard and mouse operations. \n
     * 2. Scrolling can be initiated by calling the controller API. \n
     * 3. The out-of-bounds bounce effect is supported. \n
     * When the event callback occurs, the union type in the {@link ArkUI_NodeEvent} object is
     * {@link ArkUI_NodeComponentEvent}. \n
     * {@link ArkUI_NodeComponentEvent} contains one parameter. \n
     * <b>ArkUI_NodeComponentEvent.data[0].i32</b>: edge (top, bottom, left, or right) that the scrolling reaches. \n
     */
    NODE_SCROLL_EVENT_ON_SCROLL_EDGE,
    /**
     * @brief Define that a callback is triggered when the scrolling container component reaches the start position.
     * Condition for triggering the event: \n
     * Triggered when the component reaches the start position. \n
     * When the event callback occurs, the union type in the {@Link ArkUI_NodeEvent} object is
     * {@Link ArkUI_NodeComponentEvent}. \n
     * {@Link ArkUI_NodeComponentEvent} contains no parameters. \n
     */
    NODE_SCROLL_EVENT_ON_REACH_START,
    /**
     * @brief Define that a callback is triggered when the scrolling container component ends. \n
     * Condition for triggering the event: \n
     * Triggered when the component reaches the end. \n
     * When the event callback occurs, the union type in the {@Link ArkUI_NodeEvent} object is
     * {@Link ArkUI_NodeComponentEvent}. \n
     * {@Link ArkUI_NodeComponentEvent} contains no parameters. \n
     */
    NODE_SCROLL_EVENT_ON_REACH_END,
    /**
     * @brief Defines the enumerated values of the event triggered, \n
     * when a subcomponent of ARKUI_NODE_LIST is moved into or out of the list display area. \n
     * Condition for triggering the event: \n
     * This method is triggered once during list initialization. \n
     * It is triggered when the index value of the first or last subcomponent in the list display area changes. \n
     * When the event callback occurs, the union type in the {@Link ArkUI_NodeEvent} object is
     * {@Link ArkUI_NodeComponentEvent}. \n
     * {@Link ArkUI_NodeComponentEvent} contains three parameters: \n
     * ArkUI_NodeComponentEvent.data[0].i32: List Displays the index value of \n
     * the first child component in the region. \n
     * ArkUI_NodeComponentEvent.data[1].i32: List Displays the index value of \n
     * the last child component in the region. \n
     * ArkUI_NodeComponentEvent.data[2].i32: List Displays the index value of \n
     * the subcomponent in the middle of the area. \n
     */
    NODE_LIST_ON_SCROLL_INDEX = MAX_NODE_SCOPE_NUM * ARKUI_NODE_LIST,
    /**
     * @brief Defines the enumerated values of the event triggered
     * before the sliding of the ARKUI_NODE_LIST component. \n
     * Condition for triggering the event: \n
     * This event is triggered when the scrolling component triggers scrolling. \n
     * Other inputs that trigger scrolling, such as keyboard and mouse operations, can be set. \n
     * Called through the scroll controller API. \n
     * Out-of-bounds rebound. \n
     * When the event callback occurs, the union type in the {@Link ArkUI_NodeEvent} object is \n
     * {@Link ArkUI_NodeComponentEvent}. \n
     * {@Link ArkUI_NodeComponentEvent} contains two parameters: \n
     * ArkUI_NodeComponentEvent.data[0].f32: offset of each frame scrolling. \n
     * The offset is positive when the list content is scrolled up and \n
     * is negative when the list content is scrolled down. \n
     * ArkUI_NodeComponentEvent.data[1].i32: Current sliding state. \n
     */
    NODE_LIST_ON_WILL_SCROLL,
    /**
     * @brief Define the enumerated values of the event triggered when the ARKUI_NODE_LIST component is flicked.
     * Condition for triggering the event: \n
     * This event is triggered when the scrolling component triggers scrolling. \n
     * Other inputs that trigger scrolling, such as keyboard and mouse operations, can be set. \n
     * Called through the scroll controller API. \n
     * Out-of-bounds rebound. \n
     * When the event callback occurs, the union type in the {@Link ArkUI_NodeEvent} object is \n
     * {@Link ArkUI_NodeComponentEvent}. \n
     * {@Link ArkUI_NodeComponentEvent} contains two parameters:\n
     * ArkUI_NodeComponentEvent.data[0].f32: offset of each frame scrolling. \n
     * The offset is positive when the list content is scrolled up and \n
     * is negative when the list content is scrolled down. \n
     * ArkUI_NodeComponentEvent.data[1].i32: Current sliding state. \n
     */
    NODE_LIST_ON_DID_SCROLL,

    /**
     * @brief Defines the event triggered when the refresh state of the <b>ARKUI_NODE_REFRESH</b> object changes.
     *
     * When the event callback occurs, the union type in the {@link ArkUI_NodeEvent} object is
     * {@link ArkUI_NodeComponentEvent}. \n
     * {@link ArkUI_NodeComponentEvent} contains one parameter:\n
     * <b>ArkUI_NodeComponentEvent.data[0].i32</b>: refresh state. \n
     */
    NODE_REFRESH_STATE_CHANGE = MAX_NODE_SCOPE_NUM * ARKUI_NODE_REFRESH,
    /**
     * @brief Defines the event triggered when the <b>ARKUI_NODE_REFRESH</b> object enters the refresh state.
     *
     * When the event callback occurs, the union type in the {@link ArkUI_NodeEvent} object is
     * {@link ArkUI_NodeComponentEvent}. \n
     * {@link ArkUI_NodeComponentEvent} does not contain parameters:\n
     */
    NODE_REFRESH_ON_REFRESH,

    /**
     * @brief Defines the event that is triggered when the <b>ARKUI_NODE_REFRESH</b> drop-down distance changes.
     *
     * When the event callback occurs, the union type in the {@link ArkUI_NodeEvent} object is
     * {@link ArkUI_NodeComponentEvent}. \n
     * {@link ArkUI_NodeComponentEvent} contains one parameter:\n
     * <b>ArkUI_NodeComponentEvent.data[0].f32</b>: Pull-down distance. \n
     */
    NODE_REFRESH_ON_OFFSET_CHANGE,

    /**
     * @brief Defines the event triggered when the <b>ARKUI_NODE_SCROLL</b> component is about to scroll.
     *
     * Notes for triggering the event:\n
     * 1. This event is triggered when scrolling is started by the <b>ARKUI_NODE_SCROLL</b> component or other
     * input settings, such as keyboard and mouse operations. \n
     * 2. Scrolling can be initiated by calling the controller API. \n
     * 3. The out-of-bounds bounce effect is supported. \n
     * When the event callback occurs, the union type in the {@link ArkUI_NodeEvent} object is
     * {@link ArkUI_NodeComponentEvent}. \n
     * {@link ArkUI_NodeComponentEvent} contains two parameters: \n
     * <b>ArkUI_NodeComponentEvent.data[0].f32</b>: scroll offset of each frame. The offset is positive when the
     * component is scrolled up and negative when the component is scrolled down. \n
     * <b>ArkUI_NodeComponentEvent.data[1].i32</b>: current scroll state. \n
     */
    NODE_ON_WILL_SCROLL = MAX_NODE_SCOPE_NUM * ARKUI_NODE_WATER_FLOW,
    /**
     * @brief Define the enumerated values of the event triggered when the ARKUI_NODE_WATER_FLOW component slides.
     * Condition for triggering the event: \n
     * This event is triggered when the scrolling component triggers scrolling.
     * Other inputs that trigger scrolling, such as keyboard and mouse operations, can be set. \n
     * Called through the scroll controller API. \n
     * Out-of-bounds rebound. \n
     * When the event callback occurs, the union type in the {@Link ArkUI_NodeEvent} object is \n
     * {@Link ArkUI_NodeComponentEvent}. \n
     * {@Link ArkUI_NodeComponentEvent} contains two parameters:\n
     * ArkUI_NodeComponentEvent.data[0].f32: offset of each frame scrolling. \n
     * The offset is positive when the content is scrolled up and is negative when the content is scrolled down. \n
     * ArkUI_NodeComponentEvent.data[1].i32: Current sliding state. \n
     */
    NODE_WATER_FLOW_ON_DID_SCROLL,
    /**
     * @brief Defines the enumerated values of the event triggered,
     * when the subcomponent of the start position or end position displayed in the current waterfall changes.
     * Condition for triggering the event: \n
     * This event is triggered when the index value of the \n
     * first or last subcomponent in the waterfall display area changes. \n
     * When the event callback occurs, the union type in the {@Link ArkUI_NodeEvent} object is \n
     * {@Link ArkUI_NodeComponentEvent}. \n
     * {@Link ArkUI_NodeComponentEvent} contains three parameters: \n
     * ArkUI_NodeComponentEvent.data[0].i32: The index value of the \n
     * start position of the currently displayed WaterFlow. \n
     * ArkUI_NodeComponentEvent.data[1].i32: The index value of \n
     * the end position of the currently displayed waterfall. \n
     */
    NODE_WATER_FLOW_ON_SCROLL_INDEX,
} ArkUI_NodeEventType;

/**
 * @brief Defines the common structure type of a component event.
 *
 * @since 12
 */
typedef struct ArkUI_NodeEvent ArkUI_NodeEvent;

/**
 * @brief Obtains the type of a component event.
 *
 * @param event Indicates the pointer to the component event.
 * @return Returns the type of the component event.
 * @since 12
 */
ArkUI_NodeEventType OH_ArkUI_NodeEvent_GetEventType(ArkUI_NodeEvent* event);

/**
 * @brief Obtains the custom ID of a component event.
 *
 * The event ID is passed in as a parameter when the {@link registerNodeEvent} function is called and can be applied
 * to the dispatch logic of the same event entry function {@link registerNodeEventReceiver}.
 *
 * @param event Indicates the pointer to the component event.
 * @return Returns the custom ID of the component event.
 * @since 12
 */
int32_t OH_ArkUI_NodeEvent_GetTargetId(ArkUI_NodeEvent* event);

/**
 * @brief Obtains the component object that triggers a component event.
 *
 * @param event Indicates the pointer to the component event.
 * @return Returns the component object that triggers the component event.
 * @since 12
 */
ArkUI_NodeHandle OH_ArkUI_NodeEvent_GetNodeHandle(ArkUI_NodeEvent* event);

/**
 * @brief Obtains input event (for example, touch event) data for a component event.
 *
 * @param event Indicates the pointer to the component event.
 * @return Returns the pointer to the input event data.
 * @since 12
 */
ArkUI_UIInputEvent* OH_ArkUI_NodeEvent_GetInputEvent(ArkUI_NodeEvent* event);

/**
 * @brief Obtains the numerical data in a component event.
 *
 * @param event Indicates the pointer to the component event.
 * @return Returns the pointer to the numerical data.
 * @since 12
 */
ArkUI_NodeComponentEvent* OH_ArkUI_NodeEvent_GetNodeComponentEvent(ArkUI_NodeEvent* event);

/**
 * @brief Obtains the string data in a component event.
 * 
 * @param event Indicates the pointer to the component event.
 * @return Returns the pointer to the string data.
 * @since 12
 */
ArkUI_StringAsyncEvent* OH_ArkUI_NodeEvent_GetStringAsyncEvent(ArkUI_NodeEvent* event);

/**
 * @brief Obtains the custom data in a component event.
 *
 * This parameter is passed in {@link registerNodeEvent} and can be applied to the service logic when the event
 * is triggered.
 *
 * @param event Indicates the pointer to the component event.
 * @return Returns the pointer to the custom data.
 * @since 12
 */
void* OH_ArkUI_NodeEvent_GetUserData(ArkUI_NodeEvent* event);

/**
 * @brief Defines the dirty area flag passed in the <b>::markDirty</b> API.
 *
 * @since 12
 */
typedef enum {
    /**
     * @brief Remeasure.
     *
     * When this type of flag is specified, re-layout is triggered by default.
     */
    NODE_NEED_MEASURE = 1,

    /** Re-layout. */
    NODE_NEED_LAYOUT,
    /** Re-rendering. */
    NODE_NEED_RENDER,
} ArkUI_NodeDirtyFlag;

/**
 * @brief Defines the custom component event type.
 *
 * @since 12
 */
typedef enum {
    /** Measure type. */
    ARKUI_NODE_CUSTOM_EVENT_ON_MEASURE = 1 << 0,
    /** Layout type. */
    ARKUI_NODE_CUSTOM_EVENT_ON_LAYOUT = 1 << 1,
    /** Draw type. */
    ARKUI_NODE_CUSTOM_EVENT_ON_DRAW = 1 << 2,
    /** Foreground type. */
    ARKUI_NODE_CUSTOM_EVENT_ON_FOREGROUND_DRAW = 1 << 3,
    /** Overlay type. */
    ARKUI_NODE_CUSTOM_EVENT_ON_OVERLAY_DRAW = 1 << 4,
} ArkUI_NodeCustomEventType;

/**
 * @brief Defines the general structure of a custom component event.
 *
 * @since 12
 */
typedef struct ArkUI_NodeCustomEvent ArkUI_NodeCustomEvent;

/**
 * @brief Defines the component adapter, which is used for lazy loading of elements of scrollable components.
 *
 * @since 12
 */
typedef struct ArkUI_NodeAdapter* ArkUI_NodeAdapterHandle;

/**
 * @brief Defines the component adapter event.
 *
 * @since 12
 */
typedef struct ArkUI_NodeAdapterEvent ArkUI_NodeAdapterEvent;

/**
 * @brief Enumerates component adapter events.
 *
 * @since 12
 */
typedef enum {
    /** This event occurs when the component is attached to the adapter. */
    NODE_ADAPTER_EVENT_WILL_ATTACH_TO_NODE = 1,
    /** This event occurs when the component is detached from the adapter. */
    NODE_ADAPTER_EVENT_WILL_DETACH_FROM_NODE = 2,
    /** This event occurs when the adapter obtains the unique ID of the new element to add. */
    NODE_ADAPTER_EVENT_ON_GET_NODE_ID = 3,
    /** This event occurs when the adapter obtains the content of the new element to add. */
    NODE_ADAPTER_EVENT_ON_ADD_NODE_TO_ADAPTER = 4,
    /** This event occurs when the adapter removes an element. */
    NODE_ADAPTER_EVENT_ON_REMOVE_NODE_FROM_ADAPTER = 5,
} ArkUI_NodeAdapterEventType;

/**
* @brief Creates a component adapter.
*
* @since 12
*/
ArkUI_NodeAdapterHandle OH_ArkUI_NodeAdapter_Create();

/**
* @brief Destroys a component adapter.
*
* @param handle Indicates the target component adapter.
* @since 12
*/
void OH_ArkUI_NodeAdapter_Dispose(ArkUI_NodeAdapterHandle handle);

/**
* @brief Sets the total number of elements in the specified adapter.
*
* @param handle Indicates the target component adapter.
* @param size Indicates the number of elements.
* @return Returns the error code.
*         Returns {@link ARKUI_ERROR_CODE_NO_ERROR} if the operation is successful.
*         Returns {@link ARKUI_ERROR_CODE_PARAM_INVALID} if a parameter error occurs.
* @since 12
*/
int32_t OH_ArkUI_NodeAdapter_SetTotalNodeCount(ArkUI_NodeAdapterHandle handle, uint32_t size);

/**
* @brief Obtains the total number of elements in the specified adapter.
*
* @param handle Indicates the target component adapter.
* @return Returns the total number of elements in the adapter.
* @since 12
*/
uint32_t OH_ArkUI_NodeAdapter_GetTotalNodeCount(ArkUI_NodeAdapterHandle handle);

/**
* @brief Registers an event callback for the adapter.
*
* @param handle Indicates the target component adapter.
* @param userData Indicates custom data.
* @param receiver Indicates the event receiver callback.
* @return Returns the error code.
*         Returns {@link ARKUI_ERROR_CODE_NO_ERROR} if the operation is successful.
*         Returns {@link ARKUI_ERROR_CODE_PARAM_INVALID} if a parameter error occurs.
* @since 12
*/
int32_t OH_ArkUI_NodeAdapter_RegisterEventReceiver(
ArkUI_NodeAdapterHandle handle, void* userData, void (*receiver)(ArkUI_NodeAdapterEvent* event));

/**
* @brief Deregisters an event callback for the adapter.
*
* @param handle Indicates the target component adapter.
* @since 12
*/
void OH_ArkUI_NodeAdapter_UnregisterEventReceiver(ArkUI_NodeAdapterHandle handle);

/**
* @brief Instructs the specified adapter to reload all elements.
*
* @param handle Indicates the target component adapter.
* @return Returns the error code.
*         Returns {@link ARKUI_ERROR_CODE_NO_ERROR} if the operation is successful.
*         Returns {@link ARKUI_ERROR_CODE_PARAM_INVALID} if a parameter error occurs.
* @since 12
*/
int32_t OH_ArkUI_NodeAdapter_ReloadAllItems(ArkUI_NodeAdapterHandle handle);

/**
* @brief Instructs the specified adapter to reload certain elements.
*
* @param handle Indicates the target component adapter.
* @param startPosition Indicates the start position of the elements to reload.
* @param itemCount Indicates the number of the elements to reload.
*  @return Returns the error code.
*         Returns {@link ARKUI_ERROR_CODE_NO_ERROR} if the operation is successful.
*         Returns {@link ARKUI_ERROR_CODE_PARAM_INVALID} if a parameter error occurs.
* @since 12
*/
int32_t OH_ArkUI_NodeAdapter_ReloadItem(
ArkUI_NodeAdapterHandle handle, uint32_t startPosition, uint32_t itemCount);

/**
* @brief Instructs the specified adapter to remove certain elements.
*
* @param handle Indicates the target component adapter.
* @param startPosition Indicates the start position of the elements to remove.
* @param itemCount Indicates the number of the elements to remove.
* @return Returns the error code.
*         Returns {@link ARKUI_ERROR_CODE_NO_ERROR} if the operation is successful.
*         Returns {@link ARKUI_ERROR_CODE_PARAM_INVALID} if a parameter error occurs.
* @since 12
*/
int32_t OH_ArkUI_NodeAdapter_RemoveItem(
ArkUI_NodeAdapterHandle handle, uint32_t startPosition, uint32_t itemCount);

/**
* @brief Instructs the specified adapter to insert certain elements.
*
* @param handle Indicates the target component adapter.
* @param startPosition Indicates the start position of the elements to insert.
* @param itemCount Indicates the number of the elements to insert.
* @return Returns the error code.
*         Returns {@link ARKUI_ERROR_CODE_NO_ERROR} if the operation is successful.
*         Returns {@link ARKUI_ERROR_CODE_PARAM_INVALID} if a parameter error occurs.
* @since 12
*/
int32_t OH_ArkUI_NodeAdapter_InsertItem(
ArkUI_NodeAdapterHandle handle, uint32_t startPosition, uint32_t itemCount);

/**
* @brief Instructs the specified adapter to move certain elements.
*
* @param handle Indicates the target component adapter.
* @param from Indicates the start position of the elements to move.
* @param to  Indicates the end position of the elements to move.
* @return Returns the error code.
*         Returns {@link ARKUI_ERROR_CODE_NO_ERROR} if the operation is successful.
*         Returns {@link ARKUI_ERROR_CODE_PARAM_INVALID} if a parameter error occurs.
* @since 12
*/
int32_t OH_ArkUI_NodeAdapter_MoveItem(ArkUI_NodeAdapterHandle handle, uint32_t from, uint32_t to);

/**
* @brief Obtains all elements stored in the specified adapter.
*
* This API returns the pointer to the array of the elements. You need to manually release the memory data
* to which the pointer points.
*
* @param handle Indicates the target component adapter.
* @param items Indicates the pointer to the array of the elements in the adapter.
* @param size Indicates the number of elements.
* @return Returns the error code.
*         Returns {@link ARKUI_ERROR_CODE_NO_ERROR} if the operation is successful.
*         Returns {@link ARKUI_ERROR_CODE_PARAM_INVALID} if a parameter error occurs.
* @since 12
*/
int32_t OH_ArkUI_NodeAdapter_GetAllItems(ArkUI_NodeAdapterHandle handle, ArkUI_NodeHandle** items, uint32_t* size);

/**
* @brief Obtains the custom data passed in during registration of the specified event.
*
* @param event Indicates the target adapter event.
* @since 12
*/
void* OH_ArkUI_NodeAdapterEvent_GetUserData(ArkUI_NodeAdapterEvent* event);

/**
* @brief Obtains the event type.
*
* @param event Indicates the target adapter event.
* @return Returns the event type.
* @since 12
*/
ArkUI_NodeAdapterEventType OH_ArkUI_NodeAdapterEvent_GetType(ArkUI_NodeAdapterEvent* event);

/**
* @brief Obtains the element to be removed for the event to be destroyed.
*
* @param event Indicates the target adapter event.
* @return Returns the element to be removed.
* @since 12
*/
ArkUI_NodeHandle OH_ArkUI_NodeAdapterEvent_GetRemovedNode(ArkUI_NodeAdapterEvent* event);

/**
* @brief Obtains the index of the element to be operated for the specified adapter event.
*
* @param event Indicates the target adapter event.
* @return Returns the index of the element.
* @since 12
*/
uint32_t OH_ArkUI_NodeAdapterEvent_GetItemIndex(ArkUI_NodeAdapterEvent* event);

/**
* @brief Obtains the scrollable container node that uses the specified adapter.
*
* @param event Indicates the target adapter event.
* @return Returns the error code.
*         Returns {@link ARKUI_ERROR_CODE_NO_ERROR} if the operation is successful.
*         Returns {@link ARKUI_ERROR_CODE_PARAM_INVALID} if a parameter error occurs.
* @since 12
*/
ArkUI_NodeHandle OH_ArkUI_NodeAdapterEvent_GetHostNode(ArkUI_NodeAdapterEvent* event);

/**
* @brief Sets the component to be added to the specified adapter.
*
* @param event Indicates the target adapter event.
* @param node Indicates the component to be added.
* @return Returns the error code.
*         Returns {@link ARKUI_ERROR_CODE_NO_ERROR} if the operation is successful.
*         Returns {@link ARKUI_ERROR_CODE_PARAM_INVALID} if a parameter error occurs.
* @since 12
*/
int32_t OH_ArkUI_NodeAdapterEvent_SetItem(ArkUI_NodeAdapterEvent* event, ArkUI_NodeHandle node);

/**
* @brief Sets the component ID to be generated.
*
* @param event Indicates the target adapter event.
* @param id Indicates the component ID to set.
* @return Returns the error code.
*         Returns {@link ARKUI_ERROR_CODE_NO_ERROR} if the operation is successful.
*         Returns {@link ARKUI_ERROR_CODE_PARAM_INVALID} if a parameter error occurs.
* @since 12
*/
int32_t OH_ArkUI_NodeAdapterEvent_SetNodeId(ArkUI_NodeAdapterEvent* event, int32_t id);

/**
 * @brief Declares a collection of native node APIs provided by ArkUI.
 *
 * The APIs related to the native node must be called in the main thread.
 *
 * @version 1
 * @since 12
 */
typedef struct {
    /** Struct version. */
    int32_t version;

    /**
     * @brief Creates a component based on {@link ArkUI_NodeType} and returns the pointer to the created component.
     *
     * @param type Indicates the type of component to create.
     * @return Returns the pointer to the created component. If the component fails to be created, NULL is returned.
     */
    ArkUI_NodeHandle (*createNode)(ArkUI_NodeType type);

    /**
     * @brief Destroys the component to which the specified pointer points.
     *
     * @param node Indicates the pointer.
     */
    void (*disposeNode)(ArkUI_NodeHandle node);

    /**
     * @brief Adds a component to a parent node.
     *
     * @param parent Indicates the pointer to the parent node.
     * @param child Indicates the pointer to the child node.
     * @return Returns the error code.
     *         Returns {@link ARKUI_ERROR_CODE_NO_ERROR} if the operation is successful.
     *         Returns {@link ARKUI_ERROR_CODE_PARAM_INVALID} if a parameter error occurs.
     *         Returns {@link ARKUI_ERROR_CODE_NOT_SUPPROTED_FOR_ARKTS_NODE} if the following operations are not allowed
     * on BuilderNode generated nodes:
     *         setting or resetting attributes, setting events, or adding or editing subnodes.
     */
    int32_t (*addChild)(ArkUI_NodeHandle parent, ArkUI_NodeHandle child);

    /**
     * @brief Removes a component from its parent node.
     *
     * @param parent Indicates the pointer to the parent node.
     * @param child Indicates the pointer to the child node.
     * @return Returns the error code.
     *         Returns {@link ARKUI_ERROR_CODE_NO_ERROR} if the operation is successful.
     *         Returns {@link ARKUI_ERROR_CODE_PARAM_INVALID} if a parameter error occurs.
     *         Returns {@link ARKUI_ERROR_CODE_NOT_SUPPROTED_FOR_ARKTS_NODE} if the following operations are not allowed
     * on BuilderNode generated nodes:
     *         setting or resetting attributes, setting events, or adding or editing subnodes.
     */
    int32_t (*removeChild)(ArkUI_NodeHandle parent, ArkUI_NodeHandle child);

    /**
     * @brief Inserts a component to a parent node after the specified <b>sibling</b> node.
     *
     * @param parent Indicates the pointer to the parent node.
     * @param child Indicates the pointer to the child node.
     * @param sibling Indicates the pointer to the sibling node after which the target node is to be inserted.
     * If the value is null, the node is inserted at the start of the parent node.
     * @return Returns the error code.
     *         Returns {@link ARKUI_ERROR_CODE_NO_ERROR} if the operation is successful.
     *         Returns {@link ARKUI_ERROR_CODE_PARAM_INVALID} if a parameter error occurs.
     *         Returns {@link ARKUI_ERROR_CODE_NOT_SUPPROTED_FOR_ARKTS_NODE} if the following operations are not allowed
     * on BuilderNode generated nodes:
     *         setting or resetting attributes, setting events, or adding or editing subnodes.
     */
    int32_t (*insertChildAfter)(ArkUI_NodeHandle parent, ArkUI_NodeHandle child, ArkUI_NodeHandle sibling);

    /**
     * @brief Inserts a component to a parent node before the specified <b>sibling</b> node.
     *
     * @param parent Indicates the pointer to the parent node.
     * @param child Indicates the pointer to the child node.
     * @param sibling Indicates the pointer to the sibling node before which the target node is to be inserted.
     * If the value is null, the node is inserted at the end of the parent node.
     * @return Returns the error code.
     *         Returns {@link ARKUI_ERROR_CODE_NO_ERROR} if the operation is successful.
     *         Returns {@link ARKUI_ERROR_CODE_PARAM_INVALID} if a parameter error occurs.
     *         Returns {@link ARKUI_ERROR_CODE_NOT_SUPPROTED_FOR_ARKTS_NODE} if the following operations are not allowed
     * on BuilderNode generated nodes:
     *         setting or resetting attributes, setting events, or adding or editing subnodes.
     */
    int32_t (*insertChildBefore)(ArkUI_NodeHandle parent, ArkUI_NodeHandle child, ArkUI_NodeHandle sibling);

    /**
     * @brief Inserts a component to the specified position in a parent node.
     *
     * @param parent Indicates the pointer to the parent node.
     * @param child Indicates the pointer to the child node.
     * @param position Indicates the position to which the target child node is to be inserted. If the value is a
     * negative number or invalid, the node is inserted at the end of the parent node.
     * @return Returns the error code.
     *         Returns {@link ARKUI_ERROR_CODE_NO_ERROR} if the operation is successful.
     *         Returns {@link ARKUI_ERROR_CODE_PARAM_INVALID} if a parameter error occurs.
     *         Returns {@link ARKUI_ERROR_CODE_NOT_SUPPROTED_FOR_ARKTS_NODE} if the following operations are not allowed
     * on BuilderNode generated nodes:
     *         setting or resetting attributes, setting events, or adding or editing subnodes.
     */
    int32_t (*insertChildAt)(ArkUI_NodeHandle parent, ArkUI_NodeHandle child, int32_t position);

    /**
     * @brief Sets the attribute of a node.
     *
     * @param node Indicates the node whose attribute needs to be set.
     * @param attribute Indicates the type of attribute to set.
     * @param value Indicates the attribute value.
     * @return Returns the error code.
     *         Returns {@link ARKUI_ERROR_CODE_NO_ERROR} if the operation is successful.
     *         Returns {@link ARKUI_ERROR_CODE_PARAM_INVALID} if a parameter error occurs.
     *         Returns {@link ARKUI_ERROR_CODE_ATTRIBUTE_OR_EVENT_NOT_SUPPORTED} if the dynamic implementation library
     *         of the native API was not found.
     *         Returns {@link ARKUI_ERROR_CODE_NOT_SUPPROTED_FOR_ARKTS_NODE} if the following operations are not allowed
     *         on BuilderNode generated nodes:
     *         setting or resetting attributes, setting events, or adding or editing subnodes.
     */
    int32_t (*setAttribute)(ArkUI_NodeHandle node, ArkUI_NodeAttributeType attribute, const ArkUI_AttributeItem* item);

    /**
     * @brief Obtains an attribute.
     *
     * The pointer returned by this API is an internal buffer pointer of the ArkUI framework. As such, you do not need
     * to call <b>delete</b> to release the memory. However, the pointer must be used before this API is called next
     * time. Otherwise, the pointer may be overwritten by other values.
     * @param node Indicates the node whose attribute needs to be obtained.
     * @param attribute Indicates the type of attribute to obtain.
     * @return Returns the attribute value. If the operation fails, a null pointer is returned.
     */
    const ArkUI_AttributeItem* (*getAttribute)(ArkUI_NodeHandle node, ArkUI_NodeAttributeType attribute);

    /**
     * @brief Resets an attribute.
     *
     * @param node Indicates the node whose attribute needs to be reset.
     * @param attribute Indicates the type of attribute to reset.
     * @return Returns the error code.
     *         Returns {@link ARKUI_ERROR_CODE_NO_ERROR} if the operation is successful.
     *         Returns {@link ARKUI_ERROR_CODE_PARAM_INVALID} if a parameter error occurs.
     *         Returns {@link ARKUI_ERROR_CODE_ATTRIBUTE_OR_EVENT_NOT_SUPPORTED} if the dynamic implementation library
     *         of the native API was not found.
     *         Returns {@link ARKUI_ERROR_CODE_NOT_SUPPROTED_FOR_ARKTS_NODE} if the following operations are not allowed
     *         on BuilderNode generated nodes:
     *         setting or resetting attributes, setting events, or adding or editing subnodes.
     */
    int32_t (*resetAttribute)(ArkUI_NodeHandle node, ArkUI_NodeAttributeType attribute);

    /**
     * @brief Registers an event for the specified node.
     *
     * When the component is being displayed, this API must be called in the main thread.
     *
     * @param node Indicates the target node.
     * @param eventType Indicates the type of event to register.
     * @param targetId Indicates the custom event ID, which is passed in the callback of {@link ArkUI_NodeEvent}
     * when the event is triggered.
     * @param userData Indicates the custom event parameter, which is passed in the callback of {@link ArkUI_NodeEvent}
     * @return Returns the error code.
     *         Returns {@link ARKUI_ERROR_CODE_NO_ERROR} if the operation is successful.
     *         Returns {@link ARKUI_ERROR_CODE_PARAM_INVALID} if a parameter error occurs.
     *         Returns {@link ARKUI_ERROR_CODE_ATTRIBUTE_OR_EVENT_NOT_SUPPORTED} if the dynamic implementation library
     *         of the native API was not found.
     *         Returns {@link ARKUI_ERROR_CODE_NOT_SUPPROTED_FOR_ARKTS_NODE} if the following operations are not allowed
     *         on BuilderNode generated nodes:
     *         setting or resetting attributes, setting events, or adding or editing subnodes.
     */
    int32_t (*registerNodeEvent)(ArkUI_NodeHandle node, ArkUI_NodeEventType eventType,
        int32_t targetId, void* userData);

    /**
     * @brief Unregisters an event for the specified node.
     *
     * When the component is being displayed, this API must be called in the main thread.
     *
     * @param node Indicates the target node.
     * @param eventType Indicates the type of event to unregister.
     */
    void (*unregisterNodeEvent)(ArkUI_NodeHandle node, ArkUI_NodeEventType eventType);

    /**
     * @brief Registers an event receiver.
     *
     * The ArkUI framework collects component events generated during the process and calls back the events through
     * the registered event receiver. \n
     * A new call to this API will overwrite the previously registered event receiver. \n
     * Do not directly save the <b>ArkUI_NodeEvent</b> object pointer. The data will be destroyed after the
     * callback is complete. \n
     * To bind with a component instance, you can use the <b>addNodeEventReceiver</b> function. \n
     *
     * @param eventReceiver Indicates the event receiver to register.
     */
    void (*registerNodeEventReceiver)(void (*eventReceiver)(ArkUI_NodeEvent* event));

    /**
     * @brief Unregisters the event receiver.
     *
     */
    void (*unregisterNodeEventReceiver)();

    /**
     * @brief Forcibly marks the current node that needs to be measured, laid out, or rendered again.
     *
     * Regarding updates to system attributes, the ArkUI framework automatically marks the dirty area and performs
     * measuring, layout, or rendering again. In this case, you do not need to call this API.
     * @param node Indicates the node for which you want to mark as dirty area.
     * @param dirtyFlag Indicates type of dirty area.
     */
    void (*markDirty)(ArkUI_NodeHandle node, ArkUI_NodeDirtyFlag dirtyFlag);

    /**
     * @brief Obtains the number of subnodes.
     *
     * @param node Indicates the target node.
     * @return the number of subnodes. If not, returns 0.
     */
    uint32_t (*getTotalChildCount)(ArkUI_NodeHandle node);

    /**
     * @brief Obtains a subnode.
     *
     * @param node Indicates the target node.
     * @param position Indicates the position of the subnode.
     * @return Returns the pointer to the subnode if the subnode exists; returns <b>NULL</b> otherwise.
     */
    ArkUI_NodeHandle (*getChildAt)(ArkUI_NodeHandle node, int32_t position);

    /**
     * @brief Obtains the first subnode.
     *
     * @param node Indicates the target node.
     * @return Returns the pointer to the subnode if the subnode exists; returns <b>NULL</b> otherwise.
     */
    ArkUI_NodeHandle (*getFirstChild)(ArkUI_NodeHandle node);

    /**
     * @brief Obtains the last subnode.
     *
     * @param node Indicates the target node.
     * @return Returns the pointer to the subnode if the subnode exists; returns <b>NULL</b> otherwise.
     */
    ArkUI_NodeHandle (*getLastChild)(ArkUI_NodeHandle node);

    /**
     * @brief Obtains the previous sibling node.
     *
     * @param node Indicates the target node.
     * @return Returns the pointer to the subnode if the subnode exists; returns <b>NULL</b> otherwise.
     */
    ArkUI_NodeHandle (*getPreviousSibling)(ArkUI_NodeHandle node);

    /**
     * @brief Obtains the next sibling node.
     *
     * @param node Indicates the target node.
     * @return Returns the pointer to the subnode if the subnode exists; returns <b>NULL</b> otherwise.
     */
    ArkUI_NodeHandle (*getNextSibling)(ArkUI_NodeHandle node);

    /**
     * @brief Registers a custom event for a node. When the event is triggered, the value is returned through the entry
     * point function registered by <b>registerNodeCustomEventReceiver</b>.
     *
     * @param node Indicates the target node.
     * @param eventType Indicates the type of event to register.
     * @param targetId Indicates the custom event ID, which is passed in the callback of {@link ArkUI_NodeCustomEvent}
     * when the event is triggered.
     * @param userData Indicates the custom event parameter, which is passed in the callback of
     * {@link ArkUI_NodeCustomEvent} when the event is triggered.
     * @return Returns the error code.
     *         Returns {@link ARKUI_ERROR_CODE_NO_ERROR} if the operation is successful.
     *         Returns {@link ARKUI_ERROR_CODE_PARAM_INVALID} if a parameter error occurs.
     *         Returns {@link ARKUI_ERROR_CODE_ATTRIBUTE_OR_EVENT_NOT_SUPPORTED} if the dynamic implementation library
     *         of the native API was not found.
     */
    int32_t (*registerNodeCustomEvent)(
        ArkUI_NodeHandle node, ArkUI_NodeCustomEventType eventType, int32_t targetId, void* userData);

    /**
     * @brief Unregisters a custom event for a node.
     *
     * @param node Indicates the target node.
     * @param eventType Indicates the type of event to unregister.
     */
    void (*unregisterNodeCustomEvent)(ArkUI_NodeHandle node, ArkUI_NodeCustomEventType eventType);

    /**
     * @brief Registers a unified entry point function for custom node event callbacks.
     *
     * The ArkUI framework collects custom component events generated during the process and calls back the events
     * through the registered <b>registerNodeCustomEventReceiver</b>. \n
     * A new call to this API will overwrite the previously registered event receiver.
     * Do not directly save the <b>ArkUI_NodeCustomEvent</b> object pointer.
     * The data will be destroyed after the callback is complete. \n
     * To bind with a component instance, you can use the <b>addNodeCustomEventReceiver</b> function. \n
     *
     * @param eventReceiver Indicates the event receiver to register.
     */
    void (*registerNodeCustomEventReceiver)(void (*eventReceiver)(ArkUI_NodeCustomEvent* event));

    /**
     * @brief Unregisters the unified entry point function for custom node event callbacks.
     *
     */
    void (*unregisterNodeCustomEventReceiver)();

    /**
     * @brief Sets the width and height for a component after the measurement.
     *
     * @param node Indicates the target node.
     * @param width Indicates the width.
     * @param height Indicates the height.
     * @return Returns the error code.
     *         Returns {@link ARKUI_ERROR_CODE_NO_ERROR} if the operation is successful.
     *         Returns {@link ARKUI_ERROR_CODE_PARAM_INVALID} if a parameter error occurs..
     */
    int32_t (*setMeasuredSize)(ArkUI_NodeHandle node, int32_t width, int32_t height);

    /**
     * @brief Sets the position for a component.
     *
     * @param node Indicates the target node.
     * @param positionX Indicates the X coordinate.
     * @param positionY Indicates the Y coordinate.
     * @return Returns the error code.
     *         Returns {@link ARKUI_ERROR_CODE_NO_ERROR} if the operation is successful.
     *         Returns {@link ARKUI_ERROR_CODE_PARAM_INVALID} if a parameter error occurs..
     */
    int32_t (*setLayoutPosition)(ArkUI_NodeHandle node, int32_t positionX, int32_t positionY);

    /**
     * @brief Obtains the width and height of a component after measurement.
     *
     * @param node Indicates the target node.
     * @return Returns the width and height of the component.
     */
    ArkUI_IntSize (*getMeasuredSize)(ArkUI_NodeHandle node);

    /**
     * @brief Obtains the position of a component after the layout is complete.
     *
     * @param node Indicates the target node.
     * @return Returns the position of the component.
     */
    ArkUI_IntOffset (*getLayoutPosition)(ArkUI_NodeHandle node);

    /**
     * @brief Measures a node. You can use the <b>getMeasuredSize</b> API to obtain the size after the measurement.
     *
     * @param node Indicates the target node.
     * @param Constraint Indicates the size constraint.
     * @return Returns the error code.
     *         Returns {@link ARKUI_ERROR_CODE_NO_ERROR} if the operation is successful.
     *         Returns {@link ARKUI_ERROR_CODE_PARAM_INVALID} if a parameter error occurs..
     */
    int32_t (*measureNode)(ArkUI_NodeHandle node, ArkUI_LayoutConstraint* Constraint);

    /**
     * @brief Lays outs a component and passes the expected position of the component relative to its parent component.
     *
     * When the component is being displayed, this API must be called in the main thread.
     *
     * @param node Indicates the target node.
     * @param positionX Indicates the X coordinate.
     * @param positionY Indicates the Y coordinate.
     * @return Returns the error code.
     *         Returns {@link ARKUI_ERROR_CODE_NO_ERROR} if the operation is successful.
     *         Returns {@link ARKUI_ERROR_CODE_PARAM_INVALID} if a parameter error occurs..
     */
    int32_t (*layoutNode)(ArkUI_NodeHandle node, int32_t positionX, int32_t positionY);

    /**
     * @brief Adds a component event callback function to a component to receive component events generated
     * by the component.
     *
     * Unlike the global registration function <b>registerNodeEventReceiver</b>, this API allows multiple event
     * receivers to be added to the same component. \n
     * The callback added by this API is triggered before the global callback registered by
     * <b>registerNodeEventReceiver</b>. \n
     * Do not directly save the <b>ArkUI_NodeEvent</b> object pointer.
     * The data will be destroyed after the callback is complete. \n
     *
     * @param node Indicates the component for which you want to add the event callback function.
     * @param eventReceiver Indicates the component event callback function to add.
     * @return Returns the error code.
     *         Returns {@link ARKUI_ERROR_CODE_NO_ERROR} if the operation is successful.
     *         Returns {@link ARKUI_ERROR_CODE_PARAM_INVALID} if a parameter error occurs..
     */
    int32_t (*addNodeEventReceiver)(ArkUI_NodeHandle node, void (*eventReceiver)(ArkUI_NodeEvent* event));

    /**
     * @brief Removes the registered component event callback function from a component.
     *
     * @param node Indicates the component from which you want to remove the event callback function.
     * @param eventReceiver Indicates the component event callback function to remove.
     * @return Returns the error code.
     *         Returns {@link ARKUI_ERROR_CODE_NO_ERROR} if the operation is successful.
     *         Returns {@link ARKUI_ERROR_CODE_PARAM_INVALID} if a parameter error occurs..
     */
    int32_t (*removeNodeEventReceiver)(ArkUI_NodeHandle node, void (*eventReceiver)(ArkUI_NodeEvent* event));

    /**
     * @brief Adds a custom event callback function to a component to receive custom events
     * (such as layout and drawing events) generated by the component.
     *
     * Unlike the global registration function <b>registerNodeCustomEventReceiver</b>, this API allows
     * multiple event receivers to be added to the same component. \n
     * The callback added by this API is triggered before the global callback registered by
     * <b>registerNodeCustomEventReceiver</b>. \n
     * Do not directly save the <b>ArkUI_NodeCustomEvent</b> object pointer.
     * The data will be destroyed after the callback is complete. \n
     *
     * @param node Indicates the component for which you want to add the custom event callback function.
     * @param eventReceiver Indicates the custom event callback function to add.
     * @return Returns the error code.
     *         Returns {@link ARKUI_ERROR_CODE_NO_ERROR} if the operation is successful.
     *         Returns {@link ARKUI_ERROR_CODE_PARAM_INVALID} if a parameter error occurs.
     */
    int32_t (*addNodeCustomEventReceiver)(ArkUI_NodeHandle node, void (*eventReceiver)(ArkUI_NodeCustomEvent* event));

    /**
     * @brief Removes a registered custom event callback function from a component.
     *
     * @param node Indicates the component from which you want to remove the custom event callback function.
     * @param eventReceiver Indicates the custom event callback function to remove.
     * @return Returns the error code.
     *         Returns {@link ARKUI_ERROR_CODE_NO_ERROR} if the operation is successful.
     *         Returns {@link ARKUI_ERROR_CODE_PARAM_INVALID} if a parameter error occurs.
     */
    int32_t (*removeNodeCustomEventReceiver)(ArkUI_NodeHandle node,
        void (*eventReceiver)(ArkUI_NodeCustomEvent* event));

    /**
     * @brief Saves custom data on the specified component.
     *
     * @param node Indicates the component on which the custom data will be saved.
     * @param userData Indicates the custom data to be saved.
     * @return Returns the error code.
     *         Returns {@link ARKUI_ERROR_CODE_NO_ERROR} if the operation is successful.
     *         Returns {@link ARKUI_ERROR_CODE_PARAM_INVALID} if a parameter error occurs..
     */
    int32_t (*setUserData)(ArkUI_NodeHandle node, void* userData);

    /**
     * @brief Obtains the custom data saved on the specified component.
     *
     * @param node Indicates the target component.
     * @return Returns the custom data.
     */
    void* (*getUserData)(ArkUI_NodeHandle node);

    /**
     * @brief Sets the unit for a component.
     *
     * @param node Indicates the component for which you want to set the unit.
     * @param unit Indicates the unit, which is an enumerated value of {@link ArkUI_LengthMetricUnit}.
     * The default value is <b>ARKUI_LENGTH_METRIC_UNIT_DEFAULT</b>.
     * @return Returns the error code.
    *         Returns {@link ARKUI_ERROR_CODE_NO_ERROR} if the operation is successful.
    *         Returns {@link ARKUI_ERROR_CODE_PARAM_INVALID} if a parameter error occurs.
     */
    int32_t (*setLengthMetricUnit)(ArkUI_NodeHandle node, ArkUI_LengthMetricUnit unit);

    /**
      * @brief Get the parent node.
      *
      * @param node target node object.
      * @return Returns the pointer of the component, if not return NULL
      */
    ArkUI_NodeHandle (*getParent)(ArkUI_NodeHandle node);
} ArkUI_NativeNodeAPI_1;

/**
* @brief Obtains the size constraint for measurement through a custom component event.
*
* @param event Indicates the pointer to the custom component event.
* @return Returns the pointer to the size constraint.
* @since 12
*/
ArkUI_LayoutConstraint* OH_ArkUI_NodeCustomEvent_GetLayoutConstraintInMeasure(ArkUI_NodeCustomEvent* event);

/**
* @brief Obtains the expected position of a component relative to its parent component in the layout phase through a
* custom component event.
*
* @param event Indicates the pointer to the custom component event.
* @return Returns the expected position relative to the parent component.
* @since 12
*/
ArkUI_IntOffset OH_ArkUI_NodeCustomEvent_GetPositionInLayout(ArkUI_NodeCustomEvent* event);

/**
* @brief Obtains the drawing context through a custom component event.
*
* @param event Indicates the pointer to the custom component event.
* @return Returns the drawing context.
* @since 12
*/
ArkUI_DrawContext* OH_ArkUI_NodeCustomEvent_GetDrawContextInDraw(ArkUI_NodeCustomEvent* event);

/**
* @brief Obtains the ID of a custom component event.
*
* @param event Indicates the pointer to the custom component event.
* @return Returns the ID of the custom component event.
* @since 12
*/
int32_t OH_ArkUI_NodeCustomEvent_GetEventTargetId(ArkUI_NodeCustomEvent* event);

/**
* @brief Obtains custom event parameters through a custom component event.
*
* @param event Indicates the pointer to the custom component event.
* @return Returns the custom event parameters.
* @since 12
*/
void* OH_ArkUI_NodeCustomEvent_GetUserData(ArkUI_NodeCustomEvent* event);

/**
* @brief Obtains a component object through a custom component event.
*
* @param event Indicates the pointer to the custom component event.
* @return Returns the component object.
* @since 12
*/
ArkUI_NodeHandle OH_ArkUI_NodeCustomEvent_GetNodeHandle(ArkUI_NodeCustomEvent* event);

/**
* @brief Obtains the event type through a custom component event.
*
* @param event Indicates the pointer to the custom component event.
* @return Returns the type of the custom component event.
* @since 12
*/
ArkUI_NodeCustomEventType OH_ArkUI_NodeCustomEvent_GetEventType(ArkUI_NodeCustomEvent* event);

/**
 * @brief Defines the node content event type.
 * 
 * @since 12
 */
typedef enum {
    /** Defines the attach event. */
    NODE_CONTENT_EVENT_ON_ATTACH_TO_WINDOW = 0,
    /** Defines the detach event. */
    NODE_CONTENT_EVENT_ON_DETACH_FROM_WINDOW = 1,
} ArkUI_NodeContentEventType;

/**
 * @brief Defines the general structure of a node content event.
 * @since 12
 */
typedef struct ArkUI_NodeContentEvent ArkUI_NodeContentEvent;

/**
 * @brief Defines the callback function of a node content event.
 * @since 12
 */
typedef void (*ArkUI_NodeContentCallback)(ArkUI_NodeContentEvent* event);

/**
 * @brief register a callback functoin to a node content.
 *
 * @param content Indicates the pointer to the node content instance.
 * @param callback Indicates the callback function.
 * @return Returns the error code.
 *         Returns {@link ARKUI_ERROR_CODE_NO_ERROR} if the operation is successful.
 *         Returns {@link ARKUI_ERROR_CODE_PARAM_INVALID} if a parameter error occurs.
 * @since 12
 */
int32_t OH_ArkUI_NodeContent_RegisterCallback(ArkUI_NodeContentHandle content, ArkUI_NodeContentCallback callback);

/**
 * @brief Obtains the type of a node content event.
 *
 * @param event Indicates the pointer to the node content event.
 * @return Returns the type of the node content event.
 * @since 12
 */
ArkUI_NodeContentEventType OH_ArkUI_NodeContentEvent_GetEventType(ArkUI_NodeContentEvent* event);

/**
 * @brief Add a node to a node content.
 *
 * @param content Indicates the pointer to the node content instance.
 * @param node Indicates the pointer to the node
 * @return Returns the error code.
 *         Returns {@link ARKUI_ERROR_CODE_NO_ERROR} if the operation is successful.
 *         Returns {@link ARKUI_ERROR_CODE_PARAM_INVALID} if a parameter error occurs.
 * @since 12
 */
int32_t OH_ArkUI_NodeContent_AddNode(ArkUI_NodeContentHandle content, ArkUI_NodeHandle node);

/**
 * @brief remove a node from a node content.
 *
 * @param content Indicates the pointer to the node content instance.
 * @param node Indicates the pointer to the node
  * @return Returns the error code.
 *         Returns {@link ARKUI_ERROR_CODE_NO_ERROR} if the operation is successful.
 *         Returns {@link ARKUI_ERROR_CODE_PARAM_INVALID} if a parameter error occurs.
 * @since 12
 */
int32_t OH_ArkUI_NodeContent_RemoveNode(ArkUI_NodeContentHandle content, ArkUI_NodeHandle node);

/**
 * @brief insert a node into a node content at a given position.
 *
 * @param content Indicates the pointer to the node content instance.
 * @param node Indicates the pointer to the node
 * @param position Indicates the position for inserting the node
 * @return Returns the error code.
 *         Returns {@link ARKUI_ERROR_CODE_NO_ERROR} if the operation is successful.
 *         Returns {@link ARKUI_ERROR_CODE_PARAM_INVALID} if a parameter error occurs.
 * @since 12
 */
int32_t OH_ArkUI_NodeContent_InsertNode(ArkUI_NodeContentHandle content, ArkUI_NodeHandle node, int32_t position);

/**
 * @brief Get the size of the component layout area.
 * The layout area size does not include graphic variation attributes such as scaling.
 *
 * @param node ArkUI_NodeHandle pointer.
 * @param size The drawing area size of the component handle, in px.
 * @return Returns the error code.
 *         Returns {@link ARKUI_ERROR_CODE_NO_ERROR} if the operation is successful.
 *         Returns {@link ARKUI_ERROR_CODE_PARAM_INVALID} if a parameter error occurs.
 * @since 12
 */
int32_t OH_ArkUI_NodeUtils_GetLayoutSize(ArkUI_NodeHandle node, ArkUI_IntSize* size);

/**
 * @brief Obtain the position of the component layout area relative to the parent component.
 * The relative position of the layout area does not include graphic variation attributes, such as translation.
 *
 * @param node ArkUI_NodeHandle pointer.
 * @param localOffset The offset value of the component handle relative to the parent component, in px.
 * @return Returns the error code.
 *         Returns {@link ARKUI_ERROR_CODE_NO_ERROR} if the operation is successful.
 *         Returns {@link ARKUI_ERROR_CODE_PARAM_INVALID} if a parameter error occurs.
 * @since 12
 */
int32_t OH_ArkUI_NodeUtils_GetLayoutPosition(ArkUI_NodeHandle node, ArkUI_IntOffset* localOffset);

/**
 * @brief Obtain the position of the component layout area relative to the window.
 * The relative position of the layout area does not include graphic variation attributes, such as translation.
 *
 * @param node ArkUI_NodeHandle pointer.
 * @param globalOffset The offset value of the component handle relative to the window, in px.
 * @return Returns the error code.
 *         Returns {@link ARKUI_ERROR_CODE_NO_ERROR} if the operation is successful.
 *         Returns {@link ARKUI_ERROR_CODE_PARAM_INVALID} if a parameter error occurs.
 * @since 12
 */
int32_t OH_ArkUI_NodeUtils_GetLayoutPositionInWindow(ArkUI_NodeHandle node, ArkUI_IntOffset* globalOffset);

/**
 * @brief Obtain the position of the component layout area relative to the screen.
 * The relative position of the layout area does not include graphic variation attributes, such as translation.
 *
 * @param node ArkUI_NodeHandle pointer.
 * @param screenOffset The offset value of the component handle relative to the screen, in px.
 * @return Returns the error code.
 *         Returns {@link ARKUI_ERROR_CODE_NO_ERROR} if the operation is successful.
 *         Returns {@link ARKUI_ERROR_CODE_PARAM_INVALID} if a parameter error occurs.
 * @since 12
 */
int32_t OH_ArkUI_NodeUtils_GetLayoutPositionInScreen(ArkUI_NodeHandle node, ArkUI_IntOffset* screenOffset);

/**
 * @brief Obtain the position of the component in the window, including the properties of graphic translation changes.
 *
 * @param node ArkUI_NodeHandle pointer.
 * @param translateOffset The cumulative offset value of the component handle itself,
 * parent components, and ancestor nodes, in px.
 * @return Returns the error code.
 *         Returns {@link ARKUI_ERROR_CODE_NO_ERROR} if the operation is successful.
 *         Returns {@link ARKUI_ERROR_CODE_PARAM_INVALID} if a parameter error occurs.
 * @since 12
 */
int32_t OH_ArkUI_NodeUtils_GetPositionWithTranslateInWindow(ArkUI_NodeHandle node, ArkUI_IntOffset* translateOffset);

/**
 * @brief Obtain the position of the component on the screen, including the attributes of graphic translation changes.
 *
 * @param node ArkUI_NodeHandle pointer.
 * @param translateOffset The cumulative offset value of the component handle itself,
 * parent components, and ancestor nodes, in px.
 * @return Returns the error code.
 *         Returns {@link ARKUI_ERROR_CODE_NO_ERROR} if the operation is successful.
 *         Returns {@link ARKUI_ERROR_CODE_PARAM_INVALID} if a parameter error occurs.
 * @since 12
 */
int32_t OH_ArkUI_NodeUtils_GetPositionWithTranslateInScreen(ArkUI_NodeHandle node, ArkUI_IntOffset* translateOffset);

/**
 * @brief Collapse the ListItem in its expanded state.
 *
 * @param node Node objects that need to be registered for events.
 * @param userData Custom event parameters are carried back in the callback parameter when the event is triggered.
 * @param onFinish The callback triggered after the completion of the folding animation.
 * @return Error code.
 *         {@link ARKUI_ERROR_CODE_NO_ERROR} Success.
 *         {@link ARKUI_ERROR_CODE_PARAM_INVALID} Function parameter exception.
 *         {@link ARKUI_ERROR_CODE_ATTRIBUTE_OR_EVENT_NOT_SUPPORTED} The component does not support this event.
 * @since 12
 */
int32_t OH_ArkUI_List_CloseAllSwipeActions(ArkUI_NodeHandle node, void* userData, void (*onFinish)(void* userData));
#ifdef __cplusplus
};
#endif

#endif // ARKUI_NATIVE_NODE_H
/** @}*/