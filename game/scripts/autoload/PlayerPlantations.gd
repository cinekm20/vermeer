extends Node
## Plantacje: siatka pól z rzeką, uprawa, robotnicy, zbiory.
## Uproszczony model — patrz docs/MECHANIKI_EKONOMICZNE.md pkt. 3–4.
## Dokładny wzór plonu z oryginału nie jest odtwarzalny 1:1 (zależał od
## wielu nieudokumentowanych czynników), więc formuła niżej jest świadomie
## uproszczonym, tunowalnym placeholderem do dalszego balansowania.
##
## Zgłoszone przez użytkownika: "plantacje w danym mieście powinny być
## wygenerowane na początku gry i powinny być wspólne dla wszystkich
## graczy, czyli ten który zasieje w lepszym miejscu będzie miał lepsze
## plony". Stąd DWA osobne magazyny danych:
## 1. `city_grids` — WSPÓLNY teren KAŻDEGO miasta plantacyjnego (rzeka +
##    WŁASNOŚĆ każdego pola), wygenerowany RAZ w reset_new_game() dla
##    całej gry. Celowo NIE jest migawkowany przez Players.gd (w
##    odróżnieniu od `plantations` niżej) — to fakt świata widoczny dla
##    WSZYSTKICH graczy jednocześnie, nie stan jednego z nich. Pole raz
##    kupione przez gracza X jest od tej pory niedostępne dla reszty aż do
##    końca gry (albo aż X je straci, patrz _apply_crisis_hit) — to
##    właśnie realizuje "kto zasieje w lepszym miejscu, ten ma lepsze
##    plony": kto pierwszy zajmie pola przy rzece, blokuje je reszcie.
## 2. `plantations` — WŁASNE (per gracz) rekordy "mam tu jakąś obecność":
##    robotnicy/zapasy/dzień ostatnich zbiorów/licznik kryzysów. Te SĄ
##    migawkowane przez Players.gd (Players._capture_active/_apply_snapshot
##    duplikują/przywracają tę tablicę przy zmianie aktywnego gracza) —
##    ilu robotników zatrudnia dany gracz i ile ma w magazynie to JEGO
##    własna sprawa, nie widoczna dla reszty.
## Funkcje odczytujące/zmieniające WŁASNOŚĆ konkretnego pola (buy_tile,
## plant_tile, get_owned_tile_count, get_planted_tile_count,
## calculate_harvest) zawsze odnoszą się do Players.active_index — bo
## `plantations` to i tak zawsze lista TYLKO aktywnego gracza (Players.gd
## zamienia całą tablicę przy przełączeniu tury, patrz komentarz w
## Players.gd), więc "który gracz pyta" jest zawsze jednoznaczne.

const GRID_SIZE := 16
const TILE_COST := 500.0
const WORKER_DAILY_WAGE := 1.0
const MAX_WORKERS := 500
const REFERENCE_TILE_COUNT := 50.0  ## odniesienie do tabeli plonów (ok. 50 ha przy rzece)

## Ryzyko regionalne (zgłoszone przez użytkownika, docs/GDD.md pkt. 4.2):
## strajk (brak wypłat robotnikom) i zamieszki/wywłaszczenie w niestabilnym
## regionie (Cities.REGION_UNREST_CHANCE_PER_WEEK) mają TE SAME konsekwencje
## — zabrane zapasy + ucieczka części załogi (patrz _apply_crisis_hit) —
## dzielone przez jeden wspólny licznik "crisis_hits" na plantację,
## niezależnie od przyczyny. Po CRISIS_HITS_TO_LOSE_PLANTATION kolejne
## uderzenie (obojętnie jakiej przyczyny) zabiera CAŁĄ plantację: "jak
## dłużej trwa to zabieranie plantacji" (zgłoszone przez użytkownika) —
## łącznie ze zwolnieniem WSZYSTKICH pól tego gracza z powrotem do puli
## wspólnej (patrz _release_player_tiles), żeby ktoś inny mógł je zająć.
const CRISIS_HITS_TO_LOSE_PLANTATION := 3
const CRISIS_WORKER_LOSS_RATIO := 0.5  ## ucieka połowa aktualnej załogi za każdym uderzeniem

