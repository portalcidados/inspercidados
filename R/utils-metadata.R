#' List available datasets
#'
#' Scans the metadata directory to list all available datasets.
#'
#' @return A data.frame with columns: id, title, yearly, temporal_coverage
#' @export
#'
#' @examples
#' \dontrun{
#' # List all available datasets
#' list_available_datasets()
#' }
list_available_datasets <- function() {
  metadata_dir <- system.file("metadata", package = "inspercidados")

  if (!dir.exists(metadata_dir) || metadata_dir == "") {
    # During development, use relative path
    metadata_dir <- file.path("inst", "metadata")
    if (!dir.exists(metadata_dir)) {
      cli::cli_alert_warning("No metadata directory found")
      return(data.frame(
        id = character(0),
        title = character(0),
        yearly = logical(0),
        temporal_coverage = character(0),
        stringsAsFactors = FALSE
      ))
    }
  }

  metadata_files <- list.files(metadata_dir, pattern = "\\.json$", full.names = TRUE)

  if (length(metadata_files) == 0) {
    cli::cli_alert_warning("No metadata files found in {.path {metadata_dir}}")
    return(data.frame(
      id = character(0),
      title = character(0),
      yearly = logical(0),
      temporal_coverage = character(0),
      stringsAsFactors = FALSE
    ))
  }

  datasets <- lapply(metadata_files, function(file) {
    tryCatch({
      meta <- jsonlite::fromJSON(file, simplifyVector = TRUE)
      data.frame(
        id = meta$id,
        title = meta$title,
        yearly = isTRUE(meta$yearly),
        temporal_coverage = as.character(meta$temporal_coverage),
        stringsAsFactors = FALSE
      )
    }, error = function(e) {
      cli::cli_alert_warning("Error reading {.file {basename(file)}}: {e$message}")
      NULL
    })
  })

  datasets <- do.call(rbind, Filter(Negate(is.null), datasets))

  if (is.null(datasets) || nrow(datasets) == 0) {
    return(data.frame(
      id = character(0),
      title = character(0),
      yearly = logical(0),
      temporal_coverage = character(0),
      stringsAsFactors = FALSE
    ))
  }

  return(datasets)
}


#' Get metadata for a specific dataset
#'
#' Reads and parses the metadata JSON file for a dataset.
#'
#' @param dataset_id Character. The dataset identifier (e.g., "iptu_sp", "pemob")
#'
#' @return A list containing the dataset metadata
#' @noRd
get_metadata <- function(dataset_id) {
  metadata_dir <- system.file("metadata", package = "inspercidados")

  if (!dir.exists(metadata_dir) || metadata_dir == "") {
    # During development, use relative path
    metadata_dir <- file.path("inst", "metadata")
  }

  metadata_file <- file.path(metadata_dir, paste0(dataset_id, ".json"))

  if (!file.exists(metadata_file)) {
    stop(
      "Metadata file not found for dataset '", dataset_id, "'.\n",
      "Available datasets: ",
      paste(list_available_datasets()$id, collapse = ", "),
      call. = FALSE
    )
  }

  tryCatch({
    metadata <- jsonlite::fromJSON(metadata_file, simplifyVector = TRUE)

    # Validate required fields
    required_fields <- c("id", "title", "dataverse_doi")
    missing_fields <- setdiff(required_fields, names(metadata))

    if (length(missing_fields) > 0) {
      stop(
        "Metadata for '", dataset_id, "' is missing required fields: ",
        paste(missing_fields, collapse = ", "),
        call. = FALSE
      )
    }

    # Set defaults for optional fields
    if (is.null(metadata$yearly)) metadata$yearly <- FALSE
    if (is.null(metadata$structure_type)) {
      metadata$structure_type <- "single_doi"
    }
    if (is.null(metadata$dataverse_server)) {
      metadata$dataverse_server <- "dataverse.insper.edu.br"
    }

    return(metadata)

  }, error = function(e) {
    stop(
      "Error reading metadata for '", dataset_id, "': ", e$message,
      call. = FALSE
    )
  })
}


