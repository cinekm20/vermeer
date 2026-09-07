extends Node
## Lekki zestaw testów uruchamiany bez edytora, prosto na tym samym kodzie
## co gra (nie na kopii formuł, jak tools/balance_simulation.py w Pythonie).
##
## `extends Node` + scena tests/run_tests.tscn, NIE `extends SceneTree` +
## `--script` — ten drugi wariant wyglądał prościej, ale Godot dokumentuje
## `--script` jako "uruchom skrypt bez potrzeby projektu": świadomie pomija
## pełny boot projektu (czyli też autoloady), więc każde użycie autoloadu
## (Cities, Calendar, ...) failowało z "Identifier not found" mimo że
## dokładnie ten sam kod działa normalnie w grze. Scena + pełny boot
## projektu = autoloady dostępne tak samo jak wszędzie indziej.
##
## Uruchomienie lokalnie (gdy będzie już Godot pod ręką):
##   godot --headless --path . res://tests/run_tests.tscn
##
## W CI odpalane automatycznie przez .github/workflows/godot-check.yml.
## Kod wyjścia 1, jeśli którykolwiek test nie przejdzie.

var failures: int = 0
var total: int = 0

const RaceTrackScript := preload("res://scripts/ui/RaceTrackView.gd")
const ExpertisePuzzleScript := preload("res://scripts/ui/ExpertisePuzzle.gd")
const HeistViewScript := preload("res://scripts/ui/HeistView.gd")


func _ready() -> void:
	print("=== The Forger: Retro Tycoon — testy autoloadów ===")

	_test_cities_direct_travel()
	_test_cities_route_via_transfer()
	_test_river_adjacency_detection()
	_test_harvest_requires_elapsed_time()
	_test_harvest_scales_with_time()
	_test_forgery_by_duplicate_number()
	_test_forgery_texture_falls_back_when_missing()
	_test_paintings_numbers_with_fake_variant()
	_test_ai_players_rival_names_randomized()
	_test_win_threshold_easy_mode()
	_test_difficulty_level_multipliers()
	_test_forward_contract_penalty_on_failure()
	_test_players_hotseat_swap()
	_test_players_turn_follows_earliest_date()
	_test_art_school_course_ends_turn_after_applying_effects()
	_test_security_bodyguard_and_gangster()
	_test_travel_vehicle_choice()
	_test_travel_completes_in_one_animation()
	_test_auctions_schedule()
	_test_auctions_cap_turn_advance()
	_test_auctions_present_players()
	_test_ship_and_sell_all_across_plantations()
	_test_find_plantation_index()
	_test_plantation_grows_multiple_crops_at_once()
	_test_plant_tile_requires_ownership()
	_test_plantation_crisis_from_unpaid_wages()
	_test_plantation_lost_after_repeated_crisis_hits()
	_test_plantation_tiles_are_exclusive_between_players()
	_test_water_pump_prevents_weather_crisis_and_boosts_yield()
	_test_difficulty_scales_plantation_yield()
	_test_hire_right_before_harvest_no_longer_gives_full_yield()
	_test_difficulty_very_easy_disables_weather_risk()
	_test_goods_spoil_after_a_year_in_storage()
	_test_contraband_crop_restricted_and_confiscatable()
	_test_bonus_paintings_available_and_awardable()
	_test_auctions_can_select_bonus_painting_when_available()
	_test_auctions_weighted_draw_favors_less_seen_numbers()
	_test_world_events_reform_queued()
	_test_market_shock_crash_and_boom()
	_test_yearly_report_populated_on_new_year()
	_test_grant_new_year_to_random_player_awards_money_and_avoids_duplicate_paintings()
	_test_grant_new_year_credits_correct_player_in_multiplayer()
	_test_new_year_lottery_populates_pending_after_new_year()
	_test_players_gender_and_avatar_selection()
	_test_price_history_for_charts()
	_test_players_days_diverge()
	_test_races_cooldown_between_bets()
	_test_horses_odds_drift_and_bounds()
	_test_horses_odds_shared_by_day()
	_test_race_track_winner_finishes_first()
	_test_expertise_puzzle_reveal_stable_and_monotonic()
	_test_gangsters_chance_drift_and_bounds()
	_test_gangsters_chance_shared_by_day()
	_test_gangster_attempt_resolve_apply_consequences()
	_test_heist_view_outcome_matches_precomputed_result()
	_test_travel_map_zoom_clamped_and_pins_scale_damped()
	_test_travel_map_pan_clamped_when_not_zoomed()
	_test_travel_map_zoom_keeps_focal_point_fixed()
	_test_travel_map_pinch_zoom_via_touch_events()
	_test_shared_price_by_day()
	_test_catching_up_player_does_not_double_world_drift()
	_test_catching_up_player_gets_full_personal_consequences()
	_test_catching_up_player_completes_travel()
	_test_all_scene_scripts_parse_without_error()

	print("\n=== Wynik: %d/%d testów przeszło ===" % [total - failures, total])
	get_tree().quit(1 if failures > 0 else 0)


func _assert(condition: bool, description: String) -> void:
	total += 1
	if condition:
		print("  OK   %s" % description)
	else:
		failures += 1
		print("  FAIL %s" % description)


func _test_cities_direct_travel() -> void:
	print("-- Cities: bezpośrednie trasy (docs/MECHANIKI_EKONOMICZNE.md pkt. 2.1) --")
	_assert(is_equal_approx(Cities.get_travel_days("richmond", "st_louis"), 1.9), "Richmond -> St. Louis = 1,9 dnia")
	_assert(is_equal_approx(Cities.get_travel_days("st_louis", "richmond"), 1.9), "macierz symetryczna: St. Louis -> Richmond też 1,9 dnia")
	_assert(Cities.get_travel_days("richmond", "richmond") == 0.0, "to samo miasto = 0 dni")


func _test_cities_route_via_transfer() -> void:
	print("-- Cities: trasa z przesiadką (Dijkstra) --")
	# Berlin nie ma bezpośredniej trasy do St. Louis w danych źródłowych —
	# musi znaleźć trasę przez co najmniej jedno miasto pośrednie.
	_assert(Cities.get_travel_days("berlin", "st_louis") < 0.0, "brak bezpośredniej trasy Berlin -> St. Louis w danych źródłowych")
	var result := Cities.find_route("berlin", "st_louis")
	_assert(not result["path"].is_empty(), "mimo to find_route znajduje jakąś trasę")
	_assert(result["path"][0] == "berlin", "trasa zaczyna się w Berlinie")
	_assert(result["path"][-1] == "st_louis", "trasa kończy się w St. Louis")
	_assert(result["path"].size() > 2, "trasa wymaga przynajmniej jednej przesiadki")
	_assert(result["total_days"] > 0.0, "całkowity czas podróży dodatni")


func _test_river_adjacency_detection() -> void:
	print("-- PlayerPlantations: wykrywanie sąsiedztwa z rzeką --")
	PlayerPlantations.reset_new_game()
	var idx := PlayerPlantations.found_plantation("richmond")
	# Rzeka jest teraz losowa (patrz _generate_river) i wspólna dla całego
	# miasta (PlayerPlantations.city_grids, nie per gracz) — dla
	# deterministycznego testu logiki sąsiedztwa nadpisujemy ją ręcznie:
	# prosta kolumna x=2, GRID_SIZE = 16 -> tile_index = y*16+x.
	var river: Array[bool] = []
	river.resize(PlayerPlantations.GRID_SIZE * PlayerPlantations.GRID_SIZE)
	river.fill(false)
	river[2] = true  # pole (2,0)
	PlayerPlantations.city_grids["richmond"]["river"] = river

	_assert(PlayerPlantations.is_river_tile(idx, 2), "pole (2,0) to sama rzeka")
	_assert(not PlayerPlantations.is_adjacent_to_river(idx, 2), "rzeka nie jest 'sąsiadem samej siebie' (nieistotne w grze — rzeka i tak nie do kupienia)")
	_assert(PlayerPlantations.is_adjacent_to_river(idx, 1), "pole (1,0), tuż obok rzeki -> sąsiaduje")
	_assert(PlayerPlantations.is_adjacent_to_river(idx, 3), "pole (3,0), po drugiej stronie rzeki -> też sąsiaduje")
	_assert(not PlayerPlantations.is_adjacent_to_river(idx, 5), "pole (5,0), daleko od rzeki -> nie sąsiaduje")


func _test_harvest_requires_elapsed_time() -> void:
	print("-- PlayerPlantations: zbiory wymagają upływu czasu (regresja na naprawiony exploit) --")
	PlayerPlantations.reset_new_game()
	Calendar.reset_new_game()
	Economy.reset_new_game()
	Players.reset_new_game(1)
	var idx := PlayerPlantations.found_plantation("richmond")
	PlayerPlantations.city_grids["richmond"]["river"].fill(false)  # rzeka losowa - pole 0 musi być pewne do kupienia
	PlayerPlantations.plantations[idx]["has_water_pump"] = true  # odporność na losowe susze/powodzie — test ma być deterministyczny
	PlayerPlantations.buy_tile(idx, 0)
	PlayerPlantations.plant_tile(idx, 0, "tobacco")
	PlayerPlantations.hire_workers(idx, 500)

	Players.advance_active_player_time(30)
	var first_harvest: int = PlayerPlantations.harvest(idx).get("tobacco", 0)
	var second_harvest: int = PlayerPlantations.harvest(idx).get("tobacco", 0)  # bez upływu czasu od pierwszych zbiorów

	_assert(first_harvest > 0, "pierwsze zbiory po 30 dniach dają plon > 0")
	_assert(second_harvest == 0, "powtórne zbiory BEZ upływu czasu dają 0 (exploit z sesji naprawiony)")


func _test_harvest_scales_with_time() -> void:
	print("-- PlayerPlantations: plon skaluje się proporcjonalnie do czasu --")
	# Oba pomiary w tym samym miesiącu (dni 1-29 = styczeń, stały czynnik
	# sezonowy), żeby sezonowość nie zaburzała porównania.
	PlayerPlantations.reset_new_game()
	Calendar.reset_new_game()
	Economy.reset_new_game()
	Players.reset_new_game(1)
	var idx := PlayerPlantations.found_plantation("richmond")
	PlayerPlantations.city_grids["richmond"]["river"].fill(false)  # rzeka losowa - pole 0 musi być pewne do kupienia
	PlayerPlantations.plantations[idx]["has_water_pump"] = true  # odporność na losowe susze/powodzie — test ma być deterministyczny
	PlayerPlantations.buy_tile(idx, 0)
	PlayerPlantations.plant_tile(idx, 0, "tobacco")
	PlayerPlantations.hire_workers(idx, 500)
	Players.advance_active_player_time(10)
	var harvest_10_days: int = PlayerPlantations.harvest(idx).get("tobacco", 0)

	PlayerPlantations.reset_new_game()
	Calendar.reset_new_game()
	Economy.reset_new_game()
	Players.reset_new_game(1)
	idx = PlayerPlantations.found_plantation("richmond")
	PlayerPlantations.city_grids["richmond"]["river"].fill(false)  # rzeka losowa - pole 0 musi być pewne do kupienia
	PlayerPlantations.plantations[idx]["has_water_pump"] = true  # odporność na losowe susze/powodzie — test ma być deterministyczny
	PlayerPlantations.buy_tile(idx, 0)
	PlayerPlantations.plant_tile(idx, 0, "tobacco")
	PlayerPlantations.hire_workers(idx, 500)
	Players.advance_active_player_time(20)
	var harvest_20_days: int = PlayerPlantations.harvest(idx).get("tobacco", 0)

	_assert(harvest_20_days > harvest_10_days, "20 dni upraw daje więcej plonu niż 10 dni (ten sam miesiąc)")
	_assert(absi(harvest_20_days - harvest_10_days * 2) <= 2, "plon skaluje się z grubsza liniowo z czasem (20d ≈ 2×10d)")


func _test_plantation_grows_multiple_crops_at_once() -> void:
	print("-- PlayerPlantations: jedna plantacja uprawia kilka różnych roślin naraz --")
	PlayerPlantations.reset_new_game()
	Calendar.reset_new_game()
	Economy.reset_new_game()
	Players.reset_new_game(1)
	## "rio" (nie "richmond") — richmond ma bazowy plon kawy tylko 22 (patrz
	## Crops.REFERENCE_YIELD), więc przy JEDNYM polu kawy calculate_harvest
	## liczy ~0,3 jednostki, co int() ucina do 0 i test fałszywie failuje
	## (nie błąd gry — richmond to po prostu miasto tytoniowe, nie kawowe).
	## Rio ma wysoki bazowy plon OBU upraw (kawa 220, tytoń 396), więc nawet
	## po 1 polu każdej z nich wynik zaokrągla się w górę od zera.
	var idx := PlayerPlantations.found_plantation("rio")
	PlayerPlantations.city_grids["rio"]["river"].fill(false)
	PlayerPlantations.plantations[idx]["has_water_pump"] = true  # odporność na losowe susze/powodzie — test ma być deterministyczny
	PlayerPlantations.hire_workers(idx, 500)

	PlayerPlantations.buy_tile(idx, 0)
	PlayerPlantations.buy_tile(idx, 1)
	PlayerPlantations.plant_tile(idx, 0, "tobacco")
	PlayerPlantations.plant_tile(idx, 1, "coffee")

	_assert(PlayerPlantations.get_planted_tile_count(idx, "tobacco") == 1, "1 pole obsiane tytoniem")
	_assert(PlayerPlantations.get_planted_tile_count(idx, "coffee") == 1, "1 pole obsiane kawą")
	_assert(PlayerPlantations.get_planted_tile_count(idx, "tea") == 0, "0 pól obsianych herbatą")

	Players.advance_active_player_time(30)
	var amounts := PlayerPlantations.harvest(idx)
	_assert(amounts.get("tobacco", 0) > 0, "zbiory obejmują tytoń")
	_assert(amounts.get("coffee", 0) > 0, "zbiory obejmują kawę JEDNOCZEŚNIE z tytoniem")


func _test_plant_tile_requires_ownership() -> void:
	print("-- PlayerPlantations: plant_tile wymaga wcześniejszego kupienia pola --")
	PlayerPlantations.reset_new_game()
	Players.reset_new_game(1)
	var idx := PlayerPlantations.found_plantation("richmond")
	PlayerPlantations.city_grids["richmond"]["river"].fill(false)
	_assert(not PlayerPlantations.plant_tile(idx, 0, "tobacco"), "nie da się zasadzić na polu, którego gracz jeszcze nie kupił")


