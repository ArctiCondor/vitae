#' Output format for vitae
#'
#' This output format provides support for including LaTeX dependencies and
#' bibliography entries in extension of the bookdown::pdf_document2() format.
#'
#' @inheritParams rmarkdown::pdf_document
#' @param ... Arguments passed to bookdown::pdf_document2().
#' @param pandoc_vars Pandoc variables to be passed to the template.
#'
#' @export
cv_document <- function(..., pandoc_args = NULL, pandoc_vars = NULL) {
  for (i in seq_along(pandoc_vars)){
    pandoc_args <- c(pandoc_args, rmarkdown::pandoc_variable_arg(names(pandoc_vars)[[i]], pandoc_vars[[i]]))
  }
  config <- bookdown::pdf_document2(..., pandoc_args = pandoc_args)

  pre <- config$pre_processor
  config$pre_processor <- function(metadata, input_file, runtime, knit_meta,
                                     files_dir, output_dir) {
    args <- pre(metadata, input_file, runtime, knit_meta, files_dir, output_dir)

    header_contents <- NULL

    if (has_meta(knit_meta, "latex_dependency")) {
      header_contents <- c(
        header_contents,
        latex_dependencies_as_string(
          flatten_meta(knit_meta, function(x) inherits(x, "latex_dependency"))
        )
      )
    }

    if (has_meta(knit_meta, "biliography_entry")) {
      header_contents <- c(
        header_contents,
        readLines(system.file("bib_format.tex", package = "vitae")),
        bibliography_header(
          flatten_meta(knit_meta, function(x) inherits(x, "biliography_entry"))
        )
      )
    }

    header_file <- tempfile("cv-header", fileext = ".tex")
    xfun::write_utf8(header_contents, header_file)
    args <- c(args, rmarkdown::includes_to_pandoc_args(rmarkdown::includes(in_header = header_file)))
    args
  }
  config
}

flatten_meta <- function(knit_meta, test) {
  all_meta <- list()
  for (dep in knit_meta) {
    if (is.null(names(dep)) && is.list(dep)) {
      inner_meta <- flatten_meta(dep, test)
      all_meta <- append(all_meta, inner_meta)
    } else if (test(dep)) {
      all_meta[[length(all_meta) + 1]] <- dep
    }
  }
  all_meta
}

latex_dependencies_as_string <- function(dependencies) {
  lines <- sapply(dependencies, function(dep) {
    opts <- paste(dep$options, collapse = ",")
    if (opts != "") opts <- paste0("[", opts, "]")
    # \\usepackage[opt1,opt2]{pkgname}
    paste0("\\usepackage", opts, "{", dep$name, "}")
  })
  paste(unique(lines), collapse = "\n")
}

bibliography_header <- function(bibs) {
  titles <- lapply(bibs, function(x) x[["title"]])
  files <- lapply(bibs, function(x) x[["file"]])
  c(
    paste0("\\DeclareBibliographyCategory{", titles, "}"),
    paste0("\\bibliography{", paste0(unique(files), collapse = ", "), "}")
  )
}

has_meta <- function(knit_meta, class) {
  if (inherits(knit_meta, class)) {
    return(TRUE)
  }

  if (is.list(knit_meta)) {
    for (meta in knit_meta) {
      if (is.null(names(meta))) {
        if (has_meta(meta, class)) {
          return(TRUE)
        }
      } else {
        if (inherits(meta, class)) {
          return(TRUE)
        }
      }
    }
  }
  FALSE
}

copy_supporting_files <- function(template) {
  path <- system.file("rmarkdown", "templates", template, "skeleton", package = "vitae")
  files <- list.files(path)
  # Copy class and style files
  for (f in files[files != "skeleton.Rmd"]) {
    if (!file.exists(f)) {
      file.copy(file.path(path, f), ".", recursive = TRUE)
    }
  }
}
