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

# Install Docling and FastAPI.  torch CPU-only wheel is pulled transitively by
# docling; set PIP_NO_CACHE_DIR to save layer space.
RUN pip install --no-cache-dir -r requirements.txt

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
