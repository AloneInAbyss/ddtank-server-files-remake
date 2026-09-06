<%@ WebHandler Language="C#" Class="LoginInline" %>

using System;
using System.Configuration;
using System.IO;
using System.Text;
using System.Web;
using System.Web.SessionState;
using System.Xml.Linq;
using Bussiness;
using Bussiness.CenterService;
using Bussiness.Interface;
using Road.Flash;
using SqlDataProvider.Data;

public class LoginInline : IHttpHandler, IRequiresSessionState
{
    private static readonly string LogDir = @"E:\Arquivos\Projetos\DDTank41\logs";

    public bool IsReusable
    {
        get { return false; }
    }

    private static void Dbg(string line)
    {
        try
        {
            Directory.CreateDirectory(LogDir);
            File.AppendAllText(Path.Combine(LogDir, "request-debug.log"),
                DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss.fff") + " " + line + Environment.NewLine);
        }
        catch
        {
        }
    }

    public void ProcessRequest(HttpContext context)
    {
        bool value = false;
        string message = LanguageMgr.GetTranslation("Tank.Request.Login.Fail1");
        bool isError = false;
        XElement result = new XElement("Result");
        string p = context.Request["p"];
        try
        {
            BaseInterface inter = BaseInterface.CreateInterface();
            string site = context.Request["site"] == null ? "" : HttpUtility.UrlDecode(context.Request["site"]);
            string IP = context.Request.UserHostAddress;
            if (string.IsNullOrEmpty(p))
            {
                Dbg("login.ashx empty p");
                return;
            }
            byte[] src = CryptoHelper.RsaDecryt2(Tank.Request.StaticFunction.RsaCryptor, p);
            string[] strList = Encoding.UTF8.GetString(src, 7, src.Length - 7).Split(',');
            if (strList.Length != 4)
            {
                Dbg("login.ashx bad rsa parts=" + strList.Length);
                return;
            }
            string name = strList[0];
            string newPwd = strList[2];
            string nickname = strList[3];
            Dbg("login.ashx name=" + name + " nick=" + nickname);

            int isFirst = 0;
            bool isActive = false;
            bool firstValidate = Tank.Request.PlayerManager.GetByUserIsFirst(name);
            PlayerInfo player = inter.CreateLogin(name, newPwd, int.Parse(ConfigurationManager.AppSettings["ServerID"]), ref message, ref isFirst, IP, ref isError, firstValidate, ref isActive, site, nickname);
            Dbg("CreateLogin id=" + (player == null ? "null" : player.ID.ToString()) + " isFirst=" + isFirst + " isError=" + isError + " isActive=" + isActive);

            if (player == null || player.ID <= 0)
            {
                using (PlayerBussiness db = new PlayerBussiness())
                {
                    player = db.GetUserSingleByUserName(name);
                }
                isError = false;
                Dbg("fallback GetUserSingleByUserName id=" + (player == null ? "null" : player.ID.ToString()) + " nick=" + (player == null ? "" : player.NickName));
            }
            if (player != null && string.IsNullOrEmpty(player.NickName))
            {
                player.NickName = name;
            }

            if (player != null && player.ID > 0)
            {
                try
                {
                    using (CenterServiceClient center = new CenterServiceClient())
                    {
                        bool created = center.CreatePlayer(player.ID, name, newPwd, false);
                        Dbg("Center.CreatePlayer id=" + player.ID + " ok=" + created);
                    }
                }
                catch (Exception ex)
                {
                    Dbg("Center.CreatePlayer EX " + ex.Message);
                }

                if (isFirst == 0)
                {
                    Tank.Request.PlayerManager.Update(name, newPwd);
                }
                else
                {
                    Tank.Request.PlayerManager.Remove(name);
                }

                string style = string.IsNullOrEmpty(player.Style) ? ",,,,,,,," : player.Style;
                player.Colors = string.IsNullOrEmpty(player.Colors) ? ",,,,,,,," : player.Colors;
                result.Add(new XElement("Item",
                    new XAttribute("ID", player.ID),
                    new XAttribute("IsFirst", isFirst),
                    new XAttribute("NickName", player.NickName ?? ""),
                    new XAttribute("Date", ""),
                    new XAttribute("IsConsortia", 0),
                    new XAttribute("ConsortiaID", player.ConsortiaID),
                    new XAttribute("Sex", player.Sex),
                    new XAttribute("WinCount", player.Win),
                    new XAttribute("TotalCount", player.Total),
                    new XAttribute("EscapeCount", player.Escape),
                    new XAttribute("DutyName", player.DutyName ?? ""),
                    new XAttribute("GP", player.GP),
                    new XAttribute("Honor", ""),
                    new XAttribute("Style", style),
                    new XAttribute("Gold", player.Gold),
                    new XAttribute("Colors", player.Colors ?? ""),
                    new XAttribute("Attack", player.Attack),
                    new XAttribute("Defence", player.Defence),
                    new XAttribute("Agility", player.Agility),
                    new XAttribute("Luck", player.Luck),
                    new XAttribute("Grade", player.Grade),
                    new XAttribute("Hide", player.Hide),
                    new XAttribute("Repute", player.Repute),
                    new XAttribute("ConsortiaName", player.ConsortiaName ?? ""),
                    new XAttribute("Offer", player.Offer),
                    new XAttribute("Skin", player.Skin ?? ""),
                    new XAttribute("ReputeOffer", player.ReputeOffer),
                    new XAttribute("ConsortiaHonor", player.ConsortiaHonor),
                    new XAttribute("ConsortiaLevel", player.ConsortiaLevel),
                    new XAttribute("ConsortiaRepute", player.ConsortiaRepute),
                    new XAttribute("Money", player.Money + player.MoneyLock),
                    new XAttribute("AntiAddiction", player.AntiAddiction),
                    new XAttribute("IsMarried", player.IsMarried),
                    new XAttribute("SpouseID", player.SpouseID),
                    new XAttribute("SpouseName", player.SpouseName ?? ""),
                    new XAttribute("MarryInfoID", player.MarryInfoID),
                    new XAttribute("IsCreatedMarryRoom", player.IsCreatedMarryRoom),
                    new XAttribute("IsGotRing", player.IsGotRing),
                    new XAttribute("LoginName", player.UserName ?? ""),
                    new XAttribute("Nimbus", player.Nimbus),
                    new XAttribute("FightPower", player.FightPower),
                    new XAttribute("AnswerSite", player.AnswerSite),
                    new XAttribute("WeaklessGuildProgressStr", player.WeaklessGuildProgressStr ?? ""),
                    new XAttribute("IsOldPlayer", false)));
                value = true;
                message = LanguageMgr.GetTranslation("Tank.Request.Login.Success");
            }
            else
            {
                Dbg("login.ashx FAIL no player");
                Tank.Request.PlayerManager.Remove(name);
            }
        }
        catch (Exception ex)
        {
            Dbg("login.ashx EX " + ex.Message);
            value = false;
            message = LanguageMgr.GetTranslation("Tank.Request.Login.Fail2");
        }
        finally
        {
            result.Add(new XAttribute("value", value));
            result.Add(new XAttribute("message", message));
            string xml = result.ToString(false);
            Dbg("login.ashx OUT " + xml);
            try
            {
                Directory.CreateDirectory(LogDir);
                File.WriteAllText(Path.Combine(LogDir, "last-login.xml"), xml);
            }
            catch
            {
            }
            context.Response.ContentType = "text/plain";
            context.Response.Write(xml);
        }
    }
}
