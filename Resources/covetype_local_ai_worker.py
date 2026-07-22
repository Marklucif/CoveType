#!/usr/bin/env python3
"""Persistent, local-only MLX worker for CoveType.

The worker accepts one JSON object per line on stdin and emits one JSON object
per line on stdout. Model diagnostics are redirected to stderr so the protocol
stream stays machine-readable.
"""

from __future__ import annotations

import contextlib
import gc
import json
import os
import re
import select
import sys
import time
import traceback
from pathlib import Path
from typing import Any


os.environ.setdefault("HF_HUB_DISABLE_PROGRESS_BARS", "1")
os.environ.setdefault("TOKENIZERS_PARALLELISM", "false")

APP_SUPPORT = Path.home() / "Library" / "Application Support" / "CoveType"
ASR_MODEL_PATH = APP_SUPPORT / "models" / "Qwen3-ASR-0.6B-8bit"
POLISH_MODEL_PATH = APP_SUPPORT / "models" / "Qwen3.5-0.8B-4bit"
IDLE_TIMEOUT_SECONDS = max(10, int(os.environ.get("COVETYPE_AI_IDLE_TIMEOUT", "45")))

_asr_model: Any = None
_polish_model: Any = None
_polish_tokenizer: Any = None


def emit(payload: dict[str, Any]) -> None:
    print(json.dumps(payload, ensure_ascii=False, separators=(",", ":")), flush=True)


def require_model(path: Path, display_name: str) -> None:
    if not path.is_dir() or not (path / "config.json").is_file():
        raise RuntimeError(f"{display_name} model is not installed at {path}")
    index_path = path / "model.safetensors.index.json"
    if index_path.is_file():
        try:
            index = json.loads(index_path.read_text(encoding="utf-8"))
            shards = set(index.get("weight_map", {}).values())
        except (OSError, json.JSONDecodeError) as error:
            raise RuntimeError(f"{display_name} model index is invalid: {error}") from error
        missing = [name for name in shards if not (path / name).is_file() or (path / name).stat().st_size == 0]
        if not shards or missing:
            raise RuntimeError(f"{display_name} model weights are incomplete at {path}")
    elif not (path / "model.safetensors").is_file() or (path / "model.safetensors").stat().st_size == 0:
        raise RuntimeError(f"{display_name} model weights are missing at {path}")


def model_is_complete(path: Path, display_name: str) -> bool:
    try:
        require_model(path, display_name)
        return True
    except RuntimeError:
        return False


def load_asr() -> Any:
    global _asr_model
    if _asr_model is None:
        require_model(ASR_MODEL_PATH, "Qwen3-ASR")
        from mlx_audio.stt.utils import load_model

        with contextlib.redirect_stdout(sys.stderr):
            _asr_model = load_model(str(ASR_MODEL_PATH))
    return _asr_model


def load_polisher() -> tuple[Any, Any]:
    global _polish_model, _polish_tokenizer
    if _polish_model is None or _polish_tokenizer is None:
        require_model(POLISH_MODEL_PATH, "Qwen3.5")
        from mlx_lm import load

        with contextlib.redirect_stdout(sys.stderr):
            _polish_model, _polish_tokenizer = load(str(POLISH_MODEL_PATH))
    return _polish_model, _polish_tokenizer


def transcribe(audio_path: str, language: str | None = None) -> dict[str, Any]:
    audio = Path(audio_path)
    if not audio.is_file():
        raise RuntimeError(f"Audio file does not exist: {audio}")

    model = load_asr()
    started = time.perf_counter()
    with contextlib.redirect_stdout(sys.stderr):
        result = model.generate(
            str(audio),
            language=language,
            max_tokens=2048,
            temperature=0.0,
            verbose=False,
        )
    text = str(getattr(result, "text", "")).strip()
    if not text:
        raise RuntimeError("Qwen3-ASR returned an empty transcript")
    detected_language = getattr(result, "language", None)
    if isinstance(detected_language, list):
        detected_language = detected_language[0] if detected_language else None
    return {
        "text": text,
        "language": detected_language,
        "seconds": round(time.perf_counter() - started, 3),
    }


MODE_INSTRUCTIONS = {
    "light": "Remove only filler words and exact repetitions, add necessary punctuation, and preserve the original sentence structure.",
    "formal": "Rewrite as natural, professional, and clear prose without changing the meaning.",
    "concise": "Remove redundancy while preserving every key fact and intent.",
}

ZH_MODE_INSTRUCTIONS = {
    "light": "仅删除口吃、填充词和完全重复，补充必要标点，尽量保持原句结构。",
    "formal": "删除口吃、填充词和重复表达，修正明显语序问题，使表达自然清楚，但不要改变词义。",
    "concise": "删除冗余和重复，同时保留每个关键信息、事实与意图。",
}

