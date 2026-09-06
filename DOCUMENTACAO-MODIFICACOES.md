# O que dá para modificar neste projeto

Com os arquivos que temos (servidor 4.1 em C#, cliente Flash, bancos `.bak` e a pasta `resource\` 3.6) dá para **modificar o jogo de verdade**. Não é um servidor fechado só para jogar.

O limite é: cada tipo de mudança mora num lugar diferente. Algumas pedem ferramenta que ainda não está no fluxo do dia a dia (compilador Flash, edição calma do SQL).

Documentos irmãos: [`DOCUMENTACAO.md`](DOCUMENTACAO.md), [`GUIA-SUBIR-SERVIDOR.md`](GUIA-SUBIR-SERVIDOR.md), [`DOCUMENTACAO-CENTER.md`](DOCUMENTACAO-CENTER.md), [`DOCUMENTACAO-ROAD.md`](DOCUMENTACAO-ROAD.md), [`DOCUMENTACAO-FIGHTING.md`](DOCUMENTACAO-FIGHTING.md).

---

## Em uma frase

Você controla **economia, itens, regras de combate e sistemas do servidor** de ponta a ponta. Controla **visual** na medida em que o resource 3.6 tiver o arquivo (ou você colocar um no mesmo caminho). Controla **interface** de verdade só mexendo em XML/textos ou recompilando o Flash.

O teto não é “o jogo é fechado”. O teto é tempo, SQL e, para UI profunda, a ferramenta de Flash.

---

## Cinco camadas

Quanto mais fundo, mais poder e mais trabalho.

### 1. Config (o mais fácil)

Arquivos `App.config` / `Web.config` e propriedades que o servidor lê (`GameProperties` em `Bussiness\GameProperties.cs`, muitas delas no banco / config).

Dá para mudar sem redesenhar o jogo:

- XP, ouro, xu, gift por vitória/derrota (`GP_RATE`, `EXP_*`, `MONEY_*` no Road e no Fighting)
- Nome do canal, portas, IP, quantidade máxima de jogadores
- Preço de casamento, fortalecimento e afins (várias chaves já estão no `Road.Service\App.config`)
- Ligar/desligar sistemas no `config.xml` do Flash (igreja, farm, world boss, dungeons…)

**Até onde:** economia e regras soltas. Não cria arma nova nem muda o visual do personagem.

---

### 2. Banco SQL (o miolo do conteúdo)

Itens, loja, missões, NPCs, drops, mapas liberados, prêmios diários. O C# quase só chama stored procedures (`SP_Items_All`, `SP_Shop_All`, `SP_Quest_All`…). Os dados moram nas tabelas.

Dá para:

- Colocar item na loja, mudar preço, tempo de duração
- Alterar drop de dungeon/caixa
- Mudar texto/recompensa de quest (se a UI Flash souber o ID)
- Dar gold/xu/item por script ou pelo painel (o `GameAdmin` existe, mas usa nome de banco antigo: `Db_Tank`)
- Cadastrar um **item novo** copiando um template parecido e mudando ID/nome/stats

**Até onde:** um servidor privado “de verdade” vive aqui (rate alto, loja custom, eventos).

**Travas:**

- Se o cliente 4.1 pedir um item e o resource 3.6 **não tiver a figurinha**, o item existe (stat, dano) e aparece **quadrado vazio**.
- Sem o gráfico e, às vezes, sem a linha no XML que o `Tank.Request` gera, o Flash ignora ou quebra o ícone.
- O jeito seguro de editar hoje é o SSMS. Não veio um editor visual oficial da 7Road. O `GameAdmin` precisa alinhar connection string antes de ser confiável.

---

### 3. Código C# do servidor (regras de verdade)

Source completo: `Game.Server`, `Game.Logic`, `Fighting.Server`, `Center.Server`, `Tank.Request`, `Bussiness`.

Dá para:

- Mudar física do tiro, dano, crítico, efeitos de pet/equip (`Game.Logic`) — detalhe em [`DOCUMENTACAO-COMBATE.md`](DOCUMENTACAO-COMBATE.md)
- Criar comando de GM, evento, sistema novo (se você programar)
- Alterar login, anti-flood, o `if (true)` frouxo do `Login.ashx`
- Corrigir bug, descomentar World Boss / League
- Mudar o que acontece ao fortalecer, fundir, casar, farm

**Até onde:** praticamente qualquer regra de servidor. É emulador aberto, não binário lacrado.

**Trava:** precisa compilar de novo no Visual Studio. Erro aqui derruba o Road no `Init`.

---

### 4. Cliente Flash (o que o jogador vê e clica)

Há o **código ActionScript** (`Source Flash\src\`) e os SWFs já compilados (`Source Flash\FlashSV1`).

**Sem recompilar Flash:**

- Trocar textos de UI nos XML em `FlashSV1\ui\vietnam\xml\` e no `language.txt`
- Ligar/desligar módulos no `config.xml`
- Trocar imagens que o SWF carrega de `/resource/` (roupa, mapa, ícone) — substituir o arquivo na pasta `resource\`

**Recompilando o cliente:**

- Mudar layout, botão, fluxo de tela, textos embutidos no SWF
- Esconder loja/cash, mudar como o hall funciona

**Travas:**

- Compilar AS3 pede Adobe Animate / Flash Builder / Apache Flex / toolchain antiga. O `asconfig.json` daqui gera `.swc` (biblioteca), não o `Loading.swf` / `game.swf` prontos. Não é “apertei F5 no Visual Studio”.
- Sem recompilar, muita lógica de tela está **dentro** do `.swf` e não se edita como HTML.

---

### 5. Resource (só pele)

A pasta `resource\` (pack 3.6): mapas, roupas, explosões, som.

Dá para:

- Trocar um mapa, uma arma, um ícone (mesmo nome de arquivo/pasta)
- Colocar skin custom se o **ID do item no SQL** apontar para esse caminho

**Não dá sozinho:** criar um sistema novo. Sem linha no SQL + código que use o ID, o arquivo de imagem é enfeite que ninguém pede.

Como o pack é 3.6 e o cliente é 4.1, **item muito novo do 4.1 pode não ter desenho**. Você altera o número no banco; a figurinha pode faltar.

---

## Tabela prática

| Quero… | Onde | Dificuldade |
|--------|------|-------------|
| Rate 10x, mais xu | `App.config` + às vezes SQL | Fácil |
| Item na loja / de graça | SQL (shop, templates) | Fácil / média |
| Arma com outro dano | SQL do template | Média |
| Arma com visual novo | SQL + arquivo em `resource\image\equip\...` | Média (se o path existir) |
| Traduzir para PT | XML / `language.txt` do Flash + `Language-vn.txt` do servidor | Média (trabalho, não mistério) |
| Evento / drop especial | SQL + às vezes C# | Média |
| Física do tiro diferente | `Game.Logic` | Difícil |
| Tela/loja totalmente outra | Recompilar Flash | Difícil + ferramenta extra |
| Virar “jogo novo” (Unity, mobile) | Fora deste stack | Não é este projeto |

---

## O que não temos / o que limita

1. **Editor oficial da 7Road** — conteúdo é tabela SQL + XML, não um “Unity do DDTank”.
2. **Resource 4.1 completo** — visual de coisa nova do 4.1 pode falhar.
3. **GameAdmin alinhado** — o painel existe, mas fala `Db_Tank`; o caminho seguro agora é SSMS.
4. **Flash compile ready** — source tem; o pipeline de build do cliente não está redondo.
5. **Trava de edição** — cliente, `Edition` no config e `SP_Server_Edition` no banco precisam continuar combinando; senão o Road nem sobe.

---

## Arquivos e pastas para lembrar

| Camada | Onde mexer |
|--------|------------|
| Economia / portas | `Road.Service\App.config`, `Fighting.Service\App.config`, `Center.Service\App.config` |
| Propriedades globais | `Bussiness\GameProperties.cs` + valores no SQL |
| Itens / loja / quest | Banco `Project_Player34` / `Project_Game34` (SPs `SP_Items_*`, `SP_Shop_*`, `SP_Quest_*`) |
| Regras e combate | `Game.Server\`, `Game.Logic\`, `Fighting.Server\` |
| Login HTTP | `Tank.Request\Login.ashx` (**inline neste PC**), `CreateLogin.aspx` |
| Textos e switches do cliente | `Source Flash\FlashSV1\config.xml`, `ui\vietnam\` |
| Gráfico e som | `resource\image\`, `resource\sound\` |
| Painel GM (depois de alinhar DB) | `GameAdmin\` |
