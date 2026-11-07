# Fase AD: frentes desconexas e irregulares (propostas A e B)

Data: 2026-11-05. Pré-registro feito antes de qualquer execução da fase AD.

## Motivação

O modelo final F (X1 com o portão geométrico da ordenação e o reparo global, perfil `gated_repair_global`) é o 7º de 15 no DTLZ. As maiores perdas estão no DTLZ7, com frente desconexa: F fica em 13º a 14º com m = 6 e 9, e o IGD é de 4 a 14 vezes o do melhor concorrente. Medida geométrica feita antes desta fase, sem otimização: com N = 50, a frente do DTLZ7 alcança só 60%, 52% e 82% das direções de referência para m = 3, 6 e 9 (o WFG3, com frente degenerada, 24%, 31% e 78%; DTLZ2, WFG2 e WFG4, 100%). No DTLZ7 com d = 10, a leitura na célula piora o resultado em relação ao g15 com m = 6 e 9.

**Uso do DTLZ.** As propostas foram motivadas por resultados do DTLZ, que deixa de ser uma suíte de validação independente. Se uma proposta for adotada, o artigo deve validá-la em uma suíte nova, rodada uma única vez com o modelo e os critérios fixados (proposta: MaF), e declarar que o DTLZ passou a ser suíte de desenvolvimento.

## Propostas

- **A, nichos inalcançáveis (`nicheReach`).** Uma direção que recebe 2 candidatos avaliados dirigidos a ela como nicho vazio (pelo preenchimento de nichos ou pela prioridade de nicho vazio da pré-seleção), sem que nenhum caia nela, é tratada como inalcançável por 5 gerações: sai do preenchimento de nichos e perde a prioridade de nicho vazio na pré-seleção. Qualquer solução avaliada que caia nela a reativa na hora. Inspiração: vetores de referência adaptativos para frentes irregulares.
- **B, leitura sensível a lacunas (`gapRead`).** Um vizinho k do nó j do pai só entra na célula se alguma solução não dominada do arquivo estiver no arco entre as direções de j e k (ângulo até a bissetriz no máximo igual à metade do ângulo j-k). Assim, a célula não mistura regiões separadas por uma lacuna da frente.
  - **Ajuste de projeto declarado, feito antes de qualquer execução:** a primeira versão usava um quarto do ângulo. Um teste geométrico com amostras da frente verdadeira (50 a 100 pontos não dominados) mostrou que ela cortava a maioria das arestas também em frentes contínuas (DTLZ2 com m = 3: 26% a 48% das arestas mantidas). Com metade do ângulo, as frentes contínuas mantêm 85% a 93% das arestas com m = 3 e 6 e cerca de 60% com m = 9, contra 30% a 60% no DTLZ7.
- **Controle de B (`final_Brand`).** Em cada geração, corta o mesmo número de arestas que o teste de B cortaria, escolhidas ao acaso, com um gerador privado que não altera o gerador principal.

## Blocos (runs 1 a 30, mesmas sementes do artigo)

| Bloco | Instâncias | Perfis | Execuções |
|---|---|---|---:|
| AD1 | WFG m = 3, 6, 9 (54) | final_A, final_B, final_AB, final_Brand | 6.480 |
| AD2 | WFG m = 15, 20 (36) | os mesmos quatro | 4.320 |
| AD3 | DTLZ1–4, 7, m = 3, 6, 9 (30) | os mesmos quatro | 3.600 |
| AD4 | RWMOP1–35 | final_A, final_B, final_AB | 3.150 |

Referência de todas as comparações: F (X1 da fase X no WFG m ≤ 9, X2 da fase Y no WFG m = 15/20, X1 da fase AB no DTLZ, `gated_repair_global` do bloco AC4 no RWMOP). O smoke test confere que o código novo não altera F.

## Critérios (fixados agora)

1. **Melhora no DTLZ:** signed-rank pareado por instância contra F, com Holm sobre final_A, final_B e final_AB; p de Holm < 0,05, a favor da proposta, e razão de IGD com limite superior do IC 95% abaixo de 1 (bootstrap por agrupamento sobre os problemas, 10.000 reamostragens, semente 1).
2. **Não inferioridade nas demais suítes:** limite superior do IC abaixo de 1,03 no WFG m = 3 a 9, no WFG m = 15/20 e em cada m; no RWMOP, nenhum problema com perda de HV médio acima de 0,01 e signed-rank não significativamente desfavorável (5%).
3. **Escolha:** se final_AB cumprir 1 e 2, ele é adotado; senão, entre final_A e final_B, o que cumprir 1 e 2 com a menor razão no DTLZ; se nenhum cumprir, F permanece.
4. **Atribuição de B à continuidade:** final_B contra final_Brand no DTLZ (signed-rank, 5%). Se o controle empatar, o ganho de B vem de cortar arestas, e não do teste de continuidade, e o texto deve dizer isso.
5. **Relatado à parte:** DTLZ7 sozinho, por m e d, e a posição diante dos 15 algoritmos em todas as suítes.
