const net = require("net");
const fs = require("fs");
const path = require("path");
const policyLog = path.join(__dirname, "..", "logs", "policy-843.log");

const POLICY =
  '<?xml version="1.0"?>' +
  '<!DOCTYPE cross-domain-policy SYSTEM "http://www.adobe.com/xml/dtds/cross-domain-policy.dtd">' +
  "<cross-domain-policy>" +
  '<site-control permitted-cross-domain-policies="master-only"/>' +
  '<allow-access-from domain="*" to-ports="*"/>' +
  "</cross-domain-policy>\0";

function startFlashPolicy(log) {
  const write = typeof log === "function" ? log : function (line) {
    process.stdout.write(line + "\n");
  };
  const server = net.createServer(function (socket) {
    const from = socket.remoteAddress + ":" + socket.remotePort;
    write("POLICY hit from " + from);
    try {
      fs.mkdirSync(path.dirname(policyLog), { recursive: true });
      fs.appendFileSync(policyLog, new Date().toISOString() + " hit " + from + "\n");
    } catch (e) {}
    socket.on("error", function () {});
    try {
      socket.write(POLICY, "utf8", function () {
        socket.end();
      });
    } catch (e) {}
  });
  server.on("error", function (err) {
    write("POLICY 843 error: " + err.message);
  });
  server.listen(843, "0.0.0.0", function () {
    write("POLICY 843 listening");
  });
  return server;
}

if (require.main === module) {
  startFlashPolicy();
}

module.exports = { startFlashPolicy };
