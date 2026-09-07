extends Node
## Harmonogram aukcji — w oryginale gry aukcja odbywa się w JEDNYM konkretnym
## mieście w JEDNYM konkretnym dniu (patrz zrzut ekranu użytkownika: skrzynka
## "NEXT AUCTION IS: 17.1.1918 BERLIN"), a nie na żądanie gracza w dowolnej
## chwili — wcześniej przycisk "Nowa aukcja" w AuctionHouse.gd pozwalał kupować
## obrazy bez ograniczeń, co użytkownik zgłosił jako niezgodne z oryginałem.
## Ten autoload trzyma harmonogram; AuctionHouse.gd tylko go odczytuje.
## Patrz docs/MECHANIKI_EKONOMICZNE.md pkt. 9.

const MIN_DAYS_AHEAD := 4
const MAX_DAYS_AHEAD := 12

## Sentinel "jeszcze nie wylosowano" dla current_painting_number niżej —
## NIE -1: odkąd doszły 3 bonusowe "obrazy wuja" (docs/DODATKOWE_MECHANIKI.md),
## numery -1/-2/-3 to PRAWDZIWE, poprawne numery katalogowe (Paintings.BONUS_CATALOG),
## więc -1 jako sentinel kolidowałby z pierwszym bonusowym obrazem. Wartość
## daleko poza jakimkolwiek realnym zakresem numerów (1..40 zwykłych, -1..-3
## bonusowych).
const NO_PAINTING_SELECTED := -1000
## Zgłoszenie użytkownika: 3 bonusowe "ulubione obrazy wuja" (docs/DODATKOWE_MECHANIKI.md)
## mają szansę pojawić się na aukcji ZAMIAST zwykłego obrazu z katalogu —
## tylko dopóki jest jeszcze jakiś nierozdany (patrz Paintings.get_available_bonus_numbers).
const BONUS_PAINTING_CHANCE := 0.05

## Ile dni po terminie aukcja jeszcze "czeka" (gdyby gracz akurat dojeżdżał),
## zanim uznajemy ją za przegapioną i losujemy nowy termin automatycznie —
## bez tego, jeśli gracz po prostu stał w miejscu i nie odwiedził miasta
## aukcji, wyświetlana data następnej aukcji zostawała na zawsze w przeszłości
## (zgłoszone przez testera: "aktualną datę mam np. 27 stycznia, a poniżej
## informacja, że następna aukcja to 20 stycznia").
const MISSED_GRACE_DAYS := 3

var next_auction_city: String = ""
var next_auction_day: int = 0

## Obraz wystawiony na sprzedaż w bieżącym/najbliższym terminie — losowany
## dopiero przy pierwszym wejściu do otwartej aukcji (get_current_painting_number),
## nie z góry, ale ten sam numer zostaje przy kolejnych wejściach do tego
## samego terminu (np. gracz wraca do Hub w trakcie licytacji i wchodzi
## ponownie) — dopóki resolve_and_reschedule() go nie wyzeruje.
var current_painting_number: int = NO_PAINTING_SELECTED

## number (1..Paintings.CATALOG.size()) -> ile razy dany numer już padł na
## aukcji w tej rozgrywce — patrz get_current_painting_number/_pick_weighted_painting_number.
## Numery bonusowe (ujemne, Paintings.BONUS_CATALOG) NIE są tu śledzone —
## mają osobny, rzadki mechanizm (BONUS_PAINTING_CHANCE) i pulę bez powtórek
## (Paintings.get_available_bonus_numbers), więc nie potrzebują ważenia.
var painting_draw_count: Dictionary = {}


func _ready() -> void:
	Calendar.day_advanced.connect(_on_day_advanced)


func reset_new_game() -> void:
	current_painting_number = NO_PAINTING_SELECTED
	painting_draw_count.clear()
	_pick_new_schedule(0)


func _on_day_advanced(_days_elapsed: int, current_day: int) -> void:
	if next_auction_city != "" and current_day > next_auction_day + MISSED_GRACE_DAYS:
		current_painting_number = NO_PAINTING_SELECTED
		_pick_new_schedule(current_day)


func _pick_new_schedule(from_day: int) -> void:
	var auction_cities := Cities.get_auction_cities()
	next_auction_city = auction_cities[randi() % auction_cities.size()]
	next_auction_day = from_day + MIN_DAYS_AHEAD + randi() % (MAX_DAYS_AHEAD - MIN_DAYS_AHEAD + 1)