## "richmond" (region north_america) celowo — Cities.REGION_UNREST_CHANCE_PER_WEEK
## nie ma dla niego wpisu, więc zamieszki nigdy nie ingerują w ten test.
## `lost` w apply_player_days_elapsed odzwierciedla WYŁĄCZNIE "czy PLANTACJA
## PADŁA CAŁKOWICIE" (crisis_hits >= próg), NIE "czy jakikolwiek kryzys już
## zaszedł w tym wywołaniu" — pojedyncze, niefatalne uderzenie (jak tu:
## crisis_hits 0->1) zostawia `lost=false`, więc KOLEJNE, niezależne
## sprawdzenia (zamieszki, a teraz też ryzyko pogodowe — patrz
## PlayerPlantations.WEATHER_RISK_CHANCE_PER_WEEK, jedyne z trzech BEZ
## ograniczenia do regionu) nadal by się wykonały tego samego dnia. Pompa
## wodna (has_water_pump=true) blokuje tę trzecią, region-niezależną
## możliwość, żeby test sprawdzał DOKŁADNIE jedno, przewidywalne uderzenie —
## ten sam powód, dla którego _test_security_bodyguard_and_gangster nigdy
## nie wywołuje apply_player_days_elapsed.
func _test_plantation_crisis_from_unpaid_wages() -> void:
	print("-- PlayerPlantations: strajk (brak wypłat) zabiera zapasy i połowę robotników --")
	## VERY_HARD (mnożnik ryzyka 1.0) — test sprawdza SUROWOŚĆ skutków strajku
	## (dokładnie połowa załogi, patrz CRISIS_WORKER_LOSS_RATIO), która na
	## niższych poziomach trudności jest CELOWO łagodniejsza (Difficulty.
	## risk_multiplier w _apply_crisis_hit) — bez tego przypięcia wynik
	## zależałby od tego, jaki poziom trudności zostawiły wcześniejsze testy.
	Difficulty.reset_new_game(Difficulty.Level.VERY_HARD)
	PlayerPlantations.reset_new_game()
	Economy.reset_new_game()
	WorldEvents.reset_new_game()
	Players.reset_new_game(1)
	var idx := PlayerPlantations.found_plantation("richmond")
	PlayerPlantations.plantations[idx]["has_water_pump"] = true  # odporność na losowe susze/powodzie — inaczej sporadyczny DRUGI hit tego samego dnia psuje asercje poniżej
	PlayerPlantations.hire_workers(idx, 10)
	PlayerPlantations.plantations[idx]["stored_goods"]["tobacco"] = 50
	Economy.player_money = -1.0  # już na minusie — jedna dowolna płaca utrzyma dług

	PlayerPlantations.apply_player_days_elapsed(1)

	_assert(int(PlayerPlantations.plantations[idx]["stored_goods"].get("tobacco", 0)) == 0, "zapasy skonfiskowane po strajku")
	_assert(int(PlayerPlantations.plantations[idx]["workers"]) == 5, "połowa robotników uciekła (10 -> 5)")
	_assert(int(PlayerPlantations.plantations[idx]["crisis_hits"]) == 1, "licznik uderzeń kryzysu wzrósł do 1")
	_assert(WorldEvents.has_pending(), "zdarzenie trafiło do kolejki WorldEvents")
	var reported_event := WorldEvents.consume_next()
	_assert(reported_event.get("kind", "") == "crisis" and reported_event.get("cause", "") == "wages", "zdarzenie oznaczone jako kryzys z przyczyny 'wages'")
	_assert(not reported_event.get("plantation_lost", true), "pojedynczy strajk NIE zabiera jeszcze całej plantacji")


func _test_plantation_lost_after_repeated_crisis_hits() -> void:
	print("-- PlayerPlantations: powtarzające się strajki zabierają całą plantację i zwalniają jej pola --")
	## VERY_HARD — test liczy DOKŁADNIE CRISIS_HITS_TO_LOSE_PLANTATION uderzeń
	## i sprawdza, że tyle wystarcza; na niższych poziomach trudności próg jest
	## CELOWO wyższy (Difficulty.risk_multiplier w _apply_crisis_hit robi
	## plantację bardziej wybaczającą), więc bez tego przypięcia pętla poniżej
	## mogłaby nie wystarczyć.
	Difficulty.reset_new_game(Difficulty.Level.VERY_HARD)
	PlayerPlantations.reset_new_game()
	Economy.reset_new_game()
	WorldEvents.reset_new_game()
	Players.reset_new_game(1)
	var idx := PlayerPlantations.found_plantation("richmond")
	PlayerPlantations.plantations[idx]["has_water_pump"] = true  # odporność na losowe susze/powodzie — inaczej sporadyczny dodatkowy hit psuje liczenie dokładnie 3 uderzeń
	PlayerPlantations.city_grids["richmond"]["river"].fill(false)
	PlayerPlantations.buy_tile(idx, 0)
	PlayerPlantations.hire_workers(idx, 10)

	for i in PlayerPlantations.CRISIS_HITS_TO_LOSE_PLANTATION:
		Economy.player_money = -1.0  # utrzymaj dług przed każdym kolejnym uderzeniem
		PlayerPlantations.apply_player_days_elapsed(1)

	_assert(PlayerPlantations.find_plantation_index("richmond") == -1, "po %d uderzeniach kryzysu plantacja znika z tablicy" % PlayerPlantations.CRISIS_HITS_TO_LOSE_PLANTATION)
	_assert(int(PlayerPlantations.city_grids["richmond"]["tile_owner"][0]) == -1, "utracone pole wraca do wspólnej puli (wolne dla kogokolwiek)")


## Zgłoszone przez użytkownika: "plantacje w danym mieście powinny być
## wygenerowane na początku gry i powinny być wspólne dla wszystkich
## graczy, czyli ten który zasieje w lepszym miejscu będzie miał lepsze
## plony" — sedno tego wymagania: pole zajęte przez JEDNEGO gracza musi
## być niedostępne dla RESZTY, dopóki go nie straci.
func _test_plantation_tiles_are_exclusive_between_players() -> void:
	print("-- PlayerPlantations: pola siatki miasta są na wyłączność między graczami --")
	PlayerPlantations.reset_new_game()
	Economy.reset_new_game()
	Players.reset_new_game(2)
	PlayerPlantations.city_grids["richmond"]["river"].fill(false)

	# Gracz 1 (aktywny domyślnie, active_index=0) zajmuje pole 0.
	var idx_p1 := PlayerPlantations.found_plantation("richmond")
	_assert(PlayerPlantations.buy_tile(idx_p1, 0), "gracz 1 kupuje pole 0")

	# Przesuń dzień gracza 1 do przodu, żeby pass_turn_to_earliest_player
	# faktycznie oddał ruch graczowi 2 (remis 0=0 zostawiłby aktywnym
	# gracza o niższym indeksie, czyli tego samego gracza 1).
	Players.player_days[0] = 10
	Players.pass_turn_to_earliest_player()
	_assert(Players.active_index == 1, "gracz 2 jest teraz aktywny")

	var idx_p2 := PlayerPlantations.found_plantation("richmond")
	_assert(not PlayerPlantations.buy_tile(idx_p2, 0), "gracz 2 NIE MOŻE kupić pola 0 — już należy do gracza 1")
	_assert(PlayerPlantations.buy_tile(idx_p2, 1), "gracz 2 kupuje inne, wolne pole 1")
	_assert(PlayerPlantations.get_owned_tile_count(idx_p2) == 1, "gracz 2 widzi TYLKO swoje własne pole (1), nie pole gracza 1")

	# Wróć do gracza 1 (jego snapshot z buy_tile(idx_p1, 0) musi przetrwać
	# przełączenie tury nietknięty) i sprawdź, że wciąż widzi TYLKO swoje pole.
	Players.player_days[1] = 20
	Players.pass_turn_to_earliest_player()
	_assert(Players.active_index == 0, "gracz 1 jest znów aktywny")
	_assert(PlayerPlantations.get_owned_tile_count(idx_p1) == 1, "gracz 1 nadal widzi TYLKO swoje pole (0), nie pole gracza 2")


## docs/DODATKOWE_MECHANIKI.md: "Pompy wodne: inwestycja podnosząca plon i
## chroniąca przed klęskami (susza/powódź)".
func _test_water_pump_prevents_weather_crisis_and_boosts_yield() -> void:
	print("-- PlayerPlantations: pompa wodna chroni przed pogodą i podnosi plon --")
	PlayerPlantations.reset_new_game()
	Economy.reset_new_game()
	WorldEvents.reset_new_game()
	Players.reset_new_game(1)
	var idx := PlayerPlantations.found_plantation("richmond")
	PlayerPlantations.city_grids["richmond"]["river"].fill(false)

	_assert(not PlayerPlantations.has_water_pump(idx), "plantacja startuje bez pompy")
	Economy.player_money = PlayerPlantations.WATER_PUMP_COST
	_assert(PlayerPlantations.buy_water_pump(idx), "zakup pompy się udaje przy wystarczającej gotówce")
	_assert(PlayerPlantations.has_water_pump(idx), "has_water_pump zwraca true po zakupie")
	_assert(Economy.player_money == 0.0, "koszt pompy odjęty od gotówki")
	_assert(not PlayerPlantations.buy_water_pump(idx), "nie da się kupić drugiej pompy na tę samą plantację")

	## Odporność na pogodę: kod pomija losowanie CAŁKOWICIE, gdy has_water_pump
	## jest ustawione (patrz apply_player_days_elapsed) — więc mimo bardzo
	## wielu tygodni crisis_hits musi zostać dokładnie 0, w pełni deterministycznie.
	for i in 50:
		Economy.player_money = 1000000.0
		PlayerPlantations.apply_player_days_elapsed(7)
	_assert(int(PlayerPlantations.plantations[idx].get("crisis_hits", 0)) == 0, "pompa daje pełną odporność na suszę/powódź (0 uderzeń mimo 50 tygodni)")

	## Bonus plonu: ta sama plantacja/pola/robotnicy, TYLKO obecność pompy
	## się zmienia między dwoma pomiarami.
	PlayerPlantations.buy_tile(idx, 0)
	PlayerPlantations.plant_tile(idx, 0, "tobacco")
	PlayerPlantations.hire_workers(idx, 500)
	PlayerPlantations.plantations[idx]["last_harvest_day"] = Players.active_day() - 30
	## Plon liczy się teraz ze ŚREDNIEJ załogi w czasie (worker_days_accum,
	## patrz PlayerPlantations.calculate_harvest) — bez rzeczywistego upływu
	## czasu (apply_player_days_elapsed) ten licznik zostaje na 0, więc trzeba
	## go tu ustawić ręcznie, żeby odzwierciedlić "500 robotników przez 30 dni".
	PlayerPlantations.plantations[idx]["worker_days_accum"] = 500 * 30.0
	var with_pump := PlayerPlantations.calculate_harvest(idx)
	PlayerPlantations.plantations[idx]["has_water_pump"] = false
	var without_pump := PlayerPlantations.calculate_harvest(idx)
	_assert(int(with_pump.get("tobacco", 0)) > int(without_pump.get("tobacco", 0)), "plon z pompą wyższy niż bez pompy (WATER_PUMP_YIELD_BONUS)")


## docs/DODATKOWE_MECHANIKI.md: "Towar zalegający na magazynie dłużej niż
## rok psuje się" — "richmond" + pompa wodna, tak jak w innych testach
## harvest-owych wyżej, żeby losowe ryzyko pogodowe nie ingerowało.
## Difficulty.yield_multiplier() wchodzi do calculate_harvest() jako czysty,
## deterministyczny mnożnik (bez randf() w środku formuły) — więc, w
## odróżnieniu od ryzyka niżej, dający się sprawdzić WPROST na dokładnej
## wartości, nie tylko statystycznie. int() ucina ułamki, stąd tolerancja
## ±1 zamiast równości day (ta sama technika co _test_harvest_scales_with_time).
func _test_difficulty_scales_plantation_yield() -> void:
	print("-- PlayerPlantations: Difficulty.yield_multiplier skaluje plon --")
	PlayerPlantations.reset_new_game()
	Economy.reset_new_game()
	Players.reset_new_game(1)
	var idx := PlayerPlantations.found_plantation("richmond")
	PlayerPlantations.city_grids["richmond"]["river"].fill(false)
	PlayerPlantations.plantations[idx]["has_water_pump"] = true  # bez ryzyka pogodowego w tym pomiarze
	PlayerPlantations.buy_tile(idx, 0)
	PlayerPlantations.plant_tile(idx, 0, "tobacco")
	PlayerPlantations.hire_workers(idx, 500)
	PlayerPlantations.plantations[idx]["last_harvest_day"] = Players.active_day() - 30
	## Patrz komentarz w _test_water_pump_prevents_weather_crisis_and_boosts_yield
	## wyżej — worker_days_accum trzeba ustawić ręcznie, skoro test omija
	## apply_player_days_elapsed.
	PlayerPlantations.plantations[idx]["worker_days_accum"] = 500 * 30.0

	Difficulty.reset_new_game(Difficulty.Level.VERY_HARD)  # mnożnik ×1,5
	var amount_very_hard: int = PlayerPlantations.calculate_harvest(idx).get("tobacco", 0)
	Difficulty.reset_new_game(Difficulty.Level.VERY_EASY)  # mnożnik ×4,0
	var amount_very_easy: int = PlayerPlantations.calculate_harvest(idx).get("tobacco", 0)
	Difficulty.reset_new_game(Difficulty.Level.NORMAL)  # przywrócone do domyślnego dla kolejnych testów w tym pliku

	var expected_ratio := Difficulty.YIELD_MULTIPLIER[Difficulty.Level.VERY_EASY] / Difficulty.YIELD_MULTIPLIER[Difficulty.Level.VERY_HARD]
	_assert(amount_very_hard > 0, "VERY_HARD daje niezerowy plon (baza testu)")
	_assert(absi(amount_very_easy - int(amount_very_hard * expected_ratio)) <= 1, "VERY_EASY daje ~%.2f× plon VERY_HARD (stosunek mnożników)" % expected_ratio)
	_assert(amount_very_easy > amount_very_hard, "VERY_EASY plonuje więcej niż VERY_HARD")


