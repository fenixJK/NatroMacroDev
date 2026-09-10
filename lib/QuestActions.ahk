; Quest consumers require explicit observed states. Unknown does not turn in or count a quest.

nm_PolarQuest(){
	global PolarQuestCheck, PolarQuest, PolarQuestComplete, QuestGatherField, QuestLadybugs, QuestRhinoBeetles, QuestSpider, QuestMantis, QuestScorpions, QuestWerewolf, LastBugrunLadybugs, LastBugrunRhinoBeetles, LastBugrunSpider, LastBugrunMantis, LastBugrunScorpions, LastBugrunWerewolf, MonsterRespawnTime, RotateQuest, TotalQuestsComplete, SessionQuestsComplete
	if(!PolarQuestCheck)
		return
	nm_setShiftLock(0)
	RotateQuest:="Polar"
	nm_PolarQuestProg()
	if(PolarQuestComplete = 1) {
		nm_updateAction("Quest")
		nm_gotoQuestgiver("Polar")
		nm_PolarQuestProg()
		if(PolarQuestComplete = 0){
			nm_setStatus("Starting", "Polar Quest: " . PolarQuest)
			TotalQuestsComplete:=TotalQuestsComplete+1
			SessionQuestsComplete:=SessionQuestsComplete+1
			PostSubmacroMessage("StatMonitor", 0x5555, 5, 1)
			IniWrite TotalQuestsComplete, "settings\nm_config.ini", "Status", "TotalQuestsComplete"
			IniWrite SessionQuestsComplete, "settings\nm_config.ini", "Status", "SessionQuestsComplete"
		}
	}
	;do quest stuff
	if(PolarQuestComplete = 0) {
		if ((QuestLadybugs && (nowUnix()-LastBugrunLadybugs)>floor(330*(1-(MonsterRespawnTime?MonsterRespawnTime:0)*0.01))) || (QuestRhinoBeetles && (nowUnix()-LastBugrunRhinoBeetles)>floor(330*(1-(MonsterRespawnTime?MonsterRespawnTime:0)*0.01))) || (QuestSpider && (nowUnix()-LastBugrunSpider)>floor(1830*(1-(MonsterRespawnTime?MonsterRespawnTime:0)*0.01))) || (QuestMantis && (nowUnix()-LastBugrunMantis)>floor(1230*(1-(MonsterRespawnTime?MonsterRespawnTime:0)*0.01))) || (QuestScorpions && (nowUnix()-LastBugrunScorpions)>floor(1230*(1-(MonsterRespawnTime?MonsterRespawnTime:0)*0.01))) || (QuestWerewolf && (nowUnix()-LastBugrunWerewolf)>floor(3600*(1-(MonsterRespawnTime?MonsterRespawnTime:0)*0.01)))){
			nm_Bugrun()
		}
		if nm_NightInterrupt()
			return
		nm_PolarQuestProg()
		if(PolarQuestComplete = 1) {
			nm_updateAction("Quest")
			nm_gotoQuestgiver("Polar")
			nm_PolarQuestProg()
			if(PolarQuestComplete = 0){
				nm_setStatus("Starting", "Polar Quest: " . PolarQuest)
				TotalQuestsComplete:=TotalQuestsComplete+1
				SessionQuestsComplete:=SessionQuestsComplete+1
				PostSubmacroMessage("StatMonitor", 0x5555, 5, 1)
				IniWrite TotalQuestsComplete, "settings\nm_config.ini", "Status", "TotalQuestsComplete"
				IniWrite SessionQuestsComplete, "settings\nm_config.ini", "Status", "SessionQuestsComplete"
			}
		}
	}
}

