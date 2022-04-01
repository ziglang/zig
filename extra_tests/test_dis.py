import dis
import io

def compare_lines(t1, t2):
    for l1, l2 in zip(t1.split('\n'), t2.split('\n')):
        if 'LOAD_CONST' in l1:
            # some small variation is OK
            assert 'LOAD_CONST' in l2
        else:
            assert l1.strip() == l2.strip()

def test_asyncFor():
    co = compile('''
async def f():
    class Iterable:
        def __aiter__(self):
            return self

        async def __anext__(self):
            raise StopAsyncIteration


    async for i in Iterable():
        pass
    else:
        print('ok')
    ''', '<str>', 'exec')
    # Python does not resursively call dis._disassemble, but we want
    # the dis of the "async for", which we can only access inside a "async def"
    result = io.StringIO()
    dis.dis(co.co_consts[0].co_code, file=result)
    cpython38 = """ 0 LOAD_BUILD_CLASS
          2 LOAD_CONST               1 (1)
          4 LOAD_CONST               2 (2)
          6 MAKE_FUNCTION            0
          8 LOAD_CONST               2 (2)
         10 CALL_FUNCTION            2
         12 STORE_FAST               0 (0)
         14 LOAD_FAST                0 (0)
         16 CALL_FUNCTION            0
         18 GET_AITER
    >>   20 SETUP_FINALLY           12 (to 34)
         22 GET_ANEXT
         24 LOAD_CONST               0 (0)
         26 YIELD_FROM
         28 POP_BLOCK
         30 STORE_FAST               1 (1)
         32 JUMP_ABSOLUTE           20
    >>   34 END_ASYNC_FOR
         36 LOAD_GLOBAL              0 (0)
         38 LOAD_CONST               3 (3)
         40 CALL_FUNCTION            1
         42 POP_TOP
         44 LOAD_CONST               0 (0)
         46 RETURN_VALUE
"""

    compare_lines(cpython38, result.getvalue()) 
