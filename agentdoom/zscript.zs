version "4.10"

// Agent Doom score tracker.
//
// Counts the local player's monster kills, deathmatch frags and deaths for the
// whole GZDoom session, across map changes and restarts. It writes one
// "AGENTDOOM" line to the console log whenever a value changes. The launcher
// starts GZDoom with +logfile and reads the last line when it closes the game.
//
// All state is ui-scoped and only reads the play simulation, so it cannot
// change gameplay or cause a netgame desync.
class AgentDoomScore : StaticEventHandler
{
	ui int kills;
	ui int frags;
	ui int deaths;
	ui int lastKillCount;
	ui int lastFragCount;
	ui bool wasDead;
	ui bool started;
	ui int printedKills;
	ui int printedFrags;
	ui int printedDeaths;
	ui String printedMap;

	override void UiTick()
	{
		if (gamestate != GS_LEVEL || consoleplayer < 0 || !playeringame[consoleplayer])
		{
			return;
		}

		PlayerInfo p = players[consoleplayer];
		String mapName = level.MapName;

		if (!started || mapName != printedMap)
		{
			// A new map resets the per-map counters. Take them as the new base.
			lastKillCount = p.killcount;
			lastFragCount = p.fragcount;
			started = true;
		}

		if (p.killcount > lastKillCount)
		{
			kills += p.killcount - lastKillCount;
		}
		lastKillCount = p.killcount;

		if (p.fragcount > lastFragCount)
		{
			frags += p.fragcount - lastFragCount;
		}
		lastFragCount = p.fragcount;

		bool dead = p.playerstate == PST_DEAD || p.health <= 0;
		if (dead && !wasDead)
		{
			deaths++;
		}
		wasDead = dead;

		if (kills != printedKills || frags != printedFrags || deaths != printedDeaths || mapName != printedMap)
		{
			printedKills = kills;
			printedFrags = frags;
			printedDeaths = deaths;
			printedMap = mapName;
			Console.PrintfEx(PRINT_HIGH | PRINT_NONOTIFY,
				"AGENTDOOM kills=%d frags=%d deaths=%d map=%s",
				kills, frags, deaths, mapName);
		}
	}
}