## Ryzyko pogodowe (susza/powódź) — docs/DODATKOWE_MECHANIKI.md, tipy do
## sequela: "Pompy wodne: inwestycja podnosząca plon i chroniąca przed
## klęskami (susza/powódź)". W odróżnieniu od ryzyka regionalnego
## (Cities.REGION_UNREST_CHANCE_PER_WEEK, tylko Afryka/Azja) pogoda dotyczy
## KAŻDEJ plantacji jednakowo, niezależnie od regionu — stąd stała tu, nie w
## Cities.gd. Ta sama konsekwencja co strajk/zamieszki (_apply_crisis_hit,
## dzielony licznik crisis_hits), tylko z WŁASNĄ przyczyną ("weather") do
## rozróżnienia w karcie gazety (patrz WorldEventCard.gd).
const WEATHER_RISK_CHANCE_PER_WEEK := 0.03
## Plantacja z pompą jest CAŁKOWICIE odporna na to konkretne ryzyko (patrz
## apply_player_days_elapsed) — "chroniąca przed klęskami" z materiału
## źródłowego, nie tylko je łagodząca.
const WATER_PUMP_COST := 5000.0  ## rząd wielkości Security.BODYGUARD_COST — duża, jednorazowa inwestycja infrastrukturalna
const WATER_PUMP_YIELD_BONUS := 1.2  ## +20% plonu całej plantacji, patrz calculate_harvest

## Psucie się towaru (docs/DODATKOWE_MECHANIKI.md, tipy do sequela: "Towar
## zalegający na magazynie dłużej niż rok psuje się"). Rok gry = pełne 12
## miesięcy × Calendar.DAYS_PER_MONTH (uproszczony kalendarz, patrz
## Calendar.gd) — NIE duplikujemy tej liczby jako osobnej stałej "360",
## żeby przy ewentualnej zmianie długości miesiąca w Calendar.gd próg
## zepsucia automatycznie poszedł za nią. Uproszczony model (tak jak reszta
## tego pliku — patrz komentarz nagłówkowy): CAŁY zapas danej uprawy psuje
## się naraz po przekroczeniu progu, nie stopniowo — ten sam "tunable
## placeholder" charakter co _apply_crisis_hit.
const GOODS_SPOILAGE_DAYS := Calendar.DAYS_PER_MONTH * 12

## Konfiskata przemycanej uprawy (Crops.CONTRABAND_CROP) — docs/DODATKOWE_MECHANIKI.md,
## tipy do sequela: "ukryte, nielegalne lokalne uprawy... mechanika
## konfiskaty". Wyższe niż WEATHER_RISK_CHANCE_PER_WEEK — to nielegalny
## towar, ryzyko ma być odczuwalne, nie kosmetyczne. Sprawdzane co tydzień,
## dopóki gracz TRZYMA choćby jedną jednostkę w magazynie (patrz
## _apply_contraband_confiscation) — w odróżnieniu od _apply_crisis_hit,
## konfiskata zabiera WYŁĄCZNIE ten jeden towar, nie całą plantację/załogę.
const CONTRABAND_CONFISCATION_CHANCE_PER_WEEK := 0.05

var plantations: Array[Dictionary] = []

## city_id -> {"river": Array[bool], "tile_owner": Array[int] (-1 = wolne,
## inaczej indeks gracza-właściciela), "tile_crops": Array[String]}.
## Wspólne dla WSZYSTKICH graczy — patrz komentarz nagłówkowy pliku.
var city_grids: Dictionary = {}


func reset_new_game() -> void:
	plantations.clear()
	generate_all_city_grids()


## Generuje ŚWIEŻY, w pełni niezajęty teren dla KAŻDEGO miasta typu
## "plantation" (Cities.CITIES) — wywoływane RAZ na nową grę (reset_new_game)
## i jako fallback przy wczytaniu zapisu sprzed tej funkcji (patrz
## SaveGame.gd), żeby stare zapisy dostały jakikolwiek teren zamiast
## pustego city_grids.
func generate_all_city_grids() -> void:
	city_grids.clear()
	for city_id in Cities.CITIES.keys():
		if Cities.CITIES[city_id]["type"] == "plantation":
			city_grids[city_id] = _generate_city_grid()


func _generate_city_grid() -> Dictionary:
	var tile_owner: Array[int] = []
	tile_owner.resize(GRID_SIZE * GRID_SIZE)
	tile_owner.fill(-1)
	var tile_crops: Array[String] = []
	tile_crops.resize(GRID_SIZE * GRID_SIZE)
	tile_crops.fill("")
	return {
		"river": _generate_river(),
		"tile_owner": tile_owner,
		"tile_crops": tile_crops,
	}


