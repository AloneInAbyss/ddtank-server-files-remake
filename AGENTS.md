# AGENTS.md — DDTank41

Instruções para qualquer agente de IA neste repositório. Leia este arquivo no início de cada sessão. Em conflito, **este arquivo + o código** vencem a memória da conversa.

Documentação humana (não reescrever o que já está aqui):

| Arquivo | Quando abrir |
|---------|----------------|
| [`DOCUMENTACAO.md`](DOCUMENTACAO.md) | Arquitetura, peças, o que falta |
| [`DOCUMENTACAO-AMBIENTE-LOCAL.md`](DOCUMENTACAO-AMBIENTE-LOCAL.md) | O que foi feito **neste PC** (boot até o lobby, 5/set/2026) |
| [`GUIA-SUBIR-SERVIDOR.md`](GUIA-SUBIR-SERVIDOR.md) | Subir o ambiente neste PC |
| [`DOCUMENTACAO-COMBATE.md`](DOCUMENTACAO-COMBATE.md) | Física, dano, turnos, recompensas |
| [`DOCUMENTACAO-MODIFICACOES.md`](DOCUMENTACAO-MODIFICACOES.md) | Onde cada tipo de mudança mora |
| [`DOCUMENTACAO-RESOURCE.md`](DOCUMENTACAO-RESOURCE.md) | Pacote gráfico `resource/` |
| [`DOCUMENTACAO-LAUNCHER.md`](DOCUMENTACAO-LAUNCHER.md) | Launcher (referência; não copiar CDN de terceiros) |
| [`DOCUMENTACAO-CENTER.md`](DOCUMENTACAO-CENTER.md) | Servidor Center: pastas, portas, sessão, WCF, timers |

---

## 1. Missão

Levar este emulador **à produção** (servidor jogável, estável, seguro) com **traduções em português do Brasil (pt-BR) de qualidade**.

Este repo é um fork vietnamita (Cyrus / Gun Đại Việt) da árvore Gunny / 7Road / DDTank 3.0, edição **10990**. Não é o jogo oficial. Não invente comportamento “do oficial”: o que vale é **este código**.

O idioma da conversa com o usuário é **português**. Explique termos técnicos na primeira vez. Não use jargão de processo interno.

---

## 2. Papel do agente

Atue como desenvolvedor sênior de .NET Framework, ASP.NET, SQL Server e emuladores Flash.

- Prefira mudança pequena, verificável e reversível.
- Leia o código e os docs do repo **antes** de propor arquitetura nova.
- Não comece refatoração ampla, “limpeza geral” ou rewrite.
- Não commite nem faça push a menos que o usuário peça.
- Não trate o DDClassico (launcher, CDN, `ddclassico.com`) como cliente ou resource deste servidor. Reuse só a *ideia* (Electron 11 + Pepper Flash), nunca o exe/CDN deles.
- Não baixe nem scrapeie resource de CDN de terceiros.

---

## 3. Mapa do sistema

```
Cliente Flash (Source Flash/FlashSV1)
    HTTP  → Tank.Flash (login web) + Tank.Request (XML/listas)
    TCP   → Road.Service :9500  (lobby, inventário, salas)
                ├─ Freedom / PvE: Game.Logic no próprio Road
                └─ Match: BattleServer → Fighting.Service :9208
Center.Service  (lista de servidores, correio, leilão)
SQL Server      (Project_Player34, Project_Game34, Db_Membership)
resource/       (gráficos; ~1 GB; está no .gitignore)
```

Solution principal: `DDTank 3.0.sln` (.NET Framework **4.7.2 / 4.8**).

