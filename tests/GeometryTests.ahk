TestGeometryCache() {
	snapshot := {hwnd: 1, root: 1, pid: 2, x: 100, y: 100, width: 800, height: 600, dpi: 96, monitor: 1, style: 0, exstyle: 0}
	cache := nm_GeometryCache(2000)
	cache.Put(snapshot, 36, 10000)
	Assert(cache.Read(snapshot, 11999, &offset) && offset = 36, "Verified offset reused briefly")
	Assert(!cache.Read(snapshot, 12000, &offset), "Same-size UI changes trigger periodic re-observation")
	Assert(!cache.Read(snapshot, 9999, &offset), "Backward clock never extends cache lifetime")
	for property in ["hwnd", "root", "pid", "x", "y", "width", "height", "dpi", "monitor", "style", "exstyle"] {
		changed := snapshot.Clone(), changed.%property%++
		Assert(!cache.Read(changed, 10001, &offset), "Changed " property " invalidates geometry")
	}
	snapshot.width++
	Assert(!cache.Read(snapshot, 10001, &offset), "Cache owns its snapshot copy")
	cache.Clear()
	Assert(!cache.Read(snapshot, 10001, &offset), "Cleared/failed observation is not a cached zero offset")
}

class TestInventorySurface {
	__New(observations) {
		this.observations := observations, this.Valid := true, this.Reads := 0, this.BottomReads := 0
		this.Height := 140, this.BottomMisses := 0, this.Waits := 0, this.Scrolls := []
		this.ChangeOnRead := false, this.StopAfterScrolls := 1000
		this.Client := {width: 800, height: 600, offset: 36}
	}
	Open(item) => true
	Snapshot() => this.Client.Clone()
	Current(snapshot) => this.Valid
	Bottom(snapshot) => (++this.BottomReads <= this.BottomMisses ? 0 : this.Height)
	Observe(snapshot, height, item) {
		this.Reads++
		if this.ChangeOnRead
			this.Valid := false
		return this.observations.Length ? this.observations.RemoveAt(1) : {state: "unknown"}
	}
	Scroll(snapshot, direction) {
		if !this.Valid || this.Scrolls.Length >= this.StopAfterScrolls
			return false
		this.Scrolls.Push(direction)
		return true
	}
	Wait(milliseconds) => this.Waits++
}

TestInventoryEngine() {
	surface := TestInventorySurface([{state: "found", y: 50}])
	engine := nm_InventorySearchEngine(surface)
	point := engine.Search("glitter")
	AssertEqual(point[1], 30, "Client-relative inventory x coordinate")
	AssertEqual(point[2], 276, "Inventory position includes detected top-bar offset")
	AssertEqual(engine.Outcome, "found", "Successful observation is explicit")
	surface.Height := 100, surface.Client.height := 450, surface.observations.Push({state: "found", y: 20})
	AssertEqual(engine.Search("glitter")[2], 246, "New search uses current client geometry")
	AssertEqual(surface.BottomReads, 2, "Inventory boundary is re-read even for a reused engine")

	surface := TestInventorySurface([{state: "found", y: 50}]), surface.ChangeOnRead := true
	engine := nm_InventorySearchEngine(surface)
	AssertEqual(engine.Search("glitter"), 0, "Geometry/focus change after capture rejects coordinates")
	AssertEqual(engine.Outcome, "unknown", "Invalid geometry is not evidence that an item is missing")
	surface := TestInventorySurface([{state: "missing"}, {state: "found", y: 20}]), surface.StopAfterScrolls := 2
	AssertEqual(nm_InventorySearchEngine(surface).Search("glitter"), 0, "Change during full inventory scroll aborts")
	AssertEqual(surface.Scrolls.Length, 2, "No additional scrolling after invalidation")

	surface := TestInventorySurface([{state: "missing"}, {state: "missing"}])
	engine := nm_InventorySearchEngine(surface)
	AssertEqual(engine.Search("absent", "up", 0, "", 0, 2), 0, "Missing item remains missing")
	AssertEqual(engine.Outcome, "missing", "Exhausted readable search distinguished from unavailable observation")
	AssertEqual(surface.Scrolls.Length, 1, "No scroll after final permitted search")
	AssertEqual(surface.Scrolls[1], "Up", "Configured search direction preserved")
	surface := TestInventorySurface([{state: "unknown"}, {state: "unknown"}, {state: "found", y: 5}]), surface.BottomMisses := 2
	Assert(IsObject(nm_InventorySearchEngine(surface).Search("item")), "Delayed anchors and frames can recover")
	AssertEqual(surface.Waits, 4, "Wait for each unavailable observation")
	surface := TestInventorySurface([])
	AssertEqual(nm_InventorySearchEngine(surface).Search("item"), 0, "Persistent unknown does not become a match")
	AssertEqual(surface.Reads, 40, "Unknown observation retries bounded")
	AssertEqual(surface.Scrolls.Length, 0, "No scrolling through unreadable inventory")
	surface := TestInventorySurface([]), surface.Client.width := 200
	AssertEqual(nm_InventorySearchEngine(surface).Search("item"), 0, "Too-small client fails before capture")
	AssertEqual(surface.BottomReads, 0, "No invalid-width capture")
}

