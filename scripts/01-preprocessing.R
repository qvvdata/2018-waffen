library(tidyverse)
library(readxl)
library(googlesheets)
library(countrycode)

# #COMMENTED BECAUSE OF GEOCODING PROCESS. IF DESCRIBING OF COMPANIES DONE, THEN RERUN WITH GEOCODING
(my_sheets <- gs_ls())
waffenfirmen <- gs_key('1CCpHfCVvLThUtzENr2GcMfb_z2diGr33bM_xO1JtcV0')

GEOCODE_AGAIN <- FALSE
# 
#  #Alle Worksheets aus dem GSheet Gemeindedaten importieren
# data <- gs_read(waffenfirmen, ws = 'daten', col_names = TRUE)
dok <- gs_read(waffenfirmen, ws = 'doku', col_names = TRUE)

if(GEOCODE_AGAIN) {
  # #tidy sparten
  data_original <- gs_read(waffenfirmen, ws = 'daten', col_names = TRUE)
  
  data <- data_original %>%
          mutate(adressegesamtat = paste(`Adresse gesamt`, ", Österreich"))
  # 
  # #needs version 2.7 because of google_register
  devtools::install_github("dkahle/ggmap")
  library(ggmap)
  needs(readxl)
  apiKey <- "AIzaSyBQfr6TDkuPP8GJ9krgpibtPFoDcQ6B0Mo"
  # 
  register_google(key = apiKey)
  # 
  data$latlong <- geocode(data$adressegesamtat, output = "latlona", source = "google")
  
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
  
  write.csv(data, "output/data_companies_geocoded.csv", row.names = F, fileEncoding = 'utf-8')
  
  #saveRDS(data,file="output/ignore/data.Rda") 
} else {
  #data <- readRDS("output/ignore/data.Rda")
  data <- read.csv("output/data_companies_geocoded.csv", fileEncoding = 'utf-8')
}

#Gathern
data <- data %>%
  separate(Sparten, into=c("a", "b", "c", "d", "e", "f", "g", "h", "i", "j"), sep=",") %>%
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
#<<<<<<< HEAD
exports <- read_xlsx("input/export_2017.xlsx", sheet="export_2017") %>%
  mutate(jahr = as.numeric(year)) %>%
  filter(year>2003 & rating !="Miscellaneous" & name_destination_country !="Federal Republic of Yugoslavia") %>%
  mutate(iso_destination_country = case_when(name_destination_country == "Kosovo" ~ "XK", TRUE ~ iso_destination_country)) %>%
  mutate(iso_destination_country_3 = countrycode(sourcevar = iso_destination_country, origin="iso2c", destination="iso3c")) %>%
  mutate(name_destination_country_de = case_when(name_destination_country == "Kosovo" ~ "Kosovo",
                                                 TRUE ~ countrycode(sourcevar = iso_destination_country, origin="iso2c", destination="country.name.de"))) %>%
  mutate(iso_destination_country_3 = case_when(name_destination_country == "Kosovo" ~ "KOS", TRUE ~ iso_destination_country_3))


#wk dokumentation hinzufügen
exports <- left_join(exports, dok, by=c("rating"="mlcat"))

#centroids laden
centroid <- read_delim("input/country_centroids_all.csv", 
                                         "\t", escape_double = FALSE, trim_ws = TRUE)%>%
  select(ISO3136, SHORT_NAME, LAT, LONG) %>%
  mutate(ISO3136 = case_when(SHORT_NAME == "Kosovo" ~ "XK", TRUE ~ ISO3136))

#centroid hinzufügen
exports <- left_join(exports, centroid, by=c("iso_source_country"="ISO3136"))%>%
                  rename(lat_source_country = LAT, 
                  long_source_country = LONG)

exports <- left_join(exports, centroid, by=c("iso_destination_country"="ISO3136"))%>%
                   rename(lat_destination_country = LAT, 
                    long_destination_country = LONG)


sparte_schoen <- gs_read(waffenfirmen, ws = 'Sparte_Schön', col_names = TRUE)

data_schoen <- data %>% left_join(sparte_schoen %>% select(original, schön), by=c(typ="original")) %>% select(-typ,-sparten) %>% distinct() %>% rename(typ="schön")
write.csv(data_schoen, "interaktiv/waffen-scroller/src/data/companies_geocoded.csv", row.names = F, fileEncoding = 'utf-8')
