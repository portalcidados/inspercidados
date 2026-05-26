library(readxl)
library(jsonlite)

# Ensure UTF-8 locale so non-ASCII characters survive JSON serialisation.
# (Rscript may default to the "C" locale on some systems.)
tryCatch(Sys.setlocale("LC_ALL", "en_US.UTF-8"), error = function(e) NULL)

df <- read_excel("data-raw/202603_Catalogo_Dados.xlsx", sheet = 1, skip = 1)
names(df)[c(2, 3, 4, 5, 6, 12, 13, 14)] <- c(
  "colecao", "subcolecao", "tema", "regiao", "acesso", "titulo", "descricao", "link"
)
kw_cols <- 7:11

# Keep only rows with a Dataverse DOI
df <- df[grepl("doi:10[.]60873", df$link), ]

# Extract bare DOI
df$doi <- sub(".*doi:(10[.]60873/[^&]+).*", "\\1", df$link)

# Clean a text field: collapse line breaks, normalise whitespace, ensure UTF-8.
clean_text <- function(x) {
  if (is.na(x)) return(NA_character_)
  x <- enc2utf8(as.character(x))
  x <- gsub("\r\n|\n|\r", " ", x)
  x <- gsub("\\s{2,}", " ", x)
  trimws(x)
}
df$descricao <- vapply(df$descricao, clean_text, character(1))

# Combine keyword columns into a single "; "-separated string
build_keywords <- function(row) {
  kws <- as.character(unlist(row[kw_cols]))
  kws <- kws[!is.na(kws) & nzchar(kws)]
  if (length(kws) == 0) return(NA_character_)
  paste(kws, collapse = "; ")
}
df$keywords <- apply(df, 1, build_keywords)

# Aliases — hand-assigned based on Portuguese titles
aliases <- c(
  "itbi_sp",
  "iptu_sp",
  "alvaras_sp",
  "censo_setores_sp",
  "densidade_vertical_sp",
  "iptu_verticalizacao_sp",
  "densidade_imoveis_sp",
  "geoses_sp",
  "mortalidade_sp",
  "ubs_sp",
  "qualidade_ar_mare",
  "temperatura_ar_mare",
  "pemob_anual",
  "pemob_harmonizada",
  "embarques_hora",
  "embarques_diarios",
  "embarques_mensais",
  "embarques_integracao",
  "estacoes_motiva",
  "faixa_azul_sp",
  "sinistros_sp",
  "sinistros_via_sp"
)

stopifnot(length(aliases) == nrow(df))

# Load the existing registry so manually-set fields (is_spatial, script_url)
# are preserved across rebuilds — they are not derivable from the Excel sheet.
existing <- tryCatch(read_json("inst/datasets.json"), error = function(e) list())

# Build registry list
registry <- setNames(
  lapply(seq_len(nrow(df)), function(i) {
    alias <- aliases[i]
    prev  <- existing[[alias]]
    list(
      doi         = df$doi[i],
      title       = df$titulo[i],
      description = df$descricao[i],
      theme       = clean_text(df$tema[i]),
      region      = clean_text(df$regiao[i]),
      keywords    = df$keywords[i],
      is_spatial      = isTRUE(prev[["is_spatial"]]),       # preserve manual flag
      script_url      = prev[["script_url"]] %||% NULL,    # preserve manual URL
      replication_url = prev[["replication_url"]] %||% NULL # preserve manual URL
    )
  }),
  aliases
)

json <- toJSON(registry, pretty = TRUE, auto_unbox = TRUE, null = "null")
writeLines(json, "inst/datasets.json")
cat("Written inst/datasets.json with", length(registry), "datasets.\n")

for (alias in names(registry)) {
  spatial_flag <- if (isTRUE(registry[[alias]]$is_spatial)) " [spatial]" else ""
  script_flag  <- if (!is.null(registry[[alias]]$script_url)) " [script]" else ""
  cat(sprintf("  %-30s %s%s%s\n",
    alias, registry[[alias]]$doi, spatial_flag, script_flag))
}

`%||%` <- function(x, y) if (is.null(x)) y else x
