#!/usr/bin/env python3

import argparse
import csv
import importlib.util
import html
import json
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path


SCHEMA_VERSION = "kv-cache-trace/v1"
DEFAULT_DEMO_OUTPUT = "/tmp/kv-cache-observatory.html"


def repo_root() -> Path:
    return Path(__file__).resolve().parents[2]


def demo_trace() -> dict:
    requests = [
        {"id": "request-a", "label": "Request A", "prompt_tokens": 2048, "max_tokens": 200},
        {"id": "request-b", "label": "Request B", "prompt_tokens": 2048, "max_tokens": 200},
        {"id": "request-c", "label": "Request C", "prompt_tokens": 2048, "max_tokens": 200},
    ]
    events = [
        {"time_seconds": 0, "type": "request_start", "request_id": "request-a", "blocks": [], "source": "derived"},
        {"time_seconds": 2, "type": "block_allocated", "request_id": "request-a", "blocks": [1, 2, 3, 4], "source": "derived"},
        {"time_seconds": 8, "type": "request_start", "request_id": "request-b", "blocks": [], "source": "derived"},
        {"time_seconds": 10, "type": "block_reused", "request_id": "request-b", "blocks": [1, 2, 3], "source": "derived"},
        {"time_seconds": 12, "type": "block_allocated", "request_id": "request-b", "blocks": [5], "source": "derived"},
        {"time_seconds": 18, "type": "request_start", "request_id": "request-c", "blocks": [], "source": "derived"},
        {"time_seconds": 20, "type": "block_reused", "request_id": "request-c", "blocks": [1, 2], "source": "derived"},
        {"time_seconds": 22, "type": "block_allocated", "request_id": "request-c", "blocks": [6, 7], "source": "derived"},
        {"time_seconds": 36, "type": "block_freed", "request_id": "request-a", "blocks": [4], "source": "derived"},
        {"time_seconds": 44, "type": "block_evicted", "request_id": "request-a", "blocks": [4], "source": "derived"},
        {"time_seconds": 48, "type": "request_finish", "request_id": "request-a", "blocks": [], "source": "derived"},
        {"time_seconds": 56, "type": "request_finish", "request_id": "request-b", "blocks": [], "source": "derived"},
        {"time_seconds": 64, "type": "request_finish", "request_id": "request-c", "blocks": [], "source": "derived"},
    ]
    return {
        "schema_version": SCHEMA_VERSION,
        "run": {
            "experiment": "kv-cache-observatory",
            "case": "shared-system-prompt",
            "profile": "modern-vllm-0221",
            "source": "derived",
        },
        "block_size": 16,
        "total_blocks": 16,
        "requests": requests,
        "events": events,
        "summary": summarize_trace(events, total_blocks=16),
    }


def summarize_trace(events: list[dict], total_blocks: int | None = None) -> dict:
    active_blocks = set()
    reused_events = 0
    allocated_events = 0
    evictions = 0
    for event in events:
        event_type = event.get("type")
        blocks = set(event.get("blocks", []))
        if event_type in ("block_allocated", "block_reused"):
            active_blocks.update(blocks)
        elif event_type in ("block_freed", "block_evicted"):
            active_blocks.difference_update(blocks)
        if event_type == "block_reused":
            reused_events += len(blocks)
        elif event_type == "block_allocated":
            allocated_events += len(blocks)
        elif event_type == "block_evicted":
            evictions += len(blocks)

    free_blocks = None if total_blocks is None else max(total_blocks - len(active_blocks), 0)
    hit_total = reused_events + allocated_events
    hit_rate = None if hit_total == 0 else reused_events / hit_total
    return {
        "active_blocks": len(active_blocks),
        "free_blocks": free_blocks,
        "fragmented_blocks": None,
        "cache_hit_blocks": reused_events,
        "cache_miss_blocks": allocated_events,
        "cache_hit_rate": hit_rate,
        "evictions": evictions,
        "reloads": None,
        "source": "derived",
    }


def request_label_map(trace: dict) -> dict[str, str]:
    return {request["id"]: request["label"] for request in trace.get("requests", [])}


def event_color(event_type: str) -> str:
    return {
        "request_start": "#475569",
        "block_allocated": "#2563eb",
        "block_reused": "#059669",
        "block_freed": "#ca8a04",
        "block_evicted": "#dc2626",
        "request_finish": "#64748b",
    }.get(event_type, "#334155")