| Camada | Pastas | Mexer quando |
|--------|--------|----------------|
| Config | `*\App.config`, `*\Web.config`, `FlashSV1\config.xml` | IP, porta, rates, idioma do cliente |
| SQL | stored procedures `SP_*`, tabelas de item/loja/missão | conteúdo, nomes de item, economia |
| C# | `Game.Server`, `Game.Logic`, `Fighting.*`, `Center.*`, `Bussiness`, `Tank.Request` | regra, segurança, string hardcoded |
| Flash | `Source Flash\src\` (AS3) + `FlashSV1\` (SWF + XML + `language.txt`) | UI, textos do cliente |
| Resource | `resource\` | arte/som; não versionar |

Visual Studio **não é obrigatório**. Compile servidores com MSBuild / Build Tools / Rider / `dotnet build` na solution. Sites ASP.NET antigos (`Tank.Request`, `Tank.Flash`, `GameAdmin`) pedem MSBuild com *Web Application targets*.

---

## 4. Traduções (objetivo de origem)

O jogador vê texto em **várias camadas**. Traduzir só um arquivo deixa o jogo misto (vietnamita + chinês + inglês quebrado). Sempre identifique a camada antes de editar.

### 4.1 Camadas

| # | O que o jogador vê | Onde está | Precisa recompilar? |
|---|-------------------|-----------|---------------------|
| 1 | UI, diálogos, dicas do cliente | `Source Flash\FlashSV1\ui\vietnam\language.txt` | **Não.** O Flash baixa em runtime (`PathManager` → `ui/{LANGUAGE}/language.txt`). `config.xml` tem `<LANGUAGE value="vietnam"/>`. |
| 2 | Mensagens do servidor (erro, guilda, mail, combate) | `Languages\Language-vn.txt` em cada serviço (`Road`, `Fighting`, `Center`, `Tank.Request`, `Tank.Flash`, `GameAdmin`) | Não. `LanguageMgr` relê o arquivo. |
| 3 | Avisos / notice | `Languages\SystemNotice.xml` (Center) | Não |
| 4 | Nomes de item, set, quest, NPC | SQL + XML gerado pelo Request (ex.: `clothpropertytemplateinfo_out.xml`) | Não (SQL/XML) |
| 5 | HTML de login/registro | `Tank.Flash` (`index.htm` etc.) | Não |
| 6 | String **hardcoded** no C# | `LanguageMgr.GetTranslation("texto việt...")` — se a chave não existe, o fallback **é o próprio texto** | Sim, se extrair para chave |
| 7 | Texto desenhado dentro do SWF | bitmap / componente compilado | Sim (Flash) — evite; só se 1–6 não cobrirem |

Hoje os `Language-vn.txt` **só existem em `bin\`**. Trate isso como dívida: a fonte de verdade deve viver no source (ex. `Languages\` na raiz ou pasta do serviço, copiada no build). Não edite só um `bin\` e esqueça os outros.

### 4.2 Formato dos arquivos `key:value`

`Bussiness\LanguageMgr.cs` e o cliente Flash usam o **primeiro `:`** da linha como separador.

```
# comentário
ConsortiaInvitePassHandler.Success:Convite aceito.
OpenUpArkHandler.RingScore:Você recebeu {0} afinidade
```

Regras obrigatórias:

- **Não traduza a chave.** Só o valor à direita do primeiro `:`.
- Preserve `{0}`, `{1}`, HTML (`<font>`, `<b>`) e pontuação usada pelo `string.Format`.
- Não introduza `{` / `}` extras no texto pt-BR.
- Encoding **UTF-8**. Não salve como ANSI.
- Linha sem `:` é ignorada. Não “ajude” juntando linhas.
- Se `GetTranslation` não achar a chave, o jogador vê a **chave crua**. Toda string nova no C# precisa de entrada no arquivo de idioma.
- Proibido passar frase humana como chave (`GetTranslation("Không tìm thấy pet!")`). Extraia para `Pet.Adopt.NotFound` e coloque a tradução no arquivo.
- Não faça tradução automática em massa sem glossário. Qualidade > cobertura.
- Termos de jogo: mantenha consistência (veja §4.3). Em dúvida, pergunte.

### 4.3 Glossário mínimo (pt-BR)

Use estes termos até o usuário definir outro. Não misture.

| Original comum | pt-BR |
|----------------|--------|
| Xu / money | Xu |
| Lễ kim / gift / ddtMoney | Gift |
| Vàng / gold | Ouro |
| Công hội / Consortia | Guilda |
| Huân chương / medal | Medalha |
| Lễ / church | Igreja |
| Suối nước nóng / Spa | Fonte termal |
| Pet | Pet |
| GP / exp de luta | GP |
| Ready | Pronto |

Nomes próprios de mapa, set e arma: traduzir só se houver nome estável e reconhecível; senão transliterar ou manter e anotar.

### 4.4 Como trabalhar tradução

1. Inventariar a camada (não traduzir “o jogo inteiro” num PR só).
2. Copiar o arquivo de origem para `Language-pt-BR.txt` / `ui/pt-BR/language.txt` — **não apagar o vietnamita** até o locale novo estar ligado e testado.
3. Traduzir por domínio (login, inventário, combate, guilda…).
4. Ligar o locale (`LanguagePath` nos configs; `<LANGUAGE>` no `config.xml`).
5. Conferir placeholders e uma tela real (ou o XML/log), não só o arquivo.

Cliente Flash: criar `FlashSV1\ui\pt-BR\language.txt` e apontar `<LANGUAGE value="pt-BR"/>` é preferível a sobrescrever `ui\vietnam\`.

---

## 5. Produção e segurança

Bloqueadores conhecidos. Não declare “pronto para produção” enquanto existirem:

- `Login.ashx` com `if (true)` (bypass de senha).
- Connection strings do autor (`KHANHDUY\SQLEXPRESS`, `sa` / `abc@123`) em configs versionadas.
- LoginKey diferente entre Flash (`QY-16-WAN-...`) e Request (`LAMPROVIP-...`).
- `FlashSV1\config.xml` com `SITE=http://gunny.vcdn.vn/` e `USE_MD5=true` (o playgame lê **este** config, não o de `Tank.Flash`).
- Eventos World Boss / League comentados: só religar depois de testar; não é “tradução”.
- `GameAdmin` ainda aponta para `Db_Tank`.

