library(magrittr)
library(raster)
library(rgdal)
library(gdalUtils)
library(mapview)
library(sf)

setwd("/home/michael/Dropbox/BGU/Itai_Kloog/p_56_CONUS_LST_independent_variables_from_GEE/")

# All other than NLCD
# path = ""

# NLCD
path1 = "~/Downloads/NLCD2011_landcover_11_12_21_22_23_24_31_41_42_43_51_52_71_72_73_74_81_82_90_95-0000000000-0000000000.tif"
path2 = "~/Downloads/NLCD2011_landcover_11_12_21_22_23_24_31_41_42_43_51_52_71_72_73_74_81_82_90_95-0000000000-0000005376.tif"
r1 = brick(path1)
r2 = brick(path2)
r2 = merge(r1, r2)
path = "~/Downloads/NLCD2011_landcover_11_12_21_22_23_24_31_41_42_43_51_52_71_72_73_74_81_82_90_95.tif"
writeRaster(r2, path)

################################################################################

# HDF "template"
s = get_subdatasets("mod11_sample/MOD11A1.A2014129.h12v04.006.2016203053220.hdf")
r1 = s[1] %>% readGDAL %>% raster
p1 = proj4string(r1)

# EE export
r2 = brick(path)

# proj4string change!
proj4string(r2) = p1

# Clip & mask
aoi = st_read("CONUS_polygon_from_Johnathan/conus_GLakes_buff_poly1000.shp")
aoi = st_transform(aoi, proj4string(r2))
aoi = as(aoi, "Spatial")
r2 = crop(r2, aoi)
r2 = mask(r2, aoi)

# Write
newpath = gsub(".tif", "-CORRECTED.tif", path, fixed = TRUE)
writeRaster(r2, newpath, overwrite = TRUE)

################################################################################

# Check with QGIS
e = paste("qgis", newpath)
system(e)

# Check with mapview
boston = st_read("~/Dropbox/Projects/Twitter_Preliminary_for_ISF/twitter_boston_bbox.shp")
boston = st_transform(boston, proj4string(r2))
boston = as(boston, "Spatial")
boston = crop(r2, boston)
mapview(boston)