def render_svg(trace: dict) -> str:
    labels = request_label_map(trace)
    requests = [request["id"] for request in trace.get("requests", [])]
    events = trace.get("events", [])
    max_time = max([event.get("time_seconds", 0) for event in events] + [1])
    width = 960
    left = 150
    top = 42
    row_height = 72
    block_size = 18
    scale = (width - left - 50) / max_time
    height = top + row_height * max(len(requests), 1) + 70
    row_index = {request_id: index for index, request_id in enumerate(requests)}
    lines = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}" role="img" aria-label="KV cache allocation timeline">',
        '<rect width="100%" height="100%" fill="#f8fafc"/>',
        '<text x="24" y="26" font-family="Arial, sans-serif" font-size="18" font-weight="700" fill="#0f172a">KV Cache Observatory Timeline</text>',
    ]
    for request_id in requests:
        y = top + row_index[request_id] * row_height
        lines.append(f'<text x="24" y="{y + 29}" font-family="Arial, sans-serif" font-size="14" fill="#0f172a">{html.escape(labels.get(request_id, request_id))}</text>')
        lines.append(f'<line x1="{left}" y1="{y + 24}" x2="{width - 24}" y2="{y + 24}" stroke="#cbd5e1" stroke-width="1"/>')
    for event in events:
        request_id = event.get("request_id", "")
        y = top + row_index.get(request_id, 0) * row_height
        x = left + event.get("time_seconds", 0) * scale
        color = event_color(event.get("type", ""))
        blocks = event.get("blocks", [])
        if blocks:
            for offset, block_id in enumerate(blocks[:10]):
                bx = x + offset * (block_size + 4)
                lines.append(f'<rect x="{bx:.1f}" y="{y + 8}" width="{block_size}" height="{block_size}" rx="3" fill="{color}"/>')
                lines.append(f'<text x="{bx + block_size / 2:.1f}" y="{y + 22}" font-family="Arial, sans-serif" font-size="9" text-anchor="middle" fill="#ffffff">{block_id}</text>')
        else:
            lines.append(f'<circle cx="{x:.1f}" cy="{y + 17}" r="6" fill="{color}"/>')
        label = event.get("type", "").replace("_", " ")
        lines.append(f'<text x="{x:.1f}" y="{y + 48}" font-family="Arial, sans-serif" font-size="10" fill="#334155">{html.escape(label)}</text>')
    legend_y = height - 34
    legend_items = [
        ("allocated", "block_allocated"),
        ("reused", "block_reused"),
        ("freed", "block_freed"),
        ("evicted", "block_evicted"),
    ]
    for index, (label, event_type) in enumerate(legend_items):
        x = 24 + index * 120
        lines.append(f'<rect x="{x}" y="{legend_y}" width="14" height="14" rx="3" fill="{event_color(event_type)}"/>')
        lines.append(f'<text x="{x + 20}" y="{legend_y + 12}" font-family="Arial, sans-serif" font-size="12" fill="#334155">{label}</text>')
    lines.append("</svg>")
    return "\n".join(lines)


