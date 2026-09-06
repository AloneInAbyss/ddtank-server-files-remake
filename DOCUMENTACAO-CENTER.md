# Center.Service — o servidor coordenador

Este documento descreve **o Center deste fork** (edição 10990), não o “oficial” da 7Road. Tudo abaixo foi lido em `Center.Service`, `Center.Server`, `Bussiness` e nos clientes que falam com ele (`Game.Server`, `Tank.Request`).

Documentos irmãos: [`DOCUMENTACAO.md`](DOCUMENTACAO.md), [`DOCUMENTACAO-ROAD.md`](DOCUMENTACAO-ROAD.md), [`DOCUMENTACAO-FIGHTING.md`](DOCUMENTACAO-FIGHTING.md), [`GUIA-SUBIR-SERVIDOR.md`](GUIA-SUBIR-SERVIDOR.md), [`DOCUMENTACAO-AMBIENTE-LOCAL.md`](DOCUMENTACAO-AMBIENTE-LOCAL.md), [`DOCUMENTACAO-MODIFICACOES.md`](DOCUMENTACAO-MODIFICACOES.md).

Este arquivo é **só o Center**.

---

## 1. O que é, em uma frase

O Center é a **recepção do restaurante**: não serve a comida e o jogador nunca “entra” nele. Ele sabe quais salões (canais / Game Servers) estão abertos, quem está sentado em qual mesa, e avisa todo mundo quando chega correio, leilão, aviso ou kick.

Sem o Center no ar:

- o Road **não sobe** (falha em `Login To CenterServer`);
- o Flash **não monta a lista de canais** (`ServerList.ashx` chama o Center por WCF);
- o login HTTP **não registra a sessão** (`CreatePlayer`);
- chat de guilda, amigo, corneta e kitoff **não atravessam** de um canal para outro.

**WCF** (Windows Communication Foundation) é o serviço da Microsoft que um programa usa para chamar métodos de outro processo. Aqui o Center **expõe** um contrato `ICenterService`; o Road, o `Tank.Request` e o `GameAdmin` são **clientes**.

---

## 2. Por que existe (e por que é o primeiro a ligar)

O emulador foi feito para **vários canais**. Cada `Road.Service` é um salão com o próprio `ServerID` (neste PC, o canal **4**). O jogador escolhe o canal na tela de lista e só então abre o TCP na porta 9500 daquele Road.

Alguém precisa:

1. guardar a lista de canais (nome, IP, porta, lotação) lida do SQL;
2. impedir a mesma conta em dois canais ao mesmo tempo;
3. retransmitir o que é “do mundo inteiro” (aviso, chat de guilda, amigo online, corneta);
4. varrer o banco de tempos em tempos (correio vencido, leilão encerrado, guilda inativa), porque isso não pode ficar a cargo de um canal só — se aquele Road cair, o resto do mundo pararia.

Isso é o Center. Por isso a ordem obrigatória é **SQL → IIS → Center → Fighting → Road**. O Road conecta no Center na subida; se a porta 9202 estiver fechada, o `Init` aborta.

O jogador **não** conecta no Center. O cliente Flash fala HTTP com `Tank.Flash` / `Tank.Request` e TCP com o Road. O Center só aparece no meio, entre processos de servidor.

---

## 3. Duas pastas (exe + dll)

O padrão deste repo: o processo é fino; a lógica mora na biblioteca.

| Pasta | Tipo | Função |
|-------|------|--------|
| `Center.Service` | Executável (`net48`) | Ponto de entrada. `Program.cs` sem argumento assume `--start` e chama `ConsoleStart`. |
| `Center.Server` | Biblioteca (`net472`) | Toda a lógica: `CenterServer`, `LoginMgr`, `ServerMgr`, `ServerClient`, WCF, timers. |

**Executável compilado:** `Center.Service\bin\Debug\net48\Center.Service.exe`  
Ele lê `Center.Service.exe.config` (cópia do `App.config`) na mesma pasta.

`Center.Service` depende de `Center.Server`, `Bussiness` e `Game.Base`. `Center.Server` depende de `Bussiness`, `Game.Base` e `SqlDataProvider`.

---

## 4. Mapa de arquivos

### 4.1 `Center.Service` (o processo)

