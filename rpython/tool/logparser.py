#! /usr/bin/env python
"""
Syntax:
    python logparser.py <action> <logfilename> <output> <options...>

Actions:
    draw-time      draw a timeline image of the log (format PNG by default)
    print-summary  print a summary of the log
"""
import sys, re
from rpython.rlib.debug import DebugLog
from rpython.tool import progressbar

def parse_log_file(filename, verbose=True):
    f = open(filename, 'r')
    if f.read(2) == 'BZ':
        f.close()
        import bz2
        f = bz2.BZ2File(filename, 'r')
    else:
        f.seek(0)
    lines = f.readlines()
    f.close()
    #
    return parse_log(lines, verbose=verbose)

def parse_log(lines, verbose=False):
    color = "(?:\x1b.*?m)?"
    r_start = re.compile(color + r"\[([0-9a-fA-F]+)\] \{([\w-]+)" + color + "$")
    r_stop  = re.compile(color + r"\[([0-9a-fA-F]+)\] ([\w-]+)\}" + color + "$")
    lasttime = 0
    log = DebugLog()
    time_decrase = False
    performance_log = True
    nested = 0
    #
    if verbose and sys.stdout.isatty():
        progress = progressbar.ProgressBar(color='green')
        counter = 0
    else:
        progress = None
    single_percent = len(lines) / 100
    if verbose:
        vnext = 0
    else:
        vnext = -1
    for i, line in enumerate(lines):
        if i == vnext:
            if progress is not None:
                progress.render(counter)
                counter += 1
                vnext += single_percent
            else:
                sys.stderr.write('%d%%..' % int(100.0*i/len(lines)))
                vnext += 500000
        line = line.rstrip()
        match = r_start.match(line)
        if match:
            record = log.debug_start
            nested += 1
        else:
            match = r_stop.match(line)
            if match:
                record = log.debug_stop
                nested -= 1
            else:
                log.debug_print(line)
                performance_log = performance_log and nested == 0
                continue
        time = int(int(match.group(1), 16))
        time_decrase = time_decrase or time < lasttime
        lasttime = time
        try:
            record(match.group(2), time=int(match.group(1), 16))
        except:
            print "Line", i
            raise
    if verbose:
        sys.stderr.write('loaded\n')
    if performance_log and time_decrase:
        print ("The time decreases!  The log file may have been"
               " produced on a multi-CPU machine and the process"
               " moved between CPUs.")
    return log

def extract_category(log, catprefix='', toplevel=False):
    got = []
    resulttext = []
    for entry in log:
        if entry[0] == 'debug_print':
            resulttext.append(entry[1])
        elif len(entry) == 4:
            got.extend(extract_category(
                entry[3], catprefix, toplevel=entry[0].startswith(catprefix)))
        else:
            resulttext.append('... LOG TRUCATED ...')
    if toplevel:
        resulttext.append('')
        got.insert(0, '\n'.join(resulttext))
    return got

def print_log(log):
    for entry in log:
        if entry[0] == 'debug_print':
            print entry[1]
        else:
            print "{%s" % entry[0]
            if len(entry)>3:
                print_log(entry[3])
            print "%s}" % entry[0]

def kill_category(log, catprefix=''):
    newlog = []
    for entry in log:
        if not entry[0].startswith(catprefix):
            if len(entry) > 3:
                newlog.append(entry[:3] + 
                              (kill_category(entry[3], catprefix),))
            else:
                newlog.append(entry)
    return newlog

def getsubcategories(log):
    return [entry for entry in log if entry[0] != 'debug_print']

def gettimebounds(log):
    # returns (mintime, maxtime)
    maincats = getsubcategories(log)
    return (maincats[0][1], maincats[-1][2])

def gettotaltimes(log):
    # returns a dict {'label' or None: totaltime}
    def rectime(category1, timestart1, timestop1, subcats):
        substartstop = []
        for entry in getsubcategories(subcats):
            if len(entry) != 4:
                continue
            rectime(*entry)
            substartstop.append(entry[1:3])   # (start, stop)
        # compute the total time for category1 as the part of the
        # interval [timestart1, timestop1] that is not covered by
        # any interval from one of the subcats.
        mytime = 0
        substartstop.sort()
        for substart, substop in substartstop:
            if substart >= timestop1:
                break
            if substart > timestart1:
                mytime += substart - timestart1
            if timestart1 < substop:
                timestart1 = substop
        if timestart1 < timestop1:
            mytime += timestop1 - timestart1
        #
        try:
            result[category1] += mytime
        except KeyError:
            result[category1] = mytime
    #
    result = {}
    timestart0, timestop0 = gettimebounds(log)
    rectime(None, timestart0, timestop0, log)
    return result

# ____________________________________________________________


