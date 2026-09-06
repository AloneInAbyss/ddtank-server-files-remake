# Road.Service — o canal onde o jogador fica

Este documento descreve **o Road deste fork** (edição 10990), não o “oficial” da 7Road. Tudo abaixo foi lido em `Road.Service`, `Game.Server`, `Game.Logic` e nos conectores para Center e Fighting.

Documentos irmãos: [`DOCUMENTACAO.md`](DOCUMENTACAO.md), [`DOCUMENTACAO-CENTER.md`](DOCUMENTACAO-CENTER.md), [`DOCUMENTACAO-FIGHTING.md`](DOCUMENTACAO-FIGHTING.md), [`DOCUMENTACAO-COMBATE.md`](DOCUMENTACAO-COMBATE.md), [`GUIA-SUBIR-SERVIDOR.md`](GUIA-SUBIR-SERVIDOR.md), [`DOCUMENTACAO-MODIFICACOES.md`](DOCUMENTACAO-MODIFICACOES.md).

Este arquivo é **só o Road**. Física de tiro, dano e turnos: o doc de combate. Coordenação de canais e sessão HTTP: o doc do Center.

---

## 1. O que é, em uma frase

O Road é o **salão do restaurante**. Depois do login HTTP, o cliente Flash abre TCP aqui e “vive” neste processo: lobby, inventário, loja, chat, salas, fortalecer, farm, pet, guilda, casamento.

A comunidade também chama de **Game Server**. A empresa original era 7Road — daí o nome da pasta.

Sem o Road no ar:

- o Flash conecta na 9500 e não tem com quem falar;
- inventário, loja e missões **não existem** (o Fighting não guarda isso);
- Freedom e dungeon **não começam** (essas lutas rodam **dentro** do Road).

O jogador **nunca** fala direto com Center ou Fighting. O Road é o único TCP do cliente.

---

## 2. Por que existe (e por que é o último a ligar)

O desenho original prevê **vários canais**. Cada `Road.Service` é um salão com um `ServerID` (neste PC, **4**). O Flash escolhe o canal na lista e só então abre a 9500 daquele processo.

O Road precisa:

1. do SQL (itens, mapas, loja, o próprio cadastro do canal);
2. do **Center já escutando 9202** — senão falha em `Login To CenterServer`;
3. do **Fighting já escutando 9208** se alguém for entrar em **Match** (fila). Freedom e PvE não precisam do Fighting para *começar*, mas o `BattleMgr.Start()` tenta conectar mesmo assim.

Ordem: **SQL → IIS → Center → Fighting → Road**.

---

## 3. Duas pastas (exe + dll)

| Pasta | Tipo | Função |
|-------|------|--------|
| `Road.Service` | Executável (`net48`) | Ponto de entrada. Sem argumento assume `--start`. Título da janela: `"Road Service \| DDTank 3.0"`. |
| `Game.Server` | Biblioteca (`net472`) | Quase tudo: `GameServer`, `GamePlayer`, salas, ~160 handlers, farm, pet, casamento… |

**Executável:** `Road.Service\bin\Debug\net48\Road.Service.exe`  
Lê `Road.Service.exe.config` (cópia do `App.config`) e `battle.xml` na mesma pasta.

Também usa `Game.Logic` (regras de luta), `Bussiness` (SQL) e `Game.Base` (socket).

O namespace do exe ainda é `Game.Service` (legado “DOL”). Dá para instalar como serviço Windows com nome interno **ROAD** (`--serviceinstall`). No dia a dia local sobe no console.

---

## 4. Mapa de arquivos

### 4.1 `Road.Service`

| Arquivo | Papel |
|---------|--------|
| `Program.cs` | `Main`. Sem args → `--start`. Também registra install/start/stop de serviço. |
| `Actions/ConsoleStart.cs` | Cria `GameServer`, `Start()`, loop do console. |
| `App.config` | IP 9500, `ServerID`, Center, rates, SQL, RSA, WCF cliente. |
| `battle.xml` | **Onde o Fighting realmente está** (IP/porta/chave). Não é o `FightServerIp` do App.config. |
| `logconfig.xml` | log4net. |

