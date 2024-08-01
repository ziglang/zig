/*
 * Copyright (c) 2023-2024 Huawei Device Co., Ltd.
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

#ifndef C_INCLUDE_DRAWING_RECT_H
#define C_INCLUDE_DRAWING_RECT_H

/**
 * @addtogroup Drawing
 * @{
 *
 * @brief Provides functions such as 2D graphics rendering, text drawing, and image display.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 *
 * @since 11
 * @version 1.0
 */

/**
 * @file drawing_rect.h
 *
 * @brief Declares functions related to the <b>rect</b> object in the drawing module.
 *
 * @since 11
 * @version 1.0
 */

#include "drawing_types.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Creates an <b>OH_Drawing_Rect</b> object.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param left Indicates the left position of the rect.
 * @param top Indicates the top position of the rect.
 * @param right Indicates the right position of the rect.
 * @param bottom Indicates the bottom position of the rect.
 * @return Returns the pointer to the <b>OH_Drawing_Rect</b> object created.
 * @since 11
 * @version 1.0
 */
OH_Drawing_Rect* OH_Drawing_RectCreate(float left, float top, float right, float bottom);

/**
 * @brief If rect intersects other, sets rect to intersection.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param rect Indicates the pointer to an <b>OH_Drawing_Rect</b> object.
 * @param other Indicates the pointer to an <b>OH_Drawing_Rect</b> object.
 * @return Returns true if have area in common.
 * @since 12
 * @version 1.0
 */
bool OH_Drawing_RectIntersect(OH_Drawing_Rect* rect, const OH_Drawing_Rect* other);

/**
 * @brief Sets rect to the union of rect and other.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param rect Indicates the pointer to an <b>OH_Drawing_Rect</b> object.
 * @param other Indicates the pointer to an <b>OH_Drawing_Rect</b> object.
 * @return Returns true if rect and other are not nullptr, and other is not empty;
 *         false if rect or other is nullptr, or other is empty.
 * @since 12
 * @version 1.0
 */
bool OH_Drawing_RectJoin(OH_Drawing_Rect* rect, const OH_Drawing_Rect* other);

/**
 * @brief Set the left position of the rect.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param rect Indicates the pointer to an <b>OH_Drawing_Rect</b> object.
 * @param left Indicates the left position of the rect.
 * @since 12
 * @version 1.0
 */
void OH_Drawing_RectSetLeft(OH_Drawing_Rect* rect, float left);

/**
 * @brief Set the top position of the rect.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param rect Indicates the pointer to an <b>OH_Drawing_Rect</b> object.
 * @param top Indicates the top position of the rect.
 * @since 12
 * @version 1.0
 */
void OH_Drawing_RectSetTop(OH_Drawing_Rect* rect, float top);

/**
 * @brief Set the right position of the rect.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param rect Indicates the pointer to an <b>OH_Drawing_Rect</b> object.
 * @param right Indicates the right position of the rect.
 * @since 12
 * @version 1.0
 */
void OH_Drawing_RectSetRight(OH_Drawing_Rect* rect, float right);

/**
 * @brief Set the bottom position of the rect.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param rect Indicates the pointer to an <b>OH_Drawing_Rect</b> object.
 * @param bottom Indicates the bottom position of the rect.
 * @since 12
 * @version 1.0
 */
void OH_Drawing_RectSetBottom(OH_Drawing_Rect* rect, float bottom);

/**
 * @brief Get the left position of the rect.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_Rect Indicates the pointer to an <b>OH_Drawing_Rect</b> object.
 * @return Return the left position of the rect.
 * @since 12
 * @version 1.0
 */
float OH_Drawing_RectGetLeft(OH_Drawing_Rect*);

/**
 * @brief Get the top position of the rect.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_Rect Indicates the pointer to an <b>OH_Drawing_Rect</b> object.
 * @return Return the top position of the rect.
 * @since 12
 * @version 1.0
 */
float OH_Drawing_RectGetTop(OH_Drawing_Rect*);

/**
 * @brief Get the right position of the rect.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_Rect Indicates the pointer to an <b>OH_Drawing_Rect</b> object.
 * @return Return the right position of the rect.
 * @since 12
 * @version 1.0
 */
float OH_Drawing_RectGetRight(OH_Drawing_Rect*);

/**
 * @brief Get the bottom position of the rect.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_Rect Indicates the pointer to an <b>OH_Drawing_Rect</b> object.
 * @return Return the bottom position of the rect.
 * @since 12
 * @version 1.0
 */
float OH_Drawing_RectGetBottom(OH_Drawing_Rect*);

/**
 * @brief Get the height position of the rect.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_Rect Indicates the pointer to an <b>OH_Drawing_Rect</b> object.
 * @since 12
 * @version 1.0
 */
float OH_Drawing_RectGetHeight(OH_Drawing_Rect*);

/* @brief Get the width position of the rect.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_Rect Indicates the pointer to an <b>OH_Drawing_Rect</b> object.
 * @return Returns the width.
 * @since 12
 * @version 1.0
 */
float OH_Drawing_RectGetWidth(OH_Drawing_Rect*);

/**
 * @brief Copy the original rectangular object to the destination rectangular object.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param src Indicates the pointer to an <b>OH_Drawing_Rect</b> object.
 * @param dst Indicates the pointer to an <b>OH_Drawing_Rect</b> object.
 * @since 12
 * @version 1.0
 */
void OH_Drawing_RectCopy(OH_Drawing_Rect* src, OH_Drawing_Rect* dst);

/**
 * @brief Destroys an <b>OH_Drawing_Rect</b> object and reclaims the memory occupied by the object.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_Rect Indicates the pointer to an <b>OH_Drawing_Rect</b> object.
 * @since 11
 * @version 1.0
 */
void OH_Drawing_RectDestroy(OH_Drawing_Rect*);

#ifdef __cplusplus
}
#endif
/** @} */
#endif