def render_html(trace: dict) -> str:
    summary = trace.get("summary") or summarize_trace(trace.get("events", []), trace.get("total_blocks"))
    svg = render_svg(trace)
    summary_rows = "\n".join(
        f"<tr><th>{html.escape(key.replace('_', ' '))}</th><td>{html.escape(format_value(value))}</td></tr>"
        for key, value in summary.items()
    )
    return f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>KV Cache Observatory</title>
  <style>
    body {{ margin: 0; font-family: Arial, sans-serif; color: #0f172a; background: #f8fafc; }}
    main {{ max-width: 1040px; margin: 0 auto; padding: 32px 20px; }}
    h1 {{ font-size: 28px; margin: 0 0 16px; }}
    .panel {{ background: #ffffff; border: 1px solid #cbd5e1; border-radius: 8px; padding: 16px; margin-bottom: 20px; }}
    table {{ border-collapse: collapse; width: 100%; }}
    th, td {{ border-bottom: 1px solid #e2e8f0; padding: 8px 10px; text-align: left; font-size: 14px; }}
    th {{ width: 260px; color: #334155; }}
    svg {{ max-width: 100%; height: auto; }}
  </style>
</head>
<body>
<main>
  <h1>KV Cache Observatory</h1>
  <section class="panel">{svg}</section>
  <section class="panel">
    <table>
      <tbody>
{summary_rows}
      </tbody>
    </table>
  </section>
</main>
</body>
</html>
"""


def format_value(value) -> str:
    if value is None:
        return "n/a"
    if isinstance(value, float):
        return f"{value:.6f}"
    return str(value)


def write_text(path: str | None, content: str) -> None:
    if path:
        Path(path).write_text(content, encoding="utf-8")
    else:
        sys.stdout.write(content)


def trace_schema_path() -> Path:
    return repo_root() / "schemas" / "kv-cache-trace.v1.json"


def validate_trace(trace: dict) -> list[str]:
    """Check a trace against the checked-in kv-cache-trace schema.

    Shares the validator with the report families so one schema dialect is
    enforced everywhere; a missing validator or schema is reported rather than
    silently skipped.
    """
    validator_path = repo_root() / "scripts" / "lib" / "validate_report.py"
    schema_path = trace_schema_path()
    if not validator_path.exists() or not schema_path.exists():
        return [f"missing trace validator or schema: {validator_path}, {schema_path}"]

    spec = importlib.util.spec_from_file_location("validate_report", validator_path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)

    errors: list[str] = []
    module.validate(trace, json.loads(schema_path.read_text()), "", errors)
    return errors


def write_json(path: str | None, payload: dict) -> None:
    if payload.get("schema_version") == SCHEMA_VERSION:
        errors = validate_trace(payload)
        if errors:
            for message in errors:
                sys.stderr.write(f"trace does not match {trace_schema_path().name}: {message}\n")
            raise SystemExit(1)
    text = json.dumps(payload, indent=2, sort_keys=True) + "\n"
    write_text(path, text)


def load_trace(path: str) -> dict:
    return json.loads(Path(path).read_text(encoding="utf-8"))


def command_demo(args: argparse.Namespace) -> int:
    trace = demo_trace()
    if args.trace:
        write_json(args.trace, trace)
    write_text(args.output, render_html(trace))
    return 0


def command_render(args: argparse.Namespace) -> int:
    trace = load_trace(args.input)
    output = render_svg(trace) if args.format == "svg" else render_html(trace)
    write_text(args.output, output)
    return 0


def prometheus_query(prometheus_url: str, query: str, query_time: str | None = None):
    params = {"query": query}
    if query_time:
        params["time"] = query_time
    url = prometheus_url.rstrip("/") + "/api/v1/query?" + urllib.parse.urlencode(params)
    with urllib.request.urlopen(url, timeout=10) as response:
        payload = json.loads(response.read().decode("utf-8"))
    result = payload.get("data", {}).get("result", [])
    if not result:
        return None
    try:
        value = result[0]["value"][1]
    except (KeyError, IndexError, TypeError):
        return None
    if value in ("NaN", "+Inf", "-Inf"):
        return None
    try:
        return float(value)
    except ValueError:
        return None


def first_prometheus_value(prometheus_url: str, queries: list[str], query_time: str | None = None):
    for query in queries:
        value = prometheus_query(prometheus_url, query, query_time)
        if value is not None:
            return value, query
    return None, None


def command_collect(args: argparse.Namespace) -> int:
    window = args.window
    query_time = args.time
    usage, usage_query = first_prometheus_value(args.prometheus_url, [
        f"avg_over_time((avg(vllm:kv_cache_usage_perc) * 100)[{window}:15s])",
        f"avg_over_time((avg(vllm_kv_cache_usage_perc) * 100)[{window}:15s])",
        f"avg_over_time((avg(vllm:gpu_cache_usage_perc) * 100)[{window}:15s])",
        f"avg_over_time((avg(vllm_gpu_cache_usage_perc) * 100)[{window}:15s])",
    ], query_time)
    active_blocks, active_blocks_query = first_prometheus_value(args.prometheus_url, [
        f"avg_over_time((avg(vllm:kv_cache_active_blocks))[{window}:15s])",
        f"avg_over_time((avg(vllm_kv_cache_active_blocks))[{window}:15s])",
        f"avg_over_time((avg(vllm:gpu_cache_active_blocks))[{window}:15s])",
        f"avg_over_time((avg(vllm_gpu_cache_active_blocks))[{window}:15s])",
    ], query_time)
    free_blocks, free_blocks_query = first_prometheus_value(args.prometheus_url, [
        f"avg_over_time((avg(vllm:kv_cache_free_blocks))[{window}:15s])",
        f"avg_over_time((avg(vllm_kv_cache_free_blocks))[{window}:15s])",
        f"avg_over_time((avg(vllm:gpu_cache_free_blocks))[{window}:15s])",
        f"avg_over_time((avg(vllm_gpu_cache_free_blocks))[{window}:15s])",
    ], query_time)
    fragmented_blocks, fragmented_blocks_query = first_prometheus_value(args.prometheus_url, [
        f"avg_over_time((avg(vllm:kv_cache_fragmented_blocks))[{window}:15s])",
        f"avg_over_time((avg(vllm_kv_cache_fragmented_blocks))[{window}:15s])",
        f"avg_over_time((avg(vllm:gpu_cache_fragmented_blocks))[{window}:15s])",
        f"avg_over_time((avg(vllm_gpu_cache_fragmented_blocks))[{window}:15s])",
    ], query_time)
    hits, hits_query = first_prometheus_value(args.prometheus_url, [
        f"sum(increase(vllm:prefix_cache_hits_total[{window}]))",
        f"sum(increase(vllm_prefix_cache_hits_total[{window}]))",
        f"sum(increase(vllm:prompt_tokens_cached_total[{window}]))",
        f"sum(increase(vllm_prompt_tokens_cached_total[{window}]))",
        f"sum(increase(vllm:gpu_prefix_cache_hits_total[{window}]))",
        f"sum(increase(vllm:gpu_prefix_cache_hits[{window}]))",
        f"sum(increase(vllm_gpu_prefix_cache_hits_total[{window}]))",
    ], query_time)
    queries, queries_query = first_prometheus_value(args.prometheus_url, [
        f"sum(increase(vllm:prefix_cache_queries_total[{window}]))",
        f"sum(increase(vllm_prefix_cache_queries_total[{window}]))",
        f"sum(increase(vllm:prompt_tokens_total[{window}]))",
        f"sum(increase(vllm_prompt_tokens_total[{window}]))",
        f"sum(increase(vllm:gpu_prefix_cache_queries_total[{window}]))",
        f"sum(increase(vllm:gpu_prefix_cache_queries[{window}]))",
        f"sum(increase(vllm_gpu_prefix_cache_queries_total[{window}]))",
    ], query_time)
    misses = None if hits is None or queries is None else max(queries - hits, 0)
    hit_rate = None if hits is None or not queries else hits / queries
    summary = {
        "schema_version": "kv-cache-observability/v1",
        "generated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "window": window,
        "source": "observed" if any(value is not None for value in (usage, active_blocks, free_blocks, fragmented_blocks, hits, queries)) else "unavailable",
        "kv_cache": {
            "kv_memory_utilization_percent": usage,
            "cache_hit_tokens": hits,
            "cache_miss_tokens": misses,
            "cache_hit_rate": hit_rate,
            "active_blocks": active_blocks,
            "free_blocks": free_blocks,
            "fragmented_blocks": fragmented_blocks,
            "evictions": None,
            "reloads": None,
        },
        "queries": {
            "kv_memory_utilization_percent": usage_query,
            "active_blocks": active_blocks_query,
            "free_blocks": free_blocks_query,
            "fragmented_blocks": fragmented_blocks_query,
            "cache_hit_tokens": hits_query,
            "cache_queries": queries_query,
        },
    }
    write_json(args.output, summary)
    return 0


def command_normalize_events(args: argparse.Namespace) -> int:
    payload = json.loads(Path(args.input).read_text(encoding="utf-8"))
    if isinstance(payload, list):
        raw_events = payload
    elif isinstance(payload, dict):
        raw_events = payload.get("events", [])
    else:
        raw_events = []
    events = []
    for index, raw_event in enumerate(raw_events):
        event_type = raw_event.get("type") or raw_event.get("tag") or raw_event.get("__class__")
        if event_type == "BlockStored":
            normalized_type = "block_allocated"
            blocks = raw_event.get("block_hashes", [])
        elif event_type == "BlockRemoved":
            normalized_type = "block_evicted"
            blocks = raw_event.get("block_hashes", [])
        elif event_type == "AllBlocksCleared":
            normalized_type = "block_freed"
            blocks = []
        else:
            continue
        events.append({
            "time_seconds": raw_event.get("time_seconds", index),
            "type": normalized_type,
            "request_id": raw_event.get("request_id", "kv-cache"),
            "blocks": [int(block) for block in blocks],
            "source": "observed",
        })
    request_ids = sorted({event["request_id"] for event in events}) or ["kv-cache"]
    trace = {
        "schema_version": SCHEMA_VERSION,
        "run": {
            "experiment": args.experiment,
            "case": args.case,
            "profile": args.profile,
            "source": "observed",
        },
        "block_size": args.block_size,
        "total_blocks": args.total_blocks,
        "requests": [{"id": request_id, "label": request_id} for request_id in request_ids],
        "events": events,
        "summary": summarize_trace(events, args.total_blocks),
    }
    write_json(args.output, trace)
    return 0


def load_profile_image(experiment: str, profile: str) -> str | None:
    profile_path = repo_root() / "experiments" / experiment / "serving-profiles.csv"
    if not profile_path.exists():
        return None
    with profile_path.open(newline="", encoding="utf-8") as handle:
        for row in csv.DictReader(handle):
            if row.get("profile_id") == profile:
                return resolve_serving_image(row.get("vllm_image")) or load_default_profile_image()
    return None


def load_serving_image_versions() -> dict[str, str]:
    """Read the declared vLLM images from platform/inference/versions.env.

    The file is shell syntax, but it is a flat list of NAME="value" lines, so it
    is parsed directly rather than shelled out to.
    """
    versions_path = repo_root() / "platform" / "inference" / "versions.env"
    versions: dict[str, str] = {}
    if not versions_path.exists():
        return versions
    for line in versions_path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        name, _, value = line.partition("=")
        versions[name.strip()] = value.strip().strip('"').strip("'")
    return versions


def resolve_serving_image(image: str | None) -> str | None:
    """Expand an @VLLM_IMAGE_*@ reference from versions.env."""
    if not image:
        return image
    for name, value in load_serving_image_versions().items():
        image = image.replace(f"@{name}@", value)
    return image


def load_default_profile_image() -> str | None:
    defaults_path = repo_root() / "experiments" / "_profiles" / "serving-defaults.csv"
    if not defaults_path.exists():
        return None
    with defaults_path.open(newline="", encoding="utf-8") as handle:
        for row in csv.DictReader(handle):
            if row.get("profile_id") == "default":
                return resolve_serving_image(row.get("vllm_image")) or None
    return None


def command_preflight(args: argparse.Namespace) -> int:
    image = args.image or load_profile_image(args.experiment, args.profile)
    if not image:
        sys.stderr.write(f"Missing serving profile: {args.experiment}/{args.profile}\n")
        return 1
    expected = load_serving_image_versions().get("VLLM_IMAGE_MODERN")
    if not expected:
        sys.stderr.write("platform/inference/versions.env does not define VLLM_IMAGE_MODERN\n")
        return 1
    if image != expected:
        sys.stderr.write(f"Expected a {expected} image, found: {image}\n")
        return 1
    checked = ["vllm:kv_cache_usage_perc", "vllm:request_queue_time_seconds_bucket", "vllm:request_prefill_time_seconds_bucket"]
    if args.prometheus_url:
        names_url = args.prometheus_url.rstrip("/") + "/api/v1/label/__name__/values"
        with urllib.request.urlopen(names_url, timeout=10) as response:
            payload = json.loads(response.read().decode("utf-8"))
        names = set(payload.get("data", []))
        missing = [name for name in checked if name not in names and name.replace(":", "_") not in names]
        if missing:
            sys.stderr.write("Missing expected vLLM metrics: " + ", ".join(missing) + "\n")
            return 1
    print(f"OK {args.experiment}/{args.profile} uses {image}")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="KV Cache Observatory helper")
    subparsers = parser.add_subparsers(dest="command", required=True)

    demo = subparsers.add_parser("demo", help="render a local Request A/B/C timeline")
    demo.add_argument("--output", default=DEFAULT_DEMO_OUTPUT)
    demo.add_argument("--trace")
    demo.set_defaults(func=command_demo)

    render = subparsers.add_parser("render", help="render a kv-cache-trace/v1 artifact")
    render.add_argument("--input", required=True)
    render.add_argument("--output", required=True)
    render.add_argument("--format", choices=["html", "svg"], default="html")
    render.set_defaults(func=command_render)

    collect = subparsers.add_parser("collect", help="collect aggregate KV cache metrics from Prometheus")
    collect.add_argument("--prometheus-url", required=True)
    collect.add_argument("--window", default="10m")
    collect.add_argument("--time")
    collect.add_argument("--output", required=True)
    collect.set_defaults(func=command_collect)

    normalize = subparsers.add_parser("normalize-events", help="normalize vLLM KV event JSON into kv-cache-trace/v1")
    normalize.add_argument("--input", required=True)
    normalize.add_argument("--output", required=True)
    normalize.add_argument("--experiment", default="kv-cache-observatory")
    normalize.add_argument("--case", default="shared-system-prompt")
    normalize.add_argument("--profile", default="modern-vllm-0221")
    normalize.add_argument("--block-size", type=int, default=16)
    normalize.add_argument("--total-blocks", type=int, default=16)
    normalize.set_defaults(func=command_normalize_events)

    preflight = subparsers.add_parser("preflight", help="verify the modern vLLM profile and optional metric surface")
    preflight.add_argument("--experiment", default="kv-cache-observatory")
    preflight.add_argument("--profile", default="modern-vllm-0221")
    preflight.add_argument("--image")
    preflight.add_argument("--prometheus-url")
    preflight.set_defaults(func=command_preflight)

    return parser


def main(argv: list[str]) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
