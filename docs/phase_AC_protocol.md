# Protocolo AC: cooperação, movimento e reparo da X1

Versão de implementação: 2 (ver a seção seguinte); a versão 1 é mantida abaixo como registro. Data: 2026-11-04. Estado: protocolo prospectivo, sem resultados da campanha AC. Esta versão define hipóteses e critérios de avaliação; não demonstra superioridade. Mudanças posteriores ao exame dos resultados devem gerar nova versão e ser identificadas como desenvolvimento.

## Versão 2 (enxuta, 2026-11-04): esta seção prevalece sobre as demais

Fixada antes de qualquer execução AC. Onde as seções seguintes divergirem desta, vale esta.

**Mudanças em relação à versão 1**
1. **Sementes 1 a 30**, as mesmas de todos os resultados do artigo. Assim, g15 (blocos C1, C2, D2, C5) e a X1 do artigo (`legacy`; fases X e AB) são reaproveitados como referência e não são rodados de novo, e a comparação com os 15 algoritmos usa as execuções já existentes. Sem os blocos de piloto, desenvolvimento e confirmação (1:10, 11:30, 31:60) nem a extensão DTLZ m = 15/20.
2. **Movimento só com `Problem.FE >= 300`** (`moveMinFE`). Nas suítes de 300 avaliações ele nunca atua, então H-B é testada apenas no RWMOP.
3. **Reparo só com `repairTrigger = 'infeasible'`:** atua apenas enquanto o arquivo não tiver nenhuma solução factível (fase de restauração de viabilidade). Os outros modos do código não são usados nesta fase.
4. **Registros do RWMOP reduzidos:** objetivos em precisão simples e, no lugar das restrições, a violação total de cada avaliação (factível se e só se for no máximo 0).

**Blocos (todos com runs 1:30)**

| Bloco | Instâncias | Perfis | Execuções |
|---|---|---|---:|
| AC1 | WFG m = 3, 6, 9 (54) | cooperative, cooperative_no_order, cooperative_shuffled, cooperative_proximity | 6.480 |
| AC2 | WFG m = 15, 20 (36) | os mesmos quatro | 4.320 |
| AC3 | DTLZ1–4, 7, m = 3, 6, 9 (30) | os mesmos quatro | 3.600 |
| AC4 | RWMOP1–35 (orçamentos de Kumar) | cooperative, repair_som, repair_global, move_som, move_global, move_shrink, combined | 7.350 |

**Hipóteses e critérios (fixados agora)**
- **H-A, cooperação (AC1 a AC3):** `cooperative` contra a X1 do artigo e contra g15. Critério principal: recuperar m = 15/20 (razão de IGD contra a X1 com limite superior do IC 95% abaixo de 1 e signed-rank significativo após Holm) sem perder m = 3, 6 e 9 (limite superior abaixo de 1,03 em cada m). Atribuição à topologia: `cooperative` melhor que `cooperative_shuffled` e `cooperative_proximity` (Holm); o papel da ordenação vem de `cooperative_no_order`.
- **H-C, reparo (AC4):** nos problemas em que `cooperative` termina sem solução factível em mais da metade das execuções, aumento de pelo menos 10 pontos percentuais na taxa de execuções com solução factível final; nos demais, HV não pior (margem absoluta de 0,01). Atribuição ao SOM: `repair_som` contra `repair_global`.
- **H-B, movimento (AC4):** `move_som` contra `cooperative` e `move_shrink` (passo menor sem direção aprendida); atribuição ao SOM contra `move_global`.
- **Combinação:** `combined` contra `cooperative`, `repair_som` e `move_som`, apenas descritiva.
- **Não interferência:** nas suítes de 300 avaliações, `move_som`, `repair_som` e `combined` devem coincidir exatamente com `cooperative` (verificado no smoke test).

Testes: signed-rank pareado por instância com Holm dentro de cada família, razão de médias geométricas com bootstrap por agrupamento sobre os problemas (10.000 reamostragens, semente 1), como nas fases anteriores. O HV do RWMOP usa a normalização fixa de `rwmop_norm.csv`, calculada como em `rescore_rwmop_y.m`, para ser comparável aos números do artigo.

