"""Convert a Hugging Face BERT NER model to a quantized Core ML package.

Usage:
    python ml/convert_bert_ner.py                      # writes PrivacyAI/BertNER.mlpackage
    python ml/convert_bert_ner.py --skip-quantization  # full-precision weights (~420 MB)

The app expects:
  * inputs  `input_ids` and `attention_mask`, int32, shape (1, 128)
  * a single float output with the logits, shape (1, 128, num_labels)
  * the label order printed at the end, which must match
    `EntityRecognizer.labels` in PrivacyAI/Privacy/EntityRecognizer.swift
"""

import argparse
import os
from pathlib import Path

os.environ.setdefault("TOKENIZERS_PARALLELISM", "false")

import coremltools as ct
import numpy as np
import torch
from coremltools.optimize.coreml import OpLinearQuantizerConfig, OptimizationConfig, linear_quantize_weights
from transformers import AutoModelForTokenClassification, AutoTokenizer

REPO_ROOT = Path(__file__).resolve().parent.parent


class StaticShapeWrapper(torch.nn.Module):
    """Feeds BERT fixed position and token-type ids.

    BERT builds these tensors dynamically inside `forward`, which Core ML
    cannot trace reliably. Registering them as buffers makes the graph static.
    """

    def __init__(self, model: torch.nn.Module, max_length: int):
        super().__init__()
        self.model = model
        self.register_buffer("position_ids", torch.arange(max_length).unsqueeze(0))
        self.register_buffer("token_type_ids", torch.zeros((1, max_length), dtype=torch.long))

    def forward(self, input_ids, attention_mask):
        outputs = self.model(
            input_ids=input_ids,
            attention_mask=attention_mask,
            token_type_ids=self.token_type_ids,
            position_ids=self.position_ids,
        )
        return outputs[0]  # logits


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--model", default="dslim/bert-base-NER-uncased")
    parser.add_argument("--max-length", type=int, default=128)
    parser.add_argument("--output", type=Path, default=REPO_ROOT / "PrivacyAI" / "BertNER.mlpackage")
    parser.add_argument("--skip-quantization", action="store_true")
    args = parser.parse_args()

    print(f"Loading {args.model}...")
    tokenizer = AutoTokenizer.from_pretrained(args.model)
    model = AutoModelForTokenClassification.from_pretrained(args.model, torchscript=True, return_dict=False)
    model.eval()

    wrapped = StaticShapeWrapper(model, args.max_length).eval()
    example = tokenizer(
        "my name is john and i live in new york.",
        return_tensors="pt",
        max_length=args.max_length,
        padding="max_length",
        truncation=True,
    )

    print("Tracing...")
    traced = torch.jit.trace(wrapped, (example["input_ids"], example["attention_mask"]), strict=False)

    print("Converting to Core ML...")
    mlmodel = ct.convert(
        traced,
        inputs=[
            ct.TensorType(name="input_ids", shape=(1, args.max_length), dtype=np.int32),
            ct.TensorType(name="attention_mask", shape=(1, args.max_length), dtype=np.int32),
        ],
        convert_to="mlprogram",
        compute_precision=ct.precision.FLOAT32,
    )

    if not args.skip_quantization:
        # int8 weights cut the package from ~420 MB to ~105 MB with no visible accuracy loss.
        print("Quantizing weights to int8...")
        config = OptimizationConfig(global_config=OpLinearQuantizerConfig(mode="linear_symmetric", dtype="int8"))
        mlmodel = linear_quantize_weights(mlmodel, config=config)

    mlmodel.short_description = f"{args.model} token classification (NER)"
    mlmodel.save(str(args.output))
    print(f"Saved {args.output}")

    labels = [model.config.id2label[i] for i in range(len(model.config.id2label))]
    print(f"Label order: {labels}")


if __name__ == "__main__":
    main()
