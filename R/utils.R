# Internal helpers — not exported

.ext_map <- c(
  rds = "rds",
  csv = "csv",
  tab = "tab",
  tsv = "tab",
  parquet = "parquet",
  pq = "parquet",
  gpkg = "gpkg",
  xlsx = "xlsx",
  xls = "xlsx",
  zip = "zip"
)

# Inner extension (after stripping .gz) -> file type
.gz_ext_map <- c(csv = "csv_gz", tab = "tab_gz", tsv = "tab_gz")

insper_server <- function() {
  "dataverse.datascience.insper.edu.br"
}

read_registry <- function() {
  path <- system.file("datasets.json", package = "inspercidados")
  if (!nzchar(path)) {
    cli::cli_abort(
      "Package data registry not found. Try reinstalling the package."
    )
  }
  reg <- jsonlite::read_json(path)
  # jsonlite decodes \uXXXX escapes but leaves strings marked "unknown".
  # Explicitly tag each string as UTF-8 so R displays them correctly in any locale.
  lapply(reg, function(entry) {
    lapply(entry, function(v) {
      if (is.character(v)) {
        Encoding(v) <- "UTF-8"
        v
      } else {
        v
      }
    })
  })
}

#' @noRd
resolve_dataset <- function(x) {
  if (grepl("^https?://", x)) {
    m <- regmatches(x, regexpr("10\\.60873/[A-Z0-9/]+", x, perl = TRUE))
    if (length(m) == 0 || !nzchar(m)) {
      cli::cli_abort("Could not extract a DOI from the URL {.url {x}}.")
    }
    return(m)
  }
  if (grepl("^10\\.", x)) {
    return(x)
  }

  reg <- read_registry()
  if (!x %in% names(reg)) {
    cli::cli_abort(c(
      "Dataset {.val {x}} not found.",
      "i" = "Run {.run inspercidados::list_datasets()} to see available datasets.",
      "i" = "You can also pass a DOI directly, e.g. {.val \"10.60873/FK2/TOXCRF\"}."
    ))
  }
  reg[[x]][["doi"]]
}

doi_to_url <- function(doi) {
  paste0("https://doi.org/", doi)
}

detect_file_type <- function(filename) {
  ext <- tolower(tools::file_ext(filename))
  if (ext == "gz") {
    inner <- tolower(tools::file_ext(sub(
      "\\.gz$",
      "",
      filename,
      ignore.case = TRUE
    )))
    return(.gz_ext_map[[inner]] %||% "gz")
  }
  .ext_map[[ext]] %||% "unknown"
}

# Vectorised: returns the effective (innermost) extension for each filename.
effective_ext <- function(filenames) {
  vapply(
    filenames,
    function(f) {
      ext <- tolower(tools::file_ext(f))
      if (ext == "gz") {
        return(tolower(tools::file_ext(sub(
          "\\.gz$",
          "",
          f,
          ignore.case = TRUE
        ))))
      }
      ext
    },
    character(1),
    USE.NAMES = FALSE
  )
}

# Select a file from those available in the dataset.
# Priority (when no explicit selector is given): RDS > CSV/TSV > everything else.
select_dv_file <- function(
  file_names,
  year = NULL,
  filename = NULL,
  file_pattern = NULL
) {
  if (!is.null(filename)) {
    if (!filename %in% file_names) {
      cli::cli_abort(c(
        "File {.val {filename}} not found in this dataset.",
        "i" = "Available files: {.val {file_names}}"
      ))
    }
    return(filename)
  }

  data_exts <- c(
    "rds",
    "csv",
    "tab",
    "tsv",
    "gz",
    "parquet",
    "pq",
    "gpkg",
    "xlsx",
    "xls",
    "zip"
  )
  candidates <- file_names[
    effective_ext(file_names) %in%
      data_exts |
      tools::file_ext(tolower(file_names)) %in% data_exts
  ]

  if (length(candidates) == 0) {
    cli::cli_abort(c(
      "No data files found in this dataset.",
      "i" = "All files: {.val {file_names}}"
    ))
  }

  if (!is.null(year)) {
    m <- grepl(as.character(year), candidates)
    if (any(m)) candidates <- candidates[m]
  }

  if (!is.null(file_pattern)) {
    m <- grepl(file_pattern, candidates, perl = TRUE)
    if (any(m)) candidates <- candidates[m]
  }

  if (length(candidates) == 0) {
    cli::cli_abort(c(
      "No files matched the given criteria.",
      "i" = "Available data files: {.val {file_names}}"
    ))
  }

  if (length(candidates) == 1) {
    return(candidates)
  }

  # Multiple candidates — apply default priority: RDS first, then CSV/TSV.
  rds <- candidates[tools::file_ext(tolower(candidates)) == "rds"]
  if (length(rds) > 0) {
    if (length(rds) > 1) {
      cli::cli_warn("Multiple RDS files found; using {.val {rds[[1]]}}.")
    }
    return(rds[[1]])
  }

  tabular <- candidates[effective_ext(candidates) %in% c("csv", "tab", "tsv")]
  if (length(tabular) > 0) {
    if (length(tabular) > 1) {
      cli::cli_warn(c(
        "Multiple tabular files found; using {.val {tabular[[1]]}}.",
        "i" = "Use {.arg filename} or {.arg file_pattern} to select a specific file.",
        "i" = "Matched files: {.val {tabular}}"
      ))
    }
    return(tabular[[1]])
  }

  cli::cli_warn(c(
    "Multiple files found; using {.val {candidates[[1]]}}.",
    "i" = "Use {.arg filename}, {.arg year}, or {.arg file_pattern} to be specific.",
    "i" = "Available files: {.val {candidates}}"
  ))
  candidates[[1]]
}