## Tor B — osobiste dla aktywnego gracza: płaca robotników + ryzyko
## regionalne (strajk/zamieszki, patrz stała komentarz wyżej) naliczają się
## cyklicznie za każdy dzień pracy. Wywoływane wprost przez
## Players.advance_active_player_time (NIE podłączone do Calendar.day_advanced
## — to osobisty koszt/ryzyko TEGO gracza, nie zjawisko globalne).
## Iteracja przez indeks (nie `for plantation in plantations`) — plantacja
## utracona w trakcie pętli (_apply_crisis_hit zwraca true) musi zniknąć z
## `plantations` OD RAZU, więc trzeba nią bezpiecznie manipulować w locie.
func apply_player_days_elapsed(days_elapsed: int) -> void:
	var weeks: float = float(days_elapsed) / 7.0
	var i := 0
	while i < plantations.size():
		var plantation: Dictionary = plantations[i]
		var wage_cost: float = int(plantation["workers"]) * WORKER_DAILY_WAGE * days_elapsed
		if wage_cost > 0.0:
			Economy.player_money -= wage_cost

		## Robotniko-dni narosłe OD OSTATNICH ZBIORÓW (patrz calculate_harvest,
		## harvest()) — liczone TU, z faktyczną liczbą robotników w KAŻDYM z
		## tych dni, więc zatrudnienie tuż przed zbiorem (a zwolnienie zaraz
		## po) nie daje już pełnego plonu za darmo: dni spędzone z zerową
		## załogą wliczają się do średniej tak samo jak dni z pełną.
		plantation["worker_days_accum"] = float(plantation.get("worker_days_accum", 0.0)) + int(plantation["workers"]) * days_elapsed

		## Strajk: brak wypłat (gotówka na minusie) PRZY zatrudnionej załodze —
		## zgłoszone przez użytkownika. Sprawdzane PO odjęciu tej płacy, żeby
		## strajk reagował na FAKTYCZNY, bieżący stan konta, nie sprzed niej.
		var lost := int(plantation["workers"]) > 0 and Economy.player_money < 0.0 and _apply_crisis_hit(plantation, "wages")

		## Zamieszki: niezależne od wypłat, losowane wg niestabilności REGIONU
		## tej plantacji (Cities.REGION_UNREST_CHANCE_PER_WEEK) — pominięte,
		## jeśli strajk w tym samym kroku już i tak zabrał plantację.
		if not lost:
			var region: String = Cities.CITIES[plantation["city"]]["region"]
			var chance_per_week: float = Cities.REGION_UNREST_CHANCE_PER_WEEK.get(region, 0.0)
			if chance_per_week > 0.0 and randf() < chance_per_week * weeks * Difficulty.risk_multiplier():
				lost = _apply_crisis_hit(plantation, "unrest")

		## Susza/powódź: ta sama logika co zamieszki wyżej, ale JEDNAKOWE
		## ryzyko dla każdej plantacji (nie zależne od regionu) i CAŁKOWICIE
		## pominięte, jeśli gracz ma tu pompę wodną — patrz WATER_PUMP_COST.
		if not lost and not bool(plantation.get("has_water_pump", false)):
			if randf() < WEATHER_RISK_CHANCE_PER_WEEK * weeks * Difficulty.risk_multiplier():
				lost = _apply_crisis_hit(plantation, "weather")

		## Psucie się towaru (docs/DODATKOWE_MECHANIKI.md, tipy do sequela:
		## "Towar zalegający na magazynie dłużej niż rok psuje się") —
		## niezależne od kryzysów wyżej, więc sprawdzane zawsze, dopóki
		## plantacja jeszcze istnieje (bez sensu psuć magazyn plantacji, którą
		## właśnie i tak stracono w tym samym kroku).
		if not lost:
			_apply_spoilage(plantation)

		## Konfiskata przemycanej uprawy (docs/DODATKOWE_MECHANIKI.md, tipy do
		## sequela: "ukryte, nielegalne lokalne uprawy... mechanika konfiskaty")
		## — niezależna od reszty, sprawdzana tylko, gdy plantacja faktycznie
		## MA coś w magazynie do skonfiskowania (patrz _apply_contraband_confiscation).
		if not lost:
			_apply_contraband_confiscation(plantation, weeks)

		if lost:
			plantations.remove_at(i)
		else:
			i += 1


