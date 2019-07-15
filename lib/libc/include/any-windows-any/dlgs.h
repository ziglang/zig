/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _DLGSH_INCLUDED_
#define _DLGSH_INCLUDED_

#define ctlFirst 0x0400
#define ctlLast 0x04ff

#define psh1 0x0400
#define psh2 0x0401
#define psh3 0x0402
#define psh4 0x0403
#define psh5 0x0404
#define psh6 0x0405
#define psh7 0x0406
#define psh8 0x0407
#define psh9 0x0408
#define psh10 0x0409
#define psh11 0x040a
#define psh12 0x040b
#define psh13 0x040c
#define psh14 0x040d
#define psh15 0x040e
#define pshHelp psh15
#define psh16 0x040f

#define chx1 0x0410
#define chx2 0x0411
#define chx3 0x0412
#define chx4 0x0413
#define chx5 0x0414
#define chx6 0x0415
#define chx7 0x0416
#define chx8 0x0417
#define chx9 0x0418
#define chx10 0x0419
#define chx11 0x041a
#define chx12 0x041b
#define chx13 0x041c
#define chx14 0x041d
#define chx15 0x041e
#define chx16 0x041f

#define rad1 0x0420
#define rad2 0x0421
#define rad3 0x0422
#define rad4 0x0423
#define rad5 0x0424
#define rad6 0x0425
#define rad7 0x0426
#define rad8 0x0427
#define rad9 0x0428
#define rad10 0x0429
#define rad11 0x042a
#define rad12 0x042b
#define rad13 0x042c
#define rad14 0x042d
#define rad15 0x042e
#define rad16 0x042f

#define grp1 0x0430
#define grp2 0x0431
#define grp3 0x0432
#define grp4 0x0433
#define frm1 0x0434
#define frm2 0x0435
#define frm3 0x0436
#define frm4 0x0437
#define rct1 0x0438
#define rct2 0x0439
#define rct3 0x043a
#define rct4 0x043b
#define ico1 0x043c
#define ico2 0x043d
#define ico3 0x043e
#define ico4 0x043f

#define stc1 0x0440
#define stc2 0x0441
#define stc3 0x0442
#define stc4 0x0443
#define stc5 0x0444
#define stc6 0x0445
#define stc7 0x0446
#define stc8 0x0447
#define stc9 0x0448
#define stc10 0x0449
#define stc11 0x044a
#define stc12 0x044b
#define stc13 0x044c
#define stc14 0x044d
#define stc15 0x044e
#define stc16 0x044f
#define stc17 0x0450
#define stc18 0x0451
#define stc19 0x0452
#define stc20 0x0453
#define stc21 0x0454
#define stc22 0x0455
#define stc23 0x0456
#define stc24 0x0457
#define stc25 0x0458
#define stc26 0x0459
#define stc27 0x045a
#define stc28 0x045b
#define stc29 0x045c
#define stc30 0x045d
#define stc31 0x045e
#define stc32 0x045f

#define lst1 0x0460
#define lst2 0x0461
#define lst3 0x0462
#define lst4 0x0463
#define lst5 0x0464
#define lst6 0x0465
#define lst7 0x0466
#define lst8 0x0467
#define lst9 0x0468
#define lst10 0x0469
#define lst11 0x046a
#define lst12 0x046b
#define lst13 0x046c
#define lst14 0x046d
#define lst15 0x046e
#define lst16 0x046f

#define cmb1 0x0470
#define cmb2 0x0471
#define cmb3 0x0472
#define cmb4 0x0473
#define cmb5 0x0474
#define cmb6 0x0475
#define cmb7 0x0476
#define cmb8 0x0477
#define cmb9 0x0478
#define cmb10 0x0479
#define cmb11 0x047a
#define cmb12 0x047b
#define cmb13 0x047c
#define cmb14 0x047d
#define cmb15 0x047e
#define cmb16 0x047f

#define edt1 0x0480
#define edt2 0x0481
#define edt3 0x0482
#define edt4 0x0483
#define edt5 0x0484
#define edt6 0x0485
#define edt7 0x0486
#define edt8 0x0487
#define edt9 0x0488
#define edt10 0x0489
#define edt11 0x048a
#define edt12 0x048b
#define edt13 0x048c
#define edt14 0x048d
#define edt15 0x048e
#define edt16 0x048f

#define scr1 0x0490
#define scr2 0x0491
#define scr3 0x0492
#define scr4 0x0493
#define scr5 0x0494
#define scr6 0x0495
#define scr7 0x0496
#define scr8 0x0497

#define ctl1 0x04A0

#define FILEOPENORD 1536
#define MULTIFILEOPENORD 1537
#define PRINTDLGORD 1538
#define PRNSETUPDLGORD 1539
#define FINDDLGORD 1540
#define REPLACEDLGORD 1541
#define FONTDLGORD 1542
#define FORMATDLGORD31 1543
#define FORMATDLGORD30 1544
#define RUNDLGORD 1545

#define PAGESETUPDLGORD 1546
#define NEWFILEOPENORD 1547
#define PRINTDLGEXORD 1549
#define PAGESETUPDLGORDMOTIF 1550
#define COLORMGMTDLGORD 1551
#define NEWFILEOPENV2ORD 1552

typedef struct tagCRGB {
  BYTE bRed;
  BYTE bGreen;
  BYTE bBlue;
  BYTE bExtra;
} CRGB;
#endif
