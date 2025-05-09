#' @include DataBackend.R
DataBackendRename = R6Class("DataBackendRename", inherit = DataBackend, cloneable = FALSE,
  public = list(
    old = NULL,
    new = NULL,

    initialize = function(b, old, new) {
      super$initialize(data = b, b$primary_key)
      assert_character(old, any.missing = FALSE, unique = TRUE)
      assert_subset(old, b$colnames)
      assert_character(new, any.missing = FALSE, len = length(old))
      assert_names(new, "unique")

      ii = old != new
      old = old[ii]
      new = new[ii]

      if (self$primary_key %chin% old) {
        stopf("Renaming the primary key is not supported")
      }


      resulting_names = map_values(b$colnames, old, new)
      dup = anyDuplicated(resulting_names)
      if (dup > 0L) {
        stopf("Duplicated column name after rename: %s", resulting_names[dup])
      }

      self$old = old
      self$new = new
    },

    data = function(rows, cols, data_format) {
      assert_names(cols, type = "unique")
      b = private$.data
      cols = map_values(intersect(cols, self$colnames), self$new, self$old)
      if (!missing(data_format)) warn_deprecated("DataBackendRename$data argument 'data_format'")
      data = b$data(rows, cols)
      set_col_names(data, map_values(names(data), self$old, self$new))
    },

    head = function(n = 6L) {
      data = private$.data$head(n)
      set_col_names(data, map_values(names(data), self$old, self$new))
    },

    distinct = function(rows, cols, na_rm = TRUE) {
      cols = map_values(intersect(cols, self$colnames), self$new, self$old)
      x = private$.data$distinct(rows, cols, na_rm = na_rm)
      set_names(x, map_values(names(x), self$old, self$new))
    },

    missings = function(rows, cols) {
      cols = map_values(intersect(cols, self$colnames), self$new, self$old)
      x = private$.data$missings(rows, cols)
      set_names(x, map_values(names(x), self$old, self$new))
    }
  ),

  active = list(
    rownames = function() {
      private$.data$rownames
    },

    colnames = function() {
      x = private$.data$colnames
      map_values(x, self$old, self$new)
    },

    nrow = function() {
      private$.data$nrow
    },

    ncol = function() {
      private$.data$ncol
    },

    col_hashes = function() {
      res = private$.data$col_hashes
      names(res) = map_values(names(res), self$old, self$new)
      res
    }
  ),

  private = list(
    .calculate_hash = function() {
      calculate_hash(self$old, self$new, private$.data$hash)
    }
  )
)
