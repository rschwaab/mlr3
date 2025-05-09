% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/TaskClassif_sonar.R
\name{mlr_tasks_sonar}
\alias{mlr_tasks_sonar}
\title{Sonar Classification Task}
\format{
\link[R6:R6Class]{R6::R6Class} inheriting from \link{TaskClassif}.
}
\description{
A classification task for the \link[mlbench:Sonar]{mlbench::Sonar} data set.
Positive class is set to "M" (Mine).
}
\section{Dictionary}{

This \link{Task} can be instantiated via the \link[mlr3misc:Dictionary]{dictionary} \link{mlr_tasks} or with the associated sugar function \code{\link[=tsk]{tsk()}}:

\if{html}{\out{<div class="sourceCode">}}\preformatted{mlr_tasks$get("sonar")
tsk("sonar")
}\if{html}{\out{</div>}}
}

\section{Meta Information}{

\itemize{
\item Task type: \dQuote{classif}
\item Dimensions: 208x61
\item Properties: \dQuote{twoclass}
\item Has Missings: \code{FALSE}
\item Target: \dQuote{Class}
\item Features: \dQuote{V1}, \dQuote{V10}, \dQuote{V11}, \dQuote{V12}, \dQuote{V13}, \dQuote{V14}, \dQuote{V15}, \dQuote{V16}, \dQuote{V17}, \dQuote{V18}, \dQuote{V19}, \dQuote{V2}, \dQuote{V20}, \dQuote{V21}, \dQuote{V22}, \dQuote{V23}, \dQuote{V24}, \dQuote{V25}, \dQuote{V26}, \dQuote{V27}, \dQuote{V28}, \dQuote{V29}, \dQuote{V3}, \dQuote{V30}, \dQuote{V31}, \dQuote{V32}, \dQuote{V33}, \dQuote{V34}, \dQuote{V35}, \dQuote{V36}, \dQuote{V37}, \dQuote{V38}, \dQuote{V39}, \dQuote{V4}, \dQuote{V40}, \dQuote{V41}, \dQuote{V42}, \dQuote{V43}, \dQuote{V44}, \dQuote{V45}, \dQuote{V46}, \dQuote{V47}, \dQuote{V48}, \dQuote{V49}, \dQuote{V5}, \dQuote{V50}, \dQuote{V51}, \dQuote{V52}, \dQuote{V53}, \dQuote{V54}, \dQuote{V55}, \dQuote{V56}, \dQuote{V57}, \dQuote{V58}, \dQuote{V59}, \dQuote{V6}, \dQuote{V60}, \dQuote{V7}, \dQuote{V8}, \dQuote{V9}
}
}

\seealso{
\itemize{
\item Chapter in the \href{https://mlr3book.mlr-org.com/}{mlr3book}:
\url{https://mlr3book.mlr-org.com/chapters/chapter2/data_and_basic_modeling.html}
\item Package \CRANpkg{mlr3data} for more toy tasks.
\item Package \CRANpkg{mlr3oml} for downloading tasks from \url{https://www.openml.org}.
\item Package \CRANpkg{mlr3viz} for some generic visualizations.
\item \link[mlr3misc:Dictionary]{Dictionary} of \link[=Task]{Tasks}: \link{mlr_tasks}
\item \code{as.data.table(mlr_tasks)} for a table of available \link[=Task]{Tasks} in the running session (depending on the loaded packages).
\item \CRANpkg{mlr3fselect} and \CRANpkg{mlr3filters} for feature selection and feature filtering.
\item Extension packages for additional task types:
\itemize{
\item Unsupervised clustering: \CRANpkg{mlr3cluster}
\item Probabilistic supervised regression and survival analysis: \url{https://mlr3proba.mlr-org.com/}.
}
}

Other Task: 
\code{\link{Task}},
\code{\link{TaskClassif}},
\code{\link{TaskRegr}},
\code{\link{TaskSupervised}},
\code{\link{TaskUnsupervised}},
\code{\link{california_housing}},
\code{\link{mlr_tasks}},
\code{\link{mlr_tasks_breast_cancer}},
\code{\link{mlr_tasks_german_credit}},
\code{\link{mlr_tasks_iris}},
\code{\link{mlr_tasks_mtcars}},
\code{\link{mlr_tasks_penguins}},
\code{\link{mlr_tasks_pima}},
\code{\link{mlr_tasks_spam}},
\code{\link{mlr_tasks_wine}},
\code{\link{mlr_tasks_zoo}}
}
\concept{Task}
