/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#ifndef _WRL_COREWRAPPERS_H_
#define _WRL_COREWRAPPERS_H_

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
