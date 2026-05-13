from llmcompressor.modifiers.quantization import QuantizationModifier


recipe = [
    QuantizationModifier(
        targets="Linear",
        scheme="NVFP4",
        ignore=["lm_head"],
    ),
]
