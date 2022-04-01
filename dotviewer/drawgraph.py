"""
A custom graphic renderer for the '.plain' files produced by dot.

"""

from __future__ import absolute_import, print_function
import re, os, math
os.environ['PYGAME_HIDE_SUPPORT_PROMPT'] = "hide"
import pygame
from pygame.locals import *

from dotviewer.strunicode import forcestr, forceunicode


this_dir = os.path.dirname(os.path.abspath(__file__))
FONT = os.path.join(this_dir, 'font', 'FiraMath-Regular.otf')
FIXEDFONT = os.path.join(this_dir, 'font', 'DroidSansMono.ttf')
COLOR = {
    'aliceblue': (240, 248, 255),
    'antiquewhite': (250, 235, 215),
    'antiquewhite1': (255, 239, 219),
    'antiquewhite2': (238, 223, 204),
    'antiquewhite3': (205, 192, 176),
    'antiquewhite4': (139, 131, 120),
    'aquamarine': (127, 255, 212),
    'aquamarine1': (127, 255, 212),
    'aquamarine2': (118, 238, 198),
    'aquamarine3': (102, 205, 170),
    'aquamarine4': (69, 139, 116),
    'azure': (240, 255, 255),
    'azure1': (240, 255, 255),
    'azure2': (224, 238, 238),
    'azure3': (193, 205, 205),
    'azure4': (131, 139, 139),
    'beige': (245, 245, 220),
    'bisque': (255, 228, 196),
    'bisque1': (255, 228, 196),
    'bisque2': (238, 213, 183),
    'bisque3': (205, 183, 158),
    'bisque4': (139, 125, 107),
    'black': (0, 0, 0),
    'blanchedalmond': (255, 235, 205),
    'blue': (0, 0, 255),
    'blue1': (0, 0, 255),
    'blue2': (0, 0, 238),
    'blue3': (0, 0, 205),
    'blue4': (0, 0, 139),
    'blueviolet': (138, 43, 226),
    'brown': (165, 42, 42),
    'brown1': (255, 64, 64),
    'brown2': (238, 59, 59),
    'brown3': (205, 51, 51),
    'brown4': (139, 35, 35),
    'burlywood': (222, 184, 135),
    'burlywood1': (255, 211, 155),
    'burlywood2': (238, 197, 145),
    'burlywood3': (205, 170, 125),
    'burlywood4': (139, 115, 85),
    'cadetblue': (95, 158, 160),
    'cadetblue1': (152, 245, 255),
    'cadetblue2': (142, 229, 238),
    'cadetblue3': (122, 197, 205),
    'cadetblue4': (83, 134, 139),
    'chartreuse': (127, 255, 0),
    'chartreuse1': (127, 255, 0),
    'chartreuse2': (118, 238, 0),
    'chartreuse3': (102, 205, 0),
    'chartreuse4': (69, 139, 0),
    'chocolate': (210, 105, 30),
    'chocolate1': (255, 127, 36),
    'chocolate2': (238, 118, 33),
    'chocolate3': (205, 102, 29),
    'chocolate4': (139, 69, 19),
    'coral': (255, 127, 80),
    'coral1': (255, 114, 86),
    'coral2': (238, 106, 80),
    'coral3': (205, 91, 69),
    'coral4': (139, 62, 47),
    'cornflowerblue': (100, 149, 237),
    'cornsilk': (255, 248, 220),
    'cornsilk1': (255, 248, 220),
    'cornsilk2': (238, 232, 205),
    'cornsilk3': (205, 200, 177),
    'cornsilk4': (139, 136, 120),
    'crimson': (220, 20, 60),
    'cyan': (0, 255, 255),
    'cyan1': (0, 255, 255),
    'cyan2': (0, 238, 238),
    'cyan3': (0, 205, 205),
    'cyan4': (0, 139, 139),
    'darkgoldenrod': (184, 134, 11),
    'darkgoldenrod1': (255, 185, 15),
    'darkgoldenrod2': (238, 173, 14),
    'darkgoldenrod3': (205, 149, 12),
    'darkgoldenrod4': (139, 101, 8),
    'darkgreen': (0, 100, 0),
    'darkkhaki': (189, 183, 107),
    'darkolivegreen': (85, 107, 47),
    'darkolivegreen1': (202, 255, 112),
    'darkolivegreen2': (188, 238, 104),
    'darkolivegreen3': (162, 205, 90),
    'darkolivegreen4': (110, 139, 61),
    'darkorange': (255, 140, 0),
    'darkorange1': (255, 127, 0),
    'darkorange2': (238, 118, 0),
    'darkorange3': (205, 102, 0),
    'darkorange4': (139, 69, 0),
    'darkorchid': (153, 50, 204),
    'darkorchid1': (191, 62, 255),
    'darkorchid2': (178, 58, 238),
    'darkorchid3': (154, 50, 205),
    'darkorchid4': (104, 34, 139),
    'darksalmon': (233, 150, 122),
    'darkseagreen': (143, 188, 143),
    'darkseagreen1': (193, 255, 193),
    'darkseagreen2': (180, 238, 180),
    'darkseagreen3': (155, 205, 155),
    'darkseagreen4': (105, 139, 105),
    'darkslateblue': (72, 61, 139),
    'darkslategray': (47, 79, 79),
    'darkslategray1': (151, 255, 255),
    'darkslategray2': (141, 238, 238),
    'darkslategray3': (121, 205, 205),
    'darkslategray4': (82, 139, 139),
    'darkslategrey': (47, 79, 79),
    'darkturquoise': (0, 206, 209),
    'darkviolet': (148, 0, 211),
    'deeppink': (255, 20, 147),
    'deeppink1': (255, 20, 147),
    'deeppink2': (238, 18, 137),
    'deeppink3': (205, 16, 118),
    'deeppink4': (139, 10, 80),
    'deepskyblue': (0, 191, 255),
    'deepskyblue1': (0, 191, 255),
    'deepskyblue2': (0, 178, 238),
    'deepskyblue3': (0, 154, 205),
    'deepskyblue4': (0, 104, 139),
    'dimgray': (105, 105, 105),
    'dimgrey': (105, 105, 105),
    'dodgerblue': (30, 144, 255),
    'dodgerblue1': (30, 144, 255),
    'dodgerblue2': (28, 134, 238),
    'dodgerblue3': (24, 116, 205),
    'dodgerblue4': (16, 78, 139),
    'firebrick': (178, 34, 34),
    'firebrick1': (255, 48, 48),
    'firebrick2': (238, 44, 44),
    'firebrick3': (205, 38, 38),
    'firebrick4': (139, 26, 26),
    'floralwhite': (255, 250, 240),
    'forestgreen': (34, 139, 34),
    'gainsboro': (220, 220, 220),
    'ghostwhite': (248, 248, 255),
    'gold': (255, 215, 0),
    'gold1': (255, 215, 0),
    'gold2': (238, 201, 0),
    'gold3': (205, 173, 0),
    'gold4': (139, 117, 0),
    'goldenrod': (218, 165, 32),
    'goldenrod1': (255, 193, 37),
    'goldenrod2': (238, 180, 34),
    'goldenrod3': (205, 155, 29),
    'goldenrod4': (139, 105, 20),
    'gray': (192, 192, 192),
    'gray0': (0, 0, 0),
    'gray1': (3, 3, 3),
    'gray10': (26, 26, 26),
    'gray100': (255, 255, 255),
    'gray11': (28, 28, 28),
    'gray12': (31, 31, 31),
    'gray13': (33, 33, 33),
    'gray14': (36, 36, 36),
    'gray15': (38, 38, 38),
    'gray16': (41, 41, 41),
    'gray17': (43, 43, 43),
    'gray18': (46, 46, 46),
    'gray19': (48, 48, 48),
    'gray2': (5, 5, 5),
    'gray20': (51, 51, 51),
    'gray21': (54, 54, 54),
    'gray22': (56, 56, 56),
    'gray23': (59, 59, 59),
    'gray24': (61, 61, 61),
    'gray25': (64, 64, 64),
    'gray26': (66, 66, 66),
    'gray27': (69, 69, 69),
    'gray28': (71, 71, 71),
    'gray29': (74, 74, 74),
    'gray3': (8, 8, 8),
    'gray30': (77, 77, 77),
    'gray31': (79, 79, 79),
    'gray32': (82, 82, 82),
    'gray33': (84, 84, 84),
    'gray34': (87, 87, 87),
    'gray35': (89, 89, 89),
    'gray36': (92, 92, 92),
    'gray37': (94, 94, 94),
    'gray38': (97, 97, 97),
    'gray39': (99, 99, 99),
    'gray4': (10, 10, 10),
    'gray40': (102, 102, 102),
    'gray41': (105, 105, 105),
    'gray42': (107, 107, 107),
    'gray43': (110, 110, 110),
    'gray44': (112, 112, 112),
    'gray45': (115, 115, 115),
    'gray46': (117, 117, 117),
    'gray47': (120, 120, 120),
    'gray48': (122, 122, 122),
    'gray49': (125, 125, 125),
    'gray5': (13, 13, 13),
    'gray50': (127, 127, 127),
    'gray51': (130, 130, 130),
    'gray52': (133, 133, 133),
    'gray53': (135, 135, 135),
    'gray54': (138, 138, 138),
    'gray55': (140, 140, 140),
    'gray56': (143, 143, 143),
    'gray57': (145, 145, 145),
    'gray58': (148, 148, 148),
    'gray59': (150, 150, 150),
    'gray6': (15, 15, 15),
    'gray60': (153, 153, 153),
    'gray61': (156, 156, 156),
    'gray62': (158, 158, 158),
    'gray63': (161, 161, 161),
    'gray64': (163, 163, 163),
    'gray65': (166, 166, 166),
    'gray66': (168, 168, 168),
    'gray67': (171, 171, 171),
    'gray68': (173, 173, 173),
    'gray69': (176, 176, 176),
    'gray7': (18, 18, 18),
    'gray70': (179, 179, 179),
    'gray71': (181, 181, 181),
    'gray72': (184, 184, 184),
    'gray73': (186, 186, 186),
    'gray74': (189, 189, 189),
    'gray75': (191, 191, 191),
    'gray76': (194, 194, 194),
    'gray77': (196, 196, 196),
    'gray78': (199, 199, 199),
    'gray79': (201, 201, 201),
    'gray8': (20, 20, 20),
    'gray80': (204, 204, 204),
    'gray81': (207, 207, 207),
    'gray82': (209, 209, 209),
    'gray83': (212, 212, 212),
    'gray84': (214, 214, 214),
    'gray85': (217, 217, 217),
    'gray86': (219, 219, 219),
    'gray87': (222, 222, 222),
    'gray88': (224, 224, 224),
    'gray89': (227, 227, 227),
    'gray9': (23, 23, 23),
    'gray90': (229, 229, 229),
    'gray91': (232, 232, 232),
    'gray92': (235, 235, 235),
    'gray93': (237, 237, 237),
    'gray94': (240, 240, 240),
    'gray95': (242, 242, 242),
    'gray96': (245, 245, 245),
    'gray97': (247, 247, 247),
    'gray98': (250, 250, 250),
    'gray99': (252, 252, 252),
    'green': (0, 255, 0),
    'green1': (0, 255, 0),
    'green2': (0, 238, 0),
    'green3': (0, 205, 0),
    'green4': (0, 139, 0),
    'greenyellow': (173, 255, 47),
    'grey': (192, 192, 192),
    'grey0': (0, 0, 0),
    'grey1': (3, 3, 3),
    'grey10': (26, 26, 26),
    'grey100': (255, 255, 255),
    'grey11': (28, 28, 28),
    'grey12': (31, 31, 31),
    'grey13': (33, 33, 33),
    'grey14': (36, 36, 36),
    'grey15': (38, 38, 38),
    'grey16': (41, 41, 41),
    'grey17': (43, 43, 43),
    'grey18': (46, 46, 46),
    'grey19': (48, 48, 48),
    'grey2': (5, 5, 5),
    'grey20': (51, 51, 51),
    'grey21': (54, 54, 54),
    'grey22': (56, 56, 56),
    'grey23': (59, 59, 59),
    'grey24': (61, 61, 61),
    'grey25': (64, 64, 64),
    'grey26': (66, 66, 66),
    'grey27': (69, 69, 69),
    'grey28': (71, 71, 71),
    'grey29': (74, 74, 74),
    'grey3': (8, 8, 8),
    'grey30': (77, 77, 77),
    'grey31': (79, 79, 79),
    'grey32': (82, 82, 82),
    'grey33': (84, 84, 84),
    'grey34': (87, 87, 87),
    'grey35': (89, 89, 89),
    'grey36': (92, 92, 92),
    'grey37': (94, 94, 94),
    'grey38': (97, 97, 97),
    'grey39': (99, 99, 99),
    'grey4': (10, 10, 10),
    'grey40': (102, 102, 102),
    'grey41': (105, 105, 105),
    'grey42': (107, 107, 107),
    'grey43': (110, 110, 110),
    'grey44': (112, 112, 112),
    'grey45': (115, 115, 115),
    'grey46': (117, 117, 117),
    'grey47': (120, 120, 120),
    'grey48': (122, 122, 122),
    'grey49': (125, 125, 125),
    'grey5': (13, 13, 13),
    'grey50': (127, 127, 127),
    'grey51': (130, 130, 130),
    'grey52': (133, 133, 133),
    'grey53': (135, 135, 135),
    'grey54': (138, 138, 138),
    'grey55': (140, 140, 140),
    'grey56': (143, 143, 143),
    'grey57': (145, 145, 145),
    'grey58': (148, 148, 148),
    'grey59': (150, 150, 150),
    'grey6': (15, 15, 15),
    'grey60': (153, 153, 153),
    'grey61': (156, 156, 156),
    'grey62': (158, 158, 158),
    'grey63': (161, 161, 161),
    'grey64': (163, 163, 163),
    'grey65': (166, 166, 166),
    'grey66': (168, 168, 168),
    'grey67': (171, 171, 171),
    'grey68': (173, 173, 173),
    'grey69': (176, 176, 176),
    'grey7': (18, 18, 18),
    'grey70': (179, 179, 179),
    'grey71': (181, 181, 181),
    'grey72': (184, 184, 184),
    'grey73': (186, 186, 186),
    'grey74': (189, 189, 189),
    'grey75': (191, 191, 191),
    'grey76': (194, 194, 194),
    'grey77': (196, 196, 196),
    'grey78': (199, 199, 199),
    'grey79': (201, 201, 201),
    'grey8': (20, 20, 20),
    'grey80': (204, 204, 204),
    'grey81': (207, 207, 207),
    'grey82': (209, 209, 209),
    'grey83': (212, 212, 212),
    'grey84': (214, 214, 214),
    'grey85': (217, 217, 217),
    'grey86': (219, 219, 219),
    'grey87': (222, 222, 222),
    'grey88': (224, 224, 224),
    'grey89': (227, 227, 227),
    'grey9': (23, 23, 23),
    'grey90': (229, 229, 229),
    'grey91': (232, 232, 232),
    'grey92': (235, 235, 235),
    'grey93': (237, 237, 237),
    'grey94': (240, 240, 240),
    'grey95': (242, 242, 242),
    'grey96': (245, 245, 245),
    'grey97': (247, 247, 247),
    'grey98': (250, 250, 250),
    'grey99': (252, 252, 252),
    'honeydew': (240, 255, 240),
    'honeydew1': (240, 255, 240),
    'honeydew2': (224, 238, 224),
    'honeydew3': (193, 205, 193),
    'honeydew4': (131, 139, 131),
    'hotpink': (255, 105, 180),
    'hotpink1': (255, 110, 180),
    'hotpink2': (238, 106, 167),
    'hotpink3': (205, 96, 144),
    'hotpink4': (139, 58, 98),
    'indianred': (205, 92, 92),
    'indianred1': (255, 106, 106),
    'indianred2': (238, 99, 99),
    'indianred3': (205, 85, 85),
    'indianred4': (139, 58, 58),
    'indigo': (75, 0, 130),
    'invis': (255, 255, 254),
    'ivory': (255, 255, 240),
    'ivory1': (255, 255, 240),
    'ivory2': (238, 238, 224),
    'ivory3': (205, 205, 193),
    'ivory4': (139, 139, 131),
    'khaki': (240, 230, 140),
    'khaki1': (255, 246, 143),
    'khaki2': (238, 230, 133),
    'khaki3': (205, 198, 115),
    'khaki4': (139, 134, 78),
    'lavender': (230, 230, 250),
    'lavenderblush': (255, 240, 245),
    'lavenderblush1': (255, 240, 245),
    'lavenderblush2': (238, 224, 229),
    'lavenderblush3': (205, 193, 197),
    'lavenderblush4': (139, 131, 134),
    'lawngreen': (124, 252, 0),
    'lemonchiffon': (255, 250, 205),
    'lemonchiffon1': (255, 250, 205),
    'lemonchiffon2': (238, 233, 191),
    'lemonchiffon3': (205, 201, 165),
    'lemonchiffon4': (139, 137, 112),
    'lightblue': (173, 216, 230),
    'lightblue1': (191, 239, 255),
    'lightblue2': (178, 223, 238),
    'lightblue3': (154, 192, 205),
    'lightblue4': (104, 131, 139),
    'lightcoral': (240, 128, 128),
    'lightcyan': (224, 255, 255),
    'lightcyan1': (224, 255, 255),
    'lightcyan2': (209, 238, 238),
    'lightcyan3': (180, 205, 205),
    'lightcyan4': (122, 139, 139),
    'lightgoldenrod': (238, 221, 130),
    'lightgoldenrod1': (255, 236, 139),
    'lightgoldenrod2': (238, 220, 130),
    'lightgoldenrod3': (205, 190, 112),
    'lightgoldenrod4': (139, 129, 76),
    'lightgoldenrodyellow': (250, 250, 210),
    'lightgray': (211, 211, 211),
    'lightgrey': (211, 211, 211),
    'lightpink': (255, 182, 193),
    'lightpink1': (255, 174, 185),
    'lightpink2': (238, 162, 173),
    'lightpink3': (205, 140, 149),
    'lightpink4': (139, 95, 101),
    'lightsalmon': (255, 160, 122),
    'lightsalmon1': (255, 160, 122),
    'lightsalmon2': (238, 149, 114),
    'lightsalmon3': (205, 129, 98),
    'lightsalmon4': (139, 87, 66),
    'lightseagreen': (32, 178, 170),
    'lightskyblue': (135, 206, 250),
    'lightskyblue1': (176, 226, 255),
    'lightskyblue2': (164, 211, 238),
    'lightskyblue3': (141, 182, 205),
    'lightskyblue4': (96, 123, 139),
    'lightslateblue': (132, 112, 255),
    'lightslategray': (119, 136, 153),
    'lightslategrey': (119, 136, 153),
    'lightsteelblue': (176, 196, 222),
    'lightsteelblue1': (202, 225, 255),
    'lightsteelblue2': (188, 210, 238),
    'lightsteelblue3': (162, 181, 205),
    'lightsteelblue4': (110, 123, 139),
    'lightyellow': (255, 255, 224),
    'lightyellow1': (255, 255, 224),
    'lightyellow2': (238, 238, 209),
    'lightyellow3': (205, 205, 180),
    'lightyellow4': (139, 139, 122),
    'limegreen': (50, 205, 50),
    'linen': (250, 240, 230),
    'magenta': (255, 0, 255),
    'magenta1': (255, 0, 255),
    'magenta2': (238, 0, 238),
    'magenta3': (205, 0, 205),
    'magenta4': (139, 0, 139),
    'maroon': (176, 48, 96),
    'maroon1': (255, 52, 179),
    'maroon2': (238, 48, 167),
    'maroon3': (205, 41, 144),
    'maroon4': (139, 28, 98),
    'mediumaquamarine': (102, 205, 170),
    'mediumblue': (0, 0, 205),
    'mediumorchid': (186, 85, 211),
    'mediumorchid1': (224, 102, 255),
    'mediumorchid2': (209, 95, 238),
    'mediumorchid3': (180, 82, 205),
    'mediumorchid4': (122, 55, 139),
    'mediumpurple': (147, 112, 219),
    'mediumpurple1': (171, 130, 255),
    'mediumpurple2': (159, 121, 238),
    'mediumpurple3': (137, 104, 205),
    'mediumpurple4': (93, 71, 139),
    'mediumseagreen': (60, 179, 113),
    'mediumslateblue': (123, 104, 238),
    'mediumspringgreen': (0, 250, 154),
    'mediumturquoise': (72, 209, 204),
    'mediumvioletred': (199, 21, 133),
    'midnightblue': (25, 25, 112),
    'mintcream': (245, 255, 250),
    'mistyrose': (255, 228, 225),
    'mistyrose1': (255, 228, 225),
    'mistyrose2': (238, 213, 210),
    'mistyrose3': (205, 183, 181),
    'mistyrose4': (139, 125, 123),
    'moccasin': (255, 228, 181),
    'navajowhite': (255, 222, 173),
    'navajowhite1': (255, 222, 173),
    'navajowhite2': (238, 207, 161),
    'navajowhite3': (205, 179, 139),
    'navajowhite4': (139, 121, 94),
    'navy': (0, 0, 128),
    'navyblue': (0, 0, 128),
    'none': (255, 255, 254),
    'oldlace': (253, 245, 230),
    'olivedrab': (107, 142, 35),
    'olivedrab1': (192, 255, 62),
    'olivedrab2': (179, 238, 58),
    'olivedrab3': (154, 205, 50),
    'olivedrab4': (105, 139, 34),
    'orange': (255, 165, 0),
    'orange1': (255, 165, 0),
    'orange2': (238, 154, 0),
    'orange3': (205, 133, 0),
    'orange4': (139, 90, 0),
    'orangered': (255, 69, 0),
    'orangered1': (255, 69, 0),
    'orangered2': (238, 64, 0),
    'orangered3': (205, 55, 0),
    'orangered4': (139, 37, 0),
    'orchid': (218, 112, 214),
    'orchid1': (255, 131, 250),
    'orchid2': (238, 122, 233),
    'orchid3': (205, 105, 201),
    'orchid4': (139, 71, 137),
    'palegoldenrod': (238, 232, 170),
    'palegreen': (152, 251, 152),
    'palegreen1': (154, 255, 154),
    'palegreen2': (144, 238, 144),
    'palegreen3': (124, 205, 124),
    'palegreen4': (84, 139, 84),
    'paleturquoise': (175, 238, 238),
    'paleturquoise1': (187, 255, 255),
    'paleturquoise2': (174, 238, 238),
    'paleturquoise3': (150, 205, 205),
    'paleturquoise4': (102, 139, 139),
    'palevioletred': (219, 112, 147),
    'palevioletred1': (255, 130, 171),
    'palevioletred2': (238, 121, 159),
    'palevioletred3': (205, 104, 137),
    'palevioletred4': (139, 71, 93),
    'papayawhip': (255, 239, 213),
    'peachpuff': (255, 218, 185),
    'peachpuff1': (255, 218, 185),
    'peachpuff2': (238, 203, 173),
    'peachpuff3': (205, 175, 149),
    'peachpuff4': (139, 119, 101),
    'peru': (205, 133, 63),
    'pink': (255, 192, 203),
    'pink1': (255, 181, 197),
    'pink2': (238, 169, 184),
    'pink3': (205, 145, 158),
    'pink4': (139, 99, 108),
    'plum': (221, 160, 221),
    'plum1': (255, 187, 255),
    'plum2': (238, 174, 238),
    'plum3': (205, 150, 205),
    'plum4': (139, 102, 139),
    'powderblue': (176, 224, 230),
    'purple': (160, 32, 240),
    'purple1': (155, 48, 255),
    'purple2': (145, 44, 238),
    'purple3': (125, 38, 205),
    'purple4': (85, 26, 139),
    'red': (255, 0, 0),
    'red1': (255, 0, 0),
    'red2': (238, 0, 0),
    'red3': (205, 0, 0),
    'red4': (139, 0, 0),
    'rosybrown': (188, 143, 143),
    'rosybrown1': (255, 193, 193),
    'rosybrown2': (238, 180, 180),
    'rosybrown3': (205, 155, 155),
    'rosybrown4': (139, 105, 105),
    'royalblue': (65, 105, 225),
    'royalblue1': (72, 118, 255),
    'royalblue2': (67, 110, 238),
    'royalblue3': (58, 95, 205),
    'royalblue4': (39, 64, 139),
    'saddlebrown': (139, 69, 19),
    'salmon': (250, 128, 114),
    'salmon1': (255, 140, 105),
    'salmon2': (238, 130, 98),
    'salmon3': (205, 112, 84),
    'salmon4': (139, 76, 57),
    'sandybrown': (244, 164, 96),
    'seagreen': (46, 139, 87),
    'seagreen1': (84, 255, 159),
    'seagreen2': (78, 238, 148),
    'seagreen3': (67, 205, 128),
    'seagreen4': (46, 139, 87),
    'seashell': (255, 245, 238),
    'seashell1': (255, 245, 238),
    'seashell2': (238, 229, 222),
    'seashell3': (205, 197, 191),
    'seashell4': (139, 134, 130),
    'sienna': (160, 82, 45),
    'sienna1': (255, 130, 71),
    'sienna2': (238, 121, 66),
    'sienna3': (205, 104, 57),
    'sienna4': (139, 71, 38),
    'skyblue': (135, 206, 235),
    'skyblue1': (135, 206, 255),
    'skyblue2': (126, 192, 238),
    'skyblue3': (108, 166, 205),
    'skyblue4': (74, 112, 139),
    'slateblue': (106, 90, 205),
    'slateblue1': (131, 111, 255),
    'slateblue2': (122, 103, 238),
    'slateblue3': (105, 89, 205),
    'slateblue4': (71, 60, 139),
    'slategray': (112, 128, 144),
    'slategray1': (198, 226, 255),
    'slategray2': (185, 211, 238),
    'slategray3': (159, 182, 205),
    'slategray4': (108, 123, 139),
    'slategrey': (112, 128, 144),
    'snow': (255, 250, 250),
    'snow1': (255, 250, 250),
    'snow2': (238, 233, 233),
    'snow3': (205, 201, 201),
    'snow4': (139, 137, 137),
    'springgreen': (0, 255, 127),
    'springgreen1': (0, 255, 127),
    'springgreen2': (0, 238, 118),
    'springgreen3': (0, 205, 102),
    'springgreen4': (0, 139, 69),
    'steelblue': (70, 130, 180),
    'steelblue1': (99, 184, 255),
    'steelblue2': (92, 172, 238),
    'steelblue3': (79, 148, 205),
    'steelblue4': (54, 100, 139),
    'tan': (210, 180, 140),
    'tan1': (255, 165, 79),
    'tan2': (238, 154, 73),
    'tan3': (205, 133, 63),
    'tan4': (139, 90, 43),
    'thistle': (216, 191, 216),
    'thistle1': (255, 225, 255),
    'thistle2': (238, 210, 238),
    'thistle3': (205, 181, 205),
    'thistle4': (139, 123, 139),
    'tomato': (255, 99, 71),
    'tomato1': (255, 99, 71),
    'tomato2': (238, 92, 66),
    'tomato3': (205, 79, 57),
    'tomato4': (139, 54, 38),
    'transparent': (255, 255, 254),
    'turquoise': (64, 224, 208),
    'turquoise1': (0, 245, 255),
    'turquoise2': (0, 229, 238),
    'turquoise3': (0, 197, 205),
    'turquoise4': (0, 134, 139),
    'violet': (238, 130, 238),
    'violetred': (208, 32, 144),
    'violetred1': (255, 62, 150),
    'violetred2': (238, 58, 140),
    'violetred3': (205, 50, 120),
    'violetred4': (139, 34, 82),
    'wheat': (245, 222, 179),
    'wheat1': (255, 231, 186),
    'wheat2': (238, 216, 174),
    'wheat3': (205, 186, 150),
    'wheat4': (139, 126, 102),
    'white': (255, 255, 255),
    'whitesmoke': (245, 245, 245),
    'yellow': (255, 255, 0),
    'yellow1': (255, 255, 0),
    'yellow2': (238, 238, 0),
    'yellow3': (205, 205, 0),
    'yellow4': (139, 139, 0),
    'yellowgreen': (154, 205, 50),
    }

