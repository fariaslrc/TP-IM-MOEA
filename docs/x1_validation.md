# Verificação da implementação X1 — 2026-11-04

Ambiente local: MATLAB R2026b, Windows. Foi carregada a distribuição completa do PlatEMO seguida do overlay deste repositório. Nenhuma função objetivo de benchmark foi avaliada nesta verificação.

| Verificação | Resultado |
|---|---|
| `test_x1_core` | Passou: grafo, massa extradiagonal, transporte de coordenadas, buffer, perfis e preservação do RNG. |
| `test_x1_movement` | Passou: pares, factibilidade, direção, controles, suporte, raio, fallback e feedback. |
| `test_x1_repair` | Passou: modelos afins, validação cronológica, posto/condicionamento, QP, limites, restrições nulas e preservação do RNG. |
| `run_check_x1_installation(true)` | Passou: distribuição completa, overlay, grades AC_A–AC_E, parâmetros, sementes históricas e identidades SHA-256. |
| `test_ac_resume` | Passou: oito casos sintéticos de integridade, incluindo configuração diferente, registros ausentes/truncados, fonte ausente e objetivos finais inválidos. Nenhum algoritmo executado. |
| Carregamento de metaclasses | Passou para X1C, X1M, X1F, X1CMF e a fixture sintética, sem instanciar os algoritmos. |
| `checkcode` | Sem erros de sintaxe nos arquivos da extensão, executor, testes, exportador e integração. Avisos de estilo/crescimento de arrays não impedem execução. |
| `git diff --check` | Passou. |

O teste inicial de reparo encontrou uma fixture sintética com posto insuficiente nos pools locais. O gate rejeitou corretamente esses modelos; a fixture foi substituída por uma amostra determinística de um fluxo aleatório privado. O teste explícito de posto deficiente foi mantido, e a suíte completa passou após a correção.

Pendência de validação na máquina de destino: executar `test_x1_integration` em CASA antes de qualquer campanha. Ele verifica orçamento, trajetórias `legacy`/`identity`, compatibilidade dos 44 parâmetros antigos e equivalência dos wrappers em uma fixture pequena. Está protegido pela mesma guarda de host do executor e não foi executado no computador principal.

Esses resultados demonstram propriedades dos componentes e consistência estática da instalação. Não demonstram melhora em IGD/HV, viabilidade de RWMOP, superioridade sobre comparadores nem paridade de trajetórias completas. Essas conclusões dependem da integração em CASA e do [protocolo experimental](phase_AC_protocol.md).
