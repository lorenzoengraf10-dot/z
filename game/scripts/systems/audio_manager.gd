extends Node
## Autoload. Reproduce sonidos por nombre y **no rompe si el archivo todavía no
## existe**. La idea es que quien haga el audio solo tenga que copiar los
## archivos a assets/audio/ con el nombre correcto y empiecen a sonar solos,
## sin tocar una línea de código.
##
## Nombres que el juego ya pide (crear los archivos con estos nombres):
##   talar, pescar, golpe, comer, construir, zombie_gruñido, paso
## Música: assets/audio/musica_<nombre>.ogg (ej. musica_ambiente.ogg)

const AUDIO_DIR := "res://assets/audio/"
# Tipado como Array[String] a propósito: si fuera un Array común, `ext` sería
# Variant y el `var path := ...` de abajo no podría inferir su tipo.
const EXTENSIONS: Array[String] = [".ogg", ".wav", ".mp3"]
const VOICES := 8

var _players: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _cache: Dictionary = {}
var _warned: Dictionary = {}


func _ready() -> void:
	# El minijuego de fuego pausa el juego, y queremos que sus sonidos igual
	# suenen: por eso el audio no se pausa nunca.
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in range(VOICES):
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	add_child(_music)


## Reproduce un efecto. Si no hay archivo, no hace nada (avisa una sola vez).
func play(sound_name: String, volume_db: float = 0.0) -> void:
	var stream := _load_stream(sound_name)
	if stream == null:
		return
	var voice := _free_voice()
	if voice == null:
		return
	voice.stream = stream
	voice.volume_db = volume_db
	voice.play()


func play_music(track_name: String, volume_db: float = -8.0) -> void:
	var stream := _load_stream("musica_" + track_name)
	if stream == null:
		return
	if _music.stream == stream and _music.playing:
		return
	_music.stream = stream
	_music.volume_db = volume_db
	_music.play()


func stop_music() -> void:
	_music.stop()


func _free_voice() -> AudioStreamPlayer:
	for p in _players:
		if not p.playing:
			return p
	return _players[0] if not _players.is_empty() else null


func _load_stream(sound_name: String) -> AudioStream:
	if _cache.has(sound_name):
		return _cache[sound_name]

	for ext in EXTENSIONS:
		var path := AUDIO_DIR + sound_name + ext
		if ResourceLoader.exists(path):
			# load() devuelve Resource; hace falta el cast para devolverlo como
			# AudioStream (GDScript no angosta el tipo con el `is` de arriba).
			var res := load(path)
			if res is AudioStream:
				var stream := res as AudioStream
				_cache[sound_name] = stream
				return stream

	# Todavía no hay archivo para este sonido: avisamos una vez y seguimos.
	if not _warned.has(sound_name):
		_warned[sound_name] = true
		print("[audio] falta el archivo para '%s' (poner %s%s.ogg)" % [sound_name, AUDIO_DIR, sound_name])
	_cache[sound_name] = null
	return null
