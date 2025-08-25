/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#ifndef _WRL_CLIENT_H_
#define _WRL_CLIENT_H_

#include <cstddef>
#include <unknwn.h>
/* #include <weakreference.h> */
#include <roapi.h>

/* #include <wrl/def.h> */
#include <wrl/internal.h>

namespace Microsoft {
    namespace WRL {
        namespace Details {
            template <typename T> class ComPtrRefBase {
            protected:
                T* ptr_;

            public:
                typedef typename T::InterfaceType InterfaceType;

#ifndef __WRL_CLASSIC_COM__
                operator IInspectable**() const throw()  {
                    static_assert(__is_base_of(IInspectable, InterfaceType), "Invalid cast");
                    return reinterpret_cast<IInspectable**>(ptr_->ReleaseAndGetAddressOf());
                }
#endif

                operator IUnknown**() const throw() {
                    static_assert(__is_base_of(IUnknown, InterfaceType), "Invalid cast");
                    return reinterpret_cast<IUnknown**>(ptr_->ReleaseAndGetAddressOf());
                }
            };

            template <typename T> class ComPtrRef : public Details::ComPtrRefBase<T> {
            public:
                ComPtrRef(T *ptr) throw() {
                    ComPtrRefBase<T>::ptr_ = ptr;
                }

                operator void**() const throw() {
                    return reinterpret_cast<void**>(ComPtrRefBase<T>::ptr_->ReleaseAndGetAddressOf());
                }

                operator T*() throw() {
                    *ComPtrRefBase<T>::ptr_ = nullptr;
                    return ComPtrRefBase<T>::ptr_;
                }

                operator typename ComPtrRefBase<T>::InterfaceType**() throw() {
                    return ComPtrRefBase<T>::ptr_->ReleaseAndGetAddressOf();
                }

                typename ComPtrRefBase<T>::InterfaceType *operator*() throw() {
                    return ComPtrRefBase<T>::ptr_->Get();
                }

                typename ComPtrRefBase<T>::InterfaceType *const *GetAddressOf() const throw() {
                    return ComPtrRefBase<T>::ptr_->GetAddressOf();
                }

                typename ComPtrRefBase<T>::InterfaceType **ReleaseAndGetAddressOf() throw() {
                    return ComPtrRefBase<T>::ptr_->ReleaseAndGetAddressOf();
                }
            };

        }

        template<typename T> class ComPtr {
        public:
            typedef T InterfaceType;

            ComPtr() throw() : ptr_(nullptr) {}
            ComPtr(decltype(nullptr)) throw() : ptr_(nullptr) {}

            template<class U> ComPtr(U *other) throw() : ptr_(other) {
                InternalAddRef();
            }

            ComPtr(const ComPtr &other) throw() : ptr_(other.ptr_) {
                InternalAddRef();
            }

            template<class U>
            ComPtr(const ComPtr<U> &other) throw() : ptr_(other.Get()) {
                InternalAddRef();
            }

            ComPtr(ComPtr &&other) throw() : ptr_(nullptr) {
                if(this != reinterpret_cast<ComPtr*>(&reinterpret_cast<unsigned char&>(other)))
                    Swap(other);
            }

            template<class U>
            ComPtr(ComPtr<U>&& other) throw() : ptr_(other.Detach()) {}

            ~ComPtr() throw() {
                InternalRelease();
            }

            ComPtr &operator=(decltype(nullptr)) throw() {
                InternalRelease();
                return *this;
            }

            ComPtr &operator=(InterfaceType *other) throw() {
                if (ptr_ != other) {
                    InternalRelease();
                    ptr_ = other;
                    InternalAddRef();
                }
                return *this;
            }

            template<typename U>
            ComPtr &operator=(U *other) throw()  {
                if (ptr_ != other) {
                    InternalRelease();
                    ptr_ = other;
                    InternalAddRef();
                }
                return *this;
            }

            ComPtr& operator=(const ComPtr &other) throw() {
                if (ptr_ != other.ptr_)
                    ComPtr(other).Swap(*this);
                return *this;
            }

            template<class U>
            ComPtr &operator=(const ComPtr<U> &other) throw() {
                ComPtr(other).Swap(*this);
                return *this;
            }

            ComPtr& operator=(ComPtr &&other) throw() {
                ComPtr(other).Swap(*this);
                return *this;
            }

            template<class U>
            ComPtr& operator=(ComPtr<U> &&other) throw() {
                ComPtr(other).Swap(*this);
                return *this;
            }

            void Swap(ComPtr &&r) throw() {
                InterfaceType *tmp = ptr_;
                ptr_ = r.ptr_;
                r.ptr_ = tmp;
            }

            void Swap(ComPtr &r) throw() {
                InterfaceType *tmp = ptr_;
                ptr_ = r.ptr_;
                r.ptr_ = tmp;
            }

            operator Details::BoolType() const throw() {
                return Get() != nullptr ? &Details::BoolStruct::Member : nullptr;
            }

            InterfaceType *Get() const throw()  {
                return ptr_;
            }

            InterfaceType *operator->() const throw() {
                return ptr_;
            }

            Details::ComPtrRef<ComPtr<T>> operator&() throw()  {
                return Details::ComPtrRef<ComPtr<T>>(this);
            }

            const Details::ComPtrRef<const ComPtr<T>> operator&() const throw() {
                return Details::ComPtrRef<const ComPtr<T>>(this);
            }

            InterfaceType *const *GetAddressOf() const throw() {
                return &ptr_;
            }

            InterfaceType **GetAddressOf() throw() {
                return &ptr_;
            }

            InterfaceType **ReleaseAndGetAddressOf() throw() {
                InternalRelease();
                return &ptr_;
            }

            InterfaceType *Detach() throw() {
                T* ptr = ptr_;
                ptr_ = nullptr;
                return ptr;
            }

            void Attach(InterfaceType *other) throw() {
                if (ptr_ != other) {
                    InternalRelease();
                    ptr_ = other;
                }
            }

            unsigned long Reset() {
                return InternalRelease();
            }

            HRESULT CopyTo(InterfaceType **ptr) const throw() {
                InternalAddRef();
                *ptr = ptr_;
                return S_OK;
            }

            HRESULT CopyTo(REFIID riid, void **ptr) const throw() {
                return ptr_->QueryInterface(riid, ptr);
            }

            template<typename U>
            HRESULT CopyTo(U **ptr) const throw() {
                return ptr_->QueryInterface(__uuidof(U), reinterpret_cast<void**>(ptr));
            }

            template<typename U>
            HRESULT As(Details::ComPtrRef<ComPtr<U>> p) const throw() {
                return ptr_->QueryInterface(__uuidof(U), p);
            }

            template<typename U>
            HRESULT As(ComPtr<U> *p) const throw() {
                return ptr_->QueryInterface(__uuidof(U), reinterpret_cast<void**>(p->ReleaseAndGetAddressOf()));
            }

            HRESULT AsIID(REFIID riid, ComPtr<IUnknown> *p) const throw() {
                return ptr_->QueryInterface(riid, reinterpret_cast<void**>(p->ReleaseAndGetAddressOf()));
            }

            /*
            HRESULT AsWeak(WeakRef *pWeakRef) const throw() {
                return ::Microsoft::WRL::AsWeak(ptr_, pWeakRef);
            }
            */
        protected:
            InterfaceType *ptr_;

            void InternalAddRef() const throw() {
                if(ptr_)
                    ptr_->AddRef();
            }

            unsigned long InternalRelease() throw() {
                InterfaceType *tmp = ptr_;
                if(!tmp)
                    return 0;
                ptr_ = nullptr;
                return tmp->Release();
            }
        };

