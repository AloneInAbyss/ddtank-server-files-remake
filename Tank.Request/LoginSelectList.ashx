<%@ WebHandler Language="C#" Class="LoginSelectListInline" %>

using System;
using System.Web;
using System.Xml.Linq;
using Bussiness;
using Road.Flash;
using SqlDataProvider.Data;

public class LoginSelectListInline : IHttpHandler
{
    public bool IsReusable
    {
        get { return false; }
    }

    public void ProcessRequest(HttpContext context)
    {
        bool ok = true;
        string message = "Success!";
        XElement result = new XElement("Result");
        int total = 0;
        try
        {
            string username = HttpUtility.UrlDecode(context.Request["username"] ?? "");
            using (PlayerBussiness db = new PlayerBussiness())
            {
                PlayerInfo[] list = db.GetUserLoginList(username);
                if (list != null)
                {
                    foreach (PlayerInfo player in list)
                    {
                        if (player != null && player.ID > 0)
                        {
                            if (string.IsNullOrEmpty(player.NickName))
                            {
                                player.NickName = player.UserName;
                            }
                            result.Add(FlashUtils.CreateUserLoginList(player));
                            total++;
                        }
                    }
                }
            }
        }
        catch (Exception)
        {
            ok = false;
            message = "Fail!";
        }
        result.Add(new XAttribute("value", ok ? "true" : "false"));
        result.Add(new XAttribute("message", message));
        result.Add(new XAttribute("total", total));
        string xml = result.ToString(false);
        try
        {
            System.IO.Directory.CreateDirectory(@"E:\Arquivos\Projetos\DDTank41\logs");
            System.IO.File.WriteAllText(@"E:\Arquivos\Projetos\DDTank41\logs\last-select.xml", xml);
            System.IO.File.AppendAllText(@"E:\Arquivos\Projetos\DDTank41\logs\request-debug.log",
                DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss.fff") + " select " + xml + Environment.NewLine);
        }
        catch
        {
        }
        context.Response.ContentType = "text/plain";
        context.Response.Write(xml);
    }
}