## Regresja na furtkę znalezioną podczas symulacji pełnej rozgrywki:
## zatrudnienie pełnej załogi TUŻ PRZED zbiorem, a zwolnienie jej ZARAZ PO
## (bez żadnego rzeczywistego upływu czasu z tą załogą) dawało kiedyś PEŁNY
## plon praktycznie za darmo — płaca liczy się retroaktywnie tylko za dni,
## które faktycznie upłynęły (apply_player_days_elapsed), a calculate_harvest
## liczyła worker_factor z CHWILOWEJ liczby robotników w momencie zbioru, nie
## z tego, ilu ich było przez CAŁY okres od ostatnich zbiorów. Naprawa: plon
## liczy się teraz ze ŚREDNIEJ załogi w czasie (worker_days_accum) — więc
## "pusta" załoga przez większość okresu i tylko chwilowe zatrudnienie tuż
## przed zbiorem musi dać WYRAŹNIE mniejszy plon niż ciągłe zatrudnienie przez
## cały ten sam okres.
func _test_hire_right_before_harvest_no_longer_gives_full_yield() -> void:
	print("-- PlayerPlantations: zatrudnienie tuż przed zbiorem NIE daje już pełnego plonu (naprawiona furtka) --")
	PlayerPlantations.reset_new_game()
	Calendar.reset_new_game()
	Economy.reset_new_game()
	Players.reset_new_game(1)
	var idx := PlayerPlantations.found_plantation("richmond")
	PlayerPlantations.city_grids["richmond"]["river"].fill(false)
	PlayerPlantations.plantations[idx]["has_water_pump"] = true  # bez ryzyka pogodowego w tym pomiarze
	PlayerPlantations.buy_tile(idx, 0)
	PlayerPlantations.plant_tile(idx, 0, "tobacco")

	## Scenariusz "furtki": 30 dni bez żadnej załogi (workers=0 przez cały ten
	## czas), dopiero na sam koniec — TUŻ przed harvest() — zatrudnienie pełnej
	## załogi.
	Players.advance_active_player_time(30)
	PlayerPlantations.hire_workers(idx, 500)
	var exploit_harvest: int = PlayerPlantations.harvest(idx).get("tobacco", 0)

	## Scenariusz uczciwy: dokładnie ta sama plantacja/pole/30 dni, ale załoga
	## zatrudniona przez CAŁY okres od samego początku.
	PlayerPlantations.reset_new_game()
	Calendar.reset_new_game()
	Economy.reset_new_game()
	Players.reset_new_game(1)
	idx = PlayerPlantations.found_plantation("richmond")
	PlayerPlantations.city_grids["richmond"]["river"].fill(false)
	PlayerPlantations.plantations[idx]["has_water_pump"] = true
	PlayerPlantations.buy_tile(idx, 0)
	PlayerPlantations.plant_tile(idx, 0, "tobacco")
	PlayerPlantations.hire_workers(idx, 500)
	Players.advance_active_player_time(30)
	var honest_harvest: int = PlayerPlantations.harvest(idx).get("tobacco", 0)

	_assert(honest_harvest > 0, "ciągłe zatrudnienie przez 30 dni daje niezerowy plon (baza testu)")
	_assert(exploit_harvest == 0, "zatrudnienie TUŻ przed zbiorem (bez wcześniejszej pracy) daje plon 0 — furtka zamknięta")
	_assert(exploit_harvest < honest_harvest, "plon z furtki wyraźnie niższy niż z uczciwego, ciągłego zatrudnienia")


## Difficulty.risk_multiplier() == 0.0 na VERY_EASY sprawia, że `randf() < X * 0.0`
## jest MATEMATYCZNIE zawsze fałszywe (randf() nigdy nie zwraca ujemnej
## liczby) — więc, tak jak przy pompie wodnej wyżej, można to sprawdzić w
## pełni deterministycznie, bez polegania na wielu próbach i statystyce.
## Bez pompy (w odróżnieniu od testu pompy) — właśnie BRAK pompy ma tu
## znaczenie: pokazuje, że to Difficulty, nie pompa, wyłącza ryzyko.
func _test_difficulty_very_easy_disables_weather_risk() -> void:
	print("-- PlayerPlantations: Difficulty.VERY_EASY wyłącza ryzyko pogodowe/regionalne --")
	PlayerPlantations.reset_new_game()
	Economy.reset_new_game()
	WorldEvents.reset_new_game()
	Players.reset_new_game(1)
	Difficulty.reset_new_game(Difficulty.Level.VERY_EASY)
	## "ankara" ma REGION_UNREST_CHANCE_PER_WEEK > 0 (Azja) — sprawdza więc OBA
	## źródła ryzyka naraz (pogoda + niepokoje regionalne), nie tylko pogodę.
	var idx := PlayerPlantations.found_plantation("ankara")
	PlayerPlantations.city_grids["ankara"]["river"].fill(false)

	for i in 50:
		Economy.player_money = 1000000.0
		PlayerPlantations.apply_player_days_elapsed(7)
	_assert(int(PlayerPlantations.plantations[idx].get("crisis_hits", 0)) == 0, "VERY_EASY: 0 uderzeń kryzysu mimo 50 tygodni bez pompy, w niestabilnym regionie")
	_assert(PlayerPlantations.plantations.size() == 1, "VERY_EASY: plantacja przetrwała (nigdy nie osiągnęła progu utraty)")

	Difficulty.reset_new_game(Difficulty.Level.NORMAL)  # przywrócone do domyślnego dla kolejnych testów w tym pliku


func _test_goods_spoil_after_a_year_in_storage() -> void:
	print("-- PlayerPlantations: towar starszy niż rok psuje się --")
	PlayerPlantations.reset_new_game()
	Calendar.reset_new_game()
	Economy.reset_new_game()
	WorldEvents.reset_new_game()
	Players.reset_new_game(1)
	var idx := PlayerPlantations.found_plantation("richmond")
	PlayerPlantations.plantations[idx]["has_water_pump"] = true

	# Zapas "starzeje się" wstecz: udajemy, że leży tu od dnia sprzed
	# GOODS_SPOILAGE_DAYS + 1, więc JEDNO wywołanie apply_player_days_elapsed
	# musi go zepsuć.
	PlayerPlantations.plantations[idx]["stored_goods"]["tobacco"] = 40
	PlayerPlantations.plantations[idx]["stored_since"]["tobacco"] = Players.active_day() - PlayerPlantations.GOODS_SPOILAGE_DAYS - 1

	# Świeży zapas innej uprawy, złożony DZISIAJ — nie powinien ucierpieć.
	PlayerPlantations.plantations[idx]["stored_goods"]["coffee"] = 25
	PlayerPlantations.plantations[idx]["stored_since"]["coffee"] = Players.active_day()

	PlayerPlantations.apply_player_days_elapsed(1)

	_assert(int(PlayerPlantations.plantations[idx]["stored_goods"]["tobacco"]) == 0, "roczny zapas tytoniu zepsuty do zera")
	_assert(int(PlayerPlantations.plantations[idx]["stored_goods"]["coffee"]) == 25, "świeży zapas kawy NIE zepsuty")
	_assert(WorldEvents.has_pending(), "zepsucie trafiło do kolejki WorldEvents")
	var reported := WorldEvents.consume_next()
	_assert(reported.get("kind", "") == "spoilage" and reported.get("crop", "") == "tobacco" and int(reported.get("amount", 0)) == 40, "zdarzenie opisuje dokładnie zepsuty towar (tytoń, 40 jednostek)")


## docs/DODATKOWE_MECHANIKI.md: "ukryte, nielegalne lokalne uprawy... i
## mechanika konfiskaty" — dostępna tylko w ankara/guatemala.
func _test_contraband_crop_restricted_and_confiscatable() -> void:
	print("-- Crops/PlayerPlantations: przemycana uprawa ograniczona do Ankary/Gwatemali + konfiskata --")

	_assert(Crops.is_crop_available("contraband", "ankara"), "przemycana uprawa dostępna w Ankarze")
	_assert(Crops.is_crop_available("contraband", "guatemala"), "przemycana uprawa dostępna w Gwatemali")
	_assert(not Crops.is_crop_available("contraband", "richmond"), "przemycana uprawa NIEdostępna w Richmond")
	_assert(Crops.is_crop_available("coffee", "richmond"), "zwykła uprawa (kawa) dostępna wszędzie, bez ograniczeń")

	## Nawet gdyby ktoś ją zasadził poza dozwolonymi miastami (Plantation.gd
	## i tak tego nie pozwala przez UI — to sprawdzenie na poziomie danych,
	## REFERENCE_YIELD, patrz Crops.gd) — plon musi wynosić 0.
	PlayerPlantations.reset_new_game()
	Calendar.reset_new_game()
	Economy.reset_new_game()
	Players.reset_new_game(1)
	var idx := PlayerPlantations.found_plantation("richmond")
	PlayerPlantations.plantations[idx]["has_water_pump"] = true
	PlayerPlantations.city_grids["richmond"]["river"].fill(false)
	PlayerPlantations.buy_tile(idx, 0)
	PlayerPlantations.plant_tile(idx, 0, "contraband")
	PlayerPlantations.hire_workers(idx, 500)
	Players.advance_active_player_time(30)
	var harvest := PlayerPlantations.harvest(idx)
	_assert(int(harvest.get("contraband", 0)) == 0, "przemycana uprawa zasadzona POZA Ankarą/Gwatemalą nie daje ŻADNEGO plonu (REFERENCE_YIELD)")

	## Konfiskata: powtarzamy aż zajdzie (chance=5%/tydzień, ~500 prób to
	## astronomicznie bezpieczny margines na trafienie choć raz).
	WorldEvents.reset_new_game()
	var idx2 := PlayerPlantations.found_plantation("ankara")
	var confiscated := false
	for i in 500:
		PlayerPlantations.plantations[idx2]["stored_goods"][Crops.CONTRABAND_CROP] = 10
		PlayerPlantations._apply_contraband_confiscation(PlayerPlantations.plantations[idx2], 1.0)
		if int(PlayerPlantations.plantations[idx2]["stored_goods"][Crops.CONTRABAND_CROP]) == 0:
			confiscated = true
			break
	_assert(confiscated, "konfiskata w końcu zachodzi (CONTRABAND_CONFISCATION_CHANCE_PER_WEEK w ~500 próbach)")
	_assert(WorldEvents.has_pending(), "konfiskata trafiła do kolejki WorldEvents")
	var reported := WorldEvents.consume_next()
	_assert(reported.get("kind", "") == "confiscation" and reported.get("city", "") == "ankara" and int(reported.get("amount", 0)) == 10, "zdarzenie opisuje dokładnie skonfiskowaną ilość i miasto")


## docs/DODATKOWE_MECHANIKI.md: "3 ulubione obrazy wuja" — spoza katalogu
## 40, bez fałszywek, nie liczą się do win_threshold.
func _test_bonus_paintings_available_and_awardable() -> void:
	print("-- Paintings: bonusowe obrazy wuja (numery ujemne, poza katalogiem 40) --")
	Paintings.reset_new_game()

	_assert(Paintings.is_bonus_painting(-1), "numer ujemny to obraz bonusowy")
	_assert(not Paintings.is_bonus_painting(5), "zwykły numer katalogowy NIE jest bonusowy")
	_assert(Paintings.get_available_bonus_numbers().size() == 3, "na starcie gry wszystkie 3 obrazy bonusowe dostępne")

	var info := Paintings.get_painting_info(-1)
	_assert(info.get("artist", "") == "Adriaen van de Velde", "get_painting_info działa też dla numerów bonusowych")
	_assert(is_equal_approx(Paintings.get_estimated_value(-1), Paintings.BONUS_ESTIMATED_VALUE), "szacowana wartość obrazu bonusowego to BONUS_ESTIMATED_VALUE")
	_assert(Paintings.get_texture_path(-1) == "res://art/paintings/bonus_1.jpg", "ścieżka grafiki obrazu bonusowego wg własnej konwencji nazw")

	Paintings.award_bonus_painting(-1)
	_assert(Paintings.get_available_bonus_numbers().size() == 2, "po rozdaniu jednego zostają 2 dostępne")
	_assert(not Paintings.get_available_bonus_numbers().has(-1), "rozdany numer znika z puli dostępnych")
	_assert(not Paintings.is_forgery_by_duplicate(-1), "obraz bonusowy NIGDY nie jest 'duplikatem/fałszywką' — nie wchodzi do catalogued_numbers")
	_assert(Paintings.catalogued_numbers.is_empty(), "rozdanie obrazu bonusowego NIE dolicza się do zwykłego katalogu (win_threshold)")


## Zweryfikowane bez polegania na dokładnej wartości losowania: gdy WSZYSTKIE
## obrazy bonusowe są już rozdane, get_current_painting_number() nigdy nie
## może wybrać żadnego z nich (deterministyczne, 0% szans niezależnie od
## randf()) — a gdy jest ich pod dostatkiem, w wystarczająco wielu próbach
## przynajmniej raz wybierze jeden z nich (Auctions.BONUS_PAINTING_CHANCE).
func _test_auctions_can_select_bonus_painting_when_available() -> void:
	print("-- Auctions: losowanie obrazu bonusowego na aukcji --")
	Paintings.reset_new_game()
	Calendar.reset_new_game()
	Auctions.reset_new_game()
	Players.reset_new_game(1)

	for number in Paintings.BONUS_CATALOG.keys():
		Paintings.award_bonus_painting(number)
	Auctions.current_painting_number = Auctions.NO_PAINTING_SELECTED
	var picked := Auctions.get_current_painting_number()
	_assert(picked > 0, "gdy WSZYSTKIE obrazy bonusowe rozdane, aukcja zawsze wybiera zwykły numer katalogowy (1-40)")

	Paintings.reset_new_game()  # przywraca wszystkie 3 obrazy bonusowe do puli
	var saw_bonus := false
	for i in 500:
		Auctions.current_painting_number = Auctions.NO_PAINTING_SELECTED
		if Auctions.get_current_painting_number() < 0:
			saw_bonus = true
			break
	_assert(saw_bonus, "gdy obrazy bonusowe dostępne, aukcja w końcu wybiera jeden z nich (BONUS_PAINTING_CHANCE w ~500 próbach)")


## Znalezione podczas symulacji pełnej rozgrywki: numer obrazu na aukcji był
## losowany JEDNOSTAJNIE z całych 40 (bez preferencji dla brakujących), więc
## "ostatni" obraz w kolekcji potrafił nie pojawić się przez lata gry mimo
## dziesiątek aukcji w tym czasie. Naprawa: waga losowania numeru = 1/(ile
## razy już padł + 1), patrz Auctions._pick_weighted_painting_number —
## sprawdzone tu statystycznie (nie da się tego zweryfikować na pojedynczym
## losowaniu): numer, który jeszcze ani razu nie padł, musi być wybierany
## ZDECYDOWANIE częściej niż numer, który padał już wielokrotnie.
func _test_auctions_weighted_draw_favors_less_seen_numbers() -> void:
	print("-- Auctions: losowanie numeru obrazu faworyzuje rzadziej wylosowane (naprawiona 'ostatnia sztuka') --")
	Paintings.reset_new_game()
	Calendar.reset_new_game()
	Auctions.reset_new_game()
	Players.reset_new_game(1)
	for number in Paintings.BONUS_CATALOG.keys():
		Paintings.award_bonus_painting(number)  # wyłącza gałąź bonusową — test ma być deterministyczny

	var seen_7 := 0
	const TRIALS := 500
	for i in TRIALS:
		## Licznik ustawiany OD NOWA przed KAŻDĄ próbą (nie akumulowany między
		## próbami) — inaczej samo losowanie numeru 7 podnosiłoby JEGO WŁASNY
		## licznik i samoczynnie wyrównywałoby wagi w miarę prób (system
		## "samo-balansujący się"), zaniżając zmierzoną przewagę względem
		## pojedynczego, niezależnego losowania, które faktycznie chcemy tu
		## zweryfikować.
		Auctions.painting_draw_count.clear()
		for number in Paintings.CATALOG.size():
			Auctions.painting_draw_count[number + 1] = 100  # wszystkie "wyeksploatowane"...
		Auctions.painting_draw_count.erase(7)  # ...oprócz numeru 7, który jeszcze ani razu nie padł

		Auctions.current_painting_number = Auctions.NO_PAINTING_SELECTED
		if Auctions.get_current_painting_number() == 7:
			seen_7 += 1

	## Losowanie jednostajne dawałoby ~2,5% (1/40); numer 7 (waga 1) kontra 39
	## numerów o wadze 1/101 każdy sumuje się do oczekiwanych ~72% — próg 40%
	## to bezpieczny margines na losowość przy 500 próbach.
	_assert(seen_7 > TRIALS * 0.4, "numer, który jeszcze nie padł, wybierany W ZDECYDOWANEJ WIĘKSZOŚCI prób (%d/%d), nie ~1/40" % [seen_7, TRIALS])


