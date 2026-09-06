# Sistema de combate do DDTank (neste emulador)

Este documento descreve **como a luta funciona neste código**, não o jogo oficial da 7Road. Tudo abaixo foi lido em `Game.Logic`, `Game.Server` e `Fighting.Server`.

Se você nunca viu o código: o jogador escolhe **ângulo** e **força**, atira, o servidor simula a bola no ar (gravidade + vento), cava o mapa se acertar o chão, e aplica dano se a explosão alcançar alguém.

Documentos irmãos: [`DOCUMENTACAO.md`](DOCUMENTACAO.md), [`DOCUMENTACAO-MODIFICACOES.md`](DOCUMENTACAO-MODIFICACOES.md), [`DOCUMENTACAO-ROAD.md`](DOCUMENTACAO-ROAD.md) (Freedom/PvE neste processo), [`DOCUMENTACAO-FIGHTING.md`](DOCUMENTACAO-FIGHTING.md) (só Match).

---

## 1. Onde o combate mora

Há **duas máquinas** envolvidas, mas **uma só biblioteca** de regras.

| Peça | Pasta | Papel |
|------|--------|--------|
| Sala / lobby | `Game.Server` | Cria a sala, o jogador clica em “pronto”, o servidor decide o tipo de luta |
| Regras da luta | `Game.Logic` | Turnos, física, dano, PvE, pets, cartas — **todo o combate de verdade** |
| Servidor de batalha | `Fighting.Server` | Só no PvP “ranked / match”: recebe a sala do Road e **roda o mesmo `Game.Logic`** |

Ou seja: Freedom (sala livre) e dungeon **correm no Road**. Match (fila) **corre no Fighting**. A física é a mesma.

---

## 2. Como uma luta começa

Tudo parte de `Game.Server\Rooms\StartGameAction.cs`. Três caminhos:

### 2.1 PvP livre (`Freedom`)

`GameMgr.StartPVPGame(...)` cria um `PVPGame` **dentro do Road**. Os dois times já estão na mesma sala.

### 2.2 PvE (dungeon, lab, world boss, labirinto…)

`GameMgr.StartPVEGame(...)` cria um `PVEGame` no Road. Missões, NPCs e chefes vêm do SQL + scripts.

### 2.3 PvP match (ranked / liga)

Processo, pairing e pacotes: [`DOCUMENTACAO-FIGHTING.md`](DOCUMENTACAO-FIGHTING.md).

