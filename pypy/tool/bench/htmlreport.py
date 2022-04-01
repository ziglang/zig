#!/usr/bin/env python

import Image
import ImageDraw
import urllib
import StringIO
import math
import sys
import colorsys

import py
pyhtml = py.xml.html

from result import (
    PerfResult, PerfResultDelta, PerfResultCollection,
    PerfTable
)

    
class Page:
    """generates a benchmark summary page
    The generated page is self contained, all images are inlined. The
    page refers to a local css file 'benchmark_report.css'.
    """
    
    def __init__(self, perftable=None):
        """perftable is of type PerfTable"""
        self.perftable = perftable

    def render(self):
        """return full rendered page html tree for the perftable."""
        
        perftable = self.perftable
        testid2collections = perftable.get_testid2collections()

        # loop to get per-revision collection and the 
        # maximum delta revision collections. 
        maxdeltas = []
        revdeltas = {}
        start = end = None
        for testid, collections in testid2collections.iteritems():
            if len(collections) < 2:  # less than two revisions sampled
                continue
            # collections are sorted by lowest REVNO first 
            delta = PerfResultDelta(collections[0], collections[-1])
            maxdeltas.append(delta)

            # record deltas on target revisions
            for col1, col2 in zip(collections, collections[1:]):
                revdelta = PerfResultDelta(col1, col2)
                l = revdeltas.setdefault(col2.revision, [])
                l.append(revdelta)
            
            # keep track of overall earliest and latest revision 
            if start is None or delta._from.revision < start.revision: 
                start = delta._from.results[0]
            if end is None or delta._to.revision > end.revision:
                end = delta._to.results[0]

        # sort by best changes first 
        maxdeltas.sort(key=lambda x: x.percent)

        # generate revision reports
        revno_deltas = revdeltas.items()
        revno_deltas.sort()
        revno_deltas.reverse()
        revreports = []
        for revno, deltas in revno_deltas:
            # sort by best changes first 
            deltas.sort(key=lambda x: x.percent)
            revreports.append(self.render_report(deltas))
        assert revreports

        # generate images
        #
        # generate the x axis, a list of revision numbers
        xaxis = perftable.list_values_of('revision')
        xaxis.sort()
        # samples of tests in the order of max_deltas test_ids
        samples = [testid2collections[delta.test_id] for delta in maxdeltas]
        # images in the order of max_deltas test_ids
        images = [self.gen_image_map(sample, xaxis) for sample in samples]

        page = pyhtml.html( 
            pyhtml.head(
                pyhtml.meta(
                    name="Content-Type", 
                    value="text/html; charset=latin1",
                    ),
                pyhtml.link(rel="stylesheet",
                            type="text/css",
                            href="benchmark_report.css")
 
                ),
            pyhtml.body(
                #self.render_header(start, end),
                self.render_table(maxdeltas, images, anchors=False), 
                *revreports
                )
            )
        return page 

    def _revision_report_name(self, sample):
        """return anchor name for reports,
        used to link from an image to a report"""
        return 'revno_%s' % (sample.revision,)

    def _revision_test_report_name(self, sample):
        """return anchor name for reports,
        used to link from an image to a report"""
        return 'revno_%s_test_id_%s' % (sample.revision, sample.test_id)

    def gen_image_map(self, samples, revisions=[]):
        """return a tuple of an inlined image and the corresponding image map
        samples is a list of PerfResultCollections
        revisions is a list of revision numbers and represents the x
        axis of the graph"""

        revision2collection = dict(((s.revision, s) for s in samples))
        revision2delta = dict()
        for col1, col2 in zip(samples, samples[1:]):
            revision2delta[col2.revision] = PerfResultDelta(col1, col2)
        max_value = max([s.min_elapsed for s in samples])
        map_name = samples[0].test_id # link between the image and the image map
        if max_value == 0:
            #nothing to draw
            return (pyhtml.span('No value greater than 0'), py.html.span(''))
        
        step = 3 # pixels for each revision on x axis 
        xsize = (len(revisions) - 1) * step +2
        ysize = 32 # height of the image
        im = Image.new("RGB", (xsize + 2, ysize), 'white')
        draw = ImageDraw.Draw(im)
        
        areas = []
        for x, revno in enumerate(revisions):
            if revno not in revision2collection: # data for this revision?
                continue
            sample = revision2collection[revno]
            y = ysize - (sample.min_elapsed *(ysize -2)/max_value) #scale value
            #draw.line((x*step, y, (x+1)*step, y), fill="#888888")
            draw.rectangle((x*step+1, y, x*step + step -1, ysize),
                           fill="#BBBBBB")

            head_color = "#000000"
            if revno in revision2delta:
                change = revision2delta[revno].percent
                if change < -0.15:
                    head_color = "#00FF00"
                elif change > 0.15:
                    head_color = "#FF0000"
            draw.rectangle((x*step+1, y-1, x*step + step -1, y+1),
                           fill=head_color)
            
            areas.append(
                pyhtml.area(
                    shape="rect",
                    coords= '%s,0,%s,%s' % (x*step, (x+1)*step, ysize),
                    href='#%s' % (self._revision_test_report_name(sample),),
                    title="%s Value: %s" % (sample.revision,sample.min_elapsed)
                ))
        del draw
        
        f = StringIO.StringIO()
        im.save(f, "GIF")
        image_src = 'data:image/gif,%s' % (urllib.quote(f.getvalue()),)
        html_image = pyhtml.img(src=image_src,
                                alt='Benchmark graph of %s' % (self._test_id(
                                                                       sample)),
                                usemap='#%s' % (map_name,))
        html_map = pyhtml.map(areas, name=map_name)
        return html_image, html_map
 
    def _color_for_change(self, delta, max_value=20):
        """return green for negative change_in_percent and red for
        positve change_in_percent. If change_in_percent equals 0, then
        grey is returned.
        
         The colors range from light green to full saturated green and
        light red to full saturated red.  Full saturation is reached
        when change_in_percent >= max_value.
        """
        #rgb values are between 0 and 255
        #hsv values are between 0 and 1
        if len(delta._from) < 3 or len(delta._to) < 3:
            return  '#%02x%02x%02x' % (200,200,200) # grey
            
        change_in_percent = delta.percent * 100
        if change_in_percent < 0:
            basic_color = (0,1,0) # green
        else:
            basic_color = (1,0,0) # red

        max_value = 20
        change = min(abs(change_in_percent), max_value)
        
        h,s,v = colorsys.rgb_to_hsv(*basic_color)
        rgb = colorsys.hsv_to_rgb(h, float(change) / max_value, 255)
        return '#%02x%02x%02x' % rgb

    def _change_report(self, delta): 
        """return a red,green or gray colored html representation of a
        PerfResultDelta object.
        """
          
        fromtimes = [x.elapsed_time for x in delta._from.results]
        totimes = [x.elapsed_time for x in delta._to.results]
        
        results = pyhtml.div(
            "r%d [%s] -> r%d[%s]" %(delta._from.revision, 
                                    ", ".join(map(str, fromtimes)),
                                    delta._to.revision,
                                    ", ".join(map(str, totimes)))
        )
        return pyhtml.td(
            pyhtml.div(
                '%+.1f%% change [%.0f - %.0f = %+.0f ms]' %(
                delta.percent * 100, 
                delta._to.min_elapsed, 
                delta._from.min_elapsed,
                delta.delta),
                style= "background-color: %s" % (
                        self._color_for_change(delta)),
            ),
            results,
        )

    def render_revision_header(self, sample):
        """return a header for a report with information about
        committer, messages, revision date.
        """
        revision_id = pyhtml.li('Revision ID: %s' % (sample.revision_id,))
        revision = pyhtml.li('Revision: %s' % (sample.revision,))
        date = pyhtml.li('Date: %s' % (sample.revision_date,))
        logmessage = pyhtml.li('Log Message: %s' % (sample.message,))
        committer = pyhtml.li('Committer: %s' % (sample.committer,))
        return pyhtml.ul([date, committer, revision, revision_id, logmessage])

    def render_report(self, deltas):
        """return a report table with header. 
        
        All deltas must have the same revision_id."""
        deltas = [d for d in deltas if d.test_id]
        
        sample = deltas[0]._to.getfastest()
        report_list = self.render_revision_header(sample)

        table = self.render_table(deltas)
        return pyhtml.div(
            pyhtml.a(name=self._revision_report_name(sample)),
            report_list,
            table,
        )
    
    def render_header(self, start, end):
        """return the header of the page, sample output:
        
        benchmarks on bzr.dev
        from r1231 2006-04-01
        to r1888 2006-07-01
        """
        return [
            pyhtml.div(
                'Benchmarks for %s' % (start.nick,),
                class_="titleline maintitle",
            ),
            pyhtml.div(
                'from r%s %s' % (
                    start.revision,
                    start.revision_date,
                ),
                class_="titleline",
            ),
            pyhtml.div(
                'to r%s %s' % (
                    end.revision,
                    end.revision_date,
                ),
                class_="titleline",
            ),
        ]

    def _test_id(self, sample):
        """helper function, return a short form of a test_id """
        return '.'.join(sample.test_id.split('.')[-2:])
    
    def render_table(self, deltas, images=None, anchors=True):
        """return an html table for deltas and images. 

        this function is used to generate the main table and
        the table of each report"""
        
        classname = "main"
        if images is None:
            classname = "report"
            images = [None] * len(deltas)

        table = []
        for delta, image in zip(deltas, images):
            row = []
            anchor = ''
            if anchors:
                anchor = pyhtml.a(name=self._revision_test_report_name(
                                           delta._to.getfastest()))
            row.append(pyhtml.td(anchor, self._test_id(delta._to.getfastest()),
                                 class_='testid'))
            if image:
                row.append(pyhtml.td(pyhtml.div(*image)))
            row.append(self._change_report(delta))
            table.append(pyhtml.tr(*row))
        return pyhtml.table(border=1, class_=classname, *table)


def main(path_to_perf_history='../.perf_history'):
    try:
        perftable = PerfTable(file(path_to_perf_history).readlines())
    except IOError:
        print 'Cannot find a data file. Please specify one.'
        sys.exit(-1)
    page = Page(perftable).render()
    f = file('benchmark_report.html', 'w')
    try:
        f.write(page.unicode(indent=2).encode('latin-1'))
    finally:
        f.close()
    
if __name__ == '__main__':
    if len(sys.argv) == 1:
        main()
    elif len(sys.argv) == 2:
        main(sys.argv[1])
    elif len(sys.argv ) == 3:
        main(*sys.argv[1:3])
    else:
        print 'Usage: benchmark_report.py [perf_history [branch]]'
        
