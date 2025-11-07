#' Get dataset from Insper Cidades collection
#'
#' Downloads and loads datasets from the Insper Cidades collection via Dataverse.
#' Data is automatically cached locally to avoid repeated downloads.
#'
#' Supports multiple file formats:
#' - CSV files (standalone or in ZIP archives)
#' - Parquet files (standalone or in ZIP archives)
#' - GeoPackage files (GPKG) for spatial data
#' - Excel files (XLSX)
#' - ZIP archives containing any of the above
#'
#' Accepts multiple identifier types:
#' - DOI (e.g., "10.60873/FK2/7IXFPX" or "doi:10.60873/FK2/7IXFPX")
#' - Friendly alias (e.g., "iptu_sp", "pemob", "itbi_sp")
#' - Legacy metadata ID (for backward compatibility)
#'
#' @param name Character. Dataset identifier (DOI, alias, or metadata ID)
#' @param year Numeric. Year of the dataset (optional, used for filename matching)
#' @param filename Character. Specific filename to download if dataset has multiple files
#' @param file_pattern Character. Regex pattern to match files (useful for ZIP archives)
#' @param file_type Character. Expected file type: "csv", "parquet", "gpkg", "xlsx" (optional)
#' @param show_citation Logical. Display citation information after loading?
#' @param force_download Logical. Force re-download even if cached?
#' @param server Character. Dataverse server URL (optional, defaults to env var or Insper)
#'
#' @return A tibble (for CSV/Parquet/XLSX) or sf object (for GPKG)
#'
#' @examples
#' \dontrun{
#' # Using friendly alias
#' data <- get_dataset("iptu_sp")
#'
#' # Using DOI directly
#' data <- get_dataset("10.60873/FK2/7IXFPX")
#'
#' # Specify year for filename matching
#' data_2024 <- get_dataset("mobility", year = 2024)
#'
#' # Select specific file from ZIP using pattern
#' trips <- get_dataset("mobility", file_pattern = "trips\\.csv$")
#'
#' # Specify file type for better detection
#' spatial <- get_dataset("boundaries", file_type = "gpkg")
#'
#' # Load with citation
#' data <- get_dataset("iptu_sp", show_citation = TRUE)
#'
#' # Force re-download to get latest version
#' data <- get_dataset("iptu_sp", force_download = TRUE)
#' }
#'
#' @export
get_dataset <- function(name,
                       year = NULL,
                       filename = NULL,
                       file_pattern = NULL,
                       file_type = NULL,
                       show_citation = FALSE,
                       force_download = FALSE,
                       server = NULL) {

  # Resolve identifier to DOI
  resolved <- resolve_identifier(name)
  doi <- resolved$doi
  identifier_source <- resolved$source

  cli::cli_h2("Loading dataset")
  cli::cli_alert_info("Identifier: {.val {name}} ({identifier_source})")
  cli::cli_alert_info("DOI: {.val {doi}}")

  # Get server
  if (is.null(server)) {
    server <- Sys.getenv("DATAVERSE_SERVER", unset = "dataverse.datascience.insper.edu.br")
  }

  # Get dataset metadata from Dataverse to find available files
  cli::cli_alert_info("Fetching dataset metadata from Dataverse...")
  dataset_info <- tryCatch({
    dataverse::get_dataset(doi, server = server)
  }, error = function(e) {
    stop(
      "Failed to fetch dataset metadata from Dataverse:\n",
      "  DOI: ", doi, "\n",
      "  Server: ", server, "\n",
      "  Error: ", e$message,
      call. = FALSE
    )
  })

  # Extract files
  if (is.null(dataset_info$data$latestVersion$files) ||
      length(dataset_info$data$latestVersion$files) == 0) {
    stop("No files found in dataset ", doi, call. = FALSE)
  }

  files <- dataset_info$data$latestVersion$files

  # Select target file intelligently
  target_file <- select_target_file(
    files = files,
    filename = filename,
    year = year,
    file_pattern = file_pattern,
    identifier = name
  )

  target_filename <- target_file$dataFile$filename
  target_content_type <- target_file$dataFile$contentType %||% NA

  # Detect file type
  detected_type <- detect_file_type(target_filename, target_content_type)
  cli::cli_alert_info("Detected file type: {.strong {detected_type}}")

  # Construct cache file path
  cache_dir <- get_cache_dir()
  cache_filename <- gsub("[^a-zA-Z0-9._-]", "_", target_filename)
  file_path <- file.path(cache_dir, cache_filename)

  # Download if needed
  if (!file.exists(file_path) || force_download) {
    if (force_download && file.exists(file_path)) {
      cli::cli_alert_info("Force download requested, clearing cache")
      unlink(file_path)
    }

    cli::cli_alert_info("Downloading from {.url {server}}")
    cli::cli_alert_info("File: {.file {target_filename}}")

    # Ensure cache directory exists
    if (!dir.exists(cache_dir)) {
      dir.create(cache_dir, recursive = TRUE)
    }

    # Download using dataverse package (raw file download)
    tryCatch({
      # Use get_file for raw download (works for all formats)
      dataverse::get_file(
        file = target_filename,
        dataset = doi,
        server = server,
        original = TRUE
      )

      # Move downloaded file to cache
      temp_file <- target_filename
      if (file.exists(temp_file)) {
        file.rename(temp_file, file_path)
      } else {
        stop("Download succeeded but file not found in working directory")
      }

      cli::cli_alert_success("Downloaded {.file {target_filename}}")

    }, error = function(e) {
      stop(
        "Failed to download from Dataverse:\n",
        "  Server: ", server, "\n",
        "  DOI: ", doi, "\n",
        "  File: ", target_filename, "\n",
        "  Error: ", e$message,
        call. = FALSE
      )
    })
  } else {
    cli::cli_alert_info("Using cached file: {.file {basename(file_path)}}")
  }

  # Read data based on file type
  cli::cli_h3("Reading data")

  data <- tryCatch({
    if (detected_type == "zip") {
      # Handle ZIP archive
      handle_zip_archive(file_path, file_pattern, file_type)
    } else {
      # Handle standalone file
      read_file_auto(file_path, file_type %||% detected_type)
    }
  }, error = function(e) {
    stop(
      "Failed to read file:\n",
      "  File: ", target_filename, "\n",
      "  Type: ", detected_type, "\n",
      "  Error: ", e$message,
      call. = FALSE
    )
  })

  # Show citation if requested
  if (show_citation) {
    cat("\n")
    cite_dataset(name, format = "text")
    cat("\n")
  }

  # Add attributes for traceability
  attr(data, "source") <- "inspercidados"
  attr(data, "dataset") <- name
  attr(data, "doi") <- doi
  attr(data, "filename") <- target_filename
  attr(data, "year") <- year
  attr(data, "download_date") <- file.info(file_path)$mtime

  # Report success
  if (inherits(data, "sf")) {
    cli::cli_alert_success(
      "Loaded spatial data: {.val {nrow(data)}} features, {.val {ncol(data)}} columns"
    )
  } else if (is.data.frame(data)) {
    cli::cli_alert_success(
      "Loaded {.val {nrow(data)}} rows and {.val {ncol(data)}} columns"
    )
  } else if (is.list(data)) {
    cli::cli_alert_success(
      "Loaded list with {.val {length(data)}} objects"
    )
  }

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
