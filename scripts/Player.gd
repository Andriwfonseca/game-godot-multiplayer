extends CharacterBody2D
class_name Player

# Player Controller - Controla a movimentação e física do jogador
# Sincronizado via multiplayer para todos os clientes

# 🎮 CONFIGURAÇÕES DE MOVIMENTO
@export var speed = 300.0 # Velocidade de corrida (pixels/segundo)
@export var jump_velocity = -400.0 # Força do pulo (negativo = para cima)
@export var player_color = Color.BLUE # Cor do jogador

# 📍 REFERÊNCIAS DOS NÓS (serão conectadas automaticamente)
@onready var sprite = $Sprite2D
@onready var collision = $CollisionShape2D
@onready var multiplayer_sync = $MultiplayerSynchronizer

# 🌍 FÍSICA DO MUNDO
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

# 🆔 IDENTIFICAÇÃO DO JOGADOR
var player_id: int
var is_local_player = false # Se é o jogador controlado localmente

func _ready():
	"""
	Função chamada quando o jogador é criado
	"""
	# 🔍 Descobre se este é o jogador local
	# (Quem tem autoridade para controlá-lo)
	if multiplayer.get_remote_sender_id() == 0:
		is_local_player = true
		set_multiplayer_authority(multiplayer.get_unique_id())

	# 🎨 Aplica cor única para cada jogador
	_set_player_color()

	# 🌐 CONFIGURAÇÃO MANUAL DE SINCRONIZAÇÃO
	if multiplayer_sync:
		# Define quais propriedades sincronizar
		multiplayer_sync.set_multiplayer_authority(multiplayer.get_unique_id())
		print("🔗 Sincronização configurada para jogador: ", multiplayer.get_unique_id())

func _set_player_color():
	"""
	Define uma cor única baseada no ID do jogador
	"""
	# 🌈 Array de cores disponíveis
	var colors = [
		Color.BLUE, # Jogador 1
		Color.RED, # Jogador 2
		Color.GREEN, # Jogador 3
		Color.YELLOW, # Jogador 4
		Color.PURPLE, # Jogador 5
		Color.ORANGE, # Jogador 6
		Color.CYAN, # Jogador 7
		Color.PINK # Jogador 8
	]

	# 🎯 Seleciona cor baseada no ID
	if player_id > 0 and player_id <= colors.size():
		player_color = colors[player_id - 1]
	else:
		player_color = Color.WHITE # Cor padrão

	# 🎨 Aplica a cor no sprite
	if sprite:
		sprite.modulate = player_color

func _physics_process(delta):
	"""
	Função chamada 60 vezes por segundo para física
	IMPORTANTE: Apenas o jogador local processa input!
	"""
	# 🚫 Se não é o jogador local, não processa movimento
	if not is_local_player:
		return

	# 🎮 Processa movimentação
	_handle_movement(delta)

func _handle_movement(delta):
	"""
	Processa movimentação e física do jogador
	Esta é a parte mais importante - a física de plataforma!
	"""

	# 🌍 GRAVIDADE
	# Se não está no chão, aplica gravidade
	if not is_on_floor():
		velocity.y += gravity * delta

	# 🚀 PULO
	# Se pressionar pulo E estiver no chão
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity
		print("🚀 Jogador ", player_id, " pulou!")

	# 🏃 MOVIMENTO HORIZONTAL
	# Pega input das teclas (A/D ou setas)
	var direction = Input.get_axis("ui_left", "ui_right")

	if direction != 0:
		# Se está pressionando alguma direção
		velocity.x = direction * speed
	else:
		# Se não está pressionando nada, para gradualmente
		velocity.x = move_toward(velocity.x, 0, speed)

	# 💨 APLICA O MOVIMENTO
	# Esta função mágica faz toda a física acontecer!
	move_and_slide()

# 🆔 FUNÇÕES PARA CONFIGURAR O JOGADOR

func set_player_id(id: int):
	"""
	Define o ID do jogador
	"""
	player_id = id
	name = "Player_" + str(id) # Nome do nó na árvore
	_set_player_color()
	print("👤 Jogador configurado - ID: ", id, " Nome: ", name)

func setup_for_network(id: int, is_local: bool):
	"""
	Configura o jogador para networking
	Chamado pelo GameManager quando o jogador é criado
	"""
	player_id = id
	is_local_player = is_local

	# 🔐 Define autoridade (quem pode modificar este jogador)
	if is_local:
		set_multiplayer_authority(id)
		print("🎮 Jogador local configurado - ID: ", id)
	else:
		print("🌐 Jogador remoto configurado - ID: ", id)

	_set_player_color()

# 📡 FUNÇÕES RPC (REMOTE PROCEDURE CALL) - Para networking avançado
# Por enquanto não precisamos, mas deixamos preparado para futuras melhorias

@rpc("any_peer", "call_local")
func sync_position(pos: Vector2, vel: Vector2):
	"""
	Função para sincronização manual (se necessário)
	O MultiplayerSynchronizer já faz isso automaticamente
	"""
	if not is_local_player:
		position = pos
		velocity = vel

# 🎯 FUNÇÕES ÚTEIS PARA OUTROS SCRIPTS

func get_player_id() -> int:
	return player_id

func is_local() -> bool:
	return is_local_player