| Arquivo | Papel |
|---------|--------|
| `Program.cs` | `Main`. Sem args → `--start`. Só registra a ação `ConsoleStart`. |
| `Actions/ConsoleStart.cs` | Cria o singleton `CenterServer`, chama `Start()`, depois o loop do console (`exit`, `notice`, `reload`…). |
| `IAction.cs` | Interface das ações de linha de comando. |
| `App.config` | IP, porta 9202, intervalos, SQL, idioma, AAS, WCF 2008/2009. |
| `logconfig.xml` | log4net (o `CenterServer.CreateInstance` configura e observa este arquivo). |
| `Center.Service.csproj` | `OutputType=Exe`, `StartupObject=Center.Service.Program`. |

O título da janela, no código, ainda é `"Center Service | DDTank 3.0"`.

### 4.2 `Center.Server` (a lógica)

| Arquivo | Papel |
|---------|--------|
| `CenterServer.cs` | Classe principal. Herda `BaseServer` (`Game.Base`). Sobe socket, WCF, timers; manda pacote para todos os Roads (`SendToALL`). |
| `CenterServerConfig.cs` | Lê as chaves do `App.config` (`IP`, `Port`, intervalos em **minutos**). |
| `CenterService.cs` + `ICenterService.cs` | Host WCF e o contrato que Request/Road/Admin chamam. |
| `ServerClient.cs` | **Um** Game Server conectado no TCP 9202. Login RSA do canal, ping, chat, guilda, world boss… |
| `ServerMgr.cs` | Lista de canais em memória, vinda de `SP_Service_List`. |
| `LoginMgr.cs` | Sessões de jogador em memória (quem está em qual canal). |
| `Player.cs` + `ePlayerState.cs` | Registro da sessão: `NotLogin` / `Logining` / `Play`. |
| `ServerData.cs` | DTO (objeto só para transportar dados) que o WCF devolve na lista de canais. |
| `WorldMgr.cs` | Avisos (`SystemNotice.xml`) + estado em memória do World Boss / League. |
| `ConsortiaBossMgr.cs` | Boss de guilda compartilhado entre canais. |
| `ConsortiaMrg.cs` | Classe vazia (nome antigo / leftover). Não faz nada. |
| `Managers/MacroDropMgr.cs` | Limite global de drop raro (`macrodrop\macroDrop.ini`). |
| `Statics/LogMgr.cs` | Contagem de registro / log periódico do Center. |
| `Commands/GamePropertiesCommand.cs` | Comando `/gp` registrado, mas `OnCommand` só devolve `true` (não implementado). |
| `ePackageType.cs` | Códigos dos pacotes TCP Center ↔ Road. |

O Center **não** tem os ~166 handlers de jogador. Isso é `Game.Server\Packets\Client\`.

---

## 5. Portas e quem fala com quem

Três escutas, três públicos.

| Porta | Protocolo | Quem escuta | Quem conecta | Para quê |
|-------|-----------|-------------|--------------|----------|
| **9202** | TCP (pacote `GSPacketIn`) | Center (`IP` + `Port` do App.config) | Cada `Road.Service` (`LoginServerIp` / `LoginServerPort`) | Canal se registra, ping, chat, sessão, kitoff |
| **2009** | WCF `net.tcp` | `ICenterService` | `Tank.Request`, Road (via `Bussiness.CenterService.CenterServiceClient`), `GameAdmin` | Lista de canais, `CreatePlayer`, recarga, aviso, kick |
| **2008** | HTTP (metadata WCF + `basicHttpBinding`) | `http://127.0.0.1:2008/CenterService/` | Ferramenta / debug; o endpoint `mex` | Descobrir o contrato |

O endereço WCF está **hardcoded** no `App.config` do Center **e** no `Web.config` do Request (`net.tcp://127.0.0.1:2009/`). Se o Center mudar de máquina, os dois lados precisam apontar para o mesmo host.

`Game.Server` também abre um `LoginServerConnector` no **9202** (não no 2009) para o tráfego contínuo. O WCF 2009 o Road usa pontualmente, pela DLL `Bussiness` (login da sessão, etc.).

```
Tank.Request  ──WCF 2009──►  Center.Service
GameAdmin     ──WCF 2009──►       │
                                  │  TCP 9202
Road.Service  ────────────────────┘
     ▲
     │ TCP 9500
Cliente Flash
```

---

## 6. O que acontece no `Start()`

`CenterServer.Start()` (`CenterServer.cs`). Qualquer `InitComponent(..., false)` **para o processo** (`Stop()`). Ordem:

