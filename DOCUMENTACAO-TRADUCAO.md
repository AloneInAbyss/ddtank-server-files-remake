# Tradução pt-BR

Onde mora cada texto que o jogador lê, como editar sem quebrar o jogo, e o **glossário** deste servidor.

Leia isto **antes** de traduzir. O [`AGENTS.md`](AGENTS.md) só aponta para cá: glossário e locale não ficam lá.

Irmãos: [`DOCUMENTACAO.md`](DOCUMENTACAO.md) (arquitetura), [`DOCUMENTACAO-MODIFICACOES.md`](DOCUMENTACAO-MODIFICACOES.md) (onde mudar o quê).

Este fork é vietnamita (edição 10990). Não invente texto “do oficial brasileiro”: vale **este** código + este glossário.

---

## 1. Xu não é Presente

São carteiras diferentes no código (`PlayerInfo`, `Price.as`, `ItemInfo.GetItemPrice`).

| Código | ID na loja | Cliente VN | Como entra / sai | Na UI pt-BR |
|--------|------------|------------|------------------|---------------|
| `Money` | `-1` | **Xu** | Recarga (nạp thẻ), loja cara, VIP, sala VIP | **Cupom** |
| `Gold` | `-2` | **Vàng** | Combate; gasto do dia a dia | **Ouro** |
| `GiftToken` / `ddtMoney` | `-4` | **Lễ kim** | Missão / evento; loja de presente | **Presente** |
| `Offer` / geste | `-3` | **Công trạng** | Loja da guilda | **Mérito** |
| medalha (UI da mochila) | — | **Huân chương** | Missão | **Medalha** |

**Xu** é palavra vietnamita para a moeda premium. Em servidor brasileiro de DDTank isso é **Cupom**. Não é o Gift.

**Gift / Lễ kim** é outra moeda (vale de evento/missão). Na UI: **Presente**.

O `language.txt` vietnamita **inverte** as dicas da mochila (`GoldDirections` fala de Xu; `MoneyDirections` fala de ouro). Traduzir pelo código, não copiar esse erro:

- `GoldDirections` → ouro, ganha em combate
- `MoneyDirections` → cupom, recarga
- `GiftDirections` → presente, missões
- `MedalDirections` → medalha, missões

Rótulo curto da UI: `money:Cupom`. Plural só na frase (“cupons insuficientes”).

---

## 2. Glossário (trava)

Não misture sinônimos. Em dúvida, pergunte e anote aqui — não decida no lote.

### 2.1 Moedas e pontos

| Original / código | pt-BR | Não usar |
|-------------------|-------|----------|
| Xu / money / Money | Cupom (pl. cupons) | Xu, cash, DDT, Gift |
| Lễ kim / gift / ddtMoney / GiftToken | Presente (pl. presentes) | Gift, cupom, vale |
| Vàng / gold | Ouro | Gold, vàng |
| Huân chương / medal | Medalha | Medal, honra |
| Công trạng / offer / geste / gongxun | Mérito | Gong, offer, honra |
| GP | GP | EXP (a barra do jogo é GP) |
| petScore | Pontos de pet | — |
| Score (fim de luta / World Boss) | Pontos | Score |
| HardCurrency (labirinto) | Ouro do labirinto | — |

### 2.2 Mundo e UI

| Original | pt-BR |
|----------|--------|
| Công hội / Consortia | Guilda |
| Lễ / church | Igreja |
| Suối nước nóng / Spa / hot spring | Fonte termal |
| Pet | Pet |
| Farm / nông trại | Fazenda |
| Ready | Pronto |
| Hall | Cidade |
| Room | Sala |
| Bag | Mochila |
| Shop | Loja |
| Mail / email | Correio |
| Auction | Leilão |
| Strengthen | Fortalecer |
| Fusion | Fundir |
| Compose | Compor |
| PvE / dungeon / expedição | Missão |
| PvP / match | Combate |
| World Boss | Boss mundial |
| Labyrinth | Labirinto |
| League | Liga |
| Academy | Academia |
| VIP | VIP |
| Nickname | Apelido |
| GM / BQT | GM |

Marca na UI (login, título, recados): **DDTank**, até haver nome próprio do servidor.

Mapa, set e arma: traduzir só se o nome for estável e óbvio (`Bomba`, `Poção`). Senão manter ou transliterar e anotar.

Jogo **misto** no começo é esperado: botões em pt-BR, item ainda em vietnamita.

---

## 3. Camadas (não é um arquivo só)

Traduzir só uma deixa o jogo vietnamita + chinês + inglês quebrado. Identifique a camada **antes** de editar.