## Jedno "uderzenie" kryzysu (strajk albo zamieszki, patrz apply_player_days_elapsed
## wyżej) — zabiera WSZYSTKIE zebrane zapasy tej plantacji i połowę aktualnej
## załogi (CRISIS_WORKER_LOSS_RATIO), zgłasza zdarzenie do WorldEvents
## (pokazywane jako karta gazety w Hubie, patrz WorldEvents.gd) i zwraca
## true, jeśli licznik uderzeń (crisis_hits) właśnie osiągnął próg utraty
## CAŁEJ plantacji — wywołujący usuwa wtedy REKORD gracza z `plantations`,
## a tu ZWALNIAMY jego pola we wspólnej siatce miasta (_release_player_tiles),
## żeby ktoś inny mógł je zająć od nowa.
func _apply_crisis_hit(plantation: Dictionary, cause: String) -> bool:
	plantation["crisis_hits"] = int(plantation.get("crisis_hits", 0)) + 1

	var stored: Dictionary = plantation["stored_goods"]
	var had_crops := false
	for crop in stored.keys().duplicate():
		if int(stored[crop]) > 0:
			had_crops = true
		stored[crop] = 0

	## Surowość skutków skaluje się TYM SAMYM mnożnikiem co szansa wystąpienia
	## (Difficulty.risk_multiplier) — zgłoszone przez użytkownika jako część
	## jednego pakietu "mniej losowych rzeczy" na łatwiejszych poziomach, nie
	## tylko rzadszych, ale i łagodniejszych. Na VERY_HARD (mnożnik 1.0) obie
	## stałe niżej wracają do dokładnie dzisiejszych wartości.
	var workers_before: int = int(plantation["workers"])
	var effective_loss_ratio: float = CRISIS_WORKER_LOSS_RATIO * Difficulty.risk_multiplier()
	var workers_lost: int = int(workers_before * effective_loss_ratio)
	plantation["workers"] = workers_before - workers_lost

	## Odwrotna zależność niż wyżej: im NIŻSZY mnożnik ryzyka, tym WIĘCEJ
	## uderzeń potrzeba, żeby stracić całą plantację (bardziej wybaczające
	## niższe poziomy trudności) — stąd dzielenie, nie mnożenie. Mnożnik 0.0
	## (VERY_EASY) nigdy realnie tu nie trafia: przy nim żadne wywołanie tej
	## funkcji się nie zdarza (obie szanse wyżej są wtedy dokładnie zerowe),
	## ale @warning_ignore + max() zabezpieczają przed dzieleniem przez zero,
	## gdyby kiedyś ta funkcja została wywołana spoza normalnej ścieżki (np.
	## z testu) przy tym poziomie.
	var effective_hits_to_lose: int = ceili(CRISIS_HITS_TO_LOSE_PLANTATION / maxf(Difficulty.risk_multiplier(), 0.01))
	var plantation_lost: bool = int(plantation["crisis_hits"]) >= effective_hits_to_lose
	if plantation_lost:
		_release_player_tiles(plantation["city"], Players.active_index)
	WorldEvents.report_plantation_crisis(cause, plantation["city"], workers_lost, had_crops, plantation_lost)
	return plantation_lost


## Zwalnia WSZYSTKIE pola danego gracza we wspólnej siatce miasta z powrotem
## do puli "wolne" (-1) i czyści ich uprawę — wywoływane, gdy gracz traci
## całą plantację (patrz _apply_crisis_hit wyżej).
func _release_player_tiles(city_id: String, player_index: int) -> void:
	var grid: Dictionary = city_grids[city_id]
	var tile_owner: Array = grid["tile_owner"]
	var tile_crops: Array = grid["tile_crops"]
	for i in tile_owner.size():
		if tile_owner[i] == player_index:
			tile_owner[i] = -1
			tile_crops[i] = ""


## Indeks plantacji gracza w danym mieście, albo -1, jeśli gracz nie ma tam
## (jeszcze) plantacji — patrz Hub.gd (podsumowanie po "Koniec tury") i
## Plantation.gd, obie potrzebują tego samego wyszukiwania po city_id.
func find_plantation_index(city_id: String) -> int:
	for i in plantations.size():
		if plantations[i]["city"] == city_id:
			return i
	return -1


