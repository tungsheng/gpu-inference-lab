import http from "k6/http";
import { check } from "k6";
import { Counter } from "k6/metrics";

const experimentName = "@EXPERIMENT_NAME@";
const caseId = "@CASE_ID@";
const promptTokenTarget = @PROMPT_TOKEN_TARGET@;
const maxTokens = @MAX_TOKENS@;
const timeoutSeconds = @TIMEOUT_SECONDS@;
const clientPolicy = "@CLIENT_POLICY_ID@";
const clientMode = "@CLIENT_MODE@";
const bufferCapacityRequests = @CLIENT_BUFFER_CAPACITY_REQUESTS@;
const maxQueueWaitSeconds = @CLIENT_MAX_QUEUE_WAIT_SECONDS@;
const requestShapes = @REQUEST_SHAPES_JS@;
const completionTokens = new Counter("completion_tokens");

export const options = {
  tags: {
    experiment: experimentName,
    case_id: caseId,
    client_policy: clientPolicy,
    client_mode: clientMode,
  },
  scenarios: {
@K6_SCENARIO@
  },
  thresholds: {
    http_req_failed: ["rate<0.05"],
  },
  summaryTrendStats: ["min", "avg", "med", "p(90)", "p(95)", "p(99)", "max"],
};

const targetUrl = __ENV.TARGET_URL || "@TARGET_URL@";
const modelName = __ENV.MODEL_NAME || "@MODEL_NAME@";

function buildPrompt(targetTokens) {
  const seedWords = [
    "GPU", "inference", "capacity", "planning", "requires", "measuring",
    "KV", "cache", "pressure", "queueing", "latency", "throughput",
    "memory", "headroom", "scheduling", "autoscaling", "recovery",
    "cost", "utilization", "and", "tail", "behavior", "under",
    "controlled", "workloads"
  ];
  const words = [];
  for (let index = 0; index < targetTokens; index += 1) {
    words.push(seedWords[index % seedWords.length]);
  }
  return words.join(" ");
}

function selectRequestShape() {
  const totalWeight = requestShapes.reduce((total, shape) => total + shape.weight, 0);
  let threshold = Math.random() * totalWeight;
  for (const shape of requestShapes) {
    threshold -= shape.weight;
    if (threshold <= 0) {
      return shape;
    }
  }
  return requestShapes[requestShapes.length - 1];
}

export default function () {
  const requestShape = selectRequestShape();
  const payload = JSON.stringify({
    model: modelName,
    prompt: buildPrompt(requestShape.promptTokenTarget),
    max_tokens: requestShape.maxTokens,
    temperature: 0,
  });
  const response = http.post(targetUrl, payload, {
    headers: {
      "Content-Type": "application/json",
    },
    timeout: String(timeoutSeconds) + "s",
    tags: {
      request_shape: requestShape.label,
    },
  });

  check(response, {
    "completion request succeeded": (res) => res.status === 200,
  });

  if (response.status === 200) {
    try {
      const body = response.json();
      const tokens = body && body.usage
        ? Number(body.usage.completion_tokens)
        : NaN;

      if (Number.isFinite(tokens)) {
        completionTokens.add(tokens);
      }
    } catch (_) {
      // Token usage is best-effort because failed or proxy responses may
      // not be OpenAI-compatible JSON.
    }
  }
}

function metricValue(data, metricName, valueName) {
  const metric = data.metrics[metricName];
  if (!metric || !metric.values || metric.values[valueName] === undefined) {
    return "";
  }
  return String(metric.values[valueName]);
}

function secondsFromMilliseconds(value) {
  if (value === "") {
    return "";
  }
  return String(Number(value) / 1000);
}

export function handleSummary(data) {
  const completedRequests = metricValue(data, "http_reqs", "count");
  const failedRate = metricValue(data, "http_req_failed", "rate");
  const droppedIterations = metricValue(data, "dropped_iterations", "count");
  const generatedTokens = metricValue(data, "completion_tokens", "count");
  const generatedTokensPerSecond = metricValue(data, "completion_tokens", "rate");
  const testRunDurationMs = data.state && data.state.testRunDurationMs !== undefined
    ? String(data.state.testRunDurationMs)
    : "";
  const failedRequests = completedRequests === "" || failedRate === ""
    ? ""
    : String(Math.round(Number(completedRequests) * Number(failedRate)));

  return {
    stdout: [
      "GPU_LAB_K6_SUMMARY_BEGIN",
      "completed_requests=" + completedRequests,
      "failed_requests=" + failedRequests,
      "dropped_iterations=" + droppedIterations,
      "buffering_required_requests=" + droppedIterations,
      "generated_tokens=" + generatedTokens,
      "p50_request_latency_seconds=" + secondsFromMilliseconds(metricValue(data, "http_req_duration", "med")),
      "p95_request_latency_seconds=" + secondsFromMilliseconds(metricValue(data, "http_req_duration", "p(95)")),
      "p99_request_latency_seconds=" + secondsFromMilliseconds(metricValue(data, "http_req_duration", "p(99)")),
      "requests_per_second=" + metricValue(data, "http_reqs", "rate"),
      "generation_tokens_per_second=" + generatedTokensPerSecond,
      "run_duration_seconds=" + secondsFromMilliseconds(testRunDurationMs),
      "GPU_LAB_K6_SUMMARY_END",
    ].join("\n") + "\n",
  };
}