### 4.2 `Game.Server` (o miolo)

| Pasta / arquivo | Papel |
|-----------------|--------|
| `GameServer.cs` | Boot, timers, lifecycle. Singleton `GameServer.Instance`. |
| `GameServerConfig.cs` | Lê App.config + sobrescreve nome/lotação pelo SQL (`SP_Service_Single`). |
| `GameClient.cs` | Uma conexão Flash. |
| `GamePlayer.cs` | Estado do personagem online. |
| `LoginServerConnector.cs` | TCP do Road → Center :9202. |
| `Packets/Client/` | Um handler por ação do cliente (`UserLoginHandler`, `ItemStrengthenHandler`…). |
| `Packets/PacketProcessor.cs` | Despacha pelo `packet.Code` (array de 512). |
| `Rooms/` | Sala de lobby: criar, entrar, Pronto, `StartGameAction`. |
| `Games/` | Loop das lutas **locais** (Freedom / PvE). |
| `Battle/` | `BattleMgr`, `BattleServer`, `FightServerConnector`, `ProxyGame` — Match. |
| `Managers/` | Dezenas de singletons (item, loja, quest, pet…). |
| `Farm/`, `Pet/`, `HotSpringRooms/`, `SceneMarryRooms/` | Sistemas do “mundo”. |
| `Consortia/`, `ConsortiaTask/` | Guilda. |
| `RingStation/`, `RobotWaiting/` | Arena vs bot / robôs. |
| `LittleGame/` | Mini-game (neste fork, “Hút Gà”). |
| `WorldBoss/` | Código de World Boss (timers do scan **comentados**). |
| `Commands/` | Comandos GM (`/…` no console). |
| `Statics/` | Logs econômicos. |

`Game.Logic` **não** é pasta do Road, mas o Road a usa para toda luta que não vai ao Fighting.

---

## 5. Portas e quem fala com quem

| Porta | Papel do Road |
|-------|----------------|
| **9500** | **Escuta.** Cliente Flash (depois do HTTP). |
| **9202** | **Cliente.** Conecta no Center (`LoginServerIp` / `LoginServerPort`). |
| **2009** | **Cliente WCF.** `CenterServiceClient` em `Bussiness` (login da sessão). |
| **9208** | **Cliente.** Conecta no Fighting; o endereço sai de **`battle.xml`**, não das chaves `FightServerIp` / `FightServerPort`. |

```
Cliente Flash ──TCP 9500──► Road.Service
                               ├── TCP 9202 ──► Center
                               ├── WCF 2009 ──► Center
                               └── TCP 9208 ──► Fighting   (só Match)
```

Há um endpoint SOAP `PassPort.asmx` no `App.config` (`admingunny`). É legado de interface de login; o fluxo local que funcionou usa `Tank.Request` + `BaseInterface`, não esse ASMX.

---

## 6. O que acontece no `Start()`

`GameServer.Start()`. Quase todo passo passa por `InitComponent`: se der `false`, chama `Stop()` e o `Start()` retorna `false`. **Exceção:** falha em `RecompileScripts()` chama `Stop()` mas **não aborta** o método (o boot pode continuar).

Ordem, agrupada:

1. `GameProperties.Refresh()` — propriedades globais **do SQL** (`ServerProperty`), não do `Edition` do App.config.
2. Compila `scripts\` ao lado do exe (pasta vazia = sucesso).
3. `ConsortiaLevelMgr`, eventos de script.
4. **Edição:** constante `GameServer.Edition = "2612558"` tem que ser igual a `GameProperties.EDITION` (linha `Edition` no banco; default do atributo também é `2612558`). Se divergir, o Road **não sobe**. A chave `Edition=10990` do App.config é outra coisa (número da árvore/cliente); **este check não a lê**.
5. Socket em `IP`:`Port` (9500) e pool de buffers (`MaxClientCount * 3` × 8 KB).
6. Dezenas de managers a partir do SQL — se **qualquer** um falhar, o processo para. Exemplos: mapa, item, caixa, ball, NPC, missão PvE, drop, fortalecer, loja, quest, pet, carta, totem, spa, Ring Station, Little Game.
7. `RoomMgr.Setup(MaxRoomCount)` e `GameMgr.Setup(ServerID, BOX_APPEAR_CONDITION)`.
8. `LanguageMgr.Setup("")` — arquivo em `LanguagePath` relativo ao exe.
9. `BattleMgr.Setup()` — lê `battle.xml`.
10. Timers (`InitGlobalTimer`).
11. `InitLoginServer()` — TCP no Center. Sem isso, acabou.
12. `InitOtherLoginServer()` — lista `id:ip:port` em `OtherLoginServer` (vazia neste config).
13. Mais managers (spa, pet moe, robô, eventos, cloth, totem…).
14. `DailyLeagueAwardMgr.Init()` está **comentado**.
15. `RoomMgr.Start()`, `GameMgr.Start()`, `BattleMgr.Start()`, `MacroDropMgr.Start()`.
16. `base.Start()` — aceita Flash na 9500.
17. Log: `"GameServer is now open for connections!"`.

`GameServerConfig` no construtor chama `GetServiceSingle(ServerID)`. Sem linha no SQL: log `Can't find server config,server id {0}` e o canal não sobe direito. Nome, `MaxRoomCount`, `MaxPlayerCount`, `ZoneId` e `ZoneName` **vêm dessa linha**, não só do XML.

---

## 7. O jogador no TCP 9500

1. Flash conecta em `IP:Port`.
2. `GetNewClient()` → `GameClient`.
3. Primeiro byte `0x3C` (`<`) → policy de cross-domain do Flash.
4. Pacotes seguintes: `PacketProcessor` despacha pelo código (0–511).
5. Handlers são classes com `[PacketHandler(code, …)]` em `Packets/Client/` (~160 arquivos). Registram no evento `ScriptEvent.Loaded`.

Login do personagem: pacote `LOGIN = 1` → `UserLoginHandler`. Resumo (detalhe da sessão: [`DOCUMENTACAO-CENTER.md`](DOCUMENTACAO-CENTER.md) §8):

1. Lê versão e `clientType` (fluxo normal espera `69`).
2. RSA decrypt (`WorldMgr.RsaCryptor`) → usuário / senha.
3. `BaseInterface.LoginGame` → WCF `ValidateLoginAndGetID` no Center.
4. Se `isFirst == true` → kitoff `UserLoginHandler.Register` e fecha o socket.
5. Cria `GamePlayer`, `LoginMgr.Add`, manda `SendAllowUserLogin` no TCP 9202.
6. Center responde allow; aí o personagem entra de verdade.

Dois `LoginMgr` diferentes: o do **Center** (sessão entre canais) e o do **Road** (`Game.Server.Managers.LoginMgr`, quem está **neste** processo). Não são a mesma classe.

---

## 8. Salas e para onde a luta vai

Tudo parte de `Game.Server\Rooms\StartGameAction.cs` quando a sala está pronta.

| Tipo de sala | Onde a luta roda | Método |
|--------------|------------------|--------|
| `Freedom` (livre) | **Neste Road** (`Game.Logic`) | `GameMgr.StartPVPGame` |
| PvE (dungeon, lab, World Boss, labirinto, academy, natal…) | **Neste Road** | `GameMgr.StartPVEGame` |
| `Match` (fila / ranked) | **Fighting** :9208 | `BattleMgr.AddRoom` → `FightServerConnector.SendAddRoom` |

`IsPVP` neste arquivo é **só** `eRoomType.Match`. Guilda na fila, liga por pontuação etc. entram por outros tipos; vários deles o `IsPVE` devolve `false` e o `IsPVP` também — a sala **não começa** por esse `StartGameAction`. Vale o enum + este `if`, não o marketing do cliente.