nm_RileyQuest(){
	global RileyQuestCheck, RileyQuestComplete, RileyQuest, RotateQuest, QuestGatherField, QuestAnt, QuestRedBoost, QuestFeed, LastBugrunLadybugs, LastBugrunRhinoBeetles, LastBugrunSpider, LastBugrunMantis, LastBugrunScorpions, LastBugrunWerewolf, MonsterRespawnTime, RileyLadybugs, RileyScorpions, TotalQuestsComplete, SessionQuestsComplete
	if(!RileyQuestCheck)
		return
	RotateQuest:="Riley"
	nm_RileyQuestProg()
	if(RileyQuestComplete=1) {
		nm_updateAction("Quest")
		nm_gotoQuestgiver("Riley")
		nm_RileyQuestProg()
		if(RileyQuestComplete = 0){
			nm_setStatus("Starting", "Riley Quest: " . RileyQuest)
			TotalQuestsComplete:=TotalQuestsComplete+1
			SessionQuestsComplete:=SessionQuestsComplete+1
			PostSubmacroMessage("StatMonitor", 0x5555, 5, 1)
			IniWrite TotalQuestsComplete, "settings\nm_config.ini", "Status", "TotalQuestsComplete"
			IniWrite SessionQuestsComplete, "settings\nm_config.ini", "Status", "SessionQuestsComplete"
		}
	}
	if(RileyQuestComplete = 0){
		if(QuestFeed!="none") {
			nm_updateAction("Quest")
			nm_feed(QuestFeed)
		}
		if(QuestAnt)
			nm_Collect()
		if(QuestRedBoost)
			nm_ToAnyBooster()
		if((RileyLadybugs && (nowUnix()-LastBugrunLadybugs)>floor(330*(1-(MonsterRespawnTime?MonsterRespawnTime:0)*0.01))) || (RileyScorpions && (nowUnix()-LastBugrunScorpions)>floor(1230*(1-(MonsterRespawnTime?MonsterRespawnTime:0)*0.01)))) {
			nm_Bugrun()
		}
		if nm_NightInterrupt()
			return
		nm_RileyQuestProg()
		if(RileyQuestComplete=1) {
			nm_gotoQuestgiver("Riley")
			nm_RileyQuestProg()
			if(RileyQuestComplete = 0){
				nm_setStatus("Starting", "Riley Quest: " . RileyQuest)
				TotalQuestsComplete:=TotalQuestsComplete+1
				SessionQuestsComplete:=SessionQuestsComplete+1
				PostSubmacroMessage("StatMonitor", 0x5555, 5, 1)
				IniWrite TotalQuestsComplete, "settings\nm_config.ini", "Status", "TotalQuestsComplete"
				IniWrite SessionQuestsComplete, "settings\nm_config.ini", "Status", "SessionQuestsComplete"
			}
		}
	}
}

nm_BuckoQuest(){
	global BuckoQuestCheck, BuckoQuestComplete, BuckoQuest, RotateQuest, QuestGatherField, QuestAnt, QuestBlueBoost, QuestFeed, LastBugrunLadybugs, LastBugrunRhinoBeetles, LastBugrunSpider, LastBugrunMantis, LastBugrunScorpions, LastBugrunWerewolf, MonsterRespawnTime, BuckoRhinoBeetles, BuckoMantis, TotalQuestsComplete, SessionQuestsComplete
	if(!BuckoQuestCheck)
		return
	RotateQuest:="Bucko"
	nm_BuckoQuestProg()
	if(BuckoQuestComplete=1) {
		nm_updateAction("Quest")
		nm_gotoQuestgiver("Bucko")
		nm_BuckoQuestProg()
		if(BuckoQuestComplete = 0){
			nm_setStatus("Starting", "Bucko Quest: " . BuckoQuest)
			TotalQuestsComplete:=TotalQuestsComplete+1
			SessionQuestsComplete:=SessionQuestsComplete+1
			PostSubmacroMessage("StatMonitor", 0x5555, 5, 1)
			IniWrite TotalQuestsComplete, "settings\nm_config.ini", "Status", "TotalQuestsComplete"
			IniWrite SessionQuestsComplete, "settings\nm_config.ini", "Status", "SessionQuestsComplete"
		}
	}
	if(BuckoQuestComplete = 0){
		if(QuestFeed!="none") {
			nm_updateAction("Quest")
			nm_feed(QuestFeed)
		}
		if(QuestAnt)
			nm_Collect()
		if(QuestBlueBoost)
			nm_ToAnyBooster()
		if((BuckoRhinoBeetles && (nowUnix()-LastBugrunRhinoBeetles)>floor(330*(1-(MonsterRespawnTime?MonsterRespawnTime:0)*0.01))) || (BuckoMantis && (nowUnix()-LastBugrunMantis)>floor(1230*(1-(MonsterRespawnTime?MonsterRespawnTime:0)*0.01)))) {
			nm_Bugrun()
		}
		if nm_NightInterrupt()
			return
		nm_BuckoQuestProg()
		if(BuckoQuestComplete=1) {
			nm_gotoQuestgiver("Bucko")
			nm_BuckoQuestProg()
			if(BuckoQuestComplete = 0){
				nm_setStatus("Starting", "Bucko Quest: " . BuckoQuest)
				TotalQuestsComplete:=TotalQuestsComplete+1
				SessionQuestsComplete:=SessionQuestsComplete+1
				PostSubmacroMessage("StatMonitor", 0x5555, 5, 1)
				IniWrite TotalQuestsComplete, "settings\nm_config.ini", "Status", "TotalQuestsComplete"
				IniWrite SessionQuestsComplete, "settings\nm_config.ini", "Status", "SessionQuestsComplete"
			}
		}
	}
}

