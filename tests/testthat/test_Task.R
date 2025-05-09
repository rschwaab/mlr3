test_that("Feature columns can be reordered", {
  task = tsk("california_housing")
  new_order = shuffle(task$feature_names)

  task$col_roles$feature = new_order
  expect_equal(task$feature_names, new_order)
  expect_equal(names(task$data(rows = 1)), c("median_house_value", new_order))
})

test_that("Task duplicates rows", {
  # getting same row ids twice
  task = tsk("iris")
  data = task$data(c(1L, 1L))
  expect_data_table(data, nrows = 2L, any.missing = FALSE)

  # task with duplicated ids in row_roles$use
  # this happens in ResamplingBootstrap!
  task = tsk("iris")
  task$row_roles$use = c(1:5, 1:5, 146:150)
  expect_task(task, duplicated_ids = TRUE)

  expect_equal(task$nrow, 15L)
  expect_data_table(task$data(), nrows = 15)
  task$droplevels()
  expect_character(task$class_names, len = 2L)

  task$set_row_roles(1, remove_from = "use")
  expect_equal(task$nrow, 13L)
  task$set_row_roles(1L, add_to = "use")
  expect_equal(task$nrow, 14L)
  task$set_row_roles(1L, add_to = "use")
  expect_equal(task$nrow, 15L)
})

test_that("Rows return ordered", {
  x = load_dataset("nhtemp", "datasets", TRUE)
  data = as.data.frame(x)
  data$x = as.numeric(data$x)
  data$t = as.integer(time(x))
  data = data[rev(seq_row(data)), ]
  rownames(data) = NULL
  b = as_data_backend(data)
  task = TaskRegr$new(id = "nhtemp", b, target = "x")

  x = task$data()
  expect_true(is.unsorted(x$t))

  task$col_roles$order = "t"
  x = task$data(ordered = TRUE)
  expect_integer(x$t, sorted = TRUE, any.missing = FALSE)

  x = task$data(ordered = FALSE)
  expect_true(is.unsorted(x$t))

  x = task$data(rows = sample(nrow(data), 50), ordered = TRUE)
  expect_integer(x$t, sorted = TRUE, any.missing = FALSE)
})

test_that("Rows return ordered with multiple order cols", {
  task = tsk("iris")

  x = task$data()
  expect_true(is.unsorted(x$Petal.Length))

  task$col_roles$order = c("Petal.Length", "Petal.Width")
  expect_equal(task$col_roles$order, c("Petal.Length", "Petal.Width"))

  x = task$data(ordered = TRUE)
  expect_numeric(x$Petal.Length, sorted = TRUE, any.missing = FALSE)

  expect_true(x[, is.unsorted(Petal.Width)])
  expect_true(all(x[, is.unsorted(Petal.Width), by = Petal.Width]$V1 == FALSE))
})


test_that("Task rbind", {
  task = tsk("iris")
  # expect_error(task$rbind(task), "data.frame")
  data = iris[1:10, ]
  task$rbind(iris[1:10, ])
  expect_task(task)
  expect_equal(task$nrow, 160)

  task$rbind(iris[integer(), ])
  expect_equal(task$nrow, 160)

  # #185
  task = tsk("iris")
  task$select("Petal.Length")
  task$rbind(task$data())
  expect_set_equal(task$row_ids, 1:300)

  task$rbind(data.table())
  expect_equal(task$nrow, 300L)

  # #437
  task = tsk("zoo")
  data = task$data()
  data$foo = 101:1
  nt = task$clone()$rbind(data)
  expect_task(nt)
  expect_set_equal(nt$row_ids, 1:202)
  expect_equal(nt$row_names$row_name, c(task$row_names$row_name, rep(NA, 101)))
  expect_equal(nt$col_info[list("foo"), .N, nomatch = NULL], 0L)

  # 496
  data = iris
  data$blocks = sample(letters[1:2], nrow(iris), replace = TRUE)
  task = TaskClassif$new("iris", data, target = "Species")
  task$col_roles$feature = setdiff(task$col_roles$feature, "blocks")
  task$col_roles$group = "blocks"
  learner = lrn("classif.rpart")
  learner$train(task)
  expect_prediction(predict(learner, iris, predict_type = "<Prediction>"))

  # merge factor levels
  task = tsk("penguins")
  data = task$data(1)
  data$sex = factor("unsure", levels = c("male", "female", "unsure"))
  task$rbind(data)
  expect_equal(task$levels("sex")[[1]], c("female", "male", "unsure"))
  expect_equal(task$col_info[list("sex"), fix_factor_levels], TRUE)
})