Se não houver Fighting no ar, Match mostra a chave `StartGameAction.noBattleServe`.

Física, turno e dano: [`DOCUMENTACAO-COMBATE.md`](DOCUMENTACAO-COMBATE.md). O Road, no Freedom/PvE, **é** o servidor de combate. No Match, ele vira **proxy**: `ProxyGame` manda o pacote do jogador ao Fighting e devolve o que o Fighting calcular.

---

## 9. Ligação com o Center

`LoginServerConnector` (`autoReconnect: true`, `Strict: true`). Chave de login do **canal**: `"{ServerID},{ServerName}"`, cifrada com RSA (mesmo esquema do doc do Center).

Depois do handshake manda `SendListenIPPort` (pacote 240) com o IP/porta que o Flash deve usar.

Ping periódico (`PingCheckInterval`, minutos): `SendPingCenter` (pacote 12) com a quantidade de jogadores — o Center atualiza lotação.

Se o Center **cair** (`loginServer_Disconnected`): o Road chama `Stop()` e tenta `Start()` de novo até **4** vezes (1 s entre tentativas). Depois desliga o log4net. Na prática, Center morto = canal morto.

O Road também é **cliente WCF** na 2009 (`CreatePlayer` / `ValidateLoginAndGetID` via `Bussiness`). Os dois caminhos (TCP 9202 + WCF 2009) precisam alcançar o mesmo Center.

---

## 10. Ligação com o Fighting

Arquivo canônico: `Road.Service\battle.xml` (copiado para o `bin`):

```xml
<list>
  <server id="4" ip="127.0.0.1" port="9208" key="1,7road" />
</list>
```

`BattleMgr.Setup()` lê isso. `BattleMgr.Start()` conecta cada entrada (`FightServerConnector`). Auth: Fighting manda RSA (pacote 0); Road responde com a `key` do XML cifrada.

As chaves `FightServerIp` e `FightServerPort` **existem no App.config e nenhum `.cs` as lê**. Mudar só elas não aponta o Match para outro host.

Se o Fighting cair: `AutoReconnect` (até 3 tentativas, janela de 3 min). Salas em Match naquele connector são limpas.

---

## 11. Timers

`InitGlobalTimer()`:

| Timer | Período | Função |
|-------|---------|--------|
| Save DB | `DBAutosaveInterval` (10 min neste config) | Grava jogadores / estado |
| Ping | `PingCheckInterval` (3 min) | Ping no Center + checagem de cliente |
| Save record | `SaveRecordInterval` (5 min) | Log estatístico |
| Buff scan | 60 s | Buffs expirados |
| Little Game | ~60 s | Abre/fecha o mini-game pela hora (`GameProperties`) |
| Rename batch | 24 h | Lote de rename |

**Comentados** (código existe, não agenda): World Boss scan 1 e 2, week scan, League scan. `DailyLeagueAwardMgr` também não inicia. **Não religar “junto com doc”.**

`LittleGameScan` **está ativo**.

---

## 12. Console

Prefixo `> `. Primeira palavra (espaço).

| Comando | Efeito |
|---------|--------|
| `exit` | `KeepRunning = false` e sai |
| `shutdown` | Contagem 6×60 s, aviso, `Stop()` |
| `clear` | Limpa a tela |
| `cp` | Contagens: clients, players, rooms, games, memória |
| `* &reload` | Recarrega um manager (`item`, `shop`, `quest`, `map`, `language`, `npc`…) |
| `reloadall` | Vários de uma vez |
| `cfg&reload` | Relê config |
| `nickname` | Busca jogador |
| `senditem` | Manda item por correio |
| `chargetouser` | Recarga na conta |
| `resetquest` | Corpo **comentado** (não faz nada) |
| `/comando` | `CommandMgr` (GM) |