PROTECTED_PATTERNS = (
    r"https?://[A-Za-z0-9./?=_#%&+:@~\-]+|www\.[A-Za-z0-9./?=_#%&+:@~\-]+",
    r"[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}",
    r"\d+(?:[.,:：/\-]\d+)*",
)


def protected_tokens(text: str) -> list[str]:
    tokens: list[str] = []
    for pattern in PROTECTED_PATTERNS:
        tokens.extend(re.findall(pattern, text, flags=re.IGNORECASE))
    return tokens


def mask_protected_tokens(text: str) -> tuple[str, list[tuple[str, str]]]:
    combined = re.compile("|".join(f"(?:{pattern})" for pattern in PROTECTED_PATTERNS), re.IGNORECASE)
    replacements: list[tuple[str, str]] = []

    def replace(match: re.Match[str]) -> str:
        placeholder = f"ZXQKEEP{len(replacements)}QXZ"
        replacements.append((placeholder, match.group(0)))
        return placeholder

    return combined.sub(replace, text), replacements


def compact_token(text: str) -> str:
    return re.sub(r"\s+", "", text).lower()


def is_predominantly_chinese(text: str) -> bool:
    visible = re.sub(r"\s+", "", text)
    if not visible or re.search(r"[\u3040-\u30ff]", visible):
        return False
    cjk_count = len(re.findall(r"[\u3400-\u9fff]", visible))
    return cjk_count / len(visible) >= 0.35


def validate_polish(original: str, candidate: str, mode: str) -> None:
    if not candidate:
        raise RuntimeError("Qwen3.5 returned empty text")
    lowered = candidate.lstrip().lower()
    if lowered.startswith(("thinking process", "analysis:", "分析：", "分析:")):
        raise RuntimeError("Qwen3.5 returned analysis instead of polished text")

    original_size = len(re.sub(r"\s+", "", original))
    candidate_size = len(re.sub(r"\s+", "", candidate))
    # Formal rewrites can legitimately remove a long false start or repeated
    # question. Keep strict protected-token checks, but do not reject a useful
    # rewrite solely because it is substantially shorter than the dictation.
    minimum_ratio = 0.45 if mode == "light" else (0.20 if mode == "formal" else 0.25)
    maximum_ratio = 1.8 if mode != "formal" else 2.5
    if original_size and not (original_size * minimum_ratio <= candidate_size <= original_size * maximum_ratio):
        raise RuntimeError("Polished text changed length unexpectedly")

    compact_candidate = compact_token(candidate)
    if is_predominantly_chinese(original) and not is_predominantly_chinese(candidate):
        raise RuntimeError("Qwen3.5 changed the input language")
    for token in protected_tokens(original):
        if compact_token(token) not in compact_candidate:
            raise RuntimeError(f"Polished text did not preserve protected token: {token}")


def remove_adjacent_repetitions(text: str) -> str:
    """Remove only exact adjacent CJK phrase repeats, including across punctuation."""
    pattern = re.compile(r"([\u3400-\u9fff]{2,12})(?:[\s，,、。！？!?；;：:]*)\1")
    result = text
    for _ in range(4):
        result, replacement_count = pattern.subn(r"\1", result)
        if replacement_count == 0:
            break
    return result


def remove_exact_repeated_sentences(text: str) -> str:
    """Drop later exact sentence repeats produced by speech restarts."""
    chunks = re.findall(r".*?[。！？.!?]+|.+$", text, flags=re.DOTALL)
    if len(chunks) < 2:
        return text
    seen: set[str] = set()
    kept: list[str] = []
    for chunk in chunks:
        key = compact_token(re.sub(r"[\s。！？.!?]+$", "", chunk))
        if key and key in seen:
            continue
        if key:
            seen.add(key)
        kept.append(chunk)
    return "".join(kept).strip()


