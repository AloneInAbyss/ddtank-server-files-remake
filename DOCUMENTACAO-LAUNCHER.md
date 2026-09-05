# Launcher do DDClássico — o que é e o que dá para aproveitar

Este documento descreve o launcher que você já usa para jogar no servidor **DDClássico**, e responde se alguma parte dele serve para o servidor deste repositório (`DDTank41`).

Pasta analisada no seu PC:

`C:\Users\Thiago\AppData\Local\Programs\ddclassico-launcher`

Documento irmão (servidor GitHub): [`DOCUMENTACAO.md`](DOCUMENTACAO.md).

---

## 1. Resposta curta

O `DDClassico.exe` **não é um servidor**. Também **não é** o launcher vietnamita que veio no `Source Launcher` deste projeto.

Ele é um **navegador próprio** (Electron 11 + Flash embutido) que só abre o site do DDClássico e deixa o jogo Flash rodar.

**Dá para aproveitar a ideia. Não dá para “apontar esse .exe para o nosso servidor” de um jeito limpo e pronto.**

| Peça | Reaproveitar no DDTank41? | Por quê |
|------|---------------------------|---------|
| Ideia: Electron antigo + Pepper Flash | **Sim, é o caminho certo** | Resolve o Flash morto no Chrome/Edge |
| `DDClassico.exe` do jeito que está | **Não** | URL, marca, atualizador e login são deles |
| Binários do Pepper Flash (`flashver\`) | Tecnicamente sim, juridicamente cinza | É o plugin da Adobe, não o jogo deles |
| Pasta `/resource/` do DDClássico | **Não** | É o acervo gráfico do servidor deles; versão e direitos são outros |
| Site / API / `s1.ddclassico.com` | **Não** | Isso é o servidor ao vivo em que você joga |
| Launcher C# `Source Launcher` deste repo | Só se quiser o modelo vietnamita | Não tem Flash embutido; depende de PHP + outro banco |

A recomendação prática: **fazer um launcher nosso**, copiando a *arquitetura* (Electron 11 + plugin Flash + webview), apontando para `http://127.0.0.1/` quando o IIS do DDTank41 estiver no ar.

---

## 2. O que é o DDClássico

DDClássico é um servidor privado brasileiro de DDTank “clássico”. Você entra pelo site `https://ddclassico.com` ou por este launcher. Eles também têm app de celular:

- Android: `com.seventeengames.classico`
- iOS: app `ddclassico` na App Store

O instalador no seu Windows se chama **DDClassico 1.0.4**. A janela tem 1366×780, sem borda do Windows (frame próprio).

Isso é outra árvore da família DDTank/Gunny. **Não é o fork vietnamita** (Cyrus / Gun Đại Việt / edição 10990) que está neste repositório.

---

## 3. O que tem na pasta de instalação

```
ddclassico-launcher\
  DDClassico.exe              (~120 MB)  o aplicativo Electron
  Uninstall DDClassico.exe
  *.dll, *.pak                runtime do Chromium/Electron
  locales\                    idiomas do Chromium
  resources\
    app.asar                  (~5 MB) código JS da interface
    app-update.yml            atualizador
    icon.ico / icon.png / logo.png
    elevate.exe
    flashver\
      pepflashplayer64.dll    Flash 32.0.0.303 (Windows 64 bits)
      pepflashplayer32.dll    Flash 32 bits
      libpepflashplayer.so    Flash Linux
      PepperFlashPlayer.plugin\  Flash macOS
      manutencao_rv.bat       limpa cache e reabre o app
```

**Não tem** nesta pasta:

- Center / Road / Fighting
- banco SQL
- pasta `resource` com mapas e sprites
- o cliente Flash completo salvo em disco

O jogo **não está instalado**. O launcher só abre o site; gráficos e SWFs baixam da internet na hora.

Cache e preferências ficam em `%APPDATA%\DDClassico` (pasta do Chromium). O `.bat` de manutenção apaga essa pasta e a `%APPDATA%\Electron` e relança o `.exe`.

---

## 4. Como o launcher funciona

### 4.1 Por que Electron 11.5.0

O código interno explica: o suporte a Flash (PPAPI / Pepper) foi **removido do Chromium** depois dessa época. Eles **travaram** o Electron na **11.5.0** de propósito. Atualizar o Electron quebraria o jogo.

Fluxo interno:

1. O processo principal (`app.asar`) registra o plugin Flash da pasta `resources\flashver\`.
2. No Windows 64 bits usa `pepflashplayer64.dll`; no 32 bits, `pepflashplayer32.dll`.
3. Abre uma `BrowserWindow` com `plugins: true` e uma tag `<webview plugins>`.
4. A webview carrega **direto** `https://ddclassico.com/classic/launcher` (login feito para o launcher).
5. `https://ddclassico.com` serve só para montar links absolutos (ex.: recarga).
6. Quando a URL casa com `/playgame/número`, o launcher considera que você está **dentro do jogo**.
7. Não há checagem de versão de cliente Flash, nem login automático por API própria: **quem autentica é o site deles**.

Atualização automática:

```
provider: generic
url: https://download.ddclassico.com/updates/
```

Instalador publicado: `DDClassico-Setup-1.0.4.exe` (também há `.dmg` para Mac e `.deb` Linux).

### 4.2 Para onde o seu PC já conversou

Pelos dados de rede gravados no Windows ao usar o launcher:

| Endereço | Papel |
|----------|--------|
| `https://ddclassico.com` | Site, login, launcher web |
| `https://ddclassico.com/classic/launcher` | Tela de login específica deste `.exe` |
| `https://s1.ddclassico.com` | Canal/web do jogo (equivalente ao nosso `Tank.Flash` + `Tank.Request`) |
| `https://resource.ddclassico.com` | CDN do pacote gráfico (`/resource/`) |
| `https://download.ddclassico.com/updates/` | Update deste launcher |
| `https://ip-api.ddclassico.com` | API auxiliar (IP/região) |

Há ainda analytics/ads (Google, Facebook, Twitter) e um backend em AWS. Isso é infra **deles**, não deste repo.

### 4.3 Diagrama

```
Você clica em DDClassico.exe
        │
        ▼
 Electron 11.5.0  +  Pepper Flash 32.0.0.303
        │
        │  abre webview
        ▼
 https://ddclassico.com/classic/launcher     ← login
        │
        ▼
 https://s1.ddclassico.com/.../playgame/N    ← jogo Flash
        │
        ├── HTTP  →  resource.ddclassico.com   (mapas, sprites, sons)
        ├── HTTP  →  s1.ddclassico.com         (Request / templates)
        └── TCP   →  Game Server deles         (sala, tiro, chat)
```

Compare com o fluxo do **nosso** projeto, descrito em `DOCUMENTACAO.md`:

```
Navegador ou launcher nosso
        │
        ▼
 http://127.0.0.1/           (Tank.Flash)
 http://127.0.0.1/Request/   (Tank.Request)
 http://127.0.0.1/flash/     (FlashSV1)
 http://127.0.0.1/resource/  (ainda não existe neste repo)
        │
        └── TCP 9500 → Road.Service → Center 9202 / Fighting 9208
```

O desenho é o mesmo. Só mudam o endereço e quem hospeda cada pasta.

---

## 5. Diferença para o launcher que já veio no DDTank41

Este repositório tem `Source Launcher\` (Gun Đại Việt / `Gun321.Client`):

| | **DDClassico.exe** (o que você joga) | **Source Launcher** (neste repo) |
|--|--------------------------------------|----------------------------------|
| Tecnologia | Electron 11 + Chromium + Pepper Flash | Windows Forms C# (.NET 4.0) |
| Como abre o jogo | Webview no próprio app | Depende de runtime Flash à parte / `.sol` |
| Login | Site `ddclassico.com` | API PHP (`login.php`, banco `Member_GMP`) |
| Idioma / marca | DDClássico (Brasil) | Gun Đại Việt (Vietnã) |
| Recarga | Página `/recharge` do site deles | PHP (cartão VN, MoMo) |
| Serve para o servidor local? | Não, URLs fixas neles | Só depois de PHP + banco `Member_GMP` + Flash |

Para um servidor **local** no DDTank41, o modelo do DDClássico (navegador com Flash) é **mais útil** do que o launcher C# vietnamita. O C# ainda precisa de Flash no sistema e de um banco que **não veio** nos `.bak`.

---

## 6. Dá para aproveitar no nosso servidor?

### 6.1 O que vale a pena copiar (a ideia)

O problema nº 1 para jogar o DDTank41 no seu PC, depois do SQL e do IIS, é: **o navegador moderno não roda Flash**.

O DDClássico já resolveu isso do jeito que a comunidade usa hoje:

1. Empacotar **Electron 11.5.x** (não mais novo).
2. Embutir **Pepper Flash** (win64/win32).
3. Ligar `plugins: true` na janela e na `<webview>`.
4. Abrir a URL do **seu** site, não a deles.

Isso é o que devemos imitar.

Um launcher nosso, no mesmo espírito, faria só isto:

- Abrir `http://127.0.0.1/` (ou `/index.htm` do `Tank.Flash`).
- Quando o `playgame.aspx` embutir o `Loading.swf`, o Flash plugin entra em ação.
- O `config.xml` do `FlashSV1` já aponta para `127.0.0.1/flash/`, `127.0.0.1/Request/` e `127.0.0.1/resource/`.

Não precisa recarga, update automático nem app de celular para testar local.

### 6.2 O que **não** devemos reaproveitar

**O `DDClassico.exe` pronto**

As URLs estão gravadas no `app.asar` (`SITE_ROOT = https://ddclassico.com`). O atualizador aponta para o servidor deles. A marca, o ícone e o login são do DDClássico.

Remendar o `asar` deles para apontar para `127.0.0.1` seria:

- frágil (o próximo update deles sobrescreve);
- misturar a marca de outro servidor no nosso;
- modificar software de terceiros sem ser o nosso produto.

Não é o caminho. Se formos ter launcher, **escrevemos um nosso**, bem menor.

**Os resources do DDClássico (`resource.ddclassico.com`)**

Na documentação do servidor já ficou claro: este GitHub **não tem** a pasta `/resource/`. O DDClássico tem a deles na nuvem.

Isso **não** substitui o que falta aqui, por três motivos:

1. **Versão** — o cliente deste repo é fork vietnamita, edição **10990**, UI `vietnam`. O DDClássico é outro build (clássico brasileiro). Mapas, IDs de item e SWFs provavelmente **não batem**.
2. **Direitos** — aquele pacote é o acervo do servidor deles, não um kit livre deste repositório.
3. **Endereço** — o Flash deste repo pede `http://127.0.0.1/resource/`. Não adianta o launcher “conhecer” o CDN deles se o `config.xml` e o servidor local esperam arquivos nossos.

Precisamos de um pack **da mesma linha do cliente** (`FlashSV1` / 10990), não do CDN do DDClássico.

**Login, API, canal `s1`**

Isso é o servidor ao vivo. Não entra no nosso IIS nem no nosso SQL.

### 6.3 Os DLLs do Pepper Flash

A pasta `flashver\` contém o plugin **Adobe Flash Player 32.0.0.303** (Pepper), não código do DDClássico.

- **Tecnicamente:** qualquer Electron 11 no Windows 64 bits precisa exatamente desse tipo de arquivo (`pepflashplayer64.dll`). Sem ele, o SWF não roda.
- **Juridicamente:** a Adobe encerrou o Flash. Redistribuir o plugin é zona cinzenta. Servidores privados fazem isso o tempo todo; não é “código nosso” e não devemos tratar como se o DDClássico tivesse licenciado o Flash para a gente.

Uso honesto: se formos criar um launcher **nosso**, o plugin Flash é uma dependência do runtime, igual o Electron. Não copiamos a marca, o `app.asar` nem o site deles.

### 6.4 Dá para “só mudar a URL” do DDClassico?

Quem descompactar o `app.asar` acha isto no JS:

```js
const SITE_ROOT = 'https://ddclassico.com';
const LAUNCHER_URL = `${SITE_ROOT}/classic/launcher`;
```

Trocar para `http://127.0.0.1` **em tese** faria a webview abrir o nosso `Tank.Flash` — **depois** do IIS publicado e do Flash plugin já estar ligado (isso eles já fazem).

Mesmo assim é má ideia como solução permanente:

- update oficial do DDClássico desfaz a alteração;
- a tela `/classic/launcher` **não existe** no nosso `Tank.Flash` (o nosso login é `index.htm`);
- o jogo deles espera `/playgame/123`; o nosso é `playgame.aspx?...`;
- você misturaria dois produtos.

Para teste rápido de “o Electron 11 abre o meu SWF?”, um protótipo mínimo nosso é mais limpo do que remendar o `.exe` deles.

---

## 7. O que um launcher nosso precisaria ter (mínimo)

Para o DDTank41 local, o suficiente é:

| Item | Detalhe |
|------|---------|
| Electron **11.5.x** | Não usar 12+; perde Flash |
| Pepper Flash win64 | Registrar o plugin no `app.commandLine` antes de criar a janela |
| Uma janela + `<webview plugins>` | Igual ao DDClássico |
| URL inicial | `http://127.0.0.1/index.htm` (ou a que o IIS publicar) |
| Sem atualizador | Desnecessário no localhost |
| Sem PHP / Member_GMP | O login do `Tank.Flash` + `Db_Membership` já cobre o teste |

Isso **não substitui**:

- SQL restaurado e connection strings certas;
- IIS com `Tank.Flash`, `Tank.Request`, `/flash/` (`FlashSV1`);
- a pasta `/resource/` **compatível com este cliente**;
- Center → Fighting → Road ligados.

O launcher só resolve a **janela com Flash**. O resto continua sendo o servidor.

---

## 8. Relação com os buracos do DDTank41

O `DOCUMENTACAO.md` listou o que falta para jogar. O launcher do DDClássico fecha **um** desses buracos, e só no sentido de “como fazer”, não de arquivo pronto:

| Buraco no DDTank41 | O launcher do DDClássico ajuda? |
|--------------------|----------------------------------|
| Flash morto no navegador | **Sim, como receita:** Electron 11 + Pepper Flash |
| Falta `/resource/` | **Não.** O pack deles é de outro servidor/versão |
| Config aponta para `KHANHDUY\SQLEXPRESS` | Não |
| Bancos / LoginKey inconsistentes | Não |
| Banco `Member_GMP` ausente | Não precisa, se usarmos o site `Tank.Flash` |
| Launcher C# vietnamita incompleto | Podemos **ignorar** e usar o modelo Electron |

---

## 9. Conclusão

- O que você adicionou ao workspace é o **cliente do servidor em que já joga**, não uma peça faltante do GitHub.
- A parte inteligente dele é pequena: um Chromium velho com Flash e uma webview no site.
- **Aproveitamos a arquitetura**, não o produto DDClássico.
- **Não** usamos o CDN `resource.ddclassico.com` como se fosse o resource deste repo.
- Quando o servidor local estiver no ar, o próximo passo de cliente é um **launcher nosso** (Electron 11 + Flash) abrindo `http://127.0.0.1/`, não remendar o `DDClassico.exe`.

Se for implementar esse launcher depois, o lugar natural no repo seria uma pasta nova (por exemplo `Launcher.Electron/`), separada do `Source Launcher` vietnamita, para não misturar as duas linhagens.
