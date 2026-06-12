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

function repeatWords(words, targetTokens) {
  const rendered = [];
  for (let index = 0; index < targetTokens; index += 1) {
    rendered.push(words[index % words.length]);
  }
  return rendered;
}

function buildObservatorySharedPrompt(targetTokens, shapeLabel) {
  const commonPrefixTokens = Math.max(1, Math.floor(targetTokens * 0.75));
  const suffixTokens = Math.max(targetTokens - commonPrefixTokens, 1);
  const prefix = repeatWords([
    "system", "policy", "retrieval", "tools", "memory", "instructions",
    "routing", "analysis", "constraints", "examples", "schema", "context",
  ], commonPrefixTokens);
  const suffix = repeatWords([
    shapeLabel, "user", "task", "specific", "details", "answer",
  ], suffixTokens);
  return prefix.concat(suffix).join(" ");
}

function buildObservatoryAgentPrompt(targetTokens, shapeLabel) {
  const sharedTokens = Math.max(1, Math.floor(targetTokens * 0.65));
  const workflowTokens = Math.max(targetTokens - sharedTokens, 1);
  const shared = repeatWords([
    "system", "developer", "tool", "browser", "calendar", "mail",
    "state", "memory", "plan", "scratchpad", "observation", "policy",
  ], sharedTokens);
  const workflow = repeatWords([
    shapeLabel, "step", "call", "result", "reflection", "next",
  ], workflowTokens);
  return shared.concat(workflow).join(" ");
}

function buildObservatoryMissStormPrompt(targetTokens, shapeLabel) {
  const uniquePrefixTokens = Math.min(Math.max(64, Math.floor(targetTokens * 0.20)), targetTokens);
  const stableSuffixTokens = Math.max(targetTokens - uniquePrefixTokens, 0);
  const uniqueSeed = String(__VU) + "-" + String(__ITER) + "-" + String(Math.random());
  const unique = repeatWords([
    "miss", "storm", uniqueSeed, shapeLabel, "nonce",
  ], uniquePrefixTokens);
  const suffix = repeatWords(["the"], stableSuffixTokens);
  return unique.concat(suffix).join(" ");
}

function buildPrompt(targetTokens, shapeLabel) {
  if (experimentName === "kv-cache-observatory" && caseId === "shared-system-prompt") {
    return buildObservatorySharedPrompt(targetTokens, shapeLabel);
  }
  if (experimentName === "kv-cache-observatory" && caseId === "agent-workflow") {
    return buildObservatoryAgentPrompt(targetTokens, shapeLabel);
  }
  if (experimentName === "kv-cache-observatory" && caseId === "cache-miss-storm") {
    return buildObservatoryMissStormPrompt(targetTokens, shapeLabel);
  }

  const tokenLikeWord = "the";
  const words = [];
  for (let index = 0; index < targetTokens; index += 1) {
    words.push(tokenLikeWord);
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
    prompt: buildPrompt(requestShape.promptTokenTarget, requestShape.label),
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

function counterValue(data, metricName) {
  const value = metricValue(data, metricName, "count");
  return value === "" ? "0" : value;
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
  const droppedIterations = counterValue(data, "dropped_iterations");
  const interruptedIterations = counterValue(data, "interrupted_iterations");
  const bufferingRequiredRequests = String(Number(droppedIterations) + Number(interruptedIterations));
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
      "interrupted_iterations=" + interruptedIterations,
      "buffering_required_requests=" + bufferingRequiredRequests,
      "generated_tokens=" + generatedTokens,
      "p50_request_latency_seconds=" + secondsFromMilliseconds(metricValue(data, "http_req_duration", "med")),
      "p95_request_latency_seconds=" + secondsFromMilliseconds(metricValue(data, "http_req_duration", "p(95)")),
      "p99_request_latency_seconds=" + secondsFromMilliseconds(metricValue(data, "http_req_duration", "p(99)")),
      "p50_client_waiting_seconds=" + secondsFromMilliseconds(metricValue(data, "http_req_waiting", "med")),
      "p95_client_waiting_seconds=" + secondsFromMilliseconds(metricValue(data, "http_req_waiting", "p(95)")),
      "p99_client_waiting_seconds=" + secondsFromMilliseconds(metricValue(data, "http_req_waiting", "p(99)")),
      "p95_client_blocked_seconds=" + secondsFromMilliseconds(metricValue(data, "http_req_blocked", "p(95)")),
      "p95_client_connecting_seconds=" + secondsFromMilliseconds(metricValue(data, "http_req_connecting", "p(95)")),
      "p95_client_tls_handshaking_seconds=" + secondsFromMilliseconds(metricValue(data, "http_req_tls_handshaking", "p(95)")),
      "p95_client_sending_seconds=" + secondsFromMilliseconds(metricValue(data, "http_req_sending", "p(95)")),
      "p95_client_receiving_seconds=" + secondsFromMilliseconds(metricValue(data, "http_req_receiving", "p(95)")),
      "requests_per_second=" + metricValue(data, "http_reqs", "rate"),
      "generation_tokens_per_second=" + generatedTokensPerSecond,
      "run_duration_seconds=" + secondsFromMilliseconds(testRunDurationMs),
      "GPU_LAB_K6_SUMMARY_END",
    ].join("\n") + "\n",
  };
}
