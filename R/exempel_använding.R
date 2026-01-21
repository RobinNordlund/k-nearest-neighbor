# =============================================================================
# K-NÄRMASTE GRANNE SEGREGATIONSANALYS - EXEMPELSCRIPT
# =============================================================================
# 
# Beskrivning:
#   Detta script demonstrerar användning av k-närmaste granne (k-NN) metoden
#   för analys av bostadssegregation baserat på utbildningsnivå.
#   Analysen följer Clark & Östh (2018) metodik och använder EquiPop-standard.
#
# Författare: Robin
# Skapad: 2025-01-13
# Senast uppdaterad: 2025-01-13
#
# Beroenden:
#   - MASTERSCRIPT.R (innehåller gemensamma funktioner och inställningar)
#   - funktioner_beräkningar.R (innehåller k-NN funktioner)
#   - Rutor_100m_GBG_region.shp (geografisk data)
#
# =============================================================================

# 1. INSTÄLLNINGAR OCH PAKETLADDNING ----
# =============================================================================

# Ladda masterscript med grundinställningar
source(
  "I:/INS Statistik/WW/WWRN/R/MASTERSCRIPT.R", 
  encoding = "UTF-8"
)

# Ladda k-NN funktioner
source(here("R", "knn_funktioner.R"))

# 2. DATA INLÄSNING ----
# =============================================================================

# Ladda geografisk data - 100m rutor för Göteborg och omgivande region
karta_rutor <- sf::st_read(
  "I:/INS Statistik/WW/WWRN/Rutor_100m_GBG_region/Rutor_100m_GBG_region.shp",
  stringsAsFactors = FALSE
) |> 
  st_zm()

# Ladda utbildningsdata för olika år
# Varje fil innehåller förgymnasial utbildning per 100m-ruta

data_2022 <- read.table(
  file = "input/for_gymn_2022.txt", 
  sep = "\t",          
  header = TRUE,        
  stringsAsFactors = FALSE, 
  encoding = "latin1"
)

data_2017 <- read.table(
  file = "input/for_gymn_2017.txt", 
  sep = "\t",          
  header = TRUE,        
  stringsAsFactors = FALSE, 
  encoding = "latin1"
)

data_2007 <- read.table(
  file = "input/for_gymn_2007.txt", 
  sep = "\t",          
  header = TRUE,        
  stringsAsFactors = FALSE, 
  encoding = "latin1"
)

data_1997 <- read.table(
  file = "input/for_gymn_1997.txt", 
  sep = "\t",          
  header = TRUE,        
  stringsAsFactors = FALSE, 
  encoding = "latin1"
)

# 3. KONFIGURATION AV K-VÄRDEN ----
# =============================================================================

# Definiera k-värden enligt EquiPop standard
# Dessa värden dubbleras för varje steg och representerar olika geografiska skalor:
# - Låga k-värden (100-800): Mycket lokal skala, närmaste grannar
# - Mellanliggande k-värden (1600-6400): Grannskaps-/stadsdelsnivå
# - Höga k-värden (12800-51200): Kommun-/regionsnivå

K_VALUES <- c(100, 200, 400, 800, 1600, 3200, 6400, 12800, 25600, 51200)

# 4. K-NN BERÄKNINGAR FÖR ETT ÅR ----
# =============================================================================

# Beräkna k-närmaste granne segregation för 2022
# include_self = TRUE följer EquiPop-standarden där lokal population inkluderas

resultat_2022 <- calculate_knn_segregation_fast(
  data = data_2022,
  id_col = "rutid100_sw",
  x_col = "x_öst_väst",
  y_col = "y_nord_syd",
  total_pop_col = "antal_tot",
  study_pop_col = "antal_for",
  k_values = K_VALUES, 
  include_self = TRUE
)

# 5. KARTVISUALISERING ----
# =============================================================================

# Definiera gemensamma karteringsinställningar för konsistens

INTERVALL <- c(0, 7, 12, 20, 30, 40, 100)
ETIKETTER <- c(
  "0-7 %", 
  "8-12 % (genomsnitt)", 
  "13-20 %", 
  "21-30 %", 
  "31-40 %", 
  "41 % och över"
)
FARGPALETT <- c(
  "#b2d8e8",  # Ljusblå - låga värden
  "#76adce",  # Mellanblå
  "#fedb78",  # Gul - omkring genomsnitt
  "#CF7701",  # Orange
  "#943602",  # Mörkare orange
  "#231003"   # Mörkbrun - höga värden
)

# Skapa karta för k=100 (mycket lokal skala)
karta_100 <- skapa_knn_karta(
  knn_data = resultat_2022,
  geografi_data = karta_rutor,
  k = 100,
  intervall = INTERVALL, 
  etiketter = ETIKETTER,
  fargpalett = FARGPALETT,
  titel = "Andel personer med förgymnasial utbildning",
  fyllnad_etikett = "Andel (%)",
  omrades_granser = pri_u_öar_k,
  artal = 2022
)

# Skapa karta för k=6400 (grannskaps-/stadsdelsnivå)
karta_6400 <- skapa_knn_karta(
  knn_data = resultat_2022,
  geografi_data = karta_rutor,
  k = 6400,
  intervall = INTERVALL, 
  etiketter = ETIKETTER,
  fargpalett = FARGPALETT,
  titel = "Andel personer med förgymnasial utbildning",
  fyllnad_etikett = "Andel (%)",
  omrades_granser = pri_u_öar_k,
  artal = 2022
)

