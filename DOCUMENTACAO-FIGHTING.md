# Fighting.Service — o servidor de Match

Este documento descreve **o Fighting deste fork**, não o “oficial” da 7Road. Tudo abaixo foi lido em `Fighting.Service`, `Fighting.Server`, `Game.Logic` e no conector `Game.Server\Battle\`.

Documentos irmãos: [`DOCUMENTACAO.md`](DOCUMENTACAO.md), [`DOCUMENTACAO-CENTER.md`](DOCUMENTACAO-CENTER.md), [`DOCUMENTACAO-ROAD.md`](DOCUMENTACAO-ROAD.md), [`DOCUMENTACAO-COMBATE.md`](DOCUMENTACAO-COMBATE.md) (física, dano, turnos, recompensas).

Este arquivo é **o processo**. Como a bola voa e o dano fecha: o doc de combate. O Fighting **só entra** no PvP de fila (`eRoomType.Match`).

---

## 1. O que é, em uma frase

O Fighting é a **cozinha do ranked**. O jogador não entra aqui. O Road manda a sala pela porta **9208**; o Fighting emparelha duas salas e roda o **mesmo** `Game.Logic` que o Road usa no Freedom.

Sem o Fighting no ar:

- Freedom e dungeon **continuam** (rodam no Road);
- clicar em Match / fila mostra `StartGameAction.noBattleServe`;
- o Road ainda sobe — `BattleMgr.Setup()` aceita lista vazia / conexão que falha; o canal não depende da 9208 para o `Init` do lobby.

---

## 2. Por que existe

Um canal (Road) aguenta lobby + Freedom + PvE. Match precisa **juntar salas que não se conhecem** — às vezes de canais diferentes, no desenho original — e simular a luta sem bloquear o salão.

Por isso o Fighting:

1. **escuta** TCP (o Road é o cliente);
2. guarda cada sala como `ProxyRoom`;
3. a cada **5 s** tenta emparelhar;
4. cria um `BattleGame` (`PVPGame` que fala com os jogadores **via** o Road);
5. no fim, manda o resultado de volta para o Road **aplicar** ouro, item, GP no personagem de verdade.

O Fighting **não** tem inventário persistente. Ele recebe um **snapshot** na criação da sala e devolve deltas.

Ordem de ligar: Center → **Fighting** → Road. O Fighting **não** conversa com o Center. Sem SQL ele ainda precisa dos managers de mapa/item/ball/drop (os mesmos `*Mgr.Init()` do `Bussiness`).

---

## 3. Duas pastas (exe + dll)

| Pasta | Tipo | Função |
|-------|------|--------|
| `Fighting.Service` | Executável (`net48`) | `Program.cs` sem args → `--start`. Título: `"Fighting Service \| DDTank 3.0"`. |
| `Fighting.Server` | Biblioteca | `FightServer`, `ServerClient`, `ProxyRoom`, `BattleGame`. |

**Executável:** `Fighting.Service\bin\Debug\net48\Fighting.Service.exe`

Não há WCF, HTTP nem SOAP neste processo. Só TCP binário (`GSPacketIn`).

---

## 4. Mapa de arquivos

### 4.1 `Fighting.Service`

| Arquivo | Papel |
|---------|--------|
| `Program.cs` | `Main` (`[MTAThread]`). Só registra `ConsoleStart`. |
| `Action/ConsoleStart.cs` | `FightServerConfig.Load()` → `CreateInstance` → `Start()` → console. |
| `App.config` | Bind 9208, rates de `PVPGame`, SQL, idioma. |
| `logconfig.xml` | log4net. |

### 4.2 `Fighting.Server`

| Arquivo | Papel |
|---------|--------|
| `FightServer.cs` | Boot, socket, managers, `SendToALL` para os Roads conectados. |
| `FightServerConfig.cs` | `Load()` manual do App.config (não usa o `LoadConfiguration()` baseado em `[ConfigProperty]`). |
| `ServerClient.cs` | **Um** Road. Handshake RSA, create/cancel room, dados de jogo. |
| `Rooms/ProxyRoom.cs` | Espelho da sala do Road. |
| `Rooms/ProxyRoomMgr.cs` | Thread 20 ms; matchmaking 5 s; limpeza 250 ms. |
| `Games/GameMgr.cs` | Thread **40 ms** das lutas. `StartBattleGame`. |
| `Games/BattleGame.cs` | `extends PVPGame`; roteia pacote pela `ProxyRoom`. |
| `GameObjects/ProxyPlayer.cs` | `IGamePlayer` que manda callback ao Road (gold, item…). |
| `Guild/GuildMgr.cs` | Stub: `FindGuildRelationShip` devolve **2**. |
| `Servers/ServerMgr.cs` | Vazio. |

`Fighting.Server\Games\GameMgr.StartPVPGame` **existe e ninguém chama**. Match usa `StartBattleGame`.

Protocolo Road↔Fighting: `Game.Logic\Protocol\eFightPackageType.cs` (não o `ePackageType` do Flash).

---

## 5. Portas

| Porta | Quem escuta | Quem conecta |
|-------|-------------|--------------|
| **9208** | Fighting (`IP` + `Port` do App.config) | Cada Road listado em `battle.xml` |

O cliente Flash **não** abre 9208. Se um firewall bloquear 9208 só entre os `.exe`, o lobby funciona e o Match não.

O Road descobre este host em `Road.Service\battle.xml` (`ip`, `port`, `key`). As chaves `FightServerIp` / `FightServerPort` do App.config do Road **não são lidas**.

---

## 6. O que acontece no `Start()`

`FightServer.Start()`. `InitComponent` falso → `Stop()` e aborta.

1. Socket em `m_config.Ip`:`Port`.
2. `RecompileScripts()` — pasta `scripts\` ao lado do exe; referências **hardcoded** (`Game.Base`, `Game.Logic`, `SqlDataProvider`, `Bussiness`, `System.Drawing`). Compila **uma vez** por processo (`m_compiled`).
3. Eventos de script.
4. `ProxyRoomMgr.Setup()` (cria a thread, ainda não liga).
5. `GameMgr.Setup(0, 4)` — `serverId=0`, `boxBroadcastLevel=4`.
6. SQL/managers: mapa, item, prop, ball, ball config, drop, NPC, vento, idioma.
7. `ScriptEvent.Loaded`.
8. `base.Start()` — `Listen(100)`, accept.
9. `ProxyRoomMgr.Start()` e `GameMgr.Start()`.
10. Log legado: `"GameServer is now open for connections!"` (é o **Fighting**).

Não há check de `Edition` 2612558 neste processo. Não conecta no Center.

`FightServerConfig.Load()` lê `AppSettings["Ip"]` e o XML tem a chave `IP`. No .NET Framework **Windows** o `AppSettings` costuma ser case-insensitive — por isso o boot local funciona. `ScriptCompilationTarget` no `Load()` é preenchido com o valor de **`ScriptAssemblies`** (chave errada). Pasta `scripts` vazia mascara isso.

---

## 7. Do clique em Pronto até o tiro

1. Sala `Match` no Road, todo mundo Pronto → `StartGameAction` → `BattleMgr.AddRoom`.
2. Road manda pacote **64** (`SendAddRoom`): `roomId`, tipo, guilda, NPC de pickup, snapshot de cada jogador (stats, equip, pet, cartas, buffers).
3. Fighting: `HandleGameRoomCreate` → `ProxyRoom` na fila (`orientRoomId` = id da sala no Road).
4. A cada **5000 ms** `PickUpRooms()` tenta achar um par.
5. Achou: `GameMgr.StartBattleGame` → `BattleGame`, `roomType = Match`, `timeType = 2`.
6. Fighting manda pacote **66** (`SendStartGame`); o Road vira `ProxyGame`.
7. Durante a luta: Flash → Road → pacote **2** → `game.ProcessData`; o Fighting devolve pelo **67** (`SendToRoom`) e o Road espelha na sala.
8. Tick da luta: **40 ms** (`GameMgr.THREAD_INTERVAL`). Thread das salas: **20 ms**.
9. `TurnIndex >= 100` em Match força `GameOver` (`CheckPVPGameStateAction`).
10. Fim: Fighting **68** (`SendStopGame`); Road para o proxy e aplica o que já recebeu (gold, money, gift, itens, league money…).

Se não houver Fighting, o passo 1 falha no Road e o jogador nunca chega aqui.

---

## 8. Regras de emparelhamento

`ProxyRoomMgr`, a cada 5 s, só olha sala que **não** está jogando (`Game == null`).

| `eGameType` | Critério (código) |
|-------------|-------------------|
| `Guild` | Guildas diferentes, mesmo `PlayerCount` > 1, mesma `ZoneId`; score (relação + FP + level) |
| `ALL` | Mesmo count, mesma zone, `CalculateScore < 2`, `PickUpCount < 3` |
| Default | Faixa de level (`PickUpRateLevel`) ou FP (`PickUpRate`); escolhe a mediana |

`PickUpCount` sobe a cada tick. Se `>= 4`, tem `NpcId`, sala `Match` e não é guild → pacote **88** (`SendBeginFightNpc`): o Road cria autobot (`RingStationMgr`). É assim que a fila “contra bot” nasce quando ninguém aparece.

`GuildMgr.FindGuildRelationShip` neste fork **sempre devolve 2** — a parte “relação de guilda” do score não lê SQL.

---

## 9. O que o Fighting calcula e o que o Road grava

`BattleGame` herda `PVPGame` (`Game.Logic`). Ângulo, vento, cavado, dano, pet, carta: **a mesma fórmula** do Freedom. Doc: [`DOCUMENTACAO-COMBATE.md`](DOCUMENTACAO-COMBATE.md).

Recompensa: `PVPGame.GameOver` neste Fighting lê **o App.config deste exe** (`MONEY_*`, `EXP_*`, `GIFT_*`, `DoubleEvent`). Os valores **não são os do Road** — neste repo o Match dá faixas diferentes (ex.: money lose 400–500 aqui vs 30–35 no Road).

`GP_RATE`, `LeagueMoney_Win`, `LeagueMoney_Lose` estão no XML e em campos estáticos; **não entram** no `GameOver`. League money, se existir, chega ao personagem por callback `AddLeagueMoney` no Road (pacote 84 no conector), não por esses três campos no cálculo local.

O Fighting **não** abre correio, loja, farm, Center. `conString` serve para os `*Mgr.Init()` (template de item/mapa/drop), não para o personagem `User`.

---

## 10. Pacotes Road ↔ Fighting (os que o código trata)

Amostra. Lista completa: `ServerClient.OnRecvPacket` e `FightServerConnector`.

| Código | Direção | Função |
|--------|---------|--------|
| 0 | F→R | RSA pública |
| 1 | R→F | Login do **canal** (key do `battle.xml`) |
| 2 | R→F | Dados do jogador para o `BaseGame` |
| 64 | R→F | Criar sala na fila |
| 65 | ambos | Cancelar / remover sala |
| 66 | F→R | Luta começou |
| 67 | F→R | Pacote para a sala (Flash) |
| 68 | F→R | Luta acabou |
| 83 | R→F | Jogador saiu no meio |
| 88 | F→R | Começar vs NPC/bot |
| 32–52, 74–75… | F→R | Aplicar gold, item, GP, etc. no `GamePlayer` |

Handshake: a `key` do XML tem que bater com o que o Fighting descriptografa. Neste repo: `1,7road`.

---

## 11. Console

| Comando | Efeito |
|---------|--------|
| `exit` | `Stop()` (para jogos, salas, socket) |
| `clear` | Limpa a tela |
| `list -client` | Roads conectados (`ServerClient`) |
| `list -room` | `ProxyRoom` |
| `list -game` | Jogos em `GameMgr` |
| `cfg&reload` | `RefreshSection("appSettings")` |
| `drop&reload` | `DropMgr.ReLoad()` |

`HelpStr` lê uma chave que **não está** no App.config.

`Stop()`: `GameMgr.Stop()` → `ProxyRoomMgr.Stop()` → fecha o listen e desconecta os Roads. `ServerClient.OnDisconnect` **não** limpa `ProxyRoom` órfã de forma explícita — salas podem ficar até o cleanup de 250 ms / jogo parado (60 s).

---

## 12. Configuração (`App.config`)

| Chave | Neste repo | Lida de verdade? |
|-------|------------|------------------|
| `IP` / `Port` | `127.0.0.1` / `9208` | Sim (`Load()` → `Ip`, `Port`) |
| `ServerID` | `4` | Vira `ZoneId` |
| `LanguagePath` | `Languages\Language-vn.txt` | `LanguageMgr` |
| `conString` | `Project_Player34` | Managers no `Init` |
| `Logconfig` | `logconfig.xml` | Sim (`Logconfig`, não `LogConfigFile`) |
| `MONEY_*` / `EXP_*` / `GIFT_*` | faixas do Match | `PVPGame` |
| `DoubleEvent` | `false` | `PVPGame` |
| `GP_RATE`, `LeagueMoney_*` | 0 / 3 / 8 | Campo estático; **não** o `GameOver` |
| `TimeForLeague` | `19:30\|21:30` | **Nenhuma** referência |
| `IsSoloBattle` | `false` | **Nenhuma** referência |
| `GameType`, `AreaID`, `LogPath` | 1 / 1001 / RecordLog | **Não** usados no Fighting.Server |
| `Gold_Rate`, `Gift_Rate` | `0` | **Não** no `GameOver` deste fork |
| `crosszoneString` | Game34 | Sem uso direto neste projeto |
| `ScriptCompilationTarget` / `ScriptAssemblies` | dlls | `Load()` copia Assemblies nos **dois** campos; `RecompileScripts` ignora a lista do XML e usa string fixa |

Senha SQL do autor no XML versionado: não tratar como produção.

---

## 13. O que você pode modificar

### Sem recompilar

- `App.config`: bind da 9208, rates **que o `PVPGame` lê**, idioma, SQL dos templates.
- `battle.xml` **no Road** (para o canal achar este host).
- `drop&reload` no console.

### Recompilando

- Regra de pairing em `ProxyRoomMgr`.
- `BattleGame` / callbacks em `ProxyPlayer`.
- Qualquer física: `Game.Logic` (afeta Freedom no Road **e** Match aqui). Documentar no doc de combate na mesma mudança.

### O que **não** se muda aqui

| Quer mudar | Onde é |
|------------|--------|
| Lobby, inventário, loja, farm | Road |
| Lista de canais, sessão, correio global | Center |
| Freedom / dungeon | Road + `Game.Logic` |
| Cliente | Flash |

Não invente `GP_RATE` no Fighting como se mudasse a XP da fila. Neste código, não muda.

---

## 14. Armadilhas

1. **Não é o servidor de “toda luta”.** Só Match. Testar dungeon no Fighting não faz sentido.
2. **Rates do XML deste exe**, não os do Road. Copiar um `App.config` no outro altera economia sem você perceber.
3. **`battle.xml` vs `FightServerIp`.** Vale o XML do Road.
4. **`Ip` vs `IP`.** Windows perdoa; não dependa disso em outro host.
5. **`TimeForLeague` no XML não abre liga.** Liga no Center/Road está comentada.
6. **Guild match** usa stub de relação.
7. **Sem snapshot completo no pacote 64** (versão de cliente/Road diferente) a luta nasce torta — o Fighting não busca o personagem no SQL.
8. Fighting caiu no meio: Road `ProxyGame.Stop()`; reconnect limitado (3× / 3 min).
9. Log “GameServer is now open” — texto herdado.

---

## 15. Como verificar

1. Processo no ar; `InitSocket Port:9208` True.
2. Road já ligado: no Fighting, `list -client` mostra o conector.
3. Duas salas Match (ou uma + espera de bot): `list -room`, depois `list -game`.
4. Sem Fighting: no Road a fila falha com `StartGameAction.noBattleServe`; Freedom ainda abre.

Não dá para “abrir o Flash na 9208”. Sem browser: os `list` do console + log do Road no `AddRoom`.

---

## 16. Arquivos-chave

```
Fighting.Service\Program.cs
Fighting.Service\Action\ConsoleStart.cs
Fighting.Service\App.config
Fighting.Server\FightServer.cs
Fighting.Server\FightServerConfig.cs
Fighting.Server\ServerClient.cs
Fighting.Server\Rooms\ProxyRoomMgr.cs
Fighting.Server\Rooms\ProxyRoom.cs
Fighting.Server\Games\GameMgr.cs
Fighting.Server\Games\BattleGame.cs
Fighting.Server\GameObjects\ProxyPlayer.cs
Game.Logic\PVPGame.cs
Game.Logic\Actions\CheckPVPGameStateAction.cs
Game.Logic\Protocol\eFightPackageType.cs
Game.Server\Rooms\StartGameAction.cs
Game.Server\Battle\BattleMgr.cs
Game.Server\Battle\FightServerConnector.cs
Road.Service\battle.xml
```
