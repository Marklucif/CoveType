import importlib.util
import tempfile
import unittest
from pathlib import Path
from unittest import mock


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "covetype_local_ai_worker",
    ROOT / "Resources" / "covetype_local_ai_worker.py",
)
WORKER = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(WORKER)


class LocalAIWorkerTests(unittest.TestCase):
    def test_removes_exact_repeated_sentences(self):
        text = "什么时候要？我到现在为止还没睡觉呢。什么时候要？"
        self.assertEqual(
            WORKER.remove_exact_repeated_sentences(text),
            "什么时候要？我到现在为止还没睡觉呢。",
        )

    def test_rejects_translation_during_chinese_polish(self):
        with self.assertRaisesRegex(RuntimeError, "changed the input language"):
            WORKER.validate_polish(
                "我到现在还没睡觉。",
                "I have not slept yet.",
                "formal",
            )

    def test_preserves_protected_values(self):
        with self.assertRaisesRegex(RuntimeError, "protected token"):
            WORKER.validate_polish(
                "Meet at 15:30 via https://covetype.com.",
                "Meet later via our website.",
                "concise",
            )

    def test_detects_incomplete_model_shards(self):
        with tempfile.TemporaryDirectory() as directory:
            model = Path(directory)
            (model / "config.json").write_text("{}", encoding="utf-8")
            (model / "model.safetensors.index.json").write_text(
                '{"weight_map":{"layer":"missing.safetensors"}}',
                encoding="utf-8",
            )
            self.assertFalse(WORKER.model_is_complete(model, "test"))

    def test_empty_asr_result_is_recoverable_no_speech(self):
        class EmptyResult:
            text = ""
            language = None

        class EmptyModel:
            @staticmethod
            def generate(*_args, **_kwargs):
                return EmptyResult()

        with tempfile.NamedTemporaryFile(suffix=".wav") as audio:
            with mock.patch.object(WORKER, "load_asr", return_value=EmptyModel()):
                with self.assertRaises(WORKER.NoSpeechDetectedError) as raised:
                    WORKER.transcribe(audio.name)
        self.assertEqual(raised.exception.error_code, "no_speech")


if __name__ == "__main__":
    unittest.main()