## Zaczyna śledzić WŁASNĄ obecność gracza w mieście (robotnicy/zapasy/
## kryzysy) — teren (rzeka + własność pól) już istnieje we wspólnym
## city_grids od reset_new_game(), więc tu NIE generujemy żadnej siatki.
func found_plantation(city_id: String) -> int:
	plantations.append({
		"city": city_id,
		"workers": 0,
		"stored_goods": {},  ## uprawa -> ilość w magazynie (osobno per uprawa)
		"stored_since": {},  ## uprawa -> dzień, od którego leży bieżący zapas — patrz _apply_spoilage
		"last_harvest_day": Players.active_day(),
		"crisis_hits": 0,  ## ile razy strajk/zamieszki uderzyły w tę plantację — patrz _apply_crisis_hit
		"worker_days_accum": 0.0,  ## robotniko-dni od ostatnich zbiorów — patrz calculate_harvest/harvest
	})
	return plantations.size() - 1


## Rzeka jako losowy, wijący się pas (a nie prosta kolumna, patrz zrzut
## ekranu oryginału) — "błądzenie losowe" po kolumnach: startuje w losowej
## kolumnie i w każdym kolejnym wierszu przesuwa się o -1/0/+1, przycięte do
## granic siatki, więc zawsze tworzy ciągłą, pionowo płynącą, ale krętą rzekę.
func _generate_river() -> Array[bool]:
	var river: Array[bool] = []
	river.resize(GRID_SIZE * GRID_SIZE)
	river.fill(false)
	var col := randi() % GRID_SIZE
	for row in GRID_SIZE:
		river[row * GRID_SIZE + col] = true
		col = clampi(col + (randi() % 3 - 1), 0, GRID_SIZE - 1)
	return river


## plantation_index odnosi się do rekordu AKTYWNEGO gracza (patrz komentarz
## nagłówkowy pliku) — używany tylko żeby ustalić, o KTÓRE miasto chodzi;
## sama rzeka/własność żyje we wspólnym city_grids[city], nie w tym rekordzie.
func is_river_tile(plantation_index: int, tile_index: int) -> bool:
	var city: String = plantations[plantation_index]["city"]
	return city_grids[city]["river"][tile_index]


## Pole rzeki samo nie jest "sąsiadem rzeki" — bez tego wczesnego wyjścia
## dowolne pole rzeki wypadało jako sąsiadujące z inną, sąsiednią komórką
## tej samej rzeki, co nie ma sensu semantycznie. W realnej rozgrywce i tak
## nieistotne (rzeki nie da się kupić, więc funkcja nigdy nie dostaje
## indeksu pola rzeki jako owned tile), ale wynik dla dowolnego inputu
## powinien być poprawny.
func is_adjacent_to_river(plantation_index: int, tile_index: int) -> bool:
	if is_river_tile(plantation_index, tile_index):
		return false
	var city: String = plantations[plantation_index]["city"]
	var river: Array = city_grids[city]["river"]
	var x := tile_index % GRID_SIZE
	@warning_ignore("integer_division")  ## celowe: y to indeks wiersza w siatce
	var y := tile_index / GRID_SIZE
	for dx: int in [-1, 0, 1]:
		for dy: int in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var nx: int = x + dx
			var ny: int = y + dy
			if nx >= 0 and nx < GRID_SIZE and ny >= 0 and ny < GRID_SIZE and river[ny * GRID_SIZE + nx]:
				return true
	return false


## Zajmuje pole we WSPÓLNEJ siatce miasta na rzecz AKTYWNEGO gracza
## (Players.active_index) — zwraca false, jeśli pole jest rzeką albo już
## należy do KOGOKOLWIEK (siebie samego albo innego gracza — pola są na
## wyłączność, zgłoszone przez użytkownika: "ten który zasieje w lepszym
## miejscu będzie miał lepsze plony"). Cena płaska (TILE_COST), niezależna
## od jakości pola — jedyną przewagą jest to, KTO PIERWSZY je zajmie.
func buy_tile(plantation_index: int, tile_index: int) -> bool:
	var city: String = plantations[plantation_index]["city"]
	var grid: Dictionary = city_grids[city]
	if grid["river"][tile_index] or int(grid["tile_owner"][tile_index]) != -1:
		return false
	if not Economy.spend(TILE_COST):
		return false
	grid["tile_owner"][tile_index] = Players.active_index
	return true


## Sadzi (albo zmienia) uprawę na WŁASNYM, niebędącym rzeką polu — każde pole
## plantacji może mieć inną uprawę, więc jedna plantacja może jednocześnie
## uprawiać wszystkie 4 rodzaje towaru naraz (zgłoszone przez użytkownika).
## Zwraca false, jeśli pole nie jest własnością AKTYWNEGO gracza (ani wolne,
## ani cudze).
func plant_tile(plantation_index: int, tile_index: int, crop: String) -> bool:
	var city: String = plantations[plantation_index]["city"]
	var grid: Dictionary = city_grids[city]
	if int(grid["tile_owner"][tile_index]) != Players.active_index:
		return false
	grid["tile_crops"][tile_index] = crop
	return true


