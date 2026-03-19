wpa_import.sh — Importa senhas do wpa_supplicant

Lê todos os blocos network={...} do arquivo .conf
Compara o ssid= com o banco e atualiza o campo password onde há correspondência
Informa quais SSIDs foram encontrados/ignorados
Aceita caminho customizado: sudo ./wpa_import.sh /outro/caminho/wpa.conf

wifi_show.sh — Exibe o banco no terminal com cores

Mostra estatísticas (total, com senha, ocultos, abertos)
Colore por tipo de segurança (WPA3=verde, WPA2=amarelo, aberta=vermelho)
Indica visualmente se a senha está salva
Suporta filtros e ordenação: ./wifi_show.sh known ssid / ./wifi_show.sh open / ./wifi_show.sh all channel

wifi_connect.sh — Menu interativo de conexão

Lista e permite escolher a interface WiFi
Faz rescan e exibe as redes com barra de sinal, segurança e se a senha está no banco
Para redes conhecidas: oferece usar a senha salva
Para redes novas: pede a senha e oferece salvar no banco
Opções [r] reatualizar scan, [i] trocar interface, [q] sair