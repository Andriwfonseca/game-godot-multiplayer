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

	# ⏱️ Aguarda um frame para garantir que os jogadores foram spawnados
	await get_tree().process_frame

	if game_manager:
		# 🔍 Pega o jogador local
		target_player = game_manager.get_local_player()

		if target_player:
			print("📹 Câmera agora segue o jogador local: ", target_player.name)
			# 📍 Posiciona a câmera imediatamente no jogador (sem animação)
			global_position = target_player.global_position + camera_offset
		else:
			print("⚠️ Jogador local não encontrado ainda, tentando novamente...")
			# 🔄 Tenta novamente após 1 segundo (máximo 5 tentativas)
			var max_attempts = 5
			for attempt in range(max_attempts):
				await get_tree().create_timer(1.0).timeout
				target_player = game_manager.get_local_player()
				if target_player:
					print("📹 Câmera encontrou jogador local na tentativa ", attempt + 1, ": ", target_player.name)
					global_position = target_player.global_position + camera_offset
					return

			print("❌ Erro: Não foi possível encontrar jogador local após ", max_attempts, " tentativas")

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
