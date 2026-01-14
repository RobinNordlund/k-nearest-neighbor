# K-NN Segregationsanalys (EquiPop-kompatibel)

En R-implementation av K-närmaste-grannar metoden för segregationsanalys enligt Clark & Östh (2018) och EquiPop-standarden.

## 🎯 Snabbstart

```r
# Ladda funktionerna
source("knn_funktioner.R")

# Kör analys
resultat <- calculate_knn_segregation_fast(
  data = min_data,
  id_col = "rutid100_sw",
  x_col = "x_öst_väst",
  y_col = "y_nord_syd",
  total_pop_col = "antal_tot",
  study_pop_col = "antal_for",
  k_values = c(1600, 3200, 6400, 12800),
  include_self = TRUE  # Viktigt! EquiPop-standard
)

# Beräkna isoleringsindex
index <- berakna_isoleringsindex(
  data_list = resultat,
  k_nivaer = c(1600, 3200, 6400, 12800)
)

# Skapa karta
karta <- skapa_knn_karta(
  knn_data = resultat,
  geografi_data = karta_rutor,
  k = 6400,
  intervall = c(0, 10, 20, 30, 40, 50, 100),
  etiketter = c("0-10%", "10-20%", "20-30%", "30-40%", "40-50%", "50-100%"),
  fargpalett = c("#E8F5E9", "#C8E6C9", "#A5D6A7", "#81C784", "#66BB6A", "#4CAF50"),
  titel = "Andel personer med förgymnasial utbildning",
  fyllnad_etikett = "Andel (%)",
  artal = 2022
)

# Spara
library(writexl)
write_xlsx(resultat, "knn_resultat.xlsx")
ggsave("karta_segregation.png", karta, width = 10, height = 8, dpi = 300)
```

## ✅ Validering

Funktionen har validerats mot EquiPop med följande resultat:

| Mått | Värde |
|------|-------|
| **Genomsnittlig R²** | **0.991** |
| **R² för k≥1600** | **≥0.998** |
| **R² för k≥6400** | **1.000** |
| **Status** | **✅ UTMÄRKT** |

### Detaljerad överensstämmelse per k-värde

| k | R² | Medel avvikelse | Max avvikelse (1-2% av lokationer) | Rekommendation |
|---|-----|-----------------|-------------------------------------|----------------|
| 100 | 0.962 | <1% | 17.5% | ✅ God precision för de flesta fall |
| 400 | 0.990 | <1% | 10.0% | ✅ God precision |
| 1600 | 0.998 | <0.5% | 4.5% | ✅ Utmärkt precision |
| 6400 | 1.000 | <0.5% | 1.8% | ✅ Perfekt precision |
| 12800 | 1.000 | <0.5% | 1.5% | ✅ Perfekt precision |
| 25600 | 1.000 | <0.5% | 0.6% | ✅ Perfekt precision |

**Notera:** För k=100 och k=400 har cirka 85% av lokationerna mindre än 1% avvikelse från EquiPop. Maximala avvikelser påverkar endast 1-2% av lokationerna och beror på "ties" i rutnätet (se nedan).

## 📚 Tre huvudfunktioner

Paketet innehåller tre funktioner i `knn_funktioner.R`:

### 1. `calculate_knn_segregation_fast()` - Beräkna k-NN segregation

Huvudfunktionen som beräknar k-närmaste granne segregationsmått.

```r
resultat <- calculate_knn_segregation_fast(
  data = min_data,
  id_col = "rutid100_sw",
  x_col = "x_öst_väst",
  y_col = "y_nord_syd",
  total_pop_col = "antal_tot",
  study_pop_col = "antal_for",
  k_values = c(100, 400, 1600, 6400, 12800),
  include_self = TRUE
)
```

**Parametrar:**
- `data`: Data frame eller sf-objekt med befolkningsdata
- `id_col`: Kolumnnamn för unik identifierare
- `x_col`, `y_col`: Kolumnnamn för koordinater (meter)
- `total_pop_col`: Kolumnnamn för total befolkning
- `study_pop_col`: Kolumnnamn för studiepopulation
- `k_values`: Vektor med k-värden att beräkna
- `include_self`: Logisk, alltid TRUE för EquiPop-kompatibilitet

**Returnerar:** Data frame med segregationsmått för alla k-nivåer

### 2. `berakna_isoleringsindex()` - Beräkna Spatial Isolation Index

Beräknar isolationsindex enligt Clark & Östh (2018) formeln.