1. `GameProperties.Refresh()` — propriedades globais (várias vêm do banco / config).
2. Recompila scripts da pasta `scripts\` ao lado do exe (cria a pasta se não existir).
3. Registra assemblies de script / eventos globais.
4. **Edição:** string hardcoded `Edition = "2612558"` tem que ser igual a `GameProperties.EDITION` (default da mesma string). Se divergir, o log mostra `Check Server Edition:2612558` e o Center **não sobe**.
5. Socket em `IP`:`Port` (9202).
6. `CenterService.Start()` — abre o `ServiceHost` WCF. Se 2008/2009 já estiverem ocupadas, falha aqui.
7. `ServerMgr.Start()` — `SP_Service_List`; cada canal entra com `State = 1` e `Online = 0`.
8. `MacroDropMgr.Init()` — lê `macrodrop\macroDrop.ini`.
9. `LanguageMgr.Setup("")` — arquivo em `LanguagePath` (relativo à pasta de trabalho do exe).
10. `WorldMgr.Start()` — zera World Boss / League e carrega `SystemNotice.xml`.
11. Timers globais.
12. `NewTitleMgr.Init()` e `WorldEventMgr.Init()` (código em `Bussiness` / `Game.Server.Managers`).
13. `base.Start()` — começa a aceitar conexões TCP.
14. O log escreve `"GameServer is now open for connections!"` (o texto é herdado; é o **Center**).

Se o SQL estiver fora ou `SP_Service_List` quebrar, o passo 7 falha e o processo fecha.

---

## 7. Lista de canais (`ServerMgr`)

Fonte: stored procedure `SP_Service_List` (`ServiceBussiness.GetServerList`), banco `Project_Player34` (`conString`).

Cada linha vira um `ServerInfo` em memória: `ID`, `Name`, `IP`, `Port`, `Total`, `MustLevel`, `LowestLevel`, `Online`, `State`.

| `State` | Quando | Significado prático |
|---------|--------|---------------------|
| 1 | Acabou de carregar, ou o Road **desconectou** | Canal “fechado” / à espera. O Road **só consegue logar** se o ID existir e o State for 1. |
| 2 | Road logou, ou ping com lotação baixa | Aberto, folgado (`GetState`: online ≤ 50% do `Total`) |
| 4 | Ping com online > 50% do `Total` | Cheio pela metade |
| 5 | `Online >= Total` | Lotado |
| −1 | (filtrado no Request) | `ServerList.ashx` **pula** o canal |

O Road autentica no TCP 9202 assim (`ServerClient.HandleLogin`):

1. No `OnConnect`, o Center manda a chave pública RSA (pacote 0).
2. O Road cifra `"serverId,serverName"` e devolve no pacote 1.
3. O Center descriptografa. O `serverId` **precisa** existir em `ServerMgr` e estar com `State == 1`. Senão: log `Error Login Packet ... want to login serverid` e `Disconnect`.
4. Se ok: `State = 2`, `Online = 0`, manda flags AAS/prêmio diário e chama `SendUpdateWorldEvent()` (hoje vazio — ver §12).

Depois, o Road manda **ping** (pacote 12) com a quantidade de jogadores online. O Center atualiza `Info.Online` e recalcula `State`.

Timer `SaveInterval`: `ServerMgr.SaveToDatabase()` → `SP` de `UpdateService` para cada canal (grava online/state de volta no SQL).

`reload&server` no console (ou WCF `Reload("server")`): relê o `App.config`, reinicia timers, `ReLoadServerList()`, reenvia as flags.

O Flash vê a lista por `Tank.Request\ServerList.ashx`: WCF `GetServerList()`, depois `Port - 69` no XML. O **69** é deste código; a porta gravada no SQL e a que o Flash usa **não são o mesmo número**. Se mudar a porta do Road, ajuste o valor no banco de forma que `Port - 69` caia na porta TCP real (neste setup, o canal 4 escuta **9500**).

---

## 8. Sessão de login (`LoginMgr`) — o fluxo que o jogador sente

O Center **não** valida a senha do site. Quem fala com `Db_Membership` / personagem é o `Tank.Request` + `PlayerBussiness.LoginGame`. O Center só guarda, em RAM, “esta conta existe nesta sessão e está (ou não) num canal”.

### 8.1 Do HTTP até o lobby

```
1. Flash / site  →  Tank.Request (CreateLogin / Login.ashx)
2. BaseInterface.CreateLogin
      ├─ SQL: LoginGame / ActivePlayer
      └─ WCF: Center.CreatePlayer(id, name, password, isFirst)