func _test_world_events_reform_queued() -> void:
	print("-- WorldEvents: reforma walutowa trafia do kolejki karty gazety --")
	WorldEvents.reset_new_game()
	Economy.reset_new_game()

	Economy.apply_currency_reform(5.0)

	_assert(WorldEvents.has_pending(), "reforma trafia do kolejki")
	var reported_event := WorldEvents.consume_next()
	_assert(reported_event.get("kind", "") == "reform" and is_equal_approx(reported_event.get("ratio", 0.0), 5.0), "zdarzenie to reforma z ratio=5.0")
	_assert(not WorldEvents.has_pending(), "kolejka pusta po skonsumowaniu jedynego zdarzenia")


## Krach/hossa — patrz ShippingCompanies.apply_market_shock. Wołane wprost
## (jak Economy.apply_currency_reform w teście wyżej), NIE przez losowy rzut
## w _on_day_advanced — inaczej test byłby losowo zawodny (~2%/tydzień
## szansy nie da się wiarygodnie wymusić przez zwykłe advance_days).
func _test_market_shock_crash_and_boom() -> void:
	print("-- ShippingCompanies/WorldEvents: krach i hossa zmieniają WSZYSTKIE kursy naraz i trafiają do kolejki karty gazety --")
	WorldEvents.reset_new_game()
	ShippingCompanies.reset_new_game()

	var lloyd_before := ShippingCompanies.get_price("lloyd")
	var royal_before := ShippingCompanies.get_price("royal")
	ShippingCompanies.apply_market_shock("crash", -0.3)
	_assert(is_equal_approx(ShippingCompanies.get_price("lloyd"), lloyd_before * 0.7), "krach obniża kurs Lloyd o 30%")
	_assert(is_equal_approx(ShippingCompanies.get_price("royal"), royal_before * 0.7), "krach obniża RÓWNIEŻ kurs Royal o 30% — uderza we WSZYSTKIE spółki naraz")
	_assert(WorldEvents.has_pending(), "krach trafia do kolejki karty gazety")
	var crash_event := WorldEvents.consume_next()
	_assert(crash_event.get("kind", "") == "crash" and is_equal_approx(crash_event.get("change_ratio", 0.0), -0.3), "zdarzenie to krach z change_ratio=-0.3")

	var lloyd_before_boom := ShippingCompanies.get_price("lloyd")
	ShippingCompanies.apply_market_shock("boom", 0.4)
	_assert(is_equal_approx(ShippingCompanies.get_price("lloyd"), lloyd_before_boom * 1.4), "hossa podnosi kurs Lloyd o 40%")
	var boom_event := WorldEvents.consume_next()
	_assert(boom_event.get("kind", "") == "boom" and is_equal_approx(boom_event.get("change_ratio", 0.0), 0.4), "zdarzenie to hossa z change_ratio=0.4")


func _test_ship_and_sell_all_across_plantations() -> void:
	print("-- PlayerPlantations: ship_and_sell_all sprzedaje ten sam towar z WSZYSTKICH plantacji --")
	PlayerPlantations.reset_new_game()
	Economy.reset_new_game()

	var idx_a := PlayerPlantations.found_plantation("richmond")
	var idx_b := PlayerPlantations.found_plantation("mombasa")
	PlayerPlantations.plantations[idx_a]["stored_goods"] = {"tobacco": 10}
	PlayerPlantations.plantations[idx_b]["stored_goods"] = {"tobacco": 15}

	var sold := PlayerPlantations.ship_and_sell_all("tobacco", "new_york")

	_assert(sold == 25, "sprzedano łącznie 10+15=25 jednostek z obu plantacji")
	_assert(int(PlayerPlantations.plantations[idx_a]["stored_goods"].get("tobacco", 0)) == 0, "magazyn plantacji A wyzerowany po sprzedaży")
	_assert(int(PlayerPlantations.plantations[idx_b]["stored_goods"].get("tobacco", 0)) == 0, "magazyn plantacji B wyzerowany po sprzedaży")


func _test_find_plantation_index() -> void:
	print("-- PlayerPlantations: find_plantation_index --")
	PlayerPlantations.reset_new_game()
	_assert(PlayerPlantations.find_plantation_index("richmond") == -1, "brak plantacji w mieście, gdzie gracz jej jeszcze nie założył")
	var idx := PlayerPlantations.found_plantation("richmond")
	_assert(PlayerPlantations.find_plantation_index("richmond") == idx, "po założeniu: find_plantation_index zwraca właściwy indeks")
	_assert(PlayerPlantations.find_plantation_index("mombasa") == -1, "inne miasto nadal bez plantacji")


func _test_forgery_by_duplicate_number() -> void:
	print("-- Paintings: wykrywanie fałszywek po numerze katalogowym --")
	Paintings.reset_new_game()
	_assert(not Paintings.is_forgery_by_duplicate(6), "obraz nr 6 jeszcze nie posiadany -> nie jest 'duplikatem'")
	Paintings.catalogue(6)
	_assert(Paintings.owned_count() == 1, "po katalogowaniu: 1 obraz w kolekcji")
	_assert(Paintings.is_forgery_by_duplicate(6), "próba zdobycia drugiego obrazu nr 6 = wykryta fałszywka")
	_assert(Paintings.get_category(6) == "vermeer", "obraz nr 6 należy do kategorii 'vermeer' (docs/ZRODLA_C64_WIKI.md)")


func _test_forgery_texture_falls_back_when_missing() -> void:
	print("-- Paintings: get_texture_path z is_fake=true --")
	## Obraz nr 7 ma dedykowany wariant podróbki (painting_07_fake.jpg),
	## obraz nr 1 (na razie) nie — is_fake=true musi po cichu spaść z
	## powrotem na zwykłą grafikę zamiast zwracać nieistniejącą ścieżkę.
	_assert(
		Paintings.get_texture_path(7, true) == "res://art/paintings/painting_07_fake.jpg",
		"obraz nr 7 z is_fake=true zwraca dedykowaną grafikę podróbki",
	)
	_assert(
		Paintings.get_texture_path(1, true) == Paintings.get_texture_path(1, false),
		"obraz nr 1 bez wariantu podróbki: is_fake=true spada z powrotem na zwykłą grafikę",
	)


func _test_paintings_numbers_with_fake_variant() -> void:
	print("-- Paintings: get_numbers_with_fake_variant (mini-gra Szkoły sztuki) --")
	var numbers := Paintings.get_numbers_with_fake_variant()
	_assert(numbers.has(7), "obraz nr 7 (ma dedykowaną grafikę podróbki) jest na liście")
	_assert(not numbers.has(1), "obraz nr 1 (bez dedykowanej grafiki podróbki) NIE jest na liście")
	_assert(not numbers.is_empty(), "lista nie jest pusta — mini-gra ma z czego losować")


func _test_ai_players_rival_names_randomized() -> void:
	print("-- AIPlayers: imiona/portrety generycznych rywali losowane, nie statyczne --")
	AIPlayers.reset_new_game()
	var rival_2 := AIPlayers.get_rival("rival_2")
	var rival_3 := AIPlayers.get_rival("rival_3")

	_assert(rival_2["name"] != "Rywal II", "rival_2 dostaje wylosowane imię, nie statyczny placeholder")
	_assert(rival_3["name"] != "Rywal III", "rival_3 dostaje wylosowane imię, nie statyczny placeholder")
	_assert(
		AIPlayers.GENERIC_RIVAL_POOL.has(rival_2["portrait"]) and AIPlayers.GENERIC_RIVAL_POOL.has(rival_3["portrait"]),
		"oba portrety pochodzą z puli generycznych rywali",
	)
	_assert(rival_2["portrait"] != rival_3["portrait"], "rival_2 i rival_3 dostają RÓŻNE portrety (bez powtórzeń)")

	var vico := AIPlayers.get_rival("vico")
	_assert(
		vico["portrait"].begins_with("vico_"),
		"Vico dostaje jeden z losowych wariantów portretu (vico_1/2/3)",
	)
	_assert(
		AIPlayers.get_portrait_path("vico") == "res://art/characters/%s.jpg" % vico["portrait"],
		"get_portrait_path liczy ścieżkę Vico z jego wylosowanego pola 'portrait'",
	)
	_assert(
		AIPlayers.get_portrait_path("rival_2") == "res://art/characters/%s.jpg" % rival_2["portrait"],
		"get_portrait_path liczy ścieżkę z pola 'portrait' danego rywala",
	)


func _test_win_threshold_easy_mode() -> void:
	print("-- Paintings: próg zwycięstwa (tryb łatwy vs normalny) --")
	Paintings.reset_new_game(true)
	_assert(Paintings.win_threshold == Paintings.EASY_WIN_THRESHOLD, "tryb łatwy: win_threshold == 15")
	Paintings.reset_new_game(false)
	_assert(Paintings.win_threshold == Paintings.CATALOG.size(), "tryb normalny: win_threshold == 40")


## Difficulty.gd: sprawdza mapowanie WSZYSTKICH 5 poziomów na risk_multiplier/
## yield_multiplier/is_easy_win — te trzy tabele to jedyne miejsce, gdzie te
## liczby są zdefiniowane, więc test pilnuje, żeby literówka w stałej (albo
## przyszła zmiana wartości) była widoczna od razu, zamiast dopiero w
## rozgrywce. Przywraca VERY_HARD na końcu — to jedyny poziom, przy którym
## WSZYSTKIE inne testy w tym pliku (pisane przed wprowadzeniem tej
## mechaniki) dają dokładnie takie same wyniki jak wcześniej.
func _test_difficulty_level_multipliers() -> void:
	print("-- Difficulty: mapowanie 5 poziomów na mnożniki --")
	Difficulty.reset_new_game(Difficulty.Level.VERY_EASY)
	_assert(is_equal_approx(Difficulty.risk_multiplier(), 0.0), "VERY_EASY: ryzyko całkowicie wyłączone")
	_assert(is_equal_approx(Difficulty.yield_multiplier(), 4.0), "VERY_EASY: plon ×4,0")
	_assert(Difficulty.is_easy_win(), "VERY_EASY: łatwy próg zwycięstwa")

	Difficulty.reset_new_game(Difficulty.Level.EASY)
	_assert(is_equal_approx(Difficulty.risk_multiplier(), 0.25), "EASY: ryzyko ×0,25")
	_assert(is_equal_approx(Difficulty.yield_multiplier(), 3.0), "EASY: plon ×3,0")
	_assert(Difficulty.is_easy_win(), "EASY: łatwy próg zwycięstwa")

	Difficulty.reset_new_game(Difficulty.Level.NORMAL)
	_assert(is_equal_approx(Difficulty.risk_multiplier(), 0.5), "NORMAL: ryzyko ×0,5")
	_assert(is_equal_approx(Difficulty.yield_multiplier(), 2.5), "NORMAL: plon ×2,5")
	_assert(not Difficulty.is_easy_win(), "NORMAL: pełny próg zwycięstwa (40)")

	Difficulty.reset_new_game(Difficulty.Level.HARD)
	_assert(is_equal_approx(Difficulty.risk_multiplier(), 0.75), "HARD: ryzyko ×0,75")
	_assert(is_equal_approx(Difficulty.yield_multiplier(), 2.0), "HARD: plon ×2,0")
	_assert(not Difficulty.is_easy_win(), "HARD: pełny próg zwycięstwa (40)")

	Difficulty.reset_new_game(Difficulty.Level.VERY_HARD)
	_assert(is_equal_approx(Difficulty.risk_multiplier(), 1.0), "VERY_HARD: ryzyko niezmienione (dzisiejszy balans)")
	_assert(is_equal_approx(Difficulty.yield_multiplier(), 1.5), "VERY_HARD: plon i tak ×1,5 względem dawnego balansu")
	_assert(not Difficulty.is_easy_win(), "VERY_HARD: pełny próg zwycięstwa (40)")

	_assert(Difficulty.LEVEL_ORDER.size() == 5, "LEVEL_ORDER wymienia dokładnie 5 poziomów (kolejność w MainMenu.gd)")

	Difficulty.reset_new_game(Difficulty.Level.NORMAL)  # przywrócone do domyślnego dla kolejnych testów w tym pliku


func _test_forward_contract_penalty_on_failure() -> void:
	print("-- ForwardContracts: kara za niedostarczony kontrakt --")
	Calendar.reset_new_game()
	Economy.reset_new_game()
	Crops.reset_new_game()
	PlayerPlantations.reset_new_game()
	ForwardContracts.reset_new_game()
	Players.reset_new_game(1)

	ForwardContracts.propose_contract("tobacco")
	_assert(ForwardContracts.active_contracts.size() == 1, "kontrakt utworzony")
	var money_before := Economy.player_money

	# Żadna plantacja nie dostarcza tytoniu -> po terminie kontrakt musi zawieść.
	Players.advance_active_player_time(ForwardContracts.DUE_IN_DAYS + 1)

	_assert(ForwardContracts.active_contracts.is_empty(), "kontrakt rozliczony i usunięty z listy aktywnych")
	_assert(Economy.player_money < money_before, "gotówka spadła o karę umowną za niedostarczenie")


func _test_players_hotseat_swap() -> void:
	print("-- Players: przełączanie graczy hot-seat --")
	Calendar.reset_new_game()
	Economy.reset_new_game()
	Crops.reset_new_game()
	Paintings.reset_new_game()
	PlayerPlantations.reset_new_game()
	ShippingCompanies.reset_new_game()
	ForwardContracts.reset_new_game()
	Travel.reset_new_game()
	Security.reset_new_game()
	Players.reset_new_game(2)

	Economy.player_money = 12345.0
	Paintings.catalogue(1)
	## Bez tego Security._on_day_advanced (podłączony pod Calendar.day_advanced,
	## czyli odpala się przy KAŻDYM end_turn() poniżej) miał ~5% szansy/tydzień
	## ukraść jedyny obraz gracza 1 — losowa, niezwiązana z tym testem
	## interakcja z mechaniką kradzieży (patrz Security.gd), która sprawiała,
	## że test sporadycznie failował. Ten test sprawdza migawki stanu, nie
	## kradzieże — ochroniarz eliminuje tę przypadkową zależność.
	Security.has_bodyguard = true

	Players.end_turn()  # gracz 1 -> gracz 2

	_assert(Players.active_index == 1, "po end_turn: aktywny indeks = 1 (gracz 2)")
	_assert(Economy.player_money == Economy.STARTING_MONEY, "gracz 2 widzi swój świeży stan, nie kasę gracza 1")
	_assert(Paintings.owned_count() == 0, "gracz 2 nie widzi obrazów gracza 1")

	Players.end_turn()  # gracz 2 -> gracz 1 (pełny obrót)

	_assert(Players.active_index == 0, "po drugim end_turn wracamy do gracza 1")
	_assert(Economy.player_money == 12345.0, "stan gracza 1 poprawnie przywrócony z migawki")
	_assert(Paintings.owned_count() == 1, "gracz 1 nadal ma swój obraz")