# 6. ISOLERINGSINDEX FÖR ETT ÅR ----
# =============================================================================

# Beräkna isoleringsindex för att mäta segregationsnivå
# Högre värden indikerar större segregation (homogenare områden)


isolerings_index_2022 <- berakna_isoleringsindex(
  resultat_2022, 
  K_VALUES
)


# Visualisera isoleringsindex över olika k-nivåer
p_index_2022 <- isolerings_index_2022 |> 
  mutate(k = as.factor(k)) |> 
  ggplot() +
  geom_line(
    aes(x = k, y = varde, color = variabel, group = variabel), 
    linewidth = 1
  ) +
  geom_point(
    aes(x = k, y = varde, color = variabel, group = variabel), 
    size = 3
  ) +
  scale_color_gbg_categorical(
    palette = "palette_2", 
    labels = c("Genomsnitt", "Isoleringsindex")
  ) +
  labs(
    title = paste0(
      "Isoleringsindex över olika k-nivåer för personer med ",
      "förgymnasial utbildning som högsta utbildning"
    ), 
    subtitle = "År 2022", 
    x = "K-värde", 
    y = "Isoleringsindex", 
    color = "", 
    caption = "Källa: SCB, med bearbetning av stadsledningskontoret"
  ) +
  theme_minimal() +
  tema_s_h

print(p_index_2022)

# 7. K-NN BERÄKNINGAR FÖR FLERA ÅR ----
# =============================================================================

# Beräkna k-närmaste granne för historiska år för tidsserieanalys

resultat_2017 <- calculate_knn_segregation_fast(
  data = data_2017,
  id_col = "rutid100_sw",
  x_col = "x_öst_väst",
  y_col = "y_nord_syd",
  total_pop_col = "antal_tot",
  study_pop_col = "antal_for",
  k_values = K_VALUES, 
  include_self = TRUE
)

resultat_2007 <- calculate_knn_segregation_fast(
  data = data_2007,
  id_col = "rutid100_sw",
  x_col = "x_öst_väst",
  y_col = "y_nord_syd",
  total_pop_col = "antal_tot",
  study_pop_col = "antal_for",
  k_values = K_VALUES, 
  include_self = TRUE
)

resultat_1997 <- calculate_knn_segregation_fast(
  data = data_1997,
  id_col = "rutid100_sw",
  x_col = "x_öst_väst",
  y_col = "y_nord_syd",
  total_pop_col = "antal_tot",
  study_pop_col = "antal_for",
  k_values = K_VALUES, 
  include_self = TRUE
)

# 8. TIDSSERIEANALYS AV ISOLERINGSINDEX ----
# =============================================================================

# Kombinera resultat från olika år för jämförelse
data_list <- list(
  `2022` = resultat_2022,
  `2017` = resultat_2017,
  `2007` = resultat_2007,
  `1997` = resultat_1997
)

# Beräkna isoleringsindex för alla år
isolerings_index_flera_ar <- berakna_isoleringsindex(
  data_list = data_list, 
  k_nivaer = K_VALUES
)

# Visualisera utvecklingen över tid
p_index_flera_ar <- isolerings_index_flera_ar |> 
  mutate(k = as.factor(k)) |> 
  filter(variabel == "isoleringsindex") |> 
  ggplot() +
  geom_line(
    aes(x = k, y = varde, color = ar, group = ar), 
    linewidth = 1
  ) +
  geom_point(
    aes(x = k, y = varde, color = ar, group = ar), 
    size = 3
  ) +
  scale_color_gbg_categorical(palette = "palette_4") +
  labs(
    title = paste0(
      "Isoleringsindex över olika k-nivåer för personer med ",
      "förgymnasial utbildning som högsta utbildning"
    ), 
    subtitle = "Jämförelse mellan åren 2022, 2017, 2007, 1997", 
    x = "K-värde", 
    y = "Isoleringsindex", 
    color = "År", 
    caption = "Källa: SCB, med bearbetning av stadsledningskontoret"
  ) +
  theme_minimal() +
  tema_s_h

print(p_index_flera_ar)

# =============================================================================
# SLUTNOTER
# =============================================================================
#
# TEKNISKA ANTECKNINGAR:
# 
# 1. K-värden representerar olika geografiska skalor:
#    - k=100-400: Hyperlokal skala (närmaste kvarteren)
#    - k=800-3200: Grannskapsnivå 
#    - k=6400-12800: Stadsdelsnivå
#    - k=25600-51200: Kommun/regionsnivå
#
# 2. Include_self=TRUE är kritiskt för EquiPop-kompatibilitet:
#    - Lokal population inkluderas i k-räkningen
#    - Överensstämmer med akademisk standard (Clark & Östh, 2018)
#
# 3. Isoleringsindex tolkning:
#    - Värde mellan 0 och 1
#    - Högre värde = större segregation
#    - Jämförs lämpligen över tid och mellan olika k-nivåer
#
# DATAFORMAT:
#    - 100m rutor med exakta koordinater
#    - Redan gridded till 100m intervaller
#    - Innehåller totalbefolkning och studiepopulation per ruta
#
# =============================================================================