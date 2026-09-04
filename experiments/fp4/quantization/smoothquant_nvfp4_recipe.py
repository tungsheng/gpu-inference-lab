from llmcompressor.modifiers.quantization import QuantizationModifier
from llmcompressor.modifiers.smoothquant import SmoothQuantModifier

recipe = [
    SmoothQuantModifier(
        smoothing_strength=0.5,
        ignore=["lm_head"],
    ),
    QuantizationModifier(
        targets="Linear",
        scheme="NVFP4",
        ignore=["lm_head"],
    ),
]