1. A sala vai para `BattleMgr` → `BattleServer` (`Game.Server\Battle\`).
2. O Road manda a sala por TCP (porta **9208**) ao Fighting (`battle.xml`, não `FightServerIp`).
3. Lá ela vira um `ProxyRoom` (`Fighting.Server\Rooms\`).
4. A cada **5 segundos** o `ProxyRoomMgr` tenta emparelhar duas salas.
5. Quando casa: `GameMgr.StartBattleGame` → `BattleGame` (um `PVPGame` que fala com os jogadores via `ProxyRoom`).

O Fighting atualiza o jogo a cada **40 ms**. A thread das salas roda a **20 ms**.

### Tipos de partida (enums)

Em `Game.Logic\eGameType.cs` e `eRoomType.cs` existem, entre outros:

- Livre, guilda, dungeon, Fight Lab
- Elite, World Boss, boss de guilda, guerra de guilda
- Ring Station (vs bot), labirinto, liga por pontuação

A **máquina de combate é a mesma**. O que muda é o tipo da sala, a missão (PvE) e as recompensas no fim.

---

## 3. Estados da partida

`Game.Logic\eGameState.cs`:

```
Inited → Prepared → Loading → (filme de início) → GameStart → Playing
       → (filme de fim) → GameOver → Stopped
```

PvE ainda tem: sessão preparada, espera, “tentar de novo”, fim de todas as sessões.

O motor é `BaseGame.Update()` (`Game.Logic\BaseGame.cs`):

1. Anda o relógio interno
2. Executa a fila de **ações** (tiro voando, espera, filme…)
3. Se a fila esvaziou e o timer estourou → `CheckState`
   - PvP: `CheckPVPGameStateAction`
   - PvE: `CheckPVEGameStateAction`

Em `Playing`, se ninguém está atirando: ou passa o turno (`NextTurn`), ou acaba o jogo.

No Match, se `TurnIndex >= 100`, a luta **força o fim** (evita partida eterna).

---

## 4. Turnos: quem atira e por quê

Não é “time A, depois time B” fixo.

Cada personagem que joga turno (`TurnedLiving`: jogador ou chefe com `IsTurn`) tem um número **Delay**. Quem tem o **menor Delay** joga.

### Fórmula do Delay inicial do jogador

`TurnedLiving.GetTurnDelay()`:

```
delay = 1600 - 1200 × Agility / (Agility + 1200) + Attack / 10
```

Mais **Agility** → Delay menor → joga mais vezes. **Attack** aumenta um pouco o Delay (quem bate mais “pesa” a fila).

NPCs/chefes usam Delay inicial ≈ `Agility` do template.

### O que acontece num `NextTurn`

1. Checa e cria **caixas** no mapa
2. `PrepareNewTurn()` em todo mundo (reseta bônus de dano do turno)
3. Escolhe o próximo (`FindNextTurnedLiving`)
4. Subtrai o Delay dele de **todos** (`MinusDelays`) — a fila anda
5. `PrepareSelfTurn()` + `StartAttacking()`
6. Manda ao cliente: vento, tempo, caixas (`SendGameNextTurn`)
7. Começa o timeout (`WaitLivingAttackingAction`)

### Tempo do turno

Depende de `m_timeType` (a “barra” / modo de tempo da sala):

| Tipo | Segundos que o cliente vê (`getTurnTime`) | Espera interna (`GetTurnWaitTime`) |
|------|-------------------------------------------|-------------------------------------|
| 1 | 8 | 5 |
| 2 | 10 | 7 |
| 3 | 12 | 10 |
| 4 | 16 | 15 |
| 5 | 21 | 20 |
| 6 | 31 | 30 |
| outro | 10 | — |

PvE ajusta isso pela **dificuldade** da dungeon.

Se o tempo acaba sem tiro: o servidor **para o ataque** e passa o turno.

### Vento

- Valor no mapa: `Map.wind`
- `GetNextWind()` sorteia o próximo entre **−40 e +40**
- O cliente recebe o valor × 10
- Pode ser congelado (`FrozenWind`, `ConFineWind`)
- Ícones: `WindMgr`

### Ações do jogador no turno

O cliente manda pacotes `GAME_CMD`. O servidor despacha em `Game.Logic\Cmd\`:

| Código | Comando | O que faz |
|--------|---------|-----------|
| 96 | `FireTagCommand` | “Vou atirar” — prepara, pode gastar tempo |
| 2 | `FireCommand` | Tiro de verdade: `x, y, force, angle` |
| 12 | `SkipNextCommandP` | Pula: **+20 Dander**, **+10 PetMP**, Delay +100 |
| 17 | `SuicideCommand` | Morre na hora |
| 32 | `PropUseCommand` | Item de luta (anjo, gelo, voo…) |
| 15 | `StuntCommand` | Especial se Dander ≥ 200 |
| 40 | `FlyCommand` | Voo |
| 49 | `PickCommand` | Pega caixa |
| 54 | `SetGhostTargetCommand` | Fantasma (morto) escolhe alvo |
| 84 | `SecondWeaponCommand` | Arma secundária |
| 144 | `PetKillCommand` | Skill do pet |

Validação do tiro: `CheckShootPoint(x, y)` — não aceita coordenada absurda.

---

## 5. Física do tiro (ângulo + força)

### Do clique até a bola existir

1. `FireTag` (opcional) → `PrepareShoot`
2. `Fire` → `Player.Shoot(x, y, force, angle)`
3. `Living.ShootImp()`:
   - Busca o tipo de bola em `BallMgr` (peso, arrasto, vento, crater)
   - Velocidade inicial:

```
vx = force × cos(ângulo em radianos)
vy = force × sin(ângulo em radianos)
```

   (tiros múltiplos desviam uns ±5°)
4. Cria um `SimpleBomb`, aplica `setSpeedXY`, `StartMoving()`
5. Manda ao cliente a trajetória (lista de `BombAction`)

### Como a bola voa

Não é “linha reta até o chão”. É integração numérica (**Euler**) em `EulerVector`:

A cada passinho `dt = 0.04` segundos:

```
aceleração = (força − arrasto × velocidade) / massa
velocidade += aceleração × dt
posição += velocidade × dt
```

As forças (`UpdateAGW`) vêm do **mapa** e da **bola**:

```
arrasto  = map.airResistance × ball.DragIndex
gravidade = map.gravity × ball.Weight × massa
vento    = map.wind × ball.Wind
```

Por isso a mesma força **não** cai no mesmo lugar em mapas diferentes, nem com bolas diferentes (normal, gelo, voo, cura…).

A simulação para quando **acerta o chão/personagem** ou **sai do mapa**.

### Cratera

`Map.Dig(x, y, superfície, borda)` apaga pixels do tile (`Ground`). O formato do buraco vem de `BallMgr.FindTile(bombId)`.

Não cava se o alvo está em “sem buraco” (`NoHoleTurn` / `IsNoHole`) ou se a bomba é especial.

Tipos de bola (`BallMgr.GetBallType`): normal, gelo (`FORZEN`), voo (`FLY`), cura (`CURE`), etc.

---

## 6. Dano

Há **duas fórmulas-base** no código. Depois entram dezenas de efeitos (equip, pet, carta, guilda).

### 6.1 Corpo a corpo / genérico — `Living.MakeDamage`

`Game.Logic\Living.cs`:

```
reduçãoGuarda = 0,95 × (Guarda − 3×Nível) / (500 + Guarda − 3×Nível)

se (Defesa − Sorte) < 0:
    reduçãoDefesa = 0
senão:
    reduçãoDefesa = 0,95 × (Defesa − Sorte) / (600 + Defesa − Sorte)

dano = DanoBase
     × (1 + Ataque × 0,001)
     × (1 − (reduçãoGuarda + reduçãoDefesa − reduçãoGuarda×reduçãoDefesa))
     × CurrentDamagePlus
     × CurrentShootMinus
```

- Se o alvo tem **escudo da arma secundária** (`AddArmor` + `DeputyWeapon`), soma `getHertAddition` na guarda e na defesa.
- **`IgnoreArmor`** (prop de furar armadura, etc.): zera guarda e defesa.
- Dano calculado &lt; 0 → retorna **1**.

`CurrentDamagePlus` e `CurrentShootMinus` começam em **1** a cada turno (`PrepareNewTurn`). Itens, stunt e buffs mexem nisso. O stunt (`StuntCommand`) multiplica `CurrentShootMinus` pelo poder da bola especial.

### 6.2 Explosão do projétil — `SimpleBomb.MakeDamage`

Mesma ideia, com três diferenças:

1. Soma o **bônus de World Boss** (`FightBuffers.WorldBossAddDamage`), reduzido pela guarda/defesa do alvo: `WorldBossAddDamage × (1 − (Guarda/200 + Defesa×0,003))`.
2. **Queda por distância** até o centro da explosão:

```
se distância < raio:
    dano *= 1 − (distância / raio) / 4
```

Fora do raio: **0**.

3. `IgnoreArmor` **ou** `target.Config.CancelGuard` zeram guarda e defesa.

Há um segundo caminho, `MakePetDamage`, para explosão de pet. A fórmula é a mesma, mas se `(Defesa − Sorte) < 0` a redução de defesa **não** zera: usa `0,357 + Defesa × 0,00001` em vez de `0`.

NPC/chefe com `HaveShield` ou `CanTakeDamage = false`: **0**.

### 6.3 Crítico — `Living.MakeCriticalDamage`

```
chance = Sorte × 45 / (800 + Sorte) + PetEffects.CritRate

se chance ≥ número aleatório de 0 a 99:
    crit = (0,5 + Sorte × 0,00015) × danoBase
    crit = crit × (100 − reduções de gema/pet) / 100
    crit += FightBuffers.ConsortionAddCritical
senão:
    crit = 0
```

### 6.4 Aplicar o dano — `TakeDamage`

1. Evento **`BeforeTakeDamage`**: pets, cartas, equipamentos alteram `damage` e `critical` (é aqui que “a fórmula final” se espalha).
2. `total = max(0, dano + crítico)`
3. Jogador: ainda reduz % com `ReduceDamePlus`
4. `Blood -= total`
5. Se Blood ≤ 0 → morre (`Die`), salvo `KeepLife` ou modos especiais
6. Efeitos colaterais: gelo, invisível, sem buraco…

**Jogador** (`Player.TakeDamage`):

- Friendly fire não mata: deixa **1 HP**
- Ao levar dano vivo, ganha Dander:

```
Dander += (dano × 2/5 + 5) / 2
```

Não existe um único “número mágico final” no código. A base está acima; o resto é soma de efeitos em `Game.Logic\Effects\`, `PetEffects\`, `CardEffect\`.

---

## 7. Recursos durante a luta

| Recurso | O quê | Detalhe neste código |
|---------|--------|----------------------|
| **Blood** | Vida | No reset do jogador soma HP de equip, pet e buffers |
| **Dander** | “Raiva” / especial | Máx. **200**. +20 ao atirar ou pular; mais ao levar dano. Com ≥ 200 o `Stunt` usa a bola especial (`m_spBallId`) |
| **Energy** | Energia para props | ≈ `Agility/30 + 240` + buffers. Cada item gasta `Property4` |
| **PetMP** | Mana do pet | +10 ao atirar/pular; skill gasta `CostMP` |
| **Psychic** | Recurso de fantasma | Itens de morto usam `Property7` |
| **Ghost** | Jogador morto | Ainda “joga”: escolhe alvo (`SetGhostTarget`) e se move (`GhostMoveAction`) |

---

## 8. Itens de combate e caixas

### Props (`PropUseCommand`, categoria 10)

Carregados por `PropItemMgr`. IDs típicos da fight bag: **10001–10022**.

| ID (no código) | Efeito resumido |
|----------------|-----------------|
| 10001 | +2 tiros no turno |
| 10003 | Contador interno (`Prop2`) |
| 10004 | Power up |
| 10015 | Gelo |
| 10016 | Voo; `ShootCount = 1` |
| 10020 | Ignora armadura |
| 10022 | “Nuclear” — bola ID 4, ignora armadura tipo 2 |
| Categoria 17 | Anjo / cura |

Sem energia (`Property4`) o item não usa.

### Caixas

`BaseGame.CreateBox()`:

- Se o turno deu dano (`CurrentTurnTotalDamage > 0`), sorteia 1–2 caixas (`DropInventory.BoxDrop`)
- Se há mortos, pode nascer caixa de fantasma
- Pegar: comando 49

Depois do tiro, `DropInventory.FireDrop` pode dropar item na fight bag / temp bag.

Cura por bomba tipo `CURE`: usa a arma secundária (`Property7` × `1,1 ^ StrengthenLevel`).

---

## 9. PvE: mapas, ondas, chefes

### Dados

| Manager | Função |
|---------|--------|
| `MapMgr` | Clona o mapa, pontos de spawn |
| `MissionInfoMgr` | Missão no SQL: script, turnos, params |
| `NPCInfoMgr` | Vida/ataque do NPC |
| `DropMgr` / `DropInventory` | Drops de caixa, boss, tiro |
| `PveInfoMgr` | Qual instância PvE |

### Como a dungeon anda (`PVEGame`)

1. Construtor + `SetupMissions` — lista de IDs de missão (sessões)
2. `PrepareNewSession` — carrega `MissionInfo`, instancia a IA `AMissionControl` pelo **nome do script** (`MissionInfo.Script`)
3. `PrepareNewGame` — a IA spawna ondas (`OnStartGame`)
4. `CreateNpc` / chefe → `SimpleNpc` / `SimpleBoss`
5. Chefe usa `ABrain` (`NpcInfo.Script`)
6. `CanGameOver` é da **missão**, não uma regra única
7. Vitória → próxima sessão ou `GameOverAllSession`

Scripts compilam em runtime (pasta `scripts/`). Se falhar, cai em `SimpleMissionControl`.

No PvE, vários NPCs com turno podem atacar **no mesmo ciclo** se o delay passou de um limiar (`m_pveGameDelay`).

O mapa visual que você vê é a pasta `resource\image\map\`. A **colisão** que a bola acerta é o tile que o servidor carregou via `MapMgr` (arquivos de mapa no Road/Fighting, pasta `map\`).

---

## 10. Fim da luta e recompensas

### PvP — `PVPGame.GameOver`

Ganha o time do **último vivo**.

**Experiência (GP)** se a sala é `Match` — `CalculateExperience()`:

```
maxHurt = nívelMédioInimigo × qtdTime × 300
totalHurt = min(danoDoJogador, maxHurt)
winPlus = 2 se ganhou, senão 0

gp = ceil( (winPlus + totalHurt×0,001 + kills×0,5 + (acertos/tiros)×2)
         × nívelMédioInimigo × (0,9 + (tamanhoTime−1)×0,3) )
```

No C# o termo `(acertos/tiros)×2` é **divisão inteira**. Se você acertou menos tiros do que disparou, essa parcela vira **0**. Só entra `+2` quando `acertos == tiros` (100% de acerto).

- Teto: **12 000** GP
- +200 se você está 5+ níveis abaixo do time inimigo
- `DoubleEvent` no config → ×2
- VIP → +10 GP
- **Se `TotalHurt == 0`**: sem xu / exp / gift no Match

**Money / Gift / Exp extra (Match, com dano):** números **aleatórios** nos ranges do `Fighting.Service\App.config` (e equivalentes no Road):

- `MONEY_MIN/MAX_RATE_WIN` e `_LOSE`
- `EXP_MIN/MAX_RATE_WIN` e `_LOSE`
- `GIFT_MIN/MAX_RATE_WIN` e `_LOSE`

Guilda: bônus extra. Horário ouro: `GameProperties.GoldTimeStart/End` × `TimeX2`.

Guild match: riquezas ≈ perdedores + `TotalHurt/2000`.

### PvE — `PVEGame.GameOver`

```
ratio = (kills/killsTotais)×0,4 + (dano/danoTotal)×0,4 + (vivo? 0,4 : 0)
penalidade de nível (3–6 níveis de diferença): 1,0 / 0,7 / 0,4
bônus de party = (0,9 + (jogadoresInício−1)×0,4) / jogadoresAgora

gp = XP_total_dos_NPCs × ratio × penalidade × bônusParty
```

Score: `(200 − TurnIndex)×5 + kills×5 + (vida/vidaMáx)×10` (−400 se perdeu).

Cartas do boss: `BossCardCount`, `TakeCardCommand`, `DropInventory.BossDrop`.

### Atenção: chaves de config que **existem e não entram** nesta fórmula

No `PVPGame` / App.config há `GP_RATE`, `Gold_Rate`, `Gift_Rate`, `LeagueMoney_Win` (8) e `LeagueMoney_Lose` (3). **Neste código do `PVPGame.GameOver` elas não são usadas.** Liga money passa por outros fluxos (`AddLeagueMoney` no Game.Server). Se você mudar `GP_RATE` e a exp não mudar, é por isso.

---

## 11. Diagrama PvP match

```
Jogador pronto na sala (Road)
        │
        ▼
 BattleServer  ──TCP 9208──►  Fighting.Server
        │                         │
        │                    ProxyRoom (espelho)
        │                         │
        │                    a cada 5s tenta casar 2 salas
        │                         │
        │                    BattleGame (Game.Logic)
        │                         │
        │                    loop 40 ms: física, turnos, dano
        │                         │
        ◄──── pacotes ────────────┘
     Cliente Flash (ângulo, força, explosão)
```

Freedom / PvE: some o Fighting; o `PVPGame`/`PVEGame` roda no Road.

---

## 12. Hierarquia das entidades

```
Physics
 └── Living              vida, dano, tiro
      ├── TurnedLiving   entra na fila de turnos
      │    ├── Player
      │    └── SimpleBoss
      └── SimpleNpc      NPC; no PvE entra pela lista de livings
 └── SimpleBomb          o projétil
 └── Ball                definição (peso, vento, crater)
```

`LivingConfig`: pode tomar dano, tem turno, `KeepLife`, é ajudante, tem escudo, etc.

---

## 13. O que mexer se for balancear combate

| Quero… | Onde |
|--------|------|
| Mais/menos xu e exp por luta Match | `Fighting.Service\App.config` e `Road.Service\App.config` (`MONEY_*`, `EXP_*`, `GIFT_*`) |
| Dano base de um item | SQL do template (Attack, Defence, Lucky, BaseDamage, BaseGuard) |
| Gravidade/vento de um mapa | dados do mapa (`MapMgr` / SQL / arquivos de map) |
| Tipo de bomba (peso, crater) | `BallMgr` / tabelas de ball no SQL |
| Item de luta novo | SQL categoria 10 + `PropUseCommand` se o efeito for especial |
| Comportamento do chefe | script da missão / `ABrain` |
| Fórmula de dano em si | `Living.MakeDamage`, `SimpleBomb.MakeDamage`, `MakeCriticalDamage` |
| Efeito de pet/equip | classes em `Effects\`, `PetEffects\`, `CardEffect\` |

---

## 14. Arquivos para abrir no código

```
Game.Logic\BaseGame.cs
Game.Logic\PVPGame.cs
Game.Logic\PVEGame.cs
Game.Logic\Living.cs
Game.Logic\eGameState.cs
Game.Logic\eGameType.cs
Game.Logic\Phy\Object\Player.cs
Game.Logic\Phy\Object\SimpleBomb.cs
Game.Logic\Phy\Object\TurnedLiving.cs
Game.Logic\Phy\Maps\Map.cs
Game.Logic\Phy\Maths\EulerVector.cs
Game.Logic\BallMgr.cs
Game.Logic\Cmd\FireCommand.cs
Game.Logic\Cmd\FireTagCommand.cs
Game.Logic\Cmd\PropUseCommand.cs
Game.Logic\Actions\CheckPVPGameStateAction.cs
Game.Logic\Actions\CheckPVEGameStateAction.cs
Game.Server\Rooms\StartGameAction.cs
Game.Server\Battle\BattleServer.cs
Fighting.Server\Rooms\ProxyRoomMgr.cs
Fighting.Server\Games\BattleGame.cs
Fighting.Service\App.config
```

---

## 15. Resumo em linguagem de jogador

1. Você entra numa sala. Se for fila, o Fighting casa você com outro time.
2. O jogo escolhe quem joga pelo **Delay** (Agility ajuda).
3. No seu turno você gasta tempo: anda, usa item, aponta, atira.
4. O servidor **não confia** no desenho do cliente: ele simula a bola com gravidade, vento e arrasto.
5. A explosão dá dano pela fórmula de guarda/defesa/sorte, mais crítico, menos distância ao centro.
6. Pets, cartas e equipamento entram **depois**, nos eventos de “antes de tomar dano”.
7. Quem zerar a vida do outro time (PvP) ou cumprir a missão (PvE) ganha; as moedas do Match vêm dos ranges do `App.config`.
