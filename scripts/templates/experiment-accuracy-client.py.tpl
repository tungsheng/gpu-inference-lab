import json
import os
import subprocess
import sys
from pathlib import Path


experiment_name = "@EXPERIMENT_NAME@"
profile_id = "@PROFILE_ID@"
accuracy_case_id = "@ACCURACY_CASE_ID@"
tasks = "@ACCURACY_TASKS_CSV@"
num_fewshot = "@ACCURACY_NUM_FEWSHOT@"
limit = "@ACCURACY_LIMIT@"
primary_metric = "@ACCURACY_PRIMARY_METRIC@"
target_url = "@TARGET_URL@"
model_name = "@MODEL_NAME@"
output_path = Path(os.environ.get("ACCURACY_OUTPUT_PATH", "/tmp/lm-eval-results.json"))

cmd = [
    "lm_eval",
    "--model",
    "local-completions",
    "--model_args",
    f"model={model_name},base_url={target_url},num_concurrent=1,max_retries=3,tokenized_requests=False",
    "--tasks",
    tasks,
    "--num_fewshot",
    num_fewshot,
    "--limit",
    limit,
    "--output_path",
    str(output_path),
]

print("Running accuracy command:", " ".join(cmd), flush=True)
completed = subprocess.run(cmd, check=False)

results = {}
if output_path.exists():
    try:
        payload = json.loads(output_path.read_text())
        results = payload.get("results", {})
    except json.JSONDecodeError:
        results = {}

print("GPU_LAB_ACCURACY_SUMMARY_BEGIN")
print(f"experiment={experiment_name}")
print(f"profile={profile_id}")
print(f"accuracy_case={accuracy_case_id}")
print(f"tasks={tasks}")
print(f"num_fewshot={num_fewshot}")
print(f"limit={limit}")
print(f"primary_metric={primary_metric}")
for task_name in tasks.split(","):
    task_result = results.get(task_name, {})
    score = task_result.get(primary_metric)
    if score is not None:
        print(f"{task_name}_{primary_metric}={score}")
print("GPU_LAB_ACCURACY_SUMMARY_END")

sys.exit(completed.returncode)
