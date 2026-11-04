# Implementação experimental X1 — fase AC

Estado: rascunho revisado (versão 3); implementada para avaliação; nenhum ganho competitivo foi demonstrado por esta entrega. O SOM continua no treino e na geração de soluções. O protocolo e as regras de decisão estão em [phase_AC_protocol.md](phase_AC_protocol.md).

## Algoritmos disponíveis

| Classe PlatEMO | Perfil | Mecanismo adicional |
|---|---|---|
| `TPIMMOEA_X1C` | `cooperative` | Transporte da normalização, grafo esparso, massa cooperativa limitada e leitura com suporte direto |
| `TPIMMOEA_X1M` | `move_som` | X1C com campo local de movimentos, compartilhado no treino e na leitura pelo SOM |
| `TPIMMOEA_X1F` | `repair_som` | X1C com modelos afins individuais de restrições e projeção com folgas |
| `TPIMMOEA_X1CMF` | `combined` | Combinação experimental; deve ser selecionada apenas após as ablações |

Os arquivos estão em `PlatEMO/Algorithms/Multi-objective optimization/TPIMMOEA_X1/`. Cada classe aceita `outN` como seu único parâmetro: 0 reporta o arquivo de busca de até 2N; 1 reporta N soluções escolhidas pela seleção existente. Nos experimentos RWMOP, o executor fixa `outN=1`.

O ponto único de integração é `TPIMMOEA_X.m`. Seu parâmetro 45, `x1Options`, é opcional. Vazio mantém o caminho histórico; os 44 parâmetros anteriores conservam suas posições. `x1_parameters` constrói os perfis e fixa `instr=0`: as novas rotinas não usam chamadas de `CalObj`/`CalCon` fora do orçamento.

## Cooperação e suporte

`x1_graph` constrói um grafo mútuo dos quatro vizinhos angulares mais próximos. Componentes desconectadas permanecem desconectadas. O controle de permutação usa um fluxo aleatório privado e preserva a sequência aleatória do otimizador. O grafo histórico é devolvido sem reconstrução no controle `identity`.

Se `c_j` é o número de BMUs diretos da região j na chamada de treino, a confiança é `q_j=c_j/(c_j+2)`. Atualizações recebidas dos vizinhos não contam como evidência direta. Durante a fase de ordenação, o vencedor conserva peso 1. Os pesos gaussianos dos outros nós são multiplicados por `sqrt(q_b*q_j)` e normalizados para somar 1 quando há suporte; sem suporte, sua soma é zero. Esse orçamento refere-se a cada apresentação de amostra, não a todo o treinamento.

A leitura usa vizinhos de um salto com suporte direto. Os coeficientes convexos obtidos pelo NNLS existente são ajustados pela mesma confiabilidade entre regiões e renormalizados. Portanto, após esse ajuste, não são o minimizador exato do NNLS original. O controle de proximidade troca os vizinhos do grafo pelos protótipos mais próximos em objetivos, mantendo o número elegível de vizinhos.

Os protótipos de objetivos são transportados entre normalizações por `W_new=(W_old*s_old+ideal_old-ideal_new)/s_new`. A parte de decisão permanece normalizada pelos limites do problema. O `LDis` histórico da geração é preservado: a nova vizinhança não ativa por acidente o antigo preenchimento de nichos.

## Aprendizagem de movimentos

Um buffer cronológico separado guarda as últimas 300 soluções realmente avaliadas. Ele não substitui nem aumenta o arquivo de seleção. A cada geração, `x1_movement_fit` extrai pares factíveis na mesma região de referência, com vizinhança mútua em decisões e distância RMS normalizada de até 0,25. Orienta cada par pela melhora de PBI, com a mesma normalização e direção de referência para os dois extremos.

Os controles `node`, `global`, `som` e `proximity` usam a mesma extração de pares. O modo SOM compartilha os vetores pelo grafo no ajuste e novamente na leitura. A confiança deriva dos coeficientes dos pares originais; seu suporte efetivo algébrico não equivale a uma contagem de observações independentes. A regra de proximidade reduz saltos entre regiões distantes, mas não prova que ramos distintos foram separados.

Nos índices pares elegíveis do pool, o candidato proposto é `base + vetor_aprendido + 0,25*(DE-base)`, limitado por um raio RMS e pelos limites de decisão. O raio começa em 0,1, fica em [0,005; 0,25] e recebe feedback somente de candidatos realmente alterados e avaliados. Candidatos posteriormente reparados são excluídos desse feedback. O controle `move_shrink` aplica a mesma redução do DE e o limite de raio, sem vetor aprendido. Ausência de suporte preserva exatamente o candidato DE original.

## Gatilhos de ativação

