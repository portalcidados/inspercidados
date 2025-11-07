#' Generate citation for a dataset
#'
#' Creates a properly formatted citation for a dataset from the Insper Cidades
#' collection. Supports multiple citation formats (text, BibTeX, RIS).
#'
#' Fetches citation metadata dynamically from Dataverse when possible.
#'
#' @param name Character. Dataset identifier (DOI, alias, or metadata ID)
#' @param year Numeric. Year of the dataset (optional, used for title)
#' @param format Character. Citation format: "text", "bibtex", or "ris"
#' @param server Character. Dataverse server URL (optional)
#'
#' @return Character. Citation string in the requested format
#'
#' @examples
#' \dontrun{
#' # Get text citation using alias
#' cite_dataset("iptu_sp")
#'
#' # Get text citation using DOI
#' cite_dataset("10.60873/FK2/7IXFPX")
#'
#' # Get BibTeX entry
#' cite_dataset("pemob", format = "bibtex")
#'
#' # Get RIS format for reference managers
#' cite_dataset("iptu_sp", year = 2024, format = "ris")
#' }
#'
#' @export
cite_dataset <- function(name, year = NULL, format = "text", server = NULL) {
  # Resolve identifier to DOI
  resolved <- resolve_identifier(name)
  doi <- resolved$doi

  # Get server
  if (is.null(server)) {
    server <- Sys.getenv("DATAVERSE_SERVER", unset = "dataverse.datascience.insper.edu.br")
  }

  # Try to fetch metadata from Dataverse
  authors <- "Insper Cidades"
  title <- name # Default to identifier
  publication_year <- format(Sys.Date(), "%Y")

  tryCatch(
    {
      # Get dataset metadata from Dataverse
      dataset_info <- dataverse::get_dataset(doi, server = server)

      # Extract citation metadata
      if (!is.null(dataset_info$data$latestVersion$metadataBlocks$citation)) {
        citation_block <- dataset_info$data$latestVersion$metadataBlocks$citation

        # Extract title
        if (!is.null(citation_block$fields)) {
          title_field <- citation_block$fields[
            citation_block$fields$typeName == "title",
          ]
          if (nrow(title_field) > 0) {
            title <- title_field$value[1]
          }

          # Extract authors
          author_field <- citation_block$fields[
            citation_block$fields$typeName == "author",
          ]
          if (nrow(author_field) > 0 && !is.null(author_field$value[[1]])) {
            author_list <- author_field$value[[1]]
            if (
              is.data.frame(author_list) && "authorName" %in% names(author_list)
            ) {
              authors <- paste(author_list$authorName$value, collapse = "; ")
            }
          }

          # Extract publication year
          pub_date_field <- citation_block$fields[
            citation_block$fields$typeName == "productionDate",
          ]
          if (nrow(pub_date_field) > 0) {
            pub_year <- sub("^(\\d{4}).*", "\\1", pub_date_field$value[1])
            if (nzchar(pub_year)) publication_year <- pub_year
          }
        }
      }
    },
    error = function(e) {
      # Silently fall back to defaults if metadata fetch fails
      NULL
    }
  )

  # Append year to title if provided
  if (!is.null(year)) {
    title <- paste0(title, " (", year, ")")
  }

  current_year <- format(Sys.Date(), "%Y")

  # Generate citation based on format
  citation <- switch(
    format,
    "text" = {
      paste0(
        authors,
        " (",
        publication_year,
        "). ",
        title,
        ". ",
        "DOI: ",
        doi,
        ". ",
        "Accessed via inspercidados R package on ",
        Sys.Date(),
        "."
      )
    },

    "bibtex" = {
      # Create BibTeX key from name (clean non-alphanumeric chars)
      clean_name <- gsub("[^a-zA-Z0-9]", "", name)
      key <- paste0(clean_name, if (!is.null(year)) year else publication_year)

      paste0(
        "@dataset{",
        key,
        ",\n",
        "  author = {",
        authors,
        "},\n",
        "  title = {{",
        title,
        "}},\n",
        "  year = {",
        publication_year,
        "},\n",
        "  publisher = {Insper Cidades},\n",
        "  doi = {",
        doi,
        "},\n",
        "  url = {https://",
        server,
        "/dataset.xhtml?persistentId=",
        doi,
        "},\n",
        "  note = {Accessed via inspercidados R package. ",
        "Available at https://github.com/insper-cidades/inspercidados}\n",
        "}"
      )
    },

    "ris" = {
      paste0(
        "TY  - DATA\n",
        "AU  - ",
        gsub("; ", "\nAU  - ", authors),
        "\n",
        "TI  - ",
        title,
        "\n",
        "PY  - ",
        publication_year,
        "\n",
        "PB  - Insper Cidades\n",
        "DO  - ",
        doi,
        "\n",
        "UR  - https://",
        server,
        "/dataset.xhtml?persistentId=",
        doi,
        "\n",
        "N1  - Accessed via inspercidados R package\n",
        "N1  - https://github.com/insper-cidades/inspercidados\n",
        "ER  -"
      )
    },

    stop("Format must be 'text', 'bibtex', or 'ris'", call. = FALSE)
  )

  return(citation)
}

#' Print citation information
#'
#' @param name Character. Dataset identifier (DOI, alias, or metadata ID)
#' @param year Numeric. Year (if applicable)
#' @param server Character. Dataverse server URL (optional)
#'
#' @export
print_citation <- function(name, year = NULL, server = NULL) {
  # Resolve identifier
  resolved <- resolve_identifier(name)
  doi <- resolved$doi

  cat("================== CITATION INFORMATION ==================\n")
  cat("Dataset identifier: ", name, "\n")
  cat("DOI: ", doi, "\n")
  if (!is.null(year)) {
    cat("Year: ", year, "\n")
  }
  cat("\nPlease cite this dataset as:\n\n")
  cat(cite_dataset(name, year, "text", server), "\n")
  cat("\n")
  cat(
    "For BibTeX: cite_dataset('",
    name,
    "'",
    if (!is.null(year)) paste0(", year = ", year),
    ", format = 'bibtex')\n"
  )
  cat("\n")
  cat("GitHub repository: https://github.com/insper-cidades/inspercidados\n")
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
    cat(
      "  Insper Cidades (2025). inspercidados: Standardized Access to Brazilian Urban Public Datasets.\n"
    )
    cat("  R package version ", utils::packageVersion("inspercidados"), ".\n")
    cat("  https://github.com/insper-cidades/inspercidados\n\n")
    cat("A BibTeX entry for LaTeX users: cite_package('bibtex')\n")
  } else if (format == "bibtex") {
    cat("@Manual{inspercidados2025,\n")
    cat(
      "  title = {{inspercidados}: Standardized Access to Brazilian Urban Public Datasets},\n"
    )
    cat("  author = {{Insper Cidades}},\n")
    cat("  year = {2025},\n")
    cat(
      "  note = {R package version ",
      utils::packageVersion("inspercidados"),
      "},\n"
    )
    cat("  url = {https://github.com/insper-cidades/inspercidados},\n")
    cat("}\n")
  } else {
    stop("Format must be 'text' or 'bibtex'", call. = FALSE)
  }

  invisible(NULL)
}