## Czy w podanym mieście trwa właśnie zaplanowana aukcja — termin nadszedł
## (albo minął, jeśli gracz spóźnił się i akurat tam jest) i jeszcze nie
## został rozstrzygnięty. Sprawdzane wg WŁASNEGO dnia aktywnego gracza (Tor
## B) — zawsze wywoływane w kontekście aktywnego gracza (patrz AuctionHouse.gd).
func is_open(city_id: String) -> bool:
	return city_id == next_auction_city and Players.active_day() >= next_auction_day


## Indeksy WSZYSTKICH graczy fizycznie obecnych na TEJ aukcji (nie tylko
## aktywnego) — własne miasto ORAZ własny dzień (Tor B, patrz Players.gd)
## muszą się zgadzać z zaplanowanym terminem. Kilku graczy może dotrzeć do
## tej samej aukcji niezależnym tempem (patrz GDD.md pkt. 11) — AuctionHouse.gd
## pokazuje dla każdego z nich osobną ramkę do licytacji.
func get_present_players() -> Array[int]:
	var result: Array[int] = []
	for i in Players.player_count:
		if Players.get_player_city(i) == next_auction_city and Players.get_player_day(i) >= next_auction_day:
			result.append(i)
	return result


func get_current_painting_number() -> int:
	if current_painting_number == NO_PAINTING_SELECTED:
		var available_bonus := Paintings.get_available_bonus_numbers()
		if not available_bonus.is_empty() and randf() < BONUS_PAINTING_CHANCE:
			current_painting_number = available_bonus[randi() % available_bonus.size()]
		else:
			current_painting_number = _pick_weighted_painting_number()
			painting_draw_count[current_painting_number] = int(painting_draw_count.get(current_painting_number, 0)) + 1
	return current_painting_number


## Losowanie numeru z katalogu (1..Paintings.CATALOG.size()), ważone
## odwrotnie proporcjonalnie do tego, ile razy dany numer już padł w tej
## rozgrywce (painting_draw_count) — im rzadziej dotąd padał, tym większa
## szansa. Bez tego jednostajny rozkład sprawiał, że "ostatni" brakujący
## obraz w kolekcji potrafił nie pojawić się przez lata gry mimo dziesiątek
## aukcji w tym czasie. Nadal CAŁKOWICIE losowe (nie gwarantowane) i nadal
## mogą paść numery, które gracz już ma — to konieczne dla mechaniki
## podróbek (Paintings.is_forgery_by_duplicate), tylko z mniejszą wagą, gdy
## dany numer padał już wielokrotnie.
func _pick_weighted_painting_number() -> int:
	var weights: Array[float] = []
	var total_weight := 0.0
	for i in Paintings.CATALOG.size():
		var w: float = 1.0 / (float(painting_draw_count.get(i + 1, 0)) + 1.0)
		weights.append(w)
		total_weight += w
	var roll := randf() * total_weight
	var cumulative := 0.0
	for i in weights.size():
		cumulative += weights[i]
		if roll < cumulative:
			return i + 1
	return Paintings.CATALOG.size()  ## fallback na zaokrąglenie float, praktycznie nieosiągalne


## Zamyka bieżący termin (ktoś wygrał albo nikt nie licytował) i losuje
## kolejny — inne miasto, dzień w przyszłości — żeby ten sam termin nie dało
## się rozstrzygać w nieskończoność.
func resolve_and_reschedule() -> void:
	current_painting_number = NO_PAINTING_SELECTED
	_pick_new_schedule(Calendar.current_day)


func get_schedule_string() -> String:
	return tr("Następna aukcja: %s — %s") % [
		Calendar.format_day(next_auction_day), Cities.get_city_name(next_auction_city),
	]


## Skraca planowany skok dni "Końca tury" (Players.DAYS_PER_TURN = 7 dni na
## raz), jeśli gracz stoi w mieście, gdzie ma się odbyć następna aukcja, a
## normalny skok przeleciałby od razu przez cały ten termin bez zatrzymania —
## użytkownik zgłosił, że stojąc w takim mieście i klikając "Koniec tury",
## nigdy nie trafiał dokładnie na dzień aukcji, żeby zdążyć wejść i
## zalicytować. Zwraca requested_days bez zmian, jeśli gracz jest gdzie
## indziej albo termin już minął (nic nie ma co ciąć).
func cap_turn_advance(requested_days: int, city_id: String) -> int:
	if city_id != next_auction_city or Players.active_day() >= next_auction_day:
		return requested_days
	var days_to_auction := next_auction_day - Players.active_day()
	return mini(requested_days, days_to_auction)
