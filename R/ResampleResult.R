#' @title Container for Results of `resample()`
#'
#' @include mlr_reflections.R
#'
#' @description
#' This is the result container object returned by [resample()].
#'
#' Note that all stored objects are accessed by reference.
#' Do not modify any object without cloning it first.
#'
#' [ResampleResult]s can be visualized via \CRANpkg{mlr3viz}'s `autoplot()` function.
#'
#' @template param_measures
#'
#' @section S3 Methods:
#' * `as.data.table(rr, reassemble_learners = TRUE, convert_predictions = TRUE, predict_sets = "test")`\cr
#'   [ResampleResult] -> [data.table::data.table()]\cr
#'   Returns a tabular view of the internal data.
#' * `c(...)`\cr
#'   ([ResampleResult], ...) -> [BenchmarkResult]\cr
#'   Combines multiple objects convertible to [BenchmarkResult] into a new [BenchmarkResult].
#'
#' @template seealso_resample
#' @export
#' @examples
#' task = tsk("penguins")
#' learner = lrn("classif.rpart")
#' resampling = rsmp("cv", folds = 3)
#' rr = resample(task, learner, resampling)
#' print(rr)
#'
#' # combined predictions and predictions for each fold separately
#' rr$prediction()
#' rr$predictions()
#'
#' # folds scored separately, then aggregated (macro)
#' rr$aggregate(msr("classif.acc"))
#'
#' # predictions first combined, then scored (micro)
#' rr$prediction()$score(msr("classif.acc"))
#'
#' # check for warnings and errors
#' rr$warnings
#' rr$errors
ResampleResult = R6Class("ResampleResult",
  public = list(
    #' @description
    #' Creates a new instance of this [R6][R6::R6Class] class.
    #' An alternative construction method is provided by [as_resample_result()].
    #'
    #' @param data ([ResultData] | [data.table()])\cr
    #'   An object of type [ResultData], either extracted from another [ResampleResult], another
    #'   [BenchmarkResult], or manually constructed with [as_result_data()].
    #' @param view (`character()`)\cr
    #'   Single `uhash` of the [ResultData] to operate on.
    #'   Used internally for optimizations.
    initialize = function(data = ResultData$new(), view = NULL) {
      private$.data = assert_class(data, "ResultData")
      private$.view = assert_string(view, null.ok = TRUE)
    },

    #' @description
    #' Helper for print outputs.
    #' @param ... (ignored).
    format = function(...) {
      sprintf("<%s>", class(self)[1L])
    },

    #' @description
    #' Printer.
    #' @param ... (ignored).
    print = function(...) {
      tab = self$score(measures = list(), conditions = TRUE)
      set_data_table_class(tab)
      tab[, "warnings" := map(get("warnings"), length)]
      tab[, "errors" := map(get("errors"), length)]
      cat_cli(cli_h1("{.cls {class(self)[1L]}} with {.val {self$iters}} resampling iterations"))
      if (nrow(tab)) {
        tab = remove_named(tab, c("task", "learner", "resampling", "prediction"))
        print(tab, class = FALSE, row.names = FALSE, print.keys = FALSE, digits = 3)
      }
    },

    #' @description
    #' Opens the corresponding help page referenced by field `$man`.
    help = function() {
      open_help("mlr3::ResampleResult")
    },

    #' @description
    #' Combined [Prediction] of all individual resampling iterations, and all provided predict sets.
    #' Note that, per default, most performance measures do not operate on this object directly,
    #' but instead on the prediction objects from the resampling iterations separately, and then combine
    #' the performance scores with the aggregate function of the respective [Measure] (macro averaging).
    #'
    #' If you calculate the performance on this prediction object directly, this is called micro averaging.
    #'
    #' @param predict_sets (`character()`)\cr
    #'   Subset of `{"train", "test"}`.
    #' @return [Prediction] or empty `list()` if no predictions are available.
    prediction = function(predict_sets = "test") {
      private$.data$prediction(private$.view, predict_sets)
    },

    #' @description
    #' List of prediction objects, sorted by resampling iteration.
    #' If multiple sets are given, these are combined to a single one for each iteration.
    #'
    #' If you evaluate the performance on all of the returned prediction objects and then average them, this
    #' is called macro averaging. For micro averaging, operate on the combined prediction object as returned by
    #' `$prediction()`.
    #'
    #' @param predict_sets (`character()`)\cr
    #'   Subset of `{"train", "test", "internal_valid"}`.
    #' @return List of [Prediction] objects, one per element in `predict_sets`.
    #' Or list of empty `list()`s if no predictions are available.
    predictions = function(predict_sets = "test") {
      assert_subset(predict_sets, mlr_reflections$predict_sets, empty.ok = FALSE)
      private$.data$predictions(private$.view, predict_sets)
    },

    #' @description
    #' Returns a table with one row for each resampling iteration, including all involved objects:
    #' [Task], [Learner], [Resampling], iteration number (`integer(1)`), and (if enabled)
    #' one [Prediction] for each predict set of the [Learner].
    #' Additionally, a column with the individual (per resampling iteration) performance is added
    #' for each [Measure] in `measures`, named with the id of the respective measure id.
    #' If `measures` is `NULL`, `measures` defaults to the return value of [default_measures()].
    #'
    #' @param ids (`logical(1)`)\cr
    #'   If `ids` is `TRUE`, extra columns with the ids of objects (`"task_id"`, `"learner_id"`, `"resampling_id"`)
    #'   are added to the returned table.
    #'   These allow to subset more conveniently.
    #'
    #' @param conditions (`logical(1)`)\cr
    #'   Adds condition messages (`"warnings"`, `"errors"`) as extra
    #'   list columns of character vectors to the returned table
    #'
    #' @param predictions (`logical(1)`)\cr
    #'   Additionally return prediction objects, one column for each `predict_set` of the learner.
    #'   Columns are named `"prediction_train"`, `"prediction_test"` and `"prediction_internal_valid"`,
    #'   if present.
    #'
    #' @return [data.table::data.table()].
    score = function(measures = NULL, ids = TRUE, conditions = FALSE, predictions = TRUE) {
      measures = assert_measures(as_measures(measures, task_type = self$task_type))
      assert_flag(ids)
      assert_flag(conditions)
      assert_flag(predictions)

      tab = score_measures(self, measures, view = private$.view)

      if (ids) {
        set(tab, j = "task_id", value = ids(tab[["task"]]))
        set(tab, j = "learner_id", value = ids(tab[["learner"]]))
        set(tab, j = "resampling_id", value = ids(tab[["resampling"]]))
        setcolorder(tab, c("task", "task_id", "learner", "learner_id", "resampling", "resampling_id",
          "iteration", "prediction"))
      }

      if (conditions) {
        set(tab, j = "warnings", value = map(tab$learner, "warnings"))
        set(tab, j = "errors", value = map(tab$learner, "errors"))
      }

      if (predictions && nrow(tab)) {
        predict_sets = intersect(mlr_reflections$predict_sets, tab$learner[[1L]]$predict_sets)
        predict_cols = sprintf("prediction_%s", predict_sets)
        for (i in seq_along(predict_sets)) {
          set(tab, j = predict_cols[i],
            value = map(tab$prediction, function(p) as_prediction(p[[predict_sets[i]]], check = FALSE))
          )
        }
      } else {
        predict_cols = character()
      }

      set_data_table_class(tab, "rr_score")

      cns = c("task", "task_id", "learner", "learner_id", "resampling", "resampling_id", "iteration",
        predict_cols, "warnings", "errors", ids(measures))
      cns = intersect(cns, names(tab))
      tab[, cns, with = FALSE]
    },

    #' @description
    #' Calculates the observation-wise loss via the loss function set in the
    #' [Measure]'s field `obs_loss`.
    #' Returns a `data.table()` with the columns of the matching [Prediction] object plus
    #' one additional numeric column for each measure, named with the respective measure id.
    #' If there is no observation-wise loss function for the measure, the column is filled with
    #' `NA` values.
    #' Note that some measures such as RMSE, do have an `$obs_loss`, but they require an
    #' additional transformation after aggregation, in this example taking the square-root.
    #'
    #' @param predict_sets (`character()`)\cr
    #'   The predict sets.
    obs_loss = function(measures = NULL, predict_sets = "test") {
      measures = assert_measures(as_measures(measures, task_type = self$task_type))
      tab = map_dtr(self$predictions(predict_sets), as.data.table, .idcol = "iteration")
      get_obs_loss(tab, measures)
    },

    #' @description
    #' Calculates and aggregates performance values for all provided measures, according to the
    #' respective aggregation function in [Measure].
    #' If `measures` is `NULL`, `measures` defaults to the return value of [default_measures()].
    #'
    #' @return Named `numeric()`.
    aggregate = function(measures = NULL) {
      measures = assert_measures(as_measures(measures, task_type = self$task_type))
      resample_result_aggregate(self, measures)
    },

    #' @description
    #' Subsets the [ResampleResult], reducing it to only keep the iterations specified in `iters`.
    #'
    #' @param iters (`integer()`)\cr
    #'   Resampling iterations to keep.
    #'
    #' @return
    #' Returns the object itself, but modified **by reference**.
    #' You need to explicitly `$clone()` the object beforehand if you want to keeps
    #' the object in its previous state.
    filter = function(iters) {
      iters = assert_integerish(iters, lower = 1L, upper = self$resampling$iters,
        any.missing = FALSE, unique = TRUE, coerce = TRUE)

      private$.data = private$.data$clone(deep = TRUE)
      fact = private$.data$data$fact
      if (!is.null(private$.view)) {
        fact = fact[list(private$.view), on = "uhash", nomatch = NULL]
      }

      private$.data$data$fact = fact[list(iters), on = "iteration", nomatch = NULL]

      invisible(self)
    },

    #' @description
    #' Shrinks the [ResampleResult] by discarding parts of the internally stored data.
    #' Note that certain operations might stop work, e.g. extracting
    #' importance values from learners or calculating measures requiring the task's data.
    #'
    #' @param backends (`logical(1)`)\cr
    #'   If `TRUE`, the [DataBackend] is removed from all stored [Task]s.
    #' @param models (`logical(1)`)\cr
    #'   If `TRUE`, the stored model is removed from all [Learner]s.
    #'
    #' @return
    #' Returns the object itself, but modified **by reference**.
    #' You need to explicitly `$clone()` the object beforehand if you want to keeps
    #' the object in its previous state.
    discard = function(backends = FALSE, models = FALSE) {
      private$.data$discard(backends = backends, models = models)
    },

    #' @description
    #' Marshals all stored models.
    #' @param ... (any)\cr
    #'   Additional arguments passed to [`marshal_model()`].
    marshal = function(...) {
      private$.data$marshal(...)
    },
    #' @description
    #' Unmarshals all stored models.
    #' @param ... (any)\cr
    #'   Additional arguments passed to [`unmarshal_model()`].
    unmarshal = function(...) {
      private$.data$unmarshal(...)
    },

    #' @description
    #' Sets the threshold for the response prediction of classification learners, given they have
    #' output a probability prediction for a binary classification task.
    #' This modifies the object in-place.
    #' @param threshold (`numeric(1)`)\cr
    #'   Threshold value.
    #' @template param_ties_method
    set_threshold = function(threshold, ties_method = "random") {
      if (!self$task_type == "classif") {
        stopf("Can only change the threshold for classification problems, but task type is '%s'.", self$task_type)
      }
      private$.data$set_threshold(self$uhash, threshold, ties_method)
    }
  ),

  active = list(
    #' @field task_type (`character(1)`)\cr
    #' Task type of objects in the `ResampleResult`, e.g. `"classif"` or `"regr"`.
    #' This is `NA` for empty [ResampleResult]s.
    task_type = function(rhs) {
      assert_ro_binding(rhs)
      private$.data$task_type
    },

    #' @field uhash (`character(1)`)\cr
    #' Unique hash for this object.
    uhash = function(rhs) {
      assert_ro_binding(rhs)
      uhash = private$.data$uhashes(private$.view)
      if (length(uhash) == 0L) NA_character_ else uhash
    },

    #' @field iters (`integer(1)`)\cr
    #' Number of resampling iterations stored in the `ResampleResult`.
    iters = function(rhs) {
      private$.data$iterations(private$.view)
    },

    #' @field task ([Task])\cr
    #' The task [resample()] operated on.
    task = function(rhs) {
      assert_ro_binding(rhs)
      tab = private$.data$tasks(private$.view)
      if (nrow(tab) == 0L) {
        return(NULL)
      }
      tab$task[[1L]]
    },

    #' @field learner ([Learner])\cr
    #' Learner prototype [resample()] operated on.
    #' For a list of **trained** learners, see methods `$learners()`.
    learner = function(rhs) {
      assert_ro_binding(rhs)
      tab = private$.data$learners(private$.view, states = FALSE)
      if (nrow(tab) == 0L) {
        return(NULL)
      }
      tab$learner[[1L]]
    },

    #' @field resampling ([Resampling])\cr
    #' Instantiated [Resampling] object which stores the splits into training and test.
    resampling = function(rhs) {
      assert_ro_binding(rhs)
      tab = private$.data$resamplings(private$.view)
      if (nrow(tab) == 0L) {
        return(NULL)
      }
      tab$resampling[[1L]]
    },

    #' @field learners (list of [Learner])\cr
    #' List of trained learners, sorted by resampling iteration.
    learners = function(rhs) {
      assert_ro_binding(rhs)
      private$.data$learners(private$.view)$learner
    },

    #' @field data_extra (list())\cr
    #' Additional data stored in the [ResampleResult].
    data_extra = function(rhs) {
      assert_ro_binding(rhs)
      private$.data$data_extra(private$.view)
    },

    #' @field warnings ([data.table::data.table()])\cr
    #' A table with all warning messages.
    #' Column names are `"iteration"` and `"msg"`.
    #' Note that there can be multiple rows per resampling iteration if multiple warnings have been recorded.
    warnings = function(rhs) {
      assert_ro_binding(rhs)
      private$.data$logs(private$.view, "warning")
    },

    #' @field errors ([data.table::data.table()])\cr
    #' A table with all error messages.
    #' Column names are `"iteration"` and `"msg"`.
    #' Note that there can be multiple rows per resampling iteration if multiple errors have been recorded.
    errors = function(rhs) {
      assert_ro_binding(rhs)
      private$.data$logs(private$.view, "error")
    }
  ),

  private = list(
    # @field data (`ResultData`)\cr
    # Internal data storage object of type `ResultData`.
    .data = NULL,

    # @field view (`character(1)`)\cr
    # Subset of uhashes in the [ResultData] object to operate on.
    .view = NULL,

    deep_clone = function(name, value) {
      if (name == ".data") value$clone(deep = TRUE) else value
    }
  )
)

#' @export
as.data.table.ResampleResult = function(x, ..., predict_sets = "test") { # nolint
  private = get_private(x)
  tab = private$.data$as_data_table(view = private$.view, predict_sets = predict_sets)
  cns = c("task", "learner", "resampling", "iteration", "prediction", if ("data_extra" %in% names(tab)) "data_extra")
  tab[, cns, with = FALSE]
}

# #' @export
# format_list_item.ResampleResult = function(x, ...) { # nolint
#   sprintf("<rr[%i]>", x$iters)
# }

#' @export
c.ResampleResult = function(...) {
  do.call(c, lapply(list(...), as_benchmark_result))
}


resample_result_aggregate = function(rr, measures) {
  unlist(map(unname(measures), function(m) {
    val = m$aggregate(rr)
    # CIs in mlr3inferr return more than 1 value and are already named
    if (length(val) == 1L) return(set_names(val, m$id))
    val
  })) %??% set_names(numeric(), character())
}

#' @export
print.rr_score = function(x, ...) {
  predict_cols = sprintf("prediction_%s", mlr_reflections$predict_sets)
  print_data_table(x, c("task", "learner", "resampling", predict_cols))
}
