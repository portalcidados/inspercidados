#' Generate citation for a dataset
#'
#' Creates a properly formatted citation for a dataset from the Insper Cidades
#' collection. Supports multiple citation formats (text, BibTeX, RIS).
#'
#' @param name Character. Dataset name (e.g., "iptu_sp", "pemob")
#' @param year Numeric. Year of the dataset (if applicable)
#' @param format Character. Citation format: "text", "bibtex", or "ris"
#'
#' @return Character. Citation string in the requested format
#'
#' @examples
#' \dontrun{
#' # Get text citation
#' cite_dataset("iptu_sp", year = 2024)
#'
#' # Get BibTeX entry
#' cite_dataset("pemob", format = "bibtex")
#'
#' # Get RIS format for reference managers
#' cite_dataset("iptu_sp", year = 2024, format = "ris")
#' }
#'
#' @export
cite_dataset <- function(name, year = NULL, format = "text") {

  metadata <- get_metadata(name)

  # Get the appropriate DOI based on structure type
  doi <- get_doi(metadata, year)

  # Build citation components
  authors <- if (!is.null(metadata$authors) && length(metadata$authors) > 0) {
    paste(metadata$authors, collapse = "; ")
  } else {
    "Insper Cidades"
  }

  title <- metadata$title
  if (!is.null(year)) {
    title <- paste0(title, " (", year, ")")
  }

  current_year <- format(Sys.Date(), "%Y")
  server <- get_dataverse_server(metadata)
  
  # Generate citation based on format
  citation <- switch(format,
    "text" = {
      paste0(
        authors, " (", current_year, "). ",
        title, ". ",
        "Insper Cidades - inspercidados. ",
        "DOI: ", doi, ". ",
        "Accessed: ", Sys.Date(), "."
      )
    },

    "bibtex" = {
      key <- paste0(gsub("_", "", name),
                   if (!is.null(year)) year else current_year)
      version_str <- if (!is.null(metadata$version)) {
        paste0("  version = {", metadata$version, "},\n")
      } else {
        ""
      }
      paste0(
        "@dataset{", key, ",\n",
        "  author = {", authors, "},\n",
        "  title = {{", title, "}},\n",
        "  year = {", current_year, "},\n",
        "  publisher = {Insper Cidades},\n",
        version_str,
        "  doi = {", doi, "},\n",
        "  url = {https://", server, "/dataset.xhtml?persistentId=", doi, "},\n",
        "  note = {R package: inspercidados. Processing scripts available at ",
        "https://github.com/insper-cidades/inspercidados}\n",
        "}"
      )
    },

    "ris" = {
      paste0(
        "TY  - DATA\n",
        "AU  - ", gsub("; ", "\nAU  - ", authors), "\n",
        "TI  - ", title, "\n",
        "PY  - ", current_year, "\n",
        "PB  - Insper Cidades\n",
        "DO  - ", doi, "\n",
        "UR  - https://", server, "/dataset.xhtml?persistentId=", doi, "\n",
        "N1  - R package: inspercidados\n",
        "N1  - Processing scripts: https://github.com/insper-cidades/inspercidados\n",
        "ER  -"
      )
    },

    stop("Format must be 'text', 'bibtex', or 'ris'", call. = FALSE)
  )
  
  return(citation)
}

#' Print citation information
#'
#' @param name Character. Dataset name
#' @param year Numeric. Year (if applicable)
#'
#' @export
print_citation <- function(name, year = NULL) {
  metadata <- get_metadata(name)
  
  cat("================== CITATION INFORMATION ==================\n")
  cat("Dataset: ", metadata$title, "\n")
  if (!is.null(year)) cat("Year: ", year, "\n")
  cat("\nPlease cite this dataset as:\n\n")
  cat(cite_dataset(name, year, "text"), "\n")
  cat("\n")
  cat("For BibTeX: cite_dataset('", name, "'",
      if (!is.null(year)) paste0(", year = ", year),
      ", format = 'bibtex')\n")
  cat("\n")
  cat("Processing scripts: https://github.com/insper-cidades/inspercidados/tree/main/data-raw/",
      name, "\n")
  cat("===========================================================\n")
}

#' Get citation for the inspercidados package
#'
#' Generates a citation for the inspercidados R package itself
#' (as opposed to individual datasets).
#'
#' @param format Character. Citation format: "text" or "bibtex"
#'
#' @return Invisible NULL (prints citation to console)
#' @export
#'
#' @examples
#' \dontrun{
#' # Print text citation
#' cite_package()
#'
#' # Get BibTeX entry
#' cite_package("bibtex")
#' }
cite_package <- function(format = "text") {
  if (format == "text") {
    cat("To cite inspercidados in publications use:\n\n")
    cat("  Insper Cidades (2025). inspercidados: Standardized Access to Brazilian Urban Public Datasets.\n")
    cat("  R package version ", utils::packageVersion("inspercidados"), ".\n")
    cat("  https://github.com/insper-cidades/inspercidados\n\n")
    cat("A BibTeX entry for LaTeX users: cite_package('bibtex')\n")
  } else if (format == "bibtex") {
    cat("@Manual{inspercidados2025,\n")
    cat("  title = {{inspercidados}: Standardized Access to Brazilian Urban Public Datasets},\n")
    cat("  author = {{Insper Cidades}},\n")
    cat("  year = {2025},\n")
    cat("  note = {R package version ", utils::packageVersion("inspercidados"), "},\n")
    cat("  url = {https://github.com/insper-cidades/inspercidados},\n")
    cat("}\n")
  } else {
    stop("Format must be 'text' or 'bibtex'", call. = FALSE)
  }

  invisible(NULL)
}
