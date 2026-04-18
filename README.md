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

## Docker (official Docling Serve)

Compose uses the upstream **CPU** image only (no local `build`). Default:
`ghcr.io/docling-project/docling-serve-cpu:latest` ([images](https://github.com/docling-project/docling-serve#container-images)).

```bash
docker compose pull
docker compose up -d
```

The API listens on **port 5001** (mapped to host `HOST_PORT`, default `5001`). See [Docling Serve](https://github.com/docling-project/docling-serve) for the v1 API (e.g. `POST /v1/convert/source`). This is **not** the same as the `POST /convert` multipart API implemented in `main.py` in this repo.

Optional: `export DOCLING_SERVICE_IMAGE=quay.io/docling-project/docling-serve-cpu:latest` before `docker compose pull`.

### Alternative: build this repo’s FastAPI shim

If you need the drop-in `POST /convert` multipart service (e.g. for `report_checking` as documented below):

```bash
docker build -t docling-service .
docker run -p 8001:8000 docling-service
```

> **Note:** That image is large (~4–6 GB) because `docling` pulls `torch`.
> The Dockerfile pre-downloads models during the build so the first request is fast.

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
`report_checking` backend environment **when using this repository’s built
container** (`POST /convert` on port 8000). The official Docling Serve
Compose service uses port **5001** and a different API; use the built shim
above unless the backend is updated for Docling Serve v1.
