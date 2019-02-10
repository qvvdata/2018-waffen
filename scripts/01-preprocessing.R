# #COMMENTED BECAUSE OF GEOCODING PROCESS. IF DESCRIBING OF COMPANIES DONE, THEN RERUN WITH GEOCODING
# (my_sheets <- gs_ls())
# waffenfirmen <- gs_key('1CCpHfCVvLThUtzENr2GcMfb_z2diGr33bM_xO1JtcV0')
# 
#  #Alle Worksheets aus dem GSheet Gemeindedaten importieren
# data <- gs_read(waffenfirmen, ws = 'daten', col_names = TRUE)
# dok <- gs_read(waffenfirmen, ws = 'doku', col_names = TRUE)
# 
# #tidy sparten
# data <- data %>%
#        mutate(adressegesamtat = paste(adressegesamt, ", Österreich"))
# 
# #needs version 2.7 because of google_register
# #devtools::install_github("dkahle/ggmap")
# #library(ggmap)
# needs(readxl)
# apiKey <- "AIzaSyDWRVz_gs5QtT2P2PDKiNfYs4T2eHOxE-U"
# 
# register_google(key = apiKey)
# 
# data$latlong <- geocode(data$adressegesamtat, output = "latlona", source = "google")
# saveRDS(data,file="output/ignore/data.Rda")
data <- readRDS("output/ignore/data.Rda")

data$long <- data$latlong$lon
data$lat <- data$latlong$lat
data$geocodedadress <- data$latlong$address

data <- data %>%
  separate(Beschäftigte, into=c("beschaeftigte_jahr", "beschaeftigte"), sep=":") %>%
  select(-latlong)

data$beschaeftigte <- trimws(data$beschaeftigte) 
data$beschaeftigte[is.na(data$beschaeftigte)] <- "n.v."
data$beschaeftigte[data$beschaeftigte == "kei"] <- 0
data$beschaeftigte[data$beschaeftigte == "keine"] <- 0

write.csv(data, "output/data_companies_geocoded.csv")

#Gathern
data <- data %>%
  separate(sparten, into=c("a", "b", "c", "d", "e", "f", "g", "h", "i", "j"), sep=",") %>%
  select(-c(a:j),everything()) %>%
  gather(sparten, typ, a:j) %>%
  filter(!is.na(typ) & typ !="")


data$typ <- trimws(data$typ)  

#exporte reinladen, aber nur ab 2004, weil sonst keine kategorisierung vorliegt
# exports <- read_xlsx("input/exporte_eu_pivot.xlsx", sheet="roh")%>%
#   mutate(jahr = as.numeric(year))%>%
#   filter(year>2003 & rating !="Miscellaneous" & name_destination_country !="Federal Republic of Yugoslavia")%>%
#   select(-X__1)

#exporte reinladen, aber nur ab 2004, weil sonst keine kategorisierung vorliegt
exports <- read_xlsx("input/export_2017.xlsx", sheet="export_2017") %>%
  mutate(jahr = as.numeric(year)) %>%
  filter(year>2003 & rating !="Miscellaneous" & name_destination_country !="Federal Republic of Yugoslavia")


#wk dokumentation hinzufügen
exports <- left_join(exports, dok, by=c("rating"="mlcat"))

#centroids laden
centroid <- read_delim("input/country_centroids_all.csv", 
                                         "\t", escape_double = FALSE, trim_ws = TRUE)%>%
  select(ISO3136, SHORT_NAME, LAT, LONG)

#centroid hinzufügen
exports <- left_join(exports, centroid, by=c("iso_source_country"="ISO3136"))%>%
                  rename(lat_source_country = LAT, 
                  long_source_country = LONG) 

exports <- left_join(exports, centroid, by=c("iso_destination_country"="ISO3136"))%>%
                   rename(lat_destination_country = LAT, 
                    long_destination_country = LONG)
  

