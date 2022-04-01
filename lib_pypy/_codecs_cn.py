# this getcodec() function supports any multibyte codec, although
# for compatibility with CPython it should only be used for the
# codecs from this module, i.e.:
#
#     'gb2312', 'gbk', 'gb18030', 'hz'

from _multibytecodec import __getcodec as getcodec