Lista longa de reload está em `ConsoleStart.cs`. Quem recarrega item/loja é **este** processo; o `reload` do Center só **avisa** os Roads (pacote 11).

---

## 13. Configuração

Arquivo: `Road.Service\App.config`.

### 13.1 O que o boot realmente precisa

| Chave | Valor neste repo | Uso |
|-------|------------------|-----|
| `ServerID` | `4` | Tem que existir em `SP_Service_Single` / lista do Center |
| `IP` / `Port` | `127.0.0.1` / `9500` | Bind do Flash |
| `LoginServerIp` / `LoginServerPort` | `127.0.0.1` / `9202` | Center TCP |
| `LanguagePath` | `Languages\Language-vn.txt` | `LanguageMgr` |
| `conString` / `crosszoneString` | `Project_Player34` / `Project_Game34` | SQL (senha do autor versionada — não usar em produção) |
| `MaxClientCount` | `8000` | Pool + teto de socket |
| `PrivateKey` | XML RSA | Decrypt do login Flash. **Chave privada no git.** |
| `InterName` | `SevenRoad` | Qual `BaseInterface` instanciar |

Depois do SQL: `ServerName`, lotação e zona saem da linha do canal.

WCF: `net.tcp://127.0.0.1:2009/` — mesmo host do Center.

### 13.2 Rates no App.config

`MONEY_*`, `EXP_*`, `GIFT_*` o `PVPGame` **usa** nas recompensas (Freedom neste processo; Match no Fighting lê o **próprio** `App.config`).

`GP_RATE`, `LeagueMoney_Win`, `LeagueMoney_Lose` são **declarados** em `PVPGame` e **não entram** no `GameOver` deste fork. `Gold_Rate`, `Gift_Rate`, `Xu_Rate` no XML do Road também não puxam o cálculo. Detalhe: [`DOCUMENTACAO-COMBATE.md`](DOCUMENTACAO-COMBATE.md).

Várias chaves de casamento / fortalecer (`HymenealMoney`, `MustStrengthenGold`…) ou vão para `GameProperties` (SQL) ou **não têm leitura em `.cs`**. Não assuma que mudar o XML muda o preço — confira se `GameProperties` ou o handler lê aquela chave.

### 13.3 O que **não** está neste XML

- AAS: vem do Center (pacotes 7/8).
- Fighting: `battle.xml`.
- `GameProperties.EDITION`: banco.

---

## 14. Scripts

