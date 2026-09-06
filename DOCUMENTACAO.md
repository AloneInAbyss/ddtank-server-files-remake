# DDTank 4.1 — Documentação completa do projeto

**Para subir o jogo neste PC, use o passo a passo:** [`GUIA-SUBIR-SERVIDOR.md`](GUIA-SUBIR-SERVIDOR.md).

**O que dá para alterar no jogo (config, SQL, C#, Flash, resource):** [`DOCUMENTACAO-MODIFICACOES.md`](DOCUMENTACAO-MODIFICACOES.md).

**Como o combate funciona (turnos, física, dano, PvE, recompensas):** [`DOCUMENTACAO-COMBATE.md`](DOCUMENTACAO-COMBATE.md).

**O que foi instalado neste PC, o boot até o lobby (5/set/2026) e como desfazer:** [`DOCUMENTACAO-AMBIENTE-LOCAL.md`](DOCUMENTACAO-AMBIENTE-LOCAL.md).

Este documento explica, do zero, o que é este repositório, como um servidor de DDTank funciona, o que já existe aqui e o que ainda falta para o jogo realmente abrir.

Você **não precisa saber programar** para entender o texto. Quando um termo técnico aparecer, ele é explicado na hora.

---

## 1. Resposta direta: dá para rodar um servidor com o que está aqui?

**Neste PC, sim — até o lobby.** Em 5 de setembro de 2026 o boot local chegou na cidade (canal Local, personagem da conta de teste). Detalhe do que foi instalado e patchado: [`DOCUMENTACAO-AMBIENTE-LOCAL.md`](DOCUMENTACAO-AMBIENTE-LOCAL.md).

O pacote **ainda não** é “produção”: senha frouxa, IP do autor no SQL, resource 3.6 com cliente 4.1 (prédio de dungeon sem figurinha), sem pt-BR. O código do servidor em si estava completo; faltava alinhar SQL, IIS, Flash e o TCP do Road.

| Peça | Está no projeto? | Sem isso, o que acontece? |
|------|------------------|---------------------------|
| Código dos 3 servidores (Center, Game, Fighting) | Sim | Sem eles não existe servidor |
| Site de login no navegador (`Tank.Flash`) | Sim | Não entra pelo browser |
| API HTTP que o Flash chama (`Tank.Request`) | Sim | O cliente não carrega itens, mapas, login |
| Painel de administrador (`GameAdmin`) | Sim (incompleto / desatualizado) | Não consegue enviar itens pelo painel |
| Cliente Flash compilado (interfaces `.swf`) | Sim, ~120 arquivos | Sem isso a tela do jogo não existe |
| Código-fonte do cliente Flash (ActionScript) | Sim | Só precisa se for modificar o cliente |
| Launcher Windows + API PHP | Sim | Só precisa se quiser entrar pelo executável, não pelo site |
| Backups do SQL Server (`.bak`) | Sim, 3 arquivos | Sem banco o servidor nem inicia |
| Pasta de **recursos gráficos** (`/resource/`) | **Não** | Mapas, personagens, armas e sons não aparecem |
| Banco do launcher (`Member_GMP`) | **Não** | Launcher PHP não autentica |
| Configurações apontando para o **seu** PC | **Não** | Tudo ainda aponta para o PC do autor original (Vietnã) |
| Pacote IIS pronto / script de instalação | **Não** | Você precisa publicar os sites na mão |

**Conclusão:** este repositório é um **emulador completo de servidor DDTank** (fork vietnamita da linha Gunny / 7Road / DDTank 3.0, edição **10990**). Com Visual Studio, SQL Server, IIS e o pacote de resources, dá para subir. Sem o pacote `/resource/` e sem ajustar as configs, o servidor até pode iniciar, mas o jogo **não carrega de verdade**.

---

## 2. O que é o DDTank (e o que é “servidor privado”)

**DDTank** (também chamado DanDanTang, Gunny, Boomz, conforme o país) é um jogo de tiro por turnos, em 2D, feito em **Adobe Flash**. O jogador escolhe ângulo e força, atira, e o oponente responde.

O jogo oficial era dividido em duas partes:

1. **Cliente** — o que você vê (Flash no navegador ou launcher).
2. **Servidor** — um conjunto de programas no computador da empresa que guarda contas, itens, salas e calcula as batalhas.

Este projeto é o **código do servidor** (e também o código do cliente Flash) usado por servidores privados. Ele **não é o jogo oficial**. Foi publicado no GitHub por um grupo vietnamita (Cyrus Team / Gun Đại Việt). A solution do Visual Studio se chama `DDTank 3.0.sln`; a pasta do projeto se chama `DDTank41` porque essa linhagem é conhecida como **DDTank 4.1 / Gunny 3.x**.

O cliente fala com o servidor de dois jeitos:

- **HTTP** (páginas e arquivos `.ashx`) — baixa listas de itens, mapas, missões, ranking.
- **TCP** (conexão persistente, como um chat) — login no canal, sala, chat, movimento, tiros.

---

## 3. Como as peças se encaixam (visão geral)

Imagine um restaurante:

| Peça do projeto | Analogia | O que faz de verdade |
|-----------------|----------|----------------------|
| **SQL Server** | O estoque e o caderno de pedidos | Guarda contas, itens, guildas, configs |
| **Center.Service** | A recepção / central | Lista de servidores, correio, leilão, coordenação |
| **Road.Service** (Game Server) | O salão | O jogador “vive” aqui: lobby, inventário, loja, chat, salas |
| **Fighting.Service** | A cozinha | Calcula a batalha (física do tiro, dano, turnos) |
| **Tank.Flash** | A porta da rua | Site: login, registro, página que embute o Flash |
| **Tank.Request** | O cardápio impresso | API HTTP: o Flash pede “me dá a lista de armas” e recebe XML |
| **GameAdmin** | O escritório do gerente | Painel web para enviar itens / administrar |
| **Source Flash** | O “visual” do jogo | Cliente ActionScript + SWFs já compilados |
| **Source Launcher** | Um aplicativo de desktop | Launcher Windows + API PHP de recarga (MoMo, cartão) |

Fluxo quando alguém clica em **Jogar**:

```
Navegador ou Launcher
        │  HTTP (login / token)
        ▼
 Tank.Flash  ──────►  Tank.Request (CreateLogin + Login.ashx)
        │                      │
        │  abre Loading.swf    │  XML de itens, mapas, quests...
        ▼                      │
 Cliente Flash ────────────────┘
        │
        │  TCP porta 9500
        ▼
 Road.Service  (Game.Server)   ←── jogador fica aqui
        │
        ├── TCP 9202 ──► Center.Service     (coordenação)
        └── TCP 9208 ──► Fighting.Service   (quando começa a luta)
```

Ordem obrigatória de ligar:

1. SQL Server (bancos restaurados)
2. IIS (sites `Tank.Flash` e `Tank.Request` no ar)
3. **Center.Service**
4. **Fighting.Service**
5. **Road.Service** (ele se conecta nos dois anteriores; se eles não estiverem no ar, o Game Server falha)

---

## 4. Mapa de pastas (o que é cada coisa)

Tudo fica em `e:\Arquivos\Projetos\DDTank41`.

### 4.1 Servidores (o coração)

| Pasta | Tipo | Função |
|-------|------|--------|
| `Center.Service` | Programa executável (`.exe`) | Liga o servidor central. Ponto de entrada: `Program.cs`. |
| `Center.Server` | Biblioteca (`.dll`) | Toda a lógica do Center: lista de canais, timers de correio/leilão/guilda, serviço WCF. Classe principal: `CenterServer`. |
| `Road.Service` | Programa executável | Liga o **canal de jogo**. É o processo ao qual o jogador se conecta. |
| `Game.Server` | Biblioteca | Mundo do jogo: jogador, salas, pacotes de rede (~166 handlers), farm, casamento, pets, etc. Classe principal: `GameServer`. |
| `Fighting.Service` | Programa executável | Liga o servidor de batalha. |
| `Fighting.Server` | Biblioteca | Instâncias de luta. Classe principal: `FightServer`. |
| `Game.Logic` | Biblioteca | Regras da batalha: física, efeitos, pets, cartas, NPCs, missões PvE. Usada pelo Game e pelo Fighting. |
| `Game.Base` | Biblioteca | Rede de baixo nível: socket, pacotes, scripts, comandos de console. |
| `Bussiness` | Biblioteca | Camada de negócio e acesso ao SQL. Quase tudo é stored procedure (`SP_Items_All`, `SP_Users_Items_Add`…). |
| `SqlDataProvider` | Biblioteca | Modelos de dados (classes que representam uma linha de tabela) e o helper `Sql_DbObject`. |
| `Road.Flash` | Biblioteca | Monta XML/JSON que o Flash entende e faz criptografia RSA do login. |

### 4.2 Sites web

| Pasta | Função |
|-------|--------|
| `Tank.Flash` | Site ASP.NET do login. `index.htm` é a tela de entrar/registrar. `playgame.aspx` embute o `Loading.swf`. |
| `Tank.Request` | Dezenas de arquivos `.ashx` (handlers HTTP). O Flash chama isso o tempo todo. |
| `GameAdmin` | Painel “Gunny Admin” para GM. Usa nomes de banco **antigos** (`Db_Tank`), diferentes do resto do projeto. |

### 4.3 Cliente e launcher

| Pasta | Função |
|-------|--------|
| `Source Flash` | Código ActionScript 3 em `src/` + build em `FlashSV1/` (SWFs, XMLs de UI em vietnamita). |
| `Source Launcher` | Launcher Windows (`Gun321.Client`) e API PHP em `api/` (login, recarga, MoMo). |
| `Tank.Data` | Biblioteca extra de ferramentas/admin. **Não** entra na solution principal. |

### 4.4 Dados e resto

| Pasta / arquivo | Função |
|-----------------|--------|
| `Database/` | Três backups SQL: `Db_Membership.bak` (~5 MB), `Player34.bak` (~15 MB), `Game34.bak` (~21 MB). |
| `libdll/` | DLLs de terceiros (JSON, compressão, etc.). |
| `packages/` | Pacotes NuGet do Visual Studio. |
| `DDTank 3.0.sln` | Solution principal dos servidores. |
| `Request.sln` | Solution só do `Tank.Request`. |
| `README.md` | Quase vazio: só Discord/YouTube do Cyrus Team. |

Não existe pasta `resource/` neste repositório. Isso é o buraco mais grave para jogar.

---

## 5. Os três servidores, em detalhe

### 5.1 Center.Service — o “cérebro coordenador”

- **Executável:** `Center.Service\bin\Debug\net48\Center.Service.exe`
- **Como sobe:** ao abrir, se você não passar argumento, ele assume `--start`.
- **Portas:**
  - **9202** — TCP. O Game Server se conecta aqui (configurado como `LoginServerPort`).
  - **2008** — HTTP do WCF (`http://127.0.0.1:2008/CenterService/`).
  - **2009** — WCF `net.tcp`. Usado por `Tank.Request`, `Road.Service` e `GameAdmin`.

Ele **não** é o lugar onde o jogador “joga”. Ele:

- registra quais canais (Game Servers) estão online;
- varre periodicamente correio, leilão e guildas;
- publica avisos do sistema;
- controla prêmio diário e algumas flags globais.

Configuração: `Center.Service\App.config`.

### 5.2 Road.Service — o canal onde o jogador fica

Este é o servidor que a comunidade chama de **Game Server** ou **Road Server**.

- **Executável:** `Road.Service\bin\Debug\net48\Road.Service.exe`
- **Porta do jogador:** **9500**
- **Conecta no Center:** `127.0.0.1:9202`
- **Conecta no Fighting:** `127.0.0.1:9208`
- **ID do canal:** `ServerID = 4` (precisa existir na tabela de servidores do banco)

Na inicialização ele carrega dezenas de gerenciadores a partir do SQL. Se **qualquer** um falhar, o processo **para**. Exemplos do que ele carrega (`Game.Server\GameServer.cs`):

- mapas, itens, caixas, projéteis (balls)
- NPCs, missões PvE, drops
- loja, quests, achievements
- fortalecimento, fusão, refinaria
- guildas (consortia), casamento, hot spring
- pets, cartas, totens, títulos
- Ring Station (arena vs bot), robôs, Little Game
- conexão com o Center e com o Fighting

O `ServerID` precisa bater com uma linha no banco. O código busca isso em `ServiceBussiness.GetServiceSingle(ServerID)`. Se não achar, o log diz `Can't find server config` e o canal não sobe direito.

Há ~166 handlers de pacote em `Game.Server\Packets\Client\` — cada um trata uma ação do cliente (login, criar sala, fortalecer item, etc.).

### 5.3 Fighting.Service — a batalha

- **Executável:** `Fighting.Service\bin\Debug\net48\Fighting.Service.exe`
- **Porta:** **9208**
- O jogador **não** conecta direto nele. O Road Server manda a sala para cá quando a luta começa.
- A física (ângulo, vento, dano, efeitos de pet/equip) roda em `Game.Logic`.

### 5.4 Mapa de portas

| Porta | Quem escuta | Protocolo | Quem conecta |
|-------|-------------|-----------|--------------|
| 80 | IIS | HTTP | Navegador, Flash, launcher |
| 2008 | Center | HTTP (WCF metadata) | Ferramentas / debug |
| 2009 | Center | net.tcp (WCF) | Road, Tank.Request, GameAdmin |
| 9202 | Center | TCP | Road.Service |
| 9208 | Fighting | TCP | Road.Service |
| 9500 | Road (Game) | TCP | Cliente Flash (depois do login HTTP) |

As URLs `9001` e `840` que aparecem no `Tank.Request\Web.config` são só redirecionamentos de “sair do jogo” / “favoritos”. Não são serviços deste repositório.

---

## 6. Os sites web

### 6.1 Tank.Flash — porta de entrada no navegador

Arquivos importantes:

| Arquivo | Papel |
|---------|--------|
| `index.htm` | Tela de login e registro (textos em vietnamita). |
| `checkuser.ashx` | Confere usuário/senha no banco `Db_Membership`. |
| `loading.htm` | Tela intermediária depois do login. |
| `LoginGame.aspx` | Gera o token e chama `CreateLogin.aspx` no Tank.Request. |
| `playgame.aspx` | Embute o Flash (`Loading.swf`) via ActiveX / `<object>`. |
| `auth/register.aspx` | Cadastro. |
| `Web.config` | URLs, chave de login, connection string do membership. |

Fluxo do login pelo site:

1. Você abre `http://127.0.0.1/index.htm` e digita usuário/senha (a senha vai em MD5 no JavaScript).
2. `checkuser.ashx` valida em `Db_Membership` e grava sessão.
3. O site chama `LoginGame.aspx`.
4. `LoginGame.aspx` pede para `http://127.0.0.1/request/CreateLogin.aspx` registrar a sessão de jogo.
5. Se der certo, abre `playgame.aspx?user=...&key=...`.
6. O Flash sobe com `Loading.swf?...&config=http://127.0.0.1/flash/config.xml`.
7. O Flash lê o `config.xml`, baixa os SWFs de UI, chama dezenas de URLs em `/Request/`, e por fim abre o socket TCP na porta **9500**.

Hoje o **Adobe Flash Player está morto** nos navegadores modernos (Chrome, Edge, Firefox). Para jogar pelo site você precisa de um ambiente antigo (IE + Flash, Flash Projector, ou o launcher que embute o runtime). Sem isso, `playgame.aspx` abre uma página vazia.

### 6.2 Tank.Request — a “API do Flash”

São mais de 100 handlers. Os mais importantes:

| Handler | O que devolve |
|---------|----------------|
| `CreateLogin.aspx` | Registra a sessão antes do Flash conectar |
| `Login.ashx` | Login do jogo (dados vêm criptografados com RSA) |
| `ServerList.ashx` | Lista de canais |
| `serverconfig.ashx` | Propriedades do servidor |
| `TemplateAllList.ashx` | Catálogo de itens |
| `ShopItemList.ashx` | Loja |
| `BallList.ashx` | Tipos de tiro / “bolas” |
| `LoadMapsItems.ashx` / `LoadPVEItems.ashx` | Mapas e PvE |
| `NPCInfoList.ashx` | NPCs |
| `QuestList.ashx` / `UserQuestList.ashx` | Missões |
| `LoadUserItems.ashx` / `LoadUserEquip.ashx` | Inventário e equipamento |
| `LoadUserMail.ashx` | Correio |
| `AccountRegister.ashx` / `NickNameCheck.ashx` | Criar conta / nick |
| `ConsortiaList.ashx` | Guildas |
| `DailyAwardList.ashx` | Prêmio diário |
| `CelebList/*` | Rankings (GP, oferta, guilda…) |
| `ChargeTest.ashx` / `SentReward.ashx` | Recarga / envio de item (IP restrito) |
| `API/Login.ashx` e `API/Register.ashx` | API externa (launcher / site) |

O Flash espera esses arquivos em `http://127.0.0.1/Request/` (veja `Source Flash\FlashSV1\config.xml`). No IIS isso costuma ser um **aplicativo virtual** chamado `Request` apontando para a pasta `Tank.Request`.

### 6.3 GameAdmin — painel GM

WebForms antigo, título “Gunny Admin Rev 1.0 / For Gunny 3.0”. Páginas úteis:

- `Admin/sendMail5Item.aspx` — envia itens por correio
- `Admin/customItem.aspx` — itens customizados
- `Account/Login.aspx` — login do admin

**Problema:** o `Web.config` dele ainda usa `Data Source=.\GUNNY` e bancos `Db_Tank` / `Db_Tank_All`. O resto do projeto usa `Project_Player34` / `Project_Game34`. Sem alinhar isso, o painel não fala com o mesmo banco do servidor.

---

## 7. Cliente Flash e launcher

### 7.1 Source Flash

- Linguagem do cliente: **ActionScript 3**.
- Idioma da UI neste fork: **vietnamita** (`FlashSV1\ui\vietnam\`, `Language-vn.txt`).
- Já existem **120 arquivos `.swf`** compilados, incluindo:
  - `Loading.swf`, `Launcher.swf`, `DDT_Loading.swf`
  - módulos de UI: hall, sala, loja, pets, farm, world boss, etc.
- Também há dezenas de XMLs de layout (`hall.xml`, `shop.xml`, `game.xml`…).
- `config.xml` aponta tudo para `127.0.0.1` (`/flash/`, `/Request/`, `/resource/`).

Para o IIS servir o cliente, a pasta `FlashSV1` precisa ser publicada como `http://127.0.0.1/flash/`.

**O que não está aqui:** a pasta `/resource/`. No DDTank ela costuma ter:

- tiles e fundos de mapa
- sprites de personagem, arma, asa, cabelo
- ícones de item
- animações de tiro / explosão
- a maior parte dos sons

Sem isso o Flash até inicia o loading e depois fica parado ou sem gráficos. Esse pacote **não vem neste GitHub** (é grande e em geral circula separado, extraído de um servidor já montado).

### 7.2 Source Launcher

Dois projetos Windows:

- `Gun321.Client` — launcher de verdade (login, lista de servidores, jogar, recarga).
- `GunDaiVietLauncher` / `ZGunLauncher` — cascas que extraem e rodam o `Gun321.Client`.

A pasta `Source Launcher\api\` é PHP (com pedaços do Laravel Illuminate). Endpoints:

| Arquivo | Função |
|---------|--------|
| `login.php` | Autentica e devolve XML de servidores |
| `register.php` | Cria conta no banco `Member_GMP` |
| `playgame.php` | Gera key e chama `CreateLogin.aspx` |
| `recharge.php` | Recarga com cartão de celular VN |
| `rechargemomo.php` | Recarga MoMo |
| `chargecallback.php` | Callback do gateway |
| `getcash.php` / `exchange.php` | Saldo e câmbio |
| `changepassword.php` / `forgotpass.php` | Senha |
| `config.php` | Host SQL `ADMIN\SQLEXPRESS`, banco `Member_GMP`, nome do site “Gun Đại Việt” |

Esse banco `Member_GMP` **não está** em `Database\`. O launcher desktop só funciona se você criar/importar esse banco à parte. Para testar local, o caminho pelo **site** (`Tank.Flash` + `Db_Membership`) é mais simples.

---

## 8. Banco de dados

O projeto usa **Microsoft SQL Server** (Express serve). Não há scripts `.sql` soltos: o esquema e as stored procedures vêm **dentro dos `.bak`**.

### 8.1 Arquivos em `Database\`

| Arquivo | Tamanho | Uso esperado |
|---------|---------|--------------|
| `Db_Membership.bak` | ~5 MB | Contas do site (`Tank.Flash`) |
| `Player34.bak` | ~16 MB | Dados de jogador (inventário, personagem, amigos…) |
| `Game34.bak` | ~21 MB | Dados “de jogo” / cross-zone (templates, configs compartilhadas) |

### 8.2 Nomes que o código espera

Nas configs dos servidores e do `Tank.Request`:

- `conString` → `Initial Catalog=Project_Player34`
- `crosszoneString` → `Initial Catalog=Project_Game34`

No `Tank.Flash`:

- `membershipDb` → `Initial Catalog=Db_Membership`

No `GameAdmin` (legado):

- `Db_Tank` e `Db_Tank_All`

No launcher PHP:

- `Member_GMP`

Os backups se chamam `Player34` / `Game34`, **não** `Project_Player34` / `Project_Game34`. Na hora de restaurar você escolhe o nome do banco. Duas opções válidas:

1. Restaurar como `Project_Player34` e `Project_Game34` (casa com as configs atuais).
2. Restaurar como `Player34` / `Game34` e mudar todas as connection strings.

### 8.3 Como o código fala com o SQL

Quase **só stored procedures**. Exemplos reais do código:

- Jogador / itens: `SP_Users_Active`, `SP_Users_Items_Add`, `SP_CheckAccount`
- Servidor: `SP_Service_Single`, `SP_Server_Config`, `SP_Server_Edition`
- Conteúdo: `SP_Items_All`, `SP_NPC_Info_All`, `SP_Quest_All`, `SP_Shop_All`, `SP_Ball_All`
- Social: `SP_Mail_ByUserID`, `SP_Auction_Add`, `SP_Consortia_Users_All`

Se o `.bak` estiver incompleto (procedure faltando), o servidor loga o nome da SP e o componente correspondente falha no `Init`.

### 8.4 Configuração atual (máquina do autor, não a sua)

Todos os `App.config` / `Web.config` dos servidores apontam para:

```
Data Source=KHANHDUY\SQLEXPRESS
User ID=sa
Password=abc@123
```

Isso é o SQL Express do desenvolvedor original. **No seu PC isso não existe.** Você precisa trocar `Data Source` para a sua instância (ex.: `.\SQLEXPRESS` ou `localhost`) e a senha do `sa` (ou outro usuário).

Há senhas, chaves RSA, LoginKey e até dados de pagamento MoMo gravados nesses arquivos. Trate isso como **lixo de configuração alheia**: troque tudo antes de expor o servidor na internet.

---

## 9. Sistemas de jogo que este servidor implementa

Pelo que o `GameServer` inicializa e pelo que existe no cliente, este fork cobre a linha **Gunny 3.x / DDTank 4.1**, não só o PvP básico:

- PvP em sala e PvE (dungeons / missões)
- Inventário, loja, correio, leilão
- Fortalecimento, composição, fusão, refinaria
- Guilda (Consortia), guerra de guilda
- Casamento / igreja, Hot Spring
- Pets, cartas, totens, gemas, títulos
- Farm (plantação)
- Academia (mestre/aprendiz)
- Rankings (Celeb)
- Little Game (“Đại chiến Hút Gà”)
- Ring Station (luta vs bot)
- World Boss (timers existem no código; vários estão **comentados**)
- Recarga / VIP / atividades

Alguns timers (World Boss, League semanal) estão comentados em `GameServer.InitGlobalTimer()`. Ou seja: o código existe, mas **não está ligado** nesta versão.

O `Login.ashx` tem um `if (true)` no lugar da checagem real de senha — sinal de build de debug. Em produção isso deixaria o login frouxo.

A edição interna do binário é a string `"2612558"`. A config do Road declara `Edition = 10990`. Se o valor no banco (`SP_Server_Edition`) não bater com o que o código espera, o Game Server recusa subir (`Edition: 2612558` falha no Init).

---

## 10. O que você precisa instalar no Windows

| Software | Para quê | Observação |
|----------|----------|------------|
| Windows 10/11 (64-bit) | Sistema | Já é o seu caso |
| [.NET Framework 4.8](https://dotnet.microsoft.com/download/dotnet-framework/net48) | Rodar os `.exe` | Os serviços são `net48`; as libs são `net472` |
| Visual Studio 2019 ou 2022 | Compilar | Workload “ASP.NET e desenvolvimento web” + “Desenvolvimento desktop .NET” |
| SQL Server Express + SSMS | Banco | Restaurar os 3 `.bak` |
| IIS (Internet Information Services) | Hospedar Tank.Flash e Tank.Request | Ativar no “Recursos do Windows”: ASP.NET 4.8 |
| Flash Player / Projector / launcher | Ver o jogo | Navegador moderno **não** roda Flash |
| PHP + extensão `sqlsrv` (opcional) | API do launcher | Só se for usar o launcher, não o site |

Não tem Linux nativo: é stack clássica Microsoft (C# + IIS + SQL Server + Flash).

---

## 11. Como compilaria (visão geral, sem passo a passo de exploit)

1. Abrir `DDTank 3.0.sln` no Visual Studio.
2. Restaurar NuGet se pedir.
3. Compilar a solution em **Debug** ou **Release**.
4. Compilar à parte, se for usar:
   - `Tank.Request\Tank.Request.sln`
   - `Tank.Flash\Tank.Flash.Single.sln`
   - `GameAdmin\AdminGunny.sln`
   - `Source Launcher\Gun321.Client.sln`

Saídas dos servidores:

- `Center.Service\bin\Debug\net48\Center.Service.exe`
- `Fighting.Service\bin\Debug\net48\Fighting.Service.exe`
- `Road.Service\bin\Debug\net48\Road.Service.exe`

Cada `.exe` lê o `App.config` (copiado para `NomeDoExe.exe.config` na pasta `bin`).

---

## 12. Checklist para um servidor local “mínimo”

Isto é o caminho mais curto para **testar**, não um guia de produção.

### A. Banco

1. Instalar SQL Server Express e o SSMS.
2. Restaurar:
   - `Database\Db_Membership.bak` → banco `Db_Membership`
   - `Database\Player34.bak` → banco `Project_Player34` (ou ajustar o nome nas configs)
   - `Database\Game34.bak` → banco `Project_Game34`
3. Criar um login SQL (ex.: `sa` ou um usuário só do jogo) com permissão nesses 3 bancos.
4. Conferir se existem as procedures `SP_Service_Single` e `SP_Server_Edition`, e se há um servidor com `ID = 4`.

### B. Configurações (todas precisam apontar para o **mesmo** SQL)

Arquivos a editar:

- `Center.Service\App.config`
- `Road.Service\App.config`
- `Fighting.Service\App.config`
- `Tank.Request\Web.config`
- `Tank.Flash\Web.config`
- (opcional) `GameAdmin\Web.config`

Trocar em todos:

- `Data Source=KHANHDUY\SQLEXPRESS` → sua instância
- senha do `sa`
- `IP` / URLs `127.0.0.1` se for acessar de outro PC (usar o IP da máquina)
- `ReqPath` no `Tank.Request\Web.config` (hoje aponta para `E:\Backup KhanhLam\...`, pasta de outro computador)

Manter iguais entre si:

- `ServerID` (4)
- `LoginKey` do Flash e do Request
- chave RSA (`PrivateKey` / `privateKey`)
- `Edition` e o valor no banco

### C. IIS (ideia da estrutura)

Um site no porto 80 com aplicações virtuais, por exemplo:

| URL | Pasta física |
|-----|----------------|
| `http://127.0.0.1/` | `Tank.Flash` |
| `http://127.0.0.1/Request/` | `Tank.Request` |
| `http://127.0.0.1/flash/` | `Source Flash\FlashSV1` |
| `http://127.0.0.1/resource/` | **pasta que você ainda precisa conseguir** |
| `http://127.0.0.1/admingunny/` | `GameAdmin` (opcional) |

O `config.xml` do Flash já está escrito assim. Se mudar os nomes das pastas virtuais, mude o XML também.

Habilite o MIME `.ui` (já está no `Tank.Flash\Web.config`) e um `crossdomain.xml` (já existe em `FlashSV1`).

### D. Ligar os processos

Nesta ordem, cada um numa janela de console:

1. `Center.Service.exe`
2. `Fighting.Service.exe`
3. `Road.Service.exe`

Se o Road imprimir erro de edição, de connection string ou `Can't find server config`, o banco/config ainda não está alinhado. Não adianta abrir o jogo antes disso.

### E. Entrar

- Pelo site: `http://127.0.0.1/index.htm` (precisa de Flash).
- Ou pelo launcher, se você montar o PHP + `Member_GMP`.

---

## 13. O que falta de verdade (e o que é só “trabalho”)

### Falta material (não está no GitHub)

1. **Pacote `/resource/`** — obrigatório para o cliente renderizar o jogo.
2. **Banco `Member_GMP`** — só se quiser o launcher/recarga PHP.
3. **Bancos `Db_Tank` / `Db_Count`** — só se quiser o GameAdmin do jeito que ele veio.

### Falta configuração (está no repo, mas errado para o seu PC)

1. Connection strings do autor (`KHANHDUY\SQLEXPRESS`).
2. Nomes de banco inconsistentes (`Project_*` vs arquivos `Player34`/`Game34` vs `Db_Tank`).
3. `ReqPath` e `LogPath` apontando para discos que não existem (`E:\Backup...`, `D:\GameLog`).
4. Chaves de login/recarga e RSA herdadas; LoginKey do Flash **é diferente** do Request (`QY-16-WAN-...` vs `LAMPROVIP-...`). Se o login web falhar, comece por aí.
5. GameAdmin desconectado do schema atual.

### Falta ambiente

1. IIS + ASP.NET 4.8.
2. Runtime de Flash (o maior obstáculo prático em 2026).
3. Conferir se os `.bak` têm **todas** as stored procedures que o código chama. Backups de ~40 MB no total costumam ser um dump “de desenvolvimento”, não um shard oficial cheio. Pode faltar dado de mapa/item e o Init quebrar.

### Código em estado de fork / debug

- Checagem de senha do `Login.ashx` bypassada (`if (true)`).
- Vários eventos (World Boss, League) comentados.
- Mistura de idioma: logs e avisos em vietnamita, configs em inglês/chinês, interface SevenRoad/7Road.
- `PassPort.asmx` referenciado em `http://127.0.0.1/admingunny/Flash_Port/PassPort.asmx` — o Road usa isso como interface de login web. Sem o GameAdmin publicado, essa ponta pode falhar dependendo do fluxo.

---

## 14. Versão e origem

| Campo | Valor neste repo |
|-------|------------------|
| Solution | DDTank 3.0 |
| Edição de config | 10990 |
| Hash interno de edição | 2612558 |
| Idioma do cliente | vietnamita |
| Interface de login | SevenRoad (`InterName`) |
| Nome padrão do canal | 7Road Server |
| Launcher | Gun Đại Việt 3.3.3.49 |
| Comunidade do README | Cyrus Team (Discord / YouTube) |
| Tecnologia servidor | C# / .NET Framework 4.7.2–4.8 |
| Tecnologia cliente | Adobe Flash / ActionScript 3 |
| Tecnologia web | ASP.NET WebForms + handlers `.ashx` |
| Tecnologia launcher API | PHP + SQL Server |

Isso **não** é um servidor “oficial 4.1 lacrado”. É um fork comunitário da árvore Gunny 3.0, com extras vietnamitas (recarga local, textos, launcher). Qualidade e completude dos dados no `.bak` só se descobrem restaurando e tentando iniciar o Road.

---

## 15. Glossário (para ler o código sem se perder)

| Termo que você vai ver | Significado |
|------------------------|-------------|
| **Road** | Outro nome do Game Server (a empresa original era 7Road). |
| **Center / Login Server** | Servidor central, não a tela de login do site. |
| **Fighting / Battle** | Servidor que simula o combate. |
| **Tank.Request** | Site da API HTTP. |
| **Tank.Flash** | Site que abre o SWF. |
| **Consortia** | Guilda. |
| **GP** | Experiência / “Gong Po”. |
| **Money / Xu** | Moeda premium. |
| **Gold** | Moeda básica. |
| **Gift / GiftToken** | Cupom / vale. |
| **Strengthen** | Fortalecer equipamento. |
| **Fusion / Compose** | Fundir / compor itens. |
| **PVE** | Missão contra NPCs. |
| **Ball** | Tipo de projétil. |
| **ashx** | Arquivo ASP.NET que responde a um HTTP sem página HTML. |
| **WCF** | Tecnologia Microsoft de serviço entre programas (Center expõe um). |
| **Stored procedure (SP_...)** | Função guardada no SQL Server. O C# quase nunca escreve `SELECT` solto. |
| **Connection string** | Frase que diz: servidor SQL + nome do banco + usuário + senha. |
| **Edition** | Versão do protocolo. Cliente, servidor e banco precisam concordar. |
| **.bak** | Backup nativo do SQL Server. Restaura pelo SSMS. |
| **IIS** | Servidor web da Microsoft (equivalente ao Apache, mas para ASP.NET). |
| **SWF** | Filme Flash compilado (o “executável” do cliente). |

---

## 16. Arquivos-chave se for explorar o código

```
Center.Service\Program.cs
Center.Server\CenterServer.cs
Road.Service\Program.cs
Road.Service\App.config
Game.Server\GameServer.cs
Game.Server\GameServerConfig.cs
Game.Server\GamePlayer.cs
Fighting.Service\Program.cs
Fighting.Server\FightServer.cs
Bussiness\PlayerBussiness.cs
Bussiness\ServiceBussiness.cs
Tank.Flash\Web.config
Tank.Flash\index.htm
Tank.Flash\playgame.aspx
Tank.Request\Web.config
Tank.Request\Login.ashx.cs
Tank.Request\CreateLogin.aspx.cs
Source Flash\FlashSV1\config.xml
Source Launcher\api\config.php
Database\*.bak
```

---

## 17. Veredito final

Este repositório **tem o servidor**. Não é um recorte vazio: há os três processos, a API HTTP, o site, o cliente Flash (fonte + SWFs de UI), o launcher, o painel admin e três backups SQL.

Neste PC o **boot local já passou** (SQL restaurado, IIS, Center/Fighting/Road, Electron + Flash, lobby). O texto abaixo é o que ainda vale para **outro** clone do repo, ou para produção:

1. a pasta `/resource/` **não vai no git** (~1 GB); sem ela o cliente não desenha;
2. configs versionadas ainda podem nascer com `KHANHDUY\SQLEXPRESS` — aqui já apontam para `.\SQLEXPRESS` (não commitar a senha);
3. Chrome atual não roda Flash; o caminho local é Electron 11 + Pepper Flash (`abrir-electron.bat`);
4. LoginKey, CreateLogin e lista de servidores precisam estar alinhados (vários handlers do Request neste PC estão **inline**);
5. resource 3.6 + cliente 4.1: item/prédio sem figurinha = quadrado vazio, não necessariamente crash.

Se o objetivo é **estudar** a arquitetura, o mapa Center + Road + Fighting + Request + Flash continua o padrão da comunidade.

Se o objetivo é **produção + pt-BR**, o próximo trabalho não é “escrever servidor”: é segurança mínima, um combate de verdade, depois inventário de tradução. Ordem em [`DOCUMENTACAO-AMBIENTE-LOCAL.md`](DOCUMENTACAO-AMBIENTE-LOCAL.md) §10 e no [`AGENTS.md`](AGENTS.md) §9.

---

## 18. Launcher do DDClássico (o que você já usa para jogar)

No seu PC existe outro produto, **fora deste GitHub**: o launcher **DDClassico 1.0.4** em

`C:\Users\Thiago\AppData\Local\Programs\ddclassico-launcher`

Ele **não faz parte** deste repositório. É o cliente do servidor brasileiro em que você já joga. Análise completa, inclusive o que dá para reaproveitar aqui:

**[`DOCUMENTACAO-LAUNCHER.md`](DOCUMENTACAO-LAUNCHER.md)**

Resumo de uma linha: o `.exe` deles é um Electron 11 com Flash embutido que só abre `https://ddclassico.com`. A **ideia** (Electron antigo + Pepper Flash apontando para o nosso `127.0.0.1`) serve para o DDTank41. O executável, o CDN `resource.ddclassico.com` e o login deles **não** servem como peça deste servidor.

---

## 19. Onde achar o `/resource/`

Pesquisa na internet (set/2026): **não há download público direto e completo** no GitHub. O pack gráfico circula em Discord e fóruns.

Melhor ordem de tentativa e o que recusar (resource 6.1/12.x, CDN do DDClássico):

**[`DOCUMENTACAO-RESOURCE.md`](DOCUMENTACAO-RESOURCE.md)**

**Atualização:** o resource 3.6 (~1 GB) já está em `resource/` neste PC. Análise na seção “Achado” do [`DOCUMENTACAO-RESOURCE.md`](DOCUMENTACAO-RESOURCE.md). O 4.1 deste repo pode usar essa pasta no IIS como `http://127.0.0.1/resource/`.
