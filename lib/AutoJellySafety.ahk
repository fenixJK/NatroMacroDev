; Input is tied to one focused client and the geometry used for GUI-offset detection.
class nm_AutoJellyCancelled extends Error {
}
class nm_AutoJellySurface {
	static Held := false
	__New(hwnd, offset, cancelled, anchor := unset, budget := unset) {
		this.Hwnd := hwnd, this.Offset := offset, this.Cancelled := cancelled
		this.Budget := IsSet(budget) ? budget : 0
		this.Anchor := IsSet(anchor) ? anchor.Clone() : nm_ClientSnapshot(hwnd)
		if !IsInteger(offset) || !IsObject(this.Anchor) || this.Anchor.hwnd != hwnd
			throw Error("Invalid Auto-Jelly client or offset")
		this.Check()
	}
	Clock() => DllCall("GetTickCount64", "UInt64")
	Check() {
		if this.Cancelled.Call() || GetKeyState("Escape", "P")
			throw nm_AutoJellyCancelled("Auto-Jelly stopped")
		if this.Budget
			this.Budget.CheckTime()
		if !nm_WindowOwnsFocus(this.Hwnd) || !nm_SameClient(this.Anchor, nm_ClientSnapshot(this.Hwnd))
			throw Error("Roblox focus or window geometry changed. Auto-Jelly stopped.")
		return this.Anchor
	}
	Region(kind) {
		snapshot := this.Check()
		switch kind {
			case "bee": region := {x: Round(0.5*snapshot.width - 155), y: this.Offset + Round(0.425*snapshot.height - 200), w: 320, h: 140}
			case "mutation": region := {x: Round(0.5*snapshot.width - 320), y: this.Offset + Round(0.4*snapshot.height + 17), w: 210, h: 90}
			default: throw ValueError("Unknown Auto-Jelly capture region")
		}
		if region.x < 0 || region.y < 0 || region.x + region.w > snapshot.width || region.y + region.h > snapshot.height
			throw Error("Auto-Jelly result region is outside the Roblox client")
		return region
	}
	Capture(kind) {
		region := this.Region(kind), snapshot := this.Check()
		bitmap := Gdip_BitmapFromScreen(snapshot.x + region.x "|" snapshot.y + region.y "|" region.w "|" region.h)
		if bitmap <= 0
			throw Error("Could not capture Auto-Jelly result")
		try this.Check()
		catch as err {
			Gdip_DisposeImage(bitmap)
			throw err
		}
		return bitmap ; caller must release in finally
	}
	Wait(ms) {
		deadline := this.Clock() + ms
		while this.Clock() < deadline {
			this.Check()
			Sleep Min(25, Max(1, deadline - this.Clock()))
		}
		this.Check()
	}
	Click() {
		criticalBefore := A_IsCritical, modeBefore := A_CoordModeMouse, owns := false
		Critical "On"
		try {
			snapshot := this.Check()
			if this.Budget
				this.Budget.CheckClick()
			this.Region("bee"), this.Region("mutation")
			x := Round(0.5*snapshot.width + 10), y := this.Offset + Round(0.4*snapshot.height + 230)
			if x < 0 || y < 0 || x >= snapshot.width || y >= snapshot.height
				throw Error("Auto-Jelly click is outside the Roblox client")
			if GetKeyState("LButton", "P") || nm_AutoJellySurface.Held
				throw Error("Release the mouse button before starting Auto-Jelly")
			CoordMode "Mouse", "Screen"
			MouseMove snapshot.x + x, snapshot.y + y, 0
			this.Check()
			if this.Budget
				this.Budget.Reserve()
			nm_AutoJellySurface.Held := true, owns := true
			SendEvent "{LButton down}"
		} finally {
			if owns
				nm_AutoJellySurface.Release()
			CoordMode "Mouse", modeBefore
			Critical criticalBefore
		}
		this.Check()
	}
	static Release(*) {
		if this.Held {
			this.Held := false
			SendEvent "{LButton up}"
		}
	}
}
class nm_AutoJellyObservation {
	static EnglishLanguage(list) {
		Loop Parse list, "`n", "`r"
			if RegExMatch(A_LoopField, "i)^en(?:-[a-z0-9]+)*$")
				return A_LoopField
		throw Error("Mutation detection requires an installed English OCR language")
	}
	static Match(result) {
		if result != 0 && result != 1
			throw Error("Auto-Jelly image search failed; rolling stopped")
		return result = 1
	}
	static Identify(search, bees) {
		found := 0
		for bee in bees {
			for prefix in ["-", "+"] {
				if !this.Match(search.Call(prefix bee))
					continue
				if found && found.bee != bee
					throw Error("Auto-Jelly result is ambiguous; rolling stopped")
				found := {bee: bee, gifted: prefix = "+" || (found && found.gifted)}
			}
		}
		if !found
			throw Error("Could not recognize the rolled bee; rolling stopped")
		return found
	}
	static Reason(result, selected, mythicStop, giftedStop) {
		if mythicStop && InStr("|Buoyant|Fuzzy|Precise|Spicy|Tadpole|Vector|", "|" result.bee "|")
			return "mythic"
		if giftedStop && result.gifted
			return "gifted"
		for bee in selected
			if bee = result.bee
				return "selected"
		return ""
	}
}
