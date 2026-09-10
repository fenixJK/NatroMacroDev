class nm_InlineProtocol {
	static RequestChars := 1048576
	static OutputBytes := 65536
	static Response := 2097184 ; aligned after the maximum UTF-16 request + NUL
	static Bytes := 2162736 ; response header plus 64 KiB of UTF-8 output
}
