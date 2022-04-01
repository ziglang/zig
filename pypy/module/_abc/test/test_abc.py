class AppTestAbcModule:
    def test_import_builtin(self):
        from _abc import (get_cache_token, _abc_init, _abc_register,
                          _abc_instancecheck, _abc_subclasscheck, _get_dump,
                          _reset_registry, _reset_caches)

    def test_basic(self):
        import _abc

        class SomeABC: pass
        
        _abc._abc_init(SomeABC)
        assert hasattr(SomeABC, '__abstractmethods__')

        class SomeConcreteSubClass: pass
        _abc._abc_register(SomeABC, SomeConcreteSubClass)
        
        # _abc._abc_instancecheck calls cls.__subclasscheck__, but since
        # we've only called _abc_init and haven't set the metaclass, we
        # need to monkeypatch SomeABC before calling _abc_instancecheck
        from types import MethodType
        SomeABC.__subclasscheck__ = MethodType(_abc._abc_subclasscheck, SomeABC)
        assert _abc._abc_instancecheck(SomeABC, SomeConcreteSubClass())
        assert _abc._abc_subclasscheck(SomeABC, SomeConcreteSubClass)

        class SomeOtherClass: pass
        assert not _abc._abc_instancecheck(SomeABC, SomeOtherClass())
        assert not _abc._abc_subclasscheck(SomeABC, SomeOtherClass)

        _abc._reset_registry(SomeABC)
        _abc._reset_caches(SomeABC)
        assert not _abc._abc_instancecheck(SomeABC, SomeConcreteSubClass())
        assert not _abc._abc_subclasscheck(SomeABC, SomeConcreteSubClass)
    
    def test_cache(self):
        import _abc

        class SomeABC:
            pass

        token_before = _abc.get_cache_token()
        assert _abc.get_cache_token() == token_before

        _abc._abc_init(SomeABC)
        assert _abc.get_cache_token() == token_before

        class SomeConcreteSubClass: pass
        _abc._abc_register(SomeABC, SomeConcreteSubClass)
        assert _abc.get_cache_token() != token_before

        registry, cache, negative_cache, negative_cache_version = _abc._get_dump(SomeABC)
        assert len(registry) == 1
        assert len(cache) == 0
        assert len(negative_cache) == 0
        assert negative_cache_version == token_before

        assert _abc._abc_subclasscheck(SomeABC, SomeConcreteSubClass)
        registry, cache, negative_cache, negative_cache_version = _abc._get_dump(SomeABC)
        assert len(registry) == 1
        assert len(cache) == 1
        assert len(negative_cache) == 0
        assert negative_cache_version == _abc.get_cache_token()

        class SomeOtherClass: pass
        assert not _abc._abc_subclasscheck(SomeABC, SomeOtherClass)
        registry, cache, negative_cache, negative_cache_version = _abc._get_dump(SomeABC)
        assert len(registry) == 1
        assert len(cache) == 1
        assert len(negative_cache) == 1
        assert negative_cache_version == _abc.get_cache_token()

        _abc._reset_caches(SomeABC)
        registry, cache, negative_cache, negative_cache_version = _abc._get_dump(SomeABC)
        assert len(registry) == 1
        assert len(cache) == 0
        assert len(negative_cache) == 0
        assert negative_cache_version == _abc.get_cache_token()

        _abc._reset_registry(SomeABC)
        registry, cache, negative_cache, negative_cache_version = _abc._get_dump(SomeABC)
        assert len(registry) == 0
        assert len(cache) == 0
        assert len(negative_cache) == 0
        assert negative_cache_version == _abc.get_cache_token()