3. Flash abre TCP no Road :9500
4. UserLoginHandler
      └─ WCF: Center.ValidateLoginAndGetID(name, password, …)
5. Road manda pacote 3 (ALLOW_USER_LOGIN) no TCP 9202
6. LoginMgr.TryLoginPlayer → Center responde allow true/false
7. Se allow: o jogador entra no canal
```

`CreatePlayer` (`CenterService` → `LoginMgr.CreatePlayer`):

- se o ID **já** estava na lista, herda `State` e `CurrentServer` e **substitui** o registro;
- se o **nome** já existia com outro ID, remove o antigo;
- senão, entra como `ePlayerState.NotLogin`;
- se o registro antigo tinha um `CurrentServer`, o Center manda **kitoff** nesse Road (expulsa a sessão anterior). Relogar a mesma conta em outro lugar **derruba** a sessão velha.

`ValidateLoginAndGetID` **não consulta SQL**. Percorre a lista em memória e compara `Name` + `Password`. Se a conta não passou por `CreatePlayer` neste processo, o Road recebe “overtime” / login falhou.

Estados (`ePlayerState`):

| Valor | Nome | Significado |
|-------|------|-------------|
| 0 | `NotLogin` | Registrado no Center, ainda não entrou num Road |
| 1 | `Logining` | `TryLoginPlayer` reservou o canal |
| 2 | `Play` | Road avisou `USER_ONLINE` (pacote 5) |

`TryLoginPlayer`: se já existe `CurrentServer` e o jogador está em `Play`, o Center kitoff no servidor antigo e **recusa** este login (`allow = false`). Evita dois sockets da mesma conta.

Timer `LoginLapseInterval`: remove quem ficou em `NotLogin` tempo demais (conta criada no HTTP e o Flash nunca completou o TCP). Quem já está logado só tem o `LastTime` renovado.

### 8.2 A armadilha do `IsFirst`

`UserLoginHandler` (Road): se `ValidateLoginAndGetID` devolve `isFirst == true`, o Road manda kitoff com a chave `UserLoginHandler.Register` e **fecha o socket** em milissegundos.

`BaseInterface.CreateLogin` grava no Center `isFirst == 0` (ou seja: o inteiro que veio do SQL, comparado com zero). No boot deste PC isso chegou `true` para personagem que **já existia**, e o lobby só abriu depois de chamar `CreatePlayer(..., false)`. Detalhe operacional: [`DOCUMENTACAO-AMBIENTE-LOCAL.md`](DOCUMENTACAO-AMBIENTE-LOCAL.md).

O contrato WCF do **proxy** em `Bussiness.CenterService.ICenterService` declara `ValidateLoginAndGetID(..., int zoneId, ...)`. A **implementação** em `Center.Server.ICenterService` **não tem** `zoneId`. O Road passa `AreaID` nesse parâmetro extra. Vale o que o processo do Center realmente implementa; não invente um “zone” no Center que o método não usa.

---

## 9. O contrato WCF (`ICenterService`)

Implementação: `Center.Server\CenterService.cs`. Clientes gerados: `Bussiness\CenterService\`, `Tank.Request\Service References\CenterService\`.

| Método | O que faz de verdade |
|--------|----------------------|
| `CreatePlayer` | Coloca a conta no `LoginMgr` |
| `ValidateLoginAndGetID` | Acha a conta em RAM; devolve `userID` e `IsFirst` |
| `GetServerList` | Copia `ServerMgr.Servers` para `ServerData` |
| `ReLoadServerList` | Relê `SP_Service_List` |
| `KitoffUser` | Manda o Road expulsar; remove do `LoginMgr` |
| `MailNotice` | Pacote 117 no canal onde o jogador está |
| `ChargeMoney` | Pacote 9 no Road daquela conta (recarga) |
| `SystemNotice` | Aviso para **todos** os Roads (pacote 10) |
| `Reload` | `SendReload` — ver §14 |
| `AASGetState` / `AASUpdateState` | Flag anti-vício (AAS) |
| `GetConfigState` / `UpdateConfigState` | `type=1` AAS; `type=2` prêmio diário |
| `ExperienceRateUpdate` | Pacote 177 no Road daquele `serverId` |
| `NoticeServerUpdate` | Pacote 11 (reload) só naquele canal |
| `ActivePlayer` | Incrementa contador de registro no `LogMgr` |

Quem chama no Request (exemplos): `ServerList.ashx`, `ChargeMoney.aspx`, `ChargeToUser.aspx`, `SystemNotice.aspx`, `ExperienceRate.aspx`, `AASUpdateState.aspx`, `NoticeServerUpdate.aspx`, `ActivePullDown.ashx`.

O `GameAdmin` antigo (`Backup\Admin\mainRequest.ashx.cs`) também instancia `CenterServiceClient`. O painel atual ainda aponta para o banco `Db_Tank` — não trate o Admin como caminho confiável até alinhar a connection string.

---

## 10. TCP com o Road (`ServerClient`)

Cada conexão 9202 é um `ServerClient`. Buffer 8 KB. Pacotes: `ePackageType`.

Papel principal: **retransmitir**. Chat pessoal, chat de guilda, amigo, corneta (`B_BUGLE`), criar/apagar guilda, estado de casamento — o Center quase não interpreta; manda `SendToALL` para os outros Roads (às vezes excluindo quem enviou).

O que o Center **decide** de fato:

| Pacote | Código | Ação no Center |
|--------|--------|----------------|
| RSAKey | 0 | Envia modulus/exponent no connect |
| LOGIN | 1 | Autentica o **canal** (não o jogador) |
| ALLOW_USER_LOGIN | 3 | `TryLoginPlayer` → allow |
| USER_OFFLINE / USER_ONLINE | 4 / 5 | Atualiza `LoginMgr`; avisa os outros canais |
| USER_STATE | 6 | “Esse ID está online em algum Road?” |
| PING | 12 | Atualiza online + State |
| MAIL_RESPONSE | 117 | Encaminha ao Road do destinatário |
| MACRO_DROP | 178 | Consome cota global e marca sync |
| CONSORTIA_BOSS_* | 180–188 | Estado do boss de guilda em RAM |
| WORLD_BOSS_* | 79–86 | HP / rank / sala (só se algum Road mandar) |
| SHUTDOWN | 15 | Road avisando que está parando |

Ao **desconectar** um Road: o Center remove todos os jogadores daquele `ServerClient`, avisa os outros canais (`USER_OFFLINE`) e volta o canal para `State = 1`, `Online = 0`.

O outro lado (`Game.Server\LoginServerConnector.cs`) trata os pacotes que o Center empurra: kitoff, allow login, aviso, correio, AAS, charge, guilda, rate, boss de guilda, etc.

---

## 11. Timers (o relógio do mundo)

`InitGlobalTimers()`. Quase todos os intervalos do `App.config` estão em **minutos**, convertidos para ms (`* 60 * 1000`). Dois timers são fixos em **60 segundos**.

| Timer | Chave / período | O que faz |
|-------|-----------------|-----------|
| Save DB | `SaveInterval` (default 1 min) | `ServerMgr.SaveToDatabase()` |
| System notice | `SystemNoticeInterval` — **não está no App.config**; default do código = **2 min** | Sorteia uma frase de `WorldMgr.NotceList` e manda pacote 10 |
| Login lapse | `LoginLapseInterval` (1 min neste config) | Expira `NotLogin` velho |
| Save record | `SaveRecordInterval` | `LogMgr.Save()` |
| Scan auction | `ScanAuctionInterval` (60 min) | `SP_Auction_Scan` + pacote 117 para quem precisa ver o correio do leilão |
| Scan mail | `ScanMailInterval` (120 min) | `SP_Mail_Scan` + pacote 117 |
| Scan consortia | `ScanConsortiaInterval` (1 min neste config; default da classe é 60) | `SP_Consortia_Scan` + pacote 128 |
| World event | **60 s** (não configurável) | `SendUpdateWorldEvent()` — corpo **comentado** |
| Consortia boss | **60 s** | `ConsortiaBossMgr.UpdateTime()`; a cada 6 ticks manda prêmio (pacote 185) |

Leilão usa `GameProperties.Cess` (imposto; default 0.1) na `SP_Auction_Scan`.

Se um scan passar de 120 s, o log avisa (`WarnFormat`). Os callbacks baixam a prioridade da thread para `Lowest` enquanto rodam.

---

## 12. World Boss, League e o que está desligado

O código **existe**: `WorldMgr` guarda HP (`MAX_BLOOD` / `current_blood`), janela de tempo, rank top 10, nomes de chefes e IDs de PvE (`1243`, `30001`, `30002`, `30004`). `CenterServer` tem `SendPrivateInfo`, `SendUpdateWorldBlood`, `SendLeagueOpenClose`, `SendBattleGoundOpenClose`, etc.

O timer de 60 s chama `SendUpdateWorldEvent()`. O corpo que abriria a League entre 20h e 22h está **inteiro comentado**. `WorldMgr.Start()` deixa `worldOpen = false`, `IsLeagueOpen = false`, `fightOver = true`.

**Não religue isso “junto com documentação”.** Evento global mexe em SQL, Road, Fighting e cliente. Só depois de testar de ponta a ponta, como diz o `AGENTS.md`.

Os pacotes 79–91 continuam no `ePackageType`. Se um Road mandar dano de World Boss, o Center ainda reduz HP e retransmite. Sem alguém **abrir** o evento, isso não começa sozinho.

---

## 13. Boss de guilda (`ConsortiaBossMgr`)

Estado em memória por `ConsortiaID`: HP, rank, prazo, extensão (+10 min, limitada por `extendAvailableNum`). Os Roads mandam create / sangue / rank / reload; o Center devolve o pacote 180 (e variantes 182–188) para **todos** os canais.

O timer de 60 s avança o tempo. A cada 6 passadas (`TimeCheckingAward > 5`) envia a lista de guildas que devem receber prêmio (pacote 185).

Isso **não** é o World Boss da cidade. É o chefe que a guilda convoca.

---

## 14. Console e `reload`

Depois do `Start()`, `ConsoleStart` lê linha a linha. O separador dos comandos nativos é `&`.

| Digitar | Efeito |
|---------|--------|
| `exit` | Sai do loop e chama `CenterServer.Stop()` (salva DB, fecha WCF, fecha socket) |
| `notice&texto` | Aviso imediato em todos os canais |
| `reload&tipo` | `SendReload`. `tipo` é nome de `eReloadType` (`server`, `language`, `item`, `shop`…) |
| `shutdown` | Pacote 15 para todos os Roads (“o mundo vai fechar”) |
| `AAS&true` / `AAS&false` | Liga/desliga AAS e grava no `Center.Service.exe.config` |
| `help` | Imprime `HelpStr` do App.config (hoje ainda em chinês) |
| `/comando` | Encaminha ao `CommandMgr` (`Game.Base`). `/gp` está registrado e é no-op |

`reload&server` é o único tipo que o **próprio Center** trata além de retransmitir: relê config, timers, lista de canais e flags. Os outros tipos viram pacote 11 nos Roads — quem recarrega item/loja/quest é o **Game Server**.

`eReloadType` vive em `Bussiness\Protocol\eReloadType.cs` (`ball`, `map`, `item`, `quest`, `shop`, `consortia`, `dailyaward`, `language`, `newtitle`…).

`Stop()`: desliga timers, salva canais e records, `CenterService.Stop()`, `base.Stop()`.

---

## 15. Configuração (`App.config`)

Arquivo canônico: `Center.Service\App.config` (copiado para o `bin` como `Center.Service.exe.config`).

### 15.1 Chaves que o Center realmente usa

| Chave | Uso |
|-------|-----|
| `IP` / `Port` | Bind do TCP 9202 |
| `conString` | SQL `Project_Player34` (lista de canais, leilão, correio, guilda, `GameProperties`) |
| `crosszoneString` | SQL `Project_Game34` (cross-zone; o Center declara, o uso pesado é no Request/Road) |
| `LanguagePath` | Arquivo `key:value` do `LanguageMgr` |
| `SystemNoticePath` | XML da faixa de avisos |
| `LoginLapseInterval`, `SaveInterval`, `SaveRecordInterval`, `ScanAuctionInterval`, `ScanMailInterval`, `ScanConsortiaInterval` | Minutos dos timers |
| `AAS` | Anti-vício (false neste config) |
| `DailyAwardState` | Prêmio diário ligado (true) |
| `ServerID`, `GameType`, `AreaID` | Usados pelo `LogMgr` ao gravar record |
| `LogPath`, `TxtRecord` | Record em texto |
| `HelpStr` | Texto do `help` no console |
| `system.serviceModel` | Endereços 2008 / 2009 |

`CenterServerConfig` também conhece `LogConfigFile` (default `logconfig.xml`), `ScriptAssemblies` e `ScriptCompilationTarget` (vazios neste App.config). `SystemNoticeInterval` **só tem default no código** (2 minutos) — não aparece no XML versionado.

O `App.config` versionado ainda traz a connection string do autor (`sa` / senha do fork). **Não trate isso como credencial de produção.** Não commite senha nova. Em produção: User Secrets / config fora do git.

### 15.2 Idioma e avisos

`LanguageMgr.Setup("")` junta `"" + LanguagePath`. O arquivo precisa existir **na pasta de trabalho do exe** (em geral `Center.Service\bin\Debug\net48\Languages\...`). Hoje a fonte desses arquivos ainda tende a viver no `bin`; a dívida do projeto é ter uma cópia no source e copiar no build.

`WorldMgr.LoadNotice` lê `SystemNoticePath` como XML:

```xml
<list>
  <item id="1" notice="texto que aparece na faixa"/>
