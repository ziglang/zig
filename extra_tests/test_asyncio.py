import sys

import encodings.idna
import asyncio

def test_async_gil_issue():
    async def f():
        reader, writer = await asyncio.open_connection('example.com', 80)
        writer.close()

    loop = asyncio.get_event_loop()
    loop.run_until_complete(f())
    
def test_async_for():
    # tests if async for receives all stores values in the right order
    # and if the correct methods __aiter__ and __anext__ get called
    # and if the end results of run_until_complete are None (in a tuple)
    import asyncio

    class AsyncIter:
        def __init__(self):
            self._data = list(range(5))
            self._index = 0
        
        def __aiter__(self):
            return self
        
        async def __anext__(self):
            while self._index < 5:
                await asyncio.sleep(1)
                self._index += 1
                return self._data[self._index-1]
            raise StopAsyncIteration

    class Corotest(object):
        def __init__(self):
            self.res = "-"
        
        async def do_loop(self):
            async for x in AsyncIter():
                self.res += str(x)
                self.res += "-"

    cor = Corotest()
    loop = asyncio.get_event_loop()
    futures = [asyncio.ensure_future(cor.do_loop()), asyncio.ensure_future(cor.do_loop())]
    taskres = loop.run_until_complete(asyncio.wait(futures))
    assert cor.res.count('0') == 2
    assert cor.res.count('1') == 2
    assert cor.res.count('2') == 2
    assert cor.res.count('3') == 2
    assert cor.res.count('4') == 2
    assert cor.res.find("0") < cor.res.find("1")
    assert cor.res.find("1") < cor.res.find("2")
    assert cor.res.find("2") < cor.res.find("3")
    assert cor.res.find("3") < cor.res.find("4")
    assert isinstance(taskres, tuple)
    assert len(taskres) == 2
    assert "result=None" in repr(taskres[0].pop())
    assert "result=None" in repr(taskres[0].pop())
    
def test_asynchronous_context_managers():
    # it is important that "releasing lock A" happens before "holding lock B"
    # or the other way around, but it is not allowed that both coroutines
    # hold the lock at the same time
    import encodings.idna
    import asyncio

    class Corotest(object):
        def __init__(self):
            self.res = "-"
        
        async def coro(self, name, lock):
            self.res += ' coro {}: waiting for lock -'.format(name)
            async with lock:
                self.res += ' coro {}: holding the lock -'.format(name)
                await asyncio.sleep(1)
                self.res += ' coro {}: releasing the lock -'.format(name)

    cor = Corotest()
    loop = asyncio.get_event_loop()
    lock = asyncio.Lock()
    coros = asyncio.gather(cor.coro(1, lock), cor.coro(2, lock))
    try:
        loop.run_until_complete(coros)
    finally:
        loop.close()

    assert "coro 1: waiting for lock" in cor.res
    assert "coro 1: holding the lock" in cor.res
    assert "coro 1: releasing the lock" in cor.res
    assert "coro 2: waiting for lock" in cor.res
    assert "coro 2: holding the lock" in cor.res
    assert "coro 2: releasing the lock" in cor.res
    assert cor.res.find("coro 1: releasing the lock") < cor.res.find("coro 2: holding the lock") or \
    cor.res.find("coro 2: releasing the lock") < cor.res.find("coro 1: holding the lock")
