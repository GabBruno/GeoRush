# 0002 — Limite de vulnerabilidades no CI e aceitação de risco temporária

- Status: aceito
- Data: 25/11/2026

## Contexto
O job `dependencias` do CI usa `dependency-review-action` bloqueando vulnerabilidades de severidade `critical`. O GeoRush não embarca bibliotecas de terceiros no executável/pacote final do jogo: as dependências monitoradas (`pip` em `requirements-dev.txt` e `github-actions` nos workflows) rodam exclusivamente no ambiente de integração contínua.

## Decisão
- Manter o gate bloqueante do CI em `fail-on-severity: critical`.
- Aceitar temporariamente eventuais alertas de severidade `high`, `moderate` ou `low` restritos a ferramentas de desenvolvimento/CI (como `gdtoolkit` e actions), desde que monitorados pelo Dependabot e tratados via PRs semanais (`chore(deps)`).
- Definir **25/12/2026** como prazo de revisão desta decisão (ou antes, caso o projeto passe a incluir dependências em tempo de execução ou comunicação em rede).

## Alternativas consideradas
- **Subir o bloqueio do CI para `high`:** descartada neste momento para evitar travamento de entregas por vulnerabilidades transitivas em ferramentas exclusivamente de lint/CI que não atingem o jogador final.
- **Desativar a checagem de dependências:** descartada por violar a política de Gestão de Configuração (PGC 5.3 e 13).

## Consequências
- **Positivo:** equilíbrio entre segurança real e velocidade de desenvolvimento, com risco explicitamente documentado e prazo de revisão.
- **Negativo:** exige conferência periódica na aba **Security → Dependabot alerts** para garantir que nenhum alerta `high` relevante seja negligenciado.