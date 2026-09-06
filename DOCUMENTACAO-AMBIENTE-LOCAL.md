# O que fizemos neste PC (e como desfazer)

Texto para quem nunca usou SQL Server, IIS ou “servidor de jogo”. Não é um manual de programação.

Cobre **só o que aconteceu nesta máquina**. Documentos irmãos: [`DOCUMENTACAO.md`](DOCUMENTACAO.md), [`GUIA-SUBIR-SERVIDOR.md`](GUIA-SUBIR-SERVIDOR.md), [`DOCUMENTACAO-LAUNCHER.md`](DOCUMENTACAO-LAUNCHER.md), [`DOCUMENTACAO-CENTER.md`](DOCUMENTACAO-CENTER.md), [`DOCUMENTACAO-ROAD.md`](DOCUMENTACAO-ROAD.md), [`DOCUMENTACAO-FIGHTING.md`](DOCUMENTACAO-FIGHTING.md).

**Nada disso foi commitado no git** (configs têm senha `sa`). Não faça commit dessas connection strings.

---

## 0. Onde estamos (5 de setembro de 2026)

**Objetivo inicial do boot: cumprido.** Neste PC o jogador entra no lobby.

| O que | Estado |
|-------|--------|
| SQL Express + 3 bancos | No ar (`.\SQLEXPRESS`) |
| IIS (`127.0.0.1`) | Login, `flash/`, `resource/`, `Request/` |
| Center :9202 → Fighting :9208 → Road :9500 | Ligados e falando entre si |
| Cliente | Electron 11 + Pepper Flash (ideia do DDClássico; **não** o `.exe`/CDN deles) |
| Conta de teste | `myaccount` — personagem ID 2 no lobby, canal **Local** |
| Dungeon / um tiro | **Ainda não.** O prédio da expedição não carregou o gráfico; o lobby em si está jogável |

Chrome/Edge atuais **não** rodam o jogo. O caminho que funcionou é `abrir-electron.bat`.

---

## 1. A ideia em uma analogia

Imagine um restaurante. O “jogo” que você clica é só a porta da rua.

| Peça | Analogia | Neste projeto |
|------|----------|----------------|
| Pasta `E:\Arquivos\Projetos\DDTank41` | Receita e ingredientes | Código, Flash, `resource\`, backups SQL |
| **SQL Server** | Caderno de contas | Jogadores, itens, canal 4 |
| **IIS** | Porta da rua + cardápio | `http://127.0.0.1/` (login, SWF, gráficos) |
| Center / Road / Fighting | Recepcionista, salão, cozinha | Três `.exe` (portas 9202, 9500, 9208) |
| Electron 11 + Pepper Flash | Um navegador velho que ainda entende Flash | `Launcher.Electron\` + `abrir-electron.bat` |

`127.0.0.1` = **este computador**. Nada disso está aberto na internet.

---

## 2. O que já estava aqui (não instalamos)

- Código do emulador (fork vietnamita, edição 10990).
- Backups em `Database\`: `Db_Membership.bak`, `Player34.bak`, `Game34.bak`.
- `resource\` (~1 GB, pack 3.6; está no `.gitignore`).
- Os três `.exe` já compilados.
- .NET Framework 4.8 e Build Tools 2026 (já existiam neste PC).

O que **não** estava: SQL, SSMS, IIS, Build Tools **2022**, launcher Electron nosso.

---

## 3. O que você instalou

### 3.1 SQL Server 2022 Express

Instância `SQLEXPRESS` (`.\SQLEXPRESS`). Usuário `sa`, senha `abc@123` (sua escolha; é a mesma do autor do fork — troque se um dia publicar). Serviço: **SQL Server (SQLEXPRESS)**.

### 3.2 SSMS 22

Restaurou os três bancos com os **nomes que o código espera**:

| Arquivo `.bak` | Nome do banco |
|----------------|---------------|
| `Db_Membership.bak` | `Db_Membership` |
| `Player34.bak` | `Project_Player34` |
| `Game34.bak` | `Project_Game34` |

`EXEC SP_Service_Single @ID = 4;` → 1 linha (canal 4). Sem isso o Road recusa subir.

### 3.3 Build Tools 2022

Em `E:\Programas\Microsoft Visual Studio\2022\BuildTools`. Compilamos a solution no boot; o dia a dia do lobby **não** depende de recompilar a cada login (vários handlers do Request passaram a ser `.ashx` inline).

### 3.4 IIS

Pool **DDTank** (CLR v4.0, LocalSystem). Site na pasta `Tank.Flash`. Application **Request** → `Tank.Request`. Virtuais **flash** → `Source Flash\FlashSV1`, **resource** → `resource`. MIME `.swf` / `.ui` / `.flv`. Anonymous Authentication = identidade do pool (senão 401.3).

---

## 4. Como ligar de novo neste PC

Ordem:

1. SQL Express em *Running* (`services.msc`).
2. IIS / Default Web Site no ar.
3. Center.Service → Fighting.Service → Road.Service (janelas de console).
4. `abrir-electron.bat` → login web → o Electron embute o Flash.

Não use o Flash Projector como cliente principal: o `Loading.swf` antigo trava ~49%. O entry que funciona é **`DDT_Loadin2.swf`** via `playgame.aspx`.

Se o Flash pedir *Local Storage* para `127.0.0.1`, clique **Allow**.

---

## 5. O que mudamos nos arquivos (boot)

Nada commitado. Senha `sa` continua nos `App.config` / `Web.config` — **não versionar**.

### 5.1 Config (IP, SQL, Flash)

| Arquivo | Mudança |
|---------|---------|
| `Source Flash\FlashSV1\config.xml` | `SITE=http://127.0.0.1/resource/`, `USE_MD5=false`, `REQUEST_PATH` local, `LOGIN_PATH` → `index.htm`, policy HTTP + `xmlsocket://127.0.0.1:843` e `:9500` |
| `Center` / `Road` / `Fighting` `App.config` e `.exe.config` | `Data Source=.\SQLEXPRESS` |
| `Tank.Request\Web.config` | SQL local; `ReqPath` / `LogPath` neste PC |
| `Tank.Flash\Web.config` | SQL `Db_Membership`; LoginKey alinhada ao Request |
| `resource\crossdomain.xml` | `to-ports="*"` |
| `Source Flash\FlashSV1\md5.xml` | Hash do `1.png` atualizado |

