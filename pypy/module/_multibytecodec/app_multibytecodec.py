# NOT_RPYTHON
#
# The interface here may be a little bit on the lightweight side.

from _multibytecodec import MultibyteIncrementalDecoder
from _multibytecodec import MultibyteIncrementalEncoder


class MultibyteStreamReader(MultibyteIncrementalDecoder):
    def __new__(cls, stream, errors=None):
        self = MultibyteIncrementalDecoder.__new__(cls, errors)
        self.stream = stream
        return self

    def __read(self, read, size):
        if size is None or size < 0:
            return MultibyteIncrementalDecoder.decode(self, read(), True)
        while True:
            data = read(size)
            final = not data
            output = MultibyteIncrementalDecoder.decode(self, data, final)
            if output or final:
                return output
            size = 1   # read 1 more byte and retry

    def read(self, size=None):
        return self.__read(self.stream.read, size)

    def readline(self, size=None):
        return self.__read(self.stream.readline, size)

    def readlines(self, sizehint=None):
        return self.__read(self.stream.read, sizehint).splitlines(True)


class MultibyteStreamWriter(MultibyteIncrementalEncoder):
    def __new__(cls, stream, errors=None):
        self = MultibyteIncrementalEncoder.__new__(cls, errors)
        self.stream = stream
        return self

    def write(self, data):
        self.stream.write(MultibyteIncrementalEncoder.encode(
                self, data))

    def reset(self):
        data = MultibyteIncrementalEncoder.encode(
            self, '', final=True)
        if len(data) > 0:
            self.stream.write(data)
        MultibyteIncrementalEncoder.reset(self)

    def writelines(self, lines):
        for data in lines:
            self.write(data)