## Zgłoszone przez użytkownika: kolejność tur NIE jest sztywnym round-robin —
## po KAŻDEJ czynności (tu: podróż) silnik oddaje ruch temu, kto ma teraz
## najwcześniejszą datę (Players.pass_turn_to_earliest_player). W grze
## 2-osobowej: gracz aktywny zawsze zaczyna swoją akcję będąc na RÓWNI z
## resztą (bo dostał ruch właśnie dlatego, że miał najwcześniejszą datę), więc
## KAŻDA podróż z niezerową liczbą dni wysuwa go przed pozostałych i oddaje im
## ruch — nie ma już progu "dłużej niż tydzień". Ten sam gracz dostaje ruch
## z powrotem drugi raz z rzędu tylko wtedy, gdy nadal jest najbardziej "z
## tyłu" w czasie (patrz trzeci etap testu niżej). Symuluje dokładnie to, co
## robi TravelAnimation.gd::_on_finished (advance_active_player_time, potem
## bezwarunkowo pass_turn_to_earliest_player) — scen nie instancjonujemy w
## tym pakiecie testów, patrz konwencja innych testów w tym pliku.
func _test_players_turn_follows_earliest_date() -> void:
	print("-- Travel/Players: silnik oddaje ruch graczowi z najwcześniejszą datą --")
	Economy.reset_new_game()
	Security.reset_new_game()
	Security.has_bodyguard = true  # eliminuje losową kradzież w tle, tak jak w _test_players_hotseat_swap
	Players.reset_new_game(2)
	Travel.reset_new_game()
	Calendar.reset_new_game()

	Travel.current_city = "berlin"
	Travel.route.clear()
	Travel.start_travel("london")  # 3.0 dnia
	var short_days := int(ceil(Travel.last_travel_total_days))
	Players.advance_active_player_time(short_days)  # gracz 1: dzień 0 -> %d dni
	Players.pass_turn_to_earliest_player()
	_assert(Players.active_index == 1, "gracz 1 po podróży (%d dni) wysuwa się przed gracza 2 (wciąż dzień 0) — ruch przechodzi na gracza 2" % short_days)

	Travel.current_city = "london"
	Travel.route.clear()
	Travel.start_travel("new_york")  # 13.9 dnia — znacznie dłuższa
	var long_days := int(ceil(Travel.last_travel_total_days))
	Players.advance_active_player_time(long_days)  # gracz 2: dzień 0 -> %d dni, znacznie więcej niż gracz 1
	Players.pass_turn_to_earliest_player()
	_assert(Players.active_index == 0, "gracz 2 wyprzedza gracza 1 długą podróżą (%d dni) — ruch wraca do gracza 1 (znów najwcześniejsza data)" % long_days)

	# Gracz 1 (aktywny) wraca z podróży do Londynu (patrz przywrócona migawka
	# po pass_turn_to_earliest_player wyżej) — kolejna, krótsza podróż stąd.
	Travel.route.clear()
	Travel.start_travel("ankara")  # 7.8 dnia z Londynu
	var third_days := int(ceil(Travel.last_travel_total_days))
	Players.advance_active_player_time(third_days)
	Players.pass_turn_to_earliest_player()
	_assert(Players.active_index == 0, "gracz 1 nadal jest najbardziej 'z tyłu' (dzień %d wciąż < gracz 2, dzień %d) — dostaje ruch DRUGI RAZ z rzędu, silnik NIE wraca do sztywnego round-robin" % [Players.get_player_day(0), Players.get_player_day(1)])


## Ten sam problem co podróż wyżej, ale subtelniejszy: Economy.player_money
## i Paintings.expertise są migawkowane PER GRACZ (Players._capture_active),
## więc przekazanie tury (Players.pass_turn_to_earliest_player) MUSI nastąpić
## DOPIERO PO zastosowaniu efektów kursu (opłata + zdobyta eksperckość z
## quizu) — inaczej trafiłyby do migawki złego gracza. Symuluje kolejność z
## ArtSchool.gd (_on_train_pressed -> quiz -> _end_course_turn), nie sam
## quiz UI (scen nie instancjonujemy w tym pakiecie testów).
func _test_art_school_course_ends_turn_after_applying_effects() -> void:
	print("-- ArtSchool: długi kurs oddaje ruch graczowi z najwcześniejszą datą, PO zastosowaniu efektów --")
	Calendar.reset_new_game()
	Economy.reset_new_game()
	Paintings.reset_new_game()
	Security.reset_new_game()
	Security.has_bodyguard = true
	Players.reset_new_game(2)

	var training_cost := 2000.0
	var training_days := 28  # ArtSchool.TRAINING_DAYS (Akademia w Paryżu, docs/DODATKOWE_MECHANIKI.md)
	var expertise_gain := 0.15  # symuluje trafną odpowiedź w quizie

	Economy.spend(training_cost)
	Players.advance_active_player_time(training_days)  # patrz ArtSchool.gd::_on_train_pressed
	Paintings.increase_expertise(expertise_gain)
	Players.pass_turn_to_earliest_player()  # patrz ArtSchool.gd::_end_course_turn, wywołane PO quizie

	_assert(Players.active_index == 1, "kurs dłuższy niż tydzień (%d dni) wysuwa gracza 1 do przodu, ruch przechodzi na gracza 2 (najwcześniejsza data)" % training_days)
	_assert(Economy.player_money == Economy.STARTING_MONEY, "gracz 2 widzi swój świeży stan, nie kasę pomniejszoną przez kurs gracza 1")
	_assert(is_equal_approx(Paintings.expertise, 0.0), "gracz 2 nie odziedziczył eksperckości zdobytej przez gracza 1")

	# Gracz 2 wyprzedza gracza 1 w czasie (dzień training_days+1 > training_days)
	# — dopiero to oddaje ruch z powrotem, sprawdzamy migawkę gracza 1. NIE
	# używamy Players.end_turn() tutaj: ono dolicza własny tydzień (i cap
	# Auctions.cap_turn_advance) PRZED sprawdzeniem najwcześniejszej daty, co
	# przy training_days=28 > DAYS_PER_TURN=7 nie wystarczyłoby, by wyprzedzić
	# gracza 1 — testowalibyśmy więc coś innego niż samą logikę
	# pass_turn_to_earliest_player.
	Players.advance_active_player_time(training_days + 1)
	Players.pass_turn_to_earliest_player()
	_assert(Players.active_index == 0, "gracz 2 wyprzedził gracza 1 w czasie — ruch wraca do gracza 1 (znów najwcześniejsza data)")
	_assert(
		is_equal_approx(Economy.player_money, Economy.STARTING_MONEY - training_cost),
		"po powrocie: gotówka gracza 1 poprawnie pomniejszona o koszt kursu",
	)
	_assert(is_equal_approx(Paintings.expertise, expertise_gain), "po powrocie: eksperckość gracza 1 poprawnie zapisana z kursu")


func _test_security_bodyguard_and_gangster() -> void:
	print("-- Security: ochroniarz i gangster (docs/DODATKOWE_MECHANIKI.md) --")
	Economy.reset_new_game()
	Security.reset_new_game()
	Gangsters.reset_new_game()

	_assert(not Security.has_bodyguard, "na starcie brak ochroniarza")
	var cost_before := Economy.player_money
	_assert(Security.hire_bodyguard(), "zatrudnienie ochroniarza się udaje przy wystarczających środkach")
	_assert(Security.has_bodyguard, "po zatrudnieniu: has_bodyguard == true")
	_assert(Economy.player_money == cost_before - Security.BODYGUARD_COST, "gotówka spadła dokładnie o koszt ochroniarza")
	_assert(not Security.hire_bodyguard(), "nie da się zatrudnić drugiego ochroniarza")

	AIPlayers.reset_new_game()
	Paintings.reset_new_game()
	var rival_id: String = AIPlayers.rivals[0]["id"]
	var gangster_id: String = Gangsters.GANGSTERS.keys()[0]
	AIPlayers.rivals[0]["paintings"] = [7]
	Economy.player_money = 100000.0

	## resolve_gangster_attempt() sam NIE dotyka ekonomii (patrz komentarz w
	## Security.gd) — opłata symuluje to, co realnie robi SecurityScreen.gd
	## PRZED zbudowaniem HeistView, dokładnie jak zakład w Races.gd.
	var money_before_gangster := Economy.player_money
	Economy.spend(Security.GANGSTER_COST)
	var result := Security.resolve_gangster_attempt(gangster_id, rival_id)
	Security.apply_gangster_result(result)
	_assert(Economy.player_money <= money_before_gangster - Security.GANGSTER_COST, "opłata za gangstera pobrana niezależnie od wyniku (plus ewentualna grzywna za złapanie)")

	# Rywal bez obrazów -> próba musi się nie udać (nie ma czego ukraść).
	AIPlayers.rivals[0]["paintings"] = []
	var result_empty := Security.resolve_gangster_attempt(gangster_id, rival_id)
	_assert(not result_empty["success"], "gangster nie może ukraść obrazu, którego rywal nie posiada")


## Zgłoszenie użytkownika: szansa powodzenia gangstera ma dryfować dziennie
## (20-50%), tak samo jak kurs koni (Horses.gd) — ten sam wzorzec testu co
## _test_horses_odds_drift_and_bounds.
func _test_gangsters_chance_drift_and_bounds() -> void:
	print("-- Gangsters: szansa powodzenia dryfuje dziennie i trzyma się w granicach MIN/MAX_CHANCE --")
	Calendar.reset_new_game()
	Gangsters.reset_new_game()

	var gangster_id: String = Gangsters.GANGSTERS.keys()[0]
	var starting_chance := Gangsters.get_success_chance(gangster_id)
	var changed_at_least_once := false
	for i in 200:
		Calendar.advance_days(7)
		var chance := Gangsters.get_success_chance(gangster_id)
		_assert(chance >= Gangsters.MIN_CHANCE and chance <= Gangsters.MAX_CHANCE, "szansa w granicach [MIN_CHANCE, MAX_CHANCE] (iteracja %d)" % i)
		if not is_equal_approx(chance, starting_chance):
			changed_at_least_once = true
	_assert(changed_at_least_once, "szansa faktycznie dryfuje po wielu skokach dni, nie stoi w miejscu")


## Zgłoszenie użytkownika: szansa gangstera ma być WSPÓLNA — ten sam dzień =
## ta sama szansa, niezależnie który gracz akurat wysyła gangstera (Tor A,
## ten sam wzorzec co _test_horses_odds_shared_by_day).
func _test_gangsters_chance_shared_by_day() -> void:
	print("-- Gangsters: ten sam dzień = ta sama szansa, niezależnie kto dotarł pierwszy --")
	Calendar.reset_new_game()
	Players.reset_new_game(2)
	Gangsters.reset_new_game()

	var gangster_id: String = Gangsters.GANGSTERS.keys()[0]
	Players.advance_active_player_time(15)  # gracz 1 pcha świat do dnia 15
	var chance_after_player_1 := Gangsters.get_success_chance(gangster_id)

	Players.pass_turn_to_earliest_player()
	_assert(Players.active_index == 1, "gracz 2 (dzień 0, najwcześniejsza data) dostaje ruch")
	Players.advance_active_player_time(15)  # gracz 2 dogania do dnia 15 — już zasymulowanego

	_assert(is_equal_approx(Gangsters.get_success_chance(gangster_id), chance_after_player_1), "gracz 2, docierając do TEGO SAMEGO dnia, widzi tę samą szansę")


## Zgłoszenie użytkownika: nieudana próba CZASEM oznacza złapanie własnego
## gangstera (dodatkowa grzywna), sukces i złapanie nigdy nie idą w parze, a
## apply_gangster_result() nalicza dokładnie jedną z trzech, wzajemnie
## wykluczających się konsekwencji — powtarzane wiele razy (jak
## _test_race_track_winner_finishes_first), żeby złapać ewentualny błąd
## niezależnie od tego, który wynik akurat wypadnie.
func _test_gangster_attempt_resolve_apply_consequences() -> void:
	print("-- Security: resolve/apply gangstera - sukces/ucieczka/złapanie nigdy się nie mieszają --")
	AIPlayers.reset_new_game()
	var rival_id: String = AIPlayers.rivals[0]["id"]
	var gangster_id: String = Gangsters.GANGSTERS.keys()[0]

	for trial in 30:
		Paintings.reset_new_game()
		Economy.reset_new_game()
		AIPlayers.rivals[0]["paintings"] = [7]

		var result := Security.resolve_gangster_attempt(gangster_id, rival_id)
		_assert(not (result["success"] and result["caught"]), "próba %d: sukces i złapanie nigdy naraz" % trial)

		var money_before_apply := Economy.player_money
		Security.apply_gangster_result(result)

		if result["success"]:
			_assert(result["stolen_number"] == 7, "próba %d: sukces - skradziony numer to obraz, który rywal faktycznie miał" % trial)
			_assert(Paintings.catalogued_numbers.has(7), "próba %d: sukces - obraz trafia do katalogu gracza" % trial)
			_assert(not AIPlayers.rivals[0]["paintings"].has(7), "próba %d: sukces - obraz znika z kolekcji rywala" % trial)
			_assert(is_equal_approx(Economy.player_money, money_before_apply), "próba %d: sukces - apply nie nakłada dodatkowej opłaty" % trial)
		elif result["caught"]:
			_assert(is_equal_approx(Economy.player_money, money_before_apply - Security.CAUGHT_FINE), "próba %d: złapanie - dodatkowa grzywna CAUGHT_FINE" % trial)
			_assert(Paintings.catalogued_numbers.is_empty(), "próba %d: złapanie - żaden obraz nie trafia do gracza" % trial)
		else:
			_assert(is_equal_approx(Economy.player_money, money_before_apply), "próba %d: ucieczka bez łupu - brak dodatkowej opłaty" % trial)
			_assert(Paintings.catalogued_numbers.is_empty(), "próba %d: ucieczka bez łupu - żaden obraz nie trafia do gracza" % trial)


