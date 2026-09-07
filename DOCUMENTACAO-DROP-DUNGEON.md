# Cartas do chefe no fim da dungeon

Este documento trata **só** do que acontece quando a equipe vence uma fase (ou a dungeon inteira) e cada jogador vira as cartas na tela de recompensa. Não cobre caixa no chão, lixo de formiga morta, drop depois do tiro, labirinto nem laboratório de luta.

Vale **este** código, não o jogo oficial. A regra está em `PVEGame.TakeCard` → `DropInventory.CopyDrop`.

Documentos irmãos: [`DOCUMENTACAO.md`](DOCUMENTACAO.md), [`DOCUMENTACAO-COMBATE.md`](DOCUMENTACAO-COMBATE.md).

---

## 1. O que é (e o que não é)

Depois do `GameOver` da missão, o Flash mostra um baralho. Cada virada chama o pacote de carta (`TakeCardCommand` / `BossTakeCardCommand`). O servidor **não** olha qual figura estava naquela posição: o índice só marca “essa casa já foi usada”. O item é sorteado **na hora**, na tabela SQL da **missão que acabou**.

A lista de prêmios na porta da dungeon (`Pve_Info.SimpleTemplateIds` etc.) é vitrine. O sorteio **não** usa essa lista.

`DropInventory.BossDrop` existe no C# e **não é chamado** aqui. O nome “carta do boss” no cliente não muda o fato: o handler usa `CopyDrop`.

---

## 2. Quantas cartas cada um ganha

No `PVEGame.GameOver`:

| Resultado | Cartas grátis (`BossCardCount` / `CanTakeOut`) |
|-----------|-----------------------------------------------|
| Perdeu a fase | 0 |
| Venceu e **ainda tem** próxima fase | 1 |
| Venceu a **última** fase (e não é tutorial) | 2 |

Em sala `Dungeon`, cada virada gasta 1. Acabou o saldo → `FinishTakeCard`. Dá para comprar **mais uma** carta (`PaymentTakeCardCommand`): 486 cupom, ou 437 se VIP, ou o buff `Card_Get`. Essa extra passa pelo **mesmo** `TakeCard` e pela **mesma** tabela.

Duas cartas = dois sorteios independentes. Virar a segunda não “compensa” a primeira.

---

## 3. Qual tabela o servidor abre

Cada virada:

```
id = TakeCardId   (no GameOver vira o MissionInfo.Id da fase que acabou)
CopyDrop(id, 1)
```

O `1` é **literal**. Não é a dificuldade (fácil/normal/difícil/terror) e não é o número da fase.

`CopyDrop` procura em `Drop_Condiction` a **primeira** linha em que:

- `CondictionType = 5` (`eDropType.Copy`)
- `Para1` contém `,` + id da missão + `,` (ex.: `,2002,`)
- `Para2` contém `,1,`

Essa linha aponta para um `DropID`. Os candidatos são todas as linhas de `Drop_Item` com esse `DropID`.

Formigueiro e castelo da galinha (“castelo bugou”) não têm % no C#. Cada um só chega numa missão diferente:

| Instância (`Pve_Info.ID`) | Nome no XML | Nome BR comum |
|---------------------------|-------------|---------------|
| 2 | Huyệt Ma Kiến | Formigueiro |
| 1 | Lâu đài Gà | Castelo da galinha / castelo bugou |

A dificuldade escolhe um **script** (`SimpleGameScript`, `NormalGameScript`, …). O script lista os IDs de missão (`SetupMissions`). Fácil e terror só mudam a tabela da carta se carregarem **IDs de missão diferentes**. Se o terror reutilizar o mesmo `Mission_Info.Id`, a carta lê a mesma linha `Para2=,1,`.

---

## 4. Como um item é escolhido

`GetDropItems`, um sorteio por carta, no máximo **um** item (ou moeda).

```
maxRandom = maior coluna Random da tabela
maxRound  = número ao acaso em [0, maxRandom)

candidatos = linhas com Random >= maxRound
escolhe 1 candidato, todos iguais
quantidade = número em [BeginData, EndData)
```

`Random` alto passa no corte com mais frequência. O item com o maior `Random` **sempre** entra na urna. Item com `Random` baixo quase nunca entra; quando entra, compete de igual para igual com os comuns que também passaram.

Não é “peso dividido pela soma”. Um raro com `Random = 100` ao lado de um comum com `10000` **não** tem 1% exato: na maior parte das viradas ele nem chega à urna.

Depois do sorteio, `DropInfoMgr.CanDrop(TemplateID)` pode **anular** o item se o template estiver no `macrodrop\macroDrop.ini` do Center e o teto do ciclo tiver estourado. Templates fora do `.ini` passam sempre.

IDs especiais viram moeda, não item na mochila:

| `ItemId` | Vira |
|----------|------|
| −100 | Ouro |
| −200 | Cupom |
| −300 | Presente |
| 11107 | GP (em outros fluxos; na carta passa pelo `ShopMgr.FindSpecialItemInfo`) |

Item de verdade vai para a temp bag. `IsTips` dispara aviso no chat.

Se não existir condição `Copy` + aquele ID + `Para2=1`, `CopyDrop` falha e a carta não entrega nada.

---

## 5. Colunas que importam