test_that("Task cbind", {
  task = tsk("iris")

  iris_col_hashes = task$col_hashes

  # expect_error(task$cbind(task), "data.frame")
  data = cbind(data.frame(foo = 150:1), data.frame(..row_id = task$row_ids))
  task$cbind(data)
  expect_task(task)
  expect_equal(task$ncol, 6L)
  expect_names(task$feature_names, must.include = "foo")

  expect_equal(iris_col_hashes, task$col_hashes[names(iris_col_hashes)])

  data = data.frame(bar = runif(150))
  task$cbind(data)
  expect_task(task)
  expect_equal(task$ncol, 7L)
  expect_names(task$feature_names, must.include = "bar")

  data = data.frame(..row_id = task$row_ids)
  task$cbind(data)
  expect_equal(task$ncol, 7L)

  task$cbind(iris[, character()])
  expect_equal(task$ncol, 7L)

  task$cbind(data.table())
  expect_equal(task$ncol, 7L)

  y = task$data(cols = task$target_names, rows = shuffle(task$row_ids))
  task$cbind(y)
  expect_equal(task$ncol, 7L)
  expect_disjunct(task$feature_names, task$target_names)

  # cbind to subsetted task
  task = tsk("iris")$filter(1:120)
  backend = data.table(x = runif(120))
  task$cbind(backend)

  expect_equal(iris_col_hashes, task$col_hashes[names(iris_col_hashes)])

  # cbind 0-row data (#461)
  task = tsk("iris")$filter(integer())
  task$cbind(data.frame(x = integer()))
  expect_set_equal(c(task$target_names, task$feature_names), c(names(iris), "x"))

})

test_that("cbind/rbind works", {
  task = tsk("iris")
  data = data.table(..row_id = 1:150, foo = 150:1)

  task$cbind(data)
  expect_task(task)
  expect_equal(task$n_features, 5L) # "foo" was added as a feature
  expect_set_equal(c(task$feature_names, task$target_names), c(names(iris), "foo"))
  expect_data_table(task$data(), ncols = 6, any.missing = FALSE)

  task$rbind(cbind(data.table(..row_id = 201:210, foo = 99L), iris[1:10, ]))
  expect_task(task)
  expect_set_equal(task$row_ids, c(1:150, 201:210))
  expect_equal(task$n_features, 5L) # adding rows doesn't change #features
  expect_data_table(task$data(), ncols = 6, nrows = 160, any.missing = FALSE)

  # auto generated ids
  task = tsk("zoo")
  newdata = task$data(1)
  newdata$animal = "boy"
  task$rbind(newdata)
  expect_set_equal(task$row_ids, 1:102)
})

test_that("filter works", {
  task = tsk("iris")
  task$filter(1:100)
  expect_equal(task$nrow, 100L)
  expect_equal(task$row_ids, 1:100)

  task$filter(91:150)
  expect_equal(task$nrow, 60L)
  expect_equal(task$row_ids, 91:150)

  task$filter(91)
  expect_equal(task$nrow, 1L)
  expect_equal(task$row_ids, 91)
  expect_integer(task$row_ids)  # #1285
  expect_data_table(task$data(), nrows = 1L, any.missing = FALSE)
})

test_that("select works", {
  task = tsk("iris")
  task$select(setdiff(task$feature_names, "Sepal.Length"))
  expect_equal(task$ncol, 4L)

  expect_error(task$select(c("Sepal.Width", "foobar")))

  task$select("Sepal.Width")
  expect_equal(task$feature_names, "Sepal.Width")

  expect_error(task$select(1:4), "character")
  expect_error(task$select("xxx", "subset"))
})

