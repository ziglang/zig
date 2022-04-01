/************************************************************/
/***  C header subsection: operations between chars       ***/

/*** unary operations ***/

/***  binary operations ***/


#define OP_CHAR_EQ(x,y,r)	 r = ((unsigned char)(x) == (unsigned char)(y))
#define OP_CHAR_NE(x,y,r)	 r = ((unsigned char)(x) != (unsigned char)(y))
#define OP_CHAR_LE(x,y,r)	 r = ((unsigned char)(x) <= (unsigned char)(y))
#define OP_CHAR_GT(x,y,r)	 r = ((unsigned char)(x) >  (unsigned char)(y))
#define OP_CHAR_LT(x,y,r)	 r = ((unsigned char)(x) <  (unsigned char)(y))
#define OP_CHAR_GE(x,y,r)	 r = ((unsigned char)(x) >= (unsigned char)(y))

