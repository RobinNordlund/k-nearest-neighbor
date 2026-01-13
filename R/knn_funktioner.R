# =============================================================================
# FUNKTIONSSCRIPT
# =============================================================================


library(FNN)
library(tidyverse)
library(sf)



# Korrigerad K-NN funktion enligt EquiPop-standard
# Baserad på Clark & Östh (2018) och EquiPop-metoden
# 
# VIKTIG ÄNDRING: Inkluderar nu den lokala befolkningen i k-räkningen


#' Beräkna K närmaste grannar (EquiPop-kompatibel)
#'
#' @param data sf-objekt ELLER data.frame med koordinater (100m rutor)
#' @param id_col Kolumn med ID
#' @param x_col Kolumn med x-koordinat (öst-väst)
#' @param y_col Kolumn med y-koordinat (nord-syd)
#' @param total_pop_col Kolumn med total befolkning
#' @param study_pop_col Kolumn med studiepopulation
#' @param k_values Vektor med k-värden att beräkna
#' @param include_self Om TRUE, inkludera lokal befolkning (EquiPop-standard)
#'
#' @return data.frame med K-NN resultat
calculate_knn_segregation_fast <- function(data,
                                           id_col,
                                           x_col,
                                           y_col,
                                           total_pop_col,
                                           study_pop_col,
                                           k_values,
                                           include_self = TRUE) {
  
  # EXEMPEL PÅ ANVÄNDNING
  # ======================
  # library(sf)
  # library(tidyverse)
  # 
  # # Ladda din data
  # data <- st_read("rutor_100m.gpkg")
  # 
  # # Definiera k-värden
  # k_values <- c(100, 200, 400, 800, 1600, 3200, 6400, 12800, 25600)
  # 
  # # Kör K-NN analys (EquiPop-kompatibel)
  # resultat <- calculate_knn_segregation_fast(
  #   data = data,
  #   id_col = "rutid100_sw",
  #   x_col = "x_öst_väst",
  #   y_col = "y_nord_syd",
  #   total_pop_col = "antal_tot",
  #   study_pop_col = "antal_for",
  #   k_values = k_values,
  #   include_self = TRUE  # EquiPop-standard
  # )
  # 
  # # Spara resultat
  # library(writexl)
  # write_xlsx(resultat, "knn_resultat_corrected.xlsx")
  
  # ============================================================================
  # STEG 1: VALIDERING
  # ============================================================================
  cat("\n")
  cat("═══════════════════════════════════════════════════════════════════════\n")
  cat("  K-NN BERÄKNING (EquiPop-kompatibel)\n")
  cat("═══════════════════════════════════════════════════════════════════════\n\n")
  
  cat("Steg 1: Validerar input...\n")
  
  # Kolla om det är sf-objekt eller data.frame med koordinater
  is_sf <- inherits(data, "sf")
  
  if (is_sf) {
    cat("  ✓ Data är ett sf-objekt\n")
  } else if (is.data.frame(data)) {
    cat("  ✓ Data är en data.frame med koordinater\n")
  } else {
    stop("❌ data måste vara antingen ett sf-objekt eller en data.frame")
  }
  
  required_cols <- c(id_col, x_col, y_col, total_pop_col, study_pop_col)
  if (!all(required_cols %in% names(data))) {
    missing <- required_cols[!required_cols %in% names(data)]
    stop(sprintf("❌ Kolumner saknas: %s", paste(missing, collapse = ", ")))
  }
  cat(sprintf("  ✓ Alla kolumner hittade\n"))
  cat(sprintf("    - ID: '%s'\n", id_col))
  cat(sprintf("    - X: '%s'\n", x_col))
  cat(sprintf("    - Y: '%s'\n", y_col))
  cat(sprintf("    - Total pop: '%s'\n", total_pop_col))
  cat(sprintf("    - Studie pop: '%s'\n", study_pop_col))
  
  cat(sprintf("  ✓ Include self: %s (EquiPop-standard: TRUE)\n", include_self))
  cat(sprintf("  ✓ Antal lokationer: %d\n", nrow(data)))
  cat(sprintf("  ✓ K-värden: %s\n", paste(k_values, collapse = ", ")))
  
  # ============================================================================
  # STEG 2: FÖRBEREDELSE
  # ============================================================================
  cat("\nSteg 2: Förbereder data...\n")
  
  # Extrahera koordinater - fungerar för både sf och data.frame
  if (is_sf) {
    # Ta bort geometri och använd koordinatkolumnerna
    coords <- data |>
      st_drop_geometry() |>
      select(all_of(c(x_col, y_col))) |>
      as.matrix()
  } else {
    # Vanlig data.frame - använd koordinatkolumnerna direkt
    coords <- data |>
      select(all_of(c(x_col, y_col))) |>
      as.matrix()
  }
  
  cat("  ✓ Koordinater extraherade\n")
  
  # Skapa resultat-dataframe
  if (is_sf) {
    result <- data |>
      st_drop_geometry() |>
      select(all_of(c(id_col, x_col, y_col, total_pop_col, study_pop_col))) |>
      rename(
        Id = all_of(id_col),
        EastWest = all_of(x_col),
        NorthSouth = all_of(y_col),
        CountAllLocal = all_of(total_pop_col),
        CountGroupLocal = all_of(study_pop_col)
      )
  } else {
    result <- data |>
      select(all_of(c(id_col, x_col, y_col, total_pop_col, study_pop_col))) |>
      rename(
        Id = all_of(id_col),
        EastWest = all_of(x_col),
        NorthSouth = all_of(y_col),
        CountAllLocal = all_of(total_pop_col),
        CountGroupLocal = all_of(study_pop_col)
      )
  }
  cat("  ✓ Resultat-dataframe skapad\n")
  
  # Initiera resultatkolumner för varje k
  cat("  ✓ Initierar kolumner för k-värden: ")
  for (k in k_values) {
    result[[paste0("IntervalSumCountAll_", k)]] <- NA_real_
    result[[paste0("IntervalSumCountGroup_", k)]] <- NA_real_
    result[[paste0("IntervalRatio_", k)]] <- NA_real_
    result[[paste0("IntervalDistance_", k)]] <- NA_real_
  }
  cat("Klart!\n")
  
  # ============================================================================
  # STEG 3: K-NN BERÄKNING
  # ============================================================================
  cat("\nSteg 3: Beräknar K närmaste grannar...\n")
  cat("───────────────────────────────────────────────────────────────────────\n")
  
  start_time <- Sys.time()
  
  # För varje punkt
  for (i in seq_len(nrow(result))) {
    
    # Beräkna avstånd till alla andra punkter
    distances <- sqrt(
      (coords[, 1] - coords[i, 1])^2 + 
        (coords[, 2] - coords[i, 2])^2
    )
    
    # KRITISK FÖRÄNDRING: Inkludera lokal befolkning
    if (!include_self) {
      # Gammal metod: sätt avstånd till sig själv = Inf
      distances[i] <- Inf
    }
    # Ny metod: låt avstånd till sig själv = 0 (standard)
    
    # Sortera efter avstånd
    sorted_indices <- order(distances)
    sorted_distances <- distances[sorted_indices]
    
    # Extrahera populationer i sorterad ordning
    sorted_pop_all <- result$CountAllLocal[sorted_indices]
    sorted_pop_group <- result$CountGroupLocal[sorted_indices]
    
    # Kumulativ summa
    cumsum_all <- cumsum(sorted_pop_all)
    cumsum_group <- cumsum(sorted_pop_group)
    
    # För varje k-värde
    for (k in k_values) {
      
      # Hitta index där kumulativ summa >= k
      idx <- which(cumsum_all >= k)[1]
      
      if (!is.na(idx)) {
        result[[paste0("IntervalSumCountAll_", k)]][i] <- cumsum_all[idx]
        result[[paste0("IntervalSumCountGroup_", k)]][i] <- cumsum_group[idx]
        result[[paste0("IntervalRatio_", k)]][i] <- 
          cumsum_group[idx] / cumsum_all[idx]
        result[[paste0("IntervalDistance_", k)]][i] <- sorted_distances[idx]
      }
    }
    
    # Progress med tidsuppskattning
    if (i %% 500 == 0 || i == nrow(result)) {
      elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))
      avg_time_per_loc <- elapsed / i
      remaining_locs <- nrow(result) - i
      est_remaining <- avg_time_per_loc * remaining_locs
      
      cat(sprintf("  Progress: %5d / %d lokationer (%.1f%%) | Återstår: %.0f sek\n",
                  i, nrow(result), 100 * i / nrow(result), est_remaining))
    }
  }
  
  total_time <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))
  cat("───────────────────────────────────────────────────────────────────────\n")
  cat(sprintf("  ✓ K-NN beräkning klar! Total tid: %.1f sekunder\n", total_time))
  cat(sprintf("    (Genomsnitt: %.3f sek/lokaltion)\n", 
              total_time / nrow(result)))
  
  # ============================================================================
  # STEG 4: SLUTBEARBETNING
  # ============================================================================
  cat("\nSteg 4: Slutbearbetar resultat...\n")
  
  # Beräkna SumCountAll och SumCountGroup (max k-värde)
  max_k <- max(k_values)
  max_k_col <- paste0("IntervalSumCountAll_", max_k)
  
  result <- result |>
    mutate(
      SumCountAll = .data[[max_k_col]],
      SumCountGroup = .data[[paste0("IntervalSumCountGroup_", max_k)]],
      Ratio = SumCountGroup / SumCountAll,
      MaxDistance = .data[[paste0("IntervalDistance_", max_k)]]
    )
  
  cat("  ✓ Sammanfattande kolumner skapade\n")
  cat(sprintf("  ✓ Max k-värde använt: %d\n", max_k))
  
  # ============================================================================
  # SAMMANFATTNING
  # ============================================================================
  cat("\n")
  cat("═══════════════════════════════════════════════════════════════════════\n")
  cat("  SAMMANFATTNING\n")
  cat("═══════════════════════════════════════════════════════════════════════\n")
  cat(sprintf("  Lokationer bearbetade: %d\n", nrow(result)))
  cat(sprintf("  K-värden beräknade: %s\n", paste(k_values, collapse = ", ")))
  cat(sprintf("  Include self: %s\n", include_self))
  cat(sprintf("  Total tid: %.1f sekunder (%.3f sek/lok)\n", 
              total_time, total_time / nrow(result)))
  cat(sprintf("  Resultat-kolumner: %d\n", ncol(result)))
  cat("═══════════════════════════════════════════════════════════════════════\n\n")
  
  return(result)
}




