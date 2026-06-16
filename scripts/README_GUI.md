# Gerador de Legendas — app desktop (macOS)

Interface gráfica para gerar o arquivo `.captions.json` usado pelo módulo
**Audio Visualizer**, sem precisar de linha de comando. Roda localmente no
computador do usuário (Whisper processa o áudio na própria máquina).

## Rodar a partir do código (com Python instalado)

```bash
cd scripts
pip install -r requirements-transcribe.txt
python transcribe_gui.py
```

Selecione o áudio, escolha o modelo/idioma e clique em **Gerar Legenda**. O
arquivo `.captions.json` gerado é o que se faz upload no módulo Audio
Visualizer do site (junto com o áudio original).

## Gerar um app `.app` (sem precisar instalar Python)

Use o [PyInstaller](https://pyinstaller.org/) **em um Mac** (o build de app
macOS precisa ser feito em macOS, não dá pra gerar a partir de Windows/Linux):

```bash
# Em um Mac, com Python 3.10+ instalado (python.org ou Homebrew)
cd scripts
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements-transcribe.txt pyinstaller

pyinstaller --windowed --onefile \
  --name "Gerador de Legendas" \
  transcribe_gui.py
```

O app fica em `scripts/dist/Gerador de Legendas.app`. Comprima (zip) essa
pasta e envie para o usuário final.

### Observações importantes (macOS)

- **Gatekeeper**: como o app não é assinado/notarizado pela Apple, no primeiro
  uso o macOS vai bloquear com "não é possível verificar o desenvolvedor". O
  usuário precisa: clicar com botão direito (ou Control+clique) no app →
  **Abrir** → confirmar **Abrir** no diálogo. Só precisa fazer isso uma vez.
- **ffmpeg**: o Whisper depende do `ffmpeg` no sistema. Se o usuário não tiver,
  instale via Homebrew: `brew install ffmpeg`. (Sem isso o app abre mas falha
  ao transcrever.)
- **Primeiro uso é lento**: o Whisper baixa o modelo (tiny/base/small/...) na
  primeira transcrição com aquele modelo e guarda em cache local
  (`~/.cache/whisper`). É necessário ter internet na primeira vez para cada
  modelo usado.
- **Tamanho do app**: o PyInstaller empacota o PyTorch + Whisper, então o
  `.app` final fica grande (várias centenas de MB). Isso é esperado.
- Caso quase nada do `tkinter` apareça (especialmente em Python via Homebrew),
  garanta que o Python usado tenha Tk: `brew install python-tk@3.x` ou prefira
  o instalador oficial de python.org, que já inclui Tk.