## Objetivo e alegações permitidas

Testar se a estrutura do SOM produz benefício mensurável no aprendizado e na reprodução, mantendo o SOM central conforme a orientação de Aluizio. A arquitetura pode mudar. O objetivo competitivo é melhorar os resultados nos estratos WFG com m = 3, 6, 9, 15 e 20, DTLZ e RWMOP, sem substituir evidência por uma promessa de liderança universal.

O ranking será sempre condicionado ao conjunto de problemas, dimensionalidades, orçamento, comparadores e métrica. Vencer uma média global não demonstra liderança em todos os nichos. Os dados DTLZ já examinados no desenvolvimento anterior não constituem uma família inédita de validação. Sementes novas reduzem a reutilização das mesmas realizações, mas não eliminam adaptação ao benchmark.

## Implementações e hipóteses

Todos os perfis usam `TPIMMOEA_X`, com os parâmetros declarados por `x1_parameters(profile,outN)`. O argumento 45 habilita as extensões. Os argumentos históricos permanecem explicitamente registrados. O argumento 29 (`instr`) deve ser zero: diagnósticos que chamam funções verdadeiras fora de `Problem.Evaluation` invalidariam o orçamento.

| Perfil | Alteração e papel experimental |
|---|---|
| `g15` | TP-IM-MOEA histórico, sem as extensões X1; controle de referência. |
| `legacy` | X1 anterior, com vizinhança e aprendizado por vizinhança; argumento 45 vazio. |
| `transport` | Apenas transporte dos protótipos quando muda a normalização dos objetivos. |
| `direct` | Apenas exigência de observações diretas para a elegibilidade de leitura. |
| `mass` | Apenas massa total extradiagonal fixa em 1; peso do BMU igual a 1. |
| `sparse` | Apenas grafo de vizinhos mútuos, k = 4. |
| `cooperative` | Combina transporte, suporte direto, massa controlada, grafo esparso e confiança na leitura. |
| `cooperative_no_order` | Mantém a elegibilidade por suporte direto; remove somente a ordenação da vizinhança no treino. |
| `cooperative_shuffled` | Permuta a adjacência antes dos pesos de confiança atuais; preserva a sequência de graus, não todos os pesos finais. |
| `cooperative_proximity` | Leitura por proximidade no codebook com cardinalidade comparável; controle da necessidade do grafo. |
| `move_node` | Movimento aprendido usando apenas o nó. |
| `move_global` | Movimento aprendido global, sem a localidade do SOM. |
| `move_som` | Movimento aprendido com suporte no SOM. |
| `move_proximity` | Movimento com agrupamento por proximidade em decisões. |
| `move_shrink` | Controle do efeito de encurtar o passo, sem atribuir ganho à direção aprendida. |
| `repair_global` | Reparo com modelos globais das restrições individuais. |
| `repair_proximity` | Reparo com suporte por proximidade em decisões. |
| `repair_som` | Reparo com suporte fornecido pelo SOM. |
| `combined` | Cooperação, movimento SOM e reparo SOM, para estudar compatibilidade dos mecanismos. |

Os cinco controles de movimento e os três controles de reparo partem de `cooperative`. O controle combinado não é selecionado automaticamente. Os wrappers `TPIMMOEA_X1C`, `TPIMMOEA_X1M`, `TPIMMOEA_X1F` e `TPIMMOEA_X1CMF` permitem uso direto dos mecanismos, mas o executor AC usa o mesmo nome de classe e registra o perfil para evitar diferenças acidentais de configuração.

H-A: transportar coordenadas, distinguir suporte direto, controlar massa e restringir o grafo melhora a cooperação sem difundir informação indistintamente. A superioridade de `cooperative` sobre `legacy` não basta para atribuir o ganho à topologia: são necessários os controles de permutação, proximidade e ordenação. As quatro variantes isoladas diagnosticam o mecanismo; não constituem um fatorial completo e não identificam todas as interações.

