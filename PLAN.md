# inspercidados — Overhaul Plan

**Created:** 2026-05-14
**Goal:** Clean, CRAN-ready package. Simple wrapper around `dataverse`. Three core functions.

---

## Phase 1 — Cleanup ✅

- [x] Delete dev/scratch files, legacy metadata, temp vignette
- [x] Write new `CLAUDE.md`
- [x] Delete `R/utils-metadata.R`, `R/file-readers.R`, `R/dataverse-download.R`
- [x] Replace `inst/aliases.json` with `inst/datasets.json` (richer schema: theme, region, keywords, is_spatial, script_url)

---

## Pending — Manual work by maintainer

### Spatial dataset flags

The `is_spatial` field in `inst/datasets.json` is currently `false` for all
datasets. It must be set to `true` manually for datasets that return `sf`
objects. Once set, `get_dataset()` will warn users who do not have `sf`
installed.

Known or likely spatial datasets (verify before setting):

| alias | reason |
|---|---|
| `alvaras_sp` | building permits with geocoding |
| `censo_setores_sp` | census by spatial sector |
| `densidade_vertical_sp` | density raster/polygons |
| `iptu_verticalizacao_sp` | IPTU joined to spatial units |
| `densidade_imoveis_sp` | spatial join of IPTU + census |
| `faixa_azul_sp` | road segments (linestrings) |
| `sinistros_sp` | point incidents |
| `sinistros_via_sp` | road segments |
| `estacoes_motiva` | metro station points |
| `qualidade_ar_mare` | measurement points (possibly) |
| `temperatura_ar_mare` | measurement points (possibly) |

**Workflow:** open `inst/datasets.json`, find the alias, change
`"is_spatial": false` to `"is_spatial": true`. Running `data-raw/build_registry.R`
again will **preserve** the value.

### Dataset scripts

Add a `script_url` entry in `inst/datasets.json` when a companion R script
is written for a dataset. Scripts live in `inst/scripts/{alias}.R`.

Currently available (analysis scripts):
- [x] `embarques_mensais` → `inst/scripts/embarques_mensais.R`

Currently available (replication scripts):
- [x] `embarques_hora`, `embarques_diarios`, `embarques_mensais`, `embarques_integracao` → `inst/scripts/embarques_process_tables.R`

Still needed (one script per dataset, add as data is confirmed working):
`itbi_sp`, `iptu_sp`, `alvaras_sp`, `pemob_anual`, `pemob_harmonizada`,
`embarques_diarios`, `embarques_hora`, `sinistros_sp`, …

---

## Phase 2 — Core Rewrite

### `inst/datasets.json`

Replace `inst/aliases.json` with a richer registry:

```json
{
  "iptu_sp": {
    "doi": "10.60873/FK2/7IXFPX",
    "title": "IPTU Sao Paulo",
    "description": "Annual property tax records for Sao Paulo municipality.",
    "script_url": "https://raw.githubusercontent.com/portalcidados/inspercidados/main/inst/scripts/iptu_sp.R"
  }
}
```

### `R/utils.R`

Internal helpers only. No exports.

- `insper_server()` — returns `"dataverse.datascience.insper.edu.br"`
- `resolve_dataset(x)` — alias -> DOI, DOI passthrough, URL -> DOI extraction
- `read_registry()` — reads and caches `inst/datasets.json`
- `detect_file_type(filename)` — returns `"csv"`, `"parquet"`, `"gpkg"`, `"xlsx"`, `"tab"`, `"unknown"`
- `read_file(path, type)` — routes to correct reader

### `R/list_datasets.R`

```r
list_datasets(search = NULL)
```

Returns a `tibble` with columns: `alias`, `title`, `description`, `doi`.
Filters by `search` string if provided (grep on title + description).
Data comes from `inst/datasets.json` only — no network call.

### `R/get_dataset.R`

```r
get_dataset(dataset, year = NULL, filename = NULL, file_pattern = NULL, ...)
```

1. Resolve `dataset` to DOI via `resolve_dataset()`
2. Call `dataverse::dataset_files()` to list available files
3. Select file: `filename` > year match > `file_pattern` > single file > error with list
4. Call `dataverse::get_dataframe_by_name()` with appropriate `.f` based on file type
5. Return tibble/sf with a `"doi"` attribute set

For Parquet/GPKG/XLSX, download to `tempfile()` first then read.

### `R/cite_dataset.R`

```r
cite_dataset(dataset, format = c("text", "bibtex", "ris"))
```

1. Resolve to DOI
2. Fetch metadata via `dataverse::get_dataset()`
3. Format citation from metadata fields
4. Return invisibly; print via `cli_inform()`

### `R/get_script.R`

```r
get_script(dataset, open = TRUE)
```

1. Resolve alias via `read_registry()` to get `script_url`
2. If no `script_url` — `cli_abort()` with helpful message
3. Download script to `tempfile(fileext = ".R")`
4. If `open = TRUE` — call `utils::file.edit(path)`
5. Return `path` invisibly

---

## Phase 3 — Tests

- Use `testthat` (>= 3.0.0)
- All network calls wrapped in `skip_if_offline()`
- Unit-test identifier resolution, file type detection, registry parsing without network
- Integration tests for `list_datasets()`, `get_dataset()`, `cite_dataset()` (offline-skippable)

---

## Phase 4 — Documentation & pkgdown

- One vignette: `vignettes/getting-started.Rmd` — install, list, get, cite, get_script
- `_pkgdown.yml` with:
  - Reference section grouping the 4 functions
  - Articles section for the vignette
  - Insper Cidades branding (logo, colors)
- `README.md` updated with badges and quick-start examples

---

## Phase 5 — CRAN Prep

Run `usethis::use_cran_comments()` and address:

- [ ] All examples run without `\dontrun{}` (use `skip_if_offline()` in tests)
- [ ] `R CMD check --as-cran` passes with 0 errors, 0 warnings
- [ ] `urlchecker::url_check()` clean
- [ ] `rhub::check_for_cran()` passes
- [ ] Spell check: `spelling::spell_check_package()`

---

## API Design Decisions

### Why three (or four) functions?

- `list_datasets()` — discovery: what can I get?
- `get_dataset()` — the main action: give me data
- `cite_dataset()` — academic requirement: how do I cite this?
- `get_script()` — bonus: give me the reproducible script

### Why not cache?

Caching adds complexity (cache invalidation, disk management). The `dataverse` package handles
caching internally. Remove the `rappdirs` cache layer unless users ask for it in feedback.

### Heavy dependencies in Suggests

`arrow`, `sf`, `readxl` are large. Move to `Suggests` with `rlang::check_installed()` so
the package installs fast and only pulls in what the user actually needs.