## Ile pól NALEŻĄCYCH DO AKTYWNEGO GRACZA (nie do kogokolwiek innego we
## wspólnej siatce) jest obsianych daną uprawą — patrz legenda w
## Plantation.gd (zgłoszone przez użytkownika).
func get_planted_tile_count(plantation_index: int, crop: String) -> int:
	var city: String = plantations[plantation_index]["city"]
	var grid: Dictionary = city_grids[city]
	var tile_owner: Array = grid["tile_owner"]
	var tile_crops: Array = grid["tile_crops"]
	var count := 0
	for i in tile_crops.size():
		if int(tile_owner[i]) == Players.active_index and tile_crops[i] == crop:
			count += 1
	return count


## Zmienia liczbę robotników. Sam akt zatrudnienia nic nie kosztuje — koszt to
## bieżąca płaca naliczana codziennie (patrz _on_day_advanced).
func hire_workers(plantation_index: int, count: int) -> void:
	plantations[plantation_index]["workers"] = clampi(count, 0, MAX_WORKERS)


## Jednorazowa inwestycja per plantacja (nie per pole) — patrz WATER_PUMP_COST
## wyżej. Zwraca false, jeśli plantacja już ma pompę, albo brak gotówki.
func buy_water_pump(plantation_index: int) -> bool:
	var plantation: Dictionary = plantations[plantation_index]
	if bool(plantation.get("has_water_pump", false)):
		return false
	if not Economy.spend(WATER_PUMP_COST):
		return false
	plantation["has_water_pump"] = true
	return true


func has_water_pump(plantation_index: int) -> bool:
	return bool(plantations[plantation_index].get("has_water_pump", false))


## Ile pól we wspólnej siatce miasta NALEŻY DO AKTYWNEGO GRACZA — pola
## zajęte przez innych graczy się NIE liczą (patrz komentarz nagłówkowy
## pliku: pola są na wyłączność).
func get_owned_tile_count(plantation_index: int) -> int:
	var city: String = plantations[plantation_index]["city"]
	var grid: Dictionary = city_grids[city]
	var count := 0
	for owner_index in grid["tile_owner"]:
		if int(owner_index) == Players.active_index:
			count += 1
	return count


const REFERENCE_PERIOD_DAYS := 30.0  ## REFERENCE_YIELD w Crops.gd to plon za 30 dni

