#' Get Dataverse server URL
#'
#' Returns the Dataverse server URL, checking environment variable first,
#' then falling back to dataset metadata, then to default.
#'
#' @param metadata List. Dataset metadata (optional)
#'
#' @return Character. Server URL without protocol
#' @noRd
get_dataverse_server <- function(metadata = NULL) {
  # Check environment variable first
  server <- Sys.getenv("DATAVERSE_SERVER", unset = "")

  if (server != "") {
    return(server)
  }

  # Check metadata
  if (!is.null(metadata) && !is.null(metadata$dataverse_server)) {
    return(metadata$dataverse_server)
  }

  # Default to Insper's Dataverse
  return("dataverse.datascience.insper.edu.br")
}


#' Download file from Dataverse
#'
#' Downloads a dataset file from Dataverse using the dataverse package.
#' Handles both single-DOI and multi-DOI structures.
#'
#' @param metadata List. Dataset metadata
#' @param year Numeric. Year (optional, required for yearly datasets)
#' @param file_path Character. Local path where file should be saved
#'
#' @return Invisible NULL on success, stops with error on failure
#' @noRd
download_from_dataverse <- function(metadata, year = NULL, file_path) {
  # Get server, DOI, and filename
  server <- get_dataverse_server(metadata)
  doi <- get_doi(metadata, year)
  filename <- get_dataverse_filename(metadata, year)

  cli::cli_alert_info("Downloading from {.url {server}}")
  cli::cli_alert_info("Dataset DOI: {.val {doi}}")
  cli::cli_alert_info("File: {.file {filename}}")

  # Ensure cache directory exists
  cache_dir <- dirname(file_path)
  if (!dir.exists(cache_dir)) {
    dir.create(cache_dir, recursive = TRUE)
  }

  # Download using dataverse package
  tryCatch({
    # Use get_dataframe_by_name for parquet files
    # The dataverse package will handle caching if version is specified
    raw_data <- dataverse::get_dataframe_by_name(
      filename = filename,
      dataset = doi,
      server = server,
      .f = arrow::read_parquet,  # Use arrow to read parquet format
      original = TRUE  # Get original file, not tab-delimited
    )

    # Save to our cache location
    arrow::write_parquet(raw_data, file_path)

    cli::cli_alert_success(
      "Downloaded {.file {filename}} ({nrow(raw_data)} rows, {ncol(raw_data)} cols)"
    )

    invisible(NULL)

  }, error = function(e) {
    # Provide helpful error message
    msg <- paste0(
      "Failed to download from Dataverse:\n",
      "  Server: ", server, "\n",
      "  DOI: ", doi, "\n",
      "  File: ", filename, "\n",
      "  Error: ", e$message
    )

    # Check if it's an authentication issue
    if (grepl("401|403|unauthorized|forbidden", e$message, ignore.case = TRUE)) {
      msg <- paste0(
        msg, "\n\n",
        "This may be a private dataset. Set your API key:\n",
        "  Sys.setenv(DATAVERSE_KEY = 'your-api-key')"
      )
    }

    # Check if it's a file not found issue
    if (grepl("404|not found", e$message, ignore.case = TRUE)) {
      msg <- paste0(
        msg, "\n\n",
        "File not found in Dataverse. Please check:\n",
        "  1. The DOI is correct in metadata\n",
        "  2. The filename matches what's in Dataverse\n",
        "  3. The dataset has been published"
      )
    }

    stop(msg, call. = FALSE)
  })
}


#' Check if dataset has updates
#'
#' Checks if a newer version of the dataset is available on Dataverse.
#'
#' @param metadata List. Dataset metadata
#' @param year Numeric. Year (optional)
#'
#' @return List with update information
#' @noRd
check_for_updates <- function(metadata, year = NULL) {
  server <- get_dataverse_server(metadata)
  doi <- get_doi(metadata, year)

  tryCatch({
    # Get dataset info from Dataverse
    dataset_info <- dataverse::get_dataset(doi, server = server)

    # Extract version information
    if (!is.null(dataset_info$data$latestVersion)) {
      latest_version <- dataset_info$data$latestVersion$versionNumber
      version_state <- dataset_info$data$latestVersion$versionState

      return(list(
        has_update = TRUE,
        version = latest_version,
        state = version_state,
        message = paste0(
          "Version ", latest_version, " (", version_state, ") ",
          "available on Dataverse"
        )
      ))
    }

    return(list(has_update = FALSE, message = "No version information available"))

  }, error = function(e) {
    # Silently fail - update checking is optional
    return(list(has_update = FALSE, message = paste("Could not check:", e$message)))
  })
}


