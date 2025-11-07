#' Detect file type from filename and MIME type
#'
#' Determines the file type based on file extension and optionally MIME type.
#' Supports: CSV, Parquet, GeoPackage, XLSX, and ZIP archives.
#'
#' @param filename Character. Name of the file
#' @param content_type Character. MIME type (optional)
#'
#' @return Character. One of: "csv", "parquet", "gpkg", "xlsx", "zip", "unknown"
#' @noRd
detect_file_type <- function(filename, content_type = NULL) {

  # Check MIME type first (more reliable when available)
  if (!is.null(content_type)) {
    content_type_lower <- tolower(content_type)

    if (grepl("zip", content_type_lower)) return("zip")
    if (grepl("csv", content_type_lower)) return("csv")
    if (grepl("parquet", content_type_lower)) return("parquet")
    if (grepl("spreadsheet|excel", content_type_lower)) return("xlsx")
    if (grepl("geopackage|gpkg", content_type_lower)) return("gpkg")
  }

  # Fall back to file extension
  ext <- tolower(tools::file_ext(filename))

  if (ext %in% c("csv", "txt")) return("csv")
  if (ext %in% c("parquet", "pq")) return("parquet")
  if (ext %in% c("gpkg")) return("gpkg")
  if (ext %in% c("xlsx", "xls")) return("xlsx")
  if (ext %in% c("zip")) return("zip")

  return("unknown")
}


#' Read file automatically based on type
#'
#' Reads a file using the appropriate R package based on detected file type.
#' Supports CSV, Parquet, GeoPackage (GPKG), and XLSX formats.
#'
#' @param filepath Character. Path to the file to read
#' @param file_type Character. File type hint (optional, will auto-detect if NULL)
#'
#' @return A tibble or sf object depending on file type
#' @noRd
read_file_auto <- function(filepath, file_type = NULL) {

  # Auto-detect if not specified
  if (is.null(file_type)) {
    file_type <- detect_file_type(filepath)
  }

  # Validate file exists
  if (!file.exists(filepath)) {
    stop("File not found: ", filepath, call. = FALSE)
  }

  cli::cli_alert_info("Reading {.file {basename(filepath)}} as {.strong {file_type}}")

  # Route to appropriate reader
  data <- switch(file_type,
    csv = readr::read_csv(filepath, show_col_types = FALSE),
    parquet = arrow::read_parquet(filepath),
    gpkg = sf::st_read(filepath, quiet = TRUE),
    xlsx = readxl::read_excel(filepath),
    stop("Unsupported file type: ", file_type, call. = FALSE)
  )

  return(data)
}


#' Handle ZIP archive extraction and reading
#'
#' Extracts a ZIP archive, finds files matching criteria, and reads them.
#' Handles single or multiple files intelligently.
#'
#' @param zip_path Character. Path to ZIP file
#' @param file_pattern Character. Regex pattern to filter files (optional)
#' @param file_type Character. Expected file type to look for (optional)
#'
#' @return A tibble, sf object, or list of objects depending on contents
#' @noRd
handle_zip_archive <- function(zip_path, file_pattern = NULL, file_type = NULL) {

  # Create temp extraction directory
  extract_dir <- tempfile()
  dir.create(extract_dir)

  # Ensure cleanup on exit
  on.exit(unlink(extract_dir, recursive = TRUE), add = TRUE)

  # Extract archive
  cli::cli_alert_info("Extracting ZIP archive...")
  tryCatch({
    utils::unzip(zip_path, exdir = extract_dir)
  }, error = function(e) {
    stop("Failed to extract ZIP archive: ", e$message, call. = FALSE)
  })

  # List all extracted files (recursive for nested folders)
  all_files <- list.files(extract_dir, recursive = TRUE, full.names = TRUE)

  # Filter out directories
  all_files <- all_files[!dir.exists(all_files)]

  if (length(all_files) == 0) {
    stop("ZIP archive is empty or contains only directories", call. = FALSE)
  }

  cli::cli_alert_info("Found {length(all_files)} file(s) in archive")

  # Filter by file type if specified
  if (!is.null(file_type)) {
    type_files <- Filter(function(f) detect_file_type(f) == file_type, all_files)
    if (length(type_files) > 0) {
      all_files <- type_files
      cli::cli_alert_info("Filtered to {length(all_files)} {file_type} file(s)")
    } else {
      cli::cli_alert_warning("No {file_type} files found, using all files")
    }
  }

  # Filter by pattern if specified
  if (!is.null(file_pattern)) {
    pattern_files <- grep(file_pattern, all_files, value = TRUE)
    if (length(pattern_files) > 0) {
      all_files <- pattern_files
      cli::cli_alert_info("Filtered to {length(all_files)} file(s) matching pattern")
    } else {
      stop(
        "No files found matching pattern '", file_pattern, "'.\n",
        "Available files: ", paste(basename(all_files), collapse = ", "),
        call. = FALSE
      )
    }
  }

  # Handle based on number of files
  if (length(all_files) == 1) {
    # Single file: return object directly
    return(read_file_auto(all_files[1], file_type))

  } else {
    # Multiple files: try to find the "main" data file

    # Priority 1: Look for supported data formats
    data_files <- Filter(function(f) {
      type <- detect_file_type(f)
      type %in% c("csv", "parquet", "gpkg", "xlsx")
    }, all_files)

    if (length(data_files) == 0) {
      stop(
        "No supported data files found in ZIP archive.\n",
        "Supported formats: CSV, Parquet, GeoPackage (GPKG), XLSX\n",
        "Available files: ", paste(basename(all_files), collapse = ", "),
        call. = FALSE
      )
    }

    if (length(data_files) == 1) {
      # Found exactly one data file
      return(read_file_auto(data_files[1], file_type))
    }

    # Multiple data files: warn and use first
    cli::cli_alert_warning(
      "Multiple data files found in archive. Using: {.file {basename(data_files[1])}}"
    )
    cli::cli_alert_info(
      "To select a specific file, use {.code file_pattern} parameter.\n",
      "Available files: {paste(basename(data_files), collapse = ', ')}"
    )

    return(read_file_auto(data_files[1], file_type))
  }
}


