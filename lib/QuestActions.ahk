#Include "QuestRecovery.ahk"

; Quest consumers require explicit observed states. Unknown does not turn in or count a quest.

nm_PolarQuest(){
	global PolarQuestCheck, PolarQuest, PolarQuestComplete, QuestGatherField, QuestLadybugs, QuestRhinoBeetles, QuestSpider, QuestMantis, QuestScorpions, QuestWerewolf, LastBugrunLadybugs, LastBugrunRhinoBeetles, LastBugrunSpider, LastBugrunMantis, LastBugrunScorpions, LastBugrunWerewolf, MonsterRespawnTime, RotateQuest, TotalQuestsComplete, SessionQuestsComplete
	if(!PolarQuestCheck)
		return
	RotateQuest:="Polar"
	nm_PolarQuestProg()
	if(PolarQuestComplete = 1) {
		nm_TryQuestTurnIn("Polar", nm_PolarQuestProg)
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
			nm_TryQuestTurnIn("Polar", nm_PolarQuestProg)
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
		nm_TryQuestTurnIn("Riley", nm_RileyQuestProg)
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
			nm_TryQuestTurnIn("Riley", nm_RileyQuestProg)
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
		nm_TryQuestTurnIn("Bucko", nm_BuckoQuestProg)
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
			nm_TryQuestTurnIn("Bucko", nm_BuckoQuestProg)
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
		nm_TryQuestTurnIn("Black", nm_BlackQuestProg)
	}
}

nm_BrownQuest(){
	global BrownQuestCheck, BrownQuestComplete, BrownQuest, LastBrownQuest, RotateQuest, QuestGatherField, TotalQuestsComplete, SessionQuestsComplete
	if(!BrownQuestCheck)
		return
	RotateQuest:="Brown"
	nm_BrownQuestProg()
	if(BrownQuestComplete = 1 && (nowUnix()-LastBrownQuest)>3600) {
		nm_TryQuestTurnIn("Brown", nm_BrownQuestProg)
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

; Every entry path uses the same persisted reservation and post-visit check.
nm_TryQuestTurnIn(family, reader) {
	global
	local confirmed := false, questName
	if !%family%QuestCheck || %family%QuestComplete != 1 || !nm_QuestRecovery.Begin(family, "visit")
		return false
	try {
		nm_updateAction("Quest")
		nm_gotoQuestgiver(family)
		reader.Call()
		if %family%QuestComplete != 0
			return false
		questName := family = "Honey" ? "Honey Hunt" : %family%Quest
		nm_setStatus("Starting", family " Quest: " questName)
		if family != "Honey" {
			TotalQuestsComplete++, SessionQuestsComplete++
			PostSubmacroMessage("StatMonitor", 0x5555, 5, 1)
			IniWrite TotalQuestsComplete, "settings\nm_config.ini", "Status", "TotalQuestsComplete"
			IniWrite SessionQuestsComplete, "settings\nm_config.ini", "Status", "SessionQuestsComplete"
		}
		if family = "Black" || family = "Brown" {
			Last%family%Quest := nowUnix()
			IniWrite Last%family%Quest, "settings\nm_config.ini", "Quests", "Last" family "Quest"
		}
		confirmed := true
		return true
	} finally {
		nm_QuestRecovery.Finish(family, "visit", confirmed)
		if !confirmed
			nm_setStatus("Unconfirmed", family " quest turn-in was not verified; retry in 5 minutes.")
	}
}