#' Skapa karta över k-närmaste granne resultat
#'
#' Skapar en tematisk karta som visualiserar andelen av studiepopulation
#' för en specifik k-nivå. Funktionen kombinerar k-NN resultat med
#' geografiska data och skapar en färgkodad karta enligt intervall.
#'
#' @param knn_data Data frame med k-NN resultat (från calculate_knn_segregation_fast)
#' @param geografi_data sf-objekt med kartgeometri, måste ha kolumn 'RutID'
#' @param k K-nivå att visualisera (t.ex. 100, 400, 1600)
#' @param intervall Numerisk vektor med gränsvärden för kategorier
#' @param etiketter Teckenvector med etiketter för varje kategori
#' @param fargpalett Teckenvector med färger (hex-koder)
#' @param titel Kartans huvudtitel
#' @param fyllnad_etikett Etikett för legend (fill-etikett)
#' @param omrades_granser Optional sf-objekt med geografiska gränser att lägga över
#'   (t.ex. primärområden, stadsdelar, kommundelar)
#' @param artal Årtal för datan (default: NULL, inget år visas)
#'
#' @return ggplot-objekt
#'
#' @examples
#' \dontrun{
#' # Med primärområdesgränser
#' skapa_knn_karta(
#'   knn_data = for_gym_2022_resultat,
#'   geografi_data = karta_rutor,
#'   k = 400,
#'   intervall = c(0, 10, 20, 30, 40, 50, 100),
#'   etiketter = c("0-10%", "10-20%", "20-30%", "30-40%", "40-50%", "50-100%"),
#'   fargpalett = c("#E8F5E9", "#C8E6C9", "#A5D6A7", "#81C784", "#66BB6A", "#4CAF50"),
#'   titel = "Andel personer med utländsk bakgrund",
#'   fyllnad_etikett = "Andel (%)",
#'   omrades_granser = primaromraden_granser,
#'   artal = 2022
#' )
#' 
#' # Med stadsdelsgränser istället
#' skapa_knn_karta(
#'   knn_data = for_gym_2022_resultat,
#'   geografi_data = karta_rutor,
#'   k = 1600,
#'   intervall = c(0, 25, 50, 75, 100),
#'   etiketter = c("0-25%", "25-50%", "50-75%", "75-100%"),
#'   fargpalett = c("#fee5d9", "#fcae91", "#fb6a4a", "#cb181d"),
#'   titel = "Andel personer med utländsk bakgrund",
#'   fyllnad_etikett = "Andel (%)",
#'   omrades_granser = stadsdelar_granser,
#'   artal = 2022
#' )
#' }
skapa_knn_karta <- function(knn_data,
                            geografi_data,
                            k,
                            intervall,
                            etiketter,
                            fargpalett,
                            titel,
                            fyllnad_etikett,
                            omrades_granser = NULL,
                            artal = NULL) {
  
  # ============================================================================
  # VALIDERING
  # ============================================================================
  
  # Validera k-värde
  ratio_kolumn <- paste0("IntervalRatio_", k)
  if (!ratio_kolumn %in% names(knn_data)) {
    stop(glue::glue("K-nivå {k} finns inte i data. Tillgängliga kolumner: {paste(names(knn_data), collapse = ', ')}"))
  }
  
  # Validera geografi
  if (!inherits(geografi_data, "sf")) {
    stop("geografi_data måste vara ett sf-objekt")
  }
  
  if (!"RutID" %in% names(geografi_data)) {
    stop("geografi_data måste ha kolumn 'RutID'")
  }
  
  # Validera intervall och etiketter
  if (length(intervall) != length(etiketter) + 1) {
    stop(glue::glue(
      "Antal intervall ({length(intervall)}) måste vara antal etiketter ({length(etiketter)}) + 1"
    ))
  }
  
  if (length(fargpalett) != length(etiketter)) {
    stop(glue::glue(
      "Antal färger ({length(fargpalett)}) måste matcha antal etiketter ({length(etiketter)})"
    ))
  }
  
  # ============================================================================
  # FÖRBEREDELSE AV DATA
  # ============================================================================
  
  # Skapa RutID och extrahera ratio
  data_k_niva <- knn_data |>
    mutate(RutID = paste0(EastWest, NorthSouth)) |>
    select(RutID, IntervalRatio = all_of(ratio_kolumn)) |>
    mutate(
      # Konvertera till numeriskt och procent
      IntervalRatio = as.numeric(gsub(",", ".", IntervalRatio)) * 100,
      # Skapa kategorier
      andel_kategori = cut(
        IntervalRatio,
        breaks = intervall,
        labels = etiketter,
        include.lowest = TRUE
      )
    )
  
  # Koppla med geografi
  kart_data <- geografi_data |>
    left_join(data_k_niva, by = "RutID")
  
  # ============================================================================
  # SKAPA KARTA
  # ============================================================================
  
  # Bygg undertitel
  undertitel <- if (!is.null(artal)) {
    glue::glue("År {artal}, k = {format(k, big.mark = ' ')}")
  } else {
    glue::glue("k = {format(k, big.mark = ' ')}")
  }
  
  # Skapa baskarta
  p <- ggplot(data = kart_data) +
    geom_sf(
      aes(geometry = geometry, fill = andel_kategori),
      color = NA
    ) +
    scale_fill_manual(
      values = fargpalett,
      na.value = scales::alpha("white", 0.5),
      drop = FALSE
    ) +
    labs(
      title = titel,
      subtitle = undertitel,
      caption = "Källa: SCB, med bearbetning av stadsledningskontoret",
      fill = fyllnad_etikett
    ) +
    theme_void() +
    theme(
      plot.title = element_text(size = 14, face = "bold"),
      plot.subtitle = element_text(size = 12, face = "italic"),
      legend.title = element_text(size = 10, face = "bold"),
      legend.position = "right"
    )
  
  # Lägg till områdesgränser om de finns
  if (!is.null(omrades_granser)) {
    if (!inherits(omrades_granser, "sf")) {
      warning("omrades_granser är inte ett sf-objekt och ignoreras")
    } else {
      p <- p +
        geom_sf(
          data = omrades_granser,
          color = "darkgrey",
          fill = NA,
          linewidth = 0.3
        )
    }
  }
  
  return(p)
}



