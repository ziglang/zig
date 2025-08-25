/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#ifndef _WRL_COREWRAPPERS_H_
#define _WRL_COREWRAPPERS_H_

#include <type_traits>

#include <windows.h>
#include <intsafe.h>
#include <winstring.h>
#include <roapi.h>

/* #include <wrl/def.h> */
#include <wrl/internal.h>

namespace Microsoft {
    namespace WRL {
        namespace Details {
            struct Dummy {};
        }

        namespace Wrappers {
            class HStringReference;

            class HString {
            public:
                HString() throw() : hstr_(nullptr) {}

                HString(HString&& o) throw() : hstr_(o.hstr_) {
                    o.hstr_ = nullptr;
                }

                HString(const HString&) = delete;
                HString& operator=(const HString&) = delete;

                operator HSTRING() const throw() {
                    return hstr_;
                }

                ~HString() throw() {
                    Release();
                }

                HString& operator=(HString&& o) throw() {
                    Release();
                    hstr_ = o.hstr_;
                    o.hstr_ = nullptr;
                    return *this;
                }

                HRESULT Set(const wchar_t *s, unsigned int l) throw() {
                    Release();
                    return ::WindowsCreateString(s, l, &hstr_);
                }

                template <size_t s>
                HRESULT Set(const wchar_t (&str)[s]) throw() {
                    static_assert(static_cast<size_t>(static_cast<UINT32>(s - 1)) == s - 1, "mismatch string length");
                    return Set(str, s - 1);
                }

                template <size_t s>
                HRESULT Set(wchar_t (&strRef)[s]) throw() {
                    const wchar_t *str = static_cast<const wchar_t *>(strRef);
                    unsigned int l;
                    HRESULT hr = SizeTToUInt32(::wcslen(str), &l);
                    if (SUCCEEDED(hr))
                        hr = Set(str, l);
                    return hr;
                }

                template <typename T>
                HRESULT Set(const T& s, typename ::std::enable_if<::std::is_convertible<const T&, const wchar_t *>::value, ::Microsoft::WRL::Details::Dummy>::type = ::Microsoft::WRL::Details::Dummy()) throw() {
                    HRESULT hr = S_OK;
                    const wchar_t *str = static_cast<PCWSTR>(s);
                    if (str != nullptr) {
                        unsigned int l;
                        hr = SizeTToUInt32(::wcslen(str), &l);
                        if (SUCCEEDED(hr))
                            hr = Set(str, l);
                    }
                    else
                        hr = Set(L"", 0);
                    return hr;
                }

                HRESULT Set(const HSTRING& s) throw() {
                    HRESULT hr = S_OK;
                    if (s == nullptr || s != hstr_) {
                        Release();
                        hr = ::WindowsDuplicateString(s, &hstr_);
                    }
                    return hr;
                }

                void Attach(HSTRING h) throw() {
                    ::WindowsDeleteString(hstr_);
                    hstr_ = h;
                }

                HSTRING Detach() throw() {
                    HSTRING t = hstr_;
                    hstr_ = nullptr;
                    return t;
                }

                HSTRING* GetAddressOf() throw() {
                    Release();
                    return &hstr_;
                }

                HSTRING* ReleaseAndGetAddressOf() throw() {
                    Release();
                    return &hstr_;
                }

                HSTRING Get() const throw() {
                    return hstr_;
                }

                void Release() throw() {
                    ::WindowsDeleteString(hstr_);
                    hstr_ = nullptr;
                }

                bool IsValid() const throw() {
                    return hstr_ != nullptr;
                }

                UINT32 Length() const throw() {
                    return ::WindowsGetStringLen(hstr_);
                }

                const wchar_t* GetRawBuffer(unsigned int *l) const {
                    return ::WindowsGetStringRawBuffer(hstr_, l);
                }

                HRESULT CopyTo(HSTRING *s) const throw() {
                    return ::WindowsDuplicateString(hstr_, s);
                }

                HRESULT Duplicate(const HString& o) throw() {
                    HSTRING l;
                    HRESULT hr = ::WindowsDuplicateString(o, &l);
                    return ReleaseAndAssignOnSuccess(hr, l, *this);
                }

                bool IsEmpty() const throw() {
                    return hstr_ == nullptr;
                }

                HRESULT Concat(const HString& s, HString& n) const throw() {
                    HSTRING l;
                    HRESULT hr = ::WindowsConcatString(hstr_, s, &l);
                    return ReleaseAndAssignOnSuccess(hr, l, n);
                }

