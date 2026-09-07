# Drop de dungeon (neste emulador)

Este documento descreve **como o servidor sorteia item em PvE** — formigueiro, castelo da galinha (“castelo bugou”), labirinto, etc. Não é o jogo oficial da 7Road. Tudo abaixo foi lido em `DropInventory`, `DropMgr`, `PVEGame` e nas tabelas SQL `Drop_Condiction` / `Drop_Item`.

Se você nunca viu o código: **não existe uma % fixa no C#** do tipo “formigueiro fácil = 3% de arma”. A dungeon só escolhe **qual tabela** consultar. A chance mora no banco. A lista de itens na carta da dungeon (Flash) **não** é essa tabela.

Documentos irmãos: [`DOCUMENTACAO.md`](DOCUMENTACAO.md), [`DOCUMENTACAO-COMBATE.md`](DOCUMENTACAO-COMBATE.md), [`DOCUMENTACAO-MODIFICACOES.md`](DOCUMENTACAO-MODIFICACOES.md).

---

## 1. Resposta direta

Numa dungeon deste fork o item pode cair de **vários canos**, cada um com a própria linha SQL:

| Quando | Função | O que o SQL casa |
|--------|--------|------------------|
| NPC/chefe morre | `DropInventory.NPCDrop(NpcInfo.DropId)` | `Drop_Item` cujo `DropId` é o do NPC (sem passar por tipo) |
| Caixa no chão depois de um turno com dano | `BoxDrop(tipo da sala)` | tipo `Box` (2), `Para1` = tipo da sala (`Dungeon` = **4**) |
| Depois do tiro (`CanGetProp`) | `FireDrop(tipo da sala)` | tipo `Fire` (8), mesmo `Para1` |
| Carta no fim da fase / fim da dungeon | `CopyDrop(id da missão, 1)` | tipo `Copy` (5), `Para1` contém o **ID da missão**, `Para2` contém **`1`** |
| Caixa grande do labirinto | `CopyDrop(id da missão, SessionId)` | tipo `Copy`, `Para2` = andar atual |
| Laboratório de luta | `FightLabUserDrop` | tipo `FightLab` (14) — **entrega todos** os itens da tabela, sem o filtro `Random` |

`BossDrop` e `SpecialDrop` existem no C# e **não são chamados** pelo `PVEGame.TakeCard` deste fork. A carta do chefe usa `CopyDrop`, não `BossDrop`. O [`DOCUMENTACAO-COMBATE.md`](DOCUMENTACAO-COMBATE.md) antigo citava `BossDrop` nesse ponto; o que vale é este arquivo.

Não dá para afirmar “no formigueiro a arma X cai Y%” sem ler o **seu** SQL. O dump `LoadPVEItems.xml` só mostra o que a **UI** desenha na carta.

---

## 2. Formigueiro, castelo e os IDs

No backup `GameAdmin\Backup\XMLReader\XMLImport\LoadPVEItems.xml` (espelho de `Pve_Info`):

| `Pve_Info.ID` | Nome no XML (VN) | Nome que o jogador BR costuma usar |
|---------------|------------------|-------------------------------------|
| 2 | Huyệt Ma Kiến | **Formigueiro** |
| 1 | Lâu đài Gà | **Castelo da galinha / castelo bugou** |
| 7 | Giải cứu gà con | Resgate dos pintinhos |
| 3 | Bộ lạc Tà thần | Tribo do deus maligno |
| 4 | Pháo đài hắc ám | Fortaleza sombria |
| 5 | Đại chiến rồng | Guerra do dragão |
| 6 | Đấu trường gà | Arena da galinha |
| 101 | Hướng dẫn tân thủ | Tutorial |

Esses IDs são da **instância** (`Pve_Info`). O drop da carta **não** usa o `Pve_Info.ID`. Usa o **ID da missão** (`Mission_Info.Id`) que o script da dificuldade carregou.

A dificuldade (fácil / normal / difícil / terror / épico) escolhe um **script** diferente (`SimpleGameScript`, `NormalGameScript`, …). O script chama `SetupMissions("1202,1203,1204")` (exemplo). Cada número é uma fase. Missões diferentes → `Drop_Condiction.Para1` diferentes → tabelas de item diferentes.

Uma quest do backup cita “Tổ kiến ma” com `Para1=2002`: missão **2002** entra em alguma tabela do formigueiro. Confirme no SQL ao vivo; o XML de PvE **não** traz o script.

