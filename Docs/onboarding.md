# Guia de Onboarding — GeoRush

Este guia explica como configurar o ambiente, rodar o jogo, executar os testes localmente e enviar um Pull Request seguindo as regras de Gestão de Configuração do projeto.

## 1. Pré-requisitos
- **Git** com **Git Bash** (no Windows do laboratório, use sempre o Git Bash em vez do PowerShell).
- **Godot Engine 4** (mesma versão configurada em `GODOT_VERSION` no arquivo `.github/workflows/ci.yml`).
- **Python 3.12+** (para o linter `gdlint`).

## 2. Clonar e preparar o ambiente
No Git Bash:

```bash
git clone [https://github.com/GabBruno/GeoRush.git](https://github.com/GabBruno/GeoRush.git)
cd GeoRush
pip install -r requirements-dev.txt