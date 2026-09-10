class ImageObservationTestSurface {
	__New() => (this.Valid := true, this.Changed := false, this.ThrowOnSearch := false, this.Reads := 0,
		this.Result := {found: 1, x: 20, y: 30}, this.Client := {width: 801, height: 601})
	Snapshot() => this.Client
	Current(snapshot) => this.Valid
	Publish(snapshot) => this.Published := snapshot
	Search(snapshot, region, spec) {
		this.Reads++
		if this.ThrowOnSearch
			throw Error("Fixture image search failure")
		if this.Changed
			this.Valid := false
		return this.Result
	}
}

TestImageObservation() {
	for size in [[801, 601], [200, 200], [1920, 1080]] {
		for aim in ["full", "high", "low", "left", "right", "highleft", "highright", "lowright", "center", "actionbar", "buff", "abovebuff", "quest", "questbrown"] {
			region := nm_ImageObservation.Region(size[1], size[2], aim)
			if region
				Assert(region.left >= 0 && region.top >= 0 && region.right < size[1] && region.bottom < size[2], aim " remains inside client inclusive bounds")
		}
	}
	region := nm_ImageObservation.Region(801, 601, "lowright")
	Assert(region.left = 400 && region.top = 300 && region.right = 800 && region.bottom = 600, "Odd client dimensions include the final client pixel only")
	region := nm_ImageObservation.Region(200, 200, "quest")
	Assert(region.right = 199 && region.bottom = 199, "Small quest search does not extend onto desktop")
	Assert(!nm_ImageObservation.Region(200, 100, "quest"), "Quest area below a tiny client is unusable")
	AssertThrows(() => nm_ImageObservation.Region(800, 600, "typo"), "Unknown region rejected")
	DirCreate "nm_image_assets"
	FileAppend "fixture", "nm_image_assets\observation-fixture.png"
	try {
		surface := ImageObservationTestSurface()
		result := nm_ImageObservation.Find("observation-fixture.png", 30, "full", "none", surface)
		Assert(result[1] = 0 && result[2] = 20 && result[3] = 30, "Legacy found result preserves client-relative coordinates")
		Assert(surface.Published = surface.Client, "Verified geometry is published for legacy coordinate consumers")
		surface.Result := {found: 0}
		AssertEqual(nm_ImageObservation.Find("observation-fixture.png", 30, "full", "none", surface)[1], 1, "Completed no-match is distinct from observation failure")
		for mode in ["missing", "unfocused", "changed", "exception", "outside", "invalid", "region"] {
			surface := ImageObservationTestSurface(), fileName := "observation-fixture.png", aim := "full"
			switch mode {
				case "missing": fileName := "absent-fixture.png"
				case "unfocused": surface.Valid := false
				case "changed": surface.Changed := true
				case "exception": surface.ThrowOnSearch := true
				case "outside": surface.Result := {found: 1, x: 801, y: 601}
				case "invalid": surface.Result := {found: -1, x: 20, y: 30}
				case "region": surface.Client.height := 100, aim := "quest"
			}
			observationFailed := false
			try nm_ImageObservation.Find(fileName, 30, aim, "none", surface)
			catch Error
				observationFailed := true
			Assert(observationFailed, mode " never becomes successful absence or a coordinate")
			if mode = "unfocused" || mode = "region" || mode = "missing"
				AssertEqual(surface.Reads, 0, mode " rejected before native search")
		}
	} finally FileDelete "nm_image_assets\observation-fixture.png"
}

TestCombatPresence() {
	for limit in [15000, 60000] {
		presence := nm_CombatPresence(limit, true)
		Assert(!presence.Expired([], 0), "Absence starts an observation interval")
		Assert(!presence.Expired([100], limit - 1), "A full planter-like bar does not fabricate an early timeout")
		Assert(presence.Expired([], limit), "Continuous loss expires at the monotonic deadline")
		Assert(!presence.Expired([50], limit + 1), "Target reacquisition clears accumulated absence")
		Assert(!presence.Expired([], limit + 2), "New absence gets its own interval")
		Assert(!presence.Expired([], 2 * limit + 1), "Separate losses are not accumulated into a defeat")
		Assert(presence.Expired([], 2 * limit + 2), "New continuous absence can end an unconfirmed search")
	}
	presence := nm_CombatPresence(60000)
	Assert(!presence.Expired([100], 0) && presence.MissingSince = -1, "Commando keeps visible full-health bars as present")
	for key in ["LastCommando", "LastMondoBuff"] {
		IniWrite 123, "settings\nm_config.ini", "Collect", key
		Assert(nm_CollectionRecovery.Begin(key), key " reserves retry before travel")
		Assert(!nm_CollectionRecovery.Begin(key), key " cannot immediately retry")
		nm_CollectionRecovery.Failed(key, "confirmation absent")
		AssertEqual(IniRead("settings\nm_config.ini", "Collect", key), 123, key " failure does not replace successful cooldown")
		Assert(!nm_CollectionRecovery.Ready(key), key " failed attempt remains deferred")
		AssertEqual(nm_CollectionRecovery.Interacted(key), TestNow, key " explicit confirmation advances cooldown")
		Assert(nm_CollectionRecovery.Ready(key), key " confirmed result clears retry reservation")
	}
}