Os dois mecanismos têm portões fixados antes de qualquer resultado AC (`x1_options`). Um mecanismo desligado não é ajustado nem aplicado, e não sorteia números; a execução segue exatamente o perfil sem ele. O estado de cada geração fica em `Algorithm.metric.x1GateLog` (FE, movimento ligado, reparo ligado).

* **Movimento:** só atua quando `Problem.FE >= moveMinFE` (padrão 300). Com o orçamento de 300 avaliações (regime caro: WFG e DTLZ), nunca atua, e `move_*` coincide com `cooperative`. No RWMOP, entra depois das primeiras 300 avaliações, quando o buffer de 300 registros já está cheio.
* **Reparo:** único modo, `repairTrigger = 'infeasible'`: só atua enquanto a fração factível do arquivo for no máximo `repairFeasTarget` (padrão 0), isto é, uma fase de restauração de viabilidade. Nunca atua em um problema sem violação observada.
* **Ordenação (`orderGate`):** a fase de ordenação só é aplicada quando a camada externa do `UniformPoint(N,m)` tem resolução H1 ≥ 2. Com H1 = 1 (N = 50 e m ≥ 15), todas as direções de uma camada são adjacentes entre si, e não há vizinhança local.

Revisão de 2026-11-04 (versão 3 do protocolo): o grafo mútuo (`graphMode = 'mutual'`), os pesos de confiança (`supportWeights`) e o movimento não entram na campanha; a massa cooperativa passou a apenas reduzir. Ver [phase_AC_protocol.md](phase_AC_protocol.md).

## Reparo de restrições

`x1_repair_fit` ajusta uma função afim para cada restrição observada. Usa uma divisão cronológica interna para conferir erro, posto e condicionamento antes do reajuste com todos os dados do pool. Os modos `global`, `proximity` e `som` distinguem o efeito de um modelo global da contribuição da topologia. O modo SOM não atravessa componentes desconectadas para completar um pool.

`x1_repair_apply` resolve uma projeção quadrática com folgas L1, margens de erro, limites de decisão e uma caixa de confiança ao redor do candidato. Não conhece a identidade nem as fórmulas do problema. Um modelo rejeitado ou falha numérica preserva o candidato. Restrições observadas identicamente nulas não recebem margem artificial. Depois da projeção, duplicatas com o arquivo ou com qualquer outro candidato revertem à proposta anterior.

O gate é uma validação interna, parcialmente transdutiva: os pools e associações podem usar X/F já observados. A caixa limita o deslocamento a partir do candidato, não a distância ao suporte de treino. Portanto, o reparo pode extrapolar e a factibilidade só é confirmada após a avaliação verdadeira. Para D alto, orçamento baixo ou restrições não afins, a rejeição do modelo é um comportamento esperado.

## Controles e diagnósticos

Além dos quatro algoritmos, `x1_parameters` oferece: `g15`, `legacy` (X1 histórica), `identity`, `transport`, `direct`, `mass`, `sparse`, `cooperative_no_order`, `cooperative_shuffled`, `cooperative_proximity`, `move_node`, `move_global`, `move_som`, `move_proximity`, `move_shrink`, `repair_global`, `repair_proximity` e `repair_som`.

`Algorithm.metric.x1GraphLog` registra FE, número de nós, grau médio, nós com suporte direto, nós atingidos no treino e confiança média. `x1Diagnostics` registra candidatos gerados/avaliados, movimentos/reparos efetivamente usados, deslocamentos, raio médio, modelos de reparo ativos e motivos de fallback. Custo computacional e frequência de ativação devem acompanhar as métricas de qualidade.

## Validação e execução

`run_x1_unit_tests` executa apenas testes de arrays: massa cooperativa, desconexão, transporte, buffer, perfis, aprendizagem, controles, raio, factibilidade, regressão, rank, holdout, QP e preservação do RNG. Não instancia um problema de benchmark. `run_check_x1_installation` verifica grades, sementes, hashes e orçamento sem avaliações.

`test_x1_integration`, protegido para CASA, verifica contratos de classes, orçamento e paridade entre `legacy` e `identity` em uma fixture sintética. Esse teste precisa passar na instalação de destino antes das campanhas. Os testes locais de componentes não demonstram paridade de trajetórias completas, ganho de desempenho ou superioridade científica.

Carregue primeiro uma instalação completa do PlatEMO e depois este overlay, de modo que `which TPIMMOEA_X -all` e `which PROBLEM -all` mostrem as versões corretas. A distribuição completa e os toolboxes de Statistics e Optimization são necessários. Veja os comandos e a guarda de execução em [phase_AC_protocol.md](phase_AC_protocol.md).
