# Prepare ----
stopifnot(requireNamespace("rlang"))
rlang::check_installed("pak")
pkgs <- rlang::chr(
  "shiny",
  "digest",
  "ps",
  "dplyr",
  "stringr",
  "readr",
)
pak::pak(pkgs)
libs <- ifelse(names(pkgs) == "", pkgs, names(pkgs))
libs <- if (length(libs) == 0) pkgs else libs
lapply(libs, library, quiet = TRUE, character.only = TRUE) |> invisible()


# Run ----
guid <- "job_sum_1.R"
job_key <- Sys.getenv("JOB_KEY", NA)
data <- read_rds("input_data.rds")

if (is.na(job_key)) {
  stop("The environment variable JOB_KEY must be set.")
}

calculated_key <- paste0(digest::digest(guid), digest::digest(data))

if (calculated_key != job_key) {
  stop(paste0("The JOB_KEY ", job_key," does not match the calculated_key ", calculated_key, "."))
}

result <- data + 1L

cat("Simulate a long-running job", "\n")
Sys.sleep(30)

result_file <- paste0("result_", job_key, ".rds")
unlink(result_file)
write_rds(result, result_file)

cat("Job completed for key:", job_key, "\n")