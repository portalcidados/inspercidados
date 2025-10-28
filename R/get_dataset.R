#' Get dataset from Insper Cidades collection
#'
#' Downloads and loads datasets from the Insper Cidades collection via Dataverse.
#' Data is automatically cached locally to avoid repeated downloads.
#'
#' @param name Character. Dataset name (e.g., "iptu_sp", "itbi_sp", "pemob")
#' @param year Numeric. Year of the dataset (optional for some datasets)
#' @param show_citation Logical. Display citation information after loading?
#' @param force_download Logical. Force re-download even if cached?
#'
#' @return A tibble/data.frame with the requested dataset
#'
#' @examples
#' \dontrun{
#' # Load IPTU data for 2024
#' iptu <- get_dataset("iptu_sp", year = 2024)
#'
#' # Load PEMOB survey data
#' pemob <- get_dataset("pemob")
#'
#' # Load with citation
#' iptu <- get_dataset("iptu_sp", year = 2024, show_citation = TRUE)
#'
#' # Force re-download to get latest version
#' iptu <- get_dataset("iptu_sp", year = 2024, force_download = TRUE)
#' }
#'
#' @export
get_dataset <- function(name,
                       year = NULL,
                       show_citation = FALSE,
                       force_download = FALSE) {

  # Validate dataset request
  validate_dataset_request(name, year)

  # Get metadata
  metadata <- get_metadata(name)

  # Construct cache file path
  cache_dir <- get_cache_dir()
  if (!is.null(year)) {
    file_name <- paste0(name, "_", year, ".parquet")
  } else {
    file_name <- paste0(name, ".parquet")
  }
  file_path <- file.path(cache_dir, file_name)

  # Download if needed
  if (!file.exists(file_path) || force_download) {
    if (force_download && file.exists(file_path)) {
      cli::cli_alert_info("Force download requested, clearing cache")
    }
    cli::cli_h2("Downloading {.val {name}}{if (!is.null(year)) paste0(' (', year, ')')}")
    download_from_dataverse(metadata, year, file_path)
  } else {
    cli::cli_alert_info(
      "Loading cached version of {.val {name}}{if (!is.null(year)) paste0(' (', year, ')')}"
    )
  }

  # Load data
  cli::cli_alert_info("Reading data from {.file {basename(file_path)}}")
  data <- arrow::read_parquet(file_path)

  # Show citation if requested
  if (show_citation) {
    cat("\n")
    print_citation(name, year)
    cat("\n")
  }

  # Add attributes for traceability
  attr(data, "source") <- "inspercidados"
  attr(data, "dataset") <- name
  attr(data, "year") <- year
  attr(data, "download_date") <- file.info(file_path)$mtime
  attr(data, "doi") <- get_doi(metadata, year)

  if (!is.null(metadata$version)) {
    attr(data, "version") <- metadata$version
  }

  cli::cli_alert_success(
    "Loaded {.val {nrow(data)}} rows and {.val {ncol(data)}} columns"
  )

  return(data)
}

#' Get cache directory
#'
#' Returns the cache directory for inspercidados datasets.
#' Can be configured via INSPERCIDADOS_CACHE_DIR environment variable.
#'
#' @return Character. Path to cache directory
#' @noRd
get_cache_dir <- function() {
  # Check for custom cache directory
  custom_dir <- Sys.getenv("INSPERCIDADOS_CACHE_DIR", unset = "")

  if (custom_dir != "" && nzchar(custom_dir)) {
    cache_dir <- custom_dir
  } else {
    # Use standard user cache directory
    cache_dir <- rappdirs::user_cache_dir("inspercidados", "Insper")
  }

  if (!dir.exists(cache_dir)) {
    dir.create(cache_dir, recursive = TRUE)
  }

  return(cache_dir)
}

#' List cached datasets
#'
#' @export
list_cached_datasets <- function() {
  cache_dir <- get_cache_dir()
  files <- list.files(cache_dir, pattern = "\\.parquet$", full.names = TRUE)
  
  if (length(files) == 0) {
    message("No cached datasets found.")
    return(invisible(NULL))
  }
  
  info <- file.info(files)
  data.frame(
    dataset = gsub("\\.parquet$", "", basename(files)),
    size_mb = round(info$size / 1024^2, 2),
    cached_on = info$mtime,
    stringsAsFactors = FALSE
  )
}

#' Clear cache
#'
#' @param dataset Optional. Specific dataset to clear, or NULL for all
#' @export
clear_cache <- function(dataset = NULL) {
  cache_dir <- get_cache_dir()
  
  if (is.null(dataset)) {
    # Clear all
    files <- list.files(cache_dir, pattern = "\\.parquet$", full.names = TRUE)
    if (length(files) > 0) {
      unlink(files)
      message("Cleared ", length(files), " cached dataset(s).")
    }
  } else {
    # Clear specific dataset
    pattern <- paste0("^", dataset, "(_\\d{4})?\\.parquet$")
    files <- list.files(cache_dir, pattern = pattern, full.names = TRUE)
    if (length(files) > 0) {
      unlink(files)
      message("Cleared ", length(files), " cached file(s) for dataset '", dataset, "'.")
    }
  }
}
