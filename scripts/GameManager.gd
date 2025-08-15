extends Node

# GameManager - Controla o estado do jogo e spawn de jogadores
# Gerencia partidas, spawn points e sincronização

# 📡 SIGNALS - Eventos importantes do jogo
signal game_started()
signal game_ended()

# 🎮 CONFIGURAÇÕES
@export var player_scene: PackedScene # Cena do jogador (vamos configurar no editor)

# 📍 REFERÊNCIAS DOS NÓS (conectadas automaticamente)
@onready var players_container = $Players # Container para todos os jogadores
@onready var spawn_points = $SpawnPoints # Pontos de spawn
@onready var multiplayer_spawner = $MultiplayerSpawner # Sistema de spawn multiplayer

# 🎯 ESTADO DO JOGO
var game_started_flag = false
var spawn_point_index = 0 # Índice do próximo spawn point

func _ready():
	"""
	Inicialização do GameManager
	"""
	print("🎮 GameManager iniciado!")

	# 🎯 VERIFICA PLAYER SCENE
	print("✅ Player scene carregado: ", player_scene != null)
	if player_scene:
		print("📁 Player scene path: ", player_scene.resource_path)

	# 🔗 Conecta sinais do NetworkManager
	if NetworkManager:
		NetworkManager.player_connected.connect(_on_player_connected)
		NetworkManager.player_disconnected.connect(_on_player_disconnected)
		print("🔗 Conectado ao NetworkManager")
	else:
		print("❌ NetworkManager não encontrado!")

	# ⚙️ Configura MultiplayerSpawner
	if multiplayer_spawner:
		multiplayer_spawner.spawn_path = NodePath("Players")
		print("⚙️ MultiplayerSpawner configurado (modo manual)")

	# 🚀 Inicia o jogo automaticamente após um delay
	await get_tree().create_timer(0.5).timeout
	start_game()


# 📍 FUNÇÃO PARA OBTER POSIÇÃO DE SPAWN
func _get_spawn_position() -> Vector2:
	"""
	Retorna próxima posição de spawn disponível
	Roda entre os spawn points disponíveis
	"""
	# Se não tem spawn points, usa posição padrão
	if spawn_points.get_child_count() == 0:
		print("⚠️ Nenhum spawn point encontrado, usando posição padrão")
		return Vector2(100, 100)

	# Pega o próximo spawn point (rotaciona)
	var spawn_point = spawn_points.get_child(spawn_point_index % spawn_points.get_child_count())
	spawn_point_index += 1

	print("📍 Spawn point usado: ", spawn_point.name, " posição: ", spawn_point.global_position)
	return spawn_point.global_position

# 🚀 FUNÇÃO PARA INICIAR O JOGO
func start_game():
	"""
	Inicia o jogo - apenas o servidor pode chamar
	"""
	# Só o servidor (host) pode iniciar o jogo
	if not multiplayer.is_server():
		print("📱 Cliente aguardando início do jogo...")
		return

	if game_started_flag:
		print("⚠️ Jogo já foi iniciado!")
		return

	print("🚀 Iniciando jogo...")
	game_started_flag = true

	# Spawna todos os jogadores conectados
	_spawn_all_players()

	# Notifica todos os clientes que o jogo começou
	_notify_game_started.rpc()

@rpc("authority", "call_local")
func _notify_game_started():
	"""
	RPC para notificar que o jogo começou
	Chamado em todos os clientes
	"""
	game_started_flag = true
	game_started.emit()
	print("🎉 Jogo iniciado para todos os jogadores!")

# 👥 FUNÇÃO PARA SPAWNAR TODOS OS JOGADORES
func _spawn_all_players():
	"""
	Spawna todos os jogadores conectados (apenas servidor)
	MÉTODO MANUAL - mais confiável
	"""
	if not multiplayer.is_server():
		return

	print("👥 Spawnando todos os jogadores (método manual)...")

	# Spawna o jogador do servidor (host) - ID sempre é 1
	_create_player_manually(1, true)

	# Spawna jogadores conectados
	for peer_id in NetworkManager.players.keys():
		if peer_id != 1: # Não spawna o host novamente
			_create_player_manually(peer_id, false)