COLORS = {
    None: (248, 248, 248),
    '': (160, 160, 160),
    'gc-': (224, 0, 0),
    'gc-minor': (192, 0, 16),
    'gc-collect': (255, 0, 0),
    'jit-': (0, 224, 0),
    'jit-running': (192, 255, 160),
    'jit-tracing': (0, 255, 0),
    'jit-optimize': (160, 255, 0),
    'jit-backend': (0, 255, 144),
    'jit-blackhole': (0, 160, 0),
    }
SUMMARY = {
    None: 'normal execution',
    '': 'other',
    'gc-': 'gc',
    'jit-': 'jit',
    'jit-running': 'jit-running',
    }

def getcolor(category):
    while category not in COLORS:
        category = category[:-1]
    return COLORS[category]

def getlightercolor((r, g, b)):
    return ((r*2+255)//3, (g*2+255)//3, (b*2+255)//3)

def getdarkercolor((r, g, b)):
    return (r*2//3, g*2//3, b*2//3)

def getlabel(text, _cache={}):
    try:
        return _cache[text]
    except KeyError:
        pass
    from PIL import Image, ImageDraw
    if None not in _cache:
        image = Image.new("RGBA", (1, 1), (0, 0, 0, 0))
        draw = ImageDraw.Draw(image)
        _cache[None] = draw
    else:
        draw = _cache[None]
    sx, sy = draw.textsize(text)
    texthoriz = Image.new("RGBA", (sx, sy), (0, 0, 0, 0))
    ImageDraw.Draw(texthoriz).text((0, 0), text, fill=(0, 0, 0))
    textvert = texthoriz.rotate(90)
    _cache[text] = sx, sy, texthoriz, textvert
    return _cache[text]

def bevelrect(draw, (x1, y1, x2, y2), color):
    if x2 <= x1:
        x2 = x1 + 1   # minimal width
    elif x2 >= x1 + 4:
        draw.line((x1, y1+1, x1, y2-1), fill=getlightercolor(color))
        x1 += 1
        x2 -= 1
        draw.line((x2, y1+1, x2, y2-1), fill=getdarkercolor(color))
    draw.line((x1, y1, x2-1, y1), fill=getlightercolor(color))
    y1 += 1
    y2 -= 1
    draw.line((x1, y2, x2-1, y2), fill=getdarkercolor(color))
    draw.rectangle((x1, y1, x2-1, y2-1), fill=color)

# ----------

def get_timeline_image(log, width, height):
    from PIL import Image, ImageDraw
    timestart0, timestop0 = gettimebounds(log)
    assert timestop0 > timestart0
    timefactor = float(width) / (timestop0 - timestart0)
    #
    def recdraw(sublist, subheight):
        firstx1 = None
        for entry in sublist:
            try:
                category1, timestart1, timestop1, subcats = entry
            except ValueError:
                continue
            x1 = int((timestart1 - timestart0) * timefactor)
            x2 = int((timestop1 - timestart0) * timefactor)
            y1 = (height - subheight) / 2
            y2 = y1 + subheight
            y1 = int(y1)
            y2 = int(y2)
            color = getcolor(category1)
            if firstx1 is None:
                firstx1 = x1
            bevelrect(draw, (x1, y1, x2, y2), color)
            subcats = getsubcategories(subcats)
            if subcats:
                x2 = recdraw(subcats, subheight * 0.94) - 1
            sx, sy, texthoriz, textvert = getlabel(category1)
            if sx <= x2-x1-8:
                image.paste(texthoriz, (x1+5, y1+5), texthoriz)
            elif sy <= x2-x1-2:
                image.paste(textvert, (x1+1, y1+5), textvert)
        return firstx1
    #
    image = Image.new("RGBA", (width, height), (255, 255, 255, 0))
    draw = ImageDraw.Draw(image)
    recdraw(getsubcategories(log), height)
    return image

# ----------

def render_histogram(times, time0, labels, width, barheight):
    # Render a histogram showing horizontal time bars are given by the
    # 'times' dictionary.  Each entry has the label specified by 'labels',
    # or by default the key used in 'times'.
    from PIL import Image, ImageDraw
    times = [(time, key) for (key, time) in times.items()]
    times.sort()
    times.reverse()
    images = []
    for time, key in times:
        fraction = float(time) / time0
        if fraction < 0.01:
            break
        color = getcolor(key)
        image = Image.new("RGBA", (width, barheight), (255, 255, 255, 0))
        draw = ImageDraw.Draw(image)
        x2 = int(fraction * width)
        bevelrect(draw, (0, 0, x2, barheight), color)
        # draw the labels "x%" and "key"
        percent = "%.1f%%" % (100.0 * fraction,)
        s1x, s1y, textpercent, vtextpercent = getlabel(percent)
        s2x, _, textlabel, _ = getlabel(labels.get(key, key))
        t1x = 5
        if t1x + s1x >= x2 - 3:
            if t1x + s1y < x2 - 3:
                textpercent = vtextpercent
                s1x = s1y
            else:
                t1x = x2 + 6
        t2x = t1x + s1x + 12
        if t2x + s2x >= x2 - 3:
            t2x = max(t2x, x2 + 8)
        image.paste(textpercent, (t1x, 5), textpercent)
        image.paste(textlabel,   (t2x, 5), textlabel)
        images.append(image)
    if not images:
        return None
    return combine(images, spacing=0, border=1, horizontal=False)

def get_timesummary_single_image(totaltimes, totaltime0, componentdict,
                                 width, barheight):
    # Compress the totaltimes dict so that its only entries left are
    # from componentdict.  We do that by taking the times assigned to
    # subkeys in totaltimes and adding them to the superkeys specified
    # in componentdict.
    totaltimes = totaltimes.copy()
    for key, value in totaltimes.items():
        if key in componentdict:
            continue
        del totaltimes[key]
        if key is not None:
            while key not in componentdict:
                key = key[:-1]
            try:
                totaltimes[key] += value
            except KeyError:
                totaltimes[key] = value
    return render_histogram(totaltimes, totaltime0, componentdict,
                            width, barheight)

def get_timesummary_image(log, summarywidth, summarybarheight):
    timestart0, timestop0 = gettimebounds(log)
    totaltime0 = timestop0 - timestart0
    totaltimes = gettotaltimes(log)
    spacing = 50
    width = (summarywidth - spacing) // 2
    img1 = get_timesummary_single_image(totaltimes, totaltime0, SUMMARY,
                                        width, summarybarheight)
    if None in totaltimes:
        del totaltimes[None]
    img2 = render_histogram(totaltimes, totaltime0, {},
                            width, summarybarheight)
    if img2 is None:
        return img1
    return combine([img1, img2], spacing=spacing, horizontal=True)

# ----------

def combine(imagelist, spacing=50, border=0, horizontal=False):
    if len(imagelist) <= 1 and not border:
        return imagelist[0]
    from PIL import Image, ImageDraw
    wlist = [image.size[0] for image in imagelist]
    hlist = [image.size[1] for image in imagelist]
    if horizontal:
        w = sum(wlist) + spacing*(len(imagelist)-1)
        h = max(hlist)
    else:
        w = max(wlist)
        h = sum(hlist) + spacing*(len(imagelist)-1)
    w += 2*border
    h += 2*border
    bigimage = Image.new("RGBA", (w, h), (255, 255, 255, 0))
    if border:
        draw = ImageDraw.Draw(bigimage)
        draw.rectangle((0, 0, w-1, border-1), fill=(0, 0, 0))
        draw.rectangle((0, h-border, w-1, h-1), fill=(0, 0, 0))
        draw.rectangle((0, 0, border-1, h-1), fill=(0, 0, 0))
        draw.rectangle((w-1, 0, w-border, h-1), fill=(0, 0, 0))
    x = border
    y = border
    for image in imagelist:
        bigimage.paste(image, (x, y))
        if horizontal:
            x += image.size[0] + spacing
        else:
            y += image.size[1] + spacing
    return bigimage

def draw_timeline_image(log, output=None, mainwidth=3000, mainheight=150,
                        summarywidth=850, summarybarheight=40):
    mainwidth = int(mainwidth)
    mainheight = int(mainheight)
    summarywidth = int(summarywidth)
    summarybarheight = int(summarybarheight)
    images = []
    if mainwidth > 0 and mainheight > 0:
        images.append(get_timeline_image(log, mainwidth, mainheight))
    if summarywidth > 0 and summarybarheight > 0:
        images.append(get_timesummary_image(log, summarywidth,
                                                 summarybarheight))
    image = combine(images, horizontal=False)
    if output is None:
        image.save(sys.stdout, format='png')
    else:
        image.save(output)

def print_summary(log, out):
    totaltimes = gettotaltimes(log)
    if out == '-':
        outfile = sys.stdout
    else:
        outfile = open(out, "w")
    l = totaltimes.items()
    l.sort(cmp=lambda a, b: cmp(b[1], a[1]))
    total = sum([b for a, b in l])
    for a, b in l:
        if a is None:
            a = 'normal-execution'
        s = " " * (50 - len(a))
        print >>outfile, a, s, "%.2f" % (b*100./total) + "%"
    if out != '-':
        outfile.close()

# ____________________________________________________________


ACTIONS = {
    'draw-time': (draw_timeline_image, ['output=',
                                        'mainwidth=', 'mainheight=',
                                        'summarywidth=', 'summarybarheight=',
                                        ]),
    'print-summary': (print_summary, []),
    }

if __name__ == '__main__':
    import getopt
    if len(sys.argv) < 3:
        print __doc__
        sys.exit(2)
    action = sys.argv[1]
    func, longopts = ACTIONS[action]
    options, args = getopt.gnu_getopt(sys.argv[2:], '', longopts)
    if len(args) != 2:
        print __doc__
        sys.exit(2)

    kwds = {}
    for name, value in options:
        assert name.startswith('--')
        kwds[name[2:]] = value
    log = parse_log_file(args[0])
    func(log, args[1], **kwds)