test_that("rename works", {
  task = tsk("iris")
  old = names(iris)
  new = paste0("xx_", old)
  task$rename(old, new)

  expect_set_equal(task$feature_names, setdiff(new, "xx_Species"))
  expect_equal(task$target_names, "xx_Species")
  expect_task_classif(task)
})

test_that("stratify works", {
  task = tsk("iris")
  expect_false("strata" %chin% task$properties)
  expect_null(task$strata)

  task$col_roles$stratum = task$target_names
  expect_true("strata" %chin% task$properties)
  tab = task$strata
  expect_data_table(tab, ncols = 2, nrows = 3)
  expect_list(tab$row_id, "integer")
})

test_that("groups/weights work", {
  b = as_data_backend(data.table(x = runif(20), y = runif(20), w = runif(20),
                                 o = runif(20), g = sample(letters[1:2], 20, replace = TRUE)))
  task = TaskRegr$new("test", b, target = "y")
  task$set_row_roles(16:20, character())

  expect_false("groups" %chin% task$properties)
  expect_false("weights" %chin% task$properties)
  expect_false("offset" %chin% task$properties)
  expect_null(task$groups)
  expect_null(task$weights)

  # weight
  task$col_roles$weight = "w"
  expect_subset("weights", task$properties)
  expect_data_table(task$weights, ncols = 2, nrows = 15)
  expect_numeric(task$weights$weight, any.missing = FALSE)

  task$col_roles$weight = character()
  expect_true("weights" %nin% task$properties)

  # group
  task$col_roles$group = "g"
  expect_subset("groups", task$properties)
  expect_data_table(task$groups, ncols = 2, nrows = 15)
  expect_subset(task$groups$group, c("a", "b"))

  task$col_roles$group = character()
  expect_true("groups" %nin% task$properties)

  expect_error({
    task$col_roles$weight = c("w", "g")
  }, "up to one")
})

test_that("col roles are valid", {
  b = as_data_backend(data.table(
    y = runif(20),
    logical = sample(c(TRUE, FALSE), 20, replace = TRUE),
    numeric = runif(20),
    integer = sample(1:3, 20, replace = TRUE),
    factor = factor(sample(letters[1:3], 20, replace = TRUE))))
  task = TaskRegr$new("test", b, target = "y")

  # weight
  expect_error(task$set_col_roles("logical", roles = "weight"), "type")
  expect_error(task$set_col_roles("factor", roles = "weight"), "type")
  expect_error(task$set_col_roles(c("integer", "numeric"), roles = "weight"), "There may only be up to one column with role")

  # name
  expect_error(task$set_col_roles("logical", roles = "name"), "type")
  expect_error(task$set_col_roles("integer", roles = "name"), "type")
  expect_error(task$set_col_roles("numeric", roles = "name"), "type")
  expect_error(task$set_col_roles(c("integer", "numeric"), roles = "name"), "There may only be up to one column with role")

  # group
  expect_error(task$set_col_roles(c("numeric", "factor"), roles = "group"), "There may only be up to one column with role")

  # missing weights
  b = as_data_backend(data.table(y = runif(20), numeric = c(runif(19), NA_real_)))
  task = TaskRegr$new("test", b, target = "y")

  expect_error(task$set_col_roles("numeric", roles = "weight"), "missing")

  # negative weights
  b = as_data_backend(data.table(y = runif(20), numeric = c(runif(19), -10)))
  task = TaskRegr$new("test", b, target = "y")

  expect_error(task$set_col_roles("numeric", roles = "weight"), "is not")

  # target classif
  b = as_data_backend(data.table(
    y = factor(sample(letters[1:3], 20, replace = TRUE)),
    numeric = runif(20)))
  task = as_task_classif(b, target = "y")

  expect_error({task$col_roles = insert_named(task$col_roles, list(target = "numeric", feature = "y"))},
    "must be a factor or ordered factor")

  expect_error(task$set_col_roles("numeric", roles = "target"), "up to one column with")

  # target regr
  b = as_data_backend(data.table(
    y = runif(20),
    factor = factor(sample(letters[1:3], 20, replace = TRUE))))
  task = TaskRegr$new("test", b, target = "y")

  expect_error({task$col_roles = insert_named(task$col_roles, list(target = "factor", feature = "y"))},
    "numeric or integer column")

  expect_error(task$set_col_roles("factor", roles = "target"), "up to one column with")
})

