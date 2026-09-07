extends Control
## Mapa świata z klikalnymi pinezkami — osobny ekran, wywoływany z Hubu
## przyciskiem "Jedź »" (patrz GDD.md pkt. 4.9). Wybór celu podróży = tap na
## pinezkę, potem animacja podróży (scenes/travel_animation). UI (tytuł,
## info o podróży, przyciski) w pasku przyklejonym do PRAWEGO DOLNEGO rogu
## (make_root_bottom, ta sama ozdobna ramka co w Hub.gd) — pełnowysokościowy
## pasek z prawej krawędzi (dawne make_root_side) zasłaniał pinezki
## rozrzucone po całej mapie, w tym te blisko prawej krawędzi.
##
## Zgłoszenie użytkownika: samą mapę (tło + pinezki) da się przybliżać
## (uszczypnięcie na dotyku/kółko myszy) i przesuwać (przeciąganie), a
## pinezki przy tym trochę się powiększają (nie 1:1 z zoomem mapy — patrz
## PIN_ZOOM_DAMPING) i ZOSTAJĄ na dokładnie tych samych, skalibrowanych
## miejscach. Architektura: map_content (tło + warstwa pinezek) dostaje
## `scale`/`position` sterowane przez _apply_zoom/_apply_pan zamiast
## anchorów świata-do-ekranu — to WEWNĄTRZ map_content pinezki nadal są
## anchor-owane fakturą (frac.x/frac.y) tak jak wcześniej, więc automatycznie
## poruszają się/skalują RAZEM z tłem (są jego potomkiem), niezależnie od
## aktualnego zoomu/panu. Każda pinezka dostaje DODATKOWO WŁASNE `scale`,
## które DZIELI docelowy (stonowany) rozmiar przez bieżący zoom mapy — to
## KASUJE odziedziczoną skalę rodzica i zastępuje ją stonowaną, więc pinezki
## rosną WOLNIEJ niż sama mapa (patrz _update_pin_scale). `pivot_offset`
## każdej pinezki ustawiony na jej koniuszek (ten sam punkt, który wcześniej
## dostawał offset_bottom=0 — patrz komentarz w _build_pins) — skalowanie
## wokół koniuszka, nie środka pinezki, jest KONIECZNE, żeby koniuszek został
## dokładnie na skalibrowanym miejscu niezależnie od tego, jak bardzo pinezka
## akurat urosła.

const TYPE_PIN_COLORS := {
	"plantation": Color(0.85, 0.65, 0.2),
	"auction": Color(0.55, 0.1, 0.15),
	"hub": Color(0.1, 0.55, 0.55),
}
const CURRENT_CITY_PIN_COLOR := Color(1.0, 1.0, 1.0)

const MapPinScript := preload("res://scripts/ui/MapPin.gd")

const MIN_ZOOM := 1.0
const MAX_ZOOM := 2.5
## Pinezki rosną WOLNIEJ niż mapa — przy MAX_ZOOM mapa jest 2.5× większa, ale
## pinezki tylko ok. 1.5× (1.0 + 1.5*0.35 ≈ 1.53) — zgłoszenie użytkownika:
## "trochę powiększały się pinezki", nie tyle samo co mapa (co przy dużym
## zoomie zamieniłoby je w nieczytelne plamy).
const PIN_ZOOM_DAMPING := 0.35
## Dodatkowe powiększenie zaznaczonej (klikniętej) pinezki, NAD zwykłym
## zoom-owym skalowaniem z PIN_ZOOM_DAMPING — zgłoszenie użytkownika:
## kliknięcie pinezki ma ją wyraźnie powiększyć/podświetlić, a poprzednio
## zaznaczona ma wrócić do normalnego rozmiaru. Mnożone RAZEM z `compensated`
## w _update_pin_scale, nie zastępuje go — więc zaznaczona pinezka rośnie
## proporcjonalnie tak samo przy zoomie mapy jak każda inna, tylko zawsze
## dodatkowo 1.4× większa.
const SELECTED_PIN_SCALE_BOOST := 1.4
const WHEEL_ZOOM_STEP := 0.15  ## na jedno kliknięcie kółka myszy (test/desktop)
## Zgłoszenie użytkownika: kliknięcie "Jedź »" w trakcie przybliżenia
## przeskakiwało od razu na "standardową mapę" (czyli na nowo załadowaną
## scenę TravelAnimation, zawsze w zoomie 1.0) — wyglądało jak nagłe
## szarpnięcie. Zamiast tego mapa NAJPIERW płynnie oddala się z powrotem do
## normalnego rozmiaru (patrz _on_confirm_pressed), DOPIERO PO tej animacji
## rusza scena przelotu/przejazdu.
const ZOOM_RESET_DURATION := 0.35

