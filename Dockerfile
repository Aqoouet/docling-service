ARG PYTHON_IMAGE=python:3.12-slim
FROM ${PYTHON_IMAGE}

WORKDIR /app

# System libs required by Docling's CV stack (even for DOCX-only use cases the
# package links against them at import time).
RUN apt-get update && apt-get install -y --no-install-recommends \
        libgl1 \
        libglib2.0-0 \
        libgomp1 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .

# Install torch CPU-only first from the official PyTorch index.
# The CPU wheel (~260 MB) is smaller than the default CUDA wheel (~530 MB)
# from PyPI and served faster from download.pytorch.org.
# This also avoids pip choosing a CUDA build on a CPU-only host.
# --timeout 600: raise pip's socket read timeout so that large wheels
#   (torch ~260 MB, opencv ~73 MB, scipy ~35 MB) can finish downloading
#   on a slow connection without a ReadTimeoutError.
RUN pip install --no-cache-dir --timeout 600 \
        torch \
        --index-url https://download.pytorch.org/whl/cpu

# Install Docling and FastAPI (torch is already satisfied, so pip won't
# re-download it from PyPI).
RUN pip install --no-cache-dir --timeout 600 -r requirements.txt

# Pre-download Docling models so the first request is fast.
# The models are cached to ~/.cache/docling inside the image.
RUN python - <<'EOF'
from docling.document_converter import DocumentConverter, WordFormatOption
from docling.datamodel.base_models import InputFormat
from docling.pipeline.simple_pipeline import SimplePipeline
# Instantiating the converter triggers model downloads for configured pipelines.
DocumentConverter(
    format_options={InputFormat.DOCX: WordFormatOption(pipeline_cls=SimplePipeline)}
)
print("Docling models ready.")
EOF

COPY . .

EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
