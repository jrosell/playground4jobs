submit_content <- function(guid, data) {
    running_ids <- get_running_ids(guid)
    if (length(running_ids) > 0) {
        stop("Already running jobs for this guid.")        
    }
    if (Sys.getenv("CONNECT_SERVER") != "") {
    submit_content_connect(guid, data)
    } else {
    submit_content_local(guid, data)
    }
}

get_local_running <- function() {  
  running <- ps::ps(columns = "*")
  running |> dplyr::select(cmdline,pid,ppid,name,status,user,rss,created)
}

get_running_ids <- function(guid = NULL, id = NULL) {
    if (is.null(guid)) stop("Connect jobs require content GUID")
    if (Sys.getenv("CONNECT_SERVER") != "") {   
        if (is.null(guid)) {
            stop("Connect jobs require content GUID")
        }
        client <- connectapi::connect()        
        item <- content_item(client, guid)
        if (!is.null(id)) {   
            running_ids <- get_jobs(item) |> filter(id == id, status == 0) |> pull(id)
            return(as.character(running_ids))
        }        
        running_ids <- get_jobs(item) |> filter(status == 0) |> pull(id)
    } else {
      running <- get_local_running()
      if (!is.null(id)) {
        running_ids <- running  |>
          filter(pid == id) |>
          pull(pid)
        return(as.character(running_ids))
      }
      running_ids <- running  |>
          filter(stringr::str_detect(cmdline, guid)) |>
          pull(pid)
    }
  as.character(running_ids)
}


submit_content_connect <- \(guid, data) {
    job_key <- digest(data)
    CONTENT_GUID <- guid
    client <- connect()
    item <- content_item(client, CONTENT_GUID)
    tmp <- tempfile(fileext = ".rds")
    saveRDS(data, tmp)

    # Pack and upload the files, create the job, unpack the files and run the render job
    render_task <- content_render(
        item,
        params = list(job_key = job_key),
        files  = c("input_data.rds" = tmp)
    )    
    id <- render_task$id
   
    if(!id) {
        stop("Error submitting the job to connect")
    }

    message("The job for this guid is submitted to connect.")
    id

}


submit_content_local <- function(
  guid = "job_pipeline.R",
  data,
  r_version = "4.2.0"
) {
  cat("Running submit_content_local (rig + processx)\n")

  
  job_path <- here::here("jobs", basename(guid))
  stopifnot(file.exists(job_path))
  job_key <- paste0(digest::digest(guid), digest::digest(data))
  output_dir <- here::here("outputs", job_key)  
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)  
  file.copy(job_path, file.path(output_dir, basename(guid)), overwrite = TRUE)
  readr::write_rds(data, file.path(output_dir, "input_data.rds"))
  stdout_file <- file.path(output_dir, "run.out")
  stderr_file <- file.path(output_dir, "run.err")
  rig_bin <- Sys.which("rig")
  if (rig_bin == "") {
    stop("rig executable not found on PATH")
  }
  args <- c(
    "run",
    "--r-version", r_version,
    "--script", basename(guid)
  )
  p <- processx::process$new(
    command = rig_bin,
    args    = args,
    wd      = output_dir,
    env     = c(Sys.getenv(), JOB_KEY = job_key),
    stdout  = stdout_file,
    stderr  = stderr_file,
    cleanup = FALSE,   # DO NOT auto-kill
    supervise = FALSE
  )
  pid <- p$get_pid()

  if (is.null(pid) || pid <= 0) {
    stop("Error submitting job locally (no PID)")
  }

  cat("Job submitted locally. PID:", pid, "\n")
  pid
}