def polish(text: str, mode: str) -> dict[str, Any]:
    original = text.strip()
    if not original:
        raise RuntimeError("Cannot polish empty text")
    if mode not in MODE_INSTRUCTIONS:
        raise RuntimeError(f"Unsupported polish mode: {mode}")

    model_text, protected_replacements = mask_protected_tokens(original)

    model, tokenizer = load_polisher()
    if is_predominantly_chinese(original):
        messages = [
            {
                "role": "system",
                "content": (
                    "你是中文语音输入的保守润色器。输入是中文，输出必须仍为中文，严禁翻译。"
                    "保留所有数字及格式、日期、金额、人名、专有名词、邮箱、网址、事实、语气和否定关系。"
                    "任何以 ZXQKEEP 开头并以 QXZ 结尾的占位符必须原样保留。"
                    "不得编造、解释或增加信息。只输出润色后的中文，不要引号。"
                ),
            },
            {
                "role": "user",
                "content": f"任务：{ZH_MODE_INSTRUCTIONS[mode]}\n中文口述：\n{model_text}",
            },
        ]
        answer_prefix = "润色结果："
    else:
        messages = [
            {
                "role": "system",
                "content": (
                    "You are a conservative multilingual dictation polishing engine. Detect the input language "
                    "and return only that same language; translation is forbidden. Preserve every number and its "
                    "formatting, date, amount, name, proper noun, email, URL, fact, tone, and negation. Any "
                    "placeholder beginning with ZXQKEEP and ending with QXZ must remain unchanged. Never invent, "
                    "explain, or add information. Return only the polished text without quotation marks."
                ),
            },
            {
                "role": "user",
                "content": f"Task: {MODE_INSTRUCTIONS[mode]}\nDictation:\n{model_text}",
            },
        ]
        answer_prefix = "Polished text:"
    prompt = tokenizer.apply_chat_template(
        messages,
        tokenize=False,
        add_generation_prompt=True,
        enable_thinking=False,
    )
    # Prefilling the answer label prevents this small model from starting a
    # visible chain-of-thought even when the caller requests a direct answer.
    prompt += answer_prefix
    max_tokens = max(96, min(2048, len(original) * 3 + 48))

    from mlx_lm import generate

    started = time.perf_counter()
    with contextlib.redirect_stdout(sys.stderr):
        candidate = generate(
            model,
            tokenizer,
            prompt=prompt,
            max_tokens=max_tokens,
            verbose=False,
        ).strip()
    candidate = re.sub(r"^(?:Polished text|润色结果)[：:]\s*", "", candidate, flags=re.IGNORECASE).strip()
    if len(candidate) >= 2 and candidate[0] in "\"'“‘" and candidate[-1] in "\"'”’":
        candidate = candidate[1:-1].strip()
    for placeholder, value in protected_replacements:
        candidate = candidate.replace(placeholder, value)
    candidate = remove_adjacent_repetitions(candidate)
    candidate = remove_exact_repeated_sentences(candidate)
    validate_polish(original, candidate, mode)
    return {"text": candidate, "seconds": round(time.perf_counter() - started, 3)}


def release_models() -> None:
    global _asr_model, _polish_model, _polish_tokenizer
    _asr_model = None
    _polish_model = None
    _polish_tokenizer = None
    gc.collect()
    try:
        import mlx.core as mx

        mx.clear_cache()
    except Exception:
        pass


def prewarm(load_asr_model: bool, load_polish_model: bool) -> dict[str, Any]:
    started = time.perf_counter()
    if load_asr_model:
        load_asr()
    if load_polish_model:
        load_polisher()
        # Run one tiny rewrite while the user is speaking so Metal kernel
        # compilation is paid during recording instead of after key release.
        try:
            polish("我们明天下午三点开会。", "light")
        except Exception:
            pass
    return {
        "prewarmed": True,
        "seconds": round(time.perf_counter() - started, 3),
        "asr_loaded": load_asr_model,
        "polish_loaded": load_polish_model,
    }


def handle(command: dict[str, Any]) -> dict[str, Any]:
    action = command.get("action")
    if action == "health":
        return {
            "ready": True,
            "asr_installed": model_is_complete(ASR_MODEL_PATH, "Qwen3-ASR"),
            "polish_installed": model_is_complete(POLISH_MODEL_PATH, "Qwen3.5"),
        }
    if action == "transcribe":
        language_value = command.get("language")
        language = str(language_value).strip() if language_value else None
        return transcribe(str(command.get("audio_path", "")), language)
    if action == "polish":
        return polish(str(command.get("text", "")), str(command.get("mode", "light")))
    if action == "prewarm":
        return prewarm(bool(command.get("load_asr", True)), bool(command.get("load_polisher", True)))
    if action == "release":
        release_models()
        return {"released": True}
    if action == "shutdown":
        return {"shutdown": True}
    raise RuntimeError(f"Unsupported action: {action}")


def main() -> None:
    emit({"ready": True, "protocol": 1})
    while True:
        readable, _, _ = select.select([sys.stdin], [], [], IDLE_TIMEOUT_SECONDS)
        if not readable:
            return
        line = sys.stdin.readline()
        if not line:
            return
        request_id: Any = None
        action: Any = None
        try:
            command = json.loads(line)
            request_id = command.get("id")
            action = command.get("action")
            result = handle(command)
            emit({"id": request_id, "ok": True, **result})
            if action == "shutdown":
                return
        except Exception as error:
            traceback.print_exc(file=sys.stderr)
            emit({"id": request_id, "ok": False, "error": str(error)})


if __name__ == "__main__":
    main()