nm_BlackQuest(){
	global BlackQuestCheck, BlackQuestComplete, BlackQuest, LastBlackQuest, RotateQuest, QuestGatherField, TotalQuestsComplete, SessionQuestsComplete
	if(!BlackQuestCheck)
		return
	RotateQuest:="Black"
	nm_BlackQuestProg()
	if(BlackQuestComplete = 1 && (nowUnix()-LastBlackQuest)>3600) {
		nm_updateAction("Quest")
		nm_gotoQuestgiver("Black")
		nm_BlackQuestProg()
		if(BlackQuestComplete = 0){
			nm_setStatus("Starting", "Black Bear Quest: " . BlackQuest)
			TotalQuestsComplete:=TotalQuestsComplete+1
			SessionQuestsComplete:=SessionQuestsComplete+1
			PostSubmacroMessage("StatMonitor", 0x5555, 5, 1)
			IniWrite TotalQuestsComplete, "settings\nm_config.ini", "Status", "TotalQuestsComplete"
			IniWrite SessionQuestsComplete, "settings\nm_config.ini", "Status", "SessionQuestsComplete"
			LastBlackQuest:=nowUnix()
			IniWrite LastBlackQuest, "settings\nm_config.ini", "Quests", "LastBlackQuest"
		}
	}
}

nm_BrownQuest(){
	global BrownQuestCheck, BrownQuestComplete, BrownQuest, LastBrownQuest, RotateQuest, QuestGatherField, TotalQuestsComplete, SessionQuestsComplete
	if(!BrownQuestCheck)
		return
	RotateQuest:="Brown"
	nm_BrownQuestProg()
	if(BrownQuestComplete = 1 && (nowUnix()-LastBrownQuest)>3600) {
		nm_updateAction("Quest")
		nm_gotoQuestgiver("Brown")
		nm_BrownQuestProg()
		if(BrownQuestComplete = 0){
			nm_setStatus("Starting", "Brown Bear Quest: " . BrownQuest)
			TotalQuestsComplete:=TotalQuestsComplete+1
			SessionQuestsComplete:=SessionQuestsComplete+1
			PostSubmacroMessage("StatMonitor", 0x5555, 5, 1)
			IniWrite TotalQuestsComplete, "settings\nm_config.ini", "Status", "TotalQuestsComplete"
			IniWrite SessionQuestsComplete, "settings\nm_config.ini", "Status", "SessionQuestsComplete"
			LastBrownQuest:=nowUnix()
			IniWrite LastBrownQuest, "settings\nm_config.ini", "Quests", "LastBrownQuest"
		}
	}
}

nm_HoneyQuest() {
	global HoneyQuestCheck, HoneyQuestComplete
	if !HoneyQuestCheck
		return
	nm_HoneyQuestProg()
	if HoneyQuestComplete = 1 {
		nm_updateAction("Quest")
		nm_gotoQuestgiver("Honey")
		nm_HoneyQuestProg()
		if HoneyQuestComplete = 0
			nm_setStatus("Starting", "Honey Quest: Honey Hunt")
	}
}