GONS = {
    b'triangle': 3,
    b'diamond': 4,
    b'pentagon': 5,
    b'hexagon': 6,
    b'septagon': 7,
    b'octagon': 8,
}

re_nonword=re.compile(r'([^0-9a-zA-Z_.]+)')
re_linewidth=re.compile(forcestr(r'setlinewidth\((\d+(\.\d*)?|\.\d+)\)'))

def combine(color1, color2, alpha):
    r1, g1, b1 = color1
    r2, g2, b2 = color2
    beta = 1.0 - alpha
    return (int(r1 * alpha + r2 * beta),
            int(g1 * alpha + g2 * beta),
            int(b1 * alpha + b2 * beta))


def highlight_color(color):
    if color == (0, 0, 0): # black becomes magenta
        return (255, 0, 255)
    elif color == (255, 255, 255): # white becomes yellow
        return (255, 255, 0)
    intensity = sum(color)
    if intensity > 191 * 3:
        return combine(color, (128, 192, 0), 0.2)
    else:
        return combine(color, (255, 255, 0), 0.2)

def getcolor(name, default):
    if name in COLOR:
        return COLOR[name]
    elif name.startswith('#') and len(name) == 7:
        rval = COLOR[name] = (int(name[1:3],16), int(name[3:5],16), int(name[5:7],16))
        return rval
    else:
        return default

