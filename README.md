# IA Editor — Três de Menos (`@TresDeMenos`)

Ambiente local isolado e padronizado para edição de vídeos curtos (YouTube Shorts, Reels e TikTok) do canal **Três de Menos** (Breno, Reuel e Athos), com foco em conteúdo geek, entrevistas de cosplay e dinâmicas em grupo.

Atenção: No primeiro use execute o script adequado para seu sistema, sempre que enviar um video para editar, forneça o maximo de detalhes possiveis e especificos para aumentar a qualidade final e precisão da edição, forneça nomes, referencia e coisas para evitar o achismo da IA. O uso do projeto é simples, depois de roda o script, abra sua IA dentro da pasta do projeto, coloque o video bruto na pasta "Video Bruto", e fale para o agente editar o video que esta na pasta, fornecendo os detalhes especifico que queira.

## Estrutura do Projeto

- `Video Bruto/` — vídeos originais enviados para edição (não versionados no Git).
- `Video Pronto/` — vídeos finais renderizados em `1080x1920` (não versionados no Git).
- `Referencia/` — vídeos de referência baixados para estudo (não versionados no Git).
- `docs/FOLHA_DE_ESTILO.md` — folha de estilo oficial aprovada do canal.
- `docs/ESTUDO_REFERENCIAS_E_CANAL.md` — estudo das referências, métricas do canal e estratégias de retenção.
- `AGENTS.md` e `.agents/skills/editar-short-tresdemenos/` — regras e fluxo persistente para agentes de IA.
- `setup.ps1` / `setup.sh` — instalação automática e isolada (Windows e Linux) com detecção de hardware.
- `activate-env.ps1` / `activate-env.sh` — ativação do ambiente isolado na sessão do terminal.

## Instalação Automática (Windows e Linux)

Os scripts verificam o que já está instalado no sistema (`ffmpeg`, `node >= 22`, `uv`/`python`) para **não reinstalar ferramentas existentes**, detectam automaticamente sua GPU (**NVIDIA CUDA**, **AMD ROCm/AMF**, **Intel Arc XPU/QSV** ou **CPU**) e instalam todas as dependências isoladas dentro de `.venv/`, `node_modules/` e `.cache/`.

### Windows (PowerShell)
```powershell
.\setup.ps1
```
*(Opções: `.\setup.ps1 -DryRun` apenas diagnostica hardware/ambiente; `.\setup.ps1 -Force` força reinstalação.)*

Para ativar o ambiente em uma sessão:
```powershell
. .\activate-env.ps1
```

### Linux (Bash)
```bash
chmod +x setup.sh activate-env.sh
./setup.sh
```
*(Opções: `./setup.sh --dry-run` apenas diagnostica; `./setup.sh --force` força reinstalação.)*

Para ativar o ambiente em uma sessão:
```bash
source ./activate-env.sh
```

## Ferramentas Incluídas

- **Python isolado (`.venv`):** `yt-dlp[default]`, `openai-whisper` e `torch` (CUDA / ROCm / XPU / CPU conforme o hardware detectado) — listados em `requirements.txt` e `pyproject.toml`.
- **Node.js isolado (`node_modules`):** `hyperframes` + Chrome Headless Shell isolado em `.cache/hyperframes/`.
- **FFmpeg / FFprobe:** usa a instalação do sistema se já existir no `PATH` (instala automaticamente apenas se ausente).