## Zgłoszenie użytkownika: animowana scena skoku (HeistView.gd) ma TYLKO
## wizualizować wynik ustalony PRZED animacją (dokładnie jak RaceTrackView) —
## dla wszystkich trzech wyników sprawdzamy, że stan końcowy animacji (t=1)
## faktycznie odpowiada przekazanemu outcome, niezależnie od losowego
## przebiegu drogi.
func _test_heist_view_outcome_matches_precomputed_result() -> void:
	print("-- HeistView: stan końcowy animacji zawsze zgodny z przekazanym outcome --")
	for outcome in ["success", "failure_caught", "failure_escaped"]:
		var view: Control = HeistViewScript.new()
		add_child(view)
		view.setup("res://art/gangsters/vito.jpg", "res://art/characters/male_tophat.jpg", outcome, "test", Vector2(1280.0, 720.0))

		var final_x: float = view._gangster_x(1.0)
		match outcome:
			"success":
				_assert(is_equal_approx(final_x, view.start_x - 60.0), "success: gangster kończy poza ekranem po stronie startu (ucieczka z łupem)")
			"failure_caught":
				_assert(is_equal_approx(final_x, view.turn_x), "failure_caught: gangster zamarza dokładnie na turn_x (miejscu złapania)")
			_:
				_assert(is_equal_approx(final_x, view.start_x - 60.0), "failure_escaped: gangster kończy poza ekranem po stronie startu (ucieczka bez łupu)")
		view.queue_free()


## Buduje TravelMap.tscn dodaną do drzewa testu (nie tylko preloadowany
## skrypt jak RaceTrackView/HeistView — TravelMap.gd nie ma class_name, tak
## jak inne skrypty EKRANÓW, patrz _test_all_scene_scripts_parse_without_error).
## map_viewport (PRESET_FULL_RECT) dostaje rozmiar okna projektu (project.godot
## window/size, 1280×720) automatycznie z samych anchorów, bez ręcznego
## nadpisywania .size — to samo źródło rozmiaru co Vector2(1280.0, 720.0)
## używane w testach RaceTrackView/HeistView.
func _build_travel_map_for_test() -> Control:
	Travel.reset_new_game()
	var view: Control = load("res://scenes/travel_map/TravelMap.tscn").instantiate()
	add_child(view)
	return view


## Zgłoszenie użytkownika: mapę da się przybliżać (uszczypnięcie/kółko myszy),
## a pinezki przy tym TROCHĘ się powiększają — nie 1:1 z zoomem mapy (patrz
## PIN_ZOOM_DAMPING w TravelMap.gd). Sprawdzamy: zoom trzyma się granic
## [MIN_ZOOM, MAX_ZOOM] mimo prośby o wartość poza zakresem, a widoczny
## (skompensowany) rozmiar pinezki = target_scale/zoom * zoom (odziedziczona
## skala map_content) = target_scale dokładnie, więc rośnie WOLNIEJ niż sam
## zoom mapy.
func _test_travel_map_zoom_clamped_and_pins_scale_damped() -> void:
	print("-- TravelMap: zoom trzyma się granic, pinezki rosną wolniej niż mapa (PIN_ZOOM_DAMPING) --")
	var view := _build_travel_map_for_test()
	var focal: Vector2 = view.map_viewport.size * 0.5

	view._apply_zoom(view.MAX_ZOOM + 5.0, focal)
	_assert(is_equal_approx(view.zoom, view.MAX_ZOOM), "zoom nie przekracza MAX_ZOOM mimo prośby o dużo więcej")
	_assert(is_equal_approx(view.map_content.scale.x, view.MAX_ZOOM), "map_content.scale odzwierciedla zaciśnięty zoom")

	var apparent_pin_scale: float = view.pins[0].scale.x * view.map_content.scale.x
	var expected_target_scale: float = 1.0 + (view.MAX_ZOOM - view.MIN_ZOOM) * view.PIN_ZOOM_DAMPING
	_assert(is_equal_approx(apparent_pin_scale, expected_target_scale), "widoczny rozmiar pinezki przy MAX_ZOOM = stonowany target_scale (rośnie wolniej niż mapa)")
	_assert(expected_target_scale < view.MAX_ZOOM, "stonowany rozmiar pinezki jest MNIEJSZY niż zoom samej mapy — rosną wolniej, nie 1:1")

	view._apply_zoom(view.MIN_ZOOM - 5.0, focal)
	_assert(is_equal_approx(view.zoom, view.MIN_ZOOM), "zoom nie spada poniżej MIN_ZOOM mimo prośby o dużo mniej")

	view.queue_free()


## Zgłoszenie użytkownika: pinezki mają ZOSTAĆ na dobrym miejscu — przy braku
## przybliżenia (zoom == MIN_ZOOM) mapa i tak dokładnie wypełnia ekran, więc
## przeciąganie nie powinno w ogóle przesuwać treści (nie ma dokąd — patrz
## komentarz w _apply_pan/_clamp_pan).
func _test_travel_map_pan_clamped_when_not_zoomed() -> void:
	print("-- TravelMap: bez przybliżenia przeciąganie nie rusza mapy (nie ma dokąd) --")
	var view := _build_travel_map_for_test()
	_assert(is_equal_approx(view.zoom, view.MIN_ZOOM), "startowy zoom to MIN_ZOOM")

	view._apply_pan(Vector2(150.0, -150.0))
	_assert(view.map_content.position.is_equal_approx(Vector2.ZERO), "pozycja mapy zostaje (0,0) — przeciąganie bez zoomu jest bez efektu")

	view.queue_free()


## Zgłoszenie użytkownika: pinezki mają zostać na dobrym miejscu WZGLĘDEM
## MAPY także w trakcie samego przybliżania — standardowa własność "zoom do
## punktu": ten sam punkt mapy (we współrzędnych WEWNĄTRZ map_content, przed
## przeskalowaniem) musi wypadać pod tym samym punktem ekranu (`focal`) i
## PRZED, i PO zmianie zoomu. Test liczy ten punkt tym samym wzorem co
## _apply_zoom i porównuje przed/po (przy zoomowaniu w okolicy środka ekranu
## naturalny wynik mieści się w granicach _clamp_pan, więc test nie jest
## zakłócony przez zaciskanie).
func _test_travel_map_zoom_keeps_focal_point_fixed() -> void:
	print("-- TravelMap: zoom zachowuje ten sam punkt mapy pod kursorem/palcem --")
	var view := _build_travel_map_for_test()
	var focal: Vector2 = view.map_viewport.size * 0.5
	var local_point_before: Vector2 = (focal - view.map_content.position) / view.zoom

	view._apply_zoom(1.6, focal)
	var local_point_after: Vector2 = (focal - view.map_content.position) / view.zoom
	_assert(local_point_before.is_equal_approx(local_point_after), "ten sam punkt mapy zostaje pod focal po zmianie zoomu (1.0 -> 1.6)")

	view._apply_zoom(2.2, focal)
	var local_point_after_2: Vector2 = (focal - view.map_content.position) / view.zoom
	_assert(local_point_before.is_equal_approx(local_point_after_2), "ten sam punkt mapy zostaje pod focal po kolejnej zmianie zoomu (1.6 -> 2.2)")

	view.queue_free()


## Zgłoszony przez użytkownika bug: "2 palcami nie mogę powiększyć na
## telefonie" — root cause: uszczypnięcie na dotyku przychodzi jako surowy
## InputEventScreenTouch/InputEventScreenDrag PER PALEC, który NIE dociera
## do gui_input (kanał myszy/GUI), tylko do zwykłego _input() — poprzednia
## wersja słuchała wyłącznie gui_input, więc pinch nigdy nie docierał do
## _apply_zoom na prawdziwym telefonie. Test woła view._input(event)
## BEZPOŚREDNIO (symulacja dwóch palców: dotknięcie, potem oddalenie od
## siebie) — dokładnie ta sama ścieżka kodu co realny dotyk, żeby ten
## dokładny bug nie mógł się cicho cofnąć.
func _test_travel_map_pinch_zoom_via_touch_events() -> void:
	print("-- TravelMap: uszczypnięcie DWOMA PALCAMI (surowy dotyk, nie gui_input) faktycznie zooomuje --")
	var view := _build_travel_map_for_test()

	var touch0 := InputEventScreenTouch.new()
	touch0.index = 0
	touch0.position = Vector2(300.0, 300.0)
	touch0.pressed = true
	view._input(touch0)

	var touch1 := InputEventScreenTouch.new()
	touch1.index = 1
	touch1.position = Vector2(700.0, 300.0)
	touch1.pressed = true
	view._input(touch1)
	_assert(view.touch_points.size() == 2, "oba palce zarejestrowane po dwóch InputEventScreenTouch")

	## Pierwszy InputEventScreenDrag PO dwóch dotknięciach tylko ustala punkt
	## odniesienia (pinch_start_distance) — zgodnie z komentarzem w
	## _handle_pinch, żaden zoom jeszcze się nie zmienia.
	var drag0 := InputEventScreenDrag.new()
	drag0.index = 0
	drag0.position = Vector2(280.0, 300.0)
	drag0.relative = Vector2(-20.0, 0.0)
	view._input(drag0)
	_assert(is_equal_approx(view.zoom, view.MIN_ZOOM), "pierwszy InputEventScreenDrag po zejściu dwóch palców tylko ustala punkt odniesienia (bez zmiany zoomu)")
	_assert(view.pinch_start_distance > 0.0, "pinch_start_distance ustalony po pierwszym drag przy dwóch palcach")

	## Drugi palec oddala się (odległość między palcami rośnie) -> zoom w górę.
	var drag1 := InputEventScreenDrag.new()
	drag1.index = 1
	drag1.position = Vector2(760.0, 300.0)
	drag1.relative = Vector2(60.0, 0.0)
	view._input(drag1)
	_assert(view.zoom > view.MIN_ZOOM, "uszczypnięcie (palce oddalają się od siebie) faktycznie zwiększa zoom przez _input(), nie tylko przez gui_input")

	## Podniesienie jednego palca resetuje pinch_start_distance — kolejne
	## uszczypnięcie zaczyna się od nowa, nie od starego punktu odniesienia.
	var lift0 := InputEventScreenTouch.new()
	lift0.index = 0
	lift0.position = drag0.position
	lift0.pressed = false
	view._input(lift0)
	_assert(is_equal_approx(view.pinch_start_distance, 0.0), "podniesienie jednego palca resetuje pinch_start_distance")

	view.queue_free()


func _test_travel_vehicle_choice() -> void:
	print("-- Travel: wybór pociąg vs samolot wg regionu --")
	Travel.reset_new_game()

	# Richmond i St. Louis są w tym samym regionie (north_america) -> pociąg.
	Travel.current_city = "richmond"
	Travel.route.clear()
	Travel.start_travel("st_louis")
	_assert(Travel.last_travel_vehicle == Travel.Vehicle.TRAIN, "Richmond -> St. Louis (ten sam region) = pociąg")

	# Londyn (europe) i Nowy Jork (north_america) są w różnych regionach -> samolot.
	Travel.reset_new_game()
	Travel.current_city = "london"
	Travel.start_travel("new_york")
	_assert(Travel.last_travel_vehicle == Travel.Vehicle.PLANE, "Londyn -> Nowy Jork (inny region) = samolot")


## Regresja: TravelAnimation.gd dogrywa Calendar.advance_days() na całą
## trasę od razu po animacji (patrz komentarz w TravelAnimation.gd) —
## sprawdza, że to faktycznie kończy podróż, także przy trasie z
## przesiadką (gdzie Travel._on_day_advanced musi poprawnie rozliczyć
## "nadmiarowe" dni między etapami).
func _test_travel_completes_in_one_animation() -> void:
	print("-- Travel: cała podróż kończy się po jednym advance_active_player_time --")
	Travel.reset_new_game()
	Calendar.reset_new_game()
	Players.reset_new_game(1)
	Travel.current_city = "richmond"
	Travel.route.clear()
	Travel.start_travel("st_louis")
	Players.advance_active_player_time(int(ceil(Travel.last_travel_total_days)))
	_assert(not Travel.is_traveling(), "Richmond -> St. Louis: podróż zakończona po jednym advance_active_player_time")
	_assert(Travel.current_city == "st_louis", "Travel.current_city zaktualizowany na miasto docelowe")

	# Trasa z przesiadką (Berlin -> St. Louis, patrz _test_cities_route_via_transfer).
	Travel.reset_new_game()
	Calendar.reset_new_game()
	Players.reset_new_game(1)
	Travel.current_city = "berlin"
	Travel.route.clear()
	Travel.start_travel("st_louis")
	Players.advance_active_player_time(int(ceil(Travel.last_travel_total_days)))
	_assert(not Travel.is_traveling(), "Berlin -> St. Louis (z przesiadką): podróż zakończona po jednym advance_active_player_time")
	_assert(Travel.current_city == "st_louis", "Travel.current_city zaktualizowany na miasto docelowe mimo przesiadki")


## Regresja: przed dodaniem Auctions.gd dom aukcyjny pozwalał kupować
## dowolną liczbę obrazów na żądanie (przycisk "Nowa aukcja" bez ograniczeń)
## — użytkownik zgłosił, że w oryginale aukcje odbywają się tylko w
## konkretnym mieście i dniu (patrz "NEXT AUCTION IS: ..." w oryginalnej
## grze). Sprawdza, że harmonogram faktycznie ogranicza dostępność.
func _test_auctions_schedule() -> void:
	print("-- Auctions: aukcja dostępna tylko we właściwym mieście i terminie --")
	Calendar.reset_new_game()
	Auctions.reset_new_game()
	Players.reset_new_game(1)

	_assert(Cities.get_auction_cities().has(Auctions.next_auction_city), "wylosowane miasto aukcji jest jednym z miast typu 'auction'")
	_assert(Auctions.next_auction_day > Players.active_day(), "termin aukcji jest w przyszłości względem startu gry")
	_assert(not Auctions.is_open(Auctions.next_auction_city), "aukcja jeszcze nieotwarta przed nadejściem terminu")

	var other_city: String = Cities.get_auction_cities().filter(func(c): return c != Auctions.next_auction_city)[0]
	Players.advance_active_player_time(Auctions.next_auction_day - Players.active_day())
	_assert(not Auctions.is_open(other_city), "inne miasto aukcyjne pozostaje zamknięte, nawet gdy termin nadszedł")
	_assert(Auctions.is_open(Auctions.next_auction_city), "właściwe miasto otwiera aukcję dokładnie w zaplanowanym dniu")

	var scheduled_day := Auctions.next_auction_day
	Auctions.resolve_and_reschedule()
	_assert(Auctions.next_auction_day > scheduled_day, "po rozstrzygnięciu losowany jest nowy termin w przyszłości")


