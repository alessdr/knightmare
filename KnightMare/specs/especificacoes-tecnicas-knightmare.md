# Especificações Técnicas e de Design: Game Design Document (GDD) — Knightmare (Majou Densetsu - MSX 1986)

Este documento apresenta a especificação detalhada de design e engenharia para a recriação e reconstrução do clássico *Knightmare* (Konami, 1986) em novas plataformas e ferramentas de geração de sprites e arte (como Nano Banana).

---

## 1. Tela de Abertura e Prólogo Narrativo

### 1.1 Narrativa e Prólogo
* **Contexto Teogônico:** Afrodite, a Deusa do Amor e da Beleza, foi aprisionada no Castelo das Pesadilhas pelo Príncipe das Trevas [1].
* **A Busca Inicial:** O corajoso guerreiro Popolon, apaixonado por Afrodite, parte em sua busca. Após uma busca infrutífera, cansado e abatido, Popolon é vencido pelo sono e tem um pesadelo terrível no qual milhares de criaturas horrendas ameaçam Afrodite [1].
* **A Intervenção Divina:** A Deusa Hera (irmã de Zeus) surge no sonho de Popolon e revela que o Castelo das Pesadilhas localiza-se além do Sagrado Monte Athos [1].
* **Instruções de Hera:** Hera orienta Popolon a utilizar o poder das joias mágicas deixadas por Afrodite ao longo do caminho, bem como os cristais mágicos do Olimpo [1]. Popolon desperta renovado sob a proteção de Hera e inicia sua marcha rumo ao Monte Athos [1, 2].

### 1.2 Apresentação Gráfica e Sonora
* **Identidade Visual:** Exibição do título principal *Knightmare* e do subtítulo original *Majou Densetsu* ("A Lenda do Castelo do Demônio") [4].
* **Trilha Sonora:** Abertura com tema marcante em estilo arcade sintetizado (composto por Miki Higashino) [3].

---

## 2. Estrutura e Sequência das Fases (*Stage Breakdown*)

### 2.1 Visão Geral
* **Total de Fases:** 8 fases progressivas com tempo total de partida entre 40 e 50 minutos [3].
* **Curva de Dificuldade:** A dificuldade é elevada desde o início, mas apresenta uma virada extrema ("curva em cotovelo") a partir da **Fase 6** (fases 6, 7 e 8), com aumento vertiginoso na velocidade dos projéteis, densidade de disparos e velocidade de rolagem [9].
* **Áudio:** As fases ímpares (Fases 1, 3, 5 e 7) compartilham o tema musical icônico de Miki Higashino [3].

### 2.2 Tipologia dos Cenários
| Fase | Tipo de Ambiente | Mecânicas Específicas de Terreno | Nível de Dificuldade |
| :--- | :--- | :--- | :--- |
| **Fase 1** | Trilha do Monte Athos (Externa) | Terreno aberto, árvores, riachos e pequenas pontes [1, 5] | Introdutória / Moderada [3] |
| **Fase 2** | Passagem de Montanha | Obstáculos rochosos e afunilamentos [5] | Moderada [3] |
| **Fase 3** | Travessia de Água | Rios largos com necessidade de criação de pontes [5] | Alta [5] |
| **Fase 4** | Interior do Castelo | Ambientes fechados, paredes e corredores mais amplos [5] | Moderada / Ampla [5] |
| **Fase 5** | Caminho Terrestre Avançado | Densidade alta de formações rochosas [5] | Alta [5] |
| **Fase 6** | Região Pré-Castelo (Água) | Rios rápidos e pontes estreitas exigindo precisão [5, 9] | Extrema [9] |
| **Fase 7** | Fortificação Exterior | Paredes de pedra e estreitamentos severos [5, 9] | Extrema [9] |
| **Fase 8** | Castelo das Pesadilhas | Layout final com máxima densidade de projéteis e inimigos [9] | Máxima / Brutal [9] |

---

## 3. Jogabilidade e Sistema de Mecânicas

### 3.1 Gênero e Controle
* **Estilo:** Vertical *Shoot 'em Up* (Shmup) arcade com controle de guerreiro em substituição a espaçonaves tradicionais [3].
* **Velocidade de Movimento:** A velocidade base de Popolon é lenta. Coletar o **Cristal Azul Escuro** concede upgrade de velocidade [8].
  * *Upgrade de Velocidade:* Pode ser acumulado até **3 vezes** (3x Speed). Alcançar o nível máximo de velocidade é requisito indispensável para a sobrevivência nas fases avançadas [8].

### 3.2 Armamento Principal
O jogador só pode carregar um tipo de arma por vez. As armas variam em cadência de tiro e poder de dano por impacto [6, 7]:

1. **Flecha de Fogo (*Fire Arrow*):**
   * *Cadência:* Baixa [7].
   * *Poder de Dano:* Extremamente Alto [7].
   * *Aplicação:* Essencial contra chefes de fase, permitindo destruí-los rapidamente antes que o escudo do jogador se esgoste [7].
2. **Flecha Dupla (*Double Arrow*):**
   * *Cadência:* Média/Boa [7].
   * *Poder de Dano:* Moderado/Equilibrado [7].
   * *Aplicação:* Melhor arma para uso geral durante a rolagem da fase [7].
3. **Faca Dupla (*Double Knife*):**
   * *Cadência:* Altíssima (metralhadora de projéteis) [7].
   * *Poder de Dano:* Muito Baixo [7].
   * *Aplicação:* Eficiente para limpar hordas fracas, porém ineficiente contra chefes [7].

