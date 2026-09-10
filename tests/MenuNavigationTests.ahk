TestMenuNavigation() {
	for sample in [
		["itemmenu", 0, ["itemmenu"], 0, "opened"],
		["itemmenu", 0, ["", "", "itemmenu"], 1, "opened"],
		["questlog", 0, ["beemenu", "questlog"], 1, "opened"],
		["", 0, ["shopmenu", ""], 1, "closed"],
		["itemmenu", 1, ["itemmenu", ""], 1, "closed"],
		["", 0, [""], 0, "closed"]] {
		surface := MenuNavigationFixture(sample[3]), engine := nm_MenuNavigation(surface)
		AssertEqual(engine.Run(sample[1], sample[2]), 1, "Requested menu state confirmed")
		AssertEqual(surface.Clicks.Length, sample[4], "Only the necessary click is sent")
		AssertEqual(engine.Outcome, sample[5], "Successful menu outcome is explicit")
		AssertEqual(surface.Closed, 1, "Menu input cleanup runs on success")
	}
	for observations in [["unknown"], ["", "unknown"], ["beemenu", "shopmenu"]] {
		surface := MenuNavigationFixture(observations), engine := nm_MenuNavigation(surface)
		AssertEqual(engine.Run("itemmenu"), 0, "Unknown or unexpected state is not permission to keep clicking")
		Assert(surface.Clicks.Length <= 1, "No repeated toggle on uncertainty")
		AssertEqual(surface.Closed, 1, "Failure releases operation resources")
	}
	surface := MenuNavigationFixture([""]), engine := nm_MenuNavigation(surface)
	AssertEqual(engine.Run("itemmenu", 0, 300), 0, "A click alone is not menu-open success")
	AssertEqual(engine.Outcome, "timeout", "Unchanged menu reaches shared deadline")
	AssertEqual(surface.Clicks.Length, 1, "Timeout does not resend toggles")
	AssertEqual(surface.Tick, 300, "Waits respect remaining deadline")
	surface := MenuNavigationFixture(["itemmenu"]), surface.ReadTime := 301
	AssertEqual(nm_MenuNavigation(surface).Run("itemmenu", 0, 300), 0, "Late observation cannot establish success")
	AssertEqual(surface.Clicks.Length, 0, "No late input")
	for property in ["Ready", "Current", "ClickOk"] {
		surface := MenuNavigationFixture(["", "itemmenu"]), surface.%property% := false
		AssertEqual(nm_MenuNavigation(surface).Run("itemmenu"), 0, "Rejected menu surface stops: " property)
		AssertEqual(surface.Closed, 1, "Rejected operation cleanup")
	}
	surface := MenuNavigationFixture([""]), surface.Throws := true
	AssertEqual(nm_MenuNavigation(surface).Run("itemmenu"), 0, "Capture exception fails closed")
	AssertEqual(surface.Closed, 1, "Exception releases operation resources")
	surface := MenuNavigationFixture([""])
	AssertEqual(nm_MenuNavigation(surface).Run("unknown-tab"), 0, "Unknown tab rejected before window access")
	AssertEqual(surface.Prepared, 0, "Invalid request never prepares input")
	for statuses in [Map("itemmenu", -100), Map("itemmenu", 1, "questlog", 1)]
		Assert(!nm_MenuFrameReader.Read((tab) => statuses.Has(tab) ? statuses[tab] : 0).valid, "Search error or ambiguous selected tabs is unknown")
}

class MenuNavigationFixture {
	__New(tabs) {
		this.Tabs := tabs.Clone(), this.Last := "", this.Clicks := [], this.Tick := this.ReadTime := this.Closed := this.Prepared := 0
		this.Ready := this.Current := this.ClickOk := true, this.Throws := false
	}
	Clock() => this.Tick
	Prepare(deadline) => (++this.Prepared && this.Ready)
	Observe() {
		if this.Throws
			throw Error("Injected menu observation failure")
		this.Tick += this.ReadTime
		if this.Tabs.Length
			this.Last := this.Tabs.RemoveAt(1)
		return {valid: this.Last != "unknown", tab: this.Last}
	}
	Fresh(frame) => this.Current
	Click(frame, tab) => (this.Clicks.Push(tab) && this.ClickOk)
	Wait(ms) => this.Tick += ms
	Close() => this.Closed++
}

TestMenuTemplates() {
	local bitmaps := Map()
	token := Gdip_Startup(), capture := graphics := 0
	try {
		#Include "%A_ScriptDir%\..\nm_image_assets\general\menu_bitmaps.ahk"
		AssertEqual(bitmaps.Count, 6, "All six menu templates shared with generated workers")
		capture := Gdip_CreateBitmap(350, 80), graphics := Gdip_GraphicsFromImage(capture)
		for tab, bitmap in bitmaps {
			Gdip_GraphicsClear(graphics, 0xff335577)
			AssertEqual(Gdip_DrawImage(graphics, bitmap, 10, 10), 0, "Render actual menu template")
			frame := nm_MenuFrameReader.Read((key) => Gdip_ImageSearch(capture, bitmaps[key],,,,,, 2))
			Assert(frame.valid && frame.tab = tab, "Actual menu template uniquely identifies " tab)
		}
		Gdip_GraphicsClear(graphics, 0xff335577)
		frame := nm_MenuFrameReader.Read((key) => Gdip_ImageSearch(capture, bitmaps[key],,,,,, 2))
		Assert(frame.valid && frame.tab = "", "Readable frame with no selected template reports no selected tab")
	} finally {
		if graphics
			Gdip_DeleteGraphics(graphics)
		if capture
			Gdip_DisposeImage(capture)
		for key, bitmap in bitmaps
			Gdip_DisposeImage(bitmap)
		Gdip_Shutdown(token)
	}
}