Os campos `SimpleTemplateIds` / `NormalTemplateIds` / `HardTemplateIds` / `TerrorTemplateIds` são **vitrine**. O Flash mostra esses IDs na carta da dungeon. O servidor **não** sorteia por essa lista.

---

## 3. As duas tabelas (onde a chance mora)

Carregadas no boot do Road (`DropMgr.Init` → `SP_Drop_Condiction_All` + `SP_Drop_Item_All`).

### 3.1 `Drop_Condiction` — “quando usar esta tabela”

| Coluna | Significado |
|--------|-------------|
| `DropID` | Chave da lista de itens |
| `CondictionType` | Valor de `eDropType` (abaixo) |
| `Para1` | Texto com IDs **entre vírgulas**, ex. `,2002,2003,` |
| `Para2` | Segundo filtro, no mesmo formato, ex. `,1,` ou `,0,` |

A busca faz:

```
Procura a primeira linha em que
  CondictionType == tipo
  e Para1 contém ",valor1,"
  e Para2 contém ",valor2,"
```

A **primeira** linha que casar vence. Ordem no `SELECT` importa.

### 3.2 `Drop_Item` — “o que pode sair e com que peso”

| Coluna | Significado |
|--------|-------------|
| `DropId` | Liga na condição |
| `ItemId` | `TemplateID`. Negativos viram moeda: `-100` ouro, `-200` cupom, `-300` presente |
| `Random` | Peso do filtro (quanto **maior**, mais fácil passar no corte) |
| `BeginData` / `EndData` | Quantidade: `Random.Next(Begin, End)` → intervalo **\[Begin, End)** |
| `IsBind` | Vinculado |
| `ValueDate` | Validade em dias (`0` = permanente, neste campo) |
| `IsTips` | Aviso mundial se caiu na carta |
| `IsLogs` | Log |

### 3.3 Tipos (`eDropType`)

| Valor | Nome | Uso neste código |
|-------|------|------------------|
| 1 | Cards | `CardDrop(tipo da sala)` — outro fluxo, não a carta do `TakeCard` |
| 2 | Box | Caixa no mapa |
| 3 | NPC | Existe no enum; `NPCDrop` **pula** essa busca e usa o `DropId` cru |
| 4 | Boss | Função pronta; **ninguém chama** no `PVEGame` |
| 5 | Copy | Carta da dungeon / labirinto / vários PvE |
| 6 | Special | Função pronta; **ninguém chama** |
| 7 | PvpQuests | Missão PvP |
| 8 | Fire | Drop após o tiro |
| 9 | PveQuests | Missão PvE por NPC |
| 10 | Answer | Quiz |
| 11 | Retrieve | Recuperar |
| 13 | Trminhpc | Pet |
| 14 | FightLab | Laboratório (sem filtro `Random`) |

---

## 4. O algoritmo da chance (`GetDropItems`)

É o mesmo para carta, caixa, tiro e NPC (quando o `DropId` é válido). **Não** é “peso / soma dos pesos”.

```
lista = todos os Drop_Item daquele DropId

maxRandom = o maior Random da lista
maxRound  = número aleatório em [0, maxRandom)     // Random.Next(max)

candidatos = itens com Random >= maxRound

se não sobrou ninguém: não dropa
senão: escolhe 1 candidato, todos com a mesma chance
quantidade = Next(BeginData, EndData)
se MacroDrop deixar: entrega o item
```

### 4.1 O que isso significa na prática

O item com o **maior** `Random` **sempre** entra nos candidatos (o dado nunca fica ≥ o máximo).

Um item com `Random` baixo só entra quando o dado sai baixo. Quando entra, compete **em igualdade** com os comuns que também passaram.

Exemplo (três linhas, `Random` 10000 / 5000 / 100):

| Item | P(passar no corte) | Depois ainda divide com quem passou |
|------|--------------------|--------------------------------------|
| A (10000) | 100% | quase sempre na urna |
| B (5000) | 50% | quando o dado sai abaixo de 5000, urna A+B (e C se sair abaixo de 100) |
| C (100) | 1% | raro na urna; se entrar, 1/2 ou 1/3 |

A % real de C **não** é `100/10100`. É menor, porque na maioria das vezes C nem entra na urna.

Por isso “aumentar o `Random` do item raro” **e** “baixar o `Random` do lixo” os dois mexem na chance, de jeitos diferentes.

