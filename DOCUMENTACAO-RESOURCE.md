# Onde achar um pack jogável — pesquisa na internet

Pesquisa feita em setembro de 2026.

**Objetivo atual:** não ficar preso no DDTank 4.1 deste repositório. Se outra versão vier **completa** (servidor + banco + site + `/resource/` + cliente), vale trocar de projeto.

Conclusão em uma frase: **no GitHub quase só tem código. Pack “liga e joga” mora no RaGEZONE (conta obrigatória) e em Discords.** Não achei um Mega/Drive público, sem login, que eu possa confirmar como completo e vivo.

Documentos irmãos: [`DOCUMENTACAO.md`](DOCUMENTACAO.md), [`DOCUMENTACAO-LAUNCHER.md`](DOCUMENTACAO-LAUNCHER.md).

---

## Achado: pasta `resource/` no DDTank41 (pack 3.6)

Em 5/set/2026 você colocou o resource de um download **3.6** em:

`E:\Arquivos\Projetos\DDTank41\resource\`

Ela está no `.gitignore` (`resource/`) — não vai para o Git (correto: ~1 GB).

### O que veio

| Item | Situação |
|------|----------|
| Tamanho | **~1,04 GB**, **35.879 arquivos** — pack real, não source |
| `image/` | 900 MB / 35.723 arquivos |
| `sound/` | 144 MB / 154 faixas (`.flv` + alguns `.swf`) |
| `flash/` | Quase vazio (só `characterDefine.xml`) — o cliente continua sendo o `Source Flash/FlashSV1` |
| `crossdomain.xml` | Presente, libera qualquer domínio (`*`) — serve para IIS local |

Pastas em `image/` (o que o Flash pede de gráfico):

`equip` (289 MB, 18k arquivos), `map` (**668 mapas**, 244 MB), `bomb` (126 MB), `game` (98 MB), pet, card, farm, worldboss, church, title, tilemap, etc.

Isso **é** o buraco que faltava neste repo.

### Dá para usar com este servidor 4.1?

**Sim, como base.** O `Tank.Flash\config.xml` já aponta:

`<SITE value="http://127.0.0.1/resource/" />`

O cliente 4.1 (`FlashSV1`) e o resource 3.6 falam a mesma língua de pastas (`image/equip`, `image/map/1`, sons `1001.flv`…). Hall, personagem, mapas clássicos e tiros devem aparecer.

O que **pode** falhar: item/mapa/pet que o 4.1 pede e o 3.6 não tem → 404, ícone vazio, loading em 99% numa tela específica. Não impede testar o servidor.

Isto **não** é o servidor 3.6. Só o gráfico. Center/Road/Fight e os `.bak` continuam sendo os deste projeto 4.1.

### No IIS

Publicar esta pasta como `http://127.0.0.1/resource/` (virtual directory `resource` → `E:\Arquivos\Projetos\DDTank41\resource`).

`/flash/` continua sendo o `FlashSV1`, não a pasta `resource\flash` (ela está vazia).

---

## 0. Se a versão não importa — o que caçar

Não procure “source 4.1”. Procure um **repack** com estas pastas no mesmo zip:

| Tem que ter | Sem isso |
|-------------|----------|
| `Center` / `Road` / `Fight` (ou `.exe` prontos) | Não sobe servidor |
| `.bak` ou `.sql` (Db_Tank, Membership, etc.) | Servidor inicia e morre no SQL |
| Pasta `Request` (ou site PHP) | Flash não pega itens/mapas |
| Pasta **`Resource`** (image, mapas, som — centenas de MB+) | Loading para / tela preta |
| Cliente Flash ou launcher | Não abre o jogo |

GitHub (este repo, SkelletonX, GunnyArena) **falha nesse teste**: tem source, não tem `Resource` de verdade. O próprio GunnyArena escreve isso no README.

### Candidatos reais (RaGEZONE — precisa logar para ver o link)

