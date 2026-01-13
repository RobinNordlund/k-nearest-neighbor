# K-NN SNABBREFERENS
# ===================
# En-sidas guide för snabb referens

# GRUNDLÄGGANDE ANVÄNDNING
# -------------------------
source("knn_corrected_function.R")

resultat <- calculate_knn_segregation_fast(
  data = data,                    # sf-objekt eller data.frame
  id_col = "rutid100_sw",        # Unikt ID
  x_col = "x_öst_väst",          # X-koordinat (meter)
  y_col = "y_nord_syd",          # Y-koordinat (meter)
  total_pop_col = "antal_tot",   # Total befolkning
  study_pop_col = "antal_for",   # Målpopulation
  k_values = c(1600, 6400),      # K-värden
  include_self = TRUE            # EquiPop-standard
)

# VIKTIGA PARAMETRAR
# ------------------
# include_self = TRUE  ← ALLTID! (EquiPop-standard)
# k_values: Rekommenderat c(1600, 3200, 6400, 12800)

# REKOMMENDERADE K-VÄRDEN
# -----------------------
k_minimal <- c(1600, 6400)                                          # Snabb test
k_standard <- c(1600, 3200, 6400, 12800)                           # Huvudanalys
k_komplett <- c(100, 200, 400, 800, 1600, 3200, 6400, 12800, 25600) # Alla skalor

# SPATIAL ISOLATION INDEX
# -----------------------
# Beräkna SI för k=12800
SI <- sum(resultat$CountAllLocal * resultat$IntervalRatio_12800) / 
      sum(resultat$CountAllLocal)

# VALIDERING MOT EQUIPOP
# ----------------------
# R² > 0.99  → Utmärkt ✅
# R² > 0.95  → Bra ✅
# R² < 0.95  → Kontrollera include_self = TRUE ⚠️

# ÖVERENSSTÄMMELSE PER K
# ----------------------
# k=100:   R²=0.962 (max avvikelse 17.5%) ⚠️
# k=1600:  R²=0.998 (max avvikelse 4.5%)  ✅
# k=6400:  R²=1.000 (max avvikelse 1.8%)  ✅
# k=12800: R²=1.000 (max avvikelse 1.5%)  ✅

# BERÄKNINGSTID
# -------------
# 1,000 lokationer:  ~10 sekunder
# 10,000 lokationer: ~15 minuter
# 50,000 lokationer: ~6 timmar

# OUTPUT-KOLUMNER
# ---------------
# För varje k (exempel k=12800):
#   IntervalSumCountAll_12800    # Faktiskt antal räknade
#   IntervalSumCountGroup_12800  # Antal från målgrupp
#   IntervalRatio_12800          # Andel målgrupp (0-1)
#   IntervalDistance_12800       # Avstånd till längsta (meter)

# VANLIGA FEL
# -----------
# ❌ include_self = FALSE  → Använd TRUE!
# ❌ För högt k-värde      → Max ~50% av total befolkning
# ❌ Fel kolumnnamn        → Kontrollera names(data)
# ❌ NA i data             → Filtrera bort först

# DATAKONTROLL
# ------------
# Innan analys:
sum(is.na(data))                    # Inga NA?
any(data$antal_tot < 0)             # Inga negativa?
any(data$antal_for > data$antal_tot) # Målgrupp ≤ total?

# BEST PRACTICES
# --------------
# 1. ✅ Använd k≥1600 för huvudanalyser
# 2. ✅ include_self = TRUE (alltid!)
# 3. ✅ Validera mot EquiPop om möjligt
# 4. ✅ Dokumentera: R-version, datum, k-värden
# 5. ⚠️  k=100-400: acceptera små avvikelser (ties)

# FILER I PAKETET
# ---------------
# knn_corrected_function.R           # Huvudfunktionen
# README.md                          # Översikt
# KNN_KOMPLETT_DOKUMENTATION.R       # Full dokumentation
# knn_include_self_documentation.md  # Include_self förklaring
# jamfor_med_equipop.R               # Validering
# analys_k100_skillnader.R           # K=100 djupanalys
# test_include_self.R                # Verifiering

# SNABBA EXEMPEL
# --------------

# Exempel 1: Enkel analys
resultat <- calculate_knn_segregation_fast(
  data = data,
  id_col = "id", x_col = "x", y_col = "y",
  total_pop_col = "tot", study_pop_col = "grupp",
  k_values = c(1600, 6400, 12800),
  include_self = TRUE
)

# Exempel 2: Jämför grupper
library(purrr)
grupper <- list(utrikes = "antalutr", högutb = "antalhog")
resultat_lista <- map(grupper, ~calculate_knn_segregation_fast(
  data = data, id_col = "id", x_col = "x", y_col = "y",
  total_pop_col = "tot", study_pop_col = .x,
  k_values = 12800, include_self = TRUE
))

# Exempel 3: Beräkna SI för alla k
library(tidyverse)
si_alla_k <- tibble(
  k = k_values,
  SI = map_dbl(k_values, ~{
    col <- paste0("IntervalRatio_", .x)
    sum(resultat$CountAllLocal * resultat[[col]]) / 
      sum(resultat$CountAllLocal)
  })
)

# MINNESVÄRT
# ----------
# ✅ R² > 0.99 mot EquiPop
# ✅ include_self = TRUE är EquiPop-standard
# ⚠️  k=100 kan ha 17% avvikelse (ties - OK!)
# ✅ k≥1600 har R² > 0.998 (perfekt)

# REFERENSER
# ----------
# Clark & Östh (2018), Environment and Planning B
# EquiPop: http://equipop.kultgeog.uu.se
# Göteborgs Stads kodprinciper

# KONTAKT
# -------
# Se README.md och KNN_KOMPLETT_DOKUMENTATION.R
