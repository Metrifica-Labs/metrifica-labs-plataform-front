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
      var base = 'https://unpkg.com/@ffmpeg/core@0.12.6/dist/umd';
      await ffmpeg.load({
        coreURL: await utilMod.toBlobURL(base + '/ffmpeg-core.js', 'text/javascript'),
        wasmURL: await utilMod.toBlobURL(base + '/ffmpeg-core.wasm', 'application/wasm'),
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
  // "progressivo" com duracao correta no cabecalho. Quando sourceIsMp4 e
  // true faz so um remux (stream copy, quase instantaneo); quando false
  // transcodifica de vp8/vp9+opus para h264+aac. onProgress(0..1) e chamado
  // periodicamente durante o processamento.
  window.normalizeRecordingToMp4 = function (bytes, sourceIsMp4, onProgress) {
    progressCb = onProgress || null;
    var inputName = sourceIsMp4 ? 'input.mp4' : 'input.webm';
    var args = sourceIsMp4
      ? ['-i', inputName, '-c', 'copy', '-movflags', '+faststart', 'output.mp4']
      : [
          '-i', inputName,
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
        progressCb = null;
        throw err;
      });
  };
})();
