"""Transcribe once per job with WhisperX (word-level timestamps). Run with the shared venv's python:

  %USERPROFILE%\\.cache\\video-editor\\whisperx-venv\\Scripts\\python.exe scripts\\transcribe.py <media> <out_dir> [--lang en] [--model large-v3] [--no-verbatim]

Outputs in <out_dir>:
  audio16k.wav    16 kHz mono extract
  words.json      {"language", "words": [{"word","start","end","score","seg"}], "segments": [{"id","start","end","text","w":[first,last]}]}
                  times in seconds of the source clip; "w" indexes into "words"
  transcript.txt  compact, one line per segment: S003 [12.34-15.60] text
Never re-transcribes if words.json already exists.

Whisper normally drops "um/uh". With --lang en the default is a verbatim prompt that keeps them (disable with --no-verbatim).
"""
import argparse
import json
import os
import subprocess
import sys

os.environ.setdefault("PYTHONUTF8", "1")
os.environ.setdefault("HF_HUB_DISABLE_SYMLINKS", "1")

VERBATIM_PROMPT = "Umm, let me think like, hmm... Okay, here's what I'm, like, thinking."


def run(wav, device, compute, model_name, lang, verbatim):
    import whisperx

    audio = whisperx.load_audio(wav)
    asr_options = {"initial_prompt": VERBATIM_PROMPT} if (verbatim and lang == "en") else None
    kw = {"asr_options": asr_options} if asr_options else {}
    model = whisperx.load_model(model_name, device, compute_type=compute, language=lang, **kw)
    result = model.transcribe(audio, batch_size=16 if device == "cuda" else 4)
    language = result.get("language", lang or "en")
    align_model, meta = whisperx.load_align_model(language_code=language, device=device)
    aligned = whisperx.align(result["segments"], align_model, meta, audio, device, return_char_alignments=False)
    return language, aligned


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("media")
    ap.add_argument("out_dir")
    ap.add_argument("--lang", default=None)
    ap.add_argument("--model", default="large-v3")
    ap.add_argument("--no-verbatim", action="store_true")
    a = ap.parse_args()

    os.makedirs(a.out_dir, exist_ok=True)
    words_path = os.path.join(a.out_dir, "words.json")
    if os.path.exists(words_path):
        print("words.json exists, not transcribing again:", words_path)
        return

    wav = os.path.join(a.out_dir, "audio16k.wav")
    if not os.path.exists(wav):
        subprocess.run(
            ["ffmpeg", "-y", "-i", a.media, "-vn", "-ac", "1", "-ar", "16000", "-c:a", "pcm_s16le", wav],
            check=True, capture_output=True,
        )

    import torch

    device = "cuda" if torch.cuda.is_available() else "cpu"
    compute = "float16" if device == "cuda" else "int8"
    verbatim = not a.no_verbatim
    try:
        language, aligned = run(wav, device, compute, a.model, a.lang, verbatim)
    except Exception as e:  # CUDA hiccup -> CPU int8, keep going
        if device == "cuda":
            print("CUDA failed (%s); retrying on CPU int8" % e, file=sys.stderr)
            device = "cpu"
            language, aligned = run(wav, "cpu", "int8", a.model, a.lang, verbatim)
        else:
            raise

    words, segments, lines = [], [], []
    for i, seg in enumerate(aligned["segments"]):
        ws = seg.get("words", [])
        first = len(words)
        prev_end = seg["start"]
        for k, w in enumerate(ws):
            if "start" in w and "end" in w:
                s, e, sc = w["start"], w["end"], w.get("score", 0)
            else:  # tokens WhisperX could not align (digits etc.): keep them, borrow neighbour times
                nxt = next((x["start"] for x in ws[k + 1:] if "start" in x), seg["end"])
                s, e, sc = prev_end, max(prev_end, nxt), 0
            words.append({"word": w["word"], "start": round(s, 3), "end": round(e, 3), "score": round(sc, 3), "seg": i})
            prev_end = e
        last = len(words) - 1
        segments.append({"id": i, "start": round(seg["start"], 3), "end": round(seg["end"], 3),
                         "text": seg["text"].strip(), "w": [first, last] if last >= first else [None, None]})
        lines.append("S%03d [%.2f-%.2f] %s" % (i, seg["start"], seg["end"], seg["text"].strip()))

    with open(words_path, "w", encoding="utf-8") as f:
        json.dump({"language": language, "words": words, "segments": segments}, f, ensure_ascii=False)
    with open(os.path.join(a.out_dir, "transcript.txt"), "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    print("done:", len(words), "words,", len(segments), "segments, device", device, "language", language)


if __name__ == "__main__":
    main()
