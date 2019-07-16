/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#ifndef _D2D1_EFFECT_HELPERS_H_
#define _D2D1_EFFECT_HELPERS_H_

#include <winapifamily.h>

#if WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_APP)

#include <d2d1effectauthor.h>

template<typename T>
T GetType(T t) {
    return t;
};

template<class C, typename P, typename I>
HRESULT DeducingValueSetter(HRESULT (C::*callback)(P), I *effect, const BYTE *data, UINT32 dataSize) {
    return dataSize == sizeof(P)
        ? (static_cast<C*>(effect)->*callback)(*reinterpret_cast<const P*>(data))
        : E_INVALIDARG;
}

template<typename T, T P, typename I>
HRESULT CALLBACK ValueSetter(IUnknown *effect, const BYTE *data, UINT32 dataSize) {
    return DeducingValueSetter(P, static_cast<I*>(effect), data, dataSize);
}

template<class C, typename P, typename I>
HRESULT DeducingValueGetter(P (C::*callback)() const, const I *effect, BYTE *data, UINT32 dataSize, UINT32 *actualSize) {
    if (actualSize)
        *actualSize = sizeof(P);

    if(!dataSize || !data)
        return S_OK;

    if (dataSize < sizeof(P))
        return E_NOT_SUFFICIENT_BUFFER;

    *reinterpret_cast<P*>(data) = (static_cast<const C*>(effect)->*callback)();
    return S_OK;
}

template<typename T, T P, typename I>
HRESULT CALLBACK ValueGetter(const IUnknown *effect, BYTE *data, UINT32 dataSize, UINT32 *actualSize) {
    return DeducingValueGetter(P, static_cast<const I*>(effect), data, dataSize, actualSize);
}

#define D2D1_VALUE_TYPE_BINDING(name, setter, getter)                     \
    {                                                                     \
        name,                                                             \
        &ValueSetter<decltype(GetType(setter)), setter, ID2D1EffectImpl>, \
        &ValueGetter<decltype(GetType(getter)), getter, ID2D1EffectImpl>  \
    }

#endif /* WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_APP) */

#endif /* _D2D1_EFFECT_HELPERS_H_ */
