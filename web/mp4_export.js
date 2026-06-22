// Suporte a exportacao direta em .mp4 para o Audio Visualizer.
//
// Estrategia:
// 1. Se o navegador suportar gravar MediaRecorder direto em .mp4 (H.264/AAC),
//    usamos isso (caminho rapido de captura).
// 2. Caso contrario, o motor Dart grava em .webm (caminho ja existente).
//
// Em ambos os casos o resultado passa por normalizeRecordingToMp4() abaixo,
// que carrega o ffmpeg.wasm (build single-thread, sem precisar de COOP/COEP)
// sob demanda e gera um .mp4 "normal" (moov no inicio, duracao correta no
// cabecalho). Isso e necessario porque tanto o .webm gravado via
// MediaRecorder (modo streaming) quanto o .mp4 fragmentado que alguns
// navegadores gravam nativamente costumam sair sem a duracao total no
// container, o que faz validadores de upload (TikTok, Instagram etc.)
// lerem o video como "0 segundos" e rejeitarem.
(function () {
  var ffmpegPromise = null;
  var progressCb = null;

  // Monta o worker.js do @ffmpeg/ffmpeg como um blob self-contido. O pacote
  // distribui worker.js com imports relativos ("./const.js", "./errors.js"),
  // que nao resolvem quando o script roda a partir de uma blob: URL (sem
  // diretorio real). O proprio esm.sh tambem nao serve um worker.js valido
  // para esta versao (404 / origem cruzada). Por isso buscamos os 3 arquivos
  // fonte direto do unpkg (mesma versao do pacote) e os concatenamos num
  // unico script sem import/export, eliminando a resolucao relativa.
  function buildWorkerBlobURL() {
    var base = 'https://unpkg.com/@ffmpeg/ffmpeg@0.12.10/dist/esm/';
    return Promise.all([
      fetch(base + 'const.js').then(function (r) { return r.text(); }),
      fetch(base + 'errors.js').then(function (r) { return r.text(); }),
      fetch(base + 'worker.js').then(function (r) { return r.text(); }),
    ]).then(function (parts) {
      var constSrc = parts[0].replace(/^export\s+/gm, '');
      var errorsSrc = parts[1].replace(/^export\s+/gm, '');
      var workerSrc = parts[2].replace(/^import[^\n]*\n/gm, '');
      var merged = constSrc + '\n' + errorsSrc + '\n' + workerSrc;
      var blob = new Blob([merged], { type: 'text/javascript' });
      return URL.createObjectURL(blob);
    });
  }

  function loadFFmpeg() {
    if (ffmpegPromise) return ffmpegPromise;
    ffmpegPromise = (async function () {
      var ffmpegMod = await import('https://esm.sh/@ffmpeg/ffmpeg@0.12.10');
      var utilMod = await import('https://esm.sh/@ffmpeg/util@0.12.2');
      var ffmpeg = new ffmpegMod.FFmpeg();
      ffmpeg.on('progress', function (ev) {
        if (progressCb) {
          try {
            progressCb(ev && typeof ev.progress === 'number' ? ev.progress : 0);
          } catch (e) {}
        }
      });
      // Usa o build ESM do core (nao o UMD) porque o worker roda como
      // `{type: "module"}" (exigido pelo classWorkerURL abaixo); nesse modo
      // `importScripts` nao existe, entao o worker.js cai no fallback de
      // `import()` dinamico, que precisa de um modulo com `export default`
      // (so o build ESM tem isso, o UMD e so um IIFE sem export).
      var base = 'https://unpkg.com/@ffmpeg/core@0.12.6/dist/esm';
      await ffmpeg.load({
        coreURL: await utilMod.toBlobURL(base + '/ffmpeg-core.js', 'text/javascript'),
        wasmURL: await utilMod.toBlobURL(base + '/ffmpeg-core.wasm', 'application/wasm'),
        // Sem isso o @ffmpeg/ffmpeg tenta `new Worker()` direto numa URL de
        // outra origem, e o navegador bloqueia (SecurityError), fazendo a
        // normalizacao falhar silenciosamente e cair no fallback do video
        // bruto (VFR). O blob URL e "same-origin" e nao tem o problema de
        // imports relativos que o worker.js original do pacote tem.
        classWorkerURL: await buildWorkerBlobURL(),
      });
      return ffmpeg;
    })();
    return ffmpegPromise;
  }

  // Retorna o melhor mimeType de .mp4 suportado nativamente pelo
  // MediaRecorder para gravacao direta, ou null se nenhum for suportado.
  window.metrificaPickExportMime = function () {
    var candidates = [
      'video/mp4;codecs=avc1.42E01E,mp4a.40.2',
      'video/mp4;codecs=h264,aac',
      'video/mp4',
    ];
    for (var i = 0; i < candidates.length; i++) {
      if (window.MediaRecorder && MediaRecorder.isTypeSupported(candidates[i])) {
        return candidates[i];
      }
    }
    return null;
  };

  // Normaliza a gravacao (de .webm ou de .mp4 fragmentado) para um .mp4
  // "progressivo" com duracao correta no cabecalho, sempre reencodando o
  // video para frame rate constante (CFR). O MediaRecorder (tanto gravando
  // .webm quanto .mp4 nativo) entrega frames do canvas em intervalos
  // irregulares (VFR), e um remux com "-c copy" preserva esses timestamps
  // irregulares. Validadores de upload (Instagram, TikTok etc.) leem video
  // VFR e calculam a duracao errado, rejeitando como "muito curto" mesmo
  // com o tempo total correto no cabecalho. Usamos o filtro "fps=" (em vez
  // de so "-r", que o build do ffmpeg.wasm nao aplica como vsync CFR) para
  // forcar duplicacao/descarte de frames e gerar PTS realmente constantes.
  // onProgress (0..1) e chamado periodicamente durante o processamento.
  window.normalizeRecordingToMp4 = function (bytes, sourceIsMp4, fps, onProgress) {
    progressCb = onProgress || null;
    var inputName = sourceIsMp4 ? 'input.mp4' : 'input.webm';
    var outFps = fps && fps > 0 ? fps : 30;
    var args = [
      '-i', inputName,
      '-vf', 'fps=' + outFps,
      '-vsync', 'cfr',
      '-c:v', 'libx264',
      '-preset', 'veryfast',
      '-crf', '23',
      '-pix_fmt', 'yuv420p',
      '-c:a', 'aac',
      '-b:a', '192k',
      '-movflags', '+faststart',
      'output.mp4',
    ];
    return loadFFmpeg()
      .then(function (ffmpeg) {
        return ffmpeg
          .writeFile(inputName, bytes)
          .then(function () {
            return ffmpeg.exec(args);
          })
          .then(function () {
            return ffmpeg.readFile('output.mp4');
          })
          .then(function (data) {
            try {
              ffmpeg.deleteFile(inputName);
              ffmpeg.deleteFile('output.mp4');
            } catch (e) {}
            progressCb = null;
            return data;
          });
      })
      .catch(function (err) {
        console.error('[audio-visualizer] ffmpeg normalize failed:', err);
        progressCb = null;
        throw err;
      });
  };
})();
