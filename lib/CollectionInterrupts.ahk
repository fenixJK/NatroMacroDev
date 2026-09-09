; Gathering should continue while a failed collection is backing off.
nm_BeesmasInterrupt() {
	global BeesmasGatherInterruptCheck
	now := nowUnix()
	return ((beesmasActive = 1) && (BeesmasGatherInterruptCheck = 1)
		&& ((StockingsCheck && (now-LastStockings)>3600 && nm_CollectionRecovery.Ready("LastStockings"))
		|| (FeastCheck && (now-LastFeast)>5400 && nm_CollectionRecovery.Ready("LastFeast"))
		|| (RBPDelevelCheck && (now-LastRBPDelevel)>10800 && nm_CollectionRecovery.Ready("LastRBPDelevel"))
		|| (GingerbreadCheck && (now-LastGingerbread)>7200 && nm_CollectionRecovery.Ready("LastGingerbread"))
		|| (SnowMachineCheck && (now-LastSnowMachine)>7200 && nm_CollectionRecovery.Ready("LastSnowMachine"))
		|| (CandlesCheck && (now-LastCandles)>14400 && nm_CollectionRecovery.Ready("LastCandles"))
		|| (SamovarCheck && (now-LastSamovar)>21600 && nm_CollectionRecovery.Ready("LastSamovar"))
		|| (LidArtCheck && (now-LastLidArt)>28800 && nm_CollectionRecovery.Ready("LastLidArt"))
		|| (GummyBeaconCheck && (now-LastGummyBeacon)>28800 && nm_CollectionRecovery.Ready("LastGummyBeacon"))
		|| (WinterMemoryMatchCheck && (now-LastWinterMemoryMatch)>14400 && nm_CollectionRecovery.Ready("LastWinterMemoryMatch")))
	)
}

nm_MemoryMatchInterrupt() {
	global MemoryMatchInterruptCheck
	now := nowUnix()
	return ((MemoryMatchInterruptCheck = 1)
		&& ((NormalMemoryMatchCheck && (now-LastNormalMemoryMatch)>7200 && nm_CollectionRecovery.Ready("LastNormalMemoryMatch"))
		|| (MegaMemoryMatchCheck && (now-LastMegaMemoryMatch)>14400 && nm_CollectionRecovery.Ready("LastMegaMemoryMatch"))
		|| (ExtremeMemoryMatchCheck && (now-LastExtremeMemoryMatch)>28800 && nm_CollectionRecovery.Ready("LastExtremeMemoryMatch"))
		|| ((beesmasActive = 1) && WinterMemoryMatchCheck && (now-LastWinterMemoryMatch)>14400 && nm_CollectionRecovery.Ready("LastWinterMemoryMatch")))
	)
}