O `Server_List` no SQL **ainda** pode ter o IP vietnamita `45.119.85.41`. O Flash **não** usa mais esse IP: o `ServerList.ashx` devolve `127.0.0.1` na mão.

### 5.2 Login web e Request (handlers inline)

O IIS deste site não recompilava o `Tank.Request.dll` de forma confiável. Por isso vários `.ashx` / `.aspx` viraram código **inline** (o IIS compila na hora):

| Arquivo | Por quê |
|---------|---------|
| `Tank.Flash\LoginGame.aspx` | Hash CreateLogin em 4 partes; grava `abrir-jogo.bat` / `last-play-url.txt` |
| `Tank.Flash\playgame.aspx` | Sem cookie de sessão se vier `user`+`key`; embute `DDT_Loadin2.swf`; stubs JS (`setFlashCall`, `game_interruption` para log) |
| `Tank.Flash\loading.htm` | Trim da resposta do LoginGame |
| `Tank.Request\CreateLogin.aspx` | Aceita várias LoginKeys (as que aparecem nos SWFs) |
| `Tank.Request\LoginSelectList.ashx` | Lista vazia = sucesso; devolve personagem real (ID > 0); log em `logs\last-select.xml` |
| `Tank.Request\Login.ashx` | Se `ActivePlayer` quebra (ID 0), busca o personagem por nome; `Center.CreatePlayer(..., isFirst=false)` para o Road **não** expulsar; log em `logs\last-login.xml` |
| `Tank.Request\ServerList.ashx` | XML fixo: IP `127.0.0.1`, Port `9431` (o Flash soma 69 → **9500**) |
| `Tank.Request\devchar.ashx` | Só `127.0.0.1`; helper de personagem |
| `Tank.Flash\devlogin.ashx` | Só localhost |

`Login.ashx` **ainda** tem bypass de senha no fluxo antigo (`if (true)` no `.cs`). O inline atual também não exige senha real. Isso é dívida de **segurança**, não de boot.

### 5.3 Cliente Flash (SWF)

- `Loading.swf` sozinho é beco sem saída (~49%, para no `config.xml` / `LoginSelectList`).
- URLs hardcoded de CreateLogin (`192.168.0.10:728`, `test64.ddt.7road-inc.com`) foram patchadas nos bytes dos SWFs. Backup: `*.swf.bak-pre-local-login`.
- Cópia de trabalho: **`DDT_Loadin2.swf`** (parte de `DDT_Loading.swf`).

### 5.4 Launcher nosso

