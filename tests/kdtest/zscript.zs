version "4.10"

// Test-only helper for tests/smoke.sh. It is never installed for normal play.
// On the first map of the session it scripts a known score, without manual input:
//   3 s after the map starts: kill 3 monsters with player 0 as the killer;
//   5 s after the map starts: kill player 0 once.
// Expected tracker result: kills=3 frags=0 deaths=1.
class AgentDoomTestHelper : StaticEventHandler
{
	bool done;

	override void WorldTick()
	{
		if (done || !playeringame[0] || !players[0].mo)
		{
			return;
		}
		Actor me = players[0].mo;
		if (level.maptime == 35 * 3)
		{
			int killed = 0;
			ThinkerIterator it = ThinkerIterator.Create("Actor");
			Actor mo;
			while (killed < 3 && (mo = Actor(it.Next())))
			{
				if (mo.bIsMonster && mo.bCountKill && mo.health > 0)
				{
					mo.DamageMobj(me, me, mo.health + 1000, 'None', DMG_FORCED);
					killed++;
				}
			}
			Console.Printf("agentdoomtest: killed %d, killcount %d", killed, players[0].killcount);
		}
		else if (level.maptime == 35 * 5)
		{
			me.DamageMobj(null, null, me.health + 1000, 'None', DMG_FORCED);
			Console.Printf("agentdoomtest: player killed");
			done = true;
		}
	}
}
