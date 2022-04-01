import sys

from py.io import ansi_print, get_terminal_width

"""
Black       0;30     Dark Gray     1;30
Blue        0;34     Light Blue    1;34
Green       0;32     Light Green   1;32
Cyan        0;36     Light Cyan    1;36
Red         0;31     Light Red     1;31
Purple      0;35     Light Purple  1;35
Brown       0;33     Yellow        1;33
Light Gray  0;37     White         1;37
"""


import os
if os.environ.get('TERM', 'dumb').find('256') > 0:
    from ansiramp import ansi_ramp80
    palette = map(lambda x: "38;5;%d" % x, ansi_ramp80)
else:
    palette = [39, 34, 35, 36, 31, 33, 32, 37]

# used for debugging/finding new coordinates
# How to:
#   1. Set DEBUG to True
#   2. Add a new coordinate to coordinates with a high distance and high max colour (e.g. 300)
#   3. Run, pick an interesting coordinate from the shown list and replace the newly added
#      coordinate by it.
#   4. Rerun to see the max colour, insert this max colour where you put the high max colour.
#   5. Set DEBUG to False
DEBUG = False


class Mandelbrot:
    def __init__ (self, width=100, height=28, x_pos=-0.5, y_pos=0, distance=6.75):
        self.xpos = x_pos
        self.ypos = y_pos
        aspect_ratio = 1/3.
        factor = float(distance) / width # lowering the distance will zoom in
        self.xscale = factor * aspect_ratio
        self.yscale = factor
        self.iterations = 170
        self.x = width
        self.y = height
        self.z0 = complex(0, 0)

    def init(self):
        self.reset_lines = False
        xmin = self.xpos - self.xscale * self.x / 2
        ymin = self.ypos - self.yscale * self.y / 2
        self.x_range = [xmin + self.xscale * ix for ix in range(self.x)]
        self.y_range = [ymin + self.yscale * iy for iy in range(self.y)]

    def reset(self, cnt):
        self.reset_lines = cnt

    def generate(self):
        self.reset_lines = False
        iy = 0
        while iy < self.y:
            ix = 0
            while ix < self.x:
                c = complex(self.x_range[ix], self.y_range[iy])
                z = self.z0
                colour = 0
                mind = 2

                for i in range(self.iterations):
                    z = z * z + c
                    d = abs(z)
                    if d >= 2:
                        colour = min(int(mind / 0.007), 254) + 1
                        break
                    else:
                        mind = min(d, mind)

                yield ix, iy, colour
                if self.reset_lines is not False: # jump to the beginning of the line
                    iy += self.reset_lines
                    do_break = bool(self.reset_lines)
                    self.reset_lines = False
                    if do_break:
                        break
                    ix = 0
                else:
                    ix += 1
            iy += 1


class Driver(object):
    zoom_locations = [
        # x, y, "distance", max color range
        (0.37865401, 0.669227668, 0.04, 111),
        (-1.2693, -0.4145, 0.2, 105),
        (-1.2693, -0.4145, 0.05, 97),
        (-1.2642, -0.4185, 0.01, 95),
        (-1.15, -0.28, 0.9, 94),
        (-1.15, -0.28, 0.3, 58),
        (-1.15, -0.28, 0.05, 26),
            ]
    def __init__(self, **kwargs):
        self.kwargs = kwargs
        self.zoom_location = -1
        self.max_colour = 256
        self.colour_range = None
        self.invert = True
        self.interesting_coordinates = []
        self.init()

    def init(self):
        self.width = get_terminal_width() or 80 # in some envs, the py lib doesnt default the width correctly
        self.mandelbrot = Mandelbrot(width=(self.width or 1), **self.kwargs)
        self.mandelbrot.init()
        self.gen = self.mandelbrot.generate()

    def reset(self, cnt=0):
        """ Resets to the beginning of the line and drops cnt lines internally. """
        self.mandelbrot.reset(cnt)

    def restart(self):
        """ Restarts the current generator. """
        print >>sys.stderr
        self.init()

    def dot(self):
        """ Emits a colourful character. """
        x = c = 0
        try:
            x, y, c = self.gen.next()
            if x == 0:
                width = get_terminal_width()
                if width != self.width:
                    self.init()
        except StopIteration:
            if DEBUG and self.interesting_coordinates:
                print >>sys.stderr, "Interesting coordinates:", self.interesting_coordinates
                self.interesting_coordinates = []
            kwargs = self.kwargs
            self.zoom_location += 1
            self.zoom_location %= len(self.zoom_locations)
            loc = self.zoom_locations[self.zoom_location]
            kwargs.update({"x_pos": loc[0], "y_pos": loc[1], "distance": loc[2]})
            self.max_colour = loc[3]
            if DEBUG:
                # Only used for debugging new locations:
                print "Colour range", self.colour_range
            self.colour_range = None
            self.restart()
            return
        if self.print_pixel(c, self.invert):
            self.interesting_coordinates.append(dict(x=(x, self.mandelbrot.x_range[x]),
                                                     y=(y, self.mandelbrot.y_range[y])))
        if x == self.width - 1:
            print >>sys.stderr

    def print_pixel(self, colour, invert=1):
        chars = [".", ".", "+", "*", "%", "#"]
        idx = lambda chars: (colour+1) * (len(chars) - 1) / self.max_colour
        if invert:
            idx = lambda chars, idx=idx:len(chars) - 1 - idx(chars)
        char = chars[idx(chars)]
        ansi_colour = palette[idx(palette)]
        ansi_print(char, ansi_colour, newline=False, flush=True)
        if DEBUG:
            if self.colour_range is None:
                self.colour_range = [colour, colour]
            else:
                old_colour_range = self.colour_range
                self.colour_range = [min(self.colour_range[0], colour), max(self.colour_range[1], colour)]
                if old_colour_range[0] - colour > 3 or colour - old_colour_range[1] > 3:
                    return True


if __name__ == '__main__':
    import random
    from time import sleep

    d = Driver()
    while True:
        sleep(random.random() / 800)
        d.dot()
        if 0 and random.random() < 0.01:
            string = "WARNING! " * 3
            d.jump(len(string))
            print string,
