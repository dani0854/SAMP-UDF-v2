class SampPattern extends ThrowsNonexistent {
	static module := "samp.dll"

	static FUNC_SAMP_ADDTOCHATWND := Array(Object("pattern", "xx8Bxx83xxxx81xxxxxxxxxxxx33xxB9xxxxxxxx8DxxxxxxF3xx8Bxxxx8Dxxxxxxxx8DxxxxxxxxE8xxxxxxxx8Axxxxxx83xxxx84xx8Dxxxxxx74xxEBxx8Dxxxx8Axx84xx7Exx80xxxx7DxxC6xxxx8Axxxxxx84xx75xx8Bxxxx8B812A0100006A"))
	static ADDR_SAMP_CHATMSG_PTR_PTR := Array(Object("pattern", "8B15xxxxxxxx68xxxxxxxx52E8xxxxxxxx83C4085F5E"
												   , "offset",  0x2))
}