#' Select target file from dataset files list
#'
#' Intelligently selects which file to download from a Dataverse dataset
#' based on user preferences, year patterns, and sensible defaults.
#'
#' @param files Data frame. Dataset files from Dataverse metadata
#' @param filename Character. Exact filename to select (optional)
#' @param year Numeric. Year to match in filename (optional)
#' @param file_pattern Character. Regex pattern to match (optional)
#' @param identifier Character. Dataset identifier for error messages
#'
#' @return Single row data frame with selected file information
#' @noRd
select_target_file <- function(files, filename = NULL, year = NULL,
                               file_pattern = NULL, identifier = NULL) {

  file_list <- files$dataFile$filename

  # 1. Explicit filename takes precedence
  if (!is.null(filename)) {
    idx <- which(file_list == filename)
    if (length(idx) == 0) {
      stop(
        "File '", filename, "' not found in dataset.\n",
        "Available files: ", paste(file_list, collapse = ", "),
        call. = FALSE
      )
    }
    return(files[idx[1], ])
  }

  # 2. Single file - use it
  if (length(files$dataFile$filename) == 1) {
    cli::cli_alert_info("Single file dataset: {.file {file_list[1]}}")
    return(files[1, ])
  }

  # 3. Filter by year pattern
  if (!is.null(year)) {
    year_pattern <- paste0("_", year, "\\.|_", year, "\\.")
    matches <- grep(year_pattern, file_list)
    if (length(matches) > 0) {
      if (length(matches) == 1) {
        cli::cli_alert_info("Found file for year {year}: {.file {file_list[matches[1]]}}")
        return(files[matches[1], ])
      } else {
        # Multiple matches for year - apply pattern if provided
        if (!is.null(file_pattern)) {
          pattern_matches <- grep(file_pattern, file_list[matches])
          if (length(pattern_matches) > 0) {
            match_idx <- matches[pattern_matches[1]]
            cli::cli_alert_info("Found file for year {year}: {.file {file_list[match_idx]}}")
            return(files[match_idx, ])
          }
        }
        # Use first match
        cli::cli_alert_warning("Multiple files found for year {year}, using: {.file {file_list[matches[1]]}}")
        return(files[matches[1], ])
      }
    }
  }

  # 4. Filter by file_pattern
  if (!is.null(file_pattern)) {
    matches <- grep(file_pattern, file_list)
    if (length(matches) == 1) {
      cli::cli_alert_info("Found file matching pattern: {.file {file_list[matches[1]]}}")
      return(files[matches[1], ])
    } else if (length(matches) > 1) {
      cli::cli_alert_warning(
        "Multiple files match pattern. Using first: {.file {file_list[matches[1]]}}"
      )
      return(files[matches[1], ])
    }
    # No matches - fall through to default
  }

  # 5. Default: use first file with warning
  cli::cli_alert_warning(
    "Multiple files available. Using first: {.file {file_list[1]}}"
  )

  if (!is.null(identifier)) {
    cli::cli_alert_info(
      "To select a specific file:\n",
      "  - Use {.code list_files('{identifier}')} to see all files\n",
      "  - Use {.code filename} or {.code file_pattern} parameter"
    )
  }

  return(files[1, ])
}