H-B: pares históricos locais de soluções factíveis fornecem uma direção útil de movimento. O mecanismo usa um buffer cronológico de até 300 avaliações, pares factíveis, vizinhança mútua e distância RMS normalizada de até 0,25. O tamanho efetivo do suporte é uma medida de concentração dos pesos, não de observações estatisticamente independentes. Não chamar essa direção de gradiente causal. Os controles distinguem informação direcional, localidade do SOM e simples redução do passo.

H-C: modelos locais das restrições individuais aumentam a probabilidade de obter e manter viabilidade. O reparo é uma projeção aproximada baseada em dados, não uma garantia de viabilidade verdadeira. O candidato reparado continua exigindo avaliação verdadeira dentro do orçamento. Suporte insuficiente aciona o comportamento de fallback documentado na implementação.

Portões de ativação (fixados antes dos resultados): o movimento só atua com `Problem.FE >= 300`, logo não atua nas suítes de 300 avaliações e só pode ser avaliado no RWMOP; o reparo, por padrão, só atua enquanto o arquivo não tiver membro factível (restauração de viabilidade), com modo periódico disponível como variante declarada. H-B passa a ser testada apenas no RWMOP, e a não interferência nas suítes caras deve ser verificada por igualdade exata com `cooperative`.

Na integração atual, candidatos de índices pares recebem tentativa de movimento; o reparo atua no conjunto de candidatos antes do prescreening. Duplicatas em relação ao arquivo e aos demais candidatos retornam ao candidato original. A adaptação de confiança usa apenas movimentos efetivamente escolhidos e avaliados; candidatos que também foram reparados são excluídos do feedback de raio do movimento. O gate cronológico do reparo é um diagnóstico interno: o suporte é selecionado com acesso ao conjunto disponível de X/F, tornando a avaliação transdutiva, e não uma validação externa independente. A caixa de confiança fica ao redor do candidato, não da região coberta pelo suporte; o ajuste pode extrapolar. Essas limitações devem aparecer na interpretação dos resultados.

## Matriz de problemas e orçamento

| Suíte | Instâncias | Configuração |
|---|---:|---|
| WFG principal | 54 | WFG1–9 × m = {3,6,9} × d = {10,100}; N = 50; 300 FEs. |
| WFG muitos objetivos | 36 | WFG1–9 × m = {15,20} × d = {m−1+10,100}; N = 50; 300 FEs. |
| DTLZ | 30 | DTLZ1,2,3,4,7 × m = {3,6,9} × d = {10,100}; N = 50; 300 FEs. |
| DTLZ expansão (`AC_E`) | 28 | DTLZ1–7 × m = {15,20} × d = {m−1+10,100}; N = 50; 300 FEs. |
| RWMOP | 35 | RWMOP1–35; dimensões, N e orçamento do protocolo Kumar já codificado em `q_build_tasks('Q3')`. |

RWMOP mantém o número de objetivos próprio de cada problema: não é artificialmente convertido em m = 3,6,9,15,20. Seus N são 80, 105 ou 212; os orçamentos são 20.000, 26.250, 53.000 ou 80.000 FEs conforme o problema. A extensão `AC_E` inclui DTLZ com m = 15 e 20 sem alterar a matriz histórica; DTLZ5/6 acrescentam estruturas degeneradas. Congelar parâmetros e finalistas antes de abrir a extensão, verificar as fronteiras de referência e manter o resultado dessa expansão separado da reprodução histórica. Nem todas as combinações DTLZ1–7 × m estão presentes na matriz histórica: DTLZ5/6 com m = 3,6,9 continuam fora desta versão.

Toda avaliação verdadeira deve atravessar o contador da instância de `PROBLEM`. O resultado válido exige `Problem.FE == maxFE`, `size(recObjs,1) == maxFE` e `size(recCons,1) == maxFE`. Uma parada antecipada ou exceção é uma falha, nunca uma execução completa pontuada com menos FEs. O desenho inicial conta no orçamento. Usar o mesmo orçamento também para controles, incluindo todas as avaliações eventualmente executadas por métodos auxiliares.

