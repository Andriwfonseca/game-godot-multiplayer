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

# 🌍 FÍSICA DO MUNDO
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

# 🆔 IDENTIFICAÇÃO DO JOGADOR
var player_id: int
var is_local_player = false # Se é o jogador controlado localmente

# 📡 SISTEMA DE INPUT-BASED (INPUTS EM VEZ DE POSIÇÕES)
var remote_input_direction: float = 0.0 # Direção recebida de jogador remoto (-1 a 1)
var remote_jump_pressed: bool = false # Se pulo foi pressionado no jogador remoto
var remote_is_on_floor: bool = true # Estado do chão do jogador remoto
var last_input_time: float = 0.0 # Último tempo que recebeu input

# 📡 Controle de envio de inputs (otimização)
var last_sent_direction: float = 0.0 # Última direção enviada
var input_send_timer: float = 0.0 # Timer para envio periódico de inputs
var input_send_interval: float = 0.05 # Envia inputs a cada 50ms (20 vezes por segundo)

# 📡 SINCRONIZAÇÃO PERIÓDICA (para correção de dessincronização)
var sync_timer: float = 0.0
var sync_interval: float = 0.5 # Sincroniza posição a cada 0.5 segundos

func _ready():
	"""
	Função chamada quando o jogador é criado
	"""
	print("🎮 Player _ready chamado")

	# 🎨 Aplica cor única para cada jogador
	_set_player_color()

	# 📡 Inicializa variáveis de input remoto
	remote_input_direction = 0.0
	remote_jump_pressed = false
	last_input_time = 0.0
	sync_timer = 0.0
	last_sent_direction = 0.0
	input_send_timer = 0.0


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
	NOVO: Sistema baseado em inputs - cada cliente processa movimento localmente
	"""
	sync_timer += delta
	input_send_timer += delta

	# 🎮 Jogador local: processa input e envia para rede
	if is_local_player:
		var current_direction = Input.get_axis("ui_left", "ui_right")
		var jump_pressed = Input.is_action_just_pressed("jump")

		# Processa movimento com inputs locais
		_handle_movement_with_input(delta, current_direction, jump_pressed)

		# 📡 Envia inputs via RPC periodicamente ou quando há mudança
		var direction_changed = abs(current_direction - last_sent_direction) > 0.01
		if input_send_timer >= input_send_interval or direction_changed or jump_pressed:
			input_send_timer = 0.0
			_send_input.rpc(current_direction, jump_pressed, is_on_floor())
			last_sent_direction = current_direction

		# 📡 Sincronização periódica de posição para correção
		if sync_timer >= sync_interval:
			sync_timer = 0.0
			_sync_position_periodic.rpc(global_position, velocity)

	# 🌐 Jogador remoto: processa movimento com inputs recebidos
	else:
		# Processa movimento com inputs recebidos via RPC
		var jump_just_pressed = remote_jump_pressed
		remote_jump_pressed = false # Reseta após processar

		_handle_movement_with_input(delta, remote_input_direction, jump_just_pressed)

		# Se não recebeu input há muito tempo, para o movimento
		last_input_time += delta
		if last_input_time > 0.3: # 300ms sem input = para
			remote_input_direction = 0.0

func _handle_movement_with_input(delta: float, direction: float, jump_pressed: bool):
	"""
	Processa movimentação e física do jogador usando inputs fornecidos
	Esta função é usada tanto para jogador local quanto remoto
	"""
	# 🌍 GRAVIDADE
	# Se não está no chão, aplica gravidade
	if not is_on_floor():
		velocity.y += gravity * delta

	# 🚀 PULO
	# Se pressionar pulo E estiver no chão
	if jump_pressed and is_on_floor():
		velocity.y = jump_velocity
		if is_local_player:
			print("🚀 Jogador ", player_id, " pulou!")

	# 🏃 MOVIMENTO HORIZONTAL
	# Usa direção fornecida (pode ser de Input local ou RPC remoto)
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

func setup_for_network(id: int, local_control: bool):
	"""
	Configura o jogador para networking
	Chamado pelo GameManager quando o jogador é criado
	"""
	player_id = id
	is_local_player = local_control

	# 🔐 Define autoridade (quem pode modificar este jogador)
	# REGRA: Cada jogador é controlado pelo cliente com o mesmo ID
	set_multiplayer_authority(id)

	# 🎯 Determina se É o jogador local baseado no ID
	# PROTEÇÃO: Verifica se multiplayer existe
	if multiplayer and multiplayer.has_multiplayer_peer():
		is_local_player = (id == multiplayer.get_unique_id())
	else:
		# Se não tem multiplayer, considera como local (modo single)
		is_local_player = local_control

	if is_local_player:
		print("🎮 Jogador LOCAL configurado - ID: ", id, " (EU controlo)")
	else:
		print("🌐 Jogador REMOTO configurado - ID: ", id, " (Outro controla)")

	_set_player_color()

# 📡 FUNÇÕES RPC (REMOTE PROCEDURE CALL) - Sistema baseado em inputs

@rpc("any_peer", "unreliable")
func _send_input(direction: float, jump_pressed: bool, is_on_floor_state: bool):
	"""
	Recebe inputs de jogador remoto e armazena para processamento
	Sistema novo: cada cliente processa movimento baseado em inputs
	"""
	# 📡 Só processa se NÃO for o jogador local (evita loop)
	if not is_local_player:
		remote_input_direction = direction
		if jump_pressed:
			remote_jump_pressed = true
		remote_is_on_floor = is_on_floor_state
		last_input_time = 0.0 # Reseta timer de timeout

@rpc("any_peer", "unreliable")
func _sync_position_periodic(pos: Vector2, vel: Vector2):
	"""
	Sincronização periódica de posição para correção de dessincronização
	Usado apenas para corrigir pequenos desvios, não para movimento principal
	"""
	# 📡 Só aceita se NÃO for o jogador local
	if not is_local_player:
		# Calcula distância até posição recebida
		var distance = global_position.distance_to(pos)

		# Se está muito dessincronizado (mais de 50 pixels), corrige
		if distance > 50.0:
			# Interpola suavemente para corrigir
			global_position = global_position.lerp(pos, 0.3)
			velocity = velocity.lerp(vel, 0.5)

# 🎯 FUNÇÕES ÚTEIS PARA OUTROS SCRIPTS

func get_player_id() -> int:
	return player_id

func is_local() -> bool:
	return is_local_player