Lista da seção [DDTank Releases](https://forum.ragezone.com/community/ddtank-releases.818/):

| Pack | Quando | O que o autor promete | Risco | Dificuldade para iniciante |
|------|--------|------------------------|-------|----------------------------|
| **[DDTank 9.2](https://forum.ragezone.com/threads/ddtank-9-2.1229657/)** (sticky, ~800 respostas) | 2024 | Files VN + **site PHP** + **launcher Electron** | Precisa conferir se o `Resource` veio no zip | Média. Stack parecida com o launcher do DDClássico (Electron). Mais coisa que 3.0. |
| **[5.5 PRISMA (BR)](https://forum.ragezone.com/threads/ddtank-5-5-prisma-br-gm-service-and-panel-full-100.1252687/)** | 2025 | Pack BR, senha `prisma`, painel GM | Relato de **tela preta** no tópico | Média. Mesma família Flash/IIS/SQL que você já leu neste repo. |
| **[3.9 Files Gift](https://forum.ragezone.com/threads/ddtank-3-9-files-gift.1249022/)** | 2025 | Center/Fight/Road + 3 bancos + site + **“Flash Resource”** + Request | Autor diz **não é full**, vende o completo; gente trava em **99%** | Mais baixa. Mais perto deste 4.1. |
| **[7.2 TH Open Source](https://forum.ragezone.com/threads/open-source-ddtank-7-2-th.1251766/)** | 2025 | Source + preview + download | Pouca discussão; link só logado | Média |
| **[4.1 + Source](https://forum.ragezone.com/threads/ddtank-files-4-1-source.1171801/)** / [OASES](https://forum.ragezone.com/threads/ddtank-files-4-1-oases.1165640/) | 2019+ | Files 4.1 (pets etc.) | Pedem reupload; Mega antigo cortado | Se o zip tiver Resource, casa com *este* repo |
| **12.5 / 12.6 / 14.7 CN** | 2025–26 | Pack de **12–16 GB** (logo, resource incluso) | Baidu, chinês, links que expiram | **Alta.** Não comece por aqui. |

**Ordem prática:** criar conta no RaGEZONE → baixar **9.2**, **5.5 PRISMA** e **3.9** → no Windows, olhar se existe pasta `Resource` grande → ficar com o primeiro que passar no teste da tabela.

Versão mais nova = jogo mais “bonito”, pack mais pesado, mais bug e menos tutorial em português. 3.x–5.x é o mesmo desenho que o `DOCUMENTACAO.md` já explica (IIS + SQL + 3 exes). 9.2 já traz launcher Electron, o que resolve Flash. 12.x é outro mundo.

Discords que ainda falam de pack completo: [Cyrus](https://discord.gg/cyrusteam) (autor deste 4.1) e [SkelletonX](https://discord.com/invite/4BRuPVV6bq). Pergunte “repack completo com resource”, não “source”.

---

## 0.1 O que fazer com o DDTank41 deste PC

Não apague ainda. Serve de mapa (Center / Road / Fighting / Request). Se o pack novo for 3.x–5.x, você vai reconhecer as pastas. Se for 9.2+, use o pack novo como projeto principal e este repo só como referência.

---

## 1. Por que o GitHub nunca traz isso

A pasta `/resource/` de um DDTank “completo” pesa de **centenas de MB a vários GB** (mapas, sprites de arma/roupa, sons, efeitos). Repositórios de código — inclusive o original deste projeto, [pnkl1999/DDTank41](https://github.com/pnkl1999/DDTank41) — **não** publicam isso. O autor aponta só para o Discord Cyrus e o YouTube.

O que este repo já tem (`Source Flash/FlashSV1`) é só o **cliente** (SWFs de interface + XML). Sem `/resource/`, o loading sobe e o jogo fica sem chão, personagem e arma.

---

## 2. O que procurar (e o que recusar)

| Tipo de pack | Serve neste projeto? | Motivo |
|--------------|----------------------|--------|
| Resource **Gunny 3.0 / DDTank 3.0** (2012) | Só como último recurso | É a base visual, mas falta muita coisa que o 4.1 pede (pets, cartas, mapas novos, sets) |
| Resource / files **DDTank 4.1** (RaGEZONE, OASES, Trminhpc) | **Melhor alvo** | Mesma geração deste código |
| Pack **6.1 / 9.x / 12.x** como *resource solto* neste 4.1 | Não | Cliente e IDs diferentes. **Como projeto inteiro novo**, 9.x pode servir (veja seção 0) |
| CDN do **DDClássico** (`resource.ddclassico.com`) | Não | Outro servidor, outra versão; não é pacote deste repo |
| Só “source” no GitHub (SkelletonX, GunnyArena, este repo) | Não resolve | Código sem pasta `image/` / `sound/` / mapas |

Um pack útil, depois de extraído, costuma ter pastas do tipo:

- `image/` (personagem, item, UI extra)
- mapas / `map` / tiles
- `sound` / `audio`
- às vezes `bomb`, `living`, `game`, `ui`

Se o zip só tiver `.cs` / `.aspx` / `.swf` de hall/loja, **não é resource**.

O `config.xml` deste projeto já espera:

`http://127.0.0.1/resource/`

No IIS isso vira uma pasta (ou virtual directory) chamada `resource` (minúsculo, como no XML).

---

## 3. Onde ainda faz sentido procurar (ordem de prioridade)

### 3.1 Discord do autor deste código — melhor primeiro passo

Este GitHub **é** o [pnkl1999/DDTank41](https://github.com/pnkl1999/DDTank41). O README manda para:

- Discord Cyrus: [https://discord.gg/cyrusteam](https://discord.gg/cyrusteam)
- YouTube: [https://www.youtube.com/@pnkl1999](https://www.youtube.com/@pnkl1999)

Quem compilou o `FlashSV1` vietnamita e os `.bak` `Player34`/`Game34` é esse grupo. Se alguém tem o resource **casado** com a edição 10990, é lá. Pergunte por “resource 4.1” / “resource 10990” / “FlashSV1 resource”.

O mesmo autor apareceu no RaGEZONE em 2024 com um servidor inglês ([thread](https://forum.ragezone.com/threads/ddtank-version-3-0-english-2024-support-mobile.1238739/)) e outro Discord: `https://discord.com/invite/qfgEPnRXdU`.

### 3.2 RaGEZONE (precisa criar conta)

Os links de download ficam **atrás do login**. Sem conta, a página não mostra Mega/Drive.

Threads úteis da mesma linha:

| Thread | O que é | Observação |
|--------|---------|------------|
| [DDTank Files 4.1 + Source](https://forum.ragezone.com/threads/ddtank-files-4-1-source.1171801/) | Files 4.1 + source (Trminhpc / JeffzSplush) | Mais alinhado com este repo. Gente pedindo reupload — o link original pode ter morrido. |
| [DDTank Files 4.1 OASES](https://forum.ragezone.com/threads/ddtank-files-4-1-oases.1165640/) | Pack 4.1 com pet etc. | Comentários pedem flash/website à parte. Havia Mega em 2019; provavelmente morto. |
| [DDTank 3.9 Files Gift](https://forum.ragezone.com/threads/ddtank-3-9-files-gift.1249022/) | Emulador + “Flash Resource” recente | Autor admite que **não é full**. No próprio tópico alguém trava em 99% e pede resource. Versão 3.9, não 4.1. |
| [Resource DDTank 3.0 (2012)](https://forum.ragezone.com/threads/resource-for-server-ddtank-3-0-update-7-4-2012.833851/) | Resource clássico Gunny 3.0 (~400 MB em partes) | Histórico. Links de 2012. Incompleto até para boss na época. |

Seção do fórum: **RaGEZONE → Server Developments → DDTank**.

### 3.3 Discord / wiki brasileiros do 4.1

[SkelletonX/DDTank4.1](https://github.com/SkelletonX/DDTank4.1) é outro source 4.1 (BR). Também **não** traz resource no GitHub. A wiki (“Configurando DDT”) e o vídeo [youtube.com/watch?v=zYMC9TeS3Q4](https://www.youtube.com/watch?v=zYMC9TeS3Q4) ensinam IIS/SQL. Discord deles: [https://discord.com/invite/4BRuPVV6bq](https://discord.com/invite/4BRuPVV6bq).

Fórum vietnamita [CLBGAMESVN — ĐTank 4.1 FULL SOURCE](https://www.clbgamesvn.com/diendan/showthread.php?t=326777): download só para membro logado. Comentário típico: “source bom, Flash ainda incompleto”.

### 3.4 Blogs e MediaFire de 2012 — quase certamente mortos

Espelhos do mesmo resource 3.0:

- [ddtank4you.blogspot.com — Resource 3.0 NEW](http://ddtank4you.blogspot.com/2012/07/resource-30-new.html) (3 rars MediaFire ~150+150+88 MB + patches)
- [ddtankth.com.br — Resource 3.0](https://www.ddtankth.com.br/2012/08/resource-30.html)

Hosts: MediaFire, 4Shared, FileSonic. Em 2026 isso em geral dá **link morto**. Vale um clique; não conte com isso.

Havia um Mega de 2019 no pack OASES (`mega.nz/#!TfAjnY4I!...`) republicado em fórum Metin2. A chave está **cortada** na cópia pública; não dá para baixar assim.

### 3.5 Packs 6.1 em fóruns BR

Tutoriais tipo [Files 6.1 + Site + Resource](https://stawer.forumeiros.com/t17-ddtank-files-6-1clean-site-resource-mini-tutorialdd) falam em extrair `Resource` no IIS. Isso é **outra geração** (cliente mais novo, Flash “apenas Viet” em alguns posts). Não use como resource deste 4.1, a menos que queira trocar o cliente inteiro — e aí este repositório deixa de ser o alvo.

---

## 4. O que **não** fazer

- **Não** apontar o `config.xml` deste repo para `https://resource.ddclassico.com`. É o acervo do servidor em que você joga, outra versão, e não é material deste projeto.
- **Não** misturar resource 12.x (vários GB, fóruns chineses / Baidu) com o `FlashSV1` daqui.
- **Não** esperar que um clone “full source” no GitHub venha com `image/` completo. Os que existem (este, SkelletonX, GunnyArena) são código.

---

## 5. Como validar um pack se você achar um

1. Extrair e ver se existem pastas de imagem/mapa/som de verdade (não só source).
2. Publicar no IIS como `http://127.0.0.1/resource/` (o XML daqui usa minúsculo).
3. Conferir `crossdomain.xml` (o FlashSV1 já aponta para `http://127.0.0.1/resource/crossdomain.xml`).
4. Abrir o jogo e olhar a aba Rede: 404 em `resource/image/...` = pack incompleto ou versão errada; 200 = caminho certo.
5. Se o loading para em ~99%, a causa clássica da comunidade é **resource incompatível ou faltando arquivo**, não o C# do Road.

Mesmo um pack 4.1 “bom” pode ter buraco (set, igreja, spa, um mapa). Os posts antigos já vinham com “patch church/spa” e “patch set”.

---

## 6. Veredito da pesquisa

| Pergunta | Resposta |
|----------|----------|
| Tem resource 4.1 / 10990 solto no Google, sem conta? | **Não achei nenhum link vivo e completo.** |
| O autor deste source disponibiliza? | Não no GitHub. Caminho oficial dele: **Discord Cyrus**. |
| Dá para usar o resource 3.0 de 2012? | Talvez o hall abra com gráficos velhos; pets/cartas/mapas 4.1 vão falhar. |
| Melhor esforço agora | 1) Discord Cyrus 2) conta no RaGEZONE nos tópicos 4.1 3) Discord SkelletonX |
| Launcher antes do resource? | Não. Sem essa pasta o Electron só mostra loading quebrado. |

Quando (e se) um pack da linha 4.1 aparecer, o próximo passo é só hospedar no IIS e apontar o `SITE` do `FlashSV1/config.xml` para `http://127.0.0.1/resource/`. Até lá, SQL e launcher esperam.
