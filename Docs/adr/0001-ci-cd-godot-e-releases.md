# 0001 — Uso de GitHub Releases como produção e estratégia de CI para Godot 4

- Status: aceito
- Data: 25/11/2026

## Contexto
O GeoRush é um jogo 2D educacional desenvolvido em Godot 4 (GDScript). O projeto precisa de um pipeline de CI/CD que funcione na rede do laboratório sem custos de hospedagem externa. Além disso, o GDScript não possui ferramenta nativa de cobertura de código por linha em linha de comando (como V8 ou JaCoCo).

## Decisão
- Adotar **GitHub Releases** como ambiente de produção e baseline oficial (tags `vX.Y.Z` com o pacote `.zip` único promovido do staging após aprovação manual no Environment `production`).
- Executar o CI combinando `gdlint` (`gdtoolkit`), verificação de variáveis locais não usadas e cenas Godot headless (`tests/check_scripts.tscn` e `tests/test_georush.tscn`) com o check agregador `ci-ok`.
- Registrar formalmente o desvio do quality gate de 60% de cobertura por meio de Issue dedicada com prazo de reavaliação, mantendo testes automatizados nas regras de negócio críticas (`EconomyManager`, `CustomerManager` e `BaseProducts`).

## Alternativas consideradas
- **Hospedagem em servidor dedicado ou itch.io automatizado:** descartada por exigir credenciais/contas adicionais e adicionar pontos de falha fora do escopo do laboratório.
- **Migrar testes para C#/.NET apenas para ter cobertura nativa:** descartada pelo alto custo de reescrita e por aumentar a complexidade da equipe.

## Consequências
- **Positivo:** pipeline 100% reproduzível no GitHub, build único imutável entre staging e produção, rollback em minutos sem recompilar.
- **Negativo:** ausência de métrica percentual automática de cobertura de linhas no CI; exige disciplina da equipe para adicionar testes manuais a cada nova regra de negócio.
- **Pendente:** reavaliar plugins comunitários de cobertura (ex.: gdUnit4/GUT) até o prazo definido na Issue de cobertura.