### 4.2 Um item por sorteio

`count` está fixo em **1**. Cada chamada a `CopyDrop` / `NPCDrop` / `BoxDrop` entrega no máximo **uma** linha (ou nada, se a lista estiver vazia ou o `CanDrop` vetar).

Duas cartas no fim da dungeon = **dois** sorteios independentes na **mesma** tabela (`Para2=1`).

### 4.3 Teto do servidor (`MacroDrop`)

Depois do sorteio, `DropInfoMgr.CanDrop(TemplateID)`:

- Se o template **não** está no `macrodrop\macroDrop.ini` do Center: **pode** dropar.
- Se está: conta quantos já saíram neste ciclo. Estourou `MaxDropCount` → o item some do resultado (o sorteio “acertou” e o jogador não leva).

O `.ini` de exemplo limita templates `1`, `2` e `3` a 5 por ciclo. Só vale para IDs listados lá.

---

## 5. O que acontece em cada momento da dungeon

### 5.1 Matar NPC / chefe

`SimpleNpc.Die` → `GetDropItemInfo`:

1. Só dropa se o living da vez é um **jogador** (pet/NPC matando não gera essa lista).
2. `NPCDrop(npc.DropId)` — `DropId == 0` → nada.
3. `NpcInfo.DropRate` **existe no SQL e é ignorado** neste método.
4. Item categoria 10 (prop de luta) vai para a fight bag; o resto, temp bag.
5. `TemplateID` −100/−200/−300 vira ouro / cupom / presente na hora.

O chefe (`SimpleBoss`) **não** chama esse `GetDropItemInfo`. O loot “do boss” que o jogador espera é a **carta** no fim da fase, não o cadáver.

### 5.2 Caixa no chão

`BaseGame.CreateBox`, se o turno deu dano:

- Sorteia 1 ou 2 caixas (teto: jogadores + 2 no mapa).
- Conteúdo: `BoxDrop(RoomType)`. Em dungeon, `Para1` = `,4,`.

Isso é compartilhado por **todas** as dungeons do tipo sala 4. Formigueiro e castelo usam a **mesma** tabela de caixa, salvo você criar condições extras.

### 5.3 Drop no tiro

`Player` depois de atirar, se `CanGetProp`: `FireDrop(RoomType)`. De novo, chave = tipo da sala, não o ID do formigueiro.

### 5.4 Cartas (o “drop da dungeon”)

No `GameOver` da missão:

| Situação | Quantas cartas (`BossCardCount`) |
|----------|----------------------------------|
| Perdeu | 0 |
| Venceu e **ainda tem** próxima fase | 1 |
| Venceu a **última** fase (e não é tutorial) | 2 |
| Laboratório de luta | permissão à parte; drop próprio |

O jogador vira a carta (`TakeCard`):

```
id = (TakeCardId != 0) ? TakeCardId : MissionInfo.Id
CopyDrop(id, 1)     // o 1 é literal — não é a dificuldade
```

Ou seja: **fácil e terror da mesma missão** (mesmo `MissionInfo.Id`) leem a **mesma** linha `Para2=,1,`. A dificuldade só muda o drop da carta se o script carregou **outro** ID de missão.

`IsTips` na linha do item → aviso no chat (“parabéns, pegou X no mapa Y”).

### 5.5 Labirinto

Sala `Labyrinth` (15). A caixa grande chama `CopyDrop(missão, SessionId)` — aqui o segundo número **é** o andar. Precisa de linhas `Para2` `,0,`, `,1,`, `,2,`… conforme o andar.

---

## 6. Como achar a % do formigueiro (ou do castelo) no SQL

Ordem prática:

1. `Pve_Info` onde `ID = 2` (formigueiro) ou `ID = 1` (castelo). Anote os scripts de cada dificuldade.
2. Abra o script (pasta `scripts/` no servidor, compilada em runtime) e leia `SetupMissions("…")`. São os IDs de missão.
3. Alternativa se o script não estiver à mão: `Mission_Info` pelo nome / script `DCSM2002` etc.
4. `Drop_Condiction` com `CondictionType = 5` e `Para1` contendo `,ESSE_ID,`.
5. `Drop_Item` com o `DropId` dessa linha. A coluna `Random` é o peso do corte (seção 4).
6. Para caixa/tiro: `CondictionType` 2 e 8, `Para1` contendo `,4,`.
7. Para lixo de NPC: `NPC_Info.DropId` do bicho daquela fase, depois `Drop_Item` direto.