def ensure_readable(fgcolor, bgcolor):
    if bgcolor is None:
        return fgcolor
    r, g, b = bgcolor

    l = 0.2627 * r + 0.6780 * g + 0.0593 * b
    if l < 70:
        return (255, 255, 255)
    return fgcolor

class GraphLayout:
    fixedfont = False

    def __init__(self, scale, width, height):
        self.scale = scale
        self.boundingbox = width, height
        self.nodes = {}
        self.edges = []
        self.links = {}

    def add_node(self, *args):
        n = Node(*args)
        self.nodes[n.name] = n

    def add_edge(self, *args):
        self.edges.append(Edge(self.nodes, *args))

    def get_display(self):
        from dotviewer.graphdisplay import GraphDisplay
        return GraphDisplay(self)      

    def display(self):
        self.get_display().run()

    def reload(self):
        return self

# async interaction helpers

def display_async_quit():
    pygame.event.post(pygame.event.Event(QUIT))        

def display_async_cmd(**kwds):                
    pygame.event.post(pygame.event.Event(USEREVENT, **kwds))

EventQueue = []

def wait_for_events():
    if not EventQueue:
        EventQueue.append(pygame.event.wait())
        EventQueue.extend(pygame.event.get())

def wait_for_async_cmd():
    # wait until another thread pushes a USEREVENT in the queue
    while True:
        wait_for_events()
        e = EventQueue.pop(0)
        if e.type in (USEREVENT, QUIT):   # discard all other events
            break
    EventQueue.insert(0, e)   # re-insert the event for further processing


