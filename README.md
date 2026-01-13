# K-NN Segregationsanalys (EquiPop-kompatibel)

En R-implementation av K-närmaste-grannar metoden för segregationsanalys enligt Clark & Östh (2018) och EquiPop-standarden.

## 🎯 Snabbstart

```r
# Ladda funktionen
source("knn_corrected_function.R")

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

# Spara
library(writexl)
write_xlsx(resultat, "knn_resultat.xlsx")
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

| k | R² | Max avvikelse | Rekommendation |
|---|-----|---------------|----------------|
| 100 | 0.962 | 17.5% | ⚠️ Använd med försiktighet |
| 400 | 0.990 | 10.0% | ⚠️ Använd med försiktighet |
| 1600 | 0.998 | 4.5% | ✅ Rekommenderas |
| 6400 | 1.000 | 1.8% | ✅ Perfekt |
| 12800 | 1.000 | 1.5% | ✅ Perfekt |
| 25600 | 1.000 | 0.6% | ✅ Perfekt |

## 📚 Dokumentation

### Huvudfiler

| Fil | Beskrivning |
|-----|-------------|
| `knn_corrected_function.R` | Huvudfunktionen |
| `KNN_KOMPLETT_DOKUMENTATION.R` | Omfattande dokumentation |
| `knn_include_self_documentation.md` | Förklaring av include_self |
| `jamfor_med_equipop.R` | Valideringsskript |
| `analys_k100_skillnader.R` | Djupanalys av k=100 |
| `test_include_self.R` | Verifiering av include_self |

### Snabbreferens

**Rekommenderade k-värden:**
```r
# Standard (täcker alla skalor)
k_standard <- c(100, 200, 400, 800, 1600, 3200, 6400, 12800, 25600)

# Rekommenderad för huvudanalyser
k_rekommenderad <- c(1600, 3200, 6400, 12800)

# Minimal (snabb testning)
k_test <- c(1600, 6400)
```

**Vanliga användningsfall:**
```r
# 1. Grundläggande analys
resultat <- calculate_knn_segregation_fast(
  data = data,
  id_col = "rutid",
  x_col = "x", y_col = "y",
  total_pop_col = "tot",
  study_pop_col = "grupp",
  k_values = c(1600, 6400, 12800),
  include_self = TRUE
)

# 2. Beräkna Spatial Isolation Index
SI <- sum(resultat$CountAllLocal * resultat$IntervalRatio_12800) / 
      sum(resultat$CountAllLocal)

# 3. Jämför olika grupper
grupper <- c("utrikes", "hogutb", "unga")
resultat_lista <- map(grupper, ~calculate_knn_segregation_fast(
  data = data,
  id_col = "rutid", x_col = "x", y_col = "y",
  total_pop_col = "tot",
  study_pop_col = .x,
  k_values = 12800,
  include_self = TRUE
))
```

## ⚠️ Viktigt att veta

### 1. Include_self = TRUE (EquiPop-standard)

**Alltid använd `include_self = TRUE`!**

Detta är skillnaden mellan EquiPop-metoden och vissa andra K-NN implementationer:
- ✅ `include_self = TRUE`: Lokalen räknas först (EquiPop-standard)
- ❌ `include_self = FALSE`: Hoppar över lokalen (ej EquiPop-kompatibel)

### 2. Ties vid låga k-värden

Vid **k=100-400** kan 1-2% av lokationer ha upp till 17% avvikelse från EquiPop.

**Orsak:** "Ties" - flera grannar på exakt samma avstånd i 100m rutnät. EquiPop och denna funktion väljer då i olika ordning.

**Lösning:** 
- ✅ Använd k≥1600 för huvudanalyser (R² > 0.998)
- ✅ Acceptera små avvikelser vid k=100-400
- Detta är inneboende i metoden, inte ett fel

### 3. Beräkningstid

| Antal lokationer | Ungefärlig tid |
|-----------------|----------------|
| 1,000 | ~10 sekunder |
| 10,000 | ~15 minuter |
| 50,000 | ~6 timmar |

För stora dataset (>20,000 lokationer): överväg att dela upp geografiskt.

## 📊 Output-format

Resultat-dataframe innehåller:

### Baskolumner
- `Id`: Rutans ID
- `EastWest`, `NorthSouth`: Koordinater
- `CountAllLocal`: Total befolkning i rutan
- `CountGroupLocal`: Målpopulation i rutan

### För varje k-värde (exempel k=12800)
- `IntervalSumCountAll_12800`: Faktiskt antal personer räknade
- `IntervalSumCountGroup_12800`: Antal från målgrupp
- `IntervalRatio_12800`: Andel målgrupp (0-1)
- `IntervalDistance_12800`: Avstånd till längsta grannen (meter)

### Sammanfattande (baserat på högsta k)
- `SumCountAll`, `SumCountGroup`, `Ratio`, `MaxDistance`

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

### Problem: "NA i resultat"
```r
# För högt k-värde för området
max_k <- sum(data$total_pop) * 0.5
cat("Max rekommenderat k:", max_k)
```

### Problem: "Tar för lång tid"
```r
# Testa med färre lokationer först
test_data <- data |> slice_sample(n = 1000)
```

## 🧪 Validering av dina resultat

```r
# 1. Kör både EquiPop och denna funktion på samma data
# 2. Använd valideringsskriptet
source("jamfor_med_equipop.R")

# 3. Kontrollera R²
# R² > 0.99 → Utmärkt
# R² > 0.95 → Bra
# R² < 0.95 → Kontrollera include_self = TRUE
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
- ✅ Stöd för både sf-objekt och data.frame
- ✅ Include_self = TRUE som standard
- ✅ Informativa progress-meddelanden
- ✅ Hantering av flera k-värden samtidigt
- ✅ Omfattande validering och test
- ✅ Fullständig dokumentation

## 📋 Checklista innan analys

- [ ] Data är data.frame eller sf-objekt
- [ ] Koordinater i meter (SWEREF99 TM rekommenderas)
- [ ] Inga negativa värden i befolkning
- [ ] Målgrupp ≤ total befolkning
- [ ] Inga saknade värden (NA)
- [ ] K-värden är rimliga (max ~5% av total befolkning)
- [ ] `include_self = TRUE` används

## 💡 Tips för bästa resultat

1. **Val av k-värden:**
   - Börja brett: c(100, 400, 1600, 6400, 12800)
   - För huvudanalyser: fokusera på k≥1600

2. **Datakvalitet:**
   - Kör `kontrollera_data()` före analys (se dokumentation)
   - Filtrera bort rutor med 0 befolkning

3. **Reproducerbarhet:**
   - Dokumentera R-version, datum, k-värden
   - Spara både .xlsx och .rds format
   - Inkludera metadata i filnamn

4. **Validering:**
   - Jämför alltid med EquiPop om möjligt
   - Kontrollera R² > 0.99 för k≥1600
   - Visualisera resultat för kvalitetskontroll

## 📞 Support

**För frågor om:**
- **Funktionen**: Se komplett dokumentation i `KNN_KOMPLETT_DOKUMENTATION.R`
- **Metoden**: Clark & Östh (2018), EquiPop-dokumentation
- **Användning**: Exempel i dokumentationen

## 📝 Licens

Öppen källkod - fri användning för forsknings- och analysändamål.

Vid användning, vänligen citera:
- Clark & Östh (2018) för metoden
- Göteborgs Stads kodprinciper för implementation

---

**Version:** 1.0  
**Datum:** 2024-12-19  
**Status:** ✅ Produktionsklar  
**Validering:** ✅ R² > 0.99 mot EquiPop
