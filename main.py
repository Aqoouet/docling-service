"""Docling Service — converts DOCX/PDF to structured DoclingDocument JSON.

Single responsibility: receive a file upload, convert it with Docling,
return the DoclingDocument as JSON. All mapping to application-specific
models happens in the calling service (report_checking backend).
"""

from __future__ import annotations

import os
import tempfile
from pathlib import Path

from docling.document_converter import DocumentConverter, WordFormatOption, PdfFormatOption
from docling.datamodel.base_models import InputFormat
from docling.datamodel.pipeline_options import PdfPipelineOptions
from docling.pipeline.simple_pipeline import SimplePipeline
from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.responses import JSONResponse

# ---------------------------------------------------------------------------
# Converter initialisation — done once at startup
# ---------------------------------------------------------------------------

_PDF_PIPELINE_OPTIONS = PdfPipelineOptions(do_ocr=False, do_table_structure=True)

_converter = DocumentConverter(
    format_options={
        # DOCX: lightweight rule-based pipeline, no ML models required
        InputFormat.DOCX: WordFormatOption(pipeline_cls=SimplePipeline),
        # PDF: full pipeline without OCR (text-based PDFs only)
        InputFormat.PDF: PdfFormatOption(pipeline_options=_PDF_PIPELINE_OPTIONS),
    }
)

# ---------------------------------------------------------------------------
# App
# ---------------------------------------------------------------------------

app = FastAPI(
    title="Docling Service",
    description="Converts DOCX/PDF documents to structured DoclingDocument JSON.",
    version="1.0.0",
)

_SUPPORTED_EXTENSIONS = {".docx", ".pdf"}


@app.get("/health")
def health() -> dict:
    return {"status": "ok"}


@app.post("/convert")
async def convert(file: UploadFile = File(...)) -> JSONResponse:
    """Convert an uploaded DOCX or PDF file to DoclingDocument JSON.

    Returns the full ``DoclingDocument.export_to_dict()`` payload which
    includes ``texts``, ``tables``, ``pictures``, and the document body tree.
    """
    filename = file.filename or "upload"
    suffix = Path(filename).suffix.lower()
    if suffix not in _SUPPORTED_EXTENSIONS:
        raise HTTPException(
            status_code=400,
            detail=f"Unsupported file type '{suffix}'. Supported: {sorted(_SUPPORTED_EXTENSIONS)}",
        )

    content = await file.read()
    if not content:
        raise HTTPException(status_code=400, detail="Uploaded file is empty.")

    # Write to a temp file so Docling can open it by path
    with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
        tmp.write(content)
        tmp_path = tmp.name

    try:
        result = _converter.convert(tmp_path)
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Conversion failed: {exc}") from exc
    finally:
        try:
            os.unlink(tmp_path)
        except OSError:
            pass

    doc_dict = result.document.export_to_dict()
    return JSONResponse(content=doc_dict)
