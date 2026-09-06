using Bussiness;
using Game.Base.Packets;

namespace Game.Server.Farm.Handle
{
    [FarmHandleAttbute(4)]
	public class GainFields : IFarmCommandHadler
    {
        public bool CommandHandler(GamePlayer Player, GSPacketIn packet)
        {
			int num = packet.ReadInt();
			int fieldId = packet.ReadInt();
			string msg = LanguageMgr.GetTranslation("Farm.HarvestFail");
			if (num == Player.PlayerCharacter.ID && Player.Farm.GainField(fieldId))
			{
				msg = LanguageMgr.GetTranslation("Farm.HarvestSuccess");
			}
			else if (num != Player.PlayerCharacter.ID)
			{
				msg = ((!Player.Farm.GainFriendFields(num, fieldId)) ? LanguageMgr.GetTranslation("Farm.StealLimit") : LanguageMgr.GetTranslation("Farm.Success"));
			}
			Player.SendMessage(msg);
			return true;
        }
    }
}