## Plon skalowany rzeczywistym czasem od ostatnich zbiorów (patrz harvest())
## — reference w Crops.gd to plon za REFERENCE_PERIOD_DAYS, więc krótszy/dłuższy
## odstęp od ostatnich zbiorów daje proporcjonalnie mniej/więcej. Plantacja
## może uprawiać kilka różnych roślin naraz (patrz plant_tile), więc plon
## liczy się OSOBNO dla każdej uprawy obecnej na polach, sumując tylko jej
## własne pola (robotnicy/czas/sezon są wspólne dla całej plantacji, ale
## liczba i rodzaj pól — już nie). Liczy WYŁĄCZNIE pola AKTYWNEGO gracza we
## wspólnej siatce miasta — pola innych graczy (choćby i tej samej uprawy)
## się nie wliczają, to właśnie jest sedno rywalizacji o dobre miejsca.
## Zwraca słownik uprawa -> ilość (tylko uprawy z plonem > 0).
func calculate_harvest(plantation_index: int) -> Dictionary:
	var plantation: Dictionary = plantations[plantation_index]
	var city: String = plantation["city"]
	var grid: Dictionary = city_grids[city]
	var days_since_harvest: int = Players.active_day() - int(plantation["last_harvest_day"])
	var result: Dictionary = {}
	if days_since_harvest <= 0:
		return result
	## Plon liczy się ze ŚREDNIEJ załogi w czasie od ostatnich zbiorów (patrz
	## worker_days_accum w apply_player_days_elapsed), NIE z chwilowej liczby
	## robotników w momencie zbioru — bez tego zatrudnienie pełnej załogi tuż
	## przed harvest() i zwolnienie jej zaraz po dawałoby pełny plon
	## praktycznie za darmo (płaca liczy się retroaktywnie tylko za dni,
	## które faktycznie upłynęły z zatrudnioną załogą).
	var average_workers: float = float(plantation.get("worker_days_accum", 0.0)) / days_since_harvest
	var worker_factor: float = average_workers / 500.0
	var seasonal_factor: float = Crops.SEASONAL_YIELD_FACTOR[Calendar.get_month_for_day(Players.active_day())]
	var time_factor: float = days_since_harvest / REFERENCE_PERIOD_DAYS
	## Pompa wodna: +20% plonu CAŁEJ plantacji (WATER_PUMP_YIELD_BONUS) —
	## patrz komentarz przy stałej, "podnosząca plon" z materiału źródłowego.
	var pump_factor: float = WATER_PUMP_YIELD_BONUS if bool(plantation.get("has_water_pump", false)) else 1.0
	var tile_owner: Array = grid["tile_owner"]
	var tile_crops: Array = grid["tile_crops"]
	for crop in Crops.CROPS:
		var normal_tiles := 0
		var river_tiles := 0
		for i in tile_crops.size():
			if int(tile_owner[i]) != Players.active_index or tile_crops[i] != crop:
				continue
			if is_adjacent_to_river(plantation_index, i):
				river_tiles += 1
			else:
				normal_tiles += 1
		if normal_tiles == 0 and river_tiles == 0:
			continue
		var reference: int = Crops.get_reference_yield(city, crop)
		if reference == 0:
			continue
		var effective_tiles: float = normal_tiles + river_tiles * Crops.RIVER_YIELD_MULTIPLIER
		var tile_factor: float = effective_tiles / REFERENCE_TILE_COUNT
		## Difficulty.yield_multiplier(): zgłoszone przez użytkownika — plon ma
		## być wyraźnie wyższy na KAŻDYM poziomie trudności (nawet VERY_HARD
		## dostaje ×1.5 względem dawnego balansu, nie tylko łatwiejsze
		## poziomy), bo dotychczasowy plon "nic nie dawał".
		var amount := int(reference * worker_factor * tile_factor * seasonal_factor * time_factor * pump_factor * Difficulty.yield_multiplier())
		if amount > 0:
			result[crop] = amount
	return result


## Zbiera plon narosły od ostatnich zbiorów (osobno per uprawa, patrz
## calculate_harvest) i resetuje licznik dni — kolejne wywołanie bez upływu
## czasu (Calendar.advance_days) zwróci pusty słownik.
func harvest(plantation_index: int) -> Dictionary:
	var amounts := calculate_harvest(plantation_index)
	var plantation: Dictionary = plantations[plantation_index]
	var stored: Dictionary = plantation["stored_goods"]
	## stored_since (patrz _apply_spoilage) liczy się od pierwszego zbioru
	## do PUSTEGO magazynu tej uprawy — dosypanie kolejnego zbioru do
	## istniejącego zapasu NIE resetuje zegara na nowo (tak jak w realnym
	## magazynie, najstarsza partia i tak psuje się pierwsza; uproszczenie:
	## traktujemy CAŁY zapas jako jedną partię o wieku najstarszej reszty).
	var stored_since: Dictionary = plantation.get("stored_since", {})
	for crop in amounts:
		if int(stored.get(crop, 0)) <= 0:
			stored_since[crop] = Players.active_day()
		stored[crop] = int(stored.get(crop, 0)) + amounts[crop]
	plantation["stored_since"] = stored_since
	plantation["last_harvest_day"] = Players.active_day()
	plantation["worker_days_accum"] = 0.0
	return amounts


## Psuje CAŁY zapas uprawy, która leży w magazynie dłużej niż GOODS_SPOILAGE_DAYS
## — patrz komentarz przy stałej. Zapas bez wpisu w stored_since (zapisy
## sprzed dodania tej mechaniki) domyślnie liczy się jako "dopiero co
## złożony" (Players.active_day()), żeby stare zapisy nie traciły całego
## magazynu od razu przy pierwszym wczytaniu.
func _apply_spoilage(plantation: Dictionary) -> void:
	var stored: Dictionary = plantation["stored_goods"]
	var stored_since: Dictionary = plantation.get("stored_since", {})
	var current_day: int = Players.active_day()
	for crop in stored.keys().duplicate():
		var amount: int = int(stored[crop])
		if amount <= 0:
			continue
		var since: int = int(stored_since.get(crop, current_day))
		if current_day - since > GOODS_SPOILAGE_DAYS:
			stored[crop] = 0
			WorldEvents.report_spoilage(plantation["city"], crop, amount)
	plantation["stored_since"] = stored_since