test_that("ordered factors (#95)", {
  df = data.frame(
    x = c(1, 2, 3),
    y = factor(letters[1:3], levels = letters[1:3], ordered = TRUE),
    z = factor(c("M", "R", "R"), levels = c("M", "R"))
  )
  b = as_data_backend(df)
  task = TaskClassif$new(id = "id", backend = b, target = "z")
  expect_subset(c("numeric", "ordered", "factor"), task$col_info$type)
  expect_set_equal(task$col_info[id == "z", levels][[1L]], c("M", "R"))
  expect_set_equal(task$col_info[id == "y", levels][[1L]], letters[1:3])
})

test_that("as.data.table", {
  task = tsk("iris")
  expect_data_table(as.data.table(task), nrows = 150, ncols = 5)
})

test_that("extra factor levels are stored (#179)", {
  dt = data.table(
    x1 = factor(letters[1:5], levels = letters[5:1]),
    x2 = factor(letters[1:5], levels = letters),
    x3 = letters[1:5],
    target = 1:5)
  task = TaskRegr$new("extra_factor_levels", as_data_backend(dt), "target")
  expect_equal(task$levels("x2")$x2, letters)
})

test_that("task$droplevels works", {
  dt = data.table(
    x1 = factor(letters[1:3]),
    target = 1:3
  )
  task = TaskRegr$new("droplevels", as_data_backend(dt), "target")

  task$filter(1:2)
  expect_equal(task$nrow, 2L)
  expect_equal(task$levels("x1")$x1, letters[1:3])
  task$droplevels()
  expect_equal(task$levels("x1")$x1, letters[1:2])
})

test_that("task$missings() works", {
  task = tsk("pima")
  x = task$missings()
  y = map_int(task$data(), count_missing)
  expect_equal(x, y[match(names(x), names(y))])

  # issue #862
  task = tsk("iris")$cbind(data.frame(x = 1:150))$rename("x", "y")
  missings = task$missings(cols = character())
  expect_integer(missings, len = 0L)
  testthat::expect_named(missings)
})

test_that("task$feature_types preserves key (#193)", {
  task = tsk("iris")$select(character())$cbind(iris[1:4])
  expect_data_table(task$feature_types, ncols = 2L, nrows = 4L, key = "id")
})

test_that("switch columns on and off (#301)", {
  task = tsk("iris")
  expect_equal(task$n_features, 4L)
  task$col_roles$feature = setdiff(task$col_roles$feature, "Sepal.Length")
  expect_equal(task$n_features, 3L)
  task$cbind(data.table(x = 1:150))
  expect_equal(task$n_features, 4L)
  task$col_roles$feature = union(task$col_roles$feature, "Sepal.Length")
  expect_equal(task$n_features, 5L)
  expect_data_table(task$data(), ncols = 6, nrows = 150, any.missing = FALSE)
})

test_that("row roles setters", {
  task = tsk("iris")

  expect_error({
    task$row_roles$use = "foo"
  })
  expect_error({
    task$row_roles$foo = 1L
  })

  task$row_roles$use = 1:20
  expect_equal(task$nrow, 20L)
})

test_that("row_ids_backend returns all backend rows", {
  task = tsk("iris")

  expect_set_equal(task$row_ids, task$row_ids_backend)

  task$filter(1:100)
  expect_set_equal(task$row_ids, 1:100)
  expect_set_equal(task$row_ids_backend, 1:150)

  task$set_row_roles(1:50, remove_from = "use")
  expect_set_equal(task$row_ids, 51:100)
  expect_set_equal(task$row_ids_backend, 1:150)

  expect_error({
    task$row_ids_backend = 1:10
  }, "read-only")
})