`RecompileScripts()`: pasta `{exe}\scripts\`. Zero `.cs` = ok. Senão compila para `ScriptCompilationTarget` (`GameServerScripts.dll`) com as DLLs de `ScriptAssemblies`.

Scripts de **missão PvE** (pasta `scripts/` na raiz do repo / ao lado do Road) são C# carregado em runtime pelo `Game.Logic`. Erro de compile **derruba** o `Init` se a compilação falhar de verdade. Depois de mudar script, o processo precisa subir de novo (ou o fluxo de compile do boot).

---

## 15. O que você pode modificar

Ordem do repo: **config → SQL → idioma → C#**.

### Sem recompilar o Road

- `App.config`: IP público da 9500, `ServerID`, apontar o Center, intervalos, `LanguagePath`.
- `battle.xml`: IP/porta/chave do Fighting.
- SQL: item, loja, quest, drop, NPC, mapas, linha do canal (`SP_Service_Single` / `SP_Service_List`).
- Console `item&reload` / `shop&reload` (depois de mudar o SQL).
- Arquivo de idioma no `bin`.

### Recompilando `Game.Server`

- Handler novo, regra de sala, farm, pet, fortalecer.
- Consertar `IsFirst`, bypass, economia.
- Religar World Boss / League **nos timers** — só com teste ponta a ponta.

### O que **não** se muda aqui

| Quer mudar | Onde é |
|------------|--------|
| Lista de canais, sessão entre canais, leilão global | Center |
| Fila Match, pairing | Fighting |
| Física do projétil | `Game.Logic` (Freedom/PvE usam daqui; Match no Fighting usa a **mesma** dll) |
| Tela / botão | Flash `language.txt` / SWF |
| HTML de login, `if (true)` do `Login.ashx` | `Tank.Flash` / `Tank.Request` |

---

## 16. Armadilhas deste fork

1. **Último a ligar.** Sem Center a 9202 o `Init` morre. Sem linha `ServerID=4` no SQL, `Can't find server config`.
2. **Edição 2612558 vs 10990.** O check compara SQL `GameProperties.EDITION` com a constante C#. Trocar só o `Edition` do App.config **não** alinha esse teste.
3. **`FightServerIp` mentiroso.** Vale `battle.xml`.
4. **`IsFirst`.** Personagem existente com flag `true` = kick em milissegundos. Ver doc do Center e [`DOCUMENTACAO-AMBIENTE-LOCAL.md`](DOCUMENTACAO-AMBIENTE-LOCAL.md).
5. **Dois LanguagePath.** Center, Road e Fighting cada um lê o arquivo do **próprio** `bin`.
6. **Rates diferentes** no Road e no Fighting: Match usa o XML do Fighting; Freedom usa o do Road. Os números **não são iguais** neste repo.
7. **World Boss / League** têm handler e scan escritos, timers desligados.
8. **`GP_RATE` / `LeagueMoney_*`** no XML não mudam o `GameOver`.
9. **PrivateKey e senha SQL** no App.config versionado.
10. **Center caiu** → Road tenta 4 restarts e morre junto.
11. **Match sem Fighting** → `StartGameAction.noBattleServe`. Freedom ainda funciona.
12. Recarregar item no console do Center **não** recarrega o Road sozinho — precisa do pacote 11 *e* do handler daquele tipo, ou `item&reload` aqui.

---

## 17. Segurança

- A 9500 é a porta do **jogador**. Firewall: só o que o cliente precisa; 9202/2009/9208 ficam na LAN dos processos.
- `PrivateKey` no XML é a chave que abre o login Flash. Não commitar chave de produção.
- O Road confia no Center para kitoff, charge e allow. Center WCF sem segurança (`mode="None"`) = quem alcança a 2009 manda no canal.
- `Login.ashx` com `if (true)` **não é deste processo**, mas o Road aceita a sessão que o Center gravou.

---

## 18. Como verificar se o Road está são

1. Log do `Init` sem `False` (exceto o detalhe do script vazio). Última linha feliz: open for connections.
2. Log do Center mostra login do `serverid` 4, sem `Error Login Packet`.
3. `battle.xml` aponta para um Fighting que já está no ar (se for testar Match).
4. Flash (ou Electron) entra no canal e o lobby carrega.
5. Console `cp` mostra clients/players > 0.
6. Freedom: criar sala, Pronto, começar — luta **neste** processo (`GameMgr`).
7. Dungeon: mesmo caminho local. Prédio sem gráfico = resource, não necessariamente crash do Road.

O que este doc **não** substitui: um tiro no mapa (doc de combate) nem a lista de canais (doc do Center).

---

## 19. Arquivos-chave

```
Road.Service\Program.cs
Road.Service\Actions\ConsoleStart.cs
Road.Service\App.config
Road.Service\battle.xml
Game.Server\GameServer.cs
Game.Server\GameServerConfig.cs
Game.Server\GameClient.cs
Game.Server\GamePlayer.cs
Game.Server\LoginServerConnector.cs
Game.Server\Packets\Client\UserLoginHandler.cs
Game.Server\Packets\PacketProcessor.cs
Game.Server\Rooms\StartGameAction.cs
Game.Server\Battle\BattleMgr.cs
Game.Server\Battle\FightServerConnector.cs
Game.Logic\BaseGame.cs
Bussiness\GameProperties.cs
Bussiness\ServiceBussiness.cs          (GetServiceSingle / SP_Service_Single)
```
