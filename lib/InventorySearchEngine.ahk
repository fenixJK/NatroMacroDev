; Scheduling/termination logic can run against recorded observations without input.
class nm_InventorySearchEngine {
	__New(surface) => this.Surface := surface
	Search(item, direction := "down", prescroll := 0, prescrolldir := "", scrolltoend := 1, max := 70) {
		this.Outcome := "unknown"
		if max < 1 || !this.Surface.Open(item) || !(snapshot := this.Surface.Snapshot())
			return 0
		if snapshot.width < 306 || snapshot.height - snapshot.offset < 230
			return 0
		; Re-read the visible boundary for every search, even with the same HWND.
		height := 0
		Loop 40 {
			if !this.Surface.Current(snapshot)
				return 0
			if height := this.Surface.Bottom(snapshot)
				break
			this.Surface.Wait(50)
		}
		if height <= 0 || height > snapshot.height - snapshot.offset - 150
			return 0
		Loop max {
			attempt := A_Index, observation := 0
			Loop 40 {
				if !this.Surface.Current(snapshot)
					return 0
				observation := this.Surface.Observe(snapshot, height, item)
				if observation.state != "unknown"
					break
				this.Surface.Wait(50)
			}
			if !IsObject(observation) || observation.state = "unknown" || !this.Surface.Current(snapshot)
				return 0
			if observation.state = "found" {
				y := observation.y + snapshot.offset + 190
				if y < 0 || y >= snapshot.height
					return 0
				this.Outcome := "found"
				return [30, y] ; client-relative, including the observed top-bar offset
			}
			if attempt >= max {
				this.Outcome := "missing"
				return 0 ; no unobserved scroll after the final search
			}
			if attempt = prescroll + 1 && scrolltoend {
				Loop 100
					if !this.Surface.Scroll(snapshot, direction = "down" ? "Up" : "Down")
						return 0
			} else {
				scrollDirection := attempt <= prescroll && prescrolldir ? prescrolldir : direction
				if !this.Surface.Scroll(snapshot, scrollDirection = "down" ? "Down" : "Up")
					return 0
			}
			this.Surface.Wait(500)
		}
		return 0
	}
}

class nm_InventoryFrameReader {
	static Bottom(capture, anchor) {
		if capture <= 0 || anchor <= 0 || Gdip_ImageSearch(capture, anchor, &pos, , , 6, , 2, , 2) != 1
			return 0
		xy := StrSplit(pos, ",")
		return Max(0, Integer(xy[2]) - 60)
	}
	static Item(capture, anchor, item) {
		if capture <= 0 || anchor <= 0 || item <= 0 || Gdip_ImageSearch(capture, anchor, , , , 6, , 2) != 1
			return {state: "unknown"}
		result := Gdip_ImageSearch(capture, item, &pos, , , , , 10, , 5)
		if result = 0
			return {state: "missing"}
		if result != 1
			return {state: "unknown"}
		xy := StrSplit(pos, ",")
		return {state: "found", y: Integer(xy[2])}
	}
}