test_that("col roles getters/setters", {
  task = tsk("iris")

  expect_error({
    task$col_roles$feature = "foo"
  })

  expect_error({
    task$col_roles$foo = "Species"
  })

  task$col_roles$feature = setdiff(task$col_roles$feature, "Sepal.Length")
  expect_false("Sepal.Length" %chin% task$feature_names)
})

test_that("Task$row_names", {
  task = tsk("mtcars")
  tab = task$row_names
  expect_data_table(tab, any.missing = FALSE, ncols = 2, nrows = task$nrow)
  expect_integer(tab$row_id, unique = TRUE)
  expect_character(tab$row_name)

  tab = task$filter(1:10)$row_names
  expect_data_table(tab, any.missing = FALSE, ncols = 2, nrows = task$nrow)
  expect_integer(tab$row_id, unique = TRUE)
  expect_character(tab$row_name)
})

test_that("Task$set_row_roles", {
  task = tsk("pima")

  task$set_row_roles(1:10, remove_from = "use")
  expect_true(all(1:10 %nin% task$row_ids))

  task$set_row_roles(1:10, add_to = "use")
  expect_true(all(1:10 %in% task$row_ids))
})


test_that("Task$set_col_roles", {
  task = tsk("pima")
  expect_equal(task$n_features, 8L)

  task$set_col_roles("mass", remove_from = "feature")
  expect_equal(task$n_features, 7L)
  expect_true("mass" %nin% task$feature_names)

  task$set_col_roles("mass", add_to = "feature")
  expect_equal(task$n_features, 8L)
  expect_true("mass" %chin% task$feature_names)

  task$set_col_roles("age", roles = "weight")
  expect_equal(task$n_features, 7L)
  expect_true("age" %nin% task$feature_names)
  expect_data_table(task$weights)

  task$set_col_roles("age", add_to = "feature", remove_from = "weight")
  expect_equal(task$n_features, 8L)
  expect_true("age" %chin% task$feature_names)
  expect_null(task$weights)
})

test_that("$add_strata", {
  task = tsk("mtcars")
  expect_equal(task$col_roles$stratum, character())

  task$add_strata("mpg", bins = 5)
  expect_set_equal(task$col_roles$stratum, "..stratum_mpg")
  expect_data_table(task$strata, nrows = 5)

  task$add_strata("am", bins = 3)
  expect_set_equal(task$col_roles$stratum, c("..stratum_mpg", "..stratum_am"))

  task = tsk("mtcars")
  task$add_strata(c("mpg", "am"), bins = c(2, 5))
  expect_set_equal(task$col_roles$stratum, c("..stratum_mpg", "..stratum_am"))
})

test_that("column labels", {
  task = tsk("iris")
  expect_character(task$col_info$label)
  expect_true(allMissing(task$col_info$label))
  expect_true(allMissing(task$labels))

  task$labels = c(Species = "sp")
  expect_equal(task$labels[["Species"]], "sp")
  expect_equal(count_missing(task$labels), 4L)

  fn = task$feature_names
  task$labels = set_names(toupper(fn), fn)
  expect_equal(unname(task$labels), c("sp", toupper(fn)))

  expect_error({ task$labels = c(foo = "as") }, "names")

  dt = data.table(id = c(task$target_names, task$feature_names))
  dt$label = tolower(dt$id)

  task$labels = dt
  expect_equal(
    unname(task$labels),
    tolower(c(task$target_names, task$feature_names))
  )
})

test_that("set_levels", {
  task = tsk("penguins")

  new_lvls = c("male", "female", "missing")
  task$set_levels(list(sex = new_lvls))

  tab = task$col_info[list("sex")]
  expect_equal(tab$levels[[1]], new_lvls)
  expect_equal(tab$fix_factor_levels[[1]], TRUE)
  expect_equal(levels(task$data(1)$sex), new_lvls)
  expect_equal(levels(head(task)$sex), new_lvls)


  new_lvls = c("female", "nothing")
  task$set_levels(list(sex = new_lvls))

  tab = task$col_info[list("sex")]
  expect_equal(tab$levels[[1]], new_lvls)
  expect_equal(tab$fix_factor_levels[[1]], TRUE)
  expect_equal(as.integer(task$data(1)$sex), NA_integer_)
  expect_equal(as.integer(head(task, 1)$sex), NA_integer_)
  expect_equal(levels(task$data(1)$sex), new_lvls)
  expect_equal(levels(head(task, 1)$sex), new_lvls)
})

