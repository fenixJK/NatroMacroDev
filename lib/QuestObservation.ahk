; 1 = positively complete, 0 = incomplete, -1 = unknown. Action availability
; does not alter observed completion; the former deferred value 2 is not complete.
class nm_QuestObservation {
	static Aggregate(rows, expected, recognized := true) {
		if !recognized || expected < 1 || rows.Length != expected
			return -1
		incomplete := false
		for value in rows {
			if value != 0 && value != 1
				return -1
			incomplete := incomplete || value = 0
		}
		return incomplete ? 0 : 1
	}
	static Label(value) => value = 1 ? "Complete" : value = 0 ? "Incomplete" : "Unknown"
	static Color(rgb) {
		; Explicit completed background observed in NatroTeam/NatroMacro issue 971.
		; Border, title, text, overlays and unrecognized colors are not completion.
		return rgb = 0x96D88D ? 1 : (rgb = 0xF46C55 || rgb = 0x6EFF60) ? 0 : -1
	}
	static Row(capture, y, inset, anchor) {
		if capture <= 0 || anchor <= 0 || y < 0 || y + 40 > Gdip_GetImageHeight(capture)
			return -1
		if Gdip_ImageSearch(capture, anchor, , 0, y, 6, y + 40, 5) != 1
			return -1
		complete := incomplete := 0
		Loop 3 {
			dy := A_Index + 3
			Loop 3 {
				pixel := 0
				if DllCall("gdiplus\GdipBitmapGetPixel", "Ptr", capture, "Int", inset + 8 + A_Index, "Int", y + dy, "UInt*", &pixel)
					return -1
				value := this.Color(pixel & 0xFFFFFF)
				complete += value = 1, incomplete += value = 0
			}
		}
		return complete >= 7 ? 1 : incomplete >= 7 ? 0 : -1
	}
	static Frame(capture, count, templates, anchor, inset := 16, step := 50, gap := 10, objectives := 0, assets := 0) {
		rows := []
		Loop count
			rows.Push(-1)
		if capture <= 0 || count < 1 || Gdip_GetImageWidth(capture) < 306 || Gdip_GetImageHeight(capture) < 30 + count * step
			return rows
		recognized := false
		for template in templates
			if template > 0 && Gdip_ImageSearch(capture, template, , 0, 0, 306, 30, 10) = 1 {
				recognized := true
				break
			}
		if !recognized
			return rows
		if IsObject(objectives) && count < 4 {
			; Brown's dynamically recognized row count needs a fresh endpoint in
			; this same frame, not an earlier observation made before scrolling.
			endpoint := false, endpointY := 30 + gap + count * step
			if Gdip_GetImageHeight(capture) < endpointY + 40
				return rows
			for key in ["questbartitle", "questbartitlebeesmas"]
				if assets.Has(key) && Gdip_ImageSearch(capture, assets[key], , 0, endpointY, 6, endpointY + 40, 5) = 1 {
					endpoint := true
					break
				}
			if !endpoint
				return rows
		}
		observed := []
		Loop count {
			rowIndex := A_Index, y := 30 + gap + (rowIndex - 1) * step
			value := nm_QuestObservation.Row(capture, y, inset, anchor)
			if IsObject(objectives) {
				matched := false
				for size in [16, 15, 14, 18, 17] {
					key := "s" size objectives[rowIndex]
					if assets.Has(key) && Gdip_ImageSearch(capture, assets[key], , 6, y, 304, y + 40, 30) = 1 {
						matched := true
						break
					}
				}
				if !matched
					value := -1
			}
			observed.Push(value)
		}
		return observed
	}

}

; Re-capture the title and all rows together, after scrolling has finished. A
; guessed scroll distance or stale global quest name cannot establish completion.
nm_ReadQuestRows(hwnd, startY, count, title, objectives := 0) {
	global bitmaps, QuestBarInset, QuestBarSize, QuestBarGapSize
	rows := []
	Loop count
		rows.Push(-1)
	snapshot := nm_ClientSnapshot(hwnd)
	offset := GetYOffset(hwnd, &offsetFailed)
	if !snapshot || offsetFailed || !nm_WindowOwnsFocus(hwnd) || !nm_SameClient(snapshot, nm_ClientSnapshot(hwnd))
		return rows
	top := startY - 30, height := 30 + count * QuestBarSize
	if IsObject(objectives) && count < 4
		height += QuestBarSize
	if count < 1 || snapshot.width < 306 || top < offset + 150 || top + height > snapshot.height
		return rows
	capture := Gdip_BitmapFromScreen(snapshot.x "|" snapshot.y + top "|306|" height)
	if capture <= 0
		return rows
	templates := []
	try {
		titles := title = "Brown" ? ["brown_bear1", "brown_bear2", "brown_bear3", "brown_bear4", "brown_bear5"] : [title]
		for candidate in titles {
			template := Gdip_CreateBitmapFromFile("nm_image_assets\" candidate ".png")
			if template > 0
				templates.Push(template)
		}
		if !bitmaps.Has("questbarinset")
			return rows
		observed := nm_QuestObservation.Frame(capture, count, templates, bitmaps["questbarinset"], QuestBarInset, QuestBarSize, QuestBarGapSize, objectives, bitmaps)
		return nm_WindowOwnsFocus(hwnd) && nm_SameClient(snapshot, nm_ClientSnapshot(hwnd)) ? observed : rows
	} finally {
		for template in templates
			Gdip_DisposeImage(template)
		Gdip_DisposeImage(capture)
	}
}

; Publish a recognition failure without leaving stale completed text or actions.
nm_PublishUnknownQuest(family) {
	global
	local message := "Unknown: quest title or objective rows could not be verified."
	local setting := family "QuestProgress", keys := [], key
	if %setting% != message {
		%setting% := message
		IniWrite message, "settings\nm_config.ini", "Quests", setting
	}
	MainGui[setting].Text := message
	if family != "Honey"
		QuestGatherField := "None", QuestGatherFieldSlot := 0
	switch family {
		case "Polar": keys := ["QuestLadybugs", "QuestRhinoBeetles", "QuestSpider", "QuestMantis", "QuestScorpions", "QuestWerewolf"]
		case "Riley": keys := ["RileyLadybugs", "RileyScorpions", "RileyAll", "QuestAnt", "QuestRedBoost"]
		case "Bucko": keys := ["BuckoRhinoBeetles", "BuckoMantis", "QuestAnt", "QuestBlueBoost"]
	}
	for key in keys
		%key% := 0
	if family = "Riley" || family = "Bucko"
		QuestFeed := "None"
}
