#! /usr/bin/env python
import colorsys

def hsv2ansi(h, s, v):
    # h: 0..1, s/v: 0..1
    if s < 0.1:
        return int(v * 23) + 232
    r, g, b = map(lambda x: int(x * 5), colorsys.hsv_to_rgb(h, s, v))
    return 16 + (r * 36) + (g * 6) + b

def ramp_idx(i, num):
    assert num > 0
    i0 = float(i) / num
    h = 0.57 + i0
    s = 1 - pow(i0,3)
    v = 1
    return hsv2ansi(h, s, v)

def ansi_ramp(num):
    return [ramp_idx(i, num) for i in range(num)]

ansi_ramp80 = ansi_ramp(80)

if __name__ == '__main__':
    import sys
    from py.io import ansi_print
    colors = int(sys.argv[1]) if len(sys.argv) > 1 else 80
    for col in range(colors):
        ansi_print('#', "38;5;%d" % ramp_idx(col, colors), newline=False, flush=True)
