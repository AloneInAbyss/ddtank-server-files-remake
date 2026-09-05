# Guia: subir o DDTank neste PC

Guia só de **fazer o jogo abrir**. Não explica a arquitetura (isso está no [`DOCUMENTACAO.md`](DOCUMENTACAO.md)).

Raiz do projeto (ajuste se a sua for outra):

`E:\Arquivos\Projetos\DDTank41`

O que você **já tem**: código dos 3 servidores, site, API, cliente Flash (`FlashSV1`), backups SQL e a pasta `resource\` (~1 GB, pack 3.6).

O que este guia faz: SQL → configs → compilação → IIS → ligar os 3 `.exe` → entrar.

Faça na ordem. Se pular o banco ou o IIS, o Road nem sobe ou o Flash fica em loading.

---

## 0. O que você vai instalar

| Programa | Para quê | Link / onde |
|----------|----------|-------------|
| [.NET Framework 4.8](https://dotnet.microsoft.com/download/dotnet-framework/net48) | Rodar Center / Road / Fighting | Se o Windows 10/11 já tiver, o instalador avisa |
| [Visual Studio 2022](https://visualstudio.microsoft.com/pt-br/downloads/) Community | Compilar o projeto | Workloads: **Desenvolvimento para desktop com .NET** e **ASP.NET e desenvolvimento web** |
| [SQL Server 2022 Express](https://www.microsoft.com/sql-server/sql-server-downloads) | Banco | Na instalação, anote o **nome da instância** (ex.: `.\SQLEXPRESS`) |
| [SSMS](https://learn.microsoft.com/sql/ssms/download-sql-server-management-studio-ssms) | Restaurar os `.bak` | Programa à parte do Express |
| IIS + ASP.NET 4.8 | Site, Request, flash, resource | Recursos do Windows (passo 5) |
| Um jeito de rodar **Flash** | Ver o jogo | Chrome/Edge atuais **não** servem. Opções no passo 8 |

Lembre a senha do usuário `sa` (ou crie um login SQL). Você vai colar isso em vários arquivos.

---

## 1. Descobrir o nome da instância SQL

1. Abra o **SQL Server Configuration Manager** (ou o SSMS).
2. O nome costuma ser:
   - `.\SQLEXPRESS` — Express padrão
   - `localhost` — instância default
   - `SEU-PC\SQLEXPRESS` — nome do computador + instância

Teste no SSMS: conectar com **Autenticação do SQL Server**, usuário `sa`, sua senha.

Se só existir autenticação do Windows, no instalador do SQL ligue **Modo misto** e defina senha do `sa`. Sem isso as configs deste projeto não conectam.

No resto do guia, troque `.\SQLEXPRESS` e `SUA_SENHA` pelos seus valores.

---

## 2. Restaurar os 3 bancos

Arquivos em `Database\`:

| Arquivo | Nome do banco ao restaurar (tem que ficar assim) |
|---------|--------------------------------------------------|
| `Db_Membership.bak` | `Db_Membership` |
| `Player34.bak` | `Project_Player34` |
| `Game34.bak` | `Project_Game34` |

Os backups se chamam `Player34` / `Game34`, mas o **código espera** `Project_Player34` / `Project_Game34`. O nome que vale é o que você der **na hora de restaurar**.

No SSMS, para **cada** `.bak`:

1. Clique com o botão direito em **Databases** → **Restore Database…**
2. **Source:** Device → `...` → Add → escolha o `.bak`
3. Em **Destination**, no campo **Database**, digite o nome da tabela acima (`Project_Player34`, etc.), **não** deixe o nome antigo do backup se for diferente.
4. Aba **Options**: marque **Overwrite the existing database** se pedir.
5. Se der erro de caminho de arquivo (o backup foi feito noutro PC): aba **Files**, mude **Restore As** para pastas que existem no seu SQL (ex.: `C:\Program Files\Microsoft SQL Server\MSSQL16.SQLEXPRESS\MSSQL\DATA\`).
6. OK.

No final, em Databases você deve ver os três nomes.

Conferência rápida (Nova consulta, banco `Project_Player34`):

```sql
EXEC SP_Service_Single @ID = 4;
EXEC SP_Server_Edition;
```

- Se `SP_Service_Single` não devolver linha: o canal `ServerID = 4` não existe — o Road vai logar `Can't find server config`.
- Se `SP_Server_Edition` falhar ou o valor não bater com o que o código espera (`2612558` no C#, `10990` no `App.config`), o Game Server pode recusar subir. Anote o erro e o valor; isso se resolve no banco depois.

O usuário `sa` precisa de permissão nesses 3 bancos (no Express recém-instalado, `sa` já é admin).

---

## 3. Ajustar as configs (máquina do autor → a sua)

Hoje tudo aponta para `KHANHDUY\SQLEXPRESS` e senha `abc@123`. Isso **não é o seu PC**.

Em **todos** os arquivos abaixo, troque:

```
Data Source=KHANHDUY\SQLEXPRESS
Password=abc@123
```

por:

```
Data Source=.\SQLEXPRESS
Password=SUA_SENHA
```

(Use a sua instância, não copie `.\SQLEXPRESS` se a sua for outra.)

### 3.1 Servidores

| Arquivo |
|---------|
| `Center.Service\App.config` |
| `Road.Service\App.config` |
| `Fighting.Service\App.config` |

Chaves: `conString` → banco `Project_Player34`; `crosszoneString` → `Project_Game34`.

Deixe `IP` = `127.0.0.1` se for jogar só neste computador.

Portas (não mude sem necessidade):

| Serviço | Porta |
|---------|--------|
| Center TCP | 9202 |
| Center WCF | 2008 (HTTP), 2009 (net.tcp) |
| Fighting | 9208 |
| Road (jogadores) | 9500 |

`ServerID` = `4` nos três (tem que existir no banco).

### 3.2 Sites

**`Tank.Request\Web.config`**

- Mesmas `conString` / `crosszoneString`.
- Troque `ReqPath` (hoje aponta para outro computador):

```xml
<add key="ReqPath" value="E:\Arquivos\Projetos\DDTank41\Tank.Request\" />
```

- `LogPath` aponta para `D:\GameLog`. Crie essa pasta **ou** mude para algo como `E:\Arquivos\Projetos\DDTank41\logs\`.

**`Tank.Flash\Web.config`**

- `membershipDb`: mesmo `Data Source` / senha, banco `Db_Membership`.

### 3.3 LoginKey (hoje está diferente)

No `Tank.Flash\Web.config`:

`QY-16-WAN-0668-2555555-7ROAD-dandantang-trminhpc773377`

No `Tank.Request\Web.config`:

`LAMPROVIP-DIGGORY-CYRUS-22111999-LOGINWEBKEY`

**Deixe os dois iguais.** O mais simples: copie o `LoginKey` e o `LoginKey_a` do Request para o Flash (ou o contrário). Se não bater, o site autentica e o `CreateLogin` falha.

Não precisa inventar chave nova para testar local.

### 3.4 Cliente Flash — obrigatório

O jogo carrega `http://127.0.0.1/flash/config.xml`, que é o arquivo:

`Source Flash\FlashSV1\config.xml`

Hoje ele puxa gráfico de `http://gunny.vcdn.vn/` e tem `USE_MD5` ligado. Isso **não** usa a sua pasta `resource\`.

Altere pelo menos estas linhas:

```xml
<USE_MD5 value="false"/>
<SITE value="http://127.0.0.1/resource/"/>
<POLICY_FILES>
  <file value="http://127.0.0.1/resource/crossdomain.xml"/>
</POLICY_FILES>
```

O `Tank.Flash\config.xml` já está certo (`SITE` = `http://127.0.0.1/resource/`). Quem manda no jogo é o **FlashSV1**, porque o `Web.config` aponta `FlashConfig` para `/flash/config.xml`.

---

## 4. Compilar

1. Abra `DDTank 3.0.sln` no Visual Studio.
2. Restaure NuGet se pedir.
3. Menu **Compilar** → **Compilar solução** (Debug serve).
4. Abra e compile também:
   - `Request.sln` ou `Tank.Request\Tank.Request.sln`
   - `Tank.Flash\Tank.Flash.Single.sln`

Saídas que importam:

```
Center.Service\bin\Debug\net48\Center.Service.exe
Fighting.Service\bin\Debug\net48\Fighting.Service.exe
Road.Service\bin\Debug\net48\Road.Service.exe
```

Ao compilar, o Visual Studio **copia** o `App.config` para `NomeDoExe.exe.config` na pasta `bin`. Se você editar o `App.config` **depois** de já ter compilado, compile de novo **ou** edite também o `.exe.config` em `bin\Debug\net48\`.

---

## 5. Ligar o IIS no Windows

1. Painel de Controle → **Programas** → **Ativar ou desativar recursos do Windows**.
2. Marque **Internet Information Services**.
3. Abra a árvore e garanta pelo menos:
   - IIS → Serviços da World Wide Web → Recursos de desenvolvimento de aplicativos → **ASP.NET 4.8**
   - IIS → Serviços da World Wide Web → Recursos comuns HTTP → Conteúdo estático, Documento padrão
4. OK e espere instalar.

Registre o ASP.NET (PowerShell **como administrador**):

```powershell
& "$env:windir\Microsoft.NET\Framework64\v4.0.30319\aspnet_regiis.exe" -i
```

Abra o **Gerenciador do IIS** (`inetmgr`).

### 5.1 Application Pool

1. **Application Pools** → **Add Application Pool**
2. Nome: `DDTank`
3. .NET CLR version: **v4.0**
4. Pipeline: **Integrated**
5. Depois de criar: Advanced Settings → **Enable 32-Bit Applications** = `False` (AnyCPU 64 bits). Se algum site quebrar com erro de DLL 32 bits, teste `True`.
6. Identity: **LocalSystem** ou uma conta que leia `E:\Arquivos\Projetos\DDTank41` (se der 500.19 / acesso negado, é isso).

### 5.2 Site e pastas

Pode usar o **Default Web Site** (porta 80) ou criar um site novo na 80.

Estrutura:

| URL | Tipo no IIS | Pasta física |
|-----|-------------|--------------|
| `http://127.0.0.1/` | site (raiz) | `E:\Arquivos\Projetos\DDTank41\Tank.Flash` |
| `http://127.0.0.1/Request/` | **Application** (não só virtual dir) | `E:\Arquivos\Projetos\DDTank41\Tank.Request` |
| `http://127.0.0.1/flash/` | Virtual directory | `E:\Arquivos\Projetos\DDTank41\Source Flash\FlashSV1` |
| `http://127.0.0.1/resource/` | Virtual directory | `E:\Arquivos\Projetos\DDTank41\resource` |

Como criar:

1. Clique no site → **Basic Settings** → Physical path = pasta `Tank.Flash`. Application pool = `DDTank`.
2. Botão direito no site → **Add Application…**
   - Alias: `Request`
   - Pool: `DDTank`
   - Path: pasta `Tank.Request`
3. Botão direito no site → **Add Virtual Directory…**
   - Alias: `flash` → pasta `Source Flash\FlashSV1`
   - Alias: `resource` → pasta `resource`

`Request` **tem** que ser Application (roda `.ashx` / `.aspx`). `flash` e `resource` são arquivos estáticos.

### 5.3 MIME (senão o Flash não baixa `.ui` / `.flv`)

No site (ou em `flash` e `resource`): **MIME Types** → Add, se ainda não existir:

| Extensão | Tipo |
|----------|------|
| `.ui` | `text/plain` |
| `.flv` | `video/x-flv` |
| `.swf` | `application/x-shockwave-flash` |

O `Tank.Flash\Web.config` já mapeia `.ui`. Som do resource é `.flv` — sem MIME, o IIS pode bloquear.

### 5.4 Testar o IIS (antes dos `.exe`)

No navegador:

- `http://127.0.0.1/` ou `http://127.0.0.1/index.htm` — tela de login
- `http://127.0.0.1/flash/config.xml` — XML (SITE já deve ser `/resource/`)
- `http://127.0.0.1/flash/Loading.swf` — baixa um arquivo
- `http://127.0.0.1/resource/crossdomain.xml` — política Flash
- `http://127.0.0.1/resource/image/map/1/icon.png` — uma imagem de mapa

Se algum der 404, o alias ou o caminho físico está errado. Não ligue o Road ainda.

---

## 6. Liberar portas no firewall (mesmo no localhost costuma ir; faça se der timeout)

TCP de entrada: **9202**, **9208**, **9500**, **2008**, **2009**, **80**.

---

## 7. Ligar os servidores (nessa ordem)

Três janelas de console. **Como administrador** se o socket recusar a porta.

1. `E:\Arquivos\Projetos\DDTank41\Center.Service\bin\Debug\net48\Center.Service.exe`  
   Espere mensagem de start / sem erro de SQL.

2. `E:\Arquivos\Projetos\DDTank41\Fighting.Service\bin\Debug\net48\Fighting.Service.exe`  
   Porta 9208.

3. `E:\Arquivos\Projetos\DDTank41\Road.Service\bin\Debug\net48\Road.Service.exe`  
   Ele conecta no Center (9202) e no Fighting (9208), depois abre 9500.

Se o Road imprimir:

| Mensagem (ideia) | Causa |
|------------------|--------|
| Erro de SQL / login failed | Connection string errada |
| `Can't find server config` | Não existe servidor ID 4 no banco |
| `Edition` falhou | Valor no banco ≠ o que o código espera |
| Não conecta no Center | Center não está no ar ou IP/porta 9202 |
| Init de ItemMgr / MapMgr / Shop falhou | Procedure ou dado faltando no `.bak` |

Nesse caso **não** adianta abrir o jogo. Leia o log na pasta do `.exe` (`RecordLog` / `logconfig`).

Desligar: feche Road, depois Fighting, depois Center (ordem inversa).

---

## 8. Entrar no jogo

`http://127.0.0.1/index.htm` — cadastro / login do `Tank.Flash` (banco `Db_Membership`).

**Chrome, Edge e Firefox atuais não rodam Flash.** A página `playgame.aspx` abre e o jogo não aparece.

Opções para ver o SWF:

1. **Flash Projector** (Adobe, arquivo `flashplayer_32_sa.exe`) — abrir a URL do `Loading.swf` depois do login, ou a página no projector.
2. Um **Electron 11 + Pepper Flash** apontando para `http://127.0.0.1/` (ideia do DDClássico; o `.exe` deles **não** serve, URL fixa no site deles).
3. IE / modo legado — cada vez mais difícil no Windows 11.

O launcher `DDClassico.exe` que você já tem **não** abre este servidor.

Fluxo se o Flash estiver ok:

1. Cria conta / entra no `index.htm`
2. Vai para loading → `playgame.aspx`
3. `Loading.swf` lê `/flash/config.xml`, baixa `/Request/` e `/resource/`
4. Conecta TCP na porta **9500**

---

## 9. Checklist rápido

- [ ] SQL no ar, 3 bancos restaurados com os nomes `Project_*` e `Db_Membership`
- [ ] `sa` (ou equivalente) nas connection strings
- [ ] `LoginKey` igual no Flash e no Request
- [ ] `FlashSV1\config.xml` com `SITE` = `http://127.0.0.1/resource/` e `USE_MD5` = `false`
- [ ] Solution + Tank.Flash + Tank.Request compilados
- [ ] IIS: raiz, Application `Request`, virtuais `flash` e `resource`
- [ ] Testes HTTP do passo 5.4 OK
- [ ] Center → Fighting → Road sem erro
- [ ] Cliente com Flash (não o Chrome normal)

---

## 10. Problemas comuns

**Página 500 no `/Request/`**  
Application Pool errado, ASP.NET não registrado, ou SQL do `Web.config` ainda no `KHANHDUY`.

**404 em `/flash/` ou `/resource/`**  
Alias ou pasta física. `resource` é `...\DDTank41\resource`, não `resource\flash`.

**Loading infinito / 99%**  
Olhe a aba Rede (F12). 404 em `resource/image/...` = arquivo que o 4.1 pede e o pack 3.6 não tem. 404 em `Request/*.ashx` = Application `Request` mal criada. SQL do Request falhou = XML vazio.

**Login do site OK, jogo não entra**  
`LoginKey` diferente; `CreateLogin.aspx` inacessível; Road fora do ar.

**Tela preta depois do playgame**  
Não é o servidor: é falta de Flash no navegador.

**Road sobe e cai num Init**  
O `.bak` pode não ter todas as stored procedures que o 4.1 chama. Copie o nome da SP do log; isso é buraco de banco, não de resource.

---

## 11. O que este guia não faz

- Painel `GameAdmin` (configs de banco antigas: `Db_Tank`). Opcional.
- Launcher vietnamita / PHP `Member_GMP` (banco que não veio).
- Abrir o servidor na internet (IP público, firewall do roteador, trocar `127.0.0.1` em todos os XML).
- Traduzir a UI (está em vietnamita).

Quando algo falhar, o recado útil é: **qual janela** (SQL, IIS, Center, Fighting, Road, navegador) e a **linha de erro**. Com isso dá para atacar um passo só.