class Node:
    def __init__(self, name, x, y, w, h, label, style, shape, color, fillcolor):
        self.name = forceunicode(name)
        self.x = float(x)
        self.y = float(y)
        self.w = float(w)
        self.h = float(h)
        self.label = forceunicode(label)
        self.style = style
        self.shape = shape
        self.color = forceunicode(color)
        self.fillcolor = forceunicode(fillcolor)
        self.highlight = False

    def sethighlight(self, which):
        self.highlight = bool(which)

class Edge:
    label = None
    
    def __init__(self, nodes, tail, head, cnt, *rest):
        self.tail = nodes[forceunicode(tail)]
        self.head = nodes[forceunicode(head)]
        cnt = int(cnt)
        self.points = [(float(rest[i]), float(rest[i+1]))
                       for i in range(0, cnt*2, 2)]
        rest = rest[cnt*2:]
        if len(rest) > 2:
            label, xl, yl = rest[:3]
            self.label = forceunicode(label)
            self.xl = float(xl)
            self.yl = float(yl)
            rest = rest[3:]
        self.style, self.color = rest
        self.color = forceunicode(self.color)
        linematch = re_linewidth.match(self.style)
        if linematch:
            num = linematch.group(1)
            self.linewidth = int(round(float(num)))
            self.style = self.style[linematch.end(0):]
        else:
            self.linewidth = 1
        self.highlight = False
        self.cachedbezierpoints = None
        self.cachedarrowhead = None
        self.cachedlimits = None

    def sethighlight(self, which):
        self.highlight = bool(which)

    def limits(self):
        result = self.cachedlimits
        if result is None:
            points = self.bezierpoints()
            xs = [point[0] for point in points]
            ys = [point[1] for point in points]
            self.cachedlimits = result = (min(xs), max(ys), max(xs), min(ys))
        return result

    def bezierpoints(self):
        result = self.cachedbezierpoints
        if result is None:
            result = []
            pts = self.points
            for i in range(0, len(pts)-3, 3):
                result += beziercurve(pts[i], pts[i+1], pts[i+2], pts[i+3])
            self.cachedbezierpoints = result
        return result

    def arrowhead(self):
        result = self.cachedarrowhead
        if result is None:
            # we don't know if the list of points is in the right order
            # or not :-(  try to guess...
            def dist(node, pt):
                return abs(node.x - pt[0]) + abs(node.y - pt[1])

            error_if_direct = (dist(self.head, self.points[-1]) +
                               dist(self.tail, self.points[0]))
            error_if_reversed = (dist(self.tail, self.points[-1]) +
                                 dist(self.head, self.points[0]))
            if error_if_direct > error_if_reversed:   # reversed edge
                head = 0
                dir = 1
            else:
                head = -1
                dir = -1
            n = 1
            while True:
                try:
                    x0, y0 = self.points[head]
                    x1, y1 = self.points[head+n*dir]
                except IndexError:
                    result = []
                    break
                vx = x0-x1
                vy = y0-y1
                try:
                    f = 0.12 / math.sqrt(vx*vx + vy*vy)
                    vx *= f
                    vy *= f
                    result = [(x0 + 0.9*vx, y0 + 0.9*vy),
                              (x0 + 0.4*vy, y0 - 0.4*vx),
                              (x0 - 0.4*vy, y0 + 0.4*vx)]
                    break
                except (ZeroDivisionError, ValueError):
                    n += 1
            self.cachedarrowhead = result
        return result

