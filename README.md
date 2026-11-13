# IA Editor — Três de Menos (`@TresDeMenos`)

Ambiente local isolado e automatizado para edição de vídeos curtos (**YouTube Shorts, Instagram Reels e TikTok**) do canal **Três de Menos** (Breno, Reuel e Athos), voltado para conteúdo geek, entrevistas de cosplay e dinâmicas em grupo.

> **Resumo rápido de uso:**  
> 1. Rode o script de instalação (`setup.ps1` no Windows ou `setup.sh` no Linux) **uma única vez**.  
> 2. Coloque o arquivo bruto em `Video Bruto/`.  
> 3. Abra seu agente de IA favorito **dentro da pasta raiz deste projeto** e peça para editar o vídeo, passando o máximo de contexto possível.

---

## Pré-requisitos

- **Node.js `>= 22`** instalado no sistema (necessário para o `hyperframes`).
- **Windows:** PowerShell + `winget` (opcional, caso ainda não tenha `ffmpeg`/`uv` instalados).
- **Linux:** `bash`, `curl` e gerenciador de pacotes (`apt`, `dnf` ou `pacman`).
- **Espaço em disco:** ~4–6 GB livres para `.venv` (PyTorch + Whisper), modelo `medium` do Whisper e Chrome Headless Shell isolados dentro da pasta do projeto.

> *Não precisa instalar Python, Whisper, PyTorch ou pacotes npm globalmente! Os scripts de setup criam tudo isolado dentro do próprio projeto (`.venv/`, `node_modules/` e `.cache/`).*

---

## Passo 1 — Instalação (Fazer na 1ª vez)

Baixe o projeto (`git clone` ou *Download ZIP* no GitHub e extraia a pasta). Depois, abra o terminal **na pasta raiz do projeto** e rode o comando do seu sistema:

### Windows (PowerShell)
```powershell
.\setup.ps1
```
*(Se o PowerShell bloquear a execução de scripts por política local, rode antes: `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`)*

Opções úteis:
- `.\setup.ps1 -DryRun` — apenas diagnostica hardware e ferramentas sem instalar nada.
- `.\setup.ps1 -Force` — força reinstalação completa do ambiente.

### Linux (Bash)
Se você baixou pelo **`.zip` do GitHub**, os arquivos vêm sem permissão de execução, então dê permissão primeiro (ou rode direto com `bash setup.sh`):
```bash
chmod +x setup.sh activate-env.sh
./setup.sh
```
Opções úteis:
- `./setup.sh --dry-run` — apenas diagnostica hardware e ferramentas sem instalar nada.
- `./setup.sh --force` — força reinstalação completa do ambiente.

### O que o script de instalação faz automaticamente?
1. Detecta sua CPU e GPU (**NVIDIA CUDA**, **AMD ROCm/AMF**, **Intel Arc XPU/QSV** ou **CPU only**) e escolhe a versão certa do PyTorch e o melhor encoder do FFmpeg (`h264_nvenc`, `h264_vaapi`, `h264_qsv` ou `libx264`).
2. Verifica o que já existe na sua máquina (`ffmpeg`, `node >= 22`, `uv`/`python`) para **não reinstalar** ferramentas já presentes.
3. Cria o ambiente Python isolado em `.venv/` (`yt-dlp`, `openai-whisper`, `torch`, `pillow`, `numpy`).
4. Instala `hyperframes` localmente em `node_modules/` e baixa o Chrome Headless Shell isolado em `.cache/hyperframes/`.
5. Baixa (ou reaproveita do cache global) o modelo `medium` do Whisper em `.cache/whisper/` e garante as fontes locais (`Rubik Bold` / `Rubik Bold Italic`) em `assets/fonts/`.
6. Salva o perfil da sua máquina em `.cache/hardware.env` para que qualquer agente de IA saiba exatamente qual dispositivo usar (`TRESDEMENOS_WHISPER_DEVICE` e `TRESDEMENOS_FFMPEG_ENCODER`).

---

## Passo 2 — Como Usar com seu Agente de IA

