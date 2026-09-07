# AGENTS.md — DDTank41

Instruções para qualquer agente de IA neste repositório. Leia este arquivo no início de cada sessão. Em conflito, **este arquivo + o código** vencem a memória da conversa.

Documentação humana (não reescrever o que já está aqui):

| Arquivo | Quando abrir |
|---------|----------------|
| [`DOCUMENTACAO.md`](DOCUMENTACAO.md) | Arquitetura, peças, o que falta |
| [`DOCUMENTACAO-AMBIENTE-LOCAL.md`](DOCUMENTACAO-AMBIENTE-LOCAL.md) | O que foi feito **neste PC** (boot até o lobby, 5/set/2026) |
| [`GUIA-SUBIR-SERVIDOR.md`](GUIA-SUBIR-SERVIDOR.md) | Subir o ambiente neste PC |
| [`DOCUMENTACAO-COMBATE.md`](DOCUMENTACAO-COMBATE.md) | Física, dano, turnos, recompensas |
| [`DOCUMENTACAO-FORTALECIMENTO.md`](DOCUMENTACAO-FORTALECIMENTO.md) | Forja: fortalecer arma/elmo/roupa, pedras, chance, falha |
| [`DOCUMENTACAO-DROP-DUNGEON.md`](DOCUMENTACAO-DROP-DUNGEON.md) | Drop de dungeon: cartas, NPC, caixa, SQL |
| [`DOCUMENTACAO-MODIFICACOES.md`](DOCUMENTACAO-MODIFICACOES.md) | Onde cada tipo de mudança mora |
| [`DOCUMENTACAO-RESOURCE.md`](DOCUMENTACAO-RESOURCE.md) | Pacote gráfico `resource/` |
| [`DOCUMENTACAO-LAUNCHER.md`](DOCUMENTACAO-LAUNCHER.md) | Launcher (referência; não copiar CDN de terceiros) |
| [`DOCUMENTACAO-TRADUCAO.md`](DOCUMENTACAO-TRADUCAO.md) | Locale pt-BR: camadas, glossário, formato, lotes |

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

## 4. Traduções

Detalhe (camadas, glossário, formato, lotes): [`DOCUMENTACAO-TRADUCAO.md`](DOCUMENTACAO-TRADUCAO.md). Leia **antes** de editar idioma.

- Identifique a camada. Não misture SQL de item com `language.txt` no mesmo PR.
- Não traduza a chave. UTF-8. Preserve `{n}` e HTML.
- Termos de jogo: só os do doc de tradução (Cupom ≠ Presente ≠ Ouro). Em dúvida, pergunte e anote **lá**.
- Não apague o vietnamita até o pt-BR estar ligado e testado.
- Sem tradução automática em massa. Proibido `GetTranslation("frase việt")`. Não reescrever `LanguageMgr`.

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
3. Tradução: inventário e locale conforme [`DOCUMENTACAO-TRADUCAO.md`](DOCUMENTACAO-TRADUCAO.md).
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