test_that("special chars in feature names (#697)", {
  expect_error(
    TaskRegr$new("test", data.table(`%asd` = 1:3, t = 3:1), target = "t")
    ,
    "special character"
  )
})

test_that("head/tail", {
  task = tsk("iris")
  expect_data_table(head(task, n = 3), nrows = 3)
  expect_data_table(head(task, n = -3), nrows = task$nrow - 3)

  expect_data_table(tail(task, n = 3), nrows = 3)
  expect_data_table(tail(task, n = -3), nrows = task$nrow - 3)

  expect_data_table(head(task, n = Inf), nrows = 150)
  expect_data_table(tail(task, n = Inf), nrows = 150)

  expect_data_table(head(task, n = -Inf), nrows = 0)
  expect_data_table(tail(task, n = -Inf), nrows = 0)
})

test_that("Roles get printed (#877)", {
  task = tsk("iris")
  task$col_roles$weight = "Petal.Width"
  expect_output(print(task), "Weights: Petal.Width")
})

test_that("validation task is cloned", {
  task = tsk("iris")
  task$internal_valid_task = c(1:10, 51:60, 101:110)
  task2 = task$clone(deep = TRUE)
  expect_different_address(task$internal_valid_task, task2$internal_valid_task)
})

test_that("task is cloned when assining internal validation task", {
  task = tsk("iris")
  task$internal_valid_task = task
  expect_false(identical(task, task$internal_valid_task))
})

test_that("validation task changes a task's hash", {
  task = tsk("iris")
  h1 = task$hash
  task$internal_valid_task = task$clone(deep = TRUE)$filter(1:10)
  h2 = task$hash
  expect_false(h1 == h2)
})

test_that("compatibility checks on internal_valid_task", {
  d1 = data.table(x = 1:10, y = 1:10)
  d2 = data.table(x = rnorm(10), y = 1:10)
  d3 = data.table(x1 = rnorm(10), y = 1:10)

  t1 = as_task_regr(d1, target = "y")
  t2 = as_task_regr(d2, target = "y")
  t3 = as_task_regr(d3, target = "y")
  expect_error({t1$internal_valid_task = t2 }, "differs from the type")
  expect_error({t1$internal_valid_task = t3 }, "not present")
})

test_that("can NULL validation task", {
  task = tsk("iris")
  task$internal_valid_task = 1
  task$internal_valid_task = NULL
  expect_equal(length(task$row_ids), 149)
})

test_that("internal_valid_task is printed", {
  task = tsk("iris")
  task$internal_valid_task = c(1:10, 51:60, 101:110)
  out = capture_output(print(task))
  expect_match(out, "* Validation Task: (30x5)", fixed = TRUE)
})

test_that("task hashes during resample", {
  task = orig = tsk("iris")
  task = orig$clone(deep = TRUE)
  resampling = rsmp("holdout")
  resampling$instantiate(task)
  task$internal_valid_task = resampling$test_set(1)
  learner = lrn("classif.debug", validate = "test")
  expect_equal(resampling_task_hashes(task, resampling, learner), task$hash)
})

test_that("integer vector can be passed to internal_valid_task", {
  task = tsk("iris")$filter(1:5)
  task$internal_valid_task = 5
  expect_permutation(task$row_ids, 1:4)
  expect_equal(task$internal_valid_task$row_ids, 5)
})

test_that("cbind supports non-standard primary key (#961)", {
  tbl = data.table(x = runif(10), y = runif(10), myid = 1:10)
  b = as_data_backend(tbl, primary_key = "myid")
  task = as_task_regr(b, target = "y")
  task$cbind(data.table(x1 = 10:1))
  expect_true("x1" %chin% task$feature_names)
})