#' Validate dataset request
#'
#' Checks if the requested dataset and year combination is valid.
#'
#' @param dataset_id Character. Dataset identifier
#' @param year Numeric. Year (optional)
#'
#' @return Invisible NULL if valid, otherwise stops with error
#' @noRd
validate_dataset_request <- function(dataset_id, year = NULL) {
  # Get metadata
  metadata <- get_metadata(dataset_id)

  # Check if dataset requires a year
  if (isTRUE(metadata$yearly)) {
    if (is.null(year)) {
      available_years <- get_available_years(metadata)
      stop(
        "Dataset '", dataset_id, "' requires a year.\n",
        "Available years: ", paste(available_years, collapse = ", "),
        call. = FALSE
      )
    }

    # Validate year is available
    available_years <- get_available_years(metadata)
    if (!year %in% available_years) {
      stop(
        "Year ", year, " not available for dataset '", dataset_id, "'.\n",
        "Available years: ", paste(available_years, collapse = ", "),
        call. = FALSE
      )
    }
  } else {
    if (!is.null(year)) {
      cli::cli_alert_warning(
        "Dataset '", dataset_id, "' does not have yearly versions. ",
        "Ignoring year parameter."
      )
    }
  }

  invisible(NULL)
}


#' Get available years for a dataset
#'
#' Extracts available years from metadata based on structure type.
#'
#' @param metadata List. Dataset metadata
#'
#' @return Numeric vector of available years, or NULL if not yearly
#' @noRd
get_available_years <- function(metadata) {
  if (!isTRUE(metadata$yearly)) {
    return(NULL)
  }

  # Get years based on structure type
  if (metadata$structure_type == "multi_doi" && !is.null(metadata$doi_mapping)) {
    years <- as.numeric(names(metadata$doi_mapping))
  } else if (!is.null(metadata$file_mapping)) {
    years <- as.numeric(names(metadata$file_mapping))
  } else if (!is.null(metadata$available_years)) {
    years <- as.numeric(metadata$available_years)
  } else {
    cli::cli_alert_warning(
      "Dataset marked as yearly but no year information found in metadata"
    )
    return(NULL)
  }

  return(sort(years))
}


#' Get DOI for specific dataset/year
#'
#' Resolves the correct DOI based on dataset structure type.
#'
#' @param metadata List. Dataset metadata
#' @param year Numeric. Year (optional)
#'
#' @return Character. DOI string
#' @noRd
get_doi <- function(metadata, year = NULL) {
  # Multi-DOI structure: each year has its own DOI
  if (metadata$structure_type == "multi_doi" && !is.null(year)) {
    if (!is.null(metadata$doi_mapping)) {
      doi <- metadata$doi_mapping[[as.character(year)]]
      if (is.null(doi)) {
        stop(
          "DOI not found for year ", year, " in doi_mapping",
          call. = FALSE
        )
      }
      return(doi)
    }
  }

  # Single-DOI structure: all years in one dataset
  return(metadata$dataverse_doi)
}


#' Get filename for specific dataset/year
#'
#' Resolves the correct filename based on dataset structure and year.
#'
#' @param metadata List. Dataset metadata
#' @param year Numeric. Year (optional)
#'
#' @return Character. Filename string
#' @noRd
get_dataverse_filename <- function(metadata, year = NULL) {
  # If file_mapping exists, use it
  if (!is.null(metadata$file_mapping) && !is.null(year)) {
    filename <- metadata$file_mapping[[as.character(year)]]
    if (!is.null(filename)) {
      return(filename)
    }
  }

  # Default naming convention
  if (!is.null(year)) {
    return(paste0(metadata$id, "_", year, ".parquet"))
  } else {
    return(paste0(metadata$id, ".parquet"))
  }
}
