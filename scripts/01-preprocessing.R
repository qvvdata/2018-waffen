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

#Gathern
data <- data %>%
  select(-sparten,everything()) %>%
  separate(sparten, into=c("a", "b", "c", "d", "e", "f", "g", "h", "i", "j"), sep=",") %>%
  gather(sparten, typ, a:j) %>%
  filter(!is.na(typ) & typ !="")

  data$typ <- trimws(data$typ)  
  
#exporte reinladen, aber nur ab 2004, weil sonst keine kategorisierung vorliegt
exports <- read_xlsx("input/exporte_eu_pivot.xlsx", sheet="roh")%>%
  mutate(jahr = as.numeric(year))%>%
  filter(year>2003 & rating !="Miscellaneous")%>%
  select(-X__1)

#wk dokumentation hinzufügen
exports <- left_join(exports, dok, by=c("rating"="mlcat"))