                HRESULT TrimStart(const HString& t, HString& n) const throw() {
                    HSTRING l;
                    HRESULT hr = ::WindowsTrimStringStart(hstr_, t, &l);
                    return ReleaseAndAssignOnSuccess(hr, l, n);
                }

                HRESULT TrimEnd(const HString& t, HString& n) const throw() {
                    HSTRING l;
                    HRESULT hr = ::WindowsTrimStringEnd(hstr_, t, &l);
                    return ReleaseAndAssignOnSuccess(hr, l, n);
                }

                HRESULT Substring(UINT32 s, HString& n) const throw() {
                    HSTRING l;
                    HRESULT hr = ::WindowsSubstring(hstr_, s, &l);
                    return ReleaseAndAssignOnSuccess(hr, l, n);
                }

                HRESULT Substring(UINT32 s, UINT32 len, HString& n) const throw() {
                    HSTRING l;
                    HRESULT hr = ::WindowsSubstringWithSpecifiedLength(hstr_, s, len, &l);
                    return ReleaseAndAssignOnSuccess(hr, l, n);
                }

                HRESULT Replace(const HString& s1, const HString& s2, HString& n) const throw() {
                    HSTRING l;
                    HRESULT hr = ::WindowsReplaceString(hstr_, s1, s2, &l);
                    return ReleaseAndAssignOnSuccess(hr, l, n);
                }

                template<unsigned int s>
                static HStringReference MakeReference(wchar_t const (&str)[s]) throw();

                template<unsigned int s>
                static HStringReference MakeReference(wchar_t const (&str)[s], unsigned int l) throw();

            private:
                static HRESULT ReleaseAndAssignOnSuccess(HRESULT hr, HSTRING n, HString& t) {
                    if (SUCCEEDED(hr)) {
                        *t.ReleaseAndGetAddressOf() = n;
                    }
                    return hr;
                }

            protected:
                HSTRING hstr_;
            };

            class HStringReference {
            private:
                void Init(const wchar_t* str, unsigned int len) {
                    HRESULT hres = ::WindowsCreateStringReference(str, len, &header_, &hstr_);
                    if (FAILED(hres))
                        ::Microsoft::WRL::Details::RaiseException(hres);
                }

                HStringReference() : hstr_(nullptr) {}

            public:
                HStringReference(const wchar_t* str, unsigned int len) throw() : hstr_(nullptr) {
                    Init(str, len);
                }

                template<unsigned int sizeDest>
                 explicit HStringReference(wchar_t const (&str)[sizeDest]) throw() : hstr_(nullptr) {
                    Init(str, sizeDest - 1);
                }

                template <size_t sizeDest>
                explicit HStringReference(wchar_t (&strRef)[sizeDest]) throw() {
                    const wchar_t *str = static_cast<const wchar_t*>(strRef);
                    Init(str, ::wcslen(str));
                }

                template<typename T>
                explicit HStringReference(const T &strRef) throw() : hstr_(nullptr) {
                    const wchar_t* str = static_cast<const wchar_t*>(strRef);
                    size_t len = ::wcslen(str);
                    if(static_cast<size_t>(static_cast<unsigned int>(len)) != len)
                        ::Microsoft::WRL::Details::RaiseException(INTSAFE_E_ARITHMETIC_OVERFLOW);
                    Init(str, len);
                }

                HStringReference(const HStringReference &other) throw() : hstr_(nullptr) {
                    unsigned int len = 0;
                    const wchar_t* value = other.GetRawBuffer(&len);
                    Init(value, len);
                }

                ~HStringReference() throw() {
                    hstr_ = nullptr;
                }

                HStringReference& operator=(const HStringReference &other) throw() {
                    unsigned int len = 0;
                    const wchar_t* value = other.GetRawBuffer(&len);
                    Init(value, len);
                    return *this;
                }

                HSTRING Get() const throw() {
                    return hstr_;
                }

                const wchar_t *GetRawBuffer(unsigned int *len) const {
                    return ::WindowsGetStringRawBuffer(hstr_, len);
                }

                HRESULT CopyTo(HSTRING *str) const throw() {
                    return ::WindowsDuplicateString(hstr_, str);
                }

                friend class HString;

            protected:
                HSTRING_HEADER header_;
                HSTRING hstr_;
            };

            class RoInitializeWrapper {
            public:
                RoInitializeWrapper(RO_INIT_TYPE flags) {
                    hres = ::Windows::Foundation::Initialize(flags);
                }

                ~RoInitializeWrapper() {
                    if(SUCCEEDED(hres))
                        ::Windows::Foundation::Uninitialize();
                }

                operator HRESULT() {
                    return hres;
                }
            private:
                HRESULT hres;
            };
        }
    }
}

#endif