.readers <- list(
  rds = function(filename, doi_url, server) {
    raw <- dataverse::get_file_by_name(
      filename,
      dataset = doi_url,
      server = server
    )
    tmp <- tempfile(fileext = ".rds")
    on.exit(unlink(tmp), add = TRUE)
    writeBin(raw, tmp)
    readRDS(tmp)
  },
  csv = function(filename, doi_url, server) {
    dataverse::get_dataframe_by_name(
      filename,
      dataset = doi_url,
      server = server,
      original = TRUE,
      .f = function(x) readr::read_delim(x, delim = ",", show_col_types = FALSE)
    )
  },
  tab = function(filename, doi_url, server) {
    dataverse::get_dataframe_by_name(
      filename,
      dataset = doi_url,
      server = server,
      original = TRUE,
      .f = function(x) {
        readr::read_delim(x, delim = "\t", show_col_types = FALSE)
      }
    )
  },
  csv_gz = function(filename, doi_url, server) {
    raw <- dataverse::get_file_by_name(
      filename,
      dataset = doi_url,
      server = server
    )
    tmp <- tempfile(fileext = ".csv.gz")
    on.exit(unlink(tmp), add = TRUE)
    writeBin(raw, tmp)
    readr::read_delim(tmp, delim = ",", show_col_types = FALSE)
  },
  tab_gz = function(filename, doi_url, server) {
    raw <- dataverse::get_file_by_name(
      filename,
      dataset = doi_url,
      server = server
    )
    tmp <- tempfile(fileext = ".tsv.gz")
    on.exit(unlink(tmp), add = TRUE)
    writeBin(raw, tmp)
    readr::read_delim(tmp, delim = "\t", show_col_types = FALSE)
  },
  parquet = function(filename, doi_url, server) {
    rlang::check_installed("arrow", reason = "to read Parquet (.parquet) files")
    raw <- dataverse::get_file_by_name(
      filename,
      dataset = doi_url,
      server = server
    )
    tmp <- tempfile(fileext = ".parquet")
    on.exit(unlink(tmp), add = TRUE)
    writeBin(raw, tmp)
    arrow::read_parquet(tmp)
  },
  gpkg = function(filename, doi_url, server) {
    rlang::check_installed("sf", reason = "to read GeoPackage (.gpkg) files")
    raw <- dataverse::get_file_by_name(
      filename,
      dataset = doi_url,
      server = server
    )
    tmp <- tempfile(fileext = ".gpkg")
    on.exit(unlink(tmp), add = TRUE)
    writeBin(raw, tmp)
    sf::st_read(tmp, quiet = TRUE)
  },
  xlsx = function(filename, doi_url, server) {
    rlang::check_installed(
      "readxl",
      reason = "to read Excel (.xlsx/.xls) files"
    )
    raw <- dataverse::get_file_by_name(
      filename,
      dataset = doi_url,
      server = server
    )
    tmp <- tempfile(fileext = ".xlsx")
    on.exit(unlink(tmp), add = TRUE)
    writeBin(raw, tmp)
    readxl::read_excel(tmp)
  },
  xls = function(filename, doi_url, server) {
    rlang::check_installed(
      "readxl",
      reason = "to read Excel (.xlsx/.xls) files"
    )
    raw <- dataverse::get_file_by_name(
      filename,
      dataset = doi_url,
      server = server
    )
    tmp <- tempfile(fileext = ".xls")
    on.exit(unlink(tmp), add = TRUE)
    writeBin(raw, tmp)
    readxl::read_excel(tmp)
  }
)

read_dv_file <- function(filename, doi_url, server, ftype) {
  reader <- .readers[[ftype]]
  if (is.null(reader)) {
    cli::cli_abort(c(
      "Unsupported file type {.val {ftype}} for {.val {filename}}.",
      "i" = "Supported types: rds, csv, tab/tsv, parquet, gpkg, xlsx."
    ))
  }
  reader(filename, doi_url, server)
}

# Null-coalescing operator
`%||%` <- function(x, y) if (is.null(x)) y else x
