extends Control

# MainMenu - Interface principal para conectar e hospedar jogos
# Controla os menus de host/join e navegação

# 📍 REFERÊNCIAS DOS NÓS (conectadas automaticamente)
@onready var main_panel = $MainPanel
@onready var host_button = $MainPanel/VBoxContainer/HostButton
@onready var join_button = $MainPanel/VBoxContainer/JoinButton
@onready var quit_button = $MainPanel/VBoxContainer/QuitButton

@onready var join_panel = $JoinPanel
@onready var ip_input = $JoinPanel/VBoxContainer/IPInput
@onready var port_input = $JoinPanel/VBoxContainer/PortInput
@onready var connect_button = $JoinPanel/VBoxContainer/HBoxContainer/ConnectButton
@onready var back_button = $JoinPanel/VBoxContainer/HBoxContainer/BackButton

@onready var status_label = $StatusLabel

func _ready():
	"""
	Inicialização do MainMenu
	"""
	print("🎮 MainMenu iniciado!")

	# 🔗 Conecta sinais dos botões
	host_button.pressed.connect(_on_host_button_pressed)
	join_button.pressed.connect(_on_join_button_pressed)
	quit_button.pressed.connect(_on_quit_button_pressed)

	connect_button.pressed.connect(_on_connect_button_pressed)
	back_button.pressed.connect(_on_back_button_pressed)

	# 🔗 Conecta sinais do NetworkManager
	if NetworkManager:
		NetworkManager.connection_succeeded.connect(_on_connection_succeeded)
		NetworkManager.connection_failed.connect(_on_connection_failed)
		print("🔗 Conectado ao NetworkManager")
	else:
		print("❌ NetworkManager não encontrado!")

	# 🎨 Inicializa interface
	_show_main_menu()

func _show_main_menu():
	"""
	Mostra o menu principal
	"""
	main_panel.visible = true
	join_panel.visible = false
	status_label.text = "Jogo Multiplayer 2D - Plataforma"
	status_label.modulate = Color.WHITE

func _show_join_menu():
	"""
	Mostra o menu de conectar
	"""
	main_panel.visible = false
	join_panel.visible = true
	ip_input.text = "127.0.0.1" # IP local padrão
	port_input.text = "7000" # Porta padrão
	ip_input.grab_focus() # Foca no campo IP

# 🎯 CALLBACKS DOS BOTÕES

func _on_host_button_pressed():
	"""
	Callback do botão Host - Cria servidor
	"""
	print("🏠 Tentando criar servidor...")
	status_label.text = "Criando servidor..."
	status_label.modulate = Color.YELLOW

	var success = NetworkManager.host_game()

	if success:
		status_label.text = "Servidor criado! Aguardando jogadores..."
		status_label.modulate = Color.GREEN
		print("✅ Servidor criado com sucesso!")

		# 🕐 Aguarda um pouco e inicia o jogo
		await get_tree().create_timer(2.0).timeout
		_start_game()
	else:
		status_label.text = "Erro ao criar servidor!"
		status_label.modulate = Color.RED
		print("❌ Falha ao criar servidor")

func _on_join_button_pressed():
	"""
	Callback do botão Join - Mostra tela de conexão
	"""
	print("🔗 Abrindo menu de conexão...")
	_show_join_menu()

func _on_quit_button_pressed():
	"""
	Callback do botão Quit - Sai do jogo
	"""
	print("👋 Saindo do jogo...")
	get_tree().quit()

func _on_connect_button_pressed():
	"""
	Callback do botão Connect - Tenta conectar ao servidor
	"""
	var ip = ip_input.text.strip_edges()
	var port = int(port_input.text)

	# 🔍 Validação de entrada
	if ip.is_empty():
		status_label.text = "Digite um IP válido!"
		status_label.modulate = Color.RED
		return

	if port <= 0 or port > 65535:
		status_label.text = "Digite uma porta válida (1-65535)!"
		status_label.modulate = Color.RED
		return

	print("🔗 Tentando conectar em: ", ip, ":", port)
	status_label.text = "Conectando..."
	status_label.modulate = Color.YELLOW

	var success = NetworkManager.join_game(ip, port)

	if not success:
		status_label.text = "Erro ao iniciar conexão!"
		status_label.modulate = Color.RED

func _on_back_button_pressed():
	"""
	Callback do botão Back - Volta ao menu principal
	"""
	print("⬅️ Voltando ao menu principal...")
	_show_main_menu()

# 🌐 CALLBACKS DE REDE

func _on_connection_succeeded():
	"""
	Callback quando conecta com sucesso ao servidor
	"""
	print("🎉 Conectado ao servidor com sucesso!")
	status_label.text = "Conectado! Entrando no jogo..."
	status_label.modulate = Color.GREEN

	# 🕐 Aguarda um pouco e entra no jogo
	await get_tree().create_timer(1.5).timeout
	_start_game()

func _on_connection_failed():
	"""
	Callback quando falha na conexão
	"""
	print("💥 Falha na conexão com o servidor!")
	status_label.text = "Falha na conexão!"
	status_label.modulate = Color.RED

func _start_game():
	"""
	Inicia o jogo carregando a cena principal
	"""
	print("🚀 Carregando cena do jogo...")
	get_tree().change_scene_to_file("res://scenes/Game.tscn")

# ⌨️ INPUT HANDLING PARA FACILIDADE DE USO

func _input(event):
	"""
	Processa input de teclado para facilitar navegação
	"""
	if join_panel.visible and event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ENTER:
				# Enter = Conectar
				_on_connect_button_pressed()
			KEY_ESCAPE:
				# Esc = Voltar
				_on_back_button_pressed()

	elif main_panel.visible and event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_H:
				# H = Host
				_on_host_button_pressed()
			KEY_J:
				# J = Join
				_on_join_button_pressed()
			KEY_ESCAPE:
				# Esc = Quit
				_on_quit_button_pressed()

# 🔧 FUNÇÕES ÚTEIS

func show_message(text: String, color: Color = Color.WHITE):
	"""
	Mostra uma mensagem no status label
	"""
	status_label.text = text
	status_label.modulate = color

func reset_interface():
	"""
	Reseta a interface para o estado inicial
	"""
	_show_main_menu()
	NetworkManager.disconnect_from_game()
