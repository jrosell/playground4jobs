# playground4jobs

## How to use it

1. Run the shiny application in the app.R
2. Submit the selected jobs from the jobs folder (It runs a background local process)
3. Check the status, even restarting the shiny app application.

## Using Docker

```
docker run --rm \
  -v "$HOME/.cache/R/renv:/renv/cache" \
  -v "$(pwd)/outputs:/workspace/outputs" \
  -p 5543:5543 \
  playground4jobs \
  rig run -r 4.2.0 -e "shiny::runApp(host = '0.0.0.0', port = 5543)"
```


## Next steps

- Let the user select diferent datasets.
- Could be useful to test it with posit connect.