```r
# För ett år
index <- berakna_isoleringsindex(
  data_list = resultat_2022,
  k_nivaer = c(100, 400, 1600, 6400, 12800)
)

# För flera år
data_list <- list(
  `2022` = resultat_2022,
  `2017` = resultat_2017,
  `2007` = resultat_2007
)

index <- berakna_isoleringsindex(
  data_list = data_list,
  k_nivaer = c(100, 400, 1600, 6400, 12800)
)
```

**Parametrar:**
- `data_list`: Data frame med k-NN resultat ELLER namngiven lista med flera års resultat
- `k_nivaer`: Vektor med k-värden att beräkna index för

**Returnerar:** Tibble i långt format med kolumner:
- `ar`: Årtal (eller "data" för enskilt dataset)
- `k`: K-nivå
- `variabel`: "isoleringsindex" eller "genomsnitt"
- `varde`: Beräknat värde

**Formel:** SI_k = Σ(x_i × (x_ik / k)) / Σ(x_i)

### 3. `skapa_knn_karta()` - Visualisera resultat

Skapar tematiska kartor över segregationsmönster.

```r
karta <- skapa_knn_karta(
  knn_data = resultat,
  geografi_data = karta_rutor,
  k = 6400,
  intervall = c(0, 10, 20, 30, 40, 50, 100),
  etiketter = c("0-10%", "10-20%", "20-30%", "30-40%", "40-50%", "50-100%"),
  fargpalett = c("#E8F5E9", "#C8E6C9", "#A5D6A7", "#81C784", "#66BB6A", "#4CAF50"),
  titel = "Andel personer med förgymnasial utbildning",
  fyllnad_etikett = "Andel (%)",
  omrades_granser = primaromraden_sf,  # Valfritt: Överlagra gränser
  artal = 2022
)

# Spara kartan
ggsave("segregation_karta.png", karta, width = 10, height = 8, dpi = 300)
```

**Parametrar:**
- `knn_data`: Resultat från calculate_knn_segregation_fast()
- `geografi_data`: sf-objekt med kartgeometri (måste ha kolumn 'RutID')
- `k`: K-nivå att visualisera
- `intervall`: Numerisk vektor med gränsvärden för kategorier
- `etiketter`: Teckenvector med etiketter för varje kategori
- `fargpalett`: Teckenvector med färger (hex-koder)
- `titel`: Kartans huvudtitel
- `fyllnad_etikett`: Etikett för legend
- `omrades_granser`: (Valfritt) sf-objekt med gränser (primärområden, stadsdelar)
- `artal`: (Valfritt) Årtal att visa i undertitel

**Returnerar:** ggplot-objekt

## 📖 Komplett arbetsflöde

```r
# 1. LADDA FUNKTIONER
source("knn_funktioner.R")
library(tidyverse)
library(sf)
library(writexl)

# 2. LADDA DATA
data_2022 <- read.table("for_gymn_2022.txt", sep = "\t", header = TRUE)
karta_rutor <- st_read("Rutor_100m_GBG_region.shp")

# 3. BERÄKNA K-NN SEGREGATION
k_values <- c(100, 200, 400, 800, 1600, 3200, 6400, 12800, 25600)

resultat_2022 <- calculate_knn_segregation_fast(
  data = data_2022,
  id_col = "rutid100_sw",
  x_col = "x_öst_väst",
  y_col = "y_nord_syd",
  total_pop_col = "antal_tot",
  study_pop_col = "antal_for",
  k_values = k_values,
  include_self = TRUE
)

# 4. BERÄKNA ISOLERINGSINDEX
index_2022 <- berakna_isoleringsindex(
  data_list = resultat_2022,
  k_nivaer = k_values
)

# 5. SKAPA KARTOR FÖR OLIKA K-NIVÅER
intervall <- c(0, 7, 12, 20, 30, 40, 100)
etiketter <- c("0-7%", "8-12%", "13-20%", "21-30%", "31-40%", "41% och över")
fargpalett <- c("#b2d8e8", "#76adce", "#fedb78", "#CF7701", "#943602", "#231003")

karta_100 <- skapa_knn_karta(
  knn_data = resultat_2022,
  geografi_data = karta_rutor,
  k = 100,
  intervall = intervall,
  etiketter = etiketter,
  fargpalett = fargpalett,
  titel = "Andel personer med förgymnasial utbildning - Lokal skala",
  fyllnad_etikett = "Andel (%)",
  artal = 2022
)

karta_6400 <- skapa_knn_karta(
  knn_data = resultat_2022,
  geografi_data = karta_rutor,
  k = 6400,
  intervall = intervall,
  etiketter = etiketter,
  fargpalett = fargpalett,
  titel = "Andel personer med förgymnasial utbildning - Stadsdels­nivå",
  fyllnad_etikett = "Andel (%)",
  artal = 2022
)

# 6. VISUALISERA ISOLERINGSINDEX
plot_index <- index_2022 |>
  filter(variabel == "isoleringsindex") |>
  mutate(k = as.factor(k)) |>
  ggplot(aes(x = k, y = varde, group = 1)) +
  geom_line(linewidth = 1) +
  geom_point(size = 3) +
  labs(
    title = "Isoleringsindex över olika k-nivåer",
    subtitle = "År 2022",
    x = "K-värde",
    y = "Isoleringsindex"
  ) +
  theme_minimal()

# 7. SPARA RESULTAT
write_xlsx(resultat_2022, "resultat_2022.xlsx")
write_xlsx(index_2022, "index_2022.xlsx")
ggsave("karta_k100.png", karta_100, width = 10, height = 8, dpi = 300)
ggsave("karta_k6400.png", karta_6400, width = 10, height = 8, dpi = 300)
ggsave("plot_index.png", plot_index, width = 10, height = 6, dpi = 300)

# 8. JÄMFÖR ÖVER TID
data_list <- list(
  `2022` = resultat_2022,
  `2017` = resultat_2017,
  `2007` = resultat_2007
)

index_tidsserie <- berakna_isoleringsindex(
  data_list = data_list,
  k_nivaer = k_values
)

# Visualisera utveckling över tid
plot_tidsserie <- index_tidsserie |>
  filter(variabel == "isoleringsindex") |>
  mutate(k = as.factor(k)) |>
  ggplot(aes(x = k, y = varde, color = ar, group = ar)) +
  geom_line(linewidth = 1) +
  geom_point(size = 3) +
  labs(
    title = "Utveckling av isoleringsindex över tid",
    x = "K-värde",
    y = "Isoleringsindex",
    color = "År"
  ) +
  theme_minimal()
```

