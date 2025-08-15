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
		# Adiciona Player.tscn à lista de spawnable scenes
		if player_scene:
			var scene_path = player_scene.resource_path
			print("🔍 Adicionando cena à spawnable list: ", scene_path)
		print("⚙️ MultiplayerSpawner configurado para sincronização")

	# 🚀 Inicia o jogo automaticamente após um delay
	await get_tree().create_timer(0.5).timeout
	start_game()

	# 📡 TESTE: Se é cliente, solicita sincronização
	if not multiplayer.is_server():
		await get_tree().create_timer(1.0).timeout
		print("📡 CLIENTE: Solicitando sincronização de jogadores...")
		_request_player_sync.rpc_id(1) # Envia para servidor (ID 1)

@rpc("any_peer", "call_local", "reliable")
func _request_player_sync():
	"""
	Cliente solicita sincronização de jogadores
	"""
	var requester_id = multiplayer.get_remote_sender_id()
	print("📡 SERVIDOR: Cliente ", requester_id, " solicitou sincronização")

	if multiplayer.is_server():
		# Envia todos os jogadores para o cliente que solicitou
		for child in players_container.get_children():
			if child.name.begins_with("Player_"):
				var player_id = child.name.split("_")[1].to_int()
				print("📤 Enviando jogador ", player_id, " para cliente ", requester_id)
				_force_spawn_player.rpc_id(requester_id, player_id, child.position)

