# Sistema de fortalecimento (neste emulador)

Este documento descreve **como fortalecer equipamento funciona neste código**, não o jogo oficial da 7Road. Tudo abaixo foi lido em `ItemStrengthenHandler`, `StrengthenMgr`, SQL/`Tank.Request` e na aba de forja do Flash.

Se você nunca viu o código: o jogador arrasta arma/elmo/roupa/secundária para a forja, coloca pedras, opcionalmente um amuleto de sorte e um amuleto de proteção, clica em fortalecer, e o **servidor** decide se o nível sobe, cai ou o item some.

Documentos irmãos: [`DOCUMENTACAO.md`](DOCUMENTACAO.md), [`DOCUMENTACAO-COMBATE.md`](DOCUMENTACAO-COMBATE.md), [`DOCUMENTACAO-MODIFICACOES.md`](DOCUMENTACAO-MODIFICACOES.md).

---

## 1. Resposta direta

O fortalecimento **não é uma fórmula única de “% na pedra”**. É:

1. Somar o “peso” das pedras (`RateItems` no C#).
2. Dividir pelo “custo” do nível alvo (`Rock` / `Rock1` / `Rock2` / `Rock3` no SQL).
3. Somar bônus de sorte, forja da guilda e VIP.
4. Comparar isso (escala 0–9999) com um número aleatório.

A regra de verdade mora no pacote TCP **59** (`ePackageType.ITEM_STRENGTHEN`), handler `Game.Server\Packets\Client\ItemStrengthenHandler.cs`. O Flash só monta a tela, estima a chance e manda um `bool` (se usa guilda). Se o cliente mentir, o servidor ignora o que não estiver nos slots da `StoreBag`.

**Ouro não é cobrado neste handler.** Existe `MustStrengthenGold` no `App.config` / `ServerConfig.xml`, mas nenhum C# lê essa chave. O campo de ouro na UI Flash (`_gold_txt`) também não é preenchido.

---

## 2. O que é (e o que não é) este sistema

| Sistema | Pacote | O que faz | Não confundir com fortalecimento |
|---------|--------|-----------|----------------------------------|
| **Fortalecer** | 59 `ITEM_STRENGTHEN` | Sobe `StrengthenLevel` com pedras; pode destruir ou rebaixar | Esta aba da forja |
| **Exaltar / thăng cấp** | `ITEM_ADVANCE` | Outra aba: pedra de exalt + `StrengthenExp`; teto 15 neste handler | `store/view/exalt` |
| **Fundir / compose** | `ITEM_COMPOSE` | Pedra de composição nos quatro stats | Slots diferentes |
| **Transferir** | `ITEM_TRANSFER` | Troca nível/furos entre duas armas (`InheritTransferProperty`) | Não é o clique de fortalecer |
| **Refinar** | `ITEM_REFINERY` | Equipamento refinado; pedra `Property1 == 35` | Aba própria |
| **Colar (necklace EXP)** | `StrengThenExp` | EXP do colar até nível 12 | `StrengthenMgr.GetNecklace*` — **não** usa o pacote 59 |

O array `StrengthenMgr.StrengthenExp[16]` **não entra** no handler 59. É resto morto para este fluxo.

---

## 3. Onde cada peça mora

```
Jogador clica na forja (Flash)
        │
        ├─ HTTP  Tank.Request/ItemStrengthenList.ashx
        │         XML comprimido: Rock, Rock1, Rock2, Rock3, StoneLevelMin
        │         (o cliente usa isso para desenhar a %)
        │
        ├─ HTTP  ItemStrengthenGoodsInfo (troca de template da arma no +10/+12/…)
        │
        └─ TCP  pacote 59 → Road.Service
                  ItemStrengthenHandler  ← autoridade
                  StrengthenMgr          ← tabelas em memória
                  SQL SP_Item_Strengthen_All / SP_Item_StrengthenGoodsInfo_All
```

| Camada | Arquivo | Papel |
|--------|---------|--------|
| Pacote | `Game.Server\Packets\Client\ItemStrengthenHandler.cs` | Valida slots, calcula chance, consome pedras, sobe/cai/some o item |
| Tabelas | `Game.Server\Managers\StrengthenMgr.cs` | `RateItems`, VIP 0,3, `GetNeedRate`, `StrengthenGoodsInfo` |
| SQL | `SP_Item_Strengthen_All` | Uma linha por nível alvo: `Rock` (arma), `Rock1` (elmo), `Rock2` (roupa), `Rock3` (secundária), `StoneLevelMin` |
| SQL | `SP_Item_StrengthenGoodsInfo_All` | Troca de `TemplateID` da arma (ex.: 7006 → 70061 no +10) |
| HTTP | `Tank.Request\ItemStrengthenList.ashx.cs` | Lista de taxas para o Flash |
| Flash | `Source Flash\src\store\view\strength\StoreIIStrengthBG.as` | Slots, avisos, % na tela, envio do pacote |
| Flash | `Source Flash\src\ddt\manager\GameSocketOut.as` `sendItemStrength` | Escreve só um `Boolean` (guilda) |

Amostra das taxas (backup do `GameAdmin`, **não** o banco ao vivo; o servidor lê o SQL):

| Nível alvo | Rock (todas as colunas iguais neste dump) | StoneLevelMin |
|------------|-------------------------------------------|---------------|
| 1 | 2 | 1 |
| 2 | 10 | 1 |
| 3 | 40 | 2 |
| 4 | 160 | 2 |
| 5 | 320 | 3 |
| 6 | 640 | 3 |
| 7 | 1280 | 4 |
| 8 | 2560 | 4 |
| 9 | 4400 | 4 |
| 10 | 7680 | 5 |
| 11 | 10240 | 5 |
| 12 | 12800 | 5 |

`StoneLevelMin` é gravado e enviado no XML. **Nem o handler 59 nem o cálculo de % do Flash usam esse campo.** Só o `Template.Level` da pedra entra em `RateItems`.

---

## 4. A tela: slots da `StoreBag`

A forja não manda IDs no pacote. O servidor lê **posições fixas** da mochila de loja (`StoreBag`):

| Slot | O que aceita | Como o servidor reconhece |
|------|----------------|---------------------------|
| 0, 1, 2 | Pedras (até 3) | Categoria **11**, `Property1` **2** (pedra normal) ou **35** (pedra de refinado) |
| 3 | Amuleto de proteção (“god”, bùa ma thuật / soul symbol) | Categoria 11, `Property1` **7** |
| 4 | Amuleto de sorte (bùa may mắn) | Categoria 11, `Property1` **3** |
| 5 | O equipamento | `CanStrengthen == true` e `Count == 1` |

Categorias que têm taxa SQL (`GetNeedRate`):

| `CategoryID` | Peça | Coluna SQL | Slot no personagem (equipado) |
|--------------|------|------------|-------------------------------|
| 7 | Arma | `Rock` | 6 |
| 1 | Elmo | `Rock1` | 0 |
| 5 | Roupa | `Rock2` | 4 |
| 17 | Arma secundária | `Rock3` | 15 |

Outra categoria com `CanStrengthen`: `GetNeedRate` devolve **0** e o cálculo **divide por zero** (exception no pacote). O Flash só oferece arma / elmo / roupa / secundária.

O cliente ainda exige:

- Pelo menos uma pedra e o item no slot 5.
- Nível abaixo de `STHRENTH_MAX` (padrão **12** em `PathInfo.as`; o `config.xml` deste repo **não** define a chave, então vale 12).
- Aviso extra no +5; a partir do +6 pede o amuleto de proteção; no +9 sem proteção o botão nem brilha.
- Não misturar pedra `2` com pedra `35`; item refinado (`RefineryLevel > 0`) só aceita `35`.

O servidor **não** replica o teto 12, nem o `StoneLevelMin`, nem a mistura 2/35: aceita as duas pedras no mesmo clique e soma os pesos.

---

## 5. O pacote (o que viaja na rede)

Cliente (`sendItemStrength`):

```
pacote 59
  Boolean isconsortia   // true se o jogador tem guilda e a forja da guilda tem taxa > 0
```

Servidor responde no mesmo pacote clonado:

```
Byte    0 = sucesso, 1 = falha
Boolean true no sucesso (o Flash trata como “abriu furo / animação ok”)
```

O Flash (`BaseStoreView.__showTip`) ainda conhece bytes 2 e 3 (falha “cinco” e reset da guilda). **Este handler nunca escreve 2 nem 3.**

Anti-flood: `countConnect >= 3000` desconecta. O contador **nunca é incrementado** neste arquivo — o teste está morto.

---

## 6. Fórmula da chance (servidor)

Constantes em `StrengthenMgr`:

```
RateItems (pelo Template.Level da pedra, índice Level − 1):
  nível 1 → 0,75
  nível 2 → 3
  nível 3 → 12
  nível 4 → 48
  nível 5 → 240
  nível 6 → 768

VIPStrengthenEx = 0,3
```

Passo a passo, com os nomes do código:

```
probability = soma de RateItems[pedra.Level - 1] nas slots 0, 1 e 2
              (precisa de ≥ 1 pedra válida)

need        = GetNeedRate(item)     // StrengthenInfo do nível ATUAL + 1
              cat 7 → Rock
              cat 1 → Rock1
              cat 5 → Rock2
              cat 17 → Rock3

num5 = probability × 100 / need          // chance base em “pontos percentuais”
num6 = 0
num4 = 0
num3 = 0
```

### Sorte (slot 4)

Se houver amuleto `Property1 == 3`:

```
num2 = probability + (Property2 / 100)     // Property2 é int: 10/100 = 0
num6 = num2 × 100 / need
```

Isso **soma a probabilidade das pedras de novo**, não “+10% do amuleto”. O bônus `Property2` some na divisão inteira. Na prática, **com sorte a parcela das pedras entra duas vezes**.

O Flash mostra outra conta: `pedras × (Property2 / 100)` como bônus separado (ex.: Property2 = 10 → +10% das pedras). A % da tela **não** é a % do servidor quando há amuleto de sorte.

### Guilda (`isconsortia == true`)

1. Carrega a guilda (`ConsortiaMgr.FindConsortiaInfo`).
2. Lê o controle de forja: `GetConsortiaEuqipRiches(ConsortiaID, 0, type: 2)`.
3. Se a riqueza do jogador (`PlayerCharacter.Riches`) for menor que o exigido: mensagem `ItemStrengthenHandler.FailbyPermission` e **não soma** o bônus (o clique continua).
4. Senão: `num4 = num5 × 0,1 × SmithLevel` (nível do prédio de forja da guilda).

Forja nível 5 → +50% da chance **base** (`num5`), não da chance já com sorte/VIP.

### VIP

Se `typeVIP > 0`: `num3 = 0,3 × num5`. Mesma base: +30% de `num5`.

### O dado

```
num7 = Floor( (num5 + num6 + num4 + num3) × 100 )
num8 = aleatório inteiro em [0, 9999]

se isPlayerWarrior(): num8 = 0     // sucesso garantido
                       // (flag interna: Extra.Info.coupleBossBoxNum == 9)

sucesso se num7 > num8
```

Não há teto em 100%. Três pedras baratas no +0 podem passar de 10 000 e acertar sempre.

**Antes do dado** o servidor já:

- incrementa `item.StrengthenTimes`
- marca `IsBinds` se o item **ou qualquer material** for vinculado
- chama `StoreBag.ClearBag()` — **apaga os seis slots** (pedras, amuletos e o próprio item). As pedras não voltam.

`isPlayerWarrior` não é classe de personagem; é um campo de evento (casal/boss) reaproveitado como “sempre acerta”.

---

## 7. Exemplos numéricos

Usando o dump `Rock` da tabela acima e **sem** sorte/guilda/VIP.

### 7.1 Arma +0 → +1, uma pedra nível 1

```
probability = 0,75
need        = 2
num5        = 0,75 × 100 / 2 = 37,5
num7        = Floor(3750) = 3750
P(sucesso)  = 3750 / 10000 = 37,50%     // sucesso se o dado for 0..3749
```

### 7.2 Arma +9 → +10, uma pedra nível 6

```
probability = 768
need        = 7680
num5        = 768 × 100 / 7680 = 10
P(sucesso)  = 10,00%
```

Com VIP: +3 pontos → 13%. Com forja da guilda 5: +5 pontos. VIP + guilda 5: **18%**.

Com amuleto de sorte **neste servidor** (sem VIP/guilda): `num6 ≈ num5` → cerca de **20%**, não 11%.

### 7.3 Três pedras nível 1 no +0

```
probability = 2,25
num5        = 112,5
num7        = 11250  > 9999  → sempre sucesso
```

---

## 8. O que acontece no sucesso

1. `StrengthenLevel++`.
2. **Só arma (categoria 7):** procura `StrengthenGoodsInfo` com `Level == novo nível` e `CurrentEquip == TemplateID` atual. Se `GainEquip > TemplateID`, clona o item para o template novo (ex.: 7006 no +10 vira 70061). Furos, bind, compose e o nível novo vão junto (`ItemInfo.CloneFromTemplate`).
3. `ItemInfo.OpenHole`: lê `Template.Hole` no formato `nível,tipo|nível,tipo|…`. Para cada furo 1–6, se `StrengthenLevel >= nível` e `tipo != -1`, e o furo ainda está negativo, abre (passa a `0`).
4. Devolve o item no slot 5, dispara `OnItemStrengthen` (missão / conquista), grava no SQL.
5. Se o nível ficou **≥ 10**, aviso mundial (`ItemStrengthenHandler.congratulation`).
6. Se for arma e o evento novato `STRENGTHEN_WEAPON_ACTIVE` estiver aberto, atualiza a condição com o nível novo.
7. Se o item estava em slot de equipamento (`Place < 31`), recalcula stats (`EquipBag.UpdatePlayerProperties`).

A tabela `StrengthenGoodsInfo` (amostra em `Tank.Request\itemstrengthengoodsinfo_out.xml`) encadeia skins da mesma arma:

```
7006  +10/+11 → 70061
7006  +12     → 70062
70061 +12     → 70062
70062 +15     → 70064
```

Elmo/roupa/secundária **não** trocam de template neste handler.

---

## 9. O que acontece na falha

Pedras e amuletos **já foram consumidos** (`ClearBag` veio antes do dado).

| Condição | Efeito no equipamento |
|----------|------------------------|
| Tem amuleto de proteção (slot 3 válido) | Item volta ao slot 5 **igual** (nível intacto) |
| Sem proteção **e** `Template.Level == 3` **e** `StrengthenLevel ≥ 5` | Nível cai **1**. Se a arma tinha trocado de template, tenta voltar via `FindRealStrengthenGoodInfo` (`OrginEquip` + nível novo) |
| Sem proteção **e** `Template.Level == 3` **e** nível &lt; 5 | Nível **não** cai; item volta |
| Sem proteção **e** `Template.Level != 3` | `Count--` e o item volta ao slot 5 (pode ficar com quantidade 0) |

`Template.Level` aqui é o **grau do template** (campo `Level` do item no SQL), não o `StrengthenLevel`. Só grau 3 entra na regra de “quebra e cai”; os outros graus, neste código, **somem a unidade**.

`OpenHole` também roda na falha (não reabre nada se o nível caiu abaixo do limiar, mas também não fecha furo já aberto).

O Flash no +9 sem proteção recusa o clique; o servidor **não** tem essa trava. Um cliente modificado fortalece +9 sem amuleto e, na falha, cai para +8 (se grau 3) ou perde o item.

---

## 10. O que o nível faz no combate e no poder

Fortalecer **não** multiplica Ataque/Defesa/Agilidade/Sorte do template. Esses quatro vêm do item + composição (`AttackCompose` etc.). O que escala com `StrengthenLevel` é o **Property7** (dano da arma / guarda do elmo e da roupa).

No lobby (`GamePlayer`):

```
para = StrengthenLevel + (1 se o item for “gold” / dourado, senão 0)

bônus = Round( Property7 × 1,1^para − Property7 )

arma  (slot 6):  Dano   += bônus + Property7   + gemas nos furos
elmo  (slot 0):  Guarda += bônus + Property7
roupa (slot 4):  Guarda += bônus + Property7
```

`GamePlayer.getHertAddition` devolve **só o bônus** (`Round(P7×1,1^n − P7)`). Em combate, `Living.getHertAddition(item)` devolve bônus **+** `Property7` (usado no escudo da arma secundária).

Arma secundária no poder de luta e na cura (`CURE`):

```
Property7 × 1,1 ^ StrengthenLevel
```

(sem o `− Property7` do elmo/arma principal). Usos do secundário: `deputyWeaponResCount = StrengthenLevel + 1`.

Detalhe da fórmula de dano da bola: [`DOCUMENTACAO-COMBATE.md`](DOCUMENTACAO-COMBATE.md) §6. O fortalecimento entra **antes**, no Dano/Guarda do personagem.

Furos abertos pelo strengthen só passam a valer quando o jogador **crava uma gema** (`ITEM_INLAY`). Abrir o furo (`HoleN = 0`) não dá stat sozinho.

---

## 11. Cliente Flash: o que ele calcula vs o servidor

Mesmos `rateItems` e as mesmas colunas `Rock*`. Diferenças que importam:

| Tema | Flash (o que a barra mostra) | Servidor (o que vale) |
|------|------------------------------|------------------------|
| Sorte | `pedras × Property2 / 100` (ex. +10%) | soma **de novo** as pedras; `Property2/100` vira 0 |
| Teto | recorta cada parcela e o total em 100% | sem teto |
| Pedra mínima | XML traz `StoneLevelMin`; a % ignora | ignora |
| Teto de nível | `STHRENTH_MAX` (12) | sem teto; nível 13 sem linha SQL estoura `null.Rock` |
| Proteção no +9 | recusa o clique | aceita |
| Mistura 2 e 35 | recusa no arrastar | aceita e soma |
| Ouro | leftover `_gold_txt` | não cobra |
| Intervalo | 500 ms entre cliques | nenhum |

VIP 0,3 e forja `× 0,1 × SmithLevel` coincidem com o servidor **em cima da chance base**, desde que a sorte não esteja no meio.

---

## 12. Sistemas vizinhos (só para não misturar)

### Exaltar (`ItemAdvanceHandler`)

Slots **outros** (0 = pedra de exalt, 1 = item). Gasta `StrengthenExp` contra `GameProperties.RateAdvance` (padrão 50 000). Sobe nível até 15 e também pode trocar template de arma. Aviso mundial usa `congratulation2` com `nível − 12`. **Não é o clique da aba fortalecer.**

### Transferência

`StrengthenMgr.InheritTransferProperty` troca nível, EXP, compose, furos e energia latente entre dois itens. Usado pelo pacote de transferência, não pelo 59.

### Colar

`SP_StrengThenExp_All` + `GetNecklaceLevelByGP`. Nível máximo 12. EXP do colar (`necklaceExpAdd`) entra no HP base (`GetBaseBlood`), não neste strengthen.

---

## 13. O que mexer se for balancear

Ordem do projeto: **SQL → config → C# → Flash**.

| Objetivo | Onde |
|----------|------|
| Deixar +10 mais fácil/difícil | Tabela do `SP_Item_Strengthen_All` (`Rock` / `Rock1` / `Rock2` / `Rock3`) |
| Pedra nível 4 “valer mais” | `StrengthenMgr.RateItems` **e** o array igual em `StoreIIStrengthBG.as` (senão a % mente) |
| VIP +50% em vez de +30% | `VIPStrengthenEx` no C# **e** `VipController.VIPStrengthenEx` no Flash |
| Teto 15 na aba fortalecer | `STHRENTH_MAX` no `config.xml` do Flash **e** linhas SQL 13–15 **e** trava no handler (hoje não existe) |
| Cobrar ouro | hoje a chave `MustStrengthenGold` **não faz nada**; precisaria ligar no handler |
| Não destruir item de grau ≠ 3 | ramo `item.Count--` no handler |
| Consertar a sorte | a linha `num2 += probability + Property2 / 100` — o Flash já trata `Property2` como porcentagem |
| Skin da arma no +10 | `SP_Item_StrengthenGoodsInfo_All` / XML `itemstrengthengoodsinfo_out.xml` |

Não altere `LanguageMgr` por causa disto. Mensagens: `ItemStrengthenHandler.Success` / `Fail` / `FailbyPermission` / `Content1`+`Content2` / `congratulation`. O ramo “item inválido” usa a chave **Success** (texto enganoso).

---

## 14. Arquivos para abrir no código

| Arquivo | Por quê |
|---------|---------|
| `Game.Server\Packets\Client\ItemStrengthenHandler.cs` | A regra inteira do clique |
| `Game.Server\Managers\StrengthenMgr.cs` | Pesos, VIP, `GetNeedRate`, troca de template |
| `SqlDataProvider\Data\ItemInfo.cs` `OpenHole` / `CloneFromTemplate` | Furos e clone no +10 |
| `Game.Server\GamePlayer.cs` `GetBaseAttack` / `GetBaseDefence` / `getHertAddition` | O que o nível vale fora da luta |
| `Game.Logic\Living.cs` `getHertAddition` | O que o nível vale na luta (secundária) |
| `Tank.Request\ItemStrengthenList.ashx.cs` | XML de taxas |
| `GameAdmin\Backup\XMLReader\XMLImport\ItemStrengthenList.xml` | Amostra das taxas |
| `Tank.Request\itemstrengthengoodsinfo_out.xml` | Amostra da troca de arma |
| `Source Flash\src\store\view\strength\StoreIIStrengthBG.as` | UI, % , travas do cliente |
| `Source Flash\src\store\analyze\StrengthenLevelIIAnalyzer.as` | Parse do XML |
| `Game.Server\Packets\Client\ItemAdvanceHandler.cs` | Exaltar (outra aba) |
| `Game.Server\Quests\ItemStrengthenCondition.cs` | Missão “fortaleça categoria X até nível Y” |

---

## 15. Resumo em linguagem de jogador

Você põe o equipamento no meio, até três pedras, às vezes um amuleto verde (sorte) e um dourado (não quebrar). O servidor some o “peso” das pedras, divide pelo número grande do próximo nível, soma forja da guilda e VIP, e tira um número de 0 a 9999.

Acertou: o item ganha +1. Arma no +10/+12 pode **mudar de desenho** (outro ID). Podem abrir furos de gema.

Errou: as pedras foram embora de qualquer jeito. Com o amuleto de proteção o item continua. Sem ele, item “grau 3” a partir do +5 **cai um nível**; os outros graus, neste código, **perdem o item**.

A porcentagem da tela é uma estimativa. Com amuleto de sorte ela **não** bate com o servidor. Ouro da forja, neste fork, **não é cobrado**.
