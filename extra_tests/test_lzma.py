import pytest

import os

lzma = pytest.importorskip('lzma')


def test_compressor():
    compressor = lzma.LZMACompressor(
        check=lzma.CHECK_CRC64,
        filters=[
            {"id": lzma.FILTER_X86},
            {"id": lzma.FILTER_LZMA2, "preset": lzma.PRESET_DEFAULT},
        ],
    )

    compressor.compress(b"hello world")

