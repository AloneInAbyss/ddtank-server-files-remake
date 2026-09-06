const fs = require("fs");

(async function () {
  const tabs = await (await fetch("http://127.0.0.1:9222/json")).json();
  const page = tabs.find(function (t) { return t.type === "page"; });
  if (!page) {
    throw new Error("no page tab");
  }
  console.log("tab", page.url, page.title);
  const ws = new WebSocket(page.webSocketDebuggerUrl);
  await new Promise(function (res, rej) {
    ws.onopen = res;
    ws.onerror = rej;
  });
  let id = 0;
  const pending = new Map();
  ws.onmessage = function (ev) {
    const msg = JSON.parse(ev.data);
    if (msg.id && pending.has(msg.id)) {
      pending.get(msg.id)(msg);
    }
  };
  function send(method, params) {
    const i = ++id;
    return new Promise(function (resolve) {
      pending.set(i, resolve);
      ws.send(JSON.stringify({ id: i, method: method, params: params }));
    });
  }
  const html = await send("Runtime.evaluate", {
    expression: "document.documentElement.outerHTML.slice(0,5000)",
    returnByValue: true
  });
  console.log("--- html ---");
  console.log(html.result && html.result.result && html.result.result.value);
  const info = await send("Runtime.evaluate", {
    expression: "JSON.stringify({embeds:document.embeds.length,objects:document.getElementsByTagName('object').length,plugins:navigator.plugins.length,names:[].slice.call(navigator.plugins).map(function(p){return p.name;})})",
    returnByValue: true
  });
  console.log("--- plugins ---");
  console.log(info.result && info.result.result && info.result.result.value);
  const shot = await send("Page.captureScreenshot", { format: "png" });
  if (shot.result && shot.result.data) {
    const buf = Buffer.from(shot.result.data, "base64");
    fs.writeFileSync("E:/Arquivos/Projetos/DDTank41/logs/electron-screen.png", buf);
    console.log("screenshot bytes", buf.length);
  } else {
    console.log("screenshot fail", JSON.stringify(shot).slice(0, 400));
  }
  ws.close();
})().catch(function (e) {
  console.error(e);
  process.exit(1);
});
