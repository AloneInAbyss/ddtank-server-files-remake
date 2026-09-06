<%@ WebHandler Language="C#" Class="devchar" %>

using System;
using System.Web;
using Bussiness;

public class devchar : IHttpHandler
{
    public bool IsReusable { get { return false; } }

    public void ProcessRequest(HttpContext context)
    {
        string ip = context.Request.UserHostAddress;
        if (ip != "127.0.0.1" && ip != "::1")
        {
            context.Response.StatusCode = 403;
            context.Response.Write("forbidden");
            return;
        }
        string user = string.IsNullOrEmpty(context.Request["username"]) ? "myaccount" : context.Request["username"];
        string nick = string.IsNullOrEmpty(context.Request["nick"]) ? "HeroLocal" : context.Request["nick"];
        bool ok = false;
        string err = "";
        try
        {
            using (PlayerBussiness db = new PlayerBussiness())
            {
                ok = db.RegisterUser(user, nick, "dev", true, 100, 100, 100);
            }
        }
        catch (Exception ex)
        {
            err = ex.Message;
        }
        context.Response.ContentType = "text/plain";
        context.Response.Write(ok ? "ok" : ("fail " + err));
    }
}