var info_label: Label
var confirm_button: Button
var cancel_button: Button
var selected_city: String = ""

var map_viewport: Control
var map_content: Control
var pins: Array[Button] = []
var pin_by_city: Dictionary = {}  ## city_id -> pinezka, patrz _update_pin_selection_visuals
var zoom: float = MIN_ZOOM

## Uszczypnięcie DWOMA PALCAMI na telefonie NIE przychodzi jako
## InputEventMagnifyGesture (to gest trackpada na desktopie/macOS) —
## zgłoszony przez użytkownika bug: "2 palcami nie mogę powiększyć na
## telefonie". Godot na dotyku daje surowe InputEventScreenTouch/
## InputEventScreenDrag PER PALEC (z `index`), więc uszczypnięcie trzeba
## wykryć samemu: śledzimy pozycję każdego aktualnie dotykającego palca
## (touch_points, index -> pozycja) i przy DWÓCH naraz liczymy zmianę
## odległości między nimi względem odległości na POCZĄTKU tego uszczypnięcia
## (pinch_start_distance/pinch_start_zoom) — porównanie do POCZĄTKU gestu
## (nie klatka-do-klatki) jest stabilniejsze, nie dryfuje przy drobnych
## drżeniach palców.
var touch_points: Dictionary = {}
var pinch_start_distance: float = 0.0
var pinch_start_zoom: float = MIN_ZOOM


func _ready() -> void:
	Music.play_track(Music.HUB_TRACK)  ## ten sam nastrój co Hub.gd — patrz docs/MUZYKA_PROMPTY.md
	_build_map(Cities.MAP_BACKGROUND_PATH)
	_build_pins()
	ScreenHelpers.make_instructions_button(self)

	var root := ScreenHelpers.make_root_bottom(self, true)
	ScreenHelpers.make_title(root, "Dokąd jedziemy?")
	info_label = ScreenHelpers.make_label(root, _default_info_text())
	## autowrap + szerokość ograniczona do wnętrza paska (420 szerokości
	## całego panelu - 2×26 marginesu ramki, patrz make_root_bottom) — bez
	## tego długi tekst (np. "Podróż do Rio de Janeiro: 5.3 dnia
	## (samolotem)") był szerszy niż panel i rozpychał go ponad zamierzone
	## 420px, niespójnie zależnie od nazwy miasta (przegląd czytelności/
	## dopasowania do rozdzielczości na żądanie użytkownika).
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	info_label.custom_minimum_size = Vector2(360, 0)
	confirm_button = ScreenHelpers.make_button(root, "Jedź »", _on_confirm_pressed)
	cancel_button = ScreenHelpers.make_button(root, "Anuluj", _on_cancel_pressed)
	confirm_button.visible = false
	cancel_button.visible = false
	ScreenHelpers.make_button(root, "« Powrót", func(): SceneRouter.goto_hub())


func _default_info_text() -> String:
	return tr("Jesteś w: %s — dotknij pinezkę celu podróży") % Cities.get_city_name(Travel.current_city)


