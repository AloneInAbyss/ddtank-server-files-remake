<%@ Page Language="C#" AutoEventWireup="true" %>
<%@ Import Namespace="System.Configuration" %>
<%@ Import Namespace="Bussiness.Interface" %>
<%@ Import Namespace="Tank.Request" %>
<script runat="server">
protected void Page_Load(object sender, EventArgs e)
{
    int result = 1;
    try
    {
        string content = HttpUtility.UrlDecode(Request["content"] ?? "");
        string site = Request["site"] == null ? "" : HttpUtility.UrlDecode(Request["site"]).ToLower();
        string[] parts = content.Split('|');
        if (parts.Length > 3)
        {
            string[] keys = new string[]
            {
                ConfigurationManager.AppSettings["LoginKey"],
                ConfigurationManager.AppSettings["LoginKey_" + site],
                "QY-16-WAN-0668-2555555-7ROAD-dandantang-love777",
                "BAODEPTRAI20111997-22121997-LOGINWEBKEY-AAAA",
                "QY-16-WAN-0668-2555555-7ROAD-dandantang-trminhpc773377"
            };
            bool ok = false;
            foreach (string k in keys)
            {
                if (string.IsNullOrEmpty(k))
                {
                    continue;
                }
                if (BaseInterface.md5(parts[0] + parts[1] + parts[2] + k) == parts[3].ToLower())
                {
                    ok = true;
                    break;
                }
            }
            if (ok)
            {
                string name = parts[0].Trim().ToLower();
                string password = parts[1].Trim().ToLower();
                if (!string.IsNullOrEmpty(name) && !string.IsNullOrEmpty(password))
                {
                    name = BaseInterface.GetNameBySite(name, site);
                    PlayerManager.Add(name, password);
                    result = 0;
                }
                else
                {
                    result = -91010;
                }
            }
            else
            {
                result = 5;
            }
        }
        else
        {
            result = 2;
        }
    }
    catch
    {
    }
    Response.ContentType = "text/plain";
    Response.Write(result);
}
</script>
