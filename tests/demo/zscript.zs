version "4.10"

// Test-only helper for tests/record-demo.sh. Never installed for normal play.
// It turns player 0 slowly so a recording shows the arena and the bots.
class AgentDoomDemoPan : StaticEventHandler
{
	override void WorldTick()
	{
		if (playeringame[0] && players[0].mo && players[0].health > 0)
		{
			players[0].mo.A_SetAngle(players[0].mo.angle + 0.9, SPF_INTERPOLATE);
		}
	}
}