Com o setup concluído, o fluxo para editar qualquer vídeo é sempre o mesmo:

1. **Coloque o vídeo original** na pasta `Video Bruto/` (os originais nunca são apagados ou sobrescritos).
2. **Abra seu agente de IA favorito** (Antigravity, Claude Code, Codex, Cursor, etc.) **com o workspace apontando para a pasta raiz do projeto** (`IA Editor`).
   - *Por que abrir na pasta raiz?* Assim o agente lê automaticamente as regras em `AGENTS.md`, a identidade visual em `docs/FOLHA_DE_ESTILO.md` e o pipeline técnico em `.agents/skills/editar-short-tresdemenos/SKILL.md`.
3. **Peça para o agente editar o vídeo**, fornecendo **o máximo de detalhes específicos** para evitar achismos da IA:
   - Nome do arquivo em `Video Bruto/`;
   - Nomes de quem aparece (ex.: Breno, Reuel, Athos ou nome/@ do cosplayer);
   - Personagem e jogo/anime (em entrevistas de cosplay);
   - Estilo ou momentos que você quer priorizar (ou se quer dividir um vídeo longo em Parte 1 / Parte 2).

### Exemplos de prompt para pedir a edição
- **Entrevista de cosplay:**
  > *"Edite o vídeo `Video Bruto/entrevista_evento.mp4`. O cosplayer é o `@fulano` fazendo o Dante de Devil May Cry 3. Quero foco nas partes mais engraçadas, ~55 segundos."*
- **Dinâmica em grupo:**
  > *"Edite `Video Bruto/jogo_palavras.mp4`. Somos nós três: Breno (esquerda), Reuel (centro) e Athos (direita). Deixe super dinâmico com o placar das rodadas e feche no acerto final."*
- **Vídeo longo horizontal (16:9):**
  > *"Edite `Video Bruto/live_cortes.mp4` (horizontal). Recorte para 9:16 mantendo o rosto centralizado, pegue o trecho em que falamos sobre GTA 6 e faça um Short de até 45s."*

4. **Pegue o resultado:** O vídeo final em `1080x1920` (`.mp4`, áudio normalizado entre `-13` e `-14 LUFS`, legendado na Safe Zone) será salvo em `Video Pronto/`, acompanhado de sugestões de título, descrição, hashtags e horários para **YouTube Shorts**, **Instagram Reels** e **TikTok**.

---

## Ativação Manual no Terminal (Opcional)

Se você quiser rodar comandos manualmente no terminal (como `ffmpeg`, `whisper`, `yt-dlp` ou `hyperframes`) usando o ambiente isolado:

- **Windows (PowerShell):**
  ```powershell
  . .\activate-env.ps1
  ```
- **Linux / macOS (Bash):**
  ```bash
  source ./activate-env.sh
  ```

---

## Estrutura de Pastas do Projeto

- `Video Bruto/` — coloque aqui seus vídeos originais para edição *(não versionado no Git)*.
- `Video Pronto/` — onde o agente salva os Shorts finalizados em `1080x1920` *(não versionado no Git)*.
- `Referencia/` — vídeos de referência baixados para estudo de ritmo/estilo *(não versionado no Git)*.
- `assets/fonts/` — fontes portáveis (`Rubik-Bold.ttf`, `Rubik-BoldItalic.ttf`) usadas nas legendas e overlays.
- `docs/FOLHA_DE_ESTILO.md` — regras visuais, cores, legendas, Safe Zone, cortes, música e loudness do canal.
- `docs/ESTUDO_REFERENCIAS_E_CANAL.md` — estudo de métricas e comparativo com referências.
- `AGENTS.md` — instruções gerais para qualquer agente de IA que abrir o repositório.
- `.agents/skills/editar-short-tresdemenos/SKILL.md` — passo a passo técnico de edição (anti-desync VFR, mixagem, render e validação).
- `setup.ps1` / `setup.sh` — scripts de instalação isolada (Windows e Linux).
- `activate-env.ps1` / `activate-env.sh` — scripts de ativação do ambiente isolado.
