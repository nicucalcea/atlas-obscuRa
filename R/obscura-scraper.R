library(tidyverse)
library(rvest)
library(sf)

# Scrape all place URLs

scrape_all_places <- function(base_url, start_page = 1) {
    all_places <- c() # Vector to store all results
    current_page <- start_page

    cat("Starting pagination scraping...\n")

    while (TRUE) {
        page_url_full <- paste0(base_url, "?page=", current_page)
        cat(sprintf("Scraping page %d: %s\n", current_page, page_url_full))

        # Try to get places from current page with error handling
        places <- tryCatch(
            {
                # Read the HTML page
                page <- read_html(page_url_full)

                # Extract places
                places <- page |>
                    html_elements(".CardWrapper") |>
                    html_elements("a") |>
                    html_attr("href")

                # Return places (could be empty vector)
                places
            },
            error = function(e) {
                # If there's a connection error, we've likely reached the end
                cat(sprintf(
                    "Connection error on page %d: %s\n",
                    current_page,
                    e$message
                ))
                return(NULL)
            }
        )

        # If error occurred or no places found, we've reached the end
        if (is.null(places) || length(places) == 0) {
            if (is.null(places)) {
                cat(sprintf(
                    "Connection error at page %d - assuming end of results.\n",
                    current_page
                ))
            } else {
                cat(sprintf(
                    "No places found on page %d - end of results.\n",
                    current_page
                ))
            }
            break
        }

        # Add places to our collection
        all_places <- c(all_places, places)

        # Move to next page
        current_page <- current_page + 1

        # Optional: Add a small delay to be respectful to the server
        Sys.sleep(0.5)
    }

    cat(sprintf(
        "Scraping complete! Total places found: %d\n",
        length(all_places)
    ))
    return(all_places)
}


place_urls <- scrape_all_places(
    "https://www.atlasobscura.com/things-to-do/poland/places"
)

# Scrape individual place details

get_place_details <- function(place_url) {
    place_url_full <- paste0("https://www.atlasobscura.com", place_url)
    print(place_url_full)

    Sys.sleep(0.5) # Optional delay to be respectful to the server
    place <- read_html(place_url_full)

    place_name <- place |>
        html_element("h1") |>
        html_text() |>
        str_trim()

    place_description <- place |>
        html_element("h2") |>
        html_text() |>
        str_trim()

    place_coordinates <- place |>
        html_node(
            '[data-clipboard-name-value="Coordinates"] [data-clipboard-target="source"]'
        ) |>
        html_text(trim = TRUE)

    place_coordinates <- strsplit(place_coordinates, ", ")[[1]]

    latitude <- as.numeric(place_coordinates[1])
    longitude <- as.numeric(place_coordinates[2])

    tibble(
        name = place_name,
        description = place_description,
        url = place_url_full,
        latitude = latitude,
        longitude = longitude
    )
}


place_details <- map(place_urls, get_place_details) |>
    bind_rows()

write_csv(
    place_details,
    "data/atlas_obscura_places_poland.csv"
)

# Turn it into an sf object

place_details_sf <- st_as_sf(
    place_details,
    coords = c("longitude", "latitude"),
    crs = 4326
)

write_sf(
    place_details_sf,
    "data/atlas_obscura_places_poland.geojson",
    delete_dsn = TRUE
)
