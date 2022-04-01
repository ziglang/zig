from __future__ import annotations

import pytest

a: int
b: unknown

def test_toplevel_annotation():
    assert __annotations__['a'] == "int"
    assert __annotations__['b'] == "unknown"


def test_simple_with_target():
    class C:
        a: int = 1
        assert __annotations__["a"] == "int"
        assert a == 1

def test_class_annotation():
    class C:
        a: list[int]
        b: str
        assert "__annotations__" in locals()
    assert C.__annotations__ == {"a": "list[int]", "b": "str"}

def test_func_annotations():
    def f(a: list) -> a ** 39:
        return 12
    assert f.__annotations__ == {"a": "list", "return": "a ** 39"}

def test_async_return_bug():
    async def foo(x) -> Foobar:
        pass
    assert foo.__annotations__ == {"return": "Foobar"}
