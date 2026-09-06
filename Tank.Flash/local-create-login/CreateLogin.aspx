<%@ Page Language="C#" AutoEventWireup="true" %>
<%@ Import Namespace="Bussiness.Interface" %>
<script runat="server">
protected void Page_Load(object sender, EventArgs e)
{
    Response.ContentType = "text/plain";
    string content = Request["content"] ?? "";
    string site = Request["site"] ?? "";
    string url = "http://127.0.0.1/Request/CreateLogin.aspx?content=" + HttpUtility.UrlEncode(content) + "&site=" + HttpUtility.UrlEncode(site);
    Response.Write(BaseInterface.RequestContent(url).Trim());
}
</script>
