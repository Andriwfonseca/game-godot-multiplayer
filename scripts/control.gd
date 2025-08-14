extends Control

func _ready():
	print("🧪 Testando NetworkManager...")
	
	# Testa se o NetworkManager está acessível
	if NetworkManager:
		print("✅ NetworkManager carregado com sucesso!")
		print("📊 Jogadores conectados: ", NetworkManager.get_player_count())
	else:
		print("❌ NetworkManager não encontrado!")
		print("⚠️  Verifique se está configurado no AutoLoad")

func _input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_H:
				print("🏠 Testando host...")
				NetworkManager.host_game()
			KEY_J:
				print("🔗 Testando join...")
				NetworkManager.join_game("127.0.0.1")
			KEY_Q:
				print("🚪 Desconectando...")
				NetworkManager.disconnect_from_game()
			KEY_ESCAPE:
				print("👋 Saindo...")
				get_tree().quit()
