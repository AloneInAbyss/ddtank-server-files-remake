<%@ WebHandler Language="C#" Class="devlogin" %>

using System.Web;
using System.Web.SessionState;
using Tank.Flash;

public class devlogin : IHttpHandler, IRequiresSessionState
{
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
        string pass = string.IsNullOrEmpty(context.Request["password"]) ? "dev" : context.Request["password"];
        context.Session["username"] = user;
        context.Session["password"] = pass;
        LoadingManager.Add(user, pass);
        context.Response.ContentType = "text/plain";
        context.Response.Write("ok");
    }

    public bool IsReusable
    {
        get { return false; }
    }
}