        template <class T, class U>
        bool operator==(const ComPtr<T> &a, const ComPtr<U> &b) throw()
        {
            static_assert(__is_base_of(T, U) || __is_base_of(U, T), "Type incompatible");
            return a.Get() == b.Get();
        }

        template <class T>
        bool operator==(const ComPtr<T> &a, std::nullptr_t) throw()
        {
            return a.Get() == nullptr;
        }

        template <class T>
        bool operator==(std::nullptr_t, const ComPtr<T> &a) throw()
        {
            return a.Get() == nullptr;
        }

        template <class T, class U>
        bool operator!=(const ComPtr<T> &a, const ComPtr<U> &b) throw()
        {
            static_assert(__is_base_of(T, U) || __is_base_of(U, T), "Type incompatible");
            return a.Get() != b.Get();
        }

        template <class T>
        bool operator!=(const ComPtr<T> &a, std::nullptr_t) throw()
        {
            return a.Get() != nullptr;
        }

        template <class T>
        bool operator!=(std::nullptr_t, const ComPtr<T> &a) throw()
        {
            return a.Get() != nullptr;
        }

        template <class T, class U>
        bool operator<(const ComPtr<T> &a, const ComPtr<U> &b) throw()
        {
            static_assert(__is_base_of(T, U) || __is_base_of(U, T), "Type incompatible");
            return a.Get() < b.Get();
        }
    }
}

template<typename T>
void **IID_PPV_ARGS_Helper(::Microsoft::WRL::Details::ComPtrRef<T> pp) throw() {
    static_assert(__is_base_of(IUnknown, typename T::InterfaceType), "Expected COM interface");
    return pp;
}

namespace Windows {
    namespace Foundation {
        template<typename T>
        inline HRESULT ActivateInstance(HSTRING classid, ::Microsoft::WRL::Details::ComPtrRef<T> instance) throw() {
            return ActivateInstance(classid, instance.ReleaseAndGetAddressOf());
        }

        template<typename T>
        inline HRESULT GetActivationFactory(HSTRING classid, ::Microsoft::WRL::Details::ComPtrRef<T> factory) throw() {
            return RoGetActivationFactory(classid, IID_INS_ARGS(factory.ReleaseAndGetAddressOf()));
        }
    }
}

namespace ABI {
    namespace Windows {
        namespace Foundation {
            template<typename T>
            inline HRESULT ActivateInstance(HSTRING classid, ::Microsoft::WRL::Details::ComPtrRef<T> instance) throw() {
                return ActivateInstance(classid, instance.ReleaseAndGetAddressOf());
            }

            template<typename T>
            inline HRESULT GetActivationFactory(HSTRING classid, ::Microsoft::WRL::Details::ComPtrRef<T> factory) throw() {
                return RoGetActivationFactory(classid, IID_INS_ARGS(factory.ReleaseAndGetAddressOf()));
            }
        }
    }
}

#endif