</list>
```

O timer sorteia um item da lista. Aviso imediato: console `notice&...` ou WCF `SystemNotice`.

---

## 16. Bancos e stored procedures que o Center toca

| Procedure | Quem chama | Efeito |
|-----------|------------|--------|
| `SP_Service_List` | `ServerMgr.Start` / `ReLoadServerList` | Lista de canais |
| Update de serviço (`UpdateService`) | `SaveToDatabase` | Grava online/state |
| `SP_Auction_Scan` | timer leilão | Encerra leilões; IDs para avisar |
| `SP_Mail_Scan` | timer correio | Correio vencido / a notificar |
| `SP_Consortia_Scan` | timer guilda | Guildas a notificar (pacote 128) |

O Center **não** carrega item, mapa, quest nem loja. Isso é o Road no `Init`. Mudar drop de dungeon **não** é mudança de Center.

`GameProperties` (edição, `Cess`, etc.) o Center relê no `Start` e no `reload&server`. Várias propriedades nascem de config/banco compartilhado com o Road.

---

## 17. O que você pode modificar (e onde)

Ordem deste repo: **config → SQL → idioma → C#**. Flash e resource **não** passam pelo Center.

### Sem recompilar

- `App.config`: IP público (se outro PC for conectar no 9202/2009), intervalos, AAS, prêmio diário, `LanguagePath`.
- `Languages\SystemNotice.xml` (no `bin` do exe): textos da faixa.
- SQL: linha do canal (`SP_Service_List` / tabela por trás) — **nome, IP e porta** que o Flash vê. `ServerID` do Road tem que continuar existindo.
- Console: aviso, reload, shutdown, AAS.

### Recompilando o Center

- Novo método WCF (e aí regenerar o proxy em `Bussiness` / `Tank.Request`).
- Novo pacote TCP ou regra de sessão (`LoginMgr`, `ServerClient`).
- Religar League / World Boss no `SendUpdateWorldEvent` — **só com teste**, e documentar o comportamento.
- Extrair string hardcoded para chave de idioma (`Center.Server.SendKitoffUser`, avisos de League, etc.).
- Implementar de verdade o `/gp`.

### O que **não** se muda aqui

| Quer mudar | Onde é de verdade |
|------------|-------------------|
| Física do tiro, dano, turno | `Game.Logic` / Fighting — [`DOCUMENTACAO-COMBATE.md`](DOCUMENTACAO-COMBATE.md) |
| Inventário, sala, fortalecer, farm | `Game.Server` (Road) |
| Tela, botão, dica do cliente | `FlashSV1\ui\...\language.txt` |
| Nome de item / quest | SQL + XML do Request |
| HTML de login | `Tank.Flash` |
| Senha do site / bypass `Login.ashx` | `Tank.Request` (o `if (true)` **não** é do Center) |

---

## 18. Dependências e ordem de boot

O Center precisa, para o `Init` terminar:

1. SQL no ar, `conString` válida, `SP_Service_List` ok;
2. portas **9202**, **2008** e **2009** livres;
3. `GameProperties.EDITION` = `2612558`;
4. arquivo de idioma existente (senão `LanguageMgr` pode falhar o componente);
5. `logconfig.xml` ao lado do exe (se faltar, o código tenta extrair o resource embutido).

O Road precisa do Center **já escutando 9202**. O Request precisa do Center **já escutando 2009** na hora do `ServerList` e do `CreatePlayer`. Ligar o Flash com o Center morto mostra lista de canais vazia / “Fail!”.

Vários canais: cada Road com `ServerID` distinto, todos apontando o mesmo `LoginServerIp:9202`. O Center é o ponto único de sessão. `OtherLoginServer` no Road é um conector extra (lista `ip:port` separada por `|`); neste setup local costuma estar vazio.

---

## 19. Armadilhas deste fork

1. **Center primeiro.** Road sem Center = `Init` vermelho e processo que fecha.
2. **`ServerID` fantasma.** Se o ID do Road não estiver em `SP_Service_List`, o TCP 9202 desconecta na hora.
3. **State != 1 no login do canal.** Reiniciar só o Road, com o Center ainda achando o canal “aberto”, pode recusar o segundo login. Reinicie o Center ou dê `reload&server` depois de um crash sujo; ou feche o Road de forma que o `OnDisconnect` volte o State para 1.
4. **`IsFirst`.** Ver §8.2. Sintoma: socket cai ~12 ms com mensagem de registro / “conexão falhou”.
5. **Lista de canais vs porta.** `ServerList.ashx` manda `Port - 69`. Mude uma ponta e esqueça a outra = Flash apontando para porta morta.
6. **WCF só em 127.0.0.1.** Request noutro host não alcança `net.tcp://127.0.0.1:2009/`.
7. **Edição 2612558.** Trocar `Edition` no C# sem trocar `GameProperties` (ou o contrário) impede o boot.
8. **League / World Boss comentados.** Não é “falta traduzir”. É evento desligado.
9. **`HelpStr` e o log “GameServer is now open”.** Texto legado. Não significa que o Center seja o Game Server.
10. **Proxy WCF com `zoneId` vs implementação sem `zoneId`.** Contrato assimétrico entre `Bussiness` e `Center.Server`. Mexer num lado só quebra o login.
11. **Connection string versionada.** Troque no seu PC; não commite senha.

