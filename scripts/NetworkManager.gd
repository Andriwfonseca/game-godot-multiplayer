extends Node

# NetworkManager - Gerencia todas as conexões multiplayer
# Este script é um singleton (AutoLoad) que controla o networking

# 📡 SIGNALS - Eventos que outros scripts podem "escutar"
signal player_connected(peer_id)      # Quando alguém conecta
signal player_disconnected(peer_id)   # Quando alguém desconecta  
signal connection_failed()            # Quando falha ao conectar
signal connection_succeeded()         # Quando conecta com sucesso

# ⚙️ CONSTANTES - Configurações fixas
const PORT = 7000        # Porta padrão do servidor
const MAX_PLAYERS = 8    # Máximo de jogadores simultâneos

# 📊 VARIÁVEIS - Estado atual do networking
var players = {}         # Dicionário com todos os jogadores conectados
var player_name = "Player"  # Nome base dos jogadores

func _ready():
	# 🔗 CONECTA OS SIGNALS DO MULTIPLAYER
	# Quando o sistema de multiplayer detecta eventos, chamamos nossas funções
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.connected_to_server.connect(_on_connection_succeeded)

# 🏠 FUNÇÃO PARA HOSPEDAR UM JOGO
func host_game(port: int = PORT):
	"""
	Cria um servidor para hospedar o jogo
	Retorna true se conseguiu criar, false se deu erro
	"""
	print("🏠 Iniciando servidor na porta: ", port)
	
	# Cria o peer de rede usando ENet (protocolo confiável)
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(port, MAX_PLAYERS)
	
	# Verifica se deu erro
	if error != OK:
		print("❌ Erro ao criar servidor: ", error)
		return false
	
	# Define este peer como o multiplayer ativo
	multiplayer.multiplayer_peer = peer
	print("✅ Servidor criado com sucesso!")
	
	# Adiciona o host como primeiro jogador (ID sempre é 1)
	_add_player(1)
	return true

# 🔗 FUNÇÃO PARA CONECTAR A UM JOGO
func join_game(ip: String, port: int = PORT):
	"""
	Conecta a um servidor existente
	Retorna true se iniciou a conexão, false se deu erro
	"""
	print("🔗 Tentando conectar em: ", ip, ":", port)
	
	# Cria o peer de rede como cliente
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(ip, port)
	
	# Verifica se deu erro
	if error != OK:
		print("❌ Erro ao conectar: ", error)
		return false
	
	# Define este peer como o multiplayer ativo
	multiplayer.multiplayer_peer = peer
	return true

# ➕ FUNÇÃO INTERNA PARA ADICIONAR JOGADOR
func _add_player(peer_id: int):
	"""
	Adiciona um novo jogador à lista
	"""
	players[peer_id] = {
		"id": peer_id,
		"name": player_name + str(peer_id)
	}
	
	print("👤 Jogador adicionado: ", peer_id)
	player_connected.emit(peer_id)  # Emite signal para avisar outros scripts

# ➖ FUNÇÃO INTERNA PARA REMOVER JOGADOR  
func _remove_player(peer_id: int):
	"""
	Remove um jogador da lista
	"""
	if peer_id in players:
		print("👋 Jogador removido: ", peer_id)
		players.erase(peer_id)
		player_disconnected.emit(peer_id)  # Emite signal para avisar outros scripts

# 🎯 CALLBACKS - Funções chamadas automaticamente pelo sistema de multiplayer
func _on_player_connected(peer_id: int):
	print("🎉 Jogador conectado: ", peer_id)
	_add_player(peer_id)

func _on_player_disconnected(peer_id: int):
	print("😢 Jogador desconectado: ", peer_id)
	_remove_player(peer_id)

func _on_connection_failed():
	print("💥 Falha na conexão")
	connection_failed.emit()

func _on_connection_succeeded():
	print("🎊 Conectado ao servidor com sucesso!")
	connection_succeeded.emit()

# 🚪 FUNÇÃO PARA DESCONECTAR
func disconnect_from_game():
	"""
	Desconecta do jogo atual
	"""
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	
	players.clear()
	print("🚪 Desconectado do jogo")

# 📊 FUNÇÕES ÚTEIS PARA OUTROS SCRIPTS
func get_player_count() -> int:
	return players.size()

func is_server() -> bool:
	return multiplayer.is_server()
