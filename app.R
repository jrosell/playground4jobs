# Prepare ----

stopifnot(requireNamespace("rlang"))
rlang::check_installed("pak")
pkgs <- rlang::chr(
  "shiny",
  "digest",
  "ps",
  "processx", # TODO to get the cmdline parameter not only R
  "dplyr",
  "stringr",
  "connectapi",
  "readr",
)
# pak::pak(pkgs)
libs <- ifelse(names(pkgs) == "", pkgs, names(pkgs))
libs <- if (length(libs) == 0) pkgs else libs
lapply(libs, library, quiet = TRUE, character.only = TRUE) |> invisible()

# Run ----
options(
  shiny.autoreload = FALSE,
  shiny.trace = FALSE,
  shiny.fullstacktrace = FALSE
)
source("R/submit.R")

# Example data to send
example_data <- 1:5
# export JOB_KEY=35e2c0a442507b3973949a8b4fcac5f2
# saveRDS(example_data, "input_data.rds")

job_scripts <- list.files(
  path = "jobs",
  pattern = "\\.R$",
  full.names = FALSE
)

ui <-
  fluidPage(
    titlePanel("Job Submitter"),
    sidebarLayout(
      sidebarPanel(
        selectInput(
          "guid",
          "Job script:",
          choices = job_scripts,
          selected = "job_sum_1.R"
        ),
        actionButton("submit_btn", "Submit Job"),
        actionButton("check_btn", "Check Job Status"),
        verbatimTextOutput("job_status")
      ),
      mainPanel(      
        h4("Job GUID"),
        verbatimTextOutput("job_guid"),
        h4("Job KEY"),
        verbatimTextOutput("job_key"),
        h4("Job ID"),
        verbatimTextOutput("job_id"),
        h4("Job Running"),
        tableOutput("job_running"),

        tags$table(
          tags$tr(            
            style = "vertical-align: top; border: 1px solid;",
            tags$td(         
              style = "padding: 10px;",
              h4("Job Input"),
              tableOutput("job_input")
            ),
            tags$td(              
              style = "padding: 10px;",
              h4("Job Results"),
              tableOutput("job_results")
            )
          )
        )
      )
    )
  )

server <- function(input, output, session) {
  
  status_msg <- reactiveVal("") 
  last_guid <- reactiveVal(NULL)
  last_key <- reactiveVal(NULL)
  last_id <- reactiveVal(NULL)
  
  output$job_input <- renderTable(example_data)

  output$job_status <- renderText({
    status_msg()
  })
  output$job_guid <- renderText({
    last_guid()
  })
  output$job_key <- renderText({
    last_key()
  })
  output$job_id <- renderText({
    last_id()
  })
 
  output$job_results <- renderTable({
    tibble(data = integer(0))
  })
  
  observeEvent(input$submit_btn, {
    cat("start submit_btn", "\n")    
    status_msg("Submitting the job.")
    last_guid(input$guid)
    
    try({
      job_id <- submit_content(input$guid, example_data)
      last_id(job_id)
      key <- paste0(digest::digest(input$guid), digest::digest(example_data))
      last_key(key)     
      cat("key:", key, "\n")
      status_msg("Job submitted.")
    })
    
    output$job_results <- renderTable({
      tibble(data = integer(0))
    })

    cat("end submit_btn", "\n")
    NULL
  })

  observeEvent(input$check_btn, {
    cat("start check_btn", "\n")    
    
    
    key <- paste0(digest::digest(input$guid), digest::digest(example_data))    
    cat("key:", key, "\n")

    last_guid(input$guid)
    last_key(key)
  
    local_running <- get_local_running()
    output$job_running <- renderTable({     
      local_running |> 
        filter(stringr::str_detect(cmdline, input$guid))
    })    

    
    result_file <- here::here("outputs", key, paste0("result_", key, ".rds"))
    finished <- file.exists(result_file)    
    if(finished) {
      output$job_results <- renderTable({
            read_rds(here::here("outputs", key, paste0("result_", key, ".rds")))
      })
      status_msg(paste("Results available."))      
      return()
    }

    ids <- get_running_ids(input$guid)
    if (length(ids) == 0) {
      status_msg(
        paste("Job is not running.")
      )
      return()
    }

    status_msg(
      paste("Job is running. Active PIDs:", paste(ids, collapse = ", "))
    )
    
    cat("end check_btn", "\n")
    NULL
  })
  
}

shiny::shinyApp(ui, server)