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
# st_write(roads, "~/Downloads/roads.gpkg")
source("~/Dropbox/postgis_231.R")
st_write(roads, con, "roads")

# Create grid polygons layer - PostGIS
r = raster("/media/qnap/Data/Twitter/roads/SRTMGL1_003-CORRECTED.tif")
r[!is.na(r)] = 1:length(r[!is.na(r)])
grid = rasterToPolygons(r)
grid = st_as_sf(grid)
names(grid)[1] = "id"
source("~/Dropbox/postgis_231.R")
st_write(grid, con, "grid")

# Calculate road length

# Step 1: Indices
CREATE INDEX i ON roads USING gist(geom);
CREATE INDEX igrid ON grid USING gist(geometry);

# Step 2: Line length
#CREATE TABLE grid_lengths1 AS (SELECT id, ST_LENGTH(ST_Intersection(a.geometry, b.geom))
#FROM (SELECT * FROM grid WHERE id>0 AND id<10000) a, roads b
#WHERE ST_Intersects(a.geometry, b.geom));

# CREATE TABLE grid_lengths AS (SELECT id, ST_LENGTH(ST_Intersection(a.geometry, b.geom))
# FROM grid a, roads b
# WHERE ST_Intersects(a.geometry, b.geom));

# Step 3: Join with geometry
# CREATE TABLE test AS SELECT grid.id AS id, st_length, geometry FROM grid_lengths1 LEFT JOIN grid ON grid_lengths1.id = grid.id;

# Step 4: Privileges
# GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO geobgu;

### parallel

library(sf)
library(raster)
library(parallel)
library(RPostgreSQL)
# n = dbGetQuery(con, "SELECT count(id) AS n FROM grid")
p = "..."
step = 10000
s = seq(0, 10000000, step)
result = mclapply(s, function(i) {
    con = dbConnect(
      PostgreSQL(), 
      dbname = "geobgu", 
      host = "132.72.155.231", 
      port = 5432, 
      user = "postgres", 
      password = p
    )
    start = i
    end = i + step
    q = paste0("SELECT id, ST_LENGTH(ST_Intersection(a.geometry, b.geom)) FROM (SELECT * FROM grid WHERE id>", start, " AND id<=", end, ") a, roads b WHERE ST_Intersects(a.geometry, b.geom)")
    dat = dbGetQuery(con, q)
    dbDisconnect(con)
    dat
},
mc.cores = 16
)
result = do.call(rbind, result)
result = result[!duplicated(result$id), ]
write.csv(result, "/media/qnap/Data/Twitter/roads/result.csv", row.names = FALSE)
result = read.csv("/media/qnap/Data/Twitter/roads/result.csv", stringsAsFactors = FALSE)
# con = dbConnect(
#   PostgreSQL(), 
#   dbname = "geobgu", 
#   host = "132.72.155.231", 
#   port = 5432, 
#   user = "postgres", 
#   password = p
# )
# grid = st_read(con, query = "SELECT * FROM grid")
# grid = dplyr::left_join(grid, result, "id")
# grid$st_length[is.na(grid$st_length)] = 0
# st_write(grid, "/media/qnap/Data/Twitter/roads/road_length.shp")
r = raster("/media/qnap/Data/Twitter/roads/SRTMGL1_003-CORRECTED.tif")
r[!is.na(r)] = 1:length(r[!is.na(r)])
tmp = data.frame(id = 1:length(r[!is.na(r)]))
result = dplyr::left_join(tmp, result, "id")
result$st_length[is.na(result$st_length)] = 0
r[!is.na(r)] = result$st_length
# pnt = st_centroid(grid)
# r = rasterize(grid, r, field = "st_length")
writeRaster(r, "/media/qnap/Data/Twitter/roads/SRTMGL1_003-CORRECTED.tif/us_road_length.tif")

# library(sf)
# library(RPostgreSQL)
# library(parallel)
# con = dbConnect(
#       PostgreSQL(), 
#       dbname = "geobgu", 
#       host = "132.72.155.231", 
#       port = 5432, 
#       user = "postgres", 
#       password = p
#     )
# grid = st_read(con, query = "SELECT * FROM grid")
# roads = st_read(con, query = "SELECT * FROM roads")
# 
# result = mclapply(1:nrow(roads), function(i) {
#     roads1 = roads[i, ]
#     grid1 = grid[roads1, ]
#     x = st_intersection(grid1, roads1)
#     x$length = st_length(x)
#     st_set_geometry(x, NULL)
# },
# mc.cores = 8
# )
# result = do.call(rbind, result)
# write.csv(result, "result1.csv", row.names = FALSE)