## Regresja: "Koniec tury" (Players.DAYS_PER_TURN = 7 dni) potrafił przelecieć
## od razu przez cały dzień aukcji, mimo że gracz stał akurat w mieście, gdzie
## miała się odbyć — nigdy nie dało się trafić dokładnie na termin, żeby
## zdążyć wejść do Domu aukcyjnego (zgłoszone przez użytkownika). Sprawdza,
## że cap_turn_advance skraca skok do dokładnie dnia aukcji w takiej sytuacji,
## a w pozostałych przypadkach zwraca żądaną liczbę dni bez zmian.
func _test_auctions_cap_turn_advance() -> void:
	print("-- Auctions: cap_turn_advance zatrzymuje koniec tury dokładnie na dniu aukcji --")
	Calendar.reset_new_game()
	Auctions.reset_new_game()
	Players.reset_new_game(1)

	var other_city: String = Cities.get_auction_cities().filter(func(c): return c != Auctions.next_auction_city)[0]
	_assert(
		Auctions.cap_turn_advance(7, other_city) == 7,
		"w innym mieście (nie tym z aukcją) skok dni zostaje bez zmian",
	)

	var days_to_auction := Auctions.next_auction_day - Players.active_day()
	if days_to_auction < 7:
		_assert(
			Auctions.cap_turn_advance(7, Auctions.next_auction_city) == days_to_auction,
			"w mieście aukcji, gdy termin jest bliżej niż 7 dni, skok skraca się dokładnie do dnia aukcji",
		)
	else:
		_assert(
			Auctions.cap_turn_advance(7, Auctions.next_auction_city) == 7,
			"w mieście aukcji, gdy termin jest dalej niż 7 dni, skok zostaje bez zmian",
		)

	Players.advance_active_player_time(days_to_auction)
	_assert(
		Auctions.cap_turn_advance(7, Auctions.next_auction_city) == 7,
		"gdy termin już nadszedł (gracz jest na miejscu), skok dni nie jest już capowany",
	)


## Zgłoszone przez użytkownika: aukcja ma pokazywać osobną ramkę dla KAŻDEGO
## gracza fizycznie obecnego w mieście na termin, nie dla wszystkich
## skonfigurowanych graczy. get_present_players() musi wymagać OBU warunków
## naraz (właściwe miasto ORAZ własny dzień >= termin) dla KAŻDEGO gracza
## osobno — snapshots[i]["current_city"] ustawiane ręcznie tu, tak jak inne
## testy poking snapshot state bezpośrednio (patrz np. _test_river_adjacency_detection).
func _test_auctions_present_players() -> void:
	print("-- Auctions: get_present_players zwraca tylko graczy fizycznie obecnych na aukcji --")
	Calendar.reset_new_game()
	Players.reset_new_game(3)
	Auctions.reset_new_game()
	Travel.reset_new_game()

	# Gracz 1 (aktywny): właściwe miasto i termin już nadszedł.
	Travel.current_city = Auctions.next_auction_city
	Players.player_days[0] = Auctions.next_auction_day

	# Gracz 2: to samo miasto, ale jeszcze nie dotarł do właściwego dnia.
	Players.snapshots[1]["current_city"] = Auctions.next_auction_city
	Players.player_days[1] = Auctions.next_auction_day - 1

	# Gracz 3: właściwy dzień, ale stoi w INNYM mieście.
	var other_city: String = Cities.get_auction_cities().filter(func(c): return c != Auctions.next_auction_city)[0]
	Players.snapshots[2]["current_city"] = other_city
	Players.player_days[2] = Auctions.next_auction_day

	var present := Auctions.get_present_players()
	_assert(present.has(0), "gracz 1 (właściwe miasto i dzień) jest obecny")
	_assert(not present.has(1), "gracz 2 (właściwe miasto, ZA WCZEŚNIE) NIE jest obecny")
	_assert(not present.has(2), "gracz 3 (właściwy dzień, INNE miasto) NIE jest obecny")
	_assert(present.size() == 1, "tylko jeden gracz spełnia oba warunki naraz")


func _test_yearly_report_populated_on_new_year() -> void:
	print("-- YearlyReport: migawka gospodarki tworzona przy przejściu do nowego roku --")
	Calendar.reset_new_game()
	Economy.reset_new_game()
	ShippingCompanies.reset_new_game()
	Crops.reset_new_game()
	YearlyReport.reset_new_game()

	_assert(not YearlyReport.has_pending(), "brak podsumowania na starcie gry")

	var days_to_new_year := Calendar.DAYS_PER_MONTH * 12 - Calendar.current_day
	Calendar.advance_days(days_to_new_year)
	_assert(YearlyReport.has_pending(), "po przekroczeniu Sylwestra podsumowanie czeka na pokazanie")

	var report := YearlyReport.consume_pending()
	_assert(report["year"] == Calendar.START_YEAR, "podsumowanie dotyczy roku, który się właśnie skończył, nie nowego")
	_assert(report["shipping"].size() == ShippingCompanies.COMPANIES.size(), "migawka zawiera kursy wszystkich linii żeglugowych")
	_assert(report["crops"].size() == Crops.CROPS.size(), "migawka zawiera ceny wszystkich towarów")
	_assert(not YearlyReport.has_pending(), "consume_pending() czyści podsumowanie, żeby nie pokazało się drugi raz")


func _test_grant_new_year_to_random_player_awards_money_and_avoids_duplicate_paintings() -> void:
	print("-- Players: grant_new_year_to_random_player — gotówka zawsze, obraz bez duplikatów --")
	Players.reset_new_game(1)
	Paintings.reset_new_game()
	Economy.reset_new_game()

	var money_before := Economy.player_money
	var result := Players.grant_new_year_to_random_player(1000.0, 0.0)
	_assert(result["winner_index"] == 0, "jedyny gracz zawsze wygrywa (player_count=1)")
	_assert(result["painting_number"] == -1, "painting_chance=0.0 nigdy nie daje obrazu")
	_assert(is_equal_approx(Economy.player_money, money_before + 1000.0), "gotówka doliczona zwycięzcy")

	## painting_chance=1.0: zawsze przyznaje obraz, dopóki jakiś jest dostępny — nigdy
	## numer, który zwycięzca już ma (already_catalogued filtr w grant_new_year_to_random_player).
	## Po wyczerpaniu całego katalogu (40) spada z powrotem na samą gotówkę — deterministyczny
	## dowód działania tego zabezpieczenia, bez potrzeby losowej pętli.
	var granted_numbers: Array[int] = []
	for i in Paintings.CATALOG.size():
		var r := Players.grant_new_year_to_random_player(0.0, 1.0)
		_assert(r["painting_number"] > 0, "painting_chance=1.0 przyznaje obraz, dopóki katalog nie jest wyczerpany (próba %d)" % i)
		_assert(not granted_numbers.has(r["painting_number"]), "nigdy nie przyznaje numeru, który zwycięzca już ma")
		granted_numbers.append(r["painting_number"])
	_assert(Paintings.owned_count() == Paintings.CATALOG.size(), "cały katalog skatalogowany po tylu wygranych z rzędu")

	var r_exhausted := Players.grant_new_year_to_random_player(500.0, 1.0)
	_assert(r_exhausted["painting_number"] == -1, "po wyczerpaniu całego katalogu spada z powrotem na samą gotówkę")


func _test_grant_new_year_credits_correct_player_in_multiplayer() -> void:
	print("-- Players: grant_new_year_to_random_player — dolicza gotówkę WŁAŚCIWEMU graczowi (aktywnemu i migawce) --")
	Players.reset_new_game(3)
	Paintings.reset_new_game()
	Economy.reset_new_game()

	var before: Array[float] = [Players.get_player_money(0), Players.get_player_money(1), Players.get_player_money(2)]
	for i in 20:
		var result := Players.grant_new_year_to_random_player(777.0, 0.0)
		var winner: int = result["winner_index"]
		_assert(winner >= 0 and winner < 3, "zwycięzca to zawsze poprawny indeks gracza")
		_assert(is_equal_approx(Players.get_player_money(winner), before[winner] + 777.0), "gotówka doliczona DOKŁADNIE zwycięzcy")
		before[winner] += 777.0
		for j in 3:
			if j != winner:
				_assert(is_equal_approx(Players.get_player_money(j), before[j]), "pozostali gracze bez zmian")


func _test_new_year_lottery_populates_pending_after_new_year() -> void:
	print("-- Lottery: wynik Noworocznej Loterii trafia do kolejki po przekroczeniu Sylwestra --")
	Calendar.reset_new_game()
	Economy.reset_new_game()
	Players.reset_new_game(1)
	Paintings.reset_new_game()
	Lottery.reset_new_game()

	_assert(not Lottery.has_pending(), "brak wyniku loterii na starcie gry")

	var days_to_new_year := Calendar.DAYS_PER_MONTH * 12 - Calendar.current_day
	Calendar.advance_days(days_to_new_year)
	_assert(Lottery.has_pending(), "po przekroczeniu Sylwestra wynik loterii czeka na pokazanie")

	var pending := Lottery.consume_pending()
	_assert(pending["winner_index"] == 0, "jedyny gracz zawsze wygrywa (player_count=1)")
	_assert(pending["year"] == Calendar.START_YEAR + 1, "pending niesie NOWY rok, ten sam co niesie Calendar.new_year")
	_assert(
		pending["money"] >= Economy.NEW_YEAR_MONEY_RANGE.x and pending["money"] <= Economy.NEW_YEAR_MONEY_RANGE.y,
		"kwota mieści się w Economy.NEW_YEAR_MONEY_RANGE",
	)
	_assert(pending.has("painting_number"), "pending zawiera klucz painting_number (obraz albo -1)")
	_assert(not Lottery.has_pending(), "consume_pending() czyści wynik, żeby nie pokazał się drugi raz")


func _test_players_gender_and_avatar_selection() -> void:
	print("-- Players: wybór płci i awatara --")
	Players.reset_new_game(2)

	_assert(Players.player_genders[0] == Players.GENDERS[0], "domyślna płeć gracza 1 to pierwsza z GENDERS")
	_assert(Players.player_avatar_variants[0] == Players.AVATAR_VARIANTS[0], "domyślny wariant awatara gracza 1 to pierwszy z AVATAR_VARIANTS")

	Players.set_player_gender(1, "female")
	Players.set_player_avatar(1, "boa")
	_assert(Players.player_genders[1] == "female", "płeć gracza 2 ustawiona na 'female'")
	_assert(Players.player_avatar_variants[1] == "boa", "wariant awatara gracza 2 ustawiony na 'boa'")
	_assert(Players.get_avatar_path(1) == "res://art/characters/female_boa.jpg", "ścieżka awatara łączy płeć i wariant")

	Players.set_player_gender(1, "nieznana_plec")
	Players.set_player_avatar(1, "nieznany_wariant")
	_assert(Players.player_genders[1] == "female", "nieprawidłowa płeć nie nadpisuje poprzedniego wyboru")
	_assert(Players.player_avatar_variants[1] == "boa", "nieprawidłowy wariant nie nadpisuje poprzedniego wyboru")


func _test_price_history_for_charts() -> void:
	print("-- ShippingCompanies/Crops: historia cen do wykresu na Giełdzie --")
	Calendar.reset_new_game()
	ShippingCompanies.reset_new_game()
	Crops.reset_new_game()

	## Zgłoszone przez użytkownika: na starcie nowej gry wykres ma już mieć
	## losową "przeszłość" (nie płaski pojedynczy punkt) — reset_new_game
	## dogenerowuje INITIAL_HISTORY_POINTS punktów, pierwszy zawsze = cena
	## bazowa, ostatni = aktualna (losowa) cena startowa.
	_assert(
		ShippingCompanies.price_history["lloyd"].size() == ShippingCompanies.INITIAL_HISTORY_POINTS,
		"historia kursu Lloyd zaczyna się z INITIAL_HISTORY_POINTS punktami",
	)
	_assert(ShippingCompanies.price_history["lloyd"][0] == ShippingCompanies.STARTING_PRICE, "pierwszy punkt to STARTING_PRICE")
	_assert(ShippingCompanies.price_history["lloyd"][-1] == ShippingCompanies.get_price("lloyd"), "ostatni punkt historii = aktualna (losowa) cena startowa")
	_assert(
		Crops.price_history["coffee"].size() == Crops.INITIAL_HISTORY_POINTS,
		"historia ceny kawy zaczyna się z INITIAL_HISTORY_POINTS punktami",
	)

	## Calendar.advance_days (nie wywoływanie _on_day_advanced bezpośrednio) —
	## tak samo jak reszta gry, przez sygnał Calendar.day_advanced, pod który
	## podpięte są ShippingCompanies i Crops.
	var lloyd_size_before: int = ShippingCompanies.price_history["lloyd"].size()
	var coffee_size_before: int = Crops.price_history["coffee"].size()
	Calendar.advance_days(7)
	_assert(ShippingCompanies.price_history["lloyd"].size() == lloyd_size_before + 1, "kolejny skok dni dopisuje kolejny punkt historii (Lloyd)")
	_assert(Crops.price_history["coffee"].size() == coffee_size_before + 1, "kolejny skok dni dopisuje kolejny punkt historii (kawa)")
	_assert(ShippingCompanies.price_history["lloyd"][-1] == ShippingCompanies.get_price("lloyd"), "ostatni punkt historii = aktualna cena")

	## MAX_HISTORY_POINTS ogranicza długość historii (najstarsze punkty
	## wypadają, FIFO) — bez tego pamięć/szerokość wykresu rosłaby bez końca
	## w bardzo długiej grze.
	for i in ShippingCompanies.MAX_HISTORY_POINTS + 10:
		Calendar.advance_days(7)
	_assert(
		ShippingCompanies.price_history["lloyd"].size() == ShippingCompanies.MAX_HISTORY_POINTS,
		"historia kursu nie rośnie w nieskończoność, zatrzymuje się na MAX_HISTORY_POINTS",
	)


## Niezależne linie czasu per gracz (hot-seat) — patrz nagłówek Players.gd.
## Testy niżej pokrywają nowy podział Tor A ("świat", Calendar.current_day,
## wspólny) / Tor B (Players.player_days, osobisty dla każdego gracza).
func _test_players_days_diverge() -> void:
	print("-- Players: gracze mają niezależne linie czasu --")
	Calendar.reset_new_game()
	Players.reset_new_game(2)
	Players.advance_active_player_time(10)
	_assert(Players.get_player_day(0) == 10, "gracz 1 (aktywny) ma dzień 10 po własnej akcji")
	_assert(Players.get_player_day(1) == 0, "gracz 2 pozostaje na dniu 0 (nie wykonał żadnej akcji)")
	_assert(Players.get_player_day(0) != Players.get_player_day(1), "linie czasu graczy się rozjeżdżają")


## Zgłoszone przez użytkownika: wyścigi konne (Races.gd) nie mogą być dostępne
## bez ograniczeń w obrębie jednej tury — limit Players.DAYS_PER_TURN między
## zakładami, liczony WŁASNYM czasem aktywnego gracza (Tor B).
func _test_races_cooldown_between_bets() -> void:
	print("-- Players: limit między zakładami na wyścigach (DAYS_PER_TURN) --")
	Calendar.reset_new_game()
	Players.reset_new_game(1)

	_assert(Players.days_since_last_race() >= Players.DAYS_PER_TURN, "na starcie nowej gry pierwszy zakład jest od razu możliwy")
	Players.record_race()
	_assert(Players.days_since_last_race() == 0, "zaraz po zakładzie licznik wraca do zera")

	Players.advance_active_player_time(3)
	_assert(Players.days_since_last_race() == 3 and Players.days_since_last_race() < Players.DAYS_PER_TURN, "po 3 dniach limit jeszcze nie minął")

	Players.advance_active_player_time(Players.DAYS_PER_TURN - 3)
	_assert(Players.days_since_last_race() >= Players.DAYS_PER_TURN, "po pełnym DAYS_PER_TURN limit minął, kolejny zakład znów możliwy")


