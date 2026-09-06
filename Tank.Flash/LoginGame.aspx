<%@ Page Language="C#" AutoEventWireup="true" %>
<%@ Import Namespace="System.Configuration" %>
<%@ Import Namespace="System.IO" %>
<%@ Import Namespace="System.Text" %>
<%@ Import Namespace="Bussiness.Interface" %>
<%@ Import Namespace="Tank.Flash" %>
<script runat="server">
protected void Page_Load(object sender, EventArgs e)
{
    Response.ContentType = "text/plain";
    Response.Buffer = true;

    string flashUrl = ConfigurationManager.AppSettings["FlashUrl"];

    if (Session["username"] == null || string.IsNullOrEmpty(Session["username"].ToString()))
    {
        Response.Write("0");
        return;
    }

    string name = Session["username"].ToString();
    string sessionPass = Session["password"] == null ? "" : Session["password"].ToString();

    if (!LoadingManager.Login(name, sessionPass))
    {
        Response.Write("0");
        return;
    }

    try
    {
        string password = Guid.NewGuid().ToString();
        string time = BaseInterface.ConvertDateTimeInt(DateTime.Now).ToString();
        string key = BaseInterface.GetLoginKey;
        string v = BaseInterface.md5(name + password + time + key);
        string loginUrl = BaseInterface.LoginUrl + "?content=" + HttpUtility.UrlEncode(name + "|" + password + "|" + time + "|" + v);
        string result = BaseInterface.RequestContent(loginUrl).Trim();
        if (result == "0")
        {
            string playUrl = "http://127.0.0.1/flash/DDT_Loadin2.swf?v=2&user=" + HttpUtility.UrlEncode(name) + "&key=" + HttpUtility.UrlEncode(password.ToUpper()) + "&config=http://127.0.0.1/flash/config.xml";
            try
            {
                string projector = @"E:\Downloads\Instaladores\flashplayer_32_sa.exe";
                string batPath = @"E:\Arquivos\Projetos\DDTank41\abrir-jogo.bat";
                string bat = "@echo off" + "\r\n" + "start \"\" \"" + projector + "\" \"" + playUrl + "\"" + "\r\n";
                File.WriteAllText(batPath, bat, Encoding.ASCII);
                File.WriteAllText(@"E:\Arquivos\Projetos\DDTank41\last-play-url.txt", playUrl, Encoding.ASCII);
            }
            catch
            {
            }
            Response.Write(flashUrl + "?user=" + HttpUtility.UrlEncode(name) + "&key=" + HttpUtility.UrlEncode(password.ToUpper()));
        }
        else
        {
            Response.Write(result);
        }
    }
    catch (Exception ex)
    {
        Response.Write(ex.ToString());
    }
}
</script>