## Konfiskata przemycanej uprawy — patrz CONTRABAND_CONFISCATION_CHANCE_PER_WEEK.
## W odróżnieniu od _apply_crisis_hit zabiera WYŁĄCZNIE zapas kontrabandy
## (nie robotników, nie inne uprawy, nie całą plantację) — to celowa
## konsekwencja TRZYMANIA nielegalnego towaru, nie ogólny kryzys plantacji.
func _apply_contraband_confiscation(plantation: Dictionary, weeks: float) -> void:
	var stored: Dictionary = plantation["stored_goods"]
	var amount: int = int(stored.get(Crops.CONTRABAND_CROP, 0))
	if amount <= 0:
		return
	if randf() < CONTRABAND_CONFISCATION_CHANCE_PER_WEEK * weeks * Difficulty.risk_multiplier():
		stored[Crops.CONTRABAND_CROP] = 0
		WorldEvents.report_confiscation(plantation["city"], amount)


## Sprzedaje zapas JEDNEJ uprawy z JEDNEJ plantacji po aktualnej cenie
## rynkowej (Crops.get_price) — podbija też odpowiednią linię żeglugową
## (docs/MECHANIKI_EKONOMICZNE.md pkt. 7). Współdzielone przez ship_and_sell
## (cała plantacja, wszystkie uprawy naraz) i ship_and_sell_all (jedna
## uprawa, wszystkie plantacje naraz — patrz Warehouse.gd).
func _ship_and_sell_crop(plantation_index: int, crop: String, warehouse: String) -> int:
	var plantation: Dictionary = plantations[plantation_index]
	var stored: Dictionary = plantation["stored_goods"]
	var amount: int = int(stored.get(crop, 0))
	if amount <= 0:
		return 0
	var transport_cost := Crops.get_transport_cost(warehouse, plantation["city"])
	if transport_cost < 0:
		return 0
	Economy.player_money -= transport_cost * amount
	Economy.earn(amount * Crops.get_price(crop))
	stored[crop] = 0

	var region: String = Cities.CITIES[plantation["city"]]["region"]
	ShippingCompanies.boost_from_region_activity(region, amount * 0.01)
	return amount


## Sprzedaje WSZYSTKIE zapasy JEDNEJ plantacji naraz (wszystkie uprawy,
## które akurat ma w magazynie) — przycisk "Wyślij i sprzedaj" w
## Plantation.gd.
func ship_and_sell(plantation_index: int, warehouse: String) -> int:
	var stored: Dictionary = plantations[plantation_index]["stored_goods"]
	var total := 0
	for crop in stored.keys().duplicate():
		total += _ship_and_sell_crop(plantation_index, crop, warehouse)
	return total


## Jak ship_and_sell, ale dla JEDNEJ uprawy ze WSZYSTKICH plantacji naraz
## (patrz Spichlerz/Warehouse.gd — pokazuje zsumowany zapas danej uprawy ze
## wszystkich plantacji, więc sprzedaż też musi obsłużyć wszystkie na raz,
## każdą z jej WŁASNYM kosztem transportu, bo ten zależy od miasta danej
## plantacji).
func ship_and_sell_all(crop: String, warehouse: String) -> int:
	var total := 0
	for i in plantations.size():
		total += _ship_and_sell_crop(i, crop, warehouse)
	return total


## Suma zebranego towaru danej uprawy w magazynach wszystkich plantacji gracza
## (uproszczenie: "magazyn" = suma stored_goods plantacji, które akurat mają
## zapas tej uprawy — bez modelowania osobnych magazynów w Nowym Jorku/Londynie).
func get_total_stored(crop: String) -> int:
	var total := 0
	for plantation in plantations:
		total += int(plantation["stored_goods"].get(crop, 0))
	return total


## Zużywa zebrany towar (np. na poczet kontraktu terminowego) z plantacji,
## które mają zapas danej uprawy, w kolejności iteracji.
func consume_stored(crop: String, amount: int) -> void:
	var remaining := amount
	for plantation in plantations:
		if remaining <= 0:
			break
		var stored: Dictionary = plantation["stored_goods"]
		var available: int = int(stored.get(crop, 0))
		if available <= 0:
			continue
		var take: int = min(remaining, available)
		stored[crop] = available - take
		remaining -= take
