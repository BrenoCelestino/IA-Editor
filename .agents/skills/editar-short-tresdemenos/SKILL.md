---
name: editar-short-tresdemenos
description: >-
  Fluxo completo de edição de Shorts para o canal Três de Menos usando o
  ambiente local isolado (whisper CUDA, ffmpeg, hyperframes e yt-dlp),
  seguindo obrigatoriamente docs/FOLHA_DE_ESTILO.md.
---

# Skill: Editar Short — Três de Menos (`@TresDeMenos`)

Use esta skill sempre que o usuário pedir para editar um vídeo da pasta `Video Bruto/` ou criar um novo Short para o canal Três de Menos.

## Pré-requisitos Obrigatórios
1. Ler `docs/FOLHA_DE_ESTILO.md` e confirmar que as regras seguidas estão aprovadas pelo usuário.
2. Nunca modificar os arquivos originais em `Video Bruto/`. Trabalhar com arquivos temporários em `.cache/trabalho/<nome_projeto>/` e exportar o resultado final em `Video Pronto/`.
3. Sempre iniciar comandos PowerShell com `. .\activate-env.ps1`.

## Pipeline de Edição Passo a Passo

### 1. Ingestão e Análise do Bruto
- Inspecionar o bruto com `ffprobe` (resolução, fps, orientação/rotação, streams de áudio, duração, loudness).
- Extrair áudio mono 16kHz para `.cache/trabalho/<id>/audio.wav` e transcrever com `whisper` na GPU com `word_timestamps=True` e `language="pt"`.
- Se o vídeo tiver trechos longos, gerar uma folha de contato visual com `ffmpeg` para identificar falantes, expressões, detalhes de cosplay e melhores momentos visuais.

### 2. Roteiro de Corte (Retenção Primeiro)
- **Identificar o Cold Open (0s–2,5s):** escolher a resposta mais engraçada, frase absurda ou close impressionante do cosplay.
- **Selecionar os melhores blocos:** para entrevistas, manter as **2–3 melhores trocas** dentro da duração alvo (`45s–65s`, teto `70s` salvo aprovação para Parte 1/2). Para pílulas/reações, mirar `25s–45s`.
- **Cortar pausas mortas > 0.25s** respeitando timing cômico (`0.4s–0.6s` quando houver piada).
- **Planejar resets visuais a cada 1.8s–3.0s:** mapear momentos de `punch-in` (`115%–125%`), `close` em detalhe (`130%+`), inserção de B-roll/meme (`0.8s–1.8s`) ou micro-tag/HUD.

### 3. Tratamento de Áudio e Mixagem
- Aplicar passa-altas (`highpass=f=80`) para limpar vento/ar-condicionado de evento e compressão vocal consistente.
- Inserir trilha de fundo compatível com o mood (`-24 dB` a `-28 dB` abaixo da voz, com ducking automático na fala).
- Inserir SFX/áudios de meme limitados entre `-12 dB` e `-8 dB` (sem picos bruscos).
- Normalizar saída final com `loudnorm` para `-13` a `-14 LUFS`, True Peak `<= -1.0 dBTP`, `LRA <= 5 LU`.

### 4. Compositing, Legendas e Motion (`ffmpeg` + `hyperframes`)
- Padronizar tela cheia **`1080x1920`** (sem tarjas pretas; para B-roll 16:9 usar faixa central ou split mantendo sujeito visível).
- Aplicar color grade sutil (contraste `+10–15%`, saturação ~`0.44–0.50`).
- Gerar overlays gráficos e legendas sincronizadas por palavra (`word_timestamps`) usando **fontes locais portáveis** (`assets/fonts/Rubik-Bold.ttf` e `Rubik-BoldItalic.ttf`, passando `fontsdir` ao filtro `ass` para funcionar igual no Windows e Linux), respeitando as cores por falante (`Breno`, `Reuel` e `Athos` com paleta aleatorizada por vídeo entre `#FFD600`, `#38BDF8`, `#F472B6`, e convidados em `#FFFFFF`) e **Safe Zone** (`y` mais abaixo, entre `64%` e `70%` da altura, sempre acima dos `28%` inferiores; banner de hook no terço superior `16%–21%` saindo aos `2.8s`; HUD/placar no topo seguro em dinâmicas em grupo) definidos em `docs/FOLHA_DE_ESTILO.md`.
- **Animação obrigatória em todo overlay:** hook banner, micro-tags, badges e HUD devem entrar e sair com animação suave (*slide* + *fade* de `~0,20s–0,25s`), nunca com corte seco sem transição.
- Para segmentos intermediários com áudio PCM (`pcm_s16le`), usar container `.mkv` (evitar `.ts`, que não suporta PCM) e `zoompan` em *upscale* `2x` (ou `crop` fixo para *punch-in* seco).
- Renderizar com `hyperframes` (quando usar composições HTML/CSS/GSAP) e/ou `ffmpeg` com encoding de alta qualidade (`libx264 -crf 17 -pix_fmt yuv420p` ou NVENC equivalente com verificação de qualidade).

### 5. Verificação Pós-Render Obrigatória
- Conferir `ffprobe` no arquivo final em `Video Pronto/` (deve ser `1080x1920`, áudio AAC 44.1/48kHz).
- Conferir loudness com `ffmpeg -af ebur128` (`I` próximo de `-13/-14 LUFS`, `LRA <= 5 LU`).
- Extrair frames do hook (`0.5s`), meio (`50%`), transição/meme e final (`95%`) e inspecionar visualmente com `read_file` para garantir que nenhuma legenda invade a UI do Shorts nem sobrepõe rostos.
- Entregar junto ao vídeo uma sugestão de **título PT-BR com gancho**, **descrição com @s** e **hashtags específicas**.