test_that("$select changes hash", {
  task = tsk("iris")
  h1 = task$hash
  task$select("Petal.Length")
  h2 = task$hash
  expect_false(h1 == h2)
})

test_that("$characteristics works", {
  task = tsk("spam")
  characteristics = list(foo = 1, bar = "a")
  task$characteristics = characteristics

  expect_snapshot(task)
  expect_equal(task$characteristics, characteristics)

  tsk_1 = tsk("spam")
  tsk_1$characteristics = list(n = 300)
  tsk_2 = tsk("spam")
  tsk_2$characteristics = list(n = 200)

  expect_true(tsk_1$hash != tsk_2$hash)

  learner = lrn("classif.rpart")
  resampling = rsmp("cv", folds = 3)

  design = benchmark_grid(
    tasks = list(tsk_1, tsk_2),
    learners = learner,
    resamplings = resampling
  )

  bmr = benchmark(design)
  tab = as.data.table(bmr, task_characteristics = TRUE)
  expect_names(names(tab), must.include = "n")
  expect_subset(tab$n, c(300, 200))

  tsk_1$characteristics = list(n = 300, f = 3)
  tsk_2$characteristics = list(n = 200, f = 2)

  design = benchmark_grid(
    tasks = list(tsk_1, tsk_2),
    learners = learner,
    resamplings = resampling
  )

  bmr = benchmark(design)
  tab = as.data.table(bmr, task_characteristics = TRUE)
  expect_names(names(tab), must.include = c("n", "f"))
  expect_subset(tab$n, c(300, 200))
  expect_subset(tab$f, c(2, 3))

  tsk_1$characteristics = list(n = 300, f = 2)
  tsk_2$characteristics = list(n = 200)

  design = benchmark_grid(
    tasks = list(tsk_1, tsk_2),
    learners = learner,
    resamplings = resampling
  )

  bmr = benchmark(design)
  tab = as.data.table(bmr, task_characteristics = TRUE)

  expect_names(names(tab), must.include = c("n", "f"))
  expect_subset(tab$n, c(300, 200))
  expect_subset(tab$f, c(2, NA_real_))
})

test_that("warn when internal valid task has 0 obs", {
  task = tsk("iris")
  # expect_warning({task$internal_valid_task = 151}, "has 0 observations")
})


test_that("$data() is not called during task construction", {
  tbl = data.table(x = 1:10, y = 1:10, ..row_id = 1:10)
  backend = R6Class("DataBackendTest",
    inherit = DataBackendDataTable,
    cloneable = FALSE,
    public = list(
      data = function(rows, cols, data_format) {
        stop("Bug")
      }
    )
  )$new(tbl, "..row_id")
  task = as_task_regr(backend, target = "y")
  expect_class(task, "Task")
})

test_that("row_hash works correctly", {
  task = tsk("pima")
  original_hash = task$row_hash

  # hash should change when row ids change with filter
  task$filter(1:100)
  expect_false(identical(task$row_hash, original_hash))
  new_hash = task$row_hash

  # hash should change when row roles change with set_row_roles
  task$set_row_roles(1:50, roles = "use")
  expect_false(identical(task$row_hash, new_hash))

  # hash should be read-only
  expect_error({task$row_hash = "new_hash"}, "is read-only")
})

test_that("row_ids_backend works correctly", {
  task = tsk("pima")

  # should not change when filtering
  task$filter(1:100)
  expect_set_equal(task$row_ids_backend, 1:768)

  # should not change when modifying row roles
  task$set_row_roles(1:50, remove_from = "use")
  expect_set_equal(task$row_ids_backend, 1:768)

  # should be read-only
  expect_error({task$row_ids_backend = 1:10}, "read-only")

  # should match backend$rownames
  expect_set_equal(task$row_ids_backend, task$backend$rownames)

  # should include all rows even after multiple filters
  task$filter(1:50)
  task$filter(1:25)
  expect_set_equal(task$row_ids_backend, 1:768)
})