func _create_player_manually(peer_id: int, local_control: bool):
	print("🔍 DEBUG - player_scene: ", player_scene)
	print("🔍 DEBUG - player_scene válido: ", player_scene != null)

	if player_scene:
		print("🔍 DEBUG - Tentando instanciar...")
		var player_instance = player_scene.instantiate()
		print("🔍 DEBUG - Instância criada: ", player_instance)
		print("🔍 DEBUG - Tipo: ", player_instance.get_class())
		print("🔍 DEBUG - Tem método: ", player_instance.has_method("setup_for_network"))

		# Se chegou até aqui, continua...
		player_instance.setup_for_network(peer_id, local_control)
		player_instance.position = _get_spawn_position()

		# 🔧 FORÇA o nome correto ANTES de adicionar à cena
		player_instance.name = "Player_" + str(peer_id)

		# 🔍 DEBUG - Nome antes de adicionar
		print("🔍 DEBUG - Nome do jogador antes: ", player_instance.name)

		players_container.add_child(player_instance)

		# 🔍 DEBUG - Nome depois de adicionar
		print("🔍 DEBUG - Nome do jogador depois: ", player_instance.name)
		print("✅ Jogador criado: ", player_instance.name)
	else:
		print("❌ player_scene é null!")
# 🔗 CALLBACKS DOS EVENTOS DE REDE
func _on_player_connected(peer_id: int):
	"""
	Callback quando um jogador se conecta
	"""
	print("🎉 GameManager: Jogador conectado - ", peer_id)

	# Se o jogo já começou, spawna o jogador imediatamente
	if game_started_flag and multiplayer.is_server():
		print("🚀 Spawnando jogador recém-conectado: ", peer_id)
		_create_player_manually(peer_id, false)

func _on_player_disconnected(peer_id: int):
	"""
	Callback quando um jogador se desconecta
	"""
	print("😢 GameManager: Jogador desconectado - ", peer_id)

	# Remove o jogador da cena
	var player_node = players_container.get_node_or_null("Player_" + str(peer_id))
	if player_node:
		print("🗑️ Removendo jogador da cena: ", player_node.name)
		player_node.queue_free()

# 🛑 FUNÇÃO PARA TERMINAR O JOGO
func end_game():
	"""
	Termina o jogo atual
	"""
	if not multiplayer.is_server():
		return

	print("🛑 Terminando jogo...")
	game_started_flag = false

	# Remove todos os jogadores
	for child in players_container.get_children():
		child.queue_free()

	# Notifica todos os clientes
	_notify_game_ended.rpc()

@rpc("authority", "call_local")
func _notify_game_ended():
	"""
	RPC para notificar que o jogo terminou
	"""
	game_started_flag = false
	game_ended.emit()
	print("🏁 Jogo terminado!")

# 🔍 FUNÇÕES ÚTEIS PARA OUTROS SCRIPTS
func get_local_player() -> Player:
	"""
	Retorna o jogador local (controlado por este cliente)
	"""
	var local_id = multiplayer.get_unique_id()
	print("🔍 DEBUG get_local_player - local_id: ", local_id)
	print("🔍 DEBUG get_local_player - procurando: Player_", local_id)
	print("🔍 DEBUG get_local_player - jogadores na cena:")

	# Lista todos os jogadores para debug
	for child in players_container.get_children():
		print("  - ", child.name, " (", child.get_class(), ")")

	var player_node = players_container.get_node_or_null("Player_" + str(local_id))
	print("🔍 DEBUG get_local_player - encontrado: ", player_node)

	return player_node as Player

func is_game_started() -> bool:
	"""
	Verifica se o jogo está rodando
	"""
	return game_started_flag

func get_player_count() -> int:
	"""
	Retorna quantos jogadores estão na partida
	"""
	return players_container.get_child_count()
