#' Download a dataset from Insper Dataverse
#'
#' Downloads a dataset into R as a tibble or `sf` object. The dataset can be
#' identified by its short alias, bare DOI, or full DOI URL.
#'
#' When a dataset contains multiple files, the function selects one
#' automatically using this priority order: RDS > CSV/TSV > other formats.
#' Use `year`, `filename`, or `file_pattern` to override the default selection.
#'
#' @param dataset A dataset identifier. One of:
#'   - A short alias, e.g. `"iptu_sp"` (see [list_datasets()] for all aliases).
#'   - A bare DOI, e.g. `"10.60873/FK2/TOXCRF"`.
#'   - A full DOI URL, e.g. `"https://doi.org/10.60873/FK2/TOXCRF"`.
#' @param year An integer or character year used to filter files when a dataset
#'   contains multiple annual files (e.g. `year = 2023`).
#' @param filename The exact filename to download from the dataset. Overrides
#'   `year` and `file_pattern`.
#' @param file_pattern A regex pattern matched against filenames. Applied after
#'   `year` filtering.
#' @param docs Logical. If `TRUE`, returns a named list with two elements:
#'   `data` (the downloaded tibble/sf object) and `docs`. When the dataset
#'   contains a file whose name starts with `"documentacao"` (e.g.
#'   `"documentacao_iptu.xlsx"`), that file is downloaded and returned as a
#'   tibble. Otherwise `docs` is a named list of metadata fetched from
#'   Dataverse (title, description, authors, DOI, URL, year). Default is
#'   `FALSE`.
#'
#' @return When `docs = FALSE` (default): a [tibble][tibble::tibble] or `sf`
#'   object with the `"doi"` attribute set. When `docs = TRUE`: a named list
#'   with elements `data` and `docs`.
#'
#' @export
#' @examples
#' \dontrun{
#' # By alias
#' iptu <- get_dataset("iptu_sp")
#'
#' # By DOI
#' iptu <- get_dataset("10.60873/FK2/TOXCRF")
#'
#' # By DOI URL
#' iptu <- get_dataset("https://doi.org/10.60873/FK2/TOXCRF")
#'
#' # Filter to a specific year (for multi-year datasets)
#' iptu_2023 <- get_dataset("iptu_sp", year = 2023)
#'
#' # Request a specific file by name
#' geo <- get_dataset("iptu_sp", filename = "iptu_2024.gpkg")
#'
#' # Match files with a regex pattern
#' trips <- get_dataset("pemob_anual", file_pattern = "trips\\.csv$")
#'
#' # Return data together with Dataverse metadata
#' result <- get_dataset("iptu_sp", docs = TRUE)
#' result$data
#' result$docs
#' }
get_dataset <- function(dataset,
                        year         = NULL,
                        filename     = NULL,
                        file_pattern = NULL,
                        docs         = FALSE) {
  doi     <- resolve_dataset(dataset)
  doi_url <- doi_to_url(doi)
  server  <- insper_server()

  # Warn early if the dataset is flagged as spatial and sf is not installed.
  reg <- read_registry()
  if (dataset %in% names(reg) && isTRUE(reg[[dataset]][["is_spatial"]])) {
    if (!rlang::is_installed("sf")) {
      cli::cli_warn(c(
        "Dataset {.val {dataset}} contains spatial data.",
        "i" = "Load {.pkg sf} for full functionality: {.run library(sf)}"
      ))
    }
  }

  cli::cli_inform(c("i" = "Fetching file list for {.val {doi}}"))
  files      <- dataverse::dataset_files(doi_url, server = server)
  file_names <- vapply(files, function(f) f[["label"]], character(1))

  target <- select_dv_file(
    file_names,
    year         = year,
    filename     = filename,
    file_pattern = file_pattern
  )
  ftype <- detect_file_type(target)

  cli::cli_inform(c("i" = "Downloading {.val {target}}"))
  data <- read_dv_file(target, doi_url, server, ftype)
  attr(data, "doi") <- doi

  if (!docs) return(data)

  # Prefer a "documentacao*.xlsx" file in the dataset over Dataverse metadata.
  doc_file <- file_names[
    grepl("^documentacao", file_names, ignore.case = TRUE) &
      tools::file_ext(tolower(file_names)) %in% c("xlsx", "xls")
  ]

  if (length(doc_file) > 0) {
    cli::cli_inform(c("i" = "Loading documentation from {.val {doc_file[[1]]}}"))
    rlang::check_installed("readxl", reason = "to read documentation files")
    raw <- dataverse::get_file_by_name(doc_file[[1]], dataset = doi_url, server = server)
    ext <- tools::file_ext(tolower(doc_file[[1]]))
    tmp <- tempfile(fileext = paste0(".", ext))
    on.exit(unlink(tmp), add = TRUE)
    writeBin(raw, tmp)
    docs_out <- readxl::read_excel(tmp)
  } else {
    cli::cli_inform(c("i" = "Fetching documentation from Dataverse metadata"))
    meta    <- dataverse::get_dataset(doi_url, server = server)
    fields  <- meta$data$latestVersion$metadataBlocks$citation$fields
    docs_out <- list(
      title       = extract_field(fields, "title"),
      description = extract_field(fields, "dsDescriptionValue"),
      authors     = extract_authors(fields),
      doi         = doi,
      url         = paste0("https://doi.org/", doi),
      year        = extract_year(meta)
    )
  }

  list(data = data, docs = docs_out)
}