Regras:

- Nunca commitar senha, connection string real, chave RSA privada, `.env`.
- Preferir User Secrets / configs locais fora do git quando formos a produção.
- Não enfraquecer auth, validação de pacote ou economia “para testar” e esquecer.
- Mudança de fórmula de dano/GP: documentar em `DOCUMENTACAO-COMBATE.md` na mesma alteração. `GP_RATE` e `LeagueMoney_*` **existem e não entram** no `PVPGame` deste fork.

---

## 6. Como mudar código

Ordem de preferência: **config → SQL → arquivo de idioma → C# → Flash AS3 → resource**.

- C#: estilo do arquivo atual (este código é decompilado/legado). Não modernize para C# 12 “porque sim”.
- Não adicione pacote NuGet sem necessidade.
- Combat: `Game.Logic` é a regra. Freedom/PvE no Road; Match no Fighting. Detalhe em `DOCUMENTACAO-COMBATE.md`.
- Scripts de missão PvE: pasta `scripts/`, compilados em runtime.
- Flash AS3: só se o texto/UI não puder sair do `language.txt` / XML. Não há toolchain Flash no fluxo diário.
- `resource\` não vai para o git. Não apagar. Cliente 4.1 + arte 3.6: item sem figurinha = quadrado vazio, não crash necessariamente.

Compilar depois de mudar C# que o Road carrega no `Init`. Erro de compile/load derruba o servidor.

---

## 7. Git

- Commit só quando o usuário pedir.
- Não `push --force`, não `--no-verify`, não alterar `git config`.
- Não commitar `resource/`, `bin/`, `obj/`, `.bak` enormes, senhas.
- Mensagem de commit: 1–2 frases no **porquê**, em português.

---

## 8. Verificação

- Servidor: o processo sobe? `Init` termina sem exception? Login HTTP responde?
- Tradução: chave intacta, `{n}` intacto, UTF-8, mesmo arquivo em todos os serviços que compartilham a chave.
- UI web: exercitar o fluxo (não só screenshot).
- Sem browser tools: dizer o que não deu para clicar e o que foi checado no lugar (log, XML, arquivo).

---

## 9. Ordem de trabalho sugerida (produção)

Não pule segurança para “já traduzir tudo”. Dá para paralelizar **depois** do boot local.

1. Boot local alinhado (`GUIA-SUBIR-SERVIDOR.md`): SQL, configs, IIS, Center → Fighting → Road, Flash.
2. Segurança mínima: senha real, keys iguais, configs sem senha do autor.
3. Inventário de tradução (contagem por camada) + glossário.
4. Locale pt-BR nos arquivos de idioma do cliente e do servidor.
5. Extração das strings hardcoded no C#.
6. Nomes de item/quest no SQL (maior volume; fazer por lote).
7. Estabilidade, economia, eventos — só com o jogo já jogável.

---

## 10. Proibido

- Exploit, PoC ofensivo, bypass de auth de terceiros, “hack do jogo”.
- Completar pedido de crime / phishing / item shop fraudulenta.
- Inventar fórmula de combate ou chave de config que o código não usa.
- Apagar o locale vietnamita antes do pt-BR estar ligado.
- Reescrever `LanguageMgr` sem motivo (ele é simples e estável).