## map_viewport: pełnoekranowy, NIERUCHOMY kontener, wycina (clip_contents)
## wszystko, co przy zoomie/panie wystaje poza ekran. Gesty (uszczypnięcie/
## przeciągnięcie/kółko myszy) obsługuje _input() na CAŁYM ekranie (patrz
## komentarz przy touch_points wyżej), NIE gui_input tego węzła — surowy
## dotyk wielopalcowy nie dociera do _gui_input (to kanał myszy/GUI), tylko
## do zwykłego _input().
## map_content: to, co faktycznie się skaluje/przesuwa (`scale`/`position`) —
## tło + warstwa pinezek jako jego dzieci, więc poruszają się/skalują RAZEM.
func _build_map(background_path: String) -> void:
	map_viewport = Control.new()
	map_viewport.set_anchors_preset(Control.PRESET_FULL_RECT)
	map_viewport.clip_contents = true
	map_viewport.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(map_viewport)

	map_content = Control.new()
	map_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	map_content.mouse_filter = Control.MOUSE_FILTER_PASS
	map_viewport.add_child(map_content)

	var bg := TextureRect.new()
	bg.texture = load(background_path)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_content.add_child(bg)

	## Zgłoszony bug: "skacze jasność przy mapie" — ten ekran budował tło
	## RĘCZNIE (zamiast przez ScreenHelpers.make_background, żeby dać mu
	## rodzica map_content zamiast `self`), więc po drodze zgubił ciemniącą
	## nakładkę (alpha 0.45), którą make_background zawsze dokłada. Bez niej
	## ta mapa była JAŚNIEJSZA niż podgląd mapy w Hub.gd (który TĘ nakładkę
	## ma) — stąd widoczny skok jasności przy przełączeniu scen. Dziecko
	## map_content, więc przyciemnia dokładnie widoczny (zoomowany/przesunięty)
	## fragment mapy, nie cały ekran.
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.45)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_content.add_child(overlay)


## Pinezki NIE dostają jednorazowo wyliczonej pozycji w pikselach (`position =
## frac * get_viewport_rect().size`, tak było wcześniej) — to liczy się raz,
## w momencie budowania ekranu, i później się nie przelicza, więc przy każdej
## zmianie rozdzielczości/proporcji okna (albo jeśli w momencie _ready()
## viewport jeszcze nie miał ostatecznego rozmiaru z "stretch/aspect=expand")
## pinezki zostają w miejscu wyliczonym dla STAREGO rozmiaru, a tło (które
## skaluje się przez anchory) już nie — stąd pinezki "uciekają" z właściwych
## miejsc. Zamiast tego każda pinezka dostaje anchor_left=anchor_right=frac.x,
## anchor_top=anchor_bottom=frac.y (jeden punkt zakotwiczenia) + stały,
## pikselowy offset na wielkość PIN_SIZE — layout Godota sam przelicza tę
## pozycję na nowo przy KAŻDEJ zmianie rozmiaru rodzica (map_content), tak
## samo jak robi to tło, więc oba zawsze poruszają się razem, niezależnie od
## rozdzielczości, momentu przeliczenia CZY aktualnego zoomu/panu mapy.
func _build_pins() -> void:
	var pins_layer := Control.new()
	pins_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	pins_layer.mouse_filter = Control.MOUSE_FILTER_PASS
	map_content.add_child(pins_layer)

	pins.clear()
	pin_by_city.clear()
	for city_id in Cities.CITIES.keys():
		var pin: Button = MapPinScript.new()
		var city_type: String = Cities.CITIES[city_id]["type"]
		pin.pin_color = CURRENT_CITY_PIN_COLOR if city_id == Travel.current_city else TYPE_PIN_COLORS.get(city_type, Color.GRAY)
		var frac: Vector2 = Cities.get_map_position(city_id)
		pin.anchor_left = frac.x
		pin.anchor_right = frac.x
		pin.anchor_top = frac.y
		pin.anchor_bottom = frac.y
		## Zgłoszone przez użytkownika: skalibrowany punkt (frac) ma pokrywać się
		## z KONIUSZKIEM pinezki (ostry czubek na dole grafiki, patrz MapPin.gd
		## _draw — tip = Vector2(w*0.5, size.y)), nie ze środkiem całego
		## prostokąta. W poziomie pinezka zostaje wyśrodkowana (czubek leży na
		## środku szerokości), w pionie offset_bottom=0 przypina sam dół
		## (czubek) dokładnie do punktu zakotwiczenia, a offset_top=-PIN_SIZE.y
		## rozciąga resztę grafiki W GÓRĘ od tego punktu.
		pin.offset_left = -MapPinScript.PIN_SIZE.x / 2.0
		pin.offset_right = MapPinScript.PIN_SIZE.x / 2.0
		pin.offset_top = -MapPinScript.PIN_SIZE.y
		pin.offset_bottom = 0.0
		## pivot_offset = koniuszek — pinezka rośnie/maleje (patrz
		## _update_pin_scale) WOKÓŁ tego punktu, więc koniuszek zostaje
		## dokładnie na skalibrowanym miejscu niezależnie od aktualnej skali.
		pin.pivot_offset = Vector2(MapPinScript.PIN_SIZE.x * 0.5, MapPinScript.PIN_SIZE.y)
		pin.tooltip_text = Cities.get_city_name(city_id)
		pin.pressed.connect(_on_pin_selected.bind(city_id))
		pins_layer.add_child(pin)
		pins.append(pin)
		pin_by_city[city_id] = pin