### 3.3 Sistemas de Defesa e Power-ups Mágicos
* **Escudo Mágico (Cristal Azul Claro):**
  * Absorve projéteis inimigos [8, 9].
  * Mudança de estado: Azul Claro (100% de integridade) $\rightarrow$ Amarelo (Avariado) $\rightarrow$ Vermelho (Crítico) $\rightarrow$ Destruído [8].
  * *Limitação Crucial:* O escudo **NÃO protege contra colisão física direta** com inimigos [9].
* **Aura Vermelha (Poder Vermelho):**
  * Concede invulnerabilidade contra colisão e projéteis [8].
  * *Desvantagem:* Impede o jogador de disparar [8]. Pode causar derrota em trechos aquáticos por impossibilitar a criação de pontes [8].
* **Aura Branca (Poder Branco):**
  * Concede invulnerabilidade ao contato com inimigos [8].
  * *Vantagem:* Permite continuar disparando normalmente (considerado o melhor power-up defensivo do jogo) [8].

---

## 4. Movimentação dos Elementos e Física da Tela

### 4.1 Rolagem e Câmera
* **Auto-Scroll Vertical:** A tela avança continuamente de cima para baixo em velocidade constante (que acelera nas fases 6 a 8) [5, 9].

### 4.2 Lógica de Inimigos e Ondas (*Spawn Management*)
* **Regra da Última Unidade:** Uma nova onda de inimigos (*wave*) só é acionada após o **último inimigo da onda anterior** ser destruído ou sair completamente pela borda inferior da tela [6].
* **Estratégia de Controle de Fluxo:** Utilizar inimigos lentos (como os Cavaleiros Azuis) e atrasar sua eliminação permite adiar o surgimento da próxima onda, garantindo tempo para coletar itens de blocos [6].

### 4.3 Inteligência Artificial e Balística
* **Disparo Direcionado (Mira Ativa):** Todos os disparos dos inimigos são calculados na direção exata da posição atual de Popolon no momento do tiro (não há disparos aleatórios) [10].
* **Tiro Surpresa de Despedida (*Parting Shot*):** Inimigos prestes a desaparecer pela borda inferior da tela efetuam um disparo derradeiro diretamente contra o jogador [10].
* **Manobra de Esquiva:** Para atravessar a tela de um lado a outro, o jogador deve primeiro induzir os tiros inimigos para o lado oposto antes de realizar a travessia [10].

### 4.4 Colisão Direta
* **Contato Físico Fatal:** Qualquer toque direto entre Popolon e um inimigo resulta em morte instantânea, ignorando escudos ativos ou efeitos de congelamento de tempo [9].

---

## 5. Chefões de Fim de Fase

* **Estrutura do Confronto:** Cada uma das 8 fases encerra-se com uma arena contra um chefe de fase com padrões de movimentação e disparos pré-definidos [5, 9].
* **Padrões de Ataque:** Padrões determinísticos que devem ser memorizados [9].
* **Estratégia Recomendada:** Confrontar os chefes utilizando a **Flecha de Fogo** para minimizar o tempo de combate e evitar a destruição do escudo por projéteis [7].

---

## 6. Cenários e Construção de Mapeamento (*Tilesets*)

### 6.1 Mapeamento Terrestre e Aquático
* **Superfícies:** Gramados, rochas, paredes de pedra, rios e pontes [5].
* **Caselas de Interrogação (`?`):** Blocos destrutíveis distribuídos pelo cenário [5].
  * Ao serem atingidos por disparos, revelam **peças de xadrez** ou **cristais mágicos** [5, 6].
  * Na água, atirar em caselas especiais cria pontes para permitir a travessia terrestre [5, 8].

### 6.2 Peças de Xadrez e Efeitos Especiais
* **Peça Pontuação:** Concede pontos bônus [5].
* **Peça Aniquilação:** Elimina instantaneamente todos os inimigos presentes na tela [5].
* **Peça Vermelha (Ampulheta/Congelamento):** Paralisa o tempo e os inimigos na tela [5, 9]. *(Atenção: o contato físico com inimigos congelados continua sendo fatal)* [9].

---

## 7. Guia de Reconstrução de Sprites (Para Nano Banana / Pipeline Artística)

Para recriação fiel da pixel art em ferramentas de IA e motor gráfico moderno, utilize as diretrizes de prompt e paleta abaixo:

```yaml
Estilo_Artistico: "Retro 8-bit MSX Arcade Pixel Art, 16 cores, contornos limpos"

Sprites_Principais:
  Popolon:
    descricao: "Guerreiro grego/medieval com armadura cintilante, elmo e escudo circular"
    animacoes: ["Caminhada vertical (2 frames)", "Disparo de flecha/faca", "Morte/Impacto"]
    variaveis_aura: ["Aura vermelha brilhante", "Aura branca cintilante"]

  Cavaleiro_Azul:
    descricao: "Cavaleiro com armadura azul pesada, empunhando arco e flechas"
    movimentacao: "Lenta, caminhada em linha reta para baixo"

  Chefes_de_Fase:
    quantidade: 8
    estilo: "Criaturas mitológicas gregas gigantes e demônios alados"

Elementos_Especiais:
  Cristais:
    - nome: "Cristal Azul Escuro"
      efeito: "Upgrade de Velocidade (+1x ate +3x)"
    - nome: "Cristal Azul Claro"
      efeito: "Escudo Mágico (Azul -> Amarelo -> Vermelho)"
  Caselas:
    - nome: "Bloco ?"
      estilo: "Bloco de pedra esculpido com ponto de interrogacao amarelado"
```

---

## 8. Transições entre Fases

* **Animação de Transição:** Após a derrota do chefe da fase, o movimento de rolagem é interrompido momentaneamente.
* **Progressão:** O jogo exibe a pontuação e inicia imediatamente a rolagem do cenário da fase subsequente, mantendo os power-ups de velocidade e armamento acumulados pelo jogador [8, 9].