## Blocos e separação temporal

| Bloco | Instâncias | Perfis padrão | Runs padrão | Total padrão |
|---|---:|---:|---|---:|
| `AC_A` | 90 WFG | 10: g15, legacy, quatro alterações isoladas e quatro perfis cooperative | 1:10 | 9.000 |
| `AC_B` | 35 RWMOP | 6: g15, legacy, cooperative e três reparos | 1:10 | 2.100 |
| `AC_C` | 120 WFG + DTLZ | 8: g15, legacy, cooperative e cinco movimentos | 1:10 | 9.600 |
| `AC_D` | 155, todas as suítes | 3: g15, legacy, cooperative | 31:60 | 13.950 |
| `AC_E` | 28 DTLZ da expansão | 3: g15, legacy, cooperative | 31:60 | 2.520 |

1. Verificação estrutural no computador principal: somente análise estática, testes numéricos de helpers e construção de manifests. Nenhuma otimização.
2. Piloto em CASA: runs 1:10 dos blocos necessários. Validar custo, ausência de falhas, orçamento, paridade histórica e utilidade dos sinais. Os mesmos IDs de run já usados historicamente não constituem dados independentes desses resultados anteriores.
3. Desenvolvimento em CASA: runs 11:30, passados explicitamente ao executor. Ajustes são permitidos aqui, mas todos os candidatos e decisões devem ficar registrados. Não apresentar esse conjunto como confirmação independente após selecionar parâmetros nele.
4. Congelar implementação, parâmetros, candidatos finalistas, comparadores, critérios e análise antes de abrir `AC_D`. O hash de fontes e o manifesto documentam esse congelamento. O executor não escolhe vencedores.
5. Confirmação em CASA: runs 31:60. O padrão compara cooperative com g15 e legacy; incluir `move_som`, `repair_som` e/ou `combined` somente por lista explícita previamente congelada. `AC_E` avalia separadamente a expansão DTLZ m = 15/20 com candidatos congelados. Rodar todos os candidatos retrospectivamente e relatar apenas o melhor invalida a interpretação confirmatória.

Não é necessário lançar todos os blocos simultaneamente. A quantidade de perfis e runs pode ser explicitamente reduzida no piloto para estimar custo. Não reduzir orçamento e depois tratar o piloto reduzido como uma repetição do protocolo final.

## Sementes e comparabilidade

O arquivo-base mantém a identidade histórica g15, por exemplo `TPIMMOEA_X_g15_WFG1_M3_D10_1.mat`, e o perfil é separado pelo diretório. A semente é exatamente `mod(sum(double(name).*(1:numel(name))) + 7919*run, 2^31-1)`. O identificador final é alterado de `_1` para o run solicitado, incluindo 31:60.

Assim, todas as variantes X1 do mesmo problema/run começam com a mesma semente. Isso não significa que toda a trajetória compartilha números aleatórios: diferentes mecanismos consomem o gerador de formas diferentes. A hipótese de pareamento se refere ao desenho randomizado por run, não à identidade das populações de todas as gerações. Verificar a paridade histórica de g15/legacy e a extensão `identity` em um smoke test em CASA antes da campanha; igualdade de parâmetros e hashes sozinha não demonstra paridade numérica.

## Métricas e conjunto pontuado

WFG/DTLZ: primária `IGDall`, calculada sobre as soluções factíveis não dominadas de **todas** as avaliações registradas, com a mesma fronteira `Problem.optimum`. `IGDplusAll` é secundária para reduzir ambiguidades relacionadas à dominância. O arquivo também conserva `IGDreported`. A população reportada tem 2N soluções nesse protocolo. Curvas devem comparar pontos de FE comuns, nunca gerações de tamanhos diferentes.