def beziercurve(p0, p1, p2, p3, resolution=8):
    (x0, y0) = p0
    (x1, y1) = p1
    (x2, y2) = p2
    (x3, y3) = p3
    result = []
    f = 1.0/(resolution-1)
    append = result.append
    for i in range(resolution):
        t = f*i
        t0 = (1-t)*(1-t)*(1-t)
        t1 =   t  *(1-t)*(1-t) * 3.0
        t2 =   t  *  t  *(1-t) * 3.0
        t3 =   t  *  t  *  t
        append((x0*t0 + x1*t1 + x2*t2 + x3*t3,
                y0*t0 + y1*t1 + y2*t2 + y3*t3))
    return result

def segmentdistance(p0, p1, p):
    "Distance between the point (x,y) and the segment (x0,y0)-(x1,y1)."
    (x0, y0) = p0
    (x1, y1) = p1
    (x, y) = p
    vx = x1 - x0
    vy = y1 - y0
    try:
        l = math.hypot(vx, vy)
        vx /= l
        vy /= l
        dlong = vx*(x-x0) + vy*(y-y0)
    except (ZeroDivisionError, ValueError):
        dlong = -1
    if dlong < 0.0:
        return math.hypot(x-x0, y-y0)
    elif dlong > l:
        return math.hypot(x-x1, y-y1)
    else:
        return abs(vy*(x-x0) - vx*(y-y0))

def ellipse(t, center, a, b):
    """ compute points on an elliplse, with t running from 0 to 2*math.pi, a
    and b being the radii and center as the origin of the ellipse. """
    xcenter, ycenter = center
    return int(xcenter - a / 2.0 * math.sin(t)), int(ycenter - b / 2.0 * math.cos(t))

