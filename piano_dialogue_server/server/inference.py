from __future__ import annotations

import time
from dataclasses import dataclass
from typing import Any

from .midi_utils import NoteEvent
from .protocol import DialogueNote, GenerateParams
from .rule_backend import run_rule_improviser


def _dialogue_notes_to_note_events(notes: list[DialogueNote]) -> list[NoteEvent]:
    return [
        NoteEvent(
            note=int(n.note),
            velocity=int(n.velocity),
            time=float(n.time),
            duration=float(n.duration),
        )
        for n in notes
    ]


def _note_events_to_dialogue_notes(events: list[NoteEvent]) -> list[DialogueNote]:
    return [
        DialogueNote(
            note=max(0, min(127, e.note)),
            velocity=max(1, min(127, e.velocity)),
            time=max(0.0, e.time),
            duration=max(0.01, e.duration),
        )
        for e in events
    ]


def _max_phrase_end_sec(notes: list[DialogueNote]) -> float:
    if not notes:
        return 0.0
    return max(float(note.time + note.duration) for note in notes)


def _derive_response_length_sec(params: GenerateParams) -> float:
    sec = params.max_tokens / 64.0
    return max(2.0, min(sec, 12.0))


@dataclass(frozen=True)
class InferenceEngine:
    model_ref: str
    device: str
    model: Any
    load_ms: int

    def generate_response(
        self, notes: list[DialogueNote], params: GenerateParams, session_id: str | None
    ) -> list[DialogueNote]:
        del session_id

        input_events = _dialogue_notes_to_note_events(notes)
        response_seconds = _derive_response_length_sec(params)

        result = run_rule_improviser(
            input_events,
            response_seconds=response_seconds,
            style="pop",
            context_seconds=min(8.0, _max_phrase_end_sec(notes) + 1.0),
            mode="motif",
        )

        return _note_events_to_dialogue_notes(result.notes)

    def generate_response_with_debug(
        self, notes: list[DialogueNote], params: GenerateParams, session_id: str | None
    ) -> tuple[list[DialogueNote], dict[str, Any]]:
        del session_id

        input_events = _dialogue_notes_to_note_events(notes)
        response_seconds = _derive_response_length_sec(params)

        t0 = time.perf_counter()
        result = run_rule_improviser(
            input_events,
            response_seconds=response_seconds,
            style="pop",
            context_seconds=min(8.0, _max_phrase_end_sec(notes) + 1.0),
            mode="motif",
        )
        generate_ms = int((time.perf_counter() - t0) * 1000)

        reply_notes = _note_events_to_dialogue_notes(result.notes)

        debug: dict[str, Any] = {
            "engine": "rule_improviser",
            "prompt_end_sec": _max_phrase_end_sec(notes),
            "effective_response_length_sec": response_seconds,
            "generate_ms": generate_ms,
            "reply_note_count": len(reply_notes),
        }
        if result.debug:
            debug["rule_debug"] = result.debug

        return reply_notes, debug


_engine: InferenceEngine | None = None


def get_inference_engine() -> InferenceEngine:
    global _engine  # noqa: PLW0603
    if _engine is not None:
        return _engine

    t0 = time.time()
    # Rule-based engine requires no model loading
    load_ms = int((time.time() - t0) * 1000)

    _engine = InferenceEngine(
        model_ref="rule-improviser",
        device="cpu",
        model=None,
        load_ms=load_ms,
    )
    return _engine