## Zgłoszone przez użytkownika: kursy koni mają dryfować jak ceny na Giełdzie/
## Rynku, nie być raz na zawsze ustawioną stałą (Horses.gd, ten sam wzorzec
## dryfu co ShippingCompanies.gd). Sprawdzamy dwie rzeczy naraz: że kurs
## faktycznie się zmienia po wielu skokach dni (nie stoi w miejscu), i że
## MIN_ODDS/MAX_ODDS trzymają go w rozsądnych granicach mimo wielu powtórzeń
## losowego dryfu (bez tego kurs mógłby "uciec" do zera i rozwalić wagę
## 1.0/odds w Races._pick_winner_index, albo wystrzelić do absurdu).
func _test_horses_odds_drift_and_bounds() -> void:
	print("-- Horses: kurs dryfuje dziennie i trzyma się w granicach MIN/MAX_ODDS --")
	Calendar.reset_new_game()
	Horses.reset_new_game()

	var starting_odds := Horses.get_odds("komet")
	var changed_at_least_once := false
	for i in 200:
		Calendar.advance_days(7)
		var odds := Horses.get_odds("komet")
		_assert(odds >= Horses.MIN_ODDS and odds <= Horses.MAX_ODDS, "kurs Komet w granicach [MIN_ODDS, MAX_ODDS] (iteracja %d)" % i)
		if not is_equal_approx(odds, starting_odds):
			changed_at_least_once = true
	_assert(changed_at_least_once, "kurs Komet faktycznie dryfuje po wielu skokach dni, nie stoi w miejscu")


## Zgłoszone przez użytkownika: kursy koni mają być WSPÓLNE — ten sam dzień =
## ten sam kurs, niezależnie który gracz akurat stawia zakład (Horses.gd to
## Tor A, podłączony do Calendar.day_advanced, nie do per-gracz
## Players.advance_active_player_time — ten sam wzorzec co
## _test_shared_price_by_day niżej dla Crops/ShippingCompanies).
func _test_horses_odds_shared_by_day() -> void:
	print("-- Horses: ten sam dzień = ten sam kurs, niezależnie kto dotarł pierwszy --")
	Calendar.reset_new_game()
	Players.reset_new_game(2)
	Horses.reset_new_game()

	Players.advance_active_player_time(15)  # gracz 1 pcha świat do dnia 15
	var odds_after_player_1 := Horses.get_odds("wicher")

	Players.pass_turn_to_earliest_player()
	_assert(Players.active_index == 1, "gracz 2 (dzień 0, najwcześniejsza data) dostaje ruch")
	Players.advance_active_player_time(15)  # gracz 2 dogania do dnia 15 — już zasymulowanego

	_assert(is_equal_approx(Horses.get_odds("wicher"), odds_after_player_1), "gracz 2, docierając do TEGO SAMEGO dnia, widzi ten sam kurs Wicher")


## Zgłoszenie użytkownika: wynik wyścigu nie może być oczywisty od razu — bieg
## od startu (prawo) do mety (lewo), każdy koń ma WŁASNY moment przekroczenia
## mety (t_cross), krzywa potęgowa daje organiczne zmiany prowadzenia po
## drodze. Kluczowa gwarancja uczciwości MUSI się trzymać niezależnie od tego
## losowania: zwycięzca (ustalony PRZED animacją, patrz komentarz w
## RaceTrackView.gd) ma ściśle NAJMNIEJSZY t_cross ze wszystkich koni (a więc
## miejsce 1.), a przy t=1 (koniec animacji) stoi dokładnie na mecie, tak jak
## wszyscy pozostali. Powtarzamy z wieloma losowymi zwycięzcami, żeby złapać
## ewentualny błąd we wzorze niezależnie od tego, który koń akurat wygrywa.
func _test_race_track_winner_finishes_first() -> void:
	print("-- RaceTrackView: zwycięzca ma najmniejszy t_cross (miejsce 1.), niezależnie od losowej krzywej biegu --")
	var image_paths: Array[String] = [
		"res://art/horses/komet.jpg", "res://art/horses/grom.jpg", "res://art/horses/cyklon.jpg",
		"res://art/horses/blyskawica.jpg", "res://art/horses/wicher.jpg",
	]
	var names: Array[String] = ["Komet", "Grom", "Cyklon", "Błyskawica", "Wicher"]
	for trial in 20:
		var winner_idx := randi() % image_paths.size()
		var view: Control = RaceTrackScript.new()
		add_child(view)
		view.setup(image_paths, names, winner_idx, Vector2(1280.0, 720.0))

		var winner_cross: float = view.t_cross[winner_idx]
		var winner_is_earliest := true
		for i in image_paths.size():
			if i != winner_idx and view.t_cross[i] <= winner_cross:
				winner_is_earliest = false
		_assert(winner_is_earliest, "próba %d: zwycięzca (koń %d) ma najmniejszy t_cross (miejsce 1.)" % [trial, winner_idx])
		_assert(view.places[winner_idx] == 1, "próba %d: zwycięzca (koń %d) ma dokładnie miejsce 1." % [trial, winner_idx])
		_assert(is_equal_approx(view._horse_x(winner_idx, 1.0), view.finish_x), "próba %d: zwycięzca stoi na mecie przy t=1" % trial)
		view.queue_free()


## Zgłoszone przez użytkownika: układanka eksperckości w Szkole sztuki ma
## "randomowo się układać" — kolejność odkrywania kafelków jest przetasowana
## (nie rząd po rzędzie), ale STAŁA (REVEAL_SEED w ExpertisePuzzle.gd), więc
## dwie osobne instancje muszą dać dokładnie ten sam reveal_rank. Dodatkowo
## set_progress musi być monotoniczne: więcej odkrytych kafelków przy wyższym
## fraction, nigdy mniej, i dokładnie GRID*GRID przy fraction=1.0.
func _test_expertise_puzzle_reveal_stable_and_monotonic() -> void:
	print("-- ExpertisePuzzle: stały (powtarzalny) losowy układ + monotoniczne odkrywanie kafelków --")
	var view_a: Control = ExpertisePuzzleScript.new()
	add_child(view_a)
	view_a.setup("res://art/art_school/expertise_puzzle.jpg", Vector2(240, 240))

	var view_b: Control = ExpertisePuzzleScript.new()
	add_child(view_b)
	view_b.setup("res://art/art_school/expertise_puzzle.jpg", Vector2(240, 240))

	_assert(view_a.reveal_rank == view_b.reveal_rank, "dwie instancje mają identyczny reveal_rank (stały seed)")

	var total: int = view_a.GRID * view_a.GRID
	var previous_count := -1
	for step in total + 1:
		var fraction: float = float(step) / float(total)
		view_a.set_progress(fraction)
		var revealed_count := 0
		for tile in view_a.tiles:
			if tile.visible:
				revealed_count += 1
		_assert(revealed_count >= previous_count, "krok %d: liczba odkrytych kafelków nie maleje (%d -> %d)" % [step, previous_count, revealed_count])
		_assert(revealed_count == step, "krok %d: dokładnie %d/%d kafelków odkrytych przy fraction=%.2f" % [step, step, total, fraction])
		previous_count = revealed_count

	view_a.queue_free()
	view_b.queue_free()


## Zgłoszone przez użytkownika: ceny na Giełdzie/Rynku mają być WSPÓLNE — ten
## sam dzień = ta sama cena, niezależnie kto do niego dotarł pierwszy. Skoro
## Crops/ShippingCompanies to Tor A (nie migawkowane per gracz), gracz
## doganiający resztę do JUŻ zasymulowanego dnia po prostu odczytuje tę samą,
## niezmienioną cenę — nie losuje jej na nowo.
func _test_shared_price_by_day() -> void:
	print("-- Crops/ShippingCompanies: ten sam dzień = ta sama cena, niezależnie kto dotarł pierwszy --")
	Calendar.reset_new_game()
	Players.reset_new_game(2)
	Crops.reset_new_game()
	ShippingCompanies.reset_new_game()

	Players.advance_active_player_time(15)  # gracz 1 pcha świat do dnia 15
	var price_after_player_1 := Crops.get_price("coffee")
	var shipping_after_player_1 := ShippingCompanies.get_price("lloyd")

	Players.pass_turn_to_earliest_player()
	_assert(Players.active_index == 1, "gracz 2 (dzień 0, najwcześniejsza data) dostaje ruch")
	Players.advance_active_player_time(15)  # gracz 2 dogania do dnia 15 — już zasymulowanego

	_assert(is_equal_approx(Crops.get_price("coffee"), price_after_player_1), "gracz 2, docierając do TEGO SAMEGO dnia, widzi tę samą cenę kawy")
	_assert(is_equal_approx(ShippingCompanies.get_price("lloyd"), shipping_after_player_1), "to samo dla kursu linii żeglugowej Lloyd")
	_assert(Players.get_player_day(1) == 15, "własny dzień gracza 2 mimo to poprawnie dochodzi do 15")


## Regresja na błąd znaleziony przez agenta walidującego plan: bez rozdziału
## Toru A/B, gracz doganiający resztę mógłby wywołać DRUGI raz ten sam skok
## światowego dryfu cen dla zakresu dni, który już raz się wydarzył.
func _test_catching_up_player_does_not_double_world_drift() -> void:
	print("-- Players: gracz doganiający resztę nie podwaja światowego dryfu (Tor A rusza raz na dzień) --")
	Calendar.reset_new_game()
	Players.reset_new_game(2)
	Crops.reset_new_game()

	Players.advance_active_player_time(15)
	var history_size_after_player_1: int = Crops.price_history["coffee"].size()
	var world_day_after_player_1: int = Calendar.current_day

	Players.pass_turn_to_earliest_player()
	Players.advance_active_player_time(15)  # gracz 2 dogania do JUŻ zasymulowanego dnia 15

	_assert(Calendar.current_day == world_day_after_player_1, "świat (Tor A) nie rusza się dalej, gdy doganiający gracz nie wychodzi poza już zasymulowany zakres")
	_assert(Crops.price_history["coffee"].size() == history_size_after_player_1, "historia cen nie dostaje dodatkowego punktu za doganianie tego samego zakresu dni")


## Regresja na błąd znaleziony przez agenta walidującego plan: Economy.gd
## trzymało days_in_debt w tym samym _on_day_advanced co dollar_rate/inflation
## (Tor A) — bez wydzielenia go do apply_player_days_elapsed (Tor B), zadłużenie
## gracza doganiającego resztę liczyłoby się na podstawie delty ŚWIATA, a nie
## jego WŁASNYCH dni, i wynosiłoby 0, mimo że dla NIEGO te dni realnie minęły.
func _test_catching_up_player_gets_full_personal_consequences() -> void:
	print("-- Players: gracz doganiający dostaje PEŁNE osobiste konsekwencje, nawet gdy świat się nie rusza --")
	Calendar.reset_new_game()
	Players.reset_new_game(2)
	Economy.reset_new_game()

	Players.advance_active_player_time(20)  # gracz 1 pcha świat do dnia 20

	Players.pass_turn_to_earliest_player()
	_assert(Players.active_index == 1, "gracz 2 (dzień 0) jest teraz najwcześniejszy")
	Economy.player_money = -100.0  # symulacja długu gracza 2

	Players.advance_active_player_time(20)  # gracz 2 dogania do dnia 20 — Tor A JUŻ tam był

	_assert(Calendar.current_day == 20, "świat pozostaje na dniu 20 (bez zmian od tej akcji)")
	_assert(Economy.days_in_debt == 20, "mimo braku ruchu świata, gracz 2 dostaje PEŁNE 20 dni w długu (Tor B liczy się z jego WŁASNEJ perspektywy)")


## Regresja na drugi (najkrytyczniejszy) błąd znaleziony przez agenta
## walidującego plan: Travel.gd było pierwotnie pominięte na liście systemów
## Toru B — bez przełączenia go na apply_player_days_elapsed, podróż gracza
## doganiającego resztę zawieszałaby się w połowie trasy, gdy Tor A nie ma już
## dla niego nowych dni do rozegrania.
func _test_catching_up_player_completes_travel() -> void:
	print("-- Travel: gracz doganiający kończy podróż, nawet gdy Tor A się nie rusza --")
	Calendar.reset_new_game()
	Players.reset_new_game(2)
	Travel.reset_new_game()

	Players.advance_active_player_time(30)  # gracz 1 pcha świat daleko do przodu

	Players.pass_turn_to_earliest_player()
	_assert(Players.active_index == 1, "gracz 2 (dzień 0) jest teraz najwcześniejszy")

	Travel.current_city = "berlin"
	Travel.route.clear()
	Travel.start_travel("london")  # 3.0 dnia — krócej niż to, co świat już zasymulował
	var days := int(ceil(Travel.last_travel_total_days))
	Players.advance_active_player_time(days)  # gracz 2 dogania w obrębie już zasymulowanego zakresu

	_assert(not Travel.is_traveling(), "podróż gracza 2 kończy się mimo że Tor A (Calendar.current_day) się nie rusza")
	_assert(Travel.current_city == "london", "Travel.current_city gracza 2 poprawnie zaktualizowany na miasto docelowe")


## Zgłoszone przez użytkownika: literówka typu (Container zamiast Control w
## parametrze funkcji) w Gallery.gd przeszła całe CI bez wykrycia — boot
## headless (patrz nagłówek pliku) parsuje tylko autoloady + GŁÓWNĄ scenę,
## więc skrypty POZOSTAŁYCH ekranów (Gallery.gd, AuctionHouse.gd, ...) nigdy
## nie są odwiedzane, chyba że akurat są sceną startową. Błąd wyszedł dopiero
## przy ręcznym uruchomieniu w edytorze. Ten test ładuje KAŻDY skrypt sceny
## wprost przez load() — błąd parsera (Godot loguje "Parse Error" i load()
## zwraca null) wykryje się więc już tutaj, w CI.
func _test_all_scene_scripts_parse_without_error() -> void:
	print("-- Sanity: wszystkie skrypty scen (scenes/**/*.gd) ładują się bez błędu parsera --")
	var script_paths := _find_gd_scripts("res://scenes")
	_assert(script_paths.size() > 0, "znaleziono przynajmniej jeden skrypt sceny do sprawdzenia")
	for path in script_paths:
		var script: Script = load(path)
		_assert(script != null, "ładuje się bez błędu parsera: %s" % path)


## Rekurencyjne przejście katalogu w poszukiwaniu plików .gd — DirAccess
## zamiast statycznej listy, żeby nowe ekrany automatycznie wchodziły pod
## powyższy test bez pamiętania o dopisaniu ich ręcznie.
func _find_gd_scripts(dir_path: String) -> Array[String]:
	var result: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return result
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry != "." and entry != "..":
			var full_path := dir_path + "/" + entry
			if dir.current_is_dir():
				result.append_array(_find_gd_scripts(full_path))
			elif entry.ends_with(".gd"):
				result.append(full_path)
		entry = dir.get_next()
	dir.list_dir_end()
	return result
