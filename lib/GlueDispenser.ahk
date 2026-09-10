; Retry only before gumdrop input. A sent interaction is not a reward receipt.
class nm_GlueDispenser {
	static Run(surface) {
		if !nm_CollectionRecovery.Begin("LastGlueDis")
			return 0
		interacted := false, reason := "visit interrupted"
		try {
			if !this.Visit(surface, &reason)
				return 0
			stamp := nm_CollectionRecovery.Interacted("LastGlueDis")
			interacted := true
			nm_setStatus("Interacted", "Glue Dispenser; reward not verified")
			return stamp
		} finally {
			try surface.StopWalk()
			finally {
				if !interacted
					nm_CollectionRecovery.Failed("LastGlueDis", reason)
			}
		}
	}
	static Visit(surface, &reason) {
		Loop 2 {
			reason := "reset not confirmed"
			if !surface.Reset()
				return false
			reason := "inventory opening not confirmed"
			if !surface.Menu("itemmenu")
				return false
			reason := "travel did not finish"
			if !surface.Travel(A_Index) {
				if !surface.Menu("") {
					reason := "inventory closure not confirmed after travel"
					return false
				}
				continue
			}
			reason := "gumdrops not located"
			if !(item := surface.Find()) {
				if !surface.Menu("") {
					reason := "inventory closure not confirmed after search"
					return false
				}
				continue
			}
			; A failed drag can already have sent input. Do not spend again in this visit.
			reason := "gumdrop use not confirmed"
			if !surface.Use(item)
				return false
			reason := "inventory closure not confirmed after gumdrop use"
			if !surface.Menu("")
				return false
			reason := "dispenser approach did not finish"
			if !surface.Approach()
				return false
			reason := "dispenser interaction not confirmed"
			return surface.Interact()
		}
		return false
	}
}