Pasta `Launcher.Electron\`:

- Electron **11.5.0** + Pepper Flash (`pepflashplayer64.dll` do DDClássico **só como plugin**, não como jogo).
- `main.js`: `disable-http-cache`, CDP `:9222`, log HTTP em `logs\electron-net.log`, screenshot periódico `logs\electron-screen.png`, sobe política de socket na porta **843** (se a porta já estiver ocupada, o processo Node que já escuta serve).
- `flash-policy.js`: XML de *socket policy* (o Pepper Flash exige isso para o TCP do Road).
- `abrir-electron.bat` na raiz.

Não usamos o `DDClassico.exe` nem o CDN `ddclassico.com`.

### 5.5 Diagnóstico (para a próxima sessão)

| Arquivo | Uso |
|---------|-----|
| `logs\request-debug.log` | `login.ashx` e lista de personagem |
| `logs\last-login.xml` / `last-select.xml` | Última resposta HTTP |
| `logs\electron-net.log` | HTTP do Electron + `FLASH_INTERRUPT` |
| `logs\policy-843.log` | Hits na política de socket |
| `Road.Service\bin\Debug\net48\logs\GameServer.log` | `Incoming connection` = o Flash chegou no TCP |
| `tools\debug-snapshot.ps1` | Junta portas + XMLs + tails |

---

## 6. Por que o lobby demorou (resumo técnico)

1. **Lista de servidores** anunciava `45.119.85.41` — o Flash ia para o Vietnã.
2. Sem **porta 843** (socket policy), o Pepper Flash às vezes nem completava o TCP no Road.
3. `login.ashx` tentava **criar de novo** um personagem que já existia (`InvalidCastException`, ID 0).
4. Mesmo com ID certo, o Center gravava `IsFirst=true` e o Road **expulsava** o socket em ~12 ms (mesmo alerta vietnamita de “conexão falhou”).
5. `CreatePlayer(..., false)` + personagem ID 2 → lobby.

O texto *“Xin lỗi, kết nối thất bại…”* serve para **várias** falhas (IP errado, policy, Road fechando o socket). Sem os logs acima dava para perder o dia no mesmo popup.

---

## 7. O que **não** está pronto

- Prédio da expedição / dungeon sem gráfico (resource 3.6 × cliente 4.1). Um tiro PvE **não** foi feito.
- `Server_List` no SQL ainda com IP do autor (o ashx tapa o buraco).
- Senha real no login; LoginKeys e RSA ainda no estilo do fork.
- Handlers inline vs `.cs` compilado: duas verdades; no próximo ciclo, ou compilamos o Request de verdade ou documentamos “fonte = ashx”.
- `Language-vn.txt` só em `bin\`; locale pt-BR ainda não ligado.
- World Boss / League comentados — não religar sem teste.
- `GameAdmin` ainda fala `Db_Tank`.
- Log do Road cresce muito; o arquivo já passou de 128 KB e a leitura “pelo meio” engana.

---

## 8. Como desfazer

Ordem: fechar Road → Fighting → Center; depois IIS; depois bancos; por último desinstalar programas.

### 8.1 IIS

`inetmgr`: remova **Request**, **flash**, **resource**. Volte o Default Web Site para `C:\inetpub\wwwroot` / `DefaultAppPool`. Apague o pool **DDTank**.

### 8.2 SQL

No SSMS, delete `Db_Membership`, `Project_Player34`, `Project_Game34` (marque *Close existing connections*). Os `.bak` em `Database\` ficam.

### 8.3 Programas

Configurações → Aplicativos: SSMS 22, SQL Server 2022. Visual Studio Installer: Build Tools **2022** (não o 2026).

### 8.4 Arquivos do projeto

Sem commit, um `git checkout` nos configs versionados volta o IP do autor. **Não** commite `bin\`, `obj\`, `resource\`, senhas. Pode apagar `logs\` e `Launcher.Electron\node_modules\`.

---

## 9. Glossário extra desta etapa

| Termo | Uma linha |
|-------|-----------|
| Socket policy (porta 843) | Arquivo XML que o Flash exige antes de abrir TCP no jogo |
| `ServerList` Port + 69 | O XML manda 9431; o cliente soma 69 e liga no Road **9500** |
| Handler inline | `.ashx` com C# no próprio arquivo; o IIS compila sem MSBuild |
| Pepper Flash | Plugin Flash 32 dentro do Electron 11 |
| `CreatePlayer` / `IsFirst` | Registro da sessão no Center; `true` faz o Road recusar o login |

---

## 10. Próximo passo (proposta)

O `AGENTS.md` manda **não pular segurança para traduzir tudo**. O lobby já prova o boot. Ordem sugerida:

1. **Endurecer o local sem quebrar o login** — `Server_List` no SQL para `127.0.0.1`; decidir o que vira fonte (ashx inline vs `dotnet build` do Request); **não** commitar connection string; anotar o `if (true)` para tirar depois.
2. **Um combate** — achar por que o prédio da dungeon não desenha (quase certamente figurinha 4.1 ausente no resource 3.6) e entrar por Fight Lab / Ring Station / mapa que exista no pack.
3. **Inventário de tradução** — contar chaves por camada (`language.txt` do Flash, `Language-vn.txt` dos serviços, SQL de item). Glossário já está no `AGENTS.md`. Só então locale `pt-BR` (copiar, não apagar o vietnamita).
4. **Produção de verdade** (depois): senha real, keys iguais, configs sem `sa`, GameAdmin, eventos.

Na próxima conversa, comece pelo item **1** ou **2** — não pelos dois ao mesmo tempo.