#' Beräkna spatial isolationsindex över tid
#'
#' Beräknar isolationsindex (SI) enligt Clark & Östh (2018) för flera
#' K-nivåer och år. Indexet mäter sannolikheten att träffa en person
#' från samma studiegrupp bland de k närmaste grannarna.
#'
#' Formel: SI_k = Σ(x_i × (x_ik / k)) / Σ(x_i)
#' där:
#'   x_i = studiegrupp i ruta i
#'   x_ik = studiegrupp bland k närmaste grannar
#'   k = antal närmaste grannar
#'
#' @param data_list Namngiven lista med data frames, ett per år.
#'   Kan också vara en enskild data frame för ett år.
#'   Varje data frame måste innehålla:
#'   - CountGroupLocal: studiepopulation i ruta
#'   - CountAllLocal: total population i ruta
#'   - IntervalSumCountGroup_k: studiepopulation bland k grannar
#'   - IntervalSumCountAll_k: total population bland k grannar
#' @param k_nivaer Vektor med k-värden att beräkna för
#'
#' @return Tibble i långt format med kolumner:
#'   - ar: årtal (eller "data" om inget år angavs)
#'   - k: k-nivå
#'   - variabel: "isoleringsindex" eller "genomsnitt"
#'   - varde: beräknat värde
#'
#' @examples
#' \dontrun{
#' # Flera år
#' data_list <- list(
#'   `2022` = for_gym_2022_resultat,
#'   `2017` = for_gym_2017_resultat
#' )
#' 
#' resultat <- berakna_isoleringsindex(
#'   data_list = data_list,
#'   k_nivaer = c(100, 400, 1600, 6400)
#' )
#' 
#' # Ett enskilt år
#' resultat_2022 <- berakna_isoleringsindex(
#'   data_list = for_gym_2022_resultat,
#'   k_nivaer = c(100, 400, 1600, 6400)
#' )
#' 
#' # Eller med lista för ett år
#' resultat_2022 <- berakna_isoleringsindex(
#'   data_list = list(`2022` = for_gym_2022_resultat),
#'   k_nivaer = c(100, 400, 1600, 6400)
#' )
#' }
berakna_isoleringsindex <- function(data_list, k_nivaer) {
  
  # ============================================================================
  # HANTERA INPUT - Tillåt både lista och enskild data frame
  # ============================================================================
  
  # Om data_list är en data frame, gör om till lista
  if (is.data.frame(data_list)) {
    data_list <- list(data = data_list)
    cat("ℹ️ En enskild data frame tillhandahölls - behandlar som ett år\n\n")
  }
  
  # ============================================================================
  # VALIDERING
  # ============================================================================
  
  # Validera input
  if (!is.list(data_list) || is.null(names(data_list))) {
    stop("data_list måste vara antingen:\n",
         "  1) En namngiven lista med data frames (för flera år)\n",
         "  2) En enskild data frame (för ett år)")
  }
  
  if (length(data_list) == 0) {
    stop("data_list är tom")
  }
  
  if (!is.numeric(k_nivaer) || length(k_nivaer) == 0) {
    stop("k_nivaer måste vara en numerisk vektor med minst ett värde")
  }
  
  # Validera att alla data frames har rätt kolumner
  obligatoriska_kolumner <- c("CountGroupLocal", "CountAllLocal")
  
  for (ar in names(data_list)) {
    data <- data_list[[ar]]
    
    if (!is.data.frame(data)) {
      stop(glue::glue("Data för år {ar} är inte en data frame"))
    }
    
    saknade_kolumner <- setdiff(obligatoriska_kolumner, names(data))
    if (length(saknade_kolumner) > 0) {
      stop(glue::glue(
        "Data för år {ar} saknar obligatoriska kolumner: {paste(saknade_kolumner, collapse = ', ')}"
      ))
    }
  }
  
  # ============================================================================
  # INTERN HJÄLPFUNKTION
  # ============================================================================
  
  #' Beräkna isoleringsindex för ett specifikt år och k-värde
  #'
  #' @param data Data frame med k-NN resultat
  #' @param k K-nivå att beräkna för
  #'
  #' @return Tibble med k, isoleringsindex och genomsnitt
  berakna_index_ett_k <- function(data, k) {
    
    # Kolumnnamn för detta k
    group_col <- paste0("IntervalSumCountGroup_", k)
    total_col <- paste0("IntervalSumCountAll_", k)
    
    # Validera att kolumnerna finns
    if (!all(c(group_col, total_col) %in% names(data))) {
      stop(glue::glue(
        "Kolumner för k = {k} saknas. Behöver: {group_col}, {total_col}"
      ))
    }
    
    # Beräkna isoleringsindex enligt formeln
    # SI_k = Σ(x_i × (x_ik / k)) / Σ(x_i)
    taljare <- sum(
      data$CountGroupLocal * (data[[group_col]] / data[[total_col]]),
      na.rm = TRUE
    )
    
    namnare <- sum(data$CountGroupLocal, na.rm = TRUE)
    
    if (namnare == 0) {
      warning(glue::glue("Nämnare är 0 för k = {k}, returnerar NA"))
      isoleringsindex <- NA_real_
    } else {
      isoleringsindex <- taljare / namnare
    }
    
    # Beräkna genomsnittlig andel i hela området
    studiegrupp_total <- sum(data$CountGroupLocal, na.rm = TRUE)
    population_total <- sum(data$CountAllLocal, na.rm = TRUE)
    
    if (population_total == 0) {
      warning("Total population är 0, returnerar NA för genomsnitt")
      genomsnitt_kommun <- NA_real_
    } else {
      genomsnitt_kommun <- studiegrupp_total / population_total
    }
    
    # Returnera resultat
    tibble(
      k = k,
      isoleringsindex = isoleringsindex,
      genomsnitt = genomsnitt_kommun
    )
  }
  
  # ============================================================================
  # BERÄKNING
  # ============================================================================
  
  # Iterera över alla år och k-nivåer
  resultat <- map_dfr(names(data_list), function(ar) {
    
    cat(glue::glue("Beräknar för {ar}...\n"))
    
    data <- data_list[[ar]]
    
    # Beräkna för alla k-nivåer detta år
    ar_resultat <- map_dfr(k_nivaer, ~ berakna_index_ett_k(data, .x)) |>
      mutate(ar = ar)
    
    return(ar_resultat)
  })
  
  # ============================================================================
  # FORMAT OM TILL LÅNGT FORMAT
  # ============================================================================
  
  resultat_lang <- resultat |>
    pivot_longer(
      cols = c(isoleringsindex, genomsnitt),
      names_to = "variabel",
      values_to = "varde"
    ) |>
    select(ar, k, variabel, varde)
  
  cat("\n✓ Beräkning klar!\n")
  cat(glue::glue("  Antal år: {length(unique(resultat_lang$ar))}\n"))
  cat(glue::glue("  Antal k-nivåer: {length(unique(resultat_lang$k))}\n"))
  cat(glue::glue("  Totalt antal rader: {nrow(resultat_lang)}\n\n"))
  
  return(resultat_lang)
}
