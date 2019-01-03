library(magrittr)
library(raster)
library(sf)
library(mapview)
library(rmapshaper)
library(parallel)

# setwd("/home/michael/Dropbox/BGU/Itai_Kloog/p_56_CONUS_LST_independent_variables_from_GEE/")

# Unzip, fownloaded from: ftp://ftp2.census.gov/geo/tiger/TIGER2018/ROADS/
files = list.files("~/Downloads/tiger_roads_2018/ftp2.census.gov/geo/tiger/TIGER2018/ROADS", full.names = TRUE)
for(i in files) unzip(i, exdir = "/media/qnap/Data/Twitter/roads/roads_shp")

# Create roads layer - PostGIS
r = raster("/media/qnap/Data/Twitter/roads/SRTMGL1_003-CORRECTED.tif")
files = list.files("/media/qnap/Data/Twitter/roads/roads_shp", pattern = "\\.shp$", full.names = TRUE)
roads = mclapply(files, function(x) {
    x = st_read(x, quiet = TRUE)
    x = st_transform(x, proj4string(r))
    st_union(x)
  },
  mc.cores = 16
)
roads = do.call(c, roads)
st_write("~/Downloads/roads.gpkg")
source("~/Dropbox/postgis_231.R")
st_write(x, con, "roads", append = TRUE)

# Create grid polygons layer - PostGIS
r = raster("/media/qnap/Data/Twitter/roads/SRTMGL1_003-CORRECTED.tif")
r[!is.na(r)] = 1:length(r[!is.na(r)])
grid = rasterToPolygons(r)
grid = st_as_sf(grid)
names(grid)[1] = "id"
source("~/Dropbox/postgis_231.R")
st_write(grid, con, "grid")

# Calculate road length
i = 1
grid1 = grid[i, ]

# ...