#' Get dataset information from Dataverse
#'
#' Retrieves comprehensive metadata from Dataverse without downloading data.
#'
#' @param dataset_id Character. Dataset identifier
#' @param year Numeric. Year (optional)
#'
#' @return List with dataset information
#' @export
#'
#' @examples
#' \dontrun{
#' # Get info about a dataset
#' info <- get_dataset_info("pemob")
#' print(info$title)
#' print(info$files)
#' }
get_dataset_info <- function(dataset_id, year = NULL, server = NULL) {
  # Resolve identifier to DOI
  resolved <- resolve_identifier(dataset_id)
  doi <- resolved$doi

  # Get server
  if (is.null(server)) {
    server <- Sys.getenv("DATAVERSE_SERVER", unset = "dataverse.datascience.insper.edu.br")
  }

  cli::cli_alert_info("Fetching info from {.url {server}} for {.val {doi}}")

  tryCatch({
    # Get dataset metadata from Dataverse
    dv_info <- dataverse::get_dataset(doi, server = server)

    # Extract relevant information
    info <- list(
      id = dataset_id,
      doi = doi,
      server = server,
      year = year,
      dataverse_version = dv_info$data$latestVersion$versionNumber %||% "unknown",
      publication_date = dv_info$data$publicationDate %||% "unknown"
    )

    # Extract title from Dataverse metadata if available
    if (!is.null(dv_info$data$latestVersion$metadataBlocks$citation$fields)) {
      title_field <- dv_info$data$latestVersion$metadataBlocks$citation$fields[
        dv_info$data$latestVersion$metadataBlocks$citation$fields$typeName == "title",
      ]
      if (nrow(title_field) > 0) {
        info$title <- title_field$value[1]
      }
    }

    # Get file list if available
    if (!is.null(dv_info$data$latestVersion$files)) {
      info$files <- dv_info$data$latestVersion$files
    }

    cli::cli_alert_success("Retrieved dataset information")

    return(info)

  }, error = function(e) {
    cli::cli_alert_danger("Could not fetch Dataverse info: {e$message}")

    # Return minimal info on error
    return(list(
      id = dataset_id,
      doi = doi,
      server = server,
      year = year,
      error = e$message
    ))
  })
}


#' List files available in a dataset
#'
#' Lists all files available in a Dataverse dataset without downloading them.
#' Useful for exploring multi-file datasets before downloading.
#'
#' @param dataset Character. Dataset identifier (DOI, alias, or metadata ID)
#' @param server Character. Dataverse server URL (optional)
#'
#' @return A data.frame with file information (filename, size, type, etc.)
#' @export
#'
#' @examples
#' \dontrun{
#' # List files using DOI
#' list_files("10.60873/FK2/7IXFPX")
#'
#' # List files using alias
#' list_files("iptu_sp")
#' }
list_files <- function(dataset, server = NULL) {
  # Resolve identifier to DOI
  resolved <- resolve_identifier(dataset)
  doi <- resolved$doi

  # Get server
  if (is.null(server)) {
    server <- Sys.getenv("DATAVERSE_SERVER", unset = "dataverse.datascience.insper.edu.br")
  }

  cli::cli_alert_info("Fetching file list from {.url {server}} for {.val {doi}}")

  tryCatch({
    # Get dataset metadata
    dataset_info <- dataverse::get_dataset(doi, server = server)

    # Extract files
    if (!is.null(dataset_info$data$latestVersion$files)) {
      files <- dataset_info$data$latestVersion$files

      # Clean up and format output
      result <- data.frame(
        filename = files$dataFile$filename %||% files$filename %||% NA,
        size_mb = round((files$dataFile$filesize %||% files$filesize %||% 0) / 1024^2, 2),
        content_type = files$dataFile$contentType %||% files$contentType %||% NA,
        description = files$description %||% NA,
        stringsAsFactors = FALSE
      )

      cli::cli_alert_success("Found {nrow(result)} file(s)")
      return(result)
    } else {
      cli::cli_alert_warning("No files found in dataset")
      return(data.frame(
        filename = character(0),
        size_mb = numeric(0),
        content_type = character(0),
        description = character(0),
        stringsAsFactors = FALSE
      ))
    }

  }, error = function(e) {
    stop(
      "Failed to list files from Dataverse:\n",
      "  Server: ", server, "\n",
      "  DOI: ", doi, "\n",
      "  Error: ", e$message,
      call. = FALSE
    )
  })
}


#' Null-coalescing operator
#' @noRd
`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}