Sem essas linhas, o `CopyDrop` devolve `false` e a carta vem vazia (ou só ouro se outra linha casar).

---

## 7. O que **não** altera a chance

- Sorte, GP, VIP, fortalecimento, composição (ver mandinga da forja: não existe pity cruzado).
- A lista colorida na carta da dungeon (`*TemplateIds`).
- `NpcInfo.DropRate`.
- `GP_RATE` / rates de PvP.
- Dificuldade da sala, **se** o script reutiliza o mesmo `Mission_Info.Id` — o `TakeCard` manda `1` sempre.

O que altera:

- Mexer em `Drop_Item.Random` / incluir ou tirar linha.
- Trocar o `Mission_Info.Id` no script da dificuldade.
- `macroDrop.ini` se o template estiver listado.
- Quantas cartas o `GameOver` deu (1 vs 2 sorteios).

---

## 8. Laboratório de luta (exceção)

`FightLabUserDrop`: acha a condição tipo 14, `Para2=,1,`, e **cria um item para cada linha** da tabela, quantidade `Next(Begin, End)`. Sem corte `Random`, sem `CanDrop`. Não é o formigueiro.

`CopyAllDrop` (boss de guilda) também entrega **todos** os que passam no corte, não só um.

---

## 9. O que mexer se for balancear

Ordem do projeto: **SQL → C#**. Flash só se a vitrine da carta tiver que mentir menos.

| Objetivo | Onde |
|----------|------|
| Formigueiro fácil dropar arma Y | `Drop_Item` da missão fácil + tipo `Copy` / `Para2=1` |
| Terror dropar tabela melhor | script da dificuldade com **outros** IDs de missão + outras linhas `Drop_Condiction` |
| Caixa do chão mais rica em **todas** as dungeons | tipo `Box`, `Para1=,4,` |
| Lixo do formiga soldado | `NPC_Info.DropId` daquele NPC |
| Impedir item raro farmado 200× no dia | `macrodrop\macroDrop.ini` no Center |
| Carta usar de verdade a dificuldade | hoje o C# manda `1`; teria que passar `eHardLevel` no `CopyDrop` **e** ter `Para2` no SQL |

Não misture isso com tradução. Nomes de item continuam no SQL de template.

---

## 10. Arquivos para abrir no código

| Arquivo | Por quê |
|---------|---------|
| `Game.Logic\DropInventory.cs` | Todos os canos e o sorteio |
| `Bussiness\Managers\DropMgr.cs` | Como casa `Para1` / `Para2` |
| `Bussiness\Protocol\eDropType.cs` | Números do `CondictionType` |
| `Game.Logic\PVEGame.cs` `TakeCard` / `GameOver` / `ShowBigBox` | Cartas e labirinto |
| `Game.Logic\Phy\Object\SimpleNpc.cs` | Drop ao morrer |
| `Game.Logic\BaseGame.cs` `CreateBox` | Caixa no mapa |
| `Game.Logic\Phy\Object\Player.cs` (tiro + `FireDrop`) | Drop no disparo |
| `Game.Logic\DropInfoMgr.cs` + `Center.Server\Managers\MacroDropMgr.cs` | Teto global |
| `SqlDataProvider\Data\DropCondiction.cs` / `DropItem.cs` | Colunas |
| `GameAdmin\Backup\XMLReader\XMLImport\LoadPVEItems.xml` | Nomes e IDs das dungeons (vitrine) |

Procedures: `SP_Drop_Condiction_All`, `SP_Drop_Item_All`.

---

## 11. Resumo em linguagem de jogador

Você entra no formigueiro ou no castelo. Matar formiga pode soltar um item da tabela **daquele** bicho. Caixa no chão e “item que cai depois do tiro” vêm de tabelas **da sala dungeon**, iguais em qualquer mapa desse tipo.

No fim da fase você vira 1 carta (ou 2 na última). Cada carta sorteia **um** item da tabela da **missão**, com a regra do corte `Random` — não é “1 em 100 escrito na pedra”. A figurinha de recompensa na porta da dungeon é propaganda; o servidor olha outra lista.

Para saber a % de verdade: abre o SQL, acha o ID da missão daquela dificuldade, e lê `Drop_Item`. Sem isso, qualquer número que a comunidade chutar é chute.