---

## 20. Segurança (o que o Center é e não é)

O Center **coordena**. Ele não substitui:

- autenticação HTTP (`Login.ashx` ainda pode ter `if (true)` — bypass de senha no **Request**);
- LoginKey do Flash vs Request (isso também não mora no Center);
- economia de combate (`GP_RATE` não entra no Center).

O WCF está com `security mode="None"` no `netTcpBinding`. Qualquer processo que alcance a 2009 chama `KitoffUser`, `ChargeMoney`, `SystemNotice`. Em rede pública isso é porta de administração sem senha. Em LAN de produção: firewall só para o host do Road/Request, ou ligar segurança WCF — mudança de config + teste, não “por enquanto deixa aberto”.

`CreatePlayer` aceita o `password` que o Request mandar e guarda em RAM para o `ValidateLoginAndGetID`. Não é hash de membership; é o token da sessão daquele boot.

---

## 21. Como verificar se o Center está são

Sem precisar do Flash:

1. Processo no ar, log sem exception no `Init`. A última linha feliz é a de “open for connections”.
2. `http://127.0.0.1:2008/CenterService/` responde metadata (WCF no ar).
3. Road sobe e o log do Center mostra o login do `serverid` (não o `Error Login Packet`).
4. `ServerList.ashx` devolve XML com `value="true"` e o canal 4 (Center + Request falando na 2009).
5. Console `notice&teste` — o aviso aparece no Road / no jogo se já houver cliente.

