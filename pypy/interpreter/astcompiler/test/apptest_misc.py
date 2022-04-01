import pytest

def test_warning_to_error_translation():
    import warnings
    statement = """\
def wrong1():
    a = 1
    b = 2
    global a
    global b
"""
    with warnings.catch_warnings():
        warnings.filterwarnings("error", module="<test string>")
        try:
            compile(statement, '<test string>', 'exec')
        except SyntaxError as err:
            assert err.lineno is not None
            assert err.filename is not None
            assert err.offset is not None
            assert err.msg is not None

def test_error_message_ast():
    import ast
    pos = dict(lineno=2, col_offset=3)
    m = ast.Module([ast.Expr(ast.expr(**pos), **pos)], [])
    with pytest.raises(TypeError) as excinfo:
        compile(m, 'fn', 'exec')
    assert "expected some sort of expr, but got" in str(excinfo.value)

def test_weird_exec_bug():
    with pytest.raises(SyntaxError) as excinfo:
        compile('exec {1:(foo.)}', 'fn', 'exec')
    print(excinfo.value.offset)
    assert excinfo.value.offset == 6

