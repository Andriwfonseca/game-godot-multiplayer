extends Camera2D

# CameraController - Controla a câmera para seguir o jogador local
# A câmera sempre segue o jogador do cliente local

# ⚙️ CONFIGURAÇÕES
@export var follow_speed = 5.0 # Velocidade de seguimento (suave)
@export var camera_offset = Vector2(0, -50) # Offset da câmera (0, -50 = um pouco acima)

# 🎯 REFERÊNCIAS
var target_player: Player # Jogador que a câmera deve seguir
var game_manager: Node # Referência ao GameManager

func _ready():
	"""
	Inicialização do CameraController
	"""
	print("📹 CameraController iniciado!")

	# 🔍 Encontra o GameManager
	game_manager = get_node("../GameManager")

	if game_manager:
		# 🔗 Conecta ao sinal de jogo iniciado
		game_manager.game_started.connect(_on_game_started)
		print("🔗 Conectado ao GameManager")
	else:
		print("❌ GameManager não encontrado!")

func _process(delta):
	"""
	Atualiza a posição da câmera a cada frame
	"""
	# 📹 Se tem jogador alvo, segue ele suavemente
	if target_player and is_instance_valid(target_player):
		_follow_player(delta)

func _follow_player(delta):
	"""
	Faz a câmera seguir suavemente o jogador
	"""
	# 🎯 Calcula posição alvo (jogador + offset)
	var target_position = target_player.global_position + camera_offset

	# 📹 Move suavemente para a posição alvo (lerp = interpolação linear)
	global_position = global_position.lerp(target_position, follow_speed * delta)

func _on_game_started():
	"""
	Callback quando o jogo inicia - encontra o jogador local
	"""
	print("🎮 Jogo iniciado - procurando jogador local...")

	# ⏱️ Aguarda mais tempo para RPC de jogadores
	await get_tree().create_timer(0.5).timeout

	# 🔄 Tenta encontrar jogador local com mais paciência
	_find_local_player_with_retry()

func _find_local_player_with_retry():
	"""
	Procura o jogador local com múltiplas tentativas
	"""
	if not game_manager:
		print("❌ GameManager não encontrado!")
		return

	var max_attempts = 10 # Mais tentativas
	var attempt = 0

	while attempt < max_attempts:
		attempt += 1
		print("🔍 Tentativa ", attempt, " de encontrar jogador local...")

		target_player = game_manager.get_local_player()

		if target_player:
			print("📹 🎉 Câmera encontrou jogador local: ", target_player.name)
			global_position = target_player.global_position + camera_offset
			return

		# Aguarda antes da próxima tentativa
		await get_tree().create_timer(0.5).timeout

	print("❌ Erro: Câmera não conseguiu encontrar jogador local após ", max_attempts, " tentativas")
	print("🔍 Tentando método alternativo...")
	_find_local_player_alternative()

func _find_local_player_alternative():
	"""
	Método alternativo para encontrar jogador local
	"""
	print("🔍 Método alternativo: Procurando jogador local diretamente...")

	if not game_manager:
		return

	var players_container = game_manager.get_node("Players")
	if not players_container:
		print("❌ Players container não encontrado")
		return

	# Procura diretamente nos filhos
	for child in players_container.get_children():
		print("🔍 Verificando jogador: ", child.name)
		if child.has_method("is_local") and child.is_local():
			target_player = child
			print("📹 🎉 Método alternativo encontrou jogador local: ", target_player.name)
			global_position = target_player.global_position + camera_offset
			return

	print("❌ Método alternativo também falhou")

func set_target(player: Player):
	"""
	Define manualmente qual jogador a câmera deve seguir
	Útil para debugging ou casos especiais
	"""
	target_player = player
	if target_player:
		print("📹 Alvo da câmera definido: ", target_player.name)
		global_position = target_player.global_position + camera_offset

# 🎯 FUNÇÕES ÚTEIS

func get_target_player() -> Player:
	"""
	Retorna o jogador que a câmera está seguindo
	"""
	return target_player

func is_following() -> bool:
	"""
	Verifica se a câmera está seguindo algum jogador
	"""
	return target_player != null and is_instance_valid(target_player)

func reset_camera():
	"""
	Para de seguir qualquer jogador
	"""
	target_player = null
	print("📹 Câmera resetada")

# 🔄 CONFIGURAÇÕES EM TEMPO REAL

func set_follow_speed(speed: float):
	"""
	Ajusta velocidade de seguimento em tempo real
	"""
	follow_speed = speed
	print("📹 Velocidade de seguimento: ", speed)

func set_camera_offset(new_offset: Vector2):
	"""
	Ajusta offset da câmera em tempo real
	"""
	camera_offset = new_offset
	print("📹 Offset da câmera: ", camera_offset)
