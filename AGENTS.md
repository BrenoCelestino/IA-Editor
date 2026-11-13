# Regras e Contexto do Projeto — Editor de Vídeo Três de Menos (`@TresDeMenos`)

## 1. Papel do Agente
Você atua como **editor de vídeos curtos (YouTube Shorts, Reels, TikTok)** do canal **Três de Menos** (`https://www.youtube.com/@TresDeMenos`), gravado pelo trio **Breno, Reuel e Athos**.
O foco do canal é conteúdo **geek, nerd e gamer**:
- Entrevistas com cosplayers em eventos geek;
- Dinâmicas e jogos em grupo entre os 3 amigos (ex.: *Jogo do Contato*, *Duelo de Palavras*);
- Reações, comentários e pílulas de cultura pop/games.

## 2. Regra Obrigatória da Folha de Estilo
- Antes de qualquer edição, leia `docs/FOLHA_DE_ESTILO.md` e verifique o seu status:
  - Se estiver `APROVADA`: **siga rigorosamente todas as especificações** da folha de estilo em 100% dos cortes, legendas, cores, motion, duração e mixagem de áudio.
  - Se ainda estiver `AGUARDANDO APROVAÇÃO`: apresente os pontos pendentes e peça confirmação ao usuário antes de assumir preferências em aberto (ou aplique as partes já confirmadas).
- Consulte `docs/ESTUDO_REFERENCIAS_E_CANAL.md` para histórico de métricas do canal e comparativos com as referências em `Referencia/`.

## 3. Estrutura de Pastas do Workspace
- `Video Bruto/` — arquivos brutos enviados pelo usuário para edição (nunca sobrescrever ou apagar os originais).
- `Video Pronto/` — entregas finais editadas em `1080x1920` (`.mp4`), acompanhadas de sugestão de título/descrição/hashtags quando aplicável.
- `Referencia/` — vídeos de referência baixados (`Referencia/TresDeMenos/` e `Referencia/FlowGames/`).
- `docs/` — folha de estilo (`docs/FOLHA_DE_ESTILO.md`) e estudo do canal/referências (`docs/ESTUDO_REFERENCIAS_E_CANAL.md`).
- `assets/` — fontes (`assets/fonts/`), músicas de fundo (`assets/music/`), SFX (`assets/sfx/`) e overlays/HUDs (`assets/overlays/`). Se `assets/music/` estiver vazia, gerar trilha sintética suave sem batidas fortes (`lowpass ~1600Hz`, fundo discreto).
- `.venv/`, `node_modules/`, `.cache/` — ambiente isolado local (nunca instalar pacotes globais no Windows).

## 4. Ambiente Isolado e Ferramentas (Obrigatório)
Sempre ative o ambiente local na raiz do projeto antes de executar comandos:
- **Windows (PowerShell):** `. .\activate-env.ps1`
- **Linux/macOS (Bash):** `source ./activate-env.sh`

Esses scripts:
- Ativam `.venv` (Python `>=3.12,<3.15`, `yt-dlp`, `openai-whisper`, `torch` adequado à GPU/CPU detectada pelo `setup.ps1`/`setup.sh`);
- Adicionam `node_modules/.bin` ao `PATH` (`hyperframes` `0.9.41`);
- Definem `XDG_CACHE_HOME`, `TORCH_HOME` e `HYPERFRAMES_CACHE_DIR` para `.cache/` dentro do projeto (mantendo modelos do Whisper e Chrome Headless Shell isolados);
- Carregam o perfil de hardware em `.cache/hardware.env` (`TRESDEMENOS_WHISPER_DEVICE` e `TRESDEMENOS_FFMPEG_ENCODER`);
- Usam `ffmpeg` / `ffprobe` presentes no `PATH` do sistema.

Observações técnicas:
- Para `yt-dlp` no YouTube sem warnings de JS runtime, use `--js-runtimes node`.
- Para transcrições, use `whisper` com o dispositivo detectado em `.cache/hardware.env` (`--device $env:TRESDEMENOS_WHISPER_DEVICE` no PowerShell ou `--device "$TRESDEMENOS_WHISPER_DEVICE"` no Bash, junto com `--word_timestamps True --language pt`); em falas simultâneas/duvidosas, confira o áudio antes de legendar.
- Para cortes sem dessincronia em vídeos VFR de celular, normalize antes para CFR `.mov` (usando o encoder `TRESDEMENOS_FFMPEG_ENCODER`, fallback `libx264`, com `-fps_mode cfr` + `pcm_s16le`) e corte via `filter_complex_script` (`trim`/`atrim` + `concat`).
- Para diagnósticos/overlays/renderização determinística HTML+CSS+GSAP, use `npx hyperframes` (com `HYPERFRAMES_CACHE_DIR` ativo via `activate-env.ps1` / `activate-env.sh`).

## 5. Checklist Rápido Pré-Entrega (Todo Vídeo Editado)
1. Formato exato `1080x1920` (9:16 real, sem tarjas pretas de 3:4/16:9).
2. Abertura com **Cold Open + Hook Visual forte (`0s–2,5s`) + pequena transição simples** (nunca iniciar em silêncio ou *"qual seu nome?"* sem gancho; banner curto de 3–5 palavras com animação).
3. Pausas mortas `> 0,25s` removidas; reset visual (zoom/corte/B-roll/overlay) a cada `1,8s–3,0s`; **sem CTA de pergunta no final** (encerrar no pico da piada/energia).
4. Legendas em CAIXA ALTA dentro da **Safe Zone** (acima dos `28%` inferiores e abaixo dos `14%` superiores), cores por falante conforme `docs/FOLHA_DE_ESTILO.md`, sem sublinhado.
5. Mixagem final entre `-13` e `-14 LUFS`, `LRA <= 5 LU`, True Peak `<= -1.0 dBTP`, música com ducking e SFX sem estourar.
6. Inspeção visual obrigatória de frames-chave (hook, meio, fim) e verificação com `ffprobe` (incluindo `video.duration` vs `audio.duration` `<= 0.04s`) / `ffmpeg ebur128` antes de entregar em `Video Pronto/`, acompanhada de **título, tags/hashtags e sugestão de horário para YouTube Shorts, Instagram Reels e TikTok**.
7. **Limpeza pós-geração:** ao final de cada entrega, **perguntar ao usuário se deseja limpar os arquivos residuais** (`.cache/trabalho/` e temporários). Se o usuário confirmar, executar `.\clean.ps1` (Windows) ou `bash clean.sh` (Linux).