## ⚠️ Viktigt att veta

### 1. Include_self = TRUE (EquiPop-standard)

**Alltid använd `include_self = TRUE`!**

Detta är skillnaden mellan EquiPop-metoden och vissa andra K-NN implementationer:
- ✅ `include_self = TRUE`: Lokalen räknas först (EquiPop-standard)
- ❌ `include_self = FALSE`: Hoppar över lokalen (ej EquiPop-kompatibel)

### 2. Ties vid låga k-värden

Vid **k=100-400** kan 1-2% av lokationer ha större avvikelse från EquiPop på grund av "ties".

**Orsak:** "Ties" innebär att flera grannar ligger på exakt samma avstånd i 100m-rutnätet. När detta sker väljer EquiPop och denna funktion grannar i olika ordning, vilket ger små skillnader i resultat.

**Viktig observation:** 
- För cirka **85% av lokationerna** är avvikelsen mindre än 1% även vid k=100
- Detta är en inneboende egenskap hos diskreta rutnät, inte ett fel i implementationen
- Påverkan på aggregerade mått (t.ex. Spatial Isolation Index) är minimal

**Rekommendation:** 
- ✅ Alla k-värden kan användas i analyser
- ✅ För k≥1600 är precisionen i praktiken perfekt (R² > 0.998)

### 3. Beräkningstid

Funktionen är optimerad och mycket snabb:
- **10 000 lokationer:** ~40 sekunder
- Skalbar för stora dataset tack vare effektiv implementation

### 4. RutID i kartdata

Kartfunktionen kräver att geografi_data har en kolumn som heter 'RutID':

```r
# Om din kartdata inte har RutID, skapa den:
karta_rutor <- karta_rutor |>
  mutate(RutID = paste0(x_koordinat, y_koordinat))
```

## 📊 Output-format

### calculate_knn_segregation_fast()

Resultat-dataframe innehåller:

**Baskolumner:**
- `Id`: Rutans ID
- `EastWest`, `NorthSouth`: Koordinater
- `CountAllLocal`: Total befolkning i rutan
- `CountGroupLocal`: Målpopulation i rutan

**För varje k-värde (exempel k=12800):**
- `IntervalSumCountAll_12800`: Faktiskt antal personer räknade
- `IntervalSumCountGroup_12800`: Antal från målgrupp
- `IntervalRatio_12800`: Andel målgrupp (0-1)
- `IntervalDistance_12800`: Avstånd till längsta grannen (meter)

**Sammanfattande (baserat på högsta k):**
- `SumCountAll`, `SumCountGroup`, `Ratio`, `MaxDistance`

### berakna_isoleringsindex()

Resultat-tibble i långt format:
- `ar`: Årtal (eller "data")
- `k`: K-nivå
- `variabel`: "isoleringsindex" eller "genomsnitt"
- `varde`: Beräknat värde

