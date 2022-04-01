import io
from cffi import FFI

import pytest
from hypothesis import strategies as st
from hypothesis import given, assume, settings
from hypothesis.stateful import (
    RuleBasedStateMachine, Bundle, rule, run_state_machine_as_test, precondition)
ffi = FFI()

MAX_READ_SIZE = 1024
MIN_READ_SIZE = 1
MAX_SIZE = 0xffff

@st.composite
def data_and_sizes(draw, reads=st.lists(st.integers(MIN_READ_SIZE, MAX_READ_SIZE))):
    reads = draw(reads)
    total_size = sum(reads)
    assume(0 < total_size < MAX_SIZE)
    data = draw(st.binary(min_size=total_size, max_size=total_size))
    return data, reads

class Stream(io.RawIOBase):
    def __init__(self, data, read_sizes):
        assert sum(read_sizes) == len(data)
        self.data = data
        self.n = 0
        self.read_sizes = iter(read_sizes)
        self.partial_read = 0

    def readinto(self, buf):
        if self.n == len(self.data):
            return 0
        if self.partial_read:
            read_size = self.partial_read
        else:
            read_size = next(self.read_sizes)
        if len(buf) < read_size:
            self.partial_read = read_size - len(buf)
            read_size = len(buf)
        else:
            self.partial_read = 0
        self.update_buffer(buf, self.data[self.n:self.n + read_size])
        self.n += read_size
        return read_size

    def update_buffer(self, buf, data):
        n = len(data)
        buf[:n] = data

    def readable(self):
        return True

class StreamCFFI(Stream):
    def update_buffer(self, buf, data):
        n = len(data)
        ffi.buffer(ffi.from_buffer(buf), n)[:] = data


@pytest.mark.parametrize('StreamCls', [Stream, StreamCFFI])
@given(params=data_and_sizes(), chunk_size=st.integers(MIN_READ_SIZE, 8192))
def test_buf(params, chunk_size, StreamCls):
    data, sizes = params
    stream = StreamCls(data, sizes)
    assert io.BufferedReader(stream, chunk_size).read(len(data)) == data

class StateMachine(RuleBasedStateMachine):
    def __init__(self, stream, reference):
        super().__init__()
        self.stream = stream
        self.reference = reference

    @rule(size=st.integers(MIN_READ_SIZE, MAX_READ_SIZE))
    def read(self, size):
        expected = self.reference.read(size)
        assert self.stream.read(size) == expected

    @rule(size=st.integers(MIN_READ_SIZE, MAX_READ_SIZE))
    def readinto(self, size):
        expected = self.reference.read(size)
        buf = bytearray(size)
        n = self.stream.readinto(buf)
        assert buf[:n] == expected

    @rule()
    def readline(self):
        expected = self.reference.readline(80)
        assert self.stream.readline(80) == expected

@pytest.mark.parametrize('StreamCls', [Stream, StreamCFFI])
@settings(max_examples=50, deadline=None)
@given(params=data_and_sizes(), chunk_size=st.integers(MIN_READ_SIZE, 8192))
def test_stateful(params, chunk_size, StreamCls):
    data, sizes = params
    raw_stream = StreamCls(data, sizes)
    reference = io.BytesIO(data)
    stream = io.BufferedReader(raw_stream, chunk_size)
    sm = StateMachine(stream, reference)
    run_state_machine_as_test(lambda: sm)