RWMOP: primária de qualidade `HVfixed`, na população final de **N** soluções, usando somente membros factíveis não dominados e ideal/nadir congelados de `results/rwmop_norm.csv`. Normalizar por `(f−ideal)/(nadir−ideal)` e usar referência física fixa 1,1 em cada eixo; reportar volume dividido por `1,1^m`. O exportador compensa a renormalização interna de `HV.m` quando uma solução fica abaixo do ideal congelado. Isso coincide com o procedimento histórico quando não há extrapolação do ideal; divergências nessa condição devem ser explicitadas, não ocultadas. Para m ≥ 4, o HV da instalação usa Monte Carlo com semente auxiliar fixa 1, sem alterar o estado RNG da otimização. Reportar a natureza aproximada da medida.

Se a referência fixa não existir, `HVfixed = NaN` e `HVdefined = false`, inclusive em RWMOP28. Ausência de referência não equivale a HV zero. Havendo referência válida, ausência de solução factível na população final corresponde a HV zero. `HVreported` é uma medida descritiva da normalização padrão PlatEMO e não substitui `HVfixed`.

Reportar também: proporção de runs que obtêm alguma solução factível (`everFeasible`); proporção com solução factível final (`finalFeasible`); quantidade final de factíveis; primeira FE factível; menor violação agregada final; menor violação avaliada. Primeira FE factível ausente é censurada pelo orçamento, não convertida em zero. A soma das violações tem unidades dependentes do problema e só deve ser comparada dentro dele; não produzir uma média bruta de CV entre problemas.

Separar ganho de viabilidade e ganho de qualidade condicional à viabilidade. Uma média de HV sobre apenas runs bem-sucedidos esconde falhas; por isso a primária inclui zeros de inviabilidade quando o HV é definido. Análises condicionais são secundárias e explicitamente rotuladas. Exportar linhas de runs ausentes ou inválidos, sem removê-las silenciosamente; nenhuma tabela confirmatória é considerada completa antes da auditoria.

## Comparadores externos e limites da entrega

O executor AC implementa as variantes TPIMMOEA_X e os controles g15/legacy. Os algoritmos externos existentes no repositório continuam disponíveis nos builders C/D/P, mas **não são automaticamente recriados em 31:60 pelo AC**. Antes de afirmar liderança perante a literatura, congelar a lista de comparadores aplicáveis e gerar suas 30 novas runs com o mesmo orçamento, inicialização declarada, fronteira, protocolo de arquivo/população e política de falha. A comparação com dados antigos 1:30 é evidência descritiva, não o novo teste confirmatório independente.

Incluir os concorrentes fortes já usados no manuscrito por suíte; excluir um comparador apenas por uma razão de aplicabilidade definida antes dos resultados. Documentar especialmente K-RVEA: com tendência linear, a base inicial precisa suportar d+1 termos. Seu estrato d = 10 deve ser mostrado separadamente; não preencher resultados inexistentes em d = 100 com zeros ou piores valores artificiais. N = 50 e orçamento 300 não autorizam ignorar uma exigência de inicialização. Uma adaptação de K-RVEA para outro estrato é outro protocolo e deve ser identificada.

## Critérios de decisão a congelar antes da execução confirmatória

Os limiares abaixo são escolhas de desenho propostas nesta versão, não propriedades teóricas do método. Qualquer ajuste deve preceder a abertura dos dados de confirmação.