TestInventoryReader() {
	token := Gdip_Startup()
	anchor := Gdip_CreateBitmap(3, 3), item := Gdip_CreateBitmap(3, 3), capture := Gdip_CreateBitmap(306, 300)
	graphics := Gdip_GraphicsFromImage(capture)
	try {
		Loop 3 {
			x := A_Index - 1
			Loop 3 {
				Gdip_SetPixel(anchor, x, A_Index - 1, 0xFF00CC00)
				Gdip_SetPixel(item, x, A_Index - 1, 0xFFCC0000)
			}
		}
		Gdip_GraphicsClear(graphics, 0xFF101010)
		Gdip_DrawImage(graphics, anchor, 2, 200, 3, 3)
		AssertEqual(nm_InventoryFrameReader.Bottom(capture, anchor), 140, "Real bottom-anchor crop height")
		Gdip_GraphicsClear(graphics, 0xFF101010)
		Gdip_DrawImage(graphics, anchor, 2, 20, 3, 3)
		Gdip_DrawImage(graphics, item, 30, 55, 3, 3)
		found := nm_InventoryFrameReader.Item(capture, anchor, item)
		AssertEqual(found.state, "found", "Real inventory image match")
		AssertEqual(found.y, 55, "Real match coordinate")
		Gdip_GraphicsClear(graphics, 0xFF101010)
		Gdip_DrawImage(graphics, anchor, 2, 20, 3, 3)
		AssertEqual(nm_InventoryFrameReader.Item(capture, anchor, item).state, "missing", "Readable absent item")
		Gdip_GraphicsClear(graphics, 0xFF101010)
		AssertEqual(nm_InventoryFrameReader.Item(capture, anchor, item).state, "unknown", "Missing anchor is unknown")
		AssertEqual(nm_InventoryFrameReader.Item(0, anchor, item).state, "unknown", "Invalid capture fails closed")
		Gdip_DrawImage(graphics, anchor, 2, 20, 3, 3)
		AssertEqual(Gdip_LockBits(capture, 0, 0, 306, 300, &stride, &scan, &locked), 0, "Lock fixture bitmap")
		try AssertEqual(nm_InventoryFrameReader.Item(capture, anchor, item).state, "unknown", "Real image-search error is unknown")
		finally Gdip_UnlockBits(capture, &locked)
	} finally {
		Gdip_DeleteGraphics(graphics)
		Gdip_DisposeImage(capture), Gdip_DisposeImage(anchor), Gdip_DisposeImage(item)
		Gdip_Shutdown(token)
	}
}