@rpc("authority", "call_remote", "reliable")
func _force_spawn_player(peer_id: int, spawn_position: Vector2):
	"""
	Força spawn de um jogador específico no cliente
	"""
	print("📡 CLIENTE: Recebido _force_spawn_player - ID: ", peer_id, " Pos: ", spawn_position)

	# Verifica se já existe
	if players_container.get_node_or_null("Player_" + str(peer_id)):
		print("⚠️ Jogador ", peer_id, " já existe no cliente")
		return

	# Cria o jogador
	if not player_scene:
		print("❌ Player scene não configurada no cliente!")
		return

	var player_instance = player_scene.instantiate()
	var is_local = (peer_id == multiplayer.get_unique_id())

	player_instance.setup_for_network(peer_id, is_local)
	player_instance.position = spawn_position
	player_instance.name = "Player_" + str(peer_id)

	players_container.add_child(player_instance)
	print("✅ CLIENTE: Jogador forçado criado: ", player_instance.name)


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
	Spawna todos os jogadores conectados - MÉTODO MANUAL CORRIGIDO
	"""
	if not multiplayer.is_server():
		return

	print("👥 Spawnando todos os jogadores (método manual corrigido)...")

	# Spawna o jogador do servidor (host) - ID sempre é 1
	_create_player_manually(1, true)

	# Spawna jogadores conectados
	for peer_id in NetworkManager.players.keys():
		if peer_id != 1: # Não spawna o host novamente
			_create_player_manually(peer_id, false)

func _setup_spawned_player(player: Node, peer_id: int, is_local: bool):
	"""
	Configura um jogador que foi spawnado pelo MultiplayerSpawner
	"""
	print("⚙️ Configurando jogador spawnado: ", peer_id)

	# Configura o jogador
	if player.has_method("setup_for_network"):
		player.setup_for_network(peer_id, is_local)

	# Define posição
	player.position = _get_spawn_position()

	# Define nome
	player.name = "Player_" + str(peer_id)

	print("✅ Jogador configurado: ", player.name)

func _create_player_manually(peer_id: int, local_control: bool):
	"""
	Cria um jogador manualmente - VERSÃO SIMPLIFICADA
	"""
	print("👤 Criando jogador - ID: ", peer_id, " Local: ", local_control)

	if not player_scene:
		print("❌ Player scene não configurada!")
		return

	# 🆕 Cria nova instância do jogador
	var player_instance = player_scene.instantiate()

	# ⚙️ Configura o jogador
	player_instance.setup_for_network(peer_id, local_control)
	player_instance.position = _get_spawn_position()
	player_instance.name = "Player_" + str(peer_id)

	# 🌳 Adiciona à árvore de cena
	players_container.add_child(player_instance)

	print("✅ Jogador criado com sucesso: ", player_instance.name)

	# 📡 NOTIFICA TODOS OS CLIENTES sobre o novo jogador
	if multiplayer.is_server():
		print("📡 SERVIDOR: Enviando RPC _notify_player_spawned para todos - ID: ", peer_id)
		_notify_player_spawned.rpc(peer_id, player_instance.position)
	else:
		print("📡 CLIENTE: Não envio RPC (não sou servidor)")

@rpc("authority", "call_local", "reliable")
func _notify_player_spawned(peer_id: int, spawn_position: Vector2):
	"""
	RPC para notificar clientes sobre jogador criado
	"""
	var sender_id = multiplayer.get_remote_sender_id()
	print("📡 RPC _notify_player_spawned RECEBIDO - Peer: ", peer_id, " From: ", sender_id, " IsServer: ", multiplayer.is_server())

	# Se já existe este jogador, não cria novamente
	if players_container.get_node_or_null("Player_" + str(peer_id)):
		print("⚠️ Jogador ", peer_id, " já existe, ignorando...")
		return

	# Determina se é local para este cliente
	var is_local_for_this_client = false
	if multiplayer and multiplayer.has_multiplayer_peer():
		is_local_for_this_client = (peer_id == multiplayer.get_unique_id())

	# Cria o jogador localmente
	if not player_scene:
		print("❌ Player scene não configurada no cliente!")
		return

	var player_instance = player_scene.instantiate()
	player_instance.setup_for_network(peer_id, is_local_for_this_client)
	player_instance.position = spawn_position
	player_instance.name = "Player_" + str(peer_id)

	players_container.add_child(player_instance)
	print("✅ Jogador sincronizado no cliente: ", player_instance.name)
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

		# 📡 ENVIA todos os jogadores existentes para o novo cliente
		_send_existing_players_to_client.rpc_id(peer_id)

@rpc("authority", "call_local", "reliable")
func _send_existing_players_to_client():
	"""
	Envia lista de jogadores existentes para um cliente que acabou de conectar
	"""
	print("📡 Enviando jogadores existentes para cliente...")

	for child in players_container.get_children():
		if child is Player:
			var player = child as Player
			print("📤 Enviando jogador existente: ", player.name, " pos: ", player.position)
			_notify_player_spawned.rpc(player.player_id, player.position)

func _on_player_disconnected(peer_id: int):
	"""
	Callback quando um jogador se desconecta
	"""
	print("😢 GameManager: Jogador desconectado - ", peer_id)

	# Remove o jogador da cena local
	var player_node = players_container.get_node_or_null("Player_" + str(peer_id))
	if player_node:
		print("🗑️ Removendo jogador da cena: ", player_node.name)
		player_node.queue_free()

	# Notifica todos os clientes sobre a remoção
	if multiplayer.is_server():
		_notify_player_removed.rpc(peer_id)

@rpc("authority", "call_local", "reliable")
func _notify_player_removed(peer_id: int):
	"""
	RPC para notificar clientes sobre jogador removido
	"""
	print("📡 Recebida notificação de jogador removido: ", peer_id)

	var player_node = players_container.get_node_or_null("Player_" + str(peer_id))
	if player_node:
		print("🗑️ Removendo jogador sincronizado: ", player_node.name)
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
	# 🔍 PROTEÇÃO: Verifica se multiplayer existe
	if not multiplayer or not multiplayer.has_multiplayer_peer():
		print("⚠️ Multiplayer não está ativo ainda")
		return null

	var local_id = multiplayer.get_unique_id()

	# 🔍 PROCURA por jogador local de forma mais robusta
	for child in players_container.get_children():
		if child.has_method("is_local") and child.is_local():
			print("📹 Jogador local encontrado: ", child.name, " (método is_local)")
			return child as Player

	# 🔍 FALLBACK: Procura por nome
	var player_node = players_container.get_node_or_null("Player_" + str(local_id))
	if player_node:
		print("📹 Jogador local encontrado: ", player_node.name, " (por nome)")
		return player_node as Player

	print("⚠️ Jogador local não encontrado ainda - ID: ", local_id)
	print("🔍 Jogadores disponíveis:")
	for child in players_container.get_children():
		print("  - ", child.name, " is_local: ", child.has_method("is_local") and child.is_local())

	return null

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