* Integridade obrigatória: zero resultados inválidos; orçamento exato; nenhuma chamada verdadeira fora do contador; dimensões e tamanho da população esperados; identidade de configuração e fontes verificada. Falhas são reportadas e investigadas antes de conclusões competitivas.
* Cooperação: em WFG, exigir benefício contra legacy e evidência contra ao menos os controles embaralhado e proximidade. Uma melhora de pelo menos 2% na média geométrica da razão IGDall candidato/controle, com limite superior de IC 95% abaixo de 1 e teste ajustado significativo, é o limiar proposto de superioridade prática. Distinguir os estratos m; não usar uma melhora em m = 3 para esconder perda em m = 20.
* Movimento: exigir benefício contra cooperative e contra move_shrink. Comparar move_som com move_global, move_node e move_proximity para justificar a necessidade do suporte SOM. Se apenas a redução do passo explicar o ganho, essa é a conclusão.
* Reparo: em problemas com falhas de viabilidade no controle, alvo proposto de aumento absoluto de pelo menos 10 pontos percentuais no sucesso final, com IC da diferença acima de zero, ou menor tempo até viabilidade com censura corretamente tratada. Nos problemas já consistentemente factíveis, exigir preservação do HV e investigar qualidade; não reivindicar ganho de viabilidade por um teto de 100%. Com 30 runs, o IC pode impedir afirmar esse alvo: relatar a incerteza, sem relaxar o critério após observar os dados.
* Proteção contra regressão: limite superior do IC da razão IGDall candidato/controle menor que 1,03 em cada estrato declarado. Para HV, especificar antes do teste uma margem absoluta de 0,01 na escala de volume normalizado, além de ausência de deterioração da taxa de viabilidade. Zero HV impede usar log-razões de HV; não adicionar constantes escolhidas após os resultados.
* Combinação: comparar combined com cooperative, move_som e repair_som. Ganho combinado não demonstra aditividade. Usar os perfis separados para detectar antagonismo ou redundância.

Esses critérios são rigorosos e podem permanecer inconclusivos com 30 runs. A decisão científica correta nesse caso é ampliar evidência por um protocolo novo ou reportar inconclusão, não declarar o modelo “número 1” com base na melhor seed.

## Análise estatística e multiplicidade

Unidade de replicação: run dentro de uma instância. Unidade de generalização entre problemas: função de benchmark, preservando o agrupamento de suas configurações de m/d. Não tratar 30 runs × 90 instâncias como milhares de funções independentes. Relatar medianas, intervalos interquartis, diferenças/razões de interesse e ICs, além de p-valores.

Para variantes AC com seeds pareadas, o teste confirmatório será a permutação pareada de sinais, bilateral, com 20.000 permutações e semente de análise 20261104. Estatística: média das diferenças por instância, com estimativa p = (1 + número de estatísticas permutadas pelo menos tão extremas)/(20.001), incluindo empates. Reportar também a fração de diferenças positivas/negativas/nulas. Para comparadores com seeds historicamente diferentes, não impor pareamento retrospectivo: usar rank-sum bilateral e tamanho de efeito A12 com empates. Não alternar testes conforme qual produz significância.

Congelar famílias de hipóteses antes de abrir AC_D: H-A (cooperação e seus controles), H-B (movimento e seus controles), H-C (viabilidade/HV dos reparos) e H-D (candidato final versus comparadores externos por suíte/estrato). Aplicar Holm a todos os contrastes confirmatórios declarados dentro de cada família; incluir no conjunto de ajustes todos os candidatos finalistas e estratos examinados. O uso de famílias distintas deve corresponder a alegações distintas, não dividir artificialmente uma mesma alegação de liderança para reduzir correção.

Ranks de Friedman e comparações pós-teste podem resumir os algoritmos com dados completos nas mesmas instâncias, mas não substituem efeito e IC. Para médias de razões de IGD, trabalhar no log. Se houver IGD exatamente zero em qualquer membro de uma comparação no estrato, não calcular a log-razão daquele estrato: reportar zeros e diferenças pareadas, sem afirmar que o critério relativo de 2%/3% foi demonstrado. Não adicionar epsilon. Bootstrap deve respeitar blocos de runs e famílias de problemas. WFG possui apenas nove funções e DTLZ histórico cinco: ICs que pretendam generalizar a novas funções terão limitação substancial, mesmo com muitas seeds. Para primeira viabilidade, usar análise de sobrevivência com censura à direita no maxFE e mostrar taxas de sucesso junto da curva.

## Custo computacional e diagnóstico

Registrar `tSolve` separadamente do tempo total. Rodadas paralelas servem à coleta de qualidade; comparações rigorosas de tempo devem usar a mesma máquina, versão MATLAB, número de threads, modo de execução e carga, preferencialmente uma tarefa por vez. Modelos locais podem custar mais CPU mesmo quando economizam FEs. Reportar ambos.