| # | O que o jogador vê | Onde | Volume neste repo | Recompilar? |
|---|-------------------|------|-------------------|-------------|
| 1 | UI, dicas, diálogos do cliente | `Source Flash/FlashSV1/ui/vietnam/language.txt` | ~3.515 chaves | **Não.** Flash baixa `ui/{LANGUAGE}/language.txt` (`PathManager.getLanguagePath`). |
| 2 | Erro, guilda, correio, combate (servidor) | `Language-vn.txt` hoje só em `bin\` | ~3.560 chaves (Road/Center/Fighting/Request). Flash/Admin é **outro** arquivo (~1.900) | Não. `LanguageMgr` relê. |
| 3 | Faixa / notice | `Center.Service/.../Languages/SystemNotice.xml` | 8 frases | Não |
| 4 | Item, set, quest, NPC | SQL (`Name`, `Description`…) + XML gerado pelo Request | maior volume | Não |
| 5 | Login / registro web | `Tank.Flash` (`index.htm` etc.) | pouco; já em inglês | Não |
| 6 | String **hardcoded** no C# | `GetTranslation("Não tìm thấy pet!")` | ~30 frases humanas usadas como chave | Sim, ao extrair a chave |
| 7 | Texto desenhado no SWF | bitmap / botão compilado | só o que sobrar | Sim (Flash) — **evitar** |

Os XML em `ui/vietnam/xml/` (~96) são **layout** (posição, fonte, `ui/spain/swf/...`). Quase não têm frase. Copiar a pasta; não “traduzir XML” no começo.

`Language-vn.txt` **não são cópias idênticas**: Center/Request/Fighting quase batem; Road tem 3 chaves a mais; `Tank.Flash` e `GameAdmin` são um subset diferente. Editar um `bin\` e esquecer os outros = lobby em pt-BR e combate em vietnamita.

~1.650 chaves do servidor começam com `GameServerScript` (falas de missão PvE, muitas já numa vietnamita automática ruim). Isso é **depois** de lobby e combate.

Dívida: a fonte dos `Language-*.txt` deve viver no source (ex. `Languages/` na raiz), copiada no build. Não tratar `bin\` como original.

---

## 4. Formato `chave:valor`

`Bussiness/LanguageMgr.cs` e o Flash usam o **primeiro `:`** da linha como separador.

```
# comentário
ConsortiaInvitePassHandler.Success:Convite aceito.
OpenUpArkHandler.RingScore:Você recebeu {0} afinidade
```

- **Não traduza a chave.** Só o valor à direita do primeiro `:`.
- Preserve `{0}`, `{1}`, HTML (`<font>`, `<b>`) e a pontuação que o `string.Format` espera.
- Não introduza `{` / `}` extras no pt-BR.
- Encoding **UTF-8**. Não salve como ANSI.
- Linha sem `:` é ignorada. Não junte linhas.
- Se `GetTranslation` não achar a chave, o jogador vê a **chave crua**. String nova no C# precisa de linha no arquivo.
- Proibido frase humana como chave (`GetTranslation("Không tìm thấy pet!")`). Extraia `Pet.Adopt.NotFound` e coloque a tradução no arquivo.
- Sem tradução automática em massa. Qualidade > cobertura.

No Flash, ~582 linhas têm `{n}` e ~144 têm HTML. Conferir isso no lote, não “no final”.

---

## 5. Como trabalhar um lote

1. Inventariar a **camada** e o domínio (não o jogo inteiro num PR).
2. Copiar origem → `Language-pt-BR.txt` / `ui/pt-BR/language.txt`. **Não apagar** o vietnamita até o locale novo estar ligado e testado.
3. Traduzir só o valor, com este glossário.
4. Ligar o locale só quando o lote visível daquela tela estiver revisado (`LanguagePath` nos configs; `<LANGUAGE value="pt-BR"/>` no `FlashSV1/config.xml`).
5. Conferir placeholders e **uma tela real** (Electron), ou XML/log se não der para clicar.

Cliente: criar `FlashSV1/ui/pt-BR/` e apontar `<LANGUAGE>` é melhor do que sobrescrever `ui/vietnam/`.

Servidor: um `Language-pt-BR.txt` canônico, replicado para Road, Fighting, Center, Request (e o subset Flash/Admin se a chave existir lá).

SQL (item/quest) é **outra frente**. Não misturar no mesmo PR do `language.txt`.

---

## 6. Ordem dos lotes

Infra (já no repo):

- Fonte do servidor: `Languages/Language-vn.txt` (canônico) e `Languages/Language-pt-BR.txt`. Ao ligar o locale, copiar o pt-BR para `bin\Languages\` de Road, Fighting, Center, Request, Flash e GameAdmin, e apontar `LanguagePath`.
- Cliente: `Source Flash/FlashSV1/ui/pt-BR/` (`language.txt`, `xml/`, `movingnotification.txt`). SWF/img **não** vão no Git (~60 MB duplicados); no PC rode `tools/setup-locale-pt-BR.ps1` (ou o `.sh`) para copiar de `ui/vietnam/`.
- Vietnamita (`ui/vietnam/`, `Language-vn.txt`) continua no disco. O locale ativo só muda quando `<LANGUAGE>` / `LanguagePath` apontam para pt-BR.

Depois o Flash, que é o que o jogador vê:

| Lote | Tela | Ordem de grandeza |
|------|------|-------------------|
| A | Botões, alertas, conexão, login, personagem | ~150–250 chaves |
| B | Cidade / sala / Pronto | ~200 |
| C | Combate (`tank.game`) | ~320 |
| D | Mochila, loja, fortalecer | ~200 |
| E | Guilda, igreja, fazenda, pet | ~300 |
| F | Resto (eventos, boss mundial…) | o que sobrar |

Ligar `<LANGUAGE value="pt-BR"/>` depois de **A+B** revisados.

Servidor em seguida: erro de sala/login → combate → guilda/correio → fazenda/pet → `GameServerScript` por missão.

Aí: `SystemNotice.xml` (trocar Discord/Fanpage do autor pelo recado **deste** servidor), HTML de login, ~30 hardcoded no C# (compilar), SQL por categoria.

SWF só se, depois disso, ainda houver palavra desenhada no botão. Sem toolchain Flash no fluxo diário.

Não religar World Boss / Liga “junto com a tradução”. Não commitar senha. Não declarar servidor público em pt-BR enquanto o login ainda tiver bypass / keys desalinhadas — no Electron local o locale pode ligar quando A+B estiver bom.

---

## 7. Verificação

- Chave intacta, `{n}` intacto, UTF-8.
- Mesmo valor nos serviços que compartilham a chave.
- Glossário deste arquivo (Cupom ≠ Presente ≠ Ouro).
- Uma tela real, não só o arquivo.

Reescrever `LanguageMgr` sem motivo: não. Apagar `ui/vietnam/` ou `Language-vn.txt` antes do pt-BR testado: não.