O que este doc **não** substitui: um tiro no mapa. Isso é Road + `Game.Logic` + (no match) Fighting.

---

## 22. Arquivos-chave (atalho)

```
Center.Service\Program.cs
Center.Service\Actions\ConsoleStart.cs
Center.Service\App.config
Center.Server\CenterServer.cs
Center.Server\CenterServerConfig.cs
Center.Server\CenterService.cs
Center.Server\ICenterService.cs
Center.Server\ServerClient.cs
Center.Server\ServerMgr.cs
Center.Server\LoginMgr.cs
Center.Server\WorldMgr.cs
Center.Server\ConsortiaBossMgr.cs
Center.Server\ePackageType.cs
Bussiness\ServiceBussiness.cs          (SP_Service_List)
Bussiness\Interface\BaseInterface.cs   (CreateLogin / CreatePlayer)
Bussiness\CenterService\ICenterService.cs
Game.Server\LoginServerConnector.cs
Game.Server\Packets\Client\UserLoginHandler.cs
Tank.Request\ServerList.ashx.cs
```

Road: [`DOCUMENTACAO-ROAD.md`](DOCUMENTACAO-ROAD.md) (`GameServer.cs`). Fighting: [`DOCUMENTACAO-FIGHTING.md`](DOCUMENTACAO-FIGHTING.md) + [`DOCUMENTACAO-COMBATE.md`](DOCUMENTACAO-COMBATE.md).
