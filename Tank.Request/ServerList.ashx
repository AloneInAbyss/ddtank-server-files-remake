<%@ WebHandler Language="C#" Class="ServerListInline" %>

using System.Web;

public class ServerListInline : IHttpHandler
{
    public bool IsReusable
    {
        get { return false; }
    }

    public void ProcessRequest(HttpContext context)
    {
        context.Response.ContentType = "text/plain";
        context.Response.Write("<Result value=\"true\" message=\"Success!\" total=\"0\"><Item ID=\"4\" Name=\"Local\" IP=\"127.0.0.1\" Port=\"9431\" State=\"2\" MustLevel=\"100\" LowestLevel=\"0\" Online=\"0\" Remark=\"\" /></Result>");
    }
}