As estatísticas de mecanismo (suporte efetivo, distribuição de raio, frequência de fallback, reparos propostos/aceitos, movimentos escolhidos) devem ser derivadas dos dados já disponíveis. Nenhum diagnóstico pode avaliar o problema para verificar um candidato rejeitado pelo prescreening. O buffer de aprendizagem de 300 registros mantém custo limitado nos RWMOP longos, mas introduz esquecimento: avaliar esse compromisso como sensibilidade prospectiva, sem usar a identidade do problema para escolher o buffer.

## Execução e auditoria

Instalar o overlay deste repositório sobre uma distribuição completa e compatível do PlatEMO. Carregar primeiro a distribuição completa, depois o overlay, para que `PROBLEM.m` e `TPIMMOEA_X.m` modificados tenham precedência. Confirmar com `which ... -all`; o executor registra os caminhos resolvidos e rejeita uma cópia de TPIMMOEA_X diferente da que acompanha o runner.

```matlab
% Seguro no computador principal: nenhuma avaliação e nenhuma pool.
addpath(genpath(fullfile(pwd,'PlatEMO'))); % executar na raiz TP-IM-MOEA
report = run_check_x1_installation(false);
plan = run_ac('AC_A');                   % dryRun=true por padrão
plan = run_ac('AC_D',true,{'g15','legacy','cooperative'},31:60,1);
extension = run_ac('AC_E');              % DTLZ m=15/20; somente plano
```

Somente na máquina CASA, informar explicitamente seu hostname real. Não copiar esta configuração de ambiente para o computador principal.

```matlab
setenv('TPIMMOEA_EXECUTION_HOST','CASA');
setenv('TPIMMOEA_CASA_HOSTNAME','NOME_REAL_DA_MAQUINA_CASA');
run_check_x1_installation(true);
test_x1_integration;                   % smoke/paridade: somente em CASA
run_ac('AC_A',false,[],1:10,4);          % somente este bloco
% Desenvolvimento, quando explicitamente decidido:
% run_ac('AC_A',false,{'g15','legacy','cooperative'},11:30,4);
% Confirmação, somente após congelar os finalistas:
% run_ac('AC_D',false,{'g15','legacy','cooperative'},31:60,4);
audit = verify_ac_results('AC_A',[],1:10);
addpath(fullfile(pwd,'analysis'));        % raiz do repositório
T = export_ac('AC_A',[],1:10);
```

Resultados ficam em `PlatEMO/Data_AC/<bloco>/<perfil>/`. Antes da execução, o manifesto JSON registra cada tarefa, parâmetros, seed, orçamento, protocolo, SHA-256 da identidade e hashes dos arquivos **resolvidos no path**. Inclui classes de problemas, algoritmo, helpers X1, builders, núcleo PlatEMO e utilitários relevantes. Também registra versão MATLAB e toolboxes. Workers verificam suas fontes contra o manifesto.

Retomada só aceita arquivo `COMPLETE` com identidade e fontes idênticas, orçamento exato e tamanhos válidos. O digest inclui versão MATLAB, plataforma e versões dos toolboxes, além dos arquivos. Arquivo incompatível é rejeitado; não é sobrescrito nem usado como run concluída. Para uma nova versão, criar uma cópia versionada do overlay/diretório de campanha e conservar a anterior. A primeira falha gera entrada no log e interrompe a campanha, cancelando futures ainda pendentes; não produz resultado completo. A gravação usa arquivo temporário no mesmo diretório e movimentação final. Os registros são preservados em double e os diagnósticos X1 e o manifesto de fontes acompanham cada resultado. Não iniciar dois controladores para o mesmo conjunto de tarefas.

O exportador conserva linhas `MISSING`/`INVALID` e os hashes das fontes e da normalização. `verify_ac_results` confere os registros de FE e recalcula os indicadores de viabilidade. A entrega desta implementação não inclui lançamento de campanhas nem afirma que os critérios já foram atingidos.