`Drop_Condiction` (quando usar a tabela):

| Coluna | Neste fluxo |
|--------|-------------|
| `DropID` | Liga nos itens |
| `CondictionType` | Tem que ser **5** |
| `Para1` | Lista de IDs de missão, com vírgula nas pontas |
| `Para2` | Tem que casar `,1,` |

`Drop_Item` (o que pode sair):

| Coluna | Papel |
|--------|--------|
| `DropId` | A tabela |
| `ItemId` | Template ou moeda negativa |
| `Random` | Peso do corte (maior = mais comum) |
| `BeginData` / `EndData` | Quantidade, intervalo semiaberto |
| `IsBind` | Vinculado |
| `ValueDate` | Validade em dias |
| `IsTips` | Aviso mundial |

---

## 6. Como achar a tabela do formigueiro (ou do castelo)

1. `Pve_Info` ID 2 (formigueiro) ou 1 (castelo). Anote o script da dificuldade.
2. No script, `SetupMissions("…")` — esses números são as fases. A carta usa o ID da fase **que acabou de terminar**.
3. `Drop_Condiction` com tipo 5, `Para1` contendo esse ID, `Para2` contendo `1`.
4. `Drop_Item` com o `DropID` dessa linha. Aí está a urna da carta.

Sem o SQL ao vivo não dá para cravar “arma X = Y%”.

---

## 7. O que não muda esta carta

- Sorte, GP, VIP (VIP só barateia a carta **paga**).
- Fortalecer / composição.
- A vitrine `*TemplateIds` na porta da dungeon.
- Dificuldade da sala, se o script repetir o mesmo ID de missão.
- Qual casa do baralho o jogador clicou.

O que muda: `Drop_Item.Random` e as linhas da tabela; IDs de missão no script; `macroDrop.ini` se o template estiver listado; 1 vs 2 cartas (e a extra paga).

---

## 8. Arquivos

| Arquivo | Papel |
|---------|--------|
| `Game.Logic\PVEGame.cs` (`GameOver`, `TakeCard`) | Quantas cartas e o sorteio na virada |
| `Game.Logic\DropInventory.cs` (`CopyDrop`, `GetDropItems`) | Corte `Random` e a escolha |
| `Bussiness\Managers\DropMgr.cs` | Casa `Para1` / `Para2` |
| `Game.Logic\Cmd\TakeCardCommand.cs` | Clique grátis |
| `Game.Logic\Cmd\PaymentTakeCardCommand.cs` | Carta paga |
| `Game.Logic\DropInfoMgr.cs` | Teto do Center |
| `GameAdmin\Backup\XMLReader\XMLImport\LoadPVEItems.xml` | Nomes das dungeons (não é a urna) |

Procedures: `SP_Drop_Condiction_All`, `SP_Drop_Item_All`.

---

## 9. Em linguagem de jogador

Imagina que o chefe caiu e a tela enche de cartas viradas para baixo. Você não está “descobrindo” um prêmio que já estava embaixo daquela carta. O servidor espera você clicar e **aí** sorteia. Clicar na ponta esquerda ou na do meio dá no mesmo: a casa só fica marcada como usada, para ninguém virar duas vezes o mesmo lugar.

Quantas viradas grátis você ganha depende só do resultado da fase. Perdeu: nenhuma. Passou de uma fase e ainda tem mapa pela frente: uma. Zerou a dungeon (não é o tutorial): duas. Se quiser mais uma, paga cupom (um pouco menos sendo VIP). Essa extra entra na mesma fila e usa a **mesma** lista de prêmios.

Essa lista não é a figurinha bonita na porta do formigueiro ou do castelo. Aquilo é propaganda: “por aqui *pode* sair isso”. A lista de verdade está no banco, amarrada à **fase que você acabou de terminar**. Formigueiro fácil e formigueiro terror só mudam o que cai na carta se o jogo tiver cadastrado fases diferentes para cada dificuldade. Se for a mesma fase no papel, a urna é a mesma.

Dentro da urna cada prêmio tem um número grande ou pequeno (a coluna `Random`). O servidor tira um valor ao acaso, joga fora quem tem número menor que esse valor, e sorteia **um** entre os que sobraram, sem favorito. Por isso o ouro e a pedra comum saem o tempo todo: o número deles é alto, eles quase nunca são cortados. A arma rara tem número baixo; na maioria das viradas ela nem chega a concorrer. Quando o corte está baixo o bastante para ela entrar, ela compete de igual com o resto que também entrou — não é “1 em 100 escrito na carta”.

Duas cartas seguidas são dois sorteios soltos. Tirar ouro na primeira não “aumenta” a chance da segunda. Sorte do personagem, fortalecer a arma antes, falhar pedra de composição: nada disso entra nesta conta.

Se ninguém cadastrou a fase na tabela certa, a carta abre e não vem item. Se o item raro estiver no teto diário do servidor (`macroDrop`), o sorteio até pode “acertar” e você ainda assim não leva — o servidor engole o prêmio porque o limite do dia encheu.

Para saber o que o **seu** formigueiro realmente solta: olha no SQL a fase que o mapa usa e a lista `Drop_Item` ligada a ela com o marcador `1`. Qualquer porcentagem que a comunidade chutar sem essa lista é chute.
