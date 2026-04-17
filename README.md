# docling-service

Lightweight HTTP microservice that converts `.docx` and `.pdf` documents to
structured **DoclingDocument JSON** using [Docling](https://github.com/DS4SD/docling).

Designed to be consumed by the
[report_checking](../report_checking) backend as a drop-in replacement for its
hand-written OOXML parser.

---

## API

### `GET /health`
Liveness probe. Returns `{"status": "ok"}`.

### `POST /convert`
Accepts a `multipart/form-data` upload with a single field **`file`**
(`.docx` or `.pdf`).

Returns a `DoclingDocument` JSON payload:

```json
{
  "schema_name": "DoclingDocument",
  "version": "...",
  "texts": [
    {"self_ref": "#/texts/0", "label": "section_header", "text": "1 Introduction", "level": 1},
    {"self_ref": "#/texts/1", "label": "paragraph", "text": "..."},
    ...
  ],
  "tables": [...],
  "pictures": [...],
  "body": { "children": [...] }
}
```

---

## Running locally

```bash
pip install -r requirements.txt
uvicorn main:app --reload --port 8001
```

Then test with curl:

```bash
curl -F "file=@path/to/report.docx" http://localhost:8001/convert | python -m json.tool | head -60
```

---

## Docker

```bash
docker build -t docling-service .
docker run -p 8001:8000 docling-service
```

> **Note:** The Docker image is large (~4–6 GB) because `docling` pulls
> `torch` as a transitive dependency. Models are pre-downloaded during the
> build so the first request is fast.

---

## Configuration

| Env var | Default | Description |
|---------|---------|-------------|
| `PORT` | `8000` | Uvicorn listen port (when overriding CMD) |

No further configuration is required. For PDF conversion the service uses
Docling's built-in text-layer extraction (no OCR, no GPU required).

---

## Integration with report_checking

Set `USE_DOCLING=true` and `DOCLING_URL=http://docling:8000` in the
`report_checking` backend environment. The backend will send `.docx` files
here before the LLM-based checkpoint pipeline.