## _input(), NIE _gui_input/gui_input — surowy wielopalcowy dotyk
## (InputEventScreenTouch/InputEventScreenDrag, z `index` per palec) nie
## dociera do kanału GUI (_gui_input odbiera właściwie tylko zdarzenia
## myszy/GUI), tylko do zwykłego _input(), patrz komentarz przy touch_points.
## Obsługuje: uszczypnięcie dwoma palcami (ręcznie liczone z touch_points),
## gest uszczypnięcia trackpada (InputEventMagnifyGesture, macOS/desktop),
## przeciąganie dwoma palcami trackpada (InputEventPanGesture), kółko myszy
## (zoom, desktop/test) i przeciąganie myszą (pan, desktop — TYLKO gdy żaden
## prawdziwy dotyk nie jest aktywny, patrz niżej). Zoom zawsze wokół pozycji
## gestu/kursora/środka między palcami (_apply_zoom), więc mapa "przybliża
## się w to miejsce, gdzie uszczypnięto", nie zawsze do środka ekranu.
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			touch_points[event.index] = event.position
		else:
			touch_points.erase(event.index)
			pinch_start_distance = 0.0
	elif event is InputEventScreenDrag:
		touch_points[event.index] = event.position
		if touch_points.size() >= 2:
			_handle_pinch()
		else:
			_apply_pan(event.relative)
	elif event is InputEventMagnifyGesture:
		_apply_zoom(zoom * event.factor, event.position)
	elif event is InputEventPanGesture:
		_apply_pan(-event.delta)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
		_apply_zoom(zoom + WHEEL_ZOOM_STEP, event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_apply_zoom(zoom - WHEEL_ZOOM_STEP, event.position)
	elif event is InputEventMouseMotion and touch_points.is_empty() and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		## touch_points.is_empty() — na dotyku Godot ZWYKLE emuluje z każdego
		## palca też mysz (osobne InputEventMouseMotion), więc bez tego
		## warunku przeciąganie jednym palcem przesuwałoby mapę PODWÓJNIE
		## (raz jako ScreenDrag wyżej, raz jako emulowana mysz tutaj). Na
		## prawdziwym desktopie (bez dotyku) touch_points jest zawsze puste,
		## więc przeciąganie myszą działa bez zmian.
		_apply_pan(event.relative)


## Odległość między dwoma aktualnie dotykającymi palcami i punkt w połowie
## drogi między nimi (środek uszczypnięcia — ognisko zoomu).
func _touch_distance() -> float:
	var positions: Array = touch_points.values()
	return positions[0].distance_to(positions[1])


func _touch_midpoint() -> Vector2:
	var positions: Array = touch_points.values()
	return (positions[0] + positions[1]) * 0.5


## Nowe uszczypnięcie (dopiero co dotknęły DWA palce, albo trzeci nadepnął
## po dwóch pierwszych) zapamiętuje odległość/zoom startowy; każda kolejna
## klatka przelicza zoom jako pinch_start_zoom * (bieżąca odległość / odległość
## startowa) — porównanie do POCZĄTKU gestu (nie klatka-do-klatki) jest
## stabilniejsze, patrz komentarz przy touch_points.
func _handle_pinch() -> void:
	var distance := _touch_distance()
	if pinch_start_distance <= 0.0:
		pinch_start_distance = distance
		pinch_start_zoom = zoom
		return
	_apply_zoom(pinch_start_zoom * (distance / pinch_start_distance), _touch_midpoint())


## Zmienia zoom, zachowując POD KURSOREM/PALCEM (`focal`, we współrzędnych
## map_viewport) ten sam punkt mapy co przed zmianą — standardowa transformata
## "zoom do punktu": najpierw liczymy, na jaki punkt WEWNĄTRZ map_content
## (sprzed zmiany skali) wskazuje `focal`, potem dobieramy nową pozycję tak,
## żeby DOKŁADNIE ten sam punkt mapy znów wypadł pod `focal` po zmianie skali.
func _apply_zoom(new_zoom: float, focal: Vector2) -> void:
	new_zoom = clampf(new_zoom, MIN_ZOOM, MAX_ZOOM)
	if is_equal_approx(new_zoom, zoom):
		return
	var local_point := (focal - map_content.position) / zoom
	zoom = new_zoom
	map_content.position = focal - local_point * zoom
	map_content.scale = Vector2(zoom, zoom)
	_clamp_pan()
	_update_pin_scale()


func _apply_pan(delta: Vector2) -> void:
	if zoom <= MIN_ZOOM:
		return  ## bez sensu przesuwać, gdy mapa i tak dokładnie wypełnia ekran
	map_content.position += delta
	_clamp_pan()


## Nie pozwala odsłonić pustego marginesu poza teksturą tła — powiększona
## treść (rozmiar = rozmiar viewportu * zoom) zawsze musi w pełni pokrywać
## map_viewport, więc pozycja jest zaciśnięta do przedziału [viewport - treść, 0]
## w obu osiach (przy zoom=1.0 oba krańce wynoszą 0, więc pozycja zawsze
## wraca dokładnie do (0,0) — panowanie bez przybliżenia nie ma efektu, patrz
## _apply_pan wyżej).
func _clamp_pan() -> void:
	var viewport_size := map_viewport.size
	var content_size := viewport_size * zoom
	var min_pos := viewport_size - content_size
	map_content.position.x = clampf(map_content.position.x, min_pos.x, 0.0)
	map_content.position.y = clampf(map_content.position.y, min_pos.y, 0.0)


## Każda pinezka dostaje WŁASNE `scale`, które DZIELI stonowany docelowy
## rozmiar przez bieżący zoom mapy — pinezka jest potomkiem map_content, więc
## automatycznie ODZIEDZICZA jego skalę (zoom); dzielenie przez `zoom` znosi
## tę odziedziczoną skalę i zastępuje ją stonowaną, więc finalny, widoczny
## rozmiar pinezki na ekranie to DOKŁADNIE `target_scale`, niezależnie od
## aktualnego zoomu mapy.
func _update_pin_scale() -> void:
	var target_scale := 1.0 + (zoom - MIN_ZOOM) * PIN_ZOOM_DAMPING
	var compensated := target_scale / zoom
	var selected_pin: Button = pin_by_city.get(selected_city)
	for pin in pins:
		var boost := SELECTED_PIN_SCALE_BOOST if pin == selected_pin else 1.0
		pin.scale = Vector2(compensated * boost, compensated * boost)


## Podświetla (jaśniejszy kolor + złota obwódka, patrz MapPin.set_selected) i
## powiększa (patrz _update_pin_scale) pinezkę odpowiadającą selected_city,
## a poprzednio zaznaczoną wraca do zwykłego wyglądu — zgłoszenie
## użytkownika: kliknięcie innej pinezki ma cofnąć poprzednią do pierwotnej
## formy, nie zostawiać dwóch podświetlonych naraz.
func _update_pin_selection_visuals() -> void:
	for city_id in pin_by_city:
		var pin: Button = pin_by_city[city_id]
		pin.set_selected(city_id == selected_city)
	_update_pin_scale()


## Kliknięcie pinezki tylko zaznacza cel i pokazuje czas podróży — nie
## rusza od razu (wcześniej robiło, co myliło graczy: "kliknę i już jadę").
## Rozpoczęcie podróży wymaga potwierdzenia przyciskiem "Jedź »".
func _on_pin_selected(city_id: String) -> void:
	if city_id == Travel.current_city:
		return
	var preview := Travel.preview_travel(city_id)
	if preview.is_empty():
		return
	selected_city = city_id
	_update_pin_selection_visuals()
	var vehicle_name := tr("pociągiem") if preview["vehicle"] == Travel.Vehicle.TRAIN else tr("samolotem")
	var text := tr("Podróż do %s: %.1f dnia (%s)") % [Cities.get_city_name(city_id), preview["days"], vehicle_name]
	var wage_warning := _worker_wage_warning()
	if wage_warning != "":
		text += "\n" + wage_warning
	info_label.text = text
	confirm_button.visible = true
	cancel_button.visible = true


## Ostrzeżenie o dniówkach, które nadal będą naliczane pod nieobecność gracza
## (patrz PlayerPlantations.apply_player_days_elapsed — płaca liczy się
## codziennie, niezależnie od tego, czy gracz jest fizycznie na miejscu).
## Mechanika ZOSTAJE bez zmian (zgłoszone przez użytkownika: "ma być płaca
## tak samo naliczana... jak sie jest i nie jest") — to WYŁĄCZNIE informacja
## o tym, ile to będzie kosztować, żeby gracz mógł świadomie zdecydować, czy
## zwolnić załogę przed wyjazdem. Pusty string, jeśli w mieście, z którego
## gracz wyjeżdża, nie ma jego plantacji albo nie ma tam zatrudnionych
## robotników — nie ma czym straszyć.
func _worker_wage_warning() -> String:
	var idx := PlayerPlantations.find_plantation_index(Travel.current_city)
	if idx == -1:
		return ""
	var workers: int = int(PlayerPlantations.plantations[idx]["workers"])
	if workers <= 0:
		return ""
	var daily_cost := workers * PlayerPlantations.WORKER_DAILY_WAGE
	return tr("Uwaga: %d robotników w %s nadal będzie kosztować %.0f M/dzień, nawet pod Twoją nieobecność.") % [
		workers, Cities.get_city_name(Travel.current_city), daily_cost,
	]


func _on_confirm_pressed() -> void:
	if selected_city == "" or not Travel.start_travel(selected_city):
		return

	## Zabezpieczenie przed drugim kliknięciem w trakcie animacji oddalania
	## (Travel.start_travel już ruszyło podróż — druga próba byłaby błędna).
	confirm_button.disabled = true
	cancel_button.disabled = true

	if zoom <= MIN_ZOOM:
		SceneRouter.goto_scene(SceneRouter.TRAVEL_ANIMATION)
		return

	## Płynny powrót do zoom=1.0 (ognisko na środku ekranu, nie tam, gdzie
	## akurat kliknięto pinezkę) PRZED przejściem do sceny przelotu/przejazdu
	## — patrz komentarz przy ZOOM_RESET_DURATION. _apply_zoom robi całą
	## resztę (klamrowanie pozycji + skalowanie pinezek) na każdej klatce
	## tweena, tak jak przy zwykłym zoomowaniu gestem.
	var focal := map_viewport.size * 0.5
	var tween := create_tween()
	tween.tween_method(func(z: float): _apply_zoom(z, focal), zoom, MIN_ZOOM, ZOOM_RESET_DURATION)
	## goto_scene_crossfade (NIE goto_scene) — zgłoszony bug: "na sam koniec
	## miga i dopiero się pokazuje" — change_scene_to_file samo z siebie daje
	## jedną pustą klatkę w momencie przełączenia, TA SAMA przyczyna, dla
	## której Hub.gd::_on_travel_pressed używa crossfade zamiast zwykłego
	## goto_scene po swoim własnym zoom-oucie.
	tween.tween_callback(func(): SceneRouter.goto_scene_crossfade(SceneRouter.TRAVEL_ANIMATION))


func _on_cancel_pressed() -> void:
	selected_city = ""
	_update_pin_selection_visuals()
	info_label.text = _default_info_text()
	confirm_button.visible = false
	cancel_button.visible = false