class GraphRenderer:
    MARGIN = 0.6
    FONTCACHE = {}
    
    def __init__(self, screen, graphlayout, scale=75, highdpi=False):
        if highdpi:
            self.SCALEMIN = 10
            self.SCALEMAX = 200
        else:
            self.SCALEMIN = 3
            self.SCALEMAX = 100
        self.graphlayout = graphlayout
        self.setscale(scale)
        self.setoffset(0, 0)
        self.screen = screen
        self.textzones = []
        self.highlightwords = graphlayout.links
        self.highlight_word = None
        self.visiblenodes = []
        self.visibleedges = []

    def wordcolor(self, word):
        info = self.highlightwords[word]
        if isinstance(info, tuple) and len(info) >= 2:
            color = info[1]
        else:
            color = None
        if color is None:
            color = (128,0,0)
        if word == self.highlight_word:
            return ((255,255,80), color)
        else:
            return (color, None)

    def setscale(self, scale):
        scale = max(min(scale, self.SCALEMAX), self.SCALEMIN)
        self.scale = float(scale)
        w, h = self.graphlayout.boundingbox
        self.margin = int(self.MARGIN * scale)
        self.width = int(w * scale) + (2 * self.margin)
        self.height = int(h * scale) + (2 * self.margin)
        self.bboxh = h
        size = int(15 * (scale-10) / 75)
        self.font = self.getfont(size)

    def getfont(self, size):
        if size in self.FONTCACHE:
            return self.FONTCACHE[size]
        elif size < 5:
            self.FONTCACHE[size] = None
            return None
        else:
            if self.graphlayout.fixedfont:
                filename = FIXEDFONT
            else:
                filename = FONT
            font = self.FONTCACHE[size] = pygame.font.Font(filename, size)
            return font
    
    def setoffset(self, offsetx, offsety):
        "Set the (x,y) origin of the rectangle where the graph will be rendered."
        self.ofsx = offsetx - self.margin
        self.ofsy = offsety - self.margin

    def shiftoffset(self, dx, dy):
        self.ofsx += dx
        self.ofsy += dy

    def getcenter(self):
        w, h = self.screen.get_size()
        return self.revmap(w//2, h//2)

    def setcenter(self, x, y):
        w, h = self.screen.get_size()
        x, y = self.map(x, y)
        self.shiftoffset(x-w//2, y-h//2)

    def shiftscale(self, factor, fix=None):
        if fix is None:
            fixx, fixy = self.screen.get_size()
            fixx //= 2
            fixy //= 2
        else:
            fixx, fixy = fix
        x, y = self.revmap(fixx, fixy)
        self.setscale(self.scale * factor)
        newx, newy = self.map(x, y)
        self.shiftoffset(newx - fixx, newy - fixy)

    def reoffset(self, swidth, sheight):
        offsetx = noffsetx = self.ofsx
        offsety = noffsety = self.ofsy
        width = self.width
        height = self.height

        # if it fits, center it, otherwise clamp
        if width <= swidth:
            noffsetx = (width - swidth) // 2
        else:
            noffsetx = min(max(0, offsetx), width - swidth)

        if height <= sheight:
            noffsety = (height - sheight) // 2
        else:
            noffsety = min(max(0, offsety), height - sheight)

        self.ofsx = noffsetx
        self.ofsy = noffsety

    def getboundingbox(self):
        "Get the rectangle where the graph will be rendered."
        return (-self.ofsx, -self.ofsy, self.width, self.height)

    def visible(self, x1, y1, x2, y2):
        """Is any part of the box visible (i.e. within the bounding box)?

        We have to perform clipping ourselves because with big graphs the
        coordinates may sometimes become longs and cause OverflowErrors
        within pygame.
        """
        w, h = self.screen.get_size()
        return x1 < w and x2 > 0 and y1 < h and y2 > 0

    def computevisible(self):
        del self.visiblenodes[:]
        del self.visibleedges[:]
        w, h = self.screen.get_size()
        for node in self.graphlayout.nodes.values():
            x, y = self.map(node.x, node.y)
            nw2 = int(node.w * self.scale)//2
            nh2 = int(node.h * self.scale)//2
            if x-nw2 < w and x+nw2 > 0 and y-nh2 < h and y+nh2 > 0:
                self.visiblenodes.append(node)
        for edge in self.graphlayout.edges:
            if edge.style == b"invis":
                continue
            x1, y1, x2, y2 = edge.limits()
            x1, y1 = self.map(x1, y1)
            if x1 < w and y1 < h:
                x2, y2 = self.map(x2, y2)
                if x2 > 0 and y2 > 0:
                    self.visibleedges.append(edge)

    def map(self, x, y):
        return (int(x*self.scale) - (self.ofsx - self.margin),
                int((self.bboxh-y)*self.scale) - (self.ofsy - self.margin))

    def revmap(self, px, py):
        return ((px + (self.ofsx - self.margin)) / self.scale,
                self.bboxh - (py + (self.ofsy - self.margin)) / self.scale)

    def draw_node_commands(self, node):
        if node.shape in (b"record", b'Mrecord'):
            return self.draw_record_commands(node)

        xcenter, ycenter = self.map(node.x, node.y)
        boxwidth = int(node.w * self.scale)
        boxheight = int(node.h * self.scale)
        fgcolor = getcolor(node.color, (0,0,0))
        bgcolor = getcolor(node.fillcolor, (255,255,255))
        if node.highlight:
            fgcolor = highlight_color(fgcolor)
            bgcolor = highlight_color(bgcolor)

        text = node.label
        lines = text.replace('\\l','\\l\n').replace('\r','\r\n').split('\n')
        # ignore a final newline
        if not lines[-1]:
            del lines[-1]
        wmax = 0
        hmax = 0
        commands = []
        bkgndcommands = []
        if self.font is None:
            if lines:
                raw_line = lines[0].replace('\\l','').replace('\r','')
                if raw_line:
                    for size in (12, 10, 8, 6, 4):
                        font = self.getfont(size)
                        img = TextSnippet(self, raw_line, (0, 0, 0), bgcolor, font=font)
                        w, h = img.get_size()
                        if (w >= boxwidth or h >= boxheight):
                            continue
                        else:
                            if w>wmax: wmax = w
                            def cmd(img=img, y=hmax, w=w):
                                img.draw(xcenter-w//2, ytop+y)
                            commands.append(cmd)
                            hmax += h
                            break
        else:
            for line in lines:
                raw_line = line.replace('\\l','').replace('\r','') or ' '
                if '\f' in raw_line:   # grayed out parts of the line
                    imgs = []
                    graytext = True
                    h = 16
                    w_total = 0
                    for linepart in raw_line.split('\f'):
                        graytext = not graytext
                        if not linepart.strip():
                            continue
                        if graytext:
                            fgcolor = (128, 160, 160)
                        else:
                            fgcolor = (0, 0, 0)
                        img = TextSnippet(self, linepart, fgcolor, bgcolor)
                        imgs.append((w_total, img))
                        w, h = img.get_size()
                        w_total += w
                    if w_total > wmax: wmax = w_total
                    def cmd(imgs=imgs, y=hmax):
                        for x, img in imgs:
                            img.draw(xleft+x, ytop+y)
                    commands.append(cmd)
                else:
                    img = TextSnippet(self, raw_line, (0, 0, 0), bgcolor)
                    w, h = img.get_size()
                    if w>wmax: wmax = w
                    if raw_line.strip():
                        if line.endswith('\\l'):
                            def cmd(img=img, y=hmax):
                                img.draw(xleft, ytop+y)
                        elif line.endswith('\r'):
                            def cmd(img=img, y=hmax, w=w):
                                img.draw(xright-w, ytop+y)
                        else:
                            def cmd(img=img, y=hmax, w=w):
                                img.draw(xcenter-w//2, ytop+y)
                        commands.append(cmd)
                hmax += h
                #hmax += 8

        # we know the bounding box only now; setting these variables will
        # have an effect on the values seen inside the cmd() functions above
        xleft = xcenter - wmax//2
        xright = xcenter + wmax//2
        ytop = ycenter - hmax//2
        x = xcenter-boxwidth//2
        y = ycenter-boxheight//2
        center = (xcenter, ycenter)

        if node.shape in (b'box', b'rect', b'rectangle'):
            rect = (x-1, y-1, boxwidth+2, boxheight+2)
            if rect[0] < 0:
                rect = (0, y-1, boxwidth+2 + x-1, boxheight+2)
            if rect[1] < 0:
                rect = (rect[0], 0, rect[2], boxheight+2 + y-1)
            def cmd():
                self.screen.fill(bgcolor, rect)
            bkgndcommands.append(cmd)
            def cmd():
                pygame.draw.rect(self.screen, fgcolor, rect, 1)
            commands.append(cmd)
        elif node.shape == b'square':
            width = max(boxwidth+2, boxheight+2)
            rect = (x-1, y-1, width, width)
            def cmd():
                self.screen.fill(bgcolor, rect)
            bkgndcommands.append(cmd)
            def cmd():
                pygame.draw.rect(self.screen, fgcolor, rect, 1)
            commands.append(cmd)

        elif node.shape == b'ellipse':
            rect = (x-1, y-1, boxwidth+2, boxheight+2)
            def cmd():
                pygame.draw.ellipse(self.screen, bgcolor, rect, 0)
            bkgndcommands.append(cmd)
            def cmd():
                pygame.draw.ellipse(self.screen, fgcolor, rect, 1)
            commands.append(cmd)
        elif node.shape == b'circle':
            radius = max(boxwidth+2, boxheight+2) // 2
            def cmd():
                pygame.draw.circle(self.screen, bgcolor, center, radius, 0)
            bkgndcommands.append(cmd)
            def cmd():
                pygame.draw.circle(self.screen, fgcolor, center, radius, 1)
            commands.append(cmd)
        elif node.shape == b'doublecircle':
            radius = max(boxwidth+2, boxheight+2) // 2
            bigradius = int(radius * 1.05)
            def cmd():
                pygame.draw.circle(self.screen, bgcolor, center, bigradius, 0)
            bkgndcommands.append(cmd)
            def cmd():
                pygame.draw.circle(self.screen, fgcolor, center, radius, 1)
                pygame.draw.circle(self.screen, fgcolor, center, bigradius, 1)
            commands.append(cmd)
        elif node.shape == b'octagon':
            step = 1-math.sqrt(2)/2
            points = [(int(x+boxwidth*fx), int(y+boxheight*fy))
                      for fx, fy in [(step,0), (1-step,0),
                                     (1,step), (1,1-step),
                                     (1-step,1), (step,1),
                                     (0,1-step), (0,step)]]
            def cmd():
                pygame.draw.polygon(self.screen, bgcolor, points, 0)
            bkgndcommands.append(cmd)
            def cmd():
                pygame.draw.polygon(self.screen, fgcolor, points, 1)
            commands.append(cmd)
        elif node.shape == b'doubleoctagon' or node.shape == b'tripleoctagon':
            radius = max(boxwidth+2, boxheight+2)
            # not quite right: not all sides are parallel
            width = int(radius * 1.05) - radius
            count = 8
            points = [ellipse((2 * math.pi) / float(count) * (i + 0.5),
                        center, boxwidth, boxheight)
                      for i in range(count)]
            points2 = [ellipse((2 * math.pi) / float(count) * (i + 0.5),
                        center, boxwidth + width, boxheight + width)
                      for i in range(count)]
            points3 = [ellipse((2 * math.pi) / float(count) * (i + 0.5),
                        center, boxwidth + 2 * width, boxheight + 2 * width)
                      for i in range(count)]
            if node.shape != b'tripleoctagon':
                points3 = points2
            def cmd():
                pygame.draw.polygon(self.screen, bgcolor, points3, 0)
            bkgndcommands.append(cmd)
            def cmd():
                pygame.draw.polygon(self.screen, fgcolor, points, 1)
                pygame.draw.polygon(self.screen, fgcolor, points2, 1)
                pygame.draw.polygon(self.screen, fgcolor, points3, 1)
            commands.append(cmd)
        elif node.shape in GONS:
            count = GONS[node.shape]
            points = [ellipse((2 * math.pi) / float(count) * i, center, boxwidth, boxheight)
                      for i in range(count)]
            def cmd():
                pygame.draw.polygon(self.screen, bgcolor, points, 0)
            bkgndcommands.append(cmd)
            def cmd():
                pygame.draw.polygon(self.screen, fgcolor, points, 1)
            commands.append(cmd)

        elif node.shape in (b'none', b'plain', b'plaintext'):
            pass
        return bkgndcommands, commands

    def draw_commands(self):
        nodebkgndcmd = []
        nodecmd = []
        for node in self.visiblenodes:
            cmd1, cmd2 = self.draw_node_commands(node)
            nodebkgndcmd += cmd1
            nodecmd += cmd2

        edgebodycmd = []
        edgeheadcmd = []
        for edge in self.visibleedges:

            fgcolor = getcolor(edge.color, (0,0,0))
            if edge.highlight:
                fgcolor = highlight_color(fgcolor)
            points = [self.map(*xy) for xy in edge.bezierpoints()]

            def drawedgebody(points=points, fgcolor=fgcolor, width=edge.linewidth):
                pygame.draw.lines(self.screen, fgcolor, False, points, width)
            edgebodycmd.append(drawedgebody)

            points = [self.map(*xy) for xy in edge.arrowhead()]
            if points:
                def drawedgehead(points=points, fgcolor=fgcolor):
                    pygame.draw.polygon(self.screen, fgcolor, points, 0)
                edgeheadcmd.append(drawedgehead)

            if edge.label:
                x, y = self.map(edge.xl, edge.yl)
                img = TextSnippet(self, edge.label, (0, 0, 0))
                w, h = img.get_size()
                if self.visible(x-w//2, y-h//2, x+w//2, y+h//2):
                    def drawedgelabel(img=img, x1=x-w//2, y1=y-h//2):
                        img.draw(x1, y1)
                    edgeheadcmd.append(drawedgelabel)

        return edgebodycmd + nodebkgndcmd + edgeheadcmd + nodecmd

    def draw_record_commands(self, node):
        xcenter, ycenter = self.map(node.x, node.y)
        boxwidth = int(node.w * self.scale)
        boxheight = int(node.h * self.scale)
        fgcolor = getcolor(node.color, (0,0,0))
        bgcolor = getcolor(node.fillcolor, (255,255,255))
        if node.highlight:
            fgcolor = highlight_color(fgcolor)
            bgcolor = highlight_color(bgcolor)

        text = node.label

        img = TextSnippetRecordLR.make(self, text, (boxwidth, boxheight), fgcolor, bgcolor)
        wmax, hmax = img.get_size()
        xleft = xcenter - boxwidth//2
        ytop = ycenter - boxheight//2
        def cmd(img=img, y=0):
            img.draw(xleft, ytop+y)
        commands = [cmd]
        bkgndcommands = []

        x = xcenter-boxwidth//2
        y = ycenter-boxheight//2

        # draw box
        rect = (x-1, y-1, boxwidth+2, boxheight+2)
        if rect[0] < 0:
            rect = (0, y-1, boxwidth+2 + x-1, boxheight+2)
        if rect[1] < 0:
            rect = (rect[0], 0, rect[2], boxheight+2 + y-1)
        def cmd():
            self.screen.fill(bgcolor, rect)
        bkgndcommands.append(cmd)
        def cmd():
            pygame.draw.rect(self.screen, fgcolor, rect, 1)
        commands.append(cmd)
        return bkgndcommands, commands

    def render(self):
        self.computevisible()

        bbox = self.getboundingbox()
        ox, oy, width, height = bbox
        dpy_width, dpy_height = self.screen.get_size()
        # some versions of the SDL misinterpret widely out-of-range values,
        # so clamp them
        if ox < 0:
            width += ox
            ox = 0
        if oy < 0:
            height += oy
            oy = 0
        if width > dpy_width:
            width = dpy_width
        if height > dpy_height:
            height = dpy_height
        self.screen.fill((224, 255, 224), (ox, oy, width, height))

        # gray off-bkgnd areas
        gray = (128, 128, 128)
        if ox > 0:
            self.screen.fill(gray, (0, 0, ox, dpy_height))
        if oy > 0:
            self.screen.fill(gray, (0, 0, dpy_width, oy))
        w = dpy_width - (ox + width)
        if w > 0:
            self.screen.fill(gray, (dpy_width-w, 0, w, dpy_height))
        h = dpy_height - (oy + height)
        if h > 0:
            self.screen.fill(gray, (0, dpy_height-h, dpy_width, h))

        # draw the graph and record the position of texts
        del self.textzones[:]
        for cmd in self.draw_commands():
            cmd()

    def findall(self, searchstr):
        """Return an iterator for all nodes and edges that contain a searchstr.
        """
        for item in self.graphlayout.nodes.values():
            if item.label and searchstr in item.label:
                yield item
        for item in self.graphlayout.edges:
            if item.label and searchstr in item.label:
                yield item

    def at_position(self, p):
        """Figure out the word under the cursor."""
        x, y = p
        for rx, ry, rw, rh, word in self.textzones:
            if rx <= x < rx+rw and ry <= y < ry+rh:
                return word
        return None

    def node_at_position(self, p):
        """Return the Node under the cursor."""
        x, y = p
        x, y = self.revmap(x, y)
        for node in self.visiblenodes:
            if 2.0*abs(x-node.x) <= node.w and 2.0*abs(y-node.y) <= node.h:
                return node
        return None

    def edge_at_position(self, p, distmax=14):
        """Return the Edge near the cursor."""
        x, y = p
        # XXX this function is very CPU-intensive and makes the display kinda sluggish
        distmax /= self.scale
        xy = self.revmap(x, y)
        closest_edge = None
        for edge in self.visibleedges:
            pts = edge.bezierpoints()
            for i in range(1, len(pts)):
                d = segmentdistance(pts[i-1], pts[i], xy)
                if d < distmax:
                    distmax = d
                    closest_edge = edge
        return closest_edge


class TextSnippet:
    
    def __init__(self, renderer, text, fgcolor, bgcolor=None, font=None):
        fgcolor = ensure_readable(fgcolor, bgcolor)
        self.renderer = renderer
        self.imgs = []
        self.parts = []
        if font is None:
            font = renderer.font
        if font is None:
            return
        parts = self.parts
        for word in re_nonword.split(text):
            if not word:
                continue
            if word in renderer.highlightwords:
                fg, bg = renderer.wordcolor(word)
                bg = bg or bgcolor
            else:
                fg, bg = fgcolor, bgcolor
            parts.append((word, fg, bg))
        # consolidate sequences of words with the same color
        for i in range(len(parts)-2, -1, -1):
            if parts[i][1:] == parts[i+1][1:]:
                word, fg, bg = parts[i]
                parts[i] = word + parts[i+1][0], fg, bg
                del parts[i+1]
        # delete None backgrounds
        for i in range(len(parts)):
            if parts[i][2] is None:
                parts[i] = parts[i][:2]
        # render parts
        i = 0
        while i < len(parts):
            part = parts[i]
            word = part[0]
            try:
                img = font.render(word, True, *part[1:])
            except pygame.error:
                del parts[i]   # Text has zero width
            else:
                self.imgs.append(img)
                i += 1

    def get_size(self):
        if self.imgs:
            sizes = [img.get_size() for img in self.imgs]
            return sum([w for w,h in sizes]), max([h for w,h in sizes])
        else:
            return 0, 0

    def draw(self, x, y):
        for part, img in zip(self.parts, self.imgs):
            word = part[0]
            self.renderer.screen.blit(img, (x, y))
            w, h = img.get_size()
            self.renderer.textzones.append((x, y, w, h, word))
            x += w


def record_to_nested_lists(s):
    try:
        # Python 2
        from HTMLParser import HTMLParser
        unescape = HTMLParser().unescape
    except ImportError:
        # Python 3
        from html import unescape
    def delimit_string():
        curr.append(unescape("".join(curr_string).strip("\n")))
        del curr_string[:]
    curr = []
    stack = []
    curr_string = []
    index = 0
    prev = ''
    while index < len(s):
        char = s[index]
        if char == "|":
            if prev != '}':
                delimit_string()
        elif char == "{":
            if prev == "\\":
                curr_string[-1] = "{"
            else:
                stack.append(curr)
                curr = []
        elif char == "}":
            if prev == "\\":
                curr_string[-1] = "}"
            else:
                delimit_string()
                stack[-1].append(curr)
                curr = stack.pop()
        elif char == "<":
            index = s.find(">", index) + 1
            if index == 0:
                assert 0
            else:
                prev = ">"
                continue
        else:
            curr_string.append(char)
        index += 1
        prev = char
    if curr_string or prev == "|":
        delimit_string()
    assert not stack
    return curr


class TextSnippetRecordLR:
    def __init__(self, renderer, snippets, fgcolor, bgcolor=None, font=None):
        if font is None:
            font = renderer.font
        self.snippets = snippets
        self.renderer = renderer
        self.fgcolor = fgcolor

    @staticmethod
    def make(renderer, s, bbox, fgcolor, bgcolor=None, font=None):
        fgcolor = ensure_readable(fgcolor, bgcolor)
        l = record_to_nested_lists(s)
        res = TextSnippetRecordLR.make_from_list(renderer, l, fgcolor, bgcolor, font)
        res._compute_offsets(bbox)
        return res

    @classmethod
    def make_from_list(cls, renderer, l, fgcolor, bgcolor, font):
        snippets = []
        for element in l:
            if isinstance(element, list):
                snippets.append(cls.othercls.make_from_list(renderer, element, fgcolor, bgcolor, font))
            else:
                snippets.append(TextSnippet(renderer, element, fgcolor, bgcolor, font))
        return cls(renderer, snippets, fgcolor, bgcolor, font)

    def get_size(self):
        if self.snippets:
            sizes = [img.get_size() for img in self.snippets]
            return sum([w for w,h in sizes]), max([h for w,h in sizes])
        else:
            return 0, 0

    def draw(self, x, y):
        for i, img in enumerate(self.snippets):
            w, h = img.get_size()
            if not isinstance(img, TextSnippetRecordLR):
                img.draw(x + self.offsets[i] + self.spacing, y + (self.bbox[1] - h) // 2)
            else:
                img.draw(x + self.offsets[i], y)
            if i != 0:
                start = x + self.offsets[i], y
                end = x + self.offsets[i], y + self.bbox[1]
                pygame.draw.line(self.renderer.screen, self.fgcolor, start, end)

    def _compute_offsets(self, bbox):
        self.bbox = bbox
        width_content, height_content = self.get_size()
        width, height = bbox
        spacing = (width - width_content) / 2.0 / len(self.snippets)
        offset = 0
        offsets = []
        for i, img in enumerate(self.snippets):
            w, h = img.get_size()
            offsets.append(int(offset))
            offset += w + 2 * spacing
            if not isinstance(img, TextSnippet):
                img._compute_offsets((w + 2 * spacing, height))
        self.offsets = offsets
        self.spacing = spacing

class TextSnippetRecordTD(TextSnippetRecordLR):
    othercls = TextSnippetRecordLR

    def get_size(self):
        if self.snippets:
            sizes = [img.get_size() for img in self.snippets]
            return max([w for w,h in sizes]), sum([h for w,h in sizes])
        else:
            return 0, 0

    def draw(self, x, y):
        for i, img in enumerate(self.snippets):
            w, h = img.get_size()
            if not isinstance(img, TextSnippetRecordLR):
                img.draw(x + (self.bbox[0] - w) // 2, y + self.offsets[i] + self.spacing)
            else:
                img.draw(x, y + self.offsets[i])
            if i != 0:
                start = x, y + self.offsets[i]
                end = x + self.bbox[0], y  + self.offsets[i]
                pygame.draw.line(self.renderer.screen, self.fgcolor, start, end)

    def _compute_offsets(self, bbox):
        self.bbox = bbox
        width_content, height_content = self.get_size()
        width, height = bbox
        spacing = (height - height_content) / 2.0 / len(self.snippets)
        offset = 0
        offsets = []
        for i, img in enumerate(self.snippets):
            w, h = img.get_size()
            offsets.append(int(offset))
            offset += h + 2 * spacing
            if not isinstance(img, TextSnippet):
                img._compute_offsets((width, h + 2 * spacing))
        self.offsets = offsets
        self.spacing = spacing


TextSnippetRecordLR.othercls = TextSnippetRecordTD