### skapa_knn_karta()

Returnerar ggplot-objekt som kan:
- Visas direkt: `print(karta)`
- Sparas: `ggsave("karta.png", karta)`
- Modifieras vidare med ggplot2-funktioner

## 🔧 Felsökning

### Problem: "data måste vara ett sf-objekt eller data.frame"
```r
# Kontrollera datatyp
class(data)

# Konvertera om nödvändigt
data <- as.data.frame(data)
```

### Problem: "Kolumner saknas"
```r
# Lista alla kolumnnamn
names(data)

# Kontrollera att kolumnnamnen stämmer i funktionsanropet
```

### Problem: "geografi_data måste ha kolumn 'RutID'"
```r
# Skapa RutID-kolumn
karta_rutor <- karta_rutor |>
  mutate(RutID = paste0(x_öst_väst, y_nord_syd))
```

### Problem: "K-nivå finns inte i data"
```r
# Kontrollera vilka k-nivåer som finns
names(resultat) |> str_subset("IntervalRatio")

# Använd endast k-värden som beräknats
k_values <- c(1600, 6400, 12800)  # Måste finnas i resultat
```

### Problem: "NA i resultat"
```r
# För högt k-värde för området
max_k <- sum(data$total_pop) * 0.5
cat("Max rekommenderat k:", max_k)
```

## 📖 Referenser

**Akademiska:**
- Clark, W. A. V., & Östh, J. (2018). Measuring isolation across space and over time with new tools: Evidence from Californian metropolitan regions. *Environment and Planning B: Urban Analytics and City Science*, 45(6), 1038-1054.

**Mjukvara:**
- EquiPop (Uppsala universitet): http://equipop.kultgeog.uu.se

**Kodstandarder:**
- Kodprinciper för R – Göteborgs Stad
- Tidyverse style guide

## ✨ Funktioner

- ✅ EquiPop-kompatibel (R² > 0.99)
- ✅ Mycket snabb beräkning (10 000 lokationer på ~40 sekunder)
- ✅ Tre integrerade funktioner: beräkning, index, kartläggning
- ✅ Stöd för både sf-objekt och data.frame
- ✅ Include_self = TRUE som standard
- ✅ Informativa progress-meddelanden
- ✅ Hantering av flera k-värden samtidigt
- ✅ Tidsserieanalys med flera år
- ✅ Flexibel kartvisualisering med områdesgränser
- ✅ Fullständig dokumentation med roxygen2

## 📋 Checklista innan analys

- [ ] Data är data.frame eller sf-objekt
- [ ] Koordinater i meter (SWEREF99 TM rekommenderas)
- [ ] Inga negativa värden i befolkning
- [ ] Målgrupp ≤ total befolkning
- [ ] Inga saknade värden (NA)
- [ ] K-värden är rimliga (max ~5% av total befolkning)
- [ ] `include_self = TRUE` används
- [ ] Kartdata har kolumn 'RutID'

## 💡 Tips för bästa resultat

1. **Val av k-värden:**
   - Börja brett: c(100, 400, 1600, 6400, 12800)
   - Alla k-värden ger tillförlitliga resultat
   - Använd samma k-värden för jämförelser över tid

2. **Datakvalitet:**
   - Filtrera bort rutor med 0 befolkning
   - Kontrollera att koordinater är i meter
   - Validera att studiepopulation ≤ total population

3. **Kartvisualisering:**
   - Testa olika färgpaletter för tydlighet
   - Använd 5-7 kategorier för bäst läsbarhet
   - Överväg att lägga till områdesgränser för kontext
   - Spara i hög upplösning (dpi = 300)

4. **Reproducerbarhet:**
   - Dokumentera R-version, datum, k-värden
   - Spara både .xlsx och .rds format
   - Inkludera metadata i filnamn
   - Använd samma intervall för kartor över tid

5. **Tidsserieanalys:**
   - Använd namngivna listor för tydlighet
   - Behåll samma k-värden mellan år
   - Visualisera både isoleringsindex och genomsnitt

## 📞 Support

**För frågor om:**
- **Funktionerna**: Se roxygen-dokumentation i `knn_funktioner.R`
- **Metoden**: Clark & Östh (2018), EquiPop-dokumentation
- **Användning**: Exempel i denna README

## 📝 Licens

Öppen källkod - fri användning för forsknings- och analysändamål.

Vid användning, vänligen citera:
- Clark & Östh (2018) för metoden
- Göteborgs Stads kodprinciper för implementation

---

**Version:** 1.0  
**Datum:** 2025-01-13  
**Status:** ✅ Produktionsklar  
**Validering:** ✅ R² > 0.99 mot EquiPop