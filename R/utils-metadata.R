#' List available datasets
#'
#' Lists datasets available through inspercidados package.
#' Includes datasets with friendly aliases and optionally searches Dataverse.
#'
#' @param search Character. Optional search query to filter datasets (searches Dataverse)
#' @param collection Character. Dataverse collection alias to search (e.g., "insper-cidades")
#' @param server Character. Dataverse server URL (optional)
#' @param include_search Logical. Include Dataverse search results? (default: FALSE)
#'
#' @return A data.frame with columns: alias, doi, title (if include_search=TRUE)
#' @export
#'
#' @examples
#' \dontrun{
#' # List all datasets with aliases
#' list_available_datasets()
#'
#' # Search Dataverse for datasets
#' list_available_datasets(search = "IPTU", include_search = TRUE)
#'
#' # Search specific collection
#' list_available_datasets(collection = "insper-cidades", include_search = TRUE)
#' }
list_available_datasets <- function(search = NULL,
                                   collection = NULL,
                                   server = NULL,
                                   include_search = FALSE) {

  # Always show aliases
  aliases <- get_aliases()

  if (length(aliases) == 0 && !include_search) {
    cli::cli_alert_warning("No dataset aliases found")
    return(data.frame(
      alias = character(0),
      doi = character(0),
      stringsAsFactors = FALSE
    ))
  }

  # Create data frame from aliases
  alias_df <- if (length(aliases) > 0) {
    data.frame(
      alias = names(aliases),
      doi = unlist(aliases, use.names = FALSE),
      stringsAsFactors = FALSE
    )
  } else {
    data.frame(
      alias = character(0),
      doi = character(0),
      stringsAsFactors = FALSE
    )
  }

  # If no search requested, return aliases only
  if (!include_search && is.null(search) && is.null(collection)) {
    return(alias_df)
  }

  # Search Dataverse
  if (is.null(server)) {
    server <- Sys.getenv("DATAVERSE_SERVER", unset = "dataverse.datascience.insper.edu.br")
  }

  tryCatch({
    # Build search query
    query_params <- list(type = "dataset", per_page = 100)

    if (!is.null(search)) {
      query_params$q <- search
    }
    if (!is.null(collection)) {
      query_params$subtree <- collection
    }

    cli::cli_alert_info("Searching Dataverse at {.url {server}}...")

    # Perform search
    results <- do.call(dataverse::dataverse_search, c(query_params, list(server = server)))

    if (is.null(results) || length(results) == 0) {
      cli::cli_alert_warning("No results found in Dataverse")
      return(alias_df)
    }

    # Extract DOIs and titles
    search_df <- data.frame(
      doi = sapply(results, function(x) x$global_id %||% NA),
      title = sapply(results, function(x) x$name %||% NA),
      description = sapply(results, function(x) x$description %||% NA),
      published_at = sapply(results, function(x) x$published_at %||% NA),
      stringsAsFactors = FALSE
    )

    # Clean DOI format (remove "doi:" prefix)
    search_df$doi <- gsub("^doi:", "", search_df$doi, ignore.case = TRUE)

    # Merge with aliases (mark which ones have aliases)
    search_df$alias <- sapply(search_df$doi, function(doi) {
      idx <- which(alias_df$doi == doi)
      if (length(idx) > 0) alias_df$alias[idx[1]] else NA
    })

    # Reorder columns
    search_df <- search_df[, c("alias", "doi", "title", "description", "published_at")]

    cli::cli_alert_success("Found {nrow(search_df)} dataset(s) in Dataverse")

    return(search_df)

  }, error = function(e) {
    cli::cli_alert_warning("Could not search Dataverse: {e$message}")
    cli::cli_alert_info("Returning aliases only")
    return(alias_df)
  })
}


#' Get alias registry
#'
#' Reads the aliases.json file that maps friendly names to DOIs.
#'
#' @return Named list of aliases (name -> DOI)
#' @noRd
get_aliases <- function() {
  alias_file <- system.file("aliases.json", package = "inspercidados")

  if (!file.exists(alias_file) || alias_file == "") {
    # During development, use relative path
    alias_file <- file.path("inst", "aliases.json")
    if (!file.exists(alias_file)) {
      return(list())
    }
  }

  tryCatch({
    aliases <- jsonlite::fromJSON(alias_file, simplifyVector = TRUE)
    return(as.list(aliases))
  }, error = function(e) {
    cli::cli_alert_warning("Could not read aliases.json: {e$message}")
    return(list())
  })
}


#' Check if string is a DOI
#'
#' @param x Character. String to check
#' @return Logical. TRUE if x appears to be a DOI
#' @noRd
is_doi <- function(x) {
  if (!is.character(x) || length(x) != 1) return(FALSE)

  # Check for DOI patterns:
  # - Starts with "10." (standard DOI prefix)
  # - Starts with "doi:" prefix
  grepl("^(doi:)?10\\.", x, ignore.case = TRUE)
}


#' Resolve dataset identifier to DOI
#'
#' Takes a dataset identifier and resolves it to a DOI.
#' Handles: DOI strings, alias names, or metadata IDs (legacy).
#'
#' @param identifier Character. Dataset identifier (DOI, alias, or metadata ID)
#' @return List with: doi, source ("doi", "alias", or "metadata"), identifier
#' @noRd
resolve_identifier <- function(identifier) {
  # Case 1: Already a DOI
  if (is_doi(identifier)) {
    # Normalize DOI format (remove "doi:" prefix if present)
    doi <- sub("^doi:", "", identifier, ignore.case = TRUE)
    return(list(
      doi = doi,
      source = "doi",
      identifier = identifier
    ))
  }

  # Case 2: Check if it's an alias
  aliases <- get_aliases()
  if (identifier %in% names(aliases)) {
    return(list(
      doi = aliases[[identifier]],
      source = "alias",
      identifier = identifier
    ))
  }

  # Case 3: Check if it's a legacy metadata ID
  metadata_dir <- system.file("metadata", package = "inspercidados")
  if (!dir.exists(metadata_dir) || metadata_dir == "") {
    metadata_dir <- file.path("inst", "metadata")
  }

  metadata_file <- file.path(metadata_dir, paste0(identifier, ".json"))
  if (file.exists(metadata_file)) {
    cli::cli_alert_warning(
      "Using legacy metadata file for '{identifier}'. ",
      "Consider adding to aliases.json instead."
    )
    metadata <- get_metadata(identifier)
    return(list(
      doi = metadata$dataverse_doi,
      source = "metadata",
      identifier = identifier,
      metadata = metadata
    ))
  }

  # Case 4: Not found
  stop(
    "Could not resolve identifier '", identifier, "'.\n",
    "Available aliases: ", paste(names(aliases), collapse = ", "), "\n",
    "Available metadata: ", paste(list_available_datasets()$id, collapse = ", "),
    call. = FALSE
  )
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
