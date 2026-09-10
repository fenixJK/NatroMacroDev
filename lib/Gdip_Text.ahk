; Color options are ARGB values. A supplied Brush is explicitly borrowed.
class Gdip_TextRenderer {
	static Draw(pGraphics, Text, Options, Font := "Arial", Width := "", Height := "", Measure := 0, Brush := 0, api := unset) {
		IWidth := Width
		IHeight := Height
		Text := String(Text)


		pattern_opts := "i)"
		RegExMatch(Options, pattern_opts "X([\-\d\.]+)(p*)", &xpos:="")
		RegExMatch(Options, pattern_opts "Y([\-\d\.]+)(p*)", &ypos:="")
		RegExMatch(Options, pattern_opts "W([\-\d\.]+)(p*)", &Width:="")
		RegExMatch(Options, pattern_opts "H([\-\d\.]+)(p*)", &Height:="")
		RegExMatch(Options, pattern_opts "C(?!(entre|enter))([a-f\d]+)", &Colour:="")
		RegExMatch(Options, pattern_opts "Top|Up|Bottom|Down|vCentre|vCenter", &vPos:="")
		RegExMatch(Options, pattern_opts "NoWrap", &NoWrap:="")
		RegExMatch(Options, pattern_opts "R(\d)", &Rendering:="")
		RegExMatch(Options, pattern_opts "S(\d+)(p*)", &Size:="")

		if !(IWidth && IHeight) && ((xpos && xpos[2]) || (ypos && ypos[2]) || (Width && Width[2]) || (Height && Height[2]) || (Size && Size[2])) {
			return -1
		}

		Style := 0
		Styles := "Regular|Bold|Italic|BoldItalic|Underline|Strikeout"
		for eachStyle, valStyle in StrSplit( Styles, "|" ) {
			if RegExMatch(Options, "\b" valStyle)
				Style |= (valStyle != "StrikeOut") ? (A_Index-1) : 8
		}

		Align := 0
		Alignments := "Near|Left|Centre|Center|Far|Right"
		for eachAlignment, valAlignment in StrSplit( Alignments, "|" ) {
			if RegExMatch(Options, "\b" valAlignment) {
				Align |= A_Index*10//21	; 0|0|1|1|2|2
			}
		}

		xpos := (xpos && (xpos[1] != "")) ? xpos[2] ? IWidth*(xpos[1]/100) : xpos[1] : 0
		ypos := (ypos && (ypos[1] != "")) ? ypos[2] ? IHeight*(ypos[1]/100) : ypos[1] : 0
		Width := (Width && Width[1]) ? Width[2] ? IWidth*(Width[1]/100) : Width[1] : IWidth
		Height := (Height && Height[1]) ? Height[2] ? IHeight*(Height[1]/100) : Height[1] : IHeight

		if Colour && StrLen(Colour[2]) > 8
			return -6
		Colour := Colour ? Integer("0x" Colour[2]) : 0xff000000
		if Brush && (!IsInteger(Brush) || Brush < 0)
			return -6
		if !pGraphics
			return -2

		Rendering := (Rendering && (Rendering[1] >= 0) && (Rendering[1] <= 5)) ? Rendering[1] : 4
		Size := (Size && (Size[1] > 0)) ? Size[2] ? IHeight*(Size[1]/100) : Size[1] : 12

		api := IsSet(api) ? api : Gdip_TextApi()
		hFamily := hFont := hFormat := ownedBrush := 0, result := -7, clean := true
		try {
			if !(hFamily := api.Family(Font))
				return -3
			if !(hFont := api.Font(hFamily, Size, Style))
				return -4
			if !(hFormat := api.Format(NoWrap ? 0x5000 : 0x4000))
				return -5
			if !Brush && !(ownedBrush := api.Brush(Colour))
				return -6
			pBrush := Brush ? Brush : ownedBrush
			CreateRectF(&RC, xpos, ypos, Width, Height)
			if api.Align(hFormat, Align) || api.Rendering(pGraphics, Rendering)
				return -7
			if !(ReturnRC := api.Measure(pGraphics, Text, hFont, hFormat, &RC))
				return -7
			if vPos {
				bounds := StrSplit(ReturnRC, "|")
				if (vPos[0] = "vCentre") || (vPos[0] = "vCenter")
					ypos += Floor(Height-bounds[4])//2
				else if (vPos[0] = "Top") || (vPos[0] = "Up")
					ypos := 0
				else if (vPos[0] = "Bottom") || (vPos[0] = "Down")
					ypos := Height-bounds[4]
				CreateRectF(&RC, xpos, ypos, Width, bounds[4])
				if !(ReturnRC := api.Measure(pGraphics, Text, hFont, hFormat, &RC))
					return -7
			}
			if !Measure && api.Draw(pGraphics, Text, hFont, hFormat, pBrush, &RC)
				return -7
			result := ReturnRC
		} catch {
			result := -7
		} finally {
			; Each release is attempted even if another one reports an error.
			for entry in [[ownedBrush, "DeleteBrush"], [hFormat, "DeleteFormat"], [hFont, "DeleteFont"], [hFamily, "DeleteFamily"]] {
				if !entry[1]
					continue
				try {
					if api.%entry[2]%(entry[1])
						clean := false
				} catch {
					clean := false
				}
			}
		}
		return clean ? result : -7
	}
}
class Gdip_TextApi {
	Family(name) => Gdip_FontFamilyCreate(name)
	Font(family, size, style) => Gdip_FontCreate(family, size, style)
	Format(flags) => Gdip_StringFormatCreate(flags)
	Brush(color) => Gdip_BrushCreateSolid(color)
	Align(formatHandle, align) => Gdip_SetStringFormatAlign(formatHandle, align)
	Rendering(graphics, hint) => Gdip_SetTextRenderingHint(graphics, hint)
	Measure(graphics, text, font, formatHandle, &rect) => Gdip_MeasureString(graphics, text, font, formatHandle, &rect)
	Draw(graphics, text, font, formatHandle, brush, &rect) => Gdip_DrawString(graphics, text, font, formatHandle, brush, &rect)
	DeleteBrush(brush) => Gdip_DeleteBrush(brush)
	DeleteFormat(formatHandle) => Gdip_DeleteStringFormat(formatHandle)
	DeleteFont(font) => Gdip_DeleteFont(font)
	DeleteFamily(family) => Gdip_DeleteFontFamily(family)
}
